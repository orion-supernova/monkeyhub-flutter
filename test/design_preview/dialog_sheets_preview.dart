// The dialog family: the Devices menu action sheet, the Remove confirm sheet and
// a generic alert, across light, dark and character themes.
//
//   flutter test test/design_preview/dialog_sheets_preview.dart
//   flutter test test/design_preview/dialog_sheets_preview.dart --plain-name tr
//
// PNGs: build/design_preview/dialog_<kind>_<theme>[_tr][_x13].png
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/l10n/generated/app_localizations.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/adaptive_sheet.dart';
import 'package:monkeyhub/widgets/destructive_sheet.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';

import 'preview_kit.dart';

/// A page with something on it, so the dim and the sheet's edge read.
class _Page extends StatefulWidget {
  const _Page({required this.open});
  final void Function(BuildContext context) open;
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.open(context));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeScope.of(context);
    return Scaffold(
      backgroundColor: theme.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 0),
        children: [
          Text('Linked devices', style: theme.displayLarge),
          const SizedBox(height: 16),
          for (final n in const ["Murat's iPhone 16 Pro", 'MacBook Pro', 'Chrome on Windows'])
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                Expanded(child: Text(n, style: theme.bodyEmph)),
                Icon(CupertinoIcons.ellipsis, color: theme.inkSoft),
              ]),
            ),
        ],
      ),
    );
  }
}

typedef _Open = void Function(BuildContext c, {required bool tr});

void _menu(BuildContext c, {required bool tr}) {
  final l10n = AppLocalizations.of(c);
  showIosActionSheet<String>(
    c,
    title: tr ? "Murat'ın iPhone 16 Pro cihazı" : "Murat's iPhone 16 Pro",
    actions: [
      IosSheetAction(
        label: l10n.acctRemove,
        value: 'remove',
        destructive: true,
        icon: CupertinoIcons.trash,
      ),
    ],
    cancelLabel: MaterialLocalizations.of(c).cancelButtonLabel,
  );
}

void _menuMulti(BuildContext c, {required bool tr}) {
  showIosActionSheet<String>(
    c,
    title: tr ? 'Mesaj seçenekleri' : 'Message options',
    message: tr ? 'Bu mesajla ne yapmak istersiniz?' : 'What would you like to do with it?',
    actions: [
      IosSheetAction(
        label: tr ? 'Kopyala' : 'Copy',
        value: 'copy',
        icon: CupertinoIcons.doc_on_doc,
      ),
      IosSheetAction(
        label: tr ? 'Yanıtla' : 'Reply',
        value: 'reply',
        icon: CupertinoIcons.reply,
      ),
      IosSheetAction(
        label: tr ? 'Sil' : 'Delete',
        value: 'delete',
        destructive: true,
        icon: CupertinoIcons.trash,
      ),
    ],
  );
}

void _confirm(BuildContext c, {required bool tr}) {
  final l10n = AppLocalizations.of(c);
  showConfirmSheet(
    c,
    headline: l10n.acctRemoveDeviceTitle,
    body: l10n.devicesScreenRemoveBody(tr ? "Murat'ın iPhone 16 Pro cihazı" : "Murat's iPhone 16 Pro"),
    confirmLabel: l10n.acctRemove,
  );
}

void _alert(BuildContext c, {required bool tr}) {
  showIosAlert<bool>(
    c,
    title: tr ? 'Bu cam ayarları kaydedilsin mi?' : 'Save these glass settings?',
    message: tr
        ? 'Ayarlar bu cihazda saklanır ve istediğiniz zaman değiştirebilirsiniz.'
        : 'They are kept on this device and you can change them any time.',
    actions: [
      IosAlertAction(
        label: tr ? 'Vazgeç' : 'Not now',
        value: false,
        cancel: true,
      ),
      IosAlertAction(label: tr ? 'Kaydet' : 'Save', value: true, preferred: true),
    ],
  );
}

void _alertDestructive(BuildContext c, {required bool tr}) {
  showIosAlert<bool>(
    c,
    title: tr ? 'Hesabınız silinsin mi?' : 'Delete your account?',
    message: tr
        ? 'Tüm sohbetleriniz ve fotoğraflarınız bu cihazdan ve sunucudan kalıcı olarak silinir.'
        : 'Your chats and photos are removed for good.',
    actions: [
      IosAlertAction(label: tr ? 'Hesabı sil' : 'Delete', value: true, destructive: true),
      IosAlertAction(label: tr ? 'Vazgeç' : 'Cancel', value: false, cancel: true),
    ],
  );
}

/// A plain titled sheet (the SheetFrame everything else is built on), to see
/// the panel's light and edge without the dialog furniture.
void _frame(BuildContext c, {required bool tr}) {
  showAdaptiveSheet<void>(
    c,
    builder: (ctx) => SheetFrame(
      title: tr ? 'Cihazı yeniden adlandır' : 'Rename device',
      confirm: SheetConfirm(onTap: () => Navigator.of(ctx).pop()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final n in tr ? const ['Telefon', 'Dizüstü', 'Tablet'] : const ['Phone', 'Laptop', 'Tablet'])
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(n, style: ThemeScope.of(ctx).body),
            ),
        ],
      ),
    ),
  );
}

const Map<String, _Open> _kinds = {
  'frame': _frame,
  'menu': _menu,
  'menumulti': _menuMulti,
  'confirm': _confirm,
  'alert': _alert,
  'alertred': _alertDestructive,
};

void main() {
  setUpAll(() async {
    await loadPreviewFonts();
  });

  const themes = [
    'basic',
    'basic_daylight',
    'basic_rose',
    'vault_ivory',
    'risograph_pop',
    'cyberpunk',
  ];

  Future<void> shot(
    WidgetTester tester,
    String kind,
    String id, {
    bool tr = false,
    double scale = 1,
  }) async {
    if (scale != 1) tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final theme = ThemeController.byId(id);
    final open = _kinds[kind]!;
    // flutter_test draws every BoxShadow as a hard-edged copy of its shape;
    // the real blur is half of what this design is, so look at the real one.
    debugDisableShadows = false;
    try {
      await snap(
        tester,
        previewApp(
          theme,
          _Page(open: (c) => open(c, tr: tr)),
          locale: Locale(tr ? 'tr' : 'en'),
        ),
        'dialog_${kind}_$id${tr ? '_tr' : ''}${scale != 1 ? '_x13' : ''}.png',
        dpr: 2,
        settle: const Duration(milliseconds: 1200),
        // Frame by frame: a route pushed after the first frame needs them.
        act: () async {},
      );
    } finally {
      debugDisableShadows = true;
    }
  }

  for (final id in themes) {
    for (final kind in _kinds.keys) {
      testWidgets('$kind $id', (tester) => shot(tester, kind, id));
    }
  }
  for (final id in const ['basic', 'basic_daylight']) {
    for (final kind in const ['menu', 'confirm', 'alert']) {
      testWidgets('$kind $id tr', (tester) => shot(tester, kind, id, tr: true));
      testWidgets('$kind $id x13', (tester) => shot(tester, kind, id, scale: 1.3));
    }
    testWidgets('confirm $id tr x13',
        (tester) => shot(tester, 'confirm', id, tr: true, scale: 1.3));
  }
}
