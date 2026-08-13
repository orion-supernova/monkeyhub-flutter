import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../backend/server_directory.dart';
import '../backend/server_store.dart';
import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show rootNavigatorKey;
import '../theme/theme_scope.dart';
import 'server_role_sheet.dart';

/// The palette the badge paints in, chosen per [ServerRole].
///
/// Deliberately NOT `theme.accent`. The accent is what every ordinary control
/// in the app is drawn in, so a badge wearing it reads as one more piece of
/// chrome — the opposite of a marker whose entire job is to look like it does
/// not belong. Fixed hex rather than theme tokens for the same reason: this
/// must look identical, and equally out of place, under all fourteen themes.
class _BadgePalette {
  const _BadgePalette({required this.ink, required this.fill, this.border});

  /// Text, dot and the ribbon's own field.
  final Color ink;

  /// The chip's backing. Near-opaque, not a tint: the chip is drawn ON TOP of
  /// the status bar, and a translucent fill lets the OS clock, wifi and battery
  /// glyphs bleed through it into an unreadable smear. Opacity is what makes
  /// something drawn over system chrome legible.
  final Color fill;

  /// Chip outline, defaulting to [ink] at low alpha.
  final Color? border;

  Color get stroke => border ?? ink.withValues(alpha: 0.55);

  /// The operator has moved traffic to the home server. Warm amber — the one
  /// hue nothing else in this app uses, so it cannot be confused with chrome —
  /// and pointedly not `theme.danger`, which everywhere else means something
  /// has gone wrong. Being on the home server is a deliberate arrangement, not
  /// a fault.
  static const homeserver = _BadgePalette(
    ink: Color(0xFFE8A33D),
    fill: Color(0xF21C1509),
    border: Color(0xB3E8A33D),
  );

  /// Somebody's own backend. Not a warning at all — a statement of fact — so
  /// it gets a quiet graphite that reads as a label rather than an alarm.
  static const selfHosted = _BadgePalette(
    ink: Color(0xFF9AA3AE),
    fill: Color(0xF215181C),
    border: Color(0x8C9AA3AE),
  );

  /// Text colour on top of a solid [ink] field — the ribbon's label. Near-black
  /// rather than white: amber at this weight is far too light to carry white
  /// text at 8pt.
  static const onInk = Color(0xFF141414);
}

/// The permanent mark an install wears while it is not on the ordinary server.
///
/// ───────── why it is permanent, and why it is here ─────────
///
/// A device pointed somewhere unusual is otherwise indistinguishable from a
/// stock one. Every screen looks identical, every message sends normally, and
/// the only evidence lives four taps deep in Settings. That is a bad property
/// for the one setting that decides who holds your conversations — someone
/// handed a configured handset would never learn, and neither would anyone
/// wondering why the app is slow today.
///
/// So it borrows Flutter's own debug-banner position, and for the same reason
/// that banner exists: a mode you can forget you are in should not be
/// forgettable. It renders nothing at all on the primary deployment.
///
/// ───────── the three rules it obeys ─────────
///
///  * **It only takes taps on the shape it paints.** It floats above every
///    route, and the top-right corner is where close buttons, overflow menus
///    and call controls live. The gesture detector therefore sits INSIDE the
///    ribbon's rotation and inside the pill's own bounds, so the rest of the
///    corner passes pointers straight through — see the tests, which assert
///    exactly that.
///  * **The default shape paints over the status bar.** The app draws
///    edge-to-edge, so that strip belongs to it, and covering the corner of it
///    is the point rather than an accident. But no app can paint ABOVE the
///    system glyphs — they composite last — so the shape has to be one that
///    survives having a battery drawn on top of it. A diagonal band crosses
///    that row for a few points and reads fine; a horizontal chip runs the
///    whole length of it and reads as a smear, which is why [_Pill] sits below
///    the inset instead and why [_Ribbon] is the default.
///  * **It never draws a debug underline.** Overlay content sits outside any
///    route's Material, so its own [Material] + [DefaultTextStyle] are
///    load-bearing, not decoration.
///
/// Mounted once, in the app-wide Stack inside `MaterialApp.builder`, so it
/// survives every navigation and covers full-screen pushes (calls, the camera,
/// the media viewer) as well as the shell.
class SelfHostBadge extends StatelessWidget {
  const SelfHostBadge({super.key, this.style, this.onTap});

