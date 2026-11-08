import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/ui/native/native_composer_input.dart';
import 'package:monkeyhub/ui/native/native_control.dart';

/// The native composer field's contract with Dart: typing (with its
/// selection) flows native to controller and is never echoed back; Dart's
/// own edits go out only with a new `textRev`; the field is as tall as the
/// native view reports; the smiley and focus come back as events.
void main() {
  late List<Map<String, Object?>> sets;
  late String id;

  Future<void> send(WidgetTester tester, String name, Object? value) async {
    const codec = StandardMethodCodec();
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'monkeyhub/native_overlay',
      codec.encodeMethodCall(
        MethodCall('event', {'id': id, 'name': name, 'value': value}),
      ),
      (_) {},
    );
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester, Widget field) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    sets = [];
    const overlay = MethodChannel('monkeyhub/native_overlay');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(overlay, (
      call,
    ) async {
      if (call.method == 'set') {
        final a = (call.arguments as Map).cast<String, Object?>();
        id = a['id'] as String;
        sets.add((a['spec'] as Map).cast<String, Object?>());
      }
      return null;
    });
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
          home: Material(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(width: 300, child: field),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('typing flows into the controller with its selection and is '
      'not echoed back', (tester) async {
    final controller = TextEditingController();
    final changes = <String>[];
    await pump(
      tester,
      NativeComposerInput(controller: controller, onChanged: changes.add),
    );
    expect(sets.last['kind'], 'composerField');
    final rev = sets.last['textRev'];
    await send(tester, 'changed', {'text': 'hi @al', 'start': 6, 'end': 6});
    expect(controller.text, 'hi @al');
    expect(controller.selection, const TextSelection.collapsed(offset: 6));
    expect(changes, ['hi @al']);
    expect(sets.last['textRev'], rev, reason: 'typing is never echoed back');
  });

  testWidgets('a Dart edit (the clear after a send, a mention) goes out with '
      'a new textRev and the selection to apply', (tester) async {
    final controller = TextEditingController();
    await pump(tester, NativeComposerInput(controller: controller));
    await send(tester, 'changed', {'text': 'hi @al', 'start': 6, 'end': 6});
    final rev = sets.last['textRev'] as int;
    controller.value = const TextEditingValue(
      text: 'hi @alice ',
      selection: TextSelection.collapsed(offset: 10),
    );
    await tester.pump();
    expect(sets.last['textRev'], rev + 1);
    expect(sets.last['text'], 'hi @alice ');
    expect(sets.last['selStart'], 10);
    controller.clear();
    await tester.pump();
    expect(sets.last['textRev'], rev + 2);
    expect(sets.last['text'], '');
  });

  testWidgets('it is as tall as the native view reports', (tester) async {
    final controller = TextEditingController();
    await pump(tester, NativeComposerInput(controller: controller));
    expect(tester.getSize(find.byType(NativeControl)).height, 44);
    await send(tester, 'height', 85.0);
    expect(tester.getSize(find.byType(NativeControl)).height, 85);
  });

  testWidgets('the smiley and a touch on the field come back', (tester) async {
    final controller = TextEditingController();
    final node = FocusNode();
    addTearDown(node.dispose);
    var smiley = 0;
    var taps = 0;
    await pump(
      tester,
      NativeComposerInput(
        controller: controller,
        focusNode: node,
        trailingSymbol: 'face.smiling',
        onTrailing: () => smiley++,
        onFieldTap: () => taps++,
      ),
    );
    expect(sets.last['symbol'], 'face.smiling');
    await send(tester, 'trailing', null);
    expect(smiley, 1);
    await send(tester, 'focus', true);
    expect(node.hasFocus, isTrue);
    expect(taps, 1);
    await send(tester, 'focus', false);
    expect(node.hasFocus, isFalse);
  });
}
