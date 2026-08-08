import 'package:flutter/foundation.dart';

/// Asks for the OS notification permission at most once per process, and only
/// when asking can still produce a prompt.
///
/// Extracted from [PushManager] because the rule it encodes is subtle, costly
/// to get wrong, and otherwise untestable — the logic sits behind a platform
/// channel and a `Platform.isIOS` gate that a unit test never reaches.
///
/// The bug it prevents: on Android, `requestPermissions` for a permission the
/// user has already refused twice returns INSTANTLY, showing no dialog — but it
/// still pauses and resumes the activity. That resume is what
/// `App.didChangeAppLifecycleState` answers by scheduling a foreground sync,
/// which refreshes tokens, which asks for permission again. A captured session
/// on a Galaxy S24 shows ~30 resumed/inactive flips in 23 seconds, each firing
/// a token write and a family-context read, forever, on battery.
///
/// It only ever reproduced on "some Android devices" because a device that
/// GRANTED notifications never enters the loop. Denial is what arms it — and
/// denial is ordinary on Android 13+, where POST_NOTIFICATIONS is a runtime
/// permission.
class PermissionLatch {
  PermissionLatch({
    required this.readStatus,
    required this.request,
    required this.isForeground,
  });

  /// Current authorization: `granted` | `provisional` | `denied` |
  /// `notDetermined`. Null when the platform couldn't answer.
  final Future<String?> Function() readStatus;

  /// Show the system prompt. Only ever called when [readStatus] said
  /// `notDetermined`.
  final Future<void> Function() request;

  /// Whether the app is actually on screen. A headless background launch (the
  /// VoIP-push cold start) cannot prompt and must not burn the one ask.
  final bool Function() isForeground;

  bool _settled = false;

  @visibleForTesting
  bool get settled => _settled;

  Future<void> maybeAsk() async {
    if (_settled) return;
    // Checked before latching: a background launch must still be able to ask
    // on a later, real foreground.
    if (!isForeground()) return;
    // Latched here, before the first await rather than next to the request:
    // every await below yields, and an unlatched window is the whole of what a
    // re-entrant caller needs to start a second prompt. The prompt itself
    // pauses and resumes the app, so that caller is not hypothetical.
    _settled = true;
    try {
      final status = await readStatus();
      // `granted`/`provisional` — nothing to ask for. `denied` — the OS will
      // not show the sheet again, so a request buys nothing and costs the
      // pause/resume churn above. Re-enabling from there is a Settings
      // redirect, which belongs behind an explicit button.
      if (status != 'notDetermined') return;
      await request();
    } catch (e) {
      // The channel failed rather than the user answering, so nothing was
      // actually decided. Unlatch so a later foreground can try once more —
      // being permanently silent after one transient failure is the worse of
      // the two outcomes, and the resume throttle in `App` caps a repeated
      // failure at one attempt per interval instead of a storm.
      _settled = false;
      debugPrint('PermissionLatch: ask failed: $e');
    }
  }
}
