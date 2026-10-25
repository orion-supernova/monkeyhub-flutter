import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart' show FocusRingShape, FocusableTap;
import '../keyboard/viewer_keys.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/text_case.dart';
import '../theme/density.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../widgets/chat_list_row.dart' show MonogramAvatar;
import '../widgets/desktop_scroll.dart';
import '../widgets/ios_kit.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/settings_pickers.dart';

/// The calm, native palettes. Everything else is a Character.
const List<String> _essentials = [
  'basic',
  'basic_daylight',
  'basic_graphite',
  'basic_rose',
  'basic_forest',
];

/// The theme picker: follow the device or keep one theme, then every theme as
/// a tiny phone drawn in its own colours — the Essentials first, the
/// Characters after. A tap applies; the expand glyph on a tile's corner, the
/// Preview action over each section, or touch and hold opens the full-screen
/// preview, which swipes through all of them.
class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  /// Stable per-theme keys, so the full-screen preview can open out of — and
  /// retreat into — the exact tile it belongs to.
  final Map<String, GlobalKey> _tileKeys = {};

  GlobalKey _keyFor(String id) => _tileKeys.putIfAbsent(id, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    // Every choice lands in SettingsStore, and app.dart turns it into the
    // theme on screen — so the store is what this rebuilds on, and nothing
    // here sets the controller itself.
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final themes = ThemeController.all;
    final l10n = AppLocalizations.of(context);
    final store = SettingsStore.instance;
    final system = store.appearanceMode == AppearanceMode.system;
    final light = ThemeController.byId(store.lightThemeId);
    final dark = ThemeController.byId(store.darkThemeId);

    /// Following the device, a tap files the theme under the mode it suits —
    /// a light theme becomes the light-mode theme — so no tap can put a dark
    /// palette in front of somebody's daytime screen. Fixed, it is the theme.
    void apply(AppTheme t) {
      if (system) {
        store.setSlotTheme(t.brightness, t.id);
      } else {
        store.setThemeId(t.id);
      }
      HapticFeedback.selectionClick();
    }

    /// Which half of the device-following pair [t] is, if either.
    Brightness? slotOf(AppTheme t) {
      if (!system) return null;
      if (t.id == store.lightThemeId) return Brightness.light;
      if (t.id == store.darkThemeId) return Brightness.dark;
      return null;
    }

    int indexOf(String id) =>
        themes.indexWhere((t) => t.id == id).clamp(0, themes.length - 1);

    Widget grid(List<AppTheme> set) => _ThemeGrid(
          themes: set,
          activeId: theme.id,
          slotOf: slotOf,
          keyFor: _keyFor,
          onApply: apply,
          onPreview: (t) =>
              _openCarousel(context, indexOf(t.id), themes, apply),
        );

    /// A section's header, with Preview on its far edge — iOS's "See All"
    /// slot. It opens on the theme in use when that theme lives in this
    /// section, otherwise on the section's first, so the swipe starts where
    /// the eye already is.
    Widget header(String label, List<AppTheme> set) => GroupedHeader(
          label,
          trailing: _HeaderAction(
            label: sentenceCaseOf(context, l10n.glassScreenPreviewBadge),
            onTap: () => _openCarousel(
              context,
              indexOf(
                set.any((t) => t.id == theme.id) ? theme.id : set.first.id,
              ),
              themes,
              apply,
            ),
          ),
        );

    final essentials = [
      for (final t in themes)
        if (_essentials.contains(t.id)) t,
    ];
    final characters = [
      for (final t in themes)
        if (!_essentials.contains(t.id)) t,
    ];

    return SettingsPage(
      title: l10n.settingsHubTheme,
      children: [
        GroupedSection(
          footer: system ? l10n.themePageAutoFooter : null,
          children: [
            GroupedRow.toggle(
              icon: CupertinoIcons.circle_lefthalf_fill,
              tone: TileTone.indigo,
              title: l10n.appearanceMatchDevice,
              value: system,
              onChanged: (follow) {
                HapticFeedback.selectionClick();
                store.setAppearanceMode(
                  follow ? AppearanceMode.system : AppearanceMode.fixed,
                  current: theme.id,
                );
              },
            ),
            if (system) ...[
              GroupedRow(
                icon: CupertinoIcons.sun_max_fill,
                tone: TileTone.orange,
                title: l10n.themePageLightMode,
                value: light.name,
                onTap: () => _openCarousel(
                  context,
                  indexOf(light.id),
                  themes,
                  apply,
                ),
              ),
              GroupedRow(
                icon: CupertinoIcons.moon_fill,
                tone: TileTone.indigo,
                title: l10n.themePageDarkMode,
                value: dark.name,
                onTap: () => _openCarousel(
                  context,
                  indexOf(dark.id),
                  themes,
                  apply,
                ),
              ),
            ],
          ],
        ),
        header(l10n.themePageEssentials, essentials),
        grid(essentials),
        GroupedFooter(l10n.themePageEssentialsFooter),
        header(l10n.themePageCharacters, characters),
        grid(characters),
        GroupedFooter(l10n.themePageCharactersFooter),
      ],
    );
  }

  Rect _rectForId(String id, Size media) {
    final box = _tileKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.localToGlobal(Offset.zero) & box.size;
    }
    return Rect.fromCenter(
      center: Offset(media.width / 2, media.height / 2),
      width: 1,
      height: 1,
    );
  }

  void _openCarousel(
    BuildContext context,
    int initialIndex,
    List<AppTheme> themes,
    void Function(AppTheme) apply,
  ) {
    HapticFeedback.mediumImpact();
    final media = MediaQuery.of(context).size;
    final dst = Offset.zero & media;
    final src = ValueNotifier<Rect>(_rectForId(themes[initialIndex].id, media));

    // The root navigator, always. On desktop this page lives in the settings
    // pane's nested navigator, which sits inside the shell that a theme
    // change remounts — a carousel pushed there would be torn down by its
    // own APPLY. The root also makes the tile's global rect the right frame
    // for the zoom.
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: const Duration(milliseconds: 340),
        pageBuilder: (ctx, anim, secondaryAnim) => _ThemePreviewCarousel(
          initialIndex: initialIndex,
          onPageSettle: (i) {
            // Keep the source rect on the tile now showing, so the close
            // retreats into THAT tile, not the one it opened from.
            src.value = _rectForId(themes[i].id, media);
          },
          onApply: (t) async {
            apply(t);
            // Bring the applied tile into view before the reverse transition,
            // so the close does not retreat into a rect that is off-screen.
            final tileCtx = _tileKeys[t.id]?.currentContext;
            if (tileCtx != null) {
              await Scrollable.ensureVisible(
                tileCtx,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: 0.3,
              );
            }
            src.value = _rectForId(t.id, media);
          },
        ),
        // The tile grows into the screen: a rounded window that opens out of
        // the tile's own rect, the iOS zoom transition.
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutQuart,
            reverseCurve: Curves.easeInCubic,
          );
          return AnimatedBuilder(
            animation: Listenable.merge([curved, src]),
            builder: (ctx, _) {
              final t = curved.value.clamp(0.0, 1.0);
              final rect = Rect.lerp(src.value, dst, t)!;
              final radius = ui.lerpDouble(18.0, 0.0, t)!;
              // A Stack of its own: a route's transition is not laid out
              // inside one, and a bare Positioned there is a parent-data
              // error that kills the zoom on its first frame.
              return Stack(
                children: [
                  Positioned.fromRect(
                    rect: rect,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: OverflowBox(
                        alignment: Alignment.topLeft,
                        minWidth: media.width,
                        maxWidth: media.width,
                        minHeight: media.height,
                        maxHeight: media.height,
                        child: Transform.translate(
                          offset: Offset(-rect.left, -rect.top),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The text action on a [GroupedHeader]'s far edge: accent ink, the row
/// value's size, a hit area taller than the words.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SpringPress(
      onTap: onTap,
      haptic: false,
      semanticLabel: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: groupedValueStyle(theme).copyWith(color: theme.accent),
        ),
      ),
    );
  }
}

/// Three phones to a row on a grouped plate.
class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({
    required this.themes,
    required this.activeId,
    required this.slotOf,
    required this.keyFor,
    required this.onApply,
    required this.onPreview,
  });

  final List<AppTheme> themes;
  final String activeId;
  final Brightness? Function(AppTheme) slotOf;
  final GlobalKey Function(String id) keyFor;
  final ValueChanged<AppTheme> onApply;
  final ValueChanged<AppTheme> onPreview;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    const columns = 3;
    final rows = (themes.length / columns).ceil();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: groupedFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        children: [
          for (var r = 0; r < rows; r++) ...[
            if (r > 0) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: 12),
                  Expanded(
                    child: r * columns + c < themes.length
                        ? _ThemeTile(
                            key: keyFor(themes[r * columns + c].id),
                            candidate: themes[r * columns + c],
                            active: themes[r * columns + c].id == activeId,
                            slot: slotOf(themes[r * columns + c]),
                            onApply: () => onApply(themes[r * columns + c]),
                            onPreview: () =>
                                onPreview(themes[r * columns + c]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One theme: a phone in its colours, its name, and a check — or, while the
/// app follows the device, which mode it is the theme for.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    super.key,
    required this.candidate,
    required this.active,
    required this.slot,
    required this.onApply,
    required this.onPreview,
  });

  final AppTheme candidate;
  final bool active;
  final Brightness? slot;
  final VoidCallback onApply;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final outer = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final chosen = active || slot != null;
    return GestureDetector(
      onLongPress: onPreview,
      child: SpringPress(
        onTap: onApply,
        haptic: false,
        semanticLabel: candidate.name,
        child: Column(
          children: [
            AnimatedContainer(
              duration: motion.d(const Duration(milliseconds: 220)),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: chosen ? outer.accent : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: AspectRatio(
                aspectRatio: 0.62,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: _MiniPhone(t: candidate),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _ExpandBadge(
                        t: candidate,
                        semanticLabel:
                            '${candidate.name}, ${sentenceCaseOf(context, l10n.glassScreenPreviewBadge)}',
                        onTap: onPreview,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              candidate.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: groupedMetaStyle(outer).copyWith(color: outer.ink),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 20,
              child: slot != null
                  ? _SlotBadge(
                      light: slot == Brightness.light,
                      label: slot == Brightness.light
                          ? l10n.themePageLightBadge
                          : l10n.themePageDarkBadge,
                    )
                  : RadioCheck(selected: active, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotBadge extends StatelessWidget {
  const _SlotBadge({required this.light, required this.label});
  final bool light;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.accent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            light ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
            size: 11,
            color: theme.accentInk,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: groupedMetaStyle(theme).copyWith(
              fontWeight: FontWeight.w600,
              color: theme.accentInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// The way into the full-screen preview from a tile: a small expand glyph on
/// the phone's top corner, drawn in the theme's OWN colours so it reads as
/// part of that phone, not as chrome laid over the grid. The visible half of
/// what touch-and-hold does; the hit area runs past the 22pt disc to a
/// thumb-sized 36.
class _ExpandBadge extends StatelessWidget {
  const _ExpandBadge({
    required this.t,
    required this.semanticLabel,
    required this.onTap,
  });
  final AppTheme t;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: onTap,
      haptic: false,
      semanticLabel: semanticLabel,
      focusShape: FocusRingShape.circle,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Align(
          alignment: const Alignment(0.35, -0.35),
          child: Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.surfaceRaised.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: t.ink.withValues(alpha: 0.14), width: 0.5),
            ),
            child: Icon(
              CupertinoIcons.arrow_up_left_arrow_down_right,
              size: 11,
              color: t.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// A theme as a phone: its page, a large title, two chat rows and an exchange
/// of bubbles — in its own colours, from plain boxes rather than mounted
/// screens, so a grid of thirteen stays cheap.
class _MiniPhone extends StatelessWidget {
  const _MiniPhone({required this.t});
  final AppTheme t;

  @override
  Widget build(BuildContext context) {
    final line = t.ink.withValues(alpha: 0.12);
    Widget bar(double w, Color c, [double h = 3.5]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(2),
          ),
        );
    Widget row(int seed) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: t.avatarGradient(seed).first,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(24, t.ink.withValues(alpha: 0.7), 3),
                    const SizedBox(height: 2.5),
                    bar(double.infinity, line, 2.5),
                  ],
                ),
              ),
            ],
          ),
        );
    Widget bubble({required bool mine, required double w}) => Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: w,
            height: 11,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: t.bubbleFill(isMine: mine),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        );
    return Stack(
      fit: StackFit.expand,
      children: [
        // The theme's own page, texture and all — over its flat colour, for
        // the frames before a textured page's image has decoded.
        ColoredBox(color: t.background),
        ThemeScope(
          controller: ThemeController(t),
          child: Builder(builder: (context) => t.backgroundLayer(context)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(30, t.ink, 5),
              const SizedBox(height: 8),
              row(3),
              row(11),
              const Spacer(),
              bubble(mine: false, w: 34),
              bubble(mine: true, w: 44),
              bubble(mine: true, w: 26),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThemePreviewCarousel extends StatefulWidget {
  const _ThemePreviewCarousel({
    required this.initialIndex,
    required this.onPageSettle,
    required this.onApply,
  });
  final int initialIndex;
  final ValueChanged<int> onPageSettle;

  /// Called when the user taps APPLY. Implementation applies the theme,
  /// scrolls the picker so the tile is visible, and refreshes the close
  /// transition's source rect — all *before* this returns. The carousel
  /// then pops itself.
  final Future<void> Function(AppTheme) onApply;

  @override
  State<_ThemePreviewCarousel> createState() => _ThemePreviewCarouselState();
}


class _ThemePreviewCarouselState extends State<_ThemePreviewCarousel> {
  late final PageController _pc;
  late int _index;

  /// One controller per theme, made once: the chrome and the page for a
  /// theme share it, and a fresh one per build would be a fresh notifier
  /// every frame of a swipe.
  final Map<String, ThemeController> _scopes = {};

  ThemeController _scopeFor(AppTheme t) =>
      _scopes.putIfAbsent(t.id, () => ThemeController(t));

  /// The route's own animation, watched so the glass chrome only exists
  /// while the page is at rest. The zoom moves and clips the whole route, and
  /// a BackdropFilter riding that transform re-samples every frame — the one
  /// thing glass must never do — so the close button, title and APPLY appear
  /// once the page has landed and vanish the moment it starts to retreat.
  Animation<double>? _route;
  bool _settled = false;

  /// A mouse is over the pager, so the page chevrons show. A notifier rather
  /// than state: hovering must not rebuild the preview pages.
  final ValueNotifier<bool> _hover = ValueNotifier<bool>(false);

  /// One page back or forward, for the chevrons and the arrow keys. A swipe
  /// is a finger's way through the gallery; a mouse has had no way at all.
  void _step(int delta) {
    final target = (_index + delta).clamp(0, ThemeController.all.length - 1);
    if (target == _index) return;
    _pc.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pc = PageController(initialPage: _index, viewportFraction: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context)?.animation;
    if (identical(route, _route)) return;
    _route?.removeStatusListener(_onRouteStatus);
    _route = route?..addStatusListener(_onRouteStatus);
    _settled = route == null || route.status == AnimationStatus.completed;
  }

  void _onRouteStatus(AnimationStatus status) {
    final settled = status == AnimationStatus.completed;
    if (settled == _settled || !mounted) return;
    setState(() => _settled = settled);
  }

  @override
  void dispose() {
    _route?.removeStatusListener(_onRouteStatus);
    _pc.dispose();
    _hover.dispose();
    for (final c in _scopes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _apply(BuildContext context, AppTheme t) async {
    HapticFeedback.mediumImpact();
    final nav = Navigator.of(context);
    await widget.onApply(t);
    if (mounted) nav.maybePop();
  }

  // The label reads the store (which half of the device-following pair a
  // theme already is), and an APPLY that files a theme under the mode NOT
  // showing changes no ThemeScope — so this listens to the store itself.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SettingsStore.instance,
        builder: (context, _) => _buildListening(context),
      );

  Widget _buildListening(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themes = ThemeController.all;
    final activeId = ThemeScope.of(context).id;
    final shown = themes[_index];
    final store = SettingsStore.instance;
    final system = store.appearanceMode == AppearanceMode.system;
    // Following the device, "active" means this theme already IS its mode's
    // theme — whether or not that mode is the one showing right now.
    final isActive = system
        ? shown.id ==
            (shown.isLight ? store.lightThemeId : store.darkThemeId)
        : shown.id == activeId;
    final label = switch ((system, isActive, shown.isLight)) {
      (true, true, true) => l10n.themePageInUse,
      (true, true, false) => l10n.themePageInUse,
      (true, false, true) => l10n.themePageUseLight,
      (true, false, false) => l10n.themePageUseDark,
      (false, true, _) => l10n.themePageInUse,
      (false, false, _) => l10n.themePageUse(shown.name),
    };
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      backgroundColor: Colors.black,
      // ← → step through the gallery; Esc still falls through to the route.
      body: ViewerKeys(
        onPrevious: () => _step(-1),
        onNext: () => _step(1),
        child: MouseRegion(
          onEnter: (_) => _hover.value = true,
          onExit: (_) => _hover.value = false,
          child: Stack(
            children: [
              PagerMouseDrag(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: themes.length,
                  onPageChanged: (i) {
                    setState(() => _index = i);
                    HapticFeedback.selectionClick();
                    widget.onPageSettle(i);
                  },
                  itemBuilder: (_, i) => ThemeScope(
                    controller: _scopeFor(themes[i]),
                    child: _PreviewPage(t: themes[i]),
                  ),
                ),
              ),
              // Mouse-only page chevrons, at the reading-direction edges. Plain
              // translucent discs rather than glass: they fade, and glass must
              // never animate.
              if (_settled) ...[
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _PagerChevron(
                      hover: _hover,
                      icon: CupertinoIcons.chevron_left,
                      label: rtl ? l10n.layoutPagerNext : l10n.layoutPagerPrevious,
                      enabled: rtl ? _index < themes.length - 1 : _index > 0,
                      onTap: () => _step(rtl ? 1 : -1),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _PagerChevron(
                      hover: _hover,
                      icon: CupertinoIcons.chevron_right,
                      label: rtl ? l10n.layoutPagerPrevious : l10n.layoutPagerNext,
                      enabled: rtl ? _index > 0 : _index < themes.length - 1,
                      onTap: () => _step(rtl ? -1 : 1),
                    ),
                  ),
                ),
              ],
              // The chrome wears the theme being shown, so its glass, ink and
              // APPLY are that theme's — a dark close button over Daylight would
              // be a preview of the wrong app.
              if (_settled)
                ThemeScope(
                  controller: _scopeFor(shown),
                  child: Positioned.fill(
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const GlassCloseButton(),
                                  Expanded(
                                    child: Center(
                                      child: _PagerTitle(
                                        name: shown.name,
                                        count: themes.length,
                                        index: _index,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: Density.of(context).iconButton),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: SafeArea(
                            top: false,
                            child: Center(
                              child: GlassPillButton(
                                label: label,
                                height: 50,
                                icon: isActive ? CupertinoIcons.checkmark_alt : null,
                                tint: isActive ? null : shown.accent,
                                onTap: isActive
                                    ? () => Navigator.of(context).maybePop()
                                    : () => _apply(context, shown),
                              ),
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
      ),
    );
  }
}

/// A page chevron for [_ThemePreviewCarousel], shown while a mouse is over the
/// pager ([hover]) and the page in that direction exists ([enabled]).
///
/// Fades on its own small layer and never rebuilds the pages behind it.
class _PagerChevron extends StatelessWidget {
  const _PagerChevron({
    required this.hover,
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final ValueNotifier<bool> hover;
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: hover,
      builder: (context, hovering, child) {
        final show = hovering && enabled;
        return IgnorePointer(
          ignoring: !show,
          child: AnimatedOpacity(
            opacity: show ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: child,
          ),
        );
      },
      child: FocusableTap(
        onTap: onTap,
        semanticLabel: label,
        shape: FocusRingShape.capsule,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0x59000000),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// The theme's name over a row of page dots, on one capsule of glass — the
/// iOS wallpaper picker's title, readable over any page because the glass,
/// not the page, is what the dots sit on.
class _PagerTitle extends StatelessWidget {
  const _PagerTitle({
    required this.name,
    required this.count,
    required this.index,
  });
  final String name;
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return LiquidGlass(
      shape: LiquidGlassShape.capsule,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: groupedMetaStyle(theme).copyWith(
              fontWeight: FontWeight.w600,
              color: theme.ink,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 5),
          _Dots(count: count, index: index),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;
  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: i == index ? 14 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index
                  ? theme.ink
                  : theme.ink.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

/// One theme, full screen, as the app would actually draw it: its page
/// texture, the chat list's large title and rows, then an open room — the
/// header, a short run of bubbles in the theme's real transcript shape, and
/// the composer. Plain boxes in the theme's own type and colours; no glass,
/// so a swipe moves nothing but paint.
class _PreviewPage extends StatelessWidget {
  const _PreviewPage({required this.t});
  final AppTheme t;

  // Listens to the settings it reads: this widget is built `const`, and a
  // const widget is never rebuilt by its parent, so a changed setting would
  // otherwise leave it showing the old value.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SettingsStore.instance,
        builder: (context, _) => _buildListening(context),
      );

  Widget _buildListening(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final style = SettingsStore.instance.bubbleStyle;
    final rows = [
      (l10n.themeScreenPreviewRoomOneName, l10n.themeScreenPreviewRoomOneSub, 2),
      (l10n.themeScreenPreviewRoomTwoName, l10n.themeScreenPreviewRoomTwoSub, 0),
    ];
    return Stack(
      children: [
        // The flat page colour under the layer: a textured theme (Paper)
        // draws its page from an image, and until that decodes the page
        // would otherwise be the route's black.
        Positioned.fill(child: ColoredBox(color: theme.background)),
        Positioned.fill(child: theme.backgroundLayer(context)),
        SafeArea(
          child: Padding(
            // Clear of the floating chrome: the close button and title above,
            // APPLY below.
            padding: const EdgeInsets.fromLTRB(16, 64, 16, 82),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(l10n.homeScreenTitle, style: theme.displayLarge),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < rows.length; i++)
                  _mockRow(
                    theme,
                    name: rows[i].$1,
                    sub: rows[i].$2,
                    unread: rows[i].$3,
                    divider: i < rows.length - 1,
                  ),
                const SizedBox(height: 14),
                Expanded(child: _room(context, theme, l10n, style)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// An open room on the theme's raised surface: header, transcript pinned
  /// to the bottom like a real one (a short screen clips the oldest first),
  /// composer.
  Widget _room(
    BuildContext context,
    AppTheme theme,
    AppLocalizations l10n,
    BubbleStyle style,
  ) {
    final hairline = theme.ink.withValues(alpha: 0.10);
    return ClipRRect(
      borderRadius: BorderRadius.circular(groupedRadius(theme)),
      child: ColoredBox(
        color: groupedFill(theme).withValues(alpha: 0.55),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: hairline, width: 0.5)),
              ),
              child: Row(
                children: [
                  MonogramAvatar(
                    label: l10n.glassScreenPreviewRoomName.replaceAll('#', ''),
                    seed: 'balcony',
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.glassScreenPreviewRoomName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyEmph.copyWith(color: theme.ink),
                        ),
                        Text(
                          l10n.glassScreenPreviewOnlineCount,
                          style: groupedMetaStyle(theme),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRect(
                child: SingleChildScrollView(
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    children: [
                      _bubble(
                        theme,
                        style,
                        text: l10n.themeScreenPreviewGreeting,
                        mine: false,
                        first: true,
                        last: false,
                      ),
                      const SizedBox(height: 2),
                      _bubble(
                        theme,
                        style,
                        text: l10n.themeScreenPreviewBubbleQuestion,
                        mine: false,
                        first: false,
                        last: true,
                      ),
                      const SizedBox(height: 8),
                      _bubble(
                        theme,
                        style,
                        text: l10n.themeScreenPreviewBubbleAnswer,
                        mine: true,
                        first: true,
                        last: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _composer(theme, l10n),
          ],
        ),
      ),
    );
  }

  Widget _composer(AppTheme theme, AppLocalizations l10n) {
    Widget disc(IconData icon, {required Color fill, required Color ink}) =>
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: ink),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(
        children: [
          disc(
            CupertinoIcons.plus,
            fill: theme.ink.withValues(alpha: 0.08),
            ink: theme.inkMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              // The theme's own field: Basic's sunken pill, Risograph's
              // inked slab.
              decoration: theme.inputDecoration(),
              child: Text(
                l10n.glassScreenPreviewMessageHint,
                style: theme.body.copyWith(color: theme.inkMuted),
              ),
            ),
          ),
          const SizedBox(width: 8),
          disc(
            CupertinoIcons.arrow_up,
            fill: theme.accent,
            ink: theme.accentInk,
          ),
        ],
      ),
    );
  }

  Widget _mockRow(
    AppTheme theme, {
    required String name,
    required String sub,
    required int unread,
    required bool divider,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 9, 4, 9),
      decoration: BoxDecoration(
        border: divider
            ? Border(
                bottom: BorderSide(
                  color: theme.ink.withValues(alpha: 0.10),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Row(
        children: [
          // The chat list's own lettered face.
          MonogramAvatar(label: name, seed: name, size: 50),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.bodyEmph.copyWith(color: theme.ink)),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: theme.bodySoft.copyWith(color: theme.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (unread > 0)
            Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.bubbleFill(isMine: true),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$unread',
                style: groupedMetaStyle(theme).copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.accentInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bubble(
    AppTheme theme,
    BubbleStyle style, {
    required String text,
    required bool mine,
    required bool first,
    required bool last,
  }) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        // The real transcript shape — the chosen bubble style, tails on the
        // last of a run — so the preview is what the theme will actually
        // look like in a room.
        decoration: theme.bubbleDecoration(
          isMine: mine,
          ephemeral: false,
          style: style,
          firstInRun: first,
          lastInRun: last,
        ),
        child: Text(
          text,
          style: theme.body.copyWith(color: mine ? theme.accentInk : theme.ink),
        ),
      ),
    );
  }
}
