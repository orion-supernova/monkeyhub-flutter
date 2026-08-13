import 'package:flutter/material.dart';

import '../backend/server_directory.dart';
import '../backend/server_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;

/// What the badge opens: why this device is not on the ordinary server, and
/// what follows from that.
///
/// ───────── what it is for ─────────
///
/// The badge can only say four words. This is where the rest goes, and the
/// "rest" is not decoration — a person on the home server is running against a
/// machine that may be slower and that they will be moved off again, and both
/// of those change what they should expect from the app in the next hour. Left
/// unsaid, the honest reading of a slow app is "this app is broken".
///
/// ───────── the one thing it must not do ─────────
///
/// Reassure. The warnings are stated plainly, including the one that costs the
/// operator something to admit: **writes made here may not survive the move
/// back**. Anything softer would leave someone composing a long message on a
/// backend they have been told is temporary, with no idea that is a risk.
///
/// Read-only by design. It explains; it does not offer to move anybody. The
/// deployment in force is the operator's call
/// ([ServerDirectory]) — and for a self-hosted install, the server screen is
/// one row away in Settings and is the place that owns that decision.
Future<void> showServerRoleInfo(
  BuildContext context,
) => showAdaptiveSheet<void>(
  context,
  useRootNavigator: true,
  // Four sentences and three bullets is not a short sheet, and it grows with
  // the text-scale setting and with whatever note the operator published. Bound
  // it by the safe area rather than by the raw screen height — see the
  // parameter's own note on why a SafeArea inside the content would be a no-op.
  useSafeArea: true,
  builder: (_) => const _ServerRoleSheet(),
);

class _ServerRoleSheet extends StatelessWidget {
  const _ServerRoleSheet();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = ServerStore.instance;
    final homeserver = store.role == ServerRole.homeserver;
    // The operator's own words about why, when they published any. Shown
    // verbatim and first, because a specific reason beats every generic
    // sentence below it.
    final note = homeserver ? ServerDirectory.instance.last?.note : null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: theme.sheetDecoration(),
      // Scrolls rather than overflows. Not defensive padding — the first render
      // of this sheet overflowed by 20px at a plain 390x620, and the two things
      // that make it taller are exactly the two nobody controls from here: the
      // reader's text-scale setting, and however long a note the operator chose
      // to publish. `shrinkWrap` keeps a short sheet short.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetGrabber(),
            Row(
              children: [
                Icon(
                  homeserver ? Icons.home_work_outlined : Icons.dns_outlined,
                  size: 16,
                  color: theme.inkSoft,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    homeserver
                        ? l10n.serverRoleHomeserverTitle
                        : l10n.serverRoleSelfHostedTitle,
                    style: theme.displaySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // The address, always. It is the fact underneath every sentence in
            // this sheet, and the only one that lets someone check for themselves.
            Text(store.host, style: theme.mono.copyWith(color: theme.inkMuted)),
            const SizedBox(height: 16),
            Text(
              homeserver
                  ? l10n.serverRoleHomeserverBody
                  : l10n.serverRoleSelfHostedBody,
              style: theme.body.copyWith(color: theme.inkSoft),
            ),
            if (note != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.surfaceSunken,
                  border: Border(
                    left: BorderSide(color: theme.accent, width: 2),
                  ),
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Text(note, style: theme.body),
              ),
            ],
            if (homeserver) ...[
              const SizedBox(height: 18),
              _Point(
                icon: Icons.history_toggle_off,
                text: l10n.serverRoleHomeserverWarnData,
              ),
              const SizedBox(height: 12),
              _Point(
                icon: Icons.speed_outlined,
                text: l10n.serverRoleHomeserverWarnSpeed,
              ),
              const SizedBox(height: 12),
              _Point(
                icon: Icons.autorenew,
                text: l10n.serverRoleHomeserverWarnAuto,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One consequence, stated in a sentence. Icons carry no information a screen
/// reader needs — the sentence beside each is the whole content — so they are
/// excluded from semantics rather than given labels nobody wants read out.
class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: theme.inkMuted),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: theme.bodySoft)),
      ],
    );
  }
}
