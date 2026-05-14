import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../media/upload_service.dart';
import '../privacy/capture_protection.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../theme/theme_scope.dart';
import '../widgets/attachment_menu.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_picker_sheet.dart';
import '../widgets/remote_image.dart';
import '../widgets/user_avatar.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/report_sheet.dart';
import '../widgets/visibility_badge.dart';
import 'camera_editor_screen.dart';
import 'camera_screen.dart';
import 'profile_screen.dart';
import 'room_info_screen.dart';
import 'voice_recorder_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.roomId, required this.repo, required this.api});
  final String roomId;
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late Timer _ticker;
  DateTime _now = DateTime.now();
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final Map<String, ChatUser> _members = {}; // id → user (for sender names/avatars)
  Subscription? _membersSub;
  String _membersSig = '';
  ChatRoom? _room;
  // True once we've pushed a CaptureProtection scope for this ephemeral
  // room — so dispose can pop exactly one and we don't double-push.
  bool _pushedCaptureScope = false;
  ChatStyle _lastChatStyle = SettingsStore.instance.chatStyle;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    widget.repo.openRoom(widget.roomId);
    _loadMembers();
    widget.repo.addListener(_onRepoChange);
    _scroll.addListener(_onScroll);
    SettingsStore.instance.addListener(_onSettings);
    // If the room is already in the rooms cache from the subscription, we
    // can push the capture scope immediately. Otherwise _onRepoChange will
    // pick it up on the first notification.
    _maybePushCaptureScope(widget.repo.roomById(widget.roomId));
  }

  void _onSettings() {
    final cs = SettingsStore.instance.chatStyle;
    if (cs == _lastChatStyle) return;
    _lastChatStyle = cs;
    if (mounted) setState(() {});
  }

  void _maybePushCaptureScope(ChatRoom? room) {
    if (_pushedCaptureScope) return;
    if (room == null) return;
    if (!room.isEphemeral) return;
    _pushedCaptureScope = true;
    // CaptureProtection defers its listener notification internally, so
    // calling this from initState / _onRepoChange / dispose is safe.
    CaptureProtection.instance.pushScope();
  }

  /// Flatten the message list into intro / date-divider / message items.
  /// A divider is inserted whenever consecutive messages cross a date
  /// boundary in the user's local time.
  List<_RoomItem> _buildItems(ChatRoom room, List<ChatMessage> messages) {
    final out = <_RoomItem>[_IntroItem()];
    DateTime? lastDay;
    for (final m in messages) {
      final d = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || d != lastDay) {
        out.add(_DateDividerItem(_humanDay(d)));
        lastDay = d;
      }
      out.add(_MessageItem(m));
    }
    return out;
  }

  String _humanDay(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (d == today) return 'TODAY';
    if (d == yesterday) return 'YESTERDAY';
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final sameYear = d.year == now.year;
    return sameYear ? '${months[d.month - 1]} ${d.day}' : '${months[d.month - 1]} ${d.day} · ${d.year}';
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // The list is rendered with reverse:true — items[0] (newest) sits at the
    // bottom, pixels=0 is the bottom, maxScrollExtent is the top. Trigger an
    // older-page load when the user scrolls within 220px of the top.
    // Position preservation is automatic in reverse mode: older messages are
    // appended to the END of the items list, so the user's pixel offset
    // (anchored from the bottom) is unaffected.
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 220 &&
        widget.repo.hasMoreOlder(widget.roomId) &&
        !widget.repo.isLoadingOlder(widget.roomId)) {
      widget.repo.loadOlder(widget.roomId);
    }
  }

  Future<void> _loadMembers() async {
    // Live subscription so each member's presence (status/lastSeen) and
    // any add/remove flows through without needing to re-enter the room.
    //
    // Convex re-fires whenever any roomMembers row is written — including
    // read-receipts from `markRoomRead`, which happen on every incoming
    // message while someone is in the room. We don't render lastReadAt
    // here, so we dedup on the fields we actually use and skip the rebuild
    // when nothing material has changed. Without this, rebuilds during an
    // active chat scroll can jitter the bouncing physics at edges.
    try {
      _membersSub?.cancel();
      _membersSub = await widget.repo.cv.subscribe(
        'rooms:getMembers',
        {'roomId': widget.roomId},
        onData: (data) {
          if (!mounted) return;
          final list = (data as List?) ?? const [];
          final fresh = list
              .map((e) => ChatUser.fromJson((e as Map).cast<String, dynamic>()))
              .toList();
          final sig = _signatureFor(fresh);
          if (sig == _membersSig) return;
          _membersSig = sig;
          setState(() {
            _members.clear();
            for (final u in fresh) {
              _members[u.id] = u;
            }
          });
        },
        onError: (err) => debugPrint('members sub error: $err'),
      );
    } catch (_) {
      /* ignore — initial fetch may fail offline */
    }
  }

  String _signatureFor(List<ChatUser> users) {
    final parts = users
        .map((u) =>
            '${u.id}|${u.status ?? ''}|${u.lastSeen?.millisecondsSinceEpoch ?? 0}|${u.name}|${u.avatarStorageId ?? ''}|${u.role ?? ''}')
        .toList()
      ..sort();
    return parts.join(';');
  }

  void _onRepoChange() {
    if (!mounted) return;
    final room = widget.repo.roomById(widget.roomId);
    setState(() {
      _room = room;
    });
    _maybePushCaptureScope(room);
    // With reverse:true the viewport naturally starts at the bottom (newest
    // message). No initial jumpTo needed.
  }

  @override
  void dispose() {
    _ticker.cancel();
    _composer.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _membersSub?.cancel();
    widget.repo.removeListener(_onRepoChange);
    SettingsStore.instance.removeListener(_onSettings);
    widget.repo.closeRoom();
    if (_pushedCaptureScope) {
      CaptureProtection.instance.popScope();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    await widget.repo.sendText(widget.roomId, text);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    // reverse:true → 0 is the bottom. Layout for the new bubble may not be
    // settled yet, but the bottom target is constant so the animation lands
    // cleanly regardless.
    _scroll.animateTo(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Future<void> _onAttach() async {
    final choice = await showAttachmentMenu(context);
    if (choice == null || !mounted) return;
    final nav = Navigator.of(context);
    switch (choice) {
      case AttachmentMenuChoice.gallery:
        await _pickAndSendFromGallery();
        break;
      case AttachmentMenuChoice.video:
        await _pickAndSendVideo();
        break;
      case AttachmentMenuChoice.camera:
        final captured = await nav.push<File>(MaterialPageRoute(builder: (_) => const CameraScreen()));
        if (captured == null || !mounted) break;
        final edited = await nav.push<File>(MaterialPageRoute(builder: (_) => CameraEditorScreen(source: captured)));
        if (edited != null) {
          await _uploadAndSend(file: edited, type: MessageType.image, contentType: 'image/png');
        }
        break;
      case AttachmentMenuChoice.voice:
        final file = await nav.push<File>(MaterialPageRoute(builder: (_) => const VoiceRecorderScreen()));
        if (file != null) {
          await _uploadAndSend(file: file, type: MessageType.audio, contentType: 'audio/m4a');
        }
        break;
    }
  }

  Future<void> _pickAndSendFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88);
    if (picked == null) return;
    await _uploadAndSend(file: File(picked.path), type: MessageType.image, contentType: 'image/jpeg');
  }

  void _openProfile(ChatUser u) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(user: u, repo: widget.repo, api: widget.api),
      ),
    );
  }

  Future<void> _pickAndSendVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    await _uploadAndSend(file: File(picked.path), type: MessageType.video, contentType: 'video/mp4');
  }

  Future<void> _uploadAndSend({required File file, required MessageType type, required String contentType}) async {
    try {
      final uploader = UploadService(widget.api);
      final storageId = await uploader.uploadXFile(file: file, contentType: contentType);
      await widget.repo.sendMedia(roomId: widget.roomId, storageId: storageId, type: type);
      _scrollToBottom();
    } catch (_) {
      /* TODO surface as toast */
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final room = _room ?? widget.repo.roomById(widget.roomId);
    if (room == null) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(child: Text('room gone', style: theme.bodySoft)),
      );
    }
    final messages = widget.repo.messagesFor(widget.roomId);
    final me = widget.repo.userId ?? '';
    // ListView is rendered with reverse:true so the viewport naturally
    // anchors to the newest message at the bottom. The items list is built
    // chronologically (intro → divider → messages) and reversed here so
    // items[0] is the newest message (visually at the bottom) and the intro
    // ends up at items[last] (visually at the top).
    final items = messages.isEmpty ? const <_RoomItem>[] : _buildItems(room, messages).reversed.toList();
    final chatStyle = SettingsStore.instance.chatStyle;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          if (chatStyle == ChatStyle.classic)
            _buildClassic(context, room, messages, items, me)
          else
            _buildLiquid(context, room, messages, items, me),
        ],
      ),
    );
  }

  Widget _buildClassic(BuildContext context, ChatRoom room, List<ChatMessage> messages, List<_RoomItem> items, String me) {
    return SafeArea(
      child: Column(
        children: [
          _Header(
            room: room,
            typing: widget.repo.typingIn(room.id),
            dmUser: widget.repo.otherUserFor(room),
            api: widget.api,
            onTapDmUser: () {
              final u = widget.repo.otherUserFor(room);
              if (u == null) return;
              _openProfile(u);
            },
            onOpenInfo: () => _openRoomInfo(room),
          ),
          Expanded(
            child: _messageBody(
              context,
              room,
              messages,
              items,
              me,
              listPadding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            ),
          ),
          _Composer(
            controller: _composer,
            ephemeral: room.isEphemeral,
            onSend: _send,
            onChanged: (_) => widget.repo.noteTyping(),
            onAttach: _onAttach,
          ),
        ],
      ),
    );
  }

  Widget _buildLiquid(BuildContext context, ChatRoom room, List<ChatMessage> messages, List<_RoomItem> items, String me) {
    final topSafe = MediaQuery.paddingOf(context).top;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // Header: 8pt top + 44pt button + 8pt bottom = 60pt; composer: same.
    // Scaffold's default resizeToAvoidBottomInset shrinks the body when the
    // keyboard appears, so we DO NOT add viewInsets manually — that would
    // double-count and leave a massive gap.
    const chromeH = 60.0;
    final listPadding = EdgeInsets.fromLTRB(
      20,
      topSafe + chromeH + 12,
      20,
      chromeH + 16 + bottomSafe,
    );
    // BackdropGroup batches the six BackdropFilters in the chrome (header
    // pill + 2 buttons + composer attach + field + send) into a single
    // rasterization pass — see lib/widgets/liquid_glass.dart for details.
    return BackdropGroup(
      child: Stack(
        children: [
          Positioned.fill(
            child: _messageBody(context, room, messages, items, me, listPadding: listPadding),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: _LiquidHeader(
                room: room,
                dmUser: widget.repo.otherUserFor(room),
                api: widget.api,
                onTapDmUser: () {
                  final u = widget.repo.otherUserFor(room);
                  if (u == null) return;
                  _openProfile(u);
                },
                onOpenInfo: () => _openRoomInfo(room),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _LiquidComposer(
              controller: _composer,
              ephemeral: room.isEphemeral,
              onSend: _send,
              onChanged: (_) => widget.repo.noteTyping(),
              onAttach: _onAttach,
            ),
          ),
        ],
      ),
    );
  }

  void _openRoomInfo(ChatRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoomInfoScreen(roomId: room.id, repo: widget.repo, api: widget.api),
      ),
    );
  }

  Widget _messageBody(
    BuildContext context,
    ChatRoom room,
    List<ChatMessage> messages,
    List<_RoomItem> items,
    String me, {
    required EdgeInsets listPadding,
  }) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: messages.isEmpty
          ? (room.isEphemeral
                ? _SecretSpaceWelcome(ttl: room.messageLifetime)
                : const _NoMessagesPlaceholder())
          : ListView.builder(
              controller: _scroll,
              reverse: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: listPadding,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                if (item is _IntroItem) {
                  return _RoomIntro(room: room, members: _members.values.toList(), api: widget.api);
                }
                if (item is _DateDividerItem) {
                  return _DateDivider(label: item.label);
                }
                final m = (item as _MessageItem).message;
                final author = _members[m.senderId];
                final isMine = m.senderId == me;
                final othersRead = widget.repo.latestOthersReadAt;
                final seenByOthers = isMine && othersRead != null && !othersRead.isBefore(m.createdAt);
                Future<void> onLongPress() async {
                  final messenger = ScaffoldMessenger.of(context);
                  final action = await showMessageActionSheet(
                    context,
                    isMine: isMine,
                    canCopy: m.type == MessageType.text && m.content.isNotEmpty,
                  );
                  if (!mounted || action == null) return;
                  switch (action) {
                    case MessageAction.react:
                      final emoji = await showReactionPicker(this.context);
                      if (emoji == null || emoji.isEmpty) return;
                      await widget.repo.toggleReaction(messageId: m.id, emoji: emoji);
                      break;
                    case MessageAction.copy:
                      await Clipboard.setData(ClipboardData(text: m.content));
                      messenger.showSnackBar(const SnackBar(content: Text('copied')));
                      break;
                    case MessageAction.delete:
                      await widget.repo.deleteMessage(m.id);
                      break;
                    case MessageAction.viewProfile:
                      if (author != null) _openProfile(author);
                      break;
                    case MessageAction.report:
                      final reason = await showReportSheet(this.context);
                      if (reason == null || reason.isEmpty) return;
                      final myId = widget.repo.userId;
                      if (myId == null) return;
                      try {
                        await widget.api.report(
                          reporterId: myId,
                          targetType: 'message',
                          targetId: m.id,
                          reason: reason,
                        );
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(content: Text('report sent privately. they won\'t be notified.')),
                        );
                      } catch (_) {}
                      break;
                  }
                }

                void onReactionTap(String e) {
                  widget.repo.toggleReaction(messageId: m.id, emoji: e);
                }

                void onAuthorTap() {
                  if (author == null || isMine) return;
                  _openProfile(author);
                }

                return AnimatedSwitcher(
                  duration: theme.motionMed,
                  switchInCurve: theme.motionEntrance,
                  child: m.isEphemeral
                      ? EphemeralMessageBubble(
                          key: ValueKey('e_${m.id}'),
                          message: m,
                          now: _now,
                          currentUserId: me,
                          api: widget.api,
                          author: author,
                          onLongPress: m.id.startsWith('tmp_') ? null : onLongPress,
                          onReactionTap: onReactionTap,
                          onAuthorTap: author != null && !isMine ? onAuthorTap : null,
                        )
                      : MessageBubble(
                          key: ValueKey('s_${m.id}'),
                          message: m,
                          now: _now,
                          currentUserId: me,
                          api: widget.api,
                          author: author,
                          onLongPress: m.id.startsWith('tmp_') ? null : onLongPress,
                          onReactionTap: onReactionTap,
                          onAuthorTap: author != null && !isMine ? onAuthorTap : null,
                          seenByOthers: seenByOthers,
                        ),
                );
              },
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.room,
    required this.typing,
    required this.onOpenInfo,
    required this.api,
    this.dmUser,
    this.onTapDmUser,
  });
  final ChatRoom room;
  final List<String> typing;
  final VoidCallback onOpenInfo;
  final ChatUser? dmUser;
  final ChatApi api;
  final VoidCallback? onTapDmUser;

  String _typingLabel() {
    if (typing.isEmpty) return '';
    if (typing.length == 1) return '${typing.first} is typing…';
    if (typing.length == 2) return '${typing[0]} and ${typing[1]} are typing…';
    return '${typing.first} and ${typing.length - 1} others are typing…';
  }

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
          if (dmUser != null) ...[
            GestureDetector(
              onTap: onTapDmUser,
              child: UserAvatar(user: dmUser!, size: 32, api: api),
            ),
            const SizedBox(width: 10),
          ] else ...[
            _RoomAvatar(room: room, api: api, size: 32),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: GestureDetector(
              onTap: dmUser != null ? onTapDmUser : null,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dmUser?.displayName ?? room.name, style: theme.displayMedium, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (dmUser != null)
                        Text('@${dmUser!.username}', style: theme.monoTiny.copyWith(color: theme.inkMuted))
                      else ...[
                        VisibilityBadge(isPublic: room.isPublic, dense: true),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: theme.chipDecoration(),
                          child: Text('${room.memberCount} INSIDE', style: theme.monoTiny),
                        ),
                      ],
                      if (room.isEphemeral && room.messageLifetime != null)
                        EphemeralBadge(ttl: room.messageLifetime!, dense: true),
                    ],
                  ),
                  if (typing.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        SizedBox(width: 14, height: 14, child: _TypingDots(color: theme.accent)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _typingLabel(),
                            style: theme.monoTiny.copyWith(color: theme.accent),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onOpenInfo,
            icon: Icon(Icons.more_horiz, color: theme.inkSoft, size: 18),
          ),
        ],
      ),
    );
  }
}

