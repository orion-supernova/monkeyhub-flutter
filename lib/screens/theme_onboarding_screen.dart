import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../data/settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/density.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/motion.dart';
import '../theme/theme_preference.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/app_brand_mark.dart' show canonicalLogoId;
import '../widgets/app_icon_picker.dart';
import '../widgets/appearance_picker.dart';
import '../widgets/ios_kit.dart';

/// The first thing a new install shows, before sign-in: how the app should
/// look, then which icon it should wear on the home screen.
///
/// Before the login screen rather than after it on purpose. The login screen is
/// the first screen with any character, and meeting it in a theme you would
/// never have picked — Midnight on a phone set to light mode, say — is a worse
/// first impression than one question asked first. It is also the only moment
/// the question is free: nothing is loaded, nobody is waiting.
///
/// Theme choices are written straight to [SettingsStore], and the app
/// re-themes around them — so the first step IS the preview. The icon step
/// exists because a theme can also change the home-screen icon, which not
/// everybody wants: [SettingsStore] holds every icon swap until this flow
/// finishes, and the step defaults to keeping the icon already on the home
/// screen, so nothing changes there unless it is chosen here.
class ThemeOnboardingScreen extends StatefulWidget {
  const ThemeOnboardingScreen({super.key});

  @override
  State<ThemeOnboardingScreen> createState() => _ThemeOnboardingScreenState();
}

class _ThemeOnboardingScreenState extends State<ThemeOnboardingScreen> {
  int _step = 0;

  /// The icon on the home screen before this flow started. A fresh install
  /// that has never chosen is showing the primary MonkeyHub icon whatever the
  /// mode says — no swap is ever applied before onboarding — so "auto" reads
  /// as the MonkeyHub mark here.
  late final String _currentIcon =
      SettingsStore.instance.logoMode == LogoMode.auto
          ? canonicalLogoId
          : currentIconChoice(SettingsStore.instance);
  late String _iconChoice = _currentIcon;

