// The Android Material kit, next to the glass kit it must not change.
//
//   flutter test test/design_preview/material_kit_preview.dart
//
// Writes build/design_preview/material_kit_<kit>_<theme>.png for the core set:
// buttons, fields, search, switch, segmented, chips, checks, slider, sheet.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/ui/foundation/ui_kit.dart';
import 'package:monkeyhub/widgets/app_spinner.dart';
import 'package:monkeyhub/widgets/filter_capsule.dart';
import 'package:monkeyhub/widgets/ios_kit.dart';
import 'package:monkeyhub/widgets/labeled_field.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart';
import 'package:monkeyhub/widgets/password_field.dart';
import 'package:monkeyhub/widgets/search_field.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';
import 'package:monkeyhub/widgets/value_slider.dart';

import 'preview_kit.dart';

class _Board extends StatefulWidget {
  const _Board();
  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  final _text = TextEditingController(text: 'Murat');
  final _empty = TextEditingController();
  final _search = TextEditingController();
  final _pass = TextEditingController(text: 'hunter2');
  bool _on = true;
  String _seg = 'a';
  double _v = 0.4;

  @override
  Widget build(BuildContext context) {
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(t, style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8E))),
        );
    return Material(
      type: MaterialType.transparency,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 56, 16, 24),
        children: [
          label('icon buttons: back, close, plain, tinted, disabled, chrome'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlassBackButton(onTap: () {}),
              const SizedBox(width: 8),
              GlassCloseButton(onTap: () {}),
              const SizedBox(width: 8),
              GlassIconButton(icon: Icons.add, onTap: () {}),
              const SizedBox(width: 8),
              GlassIconButton(icon: Icons.add, tint: const Color(0xFF3478F6), onTap: () {}),
              const SizedBox(width: 8),
              const GlassIconButton(icon: Icons.add, onTap: null),
              const SizedBox(width: 8),
              GlassPillButton(label: 'Done', onTap: () {}),
              const SizedBox(width: 8),
              GlassPillButton(label: 'Send', tint: const Color(0xFF3478F6), onTap: () {}),
            ],
          ),
          label('actions: primary, tonal, destructive, busy, disabled, link, row pill'),
          SheetActionButton(label: 'Continue', onTap: () {}),
          const SizedBox(height: 8),
          SheetActionButton(label: 'Not now', tonal: true, onTap: () {}),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: SheetActionButton(label: 'Delete', destructive: true, onTap: () {})),
              const SizedBox(width: 8),
              Expanded(child: SheetActionButton(label: 'Saving', busy: true, onTap: () {})),
              const SizedBox(width: 8),
              const Expanded(child: SheetActionButton(label: 'Off', onTap: null)),
            ],
          ),
          Row(
            children: [
              TextLinkButton(label: 'Not now', onTap: () {}),
              const Spacer(),
              RowPillButton(label: 'Add', filled: true, onTap: () {}),
              RowPillButton(label: 'Remove', destructive: true, onTap: () {}),
              const SizedBox(width: 12),
              const AppSpinner(),
            ],
          ),
          label('fields'),
          SheetTextField(controller: _text, hint: 'Name', leadingIcon: Icons.person_outline),
          const SizedBox(height: 8),
          ThemedInput(controller: _empty, hint: 'Room name'),
          const SizedBox(height: 8),
          PasswordField(controller: _pass, hint: 'Password'),
          label('search'),
          SearchField(
            controller: _search,
            hintText: 'Search people',
            onChanged: (_) {},
            showCancel: false,
          ),
          label('switch, checks, radio'),
          Row(
            children: [
              RowSwitch(value: _on, onChanged: (v) => setState(() => _on = v)),
              RowSwitch(value: false, onChanged: (_) {}),
              const SizedBox(width: 16),
              const SelectionCheck(picked: true),
              const SizedBox(width: 8),
              const SelectionCheck(picked: false),
              const SizedBox(width: 16),
              const SelectionCheck.radio(picked: true),
              const SizedBox(width: 8),
              const SelectionCheck.radio(picked: false),
            ],
          ),
          label('segmented'),
          IosSegmentedControl<String>(
            segments: const [
              IosSegment(value: 'a', label: 'Photos'),
              IosSegment(value: 'b', label: 'Videos'),
              IosSegment(value: 'c', label: 'Files'),
            ],
            value: _seg,
            onChanged: (v) => setState(() => _seg = v),
          ),
          label('chips'),
          Wrap(
            spacing: 8,
            children: [
              FilterCapsule(label: 'All', active: true, count: 12, onTap: () {}),
              FilterCapsule(label: 'Unread', active: false, count: 3, onTap: () {}),
              FilterCapsule(label: 'Groups', active: false, onTap: () {}),
            ],
          ),
          label('slider'),
          ValueSlider(value: _v, onChanged: (v) => setState(() => _v = v)),
          label('surface'),
          LiquidGlass(
            shape: LiquidGlassShape.rounded,
            radius: 16,
            padding: const EdgeInsets.all(16),
            child: const Text('A glass surface in this kit'),
          ),
        ],
      ),
    );
  }
}

Widget _sheet() => Align(
      alignment: Alignment.bottomCenter,
      child: SheetFrame(
        title: 'Sheet title',
        confirm: SheetConfirm(onTap: () {}, label: 'Done'),
        footer: SheetActionButton(label: 'Save', onTap: () {}),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Sheet body'),
        ),
      ),
    );

void main() {
  setUpAll(loadPreviewFonts);

  for (final kit in [UiKit.material, UiKit.glass]) {
    for (final id in ['basic', 'basic_daylight']) {
      for (final sheet in [false, true]) {
        final name = 'material_kit_${kit.name}_${sheet ? 'sheet_' : ''}$id.png';
        testWidgets('${kit.name} $id ${sheet ? 'sheet' : 'board'}', (tester) async {
          final theme = ThemeController.byId(id);
          await snap(
            tester,
            previewApp(
              theme,
              UiKitScope(kit: kit, child: sheet ? _sheet() : const _Board()),
            ),
            name,
            size: sheet ? kIphone16Pro : const Size(393, 1330),
            settle: const Duration(milliseconds: 500),
          );
        });
      }
    }
  }
}
