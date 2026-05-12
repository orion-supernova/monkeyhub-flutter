import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'basic_theme.dart';
import 'bio_organic_theme.dart';
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

  /// 3 originals + 5 ports from v02 = 8 total.
  static final List<AppTheme> all = [
    VaultNoirTheme(),
    RisographPopTheme(),
    BioOrganicTheme(),
    BasicTheme(),
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
