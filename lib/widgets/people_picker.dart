import 'dart:async';

import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import 'search_field.dart';
import 'user_avatar.dart';

/// A search bar over a list of people, with the list virtualised underneath.
///
/// Two very different screens needed the same thing at the same time — the
/// chat list's `+`, which should open onto your friends the way every other
/// messenger does, and the guardian's "allow someone" picker, which had you
/// typing a username from memory into a bare text field. Both are "find a
/// person and tap them", and writing that twice would have produced two search
/// boxes that behaved differently within a week.
///
/// **The host must bound this widget's height.** It builds a real
/// [ListView.builder], not a shrink-wrapped column, so a list of two hundred
/// friends costs the same as a list of six: only the visible rows are built,
/// and scrolling recycles them. That is also why it cannot simply be dropped
/// inside `SheetSurface`, whose child already lives in a
/// [SingleChildScrollView] — a shrink-wrapping list in there would build every
/// row on every frame.
///
/// ## Two sources, one box
///
/// [people] is whatever the host already holds in memory, and filtering it is
/// local, synchronous and un-debounced — typing costs no round trip and cannot
/// lag the keystroke. [searchMore] is optional and adds a second section for
/// everyone else, fetched from the server, debounced, and shown under its own
/// heading so it reads as a different kind of answer: these are strangers, the
/// ones above are yours.
///
/// A host that has no business reaching strangers simply omits [searchMore]
/// and gets a purely local picker.
class PeoplePicker extends StatefulWidget {
  const PeoplePicker({
    super.key,
    required this.people,
    required this.api,
    required this.onPick,
    required this.hintText,
    required this.emptyLabel,
    required this.noMatchLabel,
    this.autofocus = false,
    this.searchMore,
    this.localHeader,
    this.remoteHeader,
    this.minQueryForRemote = 2,
  });

  /// Everyone selectable without a network call. Held by the host.
  final List<ChatUser> people;
  final ChatApi api;
  final ValueChanged<ChatUser> onPick;

  final String hintText;

  /// Shown when [people] is empty AND nothing is being searched — "you have no
  /// friends yet", which is a different thing to say than "nothing matched".
  final String emptyLabel;

  /// Shown when the query matched nothing anywhere.
  final String noMatchLabel;

  final bool autofocus;

  /// Finds people beyond [people]. Omit to keep the picker purely local.
  ///
  /// Called with the trimmed query, debounced. Whatever it returns is shown
  /// under [remoteHeader], minus anyone already listed above.
  final Future<List<ChatUser>> Function(String query)? searchMore;

  /// Headings for the two sections. Only drawn when that section has rows and
  /// the other one could also appear — a single unlabelled list needs no
  /// heading telling you what it obviously is.
  final String? localHeader;
  final String? remoteHeader;

  /// How many characters before [searchMore] is worth a round trip.
  final int minQueryForRemote;

  @override
  State<PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<PeoplePicker> {
  final _q = TextEditingController();
  String _query = '';

  Timer? _debounce;
  List<ChatUser> _remote = const [];

  /// The query [_remote] actually answers. Guards against an older, slower
  /// response landing after a newer one and overwriting it — the classic
  /// out-of-order search bug, which shows up as results that do not match
  /// what is in the box.
  String _remoteFor = '';
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    setState(() => _query = v);
    final needle = v.trim();
    if (widget.searchMore == null || needle.length < widget.minQueryForRemote) {
      setState(() {
        _remote = const [];
        _remoteFor = '';
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 250), () => _runRemote(needle));
  }

  Future<void> _runRemote(String needle) async {
    try {
      final found = await widget.searchMore!(needle);
      if (!mounted || _query.trim() != needle) return;
      setState(() {
        _remote = found;
        _remoteFor = needle;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || _query.trim() != needle) return;
      // A failed lookup leaves the local results alone and simply stops
      // claiming to be searching. Saying "nothing matched" would be a lie
      // about the network.
      setState(() => _searching = false);
    }
  }

  /// Case-insensitive, matching either half of an identity.
  ///
  /// Recomputed per build rather than cached: the input is the host's live
  /// list, which changes underneath us when someone is added or removed, and
  /// a cache would need invalidating on a signal this widget never receives.
  /// It is one pass over a list that is already in memory.
  List<ChatUser> get _localMatches {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return widget.people;
    return widget.people
        .where(
          (u) =>
              u.username.toLowerCase().contains(needle) ||
              u.name.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final local = _localMatches;
    final needle = _query.trim();

    // Never repeat a row. Someone who is both a friend and a search hit
    // belongs in the section that says they are yours.
    final shown = {for (final u in local) u.id};
    final remote = _remoteFor == needle
        ? _remote.where((u) => !shown.contains(u.id)).toList(growable: false)
        : const <ChatUser>[];

    final searching = needle.isNotEmpty;
    final showHeaders = widget.localHeader != null &&
        widget.remoteHeader != null &&
        local.isNotEmpty &&
        remote.isNotEmpty;

    // ── flatten into one virtualised list ──────────────────────────────────
    // Headers ride in the same builder as the rows rather than sitting in a
    // Column above it, so a long friends list scrolls its own heading away
    // instead of pinning two of them to the top.
    final rows = <_Row>[
      if (showHeaders) _Row.header(widget.localHeader!),
      for (final u in local) _Row.person(u),
      if (showHeaders) _Row.header(widget.remoteHeader!),
      for (final u in remote) _Row.person(u),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The bar stays OUTSIDE the scroller, so it holds still while the list
        // moves under it — the arrangement every messenger uses, and the one
        // that lets you keep typing while glancing down the results.
        SearchField(
          controller: _q,
          hintText: widget.hintText,
          autofocus: widget.autofocus,
          onChanged: _onChanged,
          onClear: () => _onChanged(''),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: rows.isEmpty
              ? _Empty(
                  // A search still in flight must not report "no one matches":
                  // that is an answer, and we do not have one yet.
                  label: _searching
                      ? null
                      : (searching ? widget.noMatchLabel : widget.emptyLabel),
                )
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.zero,
                  itemCount: rows.length + (_searching ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == rows.length) return const _Searching();
                    final row = rows[i];
                    final u = row.user;
                    if (u == null) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
                        child: Text(
                          row.header!,
                          style: theme.label.copyWith(
                            letterSpacing: 2.2,
                            color: theme.inkMuted,
                          ),
                        ),
                      );
                    }
                    return _PersonTile(
                      // Keyed by identity: the list is re-filtered on every
                      // keystroke, and an unkeyed row would let the framework
                      // reuse one person's element for another's data.
                      key: ValueKey(u.id),
                      user: u,
                      api: widget.api,
                      onTap: () => widget.onPick(u),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// One entry in the flattened list: a heading or a person, never both.
class _Row {
  const _Row.header(this.header) : user = null;
  const _Row.person(this.user) : header = null;
  final String? header;
  final ChatUser? user;
}

class _Empty extends StatelessWidget {
  const _Empty({required this.label});

  /// Null while an answer is still on its way.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    if (label == null) return const _Searching();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Text(
          label!,
          style: theme.bodySoft,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching();

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: theme.accent),
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    super.key,
    required this.user,
    required this.api,
    required this.onTap,
  });

  final ChatUser user;
  final ChatApi api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            UserAvatar(user: user, size: 40, api: api),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.displayName,
                    style: theme.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${user.username}',
                    style: theme.monoTiny,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
          ],
        ),
      ),
    );
  }
}
