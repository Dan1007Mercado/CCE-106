import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class JobPostModel extends Equatable {
  const JobPostModel({
    required this.jobId,
    required this.customerId,
    required this.customerName,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.status,
    required this.budget,
    required this.difficulty,
    required this.photoUrl,
    required this.createdAt,
    this.ratingFilter,
  });

  final String jobId;
  final String customerId;
  final String customerName;
  final String title;
  final String description;
  final String category;
  final String location;
  final String status;
  final double budget;
  final String difficulty;
  final String photoUrl;
  final DateTime createdAt;
  final double? ratingFilter;

  String get readableLocation {
    final trimmed = location.trim();
    if (trimmed.isEmpty || _looksLikeCoordinates(trimmed)) {
      return 'Location captured, address unavailable';
    }

    return trimmed;
  }

  factory JobPostModel.fromMap(Map<String, dynamic> map, String documentId) {
    return JobPostModel(
      jobId: documentId,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? 'Customer',
      title: map['title'] as String? ?? 'Job request',
      description: map['description'] as String? ?? 'No details provided.',
      category: map['category'] as String? ?? 'General',
      location: map['location'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      budget: _readDouble(map['budget'] ?? map['price']),
      difficulty: _readString(map['difficulty'], fallback: 'Moderate'),
      photoUrl: map['photoUrl'] as String? ?? '',
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      ratingFilter: _readNullableDouble(map['ratingFilter']),
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

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.tryParse(value.toString());
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

  static double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _readString(dynamic value, {required String fallback}) {
    final cleaned = value?.toString().trim() ?? '';
    return cleaned.isEmpty ? fallback : cleaned;
  }

  static bool _looksLikeCoordinates(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.startsWith('lat ') || normalized.startsWith('lat:')) {
      return true;
    }

    return RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(normalized);
  }

  @override
  List<Object?> get props => [
    jobId,
    customerId,
    customerName,
    title,
    description,
    category,
    location,
    status,
    budget,
    difficulty,
    photoUrl,
    createdAt,
    ratingFilter,
  ];
}
