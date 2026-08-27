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
    this.minRamMb,
    this.languages,
  });

  /// Stable key. Persisted in settings (Marlowe's chosen brain) and used as the
  /// dedup key when two companions want the same weights — see
  /// [BrainCatalog.companionsUsing], which is the one place sharing is decided.
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

  /// The languages this brain's publisher lists, or null for a general model
  /// that names no set.
  ///
  /// Null is not "all", it is "unstated" — a general instruct model has no
  /// published translation set and pretending otherwise would be inventing a
  /// claim. Either way [covers] treats an unstated set as no objection: the
  /// list is used to warn, never to forbid, because a language a model does not
  /// advertise is not the same as one it cannot read, and refusing on that
  /// basis would remove translation from readers who currently have it.
  final List<String>? languages;

  /// Whether [languageCode] is one this brain's publisher lists.
  bool covers(String languageCode) =>
      languages == null || languages!.contains(languageCode);

  /// Physical RAM this brain wants before anyone should try to load it, or null
  /// for one every supported device can carry.
  ///
  /// Not a download check — that is [sizeBytes] against free disk. This is
  /// about what happens AFTER: weights are mapped resident alongside a chat
  /// transcript and its images, and a device that cannot hold both does not
  /// degrade, it gets its app terminated by the platform. Read by
  /// [DeviceCapability.canRun], which answers false whenever the machine is
  /// unknown.
  final int? minRamMb;

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

  /// Hunyuan-MT — Apache 2.0, and not a chat model at all.
  ///
  /// It is a TRANSLATION model: `pipeline_tag: translation`, tuned to follow
  /// translation instructions rather than to converse. That is the whole reason
  /// it is here. Every failure this feature has fought — the preamble, the
  /// reasoning trace, the label, the instruction handed back instead of obeyed
  /// — is a chat model doing what chat models do, and each one had to be
  /// stripped, refused or prompted away. A model that was never trained to
  /// chat has no such surface.
  ///
  /// Two consequences that are not cosmetic, both handled in
  /// [TranslationPrompt]:
  ///
  ///  * it has NO default system prompt, and its instruction goes in the turn;
  ///  * it has its own instruction wording, which it was trained on. Matching
  ///    the training format is the single biggest lever on what comes back, so
  ///    this family does not get the fenced turn the chat families get.
  hunyuan,
}

