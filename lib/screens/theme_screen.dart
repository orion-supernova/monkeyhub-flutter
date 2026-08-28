import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

/// Themes that share an identity (typography, decorations) but ship with
/// multiple palettes are grouped into "families" in the picker. Anything not
/// listed here renders as a standalone tile.
///
/// The display name/tagline are localized, so each family only stores a
/// stable identifier here — [_familyName]/[_familyTagline] map it to copy.
enum _ThemeFamilyId { basic, vault, others }

const List<_ThemeFamily> _families = [
  _ThemeFamily(
    id: _ThemeFamilyId.basic,
    ids: ['basic', 'basic_daylight', 'basic_graphite', 'basic_rose', 'basic_forest'],
  ),
  _ThemeFamily(
    id: _ThemeFamilyId.vault,
    ids: ['vault_noir', 'vault_ivory'],
  ),
  _ThemeFamily(
    id: _ThemeFamilyId.others,
    ids: [
      'risograph_pop',
      'bio_organic',
      'cyberpunk',
      'retro_wave',
      'neon_night',
      'deep_ocean',
    ],
  ),
];

class _ThemeFamily {
  const _ThemeFamily({required this.id, required this.ids});
  final _ThemeFamilyId id;
  final List<String> ids;
}

String _familyName(AppLocalizations l10n, _ThemeFamilyId id) {
  switch (id) {
    case _ThemeFamilyId.basic:
      return l10n.themeScreenFamilyBasicName;
    case _ThemeFamilyId.vault:
      return l10n.themeScreenFamilyVaultName;
    case _ThemeFamilyId.others:
      return l10n.themeScreenFamilyOthersName;
  }
}

String _familyTagline(AppLocalizations l10n, _ThemeFamilyId id) {
  switch (id) {
    case _ThemeFamilyId.basic:
      return l10n.themeScreenFamilyBasicTagline;
    case _ThemeFamilyId.vault:
      return l10n.themeScreenFamilyVaultTagline;
    case _ThemeFamilyId.others:
      return l10n.themeScreenFamilyOthersTagline;
  }
}

class _ThemeScreenState extends State<ThemeScreen> {
  /// Stable per-theme-id keys so the carousel can re-locate either a family
  /// chip OR a standalone tile when computing the reverse transition's rect.
  final Map<String, GlobalKey> _tileKeys = {};

  GlobalKey _keyFor(String id) => _tileKeys.putIfAbsent(id, () => GlobalKey());

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final controller = ThemeScope.controllerOf(context);
    final themes = ThemeController.all;
    final l10n = AppLocalizations.of(context);

    void apply(AppTheme t) {
      controller.theme = t;
      SettingsStore.instance.setThemeId(t.id);
      HapticFeedback.selectionClick();
    }

