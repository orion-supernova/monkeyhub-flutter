import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme_scope.dart';

/// Reached via the `+` on the floating reaction pill. WhatsApp-style:
/// a categorized sheet of every emoji, with skin tones and search. No
/// freeform text entry — picking an emoji is the only way out.
class ReactionPickerSheet extends StatelessWidget {
  const ReactionPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final screenH = MediaQuery.sizeOf(context).height;
    final pickerH = (screenH * 0.5).clamp(320.0, 460.0);
    // viewInsets.bottom = soft keyboard (pushes the WHOLE sheet up).
    // paddingOf().bottom = home indicator / gesture bar — folded INTO the
    // picker's height + grid padding so the emoji grid itself extends all
    // the way to the screen edge (no visible blank strip), while the last
    // row of emojis still clears the indicator.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final totalPickerH = pickerH + bottomSafe;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.inkMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'REACT',
              textAlign: TextAlign.center,
              style: theme.label.copyWith(letterSpacing: 2.4),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: totalPickerH,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop(emoji.emoji);
                },
                config: Config(
                  height: totalPickerH,
                  checkPlatformCompatibility: true,
                  emojiTextStyle: TextStyle(color: theme.ink, fontSize: 24),
                  emojiViewConfig: EmojiViewConfig(
                    columns: 8,
                    emojiSizeMax: 28,
                    backgroundColor: Colors.transparent,
                    verticalSpacing: 2,
                    horizontalSpacing: 2,
                    gridPadding: EdgeInsets.fromLTRB(8, 4, 8, 4 + bottomSafe),
                    recentsLimit: 28,
                    noRecents: Center(
                      child: Text(
                        'no recents yet',
                        style: theme.monoTiny,
                      ),
                    ),
                    buttonMode: ButtonMode.CUPERTINO,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: Colors.transparent,
                    indicatorColor: theme.accent,
                    iconColor: theme.inkMuted,
                    iconColorSelected: theme.accent,
                    backspaceColor: theme.accent,
                    dividerColor: theme.divider,
                    tabBarHeight: 40,
                    initCategory: Category.SMILEYS,
                  ),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: false,
                  ),
                  skinToneConfig: SkinToneConfig(
                    enabled: true,
                    dialogBackgroundColor: theme.surface,
                    indicatorColor: theme.accent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper: show the picker and return the chosen emoji (or null on dismiss).
Future<String?> showReactionPicker(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const ReactionPickerSheet(),
  );
}
