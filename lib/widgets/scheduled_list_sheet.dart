import 'dart:async';
import 'dart:math' as math;

import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../backend/chat_api.dart';
import '../data/chat_repository.dart';
import '../data/settings_store.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/family.dart';
import '../models/scheduled_message.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'capture_glyphs.dart' show ViewOnceGlyph;
import 'destructive_sheet.dart';
import 'dust/spoiler_dust.dart';
import 'dust_dissolve.dart';
import 'media_spoiler.dart';
import 'remote_image.dart';
import 'schedule_glyphs.dart';
import 'schedule_message_sheet.dart';
import 'ios_kit.dart';
import 'sheet_kit.dart';
import 'linkified_text.dart';
import '../services/link_opener.dart';
import '../l10n/text_case.dart';

/// Turns one of the repository's schedule error codes into a sentence.
///
/// Shared by this sheet and by the room screen's composer path, so a refusal
/// reads the same wherever it surfaces. The child-guard codes are deliberately
/// NOT handled here: those do not want a sentence, they want the approval sheet,
/// and the caller routes them there before reaching this.
String scheduleErrorSentence(BuildContext context, String code) {
  final l10n = AppLocalizations.of(context);
  return switch (code) {
    'SCHEDULE_OUT_OF_RANGE' => l10n.scheduleErrorOutOfRange,
    'TOO_MANY_SCHEDULED' => l10n.scheduleErrorTooMany,
    'SCHEDULE_NOT_IN_EPHEMERAL' => l10n.scheduleErrorNotInEphemeral,
    'NOT_A_MEMBER' => l10n.scheduleErrorNotMember,
    'UNBLOCK_FIRST' => l10n.scheduleErrorBlocked,
    'MESSAGE_FILTER_BLOCKED' => l10n.messageFilterBlocked,
    // `MESSAGE_FAILED` lands here on purpose. It is what the backend throws
    // when the OTHER person has blocked this one, and it is deliberately
    // indistinguishable from a generic failure — telling someone they have
    // been blocked is exactly what `guardOutgoing` refuses to do.
    _ => l10n.scheduleErrorGeneric,
  };
}

/// Opens the list of this room's queued messages.
///
/// Takes the repository rather than a snapshot, and listens to it: the list is
/// backed by a live Convex subscription, so a message that sends while the
/// sheet is open has to leave it. A snapshot would strand a row the user could
/// then "send now" a second time.
Future<void> showScheduledListSheet(
  BuildContext context, {
  required ChatRepository repo,
  required String roomId,
}) {
  return showAdaptiveSheet<void>(
    context,
    useSafeArea: true,
    builder: (_) => _ScheduledListSheet(repo: repo, roomId: roomId),
  );
}

class _ScheduledListSheet extends StatefulWidget {
  const _ScheduledListSheet({required this.repo, required this.roomId});

  final ChatRepository repo;
  final String roomId;

  @override
  State<_ScheduledListSheet> createState() => _ScheduledListSheetState();
}

