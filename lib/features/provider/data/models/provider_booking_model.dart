import 'package:equatable/equatable.dart';

class ProviderBookingModel extends Equatable {
  const ProviderBookingModel({
    required this.bookingId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.serviceTitle,
    required this.category,
    required this.price,
    required this.selectedTimeSlot,
    required this.status,
    required this.paymentStatus,
    required this.createdAt,
    this.selectedDate,
    this.serviceAddress = '',
    this.notes = '',
  });

  final String bookingId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String serviceTitle;
  final String category;
  final double price;
  final DateTime? selectedDate;
  final String selectedTimeSlot;
  final String serviceAddress;
  final String notes;
  final String status;
  final String paymentStatus;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCompleted => status == 'completed';

  factory ProviderBookingModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ProviderBookingModel(
      bookingId: map['bookingId'] as String? ?? documentId,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? 'Customer',
      customerPhone: map['customerPhone'] as String? ?? '',
      serviceTitle: map['serviceTitle'] as String? ?? 'Booked service',
      category: map['category'] as String? ?? 'General',
      price: _readDouble(map['price']),
      selectedDate: _readDateTime(map['selectedDate']),
      selectedTimeSlot: map['selectedTimeSlot'] as String? ?? '',
      serviceAddress: map['serviceAddress'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
      paymentStatus: map['paymentStatus'] as String? ?? 'unpaid',
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
    bookingId,
    customerId,
    customerName,
    customerPhone,
    serviceTitle,
    category,
    price,
    selectedDate,
    selectedTimeSlot,
    serviceAddress,
    notes,
    status,
    paymentStatus,
    createdAt,
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
