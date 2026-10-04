import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chat_message.dart';
import '../models/enums.dart';
import '../models/message_interaction.dart';
import '../theme/app_theme.dart';
import '../theme/motion.dart';
import 'message_stamp.dart';

/// Everything a transcript can do to a poll, checklist or event, in one object.
///
/// ## Why a bundle and not six parameters
///
/// Because `buildMessageContent` already takes twenty-odd, threaded through two
/// bubble widgets, and six more would be six edits in three places every time
/// one is added. The same argument [MessageCapabilities] makes one level up:
/// the question at the call site should be "wire the interactions" rather than
/// "which of these six did I forget".
///
/// Every callback carries the MESSAGE ID rather than closing over one, which is
/// what makes this constructible ONCE per room instead of once per bubble. A
/// per-bubble closure set would allocate six of them for every row in a
/// scrolling transcript, most of which are not interactive at all.
///
/// Null anywhere leaves that control absent, and a null [InteractionActions]
/// leaves the card fully legible and completely inert — which is the right
/// state for a preview, a test, and the bubble-style picker's samples.
@immutable
class InteractionActions {
  const InteractionActions({
    this.onRespond,
    this.onRetract,
    this.onClose,
    this.onAddItem,
    this.onRemoveItem,
    this.onShowRespondents,
  });

  /// Nothing wired. The state a preview surface passes, and the default.
  static const none = InteractionActions();

  final void Function(String messageId, String choiceId)? onRespond;
  final void Function(String messageId)? onRetract;
  final void Function(String messageId)? onClose;
  final void Function(String messageId, String label)? onAddItem;
  final void Function(String messageId, String choiceId)? onRemoveItem;
  final void Function(String messageId)? onShowRespondents;
}

/// What to print for one choice.
///
/// The author's own words for a poll option or a checklist item — and the
/// APP's words for an event's three RSVP buttons, whose `label` is a
/// server-owned token (`going` / `maybe` / `no`) rather than anything a person
/// typed. Rendering that token raw would put English on the card in all twelve
/// languages, which is exactly what it did until somebody rendered an event
/// card and looked at it.
///
/// Top-level and shared with [InteractionRespondentsSheet] rather than
/// duplicated, because the card and the sheet name the same choice a moment
/// apart and disagreeing about it would read as two different answers.
///
/// An unrecognised token falls back to the server's own word rather than to
/// nothing, so a newer backend degrades to English instead of to a blank row.
String interactionChoiceLabel(
  AppLocalizations l10n,
  MessageType kind,
  InteractionChoice choice,
) {
  if (kind != MessageType.event) return choice.label;
  return switch (choice.id) {
    'going' => l10n.interactionRsvpGoing,
    'maybe' => l10n.interactionRsvpMaybe,
    'no' => l10n.interactionRsvpNo,
    _ => choice.label,
  };
}

/// A poll, checklist or event in the transcript.
///
/// ## One widget, three cards
///
/// Unlike [MessageType]'s three members — which exist so the compiler forces
/// every dispatch site to answer for each — this is one widget, because the
/// three cards are the same card. A prompt, a header strip, a column of
/// choices, a footer. What differs is the CONTROL on each row (a radio, a
/// checkbox, an RSVP button) and what the footer counts, and both of those are
/// a few lines inside a shared frame. Three widgets would be three copies of
/// the bar geometry, the respondent faces, the closed state and the pending
/// state — and those are exactly the parts that must not drift.
///
/// ## The two-source problem
///
/// [message] and [interaction] arrive INDEPENDENTLY and the message usually
/// lands first: the transcript comes from `messages:list` and the body from
/// `interactions:listForRoom`, deliberately separate so a vote does not rebuild
/// the transcript (see `schema.ts:messageInteractions`). So [interaction] is
/// nullable and null is an ordinary state, not an error — it happens on every
/// first paint, on a cold boot off the disk cache, and on any interaction older
/// than the live window until the page hydrate lands.
///
/// The answer is that the PROMPT never depends on it. `message.content` holds
/// the question, so the card that renders while the body is missing is the real
/// card with its choices not yet drawn — never a spinner, never a blank. That
/// is the whole reason the server puts the question on the message row.
///
/// ## Optimism, deliberately partial
///
/// A tapped control fills at once; the tally does NOT move until the server
/// says it has. See [ChatRepository.respondToInteraction] — a bar that grew and
/// then shrank back would make a dropped vote look exactly like a counted one.
class InteractionBubble extends StatelessWidget {
  const InteractionBubble({
    super.key,
    required this.theme,
    required this.message,
    required this.interaction,
    required this.isMine,
    required this.width,
    required this.radius,
    this.stamp,
    this.actions = InteractionActions.none,
    this.currentUserId,
    this.clock = DateTime.now,
  });

