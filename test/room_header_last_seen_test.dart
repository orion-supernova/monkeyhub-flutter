@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/room_capabilities.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/screens/room_screen.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';

final _room = ChatRoom(
  id: 'dm1',
  name: 'dm:regular:me:ece',
  createdBy: 'me',
  createdAt: DateTime(2026),
  isPrivate: true,
  memberCount: 2,
  participantIds: const ['me', 'ece'],
);

Widget _host(ChatUser user) => ThemeScope(
      controller: ThemeController(BasicTheme.midnight()),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                roomHeaderStatus(
                  context,
                  room: _room,
                  dmUser: user,
                  typists: const [],
                ) ??
                const SizedBox(),
          ),
        ),
      ),
    );

ChatUser _user({String? status, DateTime? lastSeen}) => ChatUser(
      id: 'ece',
      username: 'ece',
      name: 'Ece',
      status: status,
      lastSeen: lastSeen,
    );

void main() {
  testWidgets('online says Online', (t) async {
    await t.pumpWidget(_host(_user(status: 'online')));
    expect(find.text('Online'), findsOneWidget);
  });

  testWidgets('offline with a known lastSeen says when', (t) async {
    final now = DateTime.now();
    await t.pumpWidget(_host(_user(
      status: 'offline',
      lastSeen: now.subtract(const Duration(minutes: 7)),
    )));
    expect(find.text('Last seen 7 minutes ago'), findsOneWidget);

    await t.pumpWidget(_host(_user(
      status: 'offline',
      lastSeen: now.subtract(const Duration(seconds: 10)),
    )));
    await t.pumpAndSettle();
    expect(find.text('Last seen just now'), findsOneWidget);

    await t.pumpWidget(_host(_user(
      status: 'offline',
      lastSeen: now.subtract(const Duration(days: 1)),
    )));
    await t.pumpAndSettle();
    expect(find.textContaining('Last seen yesterday at'), findsOneWidget);
  });

  testWidgets('hidden lastSeen shows nothing', (t) async {
    await t.pumpWidget(_host(_user(status: 'offline')));
    expect(find.textContaining('Last seen'), findsNothing);
    expect(find.text('Online'), findsNothing);
  });

  for (final classic in [false, true]) {
    testWidgets(
        'narrow ${classic ? 'classic' : 'liquid'} header falls back to the '
        'compact wording instead of an ellipsis', (t) async {
      t.view.physicalSize = const Size(300, 600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final user = _user(
        status: 'offline',
        lastSeen: DateTime(2020, 10, 3, 14, 32),
      );
      await t.pumpWidget(ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: debugRoomHeader(
              room: _room,
              api: ChatApi(ConvexBackend.instance),
              caps: const RoomCapabilities(
                canCall: false,
                canLeave: true,
                canDelete: false,
                hasDescription: false,
                hasMembers: true,
                hasPeerHandle: false,
                canEditSettings: false,
                canOpenPeerProfile: false,
                canReceiveForwards: true,
                canSaveMessages: true,
                canMute: true,
              ),
              dmUser: user,
              classic: classic,
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.textContaining('Seen '), findsOneWidget);
      expect(find.textContaining('Last seen'), findsNothing);
    });
  }
}
