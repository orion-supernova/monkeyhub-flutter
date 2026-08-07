// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'SUNUCUYA ULAŞILAMIYOR';

  @override
  String get bootErrorBody => 'Convex başlatılamadı.';

  @override
  String get bootErrorRetry => 'TEKRAR DENE';

  @override
  String get incomingCallNotificationTitle => 'Gelen arama';

  @override
  String get incomingCallFallbackCaller => 'Biri seni arıyor';

  @override
  String get settingsLanguageRowLabel => 'DİL';

  @override
  String get languageScreenTitle => 'dil.';

  @override
  String get languageScreenSubtitle =>
      'menülerin ve mesajların hangi dilde görüneceğini seç';

  @override
  String get languageOptionSystem => 'SİSTEM';

  @override
  String get languageOptionSystemSub => 'cihazının dil ayarını kullan';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => 'AKTİF';

  @override
  String get languageValueSystem => 'Sistem';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack =>
      'şu an sorulamadı — tekrar dene';

  @override
  String get roomScreenGateSendMessages => 'buraya mesaj göndermek';

  @override
  String get roomScreenGateSendMedia => 'fotoğraf ya da sesli not göndermek';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'bir seferde en fazla $max tane';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count MESAJI SİL',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Bu, mesajları sohbetteki herkes için kaldırır. Geri alınamaz.';

  @override
  String get roomScreenDeleteConfirmButton => 'HERKES İÇİN SİL';

  @override
  String get roomScreenJumpFailedSnack => 'o mesaja gidilemedi';

  @override
  String get roomScreenViewOnceAlreadyViewed => 'bu fotoğrafı zaten açtın.';

  @override
  String get roomScreenViewOnceGone => 'bu fotoğraf artık mevcut değil.';

  @override
  String get roomScreenViewOnceNetworkError => 'fotoğraf yüklenemedi.';

  @override
  String get roomScreenFileReadFailedSnack => 'dosya okunamadı';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'dosyalar en fazla $size olabilir';
  }

  @override
  String get roomScreenRoomGone => 'oda artık yok';

  @override
  String get roomScreenCopiedSnack => 'kopyalandı';

  @override
  String get roomScreenNameCopiedSnack => 'isim kopyalandı';

  @override
  String get roomScreenPinLimitSnack =>
      'çok fazla sabitlenmiş mesaj var — önce birini kaldır';

  @override
  String get roomScreenPinFailedSnack => 'sabitlenemedi';

  @override
  String get roomScreenReportSentSnack =>
      'şikayet gizlice gönderildi. karşı taraf bilgilendirilmeyecek.';

  @override
  String get roomScreenDeselectMessageSemantic => 'Mesaj seçimini kaldır';

  @override
  String get roomScreenSelectMessageSemantic => 'Mesajı seç';

  @override
  String roomScreenMemberCountBadge(Object count) {
    return 'İÇERİDE $count';
  }

  @override
  String roomScreenTtlSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saniye',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dakika',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saat',
    );
    return '$_temp0';
  }

  @override
  String roomScreenEphemeralNotice(Object ttl) {
    return 'bu oda geçici. mesajlar okunsun okunmasın $ttl sonra siliniyor.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count MESAJ';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'Gizli Alan';

  @override
  String get roomScreenSecretSpaceBody =>
      'Bu odadaki mesajlar geçici. Odanın güvenlik ayarlarına göre otomatik olarak siliniyorlar.';

  @override
  String get roomScreenAutoDeleteTitle => 'Otomatik Silme';

  @override
  String get roomScreenAutoDeleteVaries => 'Değişken';

  @override
  String get roomScreenAutoDeleteTimed => 'Süreli';

  @override
  String get roomScreenNoCaptureTitle => 'Yakalama Yok';

  @override
  String get roomScreenNoCaptureSubtitle => 'Ekran Görüntüsü Kısıtlı';

  @override
  String get roomScreenMorePrivacyTitle => 'Çok Daha Fazla Gizlilik';

  @override
  String get roomScreenMorePrivacySubtitle =>
      'Zaten var olan gizlilik odağının üzerine ekstra güvenlik özelliklerinin keyfini çıkar.';

  @override
  String get roomScreenNoMessagesTitle => 'Mesaj Yok';

  @override
  String get roomScreenNoMessagesSubtitle =>
      'Bir mesaj göndererek sohbeti başlat';

  @override
  String get roomScreenViewProfilePictureSemantic =>
      'profil fotoğrafını görüntüle';

  @override
  String get roomScreenViewRoomPictureSemantic => 'oda fotoğrafını görüntüle';

  @override
  String get messageBubbleFileFallbackName => 'belge';

  @override
  String get messageBubbleAttachmentStatusFailed => 'başarısız';

  @override
  String get messageBubbleAttachmentStatusSending => 'gönderiliyor…';

  @override
  String get messageBubbleViewOnceOpened => 'görüntülendi';

  @override
  String get messageBubbleViewOnceExpired => 'süresi doldu';

  @override
  String get messageBubbleViewOnceLabel => 'tek seferlik';

  @override
  String get messageBubbleViewOnceTapToView => 'görmek için dokun';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Fotoğraf';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'tek seferlik fotoğraf, görüntülemek için dokun';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'gönderimi yeniden dene';

  @override
  String get messageBubbleDiscardSemanticLabel => 'sil';

  @override
  String get profileScreenAccountSection => 'HESAP';

  @override
  String get profileScreenAddEmailPlaceholder => 'e-posta ekle';

  @override
  String get profileScreenAddEmailTitle => 'e-posta ekle mi?';

  @override
  String get profileScreenAddNameTitle => 'isim ekle mi?';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count bekliyor';
  }

  @override
  String get profileScreenApprovalsLabel => 'ONAYLAR';

  @override
  String get profileScreenApprovalsNothingWaiting => 'bekleyen yok';

  @override
  String get profileScreenApproveAction => 'ONAYLA';

  @override
  String get profileScreenBlockAction => 'ENGELLE';

  @override
  String get profileScreenBlockedDmWiped =>
      'engellendi ve DM silindi. bilgilendirilmeyecekler.';

  @override
  String get profileScreenBlockedOnly => 'engellendi. bilgilendirilmeyecekler.';

  @override
  String get profileScreenBlockedUsers => 'ENGELLENEN KULLANICILAR';

  @override
  String get profileScreenCancelAction => 'İPTAL';

  @override
  String get profileScreenCancelRequestAction => 'İSTEĞİ İPTAL ET';

  @override
  String get profileScreenChangeAction => 'DEĞİŞTİR';

  @override
  String get profileScreenChangeEmailTitle => 'e-postanı değiştir mi?';

  @override
  String get profileScreenChangeNameTitle => 'ismini değiştir mi?';

  @override
  String get profileScreenChangeProfilePictureSemantic =>
      'profil fotoğrafını değiştir';

  @override
  String get profileScreenChangeRecoveryPhrase => 'KURTARMA İFADESİNİ DEĞİŞTİR';

  @override
  String get profileScreenChooseFromLibrary => 'GALERİDEN SEÇ';

  @override
  String get profileScreenCouldNotSaveImage => 'görsel kaydedilemedi.';

  @override
  String get profileScreenDeleteAccount => 'HESABI SİL';

  @override
  String get profileScreenEmailHint => 'isteğe bağlı — kimseye gösterilmez';

  @override
  String get profileScreenEmailSectionLabel => 'E-POSTA';

  @override
  String get profileScreenErrorAlreadyFriends => 'zaten arkadaşsınız.';

  @override
  String get profileScreenErrorGeneric => 'bunu tamamlayamadık.';

  @override
  String get profileScreenErrorNotAccepting =>
      'şu anda arkadaşlık isteği kabul etmiyorlar.';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      'onlar sana zaten istek göndermiş — isteklerine bak.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'istek zaten gönderildi.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'bu kullanıcıyı sen engellemiştin — önce engeli kaldır.';

  @override
  String get profileScreenErrorUserNotFound => 'şu anda bu mümkün değil.';

  @override
  String get profileScreenFamilyAddChild => 'bir çocuk ekle';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count çocuk',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => 'AİLE';

  @override
  String get profileScreenFriendsChip => 'ARKADAŞ';

  @override
  String get profileScreenGrownUpOnlyNote =>
      'Bunu sadece bir yetişkin yapabilir — kodu ya da şifresi gerekiyor.';

  @override
  String get profileScreenGuardiansCanSee =>
      'Ne zaman çevrimiçi olduğunu ve kimlerle konuştuğunu görebilirler.';

  @override
  String get profileScreenHandPhoneBack => 'TELEFONU GERİ VER';

  @override
  String get profileScreenIncomingRequestChip => 'GELEN İSTEK';

  @override
  String get profileScreenJustTappedAction => 'YANLIŞLIKLA DOKUNDUM';

  @override
  String get profileScreenLegalSection => 'YASAL';

  @override
  String get profileScreenLicence => 'LİSANS';

  @override
  String get profileScreenLinkedAccountsLabel => 'BAĞLI HESAPLAR';

  @override
  String get profileScreenLinkedAccountsNone => 'bağlı hesap yok';

  @override
  String get profileScreenMyGrownUps => 'BÜYÜKLERİM';

  @override
  String get profileScreenNameHint => 'odada nasıl görüneceğin';

  @override
  String get profileScreenNobodyLookingAfter =>
      'bu hesaba henüz kimse bakmıyor';

  @override
  String get profileScreenNotAcceptingRequestsAction => 'İSTEK KABUL ETMİYOR';

  @override
  String get profileScreenNotConnectedChip => 'BAĞLANTI YOK';

  @override
  String get profileScreenOpenDmAction => 'DM AÇ';

  @override
  String get profileScreenPhotoPermissionDenied => 'fotoğraf izni reddedildi.';

  @override
  String get profileScreenPrivacyPolicy => 'GİZLİLİK POLİTİKASI';

  @override
  String get profileScreenPrivacySection => 'GİZLİLİK';

  @override
  String get profileScreenProfilePictureTitle => 'PROFİL FOTOĞRAFI';

  @override
  String get profileScreenRedactedFriend =>
      'bazı alanlar onların ayarları yüzünden gizli.';

  @override
  String get profileScreenRedactedStranger =>
      'sınırlı görünüm — arkadaşlarıyla daha fazlasını paylaşıyorlar.';

  @override
  String get profileScreenReportAction => 'ŞİKAYET ET';

  @override
  String get profileScreenReportSent =>
      'şikayet gizlice gönderildi. bilgilendirilmeyecekler.';

  @override
  String get profileScreenRequestPendingChip => 'İSTEK BEKLİYOR';

  @override
  String get profileScreenSaveAction => 'KAYDET';

  @override
  String get profileScreenSavedToPhotos => 'fotoğraflara kaydedildi.';

  @override
  String get profileScreenSaveToPhotos => 'FOTOĞRAFLARA KAYDET';

  @override
  String get profileScreenSendRequestAction => 'İSTEK GÖNDER';

  @override
  String get profileScreenSetUpRecoveryPhrase => 'KURTARMA İFADESİ OLUŞTUR';

  @override
  String get profileScreenSignOut => 'ÇIKIŞ YAP';

  @override
  String get profileScreenTakeSelfie => 'SELFİE ÇEK';

  @override
  String get profileScreenTapAgainToConfirmDelete =>
      'SİLMEYİ ONAYLAMAK İÇİN TEKRAR DOKUN';

  @override
  String get profileScreenTermsOfService => 'KULLANIM KOŞULLARI';

  @override
  String get profileScreenThisPhoneSection => 'BU TELEFON';

  @override
  String get profileScreenUnfriendAction => 'ARKADAŞLIKTAN ÇIKAR';

  @override
  String get profileScreenViewProfilePictureSemantic =>
      'profil fotoğrafını görüntüle';

  @override
  String get profileScreenVisibilityPreferences => 'GÖRÜNÜRLÜK TERCİHLERİ';

  @override
  String get cameraEditorScreenCropPresetFree => 'SERBEST';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'ORİJİNAL';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'kırpmayı iptal et';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'fotoğrafı sil';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'geri al';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'yinele';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'kırpmayı sıfırla';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'döndür';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'kırp';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'bu tarayıcı HEIC fotoğrafları açamıyor';

  @override
  String get cameraEditorScreenImageLoadFailedMessage => 'bu görseli açamadık';

  @override
  String get cameraEditorScreenCropDoneButton => 'TAMAM';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'yeniden çek';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'kalemi kaldır';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'fotoğrafa çiz';

  @override
  String get cameraEditorScreenSendingButton => 'GÖNDERİLİYOR…';

  @override
  String get cameraEditorScreenSendButton => 'GÖNDER';

  @override
  String get cameraEditorScreenViewOnceNote => 'bir kez açılınca kaybolur';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'çizimi temizle';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel =>
      'tek seferlik görüntüleme: açık';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel =>
      'tek seferlik görüntüleme: kapalı';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'mürekkep rengi';

  @override
  String get glassScreenPanelLooks => 'GÖRÜNÜMLER';

  @override
  String get glassScreenPanelBottomBar => 'ALT ÇUBUK';

  @override
  String get glassScreenPanelOtherSurfaces => 'DİĞER YÜZEYLER';

  @override
  String get glassScreenPanelBarLayout => 'ÇUBUK YERLEŞİMİ';

  @override
  String get glassScreenTitle => 'cam.';

  @override
  String get glassScreenSubtitle => 'arkadaki ne kadar görünsün';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'TÜM $max YUVA DOLU';
  }

  @override
  String get glassScreenSaveCurrentAs => 'GÖRÜNÜM OLARAK KAYDET…';

  @override
  String get glassScreenResetEveryDial => 'TÜM AYARLARI SIFIRLA';

  @override
  String glassScreenResetToPreset(Object name) {
    return '$name OLARAK SIFIRLA';
  }

  @override
  String get glassScreenSurfacesNote =>
      'mesaj kutusu, başlıklar, arama düğmeleri — kayan içerik yerine metnin üzerine oturan her şey';

  @override
  String get glassScreenMatchBottomBar => 'ALT ÇUBUKLA EŞLEŞTİR';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'değiştirildi — yeni bir görünüm olarak kaydet ya da sıfırla';

  @override
  String get glassScreenCustomPresetName => 'Özel';

  @override
  String get glassScreenUnsavedSubtitle =>
      'kaydedilmedi — saklamak için bir isim ver';

  @override
  String get glassScreenSaveDialogTitle => 'bu görünümü farklı kaydet';

  @override
  String get glassScreenNoRoomToast => 'yer kalmadı — önce bir görünüm sil';

  @override
  String get glassScreenRenameDialogTitle => 'yeniden adlandır';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '$name silinsin mi?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'görünüm ekranda kalmaya devam eder — sadece adını kaybeder.';

  @override
  String get glassScreenKeepButton => 'sakla';

  @override
  String get glassScreenDeleteButton => 'sil';

  @override
  String get glassScreenNameHint => 'geç saatler';

  @override
  String get glassScreenCancelButton => 'vazgeç';

  @override
  String get glassScreenSaveButton => 'kaydet';

  @override
  String get glassScreenPreviewRoomName => '# balkon';

  @override
  String get glassScreenPreviewOnlineCount => '4 çevrimiçi';

  @override
  String get glassScreenPreviewMessageHint => 'mesaj';

  @override
  String get glassScreenPreviewCollapseLabel => 'önizlemeyi daralt';

  @override
  String get glassScreenPreviewExpandLabel => 'önizlemeyi genişlet';

  @override
  String get glassScreenPreviewBadge => 'ÖNİZLEME';

  @override
  String get glassScreenBuiltInLabel => 'yerleşik';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return '$name üzerine kaydet';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return '$name adını değiştir';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return '$name sil';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return '$label sıfırla';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'çatı fotoğraflarını attı — kiremitler resmen dağılmış';

  @override
  String get glassScreenBackdropMsgMert =>
      'tamam da hoparlörü asıl kim getiriyor';

  @override
  String get glassScreenBackdropGroupFamily => 'aile';

  @override
  String get glassScreenBackdropMsgFamily =>
      'Anne: saat 8’de yemek var, yine geç kalma';

  @override
  String get glassScreenBackdropMsgZeynep => 'dışarıdayım';

  @override
  String get glassScreenBackdropMsgKerem => 'köşedeki yer güzel kahve yapıyor';

  @override
  String get glassScreenBackdropGroupWork => 'mesai';

  @override
  String get glassScreenBackdropMsgWork => 'standup bu hafta 10:30’a alındı';

  @override
  String get glassScreenBackdropMsgElif => 'yok artık. tekrar at kaybettim';

  @override
  String get glassScreenBackdropMsgBaran => 'indik 👍';

  @override
  String get glassScreenBackdropMsgAyse =>
      'kedi balkon kapısını açmayı öğrendi';

  @override
  String get glassScreenBackdropMsgCan => 'o zaman cumartesi görüşürüz';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return '$name kişisine yanıt';
  }

  @override
  String get replyIndicatorViewOnceLabel => 'fotoğraf · tek seferlik';

  @override
  String get replyIndicatorVoiceMessageLabel => 'sesli mesaj';

  @override
  String get replyIndicatorDocumentLabel => 'belge';

  @override
  String get replyIndicatorMessageRemoved => 'mesaj kaldırıldı';

  @override
  String get threadOverlayMessageNotFound => 'bu konuda o mesajı bulamadım';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'yanıtlanacak konuyu bulamadım';

  @override
  String get threadOverlayStillSending =>
      'hâlâ gönderiliyor — birazdan tekrar dene';

  @override
  String get threadOverlayCopiedToast => 'kopyalandı';

  @override
  String get threadOverlayNameCopiedToast => 'ad kopyalandı';

  @override
  String get threadOverlayPinLimitToast =>
      'çok fazla sabitlenmiş mesaj var — önce birini kaldır';

  @override
  String get threadOverlayPinFailedToast => 'bunu sabitleyemedim';

  @override
  String get threadOverlayReportedToast => 'bildirildi';

  @override
  String get threadOverlayUnavailable => 'konu kullanılamıyor';

  @override
  String get roomInfoScreenNameRequiredError => 'isim gerekli';

  @override
  String get roomInfoScreenSavedSnackbar => 'kaydedildi';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'şifre kaldırıldı';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'odadan ayrıl?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'açık kalırsa tekrar katılabilirsin.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'AYRIL';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'odayı sil?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'buradaki her mesaj onunla birlikte gider. bu geri alınamaz.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'SİL';

  @override
  String get roomInfoScreenConfirmCancelButton => 'VAZGEÇ';

  @override
  String get roomInfoScreenErrorRoomExists => 'bu isimde bir oda zaten var';

  @override
  String get roomInfoScreenErrorNotOwner => 'bunu sadece sahibi yapabilir';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'bunun için yetkin yok';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'bu oda artık yok';

  @override
  String get roomInfoScreenRoomGone => 'oda artık yok';

  @override
  String get roomInfoScreenNameLabel => 'İSİM';

  @override
  String get roomInfoScreenNameHint => 'oda ismi';

  @override
  String get roomInfoScreenDescriptionLabel => 'AÇIKLAMA';

  @override
  String get roomInfoScreenDescriptionHint => 'oda hakkında tek satır…';

  @override
  String get roomInfoScreenVisibilityLabel => 'GÖRÜNÜRLÜK';

  @override
  String get roomInfoScreenPublicTitle => 'herkese açık';

  @override
  String get roomInfoScreenPublicSub => 'herkes bulabilir';

  @override
  String get roomInfoScreenPrivateTitle => 'gizli';

  @override
  String get roomInfoScreenPrivateSub => 'sadece davetle';

  @override
  String get roomInfoScreenMessageLifeLabel => 'MESAJ ÖMRÜ';

  @override
  String roomInfoScreenTtlSeconds(Object value) {
    return '${value}sn';
  }

  @override
  String roomInfoScreenTtlMinutes(Object value) {
    return '${value}dk';
  }

  @override
  String roomInfoScreenTtlHours(Object value) {
    return '${value}sa';
  }

  @override
  String get roomInfoScreenPasswordLabel => 'ŞİFRE';

  @override
  String get roomInfoScreenLockedBadge => 'KİLİTLİ';

  @override
  String get roomInfoScreenNoneBadge => 'YOK';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      'bu oda korumalı. güvenlik nedeniyle mevcut şifre gösterilmiyor — değiştirmek için yenisini gir.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'şifreyi değiştir…';

  @override
  String get roomInfoScreenSetPasswordHint => 'bir şifreyle kilitle…';

  @override
  String get roomInfoScreenRemovePasswordButton => 'ŞİFREYİ KALDIR';

  @override
  String get roomInfoScreenSharedContentLabel => 'PAYLAŞILAN İÇERİK';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return 'ÜYELER · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => 'AYRILIYOR…';

  @override
  String get roomInfoScreenLeaveRoomButton => 'ODADAN AYRIL';

  @override
  String get roomInfoScreenDeletingButton => 'SİLİNİYOR…';

  @override
  String get roomInfoScreenDeleteButtonLabel => 'SİL';

  @override
  String get roomInfoScreenHeaderConversation => 'SOHBET';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'ODA AYARLARI';

  @override
  String get roomInfoScreenViewProfilePictureSemantic =>
      'profil fotoğrafını görüntüle';

  @override
  String get roomInfoScreenViewRoomPictureSemantic =>
      'oda fotoğrafını görüntüle';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic =>
      'oda fotoğrafını değiştir';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'oda fotoğrafı ekle';

  @override
  String get roomInfoScreenLoadingMembers => 'üyeler yükleniyor…';

  @override
  String get roomInfoScreenOwnerBadge => 'SAHİP';

  @override
  String get roomInfoScreenSaveButton => 'KAYDET';

  @override
  String get roomInfoScreenNoneCount => 'yok';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'kamera erişimi kapalı.\nfotoğraf çekmek için Ayarlar’dan izin vermen gerekiyor.';

  @override
  String get cameraScreenOpeningSystemCamera => 'sistem kamerası açılıyor…';

  @override
  String get cameraScreenCloseButtonLabel => 'kamerayı kapat';

  @override
  String get cameraScreenLowLightBoostOnLabel => 'az ışık modu: açık';

  @override
  String get cameraScreenLowLightBoostOffLabel => 'az ışık modu: kapalı';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'flaş: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'galeriden seç';

  @override
  String get cameraScreenSwitchCameraLabel => 'kamerayı değiştir';

  @override
  String get cameraScreenTakePhotoLabel => 'fotoğraf çek';

  @override
  String get childPolicyScreenAddByUsernameLabel => 'KULLANICI ADIYLA EKLE';

  @override
  String get childPolicyScreenAddCta => 'EKLE';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'Tam olarak sendeki yetkiye sahip olurlar: onaylanacak her istek, değiştirilecek her ayar ve seni kaldırma gücü. $name onları hemen aile olarak görür.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'BİR YETİŞKİN EKLE';

  @override
  String get childPolicyScreenAddGuardianHint => 'onun kullanıcı adı';

  @override
  String get childPolicyScreenAllowCta => 'İZİN VER';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'Bir daha sorulmayacaksın — ister $childName onları eklesin, ister onlar $childName’ı eklesin.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'BİRİNE İZİN VER';

  @override
  String get childPolicyScreenAskToAddLabel => 'EKLEME İZNİ İSTE';

  @override
  String get childPolicyScreenAskToAddOffDesc => 'sadece aile — yeni istek yok';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'yeni biri için senden izin isteyebilirler';

  @override
  String get childPolicyScreenBothFinalNote =>
      'İkisi de kalıcıdır. Ayrılmak istiyorsan bu YETİŞKİNLER bölümünde.';

  @override
  String get childPolicyScreenCallsLabel => 'ARAMALAR';

  @override
  String get childPolicyScreenCallsOffDesc => 'sadece mesaj';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'izinli kişilerle sesli + görüntülü arama';

  @override
  String get childPolicyScreenCancelLabel => 'VAZGEÇ';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Vazgeç';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'eklendi — istek gönderiliyor';

  @override
  String get childPolicyScreenContactAddedToList =>
      'izin verilenler listesine eklendi';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'ODA KUR';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'oda kuramazlar';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'kendi özel odalarını kurabilirler';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Her şey gider: mesajları, fotoğrafları, odaları ve arkadaşları. Bu geri alınamaz ve kullanıcı adı başkalarına açılır.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'hesap silinemedi — tekrar dene';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return '$name’İN HESABI SİLİNSİN Mİ?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Mesajlar, fotoğraflar, odalar ve arkadaşlar hepsi gider. Geri alınamaz.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return '$name’İN HESABINI SİL';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'SONSUZA DEK SİL';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'eklenemedi — tekrar dene';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'bu onun kendi kullanıcı adı';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'bir çocuk yetişkin olamaz';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'bu işlem olmadı — tekrar dene';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'birinin onlara bakması lazım — önce başka bir yetişkin ekle';

  @override
  String get childPolicyScreenErrorNotYours => 'bunu değiştirme yetkin yok';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'bu kullanıcı adında bir hesap yok';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'Bu şifreyle normal bir hesaba dönüşürler, tüm yetişkinler görünürlüğünü tamamen kaybeder. Geri dönüşü yok — normal biri gibi tekrar davet edilmen gerekir.';

  @override
  String get childPolicyScreenGraduateCta => 'MEZUN ET';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'Her şeyi korurlar ve bir şifre alırlar. Sen tüm görünürlüğünü kaybedersin. Geri alınamaz.';

  @override
  String get childPolicyScreenGraduateDangerLabel => 'TAM HESABA GEÇİR';

  @override
  String get childPolicyScreenGraduateFailed => 'mezun edilemedi — tekrar dene';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return '$name MEZUN OLSUN';
  }

  @override
  String get childPolicyScreenGraduateHint => 'onlar için bir şifre';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Bir odayı geri almak, onları da odadan çıkarır. Bir kişiyi geri almak ise sohbeti de siler — ikisi için de.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Buradaki herkes onaylayabilir, ayarları değiştirebilir ve her şeyi görebilir. Herhangi biri tek başına hareket edebilir — kimse diğerini beklemez.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'eklendi — artık onlara bakabilirler';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name kaldırıldı';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (sen)';
  }

  @override
  String get childPolicyScreenLoading => 'yükleniyor…';

  @override
  String get childPolicyScreenLockedLabel => 'KİLİTLİ';

  @override
  String get childPolicyScreenMediaLabel => 'FOTOĞRAF + SES';

  @override
  String get childPolicyScreenMediaOffDesc => 'sadece metin';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'fotoğraf, video ve sesli not gönderebilirler';

  @override
  String get childPolicyScreenNoRoomsYet => 'henüz oda yok';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Buradaki herkes sana tekrar sormadan eklenebilir — kim başlatırsa başlatsın.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Çocuklar için her zaman kapalı. Keşfet — tanımadığın kişilere ait odaların listesi — tamamen gizli ve açılamaz. Birinin onları davet ettiği odalar normal şekilde çalışmaya devam eder.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'HERKESE AÇIK ODALAR';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian artık $child için hiçbir şey görmeyecek ya da onaylamayacak.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return '$name KALDIRILSIN MI?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'KALDIR';

  @override
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count kişi';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'YETİŞKİNLER';

  @override
  String get childPolicyScreenSectionPeopleAllowed => 'İZİN VERDİĞİN KİŞİLER';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'İZİN VERDİĞİN ODALAR';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'YAPABİLECEKLERİ';

  @override
  String get childPolicyScreenSectionWhenDone => 'SON ADIMLAR';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'biri diğerini eklemeden hiçbir şey olmaz';

  @override
  String get childPolicyScreenSendNowOnDesc => 'hemen sorulurlar';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'İSTEĞİ ŞİMDİ GÖNDER';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return '$name’in tek yetişkini sensin, o yüzden öylece ayrılamazsın — önce başka birini ekle ya da bunlardan birini kullan.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'AYRIL';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return '$name’in hesabına dair tüm görünürlüğünü kaybedersin — istekleri, kişileri, odaları. Diğer yetişkinler onlara göz kulak olmaya devam eder.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'GÖZETİMİ BIRAK';

  @override
  String get childPolicyScreenStopSupervisingHeadline => 'GÖZETİMİ BIRAK?';

  @override
  String get childPolicyScreenTakeBackFailed => 'geri alınamadı — tekrar dene';

  @override
  String get childPolicyScreenTakeBackLabel => 'GERİ AL';

  @override
  String get childPolicyScreenUsernameHint => 'kullanıcı adı';

  @override
  String get childPolicyScreenYou => 'sen';

  @override
  String get roomContentScreenDefaultDocumentName => 'belge';

  @override
  String get roomContentScreenCouldntOpenFile => 'o dosya açılamadı';

  @override
  String get roomContentScreenCouldntShare => 'bunlar paylaşılamadı';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bağlantı kopyalandı',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count MESAJI SİL',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Bunlar, sohbetteki herkes için kaldırılır. Geri alınamaz.';

  @override
  String get roomContentScreenDeleteForEveryone => 'HERKES İÇİN SİL';

  @override
  String get roomContentScreenCancelTooltip => 'Vazgeç';

  @override
  String get roomContentScreenBackTooltip => 'Geri';

  @override
  String get roomContentScreenSelectingLabel => 'SEÇİLİYOR';

  @override
  String get roomContentScreenSharedContentLabel => 'PAYLAŞILAN İÇERİK';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seçildi',
      zero: 'hiçbir şey seçilmedi',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'SEÇ';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'TÜMÜ';

  @override
  String get roomContentScreenEmptyMedia => 'henüz fotoğraf ya da video yok';

  @override
  String get roomContentScreenEmptyFiles => 'henüz dosya yok';

  @override
  String get roomContentScreenEmptyVoice => 'henüz sesli not yok';

  @override
  String get roomContentScreenEmptyLinks => 'henüz bağlantı yok';

  @override
  String get roomContentScreenLoadFailed => 'bu yüklenemedi';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return '$name adlı kişiden sesli mesaj';
  }

  @override
  String get roomContentScreenForwardAction => 'İLET';

  @override
  String get roomContentScreenCopyAction => 'KOPYALA';

  @override
  String get roomContentScreenSaveAction => 'KAYDET';

  @override
  String get roomContentScreenShareAction => 'PAYLAŞ';

  @override
  String get roomContentScreenInChatAction => 'SOHBETTE';

  @override
  String get roomContentScreenDeleteAction => 'SİL';

  @override
  String get messageActionMenuReplyLabel => 'YANITLA';

  @override
  String get messageActionMenuForwardLabel => 'İLET';

  @override
  String get messageActionMenuViewThreadLabel => 'YANITLARI GÖR';

  @override
  String get messageActionMenuCopyLabel => 'KOPYALA';

  @override
  String get messageActionMenuCopyNameLabel => 'ADI KOPYALA';

  @override
  String get messageActionMenuPinLabel => 'SABİTLE';

  @override
  String get messageActionMenuUnpinLabel => 'SABİTİ KALDIR';

  @override
  String get messageActionMenuSelectLabel => 'SEÇ';

  @override
  String get messageActionMenuProfileLabel => 'PROFİL';

  @override
  String get messageActionMenuDeleteLabel => 'SİL';

  @override
  String get messageActionMenuReportLabel => 'ŞİKAYET ET';

  @override
  String get themeScreenTitle => 'tema.';

  @override
  String get themeScreenTapToApplyHint =>
      'uygulamak için dokun · tam önizleme için ⛶';

  @override
  String get themeScreenFamilyBasicName => 'TEMEL';

  @override
  String get themeScreenFamilyBasicTagline => 'iOS esintili · 5 palet';

  @override
  String get themeScreenFamilyVaultName => 'KASA';

  @override
  String get themeScreenFamilyVaultTagline => 'gizli dosya · noir + fildişi';

  @override
  String get themeScreenFamilyOthersName => 'DİĞERLERİ';

  @override
  String get themeScreenFamilyOthersTagline => 'kendine özgü modlar';

  @override
  String get themeScreenActiveBadge => 'AKTİF';

  @override
  String get themeScreenTapToApplyLabel => 'uygulamak için dokun';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return 'AKTİF — $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return 'UYGULA: $name';
  }

  @override
  String get themeScreenPreviewGreeting => 'hey, sen.';

  @override
  String get themeScreenPreviewSectionLabel => 'SOHBET';

  @override
  String get themeScreenPreviewRoomOneName => 'tasarım kulübü';

  @override
  String get themeScreenPreviewRoomOneSub => 'mia: yeni tasarımı yayına aldı.';

  @override
  String get themeScreenPreviewRoomTwoName => 'oda · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => '4 saatte mühürlenir.';

  @override
  String get themeScreenPreviewBubbleQuestion => 'nasıl hissettiriyor?';

  @override
  String get themeScreenPreviewBubbleAnswer => 'sanki doğrusu bu.';

  @override
  String get callScreenVideoCallLabel => 'Görüntülü arama';

  @override
  String get callScreenVoiceCallLabel => 'Sesli arama';

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · çalıyor…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · geliyor';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · bağlanıyor…';
  }

  @override
  String get callScreenStatusConnected => 'bağlandı';

  @override
  String get callScreenStatusEnded => 'arama sona erdi';

  @override
  String get callScreenStatusFailed => 'arama başarısız oldu';

  @override
  String get callScreenStatusSwitching => 'cihaz değiştiriliyor…';

  @override
  String get callScreenStatusMoved => 'taşındı';

  @override
  String get callScreenStatusReconnecting => 'yeniden bağlanıyor…';

  @override
  String get callScreenPoorConnectionLabel => 'kötü bağlantı';

  @override
  String get callScreenWeakConnectionLabel => 'zayıf bağlantı';

  @override
  String get callScreenControlUnmute => 'sesi aç';

  @override
  String get callScreenControlMute => 'sesi kapat';

  @override
  String get callScreenControlCamOn => 'kamerayı aç';

  @override
  String get callScreenControlCamOff => 'kamerayı kapat';

  @override
  String get callScreenControlFlip => 'çevir';

  @override
  String get callScreenControlSpeaker => 'hoparlör';

  @override
  String get callScreenControlEnd => 'bitir';

  @override
  String get linkPreviewCardLinkLabel => 'BAĞLANTI';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name isteğini kabul etti';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'o istek geri çekildi';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'istek reddedildi';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'bu kullanıcıyı engelledin — önce engeli kaldır.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'şu anda arkadaşlık isteği kabul etmiyorlar.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'gönderilemedi. tekrar dene.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => 'GELEN İSTEK';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'YENİ İSTEK';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name bir sohbet başlatmak istiyor.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'birkaç satır yaz. onaylayabilir ya da reddedebilir.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'iki taraf da kabul etmeden hiçbir şey kalıcı olmaz.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'ODA TÜRÜ';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'GEÇİCİ';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'STANDART';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'SÜRE';

  @override
  String friendRequestDraftScreenDurationSeconds(Object seconds) {
    return '${seconds}sn';
  }

  @override
  String friendRequestDraftScreenDurationMinutes(Object minutes) {
    return '${minutes}dk';
  }

  @override
  String friendRequestDraftScreenDurationHours(Object hours) {
    return '${hours}sa';
  }

  @override
  String get friendRequestDraftScreenHintWhisperOptional =>
      'bir şeyler fısılda · isteğe bağlı';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'ilk mesajı ekle · isteğe bağlı';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'fısılda · kendiliğinden siliniyor';

  @override
  String get friendRequestDraftScreenHintStartWith =>
      'başlamak için bir şeyler yaz…';

  @override
  String get friendRequestDraftScreenApproveButton => 'ONAYLA VE ODAYI AÇ';

  @override
  String get friendRequestDraftScreenDeclineButton => 'REDDET';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'İSTEĞİ İPTAL ET';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => 'BİR YETİŞKİNE SOR';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'İSTEK GÖNDER';

  @override
  String get discoverScreenTitle => 'keşfet.';

  @override
  String get discoverScreenCaptionPeople => 'kişiler';

  @override
  String get discoverScreenCaptionRooms => 'odalar';

  @override
  String get discoverScreenCaptionRequests => 'istekler';

  @override
  String get discoverScreenPeopleBandLabel => 'KİŞİLER';

  @override
  String get discoverScreenRoomsBandLabel => 'ODALAR';

  @override
  String get discoverScreenFindPeopleTitle => 'kişi bul';

  @override
  String get discoverScreenFindPeopleSubtitleChild => 'tam kullanıcı adını yaz';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      '@kullanıcıadı veya isimle ara';

  @override
  String get discoverScreenRequestsSectionLabel => 'İSTEKLER';

  @override
  String get discoverScreenInboxQuiet => 'gelen kutusu sessiz';

  @override
  String get discoverScreenNothingPending => 'gönderdiğin istek yok';

  @override
  String get discoverScreenYourPeopleLabel => 'ARKADAŞLARIN';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'henüz kimse yok — yukarıdan kişi bul';

  @override
  String get discoverScreenNoFriendsYet => 'henüz kimse yok';

  @override
  String get discoverScreenSearchRoomsTitle => 'oda ara';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'herkese açık bir odayı adıyla bul';

  @override
  String get discoverScreenPublicRoomsLabel => 'HERKESE AÇIK ODALAR';

  @override
  String get discoverScreenLoadingRooms => 'aranıyor…';

  @override
  String get discoverScreenNoRoomsOpen => 'şu an açık oda yok';

  @override
  String get discoverScreenIncomingLabel => 'gelen';

  @override
  String get discoverScreenOutgoingLabel => 'giden';

  @override
  String get discoverScreenIncomingLabelCaps => 'GELEN';

  @override
  String get discoverScreenOutgoingLabelCaps => 'GİDEN';

  @override
  String get discoverScreenJumpPeopleLabel => 'kişiler';

  @override
  String get discoverScreenJumpRoomsLabel => 'odalar';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return '$label bölümüne git';
  }

  @override
  String get imageCropScreenDefaultTitle => 'ayarla';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'FOTOĞRAFI KULLAN';

  @override
  String get imageCropScreenSavingButton => 'KAYDEDİLİYOR…';

  @override
  String get imageCropScreenCancelButton => 'VAZGEÇ';

  @override
  String get imageCropScreenHeicUnsupported =>
      'bu tarayıcı HEIC fotoğrafları açamıyor';

  @override
  String get imageCropScreenLoadFailed => 'bu görseli açamadık';

  @override
  String get imageCropScreenHintCircle =>
      'taşımak için sürükle, yakınlaştırmak için sıkıştır';

  @override
  String get imageCropScreenHintRect => 'çerçevelemek için sürükle ve sıkıştır';

  @override
  String get loginScreenSignInHeroMuted => 'tekrar\n';

  @override
  String get loginScreenSignInHeroInk => 'hoş geldin.';

  @override
  String get loginScreenSignInCta => 'GİRİŞ YAP';

  @override
  String get loginScreenSignUpHeroMuted => 'yeni\n';

  @override
  String get loginScreenSignUpHeroInk => 'üye.';

  @override
  String get loginScreenSignUpCta => 'HESAP AÇ';

  @override
  String get loginScreenResetHeroMuted => 'şifreni\n';

  @override
  String get loginScreenResetHeroInk => 'sıfırla.';

  @override
  String get loginScreenResetCta => 'ŞİFREYİ SIFIRLA';

  @override
  String get loginScreenErrorPasswordsDontMatch => 'Şifreler eşleşmiyor.';

  @override
  String get loginScreenErrorChoosePasswordFirst => 'Önce bir şifre seç.';

  @override
  String get loginScreenUsernameHint => 'kullanıcı adı';

  @override
  String get loginScreenPasswordHint => 'şifre';

  @override
  String get loginScreenConfirmPasswordHint => 'şifreyi onayla';

  @override
  String get loginScreenNameOptionalHint => 'isim (isteğe bağlı)';

  @override
  String get loginScreenRecoveryPhraseHint => '12 kelimelik kurtarma ifaden';

  @override
  String get loginScreenNewPasswordHint => 'yeni şifre';

  @override
  String get loginScreenBackToSignIn => '← girişe dön';

  @override
  String get loginScreenForgotPassword => 'şifreni mi unuttun?';

  @override
  String get loginScreenSettingUpKidsPhone => 'çocuk hesabı kur';

  @override
  String get loginScreenLegalPrefix => 'Hesap açarak ';

  @override
  String get loginScreenLegalTermsLink => 'Kullanım Şartları\'nı';

  @override
  String get loginScreenLegalMiddle => ' ve ';

  @override
  String get loginScreenLegalPrivacyLink => 'Gizlilik Politikası\'nı';

  @override
  String get loginScreenLegalSuffix => ' kabul etmiş olursun.';

  @override
  String get loginScreenAlreadyHerePrompt => 'zaten hesabın var mı? ';

  @override
  String get loginScreenSignInLink => 'giriş yap';

  @override
  String get loginScreenNoAccountPrompt => 'hesabın yok mu? ';

  @override
  String get loginScreenOpenOneLink => 'hemen aç';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12 kelime';
  }

  @override
  String get homeShellEmptyRoomHint => 'sohbete başlamak için bir oda seç';

  @override
  String get homeShellEmptySettingHint => 'bir ayar seç';

  @override
  String get searchScreenHintPeople => 'kişi ara…';

  @override
  String get searchScreenHintRooms => 'oda ara…';

  @override
  String get searchScreenPeoplePromptChild =>
      'yeni birini bulmak için kullanıcı adını eksiksiz yaz';

  @override
  String get searchScreenPeoplePromptDefault =>
      'kullanıcı adına veya isme göre ara';

  @override
  String get searchScreenNoMatchChild =>
      'kimse bulunamadı — yeni biri için kullanıcı adının\ntamamı, harfi harfine gerekiyor';

  @override
  String get searchScreenNoMatchDefault => 'kimse bulunamadı';

  @override
  String get searchScreenNoRoomsYet => 'henüz herkese açık oda yok';

  @override
  String get searchScreenNoRoomsMatch => 'eşleşen herkese açık oda yok';

  @override
  String get searchScreenActionAskToAdd => 'EKLEMEYİ SOR';

  @override
  String get searchScreenActionSendRequest => 'İSTEK GÖNDER';

  @override
  String get searchScreenActionCancel => 'İPTAL';

  @override
  String get searchScreenActionApprove => 'ONAYLA';

  @override
  String get searchScreenActionOpenDm => 'DM\'Yİ AÇ';

  @override
  String get searchScreenAskedLabel => 'soruldu';

  @override
  String get profileVisibilityScreenTitle => 'görünürlük ayarları.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'başkalarının ne gördüğünü ve sana nasıl ulaşabileceğini sen kontrol et.';

  @override
  String get profileVisibilityScreenSectionProfile => 'PROFİL';

  @override
  String get profileVisibilityScreenAvatarLabel => 'AVATAR';

  @override
  String get profileVisibilityScreenAvatarDesc => 'profil fotoğrafın';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => 'ÇEVRİMİÇİ / UZAKTA';

  @override
  String get profileVisibilityScreenOnlineAwayDesc =>
      'şu an aktif görünüp görünmediğin';

  @override
  String get profileVisibilityScreenLastSeenLabel => 'SON GÖRÜLME';

  @override
  String get profileVisibilityScreenLastSeenDesc =>
      'en son ne zaman aktif olduğun';

  @override
  String get profileVisibilityScreenSectionMessages => 'MESAJLAR';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel =>
      'OKUNDU BİLGİSİ GÖNDER';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      'açıkken, mesajlarını okuduğunu diğerleri görebilir';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel =>
      'OKUNDU BİLGİSİNİ GÖSTER';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      'kendi mesajların okunduğunda ’GÖRÜLDÜ’ ibaresini gör';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      'sadece OKUNDU BİLGİSİ GÖNDER’i açan okuyucular buna katkı sağlar. diğerleri görünmez kalır.';

  @override
  String get profileVisibilityScreenSectionPeople => 'KİŞİLER';

  @override
  String get profileVisibilityScreenFriendRequestsLabel =>
      'ARKADAŞLIK İSTEKLERİ';

  @override
  String get profileVisibilityScreenFriendRequestsDesc =>
      'sana kimlerin arkadaşlık isteği gönderebileceği';

  @override
  String get profileVisibilityScreenSupervisedTitle =>
      'BUNLARI BÜYÜKLERİN AYARLIYOR';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      'Burada başkalarının gördüğü her şeyi sen de görebilirsin, ama bunları sadece bir büyüğün değiştirebilir. Fotoğrafını, ne zaman çevrimiçi olduğunu ve en son ne zaman aktif olduğunu her zaman görebilirler.';

  @override
  String get profileVisibilityScreenOptionPublic => 'HERKESE AÇIK';

  @override
  String get profileVisibilityScreenOptionFriends => 'ARKADAŞLAR';

  @override
  String get profileVisibilityScreenOptionNobody => 'HİÇ KİMSE';

  @override
  String get profileVisibilityScreenOptionOn => 'AÇIK';

  @override
  String get profileVisibilityScreenOptionOff => 'KAPALI';

  @override
  String get profileVisibilityScreenOptionAnyone => 'HERKES';

  @override
  String get logoScreenTitle => 'uygulama logosu.';

  @override
  String get logoScreenSubtitle => 'üst çubuktaki simge, karar senin.';

  @override
  String get logoScreenAutoLabel => 'OTOMATİK';

  @override
  String get logoScreenAutoDescription =>
      'temanı izler. simge, paletle birlikte değişir.';

  @override
  String get logoScreenManualLabel => 'MANUEL';

  @override
  String get logoScreenManualDescription =>
      'istediğin simgeyi seç, temanı koru.';

  @override
  String get logoScreenAlwaysDefaultLabel => 'HER ZAMAN VARSAYILAN';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      'tema fark etmeksizin MonkeyHub simgesi.';

  @override
  String get logoScreenActiveBadge => 'AKTİF';

  @override
  String get logoScreenMonkeyCollectionHeader => 'MAYMUN KOLEKSİYONU';

  @override
  String get logoScreenThemesHeader => 'TEMALAR';

  @override
  String get recoveryPhraseScreenCopiedSnackbar =>
      'kopyalandı — güvenli bir yere yapıştır';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'onayla\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'sensin.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Şifren, hesabına başkası kurtarma ifadesi ekleyemesin diye.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'şifre';

  @override
  String get recoveryPhraseScreenContinueButton => 'DEVAM ET';

  @override
  String get recoveryPhraseScreenNotNowLink => 'şimdi değil';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'Şifreni gir.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'kaydet\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => 'bu kelimeleri.';

  @override
  String get recoveryPhraseScreenWordsBody =>
      'Bu on iki kelime, şifreni unutursan hesabına geri dönmenin tek yolu. Bunları sana bir daha gösteremeyiz ve senin için kurtaramayız.';

  @override
  String get recoveryPhraseScreenCopyButton => 'KOPYALA';

  @override
  String get recoveryPhraseScreenPaperHint =>
      'Mümkünse kağıda yaz. Bu telefondaki her şey telefonla birlikte kaybolabilir.';

  @override
  String get recoveryPhraseScreenSavedButton => 'KAYDETTİM';

  @override
  String get recoveryPhraseScreenBackLink => '← geri';

  @override
  String get recoveryPhraseScreenKeepPhraseLink =>
      'şimdi değil — mevcut ifademi koru';

  @override
  String get homeScreenProfileSemanticLabel => 'Profilin';

  @override
  String homeScreenGreeting(Object name) {
    return 'selam, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'Yeni oda';

  @override
  String get homeScreenEmptyRoomsMessage => 'henüz oda yok — birini oluştur';

  @override
  String get groupCallScreenTitleVideo => 'Grup görüntülü arama';

  @override
  String get groupCallScreenTitleVoice => 'Grup sesli arama';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '$count kişi aramada';
  }

  @override
  String get groupCallScreenReconnecting => 'yeniden bağlanıyor…';

  @override
  String get groupCallScreenUnmuteLabel => 'sesi aç';

  @override
  String get groupCallScreenMuteLabel => 'sesi kapat';

  @override
  String get groupCallScreenCamOnLabel => 'kamera aç';

  @override
  String get groupCallScreenCamOffLabel => 'kamera kapat';

  @override
  String get groupCallScreenFlipLabel => 'çevir';

  @override
  String get groupCallScreenSpeakerLabel => 'hoparlör';

  @override
  String get groupCallScreenLeaveLabel => 'ayrıl';

  @override
  String get groupCallScreenYouLabel => 'Sen';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return '$summary filtresi uygulanıyor. Filtreyi değiştir';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => 'Sohbetleri filtrele';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => 'Filtreyi temizle';

  @override
  String get roomFilterDrawerClearLabel => 'temizle';

  @override
  String get roomFilterDrawerDimensionType => 'TÜR';

  @override
  String get roomFilterDrawerDimensionNature => 'NİTELİK';

  @override
  String get roomFilterDrawerDimensionStatus => 'DURUM';

  @override
  String get roomFilterDrawerPanelClear => 'TEMİZLE';

  @override
  String get roomFilterDrawerPanelDone => 'TAMAM';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sohbet',
    );
    return '$label, $_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return '$summary ile eşleşen bir şey yok';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tüm $count sohbeti göster',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tüm $count sohbeti göster',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'yeni oda';

  @override
  String get createRoomSheetTaglineSecret => 'HİÇBİR ŞEY SAKLANMAZ';

  @override
  String get createRoomSheetTaglineRegular => 'KALICI BİR ALAN';

  @override
  String get createRoomSheetNameLabel => 'İSİM';

  @override
  String get createRoomSheetNameHint => 'ona dürüst bir isim ver…';

  @override
  String get createRoomSheetDescriptionLabel => 'AÇIKLAMA · İSTEĞE BAĞLI';

  @override
  String get createRoomSheetDescriptionHint => 'oda hakkında tek satır…';

  @override
  String get createRoomSheetVisibilityLabel => 'GÖRÜNÜRLÜK';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'herkese açık';

  @override
  String get createRoomSheetVisibilityPublicSub => 'herkes bulabilir';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'gizli';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'sadece davetle';

  @override
  String get createRoomSheetTypeLabel => 'TÜR';

  @override
  String get createRoomSheetTypeStandardTitle => 'standart';

  @override
  String get createRoomSheetTypeStandardSub => 'mesajlar kalıcı';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'geçici';

  @override
  String get createRoomSheetTypeEphemeralSub => 'otomatik silinir';

  @override
  String get createRoomSheetMessageLifeLabel => 'MESAJ ÖMRÜ';

  @override
  String createRoomSheetTtlSeconds(Object seconds) {
    return '${seconds}sn';
  }

  @override
  String createRoomSheetTtlMinutes(Object minutes) {
    return '${minutes}dk';
  }

  @override
  String createRoomSheetTtlHours(Object hours) {
    return '${hours}sa';
  }

  @override
  String get createRoomSheetPasswordLabel => 'ŞİFRE · İSTEĞE BAĞLI';

  @override
  String get createRoomSheetPasswordHint => 'bir parola ile kilitle…';

  @override
  String get createRoomSheetNameRequiredError => 'isim gerekli';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Odayı aç';

  @override
  String get createRoomSheetOpenRoomButton => 'ODAYI AÇ';

  @override
  String get familyScreenTitle => 'AİLE';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count şey onayını bekliyor',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => 'şu an çevrimiçi';

  @override
  String get familyScreenPresenceNotPaired => 'henüz eşleştirilmedi';

  @override
  String get familyScreenPresenceJustNow => 'az önce';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return '${minutes}dk önce';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return '${hours}sa önce';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return '${days}g önce';
  }

  @override
  String get familyScreenPairButton => 'EŞLEŞTİR';

  @override
  String get familyScreenReleaseButton => 'SERBEST BIRAK';

  @override
  String get familyScreenSettingsButton => 'AYARLAR';

  @override
  String get familyScreenAddChildButton => 'ÇOCUK EKLE';

  @override
  String get familyScreenEmptyStateTitle => 'henüz çocuk yok';

  @override
  String get familyScreenEmptyStateBody =>
      'Çocuğun için bir hesap oluştur, sonra telefonuyla eşleştir.';

  @override
  String get reactionDetailsSheetTitle => 'TEPKİLER';

  @override
  String get reactionDetailsSheetEmptyState => 'artık burada bir şey yok';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => 'TÜMÜ';

  @override
  String get reactionDetailsSheetYouBadge => 'SEN';

  @override
  String get roomLayoutScreenTitle => 'sohbet listesi.';

  @override
  String get roomLayoutScreenSubtitle =>
      'odalar nasıl sıralanır, filtreler nasıl çalışır';

  @override
  String get roomLayoutScreenLayoutSectionLabel => 'DÜZEN';

  @override
  String get roomLayoutScreenRowLayoutLabel => 'SATIR DÜZENİ';

  @override
  String get roomLayoutScreenRowLayoutDescription =>
      'tek sütun, tam genişlik. bir bakışta kolayca okunur.';

  @override
  String get roomLayoutScreenGridLayoutLabel => 'IZGARA DÜZENİ';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      'iki sütun, kompakt. tek bakışta daha çok oda.';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => 'FİLTRE KONTROLÜ';

  @override
  String get roomLayoutScreenChipRowLabel => 'ETİKET SATIRI';

  @override
  String get roomLayoutScreenChipRowDescription =>
      'her zaman görünür. herhangi bir filtreye tek dokunuş, tek satırlık yer kaplar.';

  @override
  String get roomLayoutScreenDrawerButtonLabel => 'ÇEKMECE DÜĞMESİ';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      'açılan tek bir düğme. sen istemeden hiçbir şey önüne çıkmaz.';

  @override
  String get roomLayoutScreenActiveBadge => 'AKTİF';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel => 'Sabitlenmiş mesaja atla';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => 'Tüm sabitlenmiş mesajlar';

  @override
  String get pinnedBannerTitleSingle => 'Sabitlenmiş mesaj';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return 'Sabitlenmiş mesaj  $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => 'sohbet stili.';

  @override
  String get pinnedBannerChatStyleSubtitle => 'odanın nasıl göründüğü';

  @override
  String get pinnedBannerClassicLabel => 'KLASİK';

  @override
  String get pinnedBannerClassicSubtitle =>
      'çizgili üst bar, sade yazma alanı.';

  @override
  String get pinnedBannerCompactLabel => 'KOMPAKT';

  @override
  String get pinnedBannerCompactSubtitle =>
      'sohbetin üzerinde süzülen buzlu cam kapsüller.';

  @override
  String get pinnedBannerActiveBadge => 'AKTİF';

  @override
  String get audioMessageMissingLabel => '[ses eksik]';

  @override
  String get audioMessageUnavailableLabel => 'ses artık yok';

  @override
  String get audioMessageRetryHint => 'yeniden denemek için dokun';

  @override
  String get audioMessageLoadingLabel => 'yükleniyor…';

  @override
  String get audioMessageUsernameRequiredError => 'Kullanıcı adını gir.';

  @override
  String get audioMessagePasswordRequiredError => 'Şifreni gir.';

  @override
  String get audioMessageCancelSemanticLabel => 'İptal';

  @override
  String get audioMessageHeroCreateLine1 => 'neredeyse\n';

  @override
  String get audioMessageHeroCreateLine2 => 'bitti.';

  @override
  String get audioMessageHeroLinkLine1 => 'tekrar\n';

  @override
  String get audioMessageHeroLinkLine2 => 'hoş geldin.';

  @override
  String get audioMessageCreateSubtitle =>
      'Ailen ve arkadaşların seni bulabilsin diye bir kullanıcı adı seç.';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return 'Bir kez giriş yap, $provider hesabına bağlansın.';
  }

  @override
  String get audioMessageUsernameHint => 'kullanıcı adı';

  @override
  String get audioMessageDisplayNameHint => 'görünen ad (isteğe bağlı)';

  @override
  String get audioMessagePasswordHint => 'şifre';

  @override
  String get audioMessageSwitchToLinkPrompt => 'O hesap benim — giriş yapayım';

  @override
  String get audioMessageCreateAccountButton => 'HESAP OLUŞTUR';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return 'GİRİŞ YAP VE $provider BAĞLA';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => 'Zaten bir hesabın var mı?';

  @override
  String get audioMessageSwitchToCreateModeLink => 'Yeni misin? Hesap oluştur';

  @override
  String get approvalsScreenTitle => 'ONAYLAR';

  @override
  String get approvalsScreenEmptyTitle => 'bekleyen bir şey yok';

  @override
  String get approvalsScreenEmptySubtitle => 'her şey tamam';

  @override
  String get approvalsScreenErrorNotGuardian =>
      'bu senin karar vereceğin bir şey değil';

  @override
  String get approvalsScreenErrorAlreadyHandled =>
      'zaten başka yerden hallolmuş';

  @override
  String get approvalsScreenErrorGeneric => 'kaydedilemedi — tekrar dene';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child, $other adlı kişiyi eklemek istiyor';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other, $child adlı kişiyi eklemek istiyor';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child, $room adlı odaya katılmak istiyor';
  }

  @override
  String get approvalsScreenSomeoneLower => 'biri';

  @override
  String get approvalsScreenSomeoneCapital => 'Biri';

  @override
  String get approvalsScreenRoomFallback => 'bir oda';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      'İsteği alacak, kabul edip etmemeye yine kendisi karar verecek.';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$child isteği görecek, kabul edebilir ya da görmezden gelebilir.';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      'Sen izni geri alana kadar orada okuyup yazabilecek.';

  @override
  String get approvalsScreenNotYetButton => 'HENÜZ DEĞİL';

  @override
  String get approvalsScreenAllowButton => 'İZİN VER';

  @override
  String get approvalsScreenForwardDirectMessageFallback => 'birebir mesaj';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count MESAJI İLET',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'henüz başka sohbet yok';

  @override
  String get approvalsScreenForwardNoMatches => 'eşleşen bir şey yok';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'bir seferde en fazla $max sohbet';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'sohbetlerde ara';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return '$title seçimini kaldır';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return '$title seç';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'KAYBOLUYOR';

  @override
  String get approvalsScreenForwardSendSemantic => 'Gönder';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SOHBETE GÖNDER',
      zero: 'GÖNDER',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => 'BAĞLI HESAPLAR';

  @override
  String get linkedAccountsScreenSubtitle =>
      'Bu hesaba bağladığın hesaplar, şifre girmeden giriş yapabilmen için.';

  @override
  String get linkedAccountsScreenEmptyState =>
      'Bu cihazda bağlanacak bir şey yok.';

  @override
  String get linkedAccountsScreenStatusChecking => 'Kontrol ediliyor…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return '$provider ile tüm cihazlarında giriş yapabilirsin.';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return 'Şifreni yazmak zorunda kalmaman için $provider ekle.';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return '$provider BAĞLANTISINI KES';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => 'BAĞLANTIYI KES';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return '$provider ile giriş yapmayı durdurmak için şifreni gir.';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return '$provider HESABINI BAĞLA';
  }

  @override
  String get linkedAccountsScreenLinkAction => 'BAĞLA';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return '$provider hesabını giriş yöntemi olarak eklemek için şifreni gir.';
  }

  @override
  String get linkedAccountsScreenPillChecking => 'KONTROL EDİLİYOR';

  @override
  String get linkedAccountsScreenPillLinked => 'BAĞLI';

  @override
  String get linkedAccountsScreenPillNotLinked => 'BAĞLI DEĞİL';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => 'SESLİ';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'GÖRÜNTÜLÜ';

  @override
  String get linkedAccountsScreenCallSheetTitle => 'Arama başlat';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle => 'Herkesi ara';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      'Odadaki tüm üyeleri arar';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle => 'Kişi seç';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle =>
      'Kimi davet edeceğini seç';

  @override
  String get linkedAccountsScreenCallSheetCallFullError =>
      'O arama dolu (en fazla 6 kişi)';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError =>
      'Arama başlatılamadı';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle => 'Aramaya davet et';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers =>
      'Burada başka üye yok';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => 'Kişi seç';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => 'Aramayı başlat';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return 'Aramayı başlat ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => 'selam';

  @override
  String get childPairScreenGreetingLine2 => 'sana.';

  @override
  String get childPairScreenIntro =>
      'Bir büyüğünden MonkeyHub’ı açıp “cihaz eşleştir”e dokunmasını iste. Sonra kodunu tarat ya da söylediği altı rakamı yaz.';

  @override
  String get childPairScreenOrDivider => 'ya da';

  @override
  String get childPairScreenGenericError =>
      'Bir şeyler ters gitti. Tekrar dene.';

  @override
  String get childPairScreenAccountGoneError => 'O hesap artık yok.';

  @override
  String get childPairScreenScanButtonLabel => 'KODU TARAT';

  @override
  String get childPairScreenNoCameraMessage =>
      'Burada kamera yok — bunun yerine altı rakamı yaz.';

  @override
  String get childPairScreenStopScanning => 'taramayı durdur';

  @override
  String get childPairScreenSubmitButtonLabel => 'BENİ İÇERİ AL';

  @override
  String get childPairScreenBackToSignIn => '← girişe dön';

  @override
  String get fileMessageUnavailable => 'bu dosya artık mevcut değil';

  @override
  String get fileMessageOpenFailed => 'bu dosya açılamadı';

  @override
  String get fileMessageDefaultName => 'belge';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return '$name dosyasını kaydet';
  }

  @override
  String get fileMessageUploadFailedLabel => 'başarısız';

  @override
  String get fileMessageSendingLabel => 'gönderiliyor…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · gönderiliyor…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return '${count}dk önce';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return '${count}sa önce';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return '${count}g önce';
  }

  @override
  String get fileMessageStandardBadge => 'STANDART';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taslak mesaj · görüntülemek için dokun',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => 'ONAYLA';

  @override
  String get fileMessageDeclineButton => 'REDDET';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return '$ago GÖNDERİLDİ';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesaj bekliyor',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => 'İSTEĞİ İPTAL ET';

  @override
  String get destructiveSheetCannotBeUndone => 'bu geri alınamaz';

  @override
  String get destructiveSheetCancelSemanticLabel => 'İptal';

  @override
  String get destructiveSheetCancelButtonLabel => 'İPTAL';

  @override
  String get destructiveSheetHideLabel => 'GİZLE';

  @override
  String get destructiveSheetViewLabel => 'GÖSTER';

  @override
  String get destructiveSheetPairingMintError =>
      'Kod oluşturulamadı — tekrar dene.';

  @override
  String get destructiveSheetPairingReleaseTitle => 'SERBEST BIRAK';

  @override
  String get destructiveSheetPairingPairTitle => 'EŞLEŞTİR';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return '$name’in telefonunda profiline gir, “telefonu geri ver”e dokun ve bu numaraları yaz.';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return '$name’in telefonunda MonkeyHub’ı aç ve bunu tara — ya da numaraları yaz.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'bu kodun süresi doldu';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return '$time içinde sona erer';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'YENİ KOD';

  @override
  String get destructiveSheetPairingOneUseNote =>
      'Sadece bir kez kullanılır. Yeni kod oluşturmak eskisini iptal eder.';

  @override
  String get deepOceanThemeAttachButtonLabel => 'Ekle';

  @override
  String get deepOceanThemeCameraButtonLabel => 'Kamera';

  @override
  String get deepOceanThemeSendButtonLabel => 'Gönder';

  @override
  String get deepOceanThemeEphemeralHint =>
      'sunucunun unutacağı bir şey fısılda…';

  @override
  String get deepOceanThemeDefaultHint => 'bir şeyler söyle…';

  @override
  String get deepOceanThemeMessageHint => 'Mesaj';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'bu dosya artık yok';

  @override
  String get photoChromeMediaYouLabel => 'sen';

  @override
  String get photoChromeCloseSemanticLabel => 'Kapat';

  @override
  String get photoChromeShowInChatSemanticLabel => 'Sohbette göster';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name yazıyor';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1 ve $name2 yazıyor';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1, $name2 +$extra kişi yazıyor';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => 'gelen arama';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'GELEN GÖRÜNTÜLÜ ARAMA';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'GELEN SESLİ ARAMA';

  @override
  String get typingIndicatorDeclineButtonLabel => 'reddet';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'reddediliyor…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'kabul et';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'bağlanıyor…';

  @override
  String get messageStampNavigationTitle => 'gezinme.';

  @override
  String get messageStampNavigationSubtitle =>
      'sohbet, keşfet, akış ve ayarlar arasında nasıl gezindiğin';

  @override
  String get messageStampRadialOrbLabel => 'RADYAL KÜRE';

  @override
  String get messageStampRadialOrbDescription =>
      'köşeden basılı tutup sürükle. sessiz duruyor, zamanla alışacağın bir hareket.';

  @override
  String get messageStampBottomPillLabel => 'ALT KAPSÜL';

  @override
  String get messageStampBottomPillDescription =>
      'klasik dokunuş. her zaman görünür, öğrenmesi kolay.';

  @override
  String get messageStampActiveLabel => 'AKTİF';

  @override
  String get messageStampUploadingLabel => 'yükleniyor';

  @override
  String get messageStampSendingLabel => 'gönderiliyor';

  @override
  String get messageStampFailedToSendLabel => 'gönderilemedi';

  @override
  String get messageStampSeenLabel => 'görüldü';

  @override
  String messageStampCountdownSeconds(Object count) {
    return '${count}sn';
  }

  @override
  String messageStampCountdownMinutes(Object count) {
    return '${count}dk';
  }

  @override
  String get voiceRecorderScreenMicPermissionDeniedSnackbar =>
      'mikrofon izni verilmedi';

  @override
  String get voiceRecorderScreenStatusRecording => 'KAYDEDİLİYOR';

  @override
  String get voiceRecorderScreenStatusReady => 'HAZIR';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'BAŞLATMAK İÇİN DOKUN';

  @override
  String get voiceRecorderScreenReRecordButton => 'TEKRAR KAYDET';

  @override
  String get voiceRecorderScreenStopButton => 'DURDUR';

  @override
  String get voiceRecorderScreenSendButton => 'GÖNDER';

  @override
  String get voiceRecorderScreenRecordButton => 'KAYDET';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => 'Herkes';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => 'HERKESE BİLDİRİR';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => 'SAHİP';

  @override
  String get releaseDeviceScreenFallbackChildName => 'o';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return '$name bu telefondan çıkış yapar ve telefon geri teslim edilir — telefon normal giriş ekranına döner, artık herkes kullanabilir.';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'Hesabı, mesajları ve arkadaşları olduğu gibi kalır. İstediği zaman tekrar giriş yapabilir.';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return 'Bir yetişkinden MonkeyHub’ı açmasını, aile bölümünden $name bulmasını ve “bırak”a dokunmasını iste.';
  }

  @override
  String get releaseDeviceScreenOrDivider => 'veya';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      'Eğer tek telefon buysa, bir yetişkin bunun yerine buradan giriş yapabilir.';

  @override
  String get releaseDeviceScreenUsernameHint => 'bir yetişkinin kullanıcı adı';

  @override
  String get releaseDeviceScreenPasswordHint => 'şifresi';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => 'Çıkış yap';

  @override
  String get releaseDeviceScreenChecking => 'KONTROL EDİLİYOR…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return '$name ÇIKIŞ YAPSIN';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => 'TELEFONU GERİ VER';

  @override
  String get releaseDeviceScreenErrorCodeExpired =>
      'Kodun süresi doldu. Yeni bir kod iste.';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      'O kod işe yaramadı. Daha önce kullanılmış olabilir.';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      'Bu işe yaramadı. Kullanıcı adını ve şifreni kontrol et.';

  @override
  String get releaseDeviceScreenErrorGeneric =>
      'Bir şeyler ters gitti. Tekrar dene.';

  @override
  String get activeCallPillMoveHereSemanticLabel => 'Görüşmeyi bu cihaza taşı';

  @override
  String activeCallPillCallWith(Object name) {
    return '$name ile görüşme';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return 'Cihaz: $device';
  }

  @override
  String get activeCallPillMoveHereLabel => 'Buraya taşı';

  @override
  String get activeCallPillUnknownCaller => 'Bilinmeyen';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'iOS Simülatörü';

  @override
  String get activeCallPillPlatformAndroid => 'Android cihaz';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'Windows bilgisayar';

  @override
  String get activeCallPillPlatformLinux => 'Linux cihaz';

  @override
  String get activeCallPillPlatformBrowser => 'Tarayıcı';

  @override
  String get activeCallPillPlatformOther => 'başka bir cihaz';

  @override
  String get activeCallPillPinnedHeader => 'SABİTLENENLER';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'SABİTLENENLER · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'artık sabitlenen yok';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return '$name tarafından gönderilen mesaja git';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return '$name tarafından gönderilen mesajı sabitlemeden kaldır';
  }

  @override
  String get callButtonErrorBusy => 'başka bir görüşmede meşgul';

  @override
  String get callButtonErrorCallFailed => 'arama başlatılamadı';

  @override
  String get callButtonErrorNotMember => 'bu odanın üyesi değilsin';

  @override
  String get callButtonErrorGeneric => 'arama başlatılamadı';

  @override
  String get callButtonAlreadyOnCall => 'Zaten bir görüşmedesin';

  @override
  String get callButtonBusyElsewhere => 'Başka bir cihazda görüşme sürüyor';

  @override
  String get callButtonVoiceCallTooltip => 'sesli arama';

  @override
  String get callButtonVideoCallTooltip => 'görüntülü arama';

  @override
  String get callButtonTooltip => 'arama';

  @override
  String get callButtonReplyStyleTitle => 'yanıt stili.';

  @override
  String get callButtonReplyStyleSubtitle =>
      'bir yanıt, yanıtladığı mesajı nasıl gösterir';

  @override
  String get callButtonReplyStylePhantomEchoLabel => 'HAYALET YANKI';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      'üst mesajın hayalet balonu, kıvrık bir bağlantı çizgisi ve birleşme noktasındaki dal ikonuyla yukarıda süzülür.';

  @override
  String get callButtonReplyStyleStickyNoteLabel => 'YAPIŞKAN NOT';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      'balonun köşesine tutturulmuş, hafif eğik polaroid tarzı bir kart.';

  @override
  String get callButtonReplyStyleComicTailLabel => 'ÇİZGİ ROMAN KUYRUK';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      'aşağıyı gösteren çizgi roman tarzı üçgen kuyruklu, küçük bir üst mesaj balonu.';

  @override
  String get callButtonReplyStyleClassicLabel => 'KLASİK';

  @override
  String get callButtonReplyStyleClassicDescription =>
      'vurgu renkli alıntı kapsülü, bağlantı çubuğu ve avatarla — WhatsApp’tan aşina olduğun o görünüm.';

  @override
  String get callButtonReplyStyleActiveBadge => 'AKTİF';

  @override
  String get callButtonReplyPreviewSampleMessage =>
      'bu arada yeni demoyu gördün mü?';

  @override
  String get callButtonReplyPreviewSampleReply =>
      'evet, o blur efekti resmen efsane.';

  @override
  String get childSetupScreenErrorPickUsername =>
      'Onun için bir kullanıcı adı seç.';

  @override
  String get childSetupScreenErrorUsernameTaken =>
      'Bu kullanıcı adı zaten alınmış.';

  @override
  String get childSetupScreenErrorChildNotAllowed =>
      'Sadece bir yetişkin hesabı çocuk ekleyebilir.';

  @override
  String get childSetupScreenErrorGeneric =>
      'Hesap oluşturulamadı — tekrar dene.';

  @override
  String get childSetupScreenTitle => 'ÇOCUK EKLE';

  @override
  String get childSetupScreenHeading => 'bu\nkim?';

  @override
  String get childSetupScreenNameLabel => 'İSİM';

  @override
  String get childSetupScreenNameHint => 'ona ne diyorsun';

  @override
  String get childSetupScreenUsernameLabel => 'KULLANICI ADI';

  @override
  String get childSetupScreenUsernameHint => 'arkadaşları onu böyle bulur';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'NE ALACAK';

  @override
  String get childSetupScreenBulletTalkImmediately =>
      'Seninle ve kardeşleriyle hemen konuşabilir.';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      'Geri kalan herkes için önce senin onayın gerekir — hem onun eklemek istediği kişiler, hem de onu eklemek isteyenler için.';

  @override
  String get childSetupScreenBulletPublicRoomsOff =>
      'Sen açana kadar herkese açık odalar kapalı kalır.';

  @override
  String get childSetupScreenBulletCantSignOut =>
      'Çıkış yapamaz ve sen her zaman nasıl gittiğini görebilirsin.';

  @override
  String get childSetupScreenCreateButton => 'OLUŞTUR + EŞLE';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return '$name kişisine mesaj gönder';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => 'istendi';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'ÜYE';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'tümünü gör ($count)';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return 'Tümünü gör ($count)';
  }

  @override
  String get bubbleStyleScreenTitle => 'baloncuk stili.';

  @override
  String get bubbleStyleScreenSubtitle => 'sözlerinin geldiği şekil';

  @override
  String get bubbleStyleScreenTailedLabel => 'KUYRUKLU';

  @override
  String get bubbleStyleScreenTailedDescription =>
      'her mesaj serisini bir kuyruk kapatır; üstündeki satırlar tek bir bloğa sıkışır.';

  @override
  String get bubbleStyleScreenSoftLabel => 'YUMUŞAK';

  @override
  String get bubbleStyleScreenSoftDescription =>
      'kuyruk yok — bir seri yalnızca sıkışan iç köşeleriyle bir arada durur.';

  @override
  String get bubbleStyleScreenPillLabel => 'KAPSÜL';

  @override
  String get bubbleStyleScreenPillDescription =>
      'tamamen yuvarlak kapsüller, her satırda birbirinin aynısı.';

  @override
  String get bubbleStyleScreenSlabLabel => 'BLOK';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'köşeli omuzlar — keskin, baskı gibi, kararlı.';

  @override
  String get bubbleStyleScreenActiveBadge => 'AKTİF';

  @override
  String get bubbleStyleScreenPreviewQuestion => 'eee? nasıl görünüyor';

  @override
  String get bubbleStyleScreenPreviewReplyOne => 'daha iyi';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => 'çok daha iyi';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => 'Video';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => 'Fotoğraf';

  @override
  String get incomingGroupCallScreenCallFullError =>
      'O arama dolu (en fazla 6 kişi)';

  @override
  String get incomingGroupCallScreenJoinFailedError => 'Aramaya katılınamadı';

  @override
  String get incomingGroupCallScreenDefaultRoomName => 'Grup araması';

  @override
  String get incomingGroupCallScreenDefaultStarterName => 'Biri';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starter görüntülü arama başlattı';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starter sesli arama başlattı';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '$count kişi zaten içeride';
  }

  @override
  String get incomingGroupCallScreenDismissButton => 'Reddet';

  @override
  String get incomingGroupCallScreenJoinButton => 'Katıl';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sohbet',
    );
    return '$_temp0';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesaj',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      'son mesaj az önce';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'son mesaj $hours saat önce';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'son mesaj dün';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'son mesaj $days gün önce';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'son mesaj bir süre önce';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'GERİ AL';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return '$contactName’ı $childName’dan geri mi alalım?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'artık birbirlerine ulaşamazlar, sohbetleri de bununla birlikte silinir.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'artık birbirlerine ulaşamazlar. $contactName bundan haberdar edilmez.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats · $messages silinecek';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      'ikisi için de silinir, fotoğraflar ve sesli notlar dahil. bu geri alınamaz.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ayrıca $count oda paylaşıyorlar',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'bunlar kalır. onları çıkarmak istersen aşağıdaki ODALAR listesinden odayı geri al.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'GERİ AL VE SİL';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return '$contactName’ı kaldırır ve $messages siler.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return '$contactName’ı izin verilenler listesinden kaldırır.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'İptal';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => 'İPTAL';

  @override
  String get groupCallBannerCallFullError => 'Bu arama dolu (en fazla 6 kişi)';

  @override
  String get groupCallBannerJoinFailedError => 'Aramaya katılamadın';

  @override
  String get groupCallBannerUnknownParticipant => 'Biri';

  @override
  String get groupCallBannerOngoingVideoCall => 'Devam eden görüntülü arama';

  @override
  String get groupCallBannerOngoingVoiceCall => 'Devam eden sesli arama';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra aramada';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => 'Aramaya katıl';

  @override
  String get groupCallBannerJoinButtonLabel => 'KATIL';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'ODAYA KATIL';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count üye',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => 'ŞİFRE';

  @override
  String get groupCallBannerPasswordHint => 'parola…';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Katıl';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'KATIL';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Vazgeç';

  @override
  String get groupCallBannerCancelButtonLabel => 'vazgeç';

  @override
  String get viewOnceViewerBadgeLabel => 'TEK SEFERLİK';

  @override
  String get viewOnceViewerSocialDividerOr => 'veya';

  @override
  String get viewOnceViewerAppleContinueButton => 'Apple ile Devam Et';

  @override
  String get viewOnceViewerGoogleContinueButton => 'Google ile Devam Et';

  @override
  String get discoverListsPeopleTitle => 'arkadaşların.';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => 'arkadaşlarını filtrele…';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Filtreyi temizle';

  @override
  String get discoverListsNoOneYet => 'henüz kimse yok';

  @override
  String discoverListsNoMatches(Object query) {
    return '\"$query\" ile eşleşen kimse yok';
  }

  @override
  String get discoverListsVoiceCallLabel => 'SESLİ ARAMA';

  @override
  String get discoverListsVideoCallLabel => 'GÖRÜNTÜLÜ ARAMA';

  @override
  String get approvalGateAlreadyAskedLabel => 'ZATEN SORULDU';

  @override
  String get approvalGateAskGrownUpLabel => 'BÜYÜĞE SOR';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return '$what hakkında zaten sordun.';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return '$what için önce bir büyüğün onay vermesi gerekiyor.';
  }

  @override
  String get approvalGateDisabledBody => 'Bir büyük şu an bunu kapatmış.';

  @override
  String get approvalGateAlreadyAskedFooter =>
      'Onlara bir mesaj gidecek. Birazdan tekrar bak.';

  @override
  String get approvalGateWillNotifyFooter =>
      'Onlara haber vereceğiz. Cevap verdiklerinde burada göreceksin.';

  @override
  String get approvalGateTalkToThemFooter =>
      'Bunun değişmesi gerektiğini düşünüyorsan onlarla konuşabilirsin.';

  @override
  String get approvalGateAskButton => 'SOR';

  @override
  String get approvalGateNotNowButton => 'ŞİMDİ DEĞİL';

  @override
  String get approvalGateOkButton => 'TAMAM';

  @override
  String get approvalGateWaitingPillLabel => 'büyük onayı bekleniyor';

  @override
  String get reportSheetTitle => 'ŞİKAYET';

  @override
  String get reportSheetSubtitle => 'sorunu bize anlat.';

  @override
  String get reportSheetPrivacyNote =>
      'şikayetler gizlidir — karşı taraf bilgilendirilmez.';

  @override
  String get reportSheetReasonSpamLabel => 'SPAM';

  @override
  String get reportSheetReasonSpamDescription =>
      'istenmeyen reklamlar veya tekrarlanan mesajlar';

  @override
  String get reportSheetReasonHarassmentLabel => 'TACİZ';

  @override
  String get reportSheetReasonHarassmentDescription =>
      'hedef alma veya zorbalık';

  @override
  String get reportSheetReasonImpersonationLabel => 'SAHTECİLİK';

  @override
  String get reportSheetReasonImpersonationDescription =>
      'başkasıymış gibi davranma';

  @override
  String get reportSheetReasonInappropriateLabel => 'UYGUNSUZ';

  @override
  String get reportSheetReasonInappropriateDescription =>
      'cinsel, şiddet içeren veya yasa dışı içerik';

  @override
  String get reportSheetReasonOtherLabel => 'DİĞER';

  @override
  String get reportSheetReasonOtherDescription => 'başka bir şey';

  @override
  String get reportSheetOtherNoteHint => 'ne oldu?';

  @override
  String get reportSheetSubmitSemanticLabel => 'Şikayeti gönder';

  @override
  String get reportSheetSubmitButton => 'GÖNDER';

  @override
  String get reportSheetUpdateRequiredTitle => 'GÜNCELLEME GEREKLİ';

  @override
  String get reportSheetUpdateAvailableTitle => 'GÜNCELLEME MEVCUT';

  @override
  String get reportSheetUpdateMandatoryBody =>
      'Bu sürüm artık düzgün çalışamayacak kadar eski. Devam etmek için güncelle.';

  @override
  String get reportSheetUpdateAvailableBody =>
      'MonkeyHub’ın yeni bir sürümü var.';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => 'GÜNCELLE';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'TestFlight’ı açar';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'App Store’u açar';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'Google Play’i açar';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'indirme sayfasını açar';

  @override
  String get reportSheetUpdateActionReloads => 'yeni sürümle yeniden yükler';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Sonra';

  @override
  String get reportSheetUpdateLaterButton => 'SONRA';

  @override
  String get roomFilterBarAllChipLabel => 'tümü';

  @override
  String roomFilterBarChipCountSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sohbet',
    );
    return '$label, $_temp0';
  }

  @override
  String composerReplyCardReplyingToLabel(Object name) {
    return 'YANITLIYORSUN: $name';
  }

  @override
  String get roomCardLockedBadge => 'KİLİTLİ';

  @override
  String get roomCardTimeAgoJustNow => 'az önce';

  @override
  String roomCardTimeAgoSeconds(Object seconds) {
    return '${seconds}sn';
  }

  @override
  String roomCardTimeAgoMinutes(Object minutes) {
    return '${minutes}dk';
  }

  @override
  String roomCardTimeAgoHours(Object hours) {
    return '${hours}sa';
  }

  @override
  String roomCardTimeAgoDays(Object days) {
    return '${days}g';
  }

  @override
  String roomCardTimeAgoWeeks(Object weeks) {
    return '${weeks}hf';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count kişi içeride';
  }

  @override
  String get roomCardMessagesFadeLabel => 'mesajlar kayboluyor';

  @override
  String get roomCardEnterLabel => '↗ gir';

  @override
  String get roomCardBlockedScreenTitle => 'ENGELLENENLER';

  @override
  String get roomCardBlockedEmptyState => 'henüz kimseyi engellemedin.';

  @override
  String get roomCardUnblockButton => 'ENGELİ KALDIR';

  @override
  String get attachmentMenuPhotoLabel => 'fotoğraf';

  @override
  String get attachmentMenuVideoLabel => 'video';

  @override
  String get attachmentMenuCameraLabel => 'kamera';

  @override
  String get attachmentMenuVoiceLabel => 'ses';

  @override
  String get attachmentMenuFileLabel => 'dosya';

  @override
  String get attachmentMenuConnectionRetrying => 'yeniden deneniyor…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'sunucuya ulaşılamıyor · yeniden denemek için dokun';

  @override
  String get attachmentMenuConnectionReconnecting => 'yeniden bağlanıyor…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Bağlantıyı yeniden dene';

  @override
  String get roomGridTileLockedBadge => 'KİLİTLİ';

  @override
  String get roomGridTileEmptyLastMessage => 'şimdilik sessiz';

  @override
  String get roomGridTileMemberCountLabel => 'İÇERİDE';

  @override
  String get roomGridTileThemeChipLabel => 'TEMA';

  @override
  String get bulkActionBarCancelLabel => 'İPTAL';

  @override
  String get bulkActionBarSelectMessagesLabel => 'MESAJ SEÇ';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count SEÇİLDİ';
  }

  @override
  String get bulkActionBarForwardLabel => 'İLET';

  @override
  String get bulkActionBarDeleteLabel => 'SİL';

  @override
  String get bulkActionBarJumpBackLabel => 'GERİ';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return 'GERİ · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel => 'Ayrıldığın yere geri dön';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return 'Ayrıldığın yere geri dön, $depth kaldı';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote => 'haberi olmayacak.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'şu an arkadaşsınız — engellemek arkadaşlığı sonlandırır, yani tekrar bağlanmak için yeni bir arkadaşlık isteği göndermen gerekir.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'aramalarında karşına çıkmaz ve sana mesaj atamaz.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'ENGELLE';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return '$name engellensin mi?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'onlarla $count oda paylaşıyorsun',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'bu odalara dokunulmaz. istersen her birinden kendi ayarlarından ayrılabilirsin.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'ENGELLE';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'arkadaşlığı kaldırır ve engeller. mevcut sohbet geçmişi arşivinde kalır.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'aramalarda gizlenir ve sana ulaşamaz.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'ENGELLE VE DM’Yİ SİL';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'ayrıca onlarla olan DM’ini de siler — tüm mesajlar, tepkiler ve medya dosyaları yok olur.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'İptal';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'İPTAL';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle =>
      'Aramaları kilit ekranında göster';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      'Ekranın kapalıyken gerçek bir telefon araması gibi çalması için MonkeyHub’ın \"tam ekran bildirimler\" iznine ihtiyacı var. Sıradaki ekran seni doğrudan ilgili ayara götürür.';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle =>
      'Hiçbir aramayı kaçırma';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      'Bazı telefonlar pil tasarrufu için arka plandaki uygulamaları durdurur, bu da gelen aramaları sessize alabilir. Aramaların her zaman ulaşması için MonkeyHub’ın kısıtlamasız çalışmasına izin ver.';

  @override
  String get bulkActionBarDialogNotNowButton => 'Şimdi değil';

  @override
  String get bulkActionBarDialogContinueButton => 'Devam et';

  @override
  String get reactionBubbleJumpToLatestLabel => 'SON MESAJA GİT';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel => 'Son mesaja git';

  @override
  String get reactionBubblePickerTitle => 'TEPKİ VER';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'henüz son kullanılan yok';

  @override
  String get reactionBubblePasswordHint => 'şifre';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return '$roomName odasına katılmak';
  }

  @override
  String get enterPublicRoomAskFailedMessage => 'şu an soramadık — tekrar dene';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'yanlış şifre';

  @override
  String get enterPublicRoomJoinFailedMessage => 'katılamadık — tekrar dene';

  @override
  String get feedBoardTitle => 'BUGÜN';

  @override
  String feedBoardEditionLabel(Object number) {
    return '№$number';
  }

  @override
  String get feedBoardHighlightsLabel => 'ÖNE ÇIKANLAR';

  @override
  String get feedBoardHighlightsEmpty => 'bugün henüz bir şey yakalanmadı';

  @override
  String get feedBoardPuzzleLabel => 'BULMACA';

  @override
  String get feedBoardPuzzleEmpty => 'bugünün bulmacası henüz hazır değil';

  @override
  String get feedBoardStandingsLabel => 'HAYAT PUANI';

  @override
  String get feedBoardStandingsEmpty => 'bugün tabloda puan yok';

  @override
  String get feedBoardActivityLabel => 'ETKİNLİK';

  @override
  String get feedBoardActivityEmpty => 'bugün şimdilik sessiz';

  @override
  String get feedBoardActivityNoFriends =>
      'bir arkadaş ekle, günü burada görünsün';

  @override
  String get feedBoardLoadFailed => 'pano yüklenemedi — birazdan tekrar dene';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'HERKESE AÇIK';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'ÖZEL';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'KATILDIN';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'GEÇİCİ · $duration';
  }

  @override
  String enterPublicRoomEphemeralSecondsShort(Object seconds) {
    return '${seconds}sn';
  }

  @override
  String enterPublicRoomEphemeralMinutesShort(Object minutes) {
    return '${minutes}dk';
  }

  @override
  String enterPublicRoomEphemeralHoursShort(Object hours) {
    return '${hours}sa';
  }

  @override
  String get countBadgeCaptureProtectionLabel => 'EKRAN YAKALAMA KORUMASI';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      'ekran görüntüleri ve ekran kaydı sistem tarafından siyah gösterilir.';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      'ekran kaydı ve yansıtma, uygulamanın üzerine bir gizlilik kalkanı indirir.';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      'geçici (kaybolan) odalar dışında ekran görüntüsü ve kayıt normal şekilde çalışır.';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      'geçici (sırlar odası) odalarında bu, ne olursa olsun her zaman açıktır.';

  @override
  String get countBadgeShowPasswordTooltip => 'şifreyi göster';

  @override
  String get countBadgeHidePasswordTooltip => 'şifreyi gizle';

  @override
  String get countBadgeProtectedLabel => 'KORUMALI';

  @override
  String get countBadgeCaptureShieldActiveBody =>
      'ekran kaydı veya yansıtma etkin.';

  @override
  String get countBadgeCaptureShieldReassurance =>
      'kayıt, konuşmalarını göremez.';

  @override
  String get linkOpenerCouldNotOpenLink => 'Bağlantı açılamadı';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel =>
      'Kurtarma parolası oluştur';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'kurtarma parolası yok — bir daha giremeyebilirsin.';

  @override
  String get destinationsChatLabel => 'Sohbet';

  @override
  String get destinationsChatShort => 'SOHBET';

  @override
  String get destinationsDiscoverLabel => 'Keşfet';

  @override
  String get destinationsDiscoverShort => 'BUL';

  @override
  String get destinationsFeedLabel => 'Akış';

  @override
  String get destinationsFeedShort => 'AKIŞ';

  @override
  String get destinationsSettingsLabel => 'Ayarlar';

  @override
  String get destinationsSettingsShort => 'AYAR';

  @override
  String get familyRequestStageSenderGuardianLabel =>
      'bir büyüğün onayı bekleniyor';

  @override
  String get familyRequestStageRecipientLabel => 'yanıt bekleniyor';

  @override
  String get roomContentTabLabelMedia => 'MEDYA';

  @override
  String get roomContentTabLabelFiles => 'DOSYALAR';

  @override
  String get roomContentTabLabelVoice => 'SES';

  @override
  String get roomContentTabLabelLinks => 'BAĞLANTILAR';

  @override
  String get roomContentTabHeaderMedia => 'medya';

  @override
  String get roomContentTabHeaderFiles => 'dosyalar';

  @override
  String get roomContentTabHeaderVoice => 'ses';

  @override
  String get roomContentTabHeaderLinks => 'bağlantılar';

  @override
  String get roomFacetLabelDms => 'birebir';

  @override
  String get roomFacetLabelGroups => 'gruplar';

  @override
  String get roomFacetLabelPublic => 'açık';

  @override
  String get roomFacetLabelPrivate => 'özel';

  @override
  String get roomFacetLabelSecret => 'gizli';

  @override
  String get roomFacetLabelLocked => 'kilitli';

  @override
  String get roomFacetLabelUnread => 'okunmamış';

  @override
  String get roomFacetLabelMentions => 'bahsetmeler';

  @override
  String get settingsScreenTitle => 'AYARLAR';

  @override
  String get settingsScreenTagline => 'görünüş. his. sen.';

  @override
  String get settingsScreenAccountHintChild => 'profil · gizlilik · büyüklerim';

  @override
  String get settingsScreenAccountHintAdult =>
      'profil · aile · bağlı hesaplar · gizlilik';

  @override
  String get settingsScreenSectionAppearance => 'GÖRÜNÜM';

  @override
  String get settingsScreenSectionLayout => 'DÜZEN';

  @override
  String get settingsScreenSectionGeneral => 'GENEL';

  @override
  String get settingsScreenCheckForUpdatesLabel => 'GÜNCELLEMELERİ KONTROL ET';

  @override
  String get settingsScreenUpdateAvailableValue => 'GÜNCELLEME MEVCUT';

  @override
  String get settingsScreenUpdateUpToDateSnackbar =>
      'En son sürümü kullanıyorsun.';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      'Bu sürümde güncellemeler kontrol edilemiyor.';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      'Güncellemeler kontrol edilemedi. Daha sonra tekrar dene.';

  @override
  String get settingsScreenSectionLinks => 'BAĞLANTILAR';

  @override
  String get settingsScreenSectionNotifications => 'BİLDİRİMLER';

  @override
  String get reportProblemRowLabel => 'Sorun bildir';

  @override
  String get reportProblemRowValue => 'Ayrıntıları bize gönderin';

  @override
  String get reportProblemIntro =>
      'Neyin yanlış gittiğini anlatın. Uygulama ve cihaz bilgileriniz otomatik olarak eklenir — nedeni bulmamıza yardımcı olur.';

  @override
  String get reportProblemDescribeLabel => 'NE OLDU';

  @override
  String get reportProblemDescribeHint =>
      'Ekran titriyor, düğmeler yanıt vermiyor…';

  @override
  String get reportProblemScreenshotsLabel => 'EKRAN GÖRÜNTÜLERİ';

  @override
  String get reportProblemAddScreenshot => 'Ekran görüntüsü ekle';

  @override
  String get reportProblemDetailsLabel => 'BİLGİLERİNİZ';

  @override
  String get reportProblemCopyDetails => 'Bilgileri kopyala';

  @override
  String get reportProblemCopied => 'Kopyalandı';

  @override
  String get reportProblemSend => 'Raporu gönder';

  @override
  String reportProblemEmailInstead(String email) {
    return 'Veya $email adresine e-posta gönderin';
  }

  @override
  String get reportProblemShakeTitle => 'Sorun bildirilsin mi?';

  @override
  String get reportProblemShakeBody =>
      'Telefonunuzu salladınız. Rapor ekranı açılsın mı?';

  @override
  String get reportProblemShakeOpen => 'Bildir';

  @override
  String get reportProblemShakeDismiss => 'Şimdi değil';

  @override
  String get settingsCallDeliveryLockScreenLabel => 'Kilit ekranı aramaları';

  @override
  String get settingsCallDeliveryBackgroundLabel => 'Arka plan etkinliği';

  @override
  String get settingsCallDeliveryStatusOff => 'İzin vermek için dokun';

  @override
  String get settingsScreenRowTheme => 'TEMA';

  @override
  String get settingsScreenRowAppLogo => 'UYGULAMA LOGOSU';

  @override
  String get settingsScreenRowGlass => 'CAM';

  @override
  String get settingsScreenRowChatList => 'SOHBET LİSTESİ';

  @override
  String get settingsScreenRowNavigation => 'GEZİNME';

  @override
  String get settingsScreenRowChatStyle => 'SOHBET STİLİ';

  @override
  String get settingsScreenRowBubbleStyle => 'BALONCUK STİLİ';

  @override
  String get settingsScreenRowReplyStyle => 'YANIT STİLİ';

  @override
  String get settingsScreenValueScrollList => 'Kaydırmalı liste';

  @override
  String get settingsScreenValueGridSheet => 'Izgara görünümü';

  @override
  String get settingsScreenValueRadialOrb => 'Radyal küre';

  @override
  String get settingsScreenValueBottomPill => 'Alt kapsül';

  @override
  String get settingsScreenValueCustom => 'Özel';

  @override
  String settingsScreenValueEdited(Object name) {
    return '$name · düzenlendi';
  }

  @override
  String get settingsScreenValueClassic => 'Klasik';

  @override
  String get settingsScreenValueCompact => 'Kompakt';

  @override
  String get settingsScreenValueBubbleTailed => 'Kuyruklu';

  @override
  String get settingsScreenValueBubbleSoft => 'Yumuşak';

  @override
  String get settingsScreenValueBubblePill => 'Kapsül';

  @override
  String get settingsScreenValueBubbleSlab => 'Blok';

  @override
  String get settingsScreenValueReplyPhantomEcho => 'Hayalet Yankı';

  @override
  String get settingsScreenValueReplyStickyNote => 'Yapışkan Not';

  @override
  String get settingsScreenValueReplyComicTail => 'Çizgi Kuyruk';

  @override
  String get settingsScreenValueLogoAuto => 'Otomatik';

  @override
  String get settingsScreenValueLogoManual => 'Manuel';

  @override
  String get settingsScreenShowLinkUrlsLabel => 'BAĞLANTI ADRESLERİNİ GÖSTER';

  @override
  String get settingsScreenLinksUrlsOnBody =>
      'önizleme kartının yanında tam adres de görünür';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      'şuan sadece önizleme — daha sade baloncuklar, açmak için dokun';

  @override
  String get settingsScreenSectionCalls => 'ARAMALAR';

  @override
  String get settingsScreenRowVideoQuality => 'Video kalitesi';

  @override
  String get settingsScreenValueVideoQualityAuto => 'Otomatik';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel =>
      'ARAMA İSTATİSTİKLERİNİ GÖSTER';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      'aramalar sırasında canlı çözünürlük, bit hızı, ping ve paket kaybı';

  @override
  String get videoQualityScreenTitle => 'Video kalitesi';

  @override
  String get videoQualityScreenSubtitle =>
      'Giden video için bir çözünürlük sınırı seç';

  @override
  String get videoQualityScreenAutoSubtitle =>
      'Bağlantına otomatik olarak uyum sağlar';

  @override
  String get videoQualityScreenHd1080Subtitle =>
      'Full HD — daha keskin, daha fazla veri kullanır';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD — güçlü bağlantılarda en iyisi';

  @override
  String get videoQualityScreenFootnote =>
      'Gerçek çözünürlük her iki cihazın kamerasına ve ağ koşullarına bağlıdır.';

  @override
  String get callScreenControlOptions => 'Diğer';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => 'Gecikme sapması';

  @override
  String get callScreenStatsLossLabel => 'Kayıp';

  @override
  String get callScreenSwapPreviewSemanticLabel =>
      'Kamera görünümlerini değiştir';

  @override
  String get callOptionsSheetTitle => 'Arama seçenekleri';

  @override
  String get settingsScreenPushNotificationsLabel => 'ANLIK BİLDİRİMLER';

  @override
  String get settingsScreenPushOnBody => 'yeni mesaj ve isteklerde seni uyarır';

  @override
  String get settingsScreenPushOffBody =>
      'sessiz — her şeyi ancak uygulamayı açınca görürsün';

  @override
  String get authErrorUsernameTaken => 'Bu kullanıcı adı zaten alınmış.';

  @override
  String get authErrorUserNotFound => 'Bu kullanıcı adında bir hesap yok.';

  @override
  String get authErrorWrongPassword => 'Yanlış şifre.';

  @override
  String get authErrorInvalidRecoveryKey =>
      'Bu kullanıcı adı ve kurtarma ifadesi eşleşmiyor.';

  @override
  String get authErrorTooManyAttempts =>
      'Çok fazla deneme yaptın. 15 dakika bekleyip tekrar dene.';

  @override
  String get authErrorChildMustPair =>
      'Bu bir çocuk hesabı — bir yetişkinden eşleştirme kodu iste.';

  @override
  String get authErrorPairingCodeExpired =>
      'Bu kodun süresi doldu. Yeni bir tane iste.';

  @override
  String get authErrorPairingCodeInvalid =>
      'Bu kod çalışmadı. Daha önce kullanılmış olabilir.';

  @override
  String get authErrorUseSocialSignIn =>
      'Bu hesap Apple veya Google ile giriş yapıyor — aşağıdaki butonları kullan.';

  @override
  String get authErrorSocialTokenInvalid =>
      'Bu giriş işlemi tamamlanamadı. Lütfen tekrar dene.';

  @override
  String get authErrorSocialNonceMismatch =>
      'Bu giriş işlemi tamamlanamadı. Lütfen tekrar dene.';

  @override
  String get authErrorSocialMisconfig =>
      'Giriş sistemi bizim tarafımızda henüz hazır değil. Daha sonra tekrar dene.';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      'Bu Apple veya Google hesabı zaten başka bir MonkeyHub hesabına bağlı.';

  @override
  String get authErrorSocialAlreadyLinked => 'Bu zaten bu hesaba bağlı.';

  @override
  String get authErrorSocialNotLinked => 'Bu, bu hesaba bağlı değil.';

  @override
  String get authErrorSocialLastCredential =>
      'Bu hesaba girişin tek yolu bu. Önce bir şifre belirle.';

  @override
  String get authErrorUsernameInvalid =>
      '1 ile 32 karakter arasında bir kullanıcı adı seç.';

  @override
  String get glassKnobLabelFrost => 'BUZLANMA';

  @override
  String get glassKnobHintFrost =>
      'camın üzerinde ne kadar beyazlık olduğu. azalt, şeffaflaşsın';

  @override
  String get glassKnobLabelBlur => 'BULANIKLIK';

  @override
  String get glassKnobHintBlur => 'üst uçta buzlu, alt uçta duru cam';

  @override
  String get glassKnobLabelSaturation => 'RENK SIZMASI';

  @override
  String get glassKnobHintSaturation =>
      'renklerin bulanıklıktan ne kadarının kurtulduğu. 2’den sonra posterize olur';

  @override
  String get glassKnobLabelRimOpacity => 'KENARLIK';

  @override
  String get glassKnobHintRimOpacity =>
      'vurgu rengindeki kenar çizgisi. kenarlıksız yüzey için sıfırla';

  @override
  String get glassKnobLabelRimWidth => 'KENARLIK KALINLIĞI';

  @override
  String get glassKnobHintRimWidth => 'o çizginin kalınlığı';

  @override
  String get glassKnobLabelShadowOpacity => 'GÖLGE';

  @override
  String get glassKnobHintShadowOpacity =>
      'yüzeyin arkasındakinden ne kadar yukarıda süzüldüğü';

  @override
  String get glassKnobLabelShadowBlur => 'GÖLGE YAYILIMI';

  @override
  String get glassKnobHintShadowBlur =>
      'yumuşak ve geniş, ya da sıkı ve keskin';

  @override
  String get glassKnobLabelShadowY => 'GÖLGE DÜŞÜŞÜ';

  @override
  String get glassKnobHintShadowY => 'yüzeyin ne kadar altına düştüğü';

  @override
  String get glassKnobLabelBarMargin => 'YAN BOŞLUK';

  @override
  String get glassKnobHintBarMargin =>
      'çubukla ekranın kenarı arasındaki boşluk';

  @override
  String get glassKnobLabelBarBottom => 'ALT BOŞLUK';

  @override
  String get glassKnobHintBarBottom => 'çubuğun alttan ne kadar yükseldiği';

  @override
  String get glassKnobLabelShellPadH => 'UÇ BOŞLUĞU';

  @override
  String get glassKnobHintShellPadH =>
      'çubuğun kenarından ilk kapsüle kadar. küçük tut, yoksa uçlar yalnız kalır';

  @override
  String get glassKnobLabelShellPadV => 'ÜST BOŞLUK';

  @override
  String get glassKnobHintShellPadV =>
      'çubuğun kenarından kapsülün üstüne kadar';

  @override
  String get glassKnobLabelIndicatorInset => 'KAPSÜL GİRİNTİSİ';

  @override
  String get glassKnobHintIndicatorInset =>
      'seçim kapsülünün kendi bölmesinin ne kadar içinde durduğu';

  @override
  String get glassKnobLabelSegmentPadV => 'SATIR BOŞLUĞU';

  @override
  String get glassKnobHintSegmentPadV =>
      'ikonun ve etiketinin üstündeki ve altındaki boşluk';

  @override
  String get glassKnobLabelIconLabelGap => 'İKON BOŞLUĞU';

  @override
  String get glassKnobHintIconLabelGap =>
      'bir ikonla altındaki kelime arasındaki boşluk';

  @override
  String get glassKnobLabelIconSize => 'İKON BOYUTU';

  @override
  String get glassKnobLabelLabelSize => 'ETİKET BOYUTU';

  @override
  String get languageOptionSpanish => 'ESPAÑOL';

  @override
  String get languageValueSpanish => 'Español';

  @override
  String get languageOptionFrench => 'FRANÇAIS';

  @override
  String get languageValueFrench => 'Français';

  @override
  String get languageOptionPortuguese => 'PORTUGUÊS (PORTUGAL)';

  @override
  String get languageValuePortuguese => 'Português (Portugal)';

  @override
  String get languageOptionSwedish => 'SVENSKA';

  @override
  String get languageValueSwedish => 'Svenska';

  @override
  String get languageOptionPortugueseBrazil => 'PORTUGUÊS (BRASIL)';

  @override
  String get languageValuePortugueseBrazil => 'Português (Brasil)';

  @override
  String get languageOptionArabic => 'العربية';

  @override
  String get languageValueArabic => 'العربية';

  @override
  String get languageOptionChinese => '简体中文';

  @override
  String get languageValueChinese => '简体中文';

  @override
  String get languageOptionHindi => 'हिन्दी';

  @override
  String get languageValueHindi => 'हिन्दी';

  @override
  String get languageOptionKorean => '한국어';

  @override
  String get languageValueKorean => '한국어';

  @override
  String get languageOptionJapanese => '日本語';

  @override
  String get languageValueJapanese => '日本語';

  @override
  String get settingsScreenRowMotion => 'HAREKET';

  @override
  String get settingsScreenValueMotionFull => 'Tam';

  @override
  String get settingsScreenValueMotionCalm => 'Sakin';

  @override
  String get settingsScreenValueMotionSystemFull => 'Cihazla aynı · tam';

  @override
  String get settingsScreenValueMotionSystemCalm => 'Cihazla aynı · sakin';

  @override
  String get motionScreenTitle => 'hareket.';

  @override
  String get motionScreenSubtitle => 'uygulama ne kadar hareket etsin';

  @override
  String get motionScreenSystemLabel => 'CİHAZLA AYNI';

  @override
  String get motionScreenSystemSubtitleFull =>
      'cihazın şu anda animasyona izin veriyor';

  @override
  String get motionScreenSystemSubtitleCalm =>
      'cihazın şu anda az hareket istiyor';

  @override
  String get motionScreenFullLabel => 'TAM';

  @override
  String get motionScreenFullSubtitle => 'her kayma, parıltı ve süsleme';

  @override
  String get motionScreenCalmLabel => 'SAKİN';

  @override
  String get motionScreenCalmSubtitle =>
      'süslemeler durur — başka hiçbir şey değişmez';

  @override
  String get momentRailCaptureLabel => 'YAKALA';

  @override
  String get momentRailYouLabel => 'sen';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String get momentTagFate => 'TESADÜF';

  @override
  String get momentTagJinx => 'KERİZLİK';

  @override
  String get momentTagLuck => 'ŞANS';

  @override
  String get momentTagCalledIt => 'DEMİŞTİM';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'ne tesadüf';

  @override
  String get momentTagJinxHint => 'kendi ettin kendi buldun';

  @override
  String get momentTagLuckHint => 'işine geldi';

  @override
  String get momentTagCalledItHint => 'geleceği görmüştün';

  @override
  String get momentTagNpcHint => 'beyin tamamen kapalı';

  @override
  String get momentComposerTitle => 'ne oldu?';

  @override
  String get momentComposerCaptionHint => 'bir şeyler yaz';

  @override
  String get momentComposerTagPrompt => 'puan mı kazandın? hemen ekle';

  @override
  String get momentComposerCapture => 'kamera';

  @override
  String get momentComposerLibrary => 'galeri';

  @override
  String get momentComposerRemovePhoto => 'fotoğrafı kaldır';

  @override
  String get momentComposerPost => 'PAYLAŞ';

  @override
  String get momentComposerErrorDailyCap =>
      'bugünlük beş tane oldu — yarına da kalsın';

  @override
  String get momentComposerErrorNotAllowed =>
      'veli fotoğraf paylaşımını kapatmış';

  @override
  String get momentComposerErrorTooLong => 'biraz uzun olmuş — kısalt';

  @override
  String get momentComposerErrorEmpty =>
      'bir fotoğraf ya da birkaç kelime ekle';

  @override
  String get momentComposerErrorGeneric => 'paylaşılamadı — tekrar dene';

  @override
  String get momentViewerDelete => 'sil';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who bir an paylaştı';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name bir $tag aldı';
  }

  @override
  String get momentActivityJustNow => 'şimdi';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '${count}dk';
  }

  @override
  String momentActivityHoursAgo(Object count) {
    return '${count}sa';
  }

  @override
  String momentActivityMoreCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bugün $count tane daha',
    );
    return '$_temp0';
  }

  @override
  String get puzzleScreenTitle => 'bulmaca.';

  @override
  String get puzzleScreenSubtitle => 'dört sembol, altı hak';

  @override
  String get puzzleSubmit => 'TAHMİN';

  @override
  String get puzzleBackspace => 'son sembolü sil';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'sembol $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return '$count tahminde çözüldü';
  }

  @override
  String get puzzleFailedTitle => 'hakkın bitti';

  @override
  String get puzzleAnswerWas => 'KOD ŞUYDU';

  @override
  String get puzzleShare => 'SONUCU KOPYALA';

  @override
  String get puzzleShareCopied => 'kopyalandı — bir arkadaşına yapıştır';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'bugünkünü zaten çözdün';

  @override
  String get puzzleErrorOutOfGuesses => 'bugün hakkın kalmadı';

  @override
  String get puzzleErrorGeneric => 'tahmin gönderilemedi — tekrar dene';

  @override
  String get puzzleScoreboardLabel => 'BUGÜNÜN SKORLARI';

  @override
  String get puzzleScoreboardEmpty => 'bugün henüz kimse bitirmedi';

  @override
  String get puzzleTilePlay => 'bugünün bulmacasını oyna';

  @override
  String puzzleTileInProgress(Object count) {
    return '$count hak kaldı';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '$total kişi içinde #$rank';
  }

  @override
  String get profileVisibilityScreenSectionFeed => 'AKIŞ';

  @override
  String get profileVisibilityScreenFeedLabel => 'öne çıkanlarım';

  @override
  String get profileVisibilityScreenFeedDesc =>
      'paylaştığın fotoğraf ve videoların o gün arkadaşlarının panosunda görünüp görünmeyeceği';

  @override
  String get profileVisibilityScreenPuzzleLabel => 'bulmaca skorum';

  @override
  String get profileVisibilityScreenPuzzleDesc =>
      'arkadaşlarının günlük bulmacada nasıl yaptığını görüp göremeyeceği';

  @override
  String get profileVisibilityScreenPointsPastLabel => 'geçmişim';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      'bugün her zaman arkadaşlarınla paylaşılır — bu, öncesindeki her şeyi açar';

  @override
  String get momentComposerVideo => 'video';

  @override
  String get momentComposerErrorTooBig => 'bu video çok büyük — en fazla 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => 'bir an paylaştın';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'bir $tag aldın';
  }

  @override
  String pointLineSelf(Object tag) {
    return 'sen · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'ne oldu?';

  @override
  String get pointComposerNoteHint => 'yukarıdan birini seç, sonra anlat';

  @override
  String get pointComposerAdd => 'PUAN EKLE';

  @override
  String get pointComposerAddPhoto => 'fotoğraf ekle';

  @override
  String get pointsBoardAdd => 'PUAN EKLE';

  @override
  String get pointsExplainerOpen => 'bu ne?';

  @override
  String get pointsExplainerTitle => 'puan oyunu';

  @override
  String get pointsExplainerIntro =>
      'Skorunu tuttuğun bir muhabbet. Başına bir şey geldiğinde — iyi, kötü ya da sadece tuhaf — kaydediyorsun ve o gün panoda duruyor.';

  @override
  String get pointsExplainerRuleHonour =>
      'Puanı kendin veriyorsun. Kimse denetlemiyor — zaten eğlencesi bu, abartırsan arkadaşların zaten söyler.';

  @override
  String get pointsExplainerRuleToday =>
      'Puanlar her gün sıfırlanır. Pano bugünü gösterir; kendi geçmişin sende kalır.';

  @override
  String get pointsExplainerRuleCap =>
      'Aynı türden günde beş tane — kimse panoyu saçmalığa çeviremesin diye.';

  @override
  String get pointsExplainerGotIt => 'ANLADIM';

  @override
  String get momentTagFateExample => 'başka ülkede dişçime rastladım';

  @override
  String get momentTagJinxExample =>
      'arabayı yıkadım, saat dörtte yağmur yağdı';

  @override
  String get momentTagLuckExample => 'treni iki saniyeyle yakaladım';

  @override
  String get momentTagCalledItExample => 'devam filmi batar demiştim, battı';

  @override
  String get momentTagNpcExample => 'garsona ‘sen de’ dedim';

  @override
  String feedBoardEditionHint(Object number) {
    return 'akışın $number. günü';
  }

  @override
  String get feedBoardHighlightsHint => 'bakmaya değer fotoğraflar ve videolar';

  @override
  String get profileVisibilityScreenPointsLabel => 'puanlarım';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'kaydettiğin puanların arkadaşlarının panosunda görünüp görünmeyeceği';

  @override
  String get momentComposerEditPhoto => 'kırpmayı düzenle';

  @override
  String get archiveScreenTitle => 'arşivin';

  @override
  String get archiveScreenEnd => 'hepsi bu kadar';

  @override
  String get archiveScreenEmptyTitle => 'henüz bir şey saklanmadı';

  @override
  String get archiveScreenEmptyBody =>
      'anlar bir gün sonra arkadaşlarının panosundan gider, ama burada sende kalır.';

  @override
  String get archiveScreenEmptyFriendTitle => 'burada bir şey yok';

  @override
  String get archiveScreenEmptyFriendBody =>
      'henüz görebileceğin bir şey paylaşmamış.';

  @override
  String get archiveScreenPrivateTitle => 'geçmişi gizli';

  @override
  String get archiveScreenPrivateBody =>
      'bugün paylaştıklarını yine de görebilirsin.';

  @override
  String get archiveScreenNotFriendTitle => 'arkadaş değilsiniz';

  @override
  String get archiveScreenNotFriendBody =>
      'yalnızca bir arkadaşının günlerine geri bakabilirsin.';

  @override
  String get archiveScreenErrorTitle => 'yüklenemedi';

  @override
  String get archiveScreenErrorBody => 'bağlantını kontrol edip tekrar dene.';

  @override
  String get feedBoardOpenArchive => 'arşiv';
}