  final AppTheme theme;
  final ChatMessage message;

  /// The body. Null until the interaction subscription (or a page hydrate)
  /// delivers it — see the class header. Never a reason to draw nothing.
  final MessageInteraction? interaction;

  final bool isMine;
  final double width;
  final BorderRadius radius;

  /// The timestamp/receipt block, laid over the card's bottom edge.
  final MessageStamp? stamp;

  /// What this transcript can do to the card. [InteractionActions.none] leaves
  /// it fully legible and completely inert, which is the right state for a
  /// preview and the same treatment `LocationBubble` gives `onStopSharing`.
  final InteractionActions actions;

  /// The reader, used for exactly one decision: whether to offer CLOSE and the
  /// remove-item controls.
  ///
  /// Derived here rather than passed as a resolved boolean because the rule is
  /// one comparison against a field this widget already holds, and a boolean
  /// would be a second copy of it for a caller to get wrong. It is deliberately
  /// narrower than the server's rule — see
  /// `ChatRepository.canAdministerInteraction`.
  final String? currentUserId;

  /// Injected for the same reason [LocationBubble] injects one: an event card
  /// says whether it has already happened, and a test that could not move the
  /// clock could not assert the transition.
  final DateTime Function() clock;

  /// Whether to offer the author-only controls. False while [interaction] is
  /// still in flight — there is nothing to close yet, and a control that
  /// appeared a moment after the card did would move everything under it.
  bool get _canAdminister {
    final me = currentUserId;
    final it = interaction;
    return me != null && it != null && it.createdBy == me;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final it = interaction;
    final id = message.id;
    // Bound once here rather than per row. The card is rebuilt on every tally
    // change, and a transcript's worth of per-row closures is exactly the sort
    // of allocation a scrolling list should not be making.
    final respond = actions.onRespond == null
        ? null
        : (String choiceId) => actions.onRespond!(id, choiceId);
    final showRespondents = actions.onShowRespondents == null ||
            // Never on an anonymous poll: the server refuses it, and a tap whose
            // only possible outcome is a refusal is worse than no tap at all.
            it?.anonymous == true
        ? null
        : () => actions.onShowRespondents!(id);

    return Container(
      width: width,
      decoration: BoxDecoration(
        // The card's own ground, not the bubble decoration. An interactive
        // message is a piece of furniture with controls on it — filling it with
        // the outgoing accent would put a filled bar and a filled checkbox on a
        // filled ground, and none of the three would read. So mine and theirs
        // share one surface, and the row's alignment says which is which,
        // exactly as it does for a photo or a map card.
        color: theme.surfaceSunken,
        borderRadius: radius,
        border: Border.all(color: theme.divider, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(theme: theme, message: message, interaction: it, l10n: l10n),
          const SizedBox(height: 9),
          // The prompt, from the MESSAGE — see the class header. This is the
          // line that makes a body-less card still say what it asked.
          Text(
            message.content,
            style: theme.bodyEmph.copyWith(color: theme.ink, height: 1.25),
          ),
          if (it != null && it.kind == MessageType.event) ...[
            const SizedBox(height: 8),
            _EventWhen(theme: theme, interaction: it, l10n: l10n, now: clock()),
          ],
          const SizedBox(height: 11),
          if (it == null)
            // The body has not landed. A row of muted placeholders rather than
            // a spinner: this resolves in a frame or two on a live room, and a
            // spinner that appears and vanishes that fast is a flicker rather
            // than information. It also keeps the card's height roughly right,
            // so the transcript does not jump when the choices arrive.
            _ChoicesSkeleton(theme: theme)
          else
            _Choices(
              theme: theme,
              interaction: it,
              l10n: l10n,
              onRespond: respond,
              onRemoveItem: _canAdminister && actions.onRemoveItem != null
                  ? (choiceId) => actions.onRemoveItem!(id, choiceId)
                  : null,
              onShowRespondents: showRespondents,
            ),
          if (it != null && it.quiz && it.correctChoiceId != null)
            _QuizVerdict(theme: theme, interaction: it, l10n: l10n),
          if (it != null && it.kind == MessageType.checklist && !it.isClosed)
            _AddItemRow(
              theme: theme,
              l10n: l10n,
              // The author's switch, enforced server-side too. `isMine` is not
              // consulted: the author is the one who set the flag, so a list
              // that allows shared adding allows it to them as well.
              enabled: it.othersMayAdd || isMine,
              onAdd: actions.onAddItem == null
                  ? null
                  : (label) => actions.onAddItem!(id, label),
            ),
          const SizedBox(height: 8),
          _Footer(
            theme: theme,
            interaction: it,
            l10n: l10n,
            stamp: stamp,
            onRetract: actions.onRetract == null
                ? null
                : () => actions.onRetract!(id),
            onClose: _canAdminister && actions.onClose != null
                ? () => actions.onClose!(id)
                : null,
            onShowRespondents: showRespondents,
          ),
        ],
      ),
    );
  }
}

