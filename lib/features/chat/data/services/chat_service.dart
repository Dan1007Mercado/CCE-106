import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message_model.dart';

class ChatService {
  ChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> get _bookingsCollection =>
      _firestore.collection('bookings');

  CollectionReference<Map<String, dynamic>> get _notificationsCollection =>
      _firestore.collection('notifications');

  Future<void> ensureBookingChat({
    required String bookingId,
    required String customerId,
    required String providerId,
    required String customerName,
    required String providerName,
    String? currentUserId,
  }) async {
    final cleanedBookingId = bookingId.trim();
    if (cleanedBookingId.isEmpty) {
      throw Exception('Booking record not found.');
    }

    final bookingRef = _bookingsCollection.doc(cleanedBookingId);
    final chatRef = _chatsCollection.doc(cleanedBookingId);

    await _firestore.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingRef);
      if (!bookingSnapshot.exists) {
        throw Exception('Booking record not found.');
      }

      final booking = bookingSnapshot.data();
      if (booking == null) {
        throw Exception('Booking record not found.');
      }

      final resolvedCustomerId = _resolveRequiredValue(
        customerId,
        booking['customerId'],
        'Customer record not found.',
      );
      final resolvedProviderId = _resolveRequiredValue(
        providerId,
        booking['providerId'],
        'Provider record not found.',
      );
      final resolvedCustomerName = _resolveName(
        customerName,
        booking['customerName'],
        'Customer',
      );
      final resolvedProviderName = _resolveName(
        providerName,
        booking['providerName'],
        'Service Provider',
      );

      _assertBookingParticipantMatch(
        expectedCustomerId: resolvedCustomerId,
        expectedProviderId: resolvedProviderId,
        booking: booking,
      );

      final requesterId = currentUserId?.trim();
      if (requesterId != null && requesterId.isNotEmpty) {
        _assertParticipant({
          'customerId': resolvedCustomerId,
          'providerId': resolvedProviderId,
        }, requesterId);
      }

