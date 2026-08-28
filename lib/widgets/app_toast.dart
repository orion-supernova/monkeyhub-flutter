import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';

/// What a toast is *about*, which decides its glyph and its accent.
///
/// Three, not two. "It worked" and "it failed" are the obvious pair, but most
/// of what this app has to say is neither — a cap was reached, a jump missed,
/// the server moved. Painting those in danger red cries wolf, and painting them
/// in success green is a lie; [neutral] is the honest third answer and the
/// default for exactly that reason.
enum ToastTone { neutral, success, danger }

/// A brief message that shows ABOVE whatever is on screen — including a modal
/// bottom sheet — and is this app's ONLY way of saying something in passing.
///
/// **Snackbars are banned here.** Not as a matter of taste: `ScaffoldMessenger`
/// owns a snackbar per Scaffold, and a bottom sheet is a route stacked on top
/// of one, so a snackbar raised from inside a sheet renders *behind* it. The
/// copy confirmations in the invite sheet were being shown correctly and were
/// simply invisible, which is a worse failure than not showing them: the code
/// silently looked right. On top of that a snackbar is Material's own furniture
/// — its shape, its elevation, its typography — on a surface where every other
/// pixel is drawn from [AppTheme], and it looked pasted on in all thirteen.
///
/// This inserts into the ROOT overlay instead. Entries added last paint last,
/// so it lands over the sheet, its scrim, and anything else in the stack.
///
/// Anchored to the TOP. A bottom-anchored toast over a bottom sheet covers the
/// buttons the user just tapped, and on a sheet that reaches the top of the
/// screen there is nowhere at the bottom left to put it.
///
/// **Capture it before an await, the way you used to capture a messenger.**
/// [AppToast.of] takes the overlay and the theme up front, so a confirmation
/// after a round trip does not need a `BuildContext` that may not be mounted
/// any more:
///
/// ```dart
/// final toast = AppToast.of(context);
/// await api.doTheThing();
/// toast.success(l10n.itWorked);
/// ```
class AppToast {
  const AppToast._(this._overlay, this._theme, this._calm);

  final OverlayState? _overlay;
  final AppTheme? _theme;
  final bool _calm;

  /// Captures everything a toast needs from [context] NOW, so it can be shown
  /// later — after an await, from a callback, from a `finally`.
  ///
  /// Never throws and never asserts on a context with no overlay above it: the
  /// whole point of holding one of these across an async gap is that the tree
  /// may have moved on, and a confirmation is not worth a crash.
  factory AppToast.of(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return const AppToast._(null, null, false);
    return AppToast._(
      overlay,
      ThemeScope.of(context),
      MotionScope.of(context).calm,
    );
  }

  /// Shows [message]. Silently does nothing when there was no overlay to show
  /// it in — see [AppToast.of].
  void show(
    String message, {
    ToastTone tone = ToastTone.neutral,
    IconData? icon,
    String? actionLabel,
    VoidCallback? onAction,
    Duration? duration,
  }) {
    final overlay = _overlay;
    final theme = _theme;
    if (overlay == null || theme == null || !overlay.mounted) return;
    if (message.trim().isEmpty) return;
    _ToastHost.instance.show(
      overlay,
      _ToastSpec(
        message: message,
        tone: tone,
        icon: icon,
        actionLabel: onAction == null ? null : actionLabel,
        onAction: actionLabel == null ? null : onAction,
        duration: duration ?? _readingTime(message, hasAction: onAction != null),
        theme: theme,
        calm: _calm,
      ),
    );
  }

