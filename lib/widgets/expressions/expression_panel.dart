import 'dart:async';
import 'dart:math' as math;

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/emoji_set_full.dart';
import '../../expressions/expression_store.dart';
import '../../expressions/justified_rows.dart';
import '../../expressions/klipy.dart';
import '../../keyboard/focusable_tap.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/expression_item.dart';
import '../../models/sticker_pack.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_scope.dart';
import '../reaction_picker_sheet.dart' show EmojiSearchBar, EmojiSearchView;
import 'expression_media.dart';
import 'expression_sheet.dart';
import 'klipy_ad_tile.dart';
import 'klipy_attribution.dart';

/// The composer's expression panel — emoji, GIFs and stickers — shown in place
/// of the keyboard.
///
/// Opened by the smiley in the composer; see [ExpressionPanelController] for
/// how it trades places with the keyboard. It is an inline widget below the
/// composer rather than a sheet on purpose: the thread overlay lives in a root
/// `OverlayEntry` where pushed routes fight it (which is why that overlay has no
/// attach button), and an inline panel works identically in both.
///
/// Three tabs, with GIFs present only when this server has KLIPY configured
/// and the account may send outside media:
///
///  * **Emoji** inserts into the composer, with the reaction picker's
///    localized search.
///  * **GIFs** is KLIPY: trending, categories, search with autocomplete, and
///    the user's own recents and favourites.
///  * **Stickers** is our packs plus KLIPY's sticker catalogue, a strip across
///    the top to switch between them, and the user's personal pack.
class ExpressionPanel extends StatefulWidget {
  const ExpressionPanel({
    super.key,
    required this.composer,
    required this.onSend,
    required this.height,
    this.onCreateSticker,
    this.onSearchFocusChanged,
    this.bottomPadding = 0,
    this.keyboardInset = 0,
  });

  /// How much of the panel the keyboard currently covers, while the two are
  /// changing places. The panel lays out at its full [height] but only
  /// occupies what the keyboard leaves, so as one slides away the other grows
  /// into exactly that space and nothing above them moves.
  final double keyboardInset;

  /// The composer's controller, which the emoji tab types into.
  final TextEditingController composer;

  /// Sends a GIF or sticker. [query] is the KLIPY search that found it, which
  /// KLIPY's share call wants for its ranking.
  final void Function(ExpressionItem item, {String? query}) onSend;

  final double height;

  /// Starts the make-a-sticker flow. Null hides the "+" tile.
  final VoidCallback? onCreateSticker;

  /// Tells the host a search field took or lost focus, so it can let the
  /// keyboard up without closing the panel.
  final ValueChanged<bool>? onSearchFocusChanged;

  /// The bottom safe area, which the panel pads itself when it is the lowest
  /// thing on screen.
  final double bottomPadding;

  @override
  State<ExpressionPanel> createState() => _ExpressionPanelState();
}

enum _Tab { emoji, gifs, stickers }

class _ExpressionPanelState extends State<ExpressionPanel> {
  /// Remembered across openings for the session, like every messenger's panel.
  static _Tab _lastTab = _Tab.emoji;

  late _Tab _tab = _lastTab;

  @override
  void initState() {
    super.initState();
    // Before the first trending request, so it can already carry the browser
    // agent KLIPY needs to serve an ad.
    unawaited(primeKlipyUserAgent());
  }

