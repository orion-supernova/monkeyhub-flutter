import 'package:flutter/widgets.dart';

/// A sent video note's circle flying down into the bubble it becomes.
///
/// The composer draws the flight with the very circle the sender was looking
/// at (see `composer_capture.dart`); what it needs from the transcript is
/// *where* that bubble is, and the transcript must hold the bubble back until
/// the circle has landed on it, or the note would be on screen twice.
///
/// So a send opens a [SendFlightTicket] just before it hands the note over.
/// The first [SendFlightLanding] mounted while the ticket is open (the new
/// outgoing circle, a frame or two later) claims it: it reports its rect and
/// shows itself at [SendFlightTicket.reveal]. Only a landing *mounted* after
/// the ticket opened can claim it, so a note already uploading further up the
/// list is never mistaken for the new one.
///
/// Rows that are not a fresh outgoing note never see any of this: the check
/// is one static read in `initState`, and nothing is wrapped.
class SendFlight {
  SendFlight._();

  static SendFlightTicket? _open;

  /// The ticket waiting for its landing, if a send is in flight.
  static SendFlightTicket? get current => _open;

  /// Opens a ticket for the send about to be handed over, closing any
  /// earlier one (its circle has given up on it already).
  static SendFlightTicket open() {
    _open?.close();
    return _open = SendFlightTicket._();
  }
}

/// One send's flight: who it lands on, and how much of the landing shows.
class SendFlightTicket extends ChangeNotifier {
  SendFlightTicket._();

  _SendFlightLandingState? _landing;
  Rect? _lastRect;
  bool _closed = false;

  /// 0 while the circle is still in the air (the landing is hidden), up to 1
  /// as the circle hands over to it. Driven by the flight.
  final ValueNotifier<double> reveal = ValueNotifier(0);

  /// Whether a landing has claimed this ticket.
  bool get claimed => _lastRect != null || _landing != null;

  /// Whether the flight is over (landed, or given up).
  bool get closed => _closed;

  void _claim(_SendFlightLandingState landing) {
    if (_closed || claimed) return;
    _landing = landing;
    notifyListeners();
  }

  void _release(_SendFlightLandingState landing) {
    // Its last rect stays: measured on every frame of the flight, and a
    // State being disposed can no longer be measured.
    if (identical(_landing, landing)) _landing = null;
  }

  /// The landing's rect in [space]'s coordinates, read fresh every call so a
  /// bubble still rising or scrolling is followed. Its last known rect once
  /// it has gone (the upload finished and the row was rebuilt as the sent
  /// circle, in the same place).
  Rect? rectIn(RenderBox space) {
    final landing = _landing;
    if (landing != null) _lastRect = _measure(landing, space) ?? _lastRect;
    return _lastRect;
  }

  static Rect? _measure(_SendFlightLandingState landing, RenderBox space) {
    if (!landing.mounted) return null;
    final box = landing.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return space.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
  }

  /// The flight is over: show the landing fully, and stop taking claims.
  void close() {
    if (_closed) return;
    _closed = true;
    reveal.value = 1;
    if (identical(SendFlight._open, this)) SendFlight._open = null;
    notifyListeners();
  }

}

/// Where a sent video note's circle lands: wraps the new outgoing circle.
/// Hidden while the circle flies to it, then revealed as it lands.
class SendFlightLanding extends StatefulWidget {
  const SendFlightLanding({super.key, required this.child});

  final Widget child;

  @override
  State<SendFlightLanding> createState() => _SendFlightLandingState();
}

class _SendFlightLandingState extends State<SendFlightLanding> {
  SendFlightTicket? _ticket;

  @override
  void initState() {
    super.initState();
    final ticket = SendFlight.current;
    if (ticket != null && !ticket.claimed && !ticket.closed) {
      _ticket = ticket;
      ticket._claim(this);
    }
  }

  @override
  void dispose() {
    _ticket?._release(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;
    if (ticket == null) return widget.child;
    return ValueListenableBuilder<double>(
      valueListenable: ticket.reveal,
      builder: (context, reveal, child) => Opacity(opacity: reveal.clamp(0.0, 1.0), child: child),
      child: widget.child,
    );
  }
}
