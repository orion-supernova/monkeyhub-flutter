import 'package:flutter/foundation.dart';

import '../backend/convex_client.dart';
import '../models/daily_game.dart';
import 'chat_repository.dart';

/// One "Beat my time" card's body: whose time, on which board.
class GameChallenge {
  const GameChallenge({
    required this.messageId,
    required this.userId,
    required this.name,
    required this.game,
    required this.dayKey,
    required this.durationMs,
    required this.hintsUsed,
  });

  final String messageId;
  final String userId;
  final String name;
  final DailyGame game;
  final String dayKey;
  final int durationMs;
  final int hintsUsed;

  static GameChallenge? fromJson(Map<String, dynamic> j) {
    final game = DailyGame.parse(j['game']?.toString());
    if (game == null) return null;
    return GameChallenge(
      messageId: j['messageId']?.toString() ?? '',
      userId: j['userId']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      game: game,
      dayKey: j['dayKey']?.toString() ?? '',
      durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
      hintsUsed: (j['hintsUsed'] as num?)?.toInt() ?? 0,
    );
  }
}

/// The time a daily board is being played against, while it is.
class ChallengeTarget {
  const ChallengeTarget({
    required this.game,
    required this.dayKey,
    required this.name,
    required this.durationMs,
  });

  final DailyGame game;
  final String dayKey;
  final String name;
  final int durationMs;
}

/// "Beat my time": the cards' bodies, and the target a challenged board is
/// being played against.
///
/// A challenge never changes once sent, so its body is fetched once per card
/// (`challenges:forMessages`) and kept for the session — no subscription. The
/// [target] is set by the card as it opens the board and read by the board's
/// scaffold for its chip and its result line; it is cleared when another
/// board opens without one.
class ChallengesStore extends ChangeNotifier {
  ChallengesStore._();
  static final ChallengesStore instance = ChallengesStore._();

  /// The chat repository, for the "send to which chats" picker. Set once by
  /// the app at sign-in; a daily game's scaffold has no other way to it.
  ChatRepository? repo;

  final Map<String, GameChallenge> _byMessage = {};
  final Set<String> _asked = {};
  ChallengeTarget? target;

  GameChallenge? forMessage(String messageId) => _byMessage[messageId];

  Future<void> ensureFor(String userId, Iterable<String> messageIds) async {
    final want = [
      for (final id in messageIds)
        if (!_byMessage.containsKey(id) && _asked.add(id)) id,
    ];
    if (want.isEmpty) return;
    try {
      final raw = await ConvexBackend.instance.query('challenges:forMessages', {
        'messageIds': want,
        'viewerUserId': userId,
      });
      for (final r in (raw as List?) ?? const []) {
        if (r is! Map) continue;
        final c = GameChallenge.fromJson(r.cast<String, dynamic>());
        if (c != null) _byMessage[c.messageId] = c;
      }
      notifyListeners();
    } catch (_) {
      _asked.removeAll(want);
    }
  }

  /// Sends the viewer's finished result for [game] on [dayKey] to [roomIds].
  Future<void> send({
    required String userId,
    required List<String> roomIds,
    required DailyGame game,
    required String dayKey,
  }) => ConvexBackend.instance.mutation('challenges:send', {
    'userId': userId,
    'roomIds': roomIds,
    'game': game.wire,
    'dayKey': dayKey,
    'clientId': 'ch_${DateTime.now().microsecondsSinceEpoch}',
  });

  void clear() {
    _byMessage.clear();
    _asked.clear();
    target = null;
    repo = null;
  }
}
