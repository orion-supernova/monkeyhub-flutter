import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_room.dart';
import '../models/chat_user.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/discover_rows.dart';
import '../widgets/ios_kit.dart';
import '../widgets/search_field.dart' show SearchField;

import 'navigation/open_room.dart';
import '../l10n/text_case.dart';

/// Chrome for the full-list screens Discover's "see all" rows open.
///
/// Discover previews a capped few of both worlds and sends the rest here, so
/// its own height stays bounded no matter how many you have — you can always
/// see both worlds without scrolling past one to reach the other.
///
/// Rooms used to need no equivalent: its preview was the public directory,
/// and [SearchScreen] with an empty query already rendered all of it. Now
/// that the preview is the rooms you're already in rather than a browsable
/// directory, [RoomsListScreen] exists for the same reason
/// [PeopleListScreen] does.
class _ListScaffold extends StatelessWidget {
  const _ListScaffold({
    required this.title,
    required this.caption,
    required this.children,
  });
  final String title;
  final String caption;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    // The shared iOS page: glass back button, a large title that hands off to
    // the bar as the list scrolls, the count as the line under it.
    return IosPage(
      title: sentenceCaseOf(context, title),
      subtitle: sentenceCaseOf(context, caption),
      children: [
        AdaptivePageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

/// Every person you're connected to.
class PeopleListScreen extends StatefulWidget {
  const PeopleListScreen({super.key, required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<PeopleListScreen> createState() => _PeopleListScreenState();
}

class _PeopleListScreenState extends State<PeopleListScreen> {
  final _q = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onChange);
    _q.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _openDm(ChatUser user) async {
    try {
      final roomId = await widget.repo.openDmWith(user);
      if (!mounted) return;
      openRoom(context, roomId: roomId, repo: widget.repo, api: widget.api);
    } catch (_) {}
  }

  /// Filters the friends already in hand — no round trip, no pushed screen.
  /// This list is people you have, so narrowing it is a local operation;
  /// searching for people you *don't* have is the separate door on Discover.
  List<ChatUser> get _visible {
    final all = widget.repo.friends;
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where(
          (u) =>
              u.displayName.toLowerCase().contains(q) ||
              u.username.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = widget.repo.friends.length;
    final visible = _visible;
    return _ListScaffold(
      title: l10n.discoverListsPeopleTitle,
      caption: l10n.discoverListsPeopleCount(total),
      children: [
        if (total > 0) ...[
          // THE search bar: pill, magnifier, clear button, accent caret.
          SearchField(
            controller: _q,
            hintText: l10n.discoverListsFilterHint,
            // No onClear: the field's own empties the controller AND reports
            // '' here. A custom one that only reset [_query] left the typed
            // text sitting in the bar over an unfiltered list.
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 18),
        ],
        if (total == 0)
          DiscoverEmptyLine(l10n.discoverListsNoOneYet)
        else if (visible.isEmpty)
          DiscoverEmptyLine(l10n.discoverListsNoMatches(_query))
        else
          // One grouped block, the iOS contacts list.
          GroupedSection(
            children: [
              for (final f in visible)
                FriendRow(
                  key: ValueKey(f.id),
                  user: f,
                  api: widget.api,
                  onTap: () => _openDm(f),
                ),
            ],
          ),
      ],
    );
  }
}

/// Every group chat you're already in.
class RoomsListScreen extends StatefulWidget {
  const RoomsListScreen({super.key, required this.repo, required this.api});
  final ChatRepository repo;
  final ChatApi api;

  @override
  State<RoomsListScreen> createState() => _RoomsListScreenState();
}

class _RoomsListScreenState extends State<RoomsListScreen> {
  final _q = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onChange);
    _q.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _openRoom(ChatRoom room) =>
      openRoom(context, roomId: room.id, repo: widget.repo, api: widget.api);

  List<ChatRoom> get _myRooms => widget.repo.activeRooms
      .where((r) => r.isGroupChat)
      .toList(growable: false);

  /// Filters the rooms already in hand — no round trip, no pushed screen.
  /// Mirrors [_PeopleListScreenState._visible]: this is rooms you're a member
  /// of, so narrowing it is local; finding rooms you're not in yet is the
  /// separate search door on Discover.
  List<ChatRoom> _visible(List<ChatRoom> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((r) => r.name.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myRooms = _myRooms;
    final total = myRooms.length;
    final visible = _visible(myRooms);
    return _ListScaffold(
      title: l10n.discoverListsRoomsTitle,
      caption: l10n.discoverListsRoomsCount(total),
      children: [
        if (total > 0) ...[
          // THE search bar: pill, magnifier, clear button, accent caret.
          SearchField(
            controller: _q,
            hintText: l10n.discoverListsFilterRoomsHint,
            // No onClear: the field's own empties the controller AND reports
            // '' here. A custom one that only reset [_query] left the typed
            // text sitting in the bar over an unfiltered list.
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 18),
        ],
        if (total == 0)
          DiscoverEmptyLine(l10n.discoverListsNoRoomsYet)
        else if (visible.isEmpty)
          DiscoverEmptyLine(l10n.discoverListsNoRoomsMatch(_query))
        else
          GroupedSection(
            children: [
              for (final r in visible)
                PublicRoomTile(
                  key: ValueKey(r.id),
                  room: r,
                  api: widget.api,
                  joined: true,
                  onTap: () => _openRoom(r),
                ),
            ],
          ),
      ],
    );
  }
}
