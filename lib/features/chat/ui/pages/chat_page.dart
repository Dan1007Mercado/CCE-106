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
  bool _isSending = false;
  bool _didEnsureChat = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = widget.args;
    if (!_didEnsureChat && args != null) {
      _didEnsureChat = true;
      _chatService.ensureBookingChat(
        bookingId: args.bookingId,
        customerId: args.customerId,
        providerId: args.providerId,
        customerName: args.customerName,
        providerName: args.providerName,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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

    return Scaffold(
      appBar: AppBar(title: Text(otherName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessageModel>>(
              stream: _chatService.streamMessages(args.bookingId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: LoadingIndicator(message: 'Loading messages...'),
                  );
                }

                final messages = snapshot.data ?? const <ChatMessageModel>[];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSizes.pagePadding),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _MessageBubble(
                      message: message,
                      isMine: message.senderId == user.uid,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
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
                    onPressed: _isSending
                        ? null
                        : () => _sendMessage(args.bookingId, user.uid),
                    icon: _isSending
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
          ),
        ],
      ),
    );
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
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: foreground,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
