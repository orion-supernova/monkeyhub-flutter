import 'package:flutter/material.dart';

import '../backend/chat_api.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import 'adaptive_sheet.dart';
import 'app_toast.dart';
import 'ios_kit.dart';
import 'labeled_field.dart';
import 'sheet_kit.dart';
import '../l10n/text_case.dart';
import '../backend/server_limits.dart';

/// What is being reported, which decides what the sheet says will be sent.
///
/// The disclosure has to be exact, because it is a promise: the server
/// (`moderationCore.fileContentReport`) sends the moderators the reported
/// message and the messages around it, or the last few messages of the DM or
/// room, and the sheet says precisely that before the user taps send.
enum ReportTarget {
  /// One message, from a long-press.
  message,

  /// A person, from their profile or a DM's info page.
  user,

  /// A group, from its info page.
  room,

  /// A moment, from the viewer's menu.
  moment,

  /// A comment on a moment, from its long-press menu.
  comment;

  String get wire => switch (this) {
        ReportTarget.message => 'message',
        ReportTarget.user => 'user',
        ReportTarget.room => 'room',
        ReportTarget.moment => 'moment',
        ReportTarget.comment => 'comment',
      };

  /// A room has no one person to block.
  bool get canBlock => this != ReportTarget.room;
}

/// The user's answer: why, and whether to block too.
class ReportChoice {
  const ReportChoice({required this.reason, required this.alsoBlock});
  final String reason;
  final bool alsoBlock;
}

/// Prompts the user to pick a report reason. Resolves to their choice (or
/// null on dismiss). The "other" path lets the user type a free-form reason;
/// everything is short to keep the sheet tight.
///
/// Prefer [fileReport], which also sends it and confirms; this is the sheet
/// alone, for a caller that needs to do something else with the answer.
Future<ReportChoice?> showReportSheet(
  BuildContext context, {
  ReportTarget target = ReportTarget.message,
}) {
  return showAdaptiveSheet<ReportChoice>(
    context,
    builder: (_) => _ReportSheet(target: target),
  );
}

