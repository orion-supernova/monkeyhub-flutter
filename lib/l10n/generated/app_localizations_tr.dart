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
  String get roomScreenUnreadDivider => 'OKUNMAMIŞ MESAJLAR';

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
  String get profileScreenChangeNameTitle => 'isim değiştir?';

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
  String get profileScreenNameNotSaved =>
      'Adınız kaydedilemedi. Lütfen tekrar deneyin.';

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
  String get settingsScreenSectionHelpAndLegal => 'YARDIM VE YASAL';

  @override
  String get settingsScreenLicence => 'LİSANS';

  @override
  String get profileScreenLinkedAccountsLabel => 'BAĞLI HESAPLAR';

  @override
  String get profileScreenLinkedAccountsNone => 'bağlı hesap yok';

  @override
  String get profileScreenMyGrownUps => 'BÜYÜKLERİM';

  @override
  String get profileScreenNameHint => 'odada nasıl görüneceğin';

  @override
  String get profileScreenChangeUsernameTitle => 'kullanıcı adını değiştir?';

  @override
  String get profileScreenChangeUsernameWarning =>
      'Girişte bunu kullanıyorsun, yani bundan sonra yenisini yazacaksın. Eski kullanıcı adın başkasının alabilmesi için serbest kalır ve 30 gün boyunca tekrar değiştiremezsin. Seni etiketleyen eski mesajlarda eski adın kalır.';

  @override
  String get profileScreenUsernameHint => 'arkadaşların seni böyle bulur';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return '$date tarihinde tekrar değiştirilebilir';
  }

  @override
  String get profileScreenUsernamePasswordTitle => 'senin olduğunu doğrula';

  @override
  String get profileScreenUsernamePasswordAction => 'KULLANICI ADINI DEĞİŞTİR';

  @override
  String get profileScreenUsernameProviderTitle => 'girişinle doğrula';

  @override
  String profileScreenUsernameChanged(String username) {
    return 'Artık @$username oldun.';
  }

  @override
  String get profileScreenUsernameNotSaved =>
      'Kullanıcı adın değiştirilemedi. Lütfen tekrar deneyin.';

  @override
  String get usernameStatusChecking => 'kontrol ediliyor…';

  @override
  String get usernameStatusAvailable => 'uygun';

  @override
  String get usernameStatusTaken => 'zaten alınmış';

  @override
  String get usernameStatusReserved => 'kullanılamaz';

  @override
  String get usernameStatusInvalid => '1–32 karakter';

  @override
  String get usernameStatusUnknown => 'kontrol edilemedi';

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
  String get settingsScreenPrivacyPolicy => 'GİZLİLİK POLİTİKASI';

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
  String get settingsScreenTermsOfService => 'KULLANIM KOŞULLARI';

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
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: açık';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: kapalı';

  @override
  String get cameraEditorScreenHdNote => 'tam çözünürlükte gönderiliyor';

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
  String get threadOverlayCoordinatesCopiedToast => 'koordinatlar kopyalandı';

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
  String get roomInfoScreenEndConversationConfirmTitle =>
      'bu sohbeti sonlandır?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName da bu sohbeti kaybeder — her iki tarafta da tüm mesajlar silinir. bu geri alınamaz.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'SONLANDIR';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'diğer kişi';

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
  String get roomInfoScreenEndingConversationButton => 'SONLANDIRILIYOR…';

  @override
  String get roomInfoScreenEndConversationButton => 'SOHBETİ SONLANDIR';

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
  String get roomInfoScreenOwnerBadge => 'SAHİP';

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
  String get roomContentScreenEmptySaved =>
      'henüz bir şey kaydedilmedi. bir mesaja basılı tutup KAYDET’i seç.\n\nburada tuttukların yalnızca sana ait — sabitlenmiş bir mesajı ise odadaki herkes görür.';

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
  String get messageActionMenuEditLabel => 'DÜZENLE';

  @override
  String get messageStampEditedLabel => 'düzenlendi';

  @override
  String get composerEditCardTitle => 'MESAJI DÜZENLE';

  @override
  String get spoilerRevealHint =>
      'Spoiler — gizli metni göstermek için etkinleştir';

  @override
  String get formatToolbarFormatLabel => 'Biçim';

  @override
  String get formatToolbarBoldLabel => 'Kalın';

  @override
  String get formatToolbarItalicLabel => 'İtalik';

  @override
  String get formatToolbarStrikethroughLabel => 'Üstü çizili';

  @override
  String get formatToolbarUnderlineLabel => 'Altı çizili';

  @override
  String get formatToolbarSpoilerLabel => 'Spoiler';

  @override
  String get formatToolbarLinkLabel => 'Bağlantı';

  @override
  String get formatToolbarCodeLabel => 'Kod';

  @override
  String get linkInputSheetTitle => 'BAĞLANTI';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => 'BAĞLANTIYI UYGULA';

  @override
  String get linkInputSheetApplySub =>
      'Seçili metne dokunulduğunda bu adres açılır';

  @override
  String get linkInputSheetRemoveLabel => 'BAĞLANTIYI KALDIR';

  @override
  String get linkConfirmSheetTitle => 'BU BAĞLANTI AÇILSIN MI?';

  @override
  String get linkConfirmSheetOpenLabel => 'BAĞLANTIYI AÇ';

  @override
  String get linkConfirmSheetCancelLabel => 'İPTAL';

  @override
  String get roomScreenEditExpiredSnack =>
      'Düzenlemek için çok geç — mesajlar yalnızca 15 dakika içinde düzenlenebilir.';

  @override
  String get roomScreenEditFailedSnack =>
      'Düzenleme kaydedilemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get messageActionMenuForwardLabel => 'İLET';

  @override
  String get messageActionMenuViewThreadLabel => 'YANITLARI GÖR';

  @override
  String get messageActionMenuCopyLabel => 'KOPYALA';

  @override
  String get messageActionMenuCopyNameLabel => 'ADI KOPYALA';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'KOORDİNATLARI KOPYALA';

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
  String get discoverScreenYourRoomsLabel => 'ODALARIN';

  @override
  String get discoverScreenNoRoomsYet => 'henüz oda yok';

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
  String get loginScreenSignInFirstHeroMuted => 'merhaba\n';

  @override
  String get loginScreenSignInFirstHeroInk => 'hoş geldin.';

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
  String get recoveryPhraseScreenConfirmHeroMuted => 'doğrula\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'kimliğini.';

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
  String get roomLayoutScreenQuietRoomSectionLabel => 'SESSİZ ODALAR';

  @override
  String get roomLayoutScreenPlainCornerLabel => 'boş köşe';

  @override
  String get roomLayoutScreenPlainCornerDescription =>
      'henüz konuşulmamış oda sade kalır';

  @override
  String get roomLayoutScreenMonogramLabel => 'odanın baş harfi';

  @override
  String get roomLayoutScreenMonogramDescription =>
      'boş köşeyi büyük, soluk bir harf doldurur';

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
  String get profileScreenDeleteAccountFailed =>
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
  String fileMessageViewSemanticLabel(Object name) {
    return '$name dosyasını görüntüle';
  }

  @override
  String get textFileViewerDownloadTooltip => 'İndir';

  @override
  String get textFileViewerTruncatedNotice =>
      'Bu dosyanın yalnızca bir kısmı gösteriliyor — kalanını görmek için indirin.';

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
  String get deepOceanThemeEphemeralHint => 'bir şey fısılda…';

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
  String get photoChromeFillToggleSemanticLabel =>
      'Ekrana sığdır veya ekranı doldur';

  @override
  String get photoChromeShowInChatSemanticLabel => 'Sohbette göster';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return '$total öğeden $current.';
  }

  @override
  String photoTrayCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotoğraf',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => 'bu fotoğrafları bırak';

  @override
  String get photoTrayRemoveSemanticLabel => 'bu fotoğrafı çıkar';

  @override
  String get photoTrayEditSemanticLabel => 'bu fotoğrafı kırp veya üzerine çiz';

  @override
  String get photoTrayAddMoreSemanticLabel => 'daha fazla fotoğraf ekle';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'tek seferde $count fotoğraf gönderebilirsin';
  }

  @override
  String get photoTrayLoadFailedSnack => 'o fotoğrafların bazıları açılamadı';

  @override
  String get mediaPickFailedMessage => 'bu açılamadı — tekrar seçmeyi dene';

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
  String get messageStampSentLabel => 'gönderildi';

  @override
  String get messageStampDeliveredLabel => 'iletildi';

  @override
  String get messageStampSeenLabel => 'görüldü';

  @override
  String get messageStampSavedLabel => 'kaydedildi';

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
  String get socialButtonDividerOr => 'veya';

  @override
  String get socialButtonGoogleContinue => 'Google ile Devam Et';

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
  String get discoverListsRoomsTitle => 'odaların.';

  @override
  String discoverListsRoomsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oda',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterRoomsHint => 'odalarını filtrele…';

  @override
  String get discoverListsNoRoomsYet => 'henüz oda yok';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return '\"$query\" ile eşleşen oda yok';
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
  String roomCardStartedAgo(Object ago) {
    return '$ago kuruldu';
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
  String get reactionBubbleSearchHint => 'emoji ara';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'eşleşme yok';

  @override
  String get reactionBubbleSearchBackSemanticLabel => 'Emojilere dön';

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
  String get roomBadgePublicTooltip =>
      'Bu odayı herkes bulabilir ve katılabilir';

  @override
  String get roomBadgePrivateTooltip =>
      'Yalnızca davetle — Keşfet\'te görünmez';

  @override
  String get roomBadgeLockedTooltip => 'Katılmak için oda şifresi gerekir';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return 'Mesajlar $duration sonra kaybolur';
  }

  @override
  String get roomBadgeJoinedTooltip => 'Bu odada zaten varsın';

  @override
  String get roomInfoSheetDetailsLabel => 'DETAYLAR';

  @override
  String get roomInfoSheetNoDescription => 'henüz açıklama yok';

  @override
  String get roomInfoSheetCreatedLabel => 'OLUŞTURULDU';

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
  String get roomContentTabLabelSaved => 'KAYDEDİLENLER';

  @override
  String get roomContentTabHeaderMedia => 'medya';

  @override
  String get roomContentTabHeaderFiles => 'dosyalar';

  @override
  String get roomContentTabHeaderVoice => 'ses';

  @override
  String get roomContentTabHeaderLinks => 'bağlantılar';

  @override
  String get roomContentTabHeaderSaved => 'kaydedilenler';

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
  String get settingsScreenSectionChat => 'SOHBET';

  @override
  String get settingsScreenSectionCompanions => 'YARDIMCILAR';

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
  String get settingsScreenSectionNotifications => 'BİLDİRİMLER';

  @override
  String get reportProblemRowLabel => 'Sorun bildir';

  @override
  String get reportProblemRowValue => 'Ayrıntıları bize gönderin';

  @override
  String get reportProblemIntro =>
      'Neyin yanlış gittiğini anlatın. Uygulama ve cihaz bilgileriniz, uygulamanın o sırada ne yaptığını gösteren teknik bir kayıtla birlikte otomatik olarak eklenir — nedeni bulmamıza yardımcı olan şey bu.';

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
  String get reportProblemSent => 'Rapor gönderildi — teşekkürler!';

  @override
  String get reportProblemSendFailed =>
      'Rapor gönderilemedi. Bağlantınızı kontrol edip tekrar deneyin.';

  @override
  String get reportProblemTooMany =>
      'Kısa süre içinde çok fazla rapor gönderdiniz. Lütfen biraz sonra tekrar deneyin.';

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
  String get settingsScreenMenuBarLabel => 'MENÜ ÇUBUĞU SİMGESİ';

  @override
  String get settingsScreenMenuBarOnBody =>
      'MonkeyHub okunmamış sayısıyla menü çubuğunda durur — pencere için tıkla';

  @override
  String get settingsScreenMenuBarOffBody =>
      'şuan kapalı — gizli pencereye dönmenin tek yolu Dock simgesi';

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
  String get settingsScreenGameRemindersLabel => 'GÜNLÜK OYUN HATIRLATMASI';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'öğlen tek bir dürtme, yalnızca oynamadıysan';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'hatırlatma yok — oyunlar baktığında yine orada';

  @override
  String get authErrorUsernameTaken => 'Bu kullanıcı adı zaten alınmış.';

  @override
  String get authErrorUsernameReserved =>
      'Bu kullanıcı adı kullanılamıyor. Lütfen başka bir tane seçin.';

  @override
  String get authErrorDisplayNameReserved =>
      'Bu ad kullanılamıyor. Lütfen başka bir ad seçin.';

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
  String get authErrorUsernameChangedRecently =>
      'Kullanıcı adını yakın zamanda değiştirdin. Sonuncusundan 30 gün sonra tekrar değiştirebilirsin.';

  @override
  String get authErrorInboxHandleLocked =>
      'Bu hesap herkesin sorun bildirimlerini alıyor, bu yüzden kullanıcı adı sabit.';

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
  String get momentViewerDeleteConfirmHeadline => 'bunu sil?';

  @override
  String get momentViewerDeleteConfirmBody =>
      'herkesin panosundan ve arşivinden tamamen silinir';

  @override
  String get momentViewerDeleteFailed => 'silinemedi — tekrar dene';

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

  @override
  String get feedBoardGamesLabel => 'OYUNLAR';

  @override
  String get feedBoardGamesOpen => 'tüm oyunlar';

  @override
  String get gamesScreenTitle => 'oyunlar.';

  @override
  String get gamesScreenSubtitle => 'günde dört tahta, herkese aynısı';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bugün $count tane kaldı',
      one: 'bugün bir tane kaldı',
      zero: 'bugünlük hepsi bitti',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => 'bugünün oyunları yüklenemedi';

  @override
  String get gamesRetry => 'TEKRAR DENE';

  @override
  String get gameQueensName => 'kraliçeler';

  @override
  String get gameQueensRule =>
      'her satır, sütun ve renkte bir taç — asla bitişik değil';

  @override
  String get gameTangoName => 'tango';

  @override
  String get gameTangoRule => 'üç güneş, üç ay, asla art arda üç tane';

  @override
  String get gameZipName => 'zip';

  @override
  String get gameZipRule => 'her kareden geçen tek bir çizgi, sayılar sırayla';

  @override
  String get gameSudokuName => 'mini sudoku';

  @override
  String get gameSudokuRule =>
      'her satır, sütun ve kutuda 1\'den 6\'ya birer kez';

  @override
  String get gameCodeName => 'şifre';

  @override
  String get gameStatusUnplayed => 'oynanmadı';

  @override
  String get gameStatusUnfinished => 'devam ediyor';

  @override
  String get gameStatusGaveUp => 'pes etti';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'duraklat';

  @override
  String get gameResume => 'devam et';

  @override
  String get gamePausedTitle => 'duraklatıldı';

  @override
  String get gamePausedBody => 'sayaç durdu, tahta gizlendi';

  @override
  String get gameUndo => 'geri al';

  @override
  String get gameClear => 'temizle';

  @override
  String get gameHint => 'ipucu';

  @override
  String get gameNotes => 'notlar';

  @override
  String get gameErase => 'sil';

  @override
  String get gameAutoCross => 'otomatik çarpı';

  @override
  String get gameGiveUp => 'pes et';

  @override
  String get gameGiveUpTitle => 'cevabı göster?';

  @override
  String get gameGiveUpBody =>
      'bugünün tahtası kapanır ve çözülmemiş olarak kaydedilir.';

  @override
  String get gameGiveUpCancel => 'DEVAM ET';

  @override
  String get gameGiveUpConfirm => 'GÖSTER';

  @override
  String gameSolvedTitle(Object time) {
    return '$time içinde çözüldü';
  }

  @override
  String get gameGaveUpTitle => 'bugünün cevabı';

  @override
  String get gameFirstInToday => 'bugünün ilki';

  @override
  String gameRankLine(Object place, Object total) {
    return 'şimdilik $total kişi içinde $place.';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hata',
      one: '1 hata',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ipucu',
      one: '1 ipucu',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => 'BUGÜNÜN SÜRELERİ';

  @override
  String get gameStandingsEmpty => 'bunu henüz kimse bitirmedi';

  @override
  String get gameShare => 'SONUCU KOPYALA';

  @override
  String get gameShareCopied => 'kopyalandı — bir arkadaşına yapıştır';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => 'tüm oyunlar';

  @override
  String get gameElapsedSemantic => 'geçen süre';

  @override
  String get gameErrorNotSolved => 'bu tahta henüz bitmedi';

  @override
  String get gameErrorAlreadyFinished => 'bugünkünü zaten bitirdin';

  @override
  String get gameErrorNoHint => 'bunda ipucu yok';

  @override
  String get gameErrorGeneric => 'oyunlara ulaşılamadı — tekrar dene';

  @override
  String get gameInfoOpen => 'nasıl oynanır';

  @override
  String get gameInfoLabel => 'NASIL OYNANIR';

  @override
  String get gameInfoRulesLabel => 'KURALLAR';

  @override
  String get gameInfoControlsLabel => 'KONTROLLER';

  @override
  String get gameInfoScoringTimed =>
      'tahta ekrandayken sayaç işler, duraklattığında ya da çıktığında durur. en hızlı olan bugünün listesinde başa geçer.';

  @override
  String get gameInfoScoringGuesses =>
      'puan, süreye göre değil kaç denemede bildiğine göre verilir.';

  @override
  String get gameInfoSameForEveryone => 'bugün herkese aynı tahta geliyor.';

  @override
  String get gameInfoQueensGoal =>
      'her satıra, sütuna ve renge birer taç yerleştir.';

  @override
  String get gameInfoQueensRule1 =>
      'sekiz taç: her satırda bir, her sütunda bir.';

  @override
  String get gameInfoQueensRule2 =>
      'her renk bloğunda da tam olarak bir taç bulunur.';

  @override
  String get gameInfoQueensRule3 => 'iki taç birbirine değemez — köşeden bile.';

  @override
  String get gameInfoQueensControls =>
      'bir kareye bir kez dokun çarpı, tekrar dokun taç, bir daha dokun boş.';

  @override
  String get gameInfoTangoGoal => 'ızgarayı güneşler ve aylarla doldur.';

  @override
  String get gameInfoTangoRule1 =>
      'her satır ve sütunda üç güneş, üç ay bulunur.';

  @override
  String get gameInfoTangoRule2 =>
      'art arda üç aynı olamaz, ne yatay ne dikey.';

  @override
  String get gameInfoTangoRule3 =>
      'iki kare arasındaki = aynı, × farklı demektir.';

  @override
  String get gameInfoTangoControls =>
      'kareye dokun güneş, tekrar dokun ay, bir daha dokun boş. basılı kareler değişmez.';

  @override
  String get gameInfoZipGoal => 'her kareden geçen tek bir çizgi çiz.';

  @override
  String get gameInfoZipRule1 => '1\'den başla, son sayıda bitir.';

  @override
  String get gameInfoZipRule2 => 'yol boyunca sayılara sırayla uğra.';

  @override
  String get gameInfoZipRule3 => 'her kare tam olarak bir kez kullanılır.';

  @override
  String get gameInfoZipControls =>
      'parmağını sürükleyerek çiz. çizginin üstünden geri gel, silinsin.';

  @override
  String get gameInfoSudokuGoal => 'ızgarayı 1\'den 6\'ya rakamlarla doldur.';

  @override
  String get gameInfoSudokuRule1 => 'her satırda 1\'den 6\'ya birer kez.';

  @override
  String get gameInfoSudokuRule2 => 'her sütunda da aynısı.';

  @override
  String get gameInfoSudokuRule3 => 've her 2x3 kutuda da.';

  @override
  String get gameInfoSudokuControls =>
      'önce bir kareye, sonra bir rakama dokun. aynı rakama tekrar dokunursan silinir. notlar modunda küçük kurşun kalem işaretleri yazılır.';

  @override
  String get gameInfoCodeGoal => 'gizli dört sembollü şifreyi çöz.';

  @override
  String get gameInfoCodeRule1 =>
      'altı deneme, ve şifrede hiçbir sembol tekrarlanmaz.';

  @override
  String get gameInfoCodeRule2 => 'yeşil, doğru sembol doğru yerde demek.';

  @override
  String get gameInfoCodeRule3 => 'sarı, doğru sembol yanlış yerde demek.';

  @override
  String get gameInfoCodeControls =>
      'sembollere dokunarak bir tahmin kur ve gönder. tahta ne kadar yaklaştığını söyler.';

  @override
  String get savedMessagesTitle => 'Kaydedilmiş Mesajlar';

  @override
  String homeScreenNoSearchResults(Object query) {
    return '\"$query\" ile eşleşen sohbet yok';
  }

  @override
  String get pullRevealSearchHint => 'sohbet ara…';

  @override
  String get pullRevealCollapseSemanticLabel =>
      'Aramayı ve arşivlenmiş sohbetleri gizle';

  @override
  String archivedChatsFolderLabel(Object count) {
    return 'arşivlenen sohbetler ($count)';
  }

  @override
  String get archivedChatsFolderTitle => 'arşivlenen sohbetler';

  @override
  String get pullRevealClearSearchSemanticLabel => 'Aramayı temizle';

  @override
  String get archivedChatsSheetTitle => 'ARŞİVLENEN SOHBETLER';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'ARŞİVLENEN SOHBETLER · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'artık arşivlenen yok';

  @override
  String get pinnedBadgeLabel => 'SABİTLİ';

  @override
  String get chatRowActionMenuPinLabel => 'SOHBETİ SABİTLE';

  @override
  String get chatRowActionMenuUnpinLabel => 'SABİTLEMEYİ KALDIR';

  @override
  String get chatRowActionMenuArchiveLabel => 'SOHBETİ ARŞİVLE';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'ARŞİVDEN ÇIKAR';

  @override
  String get messageActionMenuSaveLabel => 'KAYDET';

  @override
  String get messageActionMenuUnsaveLabel => 'KAYDI KALDIR';

  @override
  String get roomScreenSaveLimitSnack =>
      'burada çok fazla kayıt var — önce birini kaldır';

  @override
  String get roomScreenSaveFailedSnack => 'kaydedilemedi';

  @override
  String get threadOverlaySaveLimitToast =>
      'burada çok fazla kayıt var — önce birini kaldır';

  @override
  String get threadOverlaySaveFailedToast => 'kaydedilemedi';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'kaydettiğin mesajları yalnızca sen görürsün — sabitlenen bir mesaj ise tam tersi: onu odadaki herkes görür.';

  @override
  String get roomInfoScreenOwnerBadgeNote =>
      'bir ismin yanındaki küçük madalya, bu odayı kimin oluşturduğunu gösterir.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return '$name tarafından gönderilen kaydedilen mesaja git';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return '$name tarafından gönderilen mesajın kaydını kaldır';
  }

  @override
  String get muteSheetTitle => 'SOHBETİ SESSİZE AL';

  @override
  String get muteSheetSubtitle =>
      'Neyin susacağını ve ne kadar süreyle susacağını seç.';

  @override
  String get muteSheetNotificationsTitle => 'Bildirimler';

  @override
  String get muteSheetNotificationsSub => 'Bildirim yok, ses yok';

  @override
  String get muteSheetBadgesTitle => 'Okunmamış sayıları';

  @override
  String get muteSheetBadgesSub =>
      'Sohbette sayı yok, uygulama simgesine hiçbir şey eklenmez';

  @override
  String get muteSheetDurationLabel => 'NE KADAR SÜREYLE';

  @override
  String get muteDurationHour => '1 saat';

  @override
  String get muteDurationEightHours => '8 saat';

  @override
  String get muteDurationWeek => '1 hafta';

  @override
  String get muteDurationAlways => 'Her zaman';

  @override
  String get muteSheetConfirmButton => 'SESSİZE AL';

  @override
  String get muteSheetSaveButton => 'KAYDET';

  @override
  String get muteSheetUnmuteButton => 'SESİ AÇ';

  @override
  String get muteSummaryAll =>
      'Bu sohbetten sana hiçbir şey ulaşmaz — ne bildirim ne de okunmamış sayısı.';

  @override
  String get muteSummaryNotificationsOnly =>
      'Bildirim yok. Okunmamış sayısı artmaya devam eder.';

  @override
  String get muteSummaryBadgesOnly =>
      'Okunmamış sayısı yok. Bildirimler gelmeye devam eder.';

  @override
  String get muteSummaryNothingPicked => 'Susturulacak en az bir şey seç.';

  @override
  String muteUntilSentence(String when) {
    return 'Bitiş: $when.';
  }

  @override
  String get muteUntilAlwaysSentence => 'Sen tekrar açana kadar.';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String get mutedBadgeLabel => 'SESSİZ';

  @override
  String get chatRowActionMenuMuteLabel => 'SOHBETİ SESSİZE AL';

  @override
  String get chatRowActionMenuUnmuteLabel => 'SOHBETİN SESİNİ AÇ';

  @override
  String get roomInfoScreenMuteLabel => 'SESSİZE ALMA';

  @override
  String get roomInfoScreenNotMutedRow => 'Sessize alınmadı';

  @override
  String get attachmentMenuLocationLabel => 'konum';

  @override
  String get locationSheetSendCurrent => 'Mevcut konumu gönder';

  @override
  String get locationSheetSendCurrentDetail => 'Şu anda bulunduğun yer';

  @override
  String get locationSheetLiveHeading => 'CANLI PAYLAŞ';

  @override
  String get locationSheetLiveDetail => 'Kendiliğinden durur';

  @override
  String get locationShareFor15Minutes => '15 dakika boyunca';

  @override
  String get locationShareFor1Hour => '1 saat boyunca';

  @override
  String get locationShareFor8Hours => '8 saat boyunca';

  @override
  String get locationBubbleOpenInMaps => 'Haritalarda aç';

  @override
  String get locationBubbleLiveBadge => 'CANLI';

  @override
  String get locationBubbleEndedBadge => 'BİTTİ';

  @override
  String locationBubbleLiveUntil(String time) {
    return '$time saatine kadar canlı';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return 'Canlı konum $time itibarıyla sona erdi';
  }

  @override
  String get locationBubbleNoRecentUpdate => 'Yakın zamanda güncelleme yok';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters m';
  }

  @override
  String get locationBubbleStopSharing => 'Paylaşımı durdur';

  @override
  String get locationBubbleUnavailable => 'Konum kullanılamıyor';

  @override
  String get locationBubbleNoMapsApp => 'Bunu açacak bir harita uygulaması yok';

  @override
  String get locationBubbleCoordinatesCopied => 'Koordinatlar kopyalandı';

  @override
  String get locationCouldNotGetFix => 'Konumun alınamadı';

  @override
  String get locationCouldNotStartLiveShare => 'Canlı paylaşım başlatılamadı';

  @override
  String get locationPermissionNeeded =>
      'Nerede olduğunu paylaşmak için konum erişimi gerekli';

  @override
  String get locationPermissionBlockedTitle => 'Konum erişimi kapalı';

  @override
  String get locationPermissionBlockedBody =>
      'MonkeyHub buradan tekrar soramaz. Ayarlar’dan MonkeyHub için konum erişimini aç.';

  @override
  String get locationServicesOffTitle => 'Konum servisleri kapalı';

  @override
  String get locationServicesOffBody =>
      'Bu cihazda konum kapalı. Nerede olduğunu paylaşmak için Ayarlar’dan aç.';

  @override
  String get locationOpenSettings => 'Ayarları aç';

  @override
  String get locationBackgroundSheetTitle => 'Telefonun yeniden başlarsa';

  @override
  String get locationBackgroundSheetBody =>
      'Canlı paylaşımın MonkeyHub’dan çıktığında zaten devam ediyor. Arka plan erişimi gerisini kapsıyor: yeniden başlatma, uygulamayı zorla kapatma, şarjı bitip geri gelen bir telefon.';

  @override
  String get locationBackgroundSheetKeepRunning => 'Kendiliğinden devam etsin';

  @override
  String get locationBackgroundSheetKeepRunningDetail =>
      'Telefonun izin isteyecek';

  @override
  String get locationBackgroundSheetAppOnly => 'Durmuş kalsın';

  @override
  String get locationBackgroundSheetAppOnlyDetail =>
      'İzin verilecek başka şey yok';

  @override
  String get locationServiceNotificationTitle => 'Canlı konumun paylaşılıyor';

  @override
  String get locationServiceNotificationBody =>
      'Sohbeti açmak için dokun, hemen bitirmek için Durdur’a bas';

  @override
  String get childPolicyScreenLocationLabel => 'Konum';

  @override
  String get childPolicyScreenLocationOnDesc =>
      'Nerede olduğunu paylaşabilir, 8 saate kadar canlı olarak da';

  @override
  String get childPolicyScreenLocationOffDesc => 'Nerede olduğunu paylaşamaz';

  @override
  String get roomInfoScreenSavedMessagesLabel => 'KAYDEDİLEN MESAJLAR';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      'bunları yalnızca sen görürsün ve yalnızca bu odadan. Kaydedilmiş Mesajlar sohbetin ayrıdır.';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      'henüz bir şey kaydedilmedi. bir mesaja basılı tutup KAYDET’i seç.';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return '$name tarafından gönderilen kaydedilen mesaja git';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return '$name tarafından gönderilen mesajın kaydını kaldır';
  }

  @override
  String get composerCaptureCameraModeLabel => 'kamera';

  @override
  String get composerCaptureVoiceModeLabel => 'sesli mesaj';

  @override
  String get composerCaptureVideoNoteModeLabel => 'video notu';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode. Modu değiştirmek için iki parmakla kaydırın veya ok tuşlarını kullanın.';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '$mode seçildi';
  }

  @override
  String get composerCaptureRecordingAnnouncement => 'Kayıt başladı';

  @override
  String get composerCaptureLockedAnnouncement =>
      'Kayıt kilitlendi. Eller serbest.';

  @override
  String get composerCaptureCancelledAnnouncement => 'Kayıt silindi';

  @override
  String get composerCaptureSentAnnouncement => 'Kayıt gönderildi';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return 'Kaydediliyor, $elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint =>
      'Kaydetmek için basılı tutun, değiştirmek için kaydırın';

  @override
  String get composerCaptureTapForCameraHint =>
      'Kamera için dokunun, değiştirmek için kaydırın';

  @override
  String get composerCaptureSlideToCancelHint => 'iptal için kaydır';

  @override
  String get composerCaptureReleaseToCancelHint => 'iptal için bırakın';

  @override
  String get composerCaptureTapToSendHint => 'göndermek için dokunun';

  @override
  String get composerCaptureSendingLabel => 'gönderiliyor…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return '$seconds sn kaldı';
  }

  @override
  String get composerCaptureCancelLabel => 'kaydı sil';

  @override
  String get composerCaptureSendLabel => 'kaydı gönder';

  @override
  String get composerCaptureLockLabel =>
      'kaydı kilitlemek için yukarı kaydırın';

  @override
  String get composerCaptureMicPermissionTitle => 'Mikrofon gerekli';

  @override
  String get composerCaptureMicPermissionBody =>
      'MonkeyHub, sesli mesaj kaydetmek için mikrofonunuza ihtiyaç duyuyor. Ayarlar\'dan açıp tekrar deneyin.';

  @override
  String get composerCaptureCameraPermissionTitle => 'Kamera gerekli';

  @override
  String get composerCaptureCameraPermissionBody =>
      'MonkeyHub, video notu kaydetmek için kameranıza ve mikrofonunuza ihtiyaç duyuyor. Ayarlar\'dan açıp tekrar deneyin.';

  @override
  String get composerCaptureRestrictedBody =>
      'Kayıt, bu cihazdaki bir kısıtlama nedeniyle kapalı.';

  @override
  String get composerCaptureOpenSettingsLabel => 'Ayarları Aç';

  @override
  String get composerCaptureUnavailableSnack =>
      'Bu cihazda kayıt kullanılamıyor.';

  @override
  String get composerCaptureInterruptedSnack => 'Kayıt durduruldu.';

  @override
  String get composerCaptureStorageSnack =>
      'Kayıt kaydedilemedi. Boş alanınızı kontrol edin.';

  @override
  String get videoNoteMessagePlayLabel => 'video notunu oynat';

  @override
  String get videoNoteMessagePauseLabel => 'video notunu duraklat';

  @override
  String get videoNoteMessageLoadingLabel => 'video notu yükleniyor';

  @override
  String get videoNoteMessageUnavailableLabel => 'video notu kullanılamıyor';

  @override
  String get videoNoteMessageRetryLabel => 'video notunu yeniden dene';

  @override
  String get videoNoteMessageRetryHint => 'yeniden denemek için dokunun';

  @override
  String get videoNoteMessageDiscardLabel => 'video notunu sil';

  @override
  String get attachmentMenuVideoNoteLabel => 'video notu';

  @override
  String get cameraScreenPhotoModeLabel => 'FOTOĞRAF';

  @override
  String get cameraScreenVideoModeLabel => 'VİDEO';

  @override
  String get cameraScreenStartRecordingLabel => 'kaydı başlat';

  @override
  String get cameraScreenStopRecordingLabel => 'kaydı durdur';

  @override
  String get cameraScreenVideoFailedSnack => 'Bu video kaydedilemedi.';

  @override
  String get scheduleSheetTitle => 'MESAJI ZAMANLA';

  @override
  String get scheduleSheetSubtitle =>
      'Şimdi yaz. Sen ne zaman dersen o zaman gitsin.';

  @override
  String get scheduleSheetWhenLabel => 'NE ZAMAN';

  @override
  String get schedulePresetInAnHour => '1 saat sonra';

  @override
  String get schedulePresetInEightHours => '8 saat sonra';

  @override
  String get schedulePresetTomorrowMorning => 'Yarın sabah';

  @override
  String get schedulePresetThisMorning => 'Bu sabah';

  @override
  String get schedulePresetInAWeek => '1 hafta sonra';

  @override
  String get scheduleSheetCustomChip => 'Tarih seç';

  @override
  String get scheduleSheetConfirmButton => 'ZAMANLA';

  @override
  String get scheduleSheetSaveButton => 'KAYDET';

  @override
  String scheduleSendsAtSentence(String when) {
    return '$when gönderilecek.';
  }

  @override
  String scheduleWhenToday(String time) {
    return 'bugün saat $time’te';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return 'yarın saat $time’te';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return '$date saat $time’te';
  }

  @override
  String get scheduleTimePickerTitle => 'TARİH VE SAAT SEÇ';

  @override
  String get scheduleTimePickerBack => 'Hızlı seçenekler';

  @override
  String get scheduleTimePickerToday => 'Bugün';

  @override
  String get scheduleTimePickerTomorrow => 'Yarın';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ZAMANLANMIŞ',
    );
    return '$_temp0';
  }

  @override
  String scheduledPillJoin(String label, String detail) {
    return '$label · $detail';
  }

  @override
  String scheduledPillSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gönderilmeyi bekleyen $count mesaj. Görmek için dokun.',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => 'SANA BAKIYOR';

  @override
  String get scheduledListTitle => 'ZAMANLANMIŞ';

  @override
  String get scheduledListSubtitle =>
      'Gönderilene kadar bunları yalnızca sen görürsün.';

  @override
  String get scheduledListEmpty => 'Burada gönderilmeyi bekleyen bir şey yok.';

  @override
  String get scheduledListSendNow => 'Şimdi gönder';

  @override
  String get scheduledListChangeTime => 'Saati değiştir';

  @override
  String get scheduledListEdit => 'Metni düzenle';

  @override
  String get scheduledListDelete => 'Sil';

  @override
  String get scheduledListSending => 'Gönderiliyor…';

  @override
  String get scheduledListFailedTitle => 'Gönderilemedi';

  @override
  String get scheduledListRetry => 'Tekrar dene';

  @override
  String get scheduleErrorOutOfRange =>
      'Şu andan itibaren iki dakika ile bir yıl arasında bir zaman seç.';

  @override
  String get scheduleErrorTooMany =>
      'Burada bekleyen çok fazla mesaj var. Önce birkaçını gönder ya da sil.';

  @override
  String get scheduleErrorNotInEphemeral =>
      'Buradaki mesajlar kendiliğinden siliniyor, bu yüzden zamanlanamaz.';

  @override
  String get scheduleErrorNotMember => 'Artık bu sohbette değilsin.';

  @override
  String get scheduleErrorBlocked => 'Önce engeli kaldırman gerekiyor.';

  @override
  String get scheduleErrorGeneric => 'Olmadı. Tekrar dene.';

  @override
  String get scheduleEditTitle => 'MESAJI DÜZENLE';

  @override
  String get composerScheduleAction => 'Bu mesajı zamanla';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Gönderilmeyi bekleyen $count mesaj',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => 'NASIL GÖSTERİLSİN';

  @override
  String get scheduledIndicatorPill => 'Şerit';

  @override
  String get scheduledIndicatorBadge => 'Rozet';

  @override
  String get scheduledIndicatorBoth => 'İkisi de';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zaten bekleyen $count mesaj',
      zero: 'Gönderilmeyi bekleyen bir şey yok',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => 'Nasıl görünsünler';

  @override
  String get scheduledIndicatorPillSub =>
      'Yazma kutusunun üstünde bir şerit. Görmek için dokun.';

  @override
  String get scheduledIndicatorBadgeSub =>
      'Gönder düğmesinde bir sayı. Yazmaya başlayana kadar hiçbir şey görünmez.';

  @override
  String get scheduledIndicatorBothSub => 'Şerit ve yazarken görünen sayı.';

  @override
  String get scheduledBack => 'Geri';

  @override
  String get serverScreenTitle => 'sunucu.';

  @override
  String get serverScreenSubtitle =>
      'hesabınızın ve mesajlarınızın durduğu yer';

  @override
  String get serverOnboardingTitle => 'bir sunucu seçin.';

  @override
  String get serverOnboardingSubtitle =>
      'bu sürüm sunucusuz geldi — kendi sunucunuzu gösterin';

  @override
  String get serverStatusConnected => 'BAĞLI';

  @override
  String get serverStatusDisconnected => 'BAĞLI DEĞİL';

  @override
  String get serverBadgeDefault => 'VARSAYILAN';

  @override
  String get serverBadgeSelfHosted => 'KENDİ SUNUCUNUZ';

  @override
  String get serverNoneConfigured => 'Henüz sunucu yok';

  @override
  String get serverActiveNowLabel => 'KULLANIMDA';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'Bu uygulamayla birlikte gelen sunucu.';

  @override
  String get serverChoiceOwn => 'Kendi sunucunuz';

  @override
  String get serverChoiceOwnSub => 'Kendi işlettiğiniz bir Convex arka ucu.';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => 'YAPIŞTIR';

  @override
  String get serverProblemMalformed => 'Bu bir web adresi değil.';

  @override
  String get serverProblemBadScheme => 'https:// veya http:// ile başlatın.';

  @override
  String get serverProblemNoHost =>
      'https:// sonrasına sunucunuzun adresini yazın.';

  @override
  String get serverProblemCredentials =>
      'Adresteki kullanıcı adı ve parolayı çıkarın.';

  @override
  String get serverInsecureTitle => 'ŞİFRELENMEMİŞ';

  @override
  String get serverInsecureBody =>
      'Telefonlar şifresiz http’yi engeller; bu adres iOS’ta da Android’de de bağlanmaz. https kullanın ya da sunucunuza bir tünel üzerinden ulaşın.';

  @override
  String get serverTestCta => 'BAĞLANTIYI SINA';

  @override
  String get serverTestingLabel => 'Sınanıyor…';

  @override
  String get serverCheckReachable => 'Bir yanıt geldi';

  @override
  String get serverCheckConvex => 'Bir Convex sunucusu';

  @override
  String get serverCheckApp => 'MonkeyHub çalışıyor';

  @override
  String get serverResultUnreachable => 'Bu adreste hiçbir yanıt yok.';

  @override
  String get serverResultNotConvex =>
      'Bir yanıt geldi ama bu bir Convex sunucusu değil.';

  @override
  String get serverResultNotThisApp =>
      'Bu bir Convex sunucusu ama üzerinde MonkeyHub yok.';

  @override
  String get serverResultServerError => 'Sunucu yanıt verdi ama hata döndürdü.';

  @override
  String get serverResultReady => 'Bağlanmaya hazır.';

  @override
  String get serverConnectCta => 'BAĞLAN';

  @override
  String get serverConnectAnywayCta => 'YİNE DE BAĞLAN';

  @override
  String get serverAlreadyConnectedCta => 'ZATEN BAĞLI';

  @override
  String get serverUseDefaultCta => 'VARSAYILAN SUNUCUYU KULLAN';

  @override
  String get serverChangeCta => 'SUNUCUYU DEĞİŞTİR';

  @override
  String get serverAdvancedLabel => 'GELİŞMİŞ';

  @override
  String get serverSiteUrlExplain =>
      'Çoğu sunucu her şeyi tek adresten yanıtlar. Bunu yalnızca sunucunuz HTTP eylemlerini başka bir adreste sunuyorsa doldurun.';

  @override
  String get serverSiteUrlHint => 'Yukarıdakiyle aynı';

  @override
  String get serverSectionRecent => 'SON KULLANILANLAR';

  @override
  String get serverRecentForget => 'Bu sunucuyu unut';

  @override
  String get serverSwitchWarningTitle => 'SUNUCU DEĞİŞTİRMEK OTURUMU KAPATIR';

  @override
  String get serverSwitchWarningBody =>
      'Hesaplar ve sohbetler tek bir sunucuya aittir. Bu cihaz oturumu kapatır, indirdiklerini siler ve sıfırdan başlar. İki sunucuda da hiçbir şey silinmez.';

  @override
  String get serverSwitchRolledBackTitle => 'BAĞLANILAMADI';

  @override
  String serverSwitchRolledBackBody(String host) {
    return '$host yanıt vermedi, bu yüzden hiçbir şey değişmedi. Yeniden giriş yapmanız gerekecek.';
  }

  @override
  String get serverSwitchStrandedBody =>
      'Hiçbir sunucuya bağlanılamadı. Adresi kontrol edip yeniden deneyin.';

  @override
  String get serverSwitchRefusedBody =>
      'Bu cihaz bir çocuk için ayarlanmış; sunucu değiştiremez.';

  @override
  String serverChipSemantics(String server) {
    return 'Sunucuyu değiştir. Şu an $server.';
  }

  @override
  String get serverValueDefault => 'Varsayılan';

  @override
  String get settingsScreenRowServer => 'SUNUCU';

  @override
  String get settingsScreenSectionAdvanced => 'GELİŞMİŞ';

  @override
  String get serverSwitchingLabel => 'Sunucu değiştiriliyor…';

  @override
  String get serverRoleExplainAction => 'Bu ne demek?';

  @override
  String get serverBadgeRibbonHomeserver => 'EV';

  @override
  String get serverBadgeRibbonSelfHosted => 'KENDİ';

  @override
  String get serverBadgeHomeserver => 'Şu an ev sunucusundan yayında';

  @override
  String get serverBadgeHomeserverSemantics =>
      'Şu an ev sunucusundan yayında. Ayrıntılar için dokunun.';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'Kendi sunucunuz: $server. Ayrıntılar için dokunun.';
  }

  @override
  String get serverRoleHomeserverTitle => 'Ev sunucusunda çalışıyor';

  @override
  String get serverRoleHomeserverBody =>
      'MonkeyHub’ı işletenler bir süreliğine trafiği evdeki sunucularına aldı. Her şey aynı şekilde çalışıyor; bu bilinçli bir tercih, arıza değil.';

  @override
  String get serverRoleHomeserverWarnData =>
      'Bu sürede gönderdikleriniz, trafik geri alındığında burada olmayabilir.';

  @override
  String get serverRoleHomeserverWarnSpeed =>
      'Ev bağlantısı her zamankinden yavaştır; takılmalar olabilir.';

  @override
  String get serverRoleHomeserverWarnAuto =>
      'Bir şey yapmanıza gerek yok; uygulama kendiliğinden geri döner.';

  @override
  String get serverRoleSelfHostedTitle => 'Kendi sunucunuz';

  @override
  String get serverRoleSelfHostedBody =>
      'Bu cihaz sizin işlettiğiniz bir sunucuya bağlı. Ayarlar › Gelişmiş › Sunucu bölümünden değiştirebilirsiniz.';

  @override
  String get serverValueHomeserver => 'Şimdilik ev sunucusu';

  @override
  String get serverChoiceCloudSubHomeserver =>
      'Bir süreliğine ev sunucusundan yayında.';

  @override
  String get serverDirectiveChangedToast =>
      'Sunucunuz değişti. Yeniden bağlanılıyor…';

  @override
  String get loginScreenSignInWithPhone => 'sign in with your phone';

  @override
  String get loginScreenUsePasswordInstead => 'use a password instead';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      'Open MonkeyHub on your phone, tap Scan to Sign In from your profile, and point the camera here — or type the code below.';

  @override
  String get deviceLoginScreenWaiting => 'waiting for approval…';

  @override
  String get deviceLoginScreenApproved => 'approved — signing you in…';

  @override
  String get deviceLoginScreenDenied => 'sign-in request denied on your phone';

  @override
  String get deviceLoginScreenGenericError =>
      'something went wrong — try a new code';

  @override
  String get profileScreenScanToSignInLabel => 'SCAN TO SIGN IN';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro =>
      'Point your camera at the code shown on your computer, or type it in below.';

  @override
  String get deviceLoginScanScreenScanButtonLabel => 'SCAN CODE';

  @override
  String get deviceLoginScanScreenConfirmTitle => 'sign in on this device?';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return '$deviceInfo wants to sign in as you. Only approve this if it’s you, right now.';
  }

  @override
  String get deviceLoginScanScreenApproveButton => 'APPROVE';

  @override
  String get deviceLoginScanScreenDenyButton => 'DENY';

  @override
  String get deviceLoginScanScreenSuccess => 'signed in on your other device';

  @override
  String get deviceLoginScanScreenGenericError =>
      'couldn’t approve — try again';

  @override
  String get authErrorDeviceLoginInvalid => 'That code isn’t right.';

  @override
  String get authErrorDeviceLoginExpired =>
      'That code has expired — get a new one on the other device.';

  @override
  String get deviceLoginScanScreenDeniedConfirmation =>
      'sign-in request denied';

  @override
  String get roomAdminRoleAdmin => 'YÖNETİCİ';

  @override
  String get roomAdminActionViewProfile => 'Profili gör';

  @override
  String get roomAdminActionPromote => 'Yönetici yap';

  @override
  String get roomAdminActionPromoteSub =>
      'Davet edebilir, üye çıkarabilir ve grubu düzenleyebilir';

  @override
  String get roomAdminActionDemote => 'Yöneticilikten al';

  @override
  String get roomAdminActionDemoteSub => 'Grupta üye olarak kalır';

  @override
  String get roomAdminActionTransfer => 'Sahipliği devret';

  @override
  String get roomAdminActionTransferSub => 'Sen yönetici olarak kalırsın';

  @override
  String get roomAdminActionRemove => 'Gruptan çıkar';

  @override
  String get roomAdminAddFriendsRow => 'Arkadaş ekle';

  @override
  String get roomAdminInviteLinkRow => 'Davet bağlantısı';

  @override
  String get roomAdminJoinRequestsRow => 'Katılma istekleri';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return 'Grup $name kişisine devredilsin mi?';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      'Sahip olur ve grubu silebilir. Sen yönetici olarak kalırsın, geri vermek yalnızca onun elinde olur.';

  @override
  String get roomAdminTransferConfirmCta => 'DEVRET';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return '$name çıkarılsın mı?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'Gruba ve içindeki her şeye erişimi biter. Yeniden davet edilebilir ya da davet bağlantısıyla geri gelebilir.';

  @override
  String get roomAdminRemoveConfirmCta => 'ÇIKAR';

  @override
  String get roomAdminGenericError => 'Bu işe yaramadı. Tekrar dene.';

  @override
  String get roomAdminErrorNotMember => 'Artık bu grupta değilsin.';

  @override
  String get roomAdminErrorNotAdmin => 'Bunu yalnızca yöneticiler yapabilir.';

  @override
  String get roomAdminErrorNotOwner => 'Bunu yalnızca grubun sahibi yapabilir.';

  @override
  String get roomAdminErrorNotGroup =>
      'Birebir sohbette yönetilecek bir şey yok.';

  @override
  String get roomAdminErrorOwnerImmutable =>
      'Sahibin rolü yalnızca grup devredilerek değişir.';

  @override
  String get roomAdminErrorInvitesLocked =>
      'Bu gruba yalnızca yöneticiler davet edebilir.';

  @override
  String get roomInviteSheetTitle => 'Davet bağlantısı';

  @override
  String get roomInviteSheetBlurb =>
      'Tek bir bağlantı ve tek bir kod; ikisi de aynı şey. Yenisini yaptığın anda eskisi çalışmayı bırakır.';

  @override
  String get roomInviteNoLinkYet => 'Bu grubun henüz davet bağlantısı yok.';

  @override
  String get roomInviteCreateButton => 'BAĞLANTI OLUŞTUR';

  @override
  String get roomInviteRegenerateButton => 'YENİ BAĞLANTI';

  @override
  String get roomInviteRevokeButton => 'BAĞLANTIYI İPTAL ET';

  @override
  String get roomInviteCopyLink => 'Bağlantıyı kopyala';

  @override
  String get roomInviteCopyCode => 'Kodu kopyala';

  @override
  String get roomInviteShare => 'Paylaş';

  @override
  String get roomInviteLinkCopied => 'Bağlantı kopyalandı.';

  @override
  String get roomInviteCodeCopied => 'Kod kopyalandı.';

  @override
  String get roomInviteRegenerateHeadline => 'Yeni bağlantı yapılsın mı?';

  @override
  String get roomInviteRegenerateBody =>
      'Şu anki bağlantı ve kod, paylaşıldıkları her yerde anında çalışmayı bırakır. Grupta olanlar grupta kalır.';

  @override
  String get roomInviteRegenerateConfirm => 'YENİ BAĞLANTI';

  @override
  String get roomInviteRevokeHeadline => 'Bu bağlantı iptal edilsin mi?';

  @override
  String get roomInviteRevokeBody =>
      'Yenisini yapana kadar kimse bağlantıyla katılamaz. Grupta olanlar grupta kalır.';

  @override
  String get roomInviteRevokeConfirm => 'İPTAL ET';

  @override
  String get roomInviteLimitsLabel => 'SINIRLAR';

  @override
  String get roomInviteExpiryLabel => 'Geçerlilik süresi';

  @override
  String get roomInviteMaxUsesLabel => 'Kullanım sayısı';

  @override
  String get roomInviteNeverExpires => 'Süresiz';

  @override
  String get roomInviteUnlimited => 'Sınırsız';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count sa';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count gün';
  }

  @override
  String get roomInviteLimitsApplyToNew =>
      'Bunlar oluşturacağın bağlantı için geçerli.';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      'Bunlar bir sonraki bağlantı için geçerli. Yukarıdaki, oluşturulduğu sınırlarla kalır.';

  @override
  String get roomInvitePermissionsLabel => 'İZİNLER';

  @override
  String get roomInviteMembersCanInviteLabel => 'Üyeler arkadaş davet edebilir';

  @override
  String get roomInviteMembersCanInviteSub =>
      'Kapatırsan insanları yalnızca yöneticiler alabilir';

  @override
  String get roomInviteApprovalLabel => 'Her katılımı onayla';

  @override
  String get roomInviteApprovalSub =>
      'Bağlantısı olanlar önce sorar, bir yönetici evet ya da hayır der';

  @override
  String roomInviteUsesCount(Object count) {
    return '$count kez kullanıldı';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$max kullanımdan $used tanesi';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return 'bitiş $date';
  }

  @override
  String get roomInviteDeadExpired =>
      'Bu bağlantının süresi doldu. Yenisini yap.';

  @override
  String get roomInviteDeadExhausted =>
      'Bu bağlantının kullanım hakkı bitti. Yenisini yap.';

  @override
  String get roomInviteDeadRevoked => 'Bu bağlantı iptal edildi.';

  @override
  String get roomInviteDeadGeneric => 'Bu bağlantı artık çalışmıyor.';

  @override
  String get roomInviteFriendsTitle => 'Arkadaş ekle';

  @override
  String get roomInviteFriendsBlurb =>
      'Bir davet alacaklar; kabul ya da reddedebilirler.';

  @override
  String get roomInviteFriendsSearchHint => 'Arkadaşlarda ara';

  @override
  String get roomInviteFriendsInviteButton => 'DAVET ET';

  @override
  String get roomInviteFriendsSent => 'Davet edildi';

  @override
  String get roomInviteFriendsEmpty =>
      'Arkadaşlarının hepsi ya burada ya da çoktan davet edildi.';

  @override
  String get roomInviteFriendsNoMatch => 'Buna uyan arkadaş yok.';

  @override
  String get roomInviteFriendsDone => 'TAMAM';

  @override
  String get roomJoinRequestsTitle => 'Katılma istekleri';

  @override
  String get roomJoinRequestsBlurb =>
      'Bu kişiler davet bağlantısını kullandı. Sen evet demeden grupta hiçbir şey göremezler.';

  @override
  String get roomJoinRequestsEmpty => 'Bekleyen kimse yok.';

  @override
  String get roomJoinRequestsApprove => 'AL';

  @override
  String get roomJoinRequestsReject => 'ALMA';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return 'DAVET EDİLDİ · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian => 'ebeveyn bekleniyor';

  @override
  String get roomInfoScreenInviteWithdraw => 'GERİ AL';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return '$inviter davet etti · $members üye';
  }

  @override
  String get roomInvitationCardJoin => 'KATIL';

  @override
  String get discoverScreenJoinByCodeTitle => 'kodla katıl';

  @override
  String get discoverScreenJoinByCodeSubtitle => 'birinin paylaştığı grubu aç';

  @override
  String get joinInviteTitle => 'Bir gruba katıl';

  @override
  String get joinInviteBack => 'Geri';

  @override
  String get joinInviteCodeBlurb =>
      'Birinin seninle paylaştığı kodu gir. Davet bağlantısının tamamı da burada çalışır.';

  @override
  String get joinInviteCodeLabel => 'Davet kodu';

  @override
  String get joinInviteCodeHint => 'Bağlantıyı yapıştır ya da kodu yaz';

  @override
  String get joinInviteCodeInvalid => 'Bu bir davet koduna benzemiyor.';

  @override
  String get joinInviteLookupButton => 'DEVAM';

  @override
  String get joinInviteLookupFailed =>
      'Kod kontrol edilemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count üye';
  }

  @override
  String get joinInviteJoinButton => 'GRUBA KATIL';

  @override
  String get joinInviteRequestButton => 'KATILMAK İSTE';

  @override
  String get joinInviteOpenNote =>
      'Katıldığında grubun mesajlarını görebileceksin.';

  @override
  String get joinInviteApprovalNote =>
      'Buradaki hiçbir şeyi görebilmen için önce bir yöneticinin evet demesi gerekiyor.';

  @override
  String get joinInviteOpenRoom => 'GRUBU AÇ';

  @override
  String get joinInvitePendingHeadline => 'Yönetici bekleniyor';

  @override
  String get joinInvitePendingBody =>
      'Biri yanıtlar yanıtlamaz bildirim alacaksın.';

  @override
  String get joinInviteBadLinkHeadline => 'Bu davet çalışmıyor';

  @override
  String get joinInviteBadLinkBody =>
      'Kodu kontrol et ya da yeni bir bağlantı iste.';

  @override
  String get joinInviteExpiredHeadline => 'Bu davetin süresi doldu';

  @override
  String get joinInviteExpiredBody =>
      'Seni davet edenden yeni bir bağlantı iste.';

  @override
  String get joinInviteExhaustedHeadline => 'Bu davet tükendi';

  @override
  String get joinInviteExhaustedBody =>
      'Sınırlı sayıda çalışacak şekilde ayarlanmıştı. Yenisini iste.';

  @override
  String get joinInviteRevokedHeadline => 'Bu davetin yerine yenisi geldi';

  @override
  String get joinInviteRevokedBody =>
      'Bir yönetici yeni bağlantı yaptı. Güncel olanı ondan iste.';

  @override
  String get joinInviteWrongServerHeadline => 'Bu davet başka bir sunucu için';

  @override
  String joinInviteWrongServerBody(Object host) {
    return '$host sunucusuna ait. Hesabın farklı bir sunucuda olduğu için bu gruba buradan ulaşılamaz.';
  }

  @override
  String get roomInviteErrorNotFound =>
      'Bu davet kodu hiçbir şeyle eşleşmiyor.';

  @override
  String get roomInviteErrorRevoked =>
      'Bu davetin yerine yenisi geldi. Güncel bağlantıyı iste.';

  @override
  String get roomInviteErrorExpired => 'Bu davetin süresi doldu.';

  @override
  String get roomInviteErrorExhausted => 'Bu davet tükendi.';

  @override
  String get roomInviteErrorAlreadyMember => 'Bu kişi zaten grupta.';

  @override
  String get roomInviteErrorAlreadyInvited => 'Bu kişi zaten davet edildi.';

  @override
  String get roomInviteErrorSelf => 'Zaten bu gruptasın.';

  @override
  String get roomInviteErrorInvitationGone => 'Bu davet artık orada değil.';

  @override
  String get roomInviteErrorRequestPending =>
      'Katılmayı zaten istedin. Bir yönetici yanıtlayacak.';

  @override
  String get roomInviteErrorRequestGone =>
      'Bu isteği başka biri çoktan yanıtladı.';

  @override
  String get roomInviteErrorRoomPrivate =>
      'Bu gruba yalnızca davetle katılınabilir.';

  @override
  String get roomInviteErrorInvalidLimits => 'Bu sınırlar geçerli değil.';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$child, $other kişisini $room grubuna davet etmek istiyor';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$other, $child çocuğunu $room grubuna davet etti';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      'Davet gönderilir, kararı yine karşı taraf verir.';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$child daveti görür ve kabul ya da reddedebilir. Onaylaman, kabul ederse o gruba girmesine de izin verir.';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      'Kendini çıkaramazsın. Bunun yerine gruptan ayrıl.';

  @override
  String get roomAdminActionMessage => 'Mesaj gönder';

  @override
  String get roomAdminActionVoiceCall => 'Sesli ara';

  @override
  String get roomAdminActionVideoCall => 'Görüntülü ara';

  @override
  String get roomAdminYouSuffix => 'sen';

  @override
  String get roomInfoScreenSetPasswordButton => 'AYARLA';

  @override
  String get roomInfoScreenPasswordSetSnackbar => 'Şifre ayarlandı.';

  @override
  String get roomInfoScreenPasswordSetState => 'Şifre açık';

  @override
  String get roomInfoScreenPasswordUnsetState => 'Şifre yok';

  @override
  String get roomInfoScreenPasswordCancel => 'Vazgeç';

  @override
  String get roomInfoScreenEditSave => 'Kaydet';

  @override
  String get roomInfoScreenEditCancel => 'Vazgeç';

  @override
  String get roomInviteRotatedToast =>
      'Yeni bağlantı oluşturuldu. Eskisi artık çalışmıyor.';

  @override
  String get roomInviteRevokedToast => 'Davet bağlantısı iptal edildi.';

  @override
  String get newChatMenuTitle => 'Yeni sohbet';

  @override
  String get newChatMenuCreateTitle => 'Oda oluştur';

  @override
  String get newChatMenuCreateSub => 'Bir grup başlat ve insanları davet et';

  @override
  String get newChatMenuJoinTitle => 'Kodla katıl';

  @override
  String get newChatMenuJoinSub => 'Birinin seninle paylaştığı grubu aç';

  @override
  String get shareSheetTitle => 'ŞUNA GÖNDER';

  @override
  String get shareSheetSuggestedHeading => 'ÖNERİLEN';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ek',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dosya $size sınırını aştığı için alınmadı',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return '$title kişisine gönder';
  }

  @override
  String get settingsScreenRowSpeakerColors => 'KİŞİ RENKLERİ';

  @override
  String get settingsScreenValueSpeakerOff => 'Kapalı';

  @override
  String get settingsScreenValueSpeakerName => 'İsimler';

  @override
  String get settingsScreenValueSpeakerBubble => 'İsimler + baloncuklar';

  @override
  String get speakerColorScreenTitle => 'kişi renkleri.';

  @override
  String get speakerColorScreenSubtitle => 'ismi okumadan kimin yazdığını gör';

  @override
  String get speakerColorScreenOffLabel => 'KAPALI';

  @override
  String get speakerColorScreenOffDescription =>
      'odadaki herkes aynı mürekkeple yazar.';

  @override
  String get speakerColorScreenNameLabel => 'İSİMLER';

  @override
  String get speakerColorScreenNameDescription =>
      'herkesin kendine ait bir rengi olur; isminde ve avatarının çevresinde.';

  @override
  String get speakerColorScreenBubbleLabel => 'BALONCUKLAR';

  @override
  String get speakerColorScreenBubbleDescription =>
      'renk mesajlara da geçer; art arda beş mesaj bile kimin yazdığını söyler.';

  @override
  String get roomInfoScreenSpeakerColorsLabel => 'RENKLER';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => 'Otomatik';

  @override
  String get roomInfoScreenSpeakerColorsCustom => 'Özel';

  @override
  String get roomColorsScreenTitle => 'kim kim.';

  @override
  String get roomColorsScreenSubtitle => 'herkesin konuştuğu renk';

  @override
  String get roomColorsScreenOffTitle => 'kişi renkleri kapalı';

  @override
  String get roomColorsScreenOffBody =>
      'şu anda herkes aynı mürekkeple yazıyor. aç, buradaki herkes kendi rengini alsın.';

  @override
  String get roomColorsScreenOffAction => 'AÇ';

  @override
  String get roomColorsScreenOffHint =>
      'sadece bu oda için değil, tüm odalar için geçerli. ayarlarda da var.';

  @override
  String get roomColorsScreenAutoChip => 'OTOMATİK';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return '$name ile aynı';
  }

  @override
  String get roomColorsScreenResetAll => 'OTOMATİĞE DÖN';

  @override
  String get roomColorsScreenLimitToast =>
      'Bir odada sabitlenebilecek renk sayısı bu kadar.';

  @override
  String get roomColorsScreenFailedToast => 'Renk kaydedilemedi.';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return 'Renk $index';
  }

  @override
  String get devicesScreenTitle => 'CİHAZLARIN';

  @override
  String get devicesScreenSubtitle => 'Bu hesaba giriş yaptığın her yer.';

  @override
  String get devicesScreenLoading => 'kontrol ediliyor…';

  @override
  String get devicesScreenLoadFailed => 'cihazların yüklenemedi';

  @override
  String get devicesScreenThisDevice => 'BU CİHAZ';

  @override
  String get devicesScreenActiveNow => 'şu an aktif';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dakika önce',
      one: '1 dakika önce',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saat önce',
      one: '1 saat önce',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün önce',
      one: '1 gün önce',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications => 'bildirimler buraya ulaşmıyor';

  @override
  String get devicesScreenRemove => 'KALDIR';

  @override
  String get devicesScreenRemoveTitle => 'BU CİHAZ KALDIRILSIN MI?';

  @override
  String devicesScreenRemoveBody(Object name) {
    return '$name oturumu kapatılacak ve bildirim almayı bırakacak. Cihazı kim kullanıyorsa yeniden giriş yapmak zorunda kalacak.';
  }

  @override
  String get devicesScreenRemoveConfirm => 'KALDIR';

  @override
  String get devicesScreenRemoveAll => 'Diğer tüm cihazları kaldır';

  @override
  String get devicesScreenRemoveAllTitle =>
      'DİĞER TÜM CİHAZLAR KALDIRILSIN MI?';

  @override
  String get devicesScreenRemoveAllBody =>
      'Hepsinin oturumu kapatılacak ve bildirim almayı bırakacaklar. Yalnızca bu cihaz açık kalacak.';

  @override
  String get devicesScreenRemoveAllConfirm => 'TÜMÜNÜ KALDIR';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cihaz kaldırıldı',
      one: '1 cihaz kaldırıldı',
      zero: 'kaldırılacak başka cihaz yok',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed => 'cihaz kaldırılamadı';

  @override
  String get devicesScreenFootnote =>
      'Bir cihazı kaldırmak oturumunu kapatır ve bildirimlerini durdurur. Anında geçerli olur — o cihaz bir şey yapmaya kalktığı anda giriş ekranına döner.';

  @override
  String get attachmentMenuPollLabel => 'anket';

  @override
  String get attachmentMenuChecklistLabel => 'liste';

  @override
  String get attachmentMenuEventLabel => 'etkinlik';

  @override
  String get interactionKindPoll => 'ANKET';

  @override
  String get interactionKindQuiz => 'TEST';

  @override
  String get interactionKindChecklist => 'LİSTE';

  @override
  String get interactionKindEvent => 'ETKİNLİK';

  @override
  String get interactionBadgeAnonymous => 'GİZLİ';

  @override
  String get interactionBadgeMultiple => 'ÇOKLU';

  @override
  String get interactionBadgeClosed => 'KAPANDI';

  @override
  String interactionPercent(int percent) {
    return '%$percent';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names +$count';
  }

  @override
  String get interactionSeeWhoAnswered => 'Kimler yanıtladı';

  @override
  String interactionRemoveItem(String label) {
    return '$label kaldır';
  }

  @override
  String interactionChoiceSemantics(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oy',
    );
    return '$label, $_temp0';
  }

  @override
  String get interactionAddItemHint => 'Bir madde ekle';

  @override
  String get interactionRetract => 'Geri al';

  @override
  String get interactionClose => 'Kapat';

  @override
  String interactionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oy',
    );
    return '$_temp0';
  }

  @override
  String interactionRsvpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yanıt',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$done/$total bitti';
  }

  @override
  String get interactionNoAnswers => 'Yanıt yok';

  @override
  String get interactionBeFirst => 'İlk yanıtlayan sen ol';

  @override
  String interactionFinalResults(String count) {
    return '$count · kesin';
  }

  @override
  String get interactionQuizRight => 'Doğru';

  @override
  String get interactionQuizWrong => 'Az kaldı';

  @override
  String interactionEventPast(String when) {
    return '$when · çoktan oldu';
  }

  @override
  String get interactionRespondentsTitlePoll => 'KİMLER OY VERDİ';

  @override
  String get interactionRespondentsTitleChecklist => 'KİMLER İŞARETLEDİ';

  @override
  String get interactionRespondentsTitleEvent => 'KİMLER YANITLADI';

  @override
  String get interactionRespondentsFailed =>
      'Kimlerin yanıtladığı yüklenemedi.';

  @override
  String get interactionRespondentsEmpty => 'Henüz kimse yanıtlamadı.';

  @override
  String get interactionFilterAll => 'TÜMÜ';

  @override
  String get interactionRsvpGoing => 'Geliyorum';

  @override
  String get interactionRsvpMaybe => 'Belki';

  @override
  String get interactionRsvpNo => 'Gelemem';

  @override
  String get interactionComposePollTitle => 'yeni anket';

  @override
  String get interactionComposePollTagline => 'ODAYA SOR';

  @override
  String get interactionComposeChecklistTitle => 'yeni liste';

  @override
  String get interactionComposeChecklistTagline =>
      'HERKESİN İŞARETLEDİĞİ LİSTE';

  @override
  String get interactionComposeEventTitle => 'yeni etkinlik';

  @override
  String get interactionComposeEventTagline => 'KİMLER GELİYOR GÖR';

  @override
  String get interactionComposeQuestionLabel => 'SORU';

  @override
  String get interactionComposeQuestionHint => 'ne soruyorsun?';

  @override
  String get interactionComposeTitleLabel => 'BAŞLIK';

  @override
  String get interactionComposeTitleHint => 'bu liste ne için?';

  @override
  String get interactionComposeEventNameLabel => 'ETKİNLİK';

  @override
  String get interactionComposeEventNameHint => 'ne oluyor?';

  @override
  String get interactionComposeOptionsLabel => 'SEÇENEKLER';

  @override
  String get interactionComposeItemsLabel => 'MADDELER';

  @override
  String interactionComposeOptionHint(int index) {
    return '$index. seçenek';
  }

  @override
  String interactionComposeItemHint(int index) {
    return '$index. madde';
  }

  @override
  String get interactionComposeAddOption => 'Seçenek ekle';

  @override
  String get interactionComposeAddItem => 'Madde ekle';

  @override
  String get interactionComposeRemoveRow => 'Kaldır';

  @override
  String get interactionComposeMarkCorrect => 'Doğru yanıt olarak işaretle';

  @override
  String get interactionComposeMultipleTitle => 'çoklu yanıt';

  @override
  String get interactionComposeMultipleSub => 'birden fazla seçilebilir';

  @override
  String get interactionComposeAnonymousTitle => 'gizli';

  @override
  String get interactionComposeAnonymousOffSub =>
      'kimin oy verdiğini herkes görür';

  @override
  String get interactionComposeAnonymousOnSub =>
      'kimin oy verdiğini kimse görmez';

  @override
  String get interactionComposeQuizTitle => 'test modu';

  @override
  String get interactionComposeQuizSub => 'tek doğru yanıt, değiştirmek yok';

  @override
  String get interactionComposeExplanationLabel => 'AÇIKLAMA';

  @override
  String get interactionComposeExplanationHint =>
      'yanıtladıktan sonra görünür (isteğe bağlı)';

  @override
  String get interactionComposeOthersMayCheckTitle => 'herkes işaretleyebilir';

  @override
  String get interactionComposeOthersMayCheckSub => 'sadece sen değil';

  @override
  String get interactionComposeOthersMayAddTitle => 'herkes ekleyebilir';

  @override
  String get interactionComposeOthersMayAddSub => 'liste sonradan uzayabilir';

  @override
  String get interactionComposeWhenLabel => 'NE ZAMAN';

  @override
  String get interactionComposePickStart => 'Başlangıcı seç';

  @override
  String get interactionComposePickEnd => 'Bitiş ekle (isteğe bağlı)';

  @override
  String get interactionComposePlaceLabel => 'YER';

  @override
  String get interactionComposePlaceHint => 'nerede? (isteğe bağlı)';

  @override
  String get interactionComposeSendPoll => 'ANKETİ GÖNDER';

  @override
  String get interactionComposeSendChecklist => 'LİSTEYİ GÖNDER';

  @override
  String get interactionComposeSendEvent => 'ETKİNLİĞİ GÖNDER';

  @override
  String get interactionComposeErrorPrompt => 'Önce ne sorduğunu yaz.';

  @override
  String interactionComposeErrorOptions(int count) {
    return 'Bir ankette en az $count seçenek olmalı.';
  }

  @override
  String get interactionComposeErrorItems =>
      'Bir listede en az bir madde olmalı.';

  @override
  String get interactionComposeErrorAnswer =>
      'Hangi seçeneğin doğru olduğunu işaretle.';

  @override
  String get interactionComposeErrorWhen => 'Ne zaman başladığını seç.';

  @override
  String get interactionComposeErrorEnd => 'Bitiş, başlangıçtan sonra olmalı.';

  @override
  String get interactionSendFailed => 'Gönderilemedi.';

  @override
  String get interactionRefused => 'İşlenemedi.';

  @override
  String get messageReceiptsScreenTitle => 'MESAJ BİLGİSİ';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$total kişiden $read kişi okudu';
  }

  @override
  String get messageReceiptsEmptyState => 'bu odada henüz başka kimse yok';

  @override
  String get messageReceiptsSectionRead => 'OKUNDU';

  @override
  String get messageReceiptsSectionDelivered => 'İLETİLDİ';

  @override
  String get messageReceiptsSectionSent => 'GÖNDERİLDİ';

  @override
  String get messageReceiptsSectionHidden => 'BİLGİ YOK';

  @override
  String get messageReceiptsStateHidden => 'paylaşılmıyor';

  @override
  String get messageReceiptsStateWaiting => 'bekliyor';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name bunu $day saat $time itibarıyla okudu';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name bunu $day saat $time itibarıyla aldı';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name bunu henüz almadı';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name okundu bilgisi paylaşmıyor';
  }

  @override
  String get companionsScreenTitle => 'yardımcılar.';

  @override
  String get companionsScreenSubtitle =>
      'bu telefonda yaşayan, hiçbir yere veri göndermeyen yardımcılar';

  @override
  String get companionSebastianTagline => 'Mesajları çevirir';

  @override
  String get companionSebastianBlurb =>
      'Sebastian başka bir dilde yazılmış mesajı okur ve ne dediğini sana söyler — hem de burada, telefonunda; hiçbir şey hiçbir yere gönderilmeden.';

  @override
  String get companionMarloweTagline => 'Genel yardım';

  @override
  String get companionMarloweBlurb =>
      'Marlowe, çeviri dışındaki her şeyle ilgilenir. Şimdi bir beyin seç, yetenekler de onun etrafında gelsin.';

  @override
  String get companionAssuranceOnDevice => 'Tamamen bu cihazda çalışır';

  @override
  String get companionAssurancePrivate => 'Mesajların telefonundan hiç çıkmaz';

  @override
  String get companionAssuranceOffline => 'İnternet olmadan da çalışır';

  @override
  String companionInstallAction(Object size) {
    return 'Kur · $size';
  }

  @override
  String get companionInstallOneTime =>
      'tek seferlik indirme, sen kaldırana kadar durur';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$received / $total';
  }

  @override
  String get companionInstallQueued => 'Diğer indirmenin bitmesi bekleniyor';

  @override
  String get companionInstallCancel => 'Vazgeç';

  @override
  String get companionInstallRetry => 'Tekrar dene';

  @override
  String companionInstallReady(Object name) {
    return '$name hazır';
  }

  @override
  String get companionInstallFailedNetwork =>
      'İndirme tamamlanamadı. Bağlantını kontrol edip tekrar dene.';

  @override
  String get companionInstallFailedStorage =>
      'Bu cihazda yeterli alan yok. Biraz yer açıp tekrar dene.';

  @override
  String get companionInstallFailedUnknown => 'İndirme tamamlanamadı.';

  @override
  String get companionUnsupportedPlatform =>
      'Yardımcılar uygulamanın bu sürümünde henüz kullanılamıyor.';

  @override
  String companionBrainNeedsMemory(String size) {
    return '$size bellek gerekiyor';
  }

  @override
  String get sebastianTierSeniorDetail => 'Daha iyi çeviriler';

  @override
  String get sebastianTierJuniorDetail => 'Her telefonda çalışır';

  @override
  String get sebastianLanguageUnlisted =>
      'Onun dillerinden biri değil — sonuç kaba olabilir';

  @override
  String get companionStatusNotInstalled => 'Kurulu değil';

  @override
  String get companionStatusOff => 'Kapalı';

  @override
  String companionStatusTranslatingInto(Object language) {
    return '$language diline çeviriyor';
  }

  @override
  String get companionStatusNoBrain => 'Henüz bir şey indirilmedi';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count indirme hazır',
      one: '1 indirme hazır',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty =>
      'Hiçbir şey indirilmedi — yardımcılar yer kaplamıyor';

  @override
  String companionStorageUsed(Object size) {
    return 'Yardımcılar $size yer kaplıyor';
  }

  @override
  String get companionSectionGeneral => 'GENEL';

  @override
  String get companionSectionStorage => 'DEPOLAMA';

  @override
  String get companionBrainRemove => 'Kaldır';

  @override
  String companionBrainRemoveTitle(Object name) {
    return '$name KALDIRILSIN MI?';
  }

  @override
  String companionRemoveTitle(Object name) {
    return '$name KALDIRILSIN MI?';
  }

  @override
  String companionRemoveMessage(Object size) {
    return 'Bu $size yer açar. İstediğin zaman yeniden indirebilirsin.';
  }

  @override
  String get companionRemoveConfirm => 'KALDIR';

  @override
  String get sebastianEnableLabel => 'Sebastian çeviri yapsın';

  @override
  String get sebastianEnableDetail => 'İndirmeyi silmeden durdurmak için kapat';

  @override
  String get sebastianLanguageSection => 'ŞU DİLE ÇEVİR';

  @override
  String get sebastianLanguageFollowApp => 'Uygulamayla aynı';

  @override
  String sebastianBrainDetail(Object size) {
    return 'Bu cihazda · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count çeviri saklanıyor',
      one: '1 çeviri saklanıyor',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => 'Temizle';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe henüz bir şey yapamıyor — yetenekler hâlâ yolda. Şimdi yapabileceğin şey bir beyin hazırlamak; böylece yetenekler geldiğinde indirme beklenmiyor olur.';

  @override
  String get marloweBrainsSection => 'BEYİN';

  @override
  String get marloweBrainsCaption =>
      'Büyüğü daha iyi düşünür, daha yavaş cevap verir. Birden fazlasını tutup aralarında geçiş yapabilirsin.';

  @override
  String get marloweBrainTierSwift => 'Hızlı';

  @override
  String get marloweBrainTierBalanced => 'Dengeli';

  @override
  String get marloweBrainTierDeep => 'Derin';

  @override
  String get translationSlabShowOriginal => 'Orijinali göster';

  @override
  String get translationSlabFailed => 'Bu mesaj çevrilemedi.';

  @override
  String get translationSlabRetry => 'Tekrar dene';

  @override
  String translationSlabByCompanion(Object name) {
    return '$name çevirdi';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return '$language dilinden';
  }

  @override
  String get messageActionMenuTranslateLabel => 'ÇEVİR';

  @override
  String get messageActionMenuShowOriginalLabel => 'ORİJİNALİ GÖSTER';

  @override
  String get roomTranslateTitle => 'Bu sohbeti çevir';

  @override
  String get roomTranslateStopTitle => 'Çeviriyi durdur';

  @override
  String get roomTranslateSectionLabel => 'ÇEVİRİ';

  @override
  String get roomTranslateOnRow => 'Bu sohbet çevriliyor';

  @override
  String get roomTranslateOffRow => 'Kapalı';

  @override
  String get roomTranslateNeedsSetUp => 'Sebastian\'ı kur';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'Sebastian çeviriyor · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return '$language dilinde okunuyor';
  }

  @override
  String get roomTranslateStop => 'DURDUR';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return 'zaten $language dilinde';
  }

  @override
  String get roomScreenTranslateRoomOffer =>
      'sohbetin geri kalanı da çevrilsin mi?';

  @override
  String get roomScreenTranslateRoomOfferAction => 'HEPSİNİ ÇEVİR';

  @override
  String get settingsScreenCompanionsOff => 'Kapalı';

  @override
  String get settingsScreenCompanionsUnavailable => 'Kullanılamıyor';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return '$name da kullanıyor';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return '$name da aynı indirmeyi kullanıyor ve onu kaybedecek.';
  }

  @override
  String get companionBrainInUse => 'KULLANIMDA';

  @override
  String companionStatusUsingBrain(Object name) {
    return '$name kullanılıyor';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name indirilmeye devam ediyor — Ayarlar › Yardımcılar';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return 'İndiriliyor · %$percent';
  }

  @override
  String get companionInstallPause => 'Duraklat';

  @override
  String get companionInstallResume => 'Devam et';

  @override
  String get companionInstallDiscard => 'Sil';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return 'Duraklatıldı · $total / $received';
  }

  @override
  String get companionInstallFailedIntegrity =>
      'İndirilen dosya bu sürümün beklediğiyle eşleşmedi. Baştan başlanıyor.';

  @override
  String companionBannerDownloading(
    Object name,
    Object received,
    Object total,
  ) {
    return '$name · $total / $received';
  }

  @override
  String companionBannerPaused(Object name, Object received, Object total) {
    return '$name duraklatıldı · $total / $received';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name uyanıyor…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => 'YENİDEN ÇEVİR';

  @override
  String get groupCallScreenShareLabel => 'paylaş';

  @override
  String get groupCallScreenStopShareLabel => 'paylaşımı durdur';

  @override
  String get groupCallScreenShareStartingLabel => 'başlıyor…';

  @override
  String get groupCallScreenRingingLabel => 'Çalıyor…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name ekranını paylaşıyor';
  }

  @override
  String get groupCallScreenYouAreSharing => 'Ekranını paylaşıyorsun';

  @override
  String get groupCallScreenMinimizeLabel => 'gizle';

  @override
  String get groupCallScreenDrawLabel => 'çiz';

  @override
  String get callScreenControlShare => 'Paylaş';

  @override
  String get callScreenControlStopShare => 'Durdur';

  @override
  String get callScreenControlShareStarting => 'Başlıyor…';

  @override
  String get screenShareStopDrawing => 'Çizimi bitir';

  @override
  String get callScreenControlDraw => 'Çiz';

  @override
  String get callScreenControlMinimize => 'Gizle';

  @override
  String get inCallPillOngoingCall => 'Arama sürüyor';

  @override
  String get inCallPillReturn => 'Geri dön';

  @override
  String get inCallPillSharing => 'Ekranını paylaşıyorsun';

  @override
  String get inCallPillDrawSemanticLabel => 'Paylaşılan ekrana çiz';

  @override
  String get inCallPillStopSharingSemanticLabel => 'Paylaşımı durdur';

  @override
  String get screenShareUnsupported =>
      'Bu cihazda ekran paylaşımı kullanılamıyor';

  @override
  String get screenShareEphemeralWarning =>
      'Paylaşırken yakalama koruması kapalı';

  @override
  String get screenShareNotificationTitle => 'Ekranını paylaşıyorsun';

  @override
  String get screenShareNotificationBody => 'Aramadaki herkes görebilir';

  @override
  String get screenShareNotificationStop => 'Durdur';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name zaten paylaşıyor';
  }

  @override
  String get screenShareFailed => 'Paylaşım başlatılamadı';

  @override
  String get screenSharePickerTitle => 'Ekranını paylaş';

  @override
  String get screenSharePickerScreens => 'Ekranlar';

  @override
  String get screenSharePickerWindows => 'Pencereler';

  @override
  String get screenSharePickerEmpty =>
      'Paylaşacak bir şey yok — Sistem Ayarları\'nda ekran kaydına izin verip yeniden dene';

  @override
  String get gameTellFriends => 'ARKADAŞLARA SÖYLE';

  @override
  String get gameToldFriends => 'söylendi';

  @override
  String get gameTellFriendsTitle => 'arkadaşlarına söylensin mi?';

  @override
  String get gameTellFriendsBody =>
      'bu sonuçla bir bildirim alıyorlar. yalnızca bir kez gönderilebilir.';

  @override
  String get gameTellFriendsCancel => 'ŞİMDİ OLMAZ';

  @override
  String get gameTellFriendsConfirm => 'GÖNDER';

  @override
  String get gameTellFriendsSent => 'gönderildi — haberleri var';

  @override
  String get gameTellFriendsPrivate =>
      'günlük skorların gizli, kimse bunu göremezdi';

  @override
  String get gameTellFriendsFailed => 'gönderilemedi';

  @override
  String get settingsScreenFriendActivityLabel => 'ARKADAŞ HAREKETLERİ';

  @override
  String get settingsScreenFriendActivityOnBody =>
      'arkadaşların paylaştıkça kareler, puanlar ve oyun sonuçları';

  @override
  String get settingsScreenFriendActivityOffBody =>
      'hiçbir şey — panoları baktığında yine orada';

  @override
  String get searchScreenActionWithGrownUp => 'BİR BÜYÜKTE';

  @override
  String get newChatMenuSearchHint => 'arkadaşlarında ara';

  @override
  String get newChatMenuNoFriendsYet =>
      'henüz arkadaş yok —\\nKeşfet’ten birilerini bul';

  @override
  String get newChatMenuNoFriendsMatch => 'eşleşen arkadaş yok';

  @override
  String get newChatMenuOpenDmFailed => 'o sohbet açılamadı — tekrar dene';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'KENDİ KİŞİLERİNDEN SEÇ';

  @override
  String get childPolicyScreenPickPersonHint => 'ad veya kullanıcı adı ara';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'arkadaşlarından eklenecek kimse kalmadı —\\nbaşkasını aratabilirsin';

  @override
  String get childPolicyScreenPickPersonNoMatch => 'eşleşen kimse yok';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'ARKADAŞLARIN';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'DİĞER HERKES';

  @override
  String get childPolicyScreenAddRoomLabel => 'ODA EKLE';

  @override
  String get childPolicyScreenPickRoomHeading => 'ODA EKLE';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'Kendi odalarından biri. $name hemen katılır; sen geri alana kadar orada okuyup yazabilir.';
  }

  @override
  String get childPolicyScreenPickRoomHint => 'odalarında ara';

  @override
  String get childPolicyScreenPickRoomEmpty => 'eklenecek başka odan kalmadı';

  @override
  String get childPolicyScreenPickRoomNoMatch => 'eşleşen oda yok';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name artık $room odasında';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'o oda eklenemedi — tekrar dene';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'o oda bu şekilde eklenemez';

  @override
  String get childPolicyScreenErrorRoomGone => 'o oda artık yok';

  @override
  String get newChatMenuFriendsHeader => 'ARKADAŞLAR';

  @override
  String get roomChangeErrorGone =>
      'O öneri artık yok — bir yönetici cevaplamış olabilir.';

  @override
  String get roomChangeErrorNotYours =>
      'Öneriyi sadece öneren kişi geri alabilir.';

  @override
  String get roomChangeErrorNoChange => 'Zaten öyle yazıyor.';

  @override
  String get roomChangeErrorMissingValue => 'Bu hâliyle kaydedilemez.';

  @override
  String get roomChangeRequestsTitle => 'Öneriler';

  @override
  String get roomChangeRequestsBlurb =>
      'Bunları üyeler önerdi. Sen evet demeden hiçbir şey değişmez.';

  @override
  String get roomChangeRequestsEmpty => 'Öneri yok.';

  @override
  String get roomChangeRequestsApprove => 'UYGULA';

  @override
  String get roomChangeRequestsReject => 'OLMAZ';

  @override
  String get roomChangeRequestsPhotoLabel => 'Yeni grup fotoğrafı';

  @override
  String get roomChangeRequestsNameLabel => 'Yeni isim';

  @override
  String get roomChangeRequestsDescriptionLabel => 'Yeni açıklama';

  @override
  String get roomChangeRequestsUnknownLabel =>
      'Bu uygulamanın henüz gösteremediği bir değişiklik';

  @override
  String get roomChangeRequestsClearedValue => 'hiçbir şey — kaldır';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name önerdi';
  }

  @override
  String get roomAdminChangeRequestsRow => 'Öneriler';

  @override
  String get roomInfoScreenSuggestNote =>
      'bunu bir yöneticinin onaylaması gerek';

  @override
  String get roomInfoScreenSuggestAvatarNote =>
      'yeni fotoğrafları yöneticiler onaylar';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic => 'Grup fotoğrafı öner';

  @override
  String get roomInfoScreenSuggestionSentToast => 'Yöneticilere gönderildi';

  @override
  String get roomInfoScreenSuggestionAppliedToast =>
      'Tamam — bu grubu düzenleyebiliyorsun';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => 'Geri alındı';

  @override
  String get roomInfoScreenSuggestionsLabel => 'ÖNERDİKLERİN';

  @override
  String get roomInfoScreenSuggestionPhoto => 'Yeni bir grup fotoğrafı';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return 'İsim: $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return 'Açıklama: $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => 'Bir değişiklik';

  @override
  String get roomInfoScreenSuggestionPending => 'yönetici bekleniyor';

  @override
  String get roomInfoScreenSuggestionWithdraw => 'GERİ AL';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name yeni bir grup fotoğrafı önerdi';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name yeni bir isim önerdi';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name yeni bir açıklama önerdi';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öneri seni bekliyor',
      one: '$count öneri seni bekliyor',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => 'İNCELE';

  @override
  String get roomSuggestionBannerSemantic =>
      'İncelemeni bekleyen üye önerileri';

  @override
  String get gameInfoPlay => 'OYNA';

  @override
  String get gameInfoContinue => 'DEVAM ET';

  @override
  String get gameInfoSeeResult => 'SONUCUNU GÖR';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return '$total kişiden $delivered kişiye iletildi';
  }

  @override
  String get messageReceiptsSentLabel => 'GÖNDERİLDİ';

  @override
  String messageReceiptsSemanticDeliveredThenRead(
    Object deliveredDay,
    Object deliveredTime,
    Object name,
    Object readDay,
    Object readTime,
  ) {
    return '$name bunu $deliveredDay saat $deliveredTime itibarıyla aldı ve $readDay saat $readTime itibarıyla okudu';
  }

  @override
  String get messageReceiptsStampRead => 'okundu';

  @override
  String get messageReceiptsStampDelivered => 'iletildi';

  @override
  String get roomInviteCustom => 'Özel';

  @override
  String roomInviteCustomHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saat',
      one: '$count saat',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün',
      one: '$count gün',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kullanım',
      one: '$count kullanım',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => 'Saat';

  @override
  String get roomInviteUnitDays => 'Gün';

  @override
  String get roomInviteStepperIncrease => 'Artır';

  @override
  String get roomInviteStepperDecrease => 'Azalt';

  @override
  String get recordsLabel => 'TÜM ZAMANLAR';

  @override
  String get recordsBlurb => 'şimdiye kadarki en iyiler — sen ve arkadaşların';

  @override
  String recordsYourBest(Object value) {
    return 'seninki $value';
  }

  @override
  String get recordsNoneYet => 'henüz kimse';

  @override
  String get recordsEmpty =>
      'Herhangi bir oyunu çöz, en iyi derecen buraya gelsin.';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count çözüm',
      one: '$count çözüm',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return '$date tarihinde';
  }

  @override
  String recordsReactSemantic(Object name) {
    return '$name kişisinin rekoruna tepki ver';
  }

  @override
  String get recordsReactFailed => 'tepki verilemedi';

  @override
  String get recordsLoadFailed => 'rekorlar yüklenemedi';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game: rekor $value, $name';
  }

  @override
  String get appearanceLabel => 'GÖRÜNÜM';

  @override
  String get appearanceMatchDevice => 'Cihaza uy';

  @override
  String get appearanceMatchDeviceSub =>
      'gündüz açık, gece koyu — telefonunla birlikte';

  @override
  String get appearanceOneTheme => 'Tek tema';

  @override
  String get appearanceOneThemeSub => 'gün boyu aynı görünüm';

  @override
  String get appearanceLightSlot => 'AÇIK MOD';

  @override
  String get appearanceDarkSlot => 'KOYU MOD';

  @override
  String get appearanceNow => 'ŞU AN';

  @override
  String appearanceAutoValue(Object name) {
    return 'otomatik · $name';
  }

  @override
  String get themeScreenAssignHint =>
      'açık ya da koyu modda kullanmak için bir temaya dokun · tam önizleme için ⛶';

  @override
  String get themeScreenCarouselUseLight => 'AÇIK MODDA KULLAN';

  @override
  String get themeScreenCarouselUseDark => 'KOYU MODDA KULLAN';

  @override
  String get themeScreenCarouselIsLight => 'AÇIK MOD TEMAN';

  @override
  String get themeScreenCarouselIsDark => 'KOYU MOD TEMAN';

  @override
  String get onboardingThemeTitle => 'sana göre olsun.';

  @override
  String get onboardingThemeBody =>
      'bir görünüm seç. istediğin zaman ayarlardan değiştirebilirsin.';

  @override
  String get onboardingThemeYourTheme => 'TEMAN';

  @override
  String get onboardingThemeContinue => 'DEVAM';

  @override
  String get dropHintNoTarget => 'göndermek için bir sohbetin üzerine bırak';

  @override
  String get dropNothingToSend => 'burada gönderilebilecek bir şey yok';

  @override
  String dropSendPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotoğraf gönder',
    );
    return '$_temp0';
  }

  @override
  String dropSendVideos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video gönder',
    );
    return '$_temp0';
  }

  @override
  String dropSendAudio(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ses dosyası gönder',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dosya gönder',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öğe gönder',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => 'mesaja ekle';

  @override
  String get dropSendLink => 'bağlantıyı ekle';

  @override
  String dropTargetTo(String name) {
    return '$name kişisine';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dosya $size sınırını aşıyor',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => 'klasörler gönderilemez';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count boş dosya atlanıyor',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => 'burada ek gönderilemez';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tanesi dosya olarak gönderilecek',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tanesi her cihazda görünmeyebilir',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => 'fotoğraf';

  @override
  String get dropKindVideo => 'video';

  @override
  String get dropKindAudio => 'ses';

  @override
  String get dropKindFile => 'dosya';

  @override
  String get dropKindFolder => 'klasör';

  @override
  String get dropKindText => 'metin';

  @override
  String get dropKindLink => 'bağlantı';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dosya bu göndermeye sığmadı',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed => 'Bu yapılamadı. Tekrar dene.';

  @override
  String get expressionBackspace => 'Sil';

  @override
  String get expressionCreateSticker => 'Çıkartma yap';

  @override
  String get expressionDeleteSticker => 'Çıkartmalarımdan sil';

  @override
  String get expressionFavorite => 'Favorilere ekle';

  @override
  String get expressionFavorited => 'Favorilere eklendi';

  @override
  String get expressionFavorites => 'Favoriler';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF: $title';
  }

  @override
  String get expressionLoadFailed => 'Yüklenemedi. Bağlantını kontrol et.';

  @override
  String get expressionMediaNotAllowed =>
      'Aile ayarların resim göndermene izin vermiyor.';

  @override
  String get expressionMyStickers => 'Çıkartmalarım';

  @override
  String get expressionNoFavorites =>
      'Favorilere eklemek için bir GIF’e veya çıkartmaya basılı tut.';

  @override
  String get expressionNoRecents =>
      'Gönderdiğin GIF’ler ve çıkartmalar burada görünecek.';

  @override
  String get expressionNoResults => 'Sonuç yok';

  @override
  String get expressionNoStickers => 'Burada henüz çıkartma yok.';

  @override
  String get expressionOpenPanel => 'Emoji, GIF ve çıkartmalar';

  @override
  String get expressionOptionsHint => 'seçenekleri göster';

  @override
  String expressionPackCredit(String author, String license) {
    return 'Çizim: $author · $license';
  }

  @override
  String get expressionPlayGifHint => 'oynat';

  @override
  String get expressionRecent => 'Son kullanılanlar';

  @override
  String get expressionReport => 'Bildir';

  @override
  String get expressionReported => 'Teşekkürler — bildirildi.';

  @override
  String get expressionRetry => 'Tekrar dene';

  @override
  String get expressionSearchKlipy => 'KLIPY’de ara';

  @override
  String get expressionShowKeyboard => 'Klavyeyi göster';

  @override
  String get expressionSuggestionsLabel => 'Çıkartma önerileri';

  @override
  String get expressionTabEmoji => 'Emoji';

  @override
  String get expressionTabGifs => 'GIF';

  @override
  String get expressionTabStickers => 'Çıkartmalar';

  @override
  String get expressionTrending => 'Popüler';

  @override
  String get expressionUnfavorite => 'Favorilerden kaldır';

  @override
  String get expressionUnfavorited => 'Favorilerden kaldırıldı';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return 'Çıkartma $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel =>
      'GIF ve çıkartmaları otomatik oynat';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      'Birine dokunana kadar hareketsiz kalırlar. Veri tasarrufu sağlar.';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'GIF’ler ve hareketli çıkartmalar kendiliğinden oynar. Hareketi Azalt onları duraklatır.';

  @override
  String get settingsStickerSuggestionsBody =>
      'Tek bir emoji yazınca mesaj alanının üstünde eşleşen çıkartmalar çıkar.';

  @override
  String get settingsStickerSuggestionsLabel => 'Çıkartma önerileri';

  @override
  String get stickerMakerEmojiLabel => 'Hangi emoji?';

  @override
  String get stickerMakerFailed => 'Çıkartma kaydedilemedi. Tekrar dene.';

  @override
  String get stickerMakerMoreEmoji => 'Daha fazla emoji';

  @override
  String get stickerMakerPreview => 'Çıkartma önizlemesi';

  @override
  String get stickerMakerRemoveBackground => 'Arka planı kaldır';

  @override
  String get stickerMakerSave => 'Kaydet';

  @override
  String get stickerMakerSaved => 'Çıkartma, Çıkartmalarım’a eklendi';

  @override
  String get stickerMakerShape => 'Şekil';

  @override
  String get stickerMakerShapeCircle => 'Daire';

  @override
  String get stickerMakerShapeOriginal => 'Orijinal';

  @override
  String get stickerMakerShapeRounded => 'Yuvarlatılmış kare';

  @override
  String get stickerMakerTitle => 'Yeni çıkartma';

  @override
  String get stickerMakerTooMany =>
      'Çıkartma sınırına ulaştın. Yer açmak için birini sil.';

  @override
  String get expressionExpandPanel => 'Paneli genişlet';

  @override
  String get expressionCollapsePanel => 'Paneli küçült';
}
