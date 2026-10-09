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
      'अभी पूछ नहीं पाए, फिर से कोशिश करो';

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
  String get roomScreenUnreadDivider => 'अपठित मैसेज';

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
  String get roomScreenPinLimitSnack => 'बहुत सारे पिन, पहले एक अनपिन करो';

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
  String get profileScreenEmailHint => 'वैकल्पिक, किसी को नहीं दिखेगा';

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
      'उन्होंने तुम्हें पहले ही रिक्वेस्ट भेज दी है। रिक्वेस्ट्स देखो।';

  @override
  String get profileScreenErrorRequestAlreadySent =>
      'रिक्वेस्ट पहले ही भेजी जा चुकी है।';

  @override
  String get profileScreenErrorUnblockFirst =>
      'तुमने इस यूज़र को ब्लॉक किया है। पहले उन्हें अनब्लॉक करो।';

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
      'यह सिर्फ़ बड़े ही कर सकते हैं। इसके लिए उनका कोड या पासवर्ड ज़रूरी है।';

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
      'सीमित जानकारी। वे दोस्तों के साथ ज़्यादा शेयर करते हैं।';

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
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: चालू';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: बंद';

  @override
  String get cameraEditorScreenHdNote => 'पूर्ण रिज़ॉल्यूशन में भेजा जा रहा है';

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
      'कंपोज़र, हेडर, कॉल बटन, यानी वह सब कुछ जो स्क्रॉलिंग कंटेंट पर नहीं, बल्कि टेक्स्ट के ऊपर होता है';

  @override
  String get glassScreenMatchBottomBar => 'बॉटम बार जैसा करें';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'बदला गया। इसे नए लुक के रूप में सेव करें, या रीसेट करें';

  @override
  String get glassScreenCustomPresetName => 'कस्टम';

  @override
  String get glassScreenUnsavedSubtitle =>
      'सेव नहीं हुआ। रखने के लिए इसे नाम दो';

  @override
  String get glassScreenSaveDialogTitle => 'इस लुक को नाम दो';

  @override
  String get glassScreenNoRoomToast => 'जगह नहीं है, पहले कोई लुक मिटाओ';

  @override
  String get glassScreenRenameDialogTitle => 'नाम बदलो';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '$name मिटाना है?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'लुक स्क्रीन पर बना रहेगा, बस उसका नाम नहीं रहेगा।';

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
      'छत की फ़ोटो भेजी, सारी टाइलें टूटी हुई हैं';

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
      'अभी भेजा जा रहा है, थोड़ी देर में फिर कोशिश करें';

  @override
  String get threadOverlayCopiedToast => 'कॉपी हो गया';

  @override
  String get threadOverlayNameCopiedToast => 'नाम कॉपी हो गया';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'निर्देशांक कॉपी किए गए';

  @override
  String get threadOverlayPinLimitToast =>
      'बहुत ज़्यादा पिन, पहले एक अनपिन करें';

  @override
  String get threadOverlayPinFailedToast => 'उसे पिन नहीं कर सके';

  @override
  String get threadOverlayReportedToast => 'रिपोर्ट किया गया';

  @override
  String get threadOverlayUnavailable => 'थ्रेड उपलब्ध नहीं है';

  @override
  String get roomInfoScreenNameRequiredError => 'नाम ज़रूरी है';

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
    return '$peerName भी यह बातचीत खो देगा। तुम दोनों के लिए हर मैसेज गायब हो जाएगा। यह हमेशा के लिए है।';
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
  String get roomInfoScreenDescriptionHint => 'रूम के बारे में एक लाइन';

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
      'यह रूम सुरक्षित है। सुरक्षा कारणों से मौजूदा पासफ़्रेज़ नहीं दिखाया जाता। इसे बदलने के लिए नया डालें।';

  @override
  String get roomInfoScreenReplacePasswordHint => 'पासफ़्रेज़ बदलें';

  @override
  String get roomInfoScreenSetPasswordHint => 'पासफ़्रेज़ से लॉक करें';

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
  String get roomInfoScreenOwnerBadge => 'मालिक';

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
    return 'अब तुमसे उनके बारे में दोबारा नहीं पूछा जाएगा, चाहे $childName उन्हें जोड़े या वे $childName को जोड़ें।';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'किसी को अनुमति दें';

  @override
  String get childPolicyScreenAskToAddLabel => 'जोड़ने के लिए पूछें';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'सिर्फ़ परिवार, कोई नई रिक्वेस्ट नहीं';

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
      'जोड़ दिया, रिक्वेस्ट रास्ते में है';

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
      'अकाउंट डिलीट नहीं हो पाया, फिर से कोशिश करो';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return '$name का अकाउंट डिलीट करें?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'मैसेज, फ़ोटो, रूम और दोस्त, सब मिट जाएंगे। इसे पलटा नहीं जा सकता।';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return '$name का अकाउंट डिलीट करें';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'हमेशा के लिए डिलीट करें';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'उन्हें जोड़ा नहीं जा सका, फिर से कोशिश करो';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'यह तो उनका अपना यूज़रनेम है';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'कोई बच्चा बड़ा नहीं हो सकता';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'यह नहीं हो सका, फिर से कोशिश करें';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'किसी को तो उनकी देखभाल करनी होगी। पहले एक और बड़ा जोड़ें';

  @override
  String get childPolicyScreenErrorNotYours =>
      'इसे बदलने का अधिकार तुम्हें नहीं है';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'इस यूज़रनेम से कोई अकाउंट नहीं मिला';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'इस पासवर्ड के साथ वे एक सामान्य अकाउंट बन जाएंगे, और हर बड़े की उन पर नज़र पूरी तरह खत्म हो जाएगी। इसे वापस नहीं किया जा सकता। फिर तुम्हें भी बाकी सबकी तरह आमंत्रित किया जाना होगा।';

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
      'उन्हें ग्रेजुएट नहीं किया जा सका, फिर से कोशिश करें';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return '$name को ग्रेजुएट करें';
  }

  @override
  String get childPolicyScreenGraduateHint => 'उनके लिए एक पासवर्ड';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'कोई रूम वापस लेने पर वे उससे भी हट जाते हैं। कोई व्यक्ति वापस लेने पर उनकी चैट भी डिलीट हो जाती है, दोनों के लिए।';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'यहाँ मौजूद हर कोई अप्रूव कर सकता है, सेटिंग्स बदल सकता है, और सब कुछ देख सकता है। इनमें से कोई भी अकेले फैसला ले सकता है, किसी को दूसरों का इंतज़ार नहीं करना पड़ता।';

  @override
  String get childPolicyScreenGuardianAdded =>
      'जोड़ दिया गया, अब वे उनकी देखभाल कर सकते हैं';

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
      'इनमें से किसी को भी दोबारा तुमसे पूछे बिना जोड़ा जा सकता है, चाहे शुरुआत उनमें से कोई भी करे।';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'बच्चों के लिए यह हमेशा बंद रहता है। डिस्कवर (यानी अनजान लोगों के रूम्स की लिस्ट) पूरी तरह छिपा दी जाती है और इसे कभी चालू नहीं किया जा सकता। किसी ने उन्हें जिस रूम में आमंत्रित किया हो, वह पहले जैसा ही काम करता है।';

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
  String childPolicyScreenRoomMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य',
      one: '1 सदस्य',
    );
    return '$_temp0';
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
    return 'तुम $name के इकलौते बड़े हो, इसलिए यूं ही पीछे नहीं हट सकते। पहले किसी और को जोड़ो, या इनमें से कोई एक इस्तेमाल करो।';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'पीछे हटें';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'तुम्हें $name के अकाउंट की कोई भनक नहीं मिलेगी: न उनकी रिक्वेस्ट्स, न उनके लोग, न उनके रूम्स। बाकी बड़े उनका ख्याल रखते रहेंगे।';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'निगरानी बंद करें';

  @override
  String get childPolicyScreenStopSupervisingHeadline => 'निगरानी बंद करें?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'वापस नहीं ले पाए, फिर कोशिश करो';

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
      'अभी तक कुछ सेव नहीं किया. किसी मैसेज को दबाकर रखें और सेव करें चुनें.\n\nयहाँ आप जो रखते हैं वह सिर्फ़ आपके लिए है. पिन किया गया मैसेज पूरा रूम देखता है.';

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
      'स्पॉइलर: छिपा टेक्स्ट दिखाने के लिए सक्रिय करें';

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
      'एडिट करने में देर हो गई। मैसेज सिर्फ़ 15 मिनट तक ही एडिट किए जा सकते हैं।';

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
    return 'एक्टिव: $name';
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
  String callScreenStatusCalling(String kind) {
    return '$kind · कॉल की जा रही है…';
  }

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
      'तुमने इस यूज़र को ब्लॉक किया है. पहले अनब्लॉक करो.';

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
  String get friendRequestDraftScreenHintStartWith => 'शुरुआत के लिए कुछ लिखो';

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
  String get discoverScreenYourPeopleLabel => 'दोस्त';

  @override
  String get discoverScreenNoFriendsYetWithHint => 'अभी कोई नहीं, ऊपर लोग खोजो';

  @override
  String get discoverScreenNoFriendsYet => 'अभी कोई नहीं';

  @override
  String get discoverScreenSearchRoomsTitle => 'रूम खोजो';

  @override
  String get discoverScreenSearchRoomsSubtitle => 'नाम से पब्लिक रूम खोजो';

  @override
  String get discoverScreenYourRoomsLabel => 'रूम्स';

  @override
  String get discoverScreenNoRoomsYet => 'अभी कोई रूम नहीं';

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
  String get searchScreenHintPeople => 'लोग खोजो';

  @override
  String get searchScreenHintRooms => 'पब्लिक रूम खोजो';

  @override
  String get searchScreenPeoplePromptChild =>
      'किसी नए को खोजने के लिए पूरा यूज़रनेम टाइप करो';

  @override
  String get searchScreenPeoplePromptDefault => 'यूज़रनेम या नाम से खोजो';

  @override
  String get searchScreenNoMatchChild =>
      'कोई मेल नहीं खाता। नए लोगों के लिए उनका\nपूरा यूज़रनेम बिल्कुल सही लिखना होगा';

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
      'तय करो दूसरे क्या देखें, और तुम तक कैसे पहुंचें.';

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
      'यहाँ तुम वही देख सकते हो जो बाकी सब देखते हैं, पर इसे सिर्फ़ कोई बड़ा ही बदल सकता है। वे हमेशा तुम्हारी फ़ोटो, तुम्हारा ऑनलाइन स्टेटस और आख़िरी बार तुम कब थे, यह देख सकते हैं।';

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
  String get logoScreenSubtitle => 'तुम्हारे हेडर का निशान, फ़ैसला तुम्हारा.';

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
      'कॉपी हो गया, इसे कहीं सुरक्षित जगह पेस्ट करो';

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
      'अभी नहीं, मौजूदा फ़्रेज़ ही रखो';

  @override
  String get homeScreenProfileSemanticLabel => 'तुम्हारी प्रोफ़ाइल';

  @override
  String homeScreenGreeting(Object name) {
    return 'हाय, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'नया रूम';

  @override
  String get homeScreenEmptyRoomsMessage => 'अभी कोई रूम नहीं, एक बनाओ';

  @override
  String get groupCallScreenTitleVideo => 'ग्रुप वीडियो कॉल';

  @override
  String get groupCallScreenTitleVoice => 'ग्रुप वॉइस कॉल';

  @override
  String groupCallScreenParticipantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'कॉल में $count',
      one: 'सिर्फ़ तुम',
    );
    return '$_temp0';
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
  String get groupCallScreenCamOffLabel => 'कैम ऑफ';

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
  String get createRoomSheetNameHint => 'कोई सच्चा-सा नाम रखो';

  @override
  String get createRoomSheetDescriptionLabel => 'विवरण · वैकल्पिक';

  @override
  String get createRoomSheetDescriptionHint => 'रूम के बारे में एक लाइन';

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
  String get createRoomSheetPasswordHint => 'एक पासफ़्रेज़ से लॉक करो';

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
  String get audioMessageSwitchToLinkPrompt => 'वो मेरा है, साइन इन करो';

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
  String get approvalsScreenErrorGeneric => 'सेव नहीं हो पाया, फिर कोशिश करो';

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
  String get profileScreenDeleteAccountFailed =>
      'कुछ गड़बड़ हो गई। फिर से कोशिश करो।';

  @override
  String get childPairScreenAccountGoneError => 'वह अकाउंट अब मौजूद नहीं है।';

  @override
  String get childPairScreenScanButtonLabel => 'उनका कोड स्कैन करो';

  @override
  String get childPairScreenNoCameraMessage =>
      'यहाँ कैमरा नहीं है। इसके बजाय छह अंक टाइप करो।';

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
      'इस फ़ाइल का कुछ हिस्सा दिखाया जा रहा है। बाकी देखने के लिए डाउनलोड करें।';

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
      'कोड नहीं बन पाया, फिर से कोशिश करो।';

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
    return '$name के फ़ोन पर MonkeyHub खोलो और इसे स्कैन करो, या नंबर टाइप करो।';
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
  String get deepOceanThemeEphemeralHint => 'कुछ फुसफुसाओ';

  @override
  String get deepOceanThemeDefaultHint => 'कुछ कहो';

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
  String get photoChromeFillToggleSemanticLabel =>
      'स्क्रीन में फ़िट करें या भरें';

  @override
  String get photoChromeShowInChatSemanticLabel => 'चैट में दिखाएं';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return '$total में से $current';
  }

  @override
  String photoTrayCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ोटो',
      one: '1 फ़ोटो',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => 'ये फ़ोटो छोड़ें';

  @override
  String get photoTrayRemoveSemanticLabel => 'यह फ़ोटो हटाएँ';

  @override
  String get photoTrayEditSemanticLabel =>
      'इस फ़ोटो को क्रॉप करें या उस पर बनाएँ';

  @override
  String get photoTrayAddMoreSemanticLabel => 'और फ़ोटो जोड़ें';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'आप एक बार में $count फ़ोटो भेज सकते हैं';
  }

  @override
  String get photoTrayLoadFailedSnack => 'उनमें से कुछ फ़ोटो नहीं खुल सकीं';

  @override
  String get mediaPickFailedMessage => 'वह खुल नहीं पाया, फिर से चुनकर देखो';

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
    return 'यह $name को इस फ़ोन से साइन आउट कर देता है और फ़ोन वापस कर देता है। फ़ोन सामान्य साइन-इन स्क्रीन पर लौट आता है, और कोई भी इसे इस्तेमाल कर सकता है।';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'उनका अकाउंट, मैसेज और दोस्त सब कुछ सुरक्षित रहता है। उन्हें कभी भी दोबारा साइन इन किया जा सकता है।';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return 'किसी बड़े से कहो: MonkeyHub खोलें, परिवार में $name को ढूंढें, और “रिलीज़” पर टैप करें।';
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
      'एक्सेंट-रंगी कोट कैप्सूल, डोरी बार और अवतार के साथ, वही जाना-पहचाना व्हाट्सएप-स्टाइल लुक।';

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
      'अकाउंट नहीं बन सका, फिर से कोशिश करो।';

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
      'बाकी सबके लिए पहले तुम्हारी मंज़ूरी ज़रूरी है, चाहे वो किसी को जोड़ने की रिक्वेस्ट भेजें, या कोई उन्हें जोड़ने की रिक्वेस्ट भेजे।';

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
      'कोई नोक नहीं। सिलसिला बस अपने कसे हुए भीतरी कोनों से जुड़ा रहता है।';

  @override
  String get bubbleStyleScreenPillLabel => 'कैप्सूल';

  @override
  String get bubbleStyleScreenPillDescription =>
      'पूरी तरह गोल कैप्सूल, हर पंक्ति में एक जैसे।';

  @override
  String get bubbleStyleScreenSlabLabel => 'स्लैब';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'चौकोर कोने: तीखे, छपे जैसे, सोच-समझकर बनाए गए।';

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
      'दोनों की तरफ़ से हमेशा के लिए मिट जाएगा, फ़ोटो और वॉइस नोट्स समेत। इसे वापस नहीं लाया जा सकता।';

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
  String get groupCallBannerPasswordHint => 'पासफ़्रेज़';

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
  String get discoverListsPeopleTitle => 'दोस्त';

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
  String get discoverListsFilterHint => 'दोस्त खोजो';

  @override
  String get discoverListsClearFilterSemanticLabel => 'फ़िल्टर हटाओ';

  @override
  String get discoverListsNoOneYet => 'अभी तक कोई नहीं';

  @override
  String discoverListsNoMatches(Object query) {
    return '\"$query\" से कोई मेल नहीं खाता';
  }

  @override
  String get discoverListsRoomsTitle => 'रूम्स';

  @override
  String discoverListsRoomsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count रूम',
      one: '$count रूम',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterRoomsHint => 'अपने रूम खोजो';

  @override
  String get discoverListsNoRoomsYet => 'अभी तक कोई रूम नहीं';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return '\"$query\" से कोई रूम मेल नहीं खाता';
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
      'रिपोर्ट निजी होती है, दूसरे व्यक्ति को पता नहीं चलता।';

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
      'अभी तुम दोनों दोस्त हो। ब्लॉक करने पर दोस्ती खत्म हो जाएगी, तो बाद में दोबारा जुड़ने के लिए नई फ्रेंड रिक्वेस्ट भेजनी होगी।';

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
      'तुम्हारी उनके साथ की डीएम भी मिट जाएगी: हर मैसेज, रिएक्शन और मीडिया फाइल हमेशा के लिए गायब हो जाएगी।';

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
      'अभी रिक्वेस्ट नहीं भेज पाए, फिर से कोशिश करो';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'गलत पासवर्ड';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'जॉइन नहीं हो सका, दोबारा कोशिश करें';

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
      'बोर्ड लोड नहीं हो सका, थोड़ी देर में फिर कोशिश करें';

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
      'सिर्फ़ न्योते से, यह खोजो में नहीं दिखता';

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
      'कोई रिकवरी फ़्रेज़ नहीं। तुम वापस अंदर नहीं आ पाओगे।';

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
  String get settingsScreenSectionCompanions => 'साथी';

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
      'बताइए क्या गड़बड़ हुई। आपके ऐप और डिवाइस की जानकारी अपने आप जुड़ जाती है, साथ में एक तकनीकी लॉग भी जिसमें ऐप उस समय क्या कर रहा था। इसी से कारण ढूँढ़ने में मदद मिलती है।';

  @override
  String get reportProblemDescribeLabel => 'क्या हुआ';

  @override
  String get reportProblemDescribeHint =>
      'स्क्रीन झिलमिलाती है, बटन काम नहीं करते';

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
  String get reportProblemSent => 'रिपोर्ट भेज दी गई, धन्यवाद!';

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
      'फिलहाल सिर्फ़ प्रीव्यू: साफ़-सुथरे बबल, खोलने के लिए टैप करें';

  @override
  String get settingsScreenMenuBarLabel => 'मेन्यू बार आइकन';

  @override
  String get settingsScreenMenuBarOnBody =>
      'MonkeyHub अपनी अनपढ़ी गिनती के साथ मेन्यू बार में रहता है। विंडो के लिए उस पर क्लिक करें';

  @override
  String get settingsScreenMenuBarOffBody =>
      'अभी बंद है। छिपी हुई विंडो वापस लाने का एकमात्र तरीका Dock आइकन है';

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
      'फुल एचडी: ज़्यादा शार्प, ज़्यादा डेटा इस्तेमाल करता है';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'अल्ट्रा एचडी: मज़बूत कनेक्शन पर सबसे अच्छा';

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
      'साइलेंट। ऐप खोलने पर ही चीज़ें दिखेंगी';

  @override
  String get settingsScreenGameRemindersLabel => 'रोज़ का गेम रिमाइंडर';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'दोपहर में एक बार, सिर्फ़ तब जब आपने खेला न हो';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'कोई रिमाइंडर नहीं, खेल तब भी वहीं मिलेंगे';

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
      'यह किसी बच्चे का अकाउंट है। पेयरिंग कोड के लिए किसी बड़े से मांगें।';

  @override
  String get authErrorPairingCodeExpired =>
      'यह कोड ख़त्म हो चुका है। नया कोड मांगें।';

  @override
  String get authErrorPairingCodeInvalid =>
      'यह कोड काम नहीं आया। हो सकता है यह पहले ही इस्तेमाल हो चुका हो।';

  @override
  String get authErrorUseSocialSignIn =>
      'यह अकाउंट Apple या Google से साइन इन करता है। नीचे दिए बटन इस्तेमाल करें।';

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
      'काँच के किनारे की चमक। बिना बॉर्डर वाली सतह के लिए शून्य';

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
  String get motionScreenCalmSubtitle => 'सजावट रुक जाती है, और कुछ नहीं बदलता';

  @override
  String get momentRailCaptureLabel => 'कैप्चर';

  @override
  String get momentRailYouLabel => 'आप';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String momentRailPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ख़ास पल',
      one: '1 ख़ास पल',
    );
    return '$_temp0';
  }

  @override
  String momentRailPersonNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count नए',
      one: '1 नया',
    );
    return '$_temp0';
  }

  @override
  String get momentRailAddHighlight => 'ख़ास पल जोड़ें';

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
  String get momentComposerTitle => 'नया पल';

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
  String get momentComposerErrorDailyCap => 'आज पाँच हो गए, कल के लिए भी रखिए';

  @override
  String get momentComposerErrorNotAllowed =>
      'अभिभावक ने फ़ोटो साझा करना बंद कर रखा है';

  @override
  String get momentComposerErrorTooLong => 'थोड़ा लंबा है, छोटा कीजिए';

  @override
  String get momentComposerErrorEmpty => 'एक फ़ोटो या कुछ शब्द जोड़िए';

  @override
  String get momentComposerErrorGeneric => 'पोस्ट नहीं हो सका, फिर कोशिश कीजिए';

  @override
  String get momentViewerDelete => 'हटाएँ';

  @override
  String get momentViewerDeleteConfirmHeadline => 'इसे हटाएँ?';

  @override
  String get momentViewerDeleteConfirmBody =>
      'यह सबके बोर्ड और आपके संग्रह, दोनों से हमेशा के लिए हट जाएगा';

  @override
  String get momentViewerDeleteFailed => 'हटाया नहीं जा सका, फिर कोशिश कीजिए';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who ने एक पल साझा किया';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name को एक अंक मिला: $tag';
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
  String get puzzleShareCopied => 'कॉपी हो गया, दोस्त को भेजें';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'आज की पहेली आप हल कर चुके हैं';

  @override
  String get puzzleErrorOutOfGuesses => 'आज कोई मौका नहीं बचा';

  @override
  String get puzzleErrorGeneric => 'भेजा नहीं जा सका, फिर कोशिश करें';

  @override
  String get puzzleGuessWaiting =>
      'कनेक्शन नहीं है। आपका अनुमान सहेजा गया है, कनेक्शन लौटते ही भेजा जाएगा';

  @override
  String get gameSubmitWaiting =>
      'कनेक्शन नहीं है। आपका पूरा बोर्ड सहेजा गया है, कनेक्शन लौटते ही भेजा जाएगा';

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
      'आज हमेशा दोस्तों के साथ साझा होता है। यह उससे पहले का सब कुछ खोलता है';

  @override
  String get momentComposerVideo => 'वीडियो';

  @override
  String get momentComposerErrorTooBig =>
      'यह वीडियो बहुत बड़ा है (अधिकतम 20 MB)';

  @override
  String get momentActivityPostedHighlightSelf => 'आपने एक पल साझा किया';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'आपको एक अंक मिला: $tag';
  }

  @override
  String momentActivityGameSolved(String game, String name) {
    return '$name ने हल किया: $game';
  }

  @override
  String momentActivityGameSolvedSelf(String game) {
    return 'आपने हल किया: $game';
  }

  @override
  String momentActivityGameMissed(String game, String name) {
    return '$name हल नहीं कर पाए: $game';
  }

  @override
  String momentActivityGameMissedSelf(String game) {
    return 'आप हल नहीं कर पाए: $game';
  }

  @override
  String momentActivityCodeSolved(String name) {
    return '$name ने कोड तोड़ दिया';
  }

  @override
  String get momentActivityCodeSolvedSelf => 'आपने कोड तोड़ दिया';

  @override
  String momentActivityCodeMissed(String name) {
    return '$name कोड नहीं तोड़ पाए';
  }

  @override
  String get momentActivityCodeMissedSelf => 'आप कोड नहीं तोड़ पाए';

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
  String get pointComposerAdd => 'एक अंक जोड़ें';

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
      'एक चलता हुआ मज़ाक, जिसका हिसाब रखा जाता है। जब आपके साथ कुछ होता है, अच्छा, बुरा या बस अजीब, आप उसे दर्ज करते हैं और वह उस दिन बोर्ड पर रहता है।';

  @override
  String get pointsExplainerRuleHonour =>
      'अंक आप ख़ुद देते हैं। कोई जाँच नहीं करता, मज़ा यही है, और हद से बढ़े तो दोस्त बता ही देंगे।';

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
  String get feedBoardGamesLabel => 'गेम्स';

  @override
  String get feedBoardGamesOpen => 'लीडरबोर्ड';

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
      'हर पंक्ति, स्तंभ और रंग में एक ताज, जो कभी छूते नहीं';

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
  String get gameShareCopied => 'कॉपी हुआ, किसी दोस्त को भेजें';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number · $time';
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
  String get gameErrorGeneric => 'खेलों तक नहीं पहुँच सके, फिर कोशिश करें';

  @override
  String get gameInfoOpen => 'कैसे खेलें';

  @override
  String get gameInfoLabel => 'कैसे खेलें';

  @override
  String get gameInfoRulesLabel => 'नियम';

  @override
  String get gameInfoControlsLabel => 'क्या टैप करें';

  @override
  String get gameInfoScoringTimed =>
      'सबसे तेज़ खत्म करने वाला जीतता है। बाहर जाने पर घड़ी रुक जाती है।';

  @override
  String get gameInfoScoringGuesses =>
      'सबसे कम अनुमानों में हल करने वाला जीतता है। समय नहीं गिना जाता।';

  @override
  String get gameInfoSameForEveryone => 'आज सबको एक ही पहेली मिलती है।';

  @override
  String get gameInfoQueensGoal => 'बोर्ड पर 8 ताज रखें।';

  @override
  String get gameInfoQueensRule1 => 'हर पंक्ति में ठीक 1 ताज।';

  @override
  String get gameInfoQueensRule2 => 'हर स्तंभ में ठीक 1 ताज।';

  @override
  String get gameInfoQueensRule3 => 'हर रंग में ठीक 1 ताज।';

  @override
  String get gameInfoQueensControls =>
      'एक बार टैप: × (यहाँ ताज नहीं)। दो बार: ताज। फिर से: मिटाएँ।';

  @override
  String get gameInfoTangoGoal => 'हर खाने में सूरज या चाँद भरें।';

  @override
  String get gameInfoTangoRule1 => 'हर पंक्ति में 3 सूरज और 3 चाँद।';

  @override
  String get gameInfoTangoRule2 => 'हर स्तंभ में 3 सूरज और 3 चाँद।';

  @override
  String get gameInfoTangoRule3 =>
      'एक लाइन में लगातार 3 एक जैसे कभी नहीं। 2 चलेंगे।';

  @override
  String get gameInfoTangoControls =>
      'एक बार टैप: सूरज। दो बार: चाँद। फिर से: मिटाएँ। पहले से भरे खाने नहीं बदलते।';

  @override
  String get gameInfoZipGoal => 'एक ही लाइन बनाएँ जो हर खाने से गुज़रे।';

  @override
  String get gameInfoZipRule1 => '1 से शुरू करें।';

  @override
  String get gameInfoZipRule2 => 'नंबरों पर क्रम से जाएँ: 1, 2, 3…';

  @override
  String get gameInfoZipRule3 => 'हर खाना भरें। हर खाना सिर्फ़ एक बार।';

  @override
  String get gameInfoZipControls =>
      'बनाने के लिए उंगली खींचें। मिटाने के लिए वापस खींचें।';

  @override
  String get gameInfoSudokuGoal => 'ग्रिड को 1 से 6 तक के नंबरों से भरें।';

  @override
  String get gameInfoSudokuRule1 =>
      'हर पंक्ति में 1, 2, 3, 4, 5 और 6। कोई दोहराव नहीं।';

  @override
  String get gameInfoSudokuRule2 => 'हर स्तंभ में भी।';

  @override
  String get gameInfoSudokuRule3 =>
      'हर बॉक्स में भी। एक बॉक्स 2 पंक्ति और 3 स्तंभ का होता है।';

  @override
  String get gameInfoSudokuControls =>
      'एक खाने पर टैप करें, फिर एक नंबर पर। मिटाने के लिए वही नंबर फिर टैप करें। नोट्स छोटे पेंसिल निशान लगाता है।';

  @override
  String get gameInfoCodeGoal => '4 चिह्नों वाला गुप्त कोड पहचानें।';

  @override
  String get gameInfoCodeRule1 =>
      'कोड में 4 अलग-अलग चिह्न हैं। कोई दोहराव नहीं।';

  @override
  String get gameInfoCodeRule2 => 'आपको 6 अनुमान मिलते हैं।';

  @override
  String get gameInfoCodeRule3 => 'हरा: सही चिह्न, सही जगह।';

  @override
  String get gameInfoCodeControls =>
      '4 चिह्नों पर टैप करें, फिर अनुमान पर टैप करें।';

  @override
  String get savedMessagesTitle => 'सेव किए गए मैसेज';

  @override
  String homeScreenNoSearchResults(Object query) {
    return '\"$query\" से कोई चैट मेल नहीं खाती';
  }

  @override
  String get pullRevealSearchHint => 'चैट खोजो';

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
  String get roomScreenSaveLimitSnack => 'यहाँ बहुत सारे सेव हैं, पहले एक हटाओ';

  @override
  String get roomScreenSaveFailedSnack => 'उसे सेव नहीं किया जा सका';

  @override
  String get threadOverlaySaveLimitToast =>
      'यहाँ बहुत सारे सेव हैं, पहले एक हटाओ';

  @override
  String get threadOverlaySaveFailedToast => 'उसे सेव नहीं किया जा सका';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'आपके सेव किए मैसेज सिर्फ़ आपको दिखते हैं. पिन किया गया मैसेज इसका उल्टा है: उसे पूरा रूम देखता है.';

  @override
  String get roomInfoScreenOwnerBadgeNote =>
      'नाम के बगल में मौजूद छोटा मेडल दिखाता है कि यह रूम किसने बनाया.';

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
      'इस चैट से आप तक कुछ नहीं पहुँचेगा: न सूचनाएँ, न बिना पढ़े संदेशों की गिनती।';

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
      'वे अपना स्थान साझा कर सकते हैं, 8 घंटे तक लाइव भी';

  @override
  String get childPolicyScreenLocationOffDesc =>
      'वे अपना स्थान साझा नहीं कर सकते';

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
    return '$when भेजा जाएगा';
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
      'यह बिल्ड बिना सर्वर के आया है। इसे अपने सर्वर पर लगाएँ';

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
  String get serverRoleExplainAction => 'इसका क्या मतलब है?';

  @override
  String get serverBadgeRibbonHomeserver => 'होम';

  @override
  String get serverBadgeRibbonSelfHosted => 'स्वयं';

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
      'MonkeyHub चलाने वाले लोगों ने कुछ समय के लिए ट्रैफ़िक अपने घर के सर्वर पर भेजा है। सब कुछ पहले जैसा ही काम करता है। यह जानबूझकर किया गया है, कोई गड़बड़ी नहीं।';

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
  String get loginScreenUsePasswordInstead => 'इसके बजाय पासवर्ड इस्तेमाल करो';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      'अपने फ़ोन पर MonkeyHub खोलो, अपनी प्रोफ़ाइल में जाओ, “साइन इन के लिए स्कैन करें” पर टैप करो और कैमरा यहाँ रखो, या नीचे दिया कोड लिखो।';

  @override
  String get deviceLoginScreenWaiting => 'मंज़ूरी का इंतज़ार है…';

  @override
  String get deviceLoginScreenApproved => 'मंज़ूर हो गया, साइन इन हो रहा है…';

  @override
  String get deviceLoginScreenDenied =>
      'तुम्हारे फ़ोन पर साइन-इन अनुरोध ठुकरा दिया गया';

  @override
  String get deviceLoginScreenGenericError =>
      'कुछ गड़बड़ हो गई, नया कोड आज़माओ';

  @override
  String get profileScreenScanToSignInLabel => 'साइन इन के लिए स्कैन करें';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro =>
      'अपने कंप्यूटर पर दिख रहे कोड पर कैमरा रखो, या उसे नीचे लिखो।';

  @override
  String get deviceLoginScanScreenScanButtonLabel => 'कोड स्कैन करो';

  @override
  String get deviceLoginScanScreenConfirmTitle => 'इस डिवाइस पर साइन इन करें?';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return '$deviceInfo तुम्हारे नाम से साइन इन करना चाहता है। सिर्फ़ तभी मंज़ूर करो जब अभी यह तुम ही हो।';
  }

  @override
  String get deviceLoginScanScreenApproveButton => 'मंज़ूर करो';

  @override
  String get deviceLoginScanScreenDenyButton => 'ठुकराओ';

  @override
  String get deviceLoginScanScreenSuccess =>
      'तुम्हारे दूसरे डिवाइस पर साइन इन हो गया';

  @override
  String get deviceLoginScanScreenGenericError =>
      'मंज़ूर नहीं हो सका, फिर से कोशिश करो';

  @override
  String get authErrorDeviceLoginInvalid => 'यह कोड सही नहीं है।';

  @override
  String get authErrorDeviceLoginExpired =>
      'इस कोड का समय खत्म हो गया। दूसरे डिवाइस पर नया कोड लो।';

  @override
  String get deviceLoginScanScreenDeniedConfirmation =>
      'साइन-इन अनुरोध ठुकरा दिया गया';

  @override
  String get roomAdminRoleAdmin => 'एडमिन';

  @override
  String get roomAdminActionViewProfile => 'प्रोफ़ाइल देखें';

  @override
  String get roomAdminActionPromote => 'एडमिन बनाएँ';

  @override
  String get roomAdminActionPromoteSub =>
      'वे न्योता भेज सकेंगे, सदस्य हटा सकेंगे और ग्रुप बदल सकेंगे';

  @override
  String get roomAdminActionDemote => 'एडमिन हटाएँ';

  @override
  String get roomAdminActionDemoteSub =>
      'वे सदस्य के तौर पर ग्रुप में बने रहेंगे';

  @override
  String get roomAdminActionTransfer => 'मालिकाना हक सौंपें';

  @override
  String get roomAdminActionTransferSub => 'आप एडमिन बने रहेंगे';

  @override
  String get roomAdminActionRemove => 'ग्रुप से हटाएँ';

  @override
  String get roomAdminAddFriendsRow => 'दोस्त जोड़ें';

  @override
  String get roomAdminInviteLinkRow => 'न्योते का लिंक';

  @override
  String get roomAdminJoinRequestsRow => 'जुड़ने की गुज़ारिशें';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return 'ग्रुप $name को सौंपें?';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      'वे मालिक बन जाएँगे और ग्रुप मिटा सकेंगे। आप एडमिन बने रहेंगे, और वापस देना सिर्फ़ उन्हीं के हाथ में होगा।';

  @override
  String get roomAdminTransferConfirmCta => 'सौंपें';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return '$name को हटाएँ?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'उनकी ग्रुप और उसमें मौजूद हर चीज़ तक पहुँच खत्म हो जाएगी। उन्हें दोबारा न्योता दिया जा सकता है, या वे न्योते के लिंक से वापस आ सकते हैं।';

  @override
  String get roomAdminRemoveConfirmCta => 'हटाएँ';

  @override
  String get roomAdminGenericError => 'यह नहीं हो पाया। दोबारा कोशिश करें।';

  @override
  String get roomAdminErrorNotMember => 'अब आप इस ग्रुप में नहीं हैं।';

  @override
  String get roomAdminErrorNotAdmin => 'यह सिर्फ़ एडमिन कर सकते हैं।';

  @override
  String get roomAdminErrorNotOwner => 'यह सिर्फ़ ग्रुप का मालिक कर सकता है।';

  @override
  String get roomAdminErrorNotGroup =>
      'आमने-सामने की चैट में संभालने को कुछ नहीं होता।';

  @override
  String get roomAdminErrorOwnerImmutable =>
      'मालिक की भूमिका सिर्फ़ ग्रुप सौंपने से बदलती है।';

  @override
  String get roomAdminErrorInvitesLocked =>
      'इस ग्रुप में सिर्फ़ एडमिन ही न्योता भेज सकते हैं।';

  @override
  String get roomInviteSheetTitle => 'न्योते का लिंक';

  @override
  String get roomInviteSheetBlurb =>
      'एक लिंक और एक कोड, और दोनों एक ही चीज़ हैं। नया बनाते ही पुराना काम करना बंद कर देता है।';

  @override
  String get roomInviteNoLinkYet =>
      'इस ग्रुप का अभी कोई न्योते का लिंक नहीं है।';

  @override
  String get roomInviteCreateButton => 'लिंक बनाएँ';

  @override
  String get roomInviteRegenerateButton => 'नया लिंक';

  @override
  String get roomInviteRevokeButton => 'लिंक रद्द करें';

  @override
  String get roomInviteCopyLink => 'लिंक कॉपी करें';

  @override
  String get roomInviteCopyCode => 'कोड कॉपी करें';

  @override
  String get roomInviteShare => 'साझा करें';

  @override
  String get roomInviteLinkCopied => 'लिंक कॉपी हो गया।';

  @override
  String get roomInviteCodeCopied => 'कोड कॉपी हो गया।';

  @override
  String get roomInviteRegenerateHeadline => 'नया लिंक बनाएँ?';

  @override
  String get roomInviteRegenerateBody =>
      'मौजूदा लिंक और कोड जहाँ-जहाँ साझा हुए हैं, वहाँ तुरंत काम करना बंद कर देंगे। जो पहले से ग्रुप में हैं वे बने रहेंगे।';

  @override
  String get roomInviteRegenerateConfirm => 'नया लिंक';

  @override
  String get roomInviteRevokeHeadline => 'यह लिंक रद्द करें?';

  @override
  String get roomInviteRevokeBody =>
      'जब तक आप दूसरा नहीं बनाते, लिंक से कोई नया नहीं जुड़ सकेगा। जो पहले से ग्रुप में हैं वे बने रहेंगे।';

  @override
  String get roomInviteRevokeConfirm => 'रद्द करें';

  @override
  String get roomInviteLimitsLabel => 'सीमाएँ';

  @override
  String get roomInviteExpiryLabel => 'इतने समय बाद खत्म';

  @override
  String get roomInviteMaxUsesLabel => 'कितनी बार चलेगा';

  @override
  String get roomInviteNeverExpires => 'कभी नहीं';

  @override
  String get roomInviteUnlimited => 'कोई सीमा नहीं';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count घं';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count दिन';
  }

  @override
  String get roomInviteLimitsApplyToNew =>
      'ये उस लिंक पर लागू होंगी जो आप बनाएँगे।';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      'ये अगले लिंक पर लागू होंगी। ऊपर वाला उन्हीं सीमाओं पर रहेगा जिनके साथ वह बना था।';

  @override
  String get roomInvitePermissionsLabel => 'अनुमतियाँ';

  @override
  String get roomInviteMembersCanInviteLabel =>
      'सदस्य दोस्तों को न्योता दे सकते हैं';

  @override
  String get roomInviteMembersCanInviteSub =>
      'बंद करने पर सिर्फ़ एडमिन ही लोगों को ला सकेंगे';

  @override
  String get roomInviteApprovalLabel => 'हर जुड़ने को मंज़ूरी दें';

  @override
  String get roomInviteApprovalSub =>
      'लिंक वाले पहले पूछते हैं, और एडमिन हाँ या ना कहता है';

  @override
  String roomInviteUsesCount(Object count) {
    return '$count बार इस्तेमाल हुआ';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$max में से $used बार';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return '$date को खत्म';
  }

  @override
  String get roomInviteDeadExpired => 'इस लिंक की मियाद खत्म हो गई। नया बनाएँ।';

  @override
  String get roomInviteDeadExhausted =>
      'इस लिंक के इस्तेमाल खत्म हो गए। नया बनाएँ।';

  @override
  String get roomInviteDeadRevoked => 'यह लिंक रद्द कर दिया गया था।';

  @override
  String get roomInviteDeadGeneric => 'यह लिंक अब काम नहीं करता।';

  @override
  String get roomInviteFriendsTitle => 'दोस्त जोड़ें';

  @override
  String get roomInviteFriendsBlurb =>
      'उन्हें न्योता मिलेगा और वे मान या ठुकरा सकते हैं।';

  @override
  String get roomInviteFriendsSearchHint => 'दोस्तों में खोजें';

  @override
  String get roomInviteFriendsInviteButton => 'न्योता';

  @override
  String get roomInviteFriendsSent => 'न्योता भेजा';

  @override
  String get roomInviteFriendsEmpty =>
      'आपके सारे दोस्त या तो यहीं हैं या उन्हें न्योता जा चुका है।';

  @override
  String get roomInviteFriendsNoMatch => 'इससे मिलता कोई दोस्त नहीं।';

  @override
  String get roomInviteFriendsDone => 'हो गया';

  @override
  String get roomJoinRequestsTitle => 'जुड़ने की गुज़ारिशें';

  @override
  String get roomJoinRequestsBlurb =>
      'इन लोगों ने न्योते का लिंक इस्तेमाल किया है। जब तक आप हाँ नहीं कहते, इन्हें ग्रुप का कुछ नहीं दिखता।';

  @override
  String get roomJoinRequestsEmpty => 'कोई इंतज़ार में नहीं है।';

  @override
  String get roomJoinRequestsApprove => 'अंदर लें';

  @override
  String get roomJoinRequestsReject => 'नहीं';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return 'न्योता भेजा · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian => 'अभिभावक का इंतज़ार';

  @override
  String get roomInfoScreenInviteWithdraw => 'वापस लें';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return '$inviter की ओर से · $members सदस्य';
  }

  @override
  String get roomInvitationCardJoin => 'जुड़ें';

  @override
  String get discoverScreenJoinByCodeTitle => 'कोड से जुड़ें';

  @override
  String get discoverScreenJoinByCodeSubtitle =>
      'किसी ने जो ग्रुप साझा किया है उसे खोलें';

  @override
  String get joinInviteTitle => 'ग्रुप से जुड़ें';

  @override
  String get joinInviteBack => 'पीछे';

  @override
  String get joinInviteCodeBlurb =>
      'जो कोड आपके साथ साझा किया गया है वह डालें। पूरा न्योते का लिंक भी यहाँ चलता है।';

  @override
  String get joinInviteCodeLabel => 'न्योते का कोड';

  @override
  String get joinInviteCodeHint => 'लिंक चिपकाएँ या कोड लिखें';

  @override
  String get joinInviteCodeInvalid => 'यह न्योते का कोड नहीं लगता।';

  @override
  String get joinInviteLookupButton => 'आगे बढ़ें';

  @override
  String get joinInviteLookupFailed =>
      'कोड जाँचा नहीं जा सका। कनेक्शन देखकर दोबारा कोशिश करें।';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count सदस्य';
  }

  @override
  String get joinInviteJoinButton => 'ग्रुप से जुड़ें';

  @override
  String get joinInviteRequestButton => 'जुड़ने को कहें';

  @override
  String get joinInviteOpenNote => 'जुड़ते ही आप ग्रुप के संदेश देख पाएँगे।';

  @override
  String get joinInviteApprovalNote =>
      'यहाँ कुछ भी देखने से पहले किसी एडमिन का हाँ कहना ज़रूरी है।';

  @override
  String get joinInviteOpenRoom => 'ग्रुप खोलें';

  @override
  String get joinInvitePendingHeadline => 'एडमिन का इंतज़ार';

  @override
  String get joinInvitePendingBody =>
      'जैसे ही कोई जवाब देगा, आपको सूचना मिल जाएगी।';

  @override
  String get joinInviteBadLinkHeadline => 'यह न्योता काम नहीं करता';

  @override
  String get joinInviteBadLinkBody => 'कोड जाँचें, या नया लिंक माँगें।';

  @override
  String get joinInviteExpiredHeadline => 'इस न्योते की मियाद खत्म हो गई';

  @override
  String get joinInviteExpiredBody =>
      'जिसने न्योता दिया था, उससे नया लिंक माँगें।';

  @override
  String get joinInviteExhaustedHeadline => 'यह न्योता खप चुका है';

  @override
  String get joinInviteExhaustedBody =>
      'इसे गिनी-चुनी बार चलने के लिए बनाया गया था। नया माँगें।';

  @override
  String get joinInviteRevokedHeadline => 'इस न्योते की जगह नया आ गया';

  @override
  String get joinInviteRevokedBody =>
      'एडमिन ने नया लिंक बनाया है। उनसे मौजूदा लिंक माँगें।';

  @override
  String get joinInviteWrongServerHeadline => 'यह न्योता किसी और सर्वर का है';

  @override
  String joinInviteWrongServerBody(Object host) {
    return 'यह $host का है। आपका खाता किसी दूसरे सर्वर पर है, इसलिए यह ग्रुप यहाँ से नहीं खुलेगा।';
  }

  @override
  String get roomInviteErrorNotFound => 'उस न्योते के कोड से कुछ नहीं मिलता।';

  @override
  String get roomInviteErrorRevoked =>
      'उस न्योते की जगह नया आ गया। मौजूदा लिंक माँगें।';

  @override
  String get roomInviteErrorExpired => 'उस न्योते की मियाद खत्म हो गई।';

  @override
  String get roomInviteErrorExhausted => 'वह न्योता खप चुका है।';

  @override
  String get roomInviteErrorAlreadyMember => 'वे पहले से इस ग्रुप में हैं।';

  @override
  String get roomInviteErrorAlreadyInvited =>
      'उन्हें पहले ही न्योता भेजा जा चुका है।';

  @override
  String get roomInviteErrorSelf => 'आप पहले से इस ग्रुप में हैं।';

  @override
  String get roomInviteErrorInvitationGone => 'वह न्योता अब नहीं है।';

  @override
  String get roomInviteErrorRequestPending =>
      'आप पहले ही जुड़ने को कह चुके हैं। एडमिन जवाब देगा।';

  @override
  String get roomInviteErrorRequestGone =>
      'उस गुज़ारिश का जवाब कोई पहले ही दे चुका है।';

  @override
  String get roomInviteErrorRoomPrivate =>
      'इस ग्रुप में सिर्फ़ न्योते से जुड़ा जा सकता है।';

  @override
  String get roomInviteErrorInvalidLimits => 'ये सीमाएँ मान्य नहीं हैं।';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$child $other को $room में बुलाना चाहता है';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$other ने $child को $room में बुलाया है';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      'न्योता चला जाएगा, और फ़ैसला फिर भी सामने वाले का होगा।';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$child को न्योता दिखेगा और वह मान या ठुकरा सकेगा। मंज़ूरी देने पर, मानने की सूरत में उस ग्रुप में जाने की इजाज़त भी मिल जाएगी।';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      'आप खुद को नहीं हटा सकते। इसके बजाय ग्रुप छोड़ दें।';

  @override
  String get roomAdminActionMessage => 'संदेश भेजें';

  @override
  String get roomAdminActionVoiceCall => 'वॉइस कॉल';

  @override
  String get roomAdminActionVideoCall => 'वीडियो कॉल';

  @override
  String get roomAdminYouSuffix => 'आप';

  @override
  String get roomInfoScreenSetPasswordButton => 'सेट करें';

  @override
  String get roomInfoScreenPasswordSetSnackbar => 'पासवर्ड सेट हो गया।';

  @override
  String get roomInfoScreenPasswordSetState => 'पासवर्ड चालू';

  @override
  String get roomInfoScreenPasswordUnsetState => 'कोई पासवर्ड नहीं';

  @override
  String get roomInfoScreenPasswordCancel => 'रद्द करें';

  @override
  String get roomInfoScreenEditSave => 'सहेजें';

  @override
  String get roomInfoScreenEditCancel => 'रद्द करें';

  @override
  String get roomInviteRotatedToast =>
      'नया लिंक बन गया। पुराना अब काम नहीं करता।';

  @override
  String get roomInviteRevokedToast => 'न्योते का लिंक रद्द कर दिया गया।';

  @override
  String get newChatMenuTitle => 'नई चैट';

  @override
  String get newChatMenuCreateTitle => 'रूम बनाएँ';

  @override
  String get newChatMenuCreateSub => 'ग्रुप शुरू करें और लोगों को बुलाएँ';

  @override
  String get newChatMenuJoinTitle => 'कोड से जुड़ें';

  @override
  String get newChatMenuJoinSub => 'आपसे साझा किया ग्रुप खोलें';

  @override
  String get shareSheetTitle => 'किसे भेजना है';

  @override
  String get shareSheetSuggestedHeading => 'सुझाए गए';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अटैचमेंट',
      one: '1 अटैचमेंट',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें $size की सीमा से बड़ी हैं, इसलिए छोड़ दी गईं',
      one: '1 फ़ाइल $size की सीमा से बड़ी है, इसलिए छोड़ दी गई',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return '$title को भेजो';
  }

  @override
  String get settingsScreenRowSpeakerColors => 'बोलने वालों के रंग';

  @override
  String get settingsScreenValueSpeakerOff => 'बंद';

  @override
  String get settingsScreenValueSpeakerName => 'नाम';

  @override
  String get settingsScreenValueSpeakerBubble => 'नाम + बबल';

  @override
  String get speakerColorScreenTitle => 'बोलने वालों के रंग.';

  @override
  String get speakerColorScreenSubtitle => 'नाम पढ़े बिना जानें किसने कहा';

  @override
  String get speakerColorScreenOffLabel => 'बंद';

  @override
  String get speakerColorScreenOffDescription =>
      'कमरे में सब एक ही स्याही से लिखते हैं.';

  @override
  String get speakerColorScreenNameLabel => 'नाम';

  @override
  String get speakerColorScreenNameDescription =>
      'हर किसी को अपना एक रंग मिलता है, नाम पर और चेहरे के चारों ओर.';

  @override
  String get speakerColorScreenBubbleLabel => 'बबल';

  @override
  String get speakerColorScreenBubbleDescription =>
      'रंग उनके संदेशों में भी जाता है, तो लगातार पाँच संदेश भी बताते हैं किसने लिखा.';

  @override
  String get roomInfoScreenSpeakerColorsLabel => 'रंग';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => 'स्वचालित';

  @override
  String get roomInfoScreenSpeakerColorsCustom => 'कस्टम';

  @override
  String get roomColorsScreenTitle => 'कौन कौन है.';

  @override
  String get roomColorsScreenSubtitle => 'हर व्यक्ति का रंग';

  @override
  String get roomColorsScreenOffTitle => 'बोलने वालों के रंग बंद हैं';

  @override
  String get roomColorsScreenOffBody =>
      'अभी सब एक ही स्याही से दिखते हैं. चालू करें और यहाँ हर किसी को अपना रंग मिलेगा.';

  @override
  String get roomColorsScreenOffAction => 'चालू करें';

  @override
  String get roomColorsScreenOffHint =>
      'यह हर कमरे पर लागू होता है, सिर्फ़ इस पर नहीं. सेटिंग्स में भी है.';

  @override
  String get roomColorsScreenAutoChip => 'ऑटो';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return '$name के साथ साझा';
  }

  @override
  String get roomColorsScreenResetAll => 'स्वचालित पर लौटें';

  @override
  String get roomColorsScreenLimitToast =>
      'एक कमरे में इतने ही रंग तय किए जा सकते हैं.';

  @override
  String get roomColorsScreenFailedToast => 'वह रंग सहेजा नहीं जा सका.';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return 'रंग $index';
  }

  @override
  String get devicesScreenTitle => 'आपके डिवाइस';

  @override
  String get devicesScreenSubtitle =>
      'हर जगह जहाँ आपने इस अकाउंट में साइन इन किया है।';

  @override
  String get devicesScreenLoading => 'जाँच रहे हैं…';

  @override
  String get devicesScreenLoadFailed => 'आपके डिवाइस लोड नहीं हो सके';

  @override
  String get devicesScreenThisDevice => 'यही डिवाइस';

  @override
  String get devicesScreenActiveNow => 'अभी सक्रिय';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मिनट पहले',
      one: '1 मिनट पहले',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count घंटे पहले',
      one: '1 घंटा पहले',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन पहले',
      one: '1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications => 'इस पर सूचनाएँ नहीं पहुँच रही हैं';

  @override
  String get devicesScreenRemove => 'हटाएँ';

  @override
  String get devicesScreenRemoveTitle => 'यह डिवाइस हटाएँ?';

  @override
  String devicesScreenRemoveBody(Object name) {
    return '$name साइन आउट हो जाएगा और सूचनाएँ आना बंद हो जाएँगी। जिसके पास वह है उसे दोबारा साइन इन करना होगा।';
  }

  @override
  String get devicesScreenRemoveConfirm => 'हटाएँ';

  @override
  String get devicesScreenRemoveAll => 'बाकी सभी डिवाइस हटाएँ';

  @override
  String get devicesScreenRemoveAllTitle => 'बाकी सभी डिवाइस हटाएँ?';

  @override
  String get devicesScreenRemoveAllBody =>
      'वे सभी साइन आउट हो जाएँगे और सूचनाएँ आना बंद हो जाएँगी। सिर्फ़ यही डिवाइस साइन इन रहेगा।';

  @override
  String get devicesScreenRemoveAllConfirm => 'सभी हटाएँ';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count डिवाइस हटाए गए',
      one: '1 डिवाइस हटाया गया',
      zero: 'हटाने के लिए कोई और डिवाइस नहीं',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed => 'वह डिवाइस हटाया नहीं जा सका';

  @override
  String get devicesScreenFootnote =>
      'डिवाइस हटाने से वह साइन आउट हो जाता है और उसकी सूचनाएँ रुक जाती हैं। यह तुरंत लागू होता है: वह डिवाइस अगली बार जो भी करने की कोशिश करेगा, उसे लॉगिन स्क्रीन पर भेज देगा।';

  @override
  String get attachmentMenuPollLabel => 'पोल';

  @override
  String get attachmentMenuChecklistLabel => 'सूची';

  @override
  String get attachmentMenuEventLabel => 'आयोजन';

  @override
  String get interactionKindPoll => 'पोल';

  @override
  String get interactionKindQuiz => 'क्विज़';

  @override
  String get interactionKindChecklist => 'सूची';

  @override
  String get interactionKindEvent => 'आयोजन';

  @override
  String get interactionBadgeAnonymous => 'गुमनाम';

  @override
  String get interactionBadgeMultiple => 'कई';

  @override
  String get interactionBadgeClosed => 'बंद';

  @override
  String interactionPercent(int percent) {
    return '$percent%';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names +$count';
  }

  @override
  String get interactionSeeWhoAnswered => 'देखो किसने जवाब दिया';

  @override
  String interactionRemoveItem(String label) {
    return '$label हटाओ';
  }

  @override
  String interactionChoiceSemantics(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count वोट',
      one: '$count वोट',
    );
    return '$label, $_temp0';
  }

  @override
  String get interactionAddItemHint => 'एक चीज़ जोड़ो';

  @override
  String get interactionRetract => 'वापस लो';

  @override
  String get interactionClose => 'बंद करो';

  @override
  String interactionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count वोट',
      one: '$count वोट',
    );
    return '$_temp0';
  }

  @override
  String interactionRsvpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count जवाब',
      one: '$count जवाब',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$total में से $done पूरे';
  }

  @override
  String get interactionNoAnswers => 'कोई जवाब नहीं';

  @override
  String get interactionBeFirst => 'जवाब देने वाले पहले बनो';

  @override
  String interactionFinalResults(String count) {
    return '$count · आख़िरी';
  }

  @override
  String get interactionQuizRight => 'सही';

  @override
  String get interactionQuizWrong => 'बस थोड़ा चूक गए';

  @override
  String interactionEventPast(String when) {
    return '$when · हो चुका';
  }

  @override
  String get interactionRespondentsTitlePoll => 'किसने वोट दिया';

  @override
  String get interactionRespondentsTitleChecklist => 'किसने निशान लगाया';

  @override
  String get interactionRespondentsTitleEvent => 'किसने जवाब दिया';

  @override
  String get interactionRespondentsFailed => 'किसने जवाब दिया, यह नहीं आ सका।';

  @override
  String get interactionRespondentsEmpty => 'अभी तक किसी ने जवाब नहीं दिया।';

  @override
  String get interactionFilterAll => 'सभी';

  @override
  String get interactionRsvpGoing => 'आ रहे हैं';

  @override
  String get interactionRsvpMaybe => 'शायद';

  @override
  String get interactionRsvpNo => 'नहीं आ सकते';

  @override
  String get interactionComposePollTitle => 'नया पोल';

  @override
  String get interactionComposePollTagline => 'रूम से पूछो';

  @override
  String get interactionComposeChecklistTitle => 'नई सूची';

  @override
  String get interactionComposeChecklistTagline =>
      'वह सूची जिस पर सब निशान लगा सकें';

  @override
  String get interactionComposeEventTitle => 'नया आयोजन';

  @override
  String get interactionComposeEventTagline => 'देखो कौन आ रहा है';

  @override
  String get interactionComposeQuestionLabel => 'सवाल';

  @override
  String get interactionComposeQuestionHint => 'तुम क्या पूछ रहे हो?';

  @override
  String get interactionComposeTitleLabel => 'शीर्षक';

  @override
  String get interactionComposeTitleHint => 'यह सूची किस लिए है?';

  @override
  String get interactionComposeEventNameLabel => 'आयोजन';

  @override
  String get interactionComposeEventNameHint => 'क्या हो रहा है?';

  @override
  String get interactionComposeOptionsLabel => 'विकल्प';

  @override
  String get interactionComposeItemsLabel => 'चीज़ें';

  @override
  String interactionComposeOptionHint(int index) {
    return 'विकल्प $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return 'चीज़ $index';
  }

  @override
  String get interactionComposeAddOption => 'विकल्प जोड़ो';

  @override
  String get interactionComposeAddItem => 'चीज़ जोड़ो';

  @override
  String get interactionComposeRemoveRow => 'हटाओ';

  @override
  String get interactionComposeMarkCorrect => 'सही जवाब के तौर पर चुनो';

  @override
  String get interactionComposeMultipleTitle => 'कई जवाब';

  @override
  String get interactionComposeMultipleSub => 'एक से ज़्यादा चुनो';

  @override
  String get interactionComposeAnonymousTitle => 'गुमनाम';

  @override
  String get interactionComposeAnonymousOffSub => 'सबको दिखेगा किसने वोट दिया';

  @override
  String get interactionComposeAnonymousOnSub =>
      'किसी को नहीं दिखेगा किसने वोट दिया';

  @override
  String get interactionComposeQuizTitle => 'क्विज़ मोड';

  @override
  String get interactionComposeQuizSub => 'एक ही सही जवाब, बदल नहीं सकते';

  @override
  String get interactionComposeExplanationLabel => 'वजह';

  @override
  String get interactionComposeExplanationHint =>
      'जवाब देने के बाद दिखेगी (ज़रूरी नहीं)';

  @override
  String get interactionComposeOthersMayCheckTitle =>
      'कोई भी निशान लगा सकता है';

  @override
  String get interactionComposeOthersMayCheckSub => 'सिर्फ़ तुम नहीं';

  @override
  String get interactionComposeOthersMayAddTitle => 'कोई भी जोड़ सकता है';

  @override
  String get interactionComposeOthersMayAddSub => 'सूची बाद में बढ़ सकती है';

  @override
  String get interactionComposeWhenLabel => 'कब';

  @override
  String get interactionComposePickStart => 'शुरुआत चुनो';

  @override
  String get interactionComposePickEnd => 'अंत जोड़ो (ज़रूरी नहीं)';

  @override
  String get interactionComposePlaceLabel => 'जगह';

  @override
  String get interactionComposePlaceHint => 'कहाँ? (ज़रूरी नहीं)';

  @override
  String get interactionComposeSendPoll => 'पोल भेजो';

  @override
  String get interactionComposeSendChecklist => 'सूची भेजो';

  @override
  String get interactionComposeSendEvent => 'आयोजन भेजो';

  @override
  String get interactionComposeErrorPrompt =>
      'पहले लिखो कि तुम क्या पूछ रहे हो।';

  @override
  String interactionComposeErrorOptions(int count) {
    return 'पोल के लिए कम से कम $count विकल्प चाहिए।';
  }

  @override
  String get interactionComposeErrorItems => 'सूची में कम से कम एक चीज़ चाहिए।';

  @override
  String get interactionComposeErrorAnswer => 'बताओ कौन-सा विकल्प सही है।';

  @override
  String get interactionComposeErrorWhen => 'चुनो कि यह कब शुरू होगा।';

  @override
  String get interactionComposeErrorEnd => 'अंत, शुरुआत के बाद होना चाहिए।';

  @override
  String get interactionSendFailed => 'यह भेजा नहीं गया।';

  @override
  String get interactionRefused => 'यह दर्ज नहीं हुआ।';

  @override
  String get messageReceiptsScreenTitle => 'मैसेज की जानकारी';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$total में से $read ने पढ़ा';
  }

  @override
  String get messageReceiptsEmptyState => 'इस रूम में अभी कोई और नहीं है';

  @override
  String get messageReceiptsSectionRead => 'पढ़ा गया';

  @override
  String get messageReceiptsSectionDelivered => 'पहुँचा';

  @override
  String get messageReceiptsSectionSent => 'भेजा गया';

  @override
  String get messageReceiptsSectionHidden => 'कोई रसीद नहीं';

  @override
  String get messageReceiptsStateHidden => 'साझा नहीं';

  @override
  String get messageReceiptsStateWaiting => 'प्रतीक्षा में';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name ने इसे $day को $time बजे पढ़ा';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name को यह $day को $time बजे मिला';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name को यह अभी तक नहीं मिला';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name पढ़ने की रसीदें साझा नहीं करते';
  }

  @override
  String get companionsScreenTitle => 'साथी.';

  @override
  String get companionsScreenSubtitle =>
      'मददगार जो इसी फ़ोन में रहते हैं और कुछ भी कहीं नहीं भेजते';

  @override
  String get companionSebastianTagline => 'संदेश अनुवाद करता है';

  @override
  String get companionSebastianBlurb =>
      'Sebastian किसी दूसरी भाषा में लिखा संदेश पढ़ता है और आपको बताता है कि उसमें क्या लिखा है, यहीं आपके फ़ोन पर, बिना कुछ कहीं भेजे।';

  @override
  String get companionMarloweTagline => 'सामान्य मदद';

  @override
  String get companionMarloweBlurb =>
      'अनुवाद के अलावा हर चीज़ Marlowe संभालता है। अभी एक दिमाग चुन लीजिए, कौशल उसके आसपास आते जाएँगे।';

  @override
  String get companionAssuranceOnDevice => 'पूरी तरह इसी डिवाइस पर चलता है';

  @override
  String get companionAssurancePrivate =>
      'आपके संदेश कभी फ़ोन से बाहर नहीं जाते';

  @override
  String get companionAssuranceOffline => 'बिना नेटवर्क के भी काम करता है';

  @override
  String companionInstallAction(Object size) {
    return 'इंस्टॉल करें · $size';
  }

  @override
  String get companionInstallOneTime => 'एक बार का डाउनलोड, हटाने तक रहेगा';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$total में से $received';
  }

  @override
  String get companionInstallQueued => 'दूसरे डाउनलोड के पूरा होने का इंतज़ार';

  @override
  String get companionInstallCancel => 'रद्द करें';

  @override
  String get companionInstallRetry => 'फिर कोशिश करें';

  @override
  String companionInstallReady(Object name) {
    return '$name तैयार है';
  }

  @override
  String get companionInstallFailedNetwork =>
      'डाउनलोड पूरा नहीं हो सका। कनेक्शन जाँचकर फिर कोशिश करें।';

  @override
  String get companionInstallFailedStorage =>
      'इस डिवाइस में पर्याप्त जगह नहीं है। कुछ जगह खाली करके फिर कोशिश करें।';

  @override
  String get companionInstallFailedUnknown => 'डाउनलोड पूरा नहीं हो सका।';

  @override
  String get companionUnsupportedPlatform =>
      'ऐप के इस वर्शन में साथी अभी उपलब्ध नहीं हैं।';

  @override
  String companionBrainNeedsMemory(String size) {
    return '$size मेमोरी चाहिए';
  }

  @override
  String get sebastianTierSeniorDetail => 'बेहतर अनुवाद';

  @override
  String get sebastianTierJuniorDetail => 'किसी भी फ़ोन पर चलता है';

  @override
  String get sebastianLanguageUnlisted =>
      'यह उसकी भाषाओं में नहीं है, नतीजे कच्चे हो सकते हैं';

  @override
  String get companionStatusNotInstalled => 'इंस्टॉल नहीं है';

  @override
  String get companionStatusOff => 'बंद';

  @override
  String companionStatusTranslatingInto(Object language) {
    return '$language में अनुवाद कर रहा है';
  }

  @override
  String get companionStatusNoBrain => 'अभी कुछ डाउनलोड नहीं हुआ';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count डाउनलोड तैयार',
      one: '1 डाउनलोड तैयार',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty =>
      'कुछ डाउनलोड नहीं हुआ, साथी कोई जगह नहीं ले रहे';

  @override
  String companionStorageUsed(Object size) {
    return 'साथी $size जगह ले रहे हैं';
  }

  @override
  String get companionSectionGeneral => 'सामान्य';

  @override
  String get companionSectionStorage => 'स्टोरेज';

  @override
  String get companionBrainRemove => 'हटाएँ';

  @override
  String companionBrainRemoveTitle(Object name) {
    return '$name हटाएँ?';
  }

  @override
  String companionRemoveTitle(Object name) {
    return '$name को हटाएँ?';
  }

  @override
  String companionRemoveMessage(Object size) {
    return 'इससे $size जगह खाली होगी। आप इसे कभी भी दोबारा डाउनलोड कर सकते हैं।';
  }

  @override
  String get companionRemoveConfirm => 'हटाएँ';

  @override
  String get sebastianEnableLabel => 'Sebastian को अनुवाद करने दें';

  @override
  String get sebastianEnableDetail =>
      'डाउनलोड मिटाए बिना रोकने के लिए बंद करें';

  @override
  String get sebastianLanguageSection => 'इसमें अनुवाद करें';

  @override
  String get sebastianLanguageFollowApp => 'ऐप जैसी ही';

  @override
  String sebastianBrainDetail(Object size) {
    return 'इस डिवाइस पर · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अनुवाद सहेजे गए',
      one: '1 अनुवाद सहेजा गया',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => 'साफ़ करें';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe अभी कुछ नहीं कर सकता। कौशल अभी रास्ते में हैं। अभी आप इतना कर सकते हैं कि एक दिमाग तैयार रखें, ताकि जब वे आएँ तो किसी डाउनलोड का इंतज़ार न करना पड़े।';

  @override
  String get marloweBrainsSection => 'दिमाग';

  @override
  String get marloweBrainsCaption =>
      'जितना बड़ा, उतना बेहतर सोचता है और उतना ही धीमे जवाब देता है। आप एक से ज़्यादा रख सकते हैं और बदल सकते हैं।';

  @override
  String get marloweBrainTierSwift => 'तेज़';

  @override
  String get marloweBrainTierBalanced => 'संतुलित';

  @override
  String get marloweBrainTierDeep => 'गहरा';

  @override
  String get translationSlabShowOriginal => 'मूल दिखाएँ';

  @override
  String get translationSlabFailed => 'इस संदेश का अनुवाद नहीं हो सका।';

  @override
  String get translationSlabRetry => 'फिर कोशिश करें';

  @override
  String translationSlabByCompanion(Object name) {
    return '$name ने अनुवाद किया';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return '$language से';
  }

  @override
  String get messageActionMenuTranslateLabel => 'अनुवाद करें';

  @override
  String get messageActionMenuShowOriginalLabel => 'मूल दिखाएँ';

  @override
  String get roomTranslateTitle => 'इस चैट का अनुवाद करें';

  @override
  String get roomTranslateStopTitle => 'अनुवाद रोकें';

  @override
  String get roomTranslateSectionLabel => 'अनुवाद';

  @override
  String get roomTranslateOnRow => 'इस चैट का अनुवाद हो रहा है';

  @override
  String get roomTranslateOffRow => 'बंद';

  @override
  String get roomTranslateNeedsSetUp => 'Sebastian सेट अप करें';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'Sebastian अनुवाद कर रहा है · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return '$language में पढ़ रहे हैं';
  }

  @override
  String get roomTranslateStop => 'रोकें';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return 'पहले से ही $language में है';
  }

  @override
  String get roomScreenTranslateRoomOffer => 'क्या बाकी चैट का भी अनुवाद करें?';

  @override
  String get roomScreenTranslateRoomOfferAction => 'सब अनुवाद करें';

  @override
  String get settingsScreenCompanionsOff => 'बंद';

  @override
  String get settingsScreenCompanionsUnavailable => 'अनुपलब्ध';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return '$name भी इसका उपयोग करता है';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return '$name भी यही डाउनलोड उपयोग करता है और इसे खो देगा।';
  }

  @override
  String get companionBrainInUse => 'उपयोग में';

  @override
  String companionStatusUsingBrain(Object name) {
    return '$name का उपयोग';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name डाउनलोड होता रहेगा: सेटिंग्स › साथी';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return 'डाउनलोड हो रहा है · $percent%';
  }

  @override
  String get companionInstallPause => 'रोकें';

  @override
  String get companionInstallResume => 'जारी रखें';

  @override
  String get companionInstallDiscard => 'हटाएँ';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return 'रुका हुआ · $total में से $received';
  }

  @override
  String get companionInstallFailedIntegrity =>
      'डाउनलोड की गई फ़ाइल इस वर्शन की अपेक्षा से मेल नहीं खाती। फिर से शुरू किया जा रहा है।';

  @override
  String companionBannerDownloading(
    Object name,
    Object received,
    Object total,
  ) {
    return '$name · $total में से $received';
  }

  @override
  String companionBannerPaused(Object name, Object received, Object total) {
    return '$name रुका हुआ · $total में से $received';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name जाग रहा है…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => 'फिर से अनुवाद करें';

  @override
  String get groupCallScreenShareLabel => 'साझा करें';

  @override
  String get groupCallScreenStopShareLabel => 'साझा करना बंद करें';

  @override
  String get groupCallScreenShareStartingLabel => 'शुरू हो रहा…';

  @override
  String get groupCallScreenRingingLabel => 'घंटी बज रही है…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name अपनी स्क्रीन साझा कर रहे हैं';
  }

  @override
  String get groupCallScreenYouAreSharing => 'आप अपनी स्क्रीन साझा कर रहे हैं';

  @override
  String get groupCallScreenMinimizeLabel => 'छिपाएँ';

  @override
  String get groupCallScreenDrawLabel => 'बनाएँ';

  @override
  String get callScreenControlShare => 'साझा करें';

  @override
  String get callScreenControlStopShare => 'रोकें';

  @override
  String get callScreenControlShareStarting => 'शुरू हो रहा…';

  @override
  String get screenShareStopDrawing => 'ड्रॉइंग बंद करें';

  @override
  String get callScreenControlDraw => 'बनाएँ';

  @override
  String get callScreenControlMinimize => 'छिपाएँ';

  @override
  String get inCallPillOngoingCall => 'कॉल जारी है';

  @override
  String get inCallPillReturn => 'वापस जाएँ';

  @override
  String get inCallPillSharing => 'आपकी स्क्रीन साझा हो रही है';

  @override
  String get inCallPillDrawSemanticLabel => 'साझा स्क्रीन पर बनाएँ';

  @override
  String get inCallPillStopSharingSemanticLabel => 'साझा करना बंद करें';

  @override
  String get screenShareUnsupported =>
      'इस डिवाइस पर स्क्रीन साझा करना उपलब्ध नहीं है';

  @override
  String get screenShareEphemeralWarning =>
      'साझा करते समय कैप्चर सुरक्षा बंद है';

  @override
  String get screenShareNotificationTitle => 'आपकी स्क्रीन साझा हो रही है';

  @override
  String get screenShareNotificationBody => 'कॉल में सभी इसे देख सकते हैं';

  @override
  String get screenShareNotificationStop => 'रोकें';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name पहले से साझा कर रहे हैं';
  }

  @override
  String get screenShareFailed => 'साझा करना शुरू नहीं हो सका';

  @override
  String get screenSharePickerTitle => 'अपनी स्क्रीन साझा करें';

  @override
  String get screenSharePickerScreens => 'स्क्रीन';

  @override
  String get screenSharePickerWindows => 'विंडो';

  @override
  String get screenSharePickerEmpty =>
      'अभी साझा करने को कुछ नहीं। सिस्टम सेटिंग्स में स्क्रीन रिकॉर्डिंग की अनुमति दें और फिर कोशिश करें';

  @override
  String get gameTellFriends => 'दोस्तों को बताएँ';

  @override
  String get gameToldFriends => 'बता दिया';

  @override
  String get gameTellFriendsTitle => 'दोस्तों को बताएँ?';

  @override
  String get gameTellFriendsBody =>
      'उन्हें इस नतीजे की सूचना मिलेगी। यह सिर्फ़ एक बार भेजा जा सकता है।';

  @override
  String get gameTellFriendsCancel => 'अभी नहीं';

  @override
  String get gameTellFriendsConfirm => 'भेजें';

  @override
  String get gameTellFriendsSent => 'भेज दिया, उन्हें पता है';

  @override
  String get gameTellFriendsPrivate =>
      'आपके रोज़ के स्कोर निजी हैं, इसे कोई नहीं देखता';

  @override
  String get gameTellFriendsFailed => 'भेजा नहीं जा सका';

  @override
  String get settingsScreenFriendActivityLabel => 'दोस्तों की गतिविधि';

  @override
  String get settingsScreenFriendActivityOnBody =>
      'जैसे ही वे डालें: पल, पॉइंट और खेल के नतीजे';

  @override
  String get settingsScreenFriendActivityOffBody =>
      'कुछ नहीं। देखने जाएँ तो उनके बोर्ड वहीं हैं';

  @override
  String get searchScreenActionWithGrownUp => 'बड़े के पास';

  @override
  String get newChatMenuSearchHint => 'अपने दोस्तों में खोजो';

  @override
  String get newChatMenuNoFriendsYet =>
      'अभी कोई दोस्त नहीं, खोजो में लोगों को ढूँढो';

  @override
  String get newChatMenuNoFriendsMatch => 'कोई दोस्त मेल नहीं खाता';

  @override
  String get newChatMenuOpenDmFailed => 'वह चैट नहीं खुल सकी, फिर कोशिश करो';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'अपने लोगों में से चुनो';

  @override
  String get childPolicyScreenPickPersonHint => 'नाम या यूज़रनेम खोजो';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'तुम्हारे दोस्तों में जोड़ने को कोई नहीं बचा।\\nकिसी और को खोजो';

  @override
  String get childPolicyScreenPickPersonNoMatch => 'कोई मेल नहीं खाता';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'तुम्हारे दोस्त';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'बाकी सब';

  @override
  String get childPolicyScreenAddRoomLabel => 'रूम जोड़ो';

  @override
  String get childPolicyScreenPickRoomHeading => 'रूम जोड़ो';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'तुम्हारा ही कोई रूम। $name तुरंत शामिल हो जाएगा और जब तक तुम वापस न लो, वहाँ पढ़ और लिख सकेगा।';
  }

  @override
  String get childPolicyScreenPickRoomHint => 'अपने रूम्स में खोजो';

  @override
  String get childPolicyScreenPickRoomEmpty =>
      'जोड़ने के लिए तुम्हारा कोई रूम नहीं बचा';

  @override
  String get childPolicyScreenPickRoomNoMatch => 'कोई रूम मेल नहीं खाता';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name अब $room में है';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'वह रूम नहीं जुड़ सका, फिर कोशिश करो';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'वह रूम इस तरह नहीं जोड़ा जा सकता';

  @override
  String get childPolicyScreenErrorRoomGone => 'वह रूम अब मौजूद नहीं है';

  @override
  String get newChatMenuFriendsHeader => 'दोस्त';

  @override
  String get roomChangeErrorGone =>
      'वह सुझाव अब नहीं है। शायद किसी एडमिन ने जवाब दे दिया।';

  @override
  String get roomChangeErrorNotYours =>
      'सुझाव सिर्फ़ वही वापस ले सकता है जिसने दिया था।';

  @override
  String get roomChangeErrorNoChange => 'अभी वही तो लिखा है।';

  @override
  String get roomChangeErrorMissingValue => 'ऐसे सेव नहीं हो सकता।';

  @override
  String get roomChangeRequestsTitle => 'सुझाव';

  @override
  String get roomChangeRequestsBlurb =>
      'ये मेंबर्स ने सुझाए हैं। तुम्हारे हाँ कहने तक कुछ नहीं बदलेगा।';

  @override
  String get roomChangeRequestsEmpty => 'कोई सुझाव नहीं।';

  @override
  String get roomChangeRequestsApprove => 'लगा दो';

  @override
  String get roomChangeRequestsReject => 'नहीं';

  @override
  String get roomChangeRequestsPhotoLabel => 'नई ग्रुप फ़ोटो';

  @override
  String get roomChangeRequestsNameLabel => 'नया नाम';

  @override
  String get roomChangeRequestsDescriptionLabel => 'नया विवरण';

  @override
  String get roomChangeRequestsUnknownLabel =>
      'एक बदलाव जो यह ऐप अभी दिखा नहीं सकती';

  @override
  String get roomChangeRequestsClearedValue => 'कुछ नहीं (हटा दो)';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name ने सुझाया';
  }

  @override
  String get roomAdminChangeRequestsRow => 'सुझाव';

  @override
  String get roomInfoScreenSuggestNote => 'इसे किसी एडमिन को मंज़ूर करना होगा';

  @override
  String get roomInfoScreenSuggestAvatarNote =>
      'नई फ़ोटो एडमिन मंज़ूर करते हैं';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic => 'ग्रुप फ़ोटो सुझाओ';

  @override
  String get roomInfoScreenSuggestionSentToast => 'एडमिन्स को भेज दिया';

  @override
  String get roomInfoScreenSuggestionAppliedToast =>
      'हो गया, यह ग्रुप तुम बदल सकते हो';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => 'वापस ले लिया';

  @override
  String get roomInfoScreenSuggestionsLabel => 'तुम्हारे सुझाव';

  @override
  String get roomInfoScreenSuggestionPhoto => 'एक नई ग्रुप फ़ोटो';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return 'नाम: $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return 'विवरण: $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => 'एक बदलाव';

  @override
  String get roomInfoScreenSuggestionPending => 'एडमिन का इंतज़ार';

  @override
  String get roomInfoScreenSuggestionWithdraw => 'वापस लो';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name ने नई ग्रुप फ़ोटो सुझाई';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name ने नया नाम सुझाया';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name ने नया विवरण सुझाया';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सुझाव तुम्हारा इंतज़ार कर रहे हैं',
      one: '$count सुझाव तुम्हारा इंतज़ार कर रहा है',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => 'देखो';

  @override
  String get roomSuggestionBannerSemantic =>
      'मेंबर्स के सुझाव, तुम्हारी मंज़ूरी के इंतज़ार में';

  @override
  String get gameInfoPlay => 'खेलो';

  @override
  String get gameInfoContinue => 'जारी रखो';

  @override
  String get gameInfoSeeResult => 'अपना नतीजा देखो';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return '$total में से $delivered तक पहुँचा';
  }

  @override
  String get messageReceiptsSentLabel => 'भेजा';

  @override
  String messageReceiptsSemanticDeliveredThenRead(
    Object deliveredDay,
    Object deliveredTime,
    Object name,
    Object readDay,
    Object readTime,
  ) {
    return '$name को यह $deliveredDay को $deliveredTime बजे मिला और $readDay को $readTime बजे पढ़ा';
  }

  @override
  String get messageReceiptsStampRead => 'पढ़ा';

  @override
  String get messageReceiptsStampDelivered => 'पहुँचा';

  @override
  String get roomInviteCustom => 'अपना चुनो';

  @override
  String roomInviteCustomHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count घंटे',
      one: '$count घंटा',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दिन',
      one: '$count दिन',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बार',
      one: '$count बार',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => 'घंटे';

  @override
  String get roomInviteUnitDays => 'दिन';

  @override
  String get roomInviteStepperIncrease => 'बढ़ाओ';

  @override
  String get roomInviteStepperDecrease => 'घटाओ';

  @override
  String get recordsLabel => 'अब तक के रिकॉर्ड';

  @override
  String get recordsBlurb => 'अब तक का सबसे बढ़िया: तुम और तुम्हारे दोस्त';

  @override
  String recordsYourBest(Object value) {
    return 'तुम्हारा $value';
  }

  @override
  String get recordsNoneYet => 'अभी कोई नहीं';

  @override
  String get recordsEmpty => 'कोई भी गेम हल करो, तुम्हारा बेस्ट यहाँ दिखेगा।';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count बार हल',
      one: '$count बार हल',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return '$date को बना';
  }

  @override
  String recordsReactSemantic(Object name) {
    return '$name के रिकॉर्ड पर रिएक्ट करो';
  }

  @override
  String get recordsReactFailed => 'रिएक्ट नहीं हो पाया';

  @override
  String get recordsLoadFailed => 'रिकॉर्ड लोड नहीं हो पाए';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game: $name का रिकॉर्ड $value';
  }

  @override
  String get appearanceLabel => 'रूप';

  @override
  String get appearanceMatchDevice => 'डिवाइस जैसा';

  @override
  String get appearanceMatchDeviceSub =>
      'दिन में लाइट, रात में डार्क, तुम्हारे फ़ोन के साथ';

  @override
  String get appearanceOneTheme => 'एक ही थीम';

  @override
  String get appearanceOneThemeSub => 'पूरे दिन एक जैसा लुक';

  @override
  String get appearanceLightSlot => 'लाइट मोड';

  @override
  String get appearanceDarkSlot => 'डार्क मोड';

  @override
  String get appearanceNow => 'अभी';

  @override
  String appearanceAutoValue(Object name) {
    return 'ऑटो · $name';
  }

  @override
  String get themeScreenAssignHint =>
      'लाइट या डार्क मोड में लगाने के लिए थीम पर टैप करो · पूरे प्रीव्यू के लिए ⛶';

  @override
  String get themeScreenCarouselUseLight => 'लाइट मोड में लगाओ';

  @override
  String get themeScreenCarouselUseDark => 'डार्क मोड में लगाओ';

  @override
  String get themeScreenCarouselIsLight => 'तुम्हारी लाइट थीम';

  @override
  String get themeScreenCarouselIsDark => 'तुम्हारी डार्क थीम';

  @override
  String get onboardingThemeTitle => 'इसे अपना बनाओ।';

  @override
  String get onboardingThemeBody =>
      'एक लुक चुनो। सेटिंग्स में कभी भी बदल सकते हो।';

  @override
  String get onboardingThemeYourTheme => 'तुम्हारी थीम';

  @override
  String get onboardingThemeContinue => 'आगे बढ़ो';

  @override
  String get dropHintNoTarget => 'भेजने के लिए किसी चैट पर छोड़ें';

  @override
  String get dropNothingToSend => 'यहाँ कुछ भी भेजा नहीं जा सकता';

  @override
  String dropSendPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ोटो भेजें',
      one: 'फ़ोटो भेजें',
    );
    return '$_temp0';
  }

  @override
  String dropSendVideos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count वीडियो भेजें',
      one: 'वीडियो भेजें',
    );
    return '$_temp0';
  }

  @override
  String dropSendAudio(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ऑडियो भेजें',
      one: 'ऑडियो भेजें',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें भेजें',
      one: 'फ़ाइल भेजें',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम भेजें',
      one: 'आइटम भेजें',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => 'संदेश में जोड़ें';

  @override
  String get dropSendLink => 'लिंक जोड़ें';

  @override
  String dropTargetTo(String name) {
    return '$name को';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें $size से बड़ी हैं',
      one: '1 फ़ाइल $size से बड़ी है',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => 'फ़ोल्डर नहीं भेजे जा सकते';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count खाली फ़ाइलें छोड़ी जा रही हैं',
      one: 'एक खाली फ़ाइल छोड़ी जा रही है',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => 'यहाँ अटैचमेंट की अनुमति नहीं है';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलों के रूप में भेजे जाएंगे',
      one: 'फ़ाइल के रूप में भेजा जाएगा',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count हर डिवाइस पर नहीं दिखेंगे',
      one: 'हर डिवाइस पर नहीं दिखेगा',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => 'फ़ोटो';

  @override
  String get dropKindVideo => 'वीडियो';

  @override
  String get dropKindAudio => 'ऑडियो';

  @override
  String get dropKindFile => 'फ़ाइल';

  @override
  String get dropKindFolder => 'फ़ोल्डर';

  @override
  String get dropKindText => 'टेक्स्ट';

  @override
  String get dropKindLink => 'लिंक';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें इस भेजने में नहीं समाईं',
      one: '1 फ़ाइल इस भेजने में नहीं समाई',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed => 'यह नहीं हो सका। फिर कोशिश करें।';

  @override
  String get expressionBackspace => 'मिटाएँ';

  @override
  String get expressionCreateSticker => 'स्टिकर बनाएँ';

  @override
  String get expressionDeleteSticker => 'मेरे स्टिकर से हटाएँ';

  @override
  String get expressionFavorite => 'पसंदीदा में जोड़ें';

  @override
  String get expressionFavorited => 'पसंदीदा में जोड़ दिया';

  @override
  String get expressionFavorites => 'पसंदीदा';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF: $title';
  }

  @override
  String get expressionLoadFailed => 'लोड नहीं हो सका। अपना कनेक्शन जाँचें।';

  @override
  String get expressionMediaNotAllowed =>
      'आपकी फ़ैमिली सेटिंग्स तस्वीरें भेजने की अनुमति नहीं देतीं।';

  @override
  String get expressionMyStickers => 'मेरे स्टिकर';

  @override
  String get expressionNoFavorites =>
      'पसंदीदा में जोड़ने के लिए किसी GIF या स्टिकर को दबाकर रखें।';

  @override
  String get expressionNoRecents => 'आपके भेजे GIF और स्टिकर यहाँ दिखेंगे।';

  @override
  String get expressionNoResults => 'कोई नतीजा नहीं';

  @override
  String get expressionNoStickers => 'यहाँ अभी कोई स्टिकर नहीं है।';

  @override
  String get expressionOpenPanel => 'इमोजी, GIF और स्टिकर';

  @override
  String get expressionOptionsHint => 'विकल्प दिखाएँ';

  @override
  String expressionPackCredit(String author, String license) {
    return 'आर्ट: $author · $license';
  }

  @override
  String get expressionPlayGifHint => 'चलाएँ';

  @override
  String get expressionRecent => 'हाल के';

  @override
  String get expressionReport => 'रिपोर्ट करें';

  @override
  String get expressionReported => 'शुक्रिया, रिपोर्ट कर दिया गया है।';

  @override
  String get expressionRetry => 'फिर कोशिश करें';

  @override
  String get expressionSearchKlipy => 'KLIPY पर खोजें';

  @override
  String get expressionShowKeyboard => 'कीबोर्ड दिखाएँ';

  @override
  String get expressionSuggestionsLabel => 'स्टिकर सुझाव';

  @override
  String get expressionTabEmoji => 'इमोजी';

  @override
  String get expressionTabGifs => 'GIF';

  @override
  String get expressionTabStickers => 'स्टिकर';

  @override
  String get expressionTrending => 'ट्रेंडिंग';

  @override
  String get expressionUnfavorite => 'पसंदीदा से हटाएँ';

  @override
  String get expressionUnfavorited => 'पसंदीदा से हटा दिया';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return 'स्टिकर $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel => 'GIF और स्टिकर अपने-आप चलाएँ';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      'जब तक आप टैप न करें, ये रुके रहते हैं। डेटा बचता है।';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'GIF और एनिमेटेड स्टिकर अपने-आप चलते हैं। मोशन कम करें इन्हें रोक देता है।';

  @override
  String get settingsStickerSuggestionsBody =>
      'सिर्फ़ एक इमोजी टाइप करने पर मैसेज फ़ील्ड के ऊपर मिलते-जुलते स्टिकर दिखते हैं।';

  @override
  String get settingsStickerSuggestionsLabel => 'स्टिकर सुझाव';

  @override
  String get stickerMakerEmojiLabel => 'यह कौन-सा इमोजी है?';

  @override
  String get stickerMakerFailed => 'स्टिकर सेव नहीं हो सका। फिर कोशिश करें।';

  @override
  String get stickerMakerMoreEmoji => 'और इमोजी';

  @override
  String get stickerMakerPreview => 'स्टिकर प्रीव्यू';

  @override
  String get stickerMakerRemoveBackground => 'बैकग्राउंड हटाएँ';

  @override
  String get stickerMakerSave => 'सेव करें';

  @override
  String get stickerMakerSaved => 'स्टिकर मेरे स्टिकर में जोड़ दिया गया';

  @override
  String get stickerMakerShape => 'आकार';

  @override
  String get stickerMakerShapeCircle => 'गोल';

  @override
  String get stickerMakerShapeOriginal => 'ओरिजिनल';

  @override
  String get stickerMakerShapeRounded => 'गोल कोनों वाला चौकोर';

  @override
  String get stickerMakerTitle => 'नया स्टिकर';

  @override
  String get stickerMakerTooMany =>
      'आप स्टिकर की सीमा तक पहुँच गए हैं। जगह बनाने के लिए एक हटाएँ।';

  @override
  String get expressionExpandPanel => 'पैनल बड़ा करें';

  @override
  String get expressionCollapsePanel => 'पैनल छोटा करें';

  @override
  String get expressionPackStore => 'स्टिकर पैक';

  @override
  String get expressionPackSearchHint => 'स्टिकर पैक खोजें';

  @override
  String get expressionPacksAdded => 'जोड़े गए';

  @override
  String get expressionPacksMore => 'और पैक';

  @override
  String get expressionPackAdd => 'जोड़ें';

  @override
  String get expressionPackRemove => 'हटाएँ';

  @override
  String expressionPackStickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count स्टिकर',
      one: '1 स्टिकर',
    );
    return '$_temp0';
  }

  @override
  String get expressionNoPacksFound => 'कोई पैक नहीं मिला';

  @override
  String get expressionAllPacksAdded => 'सारे पैक जोड़े जा चुके हैं।';

  @override
  String expressionPackReorder(String title) {
    return '$title का क्रम बदलें';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return '“$title” पैक जोड़ें';
  }

  @override
  String expressionPackAddedToast(String title) {
    return '“$title” स्टिकर में जोड़ दिया गया';
  }

  @override
  String get expressionPacksFromKlipy => 'KLIPY से और स्टिकर';

  @override
  String expressionSearchKlipyFor(String query) {
    return 'KLIPY पर “$query” खोजें';
  }

  @override
  String get expressionHideKeyboard => 'कीबोर्ड छिपाएँ';

  @override
  String get expressionSearchStickers => 'स्टिकर खोजें';

  @override
  String get expressionYourStickers => 'आपके स्टिकर';

  @override
  String get chatListYesterday => 'कल';

  @override
  String get roomLayoutScreenCardsLayoutLabel => 'कार्ड';

  @override
  String get roomLayoutScreenCardsLayoutDescription =>
      'हर रूम अपने कार्ड में, हर जानकारी साफ़ लिखी हुई।';

  @override
  String get homeScreenTitle => 'चैट';

  @override
  String get glassScreenNativeLabel => 'iOS लिक्विड ग्लास';

  @override
  String get glassScreenNativeOnBody =>
      'टैब बार iOS खुद बनाता है। नीचे के स्लाइडर बाकी ऐप को ट्यून करते हैं।';

  @override
  String get glassScreenNativeOffBody =>
      'MonkeyHub हर जगह अपना ग्लास खुद बनाता है, जिसे नीचे के स्लाइडर ट्यून करते हैं।';

  @override
  String get glassScreenHeading => 'ग्लास';

  @override
  String get glassStyleHeader => 'स्टाइल';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody =>
      'Apple का अपना ग्लास, जिसे iOS बनाता है। ऐप के बटन भी उसी से मेल खाते हैं।';

  @override
  String get glassStyleFrostedTitle => 'फ़्रॉस्टेड';

  @override
  String get glassStyleFrostedBody =>
      'MonkeyHub का अपना ग्लास। हर सेटिंग खुद तय करें।';

  @override
  String get glassStyleRecommended => 'सुझाया गया';

  @override
  String get glassStyleLiquidFooter =>
      'कुछ ट्यून करने की ज़रूरत नहीं: ब्लर, रंगत और रोशनी iOS तय करता है। ग्लास खुद बनाने के लिए फ़्रॉस्टेड चुनें।';

  @override
  String get acctSectionPrivacy => 'गोपनीयता';

  @override
  String get acctSectionAccount => 'खाता';

  @override
  String get acctSectionFamily => 'परिवार';

  @override
  String get acctSectionThisPhone => 'यह फ़ोन';

  @override
  String get acctRowVisibility => 'प्रोफ़ाइल दृश्यता';

  @override
  String get acctRowBlocked => 'ब्लॉक किए गए उपयोगकर्ता';

  @override
  String get acctRowApprovals => 'स्वीकृतियाँ';

  @override
  String get acctNothingWaiting => 'कुछ बाकी नहीं';

  @override
  String get acctRowLinked => 'लिंक किए गए खाते';

  @override
  String get acctRowScanToSignIn => 'साइन इन के लिए स्कैन करें';

  @override
  String get acctRowSetUpRecovery => 'रिकवरी वाक्यांश सेट करें';

  @override
  String get acctRowChangeRecovery => 'रिकवरी वाक्यांश बदलें';

  @override
  String get acctSignOut => 'साइन आउट';

  @override
  String get acctDeleteAccount => 'खाता हटाएँ';

  @override
  String get acctConfirmDelete => 'हटाने के लिए फिर से टैप करें';

  @override
  String get acctHandPhoneBack => 'यह फ़ोन वापस सौंपें';

  @override
  String get acctMyGrownUps => 'मेरे बड़े';

  @override
  String get acctActionMessage => 'संदेश';

  @override
  String get acctActionAddFriend => 'जोड़ें';

  @override
  String get acctActionRequested => 'भेजा गया';

  @override
  String get acctActionAccept => 'स्वीकारें';

  @override
  String get acctActionNotAccepting => 'बंद';

  @override
  String get acctActionUnfriend => 'हटाएँ';

  @override
  String get acctActionBlock => 'ब्लॉक';

  @override
  String get acctActionReport => 'रिपोर्ट';

  @override
  String get acctStatusFriends => 'आप मित्र हैं';

  @override
  String get acctStatusRequestSent => 'अनुरोध भेजा गया';

  @override
  String get acctStatusWantsToConnect => 'आपसे मित्रता करना चाहते हैं';

  @override
  String get acctStatusNotConnected => 'आप जुड़े नहीं हैं';

  @override
  String get acctPresenceOnline => 'ऑनलाइन';

  @override
  String get acctPresenceAway => 'दूर';

  @override
  String get acctPresenceOffline => 'ऑफ़लाइन';

  @override
  String get acctProfilePhoto => 'प्रोफ़ाइल फ़ोटो';

  @override
  String get acctSaveToPhotos => 'फ़ोटो में सहेजें';

  @override
  String get acctTakeSelfie => 'सेल्फ़ी लें';

  @override
  String get acctChooseFromLibrary => 'लाइब्रेरी से चुनें';

  @override
  String get acctCancel => 'रद्द करें';

  @override
  String get acctSave => 'सहेजें';

  @override
  String get acctChange => 'बदलें';

  @override
  String get acctNotNow => 'अभी नहीं';

  @override
  String get acctAddEmail => 'ईमेल जोड़ें';

  @override
  String get acctEditNameTitle => 'नाम बदलें';

  @override
  String get acctAddNameTitle => 'अपना नाम जोड़ें';

  @override
  String get acctEditEmailTitle => 'ईमेल बदलें';

  @override
  String get acctChangeUsernameTitle => 'यूज़रनेम बदलें?';

  @override
  String get onboardingLookTitle => 'इसे अपना बनाएं';

  @override
  String get onboardingLookBody =>
      'एक लुक चुनें। आप इसे कभी भी सेटिंग्स में बदल सकते हैं।';

  @override
  String get onboardingEssentials => 'ज़रूरी';

  @override
  String get onboardingEssentialsSub => 'शांत और नेटिव';

  @override
  String get onboardingCharacters => 'किरदार वाले';

  @override
  String get onboardingCharactersSub => 'वही ऐप, ज़्यादा अंदाज़';

  @override
  String get onboardingLightMode => 'लाइट मोड';

  @override
  String get onboardingDarkMode => 'डार्क मोड';

  @override
  String get onboardingNow => 'अभी';

  @override
  String get onboardingContinue => 'जारी रखें';

  @override
  String get onboardingIconTitle => 'आपका ऐप आइकन';

  @override
  String get onboardingIconBody =>
      'अपना मौजूदा आइकन रखें, उसे अपनी थीम के साथ बदलने दें, या कोई भी चुनें।';

  @override
  String get onboardingIconIosNote =>
      'आइकन बदलने पर iOS हर बार एक छोटा नोटिस दिखाता है।';

  @override
  String get onboardingGetStarted => 'शुरू करें';

  @override
  String get appIconMatchTheme => 'थीम के साथ';

  @override
  String get appIconCurrent => 'मौजूदा';

  @override
  String get appIconSectionCollection => 'MonkeyHub कलेक्शन';

  @override
  String get appIconSectionThemes => 'थीम आइकन';

  @override
  String get appIconScreenTitle => 'ऐप आइकन';

  @override
  String get appIconMatchFooter =>
      '\'थीम के साथ\' आइकन को आपकी डार्क मोड थीम के साथ बदलता है, ताकि दिन भर वह बार-बार न बदले।';

  @override
  String get loginTitleReturning => 'फिर से स्वागत है';

  @override
  String get loginTitleFirst => 'MonkeyHub में स्वागत है';

  @override
  String get loginTitleSignUp => 'अपना खाता बनाएं';

  @override
  String get loginTitleReset => 'अपना पासवर्ड रीसेट करें';

  @override
  String get loginSubtitleSignIn =>
      'जहां छोड़ा था वहीं से जारी रखने के लिए साइन इन करें।';

  @override
  String get loginSubtitleFirst =>
      'साइन इन करें, या कुछ ही सेकंड में खाता बनाएं।';

  @override
  String get loginSubtitleSignUp => 'बस एक यूज़रनेम और पासवर्ड चाहिए।';

  @override
  String get loginSubtitleReset =>
      'अपना 12 शब्दों वाला रिकवरी फ़्रेज़ डालें और नया पासवर्ड चुनें।';

  @override
  String get loginCtaSignIn => 'साइन इन करें';

  @override
  String get loginCtaSignUp => 'खाता बनाएं';

  @override
  String get loginCtaReset => 'पासवर्ड रीसेट करें';

  @override
  String get loginNoAccountPrompt => 'नए हैं? ';

  @override
  String get loginCreateAccountLink => 'खाता बनाएं';

  @override
  String get loginHaveAccountPrompt => 'पहले से खाता है? ';

  @override
  String get loginSignInLink => 'साइन इन करें';

  @override
  String get loginForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get loginChildAccount => 'बच्चे का खाता सेट करें';

  @override
  String get loginBackToSignIn => 'साइन इन पर वापस जाएं';

  @override
  String get loginWithPhone => 'अपने फ़ोन से साइन इन करें';

  @override
  String get loginUsernameField => 'यूज़रनेम';

  @override
  String get loginPasswordField => 'पासवर्ड';

  @override
  String get loginConfirmPasswordField => 'पासवर्ड की पुष्टि करें';

  @override
  String get loginNameField => 'नाम (वैकल्पिक)';

  @override
  String get loginRecoveryPhraseField => 'आपका 12 शब्दों वाला रिकवरी फ़्रेज़';

  @override
  String get loginNewPasswordField => 'नया पासवर्ड';

  @override
  String get roomHeaderStatusOnline => 'ऑनलाइन';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य',
      one: '$count सदस्य',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => 'सेटिंग्स';

  @override
  String get settingsHubAccountHintAdult =>
      'प्रोफ़ाइल, परिवार, जुड़े खाते और गोपनीयता';

  @override
  String get settingsHubAccountHintChild =>
      'प्रोफ़ाइल, गोपनीयता और तुम्हारे बड़े';

  @override
  String get settingsHubSectionGeneral => 'सामान्य';

  @override
  String get settingsHubSectionNotifications => 'सूचनाएँ';

  @override
  String get settingsHubSectionCalls => 'कॉल';

  @override
  String get settingsHubSectionAppearance => 'रूप';

  @override
  String get settingsHubSectionCompanions => 'साथी';

  @override
  String get settingsHubSectionChats => 'चैट';

  @override
  String get settingsHubSectionHelp => 'सहायता और कानूनी';

  @override
  String get settingsHubSectionAdvanced => 'उन्नत';

  @override
  String get settingsHubLanguage => 'भाषा';

  @override
  String get settingsHubCheckForUpdates => 'अपडेट जाँचें';

  @override
  String get settingsHubUpdateAvailable => 'अपडेट उपलब्ध';

  @override
  String get settingsHubShowLinkUrls => 'लिंक के पते दिखाएँ';

  @override
  String get settingsHubShowLinkUrlsSubtitle =>
      'हर लिंक प्रीव्यू के साथ पता दिखाएँ';

  @override
  String get settingsHubPresenceDots => 'दिखाएँ कि कौन ऑनलाइन है';

  @override
  String get settingsHubPresenceDotsSubtitle => 'प्रोफ़ाइल फ़ोटो पर बिंदु';

  @override
  String get settingsHubPush => 'पुश सूचनाएँ';

  @override
  String get settingsHubPushSubtitle => 'नए संदेश, कॉल और अनुरोध';

  @override
  String get settingsHubGameReminders => 'रोज़ाना गेम रिमाइंडर';

  @override
  String get settingsHubGameRemindersSubtitle =>
      'अगर नहीं खेला तो दोपहर में एक याद';

  @override
  String get settingsHubFriendActivity => 'दोस्तों की गतिविधि';

  @override
  String get settingsHubFriendActivitySubtitle =>
      'दोस्तों की खास बातें, पॉइंट और गेम नतीजे';

  @override
  String get settingsHubMenuBar => 'मेन्यू बार आइकन';

  @override
  String get settingsHubMenuBarSubtitle =>
      'मेन्यू बार में अपठित संख्या दिखाता है';

  @override
  String get settingsHubCallStats => 'कॉल आँकड़े दिखाएँ';

  @override
  String get settingsHubCallStatsSubtitle =>
      'कॉल के दौरान रेज़ोल्यूशन, बिटरेट और पिंग';

  @override
  String get settingsHubTheme => 'थीम';

  @override
  String get settingsHubAppIcon => 'ऐप आइकन';

  @override
  String get settingsHubGlass => 'ग्लास';

  @override
  String get settingsHubNavigation => 'नेविगेशन';

  @override
  String get settingsHubMotion => 'मोशन';

  @override
  String get settingsHubChatList => 'चैट सूची';

  @override
  String get settingsHubChatStyle => 'चैट स्टाइल';

  @override
  String get settingsHubBubbleStyle => 'बबल स्टाइल';

  @override
  String get settingsHubSpeakerColors => 'बोलने वालों के रंग';

  @override
  String get settingsHubReplyStyle => 'जवाब स्टाइल';

  @override
  String get settingsHubPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get settingsHubTerms => 'सेवा की शर्तें';

  @override
  String get settingsHubLicence => 'लाइसेंस';

  @override
  String get settingsHubServer => 'सर्वर';

  @override
  String get settingsHubLayoutRows => 'पंक्तियाँ';

  @override
  String get settingsHubLayoutCards => 'कार्ड';

  @override
  String get settingsHubLayoutGrid => 'ग्रिड';

  @override
  String get settingsHubNavTabBar => 'टैब बार';

  @override
  String settingsHubThemeAuto(String name) {
    return 'ऑटो · $name';
  }

  @override
  String get chatListPageRowsSub =>
      'एक चेहरा, एक नाम और आख़िरी संदेश, Messages की तरह।';

  @override
  String get chatListPageCardsSub =>
      'हर रूम अपने कार्ड में, हर जानकारी साफ़ लिखी हुई।';

  @override
  String get chatListPageGridSub =>
      'टाइल्स के दो कॉलम। एक नज़र में ज़्यादा रूम।';

  @override
  String get chatListPageLayoutHeader => 'लेआउट';

  @override
  String get chatListPageFiltersHeader => 'फ़िल्टर';

  @override
  String get chatListPageChips => 'चिप्स';

  @override
  String get chatListPageChipsSub => 'फ़िल्टर की एक पंक्ति, हमेशा एक टैप दूर।';

  @override
  String get chatListPageButton => 'बटन';

  @override
  String get chatListPageButtonSub => 'एक बटन जो ज़रूरत पर फ़िल्टर खोलता है।';

  @override
  String get chatListPageEmptyHeader => 'खाली रूम';

  @override
  String get chatListPagePlain => 'सादा';

  @override
  String get chatListPagePlainSub =>
      'जिस रूम में अभी कुछ नहीं कहा गया, वह सादा रहता है।';

  @override
  String get chatListPageInitial => 'पहला अक्षर';

  @override
  String get chatListPageInitialSub => 'एक बड़ा हल्का अक्षर खाली कोना भरता है।';

  @override
  String get chatListPageEmptyFooter => 'ग्रिड लेआउट पर लागू होता है।';

  @override
  String get chatStylePageFooter =>
      'बातचीत का हेडर और संदेश फ़ील्ड कैसे दिखते हैं।';

  @override
  String get chatStyleClassicSub => 'ठोस हेडर और सपाट संदेश फ़ील्ड।';

  @override
  String get chatStyleCompactSub => 'धुंधले कंट्रोल बातचीत के ऊपर तैरते हैं।';

  @override
  String get bubbleTailedSub =>
      'हर सिलसिले के आख़िरी संदेश पर पूँछ, Messages की तरह।';

  @override
  String get bubbleSoftSub =>
      'कोई पूँछ नहीं। सिलसिला अपने कोनों से जुड़ा रहता है।';

  @override
  String get bubblePillSub => 'हर संदेश पर पूरी तरह गोल कैप्सूल।';

  @override
  String get bubbleSlabSub => 'चौकोर किनारे: तीखे और सोचे-समझे।';

  @override
  String get replyStylePageFooter =>
      'जवाब उस संदेश को कैसे दिखाता है जिसका वह जवाब है।';

  @override
  String get replyClassicSub => 'संदेश के ऊपर रंगीन उद्धरण, WhatsApp की तरह।';

  @override
  String get replyPhantomSub =>
      'मूल संदेश की परछाईं ऊपर तैरती है, एक वक्र से जुड़ी।';

  @override
  String get replyStickySub => 'कोने पर लगा एक छोटा, तिरछा कार्ड।';

  @override
  String get replyComicSub => 'कॉमिक जैसी पूँछ वाला छोटा बबल।';

  @override
  String get motionMatchDevice => 'डिवाइस के अनुसार';

  @override
  String get motionMatchDeviceCalmSub => 'आपका डिवाइस अभी कम मोशन चाहता है।';

  @override
  String get motionMatchDeviceFullSub =>
      'आपका डिवाइस अभी एनिमेशन की अनुमति देता है।';

  @override
  String get motionFullSub => 'हर स्प्रिंग, बहाव और सजावट।';

  @override
  String get motionCalmSub => 'सजावट स्थिर रहती है। बाकी सब वैसा ही चलता है।';

  @override
  String get navigationPageFooter =>
      'चैट, फ़ीड, खोज और सेटिंग्स के बीच कैसे जाएँ।';

  @override
  String get navTabBarSub => 'हमेशा दिखता है, कहीं भी एक टैप में।';

  @override
  String get navOrbSub =>
      'कोने से दबाकर खींचें। एक इशारा जिसकी आदत पड़ जाती है।';

  @override
  String get languageSystemLabel => 'डिवाइस की भाषा';

  @override
  String get languagePageFooter =>
      'मेन्यू और ऐप के संदेश। चैट उसी भाषा में रहती हैं जिसमें लोग लिखते हैं।';

  @override
  String get speakerPageFooter =>
      'ग्रुप चैट में एक नज़र में जानें कौन बोल रहा है।';

  @override
  String get speakerOffSub => 'सब एक ही स्याही में लिखते हैं।';

  @override
  String get speakerNamesSub => 'हर व्यक्ति का नाम और चेहरा अपने रंग में।';

  @override
  String get speakerBubblesSub => 'उनका रंग उनके संदेशों में भी आता है।';

  @override
  String get themePageAutoFooter =>
      'हल्की थीम लाइट मोड में, गहरी थीम डार्क मोड में इस्तेमाल होती हैं।';

  @override
  String get themePageLightMode => 'लाइट मोड';

  @override
  String get themePageDarkMode => 'डार्क मोड';

  @override
  String get themePageEssentials => 'ज़रूरी';

  @override
  String get themePageEssentialsFooter => 'शांत और नेटिव, पाँच रंगों में।';

  @override
  String get themePageCharacters => 'किरदार';

  @override
  String get themePageCharactersFooter =>
      'वही लेआउट, अपनी अलग पहचान के साथ। देखने के लिए किसी थीम को दबाकर रखें।';

  @override
  String get themePageLightBadge => 'लाइट';

  @override
  String get themePageDarkBadge => 'डार्क';

  @override
  String get themePageInUse => 'इस्तेमाल में';

  @override
  String get themePageUseLight => 'लाइट मोड में इस्तेमाल करें';

  @override
  String get themePageUseDark => 'डार्क मोड में इस्तेमाल करें';

  @override
  String themePageUse(String name) {
    return '$name इस्तेमाल करें';
  }

  @override
  String get acctCaptureTitle => 'स्क्रीन कैप्चर सुरक्षा';

  @override
  String get acctCaptureOnIos =>
      'रिकॉर्डिंग और मिररिंग में प्राइवेसी शील्ड दिखती है।';

  @override
  String get acctCaptureOnAndroid => 'स्क्रीनशॉट और रिकॉर्डिंग काले दिखते हैं।';

  @override
  String get acctCaptureOff =>
      'स्क्रीनशॉट और रिकॉर्डिंग सामान्य रूप से काम करते हैं।';

  @override
  String get acctCaptureFooter =>
      'गायब होने वाले संदेशों वाले रूम में यह हमेशा चालू रहता है।';

  @override
  String get acctActionPending => 'लंबित';

  @override
  String get chatSwipePin => 'पिन';

  @override
  String get chatSwipeUnpin => 'अनपिन';

  @override
  String get chatSwipeMute => 'म्यूट';

  @override
  String get chatSwipeUnmute => 'अनम्यूट';

  @override
  String get chatSwipeArchive => 'आर्काइव';

  @override
  String get appearanceMatchDeviceSubtitle =>
      'फ़ोन के साथ: दिन में लाइट, रात में डार्क';

  @override
  String get appearanceOneThemeSubtitle => 'पूरे दिन एक ही लुक';

  @override
  String get riName => 'नाम';

  @override
  String get riDescription => 'विवरण';

  @override
  String get riVisibility => 'कौन इसे ढूँढ सकता है';

  @override
  String get riPublic => 'सार्वजनिक';

  @override
  String get riPublicSub => 'कोई भी इसे डिस्कवर में ढूँढ सकता है';

  @override
  String get riPrivate => 'निजी';

  @override
  String get riPrivateSub => 'केवल आपके आमंत्रित लोग जुड़ सकते हैं';

  @override
  String get riMessageLife => 'संदेश इसके बाद गायब हो जाते हैं';

  @override
  String get riPassword => 'पासवर्ड';

  @override
  String get riRemovePassword => 'पासवर्ड हटाएँ';

  @override
  String get riSetPassword => 'पासवर्ड सेट करें';

  @override
  String get riSharedContent => 'साझा सामग्री';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count सदस्य',
      one: '1 सदस्य',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आमंत्रित',
      one: '1 आमंत्रित',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => 'वापस लें';

  @override
  String get riNotifications => 'सूचनाएँ';

  @override
  String get riTranslation => 'अनुवाद';

  @override
  String get riNameColours => 'नाम के रंग';

  @override
  String get riYouSuggested => 'आपके सुझाव';

  @override
  String get riTakeBack => 'वापस लें';

  @override
  String get riLeaveRoom => 'रूम छोड़ें';

  @override
  String get riLeaving => 'छोड़ रहे हैं…';

  @override
  String get riDeleteRoom => 'रूम हटाएँ';

  @override
  String get riDeleting => 'हटा रहे हैं…';

  @override
  String get riEndConversation => 'बातचीत समाप्त करें';

  @override
  String get riEnding => 'समाप्त कर रहे हैं…';

  @override
  String get riActionCall => 'कॉल';

  @override
  String get riActionVideo => 'वीडियो';

  @override
  String get riActionMute => 'म्यूट';

  @override
  String get riActionUnmute => 'अनम्यूट';

  @override
  String get riActionMedia => 'मीडिया';

  @override
  String get riActionAdd => 'जोड़ें';

  @override
  String get roomHeaderStatusTyping => 'टाइप कर रहे हैं…';

  @override
  String get glassScreenLead => 'पीछे का कितना हिस्सा दिखे।';

  @override
  String get transcriptDayToday => 'आज';

  @override
  String get acctRowDevices => 'डिवाइस';

  @override
  String get acctThisDevice => 'यह डिवाइस';

  @override
  String get acctRemove => 'हटाएँ';

  @override
  String get acctRemoveDeviceTitle => 'यह डिवाइस हटाएँ?';

  @override
  String get acctRemoveAllTitle => 'बाकी सभी डिवाइस हटाएँ?';

  @override
  String get acctRemoveAll => 'सभी हटाएँ';

  @override
  String get acctActiveNow => 'अभी सक्रिय';

  @override
  String get acctLoading => 'लोड हो रहा है…';

  @override
  String get acctDevicesLoadFailed => 'आपके डिवाइस लोड नहीं हो सके।';

  @override
  String get acctNoNotifications => 'सूचनाएँ इस तक नहीं पहुँच रहीं';

  @override
  String get acctBlockedEmpty => 'आपने किसी को ब्लॉक नहीं किया है।';

  @override
  String get acctUnblock => 'अनब्लॉक';

  @override
  String get pvSubtitle => 'तय करें कि दूसरे क्या देखें और आप तक कैसे पहुँचें।';

  @override
  String get pvSectionProfile => 'प्रोफ़ाइल';

  @override
  String get pvSectionMessages => 'संदेश';

  @override
  String get pvSectionPeople => 'लोग';

  @override
  String get pvSectionFeed => 'फ़ीड';

  @override
  String get pvAvatar => 'प्रोफ़ाइल फ़ोटो';

  @override
  String get pvAvatarDesc => 'आपकी फ़ोटो कौन देख सकता है';

  @override
  String get pvOnline => 'ऑनलाइन स्थिति';

  @override
  String get pvOnlineDesc => 'क्या आप अभी सक्रिय दिखते हैं';

  @override
  String get pvLastSeen => 'अंतिम बार देखा गया';

  @override
  String get pvLastSeenDesc => 'आप आख़िरी बार कब थे';

  @override
  String get pvSendReceipts => 'पढ़ने की रसीद भेजें';

  @override
  String get pvSendReceiptsDesc =>
      'दूसरों को दिखाएँ कि आपने उनके संदेश पढ़ लिए हैं';

  @override
  String get pvShowReceipts => 'पढ़ने की रसीद दिखाएँ';

  @override
  String get pvShowReceiptsDesc => 'देखें कि आपके संदेश किसने पढ़े';

  @override
  String get pvShowReceiptsHint =>
      'केवल वही लोग गिने जाते हैं जो पढ़ने की रसीद भेजते हैं।';

  @override
  String get pvFriendRequests => 'मित्रता अनुरोध';

  @override
  String get pvFriendRequestsDesc => 'कौन आपको मित्रता अनुरोध भेज सकता है';

  @override
  String get pvSupervisedTitle => 'इन्हें आपके बड़े सेट करते हैं';

  @override
  String get pvEveryone => 'सभी';

  @override
  String get pvFriends => 'मित्र';

  @override
  String get pvNobody => 'कोई नहीं';

  @override
  String get pvOn => 'चालू';

  @override
  String get pvOff => 'बंद';

  @override
  String get pvAnyone => 'कोई भी';

  @override
  String get pvHighlights => 'मेरे हाइलाइट्स';

  @override
  String get pvHighlightsDesc =>
      'क्या आपकी फ़ोटो और वीडियो दिन भर दोस्तों के बोर्ड पर दिखें';

  @override
  String get pvPuzzle => 'मेरा पहेली स्कोर';

  @override
  String get pvPuzzleDesc =>
      'क्या दोस्त देखें कि दैनिक पहेली में आपने कैसा किया';

  @override
  String get pvPast => 'मेरा पिछला';

  @override
  String get pvPastDesc =>
      'आज हमेशा दोस्तों के साथ साझा होता है। यह उससे पहले का सब खोलता है';

  @override
  String get pvPoints => 'मेरे पॉइंट्स';

  @override
  String get pvPointsDesc => 'क्या आपके दर्ज पॉइंट दोस्तों के बोर्ड पर दिखें';

  @override
  String get roomColorsPageTitle => 'कौन कौन है';

  @override
  String get roomColorsPageHeader => 'हर व्यक्ति किस रंग में बोलता है';

  @override
  String get roomColorsAuto => 'स्वचालित';

  @override
  String get roomColorsReset => 'वापस स्वचालित पर';

  @override
  String get roomColorsOffFooter =>
      'बोलने वालों के रंग बंद हैं। यहाँ चालू करने से हर रूम में चालू हो जाएँगे।';

  @override
  String roomColorsSharedWith(String name) {
    return '$name के साथ साझा';
  }

  @override
  String get settingsScreenValueReplyQuote => 'उद्धरण';

  @override
  String get replyQuoteSub =>
      'मूल संदेश जवाब के बबल के अंदर सबसे ऊपर दिखता है।';

  @override
  String get riTabMedia => 'फ़ोटो और वीडियो';

  @override
  String get riTabFiles => 'फ़ाइलें';

  @override
  String get riTabVoice => 'वॉइस संदेश';

  @override
  String get riTabLinks => 'लिंक';

  @override
  String get riTabSaved => 'सहेजे गए';

  @override
  String get riNone => 'कोई नहीं';

  @override
  String get riSavedNote =>
      'आप जो सहेजते हैं उसे केवल आप देखते हैं। पिन किया गया संदेश उल्टा है: पूरा रूम उसे देखता है।';

  @override
  String get riOwnerNote => 'मेडल इस रूम को बनाने वाले को दर्शाता है।';

  @override
  String get famPair => 'पेयर करें';

  @override
  String get famRelease => 'रिलीज़ करें';

  @override
  String get famSettings => 'सेटिंग्स';

  @override
  String get famAddChild => 'बच्चा जोड़ें';

  @override
  String get famEmptyTitle => 'अभी कोई बच्चा नहीं';

  @override
  String get famOnlineNow => 'अभी ऑनलाइन';

  @override
  String get famNotPaired => 'अभी पेयर नहीं हुआ';

  @override
  String get famJustNow => 'अभी-अभी';

  @override
  String get apprEmptyTitle => 'कुछ बाकी नहीं';

  @override
  String get apprEmptySub => 'सब हो गया।';

  @override
  String get apprNotYet => 'अभी नहीं';

  @override
  String get apprAllow => 'अनुमति दें';

  @override
  String get compGeneral => 'सामान्य';

  @override
  String get compStorage => 'स्टोरेज';

  @override
  String get compTranslateInto => 'इसमें अनुवाद करें';

  @override
  String get compBrain => 'दिमाग';

  @override
  String laUnlinkProvider(String provider) {
    return '$provider अनलिंक करें';
  }

  @override
  String laLinkProvider(String provider) {
    return '$provider लिंक करें';
  }

  @override
  String get laUnlink => 'अनलिंक';

  @override
  String get laLink => 'लिंक करें';

  @override
  String get laLinked => 'लिंक है';

  @override
  String get laNotLinked => 'लिंक नहीं';

  @override
  String rdSignOut(String name) {
    return '$name को साइन आउट करें';
  }

  @override
  String get rpContinue => 'जारी रखें';

  @override
  String get rpCopy => 'कॉपी करें';

  @override
  String get rpSaved => 'मैंने सहेज लिए';

  @override
  String get rpBack => 'वापस';

  @override
  String get rpKeep => 'अभी नहीं, मेरा मौजूदा वाक्यांश रखें';

  @override
  String get childSetupHeadingIos => 'ये कौन हैं?';

  @override
  String get childPairTitleIos => 'नमस्ते!';

  @override
  String get childPairBackIos => 'साइन इन पर वापस जाएँ';

  @override
  String get gamesHubTitle => 'लीडरबोर्ड';

  @override
  String get gamesHubSubtitle => 'आज के विजेता। हर दिन नई पहेलियाँ।';

  @override
  String get gameTellFriendsMessage =>
      'उन्हें इस नतीजे की सूचना मिलेगी। इसे सिर्फ़ एक बार भेजा जा सकता है।';

  @override
  String get deviceLoginScanTitleIos => 'साइन इन के लिए स्कैन करें';

  @override
  String get deviceLoginConfirmTitleIos => 'इस डिवाइस पर साइन इन करें?';

  @override
  String get socialHeroCreateIos => 'बस थोड़ा और';

  @override
  String get socialHeroLinkIos => 'फिर से स्वागत है';

  @override
  String socialSignInLinkIos(String provider) {
    return 'साइन इन करें और $provider लिंक करें';
  }

  @override
  String get serverTitleIos => 'सर्वर';

  @override
  String get serverOnboardingTitleIos => 'एक सर्वर चुनें';

  @override
  String get approvalGateAskIos => 'पूछें';

  @override
  String get friendRequestDraftIntroOutgoingSentence =>
      'कुछ लाइनें भेजो। वो स्वीकार या अस्वीकार कर सकते हैं।';

  @override
  String get requestDeclineIos => 'अस्वीकार';

  @override
  String get joinRequestAllowIos => 'अनुमति दें';

  @override
  String get changeRequestUseIos => 'लागू करें';

  @override
  String get settingsSearchHint => 'सेटिंग्स में खोजें';

  @override
  String settingsSearchNoResults(String query) {
    return '“$query” के लिए कोई नतीजा नहीं';
  }

  @override
  String get settingsSearchAccount => 'खाता';

  @override
  String get settingsHubDiagnostics => 'डायग्नोस्टिक्स';

  @override
  String get settingsHubDiagnosticsSubtitle =>
      'समस्या सुलझाने और बग रिपोर्ट के लिए लॉग';

  @override
  String get settingsHubAdvancedFooter =>
      'समस्या सुलझाने और सेल्फ़-होस्टिंग के लिए। रोज़ इसकी ज़रूरत नहीं।';

  @override
  String get settingsSearchKwLanguage => 'भाषा, अनुवाद, क्षेत्र';

  @override
  String get settingsSearchKwUpdates => 'अपडेट, संस्करण, नया';

  @override
  String get settingsSearchKwLinks => 'लिंक, यूआरएल, पता, प्रीव्यू';

  @override
  String get settingsSearchKwPresence => 'ऑनलाइन, स्थिति, बिंदु, सक्रिय, हरा';

  @override
  String get settingsSearchKwAutoplay => 'जिफ़, एनिमेशन, ऑटोप्ले';

  @override
  String get settingsSearchKwStickers => 'स्टिकर, इमोजी, सुझाव';

  @override
  String get settingsSearchKwPush => 'सूचनाएं, अलर्ट, आवाज़';

  @override
  String get settingsSearchKwGames => 'गेम, रिमाइंडर, रोज़ाना';

  @override
  String get settingsSearchKwFriends => 'दोस्त, गतिविधि, पॉइंट';

  @override
  String get settingsSearchKwVideo => 'वीडियो, कॉल, क्वालिटी, कैमरा';

  @override
  String get settingsSearchKwStats => 'आंकड़े, नेटवर्क, पिंग, डीबग';

  @override
  String get settingsSearchKwTheme => 'थीम, डार्क, लाइट, रंग, रात';

  @override
  String get settingsSearchKwIcon => 'ऐप आइकन, लोगो, होम स्क्रीन';

  @override
  String get settingsSearchKwGlass => 'ग्लास, ब्लर, फ़्रॉस्टेड, पारदर्शिता';

  @override
  String get settingsSearchKwNavigation => 'टैब बार, नेविगेशन, मेनू';

  @override
  String get settingsSearchKwMotion => 'मोशन, एनिमेशन, कम मोशन';

  @override
  String get settingsSearchKwCompanions => 'एआई, असिस्टेंट, अनुवाद, मॉडल';

  @override
  String get settingsSearchKwChatList => 'चैट सूची, पंक्तियां, कार्ड, ग्रिड';

  @override
  String get settingsSearchKwChatStyle => 'चैट स्टाइल, कॉम्पैक्ट, क्लासिक';

  @override
  String get settingsSearchKwBubbles => 'बबल, मैसेज, आकार';

  @override
  String get settingsSearchKwSpeakers => 'नाम, रंग, ग्रुप';

  @override
  String get settingsSearchKwReply => 'जवाब, कोट, थ्रेड';

  @override
  String get settingsSearchKwReport => 'बग, समस्या, फ़ीडबैक, मदद';

  @override
  String get settingsSearchKwLegal => 'प्राइवेसी, शर्तें, कानूनी, लाइसेंस';

  @override
  String get settingsSearchKwServer => 'सर्वर, सेल्फ़-होस्ट, यूआरएल, डेवलपर';

  @override
  String get settingsSearchKwDiagnostics => 'डायग्नोस्टिक्स, लॉग, डीबग, डेवलपर';

  @override
  String get settingsSearchKwPrivacy => 'प्राइवेसी, विज़िबिलिटी, लास्ट सीन';

  @override
  String get settingsSearchKwBlocked => 'ब्लॉक, लोग';

  @override
  String get settingsSearchKwDevices => 'डिवाइस, सेशन, साइन आउट';

  @override
  String get settingsSearchKwLinked => 'एपल, गूगल, साइन इन';

  @override
  String get settingsSearchKwRecovery => 'रिकवरी फ़्रेज़, पासवर्ड, बैकअप';

  @override
  String get settingsSearchKwCapture =>
      'स्क्रीनशॉट, स्क्रीन रिकॉर्डिंग, प्राइवेसी';

  @override
  String get settingsSearchKwFamily => 'परिवार, बच्चा, माता-पिता, मंज़ूरी';

  @override
  String get settingsSearchKwAccount => 'खाता, साइन आउट, डिलीट, ईमेल';

  @override
  String get childPolicyScreenContactStateAllowedTalking => 'बात कर रहे हैं';

  @override
  String get childPolicyScreenContactStateTalking => 'स्वीकृत';

  @override
  String get childPolicyScreenContactStateAllowedNotAdded =>
      'अभी जोड़ा नहीं गया';

  @override
  String get profileScreenSignOutConfirmTitle => 'इस डिवाइस पर साइन आउट करें?';

  @override
  String get profileScreenDeleteAccountConfirmTitle => 'अपना खाता हटाएं?';

  @override
  String get profileScreenDeleteAccountConfirmBody =>
      'आपके मैसेज, फ़ोटो, रूम और दोस्त सब मिट जाएंगे, और आपका यूज़रनेम किसी और के लिए खुला हो जाएगा।';

  @override
  String get glassPresetNameFrosted => 'फ़्रॉस्टेड';

  @override
  String get glassPresetNameClear => 'पारदर्शी';

  @override
  String settingsScreenDiagnosticsCountdown(int count) {
    return 'डायग्नॉस्टिक्स $count में…';
  }

  @override
  String pairingCodeTitlePair(String name) {
    return '$name को पेयर करो';
  }

  @override
  String pairingCodeTitleRelease(String name) {
    return '$name को रिलीज़ करो';
  }

  @override
  String archivedChatsSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चैट',
      one: '$count चैट',
    );
    return '$_temp0';
  }

  @override
  String pinnedListSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count मैसेज',
      one: '$count मैसेज',
    );
    return '$_temp0';
  }

  @override
  String get voiceRecorderScreenTitle => 'वॉइस मैसेज';

  @override
  String get chatTargetSearchHint => 'खोजें';

  @override
  String get marloweBrainTierSwiftDetail => 'तेज़ जवाब, सबसे हल्का डाउनलोड';

  @override
  String get marloweBrainTierBalancedDetail => 'रफ़्तार और गहराई का अच्छा मेल';

  @override
  String get marloweBrainTierDeepDetail =>
      'सबसे सोच-समझकर, सबसे ज़्यादा जगह चाहिए';

  @override
  String get reportFactDeviceId => 'डिवाइस आईडी';

  @override
  String get reportFactUserId => 'यूज़र आईडी';

  @override
  String get reportFactUsername => 'यूज़रनेम';

  @override
  String get reportFactApp => 'ऐप';

  @override
  String get reportFactDevice => 'डिवाइस';

  @override
  String get reportFactSystem => 'सिस्टम';

  @override
  String get reportFactDisplay => 'डिस्प्ले';

  @override
  String get reportFactAppLanguage => 'ऐप की भाषा';

  @override
  String get reportFactSystemLocale => 'सिस्टम लोकेल';

  @override
  String get reportFactLog => 'लॉग';

  @override
  String reportFactLogValue(int count) {
    return '$count इवेंट जुड़े हैं';
  }

  @override
  String reportProblemScreenshotN(int n) {
    return 'स्क्रीनशॉट $n';
  }

  @override
  String reportProblemRemoveScreenshot(int n) {
    return 'स्क्रीनशॉट $n हटाएं';
  }

  @override
  String get reportFactLanguageFromSystem => 'सिस्टम से';

  @override
  String get reportFactLanguageChosen => 'चुनी गई';

  @override
  String get pageSectionSeeAll => 'सभी देखो';

  @override
  String get discoverScreenSeeAllFriendsSemanticLabel => 'सभी दोस्त देखो';

  @override
  String get discoverScreenSeeAllRoomsSemanticLabel => 'अपने सभी रूम देखो';

  @override
  String groupCallScreenRingingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count को घंटी जा रही है',
    );
    return '$_temp0';
  }

  @override
  String photoChromeWhenToday(String time) {
    return 'आज $time बजे';
  }

  @override
  String photoChromeWhenYesterday(String time) {
    return 'कल $time बजे';
  }

  @override
  String photoChromeWhenDate(String date, String time) {
    return '$date, $time बजे';
  }

  @override
  String get photoChromeSaved => 'सेव हो गया';

  @override
  String get photoChromeSaveFailed => 'सेव नहीं हो सका';

  @override
  String get photoChromeShareFailed => 'शेयर नहीं हो सका';

  @override
  String photoChromeForwarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चैट में फ़ॉरवर्ड हो गया',
      one: 'फ़ॉरवर्ड हो गया',
    );
    return '$_temp0';
  }

  @override
  String get photoChromeForwardFailed => 'फ़ॉरवर्ड नहीं हो सका';

  @override
  String get photoChromeDeleteFailed => 'डिलीट नहीं हो सका';

  @override
  String get photoChromeDeleteBody =>
      'यह इसे इस चैट के सभी लोगों के लिए हटा देगा। इसे वापस नहीं लिया जा सकता।';

  @override
  String get roomContentMonthThis => 'इस महीने';

  @override
  String get roomContentMonthLast => 'पिछले महीने';

  @override
  String get gameInfoGoalLabel => 'लक्ष्य';

  @override
  String get gameInfoExampleLabel => 'उदाहरण';

  @override
  String get gameInfoWinLabel => 'कैसे जीतें';

  @override
  String get gameInfoQueensRule4 =>
      'ताज एक-दूसरे को छू नहीं सकते। कोने से भी नहीं।';

  @override
  String get gameInfoQueensExample =>
      'यहाँ एक ताज का मतलब: उसकी पंक्ति, स्तंभ, रंग और आसपास के 8 खानों में कोई और ताज नहीं।';

  @override
  String get gameInfoTangoRule4 =>
      '= का मतलब दोनों खाने एक जैसे। × का मतलब अलग-अलग।';

  @override
  String get gameInfoTangoExample =>
      'सूरज, सूरज, खाली? खाली खाना चाँद ही होगा।';

  @override
  String get gameInfoZipRule4 => 'ऊपर, नीचे, बाएँ या दाएँ चलें। तिरछा नहीं।';

  @override
  String get gameInfoZipRule5 => 'आखिरी नंबर पर खत्म करें।';

  @override
  String get gameInfoZipExample =>
      '1 से 2 जा रहे हैं? ज़रूरत हो तो लंबा रास्ता लें। कोई खाना खाली नहीं रह सकता।';

  @override
  String get gameInfoSudokuExample =>
      'किसी पंक्ति में 1, 2, 4, 5 और 6 हैं? खाली खाना 3 है।';

  @override
  String get gameInfoCodeRule4 => 'पीला: सही चिह्न, गलत जगह।';

  @override
  String get gameInfoCodeRule5 => 'स्लेटी: यह चिह्न कोड में नहीं है।';

  @override
  String get gameInfoCodeExample =>
      'हरा, पीला, स्लेटी, स्लेटी का मतलब: 1 चिह्न सही जगह पर है, 1 कहीं और जाएगा, 2 कोड में नहीं हैं।';

  @override
  String get leaderboardOverall => 'आज';

  @override
  String get leaderboardFooter =>
      'आज हल की गई हर पहेली के लिए 1 पॉइंट। बराबरी पर, जो ज़्यादा बार पहले आया वह आगे।';

  @override
  String get leaderboardNotPlayed => 'अभी तक नहीं खेला';

  @override
  String get leaderboardPlay => 'खेलें';

  @override
  String get leaderboardEmptyTitle => 'आज अभी कोई स्कोर नहीं';

  @override
  String get leaderboardEmptyBody =>
      'एक पहेली हल करें और सूची में सबसे पहले आएँ।';

  @override
  String get pointComposerPickFirst => 'पहले ऊपर से एक चुनें';

  @override
  String get momentStoryNext => 'अगला';

  @override
  String get momentStoryPrevious => 'पिछला';

  @override
  String leaderboardSolved(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      solved,
      locale: localeName,
      other: '$total में से $solved हल',
      zero: 'अभी कुछ हल नहीं',
    );
    return '$_temp0';
  }

  @override
  String leaderboardWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count जीत',
    );
    return '$_temp0';
  }

  @override
  String leaderboardEmptyAction(String game) {
    return '$game खेलें';
  }

  @override
  String get diagCatApi => 'सर्वर कॉल';

  @override
  String get diagCatConnection => 'कनेक्शन';

  @override
  String get diagCatDevice => 'डिवाइस';

  @override
  String get diagCatError => 'गड़बड़ियाँ';

  @override
  String get diagCatFrame => 'धीमे फ़्रेम';

  @override
  String get diagCatLayout => 'लेआउट';

  @override
  String get diagCatLifecycle => 'ऐप की स्थिति';

  @override
  String get diagCatLog => 'लॉग';

  @override
  String get diagCatNav => 'नेविगेशन';

  @override
  String get diagCatNetwork => 'नेटवर्क';

  @override
  String get diagCatSubscription => 'लाइव अपडेट';

  @override
  String get diagSevTrace => 'ट्रेस';

  @override
  String get diagSevDebug => 'डीबग';

  @override
  String get diagSevInfo => 'जानकारी';

  @override
  String get diagSevWarning => 'चेतावनी';

  @override
  String get diagSevError => 'गड़बड़ी';

  @override
  String get diagAll => 'सभी';

  @override
  String get diagSearchHint => 'नाम, ब्योरा, बॉडी खोजो';

  @override
  String get diagSummaryCopied => 'सारांश कॉपी हो गया';

  @override
  String get diagShareLog => 'लॉग शेयर करो';

  @override
  String get diagCopySummary => 'सारांश कॉपी करो';

  @override
  String get diagDeleteAll => 'सब मिटाओ';

  @override
  String get diagUndo => 'वापस लो';

  @override
  String get diagDeleteLogTitle => 'पूरा लॉग मिटाना है?';

  @override
  String get diagDeleteLogBody =>
      'अब तक दर्ज हर इवेंट मिट जाएगा, पिछली बार का लॉग भी। अब से जो होगा, वो हमेशा की तरह दर्ज होगा।';

  @override
  String get diagDelete => 'मिटाओ';

  @override
  String get diagLogDeleted => 'लॉग मिटा दिया';

  @override
  String get diagFilter => 'फ़िल्टर';

  @override
  String get diagMore => 'और';

  @override
  String get diagLatest => 'सबसे नया';

  @override
  String get diagJumpToLatest => 'सबसे नए पर जाओ';

  @override
  String get diagPaused => 'रुका हुआ';

  @override
  String get diagPreparingLog => 'लॉग तैयार हो रहा है…';

  @override
  String get diagEmptyNothingTitle => 'अभी तक कुछ दर्ज नहीं हुआ';

  @override
  String get diagEmptyNothingHint =>
      'ऐप थोड़ी देर इस्तेमाल करो, इवेंट यहाँ दिखेंगे।';

  @override
  String get diagEmptyHiddenTitle => 'अभी तक सिर्फ़ छिपे हुए इवेंट हैं';

  @override
  String get diagEmptyHiddenHint =>
      'देखने के लिए ऊपर किसी धुंधले चिप पर टैप करो, या उसे सभी में वापस लाने के लिए दबाकर रखो।';

  @override
  String get diagEmptyNoMatchTitle => 'कोई इवेंट मेल नहीं खाता';

  @override
  String get diagEmptyNoMatchHint => 'फ़िल्टर हटाने के लिए ऊपर सभी पर टैप करो।';

  @override
  String get diagApply => 'लागू करो';

  @override
  String get diagMinSeverity => 'न्यूनतम गंभीरता';

  @override
  String get diagEverything => 'सब कुछ';

  @override
  String get diagHiddenFromAllHeader => 'सभी से छिपे';

  @override
  String get diagHiddenFromAllFooter =>
      'चिप वाली लाइन में चुने जाने तक सभी से बाहर रहते हैं। वही स्विच पाने के लिए वहाँ किसी चिप को दबाकर रखो।';

  @override
  String get diagCollapseRepeats => 'दोहराव समेटो';

  @override
  String get diagCollapseRepeatsSubtitle =>
      'एक ही इवेंट की लगातार कड़ी को एक लाइन में समेटो';

  @override
  String get diagResetFilter => 'फ़िल्टर रीसेट करो';

  @override
  String get diagBodyTruncated => 'दर्ज करते समय बॉडी काट दी गई';

  @override
  String get diagCopyEvent => 'इवेंट कॉपी करो';

  @override
  String get diagEventCopied => 'इवेंट कॉपी हो गया';

  @override
  String diagHiddenFromAll(String category) {
    return '$category सभी से छिपाया';
  }

  @override
  String diagBackInAll(String category) {
    return '$category फिर से सभी में';
  }

  @override
  String diagChipSemanticLabel(String category, int count) {
    return '$category, $count';
  }

  @override
  String diagChipHiddenSemanticLabel(String category, int count) {
    return '$category, $count, सभी से छिपा';
  }

  @override
  String diagEventCount(int shown, int total) {
    return '$total में से $shown इवेंट';
  }

  @override
  String diagDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पुराने इवेंट हटा दिए गए, लॉग बीच कहानी से शुरू होता है',
    );
    return '$_temp0';
  }

  @override
  String diagRepeatSpan(int count, String seconds) {
    return '$seconds सेकंड में ×$count';
  }

  @override
  String roomContentTabSemantic(String count, String label) {
    return '$label, $count आइटम';
  }

  @override
  String get mapAppsTitle => 'मैप्स';

  @override
  String get mapAppsChoose => 'लोकेशन इसमें खोलें';

  @override
  String get mapAppsRemember => 'डिफ़ॉल्ट के रूप में इस्तेमाल करें';

  @override
  String get mapAppsAskEveryTime => 'हर बार पूछें';

  @override
  String get mapAppsBrowser => 'ब्राउज़र';

  @override
  String get mapAppsSubtitle => 'शेयर की गई लोकेशन कहाँ खुले, चुनें।';

  @override
  String get mapAppsUnavailable =>
      'आपका डिफ़ॉल्ट मैप ऐप उपलब्ध नहीं है। दूसरा चुनें।';

  @override
  String get mapAppsNoInstalled =>
      'कोई समर्थित मैप ऐप नहीं मिला। आप ब्राउज़र इस्तेमाल कर सकते हैं।';

  @override
  String get interactionAnswersSearch => 'लोग या जवाब खोजें';

  @override
  String get interactionFilterEmpty => 'इस फ़िल्टर से कोई जवाब मेल नहीं खाता।';

  @override
  String get interactionRetry => 'फिर कोशिश करें';

  @override
  String get cameraEditorScreenCaptionHint => 'कैप्शन जोड़ें…';

  @override
  String get cameraEditorScreenCaptionViewOnceHint =>
      'एक बार देखी जाने वाली फ़ोटो पर कैप्शन नहीं';

  @override
  String get cameraEditorScreenAddFromCameraSemanticLabel => 'एक और फ़ोटो लें';

  @override
  String cameraEditorScreenDiscardAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ोटो हटाएँ?',
      one: 'यह फ़ोटो हटाएँ?',
    );
    return '$_temp0';
  }

  @override
  String get cameraEditorScreenDiscardAllBody =>
      'आपके संपादन और कैप्शन खो जाएँगे।';

  @override
  String get cameraEditorScreenDiscardAllConfirm => 'हटाएँ';

  @override
  String get galleryTrayRecentsTitle => 'हाल ही के';

  @override
  String get galleryTrayBackToCameraLabel => 'कैमरा पर वापस जाएँ';

  @override
  String get galleryTrayAllPhotosLabel => 'सभी फ़ोटो';

  @override
  String get galleryTrayHandleLabel => 'हाल की फ़ोटो';

  @override
  String get galleryTrayAllowPrompt => 'अपनी हाल की फ़ोटो यहाँ देखें';

  @override
  String get galleryTrayAllowButton => 'अनुमति दें';

  @override
  String get galleryTrayDeniedPrompt => 'फ़ोटो एक्सेस बंद है';

  @override
  String get galleryTraySettingsButton => 'सेटिंग्स';

  @override
  String get galleryTrayLimitedNote =>
      'केवल आपकी अनुमति वाली फ़ोटो दिख रही हैं';

  @override
  String get galleryTrayManageButton => 'प्रबंधित करें';

  @override
  String get galleryTrayEmpty => 'अभी कोई फ़ोटो नहीं';

  @override
  String galleryTrayAddSelectedButton(int count) {
    return 'जोड़ें ($count)';
  }

  @override
  String get galleryTrayCancelSelectionLabel => 'चयन रद्द करें';

  @override
  String galleryTraySelectedTitle(int count) {
    return '$count चुने गए';
  }

  @override
  String galleryTrayPhotoLabel(int index) {
    return 'फ़ोटो $index';
  }

  @override
  String get reactionLimitTitle => 'आप रिएक्शन की सीमा तक पहुँच गए हैं';

  @override
  String reactionLimitMessageBody(int limit) {
    return 'रफ़्तार, सुकून और हर इमोजी को चमकने देने के लिए, आप एक मैसेज पर ज़्यादा से ज़्यादा $limit रिएक्शन जोड़ सकते हैं, इससे ज़्यादा नहीं। नए के लिए जगह बनाने को कोई एक वापस लें।';
  }

  @override
  String reactionLimitHighlightBody(int limit) {
    return 'हाइलाइट्स पर हर व्यक्ति $limit रिएक्शन दे सकता है, ताकि हर रिएक्शन का मतलब बना रहे। नए पसंदीदा के लिए कोई एक वापस लें।';
  }

  @override
  String get reactionLimitDismiss => 'ठीक है';

  @override
  String get reactionPickerYoursLabel => 'आपके रिएक्शन';

  @override
  String reactionPickerTakeBackSemantic(String emoji) {
    return 'अपना $emoji रिएक्शन हटाएँ';
  }

  @override
  String get momentCommentsTitle => 'कमेंट';

  @override
  String momentCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count कमेंट',
      one: '1 कमेंट',
      zero: 'कमेंट',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentsEmptyTitle => 'अभी कोई कमेंट नहीं';

  @override
  String get momentCommentsEmptyBody =>
      'कुछ शब्दों, एक स्टिकर या एक GIF से बातचीत शुरू करें।';

  @override
  String get momentCommentHint => 'कमेंट जोड़ें…';

  @override
  String momentCommentReplyHint(String name) {
    return '$name को जवाब दें…';
  }

  @override
  String momentCommentReplyingTo(String name) {
    return '$name को जवाब दे रहे हैं';
  }

  @override
  String get momentCommentCancelReply => 'जवाब रद्द करें';

  @override
  String get momentCommentReply => 'जवाब दें';

  @override
  String momentCommentViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count जवाब देखें',
      one: '1 जवाब देखें',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentHideReplies => 'जवाब छिपाएँ';

  @override
  String get momentCommentDelete => 'कमेंट हटाएँ';

  @override
  String get momentCommentDeleteConfirm =>
      'यह कमेंट हटाएँ? इसके जवाब भी हट जाएँगे।';

  @override
  String get momentCommentDeleteConfirmButton => 'हटाएँ';

  @override
  String get momentCommentSend => 'भेजें';

  @override
  String get momentCommentExpressions => 'स्टिकर और GIF';

  @override
  String get momentCommentFailed =>
      'आपका कमेंट पोस्ट नहीं हो सका। फिर से कोशिश करें।';

  @override
  String get momentCommentAuthorBadge => 'लेखक';

  @override
  String get momentCommentLike => 'पसंद';

  @override
  String get momentCommentStickerAlt => 'स्टिकर';

  @override
  String get momentCommentGifAlt => 'GIF';

  @override
  String get momentCommentPosted => 'कमेंट पोस्ट हो गया';

  @override
  String momentCommentsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'सभी $count कमेंट देखें',
      one: '1 कमेंट देखें',
    );
    return '$_temp0';
  }

  @override
  String momentReactorsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count अन्य',
      one: '1 अन्य',
    );
    return '$name और $_temp0';
  }

  @override
  String get storageKindPhotos => 'फ़ोटो';

  @override
  String get storageKindVideos => 'वीडियो';

  @override
  String get storageKindVideoMessages => 'वीडियो नोट';

  @override
  String get storageKindVoice => 'वॉइस मैसेज';

  @override
  String get storageKindFiles => 'फ़ाइलें';

  @override
  String get storageKindStickers => 'स्टिकर और GIF';

  @override
  String get storageKindChatHistory => 'चैट हिस्ट्री';

  @override
  String get storageKindOther => 'अन्य';

  @override
  String get dataUsageKindCalls => 'कॉल';

  @override
  String get dataStorageTitle => 'डेटा और स्टोरेज';

  @override
  String get settingsSearchKwDataStorage =>
      'स्टोरेज कैश मेमोरी जगह साफ़ डाउनलोड ऑटो डाउनलोड डेटा उपयोग सेल्युलर मोबाइल वाईफ़ाई wifi फ़ोटो सेव गैलरी storage cache';

  @override
  String get storageUsageTitle => 'स्टोरेज उपयोग';

  @override
  String get dataUsageTitle => 'डेटा उपयोग';

  @override
  String get dataStorageAutoDownloadHeader => 'मीडिया ऑटो डाउनलोड';

  @override
  String get dataStorageUsingCellular => 'सेल्युलर पर';

  @override
  String get dataStorageUsingWifi => 'Wi-Fi पर';

  @override
  String get dataStorageNowTag => 'अभी';

  @override
  String get autoDownloadReset => 'ऑटो डाउनलोड सेटिंग्स रीसेट करें';

  @override
  String get autoDownloadResetTitle =>
      'ऑटो डाउनलोड की डिफ़ॉल्ट सेटिंग्स वापस लाएँ?';

  @override
  String get dataStorageSaveHeader => 'फ़ोटो में सहेजें';

  @override
  String get dataStorageSaveFooter =>
      'इन चैट की नई फ़ोटो और वीडियो अपने आप फ़ोटो लाइब्रेरी में सेव हो जाएँगी।';

  @override
  String get dataStorageCallsHeader => 'कॉल';

  @override
  String get dataStorageLessDataForCalls => 'कॉल में कम डेटा इस्तेमाल करें';

  @override
  String get dataStorageCallsFooter =>
      'कमज़ोर या लिमिटेड नेटवर्क पर कम डेटा लेता है, ऑडियो और वीडियो क्वालिटी थोड़ी कम रहती है।';

  @override
  String get dataStorageCallsNever => 'कभी नहीं';

  @override
  String get dataStorageCallsCellular => 'सेल्युलर पर';

  @override
  String get dataStorageCallsAlways => 'हमेशा';

  @override
  String get dataStorageOff => 'बंद';

  @override
  String get dataStorageChatsPrivate => 'प्राइवेट चैट';

  @override
  String get dataStorageChatsGroups => 'ग्रुप';

  @override
  String get dataStorageChatsPublic => 'पब्लिक रूम्स';

  @override
  String get dataStorageNetCellular => 'सेल्युलर';

  @override
  String get dataStorageNetWifi => 'Wi-Fi';

  @override
  String get autoDownloadMaster => 'मीडिया ऑटो डाउनलोड';

  @override
  String get autoDownloadUsageHeader => 'डेटा उपयोग';

  @override
  String get autoDownloadPresetLow => 'कम';

  @override
  String get autoDownloadPresetMedium => 'मध्यम';

  @override
  String get autoDownloadPresetHigh => 'ज़्यादा';

  @override
  String get autoDownloadCustomFooter =>
      'तुमने ये सेटिंग्स बदली हैं। किसी प्रीसेट पर लौटने के लिए स्लाइडर खिसकाओ।';

  @override
  String get autoDownloadTypesHeader => 'मीडिया के प्रकार';

  @override
  String get autoDownloadVideosTitle => 'वीडियो और वीडियो नोट';

  @override
  String get autoDownloadVoiceFooter =>
      'वॉइस मैसेज और स्टिकर बहुत छोटे होते हैं, इसलिए हमेशा अपने आप डाउनलोड हो जाते हैं।';

  @override
  String get autoDownloadAllChats => 'सभी चैट';

  @override
  String autoDownloadUpToIn(String size, String chats) {
    return '$chats में $size तक';
  }

  @override
  String autoDownloadSummaryUpTo(String kind, String size) {
    return '$size तक के $kind';
  }

  @override
  String get autoDownloadSummaryVoiceOnly => 'सिर्फ़ वॉइस मैसेज';

  @override
  String get autoDownloadInHeader => 'इनमें अपने आप डाउनलोड करें';

  @override
  String get autoDownloadMaxSizeHeader => 'अधिकतम फ़ाइल साइज़';

  @override
  String autoDownloadMaxSizeVideoFooter(String size) {
    return '$size तक के वीडियो अपने आप डाउनलोड होते हैं। बड़े वीडियो टैप करने पर डाउनलोड होंगे।';
  }

  @override
  String autoDownloadMaxSizeFileFooter(String size) {
    return '$size तक की फ़ाइलें अपने आप डाउनलोड होती हैं। बड़ी फ़ाइलें टैप करने पर डाउनलोड होंगी।';
  }

  @override
  String get autoDownloadGateLoad => 'फ़ोटो डाउनलोड करें';

  @override
  String get saveToPhotosHeader => 'अपने आप सेव करें';

  @override
  String get saveToPhotosFooter =>
      'इन चैट में आने वाली नई फ़ोटो और वीडियो डाउनलोड होते ही फ़ोटो लाइब्रेरी में जुड़ जाती हैं।';

  @override
  String get saveToPhotosMaxVideoHeader => 'अधिकतम वीडियो साइज़';

  @override
  String get saveToPhotosNoAccess =>
      'अपने आप सेव करने के लिए सेटिंग्स में फ़ोटो लाइब्रेरी का एक्सेस दें।';

  @override
  String get saveToPhotosPhotosAndVideos => 'फ़ोटो और वीडियो';

  @override
  String get storageCalculating => 'कैलकुलेट हो रहा है…';

  @override
  String storageShareOfFree(String percent) {
    return 'MonkeyHub तुम्हारी खाली जगह का $percent इस्तेमाल करता है।';
  }

  @override
  String get storageEmpty => 'अभी कैश में कुछ नहीं है।';

  @override
  String storageClearAllButton(String size) {
    return 'पूरा कैश साफ़ करें $size';
  }

  @override
  String storageClearSelectedButton(String size) {
    return 'चुने हुए साफ़ करें $size';
  }

  @override
  String storageClearChatButton(String size) {
    return 'कैश साफ़ करें $size';
  }

  @override
  String get storageClearFooter =>
      'सब कुछ क्लाउड में रहता है और ज़रूरत पड़ने पर फिर से डाउनलोड हो जाता है।';

  @override
  String get storageClearAllTitle => 'पूरा कैश साफ़ करें?';

  @override
  String get storageClearSelectedTitle => 'चुने हुए आइटम साफ़ करें?';

  @override
  String get storageClearBody =>
      'तुम्हारे मैसेज बने रहेंगे। मीडिया खोलने पर फिर से डाउनलोड होगा।';

  @override
  String storageClearConfirm(String size) {
    return '$size साफ़ करें';
  }

  @override
  String storageFreed(String size) {
    return '$size खाली हुआ';
  }

  @override
  String storageCleanupTitle(String size) {
    return '$size खाली करें';
  }

  @override
  String get storageCleanupSubtitle => 'एक महीने से न खोली गई मीडिया';

  @override
  String get storageCleanupAction => 'साफ़ करें';

  @override
  String get storageCleanupFooter =>
      'सिर्फ़ वही मीडिया साफ़ होती है जिसे 30 दिनों से किसी ने नहीं देखा। सेव किए गए मैसेज को कभी नहीं छुआ जाता।';

  @override
  String get storageAutoRemoveHeader => 'कैश मीडिया अपने आप हटाएँ';

  @override
  String get storageAutoRemoveFooter =>
      'जो मीडिया इतने समय से नहीं खोली गई, वह जगह बचाने के लिए इस डिवाइस से हटा दी जाती है। वह क्लाउड में रहती है, और सेव किए गए मैसेज हमेशा रखे जाते हैं।';

  @override
  String get dataStorageKeepNever => 'कभी नहीं';

  @override
  String get dataStorageKeepMonth => '1 महीना';

  @override
  String get dataStorageKeepWeek => '1 सप्ताह';

  @override
  String get dataStorageKeepDay => '1 दिन';

  @override
  String get storageLimitHeader => 'अधिकतम कैश साइज़';

  @override
  String get storageLimitFooter =>
      'अगर कैश इससे बड़ा हो जाए, तो सबसे लंबे समय से न खोली गई मीडिया पहले हटती है।';

  @override
  String get dataStorageLimitNone => 'कोई सीमा नहीं';

  @override
  String get storageTabChats => 'चैट';

  @override
  String get storageTabMedia => 'मीडिया';

  @override
  String get storageTabFiles => 'फ़ाइलें';

  @override
  String get storageNoChats => 'अभी किसी चैट का कुछ भी कैश नहीं हुआ है।';

  @override
  String get storageNoMedia => 'अभी कोई फ़ोटो या वीडियो कैश नहीं है।';

  @override
  String get storageNoFiles => 'अभी कोई फ़ाइल कैश नहीं है।';

  @override
  String get storageOpenPhoto => 'फ़ोटो खोलें';

  @override
  String get storageOpenVideo => 'वीडियो खोलें';

  @override
  String get storageSelect => 'चुनें';

  @override
  String storageChatShare(String percent) {
    return 'यह चैट तुम्हारे कैश का $percent इस्तेमाल करती है।';
  }

  @override
  String get storageChatUnknown => 'छोड़ी हुई चैट';

  @override
  String dataUsageSince(String date) {
    return '$date से';
  }

  @override
  String get dataUsageAll => 'सभी';

  @override
  String get dataUsageNothingYet =>
      'इस नेटवर्क पर अभी तक कुछ नहीं गिना गया है।';

  @override
  String get dataUsageTapHint =>
      'क्या भेजा और क्या मिला, यह देखने के लिए किसी कैटेगरी पर टैप करें।';

  @override
  String get dataUsageSent => 'भेजा गया';

  @override
  String get dataUsageReceived => 'प्राप्त';

  @override
  String get dataUsageTotalHeader => 'कुल नेटवर्क उपयोग';

  @override
  String get dataUsageFootnote =>
      'मीडिया और कॉल गिने जाते हैं। मैसेज बहुत छोटे होते हैं, इसलिए शामिल नहीं हैं।';

  @override
  String get dataUsageReset => 'आँकड़े रीसेट करें';

  @override
  String get dataUsageResetTitle => 'डेटा उपयोग के आँकड़े रीसेट करें?';

  @override
  String get dataUsageResetBody => 'गिनती अभी से फिर शुरू होगी।';

  @override
  String get storageKindCompanions => 'साथी';

  @override
  String get storageCompanionsNote =>
      'कैश साफ़ करने पर साथी नहीं हटते। उनके डाउनलोड मैनेज करने के लिए उन पर टैप करें।';

  @override
  String storageCategoryCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम, $size',
      one: '1 आइटम, $size',
    );
    return '$_temp0';
  }

  @override
  String get storageSelectAll => 'सभी चुनें';

  @override
  String get storageDeselectAll => 'चयन हटाएं';

  @override
  String get storageCategoryEmpty => 'अभी इस तरह का कुछ भी कैश में नहीं है।';

  @override
  String get storageChatHistoryFooter =>
      'सिर्फ़ इस डिवाइस की कॉपी हटती है। मैसेज चैट में रहते हैं और अगली बार खोलने पर फिर से लोड हो जाते हैं।';

  @override
  String get storageCategoryHint =>
      'अंदर क्या है देखने के लिए किसी कैटेगरी पर टैप करें, या उसे छोड़ने के लिए उसके गोले पर।';

  @override
  String storageChatRemovedNamed(String names) {
    return '$names · हटाई गई चैट';
  }
}
