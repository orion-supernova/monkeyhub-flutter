import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_errors.dart';
import '../auth/auth_service.dart';
import '../auth/continue_store.dart';
import '../backend/convex_client.dart' show ServerRefusal;
import '../keyboard/focusable_tap.dart' show HoverEffect;
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/action_buttons.dart';
import '../widgets/ios_kit.dart' show groupedRadius;
import '../widgets/spring_press.dart';

/// "Welcome back: Continue as Lena" on a fresh install whose Apple account
/// already carries a child account's continue key (see [ContinueStore]).
///
/// Apple only. On Android the system's own "Sign in as" sheet asks the same
/// question, so the login screen never shows this there.
///
/// One button per remembered account (siblings can share an Apple ID), the
/// first one filled. "Use another account" goes back to the ordinary screen.
class ContinueAsScreen extends StatefulWidget {
  const ContinueAsScreen({
    super.key,
    required this.auth,
    required this.accounts,
    required this.onDismiss,
  });

  final AuthService auth;
  final List<ContinueAccount> accounts;
  final VoidCallback onDismiss;

  @override
  State<ContinueAsScreen> createState() => _ContinueAsScreenState();
}

class _ContinueAsScreenState extends State<ContinueAsScreen> {
  /// The account being continued as, while the call is in flight.
  ContinueAccount? _busy;
  String? _error;

  Future<void> _continue(ContinueAccount a) async {
    if (_busy != null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = a;
      _error = null;
    });
    try {
      await widget.auth.continueAs(a);
      // Signed in: the app's auth listener swaps this screen out.
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _error = e is ServerRefusal && e.code == 'CONTINUE_KEY_INVALID'
            ? l10n.continueAsFailed
            : humanizeAuthError(e, l10n);
      });
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String _label(ContinueAccount a) {
    final n = a.name?.trim();
    return n == null || n.isEmpty ? '@${a.username}' : n;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ContentWidth.auth),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    36,
                    20,
                    edgeToEdgeBottom(context, 24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.continueAsTitle,
                        style: theme.displayLarge.copyWith(letterSpacing: 0.37),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.continueAsIntro,
                        style: theme.bodySoft.copyWith(fontSize: 17),
                      ),
                      const SizedBox(height: 28),
                      for (final (i, a) in widget.accounts.indexed) ...[
                        if (i > 0) const SizedBox(height: 12),
                        SheetActionButton(
                          label: sentenceCaseOf(
                            context,
                            l10n.continueAsButton(_label(a)),
                          ),
                          tonal: i > 0,
                          busy: identical(_busy, a),
                          haptic: false,
                          onTap: _busy != null ? null : () => _continue(a),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                          decoration: BoxDecoration(
                            color: theme.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              groupedRadius(theme) * 0.6,
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: theme.body.copyWith(color: theme.danger),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Center(
                        child: SpringPress(
                          onTap: _busy != null ? null : widget.onDismiss,
                          scale: PressSpec.scaleSmall,
                          haptic: false,
                          hover: HoverEffect.none,
                          child: Text(
                            l10n.continueAsOther,
                            style: theme.body.copyWith(
                              fontSize: 15,
                              color: theme.accent,
                            ),
                          ),
                        ),
                      ),
                    ],
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