/// The strip above the prompt: what kind of thing this is, and the two or three
/// facts about it that change how an answer behaves.
///
/// Every badge here is load-bearing rather than decorative, which is the rule
/// for what earns a place: ANONYMOUS changes who will see your name, MULTIPLE
/// changes how many you may pick, QUIZ changes whether you may change your
/// mind, and CLOSED changes whether you may answer at all. A badge that only
/// restated the icon would be noise on a card that is already busy.
class _Header extends StatelessWidget {
  const _Header({
    required this.theme,
    required this.message,
    required this.interaction,
    required this.l10n,
  });

  final AppTheme theme;
  final ChatMessage message;
  final MessageInteraction? interaction;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final it = interaction;
    // Read off the MESSAGE, not the body, so the strip is right on the first
    // frame — before the interaction has landed there is still a poll icon to
    // draw, because the message already says it is a poll.
    final kind = message.type;
    final (icon, label) = switch (kind) {
      MessageType.checklist => (
          CupertinoIcons.checkmark_square,
          l10n.interactionKindChecklist,
        ),
      MessageType.event => (
          CupertinoIcons.calendar,
          l10n.interactionKindEvent,
        ),
      // Everything else reaching this widget is a poll — `buildMessageContent`
      // routes only the three interactive types here, and the two above are
      // named. A quiz is a poll wearing a badge, not a fourth kind.
      _ => (
          CupertinoIcons.chart_bar_alt_fill,
          it?.quiz == true ? l10n.interactionKindQuiz : l10n.interactionKindPoll,
        ),
    };

