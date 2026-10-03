import 'dart:async';
import 'dart:math' as math;

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
import 'expression_media.dart';
import 'expression_sheet.dart';
import 'klipy_attribution.dart';
import '../search_field.dart' show searchFieldDecoration;
import '../sheet_kit.dart' show sentenceCaseOf;

String _bare(String s) => s.replaceAll('️', '').trim();

/// The stickers in [packs] that a search for [query] finds, in pack order.
///
/// A sticker is found by its emoji: typed straight into the field ("🐶"), or
/// named in the viewer's language ("dog", "köpek") — [emojiHits] is what the
/// localized emoji search index returned for the query, the same index the
/// emoji picker and the pack store search with.
List<PackSticker> matchStickers(
  List<StickerPack> packs,
  String query, {
  Set<String> emojiHits = const {},
}) {
  if (query.trim().isEmpty) return const [];
  final hits = {for (final e in emojiHits) _bare(e)};
  final typed = _bare(query);
  return [
    for (final p in packs)
      for (final s in p.stickers)
        if (hits.contains(_bare(s.emoji)) ||
            (_bare(s.emoji).isNotEmpty && typed.contains(_bare(s.emoji))))
          s,
  ];
}

/// What the Stickers tab shows while its search field has a query: the
/// viewer's own stickers first (their personal pack and the packs they have
/// added), then matches from packs they have not added, then KLIPY's.
///
/// KLIPY's results are a separate, labelled section in KLIPY's own order —
/// its terms keep its content apart from other sources — with a way into the
/// full KLIPY browser, whose field carries the "Search KLIPY" placeholder.
class StickerSearchResults extends StatefulWidget {
  const StickerSearchResults({
    super.key,
    required this.query,
    required this.onSend,
    this.onOpenKlipy,
    this.onPicked,
  });

  final String query;
  final void Function(ExpressionItem item, {String? query}) onSend;

  /// Opens the full KLIPY browser on a query; null hides KLIPY entirely.
  final ValueChanged<String>? onOpenKlipy;

  /// After a send, so the host can put the search keyboard away.
  final VoidCallback? onPicked;

  @override
  State<StickerSearchResults> createState() => _StickerSearchResultsState();
}

class _StickerSearchResultsState extends State<StickerSearchResults> {
  Future<EmojiSearchIndex>? _index;
  Set<String> _emojiHits = const {};
  Timer? _debounce;
  List<KlipyMedia> _klipy = const [];
  bool _klipyLoading = false;

