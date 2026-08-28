import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/message_preview.dart';
import '../theme/app_theme.dart';
import '../theme/layout.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';
import '../widgets/message_stamp.dart' show formatClockTime;
import '../widgets/remote_image.dart';
import '../widgets/user_avatar.dart';
import 'room_items.dart' show humanDay;

/// Who has read one of your messages, and when — the screen behind a left pull
/// on your own bubble.
///
/// ── Where the numbers come from ────────────────────────────────────────────
///
/// Nowhere new. The room this was opened from is still mounted underneath and
/// still holds its `messages:getReadState` subscription, so every cursor on
/// this screen is already in memory before the finger has finished dragging it
/// in: [ChatRepository.roomReadCursors] and
/// [ChatRepository.roomDeliveredCursors], read through on every notification.
/// This screen issues NO query of its own and opens no subscription, which is
/// what lets it be pushed and thrown away sixty times without costing anything.
///
/// ── What a timestamp here actually means ───────────────────────────────────
///
/// The server keeps ONE read cursor per membership row, not one row per
/// (message × reader) — `schema.ts` rules that fan-out out in as many words,
/// twice. So "X read this" is exactly `X.lastReadAt >= message.createdAt`, and
/// the time shown is that cursor: the last moment X was caught up in this room.
/// For a message near the bottom of the transcript — which is very nearly
/// always what someone checks receipts on — the cursor moved *because of* this
/// message and the time is the read time. On an older message it is an upper
/// bound: they read it at some point between sending and that stamp. There is
/// no cheaper true answer available and a per-message one is not available at
/// any price, so the screen shows the cursor rather than inventing a precision
/// it does not have.
class MessageReceiptsScreen extends StatelessWidget {
  const MessageReceiptsScreen({
    super.key,
    required this.repo,
    required this.api,
    required this.roomId,
    required this.messageId,
    required this.fallbackMessage,
    required this.currentUserId,
    required this.roster,
    required this.onOpenProfile,
  });

  final ChatRepository repo;
  final ChatApi api;
  final String roomId;
  final String messageId;

  /// The bubble as the transcript knew it when the drag started. Used only
  /// when the live copy can't be found — a message that paged out of the
  /// window while this screen was open still has a header to draw.
  final ChatMessage fallbackMessage;

  final String currentUserId;

  /// The room's members, read through rather than snapshotted so somebody
  /// joining or leaving lands here too. Members are the only roster that
  /// covers people this reader isn't friends with.
  final List<ChatUser> Function() roster;

