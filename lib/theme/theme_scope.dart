import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'vault_noir_theme.dart';
import 'risograph_pop_theme.dart';
import 'bio_organic_theme.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(AppTheme initial) : _theme = initial;
  AppTheme _theme;
  AppTheme get theme => _theme;
  set theme(AppTheme value) {
    if (value.id == _theme.id) return;
    _theme = value;
    notifyListeners();
  }

  static final List<AppTheme> all = [
    VaultNoirTheme(),
    RisographPopTheme(),
    BioOrganicTheme(),
  ];
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
