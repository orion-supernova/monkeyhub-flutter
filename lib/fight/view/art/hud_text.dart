/// Every word the HUD draws. Localised by the app; text is fitted to its box.
class FightHudText {
  const FightHudText({
    required this.round,
    required this.fight,
    required this.ko,
    required this.time,
    required this.wins,
    required this.draw,
    required this.hits,
  });
  final String Function(int n) round; // "ROUND 1"
  final String fight; // "FIGHT!"
  final String ko; // "K.O."
  final String time; // "TIME"
  final String Function(String name) wins; // "KAI WINS"
  final String draw; // "DRAW"
  final String Function(int n) hits; // "3 HITS"

  static final FightHudText english = FightHudText(
      round: (n) => 'ROUND $n',
      fight: 'FIGHT!',
      ko: 'K.O.',
      time: 'TIME',
      wins: (n) => '$n WINS',
      draw: 'DRAW',
      hits: (n) => '$n HITS');
}
