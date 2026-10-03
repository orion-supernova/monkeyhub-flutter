import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/labeled_field.dart';

void main() {
  Future<void> pumpHint(WidgetTester tester, String hint) =>
      tester.pumpWidget(ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ThemedInput(controller: TextEditingController(), hint: hint),
          ),
        ),
      ));

  testWidgets('a worded hint reads in sentence case', (tester) async {
    await pumpHint(tester, 'your name');
    expect(find.text('Your name'), findsOneWidget);
  });

  testWidgets('an example value is shown exactly as typed', (tester) async {
    for (final hint in [
      'https://chat.example.com',
      '@murat',
      'you@example.com',
      'chat.example.com',
    ]) {
      await pumpHint(tester, hint);
      expect(find.text(hint), findsOneWidget, reason: hint);
    }
  });
}
