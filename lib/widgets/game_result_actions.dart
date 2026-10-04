import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'action_buttons.dart';

/// One action under a finished game's result card — Copy result, Tell
/// friends. Shared by every daily game and the code puzzle, which each used
/// to carry a private copy.
class GameResultAction {
  const GameResultAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final String label;

  /// Null shows the action as done rather than hiding it.
  final VoidCallback? onTap;

  /// The filled one — the action the card is offering first.
  final bool prominent;
}

/// The result card's actions: side by side when every label fits on one
/// line at half width, otherwise stacked full width.
///
/// Never truncated. Two capsules sharing a row leave ~150pt per label, and
/// "Sonucu kopyala" / "Arkadaşlara söyle" ended in an ellipsis on a phone —
/// a button whose name you cannot read. Measuring first and stacking when
/// needed keeps every language whole without shrinking the type.
class GameResultActions extends StatelessWidget {
  const GameResultActions({super.key, required this.actions});

  final List<GameResultAction> actions;

  static const _gap = 10.0;

  // The button's own numbers — measured against, so "fits" means fits in the
  // capsule [SheetActionButton] will actually draw.
  static TextStyle _style(AppTheme theme) => actionButtonLabelStyle(theme);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final n = actions.length;
        final each = (constraints.maxWidth - _gap * (n - 1)) / n;
        final room = each -
            kActionButtonHPad * 2 -
            kActionButtonIcon -
            kActionButtonIconGap;
        final fits = actions.every((a) {
          final painter = TextPainter(
            text: TextSpan(text: a.label, style: _style(theme)),
            textDirection: dir,
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = painter.width;
          painter.dispose();
          return w <= room;
        });
        final buttons = [for (final a in actions) _Button(action: a)];
        if (fits) {
          return Row(
            children: [
              for (var i = 0; i < n; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: buttons[i]),
              ],
            ],
          );
        }
        // Stacked, the prominent action leads: it is the one the card is
        // offering first.
        final ordered = [
          for (final b in buttons) if (b.action.prominent) b,
          for (final b in buttons) if (!b.action.prominent) b,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < ordered.length; i++) ...[
              if (i > 0) const SizedBox(height: _gap),
              ordered[i],
            ],
          ],
        );
      },
    );
  }
}

/// One action, drawn as THE button: the accent capsule when [prominent],
/// tonal otherwise, disabled (done) when its tap is null.
class _Button extends StatelessWidget {
  const _Button({required this.action});
  final GameResultAction action;

  @override
  Widget build(BuildContext context) => SheetActionButton(
        label: action.label,
        icon: action.icon,
        onTap: action.onTap,
        tonal: !action.prominent,
      );
}
