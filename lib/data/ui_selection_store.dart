import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Holds the "what is selected in a two-pane layout" UI state — the room shown
/// in the chat detail pane, and (from Phase 4) the settings sub-screen shown in
/// the settings detail pane.
///
/// Deliberately separate from [ChatRepository]: that is domain/data state whose
/// listeners fan out to every room tile; pane selection is pure UI/navigation
/// state and mixing the two would rebuild the world on every selection. Kept as
/// a hand-rolled [ChangeNotifier] singleton to match the app's existing state
/// style (no Provider/Riverpod).
///
/// On compact layouts this store is unused — rooms/settings open via
/// `Navigator.push` exactly as before. See `screens/navigation/open_room.dart`.
class UiSelectionStore extends ChangeNotifier {
  UiSelectionStore._();
  static final UiSelectionStore instance = UiSelectionStore._();

  String? _roomId;

  /// The room currently shown in the desktop chat detail pane, or null for the
  /// empty "pick a room" state.
  String? get roomId => _roomId;

  void selectRoom(String? id) {
    if (id == _roomId) return;
    _roomId = id;
    _notify();
  }

  /// Identity of the settings sub-screen currently shown in the desktop
  /// settings detail pane (e.g. 'theme', 'logo', 'family'), or null for the
  /// empty state. Used only to highlight the active row in the settings list;
  /// the pane itself is driven by its own nested navigator.
  String? _settingsDetailKey;
  String? get settingsDetailKey => _settingsDetailKey;

  void setSettingsDetailKey(String? key) {
    if (key == _settingsDetailKey) return;
    _settingsDetailKey = key;
    _notify();
  }

  /// A one-shot request to show the friend-requests list, used when something
  /// outside the widget tree needs to steer the UI — currently a friend-request
  /// notification tap. The caller pairs it with
  /// `SettingsStore.setSection(HomeSection.discover)`; Discover consumes it on
  /// mount and scrolls its INCOMING section into view.
  ///
  /// One-shot because it's an event, not state: whoever acts on it calls
  /// [consumeRequestsView], so a later rebuild (or a second Discover after a
  /// navigation) doesn't yank the user back to a screen they've since left.
  ///
  /// It outlives widget mounting on purpose — a tap that arrives during a cold
  /// start is still waiting here when Discover first builds.
  bool _requestsViewPending = false;
  bool get requestsViewPending => _requestsViewPending;

  void requestRequestsView() {
    _requestsViewPending = true;
    _notify();
  }

  /// Returns whether a request was pending, clearing it either way.
  ///
  /// Always clears — the previous incarnation of this mechanism guarded on
  /// "is this destination currently available?" and returned *before*
  /// consuming, so an unroutable request stayed set forever and ambushed the
  /// next screen that could handle it.
  bool consumeRequestsView() {
    final pending = _requestsViewPending;
    _requestsViewPending = false;
    return pending;
  }

  /// The same one-shot, for the daily games nudge: show the Feed's games shelf.
  ///
  /// Paired with `SettingsStore.setSection(HomeSection.feed)` by the caller, and
  /// consumed by [FeedScreen], which scrolls to its Games band. Routed through
  /// here rather than handled in app.dart because on a wide window the Feed
  /// lives inside its own nested navigator and owns its own scroll position,
  /// neither of which the root can reach.
  ///
  /// Outlives widget mounting for the same reason [requestRequestsView] does: a
  /// notification tapped on a cold start lands long before any screen exists.
  bool _gamesViewPending = false;
  bool get gamesViewPending => _gamesViewPending;

  void requestGamesView() {
    _gamesViewPending = true;
    _notify();
  }

  /// Returns whether a request was pending, clearing it either way.
  bool consumeGamesView() {
    final pending = _gamesViewPending;
    _gamesViewPending = false;
    return pending;
  }

  /// The same one-shot for a friend-activity notification: open THIS moment's
  /// viewer on the Feed.
  ///
  /// Carries an id where the two above carry only a bit, which is the whole
  /// difference between this notification and the nudge — it names a card, and
  /// landing on the board without opening it would throw away the only thing
  /// the banner said.
  ///
  /// The last one wins if two arrive before anything consumes them. Two taps
  /// that fast means the person tapped the second banner, and steering them to
  /// the first would be answering a question they have already changed.
  String? _momentIdPending;
  String? get momentIdPending => _momentIdPending;

