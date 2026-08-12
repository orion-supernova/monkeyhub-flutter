import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../backend/server_store.dart';
import '../data/settings_store.dart';
import '../theme/theme_scope.dart';

/// The permanent mark an install wears while it is pointed at a self-hosted
/// server.
///
/// ───────── why it is permanent, and why it is here ─────────
///
/// A repointed install is otherwise indistinguishable from a stock one. Every
/// screen looks identical, every message sends normally, and the only evidence
/// lives four taps deep in Settings. That is a bad property for the one setting
/// that decides who holds your conversations — someone handed a configured
/// handset would never learn, and a self-hoster debugging their own backend has
/// no way to confirm at a glance which box they are talking to.
///
/// So it borrows Flutter's own debug-banner position, and for the same reason
/// that banner exists: a mode you can forget you are in should not be
/// forgettable. It renders nothing at all on the bundled deployment.
///
/// ───────── the two rules it obeys ─────────
///
///  * **It never takes a tap.** Wrapped in [IgnorePointer], because it floats
///    above every route in the app and the top-right corner is where close
///    buttons, overflow menus and call controls live. A badge that swallowed one
///    of those would be a worse bug than the one it prevents.
///  * **It never draws a debug underline.** Overlay content sits outside any
///    route's Material, so its own [Material] + [DefaultTextStyle] are load
///    bearing, not decoration.
///
/// Mounted once, in the app-wide Stack inside `MaterialApp.builder`, so it
/// survives every navigation and covers full-screen pushes (calls, the camera,
/// the media viewer) as well as the shell.
class SelfHostBadge extends StatelessWidget {
  const SelfHostBadge({super.key, this.style});

  /// Forces a style instead of reading the user's. Test seam only — writing
  /// the preference goes through secure storage, which no widget test can
  /// await, and rendering both shapes is the only way to check either one.
  final SelfHostBadgeStyle? style;

  @override
  Widget build(BuildContext context) {
    // Both stores, because either one changing changes what this paints: the
    // server store flips it on and off, the settings store picks the shape.
    return AnimatedBuilder(
      animation: Listenable.merge([
        ServerStore.instance,
        SettingsStore.instance,
      ]),
      builder: (context, _) {
        final store = ServerStore.instance;
        if (!store.isCustom) return const SizedBox.shrink();
        final theme = ThemeScope.of(context);
        final shape = style ?? SettingsStore.instance.selfHostBadge;
        return Positioned(
          top: 0,
          right: 0,
          child: IgnorePointer(
            child: Material(
              type: MaterialType.transparency,
              child: DefaultTextStyle(
                style: theme.monoTiny,
                child: switch (shape) {
                  SelfHostBadgeStyle.ribbon => _Ribbon(host: store.host),
                  SelfHostBadgeStyle.pill => _Pill(host: store.host),
                },
              ),
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
    required this.host,
  });

  final SelfHostBadgeStyle style;
  final String host;

  static const double width = 62;
  static const double height = 40;

  /// Enough that the corner reads at this size, and small enough that the
  /// 96pt ribbon fits inside a 62pt frame.
  static const double _scale = 0.44;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
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
                    SelfHostBadgeStyle.ribbon => _Ribbon(host: host),
                    // insetTop 0: there is no status bar inside a 40pt frame,
                    // and the device's real one would push the chip out of it.
                    SelfHostBadgeStyle.pill => _Pill(host: host, insetTop: 0),
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
///
/// Carries the word rather than the host: at 45° across a 108pt hypotenuse
/// there is room for one short token, and "SELF-HOSTED" is the fact that
/// matters at a glance. The host name is one tap away in Settings, and the
/// [_Pill] style exists for anyone who wants it on screen permanently.
class _Ribbon extends StatelessWidget {
  const _Ribbon({required this.host});
  final String host;

  /// Side of the square corner the ribbon is drawn inside. Close enough to
  /// Flutter's own BannerPainter geometry that it reads as the same affordance
  /// rather than as a rogue widget.
  static const double _side = 96;

  /// Band thickness. Sized to the 8pt label plus its padding.
  static const double _band = 17;

  /// How far the band's centre line sits from the screen corner, measured
  /// along the corner's bisector.
  ///
  /// The number the geometry lives or dies on, and it is only checkable by
  /// rendering: at 0 the band straddles the corner and half of it paints
  /// off-screen; too large and it stops reaching both edges and reads as a
  /// stripe someone left lying across the UI rather than as a corner cut.
  static const double _fromCorner = _side * 0.5;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Corner is local (_side, 0); its inward bisector is (-1, 1)/√2. Put the
    // band's centre [_fromCorner] along that, then lay the band ACROSS it —
    // perpendicular to the bisector, which is the "\" direction, i.e. a
    // clockwise quarter-turn. Getting that sign wrong points the band along
    // the bisector instead of across it, and the ribbon slides off the corner
    // entirely with one end squared off mid-screen.
    const inset = _fromCorner / math.sqrt2;
    const cx = _side - inset;
    const cy = inset;
    // Longer than the corner's hypotenuse (_side·√2 ≈ 136) so both ends are
    // cut by the clip rather than stopping short of an edge.
    const length = _side * 1.8;
    return SizedBox(
      width: _side,
      height: _side,
      // The label is the accessible surface — the visual band is a rotated
      // strip a screen reader cannot make sense of. `container: true` stops the
      // child text being announced a second time.
      child: Semantics(
        container: true,
        label: 'Self-hosted server: $host',
        excludeSemantics: true,
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
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.accent,
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      'SELF-HOSTED',
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: theme.monoTiny.copyWith(
                        color: theme.accentInk,
                        letterSpacing: 1.1,
                        fontSize: 8,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip carrying the host, tucked under the status bar.
///
/// Translucent rather than solid: it sits over live content on every screen, so
/// it has to be legible without being opaque. The host is middle-truncated by
/// [_shortHost] rather than by an ellipsis, because the tail of a hostname is
/// the half that identifies it.
class _Pill extends StatelessWidget {
  const _Pill({required this.host, this.insetTop});
  final String host;

  /// Overrides the status-bar inset. Only [SelfHostBadgePreview] passes it —
  /// the device's real inset would push the chip out of a 40pt frame.
  final double? insetTop;

  /// Hard ceiling on the chip's width.
  ///
  /// [shortHost] caps the CHARACTER count, which is not the same thing: a
  /// wide fallback face, a large text-scale setting, or a locale whose digits
  /// are wider all turn 18 characters into a chip running most of the way
  /// across the top of the screen. This is the guarantee the character cap
  /// cannot give.
  static const double _maxWidth = 150;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Below the status bar and the notch, not underneath them. The badge lives
    // above every route, so no SafeArea in the tree applies to it.
    final top = insetTop ?? MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: top + 6, right: 10),
      child: Semantics(
        container: true,
        label: 'Self-hosted server: $host',
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          padding: const EdgeInsets.fromLTRB(8, 4, 9, 4),
          decoration: BoxDecoration(
            color: theme.accent.withValues(alpha: 0.16),
            border: Border.all(color: theme.accent.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  shortHost(host, max: 18),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.monoTiny.copyWith(
                    color: theme.accent,
                    fontSize: 9,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
