import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../backend/server_directory.dart';
import '../backend/server_store.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show rootNavigatorKey;
import '../theme/theme_scope.dart';
import 'server_role_sheet.dart';

/// The palette the mark paints in, chosen per [ServerRole].
///
/// Deliberately NOT `theme.accent`. The accent is what every ordinary control
/// in the app is drawn in, so a marker wearing it reads as one more piece of
/// chrome — the opposite of something whose entire job is to look like it does
/// not belong. Fixed hex rather than theme tokens for the same reason: this
/// must look identical, and equally out of place, under all fourteen themes.
class _Palette {
  const _Palette({required this.ink, required this.fill, required this.border});

  /// Text, dot, and the ribbon's own field.
  final Color ink;

  /// The backing. Near-opaque, and dark under every theme: the bar sits behind
  /// the OS status glyphs, which are painted last and in white.
  final Color fill;

  final Color border;

  /// The operator has moved traffic to the home server. Warm amber — the one
  /// hue nothing else in this app uses, so it cannot be confused with chrome —
  /// and pointedly not `theme.danger`, which everywhere else means something
  /// has gone wrong. Being on the home server is a deliberate arrangement, not
  /// a fault.
  static const homeserver = _Palette(
    ink: Color(0xFFE8A33D),
    fill: Color(0xF21C1509),
    border: Color(0x59E8A33D),
  );

  /// Somebody's own backend. Not a warning at all — a statement of fact — so it
  /// gets a quiet graphite that reads as a label rather than an alarm.
  static const selfHosted = _Palette(
    ink: Color(0xFF9AA3AE),
    fill: Color(0xF215181C),
    border: Color(0x4D9AA3AE),
  );

  static _Palette of(ServerRole role) =>
      role == ServerRole.homeserver ? homeserver : selfHosted;

  /// Text on top of a solid [ink] field — the ribbon's label. Near-black rather
  /// than white: amber at this weight is far too light to carry white text.
  static const onInk = Color(0xFF141414);
}

/// What the mark says, given where the app is pointed.
///
/// Split out because several surfaces need the same answer, and getting it
/// wrong in one of them leaks a deployment URL. The operator's addresses are
/// infrastructure; only a server the user typed in themselves is theirs to see.
/// See [ServerStore.isSelfHosted].
({String long, String short, String semantics}) serverMarkLabels(
  BuildContext context,
) {
  final l10n = AppLocalizations.of(context);
  final store = ServerStore.instance;
  if (store.role == ServerRole.homeserver) {
    return (
      long: l10n.serverBadgeHomeserver,
      short: l10n.serverBadgeHomeserverShort,
      semantics: l10n.serverBadgeHomeserverSemantics,
    );
  }
  return (
    long: shortHost(store.host, max: 28),
    short: l10n.serverBadgeSelfHosted,
    semantics: l10n.serverBadgeSelfHostedSemantics(store.host),
  );
}

/// A strip across the top of the app saying which server this is, that
/// everything else sits underneath.
///
/// ───────── why a bar and not an overlay ─────────
///
/// Three overlay shapes were tried before this one and each collided with
/// something it could not avoid. A chip centred in the status-bar strip is
/// drawn over by the clock, the dynamic island and the battery, because the
/// system composites its glyphs last and no app can paint above them. A chip
/// below the strip lands on whatever the current route put in its top-right. A
/// corner ribbon large enough to be tappable sweeps through where full-screen
/// routes put their close button.
///
/// A bar has none of those problems, because it overlaps nothing: it takes its
/// own height out of the layout and the app begins below it. It also gives the
/// tap a target the width of the screen, which is what a permanent
/// explain-yourself affordance actually wants.
///
/// ───────── how it takes that height ─────────
///
/// The bar draws from y=0 and pads itself by the top inset, so its background
/// fills the status-bar strip and the OS glyphs land on it rather than on app
/// content — exactly how an opaque app bar behaves under edge-to-edge. In
/// exchange, `app.dart` strips `padding.top` from everything below, so the
/// SafeArea on every screen adds nothing and content is not inset twice. That
/// pairing is load-bearing: see [consumesTopInset].
class SelfHostBar extends StatelessWidget {
  const SelfHostBar({super.key, this.onTap, this.style});

  /// Overrides what a tap opens. Test seam; production opens the info sheet.
  final VoidCallback? onTap;

  /// Forces a style instead of reading the user's. Test seam only — writing the
  /// preference goes through secure storage, whose reply never arrives under a
  /// widget test's fake clock, so a test that set it would simply hang.
  final SelfHostBadgeStyle? style;

  /// Height of the bar's content, below the status-bar inset.
  ///
  /// Also the exact amount every screen in the app moves down by while this is
  /// showing, which is why it is stated once and read from here.
  static const double contentHeight = 26;

