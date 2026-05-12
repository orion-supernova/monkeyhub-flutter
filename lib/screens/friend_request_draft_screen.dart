import 'dart:async';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/friend_request.dart';
import '../models/friend_request_message.dart';
import '../theme/theme_scope.dart';
import '../widgets/user_avatar.dart';
import '../widgets/visibility_badge.dart';
import 'room_screen.dart';

/// The draft chat that runs BEFORE a friend request is approved.
///
/// Used in two modes:
///   - **Receiver**: pass an existing [FriendRequest]. The user can read the
///     thread, append a message via [ChatRepository.appendDirectRequestMessage],
///     and Approve / Decline.
///   - **Sender (composing a new request)**: pass [target] but no [req]. The
///     screen lets you pick room type + lifetime + write an initial message,
///     then calls [ChatRepository.createDirectRequest] on first send.
class FriendRequestDraftScreen extends StatefulWidget {
  const FriendRequestDraftScreen({
    super.key,
    required this.repo,
    required this.api,
    this.req,
    this.target,
  }) : assert(req != null || target != null, 'either req or target is required');

  final ChatRepository repo;
  final ChatApi api;
  final FriendRequest? req;
  final ChatUser? target;

  @override
  State<FriendRequestDraftScreen> createState() => _FriendRequestDraftScreenState();
}

class _FriendRequestDraftScreenState extends State<FriendRequestDraftScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  List<FriendRequestMessage> _messages = [];
  Timer? _poll;

  // Compose-only state (when sending fresh)
  RoomType _roomType = RoomType.regular;
  Duration _ttl = const Duration(seconds: 60);
  String? _newRequestId;
  bool _busy = false;

  static const _ttls = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 5),
    Duration(hours: 1),
  ];

  String get _requestId => _newRequestId ?? widget.req?.id ?? '';
  ChatUser get _otherUser => widget.req?.user ?? widget.target!;

  @override
  void initState() {
    super.initState();
    if (widget.req != null) {
      _roomType = widget.req!.roomType;
      _ttl = widget.req!.messageLifetime ?? _ttl;
      _refresh();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    if (_requestId.isEmpty) return;
    try {
      final ms = await widget.api.listDirectRequestMessages(_requestId);
      if (!mounted) return;
      setState(() => _messages = ms);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (_) {}
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() => _busy = true);
    _composer.clear();

    try {
      if (_newRequestId == null && widget.req == null) {
        // Creating a fresh request with an initial message.
        final id = await widget.repo.createDirectRequest(
          friendId: widget.target!.id,
          roomType: _roomType,
          messageLifetime: _roomType == RoomType.secret ? _ttl : null,
          initialMessage: text,
        );
        setState(() => _newRequestId = id);
      } else {
        await widget.repo.appendDirectRequestMessage(
          requestId: _requestId,
          content: text,
        );
      }
      await _refresh();
    } catch (e) {
      // Re-fill composer so user doesn't lose what they typed.
      _composer.text = text;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    final nav = Navigator.of(context);
    final roomId = await widget.repo.approveDirectRequest(_otherUser.id);
    if (!mounted) return;
    if (roomId != null) {
      nav.pushReplacement(MaterialPageRoute(
          builder: (_) => RoomScreen(roomId: roomId, repo: widget.repo, api: widget.api)));
    } else {
      nav.pop();
    }
  }

  Future<void> _reject() async {
    final nav = Navigator.of(context);
    await widget.repo.rejectDirectRequest(_otherUser.id);
    if (!mounted) return;
    nav.pop();
  }

  Future<void> _cancel() async {
    final nav = Navigator.of(context);
    await widget.repo.cancelDirectRequest(_otherUser.id);
    if (!mounted) return;
    nav.pop();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _isIncoming => widget.req != null;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final me = widget.repo.userId ?? '';
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                _Header(user: _otherUser, isIncoming: _isIncoming, roomType: _roomType, ttl: _ttl, api: widget.api),
                if (!_isIncoming && _newRequestId == null) _ComposeConfig(
                  theme: theme,
                  roomType: _roomType,
                  ttl: _ttl,
                  onRoomType: (t) => setState(() => _roomType = t),
                  onTtl: (d) => setState(() => _ttl = d),
                  ttls: _ttls,
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) return _Intro(otherUser: _otherUser, isIncoming: _isIncoming);
                      final m = _messages[i - 1];
                      final isMine = m.userId == me;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isMine) ...[
                              UserAvatar(user: _otherUser, size: 28, api: widget.api),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                                  decoration: theme.messageBubbleDecoration(
                                      isMine: isMine, ephemeral: _roomType == RoomType.secret),
                                  child: Text(m.content,
                                      style: theme.body.copyWith(color: isMine ? theme.accentInk : theme.ink)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                if (_isIncoming) _ApproveBar(onApprove: _approve, onReject: _reject),
                _Composer(controller: _composer, onSend: _send, ephemeral: _roomType == RoomType.secret, ttl: _ttl, busy: _busy),
                if (!_isIncoming && _newRequestId != null) _CancelBar(onCancel: _cancel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.isIncoming,
    required this.roomType,
    required this.ttl,
    required this.api,
  });
  final ChatUser user;
  final bool isIncoming;
  final RoomType roomType;
  final Duration ttl;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.divider, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
          ),
          const SizedBox(width: 4),
          UserAvatar(user: user, size: 36, api: api),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: theme.displaySmall),
                Row(children: [
                  Text(isIncoming ? 'INCOMING REQUEST' : 'NEW REQUEST',
                      style: theme.monoTiny.copyWith(color: theme.accent)),
                  const SizedBox(width: 6),
                  if (roomType == RoomType.secret) EphemeralBadge(ttl: ttl, dense: true),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.otherUser, required this.isIncoming});
  final ChatUser otherUser;
  final bool isIncoming;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: theme.roomCardDecoration(ephemeral: false, active: false),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          isIncoming
              ? '${otherUser.displayName} wants to start a conversation.'
              : 'send a few lines. they can approve or decline.',
          style: theme.bodyEmph,
        ),
        const SizedBox(height: 8),
        Text(
          'nothing here lives anywhere permanent until both sides agree.',
          style: theme.bodySoft,
        ),
      ]),
    );
  }
}