  /// Forces a style instead of reading the user's. Test seam only — writing the
  /// preference goes through secure storage, which no widget test can await,
  /// and rendering both shapes is the only way to check either one.
  final SelfHostBadgeStyle? style;

  /// Overrides what a tap opens. Test seam; production opens the info sheet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Both stores, because either one changing changes what this paints: the
    // server store flips it on, off and between roles; the settings store picks
    // the shape.
    return AnimatedBuilder(
      animation: Listenable.merge([
        ServerStore.instance,
        SettingsStore.instance,
      ]),
      builder: (context, _) {
        final store = ServerStore.instance;
        if (!store.announcesRole) return const SizedBox.shrink();
        final role = store.role;
        final theme = ThemeScope.of(context);
        final l10n = AppLocalizations.of(context);
        final shape = style ?? SettingsStore.instance.selfHostBadge;
        final homeserver = role == ServerRole.homeserver;
        final palette = homeserver
            ? _BadgePalette.homeserver
            : _BadgePalette.selfHosted;
        // The ribbon has room for one short token; the pill has room for the
        // address, which is the more useful fact when it is somebody's own box.
        final ribbonLabel = homeserver
            ? l10n.serverBadgeHomeserverShort
            : l10n.serverBadgeSelfHosted;
        final pillLabel = homeserver
            ? l10n.serverBadgeHomeserver
            : shortHost(store.host, max: 18);
        final semantics = homeserver
            ? l10n.serverBadgeHomeserverSemantics(store.host)
            : l10n.serverBadgeSelfHostedSemantics(store.host);
        void open() =>
            onTap == null ? showServerRoleSheet(context) : onTap!.call();
        return Positioned(
          top: 0,
          right: 0,
          child: Material(
            type: MaterialType.transparency,
            child: DefaultTextStyle(
              style: theme.monoTiny,
              child: switch (shape) {
                SelfHostBadgeStyle.ribbon => _Ribbon(
                  label: ribbonLabel,
                  semanticLabel: semantics,
                  palette: palette,
                  onTap: open,
                ),
                SelfHostBadgeStyle.pill => _Pill(
                  label: pillLabel,
                  semanticLabel: semantics,
                  palette: palette,
                  onTap: open,
                ),
              },
            ),
          ),
        );
      },
    );
  }
}

/// A scaled-down copy of the real badge, for the picker on the server screen.
///
/// Renders the SAME widgets the app draws, shrunk — never a hand-drawn
/// miniature. A separately-authored preview is one that can disagree with the
/// thing it previews, and that is not hypothetical here: the first version of
/// this file had the ribbon rotated one way and its miniature rotated the
/// other, so neither could flag the other and only a render caught it.
class SelfHostBadgePreview extends StatelessWidget {
  const SelfHostBadgePreview({
    super.key,
    required this.style,
    required this.label,
    this.homeserver = false,
  });

  final SelfHostBadgeStyle style;
  final String label;
  final bool homeserver;

  static const double width = 62;
  static const double height = 40;

