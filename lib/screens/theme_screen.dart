import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';

class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final controller = ThemeScope.controllerOf(context);
    final themes = ThemeController.all;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
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
                      Text('theme.', style: theme.displayMedium),
                      const SizedBox(height: 10),
                      Row(children: [
                        Container(width: 18, height: 1, color: theme.accent),
                        const SizedBox(width: 8),
                        Text('tap to apply · ⛶ for full preview', style: theme.caption),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: themes.length,
                    itemBuilder: (context, i) {
                      final t = themes[i];
                      final tileKey = GlobalKey();
                      return _ThemeGridTile(
                        key: tileKey,
                        candidate: t,
                        active: t.id == theme.id,
                        onApply: () {
                          controller.theme = t;
                          SettingsStore.instance.setThemeId(t.id);
                          HapticFeedback.selectionClick();
                        },
                        onPreview: () => _openCarousel(context, i, tileKey, t),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openCarousel(
    BuildContext context,
    int initialIndex,
    GlobalKey tileKey,
    AppTheme sourceTheme,
  ) {
    final box = tileKey.currentContext?.findRenderObject() as RenderBox?;
    final media = MediaQuery.of(context).size;
    final dst = Offset.zero & media;
    final src = (box != null && box.hasSize)
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromCenter(
            center: Offset(media.width / 2, media.height / 2),
            width: 1,
            height: 1,
          );

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 520),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (_, _, _) =>
            _ThemePreviewCarousel(initialIndex: initialIndex),
        transitionsBuilder: (_, anim, _, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeInOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return AnimatedBuilder(
            animation: curved,
            builder: (_, _) {
              final t = curved.value.clamp(0.0, 1.0);
              final rect = Rect.lerp(src, dst, t)!;
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
                              (src.center.dx / media.width) * 2 - 1,
                              (src.center.dy / media.height) * 2 - 1,
                            ),
                            radius: 1.4,
                            colors: [
                              sourceTheme.accent.withValues(alpha: 0.95),
                              sourceTheme.accent.withValues(alpha: 0.0),
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
    return GestureDetector(
      onTap: onApply,
      child: Container(
        decoration: BoxDecoration(
          color: outer.surface,
          borderRadius: BorderRadius.circular(outer.radiusLg),
          border: Border.all(
            color: active ? outer.accent : outer.divider,
            width: active ? 1.6 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: outer.accent.withValues(alpha: 0.30), blurRadius: 18)]
              : null,
        ),
        clipBehavior: Clip.antiAlias,
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
                            'ACTIVE',
                            style: outer.monoTiny.copyWith(color: outer.accent),
                          ),
                        ])
                      else
                        Text('tap to apply', style: outer.monoTiny.copyWith(color: outer.inkMuted)),
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
    );
  }
}

class _ThemePreviewCarousel extends StatefulWidget {
  const _ThemePreviewCarousel({required this.initialIndex});
  final int initialIndex;

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

  void _apply(BuildContext context, AppTheme t) {
    final controller = ThemeScope.controllerOf(context);
    controller.theme = t;
    SettingsStore.instance.setThemeId(t.id);
    HapticFeedback.mediumImpact();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final themes = ThemeController.all;
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
                      icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    ),
                    const Spacer(),
                    _Dots(count: themes.length, index: _index),
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
                onTap: () => _apply(context, themes[_index]),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: themes[_index].accent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: themes[_index].accent.withValues(alpha: 0.40),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Text(
                    'APPLY ${themes[_index].name.toUpperCase()}',
                    style: TextStyle(
                      color: themes[_index].accentInk,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
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
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;
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
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.35),
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
                Text('hey, you.', style: theme.displayHero),
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
                _mockRoomRow(theme, name: 'design club', sub: 'mia: shipped the new tile.', ephemeral: false, active: true),
                const SizedBox(height: 10),
                _mockRoomRow(theme, name: 'chamber · ☾', sub: 'sealed in 4h.', ephemeral: true, active: false),
                const SizedBox(height: 22),
                Text('CONVERSATION', style: theme.label),
                const SizedBox(height: 10),
                _bubble(theme, text: 'how does this feel?', mine: false),
                const SizedBox(height: 8),
                _bubble(theme, text: 'like the right one.', mine: true),
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
        decoration: theme.messageBubbleDecoration(isMine: mine, ephemeral: false),
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
