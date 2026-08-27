/// What every install-related pixel in the app reads from.
///
/// One [ChangeNotifier] for the whole shelf rather than one per brain: an
/// install is a global event as much as a local one — Vera's shelf has to grey
/// out its other rows while a download runs (two concurrent multi-hundred-
/// megabyte fetches on a phone is not a feature), Settings has to show the
/// total on disk, and Sebastian's install sheet has to notice when the brain
/// he needs arrived because the user installed Vera first.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'brain_gateway.dart';
import 'brain_spec.dart';

/// Where one brain is in its life.
enum BrainStatus {
  /// Not on disk, nothing happening.
  absent,

  /// Asked for, waiting for the one download slot. Only reachable when
  /// another install is already running.
  queued,

  downloading,

  /// On disk and loadable.
  installed,

  /// The last attempt ended badly and the user has not acknowledged it.
  /// Carries a [BrainInstallFailure] on [BrainState.failure].
  failed,
}

/// Why an install ended badly, in the terms the UI has different words for.
///
/// Classified here rather than at the widget, because the classification is a
/// judgement about an exception object and that is not a thing a build method
/// should be doing.
enum BrainInstallFailure {
  /// No route to the CDN, or it died mid-stream. The overwhelmingly common
  /// one, and the only one where "try again" is honest advice.
  network,

  /// The device said no. Distinguished because retrying is pointless until the
  /// user does something, and what they should do is specific.
  storage,

  /// Anything else — a 403 on a repo that turned out to be gated, a corrupt
  /// download, a runtime that refused the file.
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
  final int receivedBytes;
  final int totalBytes;
  final BrainInstallFailure? failure;

  bool get isBusy =>
      status == BrainStatus.downloading || status == BrainStatus.queued;

  /// 0…1. Zero while queued, which is correct — nothing has been received.
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

  /// Ids waiting for the slot, in the order they were asked for.
  final List<String> _waiting = [];

  /// Fires to cancel whichever install is running.
  Completer<void>? _cancel;

  Future<void>? _refresh;

  /// True while any brain is downloading or waiting to.
  bool get isInstallingAny => _activeInstallId != null;

  /// What the UI should draw for [spec].
  ///
  /// Returns [BrainState.absent] for a brain nobody has asked about yet, which
  /// is also what it returns on an unsupported platform — the shelf is drawn
  /// there, disabled, rather than hidden, so a desktop user who wonders where
  /// the feature went gets an answer instead of a gap.
  BrainState stateOf(BrainSpec spec) => _states[spec.id] ?? BrainState.absent;

  bool isInstalled(BrainSpec spec) =>
      stateOf(spec).status == BrainStatus.installed;

  /// Whether every brain [companion] needs is ready. For Sebastian that is his
  /// one brain; for Vera it is whether she has ANY, since her shelf is a choice
  /// rather than a requirement.
  bool isReady(BrainSpec? spec) => spec != null && isInstalled(spec);

  /// Total bytes the companions occupy, counting a shared brain once.
  ///
  /// Reads [BrainSpec.sizeBytes] rather than stat-ing the files: the number is
  /// wanted synchronously in a build method, it is exact (the catalog carries
  /// measured content-lengths), and a brain that is installed is by definition
  /// the size the catalog says it is.
  int get installedBytes {
    var total = 0;
    for (final b in BrainCatalog.all) {
      if (isInstalled(b)) total += b.sizeBytes;
    }
    return total;
  }

  /// Reconciles the in-memory table with what is actually on disk.
  ///
  /// Called on first paint of anything that shows install state. Memoised while
  /// in flight so three widgets appearing in the same frame ask the plugin
  /// once, but NOT memoised afterwards: an uninstall elsewhere, or an install
  /// that finished while a screen was closed, has to be visible on the next
  /// open.
  Future<void> refresh() {
    final existing = _refresh;
    if (existing != null) return existing;
    final future = () async {
      try {
        if (!BrainGateway.instance.isSupported) return;
        for (final spec in BrainCatalog.all) {
          // Never overwrite a live download's state with a disk probe — the
          // file is half-written and `isInstalled` says no, which would snap a
          // progress arc back to "Install".
          if (stateOf(spec).isBusy) continue;
          final present = await BrainGateway.instance.isInstalled(spec);
          _states[spec.id] =
              present ? BrainState.installed : BrainState.absent;
        }
        notifyListeners();
      } finally {
        _refresh = null;
      }
    }();
    _refresh = future;
    return future;
  }

