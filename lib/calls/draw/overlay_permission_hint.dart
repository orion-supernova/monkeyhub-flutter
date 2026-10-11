import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/glass_buttons.dart';
import '../../widgets/liquid_glass.dart' show GlassTone;
import 'draw_mirror.dart';

/// Under the presenter's "you are sharing" placeholder on Android, while the
/// app may not yet display over other apps: one line saying what that
/// access buys, and the button that grants it.
///
/// Asked here and nowhere else. This is the screen the presenter is on the
/// moment a share starts, before they leave the app — the last place the
/// question can still be answered in time — and it asks nothing until a
/// share is actually running. Gone the moment the access is granted (the
/// mirror re-reads it on the way back from Settings) and absent on every
/// other platform, where [DrawMirror.overlayAllowed] stays null.
class OverlayPermissionHint extends StatelessWidget {
  const OverlayPermissionHint({super.key, required this.mirror});

  final DrawMirror mirror;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: mirror.overlayAllowed,
      builder: (context, allowed, _) {
        if (allowed != false) return const SizedBox.shrink();
        final l10n = AppLocalizations.of(context);
        final theme = ThemeScope.of(context);
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.screenShareOverlayHint,
                  style: theme.caption.copyWith(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                GlassPillButton(
                  tone: GlassTone.media,
                  icon: CupertinoIcons.pencil_outline,
                  label: l10n.screenShareOverlayAllow,
                  onTap: mirror.requestOverlay,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
