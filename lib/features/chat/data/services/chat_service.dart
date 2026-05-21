import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message_model.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  Future<void> ensureBookingChat({
    required String bookingId,
    required String customerId,
    required String providerId,
    required String customerName,
    required String providerName,
  }) async {
    if (bookingId.trim().isEmpty) {
      throw Exception('Booking record not found.');
    }

    await _chatsCollection.doc(bookingId).set({
      'chatId': bookingId,
      'bookingId': bookingId,
      'customerId': customerId,
      'providerId': providerId,
      'customerName': customerName,
      'providerName': providerName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<List<ChatMessageModel>> streamMessages(String chatId) {
    return _chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
  }) async {
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) {
      return;
    }

    final messageRef = _chatsCollection
        .doc(chatId)
        .collection('messages')
        .doc();

    final batch = _firestore.batch();
    batch.set(messageRef, {
      'senderId': senderId,
      'text': cleanedText,
      'createdAt': FieldValue.serverTimestamp(),
      'readBy': [senderId],
    });
    batch.set(_chatsCollection.doc(chatId), {
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessage': cleanedText,
      'lastSenderId': senderId,
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
