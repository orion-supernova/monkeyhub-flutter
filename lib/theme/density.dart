import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../data/settings_store.dart';

/// How tightly the app's rows and chrome buttons are set: phone size, or the
/// compact metrics a mouse can afford.
///
/// The app was drawn for a finger: a 76pt chat row, a 52pt settings row, a
/// 40pt glass disc. Under a pointer that precision is wasted, and on a laptop
/// screen it reads as a phone app blown up, a third of the list it could show.
/// Compact is iMessage-for-Mac and Telegram Desktop's density: a 64pt chat row
/// with a 44pt face, a 40pt settings row, a 32pt disc.
///
/// ONE place for these numbers, so the chat list, the settings rows and the
/// chrome buttons can never disagree about which density they are in. Widgets
/// read [Density.of] and pick a metric; none of them branches on platform.
///
/// Type is deliberately not here yet beyond the chat row's own lines: the
/// app's body sizes are spread over hundreds of call sites (the grouped type
/// scale alone has ~200), and shrinking some of them would leave pages with
/// two type sizes side by side.
@immutable
class Density {
  const Density._(this.compact);

  /// Phone metrics, as the app shipped.
  static const regular = Density._(false);

  /// Desktop metrics.
  static const compactLayout = Density._(true);

  final bool compact;

  // ── chat list row ──
  /// Avatar diameter on a chat row.
  double get chatRowAvatar => compact ? 44 : 54;

  /// Avatar to text.
  double get chatRowGap => compact ? 12 : 14;

  /// Where the row's text, and its hairline, begin.
  double get chatRowTextInset => chatRowAvatar + chatRowGap;

  /// Above and below the row's content. 10 makes a phone row ~76pt; 6 with
  /// the compact type below makes 64.
  double get chatRowPadding => compact ? 6 : 10;

  /// The name. Null keeps the theme's own emphasised body size.
  double? get chatRowTitleSize => compact ? 14 : null;

  /// The two-line preview.
  double get chatRowPreviewSize => compact ? 13 : 15;
  double get chatRowPreviewHeight => compact ? 1.25 : 1.3;

  /// The time stamp.
  double get chatRowStampSize => compact ? 12 : 15;

  /// Name to preview.
  double get chatRowLineGap => compact ? 2 : 3;

  // ── grouped (settings) row ──
  /// The floor of a one-line grouped row.
  double get groupedRowMinHeight => compact ? 40 : 52;

  /// Above and below a grouped row's content: 11 + a 30pt tile + 11 = 52 on
  /// a phone, 7 + 26 + 7 = 40 compact.
  double get groupedRowPadding => compact ? 7 : 11;

  /// The coloured tile at a grouped row's leading edge.
  double get groupedTile => compact ? 26 : 30;

  /// Tile to title.
  double get groupedTileGap => compact ? 12 : 14;

  /// Where a grouped row's text, and the hairline under it, start.
  double get groupedTextInset => 16 + groupedTile + groupedTileGap;

  // ── chrome buttons ──
  /// The glass disc's diameter (back, ×, ✓, more) and a pill's height, so
  /// the two still sit on one line.
  double get iconButton => compact ? 32 : 40;

  /// A glyph drawn for a 40pt disc, scaled to [iconButton].
  double iconGlyph(double forFortyPt) => forFortyPt * iconButton / 40;

  /// A sheet's title bar.
  double get sheetBarHeight => compact ? 44 : 52;

  /// Whether this platform is offered compact density at all: a desktop OS,
  /// native or in a browser. Phones and tablets never are; on web this reads
  /// the browser's OS, so Chrome on Android stays regular.
  static bool get platformOffersCompact =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  /// The density the settings ask for, read without subscribing.
  static Density get current =>
      platformOffersCompact && SettingsStore.instance.compactDesktop
          ? compactLayout
          : regular;

  /// The density for [context]. Rebuilds the caller when the setting flips,
  /// via [DensityScope]; with no scope above (a test) it is [current].
  static Density of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DensityInherited>()?.density ??
      current;
}

/// Publishes [Density] below the app's root, listening to the one setting it
/// derives from so only widgets that read a metric rebuild when it flips.
class DensityScope extends StatefulWidget {
  const DensityScope({super.key, required this.child});
  final Widget child;

  @override
  State<DensityScope> createState() => _DensityScopeState();
}

class _DensityScopeState extends State<DensityScope> {
  Density _density = Density.current;

  @override
  void initState() {
    super.initState();
    // Phones never change density; they need no listener at all.
    if (Density.platformOffersCompact) {
      SettingsStore.instance.addListener(_sync);
    }
  }

  void _sync() {
    final d = Density.current;
    if (d.compact != _density.compact && mounted) {
      setState(() => _density = d);
    }
  }

  @override
  void dispose() {
    if (Density.platformOffersCompact) {
      SettingsStore.instance.removeListener(_sync);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _DensityInherited(density: _density, child: widget.child);
}

class _DensityInherited extends InheritedWidget {
  const _DensityInherited({required this.density, required super.child});
  final Density density;

  @override
  bool updateShouldNotify(_DensityInherited old) =>
      old.density.compact != density.compact;
}