/// The shelf.
abstract final class BrainCatalog {
  /// Sebastian's shelf, BEST FIRST.
  ///
  /// Two rows and no picker. Which one runs is decided by the device — see
  /// [DeviceCapability] — because "how much model can this handset hold" is a
  /// real question with a knowable answer, and it is not one the person who
  /// wanted a translated bubble should be asked. See
  /// [Companion.brainsAreUserChosen]: he is installed, not configured.
  ///
  /// ── Why neither of these is Qwen3, which he shipped on ────────────────
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
  /// Both rows below are Qwen2.x Instruct: no reasoning mode to suppress, no
  /// `/no_think` to hope is honoured, no channel markers. The failure class is
  /// gone rather than filtered. Both are ChatML, which `ModelType.qwen` handles
  /// — and that matters more than it sounds on iOS, where `.litertlm` applies
  /// the chat template MANUALLY and a family the plugin does not recognise is
  /// exactly how a device ends up rendering control tokens as text.
  static const List<BrainSpec> sebastianBrains = [
    // A translation model, not a chat model talked into behaving like one.
    //
    // Tencent's Hunyuan-MT at 1.8B, converted to LiteRT-LM. 33 languages,
    // Apache 2.0, ungated. `pipeline_tag: translation` is the entire argument:
    // every bug this feature has shipped — the preamble, the reasoning trace,
    // the echoed example, the instruction handed back instead of obeyed — was a
    // chat model doing what chat models do. The contract catches them and will
    // go on catching them; this is the change that stops manufacturing them.
    //
    // ── The two things it costs ─────────────────────────────────────────
    //
    // Seven of the thirty languages this app offers are outside its published
    // set: Swedish, Greek, Romanian, Hungarian, Danish, Finnish, Norwegian.
    // They are NOT removed from the picker — Swedish is one of the app's own UI
    // locales, and a Swedish reader losing translation would be a worse
    // regression than a weaker one. Unlisted is not the same as broken, and a
    // bad answer is refused by [TranslationPrompt.verify] rather than shown.
    // `tool/`'s golden set is where that stops being an assumption.
    //
    // And flutter_gemma has no Hunyuan `ModelType`. On iOS `.litertlm` applies
    // the chat template MANUALLY, so this family gets `ModelType.general`'s
    // Gemma turn markers around a prompt that wants none. Survivable, and
    // measured rather than hoped: the markers are already in `_controlToken`,
    // and Hy-MT2's own documented usage is a PLAIN prompt with no chat template
    // at all — so stray markers are noise around an instruction it can still
    // read, not a format it cannot parse.
    BrainSpec(
      id: 'hy-mt2-1.8b',
      label: 'Translator',
      fileName: 'Hy-MT2-1.8B_int8.litertlm',
      url: 'https://huggingface.co/litert-community/Hy-MT2-1.8B/'
          'resolve/main/Hy-MT2-1.8B_int8.litertlm',
      sizeBytes: 1815622960,
      sha256: '7bbd0b65d7e69c8d92b8ab3033e353536ef40c77f4dc5f4c32f2931417c13eda',
      family: BrainFamily.hunyuan,
      // The bundle carries a 4096 window; 2048 is what a chat message plus its
      // translation needs several times over, and every token of unused window
      // is memory held on a phone that is also running a chat.
      contextTokens: 2048,
      license: 'Apache 2.0',
      minRamMb: 4096,
      // The 33 its card publishes. Seven of the thirty this app offers are
      // outside it — sv, el, ro, hu, da, fi, no — and they stay in the picker
      // with a note rather than being removed: Swedish is one of this app's own
      // UI locales, and a Swedish reader losing translation outright is a worse
      // regression than a weaker one.
      languages: [
        'zh', 'en', 'fr', 'pt', 'es', 'ja', 'tr', 'ru', 'ar', 'ko', 'th',
        'it', 'de', 'vi', 'ms', 'id', 'tl', 'hi', 'pl', 'cs', 'nl', 'km',
        'my', 'fa', 'gu', 'ur', 'te', 'mr', 'he', 'bn', 'ta', 'uk', 'bo',
        'kk', 'mn', 'ug',
      ],
    ),
    // The one everything can run, and what a device of unknown size gets: see
    // [DeviceCapability], where every failure resolves downward.
    //
    // Still a chat model, because there is no translation-tuned model at this
    // size in this format — so it keeps the fenced turn, the worked examples
    // and the whole contract that exists to talk a chat model out of chatting.
    //
    // Qwen2 rather than Qwen2.5 for a boring reason:
    // `litert-community/Qwen2.5-0.5B-Instruct` ships `.task` only, which is
    // MediaPipe, and the engine here is LiteRT-LM (see the pubspec).
    BrainSpec(
      id: 'qwen2-0.5b-instruct',
      // Never rendered — Sebastian's screen shows his own name, not a tier.
      label: 'Translator',
      fileName: 'Qwen2_0.5B_Instruct.litertlm',
      url: 'https://huggingface.co/litert-community/Qwen2-0.5B-Instruct/'
          'resolve/main/Qwen2_0.5B_Instruct.litertlm',
      sizeBytes: 647377840,
      sha256: '0f01cc004b8eb62b92ba6be85ed05a248ba0d2f78af94c4949b313eccfb4c157',
      family: BrainFamily.qwen2,
      contextTokens: 2048,
      license: 'Apache 2.0',
      minRamMb: 2048,
    ),
  ];

  /// The row every supported device can carry, and the answer whenever the
  /// machine cannot be sized. Last, because the shelf is ordered best-first.
  static BrainSpec get sebastianFallback => sebastianBrains.last;

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
        Companion.sebastian => sebastianBrains,
        Companion.marlowe => marloweBrains,
      };
}
