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
}
