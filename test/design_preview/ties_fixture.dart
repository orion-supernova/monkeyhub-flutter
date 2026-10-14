// Mock boards for big ties on the leaderboard, shared by the PNG preview
// (leaderboard_ties_preview.dart) and the simulator demo
// (podium_ties_sim.dart). No flutter_test here: the demo runs on a device.
import 'dart:convert';

import 'package:monkeyhub/models/daily_game.dart';

GameResult _r(DailyGame g, String id, String name, int secs) => GameResult(
  game: g,
  solved: true,
  gaveUp: false,
  finished: true,
  durationMs: secs * 1000,
  userId: id,
  name: name,
);

// Ten friends plus you; long names on purpose.
const tiePeople = [
  ('u_e', 'Ece Yıldız'),
  ('u_d', 'Deniz Kaya'),
  ('u_m', 'Mert'),
  ('u_s', 'Selin'),
  ('u_b', 'Bilgekaan Sevim'),
  ('u_z', 'zeynepoz'),
  ('u_j', 'Johnathan Coachella'),
  ('u_a', 'Alperen Subaşı'),
  ('u_i', 'İrem Öztürk'),
];

// Three podiums, one per game:
//   Queens: 2 tied for gold, then 10 tied at bronze (1, 1, 3), then 13th.
//   Tango: 1 gold, then 10 tied at silver, then 12th.
//   Zip: 12 tied for gold, nobody else.
final tieStandings = GameStandings(
  boards: {
    DailyGame.queens: [
      _r(DailyGame.queens, 'u_e', 'Ece Yıldız', 50),
      _r(DailyGame.queens, 'u_m', 'Mert', 50),
      for (final (id, name) in tiePeople)
        if (id != 'u_e' && id != 'u_m') _r(DailyGame.queens, id, name, 61),
      _r(DailyGame.queens, 'u1', '', 61),
      _r(DailyGame.queens, 'u_x', 'Arda', 61),
      _r(DailyGame.queens, 'u_y', 'Burak', 61),
      _r(DailyGame.queens, 'u_v', 'Defne', 75),
    ],
    DailyGame.tango: [
      _r(DailyGame.tango, 'u_x', 'Arda', 40),
      for (final (id, name) in tiePeople) _r(DailyGame.tango, id, name, 60),
      _r(DailyGame.tango, 'u1', '', 60),
      _r(DailyGame.tango, 'u_v', 'Defne', 70),
    ],
    DailyGame.zip: [
      for (final (id, name) in tiePeople) _r(DailyGame.zip, id, name, 33),
      _r(DailyGame.zip, 'u1', '', 33),
      _r(DailyGame.zip, 'u_x', 'Arda', 33),
      _r(DailyGame.zip, 'u_y', 'Burak', 33),
    ],
  },
  streaks: const {},
  names: {for (final (id, name) in tiePeople) id: name},
  myStreaks: const {},
);


/// One real day's boards, for the game icons and the tabs.
final Map<String, dynamic> tieBoardsPayload =
    jsonDecode(_boards) as Map<String, dynamic>;

const _boards = r'{"dayKey":"2026-01-01","queens":{"size":8,"regions":[1,1,1,0,0,0,0,0,1,1,2,2,2,0,2,0,1,1,1,2,2,2,2,0,1,1,5,3,3,2,2,2,4,5,5,3,3,2,2,2,4,7,5,5,3,3,6,2,4,7,7,5,6,3,6,6,4,4,7,6,6,6,6,6]},"tango":{"size":6,"givens":[-1,0,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,0,-1,-1,-1,-1,-1,-1,-1,-1,-1],"signs":[{"a":3,"b":4,"eq":false},{"a":27,"b":33,"eq":true},{"a":31,"b":32,"eq":true},{"a":14,"b":20,"eq":true},{"a":0,"b":6,"eq":true},{"a":24,"b":25,"eq":false}]},"zip":{"size":6,"checkpoints":[14,8,19,20,22,11,29,32]},"sudoku":{"size":6,"givens":[0,0,0,6,0,3,6,0,0,0,0,0,4,5,0,1,0,6,1,0,0,4,0,0,0,0,4,0,0,0,0,0,6,3,2,0]},"flow":{"size":7,"difficulty":"easy","endpoints":[[26,34],[41,7],[18,31],[36,19],[24,33],[40,37],[20,0]]},"futoshiki":{"size":5,"difficulty":"medium","givens":[0,0,0,0,0,0,0,0,0,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,3],"signs":[{"a":1,"b":6,"lt":false},{"a":3,"b":4,"lt":true},{"a":6,"b":11,"lt":true},{"a":7,"b":12,"lt":true},{"a":8,"b":13,"lt":false},{"a":10,"b":15,"lt":false},{"a":16,"b":17,"lt":true},{"a":18,"b":19,"lt":false},{"a":18,"b":23,"lt":false}]},"nonogram":{"size":10,"difficulty":"medium","rows":[[4],[5,1],[7,1],[3,1,1],[2,3],[3,1],[6],[3],[3],[4]],"cols":[[2],[3,1],[6],[3,3,1],[3,5],[4,4],[3,1,2],[1],[1],[5]]},"minesweeper":{"size":9,"difficulty":"medium","start":64,"mineCount":12,"mines":"e52932402d7bd87239c60f"},"starbattle":{"size":10,"difficulty":"hard","regions":[2,2,2,2,6,6,6,4,4,4,2,2,8,6,6,6,4,4,4,4,2,2,8,8,8,6,4,7,7,7,1,1,8,8,8,6,4,4,4,7,1,1,8,8,8,9,9,7,7,7,1,1,8,8,9,9,0,0,0,7,1,1,8,5,5,5,0,0,0,7,1,1,5,5,5,5,0,0,0,7,1,1,3,5,3,3,0,0,0,7,1,1,3,3,3,3,3,3,0,0]}}';
