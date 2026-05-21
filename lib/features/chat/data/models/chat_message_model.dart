import 'package:equatable/equatable.dart';

class ChatMessageModel extends Equatable {
  const ChatMessageModel({
    required this.messageId,
    required this.senderId,
    required this.senderRole,
    required this.receiverId,
    required this.text,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.readBy = const [],
  });

  final String messageId;
  final String senderId;
  final String senderRole;
  final String receiverId;
  final String text;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final List<String> readBy;

  factory ChatMessageModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return ChatMessageModel(
      messageId: documentId,
      senderId: map['senderId'] as String? ?? '',
      senderRole: map['senderRole'] as String? ?? '',
      receiverId: map['receiverId'] as String? ?? '',
      text: map['message'] as String? ?? map['text'] as String? ?? '',
      type: map['type'] as String? ?? 'text',
      isRead: map['isRead'] as bool? ?? false,
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
  List<Object?> get props => [
    messageId,
    senderId,
    senderRole,
    receiverId,
    text,
    type,
    isRead,
    createdAt,
    readBy,
  ];
}
