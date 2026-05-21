import 'package:equatable/equatable.dart';

class ChatMessageModel extends Equatable {
  const ChatMessageModel({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.readBy = const [],
  });

  final String messageId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final List<String> readBy;

  factory ChatMessageModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ChatMessageModel(
      messageId: documentId,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readBy: (map['readBy'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
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

  @override
  List<Object?> get props => [messageId, senderId, text, createdAt, readBy];
}
