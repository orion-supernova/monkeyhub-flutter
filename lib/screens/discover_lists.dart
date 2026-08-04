import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/discover_rows.dart';
import 'navigation/open_room.dart';

/// Chrome for the full-list screen Discover's people "see all" row opens.
///
/// Discover previews five friends and sends the rest here, so its own height
/// stays bounded no matter how many you have — you can always see both worlds
/// without scrolling past one to reach the other.
///
/// Rooms need no equivalent: [SearchScreen] with an empty query already renders
/// the whole public list, so a second screen would have been the same thing
/// minus the search field.
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
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: Icon(
                          Icons.arrow_back,
                          color: theme.inkSoft,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(title, style: theme.displayMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(width: 18, height: 1, color: theme.accent),
                      const SizedBox(width: 8),
                      Text(caption, style: theme.caption),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
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
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final total = widget.repo.friends.length;
    final visible = _visible;
    return _ListScaffold(
      title: l10n.discoverListsPeopleTitle,
      caption: l10n.discoverListsPeopleCount(total),
      children: [
        if (total > 0) ...[
          Container(
            decoration: theme.inputDecoration(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(Icons.search, color: theme.inkMuted, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _q,
                    onChanged: (v) => setState(() => _query = v),
                    style: theme.body,
                    cursorColor: theme.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      hintText: l10n.discoverListsFilterHint,
                      hintStyle: theme.body.copyWith(color: theme.inkMuted),
                    ),
                  ),
                ),
                if (_query.isNotEmpty)
                  FocusableTap(
                    onTap: () {
                      _q.clear();
                      setState(() => _query = '');
                    },
                    semanticLabel: l10n.discoverListsClearFilterSemanticLabel,
                    shape: FocusRingShape.circle,
                    radius: 999,
                    child: GestureDetector(
                      onTap: () {
                        _q.clear();
                        setState(() => _query = '');
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Icon(Icons.close, size: 16, color: theme.inkMuted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (total == 0)
          DiscoverEmptyLine(l10n.discoverListsNoOneYet)
        else if (visible.isEmpty)
          DiscoverEmptyLine(l10n.discoverListsNoMatches(_query))
        else
          for (final f in visible)
            FriendRow(
              key: ValueKey(f.id),
              user: f,
              api: widget.api,
              onTap: () => _openDm(f),
            ),
      ],
    );
  }
}
