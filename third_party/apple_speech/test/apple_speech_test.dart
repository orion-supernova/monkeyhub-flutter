import 'package:apple_speech/apple_speech.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(AppleSpeech.channel, null));

  test('no implementation: queries report unavailable, actions throw', () async {
    expect(await AppleSpeech.isAvailable(), isFalse);
    expect(await AppleSpeech.supportedLocales(), isEmpty);
    expect(await AppleSpeech.installedLocales(), isEmpty);
    expect(await AppleSpeech.bestLocale(['tr']), isNull);
    expect(await AppleSpeech.ensurePermission(), isFalse);
    await AppleSpeech.cancel();
    await expectLater(
      AppleSpeech.transcribe('/x.m4a', 'tr-TR'),
      throwsA(isA<AppleSpeechException>()
          .having((e) => e.error, 'error', AppleSpeechError.unavailable)),
    );
    await expectLater(
      AppleSpeech.ensureAssets('tr-TR'),
      throwsA(isA<AppleSpeechException>()
          .having((e) => e.error, 'error', AppleSpeechError.unavailable)),
    );
  });

  test('transcribe parses the result and relays progress', () async {
    final seen = <double>[];
    messenger.setMockMethodCallHandler(AppleSpeech.channel, (call) async {
      expect(call.method, 'transcribe');
      final id = (call.arguments as Map)['id'] as int;
      await messenger.handlePlatformMessage(
        'monkeyhub/apple_speech',
        const StandardMethodCodec().encodeMethodCall(
            MethodCall('progress', {'id': id, 'fraction': 0.5})),
        (_) {},
      );
      return {
        'text': 'Akşam Moda',
        'locale': 'tr-TR',
        'engine': 'dictation',
        'confidence': 0.9,
        'words': [
          {'text': 'Akşam', 'startMs': 0, 'endMs': 600, 'confidence': 0.6},
          {'text': ' Moda', 'startMs': 600, 'endMs': 990},
        ],
      };
    });
    final r = await AppleSpeech.transcribe('/x.m4a', 'tr', onProgress: seen.add);
    expect(r.text, 'Akşam Moda');
    expect(r.words.map((w) => w.text).join(), r.text);
    expect(r.words[1].startMs, 600);
    expect(r.words[1].confidence, isNull);
    expect(r.engine, 'dictation');
    expect(r.locale, 'tr-TR');
    expect(seen, [0.5]);
  });

  test('platform errors map to AppleSpeechError', () async {
    messenger.setMockMethodCallHandler(AppleSpeech.channel, (call) async {
      throw PlatformException(code: 'unsupportedLocale', message: 'ka');
    });
    await expectLater(
      AppleSpeech.ensureAssets('ka'),
      throwsA(isA<AppleSpeechException>()
          .having((e) => e.error, 'error', AppleSpeechError.unsupportedLocale)
          .having((e) => e.message, 'message', 'ka')),
    );
    messenger.setMockMethodCallHandler(AppleSpeech.channel, (call) async {
      throw PlatformException(code: 'somethingNew');
    });
    await expectLater(
      AppleSpeech.transcribe('/x', 'tr'),
      throwsA(isA<AppleSpeechException>()
          .having((e) => e.error, 'error', AppleSpeechError.failed)),
    );
  });
}
