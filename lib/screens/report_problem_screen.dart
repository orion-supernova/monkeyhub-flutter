import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../diagnostics/problem_report.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/adaptive_page_body.dart';

/// Lets any user describe a problem and send it, with the identifiers that make
/// it actionable already filled in.
///
/// The identifiers are the point. A report saying "it flickers" is unactionable;
/// the same report carrying a device id can be turned into a real diagnostic
/// session with one CLI command, because that id is what unlocks capture for
/// that handset. Everything else on this screen exists to make somebody
/// willing to send it.
///
/// Nothing is uploaded. The report leaves through the share sheet, which means
/// it works when the connection is the thing that is broken — and means no
/// user-submitted screenshots are stored on a server for a children's app.
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key, required this.auth});

  final AuthService auth;

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final TextEditingController _description = TextEditingController();
  final List<XFile> _shots = [];
  List<({String label, String value})> _facts = const [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadFacts();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadFacts() async {
    final facts = await ProblemReport.facts(widget.auth);
    if (!mounted) return;
    setState(() => _facts = facts);
  }

  Future<void> _addScreenshot() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        // Reports go out through a share sheet into a chat app, and a handful
        // of full-resolution screenshots is enough to get the message bounced.
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

  String get _deviceLabel {
    for (final f in _facts) {
      if (f.label == 'Device') return f.value;
    }
    return 'device';
  }

  Future<void> _send(Rect? origin) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ProblemReport.send(
        body: _body(),
        screenshots: _shots,
        deviceLabel: _deviceLabel,
        origin: origin,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _copyDetails() async {
    await Clipboard.setData(
      ClipboardData(text: ProblemReport.formatFacts(_facts)),
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(l10n.reportProblemCopied),
      ),
    );
  }

  Future<void> _emailInstead() async {
    final uri = ProblemReport.mailto(body: _body(), deviceLabel: _deviceLabel);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No mail client configured. The share sheet above is the real route.
    }
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
                                  width: 88,
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
                  const SizedBox(height: 12),
                  Center(
                    child: FocusableTap(
                      onTap: _emailInstead,
                      radius: theme.radiusSm,
                      semanticLabel: kSupportEmail,
                      child: GestureDetector(
                        onTap: _emailInstead,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          l10n.reportProblemEmailInstead(kSupportEmail),
                          style: theme.bodySoft.copyWith(color: theme.accent),
                        ),
                      ),
                    ),
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

/// Needs the button's global rect for iPad/macOS share-popover anchoring, so it
/// cannot use the plain [_Button] shape.
class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.label,
    required this.busy,
    required this.onSend,
  });
  final String label;
  final bool busy;
  final Future<void> Function(Rect? origin) onSend;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Builder(
      builder: (context) {
        void go() {
          final box = context.findRenderObject() as RenderBox?;
          onSend(
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
          );
        }

        return FocusableTap(
          onTap: busy ? null : go,
          radius: theme.radiusMd,
          semanticLabel: label,
          child: GestureDetector(
            onTap: busy ? null : go,
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
      },
    );
  }
}
