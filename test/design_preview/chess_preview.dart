// Throwaway: the chess board and its piece set on Midnight and Daylight:
// playable from both sides, in check, mid-drag, with the promotion picker
// open, mid-slide, as thumbnails, and every piece large. See preview_kit.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/turn_games/board/chess_board.dart';
import 'package:monkeyhub/turn_games/board/chess_pieces.dart';
import 'package:monkeyhub/turn_games/board/turn_board.dart';
import 'package:monkeyhub/turn_games/chess.dart';

import 'preview_kit.dart';

/// [line] (UCI, spaces) played from the opening: the encoded state and the
/// last move.
(String, String?) _play(String line) {
  var s = chessRules.initial(2);
  String? last;
  for (final m in line.split(' ').where((m) => m.isNotEmpty)) {
    s = chessRules.apply(s, chessRules.decodeMove(m));
    last = m;
  }
  return (chessRules.encode(s), last);
}

void main() {
  setUpAll(loadPreviewFonts);

  final italian = _play('e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 d2d3 f8c5 e1g1 d7d6');
  final check = _play('e2e4 e7e5 g1f3 d7d6 f1c4 c8g4 b1c3 g7g6 f3e5 g4d1 c4f7');
  final mate = _play('f2f3 e7e5 g2g4 d8h4');
  const promo = '4k3/1P6/8/8/8/8/6K1/8 w - - 0 1|';

  Widget cell(String label, Widget child) => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label, style: const TextStyle(fontSize: 11)), const SizedBox(height: 6), child],
    ),
  );

  Widget board(String state, {String? last, int? seat, bool enabled = false, double width = 300, Key? key}) =>
      SizedBox(
        width: width,
        child: TurnBoard(
          key: key,
          gameId: 'chess',
          state: state,
          lastMove: last,
          mySeat: seat,
          enabled: enabled,
          onMove: (_) {},
        ),
      );

  for (final id in ['basic', 'basic_daylight']) {
    testWidgets('chess boards $id', (tester) async {
      final theme = ThemeController.byId(id);
      final promoKey = GlobalKey();
      final dragKey = GlobalKey();
      final selectKey = GlobalKey();
      await snap(
        tester,
        previewApp(
          theme,
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                children: [
                  cell('white to move, a piece selected', board(italian.$1, last: italian.$2, seat: 0, enabled: true, key: selectKey)),
                  cell('black at the bottom, in check', board(check.$1, last: check.$2, seat: 1, enabled: true)),
                  cell('mid-drag', board(italian.$1, last: italian.$2, seat: 0, enabled: true, key: dragKey)),
                  cell('promotion picker', board(promo, seat: 0, enabled: true, key: promoKey)),
                  cell('checkmate, spectator', board(mate.$1, last: mate.$2)),
                  cell(
                    'thumbs (12 pt squares)',
                    Row(
                      children: [
                        for (final s in [italian.$1, check.$1, mate.$1])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(width: 96, child: TurnBoard(gameId: 'chess', state: s, thumbnail: true)),
                          ),
                      ],
                    ),
                  ),
                  cell('pieces at 40 pt and 24 pt', _PieceSheet(dark: id == 'basic')),
                ],
              ),
            ),
          ),
        ),
        'chess_$id.png',
        size: const Size(1000, 1180),
        dpr: 2,
        topInset: 0,
        bottomInset: 0,
        act: () async {
          Offset sq(GlobalKey k, String name, {bool flipped = false}) {
            final box = k.currentContext!.findRenderObject()! as RenderBox;
            final g = ChessGeometry(box.size, flipped: flipped);
            final i = (8 - int.parse(name[1])) * 8 + name.codeUnitAt(0) - 0x61;
            return box.localToGlobal(g.center(i));
          }

          await tester.tapAt(sq(selectKey, 'f3'));
          await tester.pump();
          await tester.tapAt(sq(promoKey, 'b7'));
          await tester.pump();
          await tester.tapAt(sq(promoKey, 'b8'));
          await tester.pump(const Duration(milliseconds: 300));
          final g = await tester.startGesture(sq(dragKey, 'c4'));
          await tester.pump();
          await g.moveTo(sq(dragKey, 'e5') + const Offset(10, 6));
          await tester.pump();
          await g.moveTo(sq(dragKey, 'f6') + const Offset(14, 12));
          await tester.pump();
        },
      );
    });

    testWidgets('chess in flight $id', (tester) async {
      final theme = ThemeController.byId(id);
      final before = _play('e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 f3g5 d7d5 e4d5');
      final after = _play('e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 f3g5 d7d5 e4d5 f6d5');
      final flag = ValueNotifier(false);
      await snap(
        tester,
        previewApp(
          theme,
          ValueListenableBuilder<bool>(
            valueListenable: flag,
            builder: (context, done, _) => Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: cell(
                  'Nxd5 mid-slide, the pawn fading',
                  board(done ? after.$1 : before.$1, last: done ? after.$2 : before.$2, seat: 0),
                ),
              ),
            ),
          ),
        ),
        'chess_flight_$id.png',
        size: const Size(340, 360),
        dpr: 2,
        topInset: 0,
        bottomInset: 0,
        settle: const Duration(milliseconds: 100),
        act: () async {
          flag.value = true;
          await tester.pump();
        },
      );
    });
  }
}

/// Every piece of both sides on a light and a dark square, at 40 and 24 pt.
class _PieceSheet extends StatelessWidget {
  const _PieceSheet({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final size in [40.0, 24.0])
        for (final side in [0, 1])
          Row(
            children: [
              for (var t = chessPawn; t <= chessKing; t++)
                for (final darkSquare in [false, true])
                  SizedBox.square(
                    dimension: size,
                    child: CustomPaint(painter: _One(t, side, darkSquare, dark)),
                  ),
            ],
          ),
    ],
  );
}

class _One extends CustomPainter {
  _One(this.type, this.side, this.darkSquare, this.dark);

  final int type;
  final int side;
  final bool darkSquare;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final theme = dark ? ThemeController.byId('basic') : ThemeController.byId('basic_daylight');
    final ink = theme.ink;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = Color.alphaBlend(
          ink.withValues(alpha: darkSquare ? (dark ? 0.15 : 0.13) : (dark ? 0.05 : 0.03)),
          theme.surfaceRaised,
        ),
    );
    canvas.save();
    canvas.translate(size.width * 0.04, size.height * 0.05);
    canvas.scale(size.width * 0.92);
    ChessPieceStyle(darkTheme: dark).paint(canvas, type, side);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_One old) => false;
}
