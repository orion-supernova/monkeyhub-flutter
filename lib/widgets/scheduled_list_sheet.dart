import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/family.dart';
import '../models/scheduled_message.dart';
import '../theme/motion.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'destructive_sheet.dart' show SheetGrabber;
import 'schedule_message_sheet.dart';

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

class _ScheduledListSheet extends StatelessWidget {
  const _ScheduledListSheet({required this.repo, required this.roomId});

  final ChatRepository repo;
  final String roomId;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(theme.radiusLg)),
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
          const SheetGrabber(),
          Text(l10n.scheduledListTitle, style: theme.label),
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
          const SizedBox(height: 16),
          _SecondaryButton(
            label: l10n.destructiveSheetCancelButtonLabel,
            color: theme.inkMuted,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(scheduleErrorSentence(context, code))),
    );
  }

  Future<void> _changeTime() async {
    final at = await showScheduleMessageSheet(
      context,
      mode: ScheduleSheetMode.reschedule,
      preview: widget.message.content,
      initial: widget.message.sendAt,
    );
    if (at == null || !mounted) return;
    await _run(() => widget.repo.rescheduleMessage(
          widget.message.id,
          sendAt: at.millisecondsSinceEpoch,
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
                  failed ? Icons.error_outline : Icons.schedule,
                  size: 13,
                  color: failed ? theme.danger : theme.accent,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _headline(context, l10n, m),
                    style: theme.monoTiny.copyWith(
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
                  onTap: _busy
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          widget.repo.cancelScheduledMessage(m.id);
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
            style: theme.monoTiny.copyWith(
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
          color: theme.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(theme.radiusLg)),
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
            const SheetGrabber(),
            Text(l10n.scheduleEditTitle, style: theme.label),
            const SizedBox(height: 14),
            Container(
              decoration: theme.inputDecoration(),
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
            _PrimaryButton(
              label: l10n.scheduleSheetSaveButton,
              onTap: _controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_controller.text.trim()),
            ),
            const SizedBox(height: 4),
            _SecondaryButton(
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

/// Kept in step with `schedule_message_sheet.dart`'s copies by hand — they are
/// private there, and lifting them into a shared file would put two sheets'
/// worth of chrome in a third place for no caller's benefit.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final enabled = onTap != null;
    return FocusableTap(
      onTap: onTap,
      enabled: enabled,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? theme.accent : theme.accentSoft,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            label,
            style: theme.label.copyWith(
              color: enabled ? theme.accentInk : theme.inkMuted,
              letterSpacing: 2.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.bordered = true,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      semanticLabel: label,
      radius: theme.radiusMd,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: bordered
                ? Border.all(color: color.withValues(alpha: 0.55), width: 1.2)
                : null,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Text(
            label,
            style: theme.label.copyWith(color: color, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}
