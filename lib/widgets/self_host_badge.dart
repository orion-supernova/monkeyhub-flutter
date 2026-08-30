import 'package:flutter/material.dart';

import '../backend/server_directory.dart';
import '../backend/server_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show rootNavigatorKey;
import 'server_role_sheet.dart';

/// The palette the bar paints in, chosen per [ServerRole].
///
/// Deliberately NOT `theme.accent`. The accent is what every ordinary control
/// in the app is drawn in, so a marker wearing it reads as one more piece of
/// chrome — the opposite of something whose entire job is to look like it does
/// not belong. Fixed hex rather than theme tokens for the same reason: this
/// must look identical, and equally out of place, under all fourteen themes.
class _Palette {
  const _Palette({required this.ink, required this.fill, required this.border});

  /// Text and dot.
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
}

/// What the bar says, given where the app is pointed.
///
/// Its own function because getting it wrong leaks a deployment URL. The
/// operator's addresses are infrastructure; only a server the user typed in
/// themselves is theirs to see. See [ServerStore.isSelfHosted].
({String label, String semantics}) serverMarkLabels(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final store = ServerStore.instance;
  if (store.role == ServerRole.homeserver) {
    return (
      label: l10n.serverBadgeHomeserver,
      semantics: l10n.serverBadgeHomeserverSemantics,
    );
  }
  return (
    label: shortHost(store.host, max: 28),
    semantics: l10n.serverBadgeSelfHostedSemantics(store.host),
  );
}

/// A corner ribbon marking which server this install is pointed at, in the
/// shape of Flutter's own debug banner.
///
/// ───────── why a ribbon, and not the bar this replaces ─────────
///
/// The first version was a strip across the top that took its own height out
/// of the layout, so the app began 26pt plus a status inset lower than the
/// screen. That is a fine trade for a chat list. It is the wrong trade for
/// every screen whose whole design is that the content IS the screen: the
/// photo send-preview fits the picture with `contain`, so taking 73pt off the
/// viewport meant a SCREENSHOT — a picture whose only claim on the screen is
/// being exactly its shape — no longer fit, and was scaled down until it left
/// a 17pt gutter down both sides. Every fullscreen viewer in the app paid the
/// same 73pt.
///
/// A ribbon takes no height at all. It is painted over the top-right corner as
/// a foreground layer, so nothing below it moves and the geometry of every
/// screen is exactly what it was before any of this existed.
///
/// ───────── what it gives up ─────────
///
/// Room for a sentence, and the tap. The bar could carry "Serving from
/// homeserver" in twelve languages and open an explanation; a ribbon fits
/// about thirteen characters and, being a foreground painter, is not
/// hit-testable — taps fall through to whatever is under it, which is the
/// right behaviour for chrome that sits over a close button.
///
/// Both moved to the Server screen, which already names the role and the host
/// and is where somebody asking "which server am I on?" goes. See
/// [showServerRoleInfo].
class ServerMarkBanner extends StatelessWidget {
  const ServerMarkBanner({super.key, required this.child});

  final Widget child;

  /// Whether a ribbon is being drawn right now.
  ///
  /// Nothing reads this to change its own layout any more — that was the old
  /// bar's contract, and the reason it existed. Kept because the Server screen
  /// and Settings both ask the same question to decide whether to highlight
  /// the row.
  static bool get isShowing => ServerStore.instance.announcesRole;

  @override
  Widget build(BuildContext context) {
    // Listens for itself rather than trusting the parent to rebuild it — the
    // app mounts this high up, where rebuilds are rare, and a server change
    // has to reach the ribbon on the same frame it reaches everything else.
    return AnimatedBuilder(
      animation: ServerStore.instance,
      builder: (context, _) {
        if (!isShowing) return child;
        final store = ServerStore.instance;
        final palette = _Palette.of(store.role);
        final l10n = AppLocalizations.of(context);
        // Flutter's own banner, in its own place, wrapping the app exactly as
        // the debug banner does — no offset, no wrapper box. Colour and label
        // are the only things this supplies.
        return Banner(
          message: store.role == ServerRole.homeserver
              ? l10n.serverBadgeRibbonHomeserver
              : l10n.serverBadgeRibbonSelfHosted,
          location: BannerLocation.topEnd,
          color: palette.fill,
          textStyle: TextStyle(
            color: palette.ink,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            height: 1.0,
          ),
          child: child,
        );
      },
    );
  }
}

/// Open the explanation for whichever server this install is on.
///
/// Routed through the ROOT navigator because the bar sits above it, in
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
