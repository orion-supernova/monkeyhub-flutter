import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../calls/call_button.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../family/family_service.dart';
import '../media/upload_service.dart';
import '../privacy/capture_protection.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/family.dart';
import '../data/ui_selection_store.dart';
import '../keyboard/focusable_tap.dart';
import '../keyboard/submit_on_enter.dart';
import '../platform.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/approval_gate.dart';
import '../widgets/attachment_menu.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/composer_reply_card.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_picker_sheet.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/remote_image.dart';
import '../widgets/swipe_to_reply.dart';
import '../widgets/thread_overlay.dart';
import '../widgets/user_avatar.dart';
import '../widgets/message_action_menu.dart';
import '../widgets/report_sheet.dart';
import '../widgets/visibility_badge.dart';
import 'camera_editor_screen.dart';
import 'camera_screen.dart';
import 'profile_screen.dart';
import 'room_info_screen.dart';
import 'voice_recorder_screen.dart';

/// Back affordance shared by both room headers. In the desktop two-pane layout
/// the room lives in the chat detail pane (never a full-screen route), so
/// "back" clears the pane selection; on compact it pops the pushed route.
void _roomBack(BuildContext context) {
  if (context.isExpanded) {
    UiSelectionStore.instance.selectRoom(null);
  } else {
    Navigator.of(context).maybePop();
  }
}

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key, required this.roomId, required this.repo, required this.api});
  final String roomId;
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen>
    with TickerProviderStateMixin {
  late Timer _ticker;
  DateTime _now = DateTime.now();
  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final Map<String, ChatUser> _members = {}; // id → user (for sender names/avatars)
  Subscription? _membersSub;
  String _membersSig = '';
  ChatRoom? _room;
  // True once we've pushed a CaptureProtection scope for this ephemeral
  // room — so dispose can pop exactly one and we don't double-push.
  bool _pushedCaptureScope = false;
  ChatStyle _lastChatStyle = SettingsStore.instance.chatStyle;

  // ──── floating date chip (visible while scrolling) ────
  // Renders the date of the topmost visible message as an overlay pill so
  // the user keeps date context when a single day's messages exceed the
  // viewport and the inline _DateDivider has scrolled off-screen. When a
  // real _DateDivider drifts through the chip's resting position, the chip
  // yields (fades/slides/shrinks) so the divider takes over momentarily —
  // see _recomputePositionState.
  final GlobalKey _listViewportKey = GlobalKey();
  final Map<String, _DateTrack> _dateTracks = {};
  String? _floatingLabel;
  bool _isActivelyScrolling = false;
  Timer? _hideTimer;
  // 0..1 — how much a real divider currently overlaps the chip's rect.
  double _dividerOverlap = 0;
  // Set during build; used by _recomputePositionState to know where the
  // chip "lives" so it can compute overlap with divider RenderBoxes.
  double _chipRestingY = 16;

  // ──── reply state ────
  // The message the composer is currently replying to. Cleared on cancel or
  // after a successful send. Set by the swipe gesture or the action menu.
  ChatMessage? _replyingTo;

  // The message currently pulsing under the scroll-to-parent highlight. The
  // pulse drives a 0→1→0 accent halo via [_highlightCtrl] over ~1s and then
  // clears itself. Multiple taps in flight cancel the previous pulse.
  String? _highlightedMessageId;
  late final AnimationController _highlightCtrl;

  // Lookup populated each build: messageId → its index in the (reversed)
  // items list. Lets us compute the "N MESSAGES ABOVE" hint on reply
  // indicators in O(1) without re-scanning the list per bubble.
  Map<String, int> _messageIndex = const {};

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _highlightCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )
      ..addListener(() {
        // Drive a per-frame rebuild only while a pulse is active; the
        // listener is cheap and runs for ~1s per user-initiated tap.
        if (_highlightedMessageId != null && mounted) setState(() {});
      })
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          if (!mounted) return;
          setState(() => _highlightedMessageId = null);
          _highlightCtrl.reset();
        }
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

    // Floating date chip: show while scrolling, fade out 800ms after the
    // last scroll event. Hidden when at the newest end (pixels < 8) since
    // the user already sees "TODAY" in the bottom-most divider there.
    final shouldShow = pos.pixels >= 8;
    _recomputePositionState();
    _hideTimer?.cancel();
    if (shouldShow) {
      if (!_isActivelyScrolling) {
        if (mounted) setState(() => _isActivelyScrolling = true);
      }
      _hideTimer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() => _isActivelyScrolling = false);
      });
    } else if (_isActivelyScrolling) {
      if (mounted) setState(() => _isActivelyScrolling = false);
    }
  }

  /// Single pass over every tracked item — picks the topmost date label
  /// AND measures how much the closest divider overlaps the chip's rect
  /// (0..1) so the chip can yield to a passing real divider.
  void _recomputePositionState() {
    final viewportCtx = _listViewportKey.currentContext;
    if (viewportCtx == null) return;
    final viewportBox = viewportCtx.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.attached) return;

    const chipHeight = 28.0;
    final chipTop = _chipRestingY;
    final chipBottom = chipTop + chipHeight;

    String? best;
    double bestDy = double.infinity;
    String? fallback;
    double fallbackDy = double.negativeInfinity;
    double maxOverlap = 0;

    for (final track in _dateTracks.values) {
      final ctx = track.key.currentContext;
      if (ctx == null) continue;
      final rb = ctx.findRenderObject() as RenderBox?;
      if (rb == null || !rb.attached) continue;
      final dy = rb.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
      final h = rb.size.height;
      final itemBottom = dy + h;

      // An item qualifies when its BOTTOM edge has reached the chip's
      // bottom edge. This places the date-flip moment exactly when the
      // divider's top crosses chipBottom — i.e., the divider has fully
      // exited the chip rect — so the message above it (which extends
      // down to the divider's top, now ≥ chipBottom) instantly takes
      // over as the new "topmost the user is reading." Picking by `dy
      // >= chipTop` alone left a ~one-message-height window where the
      // chip still showed the old date after a divider drifted past.
      if (itemBottom >= chipBottom) {
        if (dy < bestDy) {
          bestDy = dy;
          best = track.label;
        }
      } else if (dy > fallbackDy) {
        fallbackDy = dy;
        fallback = track.label;
      }

      if (track.isDivider) {
        final overlapPx =
            math.max(0.0, math.min(itemBottom, chipBottom) - math.max(dy, chipTop));
        final maxPossible = math.min(h, chipHeight);
        if (maxPossible > 0) {
          final pct = (overlapPx / maxPossible).clamp(0.0, 1.0);
          if (pct > maxOverlap) maxOverlap = pct;
        }
      }
    }

    final nextLabel = best ?? fallback;
    final labelChanged = nextLabel != null && nextLabel != _floatingLabel;
    final overlapChanged = (maxOverlap - _dividerOverlap).abs() > 0.01;
    if (labelChanged || overlapChanged) {
      if (mounted) {
        setState(() {
          if (labelChanged) _floatingLabel = nextLabel;
          _dividerOverlap = maxOverlap;
        });
      }
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
    _composerFocus.dispose();
    _highlightCtrl.dispose();
    _hideTimer?.cancel();
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
    // Snapshot reply-target BEFORE the async send. The card itself does NOT
    // auto-close on send — the user explicitly dismisses with the X. This
    // lets them fire off multiple replies to the same parent without re-
    // arming, which is the common pattern for back-and-forth in threads.
    final replyId = _replyingTo?.id;
    _composer.clear();
    await widget.repo.sendText(widget.roomId, text, replyToId: replyId);
    // A child guard rejection drops the optimistic bubble rather than leaving
    // it in the retry queue, so say why instead of letting the message just
    // vanish. Most likely a grant was revoked while the room was open.
    final gate = widget.repo.takeChildGateError();
    if (gate != null && mounted) {
      _composer.text = text; // don't lose what they wrote
      _keepComposerFocus();
      await _handleSendGate(gate);
      return;
    }
    _keepComposerFocus();
    _scrollToBottom();
  }

  /// Keep the caret in the composer after an Enter-send so the user can keep
  /// typing. Desktop only — on mobile the send button is the affordance and
  /// re-focusing would re-open the soft keyboard the user may have dismissed.
  void _keepComposerFocus() {
    if (!isPhysicalKeyboardPlatform || !mounted) return;
    if (!_composerFocus.hasFocus) _composerFocus.requestFocus();
  }

  /// A send was refused by a child guard. Two shapes: the room needs a
  /// grown-up's yes (most likely a grant was revoked, or the room gained a
  /// member from outside the family while it was open), or messaging is
  /// switched off outright. Only the first is worth asking about, and the
  /// ask has to actually raise a request — offering a button that does
  /// nothing would be worse than not offering one.
  Future<void> _handleSendGate(String gate) async {
    final uid = widget.repo.userId;
    final blockedOutright = isChildBlockedOutright(gate);
    final wantsToAsk = await showApprovalGate(
      context,
      what: 'send messages here',
      canAsk: !blockedOutright && uid != null,
    );
    if (!wantsToAsk || uid == null) return;
    try {
      await widget.api.requestApproval(
        childId: uid,
        kind: 'joinRoom',
        targetRoomId: widget.roomId,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('couldn\'t ask right now — try again')),
      );
    }
  }

  /// Arm a reply against [m]: a strong haptic + state change so the
  /// composer card slides into view. Idempotent — re-arming against the
  /// same message just replaces the target. The composer is focused on
  /// the next frame so the keyboard appears without a second tap.
  void _armReply(ChatMessage m) {
    HapticFeedback.heavyImpact();
    setState(() => _replyingTo = m);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _composerFocus.requestFocus();
    });
  }

  /// Compute a short hint like "2 MESSAGES ABOVE" / "EARLIER" for a reply's
  /// parent, based on the current items layout. Returns null when the
  /// parent isn't loaded — the reply indicator hides the suffix in that
  /// case rather than showing a stale number.
  String? _distanceLabelFor(ChatMessage child) {
    final parentId = child.replyToId;
    if (parentId == null) return null;
    final childIdx = _messageIndex[child.id];
    final parentIdx = _messageIndex[parentId];
    if (childIdx == null || parentIdx == null) return 'EARLIER';
    // items is reversed (newest at idx 0). Parent is older → larger index.
    final gap = parentIdx - childIdx - 1;
    if (gap <= 0) return 'ABOVE';
    if (gap == 1) return '1 MESSAGE ABOVE';
    if (gap <= 20) return '$gap MESSAGES ABOVE';
    return 'EARLIER';
  }

  /// Smoothly scroll to the parent message identified by [messageId], then
  /// fire a one-shot accent halo pulse on it. If the parent isn't currently
  /// in the items list, attempts up to 3 older-page loads before giving up.
  Future<void> _scrollToMessageAndHighlight(String messageId) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    for (var attempt = 0; attempt < 4; attempt++) {
      if (!mounted) return;
      final track = _dateTracks['m_$messageId'];
      final ctx = track?.key.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          alignment: 0.3,
        );
        if (!mounted) return;
        setState(() => _highlightedMessageId = messageId);
        _highlightCtrl.forward(from: 0);
        return;
      }
      // Parent not currently rendered — try paging older history.
      if (!widget.repo.hasMoreOlder(widget.roomId)) break;
      final got = await widget.repo.loadOlder(widget.roomId);
      if (got == 0) break;
      // Give the list one frame to mount the newly-prepended items.
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    messenger?.showSnackBar(
      const SnackBar(content: Text("original message not loaded")),
    );
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    // reverse:true → 0 is the bottom. Layout for the new bubble may not be
    // settled yet, but the bottom target is constant so the animation lands
    // cleanly regardless.
    _scroll.animateTo(0, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  Future<void> _onAttach() async {
    HapticFeedback.lightImpact();
    if (FamilyService.maybeInstance?.canSendMedia == false) {
      await showApprovalGate(
        context,
        what: 'send pictures or voice notes',
        canAsk: false,
      );
      return;
    }
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
    if (picked == null || !mounted) return;
    final nav = Navigator.of(context);
    // Route through the same editor the camera path uses — gives the user a
    // preview, optional annotation, and a deliberate "send" tap instead of
    // shipping the photo the moment they pick it.
    final edited = await nav.push<File>(MaterialPageRoute(
      builder: (_) => CameraEditorScreen(source: File(picked.path)),
    ));
    if (edited == null) return;
    await _uploadAndSend(file: edited, type: MessageType.image, contentType: 'image/png');
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
      // The reply card stays open across sends — see _send for the rationale.
      final replyId = _replyingTo?.id;
      final uploader = UploadService(widget.api);
      final storageId = await uploader.uploadXFile(file: file, contentType: contentType);
      await widget.repo.sendMedia(
        roomId: widget.roomId,
        storageId: storageId,
        type: type,
        replyToId: replyId,
      );
      _scrollToBottom();
    } catch (_) {
      /* TODO surface as toast */
    }
  }

  @override
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
    // Precompute id → index lookup for O(1) distance-hint computation in
    // the reply indicator. Re-derived per build (items rebuilds anyway).
    final idx = <String, int>{};
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      if (it is _MessageItem) idx[it.message.id] = i;
    }
    _messageIndex = idx;
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
          // Same column as the messages above, so the composer lines up with
          // the conversation instead of running the full width of the window.
          AdaptivePageBody(
            maxWidth: ContentWidth.roomDetail,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingTo != null)
                  ComposerReplyCard(
                    parent: _replyingTo!,
                    api: widget.api,
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
                _Composer(
                  controller: _composer,
                  focusNode: _composerFocus,
                  ephemeral: room.isEphemeral,
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
              child: AdaptivePageBody(
                maxWidth: ContentWidth.roomDetail,
                alignment: Alignment.center,
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
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AdaptivePageBody(
              maxWidth: ContentWidth.roomDetail,
              alignment: Alignment.center,
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Floats above the composer rather than adding to `chromeH`,
                // so the message list's padding stays correct and the pill
                // simply hovers over the last message while it's showing.
                TypingPill(
                  typists: widget.repo.typingIn(room.id),
                  api: widget.api,
                ),
                if (_replyingTo != null)
                  ComposerReplyCard(
                    parent: _replyingTo!,
                    api: widget.api,
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
                _LiquidComposer(
                  controller: _composer,
                  focusNode: _composerFocus,
                  ephemeral: room.isEphemeral,
                  onSend: _send,
                  onChanged: (_) => widget.repo.noteTyping(),
                  onAttach: _onAttach,
                ),
              ],
              ),
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
    final initialLoaded = widget.repo.hasLoadedInitial(widget.roomId);
    // Recorded for _recomputePositionState — must match the Positioned.top
    // applied to the chip below so the overlap math reflects the real rect.
    _chipRestingY = listPadding.top + 4;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Dismisses the soft keyboard when you tap the transcript. On desktop
      // there is no soft keyboard to dismiss, and stealing focus here would
      // silently break Enter-to-send after any click in the conversation.
      onTap: isPhysicalKeyboardPlatform
          ? null
          : () => FocusManager.instance.primaryFocus?.unfocus(),
      child: messages.isEmpty
          ? (!initialLoaded
                ? Center(
                    child: CircularProgressIndicator(
                      color: theme.accent,
                      strokeWidth: 2,
                    ),
                  )
                : (room.isEphemeral
                      ? _SecretSpaceWelcome(ttl: room.messageLifetime)
                      : const _NoMessagesPlaceholder()))
          : Stack(
              children: [
                // Centre the conversation into a readable column on wide
                // windows. Without this the list spans the whole pane, so a
                // sent and a received bubble sit pinned to opposite edges with
                // several hundred px of dead gutter between them — the bubbles
                // were already capped by messageMaxWidth, it was the column
                // around them that was missing. Pure passthrough on phones.
                AdaptivePageBody(
                  maxWidth: ContentWidth.roomDetail,
                  alignment: Alignment.center,
                  child: ListView.builder(
                  key: _listViewportKey,
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
                      return _trackedDate(
                        stableId: 'd_${item.label}',
                        label: item.label,
                        isDivider: true,
                        child: _DateDivider(label: item.label),
                      );
                    }
                    final m = (item as _MessageItem).message;
                final author = _members[m.senderId];
                final isMine = m.senderId == me;
                final othersRead = widget.repo.latestOthersReadAt;
                final seenByOthers = isMine && othersRead != null && !othersRead.isBefore(m.createdAt);
                final isPending = m.id.startsWith('tmp_');
                final canReply = !isPending &&
                    m.status == MessageStatus.sent &&
                    m.type != MessageType.system;
                final hasParent = m.isReply;
                final distanceLabel = _distanceLabelFor(m);
                final highlightT = (_highlightedMessageId == m.id)
                    ? _highlightCtrl.value
                    : 0.0;
                Future<void> onLongPress() async {
                  HapticFeedback.mediumImpact();
                  FocusManager.instance.primaryFocus?.unfocus();
                  final messenger = ScaffoldMessenger.of(context);
                  final anchor = _dateTracks['m_${m.id}']?.key;
                  if (anchor == null) return;
                  final result = await showMessageActionMenu(
                    context: context,
                    anchorKey: anchor,
                    isMine: isMine,
                    canCopy: m.type == MessageType.text && m.content.isNotEmpty,
                    canReply: canReply,
                    hasParent: hasParent,
                    bubbleBuilder: (_) {
                      final parentAuthor = m.isReply
                          ? _members[m.replyToPreview?.senderId]
                          : null;
                      return m.isEphemeral
                          ? EphemeralMessageBubble(
                              message: m,
                              now: _now,
                              currentUserId: me,
                              api: widget.api,
                              author: author,
                              parentAuthor: parentAuthor,
                              distanceLabel: distanceLabel,
                            )
                          : MessageBubble(
                              message: m,
                              now: _now,
                              currentUserId: me,
                              api: widget.api,
                              author: author,
                              parentAuthor: parentAuthor,
                              distanceLabel: distanceLabel,
                              seenByOthers: seenByOthers,
                            );
                    },
                  );
                  if (!mounted || result == null) return;
                  if (result.emoji != null) {
                    await widget.repo.toggleReaction(messageId: m.id, emoji: result.emoji!);
                    return;
                  }
                  if (result.openFullReactionPicker) {
                    final emoji = await showReactionPicker(this.context);
                    if (emoji == null || emoji.isEmpty) return;
                    await widget.repo.toggleReaction(messageId: m.id, emoji: emoji);
                    return;
                  }
                  switch (result.action!) {
                    case MessageAction.reply:
                      _armReply(m);
                      break;
                    case MessageAction.viewThread:
                      await showThreadOverlay(
                        context: this.context,
                        api: widget.api,
                        repo: widget.repo,
                        roomId: widget.roomId,
                        currentMessageId: m.id,
                        onReply: _armReply,
                      );
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

                final parentAuthor = m.isReply
                    ? _members[m.replyToPreview?.senderId]
                    : null;
                Future<void> onViewThread() => showThreadOverlay(
                      context: this.context,
                      api: widget.api,
                      repo: widget.repo,
                      roomId: widget.roomId,
                      currentMessageId: m.id,
                      onReply: _armReply,
                    );
                final bubble = m.isEphemeral
                    ? EphemeralMessageBubble(
                        key: ValueKey('e_${m.id}'),
                        message: m,
                        now: _now,
                        currentUserId: me,
                        api: widget.api,
                        author: author,
                        onLongPress: isPending ? null : onLongPress,
                        onDoubleTap: isPending ? null : onLongPress,
                        onReactionTap: onReactionTap,
                        onAuthorTap: author != null && !isMine ? onAuthorTap : null,
                        onReplyIndicatorTap: _scrollToMessageAndHighlight,
                        onViewThread: m.isReply ? onViewThread : null,
                        parentAuthor: parentAuthor,
                        distanceLabel: distanceLabel,
                        highlightT: highlightT,
                      )
                    : MessageBubble(
                        key: ValueKey('s_${m.id}'),
                        message: m,
                        now: _now,
                        currentUserId: me,
                        api: widget.api,
                        author: author,
                        onLongPress: isPending ? null : onLongPress,
                        onDoubleTap: isPending ? null : onLongPress,
                        onReactionTap: onReactionTap,
                        onAuthorTap: author != null && !isMine ? onAuthorTap : null,
                        onReplyIndicatorTap: _scrollToMessageAndHighlight,
                        onViewThread: m.isReply ? onViewThread : null,
                        parentAuthor: parentAuthor,
                        distanceLabel: distanceLabel,
                        highlightT: highlightT,
                        seenByOthers: seenByOthers,
                      );
                return _trackedDate(
                  stableId: 'm_${m.id}',
                  label: _humanDay(DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day)),
                  isDivider: false,
                  child: AnimatedSwitcher(
                    duration: theme.motionMed,
                    switchInCurve: theme.motionEntrance,
                    child: SwipeToReply(
                      key: ValueKey('sw_${m.id}'),
                      enabled: canReply,
                      onReplyTriggered: () => _armReply(m),
                      child: bubble,
                    ),
                  ),
                );
              },
                  ),
                ),
                Positioned(
                  // Anchor below the list's own top padding so the chip
                  // clears the classic Column header (top: 12) AND the
                  // liquid floating header (top: topSafe + chromeH + 12).
                  top: listPadding.top + 4,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      // AnimatedOpacity drives show/hide on scroll start /
                      // 800ms-idle. The inner Opacity + translate + scale
                      // follow `_dividerOverlap` in real time so the chip
                      // yields as a real _DateDivider crosses its rect.
                      child: AnimatedOpacity(
                        opacity: (_isActivelyScrolling && _floatingLabel != null) ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: Transform.translate(
                          offset: Offset(0, 14 * _dividerOverlap),
                          child: Transform.scale(
                            scale: 1 - 0.08 * _dividerOverlap,
                            child: Opacity(
                              opacity: (1 - _dividerOverlap).clamp(0.0, 1.0),
                              child: _FloatingDateChip(label: _floatingLabel ?? ''),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// Wrap a list item with a stable GlobalKey so _recomputePositionState
  /// can read its on-screen position. The stableId persists across rebuilds
  /// (m.id for messages, label for dividers) so child widget state (video,
  /// audio playback inside MessageBubble) survives pagination and sends.
  Widget _trackedDate({
    required String stableId,
    required String label,
    required bool isDivider,
    required Widget child,
  }) {
    var track = _dateTracks[stableId];
    if (track == null) {
      track = _DateTrack(GlobalKey(debugLabel: stableId), label, isDivider);
      _dateTracks[stableId] = track;
    } else {
      track.label = label;
    }
    return KeyedSubtree(key: track.key, child: child);
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
  final List<ChatUser> typing;
  final VoidCallback onOpenInfo;
  final ChatUser? dmUser;
  final ChatApi api;
  final VoidCallback? onTapDmUser;

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
            onPressed: () => _roomBack(context),
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
                        TypingDots(color: theme.accent),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            typingLabel(typing),
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
          if (room.isDm && dmUser != null)
            CallButton(
              peerUserId: dmUser!.id,
              peerName: dmUser!.displayName,
              roomId: room.id,
              variant: CallButtonVariant.classic,
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.ephemeral,
    required this.onSend,
    this.focusNode,
    this.onChanged,
    this.onAttach,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
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
            FocusableTap(
              onTap: onAttach,
              semanticLabel: 'Attach',
              shape: FocusRingShape.circle,
              child: GestureDetector(
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
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Container(
              decoration: theme.inputDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              // No `onSubmitted` here: a multi-line TextField never fires it —
              // Flutter turns Enter into a newline. SubmitOnEnter intercepts
              // the key instead, and leaves Shift+Enter as the newline.
              child: SubmitOnEnter(
                controller: controller,
                onSubmit: onSend,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
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
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FocusableTap(
            onTap: onSend,
            semanticLabel: 'Send',
            shape: FocusRingShape.circle,
            child: GestureDetector(
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

/// Tracks a list item's on-screen position via GlobalKey so the floating
/// date chip can read the topmost visible date. `label` is mutated in
/// place when day-rollover (midnight) flips "TODAY" → "YESTERDAY".
/// `isDivider` lets the recompute step apply the yield effect only when a
/// real _DateDivider overlaps the chip — message bubbles never cause yield.
class _DateTrack {
  _DateTrack(this.key, this.label, this.isDivider);
  final GlobalKey key;
  String label;
  final bool isDivider;
}

/// Floating date pill shown over the message list while the user scrolls.
/// Mirrors the inline _DateDivider's typography so the date string reads
/// the same whether it's inline or hovering — only the surface differs:
/// a blurred, accent-tinted pill that lifts off the messages.
class _FloatingDateChip extends StatelessWidget {
  const _FloatingDateChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.accentSoft,
            border: Border.all(color: theme.divider, width: 1),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.calendar, size: 11, color: theme.accent),
              const SizedBox(width: 6),
              Text(label, style: theme.monoTiny.copyWith(letterSpacing: 1.8)),
            ],
          ),
        ),
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
            onTap: () => _roomBack(context),
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
          if (widget.room.isDm && widget.dmUser != null) ...[
            CallButton(
              peerUserId: widget.dmUser!.id,
              peerName: widget.dmUser!.displayName,
              roomId: widget.room.id,
              variant: CallButtonVariant.liquid,
            ),
            const SizedBox(width: 12),
          ],
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
    this.focusNode,
    this.onChanged,
    this.onAttach,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
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
              // See _Composer above — multi-line fields never fire onSubmitted.
              child: SubmitOnEnter(
                controller: controller,
                onSubmit: onSend,
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
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
                ),
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

