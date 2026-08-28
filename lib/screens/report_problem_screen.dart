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
import '../widgets/adaptive_page_body.dart';
import '../widgets/app_toast.dart';

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          theme.backgroundLayer(context),
          SafeArea(
            child: AdaptivePageBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Text(l10n.reportProblemRowLabel, style: theme.displaySmall),
                  const SizedBox(height: 8),
                  Text(l10n.reportProblemIntro, style: theme.bodySoft),

                  const SizedBox(height: 24),
                  _SectionLabel(l10n.reportProblemDescribeLabel),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      border: Border.all(color: theme.divider),
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    child: TextField(
                      controller: _description,
                      style: theme.body,
                      minLines: 4,
                      maxLines: 8,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                        hintText: l10n.reportProblemDescribeHint,
                        hintStyle: theme.bodySoft,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _SectionLabel(l10n.reportProblemScreenshotsLabel),
                  const SizedBox(height: 8),
                  if (_shots.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _shots.length; i++)
                          _ShotChip(
                            name: 'screenshot ${i + 1}',
                            onRemove: () => setState(() => _shots.removeAt(i)),
                          ),
                      ],
                    ),
                  if (_shots.isNotEmpty) const SizedBox(height: 8),
                  _Button(
                    label: l10n.reportProblemAddScreenshot,
                    icon: Icons.add_photo_alternate_outlined,
                    onTap: _addScreenshot,
                  ),

                  const SizedBox(height: 24),
                  _SectionLabel(l10n.reportProblemDetailsLabel),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.surfaceSunken,
                      border: Border.all(color: theme.divider),
                      borderRadius: BorderRadius.circular(theme.radiusMd),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final f in _facts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  // Wide enough for "System locale", the longest
                                  // label — a narrower column wraps it onto two
                                  // lines and knocks the whole block out of
                                  // alignment.
                                  width: 104,
                                  child: Text(
                                    f.label,
                                    style: theme.monoTiny.copyWith(
                                      color: theme.inkMuted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  // Selectable so somebody reading their id
                                  // over the phone can pick out one chunk of it
                                  // rather than copying the whole block.
                                  child: SelectableText(
                                    f.value,
                                    style: theme.monoTiny,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Button(
                    label: l10n.reportProblemCopyDetails,
                    icon: Icons.copy_all_outlined,
                    onTap: _copyDetails,
                  ),

                  const SizedBox(height: 28),
                  _SendButton(
                    label: l10n.reportProblemSend,
                    busy: _sending,
                    onSend: _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Text(
      text,
      style: theme.label.copyWith(letterSpacing: 2.4, color: theme.accent),
    );
  }
}

class _ShotChip extends StatelessWidget {
  const _ShotChip({required this.name, required this.onRemove});
  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border.all(color: theme.divider),
        borderRadius: BorderRadius.circular(theme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, style: theme.monoTiny),
          const SizedBox(width: 6),
          FocusableTap(
            onTap: onRemove,
            shape: FocusRingShape.circle,
            semanticLabel: 'remove $name',
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Icon(Icons.close, size: 14, color: theme.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    // Bare GestureDetector plus FocusableTap — this app registers no ink.
    return FocusableTap(
      onTap: onTap,
      radius: theme.radiusMd,
      semanticLabel: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border.all(color: theme.divider),
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: theme.inkSoft),
              const SizedBox(width: 8),
              Text(label, style: theme.body),
            ],
          ),
        ),
      ),
    );
  }
}

/// The primary action, wider and filled — a different shape from [_Button] on
/// purpose, so the one button that sends does not look like the two that don't.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.label,
    required this.busy,
    required this.onSend,
  });
  final String label;
  final bool busy;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: busy ? null : onSend,
      radius: theme.radiusMd,
      semanticLabel: label,
      child: GestureDetector(
        onTap: busy ? null : onSend,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.accent,
            borderRadius: BorderRadius.circular(theme.radiusMd),
          ),
          child: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.accentInk,
                  ),
                )
              : Text(
                  label,
                  style: theme.bodyEmph.copyWith(color: theme.accentInk),
                ),
        ),
      ),
    );
  }
}
