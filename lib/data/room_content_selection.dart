import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';

/// Multi-select state for a list of messages: the shared-content browser's
/// grid, and the room transcript.
///
/// One class for both because the two selections end in the same two server
/// calls (`messages:forwardToRoom`, `messages:deleteMany`) and have the same
/// awkward property — the list underneath them is live.
///
/// Owned by the screen, not a singleton like `UiSelectionStore` — a selection
/// is meaningless once the screen closes, and a browser and a transcript open
/// side by side on a tablet must not share one.
///
/// Holds ids rather than messages on purpose. The underlying list is live: an
/// ephemeral message can self-destruct while selected, and a bulk delete
/// removes rows the user is still looking at. Holding message objects would
/// keep those alive and let the action bar act on things that no longer exist;
/// holding ids means [resolve] simply stops returning them.
class RoomContentSelection extends ChangeNotifier {
  final Set<String> _ids = {};
  bool _active = false;

  /// Whether the browser is in selection mode.
  ///
  /// Tracked separately from `_ids.isNotEmpty` because deselecting the last
  /// item should leave the mode on — dropping straight back to normal browsing
  /// makes tapping to correct a mistake feel like the screen crashed.
  bool get active => _active;

  int get count => _ids.length;
  bool get isEmpty => _ids.isEmpty;
  bool contains(String id) => _ids.contains(id);

  /// The selected ids, in no particular order. Copy — mutating the live set
  /// from a caller would skip [notifyListeners].
  Set<String> get ids => Set.unmodifiable(_ids);

  /// Enters selection mode, optionally selecting [id] as it does.
  void begin([String? id]) {
    _active = true;
    if (id != null) _ids.add(id);
    notifyListeners();
  }

  void toggle(String id) {
    if (!_ids.remove(id)) _ids.add(id);
    // Entering by tapping a tile is possible on desktop, where there is no
    // long-press idiom to enter with.
    _active = true;
    notifyListeners();
  }

  /// Replaces the selection with [ids] and turns selection mode on: what a
  /// drag across the grid hands over as it grows and shrinks its range.
  void replace(Set<String> ids) {
    _ids
      ..clear()
      ..addAll(ids);
    _active = true;
    notifyListeners();
  }

  /// Leaves selection mode and drops everything.
  void clear() {
    if (!_active && _ids.isEmpty) return;
    _ids.clear();
    _active = false;
    notifyListeners();
  }

  /// Selects everything in [all], or clears if it is already all selected.
  void selectAll(Iterable<String> all) {
    final ids = all.toSet();
    if (_ids.length == ids.length && _ids.containsAll(ids)) {
      _ids.clear();
    } else {
      _ids
        ..clear()
        ..addAll(ids);
    }
    _active = true;
    notifyListeners();
  }

  /// The selected messages, in the order [candidates] gives them.
  ///
  /// Ids with no surviving message are dropped rather than reported: a message
  /// that expired or was deleted under the selection is not an error, it is
  /// just gone. This is why the action bar counts [resolve], not [count] —
  /// otherwise it would offer to forward four things and send three.
  List<ChatMessage> resolve(List<ChatMessage> candidates) =>
      [for (final m in candidates) if (_ids.contains(m.id)) m];

  /// Drops ids that no longer appear in [candidates].
  ///
  /// Called after the list settles so the count on screen and the count the
  /// actions would operate on cannot disagree.
  void prune(List<ChatMessage> candidates) {
    if (_ids.isEmpty) return;
    final alive = {for (final m in candidates) m.id};
    final before = _ids.length;
    _ids.removeWhere((id) => !alive.contains(id));
    if (_ids.length != before) notifyListeners();
  }
}
