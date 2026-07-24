import 'package:flutter/material.dart';

import '../models/chat_room.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'labeled_field.dart';

/// Prompts for a room password when the user tries to join a locked room.
/// Resolves to the entered password, or null if dismissed.
Future<String?> showRoomPasswordSheet(BuildContext context, ChatRoom room) {
  return showAdaptiveSheet<String>(
    context,
    builder: (_) => _PasswordSheet(room: room),
  );
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.room});
  final ChatRoom room;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: theme.sheetDecoration(),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.inkMuted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.lock_outline, color: theme.accent, size: 18),
                const SizedBox(width: 8),
                Text('LOCKED', style: theme.label.copyWith(color: theme.accent, letterSpacing: 2)),
              ],
            ),
            const SizedBox(height: 10),
            Text(widget.room.name, style: theme.displayLarge),
            const SizedBox(height: 6),
            Text(
              'this room has a password. ask the host if you need it.',
              style: theme.bodySoft,
            ),
            const SizedBox(height: 20),
            ThemedInput(
              controller: _controller,
              hint: 'passphrase…',
              obscure: _obscure,
              autofocus: true,
              onSubmitted: (v) => Navigator.of(context).pop(v),
              trailing: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: theme.inkMuted,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(_controller.text),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.accent,
                  borderRadius: BorderRadius.circular(theme.radiusMd),
                ),
                child: Text(
                  'ENTER',
                  style: theme.label.copyWith(color: theme.accentInk, letterSpacing: 2.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
