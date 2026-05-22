import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceListingModel extends Equatable {
  const ServiceListingModel({
    required this.serviceId,
    required this.providerId,
    required this.providerName,
    required this.providerPhone,
    required this.category,
    required this.title,
    required this.description,
    required this.location,
    required this.price,
    required this.rating,
    required this.status,
    required this.providerVerificationStatus,
    required this.createdAt,
  });

  final String serviceId;
  final String providerId;
  final String providerName;
  final String providerPhone;
  final String category;
  final String title;
  final String description;
  final String location;
  final double price;
  final double rating;
  final String status;
  final String providerVerificationStatus;
  final DateTime createdAt;

  factory ServiceListingModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ServiceListingModel(
      serviceId: documentId,
      providerId: map['providerId'] as String? ?? '',
      providerName: map['providerName'] as String? ?? 'Service Provider',
      providerPhone:
          map['providerPhone'] as String? ?? map['phone'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      title:
          map['title'] as String? ??
          map['serviceName'] as String? ??
          'Service listing',
      description: map['description'] as String? ?? 'No description added yet.',
      location: map['location'] as String? ?? '',
      price: _readDouble(map['price']),
      rating: _readDouble(map['rating']),
      status: map['status'] as String? ?? 'active',
      providerVerificationStatus:
          map['providerVerificationStatus'] as String? ?? '',
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
    serviceId,
    providerId,
    providerName,
    providerPhone,
    category,
    title,
    description,
    location,
    price,
    rating,
    status,
    providerVerificationStatus,
    createdAt,
  ];
}
