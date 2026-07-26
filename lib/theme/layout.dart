import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Responsive layout foundation.
///
/// The app is otherwise mobile-first; this file introduces the single
/// vocabulary every adaptive decision keys off. The design goal is smooth
/// window resize on desktop/web: layout is decided ONCE by a `LayoutBuilder`
/// at [HomeShell], published through [LayoutScope], and read everywhere via
/// `context.windowClass`. Because [LayoutScope.updateShouldNotify] compares the
/// *enum* (not the raw pixel width), dragging a window within one class rebuilds
/// nothing — only crossing a breakpoint does.
///
/// Breakpoints/spacing are layout-invariant constants (identical across all 9
/// themes), so they live here rather than on the per-theme [AppTheme] object.

enum WindowClass {
  /// Phone / narrow window. The app renders exactly as it did before this
  /// redesign — bottom pill nav, full-screen room pushes, bottom sheets.
  compact,

  /// Tablet / split window. Content centers into a readable column; some grids
  /// gain a column. No two-pane yet.
  medium,

  /// Desktop / wide window. Side rail + two-pane master/detail.
  expanded,
}

class Breakpoints {
  Breakpoints._();

  /// >= [medium] px → [WindowClass.medium].
  static const double medium = 600;

  /// >= [expanded] px → [WindowClass.expanded] (two-pane desktop shell).
  static const double expanded = 1024;

  static WindowClass classOf(double width) => width >= expanded
      ? WindowClass.expanded
      : width >= medium
          ? WindowClass.medium
          : WindowClass.compact;
}

/// Spacing scale — the previously-inline magic numbers, named. Adopt
/// incrementally; existing literals keep working.
class Insets {
  Insets._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 20;
  static const double xl = 28;
  static const double xxl = 40;
}

/// Vertical rhythm of the message transcript.
///
/// **Every row owns only the gap ABOVE it.** That is the whole system, and it is
/// why these are used as `EdgeInsets.only(top:)` at every call site rather than
/// `symmetric(vertical:)`.
///
/// The reason is that Flutter does not collapse adjacent padding, it adds it. So
/// when each row contributes half of its own gap, the space between any two rows
/// depends on which two rows they are: a run of four messages laid out with
/// `vertical: grouped ? 1 : 6` reads 7, 2, 2 — the first boundary is three and a
/// half times the others, for no reason a reader can see, and the same run
/// preceded by a date divider opens wider still. With the gap owned by the row
/// below, every boundary of the same kind measures the same number, and that
/// number is stated in one place.
///
/// Nothing needs bottom padding: the transcript list supplies its own at both
/// ends.
class MessageGap {
  MessageGap._();

  /// Between two messages from the same sender. Tight on purpose — this is what
  /// makes a run read as one block of speech instead of four separate cards.
  static const double withinRun = 3;

  /// Between runs: a new speaker, or the same one returning after a break.
  static const double betweenRuns = 14;

  /// Above a date divider or the room intro. Equal to [betweenRuns] so the air
  /// above a marker matches the air below it — which the following row owns.
  static const double aroundMarker = betweenRuns;
}

/// Max content widths for centered columns on wide screens.
class ContentWidth {
  ContentWidth._();

  /// Settings / forms / feed reading column.
  static const double readable = 720;

  /// Auth / onboarding card — matches the existing login/child_pair precedent.
  static const double auth = 460;
}

/// Last window class observed by the shell's [LayoutBuilder]. Read by code that
/// runs ABOVE the shell and therefore has no [LayoutScope] in its context —
/// notably the push-notification / call-overlay routing in `app.dart`, which
/// must decide "fill the detail pane" vs "push a full screen" without a
/// descendant context. Updated synchronously during the shell's build.
WindowClass gLastWindowClass = WindowClass.compact;

/// Publishes the current [WindowClass] to the subtree. One instance, created by
/// [HomeShell]. Mirrors the `ThemeScope.of(context)` idiom used across the app.
class LayoutScope extends InheritedWidget {
  const LayoutScope({
    super.key,
    required this.windowClass,
    required this.width,
    required super.child,
  });

  final WindowClass windowClass;

  /// Raw available width, for the rare consumer that needs it (e.g. a fluid
  /// max). Prefer [windowClass] — reading width couples you to resize frames.
  final double width;

  static WindowClass of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LayoutScope>()
          ?.windowClass ??
      WindowClass.compact;

  /// Only rebuild dependents when the *class* flips, not on every pixel of a
  /// drag-resize. This is the load-bearing perf decision of the whole redesign.
  @override
  bool updateShouldNotify(LayoutScope oldWidget) =>
      oldWidget.windowClass != windowClass;
}

