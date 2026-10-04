import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import 'ios_kit.dart';

/// "This account has no recovery phrase" — shown until it has one.
///
/// One widget with two hosts (settings and profile) so the copy and the
/// severity cannot drift apart between them.
///
/// Red ([TileTone.red]) rather than accent: an account with no recovery phrase
/// is one forgotten password away from being gone for good, which is not an
/// informational state.
///
/// Callers are responsible for only rendering this when
/// `ChatUser.hasRecoveryKey == false` — explicitly false, never null, since
/// null means "unknown" — and never for a child account.
class RecoveryPhraseBanner extends StatelessWidget {
  const RecoveryPhraseBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A warning row the way Settings draws one: a red tile, the sentence, a
    // chevron — a grouped block of one. It was a sunken card with a 2pt red
    // stripe down the left and monospace copy, which read as a terminal
    // alert rather than part of the page around it.
    return Semantics(
      container: true,
      label: l10n.linkOpenerRecoveryBannerSemanticLabel,
      child: GroupedSection(
        margin: EdgeInsets.zero,
        children: [
          GroupedRow(
            icon: CupertinoIcons.exclamationmark_shield_fill,
            tone: TileTone.red,
            title: l10n.linkOpenerRecoveryBannerMessage,
            chevron: true,
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}
