import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../widgets/ios_kit.dart';
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
/// Characters after. A tap applies; touch and hold opens the full-screen
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
        _SectionLabel(l10n.themePageEssentials),
        grid([for (final t in themes) if (_essentials.contains(t.id)) t]),
        GroupedFooter(l10n.themePageEssentialsFooter),
        _SectionLabel(l10n.themePageCharacters),
        grid([for (final t in themes) if (!_essentials.contains(t.id)) t]),
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

    Navigator.of(context).push(
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
              return Positioned.fromRect(
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
              );
            },
          );
        },
      ),
    );
  }
}

/// A grouped-list header for content that is not a [GroupedSection].
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
      child: Text(
        text,
        style: theme.caption.copyWith(fontSize: 13, color: theme.inkMuted),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: _MiniPhone(t: candidate),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              candidate.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: outer.body.copyWith(fontSize: 13, color: outer.ink),
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
            style: theme.caption.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.accentInk,
            ),
          ),
        ],
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
        // The theme's own page, texture and all.
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

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pc = PageController(initialPage: _index, viewportFraction: 1);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _apply(BuildContext context, AppTheme t) async {
    HapticFeedback.mediumImpact();
    final nav = Navigator.of(context);
    await widget.onApply(t);
    if (mounted) nav.maybePop();
  }

  @override
  Widget build(BuildContext context) {
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pc,
            itemCount: themes.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              HapticFeedback.selectionClick();
              widget.onPageSettle(i);
            },
            itemBuilder: (_, i) {
              final t = themes[i];
              return ThemeScope(
                controller: ThemeController(t),
                child: _PreviewPage(t: t),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _CloseButton(theme: shown),
                    const Spacer(),
                    _Dots(count: themes.length, index: _index, theme: shown),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: SpringPress(
                onTap: isActive
                    ? () => Navigator.of(context).maybePop()
                    : () => _apply(context, shown),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isActive
                        ? shown.ink.withValues(alpha: 0.10)
                        : shown.bubbleFill(isMine: true),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive) ...[
                        Icon(
                          CupertinoIcons.checkmark_alt,
                          size: 18,
                          color: shown.ink,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: shown.bodyEmph.copyWith(
                          fontSize: 17,
                          color: isActive ? shown.ink : shown.accentInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.theme});
  final int count;
  final int index;
  final AppTheme theme;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 14 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == index
                  ? theme.ink
                  : theme.inkMuted.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.theme});
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return SpringPress(
      onTap: () => Navigator.of(context).maybePop(),
      semanticLabel: MaterialLocalizations.of(context).closeButtonTooltip,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.ink.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(CupertinoIcons.xmark, size: 17, color: theme.ink),
      ),
    );
  }
}

/// One theme, full screen: the chat list as it would look — large title, a
/// few rows — and a short exchange, in the theme's own type and colours.
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
    final rows = [
      (l10n.themeScreenPreviewRoomOneName, l10n.themeScreenPreviewRoomOneSub, 2),
      (l10n.themeScreenPreviewRoomTwoName, l10n.themeScreenPreviewRoomTwoSub, 0),
    ];
    return Stack(
      children: [
        theme.backgroundLayer(context),
        SafeArea(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 64, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  theme.name,
                  style: theme.caption.copyWith(color: theme.inkMuted),
                ),
                const SizedBox(height: 2),
                Text(l10n.homeScreenTitle, style: theme.displayLarge),
                const SizedBox(height: 14),
                for (var i = 0; i < rows.length; i++)
                  _mockRow(
                    theme,
                    name: rows[i].$1,
                    sub: rows[i].$2,
                    unread: rows[i].$3,
                    seed: i * 9 + 4,
                    divider: i < rows.length - 1,
                  ),
                const SizedBox(height: 28),
                _bubble(
                  theme,
                  text: l10n.themeScreenPreviewBubbleQuestion,
                  mine: false,
                ),
                const SizedBox(height: 6),
                _bubble(
                  theme,
                  text: l10n.themeScreenPreviewBubbleAnswer,
                  mine: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mockRow(
    AppTheme theme, {
    required String name,
    required String sub,
    required int unread,
    required int seed,
    required bool divider,
  }) {
    final hue = theme.avatarGradient(seed).first;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
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
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(hue, Colors.white, 0.22)!,
                  Color.lerp(hue, Colors.black, 0.12)!,
                ],
              ),
            ),
            child: Text(
              name.characters.first.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'CupertinoSystemDisplay',
                fontSize: 21,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
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
                style: theme.caption.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.accentInk,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bubble(AppTheme theme, {required String text, required bool mine}) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        // The real transcript shape, so the preview is what the theme will
        // actually look like in a room.
        decoration: theme.bubbleDecoration(
          isMine: mine,
          ephemeral: false,
          style: SettingsStore.instance.bubbleStyle,
        ),
        child: Text(
          text,
          style: theme.body.copyWith(color: mine ? theme.accentInk : theme.ink),
        ),
      ),
    );
  }
}
