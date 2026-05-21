import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/utils/validators.dart';
import '../../../auth/data/models/user_model.dart';
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

  Future<BookingConfirmationResult> createBookingWithMockPayment({
    required UserModel customer,
    required ServiceListingModel service,
    required DateTime selectedDate,
    required String selectedTimeSlot,
    required String serviceAddress,
    required String notes,
    required String paymentMethod,
  }) async {
    final phoneError = Validators.phone(customer.phone);
    if (phoneError != null) {
      throw Exception(phoneError);
    }

    if (!customer.hasBookingLocation) {
      throw Exception(
        'Capture your current GPS location before booking this service.',
      );
    }

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
    final commissionAmount = service.price * platformCommissionRate;
    final totalAmount = service.price + commissionAmount;
    final isCashPayment = paymentMethod.toLowerCase().contains('cash');
    final paymentStatus = isCashPayment ? 'pending' : 'paid';
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
      'serviceTitle': service.title,
      'category': service.category,
      'price': service.price,
      'selectedDate': Timestamp.fromDate(bookingDate),
      'selectedTimeSlot': selectedTimeSlot.trim(),
      'notes': notes.trim(),
      'status': 'pending',
      'paymentStatus': paymentStatus,
      'paymentId': paymentRef.id,
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
      'status': paymentStatus,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return BookingConfirmationResult(
      bookingId: bookingRef.id,
      paymentId: paymentRef.id,
      paymentStatus: paymentStatus,
      totalAmount: totalAmount,
    );
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
