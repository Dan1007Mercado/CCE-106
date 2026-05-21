import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/data/models/user_model.dart';
import '../../../provider/data/models/provider_booking_model.dart';
import '../models/service_listing_model.dart';

class BookingService {
  BookingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Booking validation checklist:
  // - Customer A books Provider X from 8 AM to 10 AM.
  // - Customer B tries Provider X from 9 AM to 11 AM and gets blocked.
  // - Customer B books Provider X from 10 AM to 12 PM and succeeds.
  // - Same customer tries the same provider/service/schedule and gets blocked.
  // - Easy/Moderate/Hard/Expert bookings under 1/2/4/6 hours are rejected.
  // - Completed, declined, and cancelled bookings release the schedule lock.
  final FirebaseFirestore _firestore;

  static const double platformCommissionRate = 0.10;

  CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _paymentsCollection =>
      _firestore.collection('payments');

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> get _providerScheduleLocks =>
      _firestore.collection('providerScheduleLocks');

  CollectionReference<Map<String, dynamic>> get _customerBookingLocks =>
      _firestore.collection('customerBookingLocks');

  Stream<List<ProviderBookingModel>> streamCustomerBookings(String customerId) {
    return _bookingsCollection
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) {
          final bookings =
              snapshot.docs
                  .map(
                    (doc) => ProviderBookingModel.fromMap(doc.data(), doc.id),
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return bookings;
        });
  }

  static const Set<String> activeBookingStatuses = {'pending', 'accepted'};

  static int minimumDurationForDifficulty(String difficulty) {
    switch (difficulty.trim().toLowerCase()) {
      case 'easy':
        return 60;
      case 'hard':
        return 240;
      case 'expert':
        return 360;
      case 'moderate':
      default:
        return 120;
    }
  }

  Future<BookingConfirmationResult> createBookingWithMockPayment({
    required UserModel customer,
    required ServiceListingModel service,
    required DateTime selectedDate,
    required String selectedTimeSlot,
    required DateTime startAt,
    required DateTime endAt,
    required int durationMinutes,
    required String serviceAddress,
    required String notes,
    required String paymentMethod,
    String? jobId,
    String? difficulty,
  }) async {
    if (selectedTimeSlot.trim().isEmpty) {
      throw Exception('Choose an available time slot.');
    }

    if (serviceAddress.trim().isEmpty) {
      throw Exception('Enter the service address.');
    }

    if (paymentMethod.trim().isEmpty) {
      throw Exception('Choose a payment method.');
    }

    final resolvedDifficulty = _normalizeDifficulty(difficulty);
    final minimumDuration = minimumDurationForDifficulty(resolvedDifficulty);
    final normalizedStartAt = _trimSeconds(startAt);
    final normalizedEndAt = _trimSeconds(endAt);
    final normalizedDuration = normalizedEndAt
        .difference(normalizedStartAt)
        .inMinutes;

    if (normalizedEndAt.isBefore(normalizedStartAt) ||
        normalizedEndAt.isAtSameMomentAs(normalizedStartAt)) {
      throw Exception('End time must be later than start time.');
    }

    if (!_isWithinServiceHours(normalizedStartAt, normalizedEndAt)) {
      throw Exception(
        'Service visits are only allowed from 6:00 AM to 6:00 PM.',
      );
    }

    if (durationMinutes != normalizedDuration ||
        normalizedDuration < minimumDuration) {
      throw Exception(
        '$resolvedDifficulty bookings must be at least ${_formatDuration(minimumDuration)}.',
      );
    }

    final bookingRef = _bookingsCollection.doc();
    final paymentRef = _paymentsCollection.doc();
    final chatRef = _chatsCollection.doc(bookingRef.id);
    final commissionAmount = service.price * platformCommissionRate;
    final totalAmount = service.price + commissionAmount;
    final isCashPayment = paymentMethod.toLowerCase().contains('cash');
    final paymentProvider = isCashPayment
        ? 'cash_on_service'
        : 'mock_test_gateway';
    final bookingDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final normalizedJobId = jobId?.trim() ?? '';
    final providerLockRef = _providerScheduleLocks.doc(
      _providerScheduleLockId(service.providerId, normalizedStartAt),
    );
    final duplicateLockRef = _customerBookingLocks.doc(
      _customerBookingLockId(
        customerId: customer.uid,
        providerId: service.providerId,
        serviceId: service.serviceId,
        startAt: normalizedStartAt,
        jobId: normalizedJobId,
      ),
    );
    final startAtTimestamp = Timestamp.fromDate(normalizedStartAt);
    final endAtTimestamp = Timestamp.fromDate(normalizedEndAt);

    await _assertNoExistingActiveBooking(
      customer: customer,
      service: service,
      requestedStartAt: normalizedStartAt,
      requestedEndAt: normalizedEndAt,
      selectedDate: bookingDate,
      selectedTimeSlot: selectedTimeSlot.trim(),
      jobId: normalizedJobId,
    );

    // Firestore indexes useful for auditing or future server-side query checks:
    // bookings: providerId ASC, status ASC, startAt ASC, endAt ASC
    // bookings: customerId ASC, providerId ASC, jobId ASC, status ASC
    // bookings: customerId ASC, providerId ASC, serviceId ASC, startAt ASC, status ASC
    //
    // Flutter transactions can only read documents, not queries. The lock docs
    // below make the provider overlap and duplicate checks transactional on the
    // client without requiring Cloud Functions.
    await _firestore.runTransaction((transaction) async {
      final providerLockSnapshot = await transaction.get(providerLockRef);
      final duplicateLockSnapshot = await transaction.get(duplicateLockRef);

      final providerBookings = _readLockBookings(providerLockSnapshot.data());
      final hasProviderConflict = providerBookings.values.any((booking) {
        final status = booking['status']?.toString() ?? '';
        if (!activeBookingStatuses.contains(status)) {
          return false;
        }

        final existingStartAt = _readDateTime(booking['startAt']);
        final existingEndAt = _readDateTime(booking['endAt']);
        if (existingStartAt == null || existingEndAt == null) {
          return false;
        }

        return existingStartAt.isBefore(normalizedEndAt) &&
            existingEndAt.isAfter(normalizedStartAt);
      });

      if (hasProviderConflict) {
        throw Exception('This provider is already booked for that schedule.');
      }

      final duplicateLock = duplicateLockSnapshot.data();
      if (_isActiveDuplicateLock(duplicateLock)) {
        throw Exception(
          'You already booked this provider for this job or schedule.',
        );
      }

      providerBookings[bookingRef.id] = {
        'bookingId': bookingRef.id,
        'customerId': customer.uid,
        'serviceId': service.serviceId,
        'jobId': normalizedJobId,
        'status': 'pending',
        'startAt': startAtTimestamp,
        'endAt': endAtTimestamp,
        'selectedTimeSlot': selectedTimeSlot.trim(),
      };

      transaction.set(bookingRef, {
        'bookingId': bookingRef.id,
        'customerId': customer.uid,
        'customerName': customer.displayName,
        'customerPhone': customer.phone.trim(),
        'customerLocation': customer.locationLabel,
        'customerLatitude': customer.latitude,
        'customerLongitude': customer.longitude,
        'serviceAddress': serviceAddress.trim(),
        'serviceId': service.serviceId,
        'providerId': service.providerId,
        'providerName': service.providerName,
        'providerPhone': service.providerPhone.trim(),
        'serviceTitle': service.title,
        'category': service.category,
        'price': service.price,
        'totalAmount': totalAmount,
        'selectedDate': Timestamp.fromDate(bookingDate),
        'selectedTimeSlot': selectedTimeSlot.trim(),
        'startAt': startAtTimestamp,
        'endAt': endAtTimestamp,
        'durationMinutes': normalizedDuration,
        'jobId': normalizedJobId,
        'difficulty': resolvedDifficulty,
        'notes': notes.trim(),
        'status': 'pending',
        'paymentStatus': 'pending',
        'paymentId': paymentRef.id,
        'providerScheduleLockId': providerLockRef.id,
        'customerBookingLockId': duplicateLockRef.id,
        'completedAt': null,
        'cancelledAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(paymentRef, {
        'paymentId': paymentRef.id,
        'bookingId': bookingRef.id,
        'customerId': customer.uid,
        'providerId': service.providerId,
        'amount': totalAmount,
        'platformCommissionRate': platformCommissionRate,
        'platformCommissionAmount': commissionAmount,
        'providerEarning': service.price,
        'paymentMethod': paymentMethod.trim(),
        'paymentProvider': paymentProvider,
        'status': 'pending',
        'paymentLifecycle': 'held_until_done',
        'isReleasedToProvider': false,
        'completedAt': null,
        'cancelledAt': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(chatRef, {
        'chatId': bookingRef.id,
        'bookingId': bookingRef.id,
        'customerId': customer.uid,
        'providerId': service.providerId,
        'customerName': customer.displayName,
        'providerName': service.providerName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(providerLockRef, {
        'providerId': service.providerId,
        'dateKey': _dateKey(normalizedStartAt),
        'bookings': providerBookings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(duplicateLockRef, {
        'bookingId': bookingRef.id,
        'customerId': customer.uid,
        'providerId': service.providerId,
        'serviceId': service.serviceId,
        'jobId': normalizedJobId,
        'startAt': startAtTimestamp,
        'status': 'pending',
        'active': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return BookingConfirmationResult(
      bookingId: bookingRef.id,
      paymentId: paymentRef.id,
      paymentStatus: 'pending',
      totalAmount: totalAmount,
    );
  }

  Future<void> cancelBookingByCustomer({
    required String bookingId,
    required String customerId,
  }) async {
    final bookingRef = _bookingsCollection.doc(bookingId);
    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);

      if (!bookingSnapshot.exists) {
        throw Exception('Booking not found.');
      }

      final booking = bookingSnapshot.data();
      if (booking == null || booking['customerId'] != customerId) {
        throw Exception('You can only cancel your own booking.');
      }

      final status = booking['status'] as String? ?? '';
      if (status == 'completed') {
        throw Exception('Completed bookings cannot be cancelled.');
      }

      if (status == 'cancelled_by_customer') {
        throw Exception('Booking is already cancelled.');
      }

      final paymentId = booking['paymentId'] as String?;
      if (paymentId == null || paymentId.isEmpty) {
        throw Exception('Payment record not found.');
      }

      final paymentRef = _paymentsCollection.doc(paymentId);
      final paymentSnapshot = await transaction.get(paymentRef);
      if (!paymentSnapshot.exists) {
        throw Exception('Payment record not found.');
      }

      final payment = paymentSnapshot.data();
      final lockRefs = _resolveLockRefs(booking);
      final providerLockSnapshot = lockRefs.providerLockRef == null
          ? null
          : await transaction.get(lockRefs.providerLockRef!);
      final duplicateLockSnapshot = lockRefs.duplicateLockRef == null
          ? null
          : await transaction.get(lockRefs.duplicateLockRef!);

      final totalAmount = _readDouble(payment?['amount']);
      final providerCancellationFee = totalAmount * 0.03;
      final platformCancellationFee = totalAmount * 0.01;
      final refundAmount =
          totalAmount - providerCancellationFee - platformCancellationFee;

      transaction.update(bookingRef, {
        'status': 'cancelled_by_customer',
        'paymentStatus': 'cancelled_fee_charged',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'cancellation': {
          'cancelledBy': 'customer',
          'providerFeeRate': 0.03,
          'platformFeeRate': 0.01,
          'providerCancellationFee': providerCancellationFee,
          'platformCancellationFee': platformCancellationFee,
          'refundAmount': refundAmount,
        },
      });

      transaction.update(paymentRef, {
        'status': 'cancelled_fee_charged',
        'providerCancellationFee': providerCancellationFee,
        'platformCancellationFee': platformCancellationFee,
        'refundAmount': refundAmount,
        'isReleasedToProvider': false,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _releaseBookingLocks(
        transaction: transaction,
        bookingId: bookingId,
        providerLockRef: lockRefs.providerLockRef,
        providerLockData: providerLockSnapshot?.data(),
        duplicateLockRef: lockRefs.duplicateLockRef,
        duplicateLockExists: duplicateLockSnapshot?.exists ?? false,
        releasedStatus: 'cancelled_by_customer',
      );
    });
  }

  Future<void> _assertNoExistingActiveBooking({
    required UserModel customer,
    required ServiceListingModel service,
    required DateTime requestedStartAt,
    required DateTime requestedEndAt,
    required DateTime selectedDate,
    required String selectedTimeSlot,
    required String jobId,
  }) async {
    final snapshot = await _bookingsCollection
        .where('providerId', isEqualTo: service.providerId)
        .get();

    var hasProviderConflict = false;

    for (final doc in snapshot.docs) {
      final booking = doc.data();
      final status = booking['status']?.toString() ?? '';
      if (!activeBookingStatuses.contains(status)) {
        continue;
      }

      if (_isDuplicateCustomerBooking(
        booking: booking,
        customerId: customer.uid,
        providerId: service.providerId,
        serviceId: service.serviceId,
        requestedStartAt: requestedStartAt,
        selectedDate: selectedDate,
        selectedTimeSlot: selectedTimeSlot,
        jobId: jobId,
      )) {
        throw Exception(
          'You already booked this provider for this job or schedule.',
        );
      }

      final existingRange = _readExistingBookingRange(booking);
      if (existingRange == null) {
        continue;
      }

      if (_rangesOverlap(
        existingRange.startAt,
        existingRange.endAt,
        requestedStartAt,
        requestedEndAt,
      )) {
        hasProviderConflict = true;
      }
    }

    if (hasProviderConflict) {
      throw Exception('This provider is already booked for that schedule.');
    }
  }

  static bool _isDuplicateCustomerBooking({
    required Map<String, dynamic> booking,
    required String customerId,
    required String providerId,
    required String serviceId,
    required DateTime requestedStartAt,
    required DateTime selectedDate,
    required String selectedTimeSlot,
    required String jobId,
  }) {
    final existingCustomerId = booking['customerId']?.toString() ?? '';
    final existingProviderId = booking['providerId']?.toString() ?? '';
    if (existingCustomerId != customerId || existingProviderId != providerId) {
      return false;
    }

    final existingJobId = booking['jobId']?.toString().trim() ?? '';
    if (jobId.isNotEmpty) {
      return existingJobId == jobId;
    }

    final existingServiceId = booking['serviceId']?.toString() ?? '';
    if (existingServiceId != serviceId) {
      return false;
    }

    final existingStartAt = _readDateTime(booking['startAt']);
    if (existingStartAt != null &&
        _trimSeconds(existingStartAt).isAtSameMomentAs(requestedStartAt)) {
      return true;
    }

    final existingDate = _readDateTime(booking['selectedDate']);
    final existingTimeSlot = booking['selectedTimeSlot']?.toString().trim();
    return existingDate != null &&
        _isSameDate(existingDate, selectedDate) &&
        existingTimeSlot == selectedTimeSlot;
  }

  static _ExistingBookingRange? _readExistingBookingRange(
    Map<String, dynamic> booking,
  ) {
    final startAt = _readDateTime(booking['startAt']);
    final endAt = _readDateTime(booking['endAt']);
    if (startAt != null && endAt != null) {
      return _ExistingBookingRange(
        startAt: _trimSeconds(startAt),
        endAt: _trimSeconds(endAt),
      );
    }

    final selectedDate = _readDateTime(booking['selectedDate']);
    final selectedTimeSlot = booking['selectedTimeSlot']?.toString() ?? '';
    if (selectedDate == null || selectedTimeSlot.trim().isEmpty) {
      return null;
    }

    final parts = selectedTimeSlot.split(' - ');
    if (parts.length != 2) {
      return null;
    }

    final startMinutes = _parseClockMinutes(parts[0]);
    final endMinutes = _parseClockMinutes(parts[1]);
    if (startMinutes == null ||
        endMinutes == null ||
        endMinutes <= startMinutes) {
      return null;
    }

    return _ExistingBookingRange(
      startAt: _dateAtMinutes(selectedDate, startMinutes),
      endAt: _dateAtMinutes(selectedDate, endMinutes),
    );
  }

  static bool _rangesOverlap(
    DateTime existingStartAt,
    DateTime existingEndAt,
    DateTime requestedStartAt,
    DateTime requestedEndAt,
  ) {
    return existingStartAt.isBefore(requestedEndAt) &&
        existingEndAt.isAfter(requestedStartAt);
  }

  static bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static int? _parseClockMinutes(String value) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(value.trim());

    if (match == null) {
      return null;
    }

    final rawHour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    final period = match.group(3)?.toUpperCase();
    if (rawHour == null ||
        minute == null ||
        rawHour < 1 ||
        rawHour > 12 ||
        minute < 0 ||
        minute > 59 ||
        period == null) {
      return null;
    }

    var hour = rawHour % 12;
    if (period == 'PM') {
      hour += 12;
    }

    return hour * 60 + minute;
  }

  static DateTime _dateAtMinutes(DateTime date, int minutes) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  _BookingLockRefs _resolveLockRefs(Map<String, dynamic> booking) {
    final providerScheduleLockId =
        booking['providerScheduleLockId'] as String? ?? '';
    final customerBookingLockId =
        booking['customerBookingLockId'] as String? ?? '';

    DocumentReference<Map<String, dynamic>>? providerLockRef;
    if (providerScheduleLockId.isNotEmpty) {
      providerLockRef = _providerScheduleLocks.doc(providerScheduleLockId);
    } else {
      final providerId = booking['providerId'] as String? ?? '';
      final startAt = _readDateTime(booking['startAt']);
      if (providerId.isNotEmpty && startAt != null) {
        providerLockRef = _providerScheduleLocks.doc(
          _providerScheduleLockId(providerId, startAt),
        );
      }
    }

    DocumentReference<Map<String, dynamic>>? duplicateLockRef;
    if (customerBookingLockId.isNotEmpty) {
      duplicateLockRef = _customerBookingLocks.doc(customerBookingLockId);
    }

    return _BookingLockRefs(
      providerLockRef: providerLockRef,
      duplicateLockRef: duplicateLockRef,
    );
  }

  void _releaseBookingLocks({
    required Transaction transaction,
    required String bookingId,
    required DocumentReference<Map<String, dynamic>>? providerLockRef,
    required Map<String, dynamic>? providerLockData,
    required DocumentReference<Map<String, dynamic>>? duplicateLockRef,
    required bool duplicateLockExists,
    required String releasedStatus,
  }) {
    if (providerLockRef != null && providerLockData != null) {
      final providerBookings = _readLockBookings(providerLockData);
      providerBookings.remove(bookingId);
      transaction.set(providerLockRef, {
        'bookings': providerBookings,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    if (duplicateLockRef != null && duplicateLockExists) {
      transaction.set(duplicateLockRef, {
        'active': false,
        'status': releasedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  static Map<String, Map<String, dynamic>> _readLockBookings(
    Map<String, dynamic>? data,
  ) {
    final rawBookings = data?['bookings'];
    if (rawBookings is! Map) {
      return <String, Map<String, dynamic>>{};
    }

    return rawBookings.map((key, value) {
      return MapEntry(
        key.toString(),
        value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{},
      );
    });
  }

  static bool _isActiveDuplicateLock(Map<String, dynamic>? data) {
    if (data == null) {
      return false;
    }

    final isActive = data['active'] == true;
    final status = data['status']?.toString() ?? '';
    return isActive && activeBookingStatuses.contains(status);
  }

  static bool _isWithinServiceHours(DateTime startAt, DateTime endAt) {
    if (startAt.year != endAt.year ||
        startAt.month != endAt.month ||
        startAt.day != endAt.day) {
      return false;
    }

    final startMinutes = startAt.hour * 60 + startAt.minute;
    final endMinutes = endAt.hour * 60 + endAt.minute;
    return startMinutes >= 6 * 60 && endMinutes <= 18 * 60;
  }

  static DateTime _trimSeconds(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
  }

  static String _normalizeDifficulty(String? difficulty) {
    final cleaned = difficulty?.trim() ?? '';
    switch (cleaned.toLowerCase()) {
      case 'easy':
        return 'Easy';
      case 'hard':
        return 'Hard';
      case 'expert':
        return 'Expert';
      case 'moderate':
      default:
        return 'Moderate';
    }
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    return DateTime.tryParse(value.toString());
  }

  static String _formatDuration(int minutes) {
    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }

    return '$minutes minutes';
  }

  static String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}$month$day';
  }

  static String _providerScheduleLockId(String providerId, DateTime startAt) {
    return '${_safeDocumentId(providerId)}_${_dateKey(startAt)}';
  }

  static String _customerBookingLockId({
    required String customerId,
    required String providerId,
    required String serviceId,
    required DateTime startAt,
    required String jobId,
  }) {
    if (jobId.isNotEmpty) {
      return [
        'job',
        _safeDocumentId(customerId),
        _safeDocumentId(providerId),
        _safeDocumentId(jobId),
      ].join('_');
    }

    return [
      'schedule',
      _safeDocumentId(customerId),
      _safeDocumentId(providerId),
      _safeDocumentId(serviceId),
      startAt.millisecondsSinceEpoch.toString(),
    ].join('_');
  }

  static String _safeDocumentId(String value) {
    return value.replaceAll(RegExp(r'[/#?\[\]*]'), '_');
  }
}

class _BookingLockRefs {
  const _BookingLockRefs({
    required this.providerLockRef,
    required this.duplicateLockRef,
  });

  final DocumentReference<Map<String, dynamic>>? providerLockRef;
  final DocumentReference<Map<String, dynamic>>? duplicateLockRef;
}

class _ExistingBookingRange {
  const _ExistingBookingRange({required this.startAt, required this.endAt});

  final DateTime startAt;
  final DateTime endAt;
}

class BookingConfirmationResult {
  const BookingConfirmationResult({
    required this.bookingId,
    required this.paymentId,
    required this.paymentStatus,
    required this.totalAmount,
  });

  final String bookingId;
  final String paymentId;
  final String paymentStatus;
  final double totalAmount;
}
