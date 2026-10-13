// The room's open-games strip, frosted, stacked over the pinned strip the way
// the floating chat style draws them. Not a test — run by path:
//
//   flutter test test/design_preview/games_banner_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/chat_games/active_games_banner.dart';
import 'package:monkeyhub/data/matches_store.dart';
import 'package:monkeyhub/models/chat_match.dart';
import 'package:monkeyhub/models/chat_message.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/models/room_pin.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/widgets/pinned_banner.dart';

import 'preview_kit.dart';

ChatMatch _game(String room, String id, String game, String? state, int turn) =>
    ChatMatch(
      id: id,
      roomId: room,
      messageId: 'msg-$id',
      game: game,
      mode: MatchMode.async,
      status: MatchStatus.active,
      seats: const [
        MatchSeat(userId: 'me', name: 'Ada'),
        MatchSeat(userId: 'zey', name: 'zeynepoz'),
      ],
      state: state,
      seq: 3,
      turnSeat: turn,
      createdBy: 'me',
      createdAt: DateTime(2026, 10, 13),
    );

final _pin = RoomPin(
  message: ChatMessage(
    id: 'p',
    roomId: 'r',
    senderId: 'zey',
    senderName: 'zeynepoz',
    content: 'image',
    createdAt: DateTime(2026, 10, 13, 11),
    type: MessageType.text,
  ),
  pinnedAt: DateTime(2026, 10, 13, 11),
  pinnedBy: 'zey',
);

void main() {
  setUpAll(loadPreviewFonts);

  for (final (id, theme) in [
    ('dark', BasicTheme.midnight()),
    ('light', BasicTheme.daylight()),
  ]) {
    testWidgets('games strip $id', (tester) async {
      final store = MatchesStore.instance;
      store.note(_game('mine', 'a', 'tictactoe', 'x.o.x..o./0', 0));
      store.note(_game('theirs', 'b', 'connectfour', null, 1));
      store.note(_game('many', 'c', 'tictactoe', 'x.o.x..o./0', 0));
      store.note(_game('many', 'd', 'chess', null, 1));
      Widget block(String room) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ActiveGamesBanner(roomId: room, userId: 'me', glass: true),
          PinnedMessageBanner(
            pins: [_pin],
            activeIndex: 0,
            onTap: () {},
            onOpenList: () {},
            glass: true,
          ),
          const SizedBox(height: 28),
        ],
      );
      await snap(
        tester,
        previewApp(
          theme,
          Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.background,
                        theme.accent.withValues(alpha: 0.5),
                        theme.background,
                      ],
                    ),
                  ),
                ),
              ),
              ListView(
                padding: const EdgeInsets.only(top: 70),
                children: [block('mine'), block('theirs'), block('many')],
              ),
            ],
          ),
        ),
        '$kPreviewDir/games_strip_$id.png',
        size: const Size(393, 520),
      );
    });
  }
}
