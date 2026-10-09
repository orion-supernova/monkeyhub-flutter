import 'dart:io' show File;

import 'package:flutter/cupertino.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/file_meta.dart'
    show formatFileSize, intakeCapFor, kMaxFileUploadBytes, kMaxMediaIntakeBytes;
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../share/shared_payload.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'chat_list_row.dart' show ChatRoomAvatar;
import 'ios_kit.dart';
import 'search_field.dart';
import 'sheet_kit.dart';
import 'pending_placeholder.dart';
import 'skeleton_rows.dart';
import 'user_avatar.dart';
import '../l10n/text_case.dart';

/// What the user picked to receive a share.
///
/// A room and a friend are different answers to the same question: the friend
/// may not have a DM room yet, and creating one is a mutation the sheet has no
/// business running while the user is still looking at it.
sealed class ShareDestination {
  const ShareDestination();
}

class ShareToRoom extends ShareDestination {
  const ShareToRoom(this.room);
  final ChatRoom room;
}

/// A friend with no DM room yet. The caller opens one — see
/// `ChatRepository.openDmWith` — which is a round trip, so it happens after the
/// sheet is gone rather than under it.
class ShareToFriend extends ShareDestination {
  const ShareToFriend(this.friend);
  final ChatUser friend;
}

/// Asks which chat an incoming share should go to.
///
/// This is the sheet the OS's *app icon* leads to. Tapping one of the app's own
/// suggestions in the share sheet's top row skips it entirely — that tap
/// already named a room, and asking again would make the suggestion pointless.
///
/// Single-select, unlike [showForwardTargetSheet]. Forwarding is a broadcast
/// ("send this to some people"); a share is a compose ("put this in that
/// chat"), and it ends in the room with the picture in an editor, which is not
/// a place five rooms can be at once.
Future<ShareDestination?> showShareTargetSheet(
  BuildContext context, {
  required ChatRepository repo,
  required ChatApi api,
  required SharedPayload payload,
}) {
  return showAdaptiveSheet<ShareDestination>(
    context,
    useSafeArea: true,
    builder: (_) => _ShareTargetSheet(repo: repo, api: api, payload: payload),
  );
}

class _ShareTargetSheet extends StatefulWidget {
  const _ShareTargetSheet({
    required this.repo,
    required this.api,
    required this.payload,
  });

  final ChatRepository repo;
  final ChatApi api;
  final SharedPayload payload;

  @override
  State<_ShareTargetSheet> createState() => _ShareTargetSheetState();
}

class _ShareTargetSheetState extends State<_ShareTargetSheet> {
  final TextEditingController _search = TextEditingController();

