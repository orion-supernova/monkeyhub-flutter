import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import 'schedule_message_sheet.dart';
import 'sheet_buttons.dart';
import 'ios_kit.dart' show groupedRadius;
import 'labeled_field.dart' show fieldDecoration;
import 'meta_text.dart';
import 'sheet_kit.dart'
    show SheetHandle, sheetFill, sheetGroupFill, sheetTopRadius;
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
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(sheetTopRadius(theme)),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: SingleChildScrollView(
          child: AnimatedSize(
            duration: motion.d(theme.motionMed),
            curve: motion.c(theme.motionEntrance),
            alignment: Alignment.bottomCenter,
            child: _choosing
                ? _IndicatorView(
                    key: const ValueKey('choose'),
                    onBack: () => setState(() => _choosing = false),
                  )
                : _ListView(
                    key: const ValueKey('list'),
                    repo: widget.repo,
                    roomId: widget.roomId,
                    onChooseIndicator: () => setState(() => _choosing = true),
                  ),
          ),
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
          const SheetHandle(),
          Text(
            sentenceCaseOf(context, l10n.scheduledListTitle),
            textAlign: TextAlign.center,
            style: theme.bodyEmph.copyWith(fontSize: 17, color: theme.ink),
          ),
          const SizedBox(height: 8),
          Text(l10n.scheduledListSubtitle, style: theme.bodySoft),
          const SizedBox(height: 16),
          // The repository is the ChangeNotifier the subscription writes into,
          // so this is the whole of the sheet's liveness.
          AnimatedBuilder(
            animation: repo,
            builder: (context, _) {
              final rows = repo.scheduledFor(roomId);
              if (rows.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    l10n.scheduledListEmpty,
                    textAlign: TextAlign.center,
                    style: theme.bodySoft,
                  ),
                );
              }
              return ConstrainedBox(
                // Bounded so a long list scrolls inside the sheet rather than
                // pushing the buttons off the bottom of a short window. Sized
                // against the viewport, not a constant, because the desktop
                // popover form is much shorter than a phone sheet.
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ScheduledRow(
                    key: ValueKey(rows[i].id),
                    repo: repo,
                    message: rows[i],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          _ShowAsRow(onTap: onChooseIndicator),
          const SizedBox(height: 14),
          SheetSecondaryButton(
            label: l10n.destructiveSheetCancelButtonLabel,
            color: theme.inkMuted,
            onTap: () => Navigator.of(context).pop(),
          ),
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
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final current = SettingsStore.instance.scheduledIndicator;
        return FocusableTap(
          onTap: onTap,
          semanticLabel:
              '${l10n.scheduledListShowAsRow}, ${_indicatorLabel(l10n, current)}',
          radius: theme.radiusMd,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: theme.surfaceRaised,
                borderRadius: BorderRadius.circular(theme.radiusMd),
                border: Border.all(color: theme.divider),
              ),
              child: Row(
                children: [
                  Icon(CupertinoIcons.slider_horizontal_3, size: 16, color: theme.inkSoft),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.scheduledListShowAsRow,
                      style: theme.body.copyWith(color: theme.ink),
                    ),
                  ),
                  Text(
                    _indicatorLabel(l10n, current),
                    style: metaText(theme).copyWith(color: theme.accent),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    size: 15,
                    color: theme.inkMuted,
                  ),
                ],
              ),
            ),
          ),
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
  const _IndicatorView({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
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
            const SheetHandle(),
            // The sheet's own back affordance. Left-aligned with the title
            // centred on it, so the header reads as a navigation bar rather
            // than as a button that happens to sit above a title.
            Row(
              children: [
                _BackButton(onTap: onBack),
                Expanded(
                  child: Text(
                    sentenceCaseOf(context, l10n.scheduledListShowAs),
                    style: theme.bodyEmph.copyWith(
                      fontSize: 17,
                      color: theme.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Balances the back button so the title is optically centred.
                const SizedBox(width: 36),
              ],
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            SheetSecondaryButton(
              label: l10n.scheduledBack,
              color: theme.inkSoft,
              onTap: onBack,
            ),
          ],
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.circle,
      semanticLabel: AppLocalizations.of(context).scheduledBack,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 28,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Icon(CupertinoIcons.chevron_back, size: 22, color: theme.accent),
          ),
        ),
      ),
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
            decoration: BoxDecoration(
              color: sheetGroupFill(theme),
              borderRadius: BorderRadius.circular(groupedRadius(theme)),
              border: Border.all(
                color: active ? theme.accent : theme.ink.withValues(alpha: 0),
                // Constant width across states: switching between 1 and 1.6
                // shifts the card's contents by 0.6px on every toggle, which
                // reads as a twitch. The room-info segments make the same note.
                width: 1.6,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: labelText(
                        theme,
                        color: active ? theme.accent : theme.ink,
                      ),
                    ),
                    const Spacer(),
                    _SelectionDot(active: active, motion: motion),
                  ],
                ),
                const SizedBox(height: 6),
                Text(sub, style: metaText(theme)),
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

class _SelectionDot extends StatelessWidget {
  const _SelectionDot({required this.active, required this.motion});

  final bool active;
  final MotionScope motion;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return SizedBox(
      width: 18,
      height: 18,
      child: AnimatedScale(
        scale: active ? 1 : 0.4,
        duration: motion.d(theme.motionFast),
        curve: motion.c(Curves.easeOutBack),
        child: AnimatedOpacity(
          opacity: active ? 1 : 0,
          // Overshoot drives the scale only — easeOutBack on a fade asserts.
          duration: motion.d(theme.motionFast),
          curve: motion.c(theme.motionEntrance),
          child: Container(
            decoration:
                BoxDecoration(color: theme.accent, shape: BoxShape.circle),
            child: Icon(CupertinoIcons.checkmark_alt, size: 12, color: theme.accentInk),
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

class _ScheduledRowState extends State<_ScheduledRow> {
  /// Set while a mutation for this row is in flight, so a double tap cannot
  /// send the same message twice while the first call is still on the wire.
  bool _busy = false;

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
    final choice = await showScheduleMessageSheet(
      context,
      mode: ScheduleSheetMode.reschedule,
      preview: widget.message.content,
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

    return AnimatedOpacity(
      opacity: _busy ? 0.5 : 1,
      duration: motion.d(theme.motionFast),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: theme.surfaceRaised,
          borderRadius: BorderRadius.circular(theme.radiusMd),
          border: Border.all(
            color: failed
                ? theme.danger.withValues(alpha: 0.55)
                : theme.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  failed ? CupertinoIcons.exclamationmark_circle : CupertinoIcons.clock,
                  size: 13,
                  color: failed ? theme.danger : theme.accent,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _headline(context, l10n, m),
                    style: metaText(theme).copyWith(
                      color: failed ? theme.danger : theme.accent,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              m.content,
              style: theme.body.copyWith(color: theme.ink),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            if (failed) ...[
              const SizedBox(height: 6),
              Text(
                scheduleErrorSentence(context, m.failedReason ?? ''),
                style: theme.bodySoft,
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              children: [
                _RowAction(
                  label: failed ? l10n.scheduledListRetry : l10n.scheduledListSendNow,
                  onTap: _busy
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          _run(() => widget.repo.sendScheduledNow(m.id));
                        },
                ),
                _RowAction(
                  label: l10n.scheduledListChangeTime,
                  onTap: _busy ? null : _changeTime,
                ),
                _RowAction(
                  label: l10n.scheduledListEdit,
                  onTap: _busy ? null : _editText,
                ),
                _RowAction(
                  label: l10n.scheduledListDelete,
                  danger: true,
                  // Through `_run` like its three siblings. On its own it had
                  // no `_busy` guard, so a double-tap fired two cancels, and no
                  // error path at all. `cancelScheduledMessage` swallows its
                  // own failures and returns null, so this surfaces nothing in
                  // the ordinary case — it is the re-entry guard that matters.
                  onTap: _busy
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          _run(() async {
                            await widget.repo.cancelScheduledMessage(m.id);
                            return null;
                          });
                        },
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

/// One word under a queued message.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final color = danger ? theme.danger : theme.accent;
    return FocusableTap(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: label,
      radius: theme.radiusSm,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Text(
            label,
            style: metaText(theme).copyWith(
              color: onTap == null ? theme.inkMuted : color,
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
}) {
  return showAdaptiveSheet<String>(
    context,
    // Matches its two siblings. Without it, a tall keyboard pushes this sheet
    // up under the status bar.
    useSafeArea: true,
    builder: (_) => _ScheduledEditSheet(initial: initial),
  );
}

class _ScheduledEditSheet extends StatefulWidget {
  const _ScheduledEditSheet({required this.initial});

  final String initial;

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
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      // The keyboard's inset, which a bottom sheet outside a Scaffold has to
      // add for itself.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sheetFill(theme),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(sheetTopRadius(theme)),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Text(
            sentenceCaseOf(context, l10n.scheduleEditTitle),
            textAlign: TextAlign.center,
            style: theme.bodyEmph.copyWith(fontSize: 17, color: theme.ink),
          ),
            const SizedBox(height: 14),
            Container(
              decoration: fieldDecoration(theme),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: TextField(
                controller: _controller,
                autofocus: true,
                style: theme.body.copyWith(color: theme.ink),
                cursorColor: theme.accent,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            SheetPrimaryButton(
              label: l10n.scheduleSheetSaveButton,
              onTap: _controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_controller.text.trim()),
            ),
            const SizedBox(height: 4),
            SheetSecondaryButton(
              label: l10n.destructiveSheetCancelButtonLabel,
              color: theme.inkMuted,
              bordered: false,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
