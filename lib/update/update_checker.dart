import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../backend/convex_client.dart';
import '../backend/release_api.dart';
import '../main.dart' show rootNavigatorKey;
import '../models/app_release.dart';
import '../widgets/update_sheet.dart';
import 'release_channel.dart';
import 'update_availability.dart';
import 'update_watch_action.dart';
import 'version_compare.dart';

export 'update_watch_action.dart' show UpdateWatchAction, decideWatchAction;

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

  /// Owned rather than passed in: every caller was handing over the same
  /// process-wide facade, and the settings row had to carry a backend handle
  /// purely to forward it here.
  ReleaseApi _api = ReleaseApi(ConvexBackend.instance);

  @visibleForTesting
  set apiForTest(ReleaseApi api) => _api = api;

  /// The check runs on every cold start by design — LATER is a "not now", not a
  /// "stop asking". This guard is only about the *same* launch: `_bootstrap`
  /// can re-run (the boot-error RETRY button calls it), and hot restart in
  /// development would otherwise re-prompt.
  bool _ran = false;

  /// Handle for the live subscription started by [watch].
  Subscription? _watchSub;

  /// True while an update sheet is on screen. Before [watch] existed only one
  /// thing could ever raise the sheet, so nothing could stack on it; now a
  /// mandatory release can arrive over the socket while the cold-start sheet
  /// is still up.
  bool _sheetOpen = false;

  @visibleForTesting
  void resetForTest() {
    _ran = false;
    _watchSub?.cancel();
    _watchSub = null;
    _sheetOpen = false;
  }

  Future<void> ensure() async {
    if (_ran) return;
    _ran = true;
    await checkNow();
  }

  /// Runs a live check against the backend regardless of [ensure]'s
  /// once-per-launch guard — the manual "Check for Updates" settings row calls
  /// this directly, since every tap there should mean an actual round trip.
  ///
  /// Never throws: every failure mode (offline, Convex unreachable, a
  /// malformed release row) is swallowed the same way [ensure] always has,
  /// and reported back as [UpdateCheckOutcome.error] instead — a manual check
  /// button still needs to say *something* on failure, just not a crash.
  Future<UpdateCheckOutcome> checkNow() async {
    try {
      final channel = await resolveChannel();
      // Debug builds, simulators and unrecognised defines: no meaningful
      // "latest" to compare against, so don't ask and don't prompt.
      if (channel == ReleaseChannel.unknown) return UpdateCheckOutcome.unsupported;

      final current = (await PackageInfo.fromPlatform()).version;
      if (current.isEmpty) return UpdateCheckOutcome.unsupported;

      final release = await _api.latestRelease(channel.wire);
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

      await _raiseSheet(
        release: release,
        channel: channel,
        currentVersion: current,
        mandatory: mandatory,
      );
      return UpdateCheckOutcome.available;
    } catch (e) {
      // Offline boot, Convex not reachable, malformed row — none of it is worth
      // surfacing on the launch path. An update prompt is an extra, and must
      // never be the reason a launch looks broken.
      debugPrint('UPDATE CHECK skipped: $e');
      return UpdateCheckOutcome.error;
    }
  }

  /// Keeps the badge honest for the whole session, not just the first frame of
  /// it.
  ///
  /// [ensure] answers "was there an update when this launch started", which on
  /// iOS can be a question from three weeks ago — an app that is never
  /// force-quit never re-asks. This subscribes instead, so publishing a release
  /// lights the Settings badge on phones that are already running.
  ///
  /// Not a foreground poll on purpose. A one-shot query in this client is
  /// internally a subscribe/read/unsubscribe on the socket that is already
  /// open, so polling on resume would cost the same traffic as simply holding
  /// the subscription — while adding a timer, a throttle, and a lifecycle
  /// hook, and still only ever answering on resume. Holding it adds no
  /// wakeups, and covers resume anyway: backgrounding past
  /// `backgroundRebuildThreshold` rebuilds the socket and `SubscriptionRegistry`
  /// re-delivers on the way back.
  ///
  /// Never raises the sheet for an ordinary update. The badge is enough — a
  /// release published mid-conversation must not throw a modal over it. Only a
  /// *mandatory* one interrupts, because the running build is below
  /// `minSupported` and can't be trusted to keep working.
  Future<void> watch() async {
    try {
      // `_bootstrap` re-runs on the boot-error RETRY button, and a second
      // subscription here would double every delivery for the rest of the
      // session.
      _watchSub?.cancel();
      _watchSub = null;

      final channel = await resolveChannel();
      // Debug builds and simulators hold no subscription at all — there is no
      // meaningful "latest" for them, so there's nothing to be told about.
      if (channel == ReleaseChannel.unknown) return;

      // Resolved once and captured: `onData` runs on every delivery and must
      // not go back to the platform channel each time.
      final current = (await PackageInfo.fromPlatform()).version;
      if (current.isEmpty) return;

      // [ensure] already owns the cold-start prompt, and the subscription's
      // first payload says the same thing it does. Without this the two would
      // race to stack two sheets. It is deliberately per-[watch]-call rather
      // than per-bind: a reconnect re-delivers as a *later* delivery, which is
      // exactly right — a mandatory release published while the phone was
      // asleep should raise its sheet the moment the user comes back.
      var firstDelivery = true;

      _watchSub = await _api.subscribeLatestRelease(
        channel: channel.wire,
        onError: (e) => debugPrint('UPDATE WATCH error: $e'),
        onRelease: (release) {
          final decision = decideWatchAction(
            release: release,
            currentVersion: current,
            isFirstDelivery: firstDelivery,
          );
          firstDelivery = false;

          switch (decision.action) {
            case UpdateWatchAction.ignore:
              return;
            case UpdateWatchAction.clearBadge:
              UpdateAvailability.instance.clear();
            case UpdateWatchAction.badgeOnly:
            case UpdateWatchAction.badgeAndPrompt:
              UpdateAvailability.instance.report(
                release: release!,
                channel: channel,
                currentVersion: current,
                mandatory: decision.mandatory,
              );
              if (decision.action == UpdateWatchAction.badgeAndPrompt) {
                unawaited(
                  _raiseSheet(
                    release: release,
                    channel: channel,
                    currentVersion: current,
                    mandatory: true,
                  ),
                );
              }
          }
        },
      );
    } catch (e) {
      // Same stance as [checkNow]: the update path is an extra and must never
      // be the reason a launch looks broken.
      debugPrint('UPDATE WATCH skipped: $e');
    }
  }

  /// Single door to [showUpdateSheet] so the "one sheet at a time" guard can't
  /// be forgotten at a call site.
  Future<void> _raiseSheet({
    required AppRelease release,
    required ReleaseChannel channel,
    required String currentVersion,
    required bool mandatory,
  }) async {
    if (_sheetOpen) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    _sheetOpen = true;
    try {
      await showUpdateSheet(
        ctx,
        release: release,
        channel: channel,
        currentVersion: currentVersion,
        mandatory: mandatory,
      );
    } finally {
      _sheetOpen = false;
    }
  }
}
