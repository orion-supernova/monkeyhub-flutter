import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../media/storage/data_usage_store.dart';
import '../../media/storage/storage_kinds.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/donut_chart.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/settings_pickers.dart';
import '../../widgets/sheet_kit.dart';
import 'storage_labels.dart';
import 'usage_widgets.dart';

/// Data Usage: what the app has moved over the network, by kind, on cellular,
/// on Wi-Fi or both, since the counters were last reset.
///
/// Every row opens into what was sent and what was received. Under the
/// breakdown, the totals in each direction and the reset. The footer says
/// plainly what is not counted (chat sync), rather than letting a total
/// imply it is everything.
class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({super.key});

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  /// Null is All.
  NetKind? _net;
  UsageKind? _focused;

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    final ok = await showIosActionSheet<bool>(
      context,
      title: l10n.dataUsageResetTitle,
      message: l10n.dataUsageResetBody,
      actions: [
        IosSheetAction(label: l10n.dataUsageReset, value: true, destructive: true),
      ],
    );
    if (ok != true) return;
    HapticFeedback.mediumImpact();
    await DataUsageStore.instance.reset();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: DataUsageStore.instance,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final store = DataUsageStore.instance;
    final net = _net;
    final total = store.total(net: net);
    final kinds = [
      for (final k in UsageKind.values)
        if (store.tally(k, net: net).total > 0) k,
    // Ordered by the all-networks total whichever tab is showing, so
    // switching tabs changes the numbers and never shuffles the rows.
    ]..sort((a, b) => store.tally(b).total.compareTo(store.tally(a).total));
    final since = MaterialLocalizations.of(context).formatMediumDate(store.since);
    final focused = _focused;

    return SettingsPage(
      title: l10n.dataUsageTitle,
      children: [
        UsageHero(
          segments: [
            for (final k in UsageKind.values)
              DonutSegment(
                id: k,
                value: store.tally(k, net: net).total.toDouble(),
                color: tileColor(theme, usageTone(k)),
              ),
          ],
          centerLabel: '',
          centerBytes: focused == null
              ? total.total
              : store.tally(focused, net: net).total,
          centerCaption: focused == null ? null : usageLabel(l10n, focused),
          highlighted: focused,
          onSegmentTap: (id) => setState(
              () => _focused = id == _focused ? null : id as UsageKind?),
          subtitle: l10n.dataUsageSince(since),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: IosSegmentedControl<NetKind?>(
            segments: [
              IosSegment(value: null, label: l10n.dataUsageAll),
              IosSegment(
                  value: NetKind.cellular,
                  label: l10n.dataStorageNetCellular,
                  icon: CupertinoIcons.antenna_radiowaves_left_right),
              IosSegment(
                  value: NetKind.wifi,
                  label: l10n.dataStorageNetWifi,
                  icon: CupertinoIcons.wifi),
            ],
            value: net,
            onChanged: (n) => setState(() {
              _net = n;
              _focused = null;
            }),
          ),
        ),
        // The list and the empty line trade places in one resize and a
        // fade, rather than the page below jumping by a whole section.
        AnimatedSize(
          duration: theme.motionMed,
          curve: theme.motionCurve,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: theme.motionFast,
            child: KeyedSubtree(
              key: ValueKey(kinds.isEmpty),
              child: kinds.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 28),
                      child: Text(l10n.dataUsageNothingYet,
                          textAlign: TextAlign.center,
                          style: groupedFooterStyle(theme)),
                    )
                  : GroupedSection(
                      footer: l10n.dataUsageTapHint,
                      children: [
                        for (final k in kinds)
                          UsageCategoryRow(
                            // Keyed by network too, so switching the filter
                            // doesn't carry an opened row's state onto
                            // different numbers.
                            key: ValueKey('$k|$net'),
                            icon: usageIcon(k),
                            tone: usageTone(k),
                            color: tileColor(theme, usageTone(k)),
                            title: usageLabel(l10n, k),
                            percent: percentLabel(
                                store.tally(k, net: net).total, total.total),
                            bytes: store.tally(k, net: net).total,
                            details: [
                              (
                                label: l10n.dataUsageReceived,
                                bytes: store.tally(k, net: net).received,
                                icon: CupertinoIcons.arrow_down,
                              ),
                              (
                                label: l10n.dataUsageSent,
                                bytes: store.tally(k, net: net).sent,
                                icon: CupertinoIcons.arrow_up,
                              ),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
        ),
        GroupedSection(
          header: l10n.dataUsageTotalHeader,
          footer: l10n.dataUsageFootnote,
          children: [
            GroupedRow(
              icon: CupertinoIcons.arrow_up,
              tone: TileTone.blue,
              title: l10n.dataUsageSent,
              value: bytesLabel(total.sent),
            ),
            GroupedRow(
              icon: CupertinoIcons.arrow_down,
              tone: TileTone.green,
              title: l10n.dataUsageReceived,
              value: bytesLabel(total.received),
            ),
          ],
        ),
        GroupedSection(
          children: [
            GroupedRow(
              title: l10n.dataUsageReset,
              destructive: true,
              onTap: _reset,
            ),
          ],
        ),
      ],
    );
  }
}