  final void Function(ChatUser user) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          // See home_screen: the bottom inset leaves a dead strip of
          // background under the scroller, which reads as a solid bar. The
          // list clears the home indicator with its own padding instead.
          SafeArea(
            bottom: false,
            // Rebuilt on the repository's own notifications, which is where
            // both cursor maps land. A receipt that arrives while this screen
            // is open moves a row from SENT to READ in front of the reader,
            // and it costs one fold over a handful of members to do it.
            child: AnimatedBuilder(
              animation: repo,
              builder: (context, _) => _body(context, theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppTheme theme) {
    final l10n = AppLocalizations.of(context);
    final message =
        repo.findMessageInRoom(roomId, messageId) ?? fallbackMessage;
    // `messages:getReadState` always returns the viewer's own row in full, so
    // two empty maps mean the subscription has not landed yet — never "nobody
    // here shares anything". Worth telling apart: without this, the half-second
    // between entering a room and the first receipt frame would file every
    // member under NO RECEIPTS and then move them, which reads as the app
    // changing its mind about the people you are talking to.
    final loading =
        repo.roomReadCursors.isEmpty && repo.roomDeliveredCursors.isEmpty;
    final entries = loading ? const <_Entry>[] : _entriesFor(message);
    final read = entries.where((e) => e.state == _ReceiptState.read).length;

    return AdaptivePageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(title: l10n.messageReceiptsScreenTitle),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                edgeToEdgeBottom(context, 28),
              ),
              // Header block first, then one row per person. Built lazily
              // rather than as a Column so a room with a hundred members lays
              // out the dozen rows that are on screen.
              itemCount: entries.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _Preamble(
                    message: message,
                    api: api,
                    read: read,
                    total: entries.length,
                    loading: loading,
                  );
                }
                final entry = entries[i - 1];
                final previous = i >= 2 ? entries[i - 2] : null;
                return _ReceiptRow(
                  index: i - 1,
                  entry: entry,
                  api: api,
                  // The section label rides on the first row of each run
                  // instead of being its own list item: the buckets are
                  // ordered and contiguous, so "did the state just change"
                  // is the whole of the grouping logic.
                  showSection: previous == null || previous.state != entry.state,
                  onOpenProfile: onOpenProfile,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Every other member of the room, bucketed against THIS message and sorted
  /// into the order the list renders: read first (most recent first, matching
  /// every other people-list in the app), then delivered, then everyone the
  /// message has not reached — or who does not say.
  List<_Entry> _entriesFor(ChatMessage message) {
    final reads = repo.roomReadCursors;
    final delivers = repo.roomDeliveredCursors;
    final at = message.createdAt;

    final out = <_Entry>[];
    for (final user in roster()) {
      // Your own row is not a receipt. You read it as you wrote it.
      if (user.id == currentUserId) continue;
      final readAt = reads[user.id];
      final deliveredAt = delivers[user.id];
      if (readAt != null && !readAt.isBefore(at)) {
        out.add(_Entry(user, _ReceiptState.read, readAt));
      } else if (deliveredAt != null && !deliveredAt.isBefore(at)) {
        out.add(_Entry(user, _ReceiptState.delivered, deliveredAt));
      } else if (readAt == null && deliveredAt == null) {
        // Neither cursor was served for this member, which the server only
        // does for someone withholding both. Distinct from "behind": there is
        // nothing to wait for here, and a row that sat in SENT forever with no
        // reason given is the kind of thing people read as a bug in the app or
        // a slight from the person.
        out.add(_Entry(user, _ReceiptState.hidden, null));
      } else {
        out.add(_Entry(user, _ReceiptState.sent, null));
      }
    }

    out.sort((a, b) {
      final byState = a.state.index.compareTo(b.state.index);
      if (byState != 0) return byState;
      final at = a.at, bt = b.at;
      if (at != null && bt != null) return bt.compareTo(at);
      // Undated rows (SENT, and anyone withholding) fall back to the name, so
      // the tail of the list is stable instead of shuffling on every rebuild.
      return a.user.displayName
          .toLowerCase()
          .compareTo(b.user.displayName.toLowerCase());
    });
    return out;
  }
}

/// How far this message got with one person. Declared in the order the list
/// shows them — [_Entry] sorts on `index`, so the enum IS the section order.
enum _ReceiptState { read, delivered, sent, hidden }

class _Entry {
  const _Entry(this.user, this.state, this.at);
  final ChatUser user;
  final _ReceiptState state;

  /// The cursor behind [state], or null where there is no time to show. See
  /// the class comment on [MessageReceiptsScreen] for what it means.
  final DateTime? at;
}

/// Back control and title, in the same shape as every other pushed list screen
/// in the app.
class _Header extends StatelessWidget {
  const _Header({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back, color: theme.inkSoft, size: 18),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              style: theme.label.copyWith(letterSpacing: 3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// The message itself, and one line of arithmetic about it.
class _Preamble extends StatelessWidget {
  const _Preamble({
    required this.message,
    required this.api,
    required this.read,
    required this.total,
    required this.loading,
  });

  final ChatMessage message;
  final ChatApi api;
  final int read;
  final int total;

  /// Whether the room's receipts have simply not arrived yet, as opposed to
  /// there being none.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MessageCard(message: message, api: api),
        const SizedBox(height: 20),
        if (loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 26, 0, 8),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: theme.accent,
                  strokeWidth: 2,
                ),
              ),
            ),
          )
        else if (total > 0) ...[
          _ReadMeter(read: read, total: total),
          const SizedBox(height: 6),
          Text(
            l10n.messageReceiptsSummary(read, total),
            style: theme.monoTiny,
          ),
          const SizedBox(height: 18),
        ] else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 22, 0, 8),
            child: Text(
              l10n.messageReceiptsEmptyState,
              textAlign: TextAlign.center,
              style: theme.bodySoft,
            ),
          ),
        ],
      ],
    );
  }
}

