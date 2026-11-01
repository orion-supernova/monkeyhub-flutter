import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../theme/theme_scope.dart';
import 'scroll_to_latest.dart';

/// The trail of messages a reader has jumped *away from* while following reply
/// tethers, newest hop last.
///
/// Tapping a tether is a one-way door without this: you land on the quoted
/// parent and the reply you were reading is gone somewhere below you. Chase a
/// chain three deep and there is no way back but scrolling and hunting. So
/// every landed jump pushes its origin here, and the back pill walks them off
/// in reverse — tap, tap, tap out is tap, tap, tap back.
///
/// Pure state with no widget dependencies, split out for the same reason
/// `BottomProximity` was: the rules (dedupe, cap, expiry) are the part worth
/// pinning down in a test, and none of them need a tree to be true.
class JumpBackStack extends ChangeNotifier {
  JumpBackStack({this.idleTimeout = defaultIdleTimeout});

  /// How long a trail survives with no jumps before it clears itself.
  ///
  /// Short, because it is the backstop and not the main exit: arriving back at
  /// the newest message is what usually retires a trail, and this only has to
  /// catch the reader who lands on a parent and then does nothing at all.
  /// Every push and pop restarts it, so chasing a chain out and walking it back
  /// both hold as long as the taps keep coming.
  static const Duration defaultIdleTimeout = Duration(seconds: 5);

  /// [Duration.zero] disables expiry.
  final Duration idleTimeout;

  /// Above this the oldest hop is dropped. A reader who has followed 32 tethers
  /// without walking any of them back is not going to walk back the first one,
  /// and an uncapped list is an uncapped list.
  static const int maxDepth = 32;

  final List<ChatMessage> _trail = [];
  Timer? _expiry;

  /// Oldest hop first. The back pill takes from the end.
  List<ChatMessage> get trail => List.unmodifiable(_trail);

  int get depth => _trail.length;
  bool get isEmpty => _trail.isEmpty;
  bool get isNotEmpty => _trail.isNotEmpty;

  /// The message a tap on the back pill would return to, without removing it.
  ChatMessage? get top => _trail.isEmpty ? null : _trail.last;

  /// Remember [origin] as somewhere to come back to. Call this only once a jump
  /// has actually landed — a trail entry for a jump that failed is a pill that
  /// takes you nowhere.
  void push(ChatMessage origin) {
    // Double-tapping one tether jumps to the same parent twice; two identical
    // hops would need two taps to walk back off. Still counts as activity, so
    // the expiry window restarts — just nothing changed to announce.
    if (_trail.isNotEmpty && _trail.last.id == origin.id) {
      _restartExpiry();
      return;
    }
    _trail.add(origin);
    if (_trail.length > maxDepth) _trail.removeAt(0);
    _restartExpiry();
    notifyListeners();
  }

  /// Take the newest hop off the trail. Null when there is nothing to go back
  /// to. Callers pop *before* travelling, so an entry whose message has since
  /// been deleted removes itself and the pill falls through to the next hop.
  ChatMessage? pop() {
    if (_trail.isEmpty) return null;
    final origin = _trail.removeLast();
    _restartExpiry();
    notifyListeners();
    return origin;
  }

  /// Throw the whole trail away — the reader has deliberately left it, or it
  /// has gone stale. Silent when there was nothing to throw away.
  void clear() {
    _expiry?.cancel();
    _expiry = null;
    if (_trail.isEmpty) return;
    _trail.clear();
    notifyListeners();
  }

  void _restartExpiry() {
    _expiry?.cancel();
    _expiry = null;
    if (idleTimeout <= Duration.zero) return;
    // An empty trail has nothing to expire; pop() clearing the last hop already
    // hid the pill.
    if (_trail.isEmpty) return;
    _expiry = Timer(idleTimeout, clear);
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _expiry = null;
    super.dispose();
  }
}

/// Returns the reader to the reply they jumped away from.
///
/// A round button in the same right-hand column as `@` and the chevron, above
/// them because it is the transient one: "back one hop" and "all the way to
/// now" are different destinations, and a reader mid-chain wants both. It used
/// to be a centred word-capsule, which covered the very bubbles it had just
/// landed on.
class JumpBackPill extends StatelessWidget {
  const JumpBackPill({super.key, required this.depth, required this.onTap});

  /// How many hops deep the trail is. Shown from 2 up, as a quiet count on
  /// the disc, so a reader who has followed a long chain can see how far back
  /// it still goes.
  final int depth;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    return ChatScrollFab(
      onTap: onTap,
      count: depth > 1 ? depth : 0,
      quietCount: true,
      // Says where it goes, not why you left — a pin banner and "show in
      // chat" push onto this same trail, and neither involves a reply.
      semanticLabel: depth > 1
          ? l10n.bulkActionBarJumpBackSemanticLabelWithDepth(depth)
          : l10n.bulkActionBarJumpBackSemanticLabel,
      // Down-and-back, because the place you jumped from is almost always
      // newer than the message you jumped to, and newer is below.
      glyph: Icon(CupertinoIcons.arrow_uturn_down, size: 15, color: theme.ink),
    );
  }
}
