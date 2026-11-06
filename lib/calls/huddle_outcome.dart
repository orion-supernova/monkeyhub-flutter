import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/enums.dart';
import '../models/huddle_history.dart';
import 'group_call_service.dart';

/// The starter's private "You wanted to talk · Nobody joined" notes.
///
/// A huddle nobody joins leaves nothing on the server (no row, no message), so
/// that line cannot come from the transcript. It is an in-memory row owned
/// here and merged into a room's transcript by the room screen
/// ([forRoom]). The chat repository has no notion of a local-only system row
/// (its `_pending` map is optimistic SENDS, which a failed send retries), so
/// this is deliberately outside it: it is never written, never synced and
/// gone on restart, which is exactly the "costs zero writes" the design wants.
class LocalHuddleNotes extends ChangeNotifier {
  LocalHuddleNotes._();
  static final LocalHuddleNotes instance = LocalHuddleNotes._();

  final Map<String, List<ChatMessage>> _byRoom = {};

  /// Newest last. The same list instance until a note is added, so a caller
  /// can compare by identity.
  List<ChatMessage> forRoom(String roomId) =>
      _byRoom[roomId] ?? const <ChatMessage>[];

  /// Notes that a huddle [groupCallId] [userId] started in [roomId] ended with
  /// nobody else having joined. Idempotent per call.
  void addAlone({
    required String roomId,
    required String groupCallId,
    required String userId,
    DateTime? at,
  }) {
    final id = 'local:huddle:$groupCallId';
    final list = _byRoom[roomId] ?? const <ChatMessage>[];
    if (list.any((m) => m.id == id)) return;
    // Only the newest note per room: three empty huddles in a row would
    // otherwise stack three identical rows. Replaces any earlier one.
    _byRoom[roomId] = [
      ChatMessage(
        id: id,
        roomId: roomId,
        senderId: userId,
        senderName: '',
        content: HuddleHistory.aloneContent,
        createdAt: at ?? DateTime.now(),
        type: MessageType.system,
      ),
    ];
    notifyListeners();
  }

  @visibleForTesting
  void clear() {
    _byRoom.clear();
    notifyListeners();
  }
}

/// Watches a huddle THIS device started, and when it ends with nobody else
/// ever having joined, files the starter's local "Nobody joined" note.
///
/// Self-removing: attached by [GroupCallService.startHuddle] and gone the
/// moment the call is. "Someone joined" is read off what the service already
/// knows (the roster, the live links), so it costs no query.
class HuddleOutcome {
  HuddleOutcome._(this._svc, this._groupCallId, this._roomId) {
    _svc.addListener(_check);
    _check();
  }

  final GroupCallService _svc;
  final String _groupCallId;
  final String _roomId;
  bool _othersSeen = false;
  bool _done = false;

  static void track(
    GroupCallService svc, {
    required String groupCallId,
    required String roomId,
  }) {
    HuddleOutcome._(svc, groupCallId, roomId);
  }

  void _check() {
    if (_done) return;
    final here = _svc.inCall && _svc.groupCallId == _groupCallId;
    if (here) {
      if (!_othersSeen && _othersIn()) _othersSeen = true;
      return;
    }
    // Entering the call is async; until the service has the id there is
    // nothing to conclude from its absence.
    if (_svc.joiningGroupCallId == _groupCallId) return;
    _done = true;
    _svc.removeListener(_check);
    final me = _svc.userId;
    if (!_othersSeen && me != null) {
      LocalHuddleNotes.instance.addAlone(
        roomId: _roomId,
        groupCallId: _groupCallId,
        userId: me,
      );
    }
  }

  bool _othersIn() {
    final me = _svc.userId;
    for (final r in _svc.rosterRows) {
      if (r['status'] == 'joined' && r['userId']?.toString() != me) return true;
    }
    return _svc.peers.values.any((p) => p.connected);
  }
}
