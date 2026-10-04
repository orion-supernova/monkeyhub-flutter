import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import 'adaptive_sheet.dart';
import 'ios_kit.dart';
import 'people_picker.dart';
import 'sheet_kit.dart';

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
    final l10n = AppLocalizations.of(context);
    final friends = _friends;

    // The Messages "New Message" sheet: a centred title over a close button,
    // the search capsule, the two room actions as a grouped block with
    // coloured tiles, then the people. Nearly full height and FIXED, so the
    // list never resizes under the finger as the filter narrows.
    return SheetFrame(
      title: l10n.newChatMenuTitle,
      maxHeightFraction: 0.92,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: PeoplePicker(
        people: friends,
        api: widget.api,
        // Never autofocused. The sheet opens onto a list you can just tap;
        // raising the keyboard on arrival would cover half of it to answer a
        // question nobody asked.
        hintText: l10n.newChatMenuSearchHint,
        emptyLabel: l10n.newChatMenuNoFriendsYet,
        noMatchLabel: l10n.newChatMenuNoFriendsMatch,
        localHeader: l10n.newChatMenuFriendsHeader,
        leading: [
          if (widget.canCreateRoom || widget.canJoinByCode)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: SheetRise(
                child: SheetGroup(
                  children: [
                    if (widget.canCreateRoom)
                      GroupedRow(
                        icon: CupertinoIcons.person_2_fill,
                        tone: TileTone.blue,
                        title: l10n.newChatMenuCreateTitle,
                        subtitle: l10n.newChatMenuCreateSub,
                        onTap: () => Navigator.of(context).pop((
                          choice: NewChatChoice.createRoom,
                          friend: null,
                        )),
                      ),
                    if (widget.canJoinByCode)
                      GroupedRow(
                        icon: CupertinoIcons.qrcode,
                        tone: TileTone.orange,
                        title: l10n.newChatMenuJoinTitle,
                        subtitle: l10n.newChatMenuJoinSub,
                        onTap: () => Navigator.of(context).pop((
                          choice: NewChatChoice.joinWithCode,
                          friend: null,
                        )),
                      ),
                  ],
                ),
              ),
            ),
        ],
        onPick: (u) => Navigator.of(context).pop((choice: null, friend: u)),
      ),
    );
  }
}

