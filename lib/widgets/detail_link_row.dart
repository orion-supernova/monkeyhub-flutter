import 'package:flutter/material.dart';

import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import 'count_badge.dart';

/// A tappable row that leads somewhere: leading icon, label, optional state on
/// the right, optional count, chevron.
///
/// Lives here rather than privately inside a screen because Profile and
/// Settings both stack these, and the thing that used to differ between the two
/// copies is the one thing a row like this has to get right — where the chevron
/// lands. See the note on the [Expanded] in [build]: a chevron that stops short
/// of the padding by a different amount on every row is instantly legible as
/// wrong even to someone who could not say why, and it was wrong on every
/// Profile row that carried a value.
class DetailLinkRow extends StatelessWidget {
  const DetailLinkRow({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.value,
    this.badge = 0,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  /// Current state, right-aligned. Null or empty leaves the row a plain link —
  /// which is what an action like SET UP RECOVERY PHRASE wants, since its label
  /// already says everything there is to say.
  final String? value;

  /// Count shown as an accent pill before the chevron. Zero hides it.
  final int badge;

  /// Overrides the leading icon's colour to call attention to the row.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final v = value;
    // Bare GestureDetector, never InkWell — this app renders no ink anywhere.
    // FocusableTap adds the cursor, the Tab stop and the hover fill.
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      hover: HoverEffect.tint,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border.all(color: theme.divider),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: iconColor ?? theme.inkSoft),
              const SizedBox(width: 12),
              // Exactly ONE tight flex child at this level, and it is this one.
              //
              // The label used to be a loose `Flexible` sitting next to a
              // `Spacer`, or next to the value's own `Expanded`. Two flex children
              // split the free width 1:1 regardless of what either needs, and a
              // loose child that uses less than its half does not hand the slack
              // to its neighbour — `Row` hands it to `mainAxisAlignment`, which
              // defaults to `start` and parks all of it AFTER the last child. So
              // the chevron, and the value beside it, floated short of the right
              // padding by however much the label happened not to use: 54pt and
              // 78pt respectively on a 360pt row reading FAMILY / add a child.
              //
              // A single `Expanded` cannot under-use its allocation, so there is
              // no slack left for the chevron to drift into.
              Expanded(
                child: v == null || v.isEmpty
                    ? Text(label, style: theme.label)
                    // `spaceBetween` spends the slack on the gap between label and
                    // value rather than behind them both, which pins the value to
                    // the right. The SizedBox is the floor on that gap, not the
                    // whole of it.
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(label, style: theme.label)),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              v,
                              style: theme.body.copyWith(color: theme.inkSoft),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 8),
                CountBadge(count: badge),
              ],
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
