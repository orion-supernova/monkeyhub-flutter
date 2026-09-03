import 'dart:io' show File;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/file_meta.dart' show formatFileSize, kMaxFileUploadBytes;
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../share/shared_payload.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;
import 'pending_placeholder.dart';
import 'skeleton_rows.dart';
import 'user_avatar.dart';

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

    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: theme.body.copyWith(color: theme.ink),
        child: Container(
          decoration: theme.sheetDecoration(),
          padding: EdgeInsets.fromLTRB(
              22, 14, 22, 22 + MediaQuery.paddingOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetGrabber(),
              Text(
                loc.shareSheetTitle,
                style: theme.label.copyWith(letterSpacing: 2.4),
              ),
              const SizedBox(height: 12),
              _SharePreview(payload: widget.payload, theme: theme),
              const SizedBox(height: 12),
              _SearchField(
                controller: _search,
                theme: theme,
                onChanged: (_) => setState(() {}),
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
                          // Circular and 32pt, matching `_TargetRow`'s avatars,
                          // so nothing shifts when the real rows replace these.
                          child: SkeletonRows(count: 5, avatarSize: 32),
                        ),
                        empty: (context) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 26),
                          child: Text(
                            _query.isEmpty
                                ? loc.approvalsScreenForwardNoChatsYet
                                : loc.approvalsScreenForwardNoMatches,
                            textAlign: TextAlign.center,
                            style: theme.bodySoft,
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: [
                          for (final r in rooms)
                            _TargetRow(
                              title: _titleOf(r),
                              avatar: _RoomAvatar(
                                  room: r, repo: widget.repo, api: widget.api),
                              trailing: r.isEphemeral
                                  ? loc.approvalsScreenForwardFadesBadge
                                  : null,
                              onTap: () => Navigator.of(context)
                                  .pop(ShareToRoom(r)),
                            ),
                          if (suggested.isNotEmpty) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(10, 14, 10, 6),
                              child: Text(
                                loc.shareSheetSuggestedHeading,
                                style: theme.label.copyWith(
                                  letterSpacing: 2.0,
                                  color: theme.inkMuted,
                                ),
                              ),
                            ),
                            for (final f in suggested)
                              _TargetRow(
                                title: f.displayName,
                                avatar: UserAvatar(
                                    user: f, size: 32, api: widget.api),
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
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: BorderRadius.circular(theme.radiusMd),
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
                formatFileSize(kMaxFileUploadBytes),
              ),
              style: theme.caption.copyWith(color: theme.danger),
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
          color: theme.surfaceRaised,
          borderRadius: BorderRadius.circular(theme.radiusSm),
        ),
        child: Icon(icon, size: 19, color: theme.inkMuted),
      );
}

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({required this.room, required this.repo, required this.api});

  final ChatRoom room;
  final ChatRepository repo;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final peer = room.isDm ? repo.otherUserFor(room) : null;
    if (peer != null) return UserAvatar(user: peer, size: 32, api: api);
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: theme.divider, width: 0.8),
      ),
      child: Icon(
        room.isEphemeral ? CupertinoIcons.timer : CupertinoIcons.person_2,
        size: 15,
        color: theme.inkMuted,
      ),
    );
  }
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.title,
    required this.avatar,
    required this.onTap,
    this.trailing,
  });

  final String title;
  final Widget avatar;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final loc = AppLocalizations.of(context);

    // `FocusableTap` registers no gesture recognizer of its own, so the bare
    // `GestureDetector` inside is what receives the pointer; both carry the
    // handler. Never an InkWell — this app draws no ink anywhere.
    return FocusableTap(
      onTap: onTap,
      semanticLabel: loc.shareSheetSendToSemantic(title),
      radius: theme.radiusMd,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              avatar,
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyEmph.copyWith(color: theme.ink),
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    trailing!,
                    style: theme.monoTiny.copyWith(color: theme.inkMuted),
                  ),
                ),
              const SizedBox(width: 6),
              Icon(CupertinoIcons.chevron_right,
                  size: 14, color: theme.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.theme,
    required this.onChanged,
  });

  final TextEditingController controller;
  final AppTheme theme;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Container(
      decoration: theme.inputDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(CupertinoIcons.search, size: 15, color: theme.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: theme.body.copyWith(color: theme.ink),
              cursorColor: theme.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: loc.approvalsScreenForwardSearchHint,
                hintStyle: theme.bodySoft.copyWith(color: theme.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
