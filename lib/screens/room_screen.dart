import 'dart:async';
// Reached only from `_deliverShare`, which only ever runs off a share the OS
// staged on disk — an iOS/Android-only path. Flutter web resolves this to its
// stub, so the import costs the web build nothing and never executes there.
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui';
import 'package:camera/camera.dart' show CameraLensDirection;
import 'package:file_selector/file_selector.dart' show openFile;
import 'package:flutter/foundation.dart' show kIsWeb, listEquals;
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
import '../data/mention_session.dart';
import '../data/room_content_selection.dart';
import '../companions/companion.dart';
import '../companions/sebastian.dart';
import '../data/settings_store.dart';
import '../data/spoiler_store.dart';
import '../family/family_service.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/file_meta.dart';
import '../media/video_poster.dart';
import '../media/image_raster.dart';
import '../media/photo_picking.dart';
import '../media/view_once_fetch.dart';
import '../privacy/capture_protection.dart';
import '../services/live_location_permission.dart';
import '../services/live_location_platform.dart';
import '../services/live_share_resume_store.dart';
import '../services/location_service.dart';
import '../models/chat_message.dart';
import '../models/message_formatting.dart';
import '../models/location_share.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/family.dart';
import '../models/room_capabilities.dart';
import '../models/room_content_item.dart';
import '../models/room_pin.dart';
import '../data/ui_selection_store.dart';
import '../platform.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import 'message_receipts_screen.dart';
import 'room_items.dart';
import 'view_once_viewer.dart';
import '../theme/theme_scope.dart';
import '../widgets/anchored_scroll.dart';
import '../widgets/approval_gate.dart';
import '../widgets/attachment_menu.dart';
import '../widgets/bulk_action_bar.dart';
import '../widgets/busy_scrim.dart';
import '../composer/capture_machine.dart';
import '../composer/capture_recorder.dart';
import '../widgets/chat_composer.dart';
import '../widgets/composer_capture.dart';
import '../widgets/chat_pane.dart';
import '../widgets/destructive_sheet.dart' show showConfirmSheet;
import '../widgets/forward_target_sheet.dart';
import '../widgets/glass_pill.dart';
import '../widgets/jump_back.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/location_share_sheet.dart';
import '../widgets/composer_edit_card.dart';
import '../widgets/composer_reply_card.dart';
import '../widgets/mention_picker.dart';
import '../widgets/photo_mosaic.dart' show mosaicHeroTag;
import '../widgets/companion_strip.dart' show kCompanionStripHeight;
import '../widgets/pinned_banner.dart';
import '../widgets/pinned_list_sheet.dart';
import '../widgets/mention_text_controller.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_details_sheet.dart';
import '../widgets/reaction_picker_sheet.dart';
import '../widgets/schedule_message_sheet.dart';
import '../widgets/scheduled_list_sheet.dart';
import '../widgets/scheduled_pill.dart';
import '../widgets/scroll_to_latest.dart';
import '../widgets/selection_check.dart';
import '../widgets/speaker_scope.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/remote_image.dart';
import '../widgets/room_gallery_scope.dart';
import '../widgets/steady_hero.dart';
import '../widgets/swipe_to_receipts.dart';
import '../widgets/swipe_to_reply.dart';
import '../widgets/thread_overlay.dart';
import '../widgets/user_avatar.dart';
import '../widgets/interaction_bubble.dart' show InteractionActions;
import '../widgets/interaction_respondents_sheet.dart';
import '../widgets/companion_install_sheet.dart';
import '../widgets/message_action_menu.dart';
import '../widgets/room_translate_bar.dart';
import '../widgets/report_sheet.dart';
import '../widgets/visibility_badge.dart';
import '../share/share_intake.dart';
import '../share/share_targets.dart';
import '../share/shared_payload.dart';
import 'camera_editor_screen.dart';
import 'interaction_compose_sheet.dart';
import 'camera_screen.dart';
import 'room_content_actions.dart';
import 'fullscreen_image_viewer.dart';
import 'media_pager_screen.dart';
import 'photo_tray_screen.dart';
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
  final MentionTextController _composer = MentionTextController();
  final FocusNode _composerFocus = FocusNode();
  late final MentionSession _mention;
  final ScrollController _scroll = ScrollController();
  // Whether the transcript is parked away from the newest message. Kept in a
  // notifier rather than a field: _onScroll runs on every scroll frame and this
  // screen rebuilds at 5Hz off _ticker already, so a setState here would make
  // the whole transcript pay for a pill.
  final BottomProximity _scrolledUp = BottomProximity();
  final Map<String, ChatUser> _members = {}; // id → user (for sender names/avatars)

  /// Which colour each member speaks in, recomputed only when the roster
  /// itself changes — the assignment is a sort plus a walk, and doing it per
  /// build would redo it on every keyboard frame. `_membersSig` already gates
  /// the roster rebuild, so this rides along on the one signal that matters.
  SpeakerSlots _speakerSlots = SpeakerSlots.none;

  /// Signature of this reader's manual colour pins for the room, so the
  /// assignment is rebuilt when a pin changes and not on every one of the
  /// repository notifications that arrive while a conversation is live.
  String _speakerPinsSig = '';
  Subscription? _membersSub;
  String _membersSig = '';
  ChatRoom? _room;
  // True once we've pushed a CaptureProtection scope for this ephemeral
  // room — so dispose can pop exactly one and we don't double-push.
  bool _pushedCaptureScope = false;
  ChatStyle _lastChatStyle = SettingsStore.instance.chatStyle;
  SpeakerTint _lastSpeakerTint = SettingsStore.instance.speakerTint;

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

  // ──── attachment state ────
  // Guards the whole attach flow against a second tap. Spans the attachment
  // sheet, the picker and the camera screen, none of which used to be guarded at
  // all — a double-tap on `+` opened two sheets and then two pickers, and the
  // second one's result overwrote the first's.
  bool _attachInFlight = false;

  // Drives [BusyScrim]. Set only for the phases where the app is working and
  // there is nothing on screen to say so: the picker's own re-encode of the
  // chosen asset, which happens after its sheet has dismissed, and the read of
  // the resulting bytes over the platform channel. Not set for the camera, which
  // is its own full-screen UI already saying what it does.
  bool _mediaBusy = false;

  // ──── reply state ────
  // The message the composer is currently replying to. Cleared on cancel or
  // after a successful send. Set by the swipe gesture or the action menu.
  ChatMessage? _replyingTo;

  // ──── edit state ────
  // The viewer's own message the composer is currently rewriting — the EDIT
  // row's counterpart to [_replyingTo], and mutually exclusive with it (and
  // with selection): the composer's banner slot says what a send will DO, and
  // it can only say one thing.
  ChatMessage? _editing;

  // Whatever was in the composer when EDIT was armed, so cancelling the edit
  // puts the half-typed message back instead of eating it. Null when nothing
  // was stashed (the composer was empty) AND while no edit is in progress.
  ({
    String text,
    List<MessageMention> mentions,
    bool everyone,
    List<FormattingEntity> formatting,
  })? _draftBeforeEdit;

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

  // Every place we have jumped away from, newest last — what the BACK
  // pill walks off one hop at a time. A plain setState here where _scrolledUp
  // needed a notifier: this changes on taps and one expiry timer, not on every
  // scroll frame.
  final JumpBackStack _jumpBack = JumpBackStack();

  // ──── land-on-unread ────
  // See _maybeLandOnUnread. Snapshotted once in initState, before openRoom's
  // markRoomRead call advances the server cursor and the subscription echoes
  // it back into widget.repo.roomById(...).lastReadAt.
  DateTime? _unreadAnchorReadAt;

  // True from mount until the initial landing has either succeeded or been
  // given up on — guards against re-triggering on a later notification (a
  // reaction, a typing update) once the reader has already scrolled off on
  // their own.
  bool _unreadLandingPending = false;

  /// Which pin the banner is describing. Read as `_pinCursor % pins.length` at
  /// build time and never clamped in place: a pinned message can self-destruct
  /// between subscription frames, so this is allowed to be briefly stale.
  int _pinCursor = 0;

  // ──── multi-select ────
  // Entered from the long-press menu's SELECT row. While it is active the
  // composer is replaced by the selection bar, every bubble becomes a checkbox
  // row, and the gestures a bubble normally owns (play, open, swipe-to-reply)
  // are suppressed — a tap has exactly one meaning in this mode.
  //
  // The same object the shared-content browser uses, deliberately: a selection
  // made in the gallery and one made in the transcript answer to the same two
  // server calls, and holding ids rather than messages is what keeps a bulk
  // action from operating on a message that expired under it.
  final RoomContentSelection _selection = RoomContentSelection();

  /// Most messages one selection may hold, from `messages:deleteMany`'s cap.
  /// Enforced here rather than only at the button so the count on screen is
  /// never a number the server would refuse outright.
  static const int _kMaxSelected = 25;

  /// Most messages one FORWARD may carry, from `messages:forwardToRoom`. Lower
  /// than [_kMaxSelected], so the button dims rather than the selection capping.
  static const int _kMaxForwarded = 10;

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
  // An album's photographs → the message its row stands for. Empty for every
  // message that is its own row, which is nearly all of them.
  Map<String, String> _rowOwnerOf = const {};
  // Memo for the item pass. _ticker rebuilds at 5Hz whether or not anything
  // changed, and messagesFor() hands back the same list instance while no
  // sends are pending, so identity is a cheap and correct cache key.
  List<ChatMessage>? _memoSource;
  String _memoFoldKey = '';
  ({List<RoomItem> items, Set<String> hidden})? _memoResult;

  @override
  void initState() {
    super.initState();
    // A camera button is about to be on screen, and `availableCameras()` is a
    // platform round-trip whose answer cannot change while the app runs. Asking
    // now takes it off the critical path of the tap that follows; it neither
    // opens a session nor prompts for anything.
    CameraScreen.warmUp();
    // Reads `_members` through a closure rather than a captured list so a
    // member who joins mid-sentence is offered without rebuilding the session.
    _mention = MentionSession(
      controller: _composer,
      roster: () => _members.values.toList(),
      selfUserId: widget.repo.userId,
      // "Everyone" in a two-person room is just the other person, who is
      // already looking at the message.
      allowEveryone: () => !(_room?.isDm ?? true),
    );
    // The picker is a conditional child of the composer column, so the screen
    // has to rebuild when it opens or closes. The session only notifies when
    // something it renders actually changed, so ordinary typing does not
    // repaint a list that would look identical.
    _mention.addListener(_onMentionChanged);
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted) return;
      // 5Hz only while a Chamber-of-Secrets countdown can be on screen: the
      // life bar on a fading message is the one reader of `_now` that wants
      // sub-second resolution. Everywhere else it feeds relative timestamps
      // and a live-share "still running" check, which a 1Hz tick serves just
      // as well — and this setState rebuilds the whole transcript, so the
      // other four ticks a second were pure cost, paid out of the same frame
      // budget the receive path parses a message on.
      if (_room?.messageLifetime == null && t.tick % 5 != 0) return;
      setState(() => _now = DateTime.now());
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
    // Snapshotted before openRoom below, which marks the room read and — once
    // the mutation's round trip echoes back through rooms:listUserRooms —
    // moves lastReadAt out from under a cursor taken any later. Guarded on a
    // real unread count: a room with nothing unread has nowhere to land that
    // isn't the bottom, and one that has never been read at all (lastReadAt
    // null) has no cursor to land relative to.
    final roomAtOpen = widget.repo.roomById(widget.roomId);
    if (roomAtOpen != null &&
        roomAtOpen.lastReadAt != null &&
        roomAtOpen.unreadCount > 0) {
      _unreadAnchorReadAt = roomAtOpen.lastReadAt;
      _unreadLandingPending = true;
    }
    // `this` is the ownership token: whichever State opened the room is the
    // only one allowed to close it. Route transitions dispose the outgoing
    // RoomScreen well after the incoming one has opened its room, so an
    // unguarded close used to tear down the room now on screen.
    widget.repo.openRoom(widget.roomId, owner: this);
    _loadMembers();
    // A room switched on in a previous session starts translating the moment
    // it opens, from the disk cache first — which is why reopening a room you
    // already read translated is instant rather than a second round of model
    // runs. No-op on a room that is not switched on.
    Sebastian.instance
        .enqueueRoom(widget.roomId, widget.repo.messagesFor(widget.roomId));
    widget.repo.addListener(_onRepoChange);
    _scroll.addListener(_onScroll);
    _scrolledUp.addListener(_onBottomProximity);
    _jumpBack.addListener(_onJumpBackChanged);
    // Entering, leaving and every tick of the selection swap the bottom chrome
    // and re-skin every visible bubble, so this one is a whole-screen rebuild
    // rather than something a local ValueListenable could scope down.
    _selection.addListener(_onSelectionChanged);
    SettingsStore.instance.addListener(_onSettings);
    // If the room is already in the rooms cache from the subscription, we
    // can push the capture scope immediately. Otherwise _onRepoChange will
    // pick it up on the first notification.
    _maybePushCaptureScope(widget.repo.roomById(widget.roomId));
    // A share the user routed here from the system sheet.
    //
    // Both doors, because there are two. A share that opened this room lands
    // before the first frame; a share sent into the room ALREADY on screen —
    // which on desktop is what selecting the selected room does, i.e. nothing —
    // arrives later and only through the listener.
    ShareIntake.instance.addListener(_takeStagedShare);
    _takeStagedShare();
  }

  /// Collects and delivers a share staged for this room, if there is one.
  ///
  /// Post-frame because delivering opens a route (the editor) and shows snack
  /// bars, neither of which a widget may do while it is being built — and this
  /// is called from `initState` as well as from a notification.
  void _takeStagedShare() {
    final staged = ShareIntake.instance.takeStagedFor(widget.roomId);
    if (staged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_deliverShare(staged));
    });
  }

  // Pushes, pops and the idle expiry all change whether the back pill is there
  // and what it says.
  void _onJumpBackChanged() {
    if (mounted) setState(() {});
  }

  void _onSelectionChanged() {
    if (mounted) setState(() {});
  }

  /// Coming to rest on the newest message retires the reply trail behind it —
  /// however the reader got there, tapping the pill or scrolling by hand.
  ///
  /// Two lines rather than a state machine because [BottomProximity] is already
  /// exactly this signal:
  ///   * its hysteresis band is tuned for this, so a reader parked on the
  ///     threshold — or an iOS rubber-band settle crossing it several times in
  ///     one gesture — can't strobe the trail away;
  ///   * it notifies on transitions only, so a jump that never left the bottom
  ///     band never fires and its pill waits out the idle timer instead. The
  ///     degenerate case fails safe;
  ///   * [JumpBackStack.clear] is silent on an empty trail, so the ordinary
  ///     scroll-to-bottom with nothing pending costs one comparison and
  ///     rebuilds nothing — which is the whole reason _scrolledUp is a notifier.
  void _onBottomProximity() {
    if (!_scrolledUp.value) _jumpBack.clear();
  }

  void _onSettings() {
    final cs = SettingsStore.instance.chatStyle;
    // Speaker colours ride along here for the composer's reply card and the
    // rest of the chrome. Every BUBBLE already repaints itself — each one wraps
    // its row in an `AnimatedBuilder` on this store for the bubble-shape
    // preference — but the card above the composer is built by this screen and
    // would otherwise keep the old colour until something unrelated rebuilt it.
    final st = SettingsStore.instance.speakerTint;
    if (cs == _lastChatStyle && st == _lastSpeakerTint) return;
    _lastChatStyle = cs;
    _lastSpeakerTint = st;
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

  /// Whether [m] must keep its own row — never folded into a chip.
  ///
  /// Nothing to do with user-pinned messages. A pinned message folded into a
  /// thread chip is fine: tapping the pin banner routes through `_travelTo`,
  /// which hands off to the thread overlay when the target is folded.
  ///
  /// The `_dateTracks` clause is the load-bearing one: that map is populated
  /// from the itemBuilder, so containsKey means "this row has already been
  /// built at least once this session". Without it a message would vanish
  /// out from under the reader the moment a newer reply pushed it into the
  /// thread's interior — possibly mid-video, or with its action menu open —
  /// and the same thing would happen on pagination when loadOlder prepends a
  /// root that turns the previously-first message into an interior one.
  bool _mustKeepOwnRow(ChatMessage m) =>
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
    // Everything _mustKeepOwnRow reads has to be in the key, or an armed reply
    // or a highlight pulse would be computed against a stale fold set.
    final foldKey = '${_dateTracks.length}'
        '|${_replyingTo?.id ?? ''}'
        '|${_highlightedMessageId ?? ''}'
        '|${_jumpTargetId ?? ''}';
    final memo = _memoResult;
    if (memo != null &&
        identical(messages, _memoSource) &&
        foldKey == _memoFoldKey) {
      return memo;
    }
    final result = buildRoomItems(
      messages: messages,
      roomIsEphemeral: room.isEphemeral,
      mustKeepOwnRow: _mustKeepOwnRow,
      dayLabel: humanDay,
      unreadAfter: _unreadAnchorReadAt,
    );
    _memoSource = messages;
    _memoFoldKey = foldKey;
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
    final owner = <String, String>{};
    for (var i = 0; i < rev.length; i++) {
      final item = rev[i];
      if (item is MessageItem) {
        index[item.message.id] = i;
        // Every photograph of an album points at the one row that draws it,
        // so a reply-jump or a search hit aimed at the third picture still
        // has somewhere to land.
        for (final p in item.album) {
          index[p.id] = i;
          // And the row's own id alongside it, because an index is not enough
          // on its own: `_dateTracks` is keyed by the id of the message the ROW
          // stands for, so a lookup under the third picture's id finds no
          // render box and every caller that wants one — the jump's landing
          // context, the action menu's anchor — silently falls back to a
          // guess. An album is the only row in the transcript that draws
          // messages other than its own, so it is the only place these two
          // ids come apart.
          owner[p.id] = item.message.id;
        }
      }
    }
    _revSource = chronological;
    _revItems = rev;
    _rowIndexOf = index;
    _rowOwnerOf = owner;
    return rev;
  }

  /// The row that draws [messageId], for the maps keyed by row rather than by
  /// message. Itself for everything that is its own row.
  String _rowOwner(String messageId) => _rowOwnerOf[messageId] ?? messageId;

  /// The render box for the row that draws [messageId], if it is laid out.
  BuildContext? _rowContextOf(String messageId) =>
      _dateTracks['m_${_rowOwner(messageId)}']?.key.currentContext;

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
        {'roomId': widget.roomId, 'viewerUserId': ?widget.repo.userId},
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
            _rebuildSpeakerSlots();
          });
        },
        onError: (err) => debugPrint('members sub error: $err'),
      );
    } catch (_) {
      /* ignore — initial fetch may fail offline */
    }
  }

  /// Re-settles who speaks in which colour.
  ///
  /// Two inputs, both of which change rarely: the roster, and this reader's own
  /// pins. Everything downstream reads the result as a plain map lookup, so
  /// this is the only place the sort and the walk are paid for.
  void _rebuildSpeakerSlots() {
    _speakerSlots = SpeakerSlots.forMembers(
      [
        for (final u in _members.values)
          (id: u.id, joinedAt: u.joinedAt?.millisecondsSinceEpoch ?? 0)
      ],
      exclude: widget.repo.userId,
      pinned: widget.repo.speakerColorsFor(widget.roomId),
    );
  }

  /// Cheap identity for the pin map — empty, and so free, for the rooms nobody
  /// has ever opened the picker in.
  String _speakerPinsSignature() {
    final pins = widget.repo.speakerColorsFor(widget.roomId);
    if (pins.isEmpty) return '';
    final parts = [for (final e in pins.entries) '${e.key}:${e.value}']..sort();
    return parts.join(',');
  }

  String _signatureFor(List<ChatUser> users) {
    final parts = users
        .map((u) =>
            // `username` is in here because the @-picker filters and inserts on
            // it. Including it was once described as belt-and-braces, on the
            // grounds that a handle could never change under the subscription;
            // `users.applyUsernameChange` has since made it load-bearing, and a
            // member who renames now correctly re-arms the picker.
            '${u.id}|${u.status ?? ''}|${u.lastSeen?.millisecondsSinceEpoch ?? 0}|${u.name}|${u.username}|${u.avatarStorageId ?? ''}|${u.role ?? ''}')
        .toList()
      ..sort();
    return parts.join(';');
  }

  /// Message ids this screen has already drawn, and the newest `createdAt`
  /// among them. Together they answer "is this row an arrival, or is it just
  /// scrolling into view?" — which is the whole question, because
  /// `ListView.builder` builds a row for the first time every time it scrolls
  /// past, and animating on that would make the transcript shimmer.
  final Set<String> _drawnMessageIds = {};
  DateTime? _newestDrawnAt;

  /// The ids currently playing their entrance. Small and short-lived: an id
  /// enters on the delivery that carried it and leaves one animation later.
  final Set<String> _arriving = {};
  Timer? _arrivalClear;

  /// Spot messages that were not here a moment ago, so the transcript can grow
  /// them in rather than snap them into place.
  ///
  /// Convex re-sends the whole live window on every change, so "what is new"
  /// cannot be read off the delivery — every row arrives every time. It has to
  /// be diffed against what this screen has already drawn.
  ///
  /// Two things deliberately do NOT animate. The first paint of a room, which
  /// would otherwise play the entire transcript in on open; and anything older
  /// than the newest row already drawn, which is how a page from [loadOlder]
  /// is told apart from an arrival — it is scrolled-to content, not news.
  void _noteArrivals(List<ChatMessage> current) {
    if (current.isEmpty) return;
    if (_drawnMessageIds.isEmpty) {
      for (final m in current) {
        _drawnMessageIds.add(m.id);
      }
      _newestDrawnAt = current.last.createdAt;
      return;
    }
    final was = _newestDrawnAt;
    final fresh = <String>[];
    for (final m in current) {
      if (!_drawnMessageIds.add(m.id)) continue;
      if (was == null || m.createdAt.isAfter(was)) fresh.add(m.id);
    }
    if (current.last.createdAt.isAfter(was ?? current.last.createdAt)) {
      _newestDrawnAt = current.last.createdAt;
    }
    if (fresh.isEmpty) return;
    _arriving.addAll(fresh);
    // One timer for the whole burst rather than one per message: a batch that
    // lands together should finish together, and the set is only a hint to the
    // builder — leaving an id in it a few ms too long costs nothing.
    _arrivalClear?.cancel();
    _arrivalClear = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(_arriving.clear);
    });
  }

  void _onRepoChange() {
    if (!mounted) return;
    final room = widget.repo.roomById(widget.roomId);
    _noteArrivals(widget.repo.timelineFor(widget.roomId));
    // A pin lands through the repository like everything else, so this is where
    // a colour picked in room info reaches the transcript. Gated on the
    // signature because this handler runs on every repository notification and
    // re-settling the palette on each would be a sort per incoming message.
    final pinsSig = _speakerPinsSignature();
    final pinsMoved = pinsSig != _speakerPinsSig;
    setState(() {
      _room = room;
      if (pinsMoved) {
        _speakerPinsSig = pinsSig;
        _rebuildSpeakerSlots();
      }
    });
    _maybePushCaptureScope(room);
    // Feeds arriving messages to Sebastian. A no-op unless this room is
    // switched on, and it short-circuits per message on anything already
    // handled — so the cost on an untranslated room is one set lookup.
    //
    // Here rather than in `build` for a hard reason: `enqueueRoom` notifies,
    // bubbles listen, and a notify from inside build is a loop.
    Sebastian.instance.enqueueRoom(
      widget.roomId,
      widget.repo.messagesFor(widget.roomId),
      // `messagesFor`, not `timelineFor` — deliberately the live list rather
      // than what the transcript happens to be showing. And the reconcile is
      // withheld while a history window is open, because during that the two
      // disagree about what "this room" means. See [Sebastian.enqueueRoom].
      reconcile: !widget.repo.inHistoryWindow(widget.roomId),
    );
    // An emptied transcript has no scroll offset to be away from, and it can
    // happen under the reader: an ephemeral room expires its last message
    // while they are scrolled up. _onScroll can't clear this — there is no
    // list left to scroll — so the pill would come back with the next message
    // and hover over a transcript that is already at its bottom.
    if (widget.repo.timelineFor(widget.roomId).isEmpty) {
      _scrolledUp.value = false;
    }
    _drainChildGate();
    // Deferred a frame so _rowIndexOf reflects the rebuild this notification
    // just triggered above, rather than whatever it held before it.
    if (_unreadLandingPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLandOnUnread());
    }
  }

  /// TRANSLATE, from a bubble's long-press menu.
  ///
  /// Four outcomes, and the ordering of the first three is the whole design of
  /// the entry point: an uninstalled Sebastian does not refuse, he introduces
  /// himself and then does the thing that was asked for.
  Future<void> _translateMessage(
    ChatMessage target,
    ScaffoldMessengerState messenger,
  ) async {
    final sebastian = Sebastian.instance;

    // Not installed → the sheet. It returns true only once his brain is
    // actually on disk, which is what lets the translation below carry on as
    // if nothing had interrupted it. A user who cancels the download gets
    // silence, not an error: they just declined.
    if (!sebastian.isInstalled) {
      final ready = await showCompanionInstallSheet(
        context,
        companion: Companion.sebastian,
        brain: sebastian.brain,
      );
      if (!ready || !mounted) return;
    }

    // Installed but switched off. Tapping TRANSLATE is a clearer statement of
    // intent than the toggle in Settings is, so it counts as switching him on
    // rather than as a reason to send someone to Settings.
    if (!sebastian.isEnabled) {
      await SettingsStore.instance.setSebastianEnabled(true);
      if (!mounted) return;
    }

    sebastian.translate(target);

    // Already in the reader's language. The detector answers this
    // synchronously and long before any model runs, so by the time the menu's
    // exit animation is done the handle is usually already settled — which is
    // why this reads it immediately rather than waiting on anything.
    //
    // A toast and not a slab: this is the one state whose answer is "there was
    // nothing to do", and a permanent note saying so under a message is a note
    // the reader has to dismiss on every message they were curious about. See
    // [TranslationSlab], which renders nothing for it.
    final handle = sebastian.handleFor(target);
    if (handle != null && handle.state == TranslationState.sameLanguage) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(AppLocalizations.of(context)
            .roomScreenAlreadyInLanguageSnack(
                sebastian.targetLanguage.autonym)),
      ));
      return;
    }

    // First translation in a room that is not switched on: offer the room.
    // Once per room per visit — `_offeredRoomTranslate` is state on this
    // screen, so leaving and coming back offers it again, which is right. It
    // is an offer rather than a prompt: no dialog, no decision to make, and it
    // goes away by itself.
    if (!_offeredRoomTranslate && !sebastian.isRoomTranslating(widget.roomId)) {
      _offeredRoomTranslate = true;
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.roomScreenTranslateRoomOffer),
        action: SnackBarAction(
          label: l10n.roomScreenTranslateRoomOfferAction,
          onPressed: () => Sebastian.instance.startRoom(
            widget.roomId,
            widget.repo.messagesFor(widget.roomId),
          ),
        ),
      ));
    }
  }

  /// Whether the "translate the whole room" offer has already been made this
  /// visit. See [_translateMessage].
  bool _offeredRoomTranslate = false;

  /// Snaps the transcript to the first unread message once, as soon as its
  /// row can be located — instead of the reverse:true default of opening at
  /// the very bottom and paging a backlog in above it. Mirrors what a
  /// notification tap or reopening a room with unread messages does in
  /// every big chat app: land where you left off, not where the list ends.
  ///
  /// Self-clearing: gives up (clears [_unreadLandingPending] without
  /// scrolling) once the room's first batch is confirmed in and the target
  /// still can't be found — either it was read on another device since, or
  /// the backlog is deeper than what's loaded. Anything short of that keeps
  /// trying on the next notification rather than landing on a stale guess.
  void _maybeLandOnUnread() {
    if (!_unreadLandingPending || !mounted) return;
    final anchor = _unreadAnchorReadAt;
    if (anchor == null) {
      _unreadLandingPending = false;
      return;
    }
    String? targetId;
    for (final m in widget.repo.timelineFor(widget.roomId)) {
      if (m.createdAt.isAfter(anchor)) {
        targetId = m.id;
        break;
      }
    }
    final index = targetId == null ? null : _rowIndexOf[targetId];
    if (targetId == null || index == null) {
      // Gated on the SUBSCRIPTION landing, not just hasLoadedInitial: that
      // one is already true off a disk-cache hydrate, which can predate
      // whatever arrived while this device was offline — exactly the
      // messages this landing exists to find. Giving up on a stale cache's
      // word would silently disable the feature on precisely its most
      // common trigger: reopening the app after time away.
      if (widget.repo.hasLiveMessages(widget.roomId)) {
        _unreadLandingPending = false;
      }
      return;
    }
    _unreadLandingPending = false;
    final id = targetId;
    unawaited(snapToIndex(
      controller: _scroll,
      // Re-read every hop: a message arriving mid-jump shifts every index.
      targetIndex: () => _rowIndexOf[id],
      itemCount: () => _revItems.length,
      targetContext: () => _dateTracks['m_$id']?.key.currentContext,
      probes: _mountedRowProbes,
      // Lower than a reply jump's 0.3: the point is to show what's NEW below
      // the divider, not to centre the divider itself.
      alignment: 0.15,
      // This is where the screen opens, not a jump the reader triggered —
      // landing already-scrolled reads as "here's where you left off",
      // where an animated scroll-past would read as scrolling through
      // messages the reader hasn't seen yet.
      settle: Duration.zero,
    ));
  }

  /// Surface a child-guard refusal that nobody was awaiting.
  ///
  /// [_send] consumes its own refusal synchronously, right where it can put the
  /// composer's text back. An attachment can't: `sendMediaLocal` is
  /// fire-and-forget by design and may be refused seconds later, possibly after
  /// the user has left the room. So a refused media send used to be *completely*
  /// silent — the bubble was dropped, the reason was stashed, and nothing ever
  /// read it. This is the catch-all. `takeChildGateError` is read-and-clear, so
  /// the text path still wins its own race.
  void _drainChildGate() {
    if (_gateSheetOpen) return;
    final gate = widget.repo.takeChildGateError();
    if (gate == null) return;
    _gateSheetOpen = true;
    // Deferred a frame. This runs from a `notifyListeners` callback, and
    // `showApprovalGate` pushes a route — do that while a frame is building and
    // Flutter asserts. Nothing here is time-critical to the millisecond.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _gateSheetOpen = false;
        return;
      }
      _handleSendGate(gate).whenComplete(() => _gateSheetOpen = false);
    });
  }

  /// A burst of refusals — several photos queued behind one revoked grant —
  /// must not stack a sheet per photo on top of each other.
  bool _gateSheetOpen = false;

  @override
  void dispose() {
    // Compact/medium `openRoom` mirrors this room into `UiSelectionStore` too
    // (see open_room.dart), so a later resize to expanded can find it. Clear
    // it back out on a normal compact dismissal so a stale roomId can't
    // resurrect this (now-closed) room on some LATER, unrelated resize.
    //
    // Guarded on `gLastWindowClass != expanded` so this does NOT fire during
    // the resize-triggered reconciliation pop itself (app.dart's
    // `_reconcileNavigatorForExpanded`) — that pop runs after the window
    // class has already flipped to expanded, and needs this exact selection
    // to still be here for `_ChatTwoPane` to land on. Also guarded on
    // identity so this never clobbers a newer selection already in flight.
    if (UiSelectionStore.instance.roomId == widget.roomId &&
        gLastWindowClass != WindowClass.expanded) {
      UiSelectionStore.instance.selectRoom(null);
    }
    // Spoilers close when you leave. Coming back to a conversation should
    // show it the way anyone opening it fresh would see it, not carry your
    // last visit's peeks — and a spoiler that only stays open for a few
    // seconds in-room would be inconsistent if it survived a whole exit.
    SpoilerStore.instance.clear();
    // Hands back the model weights when the last translating room closes.
    //
    // Several hundred megabytes of resident memory on a device that is also
    // holding this app's images and, shortly, whatever the user opens next.
    // Keeping a brain warm across the whole session is how a chat app becomes
    // the one the OS kills first when it is backgrounded.
    //
    // Deliberately does NOT clear the queue or the handles: the translations
    // stay, so walking out of a room and back in is instant. Only the weights
    // go, and the next translation reloads them — a one-off cost paid by
    // somebody who has just asked for one.
    if (Sebastian.instance.isRoomTranslating(widget.roomId)) {
      unawaited(Sebastian.instance.releaseBrain());
    }
    ShareIntake.instance.removeListener(_takeStagedShare);
    _ticker.cancel();
    _captureController.dispose();
    // Before the controller: the session is a listener on it.
    _mention.removeListener(_onMentionChanged);
    _mention.dispose();
    _composer.dispose();
    _composerFocus.dispose();
    _highlightCtrl.dispose();
    _hideTimer?.cancel();
    _arrivalClear?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _scrolledUp.removeListener(_onBottomProximity);
    _scrolledUp.dispose();
    _jumpBack.removeListener(_onJumpBackChanged);
    _jumpBack.dispose();
    _selection.removeListener(_onSelectionChanged);
    _selection.dispose();
    _membersSub?.cancel();
    widget.repo.removeListener(_onRepoChange);
    SettingsStore.instance.removeListener(_onSettings);
    widget.repo.closeRoom(this);
    if (_pushedCaptureScope) {
      CaptureProtection.instance.popScope();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    // An armed edit takes the whole send: the composer's contents are the
    // message's NEW text, not a new message.
    final editing = _editing;
    if (editing != null) {
      await _sendEdit(editing, text);
      return;
    }
    // Snapshot the reply target BEFORE the async send, then disarm: the reply
    // is sent, so the card has nothing left to say. It stays armed only when
    // the send is refused below, since then there's still a pending reply.
    final replyTarget = _replyingTo;
    // Same snapshot-then-clear for the mentions and formatting, and for the
    // same reason — the refusal path below has to be able to put them back.
    final mentions = _composer.mentions;
    final everyone = _composer.everyone;
    final formatting = _composer.formatting;
    setState(() => _replyingTo = null);
    _composer.clearMentions();
    _composer.clearFormatting();
    _composer.clear();
    // Sending while reading old history: the optimistic bubble lands on the
    // live tail, so come back to it rather than leaving the sender staring at
    // a transcript their own message isn't in.
    widget.repo.exitHistoryWindow(widget.roomId);
    await widget.repo.sendText(
      widget.roomId,
      text,
      replyToId: replyTarget?.id,
      mentions: mentions,
      mentionsEveryone: everyone,
      formatting: formatting,
    );
    // A child guard rejection drops the optimistic bubble rather than leaving
    // it in the retry queue, so say why instead of letting the message just
    // vanish. Most likely a grant was revoked while the room was open.
    final gate = widget.repo.takeChildGateError();
    if (gate != null && mounted) {
      // Nothing was sent — put the user back exactly where they were. The
      // mentions have to come back with the text: restoring "@bob" as plain
      // characters would leave a retry that reads like a tag and notifies
      // nobody.
      setState(() {
        _composer.text = text;
        _composer.restoreMentions(mentions, everyone: everyone);
        _composer.restoreFormatting(formatting);
        _replyingTo = replyTarget;
      });
      _keepComposerFocus();
      await _handleSendGate(gate);
      return;
    }
    _keepComposerFocus();
    _scrollToBottom();
    // The OS ranks share-sheet suggestions by who you actually talk to, and
    // this is where the app finds that out.
    _touchShareTarget();
  }

  /// Hold-Send: queue what is in the composer for later instead of sending it.
  ///
  /// Deliberately mirrors [_send]'s snapshot → clear → restore-on-refusal
  /// contract rather than inventing a second one. Every reason that shape
  /// exists applies here with more force: a scheduled send can be refused by
  /// exactly the same child guard, and a restore that dropped the mentions
  /// would leave a retry that reads like a tag and notifies nobody.
  ///
  /// An armed EDIT takes precedence and is not schedulable — editing an
  /// existing message is a change to something already sent, and "send this
  /// change next Tuesday" is a different feature nobody asked for. The sheet is
  /// simply not offered while an edit is armed (see [_composerSchedule]).
  Future<void> _scheduleSend() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;

    // Chamber of Secrets: the hold fires and SAYS WHY rather than doing
    // nothing. Making the gesture absent here was the first shape of this, and
    // it was wrong in the way a dead control always is — the user holds, feels
    // the button not respond, and learns nothing except that the app is broken.
    // `scheduledMessages:schedule` refuses this server-side too; this is the
    // half that explains it.
    if (_room?.isEphemeral ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).scheduleErrorNotInEphemeral),
        ),
      );
      return;
    }

    final choice = await showScheduleMessageSheet(
      context,
      preview: text,
      queuedCount: widget.repo.pendingScheduledCount(widget.roomId),
    );
    if (!mounted) return;
    // The queue row is the only way into the list when the pill is switched
    // off, so it lands here rather than opening a second sheet over this one.
    // The composer is left exactly as it was — nothing was scheduled.
    if (choice is ScheduleShowQueued) {
      _openScheduledList();
      return;
    }
    if (choice is! ScheduleAt) return;
    final at = choice.at;

    final replyTarget = _replyingTo;
    final mentions = _composer.mentions;
    final everyone = _composer.everyone;
    final formatting = _composer.formatting;
    setState(() => _replyingTo = null);
    _composer.clearMentions();
    _composer.clearFormatting();
    _composer.clear();

    final code = await widget.repo.scheduleText(
      widget.roomId,
      text,
      // An absolute instant, not a length: the sheet resolved a wall-clock
      // intent in this device's timezone, which the server cannot re-derive.
      // See `SchedulePreset` for why the two forms both exist.
      sendAt: at.millisecondsSinceEpoch,
      replyToId: replyTarget?.id,
      mentions: mentions,
      mentionsEveryone: everyone,
      formatting: formatting,
    );
    if (code == null || !mounted) return;

    // Nothing was queued — put the user back exactly where they were, the same
    // way a refused live send does.
    setState(() {
      _composer.text = text;
      _composer.restoreMentions(mentions, everyone: everyone);
      _composer.restoreFormatting(formatting);
      _replyingTo = replyTarget;
    });
    _keepComposerFocus();
    // A child-guard refusal wants the approval flow, not a sentence — the same
    // routing [_send] gives it.
    if (code == kChildApprovalRequired || code == kChildNotAllowed) {
      await _handleSendGate(code);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(scheduleErrorSentence(context, code))),
    );
  }

  /// The hold-to-schedule callback for the composer, or null where the gesture
  /// must not exist at all.
  ///
  /// Null ONLY while an edit is armed. A Chamber of Secrets room keeps the
  /// gesture and refuses it with a sentence — see [_scheduleSend] — because a
  /// hold that does nothing is indistinguishable from a bug, and this one is a
  /// deliberate rule the user deserves to hear.
  ///
  /// An edit is different: it is a transient mode the user armed a moment ago
  /// and can cancel, so the absent gesture reads as "not now" rather than as a
  /// broken button.
  VoidCallback? get _composerSchedule => _editing != null ? null : _scheduleSend;

  void _openScheduledList() {
    showScheduledListSheet(
      context,
      repo: widget.repo,
      roomId: widget.roomId,
    );
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
      what: AppLocalizations.of(context).roomScreenGateSendMessages,
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
        SnackBar(content: Text(AppLocalizations.of(context).roomScreenAskGrownUpFailedSnack)),
      );
    }
  }

  /// Arm a reply against [m]: a strong haptic + state change so the
  /// composer card slides into view. Idempotent — re-arming against the
  /// same message just replaces the target. The composer is focused on
  /// the next frame so the keyboard appears without a second tap.
  void _armReply(ChatMessage m, {bool haptic = true}) {
    // The swipe path opts out: it already fired a medium impact when the pull
    // crossed the threshold, and now that the reply arms on release the two
    // would land on the same beat and read as one muddy buzz.
    if (haptic) HapticFeedback.heavyImpact();
    // Mutual exclusion, the [_beginSelection] precedent: an edit in progress
    // hands the composer back (draft included) before the reply takes it.
    if (_editing != null) _cancelEdit();
    setState(() => _replyingTo = m);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _composerFocus.requestFocus();
    });
  }

  /// Arm an edit of [m]: the composer takes the message's current text and a
  /// banner says whose words these are. Whatever WAS being typed is stashed
  /// first and comes back when the edit is sent or cancelled — an edit must
  /// not eat a half-written message.
  void _armEdit(ChatMessage m) {
    HapticFeedback.heavyImpact();
    _draftBeforeEdit = (
      text: _composer.text,
      mentions: _composer.mentions,
      everyone: _composer.everyone,
      formatting: _composer.formatting,
    );
    setState(() {
      _replyingTo = null;
      _editing = m;
      // Formatting cleared BEFORE the text swap: the swap runs the remap, and
      // the draft's ranges have no business being remapped onto the message's
      // text. Restored (against the new text) after.
      _composer.clearFormatting();
      _composer.text = m.content;
      // The message's own mentions come along, or the restored "@bob" would
      // read as a tag and send as prose — the same rule the gate-refusal
      // restore path follows. Its formatting comes along for the same reason:
      // an edit that silently dropped the bold would save the words plain.
      _composer.restoreMentions(m.mentions, everyone: m.mentionsEveryone);
      _composer.restoreFormatting(m.formatting);
    });
    // Caret at the end: editing almost always means appending or fixing the
    // tail, and a caret at position 0 makes every edit start with a scroll.
    _composer.selection =
        TextSelection.collapsed(offset: _composer.text.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _composerFocus.requestFocus();
    });
  }

  /// Leave edit mode and put the stashed draft back in the composer.
  void _cancelEdit() {
    final draft = _draftBeforeEdit;
    _draftBeforeEdit = null;
    setState(() {
      _editing = null;
      _composer.clearFormatting();
      _composer.text = draft?.text ?? '';
      _composer.restoreMentions(
        draft?.mentions ?? const [],
        everyone: draft?.everyone ?? false,
      );
      _composer.restoreFormatting(draft?.formatting ?? const []);
    });
  }

  /// The edit-mode half of [_send], split out so the ordinary path reads as
  /// it always has. Follows the same snapshot → clear → restore-on-refusal
  /// contract.
  Future<void> _sendEdit(ChatMessage editing, String text) async {
    final mentions = _composer.mentions;
    final everyone = _composer.everyone;
    final formatting = _composer.formatting;
    // An edit that changed nothing is a cancel: leave quietly rather than
    // asking the server to stamp "edited" over a no-op. Formatting counts as
    // a change — re-bolding a word IS an edit even when the words stand.
    if (text == editing.content &&
        listEquals(formatting, editing.formatting)) {
      _cancelEdit();
      return;
    }
    final draft = _draftBeforeEdit;
    _draftBeforeEdit = null;
    setState(() {
      _editing = null;
      _composer.clearFormatting();
      _composer.text = draft?.text ?? '';
      _composer.restoreMentions(
        draft?.mentions ?? const [],
        everyone: draft?.everyone ?? false,
      );
      _composer.restoreFormatting(draft?.formatting ?? const []);
    });
    final err = await widget.repo.editMessage(
      roomId: widget.roomId,
      message: editing,
      content: text,
      mentions: mentions,
      mentionsEveryone: everyone,
      formatting: formatting,
    );
    if (err == null || !mounted) {
      _keepComposerFocus();
      return;
    }
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err == 'EDIT_WINDOW_EXPIRED'
          ? l10n.roomScreenEditExpiredSnack
          : l10n.roomScreenEditFailedSnack),
    ));
    // A transient failure gets the whole session back for a retry. An expired
    // window does NOT: re-arming an edit the server can only refuse again
    // would turn the snack into a loop.
    if (err != 'EDIT_WINDOW_EXPIRED') {
      setState(() {
        _draftBeforeEdit = draft;
        _editing = editing;
        _composer.clearFormatting();
        _composer.text = text;
        _composer.restoreMentions(mentions, everyone: everyone);
        _composer.restoreFormatting(formatting);
      });
    }
    _keepComposerFocus();
  }

  // ───────────────────────── multi-select ─────────────────────────

  /// The messages the selection bar would act on, resolved against the
  /// transcript as it is right now.
  ///
  /// Never the raw id count: a selected message can self-destruct, expire or be
  /// deleted by its sender while the bar is up, and offering to forward four
  /// things that are now three is how a bulk action lies about what it did.
  List<ChatMessage> get _selectedMessages =>
      _selection.resolve(widget.repo.timelineFor(widget.roomId));

  /// Enters selection mode with [m] already picked.
  void _beginSelection(ChatMessage m) {
    // The composer is about to be replaced by the selection bar, and a keyboard
    // left standing over it would cover the actions it was opened for.
    FocusManager.instance.primaryFocus?.unfocus();
    // Same mutual exclusion as replies: the bar replaces the composer, so an
    // edit in progress hands the draft back first.
    if (_editing != null) _cancelEdit();
    setState(() => _replyingTo = null);
    _selection.begin(m.id);
  }

  /// Takes or drops a whole album.
  ///
  /// Any member selected means the block reads as selected, so the tap that
  /// follows drops all of them; otherwise it takes all of them. The cap is
  /// checked against what the tap would actually add rather than one at a
  /// time, because half an album is exactly the outcome it exists to prevent.
  void _toggleAlbumSelection(List<ChatMessage> album) {
    final anySelected = album.any((p) => _selection.contains(p.id));
    if (anySelected) {
      for (final p in album) {
        if (_selection.contains(p.id)) _selection.toggle(p.id);
      }
      return;
    }
    if (_selection.count + album.length > _kMaxSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)
              .roomScreenMaxSelectionSnack(_kMaxSelected)),
        ),
      );
      return;
    }
    for (final p in album) {
      _selection.toggle(p.id);
    }
  }

  void _toggleSelection(ChatMessage m) {
    if (!_selection.contains(m.id) && _selection.count >= _kMaxSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).roomScreenMaxSelectionSnack(_kMaxSelected),
          ),
        ),
      );
      return;
    }
    _selection.toggle(m.id);
  }

  /// Whether every message in [picked] can leave this room.
  ///
  /// Mirrors what `messages:forwardToRoom` enforces, so the button never
  /// promises something the server refuses: a Chamber of Secrets room is
  /// refused wholesale (its expiry would be laundered away by the target
  /// room's), a view-once message has no readable body to carry, and a system
  /// notice was never anybody's message to send.
  bool _canForward(ChatRoom room, List<ChatMessage> picked) {
    if (picked.isEmpty || picked.length > _kMaxForwarded) return false;
    if (room.isEphemeral) return false;
    return picked.every((m) =>
        !m.viewOnce &&
        m.type != MessageType.system &&
        m.status == MessageStatus.sent &&
        !m.id.startsWith('tmp_'));
  }

  /// Whether every message in [picked] is one the server would let us delete.
  ///
  /// Same rule as `messages:deleteMany`: your own messages, and only those.
  /// Deleting here is delete-for-everyone — it takes the message off the other
  /// person's screen too — so it is scoped to what you actually said. Owning
  /// the room does not extend it. The server enforces this as well; this is the
  /// UX half, which is why one message of someone else's in the selection dims
  /// the whole button rather than silently deleting the rest.
  bool _canDelete(List<ChatMessage> picked, String me) {
    if (picked.isEmpty || me.isEmpty) return false;
    if (picked.any((m) => m.id.startsWith('tmp_'))) return false;
    return picked.every((m) => m.senderId == me);
  }

  /// Forwards [picked] into whichever chats the sheet comes back with.
  ///
  /// Shared by the selection bar and the long-press menu's FORWARD row — one
  /// message is just the one-item case, and the two must not drift.
  Future<void> _forwardMessages(List<ChatMessage> picked) async {
    if (picked.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    final targets = await showForwardTargetSheet(
      context,
      repo: widget.repo,
      messageCount: picked.length,
      excludeRoomId: widget.roomId,
    );
    if (targets == null || targets.isEmpty || !mounted) return;

    final result = await forwardMessages(
      api: widget.api,
      repo: widget.repo,
      sourceRoomId: widget.roomId,
      targets: [for (final t in targets) t.id],
      messages: picked,
    );
    if (!mounted) return;

    _selection.clear();
    messenger.showSnackBar(SnackBar(content: Text(result.summary)));
  }

  Future<void> _deleteSelected() async {
    final picked = _selectedMessages;
    if (picked.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmSheet(
      context,
      headline: l10n.roomScreenDeleteMessageHeadline(picked.length),
      body: l10n.roomScreenDeleteConfirmBody,
      confirmLabel: l10n.roomScreenDeleteConfirmButton,
    );
    if (!confirmed || !mounted) return;

    final result = await deleteMessages(
      api: widget.api,
      repo: widget.repo,
      messageIds: [for (final m in picked) m.id],
    );
    if (!mounted) return;

    // No local removal: the room subscription carries the deletion back, the
    // same way it does for the single-message DELETE in the action menu.
    _selection.clear();
    messenger.showSnackBar(SnackBar(content: Text(result.summary)));
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
        // A snapshot rather than a live feed: the overlay is short-lived, and
        // this screen already pays for the only `rooms:getMembers`
        // subscription either surface needs.
        members: _members.values.toList(),
        onChildGate: (gate, unsentText) {
          if (!mounted) return;
          _composer.text = unsentText;
          unawaited(_handleSendGate(gate));
        },
      );

  /// The message row nearest the top of the viewport — where the reader is.
  ///
  /// Walks the same `_dateTracks` render boxes [_recomputePositionState] does,
  /// rather than keeping a second piece of scroll state in sync with the first.
  /// Only used to anchor the back trail, so a null (nothing laid out yet, or
  /// mid-relayout) simply means this hop gets no pill.
  ChatMessage? _topmostVisibleMessage(List<ChatMessage> messages) {
    final viewportCtx = _listViewportKey.currentContext;
    if (viewportCtx == null) return null;
    final viewportBox = viewportCtx.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.attached) return null;

    String? bestId;
    var bestDy = double.infinity;
    for (final entry in _dateTracks.entries) {
      if (!entry.key.startsWith('m_')) continue;
      final ctx = entry.value.key.currentContext;
      if (ctx == null || !ctx.mounted) continue;
      final rb = ctx.findRenderObject() as RenderBox?;
      if (rb == null || !rb.attached) continue;
      final dy = rb.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
      if (dy < 0) continue; // scrolled off the top
      if (dy < bestDy) {
        bestDy = dy;
        bestId = entry.key.substring(2);
      }
    }
    if (bestId == null) return null;
    for (final m in messages) {
      if (m.id == bestId) return m;
    }
    return null;
  }

  /// Jump to the pin the banner is currently describing, then advance to the
  /// next one so repeated taps walk the room's pins.
  ///
  /// Calls [_travelTo] and pushes the trail by hand rather than going through
  /// [_jumpToMessage], because that helper uses one `from` for two jobs: the
  /// back-trail entry AND the thread fallback (`from.threadKey`). For a reply
  /// tether those are the same message; for a pin they are not. Handing it the
  /// pin would push the pin itself onto the trail, so the back pill would
  /// return the reader to where they already are.
  Future<void> _jumpToPin(RoomPin target) async {
    final messages = widget.repo.timelineFor(widget.roomId);
    // Captured before the await: after it, the transcript has scrolled and this
    // no longer names where the reader came from.
    final origin = _topmostVisibleMessage(messages);
    // `from` is the PIN, so a pin folded into a thread chip hands off to its
    // own thread — the same resolution a reply tether gets.
    final landed = await _travelTo(target.message.id, from: target.message);
    if (!mounted) return;
    // Not when the trip ended in the thread overlay: that has its own close
    // button, and a pill pointing back into a transcript nobody is looking at
    // is the case `_travelTo`'s return value exists to distinguish.
    if (landed && origin != null && origin.id != target.message.id) {
      _jumpBack.push(origin);
    }
  }

  Future<void> _onPinBannerTap() async {
    final pins = widget.repo.pinsFor(widget.roomId);
    if (pins.isEmpty) return;
    final i = _pinCursor % pins.length;
    await _jumpToPin(pins[i]);
    if (!mounted) return;
    setState(() => _pinCursor = nextPinCursor(i, pins.length));
  }

  Future<void> _openPinList(ChatRoom room) async {
    await showPinnedListSheet(
      context,
      repo: widget.repo,
      api: widget.api,
      roomId: room.id,
      onJump: (pin) {
        final pins = widget.repo.pinsFor(room.id);
        final i = pins.indexWhere((p) => p.message.id == pin.message.id);
        // Leave the cursor on what was just opened, so the next banner tap
        // continues from there rather than resuming an unrelated walk.
        if (i >= 0) setState(() => _pinCursor = i);
        _jumpToPin(pin);
      },
    );
  }

  /// Follow a reply tether up to the message it quotes, and remember where we
  /// came from so the reader can get back.
  ///
  /// The trail push happens here rather than in [_travelTo] because [_travelTo]
  /// is also how the back pill returns, and a return trip that pushed its own
  /// origin would leave the two ends bouncing off each other forever.
  Future<void> _jumpToMessage(String messageId, {required ChatMessage from}) async {
    // A trip to where the reader already is still pulses — being SHOWN the
    // message is the whole point of the gallery's SHOW IN CHAT even when it has
    // not moved — but it must not push a back pill, which would offer to return
    // them to the message they are looking at.
    if (messageId == from.id) {
      await _travelTo(messageId, from: from);
      return;
    }
    if (await _travelTo(messageId, from: from)) _jumpBack.push(from);
  }

  /// Walk one hop back down the trail, to the reply we last jumped away from.
  ///
  /// Pops before travelling, so an entry that has since become unreachable
  /// takes itself off the trail instead of parking a dead pill on screen — the
  /// next tap then tries the hop below it.
  Future<void> _jumpBackOneHop() async {
    final origin = _jumpBack.pop();
    if (origin == null) return;
    HapticFeedback.selectionClick();
    // Its own context: a message's threadKey is the thread it lives in, which
    // is exactly the fallback surface to open if it has been folded away.
    await _travelTo(origin.id, from: origin);
  }

  /// Land on the message identified by [messageId] and pulse it — the tap
  /// target behind every reply tether. [from] is the message the trip is
  /// anchored to; its thread is the fallback surface, and since `messages:send`
  /// propagates `rootId`, a parent is always in the same thread as its child.
  ///
  /// Resolution order, first hit wins:
  ///   1. folded into a thread chip → open that thread on it
  ///   2. somewhere in the transcript → snap there, however far away it is
  ///   3. not loaded → fetch a window of history around it and snap
  ///   4. unreachable (deleted, or offline) → say so
  ///
  /// True only for 2 and 3 — a landing in this transcript, which is the only
  /// outcome worth a back-pill. The thread hand-off has the overlay's own close
  /// button as its way back, and a failure went nowhere to come back from.
  Future<bool> _travelTo(String messageId, {required ChatMessage from}) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    // The pin exists to protect a jump in flight; handing the message over to
    // the thread overlay ends the flight, so drop it or the row stays
    // un-foldable for the rest of the session.
    Future<bool> handOffToThread() async {
      if (!mounted) return false;
      setState(() => _jumpTargetId = null);
      await _openThreadAt(rootId: from.threadKey, anchorMessageId: messageId);
      return false;
    }

    if (_hiddenMessageIds.contains(messageId)) return handOffToThread();
    if (await _snapToRow(messageId)) return true;
    if (!mounted) return false;

    // Not in the transcript. Pin it before the fetch so the pass that brings
    // it in can't immediately fold it away again.
    setState(() => _jumpTargetId = messageId);
    final reached = await widget.repo.jumpToMessage(widget.roomId, messageId);
    if (!mounted) return false;
    if (reached) {
      // One frame for the freshly-loaded window to lay out.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
      if (!_hiddenMessageIds.contains(messageId) &&
          await _snapToRow(messageId)) {
        return true;
      }
      // Folded, or in the room but with no row of its own — either way the
      // thread is where it can be seen.
      return handOffToThread();
    }
    setState(() => _jumpTargetId = null);
    messenger?.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).roomScreenJumpFailedSnack)),
    );
    return false;
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
      targetContext: () => _rowContextOf(messageId),
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
  /// what a send calls, and only a deliberate tap earns a haptic — and only a
  /// deliberate return to the present abandons the trail of replies behind it.
  /// A send must not, or replying mid-chain would silently lose the reader's
  /// way back.
  void _onJumpToLatestTapped() {
    HapticFeedback.selectionClick();
    _jumpBack.clear();
    _scrollToBottom();
  }

  /// What every media entry point owes the user before it opens anything: not
  /// firing twice, and not walking a supervised account into a camera it is not
  /// allowed to use. Returns false when the caller should stop.
  ///
  /// Shared rather than repeated, because there are now two doors into the same
  /// room — the attachment sheet and the composer's camera button — and a
  /// parental gate that only guards one of them guards neither.
  ///
  /// Not `onAttach: _attachInFlight ? null : _onAttach` on the composers, which
  /// is the obvious-looking way to do the in-flight half: both of them drop the
  /// button entirely when the callback is null, so the composer would visibly
  /// reflow the moment the sheet opened and reflow back when it closed. The
  /// guard belongs here, where it costs no layout.
  /// [locationCounts] widens the parental check from "may send media" to "may
  /// send media OR may share a location", for the one door that offers both.
  ///
  /// It exists because the two guardian switches are independent: a child whose
  /// guardian turned media off and location on has nothing wrong with them, and
  /// a gate that only knew about media would refuse them the sheet containing
  /// the one thing they are allowed. The camera button keeps the strict media
  /// check, because a camera is media whatever the location policy says.
  Future<bool> _claimMediaEntry({bool locationCounts = false}) async {
    // Checked before the haptic, so a second tap during the flow is silent
    // rather than buzzing back at a user whose first tap is still being
    // honoured.
    if (_attachInFlight) return false;
    HapticFeedback.lightImpact();
    final family = FamilyService.maybeInstance;
    final refused = family != null &&
        !family.canSendMedia &&
        !(locationCounts && family.canShareLocation);
    if (refused) {
      await showApprovalGate(
        context,
        what: AppLocalizations.of(context).roomScreenGateSendMedia,
        canAsk: false,
      );
      return false;
    }
    _attachInFlight = true;
    return true;
  }

  /// The handle the attachment sheet uses to reach the composer's recording
  /// modes. See [ComposerCaptureController].
  final _captureController = ComposerCaptureController();

  /// What the composer's capture control is allowed to do in this room.
  ///
  /// Rebuilt on every `build` rather than cached, because it closes over
  /// `context` and over the room's live media permission — a `ComposerCapture`
  /// held across a permission change would keep offering a camera a supervised
  /// account has just lost.
  ComposerCapture get _composerCapture => ComposerCapture(
        modes: ComposerInputMode.values,
        controller: _captureController,
        onCamera: _onCamera,
        onCaptured: _onCaptured,
        onProblem: _onCaptureProblem,
      );

  /// A finished recording, straight into the same optimistic send path a photo
  /// takes. No separate upload flow: `sendMediaLocal` already owns the bubble,
  /// the retained-bytes budget, the retry and the reconnect sweepers, and a
  /// second path would have to grow all four again.
  void _onCaptured(ComposerInputMode mode, CaptureOutcome outcome) {
    if (!mounted) return;
    // Checked here rather than at the start of the recording so a supervised
    // account that loses the permission mid-hold cannot post what it recorded.
    // The bytes are simply dropped — the temp file is already gone.
    if (FamilyService.maybeInstance?.canSendMedia == false) {
      unawaited(showApprovalGate(
        context,
        what: AppLocalizations.of(context).roomScreenGateSendMedia,
        canAsk: false,
      ));
      return;
    }
    _sendMedia(
      bytes: outcome.bytes,
      type: mode == ComposerInputMode.videoNote
          ? MessageType.videoNote
          : MessageType.audio,
      contentType: outcome.contentType,
      posterBytes: outcome.posterBytes,
      mediaDurationMs: outcome.duration.inMilliseconds,
    );
  }

  void _onCaptureProblem(CaptureFailure failure) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    unawaited(showCaptureProblem(
      context,
      failure,
      onMessage: (message) =>
          messenger.showSnackBar(SnackBar(content: Text(message))),
    ));
  }

  /// The composer's camera button — the same flow the attachment sheet's Camera
  /// entry reaches, one tap sooner.
  ///
  /// Opens on the front lens. The button sits in the composer, mid-conversation:
  /// what it is for is answering someone with your face, and the rear lens made
  /// every such reply start with a flip. Photographing something in front of you
  /// is the deliberate case, and it still has the flip button and the
  /// attachment sheet's Camera entry.
  Future<void> _onCamera() async {
    if (!await _claimMediaEntry()) return;
    try {
      if (!mounted) return;
      await _captureAndSend(initialLens: CameraLensDirection.front);
    } finally {
      _attachInFlight = false;
    }
  }

  Future<void> _onAttach() async {
    if (!await _claimMediaEntry(locationCounts: true)) return;
    try {
      if (!mounted) return; // the `finally` still clears the in-flight flag
      final family = FamilyService.maybeInstance;
      final choice = await showAttachmentMenu(
        context,
        allowMedia: family?.canSendMedia ?? true,
        allowLocation: family?.canShareLocation ?? true,
      );
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
          await _captureAndSend();
          break;
        case AttachmentMenuChoice.file:
          await _pickAndSendFile();
          break;
        case AttachmentMenuChoice.videoNote:
          // Routed into the composer's own control rather than opening
          // anything: a video note is recorded inline, and this sheet entry
          // exists to give that gesture a named, tappable, screen-reader
          // reachable door — not to become a second implementation of it.
          _captureController.requestMode(ComposerInputMode.videoNote);
          break;
        case AttachmentMenuChoice.voice:
          final bytes = await nav.push<Uint8List>(
            MaterialPageRoute(builder: (_) => const VoiceRecorderScreen()),
          );
          if (bytes != null) {
            _sendMedia(
              bytes: bytes,
              type: MessageType.audio,
              contentType: voiceNoteContentType,
            );
          }
          break;
        case AttachmentMenuChoice.location:
          await _shareLocation();
          break;
        case AttachmentMenuChoice.poll:
          await _composeInteraction(MessageType.poll);
          break;
        case AttachmentMenuChoice.checklist:
          await _composeInteraction(MessageType.checklist);
          break;
        case AttachmentMenuChoice.event:
          await _composeInteraction(MessageType.event);
          break;
      }
    } finally {
      _attachInFlight = false;
    }
  }

  // ─────────────────── polls, checklists and events ───────────────────

  /// Opens the compose sheet for [kind] and posts whatever comes back.
  ///
  /// The sheet gathers a definition and nothing else — see [InteractionDraft]
  /// for why it does not send: which room, which reply and what a failure looks
  /// like are this screen's business, exactly as they are for every other
  /// attachment.
  Future<void> _composeInteraction(MessageType kind) async {
    final draft = await showInteractionComposeSheet(context, kind: kind);
    if (draft == null || !mounted) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final roomId = widget.roomId;

    // Snapshotted and disarmed up front, exactly as `_shareLocation` and
    // `_sendMedia` do it: the sheet has been open for a while, and re-arming a
    // reply target under someone who has moved on is worse than losing it.
    final replyTarget = _replyingTo;
    if (replyTarget != null) setState(() => _replyingTo = null);
    widget.repo.exitHistoryWindow(roomId);

    final id = await widget.repo.sendInteraction(
      roomId: roomId,
      kind: draft.kind,
      prompt: draft.prompt,
      labels: draft.labels,
      multiple: draft.multiple,
      anonymous: draft.anonymous,
      quiz: draft.quiz,
      correctIndex: draft.correctIndex,
      explanation: draft.explanation,
      othersMayCheck: draft.othersMayCheck,
      othersMayAdd: draft.othersMayAdd,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
      place: draft.place,
      replyToId: replyTarget?.id,
    );
    if (!mounted) return;
    if (id == null) {
      // There is no optimistic bubble to leave sitting in a failed state — see
      // `ChatRepository.sendInteraction` — so a refusal has to be SAID. This is
      // the one send in the room where silence would look like nothing
      // happened at all.
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.interactionSendFailed)),
      );
      return;
    }
    _scrollToBottom();
  }

  /// The transcript's wiring for every interactive card in it.
  ///
  /// Built once per build rather than once per row: the callbacks take the
  /// message id, so one object serves the whole list — see
  /// [InteractionActions]. A per-bubble closure set would allocate six of them
  /// for every row in a scrolling transcript, nearly all of which are not
  /// interactive at all.
  InteractionActions get _interactionActions => InteractionActions(
        onRespond: (messageId, choiceId) async {
          final ok = await widget.repo.respondToInteraction(
            roomId: widget.roomId,
            messageId: messageId,
            choiceId: choiceId,
          );
          if (!ok && mounted) _interactionRefused();
        },
        onRetract: (messageId) async {
          final ok = await widget.repo.retractInteraction(
            roomId: widget.roomId,
            messageId: messageId,
          );
          if (!ok && mounted) _interactionRefused();
        },
        onClose: (messageId) async {
          final ok = await widget.repo.closeInteraction(messageId: messageId);
          if (!ok && mounted) _interactionRefused();
        },
        onAddItem: (messageId, label) async {
          final ok = await widget.repo
              .addChecklistItem(messageId: messageId, label: label);
          if (!ok && mounted) _interactionRefused();
        },
        onRemoveItem: (messageId, choiceId) async {
          final ok = await widget.repo.removeChecklistItem(
            messageId: messageId,
            choiceId: choiceId,
          );
          if (!ok && mounted) _interactionRefused();
        },
        onShowRespondents: (messageId) => _showRespondents(messageId),
      );

  /// One message for every way the server can say no to an answer.
  ///
  /// A closed poll, a quiz already answered, somebody else's tick, a room this
  /// reader has been removed from, or simply no connection. They are
  /// distinguishable server-side but not usefully to a reader mid-tap: in every
  /// case the control went back to where it was, and the sentence that helps is
  /// the one saying that was the server's doing rather than a missed tap.
  void _interactionRefused() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).interactionRefused)),
    );
  }

  Future<void> _showRespondents(String messageId) async {
    final interaction =
        widget.repo.interactionFor(widget.roomId, messageId);
    final me = widget.repo.userId;
    // Both are ordinary races rather than errors: the card can be tapped in the
    // frame before its body lands, and a signed-out reader has no viewer id to
    // ask with.
    if (interaction == null || me == null) return;
    await showInteractionRespondentsSheet(
      context,
      api: widget.api,
      messageId: messageId,
      currentUserId: me,
      interaction: interaction,
      resolveUser: (id) => _members[id] ?? widget.repo.userById(id),
      onOpenProfile: _openProfile,
    );
  }

  // ───────────────────────── location ─────────────────────────

  /// Picks a mode, clears the permission hurdles, gets a fix, and sends.
  ///
  /// The order matters and is the opposite of the obvious one: the sheet opens
  /// BEFORE any permission is requested. Asking for location the moment the
  /// attachment menu is tapped would put a system dialog in front of somebody
  /// who has not yet said they want to share anything — and on iOS that dialog
  /// can only be shown once, so spending it on a tap the user might abandon is
  /// spending it badly.
  Future<void> _shareLocation() async {
    // Live sharing is hidden in a Chamber of Secrets room — see the sheet's
    // header. The room's own message lifetime already governs how long anything
    // written there survives, and a share whose duration the room would silently
    // override is worse than one that was never offered.
    final choice = await showLocationShareSheet(
      context,
      allowLive: (_room ?? widget.repo.roomById(widget.roomId))
              ?.messageLifetime ==
          null,
    );
    if (choice == null || !mounted) return;

    if (!await _ensureLocationPermission()) return;
    if (!mounted) return;

    // The Always escalation, and the only place it happens. Before the fix
    // rather than after, because taking a fix can spend fifteen seconds and a
    // sheet that appears after that wait reads as an interruption rather than as
    // part of the same decision. Live shares only: a single pin sent once has
    // nothing to gain from background permission and asking for it there would
    // be the upfront prompt this whole flow exists to avoid.
    var keepRunningInBackground = false;
    if (choice.isLive) {
      keepRunningInBackground = await _offerBackgroundUpgradeIfDue();
      if (!mounted) return;
    }

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final roomId = widget.roomId;

    // Snapshotted and disarmed up front, exactly as `_sendMedia` does it and for
    // the same reason: the fix below can take fifteen seconds, and re-arming a
    // reply target under a user who has started typing something else is worse
    // than losing it.
    final replyTarget = _replyingTo;
    if (replyTarget != null) setState(() => _replyingTo = null);
    widget.repo.exitHistoryWindow(roomId);

    // The fix is taken before the message exists, for both modes. A live share
    // needs a first position to be a share at all — an empty card that fills in
    // when the publisher's first update lands would be a bubble that arrives
    // saying nothing.
    final fix = await LocationService.instance.currentFix();
    if (fix == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.locationCouldNotGetFix)),
      );
      return;
    }

    final duration = choice.duration;
    if (duration == null) {
      await widget.repo.sendLocation(
        roomId: roomId,
        fix: fix,
        replyToId: replyTarget?.id,
      );
      _scrollToBottom();
      return;
    }

    // A live share deliberately carries no reply tether. It is a standing
    // object in the transcript for hours, not a remark about the message above
    // it, and a tether would have it quoting something long since scrolled past.
    final started = await widget.repo.startLiveLocation(
      roomId: roomId,
      fix: fix,
      duration: duration,
      // Resolved here, where a locale exists, and persisted with the share.
      // The Android foreground service and its boot receiver both read it back
      // off disk with no `BuildContext` anywhere in reach — see [LiveShareNotice].
      notice: LiveShareNotice(
        title: l10n.locationServiceNotificationTitle,
        body: l10n.locationServiceNotificationBody,
        stopLabel: l10n.locationBubbleStopSharing,
      ),
      monitorSignificantChanges: keepRunningInBackground,
    );
    if (!started && mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.locationCouldNotStartLiveShare)),
      );
      return;
    }
    _scrollToBottom();
  }

  /// Offers the background upgrade, exactly once per install, and reports what
  /// the share can now promise.
  ///
  /// Returns whether the platform should be asked to keep this share alive
  /// across termination — iOS significant-change monitoring, Android's boot
  /// receiver. A false answer is the ordinary outcome and not a failure: the
  /// share still publishes for the whole time the app is backgrounded, which is
  /// what almost everybody means by "keeps working". See [decideLiveShareStart]
  /// for the table this consults and why the flag is set on ASKING rather than
  /// on being granted.
  ///
  /// Availability is passed as ready because the caller has just established it
  /// through [_ensureLocationPermission]; re-deriving it here would be a second
  /// permission round trip for an answer we hold.
  Future<bool> _offerBackgroundUpgradeIfDue() async {
    final platform = LiveLocationPlatform.instance;
    final store = LiveShareResumeStore.instance;
    final tier = await platform.authorizationTier();
    final action = decideLiveShareStart(
      availability: LocationAvailability.ready,
      tier: tier,
      alreadyOfferedAlways: await store.hasOfferedAlwaysUpgrade(),
      platformSupportsAlways: platform.supportsAlways,
    );
    if (action != LiveShareStartAction.offerAlwaysUpgrade || !mounted) {
      return tierSurvivesTermination(tier);
    }

    final wants = await showLiveShareBackgroundSheet(context);
    // Marked whichever way they answered, and marked even if the request below
    // fails. The point of the flag is "this person has been asked", not "this
    // person has granted" — see the sheet's own doc comment.
    await store.markAlwaysUpgradeOffered();
    if (!wants) return false;

    return tierSurvivesTermination(await platform.requestAlwaysAuthorization());
  }

  /// Walks the three ways location can be unavailable, each to its own exit.
  ///
  /// None of them is allowed to be a dead end, which is the whole reason this
  /// is three branches rather than a boolean:
  ///
  ///  * a soft denial is re-asked, once, by [LocationService.ensureAvailable];
  ///  * a permanent denial cannot be re-asked at all — the OS answers without
  ///    showing anything — so the only honest offer is the Settings page;
  ///  * location switched off device-wide is not a permission problem, and
  ///    sending the user to the app's permission screen would be sending them
  ///    somewhere with no switch that helps.
  Future<bool> _ensureLocationPermission() async {
    final state = await LocationService.instance.ensureAvailable();
    if (!mounted) return false;
    final l10n = AppLocalizations.of(context);
    switch (state) {
      case LocationAvailability.ready:
        return true;
      case LocationAvailability.denied:
        // Asked and refused, just now. No sheet: they answered the question a
        // second ago and repeating it in our own words is nagging.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.locationPermissionNeeded)),
        );
        return false;
      case LocationAvailability.deniedForever:
        final go = await showConfirmSheet(
          context,
          headline: l10n.locationPermissionBlockedTitle,
          body: l10n.locationPermissionBlockedBody,
          confirmLabel: l10n.locationOpenSettings,
        );
        if (go) await LocationService.instance.openAppSettings();
        return false;
      case LocationAvailability.servicesDisabled:
        final go = await showConfirmSheet(
          context,
          headline: l10n.locationServicesOffTitle,
          body: l10n.locationServicesOffBody,
          confirmLabel: l10n.locationOpenSettings,
        );
        if (go) await LocationService.instance.openLocationSettings();
        return false;
    }
  }

  /// Camera → editor → send, with the editor opening *over* the camera.
  ///
  /// There is no reopen-the-camera loop here any more, because there is nothing
  /// to reopen: the camera route stays on the stack under the editor, so RETAKE
  /// is the editor popping. That is also what fixes the shutter looking like a
  /// bug — the camera used to pop and the editor push after it, and the chat
  /// showed through the seam between the two animations.
  ///
  /// [initialLens] is which lens to open on, and RETAKE stays on it — a retake
  /// is a second attempt at the shot the entry point was for, not a different
  /// one.
  ///
  /// The camera can also record: see [CameraScreen.allowVideo]. A clip comes
  /// back as [CameraRecorded] and skips the editor entirely — there is no video
  /// editor to send it through, and the review the photograph gets exists to
  /// crop and draw on it rather than to confirm it.
  Future<void> _captureAndSend({
    CameraLensDirection initialLens = CameraLensDirection.back,
  }) async {
    final result = await CameraScreen.open<EditorSend>(
      context,
      initialLens: initialLens,
      // Chat is the one caller that can accept a clip, so it is the one caller
      // that gets the PHOTO/VIDEO switch. The camera button used to be able to
      // take a photograph and nothing else, which meant the only way to send a
      // video was to have already recorded one somewhere else.
      allowVideo: true,
      review: (context, photo) async {
        final outcome = await CameraEditorScreen.open(
          context,
          source: photo.bytes,
          canRetake: true,
          mirrored: photo.mirrored,
          overCamera: true,
        );
        return switch (outcome) {
          EditorRetake() => const ReviewRetake<EditorSend>(),
          final EditorSend send => ReviewDone(send),
          null => const ReviewDone<EditorSend>(null),
        };
      },
    );
    if (!mounted) return;

    switch (result) {
      case CameraReviewed(:final value):
        // Sent from here rather than inside the review so the upload starts
        // against a chat that is already back on screen.
        if (value != null) _sendEdited(value);

      case CameraRecorded(:final video):
        // Recorded in the camera's VIDEO mode. Sent from here rather than from
        // inside the camera for exactly the reason the photograph is: the
        // upload should start against a chat that is already back on screen.
        _sendMedia(
          bytes: video.bytes,
          type: MessageType.video,
          contentType: 'video/mp4',
          posterBytes: video.posterBytes,
          mediaDurationMs: video.durationMs,
        );

      case CameraPickLibrary():
        // The camera's own shortcut into the photo library.
        await _pickAndSendFromGallery();

      case CameraUnavailable():
        // The in-app camera could not start for a reason that isn't the user
        // saying no. Fall back to the system camera rather than leaving them
        // with no way to take a picture at all. No mirroring on this path:
        // `image_picker` never reports which lens fired, and reflecting a
        // photo of a document would be worse than leaving a selfie unflipped.
        // No retake either: the system camera has its own, and there is no
        // route of ours underneath to go back to.
        // A refusal folds into the cancel here rather than earning a snackbar
        // of its own: the library reasons for one (an asset kept in iCloud) do
        // not exist for a frame that was taken a second ago, and the camera's
        // own permission prompt has already spoken for the rest.
        final picked = (await pickPhoto(source: ImageSource.camera)).file;
        if (picked == null || !mounted) return;
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        final outcome = await CameraEditorScreen.open(context, source: bytes);
        if (outcome is EditorSend) _sendEdited(outcome);

      case null:
        return; // backed out of the camera
    }
  }

  // ─────────────────────────── incoming shares ─────────────────────────────

  /// Puts a share from the system sheet into this room.
  ///
  /// Everything here is the room's own send path, reached from a different
  /// door. That is the point: a share is subject to the same size cap, the same
  /// editor and the same optimistic bubble as a photo picked from the composer,
  /// and a second pipeline would be a second set of bugs.
  ///
  /// Three shapes, in the order they are common:
  ///
  ///  * **One photo** — the editor, exactly as the gallery pick gets. It is the
  ///    only chance to crop, annotate or arm view-once, and a share arrives
  ///    sight-unseen from an app the user has already left.
  ///  * **Anything else with bytes** — straight into the transcript. There is no
  ///    carousel to preview five photos in, and a document has nothing to edit.
  ///  * **Text or a link** — the composer, not a message. A shared URL is a
  ///    draft; sending it is still the user's tap.
  Future<void> _deliverShare(SharedPayload payload) async {
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);

    // Text first and unconditionally: with attachments it reads as their
    // caption, and the user can send or discard it after the pictures land.
    final text = payload.text;
    if (text != null && text.isNotEmpty) {
      // Appended rather than assigned — a draft already in the composer is
      // something the user typed, and a share must not eat it.
      final existing = _composer.text.trimRight();
      _composer.text = existing.isEmpty ? text : '$existing\n$text';
      _keepComposerFocus();
    }

    // Refused here rather than silently: the platform declined to copy these
    // because they are over the cap, so there are no bytes to fall back on and
    // saying nothing would look like the share simply failed.
    if (payload.oversized.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            loc.roomScreenFileSizeCapSnack(formatFileSize(kMaxFileUploadBytes)),
          ),
        ),
      );
    }

    final items = payload.sendable;
    if (items.isEmpty) {
      // Text-only share. Nothing staged on disk to release.
      _touchShareTarget();
      return;
    }

    // Same uncovered gap the picker paths document: reading a shared file back
    // is a whole-file read, tens of megabytes for a video, and it happens after
    // the system share sheet has already slid away — so without the scrim the
    // user is handed a chat screen that appears to be doing nothing.
    _setMediaBusy(true);
    try {
      final lone = payload.loneImage;
      if (lone != null) {
        final bytes = await _readShared(lone, messenger, loc);
        if (bytes == null || !mounted) return;
        final outcome = await CameraEditorScreen.open(context, source: bytes);
        // Released whether or not it was sent: the editor holds its own copy of
        // the bytes, and a share the user backed out of has no second chance to
        // be delivered from disk.
        ShareIntake.instance.disposeItems(payload.items);
        // `_sendEdited` goes through `_sendMedia`, which bumps the suggestion.
        if (outcome is EditorSend) _sendEdited(outcome);
        return;
      }

      // Everything else, in the order the sender chose. Sent one at a time
      // through the same funnel as a picked file, so the repository's upload
      // budget and retry queue see nothing unusual.
      for (final item in items) {
        final bytes = await _readShared(item, messenger, loc);
        if (bytes == null) continue;
        if (!mounted) return;
        _sendMedia(
          bytes: bytes,
          type: item.messageType,
          contentType: item.mimeType,
          fileName: item.messageType == MessageType.file ? item.fileName : null,
          fileSize: item.messageType == MessageType.file ? bytes.length : null,
          // The same poster the video PICKER extracts, and for the same reason:
          // without it the shared-content grid shows a play glyph forever,
          // because `messages.posterStorageId` is set once at send time and
          // never backfilled. `item.path` is a real filesystem path (both
          // platforms staged it themselves), which is exactly what the
          // extractor needs — the `kIsWeb` guard is belt-and-braces, since a
          // share cannot arrive there at all.
          posterBytes: item.messageType == MessageType.video && !kIsWeb
              ? await VideoPoster.extract(item.path)
              : null,
        );
      }
      ShareIntake.instance.disposeItems(payload.items);
    } finally {
      _setMediaBusy(false);
    }
  }

  /// Reads a staged share off disk, reporting the one failure that is a user's
  /// problem rather than a bug: the OS reclaimed the cache between the share
  /// and the tap that placed it.
  Future<Uint8List?> _readShared(
    SharedItem item,
    ScaffoldMessengerState messenger,
    AppLocalizations loc,
  ) async {
    try {
      return await File(item.path).readAsBytes();
    } catch (e) {
      debugPrint('share: could not read ${item.path}: $e');
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(loc.roomScreenFileReadFailedSnack)),
        );
      }
      return null;
    }
  }

  /// Tells the OS this chat was just messaged, so its share sheet ranks it up.
  ///
  /// Called from the room's send paths rather than from the repository because
  /// the suggestion needs a title and an avatar gradient, and those come from
  /// the theme — which only a widget has. Cheap and fire-and-forget: on Android
  /// it re-pushes one shortcut, on iOS it donates one intent, and a failure at
  /// either costs a slightly staler share sheet and nothing else.
  void _touchShareTarget() {
    if (!mounted) return;
    final room = _room ?? widget.repo.roomById(widget.roomId);
    if (room == null) return;
    if (!widget.repo.capabilitiesFor(room).canReceiveForwards) return;
    final loc = AppLocalizations.of(context);
    unawaited(ShareTargets.instance.touch(shareTargetFor(
      repo: widget.repo,
      theme: ThemeScope.of(context),
      room: room,
      savedMessagesTitle: loc.savedMessagesTitle,
      directMessageFallbackTitle:
          loc.approvalsScreenForwardDirectMessageFallback,
    )));
  }

  /// Sends what came out of the editor.
  void _sendEdited(EditorSend outcome) =>
      _sendPhoto(outcome.image, viewOnce: outcome.viewOnce);

  /// Sends one finished photograph. The single funnel for both photo paths —
  /// the editor's one picture and the tray's several — so a change to how a
  /// photo becomes a message cannot land on one of them and not the other.
  void _sendPhoto(CroppedImage image, {required bool viewOnce}) {
    _sendMedia(
      bytes: image.bytes,
      type: MessageType.image,
      contentType: image.contentType,
      pixelSize: Size(image.width.toDouble(), image.height.toDouble()),
      viewOnce: viewOnce,
    );
  }

  /// Opens the fullscreen gallery on [m], swipeable across every picture and
  /// clip in this conversation.
  ///
  /// The set is the transcript's own media in transcript order, which is the
  /// only order that means anything from inside a chat: swiping right goes back
  /// in time exactly as scrolling up does. It is a SNAPSHOT — a photo that
  /// arrives while the gallery is open does not appear in it, and should not:
  /// the rail would grow under the reader's thumb and the page they were
  /// looking at would shift out from under them.
  ///
  /// [messageBelongsIn] rather than a hand-written filter, so this and the
  /// shared-content MEDIA tab cannot come to disagree about what counts. It
  /// already declines an armed view-once photo — a burn-on-open picture is not
  /// something you swipe past — and anything with no storage id, which is what
  /// a failed or still-running upload looks like.
  Future<void> _openGallery(
    ChatMessage m, {
    required int sourceDecodeWidth,
  }) async {
    final media = [
      for (final x in widget.repo.timelineFor(widget.roomId))
        if (messageBelongsIn(x, RoomContentTab.media)) x,
    ];
    final start = media.indexWhere((x) => x.id == m.id);
    final id = m.mediaStorageId;
    if (start < 0) {
      // Tapped something the set does not contain. One picture is still better
      // than none — the same lone viewer a bubble outside a room gets.
      if (id == null) return;
      await FullscreenImageViewer.open(
        context,
        storageId: id,
        api: widget.api,
        heroTag: _transcriptHeroTag(m),
        thumbnailDecodeWidth: sourceDecodeWidth,
      );
      return;
    }

    // Where SHOW IN CHAT asked to be taken, filled in by the button and acted
    // on below rather than there. Travelling from inside the callback means
    // scrolling the transcript on the same frame the pager starts its exit,
    // and the Hero flying home reads its destination's rect once, at take-off
    // — so the picture flies to where the thumbnail *was* and blinks out over
    // whatever has scrolled into that spot. Waiting for the route to finish
    // costs the reader nothing they can perceive and is the difference between
    // a landing and a glitch.
    ChatMessage? travelTo;

    final landed = await MediaPagerScreen.open(
      context,
      items: media,
      initialIndex: start,
      api: widget.api,
      // The transcript's tags, not the shared-content grid's. Without this the
      // gallery would fly from a hero nothing in this route carries, and every
      // open would degrade to a cross-fade.
      heroTagFor: _transcriptHeroTag,
      sourceDecodeWidth: sourceDecodeWidth,
      onPageChanged: _alignTranscriptTo,
      onShowInChat: (msg) {
        travelTo = msg;
        // Pop the pager (a root-navigator route) before travelling, or the
        // transcript would scroll along behind a fullscreen photograph.
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
    if (!mounted) return;
    final target = travelTo;
    if (target != null) {
      await _jumpToMessage(target.id, from: m);
      return;
    }
    // Closed by hand, on a photograph the reader swiped to. `onPageChanged`
    // has already put its row under the flight; this is the belt to that
    // braces, for the case where the swipe and the close landed in one frame.
    if (landed != null && landed != start) _alignTranscriptTo(media[landed]);
  }

  /// The [Hero] tag [m]'s picture wears in THIS transcript.
  ///
  /// A photograph is drawn one of two ways depending on what it arrived with —
  /// as its own bubble, or as one tile of an album — and the two carry
  /// deliberately different tags. The gallery is handed messages rather than
  /// widgets, so it has to be told which; guessing wrong is not an error
  /// anywhere, it is a tag that matches no hero in the route, and the open
  /// degrades silently to a cross-fade. That is exactly what every photo in an
  /// album used to do.
  Object _transcriptHeroTag(ChatMessage m) =>
      _rowOwnerOf.containsKey(m.id) ? mosaicHeroTag(m) : bubbleMediaHeroTag(m);

  /// Brings the row that draws [m] into the transcript, silently, while the
  /// gallery is open over it.
  ///
  /// The gallery is a transparent route over a black scrim, so none of this is
  /// visible — and that is the point. A reader who swipes eight photographs
  /// deep is looking at a picture whose thumbnail may be a thousand rows away;
  /// closing there gives the returning Hero no destination in the tree, and a
  /// Hero with no destination does not complain, it cross-fades. Keeping the
  /// current picture's row laid out is what lets every close fly home, and it
  /// leaves the reader looking at the photograph they were looking at rather
  /// than the one they opened.
  ///
  /// Serialized on purpose. [snapToIndex] walks the list in hops and re-reads
  /// the position between them, so two of them running at once fight over the
  /// same controller; a fast swipe through a set fires one of these per page.
  /// Only the newest target is worth arriving at, so a request made while one
  /// is running replaces it rather than queuing behind it.
  String? _alignTarget;
  bool _aligning = false;

  Future<void> _alignTranscriptTo(ChatMessage m) async {
    _alignTarget = m.id;
    if (_aligning) return;
    _aligning = true;
    try {
      while (mounted && _alignTarget != null) {
        final id = _alignTarget!;
        if (_rowIndexOf[id] == null) break;
        await snapToIndex(
          controller: _scroll,
          targetIndex: () => _rowIndexOf[id],
          itemCount: () => _revItems.length,
          targetContext: () => _rowContextOf(id),
          probes: _mountedRowProbes,
          // Where a jump uses 0.3 to put the message under the reader's eyes:
          // this one is not being read, it is being made available to land on,
          // and centring gives the flight the most room on either side.
          alignment: 0.5,
          // Nobody can see this happen — the gallery is over it. An animated
          // scroll would only mean the row is still moving when the picture
          // arrives.
          settle: Duration.zero,
        );
        if (_alignTarget == id) _alignTarget = null;
      }
    } finally {
      _aligning = false;
      _alignTarget = null;
    }
  }

  /// Spends this viewer's one look at a view-once photo and shows it.
  ///
  /// The look is spent the moment the server hands back a ticket — not when the
  /// picture is dismissed — so a failure after that point is reported plainly
  /// rather than pretended away. Saying "that's gone" is more honest than a
  /// silent retry that can't work.
  Future<void> _openViewOnce(ChatMessage m) async {
    final messenger = ScaffoldMessenger.of(context);
    final res = await fetchViewOnce(
      repo: widget.repo,
      roomId: widget.roomId,
      messageId: m.id,
    );
    if (!mounted) return;
    final bytes = res.bytes;
    if (bytes != null) {
      await ViewOnceViewer.open(context, bytes: bytes);
      return;
    }
    final l10n = AppLocalizations.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(switch (res.failure!) {
          ViewOnceFailure.alreadyViewed => l10n.roomScreenViewOnceAlreadyViewed,
          ViewOnceFailure.gone => l10n.roomScreenViewOnceGone,
          ViewOnceFailure.network => l10n.roomScreenViewOnceNetworkError,
        }),
      ),
    );
  }

  /// Puts one or more photographs in front of the user before anything is sent.
  ///
  /// The picker is `pickMultiImage` — through [pickPhotos], which is where the
  /// platform's own failures are turned into something to say rather than an
  /// exception — and not `pickImage`, which is the whole feature: the library
  /// sheet has always been able to hand back a set, and asking it for one
  /// picture meant that sending four cost four trips through the attachment
  /// sheet, the OS picker and the editor — with the four photos landing in the
  /// conversation interleaved with whatever else arrived while the sender was
  /// going back for the next one.
  ///
  /// One picture still goes straight to the editor. It is the better screen for
  /// the case where all the attention is on one photograph, it is where the pen
  /// and the cropper live, and a review tray showing a rail of exactly one
  /// thumbnail would be furniture answering a question nobody asked. Several go
  /// to [PhotoTrayScreen], which is that screen for a set.
  ///
  /// The scrim is raised BEFORE the picker, not after it. `pickerImageQuality`
  /// forces the plugin to fully decode and re-encode every chosen asset —
  /// seconds for a dozen 12 megapixel HEICs — and that work happens once the
  /// native sheet has already slid away, so the user used to be handed back an
  /// unchanged chat screen and left to guess whether their tap had landed.
  ///
  /// Held for the whole method rather than lowered at the handoff: the editor
  /// and the tray both paint over the scrim and raise a spinner of their own
  /// while they decode, so there is no frame where nothing is spinning. One
  /// raise, one lower, no interleaving around a route push.
  Future<void> _pickAndSendFromGallery() async {
    // Resolved before the awaits below, which are async gaps after which
    // touching `context` is unsafe — the same up-front capture the file pick
    // and the pin paths make.
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);
    _setMediaBusy(true);
    try {
      final pick = await pickPhotos(
        // The OS enforces it, so the refusal happens while the user is still
        // looking at their library rather than after they have chosen thirty.
        limit: kMaxPhotoSelection,
      );
      if (!mounted) return;
      // The platform kept what was chosen — an iOS asset still in iCloud is
      // the usual reason, and one of those fails the whole batch rather than
      // dropping itself out of it. Nothing to send, so say why: the picker has
      // already slid away and the alternative is a tap that did nothing.
      if (pick.unreadable) {
        messenger.showSnackBar(
          SnackBar(content: Text(loc.mediaPickFailedMessage)),
        );
        return;
      }
      final picked = pick.files;
      if (picked.isEmpty) return;

      if (picked.length == 1) {
        final bytes = await picked.first.readAsBytes();
        if (!mounted) return;
        // Route through the same editor the camera path uses — a preview,
        // optional annotation, and a deliberate "send" tap instead of shipping
        // the photo the moment it is picked. No retake: there is no camera
        // behind this photo to go back to.
        final outcome = await CameraEditorScreen.open(context, source: bytes);
        if (outcome is EditorSend) _sendEdited(outcome);
        return;
      }

      // `limit` above is honoured by the iOS and Android pickers and by nothing
      // else — `file_selector`-backed web and desktop implementations ignore it.
      // Trimming here rather than letting thirty photographs through keeps the
      // send inside the repository's retained-upload budget, and saying so is
      // better than a batch that half-fails at the far end.
      final within = picked.length > kMaxPhotoSelection
          ? picked.sublist(0, kMaxPhotoSelection)
          : picked;
      if (within.length < picked.length) {
        messenger.showSnackBar(
          SnackBar(content: Text(loc.photoTrayLimitSnack(kMaxPhotoSelection))),
        );
      }

      final read = await readPickedPhotos(within);
      if (!mounted) return;
      if (read.bytes.isEmpty) {
        messenger.showSnackBar(
          SnackBar(content: Text(loc.photoTrayLoadFailedSnack)),
        );
        return;
      }

      final send = await PhotoTrayScreen.open(context, photos: read.bytes);
      if (!mounted) return;
      if (send != null) {
        // In the rail's order, and synchronously: `sendMediaLocal` puts an
        // optimistic bubble up per call, so the transcript grows the album in
        // the order the sender arranged it rather than in whatever order the
        // uploads happen to finish.
        for (final image in send.images) {
          _sendPhoto(image, viewOnce: send.viewOnce);
        }
      }
      // Counted across both halves: a photo the platform would not hand over at
      // all, and one whose bytes would not decode at export. Either way the
      // send is smaller than what was chosen, and saying so is better than
      // letting the user count bubbles.
      if (read.dropped > 0 || (send?.dropped ?? 0) > 0) {
        messenger.showSnackBar(
          SnackBar(content: Text(loc.photoTrayLoadFailedSnack)),
        );
      }
    } finally {
      _setMediaBusy(false);
    }
  }

  void _setMediaBusy(bool busy) {
    if (!mounted || _mediaBusy == busy) return;
    setState(() => _mediaBusy = busy);
  }

  void _onMentionChanged() {
    if (mounted) setState(() {});
  }

  /// Opens a mentioned user's profile. Silently does nothing for someone who
  /// has left the room since the message was sent — the mention still renders
  /// (its username is stored on the message) but there is no member row left to
  /// build a profile from.
  void _openMention(String userId) {
    final u = _members[userId];
    if (u != null) _openProfile(u);
  }

  /// The single funnel for every profile route out of this screen — the header,
  /// a bubble's avatar, the message-actions sheet and an `@` mention all land
  /// here, which is why the system-account guard belongs here and not at each
  /// of them.
  ///
  /// It is a fact about the USER, not about the room: the app's own account can
  /// post into a group room, and its bubble's avatar is a tap target there too.
  /// A profile for it offers a friend request `friends.ts` refuses and a call
  /// `calls.ts` refuses — a screenful of buttons that all say no.
  void _openProfile(ChatUser u) {
    if (u.isSystem) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(user: u, repo: widget.repo, api: widget.api),
      ),
    );
  }

  /// Same uncovered gap as the photo pick, and worse: there is no editor behind
  /// this one to take over the spinner, and a video's bytes are tens of
  /// megabytes to read across the platform channel. The scrim covers the pick
  /// and the read; the pending bubble covers the upload.
  Future<void> _pickAndSendVideo() async {
    // Captured before the awaits, for the reason the photo pick above gives.
    final messenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);
    _setMediaBusy(true);
    try {
      final pick = await pickVideo();
      if (!mounted) return;
      // Same refusal the photo path handles, and likelier here: a clip is the
      // kind of thing iCloud keeps off the device.
      if (pick.unreadable) {
        messenger.showSnackBar(
          SnackBar(content: Text(loc.mediaPickFailedMessage)),
        );
        return;
      }
      final picked = pick.file;
      if (picked == null) return;

      // Before `readAsBytes`, and only off web. `XFile.path` is a real
      // filesystem path on mobile, which is what the extractor needs; on web it
      // is a `blob:` URL with no filesystem behind it — the trap
      // `UploadService` documents for `uploadXFile` — and the plugin has no web
      // implementation to receive it anyway. Null there and on desktop, which
      // is why the grid's play-glyph tile is a permanent state rather than a
      // placeholder. Covered by the existing scrim: this whole method runs
      // inside `_setMediaBusy(true)`.
      final poster = kIsWeb ? null : await VideoPoster.extract(picked.path);

      final bytes = await picked.readAsBytes();
      _sendMedia(
        bytes: bytes,
        type: MessageType.video,
        contentType: 'video/mp4',
        posterBytes: poster,
      );
    } finally {
      _setMediaBusy(false);
    }
  }

  /// Same uncovered gap as the video pick, and for the same two reasons: the OS
  /// file browser is a route we don't own, and reading the chosen file back is
  /// a whole-file read across a platform channel (a `FileReader` round trip on
  /// web) before anything can go on screen.
  Future<void> _pickAndSendFile() async {
    // Resolved before the awaits below, which are async gaps after which
    // touching `context` is unsafe — the same up-front capture `_openViewOnce`
    // and the pin paths make.
    final messenger = ScaffoldMessenger.of(context);
    _setMediaBusy(true);
    try {
      // No `acceptedTypeGroups`: a chat carries whatever the sender has, and a
      // filter here would be a list of formats to keep updating forever.
      final picked = await openFile();
      if (picked == null || !mounted) return;

      // Read straight to bytes rather than holding the path. On web there is
      // no filesystem behind an `XFile` at all, and off web `UploadService`
      // wants bytes anyway — the same reason the video path reads them here.
      final Uint8List bytes;
      try {
        bytes = await picked.readAsBytes();
      } catch (_) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).roomScreenFileReadFailedSnack)),
        );
        return;
      }
      if (!mounted) return;

      // Refused here rather than by `_maxRetainedUploadBytes`, which is a
      // budget for *all* unfinished sends and whose overflow path produces a
      // failed bubble with no bytes left to retry — a dead end rather than an
      // error. Refusing at the picker names a size while the user is still
      // looking at the file browser they chose it in.
      if (bytes.length > kMaxFileUploadBytes) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).roomScreenFileSizeCapSnack(
                formatFileSize(kMaxFileUploadBytes),
              ),
            ),
          ),
        );
        return;
      }

      final name = picked.name;
      _sendMedia(
        bytes: bytes,
        type: MessageType.file,
        // Derived from the name rather than trusting `picked.mimeType`, which
        // is null on most Android content providers and only as good as the
        // browser's own guess on web.
        contentType: mimeTypeForFileName(name),
        fileName: name,
        fileSize: bytes.length,
      );
    } finally {
      _setMediaBusy(false);
    }
  }

  /// Puts [bytes] in the transcript now and uploads them behind it.
  ///
  /// [pixelSize] is the attachment's intrinsic size when the caller knows it —
  /// the image editor hands back exactly that. It rides along on the message so
  /// nobody, sender included, has to decode the picture before they can lay out
  /// a bubble the right shape for it.
  ///
  /// Synchronous, and that is the whole change. This used to `await` the upload
  /// and only *then* call `sendMedia`, which is where the optimistic bubble is
  /// built — so the bubble existed for the length of the mutation (milliseconds)
  /// and not for the length of the upload (seconds). The user tapped SEND, the
  /// editor popped, and the transcript sat there unchanged until the photo
  /// appeared fully formed. Now the repository owns the upload, so the bubble is
  /// on screen on this frame and the send outlives this screen: walk out of the
  /// room mid-upload and it still lands.
  void _sendMedia({
    required Uint8List bytes,
    required MessageType type,
    required String contentType,
    Size? pixelSize,

    /// Set on documents only — the name the sender's filesystem gave it, and
    /// its size. They ride on the message rather than being derived from the
    /// blob because Convex storage keeps neither.
    String? fileName,
    int? fileSize,

    /// A JPEG still frame for a video. Null on web and desktop, where it
    /// cannot be extracted at all.
    Uint8List? posterBytes,

    /// Playing time, when the sender measured it — which the composer's own
    /// recorder always does, and a picked file never can without decoding it.
    /// Rides on the message so a shared-content row and a circular note can
    /// both show a length without opening the blob.
    int? mediaDurationMs,

    /// Armed with the circled "1" in the editor: one look per recipient, then
    /// the file is deleted from the server.
    bool viewOnce = false,
  }) {
    // Snapshot and disarm up front — see _send. Deliberately NOT restored on
    // failure the way this used to be: the failure now arrives long after the
    // composer has moved on, and re-arming a reply target under a user who has
    // started typing something else is worse than losing it. Nothing is lost
    // anyway — the reply rides on the pending bubble, so retrying it keeps the
    // tether.
    final replyTarget = _replyingTo;
    if (replyTarget != null) setState(() => _replyingTo = null);
    // Same two lines the text send does, for the same two reasons: a send while
    // reading old history has to drop the window or the sender is left looking
    // at a transcript their photo isn't in, and the bubble to scroll to now
    // exists by the time we ask.
    widget.repo.exitHistoryWindow(widget.roomId);
    widget.repo.sendMediaLocal(
      roomId: widget.roomId,
      bytes: bytes,
      contentType: contentType,
      type: type,
      mediaWidth: pixelSize?.width,
      mediaHeight: pixelSize?.height,
      fileName: fileName,
      fileSize: fileSize,
      posterBytes: posterBytes,
      mediaDurationMs: mediaDurationMs,
      replyToId: replyTarget?.id,
      viewOnce: viewOnce,
    );
    _scrollToBottom();
    _touchShareTarget();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Set here rather than at construction because the theme is a
    // `ThemeScope` lookup and can change under a live screen. The controller
    // only reads it while painting, so assigning on every build is free.
    _composer.tint = theme.accent;
    final room = _room ?? widget.repo.roomById(widget.roomId);
    if (room == null) {
      return Scaffold(
        backgroundColor: theme.background,
        body: Center(
          child: Text(
            AppLocalizations.of(context).roomScreenRoomGone,
            style: theme.bodySoft,
          ),
        ),
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
      _rowOwnerOf = const {};
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
    // Every photo bubble below reads this out of the tree instead of being
    // handed a callback it would have to carry through five widgets. See the
    // scope's own doc for why it is an inherited widget and not a parameter.
    return RoomGalleryScope(
      openGallery: _openGallery,
      child: SpeakerScope(
        // A DM hands out no colours at all. Two people, two margins — the layout
        // has already said everything a colour could, and tinting the one
        // incoming bubble would just be a second accent.
        slots: room.isDm ? SpeakerSlots.none : _speakerSlots,
        child: ChatPane(
          // Back cancels a selection before it leaves the room — the selection
          // bar has its own CANCEL, but a system back that walked out of the chat
          // instead of out of the mode would be the wrong kind of surprising.
          child: PopScope(
            canPop: !_selection.active,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _selection.clear();
            },
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  theme.backgroundLayer(context),
                  if (chatStyle == ChatStyle.classic)
                    _buildClassic(context, room, messages, items, me)
                  else
                    _buildLiquid(context, room, messages, items, me),
                  // Last, so it covers the header and the composer too — a scrim
                  // that dims the transcript but leaves a live attach button
                  // underneath it is an invitation to make the problem worse.
                  if (_mediaBusy) const BusyScrim(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassic(BuildContext context, ChatRoom room, List<ChatMessage> messages, List<RoomItem> items, String me) {
    final theme = ThemeScope.of(context);
    // Read once, not once per reference — this branch used to call
    // `scheduledFor` twice in the same build while the liquid one cached it.
    final scheduled = widget.repo.scheduledFor(room.id);
    final indicator = SettingsStore.instance.scheduledIndicator;
    return SafeArea(
      child: Column(
        children: [
          _Header(
            room: room,
            typing: widget.repo.typingIn(room.id),
            dmUser: widget.repo.otherUserFor(room),
            api: widget.api,
            caps: widget.repo.capabilitiesFor(room),
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
          // Zero height with no pins, so no condition is needed here — and
          // unwrapped by ChatColumn, matching GroupCallBanner above.
          PinnedMessageBanner(
            pins: widget.repo.pinsFor(room.id),
            activeIndex: _pinCursor,
            onTap: _onPinBannerTap,
            onOpenList: () => _openPinList(room),
          ),
          // Zero height unless this room is switched on, so it needs no
          // condition here — the same posture GroupCallBanner and the pinned
          // strip above it take. Below the pins, because a pin is about the
          // conversation and this is about how the reader is reading it.
          RoomTranslateBar(
            roomId: room.id,
            onStop: () => Sebastian.instance.stopRoom(room.id),
          ),
          Expanded(
            child: _messageBody(
              context,
              room,
              messages,
              items,
              me,
              // The 12 is breathing room under the HEADER. With a pinned strip
              // present it lands between the strip and the first message
              // instead, which makes the strip read as a separate panel rather
              // than as the transcript's own chrome — the strip's own 44pt is
              // the separation.
              //
              // The liquid style has the identical line with the identical
              // fix; this one was missed the first time because the two styles
              // compute their padding in completely different places.
              listPadding: EdgeInsets.fromLTRB(
                20,
                widget.repo.pinsFor(room.id).isEmpty ? 12 : 0,
                20,
                24,
              ),
              // Classic already says who's typing in its header — a second
              // indicator at the bottom of the transcript would say it twice.
              showTypingRow: false,
            ),
          ),
          // Same column as the messages above, so the composer lines up with
          // the conversation instead of running the full width of the window.
          ChatColumn(
            // The reply card is a plain conditional child, so without this the
            // bar's height would jump to make room while only the card's
            // contents faded in. Bottom alignment keeps the composer planted
            // and grows the card upward out of it.
            child: AnimatedSize(
              duration: theme.motionFast,
              curve: theme.motionEntrance,
              alignment: Alignment.bottomCenter,
              child: _selection.active
                  ? _selectionBar(room, me)
                  : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // `else if` rather than a sibling `if`: the two banners are
                // mutually exclusive by state construction (see [_armEdit] /
                // [_armReply]), and spelling that here means a bug in that
                // invariant renders ONE wrong banner instead of two stacked
                // ones.
                if (_editing != null)
                  ComposerEditCard(
                    message: _editing!,
                    onCancel: _cancelEdit,
                  )
                else if (_replyingTo != null)
                  ComposerReplyCard(
                    parent: _replyingTo!,
                    api: widget.api,
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
                if (_mention.isOpen)
                  MentionPicker(session: _mention, api: widget.api),
                // Below the reply/edit cards and above the composer: those
                // describe the message being written right now, this describes
                // messages already written, so it belongs further from the
                // field. Zero-height when the room has none queued.
                if (indicator.showsPill && scheduled.isNotEmpty)
                  ScheduledPill(
                    scheduled: scheduled,
                    onTap: _openScheduledList,
                  ),
                ChatComposerClassic(
                  controller: _composer,
                  focusNode: _composerFocus,
                  ephemeral: room.isEphemeral,
                  onSend: _send,
                  onSchedule: _composerSchedule,
                  scheduledCount: indicator.showsBadge
                      ? widget.repo.pendingScheduledCount(room.id)
                      : 0,
                  onChanged: (_) => widget.repo.noteTyping(),
                  onAttach: _onAttach,
                  onCamera: _onCamera,
                  capture: _composerCapture,
                  mention: _mention,
                  captureOpenHintRoomId: room.id,
                ),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiquid(BuildContext context, ChatRoom room, List<ChatMessage> messages, List<RoomItem> items, String me) {
    final theme = ThemeScope.of(context);
    final topSafe = MediaQuery.paddingOf(context).top;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    // Header: 8pt top + 44pt button + 8pt bottom = 60pt; composer: same.
    // Scaffold's default resizeToAvoidBottomInset shrinks the body when the
    // keyboard appears, so we DO NOT add viewInsets manually — that would
    // double-count and leave a massive gap.
    //
    // Split in two because the pin banner grows only the TOP chrome. A single
    // constant here was doing double duty for the header and the composer, so
    // widening it for the banner would have lifted the transcript's bottom
    // padding too and left a gap above the composer.
    final pins = widget.repo.pinsFor(room.id);
    // The translate strip grows the top chrome exactly the way the pin banner
    // does, and for the same reason: in this style it FLOATS over a
    // `Positioned.fill` transcript, so nothing else holds the first message
    // clear of it. It went unreserved while it was a full-bleed bar, which put
    // it on top of the oldest visible bubble whenever a room was translating.
    final translating = Sebastian.instance.isRoomTranslating(room.id) &&
        Sebastian.instance.isReady;
    final topChromeH = 60.0 +
        (pins.isEmpty ? 0.0 : kPinnedBannerHeight) +
        (translating ? kCompanionStripHeight : 0.0);
    // The scheduled pill grows only the BOTTOM chrome — the exact case the
    // split above exists for. In the classic style the composer stack sits in a
    // real Column above an `Expanded` transcript, so a pill pushes the list and
    // covers nothing; here the chrome FLOATS over a `Positioned.fill`
    // transcript and this constant is the only thing holding the newest bubble
    // clear of it. Left at 60 the pill would sit on top of the last message.
    //
    // The reply card and the mention picker beside it are deliberately NOT
    // reserved: both are transient and keyboard-adjacent, and reserving them
    // would leave a permanent gap above the composer for chrome that is usually
    // absent. The pill is persistent, so it owns its space.
    final scheduled = widget.repo.scheduledFor(room.id);
    final indicator = SettingsStore.instance.scheduledIndicator;
    // The SAME condition the pill itself is built under, deliberately spelled
    // once into a local both read. Reserving for a pill that is switched off
    // leaves a permanent gap; building one whose space is not reserved puts it
    // on top of the newest message.
    final bottomChromeH = 60.0 +
        (indicator.showsPill && scheduled.isNotEmpty ? kScheduledPillHeight : 0.0);
    final listPadding = EdgeInsets.fromLTRB(
      20,
      // The +12 is breathing room under the HEADER, and only under the header.
      // With a pinned banner present it became a gap between the strip and the
      // first message, which reads as the two belonging to different surfaces —
      // the strip is chrome for the transcript, not a separate panel floating
      // above it. The banner's own 44pt already separates them.
      topSafe + topChromeH + (pins.isEmpty ? 12.0 : 0.0),
      20,
      bottomChromeH + 16 + bottomSafe,
    );
    // BackdropGroup batches the seven BackdropFilters in the chrome (header
    // pill + 2 buttons + composer attach + camera + field + send) into a
    // single rasterization pass — see lib/widgets/liquid_glass.dart.
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
                      caps: widget.repo.capabilitiesFor(room),
                      onOpenInfo: () => _openRoomInfo(room),
                    ),
                    if (!room.isDm && GroupCallService.maybeInstance != null)
                      GroupCallBanner(
                        api: GroupCallApi(ConvexBackend.instance),
                        service: GroupCallService.instance,
                        roomId: room.id,
                        userId: me,
                      ),
                    // Frosted here, not opaque: in this style the chrome floats
                    // over the transcript rather than sitting in a column above
                    // it, and `topChromeH` above has already reserved its space.
                    PinnedMessageBanner(
                      pins: pins,
                      activeIndex: _pinCursor,
                      onTap: _onPinBannerTap,
                      onOpenList: () => _openPinList(room),
                      glass: true,
                    ),
                    // Frosted for the same reason the pinned strip above it
                    // is: square corners under a rounded glass header were the
                    // one piece of chrome in this style not speaking its
                    // language.
                    RoomTranslateBar(
                      roomId: room.id,
                      onStop: () => Sebastian.instance.stopRoom(room.id),
                      glass: true,
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
              // See the classic composer: grows the reply card up out of the
              // bar instead of snapping the bar taller.
              child: AnimatedSize(
                duration: theme.motionFast,
                curve: theme.motionEntrance,
                alignment: Alignment.bottomCenter,
                child: _selection.active
                    ? _selectionBar(room, me)
                    : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mirrors the classic column above — see the comment there.
                if (_editing != null)
                  ComposerEditCard(
                    message: _editing!,
                    onCancel: _cancelEdit,
                  )
                else if (_replyingTo != null)
                  ComposerReplyCard(
                    parent: _replyingTo!,
                    api: widget.api,
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
                if (_mention.isOpen)
                  MentionPicker(session: _mention, api: widget.api),
                // Mirrors the classic column above. Unlike the reply card and
                // the mention picker beside it, this one has its space reserved
                // in `bottomChromeH` — see the note there.
                if (indicator.showsPill && scheduled.isNotEmpty)
                  ScheduledPill(
                    scheduled: scheduled,
                    onTap: _openScheduledList,
                  ),
                ChatComposerLiquid(
                  controller: _composer,
                  focusNode: _composerFocus,
                  ephemeral: room.isEphemeral,
                  onSend: _send,
                  onSchedule: _composerSchedule,
                  scheduledCount: indicator.showsBadge
                      ? widget.repo.pendingScheduledCount(room.id)
                      : 0,
                  onChanged: (_) => widget.repo.noteTyping(),
                  onAttach: _onAttach,
                  onCamera: _onCamera,
                  capture: _composerCapture,
                  mention: _mention,
                  captureOpenHintRoomId: room.id,
                ),
              ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The bottom chrome while a selection is live, in both chat styles.
  ///
  /// Built here rather than passed down because what the two buttons are
  /// allowed to do depends on the room, the viewer and the picks — three things
  /// the bar itself has no business knowing.
  Widget _selectionBar(ChatRoom room, String me) {
    final picked = _selectedMessages;
    return TranscriptSelectionBar(
      count: picked.length,
      onCancel: _selection.clear,
      onForward: () => _forwardMessages(picked),
      onDelete: _deleteSelected,
      canForward: _canForward(room, picked),
      canDelete: _canDelete(picked, me),
    );
  }

  /// Opens room info, and travels to whatever it hands back.
  ///
  /// The result comes from one of two places — the shared-content browser two
  /// routes up, passed through `RoomInfoScreen` untouched, or its own "Saved
  /// messages" section one route up. Both hand the message here rather than
  /// travelling themselves because only this screen owns the back-trail, the
  /// folded-thread fallback and the `listAround` window fetch, and none of that
  /// is reachable from a route stacked on top of it.
  ///
  /// The `mounted` check after the await is load-bearing rather than
  /// defensive. `RoomInfoScreen` pops TWICE on leave and on delete, which takes
  /// this screen down with it — so on those paths the future completes into a
  /// disposed state. Both pop null, so the null guard covers correctness and
  /// this one covers the `setState` inside `_travelTo`.
  Future<void> _openRoomInfo(ChatRoom room) async {
    final jump = await Navigator.of(context).push<ChatMessage>(
      MaterialPageRoute(
        builder: (_) => RoomInfoScreen(roomId: room.id, repo: widget.repo, api: widget.api),
      ),
    );
    if (!mounted || jump == null) return;

    // Deliberately NO `_jumpBack.push`, unlike `_jumpToPin` and the reply
    // tether. Those two jump from one place in the transcript to another, so
    // "back" means the position you were reading and the pill is the way home.
    //
    // This arrives from a screen the reader deliberately left the transcript
    // for — the media library, or room info's saved list. Either way there is
    // no reading position they left behind mid-scroll, and a back pill would
    // offer to return them to wherever the transcript happened to be sitting
    // before they navigated away from it.
    //
    // `from` is still the target message, so one folded into a thread hands
    // off to that thread exactly as a pin does.
    await _travelTo(jump.id, from: jump);
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
    // Built once for the whole transcript rather than inside the item builder.
    // Its callbacks take the message id, so one object serves every interactive
    // card in the list — which is the entire reason [InteractionActions] is
    // shaped that way. Rebuilding it per row would allocate six closures for
    // every row in a scrolling list, nearly all of which are plain text.
    final interactionActions = _interactionActions;
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
                    left: listPadding.left,
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
                    // belongs.
                    if (typingRows == 1 && i == 0) {
                      return typingRow();
                    }
                    final item = items[i - typingRows];
                    if (item is IntroItem) {
                      return _RoomIntro(
                        room: room,
                        members: _members.values.toList(),
                        api: widget.api,
                        caps: widget.repo.capabilitiesFor(room),
                      );
                    }
                    if (item is DateDividerItem) {
                      return _trackedDate(
                        stableId: 'd_${item.label}',
                        label: item.label,
                        isDivider: true,
                        child: _DateDivider(label: item.label),
                      );
                    }
                    // MUST precede the cast below — a new RoomItem subtype
                    // reaching it throws, and the analyzer won't catch that.
                    if (item is UnreadDividerItem) {
                      // Not wrapped in _trackedDate, same as the fold chip
                      // below: it carries no date and would otherwise win the
                      // topmost-tracked-item contest in
                      // _recomputePositionState and show a wrong floating date.
                      return const _UnreadDivider();
                    }
                    if (item is ThreadFoldItem) {
                      // Deliberately not wrapped in _trackedDate: the chip
                      // carries no date, and registering it would let it win
                      // the topmost-tracked-item contest in
                      // _recomputePositionState and show a wrong floating date.
                      final chip = _ThreadFoldChip(
                        fold: item,
                        api: widget.api,
                        members: _members,
                        onTap: () => _openFoldedThread(item),
                      );
                      // Scenery while a selection is live. The chip stands for
                      // messages that are NOT on screen, so there is nothing
                      // here to pick — and opening the thread overlay on top of
                      // a live selection would strand it behind another surface.
                      return _selection.active
                          ? IgnorePointer(child: chip)
                          : chip;
                    }
                    final messageItem = item as MessageItem;
                    final m = messageItem.message;
                    final grouped = messageItem.grouped;
                    final replyMarker = messageItem.replyMarker;
                final author = _members[m.senderId];
                final isMine = m.senderId == me;
                // A run is bracketed: name on the row that opens it, avatar on
                // the row that closes it — always at the bubble's bottom edge,
                // whether that row closes a five-message run or is a run of
                // one standing on its own.
                final showAvatar = messageItem.lastInRun;
                // `author` is null until rooms:getMembers lands, and optimistic
                // local sends carry an empty senderName — both mean "no name to
                // show yet" rather than a blank line.
                //
                // Gated on `newSender`, not `grouped`: a full-quote reply opens
                // its own spacing beat even from the same sender (see
                // `continuesRun`), but that is not a reason to say their name
                // again — the reader saw it one bubble ago.
                final senderName = (isMine || room.isDm || !messageItem.newSender)
                    ? null
                    : (author?.displayName.trim().isNotEmpty ?? false
                        ? author!.displayName
                        : (m.senderName.trim().isEmpty ? null : m.senderName));
                // Both receipts are room-wide cursors measured against THIS
                // message's timestamp — "somebody's cursor is at or past you".
                // Group rooms therefore read as "at least one other member",
                // which is the same promise the SEEN indicator has always made.
                final othersRead = widget.repo.latestOthersReadAt;
                final seenByOthers = isMine && othersRead != null && !othersRead.isBefore(m.createdAt);
                final othersDelivered = widget.repo.latestOthersDeliveredAt;
                final deliveredToOthers = isMine &&
                    othersDelivered != null &&
                    !othersDelivered.isBefore(m.createdAt);
                // Read on every build rather than snapshotted, so saving from
                // the action menu marks the bubble on the next frame — the
                // bookmark subscription notifies the repository, and this list
                // already rebuilds on that.
                final saved = widget.repo.isMessageSaved(room.id, m.id);
                final isPending = m.id.startsWith('tmp_');
                final selecting = _selection.active;
                // Every menu gate in one object — the predicates that used to
                // be derived inline here (and re-derived, by hand, in
                // ThreadOverlay) live in `message_capabilities.dart` now.
                final caps = widget.repo.capabilitiesForMessage(m, room);
                final canReply = caps.canReply;
                // Only a failed send gets handed live retry/discard callbacks.
                // The tile draws the pair when it has them, so gating here is
                // what keeps a healthy bubble from offering to resend itself.
                final sendFailed =
                    isPending && m.status == MessageStatus.error;
                Future<void> onRetrySend() =>
                    widget.repo.retryPending(m.id);
                void onDiscardSend() => widget.repo.discardPending(m.id);
                // A row's pulse is not always about the row's own message. An
                // album draws several, and the id a jump landed on is any one
                // of them — comparing against `m.id` alone (which is the LAST
                // photograph of a block) meant a trip to the second picture of
                // five arrived, scrolled, and then pulsed nothing at all.
                final highlightedId = _highlightedMessageId;
                final albumHighlightId = highlightedId == null
                    ? null
                    : (messageItem.album.any((p) => p.id == highlightedId)
                        ? highlightedId
                        : null);
                final highlightT =
                    (highlightedId == m.id || albumHighlightId != null)
                        ? _highlightCtrl.value
                        : 0.0;
                /// The action menu for ONE message of this row.
                ///
                /// Parameterised because a row is not always one message. An
                /// album draws several, and long-pressing its third picture
                /// has to open the menu for that picture, anchored to that
                /// tile: [anchorKey] is the tile's rect, and null falls back
                /// to the row's own tracked one, which is what a lone bubble
                /// wants.
                Future<void> longPressOn(
                  ChatMessage target, {
                  GlobalKey? anchorKey,
                }) async {
                  HapticFeedback.mediumImpact();
                  FocusManager.instance.primaryFocus?.unfocus();
                  final messenger = ScaffoldMessenger.of(context);
                  final anchor = anchorKey ??
                      _dateTracks['m_${_rowOwner(target.id)}']?.key;
                  if (anchor == null) return;
                  final result = await showMessageActionMenu(
                    context: context,
                    anchorKey: anchor,
                    isMine: isMine,
                    // Re-read for [target] rather than reused from the row:
                    // an album's tiles are separate messages, and what may be
                    // done to one of them is a function of which one.
                    // Sebastian's availability is a fact about the DEVICE,
                    // not about this message, so it is applied here rather
                    // than inside `messageCapabilitiesFor` — the same shape
                    // `ThreadOverlay` uses to withhold VIEW THREAD. Note it
                    // withholds the row only where he cannot run AT ALL; not
                    // being installed yet still offers it, because tapping it
                    // is how he gets installed.
                    capabilities: Sebastian.instance.isAvailable
                        ? widget.repo.capabilitiesForMessage(target, room)
                        : widget.repo
                            .capabilitiesForMessage(target, room)
                            .copyWith(canTranslate: false),
                    isPinned: widget.repo.isMessagePinned(room.id, target.id),
                    isSaved: widget.repo.isMessageSaved(room.id, target.id),
                    isTranslated:
                        Sebastian.instance.isShowingTranslation(target),
                    // The transcript row holds a document's name to one line;
                    // this is where the whole thing is legible.
                    fileName:
                        target.type == MessageType.file ? target.fileName : null,
                    bubbleBuilder: (_) {
                      // False only on an album tile, whose lifted preview is
                      // one photograph out of several and so inherits nothing
                      // about the block's place in the run.
                      final sameRow = target.id == m.id;
                      final parentAuthor = target.isReply
                          ? _members[target.replyToPreview?.senderId]
                          : null;
                      // Same avatar/name geometry as the row it lifted off, so
                      // the preview reads as that exact bubble rather than a
                      // subtly different one.
                      //
                      // Re-scoped for the same reason the menu re-reads the
                      // chat metrics: this builder runs on the ROOT overlay,
                      // where the room's own SpeakerScope is not an ancestor.
                      // Without it the lifted bubble would drop its speaker
                      // colour at exactly the moment it is being stared at.
                      return SpeakerScope(
                        slots: room.isDm ? SpeakerSlots.none : _speakerSlots,
                        child: target.isEphemeral
                          ? EphemeralMessageBubble(
                              message: target,
                              now: _now,
                              currentUserId: me,
                              api: widget.api,
                              author: author,
                              parentAuthor: parentAuthor,
                              saved: widget.repo
                                  .isMessageSaved(room.id, target.id),
                              replyMarker:
                                  sameRow ? replyMarker : ReplyMarker.full,
                              grouped: sameRow && grouped,
                              lastInRun: !sameRow || messageItem.lastInRun,
                              showAvatarSlot: !room.isDm,
                              showAvatar: showAvatar,
                              senderName: senderName,
                              onOpenViewOnce: () => _openViewOnce(target),
                            )
                          : MessageBubble(
                              message: target,
                              now: _now,
                              currentUserId: me,
                              api: widget.api,
                              author: author,
                              parentAuthor: parentAuthor,
                              seenByOthers: seenByOthers,
                              deliveredToOthers: deliveredToOthers,
                              saved: widget.repo
                                  .isMessageSaved(room.id, target.id),
                              replyMarker:
                                  sameRow ? replyMarker : ReplyMarker.full,
                              grouped: sameRow && grouped,
                              lastInRun: !sameRow || messageItem.lastInRun,
                              showAvatarSlot: !room.isDm,
                              showAvatar: showAvatar,
                              senderName: senderName,
                              onOpenViewOnce: () => _openViewOnce(target),
                            ),
                      );
                    },
                  );
                  if (!mounted || result == null) return;
                  if (result.emoji != null) {
                    await widget.repo.toggleReaction(messageId: target.id, emoji: result.emoji!);
                    return;
                  }
                  if (result.openFullReactionPicker) {
                    final emoji = await showReactionPicker(this.context);
                    if (emoji == null || emoji.isEmpty) return;
                    await widget.repo.toggleReaction(messageId: target.id, emoji: emoji);
                    return;
                  }
                  switch (result.action!) {
                    case MessageAction.reply:
                      _armReply(target);
                      break;
                    case MessageAction.edit:
                      _armEdit(target);
                      break;
                    case MessageAction.forward:
                      await _forwardMessages([target]);
                      break;
                    case MessageAction.select:
                      _beginSelection(target);
                      break;
                    case MessageAction.viewThread:
                      await _openThread(target);
                      break;
                    case MessageAction.copy:
                      await Clipboard.setData(ClipboardData(text: target.content));
                      if (!context.mounted) return;
                      messenger.showSnackBar(SnackBar(
                          content: Text(AppLocalizations.of(context)
                              .roomScreenCopiedSnack)));
                      break;
                    case MessageAction.copyName:
                      await Clipboard.setData(
                          ClipboardData(text: target.fileName ?? ''));
                      if (!context.mounted) return;
                      messenger.showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)
                              .roomScreenNameCopiedSnack)));
                      break;
                    case MessageAction.copyCoordinates:
                      // `capabilitiesForMessage` already refused this row
                      // unless `target.locationShare` is non-null, but a share can
                      // still end between the long-press and the tap — the
                      // guard is what keeps that race from copying stale
                      // formatting of a null value instead of just no-op'ing.
                      final share = target.locationShare;
                      if (share != null) {
                        await Clipboard.setData(ClipboardData(
                            text: formatCoordinates(
                                share.latitude, share.longitude)));
                      }
                      if (!context.mounted) return;
                      messenger.showSnackBar(SnackBar(
                          content: Text(AppLocalizations.of(context)
                              .locationBubbleCoordinatesCopied)));
                      break;
                    case MessageAction.translate:
                      await _translateMessage(target, messenger);
                      break;
                    case MessageAction.showOriginal:
                      Sebastian.instance.showOriginal(target);
                      break;
                    case MessageAction.translateAgain:
                      Sebastian.instance.translateAgain(target);
                      break;
                    case MessageAction.pin:
                      final err = await widget.repo.pinMessage(room.id, target.id);
                      // Surfaced rather than swallowed: the cap is the only
                      // way this fails, and silence would read as a dead menu.
                      if (err != null) {
                        if (!context.mounted) return;
                        final l10n = AppLocalizations.of(context);
                        messenger.showSnackBar(SnackBar(
                          content: Text(err == 'PIN_LIMIT_REACHED'
                              ? l10n.roomScreenPinLimitSnack
                              : l10n.roomScreenPinFailedSnack),
                        ));
                      }
                      break;
                    case MessageAction.unpin:
                      await widget.repo.unpinMessage(room.id, target.id);
                      break;
                    case MessageAction.save:
                      final saveErr =
                          await widget.repo.saveMessage(room.id, target.id);
                      // Surfaced for the reason the pin cap is: the per-room
                      // ceiling is the only way this fails, and a menu row that
                      // quietly does nothing reads as broken.
                      if (saveErr != null) {
                        if (!context.mounted) return;
                        final l10n = AppLocalizations.of(context);
                        messenger.showSnackBar(SnackBar(
                          content: Text(saveErr == 'SAVE_LIMIT_REACHED'
                              ? l10n.roomScreenSaveLimitSnack
                              : l10n.roomScreenSaveFailedSnack),
                        ));
                      }
                      break;
                    case MessageAction.unsave:
                      await widget.repo.unsaveMessage(room.id, target.id);
                      break;
                    case MessageAction.delete:
                      await widget.repo.deleteMessage(target.id);
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
                          targetId: target.id,
                          reason: reason,
                        );
                        if (!context.mounted) return;
                        messenger.showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)
                              .roomScreenReportSentSnack)),
                        );
                      } catch (_) {}
                      break;
                  }
                }

                Future<void> onLongPress() => longPressOn(m);

                // Parameterised for the reason `longPressOn` is: an album
                // row draws several messages, and a chip on the third
                // photograph belongs to the third photograph.
                void reactionTapOn(ChatMessage target, String e) {
                  widget.repo.toggleReaction(messageId: target.id, emoji: e);
                }

                void onReactionTap(String e) => reactionTapOn(m, e);

                Future<void> reactionLongPressOn(
                    ChatMessage target, String e) async {
                  HapticFeedback.mediumImpact();
                  await showReactionDetailsSheet(
                    context,
                    repo: widget.repo,
                    api: widget.api,
                    roomId: room.id,
                    messageId: target.id,
                    fallback: target.reactions,
                    currentUserId: me,
                    initialEmoji: e,
                    // The live member map is the only resolver that covers
                    // people who aren't friends of ours.
                    resolveUser: (id) => _members[id],
                    onOpenProfile: _openProfile,
                  );
                }

                Future<void> onReactionLongPress(String e) =>
                    reactionLongPressOn(m, e);

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
                        onReactionLongPress: onReactionLongPress,
                        onAuthorTap: author != null && !isMine ? onAuthorTap : null,
                        onMentionTap: _openMention,
                        onReplyIndicatorTap: (parentId) =>
                            _jumpToMessage(parentId, from: m),
                        onViewThread: m.isReply ? onViewThread : null,
                        parentAuthor: parentAuthor,
                        highlightT: highlightT,
                        seenByOthers: seenByOthers,
                        deliveredToOthers: deliveredToOthers,
                        saved: saved,
                        replyMarker: replyMarker,
                        grouped: grouped,
                        lastInRun: messageItem.lastInRun,
                        showAvatarSlot: !room.isDm,
                        showAvatar: showAvatar,
                        senderName: senderName,
                        onOpenViewOnce: () => _openViewOnce(m),
                        // Offered only on the sender's own running share. A
                        // recipient has nothing to stop, and the bubble hides
                        // the control entirely rather than showing a disabled
                        // one — "you may not stop this" is not a thing anyone
                        // needs told about somebody else's location.
                        onStopLiveShare: isMine && m.isLiveLocationRunning(_now)
                            ? () => widget.repo.stopLiveLocation(messageId: m.id)
                            : null,
                        publishingLiveShare:
                            widget.repo.activeLiveShareMessageId == m.id,
                        onRetrySend: sendFailed ? onRetrySend : null,
                        onDiscardSend: sendFailed ? onDiscardSend : null,
                        // A poll in a Chamber of Secrets room is an ordinary
                        // poll with a clock on it. Nothing about answering one
                        // changes, so the wiring is identical to the standard
                        // bubble's below.
                        interaction: m.type.isInteractive
                            ? widget.repo.interactionFor(room.id, m.id)
                            : null,
                        interactionActions: interactionActions,
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
                        onReactionLongPress: onReactionLongPress,
                        onAuthorTap: author != null && !isMine ? onAuthorTap : null,
                        onMentionTap: _openMention,
                        onReplyIndicatorTap: (parentId) =>
                            _jumpToMessage(parentId, from: m),
                        onViewThread: m.isReply ? onViewThread : null,
                        parentAuthor: parentAuthor,
                        highlightT: highlightT,
                        seenByOthers: seenByOthers,
                        deliveredToOthers: deliveredToOthers,
                        saved: saved,
                        replyMarker: replyMarker,
                        grouped: grouped,
                        lastInRun: messageItem.lastInRun,
                        showAvatarSlot: !room.isDm,
                        showAvatar: showAvatar,
                        senderName: senderName,
                        onOpenViewOnce: () => _openViewOnce(m),
                        // Offered only on the sender's own running share. A
                        // recipient has nothing to stop, and the bubble hides
                        // the control entirely rather than showing a disabled
                        // one — "you may not stop this" is not a thing anyone
                        // needs told about somebody else's location.
                        onStopLiveShare: isMine && m.isLiveLocationRunning(_now)
                            ? () => widget.repo.stopLiveLocation(messageId: m.id)
                            : null,
                        publishingLiveShare:
                            widget.repo.activeLiveShareMessageId == m.id,
                        onRetrySend: sendFailed ? onRetrySend : null,
                        onDiscardSend: sendFailed ? onDiscardSend : null,
                        album: messageItem.album,
                        // The block does not pulse when one of its pictures
                        // does. "One of these ten" is not the answer the trip
                        // was for — see [PhotoMosaic.highlightedPhotoId].
                        albumHighlightId: albumHighlightId,
                        albumHighlightT: highlightT,
                        // Pending-ness is per tile here, not per row: a block
                        // can be half landed, and the confirmed half has a
                        // menu even while the rest is still going up.
                        onAlbumTileLongPress: (target, anchor) {
                          if (target.id.startsWith('tmp_')) return;
                          longPressOn(target, anchorKey: anchor);
                        },
                        onAlbumReactionTap: reactionTapOn,
                        onAlbumReactionLongPress: reactionLongPressOn,
                        // Looked up only for the three types that can have one,
                        // so an ordinary transcript costs one enum comparison
                        // per row rather than a map probe.
                        interaction: m.type.isInteractive
                            ? widget.repo.interactionFor(room.id, m.id)
                            : null,
                        interactionActions: interactionActions,
                      );
                final row = AnimatedSwitcher(
                  duration: theme.motionMed,
                  switchInCurve: theme.motionEntrance,
                  // The two pulls share this bubble and share its gesture
                  // arena: reply toward the end edge, receipts toward the
                  // start. Each recognizer gives up inside the first few
                  // pixels of the other's direction, which is what lets both
                  // sit here without a combined widget that would have to
                  // re-tune the reply spring.
                  child: SwipeToReceipts(
                    key: ValueKey('rc_${m.id}'),
                    // Your own message, actually on the server, in a room
                    // that has someone else in it. Receipts on a send that
                    // hasn't landed would be a list of people who could not
                    // possibly have read it, and the selection bar owns the
                    // horizontal while it is up.
                    enabled: isMine &&
                        !isPending &&
                        !selecting &&
                        m.status == MessageStatus.sent &&
                        m.type != MessageType.system,
                    pageBuilder: (_) => MessageReceiptsScreen(
                      repo: widget.repo,
                      api: widget.api,
                      roomId: room.id,
                      messageId: m.id,
                      fallbackMessage: m,
                      currentUserId: me,
                      // Read through, not snapshotted: the roster is a live
                      // subscription and this screen outlives any one frame
                      // of it.
                      roster: () => _members.values.toList(),
                      onOpenProfile: _openProfile,
                    ),
                    child: SwipeToReply(
                      key: ValueKey('sw_${m.id}'),
                      // A swipe that armed a reply mid-selection would put a
                      // composer card under a bar that has no composer.
                      enabled: canReply && !selecting,
                      onReplyTriggered: () => _armReply(m, haptic: false),
                      child: bubble,
                    ),
                  ),
                );
                return _ArrivingRow(
                  // Only a message that was not on screen a moment ago plays
                  // an entrance; see [_noteArrivals]. Everything else — a row
                  // scrolled back into view, a page of older history, a
                  // re-render after a reaction — draws at full size on the
                  // first frame, as it always did.
                  key: ValueKey('arrive_${m.id}'),
                  animate: _arriving.contains(m.id),
                  duration: theme.motionMed,
                  curve: theme.motionEntrance,
                  child: _trackedDate(
                  stableId: 'm_${m.id}',
                  label: humanDay(DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day)),
                  isDivider: false,
                  child: selecting
                      ? _SelectableRow(
                          // An album is one thing on screen and is picked as
                          // one: any photograph of it selected marks the row,
                          // and the tap takes or drops the whole block. A set
                          // the reader can see but not select as a set is a
                          // forward that quietly sends four of five.
                          selected: messageItem.album.isEmpty
                              ? _selection.contains(m.id)
                              : messageItem.album
                                  .any((p) => _selection.contains(p.id)),
                          isMine: isMine,
                          onTap: () => messageItem.album.isEmpty
                              ? _toggleSelection(m)
                              : _toggleAlbumSelection(messageItem.album),
                          child: row,
                        )
                      : row,
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Back one hop up the reply trail. Above the jump-to-
                        // latest pill because it is the transient one: it comes
                        // and goes with the trail, while the pill below it is
                        // the fixture a reader always knows where to find.
                        TransientPillSlot(
                          visible: _jumpBack.isNotEmpty,
                          child: JumpBackPill(
                            depth: _jumpBack.depth,
                            onTap: _jumpBackOneHop,
                          ),
                        ),
                        // Unconditional: when the slot below is unmounted this
                        // just lifts the back pill 8px off the composer, which
                        // beats racing its fade-out to decide whether to render.
                        const SizedBox(height: 8),
                        // Two reasons to be here: scrolled away from the newest
                        // message, or parked on a detached slice of history
                        // where the bottom of the list isn't the present at
                        // all. Both want the same button, and _scrollToBottom
                        // already tells them apart.
                        ValueListenableBuilder<bool>(
                          valueListenable: _scrolledUp,
                          builder: (context, scrolledUp, _) =>
                              ScrollToLatestSlot(
                            visible: scrolledUp ||
                                widget.repo.inHistoryWindow(widget.roomId),
                            onTap: _onJumpToLatestTapped,
                          ),
                        ),
                      ],
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

/// A transcript row while multi-select is on: the bubble exactly where it was,
/// a check in the margin opposite it, and one tap target over both.
///
/// The check goes in the EMPTY half of the row — left of a sent bubble, right
/// of a received one — rather than in a leading gutter every row shares. A
/// gutter is what a settings list does, and it costs the one thing a transcript
/// cannot afford: turning selection on would shove the entire conversation
/// sideways, so the message you long-pressed is no longer where you left it.
/// Here nothing moves. The reserved width is smaller than the slack a bubble
/// already leaves at [ChatMetrics.bubbleFraction], so even a message at full
/// width holds its position.
///
/// Picked rows take the same treatment as a picked row in the forward-target
/// sheet — a soft accent plate under a hairline accent border, on the theme's
/// own radius and timing — because they are the same act. Unpicked rows keep
/// their empty ring: the surface has to say it is asking, not just answer for
/// the rows already chosen.
///
/// The bubble is wrapped in [IgnorePointer] rather than handed a different set
/// of callbacks. A message carries live gestures of its own — a video's play
/// button, a link, a reaction chip, the avatar — and selection mode has to mean
/// that a tap anywhere on the row picks it. Suppressing them at the boundary is
/// one place to be right about; rewiring each one is many.
class _SelectableRow extends StatelessWidget {
  const _SelectableRow({
    required this.selected,
    required this.isMine,
    required this.onTap,
    required this.child,
  });

  final bool selected;

  /// Which side the bubble hugs, and so which margin is free for the check.
  final bool isMine;
  final VoidCallback onTap;
  final Widget child;

  /// Width given to the check and its breathing room.
  static const double _gutter = 30;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: selected
          ? l10n.roomScreenDeselectMessageSemantic
          : l10n.roomScreenSelectMessageSemantic,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: theme.motionFast,
          curve: theme.motionEntrance,
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            color: selected
                ? theme.accent.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
            border: Border.all(
              color: selected
                  ? theme.accent.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: isMine ? _gutter : 0,
                  right: isMine ? 0 : _gutter,
                ),
                child: IgnorePointer(child: child),
              ),
              // Centred on the row's own height, so it reads as a mark against
              // the whole message rather than something pinned to its first
              // line — which is what a tall photo would otherwise look like.
              Positioned(
                top: 0,
                bottom: 0,
                left: isMine ? 0 : null,
                right: isMine ? null : 0,
                width: _gutter,
                child: Center(child: SelectionCheck(picked: selected)),
              ),
            ],
          ),
        ),
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
    required this.caps,
    this.dmUser,
    this.onTapDmUser,
  });
  final ChatRoom room;
  final List<ChatUser> typing;
  final VoidCallback onOpenInfo;
  final ChatUser? dmUser;
  final ChatApi api;
  final RoomCapabilities caps;
  final VoidCallback? onTapDmUser;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // A profile that offers a friend request the bot will refuse and a call it
    // cannot take is a dead end; leave the row inert instead.
    final onTapPeer = caps.canOpenPeerProfile ? onTapDmUser : null;
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
          if (room.isSavedMessages) ...[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: theme.accentSoft, shape: BoxShape.circle),
              child: Icon(CupertinoIcons.bookmark_fill, size: 16, color: theme.accent),
            ),
            const SizedBox(width: 10),
          ] else if (dmUser != null) ...[
            GestureDetector(
              onTap: onTapPeer,
              child: UserAvatar(user: dmUser!, size: 32, api: api),
            ),
            const SizedBox(width: 10),
          ] else ...[
            _RoomAvatar(room: room, api: api, size: 32),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: GestureDetector(
              // Matches the liquid header's title capsule: a tap opens Room
              // Info regardless of DM or group. The peer's own profile is
              // still one tap away from there, and from the avatar beside
              // this title, which keeps its dedicated `onTapPeer`.
              onTap: onOpenInfo,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.isSavedMessages
                        ? AppLocalizations.of(context).savedMessagesTitle
                        : (dmUser?.displayName ?? room.name),
                    style: theme.displayMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // Two different lines, asked for separately: a DM names
                      // the person (`@handle` is what tells two people called
                      // "Sam" apart), a group counts them. A chat with only
                      // yourself, or with the app itself, says neither.
                      if (caps.hasPeerHandle && dmUser != null)
                        Text('@${dmUser!.username}', style: theme.monoTiny.copyWith(color: theme.inkMuted))
                      else if (caps.hasMembers) ...[
                        VisibilityBadge(isPublic: room.isPublic, dense: true),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: theme.chipDecoration(),
                          child: Text(
                            AppLocalizations.of(context)
                                .roomScreenMemberCountBadge(room.memberCount),
                            style: theme.monoTiny,
                          ),
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
                            typingLabel(context, typing),
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
          // Nobody to call in a chat with only yourself, and nobody home in a
          // chat with the app — `calls.ts` refuses a system account outright,
          // so a button here would ring nothing.
          if (!caps.canCall)
            const SizedBox.shrink()
          else if (room.isDm && dmUser != null)
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

String _fmtTtl(BuildContext context, Duration d) {
  final l10n = AppLocalizations.of(context);
  if (d.inSeconds < 60) return l10n.roomScreenTtlSeconds(d.inSeconds);
  if (d.inMinutes < 60) return l10n.roomScreenTtlMinutes(d.inMinutes);
  return l10n.roomScreenTtlHours(d.inHours);
}

class _RoomIntro extends StatelessWidget {
  const _RoomIntro({
    required this.room,
    required this.members,
    required this.api,
    required this.caps,
  });
  final ChatRoom room;
  final List<ChatUser> members;
  final ChatApi api;
  final RoomCapabilities caps;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final showDescription = caps.hasDescription &&
        room.description != null &&
        room.description!.isNotEmpty;
    final showEphemeral = room.isEphemeral && room.messageLifetime != null;
    final showMembers = caps.hasMembers && members.isNotEmpty;
    // A DM, Saved Messages or a bot room has nothing here worth a card for —
    // no description, no member list, nothing but empty padding floating
    // above the first message. `caps` already zeroes hasDescription/hasMembers
    // for all three, so once ephemeral is also off there is nothing left to
    // show, and a DM with no expiry now opens straight onto the transcript.
    if (!showDescription && !showEphemeral && !showMembers) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: MessageGap.aroundMarker),
      padding: const EdgeInsets.all(18),
      decoration: theme.roomCardDecoration(ephemeral: room.isEphemeral, active: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDescription) ...[
            Text('"${room.description!.toLowerCase()}"', style: theme.bodyEmph),
            const SizedBox(height: 14),
          ],
          if (showEphemeral) ...[
            Row(
              children: [
                theme.hourglassIcon(size: 14, color: theme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).roomScreenEphemeralNotice(
                      _fmtTtl(context, room.messageLifetime!),
                    ),
                    style: theme.caption.copyWith(color: theme.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          // A face stack of "you", or of you and a bot, is decoration standing
          // where information should be.
          if (showMembers)
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
      // A fold sits inside a run of thread messages, so it takes the run's own
      // gap. Top only — see [MessageGap].
      padding: const EdgeInsets.fromLTRB(36, MessageGap.withinRun, 0, 0),
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
                  AppLocalizations.of(context)
                      .roomScreenThreadFoldCount(fold.count),
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

/// The icon + label row a date marker renders, inline or floating — the one
/// place to touch to change what a date marker looks like everywhere at once.
class _DateChipContent extends StatelessWidget {
  const _DateChipContent({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(CupertinoIcons.calendar, size: 11, color: theme.accent),
        const SizedBox(width: 6),
        Text(label, style: theme.monoTiny.copyWith(letterSpacing: 1.8)),
      ],
    );
  }
}

/// The decoration a date marker's pill sits on, shared by the inline divider
/// and the floating chip so the two read as the same object, not a hard cut
/// between "a line with text on it" and "a glass pill" mid-scroll.
BoxDecoration _dateChipDecoration(AppTheme theme, {List<BoxShadow>? shadow}) =>
    BoxDecoration(
      color: theme.accentSoft,
      border: Border.all(color: theme.divider, width: 1),
      borderRadius: BorderRadius.circular(999),
      boxShadow: shadow,
    );

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      // Top only — see [MessageGap]. The air below a divider is the following
      // message's own gap, which is the same number.
      padding: const EdgeInsets.only(top: MessageGap.aroundMarker),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: _dateChipDecoration(theme),
          child: _DateChipContent(label: label),
        ),
      ),
    );
  }
}

/// Marks where a reader's backlog starts — a full-width band rather than a
/// centred pill, deliberately: a pill reads as a date marker in this app (see
/// `_ThreadFoldChip`'s own note on the same rule), and this is answering a
/// different question — not "what day is it" but "everything below this line
/// is new". [_RoomScreenState._maybeLandOnUnread] is what puts it on screen
/// on open; this widget only draws it.
class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      // Top only — see [MessageGap], same convention _DateDivider follows.
      padding: const EdgeInsets.only(top: MessageGap.aroundMarker),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: theme.accentSoft,
          border: Border.symmetric(
            horizontal: BorderSide(color: theme.accent.withValues(alpha: 0.35)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          AppLocalizations.of(context).roomScreenUnreadDivider,
          style: theme.monoTiny.copyWith(
            color: theme.accent,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
          ),
        ),
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
          decoration: _dateChipDecoration(theme, shadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]),
          child: _DateChipContent(label: label),
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
                    AppLocalizations.of(context).roomScreenSecretSpaceTitle,
                    style: theme.displayMedium.copyWith(color: theme.ink, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context).roomScreenSecretSpaceBody,
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
                            title: AppLocalizations.of(context).roomScreenAutoDeleteTitle,
                            subtitle: ttl != null
                                ? AppLocalizations.of(context).roomScreenAutoDeleteVaries
                                : AppLocalizations.of(context).roomScreenAutoDeleteTimed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PrivateFeatureCard(
                            icon: CupertinoIcons.hand_raised_fill,
                            title: AppLocalizations.of(context).roomScreenNoCaptureTitle,
                            subtitle: AppLocalizations.of(context).roomScreenNoCaptureSubtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PrivateFeatureCard(
                    icon: CupertinoIcons.lock_fill,
                    title: AppLocalizations.of(context).roomScreenMorePrivacyTitle,
                    subtitle: AppLocalizations.of(context).roomScreenMorePrivacySubtitle,
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
          Text(
            AppLocalizations.of(context).roomScreenNoMessagesTitle,
            style: theme.bodyEmph.copyWith(color: theme.inkSoft),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context).roomScreenNoMessagesSubtitle,
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
    required this.caps,
    this.dmUser,
  });
  final ChatRoom room;
  final ChatApi api;
  final VoidCallback onOpenInfo;
  final RoomCapabilities caps;
  final ChatUser? dmUser;

  @override
  State<_LiquidHeader> createState() => _LiquidHeaderState();
}

class _LiquidHeaderState extends State<_LiquidHeader> {
  /// Avatar diameter inside the title capsule.
  static const _avatarSize = 32.0;

  bool _expanded = false;
  Timer? _collapseTimer;

  /// Whether the title renders on one line at the width it currently has.
  ///
  /// Assigned during layout rather than through setState: nothing in the tree
  /// depends on it, only [_handleTitleTap] reads it, so a setState here would be
  /// a rebuild loop that changes no pixels.
  bool _titleFits = true;

  void _expandTitle() {
    setState(() => _expanded = true);
    _collapseTimer?.cancel();
    _collapseTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _expanded = false);
    });
  }

  /// Expanding is only worth a tap when there is something hidden to reveal, and
  /// only once — a second tap means "I've read it, now let me in".
  void _handleTitleTap() {
    if (!_titleFits && !_expanded) {
      _expandTitle();
      return;
    }
    _collapseTimer?.cancel();
    // Collapse on the way out, so coming back from room info doesn't land on a
    // chip still wrapped from a tap two screens ago.
    setState(() => _expanded = false);
    widget.onOpenInfo();
  }

  /// Storage id of the picture behind the capsule's avatar, or null when it is a
  /// gradient-initials or `#` placeholder. Null means no fullscreen route and no
  /// [Hero] — a tag with no counterpart is worse than no tag.
  String? get _avatarStorageId {
    // Which picture the capsule shows follows dmUser, so which picture opens has
    // to follow it too. A `??` chain here would fall back to the room's avatar
    // for a peer who has none, flying someone else's image out of a gradient
    // placeholder.
    final id = widget.dmUser != null
        ? widget.dmUser!.avatarStorageId
        : widget.room.avatarStorageId;
    return (id == null || id.isEmpty) ? null : id;
  }

  void _openAvatarFullscreen() {
    final storageId = _avatarStorageId;
    if (storageId == null) return;
    FullscreenImageViewer.openAvatar(
      context,
      storageId: storageId,
      api: widget.api,
      // Room-keyed: unique inside this route, and deliberately distinct from
      // ProfileScreen's 'profile-avatar-$id' so a push can't collide.
      heroTag: 'room-header-avatar-${widget.room.id}',
      sourceSize: _avatarSize,
    );
  }

  /// The capsule's avatar, wrapped in its own tap target when there is a real
  /// picture behind it.
  ///
  /// The nesting is the point: the inner recognizer enters the gesture arena
  /// first (hit testing runs child-first), so it beats the capsule's opaque
  /// GestureDetector. With no picture nothing is mounted, and the tap falls
  /// through to [_handleTitleTap] — a placeholder shouldn't swallow the chip.
  Widget _buildAvatar() {
    final Widget avatar = widget.room.isSavedMessages
        ? Container(
            width: _avatarSize,
            height: _avatarSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ThemeScope.of(context).accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.bookmark_fill,
              size: _avatarSize * 0.45,
              color: ThemeScope.of(context).accent,
            ),
          )
        : widget.dmUser != null
        ? UserAvatar(user: widget.dmUser!, size: _avatarSize, api: widget.api)
        : _RoomAvatar(room: widget.room, api: widget.api, size: _avatarSize);
    if (_avatarStorageId == null) return avatar;
    return FocusableTap(
      onTap: _openAvatarFullscreen,
      shape: FocusRingShape.circle,
      semanticLabel: widget.dmUser != null
          ? AppLocalizations.of(context).roomScreenViewProfilePictureSemantic
          : AppLocalizations.of(context).roomScreenViewRoomPictureSemantic,
      child: GestureDetector(
        onTap: _openAvatarFullscreen,
        child: SteadyHero(
          tag: 'room-header-avatar-${widget.room.id}',
          child: avatar,
        ),
      ),
    );
  }

  /// True when [title] needs more than one line at [maxWidth].
  bool _overflows(String title, TextStyle style, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final title = widget.room.isSavedMessages
        ? AppLocalizations.of(context).savedMessagesTitle
        : (widget.dmUser?.displayName ?? widget.room.name);
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
                onTap: _handleTitleTap,
                child: AnimatedSize(
                  duration: theme.motionMed,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildAvatar(),
                      const SizedBox(width: 8),
                      Flexible(
                        // maxWidth here is exactly the width the title has — the
                        // Row is mainAxisSize.min, so the avatar and its gap are
                        // already subtracted. Measuring against it beats
                        // re-deriving the capsule's padding by hand.
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final style = theme.body
                                .copyWith(fontWeight: FontWeight.w600, color: theme.ink);
                            // Always measured at one line, whatever the current
                            // expansion state: the question is whether expanding
                            // would reveal anything.
                            _titleFits =
                                !_overflows(title, style, constraints.maxWidth);
                            return Text(
                              title,
                              style: style,
                              overflow:
                                  _expanded ? TextOverflow.fade : TextOverflow.ellipsis,
                              softWrap: _expanded,
                              maxLines: _expanded ? 3 : 1,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // See the classic header: no one to call in a chat with only
          // yourself, and no one home in a chat with the app.
          if (!widget.caps.canCall) ...[
            const SizedBox.shrink(),
          ] else if (widget.room.isDm && widget.dmUser != null) ...[
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


/// Grows a newly-arrived transcript row into place instead of snapping it in.
///
/// Before this the list had no insertion animation of any kind — the only
/// animated thing touching a row was an `AnimatedSwitcher` keyed on the message
/// id, which by construction animates content changing *within* a row and never
/// the row appearing. So a message that landed while you were reading simply
/// blinked into existence and shoved the transcript, which is the "it just
/// jumps" half of feeling slow.
///
/// Under the list's `reverse: true` an arrival is index 0 — the bottom — so
/// growing its height from zero reads as the bubble rising into place, and the
/// rows above it are pushed by exactly the amount they were going to move
/// anyway, over 200ms instead of over one frame.
///
/// [animate] is false for every row that is merely being built — scrolled back
/// into view, rebuilt after a reaction, part of a page of older history — and
/// those return the child untouched, allocating nothing.
class _ArrivingRow extends StatefulWidget {
  const _ArrivingRow({
    super.key,
    required this.animate,
    required this.duration,
    required this.curve,
    required this.child,
  });

  final bool animate;
  final Duration duration;
  final Curve curve;
  final Widget child;

  @override
  State<_ArrivingRow> createState() => _ArrivingRowState();
}

class _ArrivingRowState extends State<_ArrivingRow>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _ctrl = AnimationController(vsync: this, duration: widget.duration)
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    // Nothing to play, or it has finished: hand back the child itself so a
    // settled transcript carries no extra layout or opacity layer per row.
    if (ctrl == null || ctrl.isCompleted) return widget.child;
    final t = CurvedAnimation(parent: ctrl, curve: widget.curve);
    return AnimatedBuilder(
      animation: t,
      // Built once and reused across every frame of the animation — the row
      // beneath is the expensive part and none of it depends on `t`.
      child: widget.child,
      builder: (context, child) => Align(
        alignment: Alignment.topCenter,
        heightFactor: t.value,
        child: Opacity(opacity: t.value, child: child),
      ),
    );
  }
}
