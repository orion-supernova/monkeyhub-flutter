import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_errors.dart';
import '../auth/recovery_phrase.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../platform.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/password_field.dart';

/// Why this screen is being shown, which decides where it starts and what the
/// user is allowed to do to get out of it.
enum RecoveryGateMode {
  /// Signing up. No account exists yet, so this screen never touches the
  /// network — it pops `true` and lets the caller run signup with the hash.
  setup,

  /// An existing account with no phrase, or a post-reset rotation. Commits
  /// through [RecoveryPhraseScreen.onCommit] before popping.
  repair,

  /// Deliberate regeneration from profile. Also commits through `onCommit`,
  /// but the old phrase stays valid until that succeeds, so backing out is
  /// harmless and allowed.
  rotate,
}

/// Shows a freshly minted 12-word recovery phrase and asks the user to save it
/// before letting them past.
///
/// A full-screen route rather than a sheet: twelve numbered words plus the
/// explanation and two buttons does not fit a bottom sheet on a small phone,
/// and the desktop popover from `showAdaptiveSheet` caps at 460px. Being a
/// route also means there is no barrier to tap and no drag to dismiss, and it
/// inherits the same auth shell as LoginScreen and ChildPairScreen for free.
///
/// **The phrase is deliberately NOT cleared when the app is backgrounded.**
/// This looks like an oversight and is not. The single most likely thing a
/// user does on this screen is switch to 1Password or Notes to save the words
/// and then come back; wiping on `AppLifecycleState.paused` would make the
/// feature unusable for exactly the people using it correctly. Flutter keeps
/// the widget tree across backgrounding, so the phrase survives. If the OS
/// kills the process outright, the signup ordering (gate BEFORE the account is
/// created) means no account was ever made and nothing is lost.
///
/// Likewise, this screen does NOT enable `CaptureProtection` for its duration.
/// That is a persisted user *setting*, and flipping it here would silently
/// overwrite the user's own preference. It needs a scoped API before it could
/// be used that way.
class RecoveryPhraseScreen extends StatefulWidget {
  const RecoveryPhraseScreen({
    super.key,
    required this.phrase,
    required this.mode,
    this.dismissible = false,
    this.onCommit,
    this.knownPassword,
  });

  final RecoveryPhrase phrase;
  final RecoveryGateMode mode;

  /// Whether the user may leave without saving. False makes this a hard gate:
  /// Android back and desktop Esc are both blocked.
  final bool dismissible;

  /// Persists the phrase. Required for [RecoveryGateMode.repair] and
  /// [RecoveryGateMode.rotate]; unused for [RecoveryGateMode.setup], where no
  /// account exists yet.
  final Future<void> Function(String password, String recoveryKeyHash)? onCommit;

  /// Skips the password step. Set only on the post-reset rotation, where the
  /// user typed a new password seconds ago and asking again would be rude.
  final String? knownPassword;

  @override
  State<RecoveryPhraseScreen> createState() => _RecoveryPhraseScreenState();
}

/// The two steps, held as state on ONE route rather than pushed as two, so
/// there is exactly one [PopScope] guarding the flow instead of two that could
/// disagree.
///
/// There is deliberately NO "type word #4 and #7 back" step. It was tried and
/// removed: it reads as a test, it lands right after the user has already done
/// the work of saving the words, and the phrase is on screen the whole time so
/// it stops nobody who is determined to skip. "I saved them" is taken at face
/// value.
enum _Step { password, show }

class _RecoveryPhraseScreenState extends State<RecoveryPhraseScreen> {
  // `late` so the initializer can read `widget`; assignable because the
  // password step advances to the words.
  late _Step _step = _initialStep();
  bool _busy = false;
  String? _error;

  final _password = TextEditingController();