String _fmtTtl(Duration d) {
  if (d.inSeconds < 60) return '${d.inSeconds} seconds';
  if (d.inMinutes < 60) return '${d.inMinutes} minutes';
  return '${d.inHours} hours';
}

class _RoomIntro extends StatelessWidget {
  const _RoomIntro({required this.room, required this.members, required this.api});
  final ChatRoom room;
  final List<ChatUser> members;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (room.description != null && room.description!.isNotEmpty) ...[
            Text('"${room.description!.toLowerCase()}"', style: theme.bodyEmph),
            const SizedBox(height: 14),
          ],
          if (room.isEphemeral && room.messageLifetime != null) ...[
            Row(
              children: [
                theme.hourglassIcon(size: 14, color: theme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'this room is ephemeral. messages dissolve after ${_fmtTtl(room.messageLifetime!)}, read or unread.',
                    style: theme.caption.copyWith(color: theme.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          if (members.isNotEmpty)
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
                      child: UserAvatar(user: members[i], size: 26, api: api),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});
  final Color color;
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((t * 3) - i).clamp(0.0, 1.0);
            final a = (0.3 + 0.7 * (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0));
            return Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 2),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: a),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.ephemeral,
    required this.onSend,
    this.onChanged,
    this.onAttach,
  });
  final TextEditingController controller;
  final bool ephemeral;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.divider, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onAttach != null) ...[
            GestureDetector(
              onTap: onAttach,
              child: Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.surfaceRaised,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.divider),
                ),
                child: Icon(Icons.add, color: theme.inkSoft, size: 18),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Container(
              decoration: theme.inputDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: theme.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.accent.withValues(alpha: 0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.north_east, color: theme.accentInk, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── list item model ─────────────────────────

abstract class _RoomItem {}

class _IntroItem extends _RoomItem {}

class _DateDividerItem extends _RoomItem {
  _DateDividerItem(this.label);
  final String label;
}

class _MessageItem extends _RoomItem {
  _MessageItem(this.message);
  final ChatMessage message;
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: theme.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label, style: theme.monoTiny.copyWith(letterSpacing: 1.8)),
          ),
          Expanded(child: Container(height: 1, color: theme.divider)),
        ],
      ),
    );
  }
}