  bool get _showsIosNote =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _finish() async {
    final store = SettingsStore.instance;
    await applyIconChoice(store, _iconChoice);
    await store.markThemeOnboarded();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final motion = MotionScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            bottom: false,
            child: AdaptivePageBody(
              child: Column(
                children: [
                  SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          AnimatedSwitcher(
                            duration: motion.d(const Duration(milliseconds: 220)),
                            child: _step == 1
                                ? GlassBackButton(
                                    key: const ValueKey('back'),
                                    onTap: () => setState(() => _step = 0),
                                  )
                                : SizedBox(
                                    key: const ValueKey('none'),
                                    width: Density.of(context).iconButton,
                                  ),
                          ),
                          const Spacer(),
                          _PageDots(count: 2, index: _step),
                          const Spacer(),
                          SizedBox(width: Density.of(context).iconButton),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: _steps(context, motion)),
                        // Content dissolves into the page above the button
                        // instead of being sliced off by it. A painted
                        // gradient rather than a ShaderMask, which would
                        // force an offscreen layer on every scroll frame.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 28,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    theme.background.withValues(alpha: 0),
                                    theme.background,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      10,
                      20,
                      edgeToEdgeBottom(context, 16),
                    ),
                    // The one big commit on the screen: it plays the heavier
                    // haptic itself instead of the default selection tick.
                    child: SheetActionButton(
                      label: _step == 0
                          ? l10n.onboardingContinue
                          : l10n.onboardingGetStarted,
                      haptic: false,
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        if (_step == 0) {
                          setState(() => _step = 1);
                        } else {
                          _finish();
                        }
                      },
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

  Widget _steps(BuildContext context, MotionScope motion) {
    final theme = ThemeScope.of(context);
    return AnimatedSwitcher(
      duration: motion.d(const Duration(milliseconds: 380)),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        // Forward pushes in from the trailing edge, back from the leading
        // one — the direction the dots move.
        final incoming = child.key == ValueKey(_step);
        final from = (_step == 1) == incoming ? 0.12 : -0.12;
        return FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(
              begin: Offset(from, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        );
      },
      child: _step == 0
          ? AnimatedBuilder(
              key: const ValueKey(0),
              animation: SettingsStore.instance,
              builder: (context, _) => _LookStep(theme: theme),
            )
          : _IconStep(
              key: const ValueKey(1),
              selected: _iconChoice,
              current: _currentIcon,
              showIosNote: _showsIosNote,
              onSelect: (id) => setState(() => _iconChoice = id),
            ),
    );
  }
}

/// Step one: the look.
class _LookStep extends StatelessWidget {
  const _LookStep({required this.theme});

  final AppTheme theme;

  /// Calm, native-feeling palettes — the Basic family.
  static bool _isEssential(AppTheme t) => t.id.startsWith('basic');

  // Listens to the settings it reads: this widget is built `const`, and a
  // const widget is never rebuilt by its parent, so a changed setting would
  // otherwise leave it showing the old value.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: SettingsStore.instance,
        builder: (context, _) => _buildListening(context),
      );

  Widget _buildListening(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = SettingsStore.instance;
    final mode = store.appearanceMode;
    final all = ThemeController.all;
    final platform = MediaQuery.platformBrightnessOf(context);

    void setMode(AppearanceMode next) =>
        store.setAppearanceMode(next, current: theme.id);

    // Essentials first within every strip, so the calm choices are the ones
    // under the thumb and the characters are a swipe away.
    List<AppTheme> ordered(Iterable<AppTheme> ts) => [
          for (final t in ts) if (_isEssential(t)) t,
          for (final t in ts) if (!_isEssential(t)) t,
        ];

    // No horizontal padding on the list itself: the theme strips are shelves,
    // and a shelf runs off the trailing screen edge (App Store, Photos) rather
    // than stopping dead at the gutter with a sliver of the next card and a
    // stray "|" of its name. Everything else carries the 20pt gutter itself;
    // the strips keep it on the leading edge only, so the first card still
    // lines up with the title above it.
    Widget gutter(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: child,
        );
    Widget shelf(Widget strip) => Padding(
          padding: const EdgeInsets.only(left: 18),
          child: strip,
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
      children: [
        gutter(const _BrandEntrance()),
        const SizedBox(height: 20),
        gutter(Text(
          l10n.onboardingLookTitle,
          style: theme.displayLarge.copyWith(letterSpacing: 0.37),
        )),
        const SizedBox(height: 6),
        gutter(Text(l10n.onboardingLookBody, style: theme.bodySoft)),
        const SizedBox(height: 22),
        gutter(AppearanceModeSwitch(mode: mode, onChanged: setMode)),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: MotionScope.of(context).d(theme.motionMed),
          switchInCurve: theme.motionEntrance,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SizeTransition(
              sizeFactor: anim,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
          child: mode == AppearanceMode.system
              ? Column(
                  key: const ValueKey('pair'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    gutter(_StripHeading(
                      title: l10n.onboardingLightMode,
                      now: platform == Brightness.light
                          ? l10n.onboardingNow
                          : null,
                    )),
                    shelf(ThemeStrip(
                      themes: ordered(all.where((t) => t.isLight)),
                      selectedId: store.lightThemeId,
                      onSelect: (t) =>
                          store.setSlotTheme(Brightness.light, t.id),
                    )),
                    const SizedBox(height: 14),
                    gutter(_StripHeading(
                      title: l10n.onboardingDarkMode,
                      now: platform == Brightness.dark
                          ? l10n.onboardingNow
                          : null,
                    )),
                    shelf(ThemeStrip(
                      themes: ordered(all.where((t) => !t.isLight)),
                      selectedId: store.darkThemeId,
                      onSelect: (t) =>
                          store.setSlotTheme(Brightness.dark, t.id),
                    )),
                  ],
                )
              : Column(
                  key: const ValueKey('fixed'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    gutter(_StripHeading(
                      title: l10n.onboardingEssentials,
                      sub: l10n.onboardingEssentialsSub,
                    )),
                    shelf(ThemeStrip(
                      themes: [for (final t in all) if (_isEssential(t)) t],
                      selectedId: theme.id,
                      onSelect: (t) => store.setThemeId(t.id),
                    )),
                    const SizedBox(height: 14),
                    gutter(_StripHeading(
                      title: l10n.onboardingCharacters,
                      sub: l10n.onboardingCharactersSub,
                    )),
                    shelf(ThemeStrip(
                      themes: [for (final t in all) if (!_isEssential(t)) t],
                      selectedId: theme.id,
                      onSelect: (t) => store.setThemeId(t.id),
                    )),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Step two: the home-screen icon.
class _IconStep extends StatelessWidget {
  const _IconStep({
    super.key,
    required this.selected,
    required this.current,
    required this.showIosNote,
    required this.onSelect,
  });

  final String selected;
  final String current;
  final bool showIosNote;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          l10n.onboardingIconTitle,
          style: theme.displayLarge.copyWith(letterSpacing: 0.37),
        ),
        const SizedBox(height: 6),
        Text(l10n.onboardingIconBody, style: theme.bodySoft),
        const SizedBox(height: 26),
        AppIconPicker(
          selected: selected,
          current: current,
          onSelect: onSelect,
        ),
        if (showIosNote) ...[
          const SizedBox(height: 18),
          Text(
            l10n.onboardingIconIosNote,
            textAlign: TextAlign.center,
            style: groupedMetaStyle(theme),
          ),
        ],
      ],
    );
  }
}

/// The app's mark arriving on a spring: it drops in a little small and
/// overshoots into place, once, the first time the screen is built.
class _BrandEntrance extends StatelessWidget {
  const _BrandEntrance();

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
    final motion = MotionScope.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: motion.d(const Duration(milliseconds: 1100)),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(
          scale: 0.55 + 0.45 * v,
          alignment: Alignment.bottomCenter,
          child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
        ),
        child: Transform.rotate(
          angle: -0.06,
          child: Container(
            width: 60,
            height: 60,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              shape: ContinuousRectangleBorder(
                borderRadius: BorderRadius.circular(60 * 0.45),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 18,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            // The theme's own launcher art, live: picking a theme below
            // re-colours the mark above it.
            child: appIconArt(SettingsStore.instance, theme.id, 60),
          ),
        ),
      ),
    );
  }
}

class _StripHeading extends StatelessWidget {
  const _StripHeading({required this.title, this.sub, this.now});

  final String title;
  final String? sub;

  /// "Now", on the half of the pair the device is showing.
  final String? now;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: groupedHeaderStyle(theme)),
          if (sub != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                sub!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: groupedMetaStyle(theme),
              ),
            ),
          ],
          if (now != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: quietFill(theme),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                now!,
                // Meta size (13/w600) on the body face — it was 11pt caption,
                // off the scale and monospace on character themes.
                style: groupedMetaStyle(theme).copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.accent,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where you are in the flow: the current step a pill, the rest dots.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: motion.d(const Duration(milliseconds: 320)),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 20 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == index
                  ? theme.ink
                  : theme.ink.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
