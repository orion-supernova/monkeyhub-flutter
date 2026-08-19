// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'सर्वर से कनेक्ट नहीं हो सका';

  @override
  String get bootErrorBody => 'Convex शुरू नहीं हो सका।';

  @override
  String get bootErrorRetry => 'फिर से कोशिश करें';

  @override
  String get incomingCallNotificationTitle => 'इनकमिंग कॉल';

  @override
  String get incomingCallFallbackCaller => 'तुम्हें कोई कॉल कर रहा है';

  @override
  String get settingsLanguageRowLabel => 'भाषा';

  @override
  String get languageScreenTitle => 'भाषा.';

  @override
  String get languageScreenSubtitle => 'ऐप के मेन्यू और मैसेज की भाषा चुनो';

  @override
  String get languageOptionSystem => 'सिस्टम';

  @override
  String get languageOptionSystemSub =>
      'तुम्हारे डिवाइस की भाषा सेटिंग के अनुसार';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => 'सक्रिय';

  @override
  String get languageValueSystem => 'सिस्टम';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack =>
      'अभी पूछ नहीं पाए — फिर से कोशिश करो';

  @override
  String get roomScreenGateSendMessages => 'यहां मैसेज भेजना';

  @override
  String get roomScreenGateSendMedia => 'फ़ोटो या वॉइस नोट भेजना';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'एक बार में $max तक';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मैसेज डिलीट करें',
      one: 'मैसेज डिलीट करें',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'ये मैसेज इस चैट में सबके लिए हट जाएंगे। इसे वापस नहीं लिया जा सकता।';

  @override
  String get roomScreenDeleteConfirmButton => 'सबके लिए डिलीट करें';

  @override
  String get roomScreenJumpFailedSnack => 'उस मैसेज तक नहीं पहुंच पाए';

  @override
  String get roomScreenViewOnceAlreadyViewed =>
      'यह फ़ोटो पहले ही खोली जा चुकी है।';

  @override
  String get roomScreenViewOnceGone => 'यह फ़ोटो अब उपलब्ध नहीं है।';

  @override
  String get roomScreenViewOnceNetworkError => 'वह फ़ोटो लोड नहीं हो सकी।';

  @override
  String get roomScreenFileReadFailedSnack => 'वह फ़ाइल पढ़ी नहीं जा सकी';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'फ़ाइलों की साइज़ सीमा $size है';
  }

  @override
  String get roomScreenRoomGone => 'रूम गायब';

  @override
  String get roomScreenCopiedSnack => 'कॉपी हो गया';

  @override
  String get roomScreenNameCopiedSnack => 'नाम कॉपी हो गया';

  @override
  String get roomScreenPinLimitSnack => 'बहुत सारे पिन — पहले एक अनपिन करो';

  @override
  String get roomScreenPinFailedSnack => 'उसे पिन नहीं किया जा सका';

  @override
  String get roomScreenReportSentSnack =>
      'रिपोर्ट गुप्त रूप से भेज दी गई। उन्हें सूचना नहीं मिलेगी।';

  @override
  String get roomScreenDeselectMessageSemantic => 'मैसेज का चयन हटाएं';

  @override
  String get roomScreenSelectMessageSemantic => 'मैसेज चुनें';

  @override
  String roomScreenMemberCountBadge(Object count) {
    return '$count अंदर';
  }

  @override
  String roomScreenTtlSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सेकंड',
      one: '$count सेकंड',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मिनट',
      one: '$count मिनट',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count घंटे',
      one: '$count घंटा',
    );
    return '$_temp0';
  }

  @override
  String roomScreenEphemeralNotice(Object ttl) {
    return 'यह रूम अस्थायी है। मैसेज, पढ़े हों या अनपढ़े, $ttl बाद अपने आप मिट जाते हैं।';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count मैसेज';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'सीक्रेट स्पेस';

  @override
  String get roomScreenSecretSpaceBody =>
      'इस रूम के मैसेज अस्थायी हैं। रूम की सुरक्षा नीति के अनुसार वे अपने आप हट जाते हैं।';

  @override
  String get roomScreenAutoDeleteTitle => 'ऑटो-डिलीट';

  @override
  String get roomScreenAutoDeleteVaries => 'अलग-अलग';

  @override
  String get roomScreenAutoDeleteTimed => 'समयबद्ध';

  @override
  String get roomScreenNoCaptureTitle => 'नो कैप्चर';

  @override
  String get roomScreenNoCaptureSubtitle => 'स्क्रीनशॉट प्रतिबंधित';

  @override
  String get roomScreenMorePrivacyTitle => 'बहुत ज़्यादा प्राइवेसी';

  @override
  String get roomScreenMorePrivacySubtitle =>
      'पहले से मौजूद प्राइवेसी फोकस के साथ-साथ अतिरिक्त सुरक्षा फीचर्स का मज़ा लें।';

  @override
  String get roomScreenNoMessagesTitle => 'कोई मैसेज नहीं';

  @override
  String get roomScreenNoMessagesSubtitle => 'मैसेज भेजकर बातचीत शुरू करें';

  @override
  String get roomScreenViewProfilePictureSemantic => 'प्रोफ़ाइल फ़ोटो देखें';

  @override
  String get roomScreenViewRoomPictureSemantic => 'रूम फ़ोटो देखें';

  @override
  String get messageBubbleFileFallbackName => 'भेजा गया दस्तावेज़';

  @override
  String get messageBubbleAttachmentStatusFailed => 'विफल';

  @override
  String get messageBubbleAttachmentStatusSending => 'भेजा जा रहा है…';

  @override
  String get messageBubbleViewOnceOpened => 'खुल गया';

  @override
  String get messageBubbleViewOnceExpired => 'एक्सपायर हो गया';

  @override
  String get messageBubbleViewOnceLabel => 'एक बार देखें';

  @override
  String get messageBubbleViewOnceTapToView => 'देखने के लिए टैप करें';

  @override
  String get messageBubbleViewOncePhotoLabel => 'फोटो';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'एक बार देखने वाली फोटो, देखने के लिए टैप करें';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'भेजना फिर से आज़माएं';

  @override
  String get messageBubbleDiscardSemanticLabel =>
      'भेजने में असफल अटैचमेंट हटाएं';

  @override
  String get profileScreenAccountSection => 'अकाउंट';

  @override
  String get profileScreenAddEmailPlaceholder => 'ईमेल जोड़ें';

  @override
  String get profileScreenAddEmailTitle => 'ईमेल जोड़ें?';

  @override
  String get profileScreenAddNameTitle => 'नाम जोड़ें?';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count लंबित';
  }

  @override
  String get profileScreenApprovalsLabel => 'स्वीकृतियां';

  @override
  String get profileScreenApprovalsNothingWaiting => 'कुछ भी लंबित नहीं';

  @override
  String get profileScreenApproveAction => 'स्वीकार करें';

  @override
  String get profileScreenBlockAction => 'ब्लॉक करें';

  @override
  String get profileScreenBlockedDmWiped =>
      'ब्लॉक कर दिया और डीएम मिटा दी गई। उन्हें पता नहीं चलेगा।';

  @override
  String get profileScreenBlockedOnly =>
      'ब्लॉक कर दिया। उन्हें पता नहीं चलेगा।';

  @override
  String get profileScreenBlockedUsers => 'ब्लॉक किए गए यूज़र्स';

  @override
  String get profileScreenCancelAction => 'रद्द करें';

  @override
  String get profileScreenCancelRequestAction => 'रिक्वेस्ट वापस लें';

  @override
  String get profileScreenChangeAction => 'बदलें';

  @override
  String get profileScreenChangeEmailTitle => 'ईमेल बदलें?';

  @override
  String get profileScreenChangeNameTitle => 'नाम बदलें?';

  @override
  String get profileScreenChangeProfilePictureSemantic =>
      'प्रोफ़ाइल फ़ोटो बदलें';

  @override
  String get profileScreenChangeRecoveryPhrase => 'रिकवरी फ़्रेज़ बदलें';

  @override
  String get profileScreenChooseFromLibrary => 'गैलरी से चुनें';

  @override
  String get profileScreenCouldNotSaveImage => 'तस्वीर सेव नहीं हो सकी।';

  @override
  String get profileScreenDeleteAccount => 'अकाउंट डिलीट करें';

  @override
  String get profileScreenEmailHint => 'वैकल्पिक — किसी को नहीं दिखेगा';

  @override
  String get profileScreenEmailSectionLabel => 'ईमेल';

  @override
  String get profileScreenErrorAlreadyFriends => 'तुम पहले से दोस्त हो।';

  @override
  String get profileScreenErrorGeneric => 'यह पूरा नहीं हो सका।';

  @override
  String get profileScreenErrorNotAccepting =>
      'वे अभी फ्रेंड रिक्वेस्ट स्वीकार नहीं कर रहे हैं।';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      'उन्होंने तुम्हें पहले ही रिक्वेस्ट भेज दी है — रिक्वेस्ट्स देखो।';

  @override
  String get profileScreenErrorRequestAlreadySent =>
      'रिक्वेस्ट पहले ही भेजी जा चुकी है।';

  @override
  String get profileScreenErrorUnblockFirst =>
      'तुमने इस यूज़र को ब्लॉक किया है — पहले उन्हें अनब्लॉक करो।';

  @override
  String get profileScreenErrorUserNotFound => 'यह अभी संभव नहीं है।';

  @override
  String get profileScreenNameNotSaved =>
      'आपका नाम सहेजा नहीं जा सका। दोबारा कोशिश करें।';

  @override
  String get profileScreenFamilyAddChild => 'बच्चा जोड़ें';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बच्चे',
      one: '$count बच्चा',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => 'परिवार';

  @override
  String get profileScreenFriendsChip => 'दोस्त';

  @override
  String get profileScreenGrownUpOnlyNote =>
      'यह सिर्फ़ बड़े ही कर सकते हैं — इसके लिए उनका कोड या पासवर्ड ज़रूरी है।';

  @override
  String get profileScreenGuardiansCanSee =>
      'वे देख सकते हैं कि तुम कब ऑनलाइन हो और किससे बात करते हो।';

  @override
  String get profileScreenHandPhoneBack => 'यह फ़ोन वापस सौंपो';

  @override
  String get profileScreenIncomingRequestChip => 'रिक्वेस्ट मिली';

  @override
  String get profileScreenJustTappedAction => 'ग़लती से टैप हुआ';

  @override
  String get settingsScreenSectionHelpAndLegal => 'सहायता और कानूनी';

  @override
  String get settingsScreenLicence => 'लाइसेंस';

  @override
  String get profileScreenLinkedAccountsLabel => 'लिंक किए गए खाते';

  @override
  String get profileScreenLinkedAccountsNone => 'कुछ भी लिंक नहीं';

  @override
  String get profileScreenMyGrownUps => 'मेरे बड़े';

  @override
  String get profileScreenNameHint => 'रूम में तुम ऐसे नज़र आओगे';

  @override
  String get profileScreenChangeUsernameTitle => 'यूज़रनेम बदलें?';

  @override
  String get profileScreenChangeUsernameWarning =>
      'आप इसी से साइन इन करते हैं, इसलिए अब से नया वाला टाइप करेंगे। आपका पुराना यूज़रनेम किसी और के लेने के लिए खाली हो जाएगा, और आप इसे 30 दिन तक दोबारा नहीं बदल पाएंगे। जिन पुराने मैसेज में आपको टैग किया गया था, उनमें पुराना नाम ही रहेगा।';

  @override
  String get profileScreenUsernameHint => 'आपके दोस्त आपको ऐसे ढूँढ़ेंगे';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return '$date को दोबारा बदल सकेंगे';
  }

  @override
  String get profileScreenUsernamePasswordTitle =>
      'पुष्टि करें कि यह आप ही हैं';

  @override
  String get profileScreenUsernamePasswordAction => 'यूज़रनेम बदलें';

  @override
  String get profileScreenUsernameProviderTitle =>
      'अपने साइन-इन से पुष्टि करें';

  @override
  String profileScreenUsernameChanged(String username) {
    return 'अब आप @$username हैं।';
  }

  @override
  String get profileScreenUsernameNotSaved =>
      'आपका यूज़रनेम नहीं बदला जा सका। कृपया दोबारा कोशिश करें।';

  @override
  String get usernameStatusChecking => 'जाँच हो रही है…';

  @override
  String get usernameStatusAvailable => 'उपलब्ध';

  @override
  String get usernameStatusTaken => 'पहले से लिया जा चुका';

  @override
  String get usernameStatusReserved => 'उपलब्ध नहीं';

  @override
  String get usernameStatusInvalid => '1–32 अक्षर';

  @override
  String get usernameStatusUnknown => 'जाँच नहीं हो सकी';

  @override
  String get profileScreenNobodyLookingAfter =>
      'अभी कोई बड़ा इस अकाउंट का ध्यान नहीं रख रहा';

  @override
  String get profileScreenNotAcceptingRequestsAction =>
      'रिक्वेस्ट स्वीकार नहीं कर रहे';

  @override
  String get profileScreenNotConnectedChip => 'जुड़े नहीं';

  @override
  String get profileScreenOpenDmAction => 'डीएम खोलो';

  @override
  String get profileScreenPhotoPermissionDenied => 'फ़ोटो की परमिशन नहीं मिली।';

  @override
  String get settingsScreenPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get profileScreenPrivacySection => 'गोपनीयता';

  @override
  String get profileScreenProfilePictureTitle => 'प्रोफ़ाइल फ़ोटो';

  @override
  String get profileScreenRedactedFriend =>
      'उनकी सेटिंग्स के कारण कुछ जानकारी छिपी है।';

  @override
  String get profileScreenRedactedStranger =>
      'सीमित जानकारी — वे दोस्तों के साथ ज़्यादा शेयर करते हैं।';

  @override
  String get profileScreenReportAction => 'रिपोर्ट करो';

  @override
  String get profileScreenReportSent =>
      'रिपोर्ट प्राइवेट तौर पर भेज दी गई। उन्हें कोई सूचना नहीं मिलेगी।';

  @override
  String get profileScreenRequestPendingChip => 'तुम्हारी रिक्वेस्ट पेंडिंग';

  @override
  String get profileScreenSaveAction => 'सेव करो';

  @override
  String get profileScreenSavedToPhotos => 'फ़ोटोज़ में सेव हो गया।';

  @override
  String get profileScreenSaveToPhotos => 'फ़ोटोज़ में सेव करो';

  @override
  String get profileScreenSendRequestAction => 'रिक्वेस्ट भेजो';

  @override
  String get profileScreenSetUpRecoveryPhrase => 'रिकवरी फ्रेज़ सेट करो';

  @override
  String get profileScreenSignOut => 'साइन आउट करो';

  @override
  String get profileScreenTakeSelfie => 'सेल्फी लो';

  @override
  String get profileScreenTapAgainToConfirmDelete =>
      'डिलीट पक्का करने के लिए फिर टैप करो';

  @override
  String get settingsScreenTermsOfService => 'सेवा की शर्तें';

  @override
  String get profileScreenThisPhoneSection => 'यह फ़ोन';

  @override
  String get profileScreenUnfriendAction => 'अनफ्रेंड करो';

  @override
  String get profileScreenViewProfilePictureSemantic => 'प्रोफ़ाइल फ़ोटो देखें';

  @override
  String get profileScreenVisibilityPreferences => 'विज़िबिलिटी सेटिंग्स';

  @override
  String get cameraEditorScreenCropPresetFree => 'फ्री';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'मूल';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'क्रॉप रद्द करें';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'फ़ोटो हटाएं';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'पूर्ववत करें';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'फिर से करें';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'क्रॉप रीसेट करें';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'घुमाएं';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'क्रॉप करें';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'यह ब्राउज़र HEIC फ़ोटो नहीं खोल सकता';

  @override
  String get cameraEditorScreenImageLoadFailedMessage => 'वह इमेज नहीं खुल पाई';

  @override
  String get cameraEditorScreenCropDoneButton => 'हो गया';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'फिर से लें';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'पेन बंद करें';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'फ़ोटो पर ड्रॉ करें';

  @override
  String get cameraEditorScreenSendingButton => 'भेजा जा रहा है…';

  @override
  String get cameraEditorScreenSendButton => 'भेजें';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'एक बार खोलने के बाद गायब हो जाएगा';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'ड्रॉइंग साफ़ करें';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel => 'एक बार देखें: चालू';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel => 'एक बार देखें: बंद';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'स्याही का रंग';

  @override
  String get glassScreenPanelLooks => 'लुक्स';

  @override
  String get glassScreenPanelBottomBar => 'बॉटम बार';

  @override
  String get glassScreenPanelOtherSurfaces => 'अन्य सतहें';

  @override
  String get glassScreenPanelBarLayout => 'बार लेआउट';

  @override
  String get glassScreenTitle => 'काँच.';

  @override
  String get glassScreenSubtitle => 'पीछे की चीज़ें कितनी नज़र आती हैं';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'सभी $max स्लॉट भरे हैं';
  }

  @override
  String get glassScreenSaveCurrentAs => 'मौजूदा को सेव करें…';

  @override
  String get glassScreenResetEveryDial => 'हर घुंडी रीसेट करें';

  @override
  String glassScreenResetToPreset(Object name) {
    return '$name पर रीसेट करें';
  }

  @override
  String get glassScreenSurfacesNote =>
      'कंपोज़र, हेडर, कॉल बटन — यानी वह सब कुछ जो स्क्रॉलिंग कंटेंट पर नहीं, बल्कि टेक्स्ट के ऊपर होता है';

  @override
  String get glassScreenMatchBottomBar => 'बॉटम बार जैसा करें';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'बदला गया — इसे नए लुक के रूप में सेव करें, या रीसेट करें';

  @override
  String get glassScreenCustomPresetName => 'कस्टम';

  @override
  String get glassScreenUnsavedSubtitle =>
      'सेव नहीं हुआ — रखने के लिए इसे नाम दो';

  @override
  String get glassScreenSaveDialogTitle => 'इस लुक को नाम दो';

  @override
  String get glassScreenNoRoomToast => 'जगह नहीं है — पहले कोई लुक मिटाओ';

  @override
  String get glassScreenRenameDialogTitle => 'नाम बदलो';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '$name मिटाना है?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'लुक स्क्रीन पर बना रहेगा — बस उसका नाम नहीं रहेगा।';

  @override
  String get glassScreenKeepButton => 'रखो';

  @override
  String get glassScreenDeleteButton => 'मिटाओ';

  @override
  String get glassScreenNameHint => 'देर रात';

  @override
  String get glassScreenCancelButton => 'रद्द करो';

  @override
  String get glassScreenSaveButton => 'सेव करो';

  @override
  String get glassScreenPreviewRoomName => '# बालकनी';

  @override
  String get glassScreenPreviewOnlineCount => '4 ऑनलाइन';

  @override
  String get glassScreenPreviewMessageHint => 'मैसेज';

  @override
  String get glassScreenPreviewCollapseLabel => 'प्रीव्यू छोटा करो';

  @override
  String get glassScreenPreviewExpandLabel => 'प्रीव्यू बड़ा करो';

  @override
  String get glassScreenPreviewBadge => 'प्रीव्यू';

  @override
  String get glassScreenBuiltInLabel => 'बिल्ट-इन';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return '$name ओवरराइट करो';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return '$name का नाम बदलो';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return '$name मिटाओ';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return '$label रीसेट करो';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'छत की फ़ोटो भेजी — सारी टाइलें टूटी हुई हैं';

  @override
  String get glassScreenBackdropMsgMert =>
      'ठीक है पर स्पीकर असल में कौन ला रहा है';

  @override
  String get glassScreenBackdropGroupFamily => 'परिवार';

  @override
  String get glassScreenBackdropMsgFamily =>
      'मम्मी: रात 8 बजे खाना है, फिर लेट मत होना';

  @override
  String get glassScreenBackdropMsgZeynep => 'मैं बाहर हूँ';

  @override
  String get glassScreenBackdropMsgKerem => 'कोने वाली दुकान की कॉफी बढ़िया है';

  @override
  String get glassScreenBackdropGroupWork => 'ऑफ़िस';

  @override
  String get glassScreenBackdropMsgWork =>
      'स्टैंडअप अब हफ्ते के बाकी दिनों 10:30 बजे होगा';

  @override
  String get glassScreenBackdropMsgElif =>
      'नहीं यार। दोबारा भेजो, मुझसे खो गया।';

  @override
  String get glassScreenBackdropMsgBaran => 'लैंड हो गया 👍';

  @override
  String get glassScreenBackdropMsgAyse =>
      'बिल्ली ने बालकनी का दरवाज़ा खोलना सीख लिया है';

  @override
  String get glassScreenBackdropMsgCan => 'तो फिर शनिवार को मिलते हैं';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return '$name के जवाब में';
  }

  @override
  String get replyIndicatorViewOnceLabel => 'फ़ोटो · एक बार देखें';

  @override
  String get replyIndicatorVoiceMessageLabel => 'वॉइस मैसेज';

  @override
  String get replyIndicatorDocumentLabel => 'दस्तावेज़';

  @override
  String get replyIndicatorMessageRemoved => 'मैसेज हटाया गया';

  @override
  String get threadOverlayMessageNotFound => 'इस थ्रेड में वह मैसेज नहीं मिला';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'जवाब देने के लिए थ्रेड नहीं मिला';

  @override
  String get threadOverlayStillSending =>
      'अभी भेजा जा रहा है — थोड़ी देर में फिर कोशिश करें';

  @override
  String get threadOverlayCopiedToast => 'कॉपी हो गया';

  @override
  String get threadOverlayNameCopiedToast => 'नाम कॉपी हो गया';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'निर्देशांक कॉपी किए गए';

  @override
  String get threadOverlayPinLimitToast =>
      'बहुत ज़्यादा पिन — पहले एक अनपिन करें';

  @override
  String get threadOverlayPinFailedToast => 'उसे पिन नहीं कर सके';

  @override
  String get threadOverlayReportedToast => 'रिपोर्ट किया गया';

  @override
  String get threadOverlayUnavailable => 'थ्रेड उपलब्ध नहीं है';

  @override
  String get roomInfoScreenNameRequiredError => 'नाम ज़रूरी है';

  @override
  String get roomInfoScreenSavedSnackbar => 'सेव हो गया';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'पासवर्ड हटा दिया गया';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'रूम छोड़ें?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'अगर यह खुला रहा, तो तुम दोबारा जुड़ सकते हो।';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'छोड़ें';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'रूम डिलीट करें?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'यहाँ का हर मैसेज भी इसके साथ चला जाएगा। यह हमेशा के लिए है।';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'डिलीट करें';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      'यह बातचीत खत्म करें?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName भी यह बातचीत खो देगा — तुम दोनों के लिए हर मैसेज गायब हो जाएगा। यह हमेशा के लिए है।';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'खत्म करें';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'दूसरा व्यक्ति';

  @override
  String get roomInfoScreenConfirmCancelButton => 'रद्द करें';

  @override
  String get roomInfoScreenErrorRoomExists => 'इस नाम का रूम पहले से मौजूद है';

  @override
  String get roomInfoScreenErrorNotOwner => 'यह सिर्फ़ ओनर ही कर सकता है';

  @override
  String get roomInfoScreenErrorNotAuthorized =>
      'तुम्हारे पास इसकी अनुमति नहीं है';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'यह रूम अब मौजूद नहीं है';

  @override
  String get roomInfoScreenRoomGone => 'रूम मौजूद नहीं है';

  @override
  String get roomInfoScreenNameLabel => 'नाम';

  @override
  String get roomInfoScreenNameHint => 'रूम का नाम';

  @override
  String get roomInfoScreenDescriptionLabel => 'विवरण';

  @override
  String get roomInfoScreenDescriptionHint => 'रूम के बारे में एक लाइन…';

  @override
  String get roomInfoScreenVisibilityLabel => 'दृश्यता';

  @override
  String get roomInfoScreenPublicTitle => 'पब्लिक';

  @override
  String get roomInfoScreenPublicSub => 'कोई भी इसे ढूंढ सकता है';

  @override
  String get roomInfoScreenPrivateTitle => 'निजी';

  @override
  String get roomInfoScreenPrivateSub => 'सिर्फ़ इनवाइट से';

  @override
  String get roomInfoScreenMessageLifeLabel => 'मैसेज लाइफ';

  @override
  String roomInfoScreenTtlSeconds(Object value) {
    return '$valueसे';
  }

  @override
  String roomInfoScreenTtlMinutes(Object value) {
    return '$valueमि';
  }

  @override
  String roomInfoScreenTtlHours(Object value) {
    return '$valueघं';
  }

  @override
  String get roomInfoScreenPasswordLabel => 'पासवर्ड';

  @override
  String get roomInfoScreenLockedBadge => 'लॉक';

  @override
  String get roomInfoScreenNoneBadge => 'कोई नहीं';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      'यह रूम सुरक्षित है। सुरक्षा कारणों से मौजूदा पासफ़्रेज़ नहीं दिखाया जाता — इसे बदलने के लिए नया डालें।';

  @override
  String get roomInfoScreenReplacePasswordHint => 'पासफ़्रेज़ बदलें…';

  @override
  String get roomInfoScreenSetPasswordHint => 'पासफ़्रेज़ से लॉक करें…';

  @override
  String get roomInfoScreenRemovePasswordButton => 'पासवर्ड हटाएं';

  @override
  String get roomInfoScreenSharedContentLabel => 'शेयर किया गया कंटेंट';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return 'सदस्य · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => 'छोड़ा जा रहा है…';

  @override
  String get roomInfoScreenLeaveRoomButton => 'रूम छोड़ें';

  @override
  String get roomInfoScreenDeletingButton => 'डिलीट हो रहा है…';

  @override
  String get roomInfoScreenDeleteButtonLabel => 'डिलीट करें';

  @override
  String get roomInfoScreenEndingConversationButton => 'खत्म हो रहा है…';

  @override
  String get roomInfoScreenEndConversationButton => 'बातचीत खत्म करें';

  @override
  String get roomInfoScreenHeaderConversation => 'बातचीत';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'रूम सेटिंग्स';

  @override
  String get roomInfoScreenViewProfilePictureSemantic =>
      'प्रोफ़ाइल तस्वीर देखें';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'रूम की तस्वीर देखें';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'रूम की तस्वीर बदलें';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'रूम की तस्वीर जोड़ें';

  @override
  String get roomInfoScreenLoadingMembers => 'सदस्य लोड हो रहे हैं…';

  @override
  String get roomInfoScreenOwnerBadge => 'मालिक';

  @override
  String get roomInfoScreenSaveButton => 'सेव करें';

  @override
  String get roomInfoScreenNoneCount => 'कोई नहीं';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'कैमरा एक्सेस बंद है।\nफ़ोटो लेने के लिए सेटिंग्स में इसे ऑन करें।';

  @override
  String get cameraScreenOpeningSystemCamera => 'सिस्टम कैमरा खुल रहा है…';

  @override
  String get cameraScreenCloseButtonLabel => 'कैमरा बंद करें';

  @override
  String get cameraScreenLowLightBoostOnLabel => 'लो-लाइट बूस्ट: ऑन';

  @override
  String get cameraScreenLowLightBoostOffLabel => 'लो-लाइट बूस्ट: ऑफ';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'फ़्लैश: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'लाइब्रेरी से चुनें';

  @override
  String get cameraScreenSwitchCameraLabel => 'कैमरा बदलें';

  @override
  String get cameraScreenTakePhotoLabel => 'फ़ोटो लें';

  @override
  String get childPolicyScreenAddByUsernameLabel => 'यूज़रनेम से जोड़ें';

  @override
  String get childPolicyScreenAddCta => 'जोड़ें';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'उन्हें बिल्कुल वही मिलता है जो तुम्हारे पास है: हर रिक्वेस्ट को अप्रूव करने का अधिकार, हर सेटिंग को बदलने का अधिकार, और तुम्हें हटाने की ताकत। $name के लिए वे अभी से परिवार हैं।';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'बड़ा जोड़ें';

  @override
  String get childPolicyScreenAddGuardianHint => 'उनका यूज़रनेम';

  @override
  String get childPolicyScreenAllowCta => 'अनुमति दें';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'अब तुमसे उनके बारे में दोबारा नहीं पूछा जाएगा — चाहे $childName उन्हें जोड़े या वे $childName को जोड़ें।';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'किसी को अनुमति दें';

  @override
  String get childPolicyScreenAskToAddLabel => 'जोड़ने के लिए पूछें';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'सिर्फ़ परिवार — कोई नई रिक्वेस्ट नहीं';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'वे नए लोगों के बारे में तुमसे पूछ सकते हैं';

  @override
  String get childPolicyScreenBothFinalNote =>
      'ये दोनों फ़ैसले पक्के हैं। इसके बजाय अलग होने का विकल्प ऊपर बड़े सेक्शन में मिलेगा।';

  @override
  String get childPolicyScreenCallsLabel => 'कॉल्स';

  @override
  String get childPolicyScreenCallsOffDesc => 'सिर्फ़ मैसेज';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'अनुमति वाले लोगों के साथ वॉइस + वीडियो कॉल';

  @override
  String get childPolicyScreenCancelLabel => 'रद्द करें';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'रद्द करें';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'जोड़ दिया — रिक्वेस्ट रास्ते में है';

  @override
  String get childPolicyScreenContactAddedToList =>
      'अनुमति वाली लिस्ट में जोड़ दिया';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'रूम बनाएं';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'वे रूम शुरू नहीं कर सकते';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'वे अपने प्राइवेट रूम शुरू कर सकते हैं';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'सब कुछ मिट जाएगा: उनके मैसेज, फ़ोटो, रूम और दोस्त। इसे पलटा नहीं जा सकता, और यूज़रनेम किसी और के लिए खुला हो जाएगा।';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'अकाउंट डिलीट नहीं हो पाया — फिर से कोशिश करो';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return '$name का अकाउंट डिलीट करें?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'मैसेज, फ़ोटो, रूम और दोस्त — सब मिट जाएंगे। इसे पलटा नहीं जा सकता।';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return '$name का अकाउंट डिलीट करें';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'हमेशा के लिए डिलीट करें';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'उन्हें जोड़ा नहीं जा सका — फिर से कोशिश करो';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'यह तो उनका अपना यूज़रनेम है';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'कोई बच्चा बड़ा नहीं हो सकता';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'यह नहीं हो सका — फिर से कोशिश करें';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'किसी को तो उनकी देखभाल करनी होगी — पहले एक और बड़ा जोड़ें';

  @override
  String get childPolicyScreenErrorNotYours =>
      'इसे बदलने का अधिकार तुम्हें नहीं है';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'इस यूज़रनेम से कोई अकाउंट नहीं मिला';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'इस पासवर्ड के साथ वे एक सामान्य अकाउंट बन जाएंगे, और हर बड़े की उन पर नज़र पूरी तरह खत्म हो जाएगी। इसे वापस नहीं किया जा सकता — फिर तुम्हें भी बाकी सबकी तरह आमंत्रित किया जाना होगा।';

  @override
  String get childPolicyScreenGraduateCta => 'ग्रेजुएट करें';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'उनका सब कुछ वैसा ही रहेगा और उन्हें एक पासवर्ड मिल जाएगा। तुम्हारी उन पर नज़र पूरी तरह खत्म हो जाएगी। यह वापस नहीं हो सकता।';

  @override
  String get childPolicyScreenGraduateDangerLabel =>
      'पूर्ण अकाउंट में ग्रेजुएट करें';

  @override
  String get childPolicyScreenGraduateFailed =>
      'उन्हें ग्रेजुएट नहीं किया जा सका — फिर से कोशिश करें';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return '$name को ग्रेजुएट करें';
  }

  @override
  String get childPolicyScreenGraduateHint => 'उनके लिए एक पासवर्ड';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'कोई रूम वापस लेने पर वे उससे भी हट जाते हैं। कोई व्यक्ति वापस लेने पर उनकी चैट भी डिलीट हो जाती है — दोनों के लिए।';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'यहाँ मौजूद हर कोई अप्रूव कर सकता है, सेटिंग्स बदल सकता है, और सब कुछ देख सकता है। इनमें से कोई भी अकेले फैसला ले सकता है — किसी को दूसरों का इंतज़ार नहीं करना पड़ता।';

  @override
  String get childPolicyScreenGuardianAdded =>
      'जोड़ दिया गया — अब वे उनकी देखभाल कर सकते हैं';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name को हटा दिया गया';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (तुम)';
  }

  @override
  String get childPolicyScreenLoading => 'लोड हो रहा है…';

  @override
  String get childPolicyScreenLockedLabel => 'लॉक';

  @override
  String get childPolicyScreenMediaLabel => 'फ़ोटो + आवाज़';

  @override
  String get childPolicyScreenMediaOffDesc => 'सिर्फ़ टेक्स्ट';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'वे तस्वीरें, वीडियो और वॉइस नोट भेज सकते हैं';

  @override
  String get childPolicyScreenNoRoomsYet => 'अभी कोई रूम नहीं';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'इनमें से किसी को भी दोबारा तुमसे पूछे बिना जोड़ा जा सकता है — चाहे शुरुआत उनमें से कोई भी करे।';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'बच्चों के लिए यह हमेशा बंद रहता है। डिस्कवर — यानी अनजान लोगों के रूम्स की लिस्ट — पूरी तरह छिपा दी जाती है और इसे कभी चालू नहीं किया जा सकता। किसी ने उन्हें जिस रूम में आमंत्रित किया हो, वह पहले जैसा ही काम करता है।';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'पब्लिक रूम्स';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian अब $child के लिए कुछ भी न देख पाएंगे, न अप्रूव कर पाएंगे।';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return '$name को हटाएं?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'हटाएं';

  @override
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count सदस्य';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'बड़े';

  @override
  String get childPolicyScreenSectionPeopleAllowed => 'मंज़ूर किए गए लोग';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'मंज़ूर किए गए रूम्स';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'वे क्या कर सकते हैं';

  @override
  String get childPolicyScreenSectionWhenDone => 'जब बात खत्म हो';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'जब तक कोई एक-दूसरे को न जोड़े, तब तक कुछ नहीं होता';

  @override
  String get childPolicyScreenSendNowOnDesc => 'उनसे तुरंत पूछा जाएगा';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'अभी रिक्वेस्ट भेजें';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'तुम $name के इकलौते बड़े हो, इसलिए यूं ही पीछे नहीं हट सकते — पहले किसी और को जोड़ो, या इनमें से कोई एक इस्तेमाल करो।';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'पीछे हटें';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'तुम्हें $name के अकाउंट की कोई भनक नहीं मिलेगी — न उनकी रिक्वेस्ट्स, न उनके लोग, न उनके रूम्स। बाकी बड़े उनका ख्याल रखते रहेंगे।';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'निगरानी बंद करें';

  @override
  String get childPolicyScreenStopSupervisingHeadline => 'निगरानी बंद करें?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'वापस नहीं ले पाए — फिर कोशिश करो';

  @override
  String get childPolicyScreenTakeBackLabel => 'वापस लें';

  @override
  String get childPolicyScreenUsernameHint => 'यूज़रनेम';

  @override
  String get childPolicyScreenYou => 'तुम';

  @override
  String get roomContentScreenDefaultDocumentName => 'दस्तावेज़';

  @override
  String get roomContentScreenCouldntOpenFile => 'वह फ़ाइल नहीं खुल पाई';

  @override
  String get roomContentScreenCouldntShare => 'उन्हें शेयर नहीं कर पाए';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लिंक कॉपी हो गए',
      one: 'कॉपी हो गया',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मैसेज डिलीट करें',
      one: 'मैसेज डिलीट करें',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'यह उन्हें इस चैट के सभी लोगों के लिए हटा देगा। इसे वापस नहीं लिया जा सकता।';

  @override
  String get roomContentScreenDeleteForEveryone => 'सभी के लिए डिलीट करें';

  @override
  String get roomContentScreenCancelTooltip => 'रद्द करें';

  @override
  String get roomContentScreenBackTooltip => 'वापस';

  @override
  String get roomContentScreenSelectingLabel => 'सिलेक्ट मोड';

  @override
  String get roomContentScreenSharedContentLabel => 'शेयर्ड कॉन्टेंट';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चुने गए',
      one: '$count चुना गया',
      zero: 'कुछ नहीं चुना',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'चुनें';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'सभी';

  @override
  String get roomContentScreenEmptyMedia => 'अभी तक कोई फ़ोटो या वीडियो नहीं';

  @override
  String get roomContentScreenEmptyFiles => 'अभी तक कोई फ़ाइल नहीं';

  @override
  String get roomContentScreenEmptyVoice => 'अभी तक कोई वॉइस नोट नहीं';

  @override
  String get roomContentScreenEmptyLinks => 'अभी तक कोई लिंक नहीं';

  @override
  String get roomContentScreenEmptySaved =>
      'अभी तक कुछ सेव नहीं किया. किसी मैसेज को दबाकर रखें और सेव करें चुनें.\n\nयहाँ आप जो रखते हैं वह सिर्फ़ आपके लिए है — पिन किया गया मैसेज पूरा रूम देखता है.';

  @override
  String get roomContentScreenLoadFailed => 'वह लोड नहीं हो पाया';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return '$name का वॉइस नोट';
  }

  @override
  String get roomContentScreenForwardAction => 'फ़ॉरवर्ड';

  @override
  String get roomContentScreenCopyAction => 'कॉपी';

  @override
  String get roomContentScreenSaveAction => 'सेव';

  @override
  String get roomContentScreenShareAction => 'शेयर';

  @override
  String get roomContentScreenInChatAction => 'चैट में देखें';

  @override
  String get roomContentScreenDeleteAction => 'डिलीट करें';

  @override
  String get messageActionMenuReplyLabel => 'जवाब दें';

  @override
  String get messageActionMenuEditLabel => 'एडिट करें';

  @override
  String get messageStampEditedLabel => 'एडिट किया गया';

  @override
  String get composerEditCardTitle => 'मैसेज एडिट करें';

  @override
  String get spoilerRevealHint =>
      'स्पॉइलर — छिपा टेक्स्ट दिखाने के लिए सक्रिय करें';

  @override
  String get formatToolbarFormatLabel => 'फ़ॉर्मैट करें';

  @override
  String get formatToolbarBoldLabel => 'बोल्ड';

  @override
  String get formatToolbarItalicLabel => 'इटैलिक';

  @override
  String get formatToolbarStrikethroughLabel => 'स्ट्राइकथ्रू';

  @override
  String get formatToolbarUnderlineLabel => 'अंडरलाइन';

  @override
  String get formatToolbarSpoilerLabel => 'स्पॉइलर';

  @override
  String get formatToolbarLinkLabel => 'लिंक';

  @override
  String get formatToolbarCodeLabel => 'कोड';

  @override
  String get linkInputSheetTitle => 'लिंक';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => 'लिंक लागू करें';

  @override
  String get linkInputSheetApplySub =>
      'टैप करने पर चुना गया टेक्स्ट यह पता खोलेगा';

  @override
  String get linkInputSheetRemoveLabel => 'लिंक हटाएं';

  @override
  String get linkConfirmSheetTitle => 'यह लिंक खोलें?';

  @override
  String get linkConfirmSheetOpenLabel => 'लिंक खोलें';

  @override
  String get linkConfirmSheetCancelLabel => 'रद्द करें';

  @override
  String get roomScreenEditExpiredSnack =>
      'एडिट करने में देर हो गई — मैसेज सिर्फ़ 15 मिनट तक ही एडिट किए जा सकते हैं।';

  @override
  String get roomScreenEditFailedSnack =>
      'एडिट सेव नहीं हो सका। अपना कनेक्शन जाँचकर दोबारा कोशिश करें।';

  @override
  String get messageActionMenuForwardLabel => 'फ़ॉरवर्ड करें';

  @override
  String get messageActionMenuViewThreadLabel => 'थ्रेड देखें';

  @override
  String get messageActionMenuCopyLabel => 'कॉपी करें';

  @override
  String get messageActionMenuCopyNameLabel => 'नाम कॉपी करें';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'निर्देशांक कॉपी करें';

  @override
  String get messageActionMenuPinLabel => 'पिन करें';

  @override
  String get messageActionMenuUnpinLabel => 'अनपिन करें';

  @override
  String get messageActionMenuSelectLabel => 'चुनें';

  @override
  String get messageActionMenuProfileLabel => 'प्रोफ़ाइल';

  @override
  String get messageActionMenuDeleteLabel => 'डिलीट करें';

  @override
  String get messageActionMenuReportLabel => 'रिपोर्ट करें';

  @override
  String get themeScreenTitle => 'थीम.';

  @override
  String get themeScreenTapToApplyHint =>
      'लागू करने के लिए टैप करें · पूरे प्रीव्यू के लिए ⛶';

  @override
  String get themeScreenFamilyBasicName => 'बेसिक';

  @override
  String get themeScreenFamilyBasicTagline => 'iOS से प्रेरित · 5 पैलेट';

  @override
  String get themeScreenFamilyVaultName => 'वॉल्ट';

  @override
  String get themeScreenFamilyVaultTagline => 'गुप्त फ़ाइल · नॉयर + आइवरी';

  @override
  String get themeScreenFamilyOthersName => 'अन्य';

  @override
  String get themeScreenFamilyOthersTagline => 'अनोखे मूड';

  @override
  String get themeScreenActiveBadge => 'एक्टिव';

  @override
  String get themeScreenTapToApplyLabel => 'लागू करने के लिए टैप करें';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return 'एक्टिव — $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return '$name लागू करें';
  }

  @override
  String get themeScreenPreviewGreeting => 'अरे, तुम.';

  @override
  String get themeScreenPreviewSectionLabel => 'बातचीत';

  @override
  String get themeScreenPreviewRoomOneName => 'डिज़ाइन क्लब';

  @override
  String get themeScreenPreviewRoomOneSub => 'mia: नई टाइल शिप कर दी.';

  @override
  String get themeScreenPreviewRoomTwoName => 'चैंबर · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => '4 घंटे में सील होगा.';

  @override
  String get themeScreenPreviewBubbleQuestion => 'ये कैसा लग रहा है?';

  @override
  String get themeScreenPreviewBubbleAnswer => 'एकदम सही लग रहा है.';

  @override
  String get callScreenVideoCallLabel => 'इनकमिंग वीडियो कॉल';

  @override
  String get callScreenVoiceCallLabel => 'इनकमिंग वॉइस कॉल';

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · रिंग जा रही है…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · रिंग आ रही है…';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · कनेक्ट हो रही है…';
  }

  @override
  String get callScreenStatusConnected => 'कनेक्ट हो गई';

  @override
  String get callScreenStatusEnded => 'कॉल खत्म हो गई';

  @override
  String get callScreenStatusFailed => 'कॉल फेल हो गई';

  @override
  String get callScreenStatusSwitching => 'डिवाइस बदला जा रहा है…';

  @override
  String get callScreenStatusMoved => 'शिफ्ट हो गई';

  @override
  String get callScreenStatusReconnecting => 'फिर से कनेक्ट हो रही है…';

  @override
  String get callScreenPoorConnectionLabel => 'खराब कनेक्शन';

  @override
  String get callScreenWeakConnectionLabel => 'कमज़ोर कनेक्शन';

  @override
  String get callScreenControlUnmute => 'अनम्यूट';

  @override
  String get callScreenControlMute => 'म्यूट';

  @override
  String get callScreenControlCamOn => 'कैम ऑन';

  @override
  String get callScreenControlCamOff => 'कैम ऑफ';

  @override
  String get callScreenControlFlip => 'फ्लिप';

  @override
  String get callScreenControlSpeaker => 'स्पीकर';

  @override
  String get callScreenControlEnd => 'कट';

  @override
  String get linkPreviewCardLinkLabel => 'लिंक';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name ने तुम्हारी रिक्वेस्ट स्वीकार कर ली';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'वो रिक्वेस्ट वापस ले ली गई।';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar =>
      'रिक्वेस्ट अस्वीकार कर दी गई';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'तुमने इस यूज़र को ब्लॉक किया है — पहले अनब्लॉक करो.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'वो अभी फ्रेंड रिक्वेस्ट स्वीकार नहीं कर रहे हैं.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'भेजा नहीं जा सका। फिर से कोशिश करो.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel =>
      'आने वाली रिक्वेस्ट';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'जाने वाली रिक्वेस्ट';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name बातचीत शुरू करना चाहते हैं.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'कुछ लाइनें भेजो। वो स्वीकार या अस्वीकार कर सकते हैं.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'जब तक दोनों की सहमति न हो, यहां कुछ भी हमेशा के लिए नहीं रहता।';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'रूम टाइप';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'अस्थायी';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'स्टैंडर्ड';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'अवधि';

  @override
  String friendRequestDraftScreenDurationSeconds(Object seconds) {
    return '$seconds सेकंड';
  }

  @override
  String friendRequestDraftScreenDurationMinutes(Object minutes) {
    return '$minutesमि';
  }

  @override
  String friendRequestDraftScreenDurationHours(Object hours) {
    return '$hoursघं';
  }

  @override
  String get friendRequestDraftScreenHintWhisperOptional =>
      'पहली लाइन फुसफुसाओ · वैकल्पिक';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'पहला मैसेज जोड़ो · वैकल्पिक';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'फुसफुसाहट · अपने आप मिट जाती है';

  @override
  String get friendRequestDraftScreenHintStartWith => 'शुरुआत के लिए कुछ लिखो…';

  @override
  String get friendRequestDraftScreenApproveButton =>
      'अनुरोध स्वीकारो और रूम खोलो';

  @override
  String get friendRequestDraftScreenDeclineButton => 'अनुरोध ठुकराओ';

  @override
  String get friendRequestDraftScreenCancelRequestButton =>
      'भेजा हुआ अनुरोध रद्द करो';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => 'किसी बड़े से पूछो';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'अनुरोध भेजो';

  @override
  String get discoverScreenTitle => 'खोजो.';

  @override
  String get discoverScreenCaptionPeople => 'लोग';

  @override
  String get discoverScreenCaptionRooms => 'रूम';

  @override
  String get discoverScreenCaptionRequests => 'अनुरोध';

  @override
  String get discoverScreenPeopleBandLabel => 'लोग';

  @override
  String get discoverScreenRoomsBandLabel => 'रूम';

  @override
  String get discoverScreenFindPeopleTitle => 'लोग खोजो';

  @override
  String get discoverScreenFindPeopleSubtitleChild => 'पूरा यूज़रनेम लिखो';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      '@यूज़रनेम या नाम से खोजो';

  @override
  String get discoverScreenRequestsSectionLabel => 'अनुरोध';

  @override
  String get discoverScreenInboxQuiet => 'कोई अनुरोध नहीं आया';

  @override
  String get discoverScreenNothingPending => 'कुछ नहीं भेजा';

  @override
  String get discoverScreenYourPeopleLabel => 'तुम्हारे लोग';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'अभी कोई नहीं — ऊपर लोग खोजो';

  @override
  String get discoverScreenNoFriendsYet => 'अभी कोई नहीं';

  @override
  String get discoverScreenSearchRoomsTitle => 'रूम खोजो';

  @override
  String get discoverScreenSearchRoomsSubtitle => 'नाम से पब्लिक रूम खोजो';

  @override
  String get discoverScreenPublicRoomsLabel => 'पब्लिक रूम';

  @override
  String get discoverScreenLoadingRooms => 'ढूंढ रहे हैं…';

  @override
  String get discoverScreenNoRoomsOpen => 'अभी कुछ भी खुला नहीं';

  @override
  String get discoverScreenIncomingLabel => 'इनकमिंग';

  @override
  String get discoverScreenOutgoingLabel => 'आउटगोइंग';

  @override
  String get discoverScreenIncomingLabelCaps => 'इनकमिंग';

  @override
  String get discoverScreenOutgoingLabelCaps => 'आउटगोइंग';

  @override
  String get discoverScreenJumpPeopleLabel => 'लोग';

  @override
  String get discoverScreenJumpRoomsLabel => 'रूम्स';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return '$label पर जाएं';
  }

  @override
  String get imageCropScreenDefaultTitle => 'एडजस्ट';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'फ़ोटो इस्तेमाल करें';

  @override
  String get imageCropScreenSavingButton => 'सेव हो रहा है…';

  @override
  String get imageCropScreenCancelButton => 'रद्द करें';

  @override
  String get imageCropScreenHeicUnsupported =>
      'यह ब्राउज़र HEIC फ़ोटो नहीं खोल सकता';

  @override
  String get imageCropScreenLoadFailed => 'वह फ़ोटो नहीं खुल पाई';

  @override
  String get imageCropScreenHintCircle =>
      'खिसकाने के लिए खींचें, ज़ूम करने के लिए पिंच करें';

  @override
  String get imageCropScreenHintRect =>
      'फ़्रेम करने के लिए खींचें और पिंच करें';

  @override
  String get loginScreenSignInHeroMuted => 'फिर से\n';

  @override
  String get loginScreenSignInHeroInk => 'स्वागत है।';

  @override
  String get loginScreenSignInFirstHeroMuted => 'नमस्ते\n';

  @override
  String get loginScreenSignInFirstHeroInk => 'स्वागत है।';

  @override
  String get loginScreenSignInCta => 'साइन इन करें';

  @override
  String get loginScreenSignUpHeroMuted => 'नया\n';

  @override
  String get loginScreenSignUpHeroInk => 'चेहरा।';

  @override
  String get loginScreenSignUpCta => 'अकाउंट खोलें';

  @override
  String get loginScreenResetHeroMuted => 'पासवर्ड\n';

  @override
  String get loginScreenResetHeroInk => 'रीसेट।';

  @override
  String get loginScreenResetCta => 'पासवर्ड रीसेट करें';

  @override
  String get loginScreenErrorPasswordsDontMatch => 'पासवर्ड मेल नहीं खाते।';

  @override
  String get loginScreenErrorChoosePasswordFirst => 'पहले एक पासवर्ड चुनें।';

  @override
  String get loginScreenUsernameHint => 'यूज़रनेम';

  @override
  String get loginScreenPasswordHint => 'पासवर्ड';

  @override
  String get loginScreenConfirmPasswordHint => 'पासवर्ड कन्फर्म करें';

  @override
  String get loginScreenNameOptionalHint => 'नाम (वैकल्पिक)';

  @override
  String get loginScreenRecoveryPhraseHint =>
      'तुम्हारा 12-शब्दों वाला रिकवरी फ़्रेज़';

  @override
  String get loginScreenNewPasswordHint => 'नया पासवर्ड';

  @override
  String get loginScreenBackToSignIn => '← साइन इन पर वापस जाएं';

  @override
  String get loginScreenForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get loginScreenSettingUpKidsPhone => 'बच्चे का अकाउंट खोलें';

  @override
  String get loginScreenLegalPrefix => 'अकाउंट खोलकर, तुम सहमत हो: ';

  @override
  String get loginScreenLegalTermsLink => 'नियम';

  @override
  String get loginScreenLegalMiddle => ' और ';

  @override
  String get loginScreenLegalPrivacyLink => 'प्राइवेसी पॉलिसी';

  @override
  String get loginScreenLegalSuffix => ' को स्वीकार करते हो.';

  @override
  String get loginScreenAlreadyHerePrompt => 'पहले से यहाँ हो? ';

  @override
  String get loginScreenSignInLink => 'साइन इन करो';

  @override
  String get loginScreenNoAccountPrompt => 'अकाउंट नहीं है? ';

  @override
  String get loginScreenOpenOneLink => 'एक खोलो';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12 शब्द';
  }

  @override
  String get homeShellEmptyRoomHint => 'बातचीत शुरू करने के लिए एक रूम चुनो';

  @override
  String get homeShellEmptySettingHint => 'एक सेटिंग चुनो';

  @override
  String get searchScreenHintPeople => 'लोग खोजो…';

  @override
  String get searchScreenHintRooms => 'रूम खोजो…';

  @override
  String get searchScreenPeoplePromptChild =>
      'किसी नए को खोजने के लिए पूरा यूज़रनेम टाइप करो';

  @override
  String get searchScreenPeoplePromptDefault => 'यूज़रनेम या नाम से खोजो';

  @override
  String get searchScreenNoMatchChild =>
      'कोई मेल नहीं खाता — नए लोगों के लिए उनका\nपूरा यूज़रनेम बिल्कुल सही लिखना होगा';

  @override
  String get searchScreenNoMatchDefault => 'कोई मेल नहीं खाता';

  @override
  String get searchScreenNoRoomsYet => 'अभी तक कोई पब्लिक रूम नहीं है';

  @override
  String get searchScreenNoRoomsMatch => 'कोई पब्लिक रूम मेल नहीं खाता';

  @override
  String get searchScreenActionAskToAdd => 'जोड़ने को कहो';

  @override
  String get searchScreenActionSendRequest => 'रिक्वेस्ट भेजो';

  @override
  String get searchScreenActionCancel => 'रिक्वेस्ट वापस लो';

  @override
  String get searchScreenActionApprove => 'उनकी रिक्वेस्ट स्वीकार करो';

  @override
  String get searchScreenActionOpenDm => 'डीएम खोलो';

  @override
  String get searchScreenAskedLabel => 'पूछा';

  @override
  String get profileVisibilityScreenTitle => 'दृश्यता प्राथमिकताएं.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'तय करो दूसरे क्या देखें — और तुम तक कैसे पहुंचें.';

  @override
  String get profileVisibilityScreenSectionProfile => 'प्रोफ़ाइल';

  @override
  String get profileVisibilityScreenAvatarLabel => 'अवतार';

  @override
  String get profileVisibilityScreenAvatarDesc => 'तुम्हारी प्रोफ़ाइल फ़ोटो';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => 'ऑनलाइन / दूर';

  @override
  String get profileVisibilityScreenOnlineAwayDesc =>
      'क्या तुम अभी एक्टिव दिखते हो';

  @override
  String get profileVisibilityScreenLastSeenLabel => 'लास्ट सीन';

  @override
  String get profileVisibilityScreenLastSeenDesc => 'तुम आखिरी बार कब थे';

  @override
  String get profileVisibilityScreenSectionMessages => 'मैसेज';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel => 'रीड रिसीट्स भेजो';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      'ऑन होने पर, दूसरे देख सकते हैं कि तुमने उनके मैसेज पढ़ लिए हैं';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel =>
      'रीड रिसीट्स दिखाओ';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      'तुम्हारे मैसेज पढ़े जाने पर उन पर \'सीन\' का निशान देखो';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      'सिर्फ़ वे लोग गिने जाएंगे जिन्होंने \'रीड रिसीट भेजें\' चालू किया हो। बाकी लोग नज़र नहीं आएंगे।';

  @override
  String get profileVisibilityScreenSectionPeople => 'लोग';

  @override
  String get profileVisibilityScreenFriendRequestsLabel => 'फ्रेंड रिक्वेस्ट';

  @override
  String get profileVisibilityScreenFriendRequestsDesc =>
      'तुम्हें कौन फ्रेंड रिक्वेस्ट भेज सकता है';

  @override
  String get profileVisibilityScreenSupervisedTitle =>
      'ये तुम्हारे बड़ों ने सेट किए हैं';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      'यहाँ तुम वही देख सकते हो जो बाकी सब देखते हैं, पर इसे सिर्फ़ कोई बड़ा ही बदल सकता है। वे हमेशा तुम्हारी फ़ोटो, तुम्हारा ऑनलाइन स्टेटस और आख़िरी बार तुम कब थे — देख सकते हैं।';

  @override
  String get profileVisibilityScreenOptionPublic => 'पब्लिक';

  @override
  String get profileVisibilityScreenOptionFriends => 'फ्रेंड्स';

  @override
  String get profileVisibilityScreenOptionNobody => 'कोई नहीं';

  @override
  String get profileVisibilityScreenOptionOn => 'ऑन';

  @override
  String get profileVisibilityScreenOptionOff => 'ऑफ़';

  @override
  String get profileVisibilityScreenOptionAnyone => 'कोई भी';

  @override
  String get logoScreenTitle => 'ऐप लोगो.';

  @override
  String get logoScreenSubtitle => 'तुम्हारे हेडर का निशान — फ़ैसला तुम्हारा.';

  @override
  String get logoScreenAutoLabel => 'ऑटो';

  @override
  String get logoScreenAutoDescription =>
      'तुम्हारी थीम के हिसाब से चलता है. पैलेट बदलने पर निशान भी बदलता है.';

  @override
  String get logoScreenManualLabel => 'मैनुअल';

  @override
  String get logoScreenManualDescription =>
      'कोई भी निशान चुनो, अपनी थीम बनाए रखो.';

  @override
  String get logoScreenAlwaysDefaultLabel => 'हमेशा डिफ़ॉल्ट';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      'थीम कुछ भी हो, हमेशा MonkeyHub का निशान.';

  @override
  String get logoScreenActiveBadge => 'एक्टिव';

  @override
  String get logoScreenMonkeyCollectionHeader => 'मंकी कलेक्शन';

  @override
  String get logoScreenThemesHeader => 'थीम्स';

  @override
  String get recoveryPhraseScreenCopiedSnackbar =>
      'कॉपी हो गया — इसे कहीं सुरक्षित जगह पेस्ट करो';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'पुष्टि करो\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'कि यह तुम हो.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'तुम्हारा पासवर्ड, ताकि कोई और तुम्हारे अकाउंट पर रिकवरी फ्रेज़ न डाल सके.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'पासवर्ड';

  @override
  String get recoveryPhraseScreenContinueButton => 'जारी रखें';

  @override
  String get recoveryPhraseScreenNotNowLink => 'अभी नहीं';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'अपना पासवर्ड डालो.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'सेव करो\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => 'ये शब्द.';

  @override
  String get recoveryPhraseScreenWordsBody =>
      'अगर तुम अपना पासवर्ड भूल जाओ, तो ये बारह शब्द ही तुम्हारे अकाउंट में वापस जाने का इकलौता रास्ता हैं. हम इन्हें दोबारा नहीं दिखा सकते, और न ही इन्हें तुम्हारे लिए वापस ला सकते हैं.';

  @override
  String get recoveryPhraseScreenCopyButton => 'कॉपी करो';

  @override
  String get recoveryPhraseScreenPaperHint =>
      'अगर हो सके, तो इन्हें कागज़ पर लिख लो। फ़ोन में जो कुछ भी है, वह फ़ोन के साथ खो सकता है।';

  @override
  String get recoveryPhraseScreenSavedButton => 'मैंने सेव कर लिए';

  @override
  String get recoveryPhraseScreenBackLink => '← वापस';

  @override
  String get recoveryPhraseScreenKeepPhraseLink =>
      'अभी नहीं — मौजूदा फ़्रेज़ ही रखो';

  @override
  String get homeScreenProfileSemanticLabel => 'तुम्हारी प्रोफ़ाइल';

  @override
  String homeScreenGreeting(Object name) {
    return 'हाय, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'नया रूम';

  @override
  String get homeScreenEmptyRoomsMessage => 'अभी कोई रूम नहीं — एक बनाओ';

  @override
  String get groupCallScreenTitleVideo => 'ग्रुप वीडियो कॉल';

  @override
  String get groupCallScreenTitleVoice => 'ग्रुप वॉइस कॉल';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return 'कॉल में $count';
  }

  @override
  String get groupCallScreenReconnecting => 'फिर से जुड़ रहा है…';

  @override
  String get groupCallScreenUnmuteLabel => 'अनम्यूट';

  @override
  String get groupCallScreenMuteLabel => 'म्यूट';

  @override
  String get groupCallScreenCamOnLabel => 'कैम ऑन';

  @override
  String get groupCallScreenCamOffLabel => 'कैम ऑफ़';

  @override
  String get groupCallScreenFlipLabel => 'फ्लिप';

  @override
  String get groupCallScreenSpeakerLabel => 'स्पीकर';

  @override
  String get groupCallScreenLeaveLabel => 'छोड़ो';

  @override
  String get groupCallScreenYouLabel => 'तुम';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return '$summary के अनुसार फ़िल्टर किया जा रहा है। फ़िल्टर बदलो';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => 'चैट फ़िल्टर करो';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => 'फ़िल्टर साफ़ करो';

  @override
  String get roomFilterDrawerClearLabel => 'साफ़ करो';

  @override
  String get roomFilterDrawerDimensionType => 'टाइप';

  @override
  String get roomFilterDrawerDimensionNature => 'प्रकृति';

  @override
  String get roomFilterDrawerDimensionStatus => 'स्टेटस';

  @override
  String get roomFilterDrawerPanelClear => 'साफ़ करो';

  @override
  String get roomFilterDrawerPanelDone => 'हो गया';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चैट',
      one: '$count चैट',
    );
    return '$label, $_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return '$summary से कुछ मेल नहीं खाता';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सभी $count चैट दिखाओ',
      one: 'सभी $count चैट दिखाओ',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सभी $count चैट दिखाओ',
      one: 'सभी $count चैट दिखाओ',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'नया रूम';

  @override
  String get createRoomSheetTaglineSecret => 'कुछ भी सेव नहीं होगा';

  @override
  String get createRoomSheetTaglineRegular => 'एक जगह जो बनी रहेगी';

  @override
  String get createRoomSheetNameLabel => 'नाम';

  @override
  String get createRoomSheetNameHint => 'कोई सच्चा-सा नाम रखो…';

  @override
  String get createRoomSheetDescriptionLabel => 'विवरण · वैकल्पिक';

  @override
  String get createRoomSheetDescriptionHint => 'रूम के बारे में एक लाइन…';

  @override
  String get createRoomSheetVisibilityLabel => 'दृश्यता';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'पब्लिक';

  @override
  String get createRoomSheetVisibilityPublicSub => 'कोई भी इसे ढूंढ सकता है';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'प्राइवेट';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'सिर्फ इनवाइट पर';

  @override
  String get createRoomSheetTypeLabel => 'टाइप';

  @override
  String get createRoomSheetTypeStandardTitle => 'सामान्य';

  @override
  String get createRoomSheetTypeStandardSub => 'मैसेज बने रहते हैं';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'अस्थायी';

  @override
  String get createRoomSheetTypeEphemeralSub => 'अपने आप डिलीट हो जाते हैं';

  @override
  String get createRoomSheetMessageLifeLabel => 'मैसेज की उम्र';

  @override
  String createRoomSheetTtlSeconds(Object seconds) {
    return '$secondsसे';
  }

  @override
  String createRoomSheetTtlMinutes(Object minutes) {
    return '$minutesमि';
  }

  @override
  String createRoomSheetTtlHours(Object hours) {
    return '$hoursघं';
  }

  @override
  String get createRoomSheetPasswordLabel => 'पासवर्ड · वैकल्पिक';

  @override
  String get createRoomSheetPasswordHint => 'एक पासफ़्रेज़ से लॉक करो…';

  @override
  String get createRoomSheetNameRequiredError => 'नाम ज़रूरी है';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'रूम खोलो';

  @override
  String get createRoomSheetOpenRoomButton => 'रूम खोलो';

  @override
  String get familyScreenTitle => 'परिवार';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चीज़ों के लिए तुम्हारा ओके चाहिए',
      one: '1 चीज़ के लिए तुम्हारा ओके चाहिए',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => 'अभी ऑनलाइन';

  @override
  String get familyScreenPresenceNotPaired => 'अभी तक पेयर नहीं हुआ';

  @override
  String get familyScreenPresenceJustNow => 'अभी-अभी';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return '$minutesमि पहले';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return '$hoursघं पहले';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return '$daysदि पहले';
  }

  @override
  String get familyScreenPairButton => 'पेयर करो';

  @override
  String get familyScreenReleaseButton => 'अनलिंक करें';

  @override
  String get familyScreenSettingsButton => 'सेटिंग्स';

  @override
  String get familyScreenAddChildButton => 'बच्चा जोड़ें';

  @override
  String get familyScreenEmptyStateTitle => 'अभी तक कोई बच्चा नहीं';

  @override
  String get familyScreenEmptyStateBody =>
      'अपने बच्चे के लिए एक अकाउंट बनाएं, फिर उसे उसके फ़ोन से पेयर करें।';

  @override
  String get reactionDetailsSheetTitle => 'रिएक्शन';

  @override
  String get reactionDetailsSheetEmptyState => 'अब यहाँ कुछ नहीं बचा';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लोग',
      one: '$count व्यक्ति',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => 'सभी';

  @override
  String get reactionDetailsSheetYouBadge => 'तुम';

  @override
  String get roomLayoutScreenTitle => 'चैट लिस्ट।';

  @override
  String get roomLayoutScreenSubtitle =>
      'चैट्स कैसे स्टैक होते हैं और तुम उन्हें कैसे फ़िल्टर करते हो';

  @override
  String get roomLayoutScreenLayoutSectionLabel => 'लेआउट';

  @override
  String get roomLayoutScreenRowLayoutLabel => 'रो लेआउट';

  @override
  String get roomLayoutScreenRowLayoutDescription =>
      'एक कॉलम, पूरी चौड़ाई में। एक नज़र में पढ़ना आसान।';

  @override
  String get roomLayoutScreenGridLayoutLabel => 'ग्रिड लेआउट';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      'दो कॉलम, कॉम्पैक्ट। एक नज़र में ज़्यादा चैट्स।';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => 'फ़िल्टर कंट्रोल';

  @override
  String get roomLayoutScreenChipRowLabel => 'चिप रो';

  @override
  String get roomLayoutScreenChipRowDescription =>
      'हमेशा दिखते हैं। किसी भी फ़िल्टर तक बस एक टैप, सिर्फ़ एक रो जितनी जगह।';

  @override
  String get roomLayoutScreenDrawerButtonLabel => 'ड्रॉअर बटन';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      'एक बटन जो खुलता है। जब तक तुम न खोलो, रास्ते में कुछ नहीं।';

  @override
  String get roomLayoutScreenQuietRoomSectionLabel => 'शांत रूम';

  @override
  String get roomLayoutScreenPlainCornerLabel => 'खाली कोना';

  @override
  String get roomLayoutScreenPlainCornerDescription =>
      'जिस रूम में कुछ कहा नहीं गया, वो सादा रहता है';

  @override
  String get roomLayoutScreenMonogramLabel => 'रूम का पहला अक्षर';

  @override
  String get roomLayoutScreenMonogramDescription =>
      'एक बड़ा धुंधला अक्षर खाली कोने को भर देता है';

  @override
  String get roomLayoutScreenActiveBadge => 'चयनित';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel =>
      'पिन किए गए मैसेज पर जाएं';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => 'सभी पिन किए गए मैसेज';

  @override
  String get pinnedBannerTitleSingle => 'पिन किया गया मैसेज';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return 'पिन किया गया मैसेज  $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => 'चैट स्टाइल।';

  @override
  String get pinnedBannerChatStyleSubtitle => 'चैट कैसी दिखती है';

  @override
  String get pinnedBannerClassicLabel => 'क्लासिक';

  @override
  String get pinnedBannerClassicSubtitle =>
      'डिवाइडर-बॉर्डर वाला हेडर, फ्लैट कंपोज़र।';

  @override
  String get pinnedBannerCompactLabel => 'कॉम्पैक्ट';

  @override
  String get pinnedBannerCompactSubtitle =>
      'बातचीत के ऊपर तैरते धुंधले कैप्सूल।';

  @override
  String get pinnedBannerActiveBadge => 'चयनित';

  @override
  String get audioMessageMissingLabel => '[ऑडियो गायब]';

  @override
  String get audioMessageUnavailableLabel => 'ऑडियो उपलब्ध नहीं';

  @override
  String get audioMessageRetryHint => 'फिर से कोशिश करने के लिए टैप करो';

  @override
  String get audioMessageLoadingLabel => 'लोड हो रहा है…';

  @override
  String get audioMessageUsernameRequiredError => 'अपना यूज़रनेम डालो।';

  @override
  String get audioMessagePasswordRequiredError => 'अपना पासवर्ड डालो।';

  @override
  String get audioMessageCancelSemanticLabel => 'रद्द करो';

  @override
  String get audioMessageHeroCreateLine1 => 'लगभग\n';

  @override
  String get audioMessageHeroCreateLine2 => 'हो गया।';

  @override
  String get audioMessageHeroLinkLine1 => 'वापसी पर\n';

  @override
  String get audioMessageHeroLinkLine2 => 'स्वागत है।';

  @override
  String get audioMessageCreateSubtitle =>
      'ऐसा यूज़रनेम चुनो ताकि तुम्हारे परिवार और दोस्त तुम्हें ढूंढ सकें।';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return 'एक बार साइन इन करो और $provider तुम्हारे अकाउंट से जुड़ जाएगा।';
  }

  @override
  String get audioMessageUsernameHint => 'यूज़रनेम';

  @override
  String get audioMessageDisplayNameHint => 'डिस्प्ले नेम (वैकल्पिक)';

  @override
  String get audioMessagePasswordHint => 'पासवर्ड';

  @override
  String get audioMessageSwitchToLinkPrompt => 'वो मेरा है — साइन इन करो';

  @override
  String get audioMessageCreateAccountButton => 'अकाउंट बनाओ';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return 'साइन इन करो और $provider लिंक करो';
  }

  @override
  String get audioMessageSwitchToLinkModeLink =>
      'तुम्हारे पास पहले से अकाउंट है?';

  @override
  String get audioMessageSwitchToCreateModeLink => 'यहाँ नए हो? अकाउंट बनाओ';

  @override
  String get approvalsScreenTitle => 'मंज़ूरियां';

  @override
  String get approvalsScreenEmptyTitle => 'कुछ भी पेंडिंग नहीं';

  @override
  String get approvalsScreenEmptySubtitle => 'तुमने सब देख लिया';

  @override
  String get approvalsScreenErrorNotGuardian => 'ये फैसला तुम्हारा नहीं है';

  @override
  String get approvalsScreenErrorAlreadyHandled =>
      'यह पहले ही कहीं और तय हो चुका है';

  @override
  String get approvalsScreenErrorGeneric => 'सेव नहीं हो पाया — फिर कोशिश करो';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child $other को जोड़ना चाहता है';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other $child को जोड़ना चाहता है';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child $room में शामिल होना चाहता है';
  }

  @override
  String get approvalsScreenSomeoneLower => 'किसी';

  @override
  String get approvalsScreenSomeoneCapital => 'कोई';

  @override
  String get approvalsScreenRoomFallback => 'एक रूम';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      'उन्हें रिक्वेस्ट भेजी जाएगी। हां कहना है या नहीं, ये फैसला उन्हीं का है।';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$child अब यह रिक्वेस्ट देख पाएगा, और वो इसे स्वीकार या नज़रअंदाज़ कर सकता है।';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      'जब तक तुम इसे वापस नहीं लेते, वो वहां पढ़ और पोस्ट कर सकता है।';

  @override
  String get approvalsScreenNotYetButton => 'अभी नहीं';

  @override
  String get approvalsScreenAllowButton => 'अनुमति दो';

  @override
  String get approvalsScreenForwardDirectMessageFallback => 'डायरेक्ट मैसेज';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मैसेज फ़ॉरवर्ड करो',
      one: 'मैसेज फ़ॉरवर्ड करो',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'अभी कोई और चैट नहीं है';

  @override
  String get approvalsScreenForwardNoMatches => 'कुछ नहीं मिला';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'एक बार में अधिकतम $max चैट';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'चैट खोजो';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return '$title का चयन हटाओ';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return '$title चुनो';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'अस्थायी';

  @override
  String get approvalsScreenForwardSendSemantic => 'भेजो';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count को भेजो',
      zero: 'भेजो',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => 'लिंक किए गए खाते';

  @override
  String get linkedAccountsScreenSubtitle =>
      'वे खाते जो तुमने इस खाते से लिंक किए हैं, ताकि तुम बिना पासवर्ड के साइन इन कर सको।';

  @override
  String get linkedAccountsScreenEmptyState =>
      'इस डिवाइस पर लिंक करने के लिए कुछ नहीं है।';

  @override
  String get linkedAccountsScreenStatusChecking => 'जांच हो रही है…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return 'तुम अपने किसी भी डिवाइस पर $provider से साइन इन कर सकते हो।';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return '$provider जोड़ो ताकि तुम्हें पासवर्ड टाइप न करना पड़े।';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return '$provider अनलिंक करो';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => 'अनलिंक करो';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return '$provider से साइन इन करना बंद करने के लिए अपना पासवर्ड डालो।';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return '$provider लिंक करो';
  }

  @override
  String get linkedAccountsScreenLinkAction => 'लिंक करो';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return '$provider से साइन इन करना शुरू करने के लिए अपना पासवर्ड डालो।';
  }

  @override
  String get linkedAccountsScreenPillChecking => 'जांच जारी';

  @override
  String get linkedAccountsScreenPillLinked => 'लिंक्ड';

  @override
  String get linkedAccountsScreenPillNotLinked => 'लिंक नहीं';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => 'वॉइस';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'वीडियो';

  @override
  String get linkedAccountsScreenCallSheetTitle => 'कॉल शुरू करो';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle => 'सबको कॉल करो';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      'इस रूम के सभी सदस्यों को रिंग करो';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle => 'लोग चुनो';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle =>
      'किसे बुलाना है, चुनो';

  @override
  String get linkedAccountsScreenCallSheetCallFullError =>
      'यह कॉल फुल है (ज़्यादा से ज़्यादा 6 लोग)';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError =>
      'कॉल शुरू नहीं हो सकी';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle => 'कॉल में इनवाइट करो';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers =>
      'यहाँ कोई और सदस्य नहीं है';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => 'लोगों को चुनो';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => 'कॉल शुरू करो';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return 'कॉल शुरू करो ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => 'हैलो';

  @override
  String get childPairScreenGreetingLine2 => 'तुम।';

  @override
  String get childPairScreenIntro =>
      'किसी बड़े से MonkeyHub खोलने और “डिवाइस पेयर करें” पर टैप करने के लिए कहो। फिर उनका कोड स्कैन करो, या वे जो छह अंक बताएं, उन्हें टाइप करो।';

  @override
  String get childPairScreenOrDivider => 'या';

  @override
  String get childPairScreenGenericError =>
      'कुछ गड़बड़ हो गई। फिर से कोशिश करो।';

  @override
  String get childPairScreenAccountGoneError => 'वह अकाउंट अब मौजूद नहीं है।';

  @override
  String get childPairScreenScanButtonLabel => 'उनका कोड स्कैन करो';

  @override
  String get childPairScreenNoCameraMessage =>
      'यहाँ कैमरा नहीं है — इसके बजाय छह अंक टाइप करो।';

  @override
  String get childPairScreenStopScanning => 'स्कैनिंग रोको';

  @override
  String get childPairScreenSubmitButtonLabel => 'मुझे अंदर आने दो';

  @override
  String get childPairScreenBackToSignIn => '← साइन इन पर वापस';

  @override
  String get fileMessageUnavailable => 'फ़ाइल अब उपलब्ध नहीं है';

  @override
  String get fileMessageOpenFailed => 'वह फ़ाइल नहीं खुल सकी';

  @override
  String get fileMessageDefaultName => 'दस्तावेज़';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return '$name सेव करो';
  }

  @override
  String fileMessageViewSemanticLabel(Object name) {
    return '$name देखो';
  }

  @override
  String get textFileViewerDownloadTooltip => 'डाउनलोड';

  @override
  String get textFileViewerTruncatedNotice =>
      'इस फ़ाइल का कुछ हिस्सा दिखाया जा रहा है — बाकी देखने के लिए डाउनलोड करें।';

  @override
  String get fileMessageUploadFailedLabel => 'असफल';

  @override
  String get fileMessageSendingLabel => 'भेजा जा रहा है…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · भेजा जा रहा है…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return '$countमि पहले';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return '$countघं पहले';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return '$countदि पहले';
  }

  @override
  String get fileMessageStandardBadge => 'सामान्य';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ड्राफ़्ट मैसेज मिले हैं · देखने के लिए टैप करो',
      one: '$count ड्राफ़्ट मैसेज मिला है · देखने के लिए टैप करो',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => 'स्वीकार करो';

  @override
  String get fileMessageDeclineButton => 'अस्वीकार करो';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return '$ago भेजा गया';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count भेजे मैसेज पेंडिंग हैं',
      one: '$count भेजा मैसेज पेंडिंग है',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => 'अनुरोध रद्द करो';

  @override
  String get destructiveSheetCannotBeUndone => 'इसे पूर्ववत नहीं किया जा सकता';

  @override
  String get destructiveSheetCancelSemanticLabel => 'रद्द करें';

  @override
  String get destructiveSheetCancelButtonLabel => 'रद्द करें';

  @override
  String get destructiveSheetHideLabel => 'छिपाएं';

  @override
  String get destructiveSheetViewLabel => 'देखें';

  @override
  String get destructiveSheetPairingMintError =>
      'कोड नहीं बन पाया — फिर से कोशिश करो।';

  @override
  String get destructiveSheetPairingReleaseTitle => 'रिलीज़';

  @override
  String get destructiveSheetPairingPairTitle => 'पेयर';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return '$name के फ़ोन पर उनकी प्रोफ़ाइल खोलो, “यह फ़ोन वापस दो” पर टैप करो, और ये नंबर टाइप करो।';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return '$name के फ़ोन पर MonkeyHub खोलो और इसे स्कैन करो — या नंबर टाइप करो।';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'यह कोड एक्सपायर हो चुका है';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return '$time में एक्सपायर होगा';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'नया कोड';

  @override
  String get destructiveSheetPairingOneUseNote =>
      'सिर्फ़ एक बार इस्तेमाल के लिए। नया कोड बनाने पर पुराना कोड रद्द हो जाएगा।';

  @override
  String get deepOceanThemeAttachButtonLabel => 'अटैच करें';

  @override
  String get deepOceanThemeCameraButtonLabel => 'कैमरा';

  @override
  String get deepOceanThemeSendButtonLabel => 'भेजें';

  @override
  String get deepOceanThemeEphemeralHint =>
      'कुछ फुसफुसाओ जिसे सर्वर भूल जाएगा…';

  @override
  String get deepOceanThemeDefaultHint => 'कुछ कहो…';

  @override
  String get deepOceanThemeMessageHint => 'मैसेज';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'यह फ़ाइल गायब है';

  @override
  String get photoChromeMediaYouLabel => 'तुम';

  @override
  String get photoChromeCloseSemanticLabel => 'बंद करें';

  @override
  String get photoChromeShowInChatSemanticLabel => 'चैट में दिखाएं';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name टाइप कर रहे हैं';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1 और $name2 टाइप कर रहे हैं';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1, $name2 +$extra टाइप कर रहे हैं';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => 'इनकमिंग कॉल';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'इनकमिंग वीडियो कॉल';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'इनकमिंग वॉइस कॉल';

  @override
  String get typingIndicatorDeclineButtonLabel => 'अस्वीकार करें';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'अस्वीकार हो रहा है…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'स्वीकार करें';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'कनेक्ट हो रहा है…';

  @override
  String get messageStampNavigationTitle => 'नेविगेशन.';

  @override
  String get messageStampNavigationSubtitle =>
      'तुम चैट, डिस्कवर, फ़ीड और सेटिंग्स के बीच कैसे स्विच करते हो';

  @override
  String get messageStampRadialOrbLabel => 'रेडियल गोला';

  @override
  String get messageStampRadialOrbDescription =>
      'कोने पर दबाकर रखो + खींचो। इस्तेमाल में न होने पर शांत, एक इशारा जो धीरे-धीरे अपना लगने लगे।';

  @override
  String get messageStampBottomPillLabel => 'निचला कैप्सूल';

  @override
  String get messageStampBottomPillDescription =>
      'क्लासिक टैप। हमेशा दिखता है, सीखने की कोई ज़रूरत नहीं।';

  @override
  String get messageStampActiveLabel => 'सक्रिय';

  @override
  String get messageStampUploadingLabel => 'अपलोड हो रहा है';

  @override
  String get messageStampSendingLabel => 'भेजा जा रहा है';

  @override
  String get messageStampFailedToSendLabel => 'भेजने में विफल';

  @override
  String get messageStampSentLabel => 'भेजा गया';

  @override
  String get messageStampDeliveredLabel => 'डिलीवर हो गया';

  @override
  String get messageStampSeenLabel => 'देखा गया';

  @override
  String get messageStampSavedLabel => 'सेव किया गया';

  @override
  String messageStampCountdownSeconds(Object count) {
    return '$countसे';
  }

  @override
  String messageStampCountdownMinutes(Object count) {
    return '$countमि';
  }

  @override
  String get voiceRecorderScreenMicPermissionDeniedSnackbar =>
      'माइक्रोफ़ोन की अनुमति नहीं मिली';

  @override
  String get voiceRecorderScreenStatusRecording => 'रिकॉर्डिंग';

  @override
  String get voiceRecorderScreenStatusReady => 'तैयार';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'शुरू करने के लिए टैप करो';

  @override
  String get voiceRecorderScreenReRecordButton => 'दोबारा रिकॉर्ड करो';

  @override
  String get voiceRecorderScreenStopButton => 'रोको';

  @override
  String get voiceRecorderScreenSendButton => 'भेजो';

  @override
  String get voiceRecorderScreenRecordButton => 'रिकॉर्ड करो';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => 'सभी';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge =>
      'सभी को सूचित करेगा';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => 'मालिक';

  @override
  String get releaseDeviceScreenFallbackChildName => 'बच्चे';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return 'यह $name को इस फ़ोन से साइन आउट कर देता है और फ़ोन वापस कर देता है — फ़ोन सामान्य साइन-इन स्क्रीन पर लौट आता है, और कोई भी इसे इस्तेमाल कर सकता है।';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'उनका अकाउंट, मैसेज और दोस्त सब कुछ सुरक्षित रहता है। उन्हें कभी भी दोबारा साइन इन किया जा सकता है।';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return 'किसी बड़े से कहो — MonkeyHub खोलें, परिवार में $name को ढूंढें, और “रिलीज़” पर टैप करें।';
  }

  @override
  String get releaseDeviceScreenOrDivider => 'या';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      'अगर सिर्फ़ यही एक फ़ोन है, तो कोई बड़ा यहीं साइन इन कर सकता है।';

  @override
  String get releaseDeviceScreenUsernameHint => 'किसी बड़े का यूज़रनेम';

  @override
  String get releaseDeviceScreenPasswordHint => 'उनका पासवर्ड';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => 'साइन आउट करो';

  @override
  String get releaseDeviceScreenChecking => 'जांच हो रही है…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return '$name को साइन आउट करो';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => 'यह फ़ोन वापस दे दो';

  @override
  String get releaseDeviceScreenErrorCodeExpired =>
      'वह कोड ख़त्म हो चुका है। नया कोड माँगो।';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      'वह कोड काम नहीं आया। हो सकता है वह पहले ही इस्तेमाल हो चुका हो।';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      'वह काम नहीं हुआ। यूज़रनेम और पासवर्ड जांच लो।';

  @override
  String get releaseDeviceScreenErrorGeneric =>
      'कुछ गड़बड़ हो गई। फिर से कोशिश करो।';

  @override
  String get activeCallPillMoveHereSemanticLabel =>
      'कॉल को इस डिवाइस पर ले जाना';

  @override
  String activeCallPillCallWith(Object name) {
    return '$name के साथ कॉल';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return '$device पर';
  }

  @override
  String get activeCallPillMoveHereLabel => 'यहाँ ले जाओ';

  @override
  String get activeCallPillUnknownCaller => 'अज्ञात';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'iOS सिम्युलेटर';

  @override
  String get activeCallPillPlatformAndroid => 'Android डिवाइस';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'Windows पीसी';

  @override
  String get activeCallPillPlatformLinux => 'Linux डिवाइस';

  @override
  String get activeCallPillPlatformBrowser => 'ब्राउज़र';

  @override
  String get activeCallPillPlatformOther => 'कोई और डिवाइस';

  @override
  String get activeCallPillPinnedHeader => 'पिन किए गए';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'पिन किए गए · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'अब कुछ भी पिन नहीं है';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return '$name के मैसेज पर जाना';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return '$name के मैसेज से पिन हटाना';
  }

  @override
  String get callButtonErrorBusy => 'किसी और कॉल में व्यस्त';

  @override
  String get callButtonErrorCallFailed => 'कॉल शुरू नहीं हो सकी';

  @override
  String get callButtonErrorNotMember => 'इस रूम के सदस्य नहीं हो';

  @override
  String get callButtonErrorGeneric => 'कॉल शुरू नहीं हो सकी';

  @override
  String get callButtonAlreadyOnCall => 'तुम पहले से ही कॉल पर हो';

  @override
  String get callButtonBusyElsewhere => 'दूसरे डिवाइस पर कॉल चल रही है';

  @override
  String get callButtonVoiceCallTooltip => 'वॉइस कॉल';

  @override
  String get callButtonVideoCallTooltip => 'वीडियो कॉल';

  @override
  String get callButtonTooltip => 'कॉल';

  @override
  String get callButtonReplyStyleTitle => 'रिप्लाई स्टाइल.';

  @override
  String get callButtonReplyStyleSubtitle =>
      'रिप्लाई अपने मूल मैसेज को कैसे दिखाता है';

  @override
  String get callButtonReplyStylePhantomEchoLabel => 'फीकी गूंज';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      'पैरेंट का फीका बबल ऊपर तैरता है, घुमावदार कनेक्टर और जोड़ बिंदु पर ब्रांच आइकन के साथ।';

  @override
  String get callButtonReplyStyleStickyNoteLabel => 'स्टिकी नोट';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      'एक थोड़ा घुमाया हुआ पोलेरॉइड-स्टाइल कार्ड, बबल के कोने पर क्लिप किया हुआ।';

  @override
  String get callButtonReplyStyleComicTailLabel => 'कॉमिक नोक';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      'पैरेंट का एक छोटा बबल, जिसमें नीचे की ओर इशारा करती कॉमिक-बुक त्रिकोणी नोक है।';

  @override
  String get callButtonReplyStyleClassicLabel => 'क्लासिक';

  @override
  String get callButtonReplyStyleClassicDescription =>
      'एक्सेंट-रंगी कोट कैप्सूल, डोरी बार और अवतार के साथ — वही जाना-पहचाना व्हाट्सएप-स्टाइल लुक।';

  @override
  String get callButtonReplyStyleActiveBadge => 'सक्रिय';

  @override
  String get callButtonReplyPreviewSampleMessage => 'अरे, नया डेमो देखा क्या?';

  @override
  String get callButtonReplyPreviewSampleReply => 'हां, वो ब्लर एकदम कमाल है।';

  @override
  String get childSetupScreenErrorPickUsername => 'उनके लिए यूज़रनेम चुनो।';

  @override
  String get childSetupScreenErrorUsernameTaken =>
      'यह यूज़रनेम पहले से लिया जा चुका है।';

  @override
  String get childSetupScreenErrorChildNotAllowed =>
      'सिर्फ बड़ों का अकाउंट ही बच्चा जोड़ सकता है।';

  @override
  String get childSetupScreenErrorGeneric =>
      'अकाउंट नहीं बन सका — फिर से कोशिश करो।';

  @override
  String get childSetupScreenTitle => 'बच्चा जोड़ो';

  @override
  String get childSetupScreenHeading => 'कौन\nहैं ये?';

  @override
  String get childSetupScreenNameLabel => 'नाम';

  @override
  String get childSetupScreenNameHint => 'तुम उन्हें क्या बुलाते हो';

  @override
  String get childSetupScreenUsernameLabel => 'यूज़रनेम';

  @override
  String get childSetupScreenUsernameHint => 'दोस्त उन्हें कैसे ढूंढेंगे';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'उन्हें क्या मिलता है';

  @override
  String get childSetupScreenBulletTalkImmediately =>
      'वो अभी से तुमसे और अपने भाई-बहनों से बात कर सकते हैं।';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      'बाकी सबके लिए पहले तुम्हारी मंज़ूरी ज़रूरी है — चाहे वो किसी को जोड़ने की रिक्वेस्ट भेजें, या कोई उन्हें जोड़ने की रिक्वेस्ट भेजे।';

  @override
  String get childSetupScreenBulletPublicRoomsOff =>
      'पब्लिक रूम्स तब तक बंद रहते हैं जब तक तुम उन्हें ऑन नहीं करते।';

  @override
  String get childSetupScreenBulletCantSignOut =>
      'वो साइन आउट नहीं कर सकते, और तुम हमेशा देख सकते हो कि वो कैसे कर रहे हैं।';

  @override
  String get childSetupScreenCreateButton => 'बनाओ + पेयर करो';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return '$name को मैसेज करो';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => 'रिक्वेस्ट भेजी';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'सदस्य';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'सभी $count देखो';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return 'सभी $count देखो';
  }

  @override
  String get bubbleStyleScreenTitle => 'बबल स्टाइल.';

  @override
  String get bubbleStyleScreenSubtitle =>
      'वो शक्ल जिसमें तुम्हारे शब्द पहुंचते हैं';

  @override
  String get bubbleStyleScreenTailedLabel => 'नोकदार';

  @override
  String get bubbleStyleScreenTailedDescription =>
      'नोक हर मैसेज-समूह को बंद करती है; उसके ऊपर की पंक्तियां एक ब्लॉक में सिमट जाती हैं।';

  @override
  String get bubbleStyleScreenSoftLabel => 'मुलायम';

  @override
  String get bubbleStyleScreenSoftDescription =>
      'कोई नोक नहीं — सिलसिला बस अपने कसे हुए भीतरी कोनों से जुड़ा रहता है।';

  @override
  String get bubbleStyleScreenPillLabel => 'कैप्सूल';

  @override
  String get bubbleStyleScreenPillDescription =>
      'पूरी तरह गोल कैप्सूल — हर पंक्ति में एक जैसे।';

  @override
  String get bubbleStyleScreenSlabLabel => 'स्लैब';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'चौकोर कोने — तीखे, छपे जैसे, सोच-समझकर बनाए गए।';

  @override
  String get bubbleStyleScreenActiveBadge => 'सक्रिय';

  @override
  String get bubbleStyleScreenPreviewQuestion => 'तो? कैसा लग रहा है?';

  @override
  String get bubbleStyleScreenPreviewReplyOne => 'बेहतर';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => 'और बेहतर';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => 'वीडियो';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => 'फ़ोटो';

  @override
  String get incomingGroupCallScreenCallFullError =>
      'यह कॉल पहले से फुल है (ज़्यादा से ज़्यादा 6 लोग)';

  @override
  String get incomingGroupCallScreenJoinFailedError =>
      'इस कॉल में शामिल नहीं हो पाए';

  @override
  String get incomingGroupCallScreenDefaultRoomName => 'ग्रुप कॉल';

  @override
  String get incomingGroupCallScreenDefaultStarterName => 'कोई';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starter ने वीडियो कॉल शुरू की';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starter ने वॉइस कॉल शुरू की';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '$count पहले से मौजूद';
  }

  @override
  String get incomingGroupCallScreenDismissButton => 'अस्वीकार करें';

  @override
  String get incomingGroupCallScreenJoinButton => 'जॉइन करें';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चैट',
      one: '$count चैट',
    );
    return '$_temp0';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मैसेज',
      one: '$count मैसेज',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      'आख़िरी मैसेज अभी-अभी';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'आख़िरी मैसेज $hours घंटे पहले';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'आख़िरी मैसेज कल';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'आख़िरी मैसेज $days दिन पहले';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'आख़िरी मैसेज काफ़ी पहले';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'वापस लें';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return '$contactName को $childName से हटाना है?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'वे एक-दूसरे से संपर्क नहीं कर पाएँगे, और उनकी बातचीत भी साथ में मिट जाएगी।';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'वे एक-दूसरे से संपर्क नहीं कर पाएँगे। $contactName को इसका पता नहीं चलेगा।';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats · $messages डिलीट हो जाएँगे';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      'दोनों की तरफ़ से हमेशा के लिए मिट जाएगा — फ़ोटो और वॉइस नोट्स समेत। इसे वापस नहीं लाया जा सकता।';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'वे $count रूम भी शेयर करते हैं',
      one: 'वे $count रूम भी शेयर करते हैं',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'ये बने रहेंगे। अगर इन्हें निकालना है तो नीचे रूम्स लिस्ट से रूम वापस ले लो।';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'वापस लो और डिलीट करो';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return '$contactName को हटा देता है और $messages मिटा देता है।';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return '$contactName को अनुमति सूची से हटा देता है।';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'रद्द करो';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton =>
      'रद्द करो';

  @override
  String get groupCallBannerCallFullError =>
      'वह कॉल फुल है (ज़्यादा से ज़्यादा 6 लोग)';

  @override
  String get groupCallBannerJoinFailedError => 'कॉल जॉइन नहीं हो सकी';

  @override
  String get groupCallBannerUnknownParticipant => 'कोई';

  @override
  String get groupCallBannerOngoingVideoCall => 'चल रही वीडियो कॉल';

  @override
  String get groupCallBannerOngoingVoiceCall => 'चल रही वॉइस कॉल';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra कॉल में';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => 'कॉल जॉइन करो';

  @override
  String get groupCallBannerJoinButtonLabel => 'जॉइन';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'रूम जॉइन करो';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य',
      one: '$count सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => 'पासवर्ड';

  @override
  String get groupCallBannerPasswordHint => 'पासफ़्रेज़…';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'जॉइन करो';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'जॉइन';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'रद्द करो';

  @override
  String get groupCallBannerCancelButtonLabel => 'रद्द करो';

  @override
  String get viewOnceViewerBadgeLabel => 'एक बार देखो';

  @override
  String get socialButtonDividerOr => 'या';

  @override
  String get socialButtonGoogleContinue => 'Google से जारी रखें';

  @override
  String get discoverListsPeopleTitle => 'तुम्हारे लोग.';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लोग',
      one: '$count व्यक्ति',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => 'अपने लोगों को फ़िल्टर करो…';

  @override
  String get discoverListsClearFilterSemanticLabel => 'फ़िल्टर हटाओ';

  @override
  String get discoverListsNoOneYet => 'अभी तक कोई नहीं';

  @override
  String discoverListsNoMatches(Object query) {
    return '\"$query\" से कोई मेल नहीं खाता';
  }

  @override
  String get discoverListsVoiceCallLabel => 'वॉइस कॉल';

  @override
  String get discoverListsVideoCallLabel => 'वीडियो कॉल';

  @override
  String get approvalGateAlreadyAskedLabel => 'पहले से पूछा गया';

  @override
  String get approvalGateAskGrownUpLabel => 'किसी बड़े से पूछो';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return 'तुम $what के बारे में पहले ही पूछ चुके हो।';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return '$what से पहले तुम्हें किसी बड़े की हाँ चाहिए।';
  }

  @override
  String get approvalGateDisabledBody =>
      'किसी बड़े ने फ़िलहाल इसे बंद कर रखा है।';

  @override
  String get approvalGateAlreadyAskedFooter =>
      'उन्हें इसके बारे में मैसेज मिल जाएगा। थोड़ी देर बाद फिर देखो।';

  @override
  String get approvalGateWillNotifyFooter =>
      'हम उन्हें बता देंगे। जवाब मिलते ही तुम्हें यहाँ दिख जाएगा।';

  @override
  String get approvalGateTalkToThemFooter =>
      'अगर तुम्हें लगता है कि इसे बदलना चाहिए, तो तुम उनसे इस बारे में बात कर सकते हो।';

  @override
  String get approvalGateAskButton => 'पूछो';

  @override
  String get approvalGateNotNowButton => 'अभी नहीं';

  @override
  String get approvalGateOkButton => 'ठीक है';

  @override
  String get approvalGateWaitingPillLabel => 'किसी बड़े का इंतज़ार';

  @override
  String get reportSheetTitle => 'रिपोर्ट';

  @override
  String get reportSheetSubtitle => 'हमें बताओ, क्या गड़बड़ है।';

  @override
  String get reportSheetPrivacyNote =>
      'रिपोर्ट निजी होती है — दूसरे व्यक्ति को पता नहीं चलता।';

  @override
  String get reportSheetReasonSpamLabel => 'स्पैम';

  @override
  String get reportSheetReasonSpamDescription =>
      'अनचाहे विज्ञापन या बार-बार भेजे गए मैसेज';

  @override
  String get reportSheetReasonHarassmentLabel => 'उत्पीड़न';

  @override
  String get reportSheetReasonHarassmentDescription =>
      'निशाना बनाना या तंग करना';

  @override
  String get reportSheetReasonImpersonationLabel => 'नकली पहचान';

  @override
  String get reportSheetReasonImpersonationDescription =>
      'किसी और होने का दिखावा करना';

  @override
  String get reportSheetReasonInappropriateLabel => 'अनुचित';

  @override
  String get reportSheetReasonInappropriateDescription =>
      'यौन, हिंसक, या अवैध कंटेंट';

  @override
  String get reportSheetReasonOtherLabel => 'अन्य';

  @override
  String get reportSheetReasonOtherDescription => 'कुछ और';

  @override
  String get reportSheetOtherNoteHint => 'क्या हुआ?';

  @override
  String get reportSheetSubmitSemanticLabel => 'रिपोर्ट सबमिट करें';

  @override
  String get reportSheetSubmitButton => 'सबमिट करो';

  @override
  String get reportSheetUpdateRequiredTitle => 'अपडेट ज़रूरी';

  @override
  String get reportSheetUpdateAvailableTitle => 'अपडेट उपलब्ध';

  @override
  String get reportSheetUpdateMandatoryBody =>
      'यह वर्ज़न अब ठीक से काम करने के लिए बहुत पुराना हो चुका है। आगे बढ़ने के लिए अपडेट करो।';

  @override
  String get reportSheetUpdateAvailableBody =>
      'MonkeyHub का एक नया वर्ज़न उपलब्ध है।';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => 'अपडेट करो';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'TestFlight खुलेगा';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'App Store खुलेगा';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'Google Play खुलेगा';

  @override
  String get reportSheetUpdateActionOpensDownloadPage => 'डाउनलोड पेज खुलेगा';

  @override
  String get reportSheetUpdateActionReloads => 'नए वर्शन के साथ रीलोड होगा';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'बाद में';

  @override
  String get reportSheetUpdateLaterButton => 'बाद में';

  @override
  String get roomFilterBarAllChipLabel => 'सभी';

  @override
  String roomFilterBarChipCountSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चैट',
      one: '$count चैट',
    );
    return '$label, $_temp0';
  }

  @override
  String composerReplyCardReplyingToLabel(Object name) {
    return '$name को जवाब';
  }

  @override
  String get roomCardLockedBadge => 'लॉक्ड';

  @override
  String get roomCardTimeAgoJustNow => 'अभी अभी';

  @override
  String roomCardTimeAgoSeconds(Object seconds) {
    return '$secondsसे';
  }

  @override
  String roomCardTimeAgoMinutes(Object minutes) {
    return '$minutesमि';
  }

  @override
  String roomCardTimeAgoHours(Object hours) {
    return '$hoursघं';
  }

  @override
  String roomCardTimeAgoDays(Object days) {
    return '$daysदि';
  }

  @override
  String roomCardTimeAgoWeeks(Object weeks) {
    return '$weeksह';
  }

  @override
  String roomCardStartedAgo(Object ago) {
    return '$ago पहले बना';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count अंदर';
  }

  @override
  String get roomCardMessagesFadeLabel => 'मैसेज फीके होते हैं';

  @override
  String get roomCardEnterLabel => '↗ अंदर जाएं';

  @override
  String get roomCardBlockedScreenTitle => 'ब्लॉक्ड';

  @override
  String get roomCardBlockedEmptyState =>
      'तुमने अभी तक किसी को ब्लॉक नहीं किया है।';

  @override
  String get roomCardUnblockButton => 'अनब्लॉक करें';

  @override
  String get attachmentMenuPhotoLabel => 'फोटो';

  @override
  String get attachmentMenuVideoLabel => 'वीडियो';

  @override
  String get attachmentMenuCameraLabel => 'कैमरा';

  @override
  String get attachmentMenuVoiceLabel => 'आवाज़';

  @override
  String get attachmentMenuFileLabel => 'फ़ाइल';

  @override
  String get attachmentMenuConnectionRetrying => 'फिर कोशिश हो रही है…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'सर्वर से कनेक्ट नहीं हो पा रहा · फिर कोशिश के लिए टैप करें';

  @override
  String get attachmentMenuConnectionReconnecting => 'फिर से कनेक्ट हो रहा है…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel => 'फिर से कनेक्ट करें';

  @override
  String get roomGridTileEmptyLastMessage => 'अभी तक शांत है';

  @override
  String get roomGridTileMemberCountLabel => 'अंदर';

  @override
  String get roomGridTileThemeChipLabel => 'थीम';

  @override
  String get bulkActionBarCancelLabel => 'रद्द करें';

  @override
  String get bulkActionBarSelectMessagesLabel => 'मैसेज चुनें';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count चुने गए';
  }

  @override
  String get bulkActionBarForwardLabel => 'फ़ॉरवर्ड करें';

  @override
  String get bulkActionBarDeleteLabel => 'डिलीट करें';

  @override
  String get bulkActionBarJumpBackLabel => 'वापस';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return 'वापस · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel =>
      'जहाँ से आए थे, वहीं वापस जाएं';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return 'जहाँ से आए थे, वहीं वापस जाएं, $depth बाकी';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote => 'उन्हें पता नहीं चलेगा।';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'अभी तुम दोनों दोस्त हो — ब्लॉक करने पर दोस्ती खत्म हो जाएगी, तो बाद में दोबारा जुड़ने के लिए नई फ्रेंड रिक्वेस्ट भेजनी होगी।';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'वो तुम्हारी सर्च में नहीं दिखेंगे और तुम्हें मैसेज नहीं कर पाएंगे।';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'ब्लॉक';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return '$name को ब्लॉक करना है?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'उनके साथ तुम्हारे $count रूम कॉमन हैं',
      one: 'उनके साथ तुम्हारा $count रूम कॉमन है',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'ये रूम वैसे ही बने रहेंगे। चाहो तो इनमें से किसी भी रूम को उसकी सेटिंग्स से खुद छोड़ सकते हो।';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'ब्लॉक करें';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'दोस्ती हटेगी और ब्लॉक होगा। मौजूदा चैट हिस्ट्री तुम्हारे आर्काइव में रहेगी।';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'वो सर्च में नहीं दिखेंगे और तुम तक नहीं पहुंच पाएंगे।';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'ब्लॉक करें और डीएम डिलीट करें';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'तुम्हारी उनके साथ की डीएम भी मिट जाएगी — हर मैसेज, रिएक्शन और मीडिया फाइल हमेशा के लिए गायब हो जाएगी।';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'रद्द करें';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'रद्द करें';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle =>
      'आने वाली कॉल्स लॉक स्क्रीन पर दिखें';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      'स्क्रीन बंद होने पर असली फोन कॉल की तरह बजने के लिए, MonkeyHub को \"फुल-स्क्रीन नोटिफिकेशन\" ऑन करना होगा। अगली स्क्रीन तुम्हें सीधे उस स्विच पर ले जाएगी।';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle =>
      'कभी कोई कॉल मिस मत करो';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      'बैटरी बचाने के लिए कुछ फोन बैकग्राउंड में ऐप्स को रोक देते हैं, जिससे आने वाली कॉल्स की आवाज़ बंद हो सकती है। MonkeyHub को बिना रोक-टोक चलने दो ताकि कॉल्स हमेशा आएं।';

  @override
  String get bulkActionBarDialogNotNowButton => 'अभी नहीं';

  @override
  String get bulkActionBarDialogContinueButton => 'जारी रखें';

  @override
  String get reactionBubbleJumpToLatestLabel => 'लेटेस्ट पर जाएं';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel => 'लेटेस्ट पर जाएं';

  @override
  String get reactionBubblePickerTitle => 'रिएक्ट करें';

  @override
  String get reactionBubbleNoRecentsPlaceholder =>
      'अभी तक कोई रीसेंट इमोजी नहीं';

  @override
  String get reactionBubbleSearchHint => 'इमोजी खोजो';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'कोई मैच नहीं';

  @override
  String get reactionBubbleSearchBackSemanticLabel => 'इमोजी पर वापस जाओ';

  @override
  String get reactionBubblePasswordHint => 'पासवर्ड';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return '$roomName जॉइन करना';
  }

  @override
  String get enterPublicRoomAskFailedMessage =>
      'अभी रिक्वेस्ट नहीं भेज पाए — फिर से कोशिश करो';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'गलत पासवर्ड';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'जॉइन नहीं हो सका — दोबारा कोशिश करें';

  @override
  String get feedBoardTitle => 'आज';

  @override
  String feedBoardEditionLabel(Object number) {
    return 'अंक $number';
  }

  @override
  String get feedBoardHighlightsLabel => 'ख़ास पल';

  @override
  String get feedBoardHighlightsEmpty => 'आज अभी तक कुछ नहीं';

  @override
  String get feedBoardPuzzleLabel => 'पहेली';

  @override
  String get feedBoardPuzzleEmpty => 'आज की पहेली अभी तैयार नहीं है';

  @override
  String get feedBoardStandingsLabel => 'ज़िंदगी अंक';

  @override
  String get feedBoardStandingsEmpty => 'आज बोर्ड पर कोई अंक नहीं';

  @override
  String get feedBoardActivityLabel => 'गतिविधि';

  @override
  String get feedBoardActivityEmpty => 'आज अभी तक शांति है';

  @override
  String get feedBoardActivityNoFriends =>
      'दोस्त जोड़ें और उनका दिन यहाँ दिखेगा';

  @override
  String get feedBoardLoadFailed =>
      'बोर्ड लोड नहीं हो सका — थोड़ी देर में फिर कोशिश करें';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'पब्लिक';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'प्राइवेट';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'जॉइन किया हुआ';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'अस्थायी · $duration';
  }

  @override
  String enterPublicRoomEphemeralSecondsShort(Object seconds) {
    return '$secondsसे';
  }

  @override
  String enterPublicRoomEphemeralMinutesShort(Object minutes) {
    return '$minutesमि';
  }

  @override
  String enterPublicRoomEphemeralHoursShort(Object hours) {
    return '$hoursघं';
  }

  @override
  String get roomBadgePublicTooltip =>
      'कोई भी इस रूम को ढूंढकर जॉइन कर सकता है';

  @override
  String get roomBadgePrivateTooltip =>
      'सिर्फ़ न्योते से — यह खोजो में नहीं दिखता';

  @override
  String get roomBadgeLockedTooltip => 'जॉइन करने के लिए रूम का पासवर्ड चाहिए';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return 'मैसेज $duration बाद गायब हो जाते हैं';
  }

  @override
  String get roomBadgeJoinedTooltip => 'तुम पहले से इस रूम में हो';

  @override
  String get roomInfoSheetDetailsLabel => 'डिटेल्स';

  @override
  String get roomInfoSheetNoDescription => 'अभी कोई डिस्क्रिप्शन नहीं';

  @override
  String get roomInfoSheetCreatedLabel => 'बनाया गया';

  @override
  String get countBadgeCaptureProtectionLabel => 'स्क्रीन कैप्चर सुरक्षा';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      'सिस्टम को स्क्रीनशॉट + स्क्रीन रिकॉर्डिंग में सब कुछ काला दिखता है।';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      'स्क्रीन रिकॉर्डिंग + मिररिंग करने पर ऐप पर एक प्राइवेसी शील्ड आ जाती है।';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      'अस्थायी रूम्स के बाहर स्क्रीनशॉट और रिकॉर्डिंग सामान्य रूप से काम करती हैं।';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      'अस्थायी (चैंबर ऑफ़ सीक्रेट्स) रूम्स में यह हमेशा जबरन ऑन रहता है।';

  @override
  String get countBadgeShowPasswordTooltip => 'पासवर्ड दिखाएं';

  @override
  String get countBadgeHidePasswordTooltip => 'पासवर्ड छुपाएं';

  @override
  String get countBadgeProtectedLabel => 'सुरक्षित';

  @override
  String get countBadgeCaptureShieldActiveBody =>
      'स्क्रीन रिकॉर्डिंग या मिररिंग चालू है।';

  @override
  String get countBadgeCaptureShieldReassurance =>
      'रिकॉर्डिंग में तुम्हारी बातचीत नहीं दिखती।';

  @override
  String get linkOpenerCouldNotOpenLink => 'लिंक नहीं खुल सका';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel => 'रिकवरी फ़्रेज़ सेट करें';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'कोई रिकवरी फ़्रेज़ नहीं — तुम वापस अंदर नहीं आ पाओगे।';

  @override
  String get destinationsChatLabel => 'चैट';

  @override
  String get destinationsChatShort => 'चैट';

  @override
  String get destinationsDiscoverLabel => 'खोजें';

  @override
  String get destinationsDiscoverShort => 'ढूंढें';

  @override
  String get destinationsFeedLabel => 'फ़ीड';

  @override
  String get destinationsFeedShort => 'फ़ीड';

  @override
  String get destinationsSettingsLabel => 'सेटिंग्स';

  @override
  String get destinationsSettingsShort => 'सेट';

  @override
  String get familyRequestStageSenderGuardianLabel => 'बड़े का इंतज़ार';

  @override
  String get familyRequestStageRecipientLabel => 'उनका इंतज़ार';

  @override
  String get roomContentTabLabelMedia => 'मीडिया';

  @override
  String get roomContentTabLabelFiles => 'फ़ाइलें';

  @override
  String get roomContentTabLabelVoice => 'वॉइस';

  @override
  String get roomContentTabLabelLinks => 'लिंक्स';

  @override
  String get roomContentTabLabelSaved => 'सेव किए गए';

  @override
  String get roomContentTabHeaderMedia => 'मीडिया';

  @override
  String get roomContentTabHeaderFiles => 'फ़ाइलें';

  @override
  String get roomContentTabHeaderVoice => 'वॉइस';

  @override
  String get roomContentTabHeaderLinks => 'लिंक्स';

  @override
  String get roomContentTabHeaderSaved => 'सेव किए गए';

  @override
  String get roomFacetLabelDms => 'डीएम';

  @override
  String get roomFacetLabelGroups => 'ग्रुप';

  @override
  String get roomFacetLabelPublic => 'सार्वजनिक';

  @override
  String get roomFacetLabelPrivate => 'निजी';

  @override
  String get roomFacetLabelSecret => 'गुप्त';

  @override
  String get roomFacetLabelLocked => 'लॉक';

  @override
  String get roomFacetLabelUnread => 'अपठित';

  @override
  String get roomFacetLabelMentions => 'मेंशन';

  @override
  String get settingsScreenTitle => 'सेटिंग्स';

  @override
  String get settingsScreenTagline => 'रूप. एहसास. तुम.';

  @override
  String get settingsScreenAccountHintChild =>
      'प्रोफ़ाइल · प्राइवेसी · मेरे बड़े';

  @override
  String get settingsScreenAccountHintAdult =>
      'प्रोफ़ाइल · परिवार · लिंक्ड अकाउंट्स · प्राइवेसी';

  @override
  String get settingsScreenSectionAppearance => 'दिखावट';

  @override
  String get settingsScreenSectionChat => 'चैट';

  @override
  String get settingsScreenSectionGeneral => 'सामान्य';

  @override
  String get settingsScreenCheckForUpdatesLabel => 'अपडेट के लिए जाँचें';

  @override
  String get settingsScreenUpdateAvailableValue => 'अपडेट उपलब्ध है';

  @override
  String get settingsScreenUpdateUpToDateSnackbar => 'आप नवीनतम वर्शन पर हैं।';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      'इस बिल्ड पर अपडेट नहीं जाँचे जा सकते।';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      'अपडेट जाँचे नहीं जा सके। बाद में फिर से कोशिश करें।';

  @override
  String get settingsScreenSectionNotifications => 'नोटिफिकेशन';

  @override
  String get reportProblemRowLabel => 'समस्या की रिपोर्ट करें';

  @override
  String get reportProblemRowValue => 'हमें विवरण भेजें';

  @override
  String get reportProblemIntro =>
      'बताइए क्या गड़बड़ हुई। आपके ऐप और डिवाइस की जानकारी अपने आप जुड़ जाती है, साथ में एक तकनीकी लॉग भी जिसमें ऐप उस समय क्या कर रहा था — इसी से कारण ढूँढ़ने में मदद मिलती है।';

  @override
  String get reportProblemDescribeLabel => 'क्या हुआ';

  @override
  String get reportProblemDescribeHint =>
      'स्क्रीन झिलमिलाती है, बटन काम नहीं करते…';

  @override
  String get reportProblemScreenshotsLabel => 'स्क्रीनशॉट';

  @override
  String get reportProblemAddScreenshot => 'स्क्रीनशॉट जोड़ें';

  @override
  String get reportProblemDetailsLabel => 'आपकी जानकारी';

  @override
  String get reportProblemCopyDetails => 'जानकारी कॉपी करें';

  @override
  String get reportProblemCopied => 'कॉपी हो गया';

  @override
  String get reportProblemSend => 'रिपोर्ट भेजें';

  @override
  String get reportProblemSent => 'रिपोर्ट भेज दी गई — धन्यवाद!';

  @override
  String get reportProblemSendFailed =>
      'रिपोर्ट नहीं भेजी जा सकी। अपना कनेक्शन जाँचकर दोबारा कोशिश करें।';

  @override
  String get reportProblemTooMany =>
      'आपने थोड़ी ही देर में बहुत सारी रिपोर्ट भेज दी हैं। कुछ देर बाद कोशिश करें।';

  @override
  String get reportProblemShakeTitle => 'समस्या की रिपोर्ट करें?';

  @override
  String get reportProblemShakeBody =>
      'आपने फ़ोन हिलाया। रिपोर्ट स्क्रीन खोलें?';

  @override
  String get reportProblemShakeOpen => 'रिपोर्ट करें';

  @override
  String get reportProblemShakeDismiss => 'अभी नहीं';

  @override
  String get settingsCallDeliveryLockScreenLabel => 'लॉक स्क्रीन कॉल';

  @override
  String get settingsCallDeliveryBackgroundLabel => 'बैकग्राउंड गतिविधि';

  @override
  String get settingsCallDeliveryStatusOff => 'अनुमति देने के लिए टैप करें';

  @override
  String get settingsScreenRowTheme => 'थीम';

  @override
  String get settingsScreenRowAppLogo => 'ऐप लोगो';

  @override
  String get settingsScreenRowGlass => 'काँच';

  @override
  String get settingsScreenRowChatList => 'चैट लिस्ट';

  @override
  String get settingsScreenRowNavigation => 'नेविगेशन';

  @override
  String get settingsScreenRowChatStyle => 'चैट स्टाइल';

  @override
  String get settingsScreenRowBubbleStyle => 'बबल स्टाइल';

  @override
  String get settingsScreenRowReplyStyle => 'रिप्लाई स्टाइल';

  @override
  String get settingsScreenValueScrollList => 'स्क्रॉल लिस्ट';

  @override
  String get settingsScreenValueGridSheet => 'ग्रिड शीट';

  @override
  String get settingsScreenValueRadialOrb => 'रेडियल गोला';

  @override
  String get settingsScreenValueBottomPill => 'निचला कैप्सूल';

  @override
  String get settingsScreenValueCustom => 'कस्टम';

  @override
  String settingsScreenValueEdited(Object name) {
    return '$name · संपादित';
  }

  @override
  String get settingsScreenValueClassic => 'क्लासिक';

  @override
  String get settingsScreenValueCompact => 'कॉम्पैक्ट';

  @override
  String get settingsScreenValueBubbleTailed => 'नोकदार';

  @override
  String get settingsScreenValueBubbleSoft => 'मुलायम';

  @override
  String get settingsScreenValueBubblePill => 'कैप्सूल';

  @override
  String get settingsScreenValueBubbleSlab => 'स्लैब';

  @override
  String get settingsScreenValueReplyPhantomEcho => 'फीकी गूंज';

  @override
  String get settingsScreenValueReplyStickyNote => 'स्टिकी नोट';

  @override
  String get settingsScreenValueReplyComicTail => 'कॉमिक नोक';

  @override
  String get settingsScreenValueLogoAuto => 'ऑटो';

  @override
  String get settingsScreenValueLogoManual => 'मैनुअल';

  @override
  String get settingsScreenShowLinkUrlsLabel => 'लिंक यूआरएल दिखाएं';

  @override
  String get settingsScreenLinksUrlsOnBody =>
      'प्रीव्यू कार्ड के साथ मूल यूआरएल भी दिखते हैं';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      'फिलहाल सिर्फ़ प्रीव्यू — साफ़-सुथरे बबल, खोलने के लिए टैप करें';

  @override
  String get settingsScreenSectionCalls => 'कॉल';

  @override
  String get settingsScreenRowVideoQuality => 'वीडियो क्वालिटी';

  @override
  String get settingsScreenValueVideoQualityAuto => 'ऑटो';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel => 'कॉल आँकड़े दिखाएं';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      'कॉल के दौरान लाइव रिज़ॉल्यूशन, बिटरेट, पिंग और पैकेट लॉस दिखाता है';

  @override
  String get videoQualityScreenTitle => 'वीडियो क्वालिटी';

  @override
  String get videoQualityScreenSubtitle =>
      'आउटगोइंग वीडियो के लिए एक रिज़ॉल्यूशन सीमा चुनें';

  @override
  String get videoQualityScreenAutoSubtitle =>
      'आपके कनेक्शन के हिसाब से अपने आप एडजस्ट हो जाता है';

  @override
  String get videoQualityScreenHd1080Subtitle =>
      'फुल एचडी — ज़्यादा शार्प, ज़्यादा डेटा इस्तेमाल करता है';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'अल्ट्रा एचडी — मज़बूत कनेक्शन पर सबसे अच्छा';

  @override
  String get videoQualityScreenFootnote =>
      'असली रिज़ॉल्यूशन दोनों डिवाइस के कैमरे और नेटवर्क की स्थिति पर निर्भर करता है।';

  @override
  String get callScreenControlOptions => 'अधिक';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => 'जिटर';

  @override
  String get callScreenStatsLossLabel => 'लॉस';

  @override
  String get callScreenSwapPreviewSemanticLabel => 'कैमरा दृश्य बदलें';

  @override
  String get callOptionsSheetTitle => 'कॉल विकल्प';

  @override
  String get settingsScreenPushNotificationsLabel => 'पुश नोटिफिकेशन';

  @override
  String get settingsScreenPushOnBody => 'नए मैसेज और रिक्वेस्ट के लिए पिंग';

  @override
  String get settingsScreenPushOffBody =>
      'साइलेंट — ऐप खोलने पर ही चीज़ें दिखेंगी';

  @override
  String get authErrorUsernameTaken => 'यह यूज़रनेम पहले से मौजूद है।';

  @override
  String get authErrorUsernameReserved =>
      'यह उपयोगकर्ता नाम उपलब्ध नहीं है। कोई दूसरा चुनें।';

  @override
  String get authErrorDisplayNameReserved =>
      'यह नाम उपलब्ध नहीं है। कोई दूसरा चुनें।';

  @override
  String get authErrorUserNotFound => 'इस यूज़रनेम से कोई अकाउंट नहीं मिला।';

  @override
  String get authErrorWrongPassword => 'गलत पासवर्ड।';

  @override
  String get authErrorInvalidRecoveryKey =>
      'यह यूज़रनेम और रिकवरी फ्रेज़ मेल नहीं खाते।';

  @override
  String get authErrorTooManyAttempts =>
      'बहुत ज़्यादा कोशिशें हो गईं। 15 मिनट रुककर फिर कोशिश करें।';

  @override
  String get authErrorChildMustPair =>
      'यह किसी बच्चे का अकाउंट है — पेयरिंग कोड के लिए किसी बड़े से मांगें।';

  @override
  String get authErrorPairingCodeExpired =>
      'यह कोड ख़त्म हो चुका है। नया कोड मांगें।';

  @override
  String get authErrorPairingCodeInvalid =>
      'यह कोड काम नहीं आया। हो सकता है यह पहले ही इस्तेमाल हो चुका हो।';

  @override
  String get authErrorUseSocialSignIn =>
      'यह अकाउंट Apple या Google से साइन इन करता है — नीचे दिए बटन इस्तेमाल करें।';

  @override
  String get authErrorSocialTokenInvalid =>
      'यह साइन-इन पूरा नहीं हो पाया। कृपया फिर कोशिश करें।';

  @override
  String get authErrorSocialNonceMismatch =>
      'यह साइन-इन नहीं हो पाया। कृपया फिर से कोशिश करो।';

  @override
  String get authErrorSocialMisconfig =>
      'साइन-इन अभी हमारी तरफ़ से सेट नहीं है। थोड़ी देर बाद कोशिश करो।';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      'वह Apple या Google अकाउंट पहले से किसी दूसरे MonkeyHub अकाउंट से लिंक है।';

  @override
  String get authErrorSocialAlreadyLinked => 'वह पहले से इस अकाउंट से लिंक है।';

  @override
  String get authErrorSocialNotLinked => 'वह इस अकाउंट से लिंक नहीं है।';

  @override
  String get authErrorSocialLastCredential =>
      'इस अकाउंट में जाने का यही इकलौता रास्ता है। पहले एक पासवर्ड सेट करो।';

  @override
  String get authErrorUsernameInvalid =>
      '1 से 32 अक्षरों के बीच यूज़रनेम चुनो।';

  @override
  String get authErrorUsernameChangedRecently =>
      'आपने हाल ही में अपना यूज़रनेम बदला है। पिछली बार के 30 दिन बाद आप इसे दोबारा बदल सकते हैं।';

  @override
  String get authErrorInboxHandleLocked =>
      'यह अकाउंट सभी की समस्या रिपोर्ट पाता है, इसलिए इसका यूज़रनेम तय है।';

  @override
  String get glassKnobLabelFrost => 'धुंधला';

  @override
  String get glassKnobHintFrost =>
      'काँच पर कितनी सफ़ेदी है, कम करने पर आर-पार दिखता है';

  @override
  String get glassKnobLabelBlur => 'ब्लर';

  @override
  String get glassKnobHintBlur =>
      'ऊपर की तरफ़ धुंधला काँच, नीचे की तरफ़ साफ़ काँच';

  @override
  String get glassKnobLabelSaturation => 'रंग फैलाव';

  @override
  String get glassKnobHintSaturation =>
      'ब्लर के बाद कितना रंग बचता है। 2 से ज़्यादा पर पोस्टराइज़ हो जाता है';

  @override
  String get glassKnobLabelRimOpacity => 'किनारा';

  @override
  String get glassKnobHintRimOpacity =>
      'किनारे की हाइलाइट रेखा। शून्य पर बॉर्डर-रहित सतह';

  @override
  String get glassKnobLabelRimWidth => 'किनारे की चौड़ाई';

  @override
  String get glassKnobHintRimWidth => 'उस रेखा की मोटाई';

  @override
  String get glassKnobLabelShadowOpacity => 'छाया';

  @override
  String get glassKnobHintShadowOpacity =>
      'सतह पीछे की चीज़ से कितनी ऊपर उठी हुई दिखती है';

  @override
  String get glassKnobLabelShadowBlur => 'छाया फैलाव';

  @override
  String get glassKnobHintShadowBlur => 'नरम और चौड़ी, या सिमटी और तीखी';

  @override
  String get glassKnobLabelShadowY => 'छाया गिरावट';

  @override
  String get glassKnobHintShadowY => 'यह सतह से कितनी नीचे गिरती है';

  @override
  String get glassKnobLabelBarMargin => 'साइड मार्जिन';

  @override
  String get glassKnobHintBarMargin =>
      'बार और स्क्रीन के किनारे के बीच की दूरी';

  @override
  String get glassKnobLabelBarBottom => 'निचली दूरी';

  @override
  String get glassKnobHintBarBottom => 'बार नीचे से कितना ऊपर तैरता है';

  @override
  String get glassKnobLabelShellPadH => 'एंड पैडिंग';

  @override
  String get glassKnobHintShellPadH =>
      'बार के किनारे से पहले कैप्सूल तक की दूरी। कम रखने पर सिरे अलग-थलग से लगते हैं';

  @override
  String get glassKnobLabelShellPadV => 'टॉप पैडिंग';

  @override
  String get glassKnobHintShellPadV =>
      'बार के किनारे से कैप्सूल के ऊपरी हिस्से तक की दूरी';

  @override
  String get glassKnobLabelIndicatorInset => 'कैप्सूल इनसेट';

  @override
  String get glassKnobHintIndicatorInset =>
      'चुना हुआ कैप्सूल अपने स्लॉट के अंदर कितनी दूर बैठता है';

  @override
  String get glassKnobLabelSegmentPadV => 'पंक्ति पैडिंग';

  @override
  String get glassKnobHintSegmentPadV =>
      'आइकॉन और उसके लेबल के ऊपर-नीचे कितनी खाली जगह है';

  @override
  String get glassKnobLabelIconLabelGap => 'आइकन दूरी';

  @override
  String get glassKnobHintIconLabelGap =>
      'आइकन और उसके नीचे लिखे शब्द के बीच की दूरी';

  @override
  String get glassKnobLabelIconSize => 'आइकन साइज़';

  @override
  String get glassKnobLabelLabelSize => 'लेबल साइज़';

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
  String get settingsScreenRowMotion => 'मोशन';

  @override
  String get settingsScreenValueMotionFull => 'पूरा';

  @override
  String get settingsScreenValueMotionCalm => 'शांत';

  @override
  String get settingsScreenValueMotionSystemFull => 'डिवाइस जैसा · पूरा';

  @override
  String get settingsScreenValueMotionSystemCalm => 'डिवाइस जैसा · शांत';

  @override
  String get motionScreenTitle => 'मोशन.';

  @override
  String get motionScreenSubtitle => 'ऐप कितना हिले';

  @override
  String get motionScreenSystemLabel => 'डिवाइस जैसा';

  @override
  String get motionScreenSystemSubtitleFull =>
      'आपका डिवाइस अभी एनिमेशन की अनुमति देता है';

  @override
  String get motionScreenSystemSubtitleCalm =>
      'आपका डिवाइस अभी कम मोशन माँगता है';

  @override
  String get motionScreenFullLabel => 'पूरा';

  @override
  String get motionScreenFullSubtitle => 'हर बहाव, चमक और सजावट';

  @override
  String get motionScreenCalmLabel => 'शांत';

  @override
  String get motionScreenCalmSubtitle =>
      'सजावट रुक जाती है — और कुछ नहीं बदलता';

  @override
  String get momentRailCaptureLabel => 'कैप्चर';

  @override
  String get momentRailYouLabel => 'आप';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String get momentTagFate => 'संयोग';

  @override
  String get momentTagJinx => 'अपनी करनी';

  @override
  String get momentTagLuck => 'किस्मत';

  @override
  String get momentTagCalledIt => 'मैंने कहा था';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'क्या संयोग है';

  @override
  String get momentTagJinxHint => 'अपने ही पैर पर कुल्हाड़ी';

  @override
  String get momentTagLuckHint => 'बात बन गई';

  @override
  String get momentTagCalledItHint => 'आपने पहले ही भाँप लिया';

  @override
  String get momentTagNpcHint => 'दिमाग़ पूरी तरह बंद';

  @override
  String get momentComposerTitle => 'क्या हुआ?';

  @override
  String get momentComposerCaptionHint => 'कुछ लिखिए';

  @override
  String get momentComposerTagPrompt => 'अंक मिला? अभी जोड़ें';

  @override
  String get momentComposerCapture => 'कैमरा';

  @override
  String get momentComposerLibrary => 'गैलरी';

  @override
  String get momentComposerRemovePhoto => 'फ़ोटो हटाएँ';

  @override
  String get momentComposerPost => 'पोस्ट करें';

  @override
  String get momentComposerErrorDailyCap => 'आज पाँच हो गए — कल के लिए भी रखिए';

  @override
  String get momentComposerErrorNotAllowed =>
      'अभिभावक ने फ़ोटो साझा करना बंद कर रखा है';

  @override
  String get momentComposerErrorTooLong => 'थोड़ा लंबा है — छोटा कीजिए';

  @override
  String get momentComposerErrorEmpty => 'एक फ़ोटो या कुछ शब्द जोड़िए';

  @override
  String get momentComposerErrorGeneric =>
      'पोस्ट नहीं हो सका — फिर कोशिश कीजिए';

  @override
  String get momentViewerDelete => 'हटाएँ';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who ने एक पल साझा किया';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name को एक $tag मिला';
  }

  @override
  String get momentActivityJustNow => 'अभी';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '$countमि';
  }

  @override
  String momentActivityHoursAgo(Object count) {
    return '$countघं';
  }

  @override
  String momentActivityMoreCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आज $count और',
      one: 'आज 1 और',
    );
    return '$_temp0';
  }

  @override
  String get puzzleScreenTitle => 'पहेली।';

  @override
  String get puzzleScreenSubtitle => 'चार चिह्न, छह मौके';

  @override
  String get puzzleSubmit => 'अनुमान';

  @override
  String get puzzleBackspace => 'आख़िरी चिह्न मिटाएँ';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'चिह्न $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return '$count में हल';
  }

  @override
  String get puzzleFailedTitle => 'मौके ख़त्म';

  @override
  String get puzzleAnswerWas => 'कोड यह था';

  @override
  String get puzzleShare => 'परिणाम कॉपी करें';

  @override
  String get puzzleShareCopied => 'कॉपी हो गया — दोस्त को भेजें';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'आज की पहेली आप हल कर चुके हैं';

  @override
  String get puzzleErrorOutOfGuesses => 'आज कोई मौका नहीं बचा';

  @override
  String get puzzleErrorGeneric => 'भेजा नहीं जा सका — फिर कोशिश करें';

  @override
  String get puzzleScoreboardLabel => 'आज के स्कोर';

  @override
  String get puzzleScoreboardEmpty => 'आज अभी किसी ने पूरी नहीं की';

  @override
  String get puzzleTilePlay => 'आज की पहेली खेलें';

  @override
  String puzzleTileInProgress(Object count) {
    return '$count बचे';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '$total में #$rank';
  }

  @override
  String get profileVisibilityScreenSectionFeed => 'फ़ीड';

  @override
  String get profileVisibilityScreenFeedLabel => 'मेरे ख़ास पल';

  @override
  String get profileVisibilityScreenFeedDesc =>
      'आपकी साझा की गई फ़ोटो और वीडियो उस दिन दोस्तों के बोर्ड पर दिखें या नहीं';

  @override
  String get profileVisibilityScreenPuzzleLabel => 'मेरा पहेली स्कोर';

  @override
  String get profileVisibilityScreenPuzzleDesc =>
      'दोस्त देख सकें कि रोज़ की पहेली में आपने कैसा किया';

  @override
  String get profileVisibilityScreenPointsPastLabel => 'मेरा अतीत';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      'आज हमेशा दोस्तों के साथ साझा होता है — यह उससे पहले का सब कुछ खोलता है';

  @override
  String get momentComposerVideo => 'वीडियो';

  @override
  String get momentComposerErrorTooBig =>
      'यह वीडियो बहुत बड़ा है — अधिकतम 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => 'आपने एक पल साझा किया';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'आपको एक $tag मिला';
  }

  @override
  String pointLineSelf(Object tag) {
    return 'आप · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'क्या हुआ?';

  @override
  String get pointComposerNoteHint => 'ऊपर से एक चुनें, फिर बताएँ';

  @override
  String get pointComposerAdd => 'अंक जोड़ें';

  @override
  String get pointComposerAddPhoto => 'फ़ोटो जोड़ें';

  @override
  String get pointsBoardAdd => 'एक अंक जोड़ें';

  @override
  String get pointsExplainerOpen => 'यह क्या है?';

  @override
  String get pointsExplainerTitle => 'अंकों का खेल';

  @override
  String get pointsExplainerIntro =>
      'एक चलता हुआ मज़ाक, जिसका हिसाब रखा जाता है। जब आपके साथ कुछ होता है — अच्छा, बुरा या बस अजीब — आप उसे दर्ज करते हैं और वह उस दिन बोर्ड पर रहता है।';

  @override
  String get pointsExplainerRuleHonour =>
      'अंक आप ख़ुद देते हैं। कोई जाँच नहीं करता — मज़ा यही है, और हद से बढ़े तो दोस्त बता ही देंगे।';

  @override
  String get pointsExplainerRuleToday =>
      'अंक हर दिन शून्य हो जाते हैं। बोर्ड आज दिखाता है; आपका अपना इतिहास आपके पास रहता है।';

  @override
  String get pointsExplainerRuleCap =>
      'एक ही तरह के दिन में पाँच, ताकि कोई बोर्ड को बेमानी न बना दे।';

  @override
  String get pointsExplainerGotIt => 'समझ गया';

  @override
  String get momentTagFateExample =>
      'दूसरे देश में अपने दंत-चिकित्सक से टकरा गया';

  @override
  String get momentTagJinxExample => 'गाड़ी धोई, चार बजे बारिश हो गई';

  @override
  String get momentTagLuckExample => 'दो सेकंड से ट्रेन पकड़ ली';

  @override
  String get momentTagCalledItExample => 'कहा था सीक्वल पिटेगी, पिट गई';

  @override
  String get momentTagNpcExample => 'वेटर से ‘आप भी’ कह दिया';

  @override
  String feedBoardEditionHint(Object number) {
    return 'फ़ीड का दिन $number';
  }

  @override
  String get feedBoardHighlightsHint => 'देखने लायक फ़ोटो और वीडियो';

  @override
  String get profileVisibilityScreenPointsLabel => 'मेरे अंक';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'आपके दर्ज किए अंक दोस्तों के बोर्ड पर दिखें या नहीं';

  @override
  String get momentComposerEditPhoto => 'क्रॉप बदलें';

  @override
  String get archiveScreenTitle => 'आपका संग्रह';

  @override
  String get archiveScreenEnd => 'बस इतना ही';

  @override
  String get archiveScreenEmptyTitle => 'अभी कुछ सहेजा नहीं';

  @override
  String get archiveScreenEmptyBody =>
      'पल एक दिन बाद दोस्तों के बोर्ड से चले जाते हैं, पर यहाँ आपके लिए बने रहते हैं।';

  @override
  String get archiveScreenEmptyFriendTitle => 'यहाँ कुछ नहीं';

  @override
  String get archiveScreenEmptyFriendBody =>
      'अभी ऐसा कुछ साझा नहीं किया जो आप देख सकें।';

  @override
  String get archiveScreenPrivateTitle => 'इनका अतीत निजी है';

  @override
  String get archiveScreenPrivateBody => 'आज जो साझा करेंगे वह फिर भी दिखेगा।';

  @override
  String get archiveScreenNotFriendTitle => 'आप दोस्त नहीं हैं';

  @override
  String get archiveScreenNotFriendBody =>
      'आप केवल किसी दोस्त के दिन पीछे देख सकते हैं।';

  @override
  String get archiveScreenErrorTitle => 'लोड नहीं हो सका';

  @override
  String get archiveScreenErrorBody => 'कनेक्शन जाँचकर फिर कोशिश करें।';

  @override
  String get feedBoardOpenArchive => 'संग्रह';

  @override
  String get feedBoardGamesLabel => 'खेल';

  @override
  String get feedBoardGamesOpen => 'सभी खेल';

  @override
  String get gamesScreenTitle => 'खेल।';

  @override
  String get gamesScreenSubtitle => 'हर दिन चार बोर्ड, सबके लिए एक जैसे';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आज $count बाकी',
      one: 'आज एक बाकी',
      zero: 'आज सब पूरे',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => 'आज के खेल लोड नहीं हो सके';

  @override
  String get gamesRetry => 'फिर कोशिश करें';

  @override
  String get gameQueensName => 'क्वीन्स';

  @override
  String get gameQueensRule =>
      'हर पंक्ति, स्तंभ और रंग में एक ताज — कभी छूते नहीं';

  @override
  String get gameTangoName => 'टैंगो';

  @override
  String get gameTangoRule => 'तीन सूरज, तीन चाँद, कभी लगातार तीन नहीं';

  @override
  String get gameZipName => 'ज़िप';

  @override
  String get gameZipRule => 'हर खाने से गुज़रती एक रेखा, संख्याएँ क्रम में';

  @override
  String get gameSudokuName => 'मिनी सुडोकु';

  @override
  String get gameSudokuRule => 'हर पंक्ति, स्तंभ और बॉक्स में 1 से 6 एक-एक बार';

  @override
  String get gameCodeName => 'कोड';

  @override
  String get gameStatusUnplayed => 'नहीं खेला';

  @override
  String get gameStatusUnfinished => 'जारी';

  @override
  String get gameStatusGaveUp => 'छोड़ा';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'रोकें';

  @override
  String get gameResume => 'जारी रखें';

  @override
  String get gamePausedTitle => 'रुका हुआ';

  @override
  String get gamePausedBody => 'घड़ी रुकी है और बोर्ड छिपा है';

  @override
  String get gameUndo => 'पूर्ववत';

  @override
  String get gameClear => 'साफ़ करें';

  @override
  String get gameHint => 'संकेत';

  @override
  String get gameNotes => 'नोट्स';

  @override
  String get gameErase => 'मिटाएँ';

  @override
  String get gameAutoCross => 'स्वतः क्रॉस';

  @override
  String get gameGiveUp => 'हार मानें';

  @override
  String get gameGiveUpTitle => 'जवाब दिखाएँ?';

  @override
  String get gameGiveUpBody => 'आज का बोर्ड बंद हो जाएगा और अनसुलझा दर्ज होगा।';

  @override
  String get gameGiveUpCancel => 'कोशिश जारी';

  @override
  String get gameGiveUpConfirm => 'दिखाएँ';

  @override
  String gameSolvedTitle(Object time) {
    return '$time में हल';
  }

  @override
  String get gameGaveUpTitle => 'आज का जवाब';

  @override
  String get gameFirstInToday => 'आज सबसे पहले';

  @override
  String gameRankLine(Object place, Object total) {
    return 'अब तक $total में से $place';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count गलतियाँ',
      one: '1 गलती',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count संकेत',
      one: '1 संकेत',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => 'आज के समय';

  @override
  String get gameStandingsEmpty => 'अभी किसी ने पूरा नहीं किया';

  @override
  String get gameShare => 'परिणाम कॉपी करें';

  @override
  String get gameShareCopied => 'कॉपी हुआ — किसी दोस्त को भेजें';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => 'सभी खेल';

  @override
  String get gameElapsedSemantic => 'बीता समय';

  @override
  String get gameErrorNotSolved => 'यह बोर्ड अभी पूरा नहीं हुआ';

  @override
  String get gameErrorAlreadyFinished => 'आज का पहले ही पूरा कर चुके';

  @override
  String get gameErrorNoHint => 'इसके लिए कोई संकेत नहीं';

  @override
  String get gameErrorGeneric => 'खेलों तक नहीं पहुँच सके — फिर कोशिश करें';

  @override
  String get gameInfoOpen => 'कैसे खेलें';

  @override
  String get gameInfoLabel => 'कैसे खेलें';

  @override
  String get gameInfoRulesLabel => 'नियम';

  @override
  String get gameInfoControlsLabel => 'नियंत्रण';

  @override
  String get gameInfoScoringTimed =>
      'जब तक बोर्ड स्क्रीन पर है घड़ी चलती है; रोकने या बाहर जाने पर रुक जाती है। सबसे तेज़ आज की सूची में सबसे ऊपर।';

  @override
  String get gameInfoScoringGuesses =>
      'स्कोर कम अनुमानों से बनता है, घड़ी से नहीं।';

  @override
  String get gameInfoSameForEveryone => 'आज सबको एक ही बोर्ड मिलता है।';

  @override
  String get gameInfoGotIt => 'समझ गए';

  @override
  String get gameInfoQueensGoal => 'हर पंक्ति, स्तंभ और रंग में एक ताज रखें।';

  @override
  String get gameInfoQueensRule1 =>
      'आठ ताज: हर पंक्ति में एक, हर स्तंभ में एक।';

  @override
  String get gameInfoQueensRule2 => 'हर रंग-खंड में भी ठीक एक ताज होता है।';

  @override
  String get gameInfoQueensRule3 =>
      'कोई दो ताज नहीं छू सकते — कोने से भी नहीं।';

  @override
  String get gameInfoQueensControls =>
      'किसी खाने पर एक बार टैप करें तो क्रॉस, दोबारा टैप करें तो ताज, फिर से टैप करें तो खाली।';

  @override
  String get gameInfoTangoGoal => 'ग्रिड को सूरज और चाँद से भरें।';

  @override
  String get gameInfoTangoRule1 =>
      'हर पंक्ति और स्तंभ में तीन सूरज और तीन चाँद होते हैं।';

  @override
  String get gameInfoTangoRule2 =>
      'कभी भी तीन एक जैसे साथ-साथ नहीं, न आड़े न खड़े।';

  @override
  String get gameInfoTangoRule3 =>
      'दो खानों के बीच = का मतलब वे एक जैसे हैं, × का मतलब अलग हैं।';

  @override
  String get gameInfoTangoControls =>
      'खाने पर टैप करें तो सूरज, दोबारा चाँद, फिर खाली। छपे हुए खाने नहीं बदलते।';

  @override
  String get gameInfoZipGoal => 'एक ऐसी रेखा खींचें जो हर खाने से गुज़रे।';

  @override
  String get gameInfoZipRule1 => '1 से शुरू करें और आखिरी संख्या पर खत्म करें।';

  @override
  String get gameInfoZipRule2 => 'रास्ते में संख्याओं को क्रम से छुएँ।';

  @override
  String get gameInfoZipRule3 => 'हर खाना ठीक एक बार इस्तेमाल होता है।';

  @override
  String get gameInfoZipControls =>
      'उँगली घसीटकर खींचें। रेखा पर वापस घसीटें तो मिट जाएगी।';

  @override
  String get gameInfoSudokuGoal => 'ग्रिड को 1 से 6 अंकों से भरें।';

  @override
  String get gameInfoSudokuRule1 => 'हर पंक्ति में 1 से 6 तक एक-एक बार।';

  @override
  String get gameInfoSudokuRule2 => 'हर स्तंभ में भी वैसा ही।';

  @override
  String get gameInfoSudokuRule3 => 'और हर 2x3 बॉक्स में भी।';

  @override
  String get gameInfoSudokuControls =>
      'खाने पर टैप करें, फिर अंक पर। वही अंक दोबारा टैप करें तो मिट जाएगा। नोट्स मोड में छोटे पेंसिल निशान लगते हैं।';

  @override
  String get gameInfoCodeGoal => 'चार-चिह्न वाले छिपे कोड का पता लगाएँ।';

  @override
  String get gameInfoCodeRule1 =>
      'छह कोशिशें, और कोड में कोई चिह्न दोहराया नहीं जाता।';

  @override
  String get gameInfoCodeRule2 => 'हरा मतलब सही चिह्न, सही जगह।';

  @override
  String get gameInfoCodeRule3 => 'पीला मतलब सही चिह्न, गलत जगह।';

  @override
  String get gameInfoCodeControls =>
      'अनुमान बनाने के लिए चिह्नों पर टैप करें, फिर भेजें। बोर्ड बताएगा कि आप कितने करीब थे।';

  @override
  String get savedMessagesTitle => 'सेव किए गए मैसेज';

  @override
  String homeScreenNoSearchResults(Object query) {
    return '\"$query\" से कोई चैट मेल नहीं खाती';
  }

  @override
  String get pullRevealSearchHint => 'चैट खोजो…';

  @override
  String get pullRevealCollapseSemanticLabel =>
      'सर्च और आर्काइव की गई चैट छिपाएं';

  @override
  String archivedChatsFolderLabel(Object count) {
    return 'आर्काइव की गई चैट ($count)';
  }

  @override
  String get archivedChatsFolderTitle => 'आर्काइव की गई चैट';

  @override
  String get pullRevealClearSearchSemanticLabel => 'सर्च साफ़ करें';

  @override
  String get archivedChatsSheetTitle => 'आर्काइव की गई चैट';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'आर्काइव की गई चैट · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'अब कुछ भी आर्काइव नहीं है';

  @override
  String get pinnedBadgeLabel => 'पिन';

  @override
  String get chatRowActionMenuPinLabel => 'चैट पिन करें';

  @override
  String get chatRowActionMenuUnpinLabel => 'चैट अनपिन करें';

  @override
  String get chatRowActionMenuArchiveLabel => 'चैट आर्काइव करें';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'चैट अनआर्काइव करें';

  @override
  String get messageActionMenuSaveLabel => 'सेव करें';

  @override
  String get messageActionMenuUnsaveLabel => 'सेव हटाएँ';

  @override
  String get roomScreenSaveLimitSnack =>
      'यहाँ बहुत सारे सेव हैं — पहले एक हटाओ';

  @override
  String get roomScreenSaveFailedSnack => 'उसे सेव नहीं किया जा सका';

  @override
  String get threadOverlaySaveLimitToast =>
      'यहाँ बहुत सारे सेव हैं — पहले एक हटाओ';

  @override
  String get threadOverlaySaveFailedToast => 'उसे सेव नहीं किया जा सका';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'आपके सेव किए मैसेज सिर्फ़ आपको दिखते हैं — पिन किया गया मैसेज इसका उल्टा है: उसे पूरा रूम देखता है.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return '$name के सेव किए गए मैसेज पर जाना';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return '$name के मैसेज से सेव हटाना';
  }

  @override
  String get muteSheetTitle => 'चैट म्यूट करें';

  @override
  String get muteSheetSubtitle => 'चुनें कि क्या शांत रहेगा और कितनी देर तक।';

  @override
  String get muteSheetNotificationsTitle => 'सूचनाएँ';

  @override
  String get muteSheetNotificationsSub => 'कोई बैनर नहीं, कोई आवाज़ नहीं';

  @override
  String get muteSheetBadgesTitle => 'बिना पढ़े संदेशों की गिनती';

  @override
  String get muteSheetBadgesSub =>
      'चैट पर कोई संख्या नहीं, ऐप आइकॉन में कुछ नहीं जुड़ेगा';

  @override
  String get muteSheetDurationLabel => 'कितनी देर के लिए';

  @override
  String get muteDurationHour => '1 घंटा';

  @override
  String get muteDurationEightHours => '8 घंटे';

  @override
  String get muteDurationWeek => '1 सप्ताह';

  @override
  String get muteDurationAlways => 'हमेशा';

  @override
  String get muteSheetConfirmButton => 'म्यूट करें';

  @override
  String get muteSheetSaveButton => 'सहेजें';

  @override
  String get muteSheetUnmuteButton => 'अनम्यूट करें';

  @override
  String get muteSummaryAll =>
      'इस चैट से आप तक कुछ नहीं पहुँचेगा — न सूचनाएँ, न बिना पढ़े संदेशों की गिनती।';

  @override
  String get muteSummaryNotificationsOnly =>
      'कोई सूचना नहीं। बिना पढ़े संदेशों की गिनती बढ़ती रहेगी।';

  @override
  String get muteSummaryBadgesOnly =>
      'बिना पढ़े संदेशों की गिनती नहीं। सूचनाएँ आती रहेंगी।';

  @override
  String get muteSummaryNothingPicked =>
      'शांत करने के लिए कम से कम एक चीज़ चुनें।';

  @override
  String muteUntilSentence(String when) {
    return '$when तक।';
  }

  @override
  String get muteUntilAlwaysSentence => 'जब तक आप इसे फिर से चालू न करें।';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String get mutedBadgeLabel => 'म्यूट';

  @override
  String get chatRowActionMenuMuteLabel => 'चैट म्यूट करें';

  @override
  String get chatRowActionMenuUnmuteLabel => 'चैट अनम्यूट करें';

  @override
  String get roomInfoScreenMuteLabel => 'म्यूट';

  @override
  String get roomInfoScreenNotMutedRow => 'म्यूट नहीं है';

  @override
  String get attachmentMenuLocationLabel => 'स्थान';

  @override
  String get locationSheetSendCurrent => 'मौजूदा स्थान भेजें';

  @override
  String get locationSheetSendCurrentDetail => 'आप अभी कहाँ हैं';

  @override
  String get locationSheetLiveHeading => 'लाइव साझा करें';

  @override
  String get locationSheetLiveDetail => 'अपने आप बंद हो जाता है';

  @override
  String get locationShareFor15Minutes => '15 मिनट के लिए';

  @override
  String get locationShareFor1Hour => '1 घंटे के लिए';

  @override
  String get locationShareFor8Hours => '8 घंटे के लिए';

  @override
  String get locationBubbleOpenInMaps => 'मैप्स में खोलें';

  @override
  String get locationBubbleLiveBadge => 'लाइव';

  @override
  String get locationBubbleEndedBadge => 'समाप्त';

  @override
  String locationBubbleLiveUntil(String time) {
    return '$time तक लाइव';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return 'लाइव स्थान $time पर समाप्त हुआ';
  }

  @override
  String get locationBubbleNoRecentUpdate => 'कोई हालिया अपडेट नहीं';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters मी';
  }

  @override
  String get locationBubbleStopSharing => 'साझा करना बंद करें';

  @override
  String get locationBubbleUnavailable => 'स्थान उपलब्ध नहीं';

  @override
  String get locationBubbleNoMapsApp => 'इसे खोलने के लिए कोई मैप ऐप नहीं है';

  @override
  String get locationBubbleCoordinatesCopied => 'निर्देशांक कॉपी किए गए';

  @override
  String get locationCouldNotGetFix => 'आपका स्थान नहीं मिल सका';

  @override
  String get locationCouldNotStartLiveShare =>
      'लाइव साझा करना शुरू नहीं हो सका';

  @override
  String get locationPermissionNeeded =>
      'आप कहाँ हैं यह साझा करने के लिए स्थान की अनुमति चाहिए';

  @override
  String get locationPermissionBlockedTitle => 'स्थान की अनुमति बंद है';

  @override
  String get locationPermissionBlockedBody =>
      'MonkeyHub यहाँ से दोबारा नहीं पूछ सकता। सेटिंग्स में MonkeyHub के लिए स्थान की अनुमति चालू करें।';

  @override
  String get locationServicesOffTitle => 'स्थान सेवाएँ बंद हैं';

  @override
  String get locationServicesOffBody =>
      'इस डिवाइस पर स्थान बंद है। आप कहाँ हैं यह साझा करने के लिए सेटिंग्स में इसे चालू करें।';

  @override
  String get locationOpenSettings => 'सेटिंग्स खोलें';

  @override
  String get locationBackgroundSheetTitle => 'अगर आपका फ़ोन रीस्टार्ट हो जाए';

  @override
  String get locationBackgroundSheetBody =>
      'MonkeyHub से बाहर निकलने पर भी आपकी लाइव शेयरिंग चलती रहती है। बैकग्राउंड एक्सेस बाकी सब संभालता है: रीस्टार्ट, ऐप का ज़बरदस्ती बंद होना, या बैटरी खत्म होकर फ़ोन का वापस आना।';

  @override
  String get locationBackgroundSheetKeepRunning => 'अपने आप फिर शुरू करें';

  @override
  String get locationBackgroundSheetKeepRunningDetail =>
      'आपका फ़ोन इसकी अनुमति मांगेगा';

  @override
  String get locationBackgroundSheetAppOnly => 'बंद ही रहने दें';

  @override
  String get locationBackgroundSheetAppOnlyDetail => 'और कुछ अनुमति नहीं देनी';

  @override
  String get locationServiceNotificationTitle =>
      'आपकी लाइव लोकेशन शेयर हो रही है';

  @override
  String get locationServiceNotificationBody =>
      'चैट खोलने के लिए टैप करें, या अभी बंद करने के लिए रोकें दबाएँ';

  @override
  String get childPolicyScreenLocationLabel => 'स्थान';

  @override
  String get childPolicyScreenLocationOnDesc =>
      'अपना स्थान साझा कर सकते हैं, 8 घंटे तक लाइव भी';

  @override
  String get childPolicyScreenLocationOffDesc => 'अपना स्थान साझा नहीं कर सकते';

  @override
  String get roomInfoScreenSavedMessagesLabel => 'सेव किए गए मैसेज';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      'इन्हें सिर्फ तुम देख सकते हो, और सिर्फ इसी रूम से। तुम्हारी सेव किए गए मैसेज चैट अलग है।';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      'अभी कुछ सेव नहीं हुआ। किसी मैसेज को दबाए रखो और सेव करें चुनो।';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return '$name के सेव किए गए मैसेज पर जाना';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return '$name के मैसेज से सेव हटाना';
  }

  @override
  String get composerCaptureCameraModeLabel => 'कैमरा';

  @override
  String get composerCaptureVoiceModeLabel => 'वॉइस मैसेज';

  @override
  String get composerCaptureVideoNoteModeLabel => 'वीडियो नोट';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode. मोड बदलने के लिए दो उंगलियों से स्वाइप करें या ऐरो कीज़ का उपयोग करें।';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '$mode चुना गया';
  }

  @override
  String get composerCaptureRecordingAnnouncement => 'रिकॉर्डिंग शुरू';

  @override
  String get composerCaptureLockedAnnouncement =>
      'रिकॉर्डिंग लॉक हो गई। हाथ मुक्त।';

  @override
  String get composerCaptureCancelledAnnouncement => 'रिकॉर्डिंग हटा दी गई';

  @override
  String get composerCaptureSentAnnouncement => 'रिकॉर्डिंग भेजी गई';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return 'रिकॉर्डिंग, $elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint =>
      'रिकॉर्ड करने के लिए दबाकर रखें, बदलने के लिए स्वाइप करें';

  @override
  String get composerCaptureTapForCameraHint =>
      'कैमरा के लिए टैप करें, बदलने के लिए स्वाइप करें';

  @override
  String get composerCaptureSlideToCancelHint => 'रद्द करने के लिए स्लाइड करें';

  @override
  String get composerCaptureReleaseToCancelHint => 'रद्द करने के लिए छोड़ें';

  @override
  String get composerCaptureTapToSendHint => 'भेजने के लिए टैप करें';

  @override
  String get composerCaptureSendingLabel => 'भेजा जा रहा है…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return '$seconds सेकंड बाकी';
  }

  @override
  String get composerCaptureCancelLabel => 'रिकॉर्डिंग हटाएँ';

  @override
  String get composerCaptureSendLabel => 'रिकॉर्डिंग भेजें';

  @override
  String get composerCaptureLockLabel =>
      'रिकॉर्डिंग लॉक करने के लिए ऊपर स्लाइड करें';

  @override
  String get composerCaptureMicPermissionTitle => 'माइक्रोफ़ोन चाहिए';

  @override
  String get composerCaptureMicPermissionBody =>
      'वॉइस मैसेज रिकॉर्ड करने के लिए MonkeyHub को आपके माइक्रोफ़ोन की ज़रूरत है। इसे सेटिंग्स में चालू करें और दोबारा कोशिश करें।';

  @override
  String get composerCaptureCameraPermissionTitle => 'कैमरा चाहिए';

  @override
  String get composerCaptureCameraPermissionBody =>
      'वीडियो नोट रिकॉर्ड करने के लिए MonkeyHub को आपके कैमरे और माइक्रोफ़ोन की ज़रूरत है। इन्हें सेटिंग्स में चालू करें और दोबारा कोशिश करें।';

  @override
  String get composerCaptureRestrictedBody =>
      'इस डिवाइस पर लगी पाबंदी के कारण रिकॉर्डिंग बंद है।';

  @override
  String get composerCaptureOpenSettingsLabel => 'सेटिंग्स खोलें';

  @override
  String get composerCaptureUnavailableSnack =>
      'इस डिवाइस पर रिकॉर्डिंग उपलब्ध नहीं है।';

  @override
  String get composerCaptureInterruptedSnack => 'रिकॉर्डिंग रुक गई।';

  @override
  String get composerCaptureStorageSnack =>
      'रिकॉर्डिंग सेव नहीं हो सकी। खाली जगह जाँचें।';

  @override
  String get videoNoteMessagePlayLabel => 'वीडियो नोट चलाएँ';

  @override
  String get videoNoteMessagePauseLabel => 'वीडियो नोट रोकें';

  @override
  String get videoNoteMessageLoadingLabel => 'वीडियो नोट लोड हो रहा है';

  @override
  String get videoNoteMessageUnavailableLabel => 'वीडियो नोट उपलब्ध नहीं';

  @override
  String get videoNoteMessageRetryLabel => 'वीडियो नोट फिर से आज़माएँ';

  @override
  String get videoNoteMessageRetryHint => 'फिर से आज़माने के लिए टैप करें';

  @override
  String get videoNoteMessageDiscardLabel => 'वीडियो नोट हटाएँ';

  @override
  String get attachmentMenuVideoNoteLabel => 'वीडियो नोट';

  @override
  String get cameraScreenPhotoModeLabel => 'फ़ोटो';

  @override
  String get cameraScreenVideoModeLabel => 'वीडियो';

  @override
  String get cameraScreenStartRecordingLabel => 'रिकॉर्डिंग शुरू करें';

  @override
  String get cameraScreenStopRecordingLabel => 'रिकॉर्डिंग रोकें';

  @override
  String get cameraScreenVideoFailedSnack => 'वह वीडियो रिकॉर्ड नहीं हो सका।';

  @override
  String get scheduleSheetTitle => 'संदेश शेड्यूल करें';

  @override
  String get scheduleSheetSubtitle => 'अभी लिखें। जब आप कहें, तब जाएगा।';

  @override
  String get scheduleSheetWhenLabel => 'कब';

  @override
  String get schedulePresetInAnHour => '1 घंटे में';

  @override
  String get schedulePresetInEightHours => '8 घंटे में';

  @override
  String get schedulePresetTomorrowMorning => 'कल सुबह';

  @override
  String get schedulePresetThisMorning => 'आज सुबह';

  @override
  String get schedulePresetInAWeek => '1 हफ़्ते में';

  @override
  String get scheduleSheetCustomChip => 'तारीख़ चुनें';

  @override
  String get scheduleSheetConfirmButton => 'शेड्यूल करें';

  @override
  String get scheduleSheetSaveButton => 'सहेजें';

  @override
  String scheduleSendsAtSentence(String when) {
    return '$when भेजा जाएगा।';
  }

  @override
  String scheduleWhenToday(String time) {
    return 'आज $time बजे';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return 'कल $time बजे';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return '$date को $time बजे';
  }

  @override
  String get scheduleTimePickerTitle => 'तारीख़ और समय चुनें';

  @override
  String get scheduleTimePickerBack => 'झटपट विकल्प';

  @override
  String get scheduleTimePickerToday => 'आज';

  @override
  String get scheduleTimePickerTomorrow => 'कल';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count शेड्यूल किए',
      one: '1 शेड्यूल किया',
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
      other:
          '$count संदेश भेजे जाने का इंतज़ार कर रहे हैं। देखने के लिए टैप करें।',
      one: '1 संदेश भेजे जाने का इंतज़ार कर रहा है। देखने के लिए टैप करें।',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => 'ध्यान दें';

  @override
  String get scheduledListTitle => 'शेड्यूल किए गए';

  @override
  String get scheduledListSubtitle =>
      'भेजे जाने तक इन्हें सिर्फ़ आप देख सकते हैं।';

  @override
  String get scheduledListEmpty => 'यहाँ भेजे जाने के इंतज़ार में कुछ नहीं है।';

  @override
  String get scheduledListSendNow => 'अभी भेजें';

  @override
  String get scheduledListChangeTime => 'समय बदलें';

  @override
  String get scheduledListEdit => 'लिखा हुआ बदलें';

  @override
  String get scheduledListDelete => 'हटाएँ';

  @override
  String get scheduledListSending => 'भेजा जा रहा है…';

  @override
  String get scheduledListFailedTitle => 'भेजा नहीं जा सका';

  @override
  String get scheduledListRetry => 'फिर कोशिश करें';

  @override
  String get scheduleErrorOutOfRange =>
      'अभी से दो मिनट और एक साल के बीच का कोई समय चुनें।';

  @override
  String get scheduleErrorTooMany =>
      'यहाँ बहुत सारे संदेश इंतज़ार में हैं। पहले कुछ भेजें या हटाएँ।';

  @override
  String get scheduleErrorNotInEphemeral =>
      'यहाँ के संदेश अपने आप मिट जाते हैं, इसलिए इन्हें शेड्यूल नहीं किया जा सकता।';

  @override
  String get scheduleErrorNotMember => 'आप अब इस चैट में नहीं हैं।';

  @override
  String get scheduleErrorBlocked => 'पहले उन्हें अनब्लॉक करना होगा।';

  @override
  String get scheduleErrorGeneric => 'यह नहीं हो पाया। फिर कोशिश करें।';

  @override
  String get scheduleEditTitle => 'संदेश बदलें';

  @override
  String get composerScheduleAction => 'यह संदेश शेड्यूल करें';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count संदेश भेजे जाने के इंतज़ार में',
      one: '1 संदेश भेजे जाने के इंतज़ार में',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => 'कैसे दिखाएँ';

  @override
  String get scheduledIndicatorPill => 'पट्टी';

  @override
  String get scheduledIndicatorBadge => 'बैज';

  @override
  String get scheduledIndicatorBoth => 'दोनों';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count संदेश पहले से इंतज़ार में',
      one: '1 संदेश पहले से इंतज़ार में',
      zero: 'भेजे जाने के इंतज़ार में कुछ नहीं',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => 'ये कैसे दिखें';

  @override
  String get scheduledIndicatorPillSub =>
      'लिखने के बॉक्स के ऊपर एक पट्टी। देखने के लिए टैप करें।';

  @override
  String get scheduledIndicatorBadgeSub =>
      'भेजें बटन पर एक संख्या। जब तक आप लिखना शुरू न करें, कुछ नहीं दिखता।';

  @override
  String get scheduledIndicatorBothSub => 'पट्टी, और लिखते समय संख्या भी।';

  @override
  String get scheduledBack => 'वापस';

  @override
  String get serverScreenTitle => 'सर्वर.';

  @override
  String get serverScreenSubtitle => 'जहाँ आपका खाता और संदेश रहते हैं';

  @override
  String get serverOnboardingTitle => 'सर्वर चुनें.';

  @override
  String get serverOnboardingSubtitle =>
      'यह बिल्ड बिना सर्वर के आया है — इसे अपने सर्वर पर लगाएँ';

  @override
  String get serverStatusConnected => 'जुड़ा है';

  @override
  String get serverStatusDisconnected => 'जुड़ा नहीं है';

  @override
  String get serverBadgeDefault => 'डिफ़ॉल्ट';

  @override
  String get serverBadgeSelfHosted => 'स्वयं-होस्टेड';

  @override
  String get serverNoneConfigured => 'अभी कोई सर्वर नहीं';

  @override
  String get serverActiveNowLabel => 'उपयोग में';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'वह सर्वर जो इस ऐप के साथ आया था।';

  @override
  String get serverChoiceOwn => 'आपका अपना सर्वर';

  @override
  String get serverChoiceOwnSub => 'एक Convex बैकएंड जिसे आप स्वयं चलाते हैं।';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => 'चिपकाएँ';

  @override
  String get serverProblemMalformed => 'यह वेब पता नहीं है।';

  @override
  String get serverProblemBadScheme => 'इसे https:// या http:// से शुरू करें।';

  @override
  String get serverProblemNoHost => 'https:// के बाद अपने सर्वर का पता जोड़ें।';

  @override
  String get serverProblemCredentials =>
      'पते में से उपयोगकर्ता नाम और पासवर्ड हटाएँ।';

  @override
  String get serverInsecureTitle => 'एन्क्रिप्टेड नहीं';

  @override
  String get serverInsecureBody =>
      'फ़ोन सादा http रोकते हैं, इसलिए यह पता iOS या Android पर नहीं जुड़ेगा। https इस्तेमाल करें, या टनल के ज़रिए अपने सर्वर तक पहुँचें।';

  @override
  String get serverTestCta => 'कनेक्शन जाँचें';

  @override
  String get serverTestingLabel => 'जाँच हो रही है…';

  @override
  String get serverCheckReachable => 'कुछ ने जवाब दिया';

  @override
  String get serverCheckConvex => 'यह Convex सर्वर है';

  @override
  String get serverCheckApp => 'इस पर MonkeyHub चल रहा है';

  @override
  String get serverResultUnreachable => 'उस पते पर किसी ने जवाब नहीं दिया।';

  @override
  String get serverResultNotConvex =>
      'कुछ ने जवाब दिया, पर वह Convex सर्वर नहीं है।';

  @override
  String get serverResultNotThisApp =>
      'यह Convex सर्वर है, पर उस पर MonkeyHub तैनात नहीं है।';

  @override
  String get serverResultServerError => 'सर्वर ने जवाब दिया, पर त्रुटि के साथ।';

  @override
  String get serverResultReady => 'जुड़ने के लिए तैयार।';

  @override
  String get serverConnectCta => 'जुड़ें';

  @override
  String get serverConnectAnywayCta => 'फिर भी जुड़ें';

  @override
  String get serverAlreadyConnectedCta => 'पहले से जुड़ा है';

  @override
  String get serverUseDefaultCta => 'डिफ़ॉल्ट सर्वर इस्तेमाल करें';

  @override
  String get serverChangeCta => 'सर्वर बदलें';

  @override
  String get serverAdvancedLabel => 'उन्नत';

  @override
  String get serverSiteUrlExplain =>
      'ज़्यादातर सर्वर सब कुछ एक ही पते पर देते हैं। यह तभी भरें जब आपका सर्वर HTTP actions कहीं और देता हो।';

  @override
  String get serverSiteUrlHint => 'ऊपर जैसा ही';

  @override
  String get serverSectionRecent => 'हाल के';

  @override
  String get serverRecentForget => 'इस सर्वर को भूल जाएँ';

  @override
  String get serverSwitchWarningTitle => 'बदलने पर साइन आउट हो जाएगा';

  @override
  String get serverSwitchWarningBody =>
      'खाते और चैट एक ही सर्वर के होते हैं। यह डिवाइस साइन आउट होगा, डाउनलोड किया हुआ मिटाएगा, और नए सिरे से शुरू करेगा। किसी भी सर्वर पर कुछ भी मिटाया नहीं जाता।';

  @override
  String get serverSwitchRolledBackTitle => 'जुड़ नहीं सके';

  @override
  String serverSwitchRolledBackBody(String host) {
    return '$host ने जवाब नहीं दिया, इसलिए कुछ नहीं बदला। आपको फिर से साइन इन करना होगा।';
  }

  @override
  String get serverSwitchStrandedBody =>
      'कोई भी सर्वर नहीं जुड़ा। पता जाँचें और फिर कोशिश करें।';

  @override
  String get serverSwitchRefusedBody =>
      'यह डिवाइस किसी बच्चे के लिए सेट है और सर्वर नहीं बदल सकता।';

  @override
  String serverChipSemantics(String server) {
    return 'सर्वर बदलें। अभी $server।';
  }

  @override
  String get serverValueDefault => 'डिफ़ॉल्ट';

  @override
  String get settingsScreenRowServer => 'सर्वर';

  @override
  String get settingsScreenSectionAdvanced => 'उन्नत';

  @override
  String get serverSwitchingLabel => 'सर्वर बदला जा रहा है…';

  @override
  String get serverBadgeHomeserver => 'होमसर्वर से चल रहा है';

  @override
  String get serverBadgeHomeserverSemantics =>
      'होमसर्वर से चल रहा है। जानकारी के लिए टैप करें।';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'स्वयं-होस्टेड सर्वर: $server। जानकारी के लिए टैप करें।';
  }

  @override
  String get serverRoleHomeserverTitle => 'होमसर्वर पर चल रहा है';

  @override
  String get serverRoleHomeserverBody =>
      'MonkeyHub चलाने वाले लोगों ने कुछ समय के लिए ट्रैफ़िक अपने घर के सर्वर पर भेजा है। सब कुछ पहले जैसा ही काम करता है — यह जानबूझकर किया गया है, कोई गड़बड़ी नहीं।';

  @override
  String get serverRoleHomeserverWarnData =>
      'जब तक यह चालू है, आप जो भेजते हैं वह ट्रैफ़िक वापस जाने के बाद शायद यहाँ न रहे।';

  @override
  String get serverRoleHomeserverWarnSpeed =>
      'घर का कनेक्शन सामान्य से धीमा होता है, इसलिए चीज़ें अटक सकती हैं।';

  @override
  String get serverRoleHomeserverWarnAuto =>
      'आपको कुछ करने की ज़रूरत नहीं। ऐप अपने आप वापस चला जाएगा।';

  @override
  String get serverRoleSelfHostedTitle => 'आपका अपना सर्वर';

  @override
  String get serverRoleSelfHostedBody =>
      'यह डिवाइस आपके अपने सर्वर पर लगा है। इसे सेटिंग्स › उन्नत › सर्वर में बदलें।';

  @override
  String get serverValueHomeserver => 'फ़िलहाल होमसर्वर';

  @override
  String get serverChoiceCloudSubHomeserver =>
      'कुछ समय के लिए होमसर्वर से दिया जा रहा है।';

  @override
  String get serverDirectiveChangedToast =>
      'आपका सर्वर बदल गया। फिर से जुड़ा जा रहा है…';

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
}
