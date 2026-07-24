import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../backend/chat_api.dart';
import '../main.dart' show rootNavigatorKey;
import '../widgets/update_sheet.dart';
import 'release_channel.dart';
import 'version_compare.dart';

/// Asks the backend, once per launch, whether this build is behind the latest
/// one published for *its* channel — and if so, offers the update.
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
    try {
      final channel = await resolveChannel();
      // Debug builds, simulators and unrecognised defines: no meaningful
      // "latest" to compare against, so don't ask and don't prompt.
      if (channel == ReleaseChannel.unknown) return;

      final current = (await PackageInfo.fromPlatform()).version;
      if (current.isEmpty) return;

      final release = await api.latestRelease(channel.wire);
      // Nothing published for this channel yet — the normal state for a channel
      // whose store listing doesn't exist.
      if (release == null || release.version.isEmpty) return;
      if (compareVersions(current, release.version) >= 0) return;

      final min = release.minSupported;
      final mandatory = min != null &&
          min.isNotEmpty &&
          compareVersions(current, min) < 0;

      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await showUpdateSheet(
        ctx,
        release: release,
        channel: channel,
        currentVersion: current,
        mandatory: mandatory,
      );
    } catch (e) {
      // Offline boot, Convex not reachable, malformed row — none of it is worth
      // surfacing. An update prompt is an extra, and must never be the reason a
      // launch looks broken.
      debugPrint('UPDATE CHECK skipped: $e');
    }
  }
}
