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
    return streamOpenJobsForProviders(category: category);
  }

  Stream<List<JobPostModel>> streamCustomerJobs(String customerId) {
    return _jobsCollection
        .where('customerId', isEqualTo: customerId)
        .snapshots()
        .map((snapshot) => _readSortedJobs(snapshot.docs));
  }

  Stream<List<JobPostModel>> streamOpenJobsForProviders({
    String? category,
    List<String>? categories,
    double? minRating,
    String? excludeCustomerId,
  }) {
    final effectiveCategories = _resolveCategories(
      category: category,
      categories: categories,
    );

    Query<Map<String, dynamic>> query = _jobsCollection.where(
      'status',
      isEqualTo: 'open',
    );

    if (effectiveCategories.length == 1) {
      query = query.where('category', isEqualTo: effectiveCategories.single);
    } else if (effectiveCategories.length > 1 &&
        effectiveCategories.length <= 10) {
      // Firestore whereIn supports up to 10 values; larger lists are filtered
      // after the open-job query instead of requiring extra composite indexes.
      query = query.where('category', whereIn: effectiveCategories);
    }

    return query.snapshots().map((snapshot) {
      final jobs = _readSortedJobs(snapshot.docs).where((job) {
        final matchesCategory =
            effectiveCategories.isEmpty ||
            effectiveCategories.length <= 10 ||
            effectiveCategories.any(
              (category) => _matchesCategory(job.category, category),
            );
        final matchesRating =
            minRating == null ||
            job.ratingFilter == null ||
            job.ratingFilter! <= minRating;
        final isNotOwnJob =
            excludeCustomerId == null || job.customerId != excludeCustomerId;

        return job.status == 'open' &&
            matchesCategory &&
            matchesRating &&
            isNotOwnJob;
      }).toList();

      return jobs;
    });
  }

  Future<void> createJob({
    required UserModel customer,
    required String title,
    required String description,
    required String category,
    required String location,
    required double budget,
    required String difficulty,
    double? ratingFilter,
    String photoUrl = '',
  }) async {
    if (budget <= 0) {
      throw Exception('Enter a valid budget.');
    }

    await _jobsCollection.add({
      'customerId': customer.uid,
      'customerName': customer.displayName,
      'category': category,
      'title': title.trim(),
      'description': description.trim(),
      'location': location.trim(),
      'budget': budget,
      'difficulty': difficulty.trim().isEmpty ? 'Moderate' : difficulty.trim(),
      'photoUrl': photoUrl.trim(),
      'ratingFilter': ratingFilter,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'open',
    });
  }

  Future<void> updateJob({
    required String jobId,
    required String currentUserId,
    required String title,
    required String description,
    required String category,
    required String location,
    required double budget,
    required String difficulty,
    double? ratingFilter,
    String? photoUrl,
  }) async {
    final doc = await _jobsCollection.doc(jobId).get();

    if (!doc.exists) {
      throw Exception('Job post not found.');
    }

    final data = doc.data();
    if (data == null || data['customerId'] != currentUserId) {
      throw Exception('You can only edit your own job post.');
    }

    if (budget <= 0) {
      throw Exception('Enter a valid budget.');
    }

    await _jobsCollection.doc(jobId).update({
      'title': title.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'location': location.trim(),
      'budget': budget,
      'difficulty': difficulty.trim().isEmpty ? 'Moderate' : difficulty.trim(),
      'ratingFilter': ratingFilter,
      if (photoUrl != null) 'photoUrl': photoUrl.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteJob({
    required String jobId,
    required String currentUserId,
  }) async {
    final doc = await _jobsCollection.doc(jobId).get();

    if (!doc.exists) {
      throw Exception('Job post not found.');
    }

    final data = doc.data();
    if (data == null || data['customerId'] != currentUserId) {
      throw Exception('You can only delete your own job post.');
    }

    await _jobsCollection.doc(jobId).delete();
  }

  Future<void> createBooking({
    required UserModel customer,
    required ServiceListingModel service,
  }) async {
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
      'providerName': service.providerName,
      'providerPhone': service.providerPhone.trim(),
      'serviceTitle': service.title,
      'category': service.category,
      'price': service.price,
      'totalAmount': service.price,
      'selectedDate': null,
      'selectedTimeSlot': '',
      'serviceAddress': customer.locationLabel,
      'notes': '',
      'status': 'pending',
      'paymentStatus': 'pending',
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
    final resolvedAddress = _resolveLocationAddress(
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    final updatedUser = currentUser.copyWith(
      firstName: firstName.trim(),
      middleName: middleName.trim(),
      lastName: lastName.trim(),
      suffix: suffix.trim(),
      phone: phone.trim(),
      address: resolvedAddress,
      latitude: latitude,
      longitude: longitude,
      clearCoordinates: latitude == null || longitude == null,
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

  List<JobPostModel> _readSortedJobs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) => JobPostModel.fromMap(doc.data(), doc.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<String> _resolveCategories({
    String? category,
    List<String>? categories,
  }) {
    final selected = <String>[?category, ...?categories];
    final seen = <String>{};
    final normalized = <String>[];

    for (final value in selected) {
      final cleaned = value.trim();
      final key = cleaned.toLowerCase();
      if (cleaned.isEmpty || key == 'all' || seen.contains(key)) {
        continue;
      }

      seen.add(key);
      normalized.add(cleaned);
    }

    return normalized;
  }

  String _resolveLocationAddress({
    required String address,
    required double? latitude,
    required double? longitude,
  }) {
    final cleaned = address.trim();
    if (cleaned.isNotEmpty) {
      return cleaned;
    }

    if (latitude != null && longitude != null) {
      return 'Location captured, address unavailable';
    }

    return '';
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
