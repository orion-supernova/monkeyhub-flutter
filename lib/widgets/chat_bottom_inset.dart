/// How much room the chrome floating over a transcript's bottom edge is
/// actually taking — measured on the frame it changes, not guessed once.
///
/// The liquid chat style floats its composer stack over a `Positioned.fill`
/// transcript, so nothing in the layout holds the newest bubble clear of it:
/// the transcript reserves that room by hand. The reservation used to be a
/// constant (60pt, plus the scheduled pill), which is exactly right for one
/// composer — an empty one, on one line. Type a second line and the field grows
/// UPWARD, over the conversation, and the last thing anybody said sits behind
/// the glass.
///
/// So it is measured. [MeasureChatBottomInset] wraps the chrome and publishes
/// its height; the transcript spends that as a spacer at its bottom edge and
/// the jump-to-latest pills as an offset. Growth and shrink are then one code
/// path, and chrome that grows for any OTHER reason — a reply card, the
/// @-picker, the scheduled pill — is covered without anyone remembering to add
/// a constant for it.
///
/// The classic style needs none of this and passes null everywhere: its
/// composer sits in a real `Column` above an `Expanded` transcript, so the
/// viewport already shrinks by exactly the right amount for free. Keeping that
/// path constant-folded rather than routing it through a measurement it does
/// not need is deliberate.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Which of the chrome's two heights a [MeasureChatBottomInset] reports.
///
/// There are two because the chrome's height ANIMATES — the composer stack sits
/// in an `AnimatedSize`, so on any given frame where it is and where it is
/// going are different numbers, and reserving for either one alone is wrong in
/// one direction:
///
///  * reserve the drawn height and a GROWING composer outruns the transcript,
///    because a measurement can only be published at the end of the frame it
///    was taken in. The newest bubble spends the whole ease a frame behind the
///    glass — which at the front of an entrance curve is a dozen points of it
///    covered, for as long as the animation lasts;
///  * reserve the target and a SHRINKING composer is outrun by the transcript
///    instead. The list drops the full distance at once while the glass is
///    still on its way down, and the bubble lands underneath it.
///
/// [ChatBottomInset] keeps the larger of the two, so the reservation snaps open
/// and eases closed and the conversation is never behind the glass in either
/// direction.
enum ChatChromeHeight {
  /// Where the chrome is GOING: its natural height, known on the frame the text
  /// wraps. Measured INSIDE the growth animation.
  ///
  /// Free during the animation itself — the animation does not relayout the
  /// child, so this reports only when the height genuinely changes.
  target,

  /// Where the chrome IS: the height being painted this frame. Measured
  /// OUTSIDE the growth animation.
  drawn,
}

/// What a transcript must keep clear at its bottom edge.
///
/// Null until the chrome has been laid out once — see [ChatBottomChrome] for
/// what stands in until then.
class ChatBottomInset extends ChangeNotifier {
  double? _target;
  double? _drawn;

  /// The larger of where the chrome is and where it is going. See
  /// [ChatChromeHeight] for why it is the larger and not either one.
  double? get height {
    final target = _target;
    final drawn = _drawn;
    if (target == null) return drawn;
    if (drawn == null) return target;
    return math.max(target, drawn);
  }

  void report(ChatChromeHeight which, double value) {
    final before = height;
    switch (which) {
      case ChatChromeHeight.target:
        _target = value;
      case ChatChromeHeight.drawn:
        _drawn = value;
    }
    // The max swallows most reports outright — every frame of a grow animation
    // publishes a new drawn height under a target that already covers it — and
    // a report that changes nothing must not rebuild the transcript.
    if (height != before) notifyListeners();
  }
}

/// A transcript's floating bottom chrome: what it measures, and what to assume
/// until the first measurement lands.
///
/// [estimate] is NOT a fallback for a failed measurement — it is what the
/// transcript spends on its very first frame, before the chrome has been laid
/// out even once. Hosts compute it from the same constants the chrome is built
/// from, so a room opens with its newest message already in the right place
/// instead of correcting itself a frame later.
typedef ChatBottomChrome = ({ChatBottomInset inset, double estimate});