  void _select(_Tab tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = _lastTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = ExpressionStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final gifsAvailable = store.klipy != null && store.canUseOutsideMedia;
        var tab = _tab;
        if (tab == _Tab.gifs && !gifsAvailable) tab = _Tab.emoji;
        final full = widget.height + widget.bottomPadding;
        final visible = math.max(0.0, full - widget.keyboardInset);
        return SizedBox(
          height: visible,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: full,
              maxHeight: full,
              child: _body(context, theme, l10n, store, gifsAvailable, tab),
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppTheme theme,
    AppLocalizations l10n,
    ExpressionStore store,
    bool gifsAvailable,
    _Tab tab,
  ) {
    return Builder(
      builder: (context) {
        return Container(
          height: widget.height + widget.bottomPadding,
          padding: EdgeInsets.only(bottom: widget.bottomPadding),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(top: BorderSide(color: theme.divider)),
          ),
          child: DefaultTextStyle(
            style: theme.body.copyWith(
              color: theme.ink,
              decoration: TextDecoration.none,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Row(
                      children: [
                        _TabPill(
                          label: l10n.expressionTabEmoji,
                          selected: tab == _Tab.emoji,
                          onTap: () => _select(_Tab.emoji),
                        ),
                        if (gifsAvailable)
                          _TabPill(
                            label: l10n.expressionTabGifs,
                            selected: tab == _Tab.gifs,
                            onTap: () => _select(_Tab.gifs),
                          ),
                        _TabPill(
                          label: l10n.expressionTabStickers,
                          selected: tab == _Tab.stickers,
                          onTap: () => _select(_Tab.stickers),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: switch (tab) {
                      _Tab.emoji => _EmojiTab(composer: widget.composer),
                      _Tab.gifs => _KlipyBrowser(
                          key: const ValueKey('klipy-gifs'),
                          kind: ExpressionKind.gif,
                          klipy: store.klipy!,
                          onSend: widget.onSend,
                          onSearchFocusChanged: widget.onSearchFocusChanged,
                        ),
                      _Tab.stickers => _StickersTab(
                          onSend: widget.onSend,
                          onCreateSticker: store.canUseOutsideMedia
                              ? widget.onCreateSticker
                              : null,
                          onSearchFocusChanged: widget.onSearchFocusChanged,
                        ),
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FocusableTap(
        onTap: onTap,
        semanticLabel: label,
        selected: selected,
        radius: 999,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: theme.motionFast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? theme.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: theme.label.copyWith(
                color: selected ? theme.accent : theme.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Emoji ──────────────────────────────────────────────────────────────────

class _EmojiTab extends StatelessWidget {
  const _EmojiTab({required this.composer});

  final TextEditingController composer;

  /// Deletes the grapheme before the cursor — a flag or a family is one
  /// character to the user and many code units to the controller.
  void _backspace() {
    final text = composer.text;
    final sel = composer.selection;
    final end = sel.isValid ? sel.start : text.length;
    if (sel.isValid && !sel.isCollapsed) {
      composer.value = TextEditingValue(
        text: text.replaceRange(sel.start, sel.end, ''),
        selection: TextSelection.collapsed(offset: sel.start),
      );
      return;
    }
    if (end <= 0) return;
    final before = text.substring(0, end).characters;
    final trimmed = before.skipLast(1).toString();
    composer.value = TextEditingValue(
      text: trimmed + text.substring(end),
      selection: TextSelection.collapsed(offset: trimmed.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return EmojiPicker(
      textEditingController: composer,
      onEmojiSelected: (_, _) => HapticFeedback.lightImpact(),
      config: Config(
        height: null,
        // The same Unicode 16.0 set the reaction picker uses — see
        // tool/generate_emoji_set.dart.
        emojiSet: (_) => fullEmojiSet,
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
              l10n.reactionBubbleNoRecentsPlaceholder,
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
        bottomActionBarConfig: BottomActionBarConfig(
          customBottomActionBar: (_, _, showSearchView) => Row(
            children: [
              Expanded(
                child: EmojiSearchBar(onTap: showSearchView, bottomSafe: 0),
              ),
              FocusableTap(
                onTap: _backspace,
                semanticLabel: l10n.expressionBackspace,
                shape: FocusRingShape.circle,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _backspace,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 14, 4),
                    child: Icon(CupertinoIcons.delete_left,
                        size: 22, color: theme.inkMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
        searchViewConfig: SearchViewConfig(
          customSearchView: (config, state, showEmojiView) =>
              EmojiSearchView(config, state, showEmojiView, bottomSafe: 0),
        ),
        skinToneConfig: SkinToneConfig(
          enabled: true,
          rememberSkinTone: true,
          dialogBackgroundColor: theme.surface,
          indicatorColor: theme.accent,
        ),
      ),
    );
  }
}

// ─── KLIPY ──────────────────────────────────────────────────────────────────

/// What the KLIPY browser is showing.
enum _KlipySection { trending, search, recent, favorites }

/// One tile in the grid: a KLIPY result, an ad, or a remembered item.
class _Tile {
  _Tile.media(KlipyMedia m)
      : media = m,
        ad = null,
        item = m.toItem(),
        gridUrl = m.gridFile?.url,
        aspect = _aspect(m.gridFile?.width, m.gridFile?.height);
  _Tile.ad(KlipyAd a)
      : media = null,
        ad = a,
        item = null,
        gridUrl = null,
        aspect = a.width / a.height;
  _Tile.item(ExpressionItem i)
      : media = null,
        ad = null,
        item = i,
        gridUrl = i.url,
        aspect = i.aspectRatio;

  final KlipyMedia? media;
  final KlipyAd? ad;
  final ExpressionItem? item;
  final String? gridUrl;
  final double aspect;

  static double _aspect(double? w, double? h) =>
      w == null || h == null || w <= 0 || h <= 0 ? 1 : w / h;
}

class _KlipyBrowser extends StatefulWidget {
  const _KlipyBrowser({
    super.key,
    required this.kind,
    required this.klipy,
    required this.onSend,
    this.onSearchFocusChanged,
  });

  final ExpressionKind kind;
  final KlipyClient klipy;
  final void Function(ExpressionItem item, {String? query}) onSend;
  final ValueChanged<bool>? onSearchFocusChanged;

  @override
  State<_KlipyBrowser> createState() => _KlipyBrowserState();
}

class _KlipyBrowserState extends State<_KlipyBrowser> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  Timer? _autoDebounce;

  _KlipySection _section = _KlipySection.trending;
  List<KlipyResult> _results = [];
  int _page = 0;
  bool _hasNext = false;
  bool _loading = false;
  Object? _error;

  /// Bumped on every new request so a slow answer to an old query can never
  /// overwrite a newer one.
  int _gen = 0;

  List<KlipyCategory> _categories = const [];
  List<String> _suggestions = const [];

  bool get _isSticker => widget.kind == ExpressionKind.sticker;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      widget.onSearchFocusChanged?.call(_focus.hasFocus);
      setState(() {});
    });
    _scroll.addListener(_maybeLoadMore);
    _load(reset: true);
    widget.klipy.categories(widget.kind).then((c) {
      if (mounted) setState(() => _categories = c);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _autoDebounce?.cancel();
    if (_focus.hasFocus) widget.onSearchFocusChanged?.call(false);
    _query.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String get _q => _query.text.trim();

  Future<void> _load({required bool reset}) async {
    if (_section == _KlipySection.recent ||
        _section == _KlipySection.favorites) {
      return;
    }
    if (_loading && !reset) return;
    final gen = ++_gen;
    final page = reset ? 1 : _page + 1;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _results = [];
        _hasNext = false;
      }
    });
    try {
      final q = _q;
      final res = q.isEmpty
          ? await widget.klipy.trending(widget.kind, page: page)
          : await widget.klipy.search(widget.kind, q, page: page);
      if (!mounted || gen != _gen) return;
      setState(() {
        _results = reset ? res.items : [..._results, ...res.items];
        _page = res.page;
        _hasNext = res.hasNext && res.items.isNotEmpty;
        _loading = false;
      });
      if (reset && _scroll.hasClients) _scroll.jumpTo(0);
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _maybeLoadMore() {
    if (!_scroll.hasClients || !_hasNext || _loading) return;
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 400) _load(reset: false);
  }

  void _onQueryChanged(String text) {
    _debounce?.cancel();
    _autoDebounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 380), () {
      setState(() => _section =
          _q.isEmpty ? _KlipySection.trending : _KlipySection.search);
      _load(reset: true);
    });
    if (text.trim().isEmpty) {
      setState(() => _suggestions = const []);
      return;
    }
    _autoDebounce = Timer(const Duration(milliseconds: 160), () {
      widget.klipy.autocomplete(text).then((s) {
        if (mounted && _query.text == text) setState(() => _suggestions = s);
      }).catchError((Object _) {});
    });
  }

  void _runQuery(String q) {
    _query.value = TextEditingValue(
      text: q,
      selection: TextSelection.collapsed(offset: q.length),
    );
    _debounce?.cancel();
    setState(() {
      _suggestions = const [];
      _section = _KlipySection.search;
    });
    _load(reset: true);
  }

  void _showSection(_KlipySection s) {
    HapticFeedback.selectionClick();
    _query.clear();
    _focus.unfocus();
    setState(() {
      _section = s;
      _suggestions = const [];
    });
    if (s == _KlipySection.trending) _load(reset: true);
  }

  List<_Tile> _tiles() {
    final store = ExpressionStore.instance;
    bool mine(ExpressionItem i) =>
        i.source == ExpressionSource.klipy && i.kind == widget.kind;
    switch (_section) {
      case _KlipySection.recent:
        return [for (final i in store.recents.where(mine)) _Tile.item(i)];
      case _KlipySection.favorites:
        return [for (final i in store.favorites.where(mine)) _Tile.item(i)];
      case _KlipySection.trending:
      case _KlipySection.search:
        return [
          for (final r in _results)
            switch (r) {
              KlipyMedia m => _Tile.media(m),
              KlipyAd a => _Tile.ad(a),
            },
        ];
    }
  }

  void _send(_Tile t) {
    final item = t.item;
    if (item == null || item.url == null) return;
    HapticFeedback.lightImpact();
    widget.onSend(
      item,
      query: _section == _KlipySection.search ? _q : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final typing = _focus.hasFocus && _query.text.trim().isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
          child: Container(
            height: 36,
            decoration: theme.inputDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(CupertinoIcons.search, size: 15, color: theme.inkMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _query,
                    focusNode: _focus,
                    onChanged: _onQueryChanged,
                    onSubmitted: (q) => q.trim().isEmpty ? null : _runQuery(q),
                    textInputAction: TextInputAction.search,
                    style: theme.body.copyWith(color: theme.ink),
                    cursorColor: theme.accent,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      // KLIPY's one mandatory attribution: this placeholder.
                      hintText: l10n.expressionSearchKlipy,
                      hintStyle: theme.body.copyWith(color: theme.inkMuted),
                      hintMaxLines: 1,
                    ),
                  ),
                ),
                if (_query.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showSection(_KlipySection.trending),
                    child: Icon(CupertinoIcons.clear_circled_solid,
                        size: 16, color: theme.inkMuted),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: typing
                ? [
                    for (final s in _suggestions)
                      _Chip(label: s, onTap: () => _runQuery(s)),
                  ]
                : [
                    _Chip(
                      label: l10n.expressionTrending,
                      selected: _section == _KlipySection.trending,
                      onTap: () => _showSection(_KlipySection.trending),
                    ),
                    _Chip(
                      label: l10n.expressionRecent,
                      icon: CupertinoIcons.clock,
                      selected: _section == _KlipySection.recent,
                      onTap: () => _showSection(_KlipySection.recent),
                    ),
                    _Chip(
                      label: l10n.expressionFavorites,
                      icon: CupertinoIcons.star,
                      selected: _section == _KlipySection.favorites,
                      onTap: () => _showSection(_KlipySection.favorites),
                    ),
                    for (final c in _categories)
                      _Chip(
                        label: c.name,
                        selected: _section == _KlipySection.search &&
                            _q == c.query,
                        onTap: () => _runQuery(c.query),
                      ),
                  ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListenableBuilder(
            listenable: ExpressionStore.instance,
            builder: (context, _) => _grid(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: const KlipyAttribution(compact: true),
          ),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final tiles = _tiles();
    final remote = _section == _KlipySection.trending ||
        _section == _KlipySection.search;

    if (tiles.isEmpty) {
      if (remote && (_loading || (_error == null && _page == 0))) {
        return const _GridSkeleton();
      }
      final String message;
      if (_error != null) {
        message = l10n.expressionLoadFailed;
      } else if (_section == _KlipySection.recent) {
        message = l10n.expressionNoRecents;
      } else if (_section == _KlipySection.favorites) {
        message = l10n.expressionNoFavorites;
      } else {
        message = l10n.expressionNoResults;
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                style: theme.caption.copyWith(color: theme.inkMuted),
                textAlign: TextAlign.center),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _Chip(
                  label: l10n.expressionRetry,
                  onTap: () => _load(reset: true),
                ),
              ),
          ],
        ),
      );
    }

    final autoplay = expressionsAutoplay(context);
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth - 16;
      widget.klipy.adMaxWidth = width;
      final rows = justifiedRows(
        [
          for (final t in tiles)
            t.ad != null
                ? RowInput.fixed(t.ad!.width, t.ad!.height)
                : RowInput.picture(t.aspect),
        ],
        maxWidth: width,
        targetHeight: _isSticker ? 84 : 110,
      );
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        itemCount: rows.length + (remote && _hasNext ? 1 : 0),
        itemBuilder: (context, r) {
          if (r >= rows.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CupertinoActivityIndicator()),
            );
          }
          final row = rows[r];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < row.count; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  _tile(tiles[row.start + i], row.widths[i], row.height,
                      autoplay),
                ],
              ],
            ),
          );
        },
      );
    });
  }

  Widget _tile(_Tile t, double w, double h, bool autoplay) {
    final ad = t.ad;
    if (ad != null) {
      return SizedBox(width: w, height: h, child: KlipyAdTile(ad: ad));
    }
    final item = t.item!;
    final url = t.gridUrl;
    return _PressableTile(
      onTap: () => _send(t),
      onLongPress: () => showExpressionSheet(context, item),
      semanticLabel: item.title,
      child: url == null
          ? ExpressionPlaceholder(width: w, height: h)
          : KlipyImage(
              url: url,
              width: w,
              height: h,
              fit: _isSticker ? BoxFit.contain : BoxFit.cover,
              radius: _isSticker ? 0 : 8,
              play: autoplay,
              blurPreview: t.media?.blurPreview,
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = selected ? theme.accent : theme.inkSoft;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FocusableTap(
        onTap: onTap,
        semanticLabel: label,
        selected: selected,
        radius: 999,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? theme.accentSoft : theme.surfaceRaised,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected ? Colors.transparent : theme.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 4),
                ],
                Text(label, style: theme.caption.copyWith(color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A tile that sends on tap and opens the sheet on a hold, with a small press
/// scale so a tap visibly lands.
class _PressableTile extends StatefulWidget {
  const _PressableTile({
    required this.child,
    required this.onTap,
    required this.onLongPress,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? semanticLabel;

  @override
  State<_PressableTile> createState() => _PressableTileState();
}

class _PressableTileState extends State<_PressableTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      onLongPressHint: AppLocalizations.of(context).expressionOptionsHint,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        onLongPress: () {
          HapticFeedback.mediumImpact();
          setState(() => _down = false);
          widget.onLongPress();
        },
        child: AnimatedScale(
          scale: _down ? 0.92 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

/// The grid's one sweeping skeleton while a first page is in flight.
class _GridSkeleton extends StatefulWidget {
  const _GridSkeleton();

  @override
  State<_GridSkeleton> createState() => _GridSkeletonState();
}

class _GridSkeletonState extends State<_GridSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final color =
            theme.inkMuted.withValues(alpha: 0.10 + 0.10 * _c.value);
        return LayoutBuilder(builder: (context, constraints) {
          const widths = [1.3, 0.9, 1.1, 1.0, 1.4, 0.8];
          final rows = justifiedRows(
            [for (var i = 0; i < 12; i++) RowInput.picture(widths[i % 6])],
            maxWidth: constraints.maxWidth - 16,
          );
          return ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      for (var i = 0; i < row.count; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Container(
                          width: row.widths[i],
                          height: row.height,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        });
      },
    );
  }
}

// ─── Stickers ───────────────────────────────────────────────────────────────

class _StickersTab extends StatefulWidget {
  const _StickersTab({
    required this.onSend,
    this.onCreateSticker,
    this.onSearchFocusChanged,
  });

  final void Function(ExpressionItem item, {String? query}) onSend;
  final VoidCallback? onCreateSticker;
  final ValueChanged<bool>? onSearchFocusChanged;

  @override
  State<_StickersTab> createState() => _StickersTabState();
}

class _StickersTabState extends State<_StickersTab> {
  /// 'recent', 'favorites', 'klipy', or a pack id. Remembered for the session.
  static String? _lastSection;
  String? _section = _lastSection;

  void _select(String s) {
    HapticFeedback.selectionClick();
    setState(() => _section = _lastSection = s);
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
        bool usable(ExpressionItem i) =>
            i.isSticker &&
            (outside || i.source == ExpressionSource.pack);
        final recents = store.recents.where(usable).toList();
        final favorites = store.favorites.where(usable).toList();
        final packs = [
          for (final p in store.packs)
            if (!p.personal || outside) p,
        ];
        final klipy = outside ? store.klipy : null;
        final personal = packs.where((p) => p.personal).firstOrNull;

        final keys = <String>[
          if (recents.isNotEmpty) 'recent',
          if (favorites.isNotEmpty) 'favorites',
          for (final p in packs) p.id,
          if (klipy != null) 'klipy',
        ];
        var section = _section;
        if (section == null || !keys.contains(section)) {
          section = keys.isEmpty ? null : keys.first;
        }

        Widget body;
        if (section == 'klipy' && klipy != null) {
          body = _KlipyBrowser(
            key: const ValueKey('klipy-stickers'),
            kind: ExpressionKind.sticker,
            klipy: klipy,
            onSend: widget.onSend,
            onSearchFocusChanged: widget.onSearchFocusChanged,
          );
        } else if (section == 'recent') {
          body = _StickerGrid(items: recents, onSend: widget.onSend);
        } else if (section == 'favorites') {
          body = _StickerGrid(items: favorites, onSend: widget.onSend);
        } else if (section != null) {
          final pack = packs.firstWhere((p) => p.id == section);
          body = _PackGrid(
            pack: pack,
            onSend: widget.onSend,
            onCreateSticker: pack.personal ? widget.onCreateSticker : null,
          );
        } else if (!store.packsLoaded) {
          body = const _GridSkeleton();
        } else {
          body = Center(
            child: Text(
              l10n.expressionNoStickers,
              style: theme.caption.copyWith(color: theme.inkMuted),
              textAlign: TextAlign.center,
            ),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  if (recents.isNotEmpty)
                    _StripButton(
                      selected: section == 'recent',
                      label: l10n.expressionRecent,
                      onTap: () => _select('recent'),
                      child: Icon(CupertinoIcons.clock,
                          size: 20, color: theme.inkMuted),
                    ),
                  if (favorites.isNotEmpty)
                    _StripButton(
                      selected: section == 'favorites',
                      label: l10n.expressionFavorites,
                      onTap: () => _select('favorites'),
                      child: Icon(CupertinoIcons.star,
                          size: 20, color: theme.inkMuted),
                    ),
                  for (final p in packs)
                    _StripButton(
                      selected: section == p.id,
                      label: p.personal ? l10n.expressionMyStickers : p.title,
                      onTap: () => _select(p.id),
                      child: p.stickers.isEmpty
                          ? Icon(CupertinoIcons.person_crop_circle,
                              size: 20, color: theme.inkMuted)
                          : StickerArt(
                              item: p.stickers.first.toItem(),
                              url: p.stickers.first.url,
                              size: 28,
                              play: false,
                            ),
                    ),
                  if (klipy != null)
                    _StripButton(
                      selected: section == 'klipy',
                      label: l10n.expressionSearchKlipy,
                      onTap: () => _select('klipy'),
                      child: Icon(CupertinoIcons.search,
                          size: 20, color: theme.inkMuted),
                    ),
                  if (widget.onCreateSticker != null && personal == null)
                    _StripButton(
                      selected: false,
                      label: l10n.expressionCreateSticker,
                      onTap: widget.onCreateSticker!,
                      child: Icon(CupertinoIcons.add_circled,
                          size: 20, color: theme.accent),
                    ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        );
      },
    );
  }
}

class _StripButton extends StatelessWidget {
  const _StripButton({
    required this.selected,
    required this.label,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Tooltip(
      message: label,
      child: FocusableTap(
        onTap: onTap,
        semanticLabel: label,
        selected: selected,
        radius: 10,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? theme.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Five-across grid of stickers from recents or favourites — a mix of pack and
/// KLIPY stickers.
class _StickerGrid extends StatelessWidget {
  const _StickerGrid({required this.items, required this.onSend});

  final List<ExpressionItem> items;
  final void Function(ExpressionItem item, {String? query}) onSend;

  @override
  Widget build(BuildContext context) {
    final autoplay = expressionsAutoplay(context);
    return LayoutBuilder(builder: (context, constraints) {
      final columns = math.max(4, (constraints.maxWidth / 84).floor());
      final size = (constraints.maxWidth - 16) / columns - 6;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return _PressableTile(
            onTap: () {
              HapticFeedback.lightImpact();
              onSend(item);
            },
            onLongPress: () => showExpressionSheet(context, item),
            semanticLabel: item.title,
            child: Center(
              child: StickerArt(
                item: item,
                size: size,
                api: ExpressionStore.instance.api,
                play: autoplay,
              ),
            ),
          );
        },
      );
    });
  }
}

class _PackGrid extends StatelessWidget {
  const _PackGrid({
    required this.pack,
    required this.onSend,
    this.onCreateSticker,
  });

  final StickerPack pack;
  final void Function(ExpressionItem item, {String? query}) onSend;
  final VoidCallback? onCreateSticker;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final autoplay = expressionsAutoplay(context);
    final create = onCreateSticker;
    final count = pack.stickers.length + (create != null ? 1 : 0);
    return LayoutBuilder(builder: (context, constraints) {
      final columns = math.max(4, (constraints.maxWidth / 84).floor());
      final size = (constraints.maxWidth - 16) / columns - 6;
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
              child: Text(
                pack.personal
                    ? l10n.expressionMyStickers
                    : (pack.author == null
                        ? pack.title
                        : '${pack.title} · ${l10n.expressionPackCredit(pack.author!, pack.license ?? '')}'),
                style: theme.monoTiny.copyWith(color: theme.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              delegate: SliverChildBuilderDelegate(
                childCount: count,
                (context, i) {
                  if (create != null && i == 0) {
                    return _PressableTile(
                      onTap: create,
                      onLongPress: create,
                      semanticLabel: l10n.expressionCreateSticker,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.divider, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Icon(CupertinoIcons.add,
                            size: 26, color: theme.accent),
                      ),
                    );
                  }
                  final s = pack.stickers[i - (create != null ? 1 : 0)];
                  final item = s.toItem();
                  return _PressableTile(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSend(item);
                    },
                    onLongPress: () => showExpressionSheet(context, item),
                    semanticLabel: s.emoji,
                    child: Center(
                      child: StickerArt(
                        item: item,
                        url: s.url,
                        size: size,
                        play: autoplay,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Owns whether the panel is open and how tall it is, and trades places with
/// the keyboard.
///
/// The height is the keyboard's own, learned the last time it was up, so
/// toggling between keyboard and panel moves nothing above them — the way
/// WhatsApp and Telegram behave. Before the keyboard has ever been seen (a
/// desktop, or a fresh launch) it falls back to [defaultHeight].
class ExpressionPanelController extends ChangeNotifier {
  ExpressionPanelController({this.defaultHeight = 300});

  final double defaultHeight;

  bool _open = false;

  /// Whether the panel is mounted — including the moment after [close] while
  /// the keyboard rises into its place.
  bool get isOpen => _open;

  /// True in that moment: the panel is still drawn (shrinking as the keyboard
  /// covers it) but the composer's toggle already shows the smiley again.
  bool _closing = false;
  bool get closing => _closing;
  Timer? _closeTimer;

  /// Whether a search field inside the panel has the keyboard. The panel stays
  /// open, shorter, above it.
  bool _searching = false;
  bool get searching => _searching;

  double? _keyboardHeight;

  /// Call on every build with `MediaQuery.viewInsetsOf(context).bottom`.
  void noteKeyboardInset(double inset) {
    if (inset > 120 && !_searching) _keyboardHeight = inset;
  }

  double get height =>
      (_keyboardHeight ?? defaultHeight).clamp(240.0, 420.0);

  /// The panel's height while a search field has the keyboard — enough for two
  /// rows of results between the field and the keys.
  double get searchingHeight => 230;

  void open(FocusNode composerFocus) {
    if (_open && !_closing) return;
    _closeTimer?.cancel();
    _closing = false;
    composerFocus.unfocus();
    _open = true;
    notifyListeners();
  }

  /// Back to the keyboard.
  ///
  /// The panel stays mounted for as long as the keyboard takes to rise, drawn
  /// only where the keyboard does not yet cover it (see
  /// [ExpressionPanel.keyboardInset]) — so the composer rides the keyboard up
  /// instead of dropping to the floor and jumping back.
  void close(FocusNode composerFocus) {
    if (!_open || _closing) return;
    _handOver();
    composerFocus.requestFocus();
  }

  /// Only phones and tablets have a keyboard that slides up to take the
  /// panel's place; on a desktop there is nothing to wait for.
  static bool get _softKeyboard =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  void _handOver() {
    _searching = false;
    if (!_softKeyboard) {
      _open = false;
      notifyListeners();
      return;
    }
    _closing = true;
    notifyListeners();
    _closeTimer?.cancel();
    _closeTimer = Timer(const Duration(milliseconds: 450), _finishClose);
  }

  void _finishClose() {
    if (!_closing) return;
    _closing = false;
    _open = false;
    notifyListeners();
  }

  void toggle(FocusNode composerFocus) =>
      _open && !_closing ? close(composerFocus) : open(composerFocus);

  /// Puts the panel away because the keyboard is coming back by some other
  /// route — the field was tapped, or took focus. A close already under way
  /// is left to finish its hand-over.
  void dismiss() {
    if (!_open || _closing) return;
    _handOver();
  }

  /// Puts the panel away at once, with no keyboard to hand over to — the
  /// system back gesture.
  void hide() {
    if (!_open) return;
    _closeTimer?.cancel();
    _closing = false;
    _open = false;
    _searching = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  void setSearching(bool v) {
    if (_searching == v) return;
    _searching = v;
    notifyListeners();
  }
}
