import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../privacy/app_only.dart';
import '../theme/theme_scope.dart';
import '../theme/vanish_palette.dart';

/// A vanishing message where screenshots cannot be blocked (web, Linux): the
/// view-once seal instead of the words, with the same way out ("Opens in the
/// app"). One bubble at a time, so older ordinary messages in the same room
/// still read fine. It never counts as seen, so a browser tab cannot start
/// anyone's 10 second clock.
class VanishSealedBubble extends StatelessWidget {
  const VanishSealedBubble({super.key, this.onTap});

  /// Defaults to the "Opens in the app" sheet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final violet = VanishPalette(theme).vanish;
    return FocusableTap(
      onTap: onTap ?? () => AppOnly.explainVanish(context),
      semanticLabel: l10n.vanishSealedSemantics,
      radius: theme.radiusLg,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => (onTap ?? () => AppOnly.explainVanish(context))(),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: violet.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(theme.radiusLg),
          border: Border.all(color: violet.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.lock_fill, size: 15, color: violet),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                l10n.appOnlyViewOnceTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.body.copyWith(color: theme.ink, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