extension LayoutX on BuildContext {
  WindowClass get windowClass => LayoutScope.of(this);
  bool get isCompact => windowClass == WindowClass.compact;
  bool get isMedium => windowClass == WindowClass.medium;
  bool get isExpanded => windowClass == WindowClass.expanded;
}

/// Max width for a chat message bubble.
///
/// Inside a `ChatPane` (see lib/widgets/chat_pane.dart) this comes from the
/// *pane* the chat actually occupies. Everywhere else it falls back to the
/// window-derived behaviour this function has always had — which is what those
/// surfaces still want: the friend-request draft preview is a full-screen route
/// with no chat pane, and a bubble lifted into the root overlay has no pane
/// ancestor at all.
double messageMaxWidth(BuildContext context) =>
    ChatMetricsScope.maybeOf(context)?.bubbleMaxWidth ??
    _windowBubbleFallback(context);

double _windowBubbleFallback(BuildContext context) {
  switch (context.windowClass) {
    case WindowClass.expanded:
      return 560;
    case WindowClass.medium:
      return MediaQuery.of(context).size.width * 0.62;
    case WindowClass.compact:
      return MediaQuery.of(context).size.width * 0.72;
  }
}

/// Geometry for one chat surface, derived from the width that surface is
/// actually GIVEN rather than from the window.
///
/// This distinction is the whole point. [LayoutScope] describes the window, but
/// in the two-pane desktop shell the room only owns
/// `window - 84 (side rail) - 360 (room list) - 0.5 (divider)`. Sizing bubbles
/// off the window therefore produced a flat 560px bubble in a 580px pane (edge
/// to edge) while the transcript was simultaneously squeezed into a 900px
/// column inside a 1476px pane (~288px of dead gutter each side). Measuring the
/// box we were handed fixes both at once, and needs no knowledge of the shell —
/// so the same type serves the room pane, a pushed full-screen route, and the
/// thread overlay (whose surface genuinely IS the window).
@immutable
class ChatMetrics {
  const ChatMetrics._({
    required this.paneWidth,
    required this.columnWidth,
    required this.bubbleMaxWidth,
    required this.mediaMaxWidth,
    required this.linkPreviewWidth,
    required this.videoMaxWidth,
  });

  // ── tuning ──────────────────────────────────────────────────────────────
  /// Widest the chat surface ever gets. Below this the chat FILLS its pane —
  /// no gutters at any normal laptop width. The trade this number encodes:
  /// "no dead space" vs "a sent and a received bubble still read as parts of
  /// one conversation".
  static const double surfaceMax = 1160;

  /// A bubble is only ever a CEILING — every bubble hugs its own text, so
  /// "hey" is a short pill and only a genuinely long message reaches this and
  /// wraps. These numbers therefore tune the wrap point, i.e. the longest line
  /// of chat text you can be asked to read: ~55-60 characters at the app's
  /// body size. Compact keeps its own 0.72 of the pane (on a phone the pane is
  /// the window, so phones are exactly as they were).
  static const double bubbleFraction = 0.42;
  static const double compactBubbleFraction = 0.72;
  static const double bubbleMin = 240;
  static const double bubbleMax = 400;

  /// Media minimums equal the literals they replace, so phones render exactly
  /// as before and only wide panes see growth.
  static const double mediaFraction = 0.62;
  static const double mediaMin = 240;
  static const double mediaMax = 360;

  /// How tall a photo tile may get, as a multiple of its width.
  ///
  /// The tile is as wide as [mediaMaxWidth] and takes its height from the
  /// picture's own ratio, so the thumbnail is the photograph rather than a
  /// square guess at the middle of it. These bound how far that can go: a
  /// 9:16 screenshot would otherwise be a column taller than the viewport and
  /// push everything said around it off screen, and a panorama would be a
  /// letterbox slit too short to read.
  ///
  /// Only a picture outside the range is cropped, and then only by the
  /// overshoot — `BoxFit.cover` takes it out of the long axis, centred.
  static const double mediaMinHeightFactor = 0.55;
  static const double mediaMaxHeightFactor = 1.5;

  /// Height of a [width]-wide photo tile showing a picture of ratio [aspect]
  /// (width÷height), clamped to the factors above.
  ///
  /// Pass a null [aspect] for a picture whose ratio isn't known yet — the tile
  /// stands on a square until one arrives, which is the middle of the range and
  /// so the smallest reflow either way.
  static double mediaTileHeight(double width, double? aspect) {
    final natural = aspect == null || !aspect.isFinite || aspect <= 0
        ? width
        : width / aspect;
    return natural.clamp(
      width * mediaMinHeightFactor,
      width * mediaMaxHeightFactor,
    );
  }
  static const double linkFraction = 0.80;
  static const double linkMin = 320;
  static const double linkMax = 460;
  static const double videoFraction = 0.72;
  static const double videoMin = 280;
  static const double videoMax = 420;

