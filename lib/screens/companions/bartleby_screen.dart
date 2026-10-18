/// Settings › Companions › Bartleby.
///
/// ── The scribe ─────────────────────────────────────────────────────────────
///
/// Voice-message transcripts used to be a feature with no home: a speech model
/// that arrived on the first "Show transcript" tap and could only be found
/// again as a line in Storage. This screen is that home, and it answers the
/// three questions in the order somebody asks them: what does he do, which
/// languages can he do right now, and what is he costing me.
///
/// Like Sebastian he is installed, not configured. There is one speech model
/// and no choice to make (see `transcript_model.dart` for why it is Whisper
/// small), so the download is a single row, titled with the same words as the
/// "Better transcripts" link under a transcript, because it is the same offer.
///
/// The built-in list is Apple only and never downloads anything: it asks the
/// OS which of the languages it already has, the same question
/// [VoiceTranscriber] asks before every note.
library;

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../companions/companion.dart';
import '../../companions/translation/language.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/theme_scope.dart';
import '../../transcripts/transcript_model.dart';
import '../../transcripts/voice_transcriber.dart';
import '../../widgets/account_kit.dart' show SoftNote;
import '../../widgets/destructive_sheet.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/sheet_kit.dart' show IosSheetAction, showIosActionSheet;
import 'companion_page.dart';

class BartlebyScreen extends StatefulWidget {
  const BartlebyScreen({super.key});

  @override
  State<BartlebyScreen> createState() => _BartlebyScreenState();
}

class _BartlebyScreenState extends State<BartlebyScreen> {
  static const _companion = Companion.bartleby;

  VoiceTranscriber get _t => VoiceTranscriber.instance;

  /// The OS recognizer's languages already on the device, or null while the
  /// question is out.
  List<TranslationLanguage>? _builtIn;

  /// Everything of his on disk: the model, any partial, the transcripts.
  int? _bytes;

  /// Why the last download from this screen did not finish.
  TranscriptFailure? _failure;

  @override
  void initState() {
    super.initState();
    _t.modelInstalled.addListener(_onModel);
    unawaited(_t.refreshModelInstalled());
    unawaited(_loadBuiltIn());
    unawaited(_loadBytes());
  }

  @override
  void dispose() {
    _t.modelInstalled.removeListener(_onModel);
    super.dispose();
  }

  void _onModel() {
    if (!mounted) return;
    setState(() {});
    unawaited(_loadBytes());
  }

  Future<void> _loadBuiltIn() async {
    if (!_t.hasBuiltIn) return;
    final tags = await _t.builtInLanguages([
      for (final l in kTranslationLanguages) l.code,
    ]);
    final seen = <String>{};
    final langs = [
      for (final tag in tags)
        if (languageForCode(tag) case final l? when seen.add(l.code)) l,
    ];
    if (mounted) setState(() => _builtIn = langs);
  }

  Future<void> _loadBytes() async {
    final b = await TranscriptStore.instance.bytesUsed();
    if (mounted) setState(() => _bytes = b);
  }

