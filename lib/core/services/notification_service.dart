import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('notifications');

  Stream<List<AppNotificationModel>> streamForRole(String roleTarget) {
    return _notificationsCollection
        .where('roleTarget', isEqualTo: roleTarget)
        .snapshots()
        .map(_readSortedNotifications);
  }

  Stream<List<AppNotificationModel>> streamForUser(String userId) {
    return _notificationsCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map(_readSortedNotifications);
  }

  Future<void> create({
    String? userId,
    String? roleTarget,
    required String title,
    required String body,
    required String type,
    required String relatedId,
  }) async {
    final doc = _notificationsCollection.doc();
    await doc.set({
      'notificationId': doc.id,
      if (userId != null && userId.trim().isNotEmpty) 'userId': userId.trim(),
      if (roleTarget != null && roleTarget.trim().isNotEmpty)
        'roleTarget': roleTarget.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'type': type.trim(),
      'relatedId': relatedId.trim(),
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  List<AppNotificationModel> _readSortedNotifications(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => AppNotificationModel.fromMap(doc.data(), doc.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

class AppNotificationModel {
  const AppNotificationModel({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.type,
    required this.relatedId,
    required this.isRead,
    required this.createdAt,
    this.userId = '',
    this.roleTarget = '',
  });

  final String notificationId;
  final String userId;
  final String roleTarget;
  final String title;
  final String body;
  final String type;
  final String relatedId;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotificationModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return AppNotificationModel(
      notificationId: map['notificationId'] as String? ?? documentId,
      userId: map['userId'] as String? ?? '',
      roleTarget: map['roleTarget'] as String? ?? '',
      title: map['title'] as String? ?? 'Notification',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'system',
      relatedId: map['relatedId'] as String? ?? '',
      isRead: map['isRead'] as bool? ?? false,
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
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
}
