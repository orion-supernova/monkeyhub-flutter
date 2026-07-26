import 'package:flutter/material.dart';

import '../../backend/chat_api.dart';
import '../../data/chat_repository.dart';
import '../../data/settings_store.dart';
import '../../data/ui_selection_store.dart';
import '../../theme/layout.dart';
import '../room_screen.dart';

/// Opens a chat room, adapting to the current window class.
///
/// - **Expanded (desktop):** fills the chat detail pane by selecting the room
///   in [UiSelectionStore] (switching to the Chat section first so the pane is
///   visible). No navigation — the two-pane shell reacts to the selection.
/// - **Compact / medium:** pushes [RoomScreen] full-screen, exactly as the app
///   did before the desktop redesign.
///
/// This is the single decision point that lets the ~12 existing room-open call
/// sites keep their phone behavior unchanged while gaining desktop panes.
void openRoom(
  BuildContext context, {
  required String roomId,
  required ChatRepository repo,
  required ChatApi api,
}) {
  if (context.isExpanded) {
    SettingsStore.instance.setSection(HomeSection.chat);
    UiSelectionStore.instance.selectRoom(roomId);
    return;
  }
  // Mirror the selection even though nothing on compact/medium reads it today
  // — so that if the window grows to expanded while this push is still
  // showing, the desktop two-pane already has the right room queued up the
  // instant the stale push gets reconciled away (see the window-class
  // transition handler in app.dart). Deliberately NOT touching
  // SettingsStore.section here: on compact that also drives which bottom-nav
  // tab sits underneath this push, and forcing it to chat would strand the
  // user there after backing out of a room opened from Feed/Settings.
  UiSelectionStore.instance.selectRoom(roomId);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => RoomScreen(roomId: roomId, repo: repo, api: api),
    ),
  );
}

/// The desktop settings detail pane's own nested navigator. Held here (rather
/// than threaded through the settings list) so any settings row can push into
/// the pane via [openSettingsDetail]. Route 0 of this navigator is an empty
/// hint, so a sub-screen's own back button pops back to it — no per-sub-screen
/// changes needed. Null on compact, where there is no pane.
final GlobalKey<NavigatorState> settingsPaneNavKey =
    GlobalKey<NavigatorState>();

/// Opens a settings sub-screen, adapting to the current window class.
///
/// - **Expanded (desktop):** pushes [builder]'s screen into the settings detail
///   pane's nested navigator (resetting it to the empty base first), and
///   records [key] so the originating row can render as selected.
/// - **Compact / medium:** pushes the sub-screen full-screen, as before.
void openSettingsDetail(
  BuildContext context, {
  required String key,
  required WidgetBuilder builder,
}) {
  if (context.isExpanded) {
    final nav = settingsPaneNavKey.currentState;
    if (nav != null) {
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute(builder: builder));
      UiSelectionStore.instance.setSettingsDetailKey(key);
      return;
    }
    // Pane not mounted yet — fall through to a normal push.
  }
  Navigator.of(context).push(MaterialPageRoute(builder: builder));
}