    return Row(
      children: [
        Icon(icon, size: 14, color: theme.accent),
        const SizedBox(width: 6),
        Text(
          // Sentence case, as stored in the ARB — never `toUpperCase()`d
          // (Dart's invariant mapping turns Turkish "i" into "I", not "İ") —
          // and on the body face, never the theme's tracked mono.
          label,
          style: _meta(theme).copyWith(
            color: theme.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (it != null) ...[
          if (it.anonymous)
            _Badge(theme: theme, text: l10n.interactionBadgeAnonymous),
          if (it.multiple)
            _Badge(theme: theme, text: l10n.interactionBadgeMultiple),
          if (it.isClosed)
            _Badge(
              theme: theme,
              text: l10n.interactionBadgeClosed,
              emphatic: true,
            ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.theme,
    required this.text,
    this.emphatic = false,
  });

  final AppTheme theme;
  final String text;

  /// CLOSED reads against the accent rather than the muted ground, because it
  /// is the one badge that says a control the reader can see will not work.
  final bool emphatic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: emphatic ? theme.accent : theme.surface,
          borderRadius: BorderRadius.circular(theme.radiusSm),
        ),
        child: Text(
          // Sentence case from the ARB — see the note in [_Header].
          text,
          style: _meta(theme).copyWith(
            color: emphatic ? theme.accentInk : theme.inkMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// When and where, on an event card.
///
/// Renders the date in words rather than as a stamp, because this is the one
/// line somebody reads to decide whether they can come — and a bare
/// "26/08 20:00" makes them work out what day of the week that is.
class _EventWhen extends StatelessWidget {
  const _EventWhen({
    required this.theme,
    required this.interaction,
    required this.l10n,
    required this.now,
  });

  final AppTheme theme;
  final MessageInteraction interaction;
  final AppLocalizations l10n;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final start = interaction.startsAt;
    if (start == null) return const SizedBox.shrink();
    final past = start.isBefore(now);
    final when = eventWhenLine(
      start: start,
      end: interaction.endsAt,
      l: MaterialLocalizations.of(context),
      use24Hour: MediaQuery.alwaysUse24HourFormatOf(context),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              CupertinoIcons.clock,
              size: 13,
              // A past event is dimmed rather than hidden or struck through.
              // The card stays in the transcript forever and the RSVPs on it
              // are a record of who came; saying "this already happened" is
              // information, and taking the line away would remove the only
              // thing that dates it.
              color: past ? theme.inkMuted : theme.inkSoft,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                past ? l10n.interactionEventPast(when) : when,
                style: _meta(theme).copyWith(
                  color: past ? theme.inkMuted : theme.inkSoft,
                ),
              ),
            ),
          ],
        ),
        if ((interaction.place ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(CupertinoIcons.placemark, size: 13, color: theme.inkSoft),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  interaction.place!,
                  style: _meta(theme).copyWith(color: theme.inkSoft),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One line naming when an event starts, and when it ends if it says.
///
/// ## Why the date is not an ARB message
///
/// Because the ORDER of the parts is a property of the language, not of this
/// sentence, and `MaterialLocalizations` already knows it for all twelve
/// locales through `GlobalMaterialLocalizations`. An ARB string would need one
/// message per shape (start only, same-day range, cross-day range) times
/// twelve translators guessing at date order — and a translator who put the
/// month first in a locale that puts the day first would produce a card that
/// is wrong rather than merely awkward.
///
/// So this composes ALREADY-FORMATTED parts with separators that are the same
/// in every language. The only thing it decides is which parts there are.
///
/// [l] is passed rather than read from a context so the shape can be asserted
/// without a widget tree — `const DefaultMaterialLocalizations()` is
/// constructible, which is what makes this a plain unit test.
///
/// [use24Hour] comes from `MediaQuery.alwaysUse24HourFormatOf`, i.e. the
/// device's own clock setting, and not from the locale: somebody in a 12-hour
/// locale who has switched their phone to 24-hour means it.
String eventWhenLine({
  required DateTime start,
  DateTime? end,
  required MaterialLocalizations l,
  required bool use24Hour,
}) {
  String time(DateTime d) => l.formatTimeOfDay(
        TimeOfDay.fromDateTime(d),
        alwaysUse24HourFormat: use24Hour,
      );
  final date = l.formatMediumDate(start);
  final from = time(start);
  if (end == null) return '$date · $from';
  // Same day: one date and a range. Different days get both dates, because
  // "20:00 – 02:00" on one line is a four-hour party or a thirty-hour one and
  // nothing on the card would say which.
  final sameDay = start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) return '$date · $from – ${time(end)}';
  return '$date $from – ${l.formatMediumDate(end)} ${time(end)}';
}

/// What a card draws in place of its choices while the body is in flight.
///
/// Three muted bars at the heights real rows land at, so the transcript's
/// layout is approximately right before the real thing arrives and the list
/// does not lurch. No animation: this is on screen for a frame or two on a
/// live room, and a shimmer that fast reads as a glitch.
class _ChoicesSkeleton extends StatelessWidget {
  const _ChoicesSkeleton({required this.theme});

  final AppTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Container(
              height: 30,
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(theme.radiusSm),
              ),
            ),
          ),
      ],
    );
  }
}

