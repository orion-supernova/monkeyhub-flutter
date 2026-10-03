/// The horizontal strip a companion speaks through.
///
/// ── Why one widget and not two ─────────────────────────────────────────────
///
/// There were two: the global download banner and the room's translate bar.
/// They were the same control written twice — a monogram, a line of text, one
/// word of action, and a progress hairline — with the numbers slightly
/// different in each copy (`accent @0.12` against `@0.10`, a 220 ms
/// `AnimatedSize` against none at all). Nothing about "Sebastian is downloading"
/// and "Sebastian is translating" wants different chrome, and the drift was
/// already visible: one strip grew open and the other snapped.
///
/// ── Why it is opaque ───────────────────────────────────────────────────────
///
/// Both copies painted a 10–12% wash of the theme's accent and then set their
/// text in that same accent on top of it. Over a solid settings screen that is
/// merely low-contrast; over a transcript, a photo, or a themed background
/// layer it is whatever the pixels underneath happen to give it — and this app
/// ships thirteen themes, so "whatever the pixels give it" spans a very wide
/// range. The download strip is deliberately non-dismissable, which turned its
/// illegibility into a permanent fixture at the top of every screen.
///
/// So: an opaque [AppTheme.surfaceRaised] fill with a [AppTheme.divider] rule
/// under it, which is exactly the recipe [PinnedMessageBanner] already uses for
/// its non-glass variant — the two now sit above each other in a room and agree.
/// The accent stops being the background and goes back to being the signal: the
/// monogram, the progress fill, and the action word.
library;

import 'package:flutter/material.dart';

import '../companions/companion.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'ios_kit.dart' show quietFill;
import 'liquid_glass.dart';
import 'teardown_safe.dart';

/// Total height of a visible strip.
///
/// Exported for the same reason [kPinnedBannerHeight] is: the liquid chat style
/// floats its chrome OVER the transcript and has to grow the list's top padding
/// by exactly this much. The widget renders boxes of these heights rather than
/// sizing to its content, so the constant and the render cannot drift apart —
/// and the track's slot is reserved even with no progress to report, so a
/// download finishing does not change the strip's height under a reader.
const double kCompanionStripHeight = _kRowHeight + _kTrackHeight;

const double _kRowHeight = 40.0;

/// Height of the progress track under the row. Three points rather than the
/// one-and-a-half-point hairline both strips used to ride on their own bottom
/// border: at 1.5 the "track" was invisible and only the filled part existed,
/// so a download at 4% looked identical to one that had not started.
const double _kTrackHeight = 3.0;

/// Compact-style insets and corner, borrowed wholesale from [PinnedMessageBanner]
/// so the two strips are unmistakably the same family when they stack.
const double _kGlassGutter = 16.0;
const double _kGlassRadius = 20.0;

/// One strip. Zero height, and nothing to hit-test, when [visible] is false.
///
/// The zero-height contract is not a convenience: the download strip lives in a
/// column above the ROOT navigator and spans the top of every screen in the
/// app, so a hidden strip that still ate taps would be a bug nobody could find.
/// Callers mount this unconditionally and let it animate its own arrival.
class CompanionStrip extends StatelessWidget {
  const CompanionStrip({
    super.key,
    required this.visible,
    required this.companion,
    required this.message,
    this.detail,
    this.progress,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.semanticLabel,
    this.muted = false,
    this.glass = false,
    this.safeAreaTop = false,
  });

  /// Whether there is anything to say. False collapses to nothing.
  final bool visible;

  /// Whose monogram leads the row.
  final Companion companion;

  /// The primary line. Set in [AppTheme.ink] — the strip's whole job is to be
  /// read at a glance from wherever the user actually is.
  final String message;

  /// An optional second phrase, trailing the first in softer ink on the same
  /// line: a percentage, a count. Null on strips that have nothing to add.
  final String? detail;

