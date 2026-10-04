import 'dart:async';
import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import 'filter_capsule.dart';
import 'ios_kit.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_user.dart';
import '../models/enums.dart';
import '../models/message_interaction.dart';
import '../theme/app_theme.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'interaction_bubble.dart' show interactionChoiceLabel;
import 'sheet_kit.dart';
import 'search_field.dart';
import 'message_stamp.dart' show formatClockTime;
import 'user_avatar.dart';
import '../l10n/text_case.dart';

/// Names everybody who answered a poll, a checklist or an event, grouped by
/// what they picked.
///
/// ## Why this is fetched and the reaction sheet is not
///
/// [ReactionDetailsSheet] un-collapses a list the client already holds:
/// `messages:list` carries every reaction row, so long-pressing a chip needs no
/// round trip. Interactions are the opposite by design — the card carries
/// COUNTS plus a capped preview of names, and nothing else, because the full
/// list is rewritten on every single answer and shipping it to every member on
/// every vote is the fan-out the whole feature was shaped to avoid. So the full
/// list is a query, made once, when somebody actually asks for it.
///
/// ## Anonymous polls never reach here
///
/// The card does not offer the tap, and the server refuses the query. Both,
/// deliberately: the client's silence is the good experience and the server's
/// refusal is the guarantee. If this sheet is somehow opened on one — a stale
/// screen, a poll made anonymous by a forward — the error state below says so
/// rather than showing an empty list, because an empty list is a claim about
/// who voted and a refusal is the truth.
Future<void> showInteractionRespondentsSheet(
  BuildContext context, {
  required ChatApi api,
  required String messageId,
  required String currentUserId,

  /// The card's own copy of the interaction, for the choice LABELS and the
  /// kind. Passed rather than re-fetched: the sheet groups rows by choice id,
  /// and the id alone is not a thing anybody can read.
  required MessageInteraction interaction,

  /// Room members first, so somebody who is not a friend still gets a face.
  /// Null for a person who has since left.
  required ChatUser? Function(String userId) resolveUser,
  required void Function(ChatUser user) onOpenProfile,
  Listenable? changes,
  MessageInteraction Function()? currentInteraction,
}) {
  return showAdaptiveSheet<void>(
    context,
    useSafeArea: true,
    builder: (_) => InteractionRespondentsSheet(
      api: api,
      messageId: messageId,
      currentUserId: currentUserId,
      interaction: interaction,
      resolveUser: resolveUser,
      onOpenProfile: onOpenProfile,
      changes: changes,
      currentInteraction: currentInteraction,
    ),
  );
}

class InteractionRespondentsSheet extends StatefulWidget {
  const InteractionRespondentsSheet({
    super.key,
    required this.api,
    required this.messageId,
    required this.currentUserId,
    required this.interaction,
    required this.resolveUser,
    required this.onOpenProfile,
    this.changes,
    this.currentInteraction,
  });

  final ChatApi api;
  final String messageId;
  final String currentUserId;
  final MessageInteraction interaction;
  final Listenable? changes;
  final MessageInteraction Function()? currentInteraction;
  final ChatUser? Function(String userId) resolveUser;
  final void Function(ChatUser user) onOpenProfile;

  @override
  State<InteractionRespondentsSheet> createState() =>
      _InteractionRespondentsSheetState();
}

