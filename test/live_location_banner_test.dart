import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/live_location_banner.dart';

/// The strip under a chat's header while someone shares live location there:
/// the share stays one tap away after its bubble has scrolled off.
void main() {
  final now = DateTime.now();
  ChatMessage share(String id, String sender) => ChatMessage(
    id: id,
    roomId: 'r',
    senderId: sender,
    senderName: sender == 'u2' ? 'Zeynep' : 'Ada',
    content: '',
    createdAt: now,
    type: MessageType.liveLocation,
    latitude: 41,
    longitude: 29,
    liveExpiresAt: now.add(const Duration(minutes: 30)),
    liveUpdatedAt: now,
  );

  Widget host(Widget child) => ThemeScope(
    controller: ThemeController(BasicTheme.midnight()),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Column(children: [child])),
    ),
  );

  testWidgets('one share names the person and opens their map', (
    tester,
  ) async {
    ChatMessage? opened;
    await tester.pumpWidget(
      host(
        LiveLocationBanner(
          shares: [share('m1', 'u2')],
          currentUserId: 'me',
          authorOf: (_) => null,
          onOpen: (m) => opened = m,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Zeynep is sharing live location'), findsOneWidget);
    await tester.tap(find.text('View'));
    expect(opened?.id, 'm1');
  });

  testWidgets('your own share says so; none takes no space', (tester) async {
    await tester.pumpWidget(
      host(
        LiveLocationBanner(
          shares: [share('m1', 'me')],
          currentUserId: 'me',
          authorOf: (_) => null,
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("You're sharing live location"), findsOneWidget);

    await tester.pumpWidget(
      host(
        LiveLocationBanner(
          shares: const [],
          currentUserId: 'me',
          authorOf: (_) => null,
          onOpen: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(LiveLocationBanner)).height, 0);
  });
}