  /// 0..1, or null for a strip with no progress to report. Null removes the
  /// track entirely rather than drawing an empty one — a bar at zero reads as
  /// stuck, not as absent.
  final double? progress;

  /// The one word on the right. Never destructive: this strip can span every
  /// screen in the app, and a Discard that close to a stray thumb is not a
  /// button, it is a trap.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Tapping the strip itself, usually to open the screen that explains it.
  final VoidCallback? onTap;

  /// What a screen reader calls the strip as a whole. The action carries its
  /// own label.
  final String? semanticLabel;

  /// Dims the progress fill for a state that is real but not moving — a paused
  /// download. The text stays at full strength: a paused download is exactly
  /// the state that must not fade into the furniture.
  final bool muted;

  /// A gutter-inset, rounded, frosted pill instead of a full-bleed strip. For
  /// the compact chat style, where this floats over the transcript beside the
  /// header capsule and the composer rather than sitting in a column above them.
  final bool glass;

  /// Whether to inset for the status bar. True only for the strip that lives
  /// above the root navigator, outside any [Scaffold].
  final bool safeAreaTop;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Wraps the empty case too, so the first download of a session grows the
    // strip open instead of snapping it in. The translate bar never did this;
    // now both do.
    return AnimatedSize(
      duration: theme.motionFast,
      curve: theme.motionEntrance,
      alignment: Alignment.topCenter,
      child: visible
          ? _Body(
              companion: companion,
              message: message,
              detail: detail,
              progress: progress,
              actionLabel: actionLabel,
              onAction: onAction,
              onTap: onTap,
              semanticLabel: semanticLabel,
              muted: muted,
              glass: glass,
              safeAreaTop: safeAreaTop,
            )
          : const SizedBox(width: double.infinity, height: 0),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.companion,
    required this.message,
    required this.detail,
    required this.progress,
    required this.actionLabel,
    required this.onAction,
    required this.onTap,
    required this.semanticLabel,
    required this.muted,
    required this.glass,
    required this.safeAreaTop,
  });

  final Companion companion;
  final String message;
  final String? detail;
  final double? progress;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final bool muted;
  final bool glass;
  final bool safeAreaTop;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _kRowHeight,
          child: Row(
            children: [
              const SizedBox(width: 14),
              // The monogram, not a spinner and not a sparkle. This is the one
              // place in the app where a companion speaks without being asked,
              // so it should look like the same someone as everywhere else —
              // see [CompanionMark].
              CompanionMark(
                companion: companion,
                size: 16,
                foreground: theme.accent,
              ),
              const SizedBox(width: 9),
              Expanded(child: _Line(message: message, detail: detail)),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 6),
                _Action(label: actionLabel!, onTap: onAction!),
              ],
              const SizedBox(width: 6),
            ],
          ),
        ),
        _Track(value: progress, muted: muted, rounded: glass),
      ],
    );

    // A tap that opens the screen behind the strip. Opaque so the whole strip
    // is the target, not just the words — and registered OUTSIDE the action, so
    // the action's own hit test wins where they overlap.
    //
    // The label goes on a container node rather than on the monogram: what a
    // screen reader should hear is the strip, once, and then the action beside
    // it — not a decorative glyph competing with the button for attention.
    Widget tappable = onTap == null
        ? content
        : GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: content,
          );
    if (semanticLabel != null) {
      tappable = Semantics(
        container: true,
        label: semanticLabel,
        button: onTap != null,
        child: tappable,
      );
    }

    if (glass) {
      // [LiquidGlass] rather than [GlassSurface]: this is the same chrome as the
      // header capsule and the composer field, so it shares their rounded shape,
      // the user's glass dials, and — because the blur goes through
      // `BackdropFilter.grouped` — their single rasterization pass.
      //
      // The AnimatedSize is the CALLER's, one level up, deliberately: a
      // BackdropFilter inside an animating height is the jank `sheet_surface.dart`
      // warns about at length.
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _kGlassGutter),
        child: LiquidGlass(
          shape: LiquidGlassShape.rounded,
          radius: _kGlassRadius,
          child: tappable,
        ),
      );
    }

    // The SafeArea is INSIDE the decoration, not around it. The fill has to
    // reach under the status bar — this strip is the topmost thing on screen —
    // so wrapping the decoration would leave the background showing above a
    // strip that then looks like it is floating.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        border: Border(bottom: BorderSide(color: theme.divider)),
      ),
      child: safeAreaTop ? SafeArea(bottom: false, child: tappable) : tappable,
    );
  }
}

