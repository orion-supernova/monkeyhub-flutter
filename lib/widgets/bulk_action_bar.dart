import 'package:flutter/cupertino.dart';

import 'spring_press.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'liquid_glass.dart';
import '../l10n/text_case.dart';

/// One icon-over-label button in a bulk action bar.
///
/// Public because two bars use it: the shared-content browser's
/// [RoomContentActionBar] and the transcript's [TranscriptSelectionBar]. They
/// act on the same selection concept from different screens, and a user who
/// learns DELETE in the gallery should meet the same button in the chat.
class BulkActionButton extends StatelessWidget {
  const BulkActionButton({
    super.key,
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.enabled = true,
  });

  final AppTheme theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  /// Dimmed and inert rather than absent. A FORWARD button that disappears
  /// when the eleventh message is picked reads as a bug; one that is visibly
  /// unavailable is a rule the user can see.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final base = destructive ? theme.danger : theme.ink;
    final ink = enabled ? base : base.withValues(alpha: 0.35);
    final body = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: ink),
          const SizedBox(height: 5),
          Builder(
            builder: (context) => Text(
              sentenceCaseOf(context, label),
              style: theme.bodySoft.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
    if (!enabled) return body;
    // THE press: a spring under the finger, its own focus stop for a keyboard.
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      child: body,
    );
  }
}

/// The transcript's multi-select bar, shown in place of the composer.
///
/// In place of, not above: while a selection is live there is nothing to type,
/// and both chat styles already reserve exactly the composer's height at the
/// bottom of the list. Swapping the two keeps that reservation honest without
/// either style having to re-measure anything.
class TranscriptSelectionBar extends StatelessWidget {
  const TranscriptSelectionBar({
    super.key,
    required this.count,
    required this.onCancel,
    required this.onForward,
    required this.onDelete,
    required this.canForward,
    required this.canDelete,
  });

  /// How many messages are picked, resolved against what is actually on
  /// screen — never a raw id count. See `RoomContentSelection.resolve`.
  final int count;
  final VoidCallback onCancel;
  final VoidCallback onForward;
  final VoidCallback onDelete;

  /// False when the selection is over the server's per-call cap, or holds
  /// something that cannot travel (a view-once message, a system notice).
  final bool canForward;

  /// False when the selection holds someone else's message and the viewer
  /// isn't the room owner — the server would refuse exactly those.
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomSafe),
      // A floating glass capsule — the iOS 26 toolbar — in place of the
      // composer, which is glass too, so swapping one for the other never
      // changes the material at the bottom of the screen.
      child: LiquidGlass(
        shape: LiquidGlassShape.capsule,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            BulkActionButton(
              theme: theme,
              icon: CupertinoIcons.xmark,
              label: l10n.bulkActionBarCancelLabel,
              onTap: onCancel,
            ),
            Expanded(
              child: Center(
                child: Text(
                  sentenceCaseOf(
                    context,
                    count == 0
                        ? l10n.bulkActionBarSelectMessagesLabel
                        : l10n.bulkActionBarSelectedCountLabel(count),
                  ),
                  style: theme.bodyEmph.copyWith(
                    fontSize: 15,
                    color: count == 0 ? theme.inkMuted : theme.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            BulkActionButton(
              theme: theme,
              icon: CupertinoIcons.arrowshape_turn_up_right,
              label: l10n.bulkActionBarForwardLabel,
              enabled: canForward && count > 0,
              onTap: onForward,
            ),
            BulkActionButton(
              theme: theme,
              icon: CupertinoIcons.trash,
              label: l10n.bulkActionBarDeleteLabel,
              destructive: true,
              enabled: canDelete && count > 0,
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
