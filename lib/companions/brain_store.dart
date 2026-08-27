/// Where a brain lives on disk, and the only place that knows.
///
/// Three paths per brain and one rule between them:
///
///   `<support>/companions/brains/<file>.litertlm`        the real thing
///   `<support>/companions/brains/<file>.litertlm.part`   bytes so far
///   `<support>/companions/brains/<file>.litertlm.resume` how to continue
///
/// The rule is that **the final path existing means installed** — nothing
/// else. A partial never occupies it, because [BrainDownload] promotes by
/// `rename`, which is atomic: the file appears whole or not at all. That is
/// what lets `isInstalled` be a stat call rather than a conversation with the
/// plugin, and it is why a process killed mid-download can never leave
/// something that looks installed and is not.
///
/// Application SUPPORT, not documents: these are large, re-downloadable, and
/// have no business appearing in a user's Files app or being swept into an
/// iCloud backup. `getApplicationSupportDirectory` is excluded from backup on
/// both platforms, which for a 2.6 GB file is the difference between a working
/// backup and a broken one.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'brain_spec.dart';

class BrainStore {
  BrainStore._();
  static final BrainStore instance = BrainStore._();

  Directory? _dir;

  /// Forgets the memoised directory.
  ///
  /// Only tests need this. An app has exactly one application-support
  /// directory for its whole life, which is what makes memoising it correct
  /// there and wrong in a suite where each case wants its own.
  @visibleForTesting
  void resetForTest() => _dir = null;

  Future<Directory> _brainsDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final support = await getApplicationSupportDirectory();
    return _dir = Directory('${support.path}/companions/brains');
  }

  /// The installed weights. Existing at the right length IS the install.
  Future<File> brainFile(BrainSpec spec) async =>
      File('${(await _brainsDir()).path}/${spec.fileName}');

  /// Bytes received so far.
  Future<File> partFile(BrainSpec spec) async =>
      File('${(await _brainsDir()).path}/${spec.fileName}.part');

  /// The note that makes those bytes resumable — see `_Resume`.
  Future<File> resumeFile(BrainSpec spec) async =>
      File('${(await _brainsDir()).path}/${spec.fileName}.resume');

  /// Whether [spec] is installed and the right size.
  ///
  /// The length check is not paranoia about our own rename — it is about
  /// everything else that can touch a file on a phone: a restore from a
  /// half-finished backup, a filesystem that ran out of room during a copy, a
  /// user with a file manager. Cheap enough to run on every settings open.
  Future<bool> isInstalled(BrainSpec spec) async {
    try {
      final f = await brainFile(spec);
      if (!await f.exists()) return false;
      return await f.length() == spec.sizeBytes;
    } catch (_) {
      return false;
    }
  }

  /// How many bytes of [spec] are already on disk, installed or partial.
  ///
  /// Drives the "resume from 104 MB" line, so it has to answer for a paused
  /// download as readily as for a finished one.
  Future<int> bytesOnDisk(BrainSpec spec) async {
    try {
      if (await isInstalled(spec)) return spec.sizeBytes;
      final part = await partFile(spec);
      return await part.exists() ? await part.length() : 0;
    } catch (_) {
      return 0;
    }
  }

  /// Deletes the weights and anything left of a download.
  ///
  /// Everything, unconditionally: a caller reaching for this wants the disk
  /// back, and leaving a 900 MB `.part` behind because the user pressed Remove
  /// on a paused download would be the exact opposite of what they asked for.
  Future<void> delete(BrainSpec spec) async {
    for (final f in [
      await brainFile(spec),
      await partFile(spec),
      await resumeFile(spec),
    ]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  /// Deletes every file in the brains directory that no brain on the shelf
  /// claims, and returns how many bytes that freed.
  ///
  /// ── The hole this closes ───────────────────────────────────────────────
  ///
  /// Retiring a brain takes it out of [BrainCatalog.all] — which is what every
  /// screen, every install state and every delete path iterates. The weights
  /// stop being offered and stop being attributable, and they go right on
  /// occupying the disk. [bytesUsed] walks the DIRECTORY rather than the
  /// catalog, so the user is even shown the number: "Companions are using
  /// 950 MB" next to a shelf holding 617 MB of brains, and nothing anywhere to
  /// press. Several hundred megabytes, visible and unreachable.
  ///
  /// It is not hypothetical. Sebastian shipped on Qwen3-0.6B and moved to Qwen2
  /// (see [BrainCatalog.sebastianBrain]); every installed user is carrying
  /// 328 MB of a brain this build cannot load.
  ///
  /// ── Why "unclaimed" and not a list of retired names ────────────────────
  ///
  /// A list only reclaims what somebody remembered to write down, which is the
  /// same class of bug one level up: the release that forgets to add a name
  /// leaves the file behind forever, and nothing fails. Claiming is derived
  /// instead, so a brain leaving the catalog is sufficient on its own.
  ///
  /// Deleting unrecognised files is safe here in a way it would not be
  /// anywhere else, and only because of where this directory is. It lives
  /// under application-support, it is created by this class, and the only
  /// things that ever write into it are [brainFile], [partFile] and
  /// [resumeFile] — all three named after a [BrainSpec]. A file here that no
  /// spec claims is, by construction, wreckage from a previous release. It is
  /// also unusable: the engine can only be pointed at a path the catalog
  /// supplies.
  ///
  /// The one thing it costs: a brain retired in one release and brought back in
  /// the next is a fresh download rather than a file already on disk. That is
  /// the right side to be wrong on — the alternative is charging every user
  /// permanent storage against the chance that a model comes back.
  ///
  /// Never touches a live download. A spec being downloaded is in the catalog,
  /// so its `.part` is claimed.
  Future<int> sweepUnclaimed() async {
    var freed = 0;
    try {
      final dir = await _brainsDir();
      if (!await dir.exists()) return 0;

      final claimed = <String>{
        for (final spec in BrainCatalog.all) ...[
          spec.fileName,
          '${spec.fileName}.part',
          '${spec.fileName}.resume',
        ],
      };

      await for (final entity in dir.list()) {
        // Files only. Nothing writes a subdirectory here, and recursing into
        // one this class did not create is not this function's business.
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (claimed.contains(name)) continue;
        try {
          final size = await entity.length();
          await entity.delete();
          freed += size;
        } catch (_) {
          // A file we cannot read or cannot delete stays. It will be offered
          // again on the next refresh, and reporting bytes that are still
          // there would make the storage line lie.
        }
      }
    } catch (_) {}
    return freed;
  }

  /// Forgets how to resume, leaving any bytes in place.  /// Forgets how to resume, leaving any bytes in place.
  ///
  /// Used on success (there is nothing left to resume) and when a partial is
  /// discarded (the note must not outlive the bytes it describes, or the next
  /// attempt would validate a partial that no longer exists).
  Future<void> clearResume(BrainSpec spec) async {
    try {
      final f = await resumeFile(spec);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Total bytes the companions occupy, partials included.
  ///
  /// Walks the directory rather than summing [BrainSpec.sizeBytes], because
  /// this is the number shown next to a Remove button and it has to match what
  /// the OS storage screen says — including a paused download the catalog
  /// knows nothing about the size of.
  Future<int> bytesUsed() async {
    try {
      final dir = await _brainsDir();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final e in dir.list()) {
        if (e is File) {
          try {
            total += await e.length();
          } catch (_) {}
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
