import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/storage/data_prefs.dart';
import '../../media/storage/storage_kinds.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/settings_pickers.dart';
import '../../widgets/stepped_slider.dart';
import 'storage_labels.dart';

const int _mb = 1024 * 1024;

/// The size stops a video rule can rest on. They include every preset's
/// value, so a preset always lands on a stop.
const List<int> kVideoSizeStops = [
  1 * _mb, 5 * _mb, 10 * _mb, 15 * _mb, 25 * _mb, 48 * _mb, //
];

/// The size stops for files; the top is the largest file that can be sent.
const List<int> kFileSizeStops = [1 * _mb, 3 * _mb, 5 * _mb, 10 * _mb, 20 * _mb];

/// Which media type a [MediaRuleScreen] edits.
enum RuleMedia { photos, videos, files }

/// Automatic media download for one network: a master switch, the Low /
/// Medium / High slider that sets every type at once, and a row per type
/// for anyone who wants it exact. Touching a type turns the slider's label
/// off; it describes presets, and that is no longer one.
class AutoDownloadScreen extends StatelessWidget {
  const AutoDownloadScreen({super.key, required this.net});

  final NetKind net;

  static Future<void> _save(NetKind net, NetworkDownloadPrefs p) =>
      SettingsStore.instance.setDataPrefs(
          SettingsStore.instance.dataPrefs.withDownloads(net, p));

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final theme = ThemeScope.of(context);
        final p = SettingsStore.instance.dataPrefs.downloadsOn(net);
        final preset = p.presetFor(net);

        String typeSubtitle(MediaRule rule, {bool sized = true}) {
          final chats = chatsSummary(l10n, rule.chats);
          if (rule.isOff || !sized) return chats;
          return l10n.autoDownloadUpToIn(mbLabel(rule.maxBytes), chats);
        }

        void open(RuleMedia m) => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MediaRuleScreen(net: net, media: m),
            ));

        final types = [
          GroupedSection(
            header: l10n.autoDownloadUsageHeader,
            footer: preset == null ? l10n.autoDownloadCustomFooter : null,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: SteppedSlider(
                  enabled: p.enabled,
                  labels: [
                    for (final d in DownloadPreset.values) presetLabel(l10n, d),
                  ],
                  index: preset?.index,
                  onChanged: (i) => _save(
                    net,
                    NetworkDownloadPrefs.preset(DownloadPreset.values[i], net),
                  ),
                ),
              ),
            ],
          ),
          GroupedSection(
            header: l10n.autoDownloadTypesHeader,
            footer: l10n.autoDownloadVoiceFooter,
            children: [
              GroupedRow(
                icon: CupertinoIcons.photo_fill,
                tone: storageTone(StorageKind.photos),
                title: l10n.storageKindPhotos,
                subtitle: typeSubtitle(p.photos, sized: false),
                onTap: () => open(RuleMedia.photos),
              ),
              GroupedRow(
                icon: CupertinoIcons.videocam_fill,
                tone: storageTone(StorageKind.videos),
                title: l10n.autoDownloadVideosTitle,
                subtitle: typeSubtitle(p.videos),
                onTap: () => open(RuleMedia.videos),
              ),
              GroupedRow(
                icon: CupertinoIcons.doc_fill,
                tone: storageTone(StorageKind.files),
                title: l10n.storageKindFiles,
                subtitle: typeSubtitle(p.files),
                onTap: () => open(RuleMedia.files),
              ),
            ],
          ),
        ];

        return SettingsPage(
          title: net == NetKind.cellular
              ? l10n.dataStorageUsingCellular
              : l10n.dataStorageUsingWifi,
          children: [
            GroupedSection(
              children: [
                GroupedRow.toggle(
                  title: l10n.autoDownloadMaster,
                  value: p.enabled,
                  onChanged: (v) {
                    HapticFeedback.lightImpact();
                    _save(net, p.copyWith(enabled: v));
                  },
                ),
              ],
            ),
            // Dimmed, not hidden, while the switch is off: the rules are
            // still there and come back exactly as they were.
            AnimatedOpacity(
              opacity: p.enabled ? 1 : 0.4,
              duration: theme.motionFast,
              child: IgnorePointer(
                ignoring: !p.enabled,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: types,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// One media type's rule on one network: which kinds of chat it downloads
/// in, and for videos and files how large a file may be.
class MediaRuleScreen extends StatelessWidget {
  const MediaRuleScreen({super.key, required this.net, required this.media});

  final NetKind net;
  final RuleMedia media;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final prefs = SettingsStore.instance.dataPrefs.downloadsOn(net);
        final rule = switch (media) {
          RuleMedia.photos => prefs.photos,
          RuleMedia.videos => prefs.videos,
          RuleMedia.files => prefs.files,
        };

        Future<void> save(MediaRule r) {
          final next = switch (media) {
            RuleMedia.photos => prefs.copyWith(photos: r),
            RuleMedia.videos => prefs.copyWith(videos: r),
            RuleMedia.files => prefs.copyWith(files: r),
          };
          return SettingsStore.instance.setDataPrefs(
              SettingsStore.instance.dataPrefs.withDownloads(net, next));
        }

        final stops = media == RuleMedia.videos ? kVideoSizeStops : kFileSizeStops;
        final at = stops.indexOf(rule.maxBytes);

        return SettingsPage(
          title: switch (media) {
            RuleMedia.photos => l10n.storageKindPhotos,
            RuleMedia.videos => l10n.autoDownloadVideosTitle,
            RuleMedia.files => l10n.storageKindFiles,
          },
          children: [
            GroupedSection(
              header: l10n.autoDownloadInHeader,
              children: [
                for (final c in ChatClass.values)
                  GroupedRow.toggle(
                    icon: chatClassIcon(c),
                    tone: chatClassTone(c),
                    title: chatClassLabel(l10n, c),
                    value: rule.chats.contains(c),
                    onChanged: (v) {
                      HapticFeedback.lightImpact();
                      save(rule.copyWith(
                        chats: v
                            ? {...rule.chats, c}
                            : ({...rule.chats}..remove(c)),
                      ));
                    },
                  ),
              ],
            ),
            if (media != RuleMedia.photos)
              GroupedSection(
                header: l10n.autoDownloadMaxSizeHeader,
                footer: media == RuleMedia.videos
                    ? l10n.autoDownloadMaxSizeVideoFooter(mbLabel(rule.maxBytes))
                    : l10n.autoDownloadMaxSizeFileFooter(mbLabel(rule.maxBytes)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: SteppedSlider(
                      enabled: !rule.isOff,
                      labels: [for (final s in stops) mbLabel(s)],
                      index: at < 0 ? null : at,
                      onChanged: (i) => save(rule.copyWith(maxBytes: stops[i])),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
