import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/busy_scrim.dart';

/// The scrim raised over a pick, where the app is working and nothing else on
/// screen says so.
///
/// Two properties, and the second is the one worth a test: it must eat the tap
/// aimed at whatever is underneath it. The attach button is directly beneath this
/// scrim, and a second tap on it during a pick used to open a second picker.
void main() {
  Widget host({required VoidCallback onUnderneath}) => MaterialApp(
        home: ThemeScope(
          controller: ThemeController(BasicTheme.midnight()),
          child: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onUnderneath,
                    child: const SizedBox.expand(),
                  ),
                ),
                const BusyScrim(),
              ],
            ),
          ),
        ),
      );

  testWidgets('shows a spinner', (tester) async {
    await tester.pumpWidget(host(onUnderneath: () {}));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('swallows a tap meant for what is underneath it', (tester) async {
    var tapsThrough = 0;
    await tester.pumpWidget(host(onUnderneath: () => tapsThrough++));

    await tester.tap(find.byType(BusyScrim));
    await tester.pump();

    expect(tapsThrough, 0);
  });
}
