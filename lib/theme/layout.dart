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

/// Max content widths for centered columns on wide screens.
class ContentWidth {
  ContentWidth._();

  /// Settings / forms / feed reading column.
  static const double readable = 720;

  /// Chat room text column on very wide detail panes.
  static const double roomDetail = 900;

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

/// Max width for a chat message bubble. Replaces the four hard-coded
/// `MediaQuery.of(context).size.width * 0.72` sites. On desktop a percentage of
/// the (wide) window produced absurdly long single lines, so the expanded class
/// returns a fixed comfortable measure that ignores width entirely — which also
/// means it never rebuilds on resize.
double messageMaxWidth(BuildContext context) {
  switch (context.windowClass) {
    case WindowClass.expanded:
      return 560;
    case WindowClass.medium:
      return MediaQuery.of(context).size.width * 0.62;
    case WindowClass.compact:
      return MediaQuery.of(context).size.width * 0.72;
  }
}