/// The message, with an optional softer phrase after it.
///
/// One [Text] with two spans rather than two widgets, so the ellipsis lands in
/// the right place: with a [Row], a long message would push the detail off the
/// end and truncate the wrong half.
class _Line extends StatelessWidget {
  const _Line({required this.message, required this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Text.rich(
      TextSpan(
        text: message,
        style: theme.body.copyWith(color: theme.ink),
        children: detail == null
            ? null
            : [
                TextSpan(
                  text: '  ·  $detail',
                  style: theme.caption.copyWith(color: theme.inkMuted),
                ),
              ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// A track with a fill, rather than a fill alone.
///
/// Both strips used to draw only the filled part, one and a half points tall,
/// sitting on their own bottom border. It read as a smear rather than as
/// progress, and at low percentages it read as nothing at all.
class _Track extends StatelessWidget {
  const _Track({required this.value, required this.muted, required this.rounded});

  /// Null on a strip with nothing to report. The SLOT is still reserved — see
  /// [kCompanionStripHeight] — but nothing is drawn in it: an empty track reads
  /// as stuck, where no track reads as absent, which is the truth.
  final double? value;
  final bool muted;

  /// Rounds the ends for the glass variant, whose whole shape is a pill. The
  /// full-bleed strip keeps square ends — it spans the screen, and a rounded
  /// end floating in the middle of a full-width rule looks like a mistake.
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final v = value;
    if (v == null) return const SizedBox(height: _kTrackHeight);
    final radius =
        rounded ? BorderRadius.circular(_kTrackHeight / 2) : BorderRadius.zero;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: rounded ? 12 : 0),
      child: ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: _kTrackHeight,
          width: double.infinity,
          child: DecoratedBox(
            // The same track the install sheet's bar already uses, so the
            // percentage on the strip and the percentage on the sheet look
            // like one measurement seen twice.
            decoration: BoxDecoration(
              color: theme.inkMuted.withValues(alpha: 0.18),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: v.clamp(0.0, 1.0)),
              duration: motion.d(const Duration(milliseconds: 260)),
              curve: motion.c(theme.motionCurve),
              builder: (context, v, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: v,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: muted
                          ? theme.accent.withValues(alpha: 0.45)
                          : theme.accent,
                    ),
                    child: const SizedBox(height: _kTrackHeight),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one word on the right, as an actual control.
///
/// It used to be a bare [Text] inside eight points of horizontal padding, which
/// gave it a target roughly the size of the word. Now it is a pill with the
/// pairing this codebase requires: [FocusableTap] adds the focus node, the
/// Enter/Space binding and the semantics but registers NO gesture recognizer of
/// its own, so the inner [GestureDetector] is what actually receives the
/// pointer. Omitting it produces a control that looks right and does nothing —
/// a mistake that has shipped here before.
///
/// Never an [InkWell]: this app renders no ink and no ripple anywhere.
class _Action extends StatefulWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_Action> createState() => _ActionState();
}

class _ActionState extends State<_Action>
    with TeardownSafe<_Action> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: widget.onTap,
      radius: theme.radiusSm,
      semanticLabel: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: theme.motionFast,
          curve: theme.motionCurve,
          child: Container(
            // Fills the row's height, so the target is 40pt tall even though
            // the pill drawn inside it is not.
            height: _kRowHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: quietFill(theme),
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(
                  widget.label,
                  style: theme.caption.copyWith(
                    color: theme.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
