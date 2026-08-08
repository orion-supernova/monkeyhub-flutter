import 'dart:async';
import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/emoji_search_index.dart';
import '../data/emoji_set_full.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';

/// Height of the resting search bar under the grid, before safe-area padding.
const double _searchBarHeight = 44;

/// Everything the sheet draws above the picker — top padding, drag handle,
/// title, and the gap under it — plus a little slack.
/// A constant rather than a measurement: [Config.height] has to agree with the
/// [SizedBox] wrapping the picker, and a LayoutBuilder around the picker alone
/// would only know the answer after the picker had already been asked how tall
/// it is. It buys clearance from nothing device-specific: the safe area is
/// handled structurally, by the box this sheet is handed.
const double _chromeHeight = 90;

/// A top-level tear-off, not an inline `(_) => fullEmojiSet` closure.
///
/// `Config` implements `==` and compares `emojiSet` by identity, and
/// `EmojiPicker.didUpdateWidget` rebuilds its entire category list — all 1,906
/// entries, plus a recents read — whenever the config compares unequal. A
/// fresh closure per build makes that fire on every rebuild, and this sheet
/// rebuilds on every frame of the keyboard animation. Nothing visibly breaks
/// (the reload runs synchronously once recents are cached), it is simply a lot
/// of work to redo sixty times a second for a list that never changes.
///
/// The `locale` is ignored, and that is not the localization bug it looks
/// like. Two reasons. The package hands this the locale off `Config.locale`,
/// which defaults to `en` and is not the app's — it is a picker setting, not a
/// binding to `Localizations`. And an `Emoji`'s `name` is never drawn or read
/// out: grep the package and the only consumer is `Emoji.keywords`, i.e.
/// search. So there is nothing here for a translation to change. What search
/// matches on comes from [EmojiSearchIndex] instead, which follows the *app*
/// locale — see [_ReactionSearchViewState].
List<CategoryEmoji> _emojiSet(Locale locale) => fullEmojiSet;

/// Reached via the `+` on the floating reaction pill. WhatsApp-style:
/// a categorized sheet of every emoji, with skin tones and search. The only
/// text entry is the search field, and it commits nothing — picking an emoji
/// is still the only way out.
class ReactionPickerSheet extends StatelessWidget {
  const ReactionPickerSheet({super.key});