// ───────────────────────── empty-state views ─────────────────────────

class _SecretSpaceWelcome extends StatelessWidget {
  const _SecretSpaceWelcome({this.ttl});
  final Duration? ttl;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return LayoutBuilder(
      builder: (context, viewport) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: viewport.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Frosted glass disc — v02's `key.shield` over `.ultraThinMaterial`.
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        width: 100,
                        height: 100,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: theme.accent.withValues(alpha: 0.06)),
                        child: Icon(CupertinoIcons.lock_shield, size: 40, color: theme.accent.withValues(alpha: 0.75)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Secret Space',
                    style: theme.displayMedium.copyWith(color: theme.ink, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Messages in this room are ephemeral. They are automatically removed based on the room's security policy.",
                    style: theme.body.copyWith(color: theme.inkMuted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _PrivateFeatureCard(
                            icon: CupertinoIcons.timer,
                            title: 'Auto-Delete',
                            subtitle: ttl != null ? 'Varies' : 'Timed',
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: _PrivateFeatureCard(
                            icon: CupertinoIcons.hand_raised_fill,
                            title: 'No Capture',
                            subtitle: 'Screenshots Restricted',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _PrivateFeatureCard(
                    icon: CupertinoIcons.lock_fill,
                    title: 'Much More Privacy',
                    subtitle: 'Enjoy extra security features on top of already existing privacy focus.',
                    isFullWidth: true,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PrivateFeatureCard extends StatelessWidget {
  const _PrivateFeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isFullWidth = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // v02's PrivateFeatureCard: 32px disc, faint accent fill, accent-tinted glyph.
    final iconFrame = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: theme.accent.withValues(alpha: 0.08)),
      child: Icon(icon, size: 18, color: theme.accent.withValues(alpha: 0.85)),
    );

    final Widget body = isFullWidth
        ? Row(
            children: [
              iconFrame,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.caption.copyWith(color: theme.ink, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.caption.copyWith(color: theme.inkMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconFrame,
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.caption.copyWith(color: theme.ink, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.caption.copyWith(color: theme.inkMuted, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(minHeight: isFullWidth ? 0 : 118),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.accent.withValues(alpha: 0.18)),
          ),
          child: body,
        ),
      ),
    );
  }
}

class _NoMessagesPlaceholder extends StatelessWidget {
  const _NoMessagesPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.bubble_left, size: 44, color: theme.inkMuted),
          const SizedBox(height: 14),
          Text('No Messages', style: theme.bodyEmph.copyWith(color: theme.inkSoft)),
          const SizedBox(height: 6),
          Text(
            'Start the conversation by sending a message',
            style: theme.body.copyWith(color: theme.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── liquid variant chrome ─────────────────────────

class _LiquidHeader extends StatefulWidget {
  const _LiquidHeader({
    required this.room,
    required this.api,
    required this.onOpenInfo,
    this.dmUser,
    this.onTapDmUser,
  });
  final ChatRoom room;
  final ChatApi api;
  final VoidCallback onOpenInfo;
  final ChatUser? dmUser;
  final VoidCallback? onTapDmUser;

  @override
  State<_LiquidHeader> createState() => _LiquidHeaderState();
}

class _LiquidHeaderState extends State<_LiquidHeader> {
  bool _expanded = false;
  Timer? _collapseTimer;

  void _expandTitle() {
    setState(() => _expanded = true);
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final title = widget.dmUser?.displayName ?? widget.room.name;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          LiquidGlass(
            shape: LiquidGlassShape.circle,
            size: const Size(44, 44),
            onTap: () => Navigator.of(context).maybePop(),
            child: Icon(Icons.arrow_back, size: 18, color: theme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Center(
              // IntrinsicWidth makes LiquidGlass shrink-wrap its content
              // (LiquidGlass's internal Center would otherwise expand to fill
              // whatever bounded width it gets, which is why a short title
              // still produced a full-width capsule). When the title is long
              // IntrinsicWidth clamps to the parent's max, so the inner
              // Flexible(Text) ellipsizes inside the capsule's max width.
              child: IntrinsicWidth(
                child: LiquidGlass(
                  shape: LiquidGlassShape.capsule,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  onTap: _expandTitle,
                  child: AnimatedSize(
                    duration: theme.motionMed,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.dmUser != null)
                          UserAvatar(user: widget.dmUser!, size: 32, api: widget.api)
                        else
                          _RoomAvatar(room: widget.room, api: widget.api, size: 32),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            style: theme.body.copyWith(fontWeight: FontWeight.w600, color: theme.ink),
                            overflow: _expanded ? TextOverflow.fade : TextOverflow.ellipsis,
                            softWrap: _expanded,
                            maxLines: _expanded ? 3 : 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          LiquidGlass(
            shape: LiquidGlassShape.circle,
            size: const Size(44, 44),
            onTap: widget.onOpenInfo,
            child: Icon(Icons.info_outline, size: 18, color: theme.accent),
          ),
        ],
      ),
    );
  }
}

class _LiquidComposer extends StatelessWidget {
  const _LiquidComposer({
    required this.controller,
    required this.ephemeral,
    required this.onSend,
    this.onChanged,
    this.onAttach,
  });
  final TextEditingController controller;
  final bool ephemeral;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // Scaffold handles the keyboard via resizeToAvoidBottomInset — the body
    // shrinks and `bottomSafe` is already reduced to 0 when the keyboard
    // covers the home indicator. Adding viewInsets here would double-count.
    final pad = EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomSafe);
    return Padding(
      padding: pad,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onAttach != null) ...[
            LiquidGlass(
              shape: LiquidGlassShape.circle,
              size: const Size(44, 44),
              onTap: onAttach,
              child: Icon(Icons.add, size: 18, color: theme.accent),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: LiquidGlass(
              shape: LiquidGlassShape.rounded,
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: TextField(
                controller: controller,
                style: theme.body.copyWith(color: theme.ink, fontSize: 16),
                cursorColor: theme.accent,
                minLines: 1,
                maxLines: 5,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: ephemeral ? 'whisper something the server will forget…' : 'Message',
                  hintStyle: theme.body.copyWith(color: theme.inkMuted),
                ),
                onChanged: onChanged,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          LiquidGlass(
            shape: LiquidGlassShape.circle,
            size: const Size(44, 44),
            tinted: true,
            onTap: onSend,
            child: Icon(Icons.arrow_upward, size: 18, color: theme.accentInk),
          ),
        ],
      ),
    );
  }
}

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({required this.room, required this.api, this.size = 32});
  final ChatRoom room;
  final ChatApi? api;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final hasRemote = api != null &&
        room.avatarStorageId != null &&
        room.avatarStorageId!.isNotEmpty;
    if (hasRemote) {
      return ClipOval(
        child: RemoteImage(
          storageId: room.avatarStorageId!,
          api: api!,
          width: size,
          height: size,
          borderRadius: BorderRadius.circular(size / 2),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.accent.withValues(alpha: 0.10),
      ),
      child: room.isEphemeral
          ? theme.hourglassIcon(size: size * 0.56, color: theme.accent)
          : Icon(Icons.tag, size: size * 0.56, color: theme.accent),
    );
  }
}

