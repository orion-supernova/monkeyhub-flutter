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
import '../backend/group_call_api.dart';
import '../calls/call_button.dart';
import '../calls/group_call_banner.dart';
import '../calls/group_call_button.dart';
import '../calls/group_call_service.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../family/family_service.dart';
import '../media/image_raster.dart';
import '../media/upload_service.dart';
import '../privacy/capture_protection.dart';
import '../models/chat_message.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/family.dart';
import '../data/ui_selection_store.dart';
import '../platform.dart';
import '../theme/layout.dart';
import 'room_items.dart';
import '../theme/theme_scope.dart';
import '../widgets/anchored_scroll.dart';
import '../widgets/approval_gate.dart';
import '../widgets/attachment_menu.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_pane.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/composer_reply_card.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_picker_sheet.dart';
import '../widgets/scroll_to_latest.dart';
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
  // Whether the transcript is parked away from the newest message. Kept in a
  // notifier rather than a field: _onScroll runs on every scroll frame and this
  // screen rebuilds at 5Hz off _ticker already, so a setState here would make
  // the whole transcript pay for a pill.
  final BottomProximity _scrolledUp = BottomProximity();
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

  // The message a jump is currently travelling towards. Held separately from
  // _highlightedMessageId because the pulse only starts once we've landed,
  // and the target has to be un-foldable for the whole flight — a jump that
  // ends on a thread chip where the message used to be is a jump that failed.
  String? _jumpTargetId;

  // ──── thread folding ────
  // Ids folded out of the list by the last _buildItems pass. Read from async
  // callbacks (scroll-to-parent) to tell "collapsed" apart from "not loaded".
  Set<String> _hiddenMessageIds = const {};

  // The reversed item list the ListView renders, plus message id → row index,
  // both derived from the _buildItems output and memoized on its identity.
  // The index map is what lets a jump aim at a row that isn't built yet.
  List<RoomItem>? _revSource;
  List<RoomItem> _revItems = const [];
  Map<String, int> _rowIndexOf = const {};
  // Memo for the item pass. _ticker rebuilds at 5Hz whether or not anything
  // changed, and messagesFor() hands back the same list instance while no
  // sends are pending, so identity is a cheap and correct cache key.
  List<ChatMessage>? _memoSource;
  String _memoPinKey = '';
  ({List<RoomItem> items, Set<String> hidden})? _memoResult;

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
          setState(() {
            _highlightedMessageId = null;
            _jumpTargetId = null;
          });
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

  /// Wraps a row so thread rails can be painted in the leading gutter.
  ///
  /// The gutter is reserved on EVERY row and the ListView's own horizontal
  /// padding is reduced by the same amount, so content sits at exactly the
  /// same x whether a rail is present or not — no jitter as threads come and
  /// go. A Stack rather than a Row: a Row with stretch needs a bounded height
  /// the list can't supply, and IntrinsicHeight on every row is not worth it.
  Widget _railed(List<RailSegment> rails, Widget child) {
    final content =
        Padding(padding: const EdgeInsets.only(left: _kRailGutter), child: child);
    if (rails.isEmpty) return content;
    final theme = ThemeScope.of(context);
    return Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: _kRailGutter,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _ThreadRailPainter(rails: rails, accent: theme.accent),
            ),
          ),
        ),
        content,
      ],
    );
  }

  /// Whether [m] must keep its own row — never folded into a chip.
  ///
  /// The `_dateTracks` clause is the load-bearing one: that map is populated
  /// from the itemBuilder, so containsKey means "this row has already been
  /// built at least once this session". Without it a message would vanish
  /// out from under the reader the moment a newer reply pushed it into the
  /// thread's interior — possibly mid-video, or with its action menu open —
  /// and the same thing would happen on pagination when loadOlder prepends a
  /// root that turns the previously-first message into an interior one.
  bool _isPinned(ChatMessage m) =>
      m.id.startsWith('tmp_') ||
      m.status != MessageStatus.sent ||
      m.type == MessageType.system ||
      m.id == _highlightedMessageId ||
      m.id == _jumpTargetId ||
      m.id == _replyingTo?.id ||
      _dateTracks.containsKey('m_${m.id}');

  /// Flatten the message list into intro / date-divider / message / thread-
  /// fold rows. See lib/screens/room_items.dart for the algorithm.
  ({List<RoomItem> items, Set<String> hidden}) _buildItems(
    ChatRoom room,
    List<ChatMessage> messages,
  ) {
    // Everything _isPinned reads has to be in the key, or an armed reply or a
    // highlight pulse would be computed against a stale fold set.
    final pinKey = '${_dateTracks.length}'
        '|${_replyingTo?.id ?? ''}'
        '|${_highlightedMessageId ?? ''}'
        '|${_jumpTargetId ?? ''}';
    final memo = _memoResult;
    if (memo != null &&
        identical(messages, _memoSource) &&
        pinKey == _memoPinKey) {
      return memo;
    }
    final result = buildRoomItems(
      messages: messages,
      roomIsEphemeral: room.isEphemeral,
      isPinned: _isPinned,
      dayLabel: _humanDay,
    );
    _memoSource = messages;
    _memoPinKey = pinKey;
    _memoResult = result;
    return result;
  }

  /// The list the ListView actually renders — chronological items flipped so
  /// index 0 is the newest (visually the bottom under `reverse: true`) — plus
  /// the message id → index map a jump aims with. Memoized on the identity of
  /// the pass it came from, since build runs at 5Hz off _ticker.
  List<RoomItem> _reversedItems(List<RoomItem> chronological) {
    if (identical(chronological, _revSource)) return _revItems;
    final rev = chronological.reversed.toList();
    final index = <String, int>{};
    for (var i = 0; i < rev.length; i++) {
      final item = rev[i];
      if (item is MessageItem) index[item.message.id] = i;
    }
    _revSource = chronological;
    _revItems = rev;
    _rowIndexOf = index;
    return rev;
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
        widget.repo.hasMoreOlderTimeline(widget.roomId) &&
        !widget.repo.isLoadingTimeline(widget.roomId)) {
      widget.repo.loadOlderTimeline(widget.roomId);
    }
    // Reading a window of old history: the bottom of the list isn't the
    // present, so scrolling down has to fetch forwards until it is. Once the
    // window meets the live tail the repo merges it away and this stops
    // firing — the reader has simply scrolled back to now.
    if (pos.pixels <= 220 &&
        widget.repo.inHistoryWindow(widget.roomId) &&
        !widget.repo.isLoadingTimeline(widget.roomId)) {
      widget.repo.loadNewerTimeline(widget.roomId);
    }

    // Scroll-to-latest pill. Hysteresis lives in BottomProximity and the
    // notifier swallows the no-change case, so the common frame ends here.
    _scrolledUp.update(pos);

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
    // An emptied transcript has no scroll offset to be away from, and it can
    // happen under the reader: an ephemeral room expires its last message
    // while they are scrolled up. _onScroll can't clear this — there is no
    // list left to scroll — so the pill would come back with the next message
    // and hover over a transcript that is already at its bottom.
    if (widget.repo.timelineFor(widget.roomId).isEmpty) {
      _scrolledUp.value = false;
    }
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
    _scrolledUp.dispose();
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
    // Snapshot the reply target BEFORE the async send, then disarm: the reply
    // is sent, so the card has nothing left to say. It stays armed only when
    // the send is refused below, since then there's still a pending reply.
    final replyTarget = _replyingTo;
    setState(() => _replyingTo = null);
    _composer.clear();
    // Sending while reading old history: the optimistic bubble lands on the
    // live tail, so come back to it rather than leaving the sender staring at
    // a transcript their own message isn't in.
    widget.repo.exitHistoryWindow(widget.roomId);
    await widget.repo.sendText(widget.roomId, text, replyToId: replyTarget?.id);
    // A child guard rejection drops the optimistic bubble rather than leaving
    // it in the retry queue, so say why instead of letting the message just
    // vanish. Most likely a grant was revoked while the room was open.
    final gate = widget.repo.takeChildGateError();
    if (gate != null && mounted) {
      // Nothing was sent — put the user back exactly where they were.
      setState(() {
        _composer.text = text;
        _replyingTo = replyTarget;
      });
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

  /// Open the thread containing [m], scrolled to [m] itself.
  ///
  /// [ChatMessage.threadKey] resolves to the message's own id when it's a
  /// root, so this works whether the user tapped the top of a chain or a
  /// reply deep inside it.
  ///
  /// The overlay has its own composer, so replies made in there stay in
  /// there — the only thing it hands back is a child-guard refusal, which
  /// needs a surface that isn't behind the overlay's blurred scrim.
  Future<void> _openThread(ChatMessage m) =>
      _openThreadAt(rootId: m.threadKey, anchorMessageId: m.id);

  /// Opens the thread overlay on a folded run, anchored on the oldest message
  /// the chip stands in for so the user lands on the content they tapped for
  /// rather than the top of the thread.
  Future<void> _openFoldedThread(ThreadFoldItem fold) => _openThreadAt(
        rootId: fold.threadKey,
        anchorMessageId: fold.oldestHiddenId,
      );

  Future<void> _openThreadAt({
    required String rootId,
    required String anchorMessageId,
  }) =>
      showThreadOverlay(
        context: context,
        api: widget.api,
        repo: widget.repo,
        roomId: widget.roomId,
        rootId: rootId,
        anchorMessageId: anchorMessageId,
        onChildGate: (gate, unsentText) {
          if (!mounted) return;
          _composer.text = unsentText;
          unawaited(_handleSendGate(gate));
        },
      );

  /// Land on the message identified by [messageId] and pulse it — the tap
  /// target behind every reply tether. [from] is the reply that was tapped;
  /// its thread is the fallback surface, and since `messages:send` propagates
  /// `rootId`, a parent is always in the same thread as its child.
  ///
  /// Resolution order, first hit wins:
  ///   1. folded into a thread chip → open that thread on it
  ///   2. somewhere in the transcript → snap there, however far away it is
  ///   3. not loaded → fetch a window of history around it and snap
  ///   4. unreachable (deleted, or offline) → say so
  Future<void> _jumpToMessage(String messageId, {required ChatMessage from}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    // The pin exists to protect a jump in flight; handing the message over to
    // the thread overlay ends the flight, so drop it or the row stays
    // un-foldable for the rest of the session.
    Future<void> handOffToThread() async {
      if (!mounted) return;
      setState(() => _jumpTargetId = null);
      await _openThreadAt(rootId: from.threadKey, anchorMessageId: messageId);
    }

    if (_hiddenMessageIds.contains(messageId)) return handOffToThread();
    if (await _snapToRow(messageId)) return;
    if (!mounted) return;

    // Not in the transcript. Pin it before the fetch so the pass that brings
    // it in can't immediately fold it away again.
    setState(() => _jumpTargetId = messageId);
    final reached = await widget.repo.jumpToMessage(widget.roomId, messageId);
    if (!mounted) return;
    if (reached) {
      // One frame for the freshly-loaded window to lay out.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (!_hiddenMessageIds.contains(messageId) &&
          await _snapToRow(messageId)) {
        return;
      }
      // Folded, or in the room but with no row of its own — either way the
      // thread is where it can be seen.
      return handOffToThread();
    }
    setState(() => _jumpTargetId = null);
    messenger?.showSnackBar(
      const SnackBar(content: Text("couldn't jump to that message")),
    );
  }

  /// Scroll to [messageId]'s row and pulse it. False when the message has no
  /// row in the current transcript — the caller then has to go and get it.
  Future<bool> _snapToRow(String messageId) async {
    if (_rowIndexOf[messageId] == null) return false;
    setState(() => _jumpTargetId = messageId);
    final landed = await snapToIndex(
      controller: _scroll,
      // Re-read every hop: a message arriving mid-jump shifts every index.
      targetIndex: () => _rowIndexOf[messageId],
      itemCount: () => _revItems.length,
      targetContext: () => _dateTracks['m_$messageId']?.key.currentContext,
      probes: _mountedRowProbes,
      alignment: 0.3,
    );
    if (!mounted) return landed;
    if (!landed) {
      setState(() => _jumpTargetId = null);
      return false;
    }
    setState(() => _highlightedMessageId = messageId);
    _highlightCtrl.forward(from: 0);
    return true;
  }

  /// Every message row that's laid out right now, with its index — what
  /// [snapToIndex] calibrates its extrapolation against. `_dateTracks` keeps
  /// a key per row ever built this session; an unmounted one has no context.
  List<ScrollProbe> _mountedRowProbes() {
    final out = <ScrollProbe>[];
    for (final entry in _dateTracks.entries) {
      if (!entry.key.startsWith('m_')) continue;
      final index = _rowIndexOf[entry.key.substring(2)];
      if (index == null) continue;
      final ctx = entry.value.key.currentContext;
      if (ctx == null || !ctx.mounted) continue;
      out.add((index: index, context: ctx));
    }
    return out;
  }

  /// Leave a history window and land on the newest message. Not animated: the
  /// transcript swaps to an entirely different set of rows, so there's no
  /// continuous path between here and there to animate along.
  ///
  /// Deliberately silent — the haptic belongs to the affordance the reader
  /// touched, and this also runs off the back of a send, where a second buzz
  /// on top of the send's own would read as a stutter.
  void _jumpToLatest() {
    widget.repo.exitHistoryWindow(widget.roomId);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _scrollToBottom() {
    // Reading history is the one state where "the bottom" isn't the newest
    // message — drop the window first so it is.
    if (widget.repo.inHistoryWindow(widget.roomId)) {
      _jumpToLatest();
      return;
    }
    // reverse:true → 0 is the bottom. Layout for the new bubble may not be
    // settled yet, but the bottom target is constant so the animation lands
    // cleanly regardless. See scrollToLatest for why a long hop teleports
    // most of the way first.
    scrollToLatest(_scroll);
  }

  /// The pill's own tap. Separate from [_scrollToBottom] because that is also
  /// what a send calls, and only a deliberate tap earns a haptic.
  void _onJumpToLatestTapped() {
    HapticFeedback.selectionClick();
    _scrollToBottom();
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
        final edited = await nav.push<CroppedImage>(
            MaterialPageRoute(builder: (_) => CameraEditorScreen(source: captured)));
        if (edited != null) {
          await _uploadAndSend(
              file: edited.file, type: MessageType.image, contentType: edited.contentType);
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
    final edited = await nav.push<CroppedImage>(MaterialPageRoute(
      builder: (_) => CameraEditorScreen(source: File(picked.path)),
    ));
    if (edited == null) return;
    await _uploadAndSend(
        file: edited.file, type: MessageType.image, contentType: edited.contentType);
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
    // Snapshot and disarm up front — see _send. Restored if the upload or the
    // send throws, so a failure doesn't silently lose the reply target.
    final replyTarget = _replyingTo;
    if (replyTarget != null) setState(() => _replyingTo = null);
    try {
      final uploader = UploadService(widget.api);
      final storageId = await uploader.uploadXFile(file: file, contentType: contentType);
      await widget.repo.sendMedia(
        roomId: widget.roomId,
        storageId: storageId,
        type: type,
        replyToId: replyTarget?.id,
      );
      _scrollToBottom();
    } catch (_) {
      /* TODO surface as toast */
      if (mounted && replyTarget != null) {
        setState(() => _replyingTo = replyTarget);
      }
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
    // timelineFor, not messagesFor: after a jump into old history the
    // transcript renders a detached window of it until the reader scrolls
    // back down to the present. Everything else — threads, receipts, the
    // cache — still reads the live list.
    final messages = widget.repo.timelineFor(widget.roomId);
    final me = widget.repo.userId ?? '';
    // ListView is rendered with reverse:true so the viewport naturally
    // anchors to the newest message at the bottom. The items list is built
    // chronologically (intro → divider → messages) and reversed here so
    // items[0] is the newest message (visually at the bottom) and the intro
    // ends up at items[last] (visually at the top).
    final List<RoomItem> items;
    if (messages.isEmpty) {
      items = const <RoomItem>[];
      _hiddenMessageIds = const {};
      _revSource = null;
      _revItems = const [];
      _rowIndexOf = const {};
    } else {
      final built = _buildItems(room, messages);
      _hiddenMessageIds = built.hidden;
      items = _reversedItems(built.items);
    }
    final chatStyle = SettingsStore.instance.chatStyle;

    // ChatPane sits ABOVE the Scaffold on purpose: it must measure the pane
    // the shell handed us, not the Scaffold's body, which shrinks while the
    // keyboard animates. (The builder still re-runs on every keyboard frame,
    // but the width doesn't move, so ChatMetricsScope.updateShouldNotify
    // returns false and nothing below rebuilds.)
    return ChatPane(
      child: Scaffold(
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
      ),
    );
  }

  Widget _buildClassic(BuildContext context, ChatRoom room, List<ChatMessage> messages, List<RoomItem> items, String me) {
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
          // Ongoing group call in this room → join affordance. Zero height
          // when there is none (or in DMs, which use the 1:1 stack).
          if (!room.isDm && GroupCallService.maybeInstance != null)
            GroupCallBanner(
              api: GroupCallApi(ConvexBackend.instance),
              service: GroupCallService.instance,
              roomId: room.id,
              userId: me,
            ),
          Expanded(
            child: _messageBody(
              context,
              room,
              messages,
              items,
              me,
              listPadding: const EdgeInsets.fromLTRB(20 - _kRailGutter, 12, 20, 24),
              // Classic already says who's typing in its header — a second
              // indicator at the bottom of the transcript would say it twice.
              showTypingRow: false,
            ),
          ),
          // Same column as the messages above, so the composer lines up with
          // the conversation instead of running the full width of the window.
          ChatColumn(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingTo != null)
                  ComposerReplyCard(
                    parent: _replyingTo!,
                    api: widget.api,
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
                ChatComposerClassic(
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

  Widget _buildLiquid(BuildContext context, ChatRoom room, List<ChatMessage> messages, List<RoomItem> items, String me) {
    final topSafe = MediaQuery.paddingOf(context).top;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // Header: 8pt top + 44pt button + 8pt bottom = 60pt; composer: same.
    // Scaffold's default resizeToAvoidBottomInset shrinks the body when the
    // keyboard appears, so we DO NOT add viewInsets manually — that would
    // double-count and leave a massive gap.
    const chromeH = 60.0;
    final listPadding = EdgeInsets.fromLTRB(
      // Rails are painted in a per-row gutter; take its width out of the
      // list padding so message content keeps its original 20px inset.
      20 - _kRailGutter,
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
              child: ChatColumn(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LiquidHeader(
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
                    if (!room.isDm && GroupCallService.maybeInstance != null)
                      GroupCallBanner(
                        api: GroupCallApi(ConvexBackend.instance),
                        service: GroupCallService.instance,
                        roomId: room.id,
                        userId: me,
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ChatColumn(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingTo != null)
                  ComposerReplyCard(
                    parent: _replyingTo!,
                    api: widget.api,
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
                ChatComposerLiquid(
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
    List<RoomItem> items,
    String me, {
    required EdgeInsets listPadding,
    bool showTypingRow = true,
  }) {
    final theme = ThemeScope.of(context);
    final initialLoaded = widget.repo.hasLoadedInitial(widget.roomId);
    // Reserved unconditionally in the compact style: the row collapses to zero
    // height on its own when nobody is typing, so the item count stays fixed
    // and every index below shifts by exactly this much.
    final typingRows = showTypingRow ? 1 : 0;
    Widget typingRow() => TypingRow(
          typists: widget.repo.typingIn(room.id),
          api: widget.api,
          showAvatars: !room.isDm,
        );
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
          ? Stack(
              children: [
                Positioned.fill(
                  child: !initialLoaded
                      ? Center(
                          child: CircularProgressIndicator(
                            color: theme.accent,
                            strokeWidth: 2,
                          ),
                        )
                      : (room.isEphemeral
                          ? _SecretSpaceWelcome(ttl: room.messageLifetime)
                          : const _NoMessagesPlaceholder()),
                ),
                // There is no list to append to yet, but a DM where the other
                // person types first is exactly the moment you want to see it.
                if (showTypingRow)
                  Positioned(
                    left: listPadding.left + _kRailGutter,
                    right: listPadding.right,
                    bottom: listPadding.bottom,
                    child: ChatColumn(child: typingRow()),
                  ),
              ],
            )
          : Stack(
              children: [
                // The conversation fills its pane and only caps out on very
                // wide monitors, where a sent and a received bubble would
                // otherwise sit pinned to opposite edges with several hundred
                // px of dead space between them. Pure passthrough below
                // ChatMetrics.surfaceMax — i.e. on phones and on every normal
                // laptop pane. NOTE the key stays on the ListView so
                // _recomputePositionState keeps measuring in list-local
                // coordinates; the Align this may introduce offsets x only,
                // and only .dy is read.
                ChatColumn(
                  child: ListView.builder(
                  key: _listViewportKey,
                  controller: _scroll,
                  reverse: true,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: listPadding,
                  itemCount: items.length + typingRows,
                  itemBuilder: (context, i) {
                    // reverse: true — index 0 is the bottom of the transcript,
                    // which is where a message that hasn't been sent yet
                    // belongs. Railed like every other row so it shares the
                    // gutter and lands at the same left edge as the bubbles.
                    if (typingRows == 1 && i == 0) {
                      return _railed(const [], typingRow());
                    }
                    final item = items[i - typingRows];
                    if (item is IntroItem) {
                      return _railed(
                        const [],
                        _RoomIntro(
                          room: room,
                          members: _members.values.toList(),
                          api: widget.api,
                        ),
                      );
                    }
                    if (item is DateDividerItem) {
                      return _trackedDate(
                        stableId: 'd_${item.label}',
                        label: item.label,
                        isDivider: true,
                        child: _railed(
                          item.rails,
                          _DateDivider(label: item.label),
                        ),
                      );
                    }
                    // MUST precede the cast below — a new RoomItem subtype
                    // reaching it throws, and the analyzer won't catch that.
                    if (item is ThreadFoldItem) {
                      // Deliberately not wrapped in _trackedDate: the chip
                      // carries no date, and registering it would let it win
                      // the topmost-tracked-item contest in
                      // _recomputePositionState and show a wrong floating date.
                      return _railed(
                        item.rails,
                        _ThreadFoldChip(
                          fold: item,
                          api: widget.api,
                          members: _members,
                          onTap: () => _openFoldedThread(item),
                        ),
                      );
                    }
                    final messageItem = item as MessageItem;
                    final m = messageItem.message;
                    final grouped = messageItem.grouped;
                    final showReplyTether = messageItem.showReplyTether;
                final author = _members[m.senderId];
                final isMine = m.senderId == me;
                // A run is bracketed: name on the row that opens it, avatar on
                // the row that closes it. A run of one keeps the avatar at the
                // top, where it has always been — there is no block to close.
                final showAvatar = messageItem.lastInRun;
                final avatarAtBottom = messageItem.lastInRun && grouped;
                // `author` is null until rooms:getMembers lands, and optimistic
                // local sends carry an empty senderName — both mean "no name to
                // show yet" rather than a blank line.
                final senderName = (isMine || room.isDm || grouped)
                    ? null
                    : (author?.displayName.trim().isNotEmpty ?? false
                        ? author!.displayName
                        : (m.senderName.trim().isEmpty ? null : m.senderName));
                final othersRead = widget.repo.latestOthersReadAt;
                final seenByOthers = isMine && othersRead != null && !othersRead.isBefore(m.createdAt);
                final isPending = m.id.startsWith('tmp_');
                final canReply = !isPending &&
                    m.status == MessageStatus.sent &&
                    m.type != MessageType.system;
                final hasParent = m.isReply;
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
                      // Same avatar/name geometry as the row it lifted off, so
                      // the preview reads as that exact bubble rather than a
                      // subtly different one.
                      return m.isEphemeral
                          ? EphemeralMessageBubble(
                              message: m,
                              now: _now,
                              currentUserId: me,
                              api: widget.api,
                              author: author,
                              parentAuthor: parentAuthor,
                              showAvatarSlot: !room.isDm,
                              showAvatar: showAvatar,
                              avatarAtBottom: avatarAtBottom,
                              senderName: senderName,
                            )
                          : MessageBubble(
                              message: m,
                              now: _now,
                              currentUserId: me,
                              api: widget.api,
                              author: author,
                              parentAuthor: parentAuthor,
                              seenByOthers: seenByOthers,
                              showAvatarSlot: !room.isDm,
                              showAvatar: showAvatar,
                              avatarAtBottom: avatarAtBottom,
                              senderName: senderName,
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
                      await _openThread(m);
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
                Future<void> onViewThread() => _openThread(m);
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
                        onReplyIndicatorTap: (parentId) =>
                            _jumpToMessage(parentId, from: m),
                        onViewThread: m.isReply ? onViewThread : null,
                        parentAuthor: parentAuthor,
                        highlightT: highlightT,
                        seenByOthers: seenByOthers,
                        showReplyIndicator: showReplyTether,
                        grouped: grouped,
                        showAvatarSlot: !room.isDm,
                        showAvatar: showAvatar,
                        avatarAtBottom: avatarAtBottom,
                        senderName: senderName,
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
                        onReplyIndicatorTap: (parentId) =>
                            _jumpToMessage(parentId, from: m),
                        onViewThread: m.isReply ? onViewThread : null,
                        parentAuthor: parentAuthor,
                        highlightT: highlightT,
                        seenByOthers: seenByOthers,
                        showReplyIndicator: showReplyTether,
                        grouped: grouped,
                        showAvatarSlot: !room.isDm,
                        showAvatar: showAvatar,
                        avatarAtBottom: avatarAtBottom,
                        senderName: senderName,
                      );
                return _trackedDate(
                  stableId: 'm_${m.id}',
                  label: _humanDay(DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day)),
                  isDivider: false,
                  child: _railed(
                    messageItem.rails,
                    AnimatedSwitcher(
                    duration: theme.motionMed,
                    switchInCurve: theme.motionEntrance,
                    child: SwipeToReply(
                      key: ValueKey('sw_${m.id}'),
                      enabled: canReply,
                      onReplyTriggered: () => _armReply(m),
                      child: bubble,
                    ),
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
                Positioned(
                  // Clears the composer in both styles. In liquid the composer
                  // floats OVER this stack, and listPadding.bottom is exactly
                  // the room reserved for it; the old hardcoded 12 put the pill
                  // behind the glass.
                  bottom: math.max(8, listPadding.bottom - 8),
                  left: 0,
                  right: 0,
                  child: Center(
                    // Two reasons to be here: scrolled away from the newest
                    // message, or parked on a detached slice of history where
                    // the bottom of the list isn't the present at all. Both
                    // want the same button, and _scrollToBottom already tells
                    // them apart.
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _scrolledUp,
                      builder: (context, scrolledUp, _) => ScrollToLatestSlot(
                        visible: scrolledUp ||
                            widget.repo.inHistoryWindow(widget.roomId),
                        onTap: _onJumpToLatestTapped,
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
    // The rule stays full-bleed while the header CONTENT shares the chat
    // column — the macOS/Slack convention, and what stops the remaining
    // gutter on an ultrawide monitor from reading as a rendering bug. The
    // padding lives inside the column rather than on the Container: on the
    // Container it would be applied outside the constraint and the header
    // would sit 12px in from the column while the transcript sits 20px in.
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.divider, width: 1)),
      ),
      child: ChatColumn(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 20, 14),
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
            )
          else
            GroupCallButton(roomId: room.id),
          IconButton(
            onPressed: onOpenInfo,
            icon: Icon(Icons.more_horiz, color: theme.inkSoft, size: 18),
          ),
        ],
          ),
        ),
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

/// Width reserved on every row for thread rails. Two lanes at a 6px pitch,
/// plus the stroke. Subtracted from the ListView's horizontal padding so the
/// net content inset is unchanged.
const double _kRailGutter = 12.0;

/// Paints the vertical connectors that tie a thread's separated messages
/// together.
///
/// One segment per lane per row; consecutive rows butt together into a
/// continuous line. Members draw at full accent, rows the rail merely passes
/// draw faint — that contrast is the whole signal: "this thread carries on
/// past these unrelated messages".
class _ThreadRailPainter extends CustomPainter {
  const _ThreadRailPainter({required this.rails, required this.accent});

  final List<RailSegment> rails;
  final Color accent;

  static const double _stroke = 2.0;
  static const double _pitch = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    for (final seg in rails) {
      // Lane 0 sits closest to the message content; extra lanes step outward.
      final x = size.width - _stroke - seg.lane * _pitch;
      final paint = Paint()
        ..strokeWidth = _stroke
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: seg.isMember ? 0.85 : 0.20);

      final mid = size.height / 2;
      switch (seg.kind) {
        case RailKind.capTop:
          canvas.drawLine(Offset(x, mid), Offset(x, size.height), paint);
          // A dot terminates the run so the thread has a visible beginning.
          canvas.drawCircle(Offset(x, mid), _stroke, paint);
        case RailKind.capBottom:
          canvas.drawLine(Offset(x, 0), Offset(x, mid), paint);
          canvas.drawCircle(Offset(x, mid), _stroke, paint);
        case RailKind.through:
        case RailKind.across:
          canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThreadRailPainter old) =>
      old.accent != accent ||
      old.rails.length != rails.length ||
      !_sameRails(old.rails, rails);

  static bool _sameRails(List<RailSegment> a, List<RailSegment> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].kind != b[i].kind || a[i].lane != b[i].lane) return false;
    }
    return true;
  }
}

/// Stands in for a run of thread messages folded out of the timeline. Tapping
/// it opens the thread overlay anchored on the oldest message it hides.
class _ThreadFoldChip extends StatelessWidget {
  const _ThreadFoldChip({
    required this.fold,
    required this.api,
    required this.members,
    required this.onTap,
  });

  final ThreadFoldItem fold;
  final ChatApi api;
  final Map<String, ChatUser> members;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Cap the avatar stack — past three it stops reading as "who" and starts
    // reading as clutter.
    final shown = fold.senderIds.take(3).toList();
    return Padding(
      // Left-inset into the avatar gutter rather than centred: a centred pill
      // reads as a date marker, which this very much is not.
      padding: const EdgeInsets.fromLTRB(36, 2, 0, 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: theme.chipDecoration(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.arrow_branch,
                  size: 11,
                  color: theme.accent,
                ),
                const SizedBox(width: 7),
                for (var i = 0; i < shown.length; i++) ...[
                  if (i > 0) const SizedBox(width: 3),
                  _FoldSender(
                    userId: shown[i],
                    members: members,
                    api: api,
                  ),
                ],
                if (shown.isNotEmpty) const SizedBox(width: 7),
                Text(
                  // "MESSAGES", never "REPLIES": nothing denormalizes a thread
                  // size server-side, so the only number we can honestly show
                  // is how many *loaded* messages are folded right here.
                  '${fold.count} MESSAGES',
                  style: theme.monoTiny.copyWith(
                    color: theme.inkSoft,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FoldSender extends StatelessWidget {
  const _FoldSender({
    required this.userId,
    required this.members,
    required this.api,
  });

  final String userId;
  final Map<String, ChatUser> members;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final user = members[userId];
    if (user == null) return const SizedBox.shrink();
    return UserAvatar(user: user, api: api, size: 14, showStatus: false);
  }
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
            // LiquidGlass now shrink-wraps its content, so the capsule is as
            // wide as the title and no wider; Center keeps it centred in the
            // header and the inner Flexible(Text) ellipsizes once a long
            // title reaches the available width. (This used to need an
            // IntrinsicWidth to undo LiquidGlass expanding to fill.)
            child: Center(
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
          const SizedBox(width: 12),
          if (widget.room.isDm && widget.dmUser != null) ...[
            CallButton(
              peerUserId: widget.dmUser!.id,
              peerName: widget.dmUser!.displayName,
              roomId: widget.room.id,
              variant: CallButtonVariant.liquid,
            ),
            const SizedBox(width: 12),
          ] else ...[
            GroupCallButton(roomId: widget.room.id, liquid: true),
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

