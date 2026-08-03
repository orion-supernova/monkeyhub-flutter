import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';

/// "This account has no recovery phrase" — shown until it has one.
///
/// One widget with two hosts (settings and profile) so the copy and the
/// severity cannot drift apart between them.
///
/// Styled on the "limited view" pill in profile_screen.dart, but in
/// [AppTheme.danger] rather than accent: an account with no recovery phrase is
/// one forgotten password away from being gone for good, which is not an
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
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: 'Set up a recovery phrase',
      radius: theme.radiusMd,
      // Never an InkWell — this app draws no ink anywhere.
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: theme.surfaceSunken,
            border: Border(left: BorderSide(color: theme.danger, width: 2)),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Row(
            children: [
              Icon(Icons.key_off_outlined, size: 14, color: theme.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'no recovery phrase — you could not get back in.',
                  style: theme.monoTiny.copyWith(color: theme.danger),
                ),
              ),
              Icon(Icons.chevron_right, size: 14, color: theme.danger),
            ],
          ),
        ),
      ),
    );
  }
}
