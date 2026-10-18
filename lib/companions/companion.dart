/// Who lives on this device.
///
/// ── Why companions are people and not features ─────────────────────────────
///
/// "On-device LLM translation" is a sentence about engineering. "Sebastian
/// translates this for you, and never sends it anywhere" is a sentence about a
/// promise, and the promise is the whole product: the reason this app runs a
/// 328 MB model on the phone instead of calling an API is that a private
/// message stops being private the moment it leaves the handset.
///
/// So the user never meets a model picker, a quantisation, or the words
/// "LiteRT-LM". They meet Sebastian, who reads languages, Bartleby, who
/// writes down voice messages, and Marlowe, who will learn to do more. What each of them needs in order to think is
/// [BrainSpec]'s business, and it is deliberately not on screen for Sebastian
/// at all — see [Companion.brainsAreUserChosen].
///
/// Adding a companion is adding a member of this enum plus a catalog entry.
/// Everything else — install flow, storage accounting, the settings rows, the
/// "not installed yet" sheet — reads off this table.
library;

import 'package:flutter/widgets.dart';

import '../l10n/generated/app_localizations.dart';

/// The residents. Stable wire names: [id] is persisted in settings and in the
/// brain manager's on-disk bookkeeping, so renaming a member renames a key.
enum Companion {
  /// The translator. One job, and it is the one this subsystem shipped for.
  ///
  /// Sebastian is deliberately single-brained: he is installed, not
  /// configured. A user who wants a translated bubble is not shopping for a
  /// language model, and offering them the choice would be offering them a
  /// decision they have no way to make well.
  sebastian,

  /// The generalist. Multi-brained on purpose — the size/quality trade is a
  /// real one once the task is open-ended, and unlike translation it is a
  /// trade the user can actually feel.
  ///
  /// His skills are still arriving; what ships today is his brain shelf. That
  /// is honest rather than empty: a 932 MB download is something you want to
  /// have started before you need it, and his detail screen says exactly that
  /// rather than implying a chat window exists.
  marlowe,

  /// The scribe. Listens to voice messages and writes them down.
  ///
  /// Not a brain on the shelf: he works with the OS's own recognizer where it
  /// already knows the language, and with one speech model (see
  /// `TranscriptModel`) when the reader wants every language. So
  /// [usesBrains] is false and his screen is `BartlebyScreen`, not a shelf.
  ///
  /// Named for Melville's scrivener, the copyist who "would prefer not to".
  /// What this one would prefer not to do is send anything anywhere.
  bartleby;

  /// Persisted key. Never derived from [name] at the call site so a future
  /// rename is a one-line migration here instead of silent data loss.
  String get id => switch (this) {
        Companion.sebastian => 'sebastian',
        Companion.marlowe => 'marlowe',
        Companion.bartleby => 'bartleby',
      };

  static Companion? parse(String? s) => switch (s) {
        'sebastian' => Companion.sebastian,
        'marlowe' => Companion.marlowe,
        'bartleby' => Companion.bartleby,
        _ => null,
      };

  /// Proper noun — the same in every locale, like [AppLocalizations.splashBrand].
  /// Not routed through l10n for exactly that reason: a name that changed
  /// language when the UI did would stop being a name.
  String get displayName => switch (this) {
        Companion.sebastian => 'Sebastian',
        Companion.marlowe => 'Marlowe',
        Companion.bartleby => 'Bartleby',
      };

  /// Whether the brain shelf is the user's to arrange.
  ///
  /// False for Sebastian, and that is the design rather than an omission: his
  /// brain is chosen for him — by the DEVICE, from
  /// [BrainCatalog.sebastianBrains] via [DeviceCapability] — and never
  /// named on screen. True for Marlowe, whose whole detail screen is the shelf.
  bool get brainsAreUserChosen => this == Companion.marlowe;

  /// Whether this companion thinks with a brain from [BrainCatalog]. False for
  /// Bartleby, whose one download is the speech model and is managed by
  /// `VoiceTranscriber`, so brain shelves, brain banners and the brain
  /// storage total all skip him.
  bool get usesBrains => this != Companion.bartleby;

  /// One line under the name in Settings › Companions.
  String tagline(AppLocalizations l10n) => switch (this) {
        Companion.sebastian => l10n.companionSebastianTagline,
        Companion.marlowe => l10n.companionMarloweTagline,
        Companion.bartleby => l10n.companionBartlebyTagline,
      };

  /// The longer pitch, shown on the detail screen and at the top of the
  /// install sheet.
  String blurb(AppLocalizations l10n) => switch (this) {
        Companion.sebastian => l10n.companionSebastianBlurb,
        Companion.marlowe => l10n.companionMarloweBlurb,
        Companion.bartleby => l10n.companionBartlebyBlurb,
      };
}

/// The mark that stands for a companion wherever one is named.
///
/// A glyph rather than an icon from the Cupertino set, and a letter rather
/// than a picture: these are people, and every icon that reads as "AI" —
/// sparkles, a brain, a robot — says the opposite of what this feature is
/// for. A monogram in the app's own ink says "someone", which is the point.
///
/// Sized in one place so the settings row, the install sheet's hero and the
/// translated-text footer are unmistakably the same mark at three scales.
class CompanionMark extends StatelessWidget {
  const CompanionMark({
    super.key,
    required this.companion,
    required this.size,
    required this.foreground,
    this.background,
    this.borderColor,
  });

  final Companion companion;
  final double size;
  final Color foreground;

  /// Null draws the mark unfilled — what the in-bubble footer wants, where the
  /// bubble already supplies a surface and a second one would read as a chip.
  final Color? background;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final bg = background;
    final border = borderColor;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: (bg == null && border == null)
          ? null
          : BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: border == null ? null : Border.all(color: border),
            ),
      child: Text(
        companion.displayName.characters.first,
        // Deliberately not `theme.body`: this is a monogram, so it wants the
        // optical centring of a tightly-tracked capital rather than body
        // metrics with their line-height leading. `height: 1` is what keeps it
        // vertically centred in the circle at every size.
        style: TextStyle(
          fontSize: size * 0.5,
          height: 1,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
