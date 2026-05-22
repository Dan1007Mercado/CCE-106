import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
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

class AdminTermsModel extends Equatable {
  const AdminTermsModel({
    required this.termsId,
    required this.body,
    required this.version,
    this.updatedAt,
  });

  final String termsId;
  final String body;
  final String version;
  final DateTime? updatedAt;

  factory AdminTermsModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AdminTermsModel(
      termsId: map['termsId'] as String? ?? documentId,
      body: map['body'] as String? ?? '',
      version: map['version'] as String? ?? '',
      updatedAt: _readDateTime(map['updatedAt']),
    );
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
  List<Object?> get props => [termsId, body, version, updatedAt];
}
