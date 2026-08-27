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
    required this.sha256,
    required this.family,
    required this.contextTokens,
    required this.license,
  });

  /// Stable key. Persisted in settings (Marlowe's chosen brain) and used as the
  /// dedup key when two companions want the same weights — see
  /// [BrainCatalog.sebastianBrain], which is also the first row of Marlowe's
  /// shelf, so installing one gives the other a brain for free.
  final String id;

  /// What Marlowe's shelf calls it. NOT shown for Sebastian anywhere — see
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

  /// SHA-256 of the finished file, lower-case hex.
  ///
  /// Taken from HuggingFace's git-lfs `oid`, which IS the content digest — not
  /// from the HTTP `ETag`, which for these files is a different hash of
  /// something else entirely (measured: the CDN returns
  /// `02cf17…` where the lfs oid is `e3e290…`). Pinning it here rather than
  /// trusting a header at runtime is the point: it is a claim this build
  /// makes about what it expects, checkable against a file the network
  /// produced.
  ///
  /// [BrainDownload] verifies it once, after the last byte. That is the only
  /// check that catches a resume which reconnected at the wrong offset —
  /// right length, wrong contents — and it is what makes a download resumed
  /// across three sessions as trustworthy as one taken in a single sitting.
  final String sha256;

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
  /// Qwen2 — Apache 2.0, ChatML, 29 languages, and — the property that matters
  /// most here — NOT a reasoning model. It has no thinking mode to suppress,
  /// no `<think>` block, and no harmony channel markers, so the entire class of
  /// failure that [qwen3] has to be talked out of simply does not exist.
  ///
  /// The same template family a sibling project runs in production through
  /// `ModelType.qwen`, which is worth more than it sounds on iOS: `.litertlm`
  /// applies the chat template MANUALLY there, and a family the plugin does not
  /// recognise is exactly how a device ends up rendering control tokens as
  /// text.
  qwen2,

  /// Qwen3 — Apache 2.0, trained on 100+ languages, and a HYBRID REASONING
  /// model, which is the trap. Its multilingual coverage at 0.6B is genuinely
  /// rare and it is why Sebastian started here; its thinking mode is why he
  /// left. `/no_think` is a soft switch and `enableThinking: false` is honoured
  /// by the runtime rather than the weights, so neither is a guarantee — and
  /// what a real device produced was a channel marker between every token:
  ///
  ///     Okay<|channel|>thought,<|channel|>thought let<|channel|>thought's…
  ///
  /// Kept because Marlowe's shelf still uses it, where an open-ended companion
  /// showing its working is a feature rather than a bug.
  qwen3,

  /// Gemma 4 — Apache 2.0 on the litert-community bundles. No thinking
  /// preamble by default.
  gemma,
}

/// The shelf.
abstract final class BrainCatalog {
  /// Sebastian's brain, and the only one he will ever load.
  ///
  /// Qwen2-0.5B-Instruct at int8, 617 MB.
  ///
  /// ── Why this is not Qwen3, which it used to be ────────────────────────
  ///
  /// Qwen3-0.6B was chosen for multilingual coverage at 328 MB, and that
  /// argument was correct. What it missed is that Qwen3 is a hybrid REASONING
  /// model, and this is the one task where a model that likes to show its
  /// working is disqualified: the whole requirement is "emit the translation
  /// and nothing else".
  ///
  /// It was not close. Bubbles carried "Okay, I need to translate this",
  /// `<think>` blocks the runtime flag did not suppress, and finally a decode
  /// with a harmony channel marker between EVERY token, which reached readers
  /// as `,thought letthought's thought tacklethought this`. Each of those got a
  /// stripper, and the strippers worked, and the next shape arrived. That is
  /// what fighting a model's nature looks like.
  ///
  /// Qwen2 has no reasoning mode at all. There is no thinking to suppress, no
  /// `/no_think` to hope is honoured, and no channel markers — the failure
  /// class is gone rather than filtered. It is an older and individually weaker
  /// model, and it is the right one: a slightly clumsier translation that
  /// always arrives beats a better one that arrives four times out of five.
  ///
  /// ── Why not Qwen2.5, which is better still ────────────────────────────
  ///
  /// Because it does not exist in the format this app can load.
  /// `litert-community/Qwen2.5-0.5B-Instruct` ships `.task` only — MediaPipe —
  /// and the engine here is LiteRT-LM for the reason written in the pubspec.
  /// The 1.5B does ship `.litertlm`, at 1.49 GB, which is four and a half times
  /// this download for a translator inside a chat app.
  ///
  /// The cost of the move is honest: 617 MB against 328. It is still inside
  /// "smaller than a couple of podcasts", which is the ceiling this feature has
  /// always been sized against.
  static const BrainSpec sebastianBrain = BrainSpec(
    id: 'qwen2-0.5b-instruct',
    // Never rendered — Sebastian's screen shows his own name, not a tier. It
    // is a debug fallback, so it says what this brain is FOR rather than
    // borrowing a tier name from Marlowe's ladder.
    label: 'Translator',
    fileName: 'Qwen2_0.5B_Instruct.litertlm',
    url: 'https://huggingface.co/litert-community/Qwen2-0.5B-Instruct/'
        'resolve/main/Qwen2_0.5B_Instruct.litertlm',
    sizeBytes: 647377840,
    sha256: '0f01cc004b8eb62b92ba6be85ed05a248ba0d2f78af94c4949b313eccfb4c157',
    family: BrainFamily.qwen2,
    contextTokens: 2048,
    license: 'Apache 2.0',
  );

  /// Marlowe's shelf, smallest first.
  ///
  /// ── Why this floor is 1.7B and not Sebastian's 0.6B ───────────────────
  ///
  /// This shelf used to open with Sebastian's own brain, so that installing
  /// either companion gave the other one free. It was a tidy trick and it was
  /// the wrong call twice over.
  ///
  /// The one that matters is about capability, not disk. 0.6B is enough for
  /// TRANSLATION because translation is a constrained task — the answer is
  /// determined by the input, and the model is transforming rather than
  /// deciding. Open-ended assistance is the opposite: at 0.6B it invents
  /// things confidently, and shipping that as Marlowe's entry tier would mean the
  /// first impression is of a companion who makes things up. A tier nobody
  /// should pick is not a tier.
  ///
  /// The second reason is that the sharing was invisible. Installing Sebastian
  /// silently ticked a row on Marlowe's shelf; removing him from HIS screen
  /// silently took that brain away. Nothing on either screen said the two were
  /// the same file. See [companionsUsing], which is what any future overlap
  /// has to go through.
  static const List<BrainSpec> marloweBrains = [
    BrainSpec(
      id: 'qwen3-1.7b-int4',
      label: 'Swift',
      fileName: 'Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm',
      url: 'https://huggingface.co/litert-community/Qwen3-1.7B/resolve/main/'
          'Qwen3-1.7B_dynamic_wi4b32_afp32.litertlm',
      sizeBytes: 977184032,
    sha256: '2eeffef7b51bc3e1225ea69fe7aa5f417397934b56a5b6c20cc068d6fd2c918b',
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
    sha256: 'a53a59001894c58e6bdb5b9b227709f91a2e3e556baa7d85acf9c55402ba5cf5',
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
    sha256: '176b5a2b6c20bde7739fba98e653a04f5d5b4a753a4b9dd0ff529aba7c35be99',
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
        Companion.marlowe => marloweBrains,
      };
}
