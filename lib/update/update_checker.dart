import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:package_info_plus/package_info_plus.dart';

import '../backend/convex_client.dart';
import '../backend/release_api.dart';
import '../main.dart' show rootNavigatorKey;
import '../models/app_release.dart';
import '../widgets/update_sheet.dart';
import 'linux_self_update.dart';
import 'release_channel.dart';
import 'store_answer.dart';
import 'store_updates.dart';
import 'update_availability.dart';
import 'update_watch_action.dart';

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

  /// Re-asks the store on resume, for channels whose answer can change with
  /// no release row moving. See [_onResume].
  AppLifecycleListener? _resumeListener;

  /// The last store answer, so a subscription delivery or a resume shortly
  /// after a check doesn't ask again. The Microsoft Store in particular
  /// throttles how often an app may ask.
  ({ReleaseChannel channel, StoreAnswer answer, DateTime at})? _storeCache;
  Future<StoreAnswer>? _storeInFlight;

  /// The row the subscription last delivered, so a resume-time store answer
  /// can be combined with the current `minSupported` and notes.
  AppRelease? _lastRow;

  /// Minimum gap between store asks that aren't a manual tap.
  static const _storeTtl = Duration(minutes: 30);

  /// Minimum gap between resume-time re-asks. An approval or a certification
  /// lands a few times a month; checking more often than this buys nothing.
  static const _resumeEvery = Duration(hours: 6);

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
    _resumeListener?.dispose();
    _resumeListener = null;
    _storeCache = null;
    _storeInFlight = null;
    _lastRow = null;
    _sheetOpen = false;
  }

  Future<void> ensure() async {
    if (_ran) return;
    _ran = true;
    // First moment the folder a Linux self-update replaced is out of use.
    LinuxSelfUpdate.sweep();
    await checkNow();
  }

  /// The store's answer for [channel], reused for [_storeTtl] unless [fresh].
  Future<StoreAnswer> _askStore(
    ReleaseChannel channel,
    String current, {
    bool fresh = false,
  }) async {
    final cached = _storeCache;
    if (!fresh &&
        cached != null &&
        cached.channel == channel &&
        DateTime.now().difference(cached.at) < _storeTtl) {
      return cached.answer;
    }
    // ensure() and watch() start together at launch; the second ask joins
    // the first instead of going to the store twice.
    final inFlight = _storeInFlight;
    if (inFlight != null) return inFlight;
    final ask = askStore(channel, current).then((answer) {
      // A non-answer isn't worth remembering: the next ask should try again.
      if (answer.verdict != StoreVerdict.noAnswer) {
        _storeCache = (channel: channel, answer: answer, at: DateTime.now());
      }
      return answer;
    }).whenComplete(() => _storeInFlight = null);
    _storeInFlight = ask;
    return ask;
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

      // On a store channel the row only adds minSupported and notes, so a
      // backend that can't be reached mustn't hide what the store says — the
      // user on a build too old to talk to it is exactly who needs the prompt.
      AppRelease? release;
      try {
        release = await _api.latestRelease(channel.wire);
      } catch (e) {
        if (!storeAnswers(channel)) rethrow;
        debugPrint('UPDATE CHECK: no release row ($e), asking the store alone');
      }
      // Every tap is a real round trip, to the store as much as the backend.
      final store = await _askStore(channel, current, fresh: true);
      final d = decideUpdate(
        release: release,
        store: store,
        currentVersion: current,
        isFirstDelivery: true,
      );
      switch (d.action) {
        case UpdateWatchAction.ignore:
          // Nothing published for a row-driven channel is the normal state
          // for a channel with no listing yet. A store that didn't answer is
          // a failed check, and the settings row should say so.
          return store.verdict == StoreVerdict.noAnswer
              ? UpdateCheckOutcome.error
              : UpdateCheckOutcome.upToDate;
        case UpdateWatchAction.clearBadge:
          return UpdateCheckOutcome.upToDate;
        case UpdateWatchAction.badgeOnly:
        case UpdateWatchAction.badgeAndPrompt:
          break;
      }
      final offered = d.release!;

      UpdateAvailability.instance.report(
        release: offered,
        channel: channel,
        currentVersion: current,
        mandatory: d.mandatory,
      );

      await _raiseSheet(
        release: offered,
        channel: channel,
        currentVersion: current,
        mandatory: d.mandatory,
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
        onRelease: (release) async {
          final isFirst = firstDelivery;
          firstDelivery = false;
          _lastRow = release;
          // For a store channel the row only carries minSupported and notes;
          // whether there is an update at all is the store's answer.
          final store = await _askStore(channel, current);
          _apply(
            decideUpdate(
              release: release,
              store: store,
              currentVersion: current,
              isFirstDelivery: isFirst,
            ),
            channel: channel,
            current: current,
          );
        },
              );

      // An approval, a certification, a Play rollout reaching this track:
      // none of them moves the row, so the subscription can't hear them. An
      // app on iOS can stay warm for weeks, so ask again on the way back to
      // the foreground, at most every [_resumeEvery].
      _resumeListener?.dispose();
      _resumeListener = null;
      if (storeAnswers(channel)) {
        var lastAsk = DateTime.now();
        _resumeListener = AppLifecycleListener(
          onResume: () {
            if (DateTime.now().difference(lastAsk) < _resumeEvery) return;
            lastAsk = DateTime.now();
            unawaited(_onResume(channel, current));
          },
        );
      }
    } catch (e) {
      // Same stance as [checkNow]: the update path is an extra and must never
      // be the reason a launch looks broken.
      debugPrint('UPDATE WATCH skipped: $e');
    }
  }

  /// A resume-time store re-ask, combined with the row last delivered. A
  /// later delivery in every sense, so a mandatory answer interrupts.
  Future<void> _onResume(ReleaseChannel channel, String current) async {
    try {
      final store = await _askStore(channel, current, fresh: true);
      _apply(
        decideUpdate(
          release: _lastRow,
          store: store,
          currentVersion: current,
          isFirstDelivery: false,
        ),
        channel: channel,
        current: current,
      );
    } catch (e) {
      debugPrint('UPDATE RESUME check skipped: $e');
    }
  }

  /// Turns a decision into badge state and, when it calls for one, the sheet.
  void _apply(
    ({UpdateWatchAction action, AppRelease? release, bool mandatory}) d, {
    required ReleaseChannel channel,
    required String current,
  }) {
    switch (d.action) {
      case UpdateWatchAction.ignore:
        return;
      case UpdateWatchAction.clearBadge:
        UpdateAvailability.instance.clear();
      case UpdateWatchAction.badgeOnly:
      case UpdateWatchAction.badgeAndPrompt:
        UpdateAvailability.instance.report(
          release: d.release!,
          channel: channel,
          currentVersion: current,
          mandatory: d.mandatory,
        );
        if (d.action == UpdateWatchAction.badgeAndPrompt) {
          unawaited(
            _raiseSheet(
              release: d.release!,
              channel: channel,
              currentVersion: current,
              mandatory: true,
            ),
          );
        }
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
