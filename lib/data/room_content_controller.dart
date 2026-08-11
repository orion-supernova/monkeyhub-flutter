import 'package:flutter/foundation.dart';

import '../backend/chat_api.dart';
import '../models/chat_message.dart';
import '../models/message_formatting.dart';
import '../models/room_content_item.dart';
import '../services/link_preview_service.dart';
import 'chat_repository.dart';

/// Pages one tab of a room's shared content, and keeps it current.
///
/// Owned by the browser screen rather than by [ChatRepository], and not for
/// tidiness: this is a browse surface with its own lifecycle, whose state is
/// meaningless once the screen closes. `RoomInfoScreen` already sets the
/// precedent of reading outside the repository for exactly that reason.
///
/// ── Why there is no subscription here ──
///
/// A gallery that only updated on reopen would be visibly stale — send a photo,
/// back out, and it isn't there. But a second live query per tab would be four
/// more subscriptions on a screen the user is passing through. Neither is
/// needed: the room's transcript is ALREADY subscribed for the screen behind
/// this one, so newly-arrived messages can be read straight off
/// [ChatRepository.messagesFor] and spliced on top of the paged snapshot.
///
/// The seam between those two sources is the whole subtlety. They overlap —
/// the first page and the live list both contain the newest attachments — so
/// the merge dedupes by id. Without that, anything that arrived between the
/// fetch starting and finishing renders twice.
///
/// ── The SAVED tab has neither half ──
///
/// [RoomContentTab.saved] is not paged and not merged: `bookmarks:listForRoom`
/// is already subscribed for the open room and is capped at 50, so the whole
/// list is in [ChatRepository] and there is nothing to fetch, nothing to
/// deduplicate and no cursor to keep. Every method below therefore short-circuits
/// for it — see [items] and [_loadOnePage]. Modelling it as a tab that simply
/// never has more to load is what lets the screen keep one controller per tab
/// and one scroll handler for all of them.
class RoomContentController extends ChangeNotifier {
  RoomContentController({
    required this.repo,
    required this.api,
    required this.roomId,
    required this.tab,
  }) {
    repo.addListener(_onRepo);
  }

  final ChatRepository repo;
  final ChatApi api;
  final String roomId;
  final RoomContentTab tab;

  /// The pages fetched from the index, oldest-last. Never contains anything
  /// the live list is responsible for — see [items].
  final List<ChatMessage> _fetched = [];

  bool _loading = false;
  bool _hasMore = true;
  bool _loadedOnce = false;
  Object? _error;

  bool get isLoading => _loading;
  bool get hasMore => _hasMore;

  /// True once a fetch has completed, successfully or not. Distinguishes "no
  /// content" from "not asked yet", which are the same empty list otherwise.
  bool get loadedOnce => _loadedOnce;

  Object? get error => _error;

