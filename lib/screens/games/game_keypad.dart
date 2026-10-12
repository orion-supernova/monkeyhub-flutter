import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/ios_kit.dart';

/// The digits of a Latin-square board, and an eraser. Mini Sudoku's 1 to 6
/// and Futoshiki's 1 to 5 are the same control at a different length, so they
/// are one widget rather than two copies drifting apart.
///
/// A digit whose copies are all placed dims out. It stays tappable — the
/// player may well need to take one back — but a keypad that shows at a glance
/// which digits are spent removes the most tedious part of scanning a grid.
class GameKeypad extends StatelessWidget {
  const GameKeypad({
    super.key,
    required this.size,
    required this.remaining,
    required this.enabled,
    required this.onEnter,
    required this.keyPrefix,
  });

  final int size;
  final Map<int, int> remaining;
  final bool enabled;
  final void Function(int value) onEnter;

  /// Names each key `<prefix>_key_<digit>`, for tests that press them.
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        for (var v = 1; v <= size; v++)
          Expanded(
            child: Padding(
              key: ValueKey('${keyPrefix}_key_$v'),
              padding: const EdgeInsets.only(right: 6),
              child: _Key(
                enabled: enabled,
                spent: (remaining[v] ?? 0) <= 0,
                semanticLabel: '$v',
                onTap: () => onEnter(v),
                child: Text(
                  '$v',
                  style: theme.body.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: theme.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        SizedBox(
          width: 52,
          child: _Key(
            enabled: enabled,
            spent: false,
            semanticLabel: l10n.gameErase,
            onTap: () => onEnter(0),
            child: Icon(
              CupertinoIcons.delete_left,
              size: 20,
              color: theme.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.enabled,
    required this.spent,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final bool enabled;
  final bool spent;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // The iOS number-pad key: a filled, borderless tile that dips on a spring
    // under the thumb.
    return Opacity(
      opacity: !enabled
          ? 0.35
          : spent
          ? 0.45
          : 1,
      child: SpringPress(
        onTap: enabled ? onTap : null,
        semanticLabel: semanticLabel,
        scale: 0.9,
        haptic: false,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: theme.ink.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}