    int globalIndexOf(String id) => themes.indexWhere((t) => t.id == id);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // See home_screen: the bottom inset leaves a dead strip of
          // background under the scroller, which reads as a solid bar. The
          // list clears the home indicator with its own padding instead.
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.themeScreenTitle, style: theme.displayMedium),
                      const SizedBox(height: 10),
                      Row(children: [
                        Container(width: 18, height: 1, color: theme.accent),
                        const SizedBox(width: 8),
                        Text(l10n.themeScreenTapToApplyHint, style: theme.caption),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  // SingleChildScrollView + Column (not ListView) so every
                  // family card and tile is mounted from frame 1. Tile
                  // GlobalKeys must be resolvable BEFORE the user applies a
                  // theme — `Scrollable.ensureVisible` needs a mounted
                  // context to scroll to.
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      edgeToEdgeBottom(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final f in _families) ...[
                          _FamilyCard(
                            family: f,
                            themes: [
                              for (final id in f.ids)
                                themes.firstWhere((t) => t.id == id),
                            ],
                            activeId: theme.id,
                            chipKey: _keyFor,
                            onSelect: apply,
                            onPreviewVariant: (id) => _openCarousel(
                                context, globalIndexOf(id), themes, apply),
                          ),
                          const SizedBox(height: 14),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ],
      ),
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
    final media = MediaQuery.of(context).size;
    final dst = Offset.zero & media;
    final src = ValueNotifier<Rect>(_rectForId(themes[initialIndex].id, media));
    final flashColor = ValueNotifier<Color>(themes[initialIndex].accent);

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (ctx, anim, secondaryAnim) => _ThemePreviewCarousel(
          initialIndex: initialIndex,
          onPageSettle: (i) {
            // Keep the source rect in sync with the currently-shown tile so
            // the close transition retreats into THAT tile, not the original.
            src.value = _rectForId(themes[i].id, media);
            flashColor.value = themes[i].accent;
          },
          onApply: (t) async {
            apply(t);
            // Scroll the picker so the applied tile is in view before the
            // reverse transition starts — otherwise the close-zoom retreats
            // into a rect that's off-screen and looks jumpy.
            final tileCtx = _tileKeys[t.id]?.currentContext;
            if (tileCtx != null) {
              await Scrollable.ensureVisible(
                tileCtx,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: 0.3,
              );
            }
            // Refresh source rect to the post-scroll tile position.
            src.value = _rectForId(t.id, media);
            flashColor.value = t.accent;
          },
        ),
        transitionsBuilder: (ctx, anim, secondaryAnim, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeInOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return AnimatedBuilder(
            animation: Listenable.merge([curved, src, flashColor]),
            builder: (ctx, _) {
              final t = curved.value.clamp(0.0, 1.0);
              final srcRect = src.value;
              final accent = flashColor.value;
              final rect = Rect.lerp(srcRect, dst, t)!;
              final radius = ui.lerpDouble(28.0, 0.0, t)!;
              // Bell-curve wash: peaks mid-transition, fades at both ends.
              final wash = (t < 0.5 ? t * 2 : (1 - t) * 2) * 0.45;
              return Stack(
                children: [
                  // Accent flash that briefly tints the whole screen as the card swells.
                  IgnorePointer(
                    child: Opacity(
                      opacity: wash,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(
                              (srcRect.center.dx / media.width) * 2 - 1,
                              (srcRect.center.dy / media.height) * 2 - 1,
                            ),
                            radius: 1.4,
                            colors: [
                              accent.withValues(alpha: 0.95),
                              accent.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
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

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.family,
    required this.themes,
    required this.activeId,
    required this.chipKey,
    required this.onSelect,
    required this.onPreviewVariant,
  });
  final _ThemeFamily family;
  final List<AppTheme> themes;
  final String activeId;

  /// Hook so the parent state can stash a stable GlobalKey per variant id —
  /// needed so the carousel's close transition can retreat into the exact
  /// tile the user ended on.
  final GlobalKey Function(String id) chipKey;
  final ValueChanged<AppTheme> onSelect;

  /// Opens the carousel anchored on a specific variant id.
  final void Function(String id) onPreviewVariant;

  @override
  Widget build(BuildContext context) {
    final outer = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final activeFromFamily = family.ids.contains(activeId);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: outer.surface,
        borderRadius: BorderRadius.circular(outer.radiusLg),
        border: Border.all(
          color: activeFromFamily ? outer.accent : outer.divider,
          width: activeFromFamily ? 1.4 : 1,
        ),
        boxShadow: activeFromFamily
            ? [BoxShadow(color: outer.accent.withValues(alpha: 0.22), blurRadius: 16)]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_familyName(l10n, family.id),
                    style: outer.label.copyWith(letterSpacing: 2.4)),
                const SizedBox(height: 4),
                Text(_familyTagline(l10n, family.id), style: outer.monoTiny),
              ],
            ),
          ),
          // Same tile shape as the singles grid below — visual consistency.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemCount: themes.length,
            itemBuilder: (context, i) {
              final t = themes[i];
              return _ThemeGridTile(
                key: chipKey(t.id),
                candidate: t,
                active: t.id == activeId,
                onApply: () => onSelect(t),
                onPreview: () => onPreviewVariant(t.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeGridTile extends StatelessWidget {
  const _ThemeGridTile({
    super.key,
    required this.candidate,
    required this.active,
    required this.onApply,
    required this.onPreview,
  });
  final AppTheme candidate;
  final bool active;
  final VoidCallback onApply;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final outer = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final borderWidth = active ? 1.6 : 1.0;
    return GestureDetector(
      onTap: onApply,
      child: Container(
        decoration: BoxDecoration(
          color: outer.surface,
          borderRadius: BorderRadius.circular(outer.radiusLg),
          border: Border.all(
            color: active ? outer.accent : outer.divider,
            width: borderWidth,
          ),
          boxShadow: active
              ? [BoxShadow(color: outer.accent.withValues(alpha: 0.30), blurRadius: 18)]
              : null,
        ),
        // Clip the child *inside* the border line — anti-aliased clipping at
        // the full corner radius was eating the top corners of the border.
        // Shrinking by the border width gives the stroke a clean edge.
        child: Padding(
          padding: EdgeInsets.all(borderWidth),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(outer.radiusLg - borderWidth),
            child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: candidate.background,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < candidate.swatch.length; i++) ...[
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: candidate.swatch[i],
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          if (i < candidate.swatch.length - 1)
                            const SizedBox(width: 4),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.name,
                        style: outer.displaySmall.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        candidate.tagline,
                        style: outer.monoTiny,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      if (active)
                        Row(children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: outer.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.themeScreenActiveBadge,
                            style: outer.monoTiny.copyWith(color: outer.accent),
                          ),
                        ])
                      else
                        Text(l10n.themeScreenTapToApplyLabel, style: outer.monoTiny.copyWith(color: outer.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onPreview,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: outer.surfaceRaised.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                    border: Border.all(color: outer.divider),
                  ),
                  child: Icon(
                    Icons.open_in_full,
                    size: 12,
                    color: outer.inkSoft,
                  ),
                ),
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
    final isActive = shown.id == activeId;
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
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close, color: shown.ink, size: 22),
                    ),
                    const Spacer(),
                    _Dots(count: themes.length, index: _index, theme: shown),
                    const Spacer(),
                    const SizedBox(width: 48),
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
              child: GestureDetector(
                onTap: isActive
                    ? () => Navigator.of(context).maybePop()
                    : () => _apply(context, shown),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.transparent : shown.accent,
                    borderRadius: BorderRadius.circular(999),
                    border: isActive
                        ? Border.all(color: shown.accent, width: 1.5)
                        : null,
                    boxShadow: isActive
                        ? null
                        : [
                            BoxShadow(
                              color: shown.accent.withValues(alpha: 0.40),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive) ...[
                        Icon(Icons.check_circle, size: 16, color: shown.accent),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        isActive
                            ? l10n.themeScreenCarouselActiveLabel(shown.name.toUpperCase())
                            : l10n.themeScreenCarouselApplyLabel(shown.name.toUpperCase()),
                        style: TextStyle(
                          color: isActive ? shown.accent : shown.accentInk,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
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

class _PreviewPage extends StatelessWidget {
  const _PreviewPage({required this.t});
  final AppTheme t;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        theme.backgroundLayer(context),
        SafeArea(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  theme.brandMark(size: 28),
                  const SizedBox(width: 10),
                  Text(theme.name, style: theme.label.copyWith(letterSpacing: 2)),
                ]),
                const SizedBox(height: 18),
                Text(l10n.themeScreenPreviewGreeting, style: theme.displayHero),
                const SizedBox(height: 6),
                Row(children: [
                  Container(width: 18, height: 1, color: theme.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      theme.tagline,
                      style: theme.caption,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
                const SizedBox(height: 22),
                _mockRoomRow(
                  theme,
                  name: l10n.themeScreenPreviewRoomOneName,
                  sub: l10n.themeScreenPreviewRoomOneSub,
                  ephemeral: false,
                  active: true,
                ),
                const SizedBox(height: 10),
                _mockRoomRow(
                  theme,
                  name: l10n.themeScreenPreviewRoomTwoName,
                  sub: l10n.themeScreenPreviewRoomTwoSub,
                  ephemeral: true,
                  active: false,
                ),
                const SizedBox(height: 22),
                Text(l10n.themeScreenPreviewSectionLabel, style: theme.label),
                const SizedBox(height: 10),
                _bubble(theme, text: l10n.themeScreenPreviewBubbleQuestion, mine: false),
                const SizedBox(height: 8),
                _bubble(theme, text: l10n.themeScreenPreviewBubbleAnswer, mine: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _mockRoomRow(
    AppTheme theme, {
    required String name,
    required String sub,
    required bool ephemeral,
    required bool active,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: theme.roomCardDecoration(ephemeral: ephemeral, active: active),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: theme.avatarGradient(name.hashCode),
              ),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.displaySmall.copyWith(fontSize: 16)),
                const SizedBox(height: 2),
                Text(sub, style: theme.monoTiny),
              ],
            ),
          ),
          if (ephemeral) theme.hourglassIcon(size: 14, color: theme.accent),
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
        // The real transcript shape, so the carousel previews what the theme
        // will actually look like in a room. Both samples are single messages,
        // so both close their run.
        decoration: theme.bubbleDecoration(
          isMine: mine,
          ephemeral: false,
          style: SettingsStore.instance.bubbleStyle,
        ),
        child: Text(
          text,
          style: theme.body.copyWith(
            color: mine ? theme.accentInk : theme.ink,
          ),
        ),
      ),
    );
  }
}
