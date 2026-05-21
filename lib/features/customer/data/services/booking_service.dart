import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../auth/data/models/user_model.dart';
import '../../../provider/data/models/provider_booking_model.dart';
import '../models/service_listing_model.dart';

class BookingService {
  BookingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const double platformCommissionRate = 0.10;

  CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _paymentsCollection =>
      _firestore.collection('payments');

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

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

  Future<BookingConfirmationResult> createBookingWithMockPayment({
    required UserModel customer,
    required ServiceListingModel service,
    required DateTime selectedDate,
    required String selectedTimeSlot,
    required String serviceAddress,
    required String notes,
    required String paymentMethod,
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

    final bookingRef = _bookingsCollection.doc();
    final paymentRef = _paymentsCollection.doc();
    final chatRef = _chatsCollection.doc(bookingRef.id);
    final commissionAmount = service.price * platformCommissionRate;
    final totalAmount = service.price + commissionAmount;
    final isCashPayment = paymentMethod.toLowerCase().contains('cash');
    final paymentProvider = isCashPayment
        ? 'cash_on_service'
        : 'mock_test_gateway';

    final batch = _firestore.batch();
    final bookingDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    batch.set(bookingRef, {
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
      'notes': notes.trim(),
      'status': 'pending',
      'paymentStatus': 'pending',
      'paymentId': paymentRef.id,
      'completedAt': null,
      'cancelledAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(paymentRef, {
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

    batch.set(chatRef, {
      'chatId': bookingRef.id,
      'bookingId': bookingRef.id,
      'customerId': customer.uid,
      'providerId': service.providerId,
      'customerName': customer.displayName,
      'providerName': service.providerName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

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
    final bookingSnapshot = await bookingRef.get();

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
    final paymentSnapshot = await paymentRef.get();
    final payment = paymentSnapshot.data();

    final totalAmount = _readDouble(payment?['amount']);
    final providerCancellationFee = totalAmount * 0.03;
    final platformCancellationFee = totalAmount * 0.01;
    final refundAmount =
        totalAmount - providerCancellationFee - platformCancellationFee;

    final batch = _firestore.batch();

    batch.update(bookingRef, {
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

    batch.update(paymentRef, {
      'status': 'cancelled_fee_charged',
      'providerCancellationFee': providerCancellationFee,
      'platformCancellationFee': platformCancellationFee,
      'refundAmount': refundAmount,
      'isReleasedToProvider': false,
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
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
