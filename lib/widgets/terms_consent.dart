import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../backend/chat_api.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../legal_links.dart';
import '../services/link_opener.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'sheet_kit.dart';

/// "I agree to the Terms of Use (EULA) and understand there is zero
/// tolerance for objectionable content or abusive users", with a box.
///
/// THE consent control, shared by the three places agreement is formed —
/// password sign-up, the Apple/Google username step, and the acceptance sheet
/// for accounts that predate it — so the words a reviewer reads are the same
/// words everywhere. App Store Guideline 1.2 asks for exactly this: explicit
/// agreement to terms that make clear there is no tolerance for objectionable
/// content or abusive users, before anyone can post.
///
/// A box rather than a switch, because this is a statement the user signs
/// rather than a setting they can flip back. The whole row toggles; the
/// "Terms of Use (EULA)" words open the document instead.
class TermsConsentRow extends StatefulWidget {
  const TermsConsentRow({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<TermsConsentRow> createState() => _TermsConsentRowState();
}

class _TermsConsentRowState extends State<TermsConsentRow> {
  // Owned and disposed here, unlike a recognizer built inline in `build`,
  // which would leak one per frame.
  late final TapGestureRecognizer _link = TapGestureRecognizer()
    ..onTap = () => LinkOpener.open(context, kEulaUrl);

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final base = theme.bodySoft.copyWith(color: theme.inkSoft, height: 1.35);
    return Semantics(
      checked: widget.value,
      child: FocusableTap(
        onTap: _toggle,
        semanticLabel: l10n.termsConsentSemanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  widget.value
                      ? CupertinoIcons.checkmark_square_fill
                      : CupertinoIcons.square,
                  size: 22,
                  color: widget.value ? theme.accent : theme.inkMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: base,
                      children: [
                        TextSpan(text: l10n.termsConsentPrefix),
                        TextSpan(
                          text: l10n.termsConsentLink,
                          style: base.copyWith(
                            color: theme.accent,
                            decoration: TextDecoration.underline,
                            decorationColor: theme.accent,
                          ),
                          recognizer: _link,
                        ),
                        TextSpan(text: l10n.termsConsentSuffix),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the acceptance sheet if this account has not accepted the current
/// Terms of Use, and does not return until it has.
///
/// For accounts created before acceptance was asked for, and for any account
/// an old build created without the checkbox (`terms.ts` lets those sign up
/// and stops them here instead). Blocking on purpose: it cannot be swiped
/// away, and its only way out is agreeing. Asks the server once per launch,
/// and only blocks on a definite "not accepted" — offline, or a backend too
/// old to know, shows nothing rather than a sheet nobody can get past.
Future<void> ensureTermsAccepted(BuildContext context, ChatApi api) async {
  final accepted = await api.termsAccepted();
  if (accepted != false || !context.mounted) return;
  await showAdaptiveSheet<void>(
    context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _TermsAcceptanceSheet(api: api),
  );
}

class _TermsAcceptanceSheet extends StatefulWidget {
  const _TermsAcceptanceSheet({required this.api});
  final ChatApi api;

  @override
  State<_TermsAcceptanceSheet> createState() => _TermsAcceptanceSheetState();
}

class _TermsAcceptanceSheetState extends State<_TermsAcceptanceSheet> {
  bool _agreed = false;
  bool _busy = false;

  Future<void> _accept() async {
    if (!_agreed || _busy) return;
    final toast = AppToast.of(context);
    final l10n = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await widget.api.acceptTerms();
      nav.pop();
    } catch (_) {
      toast.error(l10n.termsAcceptFailed);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    // Back is swallowed: agreeing is the only way past this sheet.
    return PopScope(
      canPop: false,
      child: SheetFrame(
        title: l10n.termsSheetTitle,
        // No ×, no grabber: there is no "not now" for this one.
        showClose: false,
        handle: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.termsSheetBody,
              textAlign: TextAlign.center,
              style: theme.bodySoft.copyWith(color: theme.inkMuted),
            ),
            const SizedBox(height: 16),
            TermsConsentRow(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v),
            ),
            const SizedBox(height: 18),
            SheetActionButton(
              label: l10n.termsSheetAccept,
              busy: _busy,
              onTap: _agreed ? _accept : null,
            ),
          ],
        ),
      ),
    );
  }
}
