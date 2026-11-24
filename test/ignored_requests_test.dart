import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/backend/chat_api.dart';
import 'package:monkeyhub/backend/convex_client.dart';
import 'package:monkeyhub/data/chat_repository.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/chat_room.dart';
import 'package:monkeyhub/models/chat_user.dart';
import 'package:monkeyhub/models/friend_request.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/request_cards.dart';

class _FakeSub extends Fake implements Subscription {
  @override
  void cancel() {}
}

class _FakeCv extends Fake implements ConvexBackend {
  final Map<String, void Function(dynamic)> sinks = {};
  @override
  Future<Subscription> subscribe(
    String name,
    Map<String, dynamic> args, {
    required void Function(dynamic) onData,
    void Function(Object error)? onError,
  }) async {
    sinks[name] = onData;
    return _FakeSub();
  }

  @override
  bool get isConnected => true;
  @override
  Stream<bool> get connectionState => const Stream<bool>.empty();
}

class _Api extends Fake implements ChatApi {
  final calls = <(String, bool)>[];
  bool fail = false;

  @override
  Future<void> setDirectRequestIgnored({
    required String userId,
    required String requesterId,
    required bool ignored,
  }) async {
    calls.add((requesterId, ignored));
    if (fail) throw StateError('offline');
  }

  @override
  Future<List<ChatRoom>> listUserRooms(String u) async => throw StateError('offline');
  @override
  Future<List<ChatUser>> listFriends(String u) async => throw StateError('offline');
  @override
  Future<List<FriendRequest>> listIncomingDirectRequests(String u) async =>
      throw StateError('offline');
  @override
  Future<List<FriendRequest>> listOutgoingDirectRequests(String u) async =>
      throw StateError('offline');
}

Map<String, dynamic> _row(String id, {bool ignored = false, String message = ''}) => {
      '_id': 'req_$id',
      'createdAt': DateTime.now().subtract(const Duration(hours: 3)).millisecondsSinceEpoch,
      'roomType': 'Regular Room',
      'initialMessage': message,
      'messageCount': message.isEmpty ? 0 : 1,
      'ignored': ignored,
      'user': {'_id': id, 'username': id, 'name': id[0].toUpperCase() + id.substring(1)},
    };

Future<(ChatRepository, _Api, _FakeCv)> _attached(WidgetTester tester) async {
  final cv = _FakeCv();
  final api = _Api();
  final repo = ChatRepository(api: api, cv: cv);
  await tester.runAsync(() => repo.attach('me'));
  return (repo, api, cv);
}

void main() {
  setUpAll(() async {
    if (Platform.environment['SHOT_DIR'] == null) return;
    // Real glyphs instead of the test font's blocks, so the PNG can be read.
    const dir = '/System/Library/Fonts/Supplemental';
    for (final family in ['CupertinoSystemText', 'CupertinoSystemDisplay', 'Roboto']) {
      final l = FontLoader(family);
      for (final f in ['Arial.ttf', 'Arial Bold.ttf']) {
        l.addFont(Future.value(ByteData.sublistView(File('$dir/$f').readAsBytesSync())));
      }
      await l.load();
    }
  });

  testWidgets('ignored requests leave the inbox list but stay findable', (tester) async {
    final (repo, _, cv) = await _attached(tester);
    cv.sinks['friends:listIncomingDirectRequests']!([
      _row('ana'),
      _row('bo', ignored: true),
    ]);
    expect(repo.incomingRequests.map((r) => r.user.id), ['ana']);
    expect(repo.ignoredRequests.map((r) => r.user.id), ['bo']);
    expect(repo.incomingRequestFrom('bo')?.ignored, isTrue);
  });

  testWidgets('ignoring moves the card at once and a failure puts it back', (tester) async {
    final (repo, api, cv) = await _attached(tester);
    cv.sinks['friends:listIncomingDirectRequests']!([_row('ana'), _row('bo')]);

    await repo.setDirectRequestIgnored('ana', true);
    expect(api.calls, [('ana', true)]);
    expect(repo.incomingRequests.map((r) => r.user.id), ['bo']);
    expect(repo.ignoredRequests.single.ignored, isTrue);

    await repo.setDirectRequestIgnored('ana', false);
    expect(repo.incomingRequests.map((r) => r.user.id).toSet(), {'ana', 'bo'});
    expect(repo.ignoredRequests, isEmpty);

    api.fail = true;
    await expectLater(repo.setDirectRequestIgnored('bo', true), throwsStateError);
    expect(repo.incomingRequests.map((r) => r.user.id).toSet(), {'ana', 'bo'});
    expect(repo.ignoredRequests, isEmpty);
  });

  testWidgets('the card offers Ignore in the inbox and Move back / Delete once ignored', (tester) async {
    final (repo, api, cv) = await _attached(tester);
    cv.sinks['friends:listIncomingDirectRequests']!([
      _row('ana', message: 'Hey, we met at the climbing gym!'),
      _row('bo', ignored: true),
    ]);

    final shotDir = Platform.environment['SHOT_DIR'];
    final shot = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(390, 640));
    await tester.pumpWidget(
      ThemeScope(
        controller: ThemeController(BasicTheme.midnight()),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RepaintBoundary(
              key: shot,
              child: ListenableBuilder(
                listenable: repo,
                builder: (context, _) => ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    for (final r in [...repo.incomingRequests, ...repo.ignoredRequests]) ...[
                      IncomingRequestCard(
                        key: ValueKey('${r.ignored}_${r.user.id}'),
                        req: r,
                        repo: repo,
                        api: api,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ignore'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(find.text('Move back'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    if (shotDir != null) {
      await tester.runAsync(() async {
        final b = shot.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final img = await b.toImage(pixelRatio: 2);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(shotDir).createSync(recursive: true);
        File('$shotDir/ignored_requests.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    await tester.tap(find.text('Ignore'));
    await tester.pump();
    expect(api.calls, [('ana', true)]);
    expect(repo.ignoredRequests.map((r) => r.user.id).toSet(), {'ana', 'bo'});
    expect(find.text('Ignore'), findsNothing);
    // Let the toast's timer run out.
    await tester.pump(const Duration(seconds: 10));
    await tester.binding.setSurfaceSize(null);
  });
}
