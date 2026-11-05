import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
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

/// Every fighter as a grid of cards, the picked one alive (only it animates,
/// so twenty portraits cost one ticker).
class FightCharacterGrid extends StatelessWidget {
  const FightCharacterGrid({super.key, required this.selected, required this.onPick, this.columns = 4, this.look = FightLook.cartoon});

  final int selected;
  final ValueChanged<int> onPick;
  final int columns;
  final FightLook look;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 8.0;
        final w = (box.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in roster)
              SizedBox(
                width: w,
                height: w * 1.32,
                child: _Card(
                  key: ValueKey('fight_char_${c.id}'),
                  char: c,
                  family: fightFamilyName(l10n, fightFamilyOf(c.id)),
                  selected: c.id == selected,
                  look: look,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPick(c.id);
                  },
                ),
              ),
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
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xff16121f),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .86),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.fightPickFighter,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, decoration: TextDecoration.none),
                ),
                const SizedBox(height: 14),
                FightCharacterGrid(selected: current, look: look, onPick: (id) => Navigator.of(context).pop(id)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
