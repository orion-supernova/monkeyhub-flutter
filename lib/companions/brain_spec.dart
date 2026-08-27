/// What a companion downloads in order to think, and the shelf of them.
///
/// ── Why the catalog is a constant and not a fetch ──────────────────────────
///
/// The obvious design is a manifest on the server, so brains can be added
/// without shipping a build. This deliberately isn't that, for two reasons
/// that both outrank the convenience:
///
///  * A remote manifest is a remote instruction to download two gigabytes to
///    the user's phone. Whatever else this feature is, it should not be a
///    channel through which the backend can decide to fill someone's storage.
///  * The whole promise of a companion is that it runs on the device and
///    nothing leaves it. A feature that has to phone home before it can offer
///    to be private is telling on itself.
///
/// So the shelf ships with the app, pinned to exact URLs and exact byte counts
/// (measured, not rounded — see [BrainSpec.sizeBytes]), and adding a brain is
/// a release.
library;

import 'companion.dart';

/// One downloadable model, described in the terms the UI actually needs.
///
/// Everything the inference plugin needs to *fetch and run* it lives here too,
/// but only [BrainGateway] reads those fields — nothing in `lib/screens` or
/// `lib/widgets` should ever see [url] or [fileName].
class BrainSpec {
  const BrainSpec({
    required this.id,
    required this.label,
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.family,
    required this.contextTokens,
    required this.license,
  });

  /// Stable key. Persisted in settings (Vera's chosen brain) and used as the
  /// dedup key when two companions want the same weights — see
  /// [BrainCatalog.sebastianBrain], which is also the first row of Vera's
  /// shelf, so installing him gives her a brain for free and vice versa.
  final String id;

  /// What Vera's shelf calls it. NOT shown for Sebastian anywhere — see
  /// [Companion.brainsAreUserChosen].
  ///
  /// A plain human tier ("Swift", "Balanced", "Deep") rather than the model's
  /// real name, because the real name is not information: nobody choosing
  /// between a 328 MB download and a 1.9 GB one is helped by knowing one of
  /// them is called Qwen. The real name is still available — see
  /// [technicalName], which the detail screen prints in small type for the
  /// people who do want it.
  final String label;

  /// On-disk file name, which the plugin also uses as the model's identity for
  /// `isModelInstalled` / `uninstallModel`. Must end in `.litertlm`: the
  /// engine registered in [BrainGateway] is LiteRT-LM, and handing it a
  /// MediaPipe `.task` fails at load rather than at download — an hour later
  /// and a gigabyte heavier.
  final String fileName;

  /// Direct download. HuggingFace `resolve/main/...`, verified UNGATED at the
  /// time of writing.
  ///
  /// Gating is the thing to re-check when adding a row here, and it is not
  /// visible from the URL: `litert-community/Gemma3-1B-IT` looks identical to
  /// its neighbours and returns 401 without an account. Every brain on this
  /// shelf resolves anonymously, which is what lets the install flow be one
  /// button and no sign-in.
  final String url;

  /// Exact content-length, in bytes, taken from the CDN rather than estimated.
  ///
  /// Exact because it is spent twice: once as the number in "328 MB" (a
  /// download the user is agreeing to, so it should be the truth), and once as
  /// the free-space precheck. A rounded-down guess turns a refusal we could
  /// have made politely into a disk-full failure 90% of the way through.
  final int sizeBytes;

  /// Which prompt dialect to speak. See [BrainFamily].
  final BrainFamily family;

  /// KV-cache budget to open the model with — input AND output together, not
  /// the reply length.
  ///
  /// 1024 is the floor LiteRT-LM will allocate at all, so nothing here goes
  /// below it. Sebastian runs at exactly 2048 because a chat message plus its
  /// translation plus the instruction fits several times over, and every token
  /// of unused window is memory held on a phone that is also running a chat.
  final int contextTokens;

  /// Shown in full on the detail screen. All rows are permissive commercial
  /// licences; this is here so that stays checkable rather than remembered.
  final String license;

  /// The model's actual name, for the one line of small print that admits it.
  ///
  /// Derived rather than stored: the file name already carries it, and two
  /// fields that must agree are one field and a bug.
  String get technicalName => fileName.replaceAll('.litertlm', '');

  /// `328 MB`. Binary megabytes, matching what every OS storage screen shows,
  /// so "328 MB" here and "328 MB" in iOS Settings are the same number.
  String get sizeLabel {
    const mib = 1024 * 1024;
    if (sizeBytes >= 1024 * mib) {
      return '${(sizeBytes / (1024 * mib)).toStringAsFixed(1)} GB';
    }
    return '${(sizeBytes / mib).round()} MB';
  }
}

/// Which chat template and which quirks.
///
/// Not cosmetic: Qwen3 emits `<think>…</think>` unless told not to, and a
/// translated bubble that opens with the model's reasoning is a broken
/// feature. [TranslationPrompt] switches on this.
enum BrainFamily {
  /// Qwen3 — Apache 2.0, and the reason Sebastian is any good: the family is
  /// trained on 100+ languages, which is a rare property at 0.6B. Emits
  /// thinking traces unless suppressed.
  qwen3,

  /// Gemma 4 — Apache 2.0 on the litert-community bundles. No thinking
  /// preamble by default.
  gemma,
}

