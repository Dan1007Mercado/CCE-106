import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_dashboard_models.dart';

class AdminService {
  AdminService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _applicationsCollection =>
      _firestore.collection('providerApplications');

  CollectionReference<Map<String, dynamic>> get _paymentsCollection =>
      _firestore.collection('payments');

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

  Future<void> setUserSuspended({
    required String uid,
    required bool suspended,
  }) async {
    await _usersCollection.doc(uid).set({
      'status': suspended ? 'suspended' : 'active',
      'isSuspended': suspended,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reviewProviderApplication({
    required String applicationId,
    required String status,
    String adminRemarks = '',
  }) async {
    await _applicationsCollection.doc(applicationId).set({
      'applicationId': applicationId,
      'status': status,
      'adminRemarks': adminRemarks.trim(),
      'reviewedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveTerms(String body) async {
    if (body.trim().isEmpty) {
      throw Exception('Terms and Conditions content cannot be empty.');
    }

    await _termsDocument.set({
      'termsId': 'terms',
      'body': body.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