class _ComposeConfig extends StatelessWidget {
  const _ComposeConfig({
    required this.theme,
    required this.roomType,
    required this.ttl,
    required this.onRoomType,
    required this.onTtl,
    required this.ttls,
  });
  final dynamic theme;
  final RoomType roomType;
  final Duration ttl;
  final ValueChanged<RoomType> onRoomType;
  final ValueChanged<Duration> onTtl;
  final List<Duration> ttls;

  String _fmt(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ROOM TYPE', style: theme.label),
          const SizedBox(height: 8),
          Row(children: [
            for (final t in RoomType.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onRoomType(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: theme.chipDecoration(filled: roomType == t),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (t == RoomType.secret) ...[
                        theme.hourglassIcon(size: 10, color: roomType == t ? theme.accentInk : theme.accent),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        t == RoomType.secret ? 'EPHEMERAL' : 'STANDARD',
                        style: theme.label.copyWith(
                            color: roomType == t ? theme.accentInk : theme.inkSoft),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
          if (roomType == RoomType.secret) ...[
            const SizedBox(height: 14),
            Row(children: [
              Text('LIFETIME', style: theme.label),
              const SizedBox(width: 10),
              Text(_fmt(ttl), style: theme.monoLarge.copyWith(color: theme.accent)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final t in ttls)
                GestureDetector(
                  onTap: () => onTtl(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: theme.chipDecoration(filled: ttl == t),
                    child: Text(_fmt(t),
                        style: theme.label.copyWith(
                            color: ttl == t ? theme.accentInk : theme.inkSoft)),
                  ),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.ephemeral,
    required this.ttl,
    required this.busy,
  });
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool ephemeral;
  final Duration ttl;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.divider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: theme.inputDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                controller: controller,
                style: theme.body.copyWith(color: theme.ink),
                cursorColor: theme.accent,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: ephemeral ? 'whisper · auto-fades' : 'something to start with…',
                  hintStyle: theme.body.copyWith(color: theme.inkMuted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: busy ? null : onSend,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: busy ? theme.accentSoft : theme.accent,
                shape: BoxShape.circle,
              ),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentInk),
                    )
                  : Icon(Icons.north_east, color: theme.accentInk, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApproveBar extends StatelessWidget {
  const _ApproveBar({required this.onApprove, required this.onReject});
  final VoidCallback onApprove;
  final VoidCallback onReject;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onApprove,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Text('APPROVE & OPEN ROOM',
                    style: theme.label.copyWith(color: theme.accentInk)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onReject,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: theme.divider),
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Text('DECLINE', style: theme.label),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelBar extends StatelessWidget {
  const _CancelBar({required this.onCancel});
  final VoidCallback onCancel;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onCancel,
        child: Text('CANCEL REQUEST',
            style: theme.label.copyWith(color: theme.danger)),
      ),
    );
  }
}
