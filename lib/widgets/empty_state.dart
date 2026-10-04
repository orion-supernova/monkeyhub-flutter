import 'package:flutter/widgets.dart';

import '../l10n/text_case.dart';
import '../theme/theme_scope.dart';
import 'action_buttons.dart';
import 'ios_kit.dart' show groupedFooterStyle;

/// THE empty screen or section — iOS's `ContentUnavailableView`: a big muted
/// glyph, a title, one or two sentences, and optionally the one thing to do
/// about it, all centred.
///
/// Nine private recipes preceded it (44/48/52pt glyphs, `displaySmall` or
/// header titles, left-aligned bodies, a seal in success green) and no two
/// screens agreed. Centre this in the space the content would have taken;
/// it carries its own padding and never stretches.
///
/// [compact] is for an empty block inside a scrolling page (a section with no
/// rows yet): a smaller glyph and less air.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.action,
    this.compact = false,
  });

  /// A Cupertino glyph. Optional — a one-line "No results" needs none.
  final IconData? icon;
  final String title;
  final String? message;

  /// The one thing to do about it: a tonal capsule hugging its label.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// A custom action instead of [actionLabel]/[onAction] (two buttons, say).
  /// Prefer the label pair.
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final act = action ??
        (actionLabel != null && onAction != null
            ? SheetActionButton(
                label: actionLabel!,
                onTap: onAction,
                tonal: true,
                expand: false,
                minHeight: 44,
              )
            : null);
    return Semantics(
      container: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 32,
          vertical: compact ? 20 : 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: compact ? 34 : 48,
                color: theme.inkMuted.withValues(alpha: 0.6),
              ),
              SizedBox(height: compact ? 10 : 14),
            ],
            Text(
              sentenceCaseOf(context, title),
              textAlign: TextAlign.center,
              style: theme.bodyEmph.copyWith(
                fontSize: compact ? 17 : 20,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.normal,
                height: 1.25,
                color: theme.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: groupedFooterStyle(theme),
              ),
            ],
            if (act != null) ...[
              SizedBox(height: compact ? 14 : 20),
              act,
            ],
          ],
        ),
      ),
    );
  }
}

/// THE one-line empty note inside a section or a list ("No moments yet",
/// "Nobody here"): centred, muted, 15pt, sentence case. Replaces Discover's
/// and Feed's private lowercase one-liners.
class EmptyLine extends StatelessWidget {
  const EmptyLine(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: padding,
      child: Text(
        sentenceCaseOf(context, text),
        textAlign: TextAlign.center,
        style: groupedFooterStyle(theme),
      ),
    );
  }
}