/// Publishes [child]'s height to [inset] under [which], whenever it changes.
///
/// A render object rather than a `LayoutBuilder` + `SizeChangedLayoutNotifier`
/// pair because this measures a subtree that relayouts on every frame of an
/// `AnimatedSize` growth: it has to be free when the height is unchanged, and a
/// notifier that fired on equal values would rebuild the transcript ten times
/// for one new line of text.
class MeasureChatBottomInset extends SingleChildRenderObjectWidget {
  const MeasureChatBottomInset({
    super.key,
    required this.inset,
    required this.which,
    required Widget super.child,
  });

  final ChatBottomInset inset;

  /// Which height this instance is measuring — which is to say, whether it sits
  /// inside or outside the growth animation. See [ChatChromeHeight].
  final ChatChromeHeight which;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureChatBottomInset(inset, which);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderMeasureChatBottomInset)
      ..which = which
      ..inset = inset;
  }
}

class _RenderMeasureChatBottomInset extends RenderProxyBox {
  _RenderMeasureChatBottomInset(this._inset, this._which);

  ChatBottomInset _inset;
  set inset(ChatBottomInset value) {
    if (identical(_inset, value)) return;
    _inset = value;
    // The new inset has never heard from us, so what the old one was told says
    // nothing about whether this one is up to date.
    _published = null;
    _publish();
  }

  ChatChromeHeight _which;
  set which(ChatChromeHeight value) {
    if (_which == value) return;
    _which = value;
    _published = null;
    _publish();
  }

  /// The height already handed to the inset, or queued for it. The whole point
  /// of this class: an unchanged height costs a double comparison.
  double? _published;
  bool _queued = false;
  bool _disposed = false;

  @override
  void performLayout() {
    super.performLayout();
    _publish();
  }

  void _publish() {
    if (!hasSize) return;
    final height = size.height;
    if (_published == height) return;
    _published = height;
    if (_queued) return;
    _queued = true;
    // Deferred out of layout deliberately, and this is not a nicety: the
    // transcript reads the inset through a `ListenableBuilder`, so notifying
    // from `performLayout` would mark a widget dirty in the middle of the
    // layout pass that widget belongs to — an assertion, not a race.
    //
    // The cost is one frame, and `ChatChromeHeight` is how it is paid for: the
    // target height is published a frame after the text wraps and then stands
    // still, so the reservation is open before the glass gets anywhere near it.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (_disposed) return;
      _inset.report(_which, _published!);
    });
  }

  @override
  void dispose() {
    // Not `attached`: a reparent detaches us for a frame, and a measurement
    // dropped there would never be re-sent (`_published` already matches). This
    // fires exactly once, when there is genuinely nobody left to tell.
    _disposed = true;
    super.dispose();
  }
}

/// Rebuilds [builder] with the chrome's current height, or with
/// [ChatBottomChrome.estimate] before the first measurement lands.
///
/// A null [chrome] calls [builder] with `0` and adds no listener at all, so the
/// classic chat style is byte-identical to a plain call — see the library note.
///
/// [child] is the `ListenableBuilder` escape hatch, and it earns its keep here:
/// the jump-to-latest pills carry their own animation slots and have no
/// business rebuilding because the composer gained a line.
class ChatBottomInsetBuilder extends StatelessWidget {
  const ChatBottomInsetBuilder({
    super.key,
    required this.chrome,
    required this.builder,
    this.child,
  });

  final ChatBottomChrome? chrome;
  final Widget Function(BuildContext context, double inset, Widget? child)
      builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final chrome = this.chrome;
    if (chrome == null) return builder(context, 0, child);
    return ListenableBuilder(
      listenable: chrome.inset,
      builder: (context, child) =>
          builder(context, chrome.inset.height ?? chrome.estimate, child),
      child: child,
    );
  }
}
