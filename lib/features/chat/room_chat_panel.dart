import 'package:flutter/material.dart';

import 'chat_service.dart';

class RoomChatPanel extends StatefulWidget {
  const RoomChatPanel({
    super.key,
    required this.roomId,
    this.isFloating = false,
    this.initiallyExpanded = false,
  });

  final String roomId;
  final bool isFloating;
  final bool initiallyExpanded;

  @override
  State<RoomChatPanel> createState() => _RoomChatPanelState();
}

class _RoomChatPanelState extends State<RoomChatPanel> {
  final _chatService = ChatService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _expanded = false;
  bool _isSending = false;
  String? _error;
  DateTime? _lastSentAt;
  int _lastSeenCount = 0;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final now = DateTime.now();
    if (_lastSentAt != null &&
        now.difference(_lastSentAt!) < ChatService.cooldown) {
      setState(() => _error = 'Wait a second before sending again');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      await _chatService.sendPlayerMessage(
        roomId: widget.roomId,
        message: _controller.text,
      );
      if (!mounted) return;
      _controller.clear();
      _lastSentAt = DateTime.now();
    } on ChatException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _syncMessageCount(int count) {
    if (_lastSeenCount == 0) {
      _lastSeenCount = count;
      return;
    }

    if (_expanded) {
      _lastSeenCount = count;
      _unreadCount = 0;
      return;
    }

    if (count > _lastSeenCount) {
      _unreadCount += count - _lastSeenCount;
      _lastSeenCount = count;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 28;
    final width = widget.isFloating
        ? availableWidth.clamp(230.0, 330.0)
        : double.infinity;
    final collapsedWidth = widget.isFloating ? 70.0 : double.infinity;

    return StreamBuilder<List<RoomChatMessage>>(
      stream: _chatService.watchMessages(widget.roomId),
      builder: (context, snapshot) {
        final messages = snapshot.data ?? const <RoomChatMessage>[];
        _syncMessageCount(messages.length);
        if (_expanded) _scrollToBottom();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: _expanded ? width : collapsedWidth,
          transform: Matrix4.diagonal3Values(
            _expanded ? 1.0 : (_unreadCount > 0 ? 1.015 : 1.0),
            _expanded ? 1.0 : (_unreadCount > 0 ? 1.015 : 1.0),
            1,
          ),
          decoration: BoxDecoration(
            gradient: _expanded
                ? const LinearGradient(
                    colors: [Color(0xFFFFFAEC), Color(0xFFFFE6A0)],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE6A0), Color(0xFFE5B540)],
                  ),
            borderRadius: BorderRadius.circular(
              widget.isFloating && !_expanded ? 999 : 24,
            ),
            border: Border.all(color: const Color(0xFFFFF4D9), width: 3),
            boxShadow: [
              const BoxShadow(
                color: Color(0x77351A10),
                blurRadius: 0,
                offset: Offset(0, 7),
              ),
              BoxShadow(
                color: _unreadCount > 0
                    ? const Color(0x77E5B540)
                    : const Color(0x332B160D),
                blurRadius: _unreadCount > 0 ? 24 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ChatHeader(
                expanded: _expanded,
                unreadCount: _unreadCount,
                floating: widget.isFloating,
                onTap: () {
                  setState(() {
                    _expanded = !_expanded;
                    if (_expanded) {
                      _unreadCount = 0;
                      _lastSeenCount = messages.length;
                    }
                  });
                },
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _ChatBody(
                  messages: messages,
                  error: _error,
                  isSending: _isSending,
                  textController: _controller,
                  scrollController: _scrollController,
                  onSend: _send,
                  floating: widget.isFloating,
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 220),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.expanded,
    required this.unreadCount,
    required this.floating,
    required this.onTap,
  });

  final bool expanded;
  final int unreadCount;
  final bool floating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final collapsedFloating = floating && !expanded;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: collapsedFloating ? 64 : 58,
        padding: EdgeInsets.symmetric(horizontal: collapsedFloating ? 0 : 14),
        decoration: BoxDecoration(
          gradient: collapsedFloating
              ? const RadialGradient(
                  colors: [Color(0xFFFFF4D9), Color(0xFFE5B540)],
                )
              : const LinearGradient(
                  colors: [Color(0xFFFFE6A0), Color(0xFFE5B540)],
                ),
        ),
        child: Row(
          mainAxisAlignment: collapsedFloating
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: collapsedFloating ? 44 : 34,
                  height: collapsedFloating ? 44 : 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF233B7A), Color(0xFF101C43)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFE6A0),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Color(0xFFFFE6A0),
                    size: 22,
                  ),
                ),
                if (unreadCount > 0 && collapsedFloating)
                  Positioned(
                    right: -6,
                    top: -7,
                    child: _UnreadBadge(unreadCount: unreadCount),
                  ),
              ],
            ),
            if (!collapsedFloating) ...[
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Royal Chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF4C2B20),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              if (unreadCount > 0) _UnreadBadge(unreadCount: unreadCount),
              const SizedBox(width: 6),
              Icon(
                expanded
                    ? Icons.expand_more_rounded
                    : Icons.expand_less_rounded,
                color: const Color(0xFF4C2B20),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFB83A4B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x77B83A4B), blurRadius: 12)],
      ),
      child: Text(
        '$unreadCount',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.messages,
    required this.error,
    required this.isSending,
    required this.textController,
    required this.scrollController,
    required this.onSend,
    required this.floating,
  });

  final List<RoomChatMessage> messages;
  final String? error;
  final bool isSending;
  final TextEditingController textController;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        children: [
          SizedBox(
            height: floating ? 210 : 180,
            child: messages.isEmpty
                ? const Center(child: Text('No messages yet'))
                : ListView.builder(
                    controller: scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return _ChatMessageBubble(message: messages[index]);
                    },
                  ),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: textController,
                  maxLength: ChatService.maxMessageLength,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => isSending ? null : onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Message the room',
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(
                  tooltip: 'Send',
                  onPressed: isSending ? null : onSend,
                  icon: isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({required this.message});

  final RoomChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE6A0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5B540)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 16,
                color: Color(0xFFB83A4B),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message.message,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7C879), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '@${message.senderUsername}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF7E4F2B),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(message.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(message.message),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime? dateTime) {
  if (dateTime == null) return '';
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
