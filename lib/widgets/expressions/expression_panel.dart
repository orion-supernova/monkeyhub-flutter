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
import '../../theme/motion.dart';
import '../../theme/theme_scope.dart';
import '../search_field.dart' show SearchField;
import '../reaction_picker_sheet.dart' show EmojiSearchBar, EmojiSearchView;
import 'expression_media.dart';
import 'expression_sheet.dart';
import 'klipy_ad_tile.dart';
import 'klipy_attribution.dart';
import 'sticker_pack_store.dart';
import 'sticker_search.dart';
import '../teardown_safe.dart';
import '../ios_kit.dart';
import '../sheet_kit.dart' show SheetCloseButton, SheetHandle;
import '../skeleton_rows.dart' show SkeletonBox, SkeletonSweep;
import '../desktop_scroll.dart';

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
    this.controller,
  });

  /// Owns the panel's two levels. Present, the header becomes a drag handle
  /// between the keyboard's height and nearly the whole screen; null (tests,
  /// previews) leaves a fixed-height panel.
  final ExpressionPanelController? controller;

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

  /// The keyboard inset the panel was last laid out against — see the
  /// height animation in [build].
  double? _lastInset;

  /// False for the first frame only, so a panel opened with no keyboard up
  /// grows in from nothing rather than appearing at full height — the host's
  /// chrome does not animate its size while the panel is involved.
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    // Opened from the keyboard, it must not grow: it takes the keyboard's
    // place at full height on its first frame, and the keyboard slides away
    // over it. Grown from nothing, the composer fell with the keyboard to an
    // empty floor and jumped back up once the panel caught up — the keyboard
    // seemed to vanish and come back.
    _shown = (widget.controller?.keyboardInset ?? 0) > 0;
    if (!_shown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _shown = true);
      });
    }
    // Before the first trending request, so it can already carry the browser
    // agent KLIPY needs to serve an ad.
    unawaited(primeKlipyUserAgent());
  }

  void _select(_Tab tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() => _tab = _lastTab = tab);
  }

  /// Where a search field reports taking the keyboard: the host's callback if
  /// it gave one, otherwise the panel's own controller — so a host cannot
  /// forget to wire it and leave a search squeezed under the keyboard.
  ValueChanged<bool>? get _searchFocusChanged =>
      widget.onSearchFocusChanged ?? widget.controller?.setSearching;

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
        // Handing over to or from the keyboard, the panel shows in step
        // with how far the keyboard has gone: none of it while the keyboard
        // is all the way up, all of it once it is down. `full - inset` (the
        // panel exactly where the keyboard is not) was right only when the
        // two stand the same height. The resting panel is taller, and its
        // extra strip appeared in one frame on the way in — the composer
        // jumped up — and vanished in one on the way out — it dropped.
        final kb = widget.keyboardInset;
        final kbFull = widget.controller?.keyboardFullHeight;
        final visible = kb <= 0
            ? full
            : kbFull != null && kbFull > 0
                ? full * (1 - (kb / kbFull).clamp(0.0, 1.0))
                : math.max(0.0, full - kb);
        final dragging = widget.controller?.dragging ?? false;
        // Not while the keyboard is moving either. Opening or closing it moves
        // this height on every frame of its slide, and a tween restarted on every
        // frame trails behind and lands late — a lag and a catch-up that read
        // as a spring. The keyboard is already animating; following it frame
        // for frame is the smooth version. Read from the controller, which the
        // host feeds the real inset: under the host's Scaffold this context's
        // own MediaQuery has had it taken out, and always says 0.
        final inset = widget.controller?.keyboardInset ?? 0;
        final keyboardMoving = _lastInset != null && inset != _lastInset;
        _lastInset = inset;
        // Animated between levels, but not under a finger: while dragging the
        // panel must track the handle exactly, or it lags and feels loose.
        return AnimatedContainer(
          duration: dragging ||
                  keyboardMoving ||
                  MotionScope.of(context).calm
              ? Duration.zero
              : const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          height: _shown || MotionScope.of(context).calm ? visible : 0,
          // Laid out at its full height and NOT clipped to the part showing:
          // the rest hangs down behind the keyboard. The keyboard animates on
          // its own, between the app's frames, and the first frames of a
          // panel opening are heavy ones — clipped, every frame the app ran
          // late uncovered an empty floor below the composer, and the panel
          // popped in after it: the keyboard seemed to vanish and come back.
          // With the panel already drawn under it, a sliding keyboard only
          // ever uncovers the panel, the way a native one does.
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: full,
            maxHeight: full,
            child: _body(context, theme, l10n, store, gifsAvailable, tab),
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
            // A hairline, as the iOS keyboard draws its top edge.
            border: Border(
              top: BorderSide(
                color: theme.ink.withValues(alpha: 0.08),
                width: 1 / MediaQuery.devicePixelRatioOf(context),
              ),
            ),
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
                  _DragHeader(
                    controller: widget.controller,
                    child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
                    child: Row(
                      children: [
                        Expanded(
                          // THE segmented control — one track, one thumb,
                          // one label size app-wide.
                          child: IosSegmentedControl<_Tab>(
                            segments: [
                              IosSegment(
                                value: _Tab.emoji,
                                label: l10n.expressionTabEmoji,
                              ),
                              if (gifsAvailable)
                                IosSegment(
                                  value: _Tab.gifs,
                                  label: l10n.expressionTabGifs,
                                ),
                              IosSegment(
                                value: _Tab.stickers,
                                label: l10n.expressionTabStickers,
                              ),
                            ],
                            value: tab,
                            onChanged: _select,
                          ),
                        ),
                        // Puts the panel away without bringing the keyboard
                        // back — THE sheet ×, flat (never glass: this panel
                        // slides, and a sliding blur re-rasterises).
                        if (widget.controller != null) ...[
                          const SizedBox(width: 10),
                          SheetCloseButton(onTap: widget.controller!.hide),
                        ],
                      ],
                    ),
                  ),
                  ),
                  Expanded(
                    child: switch (tab) {
                      _Tab.emoji => _EmojiTab(
                          composer: widget.composer,
                          onSearchFocusChanged: _searchFocusChanged,
                        ),
                      _Tab.gifs => _KlipyBrowser(
                          key: const ValueKey('klipy-gifs'),
                          kind: ExpressionKind.gif,
                          klipy: store.klipy!,
                          onSend: widget.onSend,
                          onSearchFocusChanged: _searchFocusChanged,
                        ),
                      _Tab.stickers => _StickersTab(
                          onSend: widget.onSend,
                          onCreateSticker: store.canUseOutsideMedia
                              ? widget.onCreateSticker
                              : null,
                          onSearchFocusChanged: _searchFocusChanged,
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

/// The panel's grab handle: a pill above the tabs, with the whole header strip
/// as the drag area so it is easy to catch.
///
/// Vertical drags move the panel between its two levels; a tap on the pill
/// toggles them, which is also the route for anyone who cannot drag — the
/// same action is offered to screen readers.
class _DragHeader extends StatelessWidget {
  const _DragHeader({required this.controller, required this.child});

  final ExpressionPanelController? controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final l10n = AppLocalizations.of(context);
    if (c == null) {
      return Padding(padding: const EdgeInsets.only(top: 6), child: child);
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (d) => c.dragBy(d.delta.dy),
      onVerticalDragEnd: (d) => c.dragEnd(d.primaryVelocity ?? 0),
      onVerticalDragCancel: () => c.dragEnd(0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusableTap(
            onTap: c.toggleExpanded,
            semanticLabel: c.expanded
                ? l10n.expressionCollapsePanel
                : l10n.expressionExpandPanel,
            radius: 999,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: c.toggleExpanded,
              // THE grabber, with a wider catch area around it.
              child: const SizedBox(
                width: 72,
                child: SheetHandle(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ─── Emoji ──────────────────────────────────────────────────────────────────

class _EmojiTab extends StatelessWidget {
  const _EmojiTab({required this.composer, this.onSearchFocusChanged});

  final TextEditingController composer;
  final ValueChanged<bool>? onSearchFocusChanged;

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
              style: theme.bodySoft.copyWith(fontSize: 13),
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
              EmojiSearchView(
                config,
                state,
                showEmojiView,
                bottomSafe: 0,
                onSearchFocusChanged: onSearchFocusChanged,
              ),
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
    this.initialQuery,
  });

  final ExpressionKind kind;
  final KlipyClient klipy;
  final void Function(ExpressionItem item, {String? query}) onSend;
  final ValueChanged<bool>? onSearchFocusChanged;

  /// Opens already searching for this — a KLIPY category tile or a search
  /// carried over from the pack store.
  final String? initialQuery;

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

  /// What was last reported to the panel — see [StickerPackStore]'s
  /// identical field for why it is tracked rather than read at dispose.
  bool _reportedFocus = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus != _reportedFocus) {
        _reportedFocus = _focus.hasFocus;
        widget.onSearchFocusChanged?.call(_reportedFocus);
      }
      setState(() {});
    });
    _scroll.addListener(_maybeLoadMore);
    final initial = widget.initialQuery?.trim();
    if (initial != null && initial.isNotEmpty) {
      _query.text = initial;
      _section = _KlipySection.search;
    }
    _load(reset: true);
    widget.klipy.categories(widget.kind).then((c) {
      if (mounted) setState(() => _categories = c);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _autoDebounce?.cancel();
    // Switching tab mid-search must not strand the panel at its search
    // height; after the frame, as the tree is being torn down.
    final report = widget.onSearchFocusChanged;
    if (_reportedFocus && report != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => report(false));
    }
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

  /// The clear disc: back to Trending with the keyboard still up, so the
  /// next query can be typed straight away. Only the strip's tabs put the
  /// keyboard away ([_showSection]) — they are a choice to browse instead.
  void _clearQuery() {
    _debounce?.cancel();
    _autoDebounce?.cancel();
    _query.clear();
    setState(() {
      _section = _KlipySection.trending;
      _suggestions = const [];
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
    // Put the search keyboard away, so the panel drops back to its resting
    // height and the message that was just sent is on screen. The query and
    // its results stay, for a second pick.
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final typing = _focus.hasFocus && _query.text.trim().isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              Expanded(
                // THE search bar. It used to be a hand-drawn copy because it
                // carries a scope tag and runs its query on the Search key;
                // both are slots of the shared field now.
                child: SearchField(
                  controller: _query,
                  focusNode: _focus,
                  // KLIPY's one mandatory attribution: this placeholder.
                  hintText: l10n.expressionSearchKlipy,
                  onChanged: _onQueryChanged,
                  // Clearing goes back to Trending, not just to an empty box —
                  // and keeps the keyboard, like every other search field.
                  onClear: _clearQuery,
                  // The keyboard's Search key runs the search and gets out of
                  // the way, so the results have the room.
                  onSubmitted: (q) {
                    _focus.unfocus();
                    if (q.trim().isNotEmpty) _runQuery(q);
                  },
                  // A panel under the composer, not the top of a screen: the
                  // keyboard button beside it is how you put it away.
                  showCancel: false,
                  // Which of KLIPY's catalogues this box searches. The
                  // placeholder itself has to stay "Search KLIPY", so the
                  // scope goes beside it.
                  leadingAccessory: _ScopeTag(
                    label: _isSticker
                        ? l10n.expressionTabStickers
                        : l10n.expressionTabGifs,
                  ),
                ),
              ),
              if (_focus.hasFocus) HideKeyboardButton(focus: _focus),
            ],
          ),
        ),
        SizedBox(
          height: 32,
          child: HorizontalWheelScroll(
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
        ),
        // Room between the chips and the first row of GIFs, or the two read as
        // one crowded block — the chips looked stuck to the grid at 4.
        const SizedBox(height: 12),
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
                style: groupedFooterStyle(theme),
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
        // Scrolling the results is the usual way to say "enough typing".
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

/// A small label at the start of a search field naming what it searches.
class _ScopeTag extends StatelessWidget {
  const _ScopeTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: theme.ink.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: theme.bodySoft.copyWith(
              fontSize: 13,
              color: theme.inkSoft,
              fontWeight: FontWeight.w600)),
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
    // Solid accent when chosen, a neutral fill otherwise — no accent wash,
    // which on a dark theme is a navy lozenge.
    final color = selected ? theme.accentInk : theme.inkSoft;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
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
              color: selected
                  ? theme.accent
                  : theme.ink.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: theme.bodySoft.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
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

class _PressableTileState extends State<_PressableTile>
    with TeardownSafe<_PressableTile> {
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
        // A quick dip and an overshooting return — the tile visibly lands.
        child: AnimatedScale(
          scale: _down ? 0.9 : 1,
          duration: MotionScope.of(context).d(
            _down ? PressSpec.down : PressSpec.release,
          ),
          curve: _down ? PressSpec.downCurve : PressSpec.releaseCurve,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The grid's one sweeping skeleton while a first page is in flight.
/// The picture grid's placeholder: justified rows of boxes under ONE shared
/// sweep — the skeleton language every list in the app speaks, not a
/// private pulse with its own controller and colour maths.
class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonSweep(
      child: LayoutBuilder(builder: (context, constraints) {
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
                      SkeletonBox(
                        width: row.widths[i],
                        height: row.height,
                        radius: 8,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      }),
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

  final ScrollController _strip = ScrollController();

  /// The section the strip was last scrolled to show, so it scrolls once per
  /// change rather than on every rebuild.
  String? _revealed;

  /// One strip button's footprint: 40 wide plus 2 of margin each side.
  static const double _stripItemExtent = 44;
  static const double _stripPadding = 8;

  /// The tab's own search: our stickers and KLIPY's, together.
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  /// What was last reported to the panel — see [StickerPackStore]'s
  /// identical field for why it is tracked rather than read at dispose.
  bool _reportedFocus = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus != _reportedFocus) {
        _reportedFocus = _searchFocus.hasFocus;
        widget.onSearchFocusChanged?.call(_reportedFocus);
      }
      // The hide-keyboard button comes and goes with the focus.
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Leaving the tab mid-search must not strand the panel at its search
    // height; after the frame, as the tree is being torn down.
    final report = widget.onSearchFocusChanged;
    if (_reportedFocus && report != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => report(false));
    }
    _strip.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _select(String s) {
    HapticFeedback.selectionClick();
    setState(() {
      _section = _lastSection = s;
      // The strip's KLIPY button opens KLIPY on trending, not on whatever a
      // store category last searched for.
      if (s == 'klipy') _klipyQuery = null;
    });
  }

  /// What the KLIPY section opens searching for, when the pack store sent the
  /// user there with a category or a query.
  String? _klipyQuery;

  void _openKlipy(String query) {
    HapticFeedback.selectionClick();
    _searchFocus.unfocus();
    _search.clear();
    setState(() {
      _klipyQuery = query;
      _section = _lastSection = 'klipy';
    });
  }

  /// Centres strip button [index] — jumping there when the panel opens on a
  /// remembered pack, sliding when the user picks one.
  ///
  /// Computed from the fixed button width rather than by asking a button to
  /// reveal itself: the strip is a lazy list, so a pack far to the right has
  /// no widget to ask until it has been scrolled to.
  void _revealStripItem(int index, {required bool animate}) {
    if (!_strip.hasClients) return;
    final pos = _strip.position;
    final centre = _stripPadding + index * _stripItemExtent + _stripItemExtent / 2;
    final target =
        (centre - pos.viewportDimension / 2).clamp(0.0, pos.maxScrollExtent);
    if (animate && !MotionScope.of(context).calm) {
      _strip.animateTo(target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic);
    } else {
      _strip.jumpTo(target);
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
        final outside = store.canUseOutsideMedia;
        bool usable(ExpressionItem i) =>
            i.isSticker &&
            (outside || i.source == ExpressionSource.pack);
        final recents = store.recents.where(usable).toList();
        final favorites = store.favorites.where(usable).toList();
        // The user's own pack leads, straight after Recent and Favorites: it
        // is what they reach for most, and at the end of a growing strip it
        // would be the one pack that always needs scrolling to.
        final personal = outside
            ? store.packs.where((p) => p.personal).firstOrNull
            : null;
        final packs = [
          ?personal,
          for (final p in store.packs)
            if (!p.personal) p,
        ];
        final klipy = outside ? store.klipy : null;
        final offerCreate = widget.onCreateSticker != null && personal == null;

        final keys = <String>[
          if (recents.isNotEmpty) 'recent',
          if (favorites.isNotEmpty) 'favorites',
          for (final p in packs) p.id,
          if (klipy != null) 'klipy',
          '_store',
        ];
        var section = _section;
        if (!store.packsLoaded) {
          // Nothing to resolve against yet: the skeleton below, not the store
          // or a first pack that is about to be replaced.
          section = null;
        } else if (section == null || !keys.contains(section)) {
          section = keys.isEmpty ? null : keys.first;
        }

        // Bring the selected pack into view whenever it changes — including
        // the first time the packs arrive with a remembered one far along the
        // strip. Indexed by strip position, so the "make a sticker" button
        // that stands in for a missing personal pack counts too.
        final stripOrder = [
          if (recents.isNotEmpty) 'recent',
          if (favorites.isNotEmpty) 'favorites',
          if (offerCreate) '_create',
          for (final p in packs) p.id,
          if (klipy != null) 'klipy',
          '_store',
        ];
        if (section != null && section != _revealed) {
          final index = stripOrder.indexOf(section);
          final animate = _revealed != null;
          _revealed = section;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _revealStripItem(index, animate: animate);
          });
        }

        Widget body;
        if (section == '_store') {
          body = StickerPackStore(
            onOpenPack: _select,
            onSearchFocusChanged: widget.onSearchFocusChanged,
            onOpenKlipy: klipy == null ? null : _openKlipy,
          );
        } else if (section == 'klipy' && klipy != null) {
          body = _KlipyBrowser(
            // Keyed by the query it opened on, so choosing another category
            // from the store starts a fresh search rather than keeping the
            // last one.
            key: ValueKey('klipy-stickers-$_klipyQuery'),
            kind: ExpressionKind.sticker,
            klipy: klipy,
            onSend: widget.onSend,
            onSearchFocusChanged: widget.onSearchFocusChanged,
            initialQuery: _klipyQuery,
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
              style: groupedFooterStyle(theme),
              textAlign: TextAlign.center,
            ),
          );
        }

        // The KLIPY browser and the pack store bring search fields of their
        // own; everywhere else the tab's search sits on top.
        final searching = _search.text.trim().isNotEmpty;
        final showSearch =
            searching || (section != 'klipy' && section != '_store');
        final field = StickerSearchField(
          controller: _search,
          focus: _searchFocus,
          onChanged: (_) => setState(() {}),
        );
        if (searching) {
          return Column(
            children: [
              field,
              Expanded(
                child: StickerSearchResults(
                  query: _search.text,
                  onSend: widget.onSend,
                  onOpenKlipy: klipy == null ? null : _openKlipy,
                  onPicked: _searchFocus.unfocus,
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            if (showSearch) field,
            SizedBox(
              height: 44,
              child: HorizontalWheelScroll(
                child: ListView(
                  controller: _strip,
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: _stripPadding),
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
                    // Where "My stickers" will be once there is one.
                    if (offerCreate)
                      _StripButton(
                        selected: false,
                        label: l10n.expressionCreateSticker,
                        onTap: widget.onCreateSticker!,
                        child: Icon(CupertinoIcons.add_circled,
                            size: 20, color: theme.accent),
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
                    // The pack store: find, add, remove and reorder packs.
                    _StripButton(
                      selected: section == '_store',
                      label: l10n.expressionPackStore,
                      onTap: () => _select('_store'),
                      child: Icon(CupertinoIcons.square_grid_2x2,
                          size: 20, color: theme.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
            // Keyed by section, so every pack opens at its top. Unkeyed, the
            // grid widget was reused from one pack to the next and kept the
            // previous pack's scroll position.
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('section-$section'),
                child: body,
              ),
            ),
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
              color: selected
                  ? theme.ink.withValues(alpha: 0.10)
                  : theme.ink.withValues(alpha: 0),
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
      // Five across on a phone, the density Telegram and WhatsApp settle on.
      final columns = math.max(5, (constraints.maxWidth / 76).floor());
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
      // Five across on a phone, the density Telegram and WhatsApp settle on.
      final columns = math.max(5, (constraints.maxWidth / 76).floor());
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
                style: theme.bodySoft.copyWith(
                  fontSize: 13,
                  color: theme.inkMuted,
                ),
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
/// The composer row, folded away while a search inside the expression panel
/// has the keyboard.
///
/// WhatsApp's answer to searching GIFs and stickers on a phone: the keyboard,
/// the composer AND the panel cannot all share the bottom half of a screen,
/// so while the search field has focus the composer steps aside and the panel
/// takes its room. Leaving the search (the back chevron, a tab switch, a
/// send) brings it back. Kept mounted, offstage, so the field's text, focus
/// node and the recorder's state survive the round trip; the host adds
/// [ExpressionPanelController.composerRow] to the panel's search budget.
class ComposerSearchTakeover extends StatelessWidget {
  const ComposerSearchTakeover({
    super.key,
    required this.controller,
    required this.child,
  });

  final ExpressionPanelController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) => Visibility(
        visible: !(controller.isOpen && controller.searching),
        maintainState: true,
        child: child!,
      ),
      child: child,
    );
  }
}

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

  /// How tall the keyboard stood the last time it came to rest all the way
  /// up. Any single frame could be one of a keyboard's frames on the way up
  /// or down, and a trip can turn back halfway (a tab switch mid-search), so
  /// only an inset that holds still is believed.
  double? _keyboardUp;

  /// The same, for a search field's keyboard. Remembered on its own: the
  /// composer's keyboard carries a suggestion bar a search's does not, so
  /// it stands ~35pt taller, and a search sized for it settled with a step.
  double? _searchKeyboardUp;
  double _lastNotedInset = 0;

  /// Call on every build with `MediaQuery.viewInsetsOf(context).bottom`.
  void noteKeyboardInset(double inset) {
    if (inset > 120 && !_searching) _keyboardHeight = inset;
    if (inset > 120 && inset == _lastNotedInset) {
      if (_searching) {
        _searchKeyboardUp = inset;
      } else {
        _keyboardUp = inset;
      }
    }
    _lastNotedInset = inset;
  }

  /// The keyboard a search should expect: its own, once one has been seen.
  double? get _expectedSearchKeyboard => _searchKeyboardUp ?? _keyboardUp;

  /// Half the screen, as the host measured it in [setLayout] — enough to
  /// browse a few rows of GIFs or stickers without dragging, while the
  /// conversation keeps the other half. Before the host has measured (tests,
  /// previews) it falls back to the keyboard's height.
  double? _restingHeight;

  /// The resting height the panel opens at.
  double get height =>
      _restingHeight ?? (_keyboardHeight ?? defaultHeight).clamp(240.0, 420.0);

  // ── The two levels ─────────────────────────────────────────────────────
  //
  // Collapsed is the keyboard's height; expanded is nearly the whole screen,
  // leaving the composer and a sliver of the conversation — the layout the
  // user drags up to when they want to browse or search properly. The host
  // measures what "nearly the whole screen" means on every build
  // ([setLayout]); a drag on the panel's header moves between the two live
  // and snaps with the gesture's velocity.

  double _expandedHeight = 520;
  double _room = 230;
  double _inset = 0;
  double _pad = 0;

  /// The keyboard's inset as the host last measured it.
  double get keyboardInset => _inset;

  /// The composer's keyboard at rest, all the way up — what the panel trades
  /// places with. Null until one has been seen.
  double? get keyboardFullHeight => _keyboardUp;

  /// What the panel showed the moment a search took focus, padding
  /// included. The search height is blended from this as the keyboard rises.
  double? _searchFrom;
  bool _expanded = false;
  double? _dragHeight;

  bool get expanded => _expanded;

  /// Whether a finger is on the handle right now — the host draws the height
  /// without animation while it is, so the panel tracks the finger exactly.
  bool get dragging => _dragHeight != null;

  /// Tells the controller how much room the host has. Called from `build`, so
  /// it never notifies: the values are read in the same build that set them.
  ///
  /// [expanded] is the tallest the panel may grow with the keyboard down;
  /// [room] is the same budget measured for a search — what the panel could
  /// take if no keyboard were up — and [keyboardInset] is the keyboard's
  /// inset right now.
  void setLayout({
    required double expanded,
    required double room,
    double keyboardInset = 0,
    double bottomPadding = 0,
    double? resting,
  }) {
    if (resting != null) {
      // Never taller than the expanded level, never too short to browse.
      _restingHeight = resting.clamp(240.0, math.max(240.0, expanded));
    }
    _expandedHeight = math.max(expanded, height);
    _room = room;
    // The blend below is for the keyboard's way UP only. Once it is all the
    // way up — or the moment it starts back down, which is what switching
    // tab mid-search does: the field goes with the old tab, and the panel
    // hears the search is over a frame later — the panel holds its search
    // height, and the keyboard carries it down from there. Blending on the
    // way down ran the rise backwards and threw the panel back up to the
    // size it had before the search.
    if (_searchFrom != null &&
        (keyboardInset < _inset ||
            keyboardInset >= (_expectedSearchKeyboard ?? double.infinity))) {
      _searchFrom = null;
    }
    _inset = keyboardInset;
    _pad = bottomPadding;
  }

  /// The height to lay the panel out at now.
  double get currentHeight {
    if (_searching) {
      // Blended by how far up the keyboard is. Shrinking to the search height
      // at once dropped everything above the panel before the keyboard had
      // moved, and the keyboard then carried it back up: a dip and a rise,
      // which read as a bounce. Tied to the keyboard's progress, the composer
      // only ever travels up, and at the keyboard's own pace.
      final from = _searchFrom;
      final up = _expectedSearchKeyboard;
      if (from != null && up != null && _inset < up) {
        final t = (_inset / up).clamp(0.0, 1.0);
        return from + (searchingHeight - from) * t;
      }
      return searchingHeight;
    }
    return _dragHeight ?? (_expanded ? _expandedHeight : height);
  }

  /// While a search field has the keyboard the panel takes all the room left
  /// above it — searching is when people most want to see results.
  ///
  /// Measured against the keyboard's FULL height, not its inset this frame.
  /// A search starts on the frame the field takes focus, before the keyboard
  /// has begun to rise: against an inset of 0 the room above it was nearly
  /// the whole screen, the panel shot up to fill it and then sank back as the
  /// keyboard came up. The keyboard that was just put away for the panel
  /// already said how tall it is.
  double get searchingHeight =>
      math.max(200.0, _room - math.max(_inset, _expectedSearchKeyboard ?? 0));

  void dragBy(double dy) {
    final base = _dragHeight ?? (_expanded ? _expandedHeight : height);
    _dragHeight = (base - dy).clamp(height, _expandedHeight);
    notifyListeners();
  }

  void dragEnd(double velocity) {
    final h = _dragHeight ?? currentHeight;
    // A flick decides by direction; a slow release by which level is nearer.
    if (velocity < -400) {
      _expanded = true;
    } else if (velocity > 400) {
      _expanded = false;
    } else {
      _expanded = h > (height + _expandedHeight) / 2;
    }
    _dragHeight = null;
    notifyListeners();
  }

  /// Toggles between the two levels — the handle's tap and screen-reader
  /// action, for anyone who cannot or would rather not drag.
  void toggleExpanded() {
    _expanded = !_expanded;
    _dragHeight = null;
    notifyListeners();
  }

  /// After a GIF or sticker is sent: an expanded panel drops back to the
  /// keyboard's height so the message just sent is visible above it. The
  /// panel itself stays — people often send several in a row.
  void noteSent() {
    if (!_expanded && _dragHeight == null) return;
    _expanded = false;
    _dragHeight = null;
    notifyListeners();
  }

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
    // Back to the keyboard's own height first, so the hand-over is between
    // two things the same size; the next opening starts collapsed too.
    _expanded = false;
    _dragHeight = null;
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
    _expanded = false;
    _dragHeight = null;
    notifyListeners();
  }

  /// Set once [dispose] has run. A search field reports losing focus from
  /// its own `dispose`, a frame AFTER the tree it sat in went away, and by
  /// then the host may have disposed this controller with that same tree:
  /// the report must land on nothing rather than throw.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _closeTimer?.cancel();
    super.dispose();
  }

  /// The extra room a host gives the panel while a search has the keyboard:
  /// the composer row, which [ComposerSearchTakeover] folds away for it.
  static const double composerRow = 60;

  void setSearching(bool v) {
    if (_disposed || _searching == v) return;
    if (v) {
      _searchFrom = (_dragHeight ?? (_expanded ? _expandedHeight : height)) +
          _pad -
          _inset;
    }
    _searching = v;
    // Putting the search keyboard away is asking for room to look at the
    // results, so the panel opens up rather than dropping back to half height.
    // A send brings it down again ([noteSent]).
    if (!v && _open && !_closing) {
      _expanded = true;
      _dragHeight = null;
    }
    notifyListeners();
  }
}
