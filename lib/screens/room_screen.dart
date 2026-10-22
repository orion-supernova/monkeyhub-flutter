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
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../backend/group_call_api.dart';
import '../calls/call_button.dart';
import '../chat_games/active_games_banner.dart';
import '../chat_games/game_start_sheet.dart';
import '../data/matches_store.dart';
import '../backend/matches_api.dart';
import 'games/match_screen.dart';
import '../calls/call_models.dart';
import '../calls/group_call_banner.dart';
import '../calls/group_call_button.dart';
import '../calls/group_call_service.dart';
import '../data/chat_repository.dart';
import '../data/room_suggestion_queue.dart';
import '../diagnostics/diag_log.dart';
import '../drop/drop_channel.dart';
import '../drop/drop_classifier.dart';
import '../drop/drop_controller.dart';
import '../drop/drop_copy.dart';
import '../drop/drop_intake.dart';
import '../drop/drop_item.dart';
import '../drop/drop_zone.dart';
import '../data/mention_session.dart';
import '../data/room_content_selection.dart';
import '../companions/companion.dart';
import '../companions/sebastian.dart';
import '../data/settings_store.dart';
import '../data/spoiler_store.dart';
import '../family/family_service.dart';
import '../keyboard/app_shortcuts.dart';
import '../keyboard/dismiss_keyboard_on_tap.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/file_meta.dart';
import '../media/native_gallery.dart';
import '../media/native_video_player.dart';
import '../media/video_poster.dart';
import '../media/video_shrink.dart';
import '../media/image_raster.dart';
import '../widgets/gallery_tray.dart' show GalleryTray;
import '../widgets/inline_photo_picker.dart';
import '../media/photo_picking.dart';
import '../media/view_once_fetch.dart';
import '../media/view_once_media.dart';
import '../privacy/app_only.dart';
import '../privacy/capture_protection.dart';
import '../services/live_location_permission.dart';
import '../services/live_location_platform.dart';
import '../services/live_share_resume_store.dart';
import '../services/location_service.dart';
import '../models/chat_match.dart';
import '../models/chat_message.dart';
import '../models/message_capabilities.dart';
import '../models/message_formatting.dart';
import '../models/location_share.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/family.dart';
import '../models/room_capabilities.dart';
import '../models/room_posting_policy.dart';
import '../models/room_content_item.dart';
import '../models/room_pin.dart';
import '../models/reaction_limits.dart';
import '../data/ui_selection_store.dart';
import '../platform.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../widgets/app_toast.dart';
import '../widgets/sheet_kit.dart' show IosSheetAction, showIosActionSheet;
import 'message_receipts_screen.dart';
import 'room_items.dart';
import 'view_once_viewer.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import '../widgets/anchored_scroll.dart';
import '../widgets/approval_gate.dart';
import '../widgets/attachment_menu.dart';
import '../widgets/read_only_composer_footer.dart';
import '../widgets/bulk_action_bar.dart';
import '../widgets/busy_scrim.dart';
import '../widgets/chat_bottom_inset.dart';
import '../composer/capture_machine.dart';
import '../composer/capture_recorder.dart';
import '../widgets/chat_composer.dart';
import '../widgets/composer_capture.dart';
import '../widgets/chat_pane.dart';
import '../widgets/destructive_sheet.dart' show showConfirmSheet;
import '../widgets/edge_bleed.dart';
import '../widgets/forward_target_sheet.dart';
import '../widgets/glass_pill.dart';
import '../widgets/jump_back.dart';
import '../widgets/timeline_list_view.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/location_share_sheet.dart';
import '../widgets/composer_edit_card.dart';
import '../widgets/composer_reply_card.dart';
import '../widgets/mention_picker.dart';
import '../widgets/photo_deck.dart';
import '../widgets/photo_mosaic.dart' show MosaicTile, mosaicHeroTag;
import '../widgets/companion_strip.dart' show kCompanionStripHeight;
import '../widgets/pinned_banner.dart';
import '../widgets/room_change_requests_sheet.dart';
import '../widgets/room_suggestions_banner.dart';
import '../widgets/pinned_list_sheet.dart';
import '../widgets/mention_text_controller.dart';
import '../widgets/departing_row.dart';
import '../widgets/message_arrivals.dart';
import '../widgets/message_deletions.dart';
import '../widgets/message_departures.dart';
import '../widgets/message_bubble.dart';
import '../widgets/reaction_details_sheet.dart';
import '../widgets/reaction_limit_notice.dart';
import '../widgets/reaction_picker_sheet.dart';
import '../widgets/pending_placeholder.dart';
import '../widgets/schedule_message_sheet.dart';
import '../widgets/scheduled_list_sheet.dart';
import '../widgets/scheduled_pill.dart';
import '../widgets/scroll_to_latest.dart';
import '../widgets/selection_check.dart';
import '../widgets/skeleton_rows.dart';
import '../widgets/speaker_scope.dart';
import '../widgets/chat_list_row.dart' show MonogramAvatar, monogramGradient;
import '../widgets/typing_indicator.dart';
import '../widgets/remote_image.dart';
import '../widgets/room_gallery_scope.dart';
import '../widgets/video_note_message.dart' show VideoNoteRef;
import '../widgets/steady_hero.dart';
import '../widgets/swipe_to_receipts.dart';
import '../widgets/swipe_to_reply.dart';
import '../widgets/thread_overlay.dart';
import '../widgets/user_avatar.dart';
import '../widgets/interaction_bubble.dart' show InteractionActions;
import '../widgets/interaction_respondents_sheet.dart';
import '../widgets/companion_install_sheet.dart';
import '../widgets/message_action_menu.dart';
import '../widgets/message_context_menu.dart';
import '../widgets/message_hover_actions.dart';
import '../widgets/room_translate_bar.dart';
import '../widgets/moderation_actions.dart';
import '../widgets/report_sheet.dart';
import '../share/share_intake.dart';
import '../share/share_targets.dart';
import '../share/shared_payload.dart';
import 'camera_editor_screen.dart';
import 'interaction_compose_sheet.dart';
import 'camera_screen.dart';
import '../expressions/expression_store.dart';
import '../models/expression_item.dart';
import '../widgets/expressions/expression_panel.dart';
import '../widgets/expressions/sticker_maker.dart';
import '../widgets/expressions/sticker_suggestions.dart';
import '../widgets/ios_kit.dart'
    show
        GlassBackButton,
        groupedMetaStyle,
        groupedSubtitleStyle,
        groupedTitleStyle,
        quietFill;
import 'room_content_actions.dart';
import 'fullscreen_image_viewer.dart';
import 'media_pager_screen.dart';
import 'profile_screen.dart';
import 'room_info_screen.dart';
import 'navigation/room_side_pane.dart';
import 'voice_recorder_screen.dart';

/// Back affordance shared by both room headers. In the desktop two-pane layout
/// the room lives in the chat detail pane (never a full-screen route), so
/// "back" clears the pane selection; on compact it pops the pushed route.
void _roomBack(BuildContext context) {
  if (context.usesSplitShell) {
    UiSelectionStore.instance.selectRoom(null);
  } else {
    Navigator.of(context).maybePop();
  }
}

class RoomScreen extends StatelessWidget {
  const RoomScreen({
    super.key,
    required this.roomId,
    required this.repo,
    required this.api,
    this.inShellPane = false,
  });
  final String roomId;
  final ChatRepository repo;
  final ChatApi api;

  /// Shown in the wide shell's detail pane rather than pushed. Back (and Esc)
  /// then ends by closing the pane instead of popping a route, and that is
  /// decided HERE rather than by a second PopScope in the shell: two scopes
  /// on one route both hear every back, so one Esc used to cancel a selection
  /// and close the chat in the same keystroke.
  final bool inShellPane;

  @override
  Widget build(BuildContext context) {
    final view = _RoomView(
      roomId: roomId,
      repo: repo,
      api: api,
      inShellPane: inShellPane,
    );
    // Every app blocks capture, so a secret room is simply the room.
    if (!AppOnly.gatesCapture) return view;
    // The browser and Linux can't, so a secret room does not open there. The
    // room is not mounted until its type is known: mounting it to find out
    // would fetch the very messages this keeps off the device. `view` is the
    // builder's child, so a repo notification rebuilds only this decision.
    return ListenableBuilder(
      listenable: repo,
      child: view,
      builder: (context, view) {
        final room = repo.roomById(roomId);
        if (room == null) return _roomPending(context, repo);
        if (room.isEphemeral) {
          return SecretRoomGate(room: room, inShellPane: inShellPane);
        }
        return view!;
      },
    );
  }
}

/// A room that is not in the list: not arrived yet, or gone.
Widget _roomPending(BuildContext context, ChatRepository repo) {
  final theme = ThemeScope.of(context);
  // Two different things used to come out of this branch as one sentence.
  // A room that has been deleted is not in the list; neither is a room the
  // list has not arrived for yet — and telling somebody their conversation
  // is gone because their phone has not finished waking up is the worse of
  // the two mistakes by a long way.
  //
  // The notification tap is where it showed. `_openRoomFromPush` waits for
  // the session and the navigator and nothing else (see `app.dart`), and
  // `_bootstrap` deliberately mounts the UI early "in <150ms from local
  // cache" — so this screen is built, scans a `_rooms` that is still empty,
  // and prints an epitaph for the conversation the reader just tapped a
  // notification from. A list tap never showed it: you cannot tap a row
  // that is not in the list.
  //
  // Gated on the STRONG flag, not `roomsLoaded`, and that is the whole
  // point rather than caution. `roomsLoaded` is satisfied by the disk
  // snapshot, and the sharpest case here — a group somebody added you to
  // an hour ago, a first DM — is exactly a room that snapshot cannot
  // contain. See [ChatRepository.hasLiveRoomList].
  return Scaffold(
    backgroundColor: theme.background,
    body: PendingPlaceholder(
      pending: !repo.hasLiveRoomList,
      // The transcript's own silhouette, for the reason the empty-room
      // branch further down gives: it says "your conversation is coming,
      // and it will be about here" rather than "something is happening",
      // and it occupies the space the answer will, so the screen settles
      // once instead of jumping.
      loading: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: SkeletonBubbles(),
      ),
      // Reached either because the server's list genuinely does not have
      // this room, or because `PendingPlaceholder` gave up waiting — which
      // is the offline case, and which it is right to end on rather than
      // shimmer forever. See its own doc for that bargain.
      empty: (context) => Center(
        child: Text(
          AppLocalizations.of(context).roomScreenRoomGone,
          style: theme.bodySoft,
        ),
      ),
    ),
  );
}

class _RoomView extends StatefulWidget {
  const _RoomView({
    required this.roomId,
    required this.repo,
    required this.api,
    required this.inShellPane,
  });
  final String roomId;
  final ChatRepository repo;
  final ChatApi api;
  final bool inShellPane;

  @override
  State<_RoomView> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<_RoomView>
    with TickerProviderStateMixin {
  late Timer _ticker;

  /// The 1Hz clock: relative timestamps, and whether a live share is still
  /// running. Screen state, because those two decide what the screen BUILDS.
  DateTime _now = DateTime.now();

  /// The 5Hz clock, and only in a Chamber-of-Secrets room: the dissolve on a
  /// fading bubble is the one reader that wants sub-second resolution.
  ///
  /// A notifier rather than more state, so the fast tick repaints the fading
  /// bubbles subscribed to it (see [EphemeralMessageBubble.now]) instead of
  /// rebuilding the whole transcript around them four extra times a second.
  final ValueNotifier<DateTime> _fadeNow = ValueNotifier(DateTime.now());
  final MentionTextController _composer = MentionTextController();
  final FocusNode _composerFocus = FocusNode();

  /// On the composer's "+", so the attachment menu grows out of it. One key
  /// for both composers: only one of them is ever built.
  final GlobalKey _attachKey = GlobalKey(debugLabel: 'composer.attach');

  /// The attachment menu is up, which hides the "+" it grew out of.
  bool _attachMenuUp = false;

  /// The inline photo picker: its grid in the keyboard's place, and what has
  /// been picked, waiting over the composer until it is sent. Phones only;
  /// see [InlinePhotoPicker.supported].
  late final InlinePickerController _picker = InlinePickerController()
    ..addListener(_onPickerChanged);

  void _onPickerChanged() {
    if (mounted) setState(() {});
  }

  /// Mends the composer's focus when the app comes back — see
  /// [_restoreComposerFocus].
  AppLifecycleListener? _lifecycle;

  /// The emoji/GIF/sticker panel, which trades places with the keyboard — see
  /// [ExpressionPanelController].
  final ExpressionPanelController _expressions = ExpressionPanelController();

  /// The transcript's one hover strip — see [MessageHoverController]. Made on
  /// every platform (it is a few fields), but only handed to the bubbles on a
  /// pointer platform, so a phone's bubbles never even get a MouseRegion.
  final MessageHoverController _hover = MessageHoverController();

  /// This room's claim on the browser's `paste` event. See [_onPastedBundle].
  Object? _pasteToken;
  late final MentionSession _mention;
  final ScrollController _scroll = ScrollController();
  // Whether the transcript is parked away from the newest message. Kept in a
  // notifier rather than a field: _onScroll runs on every scroll frame and this
  // screen rebuilds at 5Hz off _ticker already, so a setState here would make
  // the whole transcript pay for a pill.
  final BottomProximity _scrolledUp = BottomProximity();

  /// The room the liquid style's floating bottom chrome is taking, measured
  /// rather than assumed — see `chat_bottom_inset.dart`.
  ///
  /// Null until the chrome has been laid out once, which is the whole reason
  /// [ChatBottomChrome] carries an estimate alongside it. A listenable, not a
  /// field, for the reason [_scrolledUp] above is one: the composer gains a
  /// line several times per message, and the transcript must move for it
  /// WITHOUT every bubble in the viewport being rebuilt.
  final ChatBottomInset _bottomChrome = ChatBottomInset();

  /// id → user, for sender names, avatars and speaker colours.
  ///
  /// A local index over `repo.membersFor(roomId)` rather than a roster of its
  /// own. The subscription that used to fill this lives on the repository now,
  /// which is what lets a room the reader has opened before paint its senders
  /// from disk on the first frame instead of in theme ink — see
  /// `ChatRepository._roomMembers`. Kept as a MAP because the read path is a
  /// per-bubble lookup by sender id and the repository's list is not.
  final Map<String, ChatUser> _members = {};

  /// The exact list instance [_members] was last built from.
  ///
  /// Identity is a complete change signal here, and free: the repository only
  /// replaces its roster list when the content actually changed (it holds the
  /// signature dedup that both screens used to keep separately), so an
  /// unchanged roster hands back the same instance on every one of the
  /// notifications a live conversation produces.
  List<ChatUser>? _rosterSource;

  /// Which colour each member speaks in, recomputed only when the roster
  /// itself changes — the assignment is a sort plus a walk, and doing it per
  /// build would redo it on every keyboard frame. [_rosterSource] already gates
  /// the roster rebuild, so this rides along on the one signal that matters.
  SpeakerSlots _speakerSlots = SpeakerSlots.none;

  /// Signature of this reader's manual colour pins for the room, so the
  /// assignment is rebuilt when a pin changes and not on every one of the
  /// repository notifications that arrive while a conversation is live.
  String _speakerPinsSig = '';
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
  final _datePresentation = ValueNotifier<({String? label, bool active, double overlap})>(
    (label: null, active: false, overlap: 0),
  );
  Timer? _hideTimer;
  // Set during build; used by _recomputePositionState to know where the
  // chip "lives" so it can compute overlap with divider RenderBoxes.
  double _chipRestingY = 16;

  // ──── attachment state ────
  // Guards the whole attach flow against a second tap. Spans the attachment
  // sheet, the picker and the camera screen, none of which used to be guarded at
  // all — a double-tap on `+` opened two sheets and then two pickers, and the
  // second one's result overwrote the first's.
  bool _attachInFlight = false;

  /// Whether this room has a game open, so the floating header can reserve
  /// the games banner's height. Flipped only on a change, from [_onGames].
  bool _gamesOpen = false;
  bool _watchingGames = false;

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

  /// Set when [_replyingTo] is an album's first message and the reply is to
  /// the whole album: which message that was, and how many items. Keyed to
  /// the message rather than cleared alongside it, so every one of the many
  /// places that clears or replaces [_replyingTo] also drops this for free.
  String? _replyAlbumFor;
  int _replyAlbumCount = 0;

  /// The album count of the reply being written, or null for an ordinary
  /// reply (or none). See [_replyAlbumFor].
  int? get _replyAlbum =>
      _replyingTo != null && _replyingTo!.id == _replyAlbumFor
          ? _replyAlbumCount
          : null;

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
  // The reader's cursor lives in the repository, which pins it before anything
  // can advance it and is allowed to answer a beat late — see
  // [ChatRepository.beginUnreadAnchor]. Asked for rather than copied into a
  // field here, so a screen that mounted ahead of its room list (a
  // notification tap, cold or warm) picks the answer up when it lands instead
  // of being stuck with the "don't know" it was born with.
  //
  // What this screen owns is the row that cursor resolves to: the message the
  // UNREAD MESSAGES line sits above and the opening scroll aims at, settled
  // once and then held. See [_settleUnreadDivider].
  String? _unreadDividerId;
  bool _unreadDividerSettled = false;

  /// The UNREAD MESSAGES row itself, so the opening scroll can aim at the line
  /// rather than at the message under it. Only ever one such row.
  final GlobalKey _unreadDividerKey = GlobalKey(debugLabel: 'unread-divider');

  /// What floats over the transcript's top and bottom edges, as the last build
  /// laid it out — the band the landing centres the divider in. Both zero in
  /// the classic style, whose header and composer sit outside the viewport.
  double _topChromeOverList = 0;
  double _bottomChromeOverList = 0;

  // True from mount until the initial landing has either succeeded or been
  // given up on — guards against re-triggering on a later notification (a
  // reaction, a typing update) once the reader has already scrolled off on
  // their own.
  bool _unreadLandingPending = false;

  // How long the landing may keep waiting for a cursor that has not arrived.
  // The divider itself has no deadline — a label appearing late is harmless —
  // but a viewport that jumps on its own half a minute after the room opened
  // is not, so the scroll half gives up here and leaves the reader where they
  // are. Generous because the wait it is bounding is a cold start's room list
  // on a bad connection, which is the case the whole feature exists for.
  static const Duration _kUnreadLandingWindow = Duration(seconds: 12);
  DateTime? _unreadLandingDeadline;

  /// Which pin the banner is describing, counted back from the newest — see
  /// [pinIndexForCursor], which is the only way it is read. 0 is the latest
  /// pin, so that is what a room opens on.
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
    // A play-once note staged for a player that never got to release it — the
    // process died mid-listen — is still on disk. Gone before this room can
    // show anything.
    unawaited(ViewOnceMedia.sweep());
    // The room's games: the cards' bodies and the banner. Held for exactly
    // as long as this screen is, like the room's other secondary queries.
    final me = widget.repo.userId;
    if (me != null) {
      _watchingGames = true;
      MatchesStore.instance.watchRoom(me, widget.roomId);
      MatchesStore.instance.addListener(_onGames);
    }
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
    // The panel is a conditional child of the composer column, like the
    // picker above; and focusing the field (a tap, a shortcut, a reply swipe)
    // is the keyboard coming back, which puts the panel away.
    _expressions.addListener(_onExpressionsChanged);
    _composerFocus.addListener(_onComposerFocusChanged);
    if (!isPhysicalKeyboardPlatform) {
      _lifecycle = AppLifecycleListener(onResume: _restoreComposerFocus);
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted) return;
      final now = DateTime.now();
      // The fast half: 5Hz, and only where something is actually fading. This
      // is a notifier, so it repaints the bubbles listening to it and nothing
      // else — it does NOT rebuild the screen.
      if (_room?.messageLifetime != null) _fadeNow.value = now;
      // Ordinary saved text, photos and past events do not change each second.
      // Location/countdown widgets own their clocks. Rebuild this screen only
      // when a time boundary changes a row's actions or an event's past state.
      if (t.tick % 5 != 0) return;
      final previous = _now;
      _now = now;
      final dayChanged = previous.year != now.year ||
          previous.month != now.month || previous.day != now.day;
      final rowChanged = _lastTimeline.any((m) {
        if (m.type == MessageType.liveLocation) {
          return m.isLiveLocationRunning(previous) != m.isLiveLocationRunning(now);
        }
        if (m.type == MessageType.event) {
          final start = widget.repo.interactionFor(widget.roomId, m.id)?.startsAt;
          return start != null && start.isBefore(previous) != start.isBefore(now);
        }
        return false;
      });
      if (dayChanged || rowChanged) setState(() {});
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
    // Before openRoom below, which marks the room read and — once the
    // mutation's round trip echoes back through rooms:listUserRooms — moves
    // lastReadAt out from under a cursor taken any later. The repository pins
    // it from here and answers when it can; see [beginUnreadAnchor].
    //
    // Armed unconditionally, unlike the `unreadCount > 0` snapshot this
    // replaces. That gate was read off whatever room list happened to be in
    // memory, and on both notification-tap paths that list has not caught up
    // with the push that caused the open: a cold start has no list at all, and
    // a warm one holds the counts as they were before the app went away. It
    // therefore answered "nothing unread" on exactly the two entries this
    // feature exists for, which is why the divider only ever showed up off a
    // chat-list tap. [_maybeLandOnUnread] decides from the transcript instead,
    // which cannot be stale in that way.
    widget.repo.beginUnreadAnchor(widget.roomId);
    _unreadLandingPending = true;
    _unreadLandingDeadline = DateTime.now().add(_kUnreadLandingWindow);
    // "Somebody suggested a new group photo", tapped. The push routed the tap
    // into this room by its roomId; this is the last hop, and it has to happen
    // from HERE because Room Info is pushed onto this screen's navigator — the
    // handler in app.dart has two ways of getting a room on screen and cannot
    // stack a route on either of them.
    //
    // Post-frame so the push lands on a mounted route rather than during our
    // own initState, and guarded by roomId so a request left over from a
    // notification the user navigated away from cannot ambush a different
    // room. `openChangeRequests` is only honoured for somebody who can
    // actually review — see RoomInfoScreen.
    if (UiSelectionStore.instance.consumeRoomChangeReview(widget.roomId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final room = _room;
        if (mounted && room != null) {
          unawaited(_openRoomInfo(room, openChangeRequests: true));
        }
      });
    }
    // "Ece reacted ❤️ to your message", tapped. The push opened this room by
    // its roomId; this names the bubble, which may be days up the transcript.
    // Consumed unconditionally here — a room that has just mounted IS the one
    // the tap navigated to — and listened for afterwards, for the tap that
    // arrives while this room is already on screen.
    final focus = UiSelectionStore.instance.consumeMessageFocus(widget.roomId);
    if (focus != null) unawaited(_focusMessageFromPush(focus));
    UiSelectionStore.instance.addListener(_onSelectionStoreChange);
    // `this` is the ownership token: whichever State opened the room is the
    // only one allowed to close it. Route transitions dispose the outgoing
    // RoomScreen well after the incoming one has opened its room, so an
    // unguarded close used to tear down the room now on screen.
    widget.repo.openRoom(widget.roomId, owner: this);
    // Synchronously, and BELOW `openRoom` so a warm re-entry sees the roster
    // that call did not have to go and fetch. `openRoom` is async from its
    // first await onwards, but everything before that — including the roster
    // it already holds from a previous visit — is in place by the time this
    // runs, so the first frame of a re-entered room has every sender's name,
    // avatar and colour rather than a transcript in theme ink. A first-ever
    // open finds nothing here and picks the roster up from [_onRepoChange]
    // when the disk seed or the subscription lands.
    _syncMembers();
    // Reads the roster just synced, so an admin re-entering a room they have
    // the members of already asks for the queue on the first frame.
    _suggestions.syncStanding();
    _suggestions.addListener(_onSuggestions);
    // A room switched on in a previous session starts translating the moment
    // it opens, from the disk cache first — which is why reopening a room you
    // already read translated is instant rather than a second round of model
    // runs. No-op on a room that is not switched on.
    Sebastian.instance
        .enqueueRoom(widget.roomId, widget.repo.messagesFor(widget.roomId));
    widget.repo.addListener(_onRepoChange);
    _scroll.addListener(_onScroll);
    // The strip is measured where the bubble WAS; a scroll moves the bubble
    // out from under it, so it goes, and the dwell brings it back once the
    // transcript settles under the pointer.
    _scroll.addListener(_hover.dismiss);
    if (kIsWeb) {
      _pasteToken = DropChannel.instance.addPasteListener(_onPastedBundle);
    }
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
    // The same two doors, for a file dropped on this room's row in the chat
    // list rather than into the transcript — see [DropIntake].
    if (DropController.isSupported) {
      DropIntake.instance.addListener(_takeStagedDrop);
      _takeStagedDrop();
    }
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

