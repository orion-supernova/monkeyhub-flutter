// Folded highlights opening, caught mid-flight: the stacked pictures on
// their way down into their own lines.
//
//   flutter test test/design_preview/activity_flight_preview.dart
//
// Not a test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/moment_activity.dart';

import 'preview_kit.dart';

final _now = DateTime.now();

Moment _m(String id, String caption, int ago) => Moment(
  id: id,
  userId: 'u_a',
  dayKey: '2026-10-14',
  createdAt: _now.subtract(Duration(minutes: ago)),
  expiresAt: _now.add(const Duration(hours: 20)),
  authorName: 'Alperen Subaşı',
  authorUsername: 'alperen',
  mine: false,
  seen: true,
  caption: caption,
  mediaStorageId: 'img_$id',
  mediaKind: MomentMedia.image,
);

void main() {
  setUpAll(loadPreviewFonts);
  for (final (name, ms) in [('0', 0), ('35', 90), ('70', 180), ('100', 600)]) {
    testWidgets('flight $name', (tester) async {
      await snap(
        tester,
        previewApp(
          ThemeController.byId('basic'),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: MomentActivity(
                moments: [
                  _m('a1', 'Atıştırmaya devamm', 120),
                  _m('a2', 'Kütüpe mola verdik', 130),
                  _m('a3', 'Sabah kahvesi', 140),
                  _m('a4', 'Akşam yürüyüşü', 150),
                ],
                viewerId: 'u1',
                api: ChatApi(ConvexBackend.instance),
                onOpen: (_, _) {},
              ),
            ),
          ),
        ),
        'activity_flight_$name.png',
        size: const Size(393, 520),
        settle: Duration.zero,
        act: () async {
          await tester.pump(const Duration(milliseconds: 600));
          await tester.tap(find.textContaining('posted 4'));
          await tester.pump(); // the lines lay out
          await tester.pump(); // measured; the flight starts
          if (ms > 0) await tester.pump(Duration(milliseconds: ms));
        },
      );
    });
  }
}
