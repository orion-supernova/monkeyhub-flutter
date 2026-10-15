import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';

/// What the label under a username field is currently saying.
enum UsernameCheck {
  /// Nothing to say: the field is empty, or holds the value it started with.
  idle,

  /// A request is in flight, or one is about to be.
  checking,

  available,

  /// Outside 1–32 characters. Answered without a round trip.
  invalid,

  /// Reads as the brand. `isReservedName` server-side.
  reserved,

  /// Trips the language filter. `contentFilter.isObjectionableName`.
  inappropriate,

  taken,

  /// The check itself failed — offline, most likely.
  ///
  /// Deliberately NOT folded into [taken]. A dropped request says nothing about
  /// the name, and telling someone their chosen handle is gone because their
  /// train went into a tunnel is a lie that makes them pick a worse one.
  unknown,
}

/// Debounced "is this handle free?" for every field where one is chosen.
///
/// One of these per field, owned by the field's State and disposed with it.
/// Feed it [onChanged] and render [status]; it is a [ChangeNotifier], so a
/// [ListenableBuilder] is all the wiring a caller needs.
///
/// ## Why this is a controller rather than a widget
///
/// The four places that pick a handle look nothing alike — the login form, the
/// social sign-up screen, the child-setup screen and a bottom sheet on the
/// profile. Sharing a whole field widget would mean one that could render four
/// layouts; sharing the debounce, the race guard and the reason mapping leaves
/// each screen its own markup and still keeps the behaviour identical.
///
/// ## What it does NOT do
///
/// It never gates submission. The server re-checks inside the write
/// transaction, and it has to: an [available] answer is only ever a statement
/// about the past, and the name can be claimed in the pause before the tap.
/// Treating this as permission would turn a race into a crash.
class UsernameAvailabilityController extends ChangeNotifier {
  UsernameAvailabilityController({
    required ChatApi api,
    this.excludeUserId,
    String? initialValue,
  })  : _api = api,
        _initial = initialValue?.trim() ?? '';

  final ChatApi _api;

  /// The account doing the asking, on the rename sheet. Its own handle comes
  /// back available rather than taken.
  final String? excludeUserId;

  /// The value the field opened with. Typing back to it returns to [idle]
  /// rather than reporting "available" about a name you already hold.
  final String _initial;

  /// Matches the 250ms used by the room and people searches. Long enough that
  /// ordinary typing produces one request rather than a dozen, short enough
  /// that the answer is there by the time the thumb reaches the button.
  static const debounce = Duration(milliseconds: 250);

  Timer? _timer;
  UsernameCheck _status = UsernameCheck.idle;
  UsernameCheck get status => _status;

  /// The value whose answer is currently on screen, so a caller can tell
  /// whether [status] still describes what is in the field.
  String _settled = '';
  String get settledValue => _settled;

  /// Bumped on every request. A slow answer for a handle the user has since
  /// typed past would otherwise overwrite a newer one — the classic typeahead
  /// bug, and the reason this is not just a bare `await`.
  int _seq = 0;

  bool _disposed = false;

  void onChanged(String raw) {
    _timer?.cancel();
    final value = raw.trim();

    // Answered locally, both of them: an empty field has nothing to say, and
    // the value the field opened with is already yours.
    if (value.isEmpty || value == _initial) {
      _seq++;
      _set(UsernameCheck.idle, value);
      return;
    }
    // Length is the one rule the client can apply itself, and doing so keeps a
    // 400-character paste from becoming a request.
    if (value.length > 32) {
      _seq++;
      _set(UsernameCheck.invalid, value);
      return;
    }

    _set(UsernameCheck.checking, _settled);
    _timer = Timer(debounce, () => _check(value));
  }

  Future<void> _check(String value) async {
    final seq = ++_seq;
    try {
      final res = await _api.isUsernameAvailable(
        username: value,
        excludeUserId: excludeUserId,
      );
      if (_disposed || seq != _seq) return;
      _set(
        res.available
            ? UsernameCheck.available
            : switch (res.reason) {
                'invalid' => UsernameCheck.invalid,
                'reserved' => UsernameCheck.reserved,
                'inappropriate' => UsernameCheck.inappropriate,
                'taken' => UsernameCheck.taken,
                // A reason this build predates. "Not available" is true of
                // every false, so it is the safe generalisation.
                _ => UsernameCheck.taken,
              },
        value,
      );
    } catch (_) {
      if (_disposed || seq != _seq) return;
      _set(UsernameCheck.unknown, value);
    }
  }

  void _set(UsernameCheck next, String settled) {
    if (_status == next && _settled == settled) return;
    _status = next;
    _settled = settled;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
