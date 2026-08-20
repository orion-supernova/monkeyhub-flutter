import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'sheet_surface.dart';

/// What the chat list's `+` offers.
enum NewChatChoice { createRoom, joinWithCode }

/// The chooser behind the `+` in the chat list.
///
/// That button used to open the create-room sheet directly, which meant
/// joining a room by code lived only in Discover — one tab away, under a row
/// most people never scrolled to. Somebody handed an invite code has no reason
/// to look under "discover"; they look where new chats come from, which is
/// this button.
///
/// Two rows and nothing else. A `+` that opens a menu of two is barely slower
/// than one that opens a sheet, and the alternative — a long-press for the
/// second action — hides it just as thoroughly as Discover did.
///
/// Returns null when dismissed.
Future<NewChatChoice?> showNewChatMenu(
  BuildContext context, {
  required bool canCreateRoom,
  required bool canJoinByCode,
}) {
  HapticFeedback.lightImpact();
  return showAdaptiveSheet<NewChatChoice>(
    context,
    builder: (_) => _NewChatMenu(
      canCreateRoom: canCreateRoom,
      canJoinByCode: canJoinByCode,
    ),
  );
}

class _NewChatMenu extends StatelessWidget {
  const _NewChatMenu({required this.canCreateRoom, required this.canJoinByCode});

  final bool canCreateRoom;
  final bool canJoinByCode;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return SheetSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.newChatMenuTitle, style: theme.displaySmall),
          const SizedBox(height: 14),
          if (canCreateRoom)
            _Choice(
              icon: Icons.add_comment_outlined,
              title: l10n.newChatMenuCreateTitle,
              sub: l10n.newChatMenuCreateSub,
              onTap: () =>
                  Navigator.of(context).pop(NewChatChoice.createRoom),
            ),
          if (canJoinByCode)
            _Choice(
              icon: Icons.vpn_key_outlined,
              title: l10n.newChatMenuJoinTitle,
              sub: l10n.newChatMenuJoinSub,
              onTap: () =>
                  Navigator.of(context).pop(NewChatChoice.joinWithCode),
            ),
        ],
      ),
    );
  }
}

class _Choice extends StatefulWidget {
  const _Choice({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  State<_Choice> createState() => _ChoiceState();
}

class _ChoiceState extends State<_Choice> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: widget.onTap,
      semanticLabel: '${widget.title}. ${widget.sub}',
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: theme.motionFast,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: _pressed
                ? theme.ink.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.accentSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, size: 19, color: theme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.title, style: theme.body),
                    const SizedBox(height: 2),
                    Text(widget.sub, style: theme.monoTiny),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}
