import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_button.dart';
import 'package:monkeyhub/calls/call_models.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/ui/foundation/caps.dart';
import 'package:monkeyhub/ui/foundation/ui_kit.dart';
import 'package:monkeyhub/ui/native/native_control.dart';
import 'package:monkeyhub/widgets/action_buttons.dart';
import 'package:monkeyhub/widgets/glass_buttons.dart';
import 'package:monkeyhub/widgets/labeled_field.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart' show GlassTone;
import 'package:monkeyhub/widgets/password_field.dart';
import 'package:monkeyhub/widgets/pull_down_button.dart';
import 'package:monkeyhub/widgets/pull_down_menu.dart';
import 'package:monkeyhub/widgets/search_field.dart';
import 'package:monkeyhub/widgets/viewer_chrome.dart';

void main() {
  /// A test on an iOS with Liquid Glass. The platform override is put back
  /// inside the body: the framework checks foundation variables before any
  /// tearDown runs.
  void iosTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      Caps.nativeGlassProbe = true;
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        Caps.nativeGlassProbe = false;
        UiKits.debugNativeControls = null;
      }
    });
  }

  /// The overlay channel's traffic: every `set` (id, spec) in order.
  final sets = <(String, Map<String, Object?>)>[];

  Future<void> pump(WidgetTester tester, Widget child, {UiKit kit = UiKit.liquid}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    sets.clear();
    const overlay = MethodChannel('monkeyhub/native_overlay');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      overlay,
      (call) async {
        if (call.method == 'set') {
          final m = (call.arguments as Map).cast<String, Object?>();
          sets.add((
            m['id'] as String,
            (m['spec'] as Map).cast<String, Object?>(),
          ));
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        overlay,
        null,
      ),
    );
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UiKitScope(
            kit: kit,
            child: Material(child: Center(child: SizedBox(width: 340, child: child))),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<Map> specs(WidgetTester tester) => [
    for (final v in tester.widgetList<NativeControl>(find.byType(NativeControl)))
      v.spec.toMap(),
  ];

  String kindOf(WidgetTester tester) {
    final all = specs(tester);
    expect(all, hasLength(1), reason: 'exactly one native control');
    return all.single['kind'] as String;
  }

  final cases = <String, (Widget Function(), String)>{
    'GlassButtonGroup': (
      () => GlassButtonGroup(
        tone: GlassTone.app,
        items: [
          GlassGroupItem(icon: CupertinoIcons.camera, semanticLabel: 'a', onTap: () {}),
          GlassGroupItem(icon: CupertinoIcons.mic, semanticLabel: 'b', onTap: () {}),
        ],
      ),
      'buttonGroup',
    ),
    'GlassPillButton': (() => GlassPillButton(label: 'Pill', onTap: () {}), 'button'),
    'RowPillButton': (() => RowPillButton(label: 'Remove', onTap: () {}), 'button'),
    'ThemedInput': (
      () => ThemedInput(controller: TextEditingController(), hint: 'Name'),
      'textField',
    ),
    'SheetTextField': (
      () => SheetTextField(controller: TextEditingController(), hint: 'Name'),
      'textField',
    ),
    'PasswordField': (
      () => PasswordField(controller: TextEditingController(), hint: 'Password'),
      'textField',
    ),
    'SearchField': (
      () => SearchField(
        controller: TextEditingController(),
        hintText: 'Search',
        showCancel: false,
        onChanged: (_) {},
      ),
      'searchField',
    ),
    'PullDownButton': (
      () => PullDownButton<int>(
        semanticLabel: 'More',
        items: const [PullDownItem(value: 1, label: 'One')],
        onSelected: (_) {},
      ),
      'menu',
    ),
    'ViewerToolbar': (
      () => ViewerToolbar(
        actions: [
          ViewerToolbarAction(
            icon: CupertinoIcons.trash,
            semanticLabel: 'Delete',
            onTap: () {},
          ),
        ],
      ),
      'toolbar',
    ),
    'CallGlyphButton': (
      () => CallGlyphButton(
        kind: CallMediaKind.audio,
        enabled: true,
        onTap: () {},
        size: 44,
      ),
      'symbolButton',
    ),
  };

  for (final entry in cases.entries) {
    iosTest('${entry.key}: native ${entry.value.$2} in the liquid kit', (tester) async {
      UiKits.debugNativeControls = true;
      await pump(tester, entry.value.$1());
      expect(kindOf(tester), entry.value.$2);
    });

    iosTest('${entry.key}: no platform view with native controls off', (tester) async {
      UiKits.debugNativeControls = false;
      await pump(tester, entry.value.$1());
      expect(find.byType(NativeControl), findsNothing);
    });

    iosTest('${entry.key}: no platform view in the frosted kit', (tester) async {
      UiKits.debugNativeControls = true;
      await pump(tester, entry.value.$1(), kit: UiKit.glass);
      expect(find.byType(NativeControl), findsNothing);
    });
  }

  iosTest('a multi-line field keeps the Flutter skin', (tester) async {
    UiKits.debugNativeControls = true;
    await pump(
      tester,
      ThemedInput(controller: TextEditingController(), hint: 'Notes', maxLines: 4),
    );
    expect(find.byType(NativeControl), findsNothing);
  });

  iosTest('a field with a character limit keeps the Flutter skin', (tester) async {
    UiKits.debugNativeControls = true;
    await pump(
      tester,
      SheetTextField(controller: TextEditingController(), hint: 'Bio', maxLength: 80),
    );
    expect(find.byType(NativeControl), findsNothing);
  });

  iosTest('a busy row pill keeps the Flutter skin', (tester) async {
    UiKits.debugNativeControls = true;
    await pump(tester, RowPillButton(label: 'Remove', busy: true, onTap: () {}));
    expect(find.byType(NativeControl), findsNothing);
  });

  iosTest('a lit group slot keeps the Flutter skin', (tester) async {
    UiKits.debugNativeControls = true;
    await pump(
      tester,
      GlassButtonGroup(
        tone: GlassTone.app,
        items: [
          GlassGroupItem(
            icon: CupertinoIcons.camera,
            semanticLabel: 'a',
            active: true,
            onTap: () {},
          ),
        ],
      ),
    );
    expect(find.byType(NativeControl), findsNothing);
  });

  iosTest('native typing reaches the controller; an outside edit bumps textRev', (tester) async {
    UiKits.debugNativeControls = true;
    final controller = TextEditingController(text: 'hi');
    String? changed;
    await pump(
      tester,
      ThemedInput(controller: controller, hint: 'Name', onChanged: (v) => changed = v),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final id = sets.last.$1;
    List<Map<String, Object?>> updates() =>
        [for (final (i, spec) in sets) if (i == id) spec];
    final sent = specs(tester).single;
    expect(sent['text'], 'hi');
    expect(sent['textRev'], 0);
    final before = updates().length;

    const codec = StandardMethodCodec();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'monkeyhub/native_overlay',
      codec.encodeMethodCall(
        MethodCall('event', {'id': id, 'name': 'changed', 'value': 'hello'}),
      ),
      (_) {},
    );
    await tester.pump();
    expect(controller.text, 'hello');
    expect(controller.selection.baseOffset, 5);
    expect(changed, 'hello');
    expect(updates().skip(before).where((u) => u['textRev'] != 0), isEmpty,
        reason: 'typing must not be echoed back');

    controller.text = '';
    await tester.pump();
    expect(updates().last['text'], '');
    expect(updates().last['textRev'], 1);
  });

  iosTest('a keyed control keeps one copy of its key (the stand-in is its build)', (tester) async {
    UiKits.debugNativeControls = true;
    final key = GlobalKey();
    await pump(
      tester,
      GlassIconButton(key: key, icon: CupertinoIcons.plus, onTap: () {}),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(NativeControl), findsOneWidget);
    // The stand-in shows until the native view reports it is on screen.
    expect(find.byIcon(CupertinoIcons.plus), findsOneWidget);
  });

  test('NativeSpec wire format', () {
    final menu = NativeSpec.menu(
      symbol: 'ellipsis',
      items: const [
        NativeMenuItemSpec(id: '0', label: 'One', checked: true),
        NativeMenuItemSpec.divider(),
      ],
    ).toMap();
    expect(menu['kind'], 'menu');
    expect((menu['items'] as List).length, 2);
    final date = NativeSpec.datePicker(ms: 1000, minMs: 0, style: 'wheel').toMap();
    expect(date['dateMs'], 1000.0);
    expect(date.containsKey('maxDateMs'), isFalse);
    expect(NativeSpec.toolbar(options: const [], blend: 12).toMap()['blend'], 12);
  });
}