/// The whole report flow, shared by every surface that offers one (message
/// long-press, the thread overlay, a profile, room info): the sheet, the
/// call, and the confirmation that moderators review within 24 hours.
///
/// One function rather than four call sites each awaiting the sheet and the
/// API, because the confirmation copy is a promise the App Store review reads
/// and it must say the same thing everywhere. Returns true once a report was
/// filed.
Future<bool> fileReport(
  BuildContext context, {
  required ChatApi api,
  required String reporterId,
  required ReportTarget target,
  required String targetId,
}) async {
  // Captured before the sheet's await, per AppToast's own advice.
  final toast = AppToast.of(context);
  final l10n = AppLocalizations.of(context);
  final choice = await showReportSheet(context, target: target);
  if (choice == null || choice.reason.isEmpty) return false;
  try {
    final blocked = await api.report(
      reporterId: reporterId,
      targetType: target.wire,
      targetId: targetId,
      reason: choice.reason,
      alsoBlock: target.canBlock && choice.alsoBlock,
    );
    toast.success(blocked ? l10n.reportSentAndBlocked : l10n.reportSentReviewed);
    return true;
  } catch (e) {
    toast.error(
      e.toString().contains('TOO_MANY_REPORTS')
          ? l10n.reportTooMany
          : friendlyServerError(e, l10n, l10n.reportFailed),
    );
    return false;
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.target});
  final ReportTarget target;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = <(String, String)>[
    ('SPAM', 'unwanted ads or repeated messages'),
    ('HARASSMENT', 'targeting or bullying'),
    ('IMPERSONATION', 'pretending to be someone'),
    ('INAPPROPRIATE', 'sexual, violent, or illegal content'),
    ('OTHER', 'something else'),
  ];

  final _note = TextEditingController();
  String? _selected;

  /// "Also block this person". On by default where there is a person to
  /// block: somebody reporting abuse almost always wants it to stop now, not
  /// after the review, and unticking is one tap.
  late bool _alsoBlock = widget.target.canBlock;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// Lifted out of the button's inline closure so the keyboard activation path
  /// and the tap path run the same code.
  void _submitReport() {
    final selected = _selected;
    if (selected == null) return;
    final reason = selected == 'OTHER' && _note.text.trim().isNotEmpty
        ? 'OTHER: ${_note.text.trim()}'
        : selected;
    Navigator.of(context).pop(
      ReportChoice(reason: reason, alsoBlock: _alsoBlock),
    );
  }

  /// Display label for a reason code. The code itself (`r.$1`) stays the
  /// canonical English value used for selection matching and as the reason
  /// string sent to the backend — only what's shown on screen is localized.
  String _reasonLabel(BuildContext context, String code) {
    final l10n = AppLocalizations.of(context);
    switch (code) {
      case 'SPAM':
        return l10n.reportSheetReasonSpamLabel;
      case 'HARASSMENT':
        return l10n.reportSheetReasonHarassmentLabel;
      case 'IMPERSONATION':
        return l10n.reportSheetReasonImpersonationLabel;
      case 'INAPPROPRIATE':
        return l10n.reportSheetReasonInappropriateLabel;
      case 'OTHER':
        return l10n.reportSheetReasonOtherLabel;
      default:
        return code;
    }
  }

  /// Display description for a reason code — see [_reasonLabel].
  String _reasonDescription(BuildContext context, String code) {
    final l10n = AppLocalizations.of(context);
    switch (code) {
      case 'SPAM':
        return l10n.reportSheetReasonSpamDescription;
      case 'HARASSMENT':
        return l10n.reportSheetReasonHarassmentDescription;
      case 'IMPERSONATION':
        return l10n.reportSheetReasonImpersonationDescription;
      case 'INAPPROPRIATE':
        return l10n.reportSheetReasonInappropriateDescription;
      case 'OTHER':
        return l10n.reportSheetReasonOtherDescription;
      default:
        return '';
    }
  }

  /// What leaves the device, said before it does. See [ReportTarget].
  String _disclosure(AppLocalizations l10n) => switch (widget.target) {
        ReportTarget.message => l10n.reportSheetDisclosureMessage,
        ReportTarget.user => l10n.reportSheetDisclosureUser,
        ReportTarget.room => l10n.reportSheetDisclosureRoom,
        ReportTarget.moment => l10n.reportSheetDisclosureMoment,
        ReportTarget.comment => l10n.reportSheetDisclosureComment,
      };

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    String sc(String x) => sentenceCaseOf(context, x);
    return SheetFrame(
      title: sc(l10n.reportSheetTitle),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetRise(
              child: Text(
                sc(l10n.reportSheetSubtitle),
                textAlign: TextAlign.center,
                style: theme.displaySmall.copyWith(color: theme.ink),
              ),
            ),
            const SizedBox(height: 4),
            SheetRise(
              index: 1,
              child: Text(
                _disclosure(l10n),
                textAlign: TextAlign.center,
                style: theme.bodySoft.copyWith(color: theme.inkMuted),
              ),
            ),
            const SizedBox(height: 18),
            SheetRise(
              index: 2,
              child: SheetGroup(
                children: [
                  for (final r in _reasons)
                    GroupedRow.choice(
                      title: sc(_reasonLabel(context, r.$1)),
                      subtitle: sc(_reasonDescription(context, r.$1)),
                      selected: _selected == r.$1,
                      onTap: () => setState(() => _selected = r.$1),
                    ),
                ],
              ),
            ),
            // The free-text note grows in under the list when it is needed,
            // instead of the sheet jumping by its height.
            AnimatedSize(
              duration: theme.motionFast,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _selected == 'OTHER'
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ThemedInput(
                        controller: _note,
                        hint: sc(l10n.reportSheetOtherNoteHint),
                        minLines: 2,
                        maxLines: 5,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (widget.target.canBlock) ...[
              const SizedBox(height: 12),
              SheetGroup(
                children: [
                  GroupedRow.toggle(
                    title: l10n.reportSheetAlsoBlock,
                    value: _alsoBlock,
                    onChanged: (v) => setState(() => _alsoBlock = v),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Semantics(
              label: l10n.reportSheetSubmitSemanticLabel,
              child: SheetActionButton(
                label: l10n.reportSheetSubmitButton,
                destructive: true,
                onTap: _selected == null ? null : _submitReport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