  /// "That worked" — a copy, a save, a send that landed.
  void success(String message, {String? actionLabel, VoidCallback? onAction}) =>
      show(
        message,
        tone: ToastTone.success,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  /// "That didn't work" — reserved for genuine failure, so it keeps meaning
  /// something. A cap, a refusal or a rule is [ToastTone.neutral].
  void error(String message, {String? actionLabel, VoidCallback? onAction}) =>
      show(
        message,
        tone: ToastTone.danger,
        actionLabel: actionLabel,
        onAction: onAction,
      );

  /// Takes down whatever is showing, immediately and without animating.
  ///
  /// For teardown — a test's `tearDown`, a sign-out that wipes the tree. Not
  /// for ordinary use: a toast that vanishes on a schedule nobody can see is
  /// how a confirmation ends up describing the wrong tap.
  static void hide() => _ToastHost.instance.hideNow();

  /// How long [message] is on screen for.
  ///
  /// Scaled by length rather than fixed, because 1.9 seconds is comfortable for
  /// "copied" and genuinely too short for a sentence explaining why a post was
  /// refused — and a message nobody finished reading may as well not have been
  /// shown. One with an action gets longer still: it is asking for a decision,
  /// not reporting a fact.
  static Duration _readingTime(String message, {required bool hasAction}) {
    // ~14 characters per second, which is a deliberately slow reader, on top of
    // a fixed 1.4s of "notice it, look up".
    final ms = 1400 + (message.characters.length * 70);
    final floor = hasAction ? 4200 : 1900;
    return Duration(milliseconds: ms.clamp(floor, 7000));
  }
}

/// Shorthand for the one-liner case: `showAppToast(context, 'copied')`.
///
/// Prefer [AppToast.of] when anything is awaited between deciding to say
/// something and saying it.
void showAppToast(
  BuildContext context,
  String message, {
  ToastTone tone = ToastTone.neutral,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) => AppToast.of(context).show(
  message,
  tone: tone,
  icon: icon,
  actionLabel: actionLabel,
  onAction: onAction,
  duration: duration,
);

/// Everything one toast needs to draw and time itself.
@immutable
class _ToastSpec {
  const _ToastSpec({
    required this.message,
    required this.tone,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.theme,
    required this.calm,
  });

  final String message;
  final ToastTone tone;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;

  /// Captured rather than read from the overlay's context: an `OverlayEntry`'s
  /// builder is parented to the Overlay, and while [ThemeScope] does sit above
  /// it, depending on it from there would rebuild the whole root overlay on
  /// every theme change to repaint one pill.
  final AppTheme theme;

  /// Reduce Motion, resolved at the call site for the same reason.
  final bool calm;

  Color get accent => switch (tone) {
    ToastTone.success => theme.success,
    ToastTone.danger => theme.danger,
    ToastTone.neutral => theme.accent,
  };

  IconData get glyph =>
      icon ??
      switch (tone) {
        ToastTone.success => Icons.check_rounded,
        ToastTone.danger => Icons.error_outline_rounded,
        ToastTone.neutral => Icons.info_outline_rounded,
      };
}

/// Owns the single live toast.
///
/// **Deliberately not a queue.** A second toast replaces the first rather than
/// waiting behind it. These confirm a tap, and a confirmation that arrives
/// after the tap-after-next is describing the wrong thing — the exact bug the
/// snackbar version had when copy-link and copy-code were tapped in sequence.
/// The replacement is animated rather than cut: the outgoing pill leaves, and
/// the new one arrives once it has, which reads as one thing being corrected
/// instead of two things fighting.
///
/// **A fresh `OverlayEntry` every time, never one kept alive between toasts.**
/// An idle entry parked in the root overlay is an entry that every route pushed
/// afterwards is inserted *above* — so the next toast would paint behind the
/// sheet it was raised from, which is the entire failure this file exists to
/// fix, reintroduced by an optimization.
class _ToastHost {
  _ToastHost._();
  static final _ToastHost instance = _ToastHost._();

  _ToastEntry? _live;

  /// Cancels a swap that a third toast has already made stale.
  int _seq = 0;

  void show(OverlayState overlay, _ToastSpec spec) {
    _seq++;
    final seq = _seq;
    final live = _live;
    if (live == null) {
      _insert(overlay, spec, seq);
      return;
    }
    _live = null;
    live.retire();
    if (spec.calm) {
      _insert(overlay, spec, seq);
      return;
    }
    // Long enough for the outgoing pill to clear, short enough that nobody
    // reads it as a gap. Matches the exit duration below.
    Timer(const Duration(milliseconds: 160), () {
      if (seq != _seq || !overlay.mounted) return;
      _insert(overlay, spec, seq);
    });
  }

  void _insert(OverlayState overlay, _ToastSpec spec, int seq) {
    final entry = _ToastEntry(spec);
    entry.overlayEntry = OverlayEntry(
      builder: (context) => _Toast(
        spec: spec,
        handle: entry,
        onDismissed: () {
          if (_seq == seq) _live = null;
          entry.dispose();
        },
      ),
    );
    _live = entry;
    overlay.insert(entry.overlayEntry!);
  }

  void hideNow() {
    _seq++;
    _live?.dispose();
    _live = null;
  }
}

/// The host's half of one live toast: a way to ask it to leave, and the entry
/// to tear down once it has.
class _ToastEntry {
  _ToastEntry(this.spec);

  final _ToastSpec spec;
  OverlayEntry? overlayEntry;

  /// Set by the widget once it is mounted, so the host can ask it to animate
  /// out. Null while the entry is inserted but has not built yet — a toast
  /// replaced inside one frame simply disappears, which is correct.
  VoidCallback? leave;

  void retire() {
    final go = leave;
    if (go == null) {
      dispose();
      return;
    }
    go();
  }

  void dispose() {
    // `mounted` guard: the route the overlay belonged to can be gone by the
    // time this runs — closing a sheet immediately after a copy is a completely
    // ordinary thing to do.
    final entry = overlayEntry;
    overlayEntry = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.spec,
    required this.handle,
    required this.onDismissed,
  });

  final _ToastSpec spec;
  final _ToastEntry handle;
  final VoidCallback onDismissed;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.spec.calm
        ? Duration.zero
        : const Duration(milliseconds: 260),
    reverseDuration: widget.spec.calm
        ? Duration.zero
        : const Duration(milliseconds: 160),
  );

  Timer? _timer;

