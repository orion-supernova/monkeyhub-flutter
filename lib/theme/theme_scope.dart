import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'basic_theme.dart';
import 'bio_organic_theme.dart';
import 'character_themes.dart';
import 'cyberpunk_theme.dart';
import 'deep_ocean_theme.dart';
import 'neon_night_theme.dart';
import 'retro_wave_theme.dart';
import 'risograph_pop_theme.dart';
import 'vault_noir_theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(AppTheme initial) : _theme = initial;
  AppTheme _theme;
  AppTheme get theme => _theme;
  set theme(AppTheme value) {
    if (value.id == _theme.id) return;
    _theme = value;
    notifyListeners();
  }

  /// 5 Basic variants + 2 Vault variants + 9 singles = 16 total.
  /// Order matches the on-screen layout in `ThemeScreen` so the preview
  /// carousel iterates in the same order the user sees in the list.
  ///
  /// Implemented as an uncached getter so Dart hot-reload picks up re-orderings
  /// without a full restart — `static final` initializers run once per Isolate
  /// and won't re-evaluate when the source list changes during development.
  /// The theme objects themselves are lightweight (no per-frame allocations
  /// elsewhere — `all` is read once per build).
  static List<AppTheme> get all => [
        // BASIC family
        BasicTheme.midnight(),
        BasicTheme.daylight(),
        BasicTheme.graphite(),
        BasicTheme.rose(),
        BasicTheme.forest(),
        // VAULT family
        VaultNoirTheme.noir(),
        VaultNoirTheme.ivory(),
        // CHARACTERS (singles)
        PaperTheme(),
        DotTheme(),
        BloomTheme(),
        RisographPopTheme(),
        BioOrganicTheme(),
        CyberpunkTheme(),
        RetroWaveTheme(),
        NeonNightTheme(),
        DeepOceanTheme(),
      ];

  static AppTheme byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({super.key, required ThemeController controller, required super.child})
      : super(notifier: controller);

  static AppTheme of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope.of() called with no ThemeScope ancestor');
    return scope!.notifier!.theme;
  }

  static ThemeController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null);
    return scope!.notifier!;
  }
}