/// Two views in one sheet, with its own back button.
///
/// A nested route rather than a footer control, because "how should this be
/// shown to me" is a different question from "what is waiting to go out" and
/// the second is what the sheet is for. Squeezed in underneath the list it was
/// chrome competing with the content; behind a row it is one tap away and the
/// list gets the whole sheet back.
///
/// Not a real `Navigator` route: pushing a second sheet over this one would
/// stack two surfaces and two dismiss gestures for what is a page turn inside
/// one panel.
class _ScheduledListSheetState extends State<_ScheduledListSheet> {
  bool _choosing = false;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    // Bounded and scrollable, like its sibling. The display-choice view is
    // three cards each carrying a drawn preview, which is taller than a small
    // phone — and a bottom sheet does not scroll its own contents, so without
    // this the bottom silently overflows on exactly the devices least able to
    // spare the room. The `ConstrainedBox` is also what keeps this legal inside
    // the desktop popover, which wraps sheet content in a scroll view of its
    // own: an unbounded scrollable inside another one throws.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: sheetFill(theme),
          borderRadius: BorderRadius.circular(sheetRadius(theme)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            // The shared bar, pinned above the scroll. The page turn turns
            // its leading × into a back chevron in place, so the header
            // holds still while the view under it changes.
            SheetBar(
              title: sentenceCaseOf(
                context,
                _choosing ? l10n.scheduledListShowAs : l10n.scheduledListTitle,
              ),
              leading: SheetBackCloseButton(
                back: _choosing,
                onTap: _choosing
                    ? () => setState(() => _choosing = false)
                    : null,
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  20 + MediaQuery.of(context).padding.bottom,
                ),
                child: AnimatedSize(
                  duration: motion.d(theme.motionMed),
                  curve: motion.c(theme.motionEntrance),
                  alignment: Alignment.bottomCenter,
                  child: _choosing
                      ? const _IndicatorView(key: ValueKey('choose'))
                      : _ListView(
                          key: const ValueKey('list'),
                          repo: widget.repo,
                          roomId: widget.roomId,
                          onChooseIndicator: () =>
                              setState(() => _choosing = true),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  const _ListView({
    super.key,
    required this.repo,
    required this.roomId,
    required this.onChooseIndicator,
  });

  final ChatRepository repo;
  final String roomId;
  final VoidCallback onChooseIndicator;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
          Text(
            l10n.scheduledListSubtitle,
            style: groupedFooterStyle(theme),
          ),
          const SizedBox(height: 16),
          // The repository is the ChangeNotifier the subscription writes into,
          // so this is the whole of the sheet's liveness.
          AnimatedBuilder(
            animation: repo,
            builder: (context, _) {
              final rows = repo.scheduledFor(roomId);
              if (rows.isEmpty) return EmptyLine(l10n.scheduledListEmpty);
              // A plain column in the sheet's one scroller, not a capped
              // inner list: the inner list was hard-cut by the footer card
              // with no fade, and the queue is server-capped anyway
              // (TOO_MANY_SCHEDULED), so there is never a long list to
              // virtualise.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _ScheduledRow(
                      key: ValueKey(rows[i].id),
                      repo: repo,
                      message: rows[i],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          // No Cancel under it: the bar's × is the dismiss.
          _ShowAsRow(onTap: onChooseIndicator),
      ],
    );
  }
}

/// The row that opens the display-choice view.
class _ShowAsRow extends StatelessWidget {
  const _ShowAsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final current = SettingsStore.instance.scheduledIndicator;
        // A settings row in a group, like every other sheet's — not a
        // bordered card with its own slider glyph.
        return SheetGroup(
          children: [
            GroupedRow(
              glyph: (ink, size) =>
                  ScheduleSlidersGlyph(color: ink, size: size),
              tone: TileTone.gray,
              title: l10n.scheduledListShowAsRow,
              value: _indicatorLabel(l10n, current),
              onTap: onTap,
            ),
          ],
        );
      },
    );
  }
}

String _indicatorLabel(AppLocalizations l10n, ScheduledIndicator i) =>
    switch (i) {
      ScheduledIndicator.pill => l10n.scheduledIndicatorPill,
      ScheduledIndicator.badge => l10n.scheduledIndicatorBadge,
      ScheduledIndicator.both => l10n.scheduledIndicatorBoth,
    };

String _indicatorSub(AppLocalizations l10n, ScheduledIndicator i) =>
    switch (i) {
      ScheduledIndicator.pill => l10n.scheduledIndicatorPillSub,
      ScheduledIndicator.badge => l10n.scheduledIndicatorBadgeSub,
      ScheduledIndicator.both => l10n.scheduledIndicatorBothSub,
    };

/// The second view: how a room should announce that it is holding messages.
///
/// Every choice carries a drawn miniature of the composer showing exactly what
/// it does. Three words could not carry this — "pill" and "badge" are our
/// names for our own furniture, and the difference that actually matters
/// (the badge is invisible until you start typing) is a thing you have to see.
class _IndicatorView extends StatelessWidget {
  const _IndicatorView({super.key});