  /// The drop half of [_takeStagedShare], with the same post-frame reasoning
  /// and one addition: the bytes behind a staged bundle are a temp copy the
  /// platform is holding on our behalf, and [DropIntake.handoffComplete] is
  /// what tells it they can go. Owed in every case, including the one where
  /// this screen went away before it could deliver.
  void _takeStagedDrop() {
    final staged = DropIntake.instance.takeFor(widget.roomId);
    if (staged == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted) await _deliverDrop(staged);
      } finally {
        DropIntake.instance.handoffComplete();
      }
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
      _departures.isDeparting(_arrivals.keyFor(m)) ||
      _dateTracks.containsKey('m_${m.id}');

  /// The outline a departing bubble takes flight from, for a capture taken
  /// outside the bubble's own build. Run grouping is unknown here, so the
  /// row is treated as standing on its own — a corner's worth of difference
  /// on tiles a few pixels wide.
  ShapeBorder _outlineFor(ChatMessage m) => pulseShapeFor(
        theme: ThemeScope.of(context),
        message: m,
        isMine: m.senderId == widget.repo.userId,
        bubbleStyle: SettingsStore.instance.bubbleStyle,
        ephemeral: true,
      );

  /// Flatten the message list into intro / date-divider / message / thread-
  /// fold rows. See lib/screens/room_items.dart for the algorithm.
  ({List<RoomItem> items, Set<String> hidden}) _buildItems(
    ChatRoom room,
    List<ChatMessage> messages,
  ) {
    // Here as well as in _maybeLandOnUnread because the two settle on the same
    // frame either way, and the divider must not be a frame behind the scroll
    // that lands on it. Costs one bool once settled, which is nearly always.
    _settleUnreadDivider();
    // Everything _mustKeepOwnRow reads has to be in the key, or an armed reply
    // or a highlight pulse would be computed against a stale fold set. The
    // divider row is in it for a different reason: it is null until the room
    // list answers, so on a notification tap it fills in exactly once,
    // mid-room, and a key without it would serve the divider-less pass forever.
    final foldKey = '${_dateTracks.length}'
        '|${_replyingTo?.id ?? ''}'
        '|${_highlightedMessageId ?? ''}'
        '|${_jumpTargetId ?? ''}'
        '|${_unreadDividerId ?? ''}';
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
      unreadBeforeId: _unreadDividerId,
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

    // A finger on the list outranks the opening scroll. Programmatic moves —
    // including the landing's own — leave the user direction idle.
    if (_unreadLandingPending &&
        pos.userScrollDirection != ScrollDirection.idle) {
      _abandonUnreadLanding();
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
      if (!_datePresentation.value.active) {
        if (mounted) _setDateScrolling(true);
      }
      _hideTimer = Timer(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        _setDateScrolling(false);
      });
    } else if (_datePresentation.value.active) {
      if (mounted) _setDateScrolling(false);
    }
  }

  void _setDateScrolling(bool active) {
    final value = _datePresentation.value;
    _datePresentation.value = (label: value.label, active: active, overlap: value.overlap);
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
    final value = _datePresentation.value;
    final labelChanged = nextLabel != null && nextLabel != value.label;
    final overlapChanged = (maxOverlap - value.overlap).abs() > 0.01;
    if (mounted && (labelChanged || overlapChanged)) {
      _datePresentation.value = (
        label: nextLabel ?? value.label,
        active: value.active,
        overlap: maxOverlap,
      );
    }
  }

  /// Re-index [_members] from the repository's roster, and re-settle the
  /// palette with it. Returns true when anything actually moved.
  ///
  /// Called once from `initState` — so a re-entered room, whose roster the
  /// repository still holds, has its senders on the very first frame with no
  /// await in between — and then from [_onRepoChange] for the disk seed and
  /// the live subscription that follow it.
  ///
  /// The subscription itself used to live here. It is on the repository now
  /// (`ChatRepository._registerSecondaryRoomSubscriptions`), which is what
  /// gives the roster a disk cache, the `_openGen` guard, reconnect rebinding,
  /// and one answer shared with Room Info instead of a second live query on
  /// the same rows.
  bool _syncMembers() {
    final roster = widget.repo.membersFor(widget.roomId);
    if (identical(roster, _rosterSource)) return false;
    _rosterSource = roster;
    _members
      ..clear()
      ..addEntries(roster.map((u) => MapEntry(u.id, u)));
    _rebuildSpeakerSlots();
    return true;
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

  /// Which rows are news and which are merely being drawn again — the ledger
  /// behind the transcript's entrance animation, and behind the row identity
  /// that keeps a send from being rebuilt when the server confirms it. See
  /// [MessageArrivals] for the rules and why they are not about time.
  late final MessageArrivals _arrivals = MessageArrivals(
    onSettled: () {
      if (mounted) setState(() {});
    },
  );

  /// Which rows are leaving — the ledger behind a Chamber of Secrets
  /// message's exit. It holds the bubble's last picture and keeps the row in
  /// the list while the picture blows apart. See [MessageDepartures] for the
  /// two moments that can start one and why the capture is synchronous.
  late final MessageDepartures _departures = MessageDepartures(
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// Which rows are being DELETED, and are turning to dust on their way out.
  /// Never an ephemeral row: those leave through [_departures]. See
  /// [MessageDeletions] for how a deletion is told apart from paging.
  late final MessageDeletions _deletions = MessageDeletions(
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  /// The last [ChatRepository.serverRemovals] serial acted on.
  int _seenRemovals = 0;

  /// The timeline the last build drew, ghosts included. What
  /// [_onRepoChange] diffs a delivery against to catch a row the server
  /// removed before this device's clock ran out.
  List<ChatMessage> _lastTimeline = const [];

  /// Hand the ledger this delivery. Separate from [_onRepoChange] only because
  /// the two things it needs — who we are, and whether the reader is parked at
  /// the newest message — are this screen's to know.
  void _noteArrivals(List<ChatMessage> current) => _arrivals.observe(
        current,
        myUserId: widget.repo.userId,
        // Scrolled away, an arrival lands below the fold: there is nothing to
        // watch rise, and growing a row under the reader drags what they are
        // reading. Hysteresis and the pre-layout frame both belong to the
        // notifier, which is already maintained for the jump-to-latest pill.
        nearBottom: !_scrolledUp.value,
      );

  void _onRepoChange() {
    if (!mounted) return;
    final room = widget.repo.roomById(widget.roomId);
    final current = widget.repo.timelineFor(widget.roomId);
    _noteArrivals(current);
    // Somebody else deleted messages that are on screen: they dissolve. Also
    // before the rebuild, so the rows are held in the frame that would have
    // dropped them.
    final removals = widget.repo.serverRemovals(widget.roomId);
    if (removals.serial != _seenRemovals) {
      _seenRemovals = removals.serial;
      final gone = [
        for (final m in _lastTimeline)
          if (removals.ids.contains(m.id)) m,
      ];
      // A burst is not a deletion anybody watched happen (a block, a
      // moderator clearing a room): those rows just go.
      if (gone.isNotEmpty && gone.length <= 12) {
        _deletions.begin(gone, haptic: false);
      }
    }
    // BEFORE the rebuild below, and synchronously: a row the server just
    // deleted is still the last painted frame right now, and this is the
    // only moment its pixels can still be taken for the exit.
    if (_room?.messageLifetime != null) {
      _departures.observeRemoval(
        _lastTimeline,
        current,
        keyFor: _arrivals.keyFor,
        isMine: (m) => m.senderId == widget.repo.userId,
        outlineFor: _outlineFor,
      );
    }
    // The roster lands through the repository too, so this is where the disk
    // seed and the `rooms:getMembers` delivery both reach the transcript.
    // [_syncMembers] is identity-gated and re-settles the palette itself, so
    // this costs one reference comparison on the notifications — nearly all of
    // them — that carry no roster change.
    final rosterMoved = _syncMembers();
    // Admin standing is read off that roster, so it can only move with it —
    // or with the room itself landing, on a first-ever open where the roster
    // arrived before the room did.
    if (rosterMoved || (_room == null && room != null)) {
      _suggestions.syncStanding();
    }
    // A pin lands through the repository like everything else, so this is where
    // a colour picked in room info reaches the transcript. Gated on the
    // signature because this handler runs on every repository notification and
    // re-settling the palette on each would be a sort per incoming message.
    // Deliberately independent of the roster check above rather than an else:
    // a cold start can land the seed and the pins on the same notification,
    // and the palette is settled from both. Re-settling it twice in that one
    // case is free — the function is pure in its two inputs, so the second
    // call simply derives the same answer again.
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
    _drainSendLimit();
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
    AppToast toast,
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
      toast.show(AppLocalizations.of(context)
            .roomScreenAlreadyInLanguageSnack(
                sebastian.targetLanguage.autonym));
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
      toast.show(
        l10n.roomScreenTranslateRoomOffer,
        actionLabel: l10n.roomScreenTranslateRoomOfferAction,
        onAction: () => Sebastian.instance.startRoom(
          widget.roomId,
          widget.repo.messagesFor(widget.roomId),
        ),
      );
    }
  }

  /// Whether the "translate the whole room" offer has already been made this
  /// visit. See [_translateMessage].
  bool _offeredRoomTranslate = false;

  /// Pick the row the UNREAD MESSAGES line sits above — once, and for good.
  ///
  /// The rule is the server's own definition of unread (`badges.unreadForRoom`):
  /// the oldest message past the reader's cursor that they did not send
  /// themselves. Own sends are skipped or the line lands above your last reply
  /// and calls it news to you.
  ///
  /// Latched rather than recomputed, and that is the whole reason this is a row
  /// and not the cursor itself. Every message arriving after this point arrives
  /// while the reader is watching it arrive, and is newer than the cursor too —
  /// so a per-pass comparison draws a fresh line above each of them. Settling
  /// once also means the line and [_maybeLandOnUnread]'s scroll target are
  /// literally the same message rather than two answers that agree by
  /// construction.
  ///
  /// Three ways to settle, and the order matters:
  ///
  ///  * the cursor has not arrived yet — nothing is decided. On a notification
  ///    tap the room list lands AFTER this screen, so answering here is what
  ///    used to disable the divider on exactly that entry.
  ///  * no cursor at all — a room never read before has no line to draw.
  ///  * a cursor with nothing past it — held open until the SUBSCRIPTION has
  ///    spoken, not merely `hasLoadedInitial`, which is already true off a
  ///    disk-cache hydrate that can predate everything this is looking for.
  void _settleUnreadDivider() {
    if (_unreadDividerSettled) return;
    final repo = widget.repo;
    if (!repo.unreadAnchorSettled(widget.roomId)) return;
    final anchor = repo.unreadAnchorFor(widget.roomId);
    if (anchor == null) {
      _unreadDividerSettled = true;
      return;
    }
    final me = repo.userId;
    for (final m in repo.timelineFor(widget.roomId)) {
      if (m.senderId == me) continue;
      if (!m.createdAt.isAfter(anchor)) continue;
      _unreadDividerId = m.id;
      _unreadDividerSettled = true;
      DiagLog.roomOpen('unread-divider', '${widget.roomId} at ${m.id}');
      return;
    }
    if (repo.hasLiveMessages(widget.roomId)) {
      _unreadDividerSettled = true;
      // Not a failure on its own — a room genuinely read to the end settles
      // here every time. It is only news next to an `unread-anchor` line whose
      // cursor is older than the message the reader was just notified about,
      // which is what a log has to be able to tell apart.
      DiagLog.roomOpen(
        'unread-divider',
        '${widget.roomId} none past ${anchor.toIso8601String()} '
        'in ${repo.timelineFor(widget.roomId).length} msgs',
      );
    }
  }

  /// The reader has taken the viewport somewhere on purpose — a pin, a reply,
  /// the latest pill, a send, a drag. Whatever the opening scroll was still
  /// waiting for (a room list that lands late, a first unread message older
  /// than the rows loaded so far) must not arrive after that and drag them
  /// back to the UNREAD line.
  ///
  /// That is exactly what it did: tap a pin within the landing window, and the
  /// history the jump loaded was the change that finally let the landing fire;
  /// tap the latest pill after it, and leaving the history window was. Either
  /// way "go to the bottom" ended on the last message the reader had read. The
  /// line itself stays — only the automatic scroll onto it is given up.
  void _abandonUnreadLanding() => _unreadLandingPending = false;

  /// Snaps the transcript to the first unread message once, as soon as its
  /// row can be located — instead of the reverse:true default of opening at
  /// the very bottom and paging a backlog in above it. Mirrors what a
  /// notification tap or reopening a room with unread messages does in
  /// every big chat app: land where you left off, not where the list ends.
  ///
  /// Aims at [_settleUnreadDivider]'s row, so the viewport and the line cannot
  /// disagree. Self-clearing on three exits: the row is found and jumped to,
  /// the divider settles on nothing to jump to, or the window below runs out
  /// while the answer is still coming.
  void _maybeLandOnUnread() {
    if (!_unreadLandingPending || !mounted) return;
    final deadline = _unreadLandingDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      _unreadLandingPending = false;
      return;
    }
    _settleUnreadDivider();
    // "Not yet" is not "nothing to land on" — keep waiting rather than
    // conceding the bottom of the list to a room list still in flight.
    if (!_unreadDividerSettled) return;
    final id = _unreadDividerId;
    if (id == null) {
      _unreadLandingPending = false;
      return;
    }
    // Settled on a row that isn't built — folded into a thread chip, or a
    // rebuild away. Keep trying; the deadline above is what ends it.
    if (_rowIndexOf[id] == null) return;
    if (!_scroll.hasClients) return;
    _unreadLandingPending = false;
    unawaited(snapToIndex(
      controller: _scroll,
      // Re-read every hop: a message arriving mid-jump shifts every index.
      // The message's index, not the line's: the two are adjacent, and only
      // messages are tracked for the estimate to calibrate against.
      targetIndex: () => _rowIndexOf[id],
      itemCount: () => _revItems.length,
      // The line itself once it is built — it is what the reader is looking
      // for — and the message under it until then.
      targetContext: () =>
          _unreadDividerKey.currentContext ??
          _dateTracks['m_$id']?.key.currentContext,
      probes: _mountedRowProbes,
      // The line in the middle of what the reader can see: what they already
      // read above it for context, what is new below it. When there is not
      // that much below — two unread messages — the scroll clamps at the
      // bottom and the line simply sits lower, with everything new in view.
      alignment: centredAlignment(
        viewport: _scroll.position.viewportDimension,
        extent: _unreadDividerKey.currentContext?.size?.height ?? 36,
        top: _topChromeOverList,
        bottom: _bottomChromeOverList,
        reverse: true,
      ),
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
  /// Says why a send was refused by a server limit. Runs from the same
  /// listener as [_drainChildGate], for the same reason: media sends fail
  /// after the composer has moved on.
  void _drainSendLimit() {
    final code = widget.repo.takeSendLimit();
    if (code == null || !mounted) return;
    final l10n = AppLocalizations.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showAppToast(
        context,
        switch (code) {
          'STORAGE_QUOTA_EXCEEDED' => l10n.sendLimitStorageFull,
          'FILE_TOO_LARGE' => l10n.sendLimitFileTooLarge,
          'MESSAGE_TOO_LONG' => l10n.sendLimitMessageTooLong,
          _ => l10n.sendLimitRateLimited,
        },
        tone: ToastTone.neutral,
      );
    });
  }

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

  /// Takes a message-focus request meant for this room while it is already
  /// open. Peeks first: [UiSelectionStore.consumeMessageFocus] clears on a
  /// miss, and a request naming ANOTHER room belongs to the RoomScreen about to
  /// mount for it — consuming it here would wipe it before that screen exists.
  void _onSelectionStoreChange() {
    final store = UiSelectionStore.instance;
    if (store.messageFocusPendingRoomId != widget.roomId) return;
    final id = store.consumeMessageFocus(widget.roomId);
    if (id != null) unawaited(_focusMessageFromPush(id));
  }

  /// Lands on [messageId] and pulses it — the last hop of a reaction push.
  ///
  /// Waits for the transcript first: on a cold start the tap arrives before
  /// the room has anything to scroll, and a jump into an empty list would
  /// "fail" and toast about a message that is about to arrive. Then it is the
  /// reply tether's trip ([_travelTo]): snap if loaded, page a window of
  /// history in around it if not, the thread overlay if it is folded into one.
  /// No back pill — there is nowhere in this room the reader came from.
  Future<void> _focusMessageFromPush(String messageId) async {
    final repo = widget.repo;
    if (!repo.hasLoadedInitial(widget.roomId)) {
      final loaded = Completer<void>();
      void check() {
        if (repo.hasLoadedInitial(widget.roomId) && !loaded.isCompleted) {
          loaded.complete();
        }
      }
      repo.addListener(check);
      try {
        await loaded.future.timeout(const Duration(seconds: 10));
      } on TimeoutException {
        // Offline or slow: try anyway — `_travelTo` fetches on its own.
      } finally {
        repo.removeListener(check);
      }
    }
    // One frame for the first rows to lay out, so a loaded target can snap.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    ChatMessage? find() {
      for (final m in repo.timelineFor(widget.roomId)) {
        if (m.id == messageId) return m;
      }
      return null;
    }

    var target = find();
    if (target == null) {
      // `_travelTo` wants the message itself (its thread is the fallback
      // surface), so bring its window in first when it is not loaded.
      if (!await repo.jumpToMessage(widget.roomId, messageId)) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      target = find();
      if (target == null) return;
    }
    await _travelTo(messageId, from: target);
  }

  @override
  void dispose() {
    UiSelectionStore.instance.removeListener(_onSelectionStoreChange);
    // Compact/medium `openRoom` mirrors this room into `UiSelectionStore` too
    // (see open_room.dart), so a later resize to expanded can find it. Clear
    // it back out on a normal compact dismissal so a stale roomId can't
    // resurrect this (now-closed) room on some LATER, unrelated resize.
    //
    // Guarded on `!gLastSplitShell` so this does NOT fire during
    // the resize-triggered reconciliation pop itself (app.dart's
    // `_reconcileNavigatorForExpanded`) — that pop runs after the window
    // class has already flipped to expanded, and needs this exact selection
    // to still be here for `_ChatTwoPane` to land on. Also guarded on
    // identity so this never clobbers a newer selection already in flight.
    if (UiSelectionStore.instance.roomId == widget.roomId &&
        !gLastSplitShell) {
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
    DropIntake.instance.removeListener(_takeStagedDrop);
    _ticker.cancel();
    _fadeNow.dispose();
    _captureController.dispose();
    // Before the controller: the session is a listener on it.
    _mention.removeListener(_onMentionChanged);
    _mention.dispose();
    _composer.dispose();
    _expressions.removeListener(_onExpressionsChanged);
    _expressions.dispose();
    _picker
      ..removeListener(_onPickerChanged)
      ..dispose();
    _lifecycle?.dispose();
    _composerFocus.removeListener(_onComposerFocusChanged);
    _composerFocus.unfocus();
    _composerFocus.dispose();
    _highlightCtrl.dispose();
    _hideTimer?.cancel();
    _datePresentation.dispose();
    _arrivals.dispose();
    _departures.dispose();
    _deletions.dispose();
    _scroll.removeListener(_onScroll);
    _scroll.removeListener(_hover.dismiss);
    _hover.dispose();
    final pasteToken = _pasteToken;
    if (pasteToken != null) DropChannel.instance.removePasteListener(pasteToken);
    _scroll.dispose();
    _scrolledUp.removeListener(_onBottomProximity);
    _scrolledUp.dispose();
    _bottomChrome.dispose();
    _jumpBack.removeListener(_onJumpBackChanged);
    _jumpBack.dispose();
    _selection.removeListener(_onSelectionChanged);
    _selection.dispose();
    _suggestions.removeListener(_onSuggestions);
    _suggestions.dispose();
    // No roster subscription to cancel here any more — `closeRoom` below owns
    // it now, beside the rest of the room's queries and under the same
    // ownership guard.
    widget.repo.removeListener(_onRepoChange);
    SettingsStore.instance.removeListener(_onSettings);
    widget.repo.closeRoom(this);
    if (_watchingGames) {
      MatchesStore.instance.removeListener(_onGames);
      MatchesStore.instance.unwatchRoom(widget.roomId);
    }
    if (_pushedCaptureScope) {
      CaptureProtection.instance.popScope();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    // Picked photos send with whatever was typed, or alone.
    if (_picker.hasPicks && _editing == null) {
      await _sendPicks(text);
      return;
    }
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
    final replyAlbum = _replyAlbum;
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
    // Take the future, don't await it yet. ChatRepository._send inserts the
    // optimistic bubble and notifies BEFORE its first await, so by the time
    // this returns the new message is already in the list — which means the
    // reader can be put on it now instead of after a server round trip.
    // Awaiting first left the sender staring at the old tail for the whole
    // trip, and on a slow link that is the entire "sending feels slow".
    final sent = widget.repo.sendText(
      widget.roomId,
      text,
      replyToId: replyTarget?.id,
      replyAlbumCount: replyAlbum,
      mentions: mentions,
      mentionsEveryone: everyone,
      formatting: formatting,
    );
    _keepComposerFocus();
    _scrollToBottom();
    await sent;
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
    // Focus and scroll already happened above, before the await.
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
      showAppToast(
        context,
        AppLocalizations.of(context).scheduleErrorNotInEphemeral,
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
    showAppToast(context, scheduleErrorSentence(context, code));
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

  /// Back from Notification Center or Control Center with the keyboard still
  /// up but the composer no longer focused: Flutter suspends focus while the
  /// app is inactive and does not always give it back. That leaves a keyboard
  /// that types into nothing and that no tap away can dismiss, since there is
  /// no focus left to drop. If the keyboard is still on screen, the composer
  /// is what it was open for, so focus goes back there.
  void _restoreComposerFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _composerFocus.hasFocus || _expressions.isOpen) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
      final primary = FocusManager.instance.primaryFocus;
      // Something else took focus on the way back; leave it there.
      if (primary != null && primary.context?.widget is EditableText) return;
      if (MediaQuery.viewInsetsOf(context).bottom <= 0) return;
      _composerFocus.requestFocus();
    });
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
    // The language filter, not a guardian: nobody can approve it, so it gets
    // a sentence rather than the approval sheet.
    if (isFilterBlockedError(gate)) {
      showAppToast(context, AppLocalizations.of(context).messageFilterBlocked);
      return;
    }
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
      showAppToast(
        context,
        AppLocalizations.of(context).roomScreenAskGrownUpFailedSnack,
        tone: ToastTone.danger,
      );
    }
  }

  /// Arm a reply against [m]: a strong haptic + state change so the
  /// composer card slides into view. Idempotent — re-arming against the
  /// same message just replaces the target. The composer is focused on
  /// the next frame so the keyboard appears without a second tap.
  /// Toggles one of the viewer's reactions on [m], and owns the one refusal
  /// worth explaining: past [kMaxMessageReactionsPerPerson], the friendly
  /// limit alert rather than a chip that silently does nothing.
  /// Carries out a menu choice made with the album switch on "All": on the
  /// whole [album], through its first message where one message has to
  /// stand for it (a reaction, the parent of a reply).
  Future<void> _actOnAlbum(
      MessageActionResult result, List<ChatMessage> album) async {
    final first = album.first;
    final me = widget.repo.userId;
    if (result.emoji != null) {
      await _toggleReaction(first, result.emoji!, album: true);
      return;
    }
    if (result.openFullReactionPicker) {
      final mine = {
        for (final r in first.reactions)
          if (r.userId == me && r.album) r.emoji,
      };
      final pick = await pickReaction(context, selected: mine);
      if (!mounted || pick == null || pick.emoji.isEmpty) return;
      // As on one message: picking one already held means "this one".
      if (!pick.remove && mine.contains(pick.emoji)) return;
      await _toggleReaction(first, pick.emoji, album: true);
      return;
    }
    switch (result.action) {
      case MessageAction.reply:
        _armReply(first, albumCount: album.length);
      case MessageAction.forward:
        await _forwardMessages(album);
      case MessageAction.delete:
        if (!await _confirmDelete(album.length) || !mounted) return;
        _deletions.begin(album);
        for (final m in album) {
          try {
            await widget.repo.deleteMessage(m.id);
          } catch (_) {
            _deletions.cancel([m.id]);
            rethrow;
          }
        }
      default:
        break;
    }
  }

  /// [album] toggles a reaction to the whole album [m] heads rather than to
  /// that one photo. See `MessageReaction.album`.
  Future<void> _toggleReaction(ChatMessage m, String emoji,
      {bool album = false}) async {
    final error = await widget.repo
        .toggleReaction(messageId: m.id, emoji: emoji, album: album);
    if (!mounted || error != kReactionLimitError) return;
    await showReactionLimitNotice(
      context,
      surface: ReactionLimitSurface.message,
    );
  }

  void _armReply(ChatMessage m, {bool haptic = true, int? albumCount}) {
    _replyAlbumFor = albumCount == null ? null : m.id;
    _replyAlbumCount = albumCount ?? 0;
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
    showAppToast(
      context,
      err == 'EDIT_WINDOW_EXPIRED'
          ? l10n.roomScreenEditExpiredSnack
          : err == kMessageFilterBlocked
              ? l10n.messageFilterBlocked
              : l10n.roomScreenEditFailedSnack,
      tone: err == kMessageFilterBlocked ? ToastTone.neutral : ToastTone.danger,
    );
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
      HapticFeedback.selectionClick();
      for (final p in album) {
        if (_selection.contains(p.id)) _selection.toggle(p.id);
      }
      return;
    }
    if (_selection.count + album.length > _kMaxSelected) {
      showAppToast(context, AppLocalizations.of(context)
              .roomScreenMaxSelectionSnack(_kMaxSelected));
      return;
    }
    HapticFeedback.selectionClick();
    for (final p in album) {
      _selection.toggle(p.id);
    }
  }

  void _toggleSelection(ChatMessage m) {
    if (!_selection.contains(m.id) && _selection.count >= _kMaxSelected) {
      showAppToast(
        context,
        AppLocalizations.of(context).roomScreenMaxSelectionSnack(_kMaxSelected),
      );
      return;
    }
    HapticFeedback.selectionClick();
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
    final toast = AppToast.of(context);

    final targets = await showForwardTargetSheet(
      context,
      repo: widget.repo,
      messageCount: picked.length,
      excludeRoomId: widget.roomId,
      // So a room whose posting policy takes none of these is not offered.
      kinds: postKindsOf(picked.map((m) => m.type)),
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
    toast.show(result.summary);
  }

  Future<void> _deleteSelected() async {
    final picked = _selectedMessages;
    if (picked.isEmpty) return;
    final toast = AppToast.of(context);

    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmSheet(
      context,
      headline: l10n.roomScreenDeleteMessageHeadline(picked.length),
      body: l10n.roomScreenDeleteConfirmBody,
      confirmLabel: l10n.roomScreenDeleteConfirmButton,
    );
    if (!confirmed || !mounted) return;

    // Out of selection first, so the rows burn as they read normally — no
    // check marks in the dust — and in one wave, top to bottom.
    _selection.clear();
    _deletions.begin(picked);
    final ids = [for (final m in picked) m.id];
    final result = await deleteMessages(
      api: widget.api,
      repo: widget.repo,
      messageIds: ids,
    );
    if (!mounted) return;

    // No local removal: the room subscription carries the deletion back. The
    // dissolved rows stay hidden until it does (see [MessageDeletions]); a
    // delete that failed outright gives them back.
    if (result.ok == 0) _deletions.cancel(ids);
    toast.show(result.summary);
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
    final c = _pinCursor % pins.length;
    await _jumpToPin(pins[pinIndexForCursor(c, pins.length)]);
    if (!mounted) return;
    setState(() => _pinCursor = nextPinCursor(c, pins.length));
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
        if (i >= 0) {
          setState(() => _pinCursor = pinCursorForIndex(i, pins.length));
        }
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
    final toast = AppToast.of(context);
    _abandonUnreadLanding();

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
    toast.show(
      AppLocalizations.of(context).roomScreenJumpFailedSnack,
      tone: ToastTone.danger,
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
    _abandonUnreadLanding();
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
  /// Null where the room's posting policy takes none of what the control
  /// records, which removes it from the composer outright.
  ComposerCapture? get _composerCapture {
    final posting = _posting;
    final modes = [
      for (final m in ComposerInputMode.values)
        if (posting.allowsAny(_captureKinds(m))) m,
    ];
    if (modes.isEmpty) return null;
    return ComposerCapture(
      modes: modes,
      controller: _captureController,
      onCamera: _onCamera,
      onCaptured: _onCaptured,
      onProblem: _onCaptureProblem,
    );
  }

  /// What a capture mode posts, for the room's posting policy.
  static Set<PostKind> _captureKinds(ComposerInputMode mode) => switch (mode) {
        ComposerInputMode.camera => const {PostKind.image, PostKind.video},
        ComposerInputMode.voice => const {PostKind.voice},
        ComposerInputMode.videoNote => const {PostKind.video},
      };

  /// The open room's posting policy (`RoomCapabilities.posting`): what a
  /// member may put in it. Open until the room resolves, like everything else
  /// that reads [_room]; the server is the authority either way.
  RoomPostingPolicy get _posting {
    final room = _room;
    return room == null
        ? RoomPostingPolicy.open
        : widget.repo.capabilitiesFor(room).posting;
  }

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
    final type = mode == ComposerInputMode.videoNote
        ? MessageType.videoNote
        : MessageType.audio;
    if (!outcome.viewOnce) {
      _sendMedia(
        bytes: outcome.bytes,
        type: type,
        contentType: outcome.contentType,
        posterBytes: outcome.posterBytes,
        mediaDurationMs: outcome.duration.inMilliseconds,
      );
      return;
    }
    // Play once. The full poster is the sender's face and must never leave
    // the device for an armed send; a video note carries a sixteen-pixel
    // stand-in instead, for the sealed circle to blur. A few milliseconds
    // off the UI thread before the bubble appears, which nobody can see.
    unawaited(() async {
      final micro = type == MessageType.videoNote
          ? await viewOnceMicroPoster(outcome.posterBytes)
          : null;
      if (!mounted) return;
      _sendMedia(
        bytes: outcome.bytes,
        type: type,
        contentType: outcome.contentType,
        posterBytes: micro,
        mediaDurationMs: outcome.duration.inMilliseconds,
        viewOnce: true,
      );
    }());
  }

  void _onCaptureProblem(CaptureFailure failure) {
    if (!mounted) return;
    final toast = AppToast.of(context);
    unawaited(showCaptureProblem(
      context,
      failure,
      onMessage: (message) =>
          toast.show(message),
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
      final button = _attachKey.currentContext?.findRenderObject();
      final anchor = button is RenderBox && button.hasSize
          ? button.localToGlobal(Offset.zero) & button.size
          : null;
      setState(() => _attachMenuUp = true);
      // Resolves on the pop, as the menu starts folding back, so the "+"
      // grows back in while the menu shrinks into it.
      final choice = await showAttachmentMenu(
        context,
        anchor: anchor,
        allowMedia: family?.canSendMedia ?? true,
        allowLocation: family?.canShareLocation ?? true,
        // Saved Messages has nobody to play with, and where messages expire
        // the game card would vanish out from under a game still being
        // played (the server refuses it too, `EPHEMERAL_ROOM`).
        allowGames: !(_room?.isSavedMessages ?? false) &&
            !(_room?.messagesExpire ?? false),
        // The inline picker shows photos and videos together.
        unifiedGallery: InlinePhotoPicker.supported,
        // What this room takes at all. See `room_posting_policy.dart`.
        posting: _posting,
      );
      if (mounted) setState(() => _attachMenuUp = false);
      if (choice == null || !mounted) return;
      final nav = Navigator.of(context);
      switch (choice) {
        case AttachmentMenuChoice.gallery:
          // On a phone, the library opens in the keyboard's place and picks
          // wait over the composer; elsewhere, the system picker as before.
          if (InlinePhotoPicker.supported) {
            _openPicker();
          } else {
            await _pickAndSendFromGallery();
          }
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
        case AttachmentMenuChoice.game:
          await _startGame();
          break;
      }
    } finally {
      _attachInFlight = false;
    }
  }

  // ─────────────────────────────── games ───────────────────────────────

  void _onGames() {
    if (!mounted) return;
    final open = MatchesStore.instance.openIn(widget.roomId).isNotEmpty;
    if (open != _gamesOpen) setState(() => _gamesOpen = open);
  }

  /// "Play a game": picks what and how, then starts it on the server. Bots
  /// are not a chat thing; they live on the Feed's games row.
  Future<void> _startGame() async {
    final me = widget.repo.userId;
    final room = _room;
    if (me == null || room == null || room.isSavedMessages) return;
    if (room.messagesExpire) return;
    final draft = await showGameStartSheet(
      context,
      isDm: room.isDm,
      voiceAvailable: GroupCallService.maybeInstance != null,
      memberCount: room.isDm ? null : room.memberCount,
    );
    if (draft == null || !mounted) return;
    final nav = Navigator.of(context);
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    widget.repo.exitHistoryWindow(widget.roomId);
    // Take turns: no card and nothing on the server yet. The board opens
    // locally with the creator to move, and Send creates the game with that
    // move (`matches:startTurns`); backing out creates nothing.
    if (draft.matchMode == MatchMode.async) {
      final other = room.otherParticipantId(me);
      if (other == null) return;
      final going = MatchesStore.instance
          .openIn(widget.roomId)
          .where((m) => m.mode == MatchMode.async)
          .length;
      if (going >= kMaxAsyncPerDm) {
        toast.show(l10n.chatGameErrTooMany);
        return;
      }
      String nameOf(String id) =>
          (_members[id] ?? widget.repo.userById(id))?.displayName ?? '';
      await openTurnDraft(
        context,
        userId: me,
        draft: TurnDraft(
          roomId: widget.roomId,
          game: draft.game,
          seats: [
            MatchSeat(userId: me, name: nameOf(me)),
            MatchSeat(userId: other, name: nameOf(other)),
          ],
        ),
      );
      return;
    }
    try {
      final created = await MatchesStore.instance.api.create(
        userId: me,
        roomId: widget.roomId,
        game: draft.game,
        mode: draft.matchMode,
        clientId: 'mg_${DateTime.now().microsecondsSinceEpoch}',
        options: draft.options,
      );
      if (!mounted) return;
      // Straight to the table: a live lobby to fill, or an async board where
      // the creator moves first.
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              MatchScreen(matchId: created.matchId, userId: me),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      toast.show(switch (matchErrorCode(e)) {
        'ALREADY_LIVE' => l10n.chatGameErrAlreadyLive,
        'TOO_MANY_GAMES' => l10n.chatGameErrTooMany,
        'EPHEMERAL_ROOM' => l10n.chatGameErrEphemeral,
        _ => l10n.chatGameErrGeneric,
      });
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
    final toast = AppToast.of(context);
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
      toast.show(
        l10n.interactionSendFailed,
        tone: ToastTone.danger,
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
    showAppToast(context, AppLocalizations.of(context).interactionRefused);
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
      changes: widget.repo,
      currentInteraction: () => widget.repo.interactionFor(widget.roomId, messageId) ?? interaction,
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
    final toast = AppToast.of(context);
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
      toast.show(
        l10n.locationCouldNotGetFix,
        tone: ToastTone.danger,
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
      toast.show(
        l10n.locationCouldNotStartLiveShare,
        tone: ToastTone.danger,
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
        showAppToast(context, l10n.locationPermissionNeeded);
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

  /// Camera → composer → send, with the composer opening *over* the camera.
  ///
  /// There is no reopen-the-camera loop here, because there is nothing to
  /// reopen: the camera route stays on the stack under the composer, so going
  /// back for another shot is the composer popping. That is also what fixes
  /// the shutter looking like a bug — the camera used to pop and the editor
  /// push after it, and the chat showed through the seam between the two.
  ///
  /// The photos live in one [EditorDraft] for the whole visit, so "take
  /// another" and "add from library" leave the composer without losing
  /// anything: the next capture, or the next tap in the camera's gallery,
  /// reopens it with one more photo. Backing out of the camera while photos are
  /// waiting goes back to them too — see [CameraScreen.resume].
  ///
  /// [initialLens] is which lens to open on.
  ///
  /// The camera can also record: see [CameraScreen.allowVideo]. A clip comes
  /// back as [CameraRecorded] and skips the composer entirely — there is no
  /// video editor to send it through.
  Future<void> _captureAndSend({
    CameraLensDirection initialLens = CameraLensDirection.back,
  }) async {
    final draft = EditorDraft();
    Future<ReviewDecision<EditorSend>> compose(BuildContext context) async {
      final outcome = await CameraEditorScreen.open(
        context,
        draft: draft,
        canRetake: true,
        overCamera: true,
        allowCaptions: true,
        allowSpoiler: true,
        maxPhotos: kMaxPhotoSelection,
        galleryOverCamera: true,
        allowSchedule: true,
        scheduleRefusal: _photoScheduleRefusal(),
      );
      return switch (outcome) {
        EditorRetake() => const ReviewRetake<EditorSend>(),
        EditorAddFromLibrary() => const ReviewRetake<EditorSend>(
          gallery: true,
        ),
        final EditorSend send => ReviewDone(send),
        // Only the gallery's preview keeps; never popped over the camera.
        EditorKeep() || null => const ReviewDone<EditorSend>(null),
      };
    }

    try {
      final result = await CameraScreen.open<EditorSend>(
        context,
        initialLens: initialLens,
        // Chat is the one caller that can accept a clip, so it is the one
        // caller that gets the PHOTO/VIDEO switch.
        allowVideo: true,
        review: (context, photo) {
          if (draft.length < kMaxPhotoSelection) {
            draft.add(photo.bytes, mirrored: photo.mirrored);
          }
          return compose(context);
        },
        resume: () => draft.isEmpty ? null : compose,
        // The gallery's multi-select: every picked photo joins the draft,
        // and the composer opens on the first of them.
        batch: CameraBatch(
          room: () => kMaxPhotoSelection - draft.length,
          max: kMaxPhotoSelection,
          review: (context, photos) {
            final first = draft.length;
            for (final photo in photos.take(kMaxPhotoSelection - first)) {
              draft.add(photo.bytes, mirrored: photo.mirrored);
            }
            draft.index = first;
            return compose(context);
          },
        ),
      );
      if (!mounted) return;

      switch (result) {
        case CameraReviewed(:final value):
          // Sent from here rather than inside the review so the upload starts
          // against a chat that is already back on screen.
          if (value != null) _sendEdited(value);

        case CameraRecorded(:final video):
          // Sent from here rather than from inside the camera for exactly the
          // reason the photograph is: the upload should start against a chat
          // that is already back on screen.
          final path = video.path;
          final bytes = video.bytes;
          if (path != null) {
            // Through the same size rule as a gallery pick. A clip just
            // recorded is compressed without asking: there is nothing else
            // its sender could choose to send instead.
            await _sendVideoFile(
              path,
              durationMs: video.durationMs,
              poster: video.posterBytes,
              confirm: !video.recorded,
              deleteAfter: video.recorded,
            );
          } else if (bytes != null) {
            if (bytes.length > kMaxFileUploadBytes) {
              AppToast.of(context).show(AppLocalizations.of(context)
                  .videoTooLargeSnack(formatFileSize(kMaxFileUploadBytes)));
              return;
            }
            _sendMedia(
              bytes: bytes,
              type: MessageType.video,
              contentType: 'video/mp4',
              posterBytes: video.posterBytes,
              mediaDurationMs: video.durationMs,
            );
          }

        case CameraPickLibrary(:final videos):
          // The gallery's "all photos" — the OS picker, for albums and
          // multi-select. Photos already gathered in the camera come along.
          // From VIDEO mode it is the video picker instead.
          if (videos) {
            await _pickAndSendVideo();
          } else {
            await _pickAndSendFromGallery(into: draft);
          }

        case CameraUnavailable():
          // The in-app camera could not start for a reason that isn't the user
          // saying no. Fall back to the system camera rather than leaving them
          // with no way to take a picture at all. No mirroring on this path:
          // `image_picker` never reports which lens fired, and reflecting a
          // photo of a document would be worse than leaving a selfie unflipped.
          // A refusal folds into the cancel here: the camera's own permission
          // prompt has already spoken for it.
          final picked = (await pickPhoto(source: ImageSource.camera)).file;
          if (picked == null || !mounted) return;
          final bytes = await picked.readAsBytes();
          if (!mounted) return;
          await _composeAndSend([bytes]);

        case null:
          return; // backed out of the camera
      }
    } finally {
      draft.dispose();
    }
  }

  /// The composer for photos with no camera underneath — a share, a drop, the
  /// system camera. Each photo gets its own caption, and the library is one
  /// tap away for more.
  Future<void> _composeAndSend(List<Uint8List> photos) async {
    if (photos.isEmpty) return;
    final draft = EditorDraft();
    for (final bytes in photos.take(kMaxPhotoSelection)) {
      draft.add(bytes);
    }
    draft.index = 0;
    try {
      await _composeDraft(draft);
    } finally {
      draft.dispose();
    }
  }

  Future<void> _composeDraft(EditorDraft draft) async {
    final outcome = await CameraEditorScreen.open(
      context,
      draft: draft,
      allowCaptions: true,
      allowSpoiler: true,
      maxPhotos: kMaxPhotoSelection,
      pickMore: _pickMorePhotos,
      allowSchedule: true,
      scheduleRefusal: _photoScheduleRefusal(),
    );
    if (outcome is EditorSend && mounted) _sendEdited(outcome);
  }

  /// The composer's "add from library": the OS picker, at most [remaining].
  Future<List<Uint8List>> _pickMorePhotos(int remaining) async {
    if (remaining <= 0) return const [];
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    // `pickMultiImage` refuses a limit under two, so the last slot is a
    // single pick.
    final pick = remaining == 1
        ? await pickPhoto(source: ImageSource.gallery)
        : await pickPhotos(limit: remaining);
    if (pick.unreadable) {
      toast.show(loc.mediaPickFailedMessage, tone: ToastTone.danger);
      return const [];
    }
    if (pick.files.isEmpty) return const [];
    // `limit` is ignored by the web and desktop pickers.
    final within = pick.files.length > remaining
        ? pick.files.sublist(0, remaining)
        : pick.files;
    if (within.length < pick.files.length) {
      toast.show(loc.photoTrayLimitSnack(kMaxPhotoSelection));
    }
    final read = await readPickedPhotos(within);
    if (read.dropped > 0) {
      toast.show(loc.photoTrayLoadFailedSnack, tone: ToastTone.danger);
    }
    return read.bytes;
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
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    // Nothing lands in a room members cannot post in: the share sheet does not
    // offer one, so reaching this is a stale suggestion. Dropped quietly, the
    // footer already says why.
    if (!_posting.canPost) return;

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
      // Named by the cap the sender actually hit: a document's is the upload
      // cap, a photo or video's the larger one it can be compressed from.
      final docs = payload.oversized
          .any((i) => intakeCapFor(i.mimeType) == kMaxFileUploadBytes);
      toast.show(
        docs
            ? loc.roomScreenFileSizeCapSnack(formatFileSize(kMaxFileUploadBytes))
            : loc.videoTooLargeSnack(formatFileSize(kMaxMediaIntakeBytes)),
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
        final bytes = await _readShared(lone, toast, loc);
        if (bytes == null || !mounted) return;
        // Released whether or not it is sent: the composer holds its own copy
        // of the bytes, and a share the user backs out of has no second chance
        // to be delivered from disk.
        ShareIntake.instance.disposeItems(payload.items);
        // `_sendEdited` goes through `_sendMedia`, which bumps the suggestion.
        await _composeAndSend([bytes]);
        return;
      }

      // Everything else. Photos and documents go now, in the order the sender
      // chose, through the same funnel as a picked file. Videos go after,
      // together, through the one video rule: a big clip is compressed once
      // the sender has been asked, and five clips are asked about once.
      final videos = <_OutgoingVideo>[];
      for (final item in items) {
        if (item.messageType == MessageType.video) {
          videos.add(_OutgoingVideo(item.path));
          continue;
        }
        final bytes = await _readShared(item, toast, loc);
        if (bytes == null) continue;
        if (!mounted) return;
        if (item.isImage) {
          await _sendUneditedPhoto(bytes, toast, loc);
          continue;
        }
        _sendMedia(
          bytes: bytes,
          type: item.messageType,
          contentType: item.mimeType,
          fileName: item.messageType == MessageType.file ? item.fileName : null,
          fileSize: item.messageType == MessageType.file ? bytes.length : null,
        );
      }
      if (videos.isNotEmpty && mounted) {
        // The scrim is for reading files back; a compress can take a while,
        // and the chat stays usable during it.
        _setMediaBusy(false);
        await _sendVideoFiles(videos);
      }
      ShareIntake.instance.disposeItems(payload.items);
    } finally {
      _setMediaBusy(false);
    }
  }

  /// One photo out of a multi-item share or a mixed drop, compressed exactly
  /// as the editor compresses a photo nobody edited. Used to go up raw, HEIC
  /// and 48 megapixels included, because only a lone shared photo and an
  /// all-photo drop went through the editor. HD is honoured up to the upload cap and gives way past it, the
  /// same as in the editor.
  Future<void> _sendUneditedPhoto(
    Uint8List bytes,
    AppToast toast,
    AppLocalizations loc,
  ) async {
    final hd = SettingsStore.instance.photoHd && bytes.length <= kMaxFileUploadBytes;
    if (SettingsStore.instance.photoHd && !hd) {
      toast.show(loc.photoHdOverCapSnack(1, formatFileSize(kMaxFileUploadBytes)));
    }
    final ready = await prepareUneditedForSend(bytes, hd: hd);
    if (!mounted) return;
    if (ready == null || ready.bytes.length > kMaxFileUploadBytes) {
      toast.show(loc.roomScreenFileReadFailedSnack, tone: ToastTone.danger);
      return;
    }
    _sendMedia(
      bytes: ready.bytes,
      type: MessageType.image,
      contentType: ready.contentType,
      pixelSize: Size(ready.width.toDouble(), ready.height.toDouble()),
    );
  }

  /// Reads a staged share off disk, reporting the one failure that is a user's
  /// problem rather than a bug: the OS reclaimed the cache between the share
  /// and the tap that placed it.
  Future<Uint8List?> _readShared(
    SharedItem item,
    AppToast toast,
    AppLocalizations loc,
  ) async {
    try {
      return await File(item.path).readAsBytes();
    } catch (e) {
      debugPrint('share: could not read ${item.path}: $e');
      if (mounted) {
        toast.show(
          loc.roomScreenFileReadFailedSnack,
          tone: ToastTone.danger,
        );
      }
      return null;
    }
  }

  // ───────────────────────── drag and drop ─────────────────────────

  /// What the verdict chip calls this room — the same title the row in the
  /// chat list and the header both show, so a drop names the conversation the
  /// user thinks they are aiming at.
  String _dropTargetLabel(ChatRoom room) {
    final l10n = AppLocalizations.of(context);
    if (room.isSavedMessages) return l10n.savedMessagesTitle;
    if (room.isDm) {
      return widget.repo.otherUserFor(room)?.displayName ??
          l10n.approvalsScreenForwardDirectMessageFallback;
    }
    return room.name;
  }


  /// What this room will accept off a desktop drag, right now.
  ///
  /// Read fresh on every build rather than cached: it closes over the live
  /// guardian permission, and a policy captured at mount would keep promising
  /// a supervised account an attachment it lost the right to send an hour ago.
  /// The server refuses either way — this is only what the verdict chip is
  /// allowed to say while the file is still in the air.
  DropPolicy get _dropPolicy => DropPolicy(
        allowFiles: FamilyService.maybeInstance?.canSendMedia ?? true,
        // Text is a DRAFT, not a send. A supervised account that may type at
        // all may drag a sentence in, exactly as it may paste one.
        allowText: true,
      );

  /// Everything let go over this room, through this room's own send paths.
  ///
  /// The same rule `_deliverShare` states, for the same reason: a drop is
  /// subject to the same size cap, the same editor and the same optimistic
  /// bubble as a photo picked from the composer, and a second pipeline would
  /// be a second set of bugs. What is different is only what the user was
  /// shown BEFORE it landed — on macOS, everything; in a browser, a count and
  /// some MIME types — which is why this re-plans rather than trusting the
  /// verdict chip, and why the notice at the end exists at all.
  ///
  /// Four shapes, in the order they are common:
  ///
  ///  * **one picture** — the editor, exactly as a gallery pick gets. It is
  ///    the only chance to crop, annotate or arm view-once.
  ///  * **several pictures** — the photo tray, exactly as a multi-pick gets:
  ///    reorder, drop one, arm view-once for the set.
  ///  * **anything else, or a mix** — straight into the transcript in the
  ///    order they were dragged. There is nothing to edit about a document and
  ///    no carousel that holds a PDF beside a video.
  ///  * **text or a link** — the composer. A dragged URL is a draft; sending
  ///    it is still the user's tap.
  Future<void> _deliverDrop(DropBundle bundle) async {
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    // See `_deliverShare`.
    if (!_posting.canPost) return;
    final plan = planFor(bundle.toSnapshot(), policy: _dropPolicy);

    // Text first and unconditionally, for the reason `_deliverShare` gives:
    // with attachments it reads as their caption, and the user can send or
    // discard it after the pictures land.
    final dragged = bundle.uri ?? bundle.text;
    if (plan.hasText && dragged != null && dragged.isNotEmpty) {
      // Appended rather than assigned — a draft already in the composer is
      // something the user typed, and a drop must not eat it.
      final existing = _composer.text.trimRight();
      _composer.text = existing.isEmpty ? dragged : '$existing\n$dragged';
      _keepComposerFocus();
    }

    // Said once, after the fact, and only when there is something to say.
    //
    // This is the half of the feature a browser cannot do any other way. On
    // macOS every caveat was already on the verdict chip before the user let
    // go; on web the names and sizes arrive WITH the drop, so "that one went
    // as a file" and "that one was too big" can only be said here.
    // `ToastTone.neutral` on purpose: a cap, a rule and a fallback are all
    // notices, and painting them in danger red is how red stops meaning
    // anything (see `AppToast`).
    final notice = dropLandingNotice(loc, plan);
    if (notice != null) toast.show(notice);

    if (plan.accepted.isEmpty) {
      _touchShareTarget();
      return;
    }

    // Same uncovered gap every picker path documents, and worse here: the
    // bytes come off a staged copy on disk (macOS) or straight out of a
    // browser's `File`, which for a video is tens of megabytes of read with
    // nothing on screen to explain the pause.
    // Index-aligned with `bundle.files` by construction — `toSnapshot` maps one
    // candidate per file, in order — which is what lets a plan built from
    // metadata be walked back to the bytes behind it.
    final queue = <({DropAssessment plan, DroppedFile file})>[];
    for (var i = 0; i < plan.items.length && i < bundle.files.length; i++) {
      if (plan.items[i].accepted) {
        queue.add((plan: plan.items[i], file: bundle.files[i]));
      }
    }
    if (queue.isEmpty) return;

    // Same uncovered gap every picker path documents, and worse here: the
    // bytes come off a staged copy on disk (macOS) or straight out of a
    // browser's `File`, which for a video is tens of megabytes of read with
    // nothing on screen to explain the pause.
    // Pictures meet the composer, which is itself the "are you sure". Anything
    // else (documents, videos, a mix) used to leave the instant it was let
    // go, one slip of the trackpad from a chat. Asked BEFORE any byte is read.
    if (!plan.isPhotoOnly && !await _confirmDrop(queue.map((q) => q.file))) {
      _touchShareTarget();
      return;
    }
    if (!mounted) return;
    _setMediaBusy(true);
    try {
      if (plan.isPhotoOnly) {
        await _sendDroppedPhotos(queue, toast, loc);
        return;
      }
      // Read one, send one. The alternative — read them all, then send them —
      // holds the whole drop in memory twice over at its peak, once in this
      // list and once in the repository's retained-upload budget. Bounded
      // either way by `kMaxDropBatchBytes`, but there is no reason to spend it
      // twice.
      //
      // Videos with a staged file (macOS) go after, together, through the one
      // video rule, which compresses a big one once the sender has been asked.
      // Photos are compressed as the editor compresses an unedited one.
      final videos = <_OutgoingVideo>[];
      for (final item in queue) {
        if (!mounted) return;
        final type = item.plan.messageType ?? MessageType.file;
        final path = item.file.path;
        if (type == MessageType.video && path != null && !kIsWeb) {
          videos.add(_OutgoingVideo(path));
          continue;
        }
        final bytes = await DropChannel.instance.read(item.file);
        if (!mounted) return;
        if (bytes == null || bytes.isEmpty) {
          // One unreadable file out of five is not a reason to refuse the
          // other four — but it IS a reason to say so, because the send is
          // about to be smaller than what was dropped.
          toast.show(loc.roomScreenFileReadFailedSnack, tone: ToastTone.danger);
          continue;
        }
        if (type == MessageType.image) {
          await _sendUneditedPhoto(bytes, toast, loc);
          continue;
        }
        _sendMedia(
          bytes: bytes,
          type: type,
          contentType: item.plan.uploadContentType,
          fileName: type == MessageType.file ? item.file.name : null,
          fileSize: type == MessageType.file ? bytes.length : null,
        );
      }
      if (videos.isNotEmpty && mounted) {
        _setMediaBusy(false);
        await _sendVideoFiles(videos);
      }
    } finally {
      _setMediaBusy(false);
    }
  }

  /// Names what a non-photo drop is about to send, and to whom. True to send.
  Future<bool> _confirmDrop(Iterable<DroppedFile> files) async {
    final l10n = AppLocalizations.of(context);
    final room = _room ?? widget.repo.roomById(widget.roomId);
    final names = [for (final f in files) f.name];
    const shown = 4;
    final lines = [
      ...names.take(shown),
      if (names.length > shown) l10n.dropConfirmMore(names.length - shown),
    ];
    final sure = await showIosActionSheet<bool>(
      context,
      title: l10n.dropConfirmTitle(room == null ? '' : _dropTargetLabel(room)),
      message: lines.join('\n'),
      actions: [IosSheetAction(label: l10n.dropConfirmSend, value: true)],
    );
    return sure == true;
  }

  /// The all-pictures case: every one of them goes to the composer.
  ///
  /// Split out because it is the only branch that opens a ROUTE, and a route
  /// opened from inside the send loop would put the editor over a transcript
  /// that is still receiving documents behind it.
  Future<void> _sendDroppedPhotos(
    List<({DropAssessment plan, DroppedFile file})> photos,
    AppToast toast,
    AppLocalizations loc,
  ) async {
    // Trimmed BEFORE anything is read, which is the whole reason the trim is
    // here rather than at the tray: reading eleven pictures to then show ten
    // is a megabyte of work per discarded photo. Same cap and same sentence
    // the gallery multi-pick uses.
    final within = photos.length > kMaxPhotoSelection
        ? photos.sublist(0, kMaxPhotoSelection)
        : photos;
    if (within.length < photos.length) {
      toast.show(loc.photoTrayLimitSnack(kMaxPhotoSelection));
    }

    final read = <Uint8List>[];
    var unreadable = 0;
    for (final photo in within) {
      final bytes = await DropChannel.instance.read(photo.file);
      if (bytes == null || bytes.isEmpty) {
        unreadable++;
        continue;
      }
      read.add(bytes);
    }
    if (!mounted) return;
    if (read.isEmpty) {
      toast.show(loc.roomScreenFileReadFailedSnack, tone: ToastTone.danger);
      return;
    }
    if (unreadable > 0) {
      toast.show(loc.photoTrayLoadFailedSnack, tone: ToastTone.danger);
    }

    // The same composer the camera and gallery paths use — a preview,
    // optional annotation, a caption per photo, view-once, and a deliberate
    // "send" tap instead of shipping pictures the moment they are let go.
    await _composeAndSend(read);
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

  /// Sends what came out of the composer, in its rail's order.
  ///
  /// Synchronously, one call per photo: `sendMediaLocal` puts an optimistic
  /// bubble up per call, so the transcript grows the album in the order the
  /// sender arranged it rather than in whatever order the uploads finish. A
  /// captioned photo leaves the album for a bubble of its own — see
  /// `albumEligible`.
  void _sendEdited(EditorSend outcome) {
    final at = outcome.scheduleAt;
    if (at != null) {
      unawaited(_schedulePhotos(outcome, at));
      return;
    }
    // One id for the whole send, so the transcript stacks exactly these, in
    // this order, however their uploads go. A lone photo needs none.
    final photos = outcome.photos;
    final albumId = photos.length > 1 ? newAlbumId() : null;
    // A reply written with several photos is the whole send's, so it rides
    // on the LAST one: the stack is drawn as its last item, which puts the
    // quote above the stack. It used to land on the first, which a reply
    // keeps out of a stack, splitting the send in two.
    final replyTarget = albumId == null ? null : _replyingTo;
    final replyAlbum = albumId == null ? null : _replyAlbum;
    if (replyTarget != null) setState(() => _replyingTo = null);
    for (var i = 0; i < photos.length; i++) {
      final last = i == photos.length - 1;
      _sendPhoto(
        photos[i].image,
        viewOnce: outcome.viewOnce,
        spoiler: outcome.spoiler,
        caption: photos[i].caption,
        albumId: albumId,
        replyTo: last ? replyTarget : null,
        replyToAlbumCount: last ? replyAlbum : null,
      );
    }
    if (outcome.dropped > 0) {
      AppToast.of(context).show(
        AppLocalizations.of(context).photoTrayLoadFailedSnack,
        tone: ToastTone.danger,
      );
    }
  }

  /// What the composer says when the send arrow is held in a room that
  /// refuses scheduling — the Chamber of Secrets rule [_scheduleSend] applies
  /// to text, said in the same words. Null where scheduling is allowed.
  String? _photoScheduleRefusal() => (_room?.isEphemeral ?? false)
      ? AppLocalizations.of(context).scheduleErrorNotInEphemeral
      : null;

  /// Queues the composer's photos for [at] instead of sending them.
  ///
  /// The uploads happen here, after the composer has closed, so the chat is
  /// back on screen while they run — the same reason a live photo send starts
  /// against the transcript rather than inside the composer. They land in the
  /// queue pill when the server has them. A refusal is said rather than
  /// swallowed: a scheduled photo that silently never queued looks exactly
  /// like one that did, until the day it does not arrive.
  Future<void> _schedulePhotos(EditorSend outcome, DateTime at) async {
    final replyTarget = _replyingTo;
    if (replyTarget != null) setState(() => _replyingTo = null);
    final code = await widget.repo.schedulePhotos(
      widget.roomId,
      [
        for (final p in outcome.photos) (image: p.image, caption: p.caption),
      ],
      // An absolute instant: the sheet resolved a wall-clock intent in this
      // device's timezone. See `SchedulePreset`.
      sendAt: at.millisecondsSinceEpoch,
      viewOnce: outcome.viewOnce,
      mediaSpoiler: outcome.spoiler,
      replyToId: replyTarget?.id,
    );
    if (code == null || !mounted) return;
    if (code == kChildApprovalRequired || code == kChildNotAllowed) {
      await _handleSendGate(code);
      return;
    }
    showAppToast(context, scheduleErrorSentence(context, code));
  }

  /// Sends one finished photograph. The single funnel for every photo path, so
  /// a change to how a photo becomes a message cannot land on one of them and
  /// not the others.
  void _sendPhoto(
    CroppedImage image, {
    required bool viewOnce,
    bool spoiler = false,
    String? caption,
    String? albumId,
    ChatMessage? replyTo,
    int? replyToAlbumCount,
  }) {
    _sendMedia(
      bytes: image.bytes,
      type: MessageType.image,
      contentType: image.contentType,
      pixelSize: Size(image.width.toDouble(), image.height.toDouble()),
      viewOnce: viewOnce,
      mediaSpoiler: spoiler,
      caption: caption,
      albumId: albumId,
      replyTo: replyTo,
      replyToAlbumCount: replyToAlbumCount,
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
  /// The room's photos and videos, the same set the photo gallery swipes
  /// through, for a video bubble's OS player to swipe through too. Closing
  /// it lines the transcript up on the item it closed on, as the photo
  /// gallery does.
  VideoGallery _videoGalleryFor(ChatMessage m) => VideoGallery(
        items: [
          for (final x in widget.repo.timelineFor(widget.roomId))
            if (messageBelongsIn(x, RoomContentTab.media)) x,
        ],
        onLanded: (landed) {
          if (landed.id != m.id) _alignTranscriptTo(landed);
        },
      );

  /// The video notes after [m] in the transcript, for a focused note's
  /// auto-advance. A snapshot, like the gallery's: a note that arrives while
  /// one is playing joins the run the next time a note is opened, not under
  /// the one playing now. Each one knows how to bring its own bubble on
  /// screen behind the focus, so closing always has somewhere to land.
  List<VideoNoteRef> _videoNotesAfter(ChatMessage m) {
    final timeline = widget.repo.timelineFor(widget.roomId);
    final at = timeline.indexWhere((x) => x.id == m.id);
    if (at < 0) return const [];
    return [
      for (final x in timeline.skip(at + 1))
        // Never into a play-once note: it has no storage id to find anyway,
        // but autoplay is not a way to spend somebody's one watch.
        if (x.type == MessageType.videoNote &&
            !x.viewOnce &&
            x.upload == null &&
            (x.mediaStorageId?.isNotEmpty ?? false))
          VideoNoteRef(
            storageId: x.mediaStorageId!,
            posterStorageId: x.posterStorageId,
            durationMs: x.mediaDurationMs,
            reveal: () => _alignTranscriptTo(x),
          ),
    ];
  }

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
        // Share and Save — a lone picture still gets the viewer's toolbar.
        message: m,
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
      // Share, Save, Forward and Delete. The chat is where most pictures are
      // opened from, so without this the toolbar would exist only in room
      // info.
      actions: MediaPagerActions.room(
        repo: widget.repo,
        api: widget.api,
        roomId: widget.roomId,
      ),
      onPageChanged: _alignTranscriptTo,
      // Past the transcript's loaded window, the gallery fetches its own.
      loadOlder: _olderGalleryMedia,
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
    // By id: the landed picture may be one the gallery fetched itself, older
    // than anything the transcript holds, in which case there is no row to
    // align and `_alignTranscriptTo` leaves the transcript where it is.
    if (landed != null && landed.id != m.id) _alignTranscriptTo(landed);
  }

  /// Older media for the gallery, once a reader swipes past the oldest
  /// picture the transcript has loaded. Straight from the room's media index
  /// (`roomContent:listBucket`, the shared-content grid's query) rather than
  /// by paging the transcript: a long chat can hold hundreds of messages
  /// between two photographs, and the gallery wants the photographs.
  ///
  /// Filtered through [messageBelongsIn] like the transcript's own set, and
  /// it keeps paging while a page filters down to nothing — the pager's
  /// cursor is the oldest item it HOLDS, so an empty answer with more behind
  /// it would ask for the same page again on every swipe.
  Future<RoomContentPage> _olderGalleryMedia(ChatMessage oldest) async {
    final me = widget.repo.userId;
    if (me == null) return RoomContentPage.empty;
    var before = oldest.createdAt;
    for (var tries = 0; tries < 8; tries++) {
      final page = await widget.api.listRoomContent(
        roomId: widget.roomId,
        userId: me,
        bucket: 'media',
        before: before,
        limit: 30,
      );
      final items = [
        for (final x in page.items.reversed)
          if (messageBelongsIn(x, RoomContentTab.media)) x,
      ];
      if (items.isNotEmpty || !page.hasMore || page.items.isEmpty) {
        return RoomContentPage(items: items, hasMore: page.hasMore);
      }
      before = page.items.last.createdAt;
    }
    // Eight pages in a row of nothing the gallery can show is treated as the
    // end, rather than asked for again from the same cursor on every swipe.
    return RoomContentPage.empty;
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
  ///
  /// Hands the bytes back to the sealed bubble rather than presenting them
  /// here: a photo goes to [ViewOnceViewer], a voice message plays in its pill,
  /// a video note flies into its focus — each bubble knows its own shape.
  Future<Uint8List?> _openViewOnce(ChatMessage m) async {
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    if (!await AppOnly.confirmViewOnce(context)) return null;
    final res = await fetchViewOnce(
      repo: widget.repo,
      roomId: widget.roomId,
      messageId: m.id,
    );
    final bytes = res.bytes;
    if (bytes != null) return bytes;
    if (mounted) {
      toast.show(
        viewOnceFailureMessage(l10n, m.type, res.failure!),
        tone: ToastTone.danger,
      );
    }
    return null;
  }

  /// Puts one or more photographs in front of the user before anything is sent.
  ///
  /// The picker is `pickMultiImage` — through [pickPhotos], which is where the
  /// platform's own failures are turned into something to say rather than an
  /// exception — and not `pickImage`, which is the whole feature: the library
  /// sheet has always been able to hand back a set, and asking it for one
  /// picture meant that sending four cost four trips through the attachment
  /// sheet, the OS picker and the editor.
  ///
  /// One photo or ten, they all go to the same composer: each with its own
  /// pen, crop and caption, and a rail along the bottom once there are two.
  ///
  /// [into] is a draft already under way — the camera's, when its gallery's
  /// "all photos" button was the way here — so photos gathered there come
  /// along with their edits and captions instead of being dropped.
  ///
  /// The scrim is raised BEFORE the picker, not after it. `pickerImageQuality`
  /// forces the plugin to fully decode and re-encode every chosen asset —
  /// seconds for a dozen 12 megapixel HEICs — and that work happens once the
  /// native sheet has already slid away, so the user used to be handed back an
  /// unchanged chat screen and left to guess whether their tap had landed.
  ///
  /// Held for the whole method rather than lowered at the handoff: the
  /// composer paints over the scrim and raises a spinner of its own while it
  /// decodes, so there is no frame where nothing is spinning.
  Future<void> _pickAndSendFromGallery({EditorDraft? into}) async {
    final room = kMaxPhotoSelection - (into?.length ?? 0);
    _setMediaBusy(true);
    try {
      final read = room <= 0 ? const <Uint8List>[] : await _pickMorePhotos(room);
      if (!mounted) return;
      if (read.isEmpty && (into == null || into.isEmpty)) return;
      final draft = into ?? EditorDraft();
      final firstNew = draft.length;
      for (final bytes in read) {
        draft.add(bytes);
      }
      // Opens on the first photo just chosen, not the last.
      draft.index = read.isEmpty ? draft.length - 1 : firstNew;
      try {
        await _composeDraft(draft);
      } finally {
        if (into == null) draft.dispose();
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

  void _onExpressionsChanged() {
    if (mounted) setState(() {});
  }

  void _onComposerFocusChanged() {
    if (_composerFocus.hasFocus) {
      _expressions.dismiss();
      // The keyboard is coming back to type the comment; the picks stay.
      _picker.close();
    }
  }

  // ─────────────────── the inline photo picker ───────────────────

  void _openPicker() {
    if (_expressions.isOpen) _expressions.hide();
    _composerFocus.unfocus();
    dismissSoftKeyboard();
    _picker.open();
  }

  /// The keyboard's place, held for the picker while it is up: the picker
  /// itself lies over the whole room ([_pickerSheet]) so it can be pulled up
  /// to fill it, and rests exactly on this box. The keyboard's last height
  /// (the expression panel keeps that measurement for both).
  Widget _pickerPanel({required double bottomPadding}) =>
      SizedBox(height: _expressions.height + bottomPadding);

  /// The picker, over the room. At rest it covers [_pickerPanel] and the
  /// home indicator below it, which is the same in both chat styles: the
  /// classic column's SafeArea and the liquid one's padding both keep the
  /// panel that far off the bottom.
  Widget _pickerSheet() => Positioned.fill(
        child: InlinePhotoPicker(
          controller: _picker,
          height: _expressions.height,
          bottomPadding: MediaQuery.paddingOf(context).bottom,
          onFull: () => AppToast.of(context).show(
            AppLocalizations.of(context)
                .roomScreenMaxSelectionSnack(_picker.max),
          ),
        ),
      );

  /// A tap on a pick in the strip: a video plays, a photo opens to edit.
  Future<void> _openPick(PickedMedia pick) =>
      pick.isVideo ? _playPick(pick) : _editPick(pick);

  /// A picked video, in the OS player, from the same original file a send
  /// would read ([_ReadyPick._video]). Resolves once the player is up.
  Future<void> _playPick(PickedMedia pick) async {
    try {
      final file = await pick.asset.originFile;
      if (file == null || !mounted) return;
      final l = AppLocalizations.of(context);
      final shown = await NativeVideoPlayer.present(
        url: Uri.file(file.path).toString(),
        secure: CaptureProtection.instance.active,
        shieldTitle: l.countBadgeProtectedLabel,
        shieldBody: l.countBadgeCaptureShieldActiveBody,
      );
      if (!shown) debugPrint('[inline_picker] the OS player declined a pick');
    } catch (e) {
      debugPrint('[inline_picker] play: $e');
    }
  }

  /// A picked photo, in THE photo preview: the camera's composer, with
  /// every switch and tool the camera's own shot gets (draw, crop, rotate,
  /// caption, view once, spoiler, HD, hold to schedule) and Send. The
  /// switches are the picker's own [InlinePickerController.options], so
  /// what is flipped here is what the strip sends with, and Send sends the
  /// whole selection, as the composer's arrow would. The × goes back to the
  /// strip keeping the edit and the caption. No "add more": the picker under
  /// the strip is where more come from.
  Future<void> _editPick(PickedMedia pick) async {
    final bytes = pick.edited?.bytes ?? await GalleryTray.loadBytes(pick.asset);
    if (bytes == null || !mounted) return;
    final outcome = await CameraEditorScreen.open(
      context,
      source: bytes,
      allowCaptions: true,
      allowSpoiler: true,
      maxPhotos: 1,
      options: _picker.options,
      closeKeeps: true,
      initialCaption: pick.caption,
      // Scheduling queues photos only; a selection with a clip in it is
      // sent now or not at all.
      allowSchedule: !_picker.picks.any((p) => p.isVideo),
      scheduleRefusal: _photoScheduleRefusal(),
    );
    if (!mounted || !_picker.picks.contains(pick)) return;
    switch (outcome) {
      case EditorKeep(:final image, :final caption):
        _picker.keep(pick, image: image, caption: caption);
      case EditorSend(:final photos, :final scheduleAt):
        if (photos.isEmpty) return;
        _picker.keep(
          pick,
          image: photos.first.image,
          caption: photos.first.caption ?? '',
        );
        if (scheduleAt != null) {
          await _schedulePicks(scheduleAt);
        } else {
          await _sendPicks(_composer.text.trim());
        }
      default:
        break;
    }
  }

  /// The picks, queued for [at] from their preview's held arrow. Photos
  /// only (the preview offers the hold only then), each as it was left,
  /// with the same switches a send now takes.
  Future<void> _schedulePicks(DateTime at) async {
    final options = _picker.options;
    final hd = options.hd;
    final photos = <EditorPhoto>[];
    var dropped = 0;
    _setMediaBusy(true);
    try {
      for (final pick in _picker.picks) {
        final r = await _ReadyPick.from(pick, hd: hd);
        final photo = r?.photo;
        if (photo == null) {
          dropped++;
          continue;
        }
        final caption = pick.caption.trim();
        photos.add(EditorPhoto(
          image: photo,
          caption: options.viewOnce || caption.isEmpty ? null : caption,
        ));
      }
    } finally {
      if (mounted) _setMediaBusy(false);
    }
    if (!mounted || photos.isEmpty) return;
    final send = EditorSend(
      photos: photos,
      viewOnce: options.viewOnce,
      spoiler: options.spoiler,
      dropped: dropped,
      scheduleAt: at,
    );
    _picker.take();
    _picker.close();
    options.reset();
    await _schedulePhotos(send, at);
  }

  /// Sends the picks, in pick order, as one album, then the comment (if
  /// any) right under it. Everything is made ready first and only then
  /// sent, so the order on the other side is the order they were picked in
  /// however long each took to load. A reply rides on the last item, as a
  /// multi-photo send's does (see [_sendEdited]).
  ///
  /// Videos follow the one video rule ([_sendVideoFiles]): over
  /// [kMaxFileUploadBytes] they are compressed to fit, after one question
  /// for the whole send that also offers to leave them out. Cancelling it
  /// sends nothing and leaves the picks where they were. While anything is
  /// compressing the chat stays usable (no scrim), and the send outlives
  /// the screen: leave the room and it still lands.
  Future<void> _sendPicks(String comment) async {
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    final repo = widget.repo;
    final roomId = widget.roomId;
    final cap = formatFileSize(kMaxFileUploadBytes);

    // Asked before anything leaves the strip, from the library's records:
    // no clip is read to find out.
    final picks = _picker.picks;
    final big = <PickedMedia>{};
    for (final p in picks) {
      if (p.isVideo && AssetSizes.overCap(await AssetSizes.of(p.asset))) {
        big.add(p);
      }
    }
    if (!mounted) return;
    var leaveOut = const <PickedMedia>{};
    if (big.isNotEmpty) {
      final small = picks.length - big.length;
      final choice = await showIosActionSheet<bool>(
        context,
        title: l10n.videoShrinkPromptTitle(big.length, cap),
        message: l10n.videoShrinkPromptBody(big.length),
        actions: [
          IosSheetAction(label: l10n.videoShrinkPromptAction, value: true),
          if (small > 0)
            IosSheetAction(
              label: l10n.videoShrinkSendSmallOnly(small, cap),
              value: false,
            ),
        ],
      );
      if (choice == null || !mounted) return;
      if (!choice) leaveOut = big;
    }

    final taken = [
      for (final p in _picker.take())
        if (!leaveOut.contains(p)) p,
    ];
    _picker.close();
    _composer.clear();
    final replyTarget = _replyingTo;
    final replyAlbum = _replyAlbum;
    if (replyTarget != null) setState(() => _replyingTo = null);
    // The switches as they stand now, then back off for the next send.
    final options = _picker.options;
    final hd = options.hd;
    final viewOnce = options.viewOnce;
    final spoiler = options.spoiler;
    options.reset();
    final shrinking = taken.any(big.contains);

    final ready = <_ReadyPick>[];
    // Each ready item's pick, for what its preview left on it (a caption).
    final readyFrom = <PickedMedia>[];
    var dropped = 0;
    var tooLong = 0;
    // A read is quick and gets the scrim; a compression can take a while and
    // gets a note instead, with the chat still in hand.
    if (shrinking) {
      toast.show(l10n.videoShrinkWorkingSnack);
    } else {
      _setMediaBusy(true);
    }
    try {
      for (final pick in taken) {
        final r = await _ReadyPick.from(pick, hd: hd);
        switch (r) {
          case _ReadyPick():
            ready.add(r);
            readyFrom.add(pick);
          case null when pick.isVideo && big.contains(pick):
            tooLong++;
          case null:
            dropped++;
        }
      }
    } finally {
      if (mounted && !shrinking) _setMediaBusy(false);
    }

    final albumId = ready.length > 1 ? newAlbumId() : null;
    for (var i = 0; i < ready.length; i++) {
      final r = ready[i];
      final last = i == ready.length - 1;
      final reply = last ? replyTarget : null;
      final replyCount = last ? replyAlbum : null;
      final photo = r.photo;
      // View once is a photo's: there is no sealed bubble for a clip, so a
      // video in the same send goes as itself (the strip only marks photos).
      final caption = readyFrom[i].caption.trim();
      final photoCaption =
          photo == null || viewOnce || caption.isEmpty ? null : caption;
      if (mounted) {
        if (photo != null) {
          _sendPhoto(
            photo,
            viewOnce: viewOnce,
            spoiler: spoiler,
            caption: photoCaption,
            albumId: albumId,
            replyTo: reply,
            replyToAlbumCount: replyCount,
          );
        } else {
          _sendMedia(
            bytes: r.videoBytes!,
            type: MessageType.video,
            contentType: r.contentType!,
            posterBytes: r.poster,
            mediaDurationMs: r.durationMs,
            mediaSpoiler: spoiler,
            albumId: albumId,
            replyTo: reply,
            replyToAlbumCount: replyCount,
          );
        }
      } else {
        // Left the chat while it was compressing: the send still belongs in
        // it, and the repository does not need this screen to make it.
        repo.sendMediaLocal(
          roomId: roomId,
          bytes: photo?.bytes ?? r.videoBytes!,
          contentType: photo?.contentType ?? r.contentType!,
          type: photo != null ? MessageType.image : MessageType.video,
          mediaWidth: photo?.width.toDouble(),
          mediaHeight: photo?.height.toDouble(),
          posterBytes: r.poster,
          mediaDurationMs: r.durationMs,
          viewOnce: photo != null && viewOnce,
          mediaSpoiler: spoiler,
          caption: photoCaption,
          albumId: albumId,
          replyToId: reply?.id,
          replyAlbumCount: replyCount,
        );
      }
    }
    if (comment.isNotEmpty) {
      await repo.sendText(
        roomId,
        comment,
        // With nothing sent ahead of it, the comment is the reply.
        replyToId: ready.isEmpty ? replyTarget?.id : null,
        replyAlbumCount: ready.isEmpty ? replyAlbum : null,
      );
    }
    if (dropped > 0) {
      toast.show(l10n.mediaPickFailedMessage, tone: ToastTone.danger);
    }
    if (tooLong > 0) {
      toast.show(l10n.videoShrinkFailedSnack(tooLong, cap),
          tone: ToastTone.danger);
    }
  }

  // ─────────────────── GIFs and stickers ───────────────────

  /// Sends a GIF or sticker picked from the panel or a suggestion.
  ///
  /// The panel stays open afterwards, the way every messenger's does: a sticker
  /// is often followed by another, and snapping the keyboard back up after each
  /// one is the behaviour people complain about.
  void _sendExpression(ExpressionItem item, {String? query}) {
    final replyTarget = _replyingTo;
    final replyAlbum = _replyAlbum;
    if (replyTarget != null) setState(() => _replyingTo = null);
    widget.repo.exitHistoryWindow(widget.roomId);
    unawaited(widget.repo.sendExpression(
      widget.roomId,
      item,
      replyToId: replyTarget?.id,
      replyAlbumCount: replyAlbum,
    ));
    final store = ExpressionStore.instance;
    store.noteUsed(item);
    // Stay open, but come back down from the expanded level so the message
    // just sent is on screen — see [ExpressionPanelController.noteSent].
    _expressions.noteSent();
    // KLIPY's terms ask for a share ping on every send; it also feeds the
    // user's recents on KLIPY's side.
    final slug = item.ref;
    if (item.source == ExpressionSource.klipy && slug != null) {
      unawaited(store.klipy?.registerShare(item.kind, slug, query: query));
    }
    _scrollToBottom();
    _touchShareTarget();
  }

  /// A suggested sticker answers the emoji that summoned it, so the emoji goes.
  void _sendSuggestedSticker(ExpressionItem item) {
    _composer.clear();
    _sendExpression(item);
  }

  /// A GIF or sticker the keyboard inserted — Gboard's GIF tab, the iOS sticker
  /// drawer, Samsung's keyboard. Sent as an image exactly as it arrived: the
  /// send path passes GIF and WebP through untouched, so it still moves.
  Future<void> _onKeyboardContent(KeyboardInsertedContent content) async {
    final bytes = content.data;
    if (bytes == null || bytes.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    if (FamilyService.maybeInstance?.canSendMedia == false) {
      showAppToast(context, l10n.expressionMediaNotAllowed,
          tone: ToastTone.danger);
      return;
    }
    Size? size;
    try {
      size = await imageBytesSize(bytes);
    } catch (_) {}
    if (!mounted) return;
    _sendMedia(
      bytes: bytes,
      type: MessageType.image,
      contentType: sniffImageContentType(bytes),
      pixelSize: size,
    );
  }

  // ───────────── the keyboard and the mouse: paste, ↑, shortcuts ─────────────

  /// ⌘V in the composer on macOS: files or an image on the clipboard go out
  /// through [_deliverDrop], the same intake a drag takes, so a pasted
  /// screenshot opens the photo editor exactly as a dropped one does. False
  /// (the clipboard holds text, or nothing to send) runs the ordinary text
  /// paste — see [ComposerKeys].
  Future<bool> _pasteMedia() async {
    final bundle = await DropChannel.instance.readClipboard();
    if (bundle == null) return false;
    if (!mounted) {
      DropChannel.instance.release(bundle);
      return true;
    }
    await _deliverPasted(bundle);
    return true;
  }

  /// The browser's half of [_pasteMedia]: a page only ever sees pasted files
  /// in the `paste` event, so they arrive here instead of being asked for.
  /// Taken only while the composer has focus, so an image pasted into some
  /// other field on screen is not silently sent to this chat.
  Future<void> _onPastedBundle(DropBundle bundle) async {
    if (!mounted || !_composerFocus.hasFocus) return;
    await _deliverPasted(bundle);
  }

  Future<void> _deliverPasted(DropBundle bundle) async {
    try {
      await _deliverDrop(bundle);
    } finally {
      DropChannel.instance.release(bundle);
    }
  }

  /// ↑ in an empty composer: edit the newest of your messages that can still
  /// be edited. False when there is none, which lets the key through.
  bool _editLastOwn() {
    if (_editing != null || _selection.active) return false;
    final room = widget.repo.roomById(widget.roomId);
    final me = widget.repo.userId;
    if (room == null || me == null) return false;
    final messages = widget.repo.messagesFor(widget.roomId);
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.senderId != me) continue;
      if (widget.repo.capabilitiesForMessage(m, room).canEdit) {
        _armEdit(m);
        return true;
      }
    }
    return false;
  }

  /// The room's own catalog shortcuts. Bound only for what this room can do
  /// right now: no calls where the header has no call buttons, nothing that
  /// needs the composer while a selection has replaced it. There is no
  /// in-chat search in this room yet, so `searchInChat` is not bound and ⌘F
  /// stays the app's search.
  Map<ShortcutDef, VoidCallback> _roomShortcuts(ChatRoom room) {
    final caps = widget.repo.capabilitiesFor(room);
    final composing = !_selection.active;
    final dmUser = room.isDm ? widget.repo.otherUserFor(room) : null;
    final canCall = caps.canCall &&
        FamilyService.maybeInstance?.canCall != false &&
        (room.isDm ? dmUser != null : GroupCallService.maybeInstance != null);
    void call(CallMediaKind kind) {
      if (dmUser != null) {
        CallButton(
          peerUserId: dmUser.id,
          peerName: dmUser.displayName,
          peerAvatarStorageId: dmUser.avatarStorageId,
          roomId: room.id,
          variant: CallButtonVariant.liquid,
          kind: kind,
        ).activate(context);
      } else {
        GroupCallButton(roomId: room.id, kind: kind).activate(context);
      }
    }

    return {
      AppShortcuts.roomInfo: () => _openRoomInfo(room),
      AppShortcuts.jumpToLatest: _onJumpToLatestTapped,
      if (composing) AppShortcuts.attach: _onAttach,
      if (composing)
        AppShortcuts.emoji: () {
          // A composition in flight owns the keyboard; the panel would take
          // the field's focus out from under the candidate window.
          if (_composer.value.composing.isValid) return;
          _expressions.toggle(_composerFocus);
        },
      if (canCall) AppShortcuts.voiceCall: () => call(CallMediaKind.audio),
      if (canCall) AppShortcuts.videoCall: () => call(CallMediaKind.video),
    };
  }

  /// Opens a message's read receipts: the INFO row's answer, and the same
  /// screen the start-edge swipe pulls in.
  void _openReceipts(ChatMessage m) {
    final me = widget.repo.userId ?? '';
    Navigator.of(context).push(MessageReceiptsRoute<void>(
      builder: (_) => MessageReceiptsScreen(
        repo: widget.repo,
        api: widget.api,
        roomId: widget.roomId,
        messageId: m.id,
        fallbackMessage: m,
        currentUserId: me,
        roster: () => _members.values.toList(),
        onOpenProfile: _openProfile,
      ),
    ));
  }

  Future<void> _createSticker() async {
    await createPersonalSticker(context, api: widget.api);
  }

  /// Whether the expression panel was open on the previous build — see
  /// [_chromeSize].
  bool _panelWasOpen = false;

  /// Keeps the bottom chrome's subtree — the composer's field, its focus and
  /// the keyboard with it — when [_chromeSize] adds or drops its wrapper.
  final GlobalKey _chromeKey = GlobalKey(debugLabel: 'roomBottomChrome');

  /// The bottom chrome, resized in step with its height.
  ///
  /// Animated so a reply card grows up out of the composer. Never while the
  /// expression panel is open, or on the build it closes: the panel sits
  /// BELOW the composer and animates its own height, frame by frame with the
  /// keyboard. Eased a second time out here, the box trailed the panel and
  /// — pinned to the bottom, clipped at the top — cut the composer off for a
  /// frame or two whenever it fell behind: a flicker on every keyboard move.
  ///
  /// Left out rather than given a zero duration: an [AnimatedSize] at zero
  /// finishes its animation synchronously inside its own layout and re-dirties
  /// itself, which Flutter asserts against.
  Widget _chromeSize(AppTheme theme, Widget child) {
    final involved = _expressions.isOpen || _panelWasOpen;
    _panelWasOpen = _expressions.isOpen;
    final keyed = KeyedSubtree(key: _chromeKey, child: child);
    if (involved) return keyed;
    return AnimatedSize(
      duration: theme.motionFast,
      curve: theme.motionEntrance,
      alignment: Alignment.bottomCenter,
      child: keyed,
    );
  }

  /// The panel itself, for either chat style.
  Widget _expressionPanel({required double bottomPadding}) {
    // What the expanded level may take: everything but the header, the
    // composer and a strip of conversation, so the room stays recognisably
    // the room you are answering in.
    final mq = MediaQuery.of(context);
    const reserved = 190.0;
    _expressions.setLayout(
      expanded: mq.size.height - mq.padding.top - bottomPadding - reserved,
      // Searching, the composer folds away (see ComposerSearchTakeover) and
      // its row is the panel's too.
      room: mq.size.height -
          mq.padding.top -
          reserved +
          ExpressionPanelController.composerRow,
      keyboardInset: mq.viewInsets.bottom,
      bottomPadding: bottomPadding,
      // Opens at half the screen: a few rows to browse without dragging,
      // and half the conversation still in view.
      resting: mq.size.height * 0.5,
    );
    return ExpressionPanel(
      controller: _expressions,
      composer: _composer,
      onSend: _sendExpression,
      height: _expressions.currentHeight,
      bottomPadding: _expressions.searching ? 0 : bottomPadding,
      // While a panel search has the keyboard, the panel sits above it rather
      // than trading places with it.
      keyboardInset: _expressions.searching
          ? 0
          : MediaQuery.viewInsetsOf(context).bottom,
      onCreateSticker: _createSticker,
      onSearchFocusChanged: _expressions.setSearching,
    );
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
  ///
  /// In the split shell it opens in the side pane beside the chat (see
  /// [RoomSidePane]); asking again for the same person closes it.
  void _openProfile(ChatUser u) {
    if (u.isSystem) return;
    Widget page(BuildContext _) =>
        ProfileScreen(user: u, repo: widget.repo, api: widget.api);
    final pane = RoomSidePane.maybeOf(context);
    if (pane != null) {
      pane.open<void>(page, tag: 'profile:${u.id}');
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: page));
  }

  /// Same uncovered gap as the photo pick, and worse: there is no editor behind
  /// this one to take over the spinner, and a video's bytes are tens of
  /// megabytes to read across the platform channel. The scrim covers the
  /// pick; [_sendVideoFile] takes it from there.
  Future<void> _pickAndSendVideo() async {
    // Captured before the awaits, for the reason the photo pick above gives.
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    _setMediaBusy(true);
    try {
      final pick = await pickVideo();
      if (!mounted) return;
      // Same refusal the photo path handles, and likelier here: a clip is the
      // kind of thing iCloud keeps off the device.
      if (pick.unreadable) {
        toast.show(
          loc.mediaPickFailedMessage,
          tone: ToastTone.danger,
        );
        return;
      }
      final picked = pick.file;
      if (picked == null) return;

      // Web has no filesystem behind an `XFile`: the bytes are all there is,
      // and nothing to re-encode them with. Everywhere else the file goes
      // through the one video rule, path and all.
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        if (videoFateFor(bytes.length, canShrink: false) == VideoFate.refuse) {
          toast.show(loc.videoTooLargeSnack(formatFileSize(kMaxFileUploadBytes)));
          return;
        }
        _sendMedia(
          bytes: bytes,
          type: MessageType.video,
          contentType: videoContentTypeFor(picked.name),
        );
        return;
      }
      _setMediaBusy(false);
      await _sendVideoFile(picked.path);
    } finally {
      _setMediaBusy(false);
    }
  }

  /// One video from this device's files. See [_sendVideoFiles].
  Future<void> _sendVideoFile(
    String path, {
    int? durationMs,
    Uint8List? poster,
    bool confirm = true,
    bool deleteAfter = false,
  }) =>
      _sendVideoFiles(
        [
          _OutgoingVideo(
            path,
            durationMs: durationMs,
            poster: poster,
            ownsFile: deleteAfter,
          ),
        ],
        confirm: confirm,
      );

  /// Every video that reaches a chat from this device's files goes through
  /// here: a gallery pick, the camera strip's recents, a clip recorded in the
  /// camera, the videos in a share. One rule for all of them, per video
  /// ([planVideoBatch]):
  ///
  ///  * at or under [kMaxFileUploadBytes], sent as it is;
  ///  * over it, re-encoded to fit by [VideoShrink], after the sender is told
  ///    it will look worse ([confirm] false skips the asking, for a clip the
  ///    sender just recorded, who has nothing else to choose instead);
  ///  * over it and too long to fit at any quality, or on a platform with no
  ///    encoder, refused with the size named.
  ///
  /// Asked once per batch, naming how many are over: a share of five clips
  /// with two big ones is one question, and it offers to send just the three
  /// that fit. Sent in the order given.
  ///
  /// Used to be three paths with three answers: the gallery sent anything,
  /// the camera relied on 60 s at 720p staying small, and the file picker
  /// refused. A video between 20 and 48 MB went up whole, and one past 48 MB
  /// became a failed bubble with nothing to retry.
  ///
  /// The re-encode runs without the scrim: it can take a while for a long
  /// clip, and the chat stays usable meanwhile. Files marked
  /// [_OutgoingVideo.ownsFile] are deleted once done with, sent or not.
  Future<void> _sendVideoFiles(
    List<_OutgoingVideo> videos, {
    bool confirm = true,
  }) async {
    if (videos.isEmpty) return;
    final toast = AppToast.of(context);
    final loc = AppLocalizations.of(context);
    final cap = formatFileSize(kMaxFileUploadBytes);
    try {
      final sizes = <int>[];
      for (final v in videos) {
        try {
          sizes.add(await File(v.path).length());
        } catch (_) {
          sizes.add(-1);
        }
      }
      if (!mounted) return;
      final plan = planVideoBatch(sizes, canShrink: VideoShrink.supported);
      if (plan.unreadable.isNotEmpty) {
        toast.show(loc.mediaPickFailedMessage, tone: ToastTone.danger);
      }
      if (plan.refuse.isNotEmpty) toast.show(loc.videoTooLargeSnack(cap));

      var shrink = plan.shrink;
      if (shrink.isNotEmpty && confirm) {
        final small = plan.asIs.length;
        final choice = await showIosActionSheet<bool>(
          context,
          title: loc.videoShrinkPromptTitle(shrink.length, cap),
          message: loc.videoShrinkPromptBody(shrink.length),
          actions: [
            IosSheetAction(label: loc.videoShrinkPromptAction, value: true),
            if (small > 0)
              IosSheetAction(
                label: loc.videoShrinkSendSmallOnly(small, cap),
                value: false,
              ),
          ],
        );
        if (choice == null || !mounted) return;
        if (!choice) shrink = const [];
      }

      if (shrink.isNotEmpty) toast.show(loc.videoShrinkWorkingSnack);
      var failed = 0;
      for (var i = 0; i < videos.length; i++) {
        final v = videos[i];
        if (plan.asIs.contains(i)) {
          await _deliverVideo(v, v.path);
        } else if (shrink.contains(i)) {
          final out = await VideoShrink.shrink(v.path);
          if (out == null) {
            failed++;
            continue;
          }
          try {
            await _deliverVideo(v, out);
          } finally {
            try {
              await File(out).delete();
            } catch (_) {}
          }
        }
      }
      if (failed > 0 && mounted) {
        toast.show(
          loc.videoShrinkFailedSnack(failed, cap),
          tone: ToastTone.danger,
        );
      }
    } catch (e) {
      debugPrint('[room] video send: $e');
      if (mounted) toast.show(loc.mediaPickFailedMessage, tone: ToastTone.danger);
    } finally {
      for (final v in videos) {
        if (!v.ownsFile) continue;
        try {
          await File(v.path).delete();
        } catch (_) {}
      }
    }
  }

  /// Reads [sendPath] and sends it as [v]. The poster comes from the original:
  /// same picture, and the original is the file the extractor has already
  /// opened once.
  Future<void> _deliverVideo(_OutgoingVideo v, String sendPath) async {
    final still =
        v.poster ?? (kIsWeb ? null : await VideoPoster.extract(v.path));
    final bytes = await File(sendPath).readAsBytes();
    final contentType = videoContentTypeFor(sendPath);
    if (mounted) {
      _sendMedia(
        bytes: bytes,
        type: MessageType.video,
        contentType: contentType,
        posterBytes: still,
        mediaDurationMs: v.durationMs,
      );
    } else {
      // Left the chat while it was compressing: the send still belongs in
      // it, and the repository does not need this screen to make it.
      widget.repo.sendMediaLocal(
        roomId: widget.roomId,
        bytes: bytes,
        contentType: contentType,
        type: MessageType.video,
        posterBytes: still,
        mediaDurationMs: v.durationMs,
      );
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
    final toast = AppToast.of(context);
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
        toast.show(
          AppLocalizations.of(context).roomScreenFileReadFailedSnack,
          tone: ToastTone.danger,
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
        toast.show(
          AppLocalizations.of(context).roomScreenFileSizeCapSnack(
            formatFileSize(kMaxFileUploadBytes),
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

    /// Sent as a spoiler: under dust for everyone until tapped.
    bool mediaSpoiler = false,

    /// What the sender wrote under a photo in the composer.
    String? caption,

    /// The album this item is sent in, shared by every item of one send.
    String? albumId,

    /// A reply target the caller has already taken off the composer, for a
    /// send that decides itself which of its items carries the reply. Used
    /// instead of the composer's.
    ChatMessage? replyTo,
    int? replyToAlbumCount,
  }) {
    // Snapshot and disarm up front — see _send. Deliberately NOT restored on
    // failure the way this used to be: the failure now arrives long after the
    // composer has moved on, and re-arming a reply target under a user who has
    // started typing something else is worse than losing it. Nothing is lost
    // anyway — the reply rides on the pending bubble, so retrying it keeps the
    // tether.
    final replyTarget = replyTo ?? _replyingTo;
    final replyAlbum = replyTo != null ? replyToAlbumCount : _replyAlbum;
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
      replyAlbumCount: replyAlbum,
      albumId: albumId,
      viewOnce: viewOnce,
      mediaSpoiler: mediaSpoiler,
      caption: caption,
    );
    _scrollToBottom();
    _touchShareTarget();
  }

  /// Deletes are permanent and for everyone, so every path asks first: the
  /// same sheet multi-select uses, worded for one message or several.
  Future<bool> _confirmDelete(int count) {
    final l10n = AppLocalizations.of(context);
    return showConfirmSheet(
      context,
      headline: l10n.roomScreenDeleteMessageHeadline(count),
      body: count == 1 ? l10n.roomScreenDeleteConfirmBodyOne : l10n.roomScreenDeleteConfirmBody,
      confirmLabel: l10n.roomScreenDeleteConfirmButton,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Set here rather than at construction because the theme is a
    // `ThemeScope` lookup and can change under a live screen. The controller
    // only reads it while painting, so assigning on every build is free.
    _composer.tint = theme.accent;
    // Remembers how tall the keyboard is, so the expression panel can take
    // exactly its place and nothing above the two moves when they swap.
    _expressions.noteKeyboardInset(MediaQuery.viewInsetsOf(context).bottom);
    final room = _room ?? widget.repo.roomById(widget.roomId);
    if (room == null) return _roomPending(context, widget.repo);
    // timelineFor, not messagesFor: after a jump into old history the
    // transcript renders a detached window of it until the reader scrolls
    // back down to the present. Everything else — threads, receipts, the
    // cache — still reads the live list.
    // ...plus every message whose exit is still playing: the ledger keeps a
    // departed row in the list until its picture has blown away.
    // ...and every message being deleted, until its dust has left.
    final messages = _departures.withGhosts(
      _deletions.withHeld(widget.repo.timelineFor(widget.roomId)),
    );
    _lastTimeline = messages;
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
    final screen = RoomGalleryScope(
      openGallery: _openGallery,
      videoGalleryFor: _videoGalleryFor,
      videoNotesAfter: _videoNotesAfter,
      child: SpeakerScope(
        // A DM hands out no colours at all. Two people, two margins — the layout
        // has already said everything a colour could, and tinting the one
        // incoming bubble would just be a second accent.
        slots: room.isDm ? SpeakerSlots.none : _speakerSlots,
        child: ChatPane(
          // Back (system back, browser back, Esc) unwinds whatever mode the
          // room is in, one per press, before it leaves the room: the
          // expression panel, an edit, a reply, a selection. Each has its own
          // cancel on screen, but a back that walked out of the chat instead of
          // out of the mode would be the wrong kind of surprising, and an edit
          // abandoned that way loses the stashed draft.
          child: PopScope(
            canPop: !_selection.active &&
                !_expressions.isOpen &&
                !_picker.isOpen &&
                _editing == null &&
                _replyingTo == null &&
                !widget.inShellPane,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) {
                _composerFocus.unfocus();
                // Also hides a keyboard left standing with nothing focused.
                dismissSoftKeyboard();
                return;
              }
              if (_picker.isOpen) {
                // Pulled up, back brings it down first, as a drag would.
                if (_picker.isExpanded) {
                  _picker.collapse();
                } else {
                  _picker.close();
                }
              } else if (_expressions.isOpen) {
                _expressions.hide();
              } else if (_editing != null) {
                _cancelEdit();
              } else if (_replyingTo != null) {
                setState(() => _replyingTo = null);
              } else if (_selection.active) {
                _selection.clear();
              } else if (widget.inShellPane) {
                UiSelectionStore.instance.selectRoom(null);
              }
            },
            // Files dragged in from Finder, a browser or any other Mac app
            // land here. The WHOLE screen is the target, header and composer
            // included: "drop it on the conversation" is the instruction
            // nobody has to be given, and a strip along the bottom would be a
            // smaller target for no benefit.
            //
            // Inert on every platform without a desktop drag — see [DropZone]
            // — so this costs iOS and Android one `if` per build.
            child: DropZone(
              onDrop: _deliverDrop,
              policy: _dropPolicy,
              // Zero: the transcript is the LEAST specific target in the app.
              // A chat row in the list beside it outranks it, which is what
              // makes dropping onto a row in the two-pane shell send to that
              // room rather than to the open one.
              priority: 0,
              label: _dropTargetLabel(room),
              borderRadius: BorderRadius.circular(theme.radiusLg),
              // Pulled in so the ring reads as a frame around the conversation
              // rather than as a border on the window — which, in the two-pane
              // shell where this pane runs to the window's edge, is exactly
              // what a flush ring would look like.
              glowInset: const EdgeInsets.all(7),
              child: Scaffold(
                // iOS keyboards have transparent rounded top corners. The
                // body shrinks above the keyboard; the scaffold's full-size
                // backing must still paint the theme through those corners.
                backgroundColor: theme.background,
                body: Stack(
                  children: [
                    theme.backgroundLayer(context),
                    if (chatStyle == ChatStyle.classic)
                      _buildClassic(context, room, messages, items, me)
                    else
                      _buildLiquid(context, room, messages, items, me),
                    // Over the header and the composer, so it can be pulled
                    // up to fill the room.
                    if (_picker.isOpen && !_expressions.isOpen) _pickerSheet(),
                    // Last, so it covers the header and the composer too — a
                    // scrim that dims the transcript but leaves a live attach
                    // button underneath it is an invitation to make the
                    // problem worse.
                    if (_mediaBusy) const BusyScrim(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Live while this room's route is current and its pane is on stage; see
    // [ShortcutBindings]. Newer than the shell's, so ⌘-keys a room answers win
    // over the app-wide ones for as long as it is open.
    return ShortcutBindings(
      bindings: _roomShortcuts(room),
      child: isWebOrDesktop
          ? MessageHoverScope(controller: _hover, child: screen)
          : screen,
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
          // The room's open games. Zero height when there are none.
          ActiveGamesBanner(roomId: room.id, userId: me),
          // Admins only, and zero height with nothing waiting. Above the pins:
          // a pin is part of the conversation, this is a job for the reader.
          RoomSuggestionsBanner(
            pending: _suggestions.pending,
            api: widget.api,
            onReview: _reviewSuggestions,
          ),
          // Zero height with no pins, so no condition is needed here — and
          // unwrapped by ChatColumn, matching GroupCallBanner above.
          PinnedMessageBanner(
            pins: widget.repo.pinsFor(room.id),
            activeIndex: pinIndexForCursor(
              _pinCursor,
              widget.repo.pinsFor(room.id).length,
            ),
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
                widget.repo.pinsFor(room.id).isEmpty &&
                        _suggestions.pending.isEmpty
                    ? 12
                    : 0,
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
            child: _chromeSize(
              theme,
              _selection.active
                  ? _selectionBar(room, me)
                  // A room members cannot post in gets a quiet footer in
                  // the composer's place. See `room_posting_policy.dart`.
                  : !_posting.canPost
                  ? const ReadOnlyComposerFooter()
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
                    albumCount: _replyAlbum,
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
                // Zero-height unless the composer holds a lone emoji that a
                // sticker stands for.
                StickerSuggestions(
                  composer: _composer,
                  onSend: _sendSuggestedSticker,
                ),
                PickedMediaStrip(controller: _picker, onOpen: _openPick),
                ComposerSearchTakeover(
                  controller: _expressions,
                  child: ChatComposerClassic(
                  controller: _composer,
                  focusNode: _composerFocus,
                  ephemeral: room.isEphemeral,
                  onSend: _send,
                  onSchedule: _composerSchedule,
                  scheduledCount: indicator.showsBadge
                      ? widget.repo.pendingScheduledCount(room.id)
                      : 0,
                  onChanged: (_) => widget.repo.noteTyping(),
                  onAttach:
                      attachmentMenuHasRows(_posting) ? _onAttach : null,
                  attachKey: _attachKey,
                  attachHidden: _attachMenuUp,
                  hasAttachments: _picker.hasPicks,
                  hint: _picker.hasPicks
                      ? AppLocalizations.of(context).inlinePickerCommentHint
                      : null,
                  onCamera: _posting
                          .allowsAny(const {PostKind.image, PostKind.video})
                      ? _onCamera
                      : null,
                  capture: _composerCapture,
                  mention: _mention,
                  captureOpenHintRoomId: room.id,
                  onExpressions: _posting.allows(PostKind.sticker)
                      ? () {
                          _picker.close();
                          _expressions.toggle(_composerFocus);
                        }
                      : null,
                  expressionsOpen: _expressions.isOpen && !_expressions.closing,
                  onFieldTap: _expressions.dismiss,
                  onContentInserted: _onKeyboardContent,
                  onEditLast: _editLastOwn,
                  onPasteMedia:
                      DropChannel.canReadClipboard ? _pasteMedia : null,
                ),
                ),
                // The ancestor SafeArea already holds this clear of the home
                // indicator.
                if (_expressions.isOpen) _expressionPanel(bottomPadding: 0),
                if (_picker.isOpen && !_expressions.isOpen)
                  _pickerPanel(bottomPadding: 0),
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
    final suggestions = _suggestions.pending;
    final topChromeH = 60.0 +
        (_gamesOpen ? kGamesBannerHeight : 0.0) +
        (suggestions.isEmpty ? 0.0 : kSuggestionsBannerHeight) +
        (pins.isEmpty ? 0.0 : kPinnedBannerHeight) +
        (translating ? kCompanionStripHeight : 0.0);
    // The BOTTOM chrome is measured, not computed — the exact case the split
    // above exists for, and the one place a constant could not be made to work.
    // In the classic style the composer stack sits in a real `Column` above an
    // `Expanded` transcript, so anything it grows by pushes the list and covers
    // nothing; here it FLOATS over a `Positioned.fill` transcript, and whatever
    // the transcript reserves is the only thing holding the newest bubble clear
    // of the glass.
    //
    // A constant was right for exactly one composer: an empty one, on one line.
    // A second line grows the field UPWARD and put it straight over the last
    // thing anybody said. The reply card, the @-picker and the scheduled pill
    // are the same bug wearing different hats, and they were being triaged one
    // constant at a time — the pill reserved, the other two knowingly not.
    // `MeasureChatBottomInset` below publishes the real height of all of it on
    // the frame it changes, so growth and shrink are one path and nothing has
    // to be remembered.
    final scheduled = widget.repo.scheduledFor(room.id);
    final indicator = SettingsStore.instance.scheduledIndicator;
    // What the FIRST frame spends, before the chrome has been laid out once.
    // Built from the same constants the chrome is, so it lands on the resting
    // height of a one-line composer exactly and a room opens with its newest
    // message already in place rather than correcting itself a frame later.
    // The composer adds the bottom safe area itself, so this must too.
    final bottomChromeEstimate = 60.0 +
        bottomSafe +
        (indicator.showsPill && scheduled.isNotEmpty ? kScheduledPillHeight : 0.0);
    final ChatBottomChrome bottomChrome = (
      inset: _bottomChrome,
      estimate: bottomChromeEstimate,
    );
    final listPadding = EdgeInsets.fromLTRB(
      20,
      // The +12 is breathing room under the HEADER, and only under the header.
      // With a pinned banner present it became a gap between the strip and the
      // first message, which reads as the two belonging to different surfaces —
      // the strip is chrome for the transcript, not a separate panel floating
      // above it. The banner's own 44pt already separates them.
      topSafe +
          topChromeH +
          (pins.isEmpty && suggestions.isEmpty ? 12.0 : 0.0),
      20,
      // Breathing room over the composer and NOTHING else: the chrome's own
      // height is spent inside the list, by the spacer `bottomChrome` buys at
      // its bottom edge. Padding could not do that job — it is a property of
      // the `ListView` widget, so tracking a live height through it would
      // rebuild every bubble in the viewport on every frame of the growth.
      16,
    );
    // BackdropGroup batches the seven BackdropFilters in the chrome (header
    // pill + 2 buttons + composer attach + camera + field + send) into a
    // single rasterization pass — see lib/widgets/liquid_glass.dart.
    return BackdropGroup(
      child: Stack(
        // Unclipped so the expression panel can hang below the keyboard's top
        // edge — see the note on its height in `ExpressionPanel`.
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _messageBody(
              context,
              room,
              messages,
              items,
              me,
              listPadding: listPadding,
              bottomChrome: bottomChrome,
            ),
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
                      typists: widget.repo.typingIn(room.id),
                      onOpenInfo: () => _openRoomInfo(room),
                    ),
                    if (!room.isDm && GroupCallService.maybeInstance != null)
                      GroupCallBanner(
                        api: GroupCallApi(ConvexBackend.instance),
                        service: GroupCallService.instance,
                        roomId: room.id,
                        userId: me,
                      ),
                    // Reserved in `topChromeH` above, when a game is open.
                    // Frosted, the pinned strip's sibling.
                    ActiveGamesBanner(roomId: room.id, userId: me, glass: true),
                    // Reserved in `topChromeH` above, like the pinned strip.
                    RoomSuggestionsBanner(
                      pending: suggestions,
                      api: widget.api,
                      onReview: _reviewSuggestions,
                      glass: true,
                    ),
                    // Frosted here, not opaque: in this style the chrome floats
                    // over the transcript rather than sitting in a column above
                    // it, and `topChromeH` above has already reserved its space.
                    PinnedMessageBanner(
                      pins: pins,
                      activeIndex: pinIndexForCursor(_pinCursor, pins.length),
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
            // Everything inside is what the transcript reserves for, measured
            // as one box: the composer, whichever card is above it, the
            // @-picker, the scheduled pill, the selection bar that replaces the
            // lot — and the bottom safe area, which the liquid composer adds
            // itself.
            //
            // Measured TWICE, outside the growth animation and in, because the
            // two answers differ on every frame of it and the transcript needs
            // both — see [ChatChromeHeight]. Neither wrapper affects layout;
            // they are proxies that report the size their child already had.
            child: MeasureChatBottomInset(
              inset: _bottomChrome,
              which: ChatChromeHeight.drawn,
              child: ChatColumn(
              // See the classic composer: grows the reply card up out of the
              // bar instead of snapping the bar taller.
              child: _chromeSize(
                theme,
                MeasureChatBottomInset(
                  inset: _bottomChrome,
                  which: ChatChromeHeight.target,
                  child: _selection.active
                    ? _selectionBar(room, me)
                    // Mirrors the classic column above.
                    : !_posting.canPost
                    ? ReadOnlyComposerFooter(
                        glass: true,
                        bottomInset: bottomSafe,
                      )
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
                    albumCount: _replyAlbum,
                    api: widget.api,
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
                if (_mention.isOpen)
                  MentionPicker(session: _mention, api: widget.api),
                // Mirrors the classic column above. Its space, like the reply
                // card's and the picker's, comes out of the measured chrome
                // height — see the note by `bottomChromeEstimate`.
                if (indicator.showsPill && scheduled.isNotEmpty)
                  ScheduledPill(
                    scheduled: scheduled,
                    onTap: _openScheduledList,
                  ),
                // Mirrors the classic column above.
                StickerSuggestions(
                  composer: _composer,
                  onSend: _sendSuggestedSticker,
                ),
                PickedMediaStrip(controller: _picker, onOpen: _openPick),
                ComposerSearchTakeover(
                  controller: _expressions,
                  child: ChatComposerLiquid(
                  controller: _composer,
                  focusNode: _composerFocus,
                  ephemeral: room.isEphemeral,
                  onSend: _send,
                  onSchedule: _composerSchedule,
                  scheduledCount: indicator.showsBadge
                      ? widget.repo.pendingScheduledCount(room.id)
                      : 0,
                  onChanged: (_) => widget.repo.noteTyping(),
                  onAttach:
                      attachmentMenuHasRows(_posting) ? _onAttach : null,
                  attachKey: _attachKey,
                  attachHidden: _attachMenuUp,
                  hasAttachments: _picker.hasPicks,
                  hint: _picker.hasPicks
                      ? AppLocalizations.of(context).inlinePickerCommentHint
                      : null,
                  onCamera: _posting
                          .allowsAny(const {PostKind.image, PostKind.video})
                      ? _onCamera
                      : null,
                  capture: _composerCapture,
                  mention: _mention,
                  captureOpenHintRoomId: room.id,
                  onExpressions: _posting.allows(PostKind.sticker)
                      ? () {
                          _picker.close();
                          _expressions.toggle(_composerFocus);
                        }
                      : null,
                  expressionsOpen: _expressions.isOpen && !_expressions.closing,
                  onFieldTap: _expressions.dismiss,
                  onContentInserted: _onKeyboardContent,
                  onEditLast: _editLastOwn,
                  onPasteMedia:
                      DropChannel.canReadClipboard ? _pasteMedia : null,
                  // With the panel open the composer is no longer the lowest
                  // thing on screen, so the home-indicator inset moves down to
                  // the panel rather than opening a gap between the two.
                  padding: _expressions.isOpen || _picker.isOpen
                      ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
                      : null,
                ),
                ),
                if (_expressions.isOpen)
                  _expressionPanel(bottomPadding: bottomSafe),
                if (_picker.isOpen && !_expressions.isOpen)
                  _pickerPanel(bottomPadding: bottomSafe),
              ],
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
  ///
  /// In the split shell it opens in the side pane beside the chat rather than
  /// over the whole window (see [RoomSidePane]); the jump comes back the same
  /// way, and the info button toggles it.
  Future<void> _openRoomInfo(ChatRoom room, {bool openChangeRequests = false}) async {
    Widget page(BuildContext _) => RoomInfoScreen(
          roomId: room.id,
          repo: widget.repo,
          api: widget.api,
          openChangeRequests: openChangeRequests,
        );
    final pane = RoomSidePane.maybeOf(context);
    final jump = pane != null
        // A request to review suggestions always lands; only a plain info
        // tap toggles.
        ? await pane.open<ChatMessage>(page,
            tag: openChangeRequests ? null : 'info:${room.id}')
        : await Navigator.of(context).push<ChatMessage>(
            MaterialPageRoute(builder: page),
          );
    // Room Info is where suggestions were answered before the strip existed,
    // and still can be — so whatever happened there, the strip re-reads.
    if (mounted) unawaited(_suggestions.refresh());
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

  /// Suggestions waiting on this reader, if they are an admin here. See
  /// [RoomSuggestionQueue] for why this is a fetch and not a subscription.
  late final RoomSuggestionQueue _suggestions =
      RoomSuggestionQueue.forRoom(widget.repo, widget.roomId);

  /// The strip grows and shrinks the top chrome, which the liquid style
  /// reserves transcript padding for — so its arrival is a rebuild here, not
  /// just inside the strip.
  void _onSuggestions() {
    if (mounted) setState(() {});
  }

  /// The strip's one action: straight to the review sheet, over the room.
  Future<void> _reviewSuggestions() async {
    await showRoomChangeRequestsSheet(
      context,
      repo: widget.repo,
      api: widget.api,
      roomId: widget.roomId,
    );
    if (mounted) unawaited(_suggestions.refresh());
  }

  Widget _messageBody(
    BuildContext context,
    ChatRoom room,
    List<ChatMessage> messages,
    List<RoomItem> items,
    String me, {
    required EdgeInsets listPadding,
    // The chrome floating over the transcript's bottom edge, for the styles
    // that have any. Null in the classic style, where the composer stack sits
    // in a real `Column` above an `Expanded` transcript and the viewport
    // already shrinks by exactly the right amount — and then this costs a
    // branch, no listener and no extra row. See `chat_bottom_inset.dart`.
    ChatBottomChrome? bottomChrome,
    bool showTypingRow = true,
  }) {
    final theme = ThemeScope.of(context);
    // `hasLiveMessages`, NOT `hasLoadedInitial`. The weaker flag flips true the
    // moment the subscription REGISTERS — a local, instant operation, by its
    // own admission at the call site — so on any real network it was already
    // true before a single message had landed, and the spinner this branch
    // used to draw was unreachable. What the reader actually saw was "no
    // messages yet", about a conversation that was still on its way.
    //
    // The stronger flag means the server has spoken. It never becomes true
    // offline, which is exactly why the wait below is bounded rather than
    // open-ended: see [PendingPlaceholder].
    final serverAnswered = widget.repo.hasLiveMessages(widget.roomId);
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
    // The floating chrome's own height, spent INSIDE the list rather than as
    // padding on it. `reverse: true` makes index 0 the bottom of the
    // transcript, so a spacer there is layout-identical to leading padding —
    // with the one difference that matters: the spacer owns its height through
    // a notifier, so a composer growing a line relayouts the sliver and
    // rebuilds one `SizedBox`, instead of rebuilding every bubble in the
    // viewport the way a new `padding` on the `ListView` would.
    final insetRows = bottomChrome == null ? 0 : 1;
    // The list's own bottom padding sits BELOW the spacer, so it reads as the
    // gap between the glass and the newest bubble — which is what it is.
    Widget insetSpacer() => ChatBottomInsetBuilder(
          chrome: bottomChrome,
          builder: (context, inset, _) => SizedBox(height: inset),
        );
    Widget typingRow() => TypingRow(
          typists: widget.repo.typingIn(room.id),
          api: widget.api,
          showAvatars: !room.isDm,
        );
    // Recorded for _recomputePositionState — must match the Positioned.top
    // applied to the chip below so the overlap math reflects the real rect.
    _chipRestingY = listPadding.top + 4;
    // The liquid style floats its header and composer OVER the list, and pays
    // for them in padding and in the inset spacer; classic has neither over it.
    _topChromeOverList = bottomChrome == null ? 0 : listPadding.top;
    _bottomChromeOverList = bottomChrome == null
        ? 0
        : bottomChrome.inset.height ?? bottomChrome.estimate;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Dismisses the soft keyboard when you tap the transcript — and the
      // emoji/GIF/sticker panel, which stands in the keyboard's place and has
      // to leave the same way. The panel holds no focus, so unfocusing alone
      // left it standing. On desktop there is no soft keyboard to dismiss, and
      // stealing focus there would silently break Enter-to-send after any
      // click in the conversation, so a desktop click only ever closes the
      // panel.
      onTap: isPhysicalKeyboardPlatform && !_expressions.isOpen
          ? null
          : () {
              _expressions.hide();
              _picker.close();
              if (!isPhysicalKeyboardPlatform) dismissSoftKeyboard();
            },
      child: messages.isEmpty
          ? Stack(
              children: [
                Positioned.fill(
                  child: PendingPlaceholder(
                    pending: !serverAnswered,
                    // A transcript's own silhouette rather than a spinner in
                    // the middle of the screen. A spinner says "something is
                    // happening"; this says "your messages are coming, and
                    // they will be about here" — and because it occupies the
                    // space the answer will, the screen settles once instead
                    // of jumping when the backlog lands.
                    loading: (context) => ChatBottomInsetBuilder(
                      chrome: bottomChrome,
                      builder: (context, inset, child) => Padding(
                        padding: EdgeInsets.only(
                          left: listPadding.left + 8,
                          right: listPadding.right + 8,
                          bottom: listPadding.bottom + inset + 8,
                        ),
                        child: child,
                      ),
                      child: const SkeletonBubbles(),
                    ),
                    empty: (context) => room.isEphemeral
                        ? _SecretSpaceWelcome(ttl: room.messageLifetime)
                        : const _NoMessagesPlaceholder(),
                  ),
                ),
                // There is no list to append to yet, but a DM where the other
                // person types first is exactly the moment you want to see it.
                if (showTypingRow)
                  Positioned(
                    left: listPadding.left,
                    right: listPadding.right,
                    bottom: 0,
                    child: ChatBottomInsetBuilder(
                      chrome: bottomChrome,
                      builder: (context, inset, child) => Padding(
                        padding:
                            EdgeInsets.only(bottom: listPadding.bottom + inset),
                        child: child,
                      ),
                      child: ChatColumn(child: typingRow()),
                    ),
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
                  child: TimelineListView(
                  key: _listViewportKey,
                  controller: _scroll,
                  preserveAtStart: widget.repo.inHistoryWindow(room.id),
                  padding: listPadding,
                  rowKeys: [
                    if (insetRows == 1) const ValueKey('timeline-inset'),
                    if (typingRows == 1) const ValueKey('timeline-typing'),
                    for (final item in items)
                      ValueKey(switch (item) {
                        MessageItem() => 'message:${_arrivals.keyFor(item.message)}',
                        DateDividerItem() => 'date:${item.label}',
                        ThreadFoldItem() => 'fold:${item.threadKey}:${item.oldestHiddenId}',
                        UnreadDividerItem() => 'unread',
                        IntroItem() => 'intro',
                        _ => throw StateError('Unknown transcript row ${item.runtimeType}'),
                      }),
                  ],
                  itemBuilder: (context, i) {
                    // reverse: true — index 0 is the BOTTOM of the transcript.
                    // The glass floats over exactly that edge, so its measured
                    // height goes first and everything else stands on top of
                    // it, typing row included.
                    if (insetRows == 1 && i == 0) {
                      return insetSpacer();
                    }
                    // Still the bottom of the conversation, which is where a
                    // message that hasn't been sent yet belongs.
                    if (typingRows == 1 && i == insetRows) {
                      return typingRow();
                    }
                    final item = items[i - typingRows - insetRows];
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
                      //
                      // Handed the list's own side padding because it is the
                      // one row that draws through it — see [_UnreadDivider].
                      return KeyedSubtree(
                        key: _unreadDividerKey,
                        child: _UnreadDivider(bleed: listPadding),
                      );
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
                // Same read-every-build posture: the pins subscription notifies
                // the repository, so pinning marks the bubble on the next frame.
                final pinned = widget.repo.isMessagePinned(room.id, m.id);
                final isPending = m.id.startsWith('tmp_');
                final selecting = _selection.active;
                // Every menu gate in one object — the predicates that used to
                // be derived inline here (and re-derived, by hand, in
                // ThreadOverlay) live in `message_capabilities.dart` now.
                final caps = widget.repo.capabilitiesForMessage(m, room,
                    senderIsSystem: _members[m.senderId]?.isSystem ?? false);
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
                ///
                /// [at] is a mouse's: the compact pointer menu opens there
                /// instead of the long-press overlay, with the same rows and
                /// the same answers below. [reactionsOnly] is the hover
                /// strip's react button, which wants the emoji row alone.
                Future<void> longPressOn(
                  ChatMessage target, {
                  GlobalKey? anchorKey,
                  Offset? at,
                  bool reactionsOnly = false,
                }) async {
                  final pointer = at != null;
                  _hover.dismiss();
                  if (!pointer) {
                    HapticFeedback.mediumImpact();
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                  final toast = AppToast.of(context);
                  final anchor = anchorKey ??
                      _dateTracks['m_${_rowOwner(target.id)}']?.key;
                  if (anchor == null && !pointer) return;
                  // This photo's own reactions; an album's first message also
                  // carries the album's, flagged, which belong to "All".
                  final myReactions = {
                    for (final r in target.reactions)
                      if (r.userId == me && !r.album) r.emoji,
                  };
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
                  //
                  // INFO is the receipts screen the start-edge swipe opens,
                  // on exactly the messages that swipe is enabled for, so a
                  // mouse (which cannot swipe) reaches it too.
                  final targetPending = target.id.startsWith('tmp_');
                  final capabilities = widget.repo
                      .capabilitiesForMessage(target, room)
                      .copyWith(
                        canTranslate:
                            Sebastian.instance.isAvailable ? null : false,
                        canViewReceipts: target.senderId == me &&
                            !targetPending &&
                            !_selection.active &&
                            target.status == MessageStatus.sent &&
                            target.type != MessageType.system,
                      );
                  // An album card's menu opens on the whole album, with a
                  // switch to the pressed photo alone. Its "All" side offers
                  // what can be done to every item at once.
                  final albumRow = messageItem.album.length > 1
                      ? messageItem.album
                      : null;
                  MessageMenuAlbum? albumMenu;
                  if (albumRow != null) {
                    final first = albumRow.first;
                    final firstCaps =
                        widget.repo.capabilitiesForMessage(first, room);
                    final l10n = AppLocalizations.of(context);
                    albumMenu = MessageMenuAlbum(
                      allLabel: l10n.messageMenuAlbumAll(albumRow.length),
                      oneLabel: l10n.messageMenuAlbumOne,
                      capabilities: MessageCapabilities.none.copyWith(
                        canReply: firstCaps.canReply,
                        canReact: firstCaps.canReact,
                        canForward: albumRow.every((m) => widget.repo
                            .capabilitiesForMessage(m, room)
                            .canForward),
                        canDelete: albumRow.every((m) => widget.repo
                            .capabilitiesForMessage(m, room)
                            .canDelete),
                      ),
                      myReactions: {
                        for (final r in first.reactions)
                          if (r.userId == me && r.album) r.emoji,
                      },
                      // The whole pile, lifted, while "All" is chosen: the
                      // album's own deck with the pressed card in front,
                      // laid out so that card covers exactly the rect it was
                      // pressed in and the others peek out past it. Cards
                      // only; a grid's tile stays a tile.
                      stackBuilder: !SettingsStore.instance.albumCards
                          ? null
                          : (menuContext) {
                              final radius = BorderRadius.circular(
                                  ThemeScope.of(menuContext).radiusLg);
                              final inset = PhotoDeck.inset(albumRow.length);
                              return LayoutBuilder(
                                builder: (_, box) => Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Positioned(
                                      left: -inset,
                                      top: 0,
                                      width: box.maxWidth + 2 * inset,
                                      height: box.maxHeight,
                                      child: PhotoDeck(
                                        photos: albumRow,
                                        api: widget.api,
                                        width: box.maxWidth + 2 * inset,
                                        radius: radius,
                                        currentUserId: me,
                                        highlightedPhotoId: target.id,
                                        onOpen: (_, {required sourceDecodeWidth}) {},
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                    );
                  }
                  final MessageActionResult? result;
                  if (pointer) {
                    result = await showMessageContextMenu(
                      context: context,
                      position: at,
                      capabilities: capabilities,
                      myReactions: myReactions,
                      reactionsOnly: reactionsOnly,
                      // Same gate the reaction chips' own toggle sits behind:
                      // nothing to react to on a send still in flight.
                      showReactions: !targetPending &&
                          target.type != MessageType.system &&
                          capabilities.canReact,
                      isPinned:
                          widget.repo.isMessagePinned(room.id, target.id),
                      isSaved: widget.repo.isMessageSaved(room.id, target.id),
                      isTranslated:
                          Sebastian.instance.isShowingTranslation(target),
                      fileName: target.type == MessageType.file
                          ? target.fileName
                          : null,
                      album: albumMenu,
                    );
                  } else {
                  result = await showMessageActionMenu(
                    context: context,
                    anchorKey: anchor!,
                    isMine: isMine,
                    myReactions: myReactions,
                    capabilities: capabilities,
                    isPinned: widget.repo.isMessagePinned(room.id, target.id),
                    isSaved: widget.repo.isMessageSaved(room.id, target.id),
                    isTranslated:
                        Sebastian.instance.isShowingTranslation(target),
                    // The transcript row holds a document's name to one line;
                    // this is where the whole thing is legible.
                    fileName:
                        target.type == MessageType.file ? target.fileName : null,
                    album: albumMenu,
                    // A photo or video, alone or a card of an album, lifts
                    // smaller than it sits: at full size it and the menu
                    // together outgrow the screen.
                    previewMaxHeight: albumRow != null ||
                            target.type == MessageType.image ||
                            target.type == MessageType.video
                        ? 220
                        : null,
                    bubbleBuilder: (menuContext) {
                      // A card (or grid tile) of an album lifts as itself:
                      // the same crop, corners and play button, at the rect
                      // it was pressed in. The lone-photo bubble it used to
                      // lift is sized from the photograph's own ratio, and
                      // overflowed the card-sized slot the menu gives it.
                      if (messageItem.album.length > 1) {
                        final theme = ThemeScope.of(menuContext);
                        return LayoutBuilder(
                          builder: (_, box) => ClipRRect(
                            borderRadius:
                                BorderRadius.circular(theme.radiusLg),
                            child: MosaicTile(
                              anchor: GlobalKey(),
                              message: target,
                              api: widget.api,
                              theme: theme,
                              side: box.maxWidth,
                              radius: BorderRadius.circular(theme.radiusLg),
                              highlightT: 0,
                              currentUserId: me,
                              onOpen: (_) {},
                            ),
                          ),
                        );
                      }
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
                      // The lifted copy is the bubble alone. A compact reply
                      // marker is an accent line drawn ABOVE the bubble, part
                      // of the row's context, and floating it over the blur
                      // read as a stray line. A full quote card stays: it is
                      // inside the bubble.
                      final shownMarker = sameRow ? replyMarker : ReplyMarker.full;
                      final liftedMarker = shownMarker == ReplyMarker.compact
                          ? ReplyMarker.none
                          : shownMarker;
                      return SpeakerScope(
                        slots: room.isDm ? SpeakerSlots.none : _speakerSlots,
                        // Bottom-aligned in the row's measured rect: without
                        // the marker the bubble is shorter than the row, and
                        // top-aligned it would jump up by the marker's height
                        // as it lifts.
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            target.isEphemeral
                          ? EphemeralMessageBubble(
                              message: target,
                              now: _fadeNow,
                              currentUserId: me,
                              api: widget.api,
                              author: author,
                              parentAuthor: parentAuthor,
                              saved: widget.repo
                                  .isMessageSaved(room.id, target.id),
                              pinned: widget.repo
                                  .isMessagePinned(room.id, target.id),
                              replyMarker: liftedMarker,
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
                              pinned: widget.repo
                                  .isMessagePinned(room.id, target.id),
                              replyMarker: liftedMarker,
                              grouped: sameRow && grouped,
                              lastInRun: !sameRow || messageItem.lastInRun,
                              showAvatarSlot: !room.isDm,
                              showAvatar: showAvatar,
                              senderName: senderName,
                              onOpenViewOnce: () => _openViewOnce(target),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  }
                  if (!mounted || result == null) return;
                  if (result.album && albumRow != null) {
                    await _actOnAlbum(result, albumRow);
                    return;
                  }
                  if (result.emoji != null) {
                    await _toggleReaction(target, result.emoji!);
                    return;
                  }
                  if (result.openFullReactionPicker) {
                    final pick = await pickReaction(
                      this.context,
                      selected: myReactions,
                    );
                    if (pick == null || pick.emoji.isEmpty) return;
                    // A grid pick of one already held is a no-op — choosing
                    // it from a picker means "this one", not "take it back";
                    // the picker's "your reactions" strip is for that.
                    if (!pick.remove && myReactions.contains(pick.emoji)) {
                      return;
                    }
                    await _toggleReaction(target, pick.emoji);
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
                      toast.show(AppLocalizations.of(context)
                              .roomScreenCopiedSnack);
                      break;
                    case MessageAction.copyName:
                      await Clipboard.setData(
                          ClipboardData(text: target.fileName ?? ''));
                      if (!context.mounted) return;
                      toast.show(AppLocalizations.of(context)
                              .roomScreenNameCopiedSnack);
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
                      toast.show(AppLocalizations.of(context)
                              .locationBubbleCoordinatesCopied);
                      break;
                    case MessageAction.translate:
                      await _translateMessage(target, toast);
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
                        toast.show(
                          err == 'PIN_LIMIT_REACHED'
                              ? l10n.roomScreenPinLimitSnack
                              : l10n.roomScreenPinFailedSnack,
                        );
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
                        toast.show(
                          saveErr == 'SAVE_LIMIT_REACHED'
                              ? l10n.roomScreenSaveLimitSnack
                              : l10n.roomScreenSaveFailedSnack,
                        );
                      }
                      break;
                    case MessageAction.unsave:
                      await widget.repo.unsaveMessage(room.id, target.id);
                      break;
                    case MessageAction.delete:
                      if (!await _confirmDelete(1) || !context.mounted) break;
                      _deletions.begin([target]);
                      try {
                        await widget.repo.deleteMessage(target.id);
                      } catch (_) {
                        _deletions.cancel([target.id]);
                        rethrow;
                      }
                      break;
                    case MessageAction.info:
                      _openReceipts(target);
                      break;
                    case MessageAction.viewProfile:
                      if (author != null) _openProfile(author);
                      break;
                    case MessageAction.report:
                      final myId = widget.repo.userId;
                      if (myId == null) return;
                      await fileReport(
                        this.context,
                        api: widget.api,
                        reporterId: myId,
                        target: ReportTarget.message,
                        targetId: target.id,
                      );
                      break;
                    case MessageAction.modRemoveMessage:
                    case MessageAction.modBanUser:
                    case MessageAction.modUnbanUser:
                    case MessageAction.modDismiss:
                      final card = target.moderationCard;
                      if (card == null) return;
                      await runModeratorAction(
                        this.context,
                        api: widget.api,
                        card: card,
                        action: result.action!,
                      );
                      break;
                  }
                }

                Future<void> onLongPress() => longPressOn(m);

                // The mouse's two doors into the same menu: a right-click at
                // the pointer, and the hover strip beside the bubble. Both
                // null on a pending send, exactly like the long-press.
                void onContextMenu(Offset at) => longPressOn(m, at: at);
                final hover = isWebOrDesktop && !isPending && !selecting
                    ? MessageHoverTarget(
                        id: m.id,
                        isMine: isMine,
                        onReact: m.type == MessageType.system ||
                                !caps.canReact
                            ? null
                            : (r) => longPressOn(m,
                                at: r.bottomLeft, reactionsOnly: true),
                        onReply: canReply ? () => _armReply(m) : null,
                        onMore: (r) => longPressOn(m, at: r.bottomLeft),
                      )
                    : null;

                // Parameterised for the reason `longPressOn` is: an album
                // row draws several messages, and a chip on the third
                // photograph belongs to the third photograph.
                void reactionTapOn(ChatMessage target, String e) {
                  _toggleReaction(target, e);
                }

                void onReactionTap(String e) => reactionTapOn(m, e);

                // A tap and a long-press on a chip both land here; the chip
                // plays the haptic that fits the gesture.
                Future<void> reactionLongPressOn(
                    ChatMessage target, String e, {bool? album}) async {
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
                    album: album,
                    // A tap no longer toggles, so the sheet is where your
                    // own reaction is added or taken back.
                    onToggle: caps.canReact
                        ? (emoji) => _toggleReaction(target, emoji,
                            album: album ?? false)
                        : null,
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
                // The identity of the ROW, which is not always the identity of
                // the message: a send is one row that wears two ids, the local
                // `tmp_` one until the server confirms it and the real one
                // after. Keying on `m.id` made that swap look like one row
                // leaving and another arriving — the switcher below cross-faded
                // it, and its entrance played a second time from zero height.
                final rowKey = _arrivals.keyFor(m);
                // Leaving: the whole row — swipes, selection, entrance — is
                // replaced by the exit, which holds the row's height and
                // then closes it. Tracked under the same key so the floating
                // date reads it exactly as it read the bubble.
                final departing = _departures.captureFor(rowKey);
                if (departing != null) {
                  return _trackedDate(
                    stableId: 'm_${m.id}',
                    label: transcriptDay(context, m.createdAt),
                    isDivider: false,
                    child: DepartingRow(
                      key: ValueKey('depart_$rowKey'),
                      capture: departing,
                      calm: MotionScope.of(context).calm,
                      onDone: () => _departures.end(rowKey),
                    ),
                  );
                }
                final bubble = m.isEphemeral
                    ? EphemeralMessageBubble(
                        key: ValueKey('e_${m.id}'),
                        message: m,
                        now: _fadeNow,
                        currentUserId: me,
                        api: widget.api,
                        departures: _departures,
                        rowKey: rowKey,
                        author: author,
                        onLongPress: isPending ? null : onLongPress,
                        onDoubleTap: isPending ? null : onLongPress,
                        onContextMenu: isPending ? null : onContextMenu,
                        hover: hover,
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
                        pinned: pinned,
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
                        onContextMenu: isPending ? null : onContextMenu,
                        hover: hover,
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
                        pinned: pinned,
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
                        // A right-click on a card is that card's menu, at
                        // the pointer, not the row's (the album's last item).
                        onAlbumTileContextMenu: (target, at) {
                          if (target.id.startsWith('tmp_')) return;
                          longPressOn(target, at: at);
                        },
                        onAlbumReactionTap: reactionTapOn,
                        onAlbumReactionLongPress: (target, e) =>
                            reactionLongPressOn(target, e, album: false),
                        onAlbumStackReactionTap: (first, e) =>
                            _toggleReaction(first, e, album: true),
                        onAlbumStackReactionLongPress: (first, e) =>
                            reactionLongPressOn(first, e, album: true),
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
                    key: ValueKey('rc_$rowKey'),
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
                      key: ValueKey('sw_$rowKey'),
                      // A swipe that armed a reply mid-selection would put a
                      // composer card under a bar that has no composer.
                      enabled: canReply && !selecting,
                      onReplyTriggered: () => _armReply(m, haptic: false),
                      child: bubble,
                    ),
                  ),
                );
                final tracked = _trackedDate(
                  stableId: 'm_${m.id}',
                  label: transcriptDay(context, m.createdAt),
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
                );
                // The exit needs to know how tall this row was and where the
                // bubble sat in it; the tracked key is that measurement.
                if (m.isEphemeral) {
                  _departures.registerRowBox(
                    rowKey,
                    _dateTracks['m_${m.id}']!.key,
                  );
                } else {
                  _deletions.registerRow(
                    m.id,
                    messageItem.album.isEmpty
                        ? [m.id]
                        : [for (final p in messageItem.album) p.id],
                    _dateTracks['m_${m.id}']!.key,
                  );
                }
                return ArrivingRow(
                  // Only a row that was not in the transcript a moment ago
                  // plays an entrance; see [MessageArrivals]. Everything else —
                  // a row scrolled back into view, a page of older history, a
                  // re-render after a reaction, and every message the reader
                  // sent themselves — draws at full size on the first frame.
                  key: ValueKey('arrive_$rowKey'),
                  animate: _arrivals.isArriving(rowKey),
                  sent: !MotionScope.of(context).calm &&
                      _arrivals.isSending(rowKey),
                  mine: m.senderId == me,
                  duration: theme.motionMed,
                  curve: theme.motionEntrance,
                  // Always here, so a row that starts to dissolve keeps its
                  // element and burns exactly the frame it last painted.
                  child: DissolvingRow(
                    entry: _deletions.entryFor(m.id),
                    onGone: () => _deletions.end(m.id),
                    child: tracked,
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
                      // Scroll chrome listens locally: changing its date or
                      // yielding to a divider must not rebuild the transcript.
                      child: ValueListenableBuilder<({String? label, bool active, double overlap})>(
                        valueListenable: _datePresentation,
                        builder: (context, value, _) => AnimatedOpacity(
                          opacity: (value.active && value.label != null) ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: Transform.translate(
                            offset: Offset(0, 14 * value.overlap),
                            child: Transform.scale(
                              scale: 1 - 0.08 * value.overlap,
                              child: Opacity(
                                opacity: (1 - value.overlap).clamp(0.0, 1.0),
                                child: _FloatingDateChip(label: value.label ?? ''),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  // Clears the composer in both styles. In liquid the composer
                  // floats OVER this stack and grows with what is typed, so the
                  // offset has to track it live — a hardcoded 12 used to put
                  // the pill behind the glass, and a hardcoded 76 put it behind
                  // the glass again the moment the field wrapped. In classic
                  // the chrome is null, this folds to listPadding.bottom - 8,
                  // and the layout is what it always was.
                  //
                  // The pills go through `child` rather than the builder: both
                  // carry their own entrance animations and have no business
                  // rebuilding because somebody typed a line.
                  child: ChatBottomInsetBuilder(
                    chrome: bottomChrome,
                    builder: (context, inset, child) => Padding(
                      padding: EdgeInsets.only(
                        bottom: math.max(8, listPadding.bottom + inset - 8),
                      ),
                      child: child,
                    ),
                    child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // A warm cache makes the transcript useful before the
                        // server answers, but it can be stale by hours, so say
                        // a refresh is under way. Floated here with the other
                        // pills rather than spent as a list row: a row has to
                        // leave again, and when it did the whole transcript
                        // dropped by its height a beat after the room opened.
                        _TimelineSyncPill(pending: !serverAnswered),
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

/// Shows [_TimelineSyncIndicator] while a cached transcript waits on its first
/// live batch, floated over the list so coming and going moves nothing.
///
/// The usual delay-then-hold pattern for loaders. [showAfter]: a wait shorter
/// than this already reads as instant, so it gets no loader at all. [minShown]:
/// once the pill is up it stays at least this long, because a pill that pops in
/// and straight back out reads as a glitch, not a status. [giveUpAfter]: the
/// same bound [PendingPlaceholder] puts on the empty transcript, so an offline
/// room stops claiming to load.
class _TimelineSyncPill extends StatefulWidget {
  const _TimelineSyncPill({required this.pending});

  final bool pending;

  static const showAfter = Duration(milliseconds: 300);
  static const minShown = Duration(milliseconds: 500);
  static const giveUpAfter = Duration(seconds: 8);

  @override
  State<_TimelineSyncPill> createState() => _TimelineSyncPillState();
}

class _TimelineSyncPillState extends State<_TimelineSyncPill> {
  Timer? _show;
  Timer? _giveUp;
  Timer? _hide;
  bool _visible = false;
  final _shownFor = Stopwatch();

  @override
  void initState() {
    super.initState();
    if (widget.pending) _startWaiting();
  }

  @override
  void didUpdateWidget(_TimelineSyncPill old) {
    super.didUpdateWidget(old);
    if (widget.pending == old.pending) return;
    if (widget.pending) {
      _startWaiting();
    } else {
      _show?.cancel();
      _giveUp?.cancel();
      if (!_visible) return;
      // Answered while the pill is up: let it finish its minimum stay.
      final left = _TimelineSyncPill.minShown - _shownFor.elapsed;
      if (left <= Duration.zero) {
        _visible = false;
      } else {
        _hide = Timer(left, () {
          if (mounted) setState(() => _visible = false);
        });
      }
    }
  }

  void _startWaiting() {
    _stopWaiting();
    // Already up (pending again mid-hold): stay up, just rearm the give-up.
    if (!_visible) {
      _show = Timer(_TimelineSyncPill.showAfter, () {
        if (!mounted) return;
        _shownFor
          ..reset()
          ..start();
        setState(() => _visible = true);
      });
    }
    _giveUp = Timer(_TimelineSyncPill.giveUpAfter, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _stopWaiting() {
    _show?.cancel();
    _giveUp?.cancel();
    _hide?.cancel();
    _show = null;
    _giveUp = null;
    _hide = null;
  }

  @override
  void dispose() {
    _stopWaiting();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TransientPillSlot(
        visible: _visible,
        child: const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: _TimelineSyncIndicator(),
        ),
      );
}

/// A brief cue that a cached transcript is being refreshed from the server.
class _TimelineSyncIndicator extends StatelessWidget {
  const _TimelineSyncIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final label = AppLocalizations.of(context).audioMessageLoadingLabel;
    return Semantics(
      liveRegion: true,
      child: LiquidGlass(
        shape: LiquidGlassShape.capsule,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        tinted: true,
        shadow: false,
        semanticLabel: label,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.accent,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: theme.bodySoft.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                ? quietFill(theme)
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
    final status = roomHeaderStatus(
      context,
      room: room,
      dmUser: dmUser,
      typists: typing,
    );
    // The same anatomy as the floating header — glass back, face, name over a
    // status line, calls — on a solid bar with a hairline, which is what
    // "classic" means now. The old visibility pill, the "N INSIDE" chip and
    // the separate typing row all collapse into the one status line. The rule
    // stays full-bleed while the content shares the chat column.
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.divider,
            width: 1 / MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      ),
      child: ChatColumn(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Row(
            children: [
              // THE back control — the same 40pt chevron the liquid header
              // wears, so the two chat styles can't drift apart.
              GlassBackButton(
                closes: context.usesSplitShell,
                onTap: () => _roomBack(context),
              ),
              const SizedBox(width: 10),
              if (room.isSavedMessages)
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: quietFill(theme),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.bookmark_fill,
                    size: 17,
                    color: theme.accent,
                  ),
                )
              else if (dmUser != null)
                FocusableTap(
                  onTap: onTapPeer,
                  semanticLabel: AppLocalizations.of(context)
                      .roomScreenViewProfilePictureSemantic,
                  shape: FocusRingShape.circle,
                  child: GestureDetector(
                    onTap: onTapPeer,
                    child: UserAvatar(user: dmUser!, size: 36, api: api),
                  ),
                )
              else
                _RoomAvatar(room: room, api: api, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: FocusableTap(
                  onTap: onOpenInfo,
                  semanticLabel: room.isSavedMessages
                      ? AppLocalizations.of(context).savedMessagesTitle
                      : (dmUser?.displayName ?? room.name),
                  radius: theme.radiusSm,
                  child: GestureDetector(
                    onTap: onOpenInfo,
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.isSavedMessages
                              ? AppLocalizations.of(context).savedMessagesTitle
                              : (dmUser?.displayName ?? room.name),
                          style: theme.body.copyWith(
                            fontSize: 17,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: theme.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        ?status,
                      ],
                    ),
                  ),
                ),
              ),
              if (!caps.canCall)
                const SizedBox.shrink()
              else if (room.isDm && dmUser != null) ...[
                CallButton(
                  peerUserId: dmUser!.id,
                  peerName: dmUser!.displayName,
                  peerAvatarStorageId: dmUser!.avatarStorageId,
                  roomId: room.id,
                  variant: CallButtonVariant.liquid,
                  kind: CallMediaKind.video,
                ),
                const SizedBox(width: 6),
                CallButton(
                  peerUserId: dmUser!.id,
                  peerName: dmUser!.displayName,
                  peerAvatarStorageId: dmUser!.avatarStorageId,
                  roomId: room.id,
                  variant: CallButtonVariant.liquid,
                  kind: CallMediaKind.audio,
                ),
              ] else ...[
                GroupCallButton(
                  roomId: room.id,
                  liquid: true,
                  kind: CallMediaKind.video,
                ),
                const SizedBox(width: 6),
                GroupCallButton(
                  roomId: room.id,
                  liquid: true,
                  kind: CallMediaKind.audio,
                ),
              ],
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
            // As the owner wrote it — no runtime lowercasing of someone
            // else's words.
            Text('"${room.description!}"', style: theme.bodyEmph),
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
                    style: groupedSubtitleStyle(theme).copyWith(
                      color: theme.accent,
                    ),
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
                  style: groupedMetaStyle(theme).copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.inkSoft,
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
    return Text(
      label,
      style: theme.bodySoft.copyWith(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: theme.inkSoft,
      ),
    );
  }
}

/// A soft pill in the page's own ink, no outline — Telegram's day marker. It
/// used to be an accent-tinted, bordered capsule with a calendar glyph and
/// tracked capitals, which made every day boundary the loudest thing on
/// screen.
BoxDecoration _dateChipDecoration(AppTheme theme, {List<BoxShadow>? shadow}) =>
    BoxDecoration(
      color: Color.alphaBlend(
        theme.ink.withValues(alpha: 0.08),
        theme.background,
      ).withValues(alpha: 0.92),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: _dateChipDecoration(theme),
          child: _DateChipContent(label: label),
        ),
      ),
    );
  }
}

/// Marks where a reader's backlog starts — a band drawn edge to edge rather
/// than a centred pill, deliberately: a pill reads as a date marker in this app
/// (see `_ThreadFoldChip`'s own note on the same rule), and this is answering a
/// different question — not "what day is it" but "everything below this line
/// is new". [_RoomScreenState._maybeLandOnUnread] is what puts it on screen
/// on open; this widget only draws it.
///
/// It is also the only row in the transcript that ignores the list's side
/// padding. `width: double.infinity` alone stopped it 20pt short at each end,
/// which reads as one more object floating in the column — a rule drawn across
/// the conversation has to actually reach both sides of it to say "line".
class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider({required this.bleed});

  /// The transcript's own padding. Only [EdgeInsets.left] and
  /// [EdgeInsets.right] are read; the band is handed the whole thing so the
  /// call site can pass `listPadding` without picking it apart.
  final EdgeInsets bleed;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final band = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: quietFill(theme),
        border: Border.symmetric(
          horizontal: BorderSide(color: theme.divider),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        AppLocalizations.of(context).roomScreenUnreadDivider,
        style: theme.bodySoft.copyWith(
          fontSize: 13,
          color: theme.accent,
          letterSpacing: 0,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return Padding(
      // Top only — see [MessageGap], same convention _DateDivider follows.
      padding: const EdgeInsets.only(top: MessageGap.aroundMarker),
      child: EdgeBleed(bleed: bleed, child: band),
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
/// a shadow that lifts it off the messages.
///
/// Not blurred. The chip lives inside two animating opacities (it fades in
/// with the scroll and yields to a divider by fading), and a BackdropFilter
/// in a fading layer blurs the layer's empty buffer instead of the
/// transcript: the frost dropped out for every frame of a fade and snapped
/// back at its end. Under a 92% fill the blur was barely there anyway, and
/// without it the chip is the same surface as the divider it hands off to.
class _FloatingDateChip extends StatelessWidget {
  const _FloatingDateChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: _dateChipDecoration(theme, shadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.16),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ]),
      child: _DateChipContent(label: label),
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
                          // True wherever this renders: a platform that can't
                          // block capture never opens a secret room (see
                          // SecretRoomGate).
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
                      style: groupedTitleStyle(theme).copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: groupedMetaStyle(theme)),
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
                style: groupedTitleStyle(theme).copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: groupedMetaStyle(theme),
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
            color: quietFill(theme),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.divider),
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

/// The line under a conversation's name, shared by both headers: typing,
/// else online for a DM, else the member count for a group. Null when there
/// is nothing true to say — a DM with someone offline shows their name alone
/// rather than a guess.
Widget? roomHeaderStatus(
  BuildContext context, {
  required ChatRoom room,
  required ChatUser? dmUser,
  required List<ChatUser> typists,
}) {
  final theme = ThemeScope.of(context);
  final l10n = AppLocalizations.of(context);
  // 13 on the body face: the caption slot is tracked mono on a character
  // theme, and "typing…" read as terminal output under the name.
  final base = theme.bodySoft.copyWith(
    fontSize: 13,
    height: 1.2,
    letterSpacing: 0,
  );
  final String text;
  var color = theme.inkMuted;
  if (typists.isNotEmpty) {
    // In a DM the name is the line above, so the verb alone; a group needs
    // to say who.
    text = dmUser != null && typists.length == 1
        ? l10n.roomHeaderStatusTyping
        : typingLabel(context, typists);
    color = theme.accent;
  } else if (room.isSavedMessages) {
    return null;
  } else if (dmUser != null) {
    if (dmUser.status != 'online') return null;
    text = l10n.roomHeaderStatusOnline;
    color = theme.success;
  } else if (room.isGroupChat) {
    text = l10n.roomHeaderStatusMembers(room.memberCount);
  } else {
    return null;
  }
  return AnimatedSwitcher(
    duration: const Duration(milliseconds: 220),
    child: Text(
      text,
      key: ValueKey(text),
      style: base.copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

/// The conversation header on its own, for design previews. [classic] picks
/// the solid-bar header the classic chat style uses.
@visibleForTesting
Widget debugRoomHeader({
  required ChatRoom room,
  required ChatApi api,
  required RoomCapabilities caps,
  ChatUser? dmUser,
  List<ChatUser> typists = const [],
  bool classic = false,
}) =>
    classic
        ? _Header(
            room: room,
            typing: typists,
            onOpenInfo: () {},
            api: api,
            caps: caps,
            dmUser: dmUser,
          )
        : _LiquidHeader(
      room: room,
      api: api,
      caps: caps,
      dmUser: dmUser,
      typists: typists,
      onOpenInfo: () {},
    );

class _LiquidHeader extends StatelessWidget {
  const _LiquidHeader({
    required this.room,
    required this.api,
    required this.onOpenInfo,
    required this.caps,
    this.dmUser,
    this.typists = const [],
  });
  final ChatRoom room;
  final ChatApi api;
  final VoidCallback onOpenInfo;
  final RoomCapabilities caps;
  final ChatUser? dmUser;

  /// Who is typing right now. Takes over the status line while non-empty —
  /// the place every messenger says it.
  final List<ChatUser> typists;

  /// Avatar diameter inside the title capsule — large enough to be a face,
  /// and to hold a two-line name/status block level beside it.
  static const _avatarSize = kChatHeaderAvatarSize;

  /// Diameter of the round glass controls either side of the title.
  /// Every chrome button is 40pt — the back, and the width reserved for a
  /// missing call control so the title capsule stays centred.
  static const _controlSize = 40.0;

  /// Gap between the two call controls. Tighter than the 12 that separates
  /// them from the title capsule, so the pair reads as one group rather than
  /// two unrelated buttons.
  static const _controlGap = 6.0;

  /// Storage id of the picture behind the capsule's avatar, or null when it is a
  /// gradient-initials or `#` placeholder. Null means no fullscreen route and no
  /// [Hero] — a tag with no counterpart is worse than no tag.
  String? get _avatarStorageId {
    // Which picture the capsule shows follows dmUser, so which picture opens has
    // to follow it too. A `??` chain here would fall back to the room's avatar
    // for a peer who has none, flying someone else's image out of a gradient
    // placeholder.
    final id = dmUser != null ? dmUser!.avatarStorageId : room.avatarStorageId;
    return (id == null || id.isEmpty) ? null : id;
  }

  void _openAvatarFullscreen(BuildContext context) {
    final storageId = _avatarStorageId;
    if (storageId == null) return;
    FullscreenImageViewer.openAvatar(
      context,
      storageId: storageId,
      api: api,
      // Room-keyed: unique inside this route, and deliberately distinct from
      // ProfileScreen's 'profile-avatar-$id' so a push can't collide.
      heroTag: 'room-header-avatar-${room.id}',
      sourceSize: _avatarSize,
    );
  }

  /// The capsule's avatar, wrapped in its own tap target when there is a real
  /// picture behind it.
  ///
  /// The nesting is the point: the inner recognizer enters the gesture arena
  /// first (hit testing runs child-first), so it beats the capsule's opaque
  /// GestureDetector. With no picture nothing is mounted, and the tap falls
  /// through to the capsule's [onOpenInfo] — a placeholder shouldn't swallow
  /// the chip.
  Widget _buildAvatar(BuildContext context) {
    final Widget avatar = room.isSavedMessages
        ? Container(
            width: _avatarSize,
            height: _avatarSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: quietFill(ThemeScope.of(context)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.bookmark_fill,
              size: _avatarSize * 0.45,
              color: ThemeScope.of(context).accent,
            ),
          )
        : dmUser != null
        ? UserAvatar(user: dmUser!, size: _avatarSize, api: api)
        : _RoomAvatar(room: room, api: api, size: _avatarSize);
    if (_avatarStorageId == null) return avatar;
    return FocusableTap(
      onTap: () => _openAvatarFullscreen(context),
      shape: FocusRingShape.circle,
      semanticLabel: dmUser != null
          ? AppLocalizations.of(context).roomScreenViewProfilePictureSemantic
          : AppLocalizations.of(context).roomScreenViewRoomPictureSemantic,
      child: GestureDetector(
        onTap: () => _openAvatarFullscreen(context),
        child: SteadyHero(
          tag: 'room-header-avatar-${room.id}',
          child: avatar,
        ),
      ),
    );
  }

  /// The controls right of the title: video call, then voice call, both
  /// always on show. Room Info has no button of its own here — the title
  /// capsule is its tap target.
  List<Widget> _buildCallControls() {
    // See the classic header: no one to call in a chat with only yourself,
    // and no one home in a chat with the app. Keep one control's width
    // reserved anyway, so the capsule stays centred between the back button
    // and this edge instead of drifting right by half a control.
    if (!caps.canCall) {
      return const [SizedBox(width: _controlSize)];
    }
    if (room.isDm && dmUser != null) {
      return [
        CallButton(
          peerUserId: dmUser!.id,
          peerName: dmUser!.displayName,
          peerAvatarStorageId: dmUser!.avatarStorageId,
          roomId: room.id,
          variant: CallButtonVariant.liquid,
          kind: CallMediaKind.video,
        ),
        const SizedBox(width: _controlGap),
        CallButton(
          peerUserId: dmUser!.id,
          peerName: dmUser!.displayName,
          peerAvatarStorageId: dmUser!.avatarStorageId,
          roomId: room.id,
          variant: CallButtonVariant.liquid,
          kind: CallMediaKind.audio,
        ),
      ];
    }
    return [
      GroupCallButton(roomId: room.id, liquid: true, kind: CallMediaKind.video),
      const SizedBox(width: _controlGap),
      GroupCallButton(roomId: room.id, liquid: true, kind: CallMediaKind.audio),
    ];
  }

  Widget? _status(BuildContext context) =>
      roomHeaderStatus(context, room: room, dmUser: dmUser, typists: typists);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final title = room.isSavedMessages
        ? AppLocalizations.of(context).savedMessagesTitle
        : (dmUser?.displayName ?? room.name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The iOS 26 toolbar back — THE shared one, 40pt, a chevron in the
          // label colour (the accent arrow was Material's).
          GlassBackButton(
                closes: context.usesSplitShell,
                onTap: () => _roomBack(context),
              ),
          const SizedBox(width: 12),
          Expanded(
            // LiquidGlass shrink-wraps its content, so the capsule is as wide
            // as the title and no wider; Center keeps it centred in the header
            // and the inner Flexible(Text) wraps a long title onto a second
            // line, then ellipsizes. There is no expand-on-tap any more: a tap
            // goes straight to Room Info, which shows the full name anyway.
            child: Center(
              child: LiquidGlass(
                shape: LiquidGlassShape.capsule,
                padding: const EdgeInsets.fromLTRB(5, 5, 16, 5),
                onTap: onOpenInfo,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAvatar(context),
                    const SizedBox(width: 9),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.body.copyWith(
                              fontSize: 17,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              color: theme.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          ?_status(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ..._buildCallControls(),
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
    // The same lettered face the chat list gives this room, so the header
    // and the row it was opened from show one identity. A secret room keeps
    // its hourglass — that is the one thing worth knowing at a glance.
    if (room.isEphemeral) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: monogramGradient(theme, room.id.hashCode),
        ),
        child: theme.hourglassIcon(size: size * 0.5, color: Colors.white),
      );
    }
    return MonogramAvatar(label: room.name, seed: room.id, size: size);
  }
}

/// One video on its way into a chat, as a file. [ownsFile] when this app made
/// it (a recording, a staged share) and it should go once read.
class _OutgoingVideo {
  const _OutgoingVideo(
    this.path, {
    this.durationMs,
    this.poster,
    this.ownsFile = false,
  });

  final String path;
  final int? durationMs;
  final Uint8List? poster;
  final bool ownsFile;
}

/// A pick made ready to send: a photo prepared for upload (edited, or
/// compressed to the send size), or a video's bytes with its poster and
/// length, compressed to fit first when it is over [kMaxFileUploadBytes].
/// Null from [from] when it could not be read, or (a video) could not be
/// made to fit.
class _ReadyPick {
  _ReadyPick.photo(CroppedImage this.photo)
      : videoBytes = null,
        contentType = null,
        poster = null,
        durationMs = null;
  _ReadyPick.video({
    required Uint8List this.videoBytes,
    required String this.contentType,
    this.poster,
    this.durationMs,
  }) : photo = null;

  final CroppedImage? photo;
  final Uint8List? videoBytes;
  final String? contentType;
  final Uint8List? poster;
  final int? durationMs;

  static Future<_ReadyPick?> from(PickedMedia pick, {required bool hd}) async {
    try {
      if (pick.isVideo) return await _video(pick);
      final edited = pick.edited;
      if (edited != null) return _ReadyPick.photo(edited);
      final bytes = await GalleryTray.loadBytes(pick.asset);
      if (bytes == null) return null;
      final prepared = await prepareUneditedForSend(bytes, hd: hd);
      return prepared == null ? null : _ReadyPick.photo(prepared);
    } catch (e) {
      debugPrint('[inline_picker] prepare: $e');
      return null;
    }
  }

  static Future<_ReadyPick?> _video(PickedMedia pick) async {
    final file = await pick.asset.originFile;
    if (file == null) return null;
    final duration = pick.asset.duration * 1000;
    // The poster comes from the original either way: same picture, and the
    // file the extractor can open. Phones only, but the guard is the rule
    // for every call (see video_poster_gate_test).
    final poster = kIsWeb ? null : await VideoPoster.extract(file.path);
    // Measured here as well as from the library's records: those can be
    // missing, and this is the file that would go up.
    if (videoFateFor(await file.length(), canShrink: VideoShrink.supported) ==
        VideoFate.asIs) {
      return _ReadyPick.video(
        videoBytes: await file.readAsBytes(),
        contentType: videoContentTypeFor(file.path),
        poster: poster,
        durationMs: duration,
      );
    }
    final out = await VideoShrink.shrink(file.path);
    if (out == null) return null;
    try {
      return _ReadyPick.video(
        videoBytes: await File(out).readAsBytes(),
        contentType: videoContentTypeFor(out),
        poster: poster,
        durationMs: duration,
      );
    } finally {
      try {
        await File(out).delete();
      } catch (_) {}
    }
  }
}
