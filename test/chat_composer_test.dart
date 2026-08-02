import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/chat_composer.dart';

/// The composer's optional buttons.
///
/// `onAttach` and `onCamera` are nullable, and that is load-bearing rather than
/// tidy: `thread_overlay.dart` builds both composers inside a root
/// `OverlayEntry` and passes neither, because both open full-screen routes that
/// would fight the overlay for layering. A camera button that appeared there
/// anyway would look fine in a screenshot and misbehave only when tapped —
/// hence a test.
///
/// Both composers are covered. Which one is built is a call-site decision keyed
/// off the user's chat style, so a change that only reached one of them would
/// ship broken for half the users.
void main() {
  Widget host(Widget composer) => MaterialApp(
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: composer),
      ),
    ),
  );

  final composers = <String, Widget Function({VoidCallback? onCamera})>{
    'classic': ({onCamera}) => ChatComposerClassic(
      controller: TextEditingController(),
      ephemeral: false,
      onSend: () {},
      onAttach: () {},
      onCamera: onCamera,
    ),
    'liquid': ({onCamera}) => ChatComposerLiquid(
      controller: TextEditingController(),
      ephemeral: false,
      onSend: () {},
      onAttach: () {},
      onCamera: onCamera,
    ),
  };

  composers.forEach((name, build) {
    group(name, () {
      testWidgets('shows a camera button when one is wired up', (tester) async {
        var taps = 0;
        await tester.pumpWidget(host(build(onCamera: () => taps++)));
        await tester.pumpAndSettle();

        final camera = find.byIcon(Icons.photo_camera_outlined);
        expect(camera, findsOneWidget);

        await tester.tap(camera);
        await tester.pumpAndSettle();
        expect(taps, 1);
      });

      testWidgets('omits it entirely when there is nowhere to go', (
        tester,
      ) async {
        await tester.pumpWidget(host(build()));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
        // The rest of the composer is untouched — this is an absent button, not
        // a broken row.
        expect(find.byIcon(Icons.add), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
      });
    });
  });
}
