import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../backend/chat_api.dart';
import '../main.dart' show rootNavigatorKey;
import '../widgets/update_sheet.dart';
import 'release_channel.dart';
import 'update_availability.dart';
import 'version_compare.dart';

/// What a live check against the backend found — returned by
/// [UpdateChecker.checkNow] so a manual "Check for Updates" tap can say
/// something even on the outcomes that raise no sheet.
enum UpdateCheckOutcome {
  /// A newer build exists for this channel; [showUpdateSheet] was already
  /// presented.
  available,

  /// The running build is already the latest published for this channel.
  upToDate,

  /// Debug build, simulator, or unrecognised define — no meaningful "latest"
  /// to compare against.
  unsupported,

  /// Offline, Convex unreachable, or a malformed release row.
  error,
}

/// Asks the backend whether this build is behind the latest one published for
/// *its* channel — and if so, offers the update.
///
/// Shaped after `AndroidCallReliability.instance.ensure()`, the app's existing
/// precedent for "async check on launch that may raise a dialog": a singleton
/// called from the post-first-frame callback in `_bootstrap`, so a navigator is
/// mounted and Convex is already initialized.
class UpdateChecker {
  UpdateChecker._();
  static final UpdateChecker instance = UpdateChecker._();

  /// The check runs on every cold start by design — LATER is a "not now", not a
  /// "stop asking". This guard is only about the *same* launch: `_bootstrap`
  /// can re-run (the boot-error RETRY button calls it), and hot restart in
  /// development would otherwise re-prompt.
  bool _ran = false;

  @visibleForTesting
  void resetForTest() => _ran = false;

  Future<void> ensure(ChatApi api) async {
    if (_ran) return;
    _ran = true;
    await checkNow(api);
  }

  /// Runs a live check against the backend regardless of [ensure]'s
  /// once-per-launch guard — the manual "Check for Updates" settings row calls
  /// this directly, since every tap there should mean an actual round trip.
  ///
  /// Never throws: every failure mode (offline, Convex unreachable, a
  /// malformed release row) is swallowed the same way [ensure] always has,
  /// and reported back as [UpdateCheckOutcome.error] instead — a manual check
  /// button still needs to say *something* on failure, just not a crash.
  Future<UpdateCheckOutcome> checkNow(ChatApi api) async {
    try {
      final channel = await resolveChannel();
      // Debug builds, simulators and unrecognised defines: no meaningful
      // "latest" to compare against, so don't ask and don't prompt.
      if (channel == ReleaseChannel.unknown) return UpdateCheckOutcome.unsupported;

      final current = (await PackageInfo.fromPlatform()).version;
      if (current.isEmpty) return UpdateCheckOutcome.unsupported;

      final release = await api.latestRelease(channel.wire);
      // Nothing published for this channel yet — the normal state for a channel
      // whose store listing doesn't exist.
      if (release == null || release.version.isEmpty) {
        return UpdateCheckOutcome.upToDate;
      }
      if (compareVersions(current, release.version) >= 0) {
        return UpdateCheckOutcome.upToDate;
      }

      final min = release.minSupported;
      final mandatory = min != null &&
          min.isNotEmpty &&
          compareVersions(current, min) < 0;

      UpdateAvailability.instance.report(
        release: release,
        channel: channel,
        currentVersion: current,
        mandatory: mandatory,
      );

      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        await showUpdateSheet(
          ctx,
          release: release,
          channel: channel,
          currentVersion: current,
          mandatory: mandatory,
        );
      }
      return UpdateCheckOutcome.available;
    } catch (e) {
      // Offline boot, Convex not reachable, malformed row — none of it is worth
      // surfacing on the launch path. An update prompt is an extra, and must
      // never be the reason a launch looks broken.
      debugPrint('UPDATE CHECK skipped: $e');
      return UpdateCheckOutcome.error;
    }
  }
}
