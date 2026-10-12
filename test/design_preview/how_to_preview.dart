// Renders every daily guide's demo at a few loop moments (a contact sheet per
// game), plus the guide sheet itself. Not a test — run by path:
//
//   flutter test test/design_preview/how_to_preview.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/chat_games/play_style.dart';
import 'package:monkeyhub/games/how_to/chat_guides.dart';
import 'package:monkeyhub/games/how_to/daily_guides.dart';
import 'package:monkeyhub/games/how_to/how_to_play.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/models/daily_game.dart';
import 'package:monkeyhub/theme/app_theme.dart';
import 'package:monkeyhub/theme/basic_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preview_kit.dart';

class _Frame extends CustomPainter {
  _Frame(this.demo, this.theme, this.t);
  final HowToDemo demo;
  final AppTheme theme;
  final double t;
  @override
  void paint(Canvas canvas, Size size) =>
      demo.paint(canvas, DemoFrame(theme: theme, size: size, t: t));
  @override
  bool shouldRepaint(_Frame old) => true;
}

const _moments = [0.2, 0.4, 0.6, 0.8];

Widget _sheet(AppTheme theme, HowToPlayGuide guide) => Builder(
  builder: (context) => SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in guide.steps) ...[
          Text(step.text, style: theme.body.copyWith(fontSize: 13)),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final t in _moments)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    height: 150,
                    decoration: BoxDecoration(
                      color: theme.ink.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(painter: _Frame(step.demo, theme, t)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    ),
  ),
);

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (name, theme) in [
    ('light', BasicTheme.daylight()),
    ('dark', BasicTheme.midnight()),
  ]) {
    for (final game in [...DailyGame.values, null]) {
      testWidgets('demos ${game?.wire ?? 'code'} $name', (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await snap(
          tester,
          previewApp(theme, _sheet(theme, dailyGuide(l10n, game))),
          '$kPreviewDir/how_to/${game?.wire ?? 'code'}_$name.png',
          size: const Size(640, 900),
          dpr: 2,
        );
      });
    }
  }

  for (final (name, theme) in [
    ('light', BasicTheme.daylight()),
    ('dark', BasicTheme.midnight()),
  ]) {
    for (final game in const [
      'tictactoe', 'connectfour', 'checkers', 'reversi', 'dots', 'chess',
      'liarsdice', 'imposter', 'race',
    ]) {
      testWidgets('chat $game $name', (tester) async {
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        await snap(
          tester,
          previewApp(
            theme,
            _sheet(
              theme,
              chatGuide(
                l10n,
                game,
                modes: game == 'tictactoe'
                    ? const [PlayStyle.turns, PlayStyle.live]
                    : const [],
                group: true,
                voice: game == 'imposter',
              ),
            ),
          ),
          '$kPreviewDir/how_to/chat_${game}_$name.png',
          size: Size(640, game == 'liarsdice' || game == 'tictactoe' ? 1800 : 1100),
          dpr: 2,
        );
      });
    }
  }

  for (final (name, theme, locale) in [
    ('en', BasicTheme.midnight(), const Locale('en')),
    ('tr', BasicTheme.daylight(), const Locale('tr')),
  ]) {
    testWidgets('sheet $name', (tester) async {
      await snap(
        tester,
        previewApp(
          theme,
          Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showHowToPlay(
                  context,
                  dailyGuide(AppLocalizations.of(context), DailyGame.queens),
                  actionLabel: AppLocalizations.of(context).gameInfoPlay,
                ),
                child: const Text('open'),
              ),
            ),
          ),
          locale: locale,
        ),
        '$kPreviewDir/how_to/sheet_$name.png',
        act: () async {
          await tester.tap(find.text('open'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 600));
          // Into the loop, so a finger and a crown are on the board.
          await tester.pump(const Duration(milliseconds: 1500));
        },
        settle: const Duration(milliseconds: 400),
      );
    });
  }
}
