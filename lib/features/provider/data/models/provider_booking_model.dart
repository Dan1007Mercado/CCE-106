import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProviderBookingModel extends Equatable {
  const ProviderBookingModel({
    required this.bookingId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.paymentId,
    required this.serviceTitle,
    required this.category,
    required this.price,
    required this.totalAmount,
    required this.selectedTimeSlot,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.selectedDate,
    this.startAt,
    this.endAt,
    this.durationMinutes = 0,
    this.jobId = '',
    this.difficulty = 'Moderate',
    this.serviceAddress = '',
    this.notes = '',
    this.completedAt,
    this.cancelledAt,
    this.providerCancellationFee = 0,
    this.platformCancellationFee = 0,
    this.refundAmount = 0,
  });

  final String bookingId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final String paymentId;
  final String serviceTitle;
  final String category;
  final double price;
  final double totalAmount;
  final DateTime? selectedDate;
  final DateTime? startAt;
  final DateTime? endAt;
  final int durationMinutes;
  final String jobId;
  final String difficulty;
  final String selectedTimeSlot;
  final String serviceAddress;
  final String notes;
  final String status;
  final String paymentStatus;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final double providerCancellationFee;
  final double platformCancellationFee;
  final double refundAmount;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled_by_customer';
  bool get canProviderMarkDone => status == 'accepted';
  bool get canCustomerCancel => status == 'pending' || status == 'accepted';

  factory ProviderBookingModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ProviderBookingModel(
      bookingId: map['bookingId'] as String? ?? documentId,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? 'Customer',
      customerPhone: map['customerPhone'] as String? ?? '',
      providerId: map['providerId'] as String? ?? '',
      providerName: map['providerName'] as String? ?? 'Service Provider',
      providerPhone: map['providerPhone'] as String? ?? '',
      paymentId: map['paymentId'] as String? ?? '',
      serviceTitle: map['serviceTitle'] as String? ?? 'Booked service',
      category: map['category'] as String? ?? 'General',
      price: _readDouble(map['price']),
      totalAmount: _readDouble(map['totalAmount'] ?? map['price']),
      selectedDate: _readDateTime(map['selectedDate']),
      startAt: _readDateTime(map['startAt']),
      endAt: _readDateTime(map['endAt']),
      durationMinutes: _readInt(map['durationMinutes']),
      jobId: map['jobId'] as String? ?? '',
      difficulty: _readDifficulty(map['difficulty']),
      selectedTimeSlot: map['selectedTimeSlot'] as String? ?? '',
      serviceAddress: map['serviceAddress'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      paymentStatus: map['paymentStatus'] as String? ?? 'pending',
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      completedAt: _readDateTime(map['completedAt']),
      cancelledAt: _readDateTime(map['cancelledAt']),
      providerCancellationFee: _readCancellationDouble(
        map,
        'providerCancellationFee',
      ),
      platformCancellationFee: _readCancellationDouble(
        map,
        'platformCancellationFee',
      ),
      refundAmount: _readCancellationDouble(map, 'refundAmount'),
    );
  }

  static double _readCancellationDouble(
    Map<String, dynamic> map,
    String field,
  ) {
    final cancellation = map['cancellation'];
    if (cancellation is Map) {
      return _readDouble(cancellation[field]);
    }

    return _readDouble(map[field]);
  }

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
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

  static String _readDifficulty(dynamic value) {
    final cleaned = value?.toString().trim() ?? '';
    return cleaned.isEmpty ? 'Moderate' : cleaned;
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

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
    bookingId,
    customerId,
    customerName,
    customerPhone,
    providerId,
    providerName,
    providerPhone,
    paymentId,
    serviceTitle,
    category,
    price,
    totalAmount,
    selectedDate,
    startAt,
    endAt,
    durationMinutes,
    jobId,
    difficulty,
    selectedTimeSlot,
    serviceAddress,
    notes,
    status,
    paymentStatus,
    createdAt,
    completedAt,
    cancelledAt,
    providerCancellationFee,
    platformCancellationFee,
    refundAmount,
  ];
}

class ProviderPaymentModel extends Equatable {
  const ProviderPaymentModel({
    required this.paymentId,
    required this.bookingId,
    required this.amount,
    required this.platformCommissionAmount,
    required this.providerEarning,
    required this.status,
    required this.createdAt,
  });

  final String paymentId;
  final String bookingId;
  final double amount;
  final double platformCommissionAmount;
  final double providerEarning;
  final String status;
  final DateTime createdAt;

  factory ProviderPaymentModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ProviderPaymentModel(
      paymentId: map['paymentId'] as String? ?? documentId,
      bookingId: map['bookingId'] as String? ?? '',
      amount: ProviderBookingModel._readDouble(map['amount']),
      platformCommissionAmount: ProviderBookingModel._readDouble(
        map['platformCommissionAmount'],
      ),
      providerEarning: ProviderBookingModel._readDouble(map['providerEarning']),
      status: map['status'] as String? ?? 'pending',
      createdAt:
          ProviderBookingModel._readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  List<Object?> get props => [
    paymentId,
    bookingId,
    amount,
    platformCommissionAmount,
    providerEarning,
    status,
    createdAt,
  ];
}