  /// The sheet outlives the moment it was opened at, and the room list very
  /// often arrives afterwards.
  ///
  /// A share is frequently *the launch* — the iOS extension's "Open in
  /// MonkeyHub" raises this sheet on a cold start, before
  /// `rooms:listUserRooms` has delivered anything. Read once at build time,
  /// that is a picker that says "no other chats yet" to an account with
  /// seventeen of them and never corrects itself, because nothing rebuilds it.
  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onRepoChange);
  }

  void _onRepoChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChange);
    _search.dispose();
    super.dispose();
  }

  String get _query => _search.text.trim().toLowerCase();

  String _titleOf(ChatRoom room) {
    final loc = AppLocalizations.of(context);
    if (room.isSavedMessages) return loc.savedMessagesTitle;
    if (!room.isDm) return room.name;
    return widget.repo.otherUserFor(room)?.name ??
        loc.approvalsScreenForwardDirectMessageFallback;
  }

  /// Chats, most recently active first — the same filter the forward sheet
  /// applies, because a chat that cannot receive a forward cannot receive a
  /// share either.
  List<ChatRoom> get _rooms {
    final q = _query;
    final out = <ChatRoom>[];
    for (final r in widget.repo.rooms) {
      // No `isMember` test — see the note in `buildShareTargets`. The field is
      // `rooms:listPublic`'s alone and is false on everything this list holds,
      // so filtering on it emptied the sheet outright.
      if (!widget.repo.capabilitiesFor(r).canReceiveForwards) continue;
      if (q.isNotEmpty && !_titleOf(r).toLowerCase().contains(q)) continue;
      out.add(r);
    }
    out.sort((a, b) {
      final at = a.lastMessageTime, bt = b.lastMessageTime;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
    return out;
  }

  /// Friends with no chat above. Someone you have never messaged is exactly who
  /// is missing from a "recent chats" list, and a share sheet that can only
  /// reach people you already talk to is the wrong shape — this is the row big
  /// chat apps put under the recents for the same reason.
  List<ChatUser> get _suggested {
    final q = _query;
    final known = <String>{};
    for (final r in widget.repo.rooms) {
      if (!r.isDm) continue;
      final peer = widget.repo.otherUserFor(r);
      if (peer != null) known.add(peer.id);
    }
    final out = <ChatUser>[];
    for (final f in widget.repo.friends) {
      if (known.contains(f.id)) continue;
      if (f.isSystem) continue;
      if (q.isNotEmpty && !f.displayName.toLowerCase().contains(q)) continue;
      out.add(f);
    }
    out.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final rooms = _rooms;
    final suggested = _suggested;
    final empty = rooms.isEmpty && suggested.isEmpty;

    return SheetFrame(
      title: sentenceCaseOf(context, loc.shareSheetTitle),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: DefaultTextStyle(
        style: theme.body.copyWith(color: theme.ink),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SharePreview(payload: widget.payload, theme: theme),
            const SizedBox(height: 12),
            SearchField(
              controller: _search,
              hintText: loc.chatTargetSearchHint,
              onChanged: (_) => setState(() {}),
              // In a sheet, so no Cancel. And no onClear: the default
              // empties the controller and reports '' through onChanged; the
              // custom setState-only one left the typed text in the bar.
              showCancel: false,
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.42,
              ),
              child: empty
                  ? PendingPlaceholder(
                      // A search that matched nothing HAS its answer, so it
                      // goes straight to the empty text — only an unfiltered
                      // list can still be waiting on the subscription.
                      pending: _query.isEmpty && !widget.repo.roomsLoaded,
                      loading: (context) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        // Circular and 40pt, matching the rows' avatars, so
                        // nothing shifts when the real rows replace these.
                        child: SkeletonRows(count: 5, avatarSize: 40),
                      ),
                      empty: (context) => EmptyLine(
                        _query.isEmpty
                            ? loc.approvalsScreenForwardNoChatsYet
                            : loc.approvalsScreenForwardNoMatches,
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final (i, r) in rooms.indexed)
                          _TargetRow(
                            divider: i < rooms.length - 1,
                            title: _titleOf(r),
                            avatar: ChatRoomAvatar(
                              room: r,
                              dmUser: r.isDm
                                  ? widget.repo.otherUserFor(r)
                                  : null,
                              api: widget.api,
                              size: kPersonRowAvatar,
                            ),
                            trailing: r.isEphemeral
                                ? loc.approvalsScreenForwardFadesBadge
                                : null,
                            onTap: () => Navigator.of(context)
                                .pop(ShareToRoom(r)),
                          ),
                        if (suggested.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: GroupedHeader(
                              loc.shareSheetSuggestedHeading,
                            ),
                          ),
                          for (final (i, f) in suggested.indexed)
                            _TargetRow(
                              divider: i < suggested.length - 1,
                              title: f.displayName,
                              avatar: UserAvatar(
                                user: f,
                                size: kPersonRowAvatar,
                                api: widget.api,
                              ),
                              onTap: () => Navigator.of(context)
                                  .pop(ShareToFriend(f)),
                            ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What is about to be sent, above the list.
///
/// A share sheet hands the app someone else's content sight unseen — the user
/// has already left the app they were in and cannot go back to check. Showing
/// the picture (or naming the file) is the difference between a deliberate send
/// and a hopeful one.
class _SharePreview extends StatelessWidget {
  const _SharePreview({required this.payload, required this.theme});

  final SharedPayload payload;
  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final sendable = payload.sendable;
    final images = [for (final i in sendable) if (i.isImage) i];

    final Widget leading;
    if (images.isNotEmpty) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(theme.radiusSm),
        child: Image.file(
          File(images.first.path),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          // A staged file the OS reclaimed between the share and this frame is
          // rare but real, and a preview is not worth an exception.
          errorBuilder: (_, _, _) => _glyphBox(CupertinoIcons.photo),
        ),
      );
    } else if (sendable.isNotEmpty) {
      leading = _glyphBox(
        sendable.first.messageType == MessageType.video
            ? CupertinoIcons.videocam
            : CupertinoIcons.doc,
      );
    } else {
      leading = _glyphBox(CupertinoIcons.link);
    }

    final String label;
    if (sendable.length > 1) {
      label = loc.shareSheetPreviewItems(sendable.length);
    } else if (sendable.length == 1) {
      label = sendable.first.fileName ?? loc.shareSheetPreviewItems(1);
    } else {
      label = payload.text ?? '';
    }

    final oversized = payload.oversized;

    return Container(
      padding: const EdgeInsets.all(10),
      // The sheets' grouped-block fill, not a sunken slab — sunken reads as
      // a black hole in dark themes and a stray tan in character ones.
      decoration: BoxDecoration(
        color: sheetGroupFill(theme),
        borderRadius: BorderRadius.circular(groupedRadius(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              leading,
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySoft,
                ),
              ),
            ],
          ),
          if (oversized.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              loc.shareSheetTooLargeDropped(
                oversized.length,
                // The tighter cap when any document is among them: that is
                // the limit the sender ran into.
                formatFileSize(
                  oversized.any(
                    (i) => intakeCapFor(i.mimeType) == kMaxFileUploadBytes,
                  )
                      ? kMaxFileUploadBytes
                      : kMaxMediaIntakeBytes,
                ),
              ),
              style: groupedMetaStyle(theme).copyWith(color: theme.danger),
            ),
          ],
        ],
      ),
    );
  }

  Widget _glyphBox(IconData icon) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: quietFill(theme),
          borderRadius: BorderRadius.circular(theme.radiusSm),
        ),
        child: Icon(icon, size: 19, color: theme.inkMuted),
      );
}

/// A destination. Tapping it picks it — it does not drill into anything —
/// so no chevron: the shared [PersonRow], like the new-chat list's people.
class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.title,
    required this.avatar,
    required this.onTap,
    this.trailing,
    this.divider = false,
  });

  final String title;
  final Widget avatar;
  final VoidCallback onTap;
  final String? trailing;

  /// A hairline under the row — every row but a run's last, matching the
  /// forward sheet's identical room list.
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);
    final row = PersonRow(
      avatar: avatar,
      title: title,
      titleTrailing: trailing == null
          ? null
          : Text(trailing!, style: groupedMetaStyle(theme)),
      semanticLabel: loc.shareSheetSendToSemantic(title),
      onTap: onTap,
    );
    if (!divider) return row;
    // The Contacts rule, as in the forward sheet: a hairline from the text
    // on, none under the last row.
    return Stack(
      children: [
        row,
        Positioned(
          left: kPersonRowTextInset,
          right: 0,
          bottom: 0,
          child: Container(
            height: 1 / MediaQuery.devicePixelRatioOf(context),
            color: theme.ink.withValues(alpha: 0.10),
          ),
        ),
      ],
    );
  }
}
