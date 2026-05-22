import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/services/notification_service.dart';
import '../../../customer/data/models/service_listing_model.dart';
import '../../../provider/data/models/provider_application_model.dart';
import '../../../provider/data/models/provider_booking_model.dart';
import '../models/admin_dashboard_models.dart';

class AdminService {
  AdminService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _applicationsCollection =>
      _firestore.collection('providerApplications');

  CollectionReference<Map<String, dynamic>> get _paymentsCollection =>
      _firestore.collection('payments');

  CollectionReference<Map<String, dynamic>> get _servicesCollection =>
      _firestore.collection('services');

  CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _firestore.collection('bookings');

  DocumentReference<Map<String, dynamic>> get _termsDocument =>
      _firestore.collection('platformConfig').doc('terms');

  Stream<List<AdminUserAccountModel>> streamUsers() {
    return _usersCollection.snapshots().map((snapshot) {
      final users =
          snapshot.docs
              .map((doc) => AdminUserAccountModel.fromMap(doc.data(), doc.id))
              .toList()
            ..sort((a, b) {
              final roleCompare = a.user.role.index.compareTo(
                b.user.role.index,
              );
              if (roleCompare != 0) {
                return roleCompare;
              }
              return a.user.displayName.compareTo(b.user.displayName);
            });

      return users;
    });
  }

  Stream<List<ProviderApplicationModel>> streamProviderApplications() {
    return _applicationsCollection.snapshots().map((snapshot) {
      final applications =
          snapshot.docs
              .map(
                (doc) => ProviderApplicationModel.fromMap(doc.data(), doc.id),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return applications;
    });
  }

  Stream<List<AdminPaymentModel>> streamPayments() {
    return _paymentsCollection.snapshots().map((snapshot) {
      final payments =
          snapshot.docs
              .map((doc) => AdminPaymentModel.fromMap(doc.data(), doc.id))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return payments;
    });
  }

  Stream<List<ServiceListingModel>> streamServices() {
    return _servicesCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ServiceListingModel.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Stream<List<ProviderBookingModel>> streamBookings() {
    return _bookingsCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ProviderBookingModel.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Stream<List<AppNotificationModel>> streamAdminNotifications() {
    return _notificationService.streamForRole('admin');
  }

  Stream<AdminTermsModel?> streamTerms() {
    return _termsDocument.snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }

      return AdminTermsModel.fromMap(data, snapshot.id);
    });
  }

  Future<void> setUserSuspended({
    required String uid,
    required bool suspended,
    String? currentAdminId,
  }) async {
    if (currentAdminId != null && currentAdminId == uid) {
      throw Exception('Admin cannot suspend their own admin account.');
    }

    await _usersCollection.doc(uid).set({
      'status': suspended ? 'suspended' : 'active',
      'isSuspended': suspended,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reviewProviderApplication({
    required String applicationId,
    required String status,
    required String reviewedBy,
    String adminRemarks = '',
  }) async {
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus != 'approved' && normalizedStatus != 'rejected') {
      throw Exception('Choose approve or reject.');
    }

    final applicationRef = _applicationsCollection.doc(applicationId);
    final applicationSnapshot = await applicationRef.get();
    final application = applicationSnapshot.data();
    if (!applicationSnapshot.exists || application == null) {
      throw Exception('Provider application not found.');
    }

    final providerId = application['providerId'] as String? ?? '';
    if (providerId.isEmpty) {
      throw Exception('Provider record not found.');
    }

    final userRef = _usersCollection.doc(providerId);
    await _firestore.runTransaction((transaction) async {
      transaction.set(applicationRef, {
        'applicationId': applicationId,
        'status': normalizedStatus,
        'adminRemarks': adminRemarks.trim(),
        'reviewedBy': reviewedBy,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(userRef, {
        'providerVerificationStatus': normalizedStatus,
        'verifiedProvider': normalizedStatus == 'approved',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await _notificationService.create(
      userId: providerId,
      title: normalizedStatus == 'approved'
          ? 'Application approved'
          : 'Application rejected',
      body: normalizedStatus == 'approved'
          ? 'Your provider verification application has been approved.'
          : 'Your provider verification application was rejected. Please review the admin remarks.',
      type: normalizedStatus == 'approved'
          ? 'provider_application_approved'
          : 'provider_application_rejected',
      relatedId: applicationId,
    );
  }

  Future<void> saveTerms(String body) async {
    if (body.trim().isEmpty) {
      throw Exception('Terms and Conditions content cannot be empty.');
    }

    await _termsDocument.set({
      'termsId': 'terms',
      'body': body.trim(),
      'version': DateTime.now().millisecondsSinceEpoch.toString(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
