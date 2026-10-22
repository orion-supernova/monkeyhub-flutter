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
  String get roomScreenAskGrownUpFailedSnack => 'Şu an sorulamadı. Tekrar dene';

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
  String get roomScreenDeleteConfirmBodyOne =>
      'Bu, mesajı sohbetteki herkes için kaldırır. Geri alınamaz.';

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
      'Çok fazla sabitlenmiş mesaj var. Önce birini kaldır';

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
  String get roomReadOnlyFooter =>
      'Bu oda salt okunur. Buraya yalnızca MonkeyHub yazar.';

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
  String get messageBubblePlayOnceLabel => 'Bir kez oynat';

  @override
  String get messageBubblePlayOnceTapToPlay => 'Oynatmak için dokun';

  @override
  String get messageBubblePlayOncePlayed => 'Oynatıldı';

  @override
  String get messageBubblePlayOnceVoiceSemanticLabel =>
      'Bir kez oynatılabilen sesli mesaj, oynatmak için dokun';

  @override
  String get messageBubblePlayOnceVideoNoteSemanticLabel =>
      'Bir kez oynatılabilen video notu, oynatmak için dokun';

  @override
  String get replyIndicatorPlayOnceVoiceLabel =>
      'Sesli mesaj · bir kez oynatılır';

  @override
  String get replyIndicatorPlayOnceVideoNoteLabel =>
      'Video notu · bir kez oynatılır';

  @override
  String get roomScreenPlayOnceVoiceAlreadyPlayed =>
      'Bu sesli mesajı zaten dinledin.';

  @override
  String get roomScreenPlayOnceVoiceGone =>
      'Bu sesli mesaj artık mevcut değil.';

  @override
  String get roomScreenPlayOnceVoiceNetworkError => 'Sesli mesaj yüklenemedi.';

  @override
  String get roomScreenPlayOnceVideoNoteAlreadyPlayed =>
      'Bu video notunu zaten izledin.';

  @override
  String get roomScreenPlayOnceVideoNoteGone =>
      'Bu video notu artık mevcut değil.';

  @override
  String get roomScreenPlayOnceVideoNoteNetworkError =>
      'Video notu yüklenemedi.';

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
  String get profileScreenEmailHint => 'isteğe bağlı, kimseye gösterilmez';

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
      'onlar sana zaten istek göndermiş. İsteklerine bak.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'istek zaten gönderildi.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'bu kullanıcıyı sen engellemiştin. Önce engeli kaldır.';

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
      'Bunu sadece bir yetişkin yapabilir, kodu ya da şifresi gerekiyor.';

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
      'sınırlı görünüm. Arkadaşlarıyla daha fazlasını paylaşıyorlar.';

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
      'Mesaj kutusu, başlıklar, arama düğmeleri: kayan içerik yerine metnin üzerine oturan her şey';

  @override
  String get glassScreenMatchBottomBar => 'Alt çubukla eşleştir';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'Değiştirildi. Yeni bir görünüm olarak kaydet ya da sıfırla';

  @override
  String get glassScreenCustomPresetName => 'Özel';

  @override
  String get glassScreenUnsavedSubtitle =>
      'Kaydedilmedi. Saklamak için bir isim ver';

  @override
  String get glassScreenSaveDialogTitle => 'Bu görünümü farklı kaydet';

  @override
  String get glassScreenNoRoomToast => 'Yer kalmadı. Önce bir görünüm sil';

  @override
  String get glassScreenRenameDialogTitle => 'Yeniden adlandır';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '$name silinsin mi?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'Görünüm ekranda kalmaya devam eder, sadece adını kaybeder.';

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
      'çatı fotoğraflarını attı, kiremitler resmen dağılmış';

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
      'Hâlâ gönderiliyor. Birazdan tekrar dene';

  @override
  String get threadOverlayCopiedToast => 'Kopyalandı';

  @override
  String get threadOverlayNameCopiedToast => 'Ad kopyalandı';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'Koordinatlar kopyalandı';

  @override
  String get threadOverlayPinLimitToast =>
      'Çok fazla sabitlenmiş mesaj var. Önce birini kaldır';

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
    return '$peerName da bu sohbeti kaybeder: her iki tarafta da tüm mesajlar silinir. Bu geri alınamaz.';
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
  String get roomNameReservedError => 'Oda adları dm: ile başlayamaz';

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
      'bu oda korumalı. güvenlik nedeniyle mevcut şifre gösterilmiyor, değiştirmek için yenisini gir.';

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
    return 'Bir daha sorulmayacaksın; ister $childName onları eklesin, ister onlar $childName’ı eklesin.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'Birine izin ver';

  @override
  String get childPolicyScreenAskToAddLabel => 'Ekleme izni iste';

  @override
  String get childPolicyScreenAskToAddOffDesc => 'Sadece aile, yeni istek yok';

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
      'Eklendi. İstek gönderiliyor';

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
      'Hesap silinemedi. Tekrar dene';

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
      'Eklenemedi. Tekrar dene';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'Bu onun kendi kullanıcı adı';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'Bir çocuk yetişkin olamaz';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'Bu işlem olmadı. Tekrar dene';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'Birinin onlara bakması lazım. Önce başka bir yetişkin ekle';

  @override
  String get childPolicyScreenErrorNotYours => 'Bunu değiştirme yetkin yok';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'Bu kullanıcı adında bir hesap yok';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'Bu şifreyle normal bir hesaba dönüşürler, tüm yetişkinler görünürlüğünü tamamen kaybeder. Geri dönüşü yok: normal biri gibi tekrar davet edilmen gerekir.';

  @override
  String get childPolicyScreenGraduateCta => 'Mezun et';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'Her şeyi korurlar ve bir şifre alırlar. Sen tüm görünürlüğünü kaybedersin. Geri alınamaz.';

  @override
  String get childPolicyScreenGraduateDangerLabel => 'Tam hesaba geçir';

  @override
  String get childPolicyScreenGraduateFailed => 'Mezun edilemedi. Tekrar dene';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return '$name mezun olsun';
  }

  @override
  String get childPolicyScreenGraduateHint => 'Onlar için bir şifre';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Bir odayı geri almak, onları da odadan çıkarır. Bir kişiyi geri almak ise sohbeti de siler, ikisi için de.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Buradaki herkes onaylayabilir, ayarları değiştirebilir ve her şeyi görebilir. Herhangi biri tek başına hareket edebilir; kimse diğerini beklemez.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'Eklendi. Artık onlara bakabilirler';

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
      'Buradaki herkes sana tekrar sormadan eklenebilir, kim başlatırsa başlatsın.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Çocuklar için her zaman kapalı. Keşfet (tanımadığın kişilere ait odaların listesi) tamamen gizli ve açılamaz. Birinin onları davet ettiği odalar normal şekilde çalışmaya devam eder.';

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
    return '$name’in tek yetişkini sensin, o yüzden öylece ayrılamazsın. Önce başka birini ekle ya da bunlardan birini kullan.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'Ayrıl';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return '$name’in hesabına dair tüm görünürlüğünü kaybedersin: istekleri, kişileri, odaları. Diğer yetişkinler onlara göz kulak olmaya devam eder.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'Gözetimi bırak';

  @override
  String get childPolicyScreenStopSupervisingHeadline =>
      'Gözetimi bırakmak istiyor musun?';

  @override
  String get childPolicyScreenTakeBackFailed => 'Geri alınamadı. Tekrar dene';

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
      'Henüz bir şey kaydedilmedi. Bir mesaja basılı tut ve Kaydet’i seç.\n\nBurada tuttukların yalnızca sana ait. Sabitlenmiş bir mesajı ise odadaki herkes görür.';

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
      'Spoiler. Gizli metni göstermek için etkinleştir';

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
      'Düzenlemek için çok geç. Mesajlar yalnızca 15 dakika içinde düzenlenebilir.';

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
    return 'AKTİF: $name';
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
  String callScreenStatusCalling(String kind) {
    return '$kind · aranıyor…';
  }

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
  String get callScreenPeerCameraOff => 'Kamera kapalı';

  @override
  String get callScreenPeerCameraPaused => 'Kamera duraklatıldı';

  @override
  String get callScreenControlFlip => 'Çevir';

  @override
  String get callScreenControlSpeaker => 'Hoparlör';

  @override
  String get callAudioControlLabel => 'Ses';

  @override
  String get callAudioSheetTitle => 'Ses';

  @override
  String get callAudioRoutePhone => 'Telefon';

  @override
  String get callAudioRouteHeadphones => 'Kulaklık';

  @override
  String get callAudioRouteBluetooth => 'Bluetooth';

  @override
  String get callAudioRouteCar => 'Araç';

  @override
  String get callAudioRouteOther => 'Diğer cihaz';

  @override
  String get callAudioMicFollowsNote => 'Mikrofon da seçtiğin cihaza geçer.';

  @override
  String get callAudioMicrophoneHeader => 'Mikrofon';

  @override
  String get callAudioUnknownDevice => 'Bilinmeyen cihaz';

  @override
  String get callAudioNoDevices => 'Cihaz bulunamadı';

  @override
  String get callAudioSwitchFailed => 'Ses cihazı değiştirilemedi';

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
      'Bu kullanıcıyı engelledin. Önce engeli kaldır.';

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
  String get discoverScreenYourPeopleLabel => 'Arkadaşlar';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'Henüz kimse yok. Yukarıdan kişi bul';

  @override
  String get discoverScreenNoFriendsYet => 'Henüz kimse yok';

  @override
  String get discoverScreenSearchRoomsTitle => 'Oda ara';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'Herkese açık bir odayı adıyla bul';

  @override
  String get discoverScreenYourRoomsLabel => 'Odalar';

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
  String get searchScreenHintRooms => 'Herkese açık oda ara';

  @override
  String get searchScreenPeoplePromptChild =>
      'Yeni birini bulmak için kullanıcı adını eksiksiz yaz';

  @override
  String get searchScreenPeoplePromptDefault =>
      'kullanıcı adına veya isme göre ara';

  @override
  String get searchScreenNoMatchChild =>
      'Kimse bulunamadı. Yeni biri için kullanıcı adının\ntamamı, harfi harfine gerekiyor';

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
      'Kopyalandı. Güvenli bir yere yapıştır';

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
      'şimdi değil, mevcut ifademi koru';

  @override
  String get homeScreenProfileSemanticLabel => 'Profilin';

  @override
  String homeScreenGreeting(Object name) {
    return 'selam, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'Yeni oda';

  @override
  String get homeScreenEmptyRoomsMessage => 'Henüz oda yok. Birini oluştur';

  @override
  String get groupCallScreenTitleVideo => 'Grup görüntülü arama';

  @override
  String get groupCallScreenTitleVoice => 'Grup sesli arama';

  @override
  String groupCallScreenParticipantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi görüşmede',
      one: 'Sadece sen',
    );
    return '$_temp0';
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
  String get reactionDetailsSheetAddYours => 'Sen de ekle';

  @override
  String get reactionDetailsSheetRemoveYours => 'Seninkini kaldır';

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
  String get audioMessageSwitchToLinkPrompt => 'O hesap benim, giriş yapayım';

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
  String get approvalsScreenErrorGeneric => 'kaydedilemedi, tekrar dene';

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
      'Burada kamera yok. Bunun yerine altı rakamı yaz.';

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
      'Bu dosyanın yalnızca bir kısmı gösteriliyor. Kalanını görmek için indirin.';

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
      'Kod oluşturulamadı. Tekrar dene.';

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
    return '$name’in telefonunda MonkeyHub’ı aç ve bunu tara ya da numaraları yaz.';
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
  String get photoDeckBackToFirst => 'Başa dön';

  @override
  String get inlinePickerCommentHint => 'Yorum ekle veya gönder';

  @override
  String get attachmentMenuGalleryLabel => 'Galeri';

  @override
  String inlinePickerVideoCompressNote(String size) {
    return '$size üstünde, göndermek için sıkıştırılacak';
  }

  @override
  String messageMenuAlbumAll(int count) {
    return 'Tümü ($count)';
  }

  @override
  String get messageMenuAlbumOne => 'Sadece bu';

  @override
  String replyAlbumItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öğe',
      one: '1 öğe',
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
  String get mediaPickFailedMessage => 'Bu açılamadı. Tekrar seçmeyi dene';

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
    return '$name bu telefondan çıkış yapar ve telefon geri teslim edilir. Telefon normal giriş ekranına döner, artık herkes kullanabilir.';
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
      'vurgu renkli alıntı kapsülü, bağlantı çubuğu ve avatarla: WhatsApp’tan aşina olduğun o görünüm.';

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
      'Hesap oluşturulamadı. Tekrar dene.';

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
      'Geri kalan herkes için önce senin onayın gerekir: hem onun eklemek istediği kişiler, hem de onu eklemek isteyenler için.';

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
      'kuyruk yok. Bir seri yalnızca sıkışan iç köşeleriyle bir arada durur.';

  @override
  String get bubbleStyleScreenPillLabel => 'KAPSÜL';

  @override
  String get bubbleStyleScreenPillDescription =>
      'tamamen yuvarlak kapsüller, her satırda birbirinin aynısı.';

  @override
  String get bubbleStyleScreenSlabLabel => 'BLOK';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'köşeli omuzlar: keskin, baskı gibi, kararlı.';

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
  String get discoverListsPeopleTitle => 'Arkadaşlar';

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
  String get discoverListsFilterHint => 'Arkadaş ara';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Filtreyi temizle';

  @override
  String get discoverListsNoOneYet => 'Henüz kimse yok';

  @override
  String discoverListsNoMatches(Object query) {
    return '\"$query\" ile eşleşen kimse yok';
  }

  @override
  String get discoverListsRoomsTitle => 'Odalar';

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
  String get discoverListsFilterRoomsHint => 'Odalarında ara';

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
      'şikayetler gizlidir, karşı taraf bilgilendirilmez.';

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
  String get reportSheetUpdateActionInstallsInApp =>
      'Uygulamadan çıkmadan yükler';

  @override
  String get reportSheetUpdateActionRestarts =>
      'Yükler ve uygulamayı yeniden başlatır';

  @override
  String reportSheetUpdateDownloading(int percent) {
    return 'Güncelleme indiriliyor… %$percent';
  }

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
      'Şu an arkadaşsınız. Engellemek arkadaşlığı sonlandırır, yani tekrar bağlanmak için yeni bir arkadaşlık isteği göndermen gerekir.';

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
      'Ayrıca onlarla olan DM’ini de siler: tüm mesajlar, tepkiler ve medya dosyaları yok olur.';

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
  String get enterPublicRoomAskFailedMessage => 'Şu an soramadık. Tekrar dene';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'yanlış şifre';

  @override
  String get enterPublicRoomJoinFailedMessage => 'katılamadık, tekrar dene';

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
  String get feedBoardLoadFailed => 'Pano yüklenemedi. Birazdan tekrar dene';

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
  String get roomBadgePrivateTooltip => 'Yalnızca davetle, Keşfet\'te görünmez';

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
      'Kurtarma ifaden yok. Bir daha giremeyebilirsin.';

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
  String get roomContentTabLabelMedia => 'Medya';

  @override
  String get roomContentTabLabelFiles => 'Dosyalar';

  @override
  String get roomContentTabLabelVoice => 'Ses';

  @override
  String get roomContentTabLabelLinks => 'Bağlantılar';

  @override
  String get roomContentTabLabelSaved => 'Kaydedilenler';

  @override
  String get roomContentTabHeaderMedia => 'Medya';

  @override
  String get roomContentTabHeaderFiles => 'Dosyalar';

  @override
  String get roomContentTabHeaderVoice => 'Ses';

  @override
  String get roomContentTabHeaderLinks => 'Bağlantılar';

  @override
  String get roomContentTabHeaderSaved => 'Kaydedilenler';

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
      'Neyin yanlış gittiğini anlat. Uygulama ve cihaz bilgilerin, uygulamanın o sırada ne yaptığını gösteren teknik bir kayıtla birlikte otomatik olarak eklenir. Nedeni bulmamıza yardımcı olan şey bu.';

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
  String get reportProblemSent => 'Rapor gönderildi. Teşekkürler!';

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
      'şuan sadece önizleme: daha sade baloncuklar, açmak için dokun';

  @override
  String get settingsScreenMenuBarLabel => 'MENÜ ÇUBUĞU SİMGESİ';

  @override
  String get settingsScreenMenuBarOnBody =>
      'MonkeyHub okunmamış sayısıyla menü çubuğunda durur. Pencere için tıkla';

  @override
  String get settingsScreenMenuBarOffBody =>
      'şuan kapalı. Gizli pencereye dönmenin tek yolu Dock simgesi';

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
      'Full HD: daha keskin, daha fazla veri kullanır';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD: güçlü bağlantılarda en iyisi';

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
      'sessiz. Her şeyi ancak uygulamayı açınca görürsün';

  @override
  String get settingsScreenGameRemindersLabel => 'GÜNLÜK OYUN HATIRLATMASI';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'öğlen tek bir dürtme, yalnızca oynamadıysan';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'hatırlatma yok. Oyunlar baktığında yine orada';

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
      'Bu bir çocuk hesabı. Bir yetişkinden eşleştirme kodu iste.';

  @override
  String get authErrorPairingCodeExpired =>
      'Bu kodun süresi doldu. Yeni bir tane iste.';

  @override
  String get authErrorPairingCodeInvalid =>
      'Bu kod çalışmadı. Daha önce kullanılmış olabilir.';

  @override
  String get authErrorUseSocialSignIn =>
      'Bu hesap Apple veya Google ile giriş yapıyor. Aşağıdaki butonları kullan.';

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
      'Cam kenarının parlaklığı. Kenarlıksız bir yüzey için sıfır';

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
      'süslemeler durur, başka hiçbir şey değişmez';

  @override
  String get momentRailCaptureLabel => 'Yakala';

  @override
  String get momentRailYouLabel => 'Sen';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String momentRailPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öne çıkan',
      one: '1 öne çıkan',
    );
    return '$_temp0';
  }

  @override
  String momentRailPersonNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yeni',
      one: '1 yeni',
    );
    return '$_temp0';
  }

  @override
  String get momentRailAddHighlight => 'Öne çıkan ekle';

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
      'Bugünlük beş tane oldu. Yarına da kalsın';

  @override
  String get momentComposerErrorNotAllowed =>
      'Veli fotoğraf paylaşımını kapatmış';

  @override
  String get momentComposerErrorTooLong => 'Biraz uzun olmuş. Kısalt';

  @override
  String get momentComposerErrorEmpty =>
      'Bir fotoğraf ya da birkaç kelime ekle';

  @override
  String get momentComposerErrorGeneric => 'Paylaşılamadı. Tekrar dene';

  @override
  String get momentViewerDelete => 'Sil';

  @override
  String get momentViewerDeleteConfirmHeadline => 'Bunu sil?';

  @override
  String get momentViewerDeleteConfirmBody =>
      'Herkesin panosundan ve arşivinden tamamen silinir';

  @override
  String get momentViewerDeleteFailed => 'Silinemedi. Tekrar dene';

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
  String get puzzleShareCopied => 'Kopyalandı. Bir arkadaşına yapıştır';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'Bugünkünü zaten çözdün';

  @override
  String get puzzleErrorOutOfGuesses => 'Bugün hakkın kalmadı';

  @override
  String get puzzleErrorGeneric => 'Tahmin gönderilemedi. Tekrar dene';

  @override
  String get puzzleGuessWaiting =>
      'Bağlantı yok. Tahminin kaydedildi, bağlantı gelince gönderilecek';

  @override
  String get gameSubmitWaiting =>
      'Bağlantı yok. Bitmiş tahtan kaydedildi, bağlantı gelince gönderilecek';

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
      'bugün her zaman arkadaşlarınla paylaşılır. Bu, öncesindeki her şeyi açar';

  @override
  String get momentComposerVideo => 'Video';

  @override
  String get momentComposerErrorTooBig => 'Bu video çok büyük. En fazla 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => 'Bir an paylaştın';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'Puan aldın: $tag';
  }

  @override
  String momentActivityGameSolved(String game, String name) {
    return '$name çözdü: $game';
  }

  @override
  String momentActivityGameSolvedSelf(String game) {
    return 'Çözdün: $game';
  }

  @override
  String momentActivityGameMissed(String game, String name) {
    return '$name çözemedi: $game';
  }

  @override
  String momentActivityGameMissedSelf(String game) {
    return 'Çözemedin: $game';
  }

  @override
  String momentActivityCodeSolved(String name) {
    return '$name şifreyi çözdü';
  }

  @override
  String get momentActivityCodeSolvedSelf => 'Şifreyi çözdün';

  @override
  String momentActivityCodeMissed(String name) {
    return '$name şifreyi çözemedi';
  }

  @override
  String get momentActivityCodeMissedSelf => 'Şifreyi çözemedin';

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
      'Skorunu tuttuğun bir muhabbet. Başına bir şey geldiğinde (iyi, kötü ya da sadece tuhaf) kaydediyorsun ve o gün panoda duruyor.';

  @override
  String get pointsExplainerRuleHonour =>
      'Puanı kendin veriyorsun. Kimse denetlemiyor, zaten eğlencesi bu; abartırsan arkadaşların zaten söyler.';

  @override
  String get pointsExplainerRuleToday =>
      'Puanlar her gün sıfırlanır. Pano bugünü gösterir; kendi geçmişin sende kalır.';

  @override
  String get pointsExplainerRuleCap =>
      'Aynı türden günde beş tane, kimse panoyu saçmalığa çeviremesin diye.';

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
  String get feedBoardGamesOpen => 'Sıralama';

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
      'Her satır, sütun ve renkte bir taç, asla bitişik değil';

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
  String get gameShareCopied => 'Kopyalandı. Bir arkadaşına yapıştır';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number · $time';
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
  String get gameHintWrong => 'Bu yanlıştı, o yüzden silindi.';

  @override
  String get gameHintWrongMore =>
      'Düzeltilecek başka şeyler de var. Hazır olunca yine sor.';

  @override
  String get gameHintWrongLast => 'Yerleştirdiğin diğer her şey doğru.';

  @override
  String get gameHintReveal =>
      'Henüz hiçbir kural tek başına bir kareyi kesinleştirmiyor, o yüzden işte bir tane.';

  @override
  String get gameHintQueensRegion => 'Bu renkte taç için tek bir yer kaldı.';

  @override
  String get gameHintQueensRow => 'Bu satırda taç için tek bir yer kaldı.';

  @override
  String get gameHintQueensCol => 'Bu sütunda taç için tek bir yer kaldı.';

  @override
  String get gameHintQueensRegionInRow =>
      'Bu renk sadece bu satıra sığıyor, yani satırın geri kalanına taç gelemez.';

  @override
  String get gameHintQueensRegionInCol =>
      'Bu renk sadece bu sütuna sığıyor, yani sütunun geri kalanına taç gelemez.';

  @override
  String get gameHintQueensRowInRegion =>
      'Bu satırda sadece tek bir renkte yer var, yani o rengin geri kalanına taç gelemez.';

  @override
  String get gameHintQueensColInRegion =>
      'Bu sütunda sadece tek bir renkte yer var, yani o rengin geri kalanına taç gelemez.';

  @override
  String get gameHintStarsRegion =>
      'Bu renkte sadece hâlâ gereken yıldızlar kadar yer kaldı.';

  @override
  String get gameHintStarsRow =>
      'Bu satırda sadece hâlâ gereken yıldızlar kadar yer kaldı.';

  @override
  String get gameHintStarsCol =>
      'Bu sütunda sadece hâlâ gereken yıldızlar kadar yer kaldı.';

  @override
  String get gameHintTangoEqual =>
      '= işareti iki karenin aynı olduğunu gösterir.';

  @override
  String get gameHintTangoCross =>
      '× işareti iki karenin birbirinin tersi olduğunu gösterir.';

  @override
  String get gameHintTangoPair =>
      'Yan yana iki kare zaten aynı, o yüzden sıradaki diğeri olmalı.';

  @override
  String get gameHintTangoSandwich =>
      'İki yandaki kareler aynı, o yüzden ortadaki diğeri olmalı.';

  @override
  String get gameHintTangoRowSuns => 'Bu satırda zaten üç güneş var.';

  @override
  String get gameHintTangoRowMoons => 'Bu satırda zaten üç ay var.';

  @override
  String get gameHintTangoColSuns => 'Bu sütunda zaten üç güneş var.';

  @override
  String get gameHintTangoColMoons => 'Bu sütunda zaten üç ay var.';

  @override
  String gameHintLatinBox(int digit) {
    return 'Bu kutuda $digit için tek yer burası.';
  }

  @override
  String gameHintLatinRow(int digit) {
    return 'Bu satırda $digit için tek yer burası.';
  }

  @override
  String gameHintLatinCol(int digit) {
    return 'Bu sütunda $digit için tek yer burası.';
  }

  @override
  String get gameHintLatinOnly =>
      'Buraya tek bir sayı uyuyor. Diğerleri zaten satırında, sütununda ya da kutusunda var.';

  @override
  String get gameHintLatinOnlyLines =>
      'Buraya tek bir sayı uyuyor. Diğerleri zaten satırında ya da sütununda var.';

  @override
  String get gameHintLatinOnlySigns =>
      'Satırı, sütunu ve işaretleri hesaba katınca buraya tek bir sayı uyuyor.';

  @override
  String get gameHintNonogramRowFill =>
      'Bu satırın ipucu nasıl yerleşirse yerleşsin, bu kareyi kaplıyor.';

  @override
  String get gameHintNonogramRowCross =>
      'Bu satırın ipucu hiçbir şekilde bu kareye ulaşmıyor.';

  @override
  String get gameHintNonogramColFill =>
      'Bu sütunun ipucu nasıl yerleşirse yerleşsin, bu kareyi kaplıyor.';

  @override
  String get gameHintNonogramColCross =>
      'Bu sütunun ipucu hiçbir şekilde bu kareye ulaşmıyor.';

  @override
  String get gameHintMinesStart => 'Buradan başla. Bu kare her zaman güvenli.';

  @override
  String get gameHintMinesSafe =>
      'Bu sayının bütün mayınları zaten bayraklı, yani etrafındaki diğer kareler güvenli.';

  @override
  String get gameHintMinesFlag =>
      'Bu sayı, etrafındaki her gizli karenin mayın olmasını gerektiriyor.';

  @override
  String get gameHintMinesProofSafe =>
      'Bu karenin etrafındaki sayılar güvenli olduğunu kanıtlıyor.';

  @override
  String get gameHintMinesProofMine =>
      'Bu karenin etrafındaki sayılar mayın olduğunu kanıtlıyor.';

  @override
  String get gameHintFlowPipe => 'İşte noktadan noktaya bütün bir boru.';

  @override
  String get gameHintPatchesOnly => 'Bu ipucuna tek bir yama sığıyor.';

  @override
  String get gameHintPatchesCell =>
      'Buradaki bir kare sadece bu ipucuna ait olabilir, bu da ona tek bir yama bırakıyor.';

  @override
  String get gameHintPatchesSqueeze =>
      'Etrafındaki yamalar bu ipucuna sığacak tek bir yol bırakıyor.';

  @override
  String get gameErrorGeneric => 'Oyunlara ulaşılamadı. Tekrar dene';

  @override
  String get gameInfoOpen => 'Nasıl oynanır';

  @override
  String get gameInfoScoringTimed =>
      'En hızlı bitiren kazanır. Çıkınca saat durur. Aynı süre, aynı sıra.';

  @override
  String get gameInfoScoringGuesses =>
      'En az tahminde çözen kazanır. Süre önemli değil. Aynı tahmin sayısı, aynı sıra.';

  @override
  String get gameInfoSameForEveryone => 'Bugün herkese aynı bulmaca çıkar.';

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
      'Burada çok fazla kayıt var. Önce birini kaldır';

  @override
  String get roomScreenSaveFailedSnack => 'Kaydedilemedi';

  @override
  String get threadOverlaySaveLimitToast =>
      'Burada çok fazla kayıt var. Önce birini kaldır';

  @override
  String get threadOverlaySaveFailedToast => 'Kaydedilemedi';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'kaydettiğin mesajları yalnızca sen görürsün. Sabitlenen bir mesaj ise tam tersi: onu odadaki herkes görür.';

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
      'Bu sohbetten sana hiçbir şey ulaşmaz: ne bildirim ne de okunmamış sayısı.';

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
  String get composerCaptureLockedCancel => 'İptal';

  @override
  String get composerCaptureViewOnceLabel => 'Bir kez oynat';

  @override
  String get composerCaptureViewOnceVoiceHint =>
      'Yalnızca bir kez dinleyebilir';

  @override
  String get composerCaptureViewOnceVideoHint => 'Yalnızca bir kez izleyebilir';

  @override
  String get composerCapturePauseLabel => 'Kaydı duraklat';

  @override
  String get composerCaptureResumeLabel => 'Kayda devam et';

  @override
  String get composerCaptureFlashLabel => 'Flaş';

  @override
  String get composerCaptureReviewPlayLabel => 'Kaydı oynat';

  @override
  String get composerCaptureReviewStopLabel => 'Oynatmayı durdur';

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
  String get videoNoteScrubHint =>
      'Daha hassas sarmak için parmağını çemberin dışına doğru uzaklaştır';

  @override
  String get videoNoteScrubHalf => 'Yarı hızda sarma';

  @override
  String get videoNoteScrubFine => 'Hassas sarma';

  @override
  String videoNoteSpeedLabel(String speed) {
    return 'Oynatma hızı $speed';
  }

  @override
  String get videoNoteAutoAdvanceOn => 'Otomatik oynatma açık';

  @override
  String get videoNoteAutoAdvanceOff => 'Otomatik oynatma kapalı';

  @override
  String get videoNoteAutoAdvanceSemanticLabel =>
      'Sonraki video notunu otomatik oynat';

  @override
  String get composerCaptureStartRecordingLabel => 'Kaydı başlat';

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
  String get scheduledListDeleteHeadline => 'Zamanlanmış mesajı sil';

  @override
  String get scheduledListDeleteBody => 'Gönderilmeyecek.';

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
      'Bu sürüm sunucusuz geldi. Kendi sunucunu göster';

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
      'Telefonunda MonkeyHub’ı aç, profiline git, “Giriş için tara”ya dokun ve kamerayı buraya tut ya da aşağıdaki kodu yaz.';

  @override
  String get deviceLoginScreenWaiting => 'Onay bekleniyor…';

  @override
  String get deviceLoginScreenApproved => 'Onaylandı. Giriş yapılıyor…';

  @override
  String get deviceLoginScreenDenied => 'Giriş isteği telefonunda reddedildi';

  @override
  String get deviceLoginScreenGenericError =>
      'Bir şeyler ters gitti. Yeni bir kod dene';

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
  String get deviceLoginScanScreenGenericError => 'Onaylanamadı. Tekrar dene';

  @override
  String get authErrorDeviceLoginInvalid => 'Bu kod doğru değil.';

  @override
  String get authErrorDeviceLoginExpired =>
      'Bu kodun süresi doldu. Diğer cihazdan yenisini al.';

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
      'Bir cihazı kaldırmak oturumunu kapatır ve bildirimlerini durdurur. Anında geçerli olur: o cihaz bir şey yapmaya kalktığı anda giriş ekranına döner.';

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
      'Sebastian başka bir dilde yazılmış mesajı okur ve ne dediğini sana söyler. Hem de burada, telefonunda; hiçbir şey hiçbir yere gönderilmeden.';

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
      'Onun dillerinden biri değil, sonuç kaba olabilir';

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
      'Hiçbir şey indirilmedi. Yardımcılar yer kaplamıyor';

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
      'Marlowe henüz bir şey yapamıyor, yetenekler hâlâ yolda. Şimdi yapabileceğin şey bir beyin hazırlamak; böylece yetenekler geldiğinde indirme beklenmiyor olur.';

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
    return '$name indirilmeye devam ediyor. Ayarlar › Yardımcılar';
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
  String get screenShareDrawBoardIdle => 'Çizimler burada görünür';

  @override
  String get screenShareOverlayHint =>
      'Paylaşırken çizimleri diğer uygulamaların üzerinde göster';

  @override
  String get screenShareOverlayAllow => 'İzin ver';

  @override
  String get callScreenControlDraw => 'Çiz';

  @override
  String get callScreenControlMinimize => 'Küçült';

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
      'Paylaşacak bir şey yok. Sistem Ayarları\'nda ekran kaydına izin verip yeniden dene';

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
  String get gameTellFriendsSent => 'Gönderildi, haberleri var';

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
      'hiçbir şey. Panoları baktığında yine orada';

  @override
  String get searchScreenActionWithGrownUp => 'Bir büyükte';

  @override
  String get newChatMenuSearchHint => 'Arkadaşlarında ara';

  @override
  String get newChatMenuNoFriendsYet =>
      'Henüz arkadaş yok. Keşfet’ten birilerini bul';

  @override
  String get newChatMenuNoFriendsMatch => 'Eşleşen arkadaş yok';

  @override
  String get newChatMenuOpenDmFailed => 'O sohbet açılamadı. Tekrar dene';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'Kendi kişilerinden seç';

  @override
  String get childPolicyScreenPickPersonHint => 'Ad veya kullanıcı adı ara';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'Arkadaşlarından eklenecek kimse kalmadı,\\nbaşkasını aratabilirsin';

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
      'O oda eklenemedi. Tekrar dene';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'O oda bu şekilde eklenemez';

  @override
  String get childPolicyScreenErrorRoomGone => 'O oda artık yok';

  @override
  String get newChatMenuFriendsHeader => 'Arkadaşlar';

  @override
  String get roomChangeErrorGone =>
      'O öneri artık yok. Bir yönetici cevaplamış olabilir.';

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
  String get roomChangeRequestsClearedValue => 'Hiçbir şey, kaldır';

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
      'Tamam, bu grubu düzenleyebiliyorsun';

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
  String get recordsBlurb => 'Şimdiye kadarki en iyiler: sen ve arkadaşların';

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
      'Gündüz açık, gece koyu; telefonunla birlikte';

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
  String get expressionReported => 'Teşekkürler, bildirildi.';

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
  String get settingsAlbumCardsLabel => 'Fotoğraf albümleri kart olarak';

  @override
  String get settingsAlbumCardsOffBody =>
      'Bir mesajdaki birden çok fotoğraf ızgara olarak dizilir.';

  @override
  String get settingsAlbumCardsOnBody =>
      'Bir mesajdaki birden çok fotoğraf, kaydırarak gezdiğin bir deste olarak gelir.';

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
  String get settingsHubPresenceDots => 'Kimin çevrimiçi olduğunu göster';

  @override
  String get settingsHubPresenceDotsSubtitle =>
      'Profil fotoğraflarındaki nokta';

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
      'Bugün her zaman arkadaşlarla paylaşılır. Bu, öncesini de açar';

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
      'Kaydettiklerini yalnızca sen görürsün. Sabitlenen mesaj ise tam tersi: tüm oda görür.';

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
  String get rpKeep => 'Şimdi değil, mevcut ifademi koru';

  @override
  String get childSetupHeadingIos => 'Bu kim?';

  @override
  String get childPairTitleIos => 'Merhaba!';

  @override
  String get childPairBackIos => 'Girişe dön';

  @override
  String get gamesHubTitle => 'Sıralama';

  @override
  String get gamesHubSubtitle =>
      'Bugünün kazananları. Her gün yeni bulmacalar.';

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
  String get settingsSearchHint => 'Ayarlarda ara';

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
  String get settingsSearchKwPresence =>
      'çevrimiçi, durum, nokta, aktif, yeşil';

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

  @override
  String get pageSectionSeeAll => 'Tümü';

  @override
  String get discoverScreenSeeAllFriendsSemanticLabel => 'Tüm arkadaşları gör';

  @override
  String get discoverScreenSeeAllRoomsSemanticLabel => 'Tüm odalarını gör';

  @override
  String groupCallScreenRingingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi aranıyor',
    );
    return '$_temp0';
  }

  @override
  String photoChromeWhenToday(String time) {
    return 'Bugün $time';
  }

  @override
  String photoChromeWhenYesterday(String time) {
    return 'Dün $time';
  }

  @override
  String photoChromeWhenDate(String date, String time) {
    return '$date $time';
  }

  @override
  String get photoChromeSaved => 'Kaydedildi';

  @override
  String get photoChromeSaveFailed => 'Kaydedilemedi';

  @override
  String get photoChromeShareFailed => 'Paylaşılamadı';

  @override
  String photoChromeForwarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sohbete iletildi',
      one: 'İletildi',
    );
    return '$_temp0';
  }

  @override
  String get photoChromeForwardFailed => 'İletilemedi';

  @override
  String get photoChromeDeleteFailed => 'Silinemedi';

  @override
  String get photoChromeDeleteBody =>
      'Bu, sohbetteki herkes için kaldırılır. Geri alınamaz.';

  @override
  String get roomContentMonthThis => 'Bu ay';

  @override
  String get roomContentMonthLast => 'Geçen ay';

  @override
  String get leaderboardOverall => 'Bugün';

  @override
  String get leaderboardFooter =>
      'Bugün çözdüğün her bulmaca 1 puan. Eşitlikte, daha çok birinci olan öne geçer. Yine eşitseniz aynı sırayı paylaşırsınız, isimler A\'dan Z\'ye.';

  @override
  String get leaderboardNotPlayed => 'Henüz oynamadın';

  @override
  String get leaderboardPlay => 'Oyna';

  @override
  String get leaderboardEmptyTitle => 'Bugün henüz skor yok';

  @override
  String get leaderboardEmptyBody => 'Bir bulmaca çöz, listede ilk sen ol.';

  @override
  String get pointComposerPickFirst => 'Önce yukarıdan birini seç';

  @override
  String get momentStoryNext => 'Sonraki';

  @override
  String get momentStoryPrevious => 'Önceki';

  @override
  String leaderboardSolved(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      solved,
      locale: localeName,
      other: '$solved/$total çözüldü',
      zero: 'Henüz çözülen yok',
    );
    return '$_temp0';
  }

  @override
  String leaderboardWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count galibiyet',
    );
    return '$_temp0';
  }

  @override
  String leaderboardEmptyAction(String game) {
    return 'Oyna: $game';
  }

  @override
  String get diagCatApi => 'Sunucu çağrıları';

  @override
  String get diagCatConnection => 'Bağlantı';

  @override
  String get diagCatDevice => 'Cihaz';

  @override
  String get diagCatError => 'Hatalar';

  @override
  String get diagCatFrame => 'Yavaş kareler';

  @override
  String get diagCatLayout => 'Yerleşim';

  @override
  String get diagCatLifecycle => 'Uygulama durumu';

  @override
  String get diagCatLog => 'Günlük';

  @override
  String get diagCatNav => 'Gezinme';

  @override
  String get diagCatNetwork => 'Ağ';

  @override
  String get diagCatSubscription => 'Canlı güncellemeler';

  @override
  String get diagSevTrace => 'İz';

  @override
  String get diagSevDebug => 'Hata ayıklama';

  @override
  String get diagSevInfo => 'Bilgi';

  @override
  String get diagSevWarning => 'Uyarı';

  @override
  String get diagSevError => 'Hata';

  @override
  String get diagAll => 'Tümü';

  @override
  String get diagSearchHint => 'Ad, ayrıntı, içerik ara';

  @override
  String get diagSummaryCopied => 'Özet kopyalandı';

  @override
  String get diagShareLog => 'Günlüğü paylaş';

  @override
  String get diagCopySummary => 'Özeti kopyala';

  @override
  String get diagDeleteAll => 'Tümünü sil';

  @override
  String get diagUndo => 'Geri al';

  @override
  String get diagDeleteLogTitle => 'Günlüğün tamamı silinsin mi?';

  @override
  String get diagDeleteLogBody =>
      'Şimdiye kadar kaydedilen her olay ve bir önceki açılışın günlüğü silinir. Bundan sonra olanlar her zamanki gibi kaydedilir.';

  @override
  String get diagDelete => 'Sil';

  @override
  String get diagLogDeleted => 'Günlük silindi';

  @override
  String get diagFilter => 'Filtre';

  @override
  String get diagMore => 'Diğer';

  @override
  String get diagLatest => 'En yeni';

  @override
  String get diagJumpToLatest => 'En yeniye git';

  @override
  String get diagPaused => 'duraklatıldı';

  @override
  String get diagPreparingLog => 'günlük hazırlanıyor…';

  @override
  String get diagEmptyNothingTitle => 'Henüz bir şey kaydedilmedi';

  @override
  String get diagEmptyNothingHint =>
      'Uygulamayı biraz kullan, olaylar burada görünür.';

  @override
  String get diagEmptyHiddenTitle => 'Şimdilik yalnızca gizli olaylar var';

  @override
  String get diagEmptyHiddenHint =>
      'Görmek için yukarıdaki soluk bir etikete dokun ya da Tümü\'ne geri almak için basılı tut.';

  @override
  String get diagEmptyNoMatchTitle => 'Eşleşen olay yok';

  @override
  String get diagEmptyNoMatchHint =>
      'Filtreyi temizlemek için yukarıdaki Tümü\'ne dokun.';

  @override
  String get diagApply => 'Uygula';

  @override
  String get diagMinSeverity => 'En düşük önem';

  @override
  String get diagEverything => 'Her şey';

  @override
  String get diagHiddenFromAllHeader => 'Tümü\'nde gizli';

  @override
  String get diagHiddenFromAllFooter =>
      'Etiket satırında seçilene kadar Tümü\'nde görünmez. Aynı ayar için oradaki etikete basılı tut.';

  @override
  String get diagCollapseRepeats => 'Tekrarları birleştir';

  @override
  String get diagCollapseRepeatsSubtitle =>
      'Art arda gelen aynı olayları tek satırda topla';

  @override
  String get diagResetFilter => 'Filtreyi sıfırla';

  @override
  String get diagBodyTruncated => 'İçerik kayıt sırasında kısaltıldı';

  @override
  String get diagCopyEvent => 'Olayı kopyala';

  @override
  String get diagEventCopied => 'Olay kopyalandı';

  @override
  String diagHiddenFromAll(String category) {
    return '$category Tümü\'nde gizlendi';
  }

  @override
  String diagBackInAll(String category) {
    return '$category yeniden Tümü\'nde';
  }

  @override
  String diagChipSemanticLabel(String category, int count) {
    return '$category, $count';
  }

  @override
  String diagChipHiddenSemanticLabel(String category, int count) {
    return '$category, $count, Tümü\'nde gizli';
  }

  @override
  String diagEventCount(int shown, int total) {
    return '$total olaydan $shown tanesi';
  }

  @override
  String diagDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Önceki $count olay atıldı, günlük hikâyenin ortasından başlıyor',
    );
    return '$_temp0';
  }

  @override
  String diagRepeatSpan(int count, String seconds) {
    return '$seconds sn içinde ×$count';
  }

  @override
  String roomContentTabSemantic(String count, String label) {
    return '$label, $count öğe';
  }

  @override
  String get mapAppsTitle => 'Haritalar';

  @override
  String get mapAppsChoose => 'Konumu şurada aç';

  @override
  String get mapAppsRemember => 'Varsayılan olarak kullan';

  @override
  String get mapAppsAskEveryTime => 'Her seferinde sor';

  @override
  String get mapAppsBrowser => 'Tarayıcı';

  @override
  String get mapAppsSubtitle => 'Paylaşılan konumların nerede açılacağını seç.';

  @override
  String get mapAppsUnavailable =>
      'Varsayılan harita uygulaman kullanılamıyor. Başka bir uygulama seç.';

  @override
  String get mapAppsNoInstalled =>
      'Desteklenen bir harita uygulaması bulunamadı. Tarayıcını kullanabilirsin.';

  @override
  String get interactionAnswersSearch => 'Kişi veya yanıt ara';

  @override
  String get interactionFilterEmpty => 'Bu filtreye uygun yanıt yok.';

  @override
  String get interactionRetry => 'Tekrar dene';

  @override
  String get cameraEditorScreenCaptionHint => 'Açıklama ekle…';

  @override
  String get cameraEditorScreenCaptionViewOnceHint =>
      'Tek seferlik fotoğraflarda açıklama olmaz';

  @override
  String get cameraEditorScreenAddFromCameraSemanticLabel =>
      'Bir fotoğraf daha çek';

  @override
  String cameraEditorScreenDiscardAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotoğraf silinsin mi?',
      one: 'Bu fotoğraf silinsin mi?',
    );
    return '$_temp0';
  }

  @override
  String get cameraEditorScreenDiscardAllBody =>
      'Düzenlemelerin ve açıklamaların kaybolacak.';

  @override
  String get cameraEditorScreenDiscardAllConfirm => 'Sil';

  @override
  String get galleryTrayRecentsTitle => 'Son Eklenenler';

  @override
  String get galleryTrayBackToCameraLabel => 'Kameraya dön';

  @override
  String get galleryTrayAllPhotosLabel => 'Tüm fotoğraflar';

  @override
  String get galleryTrayHandleLabel => 'Son fotoğraflar';

  @override
  String get galleryTrayAllowPrompt => 'Son fotoğraflarını burada gör';

  @override
  String get galleryTrayAllowButton => 'İzin ver';

  @override
  String get galleryTrayDeniedPrompt => 'Fotoğraf erişimi kapalı';

  @override
  String get galleryTraySettingsButton => 'Ayarlar';

  @override
  String get galleryTrayLimitedNote =>
      'Yalnızca izin verdiğin fotoğraflar gösteriliyor';

  @override
  String get galleryTrayManageButton => 'Yönet';

  @override
  String get galleryTrayEmpty => 'Henüz fotoğraf yok';

  @override
  String galleryTrayAddSelectedButton(int count) {
    return 'Ekle ($count)';
  }

  @override
  String get galleryTrayCancelSelectionLabel => 'Seçimi iptal et';

  @override
  String galleryTraySelectedTitle(int count) {
    return '$count seçildi';
  }

  @override
  String galleryTrayPhotoLabel(int index) {
    return 'Fotoğraf $index';
  }

  @override
  String get reactionLimitTitle => 'Tepki sınırına ulaştın';

  @override
  String reactionLimitMessageBody(int limit) {
    return 'Hız, akıl sağlığı ve her emojinin hakkını vermek adına bir mesaja en fazla $limit tepki ekleyebilirsin, daha fazla değil. Yeni bir tane için birini geri al.';
  }

  @override
  String reactionLimitHighlightBody(int limit) {
    return 'Öne çıkanlarda kişi başı $limit tepki var, böylece her biri hâlâ bir şey anlatıyor. Yeni favorine yer açmak için birini geri al.';
  }

  @override
  String get reactionLimitDismiss => 'Tamam';

  @override
  String get reactionPickerYoursLabel => 'Tepkilerin';

  @override
  String reactionPickerTakeBackSemantic(String emoji) {
    return '$emoji tepkini kaldır';
  }

  @override
  String get momentCommentsTitle => 'Yorumlar';

  @override
  String momentCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yorum',
      one: '1 yorum',
      zero: 'Yorum',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentsEmptyTitle => 'Henüz yorum yok';

  @override
  String get momentCommentsEmptyBody =>
      'Sohbeti bir sözle, bir çıkartmayla ya da bir GIF ile başlat.';

  @override
  String get momentCommentHint => 'Yorum ekle…';

  @override
  String momentCommentReplyHint(String name) {
    return '$name kişisine yanıt ver…';
  }

  @override
  String momentCommentReplyingTo(String name) {
    return '$name kişisine yanıt veriyorsun';
  }

  @override
  String get momentCommentCancelReply => 'Yanıtı iptal et';

  @override
  String get momentCommentReply => 'Yanıtla';

  @override
  String momentCommentViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yanıtı gör',
      one: '1 yanıtı gör',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentHideReplies => 'Yanıtları gizle';

  @override
  String get momentCommentDelete => 'Yorumu sil';

  @override
  String get momentCommentDeleteConfirm =>
      'Bu yorum silinsin mi? Yanıtları da gider.';

  @override
  String get momentCommentDeleteConfirmButton => 'Sil';

  @override
  String get momentCommentSend => 'Gönder';

  @override
  String get momentCommentExpressions => 'Çıkartmalar ve GIF\'ler';

  @override
  String get momentCommentFailed => 'Yorumun gönderilemedi. Tekrar dene.';

  @override
  String get momentCommentAuthorBadge => 'Paylaşan';

  @override
  String get momentCommentLike => 'Beğen';

  @override
  String get momentCommentStickerAlt => 'Çıkartma';

  @override
  String get momentCommentGifAlt => 'GIF';

  @override
  String get momentCommentPosted => 'Yorum gönderildi';

  @override
  String momentCommentsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count yorumun tümünü gör',
      one: '1 yorumu gör',
    );
    return '$_temp0';
  }

  @override
  String momentReactorsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi daha',
      one: '1 kişi daha',
    );
    return '$name ve $_temp0';
  }

  @override
  String get storageKindPhotos => 'Fotoğraflar';

  @override
  String get storageKindVideos => 'Videolar';

  @override
  String get storageKindVideoMessages => 'Video notları';

  @override
  String get storageKindVoice => 'Sesli mesajlar';

  @override
  String get storageKindFiles => 'Dosyalar';

  @override
  String get storageKindStickers => 'Çıkartmalar ve GIF\'ler';

  @override
  String get storageKindChatHistory => 'Sohbet geçmişi';

  @override
  String get storageKindOther => 'Diğer';

  @override
  String get dataUsageKindCalls => 'Aramalar';

  @override
  String get dataStorageTitle => 'Veri ve Depolama';

  @override
  String get settingsSearchKwDataStorage =>
      'depolama önbellek bellek alan temizle indir otomatik indirme veri kullanımı hücresel mobil wifi fotoğraflara kaydet galeri storage cache';

  @override
  String get storageUsageTitle => 'Depolama Kullanımı';

  @override
  String get dataUsageTitle => 'Veri Kullanımı';

  @override
  String get dataStorageAutoDownloadHeader => 'Otomatik medya indirme';

  @override
  String get dataStorageUsingCellular => 'Hücresel Kullanırken';

  @override
  String get dataStorageUsingWifi => 'Wi-Fi Kullanırken';

  @override
  String get dataStorageNowTag => 'Şu an';

  @override
  String get autoDownloadReset => 'Otomatik indirme ayarlarını sıfırla';

  @override
  String get autoDownloadResetTitle =>
      'Varsayılan otomatik indirme ayarları geri yüklensin mi?';

  @override
  String get dataStorageSaveHeader => 'Fotoğraflar\'a kaydet';

  @override
  String get dataStorageSaveFooter =>
      'Bu sohbetlerdeki yeni fotoğraf ve videolar otomatik olarak fotoğraf arşivine kaydedilir.';

  @override
  String get dataStorageCallsHeader => 'Aramalar';

  @override
  String get dataStorageLessDataForCalls => 'Aramalarda daha az veri kullan';

  @override
  String get dataStorageCallsFooter =>
      'Zayıf veya kotalı ağlarda daha az veri kullanır, ses ve görüntü kalitesi biraz düşer.';

  @override
  String get dataStorageCallsNever => 'Asla';

  @override
  String get dataStorageCallsCellular => 'Hücresel veride';

  @override
  String get dataStorageCallsAlways => 'Her zaman';

  @override
  String get dataStorageOff => 'Kapalı';

  @override
  String get dataStorageChatsPrivate => 'Özel sohbetler';

  @override
  String get dataStorageChatsGroups => 'Gruplar';

  @override
  String get dataStorageChatsPublic => 'Herkese açık odalar';

  @override
  String get dataStorageNetCellular => 'Hücresel';

  @override
  String get dataStorageNetWifi => 'Wi-Fi';

  @override
  String get autoDownloadMaster => 'Medyayı otomatik indir';

  @override
  String get autoDownloadUsageHeader => 'Veri kullanımı';

  @override
  String get autoDownloadPresetLow => 'Düşük';

  @override
  String get autoDownloadPresetMedium => 'Orta';

  @override
  String get autoDownloadPresetHigh => 'Yüksek';

  @override
  String get autoDownloadCustomFooter =>
      'Bu ayarları özelleştirdin. Hazır ayara dönmek için kaydırıcıyı hareket ettir.';

  @override
  String get autoDownloadTypesHeader => 'Medya türleri';

  @override
  String get autoDownloadVideosTitle => 'Videolar ve video notları';

  @override
  String get autoDownloadVoiceFooter =>
      'Sesli mesajlar ve çıkartmalar çok küçük olduğu için her zaman otomatik indirilir.';

  @override
  String get autoDownloadAllChats => 'Tüm sohbetler';

  @override
  String autoDownloadUpToIn(String size, String chats) {
    return 'En fazla $size, $chats';
  }

  @override
  String autoDownloadSummaryUpTo(String kind, String size) {
    return '$kind, en fazla $size';
  }

  @override
  String get autoDownloadSummaryVoiceOnly => 'Yalnızca sesli mesajlar';

  @override
  String get autoDownloadInHeader => 'Otomatik indirilecek yerler';

  @override
  String get autoDownloadMaxSizeHeader => 'Maksimum dosya boyutu';

  @override
  String autoDownloadMaxSizeVideoFooter(String size) {
    return '$size boyutuna kadar videolar otomatik indirilir. Daha büyükler dokunmanı bekler.';
  }

  @override
  String autoDownloadMaxSizeFileFooter(String size) {
    return '$size boyutuna kadar dosyalar otomatik indirilir. Daha büyükler dokunmanı bekler.';
  }

  @override
  String get autoDownloadGateLoad => 'Fotoğrafı indir';

  @override
  String get saveToPhotosHeader => 'Otomatik kaydet';

  @override
  String get saveToPhotosFooter =>
      'Bu sohbetlerde aldığın yeni fotoğraf ve videolar indirildikçe fotoğraf arşivine eklenir.';

  @override
  String get saveToPhotosMaxVideoHeader => 'Maksimum video boyutu';

  @override
  String get saveToPhotosNoAccess =>
      'Otomatik kaydetmek için Ayarlar\'dan fotoğraf arşivine erişim izni ver.';

  @override
  String get saveToPhotosPhotosAndVideos => 'Fotoğraflar ve videolar';

  @override
  String get storageCalculating => 'Hesaplanıyor…';

  @override
  String storageShareOfFree(String percent) {
    return 'MonkeyHub boş alanının $percent kadarını kullanıyor.';
  }

  @override
  String get storageEmpty => 'Şu an önbellekte bir şey yok.';

  @override
  String storageClearAllButton(String size) {
    return 'Tüm önbelleği temizle $size';
  }

  @override
  String storageClearSelectedButton(String size) {
    return 'Seçilenleri temizle $size';
  }

  @override
  String storageClearChatButton(String size) {
    return 'Önbelleği temizle $size';
  }

  @override
  String get storageClearFooter =>
      'Her şey bulutta kalır ve ihtiyaç duyduğunda yeniden indirilir.';

  @override
  String get storageClearAllTitle => 'Tüm önbellek temizlensin mi?';

  @override
  String get storageClearSelectedTitle => 'Seçilenler temizlensin mi?';

  @override
  String get storageClearBody =>
      'Mesajların silinmez. Medya, açtığında yeniden indirilir.';

  @override
  String storageClearConfirm(String size) {
    return '$size temizle';
  }

  @override
  String storageFreed(String size) {
    return '$size boşaltıldı';
  }

  @override
  String storageCleanupTitle(String size) {
    return '$size boşalt';
  }

  @override
  String get storageCleanupSubtitle => 'Bir aydır açmadığın medya';

  @override
  String get storageCleanupAction => 'Temizle';

  @override
  String get storageCleanupFooter =>
      'Yalnızca 30 gündür kimsenin bakmadığı medyayı temizler. Kaydedilmiş Mesajlar\'a asla dokunulmaz.';

  @override
  String get storageAutoRemoveHeader => 'Önbellekteki medyayı otomatik sil';

  @override
  String get storageAutoRemoveFooter =>
      'Bu süre boyunca açmadığın medya, yer açmak için bu cihazdan kaldırılır. Bulutta kalmaya devam eder ve Kaydedilmiş Mesajlar her zaman korunur.';

  @override
  String get dataStorageKeepNever => 'Asla';

  @override
  String get dataStorageKeepMonth => '1 ay';

  @override
  String get dataStorageKeepWeek => '1 hafta';

  @override
  String get dataStorageKeepDay => '1 gün';

  @override
  String get storageLimitHeader => 'Maksimum önbellek boyutu';

  @override
  String get storageLimitFooter =>
      'Önbellek bu boyutu aşarsa en uzun süredir açılmayan medya önce silinir.';

  @override
  String get dataStorageLimitNone => 'Sınır yok';

  @override
  String get storageTabChats => 'Sohbetler';

  @override
  String get storageTabMedia => 'Medya';

  @override
  String get storageTabFiles => 'Dosyalar';

  @override
  String get storageNoChats => 'Henüz hiçbir sohbette önbellek yok.';

  @override
  String get storageNoMedia => 'Henüz önbellekte fotoğraf veya video yok.';

  @override
  String get storageNoFiles => 'Henüz önbellekte dosya yok.';

  @override
  String get storageOpenPhoto => 'Fotoğrafı aç';

  @override
  String get storageOpenVideo => 'Videoyu aç';

  @override
  String get storageSelect => 'Seç';

  @override
  String storageChatShare(String percent) {
    return 'Bu sohbet önbelleğinin $percent kadarını kullanıyor.';
  }

  @override
  String get storageChatUnknown => 'Ayrıldığın sohbet';

  @override
  String dataUsageSince(String date) {
    return '$date tarihinden beri';
  }

  @override
  String get dataUsageAll => 'Tümü';

  @override
  String get dataUsageNothingYet => 'Bu ağda henüz hiçbir şey sayılmadı.';

  @override
  String get dataUsageTapHint =>
      'Gönderilen ve alınanları görmek için bir kategoriye dokun.';

  @override
  String get dataUsageSent => 'Gönderilen';

  @override
  String get dataUsageReceived => 'Alınan';

  @override
  String get dataUsageTotalHeader => 'Toplam ağ kullanımı';

  @override
  String get dataUsageFootnote =>
      'Medya ve aramaları sayar. Mesajların kendisi çok küçük olduğundan dahil değildir.';

  @override
  String get dataUsageReset => 'İstatistikleri sıfırla';

  @override
  String get dataUsageResetTitle =>
      'Veri kullanımı istatistikleri sıfırlansın mı?';

  @override
  String get dataUsageResetBody => 'Sayım şu andan itibaren yeniden başlar.';

  @override
  String get storageKindCompanions => 'Yoldaşlar';

  @override
  String get storageCompanionsNote =>
      'Yoldaşlar önbellekle birlikte temizlenmez. İndirmelerini yönetmek için onlara dokun.';

  @override
  String storageCategoryCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count öğe, $size',
      one: '1 öğe, $size',
    );
    return '$_temp0';
  }

  @override
  String get storageSelectAll => 'Tümünü seç';

  @override
  String get storageDeselectAll => 'Seçimi kaldır';

  @override
  String get storageCategoryEmpty =>
      'Şu anda bu türde önbelleğe alınmış bir şey yok.';

  @override
  String get storageChatHistoryFooter =>
      'Yalnızca bu cihazdaki kopya silinir. Mesajlar sohbette kalır ve sohbeti bir sonraki açışında yeniden yüklenir.';

  @override
  String get storageCategoryHint =>
      'İçinde ne olduğunu görmek için bir kategoriye, hariç tutmak için dairesine dokun.';

  @override
  String storageChatRemovedNamed(String names) {
    return '$names · kaldırılan sohbet';
  }

  @override
  String get streaksLabel => 'Seriler';

  @override
  String get streakAtRiskFooter => 'Serini korumak için bugün oyna.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count günlük seri',
    );
    return '$_temp0';
  }

  @override
  String recordsCheersMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 've $count kişi daha',
    );
    return '$_temp0';
  }

  @override
  String get recordsCheer => 'Tebrik et';

  @override
  String get myStreaksLabel => 'Serilerim';

  @override
  String streakLongest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün',
    );
    return 'En uzun serin: $_temp0';
  }

  @override
  String get streaksEmpty => 'Burada henüz kimse seride değil.';

  @override
  String videoTooLargeSnack(String size) {
    return 'Videolar en fazla $size olabilir';
  }

  @override
  String videoShrinkPromptTitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video $size sınırını aşıyor',
      one: 'Bu video $size sınırını aşıyor',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkPromptBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sığmaları için sıkıştırılacaklar, epey bulanık görünecekler.',
      one: 'Sığması için sıkıştırılacak, epey bulanık görünecek.',
    );
    return '$_temp0';
  }

  @override
  String get videoShrinkPromptAction => 'Sıkıştır ve gönder';

  @override
  String get videoShrinkWorkingSnack => 'Video sıkıştırılıyor…';

  @override
  String videoShrinkFailedSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count video sıkıştırılsa bile $size içine sığmayacak kadar uzun',
      one: 'Sıkıştırılsa bile $size içine sığmayacak kadar uzun',
    );
    return '$_temp0';
  }

  @override
  String photoHdOverCapSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fotoğraf $size sınırını aştığı için standart kalitede gitti',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkSendSmallOnly(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Yalnızca $size altındaki $count videoyu gönder',
    );
    return '$_temp0';
  }

  @override
  String get kbdGroupGeneral => 'Genel';

  @override
  String get kbdGroupNavigation => 'Gezinme';

  @override
  String get kbdGroupChat => 'Sohbette';

  @override
  String get kbdGroupComposer => 'Yazma';

  @override
  String get kbdGroupViewer => 'Fotoğraflar ve videolar';

  @override
  String get kbdGroupCall => 'Aramalar';

  @override
  String get kbdCommandPalette => 'Sohbet ve komut ara';

  @override
  String get kbdShowShortcuts => 'Klavye kısayolları';

  @override
  String get kbdSearch => 'Ara';

  @override
  String get kbdNewChat => 'Yeni sohbet';

  @override
  String get kbdSettings => 'Ayarlar';

  @override
  String get kbdBack => 'Geri dön veya kapat';

  @override
  String kbdGoTo(String section) {
    return '$section bölümüne git';
  }

  @override
  String get kbdNextChat => 'Sonraki sohbet';

  @override
  String get kbdPreviousChat => 'Önceki sohbet';

  @override
  String get kbdNextUnread => 'Sonraki okunmamış sohbet';

  @override
  String get kbdCloseChat => 'Sohbeti kapat';

  @override
  String get kbdRoomInfo => 'Sohbet bilgisi';

  @override
  String get kbdSearchInChat => 'Bu sohbette ara';

  @override
  String get kbdJumpToLatest => 'Son mesaja atla';

  @override
  String get kbdAttach => 'Dosya ekle';

  @override
  String get kbdVoiceCall => 'Sesli arama';

  @override
  String get kbdVideoCall => 'Görüntülü arama';

  @override
  String get kbdSend => 'Gönder';

  @override
  String get kbdNewline => 'Yeni satır';

  @override
  String get kbdEditLast => 'Son mesajını düzenle';

  @override
  String get kbdBold => 'Kalın';

  @override
  String get kbdItalic => 'İtalik';

  @override
  String get kbdUnderline => 'Altı çizili';

  @override
  String get kbdPasteMedia => 'Fotoğraf veya dosya yapıştır';

  @override
  String get kbdEmoji => 'Emoji ve çıkartmalar';

  @override
  String get kbdViewerPrevious => 'Önceki';

  @override
  String get kbdViewerNext => 'Sonraki';

  @override
  String get kbdZoomIn => 'Yakınlaştır';

  @override
  String get kbdZoomOut => 'Uzaklaştır';

  @override
  String get kbdZoomFit => 'Pencereye sığdır';

  @override
  String get kbdPlayPause => 'Oynat veya duraklat';

  @override
  String get kbdCopyMedia => 'Kopyala';

  @override
  String get kbdSaveMedia => 'Kaydet';

  @override
  String get kbdToggleMute => 'Mikrofonu kapat veya aç';

  @override
  String get kbdToggleCamera => 'Kamerayı aç veya kapat';

  @override
  String get kbdHangUp => 'Aramayı bitir';

  @override
  String get kbdGroupApp => 'Uygulama';

  @override
  String get kbdCloseWindow => 'Pencereyi kapat';

  @override
  String get kbdMinimizeWindow => 'Simge durumuna küçült';

  @override
  String get kbdFullScreen => 'Tam ekran';

  @override
  String get kbdHideApp => 'MonkeyHub\'ı gizle';

  @override
  String get kbdQuit => 'MonkeyHub\'dan çık';

  @override
  String get kbdPanelTitle => 'Klavye Kısayolları';

  @override
  String get kbdPanelSearchHint => 'Kısayollarda ara';

  @override
  String get kbdPanelEmpty => 'Eşleşen kısayol yok';

  @override
  String kbdPeekHint(String key) {
    return 'Bulunduğun ekranın kısayollarını görmek için istediğin an $key tuşunu basılı tut';
  }

  @override
  String kbdPeekSetting(String key) {
    return '$key tuşu basılı tutulunca kısayolları göster';
  }

  @override
  String get kbdPaletteHint => 'Bir sohbete geç veya komut çalıştır';

  @override
  String get kbdPaletteChats => 'Sohbetler';

  @override
  String get kbdPaletteCommands => 'Komutlar';

  @override
  String get kbdPaletteEmpty => 'Hiçbir şey bulunamadı';

  @override
  String get kbdPaletteMove => 'Gezin';

  @override
  String get kbdPaletteOpen => 'Aç';

  @override
  String get kbdPaletteClose => 'Kapat';

  @override
  String get msgDeskReactLabel => 'Tepki ver';

  @override
  String get msgDeskMoreLabel => 'Diğer';

  @override
  String get msgDeskInfoLabel => 'Bilgi';

  @override
  String get kbdSeekBackward => '5 saniye geri';

  @override
  String get kbdSeekForward => '5 saniye ileri';

  @override
  String get kbdMuteVideo => 'Videonun sesini kapat veya aç';

  @override
  String get viewerSavedToDownloads => 'İndirilenler\'e kaydedildi';

  @override
  String get viewerDownloaded => 'İndirildi';

  @override
  String get viewerShowInFinder => 'Finder\'da göster';

  @override
  String get viewerShowInFolder => 'Klasörde göster';

  @override
  String get viewerCopied => 'Kopyalandı';

  @override
  String get viewerCopyFailed => 'Kopyalanamadı';

  @override
  String get hoverCompactLayoutTitle => 'Kompakt düzen';

  @override
  String get hoverCompactLayoutSubtitle =>
      'Fare ve büyük ekran için daha kısa satırlar ve daha küçük düğmeler.';

  @override
  String get layoutPagerPrevious => 'Önceki';

  @override
  String get layoutPagerNext => 'Sonraki';

  @override
  String get resultSheetMistakes => 'Hatalar';

  @override
  String get resultSheetHints => 'İpuçları';

  @override
  String get resultSheetStreak => 'Seri';

  @override
  String resultSheetStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gün',
      one: '1 gün',
    );
    return '$_temp0';
  }

  @override
  String get resultSheetNone => 'Yok';

  @override
  String resultSheetToday(String game) {
    return '$game · Bugün';
  }

  @override
  String resultSheetYouFaster(String time) {
    return 'Sen $time daha hızlıydın';
  }

  @override
  String resultSheetTheyFaster(String name, String time) {
    return '$name $time daha hızlıydı';
  }

  @override
  String get resultSheetSameTime => 'Seninle aynı süre';

  @override
  String get resultSheetFooter =>
      'Sıralamayı yalnızca süre belirler. Hatalar ve ipuçları sadece merak edenler için.';

  @override
  String get resultSheetHintNoRecord =>
      'İpucuyla çözüldü, bu yüzden tüm zamanların rekoru olamaz.';

  @override
  String get gameTierEasy => 'Kolay';

  @override
  String get gameTierMedium => 'Orta';

  @override
  String get gameTierHard => 'Zor';

  @override
  String get gameComingSoon => 'Yakında';

  @override
  String get gameComingSoonName => 'Yeni bulmaca';

  @override
  String get chatGameNameTicTacToe => 'XOX';

  @override
  String get chatGameNameConnectFour => 'Dörtlü';

  @override
  String get chatGameNameCheckers => 'Dama';

  @override
  String get chatGameNameReversi => 'Reversi';

  @override
  String get chatGameNameDots => 'Kutu Kapmaca';

  @override
  String get chatGameDescTicTacToe => 'Üçünü yan yana dizen kazanır.';

  @override
  String get chatGameDescConnectFour => 'Pul bırak, dördünü dizen kazanır.';

  @override
  String get chatGameDescCheckers => 'Atlayarak taş al. Hepsini topla.';

  @override
  String get chatGameDescReversi =>
      'Sıkıştır ve çevir. En çok taşı olan kazanır.';

  @override
  String get chatGameDescDots => 'Çizgi çek, kutuyu kapat, tekrar oyna.';

  @override
  String get chatGameKindLive => 'Canlı oyun';

  @override
  String get chatGameKindTurns => 'Sırayla';

  @override
  String get chatGameStatusWaiting => 'Bekleniyor';

  @override
  String get chatGameStatusPlaying => 'Oynanıyor';

  @override
  String get chatGameStatusPaused => 'Duraklatıldı';

  @override
  String get chatGameStatusFinished => 'Bitti';

  @override
  String get chatGameStatusEnded => 'Sona erdi';

  @override
  String get chatGameYourMove => 'Sıra sende';

  @override
  String chatGameTurnOf(String name) {
    return 'Sıra $name adlı kişide';
  }

  @override
  String chatGameWaitingFor(String name) {
    return '$name bekleniyor';
  }

  @override
  String chatGameWonBy(String name) {
    return '$name kazandı';
  }

  @override
  String get chatGameYouWon => 'Kazandın';

  @override
  String get chatGameDraw => 'Berabere';

  @override
  String get chatGameNobodyWon => 'Herkes ayrıldı, kazanan yok';

  @override
  String chatGameReasonTimeout(String name) {
    return '$name süresini doldurdu';
  }

  @override
  String chatGameReasonResign(String name) {
    return '$name pes etti';
  }

  @override
  String chatGameReasonLeft(String name) {
    return '$name ayrıldı';
  }

  @override
  String get chatGameOpenSeat => 'Boş koltuk';

  @override
  String get chatGameReady => 'Hazır';

  @override
  String get chatGameNotReady => 'Hazır değil';

  @override
  String chatGameWatchingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count izliyor',
    );
    return '$_temp0';
  }

  @override
  String get chatGameJoin => 'Katıl';

  @override
  String get chatGameWatch => 'İzle';

  @override
  String get chatGamePlay => 'Oyna';

  @override
  String get chatGameOpen => 'Aç';

  @override
  String get chatGameRematch => 'Rövanş';

  @override
  String get chatGameNotRanked =>
      'Sadece eğlence için. Sohbet oyunları serilerine ya da rekorlarına katılmaz.';

  @override
  String get chatGameNotRankedShort => 'Sıralamaya girmez';

  @override
  String get chatGameImReady => 'Hazırım';

  @override
  String get chatGameUnready => 'Henüz hazır değilim';

  @override
  String get chatGameTakeSeat => 'Katılmak için dokun';

  @override
  String get chatGameLeaveSeat => 'Koltuktan kalk';

  @override
  String get chatGameStartsWhenReady => 'Herkes hazır olunca başlar';

  @override
  String chatGameNeedPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oyuncu daha bekleniyor',
    );
    return '$_temp0';
  }

  @override
  String get chatGameWatchingLabel => 'İzleyenler';

  @override
  String get chatGameAskSwap => 'Yer değiştirmeyi iste';

  @override
  String chatGameSwapRequest(String name) {
    return '$name yerine geçmek istiyor';
  }

  @override
  String get chatGameSwap => 'Değiştir';

  @override
  String get chatGameDecline => 'Reddet';

  @override
  String get chatGameAccept => 'Kabul et';

  @override
  String chatGameSwapAsked(String name) {
    return '$name adlı kişiye soruldu';
  }

  @override
  String get chatGameCancel => 'Vazgeç';

  @override
  String get chatGameResign => 'Pes et';

  @override
  String get chatGameResignConfirm => 'Bu oyundan pes mi ediyorsun?';

  @override
  String get chatGameResignBody => 'Bu senin için yenilgi sayılır.';

  @override
  String get chatGameOfferDraw => 'Beraberlik teklif et';

  @override
  String get chatGameDrawOffered => 'Beraberlik teklif edildi';

  @override
  String chatGameDrawOfferFrom(String name) {
    return '$name beraberlik teklif ediyor';
  }

  @override
  String chatGamePausedTitle(String name) {
    return '$name oyundan ayrıldı';
  }

  @override
  String get chatGamePausedMany => 'Oyuncular oyundan ayrıldı';

  @override
  String get chatGamePausedBody => 'Tahtayı bir süre bekletiyoruz.';

  @override
  String get chatGamePausedYou => 'Herkes dönünce oyun devam eder.';

  @override
  String get chatGameLeave => 'Oyundan ayrıl';

  @override
  String get chatGameGo => 'Başla!';

  @override
  String get chatGameNudge => 'Dürt';

  @override
  String get chatGameNudged => 'Dürtüldü';

  @override
  String chatGameHoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saat kaldı',
    );
    return '$_temp0';
  }

  @override
  String chatGameMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dakika kaldı',
    );
    return '$_temp0';
  }

  @override
  String get chatGameMoveFailed => 'Bu hamle gönderilemedi';

  @override
  String get chatGameStale => 'Tahta değişti. Tekrar dene.';

  @override
  String get chatGameStartTitle => 'Oyun oyna';

  @override
  String get chatGameMenuItem => 'Oyun';

  @override
  String get chatGameModeLive => 'Canlı';

  @override
  String get chatGameBotEasyHint => 'Hata yapar. Öğrenmek için ideal.';

  @override
  String get chatGameBotMediumHint => 'Adil oynar, kazanmanı engeller.';

  @override
  String get chatGameBotHardHint => 'Birkaç hamle ilerisini düşünür.';

  @override
  String get chatGameStart => 'Başlat';

  @override
  String get chatGameErrAlreadyLive =>
      'Burada zaten canlı bir oyun var. Önce onu bitir ya da ondan ayrıl.';

  @override
  String get chatGameErrTooMany =>
      'Burada zaten 3 sıralı oyunun var. Önce birini bitir.';

  @override
  String get chatGameErrEphemeral =>
      'Mesajların kaybolduğu bir sohbette oyun oynanamaz.';

  @override
  String get chatGameErrGeneric => 'Bir şeyler ters gitti. Tekrar dene.';

  @override
  String get chatGamePlayersTwo => '2 oyuncu';

  @override
  String get chatGamePlayersUpToFour => '2–4 oyuncu';

  @override
  String get chatGameBotName => 'Maymun';

  @override
  String get chatGameBotBadge => 'Bot';

  @override
  String get chatGameNewGame => 'Yeni oyun';

  @override
  String chatGameBannerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oyun',
    );
    return '$_temp0';
  }

  @override
  String chatGameBannerYourMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oyunda sıra sende',
    );
    return '$_temp0';
  }

  @override
  String get chatGameSheetTitle => 'Bu sohbetteki oyunlar';

  @override
  String get chatGameGone => 'Bu oyun artık mevcut değil.';

  @override
  String get chatGameSeatsLabel => 'Oyuncular';

  @override
  String get gameFlowName => 'Akış';

  @override
  String get gameFutoshikiName => 'Futoshiki';

  @override
  String get gameNonogramName => 'Nonogram';

  @override
  String get gameMinesweeperName => 'Mayın tarlası';

  @override
  String get gameStarbattleName => 'Yıldız savaşı';

  @override
  String get gamePatchesName => 'Yamalar';

  @override
  String get gameFlowRule => 'aynı noktaları birleştir, her kareyi doldur';

  @override
  String get gameFutoshikiRule =>
      'her satır ve sütunda 1\'den 5\'e birer kez, her işaret doğru';

  @override
  String get gameNonogramRule => 'her ipucuna uyacak şekilde kareleri boya';

  @override
  String get gameMinesweeperRule => 'güvenli her kareyi aç, tahmin gerekmez';

  @override
  String get gameStarbattleRule =>
      'her satır, sütun ve renkte iki yıldız, asla bitişik değil';

  @override
  String get gamePatchesRule =>
      'tahtayı dikdörtgenlere böl, her birinde bir ipucu';

  @override
  String get gameFlag => 'Bayrak';

  @override
  String get gameAutoDot => 'Otomatik nokta';

  @override
  String boardCellName(int row, int col) {
    return 'Satır $row, sütun $col';
  }

  @override
  String get boardEmpty => 'boş';

  @override
  String get boardBlack => 'siyah';

  @override
  String get boardWhite => 'beyaz';

  @override
  String get boardLegalMove => 'geçerli hamle';

  @override
  String get boardMoveHere => 'buraya oyna';

  @override
  String boardColumnFilled(int column, int count, int total) {
    return 'Sütun $column, $total yerden $count dolu';
  }

  @override
  String boardSquareName(int number) {
    return 'Kare $number';
  }

  @override
  String get boardDarkMan => 'koyu taş';

  @override
  String get boardDarkKing => 'koyu dama';

  @override
  String get boardLightMan => 'açık taş';

  @override
  String get boardLightKing => 'açık dama';

  @override
  String boardBoxName(String cell) {
    return 'Kutu, $cell';
  }

  @override
  String get boardOpen => 'açık';

  @override
  String get boardDrawn => 'çizildi';

  @override
  String boardClaimedBy(String name) {
    return '$name aldı';
  }

  @override
  String boardHorizontalEdge(int row, int col) {
    return 'Yatay çizgi, satır $row, sütun $col';
  }

  @override
  String boardVerticalEdge(int row, int col) {
    return 'Dikey çizgi, satır $row, sütun $col';
  }

  @override
  String get challengeAction => 'Meydan oku';

  @override
  String get challengeTitle => 'Süremi geç';

  @override
  String get challengeKind => 'Günlük meydan okuma';

  @override
  String challengeYouBeat(String time) {
    return '$time farkla geçtin';
  }

  @override
  String challengeStillStanding(String time) {
    return '$time farkla hâlâ ayakta';
  }

  @override
  String get challengeTie => 'Tam berabere';

  @override
  String get challengeClosed => 'O tahta kapandı';

  @override
  String get challengeYourTime => 'Geçilmesi gereken süren';

  @override
  String get challengeSent => 'Meydan okuma gönderildi';

  @override
  String challengeTarget(String name, String time) {
    return '$name $time';
  }

  @override
  String challengeBeatName(String name, String time) {
    return '$name adlı kişinin $time süresini geçtin';
  }

  @override
  String challengeKept(String name, String time) {
    return '$name $time farkla korudu';
  }

  @override
  String challengeBackName(String name) {
    return '$name adlı kişiye meydan oku';
  }

  @override
  String challengeBackRoom(String room) {
    return '$room grubunda yanıtla';
  }

  @override
  String challengeFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arkadaşın oynadı',
      one: '1 arkadaşın oynadı',
      zero: 'Buradaki arkadaşlarından henüz oynayan yok',
    );
    return '$_temp0';
  }

  @override
  String challengeYouAndFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sen ve $count arkadaşın oynadınız',
      one: 'Sen ve 1 arkadaşın oynadınız',
      zero: 'Şimdilik sadece sen oynadın',
    );
    return '$_temp0';
  }

  @override
  String get challengeFriendsOnlyNote =>
      'Burada sadece arkadaşların görünür. Bu sohbetteki diğer kişiler de oynamış olabilir.';

  @override
  String get chatGameNameLiarsDice => 'Yalancı Zar';

  @override
  String get chatGameNameImposter => 'Sahtekâr';

  @override
  String get chatGameNameRace => 'Bulmaca Yarışı';

  @override
  String get chatGameDescLiarsDice =>
      'Gizli zarlara teklif ver. Yalancıyı yakala.';

  @override
  String get chatGameDescImposter => 'Biriniz kelimeyi bilmiyor. Onu bulun.';

  @override
  String get chatGameDescRace =>
      'Herkese aynı bulmaca. En hızlı çözen kazanır.';

  @override
  String chatGamePlayersRange(int min, int max) {
    return '$min–$max oyuncu';
  }

  @override
  String chatGameNeedsPeople(int count) {
    return 'En az $count kişi gerekli';
  }

  @override
  String get chatGameVoiceOption => 'Sesli ipuçları';

  @override
  String get chatGameVoiceOptionHint =>
      'İpuçlarını yazmak yerine aramada söyleyin';

  @override
  String get chatGamePuzzleOption => 'Bulmaca';

  @override
  String get chatGamePuzzleRandom => 'Rastgele';

  @override
  String chatGameStartNamed(String game) {
    return '$game başlat';
  }

  @override
  String chatGameLdRoundDice(int count, int round) {
    return '$round. tur · $count zar';
  }

  @override
  String get chatGameLdYourDice => 'Zarların';

  @override
  String get chatGameLdNoBid => 'Henüz teklif yok';

  @override
  String chatGameLdBidBy(String name) {
    return 'Teklif: $name';
  }

  @override
  String get chatGameLdYourBid => 'Senin teklifin';

  @override
  String get chatGameLdBid => 'Teklif ver';

  @override
  String get chatGameLdLiar => 'Yalancı!';

  @override
  String get chatGameLdOnesWild => '1\'ler jokerdir';

  @override
  String get chatGameLdOnesOnly => '1 teklifinde joker yok';

  @override
  String get chatGameLdHolds => 'Teklif tuttu';

  @override
  String get chatGameLdBusted => 'Yakalandı!';

  @override
  String chatGameLdThereWere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tane vardı',
    );
    return '$_temp0';
  }

  @override
  String chatGameLdLosesDie(String name) {
    return '$name bir zar kaybeder';
  }

  @override
  String get chatGameLdYouLoseDie => 'Bir zar kaybettin';

  @override
  String chatGameLdCalled(String name) {
    return '$name yalancı dedi';
  }

  @override
  String chatGameLdTimedOut(String name) {
    return '$name için süre doldu';
  }

  @override
  String get chatGameLdOut => 'Elendi';

  @override
  String get chatGameLdQuantity => 'Kaç tane';

  @override
  String get chatGameLdFace => 'Hangi sayı';

  @override
  String get chatGameLdFewer => 'Azalt';

  @override
  String get chatGameLdMore => 'Artır';

  @override
  String get chatGameLdPrompt => 'Teklifi yükselt ya da yalancı de';

  @override
  String get chatGameLdOpenPrompt => 'İlk teklifi ver';

  @override
  String get chatGameImpHoldToSee => 'Kartını görmek için basılı tut';

  @override
  String get chatGameImpYourWord => 'Kelimen';

  @override
  String get chatGameImpYouAre => 'Sahtekâr sensin';

  @override
  String chatGameImpCategory(String category) {
    return 'Kategori: $category';
  }

  @override
  String get chatGameImpBlendIn => 'Aralarına karış. Kimse bilmiyor.';

  @override
  String get chatGameImpKeepSecret =>
      'Doğrudan söyleme. Diğerlerinin anlayacağı ipuçları ver.';

  @override
  String get chatGameImpGotIt => 'Anladım';

  @override
  String chatGameImpLooked(int count, int total) {
    return '$total kişiden $count kişi baktı';
  }

  @override
  String chatGameImpGiving(String name) {
    return '$name ipucu veriyor';
  }

  @override
  String get chatGameImpYourClue => 'İpucu sırası sende';

  @override
  String get chatGameImpClueHint => 'Bir ile dört kelime';

  @override
  String get chatGameImpClueField => 'İpucun';

  @override
  String get chatGameImpSend => 'Gönder';

  @override
  String get chatGameImpTooManyWords => 'En fazla dört kelime';

  @override
  String get chatGameImpPassed => 'Pas geçti';

  @override
  String get chatGameImpSpoke => 'Aramada söyledi';

  @override
  String get chatGameImpJoinCall => 'Aramaya katıl';

  @override
  String get chatGameImpOnCall => 'Aramadasın';

  @override
  String get chatGameImpVoiceHint =>
      'İpucunu sesli söyle, sonra Bitti\'ye dokun.';

  @override
  String get chatGameImpDone => 'Bitti';

  @override
  String get chatGameImpVoteTitle => 'Sahtekâr kim?';

  @override
  String get chatGameImpVoteHint =>
      'Oy vermek için bir oyuncuya dokun. Süre bitene kadar değiştirebilirsin.';

  @override
  String get chatGameImpSkip => 'Pas geç';

  @override
  String chatGameImpVoted(int count, int total) {
    return '$total kişiden $count kişi oy verdi';
  }

  @override
  String get chatGameImpVotedBadge => 'Oy verdi';

  @override
  String get chatGameImpYourVote => 'Senin oyun';

  @override
  String get chatGameImpGuessing => 'Sahtekâr tahmin ediyor…';

  @override
  String get chatGameImpGuessHint => 'Yakalandın. Kazanmak için kelimeyi bil.';

  @override
  String get chatGameImpGuessField => 'Kelime…';

  @override
  String get chatGameImpGuess => 'Tahmin et';

  @override
  String chatGameImpWas(String name) {
    return 'Sahtekâr $name idi';
  }

  @override
  String get chatGameImpYouWere => 'Sahtekâr sendin';

  @override
  String get chatGameImpTheWord => 'Kelime şuydu';

  @override
  String chatGameImpTheyGuessed(String guess) {
    return 'Tahmin: “$guess”';
  }

  @override
  String chatGameImpVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oy',
    );
    return '$_temp0';
  }

  @override
  String chatGameImpSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kişi pas geçti',
    );
    return '$_temp0';
  }

  @override
  String get chatGameImpReasonEscaped => 'Kimse elenmedi, sahtekâr kaçtı.';

  @override
  String get chatGameImpReasonWrong => 'Ekip yanlış kişiyi eledi.';

  @override
  String get chatGameImpReasonGuessed =>
      'Yakalandı ama sahtekâr kelimeyi bildi.';

  @override
  String get chatGameImpReasonCaught => 'Ekip sahtekârı yakaladı.';

  @override
  String get chatGameImpReasonImposterLeft => 'Sahtekâr oyundan ayrıldı.';

  @override
  String get chatGameImpReasonCrewLeft => 'Ekibin geri kalanı ayrıldı.';

  @override
  String get chatGameImpCrewWon => 'Ekip kazandı';

  @override
  String get chatGameImpYourTeamWon => 'Takımın kazandı';

  @override
  String chatGameImpImposterWon(String name) {
    return '$name sahtekâr olarak kazandı';
  }

  @override
  String get chatGameImpYouWonImposter => 'Sahtekâr olarak kazandın';

  @override
  String get chatGameImpCardReveal => 'Kartlara bakılıyor';

  @override
  String chatGameImpCardClues(int count, int total) {
    return 'İpuçları · $count/$total';
  }

  @override
  String get chatGameImpCardVote => 'Oylama';

  @override
  String chatGameRaceFinishedCount(int count, int total) {
    return '$total kişiden $count kişi bitirdi';
  }

  @override
  String chatGameRaceYouPlaced(int rank) {
    return '$rank. oldun';
  }

  @override
  String get chatGameRaceWaiting => 'Diğerleri bekleniyor';

  @override
  String get chatGameRaceTimeUp => 'Süre doldu. Kimse bitiremedi.';

  @override
  String get chatGameRaceDnf => 'Bitiremedi';

  @override
  String get chatGameRaceLeft => 'Ayrıldı';

  @override
  String get chatGameRaceResults => 'Sonuçlar';

  @override
  String get chatGameRaceSolved => 'Çözdün!';

  @override
  String get chatGamePartyLeaveConfirm => 'Oyundan ayrılıyor musun?';

  @override
  String get chatGamePartyLeaveBody => 'Diğerleri sensiz devam eder.';

  @override
  String get chatGameErrTooLate => 'Geç kaldın, süre doldu';

  @override
  String get chatGameErrBadClue =>
      'Bu ipucu kullanılamaz. Bir ile dört kelime, bağlantı yok.';

  @override
  String get chatGameErrBadGuess => 'Önce bir tahmin yaz';

  @override
  String get chatGameErrNotSolved => 'Bulmaca henüz çözülmedi';

  @override
  String get chatGameNameChess => 'Satranç';

  @override
  String get chatGameDescChess => 'Şah mat eden kazanır.';

  @override
  String get chessPawn => 'piyon';

  @override
  String get chessKnight => 'at';

  @override
  String get chessBishop => 'fil';

  @override
  String get chessRook => 'kale';

  @override
  String get chessQueen => 'vezir';

  @override
  String get chessKing => 'şah';

  @override
  String chessPieceWhite(String piece) {
    return '$piece, beyaz';
  }

  @override
  String chessPieceBlack(String piece) {
    return '$piece, siyah';
  }

  @override
  String chessPromoteTo(String piece) {
    return '$piece olarak terfi et';
  }

  @override
  String get kbdPeekDontShowAgain => 'Bir daha gösterme';

  @override
  String get kbdPeekTurnedOff =>
      'Tamamdır, artık çıkmayacak. İstersen Ayarlar\'dan geri açabilirsin.';

  @override
  String get chatGameBadgeTurns => 'Sırayla';

  @override
  String get chatGameSectionBoards => 'Masa oyunları';

  @override
  String get chatGameSectionParty => 'Parti oyunları';

  @override
  String get chatGameBoardsHintDm =>
      'İster şimdi canlı oynayın, ister boş buldukça sırayla.';

  @override
  String get chatGameBoardsHintGroup =>
      'Burada canlı oynanır. Yerini kap ya da izle.';

  @override
  String get chatGamePartyHint =>
      'Herkes aynı anda oynuyor, önce ekibi toplayın.';

  @override
  String get chatGameLiveTitle => 'Canlı oyna';

  @override
  String get chatGameLiveNow => 'Herkes aynı anda, hemen şimdi oynar.';

  @override
  String get chatGameLivePause =>
      'Biri çıkarsa oyun durur. 2 dakikada dönmezse hükmen kaybeder.';

  @override
  String get chatGameTurnsTitle => 'Sırayla oyna';

  @override
  String get chatGameTurnsAnytime =>
      'Ne zaman istersen hamleni yap. Her hamle sohbete düşer.';

  @override
  String get chatGameTurnsClock =>
      'Her hamle için 2 gün var. Biz hatırlatırız, sen de dürtebilirsin.';

  @override
  String get chatGameHowWillYouPlay => 'Nasıl oynamak istersin?';

  @override
  String get botHubTitle => 'Bota karşı oyna';

  @override
  String botHubSubtitle(String bot) {
    return 'Sadece sen ve $bot. Hamleleri öğren, sonra arkadaşlarını yen.';
  }

  @override
  String get botHubLevelTitle => 'Ne kadar zor olsun?';

  @override
  String get botHubPickGame => 'Bir oyun seç';

  @override
  String get botHubCaption => 'Antrenman';

  @override
  String botHubGameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oyun',
      one: '1 oyun',
    );
    return '$_temp0';
  }

  @override
  String get practiceNotRanked =>
      'Sadece eğlence için. Bu oyunlar serilerine ya da rekorlarına katılmaz.';

  @override
  String get chatGameMvYouPlayed => 'Sen oynadın';

  @override
  String chatGameMvTheyPlayed(String name) {
    return '$name oynadı';
  }

  @override
  String chatGameMvNumber(int count) {
    return '$count. hamle';
  }

  @override
  String chatGameMvColumn(int count) {
    return '$count. sütun';
  }

  @override
  String get chatGameMvEarlier => 'Önceki hamle';

  @override
  String get chatGameMvSend => 'Hamleyi gönder';

  @override
  String get chatGameMvUndo => 'Geri al';

  @override
  String get chatGameMvStagedHint =>
      'Henüz gitmedi. Fikrini değiştir ya da Gönder\'e bas.';

  @override
  String get chatGameMvSentToast => 'Hamlen gitti. Sıra onda.';

  @override
  String get chatGameMvYourTurnSub => 'Hamleni yap, sonra gönder. Acele yok.';

  @override
  String get chatGameMvWaitingSub => 'Sıra sana gelince haber veririz.';

  @override
  String get chatGameMvNudgeLater => '12 saat ses çıkmazsa dürtebilirsin';

  @override
  String get chatGameMvForfeitNote => 'Süre biterse sırası olan kaybeder';

  @override
  String get chatGameMvAgain => 'Sıra hâlâ sende. Devam!';

  @override
  String get chatGameMvSending => 'Gönderiliyor…';

  @override
  String get howToNext => 'İleri';

  @override
  String get howToWatchAgain => 'Tekrar izle';

  @override
  String get howToGotIt => 'Tamamdır';

  @override
  String get howToProTip => 'Taktik';

  @override
  String howToStepSemantic(int step, int total) {
    return 'Adım $step/$total';
  }

  @override
  String get howToQueens1 => 'Her satıra, her sütuna ve her renge bir taç.';

  @override
  String get howToQueens2 => 'Taçlar birbirine değemez. Çaprazdan bile.';

  @override
  String get howToQueens3 =>
      'Bir kere dokun ×, iki kere taç, bir daha dokunursan silinir.';

  @override
  String get howToQueens4 =>
      'Otomatik çarpı açıkken, bir tacın elediği her kareye senin yerine × konur. Sonra geriye ne kaldığına bak.';

  @override
  String get howToTango1 =>
      'Bir kere dokun güneş, iki kere ay. Bütün kareleri doldur.';

  @override
  String get howToTango2 => 'Her satır ve sütunun yarısı güneş, yarısı ay.';

  @override
  String get howToTango3 =>
      'Aynı şeyden 3 tane yan yana ya da alt alta gelemez. 2 tamam.';

  @override
  String get howToTango4 => '= varsa ikisi aynı, × varsa ikisi farklı.';

  @override
  String get howToTangoTip =>
      'Yan yana iki aynı mı var? İki ucundaki kareler diğeri olur.';

  @override
  String get howToZip1 => '1\'den başla, sayıların üstünden sırayla geç.';

  @override
  String get howToZip2 => 'Bütün karelerden geç, son sayıda bitir.';

  @override
  String get howToZip3 => 'Yanlış mı döndün? Geri sürükle, silinsin.';

  @override
  String get howToZipTip =>
      'Bir kareyi yalnız bırakma. Köşeleri ve kenarları geçerken topla.';

  @override
  String get howToSudoku1 =>
      'Her satır, sütun ve kutuda 1\'den 6\'ya kadar her sayı bir kere. Tekrar yok.';

  @override
  String get howToSudoku2 => 'Kareye dokun, sonra sayıya dokun.';

  @override
  String get howToSudoku3 =>
      'Bir satırda, sütunda ya da kutuda aynı sayı iki kere mi var? Kırmızı yanar.';

  @override
  String get howToSudoku4 =>
      'Sadece bir sayısı eksik olan satır ve sütunları kolla. Bedava puan.';

  @override
  String get howToFlow1 => 'Bir noktadan eşine sürükle, boruyu çek.';

  @override
  String get howToFlow2 =>
      'Borular kesişemez, her kare de dolmalı. Gerekirse dolaş.';

  @override
  String get howToFlowTip =>
      'Önce boruları kenarlardan geçir. Ortası kendiliğinden çözülür.';

  @override
  String get howToFutoshiki1 =>
      'Her kareyi 1\'den 5\'e kadar bir sayıyla doldur. Her satır ve sütunda her sayı tam bir kere.';

  @override
  String get howToFutoshiki2 => 'İşaretin sivri ucu küçük sayıyı gösterir.';

  @override
  String get howToFutoshiki3 => 'İşareti bozarsan kırmızı yanar.';

  @override
  String get howToFutoshikiTip =>
      'Zincirleri takip et: a < b < c ise c en az 3’tür.';

  @override
  String get howToNonogram1 =>
      'Her sayı, aralıksız boyanacak kare sayısıdır. 5, yan yana 5 kare demek.';

  @override
  String get howToNonogram2 =>
      '1 1, arasında en az bir boş kare olan iki tek kare demek. Boşluk daha büyük de olabilir.';

  @override
  String get howToNonogramOrder =>
      'Sıra önemli: satırlar soldan sağa, sütunlar yukarıdan aşağıya okunur. Yani 1 3, önce 1 sonra 3 demek.';

  @override
  String get howToNonogram3 =>
      'Dokun boyansın, bir daha × olsun, bir daha silinsin. Sürükle, bir sürü kareyi tek seferde hallet.';

  @override
  String get howToNonogram4 =>
      'Bütün ipuçlarını tuttur, gizli resim ortaya çıksın.';

  @override
  String get howToNonogramTip =>
      'Büyük ipuçlarıyla başla. 10 karelik bir satırdaki 7, ortadaki 4 kareyi her zaman kaplar.';

  @override
  String get howToMines1 =>
      'Mayın olmayan bütün kareleri aç. Boş alanlar kendiliğinden açılır.';

  @override
  String get howToMines2 =>
      'Sayı, o kareye değen mayın sayısı. Çaprazlar da dahil.';

  @override
  String get howToMines3 =>
      'Mayın olduğundan emin misin? Basılı tut, bayrağı dik.';

  @override
  String get howToMines4 =>
      'Mayına basarsan 30 saniye ceza yersin. Ama hiçbir zaman tahmin etmen gerekmez.';

  @override
  String get howToMinesTip =>
      'Yanında tek bir kapalı kare olan bir 1 mi var? Mayın o karede.';

  @override
  String get howToStars1 => 'Her satıra, her sütuna ve her renge 2 yıldız.';

  @override
  String get howToStars2 => 'Yıldızlar birbirine değemez. Çaprazdan bile.';

  @override
  String get howToStarsControls =>
      'Bir kere dokun nokta, iki kere yıldız, bir daha dokunursan silinir.';

  @override
  String get howToStars3 =>
      'Otomatik nokta açıkken, bir yıldız etrafındaki kareleri noktayla kapatır. Bir satır 2 yıldızını bulunca geri kalanı da noktalanır.';

  @override
  String get howToPatches1 =>
      'Tahtayı dikdörtgenlere böl. Her birinde tam olarak bir ipucu olmalı.';

  @override
  String get howToPatches2 =>
      'Rozet yamanın şeklidir: kare, uzun ya da geniş. Kesik çizgili rozet, bu üçünden herhangi biri olabilir demek. Sayı varsa, yamanın kaç kareyi kapladığını söyler.';

  @override
  String get howToPatches3 =>
      'Yama kesmek için köşeden köşeye sürükle. Kaldırmak için yamaya dokun.';

  @override
  String get howToPatches4 =>
      'Kenara dayanan büyük bir ipucu çoğu zaman tek şekilde sığar. Oradan başla.';

  @override
  String get howToCode1 =>
      '4 farklı sembolden oluşan gizli bir şifre var, hiçbiri tekrar etmiyor. Çöz bakalım.';

  @override
  String get howToCode2 => 'Yeşil: sembol de doğru, yeri de.';

  @override
  String get howToCode3 =>
      'Sarı: şifrede var ama yeri başka. Gri: şifrede hiç yok.';

  @override
  String get howToCode4 =>
      '6 hakkın var. Ne kadar az denemede bulursan o kadar iyi.';

  @override
  String get howToCodeTip =>
      'İlk tahminlerini yeni sembollere harca. Öğrenmek, tahmin etmekten iyidir.';

  @override
  String get howToTtt1 =>
      'Sırayla işaretini koy. 3\'ünü yan yana dizen kazanır.';

  @override
  String get howToTtt2 =>
      'Rakip 2 tane dizdi mi? Üçüncü kareyi ondan önce kap.';

  @override
  String get howToC41 =>
      'Bir sütuna dokun, pulu bırak. Pul en alttaki boş yere düşer.';

  @override
  String get howToC42 =>
      '4\'ünü yan yana dizen kazanır: yatay, dikey ya da çapraz.';

  @override
  String get howToC4Tip =>
      'Ortadaki sütunu oyna. Diğerlerinden daha çok dörtlünün parçası.';

  @override
  String get howToCheckers1 =>
      'Taşlar çapraz bir kare ileri gider. Önce taşa, sonra gideceği kareye dokun.';

  @override
  String get howToCheckers2 =>
      'Rakip taşın üstünden atla, onu al. Alabiliyorsan almak zorundasın. Almak zorunda olan taşın etrafında halka yanar.';

  @override
  String get howToCheckers3 =>
      'İndiğin yerden bir daha atlayabiliyor musun? Devam et. Tek hamlede birkaç taş alabilirsin.';

  @override
  String get howToCheckers4 =>
      'Karşı tarafa ulaşan taş dama olur. Dama geri de gidebilir ama yine sadece bir kare gider, uzağa uçamaz.';

  @override
  String get howToCheckersWin =>
      'Rakibin tüm taşlarını al ya da onu hamlesiz bırak, kazan. Taş alınmadan ve düz taş oynanmadan ikişer 40 hamle geçerse berabere.';

  @override
  String get howToCheckersTip =>
      'Arka sıranı yerinde tut. Rakibin dama çıkarmasını engeller.';

  @override
  String get howToReversi1 =>
      'Pulunu öyle bir yere koy ki rakibin bir sıra pulu iki pulunun arasında sıkışsın. Her hamle en az bir pul sıkıştırmalı.';

  @override
  String get howToReversi2 =>
      'Sıkışan her pul senin rengine döner. Hem de her yönde aynı anda.';

  @override
  String get howToReversi3 =>
      'Oynayacak hamlen yok mu? Sıran atlanır. Kimse oynayamayınca en çok pulu olan kazanır.';

  @override
  String get howToReversiTip => 'Köşeleri kap. Köşedeki taş asla çevrilemez.';

  @override
  String get howToDots1 => 'Sırayla iki nokta arasına çizgi çekin.';

  @override
  String get howToDots2 => 'Kutuyu kapatan alır. Üstüne bir daha oynar!';

  @override
  String get howToDots3 =>
      'Bir kutunun üçüncü kenarına dikkat. Onu çizersen kutuyu sıradakine hediye edersin.';

  @override
  String get howToDotsWin =>
      'Son çizgi çekildiğinde en çok kutusu olan kazanır.';

  @override
  String get howToChess1 =>
      'Taşa dokun, nereye gidebildiğini gör. Sonra bir kareye dokun.';

  @override
  String get howToChess2 => 'Rakip taşın üstüne git, onu al.';

  @override
  String get howToChess3 =>
      'Piyonu son sıraya getir, vezir olsun. Ya da ne seçersen o.';

  @override
  String get howToChess4 =>
      'Şah çekildiyse şahın saldırı altında demek, hemen kurtar. Kaçacak yer yoksa şah mat, oyun biter. Şah çekilmediği hâlde oynayacak hamle yoksa berabere.';

  @override
  String get howToChessTip =>
      'Her hamleden önce rakibin neyi alabileceğine bak.';

  @override
  String get howToLiars1 =>
      'Herkes gizlice 5 zar atar. Sen sadece kendi zarlarını görürsün.';

  @override
  String get howToLiars2 =>
      'Sıran gelince, masada bir sayıdan en az kaç tane olduğunu iddia et. Herkesin zarı sayılır. Mesela “dört tane 3”.';

  @override
  String get howToLiars3 =>
      '1\'ler joker: her sayı yerine geçer. Tabii teklif 1\'ler üzerine değilse.';

  @override
  String get howToLiars4 =>
      'Sıradaki oyuncu teklifi yükseltmek zorunda: ya daha çok zar ya da aynı adette daha büyük bir sayı…';

  @override
  String get howToLiars5 =>
      '…ya da “Yalancı!” der. Herkes zarlarını açar, birlikte sayılır.';

  @override
  String get howToLiars6 =>
      'En az o kadar var mı? “Yalancı” diyen bir zar kaybeder. Daha az mı? Teklifi veren kaybeder.';

  @override
  String get howToLiars7 =>
      'Zarın bittiyse oyundan çıkarsın. Elinde zar kalan son kişi kazanır.';

  @override
  String get howToLiarsClock =>
      'Her sıra 45 saniye. Süren biterse oyun senin yerine oynar.';

  @override
  String get howToLiarsTip =>
      'Önce kendi zarlarını say. 1’ler joker olduğu için diğerlerinin zarlarının yaklaşık üçte biri söylediğin yüze uyar.';

  @override
  String get howToImposter1 =>
      'Herkese aynı gizli kelime gelir. Sahtekâr hariç: ona sadece kategori gelir.';

  @override
  String get howToImposter2 =>
      'Sırayla kısa bir ipucu verin. Kelimeyi bildiğini göster ama ele verme.';

  @override
  String get howToImposterVoice =>
      'Sesli modda ipucunu aramada yüksek sesle söyle, sonra Bitti\'ye dokun.';

  @override
  String get howToImposter3 =>
      'Sonra herkes sahtekâr sandığı kişiye oy verir ya da pas geçer.';

  @override
  String get howToImposter4 =>
      'Yakalandı mı? Sahtekârın son bir şansı var: kelimeyi bilirse galibiyeti kapar. Yanlış kişi mi seçildi, oylar mı eşit çıktı ya da çok kişi mi pas geçti? Sahtekâr kazanır.';

  @override
  String get howToRace1 => 'Herkese aynı anda aynı yepyeni bulmaca gelir.';

  @override
  String get howToRace2 =>
      'Kendi telefonunda çöz. İlerleme çubuğun, ne kadar yaklaştığını herkese gösterir.';

  @override
  String get howToRace3 => 'İlk bitiren kazanır. 10 dakikan var.';

  @override
  String get howToLive1 =>
      'Herkes aynı anda oynar. Herkes Hazırım\'a dokununca oyun başlar.';

  @override
  String get howToLive2 =>
      'Biri oyundan mı çıktı? Oyun herkes için durur. Geri dönmek için 2 dakikası var, yoksa hükmen kaybeder.';

  @override
  String get howToLive3 =>
      'Sohbetteki diğerleri izleyebilir. Yer isteyebilirler, oyunculardan biri de yerini devredebilir.';

  @override
  String get howToTurns1 =>
      'Hamleni yap, sonra Hamleyi gönder\'e dokun. Sohbete mesaj olarak düşer.';

  @override
  String get howToTurns2 =>
      'Her hamle için 2 gün var. 20 saat sonra biz hatırlatırız, 12 saat ses çıkmazsa sen de dürtebilirsin.';

  @override
  String get howToTurns3 =>
      '2 gün içinde hamle yapmazsan yenilmiş sayılırsın. Bir sohbette aynı anda en fazla 3 oyun.';

  @override
  String momentActivityGamesSolvedAll(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oyun',
    );
    return '$name $_temp0 çözdü';
  }

  @override
  String momentActivityGamesSolvedSome(int count, String name, int solved) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oyunun',
    );
    return '$name $_temp0 $solved tanesini çözdü';
  }

  @override
  String momentActivityGamesPlayed(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oyun',
    );
    return '$name $_temp0 oynadı';
  }

  @override
  String momentActivityHighlightsPosted(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count an',
    );
    return '$name $_temp0 paylaştı';
  }

  @override
  String podiumSharedBy(int count, String names, int place) {
    return '$place. sıra, $count kişi paylaşıyor: $names';
  }

  @override
  String get myBestsLabel => 'Rekorlarım';

  @override
  String recordsSharedBy(int count, String name) {
    return '$name +$count';
  }

  @override
  String get reportSheetDisclosureMessage =>
      'Şikayet etmek bu mesajı ve bu sohbetteki son birkaç mesajı incelenmek üzere MonkeyHub moderatörlerine gönderir. Kişi şikayet ettiğini bilmez.';

  @override
  String get reportSheetDisclosureUser =>
      'Şikayet etmek bu kişiyle son birkaç mesajını incelenmek üzere MonkeyHub moderatörlerine gönderir. Şikayet ettiğini bilmezler.';

  @override
  String get reportSheetDisclosureRoom =>
      'Şikayet etmek bu gruptaki son birkaç mesajı incelenmek üzere MonkeyHub moderatörlerine gönderir. Buradaki kimse şikayet ettiğini bilmez.';

  @override
  String get reportSheetAlsoBlock => 'Bu kişiyi engelle';

  @override
  String get reportSentReviewed =>
      'Teşekkürler. Moderatörlerimiz şikayetleri 24 saat içinde inceler.';

  @override
  String get reportSentAndBlocked =>
      'Teşekkürler. Moderatörlerimiz şikayetleri 24 saat içinde inceler. Bu kişiyi engelledin.';

  @override
  String get reportTooMany =>
      'Çok fazla şikayet gönderdin. Biraz sonra tekrar dene.';

  @override
  String get reportFailed => 'Şikayet gönderilemedi. Tekrar dene.';

  @override
  String get riReportPerson => 'Bu kişiyi şikayet et';

  @override
  String get riReportGroup => 'Bu grubu şikayet et';

  @override
  String get moderationActionRemoveMessage => 'Mesajı kaldır';

  @override
  String get moderationActionBan => 'Kullanıcıyı yasakla';

  @override
  String get moderationActionUnban => 'Yasağı kaldır';

  @override
  String get moderationActionDismiss => 'Şikayeti kapat';

  @override
  String get moderationConfirmRemoveTitle => 'Bu mesaj kaldırılsın mı?';

  @override
  String get moderationConfirmRemoveBody =>
      'Sohbetteki herkes için silinir. Şikayet kartı kendi kopyasını saklar.';

  @override
  String get moderationConfirmBanTitle => 'Bu hesap yasaklansın mı?';

  @override
  String get moderationConfirmBanBody =>
      'Her yerde oturumu kapanır, tekrar giriş yapamaz, aramada görünmez ve tüm herkese açık odalardan çıkar. Yasağı bu karttan kaldırabilirsin.';

  @override
  String get moderationActionDone => 'Tamam';

  @override
  String get moderationActionFailed => 'Bu işlem tamamlanamadı. Tekrar dene.';

  @override
  String get moderationCantBan =>
      'Moderatörler ve sistem hesapları yasaklanamaz.';

  @override
  String get messageFilterBlocked =>
      'Bu mesaj uygunsuz ifadeler içerebileceği için gönderilemiyor.';

  @override
  String get nameInappropriate =>
      'Bu ad uygunsuz ifadeler içerebilir. Lütfen başka bir ad seç.';

  @override
  String get authErrorAccountSuspended =>
      'Hesabın Kullanım Koşulları\'nı ihlal ettiği için askıya alındı.';

  @override
  String get authErrorLastGuardian =>
      'Bir çocuk hesabının tek velisisin. Önce başka bir veli ekle ya da çocuk hesabını sil.';

  @override
  String get authSuspendedDeleteAction => 'Hesabımı sil';

  @override
  String get authSuspendedDeleteFailed =>
      'Hesabın buradan silinemedi. Lütfen destekle iletişime geç, birlikte halledelim.';

  @override
  String get termsConsentPrefix => '';

  @override
  String get termsConsentLink => 'Kullanım Koşulları\'nı (EULA)';

  @override
  String get termsConsentSuffix =>
      ' kabul ediyorum ve uygunsuz içeriğe ya da taciz eden kullanıcılara hiçbir şekilde tolerans gösterilmediğini anlıyorum.';

  @override
  String get termsConsentSemanticLabel => 'Kullanım Koşulları\'nı kabul et';

  @override
  String get termsMustAccept =>
      'Devam etmek için lütfen Kullanım Koşulları\'nı kabul et.';

  @override
  String get termsSheetTitle => 'Kullanım Koşulları';

  @override
  String get termsSheetBody =>
      'MonkeyHub\'ı kullanmaya devam etmek için lütfen Kullanım Koşulları\'nı kabul et. Burada uygunsuz içeriğe ya da taciz edici davranışa yer yok ve şikayet edilen içerikler moderatörlerimiz tarafından incelenir.';

  @override
  String get termsSheetAccept => 'Kabul et ve devam et';

  @override
  String get termsAcceptFailed => 'Kaydedilemedi. Tekrar dene.';

  @override
  String get settingsHubContactSupport => 'Destekle iletişime geç';

  @override
  String get reportSheetDisclosureMoment =>
      'Şikayet etmek bu anı incelenmek üzere MonkeyHub moderatörlerine gönderir. Kişi şikayet ettiğini bilmez.';

  @override
  String get reportSheetDisclosureComment =>
      'Şikayet etmek bu yorumu incelenmek üzere MonkeyHub moderatörlerine gönderir. Kişi şikayet ettiğini bilmez.';

  @override
  String get sendLimitRateLimited =>
      'Çok hızlı gönderiyorsun. Biraz bekleyip tekrar dene.';

  @override
  String get sendLimitStorageFull =>
      'Depolama alanın dolu. Yer açmak için gönderdiğin bazı fotoğrafları veya dosyaları sil.';

  @override
  String get sendLimitFileTooLarge => 'Bu dosya göndermek için çok büyük.';

  @override
  String get sendLimitMessageTooLong =>
      'Bu mesaj çok uzun. Birkaç mesaja bölmeyi dene.';

  @override
  String get limitTooOften =>
      'Bunu çok sık yapıyorsun. Biraz sonra tekrar dene.';

  @override
  String get limitRoomFull => 'Bu oda dolu.';

  @override
  String get limitRemovedFromRoom =>
      'Bu odadan çıkarıldın. Bir yönetici seni tekrar davet edebilir.';

  @override
  String get limitTooManyRooms =>
      'Çok fazla odadasın. Önce artık kullanmadığın birinden ayrıl.';

  @override
  String get limitRoomTextTooLong =>
      'Bu ad veya açıklama çok uzun. Adlar 100, açıklamalar 500 karakterden kısa olmalı.';

  @override
  String get limitNotYourFile =>
      'Bu dosya kullanılamıyor. Tekrar seçip yeniden dene.';

  @override
  String get limitDeviceLoginBusy =>
      'Giriş kodları şu an yoğun. Bir dakika sonra tekrar dene.';

  @override
  String get limitRequestMessages =>
      'İsteğini kabul edene kadar daha fazla gönderemezsin.';

  @override
  String get mediaSendViewOnceTip => 'Yalnızca bir kez açabilir';

  @override
  String get mediaSendSpoilerTip => 'Dokunana kadar tozun altında gizli';

  @override
  String get mediaSendSpoilerNote => 'Dokununca görünür';

  @override
  String get mediaSendSpoilerOnSemanticLabel => 'Spoiler: açık';

  @override
  String get mediaSendSpoilerOffSemanticLabel => 'Spoiler: kapalı';

  @override
  String get mediaSpoilerRevealSemanticLabel => 'Spoiler. Göstermek için dokun';

  @override
  String get voiceTranscriptShow => 'Metni göster';

  @override
  String get voiceTranscriptHide => 'Metni gizle';

  @override
  String voiceTranscriptCellularPrompt(String size) {
    return 'Bartleby metinleri telefonunda yazar. Önce tek seferlik $size indirme gerekiyor.';
  }

  @override
  String voiceTranscriptDownloadAction(String size) {
    return '$size indir';
  }

  @override
  String voiceTranscriptDownloading(String received, String total) {
    return 'Bartleby hazırlanıyor · $received / $total';
  }

  @override
  String get voiceTranscriptOneTimeNote =>
      'Yalnızca bir kez. Sonrasında metinler internetsiz çalışır.';

  @override
  String get voiceTranscriptCancel => 'Vazgeç';

  @override
  String get voiceTranscriptWorking => 'Metne dönüştürülüyor…';

  @override
  String get voiceTranscriptFailedNetwork => 'Konuşma modeli indirilemedi.';

  @override
  String voiceTranscriptFailedStorage(String size) {
    return 'Yeterli boş alan yok. Konuşma modeli $size gerektiriyor.';
  }

  @override
  String get voiceTranscriptFailedAudio => 'Bu sesli mesaj okunamadı.';

  @override
  String get voiceTranscriptFailed => 'Bu sesli mesaj metne dönüştürülemedi.';

  @override
  String get voiceTranscriptRetry => 'Tekrar dene';

  @override
  String get voiceTranscriptNoSpeech => 'Bu sesli mesajda konuşma yok.';

  @override
  String get voiceTranscriptOnDevice => 'Bu cihazda metne dönüştürüldü';

  @override
  String voiceTranscriptLanguageOnDevice(String language) {
    return '$language · bu cihazda';
  }

  @override
  String get voiceTranscriptCopy => 'Kopyala';

  @override
  String get voiceTranscriptCopied => 'Metin kopyalandı';

  @override
  String get storageKindSpeechModel => 'Sesli mesaj metinleri';

  @override
  String get voiceTranscriptBuiltInCredit => 'Apple konuşma tanıma';

  @override
  String voiceTranscriptBuiltInLanguageCredit(String language) {
    return '$language · Apple konuşma tanıma';
  }

  @override
  String get voiceTranscriptUpgradeLink => 'Daha iyi metinler';

  @override
  String voiceTranscriptUpgradeOffer(String size) {
    return 'Dil ya da kelimeler mi yanlış? Tek seferlik $size indirmeyle Bartleby hangi dilin konuşulduğunu kendisi anlar ve 100\'e yakın dil bilir. Sonrasında internetsiz çalışır.';
  }

  @override
  String get voiceTranscriptNotNow => 'Şimdi değil';

  @override
  String get appOnlyGetApp => 'Uygulamayı indir';

  @override
  String get appOnlyScanHint => 'Uygulamayı indirmek için telefonunla tara';

  @override
  String get appOnlyBlockedInApp =>
      'Uygulamada ekran görüntüsü ve ekran kaydı engellenir';

  @override
  String get appOnlyViewOnceTitle => 'Uygulamada açılır';

  @override
  String appOnlyViewOnceBody(String platform) {
    String _temp0 = intl.Intl.selectLogic(platform, {
      'web':
          'Tarayıcın ekran görüntüsünü engelleyemiyor, bu yüzden tek seferlik mesajlar burada açılmaz. Telefonundaki MonkeyHub\'da ya da bir Mac veya Windows bilgisayarda aç.',
      'other':
          'Linux ekran görüntüsünü engelleyemiyor, bu yüzden tek seferlik mesajlar burada açılmaz. Telefonundaki MonkeyHub\'da ya da bir Mac veya Windows bilgisayarda aç.',
    });
    return '$_temp0';
  }

  @override
  String get appOnlyViewOnceSealed => 'Sen açana kadar mühürlü kalır';

  @override
  String get appOnlySecretTitle => 'Gizli odalar uygulamada açılır';

  @override
  String appOnlySecretBody(String platform) {
    String _temp0 = intl.Intl.selectLogic(platform, {
      'web':
          'Tarayıcın ekran görüntüsünü engelleyemiyor, bu yüzden gizli odalar burada kapalı kalır ve içlerindeki hiçbir şey yüklenmez. Bu odayı telefonundaki MonkeyHub\'da ya da bir Mac veya Windows bilgisayarda aç.',
      'other':
          'Linux ekran görüntüsünü engelleyemiyor, bu yüzden gizli odalar burada kapalı kalır ve içlerindeki hiçbir şey yüklenmez. Bu odayı telefonundaki MonkeyHub\'da ya da bir Mac veya Windows bilgisayarda aç.',
    });
    return '$_temp0';
  }

  @override
  String get appOnlySecretTimers =>
      'Buradaki mesajlar yine de süreleri dolunca kaybolur';

  @override
  String get appOnlySecretPreview => 'Okumak için uygulamada aç';

  @override
  String get appOnlyTranscriptTitle => 'Sesli mesaj metinleri';

  @override
  String get appOnlyTranscriptBody =>
      'MonkeyHub sesli mesajları bir sunucuda değil, kendi cihazında metne çevirir. Tarayıcı bunu yapamaz, bu yüzden metinler telefonundaki ya da bilgisayarındaki uygulamada.';

  @override
  String get appOnlyTranscriptOnDevice => 'Doğrudan cihazında oluşturulur';

  @override
  String get appOnlyTranscriptNoUpload =>
      'Metne çevirmek için hiçbir ses bir yere gönderilmez';

  @override
  String get appOnlyTranscriptOffline =>
      'Kurulduktan sonra internetsiz çalışır';

  @override
  String get liveCallChipVoice => 'Sesli arama';

  @override
  String get liveCallChipVideo => 'Görüntülü arama';

  @override
  String get companionBartlebyTagline => 'Sesli mesajları yazıya döker';

  @override
  String get companionBartlebyBlurb =>
      'Bartleby sesli mesajları dinler ve yazıya döker, hem de burada, telefonunda. Ne ses ne de yazılanlar telefonundan çıkar.';

  @override
  String get bartlebyQuote =>
      '“Sesini hiçbir yere göndermemeyi tercih ederim.”';

  @override
  String get bartlebyStatusEveryLanguage => '100\'e yakın dil için hazır';

  @override
  String get bartlebyStatusBuiltInOnly => 'Yalnızca yerleşik diller';

  @override
  String get bartlebyBuiltInHeader => 'İndirmeden hazır diller';

  @override
  String get bartlebyBuiltInFooter =>
      'Cihazında Siri ve dikte için bunlar zaten var, bu yüzden Bartleby önce bunları kullanır; indirilecek bir şey yok. Diğer diller için aşağıdaki indirme gerekir.';

  @override
  String get bartlebyBuiltInFooterModel =>
      'Aşağıdaki indirme bunları da kapsıyor, bu yüzden Bartleby her sesli mesajda onu kullanır.';

  @override
  String get bartlebyBuiltInNone => 'Bu cihazda henüz yok';

  @override
  String get bartlebyModelTitle => 'Daha iyi metinler';

  @override
  String get bartlebyModelDetail =>
      'Hangi dilin konuşulduğunu kendisi anlar. 100\'e yakın dil, internetsiz çalışır';

  @override
  String bartlebyModelInstalled(String size) {
    return 'Bu cihazda · $size';
  }

  @override
  String bartlebyStorageUsed(String size) {
    return 'Bartleby bu cihazda $size yer kaplıyor, kayıtlı metinler dahil.';
  }

  @override
  String get bartlebyStorageEmpty => 'Bartleby bu cihazda hiç yer kaplamıyor.';

  @override
  String get bartlebyCellularTitle => 'Mobil veriyle indirilsin mi?';

  @override
  String bartlebyCellularBody(String size) {
    return 'Bu, tek seferlik bir $size indirme. Mobil veri kotanı harcamak istemiyorsan Wi-Fi\'ı bekle.';
  }

  @override
  String get bartlebyRemoveKeepsTranscripts => 'Mevcut metinlerin silinmez.';

  @override
  String get settingsSearchKwTranscripts =>
      'metin, sesli mesaj, konuşma, dikte, yazıya dökme';

  @override
  String get chatGameTakeback => 'Geri al';

  @override
  String chatGameTakebackFrom(String name) {
    return '$name son hamlesini geri almak istiyor';
  }

  @override
  String get chatGameTakebackAsked => 'Geri alma isteği gönderildi';

  @override
  String chatGameTakebacksLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count geri alma hakkın kaldı',
      zero: 'Geri alma hakkın kalmadı',
    );
    return '$_temp0';
  }

  @override
  String get chatGameNoTakebacksHard => 'Zor bota karşı geri alma yok';

  @override
  String get chatGameYouResigned => 'Pes ettin';

  @override
  String get chatGameDrawAgreed => 'Berabere kalındı';

  @override
  String chatGameBotPlaysOn(String name) {
    return '$name oynamaya devam etmek istiyor';
  }

  @override
  String get chatGameDrawTooSoon =>
      'İki hamle sonra tekrar beraberlik teklif edebilirsin';

  @override
  String get chatGameTakebackTooSoon =>
      'Bu hamleyi geri alma isteğin zaten reddedildi';

  @override
  String get chatGameMoves => 'Hamleler';

  @override
  String get chatGameBackToGame => 'Güncel hamleye dön';

  @override
  String get chatGameNoMovesYet => 'Henüz hamle yok';

  @override
  String get chatGameKeysReplay => 'Hamleleri ← ve → ile gez';

  @override
  String get partyLdAcesRule =>
      '1\'lere geçmek için yarısı yeter, yukarı yuvarlanır. 1\'lerden çıkmak için iki katı artı bir gerekir.';

  @override
  String get partyRaceGrace => 'Biri bitirdiğinde diğerlerine 2 dakika kalır.';

  @override
  String get partyImposterClueRule => 'Kelimenin kendisi olmaz';

  @override
  String get partyLdKeys => '↑ ↓ adet · 1–6 yüz · Enter teklif · L yalancı';

  @override
  String get partyImposterVoteKeys =>
      'Oy için satırın numarasına bas · Atlamak için 0';

  @override
  String get dailyStandingsHintedNote =>
      'İpucu kullanılan çözümler, ipucusuz çözümlerin ardından sıralanır';

  @override
  String get howToPatchesControls =>
      'Yama kesmek için köşeden köşeye sürükle. Yeniden şekillendirmek için yamanın kenarını ya da köşesini sürükle. Kaldırmak için yamaya dokun.';

  @override
  String dropConfirmTitle(String room) {
    return '$room sohbetine gönderilsin mi?';
  }

  @override
  String dropConfirmMore(int count) {
    return 've $count tane daha';
  }

  @override
  String get dropConfirmSend => 'Gönder';

  @override
  String get streakCelebrateLabel => 'gün seri';

  @override
  String get streakCelebrateTier1 => 'İvmeni yakaladın';

  @override
  String get streakCelebrateTier2 => 'Alev alev';

  @override
  String get streakCelebrateTier3 => 'Durdurulamaz';

  @override
  String get streakCelebrateTier4 => 'Efsane';

  @override
  String get powerSavingHeader => 'Güç tasarrufu';

  @override
  String get powerSavingAuto => 'Otomatik';

  @override
  String get powerSavingAutoOffSub =>
      'Düşük Güç Modu veya Pil Tasarrufu açıkken animasyonları sakinleştirir';

  @override
  String get powerSavingAutoOnSub => 'Şu an açık: telefonun güç tasarrufunda';

  @override
  String get powerSavingNever => 'Asla';

  @override
  String get powerSavingNeverSub => 'Düşük Güç Modunda bile tam hareket';

  @override
  String get powerSavingAlways => 'Her zaman';

  @override
  String get powerSavingAlwaysSub =>
      'Telefon ne derse desin pil için sakin hareket';
}
