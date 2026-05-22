import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/data/models/user_model.dart';
import '../../../customer/data/models/service_listing_model.dart';
import '../models/provider_availability_slot_model.dart';
import '../models/provider_booking_model.dart';

class ProviderService {
  ProviderService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _servicesCollection =>
      _firestore.collection('services');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _paymentsCollection =>
      _firestore.collection('payments');

  CollectionReference<Map<String, dynamic>> get _availabilityCollection =>
      _firestore.collection('providerAvailability');

  CollectionReference<Map<String, dynamic>> get _providerScheduleLocks =>
      _firestore.collection('providerScheduleLocks');

  CollectionReference<Map<String, dynamic>> get _customerBookingLocks =>
      _firestore.collection('customerBookingLocks');

  static const Set<String> _activeBookingStatuses = {'pending', 'accepted'};

  Stream<List<ServiceListingModel>> streamProviderServices(String providerId) {
    return _servicesCollection
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
          final services =
              snapshot.docs
                  .map((doc) => ServiceListingModel.fromMap(doc.data(), doc.id))
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return services;
        });
  }

  Stream<List<ProviderBookingModel>> streamProviderBookings(String providerId) {
    return _bookingsCollection
        .where('providerId', isEqualTo: providerId)
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

  Stream<List<ProviderPaymentModel>> streamProviderPayments(String providerId) {
    return _paymentsCollection
        .where('providerId', isEqualTo: providerId)
        .snapshots()
        .map((snapshot) {
          final payments =
              snapshot.docs
                  .map(
                    (doc) => ProviderPaymentModel.fromMap(doc.data(), doc.id),
                  )
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return payments;
        });
  }

  Stream<List<ProviderAvailabilitySlotModel>> streamAvailabilitySlots(
    String providerId,
  ) {
    return _availabilityCollection
        .doc(providerId)
        .collection('slots')
        .snapshots()
        .map((snapshot) {
          final slots =
              snapshot.docs
                  .map(
                    (doc) => ProviderAvailabilitySlotModel.fromMap(
                      doc.data(),
                      doc.id,
                    ),
                  )
                  .toList()
                ..sort((a, b) {
                  final dateCompare = a.dateLabel.compareTo(b.dateLabel);
                  if (dateCompare != 0) {
                    return dateCompare;
                  }
                  return a.timeSlot.compareTo(b.timeSlot);
                });

          return slots;
        });
  }

  Future<void> addServiceListing({
    required UserModel provider,
    required String title,
    required String category,
    required String description,
    required String location,
    required double price,
  }) async {
    if (provider.role != AppUserRole.service) {
      throw Exception('Only service providers can publish service listings.');
    }

    await _assertProviderApproved(
      provider.uid,
      fallbackStatus: provider.providerVerificationStatus,
      fallbackVerified: provider.verifiedProvider,
    );

    if (title.trim().isEmpty ||
        category.trim().isEmpty ||
        description.trim().isEmpty ||
        location.trim().isEmpty) {
      throw Exception('Complete all listing fields before saving.');
    }

    if (price <= 0) {
      throw Exception('Enter a valid service price.');
    }

    final doc = _servicesCollection.doc();
    await doc.set({
      'serviceId': doc.id,
      'providerId': provider.uid,
      'providerName': provider.displayName,
      'providerPhone': provider.phone.trim(),
      'providerVerificationStatus': 'approved',
      'category': category.trim(),
      'title': title.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'price': price,
      'rating': 0,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateServiceListing({
    required String serviceId,
    required String providerId,
    required String title,
    required String category,
    required String description,
    required String location,
    required double price,
  }) async {
    await _assertProviderApproved(providerId);
    final doc = await _servicesCollection.doc(serviceId).get();
    final service = doc.data();
    if (!doc.exists || service == null) {
      throw Exception('Service listing not found.');
    }

    if (service['providerId'] != providerId) {
      throw Exception('You can only edit your own services.');
    }

    if (title.trim().isEmpty ||
        category.trim().isEmpty ||
        description.trim().isEmpty ||
        location.trim().isEmpty) {
      throw Exception('Complete all listing fields before saving.');
    }

    if (price <= 0) {
      throw Exception('Enter a valid service price.');
    }

    await doc.reference.set({
      'title': title.trim(),
      'category': category.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'price': price,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setServiceActive({
    required String serviceId,
    required String providerId,
    required bool isActive,
  }) async {
    final doc = await _servicesCollection.doc(serviceId).get();
    final service = doc.data();
    if (!doc.exists || service == null) {
      throw Exception('Service listing not found.');
    }

    if (service['providerId'] != providerId) {
      throw Exception('You can only update your own services.');
    }

    if (isActive) {
      await _assertProviderApproved(providerId);
    }

    await doc.reference.set({
      'status': isActive ? 'active' : 'inactive',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteServiceListing({
    required String serviceId,
    required String providerId,
  }) async {
    final doc = await _servicesCollection.doc(serviceId).get();
    final service = doc.data();
    if (!doc.exists || service == null) {
      throw Exception('Service listing not found.');
    }

    if (service['providerId'] != providerId) {
      throw Exception('You can only delete your own services.');
    }

    await doc.reference.delete();
  }

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    final bookingRef = _bookingsCollection.doc(bookingId);

    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);

      if (!bookingSnapshot.exists) {
        throw Exception('Booking not found.');
      }

      final booking = bookingSnapshot.data();
      if (booking == null) {
        throw Exception('Booking not found.');
      }

      final lockRefs = _resolveLockRefs(booking);
      final providerLockSnapshot = lockRefs.providerLockRef == null
          ? null
          : await transaction.get(lockRefs.providerLockRef!);
      final duplicateLockSnapshot = lockRefs.duplicateLockRef == null
          ? null
          : await transaction.get(lockRefs.duplicateLockRef!);
      final normalizedStatus = status.trim();
      if (normalizedStatus == 'accepted') {
        final providerId = booking['providerId'] as String? ?? '';
        if (providerId.isEmpty) {
          throw Exception('Provider record not found.');
        }
        final providerSnapshot = await transaction.get(
          _usersCollection.doc(providerId),
        );
        _assertProviderApprovedFromData(
          providerSnapshot.data(),
          blockedMessage: 'Only approved providers can accept bookings.',
        );
      }

      transaction.set(bookingRef, {
        'status': normalizedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (_activeBookingStatuses.contains(normalizedStatus)) {
        _updateBookingLocksStatus(
          transaction: transaction,
          bookingId: bookingId,
          providerLockRef: lockRefs.providerLockRef,
          providerLockData: providerLockSnapshot?.data(),
          duplicateLockRef: lockRefs.duplicateLockRef,
          duplicateLockExists: duplicateLockSnapshot?.exists ?? false,
          status: normalizedStatus,
        );
      } else {
        _releaseBookingLocks(
          transaction: transaction,
          bookingId: bookingId,
          providerLockRef: lockRefs.providerLockRef,
          providerLockData: providerLockSnapshot?.data(),
          duplicateLockRef: lockRefs.duplicateLockRef,
          duplicateLockExists: duplicateLockSnapshot?.exists ?? false,
          releasedStatus: normalizedStatus,
        );
      }
    });
  }

  Future<void> markBookingAsDone({
    required String bookingId,
    required String providerId,
  }) async {
    final bookingRef = _bookingsCollection.doc(bookingId);

    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);

      if (!bookingSnapshot.exists) {
        throw Exception('Booking not found.');
      }

      final booking = bookingSnapshot.data();
      if (booking == null || booking['providerId'] != providerId) {
        throw Exception('You can only complete your own booking.');
      }

      final providerSnapshot = await transaction.get(
        _usersCollection.doc(providerId),
      );
      _assertProviderApprovedFromData(providerSnapshot.data());

      final paymentId = booking['paymentId'] as String?;
      if (paymentId == null || paymentId.isEmpty) {
        throw Exception('Payment record not found.');
      }

      final paymentRef = _paymentsCollection.doc(paymentId);
      final paymentSnapshot = await transaction.get(paymentRef);
      if (!paymentSnapshot.exists) {
        throw Exception('Payment record not found.');
      }

      final lockRefs = _resolveLockRefs(booking);
      final providerLockSnapshot = lockRefs.providerLockRef == null
          ? null
          : await transaction.get(lockRefs.providerLockRef!);
      final duplicateLockSnapshot = lockRefs.duplicateLockRef == null
          ? null
          : await transaction.get(lockRefs.duplicateLockRef!);

      transaction.update(bookingRef, {
        'status': 'completed',
        'paymentStatus': 'paid',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(paymentRef, {
        'status': 'paid',
        'isReleasedToProvider': true,
        'releasedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _releaseBookingLocks(
        transaction: transaction,
        bookingId: bookingId,
        providerLockRef: lockRefs.providerLockRef,
        providerLockData: providerLockSnapshot?.data(),
        duplicateLockRef: lockRefs.duplicateLockRef,
        duplicateLockExists: duplicateLockSnapshot?.exists ?? false,
        releasedStatus: 'completed',
      );
    });
  }

  Future<void> addAvailabilitySlot({
    required String providerId,
    required String dateLabel,
    required String timeSlot,
  }) async {
    if (dateLabel.trim().isEmpty || timeSlot.trim().isEmpty) {
      throw Exception('Enter the date and time slot.');
    }

    final doc = _availabilityCollection
        .doc(providerId)
        .collection('slots')
        .doc();

    await doc.set({
      'slotId': doc.id,
      'providerId': providerId,
      'dateLabel': dateLabel.trim(),
      'timeSlot': timeSlot.trim(),
      'status': 'available',
      'createdAt': FieldValue.serverTimestamp(),
    });
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

  void _updateBookingLocksStatus({
    required Transaction transaction,
    required String bookingId,
    required DocumentReference<Map<String, dynamic>>? providerLockRef,
    required Map<String, dynamic>? providerLockData,
    required DocumentReference<Map<String, dynamic>>? duplicateLockRef,
    required bool duplicateLockExists,
    required String status,
  }) {
    if (providerLockRef != null && providerLockData != null) {
      final providerBookings = _readLockBookings(providerLockData);
      final lockBooking = providerBookings[bookingId];
      if (lockBooking != null) {
        lockBooking['status'] = status;
        providerBookings[bookingId] = lockBooking;
        transaction.set(providerLockRef, {
          'bookings': providerBookings,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    if (duplicateLockRef != null && duplicateLockExists) {
      transaction.set(duplicateLockRef, {
        'active': true,
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
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

  static String _providerScheduleLockId(String providerId, DateTime startAt) {
    return '${_safeDocumentId(providerId)}_${_dateKey(startAt)}';
  }

  static String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}$month$day';
  }

  static String _safeDocumentId(String value) {
    return value.replaceAll(RegExp(r'[/#?\[\]*]'), '_');
  }

  Future<void> _assertProviderApproved(
    String providerId, {
    String? fallbackStatus,
    bool? fallbackVerified,
    String? blockedMessage,
  }) async {
    final snapshot = await _usersCollection.doc(providerId).get();
    final data = snapshot.data();
    _assertProviderApprovedFromData(
      data,
      fallbackStatus: fallbackStatus,
      fallbackVerified: fallbackVerified,
      blockedMessage: blockedMessage,
    );
  }

  static void _assertProviderApprovedFromData(
    Map<String, dynamic>? data, {
    String? fallbackStatus,
    bool? fallbackVerified,
    String? blockedMessage,
  }) {
    final status =
        data?['providerVerificationStatus'] as String? ??
        fallbackStatus ??
        (data?['verifiedProvider'] == true ? 'approved' : 'no_application');
    final verified = data?['verifiedProvider'] as bool? ?? fallbackVerified;
    final normalizedStatus = status.trim().toLowerCase();

    if (verified == true && normalizedStatus == 'approved') {
      return;
    }

    if (blockedMessage != null) {
      throw Exception(blockedMessage);
    }

    throw Exception(_verificationMessage(normalizedStatus));
  }

  static String _verificationMessage(String status) {
    return switch (status) {
      'pending' => 'Your application is still pending Super Admin approval.',
      'rejected' =>
        'Your provider application was rejected. Please review the admin remarks and resubmit.',
      _ =>
        'Submit a provider verification application before posting services or accepting bookings.',
    };
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
