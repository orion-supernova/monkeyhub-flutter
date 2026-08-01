import 'package:flutter/widgets.dart';

import '../models/chat_user.dart';
import '../models/mention.dart';
import '../widgets/mention_text_controller.dart';

/// The `@`-picker's state machine: when it is open, what it is showing, which
/// row is armed, and what happens when one is taken.
///
/// It listens to the [controller] rather than to the composer's `onChanged`,
/// because `onChanged` does not fire when the user merely *moves the caret* —
/// tapping into the middle of an existing `@bob` has to open the list, and
/// tapping away has to close it. Listening to the controller also means none of
/// the four composer call sites have to give up the `onChanged` they already
/// use for typing indicators.
class MentionSession extends ChangeNotifier {
  MentionSession({
    required this.controller,
    required this.roster,
    required this.selfUserId,
    required this.allowEveryone,
  }) {
    controller.addListener(_onControllerChanged);
  }

  final MentionTextController controller;

  /// Read fresh on every keystroke rather than captured, so a member who joins
  /// mid-sentence is offered without the session being rebuilt.
  final List<ChatUser> Function() roster;

  final String? selfUserId;

  /// False in a DM, where addressing "everyone" means addressing the one other
  /// person who is already reading.
  ///
  /// A callback rather than a bool because the room this session belongs to
  /// may not have loaded yet when it is constructed, and a snapshot taken then
  /// would offer `@everyone` in a DM forever.
  final bool Function() allowEveryone;

  List<ChatUser> _matches = const [];
  bool _showEveryone = false;
  int _active = 0;
  MentionQuery? _query;

  /// The `@` the user dismissed with Escape. Kept closed until the caret
  /// leaves it, so Escape means "not this one" rather than "not for a moment".
  int? _dismissedAt;

  bool get isOpen => _query != null && itemCount > 0;
  List<ChatUser> get matches => _matches;
  bool get showEveryone => _showEveryone;
  int get itemCount => _matches.length + (_showEveryone ? 1 : 0);

  /// Index of the armed row, counting `@everyone` as row 0 when it is shown.
  int get activeIndex => _active;

  void _onControllerChanged() {
    // Correctness first: whatever else this edit did, a mention whose handle
    // no longer reads as that person's handle is no longer a mention.
    controller.prune();
    _recompute();
  }

  void _recompute() {
    final before = _signature;

    final sel = controller.selection;
    final text = controller.text;
    // An invalid or ranged selection means there is no single caret to be
    // "inside" a mention. `TextEditingController.text =` sets the offset to -1,
    // which the room screen does whenever it restores an unsent draft.
    if (!sel.isValid || !sel.isCollapsed) return _closeAndNotify(before);

    final q = MentionQuery.activeAt(text, sel.baseOffset);
    if (q == null) {
      _dismissedAt = null;
      return _closeAndNotify(before);
    }
    if (_dismissedAt == q.atIndex) return _closeAndNotify(before);

    // A handle that is already committed and already behind the caret is a
    // finished mention, not a query. Without this the list would spring open
    // again the moment a pick landed, since "@bob " still reads as a search
    // for "bob".
    for (final m in MentionDetector.matches(
      text,
      usernameById: controller.handles,
      everyone: controller.everyone,
    )) {
      if (m.start == q.atIndex && sel.baseOffset >= m.end) {
        return _closeAndNotify(before);
      }
    }

    _query = q;
    _matches = rankMembers(roster(), q.query, excludeUserId: selfUserId);
    _showEveryone = allowEveryone() &&
        kEveryoneHandle.startsWith(q.query.trim().toLowerCase());
    // Keep the armed row in range as the list narrows under the user.
    if (_active >= itemCount) _active = 0;
    _notifyIfChanged(before);
  }

  void moveActive(int delta) {
    if (!isOpen) return;
    final n = itemCount;
    _active = (_active + delta) % n;
    if (_active < 0) _active += n;
    notifyListeners();
  }

  void setActive(int index) {
    if (!isOpen || index < 0 || index >= itemCount) return;
    if (_active == index) return;
    _active = index;
    notifyListeners();
  }

  /// Closes the list and remembers not to reopen it for this `@`.
  void dismiss() {
    if (!isOpen) return;
    _dismissedAt = _query?.atIndex;
    _close();
    notifyListeners();
  }

  /// Replaces the in-progress `@…` with the armed row's handle.
  ///
  /// Returns false when there was nothing armed, so a key handler can tell
  /// whether it consumed the keystroke.
  bool accept([int? index]) {
    final q = _query;
    if (q == null || !isOpen) return false;
    final i = index ?? _active;
    if (i < 0 || i >= itemCount) return false;

    String handle;
    String? userId;
    if (_showEveryone && i == 0) {
      handle = kEveryoneHandle;
    } else {
      final u = _matches[i - (_showEveryone ? 1 : 0)];
      handle = u.username;
      userId = u.id;
    }

    final text = controller.text;
    final caret = controller.selection.baseOffset;
    if (caret < q.atIndex || caret > text.length) return false;

    final head = text.substring(0, q.atIndex);
    final tail = text.substring(caret);
    // One trailing space, and only if there isn't one already — so accepting
    // mid-sentence doesn't wedge two spaces into the middle of it.
    final token = tail.startsWith(' ') ? '@$handle' : '@$handle ';

    if (userId == null) {
      controller.commitEveryone();
    } else {
      controller.commit(userId, handle);
    }
    // Assigning `value` runs the listener, which prunes (the handle is present,
    // so it survives) and then recomputes — landing on the completed-mention
    // rule above and closing the list. Nothing here has to close it by hand.
    controller.value = TextEditingValue(
      text: head + token + tail,
      selection: TextSelection.collapsed(offset: head.length + token.length),
    );
    return true;
  }

  void _close() {
    _query = null;
    _matches = const [];
    _showEveryone = false;
    _active = 0;
  }

  void _closeAndNotify(Object? before) {
    _close();
    _notifyIfChanged(before);
  }

  /// The listener fires on every keystroke and every caret move, so rebuilding
  /// the picker only when something it renders actually changed is what keeps
  /// typing from repainting a list that looks identical.
  Object get _signature => Object.hash(
        _query?.atIndex,
        _query?.query,
        _active,
        _showEveryone,
        Object.hashAll([for (final u in _matches) u.id]),
      );

  void _notifyIfChanged(Object? before) {
    if (_signature == before) return;
    notifyListeners();
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }
}