  /// Starts (or queues) a download.
  ///
  /// Serialised across the whole shelf on purpose. Two brains downloading at
  /// once on a phone means both crawl, the progress UI stops meaning anything,
  /// and the peak disk requirement is the sum rather than the max — on a device
  /// that may not have room for the sum. The second request waits, visibly, as
  /// [BrainStatus.queued].
  Future<void> install(BrainSpec spec) async {
    if (!BrainGateway.instance.isSupported) return;
    final current = stateOf(spec);
    if (current.status == BrainStatus.installed || current.isBusy) return;

    if (_activeInstallId != null) {
      if (!_waiting.contains(spec.id)) _waiting.add(spec.id);
      _set(spec.id, const BrainState(status: BrainStatus.queued));
      return;
    }

    await _run(spec);
  }

  Future<void> _run(BrainSpec spec) async {
    _activeInstallId = spec.id;
    _waiting.remove(spec.id);
    final cancel = _cancel = Completer<void>();
    _set(
      spec.id,
      BrainState(
        status: BrainStatus.downloading,
        totalBytes: spec.sizeBytes,
      ),
    );

    try {
      await for (final p in BrainGateway.instance
          .install(spec, cancel: cancel.future)) {
        _set(
          spec.id,
          BrainState(
            status: BrainStatus.downloading,
            receivedBytes: p.receivedBytes,
            totalBytes: p.totalBytes,
          ),
        );
      }
      _set(spec.id, BrainState.installed);
    } on BrainInstallCancelled {
      // Silent, and back to absent. The user pressed cancel; they know.
      _set(spec.id, BrainState.absent);
    } catch (e) {
      _set(
        spec.id,
        BrainState(status: BrainStatus.failed, failure: _classify(e)),
      );
    } finally {
      _activeInstallId = null;
      if (!cancel.isCompleted) cancel.complete();
      _cancel = null;
      // Hand the slot on. Skips anything the user cancelled out of the queue
      // while this one ran.
      while (_waiting.isNotEmpty) {
        final next = BrainCatalog.byId(_waiting.first);
        _waiting.removeAt(0);
        if (next != null && stateOf(next).status == BrainStatus.queued) {
          unawaited(_run(next));
          break;
        }
      }
    }
  }

  /// Stops the running install, or removes a queued one from the line.
  void cancel(BrainSpec spec) {
    if (_activeInstallId == spec.id) {
      _cancel?.complete();
      return;
    }
    if (_waiting.remove(spec.id)) _set(spec.id, BrainState.absent);
  }

  /// Clears a [BrainStatus.failed] back to [BrainStatus.absent] so the row
  /// offers its install button again. Called when the user dismisses the
  /// error, not automatically — an error that vanishes on its own is an error
  /// nobody read.
  void acknowledgeFailure(BrainSpec spec) {
    if (stateOf(spec).status == BrainStatus.failed) {
      _set(spec.id, BrainState.absent);
    }
  }

  /// Deletes the weights.
  ///
  /// No confirmation here — that belongs to the screen, which is where the
  /// sentence explaining what is about to be lost can be written.
  Future<void> uninstall(BrainSpec spec) async {
    await BrainGateway.instance.uninstall(spec);
    _set(spec.id, BrainState.absent);
  }

  void _set(String id, BrainState state) {
    _states[id] = state;
    notifyListeners();
  }

  BrainInstallFailure _classify(Object error) {
    final s = error.toString().toLowerCase();
    if (s.contains('space') ||
        s.contains('enospc') ||
        s.contains('disk') ||
        s.contains('storage')) {
      return BrainInstallFailure.storage;
    }
    if (s.contains('socket') ||
        s.contains('network') ||
        s.contains('connection') ||
        s.contains('timeout') ||
        s.contains('handshake') ||
        s.contains('host')) {
      return BrainInstallFailure.network;
    }
    return BrainInstallFailure.unknown;
  }
}
