import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/widgets/call_chrome.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/destructive_sheet.dart';

/// Which haptic the shared controls play. Each one stands for many call
/// sites — every destructive confirm, every call control — so a change that
/// moved the weight around would reach the whole app at once.
void main() {
  List<String> recordHaptics(WidgetTester tester) {
    final played = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        played.add('${call.arguments}'.replaceFirst('HapticFeedbackType.', ''));
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    return played;
  }

  Widget host(Widget child) => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: child)),
        ),
      );

  group('destructive confirm', () {
    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(host(Builder(
        builder: (context) => TextButton(
          onPressed: () => showConfirmSheet(
            context,
            headline: 'DELETE',
            body: 'Gone for good.',
            confirmLabel: 'Delete it',
          ),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('confirming lands one heavy impact', (tester) async {
      final haptics = recordHaptics(tester);
      await open(tester);
      await tester.tap(find.text('Delete it'));
      await tester.pumpAndSettle();
      expect(haptics, ['heavyImpact']);
    });

    testWidgets('backing out is silent', (tester) async {
      final haptics = recordHaptics(tester);
      await open(tester);
      final l10n = AppLocalizations.of(tester.element(find.text('Delete it')));
      await tester.tap(find.text(l10n.destructiveSheetCancelButtonLabel));
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
    });
  });

  group('call controls', () {
    /// Taps it and returns how many times its `onTap` ran.
    Future<int> tapControl(
      WidgetTester tester, {
      bool large = false,
      bool enabled = true,
    }) async {
      var taps = 0;
      await tester.pumpWidget(host(SizedBox(
        width: 120,
        child: CallControlButton(
          icon: Icons.mic_off,
          label: 'Mute',
          large: large,
          enabled: enabled,
          onTap: () => taps++,
        ),
      )));
      await tester.tap(find.byIcon(Icons.mic_off), warnIfMissed: false);
      await tester.pump();
      return taps;
    }

    testWidgets('a tray toggle ticks', (tester) async {
      final haptics = recordHaptics(tester);
      expect(await tapControl(tester), 1);
      expect(haptics, ['selectionClick']);
    });

    testWidgets('ending the call lands heavy', (tester) async {
      final haptics = recordHaptics(tester);
      expect(await tapControl(tester, large: true), 1);
      expect(haptics, ['heavyImpact']);
    });

    testWidgets('a disabled control is silent', (tester) async {
      final haptics = recordHaptics(tester);
      expect(await tapControl(tester, enabled: false), 0);
      expect(haptics, isEmpty);
    });
  });
}
