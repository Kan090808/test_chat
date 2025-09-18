import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import '../services/matrix_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.room});

  final Room? room;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room?.id != widget.room?.id) {
      _messageController.clear();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }
    await context.read<MatrixService>().sendMessage(text);
    _messageController.clear();
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MatrixService>();
    final room = widget.room ?? service.selectedRoom;
    if (room == null) {
      return const Center(
        child: Text('請選擇聊天室開始聊天'),
      );
    }

    final timeline = room.timeline;
    final events = timeline?.events ?? const <MatrixEvent>[];
    final messages = events
        .where((event) =>
            event.type == 'm.room.message' &&
            (event.content['msgtype'] == null ||
                event.content['msgtype'] == 'm.text'))
        .toList();

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => service.refreshSelectedRoom(),
            child: messages.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 180),
                      Center(child: Text('尚未有訊息，快傳一則吧！')),
                    ],
                  )
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final event = messages[index];
                      final body = event.content['body'] as String? ?? '';
                      final senderId = event.senderId ?? '';
                      final isMine = senderId == service.client.userID;
                      final timestamp = _parseTimestamp(event.originServerTs);
                      return MessageBubble(
                        message: body,
                        sender: senderId,
                        isMine: isMine,
                        timestamp: DateFormat('MM/dd HH:mm').format(timestamp),
                      );
                    },
                  ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: '輸入訊息...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                  tooltip: '送出訊息',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  DateTime _parseTimestamp(dynamic value) {
    if (value is DateTime) {
      return value.toLocal();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true).toLocal();
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
          .toLocal();
    }
    return DateTime.now();
  }
}