  /// Whether the pending moment should open with its comments sheet up — a
  /// comment or a reply notification, as opposed to a "posted" one. Rides with
  /// [_momentIdPending] and is cleared with it.
  bool _momentCommentsPending = false;
  bool get momentCommentsPending => _momentCommentsPending;

  void requestMoment(String momentId, {bool comments = false}) {
    _momentIdPending = momentId;
    _momentCommentsPending = comments;
    _notify();
  }

  /// Returns the pending moment id, clearing it either way. Read
  /// [momentCommentsPending] first if it matters.
  String? consumeMoment() {
    final pending = _momentIdPending;
    _momentIdPending = null;
    _momentCommentsPending = false;
    return pending;
  }

  /// "Once you are in this room, scroll to this message and pulse it."
  ///
  /// The last hop of a reaction notification: the tap is routed to the room by
  /// `data.roomId` like any message push, and this names the bubble that was
  /// reacted to — which may be days up the transcript, where landing at the
  /// bottom would hide the one thing the banner was about. Keyed by room for
  /// [roomChangeReviewPending]'s reason, and consumed the same way.
  ({String roomId, String messageId})? _messageFocusPending;

  /// Which room the pending focus is for, WITHOUT consuming it — so a room
  /// already open can ignore a request meant for the one about to mount
  /// instead of clearing it on a miss.
  String? get messageFocusPendingRoomId => _messageFocusPending?.roomId;

  void requestMessageFocus(String roomId, String messageId) {
    _messageFocusPending = (roomId: roomId, messageId: messageId);
    _notify();
  }

  /// The message to jump to when [roomId] was the room asked for; null
  /// otherwise. Clears the request either way, as
  /// [consumeRoomChangeReview] does.
  String? consumeMessageFocus(String roomId) {
    final pending = _messageFocusPending;
    _messageFocusPending = null;
    return pending?.roomId == roomId ? pending!.messageId : null;
  }

  /// "Once you are in this room, open the suggested-changes queue."
  ///
  /// The last hop of a `roomChangeRequests` notification. The tap itself is
  /// already routed by `data.roomId` — every push carrying one opens its room
  /// on both platforms — so all this carries is what to show ON TOP of the
  /// room, which is the difference between an admin landing on approve/reject
  /// and landing in a transcript with no sign of why they were sent there.
  ///
  /// Keyed by room, unlike the three one-shots above, because it is consumed
  /// by [RoomScreen] — one of which exists per room, any of which may be the
  /// one that mounts next, and the WRONG one must not act on it. A stale id
  /// simply never matches and ages out with the session.
  ///
  /// Outlives widget mounting for the same reason the others do: a
  /// notification tapped on a cold start lands long before any screen exists.
  String? _roomChangeReviewPending;
  String? get roomChangeReviewPending => _roomChangeReviewPending;

  void requestRoomChangeReview(String roomId) {
    _roomChangeReviewPending = roomId;
    _notify();
  }

  /// True when [roomId] was the room asked for, clearing the request either
  /// way. Clearing on a MISS is deliberate: the only way to reach here is by
  /// opening a room, so a request that names a different one has already been
  /// overtaken by the user going somewhere else, and keeping it would ambush
  /// them later.
  bool consumeRoomChangeReview(String roomId) {
    final pending = _roomChangeReviewPending;
    _roomChangeReviewPending = null;
    return pending == roomId;
  }

  /// [notifyListeners], deferred to the end of the frame when we are inside
  /// one.
  ///
  /// Selection changes legitimately originate from `State.dispose` —
  /// `_RoomScreenState` clears its own room on a compact dismissal so a stale
  /// id can't resurrect a closed room on a later resize. But Flutter unmounts
  /// disposed elements from `BuildOwner.finalizeTree`, under `lockState`: any
  /// `setState` reached from there throws *"setState() or markNeedsBuild()
  /// called when widget tree was locked"*. [SettingsScreen] listens here to
  /// highlight the active pane row, so backing out of a room while Settings
  /// was mounted crashed mid-frame.
  ///
  /// Only the fan-out waits — the fields are already written, so anything
  /// reading the store directly (rather than rebuilding on it) still sees the
  /// new value in the same tick. Deferral kicks in solely during
  /// build/layout/paint, where a synchronous rebuild request would be illegal
  /// anyway; taps, timers and post-frame callbacks notify immediately as
  /// before.
  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
      return;
    }
    notifyListeners();
  }
}