  /// Whether a bar is being drawn right now.
  ///
  /// `app.dart` reads this to decide whether to remove `padding.top` from the
  /// subtree below. The two must agree, or the app is inset either twice or not
  /// at all, so neither side is allowed its own copy of the condition.
  static bool get consumesTopInset =>
      consumesTopInsetFor(SettingsStore.instance.selfHostBadge);

  /// The same question against an explicit style, for the test seam.
  static bool consumesTopInsetFor(SelfHostBadgeStyle style) =>
      ServerStore.instance.announcesRole && style == SelfHostBadgeStyle.bar;

  @override
  Widget build(BuildContext context) {
    if (!consumesTopInsetFor(style ?? SettingsStore.instance.selfHostBadge)) {
      return const SizedBox.shrink();
    }
    final theme = ThemeScope.of(context);
    final store = ServerStore.instance;
    final palette = _Palette.of(store.role);
    final labels = serverMarkLabels(context);
    final top = MediaQuery.paddingOf(context).top;
    return GestureDetector(
      onTap: onTap ?? () => showServerRoleSheet(context),
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        container: true,
        button: true,
        label: labels.semantics,
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            height: top + contentHeight,
            padding: EdgeInsets.only(top: top),
            decoration: BoxDecoration(
              color: palette.fill,
              border: Border(
                bottom: BorderSide(color: palette.border, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.ink,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                // Flexible, not fixed: the label is a full sentence in twelve
                // languages, and this is the one shape with room for all of
                // them. It still may not push the glyph off the end.
                Flexible(
                  child: Text(
                    labels.long,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.monoTiny.copyWith(
                      color: palette.ink,
                      fontSize: 10,
                      letterSpacing: 0.4,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Icon(Icons.info_outline, size: 12, color: palette.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The corner-ribbon alternative: an overlay that takes no height.
///
/// Renders nothing unless the ribbon style is selected, so the app can mount
/// both this and [SelfHostBar] unconditionally and let the preference decide
/// which appears.
///
/// Two rules keep an overlay in the top-right corner from being a bug in
/// itself:
///
///  * **It only takes taps on the shape it paints.** The gesture detector sits
///    INSIDE the rotation, so the extreme corner — where a close button goes —
///    passes pointers straight through. The tests assert exactly that.
///  * **It never draws a debug underline.** Overlay content sits outside any
///    route's Material, so its own [Material] + [DefaultTextStyle] are
///    load-bearing, not decoration.
class SelfHostBadge extends StatelessWidget {
  const SelfHostBadge({super.key, this.onTap, this.style});

  /// Overrides what a tap opens. Test seam; production opens the info sheet.
  final VoidCallback? onTap;

  /// Forces a style instead of reading the user's. Test seam — see
  /// [SelfHostBar.style].
  final SelfHostBadgeStyle? style;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ServerStore.instance,
        SettingsStore.instance,
      ]),
      builder: (context, _) {
        final store = ServerStore.instance;
        if (!store.announcesRole) return const SizedBox.shrink();
        final shape = style ?? SettingsStore.instance.selfHostBadge;
        if (shape != SelfHostBadgeStyle.ribbon) {
          return const SizedBox.shrink();
        }
        final theme = ThemeScope.of(context);
        final labels = serverMarkLabels(context);
        return Positioned(
          top: 0,
          right: 0,
          child: Material(
            type: MaterialType.transparency,
            child: DefaultTextStyle(
              style: theme.monoTiny,
              child: _Ribbon(
                label: labels.short,
                semanticLabel: labels.semantics,
                palette: _Palette.of(store.role),
                onTap: onTap ?? () => showServerRoleSheet(context),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A scaled-down copy of the real thing, for the picker on the server screen.
///
/// Renders the SAME widgets the app draws, shrunk — never a hand-drawn
/// miniature. A separately-authored preview is one that can disagree with the
/// thing it previews, and that is not hypothetical here: an early version of
/// this file had the ribbon rotated one way and its miniature rotated the
/// other, so neither could flag the other and only a render caught it.
class SelfHostBadgePreview extends StatelessWidget {
  const SelfHostBadgePreview({
    super.key,
    required this.style,
    required this.label,
    required this.role,
  });

  final SelfHostBadgeStyle style;
  final String label;
  final ServerRole role;

  static const double width = 74;
  static const double height = 44;

  /// Enough that the corner reads at this size, and small enough that the
  /// ribbon's square fits inside the frame.
  static const double _scale = 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final palette = _Palette.of(role);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: theme.surfaceSunken,
          child: switch (style) {
            // A miniature of the LAYOUT, not of the widget. What distinguishes
            // the bar is that the app sits under it, and a picture of the strip
            // on its own would not show the thing being chosen.
            SelfHostBadgeStyle.bar => Column(
              children: [
                Container(
                  height: 9,
                  decoration: BoxDecoration(
                    color: palette.fill,
                    border: Border(
                      bottom: BorderSide(color: palette.border, width: 0.5),
                    ),
                  ),
                  child: Center(
                    child: Container(width: 26, height: 2, color: palette.ink),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final w in const [1.0, 0.7, 0.85])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: w,
                              child: Container(height: 3, color: theme.divider),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SelfHostBadgeStyle.ribbon => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: 0,
                  right: 0,
                  child: Transform.scale(
                    scale: _scale,
                    alignment: Alignment.topRight,
                    child: _Ribbon(
                      label: label,
                      semanticLabel: label,
                      palette: palette,
                      onTap: null,
                    ),
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}

/// A corner band, at Flutter's debug-banner angle.
class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.label,
    required this.semanticLabel,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final _Palette palette;
  final VoidCallback? onTap;

  /// Side of the square corner the ribbon is drawn inside. Big enough to
  /// contain the band at [_fromCorner] with room to clip both ends.
  static const double _side = 132;

  /// Band thickness.
  ///
  /// Nearly three times Flutter's BannerPainter, and the reason is the touch
  /// target rather than legibility. The reachable part of a corner band is the
  /// part below the status-bar inset, and a band's width there falls off as you
  /// move toward the corner — at the 17pt this started at, a 47pt inset left a
  /// sliver. Thickening it widens that whole triangle.
  static const double _band = 32;

  /// Perpendicular distance from the screen corner to the band's centre line.
  ///
  /// The number the geometry lives or dies on, and it is only checkable by
  /// rendering. Flutter's own banner uses ~28 here; this is a little further
  /// out because the band is thicker, and the two have to be moved together:
  ///
  ///  * Too small and the band straddles the corner, painting half of itself
  ///    off-screen.
  ///  * Too large — the 64 this briefly had — and it stops being a corner cut.
  ///    The corner itself goes empty, the band slides down and left into the
  ///    middle of the screen, and it reads as a stripe someone left lying
  ///    across the UI. It also stopped overlapping the status glyphs at all,
  ///    which is the one thing this shape is for.
  static const double _fromCorner = 40;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Corner is local (_side, 0); its inward bisector is (-1, 1)/√2. Put the
    // band's centre [_fromCorner] along that, then lay the band ACROSS it —
    // perpendicular to the bisector, which is the "\" direction, i.e. a
    // clockwise quarter-turn. Getting that sign wrong points the band along the
    // bisector instead of across it, and the ribbon slides off the corner
    // entirely with one end squared off mid-screen.
    const inset = _fromCorner / math.sqrt2;
    const cx = _side - inset;
    const cy = inset;
    // Longer than the corner's hypotenuse so both ends are cut by the clip
    // rather than stopping short of an edge.
    const length = _side * 1.8;
    return SizedBox(
      width: _side,
      height: _side,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: cx - length / 2,
              top: cy - _band / 2,
              width: length,
              height: _band,
              child: Transform.rotate(
                angle: math.pi / 4,
                // INSIDE the rotation, so the hit area is the band and not the
                // square it lives in. The extreme corner — where a close button
                // would be — has no band under it and passes pointers through.
                // `Transform` maps hit tests through its matrix, so this works
                // without any manual hit-test maths.
                child: GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: Semantics(
                    container: true,
                    button: onTap != null,
                    label: semanticLabel,
                    excludeSemantics: true,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.ink,
                        boxShadow: [
                          BoxShadow(
                            color: theme.background.withValues(alpha: 0.45),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: theme.monoTiny.copyWith(
                          color: _Palette.onInk,
                          letterSpacing: 1.2,
                          fontSize: 9,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Open the explanation for whichever server this install is on.
///
/// Routed through the ROOT navigator because the mark can live above it, in
/// `MaterialApp.builder`, where `Navigator.of(context)` finds nothing.
void showServerRoleSheet(BuildContext context) {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  showServerRoleInfo(nav.context);
}

/// Fit a hostname into a small space without losing the part that identifies
/// it.
///
/// Elides from the MIDDLE, keeping the leading label and the registrable tail —
/// `matrix.home.example.com` reads as `matrix…example.com`, not as
/// `matrix.home.exa…`, which would be indistinguishable from every other host
/// on that domain. Ports survive for the same reason: on a self-hosted box the
/// port is often the only thing separating two deployments.
///
/// Top-level and pure so it can be tested without a widget tree.
String shortHost(String host, {int max = 22}) {
  if (host.length <= max) return host;
  // Never cut inside the port or the last label.
  final tailStart = host.lastIndexOf('.', host.length - 1);
  final tail = tailStart <= 0
      ? host.substring(host.length - 8)
      : host.substring(host.lastIndexOf('.', tailStart - 1) + 1);
  if (tail.length >= max) return '…${tail.substring(tail.length - max + 1)}';
  final headRoom = max - tail.length - 1;
  return '${host.substring(0, headRoom)}…$tail';
}
