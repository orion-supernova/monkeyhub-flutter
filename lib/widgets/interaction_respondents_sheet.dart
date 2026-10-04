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
  });

  final ChatApi api;
  final String messageId;
  final String currentUserId;
  final MessageInteraction interaction;
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

  /// Selected filter; null means ALL. Same shape as the reaction sheet's, and
  /// the same reasoning: the interesting question is usually "who picked THAT
  /// one", and a flat list of forty makes the reader do the grouping.
  String? _choiceId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.api.interactionRespondents(
        messageId: widget.messageId,
        userId: widget.currentUserId,
      );
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (_) {
      if (!mounted) return;
      // One state for every way this can fail — offline, a deleted message, an
      // anonymous poll. They are distinguishable server-side but not usefully
      // to a reader: the sheet cannot show the names, and why is a detail that
      // would need three more strings to say badly.
      setState(() => _failed = true);
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
    final it = widget.interaction;
    final rows = _rows;

    final selected =
        it.choices.any((c) => c.id == _choiceId) ? _choiceId : null;
    // Built as a statement rather than a ternary with a `..sort()` cascade on
    // the end of it. The cascade binds to the WHOLE conditional, so the
    // still-loading branch — a `const []` — was the thing being sorted, and
    // sorting an unmodifiable list throws. It crashed the sheet on open, every
    // time, in the one frame before the query came back: an analyzer-clean,
    // type-correct expression whose precedence was not what it read as.
    final visible = <InteractionRespondentDetail>[
      if (rows != null)
        for (final r in rows)
          if (selected == null || r.choiceId == selected) r,
    ]..sort((a, b) => b.at.compareTo(a.at));

    return SheetFrame(
      title: sentenceCaseOf(context, _title(l10n, it.kind)),
      subtitle: it.kind == MessageType.event
          ? l10n.interactionRsvpCount(it.respondentCount)
          : l10n.interactionVoteCount(it.respondentCount),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_failed)
            EmptyLine(l10n.interactionRespondentsFailed)
          else if (rows == null)
            // A real spinner here, unlike the card's skeleton: this is a round
            // trip somebody explicitly asked for by opening the sheet, and it
            // can genuinely take a moment on a bad connection. A skeleton would
            // be pretending the data is nearly here.
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CupertinoActivityIndicator()),
            )
          else if (rows.isEmpty)
            EmptyLine(l10n.interactionRespondentsEmpty)
          else ...[
            // One choice with answers needs no filter — every row is in the
            // only bucket there is.
            if (it.choices.where((c) => c.count > 0).length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // Room for FocusableTap's ring, which paints outside its
                // child's bounds and would otherwise be clipped by the scroll
                // view — the same inset the reaction sheet's pill row carries.
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Row(
                  children: [
                    FilterCapsule(
                      label: l10n.interactionFilterAll,
                      count: rows.length,
                      active: selected == null,
                      onTap: () => _select(null),
                    ),
                    for (final c in it.choices)
                      if (c.count > 0) ...[
                        const SizedBox(width: 6),
                        FilterCapsule(
                          label: interactionChoiceLabel(l10n, it.kind, c),
                          count: c.count,
                          active: selected == c.id,
                          onTap: () => _select(c.id),
                        ),
                      ],
                  ],
                ),
              ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: visible.length,
                itemBuilder: (context, i) {
                  final r = visible[i];
                  final label = it.choices
                      .where((c) => c.id == r.choiceId)
                      .map((c) => interactionChoiceLabel(l10n, it.kind, c))
                      .firstOrNull;
                  return _RespondentRow(
                    theme: theme,
                    api: widget.api,
                    user: _userFor(r.userId, r.name),
                    // The name from the row, not from the resolved user. It is
                    // what they were called when they answered, and the card's
                    // preview line shows the same string — two surfaces about
                    // the same answer disagreeing about the person's name would
                    // be worse than either being slightly out of date.
                    name: r.name,
                    time: formatClockTime(r.at),
                    // Only when the filter is off. With one choice selected the
                    // label is already at the top of the sheet, on the pill.
                    choiceLabel: selected == null ? label : null,
                    isMe: r.userId == widget.currentUserId,
                    onOpenProfile: _openProfile,
                  );
                },
              ),
            ),
          ],
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
