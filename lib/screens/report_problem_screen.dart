import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';

import '../auth/auth_service.dart';
import '../backend/chat_api.dart';
import '../diagnostics/problem_report.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../media/upload_service.dart';
import '../push/device_identity.dart';
import '../theme/theme_scope.dart';
import '../widgets/app_toast.dart';
import '../widgets/ios_kit.dart';
import '../widgets/prominent_button.dart';
import '../widgets/sheet_kit.dart' show sentenceCaseOf;

/// Lets any user describe a problem and send it, with the identifiers that make
/// it actionable already filled in.
///
/// The identifiers are the point. A report saying "it flickers" is unactionable;
/// the same report carrying a device id and the captured log can be triaged
/// without a single follow-up question. Everything else on this screen exists to
/// make somebody willing to send it.
///
/// Tapping send SENDS. It used to open the share sheet, which meant the report
/// only existed if the user then picked an app, found a recipient and hit send
/// there — three chances to abandon a form they had already filled in, and no way
/// for anyone to know they had. Now the screen uploads the evidence, posts the
/// report, and says so.
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key, required this.auth, required this.api});

  final AuthService auth;
  final ChatApi api;

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final TextEditingController _description = TextEditingController();
  final List<XFile> _shots = [];
  List<({String label, String value})> _facts = const [];
  bool _sending = false;

  /// The locale the loaded [_facts] were built for, so a rebuild that changed
  /// something else — a theme swap, a keyboard inset — does not kick off another
  /// gather. Only a real language change should.
  String? _factsLocale;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Here rather than in initState because the app language is read off this
    // context, and Localizations is not resolvable until dependencies are.
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (locale == _factsLocale) return;
    _factsLocale = locale;
    _loadFacts(locale);
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadFacts(String appLocale) async {
    final facts = await ProblemReport.facts(widget.auth, appLocale: appLocale);
    if (!mounted) return;
    setState(() => _facts = facts);
  }

  Future<void> _addScreenshot() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Downscaled because these are uploaded now, and a handful of
        // full-resolution screenshots is a slow send on the connection most
        // likely to be part of the problem.
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() => _shots.add(picked));
    } catch (_) {
      // A denied gallery permission must not break the report — the text and
      // the identifiers are the part that matters.
    }
  }

  String _body() => ProblemReport.buildBody(
    facts: _facts,
    description: _description.text,
    screenshotCount: _shots.length,
  );

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final l10n = AppLocalizations.of(context);
    var ok = true;
    var message = l10n.reportProblemSent;
    try {
      await ProblemReport.send(
        api: widget.api,
        uploads: UploadService(widget.api),
        auth: widget.auth,
        body: _body(),
        screenshots: _shots,
        deviceId: await DeviceIdentity.ensure(),
      );
    } catch (e) {
      // The throttle is the one failure that is the user's to understand — it
      // says "wait", not "something broke", and telling them to retry would be
      // telling them to do the thing that cannot work. Everything else is ours.
      ok = false;
      message = e.toString().contains('TOO_MANY_REPORTS')
          ? l10n.reportProblemTooMany
          : l10n.reportProblemSendFailed;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    showAppToast(context, message, duration: const Duration(seconds: 3));
    // Leave on success only. A failed report must keep the text the user typed
    // and the screenshots they picked, or the retry is a retype.
    if (ok) Navigator.of(context).maybePop();
  }

  Future<void> _copyDetails() async {
    await Clipboard.setData(
      ClipboardData(text: ProblemReport.formatFacts(_facts)),
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    showAppToast(
      context,
      l10n.reportProblemCopied,
      tone: ToastTone.success,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);

    return IosPage(
      title: l10n.reportProblemRowLabel,
      subtitle: l10n.reportProblemIntro,
      children: [
        GroupedSection(
          header: sentenceCaseOf(context, l10n.reportProblemDescribeLabel),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TextField(
                controller: _description,
                style: theme.body.copyWith(fontSize: 17, color: theme.ink),
                minLines: 4,
                maxLines: 8,
                maxLength: 2000,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  hintText: l10n.reportProblemDescribeHint,
                  hintStyle: theme.bodySoft.copyWith(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
        GroupedSection(
          header: sentenceCaseOf(context, l10n.reportProblemScreenshotsLabel),
          children: [
            for (var i = 0; i < _shots.length; i++)
              GroupedRow(
                icon: CupertinoIcons.photo_fill,
                tone: TileTone.blue,
                title: 'Screenshot ${i + 1}',
                trailing: _RemoveButton(
                  label: 'Screenshot ${i + 1}',
                  onTap: () => setState(() => _shots.removeAt(i)),
                ),
              ),
            GroupedRow(
              icon: CupertinoIcons.plus,
              tone: TileTone.green,
              title: l10n.reportProblemAddScreenshot,
              chevron: false,
              onTap: _addScreenshot,
            ),
          ],
        ),
        GroupedSection(
          header: sentenceCaseOf(context, l10n.reportProblemDetailsLabel),
          children: [
            for (final f in _facts)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 11, 16, 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      // Wide enough for "System locale", the longest label —
                      // a narrower column wraps it onto two lines and knocks
                      // the whole block out of alignment.
                      width: 120,
                      child: Text(
                        f.label,
                        style: theme.body.copyWith(
                          fontSize: 15,
                          color: theme.inkMuted,
                        ),
                      ),
                    ),
                    Expanded(
                      // Selectable so somebody reading their id over the phone
                      // can pick out one chunk of it rather than copying the
                      // whole block.
                      child: SelectableText(
                        f.value,
                        textAlign: TextAlign.end,
                        style: theme.body.copyWith(
                          fontSize: 15,
                          color: theme.ink,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            GroupedRow(
              icon: CupertinoIcons.doc_on_doc_fill,
              tone: TileTone.gray,
              title: l10n.reportProblemCopyDetails,
              chevron: false,
              onTap: _copyDetails,
            ),
          ],
        ),
        ProminentButton(
          label: l10n.reportProblemSend,
          busy: _sending,
          onTap: _sending ? null : _send,
        ),
      ],
    );
  }
}

/// The minus a removable screenshot row ends in — iOS's red delete disc.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      shape: FocusRingShape.circle,
      semanticLabel: 'remove $label',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            CupertinoIcons.minus_circle_fill,
            size: 22,
            color: theme.danger,
          ),
        ),
      ),
    );
  }
}
