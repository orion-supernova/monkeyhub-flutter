import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/data/ui_selection_store.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/media/image_raster.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/enums.dart';
import 'package:monkeyhub/screens/create_room_sheet.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/layout.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/adaptive_sheet.dart';
import 'package:monkeyhub/widgets/chat_list_row.dart';
import 'package:monkeyhub/widgets/message_life_picker.dart';

/// The redesigned new-room sheet: a live preview card over four sections.
/// What this pins is behaviour a person would notice: the card's subtitle
/// follows every choice, Secret reveals the shared timer picker, people picked
/// are invited, and the create call carries exactly what was chosen.
class _Created {
  _Created(this.args);
  final Map<String, Object?> args;
}

class _FakeRepo extends Fake implements ChatRepository {
  final List<_Created> created = [];
  final List<String> invited = [];

  @override
  String? get userId => 'me';

  @override
  List<ChatUser> get friends => [
        ChatUser(id: 'u1', username: 'zeynep', name: 'Zeynep Kaya'),
        ChatUser(id: 'u2', username: 'alp', name: 'Alp Demir'),
        ChatUser(id: 'u3', username: 'burak', name: 'Burak Aydin'),
      ];

  @override
  Future<String> createRoom({
    required String name,
    required bool isPrivate,
    String? description,
    String? password,
    RoomType type = RoomType.regular,
    Duration? messageLifetime,
    String? messageClock,
  }) async {
    created.add(_Created({
      'name': name,
      'isPrivate': isPrivate,
      'description': description,
      'password': password,
      'type': type,
      'messageLifetime': messageLifetime,
      'messageClock': messageClock,
    }));
    return 'room-1';
  }

  @override
  Future<void> inviteToRoom({
    required String roomId,
    required String inviteeId,
  }) async {
    invited.add(inviteeId);
  }
}

class _FakeApi extends Fake implements ChatApi {
  int uploadUrls = 0;

  /// The upload itself needs a network; counting the request is enough to show
  /// the picture was sent on, and failing here proves a failed upload cannot
  /// hurt the room.
  @override
  Future<String> generateUploadUrl() async {
    uploadUrls++;
    throw StateError('offline');
  }
}