  @override
  Widget build(BuildContext context) {
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final current = SettingsStore.instance.scheduledIndicator;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The title and back chevron live in the sheet's bar, above.
            const SizedBox(height: 4),
            for (var i = 0; i < ScheduledIndicator.values.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _IndicatorCard(
                index: i,
                motion: motion,
                indicator: ScheduledIndicator.values[i],
                label: _indicatorLabel(l10n, ScheduledIndicator.values[i]),
                sub: _indicatorSub(l10n, ScheduledIndicator.values[i]),
                active: current == ScheduledIndicator.values[i],
                onTap: () {
                  HapticFeedback.selectionClick();
                  SettingsStore.instance
                      .setScheduledIndicator(ScheduledIndicator.values[i]);
                },
              ),
            ],
            // No Back button down here: the bar's chevron is the way back,
            // and two of them was one too many.
          ],
        );
      },
    );
  }
}

/// One choice, with a picture of what it does.
///
/// The card shape follows `_MotionCard` in `motion_screen.dart` — border
/// thickens and an accent glow appears when active, and a live preview box sits
/// under the words. That screen made the same argument this one does: the
/// difference between the options is visual, so the option has to show it.
class _IndicatorCard extends StatelessWidget {
  const _IndicatorCard({
    required this.index,
    required this.motion,
    required this.indicator,
    required this.label,
    required this.sub,
    required this.active,
    required this.onTap,
  });

  final int index;
  final MotionScope motion;
  final ScheduledIndicator indicator;
  final String label;
  final String sub;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: motion.stagger(theme.motionMed, index, strideMs: 45),
      curve: motion.c(theme.motionEntrance),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(0, (1 - v) * 8),
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: FocusableTap(
        onTap: onTap,
        selected: active,
        semanticLabel: '$label. $sub',
        radius: theme.radiusLg,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: motion.d(theme.motionFast),
            padding: const EdgeInsets.all(14),
            // Borderless, like every grouped block on a sheet; the check is
            // the selection, as in an iOS pick-one list.
            decoration: BoxDecoration(
              color: sheetGroupFill(theme),
              borderRadius: BorderRadius.circular(groupedRadius(theme)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(label, style: groupedTitleStyle(theme)),
                    ),
                    const SizedBox(width: 10),
                    SelectionCheck(picked: active),
                  ],
                ),
                const SizedBox(height: 2),
                Text(sub, style: groupedSubtitleStyle(theme)),
                const SizedBox(height: 12),
                _IndicatorPreview(indicator: indicator),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A miniature of the composer, drawn to scale, showing where this choice puts
/// its mark.
///
/// Drawn rather than screenshotted for the reason `LocationMapPreview` is: a
/// picture would need re-cutting for eleven other themes and would be wrong the
/// day the accent colour changes. This is built from the same tokens the real
/// chrome is, so it cannot drift from what it depicts.
class _IndicatorPreview extends StatelessWidget {
  const _IndicatorPreview({required this.indicator});

