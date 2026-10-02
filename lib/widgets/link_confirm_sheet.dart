import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'sheet_kit.dart';

/// Asks before opening a link ENTITY — text like "check this" that carries a
/// URL the visible words say nothing about.
///
/// Bare URLs in a message keep their direct tap-to-open, because there the
/// visible text IS the destination. A link entity severs that: the sender
/// chose both the words and the target independently, which is precisely the
/// shape of a phishing lure, so the one thing this sheet exists to do is put
/// the real destination in front of the reader's eyes before anything loads.
/// The host is pulled out and printed loudest — "which SITE is this" is the
/// question a reader can actually answer at a glance; the full URL sits under
/// it for anyone who reads further.
///
/// Returns true when the reader chose to open.
Future<bool> showLinkConfirmSheet(BuildContext context, {required String url}) async {
  final res = await showAdaptiveSheet<bool>(
    context,
    builder: (_) => _LinkConfirmSheet(url: url),
  );
  return res ?? false;
}

class _LinkConfirmSheet extends StatelessWidget {
  const _LinkConfirmSheet({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    // Empty-host fallback covers a URL Uri can't parse; the full string below
    // is then the only honest rendering, and the tile still shows it.
    final host = Uri.tryParse(url)?.host ?? '';
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.linkConfirmSheetTitle),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The destination, host loudest. SelectableText so a suspicious
          // reader can copy the URL out and inspect it without opening it —
          // which is the whole posture of this sheet.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: sheetGroupFill(theme),
              borderRadius: BorderRadius.circular(groupedRadius(theme)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tileColor(theme, TileTone.blue),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    CupertinoIcons.link,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (host.isNotEmpty) ...[
                        Text(
                          host,
                          style: theme.bodyEmph.copyWith(
                            color: theme.ink,
                            fontSize: 17,
                            fontStyle: FontStyle.normal,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      SelectableText(
                        url,
                        style: theme.caption.copyWith(
                          fontSize: 13,
                          color: theme.inkMuted,
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SheetActionButton(
            label: l10n.linkConfirmSheetOpenLabel,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 4),
          // Autofocused so Enter on a fresh sheet cancels rather than opens —
          // the destructive-sheet convention, borrowed because "open an
          // unread URL" is the riskier of the two options here too.
          FocusableTap(
            onTap: () => Navigator.of(context).pop(false),
            autofocus: true,
            semanticLabel: l10n.linkConfirmSheetCancelLabel,
            radius: theme.radiusMd,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              behavior: HitTestBehavior.opaque,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                alignment: Alignment.center,
                child: Text(
                  sentenceCaseOf(context, l10n.linkConfirmSheetCancelLabel),
                  style: theme.body.copyWith(
                    fontSize: 17,
                    color: theme.accent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
