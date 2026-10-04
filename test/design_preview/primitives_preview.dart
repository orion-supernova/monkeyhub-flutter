// Renders every shared design-system primitive (buttons, segmented control,
// rows, quick actions, empty states, fields, alerts, media marks) under
// Midnight, Daylight and Risograph Pop, plus a Turkish 1.3× pass.
//
//   flutter test test/design_preview/primitives_preview.dart
//
// PNGs: build/design_preview/prim_<page>_<theme>[_tr13].png
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monkeyhub/theme/theme_scope.dart';
import 'package:monkeyhub/widgets/account_kit.dart';
import 'package:monkeyhub/widgets/count_badge.dart';
import 'package:monkeyhub/widgets/filter_capsule.dart';
import 'package:monkeyhub/widgets/game_result_actions.dart';
import 'package:monkeyhub/widgets/ios_kit.dart';
import 'package:monkeyhub/widgets/liquid_glass.dart' show GlassTone;
import 'package:monkeyhub/widgets/photo_chrome.dart';
import 'package:monkeyhub/widgets/prominent_button.dart';
import 'package:monkeyhub/widgets/search_field.dart';
import 'package:monkeyhub/widgets/sheet_kit.dart';
import 'package:monkeyhub/widgets/skeleton_rows.dart';

import 'preview_kit.dart';

bool _tr(BuildContext c) => Localizations.localeOf(c).languageCode == 'tr';
String _t(BuildContext c, String en, String tr) => _tr(c) ? tr : en;