class _InteractionRespondentsSheetState
    extends State<InteractionRespondentsSheet> {
  List<InteractionRespondentDetail>? _rows;
  bool _failed = false;
  bool _loading = false;
  bool _refreshQueued = false;
  late String _interactionSnapshot;
  int _request = 0;
  Timer? _refresh;
  final _search = TextEditingController();
  String _query = '';
  MessageInteraction get _interaction =>
      widget.currentInteraction?.call() ?? widget.interaction;

  /// Selected filter; null means ALL. Same shape as the reaction sheet's, and
  /// the same reasoning: the interesting question is usually "who picked THAT
  /// one", and a flat list of forty makes the reader do the grouping.
  String? _choiceId;

  @override
  void initState() {
    super.initState();
    _interactionSnapshot = jsonEncode(_interaction.toJson());
    widget.changes?.addListener(_changed);
    _load();
  }

  void _changed() {
    // The repository also notifies for presence, typing, avatars and API
    // traffic. Those must not start another respondents query (or cancel the
    // current query's result). Only this card's confirmed state matters.
    final snapshot = jsonEncode(_interaction.toJson());
    if (snapshot == _interactionSnapshot) return;
    _interactionSnapshot = snapshot;
    setState(() {});
    _refresh?.cancel();
    _refresh = Timer(const Duration(milliseconds: 180), _load);
  }

  @override
  void dispose() {
    _request++;
    _refresh?.cancel();
    widget.changes?.removeListener(_changed);
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_interaction.anonymous) return;
    _refresh?.cancel();
    _refresh = null;
    if (_loading) {
      _refreshQueued = true;
      return;
    }
    _refreshQueued = false;
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await widget.api
          .interactionRespondents(
            messageId: widget.messageId,
            userId: widget.currentUserId,
          )
          .timeout(const Duration(seconds: 15));
      if (!mounted || request != _request) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      // One state for every way this can fail — offline, a deleted message, an
      // anonymous poll. They are distinguishable server-side but not usefully
      // to a reader: the sheet cannot show the names, and why is a detail that
      // would need three more strings to say badly.
      setState(() {
        _failed = true;
        _loading = false;
      });
    } finally {
      if (mounted && request == _request && _refreshQueued) {
        _refreshQueued = false;
        unawaited(_load());
      }
    }
  }

  ChatUser _userFor(String id, String fallbackName) =>
      widget.resolveUser(id) ??
      // Answered, then left the room, and never was a friend. The stored name
      // is the snapshot taken when they answered — which is why the response
      // row carries one — and the id still seeds a stable avatar gradient, so
      // the row does not look broken.
      ChatUser(id: id, username: fallbackName, name: fallbackName);

  void _select(String? choiceId) {
    if (_choiceId == choiceId) return;
    HapticFeedback.selectionClick();
    setState(() => _choiceId = choiceId);
  }

  void _openProfile(ChatUser user) {
    Navigator.of(context).pop();
    widget.onOpenProfile(user);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final it = _interaction;
    final rows = _rows;
    final selected = it.choices.any((c) => c.id == _choiceId)
        ? _choiceId
        : null;
    final counts = <String, int>{};
    for (final row in rows ?? <InteractionRespondentDetail>[]) {
      counts.update(row.choiceId, (n) => n + 1, ifAbsent: () => 1);
    }
    String labelFor(String id) =>
        it.choices
            .where((c) => c.id == id)
            .map((c) => interactionChoiceLabel(l10n, it.kind, c))
            .firstOrNull ??
        '';
    final visible = <InteractionRespondentDetail>[
      for (final row in rows ?? <InteractionRespondentDetail>[])
        if ((selected == null || row.choiceId == selected) &&
            (_query.isEmpty ||
                '${row.name} ${labelFor(row.choiceId)}'.toLowerCase().contains(
                  _query,
                )))
          row,
    ]..sort((a, b) => b.at.compareTo(a.at));
    final people =
        rows?.map((r) => r.userId).toSet().length ?? it.respondentCount;
    final subtitle = it.kind == MessageType.checklist
        ? l10n.interactionChecklistProgress(
            rows == null ? it.doneCount : counts.length,
            it.choices.length,
          )
        : it.kind == MessageType.event
        ? l10n.interactionRsvpCount(people)
        : l10n.interactionVoteCount(people);

    return SheetFrame(
      title: sentenceCaseOf(context, _title(l10n, it.kind)),
      subtitle: subtitle,
      maxHeightFraction: 0.78,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      child: it.anonymous
          ? EmptyLine(l10n.interactionBadgeAnonymous)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchField(
                  controller: _search,
                  hintText: l10n.interactionAnswersSearch,
                  showCancel: false,
                  onChanged: (text) =>
                      setState(() => _query = text.trim().toLowerCase()),
                ),
                const SizedBox(height: 8),
                if (it.choices.length > 1)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 3,
                    ),
                    child: Row(
                      children: [
                        FilterCapsule(
                          label: l10n.interactionFilterAll,
                          count: rows?.length ?? 0,
                          showZeroCount: true,
                          active: selected == null,
                          onTap: () => _select(null),
                        ),
                        for (final choice in it.choices) ...[
                          const SizedBox(width: 6),
                          FilterCapsule(
                            label: interactionChoiceLabel(
                              l10n,
                              it.kind,
                              choice,
                            ),
                            count: counts[choice.id] ?? 0,
                            showZeroCount: true,
                            active: selected == choice.id,
                            onTap: () => _select(choice.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (_failed) ...[
                  EmptyLine(l10n.interactionRespondentsFailed),
                  SheetActionButton(label: l10n.interactionRetry, onTap: _load),
                ],
                const SizedBox(height: 8),
                Flexible(
                  child: rows == null
                      ? _failed
                            ? const SizedBox.shrink()
                            : const Center(child: CupertinoActivityIndicator())
                      : visible.isEmpty
                      ? EmptyLine(
                          rows.isEmpty
                              ? l10n.interactionRespondentsEmpty
                              : l10n.interactionFilterEmpty,
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: visible.length,
                          itemBuilder: (context, i) {
                            final r = visible[i];
                            return _RespondentRow(
                              theme: theme,
                              api: widget.api,
                              user: _userFor(r.userId, r.name),
                              name: r.name,
                              time: formatClockTime(r.at),
                              choiceLabel: selected == null
                                  ? labelFor(r.choiceId)
                                  : null,
                              isMe: r.userId == widget.currentUserId,
                              onOpenProfile: _openProfile,
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  String _title(AppLocalizations l10n, MessageType kind) => switch (kind) {
    MessageType.checklist => l10n.interactionRespondentsTitleChecklist,
    MessageType.event => l10n.interactionRespondentsTitleEvent,
    _ => l10n.interactionRespondentsTitlePoll,
  };
}

class _RespondentRow extends StatelessWidget {
  const _RespondentRow({
    required this.theme,
    required this.api,
    required this.user,
    required this.name,
    required this.time,
    required this.isMe,
    required this.onOpenProfile,
    this.choiceLabel,
  });

  final AppTheme theme;
  final ChatApi api;
  final ChatUser user;
  final String name;
  final String time;
  final String? choiceLabel;
  final bool isMe;
  final void Function(ChatUser user) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    // Tapping your own row would open your own profile from inside a sheet
    // about a poll, which is a place nobody meant to go.
    return PersonRow(
      avatar: UserAvatar(user: user, size: kPersonRowAvatar, api: api),
      title: name,
      subtitle: choiceLabel,
      trailing: Text(time, style: _meta(theme)),
      semanticLabel: name,
      onTap: isMe ? null : () => onOpenProfile(user),
    );
  }
}

/// Small meta text — counts, times, choice names — in the theme's body face
/// at footnote size with tabular figures, never the tracked monospace.
TextStyle _meta(AppTheme theme) => theme.bodySoft.copyWith(
  fontSize: 13,
  color: theme.inkMuted,
  fontFeatures: const [FontFeature.tabularFigures()],
);