  /// This tab's messages, newest first.
  ///
  /// Recomputed on read rather than cached, because the live half changes
  /// underneath us on every repository notify and a cache would need
  /// invalidating on each one anyway. The lists involved are a few hundred
  /// entries at most.
  List<ChatMessage> get items {
    // The saved tab is the repository's list verbatim, and the ordering is the
    // point: `bookmarks:listForRoom` sorts by `savedAt` descending, NOT by
    // `createdAt` the way every other tab does. A personal shelf reads with the
    // last thing you put on it at the top — see [MessageBookmark.savedAt] — so
    // re-sorting this into transcript order below would quietly undo the one
    // decision that makes it a shelf rather than a second gallery.
    if (tab == RoomContentTab.saved) {
      return [for (final b in repo.savedFor(roomId)) b.message];
    }

    final seen = <String>{};
    final out = <ChatMessage>[];

    // The live half first: these are the newest, and a message present in both
    // halves should be the live copy — it carries current reactions and the
    // real id, where the fetched copy is a snapshot.
    for (final m in repo.messagesFor(roomId)) {
      if (!messageBelongsIn(m, tab)) continue;
      if (seen.add(m.id)) out.add(m);
    }
    for (final m in _fetched) {
      if (seen.add(m.id)) out.add(m);
    }

    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  /// [items] flattened to one entry per URL, for the LINKS tab.
  ///
  /// A message can hold several links and the server only recorded that it
  /// holds one, so this is where the count is actually decided. Ordering
  /// follows the message: bare URLs in the order they appear in its text,
  /// then link ENTITIES (formatted text carrying a URL) in span order — the
  /// row already holds the spans, so "check this" carrying a destination
  /// lands in the tab exactly as the bare URL would have. De-duplicated per
  /// message, matching `UrlDetector.extract`'s own rule.
  List<RoomLink> get links {
    final out = <RoomLink>[];
    for (final m in items) {
      final seen = <String>{};
      for (final url in UrlDetector.extract(m.content)) {
        if (seen.add(url)) out.add(RoomLink(url: url, message: m));
      }
      for (final f in m.formatting) {
        final url = f.url;
        if (f.type == FormattingType.link && url != null && seen.add(url)) {
          out.add(RoomLink(url: url, message: m));
        }
      }
    }
    return out;
  }

  /// Whether this tab currently has anything to draw.
  ///
  /// Not the same as `items.isEmpty` on the LINKS tab: a page of thirty
  /// messages there can yield zero renderable rows, because the row count is
  /// decided by [links] — the client's own re-derivation — while the page was
  /// selected by the server's coarser `hasLink`. See [_renderableCount].
  bool get isEmpty => _renderableCount == 0;

  /// How many rows this tab would actually draw from what is held.
  int get _renderableCount =>
      tab == RoomContentTab.links ? links.length : items.length;

  /// Loads the first page, once. Safe to call from `initState` and again from
  /// a rebuild.
  Future<void> loadInitial() {
    if (_loadedOnce || _loading) return Future.value();
    return loadMore();
  }

  /// Most pages one [loadMore] will chase before giving the screen a frame.
  ///
  /// Only ever reached on the LINKS tab, where a fetched page can render
  /// nothing (see [_renderableCount]). A bound rather than a `while (isEmpty)`
  /// because the alternative is a room whose links tab silently reads its
  /// entire history in one call.
  static const _maxPagesPerLoad = 4;

  /// Fetches the next page older than everything currently held, and keeps
  /// going while the pages it gets back render nothing.
  ///
  /// That continuation matters only for LINKS: the server records that a
  /// message contains a URL, and the client decides what a URL is. The two are
  /// separate implementations, so a page of thirty `hasLink` messages can
  /// produce zero rows — and stopping there would show "no links" over a room
  /// full of them, with more pages still available.
  ///
  /// The cursor comes from [_fetched] rather than from [items], deliberately.
  /// [items] includes the live half, which is always at the NEWEST end — using
  /// its last entry as "oldest I hold" would be correct only until the fetched
  /// pages ran past it, and then paging would jump backwards and re-fetch.
  Future<void> loadMore() async {
    for (var page = 0; page < _maxPagesPerLoad; page++) {
      final before = _renderableCount;
      await _loadOnePage();
      if (!_hasMore || _error != null) return;
      // Progress made, or nothing more to chase.
      if (_renderableCount > before) return;
    }
  }

  Future<void> _loadOnePage() async {
    if (_loading || !_hasMore) return;
    // Nothing to fetch, and saying so once is what stops the scroll handler
    // from asking again on every frame near the bottom. `loadedOnce` matters as
    // much as `hasMore`: without it the screen would sit on its spinner
    // forever, because an empty shelf and an unasked question look identical.
    if (tab == RoomContentTab.saved) {
      _hasMore = false;
      _loadedOnce = true;
      notifyListeners();
      return;
    }
    final userId = repo.userId;
    if (userId == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final before = _fetched.isEmpty ? null : _fetched.last.createdAt;
      final bucket = tab.bucket;
      final page = bucket == null
          ? await api.listRoomLinks(
              roomId: roomId, userId: userId, before: before)
          : await api.listRoomContent(
              roomId: roomId, userId: userId, bucket: bucket, before: before);

      // Dedupe against what is already held rather than trusting the cursor.
      // Two messages can share a `createdAt` to the millisecond — a forward
      // writes a batch inside one transaction — and an exclusive `<` cursor
      // would then skip one of them while an inclusive one repeats it. Filtering
      // by id makes the page boundary independent of that.
      final known = {for (final m in _fetched) m.id};
      for (final m in page.items) {
        if (known.add(m.id)) _fetched.add(m);
      }
      _hasMore = page.hasMore;
    } catch (e) {
      _error = e;
      // Not cleared: a failed page must not look like the end of the list, or
      // the screen would render "that's everything" over a network error.
      debugPrint('room content load error: $e');
    } finally {
      _loading = false;
      _loadedOnce = true;
      notifyListeners();
    }
  }

  /// Drops the paged half and re-fetches from the top.
  ///
  /// Used after a bulk delete, where the fetched snapshot is now describing
  /// messages that no longer exist. The live half needs no help — the
  /// transcript subscription reconciles it on its own.
  Future<void> refresh() async {
    _fetched.clear();
    _hasMore = true;
    _loadedOnce = false;
    notifyListeners();
    await loadMore();
  }

  /// Forgets [ids] immediately, so a deletion shows up on the next frame
  /// instead of after a round trip.
  ///
  /// The live half is left alone on purpose: `messages:list` will drop those
  /// rows by itself, and a client-side removal there would fight the
  /// subscription rather than lead it.
  void forget(Set<String> ids) {
    final before = _fetched.length;
    _fetched.removeWhere((m) => ids.contains(m.id));
    if (_fetched.length != before) notifyListeners();
  }

  void _onRepo() {
    // The live half of [items] is derived from the repository, so any change
    // to it can change what this tab renders. Cheap: the screen rebuilds a
    // grid, and the repository does not notify per frame.
    notifyListeners();
  }

  @override
  void dispose() {
    repo.removeListener(_onRepo);
    super.dispose();
  }
}