/// The shelf.
abstract final class BrainCatalog {
  /// Sebastian's brain, and the only one he will ever load.
  ///
  /// Qwen3 0.6B at int4/block-32, 328 MB. The size is the whole argument: this
  /// is a translation feature inside a chat app, and the honest ceiling on what
  /// a person will accept for it is "smaller than a couple of podcasts". A 1.7B
  /// model translates better and would not get installed.
  ///
  /// Qwen3 rather than the obvious Gemma 3 1B for two independent reasons.
  /// Multilingual coverage is the first — Gemma 3 1B is heavily English-tilted
  /// and this is a feature for people who are not reading English. The second
  /// is decisive on its own: `litert-community/Gemma3-1B-IT` is a GATED repo.
  /// It would put a HuggingFace account between the user and a translated
  /// message.
  static const BrainSpec sebastianBrain = BrainSpec(
    id: 'qwen3-0.6b-int4',
    // Never rendered — Sebastian's screen shows his own name, not a tier. It
    // is a debug fallback, so it says what this brain is FOR rather than
    // borrowing a tier name from Vera's ladder, where 'Swift' now means
    // something four times the size.
    label: 'Translator',
    fileName: 'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
    url: 'https://huggingface.co/litert-community/Qwen3-0.6B/resolve/main/'
        'Qwen3-0.6B_dynamic_wi4b32_afp32.litertlm',
    sizeBytes: 344437808,
    family: BrainFamily.qwen3,
    contextTokens: 2048,
    license: 'Apache 2.0',
  );

  /// Vera's shelf, smallest first.
  ///
  /// ── Why her floor is 1.7B and not Sebastian's 0.6B ────────────────────
  ///
  /// This shelf used to open with Sebastian's own brain, so that installing
  /// either companion gave the other one free. It was a tidy trick and it was
  /// the wrong call twice over.
  ///
  /// The one that matters is about capability, not disk. 0.6B is enough for
  /// TRANSLATION because translation is a constrained task — the answer is
  /// determined by the input, and the model is transforming rather than
  /// deciding. Open-ended assistance is the opposite: at 0.6B it invents
  /// things confidently, and shipping that as Vera's entry tier would mean her
  /// first impression is of a companion who makes things up. A tier nobody
  /// should pick is not a tier.
  ///
  /// The second reason is that the sharing was invisible. Installing Sebastian
  /// silently ticked a row on Vera's shelf; removing him from HIS screen
  /// silently took her brain away. Nothing on either screen said the two were
  /// the same file. See [companionsUsing], which is what any future overlap
  /// has to go through.
  static const List<BrainSpec> veraBrains = [
    BrainSpec(
      id: 'qwen3-1.7b-int4',
      label: 'Swift',
      fileName: 'Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm',
      url: 'https://huggingface.co/litert-community/Qwen3-1.7B/resolve/main/'
          'Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm',
      sizeBytes: 977184032,
      family: BrainFamily.qwen3,
      contextTokens: 4096,
      license: 'Apache 2.0',
    ),
    // The `-gpu` bundle, not the plain one: 1.9 GB against 2.4 GB, and the
    // difference is weights laid out for the accelerator this engine will
    // actually reach for on every platform it supports. Paying 500 MB to be
    // slower would be a strange trade.
    BrainSpec(
      id: 'gemma-4-e2b',
      label: 'Balanced',
      fileName: 'gemma-4-E2B-it-gpu.litertlm',
      url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/'
          'resolve/main/gemma-4-E2B-it-gpu.litertlm',
      sizeBytes: 2008432640,
      family: BrainFamily.gemma,
      contextTokens: 4096,
      license: 'Apache 2.0',
    ),
    BrainSpec(
      id: 'qwen3.5-4b-int4',
      label: 'Deep',
      fileName: 'Qwen3.5-4B_mixed_int4.litertlm',
      url: 'https://huggingface.co/litert-community/Qwen3.5-4B/resolve/main/'
          'Qwen3.5-4B_mixed_int4.litertlm',
      sizeBytes: 2754365536,
      family: BrainFamily.qwen3,
      contextTokens: 4096,
      license: 'Apache 2.0',
    ),
  ];

  /// Every distinct brain any companion can ask for, each appearing once.
  ///
  /// De-duplicated by id rather than assumed distinct: this is what the
  /// storage total is summed over, and a brain two companions shared would
  /// otherwise be counted twice and report a number that does not match the
  /// OS storage screen.
  static List<BrainSpec> get all {
    final seen = <String>{};
    return [
      for (final companion in Companion.values)
        for (final brain in forCompanion(companion))
          if (seen.add(brain.id)) brain,
    ];
  }

  /// Which companions can load [spec] — the one place sharing is decided.
  ///
  /// Derived from [forCompanion] rather than stored, so it cannot disagree
  /// with what the shelves actually offer. Every delete guard and every
  /// "also used by" line reads this, which means a future catalog CAN share a
  /// brain between two companions and the UI will handle it — the thing that
  /// went wrong before was not the sharing, it was that nothing modelled it.
  static List<Companion> companionsUsing(BrainSpec spec) => [
        for (final companion in Companion.values)
          if (forCompanion(companion).any((b) => b.id == spec.id)) companion,
      ];

  static BrainSpec? byId(String? id) {
    if (id == null) return null;
    for (final b in all) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// What [companion] is allowed to load. Sebastian's list is exactly one, and
  /// the UI never renders it as a list.
  static List<BrainSpec> forCompanion(Companion companion) =>
      switch (companion) {
        Companion.sebastian => const [sebastianBrain],
        Companion.vera => veraBrains,
      };
}
