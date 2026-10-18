@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/brain_spec.dart';
import 'package:monkeyhub/companions/brain_store.dart';
import 'package:monkeyhub/companions/companion.dart';
import 'package:monkeyhub/companions/device_capability.dart';
import 'package:monkeyhub/screens/companions/companion_page.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The shelf, and what happens to a brain that leaves it.
///
/// The catalog is a constant, so most of it cannot be wrong at runtime. What
/// CAN be wrong is the relationship between the constant and the disk: a brain
/// removed from the catalog is a brain nothing iterates any more, and the file
/// it left behind is several hundred megabytes that no screen counts, no button
/// offers, and no delete path reaches.
void main() {
  group('the catalog itself', () {
    /// Sebastian's brain must not be a reasoning model. This is the whole
    /// reason the shelf changed: Qwen3's thinking mode could not be reliably
    /// switched off — `enableThinking: false` is honoured by the runtime rather
    /// than the weights, `/no_think` is a soft switch — and what reached
    /// readers was first "Okay, I need to translate this", then `<think>`
    /// blocks, then a channel marker between every token.
    ///
    /// Asserted rather than remembered because the next person to look for a
    /// better translator will find that the strongest small multilingual models
    /// are mostly reasoning models, and the reason not to take one is written
    /// nowhere the compiler can see.
    test('no brain Sebastian can load has a reasoning mode', () {
      for (final brain in BrainCatalog.sebastianBrains) {
        expect(
          brain.family,
          isNot(BrainFamily.qwen3),
          reason: 'a hybrid-reasoning model cannot be talked out of narrating '
              'itself — see BrainCatalog.sebastianBrains (${brain.id})',
        );
      }
    });

    /// The shelf is walked best-first and the device takes the first row it can
    /// carry, so the ORDER is the policy. Stated as a test because a list
    /// literal has no other way to say which end is which.
    test('his shelf is ordered best first', () {
      final sizes = [for (final b in BrainCatalog.sebastianBrains) b.sizeBytes];
      expect(sizes, orderedEquals(sizes.toList()..sort((a, b) => b - a)));
      expect(BrainCatalog.sebastianFallback, BrainCatalog.sebastianBrains.last);
    });

    /// The fallback is what a device of unknown size gets, so it cannot itself
    /// be gated behind more memory than anything else on the shelf.
    test('the fallback asks for as little as anything on the shelf', () {
      final floors = [
        for (final b in BrainCatalog.sebastianBrains) b.minRamMb ?? 0,
      ];
      expect(BrainCatalog.sebastianFallback.minRamMb ?? 0,
          floors.reduce((a, b) => a < b ? a : b));
    });

    /// The engine registered in `BrainGateway` is LiteRT-LM, and handing it a
    /// MediaPipe `.task` fails at LOAD rather than at download — an hour later
    /// and several hundred megabytes heavier.
    test('every brain is a .litertlm', () {
      for (final brain in BrainCatalog.all) {
        expect(brain.fileName, endsWith('.litertlm'), reason: brain.id);
      }
    });

    /// 1024 is the floor LiteRT-LM will allocate at all.
    test('every brain opens with a window the runtime will accept', () {
      for (final brain in BrainCatalog.all) {
        expect(brain.contextTokens, greaterThanOrEqualTo(1024),
            reason: brain.id);
      }
    });

    /// The size is spent twice — as the number a user agrees to, and as the
    /// free-space precheck — and the digest is what makes a download resumed
    /// across three sessions as trustworthy as one taken in a single sitting.
    test('every brain carries an exact size and a full digest', () {
      for (final brain in BrainCatalog.all) {
        expect(brain.sizeBytes, greaterThan(1000000), reason: brain.id);
        expect(brain.sha256, hasLength(64), reason: brain.id);
        expect(brain.sha256, matches(RegExp(r'^[0-9a-f]{64}$')),
            reason: brain.id);
        expect(brain.url, endsWith(brain.fileName), reason: brain.id);
      }
    });

    test('ids are unique and every companion has at least one brain', () {
      final ids = BrainCatalog.all.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final companion in Companion.values) {
        // Bartleby's one download is the speech model, not a brain.
        expect(
          BrainCatalog.forCompanion(companion),
          companion.usesBrains ? isNotEmpty : isEmpty,
          reason: companion.id,
        );
      }
    });

    /// File names have to be distinct too, not just ids: they ARE the identity
    /// on disk and the key the sweep below claims by, so two specs sharing one
    /// would have each install overwrite the other.
    test('file names are unique', () {
      final names = BrainCatalog.all.map((b) => b.fileName).toList();
      expect(names.toSet().length, names.length);
    });
  });

  group('what the two rows are called', () {
    /// SR and JR rather than a tier ladder. Marlowe's shelf is a choice and its
    /// rows are named for what the choice is about; Sebastian's is not — the
    /// device decides — so his rows are named for who they are: one companion,
    /// with more or less of him on the phone.
    test('the fallback is Jr. and everything above it is Sr.', () {
      expect(
        sebastianTierName(BrainCatalog.sebastianFallback),
        'Sebastian Jr.',
      );
      for (final brain in BrainCatalog.sebastianBrains) {
        if (brain.id == BrainCatalog.sebastianFallback.id) continue;
        expect(sebastianTierName(brain), 'Sebastian Sr.', reason: brain.id);
      }
    });

    /// Names, not labels. Routing these through l10n would have a name change
    /// language when the UI did, which is the argument
    /// [Companion.displayName] already makes.
    test('and they carry his name', () {
      for (final brain in BrainCatalog.sebastianBrains) {
        expect(
          sebastianTierName(brain),
          startsWith(Companion.sebastian.displayName),
        );
      }
    });
  });

  group('which brain this device gets', () {
    tearDown(() => DeviceCapability.instance.setRamForTest(null));

    /// The whole point of the gate. A phone that cannot hold 1.5 GB of weights
    /// beside a chat transcript does not degrade — the platform terminates the
    /// app, which the user experiences as a crash and cannot connect to a model
    /// they were never asked about.
    test('a small device is not offered a brain it cannot hold', () {
      DeviceCapability.instance.setRamForTest(2048);
      final big = BrainCatalog.sebastianBrains.first;
      expect(DeviceCapability.instance.canRun(big), isFalse);
      expect(
        DeviceCapability.instance.canRun(BrainCatalog.sebastianFallback),
        isTrue,
      );
    });

    test('a large device is', () {
      DeviceCapability.instance.setRamForTest(8192);
      for (final brain in BrainCatalog.sebastianBrains) {
        expect(DeviceCapability.instance.canRun(brain), isTrue,
            reason: brain.id);
      }
    });

    /// Unknown resolves DOWNWARD, and that direction is the whole safety
    /// argument: an unreadable platform costs a slightly worse translation
    /// rather than a crash.
    test('an unsizeable device is treated as the smallest one', () {
      DeviceCapability.instance.setRamForTest(null);
      expect(
        DeviceCapability.instance.canRun(BrainCatalog.sebastianBrains.first),
        isFalse,
      );
    });

    /// Exactly at the floor counts as meeting it. Stated because `>` and `>=`
    /// are one character apart and the difference is a whole tier of phones.
    test('a device exactly at the floor meets it', () {
      final big = BrainCatalog.sebastianBrains.first;
      DeviceCapability.instance.setRamForTest(big.minRamMb);
      expect(DeviceCapability.instance.canRun(big), isTrue);
    });

    /// A brain with no stated floor is one every supported device can carry,
    /// and must not be gated by a machine this cannot size.
    test('a brain with no floor runs anywhere, even unsized', () {
      DeviceCapability.instance.setRamForTest(null);
      const unbounded = BrainSpec(
        id: 'x',
        label: 'x',
        fileName: 'x.litertlm',
        url: 'https://example.com/x.litertlm',
        sizeBytes: 1,
        sha256: 'x',
        family: BrainFamily.qwen2,
        contextTokens: 1024,
        license: 'Apache 2.0',
      );
      expect(DeviceCapability.instance.canRun(unbounded), isTrue);
    });
  });

  group('weights no brain on the shelf claims', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('brain_catalog_test');
      PathProviderPlatform.instance = _TmpPathProvider(tmp.path);
      BrainStore.instance.resetForTest();
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<File> place(String name, int bytes) async {
      final dir = Directory('${tmp.path}/companions/brains');
      await dir.create(recursive: true);
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(List.filled(bytes, 0));
      return f;
    }

    /// The gap this closes, and it is live for every installed user right now.
    /// Sebastian shipped on Qwen3-0.6B; moving him to Qwen2 took that brain out
    /// of `BrainCatalog.all`, which is what every screen, every install state
    /// and every delete path iterates. Nothing could attribute the file and
    /// nothing offered to remove it — while `bytesUsed` walks the DIRECTORY and
    /// went on counting all 328 MB of it.
    test('a brain that left the catalog is deleted', () async {
      await place('Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm', 2048);

      final freed = await BrainStore.instance.sweepUnclaimed();

      expect(freed, 2048);
      expect(await BrainStore.instance.bytesUsed(), 0);
    });

    /// Its half-finished download and its resume note go with it. A `.part`
    /// is the larger of the three often enough to matter — a download
    /// abandoned at 90% of 2.6 GB is most of a brain.
    test('so are its partial and its resume note', () async {
      const gone = 'SomeRetiredBrain.litertlm';
      await place(gone, 1024);
      await place('$gone.part', 4096);
      await place('$gone.resume', 64);

      expect(await BrainStore.instance.sweepUnclaimed(), 1024 + 4096 + 64);
      expect(await BrainStore.instance.bytesUsed(), 0);
    });

    /// Derived rather than listed, which is the whole point: a release that
    /// retires a brain and forgets to write its name down anywhere still
    /// reclaims the disk. Nothing here knows what this file was called.
    test('including one nobody wrote down anywhere', () async {
      await place('a_model_from_2024_nobody_remembers.litertlm', 8192);
      expect(await BrainStore.instance.sweepUnclaimed(), 8192);
    });

    /// The counterpart risk, and the one that would be unforgivable: an
    /// installed brain, or the partial of a download in flight, swept away by
    /// a refresh that happened to run at the wrong moment.
    test('leaves every live brain, partial and resume note alone', () async {
      var expected = 0;
      for (final brain in BrainCatalog.all) {
        await place(brain.fileName, 512);
        await place('${brain.fileName}.part', 256);
        await place('${brain.fileName}.resume', 32);
        expected += 512 + 256 + 32;
      }

      expect(await BrainStore.instance.sweepUnclaimed(), 0);
      expect(await BrainStore.instance.bytesUsed(), expected);
    });

    /// Mixed, which is the real upgrade: the new brain half-downloaded beside
    /// the old one it replaces.
    test('keeps the new brain while reclaiming the old', () async {
      final live = BrainCatalog.sebastianFallback.fileName;
      await place('$live.part', 4096);
      await place('Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm', 2048);

      expect(await BrainStore.instance.sweepUnclaimed(), 2048);
      expect(await BrainStore.instance.bytesUsed(), 4096);
    });

    test('sweeping an empty or absent directory is not an error', () async {
      expect(await BrainStore.instance.sweepUnclaimed(), 0);
      await place('x.litertlm', 1);
      await BrainStore.instance.sweepUnclaimed();
      expect(await BrainStore.instance.sweepUnclaimed(), 0);
    });
  });
}

class _TmpPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TmpPathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}
