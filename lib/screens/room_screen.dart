import 'dart:async';
import 'package:flutter/material.dart';
import '../data/mock_store.dart';
import '../models/room.dart';
import '../theme/theme_scope.dart';
import '../widgets/visibility_badge.dart';
import '../widgets/user_avatar.dart';
import '../widgets/message_bubble.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.roomId});
  final String roomId;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late Timer _ticker;
  DateTime _now = DateTime.now();
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      MockStore.instance.purgeExpiredMessages();
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    MockStore.instance.sendMessage(widget.roomId, text);
    _composer.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    final room = store.roomById(widget.roomId);
    if (room == null) {
      return Scaffold(backgroundColor: theme.background, body: Center(child: Text('room gone', style: theme.bodySoft)));
    }
    final messages = store.messagesFor(room.id, now: _now);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                _Header(room: room),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) return _RoomIntro(room: room);
                      final m = messages[i - 1];
                      return AnimatedSwitcher(
                        duration: theme.motionMed,
                        switchInCurve: theme.motionEntrance,
                        child: m.isEphemeral
                            ? EphemeralMessageBubble(key: ValueKey('e_${m.id}'), message: m, now: _now)
                            : MessageBubble(key: ValueKey('s_${m.id}'), message: m, now: _now),
                      );
                    },
                  ),
                ),
                _Composer(
                  controller: _composer,
                  ephemeral: room.isEphemeral,
                  ttl: room.ttl,
                  onSend: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.room});
  final Room room;
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
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name, style: theme.displayMedium),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    VisibilityBadge(isPublic: room.isPublic, dense: true),
                    if (room.isEphemeral) EphemeralBadge(ttl: room.ttl!, dense: true),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: theme.chipDecoration(),
                      child: Text('${room.memberIds.length} INSIDE', style: theme.monoTiny),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_horiz, color: theme.inkSoft, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RoomIntro extends StatelessWidget {
  const _RoomIntro({required this.room});
  final Room room;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final store = MockStore.instance;
    final members = room.memberIds.map(store.userById).toList();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (room.description != null) ...[
            Text('"${room.description!.toLowerCase()}"', style: theme.bodyEmph),
            const SizedBox(height: 14),
          ],
          if (room.isEphemeral) ...[
            Row(
              children: [
                theme.hourglassIcon(size: 14, color: theme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'this room is ephemeral. messages dissolve after ${_fmtTtl(room.ttl!)}, read or unread.',
                    style: theme.caption.copyWith(color: theme.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Wrap(
            spacing: -6,
            children: [
              for (var i = 0; i < members.take(6).length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 0),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.background, width: 1.5),
                    ),
                    child: UserAvatar(user: members[i], size: 26),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtTtl(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} seconds';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes';
    return '${d.inHours} hours';
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.ephemeral,
    required this.ttl,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool ephemeral;
  final Duration? ttl;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.divider, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ephemeral)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Row(
                children: [
                  theme.hourglassIcon(size: 10, color: theme.accent),
                  const SizedBox(width: 6),
                  Text(
                    'EPHEMERAL · ANYTHING YOU SEND FADES IN ${_fmt(ttl!)}',
                    style: theme.monoTiny.copyWith(color: theme.accent),
                  ),
                ],
              ),
            ),
          Row(
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
                      hintText: ephemeral ? 'whisper something the server will forget…' : 'say something…',
                      hintStyle: theme.body.copyWith(color: theme.inkMuted),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onSubmitted: (_) => onSend(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: theme.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: theme.accent.withValues(alpha: 0.40), blurRadius: 18, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Icon(Icons.north_east, color: theme.accentInk, size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }
}
