import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../theme/theme_scope.dart';
import 'action_buttons.dart';
import 'glass_buttons.dart';
import 'ios_kit.dart'
    show groupedFooterStyle, groupedRadius, tileColor, TileTone;

/// What an inline [Notice] is saying. Picks the colour and the default glyph.
enum NoticeTone {
  /// Neutral information ("some fields are hidden").
  info,

  /// Heads-up, nothing failed yet.
  warn,

  /// Something failed, usually with the one thing to do about it.
  error,

  /// A confirmation that reuses the layout.
  success,

  /// A call to act, in the accent.
  action,
}

/// THE inline banner: a washed rounded block with a glyph, an optional bold
/// [title], the [message], an optional one-line action and an optional
/// dismiss ×.
///
/// Page-level notices, form errors and server-unreachable cards are all this
/// widget; [SoftNote] and [FormErrorBanner] are presets. Specialised strips
/// (the connection banner, pinned message, call and game banners) are
/// different roles: they live in chat chrome and are not washed blocks.
///
/// [loud] is the form-error register: the sentence is set in the tone colour
/// at 15pt and announced to a screen reader the moment it appears. The quiet
/// default sets the sentence in soft ink beside a tinted glyph.
class Notice extends StatelessWidget {
  const Notice(
    this.message, {
    super.key,
    this.tone = NoticeTone.info,
    this.color,
    this.icon,
    this.title,
    this.loud = false,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.dismissLabel,
  });

  final String message;
  final String? title;
  final NoticeTone tone;

  /// An explicit colour beating [tone] (a caller-computed hue).
  final Color? color;

  /// Null picks the tone's glyph.
  final IconData? icon;
  final bool loud;

  /// Both set draws a text action under the message.
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Set draws a small × at the trailing edge.
  final VoidCallback? onDismiss;
  final String? dismissLabel;

  static IconData glyphFor(NoticeTone tone) => switch (tone) {
        NoticeTone.info => CupertinoIcons.info_circle_fill,
        NoticeTone.warn => CupertinoIcons.exclamationmark_triangle_fill,
        NoticeTone.error => CupertinoIcons.exclamationmark_circle_fill,
        NoticeTone.success => CupertinoIcons.checkmark_circle_fill,
        NoticeTone.action => CupertinoIcons.arrow_right_circle_fill,
      };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final c = color ??
        switch (tone) {
          NoticeTone.info => theme.inkMuted,
          NoticeTone.warn => tileColor(theme, TileTone.orange),
          NoticeTone.error => theme.danger,
          NoticeTone.success => theme.success,
          NoticeTone.action => theme.accent,
        };
    final body = loud
        ? theme.bodySoft.copyWith(fontSize: 15, height: 1.3, color: c)
        : groupedFooterStyle(theme).copyWith(color: theme.inkSoft);
    final hasAction = actionLabel != null && onAction != null;
    Widget box = Container(
      padding: EdgeInsets.fromLTRB(
        loud ? 12 : 14,
        11,
        onDismiss != null ? 6 : 14,
        hasAction ? 2 : 11,
      ),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(groupedRadius(theme) * 0.7),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon ?? glyphFor(tone), size: loud ? 18 : 16, color: c),
          ),
          SizedBox(width: loud ? 9 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: groupedFooterStyle(theme).copyWith(
                      color: theme.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(message, style: body),
                if (hasAction)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Transform.translate(
                      offset: const Offset(-4, 0),
                      child: TextLinkButton(
                        label: actionLabel!,
                        onTap: onAction,
                        destructive: tone == NoticeTone.error && color == null,
                        fontSize: 15,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (onDismiss != null)
            GlassCloseButton(
              onTap: onDismiss,
              semanticLabel: dismissLabel,
              size: 32,
              iconSize: 12,
            ),
        ],
      ),
    );
    if (loud) box = Semantics(liveRegion: true, child: box);
    return box;
  }
}
