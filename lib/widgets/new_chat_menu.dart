import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/layout.dart';
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
/// So the friends come first, with a search bar over them, and the two room
/// actions sit underneath as the less common case. It is the shape WhatsApp,
/// Telegram and Signal all converged on, for the reason they converged on it:
/// the list you want is nearly always short enough to tap without typing, and
/// the search bar is there for the day it isn't.
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

    // Autofocus only once the list is long enough that typing beats looking.
    // Below that the keyboard is pure obstruction: it covers the very rows
    // the sheet opened to show.
    final autofocusSearch = friends.length >= 8 && context.isCompact;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(theme.radiusLg),
          ),
        ),
        // A FIXED height, not one that fits the list.
        //
        // The obvious alternative — shrink-wrap to however many friends there
        // are — resizes the sheet on every keystroke as the filter narrows,
        // which walks the rows out from under the finger that is reaching for
        // them. A stable box that scrolls is the calmer answer, and it is what
        // every messenger's new-chat sheet does. Short of full height, because
        // a sheet that fills the screen is a page and this is not one.
        constraints: BoxConstraints(
          maxHeight: media.size.height * 0.78,
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
            // Flexible rather than Expanded so the two room rows below always
            // get the height they ask for first; the list takes what is left.
            Flexible(
              child: PeoplePicker(
                people: friends,
                api: widget.api,
                autofocus: autofocusSearch,
                hintText: l10n.newChatMenuSearchHint,
                emptyLabel: l10n.newChatMenuNoFriendsYet,
                noMatchLabel: l10n.newChatMenuNoFriendsMatch,
                onPick: (u) =>
                    Navigator.of(context).pop((choice: null, friend: u)),
              ),
            ),
            if (widget.canCreateRoom || widget.canJoinByCode) ...[
              const SizedBox(height: 6),
              Container(height: 1, color: theme.divider),
              const SizedBox(height: 6),
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
