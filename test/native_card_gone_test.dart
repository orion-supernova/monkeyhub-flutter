import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/calls/native_call_handler.dart';

/// A dismissal ack turns off the server's `taken` push for this device — the
/// last thing that can stop a ringer — so it may only be sent once the card is
/// really gone. On 2026-10-07 a cancelled call kept an iPhone and a Galaxy
/// ringing: both acked on the strength of having asked for the end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<dynamic> cards;
  Object? listError;

  setUpAll(() {
    NativeCallHandler.nativeCallUiOverride = true;
    NativeCallHandler.activeCallsFn = () async {
      if (listError != null) throw listError!;
      return cards;
    };
  });

  tearDownAll(() => NativeCallHandler.nativeCallUiOverride = null);

  setUp(() {
    cards = [];
    listError = null;
  });

  Map<String, dynamic> card(Map<String, dynamic> extra) =>
      {'id': 'uuid', 'extra': extra};

  test('gone when the plugin lists no card for the call', () async {
    cards = [card({'callId': 'other'})];
    expect(await NativeCallHandler.instance.cardGone('c1'), isTrue);
  });

  test('not gone while the 1:1 card is still listed', () async {
    cards = [card({'callId': 'c1'})];
    expect(await NativeCallHandler.instance.cardGone('c1'), isFalse);
  });

  test('not gone while the group card is still listed', () async {
    cards = [card({'groupCallId': 'g1'})];
    expect(await NativeCallHandler.instance.cardGone('g1'), isFalse);
  });

  test('a live card with no identity is not gone', () async {
    // iOS lists a card the plugin holds no entry for (the fallback ringer)
    // as a bare id. It may be this call's: the 2026-10-08 iPhone that kept
    // ringing after a cancel acked on exactly this.
    cards = [
      {'id': 'uuid'},
    ];
    expect(await NativeCallHandler.instance.cardGone('c1'), isFalse);
  });

  test('cannot tell is not gone — the push stays on', () async {
    listError = Exception('plugin channel wedged');
    expect(await NativeCallHandler.instance.cardGone('c1'), isFalse);
  });

  /// iOS asks AppDelegate instead (`cardLive`): it reads the plugin's own
  /// record by the cards' real UUIDs and counts an invite push still being
  /// reported, the two things the observer-backed list cannot see. On
  /// 2026-10-11 every one of a run of cancelled calls was acked by a
  /// zeynepoz iPhone that kept ringing.
  group('iOS: AppDelegate decides', () {
    late List<String> asked;
    late Object? Function(String method, String callId) answer;
    late Future<Object?> Function(String, String) savedVoip;

    setUp(() {
      asked = [];
      answer = (_, _) => null;
      savedVoip = NativeCallHandler.iosVoipFn;
      NativeCallHandler.iosNativeOverride = true;
      NativeCallHandler.iosVoipFn = (method, callId) async {
        asked.add('$method:$callId');
        final a = answer(method, callId);
        if (a is Exception) throw a;
        return a;
      };
    });

    tearDown(() {
      NativeCallHandler.iosNativeOverride = null;
      NativeCallHandler.iosVoipFn = savedVoip;
    });

    test('a card native says is up is not gone, whatever the list says',
        () async {
      answer = (_, _) => true;
      cards = [];
      expect(await NativeCallHandler.instance.cardGone('c1'), isFalse);
      expect(asked, ['cardLive:c1']);
    });

    test('native says gone: gone, even past a lagging bare list entry',
        () async {
      answer = (_, _) => false;
      cards = [
        {'id': 'uuid'},
      ];
      expect(await NativeCallHandler.instance.cardGone('c1'), isTrue);
    });

    test('an older native side (no bool) falls back to the list', () async {
      answer = (_, _) => null;
      cards = [card({'callId': 'c1'})];
      expect(await NativeCallHandler.instance.cardGone('c1'), isFalse);
      cards = [];
      expect(await NativeCallHandler.instance.cardGone('c1'), isTrue);
    });

    test('a failing cardLive falls back to the list, never to "gone"',
        () async {
      answer = (_, _) => Exception('channel wedged');
      listError = Exception('plugin channel wedged too');
      expect(await NativeCallHandler.instance.cardGone('c1'), isFalse);
    });

    group('endNative', () {
      late List<String> ended;
      late Future<void> Function(String) savedEnd;

      setUp(() {
        ended = [];
        savedEnd = NativeCallHandler.endCallFn;
        NativeCallHandler.endCallFn = (uuid) async => ended.add(uuid);
      });

      tearDown(() => NativeCallHandler.endCallFn = savedEnd);

      test('tells native the call is over BEFORE the plugin end', () async {
        answer = (method, _) {
          // Native ends the ringing card by its real id first; by the time
          // the plugin path looks, only an answered card would be left.
          expect(ended, isEmpty);
          return 1;
        };
        cards = [card({'callId': 'c1'})..['id'] = 'answered-uuid'];
        await NativeCallHandler.instance.endNative('c1');
        expect(asked, ['callOver:c1']);
        expect(ended, ['answered-uuid']);
      });

      test('a failing callOver still runs the plugin end', () async {
        answer = (_, _) => Exception('older native side');
        cards = [card({'callId': 'c1'})..['id'] = 'u1'];
        await NativeCallHandler.instance.endNative('c1');
        expect(ended, ['u1']);
      });

      test('a group dismissal is never a callOver', () async {
        cards = [];
        await NativeCallHandler.instance.endNativeByCallId('g1');
        expect(asked, isEmpty);
      });
    });

    test('the audio release names the call that ended', () async {
      // Natively a release naming another call than the one audio was last
      // applied for is ignored: the settled belt repeats for seconds and
      // must not take a redial's session down.
      await NativeCallHandler.instance.deactivateIosAudioSession(callId: 'c1');
      await NativeCallHandler.instance.deactivateIosAudioSession();
      expect(asked, ['deactivateAudioSession:c1', 'deactivateAudioSession:']);
    });

    test('no audio release while a group call is live', () async {
      final saved = NativeCallHandler.groupCallActiveProbe;
      NativeCallHandler.groupCallActiveProbe = () => true;
      try {
        await NativeCallHandler.instance.deactivateIosAudioSession(callId: 'c1');
        expect(asked, isEmpty);
      } finally {
        NativeCallHandler.groupCallActiveProbe = saved;
      }
    });
  });

  test('markConnected reports a call once, reconnects included', () async {
    final saved = NativeCallHandler.connectCallFn;
    final connected = <String>[];
    NativeCallHandler.connectCallFn = (uuid) async => connected.add(uuid);
    try {
      NativeCallHandler.instance.debugRememberUuid('cc1', 'uuid-cc1');
      for (var i = 0; i < 3; i++) {
        await NativeCallHandler.instance.markConnected('cc1');
      }
      expect(connected, ['uuid-cc1']);
    } finally {
      NativeCallHandler.connectCallFn = saved;
    }
  });

  group('markConnected is once per card, not once per call id', () {
    late List<String> connected;
    late Future<void> Function(String uuid) savedConnect;
    late Future<void> Function(String uuid) savedEnd;

    setUp(() {
      savedConnect = NativeCallHandler.connectCallFn;
      savedEnd = NativeCallHandler.endCallFn;
      connected = [];
      NativeCallHandler.connectCallFn = (uuid) async => connected.add(uuid);
      NativeCallHandler.endCallFn = (_) async {};
    });

    tearDown(() {
      NativeCallHandler.connectCallFn = savedConnect;
      NativeCallHandler.endCallFn = savedEnd;
    });

    test('a group call rung again under the same id gets its own report',
        () async {
      final h = NativeCallHandler.instance;
      h.debugRememberUuid('gc-again', 'card-1');
      await h.markConnected('gc-again');
      // The second ring is a new card: without its own setCallConnected
      // the plugin's 60 s timeout hangs the call up mid-call.
      h.debugRememberUuid('gc-again', 'card-2');
      await h.markConnected('gc-again');
      await h.markConnected('gc-again');
      expect(connected, ['card-1', 'card-2']);
    });

    test('a card ended and raised again under the same native id reports '
        'again', () async {
      final h = NativeCallHandler.instance;
      h.debugRememberUuid('gc-derived', 'derived-uuid');
      await h.markConnected('gc-derived');
      await h.endNativeByCallId('gc-derived');
      h.debugRememberUuid('gc-derived', 'derived-uuid');
      await h.markConnected('gc-derived');
      expect(connected, ['derived-uuid', 'derived-uuid']);
    });
  });

  test('off iOS there is no callOver', () async {
    final saved = NativeCallHandler.iosVoipFn;
    final asked = <String>[];
    NativeCallHandler.iosVoipFn = (method, callId) async {
      asked.add(method);
      return null;
    };
    final savedEnd = NativeCallHandler.endCallFn;
    NativeCallHandler.endCallFn = (_) async {};
    try {
      cards = [];
      await NativeCallHandler.instance.endNative('c1');
      expect(asked, isEmpty);
    } finally {
      NativeCallHandler.iosVoipFn = saved;
      NativeCallHandler.endCallFn = savedEnd;
    }
  });
}
