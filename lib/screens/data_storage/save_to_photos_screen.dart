import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/storage/data_prefs.dart';
import '../../media/storage/gallery_autosave.dart';
import '../../media/storage/storage_kinds.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/settings_pickers.dart';
import '../../widgets/stepped_slider.dart';
import 'auto_download_screen.dart' show kVideoSizeStops;
import 'storage_labels.dart';

/// Save to Photos for one kind of chat: photos, videos, and the largest video
/// worth copying into the library.
///
/// Turning either on asks for photo library access right here, the one moment
/// the request makes sense. If it is refused the switch stays off and a toast
/// says why, rather than showing a rule that can never run.
class SaveToPhotosScreen extends StatelessWidget {
  const SaveToPhotosScreen({super.key, required this.chat});

  final ChatClass chat;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final prefs = SettingsStore.instance.dataPrefs;
        final rule = prefs.saveIn(chat);

        Future<void> save(SaveToPhotos next) async {
          final turningOn = (next.photos && !rule.photos) ||
              (next.videos && !rule.videos);
          if (turningOn && !await GalleryAutoSave.ensureAccess()) {
            if (context.mounted) {
              AppToast.of(context).show(l10n.saveToPhotosNoAccess,
                  tone: ToastTone.danger);
            }
            return;
          }
          final p = SettingsStore.instance.dataPrefs;
          await SettingsStore.instance.setDataPrefs(
              p.copyWith(saveToPhotos: {...p.saveToPhotos, chat: next}));
        }

        final at = kVideoSizeStops.indexOf(rule.maxVideoBytes);
        return SettingsPage(
          title: chatClassLabel(l10n, chat),
          children: [
            GroupedSection(
              header: l10n.saveToPhotosHeader,
              footer: l10n.saveToPhotosFooter,
              children: [
                GroupedRow.toggle(
                  icon: CupertinoIcons.photo_fill,
                  tone: storageTone(StorageKind.photos),
                  title: l10n.storageKindPhotos,
                  value: rule.photos,
                  onChanged: (v) {
                    HapticFeedback.lightImpact();
                    save(rule.copyWith(photos: v));
                  },
                ),
                GroupedRow.toggle(
                  icon: CupertinoIcons.videocam_fill,
                  tone: storageTone(StorageKind.videos),
                  title: l10n.storageKindVideos,
                  value: rule.videos,
                  onChanged: (v) {
                    HapticFeedback.lightImpact();
                    save(rule.copyWith(videos: v));
                  },
                ),
              ],
            ),
            if (rule.videos)
              GroupedSection(
                header: l10n.saveToPhotosMaxVideoHeader,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: SteppedSlider(
                      labels: [
                        for (final s in kVideoSizeStops) mbLabel(s),
                      ],
                      index: at < 0 ? null : at,
                      onChanged: (i) => save(
                          rule.copyWith(maxVideoBytes: kVideoSizeStops[i])),
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
