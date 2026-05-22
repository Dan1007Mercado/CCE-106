import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
    required this.skillCategory,
    required this.experienceYears,
    required this.serviceDescription,
    required this.previousWorkDescription,
    required this.serviceLocationCoverage,
    required this.expectedRate,
    required this.validIdFront,
    required this.validIdBack,
    required this.selfieWithId,
    required this.existingValidIdFrontUrl,
    required this.existingValidIdBackUrl,
    required this.existingSelfieWithIdUrl,
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
  final String skillCategory;
  final int experienceYears;
  final String serviceDescription;
  final String previousWorkDescription;
  final String serviceLocationCoverage;
  final double? expectedRate;
  final XFile? validIdFront;
  final XFile? validIdBack;
  final XFile? selfieWithId;
  final String existingValidIdFrontUrl;
  final String existingValidIdBackUrl;
  final String existingSelfieWithIdUrl;
}

class ProviderApplicationService {
  ProviderApplicationService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ImagePicker? imagePicker,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _imagePicker = imagePicker ?? ImagePicker(),
       _notificationService = notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _imagePicker;
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

  Future<XFile?> pickImage({required ImageSource source}) async {
    try {
      return _imagePicker.pickImage(
        source: source,
        imageQuality: 86,
        maxWidth: 1800,
      );
    } catch (_) {
      throw Exception('We could not open the selected image source.');
    }
  }

  Future<void> submitApplication({
    required UserModel provider,
    required ProviderApplicationSubmission submission,
  }) async {
    if (provider.role != AppUserRole.service) {
      throw Exception('Only service providers can apply for verification.');
    }

    _validateSubmission(submission);

    // Valid ID files contain private identity data. Firestore and Storage
    // security rules must restrict these URLs/paths to the provider owner and
    // Super Admin reviewers only.
    final validIdFrontUrl = submission.validIdFront == null
        ? submission.existingValidIdFrontUrl.trim()
        : await _uploadApplicationImage(
            providerId: provider.uid,
            image: submission.validIdFront!,
            fileName: 'valid_id_front.jpg',
          );
    final validIdBackUrl = submission.validIdBack == null
        ? submission.existingValidIdBackUrl.trim()
        : await _uploadApplicationImage(
            providerId: provider.uid,
            image: submission.validIdBack!,
            fileName: 'valid_id_back.jpg',
          );
    final selfieWithIdUrl = submission.selfieWithId == null
        ? submission.existingSelfieWithIdUrl.trim()
        : await _uploadApplicationImage(
            providerId: provider.uid,
            image: submission.selfieWithId!,
            fileName: 'selfie_with_id.jpg',
          );

    if (validIdFrontUrl.isEmpty) {
      throw Exception('Please upload at least one valid ID photo.');
    }

    final applicationRef = _applicationsCollection.doc(provider.uid);
    final userRef = _usersCollection.doc(provider.uid);
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
      'skillCategory': submission.skillCategory.trim(),
      'experienceYears': submission.experienceYears,
      'serviceDescription': submission.serviceDescription.trim(),
      'previousWorkDescription': submission.previousWorkDescription.trim(),
      'serviceLocationCoverage': submission.serviceLocationCoverage.trim(),
      'expectedRate': submission.expectedRate,
      'validIdFrontUrl': validIdFrontUrl,
      'validIdBackUrl': validIdBackUrl,
      'selfieWithIdUrl': selfieWithIdUrl,
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

  Future<String> _uploadApplicationImage({
    required String providerId,
    required XFile image,
    required String fileName,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      final reference = _storage
          .ref()
          .child('provider_applications')
          .child(providerId)
          .child(fileName);

      await reference.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return reference.getDownloadURL();
    } on FirebaseException catch (error) {
      throw Exception(error.message ?? 'We could not upload your ID image.');
    }
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

    if (submission.validIdType.trim().isEmpty) {
      throw Exception('Valid ID type is required.');
    }

    if (submission.validIdFront == null &&
        submission.existingValidIdFrontUrl.trim().isEmpty) {
      throw Exception('Please upload at least one valid ID photo.');
    }
  }
}
