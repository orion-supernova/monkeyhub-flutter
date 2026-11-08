import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../data/room_filter.dart';
import '../../widgets/count_badge.dart';
import '../../theme/theme_scope.dart';
import '../../widgets/ios_kit.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/liquid_glass.dart' show GlassTone;
import '../../widgets/notice.dart';
import '../../widgets/password_field.dart';
import '../../widgets/pull_down_button.dart';
import '../../widgets/pull_down_menu.dart';
import '../../widgets/room_filter_bar.dart';
import '../../widgets/search_field.dart';
import '../../widgets/status_pill.dart';
import '../../widgets/value_slider.dart';
import '../foundation/ui_kit.dart';
import '../native/native_control.dart';

/// Every shared control in the ACTIVE kit, with real state, on one page.
///
/// For design review and for simulator screenshots: switch Settings › Glass
/// between Liquid / Frosted / Material / Lite (and Native controls between
/// Everything and Just the tab bar), come back here and compare. Controls with
/// a native form show it only where [NativeControl.readyIn] says so.
///
/// Developer tool: its labels are English on purpose.
class ControlsLabScreen extends StatefulWidget {
  const ControlsLabScreen({super.key});

  @override
  State<ControlsLabScreen> createState() => _ControlsLabScreenState();
}

class _ControlsLabScreenState extends State<ControlsLabScreen> {
  bool _switch = true;
  String _segment = 'a';
  double _slider = 0.4;
  final _text = TextEditingController(text: 'Hello');
  final _password = TextEditingController();
  final _search = TextEditingController();
  final _focus = FocusNode();
  String _picked = 'none';
  DateTime _date = DateTime.now().add(const Duration(hours: 1));
  bool _check = true;
  bool _radio = false;
  RoomFilter _filter = RoomFilter(const {});
  int _taps = 0;

