import 'package:flutter/widgets.dart';

/// What is flying: a ticket is only ever claimed by a landing of its kind,
/// so a voice note sent while a video note is still uploading can never land
/// on the circle.
enum SendFlightKind { videoNote, voice }

/// The pieces of a landing bubble a flight lands its own pieces on, marked
/// with [SendFlightMark]: a voice bubble's play disc, waveform and meta line.
enum SendFlightPart { disc, wave, label }

/// A sent note flying down into the bubble it becomes: a video note's
/// circle, or a voice note's strip or disc (see `composer_capture.dart`).
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
  static SendFlightTicket open([SendFlightKind kind = SendFlightKind.videoNote]) {
    _open?.close();
    return _open = SendFlightTicket._(kind);
  }
}

/// One send's flight: who it lands on, and how much of the landing shows.
class SendFlightTicket extends ChangeNotifier {
  SendFlightTicket._(this.kind);

  final SendFlightKind kind;

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

  /// The landing bubble's own fill, when it said, for the flight to arrive
  /// in.
  Color? get color => _landing?.widget.color ?? _lastColor;
  Color? _lastColor;

  /// The landing's waveform bar heights, 0..1, when it has one, for the
  /// flying bars to become.
  List<double>? get bars => _landing?.widget.bars ?? _lastBars;
  List<double>? _lastBars;

  final _lastParts = <SendFlightPart, Rect>{};

  /// One of the landing's marked pieces, in [space]'s coordinates, read fresh
  /// like [rectIn].
  Rect? partIn(SendFlightPart part, RenderBox space) {
    final mark = _landing?._parts[part];
    if (mark != null && mark.mounted) {
      final box = mark.context.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) {
        _lastParts[part] = space.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
      }
    }
    return _lastParts[part];
  }

  void _claim(_SendFlightLandingState landing) {
    if (_closed || claimed || landing.widget.kind != kind) return;
    _lastColor = landing.widget.color;
    _lastBars = landing.widget.bars;
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

/// Where a sent note lands: wraps the new outgoing circle, or the new
/// outgoing voice bubble. Hidden while the note flies to it, then revealed
/// as it lands.
class SendFlightLanding extends StatefulWidget {
  const SendFlightLanding({
    super.key,
    this.kind = SendFlightKind.videoNote,
    this.color,
    this.bars,
    required this.child,
  });

  final SendFlightKind kind;

  /// A voice bubble's waveform heights (see [SendFlightTicket.bars]).
  final List<double>? bars;

  /// The bubble's fill, for a flight that takes on its colour as it lands.
  final Color? color;

  final Widget child;

  @override
  State<SendFlightLanding> createState() => _SendFlightLandingState();
}

class _SendFlightLandingState extends State<SendFlightLanding> {
  SendFlightTicket? _ticket;
  final _parts = <SendFlightPart, _SendFlightMarkState>{};

  @override
  void initState() {
    super.initState();
    final ticket = SendFlight.current;
    if (ticket != null && !ticket.claimed && !ticket.closed && ticket.kind == widget.kind) {
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

/// Marks one piece of a landing bubble (see [SendFlightPart]) so a flight can
/// put its own copy exactly on it. Free outside a landing: it finds none and
/// does nothing.
class SendFlightMark extends StatefulWidget {
  const SendFlightMark({super.key, required this.part, required this.child});

  final SendFlightPart part;
  final Widget child;

  @override
  State<SendFlightMark> createState() => _SendFlightMarkState();
}

class _SendFlightMarkState extends State<SendFlightMark> {
  _SendFlightLandingState? _landing;

  @override
  void initState() {
    super.initState();
    _landing = context.findAncestorStateOfType<_SendFlightLandingState>();
    _landing?._parts[widget.part] = this;
  }

  @override
  void dispose() {
    final landing = _landing;
    if (landing != null && identical(landing._parts[widget.part], this)) landing._parts.remove(widget.part);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
