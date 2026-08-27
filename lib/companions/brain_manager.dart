/// What every install-related pixel in the app reads from.
///
/// One [ChangeNotifier] for the whole shelf rather than one per brain: an
/// install is a global event as much as a local one — Marlowe's shelf has to
/// grey out its other rows while a download runs (two concurrent
/// multi-hundred-megabyte fetches on a phone is not a feature), Settings shows
/// the running percentage, and a companion's own screen has to notice when the
/// brain it needs arrived because the user started it from somewhere else.
///
/// ── Stopping and starting ──────────────────────────────────────────────────
///
/// A download here is measured in hundreds of megabytes and tens of minutes,
/// which makes "stop for now" an ordinary thing to want rather than an edge
/// case — a train tunnel, a battery warning, a metered connection, a phone
/// that got put down. So the state machine treats it as one:
///
///     absent ──install──▶ queued ──▶ downloading ⇄ paused
///                                        │             │
///                                        ├──▶ installed
///                                        └──▶ failed ──retry──▶ …
///
/// [pause] keeps every byte. [cancel] throws them away — that is the whole
/// difference between the two, and it is why they are separate verbs instead
/// of one "stop".
///
/// Crucially, PAUSED IS NOT AN IN-MEMORY STATE. It is a `.part` file on disk
/// with a note beside it, so a download interrupted by the process being killed
/// is in exactly the same state as one the user paused deliberately, and
/// [refresh] finds both. See [BrainStore] and [BrainDownload].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'brain_download.dart';
import 'brain_gateway.dart';
import 'brain_spec.dart';
import 'device_capability.dart';
import 'brain_store.dart';

/// Where one brain is in its life.
enum BrainStatus {
  /// Nothing on disk, nothing happening.
  absent,

  /// Asked for, waiting for the one download slot. Only reachable when another
  /// install is already running.
  queued,

  downloading,

  /// Stopped with bytes kept. Reached by [BrainManager.pause], and also by
  /// simply finding a `.part` file at startup — a download the OS interrupted
  /// looks identical to one the user paused, because it is.
  paused,

  /// On disk, full length, and loadable.
  installed,

  /// The last attempt ended badly and the user has not acknowledged it.
  failed,
}

/// Why an install ended badly, in the terms the UI has different words for.
enum BrainInstallFailure {
  /// No route to the CDN, or it died mid-stream. The common one, and the only
  /// one where "try again" is honest advice — and now the cheapest, because
  /// trying again resumes rather than restarts.
  network,

  /// The device said no.
  storage,

  /// The bytes are not the bytes this build expects: a length or a digest that
  /// disagrees with [BrainSpec]. Retrying IS worth offering, but only because
  /// the partial has already been discarded — see [BrainDownload].
  integrity,

  unknown,
}

/// One row of the shelf, as the UI sees it.
@immutable
class BrainState {
  const BrainState({
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.failure,
  });

  final BrainStatus status;

  /// Bytes on disk. Meaningful while [BrainStatus.downloading] AND while
  /// [BrainStatus.paused] — a paused row says "104 MB of 328 MB", which is the
  /// number that makes resuming feel like continuing rather than restarting.
  final int receivedBytes;
  final int totalBytes;
  final BrainInstallFailure? failure;

  bool get isBusy =>
      status == BrainStatus.downloading || status == BrainStatus.queued;

  /// Whether there are bytes worth keeping — what the UI asks to decide
  /// between offering RESUME and offering INSTALL.
  bool get isResumable => status == BrainStatus.paused && receivedBytes > 0;

  double get fraction =>
      totalBytes <= 0 ? 0 : (receivedBytes / totalBytes).clamp(0.0, 1.0);

  static const absent = BrainState(status: BrainStatus.absent);
  static const installed = BrainState(status: BrainStatus.installed);
}

class BrainManager extends ChangeNotifier {
  BrainManager._();
  static final BrainManager instance = BrainManager._();

  final Map<String, BrainState> _states = {};

  /// The brain currently downloading, if any. At most one, ever — see
  /// [install].
  String? _activeInstallId;

  /// The live download, so [pause] and [cancel] have something to talk to.
  BrainDownload? _active;

  /// Ids waiting for the slot, in the order they were asked for.
  final List<String> _waiting = [];

  Future<void>? _refresh;

  /// True while any brain is downloading or waiting to.
  bool get isInstallingAny => _activeInstallId != null;

  /// The state of the download that is actually running, or null.
  ///
  /// Exposed for the ambient indicator in Settings, which needs a percentage
  /// and does not care which brain it belongs to — at most one runs at a time,
  /// so "the download" is unambiguous.
  BrainState? get activeInstall {
    final id = _activeInstallId;
    if (id == null) return null;
    final state = _states[id];
    return state != null && state.isBusy ? state : null;
  }

