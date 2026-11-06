import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../backend/convex_client.dart';
import '../privacy/vanish_rules.dart';

/// Everything the open room knows about vanish mode that the server tells it:
/// the burn state (for the countdown rings) and the caller's own sharing
/// choices (for the hidden-seen card and for what `markRoomRead` claims).
///
/// ONE of these per repository, bound to whichever room is open. Each of its
/// two subscriptions is registered at most once per open room and only for a
/// room that is vanishing, so a normal chat never pays for either. Bubbles do
/// not listen to it as a whole transcript: each ring listens for itself.
class VanishController extends ChangeNotifier {
  VanishController({
    required this.cv,
    required this.api,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  /// The server's clock (burn times are its), skew-corrected by the host.
  final DateTime Function() clock;

  final ConvexBackend cv;
  final ChatApi api;

  String? _roomId;
  int _gen = 0;
  Subscription? _stateSub;
  Subscription? _prefsSub;

  VanishState? _state;
  VanishPrefs? _prefs;

  /// The answer the reader just gave on the card ("share" / "keep"), for the
  /// note that replaces it. Local to this open; the server's `perChat` is what
  /// outlives it.
  bool? _answeredShare;

  String? get roomId => _roomId;
  VanishState? get state => _state;
  VanishPrefs? get prefs => _prefs;

  /// Null until the reader answered the card in this session.
  bool? get answeredShare => _answeredShare;

  /// Whether either subscription is live (tests, and the one-per-room claim).
  @visibleForTesting
  bool get watchingState => _stateSub != null;
  @visibleForTesting
  bool get watchingPrefs => _prefsSub != null;

  /// Points the controller at [roomId] (null: no room open). Drops everything
  /// held for the previous room.
  void bind(String? roomId) {
    if (roomId == _roomId) return;
    _gen++;
    _stateSub?.cancel();
    _prefsSub?.cancel();
    _stateSub = null;
    _prefsSub = null;
    _release(null);
    _stateStarting = false;
    _prefsStarting = false;
    _roomId = roomId;
    _state = null;
    _prefs = null;
    _answeredShare = null;
    notifyListeners();
  }

  /// Starts the burn-state subscription for the bound room. Idempotent.
  void watchState() {
    final id = _roomId;
    if (id == null || _stateSub != null || _stateStarting) return;
    _stateStarting = true;
    final gen = _gen;
    cv.subscribe(
      'vanish:stateForRoom',
      {'roomId': id},
      onData: (data) {
        if (gen != _gen) return;
        final next = VanishState.fromJson(data);
        if (next == _state) return;
        _state = next;
        notifyListeners();
      },
      onError: (e) => debugPrint('vanish state sub error: $e'),
    ).then((sub) {
      _stateStarting = false;
      if (gen != _gen) {
        sub.cancel();
        return;
      }
      _stateSub = sub;
    }).catchError((Object e) {
      _stateStarting = false;
      debugPrint('vanish state sub failed: $e');
    });
  }

  bool _stateStarting = false;
  bool _prefsStarting = false;

  final List<({Completer<VanishPrefs?> done, Timer timer})> _waiters = [];

  void _release(VanishPrefs? value) {
    final waiting = List.of(_waiters);
    _waiters.clear();
    for (final w in waiting) {
      w.timer.cancel();
      if (!w.done.isCompleted) w.done.complete(value);
    }
  }

  void _startPrefs() {
    final id = _roomId;
    if (id == null || _prefsSub != null || _prefsStarting) return;
    _prefsStarting = true;
    final gen = _gen;
    cv.subscribe(
      'vanish:myVanishPrefs',
      {'roomId': id},
      onData: (data) {
        if (gen != _gen) return;
        final next = VanishPrefs.fromJson(data);
        if (next == null) return;
        final changed = next != _prefs;
        _prefs = next;
        _release(next);
        if (changed) notifyListeners();
      },
      onError: (e) => debugPrint('vanish prefs sub error: $e'),
    ).then((sub) {
      _prefsStarting = false;
      if (gen != _gen) {
        sub.cancel();
        return;
      }
      _prefsSub = sub;
    }).catchError((Object e) {
      _prefsStarting = false;
      _release(null);
      debugPrint('vanish prefs sub failed: $e');
    });
  }

  /// Starts the prefs subscription for the bound room and resolves with the
  /// first answer (or null after [timeout], when the backend is not there).
  /// Idempotent for the subscription; each caller gets its own wait.
  Future<VanishPrefs?> watchPrefs({
    Duration timeout = const Duration(seconds: 3),
  }) {
    if (_roomId == null) return Future.value(null);
    _startPrefs();
    final known = _prefs;
    if (known != null) return Future.value(known);
    final done = Completer<VanishPrefs?>();
    final timer = Timer(timeout, () {
      _waiters.removeWhere((w) => identical(w.done, done));
      if (!done.isCompleted) done.complete(null);
    });
    _waiters.add((done: done, timer: timer));
    return done.future;
  }

  /// Both subscriptions, for a room that is vanishing.
  void watchAll() {
    watchState();
    _startPrefs();
  }

  /// The hidden-seen card's answer: share my reads in THIS chat, or do not.
  /// Optimistic (the card turns into its note at once); rolled back when the
  /// server refuses.
  Future<void> answer(bool share) async {
    final id = _roomId;
    if (id == null) return;
    final before = _prefs;
    _answeredShare = share;
    _prefs = (before ?? const VanishPrefs()).withPerChat(share);
    notifyListeners();
    try {
      await api.setVanishShareReads(id, share);
    } catch (e) {
      debugPrint('vanish answer failed: $e');
      if (_roomId == id) {
        _answeredShare = null;
        _prefs = before;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _prefsSub?.cancel();
    super.dispose();
  }
}
