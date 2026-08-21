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
  /// consumed by [FeedScreen], which opens the games hub. Routed through here
  /// rather than pushed straight onto the root navigator because on a wide
  /// window the Feed lives inside its own nested navigator — a root push would
  /// cover the shell instead of opening inside it, and the tab the user was
  /// steered to would be behind the screen they were steered to.
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