  final ScheduledIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      height: 66,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.surfaceSunken,
        borderRadius: BorderRadius.circular(theme.radiusMd),
        border: Border.all(color: theme.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The pill, above the composer, exactly where the real one sits.
            if (indicator.showsPill)
              Align(
                alignment: Alignment.center,
                child: Container(
                  height: 12,
                  width: 78,
                  decoration: BoxDecoration(
                    color: theme.ink.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            if (indicator.showsPill) const SizedBox(height: 7),
            Row(
              children: [
                // The attach button and the text field, greyed — they are
                // scenery, not the subject.
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.surfaceRaised,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.divider),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: theme.surfaceRaised,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.divider),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // The send button, and its badge when this choice has one.
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (indicator.showsBadge)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: theme.surface,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: theme.accent, width: 1.2),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One queued message, and everything that can be done to it.
///
/// The actions are laid out rather than hidden behind an overflow menu: there
/// are four of them, they are all one word, and a queued message is something
/// people come here specifically to act on — a menu would put every one of them
/// two taps away to save a row of chrome.
class _ScheduledRow extends StatefulWidget {
  const _ScheduledRow({
    super.key,
    required this.repo,
    required this.message,
  });

  final ChatRepository repo;
  final ScheduledMessage message;

  @override
  State<_ScheduledRow> createState() => _ScheduledRowState();
}

class _ScheduledRowState extends State<_ScheduledRow>
    with SingleTickerProviderStateMixin {
  /// Set while a mutation for this row is in flight, so a double tap cannot
  /// send the same message twice while the first call is still on the wire.
  bool _busy = false;

  /// Deleting: the row turns to dust, the way a deleted message does in the
  /// chat, and closes up under the cloud.
  bool _burning = false;

  /// Whether the cancel has gone to the server. It goes once the dust has
  /// settled, not before: the subscription drops the row the moment the
  /// server agrees, and a row unmounted mid-burn takes its dust with it.
  bool _cancelSent = false;

  Timer? _closeTimer;
  Timer? _giveBackTimer;

  /// The row's height, closing as the dust lifts.
  late final AnimationController _collapse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );

  @override
  void dispose() {
    // The sheet closed mid-burn: the user still said delete.
    if (_burning && !_cancelSent) {
      widget.repo.cancelScheduledMessage(widget.message.id);
    }
    _closeTimer?.cancel();
    _giveBackTimer?.cancel();
    _collapse.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy || _burning) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showConfirmSheet(
      context,
      headline: l10n.scheduledListDeleteHeadline,
      body: l10n.scheduledListDeleteBody,
      confirmLabel: l10n.scheduledListDelete,
    );
    if (!ok || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _burning = true);
    // Closes up once the front has crossed, under the dust still in the
    // air, as a deleted message does.
    _closeTimer = Timer(
      MediaQuery.disableAnimationsOf(context)
          ? DustDissolve.calmDuration
          : DustDissolve.waveDuration,
      () {
        if (mounted) _collapse.reverse();
      },
    );
  }

  Future<void> _afterBurn() async {
    if (!mounted || _cancelSent) return;
    _cancelSent = true;
    await widget.repo.cancelScheduledMessage(widget.message.id);
    // The subscription normally drops this row a moment from now. If it is
    // still here a while later the cancel did not take (the repository
    // swallows the failure), so the message comes back rather than staying
    // queued behind an invisible row.
    _giveBackTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _burning = false;
        _cancelSent = false;
      });
      _collapse.forward();
    });
  }

  Future<void> _run(Future<String?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final code = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (code == null) return;
    // A child-guard refusal is not a sentence in a snackbar — it is the
    // approval flow, which only the room screen can open. Everything else says
    // what went wrong where the user is looking.
    if (code == kChildApprovalRequired || code == kChildNotAllowed) {
      Navigator.of(context).pop();
      return;
    }
    showAppToast(context, scheduleErrorSentence(context, code));
  }

  Future<void> _changeTime() async {
    final m = widget.message;
    final choice = await showScheduleMessageSheet(
      context,
      mode: ScheduleSheetMode.reschedule,
      preview: m.isPhoto && m.content.isEmpty
          ? AppLocalizations.of(context).attachmentMenuPhotoLabel
          : m.content,
      initial: widget.message.sendAt,
    );
    // Reschedule mode never offers the queue row — we are already looking at
    // the queue — so anything but an instant means the user backed out.
    if (choice is! ScheduleAt || !mounted) return;
    await _run(() => widget.repo.rescheduleMessage(
          widget.message.id,
          sendAt: choice.at.millisecondsSinceEpoch,
        ));
  }

  Future<void> _editText() async {
    final text = await showScheduledEditSheet(
      context,
      initial: widget.message.content,
      // A photo's caption may be taken off entirely; a text message may not
      // be emptied — the server holds the same line.
      allowEmpty: widget.message.isPhoto,
    );
    if (text == null || !mounted) return;
    await _run(() => widget.repo.updateScheduledText(
          widget.message.id,
          text,
          // The message's own mentions and formatting are deliberately NOT
          // carried through. The spans are offsets into the OLD string and the
          // mentions name people the new words may not mention any more — see
          // `scheduledMessages:updateText`. Editing here is plain text; the
          // rich version of this belongs in the composer, which is where the
          // mention picker and format toolbar live.
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final motion = MotionScope.of(context);
    final l10n = AppLocalizations.of(context);
    final m = widget.message;
    final failed = m.hasFailed;
    final radius = groupedRadius(theme);

    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _collapse,
        curve: Curves.easeInOutCubic,
      ),
      alignment: Alignment.topCenter,
      child: DustDissolve(
        active: _burning,
        onDone: _afterBurn,
        seed: m.id.hashCode,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
        child: _card(context, theme, motion, l10n, m, failed),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    AppTheme theme,
    MotionScope motion,
    AppLocalizations l10n,
    ScheduledMessage m,
    bool failed,
  ) {
    return AnimatedOpacity(
      opacity: _busy ? 0.5 : 1,
      duration: motion.d(theme.motionFast),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        // A grouped block like every other sheet's, no outline. A failed
        // send says so in red text and glyph, not with a red border.
        decoration: BoxDecoration(
          color: sheetGroupFill(theme),
          borderRadius: BorderRadius.circular(groupedRadius(theme)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              // Top-aligned: when a long Turkish "when" wraps, the glyph
              // belongs to the first line, not floating between the two.
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  // Centred on the first line's box, which grows with the
                  // reader's text size while the 15pt glyph does not.
                  padding: EdgeInsets.only(
                    top: math.max(
                      0,
                      (_lineHeightOf(context, groupedSubtitleStyle(theme)) -
                              15) /
                          2,
                    ),
                  ),
                  // A clock showing the very time it goes out. A failed send
                  // folds its hands into a "!"; an overdue one, going out
                  // now, spins its minute hand once.
                  child: ScheduleClockGlyph(
                    time: m.sendAt,
                    alert: failed,
                    kickKey: m.isOverdueAt(DateTime.now()),
                    color: failed ? theme.danger : theme.accent,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    sentenceCaseOf(context, _headline(context, l10n, m)),
                    style: groupedSubtitleStyle(theme).copyWith(
                      color: failed ? theme.danger : theme.accent,
                    ),
                    // Two lines: a dated Turkish "when" runs long.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (m.isPhoto)
              _PhotoLine(message: m, api: widget.repo.api)
            else
              ScheduledRichText(
                message: m,
                style: groupedTitleStyle(theme),
                maxLines: 3,
              ),
            if (failed) ...[
              const SizedBox(height: 6),
              Text(
                scheduleErrorSentence(context, m.failedReason ?? ''),
                style: groupedSubtitleStyle(theme),
              ),
            ],
            const SizedBox(height: 6),
            // Four even slots, a drawn glyph over each word: each glyph plays
            // its own one-off kick as it is pressed.
            Row(
              children: [
                _RowAction(
                  label: failed ? l10n.scheduledListRetry : l10n.scheduledListSendNow,
                  glyph: (color, kick) => ScheduleActionGlyph(
                    mark: failed
                        ? ScheduleActionMark.retry
                        : ScheduleActionMark.sendNow,
                    color: color,
                    kickKey: kick,
                  ),
                  onTap: _busy
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          _run(() => widget.repo.sendScheduledNow(m.id));
                        },
                ),
                _RowAction(
                  label: l10n.scheduledListChangeTime,
                  // The row's own time on the face: the press spins the
                  // minute hand once round to it.
                  glyph: (color, kick) => ScheduleClockGlyph(
                    time: m.sendAt,
                    color: color,
                    kickKey: kick,
                  ),
                  onTap: _busy ? null : _changeTime,
                ),
                _RowAction(
                  label: l10n.scheduledListEdit,
                  glyph: (color, kick) => ScheduleActionGlyph(
                    mark: ScheduleActionMark.edit,
                    color: color,
                    kickKey: kick,
                  ),
                  onTap: _busy ? null : _editText,
                ),
                _RowAction(
                  label: l10n.scheduledListDelete,
                  danger: true,
                  glyph: (color, kick) => ScheduleActionGlyph(
                    mark: ScheduleActionMark.delete,
                    color: color,
                    kickKey: kick,
                  ),
                  // Through `_run` like its three siblings. On its own it had
                  // no `_busy` guard, so a double-tap fired two cancels, and no
                  // error path at all. `cancelScheduledMessage` swallows its
                  // own failures and returns null, so this surfaces nothing in
                  // the ordinary case — it is the re-entry guard that matters.
                  // Asked first, like every delete, then the row goes to dust
                  // and only then to the server; see [_burning].
                  onTap: _busy || _burning ? null : _delete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _headline(
    BuildContext context,
    AppLocalizations l10n,
    ScheduledMessage m,
  ) {
    if (m.hasFailed) return l10n.scheduledListFailedTitle;
    // The window between the deadline and the scheduler firing. Says "sending"
    // rather than showing a countdown that has run out — see
    // `ScheduledMessage.isOverdueAt`.
    if (m.isOverdueAt(DateTime.now())) return l10n.scheduledListSending;
    return l10n.scheduleSendsAtSentence(scheduleWhenPhrase(context, m.sendAt));
  }
}

/// A queued message's words as the chat will show them: its bold, italic,
/// strikes, code, links, mentions and spoilers, through the bubble's own
/// [LinkifiedText], capped to a preview's few lines. Links open as they do
/// in the chat; a spoiler peeks under the finger and seals again.
class ScheduledRichText extends StatelessWidget {
  const ScheduledRichText({
    super.key,
    required this.message,
    required this.style,
    required this.maxLines,
  });

  final ScheduledMessage message;
  final TextStyle style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final linkStyle = style.copyWith(
      color: theme.accent,
      decoration: TextDecoration.underline,
      decorationColor: theme.accent.withValues(alpha: 0.7),
    );
    // As on an incoming bubble: weight carries a mention, colour is the
    // accent, and no underline, which stays the link's own signature.
    final mentionStyle = style.copyWith(
      color: theme.accent,
      fontWeight: FontWeight.w600,
    );
    return LinkifiedText(
      text: message.content,
      trimRight: true,
      style: style,
      linkStyle: linkStyle,
      onLinkTap: (url) => LinkOpener.open(context, url),
      mentionHandles: {
        for (final mention in message.mentions)
          mention.userId: mention.username,
      },
      mentionsEveryone: message.mentionsEveryone,
      mentionStyle: mentionStyle,
      selfMentionStyle: mentionStyle,
      formatting: message.formatting,
      codeStyle: theme.codeStyle(style),
      codeBackground: theme.codeBackground(isMine: false),
      codeBorder: theme.codeBorder(isMine: false),
      // Its own key, apart from the message it becomes: peeking here must
      // not open the sent copy's spoiler in the chat.
      spoilerContextId: 'scheduled:${message.id}',
      spoilerDust: theme.spoilerDust(isMine: false),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// One action under a queued message: a drawn glyph over its word, sharing
/// the row's width evenly with its siblings. Pressing it plays the glyph's
/// kick (Reduce Motion: none) before the action runs.
class _RowAction extends StatefulWidget {
  const _RowAction({
    required this.label,
    required this.glyph,
    required this.onTap,
    this.danger = false,
  });

  final String label;

  /// The glyph in [color]; a change of the kick object plays its kick.
  final Widget Function(Color color, Object kick) glyph;
  final VoidCallback? onTap;
  final bool danger;

  @override
  State<_RowAction> createState() => _RowActionState();
}

class _RowActionState extends State<_RowAction> {
  int _presses = 0;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final onTap = widget.onTap;
    final color = onTap == null
        ? theme.inkMuted.withValues(alpha: 0.6)
        : widget.danger
            ? theme.danger
            : theme.accent;
    final text = sentenceCaseOf(context, widget.label);
    return Expanded(
      child: SpringPress(
        onTap: onTap == null
            ? null
            : () {
                setState(() => _presses++);
                onTap();
              },
        scale: PressSpec.scaleSmall,
        semanticLabel: text,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.glyph(color, _presses),
                const SizedBox(height: 3),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.body.copyWith(fontSize: 12.5, color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rewrites a queued message's words. Returns the new text, or null on cancel.
///
/// A plain field rather than the full composer: the composer is bound to the
/// room's mention session and format toolbar, both of which belong to a message
/// being written now. See the note at `_ScheduledRowState._editText`.
Future<String?> showScheduledEditSheet(
  BuildContext context, {
  required String initial,
  bool allowEmpty = false,
}) {
  return showAdaptiveSheet<String>(
    context,
    // Matches its two siblings. Without it, a tall keyboard pushes this sheet
    // up under the status bar.
    useSafeArea: true,
    builder: (_) =>
        _ScheduledEditSheet(initial: initial, allowEmpty: allowEmpty),
  );
}

class _ScheduledEditSheet extends StatefulWidget {
  const _ScheduledEditSheet({required this.initial, this.allowEmpty = false});

  final String initial;

  /// A photo's caption, which may be cleared. Text may not.
  final bool allowEmpty;

  @override
  State<_ScheduledEditSheet> createState() => _ScheduledEditSheetState();
}

class _ScheduledEditSheetState extends State<_ScheduledEditSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial)
      // Caret at the end: an edit is almost always a fix to the tail, and a
      // caret at 0 makes every one of them start with a scroll. The same
      // reasoning `_RoomScreenState._armEdit` gives.
      ..selection = TextSelection.collapsed(offset: widget.initial.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // SheetFrame adds the keyboard's inset, which a bottom sheet outside a
    // Scaffold has to add for itself.
    return SheetFrame(
      title: sentenceCaseOf(context, l10n.scheduleEditTitle),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SheetActionButton(
            label: l10n.scheduleSheetSaveButton,
            onTap: _controller.text.trim().isEmpty && !widget.allowEmpty
                ? null
                : () => Navigator.of(context).pop(_controller.text.trim()),
          ),
        ],
      ),
    );
  }
}

/// One rendered line of [style] at the reader's text size.
double _lineHeightOf(BuildContext context, TextStyle style) =>
    MediaQuery.textScalerOf(context).scale(style.fontSize ?? 15) *
    (style.height ?? 1.2);

/// A queued photo in the list: the picture that will go out, and its caption
/// — or the word "Photo" when it has none. The file is already on the server,
/// so this is the real thing, not a stand-in.
class _PhotoLine extends StatelessWidget {
  const _PhotoLine({required this.message, required this.api});

  final ScheduledMessage message;
  final ChatApi api;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final caption = message.content;
    final picture = RemoteImage(
      storageId: message.mediaStorageId!,
      api: api,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(10),
      decodeWidth: (52 * MediaQuery.devicePixelRatioOf(context)).round(),
    );
    return Row(
      children: [
        SizedBox.square(
          dimension: 52,
          // A spoiler goes out under the dust, so it waits under it too: the
          // chat's own cover, a tap to peek, sealed again next time.
          child: message.mediaSpoiler
              ? MediaSpoilerCover(
                  sigma: 10,
                  dustDensity: SpoilerDust.defaultDensity / 2,
                  borderRadius: BorderRadius.circular(10),
                  child: picture,
                )
              : picture,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: caption.isEmpty
              ? Text(
                  l10n.attachmentMenuPhotoLabel,
                  style: groupedSubtitleStyle(theme),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )
              : ScheduledRichText(
                  message: message,
                  style: groupedTitleStyle(theme),
                  maxLines: 2,
                ),
        ),
        // The composer's own circled "1", flooded: this one is view once.
        if (message.viewOnce) ...[
          const SizedBox(width: 8),
          ViewOnceGlyph(
            color: theme.accent,
            knockout: sheetGroupFill(theme),
            on: 1,
            size: 18,
          ),
        ],
      ],
    );
  }
}