/// The message, drawn as the bubble it is rather than as a quoted row.
///
/// Sits on the end side, filled with `accent`, tail-less — enough for the
/// reader to recognise which of their messages this screen is about at a
/// glance, without dragging the whole [MessageBubble] machinery (albums,
/// reactions, receipts, polls) onto a screen that only needs the gist.
class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.api});

  final ChatMessage message;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // View-once media has no storage id — the server withholds it — so there
    // is deliberately nothing to show for those beyond the words.
    final hasThumb = !message.viewOnce &&
        message.mediaStorageId != null &&
        (message.type == MessageType.image ||
            message.type == MessageType.video);
    final ink = theme.accentInk;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
          decoration: theme.messageBubbleDecoration(
            isMine: true,
            ephemeral: message.isEphemeral,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasThumb) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(theme.radiusSm),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: RemoteImage(
                          storageId: message.mediaStorageId!,
                          api: api,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      messagePreviewLine(message, hasThumbnail: hasThumb),
                      style: theme.body.copyWith(color: ink),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // The card's own stamp gets the day as well as the clock: a
              // screen full of read times is unreadable if you can't see what
              // it is measuring from.
              Text(
                '${humanDay(_dayOf(message.createdAt))} · '
                '${formatClockTime(message.createdAt)}',
                style: theme.monoTiny.copyWith(
                  color: ink.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// A hairline of how far the message has got through the room.
///
/// Two segments, not three: read against everyone else. Delivery has its own
/// section below and its own stamps, and a second colour here would have made
/// the one number worth glancing at — how many people have actually seen this
/// — the hardest thing on the bar to measure.
class _ReadMeter extends StatelessWidget {
  const _ReadMeter({required this.read, required this.total});
  final int read;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final fraction = total == 0 ? 0.0 : (read / total).clamp(0.0, 1.0);
    // Decorative: the same fraction is spelled out in words directly under it.
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          height: 3,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: theme.surfaceRaised)),
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: fraction,
                  child: ColoredBox(color: theme.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One person, and where this message got to with them.
class _ReceiptRow extends StatefulWidget {
  const _ReceiptRow({
    required this.index,
    required this.entry,
    required this.api,
    required this.showSection,
    required this.onOpenProfile,
  });

  final int index;
  final _Entry entry;
  final ChatApi api;

  /// Whether this row opens a new bucket and therefore carries its heading.
  final bool showSection;

  final void Function(ChatUser user) onOpenProfile;

  @override
  State<_ReceiptRow> createState() => _ReceiptRowState();
}

class _ReceiptRowState extends State<_ReceiptRow> {
  bool _pressed = false;

  void _open() => widget.onOpenProfile(widget.entry.user);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final entry = widget.entry;
    final user = entry.user;

    final row = Row(
      children: [
        // Faded for everyone the message hasn't reached, so the two halves of
        // the list are legible as two halves from across the room — before
        // reading a single name or heading.
        Opacity(
          opacity: entry.at == null ? 0.55 : 1,
          child: UserAvatar(
            user: user,
            api: widget.api,
            size: 40,
            showStatus: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 10),
        _Stamp(entry: entry),
        SizedBox(
          width: 18,
          child: Icon(Icons.chevron_right, size: 16, color: theme.inkMuted),
        ),
      ],
    );

    final tappable = FocusableTap(
      onTap: _open,
      radius: theme.radiusMd,
      semanticLabel: _semanticsFor(l10n, entry),
      child: GestureDetector(
        onTap: _open,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: theme.motionFast,
          curve: theme.motionCurve,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: _pressed ? theme.surfaceRaised : Colors.transparent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: row,
        ),
      ),
    );

    // No entrance animation on these rows, and that is load-bearing rather
    // than a taste: the page is dragged in from an overlay and handed over to
    // a route mid-flight (see `swipe_to_receipts.dart`), which builds this
    // list a second time. Anything that animates on first build would replay
    // from the start on the handover frame, turning a seamless takeover into a
    // visible flinch. The page's own slide is the entrance.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSection)
          Padding(
            padding: EdgeInsets.fromLTRB(8, widget.index == 0 ? 0 : 18, 8, 8),
            child: Text(
              _sectionLabel(l10n, entry.state),
              style: theme.label.copyWith(
                letterSpacing: 2.4,
                color: entry.state == _ReceiptState.read
                    ? theme.accent
                    : theme.inkMuted,
              ),
            ),
          ),
        tappable,
      ],
    );
  }

  static String _sectionLabel(AppLocalizations l10n, _ReceiptState state) =>
      switch (state) {
        _ReceiptState.read => l10n.messageReceiptsSectionRead,
        _ReceiptState.delivered => l10n.messageReceiptsSectionDelivered,
        _ReceiptState.sent => l10n.messageReceiptsSectionSent,
        _ReceiptState.hidden => l10n.messageReceiptsSectionHidden,
      };

  /// The whole row as one sentence, because the visual hierarchy that makes
  /// the day and the clock readable apart is worth nothing read aloud.
  static String _semanticsFor(AppLocalizations l10n, _Entry entry) {
    final name = entry.user.displayName;
    final at = entry.at;
    if (at == null) {
      return entry.state == _ReceiptState.hidden
          ? l10n.messageReceiptsSemanticHidden(name)
          : l10n.messageReceiptsSemanticSent(name);
    }
    final day = humanDay(_dayOf(at));
    final clock = formatClockTime(at);
    return entry.state == _ReceiptState.read
        ? l10n.messageReceiptsSemanticRead(name, day, clock)
        : l10n.messageReceiptsSemanticDelivered(name, day, clock);
  }
}

/// The right-hand column: when.
///
/// The day and the clock are two different facts and are drawn as two
/// different things — the day small, muted, tracked out and upper-case, the
/// time large, mono and in full ink under it. Setting them in one style is
/// what makes a column of receipts unreadable: every row becomes the same
/// length of grey, and the eye has nothing to sort on.
class _Stamp extends StatelessWidget {
  const _Stamp({required this.entry});
  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final at = entry.at;

    if (at == null) {
      return Text(
        entry.state == _ReceiptState.hidden
            ? l10n.messageReceiptsStateHidden
            : l10n.messageReceiptsStateWaiting,
        style: theme.monoTiny.copyWith(color: theme.inkMuted),
      );
    }

    final read = entry.state == _ReceiptState.read;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          humanDay(_dayOf(at)),
          style: theme.monoTiny.copyWith(
            color: theme.inkMuted,
            fontSize: 9,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          formatClockTime(at),
          style: theme.mono.copyWith(
            fontSize: 15,
            height: 1.1,
            color: read ? theme.ink : theme.inkSoft,
            fontWeight: read ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
