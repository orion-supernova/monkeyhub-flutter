import 'package:flutter/material.dart';

import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../widgets/spring_press.dart';

/// Two pill toggles, Sound and Music, for the dark Jungle Fist pause menu.
/// Styled like the look picker beside it: a white pill when on, a translucent
/// one when off. Each flips its [SettingsStore] flag; the fight audio listens.
class FightAudioToggles extends StatelessWidget {
  const FightAudioToggles({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = SettingsStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Row(
        children: [
          Expanded(
            child: _Pill(
              label: l10n.fightSoundLabel,
              icon: store.fightSound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              on: store.fightSound,
              onTap: () => store.setFightSound(!store.fightSound),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Pill(
              label: l10n.fightMusicLabel,
              icon: store.fightMusic ? Icons.music_note_rounded : Icons.music_off_rounded,
              on: store.fightMusic,
              onTap: () => store.setFightMusic(!store.fightMusic),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.on, required this.onTap});
  final String label;
  final IconData icon;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = on ? const Color(0xff0b0a12) : Colors.white;
    return SpringPress(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: on ? Colors.white : const Color(0x1fffffff),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
