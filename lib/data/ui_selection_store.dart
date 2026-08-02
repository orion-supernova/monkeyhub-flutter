import 'package:flutter/foundation.dart';

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
    notifyListeners();
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
    notifyListeners();
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
    notifyListeners();
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
}