  /// Whether any brain has bytes on disk and is not being fetched.
  ///
  /// Read by the ambient indicators, which have to surface a paused download
  /// as well as a running one — it is the paused one that gets forgotten.
  bool get hasPausedDownload => _states.values
      .any((s) => s.status == BrainStatus.paused && s.receivedBytes > 0);

  /// What the UI should draw for [spec].
  BrainState stateOf(BrainSpec spec) => _states[spec.id] ?? BrainState.absent;

  bool isInstalled(BrainSpec spec) =>
      stateOf(spec).status == BrainStatus.installed;

  bool isReady(BrainSpec? spec) => spec != null && isInstalled(spec);

  /// Total bytes the companions occupy.
  ///
  /// Read from the FILESYSTEM rather than summed from [BrainSpec.sizeBytes],
  /// which is what makes a half-finished download count. A user looking at
  /// this number is deciding whether to free space, and 900 MB of paused
  /// partial is 900 MB whatever the catalog thinks it will eventually be.
  int get installedBytes => _bytesUsed;
  int _bytesUsed = 0;

  /// Reconciles the in-memory table with what is actually on disk.
  ///
  /// This is also the resume-after-death path: a `.part` file left by a
  /// process the OS killed is indistinguishable from one the user paused, so
  /// both come back as [BrainStatus.paused] with their byte count intact and
  /// the row offers to continue.
  Future<void> refresh() {
    final existing = _refresh;
    if (existing != null) return existing;
    final future = () async {
      try {
        if (!BrainGateway.instance.isSupported) return;
        // AWAITED, and that ordering is the whole point. Sebastian's shelf is
        // walked best-first and gated on physical RAM, so a machine that has
        // not been sized yet resolves to the small brain — correct as a default
        // and wrong as an answer. `main.dart` fires this off unawaited at boot;
        // here is where anything that is about to READ the shelf waits for it.
        //
        // Cheap and memoised: the second caller awaits the first call rather
        // than asking the platform again.
        await DeviceCapability.instance.prime();
        // Before anything is counted, and on every refresh rather than once
        // behind a version flag. A brain this build has retired is not absent,
        // not installed and not paused — it is a file nothing in the catalog
        // can see, while `bytesUsed` below walks the DIRECTORY and counts it.
        // Leaving it would show the user disk they have no way to reclaim.
        //
        // Refresh is the right hook: it is what runs at boot (`main.dart`) and
        // whenever a companion screen opens, which is exactly when the storage
        // number is about to be read.
        final freed = await BrainStore.instance.sweepUnclaimed();
        if (freed > 0) {
          debugPrint(
            'BrainManager: reclaimed ${freed ~/ (1024 * 1024)} MB of weights '
            'no brain on the shelf claims',
          );
        }
        for (final spec in BrainCatalog.all) {
          // Never overwrite a live download's state with a disk probe — the
          // file is half-written, so `isInstalled` says no, which would snap a
          // running progress bar back to "Install".
          if (stateOf(spec).isBusy) continue;

          if (await BrainStore.instance.isInstalled(spec)) {
            _states[spec.id] = BrainState.installed;
            continue;
          }
          final onDisk = await BrainStore.instance.bytesOnDisk(spec);
          _states[spec.id] = onDisk > 0
              ? BrainState(
                  status: BrainStatus.paused,
                  receivedBytes: onDisk,
                  totalBytes: spec.sizeBytes,
                )
              : BrainState.absent;
        }
        _bytesUsed = await BrainStore.instance.bytesUsed();
        notifyListeners();
      } finally {
        _refresh = null;
      }
    }();
    _refresh = future;
    return future;
  }

  /// Starts a download, or continues a paused one.
  ///
  /// One verb for both, because from the caller's side they are the same
  /// request — "get me this brain" — and from the downloader's side the only
  /// difference is a starting offset it works out from the disk. A separate
  /// `resume` that did something subtly different is how the two paths drift.
  ///
  /// Serialised across the whole shelf. Two brains downloading at once on a
  /// phone means both crawl, the progress UI stops meaning anything, and the
  /// peak disk requirement is the sum rather than the max — on a device that
  /// may not have room for the sum.
  Future<void> install(BrainSpec spec) async {
    if (!BrainGateway.instance.isSupported) return;
    final current = stateOf(spec);
    if (current.status == BrainStatus.installed || current.isBusy) return;

    if (_activeInstallId != null) {
      if (!_waiting.contains(spec.id)) _waiting.add(spec.id);
      _set(
        spec.id,
        BrainState(
          status: BrainStatus.queued,
          // Carried through the queue so a paused download that is waiting for
          // the slot still shows what it already has, instead of reading as if
          // it were starting from nothing.
          receivedBytes: current.receivedBytes,
          totalBytes: spec.sizeBytes,
        ),
      );
      return;
    }

    await _run(spec);
  }

