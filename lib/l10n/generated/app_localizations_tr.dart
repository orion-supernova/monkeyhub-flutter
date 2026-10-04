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
  String get bootErrorTitle => 'Sunucuya ulaşılamıyor';

  @override
  String get bootErrorBody => 'Convex başlatılamadı.';

  @override
  String get bootErrorRetry => 'Tekrar dene';

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
      'Şu an sorulamadı — tekrar dene';

  @override
  String get roomScreenGateSendMessages => 'buraya mesaj göndermek';

  @override
  String get roomScreenGateSendMedia => 'fotoğraf ya da sesli not göndermek';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'Bir seferde en fazla $max tane';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesajı sil',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Bu, mesajları sohbetteki herkes için kaldırır. Geri alınamaz.';

  @override
  String get roomScreenDeleteConfirmButton => 'Herkes için sil';

  @override
  String get roomScreenJumpFailedSnack => 'O mesaja gidilemedi';

  @override
  String get roomScreenUnreadDivider => 'Okunmamış mesajlar';

  @override
  String get roomScreenViewOnceAlreadyViewed => 'Bu fotoğrafı zaten açtın.';

  @override
  String get roomScreenViewOnceGone => 'Bu fotoğraf artık mevcut değil.';

  @override
  String get roomScreenViewOnceNetworkError => 'Fotoğraf yüklenemedi.';

  @override
  String get roomScreenFileReadFailedSnack => 'Dosya okunamadı';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'Dosyalar en fazla $size olabilir';
  }

  @override
  String get roomScreenRoomGone => 'Oda artık yok';

  @override
  String get roomScreenCopiedSnack => 'Kopyalandı';

  @override
  String get roomScreenNameCopiedSnack => 'İsim kopyalandı';

  @override
  String get roomScreenPinLimitSnack =>
      'Çok fazla sabitlenmiş mesaj var — önce birini kaldır';

  @override
  String get roomScreenPinFailedSnack => 'Sabitlenemedi';

  @override
  String get roomScreenReportSentSnack =>
      'Şikayet gizlice gönderildi. Karşı taraf bilgilendirilmeyecek.';

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
    return 'Bu oda geçici. Mesajlar okunsun okunmasın $ttl sonra siliniyor.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count mesaj';
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
      'Profil fotoğrafını görüntüle';

  @override
  String get roomScreenViewRoomPictureSemantic => 'Oda fotoğrafını görüntüle';

  @override
  String get messageBubbleFileFallbackName => 'Belge';

  @override
  String get messageBubbleAttachmentStatusFailed => 'Başarısız';

  @override
  String get messageBubbleAttachmentStatusSending => 'Gönderiliyor…';

  @override
  String get messageBubbleViewOnceOpened => 'Görüntülendi';

  @override
  String get messageBubbleViewOnceExpired => 'Süresi doldu';

  @override
  String get messageBubbleViewOnceLabel => 'Tek seferlik';

  @override
  String get messageBubbleViewOnceTapToView => 'Görmek için dokun';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Fotoğraf';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'Tek seferlik fotoğraf, görüntülemek için dokun';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'Gönderimi yeniden dene';

  @override
  String get messageBubbleDiscardSemanticLabel => 'Sil';

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
  String get profileScreenLinkedAccountsNone => 'Bağlı hesap yok';

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
  String get cameraEditorScreenCropPresetFree => 'Serbest';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'Orijinal';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'Kırpmayı iptal et';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'Fotoğrafı sil';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'Geri al';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'Yinele';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'Kırpmayı sıfırla';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'Döndür';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'Kırp';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'Bu tarayıcı HEIC fotoğrafları açamıyor';

  @override
  String get cameraEditorScreenImageLoadFailedMessage => 'Bu görseli açamadık';

  @override
  String get cameraEditorScreenCropDoneButton => 'Tamam';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'Yeniden çek';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'Kalemi kaldır';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'Fotoğrafa çiz';

  @override
  String get cameraEditorScreenSendingButton => 'Gönderiliyor…';

  @override
  String get cameraEditorScreenSendButton => 'Gönder';

  @override
  String get cameraEditorScreenViewOnceNote => 'Bir kez açılınca kaybolur';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'Çizimi temizle';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel =>
      'Tek seferlik görüntüleme: açık';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel =>
      'Tek seferlik görüntüleme: kapalı';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: açık';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: kapalı';

  @override
  String get cameraEditorScreenHdNote => 'Tam çözünürlükte gönderiliyor';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'Mürekkep rengi';

  @override
  String get glassScreenPanelLooks => 'Görünümler';

  @override
  String get glassScreenPanelBottomBar => 'Alt çubuk';

  @override
  String get glassScreenPanelOtherSurfaces => 'Diğer yüzeyler';

  @override
  String get glassScreenPanelBarLayout => 'Çubuk yerleşimi';

  @override
  String get glassScreenTitle => 'cam.';

  @override
  String get glassScreenSubtitle => 'arkadaki ne kadar görünsün';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'Tüm $max yuva dolu';
  }

  @override
  String get glassScreenSaveCurrentAs => 'Görünüm olarak kaydet…';

  @override
  String get glassScreenResetEveryDial => 'Tüm ayarları sıfırla';

  @override
  String glassScreenResetToPreset(Object name) {
    return '$name olarak sıfırla';
  }

  @override
  String get glassScreenSurfacesNote =>
      'Mesaj kutusu, başlıklar, arama düğmeleri — kayan içerik yerine metnin üzerine oturan her şey';

  @override
  String get glassScreenMatchBottomBar => 'Alt çubukla eşleştir';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'Değiştirildi — yeni bir görünüm olarak kaydet ya da sıfırla';

  @override
  String get glassScreenCustomPresetName => 'Özel';

  @override
  String get glassScreenUnsavedSubtitle =>
      'Kaydedilmedi — saklamak için bir isim ver';

  @override
  String get glassScreenSaveDialogTitle => 'Bu görünümü farklı kaydet';

  @override
  String get glassScreenNoRoomToast => 'Yer kalmadı — önce bir görünüm sil';

  @override
  String get glassScreenRenameDialogTitle => 'Yeniden adlandır';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '$name silinsin mi?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'Görünüm ekranda kalmaya devam eder — sadece adını kaybeder.';

  @override
  String get glassScreenKeepButton => 'Sakla';

  @override
  String get glassScreenDeleteButton => 'Sil';

  @override
  String get glassScreenNameHint => 'Geç saatler';

  @override
  String get glassScreenCancelButton => 'Vazgeç';

  @override
  String get glassScreenSaveButton => 'Kaydet';

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
  String get glassScreenPreviewBadge => 'Önizleme';

  @override
  String get glassScreenBuiltInLabel => 'Yerleşik';

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
  String get replyIndicatorViewOnceLabel => 'Fotoğraf · tek seferlik';

  @override
  String get replyIndicatorVoiceMessageLabel => 'Sesli mesaj';

  @override
  String get replyIndicatorDocumentLabel => 'Belge';

  @override
  String get replyIndicatorMessageRemoved => 'Mesaj kaldırıldı';

  @override
  String get threadOverlayMessageNotFound => 'Bu konuda o mesajı bulamadım';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'Yanıtlanacak konuyu bulamadım';

  @override
  String get threadOverlayStillSending =>
      'Hâlâ gönderiliyor — birazdan tekrar dene';

  @override
  String get threadOverlayCopiedToast => 'Kopyalandı';

  @override
  String get threadOverlayNameCopiedToast => 'Ad kopyalandı';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'Koordinatlar kopyalandı';

  @override
  String get threadOverlayPinLimitToast =>
      'Çok fazla sabitlenmiş mesaj var — önce birini kaldır';

  @override
  String get threadOverlayPinFailedToast => 'Bunu sabitleyemedim';

  @override
  String get threadOverlayReportedToast => 'Bildirildi';

  @override
  String get threadOverlayUnavailable => 'konu kullanılamıyor';

  @override
  String get roomInfoScreenNameRequiredError => 'İsim gerekli';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'Şifre kaldırıldı';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'Odadan ayrıl?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'Açık kalırsa tekrar katılabilirsin.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'Ayrıl';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'Odayı sil?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'Buradaki her mesaj onunla birlikte gider. Bu geri alınamaz.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'Sil';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      'Bu sohbeti sonlandır?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName da bu sohbeti kaybeder — her iki tarafta da tüm mesajlar silinir. Bu geri alınamaz.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'Sonlandır';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'Diğer kişi';

  @override
  String get roomInfoScreenConfirmCancelButton => 'VAZGEÇ';

  @override
  String get roomInfoScreenErrorRoomExists => 'Bu isimde bir oda zaten var';

  @override
  String get roomInfoScreenErrorNotOwner => 'Bunu sadece sahibi yapabilir';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'Bunun için yetkin yok';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'Bu oda artık yok';

  @override
  String get roomInfoScreenRoomGone => 'Oda artık yok';

  @override
  String get roomInfoScreenNameLabel => 'İSİM';

  @override
  String get roomInfoScreenNameHint => 'Oda ismi';

  @override
  String get roomInfoScreenDescriptionLabel => 'AÇIKLAMA';

  @override
  String get roomInfoScreenDescriptionHint => 'Oda hakkında tek satır';

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
  String get roomInfoScreenReplacePasswordHint => 'Şifreyi değiştir';

  @override
  String get roomInfoScreenSetPasswordHint => 'Bir şifreyle kilitle';

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
      'Profil fotoğrafını görüntüle';

  @override
  String get roomInfoScreenViewRoomPictureSemantic =>
      'Oda fotoğrafını görüntüle';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic =>
      'Oda fotoğrafını değiştir';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'Oda fotoğrafı ekle';

  @override
  String get roomInfoScreenOwnerBadge => 'SAHİP';

  @override
  String get roomInfoScreenNoneCount => 'yok';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'Kamera erişimi kapalı.\nFotoğraf çekmek için Ayarlar’dan izin vermen gerekiyor.';

  @override
  String get cameraScreenOpeningSystemCamera => 'Sistem kamerası açılıyor…';

  @override
  String get cameraScreenCloseButtonLabel => 'Kamerayı kapat';

  @override
  String get cameraScreenLowLightBoostOnLabel => 'Az ışık modu: açık';

  @override
  String get cameraScreenLowLightBoostOffLabel => 'Az ışık modu: kapalı';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'Flaş: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'Galeriden seç';

  @override
  String get cameraScreenSwitchCameraLabel => 'Kamerayı değiştir';

  @override
  String get cameraScreenTakePhotoLabel => 'Fotoğraf çek';

  @override
  String get childPolicyScreenAddByUsernameLabel => 'Kullanıcı adıyla ekle';

  @override
  String get childPolicyScreenAddCta => 'Ekle';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'Tam olarak sendeki yetkiye sahip olurlar: onaylanacak her istek, değiştirilecek her ayar ve seni kaldırma gücü. $name onları hemen aile olarak görür.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'Bir yetişkin ekle';

  @override
  String get childPolicyScreenAddGuardianHint => 'Onun kullanıcı adı';

  @override
  String get childPolicyScreenAllowCta => 'İzin ver';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'Bir daha sorulmayacaksın — ister $childName onları eklesin, ister onlar $childName’ı eklesin.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'Birine izin ver';

  @override
  String get childPolicyScreenAskToAddLabel => 'Ekleme izni iste';

  @override
  String get childPolicyScreenAskToAddOffDesc => 'Sadece aile — yeni istek yok';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'Yeni biri için senden izin isteyebilirler';

  @override
  String get childPolicyScreenBothFinalNote =>
      'İkisi de kalıcıdır. Bunun yerine ayrılmak istiyorsan yukarıdaki Yetişkinler bölümüne bak.';

  @override
  String get childPolicyScreenCallsLabel => 'Aramalar';

  @override
  String get childPolicyScreenCallsOffDesc => 'Sadece mesaj';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'İzinli kişilerle sesli + görüntülü arama';

  @override
  String get childPolicyScreenCancelLabel => 'Vazgeç';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Vazgeç';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'Eklendi — istek gönderiliyor';

  @override
  String get childPolicyScreenContactAddedToList =>
      'İzin verilenler listesine eklendi';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'Oda kur';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'Oda kuramazlar';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'Kendi özel odalarını kurabilirler';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Her şey gider: mesajları, fotoğrafları, odaları ve arkadaşları. Bu geri alınamaz ve kullanıcı adı başkalarına açılır.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'Hesap silinemedi — tekrar dene';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return '$name’in hesabı silinsin mi?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Mesajlar, fotoğraflar, odalar ve arkadaşlar hepsi gider. Geri alınamaz.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return '$name’in hesabını sil';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'Sonsuza dek sil';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'Eklenemedi — tekrar dene';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'Bu onun kendi kullanıcı adı';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'Bir çocuk yetişkin olamaz';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'Bu işlem olmadı — tekrar dene';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'Birinin onlara bakması lazım — önce başka bir yetişkin ekle';

  @override
  String get childPolicyScreenErrorNotYours => 'Bunu değiştirme yetkin yok';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'Bu kullanıcı adında bir hesap yok';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'Bu şifreyle normal bir hesaba dönüşürler, tüm yetişkinler görünürlüğünü tamamen kaybeder. Geri dönüşü yok — normal biri gibi tekrar davet edilmen gerekir.';

  @override
  String get childPolicyScreenGraduateCta => 'Mezun et';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'Her şeyi korurlar ve bir şifre alırlar. Sen tüm görünürlüğünü kaybedersin. Geri alınamaz.';

  @override
  String get childPolicyScreenGraduateDangerLabel => 'Tam hesaba geçir';

  @override
  String get childPolicyScreenGraduateFailed => 'Mezun edilemedi — tekrar dene';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return '$name mezun olsun';
  }

  @override
  String get childPolicyScreenGraduateHint => 'Onlar için bir şifre';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Bir odayı geri almak, onları da odadan çıkarır. Bir kişiyi geri almak ise sohbeti de siler — ikisi için de.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Buradaki herkes onaylayabilir, ayarları değiştirebilir ve her şeyi görebilir. Herhangi biri tek başına hareket edebilir — kimse diğerini beklemez.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'Eklendi — artık onlara bakabilirler';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name kaldırıldı';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (sen)';
  }

  @override
  String get childPolicyScreenLoading => 'Yükleniyor…';

  @override
  String get childPolicyScreenLockedLabel => 'Kilitli';

  @override
  String get childPolicyScreenMediaLabel => 'Fotoğraf + ses';

  @override
  String get childPolicyScreenMediaOffDesc => 'Sadece metin';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'Fotoğraf, video ve sesli not gönderebilirler';

  @override
  String get childPolicyScreenNoRoomsYet => 'Henüz oda yok';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Buradaki herkes sana tekrar sormadan eklenebilir — kim başlatırsa başlatsın.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Çocuklar için her zaman kapalı. Keşfet — tanımadığın kişilere ait odaların listesi — tamamen gizli ve açılamaz. Birinin onları davet ettiği odalar normal şekilde çalışmaya devam eder.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'Herkese açık odalar';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian artık $child için hiçbir şey görmeyecek ya da onaylamayacak.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return '$name kaldırılsın mı?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'Kaldır';

  @override
  String childPolicyScreenRoomMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi',
    );
    return '$_temp0';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'Yetişkinler';

  @override
  String get childPolicyScreenSectionPeopleAllowed => 'İzin verdiğin kişiler';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'İzin verdiğin odalar';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'Yapabilecekleri';

  @override
  String get childPolicyScreenSectionWhenDone => 'Son adımlar';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'Biri diğerini eklemeden hiçbir şey olmaz';

  @override
  String get childPolicyScreenSendNowOnDesc => 'Hemen sorulurlar';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'İsteği şimdi gönder';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return '$name’in tek yetişkini sensin, o yüzden öylece ayrılamazsın — önce başka birini ekle ya da bunlardan birini kullan.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'Ayrıl';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return '$name’in hesabına dair tüm görünürlüğünü kaybedersin — istekleri, kişileri, odaları. Diğer yetişkinler onlara göz kulak olmaya devam eder.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'Gözetimi bırak';

  @override
  String get childPolicyScreenStopSupervisingHeadline =>
      'Gözetimi bırakmak istiyor musun?';

  @override
  String get childPolicyScreenTakeBackFailed => 'Geri alınamadı — tekrar dene';

  @override
  String get childPolicyScreenTakeBackLabel => 'Geri al';

  @override
  String get childPolicyScreenUsernameHint => 'Kullanıcı adı';

  @override
  String get childPolicyScreenYou => 'Sen';

  @override
  String get roomContentScreenDefaultDocumentName => 'Belge';

  @override
  String get roomContentScreenCouldntOpenFile => 'O dosya açılamadı';

  @override
  String get roomContentScreenCouldntShare => 'Bunlar paylaşılamadı';

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
      other: '$count mesajı sil',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Bunlar, sohbetteki herkes için kaldırılır. Geri alınamaz.';

  @override
  String get roomContentScreenDeleteForEveryone => 'Herkes için sil';

  @override
  String get roomContentScreenCancelTooltip => 'Vazgeç';

  @override
  String get roomContentScreenBackTooltip => 'Geri';

  @override
  String get roomContentScreenSelectingLabel => 'Seçiliyor';

  @override
  String get roomContentScreenSharedContentLabel => 'Paylaşılan içerik';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seçildi',
      zero: 'Hiçbir şey seçilmedi',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'Seç';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'Tümü';

  @override
  String get roomContentScreenEmptyMedia => 'Henüz fotoğraf ya da video yok';

  @override
  String get roomContentScreenEmptyFiles => 'Henüz dosya yok';

  @override
  String get roomContentScreenEmptyVoice => 'Henüz sesli not yok';

  @override
  String get roomContentScreenEmptyLinks => 'Henüz bağlantı yok';

  @override
  String get roomContentScreenEmptySaved =>
      'Henüz bir şey kaydedilmedi. Bir mesaja basılı tut ve Kaydet’i seç.\n\nBurada tuttukların yalnızca sana ait — sabitlenmiş bir mesajı ise odadaki herkes görür.';

  @override
  String get roomContentScreenLoadFailed => 'Bu yüklenemedi';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return '$name adlı kişiden sesli mesaj';
  }

  @override
  String get roomContentScreenForwardAction => 'İlet';

  @override
  String get roomContentScreenCopyAction => 'Kopyala';

  @override
  String get roomContentScreenSaveAction => 'Kaydet';

  @override
  String get roomContentScreenShareAction => 'Paylaş';

  @override
  String get roomContentScreenInChatAction => 'Sohbette';

  @override
  String get roomContentScreenDeleteAction => 'Sil';

  @override
  String get messageActionMenuReplyLabel => 'Yanıtla';

  @override
  String get messageActionMenuEditLabel => 'Düzenle';

  @override
  String get messageStampEditedLabel => 'düzenlendi';

  @override
  String get composerEditCardTitle => 'Mesajı düzenle';

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
  String get linkConfirmSheetTitle => 'Bu bağlantı açılsın mı?';

  @override
  String get linkConfirmSheetOpenLabel => 'Bağlantıyı aç';

  @override
  String get linkConfirmSheetCancelLabel => 'İptal';

  @override
  String get roomScreenEditExpiredSnack =>
      'Düzenlemek için çok geç — mesajlar yalnızca 15 dakika içinde düzenlenebilir.';

  @override
  String get roomScreenEditFailedSnack =>
      'Düzenleme kaydedilemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get messageActionMenuForwardLabel => 'İlet';

  @override
  String get messageActionMenuViewThreadLabel => 'Yanıtları gör';

  @override
  String get messageActionMenuCopyLabel => 'Kopyala';

  @override
  String get messageActionMenuCopyNameLabel => 'Adı kopyala';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'Koordinatları kopyala';

  @override
  String get messageActionMenuPinLabel => 'Sabitle';

  @override
  String get messageActionMenuUnpinLabel => 'Sabiti kaldır';

  @override
  String get messageActionMenuSelectLabel => 'Seç';

  @override
  String get messageActionMenuProfileLabel => 'Profil';

  @override
  String get messageActionMenuDeleteLabel => 'Sil';

  @override
  String get messageActionMenuReportLabel => 'Şikayet et';

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
  String get callScreenStatusConnected => 'Bağlandı';

  @override
  String get callScreenStatusEnded => 'Arama sona erdi';

  @override
  String get callScreenStatusFailed => 'Arama başarısız oldu';

  @override
  String get callScreenStatusSwitching => 'Cihaz değiştiriliyor…';

  @override
  String get callScreenStatusMoved => 'Taşındı';

  @override
  String get callScreenStatusReconnecting => 'Yeniden bağlanıyor…';

  @override
  String get callScreenPoorConnectionLabel => 'Kötü bağlantı';

  @override
  String get callScreenWeakConnectionLabel => 'Zayıf bağlantı';

  @override
  String get callScreenControlUnmute => 'Sesi aç';

  @override
  String get callScreenControlMute => 'Sesi kapat';

  @override
  String get callScreenControlCamOn => 'Kamerayı aç';

  @override
  String get callScreenControlCamOff => 'Kamerayı kapat';

  @override
  String get callScreenControlFlip => 'Çevir';

  @override
  String get callScreenControlSpeaker => 'Hoparlör';

  @override
  String get callScreenControlEnd => 'Bitir';

  @override
  String get linkPreviewCardLinkLabel => 'Bağlantı';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name isteğini kabul etti';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'O istek geri çekildi';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'İstek reddedildi';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'Bu kullanıcıyı engelledin — önce engeli kaldır.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'Şu anda arkadaşlık isteği kabul etmiyorlar.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'Gönderilemedi. Tekrar dene.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => 'Gelen istek';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'Yeni istek';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name bir sohbet başlatmak istiyor.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'birkaç satır yaz. onaylayabilir ya da reddedebilir.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'İki taraf da kabul etmeden hiçbir şey kalıcı olmaz.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'Oda türü';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'Geçici';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'Standart';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'Süre';

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
      'Bir şeyler fısılda · isteğe bağlı';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'İlk mesajı ekle · isteğe bağlı';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'Fısılda · kendiliğinden siliniyor';

  @override
  String get friendRequestDraftScreenHintStartWith =>
      'Başlamak için bir şeyler yaz';

  @override
  String get friendRequestDraftScreenApproveButton => 'Onayla ve odayı aç';

  @override
  String get friendRequestDraftScreenDeclineButton => 'Reddet';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'İsteği iptal et';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => 'Bir yetişkine sor';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'İstek gönder';

  @override
  String get discoverScreenTitle => 'keşfet.';

  @override
  String get discoverScreenCaptionPeople => 'kişiler';

  @override
  String get discoverScreenCaptionRooms => 'odalar';

  @override
  String get discoverScreenCaptionRequests => 'istekler';

  @override
  String get discoverScreenPeopleBandLabel => 'Kişiler';

  @override
  String get discoverScreenRoomsBandLabel => 'Odalar';

  @override
  String get discoverScreenFindPeopleTitle => 'Kişi bul';

  @override
  String get discoverScreenFindPeopleSubtitleChild => 'Tam kullanıcı adını yaz';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      '@kullanıcıadı veya isimle ara';

  @override
  String get discoverScreenRequestsSectionLabel => 'İstekler';

  @override
  String get discoverScreenInboxQuiet => 'Gelen kutusu sessiz';

  @override
  String get discoverScreenNothingPending => 'Gönderdiğin istek yok';

  @override
  String get discoverScreenYourPeopleLabel => 'Arkadaşların';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'Henüz kimse yok — yukarıdan kişi bul';

  @override
  String get discoverScreenNoFriendsYet => 'Henüz kimse yok';

  @override
  String get discoverScreenSearchRoomsTitle => 'Oda ara';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'Herkese açık bir odayı adıyla bul';

  @override
  String get discoverScreenYourRoomsLabel => 'Odaların';

  @override
  String get discoverScreenNoRoomsYet => 'Henüz oda yok';

  @override
  String get discoverScreenIncomingLabel => 'Gelen';

  @override
  String get discoverScreenOutgoingLabel => 'Giden';

  @override
  String get discoverScreenIncomingLabelCaps => 'GELEN';

  @override
  String get discoverScreenOutgoingLabelCaps => 'GİDEN';

  @override
  String get discoverScreenJumpPeopleLabel => 'Kişiler';

  @override
  String get discoverScreenJumpRoomsLabel => 'Odalar';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return '$label bölümüne git';
  }

  @override
  String get imageCropScreenDefaultTitle => 'Ayarla';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'Fotoğrafı kullan';

  @override
  String get imageCropScreenSavingButton => 'Kaydediliyor…';

  @override
  String get imageCropScreenCancelButton => 'Vazgeç';

  @override
  String get imageCropScreenHeicUnsupported =>
      'Bu tarayıcı HEIC fotoğrafları açamıyor';

  @override
  String get imageCropScreenLoadFailed => 'Bu görseli açamadık';

  @override
  String get imageCropScreenHintCircle =>
      'Taşımak için sürükle, yakınlaştırmak için sıkıştır';

  @override
  String get imageCropScreenHintRect => 'Çerçevelemek için sürükle ve sıkıştır';

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
  String get searchScreenHintPeople => 'Kişi ara';

  @override
  String get searchScreenHintRooms => 'Oda ara';

  @override
  String get searchScreenPeoplePromptChild =>
      'Yeni birini bulmak için kullanıcı adını eksiksiz yaz';

  @override
  String get searchScreenPeoplePromptDefault =>
      'kullanıcı adına veya isme göre ara';

  @override
  String get searchScreenNoMatchChild =>
      'Kimse bulunamadı — yeni biri için kullanıcı adının\ntamamı, harfi harfine gerekiyor';

  @override
  String get searchScreenNoMatchDefault => 'Kimse bulunamadı';

  @override
  String get searchScreenNoRoomsYet => 'Henüz herkese açık oda yok';

  @override
  String get searchScreenNoRoomsMatch => 'Eşleşen herkese açık oda yok';

  @override
  String get searchScreenActionAskToAdd => 'Eklemeyi sor';

  @override
  String get searchScreenActionSendRequest => 'İstek gönder';

  @override
  String get searchScreenActionCancel => 'İptal';

  @override
  String get searchScreenActionApprove => 'Onayla';

  @override
  String get searchScreenActionOpenDm => 'DM\'yi aç';

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
      'Kopyalandı — güvenli bir yere yapıştır';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'Doğrula\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'kimliğini.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Şifren, hesabına başkası kurtarma ifadesi ekleyemesin diye.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'Şifre';

  @override
  String get recoveryPhraseScreenContinueButton => 'DEVAM ET';

  @override
  String get recoveryPhraseScreenNotNowLink => 'şimdi değil';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'Şifreni gir.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'Kaydet\n';

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
  String get homeScreenEmptyRoomsMessage => 'Henüz oda yok — birini oluştur';

  @override
  String get groupCallScreenTitleVideo => 'Grup görüntülü arama';

  @override
  String get groupCallScreenTitleVoice => 'Grup sesli arama';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '$count kişi aramada';
  }

  @override
  String get groupCallScreenReconnecting => 'Yeniden bağlanıyor…';

  @override
  String get groupCallScreenUnmuteLabel => 'Sesi aç';

  @override
  String get groupCallScreenMuteLabel => 'Sesi kapat';

  @override
  String get groupCallScreenCamOnLabel => 'Kamerayı aç';

  @override
  String get groupCallScreenCamOffLabel => 'Kamerayı kapat';

  @override
  String get groupCallScreenFlipLabel => 'Çevir';

  @override
  String get groupCallScreenSpeakerLabel => 'Hoparlör';

  @override
  String get groupCallScreenLeaveLabel => 'Ayrıl';

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
  String get roomFilterDrawerClearLabel => 'Temizle';

  @override
  String get roomFilterDrawerDimensionType => 'Tür';

  @override
  String get roomFilterDrawerDimensionNature => 'Nitelik';

  @override
  String get roomFilterDrawerDimensionStatus => 'Durum';

  @override
  String get roomFilterDrawerPanelClear => 'Temizle';

  @override
  String get roomFilterDrawerPanelDone => 'Tamam';

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
      other: 'Tüm $count sohbeti göster',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'Yeni oda';

  @override
  String get createRoomSheetTaglineSecret => 'Hiçbir şey saklanmaz';

  @override
  String get createRoomSheetTaglineRegular => 'Kalıcı bir alan';

  @override
  String get createRoomSheetNameLabel => 'İsim';

  @override
  String get createRoomSheetNameHint => 'Ona dürüst bir isim ver';

  @override
  String get createRoomSheetDescriptionLabel => 'Açıklama · isteğe bağlı';

  @override
  String get createRoomSheetDescriptionHint => 'Oda hakkında tek satır';

  @override
  String get createRoomSheetVisibilityLabel => 'Görünürlük';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'Herkese açık';

  @override
  String get createRoomSheetVisibilityPublicSub => 'Herkes bulabilir';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'Gizli';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'Sadece davetle';

  @override
  String get createRoomSheetTypeLabel => 'Tür';

  @override
  String get createRoomSheetTypeStandardTitle => 'Standart';

  @override
  String get createRoomSheetTypeStandardSub => 'Mesajlar kalıcı';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'Geçici';

  @override
  String get createRoomSheetTypeEphemeralSub => 'Otomatik silinir';

  @override
  String get createRoomSheetMessageLifeLabel => 'Mesaj ömrü';

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
  String get createRoomSheetPasswordLabel => 'Şifre · isteğe bağlı';

  @override
  String get createRoomSheetPasswordHint => 'Bir parola ile kilitle';

  @override
  String get createRoomSheetNameRequiredError => 'İsim gerekli';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Odayı aç';

  @override
  String get createRoomSheetOpenRoomButton => 'Odayı aç';

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
  String get reactionDetailsSheetTitle => 'Tepkiler';

  @override
  String get reactionDetailsSheetEmptyState => 'Artık burada bir şey yok';

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
  String get reactionDetailsSheetFilterAll => 'Tümü';

  @override
  String get reactionDetailsSheetYouBadge => 'Sen';

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
  String get audioMessageUnavailableLabel => 'Ses artık yok';

  @override
  String get audioMessageRetryHint => 'Yeniden denemek için dokun';

  @override
  String get audioMessageLoadingLabel => 'Yükleniyor…';

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
  String get audioMessageUsernameHint => 'Kullanıcı adı';

  @override
  String get audioMessageDisplayNameHint => 'Görünen ad (isteğe bağlı)';

  @override
  String get audioMessagePasswordHint => 'Şifre';

  @override
  String get audioMessageSwitchToLinkPrompt => 'O hesap benim — giriş yapayım';

  @override
  String get audioMessageCreateAccountButton => 'Hesap oluştur';

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
  String get approvalsScreenForwardDirectMessageFallback => 'Birebir mesaj';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesajı ilet',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'Henüz başka sohbet yok';

  @override
  String get approvalsScreenForwardNoMatches => 'Eşleşen bir şey yok';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'Bir seferde en fazla $max sohbet';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'Sohbetlerde ara';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return '$title seçimini kaldır';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return '$title seç';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'Kayboluyor';

  @override
  String get approvalsScreenForwardSendSemantic => 'Gönder';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sohbete gönder',
      zero: 'Gönder',
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
  String get linkedAccountsScreenCallSheetVoiceLabel => 'Sesli';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'Görüntülü';

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
  String get childPairScreenStopScanning => 'Taramayı durdur';

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
  String get fileMessageStandardBadge => 'Standart';

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
  String get fileMessageApproveButton => 'Onayla';

  @override
  String get fileMessageDeclineButton => 'Reddet';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return '$ago gönderildi';
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
  String get fileMessageCancelRequestButton => 'İsteği iptal et';

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
  String get destructiveSheetPairingCodeExpired => 'Bu kodun süresi doldu';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return '$time içinde sona erer';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'Yeni kod';

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
  String get deepOceanThemeEphemeralHint => 'Bir şey fısılda';

  @override
  String get deepOceanThemeDefaultHint => 'Bir şeyler söyle';

  @override
  String get deepOceanThemeMessageHint => 'Mesaj';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'Bu dosya artık yok';

  @override
  String get photoChromeMediaYouLabel => 'Sen';

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
  String get photoTrayDiscardSemanticLabel => 'Bu fotoğrafları bırak';

  @override
  String get photoTrayRemoveSemanticLabel => 'Bu fotoğrafı çıkar';

  @override
  String get photoTrayEditSemanticLabel => 'Bu fotoğrafı kırp veya üzerine çiz';

  @override
  String get photoTrayAddMoreSemanticLabel => 'Daha fazla fotoğraf ekle';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'Tek seferde $count fotoğraf gönderebilirsin';
  }

  @override
  String get photoTrayLoadFailedSnack => 'O fotoğrafların bazıları açılamadı';

  @override
  String get mediaPickFailedMessage => 'Bu açılamadı — tekrar seçmeyi dene';

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
  String get typingIndicatorUnknownCallerFallbackName => 'Gelen arama';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'Gelen görüntülü arama';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'Gelen sesli arama';

  @override
  String get typingIndicatorDeclineButtonLabel => 'Reddet';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'Reddediliyor…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'Kabul et';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'Bağlanıyor…';

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
      'Mikrofon izni verilmedi';

  @override
  String get voiceRecorderScreenStatusRecording => 'Kaydediliyor';

  @override
  String get voiceRecorderScreenStatusReady => 'Hazır';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'Başlatmak için dokun';

  @override
  String get voiceRecorderScreenReRecordButton => 'Tekrar kaydet';

  @override
  String get voiceRecorderScreenStopButton => 'Durdur';

  @override
  String get voiceRecorderScreenSendButton => 'Gönder';

  @override
  String get voiceRecorderScreenRecordButton => 'Kaydet';

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
  String get activeCallPillPinnedHeader => 'Sabitlenenler';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'Sabitlenenler · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'Artık sabitlenen yok';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return '$name tarafından gönderilen mesaja git';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return '$name tarafından gönderilen mesajı sabitlemeden kaldır';
  }

  @override
  String get callButtonErrorBusy => 'Başka bir görüşmede meşgul';

  @override
  String get callButtonErrorCallFailed => 'Arama başlatılamadı';

  @override
  String get callButtonErrorNotMember => 'Bu odanın üyesi değilsin';

  @override
  String get callButtonErrorGeneric => 'Arama başlatılamadı';

  @override
  String get callButtonAlreadyOnCall => 'Zaten bir görüşmedesin';

  @override
  String get callButtonBusyElsewhere => 'Başka bir cihazda görüşme sürüyor';

  @override
  String get callButtonVoiceCallTooltip => 'Sesli arama';

  @override
  String get callButtonVideoCallTooltip => 'Görüntülü arama';

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
  String get childSetupScreenWaitingPillAskedLabel => 'İstendi';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'ÜYE';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'Tümünü gör ($count)';
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
      'Son mesaj az önce';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'Son mesaj $hours saat önce';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'Son mesaj dün';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'Son mesaj $days gün önce';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'Son mesaj bir süre önce';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'Geri al';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return '$contactName’ı $childName’dan geri mi alalım?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'Artık birbirlerine ulaşamazlar, sohbetleri de bununla birlikte silinir.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'Artık birbirlerine ulaşamazlar. $contactName bundan haberdar edilmez.';
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
      'İkisi için de silinir, fotoğraflar ve sesli notlar dahil. Bu geri alınamaz.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ayrıca $count oda paylaşıyorlar',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'Bunlar kalır. Onları çıkarmak istersen aşağıdaki Odalar listesinden odayı geri al.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'Geri al ve sil';

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
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => 'İptal';

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
  String get groupCallBannerJoinButtonLabel => 'Katıl';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'Odaya katıl';

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
  String get groupCallBannerPasswordFieldLabel => 'Şifre';

  @override
  String get groupCallBannerPasswordHint => 'Parola';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Katıl';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'Katıl';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Vazgeç';

  @override
  String get groupCallBannerCancelButtonLabel => 'Vazgeç';

  @override
  String get viewOnceViewerBadgeLabel => 'Tek seferlik';

  @override
  String get socialButtonDividerOr => 'veya';

  @override
  String get socialButtonGoogleContinue => 'Google ile Devam Et';

  @override
  String get discoverListsPeopleTitle => 'Arkadaşların';

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
  String get discoverListsFilterHint => 'Arkadaşlarını filtrele';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Filtreyi temizle';

  @override
  String get discoverListsNoOneYet => 'Henüz kimse yok';

  @override
  String discoverListsNoMatches(Object query) {
    return '\"$query\" ile eşleşen kimse yok';
  }

  @override
  String get discoverListsRoomsTitle => 'Odaların';

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
  String get discoverListsFilterRoomsHint => 'Odalarını filtrele';

  @override
  String get discoverListsNoRoomsYet => 'Henüz oda yok';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return '\"$query\" ile eşleşen oda yok';
  }

  @override
  String get discoverListsVoiceCallLabel => 'SESLİ ARAMA';

  @override
  String get discoverListsVideoCallLabel => 'GÖRÜNTÜLÜ ARAMA';

  @override
  String get approvalGateAlreadyAskedLabel => 'Zaten soruldu';

  @override
  String get approvalGateAskGrownUpLabel => 'Büyüğe sor';

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
  String get approvalGateAskButton => 'Sor';

  @override
  String get approvalGateNotNowButton => 'ŞİMDİ DEĞİL';

  @override
  String get approvalGateOkButton => 'Tamam';

  @override
  String get approvalGateWaitingPillLabel => 'Büyük onayı bekleniyor';

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
  String get reportSheetUpdateRequiredTitle => 'Güncelleme gerekli';

  @override
  String get reportSheetUpdateAvailableTitle => 'Güncelleme mevcut';

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
  String get reportSheetUpdateButtonTitle => 'Güncelle';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'TestFlight’ı açar';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'App Store’u açar';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'Google Play’i açar';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'İndirme sayfasını açar';

  @override
  String get reportSheetUpdateActionReloads => 'Yeni sürümle yeniden yükler';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Sonra';

  @override
  String get reportSheetUpdateLaterButton => 'Sonra';

  @override
  String get roomFilterBarAllChipLabel => 'Tümü';

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
    return 'Yanıtlıyorsun: $name';
  }

  @override
  String get roomCardLockedBadge => 'Kilitli';

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
  String get roomCardMessagesFadeLabel => 'Mesajlar kayboluyor';

  @override
  String get roomCardEnterLabel => '↗ Gir';

  @override
  String get roomCardBlockedScreenTitle => 'ENGELLENENLER';

  @override
  String get roomCardBlockedEmptyState => 'henüz kimseyi engellemedin.';

  @override
  String get roomCardUnblockButton => 'ENGELİ KALDIR';

  @override
  String get attachmentMenuPhotoLabel => 'Fotoğraf';

  @override
  String get attachmentMenuVideoLabel => 'Video';

  @override
  String get attachmentMenuCameraLabel => 'Kamera';

  @override
  String get attachmentMenuVoiceLabel => 'Ses';

  @override
  String get attachmentMenuFileLabel => 'Dosya';

  @override
  String get attachmentMenuConnectionRetrying => 'Yeniden deneniyor…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'Sunucuya ulaşılamıyor · Yeniden denemek için dokun';

  @override
  String get attachmentMenuConnectionReconnecting => 'Yeniden bağlanıyor…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Bağlantıyı yeniden dene';

  @override
  String get roomGridTileEmptyLastMessage => 'şimdilik sessiz';

  @override
  String get roomGridTileMemberCountLabel => 'İçeride';

  @override
  String get roomGridTileThemeChipLabel => 'TEMA';

  @override
  String get bulkActionBarCancelLabel => 'İptal';

  @override
  String get bulkActionBarSelectMessagesLabel => 'Mesaj seç';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count seçildi';
  }

  @override
  String get bulkActionBarForwardLabel => 'İlet';

  @override
  String get bulkActionBarDeleteLabel => 'Sil';

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
  String get bulkActionBarBlockSheetNotNotifiedNote => 'Haberi olmayacak.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'Şu an arkadaşsınız — engellemek arkadaşlığı sonlandırır, yani tekrar bağlanmak için yeni bir arkadaşlık isteği göndermen gerekir.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'Aramalarında karşına çıkmaz ve sana mesaj atamaz.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'Engelle';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return '$name engellensin mi?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Onlarla $count oda paylaşıyorsun',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'Bu odalara dokunulmaz. İstersen her birinden kendi ayarlarından ayrılabilirsin.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'Engelle';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'Arkadaşlığı kaldırır ve engeller. Mevcut sohbet geçmişi arşivinde kalır.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'Aramalarda gizlenir ve sana ulaşamaz.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'Engelle ve DM’yi sil';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'Ayrıca onlarla olan DM’ini de siler — tüm mesajlar, tepkiler ve medya dosyaları yok olur.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'İptal';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'İptal';

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
  String get reactionBubblePickerTitle => 'Tepki ver';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'Henüz son kullanılan yok';

  @override
  String get reactionBubbleSearchHint => 'Emoji ara';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'Eşleşme yok';

  @override
  String get reactionBubbleSearchBackSemanticLabel => 'Emojilere dön';

  @override
  String get reactionBubblePasswordHint => 'şifre';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return '$roomName odasına katılmak';
  }

  @override
  String get enterPublicRoomAskFailedMessage => 'Şu an soramadık — tekrar dene';

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
  String get feedBoardHighlightsLabel => 'Öne çıkanlar';

  @override
  String get feedBoardHighlightsEmpty => 'Bugün henüz bir şey yakalanmadı';

  @override
  String get feedBoardPuzzleLabel => 'BULMACA';

  @override
  String get feedBoardPuzzleEmpty => 'bugünün bulmacası henüz hazır değil';

  @override
  String get feedBoardStandingsLabel => 'Hayat puanı';

  @override
  String get feedBoardStandingsEmpty => 'Bugün tabloda puan yok';

  @override
  String get feedBoardActivityLabel => 'Etkinlik';

  @override
  String get feedBoardActivityEmpty => 'bugün şimdilik sessiz';

  @override
  String get feedBoardActivityNoFriends =>
      'Bir arkadaş ekle, günü burada görünsün';

  @override
  String get feedBoardLoadFailed => 'Pano yüklenemedi — birazdan tekrar dene';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'Herkese açık';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'Özel';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'Katıldın';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'Geçici · $duration';
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
  String get roomInfoSheetNoDescription => 'Henüz açıklama yok';

  @override
  String get roomInfoSheetCreatedLabel => 'Oluşturuldu';

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
      'Kurtarma ifadesi oluştur';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'Kurtarma ifaden yok — bir daha giremeyebilirsin.';

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
  String get reportProblemRowValue => 'Ayrıntıları bize gönder';

  @override
  String get reportProblemIntro =>
      'Neyin yanlış gittiğini anlat. Uygulama ve cihaz bilgilerin, uygulamanın o sırada ne yaptığını gösteren teknik bir kayıtla birlikte otomatik olarak eklenir — nedeni bulmamıza yardımcı olan şey bu.';

  @override
  String get reportProblemDescribeLabel => 'Ne oldu';

  @override
  String get reportProblemDescribeHint =>
      'Ekran titriyor, düğmeler yanıt vermiyor';

  @override
  String get reportProblemScreenshotsLabel => 'Ekran görüntüleri';

  @override
  String get reportProblemAddScreenshot => 'Ekran görüntüsü ekle';

  @override
  String get reportProblemDetailsLabel => 'Bilgilerin';

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
      'Rapor gönderilemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String get reportProblemTooMany =>
      'Kısa süre içinde çok fazla rapor gönderdin. Biraz sonra tekrar dene.';

  @override
  String get reportProblemShakeTitle => 'Sorun bildirilsin mi?';

  @override
  String get reportProblemShakeBody =>
      'Telefonunu salladın. Rapor ekranı açılsın mı?';

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
  String get glassKnobLabelFrost => 'Buzlanma';

  @override
  String get glassKnobHintFrost =>
      'Camın üzerinde ne kadar beyazlık olduğu. Azalt, şeffaflaşsın';

  @override
  String get glassKnobLabelBlur => 'Bulanıklık';

  @override
  String get glassKnobHintBlur => 'Üst uçta buzlu, alt uçta duru cam';

  @override
  String get glassKnobLabelSaturation => 'Renk sızması';

  @override
  String get glassKnobHintSaturation =>
      'Renklerin bulanıklıktan ne kadarının kurtulduğu. 2’den sonra posterize olur';

  @override
  String get glassKnobLabelRimOpacity => 'Kenarlık';

  @override
  String get glassKnobHintRimOpacity =>
      'Vurgu rengindeki kenar çizgisi. Kenarlıksız yüzey için sıfırla';

  @override
  String get glassKnobLabelRimWidth => 'Kenarlık kalınlığı';

  @override
  String get glassKnobHintRimWidth => 'O çizginin kalınlığı';

  @override
  String get glassKnobLabelShadowOpacity => 'Gölge';

  @override
  String get glassKnobHintShadowOpacity =>
      'Yüzeyin arkasındakinden ne kadar yukarıda süzüldüğü';

  @override
  String get glassKnobLabelShadowBlur => 'Gölge yayılımı';

  @override
  String get glassKnobHintShadowBlur =>
      'Yumuşak ve geniş, ya da sıkı ve keskin';

  @override
  String get glassKnobLabelShadowY => 'Gölge düşüşü';

  @override
  String get glassKnobHintShadowY => 'Yüzeyin ne kadar altına düştüğü';

  @override
  String get glassKnobLabelBarMargin => 'Yan boşluk';

  @override
  String get glassKnobHintBarMargin =>
      'Çubukla ekranın kenarı arasındaki boşluk';

  @override
  String get glassKnobLabelBarBottom => 'Alt boşluk';

  @override
  String get glassKnobHintBarBottom => 'Çubuğun alttan ne kadar yükseldiği';

  @override
  String get glassKnobLabelShellPadH => 'Uç boşluğu';

  @override
  String get glassKnobHintShellPadH =>
      'Çubuğun kenarından ilk kapsüle kadar. Küçük tut, yoksa uçlar yalnız kalır';

  @override
  String get glassKnobLabelShellPadV => 'Üst boşluk';

  @override
  String get glassKnobHintShellPadV =>
      'Çubuğun kenarından kapsülün üstüne kadar';

  @override
  String get glassKnobLabelIndicatorInset => 'Kapsül girintisi';

  @override
  String get glassKnobHintIndicatorInset =>
      'Seçim kapsülünün kendi bölmesinin ne kadar içinde durduğu';

  @override
  String get glassKnobLabelSegmentPadV => 'Satır boşluğu';

  @override
  String get glassKnobHintSegmentPadV =>
      'İkonun ve etiketinin üstündeki ve altındaki boşluk';

  @override
  String get glassKnobLabelIconLabelGap => 'İkon boşluğu';

  @override
  String get glassKnobHintIconLabelGap =>
      'Bir ikonla altındaki kelime arasındaki boşluk';

  @override
  String get glassKnobLabelIconSize => 'İkon boyutu';

  @override
  String get glassKnobLabelLabelSize => 'Etiket boyutu';

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
  String get settingsScreenValueMotionSystemFull => 'Cihazla aynı · Tam';

  @override
  String get settingsScreenValueMotionSystemCalm => 'Cihazla aynı · Sakin';

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
  String get momentRailCaptureLabel => 'Yakala';

  @override
  String get momentRailYouLabel => 'Sen';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String get momentTagFate => 'Tesadüf';

  @override
  String get momentTagJinx => 'Kerizlik';

  @override
  String get momentTagLuck => 'Şans';

  @override
  String get momentTagCalledIt => 'Demiştim';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'Ne tesadüf';

  @override
  String get momentTagJinxHint => 'Kendi ettin kendi buldun';

  @override
  String get momentTagLuckHint => 'İşine geldi';

  @override
  String get momentTagCalledItHint => 'Geleceği görmüştün';

  @override
  String get momentTagNpcHint => 'Beyin tamamen kapalı';

  @override
  String get momentComposerTitle => 'Yeni an';

  @override
  String get momentComposerCaptionHint => 'Bir şeyler yaz';

  @override
  String get momentComposerTagPrompt => 'puan mı kazandın? hemen ekle';

  @override
  String get momentComposerCapture => 'Kamera';

  @override
  String get momentComposerLibrary => 'Galeri';

  @override
  String get momentComposerRemovePhoto => 'Fotoğrafı kaldır';

  @override
  String get momentComposerPost => 'Paylaş';

  @override
  String get momentComposerErrorDailyCap =>
      'Bugünlük beş tane oldu — yarına da kalsın';

  @override
  String get momentComposerErrorNotAllowed =>
      'Veli fotoğraf paylaşımını kapatmış';

  @override
  String get momentComposerErrorTooLong => 'Biraz uzun olmuş — kısalt';

  @override
  String get momentComposerErrorEmpty =>
      'Bir fotoğraf ya da birkaç kelime ekle';

  @override
  String get momentComposerErrorGeneric => 'Paylaşılamadı — tekrar dene';

  @override
  String get momentViewerDelete => 'Sil';

  @override
  String get momentViewerDeleteConfirmHeadline => 'Bunu sil?';

  @override
  String get momentViewerDeleteConfirmBody =>
      'Herkesin panosundan ve arşivinden tamamen silinir';

  @override
  String get momentViewerDeleteFailed => 'Silinemedi — tekrar dene';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who bir an paylaştı';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name puan aldı: $tag';
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
  String get puzzleScreenSubtitle => 'Dört sembol, altı hak';

  @override
  String get puzzleSubmit => 'Tahmin';

  @override
  String get puzzleBackspace => 'Son sembolü sil';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'Sembol $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return '$count tahminde çözüldü';
  }

  @override
  String get puzzleFailedTitle => 'Hakkın bitti';

  @override
  String get puzzleAnswerWas => 'Kod şuydu';

  @override
  String get puzzleShare => 'Sonucu kopyala';

  @override
  String get puzzleShareCopied => 'Kopyalandı — bir arkadaşına yapıştır';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'Bugünkünü zaten çözdün';

  @override
  String get puzzleErrorOutOfGuesses => 'Bugün hakkın kalmadı';

  @override
  String get puzzleErrorGeneric => 'Tahmin gönderilemedi — tekrar dene';

  @override
  String get puzzleScoreboardLabel => 'Bugünün skorları';

  @override
  String get puzzleScoreboardEmpty => 'Bugün henüz kimse bitirmedi';

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
  String get momentComposerVideo => 'Video';

  @override
  String get momentComposerErrorTooBig => 'Bu video çok büyük — en fazla 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => 'Bir an paylaştın';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'Puan aldın: $tag';
  }

  @override
  String pointLineSelf(Object tag) {
    return 'Sen · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'Ne oldu?';

  @override
  String get pointComposerNoteHint => 'Yukarıdan birini seç, sonra anlat';

  @override
  String get pointComposerAdd => 'Puan ekle';

  @override
  String get pointComposerAddPhoto => 'fotoğraf ekle';

  @override
  String get pointsBoardAdd => 'Puan ekle';

  @override
  String get pointsExplainerOpen => 'Bu ne?';

  @override
  String get pointsExplainerTitle => 'Puan oyunu';

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
  String get pointsExplainerGotIt => 'Anladım';

  @override
  String get momentTagFateExample => 'Başka ülkede dişçime rastladım';

  @override
  String get momentTagJinxExample =>
      'Arabayı yıkadım, saat dörtte yağmur yağdı';

  @override
  String get momentTagLuckExample => 'Treni iki saniyeyle yakaladım';

  @override
  String get momentTagCalledItExample => 'Devam filmi batar demiştim, battı';

  @override
  String get momentTagNpcExample => 'Garsona ‘sen de’ dedim';

  @override
  String feedBoardEditionHint(Object number) {
    return 'Akışın $number. günü';
  }

  @override
  String get feedBoardHighlightsHint => 'bakmaya değer fotoğraflar ve videolar';

  @override
  String get profileVisibilityScreenPointsLabel => 'puanlarım';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'kaydettiğin puanların arkadaşlarının panosunda görünüp görünmeyeceği';

  @override
  String get momentComposerEditPhoto => 'Kırpmayı düzenle';

  @override
  String get archiveScreenTitle => 'Arşivin';

  @override
  String get archiveScreenEnd => 'Hepsi bu kadar';

  @override
  String get archiveScreenEmptyTitle => 'Henüz bir şey saklanmadı';

  @override
  String get archiveScreenEmptyBody =>
      'Anlar bir gün sonra arkadaşlarının panosundan gider, ama burada sende kalır.';

  @override
  String get archiveScreenEmptyFriendTitle => 'Burada bir şey yok';

  @override
  String get archiveScreenEmptyFriendBody =>
      'Henüz görebileceğin bir şey paylaşmamış.';

  @override
  String get archiveScreenPrivateTitle => 'Geçmişi gizli';

  @override
  String get archiveScreenPrivateBody =>
      'Bugün paylaştıklarını yine de görebilirsin.';

  @override
  String get archiveScreenNotFriendTitle => 'Arkadaş değilsiniz';

  @override
  String get archiveScreenNotFriendBody =>
      'Yalnızca bir arkadaşının günlerine geri bakabilirsin.';

  @override
  String get archiveScreenErrorTitle => 'Yüklenemedi';

  @override
  String get archiveScreenErrorBody => 'Bağlantını kontrol edip tekrar dene.';

  @override
  String get feedBoardOpenArchive => 'Arşiv';

  @override
  String get feedBoardGamesLabel => 'Oyunlar';

  @override
  String get feedBoardGamesOpen => 'Tüm oyunlar';

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
  String get gamesLoadFailed => 'Bugünün oyunları yüklenemedi';

  @override
  String get gamesRetry => 'Tekrar dene';

  @override
  String get gameQueensName => 'Kraliçeler';

  @override
  String get gameQueensRule =>
      'Her satır, sütun ve renkte bir taç — asla bitişik değil';

  @override
  String get gameTangoName => 'Tango';

  @override
  String get gameTangoRule => 'üç güneş, üç ay, asla art arda üç tane';

  @override
  String get gameZipName => 'Zip';

  @override
  String get gameZipRule => 'her kareden geçen tek bir çizgi, sayılar sırayla';

  @override
  String get gameSudokuName => 'Mini sudoku';

  @override
  String get gameSudokuRule =>
      'her satır, sütun ve kutuda 1\'den 6\'ya birer kez';

  @override
  String get gameCodeName => 'Şifre';

  @override
  String get gameStatusUnplayed => 'Oynanmadı';

  @override
  String get gameStatusUnfinished => 'Devam ediyor';

  @override
  String get gameStatusGaveUp => 'Pes etti';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'Duraklat';

  @override
  String get gameResume => 'Devam et';

  @override
  String get gamePausedTitle => 'Duraklatıldı';

  @override
  String get gamePausedBody => 'Sayaç durdu, tahta gizlendi';

  @override
  String get gameUndo => 'Geri al';

  @override
  String get gameClear => 'temizle';

  @override
  String get gameHint => 'İpucu';

  @override
  String get gameNotes => 'notlar';

  @override
  String get gameErase => 'sil';

  @override
  String get gameAutoCross => 'Otomatik çarpı';

  @override
  String get gameGiveUp => 'Pes et';

  @override
  String get gameGiveUpTitle => 'Cevabı göster?';

  @override
  String get gameGiveUpBody =>
      'Bugünün tahtası kapanır ve çözülmemiş olarak kaydedilir.';

  @override
  String get gameGiveUpCancel => 'Devam et';

  @override
  String get gameGiveUpConfirm => 'Göster';

  @override
  String gameSolvedTitle(Object time) {
    return '$time içinde çözüldü';
  }

  @override
  String get gameGaveUpTitle => 'Bugünün cevabı';

  @override
  String get gameFirstInToday => 'Bugünün ilki';

  @override
  String gameRankLine(Object place, Object total) {
    return 'Şimdilik $total kişi içinde $place.';
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
  String get gameStandingsLabel => 'Bugünün süreleri';

  @override
  String get gameStandingsEmpty => 'Bunu henüz kimse bitirmedi';

  @override
  String get gameShare => 'Sonucu kopyala';

  @override
  String get gameShareCopied => 'Kopyalandı — bir arkadaşına yapıştır';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => 'Tüm oyunlar';

  @override
  String get gameElapsedSemantic => 'Geçen süre';

  @override
  String get gameErrorNotSolved => 'Bu tahta henüz bitmedi';

  @override
  String get gameErrorAlreadyFinished => 'Bugünkünü zaten bitirdin';

  @override
  String get gameErrorNoHint => 'Bunda ipucu yok';

  @override
  String get gameErrorGeneric => 'Oyunlara ulaşılamadı — tekrar dene';

  @override
  String get gameInfoOpen => 'Nasıl oynanır';

  @override
  String get gameInfoLabel => 'Nasıl oynanır';

  @override
  String get gameInfoRulesLabel => 'Kurallar';

  @override
  String get gameInfoControlsLabel => 'Kontroller';

  @override
  String get gameInfoScoringTimed =>
      'Tahta ekrandayken sayaç işler, duraklattığında ya da çıktığında durur. En hızlı olan bugünün listesinde başa geçer.';

  @override
  String get gameInfoScoringGuesses =>
      'Puan, süreye göre değil kaç denemede bildiğine göre verilir.';

  @override
  String get gameInfoSameForEveryone => 'Bugün herkese aynı tahta geliyor.';

  @override
  String get gameInfoQueensGoal =>
      'Her satıra, sütuna ve renge birer taç yerleştir.';

  @override
  String get gameInfoQueensRule1 =>
      'Sekiz taç: her satırda bir, her sütunda bir.';

  @override
  String get gameInfoQueensRule2 =>
      'Her renk bloğunda da tam olarak bir taç bulunur.';

  @override
  String get gameInfoQueensRule3 => 'İki taç birbirine değemez — köşeden bile.';

  @override
  String get gameInfoQueensControls =>
      'Bir kareye bir kez dokun çarpı, tekrar dokun taç, bir daha dokun boş.';

  @override
  String get gameInfoTangoGoal => 'Izgarayı güneşler ve aylarla doldur.';

  @override
  String get gameInfoTangoRule1 =>
      'Her satır ve sütunda üç güneş, üç ay bulunur.';

  @override
  String get gameInfoTangoRule2 =>
      'Art arda üç aynı olamaz, ne yatay ne dikey.';

  @override
  String get gameInfoTangoRule3 =>
      'İki kare arasındaki = aynı, × farklı demektir.';

  @override
  String get gameInfoTangoControls =>
      'Kareye dokun güneş, tekrar dokun ay, bir daha dokun boş. Basılı kareler değişmez.';

  @override
  String get gameInfoZipGoal => 'Her kareden geçen tek bir çizgi çiz.';

  @override
  String get gameInfoZipRule1 => '1\'den başla, son sayıda bitir.';

  @override
  String get gameInfoZipRule2 => 'Yol boyunca sayılara sırayla uğra.';

  @override
  String get gameInfoZipRule3 => 'Her kare tam olarak bir kez kullanılır.';

  @override
  String get gameInfoZipControls =>
      'Parmağını sürükleyerek çiz. Çizginin üstünden geri gel, silinsin.';

  @override
  String get gameInfoSudokuGoal => 'Izgarayı 1\'den 6\'ya rakamlarla doldur.';

  @override
  String get gameInfoSudokuRule1 => 'Her satırda 1\'den 6\'ya birer kez.';

  @override
  String get gameInfoSudokuRule2 => 'Her sütunda da aynısı.';

  @override
  String get gameInfoSudokuRule3 => 'Ve her 2x3 kutuda da.';

  @override
  String get gameInfoSudokuControls =>
      'Önce bir kareye, sonra bir rakama dokun. Aynı rakama tekrar dokunursan silinir. Notlar modunda küçük kurşun kalem işaretleri yazılır.';

  @override
  String get gameInfoCodeGoal => 'Gizli dört sembollü şifreyi çöz.';

  @override
  String get gameInfoCodeRule1 =>
      'Altı deneme, ve şifrede hiçbir sembol tekrarlanmaz.';

  @override
  String get gameInfoCodeRule2 => 'Yeşil, doğru sembol doğru yerde demek.';

  @override
  String get gameInfoCodeRule3 => 'Sarı, doğru sembol yanlış yerde demek.';

  @override
  String get gameInfoCodeControls =>
      'Sembollere dokunarak bir tahmin kur ve gönder. Tahta ne kadar yaklaştığını söyler.';

  @override
  String get savedMessagesTitle => 'Kaydedilmiş Mesajlar';

  @override
  String homeScreenNoSearchResults(Object query) {
    return '\"$query\" ile eşleşen sohbet yok';
  }

  @override
  String get pullRevealSearchHint => 'Sohbet ara';

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
  String get archivedChatsSheetTitle => 'Arşivlenen sohbetler';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'Arşivlenen sohbetler · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'Artık arşivlenen yok';

  @override
  String get pinnedBadgeLabel => 'SABİTLİ';

  @override
  String get chatRowActionMenuPinLabel => 'Sohbeti sabitle';

  @override
  String get chatRowActionMenuUnpinLabel => 'Sabitlemeyi kaldır';

  @override
  String get chatRowActionMenuArchiveLabel => 'Sohbeti arşivle';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'Arşivden çıkar';

  @override
  String get messageActionMenuSaveLabel => 'Kaydet';

  @override
  String get messageActionMenuUnsaveLabel => 'Kaydı kaldır';

  @override
  String get roomScreenSaveLimitSnack =>
      'Burada çok fazla kayıt var — önce birini kaldır';

  @override
  String get roomScreenSaveFailedSnack => 'Kaydedilemedi';

  @override
  String get threadOverlaySaveLimitToast =>
      'Burada çok fazla kayıt var — önce birini kaldır';

  @override
  String get threadOverlaySaveFailedToast => 'Kaydedilemedi';

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
  String get muteSheetTitle => 'Sohbeti sessize al';

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
  String get muteSheetDurationLabel => 'Ne kadar süreyle';

  @override
  String get muteDurationHour => '1 saat';

  @override
  String get muteDurationEightHours => '8 saat';

  @override
  String get muteDurationWeek => '1 hafta';

  @override
  String get muteDurationAlways => 'Süresiz';

  @override
  String get muteSheetConfirmButton => 'Sessize al';

  @override
  String get muteSheetSaveButton => 'Kaydet';

  @override
  String get muteSheetUnmuteButton => 'Sesi aç';

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
  String get chatRowActionMenuMuteLabel => 'Sohbeti sessize al';

  @override
  String get chatRowActionMenuUnmuteLabel => 'Sohbetin sesini aç';

  @override
  String get roomInfoScreenMuteLabel => 'SESSİZE ALMA';

  @override
  String get roomInfoScreenNotMutedRow => 'Sessize alınmadı';

  @override
  String get attachmentMenuLocationLabel => 'Konum';

  @override
  String get locationSheetSendCurrent => 'Mevcut konumu gönder';

  @override
  String get locationSheetSendCurrentDetail => 'Şu anda bulunduğun yer';

  @override
  String get locationSheetLiveHeading => 'Canlı paylaş';

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
      'Nerede olduklarını paylaşabilirler, 8 saate kadar canlı olarak da';

  @override
  String get childPolicyScreenLocationOffDesc =>
      'Nerede olduklarını paylaşamazlar';

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
  String get videoNoteMessagePlayLabel => 'Video notunu oynat';

  @override
  String get videoNoteMessagePauseLabel => 'Video notunu duraklat';

  @override
  String get videoNoteMessageLoadingLabel => 'Video notu yükleniyor';

  @override
  String get videoNoteMessageUnavailableLabel => 'Video notu kullanılamıyor';

  @override
  String get videoNoteMessageRetryLabel => 'Video notunu yeniden dene';

  @override
  String get videoNoteMessageRetryHint => 'Yeniden denemek için dokun';

  @override
  String get videoNoteMessageDiscardLabel => 'Video notunu sil';

  @override
  String get attachmentMenuVideoNoteLabel => 'Video notu';

  @override
  String get cameraScreenPhotoModeLabel => 'Fotoğraf';

  @override
  String get cameraScreenVideoModeLabel => 'Video';

  @override
  String get cameraScreenStartRecordingLabel => 'Kaydı başlat';

  @override
  String get cameraScreenStopRecordingLabel => 'Kaydı durdur';

  @override
  String get cameraScreenVideoFailedSnack => 'Bu video kaydedilemedi.';

  @override
  String get scheduleSheetTitle => 'Mesajı zamanla';

  @override
  String get scheduleSheetSubtitle =>
      'Şimdi yaz. Sen ne zaman dersen o zaman gitsin.';

  @override
  String get scheduleSheetWhenLabel => 'Ne zaman';

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
  String get scheduleSheetConfirmButton => 'Zamanla';

  @override
  String get scheduleSheetSaveButton => 'Kaydet';

  @override
  String scheduleSendsAtSentence(String when) {
    return '$when gönderilecek';
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
  String get scheduleTimePickerTitle => 'Tarih ve saat seç';

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
  String get scheduledListTitle => 'Zamanlanmış';

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
  String get scheduleEditTitle => 'Mesajı düzenle';

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
  String get scheduledListShowAs => 'Nasıl gösterilsin';

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
  String get serverScreenSubtitle => 'Hesabının ve mesajlarının durduğu yer';

  @override
  String get serverOnboardingTitle => 'Bir sunucu seç.';

  @override
  String get serverOnboardingSubtitle =>
      'Bu sürüm sunucusuz geldi — kendi sunucunu göster';

  @override
  String get serverStatusConnected => 'Bağlı';

  @override
  String get serverStatusDisconnected => 'Bağlı değil';

  @override
  String get serverBadgeDefault => 'Varsayılan';

  @override
  String get serverBadgeSelfHosted => 'Kendi sunucun';

  @override
  String get serverNoneConfigured => 'Henüz sunucu yok';

  @override
  String get serverActiveNowLabel => 'Kullanımda';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'Bu uygulamayla birlikte gelen sunucu.';

  @override
  String get serverChoiceOwn => 'Kendi sunucun';

  @override
  String get serverChoiceOwnSub => 'Kendi işlettiğin bir Convex arka ucu.';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => 'Yapıştır';

  @override
  String get serverProblemMalformed => 'Bu bir web adresi değil.';

  @override
  String get serverProblemBadScheme => 'https:// veya http:// ile başlat.';

  @override
  String get serverProblemNoHost =>
      'https:// sonrasına sunucunun adresini yaz.';

  @override
  String get serverProblemCredentials =>
      'Adresteki kullanıcı adı ve parolayı çıkar.';

  @override
  String get serverInsecureTitle => 'Şifrelenmemiş';

  @override
  String get serverInsecureBody =>
      'Telefonlar şifresiz http’yi engeller; bu adres iOS’ta da Android’de de bağlanmaz. https kullan ya da sunucuna bir tünel üzerinden ulaş.';

  @override
  String get serverTestCta => 'Bağlantıyı sına';

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
  String get serverConnectCta => 'Bağlan';

  @override
  String get serverConnectAnywayCta => 'Yine de bağlan';

  @override
  String get serverAlreadyConnectedCta => 'Zaten bağlı';

  @override
  String get serverUseDefaultCta => 'Varsayılan sunucuyu kullan';

  @override
  String get serverChangeCta => 'Sunucuyu değiştir';

  @override
  String get serverAdvancedLabel => 'Gelişmiş';

  @override
  String get serverSiteUrlExplain =>
      'Çoğu sunucu her şeyi tek adresten yanıtlar. Bunu yalnızca sunucun HTTP eylemlerini başka bir adreste sunuyorsa doldur.';

  @override
  String get serverSiteUrlHint => 'Yukarıdakiyle aynı';

  @override
  String get serverSectionRecent => 'Son kullanılanlar';

  @override
  String get serverRecentForget => 'Bu sunucuyu unut';

  @override
  String get serverSwitchWarningTitle => 'Sunucu değiştirmek oturumu kapatır';

  @override
  String get serverSwitchWarningBody =>
      'Hesaplar ve sohbetler tek bir sunucuya aittir. Bu cihaz oturumu kapatır, indirdiklerini siler ve sıfırdan başlar. İki sunucuda da hiçbir şey silinmez.';

  @override
  String get serverSwitchRolledBackTitle => 'Bağlanılamadı';

  @override
  String serverSwitchRolledBackBody(String host) {
    return '$host yanıt vermedi, bu yüzden hiçbir şey değişmedi. Yeniden giriş yapman gerekecek.';
  }

  @override
  String get serverSwitchStrandedBody =>
      'Hiçbir sunucuya bağlanılamadı. Adresi kontrol edip yeniden dene.';

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
      'Şu an ev sunucusundan yayında. Ayrıntılar için dokun.';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'Kendi sunucun: $server. Ayrıntılar için dokun.';
  }

  @override
  String get serverRoleHomeserverTitle => 'Ev sunucusunda çalışıyor';

  @override
  String get serverRoleHomeserverBody =>
      'MonkeyHub’ı işletenler bir süreliğine trafiği evdeki sunucularına aldı. Her şey aynı şekilde çalışıyor; bu bilinçli bir tercih, arıza değil.';

  @override
  String get serverRoleHomeserverWarnData =>
      'Bu sürede gönderdiklerin, trafik geri alındığında burada olmayabilir.';

  @override
  String get serverRoleHomeserverWarnSpeed =>
      'Ev bağlantısı her zamankinden yavaştır; takılmalar olabilir.';

  @override
  String get serverRoleHomeserverWarnAuto =>
      'Bir şey yapmana gerek yok; uygulama kendiliğinden geri döner.';

  @override
  String get serverRoleSelfHostedTitle => 'Kendi sunucun';

  @override
  String get serverRoleSelfHostedBody =>
      'Bu cihaz senin işlettiğin bir sunucuya bağlı. Ayarlar › Gelişmiş › Sunucu bölümünden değiştirebilirsin.';

  @override
  String get serverValueHomeserver => 'Şimdilik ev sunucusu';

  @override
  String get serverChoiceCloudSubHomeserver =>
      'Bir süreliğine ev sunucusundan yayında.';

  @override
  String get serverDirectiveChangedToast =>
      'Sunucun değişti. Yeniden bağlanılıyor…';

  @override
  String get loginScreenSignInWithPhone => 'sign in with your phone';

  @override
  String get loginScreenUsePasswordInstead => 'Bunun yerine şifre kullan';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      'Telefonunda MonkeyHub’ı aç, profiline git, “Giriş için tara”ya dokun ve kamerayı buraya tut — ya da aşağıdaki kodu yaz.';

  @override
  String get deviceLoginScreenWaiting => 'Onay bekleniyor…';

  @override
  String get deviceLoginScreenApproved => 'Onaylandı — giriş yapılıyor…';

  @override
  String get deviceLoginScreenDenied => 'Giriş isteği telefonunda reddedildi';

  @override
  String get deviceLoginScreenGenericError =>
      'Bir şeyler ters gitti — yeni bir kod dene';

  @override
  String get profileScreenScanToSignInLabel => 'Giriş için tara';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro =>
      'Kameranı bilgisayarında görünen koda tut ya da kodu aşağıya yaz.';

  @override
  String get deviceLoginScanScreenScanButtonLabel => 'Kodu tara';

  @override
  String get deviceLoginScanScreenConfirmTitle =>
      'Bu cihazda giriş yapılsın mı?';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return '$deviceInfo senin hesabınla giriş yapmak istiyor. Yalnızca şu an bunu yapan sensen onayla.';
  }

  @override
  String get deviceLoginScanScreenApproveButton => 'Onayla';

  @override
  String get deviceLoginScanScreenDenyButton => 'Reddet';

  @override
  String get deviceLoginScanScreenSuccess => 'Diğer cihazında giriş yapıldı';

  @override
  String get deviceLoginScanScreenGenericError => 'Onaylanamadı — tekrar dene';

  @override
  String get authErrorDeviceLoginInvalid => 'Bu kod doğru değil.';

  @override
  String get authErrorDeviceLoginExpired =>
      'Bu kodun süresi doldu — diğer cihazdan yenisini al.';

  @override
  String get deviceLoginScanScreenDeniedConfirmation =>
      'Giriş isteği reddedildi';

  @override
  String get roomAdminRoleAdmin => 'Yönetici';

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
  String get roomAdminTransferConfirmCta => 'Devret';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return '$name çıkarılsın mı?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'Gruba ve içindeki her şeye erişimi biter. Yeniden davet edilebilir ya da davet bağlantısıyla geri gelebilir.';

  @override
  String get roomAdminRemoveConfirmCta => 'Çıkar';

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
  String get roomInviteCreateButton => 'Bağlantı oluştur';

  @override
  String get roomInviteRegenerateButton => 'Yeni bağlantı';

  @override
  String get roomInviteRevokeButton => 'Bağlantıyı iptal et';

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
  String get roomInviteRegenerateConfirm => 'Yeni bağlantı';

  @override
  String get roomInviteRevokeHeadline => 'Bu bağlantı iptal edilsin mi?';

  @override
  String get roomInviteRevokeBody =>
      'Yenisini yapana kadar kimse bağlantıyla katılamaz. Grupta olanlar grupta kalır.';

  @override
  String get roomInviteRevokeConfirm => 'İptal et';

  @override
  String get roomInviteLimitsLabel => 'Sınırlar';

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
  String get roomInvitePermissionsLabel => 'İzinler';

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
    return 'Bitiş $date';
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
  String get roomInviteFriendsInviteButton => 'Davet et';

  @override
  String get roomInviteFriendsSent => 'Davet edildi';

  @override
  String get roomInviteFriendsEmpty =>
      'Arkadaşlarının hepsi ya burada ya da çoktan davet edildi.';

  @override
  String get roomInviteFriendsNoMatch => 'Buna uyan arkadaş yok.';

  @override
  String get roomInviteFriendsDone => 'Tamam';

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
  String get roomInfoScreenInviteAwaitingGuardian => 'Ebeveyn bekleniyor';

  @override
  String get roomInfoScreenInviteWithdraw => 'GERİ AL';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return '$inviter davet etti · $members üye';
  }

  @override
  String get roomInvitationCardJoin => 'Katıl';

  @override
  String get discoverScreenJoinByCodeTitle => 'Kodla katıl';

  @override
  String get discoverScreenJoinByCodeSubtitle => 'Birinin paylaştığı grubu aç';

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
  String get joinInviteLookupButton => 'Devam';

  @override
  String get joinInviteLookupFailed =>
      'Kod kontrol edilemedi. Bağlantını kontrol edip tekrar dene.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count üye';
  }

  @override
  String get joinInviteJoinButton => 'Gruba katıl';

  @override
  String get joinInviteRequestButton => 'Katılmak iste';

  @override
  String get joinInviteOpenNote =>
      'Katıldığında grubun mesajlarını görebileceksin.';

  @override
  String get joinInviteApprovalNote =>
      'Buradaki hiçbir şeyi görebilmen için önce bir yöneticinin evet demesi gerekiyor.';

  @override
  String get joinInviteOpenRoom => 'Grubu aç';

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
  String get roomAdminYouSuffix => 'Sen';

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
  String get newChatMenuJoinSub => 'Seninle paylaşılan grubu aç';

  @override
  String get shareSheetTitle => 'Şuna gönder';

  @override
  String get shareSheetSuggestedHeading => 'Önerilen';

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
  String get attachmentMenuPollLabel => 'Anket';

  @override
  String get attachmentMenuChecklistLabel => 'Liste';

  @override
  String get attachmentMenuEventLabel => 'Etkinlik';

  @override
  String get interactionKindPoll => 'Anket';

  @override
  String get interactionKindQuiz => 'Test';

  @override
  String get interactionKindChecklist => 'Liste';

  @override
  String get interactionKindEvent => 'Etkinlik';

  @override
  String get interactionBadgeAnonymous => 'Gizli';

  @override
  String get interactionBadgeMultiple => 'Çoklu';

  @override
  String get interactionBadgeClosed => 'Kapandı';

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
  String get interactionRespondentsTitlePoll => 'Kimler oy verdi';

  @override
  String get interactionRespondentsTitleChecklist => 'Kimler işaretledi';

  @override
  String get interactionRespondentsTitleEvent => 'Kimler yanıtladı';

  @override
  String get interactionRespondentsFailed =>
      'Kimlerin yanıtladığı yüklenemedi.';

  @override
  String get interactionRespondentsEmpty => 'Henüz kimse yanıtlamadı.';

  @override
  String get interactionFilterAll => 'Tümü';

  @override
  String get interactionRsvpGoing => 'Geliyorum';

  @override
  String get interactionRsvpMaybe => 'Belki';

  @override
  String get interactionRsvpNo => 'Gelemem';

  @override
  String get interactionComposePollTitle => 'Yeni anket';

  @override
  String get interactionComposePollTagline => 'Odaya sor';

  @override
  String get interactionComposeChecklistTitle => 'Yeni liste';

  @override
  String get interactionComposeChecklistTagline =>
      'Herkesin işaretlediği liste';

  @override
  String get interactionComposeEventTitle => 'Yeni etkinlik';

  @override
  String get interactionComposeEventTagline => 'Kimler geliyor gör';

  @override
  String get interactionComposeQuestionLabel => 'Soru';

  @override
  String get interactionComposeQuestionHint => 'Ne soruyorsun?';

  @override
  String get interactionComposeTitleLabel => 'Başlık';

  @override
  String get interactionComposeTitleHint => 'Bu liste ne için?';

  @override
  String get interactionComposeEventNameLabel => 'Etkinlik';

  @override
  String get interactionComposeEventNameHint => 'Ne oluyor?';

  @override
  String get interactionComposeOptionsLabel => 'Seçenekler';

  @override
  String get interactionComposeItemsLabel => 'Maddeler';

  @override
  String interactionComposeOptionHint(int index) {
    return '$index. Seçenek';
  }

  @override
  String interactionComposeItemHint(int index) {
    return '$index. Madde';
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
  String get interactionComposeMultipleTitle => 'Çoklu yanıt';

  @override
  String get interactionComposeMultipleSub => 'Birden fazla seçilebilir';

  @override
  String get interactionComposeAnonymousTitle => 'Gizli';

  @override
  String get interactionComposeAnonymousOffSub =>
      'Kimin oy verdiğini herkes görür';

  @override
  String get interactionComposeAnonymousOnSub =>
      'Kimin oy verdiğini kimse görmez';

  @override
  String get interactionComposeQuizTitle => 'Test modu';

  @override
  String get interactionComposeQuizSub => 'Tek doğru yanıt, değiştirmek yok';

  @override
  String get interactionComposeExplanationLabel => 'Açıklama';

  @override
  String get interactionComposeExplanationHint =>
      'Yanıtladıktan sonra görünür (isteğe bağlı)';

  @override
  String get interactionComposeOthersMayCheckTitle => 'Herkes işaretleyebilir';

  @override
  String get interactionComposeOthersMayCheckSub => 'Sadece sen değil';

  @override
  String get interactionComposeOthersMayAddTitle => 'Herkes ekleyebilir';

  @override
  String get interactionComposeOthersMayAddSub => 'Liste sonradan uzayabilir';

  @override
  String get interactionComposeWhenLabel => 'Ne zaman';

  @override
  String get interactionComposePickStart => 'Başlangıcı seç';

  @override
  String get interactionComposePickEnd => 'Bitiş ekle (isteğe bağlı)';

  @override
  String get interactionComposePlaceLabel => 'Yer';

  @override
  String get interactionComposePlaceHint => 'Nerede? (isteğe bağlı)';

  @override
  String get interactionComposeSendPoll => 'Anketi gönder';

  @override
  String get interactionComposeSendChecklist => 'Listeyi gönder';

  @override
  String get interactionComposeSendEvent => 'Etkinliği gönder';

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
  String get messageReceiptsScreenTitle => 'Mesaj bilgisi';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$total kişiden $read kişi okudu';
  }

  @override
  String get messageReceiptsEmptyState => 'Bu odada henüz başka kimse yok';

  @override
  String get messageReceiptsSectionRead => 'Okundu';

  @override
  String get messageReceiptsSectionDelivered => 'İletildi';

  @override
  String get messageReceiptsSectionSent => 'Gönderildi';

  @override
  String get messageReceiptsSectionHidden => 'Bilgi yok';

  @override
  String get messageReceiptsStateHidden => 'Paylaşılmıyor';

  @override
  String get messageReceiptsStateWaiting => 'Bekliyor';

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
      'Tek seferlik indirme, sen kaldırana kadar durur';

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
  String get companionSectionGeneral => 'Genel';

  @override
  String get companionSectionStorage => 'Depolama';

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
  String get companionRemoveConfirm => 'Kaldır';

  @override
  String get sebastianEnableLabel => 'Sebastian çeviri yapsın';

  @override
  String get sebastianEnableDetail => 'İndirmeyi silmeden durdurmak için kapat';

  @override
  String get sebastianLanguageSection => 'Şu dile çevir';

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
  String get marloweBrainsSection => 'Beyin';

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
  String get messageActionMenuTranslateLabel => 'Çevir';

  @override
  String get messageActionMenuShowOriginalLabel => 'Orijinali göster';

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
    return 'Zaten $language dilinde';
  }

  @override
  String get roomScreenTranslateRoomOffer =>
      'Sohbetin geri kalanı da çevrilsin mi?';

  @override
  String get roomScreenTranslateRoomOfferAction => 'Hepsini çevir';

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
  String get companionBrainInUse => 'Kullanımda';

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
  String get messageActionMenuTranslateAgainLabel => 'Yeniden çevir';

  @override
  String get groupCallScreenShareLabel => 'Paylaş';

  @override
  String get groupCallScreenStopShareLabel => 'Paylaşımı durdur';

  @override
  String get groupCallScreenShareStartingLabel => 'Başlıyor…';

  @override
  String get groupCallScreenRingingLabel => 'Çalıyor…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name ekranını paylaşıyor';
  }

  @override
  String get groupCallScreenYouAreSharing => 'Ekranını paylaşıyorsun';

  @override
  String get groupCallScreenMinimizeLabel => 'Gizle';

  @override
  String get groupCallScreenDrawLabel => 'Çiz';

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
  String get gameTellFriends => 'Arkadaşlara söyle';

  @override
  String get gameToldFriends => 'Söylendi';

  @override
  String get gameTellFriendsTitle => 'Arkadaşlarına söylensin mi?';

  @override
  String get gameTellFriendsBody =>
      'bu sonuçla bir bildirim alıyorlar. yalnızca bir kez gönderilebilir.';

  @override
  String get gameTellFriendsCancel => 'Şimdi olmaz';

  @override
  String get gameTellFriendsConfirm => 'Gönder';

  @override
  String get gameTellFriendsSent => 'Gönderildi — haberleri var';

  @override
  String get gameTellFriendsPrivate =>
      'Günlük skorların gizli, kimse bunu göremezdi';

  @override
  String get gameTellFriendsFailed => 'Gönderilemedi';

  @override
  String get settingsScreenFriendActivityLabel => 'ARKADAŞ HAREKETLERİ';

  @override
  String get settingsScreenFriendActivityOnBody =>
      'arkadaşların paylaştıkça kareler, puanlar ve oyun sonuçları';

  @override
  String get settingsScreenFriendActivityOffBody =>
      'hiçbir şey — panoları baktığında yine orada';

  @override
  String get searchScreenActionWithGrownUp => 'Bir büyükte';

  @override
  String get newChatMenuSearchHint => 'Arkadaşlarında ara';

  @override
  String get newChatMenuNoFriendsYet =>
      'Henüz arkadaş yok — Keşfet’ten birilerini bul';

  @override
  String get newChatMenuNoFriendsMatch => 'Eşleşen arkadaş yok';

  @override
  String get newChatMenuOpenDmFailed => 'O sohbet açılamadı — tekrar dene';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'Kendi kişilerinden seç';

  @override
  String get childPolicyScreenPickPersonHint => 'Ad veya kullanıcı adı ara';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'Arkadaşlarından eklenecek kimse kalmadı —\\nbaşkasını aratabilirsin';

  @override
  String get childPolicyScreenPickPersonNoMatch => 'Eşleşen kimse yok';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'Arkadaşların';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'Diğer herkes';

  @override
  String get childPolicyScreenAddRoomLabel => 'Oda ekle';

  @override
  String get childPolicyScreenPickRoomHeading => 'Oda ekle';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'Kendi odalarından biri. $name hemen katılır; sen geri alana kadar orada okuyup yazabilir.';
  }

  @override
  String get childPolicyScreenPickRoomHint => 'Odalarında ara';

  @override
  String get childPolicyScreenPickRoomEmpty => 'Eklenecek başka odan kalmadı';

  @override
  String get childPolicyScreenPickRoomNoMatch => 'Eşleşen oda yok';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name artık $room odasında';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'O oda eklenemedi — tekrar dene';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'O oda bu şekilde eklenemez';

  @override
  String get childPolicyScreenErrorRoomGone => 'O oda artık yok';

  @override
  String get newChatMenuFriendsHeader => 'Arkadaşlar';

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
  String get roomChangeRequestsClearedValue => 'Hiçbir şey — kaldır';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name önerdi';
  }

  @override
  String get roomAdminChangeRequestsRow => 'Öneriler';

  @override
  String get roomInfoScreenSuggestNote =>
      'Bunu bir yöneticinin onaylaması gerek';

  @override
  String get roomInfoScreenSuggestAvatarNote =>
      'Yeni fotoğrafları yöneticiler onaylar';

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
  String get roomInfoScreenSuggestionPending => 'Yönetici bekleniyor';

  @override
  String get roomInfoScreenSuggestionWithdraw => 'Geri al';

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
  String get roomSuggestionBannerReview => 'İncele';

  @override
  String get roomSuggestionBannerSemantic =>
      'İncelemeni bekleyen üye önerileri';

  @override
  String get gameInfoPlay => 'Oyna';

  @override
  String get gameInfoContinue => 'Devam et';

  @override
  String get gameInfoSeeResult => 'Sonucunu gör';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return '$total kişiden $delivered kişiye iletildi';
  }

  @override
  String get messageReceiptsSentLabel => 'Gönderildi';

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
  String get messageReceiptsStampRead => 'Okundu';

  @override
  String get messageReceiptsStampDelivered => 'İletildi';

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
  String get recordsLabel => 'Tüm zamanlar';

  @override
  String get recordsBlurb => 'Şimdiye kadarki en iyiler — sen ve arkadaşların';

  @override
  String recordsYourBest(Object value) {
    return 'Seninki $value';
  }

  @override
  String get recordsNoneYet => 'Henüz kimse';

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
  String get recordsReactFailed => 'Tepki verilemedi';

  @override
  String get recordsLoadFailed => 'Rekorlar yüklenemedi';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game: rekor $value, $name';
  }

  @override
  String get appearanceLabel => 'Görünüm';

  @override
  String get appearanceMatchDevice => 'Cihaza uy';

  @override
  String get appearanceMatchDeviceSub =>
      'Gündüz açık, gece koyu — telefonunla birlikte';

  @override
  String get appearanceOneTheme => 'Tek tema';

  @override
  String get appearanceOneThemeSub => 'Gün boyu aynı görünüm';

  @override
  String get appearanceLightSlot => 'Açık mod';

  @override
  String get appearanceDarkSlot => 'Koyu mod';

  @override
  String get appearanceNow => 'Şu an';

  @override
  String appearanceAutoValue(Object name) {
    return 'Otomatik · $name';
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
  String get dropHintNoTarget => 'Göndermek için bir sohbetin üzerine bırak';

  @override
  String get dropNothingToSend => 'Burada gönderilebilecek bir şey yok';

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
  String get dropSendText => 'Mesaja ekle';

  @override
  String get dropSendLink => 'Bağlantıyı ekle';

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
  String get dropNoticeFolder => 'Klasörler gönderilemez';

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
  String get dropNoticeNotAllowed => 'Burada ek gönderilemez';

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
  String get expressionOptionsHint => 'Seçenekleri göster';

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

  @override
  String get expressionPackStore => 'Çıkartma paketleri';

  @override
  String get expressionPackSearchHint => 'Çıkartma paketlerinde ara';

  @override
  String get expressionPacksAdded => 'Eklenenler';

  @override
  String get expressionPacksMore => 'Diğer paketler';

  @override
  String get expressionPackAdd => 'Ekle';

  @override
  String get expressionPackRemove => 'Kaldır';

  @override
  String expressionPackStickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count çıkartma',
      one: '1 çıkartma',
    );
    return '$_temp0';
  }

  @override
  String get expressionNoPacksFound => 'Eşleşen paket yok';

  @override
  String get expressionAllPacksAdded => 'Tüm paketleri ekledin.';

  @override
  String expressionPackReorder(String title) {
    return '$title sırasını değiştir';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return '“$title” paketini ekle';
  }

  @override
  String expressionPackAddedToast(String title) {
    return '“$title” çıkartmalarına eklendi';
  }

  @override
  String get expressionPacksFromKlipy => 'KLIPY’den daha fazla çıkartma';

  @override
  String expressionSearchKlipyFor(String query) {
    return 'KLIPY’de “$query” ara';
  }

  @override
  String get expressionHideKeyboard => 'Klavyeyi gizle';

  @override
  String get expressionSearchStickers => 'Çıkartma ara';

  @override
  String get expressionYourStickers => 'Çıkartmaların';

  @override
  String get chatListYesterday => 'Dün';

  @override
  String get roomLayoutScreenCardsLayoutLabel => 'KARTLAR';

  @override
  String get roomLayoutScreenCardsLayoutDescription =>
      'her oda kendi kartında, her ayrıntı açıkça yazılı.';

  @override
  String get homeScreenTitle => 'Sohbetler';

  @override
  String get glassScreenNativeLabel => 'iOS Liquid Glass';

  @override
  String get glassScreenNativeOnBody =>
      'Sekme çubuğunu iOS\'un kendisi çizer. Aşağıdaki ayarlar uygulamanın geri kalanını düzenler.';

  @override
  String get glassScreenNativeOffBody =>
      'MonkeyHub camı her yerde kendisi çizer; aşağıdaki ayarlarla düzenlenir.';

  @override
  String get glassScreenHeading => 'Cam';

  @override
  String get glassStyleHeader => 'Stil';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody =>
      'Apple\'ın kendi camı, iOS tarafından çizilir. Uygulamadaki düğmeler de ona uyar.';

  @override
  String get glassStyleFrostedTitle => 'Buzlu';

  @override
  String get glassStyleFrostedBody =>
      'MonkeyHub\'ın kendi camı. Her ayarı kendin şekillendir.';

  @override
  String get glassStyleRecommended => 'Önerilen';

  @override
  String get glassStyleLiquidFooter =>
      'Ayarlanacak bir şey yok: bulanıklığı, tonu ve ışığı iOS belirler. Camı kendin şekillendirmek için Buzlu\'yu seç.';

  @override
  String get acctSectionPrivacy => 'Gizlilik';

  @override
  String get acctSectionAccount => 'Hesap';

  @override
  String get acctSectionFamily => 'Aile';

  @override
  String get acctSectionThisPhone => 'Bu telefon';

  @override
  String get acctRowVisibility => 'Profil görünürlüğü';

  @override
  String get acctRowBlocked => 'Engellenen kullanıcılar';

  @override
  String get acctRowApprovals => 'Onaylar';

  @override
  String get acctNothingWaiting => 'Bekleyen yok';

  @override
  String get acctRowLinked => 'Bağlı hesaplar';

  @override
  String get acctRowScanToSignIn => 'Giriş için tara';

  @override
  String get acctRowSetUpRecovery => 'Kurtarma ifadesi oluştur';

  @override
  String get acctRowChangeRecovery => 'Kurtarma ifadesini değiştir';

  @override
  String get acctSignOut => 'Çıkış yap';

  @override
  String get acctDeleteAccount => 'Hesabı sil';

  @override
  String get acctConfirmDelete => 'Silmek için tekrar dokun';

  @override
  String get acctHandPhoneBack => 'Bu telefonu geri ver';

  @override
  String get acctMyGrownUps => 'Büyüklerim';

  @override
  String get acctActionMessage => 'Mesaj';

  @override
  String get acctActionAddFriend => 'Ekle';

  @override
  String get acctActionRequested => 'İstendi';

  @override
  String get acctActionAccept => 'Kabul et';

  @override
  String get acctActionNotAccepting => 'Kapalı';

  @override
  String get acctActionUnfriend => 'Çıkar';

  @override
  String get acctActionBlock => 'Engelle';

  @override
  String get acctActionReport => 'Bildir';

  @override
  String get acctStatusFriends => 'Arkadaşsınız';

  @override
  String get acctStatusRequestSent => 'İstek gönderildi';

  @override
  String get acctStatusWantsToConnect => 'Arkadaş olmak istiyor';

  @override
  String get acctStatusNotConnected => 'Bağlı değilsiniz';

  @override
  String get acctPresenceOnline => 'Çevrimiçi';

  @override
  String get acctPresenceAway => 'Uzakta';

  @override
  String get acctPresenceOffline => 'Çevrimdışı';

  @override
  String get acctProfilePhoto => 'Profil fotoğrafı';

  @override
  String get acctSaveToPhotos => 'Fotoğraflar\'a kaydet';

  @override
  String get acctTakeSelfie => 'Selfie çek';

  @override
  String get acctChooseFromLibrary => 'Arşivden seç';

  @override
  String get acctCancel => 'Vazgeç';

  @override
  String get acctSave => 'Kaydet';

  @override
  String get acctChange => 'Değiştir';

  @override
  String get acctNotNow => 'Şimdi değil';

  @override
  String get acctAddEmail => 'E-posta ekle';

  @override
  String get acctEditNameTitle => 'Adı düzenle';

  @override
  String get acctAddNameTitle => 'Adını ekle';

  @override
  String get acctEditEmailTitle => 'E-postayı düzenle';

  @override
  String get acctChangeUsernameTitle => 'Kullanıcı adı değişsin mi?';

  @override
  String get onboardingLookTitle => 'Sana göre olsun';

  @override
  String get onboardingLookBody =>
      'Bir görünüm seç. İstediğin zaman Ayarlar\'dan değiştirebilirsin.';

  @override
  String get onboardingEssentials => 'Temel';

  @override
  String get onboardingEssentialsSub => 'Sade ve doğal';

  @override
  String get onboardingCharacters => 'Karakterli';

  @override
  String get onboardingCharactersSub => 'Aynı uygulama, daha çok kişilik';

  @override
  String get onboardingLightMode => 'Açık mod';

  @override
  String get onboardingDarkMode => 'Koyu mod';

  @override
  String get onboardingNow => 'Şu an';

  @override
  String get onboardingContinue => 'Devam';

  @override
  String get onboardingIconTitle => 'Uygulama simgen';

  @override
  String get onboardingIconBody =>
      'Simgeni koru, temana uymasına izin ver ya da istediğin bir simgeyi seç.';

  @override
  String get onboardingIconIosNote =>
      'iOS, simge her değiştiğinde kısa bir bildirim gösterir.';

  @override
  String get onboardingGetStarted => 'Başlayalım';

  @override
  String get appIconMatchTheme => 'Temaya uy';

  @override
  String get appIconCurrent => 'Mevcut';

  @override
  String get appIconSectionCollection => 'MonkeyHub koleksiyonu';

  @override
  String get appIconSectionThemes => 'Tema simgeleri';

  @override
  String get appIconScreenTitle => 'Uygulama simgesi';

  @override
  String get appIconMatchFooter =>
      'Temaya uy seçeneği simgeyi koyu mod temanla birlikte değiştirir; böylece gün içinde sürekli değişmez.';

  @override
  String get loginTitleReturning => 'Tekrar hoş geldin';

  @override
  String get loginTitleFirst => 'MonkeyHub\'a hoş geldin';

  @override
  String get loginTitleSignUp => 'Hesabını oluştur';

  @override
  String get loginTitleReset => 'Şifreni sıfırla';

  @override
  String get loginSubtitleSignIn =>
      'Kaldığın yerden devam etmek için giriş yap.';

  @override
  String get loginSubtitleFirst =>
      'Giriş yap ya da birkaç saniyede hesap oluştur.';

  @override
  String get loginSubtitleSignUp => 'Bir kullanıcı adı ve şifre yeterli.';

  @override
  String get loginSubtitleReset =>
      '12 kelimelik kurtarma ifadeni gir ve yeni bir şifre seç.';

  @override
  String get loginCtaSignIn => 'Giriş yap';

  @override
  String get loginCtaSignUp => 'Hesap oluştur';

  @override
  String get loginCtaReset => 'Şifreyi sıfırla';

  @override
  String get loginNoAccountPrompt => 'Yeni misin? ';

  @override
  String get loginCreateAccountLink => 'Hesap oluştur';

  @override
  String get loginHaveAccountPrompt => 'Hesabın var mı? ';

  @override
  String get loginSignInLink => 'Giriş yap';

  @override
  String get loginForgotPassword => 'Şifreni mi unuttun?';

  @override
  String get loginChildAccount => 'Çocuk hesabı kur';

  @override
  String get loginBackToSignIn => 'Girişe dön';

  @override
  String get loginWithPhone => 'Telefonunla giriş yap';

  @override
  String get loginUsernameField => 'Kullanıcı adı';

  @override
  String get loginPasswordField => 'Şifre';

  @override
  String get loginConfirmPasswordField => 'Şifreyi onayla';

  @override
  String get loginNameField => 'Ad (isteğe bağlı)';

  @override
  String get loginRecoveryPhraseField => '12 kelimelik kurtarma ifaden';

  @override
  String get loginNewPasswordField => 'Yeni şifre';

  @override
  String get roomHeaderStatusOnline => 'Çevrimiçi';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count üye',
      one: '$count üye',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => 'Ayarlar';

  @override
  String get settingsHubAccountHintAdult =>
      'Profil, aile, bağlı hesaplar ve gizlilik';

  @override
  String get settingsHubAccountHintChild => 'Profil, gizlilik ve büyüklerin';

  @override
  String get settingsHubSectionGeneral => 'Genel';

  @override
  String get settingsHubSectionNotifications => 'Bildirimler';

  @override
  String get settingsHubSectionCalls => 'Aramalar';

  @override
  String get settingsHubSectionAppearance => 'Görünüm';

  @override
  String get settingsHubSectionCompanions => 'Yoldaşlar';

  @override
  String get settingsHubSectionChats => 'Sohbetler';

  @override
  String get settingsHubSectionHelp => 'Yardım ve yasal';

  @override
  String get settingsHubSectionAdvanced => 'Gelişmiş';

  @override
  String get settingsHubLanguage => 'Dil';

  @override
  String get settingsHubCheckForUpdates => 'Güncellemeleri denetle';

  @override
  String get settingsHubUpdateAvailable => 'Güncelleme var';

  @override
  String get settingsHubShowLinkUrls => 'Bağlantı adreslerini göster';

  @override
  String get settingsHubShowLinkUrlsSubtitle =>
      'Her bağlantı önizlemesinin yanında adresi yaz';

  @override
  String get settingsHubPush => 'Anlık bildirimler';

  @override
  String get settingsHubPushSubtitle => 'Yeni mesajlar, aramalar ve istekler';

  @override
  String get settingsHubGameReminders => 'Günlük oyun hatırlatıcısı';

  @override
  String get settingsHubGameRemindersSubtitle =>
      'Oynamadıysan öğle vakti bir hatırlatma';

  @override
  String get settingsHubFriendActivity => 'Arkadaş etkinliği';

  @override
  String get settingsHubFriendActivitySubtitle =>
      'Arkadaşlarından öne çıkanlar, puanlar ve oyun sonuçları';

  @override
  String get settingsHubMenuBar => 'Menü çubuğu simgesi';

  @override
  String get settingsHubMenuBarSubtitle =>
      'Okunmamış sayısını menü çubuğunda gösterir';

  @override
  String get settingsHubCallStats => 'Arama istatistiklerini göster';

  @override
  String get settingsHubCallStatsSubtitle =>
      'Arama sırasında çözünürlük, bit hızı ve ping';

  @override
  String get settingsHubTheme => 'Tema';

  @override
  String get settingsHubAppIcon => 'Uygulama simgesi';

  @override
  String get settingsHubGlass => 'Cam';

  @override
  String get settingsHubNavigation => 'Gezinme';

  @override
  String get settingsHubMotion => 'Hareket';

  @override
  String get settingsHubChatList => 'Sohbet listesi';

  @override
  String get settingsHubChatStyle => 'Sohbet stili';

  @override
  String get settingsHubBubbleStyle => 'Baloncuk stili';

  @override
  String get settingsHubSpeakerColors => 'Konuşan renkleri';

  @override
  String get settingsHubReplyStyle => 'Yanıt stili';

  @override
  String get settingsHubPrivacyPolicy => 'Gizlilik politikası';

  @override
  String get settingsHubTerms => 'Hizmet koşulları';

  @override
  String get settingsHubLicence => 'Lisans';

  @override
  String get settingsHubServer => 'Sunucu';

  @override
  String get settingsHubLayoutRows => 'Satırlar';

  @override
  String get settingsHubLayoutCards => 'Kartlar';

  @override
  String get settingsHubLayoutGrid => 'Izgara';

  @override
  String get settingsHubNavTabBar => 'Sekme çubuğu';

  @override
  String settingsHubThemeAuto(String name) {
    return 'Otomatik · $name';
  }

  @override
  String get chatListPageRowsSub =>
      'Bir yüz, bir isim ve son mesaj; Mesajlar\'daki gibi.';

  @override
  String get chatListPageCardsSub =>
      'Her oda kendi kartında, her ayrıntı açıkça yazılı.';

  @override
  String get chatListPageGridSub =>
      'İki sütun kutucuk. Bir bakışta daha çok oda.';

  @override
  String get chatListPageLayoutHeader => 'Düzen';

  @override
  String get chatListPageFiltersHeader => 'Filtreler';

  @override
  String get chatListPageChips => 'Çipler';

  @override
  String get chatListPageChipsSub =>
      'Her zaman bir dokunuş uzakta bir filtre sırası.';

  @override
  String get chatListPageButton => 'Düğme';

  @override
  String get chatListPageButtonSub =>
      'İstediğinde filtreleri açan tek bir düğme.';

  @override
  String get chatListPageEmptyHeader => 'Boş odalar';

  @override
  String get chatListPagePlain => 'Sade';

  @override
  String get chatListPagePlainSub => 'Henüz konuşulmamış bir oda sade kalır.';

  @override
  String get chatListPageInitial => 'Baş harf';

  @override
  String get chatListPageInitialSub =>
      'Büyük, soluk bir harf boş köşeyi doldurur.';

  @override
  String get chatListPageEmptyFooter => 'Izgara düzeninde geçerlidir.';

  @override
  String get chatStylePageFooter =>
      'Sohbetin başlığı ve mesaj alanının nasıl çizildiği.';

  @override
  String get chatStyleClassicSub => 'Dolu bir başlık ve düz bir mesaj alanı.';

  @override
  String get chatStyleCompactSub =>
      'Buzlu kontroller sohbetin üzerinde süzülür.';

  @override
  String get bubbleTailedSub =>
      'Her serinin son mesajında bir kuyruk; Mesajlar\'daki gibi.';

  @override
  String get bubbleSoftSub => 'Kuyruk yok. Seri köşeleriyle bir arada durur.';

  @override
  String get bubblePillSub => 'Her mesajda tamamen yuvarlak kapsüller.';

  @override
  String get bubbleSlabSub => 'Köşeli omuzlar: keskin ve kararlı.';

  @override
  String get replyStylePageFooter =>
      'Bir yanıtın, cevap verdiği mesajı nasıl gösterdiği.';

  @override
  String get replyClassicSub =>
      'Mesajın üstünde renkli bir alıntı; WhatsApp tarzı.';

  @override
  String get replyPhantomSub =>
      'Orijinalin bir hayaleti üstte süzülür, bir eğriyle bağlanır.';

  @override
  String get replyStickySub => 'Köşeye tutturulmuş küçük, eğik bir kart.';

  @override
  String get replyComicSub => 'Çizgi roman kuyruklu mini bir baloncuk.';

  @override
  String get motionMatchDevice => 'Cihaza uy';

  @override
  String get motionMatchDeviceCalmSub =>
      'Cihazın şu anda daha az hareket istiyor.';

  @override
  String get motionMatchDeviceFullSub =>
      'Cihazın şu anda animasyona izin veriyor.';

  @override
  String get motionFullSub => 'Her yay, süzülme ve gösteriş.';

  @override
  String get motionCalmSub => 'Süslemeler durur. Gerisi aynı çalışır.';

  @override
  String get navigationPageFooter =>
      'Sohbetler, Akış, Keşfet ve Ayarlar arasında nasıl geçtiğin.';

  @override
  String get navTabBarSub => 'Her zaman görünür, her yere tek dokunuş.';

  @override
  String get navOrbSub =>
      'Köşeden basılı tut ve sürükle. Alıştıkça sevilen bir hareket.';

  @override
  String get languageSystemLabel => 'Cihaz dili';

  @override
  String get languagePageFooter =>
      'Menüler ve uygulama mesajları. Sohbetler, insanlar hangi dilde yazarsa o dilde kalır.';

  @override
  String get speakerPageFooter =>
      'Grup sohbetlerinde kimin konuştuğunu bir bakışta anla.';

  @override
  String get speakerOffSub => 'Herkes aynı mürekkeple yazar.';

  @override
  String get speakerNamesSub => 'Herkesin adında ve yüzünde kendi rengi olur.';

  @override
  String get speakerBubblesSub => 'Renkleri mesajlarına da taşınır.';

  @override
  String get themePageAutoFooter =>
      'Açık temalar açık modda, koyu temalar koyu modda kullanılır.';

  @override
  String get themePageLightMode => 'Açık mod';

  @override
  String get themePageDarkMode => 'Koyu mod';

  @override
  String get themePageEssentials => 'Temeller';

  @override
  String get themePageEssentialsFooter => 'Sakin ve doğal, beş renkte.';

  @override
  String get themePageCharacters => 'Karakterler';

  @override
  String get themePageCharactersFooter =>
      'Aynı düzen, kendine has bir kişilik. Önizlemek için bir temaya basılı tut.';

  @override
  String get themePageLightBadge => 'Açık';

  @override
  String get themePageDarkBadge => 'Koyu';

  @override
  String get themePageInUse => 'Kullanımda';

  @override
  String get themePageUseLight => 'Açık modda kullan';

  @override
  String get themePageUseDark => 'Koyu modda kullan';

  @override
  String themePageUse(String name) {
    return '$name kullan';
  }

  @override
  String get acctCaptureTitle => 'Ekran kaydı koruması';

  @override
  String get acctCaptureOnIos =>
      'Kayıt ve yansıtmada gizlilik perdesi görünür.';

  @override
  String get acctCaptureOnAndroid =>
      'Ekran görüntüleri ve kayıtlar siyah çıkar.';

  @override
  String get acctCaptureOff => 'Ekran görüntüleri ve kayıtlar normal çalışır.';

  @override
  String get acctCaptureFooter =>
      'Kaybolan mesajlı odalarda bu her zaman açıktır.';

  @override
  String get acctActionPending => 'Bekliyor';

  @override
  String get chatSwipePin => 'Sabitle';

  @override
  String get chatSwipeUnpin => 'Sabitlemeyi kaldır';

  @override
  String get chatSwipeMute => 'Sessize al';

  @override
  String get chatSwipeUnmute => 'Sesi aç';

  @override
  String get chatSwipeArchive => 'Arşivle';

  @override
  String get appearanceMatchDeviceSubtitle =>
      'Telefonunla birlikte: gündüz açık, gece koyu';

  @override
  String get appearanceOneThemeSubtitle => 'Gün boyu aynı görünüm';

  @override
  String get riName => 'Ad';

  @override
  String get riDescription => 'Açıklama';

  @override
  String get riVisibility => 'Kimler bulabilir';

  @override
  String get riPublic => 'Herkese açık';

  @override
  String get riPublicSub => 'Herkes Keşfet\'te bulabilir';

  @override
  String get riPrivate => 'Özel';

  @override
  String get riPrivateSub => 'Yalnızca davet ettiklerin katılabilir';

  @override
  String get riMessageLife => 'Mesajlar şu süre sonra kaybolur';

  @override
  String get riPassword => 'Şifre';

  @override
  String get riRemovePassword => 'Şifreyi kaldır';

  @override
  String get riSetPassword => 'Şifre belirle';

  @override
  String get riSharedContent => 'Paylaşılanlar';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count üye',
      one: '1 üye',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count davetli',
      one: '1 davetli',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => 'Geri çek';

  @override
  String get riNotifications => 'Bildirimler';

  @override
  String get riTranslation => 'Çeviri';

  @override
  String get riNameColours => 'İsim renkleri';

  @override
  String get riYouSuggested => 'Önerdiklerin';

  @override
  String get riTakeBack => 'Geri al';

  @override
  String get riLeaveRoom => 'Odadan ayrıl';

  @override
  String get riLeaving => 'Ayrılınıyor…';

  @override
  String get riDeleteRoom => 'Odayı sil';

  @override
  String get riDeleting => 'Siliniyor…';

  @override
  String get riEndConversation => 'Sohbeti sonlandır';

  @override
  String get riEnding => 'Sonlandırılıyor…';

  @override
  String get riActionCall => 'Ara';

  @override
  String get riActionVideo => 'Görüntülü';

  @override
  String get riActionMute => 'Sessize al';

  @override
  String get riActionUnmute => 'Sesi aç';

  @override
  String get riActionMedia => 'Medya';

  @override
  String get riActionAdd => 'Ekle';

  @override
  String get roomHeaderStatusTyping => 'Yazıyor…';

  @override
  String get glassScreenLead => 'Arkadakinin ne kadarının görüneceği.';

  @override
  String get transcriptDayToday => 'Bugün';

  @override
  String get acctRowDevices => 'Cihazlar';

  @override
  String get acctThisDevice => 'Bu cihaz';

  @override
  String get acctRemove => 'Kaldır';

  @override
  String get acctRemoveDeviceTitle => 'Bu cihaz kaldırılsın mı?';

  @override
  String get acctRemoveAllTitle => 'Diğer tüm cihazlar kaldırılsın mı?';

  @override
  String get acctRemoveAll => 'Tümünü kaldır';

  @override
  String get acctActiveNow => 'Şu an etkin';

  @override
  String get acctLoading => 'Yükleniyor…';

  @override
  String get acctDevicesLoadFailed => 'Cihazların yüklenemedi.';

  @override
  String get acctNoNotifications => 'Bildirimler buna ulaşmıyor';

  @override
  String get acctBlockedEmpty => 'Kimseyi engellemedin.';

  @override
  String get acctUnblock => 'Engeli kaldır';

  @override
  String get pvSubtitle =>
      'Başkalarının ne gördüğünü ve sana nasıl ulaşabileceğini belirle.';

  @override
  String get pvSectionProfile => 'Profil';

  @override
  String get pvSectionMessages => 'Mesajlar';

  @override
  String get pvSectionPeople => 'Kişiler';

  @override
  String get pvSectionFeed => 'Akış';

  @override
  String get pvAvatar => 'Profil fotoğrafı';

  @override
  String get pvAvatarDesc => 'Fotoğrafını kimler görebilir';

  @override
  String get pvOnline => 'Çevrimiçi durumu';

  @override
  String get pvOnlineDesc => 'Şu an etkin görünüp görünmediğin';

  @override
  String get pvLastSeen => 'Son görülme';

  @override
  String get pvLastSeenDesc => 'En son ne zaman buralardaydın';

  @override
  String get pvSendReceipts => 'Okundu bilgisi gönder';

  @override
  String get pvSendReceiptsDesc =>
      'Mesajlarını okuduğunda başkaları görebilsin';

  @override
  String get pvShowReceipts => 'Okundu bilgisini göster';

  @override
  String get pvShowReceiptsDesc => 'Mesajlarını kimin okuduğunu gör';

  @override
  String get pvShowReceiptsHint =>
      'Yalnızca okundu bilgisi gönderenler sayılır.';

  @override
  String get pvFriendRequests => 'Arkadaşlık istekleri';

  @override
  String get pvFriendRequestsDesc =>
      'Sana kimler arkadaşlık isteği gönderebilir';

  @override
  String get pvSupervisedTitle => 'Bunları büyüklerin ayarlar';

  @override
  String get pvEveryone => 'Herkes';

  @override
  String get pvFriends => 'Arkadaşlar';

  @override
  String get pvNobody => 'Hiç kimse';

  @override
  String get pvOn => 'Açık';

  @override
  String get pvOff => 'Kapalı';

  @override
  String get pvAnyone => 'Herkes';

  @override
  String get pvHighlights => 'Öne çıkanlarım';

  @override
  String get pvHighlightsDesc =>
      'Fotoğraf ve videolarının günlük olarak arkadaşlarının panolarında görünüp görünmediği';

  @override
  String get pvPuzzle => 'Bulmaca puanım';

  @override
  String get pvPuzzleDesc =>
      'Arkadaşların günlük bulmacada nasıl yaptığını görsün mü';

  @override
  String get pvPast => 'Geçmişim';

  @override
  String get pvPastDesc =>
      'Bugün her zaman arkadaşlarla paylaşılır — bu, öncesini de açar';

  @override
  String get pvPoints => 'Puanlarım';

  @override
  String get pvPointsDesc =>
      'Kaydettiğin puanların arkadaşlarının panolarında görünüp görünmediği';

  @override
  String get roomColorsPageTitle => 'Kim kim';

  @override
  String get roomColorsPageHeader => 'Herkesin konuştuğu renk';

  @override
  String get roomColorsAuto => 'Otomatik';

  @override
  String get roomColorsReset => 'Otomatiğe dön';

  @override
  String get roomColorsOffFooter =>
      'Konuşan renkleri kapalı. Burada açarsan tüm odalarda açılır.';

  @override
  String roomColorsSharedWith(String name) {
    return '$name ile ortak';
  }

  @override
  String get settingsScreenValueReplyQuote => 'Alıntı';

  @override
  String get replyQuoteSub =>
      'Orijinal mesaj, yanıtın balonunun içinde en üstte durur.';

  @override
  String get riTabMedia => 'Fotoğraflar ve videolar';

  @override
  String get riTabFiles => 'Dosyalar';

  @override
  String get riTabVoice => 'Sesli mesajlar';

  @override
  String get riTabLinks => 'Bağlantılar';

  @override
  String get riTabSaved => 'Kaydedilenler';

  @override
  String get riNone => 'Yok';

  @override
  String get riSavedNote =>
      'Kaydettiklerini yalnızca sen görürsün. Sabitlenen mesaj ise tam tersi — tüm oda görür.';

  @override
  String get riOwnerNote => 'Madalya bu odayı kuranı gösterir.';

  @override
  String get famPair => 'Eşleştir';

  @override
  String get famRelease => 'Serbest bırak';

  @override
  String get famSettings => 'Ayarlar';

  @override
  String get famAddChild => 'Çocuk ekle';

  @override
  String get famEmptyTitle => 'Henüz çocuk yok';

  @override
  String get famOnlineNow => 'Şu an çevrimiçi';

  @override
  String get famNotPaired => 'Henüz eşleştirilmedi';

  @override
  String get famJustNow => 'Az önce';

  @override
  String get apprEmptyTitle => 'Bekleyen bir şey yok';

  @override
  String get apprEmptySub => 'Her şey yolunda.';

  @override
  String get apprNotYet => 'Şimdi değil';

  @override
  String get apprAllow => 'İzin ver';

  @override
  String get compGeneral => 'Genel';

  @override
  String get compStorage => 'Depolama';

  @override
  String get compTranslateInto => 'Şu dile çevir';

  @override
  String get compBrain => 'Beyin';

  @override
  String laUnlinkProvider(String provider) {
    return '$provider bağlantısını kaldır';
  }

  @override
  String laLinkProvider(String provider) {
    return '$provider bağla';
  }

  @override
  String get laUnlink => 'Bağlantıyı kaldır';

  @override
  String get laLink => 'Bağla';

  @override
  String get laLinked => 'Bağlı';

  @override
  String get laNotLinked => 'Bağlı değil';

  @override
  String rdSignOut(String name) {
    return '$name hesabından çıkış yap';
  }

  @override
  String get rpContinue => 'Devam';

  @override
  String get rpCopy => 'Kopyala';

  @override
  String get rpSaved => 'Kaydettim';

  @override
  String get rpBack => 'Geri';

  @override
  String get rpKeep => 'Şimdi değil — mevcut ifademi koru';

  @override
  String get childSetupHeadingIos => 'Bu kim?';

  @override
  String get childPairTitleIos => 'Merhaba!';

  @override
  String get childPairBackIos => 'Girişe dön';

  @override
  String get gamesHubTitle => 'Oyunlar';

  @override
  String get gamesHubSubtitle => 'Her gün yeni tahtalar, herkes için aynı.';

  @override
  String get gameTellFriendsMessage =>
      'Bu sonuçla bir bildirim alacaklar. Yalnızca bir kez gönderilebilir.';

  @override
  String get deviceLoginScanTitleIos => 'Giriş için tara';

  @override
  String get deviceLoginConfirmTitleIos => 'Bu cihazda giriş yapılsın mı?';

  @override
  String get socialHeroCreateIos => 'Az kaldı';

  @override
  String get socialHeroLinkIos => 'Tekrar hoş geldin';

  @override
  String socialSignInLinkIos(String provider) {
    return 'Giriş yap ve $provider bağla';
  }

  @override
  String get serverTitleIos => 'Sunucu';

  @override
  String get serverOnboardingTitleIos => 'Bir sunucu seç';

  @override
  String get approvalGateAskIos => 'Sor';

  @override
  String get friendRequestDraftIntroOutgoingSentence =>
      'Birkaç satır yaz. Onaylayabilir ya da reddedebilir.';

  @override
  String get requestDeclineIos => 'Reddet';

  @override
  String get joinRequestAllowIos => 'İzin ver';

  @override
  String get changeRequestUseIos => 'Kullan';

  @override
  String get settingsSearchHint => 'Ara';

  @override
  String settingsSearchNoResults(String query) {
    return '“$query” için sonuç yok';
  }

  @override
  String get settingsSearchAccount => 'Hesap';

  @override
  String get settingsHubDiagnostics => 'Tanılama';

  @override
  String get settingsHubDiagnosticsSubtitle =>
      'Sorun giderme ve hata bildirimi için kayıtlar';

  @override
  String get settingsHubAdvancedFooter =>
      'Sorun giderme ve kendi sunucunu barındırmak için. Günlük kullanımda gerekmez.';

  @override
  String get settingsSearchKwLanguage => 'dil, çeviri, bölge';

  @override
  String get settingsSearchKwUpdates => 'güncelleme, sürüm, yeni';

  @override
  String get settingsSearchKwLinks => 'bağlantı, url, adres, önizleme';

  @override
  String get settingsSearchKwAutoplay => 'gif, animasyon, otomatik oynat';

  @override
  String get settingsSearchKwStickers => 'çıkartma, emoji, öneri';

  @override
  String get settingsSearchKwPush => 'bildirim, uyarı, ses, rozet';

  @override
  String get settingsSearchKwGames => 'oyun, hatırlatıcı, günlük, bulmaca';

  @override
  String get settingsSearchKwFriends => 'arkadaş, etkinlik, puan';

  @override
  String get settingsSearchKwVideo => 'video, arama, kalite, kamera, veri';

  @override
  String get settingsSearchKwStats =>
      'arama istatistikleri, ağ, ping, hata ayıklama';

  @override
  String get settingsSearchKwTheme => 'tema, koyu, açık, renk, gece, görünüm';

  @override
  String get settingsSearchKwIcon => 'uygulama simgesi, logo, ana ekran';

  @override
  String get settingsSearchKwGlass =>
      'cam, liquid glass, bulanıklık, buzlu, şeffaflık';

  @override
  String get settingsSearchKwNavigation => 'sekme çubuğu, gezinme, menü';

  @override
  String get settingsSearchKwMotion => 'hareket, animasyon, hareketi azalt';

  @override
  String get settingsSearchKwCompanions => 'yapay zeka, asistan, çeviri, model';

  @override
  String get settingsSearchKwChatList =>
      'sohbet listesi, satır, kart, ızgara, filtre';

  @override
  String get settingsSearchKwChatStyle => 'sohbet stili, kompakt, klasik';

  @override
  String get settingsSearchKwBubbles => 'baloncuk, mesaj, kuyruk, şekil';

  @override
  String get settingsSearchKwSpeakers => 'isim, renk, grup';

  @override
  String get settingsSearchKwReply => 'yanıt, alıntı, konu';

  @override
  String get settingsSearchKwReport => 'hata, sorun, geri bildirim, destek';

  @override
  String get settingsSearchKwLegal => 'gizlilik, koşullar, yasal, lisans';

  @override
  String get settingsSearchKwServer =>
      'sunucu, kendi sunucun, url, geliştirici';

  @override
  String get settingsSearchKwDiagnostics =>
      'tanılama, kayıt, hata ayıklama, geliştirici';

  @override
  String get settingsSearchKwPrivacy =>
      'gizlilik, görünürlük, son görülme, okundu';

  @override
  String get settingsSearchKwBlocked => 'engellenen, engelle, kişi';

  @override
  String get settingsSearchKwDevices => 'cihaz, oturum, çıkış, telefon';

  @override
  String get settingsSearchKwLinked => 'apple, google, giriş, bağlı';

  @override
  String get settingsSearchKwRecovery =>
      'kurtarma ifadesi, şifre, yedek, unuttum';

  @override
  String get settingsSearchKwCapture =>
      'ekran görüntüsü, ekran kaydı, gizlilik';

  @override
  String get settingsSearchKwFamily => 'aile, çocuk, ebeveyn, onay';

  @override
  String get settingsSearchKwAccount =>
      'hesap, çıkış, sil, e-posta, kullanıcı adı';

  @override
  String get childPolicyScreenContactStateAllowedTalking => 'Konuşuyor';

  @override
  String get childPolicyScreenContactStateTalking => 'Onaylandı';

  @override
  String get childPolicyScreenContactStateAllowedNotAdded => 'Henüz eklenmedi';

  @override
  String get profileScreenSignOutConfirmTitle =>
      'Bu cihazda çıkış yapmak istiyor musun?';

  @override
  String get profileScreenDeleteAccountConfirmTitle => 'Hesabın silinsin mi?';

  @override
  String get profileScreenDeleteAccountConfirmBody =>
      'Mesajların, fotoğrafların, odaların ve arkadaşların silinir; kullanıcı adın başkalarına açılır.';

  @override
  String get glassPresetNameFrosted => 'Buzlu';

  @override
  String get glassPresetNameClear => 'Şeffaf';

  @override
  String settingsScreenDiagnosticsCountdown(int count) {
    return 'Tanılamaya $count dokunuş kaldı…';
  }

  @override
  String pairingCodeTitlePair(String name) {
    return '$name ile eşleştir';
  }

  @override
  String pairingCodeTitleRelease(String name) {
    return '$name cihazını serbest bırak';
  }

  @override
  String archivedChatsSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sohbet',
    );
    return '$_temp0';
  }

  @override
  String pinnedListSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mesaj',
    );
    return '$_temp0';
  }

  @override
  String get voiceRecorderScreenTitle => 'Sesli mesaj';

  @override
  String get chatTargetSearchHint => 'Ara';

  @override
  String get marloweBrainTierSwiftDetail => 'Hızlı yanıtlar, en hafif indirme';

  @override
  String get marloweBrainTierBalancedDetail =>
      'Hız ve derinlik arasında iyi bir denge';

  @override
  String get marloweBrainTierDeepDetail =>
      'En düşünceli olanı, en çok yeri kaplar';

  @override
  String get reportFactDeviceId => 'Cihaz kimliği';

  @override
  String get reportFactUserId => 'Kullanıcı kimliği';

  @override
  String get reportFactUsername => 'Kullanıcı adı';

  @override
  String get reportFactApp => 'Uygulama';

  @override
  String get reportFactDevice => 'Cihaz';

  @override
  String get reportFactSystem => 'Sistem';

  @override
  String get reportFactDisplay => 'Ekran';

  @override
  String get reportFactAppLanguage => 'Uygulama dili';

  @override
  String get reportFactSystemLocale => 'Sistem dili';

  @override
  String get reportFactLog => 'Kayıt';

  @override
  String reportFactLogValue(int count) {
    return '$count olay eklendi';
  }

  @override
  String reportProblemScreenshotN(int n) {
    return 'Ekran görüntüsü $n';
  }

  @override
  String reportProblemRemoveScreenshot(int n) {
    return '$n. ekran görüntüsünü kaldır';
  }

  @override
  String get reportFactLanguageFromSystem => 'sistemden';

  @override
  String get reportFactLanguageChosen => 'elle seçildi';
}
