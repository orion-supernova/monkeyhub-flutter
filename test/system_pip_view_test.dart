import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/call_pip.dart';
import 'package:monkeyhub/calls/widgets/system_pip_view.dart';

Widget _host() => const Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(children: [SizedBox.expand(), SystemPipView()]),
    );

void main() {
  tearDown(() => CallPip.instance.debugReset());

  testWidgets('out of PiP it is an empty box', (tester) async {
    CallPip.instance.spec.value = const CallPipSpec(title: 'Ada');
    await tester.pumpWidget(_host());
    expect(find.text('Ada'), findsNothing);
    expect(find.byType(ColoredBox), findsNothing);
  });

  testWidgets('in PiP with the picture off it shows the name card',
      (tester) async {
    CallPip.instance.spec.value = const CallPipSpec(title: 'Ada Lovelace');
    CallPip.instance.inPip.value = true;
    await tester.pumpWidget(_host());
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Back out of PiP: gone again.
    CallPip.instance.inPip.value = false;
    await tester.pump();
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  testWidgets('the name card fits a tiny window', (tester) async {
    tester.view.physicalSize = const Size(120, 213);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    CallPip.instance.spec.value = const CallPipSpec(title: 'A very long name for a tiny window');
    CallPip.instance.inPip.value = true;
    await tester.pumpWidget(_host());
    expect(tester.takeException(), isNull);
  });
}
