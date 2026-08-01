import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
// ScrollCacheExtent lives in rendering/, not re-exported by material.dart.
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../screens/profile_screen.dart';
import '../screens/room_items.dart';
import '../keyboard/overlay_modal_scope.dart';
import '../platform.dart';
import '../theme/theme_scope.dart';
import 'anchored_scroll.dart';
import 'chat_composer.dart';
import 'chat_pane.dart';
import 'composer_reply_card.dart';
import 'glass_pill.dart';
import 'jump_back.dart';
import 'message_action_menu.dart';
import 'message_bubble.dart';
import 'reaction_picker_sheet.dart';
import 'report_sheet.dart';
import 'scroll_to_latest.dart';
import 'swipe_to_reply.dart';

/// Page size for thread paging. Small on purpose — the overlay pages on
/// scroll, so the first paint costs a fraction of the old flat 50-message
/// fetch.
const int kThreadPageSize = 25;

/// Open the thread rooted at [rootId], scrolled to [anchorMessageId].
///
/// The list is live: it reads [ChatRepository.threadFor], which merges
/// fetched pages with the room's own subscription, so messages sent from
/// inside the thread — and messages other people send while it's open —
/// appear without a refetch. Scrolling to the top pages further back.
///
/// Dismiss: tap the scrim, tap the close button, or press Esc. Vertical drag
/// scrolls the list and dismisses the keyboard rather than the overlay.
///
/// [onChildGate] is invoked instead of sending when a child guard refuses the
/// message. The overlay dismisses first and hands back the refusal plus the
/// unsent text, so the host screen can restore it into its own composer and
/// run the approval flow on a surface that isn't behind a blurred scrim.
Future<void> showThreadOverlay({
  required BuildContext context,
  required ChatApi api,
  required ChatRepository repo,
  required String roomId,
  required String rootId,
  required String anchorMessageId,
  void Function(String gateError, String unsentText)? onChildGate,
}) async {
  final theme = ThemeScope.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _ThreadSheet(
      api: api,
      repo: repo,
      roomId: roomId,
      rootId: rootId,
      anchorMessageId: anchorMessageId,
      themeMotion: theme.motionEntrance,
      onChildGate: onChildGate,
      onResolve: () {
        if (!completer.isCompleted) completer.complete();
        try {
          entry.remove();
        } catch (_) {}
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _ThreadSheet extends StatefulWidget {
  const _ThreadSheet({
    required this.api,
    required this.repo,
    required this.roomId,
    required this.rootId,
    required this.anchorMessageId,
    required this.themeMotion,
    required this.onResolve,
    this.onChildGate,
  });

  final ChatApi api;
  final ChatRepository repo;
  final String roomId;
  final String rootId;
  final String anchorMessageId;
  final Curve themeMotion;
  final VoidCallback onResolve;
  final void Function(String gateError, String unsentText)? onChildGate;

  @override
  State<_ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends State<_ThreadSheet>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Accent halo pulse on a message we've just scrolled to — the anchor the
  /// overlay opened on, or a parent reached by tapping a reply tether. Same
  /// one-shot 0→1→0 the room transcript fires, so "here it is" reads
  /// identically on both surfaces.
  late final AnimationController _pulse;
  String? _highlightedId;
  final ScrollController _scroll = ScrollController();
  // Same affordance as the room transcript: a pill that returns you to the
  // newest reply. Notifier-backed so a scroll frame never rebuilds the overlay.
  final BottomProximity _scrolledUp = BottomProximity();

  // …and the same reply trail, for the same reason: a thread can be long, and
  // following a tether up it strands the reader just as thoroughly as it does
  // in the room. Its own instance, not the room's — the two surfaces scroll
  // independently and a hop in one means nothing in the other.
  final JumpBackStack _jumpBack = JumpBackStack();
  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocus = FocusNode(debugLabel: 'thread-composer');

  bool _closing = false;

  /// Per-message-id keys for `ensureVisible` and for anchoring the action
  /// menu. Built lazily in the item builder rather than up-front: the list is
  /// live, and a message that arrives after the overlay opens would otherwise
  /// have no key — which silently kills long-press on exactly the messages
  /// the user is most likely to interact with.
  final Map<String, GlobalKey> _keys = {};

  /// The message a new reply attaches to. Null means "the last message in the
  /// thread", resolved at send time so it tracks live arrivals. Set
  /// explicitly by Reply / swipe.
  ChatMessage? _target;

  /// One-shot guard so the anchor scroll doesn't re-fire on every rebuild.
  bool _didAnchor = false;

  /// Ephemeral bubbles render a countdown against this. Without a ticker the
  /// overlay computed `DateTime.now()` once and the countdowns sat frozen.
  Timer? _tick;
  DateTime _now = DateTime.now();

  /// In-overlay toast. A SnackBar can't be used here: ScaffoldMessenger
  /// renders inside the Scaffold's subtree, which sits *below* this root
  /// overlay entry and behind the blurred scrim.
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 160),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )
      ..addListener(() {
        if (_highlightedId != null && mounted) setState(() {});
      })
      ..addStatusListener((s) {
        if (s != AnimationStatus.completed || !mounted) return;
        setState(() => _highlightedId = null);
        _pulse.reset();
      });

    widget.repo.addListener(_onRepoChange);
    _scroll.addListener(_onScroll);
    _scrolledUp.addListener(_onBottomProximity);
    // Pushes, pops and the idle expiry all change whether the back pill is
    // there and what it says.
    _jumpBack.addListener(_onJumpBackChanged);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    widget.repo.openThread(widget.rootId);
    // Deferred a frame on purpose: loadOlderThread notifies synchronously
    // before its first await, and we're already listening — kicking it off
    // here directly would call setState while the tree is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadFirstPage());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _toastTimer?.cancel();
    widget.repo.removeListener(_onRepoChange);
    widget.repo.closeThread(widget.rootId);
    _scroll.dispose();
    _scrolledUp.removeListener(_onBottomProximity);
    _scrolledUp.dispose();
    _jumpBack.removeListener(_onJumpBackChanged);
    _jumpBack.dispose();
    _composer.dispose();
    _composerFocus.dispose();
    _pulse.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onJumpBackChanged() {
    if (mounted) setState(() {});
  }

  /// Coming to rest on the newest reply retires the trail behind it — see the
  /// room screen's `_onBottomProximity` for why [BottomProximity]'s hysteresis
  /// and transition-only notifications are the whole of the rule.
  ///
  /// One extra path here: `_onRepoChange` forces the notifier false when the
  /// thread empties under the reader. A trail into messages that no longer
  /// exist is exactly one worth throwing away, so that firing this is correct.
  void _onBottomProximity() {
    if (!_scrolledUp.value) _jumpBack.clear();
  }

  void _onRepoChange() {
    if (!mounted) return;
    // A thread emptied under the reader (ephemeral replies expiring) leaves no
    // list to scroll, so _onScroll can never clear this on its own — and the
    // pill would reappear over the next reply while already at the bottom.
    if (_messages.isEmpty) _scrolledUp.value = false;
    setState(() {});
  }

  List<ChatMessage> get _messages =>
      widget.repo.threadFor(widget.roomId, widget.rootId);

  Future<void> _loadFirstPage() async {
    await widget.repo.loadOlderThread(
      roomId: widget.roomId,
      rootId: widget.rootId,
      pageSize: kThreadPageSize,
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _anchor());
  }

  // ───────────── scrolling ─────────────

  /// The list is `reverse: true`, so the *top* of the thread is the maximum
  /// scroll extent. Mirrors the room screen's own near-top trigger.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.pixels >= p.maxScrollExtent - 220) {
      if (widget.repo.hasMoreThread(widget.rootId) &&
          !widget.repo.isLoadingThread(widget.rootId)) {
        unawaited(widget.repo.loadOlderThread(
          roomId: widget.roomId,
          rootId: widget.rootId,
          pageSize: kThreadPageSize,
        ));
      }
    }
    // Hysteresis lives in BottomProximity; the notifier swallows the
    // no-change case, so the common scroll frame ends on one comparison.
    _scrolledUp.update(p);
  }

  /// Return to the newest reply. See [scrollToLatest] for why a long hop
  /// teleports most of the way before animating. A thread has no history
  /// window, so unlike the room transcript the bottom of the list always is
  /// the present.
  ///
  /// Only ever reached by a deliberate tap on the pill, so it also abandons the
  /// reply trail: going back to now is the one move that says the reader is
  /// done with where they've been.
  void _scrollToBottom() {
    HapticFeedback.selectionClick();
    _jumpBack.clear();
    scrollToLatest(_scroll);
  }

  /// Centers the message the overlay was opened on and pulses it.
  Future<void> _anchor() async {
    if (!mounted || _didAnchor) return;
    _didAnchor = true;
    await _revealInThread(widget.anchorMessageId);
  }

  /// Tapping a reply tether inside the thread goes to the quoted parent, and
  /// remembers [from] — the reply that was tapped — as somewhere to come back
  /// to.
  ///
  /// A reply and its parent always share a `rootId` (see `messages:send`), so
  /// the parent is always somewhere in this thread — it just may be older
  /// than the pages fetched so far.
  Future<void> _jumpToParent(String parentId, {required ChatMessage from}) async {
    if (await _revealInThread(parentId)) {
      _jumpBack.push(from);
      return;
    }
    if (mounted) _showToast("couldn't find that message in this thread");
  }

  /// Walk one hop back down the trail, to the reply we last jumped away from.
  ///
  /// Pops before travelling so an entry that has since expired out of the
  /// thread takes itself off the trail rather than parking a dead pill. Unlike
  /// [_jumpToParent] this pushes nothing, or the two ends would bounce off each
  /// other forever.
  Future<void> _jumpBackOneHop() async {
    final origin = _jumpBack.pop();
    if (origin == null) return;
    HapticFeedback.selectionClick();
    if (await _revealInThread(origin.id)) return;
    if (mounted) _showToast("couldn't find that message in this thread");
  }

  /// Page the thread back until [messageId] is loaded, scroll to it however
  /// far up it turns out to be, and pulse it.
  Future<bool> _revealInThread(String messageId, {double alignment = 0.5}) async {
    if (!await _pageUntilLoaded(messageId)) return false;
    if (!mounted) return false;
    // Let the newly-prepended page lay out before measuring against it.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return false;
    final landed = await snapToIndex(
      controller: _scroll,
      targetIndex: () => _rowIndexOf(messageId),
      // +1 for the loader/end slot the builder keeps at the top.
      itemCount: () => _messages.length + 1,
      targetContext: () => _keys[messageId]?.currentContext,
      probes: _mountedRowProbes,
      alignment: alignment,
    );
    if (!mounted || !landed) return landed;
    setState(() => _highlightedId = messageId);
    _pulse.forward(from: 0);
    return true;
  }

  /// Fetch older pages until [messageId] is in the thread. Bounded only by
  /// the thread running out of history (or ~1000 messages of it).
  Future<bool> _pageUntilLoaded(String messageId) async {
    for (var i = 0; i < 40; i++) {
      if (!mounted) return false;
      if (_messages.any((m) => m.id == messageId)) return true;
      if (!widget.repo.hasMoreThread(widget.rootId)) return false;
      if (widget.repo.isLoadingThread(widget.rootId)) {
        // A scroll-triggered page is already in flight; let it land.
        await Future<void>.delayed(const Duration(milliseconds: 60));
        continue;
      }
      await widget.repo.loadOlderThread(
        roomId: widget.roomId,
        rootId: widget.rootId,
        pageSize: kThreadPageSize,
      );
    }
    return mounted && _messages.any((m) => m.id == messageId);
  }

  /// Row index of [id] in the reversed list the builder renders.
  int? _rowIndexOf(String id) {
    final msgs = _messages;
    for (var j = 0; j < msgs.length; j++) {
      if (msgs[j].id == id) return msgs.length - 1 - j;
    }
    return null;
  }

  List<ScrollProbe> _mountedRowProbes() {
    final msgs = _messages;
    final out = <ScrollProbe>[];
    for (var j = 0; j < msgs.length; j++) {
      final ctx = _keys[msgs[j].id]?.currentContext;
      if (ctx == null || !ctx.mounted) continue;
      out.add((index: msgs.length - 1 - j, context: ctx));
    }
    return out;
  }

  // ───────────── composing ─────────────

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toast = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _armReply(ChatMessage m, {bool haptic = true}) {
    // The swipe path opts out — it already buzzed at the threshold, and the
    // reply now arms on release rather than 220ms later.
    if (haptic) HapticFeedback.heavyImpact();
    setState(() => _target = m);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  /// Resolves the reply target against the *current* thread. A message can
  /// never be sent into a thread with a null parent — it would land in the
  /// room but outside the thread, and appear to vanish from this overlay — so
  /// a target that was deleted or expired mid-compose falls back to the last
  /// live message.
  ChatMessage? _resolveTarget(List<ChatMessage> messages) {
    if (messages.isEmpty) return null;
    final t = _target;
    if (t != null) {
      for (final m in messages) {
        if (m.id == t.id) return m;
      }
    }
    return messages.last;
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    final target = _resolveTarget(_messages);
    if (target == null) {
      _showToast("couldn't find the thread to reply to");
      return;
    }
    if (target.id.startsWith('tmp_')) {
      _showToast('still sending — try again in a second');
      return;
    }
    _composer.clear();
    // Disarm: the reply is sent, so an explicit target has nothing left to
    // say. Falling back to null means the next send goes to the tail — which
    // is now the message just sent. Nothing to restore on the refusal path
    // below: it dismisses the overlay and hands the text to the room.
    if (_target != null) setState(() => _target = null);
    await widget.repo.sendText(widget.roomId, text, replyToId: target.id);

    // Read-and-clear, immediately after the send, exactly as the room screen
    // does — leaving it set would leak the refusal into the next send there.
    final gate = widget.repo.takeChildGateError();
    if (gate != null) {
      final handler = widget.onChildGate;
      await _dismiss();
      // Handed to the host rather than shown here: the approval sheet is a
      // pushed route, and this overlay's scrim would blur it.
      handler?.call(gate, text);
      return;
    }
    if (!mounted) return;
    // Reverse list: offset 0 is the newest message.
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  // ───────────── dismissal ─────────────

  Future<void> _dismiss() async {
    if (_closing) return;
    _closing = true;
    await _ctrl.reverse();
    if (!mounted) return;
    widget.onResolve();
  }

  // ───────────── action menu ─────────────

  Future<void> _onLongPressBubble(ChatMessage m, ChatUser? author) async {
    final isMine = m.senderId == widget.repo.userId;
    final isPending = m.id.startsWith('tmp_');
    final canReply = !isPending &&
        m.status == MessageStatus.sent &&
        m.type != MessageType.system;
    final anchor = _keys[m.id];
    if (anchor == null) return;
    HapticFeedback.mediumImpact();

    // Same run geometry as the row this was lifted off — see the
    // ListView.builder below. The overlay force-sizes the preview into the
    // measured rect, so a wrong `grouped` here (default false, i.e. the wide
    // between-runs gap) makes it taller than that rect and overflows.
    final messages = _messages;
    final j = messages.indexWhere((x) => x.id == m.id);
    final prev = j <= 0 ? null : messages[j - 1];
    final grouped = continuesRun(prev, m);
    final next = j == -1 || j + 1 >= messages.length ? null : messages[j + 1];
    final lastInRun = next == null || !continuesRun(m, next);

    final result = await showMessageActionMenu(
      context: context,
      anchorKey: anchor,
      isMine: isMine,
      canCopy: m.type == MessageType.text && m.content.isNotEmpty,
      canReply: canReply,
      // hasParent: false — even when the message has a parent we
      // intentionally suppress the View Thread row inside this overlay to
      // prevent recursion. The user already sees the thread.
      hasParent: false,
      bubbleBuilder: (_) => _bubbleFor(
        m,
        author,
        // Must match the row this lifted off, marker included — the overlay
        // force-sizes the preview into the measured rect, so anything but the
        // row's own marker is exactly the overflow the comment above warns
        // about.
        replyMarker: replyMarkerFor(prev, m),
        interactive: false,
        grouped: grouped,
        lastInRun: lastInRun,
      ),
    );
    if (!mounted || result == null) return;
    if (result.emoji != null) {
      await widget.repo.toggleReaction(messageId: m.id, emoji: result.emoji!);
      return;
    }
    if (result.openFullReactionPicker) {
      final emoji = await showReactionPicker(context);
      if (emoji == null || emoji.isEmpty) return;
      await widget.repo.toggleReaction(messageId: m.id, emoji: emoji);
      return;
    }
    switch (result.action!) {
      case MessageAction.reply:
        // Stays in the thread now that there's a composer here — retarget
        // rather than dismissing to the room's composer.
        _armReply(m);
        break;
      case MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: m.content));
        _showToast('copied');
        break;
      case MessageAction.viewProfile:
        if (author != null && context.mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                user: author,
                repo: widget.repo,
                api: widget.api,
              ),
            ),
          );
        }
        break;
      case MessageAction.delete:
        await widget.repo.deleteMessage(m.id);
        break;
      case MessageAction.report:
        if (!context.mounted) return;
        final reason = await showReportSheet(context);
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
          _showToast('reported');
        } catch (_) {}
        break;
      case MessageAction.viewThread:
        // Suppressed (hasParent: false above ensures this row isn't shown),
        // but the switch must be exhaustive.
        break;
    }
  }

  // ───────────── rendering ─────────────

  Widget _bubbleFor(
    ChatMessage m,
    ChatUser? author, {
    required ReplyMarker replyMarker,
    required bool interactive,
    bool grouped = false,
    bool lastInRun = true,
    double highlightT = 0,
  }) {
    final me = widget.repo.userId ?? '';
    final isDm = widget.repo.roomById(widget.roomId)?.isDm ?? false;
    // Same bracketing as the room transcript — see room_screen's builder.
    final name = (m.senderId == me || isDm || grouped)
        ? null
        : (author?.displayName.trim().isNotEmpty ?? false
            ? author!.displayName
            : (m.senderName.trim().isEmpty ? null : m.senderName));
    if (m.isEphemeral) {
      return EphemeralMessageBubble(
        message: m,
        now: _now,
        currentUserId: me,
        api: widget.api,
        author: author,
        useHero: false,
        grouped: grouped,
        lastInRun: lastInRun,
        showAvatarSlot: !isDm,
        showAvatar: lastInRun,
        avatarAtBottom: lastInRun && grouped,
        senderName: name,
        highlightT: highlightT,
        replyMarker: replyMarker,
        // Null hides the branch button — no thread-within-a-thread.
        onViewThread: null,
        onReplyIndicatorTap:
            interactive ? (parentId) => _jumpToParent(parentId, from: m) : null,
        onLongPress: interactive ? () => _onLongPressBubble(m, author) : null,
        onDoubleTap: interactive ? () => _onLongPressBubble(m, author) : null,
      );
    }
    return MessageBubble(
      message: m,
      now: _now,
      currentUserId: me,
      api: widget.api,
      author: author,
      useHero: false,
      grouped: grouped,
      lastInRun: lastInRun,
      showAvatarSlot: !isDm,
      showAvatar: lastInRun,
      avatarAtBottom: lastInRun && grouped,
      senderName: name,
      highlightT: highlightT,
      replyMarker: replyMarker,
      onViewThread: null,
      onReplyIndicatorTap:
          interactive ? (parentId) => _jumpToParent(parentId, from: m) : null,
      onLongPress: interactive ? () => _onLongPressBubble(m, author) : null,
      onDoubleTap: interactive ? () => _onLongPressBubble(m, author) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final curved = CurvedAnimation(parent: _ctrl, curve: widget.themeMotion);
    final messages = _messages;
    final loading = widget.repo.isLoadingThread(widget.rootId);
    final hasLoaded = widget.repo.hasLoadedThread(widget.rootId);
    final target = _resolveTarget(messages);
    // Whether the send would attach somewhere other than the newest message,
    // i.e. the user deliberately branched off an earlier one.
    final offTail =
        target != null && messages.isNotEmpty && target.id != messages.last.id;

    // SafeArea consumes *padding*, not *viewInsets*, and padding.bottom is
    // not reliably zeroed when the keyboard is up — so take the larger of the
    // two rather than adding them, or the home indicator gets counted twice.
    final media = MediaQuery.of(context);
    final bottomInset =
        media.viewInsets.bottom > media.padding.bottom
            ? media.viewInsets.bottom
            : media.padding.bottom;

    return Material(
      type: MaterialType.transparency,
      child: OverlayModalScope(
        onDismiss: _dismiss,
        // This overlay owns a text field, so restoring focus to the room's
        // composer on close would pop the keyboard straight back up.
        restoreFocus: false,
        child: Stack(
          children: [
            // Frosted scrim. Tap to dismiss.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismiss,
                child: AnimatedBuilder(
                  animation: curved,
                  builder: (_, _) {
                    final t = curved.value;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: 22 * t,
                                sigmaY: 22 * t,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.black.withValues(alpha: 0.32 * t),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            // Scrolling sheet of full-size bubbles + composer. The sheet is
            // transparent (no card surface) so the scrim shows through.
            //
            // The ChatPane goes here — inside Positioned.fill, outside the
            // Column — so the transcript and composer are column-constrained
            // while the scrim, close button and toast stay full-bleed: they
            // are chrome for the window, not for the conversation. An overlay
            // has no pane of its own, so what it measures IS the window,
            // which is exactly right.
            Positioned.fill(
              child: ChatPane(
                child: SafeArea(
                // Bottom handled manually — see bottomInset above.
                bottom: false,
                child: AnimatedBuilder(
                  animation: curved,
                  builder: (_, child) =>
                      Opacity(opacity: curved.value, child: child),
                  child: Column(
                    children: [
                      Expanded(
                        // Deliberately only the populated branch is wrapped.
                        // An empty thread paints a bare Text/spinner, which
                        // hit-tests through to the scrim behind — tapping the
                        // middle of "thread unavailable" dismisses the overlay,
                        // and swallowing that to unfocus a keyboard that isn't
                        // up (there is no composer without a target) would be a
                        // pure loss.
                        child: messages.isEmpty
                            ? Center(
                                child: hasLoaded
                                    ? Text(
                                        'thread unavailable',
                                        style: theme.bodySoft
                                            .copyWith(color: theme.inkMuted),
                                      )
                                    : const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                              )
                            : GestureDetector(
                                // Tapping the transcript puts the keyboard
                                // away — the same gesture the room screen
                                // offers, and the companion to the list's own
                                // drag-to-dismiss. Translucent so it wins the
                                // arena ahead of the scrim: a tap in here
                                // closes the keyboard and must NOT also close
                                // the whole overlay. (No behaviour is lost —
                                // Scrollable already hit-tests opaque, so these
                                // taps never reached the scrim to begin with.)
                                //
                                // On desktop there is no soft keyboard to put
                                // away, and stealing focus would silently break
                                // Enter-to-send after any click in the thread.
                                behavior: HitTestBehavior.translucent,
                                onTap: isPhysicalKeyboardPlatform
                                    ? null
                                    : () => FocusManager.instance.primaryFocus
                                        ?.unfocus(),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: _buildList(messages, loading),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        // Back pill above the jump-to-latest
                                        // one, same order as the room, so the
                                        // fixture stays in the slot the reader
                                        // already knows and the transient one
                                        // floats over it.
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TransientPillSlot(
                                              visible: _jumpBack.isNotEmpty,
                                              child: JumpBackPill(
                                                depth: _jumpBack.depth,
                                                onTap: _jumpBackOneHop,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ValueListenableBuilder<bool>(
                                              valueListenable: _scrolledUp,
                                              builder:
                                                  (context, scrolledUp, _) =>
                                                      ScrollToLatestSlot(
                                                visible: scrolledUp,
                                                onTap: _scrollToBottom,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      if (target != null)
                        AnimatedPadding(
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOut,
                          padding: EdgeInsets.only(bottom: bottomInset),
                          child: _buildComposer(target, offTail: offTail),
                        ),
                    ],
                  ),
                ),
                ),
              ),
            ),
            // Close button — the other dismiss affordance besides scrim tap.
            Positioned(
              top: 0,
              right: 16,
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: curved,
                  builder: (_, child) =>
                      Opacity(opacity: curved.value, child: child),
                  child: _CloseButton(onTap: _dismiss),
                ),
              ),
            ),
            if (_toast != null)
              Positioned(
                left: 20,
                right: 20,
                bottom: bottomInset + 96,
                child: IgnorePointer(child: _Toast(message: _toast!)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    List<ChatMessage> messages,
    bool loading,
  ) {
    // Reversed so the newest sits against the composer and so prepending an
    // older page preserves scroll position for free.
    final count = messages.length + 1; // +1 for the top loading//end slot
    return ChatColumn(
      child: ListView.builder(
      controller: _scroll,
      reverse: true,
      // Build well beyond the viewport so `ensureVisible` finds anchor keys
      // and long-press works on off-screen bubbles.
      scrollCacheExtent: const ScrollCacheExtent.pixels(1200),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 12),
      itemCount: count,
      itemBuilder: (context, i) {
        if (i == count - 1) {
          // Visually the top of the thread.
          if (!loading) return const SizedBox(height: 8);
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final j = messages.length - 1 - i; // chronological index
        final m = messages[j];
        final author = widget.repo.userById(m.senderId) ??
            ChatUser(
              id: m.senderId,
              username: m.senderName,
              name: m.senderName,
            );

        // The room list's own rule, so a thread doesn't read as looser than
        // the conversation it came from. A linear chain is the common shape
        // here, which means most rows quote the row above them and so get the
        // compact marker — the name alone is enough to tell a branch from a
        // straight continuation, and that ambiguity is the whole reason
        // threads are hard to read.
        final prev = j == 0 ? null : messages[j - 1];
        final marker = replyMarkerFor(prev, m);

        // Note this deliberately has no day-boundary clause: a thread draws
        // no date dividers.
        final grouped = continuesRun(prev, m);

        // Whether anything below continues this run — the next message must
        // be evaluated the same way, marker included.
        final next = j + 1 < messages.length ? messages[j + 1] : null;
        final lastInRun = next == null || !continuesRun(m, next);

        final canReply = !m.id.startsWith('tmp_') &&
            m.status == MessageStatus.sent &&
            m.type != MessageType.system;

        final bubble = SwipeToReply(
          enabled: canReply,
          onReplyTriggered: () => _armReply(m, haptic: false),
          child: _bubbleFor(
            m,
            author,
            replyMarker: marker,
            interactive: true,
            grouped: grouped,
            lastInRun: lastInRun,
            highlightT: _highlightedId == m.id ? _pulse.value : 0.0,
          ),
        );

        return KeyedSubtree(
          key: _keys.putIfAbsent(
            m.id,
            () => GlobalKey(debugLabel: 'thread-${m.id}'),
          ),
          child: bubble,
        );
      },
      ),
    );
  }

  /// [target] is the message a send will attach to. [offTail] is true only
  /// when that's *not* the newest message in the thread.
  Widget _buildComposer(ChatMessage target, {required bool offTail}) {
    final room = widget.repo.roomById(widget.roomId);
    final ephemeral = room?.isEphemeral ?? false;
    final classic = SettingsStore.instance.chatStyle == ChatStyle.classic;
    final theme = ThemeScope.of(context);
    // Same column as the thread transcript above it, so the composer lines up
    // with the conversation instead of running the full window width.
    return ChatColumn(
      // Grows the reply card up out of the composer rather than snapping the
      // whole bar taller when the user retargets an earlier message.
      child: AnimatedSize(
        duration: theme.motionFast,
        curve: theme.motionEntrance,
        alignment: Alignment.bottomCenter,
        child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // No "REPLYING TO" banner in the normal case. In a room it earns its
        // space — it's the only thing saying you're not just typing into the
        // channel. In a thread the whole view IS the context, and the default
        // target is the message sitting directly above the composer, so the
        // card just restates what's already on screen.
        //
        // It comes back when you long-press or swipe an EARLIER message to
        // branch, because then the send goes somewhere the layout doesn't
        // imply — that's the one case where silence would be wrong.
        if (offTail)
          ComposerReplyCard(
            // Without the key the card doesn't re-run its entrance animation
            // when the user retargets, so the switch reads as nothing
            // happening.
            key: ValueKey(target.id),
            parent: target,
            api: widget.api,
            // Clearing goes back to the tail, which is the default — there is
            // no null target inside a thread.
            onCancel: () => setState(() => _target = null),
          ),
        // Attachments are deliberately absent: the attach flow pushes
        // full-screen routes (camera, voice recorder) that would fight this
        // root-overlay entry for layering. Text only in the thread.
        if (classic)
          ChatComposerClassic(
            controller: _composer,
            focusNode: _composerFocus,
            ephemeral: ephemeral,
            onSend: _send,
            onChanged: (_) => widget.repo.noteTyping(),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          )
        else
          ChatComposerLiquid(
            controller: _composer,
            focusNode: _composerFocus,
            ephemeral: ephemeral,
            onSend: _send,
            onChanged: (_) => widget.repo.noteTyping(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          ),
      ],
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: theme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.accent.withValues(alpha: 0.30)),
            ),
            child: Text(
              message,
              style: theme.bodySoft.copyWith(color: theme.ink),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.surface.withValues(alpha: 0.55),
                border: Border.all(
                  color: theme.accent.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(Icons.close, size: 18, color: theme.ink),
            ),
          ),
        ),
      ),
    );
  }
}