  /// Enough that the corner reads at this size, and small enough that the 96pt
  /// ribbon fits inside a 62pt frame.
  static const double _scale = 0.44;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final palette = homeserver
        ? _BadgePalette.homeserver
        : _BadgePalette.selfHosted;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(
          color: theme.surfaceSunken,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Transform.scale(
                  scale: _scale,
                  alignment: Alignment.topRight,
                  child: switch (style) {
                    SelfHostBadgeStyle.ribbon => _Ribbon(
                      label: label,
                      semanticLabel: label,
                      palette: palette,
                      onTap: null,
                    ),
                    // insetTop 0: there is no status bar inside a 40pt frame,
                    // and the device's real one would push the chip out of it.
                    SelfHostBadgeStyle.pill => _Pill(
                      label: label,
                      semanticLabel: label,
                      palette: palette,
                      onTap: null,
                      insetTop: 0,
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A corner band, at Flutter's debug-banner angle and size.
class _Ribbon extends StatelessWidget {
  const _Ribbon({
    required this.label,
    required this.semanticLabel,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final _BadgePalette palette;
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
    // Longer than the corner's hypotenuse (_side·√2 ≈ 136) so both ends are cut
    // by the clip rather than stopping short of an edge.
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
                          color: _BadgePalette.onInk,
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

/// A chip in the status-bar strip.
///
/// Sits BELOW the top inset, and that is the whole difference between the two
/// shapes.
///
/// It was briefly centred inside the status-bar strip, to be as visible as
/// [_Ribbon]. That does not work and cannot be made to work: no app can paint
/// above the system status bar, so a horizontal chip in that strip runs the
/// full length of the signal, wifi and battery glyphs — and the dynamic island
/// — with all of them composited on top of it. The result is a smear, not a
/// badge. A diagonal band gets away with the same overlap because it only
/// crosses that row for a few points; a horizontal one does not.
///
/// So this shape trades reach for cleanliness: it says more, it collides with
/// nothing, and it is the right pick for anyone who finds the corner band
/// heavy. [_Ribbon] is the default because it is the one that survives being
/// drawn where the glyphs are.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.semanticLabel,
    required this.palette,
    required this.onTap,
    this.insetTop,
  });

  final String label;
  final String semanticLabel;
  final _BadgePalette palette;
  final VoidCallback? onTap;

  /// Overrides the status-bar inset. [SelfHostBadgePreview] passes 0 — the
  /// device's real inset would push the chip out of a 40pt frame.
  final double? insetTop;

  /// Hard ceiling on the chip's width.
  ///
  /// [shortHost] caps the CHARACTER count, which is not the same thing: a wide
  /// fallback face, a large text-scale setting, or a locale whose glyphs are
  /// wider all turn 18 characters into a chip running most of the way across
  /// the top of the screen. This is the guarantee the character cap cannot give.
  static const double _maxWidth = 170;

  /// Chip height, used to centre it in the status-bar strip.
  static const double _height = 22;

  /// Invisible, tappable margin under the chip.
  ///
  /// A 22pt chip is half the 44pt a finger wants. This buys the rest of it
  /// without making anything anybody can see any bigger.
  ///
  /// Transparent but opaque to pointers, which is what [HitTestBehavior.opaque]
  /// on the detector buys. Deliberately BELOW the chip and not around it: the
  /// space to its left is app content, and a badge that quietly ate a strip of
  /// it would be the very bug the corner rule exists to prevent.
  static const double _touchSkirt = 18;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final top = insetTop ?? MediaQuery.paddingOf(context).top;
    // CLEAR of the inset, not inside it. The badge sits above every route, so
    // no SafeArea in the tree applies to it and this is the only thing standing
    // between the chip and the dynamic island.
    final offset = top + 6;
    return Padding(
      padding: EdgeInsets.only(top: offset, right: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.only(bottom: onTap == null ? 0 : _touchSkirt),
          child: Semantics(
            container: true,
            button: onTap != null,
            label: semanticLabel,
            excludeSemantics: true,
            child: Container(
              height: _height,
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: palette.fill,
                border: Border.all(color: palette.stroke),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.ink,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.monoTiny.copyWith(
                        color: palette.ink,
                        fontSize: 9,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Open the explanation for whichever server this install is on.
///
/// Routed through the ROOT navigator because the badge lives above it, in
/// `MaterialApp.builder`, where `Navigator.of(context)` finds nothing.
void showServerRoleSheet(BuildContext context) {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  showServerRoleInfo(nav.context);
}

/// Fit a hostname into a chip without losing the part that identifies it.
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
