import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../widgets/adaptive_sheet.dart';
import '../../widgets/sheet_drag.dart' show SheetScrollBody;
import '../../widgets/sheet_kit.dart' show SheetFrame;
import '../../widgets/spring_press.dart';
import '../core/core.dart';
import 'art/art_common.dart' show FightLook;
import 'fighter_portrait.dart';

/// The family a fighter belongs to, for the card's label and tint.
enum FightFamily { human, monkey, animal, legend }

FightFamily fightFamilyOf(int id) => switch (id) {
  0 || 12 || 13 || 14 || 15 => FightFamily.human,
  1 || 4 || 5 || 6 || 7 => FightFamily.monkey,
  2 || 8 || 9 || 10 || 11 => FightFamily.animal,
  _ => FightFamily.legend,
};

String fightFamilyName(AppLocalizations l10n, FightFamily f) => switch (f) {
  FightFamily.human => l10n.fightFamilyHuman,
  FightFamily.monkey => l10n.fightFamilyMonkey,
  FightFamily.animal => l10n.fightFamilyAnimal,
  FightFamily.legend => l10n.fightFamilyLegend,
};

/// Card colours per family: (top, bottom, glow).
(Color, Color, Color) fightFamilyTones(FightFamily f) => switch (f) {
  FightFamily.human => (const Color(0xff1fb5a8), const Color(0xff0c3d3a), const Color(0xff3fd2c7)),
  FightFamily.monkey => (const Color(0xffc8642a), const Color(0xff3d1a08), const Color(0xffffb86b)),
  FightFamily.animal => (const Color(0xff6b7a8f), const Color(0xff1e2430), const Color(0xffb6c8ff)),
  FightFamily.legend => (const Color(0xff7b5cff), const Color(0xff1d1240), const Color(0xffc48bff)),
};

/// Clamps a stored pick to the roster.
int fightCharOf(int id) => id >= 0 && id < roster.length ? id : 0;

/// The cast by family, in the order the picker shows them: each family
/// starts with its starter (KAI, MOJO, TANK, NYX), then the rest by id.
const List<(FightFamily, List<int>)> kFightFamilies = [
  (FightFamily.human, [0, 12, 13, 14, 15]),
  (FightFamily.monkey, [1, 4, 5, 6, 7]),
  (FightFamily.animal, [2, 8, 9, 10, 11]),
  (FightFamily.legend, [3, 16, 17, 18, 19]),
];

/// Every fighter, grouped by family: a header and a row of five cards per
/// family. The picked one is alive (only it animates, so twenty portraits
/// cost one ticker); rows scroll sideways when the screen is too narrow.
class FightCharacterGrid extends StatelessWidget {
  const FightCharacterGrid({super.key, required this.selected, required this.onPick, this.look = FightLook.cartoon, this.maxCardWidth});

  /// Caps a card's width (desktop); the rows then sit left-aligned.
  final double? maxCardWidth;
  final int selected;
  final ValueChanged<int> onPick;
  final FightLook look;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        // Five across when they fit at a readable size, else a sideways row.
        final fit = (box.maxWidth - gap * 4) / 5;
        final w = fit >= 76 ? (maxCardWidth == null ? fit : (fit < maxCardWidth! ? fit : maxCardWidth!)) : 84.0;
        final h = w * 1.3;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (fam, ids) in kFightFamilies) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 10, 0, 6),
                child: Row(
                  children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: fightFamilyTones(fam).$3, shape: BoxShape.circle)),
                    const SizedBox(width: 7),
                    Text(
                      fightFamilyName(l10n, fam).toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Color(0xb3ffffff)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: fit >= 76 ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
                  itemCount: ids.length,
                  separatorBuilder: (_, _) => const SizedBox(width: gap),
                  itemBuilder: (context, i) {
                    final c = roster[ids[i]];
                    return SizedBox(
                      width: w,
                      child: _Card(
                        key: ValueKey('fight_char_${c.id}'),
                        char: c,
                        family: fightFamilyName(l10n, fam),
                        selected: c.id == selected,
                        look: look,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onPick(c.id);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.char, required this.family, required this.selected, required this.look, required this.onTap});

  final CharacterDef char;
  final String family;
  final bool selected;
  final FightLook look;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (top, bottom, glow) = fightFamilyTones(fightFamilyOf(char.id));
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: SpringPress(
        onTap: onTap,
        haptic: false,
        scale: 0.94,
        semanticLabel: char.name,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [top, bottom], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? const Color(0xffffd23a) : const Color(0x22ffffff), width: selected ? 2.5 : 1),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                bottom: 22,
                child: FighterPortrait(charId: char.id, animate: selected, ready: selected, look: look, glow: glow),
              ),
              Positioned(
                left: 7,
                right: 5,
                bottom: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      family.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xb3ffffff), letterSpacing: .8),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(char.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A sheet with the grid; resolves to the picked id (null if dismissed).
Future<int?> showFightCharacterPicker(BuildContext context, {required int current, FightLook look = FightLook.cartoon}) {
  return showAdaptiveSheet<int>(
    context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SheetFrame(
        title: l10n.fightPickFighter,
        maxHeightFraction: .86,
        padding: EdgeInsets.zero,
        child: SheetScrollBody(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: FightCharacterGrid(selected: current, look: look, onPick: (id) => Navigator.of(context).pop(id)),
        ),
      );
    },
  );
}
