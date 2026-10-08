import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../backend/chat_api.dart';
import '../../data/chat_repository.dart';
import '../../data/settings_store.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../media/storage/data_prefs.dart';
import '../../media/storage/data_usage_store.dart';
import '../../media/storage/network_kind.dart';
import '../../media/storage/storage_kinds.dart';
import '../../media/storage/storage_service.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/pull_down_menu.dart';
import '../../widgets/settings_pickers.dart';
import '../../widgets/sheet_kit.dart';
import 'auto_download_screen.dart';
import 'data_usage_screen.dart';
import 'save_to_photos_screen.dart';
import 'storage_labels.dart';
import 'storage_usage_screen.dart';

/// Settings → Data and Storage.
///
/// Telegram's page in this app's kit: storage and data usage at the top, each
/// with its total; automatic download per network; Save to Photos per kind of
/// chat; and the calls data saver. The network you are on right now is
/// marked, so "which of these two rows applies to me" never needs working out.
class DataStorageScreen extends StatefulWidget {
  const DataStorageScreen({super.key, required this.repo, required this.api});

  final ChatRepository repo;
  final ChatApi api;

  @override
  State<DataStorageScreen> createState() => _DataStorageScreenState();
}

class _DataStorageScreenState extends State<DataStorageScreen> {
  late final Listenable _deps = Listenable.merge([
    SettingsStore.instance,
    StorageService.instance,
    DataUsageStore.instance,
    NetworkKindMonitor.instance,
  ]);

  @override
  void initState() {
    super.initState();
    unawaited(StorageService.instance.scan());
  }

  void _push(WidgetBuilder b) =>
      Navigator.of(context).push(MaterialPageRoute(builder: b));

  Future<void> _resetDownloads() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showIosActionSheet<bool>(
      context,
      title: l10n.autoDownloadResetTitle,
      actions: [
        IosSheetAction(label: l10n.autoDownloadReset, value: true, destructive: true),
      ],
    );
    if (ok != true) return;
    HapticFeedback.mediumImpact();
    final d = DataStoragePrefs.defaults;
    await SettingsStore.instance.setDataPrefs(SettingsStore.instance.dataPrefs
        .copyWith(cellular: d.cellular, wifi: d.wifi));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _deps, builder: (context, _) => _build());
  }

  Widget _build() {
    final l10n = AppLocalizations.of(context);
    final theme = ThemeScope.of(context);
    final prefs = SettingsStore.instance.dataPrefs;
    final storage = StorageService.instance;
    final now = NetworkKindMonitor.instance.current;
    final defaults = DataStoragePrefs.defaults;
    final customised = prefs.cellular.presetFor(NetKind.cellular) !=
            defaults.cellular.presetFor(NetKind.cellular) ||
        prefs.wifi.presetFor(NetKind.wifi) !=
            defaults.wifi.presetFor(NetKind.wifi) ||
        prefs.cellular.enabled != defaults.cellular.enabled ||
        prefs.wifi.enabled != defaults.wifi.enabled;

    Widget nowTag() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: quietFill(theme),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(l10n.dataStorageNowTag,
              style: groupedMetaStyle(theme).copyWith(
                  fontWeight: FontWeight.w600, color: theme.accent)),
        );

    GroupedRow netRow(NetKind net) => GroupedRow(
          icon: net == NetKind.cellular
              ? CupertinoIcons.antenna_radiowaves_left_right
              : CupertinoIcons.wifi,
          tone: net == NetKind.cellular ? TileTone.green : TileTone.blue,
          title: net == NetKind.cellular
              ? l10n.dataStorageUsingCellular
              : l10n.dataStorageUsingWifi,
          titleTrailing: net == now ? nowTag() : null,
          subtitle: downloadSummary(l10n, prefs.downloadsOn(net)),
          onTap: () => _push((_) => AutoDownloadScreen(net: net)),
        );

    return SettingsPage(
      title: l10n.dataStorageTitle,
      children: [
        GroupedSection(
          children: [
            GroupedRow(
              icon: CupertinoIcons.chart_pie_fill,
              tone: TileTone.orange,
              title: l10n.storageUsageTitle,
              value: storage.calculating ? '…' : bytesLabel(storage.report.total),
              onTap: () => _push((_) =>
                  StorageUsageScreen(repo: widget.repo, api: widget.api)),
            ),
            GroupedRow(
              icon: CupertinoIcons.chart_bar_fill,
              tone: TileTone.purple,
              title: l10n.dataUsageTitle,
              value: bytesLabel(DataUsageStore.instance.total().total),
              onTap: () => _push((_) => const DataUsageScreen()),
            ),
          ],
        ),
        GroupedSection(
          header: l10n.dataStorageAutoDownloadHeader,
          children: [
            netRow(NetKind.cellular),
            netRow(NetKind.wifi),
            // Only when there is something to reset: a row that does nothing
            // when tapped reads as broken.
            if (customised)
              GroupedRow(
                icon: CupertinoIcons.arrow_counterclockwise,
                tone: TileTone.gray,
                title: l10n.autoDownloadReset,
                onTap: _resetDownloads,
              ),
          ],
        ),
        GroupedSection(
          header: l10n.dataStorageSaveHeader,
          footer: l10n.dataStorageSaveFooter,
          children: [
            for (final c in ChatClass.values)
              GroupedRow(
                icon: chatClassIcon(c),
                tone: chatClassTone(c),
                title: chatClassLabel(l10n, c),
                value: saveSummary(l10n, prefs.saveIn(c)),
                onTap: () => _push((_) => SaveToPhotosScreen(chat: c)),
              ),
          ],
        ),
        GroupedSection(
          header: l10n.dataStorageCallsHeader,
          footer: l10n.dataStorageCallsFooter,
          children: [
            PullDownRow<CallDataSaver>(
              icon: CupertinoIcons.phone_fill,
              tone: TileTone.green,
              title: l10n.dataStorageLessDataForCalls,
              value: prefs.callDataSaver,
              options: CallDataSaver.values,
              labelOf: (c) => callSaverLabel(l10n, c),
              onChanged: (c) => SettingsStore.instance
                  .setDataPrefs(prefs.copyWith(callDataSaver: c)),
            ),
          ],
        ),
      ],
    );
  }
}
