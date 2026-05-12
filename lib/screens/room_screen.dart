import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../media/upload_service.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../theme/theme_scope.dart';
import '../widgets/attachment_menu.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_picker_sheet.dart';
import '../widgets/user_avatar.dart';
import '../widgets/message_action_sheet.dart';
import '../widgets/visibility_badge.dart';
import 'camera_editor_screen.dart';
import 'camera_screen.dart';
import 'room_info_screen.dart';
import 'voice_recorder_screen.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.roomId,
    required this.repo,
    required this.api,
  });
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
  ChatRoom? _room;
  bool _didInitialJump = false;

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
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // Trigger a page load when the user scrolls within 220px of the top.
    // ListView is built bottom-anchored visually (newest at the bottom), but
    // its scroll origin is the FIRST item (oldest) — so "near the top" means
    // pixels close to 0.
    if (_scroll.position.pixels <= 220 &&
        widget.repo.hasMoreOlder(widget.roomId) &&
        !widget.repo.isLoadingOlder(widget.roomId)) {
      final extentBefore = _scroll.position.maxScrollExtent;
      widget.repo.loadOlder(widget.roomId).then((added) {
        if (!mounted || added == 0) return;
        // Preserve visual position so the user doesn't get yanked downward
        // by the newly-prepended items: jump by the difference in extent.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scroll.hasClients) return;
          final delta = _scroll.position.maxScrollExtent - extentBefore;
          if (delta > 0) {
            _scroll.jumpTo(_scroll.position.pixels + delta);
          }
        });
      });
    }
  }

  Future<void> _loadMembers() async {
    try {
      final ms = await widget.api.getMembers(widget.roomId);
      if (!mounted) return;
      setState(() {
        _members.clear();
        for (final u in ms) {
          _members[u.id] = u;
        }
      });
    } catch (_) {/* ignore — initial fetch may fail offline */}
  }

  void _onRepoChange() {
    if (!mounted) return;
    setState(() {
      _room = widget.repo.roomById(widget.roomId);
    });
    // Land at the newest message on the first time we have content.
    if (!_didInitialJump && widget.repo.messagesFor(widget.roomId).isNotEmpty) {
      _didInitialJump = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    _composer.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    widget.repo.removeListener(_onRepoChange);
    widget.repo.closeRoom();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    _composer.clear();
    await widget.repo.sendText(widget.roomId, text);
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
        final captured = await nav.push<File>(
          MaterialPageRoute(builder: (_) => const CameraScreen()),
        );
        if (captured == null || !mounted) break;
        final edited = await nav.push<File>(
          MaterialPageRoute(builder: (_) => CameraEditorScreen(source: captured)),
        );
        if (edited != null) {
          await _uploadAndSend(
            file: edited,
            type: MessageType.image,
            contentType: 'image/png',
          );
        }
        break;
      case AttachmentMenuChoice.voice:
        final file = await nav.push<File>(
          MaterialPageRoute(builder: (_) => const VoiceRecorderScreen()),
        );
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
    await _uploadAndSend(
      file: File(picked.path),
      type: MessageType.image,
      contentType: 'image/jpeg',
    );
  }

  Future<void> _pickAndSendVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    await _uploadAndSend(
      file: File(picked.path),
      type: MessageType.video,
      contentType: 'video/mp4',
    );
  }

  Future<void> _uploadAndSend({
    required File file,
    required MessageType type,
    required String contentType,
  }) async {
    try {
      final uploader = UploadService(widget.api);
      final storageId = await uploader.uploadXFile(file: file, contentType: contentType);
      await widget.repo.sendMedia(
        roomId: widget.roomId,
        storageId: storageId,
        type: type,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
        }
      });
    } catch (_) {/* TODO surface as toast */}
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: Column(
              children: [
                _Header(
                  room: room,
                  typing: widget.repo.typingIn(room.id),
                  dmUser: widget.repo.otherUserFor(room),
                  api: widget.api,
                  onOpenInfo: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoomInfoScreen(
                          roomId: room.id,
                          repo: widget.repo,
                          api: widget.api,
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return _RoomIntro(
                          room: room,
                          members: _members.values.toList(),
                          api: widget.api,
                        );
                      }
                      final m = messages[i - 1];
                      final author = _members[m.senderId];
                      final isMine = m.senderId == me;
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
                            messenger.showSnackBar(
                              const SnackBar(content: Text('copied')),
                            );
                            break;
                          case MessageAction.delete:
                            await widget.repo.deleteMessage(m.id);
                            break;
                        }
                      }
                      void onReactionTap(String e) {
                        widget.repo.toggleReaction(messageId: m.id, emoji: e);
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
                              ),
                      );
                    },
                  ),
                ),
                _Composer(
                  controller: _composer,
                  ephemeral: room.isEphemeral,
                  ttl: room.messageLifetime,
                  onSend: _send,
                  onChanged: (_) => widget.repo.noteTyping(),
                  onAttach: _onAttach,
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
  const _Header({
    required this.room,
    required this.typing,
    required this.onOpenInfo,
    required this.api,
    this.dmUser,
  });
  final ChatRoom room;
  final List<String> typing;
  final VoidCallback onOpenInfo;
  final ChatUser? dmUser;
  final ChatApi api;

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
            UserAvatar(user: dmUser!, size: 32, api: api),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dmUser?.displayName ?? room.name,
                  style: theme.displayMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (dmUser != null)
                      Text('@${dmUser!.username}',
                          style: theme.monoTiny.copyWith(color: theme.inkMuted))
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
                  Row(children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: _TypingDots(color: theme.accent),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _typingLabel(),
                        style: theme.monoTiny.copyWith(color: theme.accent),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ],
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

class _RoomIntro extends StatelessWidget {
  const _RoomIntro({required this.room, required this.members, required this.api});
  final ChatRoom room;
  final List<ChatUser> members;
  final ChatApi api;

  static String _fmtTtl(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds} seconds';
    if (d.inMinutes < 60) return '${d.inMinutes} minutes';
    return '${d.inHours} hours';
  }

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
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
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
    required this.ttl,
    required this.onSend,
    this.onChanged,
    this.onAttach,
  });
  final TextEditingController controller;
  final bool ephemeral;
  final Duration? ttl;
  final VoidCallback onSend;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onAttach;

  static String _fmt(Duration d) {
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }

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
          if (ephemeral && ttl != null)
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
                    onChanged: onChanged,
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
}
