import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
// ScrollCacheExtent lives in rendering/, not re-exported by material.dart.
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/mention_session.dart';
import '../data/settings_store.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/location_share.dart' show formatCoordinates;
import '../models/reaction_limits.dart';
import '../models/room_posting_policy.dart';
import 'read_only_composer_footer.dart';
import '../companions/companion.dart';
import '../companions/sebastian.dart';
import '../l10n/generated/app_localizations.dart';
import '../privacy/app_only.dart';
import '../screens/profile_screen.dart';
import '../screens/room_items.dart';
import '../keyboard/overlay_modal_scope.dart';
import '../theme/theme_scope.dart';
import 'app_toast.dart';
import 'anchored_scroll.dart';
import '../composer/capture_machine.dart';
import '../composer/capture_recorder.dart';
import 'chat_composer.dart';
import '../expressions/expression_store.dart';
import '../family/family_service.dart';
import '../media/image_raster.dart';
import '../media/view_once_fetch.dart';
import '../media/view_once_media.dart' show viewOnceMicroPoster;
import '../models/expression_item.dart';
import 'expressions/expression_panel.dart';
import 'expressions/expression_sheet.dart';
import 'chat_pane.dart';
import 'composer_capture.dart';
import 'composer_reply_card.dart';
import 'destructive_sheet.dart' show showConfirmSheet;
import 'glass_buttons.dart';
import 'glass_pill.dart';
import 'glass_reveal.dart';
import 'jump_back.dart';
import 'mention_picker.dart';
import 'mention_text_controller.dart';
import 'companion_install_sheet.dart';
import 'message_action_menu.dart';
import 'interaction_bubble.dart' show InteractionActions;
import 'interaction_respondents_sheet.dart';
import 'message_bubble.dart';
import 'reaction_limit_notice.dart';
import 'reaction_picker_sheet.dart';
import 'message_deletions.dart';
import 'moderation_actions.dart';
import 'report_sheet.dart';
import 'scroll_to_latest.dart';
import 'speaker_scope.dart';
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
/// Dismiss: tap the background — the scrim, the space beside a bubble, the gap
/// above the first message — or the close button, or Esc. Taps on the messages
/// themselves are content, not background, and do nothing. A tap while the soft
/// keyboard is up spends itself putting the keyboard away. Vertical drag
/// scrolls the list, anywhere in it, and dismisses the keyboard rather than the
/// overlay.
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

  /// The room's roster, for the @-picker. Handed in rather than subscribed to
  /// here: this overlay is only ever opened from the room screen, which already
  /// holds a live `rooms:getMembers` subscription, and a second one would pay
  /// for the same rows twice.
  List<ChatUser> members = const [],
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
      members: members,
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
    required this.members,
    required this.themeMotion,
    required this.onResolve,
    this.onChildGate,
  });

  final ChatApi api;
  final ChatRepository repo;
  final String roomId;
  final String rootId;
  final String anchorMessageId;
  final List<ChatUser> members;
  final Curve themeMotion;
  final VoidCallback onResolve;
  final void Function(String gateError, String unsentText)? onChildGate;

  @override
  State<_ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends State<_ThreadSheet>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;

  /// Who speaks in which colour, from the roster the room handed over. That
  /// roster is a constructor argument and does not change while the sheet is
  /// open, so this is settled once rather than per build — and it agrees with
  /// the transcript underneath because both are the same pure function of the
  /// same list.
  late final SpeakerSlots _speakerSlots =
      (widget.repo.roomById(widget.roomId)?.isDm ?? false)
          ? SpeakerSlots.none
          : SpeakerSlots.forMembers(
              [
                for (final u in widget.members)
                  (id: u.id, joinedAt: u.joinedAt?.millisecondsSinceEpoch ?? 0)
              ],
              exclude: widget.repo.userId,
              pinned: widget.repo.speakerColorsFor(widget.roomId),
            );

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
  final MentionTextController _composer = MentionTextController();
  final FocusNode _composerFocus = FocusNode(debugLabel: 'thread-composer');

  /// The emoji/GIF/sticker panel. Safe in this overlay for the same reason the
  /// @-picker is: it is an inline sibling of the composer and pushes nothing.
  final ExpressionPanelController _expressions = ExpressionPanelController();
  late final MentionSession _mention;

  bool _closing = false;

  /// Per-message-id keys for `ensureVisible` and for anchoring the action
  /// menu. Built lazily in the item builder rather than up-front: the list is
  /// live, and a message that arrives after the overlay opens would otherwise
  /// have no key — which silently kills long-press on exactly the messages
  /// the user is most likely to interact with.
  final Map<String, GlobalKey> _keys = {};

  /// Keys on the bubble boxes themselves, as opposed to [_keys]' full-width
  /// rows. Only these say where the message actually *is*, which is what
  /// [_tapLandedOnAMessage] needs — see it for why the row can't.
  final Map<String, GlobalKey> _bubbleKeys = {};

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

  /// The same instant as [_now], as a listenable, because that is what a
  /// fading bubble takes now. The overlay ticks at 1Hz and rebuilds itself
  /// anyway, so this changes nothing here — it exists so the room screen can
  /// drive its own fade at 5Hz without rebuilding a transcript. See
  /// [EphemeralMessageBubble.now].
  final ValueNotifier<DateTime> _fadeNow = ValueNotifier(DateTime.now());


  @override
  void initState() {
    super.initState();
    _mention = MentionSession(
      controller: _composer,
      roster: () => widget.members,
      selfUserId: widget.repo.userId,
      // The roster is a snapshot taken when the overlay opened, so a DM is
      // still a DM for as long as it is up — no need to re-read the room.
      allowEveryone: () => widget.members.length > 2,
    );
    _mention.addListener(_onMentionChanged);
    _expressions.addListener(_onExpressionsChanged);
    _composerFocus.addListener(_onComposerFocusChanged);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 160),
    )..forward();
    _pulse =
        AnimationController(
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
      if (!mounted) return;
      final now = DateTime.now();
      _fadeNow.value = now;
      setState(() => _now = now);
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
    _fadeNow.dispose();
    widget.repo.removeListener(_onRepoChange);
    widget.repo.closeThread(widget.rootId);
    _deletions.dispose();
    _scroll.dispose();
    _scrolledUp.removeListener(_onBottomProximity);
    _scrolledUp.dispose();
    _jumpBack.removeListener(_onJumpBackChanged);
    _jumpBack.dispose();
    // Before the controller: the session is a listener on it.
    _mention.removeListener(_onMentionChanged);
    _mention.dispose();
    _composer.dispose();
    _expressions.removeListener(_onExpressionsChanged);
    _expressions.dispose();
    _composerFocus.removeListener(_onComposerFocusChanged);
    _composerFocus.dispose();
    _pulse.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onJumpBackChanged() {
    if (mounted) setState(() {});
  }

  void _onExpressionsChanged() {
    if (mounted) setState(() {});
  }

  void _onComposerFocusChanged() {
    if (_composerFocus.hasFocus) _expressions.dismiss();
  }

  /// Sends a GIF or sticker into the thread, tethered to the same reply
  /// target a text send would take — see [_resolveTarget] for why an untethered
  /// one would land outside the thread and seem to vanish.
  Future<void> _sendExpression(ExpressionItem item, {String? query}) async {
    final target = _resolveTarget(_messages);
    if (target == null) {
      _showToast(AppLocalizations.of(context).threadOverlayReplyTargetNotFound);
      return;
    }
    if (target.id.startsWith('tmp_')) {
      _showToast(AppLocalizations.of(context).threadOverlayStillSending);
      return;
    }
    if (_target != null) setState(() => _target = null);
    final store = ExpressionStore.instance;
    store.noteUsed(item);
    // Stay open, but come back down from the expanded level so the message
    // just sent is on screen — see [ExpressionPanelController.noteSent].
    _expressions.noteSent();
    final slug = item.ref;
    if (item.source == ExpressionSource.klipy && slug != null) {
      unawaited(store.klipy?.registerShare(item.kind, slug, query: query));
    }
    await widget.repo.sendExpression(widget.roomId, item, replyToId: target.id);
    // Read-and-clear, as `_send` does: a guardian's refusal is handed to the
    // host, whose approval sheet this overlay would otherwise sit on top of.
    final gate = widget.repo.takeChildGateError();
    if (gate != null) {
      final handler = widget.onChildGate;
      await _dismiss();
      handler?.call(gate, '');
    }
  }

  /// A keyboard-inserted GIF or sticker, sent as an image into the thread —
  /// inline, like the recorders, so nothing is pushed over this overlay.
  Future<void> _onKeyboardContent(KeyboardInsertedContent content) async {
    final bytes = content.data;
    if (bytes == null || bytes.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    if (FamilyService.maybeInstance?.canSendMedia == false) {
      _showToast(l10n.expressionMediaNotAllowed);
      return;
    }
    final target = _resolveTarget(_messages);
    if (target == null || target.id.startsWith('tmp_')) {
      _showToast(target == null
          ? l10n.threadOverlayReplyTargetNotFound
          : l10n.threadOverlayStillSending);
      return;
    }
    Size? size;
    try {
      size = await imageBytesSize(bytes);
    } catch (_) {}
    if (!mounted) return;
    widget.repo.sendMediaLocal(
      roomId: widget.roomId,
      bytes: bytes,
      contentType: sniffImageContentType(bytes),
      type: MessageType.image,
      mediaWidth: size?.width,
      mediaHeight: size?.height,
      replyToId: target.id,
    );
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

  /// Replies being deleted, turning to dust on their way out. The room
  /// screen's ledger, for this list. See [MessageDeletions].
  late final MessageDeletions _deletions = MessageDeletions(
    onChanged: () {
      if (mounted) setState(() {});
    },
  );
  int _seenRemovals = 0;

  /// What the list drew last, held rows included: where a reply someone
  /// else deleted is looked up.
  List<ChatMessage> _lastShown = const [];

  void _onRepoChange() {
    if (!mounted) return;
    final removals = widget.repo.serverRemovals(widget.roomId);
    if (removals.serial != _seenRemovals) {
      _seenRemovals = removals.serial;
      final gone = [
        for (final m in _lastShown)
          if (removals.ids.contains(m.id)) m,
      ];
      if (gone.isNotEmpty && gone.length <= 12) {
        _deletions.begin(gone, haptic: false);
      }
    }
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
        unawaited(
          widget.repo.loadOlderThread(
            roomId: widget.roomId,
            rootId: widget.rootId,
            pageSize: kThreadPageSize,
          ),
        );
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
  Future<void> _jumpToParent(
    String parentId, {
    required ChatMessage from,
  }) async {
    if (await _revealInThread(parentId)) {
      _jumpBack.push(from);
      return;
    }
    if (mounted) {
      _showToast(AppLocalizations.of(context).threadOverlayMessageNotFound);
    }
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
    if (mounted) {
      _showToast(AppLocalizations.of(context).threadOverlayMessageNotFound);
    }
  }

  /// Page the thread back until [messageId] is loaded, scroll to it however
  /// far up it turns out to be, and pulse it.
  Future<bool> _revealInThread(
    String messageId, {
    double alignment = 0.5,
  }) async {
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

  /// THE toast. A SnackBar can't be used here — ScaffoldMessenger renders
  /// inside the Scaffold's subtree, below this root overlay entry and behind
  /// the scrim — but [AppToast] inserts into the root overlay itself, above
  /// this entry, so the thread speaks with the same voice as the room. (It
  /// had its own blurred, accent-bordered copy that popped in and out.)
  void _showToast(String message) {
    if (!mounted) return;
    AppToast.of(context).show(message);
  }

  /// What the thread's composer may capture.
  ///
  /// Voice notes and video notes only — no camera. The camera is a full-screen
  /// route and this composer lives inside a root `OverlayEntry` that a route
  /// would fight for layering, which is exactly why `onCamera` and `onAttach`
  /// have always been null here. Both recorders are inline: they push nothing,
  /// they grow the composer upward, and so the objection that keeps
  /// attachments out of a thread simply does not apply to them.
  ComposerCapture get _threadCapture => ComposerCapture(
        modes: const [ComposerInputMode.voice, ComposerInputMode.videoNote],
        onCaptured: _onCaptured,
        onProblem: _onCaptureProblem,
      );

  /// Sends a recording into the thread, tethered to the same reply target a
  /// text message would take. Without that tether it would land in the room but
  /// outside the thread and appear to vanish from this overlay — the exact trap
  /// [_resolveTarget] documents.
  void _onCaptured(ComposerInputMode mode, CaptureOutcome outcome) {
    if (!mounted) return;
    final target = _resolveTarget(_messages);
    if (target == null) {
      _showToast(AppLocalizations.of(context).threadOverlayReplyTargetNotFound);
      return;
    }
    if (target.id.startsWith('tmp_')) {
      _showToast(AppLocalizations.of(context).threadOverlayStillSending);
      return;
    }
    final type = mode == ComposerInputMode.videoNote
        ? MessageType.videoNote
        : MessageType.audio;
    void send(Uint8List? poster) => widget.repo.sendMediaLocal(
          roomId: widget.roomId,
          bytes: outcome.bytes,
          contentType: outcome.contentType,
          type: type,
          posterBytes: poster,
          mediaDurationMs: outcome.duration.inMilliseconds,
          replyToId: target.id,
          viewOnce: outcome.viewOnce,
        );
    if (!outcome.viewOnce) {
      send(outcome.posterBytes);
    } else {
      // The room screen's rule: never the full poster on a play-once send,
      // only a video note's sixteen-pixel stand-in.
      unawaited(() async {
        send(type == MessageType.videoNote
            ? await viewOnceMicroPoster(outcome.posterBytes)
            : null);
      }());
    }
    if (_scroll.hasClients) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onCaptureProblem(CaptureFailure failure) {
    if (!mounted) return;
    // The permission sheet is a pushed route and this overlay's scrim would
    // blur it — the same objection the child-gate handler makes. A sheet is not
    // a camera, though: it presents *above* the overlay rather than fighting it
    // for the same layer, so it is shown here rather than handed to the host.
    unawaited(showCaptureProblem(context, failure, onMessage: _showToast));
  }

  /// TRANSLATE, from a bubble inside the thread.
  ///
  /// The room screen's version of this also offers to translate the whole
  /// room; this one deliberately does not. A thread is a slice of a room the
  /// reader opened on purpose, and answering "translate this one message" with
  /// an offer about the room behind it changes the subject.
  /// Toggles one reaction, and owns the one refusal worth explaining.
  Future<void> _toggleReaction(ChatMessage m, String emoji) async {
    final error =
        await widget.repo.toggleReaction(messageId: m.id, emoji: emoji);
    if (!mounted || error != kReactionLimitError) return;
    await showReactionLimitNotice(
      context,
      surface: ReactionLimitSurface.message,
    );
  }

  Future<void> _translate(ChatMessage m) async {
    final sebastian = Sebastian.instance;
    if (!sebastian.isInstalled) {
      final ready = await showCompanionInstallSheet(
        context,
        companion: Companion.sebastian,
        brain: sebastian.brain,
      );
      if (!ready || !mounted) return;
    }
    if (!sebastian.isEnabled) {
      await SettingsStore.instance.setSebastianEnabled(true);
      if (!mounted) return;
    }
    sebastian.translate(m);

    // Nothing to do — the detector settled it synchronously. Reported as a
    // toast rather than as a slab in the bubble, matching the room; see
    // `TranslationSlab`, which draws nothing for this state.
    final handle = sebastian.handleFor(m);
    if (handle != null && handle.state == TranslationState.sameLanguage) {
      if (!mounted) return;
      _showToast(AppLocalizations.of(context)
          .roomScreenAlreadyInLanguageSnack(sebastian.targetLanguage.autonym));
    }
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

  void _onMentionChanged() {
    if (mounted) setState(() {});
  }

  /// Opens a mentioned user's profile from inside the thread. Resolved against
  /// What the overlay can do to a poll, checklist or event inside a thread.
  ///
  /// The same set the transcript offers, wired to the same repository — a card
  /// answered here and the copy of it underneath are one object, so the two
  /// surfaces cannot disagree about the tally.
  ///
  /// Built once per build rather than per row, for the reason
  /// [InteractionActions] carries the message id at all: a thread is a list,
  /// and most of its rows are not interactive.
  ///
  /// A refusal is silent here, unlike in the room. The overlay sits above the
  /// transcript with its own scrim, and a snack bar posted from underneath it
  /// either does not appear or appears behind it — so the control simply goes
  /// back to where it was, which is the same thing the reader sees when a tap
  /// does not land.
  InteractionActions get _interactionActions => InteractionActions(
        onRespond: (messageId, choiceId) => widget.repo.respondToInteraction(
          roomId: widget.roomId,
          messageId: messageId,
          choiceId: choiceId,
        ),
        onRetract: (messageId) => widget.repo.retractInteraction(
          roomId: widget.roomId,
          messageId: messageId,
        ),
        onClose: (messageId) =>
            widget.repo.closeInteraction(messageId: messageId),
        onAddItem: (messageId, label) =>
            widget.repo.addChecklistItem(messageId: messageId, label: label),
        onRemoveItem: (messageId, choiceId) => widget.repo
            .removeChecklistItem(messageId: messageId, choiceId: choiceId),
        onShowRespondents: _showRespondents,
      );

  Future<void> _showRespondents(String messageId) async {
    final interaction = widget.repo.interactionFor(widget.roomId, messageId);
    final me = widget.repo.userId;
    if (interaction == null || me == null) return;
    await showInteractionRespondentsSheet(
      context,
      api: widget.api,
      messageId: messageId,
      currentUserId: me,
      interaction: interaction,
      resolveUser: (id) => widget.repo.userById(id),
      onOpenProfile: (user) => _openMentionedProfile(user.id),
    );
  }

  /// the roster snapshot the overlay was handed; someone who has left the room
  /// still renders as a mention but has no profile to open.
  void _openMentionedProfile(String userId) {
    ChatUser? user;
    for (final u in widget.members) {
      if (u.id == userId) {
        user = u;
        break;
      }
    }
    if (user == null || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProfileScreen(user: user!, repo: widget.repo, api: widget.api),
      ),
    );
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    final target = _resolveTarget(_messages);
    if (target == null) {
      _showToast(AppLocalizations.of(context).threadOverlayReplyTargetNotFound);
      return;
    }
    if (target.id.startsWith('tmp_')) {
      _showToast(AppLocalizations.of(context).threadOverlayStillSending);
      return;
    }
    final mentions = _composer.mentions;
    final everyone = _composer.everyone;
    final formatting = _composer.formatting;
    _composer.clearMentions();
    _composer.clearFormatting();
    _composer.clear();
    // Disarm: the reply is sent, so an explicit target has nothing left to
    // say. Falling back to null means the next send goes to the tail — which
    // is now the message just sent. Nothing to restore on the refusal path
    // below: it dismisses the overlay and hands the text to the room.
    if (_target != null) setState(() => _target = null);
    await widget.repo.sendText(
      widget.roomId,
      text,
      replyToId: target.id,
      mentions: mentions,
      mentionsEveryone: everyone,
      formatting: formatting,
    );

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

  /// A tap that landed on the transcript rather than on the scrim around it.
  ///
  /// The rule is the scrim's: the background dismisses, the messages don't.
  /// It has to be re-stated here only because a [Scrollable] hit-tests opaque
  /// across its whole viewport, so a tap in the empty half of a row never
  /// reaches the scrim underneath to be handled there — on a phone the list is
  /// the entire window, which left the close button as the only way out.
  ///
  /// Two things come before the dismiss:
  ///  * While the soft keyboard — or the expression panel standing in its
  ///    place — is up, the tap only puts it away. The composer may be holding
  ///    a half-typed reply and closing would take it along.
  ///  * A tap on a message is a tap on content, not on the background.
  ///
  /// Anything that handles its own taps — a photo, a pill, a link, a mention —
  /// never gets this far; its recognizer wins the arena first.
  void _tapTranscript(Offset globalPosition, {required bool keyboardUp}) {
    // The expression panel stands in the keyboard's place, so it gets the
    // keyboard's rule: the first tap only puts it away. Checked first — with
    // the panel up the keyboard is down, and a tap would otherwise close the
    // whole thread under a reply the user was picking a sticker for.
    if (_expressions.isOpen) {
      _expressions.hide();
      return;
    }
    if (keyboardUp) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_tapLandedOnAMessage(globalPosition)) return;
    unawaited(_dismiss());
  }

  /// Whether [globalPosition] is inside some bubble's own box.
  ///
  /// Measured off [_bubbleKeys] rather than the row keys because a row is
  /// always the full width of the list: by the row, every tap is on a message
  /// and nothing would ever dismiss. Only mounted rows are checked, which is
  /// every row a finger can reach.
  bool _tapLandedOnAMessage(Offset globalPosition) {
    for (final key in _bubbleKeys.values) {
      final ctx = key.currentContext;
      if (ctx == null || !ctx.mounted) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      if (rect.contains(globalPosition)) return true;
    }
    return false;
  }

  // ───────────── action menu ─────────────

  Future<void> _onLongPressBubble(ChatMessage m, ChatUser? author) async {
    final isMine = m.senderId == widget.repo.userId;
    // The shared table, then this overlay's deliberate subtractions:
    //  * VIEW THREAD would recurse — the user already sees the thread.
    //  * FORWARD and SELECT belong to the transcript, which owns the
    //    selection bar and the target sheet — an overlay with its own
    //    composer and its own scroll position is not where a bulk action
    //    should start.
    //  * EDIT is off until this overlay grows its own edit-mode composer
    //    state; offering the row and dumping the user back into the room's
    //    composer would be worse than not offering it here yet.
    // An unresolvable room (this overlay only ever holds a `roomId`) affords
    // the locked-down floor inside `capabilitiesForMessage`, which drops the
    // SAVE row rather than offering one that would throw.
    final caps = widget.repo
        .capabilitiesForMessage(m, widget.repo.roomById(widget.roomId),
            senderIsSystem: widget.members
                .any((u) => u.id == m.senderId && u.isSystem))
        .copyWith(
          canViewThread: false,
          canForward: false,
          canSelect: false,
          canEdit: false,
        );
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
    final newSender = !sameSenderAsPrev(prev, m);
    final next = j == -1 || j + 1 >= messages.length ? null : messages[j + 1];
    final lastInRun = next == null || !continuesRun(m, next);

    final me = widget.repo.userId;
    final mine = {
      for (final r in m.reactions)
        if (r.userId == me) r.emoji,
    };
    final result = await showMessageActionMenu(
      context: context,
      anchorKey: anchor,
      isMine: isMine,
      myReactions: mine,
      // Withheld only where a companion cannot run at all — the same shape
      // the room screen uses, and for the same reason: not being installed
      // yet is the discovery path, not a refusal.
      capabilities:
          Sebastian.instance.isAvailable ? caps : caps.copyWith(canTranslate: false),
      isPinned: widget.repo.isMessagePinned(widget.roomId, m.id),
      isSaved: widget.repo.isMessageSaved(widget.roomId, m.id),
      isTranslated: Sebastian.instance.isShowingTranslation(m),
      // Same reason as in the room: a document's row can only afford one line
      // of its name, and this is where the whole thing is legible.
      fileName: m.type == MessageType.file ? m.fileName : null,
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
        newSender: newSender,
        lastInRun: lastInRun,
      ),
    );
    if (!mounted || result == null) return;
    if (result.emoji != null) {
      await _toggleReaction(m, result.emoji!);
      return;
    }
    if (result.openFullReactionPicker) {
      final pick = await pickReaction(context, selected: mine);
      if (pick == null || pick.emoji.isEmpty) return;
      // A grid pick of one already held is a no-op — choosing it from a
      // picker means "this one", not "take it back"; the strip is for that.
      if (!pick.remove && mine.contains(pick.emoji)) return;
      await _toggleReaction(m, pick.emoji);
      return;
    }
    switch (result.action!) {
      case MessageAction.translate:
        await _translate(m);
        break;
      case MessageAction.showOriginal:
        Sebastian.instance.showOriginal(m);
        break;
      case MessageAction.translateAgain:
        Sebastian.instance.translateAgain(m);
        break;
      case MessageAction.reply:
        // Stays in the thread now that there's a composer here — retarget
        // rather than dismissing to the room's composer.
        _armReply(m);
        break;
      case MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: m.content));
        if (!context.mounted) return;
        _showToast(AppLocalizations.of(context).threadOverlayCopiedToast);
        break;
      case MessageAction.copyName:
        await Clipboard.setData(ClipboardData(text: m.fileName ?? ''));
        if (!context.mounted) return;
        _showToast(AppLocalizations.of(context).threadOverlayNameCopiedToast);
        break;
      case MessageAction.copyCoordinates:
        final share = m.locationShare;
        if (share != null) {
          await Clipboard.setData(ClipboardData(
              text: formatCoordinates(share.latitude, share.longitude)));
        }
        if (!context.mounted) return;
        _showToast(
            AppLocalizations.of(context).threadOverlayCoordinatesCopiedToast);
        break;
      case MessageAction.info:
        // Never offered here: the thread has no receipts screen to open, and
        // `canViewReceipts` is only switched on by the room.
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
      case MessageAction.pin:
        final err = await widget.repo.pinMessage(widget.roomId, m.id);
        if (err == null) break;
        if (!context.mounted) return;
        _showToast(
          err == 'PIN_LIMIT_REACHED'
              ? AppLocalizations.of(context).threadOverlayPinLimitToast
              : AppLocalizations.of(context).threadOverlayPinFailedToast,
        );
        break;
      case MessageAction.unpin:
        await widget.repo.unpinMessage(widget.roomId, m.id);
        break;
      case MessageAction.save:
        final saveErr = await widget.repo.saveMessage(widget.roomId, m.id);
        if (saveErr == null) break;
        if (!context.mounted) return;
        _showToast(
          saveErr == 'SAVE_LIMIT_REACHED'
              ? AppLocalizations.of(context).threadOverlaySaveLimitToast
              : AppLocalizations.of(context).threadOverlaySaveFailedToast,
        );
        break;
      case MessageAction.unsave:
        await widget.repo.unsaveMessage(widget.roomId, m.id);
        break;
      case MessageAction.delete:
        // Asks first, as the room does: permanent, and for everyone.
        final l10n = AppLocalizations.of(context);
        final confirmed = await showConfirmSheet(
          context,
          headline: l10n.roomScreenDeleteMessageHeadline(1),
          body: l10n.roomScreenDeleteConfirmBodyOne,
          confirmLabel: l10n.roomScreenDeleteConfirmButton,
        );
        if (!confirmed || !mounted) break;
        _deletions.begin([m]);
        try {
          await widget.repo.deleteMessage(m.id);
        } catch (_) {
          _deletions.cancel([m.id]);
          rethrow;
        }
        break;
      case MessageAction.report:
        if (!context.mounted) return;
        final myId = widget.repo.userId;
        if (myId == null) return;
        await fileReport(
          context,
          api: widget.api,
          reporterId: myId,
          target: ReportTarget.message,
          targetId: m.id,
        );
        break;
      case MessageAction.modRemoveMessage:
      case MessageAction.modRemoveContent:
      case MessageAction.modBanUser:
      case MessageAction.modUnbanUser:
      case MessageAction.modDismiss:
        final card = m.moderationCard;
        if (card == null || !context.mounted) return;
        await runModeratorAction(
          context,
          api: widget.api,
          card: card,
          action: result.action!,
        );
        break;
      case MessageAction.viewThread:
      case MessageAction.forward:
      case MessageAction.select:
      case MessageAction.edit:
        // None of these rows are offered in here — see the `copyWith`
        // subtractions where `caps` is built above. The switch must still be
        // exhaustive.
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
    bool newSender = true,
    bool lastInRun = true,
    double highlightT = 0,
  }) {
    final me = widget.repo.userId ?? '';
    final isDm = widget.repo.roomById(widget.roomId)?.isDm ?? false;
    // Only the rows in the list get one. The action menu's preview is built
    // from this same method, and a GlobalKey can only be in the tree once —
    // handing it out twice would tear the bubble out of the transcript the
    // moment the menu opened.
    final bubbleKey = interactive
        ? _bubbleKeys.putIfAbsent(
            m.id,
            () => GlobalKey(debugLabel: 'thread-bubble-${m.id}'),
          )
        : null;
    // Same bracketing as the room transcript — see room_screen's builder.
    // Gated on `newSender`, not `grouped`: see room_screen's own comment.
    final name = (m.senderId == me || isDm || !newSender)
        ? null
        : (author?.displayName.trim().isNotEmpty ?? false
              ? author!.displayName
              : (m.senderName.trim().isEmpty ? null : m.senderName));
    // The same two cursors the transcript reads, and read the same way. The
    // overlay is always opened over the room that is already open, so the
    // repository's active read/delivery state is this thread's room's. Left
    // unpassed, a reply would sit on one tick in the overlay while its own copy
    // in the transcript underneath showed two.
    final mine = m.senderId == me;
    final othersRead = widget.repo.latestOthersReadAt;
    final othersDelivered = widget.repo.latestOthersDeliveredAt;
    final seenByOthers =
        mine && othersRead != null && !othersRead.isBefore(m.createdAt);
    final deliveredToOthers = mine &&
        othersDelivered != null &&
        !othersDelivered.isBefore(m.createdAt);
    // Same reasoning as the two cursors above: a reply is one message with two
    // copies on screen, and a bookmark visible in the transcript underneath but
    // not in the overlay would read as two different messages.
    final saved = widget.repo.isMessageSaved(widget.roomId, m.id);
    final pinned = widget.repo.isMessagePinned(widget.roomId, m.id);
    // A poll can be replied to, so a poll can be IN a thread — and the overlay
    // reads the same repository the transcript does, so the card behind it is
    // the same object with the same tally. Without this it would render as its
    // question with no options for as long as the overlay stayed open, since
    // `interaction: null` is the "body has not arrived" state and nothing here
    // would ever deliver one.
    final interaction =
        m.type.isInteractive ? widget.repo.interactionFor(widget.roomId, m.id) : null;
    if (m.isEphemeral) {
      return EphemeralMessageBubble(
        seenByOthers: seenByOthers,
        deliveredToOthers: deliveredToOthers,
        saved: saved,
        pinned: pinned,
        bubbleKey: bubbleKey,
        message: m,
        now: _fadeNow,
        currentUserId: me,
        api: widget.api,
        author: author,
        useHero: false,
        grouped: grouped,
        lastInRun: lastInRun,
        showAvatarSlot: !isDm,
        showAvatar: lastInRun,
        senderName: name,
        highlightT: highlightT,
        replyMarker: replyMarker,
        onMentionTap: _openMentionedProfile,
        // Null hides the branch button — no thread-within-a-thread.
        onViewThread: null,
        onReplyIndicatorTap: interactive
            ? (parentId) => _jumpToParent(parentId, from: m)
            : null,
        onLongPress: interactive ? () => _onLongPressBubble(m, author) : null,
        onDoubleTap: interactive ? () => _onLongPressBubble(m, author) : null,
        interaction: interaction,
        interactionActions: _interactionActions,
      );
    }
    return MessageBubble(
      seenByOthers: seenByOthers,
      deliveredToOthers: deliveredToOthers,
      saved: saved,
      pinned: pinned,
      bubbleKey: bubbleKey,
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
      senderName: name,
      highlightT: highlightT,
      replyMarker: replyMarker,
      onMentionTap: _openMentionedProfile,
      onViewThread: null,
      onReplyIndicatorTap: interactive
          ? (parentId) => _jumpToParent(parentId, from: m)
          : null,
      onLongPress: interactive ? () => _onLongPressBubble(m, author) : null,
      onDoubleTap: interactive ? () => _onLongPressBubble(m, author) : null,
      // A play-once voice message plays in its own pill, so it can be heard
      // here. A sealed photo or video note opens a route, and a route pushed
      // from this root overlay entry lands BENEATH it — the one look would be
      // spent on a viewer nobody can see. Those stay inert in a thread, as
      // photos always have.
      onOpenViewOnce:
          m.type == MessageType.audio ? () => _openViewOnce(m) : null,
      interaction: interaction,
      interactionActions: _interactionActions,
    );
  }

  /// The room screen's `_openViewOnce`: spends the look, says why not when it
  /// can't be had, and hands the bytes to the bubble.
  Future<Uint8List?> _openViewOnce(ChatMessage m) async {
    final l10n = AppLocalizations.of(context);
    if (!await AppOnly.confirmViewOnce(context)) return null;
    final res = await fetchViewOnce(
      repo: widget.repo,
      roomId: widget.roomId,
      messageId: m.id,
    );
    final bytes = res.bytes;
    if (bytes != null) return bytes;
    _showToast(viewOnceFailureMessage(l10n, m.type, res.failure!));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // See room_screen.build — assigned per build so a theme change reaches it.
    _composer.tint = theme.accent;
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
    final bottomInset = media.viewInsets.bottom > media.padding.bottom
        ? media.viewInsets.bottom
        : media.padding.bottom;
    // See room_screen.build: the panel takes the keyboard's exact height.
    _expressions.noteKeyboardInset(media.viewInsets.bottom);

    return ExpressionSheetScope(
      // Sheets pushed from here would land UNDER this root overlay entry.
      enabled: false,
      child: Material(
      type: MaterialType.transparency,
      // The overlay mounts on the ROOT overlay, so the room's own scope is not
      // an ancestor of anything in here — a thread would print its replies in
      // plain ink while the transcript one layer down had them coloured, and
      // two views of the same message would disagree.
      //
      // Built from the roster the room already handed over rather than from a
      // second subscription, for exactly the reason `members` is passed at all.
      child: SpeakerScope(
        slots: _speakerSlots,
        child: OverlayModalScope(
        onDismiss: _dismiss,
        // This overlay owns a text field, so restoring focus to the room's
        // composer on close would pop the keyboard straight back up.
        restoreFocus: false,
        child: Stack(
          children: [
            // Frosted scrim. Tap to dismiss — after the expression panel, if
            // it is up, by the same first-tap rule as `_tapTranscript`.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_expressions.isOpen) {
                    _expressions.hide();
                    return;
                  }
                  unawaited(_dismiss());
                },
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
                          // hit-tests through to the scrim behind — so tapping
                          // the middle of "thread unavailable" already dismisses,
                          // and there is no keyboard to put away first (no
                          // composer without a target).
                          child: messages.isEmpty
                              ? Center(
                                  child: hasLoaded
                                      ? Text(
                                          AppLocalizations.of(
                                            context,
                                          ).threadOverlayUnavailable,
                                          style: theme.bodySoft.copyWith(
                                            color: theme.inkMuted,
                                          ),
                                        )
                                      : const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CupertinoActivityIndicator(radius: 11),
                                        ),
                                )
                              : GestureDetector(
                                  // Tapping the transcript closes the thread, or
                                  // puts the keyboard away when it's up — see
                                  // [_tapTranscript]. Translucent so it wins the
                                  // arena ahead of the scrim, which the
                                  // Scrollable's opaque hit-testing keeps these
                                  // taps away from regardless.
                                  behavior: HitTestBehavior.translucent,
                                  onTapUp: (d) => _tapTranscript(
                                    d.globalPosition,
                                    keyboardUp: media.viewInsets.bottom > 0,
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: _buildList(
                                          _lastShown =
                                              _deletions.withHeld(messages),
                                          loading,
                                        ),
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
                                                          onTap:
                                                              _scrollToBottom,
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
            // Top-leading, like every ×.
            PositionedDirectional(
              top: 0,
              start: 16,
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: curved,
                  // Grown, not faded: the × is glass, and in a fading layer
                  // its blur samples an empty buffer, a flat wash until the
                  // fade ends and the frost snaps in. See [GlassReveal].
                  builder: (_, child) =>
                      GlassReveal(t: curved.value, from: 0.6, child: child!),
                  // The Padding was inside the button until it moved out to
                  // `glass_close_button.dart`; position is the caller's
                  // business, and the other two surfaces place it differently.
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GlassCloseButton(
                      onTap: _dismiss,
                      semanticLabel: AppLocalizations.of(
                        context,
                      ).photoChromeCloseSemanticLabel,
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildList(List<ChatMessage> messages, bool loading) {
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
                  child: CupertinoActivityIndicator(radius: 9),
                ),
              ),
            );
          }
          final j = messages.length - 1 - i; // chronological index
          final m = messages[j];
          final author =
              widget.repo.userById(m.senderId) ??
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
          final newSender = !sameSenderAsPrev(prev, m);

          // Whether anything below continues this run — the next message must
          // be evaluated the same way, marker included.
          final next = j + 1 < messages.length ? messages[j + 1] : null;
          final lastInRun = next == null || !continuesRun(m, next);

          final canReply =
              !m.id.startsWith('tmp_') &&
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
              newSender: newSender,
              lastInRun: lastInRun,
              highlightT: _highlightedId == m.id ? _pulse.value : 0.0,
            ),
          );

          final rowKey = _keys.putIfAbsent(
            m.id,
            () => GlobalKey(debugLabel: 'thread-${m.id}'),
          );
          if (!m.isEphemeral) _deletions.registerRow(m.id, [m.id], rowKey);
          return KeyedSubtree(
            key: rowKey,
            child: DissolvingRow(
              entry: _deletions.entryFor(m.id),
              onGone: () => _deletions.end(m.id),
              child: bubble,
            ),
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
    // Everything sent from here is a reply, so a room whose posting policy
    // takes no posts, or no replies, gets the room's read-only footer in the
    // composer's place. See `room_posting_policy.dart`.
    final posting = room == null
        ? RoomPostingPolicy.open
        : widget.repo.capabilitiesFor(room).posting;
    if (!posting.canPost || !posting.canReply) {
      return ChatColumn(child: ReadOnlyComposerFooter(glass: !classic));
    }
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
            // The @-picker, unlike the attach flow below, is safe here precisely
            // because it is a sibling in this Column rather than an overlay of its
            // own — there is nothing for this root entry to fight with.
            if (_mention.isOpen)
              MentionPicker(session: _mention, api: widget.api),
            // Attachments are deliberately absent: the attach flow pushes
            // full-screen routes (camera, voice recorder) that would fight this
            // root-overlay entry for layering. What IS offered is the composer's
            // own inline recorders — see [_threadCapture] — which push nothing.
            if (classic)
              ComposerSearchTakeover(
                controller: _expressions,
                child: ChatComposerClassic(
                controller: _composer,
                focusNode: _composerFocus,
                ephemeral: ephemeral,
                onSend: _send,
                onChanged: (_) => widget.repo.noteTyping(),
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                capture: _threadCapture,
                mention: _mention,
                onExpressions: () => _expressions.toggle(_composerFocus),
                expressionsOpen: _expressions.isOpen && !_expressions.closing,
                onFieldTap: _expressions.dismiss,
                onContentInserted: _onKeyboardContent,
              ),
              )
            else
              ComposerSearchTakeover(
                controller: _expressions,
                child: ChatComposerLiquid(
                controller: _composer,
                focusNode: _composerFocus,
                ephemeral: ephemeral,
                onSend: _send,
                onChanged: (_) => widget.repo.noteTyping(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                capture: _threadCapture,
                mention: _mention,
                onExpressions: () => _expressions.toggle(_composerFocus),
                expressionsOpen: _expressions.isOpen && !_expressions.closing,
                onFieldTap: _expressions.dismiss,
                onContentInserted: _onKeyboardContent,
              ),
              ),
            // No "make a sticker" here: that flow pushes a full-screen route,
            // which this root-overlay entry would sit on top of.
            if (_expressions.isOpen)
              ExpressionPanel(
                controller: _expressions..setLayout(
                  // See the room screen's `_expressionPanel` for the budget.
                  expanded: MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).vertical -
                      190,
                  room: MediaQuery.sizeOf(context).height -
                      MediaQuery.paddingOf(context).top -
                      190 +
                      ExpressionPanelController.composerRow,
                  keyboardInset: MediaQuery.viewInsetsOf(context).bottom,
                  resting: MediaQuery.sizeOf(context).height * 0.5,
                ),
                composer: _composer,
                onSend: _sendExpression,
                height: _expressions.currentHeight,
                keyboardInset: _expressions.searching
                    ? 0
                    : MediaQuery.viewInsetsOf(context).bottom,
                onSearchFocusChanged: _expressions.setSearching,
              ),
          ],
        ),
      ),
    );
  }
}
