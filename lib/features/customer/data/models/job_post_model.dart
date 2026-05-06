import 'package:equatable/equatable.dart';

class JobPostModel extends Equatable {
  const JobPostModel({
    required this.jobId,
    required this.customerId,
    required this.customerName,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
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
  final DateTime createdAt;
  final double? ratingFilter;

  factory JobPostModel.fromMap(Map<String, dynamic> map, String documentId) {
    return JobPostModel(
      jobId: documentId,
      customerId: map['customerId'] as String? ?? '',
      customerName: map['customerName'] as String? ?? 'Customer',
      title: map['title'] as String? ?? 'Job request',
      description: map['description'] as String? ?? 'No details provided.',
      category: map['category'] as String? ?? 'General',
      location: map['location'] as String? ?? '',
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

    final toDate = (value as dynamic).toDate;
    if (toDate is Function) {
      final result = toDate();
      if (result is DateTime) {
        return result;
      }
    }

    return null;
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

  @override
  List<Object?> get props => [
    jobId,
    customerId,
    customerName,
    title,
    description,
    category,
    location,
    createdAt,
    ratingFilter,
  ];
}
