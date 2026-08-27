/// The only test in this repo that needs a real language model.
///
/// ── What it is for ─────────────────────────────────────────────────────────
///
/// Sebastian runs Qwen3-0.6B, which is a hybrid REASONING model — close to the
/// worst family available for a task whose whole requirement is "emit the
/// answer and nothing else". It was chosen for its multilingual coverage at
/// 328 MB, which is a real argument, and it may still be the right choice. The
/// point of this file is that the question stops being answered by argument.
///
/// It runs the shipped pipeline over `test/fixtures/translation_golden.json`
/// and prints pass rate, preamble-leak rate, wrong-language rate, first-try
/// rate and mean latency. Run it against the incumbent, record the numbers,
/// then run it against a candidate brain and compare. A swap is justified when
/// a candidate wins on preamble leak AND wrong language; a slightly clumsier
/// translation that never narrates itself is the better product.
///
/// ── How to run it ──────────────────────────────────────────────────────────
///
///     flutter test integration_test/translation_eval_test.dart -d <device>
///
/// It needs Sebastian's brain already on the device and will skip loudly
/// otherwise — downloading 328 MB from inside a test is not a thing a test
/// should do to somebody's connection.
///
/// It is NOT part of `flutter test`. The contract this feature has to keep is
/// asserted without a model in `test/translation_contract_test.dart`, which is
/// what runs in CI; a suite that needed a third of a gigabyte to start is a
/// suite nobody runs.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:monkeyhub/companions/brain_gateway.dart';
import 'package:monkeyhub/companions/brain_spec.dart';
import 'package:monkeyhub/companions/sebastian.dart';
import 'package:monkeyhub/companions/translation/language.dart';

import '../test/support/translation_eval.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('golden set', (tester) async {
    final brain = BrainCatalog.sebastianBrain;

    if (!await BrainGateway.instance.isInstalled(brain)) {
      // Not a failure. The brain is a 328 MB download the user opted into, and
      // a machine that does not have it cannot answer this question — which is
      // different from answering it badly.
      debugPrint(
        'SKIPPED: ${brain.id} is not installed on this device.\n'
        'Install Sebastian from Settings › Companions and run this again.',
      );
      return;
    }

    final cases = GoldenCase.load();
    debugPrint('Running ${cases.length} cases against ${brain.id}…');

    final outcomes = <CaseOutcome>[];
    for (var i = 0; i < cases.length; i++) {
      final golden = cases[i];
      final started = DateTime.now();
      final run = await Sebastian.instance.runOnce(
        golden.source,
        languageForCode(golden.target)!,
      );
      outcomes.add(
        scoreCase(
          golden,
          run.text,
          elapsed: DateTime.now().difference(started),
          attempts: run.attempts,
        ),
      );

      // Progress, because a hundred generations on a phone is minutes and a
      // silent test looks like a hung one.
      if ((i + 1) % 10 == 0) {
        debugPrint('  ${i + 1}/${cases.length}');
      }
    }

    final report = EvalReport(brain.id, outcomes);
    debugPrint('\n${report.format()}');

    // Every refusal, so a regression can be read rather than guessed at. The
    // SOURCE is a fixture in this repo and the OUTPUT came from a fixture, so
    // there is nothing private here — which is exactly why the app's own
    // logging prints only the verdict.
    final failed = outcomes.where((o) => !o.passed).toList();
    if (failed.isNotEmpty) {
      debugPrint('── refusals ──────────────────────────────────────');
      for (final o in failed) {
        debugPrint('[${o.failure!.name}] ${o.golden.pair}  '
            '${o.golden.source}\n   → ${o.output ?? '(nothing)'}');
      }
    }

    await BrainGateway.instance.unload();

    // A floor, not a target. It is set where it is so the harness itself fails
    // loudly if the pipeline breaks outright — a wiring mistake that refuses
    // everything should not look like a quiet benchmark run. Raise it once
    // there is a recorded baseline to raise it to.
    expect(
      report.passRate,
      greaterThan(0.5),
      reason: 'fewer than half the golden set survived the contract:\n'
          '${report.format()}',
    );
  }, timeout: const Timeout(Duration(minutes: 30)));
}
