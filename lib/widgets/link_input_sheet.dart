import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber, ChoiceTile;

/// What the link sheet resolved to: a URL to apply, or an instruction to
/// remove the existing link. A dismissed sheet returns null — change nothing.
class LinkInputResult {
  const LinkInputResult.apply(String this.url) : removed = false;
  const LinkInputResult.remove()
      : url = null,
        removed = true;

  final String? url;
  final bool removed;
}

/// Asks for the URL a selected stretch of composer text should carry.
/// Pre-filled (with a REMOVE option) when the selection already sits inside a
/// link span, so "edit the link" and "add a link" are one gesture.
Future<LinkInputResult?> showLinkInputSheet(
  BuildContext context, {
  String? initialUrl,
}) =>
    showAdaptiveSheet<LinkInputResult>(
      context,
      builder: (_) => _LinkInputSheet(initialUrl: initialUrl),
    );

class _LinkInputSheet extends StatefulWidget {
  const _LinkInputSheet({this.initialUrl});
  final String? initialUrl;

  @override
  State<_LinkInputSheet> createState() => _LinkInputSheetState();
}

class _LinkInputSheetState extends State<_LinkInputSheet> {
  late final TextEditingController _url =
      TextEditingController(text: widget.initialUrl ?? '');

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _apply() {
    var u = _url.text.trim();
    if (u.isEmpty) return;
    // A bare "example.com" is what people type; the scheme is what the
    // opener (and the server's validator) needs. Never guess http — an
    // upgrade-refusing site can say so itself with a redirect.
    if (!u.startsWith('http://') && !u.startsWith('https://')) {
      u = 'https://$u';
    }
    Navigator.of(context).pop(LinkInputResult.apply(u));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.radiusLg)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        // The keyboard is up the moment the field autofocuses, so the inset
        // is part of this sheet's ordinary shape, not an edge case.
        20 +
            MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetGrabber(),
          Text(l10n.linkInputSheetTitle,
              style: theme.label.copyWith(color: theme.accent)),
          const SizedBox(height: 12),
          Container(
            decoration: theme.inputDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              style: theme.body.copyWith(color: theme.ink),
              cursorColor: theme.accent,
              decoration: InputDecoration(
                isCollapsed: false,
                border: InputBorder.none,
                hintText: l10n.linkInputSheetHint,
                hintStyle: theme.body.copyWith(color: theme.inkMuted),
              ),
              onSubmitted: (_) => _apply(),
            ),
          ),
          const SizedBox(height: 16),
          ChoiceTile(
            color: theme.accent,
            icon: CupertinoIcons.link,
            title: l10n.linkInputSheetApplyLabel,
            sub: l10n.linkInputSheetApplySub,
            filled: true,
            onTap: _apply,
          ),
          if (widget.initialUrl != null) ...[
            const SizedBox(height: 10),
            ChoiceTile(
              color: theme.danger,
              icon: CupertinoIcons.xmark_circle,
              title: l10n.linkInputSheetRemoveLabel,
              sub: widget.initialUrl!,
              onTap: () =>
                  Navigator.of(context).pop(const LinkInputResult.remove()),
            ),
          ],
        ],
      ),
    );
  }
}