  /// Preserves the previous fixed 280x360 video box ratio.
  static const double videoAspectCap = 360 / 280;

  /// Pane width is snapped DOWN to this grid before anything is derived, so a
  /// drag-resize changes the metrics identity once per 32 logical px instead
  /// of once per frame — the same rebuild-avoidance concern that makes
  /// [LayoutScope.updateShouldNotify] compare an enum. Down rather than
  /// nearest, so the column can never exceed the real pane.
  static const double quantum = 32;

  // ── derived ─────────────────────────────────────────────────────────────
  /// Quantized. Deliberately NOT the raw constraint.
  final double paneWidth;
  final double columnWidth;
  final double bubbleMaxWidth;
  final double mediaMaxWidth;
  final double linkPreviewWidth;
  final double videoMaxWidth;

  double get videoMaxHeight => videoMaxWidth * videoAspectCap;

  /// True when the column already fills the pane, so wrapping in a
  /// [ConstrainedBox] would be a no-op — every phone, and every desktop pane
  /// narrower than [surfaceMax].
  bool get columnFillsPane => columnWidth >= paneWidth;

  factory ChatMetrics.forPane(double rawPaneWidth, WindowClass windowClass) {
    final compact = windowClass == WindowClass.compact;
    // A phone never drag-resizes, so there is nothing to quantize away and
    // skipping the snap keeps mobile on exactly the numbers it had before.
    final pane = compact
        ? math.max(1.0, rawPaneWidth)
        : math.max(quantum, (rawPaneWidth / quantum).floorToDouble() * quantum);
    final column = math.min(pane, surfaceMax);
    final bubble = compact
        ? column * compactBubbleFraction
        : (column * bubbleFraction).clamp(bubbleMin, bubbleMax);
    return ChatMetrics._(
      paneWidth: pane,
      columnWidth: column,
      bubbleMaxWidth: bubble,
      mediaMaxWidth: (bubble * mediaFraction).clamp(mediaMin, mediaMax),
      linkPreviewWidth: (bubble * linkFraction).clamp(linkMin, linkMax),
      videoMaxWidth: (bubble * videoFraction).clamp(videoMin, videoMax),
    );
  }

  /// Equality covers exactly what consumers read — deliberately NOT
  /// [paneWidth], which is kept for debugging and tests. Past [surfaceMax]
  /// every consumed value saturates, so dragging a 1600px window out to 1900
  /// compares equal and [ChatMetricsScope.updateShouldNotify] rebuilds
  /// nothing at all. [columnFillsPane] stands in for the part of [paneWidth]
  /// that does change what gets built.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMetrics &&
          other.columnWidth == columnWidth &&
          other.columnFillsPane == columnFillsPane &&
          other.bubbleMaxWidth == bubbleMaxWidth &&
          other.mediaMaxWidth == mediaMaxWidth &&
          other.linkPreviewWidth == linkPreviewWidth &&
          other.videoMaxWidth == videoMaxWidth;

  @override
  int get hashCode => Object.hash(columnWidth, columnFillsPane, bubbleMaxWidth,
      mediaMaxWidth, linkPreviewWidth, videoMaxWidth);

  @override
  String toString() =>
      'ChatMetrics(pane: $paneWidth, column: $columnWidth, bubble: $bubbleMaxWidth)';
}

/// Publishes [ChatMetrics] to one chat surface. Created by `ChatPane`.
class ChatMetricsScope extends InheritedWidget {
  const ChatMetricsScope({
    super.key,
    required this.metrics,
    required super.child,
  });

  final ChatMetrics metrics;

  /// Nullable on purpose: "there is no chat pane here" is a real case
  /// ([messageMaxWidth]'s fallback, root-overlay contexts) and must stay
  /// visible rather than being papered over by [of]'s MediaQuery guess.
  static ChatMetrics? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChatMetricsScope>()
      ?.metrics;

  static ChatMetrics of(BuildContext context) =>
      maybeOf(context) ??
      ChatMetrics.forPane(
          MediaQuery.sizeOf(context).width, context.windowClass);

  /// One-shot read that does NOT register a dependency — for callers outside
  /// a build phase, e.g. capturing the room's metrics when opening a root
  /// overlay that will re-provide them to a lifted bubble.
  static ChatMetrics? readOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ChatMetricsScope>()?.metrics;

  /// Value equality on the derived numbers. Every field is a pure function of
  /// the quantized pane width, so a 1600 -> 1920 drag flips this ten times and
  /// leaves [ChatMetrics.bubbleMaxWidth] (already saturated) untouched.
  @override
  bool updateShouldNotify(ChatMetricsScope oldWidget) =>
      oldWidget.metrics != metrics;
}
