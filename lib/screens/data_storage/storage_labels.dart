import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../media/file_meta.dart';
import '../../media/storage/data_prefs.dart';
import '../../media/storage/data_usage_store.dart';
import '../../media/storage/storage_kinds.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ios_kit.dart';

/// Names, colours and glyphs for everything the Data and Storage screens
/// show. One table, so a category is the same colour in the chart, its check
/// circle and its tile on every screen.

/// Bytes the way the rest of the app prints them.
String bytesLabel(int bytes) => formatFileSize(bytes);

/// A rule's size cap, as the stops on its slider print it: whole megabytes.
String mbLabel(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

/// A share as Telegram prints it: whole numbers from 10%, one decimal under,
/// and never a "0%" for something that is there.
String percentLabel(int part, int whole) {
  if (whole <= 0 || part <= 0) return '';
  final p = part / whole * 100;
  if (p >= 9.95) return '${p.round()}%';
  if (p < 0.1) return '<0.1%';
  return '${p.toStringAsFixed(1)}%';
}

TileTone storageTone(StorageKind k) => switch (k) {
      StorageKind.photos => TileTone.teal,
      StorageKind.videos => TileTone.blue,
      StorageKind.videoMessages => TileTone.pink,
      StorageKind.voice => TileTone.purple,
      StorageKind.files => TileTone.green,
      StorageKind.stickers => TileTone.orange,
      StorageKind.chatHistory => TileTone.indigo,
      StorageKind.companions => TileTone.red,
      StorageKind.other => TileTone.gray,
    };

Color storageColor(AppTheme theme, StorageKind k) =>
    tileColor(theme, storageTone(k));

String storageLabel(AppLocalizations l10n, StorageKind k) => switch (k) {
      StorageKind.photos => l10n.storageKindPhotos,
      StorageKind.videos => l10n.storageKindVideos,
      StorageKind.videoMessages => l10n.storageKindVideoMessages,
      StorageKind.voice => l10n.storageKindVoice,
      StorageKind.files => l10n.storageKindFiles,
      StorageKind.stickers => l10n.storageKindStickers,
      StorageKind.chatHistory => l10n.storageKindChatHistory,
      StorageKind.companions => l10n.storageKindCompanions,
      StorageKind.other => l10n.storageKindOther,
    };

String usageLabel(AppLocalizations l10n, UsageKind k) => switch (k) {
      UsageKind.photos => l10n.storageKindPhotos,
      UsageKind.videos => l10n.storageKindVideos,
      UsageKind.videoMessages => l10n.storageKindVideoMessages,
      UsageKind.voice => l10n.storageKindVoice,
      UsageKind.files => l10n.storageKindFiles,
      UsageKind.stickers => l10n.storageKindStickers,
      UsageKind.calls => l10n.dataUsageKindCalls,
      UsageKind.other => l10n.storageKindOther,
    };

TileTone usageTone(UsageKind k) => switch (k) {
      UsageKind.photos => storageTone(StorageKind.photos),
      UsageKind.videos => storageTone(StorageKind.videos),
      UsageKind.videoMessages => storageTone(StorageKind.videoMessages),
      UsageKind.voice => storageTone(StorageKind.voice),
      UsageKind.files => storageTone(StorageKind.files),
      UsageKind.stickers => storageTone(StorageKind.stickers),
      UsageKind.calls => TileTone.red,
      UsageKind.other => storageTone(StorageKind.other),
    };

IconData usageIcon(UsageKind k) => switch (k) {
      UsageKind.photos => CupertinoIcons.photo_fill,
      UsageKind.videos => CupertinoIcons.videocam_fill,
      UsageKind.videoMessages => CupertinoIcons.smallcircle_fill_circle_fill,
      UsageKind.voice => CupertinoIcons.mic_fill,
      UsageKind.files => CupertinoIcons.doc_fill,
      UsageKind.stickers => CupertinoIcons.smiley_fill,
      UsageKind.calls => CupertinoIcons.phone_fill,
      UsageKind.other => CupertinoIcons.ellipsis_circle_fill,
    };

String chatClassLabel(AppLocalizations l10n, ChatClass c) => switch (c) {
      ChatClass.privateChats => l10n.dataStorageChatsPrivate,
      ChatClass.groups => l10n.dataStorageChatsGroups,
      ChatClass.publicRooms => l10n.dataStorageChatsPublic,
    };

IconData chatClassIcon(ChatClass c) => switch (c) {
      ChatClass.privateChats => CupertinoIcons.person_fill,
      ChatClass.groups => CupertinoIcons.person_3_fill,
      ChatClass.publicRooms => CupertinoIcons.globe,
    };

TileTone chatClassTone(ChatClass c) => switch (c) {
      ChatClass.privateChats => TileTone.blue,
      ChatClass.groups => TileTone.green,
      ChatClass.publicRooms => TileTone.orange,
    };

String keepLabel(AppLocalizations l10n, KeepMedia k) => switch (k) {
      KeepMedia.forever => l10n.dataStorageKeepNever,
      KeepMedia.month => l10n.dataStorageKeepMonth,
      KeepMedia.week => l10n.dataStorageKeepWeek,
      KeepMedia.day => l10n.dataStorageKeepDay,
    };

String limitLabel(AppLocalizations l10n, CacheLimit c) => switch (c) {
      CacheLimit.unlimited => l10n.dataStorageLimitNone,
      _ => '${c.gigabytes} GB',
    };

String netLabel(AppLocalizations l10n, NetKind n) => switch (n) {
      NetKind.cellular => l10n.dataStorageNetCellular,
      NetKind.wifi => l10n.dataStorageNetWifi,
    };

String callSaverLabel(AppLocalizations l10n, CallDataSaver c) => switch (c) {
      CallDataSaver.never => l10n.dataStorageCallsNever,
      CallDataSaver.cellular => l10n.dataStorageCallsCellular,
      CallDataSaver.always => l10n.dataStorageCallsAlways,
    };

String presetLabel(AppLocalizations l10n, DownloadPreset p) => switch (p) {
      DownloadPreset.low => l10n.autoDownloadPresetLow,
      DownloadPreset.medium => l10n.autoDownloadPresetMedium,
      DownloadPreset.high => l10n.autoDownloadPresetHigh,
    };

/// The one-line summary under "Using Cellular": what will download on its
/// own, at a glance. "Off" when nothing will.
String downloadSummary(AppLocalizations l10n, NetworkDownloadPrefs p) {
  if (!p.enabled) return l10n.dataStorageOff;
  final parts = <String>[
    if (!p.photos.isOff) l10n.storageKindPhotos,
    if (!p.videos.isOff)
      l10n.autoDownloadSummaryUpTo(
          l10n.storageKindVideos, mbLabel(p.videos.maxBytes)),
    if (!p.files.isOff)
      l10n.autoDownloadSummaryUpTo(
          l10n.storageKindFiles, mbLabel(p.files.maxBytes)),
  ];
  return parts.isEmpty ? l10n.autoDownloadSummaryVoiceOnly : parts.join(', ');
}

/// Which kinds of chat a rule covers, in a few words.
String chatsSummary(AppLocalizations l10n, Set<ChatClass> chats) {
  if (chats.isEmpty) return l10n.dataStorageOff;
  if (chats.length == ChatClass.values.length) return l10n.autoDownloadAllChats;
  return [
    for (final c in ChatClass.values)
      if (chats.contains(c)) chatClassLabel(l10n, c),
  ].join(', ');
}

String saveSummary(AppLocalizations l10n, SaveToPhotos s) {
  if (s.photos && s.videos) return l10n.saveToPhotosPhotosAndVideos;
  if (s.photos) return l10n.storageKindPhotos;
  if (s.videos) return l10n.storageKindVideos;
  return l10n.dataStorageOff;
}
