import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/brain_spec.dart';
import 'package:monkeyhub/companions/brain_store.dart';
import 'package:monkeyhub/companions/device_capability.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/screens/companions/companion_page.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// What Sebastian's storage section actually renders.
///
/// It was reported showing a single 617 MB row on a machine that should have
/// been offered more, with nothing on screen to say a better brain existed or
/// why it was not available. That is the kind of thing that is very easy to
/// believe you have fixed by reading the code, so this renders the rows instead
/// of reasoning about them.
void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sebastian_shelf_test');
    PathProviderPlatform.instance = _TmpPathProvider(tmp.path);
    BrainStore.instance.resetForTest();
  });

  tearDown(() async {
    DeviceCapability.instance.setRamForTest(null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  Widget host(List<Widget> children) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: Scaffold(body: ListView(children: children)),
    ),
  );

  /// The rows exactly as `SebastianScreen` builds them. Kept in step with the
  /// screen by using the same three public helpers it does — if any of them
  /// changes shape this stops compiling, which is the point.
  List<Widget> shelf(AppLocalizations l10n) => [
    for (final brain in BrainCatalog.sebastianBrains)
      BrainRow(
        brain: brain,
        name: sebastianTierName(brain),
        detail: brain.sizeLabel,
        unavailableReason: brainUnavailableReason(brain, l10n),
      ),
  ];

  Future<void> pumpShelf(WidgetTester tester) async {
    late List<Widget> rows;
    await tester.pumpWidget(
      host([
        Builder(
          builder: (context) {
            rows = shelf(AppLocalizations.of(context));
            return Column(children: rows);
          },
        ),
      ]),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('both of him are on screen, whatever the device', (tester) async {
    DeviceCapability.instance.setRamForTest(2048);
    await pumpShelf(tester);

    expect(find.text('Sebastian Sr.'), findsOneWidget);
    expect(find.text('Sebastian Jr.'), findsOneWidget);
  });

  /// The reported bug in its exact shape: the better brain silently missing,
  /// so the smaller one looks like all there is.
  testWidgets('a small device still SEES the brain it cannot run', (
    tester,
  ) async {
    DeviceCapability.instance.setRamForTest(2048);
    await pumpShelf(tester);

    expect(find.text('Sebastian Sr.'), findsOneWidget);
    expect(
      find.textContaining('4 GB'),
      findsOneWidget,
      reason: 'the row has to say WHY, not just be greyed out — "needs 4 GB" '
          'is checkable against your own phone, "unavailable" is not',
    );
  });

  /// A row this device cannot run offers nothing to press: no download button,
  /// so its size never appears. Pressing it could only fail.
  testWidgets('an unavailable row offers no download', (tester) async {
    DeviceCapability.instance.setRamForTest(2048);
    await pumpShelf(tester);

    expect(find.text(BrainCatalog.sebastianBrains.first.sizeLabel),
        findsNothing);
    expect(find.byIcon(Icons.block), findsOneWidget);
  });

  testWidgets('a large device is offered both, with no reason line', (
    tester,
  ) async {
    DeviceCapability.instance.setRamForTest(8192);
    await pumpShelf(tester);

    expect(find.textContaining('GB of memory'), findsNothing);
    expect(find.byIcon(Icons.block), findsNothing);
    for (final brain in BrainCatalog.sebastianBrains) {
      expect(find.text(brain.sizeLabel), findsWidgets, reason: brain.id);
    }
  });

  /// Unknown resolves downward, so an unsized machine is shown the same thing a
  /// small one is — including the reason.
  testWidgets('an unsized device is told what it would need', (tester) async {
    DeviceCapability.instance.setRamForTest(null);
    await pumpShelf(tester);

    expect(find.text('Sebastian Sr.'), findsOneWidget);
    expect(find.textContaining('4 GB'), findsOneWidget);
  });


}

class _TmpPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TmpPathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}
