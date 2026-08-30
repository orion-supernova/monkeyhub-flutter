import 'dart:async';

import 'package:flutter/widgets.dart';

/// Draws a loading state while an answer is still coming, and the empty state
/// once it is clear no answer is coming at all.
///
/// **The bug this exists to make unrepresentable.** A list that has not been
/// answered yet and a list that is genuinely empty are the same empty list, and
/// every screen in this app that had to tell them apart guessed. On a fast
/// connection the guess is invisible; on a slow one the chat list told people
/// with a hundred rooms that they had none, and a room being opened said "no
/// messages yet" about a conversation years long. That is the complaint this
/// answers, in the reporter's words: "we only have empty views... on slow
/// network conditions we see empty view not loading properly".
///
/// **Why there is a [timeout] at all.** The obvious fix — draw the skeleton
/// until the data lands — trades one wrong state for another: a device that is
/// offline, or pointed at a backend that is down, never gets an answer, and a
/// skeleton that shimmers forever is a worse lie than an empty list. It says
/// "any moment now" indefinitely. So the wait is bounded: past [timeout] the
/// screen admits it does not know and shows [empty], which at least offers the
/// actions that make a room or start a chat.
///
/// The timer runs only while [pending] is true, and restarts if a screen goes
/// back to pending — a reconnect, or a new account signing in.
class PendingPlaceholder extends StatefulWidget {
  const PendingPlaceholder({
    super.key,
    required this.pending,
    required this.loading,
    required this.empty,
    this.timeout = const Duration(seconds: 8),
  });

  /// Whether the answer is still outstanding. False the moment anything has
  /// answered — including an answer of "nothing", which is what lets a genuinely
  /// empty account reach its empty state immediately instead of shimmering.
  final bool pending;

  /// The skeleton. Built lazily so a screen that is not waiting never pays for
  /// its controller.
  final WidgetBuilder loading;

  /// What to draw once there is an answer, or once [timeout] has passed without
  /// one.
  final WidgetBuilder empty;

  /// How long to keep saying "any moment now" before admitting otherwise.
  ///
  /// Eight seconds is past the slow-but-working case this is for and short of
  /// the point where a shimmer reads as a hang. It is deliberately longer than
  /// a fast request and shorter than the 15s timeouts the backend calls carry,
  /// so a request that is going to fail outright has usually not even given up
  /// yet when this does — the user sees the honest empty state first and the
  /// error surfaces behind it.
  final Duration timeout;

  @override
  State<PendingPlaceholder> createState() => _PendingPlaceholderState();
}

class _PendingPlaceholderState extends State<PendingPlaceholder> {
  Timer? _giveUp;

  /// Set once [PendingPlaceholder.timeout] has elapsed with [pending] still
  /// true. Cleared whenever a fresh wait starts.
  bool _waitedLongEnough = false;

  @override
  void initState() {
    super.initState();
    if (widget.pending) _startWaiting();
  }

  @override
  void didUpdateWidget(PendingPlaceholder old) {
    super.didUpdateWidget(old);
    if (widget.pending == old.pending) return;
    if (widget.pending) {
      // A new wait — a reconnect, or another account signing in. It gets the
      // full timeout of its own rather than inheriting the last one's verdict.
      _startWaiting();
    } else {
      _giveUp?.cancel();
      _giveUp = null;
    }
  }

  void _startWaiting() {
    _giveUp?.cancel();
    _waitedLongEnough = false;
    _giveUp = Timer(widget.timeout, () {
      if (!mounted) return;
      setState(() => _waitedLongEnough = true);
    });
  }

  @override
  void dispose() {
    _giveUp?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showLoading = widget.pending && !_waitedLongEnough;
    return showLoading ? widget.loading(context) : widget.empty(context);
  }
}