/// A real 8x8 PNG, so Image.memory has something to decode.
Future<Uint8List> _png() async {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = const Color(0xFFCC3355));
  final img = await rec.endRecording().toImage(8, 8);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  late _FakeRepo repo;
  late _FakeApi api;
  CroppedImage? nextPick;

  Widget host() => ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: LayoutScope(
          // Wide enough to take the split-shell path, so a successful create
          // selects the room instead of pushing a RoomScreen this fake could
          // not build.
          windowClass: WindowClass.expanded,
          width: 1400,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showAdaptiveSheet(
                      context,
                      useSafeArea: true,
                      builder: (_) =>
                          CreateRoomSheet(
                        repo: repo,
                        api: api,
                        pickPicture: (_) async => nextPick,
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    repo = _FakeRepo();
    api = _FakeApi();
    nextPick = null;
  });

  testWidgets('starts as an invite-only regular room with only you',
      (tester) async {
    await open(tester);
    expect(find.text('Untitled room'), findsOneWidget);
    expect(find.text('Invite only · just you · regular'), findsOneWidget);
    expect(find.text('only you so far'), findsOneWidget);
    expect(find.byType(MessageLifePicker), findsNothing);
  });

  testWidgets('Secret reveals the timer picker and the subtitle follows it',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Secret'));
    await tester.pumpAndSettle();

    expect(find.byType(MessageLifePicker), findsOneWidget);
    expect(find.text('SECRET'), findsOneWidget);
    expect(
      find.text('Invite only · just you · secret · 30s after sent'),
      findsOneWidget,
    );

    await tester.tap(find.text('After seen'));
    await tester.pumpAndSettle();
    expect(
      find.text('Invite only · just you · secret · 10s after seen'),
      findsOneWidget,
    );

    await tester.tap(find.text('Regular'));
    await tester.pumpAndSettle();
    expect(find.byType(MessageLifePicker), findsNothing);
    expect(find.text('SECRET'), findsNothing);
  });

  testWidgets('picking people counts them as "you + n" and un-picking undoes it',
      (tester) async {
    await open(tester);
    await tester.tap(find.text('Zeynep'));
    await tester.pump();
    await tester.tap(find.text('Alp'));
    await tester.pumpAndSettle();
    expect(find.text('you + 2'), findsWidgets);
    expect(find.text('Invite only · you + 2 · regular'), findsOneWidget);

    await tester.tap(find.text('Alp'));
    await tester.pumpAndSettle();
    expect(find.text('Invite only · you + 1 · regular'), findsOneWidget);
  });

  testWidgets('Findable and a password show in the subtitle', (tester) async {
    await open(tester);
    await tester.tap(find.text('Findable'));
    await tester.pumpAndSettle();
    expect(find.text('Findable · just you · regular'), findsOneWidget);
    await tester.tap(find.text('Lock with a password'));
    await tester.pumpAndSettle();
    expect(find.text('Findable · locked · just you · regular'), findsOneWidget);
  });

  testWidgets('a name is required', (tester) async {
    await open(tester);
    await tester.tap(find.text('Open the room'));
    await tester.pumpAndSettle();
    expect(find.text('Name is required'), findsOneWidget);
    expect(repo.created, isEmpty);
  });

  testWidgets('create sends what was chosen and invites the people picked',
      (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'Late night crew');
    await tester.pump();
    await tester.tap(find.text('Zeynep'));
    await tester.pump();
    await tester.tap(find.text('Burak'));
    await tester.pump();
    await tester.tap(find.text('Secret'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('After seen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Findable'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open the room'));
    // Create, the invites, then the card's flight.
    await tester.pumpAndSettle();

    expect(repo.created, hasLength(1));
    final a = repo.created.single.args;
    expect(a['name'], 'Late night crew');
    expect(a['isPrivate'], false);
    expect(a['type'], RoomType.secret);
    expect(a['messageClock'], 'seen');
    expect(a['messageLifetime'], const Duration(seconds: 10));
    expect(a['password'], isNull);
    expect(repo.invited, unorderedEquals(['u1', 'u3']));
    expect(UiSelectionStore.instance.roomId, 'room-1');
  });

  testWidgets('a regular room sends no clock and no lifetime', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, 'Plain');
    await tester.tap(find.text('Open the room'));
    await tester.pumpAndSettle();
    final a = repo.created.single.args;
    expect(a['type'], RoomType.regular);
    expect(a['messageClock'], isNull);
    expect(a['messageLifetime'], isNull);
    expect(a['isPrivate'], true);
  });

  testWidgets('the description hides until asked for', (tester) async {
    await open(tester);
    expect(find.text('One line about the room'), findsNothing);
    await tester.tap(find.text('+ Add a description'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(3));
    await tester.enterText(find.byType(TextField).at(1), 'Mind the gap');
    await tester.enterText(find.byType(TextField).first, 'Tube');
    await tester.tap(find.text('Open the room'));
    await tester.pumpAndSettle();
    expect(repo.created.single.args['description'], 'Mind the gap');
  });

  group('room picture', () {
    Future<CroppedImage> pick(WidgetTester tester) async {
      final bytes = (await tester.runAsync(_png))!;
      return CroppedImage(
          bytes: bytes, contentType: 'image/png', width: 8, height: 8);
    }

    testWidgets('wears the default lettered face that follows the name',
        (tester) async {
      await open(tester);
      expect(find.byType(MonogramAvatar), findsOneWidget);
      expect(find.text('#'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'tube club');
      await tester.pump();
      expect(find.text('T'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('tapping the avatar picks a photo; the x puts it back',
        (tester) async {
      await open(tester);
      nextPick = await pick(tester);
      await tester.tap(find.byType(MonogramAvatar));
      await tester.pumpAndSettle();
      expect(find.byType(MonogramAvatar), findsNothing);
      expect(find.byType(Image), findsOneWidget);

      // The card's own x (10px); the sheet's close glyph is bigger.
      await tester.tap(find.byWidgetPredicate((w) =>
          w is Icon && w.icon == CupertinoIcons.xmark && w.size == 10));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(find.byType(MonogramAvatar), findsOneWidget);
    });

    testWidgets('a cancelled pick changes nothing', (tester) async {
      await open(tester);
      await tester.tap(find.byType(MonogramAvatar));
      await tester.pumpAndSettle();
      expect(find.byType(MonogramAvatar), findsOneWidget);
    });

    testWidgets('long-press drops the picked photo', (tester) async {
      await open(tester);
      nextPick = await pick(tester);
      await tester.tap(find.byType(MonogramAvatar));
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('create uploads the picked photo; a failure keeps the room',
        (tester) async {
      await open(tester);
      nextPick = await pick(tester);
      await tester.tap(find.byType(MonogramAvatar));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Pics');
      await tester.tap(find.text('Open the room'));
      await tester.pumpAndSettle();
      expect(repo.created, hasLength(1));
      expect(api.uploadUrls, 1);
      expect(UiSelectionStore.instance.roomId, 'room-1');
    });

    testWidgets('no picture means no upload', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(TextField).first, 'Plain');
      await tester.tap(find.text('Open the room'));
      await tester.pumpAndSettle();
      expect(api.uploadUrls, 0);
    });
  });
}