  _Step _initialStep() {
    // Password first, always — otherwise the user reads twelve words, writes
    // them down, taps "I saved them", and only then discovers they can't
    // remember the password needed to save them.
    final needsPassword =
        widget.mode != RecoveryGateMode.setup && widget.knownPassword == null;
    return needsPassword ? _Step.password : _Step.show;
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  String get _effectivePassword =>
      widget.knownPassword ?? _password.text;

  void _goTo(_Step step) => setState(() {
        _step = step;
        _error = null;
      });

  void _copy() {
    // The canonical form IS what is displayed, so a paste of this on the reset
    // screen hashes identically. See RecoveryPhrase.canonical.
    Clipboard.setData(ClipboardData(text: widget.phrase.canonical));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).recoveryPhraseScreenCopiedSnackbar,
        ),
      ),
    );
  }

  /// Takes "I saved them" at its word and moves on.
  Future<void> _save() async {
    if (_busy) return;

    // Signup has no account to write to yet — the caller runs signup with this
    // hash the moment we pop, so that killing the app mid-gate leaves no
    // half-provisioned account behind.
    if (widget.mode == RecoveryGateMode.setup) {
      Navigator.of(context).pop(true);
      return;
    }

    // Commit BEFORE popping. The user must never walk away believing a phrase
    // is live when the server rejected it.
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onCommit!(
        _effectivePassword,
        recoveryPhraseHash(widget.phrase.canonical),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = humanizeAuthError(e, AppLocalizations.of(context));
          _busy = false;
          // A wrong password can only be fixed on the password step, and only
          // when we own that step at all.
          if (widget.knownPassword == null &&
              e.toString().contains('WRONG_PASSWORD')) {
            _step = _Step.password;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return PopScope(
      // The whole point of the gate. Blocks Android back and desktop Esc; a
      // route has no barrier tap or drag-to-close to worry about.
      canPop: widget.dismissible,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            theme.backgroundLayer(context),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: ContentWidth.auth),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _body(theme),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(AppTheme theme) => switch (_step) {
        _Step.password => _passwordStep(theme),
        _Step.show => _showStep(theme),
      };

  // ───────────────────────────── password ─────────────────────────────

  List<Widget> _passwordStep(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    return [
      _Hero(
        muted: l10n.recoveryPhraseScreenConfirmHeroMuted,
        ink: l10n.recoveryPhraseScreenConfirmHeroInk,
      ),
      const SizedBox(height: 20),
      Text(
        l10n.recoveryPhraseScreenPasswordBody,
        style: theme.bodySoft,
      ),
      const SizedBox(height: 24),
      PasswordField(
        controller: _password,
        hint: l10n.recoveryPhraseScreenPasswordHint,
        autofocus: isPhysicalKeyboardPlatform,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submitPassword(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        _ErrorBanner(_error!),
      ],
      const SizedBox(height: 20),
      _Cta(
        label: l10n.recoveryPhraseScreenContinueButton,
        busy: _busy,
        onTap: _submitPassword,
      ),
      if (widget.dismissible) ...[
        const SizedBox(height: 16),
        _TextLink(
          label: l10n.recoveryPhraseScreenNotNowLink,
          onTap: () => Navigator.of(context).pop(false),
        ),
      ],
    ];
  }

  void _submitPassword() {
    if (_password.text.isEmpty) {
      setState(
        () => _error =
            AppLocalizations.of(context).recoveryPhraseScreenEnterPasswordError,
      );
      return;
    }
    _goTo(_Step.show);
  }

  // ─────────────────────────────── show ───────────────────────────────

  List<Widget> _showStep(AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    return [
      _Hero(
        muted: l10n.recoveryPhraseScreenSaveHeroMuted,
        ink: l10n.recoveryPhraseScreenSaveHeroInk,
      ),
      const SizedBox(height: 20),
      Text(
        l10n.recoveryPhraseScreenWordsBody,
        style: theme.bodySoft,
      ),
      const SizedBox(height: 24),
      _PhraseGrid(words: widget.phrase.words),
      const SizedBox(height: 16),
      _OutlineCta(label: l10n.recoveryPhraseScreenCopyButton, onTap: _copy),
      const SizedBox(height: 10),
      Text(
        // Honest rather than reassuring: on mobile the clipboard is readable
        // by other apps. We deliberately do NOT try to clear it afterwards —
        // that can't be done reliably and it would break the paste.
        l10n.recoveryPhraseScreenPaperHint,
        style: theme.monoTiny.copyWith(color: theme.inkMuted),
      ),
      if (_error != null) ...[
        const SizedBox(height: 14),
        _ErrorBanner(_error!),
      ],
      const SizedBox(height: 24),
      _Cta(
        label: l10n.recoveryPhraseScreenSavedButton,
        busy: _busy,
        onTap: _save,
      ),
      if (_backLabel(l10n) != null) ...[
        const SizedBox(height: 16),
        _TextLink(
          label: _backLabel(l10n)!,
          onTap: () => Navigator.of(context).pop(false),
        ),
      ],
    ];
  }

  /// The escape hatch, offered only where leaving costs the user nothing.
  ///
  ///  * setup — no account exists yet, so backing out loses nothing at all.
  ///  * rotate — the OLD phrase stays valid right up until onCommit succeeds.
  ///  * repair, dismissible — the one-time "not now" for existing accounts.
  ///  * repair, not dismissible — post-reset rotation. No way out but forward.
  String? _backLabel(AppLocalizations l10n) {
    if (widget.mode == RecoveryGateMode.setup) {
      return l10n.recoveryPhraseScreenBackLink;
    }
    if (widget.dismissible) return l10n.recoveryPhraseScreenKeepPhraseLink;
    return null;
  }

}

/// The twelve words, numbered, two columns by six rows.
///
/// Built as a Column of Rows rather than a GridView: twelve fixed items inside
/// a SingleChildScrollView must not introduce a second scrollable. The numbers
/// are there so a hand-written copy can be checked against the screen.
class _PhraseGrid extends StatelessWidget {
  const _PhraseGrid({required this.words});
  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Below this a two-column row squeezes the longer words (8 characters
        // plus a two-digit index) into an ellipsis.
        final twoUp = constraints.maxWidth >= 340;
        if (!twoUp) {
          return Column(
            children: [
              for (var i = 0; i < 12; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _WordCell(index: i, word: words[i]),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var row = 0; row < 6; row++) ...[
              if (row > 0) const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _WordCell(index: row, word: words[row])),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WordCell(index: row + 6, word: words[row + 6]),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

class _WordCell extends StatelessWidget {
  const _WordCell({required this.index, required this.word});
  final int index;
  final String word;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        border: Border.all(color: theme.divider),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '${index + 1}',
              style: theme.monoTiny.copyWith(color: theme.inkMuted),
            ),
          ),
          const SizedBox(width: 6),
          // Plain Text, never SelectableText: partial selection of a recovery
          // phrase is a footgun, and there is exactly one honest copy action.
          Expanded(
            child: Text(
              word,
              style: theme.mono.copyWith(color: theme.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.muted, required this.ink});
  final String muted;
  final String ink;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return RichText(
      text: TextSpan(
        style: theme.displayHero,
        children: [
          TextSpan(
            text: muted,
            style: theme.displayHero.copyWith(color: theme.inkMuted),
          ),
          TextSpan(text: ink),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.danger.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: theme.danger, width: 2)),
        borderRadius: BorderRadius.circular(theme.radiusMd),
      ),
      child: Text(message, style: theme.body.copyWith(color: theme.danger)),
    );
  }
}

/// Filled primary action. Mirrors `_SubmitButton` in login_screen.dart — a bare
/// GestureDetector inside a FocusableTap. Never an InkWell; this app draws no
/// ink anywhere.
class _Cta extends StatelessWidget {
  const _Cta({required this.label, required this.busy, required this.onTap});
  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: busy ? null : onTap,
      enabled: !busy,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: busy ? theme.accentSoft : theme.accent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.accentInk,
                  ),
                )
              : Text(
                  label,
                  style: theme.label
                      .copyWith(color: theme.accentInk, letterSpacing: 2.4),
                ),
        ),
      ),
    );
  }
}

/// Secondary action — same shape as [_Cta], outlined instead of filled, so
/// COPY reads as subordinate to the primary CTA below it.
class _OutlineCta extends StatelessWidget {
  const _OutlineCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: theme.accent),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            label,
            style:
                theme.label.copyWith(color: theme.accent, letterSpacing: 2.4),
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Center(
      child: FocusableTap(
        onTap: onTap,
        enabled: onTap != null,
        semanticLabel: label,
        radius: theme.radiusMd,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              label,
              style: theme.monoTiny.copyWith(color: theme.inkMuted),
            ),
          ),
        ),
      ),
    );
  }
}
