import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../backend/server_directory.dart';
import '../backend/server_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'sheet_kit.dart';

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
    final tone = homeserver ? TileTone.indigo : TileTone.teal;
    // The name in the bar like every sheet; the big tile stays in the body
    // as the hero, with the address and the explanation under it.
    return SheetFrame(
      title: homeserver
          ? l10n.serverRoleHomeserverTitle
          : l10n.serverRoleSelfHostedTitle,
      // Scrolls rather than overflows. Not defensive padding — the first render
      // of this sheet overflowed by 20px at a plain 390x620, and the two things
      // that make it taller are exactly the two nobody controls from here: the
      // reader's text-scale setting, and however long a note the operator chose
      // to publish.
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // An info card in the App Store shape: the subject as a large
            // tile.
            Center(
              child: Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tileColor(theme, tone),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  homeserver
                      ? CupertinoIcons.house_fill
                      : CupertinoIcons.cloud_fill,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
            // The address, for the one server whose address is the user's.
            //
            // It is the fact underneath every sentence here and the only one
            // that lets someone check for themselves — but on the home server
            // it is not their fact to check. That address is the operator's
            // infrastructure, and specifically the name of a machine on
            // somebody's domestic line; printing it in a sheet every user can
            // open makes a residential endpoint trivially harvestable, and buys
            // the reader nothing they can act on. Every other surface already
            // withholds it (see [serverMarkLabels]); this sheet was the one
            // place still publishing it.
            if (!homeserver && store.host.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                store.host,
                style: groupedSubtitleStyle(theme),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              homeserver
                  ? l10n.serverRoleHomeserverBody
                  : l10n.serverRoleSelfHostedBody,
              style: theme.body.copyWith(color: theme.inkSoft),
              textAlign: TextAlign.center,
            ),
            if (note != null) ...[
              const SizedBox(height: 16),
              // The operator's note on a neutral plate — a quotation, not an
              // alert, so no accent rule.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: sheetGroupFill(theme),
                  borderRadius: BorderRadius.circular(groupedRadius(theme)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.quote_bubble_fill,
                      size: 18,
                      color: theme.inkMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        note,
                        style: theme.body.copyWith(color: theme.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (homeserver) ...[
              const SizedBox(height: 18),
              SheetGroup(
                children: [
                  _Point(
                    icon: CupertinoIcons.clock_fill,
                    tone: TileTone.orange,
                    text: l10n.serverRoleHomeserverWarnData,
                  ),
                  _Point(
                    icon: CupertinoIcons.speedometer,
                    tone: TileTone.blue,
                    text: l10n.serverRoleHomeserverWarnSpeed,
                  ),
                  _Point(
                    icon: CupertinoIcons.arrow_2_circlepath,
                    tone: TileTone.green,
                    text: l10n.serverRoleHomeserverWarnAuto,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// One fact about the server: a coloured tile and a sentence, a row of the
/// grouped block.
class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.tone, required this.text});
  final IconData icon;
  final TileTone tone;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tileColor(theme, tone),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                text,
                style: groupedSubtitleStyle(theme).copyWith(
                  color: theme.inkSoft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
