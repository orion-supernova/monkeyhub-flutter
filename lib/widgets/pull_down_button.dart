import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import '../ui/native/native_control.dart';
import '../ui/foundation/ui_kit.dart';
import 'glass_buttons.dart';
import 'liquid_glass.dart' show GlassTone;
import 'pull_down_menu.dart';

/// THE button that opens a pull-down menu: an icon button (`...`, sort,
/// filter) or a labelled one ("Sort: Name"), plus its [items] and what to do
/// with the pick.
///
/// In the liquid kit on iOS 26 this is a real SwiftUI `Menu`: the glass button
/// itself morphs into the system menu. Every other kit draws the same
/// [GlassIconButton] / [GlassPillButton] and opens [showPullDownMenu] from it,
/// so a caller writes the button once.
///
/// Give it an [icon] for the round form or a [label] for the pill form (an
/// [icon] beside a [label] leads the label). The long-press menus that lift a
/// preview (`showMessageActionMenu`, `showChatRowActionMenu`) and row-anchored
/// pickers ([PullDownRow]) keep calling [showPullDownMenu] directly: their
/// trigger is not a button.
class PullDownButton<T> extends StatefulWidget {
  const PullDownButton({
    super.key,
    required this.items,
    required this.onSelected,
    required this.semanticLabel,
    this.icon = CupertinoIcons.ellipsis,
    this.label,
    this.tone = GlassTone.app,
    this.size,
  });

  final List<PullDownItem<T>> items;
  final ValueChanged<T> onSelected;
  final String semanticLabel;

  /// The glyph of the round form; leads [label] in the pill form.
  final IconData? icon;

  /// Non-null draws the labelled pill form.
  final String? label;
  final GlassTone tone;

  /// The round form's diameter; null follows the density.
  final double? size;

  @override
  State<PullDownButton<T>> createState() => _PullDownButtonState<T>();
}

class _PullDownButtonState<T> extends State<PullDownButton<T>> {
  final GlobalKey _anchor = GlobalKey(debugLabel: 'pull-down-button');

  Future<void> _open() async {
    final picked = await showPullDownMenu<T>(
      context: context,
      anchorKey: _anchor,
      items: widget.items,
    );
    if (picked != null && mounted) widget.onSelected(picked);
  }

  Widget _flutter(BuildContext context) {
    final label = widget.label;
    final enabled = widget.items.isNotEmpty;
    return KeyedSubtree(
      key: _anchor,
      child: label == null
          ? GlassIconButton(
              icon: widget.icon,
              semanticLabel: widget.semanticLabel,
              tone: widget.tone,
              size: widget.size,
              onTap: enabled ? _open : null,
            )
          : GlassPillButton(
              label: label,
              icon: CupertinoIcons.chevron_up_chevron_down,
              semanticLabel: widget.semanticLabel,
              tone: widget.tone,
              onTap: enabled ? _open : null,
            ),
    );
  }

  Widget _liquid(BuildContext context) {
    final size = widget.size ?? 44.0;
    final label = widget.label;
    final symbol = sfSymbolFor(widget.icon);
    final anyChecked = widget.items.any((i) => i.checked);
    final specs = <NativeMenuItemSpec>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (item.startsGroup && i > 0) specs.add(const NativeMenuItemSpec.divider());
      specs.add(
        NativeMenuItemSpec(
          id: '$i',
          label: item.label,
          symbol: sfSymbolFor(item.icon),
          destructive: item.destructive,
          checked: anyChecked ? item.checked : null,
        ),
      );
    }
    return NativeControl(
      standIn: FlutterSkinsOnly(child: Builder(builder: build)),
      size: label == null ? Size.square(size) : null,
      spec: NativeSpec.menu(
        label: label,
        symbol: label == null ? symbol : null,
        items: specs,
        size: size,
        symbolSize: size * 17 / 44,
        enabled: widget.items.isNotEmpty,
      ),
      onEvent: (event, value) {
        if (event != 'select') return;
        final i = int.tryParse('$value');
        if (i != null && i >= 0 && i < widget.items.length) {
          widget.onSelected(widget.items[i].value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final native =
        widget.tone == GlassTone.app &&
        NativeControl.readyIn(context) &&
        (widget.label != null || sfSymbolFor(widget.icon) != null);
    return KitSwitch(glass: _flutter, liquid: native ? _liquid : null);
  }
}