  Future<void> _download() async {
    final l10n = AppLocalizations.of(context);
    final size = _t.model.sizeLabel;
    var cellularOk = false;
    if (_t.downloadNeedsCellularConsent) {
      final go = await showIosActionSheet<bool>(
        context,
        title: l10n.bartlebyCellularTitle,
        message: l10n.bartlebyCellularBody(size),
        actions: [
          IosSheetAction(
            label: l10n.voiceTranscriptDownloadAction(size),
            value: true,
          ),
        ],
      );
      if (go != true || !mounted) return;
      cellularOk = true;
    }
    setState(() => _failure = null);
    final failure = await _t.installModel(cellularOk: cellularOk);
    if (!mounted) return;
    setState(() => _failure = failure);
    unawaited(_loadBytes());
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showConfirmSheet(
      context,
      headline: l10n.companionRemoveTitle(_companion.displayName),
      body: '${l10n.companionRemoveMessage(_t.model.sizeLabel)} '
          '${l10n.bartlebyRemoveKeepsTranscripts}',
      confirmLabel: l10n.companionRemoveConfirm,
    );
    if (!confirmed || !mounted) return;
    await _t.removeModel();
    unawaited(_loadBytes());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final installed = _t.modelInstalled.value ?? false;
    final bytes = _bytes;
    final builtIn = _builtIn;

    return CompanionPage(
      title: _companion.displayName,
      subtitle: _companion.tagline(l10n),
      children: [
        CompanionPortrait(companion: _companion, quote: l10n.bartlebyQuote),
        const SizedBox(height: 24),
        if (!_t.supported)
          SoftNote(
            icon: CupertinoIcons.info_circle,
            text: l10n.companionUnsupportedPlatform,
          )
        else ...[
          // Apple only: the languages he can do with nothing downloaded.
          // Left out until the OS has answered, rather than flashing "none".
          if (_t.hasBuiltIn && builtIn != null)
            GroupedSection(
              header: l10n.bartlebyBuiltInHeader,
              footer: installed
                  ? l10n.bartlebyBuiltInFooterModel
                  : l10n.bartlebyBuiltInFooter,
              children: [
                if (builtIn.isEmpty)
                  GroupedRow(title: l10n.bartlebyBuiltInNone)
                else
                  for (final lang in builtIn)
                    GroupedRow(title: '${lang.flag}  ${lang.autonym}'),
              ],
            ),
          GroupedSection(
            header: l10n.compStorage,
            footer: bytes == null
                ? null
                : (bytes == 0
                    ? l10n.bartlebyStorageEmpty
                    : l10n.bartlebyStorageUsed(companionByteLabel(bytes))),
            children: [
              _ModelRow(
                model: _t.model,
                installed: installed,
                failure: _failure,
                onDownload: _download,
                onCancel: _t.cancelDownload,
                onRemove: _remove,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The speech model, with its whole lifecycle: absent, downloading, failed,
/// on disk. Laid out like [BrainRow] so the three companions' downloads read
/// as one control; not a [BrainRow] because this is not a brain and its
/// download is [VoiceTranscriber]'s, which has no pause.
///
/// Listens to the download itself, so a progress tick repaints this row and
/// not the page.
class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.installed,
    required this.failure,
    required this.onDownload,
    required this.onCancel,
    required this.onRemove,
  });

  final TranscriptModel model;
  final bool installed;
  final TranscriptFailure? failure;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder(
      valueListenable: VoiceTranscriber.instance.download,
      builder: (context, dl, _) {
        final size = model.sizeLabel;
        final Widget trailing;
        if (dl != null) {
          trailing = RowPillButton(
            label: l10n.companionInstallCancel,
            onTap: onCancel,
          );
        } else if (installed) {
          trailing = RowPillButton(
            label: l10n.companionBrainRemove,
            onTap: onRemove,
            destructive: true,
          );
        } else if (failure != null) {
          trailing = RowPillButton(
            label: l10n.companionInstallRetry,
            onTap: onDownload,
          );
        } else {
          trailing = RowPillButton(
            label: size,
            semanticLabel: l10n.companionInstallAction(size),
            onTap: onDownload,
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.bartlebyModelTitle,
                          style: groupedTitleStyle(theme),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          installed
                              ? l10n.bartlebyModelInstalled(size)
                              : l10n.bartlebyModelDetail,
                          style: groupedSubtitleStyle(theme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  trailing,
                ],
              ),
              if (dl != null) ...[
                const SizedBox(height: 12),
                CompanionProgressLine(fraction: dl.fraction),
                const SizedBox(height: 4),
                Text(
                  l10n.companionInstallProgress(
                    companionByteLabel(dl.received),
                    companionByteLabel(dl.total),
                  ),
                  style: groupedMetaStyle(theme).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ] else if (failure != null && !installed) ...[
                const SizedBox(height: 8),
                Text(
                  failure == TranscriptFailure.storage
                      ? l10n.voiceTranscriptFailedStorage(size)
                      : l10n.voiceTranscriptFailedNetwork,
                  style: groupedMetaStyle(theme).copyWith(color: theme.danger),
                ),
              ] else if (!installed) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.companionInstallOneTime,
                  style: groupedMetaStyle(theme),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
