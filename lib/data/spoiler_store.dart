import 'dart:collection';

/// Which spoilers are open RIGHT NOW, keyed by message id.
///
/// Memory-only, deliberately. Revealed-ness is not message state — the server
/// stores who said what, not who has peeked — and it is not even device
/// state: a spoiler you wiped this morning going back to dust after a restart
/// is the feature working, not a bug. So: no backend field, no disk write,
/// just a set that dies with the process.
///
/// **Open is temporary.** A revealed spoiler heals on its own after a hold, so
/// an entry here means "currently open", not "peeked at some point". The
/// overlay owns the timer and calls [conceal] when the dust closes back over;
/// this set exists so a rebuild in place doesn't yank the text away
/// mid-read. An overlay that mounts and finds itself already open starts a
/// fresh hold, so an entry can never strand a message permanently readable.
///
/// Leaving the room clears the lot (see `RoomScreen.dispose`) — coming back to
/// a conversation should show it the way anyone else would see it.
///
/// An LRU with a cap rather than a bare set, so a marathon session that
/// reveals thousands of spoilers doesn't grow without bound.
///
/// Partial wipes are NOT recorded anywhere, including here. The wipe mask
/// lives in the overlay widget's own State, so scrolling a half-wiped
/// spoiler out of the list resets it to full dust.
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

  /// The dust has closed back over this message.
  void conceal(String messageId) => _revealed.remove(messageId);

  /// Called on room exit, and by tests.
  void clear() => _revealed.clear();
}
