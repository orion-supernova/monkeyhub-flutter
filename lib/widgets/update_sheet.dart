import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/app_release.dart';
import '../theme/theme_scope.dart';
import '../update/release_channel.dart';
import '../update/update_destination.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show ChoiceTile;
import 'meta_text.dart';
import 'sheet_kit.dart'
    show SheetHandle, SheetRise, sheetFill, sheetTopRadius;
import '../l10n/text_case.dart';

/// "A newer version is out" — LATER and UPDATE.
///
/// Deliberately built on the same furniture as the destructive sheets
/// (`SheetGrabber`, `ChoiceTile`, the plain text secondary action) so it can't
/// drift visually from the rest of the sheet family. The one inversion: here the
/// *primary* tile autofocuses, because unlike a delete confirmation the loud
/// option is the safe one.
///
/// When [mandatory], LATER is gone and the sheet can't be dismissed by tapping
/// outside, dragging it down, Android back, or Esc — the running build is below
/// the channel's `minSupported` and can't be trusted to keep working.
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
    final notes = release.notes?.trim();

    return PopScope(
      // Blocks Android back and desktop Esc for a mandatory update. The
      // tap-outside and drag routes are closed by showAdaptiveSheet's
      // isDismissible/enableDrag.
      canPop: !mandatory,
      child: Container(
        decoration: BoxDecoration(
          color: sheetFill(theme),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(sheetTopRadius(theme)),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Nothing to drag away when the update is mandatory, so don't
            // suggest otherwise.
            if (!mandatory)
              const SheetHandle()
            else
              const SizedBox(height: 14),
            const SizedBox(height: 8),
            // The App Store's update card: the app's own icon tile, a
            // centred title, a line of why, and the version change in a
            // quiet capsule.
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
              sentenceCaseOf(
                context,
                mandatory
                    ? AppLocalizations.of(context).reportSheetUpdateRequiredTitle
                    : AppLocalizations.of(
                        context,
                      ).reportSheetUpdateAvailableTitle,
              ),
              textAlign: TextAlign.center,
              style: theme.bodyEmph.copyWith(fontSize: 20, color: theme.ink),
            ),
            const SizedBox(height: 6),
            Text(
              mandatory
                  ? AppLocalizations.of(context).reportSheetUpdateMandatoryBody
                  : AppLocalizations.of(context).reportSheetUpdateAvailableBody,
              textAlign: TextAlign.center,
              style: theme.bodySoft.copyWith(color: theme.inkMuted),
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
                  AppLocalizations.of(context).reportSheetUpdateVersionArrow(
                    currentVersion,
                    release.version,
                  ),
                  style: metaText(theme, color: theme.inkSoft),
                ),
              ),
            ),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(notes, style: theme.bodySoft),
            ],
            const SizedBox(height: 20),
            ChoiceTile(
              color: theme.accent,
              icon: CupertinoIcons.arrow_down_circle_fill,
              title: AppLocalizations.of(context).reportSheetUpdateButtonTitle,
              sub: _actionSub(context),
              filled: true,
              // Inverted from the destructive sheets: the loud option here is
              // the safe one, so Enter on a freshly-opened sheet updates.
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
            if (!mandatory) ...[
              const SizedBox(height: 10),
              FocusableTap(
                onTap: () => Navigator.of(context).pop(),
                semanticLabel: AppLocalizations.of(
                  context,
                ).reportSheetUpdateLaterSemanticLabel,
                radius: theme.radiusMd,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    alignment: Alignment.center,
                    child: Text(
                      sentenceCaseOf(
                        context,
                        AppLocalizations.of(context).reportSheetUpdateLaterButton,
                      ),
                      style: theme.body.copyWith(
                        fontSize: 17,
                        color: theme.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
