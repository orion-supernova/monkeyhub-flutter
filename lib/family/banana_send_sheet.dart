import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/banana_glyph.dart';
import '../keyboard/focusable_tap.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/theme_scope.dart';
import '../widgets/action_buttons.dart';
import '../widgets/adaptive_sheet.dart';
import '../widgets/labeled_field.dart';
import '../widgets/sheet_kit.dart' show SheetFrame;

/// Asks a guardian how many bananas to send (25, 50, 100 or their own
/// number, 1 to 1000). Resolves null when dismissed.
///
/// Shared by the approvals card ("Send bananas" instead of a yes) and the
/// child's Bananas screen, so the amounts and the cap live in one place.
Future<int?> showSendBananasSheet(
  BuildContext context, {
  required String childName,
}) {
  return showAdaptiveSheet<int>(
    context,
    builder: (_) => _SendBananasSheet(childName: childName),
  );
}

const _presets = [25, 50, 100];
const kMaxBananaGift = 1000;

class _SendBananasSheet extends StatefulWidget {
  const _SendBananasSheet({required this.childName});
  final String childName;

  @override
  State<_SendBananasSheet> createState() => _SendBananasSheetState();
}

class _SendBananasSheetState extends State<_SendBananasSheet> {
  int _amount = 50;
  bool _custom = false;
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _pick(int v) {
    HapticFeedback.selectionClick();
    setState(() {
      _custom = false;
      _amount = v;
    });
  }

  void _onText(String s) {
    final n = int.tryParse(s) ?? 0;
    setState(() => _amount = n.clamp(0, kMaxBananaGift));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    final l10n = AppLocalizations.of(context);
    final valid = _amount >= 1 && _amount <= kMaxBananaGift;
    return SheetFrame(
      title: l10n.bananasSendTitle(widget.childName),
      showClose: true,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in _presets)
                  _Chip(
                    selected: !_custom && _amount == p,
                    onTap: () => _pick(p),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BananaGlyph(size: 16),
                        const SizedBox(width: 6),
                        Text('$p'),
                      ],
                    ),
                  ),
                _Chip(
                  selected: _custom,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _custom = true;
                      _amount = int.tryParse(_text.text) ?? 0;
                    });
                  },
                  child: Text(l10n.bananasCustom),
                ),
              ],
            ),
            if (_custom) ...[
              const SizedBox(height: 14),
              SheetTextField(
                controller: _text,
                hint: l10n.bananasCustomHint,
                autofocus: true,
                maxLength: 4,
                keyboardType: TextInputType.number,
                textCapitalization: TextCapitalization.none,
                onChanged: _onText,
              ),
            ],
            const SizedBox(height: 18),
            DefaultTextStyle.merge(
              style: TextStyle(color: theme.ink),
              child: SheetActionButton(
                label: l10n.bananasSendAction(valid ? _amount : 0),
                onTap: valid ? () => Navigator.of(context).pop(_amount) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.selected, required this.onTap, required this.child});
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return FocusableTap(
      onTap: onTap,
      selected: selected,
      radius: 22,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? theme.accent.withValues(alpha: 0.16)
              : theme.ink.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? theme.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: selected ? theme.accent : theme.ink,
          ),
          child: child,
        ),
      ),
    );
  }
}