  /// Bumped per query, so a slow answer never lands on a newer one.
  int _gen = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_index == null) {
      _index = EmojiSearchIndex.forLocale(
          Localizations.maybeLocaleOf(context) ?? const Locale('en'));
      _run();
    }
  }

  @override
  void didUpdateWidget(StickerSearchResults old) {
    super.didUpdateWidget(old);
    if (old.query.trim() != widget.query.trim()) _run();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _run() {
    final gen = ++_gen;
    final q = widget.query.trim();
    _index?.then((i) {
      if (!mounted || gen != _gen) return;
      setState(() => _emojiHits = {for (final e in i.search(q)) e.emoji});
    });
    _debounce?.cancel();
    final klipy = ExpressionStore.instance.klipy;
    if (widget.onOpenKlipy == null || klipy == null || q.isEmpty) {
      setState(() {
        _klipy = const [];
        _klipyLoading = false;
      });
      return;
    }
    setState(() => _klipyLoading = true);
    // KLIPY only once typing pauses; our own matches update per keystroke.
    _debounce = Timer(const Duration(milliseconds: 380), () async {
      try {
        final page = await klipy.search(ExpressionKind.sticker, q);
        if (!mounted || gen != _gen) return;
        setState(() {
          _klipy = [for (final r in page.items) if (r is KlipyMedia) r];
          _klipyLoading = false;
        });
      } catch (_) {
        if (!mounted || gen != _gen) return;
        setState(() {
          _klipy = const [];
          _klipyLoading = false;
        });
      }
    });
  }

  void _send(ExpressionItem item, {String? query}) {
    HapticFeedback.lightImpact();
    widget.onSend(item, query: query);
    widget.onPicked?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = ExpressionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final outside = store.canUseOutsideMedia;
        final mine = [
          for (final p in store.packs)
            if (outside || !p.personal) p,
        ];
        final mineIds = {for (final p in mine) p.id};
        final others = [
          for (final p in store.catalog)
            if (!p.personal && !mineIds.contains(p.id)) p,
        ];
        final q = widget.query.trim();
        final yours = matchStickers(mine, q, emojiHits: _emojiHits);
        final more = matchStickers(others, q, emojiHits: _emojiHits);
        final klipyOn = outside && widget.onOpenKlipy != null &&
            store.klipy != null;

        return LayoutBuilder(builder: (context, constraints) {
          // Five across on a phone, as in the pack grids.
          final columns = math.max(5, (constraints.maxWidth / 76).floor());
          final size = (constraints.maxWidth - 16) / columns - 6;
          Widget grid(List<PackSticker> stickers) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    childCount: stickers.length,
                    (context, i) {
                      final s = stickers[i];
                      final item = s.toItem();
                      return _Tap(
                        onTap: () => _send(item),
                        onLongPress: () => showExpressionSheet(context, item),
                        label: s.emoji,
                        child: Center(
                          child: StickerArt(
                            item: item,
                            url: s.url,
                            size: size,
                            play: expressionsAutoplay(context),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );

          final nothing = yours.isEmpty &&
              more.isEmpty &&
              (!klipyOn || (!_klipyLoading && _klipy.isEmpty));
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              if (yours.isNotEmpty) ...[
                _header(context, l10n.expressionYourStickers),
                grid(yours),
              ],
              if (more.isNotEmpty) ...[
                _header(context, l10n.expressionPacksMore),
                grid(more),
              ],
              if (klipyOn && (_klipyLoading || _klipy.isNotEmpty)) ...[
                _header(context, l10n.expressionPacksFromKlipy),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 92,
                    child: _klipyLoading && _klipy.isEmpty
                        ? const Center(child: CupertinoActivityIndicator())
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _klipy.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 6),
                            itemBuilder: (context, i) {
                              final m = _klipy[i];
                              final item = m.toItem();
                              final url = m.gridFile?.url;
                              return _Tap(
                                onTap: () => _send(item, query: q),
                                onLongPress: () =>
                                    showExpressionSheet(context, item),
                                label: item.title,
                                child: url == null
                                    ? const ExpressionPlaceholder(
                                        width: 88, height: 88)
                                    : KlipyImage(
                                        url: url,
                                        width: 88,
                                        height: 88,
                                        fit: BoxFit.contain,
                                        radius: 0,
                                        play: expressionsAutoplay(context),
                                      ),
                              );
                            },
                          ),
                  ),
                ),
              ],
              if (klipyOn)
                SliverToBoxAdapter(
                  child: _SearchKlipyRow(
                    label: l10n.expressionSearchKlipyFor(q),
                    onTap: () => widget.onOpenKlipy!(q),
                  ),
                ),
              if (klipyOn && _klipy.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: KlipyAttribution(compact: true),
                  ),
                ),
              if (nothing)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.expressionNoResults,
                      textAlign: TextAlign.center,
                      style: theme.caption.copyWith(color: theme.inkMuted),
                    ),
                  ),
                ),
            ],
          );
        });
      },
    );
  }

  Widget _header(BuildContext context, String label) {
    final theme = ThemeScope.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Semantics(
          header: true,
          child: Text(sentenceCaseOf(context, label),
              style: theme.bodySoft.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.inkMuted,
              )),
        ),
      ),
    );
  }
}

/// The Stickers tab's search field: our stickers and KLIPY's, together.
class StickerSearchField extends StatelessWidget {
  const StickerSearchField({
    super.key,
    required this.controller,
    required this.focus,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Container(
        height: 36,
        decoration: searchFieldDecoration(theme),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(CupertinoIcons.search, size: 15, color: theme.inkMuted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focus,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                // Matches update as you type; the key just puts the keyboard
                // away so they have the room.
                onSubmitted: (_) => focus.unfocus(),
                style: theme.body.copyWith(color: theme.ink),
                cursorColor: theme.accent,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: l10n.expressionSearchStickers,
                  hintStyle: theme.body.copyWith(color: theme.inkMuted),
                  hintMaxLines: 1,
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: Icon(CupertinoIcons.clear_circled_solid,
                    size: 16, color: theme.inkMuted),
              ),
            if (focus.hasFocus) HideKeyboardButton(focus: focus),
          ],
        ),
      ),
    );
  }
}

class _Tap extends StatelessWidget {
  const _Tap({
    required this.child,
    required this.onTap,
    required this.onLongPress,
    this.label,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onLongPressHint: AppLocalizations.of(context).expressionOptionsHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress();
        },
        child: child,
      ),
    );
  }
}

class _SearchKlipyRow extends StatelessWidget {
  const _SearchKlipyRow({required this.label, required this.onTap});

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
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