  /// `--dart-define=LAB_SECTION=2` scrolls to that section (0-3) on open, so
  /// a headless simulator screenshot can reach every control.
  static const int _openSection = int.fromEnvironment('LAB_SECTION');
  final _sections = List.generate(4, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    if (_openSection > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Later sections are not built yet in the lazy list, so scroll the
        // list itself (through the first section, which always is), then
        // settle on the section once it exists.
        final first = _sections[0].currentContext;
        if (first == null || !first.mounted) return;
        final position = Scrollable.of(first).position;
        position.jumpTo(
          (_openSection * 640.0).clamp(0.0, position.maxScrollExtent),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final c = _sections[_openSection.clamp(0, 3)].currentContext;
          if (c != null && c.mounted) Scrollable.ensureVisible(c);
        });
      });
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _password.dispose();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _tap([String? what]) => setState(() {
    _taps++;
    if (what != null) _picked = what;
  });

  Widget _row(String title, Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: groupedTitleStyle(ThemeScope.of(context)),
          ),
        ),
        child,
      ],
    ),
  );

  Widget _block(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final kit = UiKit.of(context);
    final native = NativeControl.readyIn(context);
    final items = <PullDownItem<String>>[
      PullDownItem(value: 'one', label: 'One', icon: CupertinoIcons.star, checked: _picked == 'one'),
      PullDownItem(value: 'two', label: 'Two', icon: CupertinoIcons.heart, checked: _picked == 'two'),
      const PullDownItem(
        value: 'del',
        label: 'Delete',
        icon: CupertinoIcons.trash,
        destructive: true,
        startsGroup: true,
      ),
    ];
    return IosPage(
      title: 'Controls lab',
      subtitle: 'Kit: ${kit.name} · native controls: ${native ? 'on' : 'off'}'
          ' · taps $_taps · picked $_picked',
      children: [
        GroupedSection(
          key: _sections[0],
          header: 'Buttons',
          children: [
            _row(
              'Icon, back, close',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassIconButton(
                    icon: CupertinoIcons.plus,
                    semanticLabel: 'Add',
                    onTap: () => _tap('icon'),
                  ),
                  const SizedBox(width: 8),
                  GlassBackButton(onTap: () => _tap('back')),
                  const SizedBox(width: 8),
                  GlassCloseButton(onTap: () => _tap('close')),
                ],
              ),
            ),
            _row(
              'Button group',
              GlassButtonGroup(
                tone: GlassTone.app,
                items: [
                  GlassGroupItem(
                    icon: CupertinoIcons.camera,
                    semanticLabel: 'Camera',
                    onTap: () => _tap('camera'),
                  ),
                  GlassGroupItem(
                    icon: CupertinoIcons.photo_on_rectangle,
                    semanticLabel: 'Photos',
                    onTap: () => _tap('photos'),
                  ),
                  GlassGroupItem(
                    icon: CupertinoIcons.mic,
                    semanticLabel: 'Voice',
                    onTap: () => _tap('voice'),
                  ),
                ],
              ),
            ),
            _row(
              'Pill',
              GlassPillButton(label: 'Pill', onTap: () => _tap('pill')),
            ),
            _row(
              'Pill, tinted',
              GlassPillButton(
                label: 'Send',
                tint: Theme.of(context).colorScheme.primary,
                onTap: () => _tap('pill-tint'),
              ),
            ),
            _row(
              'Row pill',
              RowPillButton(label: 'Remove', onTap: () => _tap('row-pill')),
            ),
            _row(
              'Row pill, filled',
              RowPillButton(
                label: 'Add',
                filled: true,
                onTap: () => _tap('row-pill-filled'),
              ),
            ),
            _block(SheetActionButton(label: 'Primary', onTap: () => _tap('primary'))),
            _block(SheetActionButton(label: 'Tonal', tonal: true, onTap: () => _tap('tonal'))),
            _block(
              SheetActionButton(
                label: 'Destructive',
                destructive: true,
                onTap: () => _tap('destructive'),
              ),
            ),
            _row(
              'Text link',
              TextLinkButton(label: 'Learn more', onTap: () => _tap('link')),
            ),
            // The action tiles of a profile and the call details sheet: native
            // `tile` plates under native controls, ChromeDisc.plate otherwise.
            _block(
              SheetQuickActions(
                actions: [
                  QuickAction(
                    icon: CupertinoIcons.phone_fill,
                    label: 'Voice call',
                    onTap: () => _tap('tile-voice'),
                  ),
                  QuickAction(
                    icon: CupertinoIcons.videocam_fill,
                    label: 'Video call',
                    onTap: () => _tap('tile-video'),
                  ),
                  QuickAction(
                    icon: CupertinoIcons.bubble_left_fill,
                    label: 'Message',
                    onTap: () => _tap('tile-message'),
                  ),
                  QuickAction(
                    icon: CupertinoIcons.star_slash_fill,
                    label: 'Remove from favourites',
                    onTap: () => _tap('tile-fav'),
                  ),
                ],
              ),
            ),
          ],
        ),
        GroupedSection(
          key: _sections[1],
          header: 'Toggles and pickers',
          children: [
            GroupedRow.toggle(
              title: 'Row switch',
              value: _switch,
              onChanged: (v) => setState(() => _switch = v),
            ),
            _block(
              IosSegmentedControl<String>(
                segments: const [
                  IosSegment(value: 'a', label: 'First'),
                  IosSegment(value: 'b', label: 'Second'),
                  IosSegment(value: 'c', label: 'Third'),
                ],
                value: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
            ),
            _block(
              ValueSlider(
                value: _slider,
                onChanged: (v) => setState(() => _slider = v),
              ),
            ),
            _row(
              'Pull-down: icon',
              PullDownButton<String>(
                items: items,
                semanticLabel: 'More',
                onSelected: (v) => setState(() => _picked = v),
              ),
            ),
            _row(
              'Pull-down: label',
              PullDownButton<String>(
                items: items,
                label: 'Sort',
                icon: null,
                semanticLabel: 'Sort',
                onSelected: (v) => setState(() => _picked = v),
              ),
            ),
            _row(
              'Date (compact)',
              _DateField(
                value: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
            ),
          ],
        ),
        GroupedSection(
          key: _sections[2],
          header: 'Fields',
          children: [
            _block(
              ThemedInput(
                controller: _text,
                hint: 'Text field',
                focusNode: _focus,
                onChanged: (_) => setState(() {}),
              ),
            ),
            _block(PasswordField(controller: _password, hint: 'Password')),
            _block(
              SearchField(
                controller: _search,
                hintText: 'Search',
                showCancel: false,
                onChanged: (_) => setState(() {}),
              ),
            ),
            _row(
              'Field text',
              Text(_text.text, style: groupedValueStyle(ThemeScope.of(context))),
            ),
            _row(
              'Clear and focus',
              GlassPillButton(
                label: 'Clear',
                onTap: () => setState(() {
                  _text.clear();
                  _focus.requestFocus();
                }),
              ),
            ),
          ],
        ),
        GroupedSection(
          key: _sections[3],
          header: 'Indicators',
          children: [
            _row(
              'Status pill',
              const StatusPill(label: 'Pinned', icon: CupertinoIcons.pin),
            ),
            _row('Count badge', const CountBadge(count: 7)),
            _block(const Notice('A notice, in the info register.')),
            _block(RoomFilterBar(
              filter: _filter,
              counts: RoomFacetCounts.zero,
              gutter: 0,
              onChanged: (f) => setState(() => _filter = f),
            )),
            _row(
              'Selection check',
              GestureDetector(
                onTap: () => setState(() => _check = !_check),
                child: SelectionCheck(picked: _check),
              ),
            ),
            _row(
              'Selection radio',
              GestureDetector(
                onTap: () => setState(() => _radio = !_radio),
                child: SelectionCheck.radio(picked: _radio),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A date in a row: the native compact picker in the liquid kit, otherwise a
/// button that opens the shared pull-down of quick choices.
class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    if (NativeControl.readyIn(context)) {
      return NativeControl(
        standIn: FlutterSkinsOnly(child: Builder(builder: build)),
        spec: NativeSpec.datePicker(
          ms: value.millisecondsSinceEpoch,
          style: 'compact',
        ),
        onEvent: (event, v) {
          if (event == 'changed' && v is num) {
            onChanged(DateTime.fromMillisecondsSinceEpoch(v.round()));
          }
        },
      );
    }
    return PullDownButton<int>(
      label: '${value.hour.toString().padLeft(2, '0')}:'
          '${value.minute.toString().padLeft(2, '0')}',
      icon: null,
      semanticLabel: 'Time',
      items: const [
        PullDownItem(value: 1, label: 'In an hour'),
        PullDownItem(value: 24, label: 'Tomorrow'),
      ],
      onSelected: (h) => onChanged(DateTime.now().add(Duration(hours: h))),
    );
  }
}
