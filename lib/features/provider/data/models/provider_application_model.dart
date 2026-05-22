import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ProviderApplicationModel extends Equatable {
  const ProviderApplicationModel({
    required this.applicationId,
    required this.providerId,
    required this.providerName,
    required this.providerEmail,
    required this.providerPhone,
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
    required this.maskedValidIdNumber,
    required this.skillCategory,
    required this.experienceYears,
    required this.serviceDescription,
    required this.previousWorkDescription,
    required this.serviceLocationCoverage,
    required this.expectedRate,
    required this.verificationConsentAccepted,
    required this.verificationConsentAcceptedAt,
    required this.dataPrivacyNoticeVersion,
    required this.status,
    required this.adminRemarks,
    required this.reviewedBy,
    required this.createdAt,
    required this.updatedAt,
    this.reviewedAt,
  });

  final String applicationId;
  final String providerId;
  final String providerName;
  final String providerEmail;
  final String providerPhone;
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
  final String maskedValidIdNumber;
  final String skillCategory;
  final int experienceYears;
  final String serviceDescription;
  final String previousWorkDescription;
  final String serviceLocationCoverage;
  final double? expectedRate;
  final bool verificationConsentAccepted;
  final DateTime? verificationConsentAcceptedAt;
  final String dataPrivacyNoticeVersion;
  final String status;
  final String adminRemarks;
  final String reviewedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reviewedAt;

  String get normalizedStatus => status.trim().toLowerCase();

  bool get isPending => normalizedStatus == 'pending';
  bool get isApproved => normalizedStatus == 'approved';
  bool get isRejected => normalizedStatus == 'rejected';

  factory ProviderApplicationModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final providerName = map['providerName'] as String? ?? '';
    final fullName = map['fullName'] as String? ?? providerName;
    final validIdNumber = map['validIdNumber'] as String? ?? '';
    final maskedValidIdNumber =
        map['maskedValidIdNumber'] as String? ??
        maskValidIdNumber(validIdNumber);

    return ProviderApplicationModel(
      applicationId: map['applicationId'] as String? ?? documentId,
      providerId: map['providerId'] as String? ?? '',
      providerName: providerName.isEmpty ? 'Service Provider' : providerName,
      providerEmail: map['providerEmail'] as String? ?? '',
      providerPhone: map['providerPhone'] as String? ?? '',
      fullName: fullName.isEmpty ? 'Service Provider' : fullName,
      firstName: map['firstName'] as String? ?? '',
      middleName: map['middleName'] as String? ?? '',
      lastName: map['lastName'] as String? ?? '',
      suffix: map['suffix'] as String? ?? '',
      age: _readInt(map['age']),
      birthDate: _readDateTime(map['birthDate']),
      gender: map['gender'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      city: map['city'] as String? ?? '',
      province: map['province'] as String? ?? '',
      validIdType: map['validIdType'] as String? ?? '',
      validIdNumber: validIdNumber,
      validIdDetails: map['validIdDetails'] as String? ?? '',
      maskedValidIdNumber: maskedValidIdNumber,
      skillCategory: map['skillCategory'] as String? ?? '',
      experienceYears: _readInt(map['experienceYears']),
      serviceDescription: map['serviceDescription'] as String? ?? '',
      previousWorkDescription: map['previousWorkDescription'] as String? ?? '',
      serviceLocationCoverage: map['serviceLocationCoverage'] as String? ?? '',
      expectedRate: _readNullableDouble(map['expectedRate']),
      verificationConsentAccepted:
          map['verificationConsentAccepted'] == true,
      verificationConsentAcceptedAt: _readDateTime(
        map['verificationConsentAcceptedAt'],
      ),
      dataPrivacyNoticeVersion:
          map['dataPrivacyNoticeVersion'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      adminRemarks: map['adminRemarks'] as String? ?? '',
      reviewedBy: map['reviewedBy'] as String? ?? '',
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readDateTime(map['updatedAt']) ??
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: _readDateTime(map['reviewedAt']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _readNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
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

  @override
  List<Object?> get props => [
    applicationId,
    providerId,
    providerName,
    providerEmail,
    providerPhone,
    fullName,
    firstName,
    middleName,
    lastName,
    suffix,
    age,
    birthDate,
    gender,
    phoneNumber,
    email,
    address,
    city,
    province,
    validIdType,
    validIdNumber,
    validIdDetails,
    maskedValidIdNumber,
    skillCategory,
    experienceYears,
    serviceDescription,
    previousWorkDescription,
    serviceLocationCoverage,
    expectedRate,
    verificationConsentAccepted,
    verificationConsentAcceptedAt,
    dataPrivacyNoticeVersion,
    status,
    adminRemarks,
    reviewedBy,
    createdAt,
    updatedAt,
    reviewedAt,
  ];
}

String maskValidIdNumber(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) {
    return '';
  }

  final visibleLength = cleaned.length < 4 ? cleaned.length : 4;
  final visibleSuffix = cleaned.substring(cleaned.length - visibleLength);
  return '****$visibleSuffix';
}
