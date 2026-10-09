import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/moment.dart';
import 'package:monkeyhub/models/moment_group.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/moment_rail.dart';

/// What this pins: the ends of the moment flight still agree.
///
/// A Hero whose tag matches nothing does not throw, warn, or log — it simply
/// does not fly, and the picture cuts to full screen exactly as it did before
/// any of this existed. That is the only failure mode here and it is completely
/// silent, so the tag being present on the source thumbnail is worth a test of
/// its own.
class _FakeChatApi extends Fake implements ChatApi {
  // Null is a real answer from this API — a swept blob — and it keeps the test
  // off the network without the rail having to know it is in a test.
  @override
  Future<String?> getFileUrl(String storageId) async => null;
}

Moment _moment({String? media}) => Moment(
  id: 'm1',
  userId: 'u1',
  dayKey: '2026-08-08',
  createdAt: DateTime(2026, 8, 8, 9),
  expiresAt: DateTime(2026, 8, 9, 9),
  authorName: 'Ada',
  authorUsername: 'ada',
  mine: true,
  seen: true,
  caption: 'a caption',
  mediaStorageId: media,
  mediaKind: media == null ? MomentMedia.none : MomentMedia.image,
);

Widget _host(Moment moment) => ThemeScope(
  controller: ThemeController(BasicTheme.midnight()),
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MomentRail(
        groups: MomentGroup.of([moment]),
        api: _FakeChatApi(),
        serverNow: DateTime(2026, 8, 8, 12),
        onCapture: () {},
        onOpen: (_) {},
      ),
    ),
  ),
);

Finder _heroFor(String momentId) => find.byWidgetPredicate(
  (w) => w is Hero && w.tag == momentMediaHeroTag(momentId),
);

void main() {
  testWidgets('a rail card with a picture publishes the flight tag', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_moment(media: 'blob1')));
    await tester.pump();

    expect(_heroFor('m1'), findsOneWidget);
  });

  testWidgets('a caption-only card publishes none — there is nothing to fly', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_moment()));
    await tester.pump();

    expect(_heroFor('m1'), findsNothing);
  });
}
