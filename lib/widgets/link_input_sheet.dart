import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'sheet_kit.dart';
import '../l10n/text_case.dart';

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
    // An iOS edit sheet: × on the left, the title, a ✓ on the right that
    // applies — and the field, autofocused, as a filled rounded box. Removing
    // an existing link is the one other thing to do here, as a red button.
    return SheetFrame(
      leading: const SheetCloseButton(),
      title: sentenceCaseOf(context, l10n.linkInputSheetTitle),
      trailing: AnimatedBuilder(
        animation: _url,
        builder: (context, _) => SheetConfirmButton(
          label: l10n.linkInputSheetApplyLabel,
          onTap: _url.text.trim().isEmpty ? null : _apply,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              color: sheetGroupFill(theme),
              borderRadius: BorderRadius.circular(groupedRadius(theme)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              children: [
                Icon(CupertinoIcons.link, size: 18, color: theme.inkMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _url,
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    style: theme.body.copyWith(color: theme.ink, fontSize: 17),
                    cursorColor: theme.accent,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: l10n.linkInputSheetHint,
                      hintStyle: theme.body.copyWith(
                        color: theme.inkMuted,
                        fontSize: 17,
                      ),
                    ),
                    onSubmitted: (_) => _apply(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l10n.linkInputSheetApplySub,
              style: theme.caption.copyWith(fontSize: 13, color: theme.inkMuted),
            ),
          ),
          if (widget.initialUrl != null) ...[
            const SizedBox(height: 18),
            SheetActionButton(
              label: l10n.linkInputSheetRemoveLabel,
              tonal: true,
              destructive: true,
              onTap: () =>
                  Navigator.of(context).pop(const LinkInputResult.remove()),
            ),
          ],
        ],
      ),
    );
  }
}
