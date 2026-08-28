import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/server_directory.dart';
import 'package:monkeyhub/backend/server_endpoint.dart';
import 'package:monkeyhub/backend/server_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/server_role_sheet.dart';

/// The sheet behind the server bar explains why this device is not on the
/// ordinary deployment. It is opened by a tap available on every screen, to
/// every user, so the one rule it shares with every other server surface is the
/// one worth a test of its own: **only an address the user chose is printed.**
///
/// The home server's is not that. It names a machine on the operator's domestic
/// line, and nothing in the sheet asks the reader to act on it.
void main() {
  const surface = Size(390, 700);

  const selfHosted = ServerEndpoint(deploymentUrl: 'https://chat.example.com');
  final homeserver = KnownHosts.endpointFor(ServerRole.homeserver);

  Widget scene() {
    final controller = ThemeController(ThemeController.byId('basic'));
    return MediaQuery(
      data: const MediaQueryData(size: surface),
      child: ThemeScope(
        controller: controller,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showServerRoleInfo(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Size the window as well as the MediaQuery: `showAdaptiveSheet` picks a
  /// bottom sheet or a desktop popover by window width, and the default test
  /// surface is wide enough to get the other one.
  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(scene());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    ServerStore.instance.resetForTest();
  });

  testWidgets("never prints the home server's address", (tester) async {
    ServerStore.instance.setForTest(homeserver);
    await open(tester);
    expect(find.text('Running on the homeserver'), findsOneWidget);
    // The sentences stay; the address does not. This is the assertion the sheet
    // used to fail — it printed the host under the title unconditionally, on
    // the one surface where the host is not the reader's to check.
    expect(find.textContaining('walhallaa'), findsNothing);
  });

  testWidgets('prints the address of a server the user typed in', (
    tester,
  ) async {
    ServerStore.instance.setForTest(selfHosted);
    await open(tester);
    expect(find.text('Your own server'), findsOneWidget);
    expect(find.text('chat.example.com'), findsOneWidget);
  });

  testWidgets("prints the operator's address when the user pinned it", (
    tester,
  ) async {
    // Typing that address in makes it a server they chose, and a server someone
    // chose is theirs to see — they are the one who supplied it.
    ServerStore.instance.setForTest(homeserver, pinned: true);
    await open(tester);
    expect(find.text('Your own server'), findsOneWidget);
    expect(find.text(KnownHosts.homeserverHost), findsOneWidget);
  });
}
