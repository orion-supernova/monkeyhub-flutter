import 'package:flutter/material.dart';

import '../backend/server_directory.dart';
import '../backend/server_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../main.dart' show rootNavigatorKey;
import '../theme/theme_scope.dart';
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
/// routes put their close button — and it is the reason there is no longer a
/// choice of shape here: an option that collides with the app is not a taste
/// someone should have to hold.
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
  const SelfHostBar({super.key, this.onTap});

  /// Overrides what a tap opens. Test seam; production opens the info sheet.
  final VoidCallback? onTap;

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
  static bool get consumesTopInset => ServerStore.instance.announcesRole;

  @override
  Widget build(BuildContext context) {
    if (!consumesTopInset) return const SizedBox.shrink();
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
                    labels.label,
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