      final chatSnapshot = await transaction.get(chatRef);
      final chat = chatSnapshot.data();
      final chatData = <String, dynamic>{
        'chatId': cleanedBookingId,
        'bookingId': cleanedBookingId,
        'customerId': resolvedCustomerId,
        'providerId': resolvedProviderId,
        'customerName': resolvedCustomerName,
        'providerName': resolvedProviderName,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!chatSnapshot.exists) {
        chatData.addAll({
          'lastMessage': '',
          'lastMessageAt': null,
          'lastSenderId': '',
          'unreadForCustomer': 0,
          'unreadForProvider': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        if (chat == null || !chat.containsKey('lastMessage')) {
          chatData['lastMessage'] = '';
        }
        if (chat == null || !chat.containsKey('lastMessageAt')) {
          chatData['lastMessageAt'] = null;
        }
        if (chat == null || !chat.containsKey('lastSenderId')) {
          chatData['lastSenderId'] = '';
        }
        if (chat == null || !chat.containsKey('unreadForCustomer')) {
          chatData['unreadForCustomer'] = 0;
        }
        if (chat == null || !chat.containsKey('unreadForProvider')) {
          chatData['unreadForProvider'] = 0;
        }
        if (chat == null || !chat.containsKey('createdAt')) {
          chatData['createdAt'] = FieldValue.serverTimestamp();
        }
      }

      transaction.set(chatRef, chatData, SetOptions(merge: true));
    });
  }

  Stream<List<ChatMessageModel>> streamMessages({
    required String chatId,
    required String userId,
  }) async* {
    final cleanedChatId = chatId.trim();
    final cleanedUserId = userId.trim();

    await _validateChatParticipant(
      chatId: cleanedChatId,
      userId: cleanedUserId,
    );

    yield* _chatsCollection
        .doc(cleanedChatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<int> streamUnreadCount({
    required String chatId,
    required String userId,
  }) {
    final cleanedChatId = chatId.trim();
    final cleanedUserId = userId.trim();
    if (cleanedChatId.isEmpty || cleanedUserId.isEmpty) {
      return Stream.value(0);
    }

    return _chatsCollection.doc(cleanedChatId).snapshots().map((snapshot) {
      final chat = snapshot.data();
      if (chat == null) {
        return 0;
      }

      final role = _roleForUser(chat, cleanedUserId);
      if (role == null) {
        return 0;
      }

      final unreadField = role == 'customer'
          ? 'unreadForCustomer'
          : 'unreadForProvider';
      return _readInt(chat[unreadField]);
    });
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

    final cleanedChatId = chatId.trim();
    final cleanedSenderId = senderId.trim();
    if (cleanedChatId.isEmpty || cleanedSenderId.isEmpty) {
      throw Exception('Chat details are unavailable right now.');
    }

    final chatRef = _chatsCollection.doc(cleanedChatId);
    final messageRef = _chatsCollection
        .doc(cleanedChatId)
        .collection('messages')
        .doc();
    final notificationRef = _notificationsCollection.doc();

    await _firestore.runTransaction((transaction) async {
      final chatSnapshot = await transaction.get(chatRef);
      if (!chatSnapshot.exists) {
        throw Exception('Chat not found for this booking.');
      }

      final chat = chatSnapshot.data();
      if (chat == null) {
        throw Exception('Chat not found for this booking.');
      }

      final senderRole = _roleForUser(chat, cleanedSenderId);
      if (senderRole == null) {
        throw Exception('You do not have access to this chat.');
      }

      final receiverId = senderRole == 'customer'
          ? chat['providerId'] as String? ?? ''
          : chat['customerId'] as String? ?? '';
      if (receiverId.trim().isEmpty) {
        throw Exception('Message receiver is unavailable.');
      }

      final senderName = senderRole == 'customer'
          ? _resolveName('', chat['customerName'], 'Customer')
          : _resolveName('', chat['providerName'], 'Service Provider');
      final bookingId = chat['bookingId'] as String? ?? cleanedChatId;
      final notificationBody = '$senderName: ${_preview(cleanedText)}';

      transaction.set(messageRef, {
        'messageId': messageRef.id,
        'senderId': cleanedSenderId,
        'senderRole': senderRole,
        'receiverId': receiverId,
        'message': cleanedText,
        'text': cleanedText,
        'type': 'text',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': [cleanedSenderId],
      });

      transaction.set(chatRef, {
        'lastMessage': cleanedText,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': cleanedSenderId,
        if (senderRole == 'customer')
          'unreadForProvider': FieldValue.increment(1)
        else
          'unreadForCustomer': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(notificationRef, {
        'notificationId': notificationRef.id,
        'type': 'chat_message',
        'title': 'New message',
        'body': notificationBody,
        'relatedId': bookingId,
        'bookingId': bookingId,
        'chatId': cleanedChatId,
        'userId': receiverId,
        'senderId': cleanedSenderId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markChatRead({
    required String chatId,
    required String userId,
  }) async {
    final cleanedChatId = chatId.trim();
    final cleanedUserId = userId.trim();
    final chatRef = _chatsCollection.doc(cleanedChatId);
    final chat = await _validateChatParticipant(
      chatId: cleanedChatId,
      userId: cleanedUserId,
    );
    final role = _roleForUser(chat, cleanedUserId);
    if (role == null) {
      throw Exception('You do not have access to this chat.');
    }

    final unreadField = role == 'customer'
        ? 'unreadForCustomer'
        : 'unreadForProvider';
    final unreadCount = _readInt(chat[unreadField]);

    final unreadMessages = await chatRef
        .collection('messages')
        .where('receiverId', isEqualTo: cleanedUserId)
        .get();

    WriteBatch batch = _firestore.batch();
    var pendingWrites = 0;

    Future<void> commitBatchIfNeeded({bool force = false}) async {
      if (pendingWrites == 0 || (!force && pendingWrites < 450)) {
        return;
      }

      await batch.commit();
      batch = _firestore.batch();
      pendingWrites = 0;
    }

    if (unreadCount != 0) {
      batch.set(chatRef, {
        unreadField: 0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      pendingWrites++;
    }

    for (final doc in unreadMessages.docs) {
      final data = doc.data();
      if (data['isRead'] == true) {
        continue;
      }

      batch.update(doc.reference, {
        'isRead': true,
        'readBy': FieldValue.arrayUnion([cleanedUserId]),
      });
      pendingWrites++;
      await commitBatchIfNeeded();
    }

    await commitBatchIfNeeded(force: true);
  }

  Future<Map<String, dynamic>> _validateChatParticipant({
    required String chatId,
    required String userId,
  }) async {
    if (chatId.trim().isEmpty || userId.trim().isEmpty) {
      throw Exception('Chat details are unavailable right now.');
    }

    final chatSnapshot = await _chatsCollection.doc(chatId).get();
    if (!chatSnapshot.exists) {
      throw Exception('Chat not found for this booking.');
    }

    final chat = chatSnapshot.data();
    if (chat == null) {
      throw Exception('Chat not found for this booking.');
    }

    _assertParticipant(chat, userId);
    return chat;
  }

  void _assertParticipant(Map<String, dynamic> chat, String userId) {
    if (_roleForUser(chat, userId) == null) {
      throw Exception('You do not have access to this chat.');
    }
  }

  String? _roleForUser(Map<String, dynamic> chat, String userId) {
    final customerId = chat['customerId'] as String? ?? '';
    final providerId = chat['providerId'] as String? ?? '';
    if (userId == customerId) {
      return 'customer';
    }

    if (userId == providerId) {
      return 'services';
    }

    return null;
  }

  void _assertBookingParticipantMatch({
    required String expectedCustomerId,
    required String expectedProviderId,
    required Map<String, dynamic> booking,
  }) {
    final bookingCustomerId = booking['customerId'] as String? ?? '';
    final bookingProviderId = booking['providerId'] as String? ?? '';
    if (bookingCustomerId != expectedCustomerId ||
        bookingProviderId != expectedProviderId) {
      throw Exception('Booking details do not match this chat.');
    }
  }

  String _resolveRequiredValue(
    String provided,
    dynamic fallback,
    String errorMessage,
  ) {
    final cleanedProvided = provided.trim();
    if (cleanedProvided.isNotEmpty) {
      return cleanedProvided;
    }

    final cleanedFallback = fallback?.toString().trim() ?? '';
    if (cleanedFallback.isNotEmpty) {
      return cleanedFallback;
    }

    throw Exception(errorMessage);
  }

  String _resolveName(String provided, dynamic fallback, String defaultValue) {
    final cleanedProvided = provided.trim();
    if (cleanedProvided.isNotEmpty) {
      return cleanedProvided;
    }

    final cleanedFallback = fallback?.toString().trim() ?? '';
    return cleanedFallback.isEmpty ? defaultValue : cleanedFallback;
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _preview(String text) {
    const maxLength = 80;
    final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= maxLength) {
      return cleaned;
    }

    return '${cleaned.substring(0, maxLength - 3)}...';
  }
}
