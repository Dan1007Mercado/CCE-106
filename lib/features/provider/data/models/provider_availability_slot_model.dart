import 'package:equatable/equatable.dart';

class ProviderAvailabilitySlotModel extends Equatable {
  const ProviderAvailabilitySlotModel({
    required this.slotId,
    required this.dateLabel,
    required this.timeSlot,
    required this.status,
  });

  final String slotId;
  final String dateLabel;
  final String timeSlot;
  final String status;

  factory ProviderAvailabilitySlotModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ProviderAvailabilitySlotModel(
      slotId: documentId,
      dateLabel: map['dateLabel'] as String? ?? '',
      timeSlot: map['timeSlot'] as String? ?? '',
      status: map['status'] as String? ?? 'available',
    );
  }

  @override
  List<Object?> get props => [slotId, dateLabel, timeSlot, status];
}
