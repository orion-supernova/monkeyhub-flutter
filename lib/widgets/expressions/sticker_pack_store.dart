import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/emoji_search_index.dart';
import '../../expressions/expression_store.dart';
import '../../expressions/klipy.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/expression_item.dart';
import '../../models/sticker_pack.dart';
import '../../theme/theme_scope.dart';
import '../app_toast.dart';
import 'expression_media.dart';
import 'klipy_attribution.dart';
import '../meta_text.dart';
import '../ios_kit.dart';
import '../search_field.dart';

String _bare(String s) => s.replaceAll('️', '').trim();

/// Which of [packs] a search for [query] should show.
///
/// Three ways in, because people look for stickers the way they think of
/// them: by the pack's name ("wild"), by an emoji typed straight into the
/// field ("🐶"), and by a word for an emoji in their own language ("dog",
/// "köpek") — [emojiHits] is what the localized emoji search index returned
/// for the query, the same index the emoji picker searches with.
List<StickerPack> matchPacks(
  List<StickerPack> packs,
  String query, {
  Set<String> emojiHits = const {},
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return packs;
  final hits = {for (final e in emojiHits) _bare(e)};
  final typed = _bare(query);
  return [
    for (final p in packs)
      if (p.title.toLowerCase().contains(q) ||
          p.stickers.any((s) {
            final e = _bare(s.emoji);
            return hits.contains(e) || (e.isNotEmpty && typed.contains(e));
          }))
        p,
  ];
}

/// The sticker pack store, shown inside the expression panel in place of a
/// pack's grid.
///
/// Inside the panel rather than a sheet of its own for the reason the panel
/// itself is inline: in the thread overlay a pushed sheet would land under the
/// overlay. Here it works identically everywhere, and dragging the panel up
/// gives it the whole screen.
class StickerPackStore extends StatefulWidget {
  const StickerPackStore({
    super.key,
    required this.onOpenPack,
    this.onSearchFocusChanged,
    this.onOpenKlipy,
  });

  /// Opens KLIPY's sticker search on a query — a category tile, or the
  /// store's own search carried over. Null (no KLIPY on this server, or an
  /// account that may not send outside pictures) hides the KLIPY section.
  final ValueChanged<String>? onOpenKlipy;

  /// Switches the panel to a pack the user has just added — straight from the
  /// store to using it.
  final ValueChanged<String> onOpenPack;

  /// Tells the panel the search field took or lost the keyboard, so it can
  /// grow to fill everything above the keys — a half-height panel with the
  /// keyboard up left room for barely one pack.
  final ValueChanged<bool>? onSearchFocusChanged;

  @override
  State<StickerPackStore> createState() => _StickerPackStoreState();
}

class _StickerPackStoreState extends State<StickerPackStore> {
  final _query = TextEditingController();
  final _focus = FocusNode();

  /// What was last reported through [StickerPackStore.onSearchFocusChanged].
  /// Tracked rather than read off [_focus] at dispose: by then the node has
  /// already let go, so `hasFocus` says false and the release would never be
  /// sent.
  bool _reportedFocus = false;

  /// KLIPY's sticker categories, loaded once for the "from KLIPY" section.
  List<KlipyCategory> _klipyCategories = const [];

  @override
  void initState() {
    super.initState();
    final klipy = ExpressionStore.instance.klipy;
    if (widget.onOpenKlipy != null && klipy != null) {
      klipy.categories(ExpressionKind.sticker).then((c) {
        if (mounted) setState(() => _klipyCategories = c);
      }).catchError((Object _) {});
    }
    _focus.addListener(() {
      if (_focus.hasFocus == _reportedFocus) return;
      _reportedFocus = _focus.hasFocus;
      widget.onSearchFocusChanged?.call(_reportedFocus);
      // The hide-keyboard button comes and goes with the focus.
      if (mounted) setState(() {});
    });
  }
  Set<String> _emojiHits = const {};
  String? _expanded;
  Future<EmojiSearchIndex>? _index;
  int _gen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _index ??= EmojiSearchIndex.forLocale(
        Localizations.maybeLocaleOf(context) ?? const Locale('en'));
  }

  @override
  void dispose() {
    // Leaving the store with the keyboard up must not strand the panel at its
    // search height. After the frame, because this runs while the tree is
    // being torn down, and the host rebuilds when told.
    final report = widget.onSearchFocusChanged;
    if (_reportedFocus && report != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => report(false));
    }
    _focus.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onQuery(String text) {
    final gen = ++_gen;
    setState(() {});
    final index = _index;
    if (index == null || text.trim().isEmpty) {
      setState(() => _emojiHits = const {});
      return;
    }
    index.then((i) {
      if (!mounted || gen != _gen) return;
      setState(() => _emojiHits = {for (final e in i.search(text)) e.emoji});
    });
  }

  Future<void> _toggleInstalled(StickerPack pack, bool install) async {
    HapticFeedback.selectionClick();
    final l10n = AppLocalizations.of(context);
    final toast = AppToast.of(context);
    try {
      await ExpressionStore.instance.setInstalled(pack, install);
    } catch (_) {
      toast.show(l10n.expressionActionFailed, tone: ToastTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = ExpressionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final official = [
          for (final p in store.catalog)
            if (!p.personal) p,
        ];
        final byId = {for (final p in official) p.id: p};
        final added = [
          for (final p in store.packs)
            if (!p.personal && byId.containsKey(p.id)) p,
        ];
        final more = [
          for (final p in official)
            if (!store.isInstalled(p.id)) p,
        ];
        final searching = _query.text.trim().isNotEmpty;

        Widget row(StickerPack p, {Widget? handle}) => _PackRow(
              key: ValueKey('pack-${p.id}'),
              pack: p,
              installed: store.isInstalled(p.id),
              expanded: _expanded == p.id,
              onTap: () => setState(
                  () => _expanded = _expanded == p.id ? null : p.id),
              onAdd: () async {
                // Put the search keyboard away first, so the pack it opens
                // shows at the panel's normal height.
                _focus.unfocus();
                await _toggleInstalled(p, true);
                if (mounted) widget.onOpenPack(p.id);
              },
              onRemove: () => _toggleInstalled(p, false),
              handle: handle,
            );

        final List<Widget> body;
        if (searching) {
          final found = matchPacks(official, _query.text, emojiHits: _emojiHits);
          body = found.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.expressionNoPacksFound,
                      textAlign: TextAlign.center,
                      style: groupedFooterStyle(theme),
                    ),
                  ),
                ]
              : [for (final p in found) row(p)];
          // Our packs are a few hundred stickers; KLIPY has many thousands.
          // Carry the search over rather than ending at "no packs match".
          final openKlipy = widget.onOpenKlipy;
          if (openKlipy != null && store.klipy != null) {
            final q = _query.text.trim();
            body.add(_KlipySearchRow(
              label: l10n.expressionSearchKlipyFor(q),
              onTap: () {
                _focus.unfocus();
                openKlipy(q);
              },
            ));
          }
        } else {
          body = [
            if (added.isNotEmpty) ...[
              _Header(l10n.expressionPacksAdded),
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                onReorder: (from, to) {
                  final ids = [for (final p in added) p.id];
                  final moved = ids.removeAt(from);
                  ids.insert(to > from ? to - 1 : to, moved);
                  HapticFeedback.selectionClick();
                  store.reorderInstalled(ids);
                },
                children: [
                  for (var i = 0; i < added.length; i++)
                    row(
                      added[i],
                      handle: ReorderableDragStartListener(
                        index: i,
                        child: Semantics(
                          label: l10n.expressionPackReorder(added[i].title),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(CupertinoIcons.line_horizontal_3,
                                size: 18, color: theme.inkMuted),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            _Header(l10n.expressionPacksMore),
            if (more.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Text(l10n.expressionAllPacksAdded,
                    style: groupedFooterStyle(theme)),
              )
            else
              for (final p in more) row(p),
            // KLIPY's catalogue, as its own clearly labelled section — its
            // terms keep its content apart from other sources, in the order it
            // returns. Tapping a category opens its stickers.
            if (widget.onOpenKlipy != null &&
                store.klipy != null &&
                _klipyCategories.isNotEmpty) ...[
              _Header(l10n.expressionPacksFromKlipy),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in _klipyCategories)
                      _KlipyCategoryTile(
                        category: c,
                        onTap: () => widget.onOpenKlipy!(c.query),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: KlipyAttribution(compact: true),
              ),
            ],
          ];
        }

        return Column(
          children: [
            // THE search bar: pill, 18pt magnifier, clear button. Search
            // filters as you type; the key just puts the keyboard away.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SearchField(
                      controller: _query,
                      focusNode: _focus,
                      hintText: l10n.expressionPackSearchHint,
                      onChanged: _onQuery,
                    ),
                  ),
                  if (_focus.hasFocus) HideKeyboardButton(focus: _focus),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                // Scrolling the packs puts the search keyboard away.
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 12),
                children: body,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One KLIPY sticker category: its preview and its name.
class _KlipyCategoryTile extends StatelessWidget {
  const _KlipyCategoryTile({required this.category, required this.onTap});

  final KlipyCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final url = category.previewUrl;
    return FocusableTap(
      onTap: onTap,
      semanticLabel: category.name,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              if (url != null)
                KlipyImage(
                  url: url,
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                  radius: 0,
                  play: false,
                )
              else
                const SizedBox(width: 64, height: 64),
              const SizedBox(height: 4),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: groupedMetaStyle(theme).copyWith(color: theme.inkSoft),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Search '<query>' on KLIPY", at the end of the store's search results.
class _KlipySearchRow extends StatelessWidget {
  const _KlipySearchRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Icon(CupertinoIcons.search, size: 18, color: theme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: theme.body.copyWith(color: theme.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A section header in the store — THE one, 17/w600 ink.
class _Header extends StatelessWidget {
  const _Header(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(header: true, child: GroupedHeader(label)),
      );
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    super.key,
    required this.pack,
    required this.installed,
    required this.expanded,
    required this.onTap,
    required this.onAdd,
    required this.onRemove,
    this.handle,
  });

  final StickerPack pack;
  final bool installed;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final Widget? handle;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final autoplay = expressionsAutoplay(context);
    final preview = pack.stickers.take(4).toList();
    final credit = pack.author == null
        ? null
        : l10n.expressionPackCredit(pack.author!, pack.license ?? '');
    return Container(
      color: theme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FocusableTap(
            onTap: onTap,
            semanticLabel: pack.title,
            radius: theme.radiusMd,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pack.title, style: theme.bodyEmph),
                          const SizedBox(height: 2),
                          Text(
                            [
                              l10n.expressionPackStickerCount(
                                  pack.stickers.length),
                              ?credit,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: metaText(theme)
                                .copyWith(color: theme.inkMuted),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              for (final s in preview)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: StickerArt(
                                    item: s.toItem(),
                                    url: s.url,
                                    size: 36,
                                    // Still, in a list of fourteen packs;
                                    // the expanded preview is where they move.
                                    play: false,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    RowPillButton(
                      label: installed
                          ? l10n.expressionPackRemove
                          : l10n.expressionPackAdd,
                      filled: !installed,
                      onTap: installed ? onRemove : onAdd,
                    ),
                    ?handle,
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in pack.stickers)
                    StickerArt(
                      item: s.toItem(),
                      url: s.url,
                      size: 52,
                      play: autoplay,
                    ),
                ],
              ),
            ),
          Divider(height: 1, color: theme.divider),
        ],
      ),
    );
  }
}