  /// Stops the running download and KEEPS the bytes.
  ///
  /// No-op on a brain that is not the one running — including one merely
  /// queued, which is [cancel]'s business since it has nothing to keep.
  void pause(BrainSpec spec) {
    if (_activeInstallId != spec.id) return;
    _active?.pause();
  }

  /// Stops and throws the bytes away.
  ///
  /// Deletes the partial and the resume note, so the next attempt starts from
  /// zero. This is the destructive one; [pause] is the other.
  void cancel(BrainSpec spec) {
    if (_activeInstallId == spec.id) {
      _active?.cancel();
      return;
    }
    if (_waiting.remove(spec.id)) {
      // Never ran, so there is nothing to abort — but there may be bytes from
      // an earlier attempt, and CANCEL means the user wants them gone.
      unawaited(_discardAndForget(spec));
    } else if (stateOf(spec).status == BrainStatus.paused) {
      unawaited(_discardAndForget(spec));
    }
  }

  Future<void> _discardAndForget(BrainSpec spec) async {
    await BrainStore.instance.delete(spec);
    _bytesUsed = await BrainStore.instance.bytesUsed();
    _set(spec.id, BrainState.absent);
  }

  Future<void> _run(BrainSpec spec) async {
    _activeInstallId = spec.id;
    _waiting.remove(spec.id);
    final download = _active = BrainDownload(spec);

    _set(
      spec.id,
      BrainState(
        status: BrainStatus.downloading,
        receivedBytes: stateOf(spec).receivedBytes,
        totalBytes: spec.sizeBytes,
      ),
    );

    var lastReceived = stateOf(spec).receivedBytes;
    try {
      await for (final p in download.start()) {
        lastReceived = p.received;
        _set(
          spec.id,
          BrainState(
            status: BrainStatus.downloading,
            receivedBytes: p.received,
            totalBytes: p.total,
          ),
        );
      }
      _set(spec.id, BrainState.installed);
    } on DownloadPaused {
      // Bytes kept. The row now offers to continue, and says how far it got.
      _set(
        spec.id,
        BrainState(
          status: BrainStatus.paused,
          receivedBytes: await BrainStore.instance.bytesOnDisk(spec),
          totalBytes: spec.sizeBytes,
        ),
      );
    } on DownloadCancelled {
      // Silent, and back to absent. The user pressed cancel; they know.
      _set(spec.id, BrainState.absent);
    } on DownloadException catch (e) {
      _set(
        spec.id,
        BrainState(
          status: BrainStatus.failed,
          receivedBytes: lastReceived,
          totalBytes: spec.sizeBytes,
          failure: switch (e.failure) {
            DownloadFailure.network => BrainInstallFailure.network,
            DownloadFailure.storage => BrainInstallFailure.storage,
            DownloadFailure.integrity => BrainInstallFailure.integrity,
            DownloadFailure.unknown => BrainInstallFailure.unknown,
          },
        ),
      );
    } catch (e) {
      debugPrint('BrainManager: unclassified install failure: $e');
      _set(
        spec.id,
        const BrainState(
          status: BrainStatus.failed,
          failure: BrainInstallFailure.unknown,
        ),
      );
    } finally {
      _activeInstallId = null;
      _active = null;
      _bytesUsed = await BrainStore.instance.bytesUsed();
      notifyListeners();
      _startNextWaiting();
    }
  }

  /// Hands the slot on, skipping anything the user pulled out of the queue
  /// while this one ran.
  void _startNextWaiting() {
    while (_waiting.isNotEmpty) {
      final next = BrainCatalog.byId(_waiting.first);
      _waiting.removeAt(0);
      if (next != null && stateOf(next).status == BrainStatus.queued) {
        unawaited(_run(next));
        return;
      }
    }
  }

  /// Clears a [BrainStatus.failed] row back to whatever the disk says.
  ///
  /// Goes through [refresh] rather than straight to `absent`, because a failed
  /// download usually still has its bytes — a dropped connection keeps them —
  /// and snapping the row to "Install · 328 MB" would throw away the one thing
  /// that makes the retry cheap.
  Future<void> acknowledgeFailure(BrainSpec spec) async {
    if (stateOf(spec).status != BrainStatus.failed) return;
    _states.remove(spec.id);
    await refresh();
  }

  /// Deletes the weights, and anything left of a download.
  ///
  /// No confirmation here — that belongs to the screen, which is where the
  /// sentence explaining what is about to be lost can be written.
  Future<void> uninstall(BrainSpec spec) async {
    if (_activeInstallId == spec.id) {
      _active?.cancel();
    }
    await BrainGateway.instance.uninstall(spec);
    _bytesUsed = await BrainStore.instance.bytesUsed();
    _set(spec.id, BrainState.absent);
  }

  void _set(String id, BrainState state) {
    _states[id] = state;
    notifyListeners();
  }
}
