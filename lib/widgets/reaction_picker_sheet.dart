import 'package:flutter/material.dart';
import '../theme/theme_scope.dart';

class ReactionPickerSheet extends StatefulWidget {
  const ReactionPickerSheet({super.key});
  @override
  State<ReactionPickerSheet> createState() => _ReactionPickerSheetState();
}

class _ReactionPickerSheetState extends State<ReactionPickerSheet> {
  final _q = TextEditingController();
  String _query = '';

  // Curated set matching v02's ReactionPickerView.
  static const _common = [
    '❤️', '🔥', '😂', '😮', '😢', '👍', '👎', '🙏',
    '🎉', '👀', '💀', '✨', '💯', '🤔', '😍', '😎',
    '🥲', '🫠', '🫡', '🤝', '☕', '🌙', '🌊', '🥀',
  ];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final visible = _query.isEmpty
        ? _common
        : _common.where((e) => true).toList(); // emoji search is non-trivial — kept simple

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: theme.inkMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('REACT', style: theme.label.copyWith(letterSpacing: 2.4)),
            const SizedBox(height: 14),
            Container(
              decoration: theme.inputDecoration(),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextField(
                controller: _q,
                style: theme.body.copyWith(color: theme.ink),
                cursorColor: theme.accent,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'or paste an emoji…',
                  hintStyle: theme.body.copyWith(color: theme.inkMuted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (v) {
                  final t = v.trim();
                  if (t.isNotEmpty) Navigator.of(context).pop(t);
                },
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final e in visible)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(e),
                    child: Container(
                      width: 46, height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.surfaceRaised,
                        borderRadius: BorderRadius.circular(theme.radiusMd),
                        border: Border.all(color: theme.divider),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
              ],
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
