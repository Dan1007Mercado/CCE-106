import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/validators.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/job_post_model.dart';
import '../models/service_listing_model.dart';

class CustomerService {
  CustomerService({FirebaseFirestore? firestore, FirebaseAuth? firebaseAuth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  static const Duration profileEditCooldown = Duration(hours: 24);

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _servicesCollection =>
      _firestore.collection('services');

  CollectionReference<Map<String, dynamic>> get _jobsCollection =>
      _firestore.collection('jobs');

  CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _firestore.collection('bookings');

  Stream<List<ServiceListingModel>> streamServices({
    String? category,
    double? minRating,
  }) {
    return _servicesCollection.snapshots().map((snapshot) {
      final services =
          snapshot.docs
              .map((doc) => ServiceListingModel.fromMap(doc.data(), doc.id))
              .where(
                (service) =>
                    _matchesCategory(service.category, category) &&
                    (minRating == null || service.rating >= minRating),
              )
              .toList()
            ..sort((a, b) {
              final ratingCompare = b.rating.compareTo(a.rating);
              if (ratingCompare != 0) {
                return ratingCompare;
              }
              return b.createdAt.compareTo(a.createdAt);
            });

      return services;
    });
  }

  Stream<List<JobPostModel>> streamJobs({String? category}) {
    return _jobsCollection.snapshots().map((snapshot) {
      final jobs =
          snapshot.docs
              .map((doc) => JobPostModel.fromMap(doc.data(), doc.id))
              .where((job) => _matchesCategory(job.category, category))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return jobs;
    });
  }

  Future<void> createJob({
    required UserModel customer,
    required String title,
    required String description,
    required String category,
    required String location,
    double? ratingFilter,
  }) async {
    await _jobsCollection.add({
      'customerId': customer.uid,
      'customerName': customer.displayName,
      'category': category,
      'title': title.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'ratingFilter': ratingFilter,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }

  Future<void> createBooking({
    required UserModel customer,
    required ServiceListingModel service,
  }) async {
    if (!customer.hasContactNumber) {
      throw Exception('Add your Philippine mobile number before booking.');
    }

    if (!customer.hasBookingLocation) {
      throw Exception(
        'Capture your current GPS location before booking this service.',
      );
    }

    final bookingRef = _bookingsCollection.doc();

    await bookingRef.set({
      'bookingId': bookingRef.id,
      'customerId': customer.uid,
      'customerName': customer.displayName,
      'customerPhone': customer.phone,
      'customerLocation': customer.locationLabel,
      'customerLatitude': customer.latitude,
      'customerLongitude': customer.longitude,
      'serviceId': service.serviceId,
      'providerId': service.providerId,
      'serviceTitle': service.title,
      'category': service.category,
      'price': service.price,
      'selectedDate': null,
      'selectedTimeSlot': '',
      'notes': '',
      'status': 'pending',
      'paymentStatus': 'unpaid',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<UserModel> updateCustomerProfile({
    required UserModel currentUser,
    required String firstName,
    required String lastName,
    required String phone,
    required String address,
    required double? latitude,
    required double? longitude,
    required String profilePic,
    String middleName = '',
    String suffix = '',
    UserPermissionStatus? photosPermission,
    UserPermissionStatus? locationPermission,
  }) async {
    final snapshot = await _usersCollection.doc(currentUser.uid).get();
    final lastUpdated = _readDateTime(
      snapshot.data()?['profileUpdatedAt'] ?? currentUser.profileUpdatedAt,
    );

    if (lastUpdated != null) {
      final nextAllowed = lastUpdated.add(profileEditCooldown);
      if (DateTime.now().isBefore(nextAllowed)) {
        throw Exception(
          'Profile edits are on cooldown until ${_formatDateTime(nextAllowed)}.',
        );
      }
    }

    final phoneError = Validators.phone(phone);
    if (phoneError != null) {
      throw Exception(phoneError);
    }

    final now = DateTime.now();
    final updatedUser = currentUser.copyWith(
      firstName: firstName.trim(),
      middleName: middleName.trim(),
      lastName: lastName.trim(),
      suffix: suffix.trim(),
      phone: phone.trim(),
      address: address.trim(),
      latitude: latitude,
      longitude: longitude,
      profilePic: profilePic.trim(),
      photosPermission: photosPermission ?? currentUser.photosPermission,
      locationPermission: locationPermission ?? currentUser.locationPermission,
      profileUpdatedAt: now,
    );

    await _usersCollection.doc(currentUser.uid).set({
      ...updatedUser.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'profileUpdatedAt': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    final authUser = _firebaseAuth.currentUser;
    if (authUser != null && authUser.uid == currentUser.uid) {
      await authUser.updateDisplayName(updatedUser.displayName);
    }

    return updatedUser;
  }

  Future<UserModel> updateUserPreferences({
    required UserModel currentUser,
    AppThemePreference? themeMode,
    UserPermissionStatus? photosPermission,
    UserPermissionStatus? notificationsPermission,
    UserPermissionStatus? locationPermission,
  }) async {
    final updatedUser = currentUser.copyWith(
      themeMode: themeMode ?? currentUser.themeMode,
      photosPermission: photosPermission ?? currentUser.photosPermission,
      notificationsPermission:
          notificationsPermission ?? currentUser.notificationsPermission,
      locationPermission: locationPermission ?? currentUser.locationPermission,
    );

    await _usersCollection.doc(currentUser.uid).set({
      ...updatedUser.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return updatedUser;
  }

  bool _matchesCategory(String source, String? selectedCategory) {
    if (selectedCategory == null || selectedCategory == 'All') {
      return true;
    }

    return source.trim().toLowerCase() == selectedCategory.trim().toLowerCase();
  }

  DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    final toDate = (value as dynamic).toDate;
    if (toDate is Function) {
      final result = toDate();
      if (result is DateTime) {
        return result;
      }
    }

    return null;
  }

  String _formatDateTime(DateTime value) {
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.month}/${value.day}/${value.year} ${value.hour}:$minute';
  }
}
