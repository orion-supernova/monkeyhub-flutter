import 'dart:async';

import 'package:flutter/foundation.dart';

import 'drop_item.dart';

/// Parks a drop for a room that is not on screen yet.
///
/// A file dropped on a chat ROW has further to travel than one dropped into an
/// open conversation: the row selects its room, the shell swaps the detail
/// pane, and only then is there a `RoomScreen` with a send path in it. The
/// bundle has to sit somewhere that is neither widget nor navigator for the
/// length of that hop — which is exactly the problem [ShareIntake] already
/// solved for the system share sheet, and this is the same solution with the
/// share sheet's platform half removed.
///
/// A [ChangeNotifier] rather than a plain box, for the reason `ShareIntake`'s
/// own doc gives and which applies twice as hard here: on desktop a drop opens
/// a room by SELECTING it, and selecting the room that is already selected is
/// a no-op — no rebuild, no new `RoomScreen`, and a bundle that would sit
/// staged forever. Dropping onto the row of the chat you are already reading
/// is an entirely ordinary thing to do. So a mounted room listens as well as
/// checking on mount, and both doors go through [takeFor].
///
/// Never disposed: a process-lifetime singleton whose only listeners are
/// `RoomScreen`s that remove themselves.
class DropIntake extends ChangeNotifier {
  DropIntake._();
  static final DropIntake instance = DropIntake._();

  /// Longest a staged bundle is allowed to pin its bytes.
  ///
  /// The handoff future is what keeps macOS from deleting the staged copies
  /// out from under a room that has not finished reading them — so if no room
  /// ever collects the bundle (dropped onto a chat that is then deleted, a
  /// selection that does not mount, a crash in between) something has to give
  /// up on its behalf. Generous, because the legitimate slow case is a drop
  /// that opens the photo editor and waits for a crop.
  static const Duration _handoffGrace = Duration(minutes: 3);

  String? _roomId;
  DropBundle? _bundle;

  /// Completed when the destination has finished with the bundle.
  ///
  /// `DropController` awaits the zone's `onDrop` before releasing the
  /// platform's staged copies, and the chat-row zone's work is over the
  /// instant it has selected a room — long before the bytes have been read.
  /// So its `onDrop` returns THIS future instead of its own, and the room that
  /// eventually receives the bundle is what completes it.
  Completer<void>? _handoff;
  Timer? _grace;

  /// Parks [bundle] for [roomId] and returns a future that completes when the
  /// room is done with it.
  ///
  /// One at a time. A second drop cannot realistically be in flight while the
  /// first is still being placed — the first is a few hundred milliseconds old
  /// at most — and queueing them would mean holding two sets of staged bytes
  /// for a case that requires two hands and two mice.
  Future<void> stageFor(String roomId, DropBundle bundle) {
    // A previous bundle nobody collected. Let its bytes go rather than
    // stranding them behind the new one.
    _completeHandoff();
    _roomId = roomId;
    _bundle = bundle;
    final handoff = Completer<void>();
    _handoff = handoff;
    _grace = Timer(_handoffGrace, _completeHandoff);
    notifyListeners();
    return handoff.future;
  }

  /// Hands over (and clears) the bundle staged for [roomId], if any.
  ///
  /// Does NOT complete the handoff: the caller has the bundle, not the bytes.
  /// [handoffComplete] is the other half and the caller owes it, which is why
  /// every call site pairs them in a `finally`.
  DropBundle? takeFor(String roomId) {
    if (_roomId != roomId) return null;
    final out = _bundle;
    _roomId = null;
    _bundle = null;
    return out;
  }

  /// Releases the platform's staged copies. Idempotent.
  void handoffComplete() => _completeHandoff();

  void _completeHandoff() {
    _grace?.cancel();
    _grace = null;
    final handoff = _handoff;
    _handoff = null;
    if (handoff != null && !handoff.isCompleted) handoff.complete();
  }

  @visibleForTesting
  void debugReset() {
    _completeHandoff();
    _roomId = null;
    _bundle = null;
  }
}