  /// Live upward drag, in logical pixels and never positive — a toast is
  /// flicked away toward the edge it came from, and dragging it further DOWN
  /// into the screen it is covering is not a gesture anyone means.
  double _drag = 0;

  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    widget.handle.leave = _leave;
    _ctrl.forward();
    _timer = Timer(widget.spec.duration, _leave);
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Only if it is still ours: a replacement toast has already claimed the
    // handle by the time this one is torn down.
    if (identical(widget.handle.leave, _leave)) widget.handle.leave = null;
    _ctrl.dispose();
    super.dispose();
  }

  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    _ctrl.reverse().whenCompleteOrCancel(() {
      if (mounted) widget.onDismissed();
    });
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_leaving) return;
    // Resistance downward, none upward: the toast follows a flick toward the
    // top edge exactly, and merely acknowledges a pull the other way.
    final delta = d.delta.dy > 0 ? d.delta.dy * 0.25 : d.delta.dy;
    setState(() => _drag = (_drag + delta).clamp(-160.0, 24.0));
  }

  void _onDragEnd(DragEndDetails d) {
    if (_leaving) return;
    final velocity = d.velocity.pixelsPerSecond.dy;
    if (_drag < -26 || velocity < -420) {
      _leave();
      return;
    }
    setState(() => _drag = 0);
  }

  void _act() {
    final action = widget.spec.onAction;
    _leave();
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final theme = spec.theme;
    final top = MediaQuery.paddingOf(context).top;

    return Positioned(
      // Just under the status bar, and inset from both edges so it reads as a
      // floating pill rather than a banner welded to the top.
      top: top + 10,
      left: 16,
      right: 16,
      // Material + DefaultTextStyle, or every glyph in here gets Flutter's
      // yellow double underline.
      //
      // An OverlayEntry is parented to the Overlay, NOT to the MaterialApp's
      // subtree, so there is no Material and no inherited text style above it.
      // Flutter's response to unstyled text is that debug decoration, which
      // ships to users as a bug that looks like a rendering fault.
      //
      // `transparency` rather than a real Material: the pill paints its own
      // surface below, and a second one would double the shadow.
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: theme.body,
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              final v = Curves.easeOutCubic.transform(_ctrl.value);
              // The drag reads as the pill being carried off, so it takes the
              // opacity with it — otherwise a half-flicked toast hangs at the
              // edge of the screen at full strength.
              final carried = (1 - (_drag.abs() / 90)).clamp(0.0, 1.0);
              return Opacity(
                opacity: (v * carried).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, _drag + (1 - v) * -22),
                  child: Transform.scale(scale: 0.96 + 0.04 * v, child: child),
                ),
              );
            },
            // Built once: none of it depends on the drag or the entrance.
            child: Center(
              child: ConstrainedBox(
                // Capped so a toast on a desktop window is a pill in the middle
                // rather than a rule drawn across the whole title bar.
                constraints: const BoxConstraints(maxWidth: 460),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  // A tap dismisses only when there is nothing else to hit. With
                  // an action on board, a stray tap would take the offer away.
                  onTap: spec.onAction == null ? _leave : null,
                  child: _Pill(spec: spec, onAction: _act),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill itself: a frosted capsule, a tone-coloured glyph, the message, and
/// optionally one thing to do about it.
class _Pill extends StatelessWidget {
  const _Pill({required this.spec, required this.onAction});

  final _ToastSpec spec;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = spec.theme;
    final accent = spec.accent;
    final label = spec.actionLabel;

    return Semantics(
      // So a screen reader speaks the message when it appears rather than only
      // when something happens to focus it. The pill itself is not focusable —
      // there is nothing to do with it but read it (and, when there is an
      // action, the button below carries its own semantics).
      liveRegion: true,
      container: true,
      label: spec.message,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_radius),
          // Two shadows rather than one: a tight dark contact shadow so the
          // pill sits ON the screen, and a wide soft one so it reads as
          // floating well above it. A single blur can do one or the other.
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius),
          child: BackdropFilter(
            // Frosted rather than opaque. This lands over Risograph's halftone
            // and Cyberpunk's scanlines as often as over a flat surface, and a
            // solid rectangle punches a hole in both; blurring what is behind
            // it keeps the pill part of the screen it interrupts.
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              padding: EdgeInsets.fromLTRB(10, 9, label == null ? 16 : 8, 9),
              decoration: BoxDecoration(
                color: theme.surfaceRaised.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: accent.withValues(alpha: 0.38),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(spec.glyph, size: 15, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      spec.message,
                      style: theme.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (label != null) ...[
                    const SizedBox(width: 10),
                    _ActionButton(
                      label: label,
                      accent: theme.accent,
                      onTap: onAction,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Nearly a capsule at one line and a well-rounded card at three, without
  /// the geometry having to know which it is.
  static const double _radius = 20;
}

/// The optional trailing control — UNDO, RETRY, the offer a message makes.
///
/// Always the theme accent, never the tone colour: this is the one thing on the
/// pill you can press, and a red "RETRY" beside a red error glyph loses the
/// distinction between what happened and what you can do about it.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      shape: FocusRingShape.capsule,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              // Explicit: see the DefaultTextStyle note above. Anything under
              // an OverlayEntry that does not state this can fall back to the
              // debug style.
              decoration: TextDecoration.none,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}
