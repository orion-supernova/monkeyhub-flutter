import 'dart:collection';

/// Which spoilers this SESSION has revealed, keyed by message id.
///
/// Memory-only, deliberately. Revealed-ness is not message state — the server
/// stores who said what, not who has peeked — and it is not even device
/// state: a spoiler you wiped this morning going back to dust after a restart
/// is the feature working, not a bug. So: no backend field, no disk write,
/// just a set that dies with the process.
///
/// An LRU with a cap rather than a bare set, so a marathon session that
/// reveals thousands of spoilers doesn't grow without bound. Evicting an old
/// entry re-veils that message if it scrolls back — harmless, and at this cap
/// it takes deliberate effort to ever see it happen.
///
/// Partial wipes are NOT recorded anywhere, including here. The wipe mask
/// lives in the overlay widget's own State, so scrolling a half-wiped
/// spoiler out of the list resets it to full dust — the veil re-forming over
/// text you only glimpsed reads as the effect's nature, and recording
/// per-cell masks per message would be a lot of machinery to prevent it.
class SpoilerStore {
  SpoilerStore._();

  static final SpoilerStore instance = SpoilerStore._();

  static const _cap = 512;

  final LinkedHashSet<String> _revealed = LinkedHashSet();

  bool isRevealed(String messageId) => _revealed.contains(messageId);

  void reveal(String messageId) {
    // Re-inserting moves the key to the back of the eviction order.
    _revealed
      ..remove(messageId)
      ..add(messageId);
    while (_revealed.length > _cap) {
      _revealed.remove(_revealed.first);
    }
  }

  /// Test seam.
  void clear() => _revealed.clear();
}