/// The column of answerable rows.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.theme,
    required this.interaction,
    required this.l10n,
    this.onRespond,
    this.onRemoveItem,
    this.onShowRespondents,
  });

  final AppTheme theme;
  final MessageInteraction interaction;
  final AppLocalizations l10n;
  final void Function(String choiceId)? onRespond;
  final void Function(String choiceId)? onRemoveItem;
  final VoidCallback? onShowRespondents;

  @override
  Widget build(BuildContext context) {
    final it = interaction;
    return Column(
      children: [
        for (final choice in it.choices)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _ChoiceRow(
              theme: theme,
              interaction: it,
              choice: choice,
              l10n: l10n,
              onRespond: onRespond,
              onRemove: onRemoveItem,
              onShowRespondents: onShowRespondents,
            ),
          ),
      ],
    );
  }
}

/// One option, item or RSVP button.
///
/// ## Why the bar is a background and not a widget beside the label
///
/// The fill is painted UNDER the row's own contents, so the label sits on top
/// of it and the row's height is set by its text rather than by the bar. A bar
/// laid out beside the label would take width from it, and a poll option is the
/// one string on this card that must never be truncated to make room for
/// chrome — the whole message is what the options say.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.theme,
    required this.interaction,
    required this.choice,
    required this.l10n,
    this.onRespond,
    this.onRemove,
    this.onShowRespondents,
  });

  final AppTheme theme;
  final MessageInteraction interaction;
  final InteractionChoice choice;
  final AppLocalizations l10n;
  final void Function(String choiceId)? onRespond;
  final void Function(String choiceId)? onRemove;
  final VoidCallback? onShowRespondents;

  @override
  Widget build(BuildContext context) {
    final it = interaction;
    final motion = MotionScope.of(context);
    final chosen = it.myChoiceIds.contains(choice.id);
    final pending = it.pendingChoiceIds.contains(choice.id);
    // Filled the instant it is tapped, before the server has agreed — the
    // partial optimism the class header describes. `chosen != pending` rather
    // than `chosen || pending`, because a pending tap on a choice you already
    // hold is a RETRACTION, and drawing it filled would show the opposite of
    // what is about to happen.
    final selected = pending ? !chosen : chosen;

    // A quiz reveals its marks once this reader has answered (or it closes),
    // which is exactly when the server starts sending `correctChoiceId`.
    final correct = it.correctChoiceId;
    final isRight = correct != null && correct == choice.id;
    final isWrongPick = correct != null && chosen && !isRight;

    final fraction = it.fractionOf(choice);
    // A checklist's row is done or not; there is no proportion to draw, and a
    // bar that filled to 100% behind a ticked item would read as a progress
    // bar for that one task.
    final showsBar = it.kind == MessageType.poll;

    final markColor = isRight
        ? theme.success
        : isWrongPick
            ? theme.danger
            : theme.accent;

    final row = Stack(
      children: [
        if (showsBar)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radiusSm),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
                  duration: motion.d(theme.motionMed),
                  curve: motion.c(theme.motionCurve),
                  builder: (context, value, _) => FractionallySizedBox(
                    widthFactor: value,
                    child: Container(
                      color: markColor.withValues(
                        // Deliberately faint. This is a background a label has
                        // to stay readable on in both themes, and a bar at full
                        // accent would need its own foreground colour — which
                        // would then have to change halfway across the row as
                        // the fill passes under the text.
                        alpha: isRight ? 0.26 : 0.16,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            children: [
              _Control(
                theme: theme,
                kind: it.kind,
                multiple: it.multiple,
                selected: selected,
                color: markColor,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      interactionChoiceLabel(l10n, it.kind, choice),
                      style: theme.body.copyWith(
                        color: theme.ink,
                        height: 1.2,
                        // A ticked checklist item is struck through — the one
                        // place this card uses a text decoration, because a
                        // checklist's whole affordance is seeing what is left.
                        // A poll option is never struck: an option nobody
                        // picked is not "done".
                        //
                        // `none` rather than null, and the colour conditional
                        // with it: an unset `decoration` INHERITS one, so the
                        // pair as it stood meant "whatever is inherited, drawn
                        // in inkMuted". Harmless here, where this card is
                        // always inside a Material that supplies a clean
                        // style — but it is the exact shape that painted the
                        // drag chrome's file names with a red underline, and
                        // it costs nothing to close.
                        decoration: it.kind == MessageType.checklist &&
                                choice.count > 0
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor:
                            it.kind == MessageType.checklist && choice.count > 0
                                ? theme.inkMuted
                                : null,
                      ),
                    ),
                    if (choice.respondents.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      _RespondentLine(
                        theme: theme,
                        choice: choice,
                        l10n: l10n,
                        onTap: onShowRespondents,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (showsBar)
                Text(
                  l10n.interactionPercent((fraction * 100).round()),
                  style: _meta(theme).copyWith(
                    color: theme.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (onRemove != null) ...[
                const SizedBox(width: 4),
                FocusableTap(
                  onTap: () => onRemove!(choice.id),
                  radius: theme.radiusSm,
                  semanticLabel: l10n.interactionRemoveItem(
                      interactionChoiceLabel(l10n, it.kind, choice)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onRemove!(choice.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Icon(
                        CupertinoIcons.minus_circle,
                        size: 15,
                        color: theme.inkMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final answerable = onRespond != null && !it.isClosed && !_spent();
    return FocusableTap(
      onTap: answerable ? () => onRespond!(choice.id) : null,
      enabled: answerable,
      radius: theme.radiusSm,
      selected: selected,
      semanticLabel: _semanticLabel(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: answerable
            ? () {
                HapticFeedback.selectionClick();
                onRespond!(choice.id);
              }
            : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(theme.radiusSm),
            border: Border.all(
              color: selected ? markColor : theme.divider,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: row,
        ),
      ),
    );
  }

  /// Whether this reader's one answer is already used up.
  ///
  /// Only a quiz spends one: the server refuses a second answer there, so the
  /// row must stop offering to take it. Every other kind toggles, which is what
  /// makes the same control mean both "vote" and "take it back".
  bool _spent() => interaction.quiz && interaction.hasAnswered;

  String _semanticLabel() {
    final n = choice.count;
    return interaction.kind == MessageType.checklist
        ? interactionChoiceLabel(l10n, interaction.kind, choice)
        // Argument order is ALPHABETICAL by placeholder name, not the order the
        // placeholders appear in the string: `count` before `label`. That is
        // how `flutter gen-l10n` emits every multi-placeholder method, and
        // getting it backwards here compiles fine whenever both happen to be
        // strings — so the two are deliberately typed differently.
        : l10n.interactionChoiceSemantics(
            n, interactionChoiceLabel(l10n, interaction.kind, choice));
  }
}

/// The radio, checkbox or RSVP mark at the head of a row.
///
/// Shape carries the rule, which is the point of drawing it at all: a circle
/// means "one of these", a square means "any of these", and a reader who has
/// used any other app already knows that. It is why [MessageInteraction.multiple]
/// changes the glyph rather than only the behaviour — a poll that silently
/// accepted a second vote from a control shaped like a radio button would be
/// the app lying about its own rules.
class _Control extends StatelessWidget {
  const _Control({
    required this.theme,
    required this.kind,
    required this.multiple,
    required this.selected,
    required this.color,
  });

  final AppTheme theme;
  final MessageType kind;
  final bool multiple;
  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    // A checklist is always a square: ticking one item says nothing about the
    // others, which is exactly what `multiple` means on a poll.
    final square = kind == MessageType.checklist || multiple;
    return AnimatedContainer(
      duration: motion.d(theme.motionFast),
      curve: motion.c(theme.motionCurve),
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius:
            BorderRadius.circular(square ? theme.radiusSm * 0.6 : 9),
        border: Border.all(
          color: selected ? color : theme.inkMuted.withValues(alpha: 0.5),
          width: 1.6,
        ),
      ),
      child: selected
          ? Icon(CupertinoIcons.check_mark, size: 12, color: theme.accentInk)
          : null,
    );
  }
}

/// "alice, bob +3" under a choice.
///
/// The list is a PREVIEW — the server caps it, so `+N` is a real count of
/// people this line does not name rather than a rendering shortcut. Empty on an
/// anonymous poll, where the names were never written and there is nothing
/// behind the tap either.
class _RespondentLine extends StatelessWidget {
  const _RespondentLine({
    required this.theme,
    required this.choice,
    required this.l10n,
    this.onTap,
  });

  final AppTheme theme;
  final InteractionChoice choice;
  final AppLocalizations l10n;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final names = choice.respondents.map((r) => r.name).join(', ');
    final hidden = choice.hiddenCount;
    // Alphabetical argument order again — `count` then `names`. See the note in
    // [_ChoiceRow._semanticLabel].
    final text = hidden > 0 ? l10n.interactionAndMore(hidden, names) : names;
    final line = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _meta(theme).copyWith(color: theme.inkMuted),
    );
    if (onTap == null) return line;
    return FocusableTap(
      onTap: onTap,
      radius: theme.radiusSm,
      semanticLabel: l10n.interactionSeeWhoAnswered,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: line,
      ),
    );
  }
}

/// A quiz's verdict, once its answer is due.
///
/// Rendered only when `correctChoiceId` is non-null, which is precisely when
/// the server decided this reader has earned it — they answered, or the quiz
/// was closed. Null is not "no answer"; a quiz always has one, and the field's
/// absence is the withholding itself (see `sanitizeInteraction`). So this
/// widget needs no rule of its own about when to appear: the data's presence IS
/// the rule, and there is no second copy of it to drift.
///
/// A reader who never answered a closed quiz sees the answer with no verdict,
/// which is the honest rendering — they got nothing wrong, they just did not
/// play.
class _QuizVerdict extends StatelessWidget {
  const _QuizVerdict({
    required this.theme,
    required this.interaction,
    required this.l10n,
  });

  final AppTheme theme;
  final MessageInteraction interaction;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final it = interaction;
    final answered = it.hasAnswered;
    final right = answered && it.myChoiceIds.contains(it.correctChoiceId);
    final note = it.explanation ?? '';
    final tone = !answered
        ? theme.inkMuted
        : right
            ? theme.success
            : theme.danger;

    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            !answered
                ? CupertinoIcons.info_circle
                : right
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.xmark_seal_fill,
            size: 14,
            color: tone,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (answered)
                  Text(
                    right ? l10n.interactionQuizRight : l10n.interactionQuizWrong,
                    style: _meta(theme).copyWith(
                      color: tone,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (note.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: answered ? 2 : 0),
                    child: Text(
                      note,
                      style: _meta(theme).copyWith(color: theme.inkSoft),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The composer for a new checklist item.
///
/// Inline rather than behind a sheet, because adding three things to a list is
/// three taps and a sheet would make it nine. Clears itself on submit and keeps
/// focus, so the second item is typed straight after the first.
class _AddItemRow extends StatefulWidget {
  const _AddItemRow({
    required this.theme,
    required this.l10n,
    required this.enabled,
    this.onAdd,
  });

  final AppTheme theme;
  final AppLocalizations l10n;
  final bool enabled;
  final void Function(String label)? onAdd;

  @override
  State<_AddItemRow> createState() => _AddItemRowState();
}

class _AddItemRowState extends State<_AddItemRow> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onAdd?.call(text);
    _controller.clear();
    // Kept, deliberately. The common case is adding several items at once, and
    // a field that dismissed the keyboard after each one would make the second
    // item cost a tap the first did not.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    if (!widget.enabled || widget.onAdd == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(CupertinoIcons.add, size: 15, color: theme.inkMuted),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              style: theme.body.copyWith(color: theme.ink),
              cursorColor: theme.accent,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: widget.l10n.interactionAddItemHint,
                hintStyle: theme.body.copyWith(color: theme.inkMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The line under the choices: how many answered, and what this reader may
/// still do about it.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.theme,
    required this.interaction,
    required this.l10n,
    this.stamp,
    this.onRetract,
    this.onClose,
    this.onShowRespondents,
  });

  final AppTheme theme;
  final MessageInteraction? interaction;
  final AppLocalizations l10n;
  final MessageStamp? stamp;
  final VoidCallback? onRetract;
  final VoidCallback? onClose;
  final VoidCallback? onShowRespondents;

  @override
  Widget build(BuildContext context) {
    final it = interaction;
    final actions = <Widget>[];

    if (it != null) {
      // Only where all three are true: the poll allows retraction, this reader
      // has something to retract, and it is still open. Any one of them false
      // and the control is absent rather than dimmed — a dimmed control is a
      // question ("why not?") a footer has no room to answer.
      if (onRetract != null &&
          it.hasAnswered &&
          !it.isClosed &&
          !it.quiz &&
          it.kind != MessageType.checklist) {
        actions.add(_action(l10n.interactionRetract, onRetract!));
      }
      if (onClose != null && !it.isClosed) {
        actions.add(_action(l10n.interactionClose, onClose!));
      }
      if (onShowRespondents != null && !it.anonymous && it.respondentCount > 0) {
        actions.add(_action(l10n.interactionSeeWhoAnswered, onShowRespondents!));
      }
    }

    // TWO rows, not one, and this is a fix rather than a preference. All three
    // actions can be live at once on the author's own open poll — RETRACT,
    // CLOSE and SEE WHO ANSWERED — and beside a count and a timestamp that is
    // more words than 280pt holds. As a single `Row` it overflowed by 22
    // pixels, which no test caught: a `Row` reports overflow by painting a
    // stripe, not by failing layout, so the widget tests were green and the
    // card was broken. It turned up the first time anybody rendered one and
    // looked at it.
    //
    // The count and the stamp keep the top line because they are the two
    // things that are always there. The actions go beneath in a `Wrap`, which
    // takes a second line only when it needs one — so the ordinary card, with
    // no actions at all, is exactly the single row it always was.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (it != null)
              Flexible(
                child: Text(
                  _countLine(it),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _meta(theme).copyWith(color: theme.inkMuted),
                ),
              ),
            const Spacer(),
            // The stamp rides in the footer's own row rather than being laid
            // over the card like a photo's. There is text along this edge to
            // collide with, and a lozenge floating over a percentage is the
            // sort of overlap that only looks fine on the one string it was
            // checked against.
            if (stamp != null)
              KeyedSubtree(key: kVisibleStampKey, child: stamp!),
          ],
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Wrap(spacing: 14, runSpacing: 6, children: actions),
          ),
      ],
    );
  }

  String _countLine(MessageInteraction it) {
    if (it.kind == MessageType.checklist) {
      return l10n.interactionChecklistProgress(it.doneCount, it.choices.length);
    }
    if (it.respondentCount == 0) {
      return it.isClosed
          ? l10n.interactionNoAnswers
          : l10n.interactionBeFirst;
    }
    final base = it.kind == MessageType.event
        ? l10n.interactionRsvpCount(it.respondentCount)
        : l10n.interactionVoteCount(it.respondentCount);
    return it.isClosed ? l10n.interactionFinalResults(base) : base;
  }

  Widget _action(String label, VoidCallback onTap) => FocusableTap(
        onTap: onTap,
        radius: theme.radiusSm,
        semanticLabel: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Text(
            label,
            style: _meta(theme).copyWith(
              color: theme.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

/// Meta text on a poll/checklist/event card — badges, percentages, the
/// "who answered" line, times and places: the body face at 13 with tabular
/// figures, never the theme's tracked mono or caption slot.
TextStyle _meta(AppTheme theme) => theme.bodySoft.copyWith(
      fontSize: 13,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
