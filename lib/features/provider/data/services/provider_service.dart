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

  CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _paymentsCollection =>
      _firestore.collection('payments');

  CollectionReference<Map<String, dynamic>> get _availabilityCollection =>
      _firestore.collection('providerAvailability');

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

  Future<void> updateBookingStatus({
    required String bookingId,
    required String status,
  }) async {
    await _bookingsCollection.doc(bookingId).set({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
}
