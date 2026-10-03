import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'dart:async';

import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../models/chat_user.dart';
import '../theme/theme_scope.dart';
import 'search_field.dart';

import 'user_avatar.dart';
import 'teardown_safe.dart';
import '../l10n/text_case.dart';

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
    this.leading = const [],
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

  /// Rows drawn above the people, INSIDE the scroller.
  ///
  /// The host's own actions — "create a room", "join with a code" — go here
  /// rather than in a pinned block under the list. Pinning them is what makes
  /// a sheet feel cramped: the list ends up a narrow band squeezed between the
  /// search bar and a footer, with barely a few rows visible and nowhere to
  /// scroll. Scrolling them away gives the people the whole sheet, which is
  /// the arrangement WhatsApp uses and the reason its list feels roomy.
  ///
  /// Hidden the moment a query is typed. Once you are searching for a person,
  /// "create a room" is not an answer to what you asked, and it would be
  /// sitting on top of the rows that are.
  final List<Widget> leading;

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
    final showLeading = widget.leading.isNotEmpty && !searching;

    // The "everyone else" heading only earns its place when both sections have
    // rows to separate. The "your friends" one also earns it whenever the
    // host's own actions are sitting above the people — without it the list
    // runs straight on from the buttons with nothing saying what changed.
    final bothSections = widget.localHeader != null &&
        widget.remoteHeader != null &&
        local.isNotEmpty &&
        remote.isNotEmpty;
    final showLocalHeader = widget.localHeader != null &&
        local.isNotEmpty &&
        (bothSections || showLeading);

    // ── flatten into one virtualised list ──────────────────────────────────
    // Everything rides in the one builder — the host's rows, the headings and
    // the people — rather than stacking fixed blocks around a short list. That
    // is what lets the people have the whole sheet to scroll in, and it keeps
    // every row lazily built no matter how many friends there are.
    final rows = <_Row>[
      if (showLeading) ...widget.leading.map(_Row.widget),
      if (showLocalHeader) _Row.header(widget.localHeader!),
      for (final u in local) _Row.person(u),
      if (bothSections) _Row.header(widget.remoteHeader!),
      for (final u in remote) _Row.person(u),
    ];

    // No people, and nothing on its way. Said INSIDE the list so the host's
    // rows above it stay reachable — a bare centred message in place of the
    // whole scroller would take "create a room" away from someone whose only
    // problem is having no friends yet.
    if (local.isEmpty && remote.isEmpty && !_searching) {
      rows.add(
        _Row.widget(
          _Empty(label: searching ? widget.noMatchLabel : widget.emptyLabel),
        ),
      );
    }

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
        const SizedBox(height: 6),
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.zero,
            itemCount: rows.length + (_searching ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == rows.length) return const _Searching();
              final row = rows[i];
              final child = row.child;
              if (child != null) return child;
              final u = row.user;
              if (u == null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 18, 0, 4),
                  child: Text(
                    sentenceCaseOf(context, row.header!),
                    style: theme.caption.copyWith(
                      fontSize: 13,
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

/// One entry in the flattened list: a heading, a person, or a widget the host
/// supplied. Exactly one of the three.
class _Row {
  const _Row.header(String this.header) : user = null, child = null;
  const _Row.person(ChatUser this.user) : header = null, child = null;
  const _Row.widget(Widget this.child) : header = null, user = null;
  final String? header;
  final ChatUser? user;
  final Widget? child;
}

/// "Nobody here" — only ever built once a lookup has actually answered. A
/// search still in flight must not report "no one matches": that is an answer,
/// and we do not have one yet. The caller enforces that; see the `_searching`
/// guard where this row is appended.
class _Empty extends StatelessWidget {
  const _Empty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      child: Text(
        label,
        style: theme.bodySoft,
        textAlign: TextAlign.center,
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
          child: CupertinoActivityIndicator(radius: 8, color: theme.inkMuted),
        ),
      ),
    );
  }
}

class _PersonTile extends StatefulWidget {
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
  State<_PersonTile> createState() => _PersonTileState();
}

/// A contact row the way Messages draws one: face, name, handle under it in
/// muted ink, a hairline that starts at the text. No chevron — tapping a
/// person starts the chat, it does not drill into anything.
class _PersonTileState extends State<_PersonTile>
    with TeardownSafe<_PersonTile> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final user = widget.user;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _down ? Duration.zero : const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          color: _down ? theme.ink.withValues(alpha: 0.07) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            UserAvatar(user: user, size: 42, api: widget.api),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.ink.withValues(alpha: 0.08),
                      width: 1 / MediaQuery.devicePixelRatioOf(context),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.displayName,
                      style: theme.bodyEmph.copyWith(
                        color: theme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '@${user.username}',
                      style: theme.caption.copyWith(
                        fontSize: 13,
                        color: theme.inkMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
