import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;
import 'people_picker.dart';

/// What the chat list's `+` offers besides a person.
enum NewChatChoice { createRoom, joinWithCode }

/// What the sheet came back with: either a friend to open a DM with, or one
/// of the two room actions. Never both, and null when it was dismissed.
typedef NewChatOutcome = ({NewChatChoice? choice, ChatUser? friend});

/// The sheet behind the `+` in the chat list.
///
/// It used to be two rows — create a room, join with a code — and nothing
/// else, which quietly made "message a person I already know" the one thing
/// the new-chat button could not start. The only route to a friend's DM was
/// Discover: a different tab, scrolled past the room world, through a people
/// search. That is a long way round for the single most common thing anyone
/// opens a messenger to do.
///
/// The layout, top to bottom: a search bar that stays put, then the two room
/// actions, then the friends — with the actions and the friends sharing ONE
/// scroller. That last part is the whole trick. The first cut pinned the room
/// actions to the bottom instead, which left the friends a narrow band
/// squeezed between two fixed blocks: four or five rows visible, and scrolling
/// them felt like reading through a letterbox. Letting the actions scroll away
/// gives the people the entire sheet.
///
/// It is the shape WhatsApp, Telegram and Signal all converged on, for the
/// reason they converged on it: the list you want is nearly always short
/// enough to tap without typing, the actions are one flick away, and the
/// search bar is there for the day the list isn't short.
///
/// The list is virtualised and filtered locally — see [PeoplePicker]. Nothing
/// here issues a network call: `repo.friends` is already live in memory
/// because the chat list is driven by the same repository.
///
/// Returns null when dismissed.
Future<NewChatOutcome?> showNewChatMenu(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
  required bool canCreateRoom,
  required bool canJoinByCode,
}) {
  HapticFeedback.lightImpact();
  return showAdaptiveSheet<NewChatOutcome>(
    context,
    // It can reach the top of the screen once a long friends list is in it.
    useSafeArea: true,
    builder: (_) => _NewChatMenu(
      repo: repo,
      api: api,
      canCreateRoom: canCreateRoom,
      canJoinByCode: canJoinByCode,
    ),
  );
}

class _NewChatMenu extends StatefulWidget {
  const _NewChatMenu({
    required this.repo,
    required this.api,
    required this.canCreateRoom,
    required this.canJoinByCode,
  });

  final ChatRepository repo;
  final ChatApi api;
  final bool canCreateRoom;
  final bool canJoinByCode;

  @override
  State<_NewChatMenu> createState() => _NewChatMenuState();
}

class _NewChatMenuState extends State<_NewChatMenu> {
  @override
  void initState() {
    super.initState();
    // The friends list is live: someone accepting a request while this sheet
    // is open should appear in it, not on the next open.
    widget.repo.addListener(_onRepo);
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepo);
    super.dispose();
  }

  void _onRepo() {
    if (mounted) setState(() {});
  }

  /// Real people only.
  ///
  /// The bug-report bot is in `friends` like anybody else — it has to be, so
  /// its thread is reachable — but "start a new chat with the log bot" is not
  /// an action, and the backend refuses most of what it implies anyway.
  List<ChatUser> get _friends =>
      widget.repo.friends.where((f) => !f.isSystem).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final media = MediaQuery.of(context);
    final friends = _friends;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(theme.radiusLg),
          ),
        ),
        // Nearly the whole window, and a FIXED size.
        //
        // Tall because this is a list you scroll, and a sheet that stops
        // halfway shows a handful of rows and makes the rest feel like work.
        // Fixed because the alternative — fitting the list — resizes the sheet
        // on every keystroke as the filter narrows, which walks the rows out
        // from under the finger reaching for them. `useSafeArea` on the route
        // keeps it clear of the status bar, so this never actually reaches the
        // top of the screen.
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.92,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          // `viewInsets` and `padding` are never both non-zero — raising the
          // keyboard is what zeroes the second — so adding them covers a
          // sheet at rest and a sheet being typed into with one expression.
          12 + media.padding.bottom + media.viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabber(),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(l10n.newChatMenuTitle, style: theme.displaySmall),
            ),
            // Expanded, not Flexible: the picker owns everything below the
            // title, and there is no longer a pinned footer competing with it
            // for height. The room actions live INSIDE its scroller now — see
            // `leading` below.
            Expanded(
              child: PeoplePicker(
                people: friends,
                api: widget.api,
                // Never autofocused. The sheet opens onto a list you can just
                // tap; raising the keyboard on arrival would cover the bottom
                // half of it to answer a question nobody asked.
                hintText: l10n.newChatMenuSearchHint,
                emptyLabel: l10n.newChatMenuNoFriendsYet,
                noMatchLabel: l10n.newChatMenuNoFriendsMatch,
                localHeader: l10n.newChatMenuFriendsHeader,
                leading: [
                  if (widget.canCreateRoom)
                    _Choice(
                      icon: Icons.add_comment_outlined,
                      title: l10n.newChatMenuCreateTitle,
                      sub: l10n.newChatMenuCreateSub,
                      onTap: () => Navigator.of(context).pop((
                        choice: NewChatChoice.createRoom,
                        friend: null,
                      )),
                    ),
                  if (widget.canJoinByCode)
                    _Choice(
                      icon: Icons.vpn_key_outlined,
                      title: l10n.newChatMenuJoinTitle,
                      sub: l10n.newChatMenuJoinSub,
                      onTap: () => Navigator.of(context).pop((
                        choice: NewChatChoice.joinWithCode,
                        friend: null,
                      )),
                    ),
                ],
                onPick: (u) =>
                    Navigator.of(context).pop((choice: null, friend: u)),
              ),
            ),
          ],
        ),
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
