import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/companions/brain_download.dart';
import 'package:monkeyhub/transcripts/speech_engine.dart';
import 'package:monkeyhub/transcripts/transcript.dart';
import 'package:monkeyhub/transcripts/transcript_model.dart';
import 'package:monkeyhub/transcripts/voice_transcriber.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:monkeyhub/widgets/voice_transcript.dart';

import 'preview_kit.dart';

/// Voice bubbles with their transcripts in every state the slab has: read
/// along mid-play, the cellular prompt, the model downloading, and folded.
Duration _ms(int v) => Duration(milliseconds: v);

final _turkish = Transcript(
  text: 'Akşam Moda\'da buluşalım mı? Sahildeki kafe sekizde kapanıyor, o yüzden yedi gibi orada olalım.',
  language: 'tr',
  words: [
    for (final (i, w) in 'Akşam Moda\'da buluşalım mı? Sahildeki kafe sekizde kapanıyor, o yüzden yedi gibi orada olalım.'
        .split(' ')
        .indexed)
      TranscriptWord(text: i == 0 ? w : ' $w', start: _ms(i * 420), end: _ms(i * 420 + 380)),
  ],
);

const _swedish = Transcript(
  text: 'Jag är framme om tio minuter, ta det lugnt.',
  language: 'sv',
);

const _builtIn = Transcript(
  text: 'Can you grab bread on the way? The bakery closes at seven.',
  language: 'en',
  source: TranscriptSource.builtIn,
);

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.theme,
    required this.id,
    required this.isMine,
    this.position = Duration.zero,
    this.following = false,
  });

  final AppTheme theme;
  final String id;
  final bool isMine;
  final Duration position;
  final bool following;

  @override
  Widget build(BuildContext context) {
    final ink = isMine ? theme.accentInk : theme.ink;
    final handle = VoiceTranscriber.instance.handleFor(id);
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isMine ? ink.withValues(alpha: 0.2) : theme.accent,
            shape: BoxShape.circle,
          ),
          child: Icon(following ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 19, color: isMine ? ink : theme.accentInk),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 20,
                child: Row(
                  children: [
                    for (var i = 0; i < 24; i++)
                      Container(
                        width: 2.4,
                        height: 4 + (i * 7 % 13).toDouble(),
                        margin: const EdgeInsets.only(right: 2.5),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: i < (following ? 10 : 0) ? 1 : 0.32),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(following ? '0:04 / 0:07' : '0:07',
                  style: theme.body.copyWith(fontSize: 13, color: ink.withValues(alpha: 0.8))),
            ],
          ),
        ),
        const SizedBox(width: 2),
        TranscriptButton(handle: handle, isMine: isMine, onTap: () {}),
      ],
    );
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
          decoration: BoxDecoration(
            color: isMine ? theme.accent : theme.surfaceRaised,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              row,
              TranscriptSlab(
                handle: handle,
                isMine: isMine,
                position: position,
                following: following,
                onSeek: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Samples extends StatelessWidget {
  const _Samples(this.theme);
  final AppTheme theme;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Bubble(theme: theme, id: 'tr', isMine: false, position: _ms(2600), following: true),
                const SizedBox(height: 14),
                _Bubble(theme: theme, id: 'sv', isMine: true),
                const SizedBox(height: 14),
                _Bubble(theme: theme, id: 'apple', isMine: false),
                const SizedBox(height: 14),
                _Bubble(theme: theme, id: 'offer', isMine: false),
                const SizedBox(height: 14),
                _Bubble(theme: theme, id: 'consent', isMine: false),
                const SizedBox(height: 14),
                _Bubble(theme: theme, id: 'dl', isMine: true),
                const SizedBox(height: 14),
                _Bubble(theme: theme, id: 'folded', isMine: false),
              ],
            ),
          ),
        ),
      );
}

void main() {
  setUpAll(loadPreviewFonts);
  for (final theme in [BasicTheme.midnight(), BasicTheme.daylight()]) {
    testWidgets('${theme.id} voice transcripts', (tester) async {
      final tmp = await tester.runAsync(() => Directory.systemTemp.createTemp('vt_preview'));
      TranscriptStore.instance.debugDir = tmp;
      addTearDown(() => TranscriptStore.instance.debugDir = null);
      await tester.runAsync(() => File('${tmp!.path}/transcripts.json').writeAsString(jsonEncode({
            'tr': _turkish.toJson(),
            'sv': _swedish.toJson(),
            'apple': _builtIn.toJson(),
            'offer': _builtIn.toJson(),
          })));

      var cellular = true;
      final gate = Completer<void>();
      Stream<DownloadProgress> download(DownloadTarget t) async* {
        yield DownloadProgress(received: (t.sizeBytes * 0.37).round(), total: t.sizeBytes);
        await gate.future;
      }

      final t = VoiceTranscriber.instance = VoiceTranscriber.forTest(
        _Engine(),
        download: download,
        onCellular: () => cellular,
      );
      Future<String> audio() async => '/x.m4a';
      await tester.runAsync(() async {
        await t.toggle('tr', audio);
        await t.toggle('sv', audio);
        await t.toggle('apple', audio);
        await t.toggle('offer', audio);
        t.setOffering('offer', true);
        await t.toggle('consent', audio);
        cellular = false;
        unawaited(t.toggle('dl', audio));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      await snap(
        tester,
        previewApp(theme, _Samples(theme)),
        'voice_transcript_${theme.id}.png',
        size: const Size(393, 1700),
      );
      expect(tester.takeException(), isNull);
      t.cancelDownload();
      await tester.runAsync(() => tmp!.delete(recursive: true));
    });
  }
}

class _Engine implements SpeechEngine {
  @override
  bool get supported => true;
  @override
  Future<Transcript> transcribe({
    required String audioPath,
    required String modelPath,
    void Function(double fraction)? onProgress,
  }) async =>
      const Transcript(text: '');
  @override
  Future<void> release() async {}

  @override
  Future<void> prewarm() async {}
}
