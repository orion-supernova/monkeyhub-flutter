import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/settings_store.dart';
import '../main.dart' show rootNavigatorKey;
import '../screens/recovery_phrase_screen.dart';
import 'auth_service.dart';
import 'recovery_phrase.dart';

/// Raises the save-your-recovery-phrase gate for accounts that need it.
///
/// Two populations reach this, and they are treated differently:
///
///  * **Accounts created before the phrase was mandatory.** Most have no
///    phrase at all, because the field used to be optional and hidden behind a
///    disclosure toggle. They are unrecoverable today. Prompted once, and the
///    prompt is dismissible — after that the settings/profile banner carries
///    it. This is a prompt, not a nag.
///  * **A just-completed password reset.** The phrase was typed out in full,
///    possibly on a borrowed machine, so it is spent and must be rotated. That
///    gate is NOT dismissible and ignores any previous dismissal.
///
/// Shaped after [UpdateChecker] — the app's existing precedent for "decide
/// after boot whether to raise a modal", including the once-per-run latch.
class RecoveryGate {
  RecoveryGate._();
  static final RecoveryGate instance = RecoveryGate._();

  bool _running = false;

  /// The account already handled this run. Unlike UpdateChecker's plain bool,
  /// this is keyed by user: signing out and back in as someone else must
  /// re-check, and an app that stays open for days should not re-ask.
  String? _checkedFor;

  /// Clears the latch. Called on sign-out so the next account is checked.
  void reset() {
    _checkedFor = null;
  }

  @visibleForTesting
  void resetForTest() => reset();

  Future<void> ensure(AuthService auth, ChatApi api) async {
    final session = auth.session;
    if (session == null) return;
    // Children have no password and no reset path, so there is nothing here
    // that could work for them. The backend also returns hasRecoveryKey as
    // null for a child; this is the near-side half of the same guard.
    if (auth.isChild) return;
    if (_running || _checkedFor == session.userId) return;

    _running = true;
    try {
      final rotating = auth.needsPhraseRotation;

      // A dismissal only silences the legacy-account prompt. A rotation is a
      // consequence of something the user just did, and is not optional.
      if (!rotating &&
          SettingsStore.instance.recoveryPromptDismissedFor == session.userId) {
        _checkedFor = session.userId;
        return;
      }

      var needs = rotating;
      if (!needs) {
        final me =
            await api.getProfile(session.userId, viewerUserId: session.userId);
        // `null` means UNKNOWN — a backend that predates the field, or a
        // response we couldn't read. Fail open and stay quiet: a client
        // shipped ahead of the backend deploy must never nag.
        needs = me?.hasRecoveryKey == false;
      }
      if (!needs) {
        _checkedFor = session.userId;
        return;
      }

      final nav = rootNavigatorKey.currentState;
      // No navigator yet — leave the latch unset so the next trigger retries.
      if (nav == null) return;

      final saved = await nav.push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => RecoveryPhraseScreen(
            phrase: RecoveryPhrase.generate(),
            mode: RecoveryGateMode.repair,
            dismissible: !rotating,
            // Present only on the post-reset path, where the user set a new
            // password seconds ago. Consumed once, so a later gate in the same
            // session asks properly.
            knownPassword: auth.consumePendingRotationPassword(),
            onCommit: (password, hash) =>
                auth.setRecoveryKey(password: password, recoveryKeyHash: hash),
          ),
        ),
      );

      _checkedFor = session.userId;
      if (saved != true) {
        await SettingsStore.instance
            .markRecoveryPromptDismissed(session.userId);
      }
    } catch (e) {
      // Offline, Convex unreachable, profile fetch failed — none of it is
      // worth surfacing, and none of it should stop the app opening. The
      // latch is left unset so the next launch tries again.
      debugPrint('RECOVERY GATE skipped: $e');
    } finally {
      _running = false;
    }
  }
}
