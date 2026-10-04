import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../models/app_release.dart';
import '../theme/theme_scope.dart';
import '../update/release_channel.dart';
import '../update/update_destination.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart'
    show groupedFooterStyle, groupedMetaStyle, groupedSubtitleStyle;
import 'meta_text.dart';
import 'sheet_kit.dart' show SheetActionButton, SheetFrame, SheetRise;

/// "A newer version is out" — the title in the bar, the × as "later", and one
/// Update button.
///
/// Built on the shared sheet furniture ([SheetFrame], [SheetActionButton]) so
/// it can't drift from the rest of the sheet family. The × replaced a "Later"
/// text button: the two said the same thing, and every other optional prompt
/// has only the ×. The primary button autofocuses, because unlike a delete
/// confirmation the loud option is the safe one.
///
/// When [mandatory], the × and the handle are gone and the sheet can't be
/// dismissed by tapping outside, dragging it down, Android back, or Esc — the
/// running build is below the channel's `minSupported` and can't be trusted
/// to keep working.
Future<void> showUpdateSheet(
  BuildContext context, {
  required AppRelease release,
  required ReleaseChannel channel,
  required String currentVersion,
  required bool mandatory,
}) {
  return showAdaptiveSheet<void>(
    context,
    useRootNavigator: true,
    isDismissible: !mandatory,
    enableDrag: !mandatory,
    builder: (_) => _UpdateSheet(
      release: release,
      channel: channel,
      currentVersion: currentVersion,
      mandatory: mandatory,
    ),
  );
}

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet({
    required this.release,
    required this.channel,
    required this.currentVersion,
    required this.mandatory,
  });

  final AppRelease release;
  final ReleaseChannel channel;
  final String currentVersion;
  final bool mandatory;

  /// What the update button actually does, in the user's terms — the button is
  /// only honest if it names where it's about to send them.
  String _actionSub(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (channel) {
      case ReleaseChannel.iosTestflight:
      case ReleaseChannel.macosTestflight:
        return l10n.reportSheetUpdateActionOpensTestflight;
      case ReleaseChannel.iosAppstore:
      case ReleaseChannel.macosAppstore:
        return l10n.reportSheetUpdateActionOpensAppStore;
      case ReleaseChannel.androidPlay:
        return l10n.reportSheetUpdateActionOpensGooglePlay;
      case ReleaseChannel.androidApk:
      case ReleaseChannel.macosDmg:
      case ReleaseChannel.windows:
      case ReleaseChannel.linux:
        return l10n.reportSheetUpdateActionOpensDownloadPage;
      case ReleaseChannel.web:
        return l10n.reportSheetUpdateActionReloads;
      case ReleaseChannel.unknown:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final notes = release.notes?.trim();
    final sub = _actionSub(context);

    return PopScope(
      // Blocks Android back and desktop Esc for a mandatory update. The
      // tap-outside and drag routes are closed by showAdaptiveSheet's
      // isDismissible/enableDrag.
      canPop: !mandatory,
      child: SheetFrame(
        title: mandatory
            ? l10n.reportSheetUpdateRequiredTitle
            : l10n.reportSheetUpdateAvailableTitle,
        // An optional update is an optional prompt: the × is the "later".
        // A mandatory one has no way out — no ×, and nothing to drag away.
        showClose: !mandatory,
        handle: !mandatory,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The App Store's update card: the app's own icon tile as the
            // hero, a line of why, and the version change in a quiet capsule.
            Center(
              child: SheetRise(
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(
                          mandatory ? theme.danger : theme.accent,
                          Colors.white,
                          0.16,
                        )!,
                        mandatory ? theme.danger : theme.accent,
                      ],
                    ),
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_down_to_line,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              mandatory
                  ? l10n.reportSheetUpdateMandatoryBody
                  : l10n.reportSheetUpdateAvailableBody,
              textAlign: TextAlign.center,
              style: groupedFooterStyle(theme),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: theme.ink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.reportSheetUpdateVersionArrow(
                    currentVersion,
                    release.version,
                  ),
                  style: metaText(theme, color: theme.inkSoft),
                ),
              ),
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              // Centred with everything else on the card.
              Text(
                notes,
                textAlign: TextAlign.center,
                style: groupedSubtitleStyle(theme).copyWith(
                  color: theme.inkSoft,
                ),
              ),
            ],
            const SizedBox(height: 22),
            SheetActionButton(
              label: l10n.reportSheetUpdateButtonTitle,
              icon: CupertinoIcons.arrow_down_circle_fill,
              destructive: mandatory,
              // The loud option here is the safe one, so Enter on a
              // freshly-opened sheet updates — the inverse of a delete
              // confirmation.
              autofocus: true,
              onTap: () {
                // Close first on an optional update so the user isn't left
                // staring at the sheet behind the store. A mandatory one stays
                // up: if they back out of the store without updating, the
                // prompt is still there.
                if (!mandatory) Navigator.of(context).pop();
                openUpdateDestination(
                  channel,
                  release.updateUrl,
                  version: release.version,
                );
              },
            ),
            // Where the button is about to send them — the button is only
            // honest if it says so.
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: groupedMetaStyle(theme),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
