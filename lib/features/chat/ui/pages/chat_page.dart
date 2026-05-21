import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_sizes.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/bloc/auth_bloc.dart';
import '../../data/models/chat_message_model.dart';
import '../../data/services/chat_service.dart';

class ChatPageArgs {
  const ChatPageArgs({
    required this.bookingId,
    required this.customerId,
    required this.providerId,
    required this.customerName,
    required this.providerName,
  });

  final String bookingId;
  final String customerId;
  final String providerId;
  final String customerName;
  final String providerName;
}

class ChatPage extends StatefulWidget {
  const ChatPage({required this.args, super.key});

  final ChatPageArgs? args;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Future<void>? _prepareChatFuture;
  String? _prepareChatKey;
  bool _isSending = false;
  bool _isMarkingRead = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleMessageTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleMessageTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleMessageTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final user = context.select((AuthBloc bloc) => bloc.state.user);

    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('Chat details are unavailable right now.')),
      );
    }

    if (user == null) {
      return const Scaffold(
        body: Center(child: LoadingIndicator(message: 'Loading chat...')),
      );
    }

    final otherName = user.uid == args.customerId
        ? args.providerName
        : args.customerName;
    final displayName = otherName.trim().isEmpty ? 'Chat' : otherName.trim();

    return Scaffold(
      appBar: AppBar(title: Text(displayName)),
      body: FutureBuilder<void>(
        future: _prepareChat(args, user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: LoadingIndicator(message: 'Loading chat...'),
            );
          }

          if (snapshot.hasError) {
            return _ChatErrorState(message: _errorMessage(snapshot.error));
          }

          return Column(
            children: [
              Expanded(child: _buildMessageList(args, user.uid)),
              _MessageComposer(
                controller: _messageController,
                canSend:
                    !_isSending && _messageController.text.trim().isNotEmpty,
                isSending: _isSending,
                onSend: () => _sendMessage(args.bookingId, user.uid),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageList(ChatPageArgs args, String currentUserId) {
    return StreamBuilder<List<ChatMessageModel>>(
      stream: _chatService.streamMessages(
        chatId: args.bookingId,
        userId: currentUserId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: LoadingIndicator(message: 'Loading messages...'),
          );
        }

        if (snapshot.hasError) {
          return _ChatErrorState(message: _errorMessage(snapshot.error));
        }

        final messages = snapshot.data ?? const <ChatMessageModel>[];
        if (messages.isEmpty) {
          return const Center(
            child: Text('No messages yet. Start the conversation.'),
          );
        }

        _scheduleScrollToLatest();
        if (messages.any(
          (message) =>
              message.receiverId == currentUserId && message.isRead == false,
        )) {
          _scheduleMarkRead(args.bookingId, currentUserId);
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _MessageBubble(
              message: message,
              isMine: message.senderId == currentUserId,
            );
          },
        );
      },
    );
  }

  Future<void> _prepareChat(ChatPageArgs args, String currentUserId) {
    final key = '${args.bookingId}|$currentUserId';
    if (_prepareChatKey == key && _prepareChatFuture != null) {
      return _prepareChatFuture!;
    }

    _prepareChatKey = key;
    _prepareChatFuture = () async {
      await _chatService.ensureBookingChat(
        bookingId: args.bookingId,
        customerId: args.customerId,
        providerId: args.providerId,
        customerName: args.customerName,
        providerName: args.providerName,
        currentUserId: currentUserId,
      );
      await _chatService.markChatRead(
        chatId: args.bookingId,
        userId: currentUserId,
      );
    }();

    return _prepareChatFuture!;
  }

  void _scheduleScrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _scheduleMarkRead(String chatId, String userId) {
    if (_isMarkingRead) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _isMarkingRead) {
        return;
      }

      _isMarkingRead = true;
      try {
        await _chatService.markChatRead(chatId: chatId, userId: userId);
      } catch (_) {
        // A read receipt failure should not block the open chat.
      } finally {
        _isMarkingRead = false;
      }
    });
  }

  Future<void> _sendMessage(String chatId, String senderId) async {
    final text = _messageController.text;
    if (text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await _chatService.sendMessage(
        chatId: chatId,
        senderId: senderId,
        text: text,
      );
      _messageController.clear();
      _scheduleScrollToLatest();
    } catch (error) {
      if (!mounted) {
        return;
      }

      Helpers.showSnackBar(
        context,
        error.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _errorMessage(Object? error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.canSend,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'Write a message',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              onPressed: canSend ? onSend : null,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              tooltip: 'Send',
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatErrorState extends StatelessWidget {
  const _ChatErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessageModel message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isMine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final foreground = isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatMessageTime(message.createdAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMessageTime(DateTime value) {
  if (value.millisecondsSinceEpoch == 0) {
    return 'Sending...';
  }

  final now = DateTime.now();
  final local = value.toLocal();
  final hourOfPeriod = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  final time = '$hourOfPeriod:$minute $period';

  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return time;
  }

  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}, $time';
}
