import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/fight/view/art/kai_poses.dart';
import 'package:monkeyhub/fight/view/fight_online_screen.dart';
import 'package:monkeyhub/fight/view/fighter_portrait.dart';

final String? shotDir = Platform.environment['FIGHT_SHOTS'];

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('the ready flourish punches, then settles into guard', () {
    expect(portraitPose(5, readyAt: 5.0).lean, isNot(pHvyX.lean));
    expect(portraitPose(5.3, readyAt: 5.0).v, pHvyX.v);
    expect(portraitPose(7, readyAt: 5.0).fu, closeTo(pGuard.fu, 1e-9));
  });

  testWidgets('VS cards: both fighters drawn, the ready one mid-punch', (tester) async {
    tester.view.physicalSize = const Size(393, 300) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    Widget row(bool rightReady) => RepaintBoundary(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xff3b1f5e),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Expanded(child: FightSeatCard(name: 'muratcankoc', ready: true, tone: 0, height: 240, charId: 0)),
                const SizedBox(width: 50),
                Expanded(child: FightSeatCard(name: 'zeynepoz', ready: rightReady, tone: 1, height: 240, charId: 3)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(row(false));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(row(true));
    await tester.pump(const Duration(milliseconds: 250)); // right one mid-punch
    expect(find.byType(FighterPortrait), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    if (shotDir != null) {
      await tester.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(shotDir!).createSync(recursive: true);
        File('$shotDir/vs_cards.png').writeAsBytesSync(png!.buffer.asUint8List());
      });
    }
  });
}
