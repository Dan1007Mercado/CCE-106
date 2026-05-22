import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/services/notification_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../models/provider_application_model.dart';

class ProviderApplicationSubmission {
  const ProviderApplicationSubmission({
    required this.fullName,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    required this.age,
    required this.birthDate,
    required this.gender,
    required this.phoneNumber,
    required this.email,
    required this.address,
    required this.city,
    required this.province,
    required this.validIdType,
    required this.validIdNumber,
    required this.validIdDetails,
    required this.skillCategory,
    required this.experienceYears,
    required this.serviceDescription,
    required this.previousWorkDescription,
    required this.serviceLocationCoverage,
    required this.expectedRate,
    required this.verificationConsentAccepted,
  });

  final String fullName;
  final String firstName;
  final String middleName;
  final String lastName;
  final String suffix;
  final int age;
  final DateTime? birthDate;
  final String gender;
  final String phoneNumber;
  final String email;
  final String address;
  final String city;
  final String province;
  final String validIdType;
  final String validIdNumber;
  final String validIdDetails;
  final String skillCategory;
  final int experienceYears;
  final String serviceDescription;
  final String previousWorkDescription;
  final String serviceLocationCoverage;
  final double? expectedRate;
  final bool verificationConsentAccepted;
}

class ProviderApplicationService {
  ProviderApplicationService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notificationService = notificationService ?? NotificationService();

  static const String dataPrivacyNoticeVersion = 'provider_verification_v1';

  final FirebaseFirestore _firestore;
  final NotificationService _notificationService;

  CollectionReference<Map<String, dynamic>> get _applicationsCollection =>
      _firestore.collection('providerApplications');

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  Stream<ProviderApplicationModel?> streamLatestForProvider(String providerId) {
    return _applicationsCollection.doc(providerId).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        return null;
      }

      return ProviderApplicationModel.fromMap(data, snapshot.id);
    });
  }

  Future<void> submitApplication({
    required UserModel provider,
    required ProviderApplicationSubmission submission,
  }) async {
    if (provider.role != AppUserRole.service) {
      throw Exception('Only service providers can apply for verification.');
    }

    _validateSubmission(submission);

    final applicationRef = _applicationsCollection.doc(provider.uid);
    final userRef = _usersCollection.doc(provider.uid);
    final validIdNumber = submission.validIdNumber.trim();
    final applicationData = {
      'applicationId': applicationRef.id,
      'providerId': provider.uid,
      'providerName': provider.displayName,
      'providerEmail': provider.email,
      'providerPhone': provider.phone.trim(),
      'fullName': submission.fullName.trim(),
      'firstName': submission.firstName.trim(),
      'middleName': submission.middleName.trim(),
      'lastName': submission.lastName.trim(),
      'suffix': submission.suffix.trim(),
      'age': submission.age,
      'birthDate': submission.birthDate == null
          ? null
          : Timestamp.fromDate(submission.birthDate!),
      'gender': submission.gender.trim(),
      'phoneNumber': submission.phoneNumber.trim(),
      'email': submission.email.trim(),
      'address': submission.address.trim(),
      'city': submission.city.trim(),
      'province': submission.province.trim(),
      'validIdType': submission.validIdType.trim(),
      'validIdNumber': validIdNumber,
      'validIdDetails': submission.validIdDetails.trim(),
      'maskedValidIdNumber': maskValidIdNumber(validIdNumber),
      'skillCategory': submission.skillCategory.trim(),
      'experienceYears': submission.experienceYears,
      'serviceDescription': submission.serviceDescription.trim(),
      'previousWorkDescription': submission.previousWorkDescription.trim(),
      'serviceLocationCoverage': submission.serviceLocationCoverage.trim(),
      'expectedRate': submission.expectedRate,
      'verificationConsentAccepted': true,
      'verificationConsentAcceptedAt': FieldValue.serverTimestamp(),
      'dataPrivacyNoticeVersion': dataPrivacyNoticeVersion,
      'status': 'pending',
      'adminRemarks': '',
      'reviewedBy': '',
      'reviewedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.runTransaction((transaction) async {
      final existingApplication = await transaction.get(applicationRef);
      transaction.set(applicationRef, {
        ...applicationData,
        if (!existingApplication.exists)
          'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(userRef, {
        'providerVerificationStatus': 'pending',
        'verifiedProvider': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await _notificationService.create(
      roleTarget: 'admin',
      title: 'New provider application',
      body: '${provider.displayName} submitted a provider verification request',
      type: 'provider_application_submitted',
      relatedId: applicationRef.id,
    );
  }

  void _validateSubmission(ProviderApplicationSubmission submission) {
    if (submission.fullName.trim().isEmpty) {
      throw Exception('Full name is required.');
    }

    if (submission.firstName.trim().isEmpty ||
        submission.lastName.trim().isEmpty) {
      throw Exception('First name and last name are required.');
    }

    if (submission.age < 18) {
      throw Exception('Service providers must be at least 18 years old.');
    }

    if (submission.phoneNumber.trim().isEmpty) {
      throw Exception('Phone number is required.');
    }

    if (submission.email.trim().isEmpty) {
      throw Exception('Email is required.');
    }

    if (submission.address.trim().isEmpty) {
      throw Exception('Address is required.');
    }

    if (submission.city.trim().isEmpty || submission.province.trim().isEmpty) {
      throw Exception('City and province are required.');
    }

    if (submission.validIdType.trim().isEmpty) {
      throw Exception('Valid ID type is required.');
    }

    if (submission.validIdNumber.trim().isEmpty) {
      throw Exception('Valid ID number is required.');
    }

    if (submission.skillCategory.trim().isEmpty) {
      throw Exception('Skill category is required.');
    }

    if (submission.experienceYears < 0) {
      throw Exception('Experience years must be 0 or higher.');
    }

    if (submission.serviceDescription.trim().isEmpty) {
      throw Exception('Service description is required.');
    }

    if (submission.serviceLocationCoverage.trim().isEmpty) {
      throw Exception('Service coverage area is required.');
    }

    if (submission.expectedRate != null && submission.expectedRate! < 0) {
      throw Exception('Expected rate must be 0 or higher.');
    }

    if (!submission.verificationConsentAccepted) {
      throw Exception('Accept the data collection consent before submitting.');
    }
  }
}