  /// Sizes the grid to the box this sheet is actually handed, and lets the
  /// picker's own category list scroll inside it — the grid never shrinks its
  /// cells and never spills past the sheet.
  ///
  /// The height comes from `LayoutBuilder`, not from arithmetic on
  /// `MediaQuery.sizeOf(context).height`, because inside a bottom-sheet route
  /// the MediaQuery is not the window's. `ModalBottomSheetRoute.buildPage`
  /// wraps its content in `MediaQuery.removePadding(removeTop: true)`, and
  /// `MediaQueryData.removePadding` zeroes `viewPadding.top` along with
  /// `padding.top`. From in here BOTH read 0 on a Dynamic Island phone, so
  /// `screenH - padding.top - keyboard` handed the grid 59pt more than existed
  /// — and since the sheet is bottom-anchored and the keyboard had already
  /// pushed it up, those 59pt came off the TOP and the picker's title and tab
  /// bar ended up under the island. A `SafeArea` in here would have done
  /// nothing for the same reason: the padding it wants to apply is already
  /// gone.
  ///
  /// The fix is applied one level up instead, where the real inset still
  /// exists: `showReactionPicker` passes `useSafeArea: true`, so the ROUTE
  /// insets the sheet's box by the window's `MediaQuery.padding.top`, and the
  /// `constraints.maxHeight` read here is already island-aware. `viewInsets`
  /// survives the route untouched, so the keyboard is still subtracted here —
  /// and because both are read during layout, the grid re-fits itself on every
  /// frame of the keyboard sliding in or out under an open sheet, and on
  /// rotation.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _build(context, constraints),
    );
  }

  Widget _build(BuildContext context, BoxConstraints constraints) {
    final theme = ThemeScope.of(context);
    final screenH = MediaQuery.sizeOf(context).height;
    // viewInsets.bottom = soft keyboard (pushes the WHOLE sheet up).
    // paddingOf().bottom = home indicator / gesture bar — folded INTO the
    // picker's height and onto the search bar, which is the bottom-most row,
    // so the sheet still reaches the screen edge while the search field
    // clears the indicator. Flutter zeroes this padding once the keyboard
    // covers it, so opening search reclaims the space instead of stranding it.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeArea = MediaQuery.paddingOf(context);
    final bottomSafe = safeArea.bottom;

    // The box, when there is one. The desktop popover puts this sheet inside a
    // `SingleChildScrollView`, which offers unbounded height and means nothing
    // about the screen — there, fall back to the window, minus a top inset the
    // popover path has not spent (`viewPadding` rather than `padding`, so a
    // keyboard overlapping the top inset in landscape cannot zero it).
    final available = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : screenH - MediaQuery.viewPaddingOf(context).top;

    final desiredH = (screenH * 0.5).clamp(320.0, 460.0).toDouble() +
        bottomSafe +
        _searchBarHeight;
    // Until search existed there was no text entry here, so the keyboard never
    // came up and half the screen was always free. Now it does: the sheet is
    // lifted by the full keyboard height, and a picker still asking for half
    // the *screen* overflows the space left above it. Give back whatever the
    // keyboard took.
    //
    // No minimum floor. A floor is what you reach for here, and on a short
    // viewport — landscape, a small phone, a split view — honouring it is
    // exactly what overflows the sheet, because the sheet sits above the
    // keyboard and cannot grow into it. A cramped grid beats a broken one.
    final ceiling = available - bottomInset - _chromeHeight;
    final totalPickerH = math.max(0.0, math.min(desiredH, ceiling));
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Meaningless once dismiss-by-drag isn't a thing — the desktop
            // popover closes via barrier tap / Esc, not a drag gesture.
            if (context.isCompact)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.inkMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            Text(
              AppLocalizations.of(context).reactionBubblePickerTitle,
              textAlign: TextAlign.center,
              style: theme.label.copyWith(letterSpacing: 2.4),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: totalPickerH,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(emoji.emoji);
                },
                config: Config(
                  // Null, not `totalPickerH`: the SizedBox above already bounds
                  // the picker, and a height that moves with the keyboard is
                  // the other thing that makes the config compare unequal every
                  // frame — see [_emojiSet]. With both gone this Config is
                  // stable across rebuilds.
                  height: null,
                  // The package's bundled set stopped at Unicode 14.0, so every
                  // glyph added since — 🫨 🩷 🐦‍🔥 🍋‍🟩 ⛓️‍💥 🫩 and ~290 others —
                  // was missing from the grid even though the phone renders
                  // them fine. `fullEmojiSet` is generated from Unicode 16.0;
                  // see tool/generate_emoji_set.dart.
                  emojiSet: _emojiSet,
                  // Android-only inside the package (it no-ops everywhere
                  // else), and pointless now that we ship exactly the glyphs we
                  // want: it would only cost a platform channel round-trip over
                  // 1,900 entries on every open.
                  checkPlatformCompatibility: false,
                  emojiTextStyle: TextStyle(color: theme.ink, fontSize: 24),
                  emojiViewConfig: EmojiViewConfig(
                    columns: 8,
                    emojiSizeMax: 28,
                    backgroundColor: Colors.transparent,
                    verticalSpacing: 2,
                    horizontalSpacing: 2,
                    gridPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                    recentsLimit: 28,
                    noRecents: Center(
                      child: Text(
                        AppLocalizations.of(context)
                            .reactionBubbleNoRecentsPlaceholder,
                        style: theme.monoTiny,
                      ),
                    ),
                    buttonMode: ButtonMode.CUPERTINO,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: Colors.transparent,
                    indicatorColor: theme.accent,
                    iconColor: theme.inkMuted,
                    iconColorSelected: theme.accent,
                    backspaceColor: theme.accent,
                    dividerColor: theme.divider,
                    tabBarHeight: 40,
                    initCategory: Category.SMILEYS,
                  ),
                  // The package only ever opens search from this bar, so
                  // disabling it (as this sheet used to) left 1,900 emoji
                  // reachable by scrolling alone. Ours is a search field
                  // rather than the stock circular button — there is no text
                  // to backspace in a reaction picker, so that half of the
                  // default bar is dropped.
                  bottomActionBarConfig: BottomActionBarConfig(
                    customBottomActionBar: (_, _, showSearchView) => _SearchBar(
                      onTap: showSearchView,
                      bottomSafe: bottomSafe,
                    ),
                  ),
                  searchViewConfig: SearchViewConfig(
                    customSearchView: (config, state, showEmojiView) =>
                        _ReactionSearchView(
                      config,
                      state,
                      showEmojiView,
                      bottomSafe: bottomSafe,
                    ),
                  ),
                  skinToneConfig: SkinToneConfig(
                    enabled: true,
                    rememberSkinTone: true,
                    dialogBackgroundColor: theme.surface,
                    indicatorColor: theme.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The resting search affordance under the grid. Looks like the search field
/// it opens, so tapping it feels like focusing rather than navigating.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap, required this.bottomSafe});

  final VoidCallback onTap;
  final double bottomSafe;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final hint = AppLocalizations.of(context).reactionBubbleSearchHint;
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 4, 10, 4 + bottomSafe),
      child: FocusableTap(
        onTap: onTap,
        semanticLabel: hint,
        radius: 12,
        // Bare GestureDetector, never InkWell — this app renders no ink anywhere.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 36,
            decoration: theme.inputDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(CupertinoIcons.search, size: 15, color: theme.inkMuted),
                const SizedBox(width: 8),
                Text(
                  hint,
                  style: theme.bodySoft.copyWith(color: theme.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Replaces the whole picker while search is open — that is the package's
/// model, not a choice we make here. The stock view is rebuilt rather than
/// configured because it leans on [IconButton], and nothing in this app is
/// allowed to render an ink ripple.
class _ReactionSearchView extends SearchView {
  const _ReactionSearchView(
    super.config,
    super.state,
    super.showEmojiView, {
    required this.bottomSafe,
  });

  final double bottomSafe;

  @override
  _ReactionSearchViewState createState() => _ReactionSearchViewState();
}

class _ReactionSearchViewState extends SearchViewState<_ReactionSearchView> {
  /// Tracked only to tell the two empty states apart: with nothing typed the
  /// view seeds itself with recents, so "no matches" would be a lie for a user
  /// who has simply never reacted before.
  String _query = '';

  Locale? _locale;
  Future<EmojiSearchIndex>? _index;

  /// Guards against an older query's index load landing after a newer one's.
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // maybeLocaleOf, not localeOf: the picker is also built in tests and tools
    // that never wrap it in Localizations, and an English index is a much
    // better answer there than a throw.
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('en');
    if (locale == _locale) return;
    _locale = locale;
    _index = EmojiSearchIndex.forLocale(locale);
    // Language changed under an open query — re-run it so the results follow.
    if (_query.isNotEmpty) onTextInputChanged(_query);
  }

  /// Deliberately does not call `super`.
  ///
  /// The package's [SearchViewState] would run `EmojiPickerUtils.searchEmoji`,
  /// which only ever matches English here: it reads its terms out of
  /// `Emoji.name`, and `fullEmojiSet` is generated from the English CLDR
  /// annotations. Worse, it flattens that set into a **singleton** cache the
  /// first time it is called and never invalidates it, so a per-locale emoji
  /// set would not have fixed this either — the first language to search would
  /// have been frozen in for the rest of the process.
  ///
  /// [EmojiSearchIndex] is the replacement. Everything else `super` did is
  /// reproduced below; `links` is repopulated lazily by `buildEmoji` via
  /// `addSkinToneTargetIfAvailable`, so clearing it here is enough.
  @override
  void onTextInputChanged(String text) {
    _query = text;
    final generation = ++_generation;
    links.clear();
    results.clear();

    final index = _index;
    if (index == null) return;
    index.then((index) {
      if (!mounted || generation != _generation) return;
      final matches = index.search(text);
      setState(() {
        results
          ..clear()
          ..addAll(matches);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final emojiSize =
            widget.config.emojiViewConfig.getEmojiSize(constraints.maxWidth);
        final emojiBoxSize =
            widget.config.emojiViewConfig.getEmojiBoxSize(constraints.maxWidth);

        return Column(
          children: [
            // Transparent Material, not the default one: the skin-tone overlay
            // and the emoji cells both want a Material ancestor for text
            // styling, and without one Flutter paints its yellow debug
            // underlines over every glyph.
            //
            // A grid rather than the stock horizontal strip: search replaces
            // the entire picker, so a one-row strip would leave most of a
            // 460pt sheet empty and cap a 200-hit query at whatever fits
            // across.
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: results.isEmpty
                    ? Center(
                        child: Text(
                          _query.isEmpty
                              ? loc.reactionBubbleNoRecentsPlaceholder
                              : loc.reactionBubbleSearchEmptyPlaceholder,
                          style: theme.monoTiny,
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: widget.config.emojiViewConfig.columns,
                          mainAxisSpacing:
                              widget.config.emojiViewConfig.verticalSpacing,
                          crossAxisSpacing:
                              widget.config.emojiViewConfig.horizontalSpacing,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) => buildEmoji(
                          results[index],
                          emojiSize,
                          emojiBoxSize,
                        ),
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 10, 4 + widget.bottomSafe),
              child: Row(
                children: [
                  FocusableTap(
                    onTap: widget.showEmojiView,
                    semanticLabel: loc.reactionBubbleSearchBackSemanticLabel,
                    shape: FocusRingShape.circle,
                    radius: 18,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.showEmojiView,
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          CupertinoIcons.chevron_left,
                          size: 18,
                          color: theme.inkMuted,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      decoration: theme.inputDecoration(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Icon(
                            CupertinoIcons.search,
                            size: 15,
                            color: theme.inkMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              focusNode: focusNode,
                              onChanged: onTextInputChanged,
                              style: theme.body.copyWith(color: theme.ink),
                              cursorColor: theme.accent,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                hintText: loc.reactionBubbleSearchHint,
                                hintStyle: theme.bodySoft
                                    .copyWith(color: theme.inkMuted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Helper: show the picker and return the chosen emoji (or null on dismiss).
///
/// `useSafeArea: true` is load-bearing, not decoration — it is the only place
/// in this path where the window's real top inset is still readable. See
/// [ReactionPickerSheet.build].
Future<String?> showReactionPicker(BuildContext context) {
  // Warm the search index while the sheet animates in. Building it means
  // reading a 75-250 KB asset and tokenising ~1,900 entries, which is fast but
  // not free, and the alternative is paying for it on the user's first
  // keystroke. Memoised, so a second open costs nothing.
  final locale = Localizations.maybeLocaleOf(context);
  if (locale != null) unawaited(EmojiSearchIndex.forLocale(locale));

  return showAdaptiveSheet<String>(
    context,
    useSafeArea: true,
    builder: (_) => const ReactionPickerSheet(),
  );
}
