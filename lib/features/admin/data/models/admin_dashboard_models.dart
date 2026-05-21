import 'package:equatable/equatable.dart';

import '../../../auth/data/models/user_model.dart';

class AdminUserAccountModel extends Equatable {
  const AdminUserAccountModel({
    required this.user,
    required this.status,
    required this.isSuspended,
  });

  final UserModel user;
  final String status;
  final bool isSuspended;

  factory AdminUserAccountModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    final status = map['status'] as String? ?? 'active';
    final isSuspended =
        map['isSuspended'] as bool? ?? status.toLowerCase() == 'suspended';

    return AdminUserAccountModel(
      user: UserModel.fromMap(map, documentId),
      status: isSuspended ? 'suspended' : status,
      isSuspended: isSuspended,
    );
  }

  @override
  List<Object?> get props => [user, status, isSuspended];
}

class ProviderApplicationModel extends Equatable {
  const ProviderApplicationModel({
    required this.applicationId,
    required this.providerId,
    required this.providerName,
    required this.skillCategory,
    required this.experienceYears,
    required this.proofUrl,
    required this.status,
    required this.adminRemarks,
    required this.createdAt,
    this.reviewedAt,
  });

  final String applicationId;
  final String providerId;
  final String providerName;
  final String skillCategory;
  final int experienceYears;
  final String proofUrl;
  final String status;
  final String adminRemarks;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  factory ProviderApplicationModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ProviderApplicationModel(
      applicationId: map['applicationId'] as String? ?? documentId,
      providerId: map['providerId'] as String? ?? '',
      providerName: map['providerName'] as String? ?? 'Service Provider',
      skillCategory: map['skillCategory'] as String? ?? 'General',
      experienceYears: _readInt(map['experienceYears']),
      proofUrl: map['proofUrl'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      adminRemarks: map['adminRemarks'] as String? ?? '',
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: _readDateTime(map['reviewedAt']),
    );
  }

  static int _readInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _readDateTime(dynamic value) {
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

  @override
  List<Object?> get props => [
    applicationId,
    providerId,
    providerName,
    skillCategory,
    experienceYears,
    proofUrl,
    status,
    adminRemarks,
    createdAt,
    reviewedAt,
  ];
}

class AdminPaymentModel extends Equatable {
  const AdminPaymentModel({
    required this.paymentId,
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.amount,
    required this.platformCommissionAmount,
    required this.providerEarning,
    required this.status,
    required this.createdAt,
  });

  final String paymentId;
  final String bookingId;
  final String customerId;
  final String providerId;
  final double amount;
  final double platformCommissionAmount;
  final double providerEarning;
  final String status;
  final DateTime createdAt;

  factory AdminPaymentModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return AdminPaymentModel(
      paymentId: map['paymentId'] as String? ?? documentId,
      bookingId: map['bookingId'] as String? ?? '',
      customerId: map['customerId'] as String? ?? '',
      providerId: map['providerId'] as String? ?? '',
      amount: _readDouble(map['amount']),
      platformCommissionAmount: _readDouble(map['platformCommissionAmount']),
      providerEarning: _readDouble(map['providerEarning']),
      status: map['status'] as String? ?? 'pending',
      createdAt:
          ProviderApplicationModel._readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  List<Object?> get props => [
    paymentId,
    bookingId,
    customerId,
    providerId,
    amount,
    platformCommissionAmount,
    providerEarning,
    status,
    createdAt,
  ];
}