Widget _avatar(BuildContext context, String letter, Color color) => Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    final t = (String en, String tr) => _t(context, en, tr);
    return IosPage(
      title: t('Buttons', 'Düğmeler'),
      showBack: false,
      children: [
        SheetActionButton(label: t('Create account', 'Hesap oluştur'), onTap: () {}),
        const SizedBox(height: 10),
        SheetActionButton(
          label: t('Test connection', 'Bağlantıyı test et'),
          onTap: () {},
          tonal: true,
          icon: CupertinoIcons.bolt_fill,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: SheetActionButton(label: 'Busy', onTap: () {}, busy: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SheetActionButton(
              label: t('Disabled', 'Devre dışı'),
              onTap: null,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        SheetActionButton(
          label: t('Delete account', 'Hesabı sil'),
          onTap: () {},
          destructive: true,
        ),
        const SizedBox(height: 10),
        SheetActionButton(
          label: t('Leave group and delete history',
              'Gruptan ayrıl ve tüm geçmişi kalıcı olarak sil'),
          onTap: () {},
          destructive: true,
          tonal: true,
        ),
        const SizedBox(height: 4),
        Center(
          child: TextLinkButton(
            label: t('Use password instead', 'Bunun yerine şifre kullan'),
            onTap: () {},
          ),
        ),
        const SizedBox(height: 4),
        ProminentButton(label: t('Sign in', 'Giriş yap'), onTap: () {}),
        const SizedBox(height: 10),
        const SheetButton(label: 'SheetButton (alias)', onTap: null),
        const SizedBox(height: 18),
        GameResultActions(actions: [
          GameResultAction(
            icon: CupertinoIcons.doc_on_doc,
            label: t('Copy result', 'Sonucu kopyala'),
            onTap: () {},
          ),
          GameResultAction(
            icon: CupertinoIcons.paperplane_fill,
            label: t('Tell friends', 'Arkadaşlara söyle'),
            onTap: () {},
            prominent: true,
          ),
        ]),
        const SizedBox(height: 18),
        GroupedSection(children: [
          PersonRow(
            avatar: _avatar(context, 'D', const Color(0xFF5856D6)),
            title: 'Deniz Kaya-Wilhelmsen',
            subtitle: 'iPhone 16 Pro · ${t('last active today', 'bugün aktif')}',
            trailing: RowPillButton(
              label: t('Remove', 'Kaldır'),
              destructive: true,
              onTap: () {},
            ),
          ),
          PersonRow(
            avatar: _avatar(context, 'E', const Color(0xFF30B350)),
            title: 'Ece',
            subtitle: '@ece',
            trailing: RowPillButton(
              label: t('Unblock', 'Engeli kaldır'),
              busy: true,
              onTap: () {},
            ),
          ),
        ]),
      ],
    );
  }
}

enum _Mute { hour, day, week, always }

class _Controls extends StatefulWidget {
  const _Controls();
  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  final _search = TextEditingController(text: 'deniz');
  final _field = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final t = (String en, String tr) => _t(context, en, tr);
    return IosPage(
      title: t('Controls', 'Kontroller'),
      showBack: false,
      children: [
        IosSegmentedControl<int>(
          value: 1,
          onChanged: (_) {},
          segments: [
            IosSegment(value: 0, label: t('Low', 'Düşük')),
            IosSegment(value: 1, label: t('Auto', 'Otomatik')),
            IosSegment(value: 2, label: t('High', 'Yüksek')),
          ],
        ),
        const SizedBox(height: 12),
        IosSegmentedControl<_Mute>(
          value: _Mute.always,
          onChanged: (_) {},
          segments: [
            IosSegment(value: _Mute.hour, label: t('1 hour', '1 saat')),
            IosSegment(value: _Mute.day, label: t('1 day', '1 gün')),
            IosSegment(value: _Mute.week, label: t('1 week', '1 hafta')),
            IosSegment(value: _Mute.always, label: t('Always', 'Her zaman')),
          ],
        ),
        const SizedBox(height: 12),
        IosSegmentedControl<int>(
          value: 0,
          onChanged: (_) {},
          segments: [
            IosSegment(
              value: 0,
              label: t('Voice', 'Sesli'),
              icon: CupertinoIcons.phone_fill,
            ),
            IosSegment(
              value: 1,
              label: t('Video', 'Görüntülü'),
              icon: CupertinoIcons.video_camera_solid,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SearchField(
          controller: _search,
          hintText: t('Search', 'Ara'),
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        SheetTextField(
          controller: _field,
          hint: t('Say something honest', 'Dürüst bir şey söyle'),
          leadingIcon: CupertinoIcons.pencil,
        ),
        const SizedBox(height: 12),
        FormErrorBanner(
          t('That password doesn’t match this account.',
              'Bu şifre bu hesapla eşleşmiyor.'),
          actionLabel: t('Reset password', 'Şifreyi sıfırla'),
          onAction: () {},
        ),
        const SizedBox(height: 12),
        SoftNote(
          icon: CupertinoIcons.info_circle_fill,
          title: t('Server unreachable', 'Sunucuya ulaşılamıyor'),
          text: t('Check the address, or try again in a minute.',
              'Adresi kontrol et ya da bir dakika sonra tekrar dene.'),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const CountBadge.tab(count: 3),
            const CountBadge.tab(count: 128),
            const CountBadge(count: 7),
            const CountBadge(count: 2, mention: true),
            const RowBadge(count: 12),
            const SelectionCheck(picked: true),
            const SelectionCheck(picked: false),
            FilterCapsule(
              label: t('Unread', 'Okunmamış'),
              active: true,
              count: 4,
              onTap: () {},
            ),
            FilterCapsule(
              label: t('Groups', 'Gruplar'),
              active: false,
              count: 9,
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 16),
        const SkeletonRows(count: 2),
        const SizedBox(height: 8),
        const SkeletonSweep(
          child: Row(children: [
            SkeletonBox(width: 64, height: 64, radius: 12),
            SizedBox(width: 10),
            Expanded(child: SkeletonBox(height: 64, radius: 12)),
          ]),
        ),
      ],
    );
  }
}

class _Lists extends StatelessWidget {
  const _Lists();

  @override
  Widget build(BuildContext context) {
    final t = (String en, String tr) => _t(context, en, tr);
    return IosPage(
      title: t('Lists', 'Listeler'),
      showBack: false,
      children: [
        GroupedSection(children: [
          GroupedRow(
            icon: CupertinoIcons.paintbrush_fill,
            tone: TileTone.indigo,
            title: t('Theme', 'Tema'),
            value: t('Auto · Risograph Pop', 'Otomatik · Risograph Pop'),
            onTap: () {},
          ),
          GroupedRow(
            icon: CupertinoIcons.link,
            tone: TileTone.blue,
            title: t('Linked accounts', 'Bağlı hesaplar'),
            value: t('Nothing linked', 'Bağlı hesap yok'),
            onTap: () {},
          ),
          GroupedRow(
            icon: CupertinoIcons.person_2_fill,
            tone: TileTone.orange,
            title: t('Speaker colours', 'Konuşmacı renkleri'),
            value: t('Match the avatar', 'Profil fotoğrafına uy'),
            onTap: () {},
          ),
          GroupedRow(
            icon: CupertinoIcons.bell_fill,
            tone: TileTone.red,
            title: t('Approvals', 'Onaylar'),
            badge: 3,
            onTap: () {},
          ),
          GroupedRow.toggle(
            icon: CupertinoIcons.eye_fill,
            tone: TileTone.teal,
            title: t('Read receipts', 'Okundu bilgisi'),
            value: false,
            onChanged: (_) {},
          ),
        ]),
        SheetQuickActions(actions: [
          QuickAction(
            icon: CupertinoIcons.chat_bubble_fill,
            label: t('Message', 'Mesaj gönder'),
            onTap: () {},
          ),
          QuickAction(
            icon: CupertinoIcons.phone_fill,
            label: t('Call', 'Ara'),
            onTap: () {},
          ),
          QuickAction(
            icon: CupertinoIcons.video_camera_solid,
            label: t('Video', 'Görüntülü ara'),
            onTap: () {},
          ),
          QuickAction(
            icon: CupertinoIcons.bell_slash_fill,
            label: t('Mute', 'Sessize al'),
            onTap: () {},
            busy: true,
          ),
        ]),
        const SizedBox(height: 8),
        PageSectionHeader(
          t('Moments', 'Anlar'),
          actionLabel: t('See all', 'Tümünü gör'),
          onAction: () {},
        ),
        EmptyLine(t('No moments yet', 'Henüz an yok')),
        OrDivider(label: t('or', 'ya da')),
        EmptyState(
          icon: CupertinoIcons.person_2,
          title: t('No blocked people', 'Engellenen kimse yok'),
          message: t(
            'People you block can’t message you or see when you’re online.',
            'Engellediğin kişiler sana mesaj atamaz ve çevrimiçi olduğunu göremez.',
          ),
          actionLabel: t('Find people', 'Kişileri bul'),
          onAction: () {},
        ),
      ],
    );
  }
}

class _Media extends StatelessWidget {
  const _Media();

  @override
  Widget build(BuildContext context) {
    final t = (String en, String tr) => _t(context, en, tr);
    // A stand-in photograph: bright sky over a dark field, the worst case
    // for marks that must read on both.
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFBFE3FF), Color(0xFFFFF4D6), Color(0xFF203020)],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const GlassCloseButton(tone: GlassTone.media),
                  const Spacer(),
                  GlassPillButton(
                    label: t('Use photo', 'Fotoğrafı kullan'),
                    tint: ThemeScope.of(context).accent,
                    onTap: () {},
                  ),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  MediaOverlayChip(
                    icon: CupertinoIcons.crop,
                    semanticLabel: 'Crop',
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  MediaOverlayChip(
                    icon: CupertinoIcons.xmark,
                    semanticLabel: 'Remove',
                    onTap: () {},
                  ),
                  const SizedBox(width: 16),
                  const SelectionCheck(picked: false, media: true),
                  const SizedBox(width: 8),
                  const SelectionCheck(picked: true, media: true),
                ]),
                const SizedBox(height: 30),
                const Center(child: MediaPlayDisc()),
                const SizedBox(height: 16),
                const Center(child: MediaPlayDisc(size: 36)),
                const SizedBox(height: 16),
                const Row(children: [
                  MediaDurationBadge(
                    duration: Duration(seconds: 42),
                    icon: CupertinoIcons.video_camera_solid,
                  ),
                  SizedBox(width: 8),
                  MediaDurationBadge(duration: Duration(minutes: 63, seconds: 7)),
                ]),
                const Spacer(),
                Center(
                  child: MediaNoteCapsule(
                    icon: CupertinoIcons.sparkles,
                    iconColor: ThemeScope.of(context).accent,
                    text: t('Sends in full resolution',
                        'Tam çözünürlükte gönderilir'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  PhotoViewOnceToggle(
                    active: true,
                    accent: ThemeScope.of(context).accent,
                    accentInk: ThemeScope.of(context).accentInk,
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  PhotoHdToggle(
                    active: false,
                    accent: ThemeScope.of(context).accent,
                    accentInk: ThemeScope.of(context).accentInk,
                    onTap: () {},
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    tone: GlassTone.media,
                    icon: CupertinoIcons.scribble,
                    onTap: () {},
                  ),
                  const Spacer(),
                  GlassPillButton(
                    label: t('Send', 'Gönder'),
                    tint: ThemeScope.of(context).accent,
                    onTap: () {},
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A plain page that opens an overlay once it has a context.
class _Opener extends StatelessWidget {
  const _Opener({required this.anchor});
  final GlobalKey anchor;

  @override
  Widget build(BuildContext context) => IosPage(
        key: anchor,
        title: 'Overlay',
        showBack: false,
        children: [
          for (var i = 0; i < 6; i++)
            GroupedSection(children: [
              GroupedRow(title: 'Row $i', value: 'Value', onTap: () {}),
            ]),
        ],
      );
}

final _alertField = TextEditingController(text: 'Evening glass');

final Map<String, void Function(BuildContext)> _overlays = {
  'alert': (c) => showIosAlert<bool>(
        c,
        title: _t(c, 'Save these glass settings?', 'Bu cam ayarları kaydedilsin mi?'),
        message: _t(c, 'You can change them again any time in Appearance.',
            'Bunları Görünüm’de istediğin zaman yeniden değiştirebilirsin.'),
        actions: [
          IosAlertAction(label: _t(c, 'Cancel', 'Vazgeç'), value: false, cancel: true),
          IosAlertAction(label: _t(c, 'Save', 'Kaydet'), value: true, preferred: true),
        ],
      ),
  'alertfield': (c) => showIosAlert<bool>(
        c,
        title: _t(c, 'Name this preset', 'Bu ön ayara ad ver'),
        field: IosAlertField(controller: _alertField, hint: 'Name'),
        actions: [
          IosAlertAction(label: _t(c, 'Cancel', 'Vazgeç'), value: false, cancel: true),
          IosAlertAction(label: _t(c, 'Save preset', 'Ön ayarı kaydet'), value: true, preferred: true),
        ],
      ),
  'actions': (c) => showIosActionSheet<int>(
        c,
        title: _t(c, 'Leave Weekend Crew?', 'Weekend Crew’dan ayrılsın mı?'),
        message: _t(c, 'You will stop getting its messages.',
            'Artık mesajlarını almayacaksın.'),
        actions: [
          IosSheetAction(label: _t(c, 'Mark as read', 'Okundu olarak işaretle'), value: 1),
          IosSheetAction(label: _t(c, 'Leave group', 'Gruptan ayrıl'), value: 3, destructive: true),
        ],
      ),
};

void main() {
  setUpAll(loadPreviewFonts);
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  final pages = <String, Widget>{
    'buttons': const _Buttons(),
    'controls': const _Controls(),
    'lists': const _Lists(),
    'media': const _Media(),
  };

  Future<void> page(WidgetTester tester, String id, MapEntry<String, Widget> e,
      {Locale locale = const Locale('en'), double scale = 1, String suffix = ''}) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await snap(
      tester,
      previewApp(ThemeController.byId(id), e.value, locale: locale),
      'prim_${e.key}_$id$suffix.png',
    );
  }

  Future<void> overlay(WidgetTester tester, String id,
      MapEntry<String, void Function(BuildContext)> e,
      {Locale locale = const Locale('en'), double scale = 1, String suffix = ''}) async {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final anchor = GlobalKey();
    await snap(
      tester,
      previewApp(ThemeController.byId(id), _Opener(anchor: anchor), locale: locale),
      'prim_${e.key}_$id$suffix.png',
      act: () async {
        e.value(anchor.currentContext!);
        await tester.pump();
      },
    );
  }

  for (final id in ['basic', 'basic_daylight', 'risograph_pop']) {
    for (final e in pages.entries) {
      testWidgets('prim ${e.key}: $id', (t) => page(t, id, e));
    }
    for (final e in _overlays.entries) {
      testWidgets('prim ${e.key}: $id', (t) => overlay(t, id, e));
    }
  }
  for (final id in ['basic', 'risograph_pop']) {
    for (final e in pages.entries) {
      testWidgets('prim ${e.key}: $id tr 1.3', (t) =>
          page(t, id, e, locale: const Locale('tr'), scale: 1.3, suffix: '_tr13'));
    }
    for (final e in _overlays.entries) {
      testWidgets('prim ${e.key}: $id tr 1.3', (t) =>
          overlay(t, id, e, locale: const Locale('tr'), scale: 1.3, suffix: '_tr13'));
    }
  }
}
