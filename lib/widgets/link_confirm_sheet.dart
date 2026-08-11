import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';
import '../keyboard/focusable_tap.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber, ChoiceTile;

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
        20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetGrabber(),
          Text(l10n.linkConfirmSheetTitle,
              style: theme.label.copyWith(color: theme.accent)),
          const SizedBox(height: 10),
          // The destination, host loudest. SelectableText so a suspicious
          // reader can copy the URL out and inspect it without opening it —
          // which is the whole posture of this sheet.
          if (host.isNotEmpty) ...[
            Text(host, style: theme.bodyEmph.copyWith(color: theme.ink)),
            const SizedBox(height: 4),
          ],
          SelectableText(
            url,
            style: theme.monoTiny.copyWith(color: theme.inkSoft),
            maxLines: 4,
          ),
          const SizedBox(height: 20),
          ChoiceTile(
            color: theme.accent,
            icon: CupertinoIcons.arrow_up_right_square,
            title: l10n.linkConfirmSheetOpenLabel,
            sub: host.isNotEmpty ? host : url,
            filled: true,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
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
                padding: const EdgeInsets.symmetric(vertical: 14),
                alignment: Alignment.center,
                child: Text(l10n.linkConfirmSheetCancelLabel,
                    style: theme.label.copyWith(color: theme.inkMuted)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
