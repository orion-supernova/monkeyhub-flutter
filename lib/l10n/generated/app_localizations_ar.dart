// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'تعذّر الوصول إلى الخادم';

  @override
  String get bootErrorBody => 'تعذّرت تهيئة Convex.';

  @override
  String get bootErrorRetry => 'إعادة المحاولة';

  @override
  String get incomingCallNotificationTitle => 'مكالمة واردة';

  @override
  String get incomingCallFallbackCaller => 'شخص ما يتصل بك';

  @override
  String get settingsLanguageRowLabel => 'اللغة';

  @override
  String get languageScreenTitle => 'اللغة.';

  @override
  String get languageScreenSubtitle => 'اختر لغة القوائم والرسائل في التطبيق';

  @override
  String get languageOptionSystem => 'النظام';

  @override
  String get languageOptionSystemSub => 'يطابق لغة جهازك';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => 'نشط';

  @override
  String get languageValueSystem => 'النظام';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack =>
      'تعذّر إرسال الطلب الآن. حاول مرة أخرى';

  @override
  String get roomScreenGateSendMessages => 'إرسال الرسائل هنا';

  @override
  String get roomScreenGateSendMedia => 'إرسال الصور أو الرسائل الصوتية';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'بحد أقصى $max في المرة الواحدة';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف $count رسالة',
      many: 'حذف $count رسالة',
      few: 'حذف $count رسائل',
      two: 'حذف رسالتين',
      one: 'حذف الرسالة',
      zero: 'حذف $count رسالة',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'سيؤدي هذا إلى حذفها لدى الجميع في هذه المحادثة. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get roomScreenDeleteConfirmBodyOne =>
      'سيؤدي هذا إلى حذفها لدى الجميع في هذه المحادثة. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get roomScreenDeleteConfirmButton => 'حذف للجميع';

  @override
  String get roomScreenJumpFailedSnack => 'تعذّر الانتقال إلى تلك الرسالة';

  @override
  String get roomScreenUnreadDivider => 'رسائل غير مقروءة';

  @override
  String get roomScreenViewOnceAlreadyViewed => 'لقد فتحت هذه الصورة من قبل.';

  @override
  String get roomScreenViewOnceGone => 'لم تعد هذه الصورة متاحة.';

  @override
  String get roomScreenViewOnceNetworkError => 'تعذّر تحميل تلك الصورة.';

  @override
  String get roomScreenFileReadFailedSnack => 'تعذّرت قراءة ذلك الملف';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'الحد الأقصى لحجم الملفات هو $size';
  }

  @override
  String get roomScreenRoomGone => 'الغرفة لم تعد موجودة';

  @override
  String get roomScreenCopiedSnack => 'تم النسخ';

  @override
  String get roomScreenNameCopiedSnack => 'تم نسخ الاسم';

  @override
  String get roomScreenPinLimitSnack => 'التثبيت ممتلئ. ألغِ تثبيت رسالة أولاً';

  @override
  String get roomScreenPinFailedSnack => 'تعذّر تثبيت ذلك';

  @override
  String get roomScreenReportSentSnack =>
      'تم إرسال البلاغ سرًا. لن يتم إشعارهم.';

  @override
  String get roomScreenDeselectMessageSemantic => 'إلغاء تحديد الرسالة';

  @override
  String get roomScreenSelectMessageSemantic => 'تحديد الرسالة';

  @override
  String roomScreenMemberCountBadge(Object count) {
    return '$count بالداخل';
  }

  @override
  String roomScreenTtlSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ثانية',
      many: '$count ثانية',
      few: '$count ثوانٍ',
      two: 'ثانيتان',
      one: 'ثانية واحدة',
      zero: '$count ثانية',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دقيقة',
      many: '$count دقيقة',
      few: '$count دقائق',
      two: 'دقيقتان',
      one: 'دقيقة واحدة',
      zero: '$count دقيقة',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      many: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتان',
      one: 'ساعة واحدة',
      zero: '$count ساعة',
    );
    return '$_temp0';
  }

  @override
  String roomScreenEphemeralNotice(Object ttl) {
    return 'هذه الغرفة مؤقتة. تختفي الرسائل بعد $ttl، سواء قُرئت أم لم تُقرأ.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count رسالة';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'مساحة سرية';

  @override
  String get roomScreenSecretSpaceBody =>
      'الرسائل في هذه الغرفة مؤقتة، ويتم حذفها تلقائيًا وفقًا لسياسة الأمان الخاصة بالغرفة.';

  @override
  String get roomReadOnlyFooter =>
      'هذه الغرفة للقراءة فقط. MonkeyHub وحده ينشر هنا.';

  @override
  String get roomScreenAutoDeleteTitle => 'الحذف التلقائي';

  @override
  String get roomScreenAutoDeleteVaries => 'متغيّر';

  @override
  String get roomScreenAutoDeleteTimed => 'مؤقّت';

  @override
  String get roomScreenNoCaptureTitle => 'منع الالتقاط';

  @override
  String get roomScreenNoCaptureSubtitle => 'لقطات الشاشة مقيّدة';

  @override
  String get roomScreenMorePrivacyTitle => 'خصوصية أكبر بكثير';

  @override
  String get roomScreenMorePrivacySubtitle =>
      'استمتع بميزات أمان إضافية إلى جانب التركيز الحالي على الخصوصية.';

  @override
  String get roomScreenNoMessagesTitle => 'لا توجد رسائل';

  @override
  String get roomScreenNoMessagesSubtitle => 'ابدأ المحادثة بإرسال رسالة';

  @override
  String get roomScreenViewProfilePictureSemantic => 'عرض الصورة الشخصية';

  @override
  String get roomScreenViewRoomPictureSemantic => 'عرض صورة الغرفة';

  @override
  String get messageBubbleFileFallbackName => 'مستند مُرسَل';

  @override
  String get messageBubbleAttachmentStatusFailed => 'فشل الإرسال';

  @override
  String get messageBubbleAttachmentStatusSending => 'جارٍ الإرسال…';

  @override
  String get messageBubbleViewOnceOpened => 'مفتوحة';

  @override
  String get messageBubbleViewOnceExpired => 'منتهية';

  @override
  String get messageBubbleViewOnceLabel => 'مشاهدة واحدة';

  @override
  String get messageBubbleViewOnceTapToView => 'اضغط للمشاهدة';

  @override
  String get messageBubbleViewOncePhotoLabel => 'صورة';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'صورة ذات مشاهدة واحدة، اضغط للمشاهدة';

  @override
  String get messageBubblePlayOnceLabel => 'تشغيل مرة واحدة';

  @override
  String get messageBubblePlayOnceTapToPlay => 'انقر للتشغيل';

  @override
  String get messageBubblePlayOncePlayed => 'تم التشغيل';

  @override
  String get messageBubblePlayOnceVoiceSemanticLabel =>
      'رسالة صوتية تُشغَّل مرة واحدة، انقر للتشغيل';

  @override
  String get messageBubblePlayOnceVideoNoteSemanticLabel =>
      'ملاحظة فيديو تُشغَّل مرة واحدة، انقر للتشغيل';

  @override
  String get replyIndicatorPlayOnceVoiceLabel =>
      'رسالة صوتية · تشغيل مرة واحدة';

  @override
  String get replyIndicatorPlayOnceVideoNoteLabel =>
      'ملاحظة فيديو · تشغيل مرة واحدة';

  @override
  String get roomScreenPlayOnceVoiceAlreadyPlayed =>
      'لقد استمعت إلى هذه الرسالة الصوتية من قبل.';

  @override
  String get roomScreenPlayOnceVoiceGone => 'لم تعد هذه الرسالة الصوتية متاحة.';

  @override
  String get roomScreenPlayOnceVoiceNetworkError =>
      'تعذّر تحميل تلك الرسالة الصوتية.';

  @override
  String get roomScreenPlayOnceVideoNoteAlreadyPlayed =>
      'لقد شاهدت ملاحظة الفيديو هذه من قبل.';

  @override
  String get roomScreenPlayOnceVideoNoteGone =>
      'لم تعد ملاحظة الفيديو هذه متاحة.';

  @override
  String get roomScreenPlayOnceVideoNoteNetworkError =>
      'تعذّر تحميل ملاحظة الفيديو تلك.';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'إعادة الإرسال';

  @override
  String get messageBubbleDiscardSemanticLabel => 'إلغاء الإرسال';

  @override
  String get profileScreenAccountSection => 'الحساب';

  @override
  String get profileScreenAddEmailPlaceholder => 'إضافة بريد إلكتروني';

  @override
  String get profileScreenAddEmailTitle => 'إضافة بريد إلكتروني؟';

  @override
  String get profileScreenAddNameTitle => 'إضافة اسم؟';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count في الانتظار';
  }

  @override
  String get profileScreenApprovalsLabel => 'الموافقات';

  @override
  String get profileScreenApprovalsNothingWaiting =>
      'لا توجد طلبات في الانتظار';

  @override
  String get profileScreenApproveAction => 'قبول';

  @override
  String get profileScreenBlockAction => 'حظر';

  @override
  String get profileScreenBlockedDmWiped =>
      'تم الحظر ومسح المحادثة الخاصة. لن يصلهم إشعار بذلك.';

  @override
  String get profileScreenBlockedOnly => 'تم الحظر. لن يصلهم إشعار بذلك.';

  @override
  String get profileScreenBlockedUsers => 'المستخدمون المحظورون';

  @override
  String get profileScreenCancelAction => 'إلغاء';

  @override
  String get profileScreenCancelRequestAction => 'إلغاء الطلب';

  @override
  String get profileScreenChangeAction => 'تغيير';

  @override
  String get profileScreenChangeEmailTitle => 'تغيير البريد الإلكتروني؟';

  @override
  String get profileScreenChangeNameTitle => 'تغيير الاسم؟';

  @override
  String get profileScreenChangeProfilePictureSemantic =>
      'تغيير الصورة الشخصية';

  @override
  String get profileScreenChangeRecoveryPhrase => 'تغيير عبارة الاسترداد';

  @override
  String get profileScreenChooseFromLibrary => 'الاختيار من المعرض';

  @override
  String get profileScreenCouldNotSaveImage => 'تعذّر حفظ الصورة.';

  @override
  String get profileScreenDeleteAccount => 'حذف الحساب';

  @override
  String get profileScreenEmailHint => 'اختياري، ولن يُعرض لأي شخص';

  @override
  String get profileScreenEmailSectionLabel => 'البريد الإلكتروني';

  @override
  String get profileScreenErrorAlreadyFriends => 'أنتما صديقان بالفعل.';

  @override
  String get profileScreenErrorGeneric => 'تعذّر إتمام ذلك.';

  @override
  String get profileScreenErrorNotAccepting =>
      'هذا المستخدم لا يقبل طلبات الصداقة حاليًا.';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      'لقد أرسل لك طلبًا بالفعل. تحقّق من الطلبات.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'تم إرسال الطلب بالفعل.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'لقد حظرت هذا المستخدم. قم بإلغاء الحظر عنه أولًا.';

  @override
  String get profileScreenErrorUserNotFound => 'هذا غير ممكن حاليًا.';

  @override
  String get profileScreenNameNotSaved =>
      'لم نتمكّن من حفظ اسمك. حاول مرة أخرى.';

  @override
  String get profileScreenFamilyAddChild => 'إضافة طفل';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count طفل',
      many: '$count طفلًا',
      few: '$count أطفال',
      two: 'طفلان',
      one: 'طفل واحد',
      zero: 'لا يوجد أطفال',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => 'العائلة';

  @override
  String get profileScreenFriendsChip => 'أصدقاء';

  @override
  String get profileScreenGrownUpOnlyNote =>
      'لا يمكن فعل هذا إلا من قِبل ولي الأمر، إذ يتطلب رمزه أو كلمة مروره.';

  @override
  String get profileScreenGuardiansCanSee =>
      'يمكنهم معرفة متى تكون متصلًا بالإنترنت ومع من تتحدث.';

  @override
  String get profileScreenHandPhoneBack => 'أعد هذا الهاتف';

  @override
  String get profileScreenIncomingRequestChip => 'طلب وارد';

  @override
  String get profileScreenJustTappedAction => 'ضغطت بالخطأ';

  @override
  String get settingsScreenSectionHelpAndLegal => 'المساعدة والشؤون القانونية';

  @override
  String get settingsScreenLicence => 'الترخيص';

  @override
  String get profileScreenLinkedAccountsLabel => 'الحسابات المرتبطة';

  @override
  String get profileScreenLinkedAccountsNone => 'لا حسابات مرتبطة';

  @override
  String get profileScreenMyGrownUps => 'أولياء أموري';

  @override
  String get profileScreenNameHint => 'هكذا سيراك أعضاء الغرفة';

  @override
  String get profileScreenChangeUsernameTitle => 'تغيير اسم المستخدم؟';

  @override
  String get profileScreenChangeUsernameWarning =>
      'أنت تسجّل الدخول بهذا الاسم، لذا ستكتب الاسم الجديد من الآن فصاعدًا. يصبح اسم المستخدم القديم متاحًا لأي شخص آخر، ولن تتمكّن من تغييره مجددًا لمدة 30 يومًا. الرسائل القديمة التي أشارت إليك تحتفظ بالاسم القديم.';

  @override
  String get profileScreenUsernameHint => 'هكذا يجدك أصدقاؤك';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return 'يمكن تغييره مجددًا في $date';
  }

  @override
  String get profileScreenUsernamePasswordTitle => 'أكّد أنك أنت';

  @override
  String get profileScreenUsernamePasswordAction => 'تغيير اسم المستخدم';

  @override
  String get profileScreenUsernameProviderTitle => 'أكّد بتسجيل دخولك';

  @override
  String profileScreenUsernameChanged(String username) {
    return 'أنت الآن @$username.';
  }

  @override
  String get profileScreenUsernameNotSaved =>
      'تعذّر تغيير اسم المستخدم. يرجى المحاولة مرة أخرى.';

  @override
  String get usernameStatusChecking => 'جارٍ التحقق…';

  @override
  String get usernameStatusAvailable => 'متاح';

  @override
  String get usernameStatusTaken => 'مستخدم بالفعل';

  @override
  String get usernameStatusReserved => 'غير متاح';

  @override
  String get usernameStatusInvalid => 'من 1 إلى 32 حرفًا';

  @override
  String get usernameStatusUnknown => 'تعذّر التحقق';

  @override
  String get profileScreenNobodyLookingAfter =>
      'لا أحد يشرف على هذا الحساب بعد';

  @override
  String get profileScreenNotAcceptingRequestsAction => 'لا يقبل الطلبات';

  @override
  String get profileScreenNotConnectedChip => 'غير مرتبط';

  @override
  String get profileScreenOpenDmAction => 'فتح رسالة خاصة';

  @override
  String get profileScreenPhotoPermissionDenied =>
      'تم رفض إذن الوصول إلى الصور.';

  @override
  String get settingsScreenPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get profileScreenPrivacySection => 'الخصوصية';

  @override
  String get profileScreenProfilePictureTitle => 'الصورة الشخصية';

  @override
  String get profileScreenRedactedFriend =>
      'بعض الحقول مخفية حسب إعدادات ظهوره.';

  @override
  String get profileScreenRedactedStranger =>
      'عرض محدود، فهو يشارك المزيد مع أصدقائه.';

  @override
  String get profileScreenReportAction => 'إبلاغ';

  @override
  String get profileScreenReportSent => 'تم إرسال البلاغ بسرية. لن يتم إخطاره.';

  @override
  String get profileScreenRequestPendingChip => 'طلب مرسل';

  @override
  String get profileScreenSaveAction => 'حفظ';

  @override
  String get profileScreenSavedToPhotos => 'تم الحفظ في الصور.';

  @override
  String get profileScreenSaveToPhotos => 'حفظ في الصور';

  @override
  String get profileScreenSendRequestAction => 'إرسال طلب';

  @override
  String get profileScreenSetUpRecoveryPhrase => 'إعداد عبارة الاسترداد';

  @override
  String get profileScreenSignOut => 'تسجيل الخروج';

  @override
  String get profileScreenTakeSelfie => 'التقط سيلفي';

  @override
  String get profileScreenTapAgainToConfirmDelete =>
      'اضغط مرة أخرى لتأكيد الحذف';

  @override
  String get settingsScreenTermsOfService => 'شروط الخدمة';

  @override
  String get profileScreenThisPhoneSection => 'هذا الهاتف';

  @override
  String get profileScreenUnfriendAction => 'إلغاء الصداقة';

  @override
  String get profileScreenViewProfilePictureSemantic => 'عرض الصورة الشخصية';

  @override
  String get profileScreenVisibilityPreferences => 'تفضيلات الظهور';

  @override
  String get cameraEditorScreenCropPresetFree => 'حر';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'أصلي';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'إلغاء القص';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'تجاهل الصورة';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'تراجع';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'إعادة';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'إعادة تعيين القص';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'تدوير';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'قص';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'لا يستطيع هذا المتصفح فتح صور HEIC';

  @override
  String get cameraEditorScreenImageLoadFailedMessage => 'تعذّر فتح هذه الصورة';

  @override
  String get cameraEditorScreenCropDoneButton => 'تم';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'إعادة الالتقاط';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'إخفاء القلم';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'الرسم على الصورة';

  @override
  String get cameraEditorScreenSendingButton => 'جارٍ الإرسال…';

  @override
  String get cameraEditorScreenSendButton => 'إرسال';

  @override
  String get cameraEditorScreenViewOnceNote => 'تختفي بعد فتحها مرة واحدة';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'مسح الرسم';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel =>
      'المشاهدة لمرة واحدة: مفعّلة';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel =>
      'المشاهدة لمرة واحدة: غير مفعّلة';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: مفعّل';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: معطّل';

  @override
  String get cameraEditorScreenHdNote => 'سيتم الإرسال بالدقة الكاملة';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'لون الحبر';

  @override
  String get glassScreenPanelLooks => 'المظاهر';

  @override
  String get glassScreenPanelBottomBar => 'الشريط السفلي';

  @override
  String get glassScreenPanelOtherSurfaces => 'الأسطح الأخرى';

  @override
  String get glassScreenPanelBarLayout => 'تخطيط الشريط';

  @override
  String get glassScreenTitle => 'الزجاج.';

  @override
  String get glassScreenSubtitle => 'مقدار ما يظهر مما خلفه';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'جميع الخانات الـ$max ممتلئة';
  }

  @override
  String get glassScreenSaveCurrentAs => 'حفظ الحالي باسم…';

  @override
  String get glassScreenResetEveryDial => 'إعادة تعيين كل قرص';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'إعادة تعيين إلى $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'شريط الكتابة، والرؤوس، وأزرار الاتصال: أي عنصر يظهر فوق النص لا فوق المحتوى القابل للتمرير';

  @override
  String get glassScreenMatchBottomBar => 'مطابقة الشريط السفلي';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'معدَّل. احفظه كمظهر جديد أو أعد تعيينه';

  @override
  String get glassScreenCustomPresetName => 'مخصص';

  @override
  String get glassScreenUnsavedSubtitle => 'غير محفوظ. امنحه اسمًا للاحتفاظ به';

  @override
  String get glassScreenSaveDialogTitle => 'احفظ هذا المظهر باسم';

  @override
  String get glassScreenNoRoomToast => 'لا توجد مساحة. احذف مظهرًا أولاً';

  @override
  String get glassScreenRenameDialogTitle => 'إعادة تسمية';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'حذف $name؟';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'يبقى المظهر على الشاشة، لكنه يفقد اسمه فقط.';

  @override
  String get glassScreenKeepButton => 'إبقاء';

  @override
  String get glassScreenDeleteButton => 'حذف';

  @override
  String get glassScreenNameHint => 'ليلة متأخرة';

  @override
  String get glassScreenCancelButton => 'إلغاء';

  @override
  String get glassScreenSaveButton => 'حفظ';

  @override
  String get glassScreenPreviewRoomName => '# الشرفة';

  @override
  String get glassScreenPreviewOnlineCount => '4 متصلين';

  @override
  String get glassScreenPreviewMessageHint => 'رسالة';

  @override
  String get glassScreenPreviewCollapseLabel => 'طي المعاينة';

  @override
  String get glassScreenPreviewExpandLabel => 'توسيع المعاينة';

  @override
  String get glassScreenPreviewBadge => 'معاينة';

  @override
  String get glassScreenBuiltInLabel => 'مدمج';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'استبدال $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'إعادة تسمية $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'حذف $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'إعادة تعيين $label';
  }

  @override
  String get glassScreenBackdropMsgDilan => 'أرسل صور السطح، البلاط كله متشقق';

  @override
  String get glassScreenBackdropMsgMert =>
      'حسنًا، لكن من سيحضر السماعة فعليًا؟';

  @override
  String get glassScreenBackdropGroupFamily => 'العائلة';

  @override
  String get glassScreenBackdropMsgFamily =>
      'أمي: العشاء الساعة 8، لا تتأخر مجددًا';

  @override
  String get glassScreenBackdropMsgZeynep => 'أنا في الخارج';

  @override
  String get glassScreenBackdropMsgKerem =>
      'ذلك المكان الذي في الزاوية قهوته رائعة';

  @override
  String get glassScreenBackdropGroupWork => 'العمل';

  @override
  String get glassScreenBackdropMsgWork =>
      'تم نقل الاجتماع الصباحي إلى الساعة 10:30 لبقية الأسبوع';

  @override
  String get glassScreenBackdropMsgElif => 'مستحيل. أرسله مرة أخرى، لقد أضعته';

  @override
  String get glassScreenBackdropMsgBaran => 'وصلنا 👍';

  @override
  String get glassScreenBackdropMsgAyse => 'القطة تعلمت فتح باب الشرفة';

  @override
  String get glassScreenBackdropMsgCan => 'أراك يوم السبت إذن';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return 'رداً على $name';
  }

  @override
  String get replyIndicatorViewOnceLabel => 'صورة · مشاهدة واحدة';

  @override
  String get replyIndicatorVoiceMessageLabel => 'رسالة صوتية';

  @override
  String get replyIndicatorDocumentLabel => 'مستند';

  @override
  String get replyIndicatorMessageRemoved => 'تم حذف الرسالة';

  @override
  String get threadOverlayMessageNotFound =>
      'تعذر العثور على هذه الرسالة في هذه السلسلة';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'تعذر العثور على السلسلة للرد عليها';

  @override
  String get threadOverlayStillSending =>
      'لا تزال قيد الإرسال. حاول مجدداً بعد قليل';

  @override
  String get threadOverlayCopiedToast => 'تم النسخ';

  @override
  String get threadOverlayNameCopiedToast => 'تم نسخ الاسم';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'تم نسخ الإحداثيات';

  @override
  String get threadOverlayPinLimitToast =>
      'عدد الرسائل المثبّتة كبير جداً. ألغِ تثبيت واحدة أولاً';

  @override
  String get threadOverlayPinFailedToast => 'تعذّر تثبيت الرسالة';

  @override
  String get threadOverlayReportedToast => 'تم الإبلاغ';

  @override
  String get threadOverlayUnavailable => 'السلسلة غير متاحة';

  @override
  String get roomInfoScreenNameRequiredError => 'الاسم مطلوب';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'تم مسح كلمة المرور';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'مغادرة الغرفة؟';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'يمكنك الانضمام مجدداً إذا بقيت مفتوحة.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'مغادرة';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'حذف الغرفة؟';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'ستُحذف كل رسالة هنا معها. هذا إجراء نهائي.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'حذف';

  @override
  String get roomInfoScreenEndConversationConfirmTitle => 'إنهاء هذه المحادثة؟';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return 'سيفقد $peerName هذه المحادثة أيضاً، وتختفي كل رسالة لديكما. هذا إجراء نهائي.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'إنهاء';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'الشخص الآخر';

  @override
  String get roomInfoScreenConfirmCancelButton => 'إلغاء';

  @override
  String get roomInfoScreenErrorRoomExists => 'توجد غرفة بهذا الاسم بالفعل';

  @override
  String get roomNameReservedError => 'لا يمكن أن يبدأ اسم الغرفة بـ dm:';

  @override
  String get roomInfoScreenErrorNotOwner => 'المالك فقط يمكنه فعل ذلك';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'ليس لديك إذن بذلك';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'هذه الغرفة لم تعد موجودة';

  @override
  String get roomInfoScreenRoomGone => 'الغرفة غير موجودة';

  @override
  String get roomInfoScreenNameLabel => 'الاسم';

  @override
  String get roomInfoScreenNameHint => 'اسم الغرفة';

  @override
  String get roomInfoScreenDescriptionLabel => 'الوصف';

  @override
  String get roomInfoScreenDescriptionHint => 'سطر واحد عن الغرفة';

  @override
  String get roomInfoScreenVisibilityLabel => 'الظهور';

  @override
  String get roomInfoScreenPublicTitle => 'عام';

  @override
  String get roomInfoScreenPublicSub => 'يمكن لأي شخص العثور عليها';

  @override
  String get roomInfoScreenPrivateTitle => 'خاصة';

  @override
  String get roomInfoScreenPrivateSub => 'بالدعوة فقط';

  @override
  String get roomInfoScreenMessageLifeLabel => 'عمر الرسالة';

  @override
  String roomInfoScreenTtlSeconds(Object value) {
    return '$valueث';
  }

  @override
  String roomInfoScreenTtlMinutes(Object value) {
    return '$valueد';
  }

  @override
  String roomInfoScreenTtlHours(Object value) {
    return '$valueس';
  }

  @override
  String get roomInfoScreenPasswordLabel => 'كلمة المرور';

  @override
  String get roomInfoScreenLockedBadge => 'مقفل';

  @override
  String get roomInfoScreenNoneBadge => 'لا يوجد';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      'هذه الغرفة محمية بكلمة مرور. لا تُعرض كلمة المرور الحالية لأسباب أمنية، أدخل كلمة جديدة لاستبدالها.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'استبدال كلمة المرور';

  @override
  String get roomInfoScreenSetPasswordHint => 'أقفل بكلمة مرور';

  @override
  String get roomInfoScreenRemovePasswordButton => 'إزالة كلمة المرور';

  @override
  String get roomInfoScreenSharedContentLabel => 'المحتوى المشترك';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return 'الأعضاء · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => 'جارٍ المغادرة…';

  @override
  String get roomInfoScreenLeaveRoomButton => 'مغادرة الغرفة';

  @override
  String get roomInfoScreenDeletingButton => 'جارٍ الحذف…';

  @override
  String get roomInfoScreenDeleteButtonLabel => 'حذف';

  @override
  String get roomInfoScreenEndingConversationButton => 'جارٍ الإنهاء…';

  @override
  String get roomInfoScreenEndConversationButton => 'إنهاء المحادثة';

  @override
  String get roomInfoScreenHeaderConversation => 'المحادثة';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'إعدادات الغرفة';

  @override
  String get roomInfoScreenViewProfilePictureSemantic =>
      'عرض صورة الملف الشخصي';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'عرض صورة الغرفة';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'تغيير صورة الغرفة';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'إضافة صورة الغرفة';

  @override
  String get roomInfoScreenOwnerBadge => 'المالك';

  @override
  String get roomInfoScreenNoneCount => 'لا يوجد';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'الوصول إلى الكاميرا متوقف.\nفعّله من الإعدادات لالتقاط صورة.';

  @override
  String get cameraScreenOpeningSystemCamera => 'جارٍ فتح كاميرا النظام…';

  @override
  String get cameraScreenCloseButtonLabel => 'إغلاق الكاميرا';

  @override
  String get cameraScreenLowLightBoostOnLabel =>
      'تحسين الإضاءة المنخفضة: مفعّل';

  @override
  String get cameraScreenLowLightBoostOffLabel =>
      'تحسين الإضاءة المنخفضة: معطّل';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'الفلاش: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'الاختيار من مكتبة الصور';

  @override
  String get cameraScreenSwitchCameraLabel => 'تبديل الكاميرا';

  @override
  String get cameraScreenTakePhotoLabel => 'التقاط صورة';

  @override
  String get childPolicyScreenAddByUsernameLabel => 'الإضافة باسم المستخدم';

  @override
  String get childPolicyScreenAddCta => 'إضافة';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'سيحصل على الصلاحيات نفسها التي تملكها تمامًا: كل طلب يحتاج إلى موافقة، وكل إعداد يمكن تغييره، وحتى صلاحية إزالتك. سيعتبره $name فردًا من العائلة على الفور.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'إضافة ولي أمر';

  @override
  String get childPolicyScreenAddGuardianHint => 'اسم مستخدمه';

  @override
  String get childPolicyScreenAllowCta => 'السماح';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'لن تُسأل عنه مرة أخرى، سواء أضافه $childName أو أضاف هو $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'السماح لشخص ما';

  @override
  String get childPolicyScreenAskToAddLabel => 'طلب الإضافة';

  @override
  String get childPolicyScreenAskToAddOffDesc => 'العائلة فقط، لا طلبات جديدة';

  @override
  String get childPolicyScreenAskToAddOnDesc => 'يمكنهم سؤالك عن أشخاص جدد';

  @override
  String get childPolicyScreenBothFinalNote =>
      'كلا الإجراءين نهائي. أما خيار الانسحاب فتجده في قسم أولياء الأمور.';

  @override
  String get childPolicyScreenCallsLabel => 'المكالمات';

  @override
  String get childPolicyScreenCallsOffDesc => 'الرسائل فقط';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'صوت وفيديو مع الأشخاص المسموح بهم';

  @override
  String get childPolicyScreenCancelLabel => 'إلغاء';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'إلغاء';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'تمت الإضافة، والطلب في طريقه';

  @override
  String get childPolicyScreenContactAddedToList =>
      'أُضيف إلى القائمة المسموح بها';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'إنشاء الغرف';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'لا يمكنهم إنشاء غرف';

  @override
  String get childPolicyScreenCreateRoomsOnDesc => 'يمكنهم إنشاء غرفهم الخاصة';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'سيُحذف كل شيء: رسائلهم وصورهم وغرفهم وأصدقاؤهم. لا يمكن التراجع عن هذا، ويصبح اسم المستخدم متاحًا لأي شخص آخر.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'تعذّر حذف الحساب. حاول مرة أخرى';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return 'حذف حساب $name؟';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'ستُحذف الرسائل والصور والغرف والأصدقاء بالكامل. لا يمكن التراجع عن هذا.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'حذف حساب $name';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'حذف نهائي';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'تعذّرت إضافته. حاول مرة أخرى';

  @override
  String get childPolicyScreenErrorCannotAddSelf => 'هذا اسم مستخدم الطفل نفسه';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'لا يمكن للطفل أن يكون ولي أمر';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'تعذّر تنفيذ ذلك. حاول مرة أخرى';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'لا بد أن يعتني بهم أحد. أضف وليّ أمر آخر أولاً';

  @override
  String get childPolicyScreenErrorNotYours => 'ليس من حقك تغيير هذا';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'لا يوجد حساب باسم المستخدم هذا';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'سيصبح حسابًا عاديًا بكلمة المرور هذه، ويفقد جميع أولياء الأمور كل قدرة على الاطلاع. لا عودة عن هذا القرار، إذ سيتعيّن دعوته من جديد كأي شخص آخر.';

  @override
  String get childPolicyScreenGraduateCta => 'تخريج';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'يحتفظ بكل شيء ويحصل على كلمة مرور. تفقد أنت كل قدرة على الاطلاع. لا رجعة في ذلك.';

  @override
  String get childPolicyScreenGraduateDangerLabel => 'تخريج إلى حساب كامل';

  @override
  String get childPolicyScreenGraduateFailed => 'تعذّر تخريجه. حاول مرة أخرى';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'تخريج $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'كلمة مرور له';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'سحب الإذن عن غرفة يُخرجه منها أيضًا. وسحب الإذن عن شخص يحذف محادثتهما كذلك، لدى الطرفين.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'يمكن لأي شخص هنا الموافقة وتغيير الإعدادات ورؤية كل شيء. يمكن لأي منهم التصرف بمفرده، فلا شيء ينتظر البقية.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'تمت الإضافة، ويمكنه الاعتناء به الآن';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return 'تمت إزالة $name';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (أنت)';
  }

  @override
  String get childPolicyScreenLoading => 'جارٍ التحميل…';

  @override
  String get childPolicyScreenLockedLabel => 'مقفل';

  @override
  String get childPolicyScreenMediaLabel => 'الصور + الصوت';

  @override
  String get childPolicyScreenMediaOffDesc => 'نص فقط';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'يمكنه إرسال الصور والفيديو والرسائل الصوتية';

  @override
  String get childPolicyScreenNoRoomsYet => 'لا توجد غرف بعد';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'يمكن إضافة أي شخص هنا دون سؤالك مجددًا، أيًا كان من يبدأ الأمر.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'معطّلة دائمًا للأطفال. أما اكتشاف (قائمة الغرف التي يملكها أشخاص لا تعرفهم) فمخفية بالكامل ولا يمكن تفعيلها. الغرف التي يُدعى إليها لا تزال تعمل بشكل طبيعي.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'الغرف العامة';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return 'لن يعود بإمكان $guardian رؤية أي شيء يخص $child أو الموافقة عليه.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return 'إزالة $name؟';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'إزالة';

  @override
  String childPolicyScreenRoomMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عضو',
      many: '$count عضوًا',
      few: '$count أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
      zero: 'لا أعضاء',
    );
    return '$_temp0';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'أولياء الأمور';

  @override
  String get childPolicyScreenSectionPeopleAllowed => 'الأشخاص الذين سمحت لهم';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'الغرف التي سمحت بها';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'ما يمكنه فعله';

  @override
  String get childPolicyScreenSectionWhenDone => 'عند الانتهاء';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'لن يحدث شيء حتى يضيف أحدهما الآخر';

  @override
  String get childPolicyScreenSendNowOnDesc => 'يُسألون فورًا';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'إرسال الطلب الآن';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'أنتَ ولي الأمر الوحيد لـ$name، لذا لا يمكنك التنحي وحسب. أضف وليّ أمر آخر أولاً، أو استخدم أحد هذه الخيارات.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'التنحي';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'ستفقد كل قدرة على متابعة حساب $name: طلباته، وأشخاصه، وغرفه. سيستمر باقي أولياء الأمور في رعايته.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'إيقاف الإشراف';

  @override
  String get childPolicyScreenStopSupervisingHeadline => 'إيقاف الإشراف؟';

  @override
  String get childPolicyScreenTakeBackFailed => 'تعذّر السحب. حاول مرة أخرى';

  @override
  String get childPolicyScreenTakeBackLabel => 'سحب';

  @override
  String get childPolicyScreenUsernameHint => 'اسم المستخدم';

  @override
  String get childPolicyScreenYou => 'أنتَ';

  @override
  String get roomContentScreenDefaultDocumentName => 'مستند';

  @override
  String get roomContentScreenCouldntOpenFile => 'تعذّر فتح هذا الملف';

  @override
  String get roomContentScreenCouldntShare => 'تعذّر مشاركتها';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم نسخ $count رابط',
      many: 'تم نسخ $count رابطًا',
      few: 'تم نسخ $count روابط',
      two: 'تم نسخ رابطين',
      one: 'تم نسخ الرابط',
      zero: 'لم يُنسخ أي رابط',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف $count رسالة',
      many: 'حذف $count رسالة',
      few: 'حذف $count رسائل',
      two: 'حذف رسالتين',
      one: 'حذف الرسالة',
      zero: 'حذف الرسائل',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'سيؤدي هذا إلى إزالتها لدى الجميع في هذه المحادثة. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get roomContentScreenDeleteForEveryone => 'حذف للجميع';

  @override
  String get roomContentScreenCancelTooltip => 'إلغاء';

  @override
  String get roomContentScreenBackTooltip => 'رجوع';

  @override
  String get roomContentScreenSelectingLabel => 'التحديد';

  @override
  String get roomContentScreenSharedContentLabel => 'المحتوى المشترك';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر محدد',
      many: '$count عنصرًا محددًا',
      few: '$count عناصر محددة',
      two: 'عنصران محددان',
      one: 'عنصر واحد محدد',
      zero: 'لا شيء محدد',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'تحديد';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'الكل';

  @override
  String get roomContentScreenEmptyMedia => 'لا توجد صور أو مقاطع فيديو بعد';

  @override
  String get roomContentScreenEmptyFiles => 'لا توجد ملفات بعد';

  @override
  String get roomContentScreenEmptyVoice => 'لا توجد رسائل صوتية بعد';

  @override
  String get roomContentScreenEmptyLinks => 'لا توجد روابط بعد';

  @override
  String get roomContentScreenEmptySaved =>
      'لم تحفظ شيئًا بعد. اضغط مطوّلًا على رسالة واختر حفظ.\n\nما تحفظه هنا يخصّك وحدك، أما الرسالة المثبّتة فتراها الغرفة كلها.';

  @override
  String get roomContentScreenLoadFailed => 'تعذّر تحميل ذلك';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'رسالة صوتية من $name';
  }

  @override
  String get roomContentScreenForwardAction => 'إعادة توجيه';

  @override
  String get roomContentScreenCopyAction => 'نسخ';

  @override
  String get roomContentScreenSaveAction => 'حفظ';

  @override
  String get roomContentScreenShareAction => 'مشاركة';

  @override
  String get roomContentScreenInChatAction => 'في المحادثة';

  @override
  String get roomContentScreenDeleteAction => 'حذف';

  @override
  String get messageActionMenuReplyLabel => 'رد';

  @override
  String get messageActionMenuEditLabel => 'تعديل';

  @override
  String get messageStampEditedLabel => 'معدّلة';

  @override
  String get composerEditCardTitle => 'تعديل الرسالة';

  @override
  String get spoilerRevealHint => 'سبويلر: فعِّل لإظهار النص المخفي';

  @override
  String get formatToolbarFormatLabel => 'تنسيق';

  @override
  String get formatToolbarBoldLabel => 'عريض';

  @override
  String get formatToolbarItalicLabel => 'مائل';

  @override
  String get formatToolbarStrikethroughLabel => 'يتوسطه خط';

  @override
  String get formatToolbarUnderlineLabel => 'تسطير';

  @override
  String get formatToolbarSpoilerLabel => 'سبويلر';

  @override
  String get formatToolbarLinkLabel => 'رابط';

  @override
  String get formatToolbarCodeLabel => 'كود';

  @override
  String get linkInputSheetTitle => 'رابط';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => 'تطبيق الرابط';

  @override
  String get linkInputSheetApplySub =>
      'سيفتح النص المحدد هذا العنوان عند النقر عليه';

  @override
  String get linkInputSheetRemoveLabel => 'إزالة الرابط';

  @override
  String get linkConfirmSheetTitle => 'فتح هذا الرابط؟';

  @override
  String get linkConfirmSheetOpenLabel => 'فتح الرابط';

  @override
  String get linkConfirmSheetCancelLabel => 'إلغاء';

  @override
  String get roomScreenEditExpiredSnack =>
      'فات أوان التعديل. لا يمكن تعديل الرسائل إلا خلال 15 دقيقة.';

  @override
  String get roomScreenEditFailedSnack =>
      'لم نتمكّن من حفظ التعديل. تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String get messageActionMenuForwardLabel => 'إعادة توجيه';

  @override
  String get messageActionMenuViewThreadLabel => 'عرض السلسلة';

  @override
  String get messageActionMenuCopyLabel => 'نسخ';

  @override
  String get messageActionMenuCopyNameLabel => 'نسخ الاسم';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'نسخ الإحداثيات';

  @override
  String get messageActionMenuPinLabel => 'تثبيت';

  @override
  String get messageActionMenuUnpinLabel => 'إلغاء التثبيت';

  @override
  String get messageActionMenuSelectLabel => 'تحديد';

  @override
  String get messageActionMenuProfileLabel => 'الملف الشخصي';

  @override
  String get messageActionMenuDeleteLabel => 'حذف';

  @override
  String get messageActionMenuReportLabel => 'إبلاغ';

  @override
  String get themeScreenTitle => 'السمة.';

  @override
  String get themeScreenTapToApplyHint => 'اضغط للتطبيق · ⛶ للمعاينة الكاملة';

  @override
  String get themeScreenFamilyBasicName => 'أساسي';

  @override
  String get themeScreenFamilyBasicTagline => 'مستوحاة من iOS · 5 لوحات ألوان';

  @override
  String get themeScreenFamilyVaultName => 'الخزنة';

  @override
  String get themeScreenFamilyVaultTagline => 'ملف سري · أسود وعاجي';

  @override
  String get themeScreenFamilyOthersName => 'أخرى';

  @override
  String get themeScreenFamilyOthersTagline => 'أجواء متفردة';

  @override
  String get themeScreenActiveBadge => 'نشط';

  @override
  String get themeScreenTapToApplyLabel => 'اضغط للتطبيق';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return 'نشط: $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return 'تطبيق $name';
  }

  @override
  String get themeScreenPreviewGreeting => 'أهلاً بك.';

  @override
  String get themeScreenPreviewSectionLabel => 'المحادثة';

  @override
  String get themeScreenPreviewRoomOneName => 'نادي التصميم';

  @override
  String get themeScreenPreviewRoomOneSub => 'ميا: أطلقت البطاقة الجديدة.';

  @override
  String get themeScreenPreviewRoomTwoName => 'الحجرة · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => 'تُختم خلال 4 ساعات.';

  @override
  String get themeScreenPreviewBubbleQuestion => 'كيف تشعر حيال هذا؟';

  @override
  String get themeScreenPreviewBubbleAnswer => 'وكأنه الخيار الصحيح.';

  @override
  String get callScreenVideoCallLabel => 'مكالمة فيديو واردة';

  @override
  String get callScreenVoiceCallLabel => 'مكالمة صوتية واردة';

  @override
  String callScreenStatusCalling(String kind) {
    return '$kind · جارٍ الاتصال…';
  }

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · يرن…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · واردة';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · جارٍ الربط…';
  }

  @override
  String get callScreenStatusConnected => 'متصلة';

  @override
  String get callScreenStatusEnded => 'انتهت المكالمة';

  @override
  String get callScreenStatusFailed => 'فشلت المكالمة';

  @override
  String get callScreenStatusSwitching => 'جارٍ تبديل الجهاز…';

  @override
  String get callScreenStatusMoved => 'انتقلت';

  @override
  String get callScreenStatusReconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String get callScreenPoorConnectionLabel => 'اتصال رديء';

  @override
  String get callScreenWeakConnectionLabel => 'اتصال ضعيف';

  @override
  String get callScreenControlUnmute => 'إلغاء الكتم';

  @override
  String get callScreenControlMute => 'كتم';

  @override
  String get callScreenControlCamOn => 'تشغيل الكاميرا';

  @override
  String get callScreenControlCamOff => 'إيقاف الكاميرا';

  @override
  String get callScreenPeerCameraOff => 'الكاميرا مغلقة';

  @override
  String get callScreenPeerCameraPaused => 'الكاميرا متوقفة مؤقتًا';

  @override
  String get callScreenControlFlip => 'تبديل';

  @override
  String get callScreenControlSpeaker => 'مكبر الصوت';

  @override
  String get callAudioControlLabel => 'الصوت';

  @override
  String get callAudioSheetTitle => 'الصوت';

  @override
  String get callAudioRoutePhone => 'الهاتف';

  @override
  String get callAudioRouteHeadphones => 'سماعات الرأس';

  @override
  String get callAudioRouteBluetooth => 'بلوتوث';

  @override
  String get callAudioRouteCar => 'السيارة';

  @override
  String get callAudioRouteOther => 'جهاز آخر';

  @override
  String get callAudioMicFollowsNote =>
      'ينتقل الميكروفون مع الجهاز الذي تختاره.';

  @override
  String get callAudioMicrophoneHeader => 'الميكروفون';

  @override
  String get callAudioUnknownDevice => 'جهاز غير معروف';

  @override
  String get callAudioNoDevices => 'لم يتم العثور على أجهزة';

  @override
  String get callAudioSwitchFailed => 'تعذر تبديل جهاز الصوت';

  @override
  String get callScreenControlEnd => 'إنهاء';

  @override
  String get linkPreviewCardLinkLabel => 'رابط';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return 'قبل $name طلبك.';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar => 'تم سحب هذا الطلب.';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'تم رفض الطلب.';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'لقد حظرت هذا المستخدم. ألغِ الحظر أولاً.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'هذا المستخدم لا يقبل طلبات الصداقة حالياً.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'تعذر الإرسال. حاول مرة أخرى.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => 'طلب وارد';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'طلب صادر';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name يريد بدء محادثة معك.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'أرسل بضعة أسطر. يمكنهم القبول أو الرفض.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'لن يُحفظ أي شيء هنا بشكل دائم حتى يوافق الطرفان.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'نوع الغرفة';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'مؤقتة';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'عادية';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'مدة البقاء';

  @override
  String friendRequestDraftScreenDurationSeconds(Object seconds) {
    return '$seconds ث';
  }

  @override
  String friendRequestDraftScreenDurationMinutes(Object minutes) {
    return '$minutesد';
  }

  @override
  String friendRequestDraftScreenDurationHours(Object hours) {
    return '$hoursس';
  }

  @override
  String get friendRequestDraftScreenHintWhisperOptional =>
      'اهمس بسطر أول · اختياري';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'أضف رسالة أولى · اختياري';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'همسة · تتلاشى تلقائيًا';

  @override
  String get friendRequestDraftScreenHintStartWith => 'شيء لتبدأ به';

  @override
  String get friendRequestDraftScreenApproveButton =>
      'قبول الطلب الوارد وفتح الغرفة';

  @override
  String get friendRequestDraftScreenDeclineButton => 'رفض الطلب الوارد';

  @override
  String get friendRequestDraftScreenCancelRequestButton =>
      'إلغاء الطلب المرسل';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => 'اسأل ولي الأمر';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'إرسال الطلب';

  @override
  String get discoverScreenTitle => 'اكتشف.';

  @override
  String get discoverScreenCaptionPeople => 'أشخاص';

  @override
  String get discoverScreenCaptionRooms => 'غرف';

  @override
  String get discoverScreenCaptionRequests => 'طلبات';

  @override
  String get discoverScreenPeopleBandLabel => 'الأشخاص';

  @override
  String get discoverScreenRoomsBandLabel => 'الغرف';

  @override
  String get discoverScreenFindPeopleTitle => 'البحث عن أشخاص';

  @override
  String get discoverScreenFindPeopleSubtitleChild =>
      'اكتب اسم المستخدم كاملاً';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'ابحث عبر @اسم المستخدم أو الاسم';

  @override
  String get discoverScreenRequestsSectionLabel => 'الطلبات';

  @override
  String get discoverScreenInboxQuiet => 'لا طلبات واردة';

  @override
  String get discoverScreenNothingPending => 'لا طلبات مُرسلة';

  @override
  String get discoverScreenYourPeopleLabel => 'الأصدقاء';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'لا أحد بعد. ابحث عن أشخاص في الأعلى';

  @override
  String get discoverScreenNoFriendsYet => 'لا أحد بعد';

  @override
  String get discoverScreenSearchRoomsTitle => 'البحث عن غرف';

  @override
  String get discoverScreenSearchRoomsSubtitle => 'ابحث عن غرفة عامة بالاسم';

  @override
  String get discoverScreenYourRoomsLabel => 'الغرف';

  @override
  String get discoverScreenNoRoomsYet => 'لا غرف بعد';

  @override
  String get discoverScreenIncomingLabel => 'وارد';

  @override
  String get discoverScreenOutgoingLabel => 'صادر';

  @override
  String get discoverScreenIncomingLabelCaps => 'وارد';

  @override
  String get discoverScreenOutgoingLabelCaps => 'صادر';

  @override
  String get discoverScreenJumpPeopleLabel => 'الأشخاص';

  @override
  String get discoverScreenJumpRoomsLabel => 'الغرف';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'الانتقال إلى $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'ضبط';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'استخدام الصورة';

  @override
  String get imageCropScreenSavingButton => 'جارٍ الحفظ…';

  @override
  String get imageCropScreenCancelButton => 'إلغاء';

  @override
  String get imageCropScreenHeicUnsupported =>
      'لا يمكن لهذا المتصفح فتح صور HEIC';

  @override
  String get imageCropScreenLoadFailed => 'تعذر فتح هذه الصورة';

  @override
  String get imageCropScreenHintCircle => 'اسحب للتحريك، واقرص للتكبير';

  @override
  String get imageCropScreenHintRect => 'اسحب واقرص لضبط الإطار';

  @override
  String get loginScreenSignInHeroMuted => 'أهلاً\n';

  @override
  String get loginScreenSignInHeroInk => 'بعودتك.';

  @override
  String get loginScreenSignInFirstHeroMuted => 'أهلاً\n';

  @override
  String get loginScreenSignInFirstHeroInk => 'وسهلاً.';

  @override
  String get loginScreenSignInCta => 'تسجيل الدخول';

  @override
  String get loginScreenSignUpHeroMuted => 'عضو\n';

  @override
  String get loginScreenSignUpHeroInk => 'جديد.';

  @override
  String get loginScreenSignUpCta => 'فتح حساب';

  @override
  String get loginScreenResetHeroMuted => 'إعادة تعيين\n';

  @override
  String get loginScreenResetHeroInk => 'كلمة المرور.';

  @override
  String get loginScreenResetCta => 'إعادة تعيين كلمة المرور';

  @override
  String get loginScreenErrorPasswordsDontMatch =>
      'كلمتا المرور غير متطابقتين.';

  @override
  String get loginScreenErrorChoosePasswordFirst => 'اختر كلمة مرور أولاً.';

  @override
  String get loginScreenUsernameHint => 'اسم المستخدم';

  @override
  String get loginScreenPasswordHint => 'كلمة المرور';

  @override
  String get loginScreenConfirmPasswordHint => 'تأكيد كلمة المرور';

  @override
  String get loginScreenNameOptionalHint => 'الاسم (اختياري)';

  @override
  String get loginScreenRecoveryPhraseHint =>
      'عبارة الاسترداد المكوّنة من 12 كلمة';

  @override
  String get loginScreenNewPasswordHint => 'كلمة المرور الجديدة';

  @override
  String get loginScreenBackToSignIn => '← الرجوع إلى تسجيل الدخول';

  @override
  String get loginScreenForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get loginScreenSettingUpKidsPhone => 'إعداد حساب طفل';

  @override
  String get loginScreenLegalPrefix => 'بفتح حساب، فإنك توافق على ';

  @override
  String get loginScreenLegalTermsLink => 'الشروط';

  @override
  String get loginScreenLegalMiddle => ' و';

  @override
  String get loginScreenLegalPrivacyLink => 'سياسة الخصوصية';

  @override
  String get loginScreenLegalSuffix => '.';

  @override
  String get loginScreenAlreadyHerePrompt => 'لديك حساب بالفعل؟ ';

  @override
  String get loginScreenSignInLink => 'تسجيل الدخول';

  @override
  String get loginScreenNoAccountPrompt => 'ليس لديك حساب؟ ';

  @override
  String get loginScreenOpenOneLink => 'فتح حساب';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12 كلمة';
  }

  @override
  String get homeShellEmptyRoomHint => 'اختر غرفة لبدء الدردشة';

  @override
  String get homeShellEmptySettingHint => 'اختر إعدادًا';

  @override
  String get searchScreenHintPeople => 'ابحث عن أشخاص';

  @override
  String get searchScreenHintRooms => 'ابحث عن غرف عامة';

  @override
  String get searchScreenPeoplePromptChild =>
      'اكتب اسم المستخدم كاملاً للعثور على شخص جديد';

  @override
  String get searchScreenPeoplePromptDefault => 'ابحث باسم المستخدم أو الاسم';

  @override
  String get searchScreenNoMatchChild =>
      'لا يوجد تطابق. يحتاج الأشخاص الجدد إلى\nاسم المستخدم كاملاً بالتهجئة الصحيحة';

  @override
  String get searchScreenNoMatchDefault => 'لا يوجد تطابق';

  @override
  String get searchScreenNoRoomsYet => 'لا توجد غرف عامة بعد';

  @override
  String get searchScreenNoRoomsMatch => 'لا توجد غرف عامة مطابقة';

  @override
  String get searchScreenActionAskToAdd => 'اطلب الإضافة';

  @override
  String get searchScreenActionSendRequest => 'أرسل طلبًا';

  @override
  String get searchScreenActionCancel => 'ألغِ الطلب المرسل';

  @override
  String get searchScreenActionApprove => 'اقبل الطلب الوارد';

  @override
  String get searchScreenActionOpenDm => 'افتح محادثة خاصة';

  @override
  String get searchScreenAskedLabel => 'تم الطلب';

  @override
  String get profileVisibilityScreenTitle => 'تفضيلات الظهور.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'تحكم فيما يراه الآخرون، وكيف يمكنهم التواصل معك.';

  @override
  String get profileVisibilityScreenSectionProfile => 'الملف الشخصي';

  @override
  String get profileVisibilityScreenAvatarLabel => 'الصورة الرمزية';

  @override
  String get profileVisibilityScreenAvatarDesc => 'صورتك الشخصية';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => 'متصل / غائب';

  @override
  String get profileVisibilityScreenOnlineAwayDesc =>
      'ما إذا كنت تظهر نشطًا الآن';

  @override
  String get profileVisibilityScreenLastSeenLabel => 'آخر ظهور';

  @override
  String get profileVisibilityScreenLastSeenDesc => 'آخر وقت كنت فيه متواجدًا';

  @override
  String get profileVisibilityScreenSectionMessages => 'الرسائل';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel =>
      'إرسال إيصالات القراءة';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      'عند التفعيل، يمكن للآخرين رؤية أنك قرأت رسائلهم';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel =>
      'إظهار إيصالات القراءة';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      'شاهد علامة \"تمت المشاهدة\" على رسائلك بعد قراءتها';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      'لا يُسهم في ذلك سوى القراء الذين فعّلوا \"إرسال تأكيدات القراءة\"، أما البقية فتبقى مشاركتهم غير ظاهرة.';

  @override
  String get profileVisibilityScreenSectionPeople => 'الأشخاص';

  @override
  String get profileVisibilityScreenFriendRequestsLabel => 'طلبات الصداقة';

  @override
  String get profileVisibilityScreenFriendRequestsDesc =>
      'من يمكنه إرسال طلبات صداقة إليك';

  @override
  String get profileVisibilityScreenSupervisedTitle =>
      'أولياء أمورك هم من ضبطوا هذه الإعدادات';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      'يمكنك أن ترى هنا كل ما يراه الآخرون، لكن التغيير محصور بولي الأمر. فهو يستطيع دائمًا رؤية صورتك، ومتى تكون متصلاً، ومتى كان آخر ظهور لك.';

  @override
  String get profileVisibilityScreenOptionPublic => 'عام';

  @override
  String get profileVisibilityScreenOptionFriends => 'الأصدقاء';

  @override
  String get profileVisibilityScreenOptionNobody => 'لا أحد';

  @override
  String get profileVisibilityScreenOptionOn => 'تشغيل';

  @override
  String get profileVisibilityScreenOptionOff => 'إيقاف';

  @override
  String get profileVisibilityScreenOptionAnyone => 'أي شخص';

  @override
  String get logoScreenTitle => 'شعار التطبيق.';

  @override
  String get logoScreenSubtitle =>
      'العلامة التي تظهر في الشريط العلوي، القرار لك.';

  @override
  String get logoScreenAutoLabel => 'تلقائي';

  @override
  String get logoScreenAutoDescription =>
      'يتبع مظهرك؛ تتغيّر العلامة مع لوحة الألوان.';

  @override
  String get logoScreenManualLabel => 'يدوي';

  @override
  String get logoScreenManualDescription =>
      'اختر أي علامة تريدها، مع إبقاء مظهرك كما هو.';

  @override
  String get logoScreenAlwaysDefaultLabel => 'الافتراضي دائمًا';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      'علامة MonkeyHub، بصرف النظر عن المظهر.';

  @override
  String get logoScreenActiveBadge => 'نشِط';

  @override
  String get logoScreenMonkeyCollectionHeader => 'مجموعة القرود';

  @override
  String get logoScreenThemesHeader => 'المظاهر';

  @override
  String get recoveryPhraseScreenCopiedSnackbar =>
      'تم النسخ. الصقها في مكان آمن';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'تحقّق\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'من هويتك.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'كلمة مرورك، حتى لا يتمكن أي شخص آخر من إنشاء عبارة استرداد لحسابك.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'كلمة المرور';

  @override
  String get recoveryPhraseScreenContinueButton => 'متابعة';

  @override
  String get recoveryPhraseScreenNotNowLink => 'ليس الآن';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'أدخل كلمة المرور.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'احفظ\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => 'هذه الكلمات.';

  @override
  String get recoveryPhraseScreenWordsBody =>
      'هذه الكلمات الاثنتا عشرة هي السبيل الوحيد للعودة إلى حسابك إن نسيت كلمة المرور. لن نتمكن من إظهارها لك مرة أخرى، ولا من استعادتها نيابة عنك.';

  @override
  String get recoveryPhraseScreenCopyButton => 'نسخ';

  @override
  String get recoveryPhraseScreenPaperHint =>
      'دوّنها على ورقة إن استطعت. فكل ما هو على هذا الهاتف قد يُفقد معه.';

  @override
  String get recoveryPhraseScreenSavedButton => 'لقد حفظتها';

  @override
  String get recoveryPhraseScreenBackLink => '→ رجوع';

  @override
  String get recoveryPhraseScreenKeepPhraseLink =>
      'ليس الآن، احتفظ بعبارتي الحالية';

  @override
  String get homeScreenProfileSemanticLabel => 'ملفك الشخصي';

  @override
  String homeScreenGreeting(Object name) {
    return 'أهلاً يا $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'غرفة جديدة';

  @override
  String get homeScreenEmptyRoomsMessage => 'لا توجد غرف بعد. أنشئ واحدة';

  @override
  String get groupCallScreenTitleVideo => 'مكالمة فيديو جماعية';

  @override
  String get groupCallScreenTitleVoice => 'مكالمة صوتية جماعية';

  @override
  String groupCallScreenParticipantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count في المكالمة',
      one: 'أنت فقط',
    );
    return '$_temp0';
  }

  @override
  String get groupCallScreenReconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String get groupCallScreenUnmuteLabel => 'إلغاء الكتم';

  @override
  String get groupCallScreenMuteLabel => 'كتم';

  @override
  String get groupCallScreenCamOnLabel => 'تشغيل الكاميرا';

  @override
  String get groupCallScreenCamOffLabel => 'إيقاف الكاميرا';

  @override
  String get groupCallScreenFlipLabel => 'تبديل';

  @override
  String get groupCallScreenSpeakerLabel => 'مكبر الصوت';

  @override
  String get groupCallScreenLeaveLabel => 'مغادرة';

  @override
  String get groupCallScreenYouLabel => 'أنت';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return 'التصفية حسب $summary. تغيير التصفية';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => 'تصفية المحادثات';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => 'مسح التصفية';

  @override
  String get roomFilterDrawerClearLabel => 'مسح';

  @override
  String get roomFilterDrawerDimensionType => 'النوع';

  @override
  String get roomFilterDrawerDimensionNature => 'الطبيعة';

  @override
  String get roomFilterDrawerDimensionStatus => 'الحالة';

  @override
  String get roomFilterDrawerPanelClear => 'مسح';

  @override
  String get roomFilterDrawerPanelDone => 'تم';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محادثة',
      many: '$count محادثة',
      few: '$count محادثات',
      two: 'محادثتان',
      one: 'محادثة واحدة',
      zero: 'لا محادثات',
    );
    return '$label، $_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return 'لا شيء يطابق $summary';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إظهار كل $count محادثة',
      many: 'إظهار كل $count محادثة',
      few: 'إظهار كل $count محادثات',
      two: 'إظهار المحادثتين',
      one: 'إظهار المحادثة الوحيدة',
      zero: 'إظهار كل المحادثات',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إظهار كل $count محادثة',
      many: 'إظهار كل $count محادثة',
      few: 'إظهار كل $count محادثات',
      two: 'إظهار المحادثتين',
      one: 'إظهار المحادثة الوحيدة',
      zero: 'إظهار كل المحادثات',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'غرفة جديدة';

  @override
  String get createRoomSheetTaglineSecret => 'لن يُحفظ شيء';

  @override
  String get createRoomSheetTaglineRegular => 'مساحة تبقى';

  @override
  String get createRoomSheetNameLabel => 'الاسم';

  @override
  String get createRoomSheetNameHint => 'سمّها باسم صادق';

  @override
  String get createRoomSheetDescriptionLabel => 'الوصف · اختياري';

  @override
  String get createRoomSheetDescriptionHint => 'سطر واحد عن الغرفة';

  @override
  String get createRoomSheetVisibilityLabel => 'الظهور';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'عامة';

  @override
  String get createRoomSheetVisibilityPublicSub => 'يمكن لأي شخص إيجادها';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'خاصة';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'بالدعوة فقط';

  @override
  String get createRoomSheetTypeLabel => 'النوع';

  @override
  String get createRoomSheetTypeStandardTitle => 'عادية';

  @override
  String get createRoomSheetTypeStandardSub => 'الرسائل تبقى';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'مؤقتة';

  @override
  String get createRoomSheetTypeEphemeralSub => 'تُحذف تلقائيًا';

  @override
  String get createRoomSheetMessageLifeLabel => 'عمر الرسالة';

  @override
  String createRoomSheetTtlSeconds(Object seconds) {
    return '$secondsث';
  }

  @override
  String createRoomSheetTtlMinutes(Object minutes) {
    return '$minutesد';
  }

  @override
  String createRoomSheetTtlHours(Object hours) {
    return '$hoursس';
  }

  @override
  String get createRoomSheetPasswordLabel => 'كلمة المرور · اختياري';

  @override
  String get createRoomSheetPasswordHint => 'اقفلها بعبارة مرور';

  @override
  String get createRoomSheetNameRequiredError => 'الاسم مطلوب';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'افتح الغرفة';

  @override
  String get createRoomSheetOpenRoomButton => 'افتح الغرفة';

  @override
  String get familyScreenTitle => 'العائلة';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شيء يحتاج إلى موافقتك',
      many: '$count شيئًا يحتاج إلى موافقتك',
      few: '$count أشياء تحتاج إلى موافقتك',
      two: 'شيئان يحتاجان إلى موافقتك',
      one: 'شيء واحد يحتاج إلى موافقتك',
      zero: 'لا شيء يحتاج إلى موافقتك',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => 'متصل الآن';

  @override
  String get familyScreenPresenceNotPaired => 'لم يتم الإقران بعد';

  @override
  String get familyScreenPresenceJustNow => 'منذ لحظات';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return 'منذ $minutes د';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return 'منذ $hours س';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return 'منذ $days يوم';
  }

  @override
  String get familyScreenPairButton => 'إقران';

  @override
  String get familyScreenReleaseButton => 'فصل';

  @override
  String get familyScreenSettingsButton => 'الإعدادات';

  @override
  String get familyScreenAddChildButton => 'إضافة طفل';

  @override
  String get familyScreenEmptyStateTitle => 'لا يوجد أطفال بعد';

  @override
  String get familyScreenEmptyStateBody =>
      'أنشئ حسابًا لطفلك، ثم اربطه بهاتفه.';

  @override
  String get reactionDetailsSheetTitle => 'التفاعلات';

  @override
  String get reactionDetailsSheetEmptyState => 'لم يتبقَّ شيء هنا';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخص',
      many: '$count شخصًا',
      few: '$count أشخاص',
      two: 'شخصان',
      one: 'شخص واحد',
      zero: 'لا أحد',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => 'الكل';

  @override
  String get reactionDetailsSheetYouBadge => 'أنت';

  @override
  String get reactionDetailsSheetAddYours => 'أضف تفاعلك';

  @override
  String get reactionDetailsSheetRemoveYours => 'أزل تفاعلك';

  @override
  String get roomLayoutScreenTitle => 'قائمة المحادثات.';

  @override
  String get roomLayoutScreenSubtitle => 'كيف تُرتَّب الغرف، وكيف تُصفّيها';

  @override
  String get roomLayoutScreenLayoutSectionLabel => 'التخطيط';

  @override
  String get roomLayoutScreenRowLayoutLabel => 'تخطيط الصفوف';

  @override
  String get roomLayoutScreenRowLayoutDescription =>
      'عمود واحد بعرض كامل. سهل القراءة بنظرة واحدة.';

  @override
  String get roomLayoutScreenGridLayoutLabel => 'تخطيط الشبكة';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      'عمودان، بشكل مضغوط. غرف أكثر في نظرة واحدة.';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => 'التحكم في التصفية';

  @override
  String get roomLayoutScreenChipRowLabel => 'صف الشرائح';

  @override
  String get roomLayoutScreenChipRowDescription =>
      'ظاهر دائمًا. نقرة واحدة لأي تصفية، وصف واحد من المساحة.';

  @override
  String get roomLayoutScreenDrawerButtonLabel => 'زر الدرج';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      'زر واحد يُفتح عند الحاجة. لا شيء يعترض طريقك حتى تطلبه.';

  @override
  String get roomLayoutScreenQuietRoomSectionLabel => 'الغرف الهادئة';

  @override
  String get roomLayoutScreenPlainCornerLabel => 'زاوية فارغة';

  @override
  String get roomLayoutScreenPlainCornerDescription =>
      'الغرفة التي لم يُقل فيها شيء تبقى بسيطة';

  @override
  String get roomLayoutScreenActiveBadge => 'نشط';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel =>
      'الانتقال إلى الرسالة المثبّتة';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => 'جميع الرسائل المثبّتة';

  @override
  String get pinnedBannerTitleSingle => 'رسالة مثبّتة';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return 'رسالة مثبّتة  $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => 'نمط المحادثة.';

  @override
  String get pinnedBannerChatStyleSubtitle => 'كيف تبدو الغرفة';

  @override
  String get pinnedBannerClassicLabel => 'كلاسيكي';

  @override
  String get pinnedBannerClassicSubtitle =>
      'رأس محاط بخط فاصل، وشريط كتابة مسطح.';

  @override
  String get pinnedBannerCompactLabel => 'مضغوط';

  @override
  String get pinnedBannerCompactSubtitle => 'كبسولات ضبابية تطفو فوق المحادثة.';

  @override
  String get pinnedBannerActiveBadge => 'نشط';

  @override
  String get audioMessageMissingLabel => '[الصوت مفقود]';

  @override
  String get audioMessageUnavailableLabel => 'الصوت غير متاح';

  @override
  String get audioMessageRetryHint => 'اضغط لإعادة المحاولة';

  @override
  String get audioMessageLoadingLabel => 'جارٍ التحميل…';

  @override
  String get audioMessageUsernameRequiredError => 'أدخل اسم المستخدم.';

  @override
  String get audioMessagePasswordRequiredError => 'أدخل كلمة المرور.';

  @override
  String get audioMessageCancelSemanticLabel => 'إلغاء';

  @override
  String get audioMessageHeroCreateLine1 => 'على وشك\n';

  @override
  String get audioMessageHeroCreateLine2 => 'الوصول.';

  @override
  String get audioMessageHeroLinkLine1 => 'أهلاً\n';

  @override
  String get audioMessageHeroLinkLine2 => 'بعودتك.';

  @override
  String get audioMessageCreateSubtitle =>
      'اختر اسم مستخدم ليتمكن أفراد عائلتك وأصدقاؤك من العثور عليك.';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return 'سجّل الدخول مرة واحدة ليُربط $provider بحسابك.';
  }

  @override
  String get audioMessageUsernameHint => 'اسم المستخدم';

  @override
  String get audioMessageDisplayNameHint => 'الاسم المعروض (اختياري)';

  @override
  String get audioMessagePasswordHint => 'كلمة المرور';

  @override
  String get audioMessageSwitchToLinkPrompt => 'هذا الحساب لي، تسجيل الدخول';

  @override
  String get audioMessageCreateAccountButton => 'إنشاء حساب';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return 'تسجيل الدخول وربط $provider';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => 'لديك حساب بالفعل؟';

  @override
  String get audioMessageSwitchToCreateModeLink => 'جديد هنا؟ أنشئ حساباً';

  @override
  String get approvalsScreenTitle => 'الموافقات';

  @override
  String get approvalsScreenEmptyTitle => 'لا شيء بالانتظار';

  @override
  String get approvalsScreenEmptySubtitle => 'أنت على اطلاع بكل شيء';

  @override
  String get approvalsScreenErrorNotGuardian => 'هذا القرار ليس لك';

  @override
  String get approvalsScreenErrorAlreadyHandled =>
      'تمت معالجته بالفعل في مكان آخر';

  @override
  String get approvalsScreenErrorGeneric => 'تعذّر الحفظ. حاول مرة أخرى';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child يريد إضافة $other';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other يريد إضافة $child';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child يريد الانضمام إلى $room';
  }

  @override
  String get approvalsScreenSomeoneLower => 'شخص ما';

  @override
  String get approvalsScreenSomeoneCapital => 'شخص ما';

  @override
  String get approvalsScreenRoomFallback => 'غرفة';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      'سيتلقّون الطلب، ويبقى القرار لهم بالموافقة أو الرفض.';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return 'سيرى $child الطلب وسيكون بإمكانه قبوله أو تجاهله.';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      'سيتمكنون من القراءة والنشر هناك إلى أن تسحب هذا الإذن.';

  @override
  String get approvalsScreenNotYetButton => 'ليس الآن';

  @override
  String get approvalsScreenAllowButton => 'السماح';

  @override
  String get approvalsScreenForwardDirectMessageFallback => 'رسالة مباشرة';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إعادة توجيه $count رسالة',
      many: 'إعادة توجيه $count رسالة',
      few: 'إعادة توجيه $count رسائل',
      two: 'إعادة توجيه رسالتين',
      one: 'إعادة توجيه رسالة واحدة',
      zero: 'إعادة توجيه $count رسائل',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'لا توجد محادثات أخرى بعد';

  @override
  String get approvalsScreenForwardNoMatches => 'لا توجد نتائج مطابقة';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'حتى $max محادثات في كل مرة';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'ابحث في المحادثات';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'إلغاء تحديد $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'تحديد $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'زائلة';

  @override
  String get approvalsScreenForwardSendSemantic => 'إرسال';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إرسال إلى $count',
      many: 'إرسال إلى $count',
      few: 'إرسال إلى $count',
      two: 'إرسال إلى $count',
      one: 'إرسال إلى $count',
      zero: 'إرسال',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => 'الحسابات المرتبطة';

  @override
  String get linkedAccountsScreenSubtitle =>
      'الحسابات التي ربطتها بهذا الحساب لتتمكن من تسجيل الدخول دون كلمة مرور.';

  @override
  String get linkedAccountsScreenEmptyState =>
      'لا يوجد ما يمكن ربطه على هذا الجهاز.';

  @override
  String get linkedAccountsScreenStatusChecking => 'جارٍ التحقق…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return 'يمكنك تسجيل الدخول باستخدام $provider من أي جهاز من أجهزتك.';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return 'أضف $provider حتى لا تضطر إلى كتابة كلمة المرور.';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return 'إلغاء ربط $provider';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => 'إلغاء الربط';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return 'أدخل كلمة المرور لإيقاف تسجيل الدخول باستخدام $provider.';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return 'ربط $provider';
  }

  @override
  String get linkedAccountsScreenLinkAction => 'ربط';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return 'أدخل كلمة المرور لإضافة $provider كوسيلة لتسجيل الدخول.';
  }

  @override
  String get linkedAccountsScreenPillChecking => 'جارٍ التحقق';

  @override
  String get linkedAccountsScreenPillLinked => 'مرتبط';

  @override
  String get linkedAccountsScreenPillNotLinked => 'غير مرتبط';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => 'صوت';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'فيديو';

  @override
  String get linkedAccountsScreenCallSheetTitle => 'بدء مكالمة';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle =>
      'الاتصال بالجميع';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      'اتصال بجميع أعضاء هذه الغرفة';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle => 'اختيار أشخاص';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle =>
      'اختر من تريد دعوته';

  @override
  String get linkedAccountsScreenCallSheetCallFullError =>
      'المكالمة ممتلئة (بحد أقصى 6 أشخاص)';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError =>
      'تعذّر بدء المكالمة';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle => 'دعوة إلى المكالمة';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers =>
      'لا يوجد أعضاء آخرون هنا';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => 'اختر أشخاصًا';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => 'بدء المكالمة';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return 'بدء المكالمة ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => 'أهلاً';

  @override
  String get childPairScreenGreetingLine2 => 'بك.';

  @override
  String get childPairScreenIntro =>
      'اطلب من ولي أمرك فتح تطبيق MonkeyHub والنقر على \"إقران جهاز\"، ثم امسح رمزه ضوئيًا، أو اكتب الأرقام الستة التي يُمليها عليك.';

  @override
  String get childPairScreenOrDivider => 'أو';

  @override
  String get childPairScreenGenericError => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get profileScreenDeleteAccountFailed => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get childPairScreenAccountGoneError => 'هذا الحساب لم يعد موجودًا.';

  @override
  String get childPairScreenScanButtonLabel => 'امسح رمزه ضوئيًا';

  @override
  String get childPairScreenNoCameraMessage =>
      'لا توجد كاميرا هنا. أدخل الأرقام الستة بدلاً من ذلك.';

  @override
  String get childPairScreenStopScanning => 'إيقاف المسح';

  @override
  String get childPairScreenSubmitButtonLabel => 'دعني أدخل';

  @override
  String get childPairScreenBackToSignIn => '→ العودة إلى تسجيل الدخول';

  @override
  String get fileMessageUnavailable => 'الملف لم يعد متاحًا';

  @override
  String get fileMessageOpenFailed => 'تعذّر فتح هذا الملف';

  @override
  String get fileMessageDefaultName => 'مستند';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return 'حفظ $name';
  }

  @override
  String fileMessageViewSemanticLabel(Object name) {
    return 'عرض $name';
  }

  @override
  String get textFileViewerDownloadTooltip => 'تنزيل';

  @override
  String get textFileViewerTruncatedNotice =>
      'يتم عرض جزء من هذا الملف. نزّله لرؤية الباقي.';

  @override
  String get fileMessageUploadFailedLabel => 'فشل الإرسال';

  @override
  String get fileMessageSendingLabel => 'جارٍ الإرسال…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · جارٍ الإرسال…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return 'منذ $count د';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return 'منذ $count س';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return 'منذ $count يوم';
  }

  @override
  String get fileMessageStandardBadge => 'عادية';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة بانتظارك · اضغط للعرض',
      many: '$count رسالة بانتظارك · اضغط للعرض',
      few: '$count رسائل بانتظارك · اضغط للعرض',
      two: 'رسالتان بانتظارك · اضغط للعرض',
      one: 'رسالة واحدة بانتظارك · اضغط للعرض',
      zero: 'لا رسائل بانتظارك · اضغط للعرض',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => 'قبول';

  @override
  String get fileMessageDeclineButton => 'رفض';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'أُرسل $ago';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة أرسلتها بانتظار القبول',
      many: '$count رسالة أرسلتها بانتظار القبول',
      few: '$count رسائل أرسلتها بانتظار القبول',
      two: 'رسالتان أرسلتهما بانتظار القبول',
      one: 'رسالة واحدة أرسلتها بانتظار القبول',
      zero: 'لا رسائل أرسلتها بانتظار القبول',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => 'إلغاء الطلب';

  @override
  String get destructiveSheetCannotBeUndone => 'لا يمكن التراجع عن هذا';

  @override
  String get destructiveSheetCancelSemanticLabel => 'إلغاء';

  @override
  String get destructiveSheetCancelButtonLabel => 'إلغاء';

  @override
  String get destructiveSheetHideLabel => 'إخفاء';

  @override
  String get destructiveSheetViewLabel => 'عرض';

  @override
  String get destructiveSheetPairingMintError =>
      'تعذّر إنشاء الرمز. حاول مرة أخرى.';

  @override
  String get destructiveSheetPairingReleaseTitle => 'تحرير';

  @override
  String get destructiveSheetPairingPairTitle => 'إقران';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return 'على هاتف $name، افتح ملفه الشخصي، واضغط على \"إرجاع الهاتف\"، ثم اكتب هذه الأرقام.';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return 'على هاتف $name، افتح تطبيق MonkeyHub وامسح هذا الرمز، أو اكتب الأرقام.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'انتهت صلاحية هذا الرمز';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'ينتهي خلال $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'رمز جديد';

  @override
  String get destructiveSheetPairingOneUseNote =>
      'استخدام واحد فقط. إنشاء رمز جديد يلغي الرمز القديم.';

  @override
  String get deepOceanThemeAttachButtonLabel => 'إرفاق';

  @override
  String get deepOceanThemeCameraButtonLabel => 'الكاميرا';

  @override
  String get deepOceanThemeSendButtonLabel => 'إرسال';

  @override
  String get deepOceanThemeEphemeralHint => 'اهمس بشيء';

  @override
  String get deepOceanThemeDefaultHint => 'قل شيئًا';

  @override
  String get deepOceanThemeMessageHint => 'رسالة';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'لم يعد هذا الملف موجودًا';

  @override
  String get photoChromeMediaYouLabel => 'أنت';

  @override
  String get photoChromeCloseSemanticLabel => 'إغلاق';

  @override
  String get photoChromeFillToggleSemanticLabel =>
      'ملء الشاشة أو احتواء الصورة';

  @override
  String get photoChromeShowInChatSemanticLabel => 'عرض في المحادثة';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return 'العنصر $current من $total';
  }

  @override
  String photoTrayCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صورة',
      many: '$count صورة',
      few: '$count صور',
      two: 'صورتان',
      one: 'صورة واحدة',
      zero: 'لا صور',
    );
    return '$_temp0';
  }

  @override
  String get photoDeckBackToFirst => 'العودة إلى الأولى';

  @override
  String get inlinePickerCommentHint => 'أضف تعليقًا أو أرسل';

  @override
  String get attachmentMenuGalleryLabel => 'المعرض';

  @override
  String inlinePickerVideoCompressNote(String size) {
    return 'أكبر من $size، لذا سيُضغط قبل الإرسال';
  }

  @override
  String messageMenuAlbumAll(int count) {
    return 'الكل ($count)';
  }

  @override
  String get messageMenuAlbumOne => 'هذا فقط';

  @override
  String replyAlbumItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عناصر',
      one: 'عنصر واحد',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => 'تجاهل هذه الصور';

  @override
  String get photoTrayRemoveSemanticLabel => 'إزالة هذه الصورة';

  @override
  String get photoTrayEditSemanticLabel => 'قص الصورة أو الرسم عليها';

  @override
  String get photoTrayAddMoreSemanticLabel => 'إضافة المزيد من الصور';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'يمكنك إرسال $count صور في المرة الواحدة';
  }

  @override
  String get photoTrayLoadFailedSnack => 'تعذّر فتح بعض تلك الصور';

  @override
  String get mediaPickFailedMessage => 'تعذّر فتحه. جرّب اختياره مرة أخرى';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name يكتب الآن';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1 و$name2 يكتبان الآن';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1، $name2 +$extra يكتبون الآن';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => 'مكالمة واردة';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'مكالمة فيديو واردة';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'مكالمة صوتية واردة';

  @override
  String get typingIndicatorDeclineButtonLabel => 'رفض';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'جارٍ الرفض…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'قبول';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'جارٍ الاتصال…';

  @override
  String get messageStampNavigationTitle => 'التنقل.';

  @override
  String get messageStampNavigationSubtitle =>
      'طريقة تنقلك بين المحادثة والاستكشاف والخلاصة والإعدادات';

  @override
  String get messageStampRadialOrbLabel => 'كرة شعاعية';

  @override
  String get messageStampRadialOrbDescription =>
      'اضغط مطوّلاً واسحب من الزاوية. سكون هادئ، وإيماءة تعتاد عليها شيئًا فشيئًا.';

  @override
  String get messageStampBottomPillLabel => 'كبسولة سفلية';

  @override
  String get messageStampBottomPillDescription =>
      'نقرة تقليدية. ظاهرة دائمًا، ولا تحتاج إلى تعلّم.';

  @override
  String get messageStampActiveLabel => 'نشط';

  @override
  String get messageStampUploadingLabel => 'جارٍ الرفع';

  @override
  String get messageStampSendingLabel => 'جارٍ الإرسال';

  @override
  String get messageStampFailedToSendLabel => 'فشل الإرسال';

  @override
  String get messageStampSentLabel => 'تم الإرسال';

  @override
  String get messageStampDeliveredLabel => 'تم التسليم';

  @override
  String get messageStampSeenLabel => 'تمت المشاهدة';

  @override
  String get messageStampSavedLabel => 'محفوظة';

  @override
  String messageStampCountdownSeconds(Object count) {
    return '$countث';
  }

  @override
  String messageStampCountdownMinutes(Object count) {
    return '$countد';
  }

  @override
  String get voiceRecorderScreenMicPermissionDeniedSnackbar =>
      'تم رفض إذن الميكروفون';

  @override
  String get voiceRecorderScreenStatusRecording => 'جارٍ التسجيل';

  @override
  String get voiceRecorderScreenStatusReady => 'جاهز';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'اضغط للبدء';

  @override
  String get voiceRecorderScreenReRecordButton => 'إعادة التسجيل';

  @override
  String get voiceRecorderScreenStopButton => 'إيقاف';

  @override
  String get voiceRecorderScreenSendButton => 'إرسال';

  @override
  String get voiceRecorderScreenRecordButton => 'تسجيل';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => 'الجميع';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => 'يُنبّه الجميع';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => 'المالك';

  @override
  String get releaseDeviceScreenFallbackChildName => 'الطفل';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return 'سيسجّل هذا خروج $name من هذا الهاتف ويعيده؛ يعود الهاتف إلى شاشة تسجيل الدخول المعتادة، ويصبح بإمكان أي شخص استخدامه.';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'يظل حسابهم ورسائلهم وأصدقاؤهم محفوظين بالكامل. ويمكنهم تسجيل الدخول مجددًا في أي وقت.';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return 'اطلب من أحد أولياء الأمور فتح MonkeyHub، وإيجاد $name ضمن العائلة، ثم النقر على «تحرير».';
  }

  @override
  String get releaseDeviceScreenOrDivider => 'أو';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      'إذا كان هذا هو الهاتف الوحيد، يمكن لأحد أولياء الأمور تسجيل الدخول هنا بدلاً من ذلك.';

  @override
  String get releaseDeviceScreenUsernameHint => 'اسم مستخدم ولي الأمر';

  @override
  String get releaseDeviceScreenPasswordHint => 'كلمة مرور ولي الأمر';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => 'تسجيل الخروج';

  @override
  String get releaseDeviceScreenChecking => 'جارٍ التحقق…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return 'تسجيل خروج $name';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => 'أعد هذا الهاتف';

  @override
  String get releaseDeviceScreenErrorCodeExpired =>
      'انتهت صلاحية هذا الرمز. اطلب رمزًا جديدًا.';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      'لم يعمل هذا الرمز. ربما يكون قد استُخدم من قبل.';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      'لم ينجح ذلك. تحقق من اسم المستخدم وكلمة المرور.';

  @override
  String get releaseDeviceScreenErrorGeneric => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get activeCallPillMoveHereSemanticLabel =>
      'نقل المكالمة إلى هذا الجهاز';

  @override
  String activeCallPillCallWith(Object name) {
    return 'مكالمة مع $name';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return 'على $device';
  }

  @override
  String get activeCallPillMoveHereLabel => 'نقل هنا';

  @override
  String get activeCallPillUnknownCaller => 'غير معروف';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'محاكي iOS';

  @override
  String get activeCallPillPlatformAndroid => 'جهاز Android';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'كمبيوتر Windows';

  @override
  String get activeCallPillPlatformLinux => 'جهاز Linux';

  @override
  String get activeCallPillPlatformBrowser => 'متصفح';

  @override
  String get activeCallPillPlatformOther => 'جهاز آخر';

  @override
  String get activeCallPillPinnedHeader => 'الرسائل المثبتة';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'الرسائل المثبتة · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'لم يعد هناك أي شيء مثبّت';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'الانتقال إلى الرسالة من $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'إلغاء تثبيت الرسالة من $name';
  }

  @override
  String get callButtonErrorBusy => 'مشغول في مكالمة أخرى';

  @override
  String get callButtonErrorCallFailed => 'تعذّر بدء المكالمة';

  @override
  String get callButtonErrorNotMember => 'لست عضوًا في هذه الغرفة';

  @override
  String get callButtonErrorGeneric => 'تعذّر بدء المكالمة';

  @override
  String get callButtonAlreadyOnCall => 'أنت بالفعل في مكالمة';

  @override
  String get callButtonBusyElsewhere => 'هناك مكالمة جارية على جهاز آخر';

  @override
  String get callButtonVoiceCallTooltip => 'مكالمة صوتية';

  @override
  String get callButtonVideoCallTooltip => 'مكالمة فيديو';

  @override
  String get callButtonTooltip => 'مكالمة';

  @override
  String get callButtonReplyStyleTitle => 'نمط الرد.';

  @override
  String get callButtonReplyStyleSubtitle => 'كيف يعرض الرد الرسالة الأصلية';

  @override
  String get callButtonReplyStylePhantomEchoLabel => 'صدى شبحي';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      'تطفو فقاعة شبحية للرسالة الأصلية في الأعلى، مع خط ربط منحنٍ وأيقونة التفرع عند نقطة الالتقاء.';

  @override
  String get callButtonReplyStyleStickyNoteLabel => 'ملاحظة لاصقة';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      'بطاقة بأسلوب بولارويد مائلة قليلاً، مقصوصة عند زاوية الفقاعة.';

  @override
  String get callButtonReplyStyleComicTailLabel => 'ذيل كوميكس';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      'فقاعة مصغّرة للرسالة الأصلية بذيل مثلث على طراز الكوميكس يشير إلى الأسفل.';

  @override
  String get callButtonReplyStyleClassicLabel => 'كلاسيكي';

  @override
  String get callButtonReplyStyleClassicDescription =>
      'كبسولة اقتباس بلون مميز، مع شريط ربط وصورة رمزية: المظهر المألوف بطراز واتساب.';

  @override
  String get callButtonReplyStyleActiveBadge => 'نشط';

  @override
  String get callButtonReplyPreviewSampleMessage =>
      'بالمناسبة، هل رأيت العرض التجريبي الجديد؟';

  @override
  String get callButtonReplyPreviewSampleReply =>
      'نعم، هذا التمويه رائع فعلاً.';

  @override
  String get childSetupScreenErrorPickUsername => 'اختر اسم مستخدم له.';

  @override
  String get childSetupScreenErrorUsernameTaken =>
      'اسم المستخدم هذا مُستخدَم بالفعل.';

  @override
  String get childSetupScreenErrorChildNotAllowed =>
      'يمكن لحساب ولي الأمر فقط إضافة طفل.';

  @override
  String get childSetupScreenErrorGeneric =>
      'تعذّر إنشاء الحساب. حاول مرة أخرى.';

  @override
  String get childSetupScreenTitle => 'إضافة طفل';

  @override
  String get childSetupScreenHeading => 'من\nهو؟';

  @override
  String get childSetupScreenNameLabel => 'الاسم';

  @override
  String get childSetupScreenNameHint => 'الاسم الذي تناديه به';

  @override
  String get childSetupScreenUsernameLabel => 'اسم المستخدم';

  @override
  String get childSetupScreenUsernameHint => 'كيف يعثر عليه الأصدقاء';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'ماذا يحصل عليه';

  @override
  String get childSetupScreenBulletTalkImmediately =>
      'يمكنه التحدث معك ومع إخوته وأخواته فورًا.';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      'أما كل شخص آخر فيحتاج إلى موافقتك أولاً، سواء الذين يطلب التواصل معهم، أو الذين يطلبون التواصل معه.';

  @override
  String get childSetupScreenBulletPublicRoomsOff =>
      'الغرف العامة معطّلة إلى أن تقوم بتفعيلها.';

  @override
  String get childSetupScreenBulletCantSignOut =>
      'لا يمكنه تسجيل الخروج، وبإمكانك دائمًا متابعة أحواله.';

  @override
  String get childSetupScreenCreateButton => 'إنشاء + إقران';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return 'مراسلة $name';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => 'مطلوب';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'عضو';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'عرض الكل $count';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return 'عرض الكل $count';
  }

  @override
  String get bubbleStyleScreenTitle => 'نمط الفقاعة.';

  @override
  String get bubbleStyleScreenSubtitle => 'الشكل الذي تصل به كلماتك';

  @override
  String get bubbleStyleScreenTailedLabel => 'بذيل';

  @override
  String get bubbleStyleScreenTailedDescription =>
      'يُنهي الذيل كل سلسلة رسائل متتالية، وتلتحم الصفوف التي فوقه في كتلة واحدة.';

  @override
  String get bubbleStyleScreenSoftLabel => 'ناعم';

  @override
  String get bubbleStyleScreenSoftDescription =>
      'بدون ذيل. تتماسك مجموعة الرسائل عبر زواياها الداخلية المشدودة فقط.';

  @override
  String get bubbleStyleScreenPillLabel => 'كبسولة';

  @override
  String get bubbleStyleScreenPillDescription =>
      'كبسولات مستديرة بالكامل، متطابقة في كل صف.';

  @override
  String get bubbleStyleScreenSlabLabel => 'كتلة';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'زوايا مربّعة: حادة، مطبوعة، مقصودة.';

  @override
  String get bubbleStyleScreenActiveBadge => 'نشط';

  @override
  String get bubbleStyleScreenPreviewQuestion => 'حسنًا، كيف يبدو؟';

  @override
  String get bubbleStyleScreenPreviewReplyOne => 'أفضل';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => 'أفضل بكثير';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => 'فيديو';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => 'صورة';

  @override
  String get incomingGroupCallScreenCallFullError =>
      'هذه المكالمة الواردة ممتلئة (الحد الأقصى 6 أشخاص)';

  @override
  String get incomingGroupCallScreenJoinFailedError =>
      'تعذّر الانضمام إلى المكالمة الواردة';

  @override
  String get incomingGroupCallScreenDefaultRoomName => 'مكالمة جماعية واردة';

  @override
  String get incomingGroupCallScreenDefaultStarterName => 'شخص ما';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return 'بدأ $starter مكالمة فيديو';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return 'بدأ $starter مكالمة صوتية';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '$count منضمّون بالفعل';
  }

  @override
  String get incomingGroupCallScreenDismissButton => 'رفض';

  @override
  String get incomingGroupCallScreenJoinButton => 'انضمام';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محادثة',
      many: '$count محادثة',
      few: '$count محادثات',
      two: 'محادثتان',
      one: 'محادثة واحدة',
      zero: '$count محادثة',
    );
    return '$_temp0';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      many: '$count رسالة',
      few: '$count رسائل',
      two: 'رسالتان',
      one: 'رسالة واحدة',
      zero: '$count رسالة',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      'آخر رسالة منذ لحظات';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'آخر رسالة منذ $hours ساعة';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'آخر رسالة أمس';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'آخر رسالة منذ $days أيام';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'آخر رسالة منذ فترة';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'سحب';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return 'إبعاد $contactName عن $childName؟';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'لن يتمكّنا من التواصل مع بعضهما، وستُحذف محادثتهما معه.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'لن يتمكّنا من التواصل مع بعضهما. لن يُخبَر $contactName بذلك.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return 'سيتم حذف $chats · $messages';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      'ستُحذف من الطرفين، بما في ذلك الصور والملاحظات الصوتية. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كما يشتركان في $count غرفة',
      many: 'كما يشتركان في $count غرفة',
      few: 'كما يشتركان في $count غرف',
      two: 'كما يشتركان في غرفتين',
      one: 'كما يشتركان في غرفة واحدة',
      zero: 'لا يشتركان في أي غرفة',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'تبقى هذه الغرف كما هي. إذا كنت تريد التخلص منها، فأزلها من قائمة الغرف أدناه.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'الإزالة والحذف';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'يزيل $contactName ويمسح $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'يزيل $contactName من القائمة المسموح بها.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'إلغاء';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => 'إلغاء';

  @override
  String get groupCallBannerCallFullError =>
      'المكالمة ممتلئة (الحد الأقصى 6 أشخاص)';

  @override
  String get groupCallBannerJoinFailedError => 'تعذر الانضمام إلى المكالمة';

  @override
  String get groupCallBannerUnknownParticipant => 'شخص ما';

  @override
  String get groupCallBannerOngoingVideoCall => 'مكالمة فيديو جارية';

  @override
  String get groupCallBannerOngoingVoiceCall => 'مكالمة صوتية جارية';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra في المكالمة';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => 'الانضمام إلى المكالمة';

  @override
  String get groupCallBannerJoinButtonLabel => 'انضمام';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'الانضمام إلى الغرفة';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عضو',
      many: '$count عضوًا',
      few: '$count أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
      zero: 'لا يوجد أعضاء',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => 'كلمة المرور';

  @override
  String get groupCallBannerPasswordHint => 'عبارة المرور';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'انضمام';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'انضمام';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'إلغاء';

  @override
  String get groupCallBannerCancelButtonLabel => 'إلغاء';

  @override
  String get viewOnceViewerBadgeLabel => 'مشاهدة واحدة';

  @override
  String get socialButtonDividerOr => 'أو';

  @override
  String get socialButtonGoogleContinue => 'المتابعة باستخدام Google';

  @override
  String get discoverListsPeopleTitle => 'الأصدقاء';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count شخص',
      many: '$count شخصًا',
      few: '$count أشخاص',
      two: 'شخصان',
      one: 'شخص واحد',
      zero: 'لا يوجد أشخاص',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => 'ابحث في الأصدقاء';

  @override
  String get discoverListsClearFilterSemanticLabel => 'مسح التصفية';

  @override
  String get discoverListsNoOneYet => 'لا أحد بعد';

  @override
  String discoverListsNoMatches(Object query) {
    return 'لا أحد يطابق \"$query\"';
  }

  @override
  String get discoverListsRoomsTitle => 'الغرف';

  @override
  String discoverListsRoomsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count غرفة',
      many: '$count غرفة',
      few: '$count غرف',
      two: 'غرفتان',
      one: 'غرفة واحدة',
      zero: 'لا توجد غرف',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterRoomsHint => 'ابحث في غرفك';

  @override
  String get discoverListsNoRoomsYet => 'لا غرف بعد';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return 'لا غرف تطابق \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'مكالمة صوتية';

  @override
  String get discoverListsVideoCallLabel => 'مكالمة فيديو';

  @override
  String get approvalGateAlreadyAskedLabel => 'تم الطلب مسبقًا';

  @override
  String get approvalGateAskGrownUpLabel => 'اسأل ولي الأمر';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return 'لقد سألت بالفعل عن $what.';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return 'يجب أن يوافق ولي أمرك قبل أن تتمكن من $what.';
  }

  @override
  String get approvalGateDisabledBody => 'أوقف ولي أمرك هذا الخيار مؤقتًا.';

  @override
  String get approvalGateAlreadyAskedFooter =>
      'سيصلهم إشعار بذلك. عد للتحقق قريبًا.';

  @override
  String get approvalGateWillNotifyFooter =>
      'سنخبرهم بذلك. سترى الرد هنا عندما يجيبون.';

  @override
  String get approvalGateTalkToThemFooter =>
      'يمكنك التحدث معهم بشأن ذلك إذا رأيت أنه ينبغي أن يتغير.';

  @override
  String get approvalGateAskButton => 'اسأل';

  @override
  String get approvalGateNotNowButton => 'ليس الآن';

  @override
  String get approvalGateOkButton => 'حسنًا';

  @override
  String get approvalGateWaitingPillLabel => 'بانتظار ولي الأمر';

  @override
  String get reportSheetTitle => 'إبلاغ';

  @override
  String get reportSheetSubtitle => 'أخبرنا بالمشكلة.';

  @override
  String get reportSheetPrivacyNote =>
      'البلاغات سرية، ولن يتم إخطار الشخص الآخر.';

  @override
  String get reportSheetReasonSpamLabel => 'رسائل مزعجة';

  @override
  String get reportSheetReasonSpamDescription =>
      'إعلانات غير مرغوب فيها أو رسائل متكررة';

  @override
  String get reportSheetReasonHarassmentLabel => 'تحرش';

  @override
  String get reportSheetReasonHarassmentDescription => 'استهداف أو تنمّر';

  @override
  String get reportSheetReasonImpersonationLabel => 'انتحال شخصية';

  @override
  String get reportSheetReasonImpersonationDescription =>
      'التظاهر بأنه شخص آخر';

  @override
  String get reportSheetReasonInappropriateLabel => 'غير لائق';

  @override
  String get reportSheetReasonInappropriateDescription =>
      'محتوى جنسي أو عنيف أو غير قانوني';

  @override
  String get reportSheetReasonOtherLabel => 'أخرى';

  @override
  String get reportSheetReasonOtherDescription => 'شيء آخر';

  @override
  String get reportSheetOtherNoteHint => 'ماذا حدث؟';

  @override
  String get reportSheetSubmitSemanticLabel => 'إرسال البلاغ';

  @override
  String get reportSheetSubmitButton => 'إرسال';

  @override
  String get reportSheetUpdateRequiredTitle => 'التحديث مطلوب';

  @override
  String get reportSheetUpdateAvailableTitle => 'التحديث متاح';

  @override
  String get reportSheetUpdateMandatoryBody =>
      'هذا الإصدار قديم جدًا ولم يعد يعمل بشكل صحيح. حدّث التطبيق للمتابعة.';

  @override
  String get reportSheetUpdateAvailableBody => 'يتوفر إصدار أحدث من MonkeyHub.';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => 'تحديث';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'يفتح TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'يفتح App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'يفتح Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage => 'يفتح صفحة التنزيل';

  @override
  String get reportSheetUpdateActionReloads => 'يعيد التحميل بالإصدار الجديد';

  @override
  String get reportSheetUpdateActionInstallsInApp => 'يثبّت دون مغادرة التطبيق';

  @override
  String get reportSheetUpdateActionRestarts => 'يثبّت ويعيد تشغيل التطبيق';

  @override
  String reportSheetUpdateDownloading(int percent) {
    return 'جارٍ تنزيل التحديث… $percent٪';
  }

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'لاحقًا';

  @override
  String get reportSheetUpdateLaterButton => 'لاحقًا';

  @override
  String get roomFilterBarAllChipLabel => 'الكل';

  @override
  String roomFilterBarChipCountSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دردشة',
      many: '$count دردشة',
      few: '$count دردشات',
      two: 'دردشتان',
      one: 'دردشة واحدة',
      zero: '$count دردشة',
    );
    return '$label، $_temp0';
  }

  @override
  String composerReplyCardReplyingToLabel(Object name) {
    return 'الرد على $name';
  }

  @override
  String get roomCardLockedBadge => 'مقفل';

  @override
  String get roomCardTimeAgoJustNow => 'الآن';

  @override
  String roomCardTimeAgoSeconds(Object seconds) {
    return '$secondsث';
  }

  @override
  String roomCardTimeAgoMinutes(Object minutes) {
    return '$minutesد';
  }

  @override
  String roomCardTimeAgoHours(Object hours) {
    return '$hoursس';
  }

  @override
  String roomCardTimeAgoDays(Object days) {
    return '$daysي';
  }

  @override
  String roomCardTimeAgoWeeks(Object weeks) {
    return '$weeksأ';
  }

  @override
  String roomCardStartedAgo(Object ago) {
    return 'أُنشئت قبل $ago';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count بالداخل';
  }

  @override
  String get roomCardMessagesFadeLabel => 'الرسائل تتلاشى';

  @override
  String get roomCardEnterLabel => '↗ دخول';

  @override
  String get roomCardBlockedScreenTitle => 'المحظورون';

  @override
  String get roomCardBlockedEmptyState => 'لم تحظر أحدًا.';

  @override
  String get roomCardUnblockButton => 'إلغاء الحظر';

  @override
  String get attachmentMenuPhotoLabel => 'صورة';

  @override
  String get attachmentMenuVideoLabel => 'فيديو';

  @override
  String get attachmentMenuCameraLabel => 'كاميرا';

  @override
  String get attachmentMenuVoiceLabel => 'صوت';

  @override
  String get attachmentMenuFileLabel => 'ملف';

  @override
  String get attachmentMenuConnectionRetrying => 'جارٍ إعادة المحاولة…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'تعذّر الوصول إلى الخادم · اضغط لإعادة المحاولة';

  @override
  String get attachmentMenuConnectionReconnecting => 'جارٍ إعادة الاتصال…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'إعادة محاولة الاتصال';

  @override
  String get roomGridTileEmptyLastMessage => 'هادئ حتى الآن';

  @override
  String get roomGridTileMemberCountLabel => 'داخل';

  @override
  String get roomGridTileThemeChipLabel => 'المظهر';

  @override
  String get bulkActionBarCancelLabel => 'إلغاء';

  @override
  String get bulkActionBarSelectMessagesLabel => 'اختر الرسائل';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة محددة',
      many: '$count رسالة محددة',
      few: '$count رسائل محددة',
      two: 'رسالتان محددتان',
      one: 'رسالة واحدة محددة',
      zero: 'لا رسائل محددة',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarForwardLabel => 'إعادة توجيه';

  @override
  String get bulkActionBarDeleteLabel => 'حذف';

  @override
  String get bulkActionBarJumpBackLabel => 'رجوع';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return 'رجوع · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel =>
      'العودة إلى المكان الذي انتقلت منه';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return 'العودة إلى المكان الذي انتقلت منه، و$depth خطوات متبقية';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote => 'لن يتم إشعارهم.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'أنتما صديقان حاليًا. الحظر يلغي هذه الصداقة، لذا ستحتاج إلى إرسال طلب صداقة جديد لإعادة التواصل لاحقًا.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'سيختفون من نتائج بحثك ولن يتمكنوا من مراسلتك.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'حظر';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return 'حظر $name؟';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تشترك معه في $count غرفة',
      many: 'تشترك معه في $count غرفة',
      few: 'تشترك معه في $count غرف',
      two: 'تشترك معه في غرفتين',
      one: 'تشترك معه في غرفة واحدة',
      zero: 'لا تشترك معه في أي غرفة',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'تبقى هذه الغرف كما هي دون أي تغيير. يمكنك مغادرة أي منها بنفسك من إعدادات كل غرفة.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'حظر';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'إلغاء الصداقة والحظر. تبقى المحادثات السابقة في أرشيفك.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'يختفون من نتائج البحث ولا يمكنهم الوصول إليك.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'حظر وحذف المحادثة الخاصة';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'كما يمسح محادثتك الخاصة معه بالكامل: تُحذف كل رسالة وتفاعل وملف وسائط.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'إلغاء';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'إلغاء';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle =>
      'إظهار المكالمات الواردة على شاشة القفل';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      'لكي ترن المكالمات الواردة مثل مكالمة هاتفية حقيقية عند إطفاء الشاشة، يحتاج MonkeyHub إلى تفعيل ميزة \"الإشعارات على كامل الشاشة\". الشاشة التالية ستنقلك مباشرة إلى هذا الخيار.';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle => 'لا تفوّت أي مكالمة';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      'بعض الهواتف توقف التطبيقات مؤقتًا في الخلفية لتوفير البطارية، ما قد يؤدي إلى كتم المكالمات الواردة. اسمح لتطبيق MonkeyHub بالعمل دون قيود لضمان وصول جميع المكالمات.';

  @override
  String get bulkActionBarDialogNotNowButton => 'ليس الآن';

  @override
  String get bulkActionBarDialogContinueButton => 'متابعة';

  @override
  String get reactionBubbleJumpToLatestLabel => 'الانتقال إلى الأحدث';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel => 'الانتقال إلى الأحدث';

  @override
  String get reactionBubblePickerTitle => 'تفاعل';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'لا توجد عناصر حديثة بعد';

  @override
  String get reactionBubbleSearchHint => 'ابحث عن إيموجي';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'لا توجد نتائج';

  @override
  String get reactionBubbleSearchBackSemanticLabel => 'العودة إلى الإيموجي';

  @override
  String get reactionBubblePasswordHint => 'كلمة المرور';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return 'الانضمام إلى $roomName';
  }

  @override
  String get enterPublicRoomAskFailedMessage =>
      'تعذّر إرسال الطلب الآن. حاول مرة أخرى';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'كلمة المرور غير صحيحة';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'تعذّر الانضمام. حاول مرة أخرى';

  @override
  String get feedBoardTitle => 'اليوم';

  @override
  String feedBoardEditionLabel(Object number) {
    return 'العدد $number';
  }

  @override
  String get feedBoardHighlightsLabel => 'أبرز اللحظات';

  @override
  String get feedBoardHighlightsEmpty => 'لا شيء تم التقاطه اليوم بعد';

  @override
  String get feedBoardPuzzleLabel => 'اللغز';

  @override
  String get feedBoardPuzzleEmpty => 'لغز اليوم ليس جاهزًا بعد';

  @override
  String get feedBoardStandingsLabel => 'نقاط الحياة';

  @override
  String get feedBoardStandingsEmpty => 'لا نقاط على اللوحة اليوم';

  @override
  String get feedBoardActivityLabel => 'النشاط';

  @override
  String get feedBoardActivityEmpty => 'هادئ حتى الآن اليوم';

  @override
  String get feedBoardActivityNoFriends => 'أضف صديقًا وسيظهر يومه هنا';

  @override
  String get feedBoardLoadFailed => 'تعذّر تحميل اللوحة. أعد المحاولة بعد قليل';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'عامة';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'خاصة';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'منضم';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'مؤقتة · $duration';
  }

  @override
  String enterPublicRoomEphemeralSecondsShort(Object seconds) {
    return '$secondsث';
  }

  @override
  String enterPublicRoomEphemeralMinutesShort(Object minutes) {
    return '$minutesد';
  }

  @override
  String enterPublicRoomEphemeralHoursShort(Object hours) {
    return '$hoursس';
  }

  @override
  String get roomBadgePublicTooltip =>
      'يمكن لأي شخص العثور على هذه الغرفة والانضمام إليها';

  @override
  String get roomBadgePrivateTooltip => 'بالدعوة فقط، ولا تظهر في الاستكشاف';

  @override
  String get roomBadgeLockedTooltip => 'تحتاج إلى كلمة مرور الغرفة للانضمام';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return 'تختفي الرسائل بعد $duration';
  }

  @override
  String get roomBadgeJoinedTooltip => 'أنت بالفعل في هذه الغرفة';

  @override
  String get roomInfoSheetDetailsLabel => 'التفاصيل';

  @override
  String get roomInfoSheetNoDescription => 'لا يوجد وصف بعد';

  @override
  String get roomInfoSheetCreatedLabel => 'تاريخ الإنشاء';

  @override
  String get countBadgeShowPasswordTooltip => 'إظهار كلمة المرور';

  @override
  String get countBadgeHidePasswordTooltip => 'إخفاء كلمة المرور';

  @override
  String get countBadgeProtectedLabel => 'محمي';

  @override
  String get countBadgeCaptureShieldActiveBody =>
      'تسجيل الشاشة أو نسخها نشط حاليًا.';

  @override
  String get countBadgeCaptureShieldReassurance =>
      'لا يمكن للتسجيل رؤية محادثاتك.';

  @override
  String get linkOpenerCouldNotOpenLink => 'تعذّر فتح الرابط';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel => 'إعداد عبارة استرداد';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'لا توجد عبارة استرداد، ولن تتمكن من العودة إلى حسابك.';

  @override
  String get destinationsChatLabel => 'دردشة';

  @override
  String get destinationsChatShort => 'دردشة';

  @override
  String get destinationsDiscoverLabel => 'استكشاف';

  @override
  String get destinationsDiscoverShort => 'استكشاف';

  @override
  String get destinationsFeedLabel => 'خلاصة';

  @override
  String get destinationsFeedShort => 'خلاصة';

  @override
  String get destinationsSettingsLabel => 'الإعدادات';

  @override
  String get destinationsSettingsShort => 'إعدادات';

  @override
  String get familyRequestStageSenderGuardianLabel => 'بانتظار ولي أمر';

  @override
  String get familyRequestStageRecipientLabel => 'بانتظارهم';

  @override
  String get roomContentTabLabelMedia => 'الوسائط';

  @override
  String get roomContentTabLabelFiles => 'الملفات';

  @override
  String get roomContentTabLabelVoice => 'الصوت';

  @override
  String get roomContentTabLabelLinks => 'الروابط';

  @override
  String get roomContentTabLabelSaved => 'المحفوظة';

  @override
  String get roomContentTabHeaderMedia => 'الوسائط';

  @override
  String get roomContentTabHeaderFiles => 'الملفات';

  @override
  String get roomContentTabHeaderVoice => 'الصوت';

  @override
  String get roomContentTabHeaderLinks => 'الروابط';

  @override
  String get roomContentTabHeaderSaved => 'المحفوظة';

  @override
  String get roomFacetLabelDms => 'فردي';

  @override
  String get roomFacetLabelGroups => 'جماعات';

  @override
  String get roomFacetLabelPublic => 'عام';

  @override
  String get roomFacetLabelPrivate => 'خاص';

  @override
  String get roomFacetLabelSecret => 'سري';

  @override
  String get roomFacetLabelLocked => 'مقفل';

  @override
  String get roomFacetLabelUnread => 'غير مقروء';

  @override
  String get roomFacetLabelMentions => 'إشارات';

  @override
  String get settingsScreenTitle => 'الإعدادات';

  @override
  String get settingsScreenTagline => 'الشكل. الشعور. أنتَ.';

  @override
  String get settingsScreenAccountHintChild =>
      'الملف الشخصي · الخصوصية · أولياء أمري';

  @override
  String get settingsScreenAccountHintAdult =>
      'الملف الشخصي · العائلة · الحسابات المرتبطة · الخصوصية';

  @override
  String get settingsScreenSectionAppearance => 'المظهر';

  @override
  String get settingsScreenSectionChat => 'المحادثات';

  @override
  String get settingsScreenSectionCompanions => 'الرفاق';

  @override
  String get settingsScreenSectionGeneral => 'عام';

  @override
  String get settingsScreenCheckForUpdatesLabel => 'التحقق من التحديثات';

  @override
  String get settingsScreenUpdateAvailableValue => 'يتوفر تحديث';

  @override
  String get settingsScreenUpdateUpToDateSnackbar => 'لديك أحدث إصدار.';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      'تعذّر التحقق من التحديثات في هذا الإصدار.';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      'تعذّر التحقق من التحديثات. حاول مرة أخرى لاحقًا.';

  @override
  String get settingsScreenSectionNotifications => 'الإشعارات';

  @override
  String get reportProblemRowLabel => 'الإبلاغ عن مشكلة';

  @override
  String get reportProblemRowValue => 'أرسل لنا التفاصيل';

  @override
  String get reportProblemIntro =>
      'أخبرنا بما حدث. تُضاف معلومات التطبيق والجهاز تلقائيًا، ومعها سجل تقني لما كان التطبيق يفعله، وهذا ما يساعدنا في معرفة السبب.';

  @override
  String get reportProblemDescribeLabel => 'ماذا حدث';

  @override
  String get reportProblemDescribeHint => 'الشاشة ترتجف، الأزرار لا تستجيب';

  @override
  String get reportProblemScreenshotsLabel => 'لقطات الشاشة';

  @override
  String get reportProblemAddScreenshot => 'إضافة لقطة شاشة';

  @override
  String get reportProblemDetailsLabel => 'معلوماتك';

  @override
  String get reportProblemCopyDetails => 'نسخ المعلومات';

  @override
  String get reportProblemCopied => 'تم النسخ';

  @override
  String get reportProblemSend => 'إرسال البلاغ';

  @override
  String get reportProblemSent => 'تم إرسال البلاغ. شكرًا لك!';

  @override
  String get reportProblemSendFailed =>
      'لم نتمكّن من إرسال البلاغ. تحقّق من اتصالك وحاول مرة أخرى.';

  @override
  String get reportProblemTooMany =>
      'أرسلت الكثير من البلاغات في وقت قصير. حاول مرة أخرى بعد قليل.';

  @override
  String get reportProblemShakeTitle => 'هل تريد الإبلاغ عن مشكلة؟';

  @override
  String get reportProblemShakeBody => 'لقد هززت هاتفك. هل نفتح شاشة البلاغ؟';

  @override
  String get reportProblemShakeOpen => 'إبلاغ';

  @override
  String get reportProblemShakeDismiss => 'ليس الآن';

  @override
  String get settingsCallDeliveryLockScreenLabel => 'المكالمات على شاشة القفل';

  @override
  String get settingsCallDeliveryBackgroundLabel => 'النشاط في الخلفية';

  @override
  String get settingsCallDeliveryStatusOff => 'اضغط للسماح';

  @override
  String get settingsScreenRowTheme => 'السمة';

  @override
  String get settingsScreenRowAppLogo => 'شعار التطبيق';

  @override
  String get settingsScreenRowGlass => 'الزجاج';

  @override
  String get settingsScreenRowChatList => 'قائمة المحادثات';

  @override
  String get settingsScreenRowNavigation => 'التنقل';

  @override
  String get settingsScreenRowChatStyle => 'نمط المحادثة';

  @override
  String get settingsScreenRowBubbleStyle => 'نمط الفقاعة';

  @override
  String get settingsScreenRowReplyStyle => 'نمط الرد';

  @override
  String get settingsScreenValueScrollList => 'قائمة تمرير';

  @override
  String get settingsScreenValueGridSheet => 'شبكة';

  @override
  String get settingsScreenValueRadialOrb => 'كرة شعاعية';

  @override
  String get settingsScreenValueBottomPill => 'كبسولة سفلية';

  @override
  String get settingsScreenValueCustom => 'مخصص';

  @override
  String settingsScreenValueEdited(Object name) {
    return '$name · معدَّل';
  }

  @override
  String get settingsScreenValueClassic => 'كلاسيكي';

  @override
  String get settingsScreenValueCompact => 'مضغوط';

  @override
  String get settingsScreenValueBubbleTailed => 'مذيّل';

  @override
  String get settingsScreenValueBubbleSoft => 'ناعم';

  @override
  String get settingsScreenValueBubblePill => 'كبسولة';

  @override
  String get settingsScreenValueBubbleSlab => 'كتلة';

  @override
  String get settingsScreenValueReplyPhantomEcho => 'صدى شبحي';

  @override
  String get settingsScreenValueReplyStickyNote => 'ملاحظة لاصقة';

  @override
  String get settingsScreenValueReplyComicTail => 'ذيل كوميدي';

  @override
  String get settingsScreenValueLogoAuto => 'تلقائي';

  @override
  String get settingsScreenValueLogoManual => 'يدوي';

  @override
  String get settingsScreenShowLinkUrlsLabel => 'إظهار عناوين الروابط';

  @override
  String get settingsScreenLinksUrlsOnBody =>
      'تظهر الروابط الأصلية إلى جانب بطاقة المعاينة';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      'حاليًا معاينة فقط: فقاعات أنظف، اضغط للفتح';

  @override
  String get settingsScreenMenuBarLabel => 'أيقونة شريط القوائم';

  @override
  String get settingsScreenMenuBarOnBody =>
      'يبقى MonkeyHub في شريط القوائم مع عدد الرسائل غير المقروءة. انقر عليه لفتح النافذة';

  @override
  String get settingsScreenMenuBarOffBody =>
      'معطّل حاليًا، وأيقونة الـ Dock هي الطريقة الوحيدة لاستعادة نافذة مخفية';

  @override
  String get settingsScreenSectionCalls => 'المكالمات';

  @override
  String get settingsScreenRowVideoQuality => 'جودة الفيديو';

  @override
  String get settingsScreenValueVideoQualityAuto => 'تلقائي';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel => 'إظهار إحصاءات المكالمة';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      'الدقة ومعدل البت والزمن ونسبة فقدان الحزم أثناء المكالمات مباشرةً';

  @override
  String get videoQualityScreenTitle => 'جودة الفيديو';

  @override
  String get videoQualityScreenSubtitle =>
      'اختر الحد الأقصى لدقة الفيديو الصادر';

  @override
  String get videoQualityScreenAutoSubtitle => 'يتكيف تلقائيًا مع اتصالك';

  @override
  String get videoQualityScreenHd1080Subtitle =>
      'دقة عالية جدًا: أوضح، يستخدم بيانات أكثر';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'دقة فائقة الوضوح: الأفضل مع اتصال قوي';

  @override
  String get videoQualityScreenFootnote =>
      'تعتمد الدقة الفعلية على كاميرات كلا الجهازين وحالة الشبكة.';

  @override
  String get callScreenControlOptions => 'المزيد';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => 'تذبذب';

  @override
  String get callScreenStatsLossLabel => 'فقدان';

  @override
  String get callScreenSwapPreviewSemanticLabel => 'تبديل عرض الكاميرا';

  @override
  String get callOptionsSheetTitle => 'خيارات المكالمة';

  @override
  String get settingsScreenPushNotificationsLabel => 'الإشعارات الفورية';

  @override
  String get settingsScreenPushOnBody => 'تنبيهات للرسائل والطلبات الجديدة';

  @override
  String get settingsScreenPushOffBody =>
      'صامت، لن ترى شيئًا إلا عند فتح التطبيق';

  @override
  String get settingsScreenGameRemindersLabel => 'تذكير الألعاب اليومي';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'تنبيه واحد وقت الظهيرة، فقط إن لم تلعب بعد';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'بلا تذكير، الألعاب في مكانها متى فتحت التطبيق';

  @override
  String get authErrorUsernameTaken => 'اسم المستخدم هذا مُستخدَم بالفعل.';

  @override
  String get authErrorUsernameReserved =>
      'اسم المستخدم هذا غير متاح. اختر اسمًا آخر.';

  @override
  String get authErrorDisplayNameReserved =>
      'هذا الاسم غير متاح. اختر اسمًا آخر.';

  @override
  String get authErrorUserNotFound => 'لا يوجد حساب بهذا الاسم.';

  @override
  String get authErrorWrongPassword => 'كلمة المرور خاطئة.';

  @override
  String get authErrorInvalidRecoveryKey =>
      'اسم المستخدم وعبارة الاسترداد لا يتطابقان.';

  @override
  String get authErrorTooManyAttempts =>
      'محاولات كثيرة جدًا. انتظر 15 دقيقة ثم أعد المحاولة.';

  @override
  String get authErrorChildMustPair =>
      'هذا حساب طفل. اطلب من ولي الأمر رمز اقتران.';

  @override
  String get authErrorPairingCodeExpired =>
      'انتهت صلاحية هذا الرمز. اطلب رمزًا جديدًا.';

  @override
  String get authErrorPairingCodeInvalid =>
      'لم يعمل هذا الرمز. ربما يكون قد استُخدم بالفعل.';

  @override
  String get authErrorUseSocialSignIn =>
      'هذا الحساب يسجّل الدخول عبر Apple أو Google. استخدم الأزرار أدناه.';

  @override
  String get authErrorSocialTokenInvalid =>
      'لم تكتمل عملية تسجيل الدخول هذه. يُرجى المحاولة مرة أخرى.';

  @override
  String get authErrorSocialNonceMismatch =>
      'تعذّر إتمام تسجيل الدخول. يُرجى المحاولة مرة أخرى.';

  @override
  String get authErrorSocialMisconfig =>
      'لم يتم إعداد تسجيل الدخول من جانبنا بعد. حاول مرة أخرى لاحقًا.';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      'حساب Apple أو Google هذا مرتبط بالفعل بحساب آخر على MonkeyHub.';

  @override
  String get authErrorSocialAlreadyLinked => 'هذا مرتبط بالفعل بهذا الحساب.';

  @override
  String get authErrorSocialNotLinked => 'هذا غير مرتبط بهذا الحساب.';

  @override
  String get authErrorSocialLastCredential =>
      'هذه هي الوسيلة الوحيدة للدخول إلى هذا الحساب. عيّن كلمة مرور أولًا.';

  @override
  String get authErrorUsernameInvalid =>
      'اختر اسم مستخدم يتراوح طوله بين 1 و32 حرفًا.';

  @override
  String get authErrorUsernameChangedRecently =>
      'لقد غيّرت اسم المستخدم مؤخرًا. يمكنك تغييره مجددًا بعد 30 يومًا من آخر تغيير.';

  @override
  String get authErrorInboxHandleLocked =>
      'هذا الحساب يستقبل بلاغات المشاكل من الجميع، لذا فاسم المستخدم الخاص به ثابت.';

  @override
  String get glassKnobLabelFrost => 'ضبابي';

  @override
  String get glassKnobHintFrost =>
      'مقدار البياض الذي يغطي الزجاج. قلّله ليصبح أكثر شفافية.';

  @override
  String get glassKnobLabelBlur => 'تمويه';

  @override
  String get glassKnobHintBlur =>
      'ضبابي عند الحد الأعلى، وزجاج صافٍ عند الحد الأدنى.';

  @override
  String get glassKnobLabelSaturation => 'تسرب اللون';

  @override
  String get glassKnobHintSaturation =>
      'مقدار اللون الذي يبقى بعد التمويه. بعد القيمة 2 يظهر تأثير البوسترة.';

  @override
  String get glassKnobLabelRimOpacity => 'حافة';

  @override
  String get glassKnobHintRimOpacity => 'سطوع حافة الزجاج. صفر لسطح بلا حدود';

  @override
  String get glassKnobLabelRimWidth => 'سُمك الحافة';

  @override
  String get glassKnobHintRimWidth => 'سماكة خط الحافة.';

  @override
  String get glassKnobLabelShadowOpacity => 'ظل';

  @override
  String get glassKnobHintShadowOpacity => 'إلى أي مدى يطفو السطح فوق ما خلفه.';

  @override
  String get glassKnobLabelShadowBlur => 'انتشار الظل';

  @override
  String get glassKnobHintShadowBlur => 'ظل ناعم وواسع، أو ضيق وحاد.';

  @override
  String get glassKnobLabelShadowY => 'هبوط الظل';

  @override
  String get glassKnobHintShadowY => 'إلى أي عمق ينزل الظل تحت السطح.';

  @override
  String get glassKnobLabelBarMargin => 'هامش جانبي';

  @override
  String get glassKnobHintBarMargin => 'التباعد بين الشريط وحافة الشاشة.';

  @override
  String get glassKnobLabelBarBottom => 'تباعد سفلي';

  @override
  String get glassKnobHintBarBottom =>
      'إلى أي ارتفاع يطفو الشريط عن أسفل الشاشة.';

  @override
  String get glassKnobLabelShellPadH => 'حشو طرفي';

  @override
  String get glassKnobHintShellPadH =>
      'من حافة الشريط إلى أول كبسولة. اجعلها صغيرة وإلا بدت الأطراف معزولة.';

  @override
  String get glassKnobLabelShellPadV => 'حشو علوي';

  @override
  String get glassKnobHintShellPadV => 'من حافة الشريط إلى أعلى الكبسولة.';

  @override
  String get glassKnobLabelIndicatorInset => 'إزاحة الكبسولة';

  @override
  String get glassKnobHintIndicatorInset =>
      'إلى أي عمق تجلس كبسولة التحديد داخل مكانها.';

  @override
  String get glassKnobLabelSegmentPadV => 'حشو الصف';

  @override
  String get glassKnobHintSegmentPadV =>
      'المساحة الفارغة فوق الأيقونة وتسميتها وتحتهما.';

  @override
  String get glassKnobLabelIconLabelGap => 'تباعد الأيقونة';

  @override
  String get glassKnobHintIconLabelGap =>
      'المسافة بين الأيقونة والكلمة الموجودة تحتها';

  @override
  String get glassKnobLabelIconSize => 'حجم الأيقونة';

  @override
  String get glassKnobLabelLabelSize => 'حجم التسمية';

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
  String get settingsScreenRowMotion => 'الحركة';

  @override
  String get settingsScreenValueMotionFull => 'كاملة';

  @override
  String get settingsScreenValueMotionCalm => 'هادئة';

  @override
  String get settingsScreenValueMotionSystemFull => 'مثل الجهاز · كاملة';

  @override
  String get settingsScreenValueMotionSystemCalm => 'مثل الجهاز · هادئة';

  @override
  String get motionScreenTitle => 'الحركة.';

  @override
  String get motionScreenSubtitle => 'مقدار حركة التطبيق';

  @override
  String get motionScreenSystemLabel => 'مثل الجهاز';

  @override
  String get motionScreenSystemSubtitleFull => 'جهازك يسمح بالحركة الآن';

  @override
  String get motionScreenSystemSubtitleCalm => 'جهازك يطلب حركة أقل الآن';

  @override
  String get motionScreenFullLabel => 'كاملة';

  @override
  String get motionScreenFullSubtitle => 'كل انسياب وتوهّج وزخرفة';

  @override
  String get motionScreenCalmLabel => 'هادئة';

  @override
  String get motionScreenCalmSubtitle => 'تتوقف الزخارف، ولا يتغير شيء آخر';

  @override
  String get momentRailCaptureLabel => 'التقاط';

  @override
  String get momentRailYouLabel => 'أنت';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String momentRailPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count لحظة',
      many: '$count لحظة',
      few: '$count لحظات',
      two: 'لحظتان',
      one: 'لحظة واحدة',
      zero: 'لا لحظات',
    );
    return '$_temp0';
  }

  @override
  String momentRailPersonNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جديدة',
      many: '$count جديدة',
      few: '$count جديدة',
      two: 'اثنتان جديدتان',
      one: 'واحدة جديدة',
      zero: 'لا جديد',
    );
    return '$_temp0';
  }

  @override
  String get momentRailAddHighlight => 'أضف لحظة';

  @override
  String get momentTagFate => 'مصادفة';

  @override
  String get momentTagJinx => 'نحس';

  @override
  String get momentTagLuck => 'حظ';

  @override
  String get momentTagCalledIt => 'قلت لكم';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'ما أغرب الصدفة';

  @override
  String get momentTagJinxHint => 'جلبته لنفسك';

  @override
  String get momentTagLuckHint => 'سار الأمر لصالحك';

  @override
  String get momentTagCalledItHint => 'توقّعت ذلك';

  @override
  String get momentTagNpcHint => 'العقل مغلق تمامًا';

  @override
  String get momentComposerTitle => 'لحظة جديدة';

  @override
  String get momentComposerCaptionHint => 'قل شيئًا عنه';

  @override
  String get momentComposerTagPrompt => 'كسبت نقطة؟ أضفها الآن';

  @override
  String get momentComposerCapture => 'الكاميرا';

  @override
  String get momentComposerLibrary => 'المعرض';

  @override
  String get momentComposerRemovePhoto => 'إزالة الصورة';

  @override
  String get momentComposerPost => 'نشر';

  @override
  String get momentComposerErrorDailyCap => 'صارت خمسًا اليوم. أبقِ شيئًا للغد';

  @override
  String get momentComposerErrorNotAllowed => 'أوقف وليّ الأمر مشاركة الصور';

  @override
  String get momentComposerErrorTooLong => 'طويل قليلًا، اختصره';

  @override
  String get momentComposerErrorEmpty => 'أضف صورة أو بضع كلمات';

  @override
  String get momentComposerErrorGeneric => 'تعذّر النشر. حاول مجددًا';

  @override
  String get momentViewerDelete => 'حذف';

  @override
  String get momentViewerDeleteConfirmHeadline => 'حذف هذا؟';

  @override
  String get momentViewerDeleteConfirmBody =>
      'سيختفي من لوحة الجميع ومن أرشيفك نهائيًا';

  @override
  String get momentViewerDeleteFailed => 'تعذّر الحذف. حاول مجددًا';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who نشر لحظة';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name سجّل نقطة: $tag';
  }

  @override
  String get momentActivityJustNow => 'الآن';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '$countد';
  }

  @override
  String momentActivityHoursAgo(Object count) {
    return '$countس';
  }

  @override
  String get puzzleScreenTitle => 'اللغز.';

  @override
  String get puzzleScreenSubtitle => 'أربعة رموز، ست محاولات';

  @override
  String get puzzleSubmit => 'تخمين';

  @override
  String get puzzleBackspace => 'حذف آخر رمز';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'الرمز $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'حُلّ في $count';
  }

  @override
  String get puzzleFailedTitle => 'نفدت المحاولات';

  @override
  String get puzzleAnswerWas => 'كان الرمز';

  @override
  String get puzzleShare => 'نسخ النتيجة';

  @override
  String get puzzleShareCopied => 'تم النسخ. أرسلها إلى صديق';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'لقد حللت لغز اليوم بالفعل';

  @override
  String get puzzleErrorOutOfGuesses => 'لا محاولات متبقية اليوم';

  @override
  String get puzzleErrorGeneric => 'تعذّر الإرسال. حاول مجددًا';

  @override
  String get puzzleGuessWaiting =>
      'لا يوجد اتصال. تخمينك محفوظ وسيُرسل عند عودة الاتصال';

  @override
  String get gameSubmitWaiting =>
      'لا يوجد اتصال. لوحتك المكتملة محفوظة وستُرسل عند عودة الاتصال';

  @override
  String get puzzleScoreboardLabel => 'نتائج اليوم';

  @override
  String get puzzleScoreboardEmpty => 'لم ينتهِ أحد اليوم بعد';

  @override
  String get puzzleTilePlay => 'العب لغز اليوم';

  @override
  String puzzleTileInProgress(Object count) {
    return 'بقي $count';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '#$rank من $total';
  }

  @override
  String get profileVisibilityScreenSectionFeed => 'الموجز';

  @override
  String get profileVisibilityScreenFeedLabel => 'أبرز لحظاتي';

  @override
  String get profileVisibilityScreenFeedDesc =>
      'ما إذا كانت الصور والمقاطع التي تنشرها تظهر على لوحات أصدقائك ذلك اليوم';

  @override
  String get profileVisibilityScreenPuzzleLabel => 'نتيجتي في اللغز';

  @override
  String get profileVisibilityScreenPuzzleDesc =>
      'ما إذا كان أصدقاؤك يرون أداءك في لغز اليوم';

  @override
  String get profileVisibilityScreenPointsPastLabel => 'ماضيي';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      'اليوم يُشارك دائمًا مع الأصدقاء، وهذا يفتح كل ما قبله';

  @override
  String get momentComposerVideo => 'فيديو';

  @override
  String get momentComposerErrorTooBig =>
      'هذا الفيديو كبير جدًا. الحد الأقصى 20 ميغابايت';

  @override
  String get momentActivityPostedHighlightSelf => 'نشرت لحظة';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'سجّلت نقطة: $tag';
  }

  @override
  String momentActivityGameSolved(String game, String name) {
    return '$name حلّ: $game';
  }

  @override
  String momentActivityGameSolvedSelf(String game) {
    return 'حللت: $game';
  }

  @override
  String momentActivityGameMissed(String game, String name) {
    return '$name لم يحلّ: $game';
  }

  @override
  String momentActivityGameMissedSelf(String game) {
    return 'لم تحلّ: $game';
  }

  @override
  String momentActivityCodeSolved(String name) {
    return '$name فكّ الشيفرة';
  }

  @override
  String get momentActivityCodeSolvedSelf => 'فككت الشيفرة';

  @override
  String momentActivityCodeMissed(String name) {
    return '$name لم يفكّ الشيفرة';
  }

  @override
  String get momentActivityCodeMissedSelf => 'لم تفكّ الشيفرة';

  @override
  String pointLineSelf(Object tag) {
    return 'أنت · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'ماذا حدث؟';

  @override
  String get pointComposerNoteHint => 'اختر واحدة أعلاه ثم احكِ';

  @override
  String get pointComposerAdd => 'أضف نقطة';

  @override
  String get pointComposerAddPhoto => 'إضافة صورة';

  @override
  String get pointsBoardAdd => 'أضف نقطة';

  @override
  String get pointsExplainerOpen => 'ما هذا؟';

  @override
  String get pointsExplainerTitle => 'لعبة النقاط';

  @override
  String get pointsExplainerIntro =>
      'نكتة متكررة تحتفظون بنتيجتها. عندما يحدث لك شيء، جيد أو سيئ أو غريب فحسب، تسجّله فيبقى على اللوحة ذلك اليوم.';

  @override
  String get pointsExplainerRuleHonour =>
      'أنت من يمنح نفسه النقاط. لا أحد يتحقق، وهذه هي المتعة، وأصدقاؤك سيخبرونك إن بالغت.';

  @override
  String get pointsExplainerRuleToday =>
      'تُصفَّر النقاط كل يوم. اللوحة تعرض اليوم؛ وسجلّك يبقى لك.';

  @override
  String get pointsExplainerRuleCap =>
      'خمس من كل نوع يوميًا، حتى لا يحوّل أحد اللوحة إلى عبث.';

  @override
  String get pointsExplainerGotIt => 'فهمت';

  @override
  String get momentTagFateExample => 'صادفت طبيب أسناني في بلد آخر';

  @override
  String get momentTagJinxExample => 'غسلت السيارة، فأمطرت في الرابعة';

  @override
  String get momentTagLuckExample => 'لحقت القطار بثانيتين';

  @override
  String get momentTagCalledItExample => 'قلت إن الجزء الثاني سيفشل، ففشل';

  @override
  String get momentTagNpcExample => 'قلت ‘وأنت أيضًا’ للنادل';

  @override
  String feedBoardEditionHint(Object number) {
    return 'اليوم $number من الموجز';
  }

  @override
  String get feedBoardHighlightsHint => 'صور ومقاطع تستحق النظر';

  @override
  String get profileVisibilityScreenPointsLabel => 'نقاطي';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'ما إذا كانت النقاط التي تسجّلها تظهر على لوحات أصدقائك';

  @override
  String get momentComposerEditPhoto => 'تعديل القص';

  @override
  String get archiveScreenTitle => 'أرشيفك';

  @override
  String get archiveScreenEnd => 'هذا كل شيء';

  @override
  String get archiveScreenEmptyTitle => 'لا شيء محفوظ بعد';

  @override
  String get archiveScreenEmptyBody =>
      'تغادر اللحظات لوحات أصدقائك بعد يوم، لكنها تبقى هنا لك.';

  @override
  String get archiveScreenEmptyFriendTitle => 'لا شيء هنا';

  @override
  String get archiveScreenEmptyFriendBody => 'لم ينشر بعد ما يمكنك رؤيته.';

  @override
  String get archiveScreenPrivateTitle => 'ماضيه خاص';

  @override
  String get archiveScreenPrivateBody => 'لا يزال بإمكانك رؤية ما ينشره اليوم.';

  @override
  String get archiveScreenNotFriendTitle => 'لستما صديقين';

  @override
  String get archiveScreenNotFriendBody => 'يمكنك العودة في أيام صديق فقط.';

  @override
  String get archiveScreenErrorTitle => 'تعذّر التحميل';

  @override
  String get archiveScreenErrorBody => 'تحقق من اتصالك وحاول مجددًا.';

  @override
  String get feedBoardOpenArchive => 'الأرشيف';

  @override
  String get feedBoardGamesLabel => 'الألعاب';

  @override
  String get feedBoardGamesOpen => 'لوحة الصدارة';

  @override
  String get gamesScreenTitle => 'الألعاب.';

  @override
  String get gamesScreenSubtitle => 'أربعة ألواح كل يوم، ونفس الأربعة للجميع';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقيت $count اليوم',
      one: 'بقيت واحدة اليوم',
      zero: 'انتهت ألعاب اليوم',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => 'تعذّر تحميل ألعاب اليوم';

  @override
  String get gamesRetry => 'أعد المحاولة';

  @override
  String get gameQueensName => 'الملكات';

  @override
  String get gameQueensRule => 'تاج واحد في كل صف وعمود ولون، دون تلامس';

  @override
  String get gameTangoName => 'تانغو';

  @override
  String get gameTangoRule => 'ثلاث شموس وثلاثة أقمار، ولا ثلاثة متتالية';

  @override
  String get gameZipName => 'زِب';

  @override
  String get gameZipRule => 'خط واحد يمرّ بكل مربع، والأرقام بالترتيب';

  @override
  String get gameSudokuName => 'سودوكو مصغّر';

  @override
  String get gameSudokuRule => 'من 1 إلى 6 مرة واحدة في كل صف وعمود ومربع';

  @override
  String get gameCodeName => 'الشيفرة';

  @override
  String get gameStatusUnplayed => 'لم تُلعب';

  @override
  String get gameStatusUnfinished => 'قيد اللعب';

  @override
  String get gameStatusGaveUp => 'استسلم';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'إيقاف مؤقت';

  @override
  String get gameResume => 'متابعة';

  @override
  String get gamePausedTitle => 'متوقّف';

  @override
  String get gamePausedBody => 'الوقت متوقّف واللوح مخفي';

  @override
  String get gameUndo => 'تراجع';

  @override
  String get gameClear => 'مسح';

  @override
  String get gameHint => 'تلميح';

  @override
  String get gameNotes => 'ملاحظات';

  @override
  String get gameErase => 'محو';

  @override
  String get gameAutoCross => 'تعليم تلقائي';

  @override
  String get gameGiveUp => 'استسلام';

  @override
  String get gameGiveUpTitle => 'هل تريد عرض الحل؟';

  @override
  String get gameGiveUpBody => 'سيُغلق لوح اليوم ويُسجّل كغير محلول.';

  @override
  String get gameGiveUpCancel => 'سأتابع';

  @override
  String get gameGiveUpConfirm => 'اعرضه';

  @override
  String gameSolvedTitle(Object time) {
    return 'حُلّت في $time';
  }

  @override
  String get gameGaveUpTitle => 'حل اليوم';

  @override
  String get gameFirstInToday => 'أول من أنهاها اليوم';

  @override
  String gameRankLine(Object place, Object total) {
    return '$place من $total حتى الآن';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أخطاء',
      one: 'خطأ واحد',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تلميحات',
      one: 'تلميح واحد',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => 'أزمنة اليوم';

  @override
  String get gameStandingsEmpty => 'لم ينهها أحد بعد';

  @override
  String get gameShare => 'انسخ النتيجة';

  @override
  String get gameShareCopied => 'تم النسخ. الصقه لصديق';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number · $time';
  }

  @override
  String get gameBackToHub => 'كل الألعاب';

  @override
  String get gameElapsedSemantic => 'الوقت المنقضي';

  @override
  String get gameErrorNotSolved => 'اللوح لم يكتمل بعد';

  @override
  String get gameErrorAlreadyFinished => 'لقد أنهيت لعبة اليوم';

  @override
  String get gameErrorNoHint => 'لا يوجد تلميح لهذه';

  @override
  String get gameHintWrong => 'هذه كانت خاطئة، لذا مُسحت.';

  @override
  String get gameHintWrongMore =>
      'ما زال هناك ما تصلحه. اطلب مرة أخرى عندما تكون جاهزًا.';

  @override
  String get gameHintWrongLast => 'كل ما وضعته غير ذلك صحيح.';

  @override
  String get gameHintReveal =>
      'لا توجد بعد قاعدة واحدة تحسم أي مربع، لذا إليك واحدًا.';

  @override
  String get gameHintQueensRegion => 'بقي مكان واحد فقط لتاج في هذا اللون.';

  @override
  String get gameHintQueensRow => 'بقي مكان واحد فقط لتاج في هذا الصف.';

  @override
  String get gameHintQueensCol => 'بقي مكان واحد فقط لتاج في هذا العمود.';

  @override
  String get gameHintQueensRegionInRow =>
      'هذا اللون لا يتسع إلا في هذا الصف، لذا لا يمكن وضع تاج في باقي الصف.';

  @override
  String get gameHintQueensRegionInCol =>
      'هذا اللون لا يتسع إلا في هذا العمود، لذا لا يمكن وضع تاج في باقي العمود.';

  @override
  String get gameHintQueensRowInRegion =>
      'هذا الصف ليس فيه مكان إلا في لون واحد، لذا لا يمكن وضع تاج في باقي ذلك اللون.';

  @override
  String get gameHintQueensColInRegion =>
      'هذا العمود ليس فيه مكان إلا في لون واحد، لذا لا يمكن وضع تاج في باقي ذلك اللون.';

  @override
  String get gameHintStarsRegion =>
      'لم يبقَ في هذا اللون مكان إلا للنجوم التي ما زال يحتاجها.';

  @override
  String get gameHintStarsRow =>
      'لم يبقَ في هذا الصف مكان إلا للنجوم التي ما زال يحتاجها.';

  @override
  String get gameHintStarsCol =>
      'لم يبقَ في هذا العمود مكان إلا للنجوم التي ما زال يحتاجها.';

  @override
  String get gameHintTangoEqual => 'إشارة = تعني أن المربعين متشابهان.';

  @override
  String get gameHintTangoCross => 'إشارة × تعني أن المربعين مختلفان.';

  @override
  String get gameHintTangoPair =>
      'مربعان متجاوران متشابهان بالفعل، لذا يجب أن يكون التالي عكسهما.';

  @override
  String get gameHintTangoSandwich =>
      'المربعان على الجانبين متشابهان، لذا يجب أن يكون الأوسط عكسهما.';

  @override
  String get gameHintTangoRowSuns => 'هذا الصف فيه شموسه الثلاث بالفعل.';

  @override
  String get gameHintTangoRowMoons => 'هذا الصف فيه أقماره الثلاثة بالفعل.';

  @override
  String get gameHintTangoColSuns => 'هذا العمود فيه شموسه الثلاث بالفعل.';

  @override
  String get gameHintTangoColMoons => 'هذا العمود فيه أقماره الثلاثة بالفعل.';

  @override
  String gameHintLatinBox(int digit) {
    return 'هذا هو المكان الوحيد للرقم $digit في هذا المربع الكبير.';
  }

  @override
  String gameHintLatinRow(int digit) {
    return 'هذا هو المكان الوحيد للرقم $digit في هذا الصف.';
  }

  @override
  String gameHintLatinCol(int digit) {
    return 'هذا هو المكان الوحيد للرقم $digit في هذا العمود.';
  }

  @override
  String get gameHintLatinOnly =>
      'رقم واحد فقط يناسب هنا. الباقي موجود بالفعل في صفه أو عموده أو مربعه الكبير.';

  @override
  String get gameHintLatinOnlyLines =>
      'رقم واحد فقط يناسب هنا. الباقي موجود بالفعل في صفه أو عموده.';

  @override
  String get gameHintLatinOnlySigns =>
      'رقم واحد فقط يناسب هنا بعد حساب صفه وعموده والإشارات.';

  @override
  String get gameHintNonogramRowFill =>
      'أيًّا كانت طريقة وضع دليل هذا الصف، فهو يغطي هذا المربع.';

  @override
  String get gameHintNonogramRowCross =>
      'لا توجد طريقة لوضع دليل هذا الصف تصل إلى هذا المربع.';

  @override
  String get gameHintNonogramColFill =>
      'أيًّا كانت طريقة وضع دليل هذا العمود، فهو يغطي هذا المربع.';

  @override
  String get gameHintNonogramColCross =>
      'لا توجد طريقة لوضع دليل هذا العمود تصل إلى هذا المربع.';

  @override
  String get gameHintMinesStart => 'ابدأ من هنا. هذا المربع آمن دائمًا.';

  @override
  String get gameHintMinesSafe =>
      'كل ألغام هذا الرقم عليها علم بالفعل، لذا باقي المربعات حوله آمنة.';

  @override
  String get gameHintMinesFlag =>
      'هذا الرقم يحتاج أن يكون كل مربع مخفي حوله لغمًا.';

  @override
  String get gameHintMinesProofSafe => 'الأرقام حول هذا المربع تثبت أنه آمن.';

  @override
  String get gameHintMinesProofMine => 'الأرقام حول هذا المربع تثبت أنه لغم.';

  @override
  String get gameHintFlowPipe => 'إليك أنبوبًا كاملًا، من نقطة إلى نقطة.';

  @override
  String get gameHintPatchesOnly => 'رقعة واحدة فقط تناسب هذا الدليل.';

  @override
  String get gameHintPatchesCell =>
      'مربع هنا لا يمكن أن يتبع إلا هذا الدليل، وهذا يترك له رقعة واحدة.';

  @override
  String get gameHintPatchesSqueeze =>
      'الرقع المحيطة لا تترك لهذا الدليل إلا طريقة واحدة ليتّسع.';

  @override
  String get gameErrorGeneric => 'تعذّر الوصول إلى الألعاب. حاول مجددًا';

  @override
  String get gameInfoOpen => 'كيف تلعب';

  @override
  String get gameInfoScoringTimed =>
      'الأسرع يفوز. تتوقف الساعة عندما تخرج. الوقت نفسه، المركز نفسه.';

  @override
  String get gameInfoScoringGuesses =>
      'الأقل تخمينًا يفوز. الوقت لا يُحسب. عدد التخمينات نفسه، المركز نفسه.';

  @override
  String get gameInfoSameForEveryone => 'الجميع يحصل على اللغز نفسه اليوم.';

  @override
  String get savedMessagesTitle => 'الرسائل المحفوظة';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'لا توجد محادثات تطابق \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'ابحث عن محادثات';

  @override
  String get pullRevealCollapseSemanticLabel =>
      'إخفاء البحث والمحادثات المؤرشفة';

  @override
  String archivedChatsFolderLabel(Object count) {
    return 'محادثات مؤرشفة ($count)';
  }

  @override
  String get archivedChatsFolderTitle => 'محادثات مؤرشفة';

  @override
  String get pullRevealClearSearchSemanticLabel => 'مسح البحث';

  @override
  String get archivedChatsSheetTitle => 'المحادثات المؤرشفة';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'المحادثات المؤرشفة · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'لم يعد هناك أي شيء مؤرشف';

  @override
  String get pinnedBadgeLabel => 'مثبت';

  @override
  String get chatRowActionMenuPinLabel => 'تثبيت المحادثة';

  @override
  String get chatRowActionMenuUnpinLabel => 'إلغاء تثبيت المحادثة';

  @override
  String get chatRowActionMenuArchiveLabel => 'أرشفة المحادثة';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'إلغاء أرشفة المحادثة';

  @override
  String get messageActionMenuSaveLabel => 'حفظ';

  @override
  String get messageActionMenuUnsaveLabel => 'إلغاء الحفظ';

  @override
  String get roomScreenSaveLimitSnack =>
      'المحفوظات هنا كثيرة. ألغِ حفظ واحدة أولاً';

  @override
  String get roomScreenSaveFailedSnack => 'تعذّر حفظ ذلك';

  @override
  String get threadOverlaySaveLimitToast =>
      'المحفوظات هنا كثيرة. ألغِ حفظ واحدة أولاً';

  @override
  String get threadOverlaySaveFailedToast => 'تعذّر حفظ ذلك';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'أنت وحدك من يرى الرسائل التي تحفظها، والرسالة المثبّتة عكس ذلك تمامًا: تراها الغرفة كلها.';

  @override
  String get roomInfoScreenOwnerBadgeNote =>
      'الميدالية الصغيرة بجانب الاسم تدل على من أنشأ هذه الغرفة.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return 'الانتقال إلى الرسالة المحفوظة من $name';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return 'إلغاء حفظ الرسالة من $name';
  }

  @override
  String get muteSheetTitle => 'كتم المحادثة';

  @override
  String get muteSheetSubtitle => 'اختر ما الذي يهدأ، ولكم من الوقت.';

  @override
  String get muteSheetNotificationsTitle => 'الإشعارات';

  @override
  String get muteSheetNotificationsSub => 'بلا إشعار، بلا صوت';

  @override
  String get muteSheetBadgesTitle => 'عدّاد غير المقروء';

  @override
  String get muteSheetBadgesSub =>
      'بلا رقم على المحادثة، ولا شيء يُضاف إلى أيقونة التطبيق';

  @override
  String get muteSheetDurationLabel => 'لكم من الوقت';

  @override
  String get muteDurationHour => 'ساعة واحدة';

  @override
  String get muteDurationEightHours => '8 ساعات';

  @override
  String get muteDurationWeek => 'أسبوع واحد';

  @override
  String get muteDurationAlways => 'دائمًا';

  @override
  String get muteSheetConfirmButton => 'كتم';

  @override
  String get muteSheetSaveButton => 'حفظ';

  @override
  String get muteSheetUnmuteButton => 'إلغاء الكتم';

  @override
  String get muteSummaryAll =>
      'لن يصلك شيء من هذه المحادثة: لا إشعارات ولا عدّاد غير مقروء.';

  @override
  String get muteSummaryNotificationsOnly =>
      'بلا إشعارات. عدّاد غير المقروء يستمر في الارتفاع.';

  @override
  String get muteSummaryBadgesOnly =>
      'بلا عدّاد غير مقروء. الإشعارات ما زالت تصل.';

  @override
  String get muteSummaryNothingPicked => 'اختر شيئًا واحدًا على الأقل لكتمه.';

  @override
  String muteUntilSentence(String when) {
    return 'حتى $when.';
  }

  @override
  String get muteUntilAlwaysSentence => 'حتى تعيد تشغيله بنفسك.';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date، $time';
  }

  @override
  String get mutedBadgeLabel => 'مكتومة';

  @override
  String get chatRowActionMenuMuteLabel => 'كتم المحادثة';

  @override
  String get chatRowActionMenuUnmuteLabel => 'إلغاء كتم المحادثة';

  @override
  String get roomInfoScreenMuteLabel => 'الكتم';

  @override
  String get roomInfoScreenNotMutedRow => 'غير مكتومة';

  @override
  String get attachmentMenuLocationLabel => 'الموقع';

  @override
  String get locationSheetSendCurrent => 'إرسال الموقع الحالي';

  @override
  String get locationSheetSendCurrentDetail => 'مكانك الآن';

  @override
  String get locationSheetLiveHeading => 'مشاركة مباشرة';

  @override
  String get locationSheetLiveDetail => 'يتوقّف تلقائيًا';

  @override
  String get locationShareFor15Minutes => 'لمدة 15 دقيقة';

  @override
  String get locationShareFor1Hour => 'لمدة ساعة واحدة';

  @override
  String get locationShareFor8Hours => 'لمدة 8 ساعات';

  @override
  String get locationBubbleOpenInMaps => 'فتح في الخرائط';

  @override
  String get locationBubbleLiveBadge => 'مباشر';

  @override
  String get locationBubbleEndedBadge => 'انتهى';

  @override
  String locationBubbleLiveUntil(String time) {
    return 'مباشر حتى $time';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return 'انتهى الموقع المباشر في $time';
  }

  @override
  String get locationBubbleNoRecentUpdate => 'لا يوجد تحديث حديث';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters م';
  }

  @override
  String get locationBubbleStopSharing => 'إيقاف المشاركة';

  @override
  String get locationBubbleUnavailable => 'الموقع غير متاح';

  @override
  String get locationBubbleNoMapsApp => 'لا يوجد تطبيق خرائط لفتح هذا';

  @override
  String get locationBubbleCoordinatesCopied => 'تم نسخ الإحداثيات';

  @override
  String get locationCouldNotGetFix => 'تعذّر الحصول على موقعك';

  @override
  String get locationCouldNotStartLiveShare => 'تعذّر بدء المشاركة المباشرة';

  @override
  String get locationPermissionNeeded =>
      'الوصول إلى الموقع مطلوب لمشاركة مكانك';

  @override
  String get locationPermissionBlockedTitle => 'الوصول إلى الموقع معطّل';

  @override
  String get locationPermissionBlockedBody =>
      'لا يمكن لـ MonkeyHub أن يطلب مرة أخرى من هنا. فعّل الوصول إلى الموقع لـ MonkeyHub من الإعدادات.';

  @override
  String get locationServicesOffTitle => 'خدمات الموقع معطّلة';

  @override
  String get locationServicesOffBody =>
      'الموقع معطّل على هذا الجهاز. فعّله من الإعدادات لمشاركة مكانك.';

  @override
  String get locationOpenSettings => 'فتح الإعدادات';

  @override
  String get locationBackgroundSheetTitle => 'إذا أُعيد تشغيل هاتفك';

  @override
  String get locationBackgroundSheetBody =>
      'مشاركتك المباشرة تستمر بالفعل عند خروجك من MonkeyHub. الوصول في الخلفية يغطي ما تبقّى: إعادة تشغيل، إغلاق قسري، أو هاتف نفدت بطاريته ثم عاد.';

  @override
  String get locationBackgroundSheetKeepRunning => 'استئنافها تلقائيًا';

  @override
  String get locationBackgroundSheetKeepRunningDetail =>
      'سيطلب منك هاتفك السماح بذلك';

  @override
  String get locationBackgroundSheetAppOnly => 'اتركها متوقفة';

  @override
  String get locationBackgroundSheetAppOnlyDetail => 'لا شيء آخر للسماح به';

  @override
  String get locationServiceNotificationTitle => 'تتم مشاركة موقعك المباشر';

  @override
  String get locationServiceNotificationBody =>
      'اضغط لفتح المحادثة، أو «إيقاف» لإنهائها الآن';

  @override
  String get childPolicyScreenLocationLabel => 'الموقع';

  @override
  String get childPolicyScreenLocationOnDesc =>
      'يمكنهم مشاركة مكانهم، بما في ذلك مباشرةً حتى 8 ساعات';

  @override
  String get childPolicyScreenLocationOffDesc => 'لا يمكنهم مشاركة مكانهم';

  @override
  String get roomInfoScreenSavedMessagesLabel => 'الرسائل المحفوظة';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      'أنت وحدك تراها، ومن هذه الغرفة فقط. محادثة الرسائل المحفوظة منفصلة.';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      'لا شيء محفوظ بعد. اضغط مطولاً على رسالة واختر حفظ.';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return 'الانتقال إلى الرسالة المحفوظة من $name';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return 'إلغاء حفظ الرسالة من $name';
  }

  @override
  String get composerCaptureCameraModeLabel => 'الكاميرا';

  @override
  String get composerCaptureVoiceModeLabel => 'رسالة صوتية';

  @override
  String get composerCaptureVideoNoteModeLabel => 'ملاحظة فيديو';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode. مرّر بإصبعين أو استخدم مفاتيح الأسهم لتغيير الوضع.';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return 'تم اختيار $mode';
  }

  @override
  String get composerCaptureRecordingAnnouncement => 'بدأ التسجيل';

  @override
  String get composerCaptureLockedAnnouncement =>
      'تم تثبيت التسجيل. بدون استخدام اليدين.';

  @override
  String get composerCaptureCancelledAnnouncement => 'تم تجاهل التسجيل';

  @override
  String get composerCaptureSentAnnouncement => 'تم إرسال التسجيل';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return 'جارٍ التسجيل، $elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint =>
      'اضغط مع الاستمرار للتسجيل، واسحب للتبديل';

  @override
  String get composerCaptureTapForCameraHint => 'انقر للكاميرا، واسحب للتبديل';

  @override
  String get composerCaptureSlideToCancelHint => 'اسحب للإلغاء';

  @override
  String get composerCaptureReleaseToCancelHint => 'أفلت للإلغاء';

  @override
  String get composerCaptureTapToSendHint => 'اضغط للإرسال';

  @override
  String get composerCaptureSendingLabel => 'جارٍ الإرسال…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return 'بقيت $seconds ثانية';
  }

  @override
  String get composerCaptureLockedCancel => 'إلغاء';

  @override
  String get composerCaptureViewOnceLabel => 'تشغيل مرة واحدة';

  @override
  String get composerCaptureViewOnceVoiceHint =>
      'يمكنه الاستماع إليها مرة واحدة فقط';

  @override
  String get composerCaptureViewOnceVideoHint => 'يمكنه مشاهدتها مرة واحدة فقط';

  @override
  String get composerCapturePauseLabel => 'إيقاف التسجيل مؤقتًا';

  @override
  String get composerCaptureResumeLabel => 'استئناف التسجيل';

  @override
  String get composerCaptureFlashLabel => 'الفلاش';

  @override
  String get composerCaptureReviewPlayLabel => 'تشغيل التسجيل';

  @override
  String get composerCaptureReviewStopLabel => 'إيقاف التشغيل';

  @override
  String get composerCaptureCancelLabel => 'تجاهل التسجيل';

  @override
  String get composerCaptureSendLabel => 'إرسال التسجيل';

  @override
  String get composerCaptureLockLabel => 'اسحب لأعلى لتثبيت التسجيل';

  @override
  String get composerCaptureMicPermissionTitle => 'الميكروفون مطلوب';

  @override
  String get composerCaptureMicPermissionBody =>
      'يحتاج MonkeyHub إلى الميكروفون لتسجيل رسالة صوتية. فعّله من الإعدادات ثم أعد المحاولة.';

  @override
  String get composerCaptureCameraPermissionTitle => 'الكاميرا مطلوبة';

  @override
  String get composerCaptureCameraPermissionBody =>
      'يحتاج MonkeyHub إلى الكاميرا والميكروفون لتسجيل ملاحظة فيديو. فعّلهما من الإعدادات ثم أعد المحاولة.';

  @override
  String get composerCaptureRestrictedBody =>
      'التسجيل معطّل بسبب قيد على هذا الجهاز.';

  @override
  String get composerCaptureOpenSettingsLabel => 'فتح الإعدادات';

  @override
  String get composerCaptureUnavailableSnack =>
      'التسجيل غير متاح على هذا الجهاز.';

  @override
  String get composerCaptureInterruptedSnack => 'تم إيقاف التسجيل.';

  @override
  String get composerCaptureStorageSnack =>
      'تعذّر حفظ التسجيل. تحقق من المساحة المتاحة.';

  @override
  String get videoNoteMessagePlayLabel => 'تشغيل ملاحظة الفيديو';

  @override
  String get videoNoteMessagePauseLabel => 'إيقاف ملاحظة الفيديو مؤقتًا';

  @override
  String get videoNoteMessageLoadingLabel => 'جارٍ تحميل ملاحظة الفيديو';

  @override
  String get videoNoteMessageUnavailableLabel => 'ملاحظة الفيديو غير متاحة';

  @override
  String get videoNoteMessageRetryLabel => 'إعادة محاولة ملاحظة الفيديو';

  @override
  String get videoNoteMessageRetryHint => 'اضغط لإعادة المحاولة';

  @override
  String get videoNoteMessageDiscardLabel => 'تجاهل ملاحظة الفيديو';

  @override
  String get videoNoteScrubHint => 'أبعد إصبعك عن الدائرة للتنقل بدقة أكبر';

  @override
  String get videoNoteScrubHalf => 'تنقل بنصف السرعة';

  @override
  String get videoNoteScrubFine => 'تنقل دقيق';

  @override
  String videoNoteSpeedLabel(String speed) {
    return 'سرعة التشغيل $speed';
  }

  @override
  String get videoNoteAutoAdvanceOn => 'التشغيل التلقائي: مفعّل';

  @override
  String get videoNoteAutoAdvanceOff => 'التشغيل التلقائي: متوقف';

  @override
  String get videoNoteAutoAdvanceSemanticLabel =>
      'تشغيل ملاحظة الفيديو التالية تلقائيًا';

  @override
  String get composerCaptureStartRecordingLabel => 'بدء التسجيل';

  @override
  String get attachmentMenuVideoNoteLabel => 'ملاحظة فيديو';

  @override
  String get cameraScreenPhotoModeLabel => 'صورة';

  @override
  String get cameraScreenVideoModeLabel => 'فيديو';

  @override
  String get cameraScreenStartRecordingLabel => 'بدء التسجيل';

  @override
  String get cameraScreenStopRecordingLabel => 'إيقاف التسجيل';

  @override
  String get cameraScreenVideoFailedSnack => 'تعذّر تسجيل هذا الفيديو.';

  @override
  String get scheduleSheetTitle => 'جدولة الرسالة';

  @override
  String get scheduleSheetSubtitle =>
      'اكتبها الآن، وتُرسَل في الوقت الذي تختاره.';

  @override
  String get scheduleSheetWhenLabel => 'متى';

  @override
  String get schedulePresetInAnHour => 'بعد ساعة';

  @override
  String get schedulePresetInEightHours => 'بعد 8 ساعات';

  @override
  String get schedulePresetTomorrowMorning => 'صباح الغد';

  @override
  String get schedulePresetThisMorning => 'هذا الصباح';

  @override
  String get schedulePresetInAWeek => 'بعد أسبوع';

  @override
  String get scheduleSheetCustomChip => 'اختيار تاريخ';

  @override
  String get scheduleSheetConfirmButton => 'جدولة';

  @override
  String get scheduleSheetSaveButton => 'حفظ';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'تُرسَل $when';
  }

  @override
  String scheduleWhenToday(String time) {
    return 'اليوم في $time';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return 'غدًا في $time';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return 'في $date الساعة $time';
  }

  @override
  String get scheduleTimePickerTitle => 'اختيار التاريخ والوقت';

  @override
  String get scheduleTimePickerBack => 'خيارات سريعة';

  @override
  String get scheduleTimePickerToday => 'اليوم';

  @override
  String get scheduleTimePickerTomorrow => 'غدًا';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة مجدولة',
      many: '$count رسالة مجدولة',
      few: '$count رسائل مجدولة',
      two: 'رسالتان مجدولتان',
      one: 'رسالة مجدولة',
      zero: 'لا شيء مجدول',
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
      other: '$count رسالة بانتظار الإرسال. اضغط لعرضها.',
      many: '$count رسالة بانتظار الإرسال. اضغط لعرضها.',
      few: '$count رسائل بانتظار الإرسال. اضغط لعرضها.',
      two: 'رسالتان بانتظار الإرسال. اضغط لعرضهما.',
      one: 'رسالة واحدة بانتظار الإرسال. اضغط لعرضها.',
      zero: 'لا توجد رسائل بانتظار الإرسال.',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => 'تحتاج إليك';

  @override
  String get scheduledListTitle => 'المجدولة';

  @override
  String get scheduledListSubtitle => 'لا يراها أحد غيرك حتى تُرسَل.';

  @override
  String get scheduledListEmpty => 'لا شيء بانتظار الإرسال هنا.';

  @override
  String get scheduledListSendNow => 'إرسال الآن';

  @override
  String get scheduledListChangeTime => 'تغيير الوقت';

  @override
  String get scheduledListEdit => 'تعديل النص';

  @override
  String get scheduledListDelete => 'حذف';

  @override
  String get scheduledListDeleteHeadline => 'حذف الرسالة المجدولة';

  @override
  String get scheduledListDeleteBody => 'لن يتم إرسالها.';

  @override
  String get scheduledListSending => 'جارٍ الإرسال…';

  @override
  String get scheduledListFailedTitle => 'تعذّر الإرسال';

  @override
  String get scheduledListRetry => 'إعادة المحاولة';

  @override
  String get scheduleErrorOutOfRange => 'اختر وقتًا بين دقيقتين وسنة من الآن.';

  @override
  String get scheduleErrorTooMany =>
      'هناك رسائل كثيرة بانتظار الإرسال هنا. أرسل بعضها أو احذفها أولًا.';

  @override
  String get scheduleErrorNotInEphemeral =>
      'رسائل هذه المحادثة تختفي من تلقاء نفسها، لذا لا يمكن جدولتها.';

  @override
  String get scheduleErrorNotMember => 'لم تعد في هذه المحادثة.';

  @override
  String get scheduleErrorBlocked => 'عليك إلغاء الحظر أولًا.';

  @override
  String get scheduleErrorGeneric => 'لم ينجح ذلك. حاول مرة أخرى.';

  @override
  String get scheduleEditTitle => 'تعديل الرسالة';

  @override
  String get composerScheduleAction => 'جدولة هذه الرسالة';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة بانتظار الإرسال',
      many: '$count رسالة بانتظار الإرسال',
      few: '$count رسائل بانتظار الإرسال',
      two: 'رسالتان بانتظار الإرسال',
      one: 'رسالة واحدة بانتظار الإرسال',
      zero: 'لا رسائل بانتظار الإرسال',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => 'طريقة العرض';

  @override
  String get scheduledIndicatorPill => 'شريط';

  @override
  String get scheduledIndicatorBadge => 'شارة';

  @override
  String get scheduledIndicatorBoth => 'كلاهما';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة بانتظار الإرسال',
      many: '$count رسالة بانتظار الإرسال',
      few: '$count رسائل بانتظار الإرسال',
      two: 'رسالتان بانتظار الإرسال',
      one: 'رسالة واحدة بانتظار الإرسال',
      zero: 'لا شيء بانتظار الإرسال',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => 'كيف تظهر';

  @override
  String get scheduledIndicatorPillSub =>
      'شريط فوق مربع الكتابة. اضغط عليه لعرضها.';

  @override
  String get scheduledIndicatorBadgeSub =>
      'رقم على زر الإرسال. لا يظهر شيء حتى تبدأ الكتابة.';

  @override
  String get scheduledIndicatorBothSub =>
      'الشريط، بالإضافة إلى الرقم أثناء الكتابة.';

  @override
  String get scheduledBack => 'رجوع';

  @override
  String get serverScreenTitle => 'الخادم.';

  @override
  String get serverScreenSubtitle => 'حيث يوجد حسابك ورسائلك';

  @override
  String get serverOnboardingTitle => 'اختر خادمًا.';

  @override
  String get serverOnboardingSubtitle =>
      'لم يأتِ هذا الإصدار بخادم، فوجّهه إلى خادمك';

  @override
  String get serverStatusConnected => 'متصل';

  @override
  String get serverStatusDisconnected => 'غير متصل';

  @override
  String get serverBadgeDefault => 'الافتراضي';

  @override
  String get serverBadgeSelfHosted => 'استضافة ذاتية';

  @override
  String get serverNoneConfigured => 'لا يوجد خادم بعد';

  @override
  String get serverActiveNowLabel => 'قيد الاستخدام';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'الخادم الذي جاء مع هذا التطبيق.';

  @override
  String get serverChoiceOwn => 'خادمك الخاص';

  @override
  String get serverChoiceOwnSub => 'خادم Convex تديره بنفسك.';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => 'لصق';

  @override
  String get serverProblemMalformed => 'هذا ليس عنوان ويب.';

  @override
  String get serverProblemBadScheme => 'ابدأه بـ https:// أو http://.';

  @override
  String get serverProblemNoHost => 'أضف عنوان خادمك بعد https://.';

  @override
  String get serverProblemCredentials =>
      'أزل اسم المستخدم وكلمة المرور من العنوان.';

  @override
  String get serverInsecureTitle => 'غير مُشفّر';

  @override
  String get serverInsecureBody =>
      'تحجب الهواتف بروتوكول http العادي، لذا لن يتصل هذا العنوان على iOS أو Android. استخدم https أو صِل إلى خادمك عبر نفق.';

  @override
  String get serverTestCta => 'اختبر الاتصال';

  @override
  String get serverTestingLabel => 'جارٍ الاختبار…';

  @override
  String get serverCheckReachable => 'استجاب شيء ما';

  @override
  String get serverCheckConvex => 'إنه خادم Convex';

  @override
  String get serverCheckApp => 'يشغّل MonkeyHub';

  @override
  String get serverResultUnreachable => 'لم يستجب شيء على هذا العنوان.';

  @override
  String get serverResultNotConvex => 'استجاب شيء ما، لكنه ليس خادم Convex.';

  @override
  String get serverResultNotThisApp =>
      'هذا خادم Convex، لكن MonkeyHub غير منشور عليه.';

  @override
  String get serverResultServerError => 'استجاب الخادم، لكن بخطأ.';

  @override
  String get serverResultReady => 'جاهز للاتصال.';

  @override
  String get serverConnectCta => 'اتصل';

  @override
  String get serverConnectAnywayCta => 'اتصل على أي حال';

  @override
  String get serverAlreadyConnectedCta => 'متصل بالفعل';

  @override
  String get serverUseDefaultCta => 'استخدم الخادم الافتراضي';

  @override
  String get serverChangeCta => 'تغيير الخادم';

  @override
  String get serverAdvancedLabel => 'خيارات متقدمة';

  @override
  String get serverSiteUrlExplain =>
      'معظم الخوادم تجيب على كل شيء من عنوان واحد. املأ هذا فقط إذا كان خادمك يقدّم إجراءات http من مكان آخر.';

  @override
  String get serverSiteUrlHint => 'نفس ما سبق';

  @override
  String get serverSectionRecent => 'الأخيرة';

  @override
  String get serverRecentForget => 'انسَ هذا الخادم';

  @override
  String get serverSwitchWarningTitle => 'التبديل يسجّل خروجك';

  @override
  String get serverSwitchWarningBody =>
      'الحسابات والمحادثات تخصّ خادمًا واحدًا. سيسجّل هذا الجهاز الخروج، ويمسح ما نزّله، ويبدأ من جديد. ولن يُحذف أي شيء على أي من الخادمين.';

  @override
  String get serverSwitchRolledBackTitle => 'تعذّر الاتصال';

  @override
  String serverSwitchRolledBackBody(String host) {
    return 'لم يستجب $host، لذا لم يتغير شيء. عليك تسجيل الدخول من جديد.';
  }

  @override
  String get serverSwitchStrandedBody =>
      'لم يتصل أي من الخادمين. تحقّق من العنوان وحاول مرة أخرى.';

  @override
  String get serverSwitchRefusedBody =>
      'هذا الجهاز مُعدّ لطفل ولا يمكنه تغيير الخادم.';

  @override
  String serverChipSemantics(String server) {
    return 'تغيير الخادم. الحالي $server.';
  }

  @override
  String get serverValueDefault => 'الافتراضي';

  @override
  String get settingsScreenRowServer => 'الخادم';

  @override
  String get settingsScreenSectionAdvanced => 'خيارات متقدمة';

  @override
  String get serverSwitchingLabel => 'جارٍ تبديل الخادم…';

  @override
  String get serverRoleExplainAction => 'ماذا يعني هذا؟';

  @override
  String get serverBadgeRibbonHomeserver => 'منزلي';

  @override
  String get serverBadgeRibbonSelfHosted => 'ذاتي';

  @override
  String get serverBadgeHomeserver => 'يعمل من الخادم المنزلي';

  @override
  String get serverBadgeHomeserverSemantics =>
      'يعمل من الخادم المنزلي. اضغط للتفاصيل.';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'خادم باستضافة ذاتية: $server. اضغط للتفاصيل.';
  }

  @override
  String get serverRoleHomeserverTitle => 'يعمل على الخادم المنزلي';

  @override
  String get serverRoleHomeserverBody =>
      'قام مشغّلو MonkeyHub بنقل حركة البيانات إلى خادمهم المنزلي لفترة. كل شيء يعمل كالمعتاد، وهذا إجراء مقصود وليس عطلًا.';

  @override
  String get serverRoleHomeserverWarnData =>
      'قد لا يبقى ما ترسله أثناء تشغيل هذا بعد عودة حركة البيانات.';

  @override
  String get serverRoleHomeserverWarnSpeed =>
      'الاتصال المنزلي أبطأ من المعتاد، لذا قد تصبح الأمور متأخرة.';

  @override
  String get serverRoleHomeserverWarnAuto =>
      'لا داعي لفعل أي شيء. سيعود التطبيق تلقائيًا.';

  @override
  String get serverRoleSelfHostedTitle => 'خادمك الخاص';

  @override
  String get serverRoleSelfHostedBody =>
      'هذا الجهاز موجَّه إلى خادم تديره بنفسك. يمكنك تغييره من الإعدادات › خيارات متقدمة › الخادم.';

  @override
  String get serverValueHomeserver => 'الخادم المنزلي، مؤقتًا';

  @override
  String get serverChoiceCloudSubHomeserver =>
      'يُقدَّم من الخادم المنزلي لفترة.';

  @override
  String get serverDirectiveChangedToast => 'تغيّر خادمك. جارٍ إعادة الاتصال…';

  @override
  String get loginScreenSignInWithPhone => 'sign in with your phone';

  @override
  String get loginScreenUsePasswordInstead => 'استخدم كلمة مرور بدلاً من ذلك';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      'افتح MonkeyHub على هاتفك، وانتقل إلى ملفك الشخصي، واضغط «امسح لتسجيل الدخول» ثم وجّه الكاميرا إلى هنا، أو اكتب الرمز أدناه.';

  @override
  String get deviceLoginScreenWaiting => 'بانتظار الموافقة…';

  @override
  String get deviceLoginScreenApproved => 'تمت الموافقة. جارٍ تسجيل دخولك…';

  @override
  String get deviceLoginScreenDenied => 'رُفض طلب تسجيل الدخول على هاتفك';

  @override
  String get deviceLoginScreenGenericError => 'حدث خطأ ما. جرّب رمزًا جديدًا';

  @override
  String get profileScreenScanToSignInLabel => 'امسح لتسجيل الدخول';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro =>
      'وجّه الكاميرا إلى الرمز الظاهر على حاسوبك، أو اكتبه أدناه.';

  @override
  String get deviceLoginScanScreenScanButtonLabel => 'مسح الرمز';

  @override
  String get deviceLoginScanScreenConfirmTitle =>
      'تسجيل الدخول على هذا الجهاز؟';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return 'يريد $deviceInfo تسجيل الدخول باسمك. وافق فقط إذا كنت أنت، الآن.';
  }

  @override
  String get deviceLoginScanScreenApproveButton => 'موافقة';

  @override
  String get deviceLoginScanScreenDenyButton => 'رفض';

  @override
  String get deviceLoginScanScreenSuccess => 'تم تسجيل الدخول على جهازك الآخر';

  @override
  String get deviceLoginScanScreenGenericError =>
      'تعذّرت الموافقة. حاول مرة أخرى';

  @override
  String get authErrorDeviceLoginInvalid => 'هذا الرمز غير صحيح.';

  @override
  String get authErrorDeviceLoginExpired =>
      'انتهت صلاحية هذا الرمز. احصل على رمز جديد من الجهاز الآخر.';

  @override
  String get deviceLoginScanScreenDeniedConfirmation =>
      'تم رفض طلب تسجيل الدخول';

  @override
  String get roomAdminRoleAdmin => 'مشرف';

  @override
  String get roomAdminActionViewProfile => 'عرض الملف الشخصي';

  @override
  String get roomAdminActionPromote => 'تعيينه مشرفًا';

  @override
  String get roomAdminActionPromoteSub =>
      'سيتمكن من الدعوة وإخراج الأعضاء وتعديل المجموعة';

  @override
  String get roomAdminActionDemote => 'إزالة الإشراف';

  @override
  String get roomAdminActionDemoteSub => 'يبقى في المجموعة كعضو';

  @override
  String get roomAdminActionTransfer => 'نقل الملكية';

  @override
  String get roomAdminActionTransferSub => 'تبقى أنت مشرفًا';

  @override
  String get roomAdminActionRemove => 'إخراج من المجموعة';

  @override
  String get roomAdminAddFriendsRow => 'إضافة أصدقاء';

  @override
  String get roomAdminInviteLinkRow => 'رابط الدعوة';

  @override
  String get roomAdminJoinRequestsRow => 'طلبات الانضمام';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return 'تسليم المجموعة إلى $name؟';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      'سيصبح المالك ويستطيع حذف المجموعة. تبقى أنت مشرفًا، وإعادتها إليك بيده وحده.';

  @override
  String get roomAdminTransferConfirmCta => 'نقل';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return 'إخراج $name؟';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'يفقد الوصول إلى المجموعة وكل ما فيها. يمكن دعوته مرة أخرى، أو العودة عبر رابط الدعوة.';

  @override
  String get roomAdminRemoveConfirmCta => 'إخراج';

  @override
  String get roomAdminGenericError => 'لم ينجح ذلك. حاول مرة أخرى.';

  @override
  String get roomAdminErrorNotMember => 'لم تعد في هذه المجموعة.';

  @override
  String get roomAdminErrorNotAdmin => 'لا يستطيع ذلك إلا المشرفون.';

  @override
  String get roomAdminErrorNotOwner => 'لا يستطيع ذلك إلا مالك المجموعة.';

  @override
  String get roomAdminErrorNotGroup => 'لا شيء لإدارته في محادثة ثنائية.';

  @override
  String get roomAdminErrorOwnerImmutable =>
      'دور المالك لا يتغير إلا بنقل المجموعة.';

  @override
  String get roomAdminErrorInvitesLocked =>
      'لا يستطيع الدعوة إلى هذه المجموعة إلا المشرفون.';

  @override
  String get roomInviteSheetTitle => 'رابط الدعوة';

  @override
  String get roomInviteSheetBlurb =>
      'رابط واحد ورمز واحد، وهما الشيء نفسه. ما إن تنشئ رابطًا جديدًا حتى يتوقف القديم عن العمل.';

  @override
  String get roomInviteNoLinkYet => 'لا يوجد رابط دعوة لهذه المجموعة بعد.';

  @override
  String get roomInviteCreateButton => 'إنشاء رابط';

  @override
  String get roomInviteRegenerateButton => 'رابط جديد';

  @override
  String get roomInviteRevokeButton => 'إبطال الرابط';

  @override
  String get roomInviteCopyLink => 'نسخ الرابط';

  @override
  String get roomInviteCopyCode => 'نسخ الرمز';

  @override
  String get roomInviteShare => 'مشاركة';

  @override
  String get roomInviteLinkCopied => 'تم نسخ الرابط.';

  @override
  String get roomInviteCodeCopied => 'تم نسخ الرمز.';

  @override
  String get roomInviteRegenerateHeadline => 'إنشاء رابط جديد؟';

  @override
  String get roomInviteRegenerateBody =>
      'يتوقف الرابط والرمز الحاليان عن العمل فورًا في كل مكان شُورِكا فيه. ومن هم في المجموعة يبقون فيها.';

  @override
  String get roomInviteRegenerateConfirm => 'رابط جديد';

  @override
  String get roomInviteRevokeHeadline => 'إبطال هذا الرابط؟';

  @override
  String get roomInviteRevokeBody =>
      'لن ينضم أحد جديد بالرابط حتى تنشئ غيره. ومن هم في المجموعة يبقون فيها.';

  @override
  String get roomInviteRevokeConfirm => 'إبطال';

  @override
  String get roomInviteLimitsLabel => 'الحدود';

  @override
  String get roomInviteExpiryLabel => 'ينتهي بعد';

  @override
  String get roomInviteMaxUsesLabel => 'عدد مرات الاستخدام';

  @override
  String get roomInviteNeverExpires => 'أبدًا';

  @override
  String get roomInviteUnlimited => 'بلا حد';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count ساعة';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count يوم';
  }

  @override
  String get roomInviteLimitsApplyToNew => 'تنطبق على الرابط الذي ستنشئه.';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      'تنطبق على الرابط التالي. أما الذي في الأعلى فيحتفظ بالحدود التي أُنشئ بها.';

  @override
  String get roomInvitePermissionsLabel => 'الأذونات';

  @override
  String get roomInviteMembersCanInviteLabel => 'يمكن للأعضاء دعوة أصدقائهم';

  @override
  String get roomInviteMembersCanInviteSub =>
      'أوقِفه فلا يُدخل الناس إلا المشرفون';

  @override
  String get roomInviteApprovalLabel => 'الموافقة على كل انضمام';

  @override
  String get roomInviteApprovalSub =>
      'من معه الرابط يطلب أولًا، ويقرر مشرف بالقبول أو الرفض';

  @override
  String roomInviteUsesCount(Object count) {
    return 'استُخدم $count مرة';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$used من $max استخدامات';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return 'ينتهي في $date';
  }

  @override
  String get roomInviteDeadExpired => 'انتهت صلاحية هذا الرابط. أنشئ غيره.';

  @override
  String get roomInviteDeadExhausted => 'نفدت استخدامات هذا الرابط. أنشئ غيره.';

  @override
  String get roomInviteDeadRevoked => 'أُبطِل هذا الرابط.';

  @override
  String get roomInviteDeadGeneric => 'لم يعد هذا الرابط يعمل.';

  @override
  String get roomInviteFriendsTitle => 'إضافة أصدقاء';

  @override
  String get roomInviteFriendsBlurb => 'ستصلهم دعوة ويمكنهم قبولها أو رفضها.';

  @override
  String get roomInviteFriendsSearchHint => 'ابحث في الأصدقاء';

  @override
  String get roomInviteFriendsInviteButton => 'دعوة';

  @override
  String get roomInviteFriendsSent => 'تمت الدعوة';

  @override
  String get roomInviteFriendsEmpty => 'كل أصدقائك هنا بالفعل أو دُعوا بالفعل.';

  @override
  String get roomInviteFriendsNoMatch => 'لا يطابق ذلك أي صديق.';

  @override
  String get roomInviteFriendsDone => 'تم';

  @override
  String get roomJoinRequestsTitle => 'طلبات الانضمام';

  @override
  String get roomJoinRequestsBlurb =>
      'هؤلاء استخدموا رابط الدعوة. لا يرون شيئًا في المجموعة حتى توافق.';

  @override
  String get roomJoinRequestsEmpty => 'لا أحد ينتظر.';

  @override
  String get roomJoinRequestsApprove => 'أدخِله';

  @override
  String get roomJoinRequestsReject => 'لا';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return 'مدعوّون · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian => 'بانتظار وليّ الأمر';

  @override
  String get roomInfoScreenInviteWithdraw => 'سحب';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return 'من $inviter · $members عضوًا';
  }

  @override
  String get roomInvitationCardJoin => 'انضمام';

  @override
  String get discoverScreenJoinByCodeTitle => 'الانضمام برمز';

  @override
  String get discoverScreenJoinByCodeSubtitle => 'افتح مجموعة شاركها أحدهم معك';

  @override
  String get joinInviteTitle => 'الانضمام إلى مجموعة';

  @override
  String get joinInviteBack => 'رجوع';

  @override
  String get joinInviteCodeBlurb =>
      'أدخِل الرمز الذي شاركه أحدهم معك. ورابط الدعوة كاملًا يعمل هنا أيضًا.';

  @override
  String get joinInviteCodeLabel => 'رمز الدعوة';

  @override
  String get joinInviteCodeHint => 'الصق الرابط أو اكتب الرمز';

  @override
  String get joinInviteCodeInvalid => 'لا يبدو هذا رمز دعوة.';

  @override
  String get joinInviteLookupButton => 'متابعة';

  @override
  String get joinInviteLookupFailed =>
      'تعذّر التحقق من الرمز. تأكد من اتصالك وحاول مرة أخرى.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count عضوًا';
  }

  @override
  String get joinInviteJoinButton => 'الانضمام إلى المجموعة';

  @override
  String get joinInviteRequestButton => 'طلب الانضمام';

  @override
  String get joinInviteOpenNote => 'ستتمكن من رؤية رسائل المجموعة فور انضمامك.';

  @override
  String get joinInviteApprovalNote =>
      'لا بد أن يوافق مشرف قبل أن ترى أي شيء هنا.';

  @override
  String get joinInviteOpenRoom => 'فتح المجموعة';

  @override
  String get joinInvitePendingHeadline => 'بانتظار مشرف';

  @override
  String get joinInvitePendingBody => 'سيصلك إشعار فور أن يرد أحدهم.';

  @override
  String get joinInviteBadLinkHeadline => 'هذه الدعوة لا تعمل';

  @override
  String get joinInviteBadLinkBody => 'تحقق من الرمز، أو اطلب رابطًا جديدًا.';

  @override
  String get joinInviteExpiredHeadline => 'انتهت صلاحية هذه الدعوة';

  @override
  String get joinInviteExpiredBody => 'اطلب رابطًا جديدًا ممن دعاك.';

  @override
  String get joinInviteExhaustedHeadline => 'استُنفدت هذه الدعوة';

  @override
  String get joinInviteExhaustedBody =>
      'كانت مضبوطة لعدد محدود من المرات. اطلب غيرها.';

  @override
  String get joinInviteRevokedHeadline => 'استُبدلت هذه الدعوة';

  @override
  String get joinInviteRevokedBody =>
      'أنشأ مشرف رابطًا جديدًا. اطلب منه الرابط الحالي.';

  @override
  String get joinInviteWrongServerHeadline => 'هذه الدعوة تخص خادمًا آخر';

  @override
  String joinInviteWrongServerBody(Object host) {
    return 'هي تخص $host. حسابك على خادم مختلف، فلا يمكن الوصول إلى هذه المجموعة من هنا.';
  }

  @override
  String get roomInviteErrorNotFound => 'رمز الدعوة هذا لا يطابق أي شيء.';

  @override
  String get roomInviteErrorRevoked =>
      'استُبدلت هذه الدعوة. اطلب الرابط الحالي.';

  @override
  String get roomInviteErrorExpired => 'انتهت صلاحية هذه الدعوة.';

  @override
  String get roomInviteErrorExhausted => 'استُنفدت هذه الدعوة.';

  @override
  String get roomInviteErrorAlreadyMember => 'هو في هذه المجموعة بالفعل.';

  @override
  String get roomInviteErrorAlreadyInvited => 'دُعي بالفعل.';

  @override
  String get roomInviteErrorSelf => 'أنت في هذه المجموعة بالفعل.';

  @override
  String get roomInviteErrorInvitationGone => 'لم تعد تلك الدعوة موجودة.';

  @override
  String get roomInviteErrorRequestPending =>
      'طلبت الانضمام بالفعل. سيرد أحد المشرفين.';

  @override
  String get roomInviteErrorRequestGone => 'ردّ أحدهم على ذلك الطلب بالفعل.';

  @override
  String get roomInviteErrorRoomPrivate =>
      'لا يُنضم إلى هذه المجموعة إلا بدعوة.';

  @override
  String get roomInviteErrorInvalidLimits => 'هذه الحدود غير صالحة.';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return 'يريد $child دعوة $other إلى $room';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return 'دعا $other ابنك $child إلى $room';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      'تُرسَل الدعوة، ويبقى القرار للطرف الآخر.';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return 'سيرى $child الدعوة ويمكنه قبولها أو رفضها. وموافقتك تمنحه أيضًا الدخول إلى تلك المجموعة إن قَبِل.';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      'لا يمكنك إخراج نفسك. غادِر المجموعة بدلًا من ذلك.';

  @override
  String get roomAdminActionMessage => 'مراسلة';

  @override
  String get roomAdminActionVoiceCall => 'مكالمة صوتية';

  @override
  String get roomAdminActionVideoCall => 'مكالمة فيديو';

  @override
  String get roomAdminYouSuffix => 'أنت';

  @override
  String get roomInfoScreenSetPasswordButton => 'تعيين';

  @override
  String get roomInfoScreenPasswordSetSnackbar => 'تم تعيين كلمة المرور.';

  @override
  String get roomInfoScreenPasswordSetState => 'كلمة المرور مفعّلة';

  @override
  String get roomInfoScreenPasswordUnsetState => 'بدون كلمة مرور';

  @override
  String get roomInfoScreenPasswordCancel => 'إلغاء';

  @override
  String get roomInfoScreenEditSave => 'حفظ';

  @override
  String get roomInfoScreenEditCancel => 'إلغاء';

  @override
  String get roomInviteRotatedToast =>
      'تم إنشاء رابط جديد. الرابط السابق لم يعد يعمل.';

  @override
  String get roomInviteRevokedToast => 'تم إبطال رابط الدعوة.';

  @override
  String get newChatMenuTitle => 'محادثة جديدة';

  @override
  String get newChatMenuCreateTitle => 'إنشاء غرفة';

  @override
  String get newChatMenuCreateSub => 'ابدأ مجموعة وادعُ الناس';

  @override
  String get newChatMenuJoinTitle => 'الانضمام برمز';

  @override
  String get newChatMenuJoinSub => 'افتح مجموعة شوركت معك';

  @override
  String get shareSheetTitle => 'مشاركة مع';

  @override
  String get shareSheetSuggestedHeading => 'مقترحون';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مرفق',
      many: '$count مرفقًا',
      few: '$count مرفقات',
      two: 'مرفقان',
      one: 'مرفق واحد',
      zero: '$count مرفقات',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف يتجاوز حد $size ولم يُضَف',
      many: '$count ملفًا يتجاوز حد $size ولم يُضَف',
      few: '$count ملفات تتجاوز حد $size ولم تُضَف',
      two: 'ملفان يتجاوزان حد $size ولم يُضافا',
      one: 'ملف واحد يتجاوز حد $size ولم يُضَف',
      zero: '$count ملفات تتجاوز حد $size ولم تُضَف',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return 'إرسال إلى $title';
  }

  @override
  String get settingsScreenRowSpeakerColors => 'ألوان المتحدّثين';

  @override
  String get settingsScreenValueSpeakerOff => 'مُعطَّل';

  @override
  String get settingsScreenValueSpeakerName => 'الأسماء';

  @override
  String get settingsScreenValueSpeakerBubble => 'الأسماء + الفقاعات';

  @override
  String get speakerColorScreenTitle => 'ألوان المتحدّثين.';

  @override
  String get speakerColorScreenSubtitle => 'من قال ذلك، دون قراءة الاسم';

  @override
  String get speakerColorScreenOffLabel => 'مُعطَّل';

  @override
  String get speakerColorScreenOffDescription =>
      'الجميع في الغرفة يكتبون بالحبر نفسه.';

  @override
  String get speakerColorScreenNameLabel => 'الأسماء';

  @override
  String get speakerColorScreenNameDescription =>
      'لكل شخص لون خاص به، على اسمه وحول صورته.';

  @override
  String get speakerColorScreenBubbleLabel => 'الفقاعات';

  @override
  String get speakerColorScreenBubbleDescription =>
      'اللون ينتقل إلى رسائلهم أيضًا، فتظل خمس رسائل متتالية تخبرك بمن كتبها.';

  @override
  String get roomInfoScreenSpeakerColorsLabel => 'الألوان';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => 'تلقائي';

  @override
  String get roomInfoScreenSpeakerColorsCustom => 'مخصّص';

  @override
  String get roomColorsScreenTitle => 'من هو من.';

  @override
  String get roomColorsScreenSubtitle => 'اللون الذي يتحدّث به كل شخص';

  @override
  String get roomColorsScreenOffTitle => 'ألوان المتحدّثين مُعطَّلة';

  @override
  String get roomColorsScreenOffBody =>
      'الآن يظهر الجميع بالحبر نفسه. فعّلها ليحصل كل شخص هنا على لون خاص به.';

  @override
  String get roomColorsScreenOffAction => 'تفعيل';

  @override
  String get roomColorsScreenOffHint =>
      'تنطبق على كل الغرف، لا على هذه فقط. متاحة أيضًا في الإعدادات.';

  @override
  String get roomColorsScreenAutoChip => 'تلقائي';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return 'مشترك مع $name';
  }

  @override
  String get roomColorsScreenResetAll => 'العودة إلى التلقائي';

  @override
  String get roomColorsScreenLimitToast =>
      'هذا أقصى عدد ألوان يمكن تثبيته في غرفة.';

  @override
  String get roomColorsScreenFailedToast => 'تعذّر حفظ هذا اللون.';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return 'اللون $index';
  }

  @override
  String get devicesScreenTitle => 'أجهزتك';

  @override
  String get devicesScreenSubtitle =>
      'كل مكان سجّلت فيه الدخول إلى هذا الحساب.';

  @override
  String get devicesScreenLoading => 'جارٍ التحقق…';

  @override
  String get devicesScreenLoadFailed => 'تعذّر تحميل أجهزتك';

  @override
  String get devicesScreenThisDevice => 'هذا الجهاز';

  @override
  String get devicesScreenActiveNow => 'نشط الآن';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count دقيقة',
      many: 'قبل $count دقيقة',
      few: 'قبل $count دقائق',
      two: 'قبل دقيقتين',
      one: 'قبل دقيقة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count ساعة',
      many: 'قبل $count ساعة',
      few: 'قبل $count ساعات',
      two: 'قبل ساعتين',
      one: 'قبل ساعة',
      zero: 'الآن',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قبل $count يوم',
      many: 'قبل $count يومًا',
      few: 'قبل $count أيام',
      two: 'قبل يومين',
      one: 'قبل يوم',
      zero: 'اليوم',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications => 'الإشعارات لا تصل إلى هذا الجهاز';

  @override
  String get devicesScreenRemove => 'إزالة';

  @override
  String get devicesScreenRemoveTitle => 'إزالة هذا الجهاز؟';

  @override
  String devicesScreenRemoveBody(Object name) {
    return 'سيتم تسجيل خروج $name وسيتوقف عن تلقي الإشعارات. من بحوزته الجهاز سيضطر إلى تسجيل الدخول من جديد.';
  }

  @override
  String get devicesScreenRemoveConfirm => 'إزالة';

  @override
  String get devicesScreenRemoveAll => 'إزالة كل الأجهزة الأخرى';

  @override
  String get devicesScreenRemoveAllTitle => 'إزالة كل الأجهزة الأخرى؟';

  @override
  String get devicesScreenRemoveAllBody =>
      'سيتم تسجيل خروجها جميعًا وستتوقف عن تلقي الإشعارات. هذا الجهاز وحده سيبقى مسجّل الدخول.';

  @override
  String get devicesScreenRemoveAllConfirm => 'إزالة الكل';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إزالة $count جهاز',
      many: 'تمت إزالة $count جهازًا',
      few: 'تمت إزالة $count أجهزة',
      two: 'تمت إزالة جهازين',
      one: 'تمت إزالة جهاز واحد',
      zero: 'لا توجد أجهزة أخرى لإزالتها',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed => 'تعذّرت إزالة هذا الجهاز';

  @override
  String get devicesScreenFootnote =>
      'إزالة جهاز تُسجّل خروجه وتوقف إشعاراته. يسري ذلك فورًا: أول شيء يحاول ذلك الجهاز فعله سيعيده إلى شاشة تسجيل الدخول.';

  @override
  String get attachmentMenuPollLabel => 'استطلاع';

  @override
  String get attachmentMenuChecklistLabel => 'قائمة';

  @override
  String get attachmentMenuEventLabel => 'مناسبة';

  @override
  String get interactionKindPoll => 'استطلاع';

  @override
  String get interactionKindQuiz => 'اختبار';

  @override
  String get interactionKindChecklist => 'قائمة';

  @override
  String get interactionKindEvent => 'مناسبة';

  @override
  String get interactionBadgeAnonymous => 'مجهول';

  @override
  String get interactionBadgeMultiple => 'متعدد';

  @override
  String get interactionBadgeClosed => 'مغلق';

  @override
  String interactionPercent(int percent) {
    return '$percent٪';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names +$count';
  }

  @override
  String get interactionSeeWhoAnswered => 'شاهد من أجاب';

  @override
  String interactionRemoveItem(String label) {
    return 'إزالة $label';
  }

  @override
  String interactionChoiceSemantics(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صوت',
      many: '$count صوتًا',
      few: '$count أصوات',
      two: 'صوتان',
      one: 'صوت واحد',
      zero: 'لا أصوات',
    );
    return '$label، $_temp0';
  }

  @override
  String get interactionAddItemHint => 'أضف عنصرًا';

  @override
  String get interactionRetract => 'تراجع';

  @override
  String get interactionClose => 'إغلاق';

  @override
  String interactionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صوت',
      many: '$count صوتًا',
      few: '$count أصوات',
      two: 'صوتان',
      one: 'صوت واحد',
      zero: 'لا أصوات',
    );
    return '$_temp0';
  }

  @override
  String interactionRsvpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رد',
      many: '$count ردًا',
      few: '$count ردود',
      two: 'ردان',
      one: 'رد واحد',
      zero: 'لا ردود',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$done من $total منجزة';
  }

  @override
  String get interactionNoAnswers => 'لا إجابات';

  @override
  String get interactionBeFirst => 'كن أول من يجيب';

  @override
  String interactionFinalResults(String count) {
    return '$count · نهائي';
  }

  @override
  String get interactionQuizRight => 'إجابة صحيحة';

  @override
  String get interactionQuizWrong => 'لم توفَّق';

  @override
  String interactionEventPast(String when) {
    return '$when · انتهت';
  }

  @override
  String get interactionRespondentsTitlePoll => 'من صوّت';

  @override
  String get interactionRespondentsTitleChecklist => 'من أشّر';

  @override
  String get interactionRespondentsTitleEvent => 'من ردّ';

  @override
  String get interactionRespondentsFailed => 'تعذّر تحميل من أجاب.';

  @override
  String get interactionRespondentsEmpty => 'لم يجب أحد بعد.';

  @override
  String get interactionFilterAll => 'الكل';

  @override
  String get interactionRsvpGoing => 'سآتي';

  @override
  String get interactionRsvpMaybe => 'ربما';

  @override
  String get interactionRsvpNo => 'لا أستطيع';

  @override
  String get interactionComposePollTitle => 'استطلاع جديد';

  @override
  String get interactionComposePollTagline => 'اسأل الغرفة';

  @override
  String get interactionComposeChecklistTitle => 'قائمة جديدة';

  @override
  String get interactionComposeChecklistTagline => 'قائمة يؤشّر عليها الجميع';

  @override
  String get interactionComposeEventTitle => 'مناسبة جديدة';

  @override
  String get interactionComposeEventTagline => 'شاهد من سيأتي';

  @override
  String get interactionComposeQuestionLabel => 'السؤال';

  @override
  String get interactionComposeQuestionHint => 'عمّ تسأل؟';

  @override
  String get interactionComposeTitleLabel => 'العنوان';

  @override
  String get interactionComposeTitleHint => 'لماذا هذه القائمة؟';

  @override
  String get interactionComposeEventNameLabel => 'المناسبة';

  @override
  String get interactionComposeEventNameHint => 'ماذا سيحدث؟';

  @override
  String get interactionComposeOptionsLabel => 'الخيارات';

  @override
  String get interactionComposeItemsLabel => 'العناصر';

  @override
  String interactionComposeOptionHint(int index) {
    return 'الخيار $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return 'العنصر $index';
  }

  @override
  String get interactionComposeAddOption => 'أضف خيارًا';

  @override
  String get interactionComposeAddItem => 'أضف عنصرًا';

  @override
  String get interactionComposeRemoveRow => 'إزالة';

  @override
  String get interactionComposeMarkCorrect => 'حدّده كإجابة صحيحة';

  @override
  String get interactionComposeMultipleTitle => 'إجابات متعددة';

  @override
  String get interactionComposeMultipleSub => 'اختر أكثر من واحد';

  @override
  String get interactionComposeAnonymousTitle => 'مجهول';

  @override
  String get interactionComposeAnonymousOffSub => 'الجميع يرى من صوّت';

  @override
  String get interactionComposeAnonymousOnSub => 'لا أحد يرى من صوّت';

  @override
  String get interactionComposeQuizTitle => 'وضع الاختبار';

  @override
  String get interactionComposeQuizSub => 'إجابة صحيحة واحدة، بلا تغيير';

  @override
  String get interactionComposeExplanationLabel => 'التوضيح';

  @override
  String get interactionComposeExplanationHint => 'يظهر بعد الإجابة (اختياري)';

  @override
  String get interactionComposeOthersMayCheckTitle => 'يمكن لأي أحد التأشير';

  @override
  String get interactionComposeOthersMayCheckSub => 'لست أنت وحدك';

  @override
  String get interactionComposeOthersMayAddTitle => 'يمكن لأي أحد الإضافة';

  @override
  String get interactionComposeOthersMayAddSub => 'يمكن أن تكبر القائمة لاحقًا';

  @override
  String get interactionComposeWhenLabel => 'متى';

  @override
  String get interactionComposePickStart => 'اختر وقت البداية';

  @override
  String get interactionComposePickEnd => 'أضف وقت نهاية (اختياري)';

  @override
  String get interactionComposePlaceLabel => 'المكان';

  @override
  String get interactionComposePlaceHint => 'أين؟ (اختياري)';

  @override
  String get interactionComposeSendPoll => 'أرسل الاستطلاع';

  @override
  String get interactionComposeSendChecklist => 'أرسل القائمة';

  @override
  String get interactionComposeSendEvent => 'أرسل المناسبة';

  @override
  String get interactionComposeErrorPrompt => 'اكتب أولًا عمّ تسأل.';

  @override
  String interactionComposeErrorOptions(int count) {
    return 'يحتاج الاستطلاع إلى $count خيارات على الأقل.';
  }

  @override
  String get interactionComposeErrorItems =>
      'تحتاج القائمة إلى عنصر واحد على الأقل.';

  @override
  String get interactionComposeErrorAnswer => 'حدّد الخيار الصحيح.';

  @override
  String get interactionComposeErrorWhen => 'اختر متى تبدأ.';

  @override
  String get interactionComposeErrorEnd => 'يجب أن تكون النهاية بعد البداية.';

  @override
  String get interactionSendFailed => 'لم يُرسل.';

  @override
  String get interactionRefused => 'لم يُسجَّل.';

  @override
  String get messageReceiptsScreenTitle => 'معلومات الرسالة';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return 'قرأها $read من $total';
  }

  @override
  String get messageReceiptsEmptyState => 'لا يوجد أحد آخر في هذه الغرفة بعد';

  @override
  String get messageReceiptsSectionRead => 'مقروءة';

  @override
  String get messageReceiptsSectionDelivered => 'تم التسليم';

  @override
  String get messageReceiptsSectionSent => 'أُرسلت';

  @override
  String get messageReceiptsSectionHidden => 'لا توجد إيصالات';

  @override
  String get messageReceiptsStateHidden => 'غير مُشارَك';

  @override
  String get messageReceiptsStateWaiting => 'في الانتظار';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return 'قرأها $name $day في $time';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return 'استلمها $name $day في $time';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return 'لم يستلمها $name بعد';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name لا يشارك إيصالات القراءة';
  }

  @override
  String get companionsScreenTitle => 'الرفاق.';

  @override
  String get companionsScreenSubtitle =>
      'مساعدون يعيشون في هذا الهاتف ولا يرسلون شيئًا إلى أي مكان';

  @override
  String get companionSebastianTagline => 'يترجم الرسائل';

  @override
  String get companionSebastianBlurb =>
      'يقرأ Sebastian رسالة مكتوبة بلغة أخرى ويخبرك بما تقوله، هنا على هاتفك، دون إرسال أي شيء إلى أي مكان.';

  @override
  String get companionMarloweTagline => 'مساعدة عامة';

  @override
  String get companionMarloweBlurb =>
      'يتولّى Marlowe كل ما ليس ترجمة. اختر عقلًا الآن، وستأتي المهارات لاحقًا.';

  @override
  String get companionAssuranceOnDevice => 'يعمل بالكامل على هذا الجهاز';

  @override
  String get companionAssurancePrivate => 'رسائلك لا تغادر هاتفك أبدًا';

  @override
  String get companionAssuranceOffline => 'يعمل بدون اتصال';

  @override
  String companionInstallAction(Object size) {
    return 'تثبيت · $size';
  }

  @override
  String get companionInstallOneTime => 'تنزيل لمرة واحدة، يبقى حتى تحذفه';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$received من $total';
  }

  @override
  String get companionInstallQueued => 'في انتظار انتهاء تنزيل آخر';

  @override
  String get companionInstallCancel => 'إلغاء';

  @override
  String get companionInstallRetry => 'حاول مجددًا';

  @override
  String companionInstallReady(Object name) {
    return '$name جاهز';
  }

  @override
  String get companionInstallFailedNetwork =>
      'تعذّر إكمال التنزيل. تحقّق من اتصالك وحاول مجددًا.';

  @override
  String get companionInstallFailedStorage =>
      'لا توجد مساحة كافية على هذا الجهاز. أفرغ بعض المساحة وحاول مجددًا.';

  @override
  String get companionInstallFailedUnknown => 'تعذّر إكمال التنزيل.';

  @override
  String get companionUnsupportedPlatform =>
      'الرفاق غير متوفرين بعد في هذا الإصدار من التطبيق.';

  @override
  String companionBrainNeedsMemory(String size) {
    return 'يتطلب $size من الذاكرة';
  }

  @override
  String get sebastianTierSeniorDetail => 'ترجمات أدق';

  @override
  String get sebastianTierJuniorDetail => 'يعمل على أي هاتف';

  @override
  String get sebastianLanguageUnlisted => 'ليست من لغاته، توقع نتائج تقريبية';

  @override
  String get companionStatusNotInstalled => 'غير مثبّت';

  @override
  String get companionStatusOff => 'مُعطّل';

  @override
  String companionStatusTranslatingInto(Object language) {
    return 'يترجم إلى $language';
  }

  @override
  String get companionStatusNoBrain => 'لم يتم تنزيل أي شيء بعد';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تنزيل جاهز',
      many: '$count تنزيلًا جاهزًا',
      few: '$count تنزيلات جاهزة',
      two: 'تنزيلان جاهزان',
      one: 'تنزيل واحد جاهز',
      zero: 'لا تنزيلات جاهزة',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty =>
      'لم يتم تنزيل أي شيء، فالرفاق لا يشغلون أي مساحة';

  @override
  String companionStorageUsed(Object size) {
    return 'يشغل الرفاق $size';
  }

  @override
  String get companionSectionGeneral => 'عام';

  @override
  String get companionSectionStorage => 'التخزين';

  @override
  String get companionBrainRemove => 'إزالة';

  @override
  String companionBrainRemoveTitle(Object name) {
    return 'إزالة $name؟';
  }

  @override
  String companionRemoveTitle(Object name) {
    return 'إزالة $name؟';
  }

  @override
  String companionRemoveMessage(Object size) {
    return 'هذا يوفّر $size. يمكنك تنزيله مرة أخرى في أي وقت.';
  }

  @override
  String get companionRemoveConfirm => 'إزالة';

  @override
  String get sebastianEnableLabel => 'دع Sebastian يترجم';

  @override
  String get sebastianEnableDetail => 'عطّله لإيقافه دون حذف التنزيل';

  @override
  String get sebastianLanguageSection => 'الترجمة إلى';

  @override
  String get sebastianLanguageFollowApp => 'نفس لغة التطبيق';

  @override
  String sebastianBrainDetail(Object size) {
    return 'على هذا الجهاز · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ترجمة محفوظة',
      many: '$count ترجمة محفوظة',
      few: '$count ترجمات محفوظة',
      two: 'ترجمتان محفوظتان',
      one: 'ترجمة واحدة محفوظة',
      zero: 'لا ترجمات محفوظة',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => 'مسح';

  @override
  String get marloweSkillsComingSoon =>
      'لا يستطيع Marlowe فعل شيء بعد، فالمهارات في الطريق. ما يمكنك فعله الآن هو تجهيز عقل، حتى لا ينتظر شيء تنزيلًا حين تصل.';

  @override
  String get marloweBrainsSection => 'العقل';

  @override
  String get marloweBrainsCaption =>
      'الأكبر يفكّر بشكل أفضل ويجيب ببطء أكثر. يمكنك الاحتفاظ بأكثر من واحد والتبديل بينها.';

  @override
  String get marloweBrainTierSwift => 'سريع';

  @override
  String get marloweBrainTierBalanced => 'متوازن';

  @override
  String get marloweBrainTierDeep => 'عميق';

  @override
  String get translationSlabShowOriginal => 'عرض الأصل';

  @override
  String get translationSlabFailed => 'تعذّرت ترجمة هذه الرسالة.';

  @override
  String get translationSlabRetry => 'حاول مجددًا';

  @override
  String translationSlabByCompanion(Object name) {
    return 'ترجمها $name';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return 'من $language';
  }

  @override
  String get messageActionMenuTranslateLabel => 'ترجمة';

  @override
  String get messageActionMenuShowOriginalLabel => 'عرض الأصل';

  @override
  String get roomTranslateTitle => 'ترجمة هذه المحادثة';

  @override
  String get roomTranslateStopTitle => 'إيقاف الترجمة';

  @override
  String get roomTranslateSectionLabel => 'الترجمة';

  @override
  String get roomTranslateOnRow => 'يترجم هذه المحادثة';

  @override
  String get roomTranslateOffRow => 'مُعطّل';

  @override
  String get roomTranslateNeedsSetUp => 'إعداد Sebastian';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'Sebastian يترجم · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return 'تقرأ بـ$language';
  }

  @override
  String get roomTranslateStop => 'إيقاف';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return 'بالفعل بـ$language';
  }

  @override
  String get roomScreenTranslateRoomOffer => 'هل نترجم بقية المحادثة أيضًا؟';

  @override
  String get roomScreenTranslateRoomOfferAction => 'ترجمة الكل';

  @override
  String get settingsScreenCompanionsOff => 'مُعطّل';

  @override
  String get settingsScreenCompanionsUnavailable => 'غير متوفر';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return 'يستخدمه $name أيضًا';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return 'يستخدم $name التنزيل نفسه وسيفقده أيضًا.';
  }

  @override
  String get companionBrainInUse => 'قيد الاستخدام';

  @override
  String companionStatusUsingBrain(Object name) {
    return 'يستخدم $name';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return 'يستمر تنزيل $name في الإعدادات › الرفاق';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return 'جارٍ التنزيل · $percent٪';
  }

  @override
  String get companionInstallPause => 'إيقاف مؤقت';

  @override
  String get companionInstallResume => 'استئناف';

  @override
  String get companionInstallDiscard => 'تجاهل';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return 'متوقف مؤقتًا · $received من $total';
  }

  @override
  String get companionInstallFailedIntegrity =>
      'الملف الذي جرى تنزيله لا يطابق ما يتوقعه هذا الإصدار. سيبدأ من جديد.';

  @override
  String companionBannerDownloading(
    Object name,
    Object received,
    Object total,
  ) {
    return '$name · $received من $total';
  }

  @override
  String companionBannerPaused(Object name, Object received, Object total) {
    return '$name متوقف مؤقتًا · $received من $total';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name يستيقظ…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => 'أعد الترجمة';

  @override
  String get groupCallScreenShareLabel => 'مشاركة';

  @override
  String get groupCallScreenStopShareLabel => 'إيقاف المشاركة';

  @override
  String get groupCallScreenShareStartingLabel => 'جارٍ البدء…';

  @override
  String get groupCallScreenRingingLabel => 'يرن…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name يشارك شاشته';
  }

  @override
  String get groupCallScreenYouAreSharing => 'أنت تشارك شاشتك';

  @override
  String get groupCallScreenDrawLabel => 'رسم';

  @override
  String get callScreenControlShare => 'مشاركة';

  @override
  String get callScreenControlStopShare => 'إيقاف';

  @override
  String get callScreenControlShareStarting => 'جارٍ البدء…';

  @override
  String get screenShareStopDrawing => 'إيقاف الرسم';

  @override
  String get screenShareDrawBoardIdle => 'تظهر الرسومات هنا';

  @override
  String get screenShareOverlayHint =>
      'اعرض الرسومات فوق التطبيقات الأخرى أثناء المشاركة';

  @override
  String get screenShareOverlayAllow => 'السماح';

  @override
  String get callScreenControlDraw => 'رسم';

  @override
  String get callScreenControlMinimize => 'تصغير';

  @override
  String get inCallPillOngoingCall => 'مكالمة جارية';

  @override
  String get inCallPillReturn => 'عودة';

  @override
  String get inCallPillSharing => 'أنت تشارك شاشتك';

  @override
  String get inCallPillDrawSemanticLabel => 'الرسم على الشاشة المشتركة';

  @override
  String get inCallPillStopSharingSemanticLabel => 'إيقاف المشاركة';

  @override
  String get screenShareUnsupported => 'مشاركة الشاشة غير متاحة على هذا الجهاز';

  @override
  String get screenShareEphemeralWarning =>
      'حماية الالتقاط متوقفة أثناء المشاركة';

  @override
  String get screenShareNotificationTitle => 'مشاركة شاشتك';

  @override
  String get screenShareNotificationBody => 'يمكن للجميع في المكالمة رؤيتها';

  @override
  String get screenShareNotificationStop => 'إيقاف';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name يشارك بالفعل';
  }

  @override
  String get screenShareFailed => 'تعذّر بدء المشاركة';

  @override
  String get screenSharePickerTitle => 'شارك شاشتك';

  @override
  String get screenSharePickerScreens => 'الشاشات';

  @override
  String get screenSharePickerWindows => 'النوافذ';

  @override
  String get screenSharePickerEmpty =>
      'لا شيء للمشاركة بعد. اسمح بتسجيل الشاشة في إعدادات النظام وحاول مجددًا';

  @override
  String get gameTellFriends => 'أخبر أصدقاءك';

  @override
  String get gameToldFriends => 'تم إخبارهم';

  @override
  String get gameTellFriendsTitle => 'نُخبر أصدقاءك؟';

  @override
  String get gameTellFriendsBody =>
      'سيصلهم إشعار بهذه النتيجة. يمكن إرساله مرة واحدة فقط.';

  @override
  String get gameTellFriendsCancel => 'ليس الآن';

  @override
  String get gameTellFriendsConfirm => 'أرسِل';

  @override
  String get gameTellFriendsSent => 'أُرسل، صاروا يعرفون';

  @override
  String get gameTellFriendsPrivate => 'نتائجك اليومية خاصة، لن يراها أحد';

  @override
  String get gameTellFriendsFailed => 'تعذّر الإرسال';

  @override
  String get settingsScreenFriendActivityLabel => 'نشاط الأصدقاء';

  @override
  String get settingsScreenFriendActivityOnBody =>
      'اللحظات والنقاط ونتائج الألعاب فور نشرها';

  @override
  String get settingsScreenFriendActivityOffBody =>
      'لا شيء، لوحاتهم موجودة متى نظرت';

  @override
  String get searchScreenActionWithGrownUp => 'عند وليّ الأمر';

  @override
  String get newChatMenuSearchHint => 'ابحث في أصدقائك';

  @override
  String get newChatMenuNoFriendsYet =>
      'لا أصدقاء بعد. ابحث عن أشخاص في الاستكشاف';

  @override
  String get newChatMenuNoFriendsMatch => 'لا يوجد صديق مطابق';

  @override
  String get newChatMenuOpenDmFailed => 'تعذّر فتح تلك المحادثة. حاول مرة أخرى';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'اختر من أشخاصك';

  @override
  String get childPolicyScreenPickPersonHint => 'ابحث باسم أو باسم مستخدم';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'لم يبق أحد لإضافته من أصدقائك،\\nابحث عن أي شخص آخر';

  @override
  String get childPolicyScreenPickPersonNoMatch => 'لا أحد مطابق';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'أصدقاؤك';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'بقية الأشخاص';

  @override
  String get childPolicyScreenAddRoomLabel => 'أضف غرفة';

  @override
  String get childPolicyScreenPickRoomHeading => 'أضف غرفة';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'إحدى غرفك أنت. سينضم $name فورًا ويمكنه القراءة والنشر فيها حتى تسحب ذلك.';
  }

  @override
  String get childPolicyScreenPickRoomHint => 'ابحث في غرفك';

  @override
  String get childPolicyScreenPickRoomEmpty => 'لم تبق لك غرفة لإضافتها';

  @override
  String get childPolicyScreenPickRoomNoMatch => 'لا توجد غرفة مطابقة';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name الآن في $room';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'تعذّر إضافة تلك الغرفة. حاول مرة أخرى';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'لا يمكن إضافة تلك الغرفة بهذه الطريقة';

  @override
  String get childPolicyScreenErrorRoomGone => 'تلك الغرفة لم تعد موجودة';

  @override
  String get newChatMenuFriendsHeader => 'الأصدقاء';

  @override
  String get roomChangeErrorGone =>
      'الاقتراح لم يعد موجودًا، ربما ردّ عليه أحد المشرفين.';

  @override
  String get roomChangeErrorNotYours => 'لا يسحب الاقتراح إلا صاحبه.';

  @override
  String get roomChangeErrorNoChange => 'هذا هو المكتوب أصلًا.';

  @override
  String get roomChangeErrorMissingValue => 'لا يمكن حفظ هذا بهذا الشكل.';

  @override
  String get roomChangeRequestsTitle => 'الاقتراحات';

  @override
  String get roomChangeRequestsBlurb =>
      'اقترحها الأعضاء. لا يتغير شيء حتى توافق.';

  @override
  String get roomChangeRequestsEmpty => 'لا اقتراحات.';

  @override
  String get roomChangeRequestsApprove => 'اعتمدها';

  @override
  String get roomChangeRequestsReject => 'لا';

  @override
  String get roomChangeRequestsPhotoLabel => 'صورة جديدة للمجموعة';

  @override
  String get roomChangeRequestsNameLabel => 'اسم جديد';

  @override
  String get roomChangeRequestsDescriptionLabel => 'وصف جديد';

  @override
  String get roomChangeRequestsUnknownLabel =>
      'تغيير لا يستطيع التطبيق عرضه بعد';

  @override
  String get roomChangeRequestsClearedValue => 'لا شيء، احذفه';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return 'اقترحه $name';
  }

  @override
  String get roomAdminChangeRequestsRow => 'الاقتراحات';

  @override
  String get roomInfoScreenSuggestNote => 'يحتاج هذا إلى موافقة مشرف';

  @override
  String get roomInfoScreenSuggestAvatarNote =>
      'المشرفون يوافقون على الصور الجديدة';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic => 'اقترح صورة للمجموعة';

  @override
  String get roomInfoScreenSuggestionSentToast => 'أُرسل إلى المشرفين';

  @override
  String get roomInfoScreenSuggestionAppliedToast =>
      'تم. يمكنك تعديل هذه المجموعة';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => 'سُحب';

  @override
  String get roomInfoScreenSuggestionsLabel => 'اقتراحاتك';

  @override
  String get roomInfoScreenSuggestionPhoto => 'صورة جديدة للمجموعة';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return 'الاسم: $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return 'الوصف: $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => 'تغيير';

  @override
  String get roomInfoScreenSuggestionPending => 'بانتظار مشرف';

  @override
  String get roomInfoScreenSuggestionWithdraw => 'اسحبه';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return 'اقترح $name صورة جديدة للمجموعة';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return 'اقترح $name اسمًا جديدًا';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return 'اقترح $name وصفًا جديدًا';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اقتراح بانتظارك',
      many: '$count اقتراحًا بانتظارك',
      few: '$count اقتراحات بانتظارك',
      two: 'اقتراحان بانتظارك',
      one: 'اقتراح واحد بانتظارك',
      zero: 'لا اقتراحات بانتظارك',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => 'مراجعة';

  @override
  String get roomSuggestionBannerSemantic => 'اقتراحات الأعضاء بانتظار مراجعتك';

  @override
  String get gameInfoPlay => 'العب';

  @override
  String get gameInfoContinue => 'تابع اللعب';

  @override
  String get gameInfoSeeResult => 'شاهد نتيجتك';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return 'وصلت إلى $delivered من $total';
  }

  @override
  String get messageReceiptsSentLabel => 'أُرسلت';

  @override
  String messageReceiptsSemanticDeliveredThenRead(
    Object deliveredDay,
    Object deliveredTime,
    Object name,
    Object readDay,
    Object readTime,
  ) {
    return 'استلمها $name $deliveredDay في $deliveredTime وقرأها $readDay في $readTime';
  }

  @override
  String get messageReceiptsStampRead => 'قُرئت';

  @override
  String get messageReceiptsStampDelivered => 'وصلت';

  @override
  String get roomInviteCustom => 'مخصص';

  @override
  String roomInviteCustomHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ساعة',
      many: '$count ساعة',
      few: '$count ساعات',
      two: 'ساعتان',
      one: 'ساعة واحدة',
      zero: '$count ساعة',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
      zero: '$count يوم',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count استخدام',
      many: '$count استخدامًا',
      few: '$count استخدامات',
      two: 'استخدامان',
      one: 'استخدام واحد',
      zero: '$count استخدام',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => 'ساعات';

  @override
  String get roomInviteUnitDays => 'أيام';

  @override
  String get roomInviteStepperIncrease => 'زيادة';

  @override
  String get roomInviteStepperDecrease => 'إنقاص';

  @override
  String get recordsLabel => 'كل الأوقات';

  @override
  String get recordsBlurb => 'أفضل ما حققه أحد على الإطلاق: أنت وأصدقاؤك';

  @override
  String recordsYourBest(Object value) {
    return 'رقمك $value';
  }

  @override
  String get recordsNoneYet => 'لا أحد بعد';

  @override
  String get recordsEmpty => 'حُلّ أي لعبة وسيظهر أفضل رقم لك هنا.';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حل',
      many: '$count حلًا',
      few: '$count حلول',
      two: 'حلّان',
      one: 'حل واحد',
      zero: '$count حل',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return 'سُجّل في $date';
  }

  @override
  String recordsReactSemantic(Object name) {
    return 'تفاعل مع رقم $name';
  }

  @override
  String get recordsReactFailed => 'تعذّر التفاعل';

  @override
  String get recordsLoadFailed => 'تعذّر تحميل الأرقام';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game: رقم $value باسم $name';
  }

  @override
  String get appearanceLabel => 'المظهر';

  @override
  String get appearanceMatchDevice => 'مثل الجهاز';

  @override
  String get appearanceMatchDeviceSub => 'فاتح نهارًا، داكن ليلًا، مع هاتفك';

  @override
  String get appearanceOneTheme => 'مظهر واحد';

  @override
  String get appearanceOneThemeSub => 'المظهر نفسه طوال اليوم';

  @override
  String get appearanceLightSlot => 'الوضع الفاتح';

  @override
  String get appearanceDarkSlot => 'الوضع الداكن';

  @override
  String get appearanceNow => 'الآن';

  @override
  String appearanceAutoValue(Object name) {
    return 'تلقائي · $name';
  }

  @override
  String get themeScreenAssignHint =>
      'اضغط على مظهر لاستخدامه في الوضع الفاتح أو الداكن · ⛶ للمعاينة الكاملة';

  @override
  String get themeScreenCarouselUseLight => 'استخدمه في الوضع الفاتح';

  @override
  String get themeScreenCarouselUseDark => 'استخدمه في الوضع الداكن';

  @override
  String get themeScreenCarouselIsLight => 'مظهرك الفاتح';

  @override
  String get themeScreenCarouselIsDark => 'مظهرك الداكن';

  @override
  String get onboardingThemeTitle => 'اجعله على ذوقك.';

  @override
  String get onboardingThemeBody =>
      'اختر مظهرًا. يمكنك تغييره متى شئت من الإعدادات.';

  @override
  String get onboardingThemeYourTheme => 'مظهرك';

  @override
  String get onboardingThemeContinue => 'متابعة';

  @override
  String get dropHintNoTarget => 'أفلِتها على محادثة لإرسالها';

  @override
  String get dropNothingToSend => 'لا شيء هنا يمكن إرساله';

  @override
  String dropSendPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إرسال $count صورة',
      many: 'إرسال $count صورة',
      few: 'إرسال $count صور',
      two: 'إرسال صورتين',
      one: 'إرسال صورة',
      zero: 'إرسال $count صور',
    );
    return '$_temp0';
  }

  @override
  String dropSendVideos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إرسال $count مقطع',
      many: 'إرسال $count مقطعًا',
      few: 'إرسال $count مقاطع',
      two: 'إرسال مقطعين',
      one: 'إرسال مقطع فيديو',
      zero: 'إرسال $count مقاطع',
    );
    return '$_temp0';
  }

  @override
  String dropSendAudio(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إرسال $count ملف صوتي',
      many: 'إرسال $count ملفًا صوتيًا',
      few: 'إرسال $count ملفات صوتية',
      two: 'إرسال ملفين صوتيين',
      one: 'إرسال ملف صوتي',
      zero: 'إرسال $count ملفات صوتية',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إرسال $count ملف',
      many: 'إرسال $count ملفًا',
      few: 'إرسال $count ملفات',
      two: 'إرسال ملفين',
      one: 'إرسال ملف',
      zero: 'إرسال $count ملفات',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'إرسال $count عنصر',
      many: 'إرسال $count عنصرًا',
      few: 'إرسال $count عناصر',
      two: 'إرسال عنصرين',
      one: 'إرسال عنصر',
      zero: 'إرسال $count عناصر',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => 'إضافة إلى الرسالة';

  @override
  String get dropSendLink => 'إضافة الرابط';

  @override
  String dropTargetTo(String name) {
    return 'إلى $name';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف يتجاوز $size',
      many: '$count ملفًا يتجاوز $size',
      few: '$count ملفات تتجاوز $size',
      two: 'ملفان يتجاوزان $size',
      one: 'ملف واحد يتجاوز $size',
      zero: '$count ملفات تتجاوز $size',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => 'لا يمكن إرسال المجلدات';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تخطّي $count ملف فارغ',
      many: 'تخطّي $count ملفًا فارغًا',
      few: 'تخطّي $count ملفات فارغة',
      two: 'تخطّي ملفين فارغين',
      one: 'تخطّي ملف فارغ',
      zero: 'تخطّي $count ملفات فارغة',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => 'المرفقات غير مسموح بها هنا';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سيُرسل $count كملفات',
      many: 'سيُرسل $count كملفات',
      few: 'سيُرسل $count كملفات',
      two: 'سيُرسلان كملفات',
      one: 'سيُرسل كملف',
      zero: 'سيُرسل $count كملفات',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قد لا تظهر $count على كل الأجهزة',
      many: 'قد لا تظهر $count على كل الأجهزة',
      few: 'قد لا تظهر $count على كل الأجهزة',
      two: 'قد لا تظهران على كل الأجهزة',
      one: 'قد لا تظهر على كل الأجهزة',
      zero: 'قد لا تظهر $count على كل الأجهزة',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => 'صورة';

  @override
  String get dropKindVideo => 'فيديو';

  @override
  String get dropKindAudio => 'صوت';

  @override
  String get dropKindFile => 'ملف';

  @override
  String get dropKindFolder => 'مجلد';

  @override
  String get dropKindText => 'نص';

  @override
  String get dropKindLink => 'رابط';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف لم يتسع في هذا الإرسال',
      many: '$count ملفًا لم يتسع في هذا الإرسال',
      few: '$count ملفات لم تتسع في هذا الإرسال',
      two: 'ملفان لم يتسعا في هذا الإرسال',
      one: 'ملف واحد لم يتسع في هذا الإرسال',
      zero: '$count ملفات لم تتسع في هذا الإرسال',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed => 'تعذّر ذلك. حاول مجددًا.';

  @override
  String get expressionBackspace => 'حذف';

  @override
  String get expressionCreateSticker => 'اصنع ملصقًا';

  @override
  String get expressionDeleteSticker => 'احذف من ملصقاتي';

  @override
  String get expressionFavorite => 'أضف إلى المفضلة';

  @override
  String get expressionFavorited => 'أُضيف إلى المفضلة';

  @override
  String get expressionFavorites => 'المفضلة';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF: $title';
  }

  @override
  String get expressionLoadFailed => 'تعذّر التحميل. تحقّق من اتصالك.';

  @override
  String get expressionMediaNotAllowed =>
      'إعدادات عائلتك لا تسمح بإرسال الصور.';

  @override
  String get expressionMyStickers => 'ملصقاتي';

  @override
  String get expressionNoFavorites =>
      'اضغط مطولًا على صورة GIF أو ملصق لإضافته إلى المفضلة.';

  @override
  String get expressionNoRecents => 'ستظهر هنا صور GIF والملصقات التي ترسلها.';

  @override
  String get expressionNoResults => 'لا توجد نتائج';

  @override
  String get expressionNoStickers => 'لا توجد ملصقات هنا بعد.';

  @override
  String get expressionOpenPanel => 'الرموز التعبيرية وصور GIF والملصقات';

  @override
  String get expressionOptionsHint => 'عرض الخيارات';

  @override
  String expressionPackCredit(String author, String license) {
    return 'الرسم: $author · $license';
  }

  @override
  String get expressionPlayGifHint => 'تشغيل';

  @override
  String get expressionRecent => 'الأخيرة';

  @override
  String get expressionReport => 'إبلاغ';

  @override
  String get expressionReported => 'شكرًا، تم الإبلاغ.';

  @override
  String get expressionRetry => 'حاول مجددًا';

  @override
  String get expressionSearchKlipy => 'ابحث في KLIPY';

  @override
  String get expressionShowKeyboard => 'إظهار لوحة المفاتيح';

  @override
  String get expressionSuggestionsLabel => 'ملصقات مقترحة';

  @override
  String get expressionTabEmoji => 'الرموز التعبيرية';

  @override
  String get expressionTabGifs => 'GIF';

  @override
  String get expressionTabStickers => 'الملصقات';

  @override
  String get expressionTrending => 'الرائج';

  @override
  String get expressionUnfavorite => 'أزل من المفضلة';

  @override
  String get expressionUnfavorited => 'أُزيل من المفضلة';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return 'ملصق $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel =>
      'تشغيل صور GIF والملصقات تلقائيًا';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      'تبقى ثابتة حتى تضغط على أحدها. يوفّر البيانات.';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'تُشغَّل صور GIF والملصقات المتحركة تلقائيًا. خيار تقليل الحركة يوقفها مؤقتًا.';

  @override
  String get settingsAlbumCardsLabel => 'ألبومات الصور كبطاقات';

  @override
  String get settingsAlbumCardsOffBody =>
      'تظهر الصور المتعددة في رسالة واحدة على شكل شبكة.';

  @override
  String get settingsAlbumCardsOnBody =>
      'تظهر الصور المتعددة في رسالة واحدة كمجموعة بطاقات تتصفحها بالسحب.';

  @override
  String get settingsStickerSuggestionsBody =>
      'كتابة رمز تعبيري واحد تعرض ملصقات مطابقة فوق حقل الرسالة.';

  @override
  String get settingsStickerSuggestionsLabel => 'ملصقات مقترحة';

  @override
  String get stickerMakerEmojiLabel => 'ما هو الرمز التعبيري؟';

  @override
  String get stickerMakerFailed => 'تعذّر حفظ الملصق. حاول مجددًا.';

  @override
  String get stickerMakerMoreEmoji => 'مزيد من الرموز التعبيرية';

  @override
  String get stickerMakerPreview => 'معاينة الملصق';

  @override
  String get stickerMakerRemoveBackground => 'إزالة الخلفية';

  @override
  String get stickerMakerSave => 'حفظ';

  @override
  String get stickerMakerSaved => 'أُضيف الملصق إلى ملصقاتي';

  @override
  String get stickerMakerShape => 'الشكل';

  @override
  String get stickerMakerShapeCircle => 'دائرة';

  @override
  String get stickerMakerShapeOriginal => 'الأصلي';

  @override
  String get stickerMakerShapeRounded => 'مربع بحواف مستديرة';

  @override
  String get stickerMakerTitle => 'ملصق جديد';

  @override
  String get stickerMakerTooMany =>
      'وصلت إلى الحد الأقصى للملصقات. احذف واحدًا لتفريغ مساحة.';

  @override
  String get expressionExpandPanel => 'توسيع اللوحة';

  @override
  String get expressionCollapsePanel => 'تصغير اللوحة';

  @override
  String get expressionPackStore => 'حزم الملصقات';

  @override
  String get expressionPackSearchHint => 'ابحث في حزم الملصقات';

  @override
  String get expressionPacksAdded => 'المُضافة';

  @override
  String get expressionPacksMore => 'حزم أخرى';

  @override
  String get expressionPackAdd => 'إضافة';

  @override
  String get expressionPackRemove => 'إزالة';

  @override
  String expressionPackStickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملصق',
      many: '$count ملصقًا',
      few: '$count ملصقات',
      two: 'ملصقان',
      one: 'ملصق واحد',
      zero: 'لا ملصقات',
    );
    return '$_temp0';
  }

  @override
  String get expressionNoPacksFound => 'لا توجد حزم مطابقة';

  @override
  String get expressionAllPacksAdded => 'أضفت كل الحزم.';

  @override
  String expressionPackReorder(String title) {
    return 'إعادة ترتيب $title';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return 'أضف حزمة «$title»';
  }

  @override
  String expressionPackAddedToast(String title) {
    return 'أُضيفت «$title» إلى ملصقاتك';
  }

  @override
  String get expressionPacksFromKlipy => 'مزيد من الملصقات من KLIPY';

  @override
  String expressionSearchKlipyFor(String query) {
    return 'ابحث عن «$query» في KLIPY';
  }

  @override
  String get expressionHideKeyboard => 'إخفاء لوحة المفاتيح';

  @override
  String get expressionSearchStickers => 'ابحث في الملصقات';

  @override
  String get expressionYourStickers => 'ملصقاتك';

  @override
  String get chatListYesterday => 'أمس';

  @override
  String get roomLayoutScreenCardsLayoutLabel => 'بطاقات';

  @override
  String get roomLayoutScreenCardsLayoutDescription =>
      'كل غرفة في بطاقتها الخاصة، وكل التفاصيل مكتوبة.';

  @override
  String get homeScreenTitle => 'الدردشات';

  @override
  String get glassScreenNativeLabel => 'زجاج iOS السائل';

  @override
  String get glassScreenNativeOnBody =>
      'يرسم iOS شريط التبويب بنفسه. تضبط المنزلقات أدناه بقية التطبيق.';

  @override
  String get glassScreenNativeOffBody =>
      'يرسم MonkeyHub زجاجه الخاص في كل مكان، وتضبطه المنزلقات أدناه.';

  @override
  String get glassScreenHeading => 'الزجاج';

  @override
  String get glassStyleHeader => 'النمط';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody =>
      'زجاج Apple نفسه، يرسمه iOS. تتطابق معه الأزرار في كل التطبيق.';

  @override
  String get glassStyleFrostedTitle => 'مُصنفَر';

  @override
  String get glassStyleFrostedBody =>
      'زجاج MonkeyHub الخاص. اضبط كل إعداد بنفسك.';

  @override
  String get glassStyleRecommended => 'موصى به';

  @override
  String get glassStyleLiquidFooter =>
      'لا شيء لضبطه: يحدد iOS التمويه والتلوين والإضاءة. اختر «مُصنفَر» لتشكيل الزجاج بنفسك.';

  @override
  String get acctSectionPrivacy => 'الخصوصية';

  @override
  String get acctSectionAccount => 'الحساب';

  @override
  String get acctSectionFamily => 'العائلة';

  @override
  String get acctSectionThisPhone => 'هذا الهاتف';

  @override
  String get acctRowVisibility => 'ظهور الملف الشخصي';

  @override
  String get acctRowBlocked => 'المستخدمون المحظورون';

  @override
  String get acctRowApprovals => 'الموافقات';

  @override
  String get acctNothingWaiting => 'لا شيء بانتظارك';

  @override
  String get acctRowLinked => 'الحسابات المرتبطة';

  @override
  String get acctRowScanToSignIn => 'امسح لتسجيل الدخول';

  @override
  String get acctRowSetUpRecovery => 'إعداد عبارة الاسترداد';

  @override
  String get acctRowChangeRecovery => 'تغيير عبارة الاسترداد';

  @override
  String get acctSignOut => 'تسجيل الخروج';

  @override
  String get acctDeleteAccount => 'حذف الحساب';

  @override
  String get acctConfirmDelete => 'انقر مرة أخرى للحذف';

  @override
  String get acctHandPhoneBack => 'أعِد هذا الهاتف';

  @override
  String get acctMyGrownUps => 'الكبار المسؤولون عني';

  @override
  String get acctActionMessage => 'رسالة';

  @override
  String get acctActionAddFriend => 'إضافة';

  @override
  String get acctActionRequested => 'تم الطلب';

  @override
  String get acctActionAccept => 'قبول';

  @override
  String get acctActionNotAccepting => 'مغلق';

  @override
  String get acctActionUnfriend => 'إلغاء';

  @override
  String get acctActionBlock => 'حظر';

  @override
  String get acctActionReport => 'إبلاغ';

  @override
  String get acctStatusFriends => 'أصدقاء';

  @override
  String get acctStatusRequestSent => 'تم إرسال الطلب';

  @override
  String get acctStatusWantsToConnect => 'يريد أن يكون صديقك';

  @override
  String get acctStatusNotConnected => 'لا يوجد اتصال بينكما';

  @override
  String get acctPresenceOnline => 'متصل الآن';

  @override
  String get acctPresenceAway => 'بعيد';

  @override
  String get acctPresenceOffline => 'غير متصل حاليًا';

  @override
  String get acctProfilePhoto => 'صورة الملف الشخصي';

  @override
  String get acctSaveToPhotos => 'حفظ في الصور';

  @override
  String get acctTakeSelfie => 'التقط صورة سيلفي';

  @override
  String get acctChooseFromLibrary => 'اختر من المكتبة';

  @override
  String get acctCancel => 'إلغاء';

  @override
  String get acctSave => 'حفظ';

  @override
  String get acctChange => 'تغيير';

  @override
  String get acctNotNow => 'ليس الآن';

  @override
  String get acctAddEmail => 'إضافة بريد إلكتروني';

  @override
  String get acctEditNameTitle => 'تعديل الاسم';

  @override
  String get acctAddNameTitle => 'أضف اسمك';

  @override
  String get acctEditEmailTitle => 'تعديل البريد الإلكتروني';

  @override
  String get acctChangeUsernameTitle => 'تغيير اسم المستخدم؟';

  @override
  String get onboardingLookTitle => 'اجعله على ذوقك';

  @override
  String get onboardingLookBody =>
      'اختر مظهرًا. يمكنك تغييره في أي وقت من الإعدادات.';

  @override
  String get onboardingEssentials => 'الأساسية';

  @override
  String get onboardingEssentialsSub => 'هادئة وأصيلة';

  @override
  String get onboardingCharacters => 'بطابع خاص';

  @override
  String get onboardingCharactersSub => 'التطبيق نفسه، بشخصية أكبر';

  @override
  String get onboardingLightMode => 'الوضع الفاتح';

  @override
  String get onboardingDarkMode => 'الوضع الداكن';

  @override
  String get onboardingNow => 'الآن';

  @override
  String get onboardingContinue => 'متابعة';

  @override
  String get onboardingIconTitle => 'أيقونة التطبيق';

  @override
  String get onboardingIconBody =>
      'احتفظ بأيقونتك الحالية، أو اجعلها تتبع مظهرك، أو اختر أي شعار.';

  @override
  String get onboardingIconIosNote =>
      'يعرض iOS تنبيهًا قصيرًا كلما تغيّرت الأيقونة.';

  @override
  String get onboardingGetStarted => 'لنبدأ';

  @override
  String get appIconMatchTheme => 'مطابقة المظهر';

  @override
  String get appIconCurrent => 'الحالية';

  @override
  String get appIconSectionCollection => 'مجموعة MonkeyHub';

  @override
  String get appIconSectionThemes => 'أيقونات المظاهر';

  @override
  String get appIconScreenTitle => 'أيقونة التطبيق';

  @override
  String get appIconMatchFooter =>
      'خيار مطابقة المظهر يغيّر الأيقونة مع مظهر الوضع الداكن، فلا تتبدّل ذهابًا وإيابًا خلال اليوم.';

  @override
  String get loginTitleReturning => 'مرحبًا بعودتك';

  @override
  String get loginTitleFirst => 'مرحبًا بك في MonkeyHub';

  @override
  String get loginTitleSignUp => 'أنشئ حسابك';

  @override
  String get loginTitleReset => 'أعد تعيين كلمة المرور';

  @override
  String get loginSubtitleSignIn => 'سجّل الدخول لتتابع من حيث توقفت.';

  @override
  String get loginSubtitleFirst => 'سجّل الدخول، أو أنشئ حسابًا في ثوانٍ.';

  @override
  String get loginSubtitleSignUp => 'كل ما تحتاجه اسم مستخدم وكلمة مرور.';

  @override
  String get loginSubtitleReset =>
      'أدخل عبارة الاسترداد المكوّنة من 12 كلمة واختر كلمة مرور جديدة.';

  @override
  String get loginCtaSignIn => 'تسجيل الدخول';

  @override
  String get loginCtaSignUp => 'إنشاء حساب';

  @override
  String get loginCtaReset => 'إعادة تعيين كلمة المرور';

  @override
  String get loginNoAccountPrompt => 'جديد هنا؟ ';

  @override
  String get loginCreateAccountLink => 'أنشئ حسابًا';

  @override
  String get loginHaveAccountPrompt => 'لديك حساب بالفعل؟ ';

  @override
  String get loginSignInLink => 'سجّل الدخول';

  @override
  String get loginForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get loginChildAccount => 'إعداد حساب طفل';

  @override
  String get loginBackToSignIn => 'العودة إلى تسجيل الدخول';

  @override
  String get loginWithPhone => 'سجّل الدخول بهاتفك';

  @override
  String get loginUsernameField => 'اسم المستخدم';

  @override
  String get loginPasswordField => 'كلمة المرور';

  @override
  String get loginConfirmPasswordField => 'تأكيد كلمة المرور';

  @override
  String get loginNameField => 'الاسم (اختياري)';

  @override
  String get loginRecoveryPhraseField => 'عبارة الاسترداد المكوّنة من 12 كلمة';

  @override
  String get loginNewPasswordField => 'كلمة مرور جديدة';

  @override
  String get roomHeaderStatusOnline => 'متصل الآن';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عضو',
      many: '$count عضوًا',
      few: '$count أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
      zero: 'لا أعضاء',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => 'الإعدادات';

  @override
  String get settingsHubAccountHintAdult =>
      'الملف الشخصي والعائلة والحسابات المرتبطة والخصوصية';

  @override
  String get settingsHubAccountHintChild =>
      'الملف الشخصي والخصوصية والكبار المسؤولون عنك';

  @override
  String get settingsHubSectionGeneral => 'عام';

  @override
  String get settingsHubSectionNotifications => 'الإشعارات';

  @override
  String get settingsHubSectionCalls => 'المكالمات';

  @override
  String get settingsHubSectionAppearance => 'المظهر';

  @override
  String get settingsHubSectionCompanions => 'الرفاق';

  @override
  String get settingsHubSectionChats => 'الدردشات';

  @override
  String get settingsHubSectionHelp => 'المساعدة والشؤون القانونية';

  @override
  String get settingsHubSectionAdvanced => 'متقدم';

  @override
  String get settingsHubLanguage => 'اللغة';

  @override
  String get settingsHubCheckForUpdates => 'التحقق من وجود تحديثات';

  @override
  String get settingsHubUpdateAvailable => 'يتوفر تحديث';

  @override
  String get settingsHubShowLinkUrls => 'إظهار عناوين الروابط';

  @override
  String get settingsHubShowLinkUrlsSubtitle =>
      'عرض العنوان بجانب كل معاينة رابط';

  @override
  String get settingsHubPresenceDots => 'إظهار المتصلين';

  @override
  String get settingsHubPresenceDotsSubtitle => 'النقطة على صور الملف الشخصي';

  @override
  String get settingsHubPush => 'الإشعارات الفورية';

  @override
  String get settingsHubPushSubtitle => 'الرسائل الجديدة والمكالمات والطلبات';

  @override
  String get settingsHubGameReminders => 'تذكير اللعبة اليومي';

  @override
  String get settingsHubGameRemindersSubtitle =>
      'تذكير واحد وقت الغداء إن لم تلعب';

  @override
  String get settingsHubFriendActivity => 'نشاط الأصدقاء';

  @override
  String get settingsHubFriendActivitySubtitle =>
      'أبرز اللحظات والنقاط ونتائج الألعاب من الأصدقاء';

  @override
  String get settingsHubMenuBar => 'أيقونة شريط القوائم';

  @override
  String get settingsHubMenuBarSubtitle =>
      'يعرض عدد غير المقروء في شريط القوائم';

  @override
  String get settingsHubCallStats => 'إظهار إحصاءات المكالمة';

  @override
  String get settingsHubCallStatsSubtitle =>
      'الدقة ومعدل البت وزمن الاستجابة أثناء المكالمات';

  @override
  String get settingsHubTheme => 'السمة';

  @override
  String get settingsHubAppIcon => 'أيقونة التطبيق';

  @override
  String get settingsHubGlass => 'الزجاج';

  @override
  String get settingsHubNavigation => 'التنقل';

  @override
  String get settingsHubMotion => 'الحركة';

  @override
  String get settingsHubChatList => 'قائمة الدردشات';

  @override
  String get settingsHubChatStyle => 'نمط الدردشة';

  @override
  String get settingsHubBubbleStyle => 'نمط الفقاعات';

  @override
  String get settingsHubSpeakerColors => 'ألوان المتحدثين';

  @override
  String get settingsHubReplyStyle => 'نمط الرد';

  @override
  String get settingsHubPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get settingsHubTerms => 'شروط الخدمة';

  @override
  String get settingsHubLicence => 'الترخيص';

  @override
  String get settingsHubServer => 'الخادم';

  @override
  String get settingsHubLayoutRows => 'صفوف';

  @override
  String get settingsHubLayoutCards => 'بطاقات';

  @override
  String get settingsHubLayoutGrid => 'شبكة';

  @override
  String get settingsHubNavTabBar => 'شريط علامات التبويب';

  @override
  String settingsHubThemeAuto(String name) {
    return 'تلقائي · $name';
  }

  @override
  String get chatListPageRowsSub => 'وجه واسم وآخر رسالة، كما في الرسائل.';

  @override
  String get chatListPageCardsSub =>
      'كل غرفة في بطاقتها الخاصة، وكل التفاصيل مكتوبة.';

  @override
  String get chatListPageGridSub => 'عمودان من المربعات. غرف أكثر بنظرة واحدة.';

  @override
  String get chatListPageLayoutHeader => 'التخطيط';

  @override
  String get chatListPageFiltersHeader => 'عوامل التصفية';

  @override
  String get chatListPageChips => 'شرائح';

  @override
  String get chatListPageChipsSub =>
      'صف من عوامل التصفية، على بعد نقرة دائمًا.';

  @override
  String get chatListPageButton => 'زر';

  @override
  String get chatListPageButtonSub => 'زر واحد يفتح عوامل التصفية عند الطلب.';

  @override
  String get chatStylePageFooter => 'كيف يُرسم رأس المحادثة وحقل الرسالة.';

  @override
  String get chatStyleClassicSub => 'رأس مصمت وحقل رسالة مسطح.';

  @override
  String get chatStyleCompactSub => 'عناصر تحكم ضبابية تطفو فوق المحادثة.';

  @override
  String get bubbleTailedSub =>
      'ذيل على آخر رسالة في كل سلسلة، كما في الرسائل.';

  @override
  String get bubbleSoftSub => 'بلا ذيل. تتماسك السلسلة بزواياها.';

  @override
  String get bubblePillSub => 'كبسولات مستديرة بالكامل لكل رسالة.';

  @override
  String get bubbleSlabSub => 'أكتاف مربعة: حادة ومقصودة.';

  @override
  String get replyStylePageFooter => 'كيف يُظهر الرد الرسالة التي يجيب عنها.';

  @override
  String get replyClassicSub => 'اقتباس ملوّن فوق الرسالة، بأسلوب واتساب.';

  @override
  String get replyPhantomSub => 'طيف من الأصل يطفو فوقها ويتصل بمنحنى.';

  @override
  String get replyStickySub => 'بطاقة صغيرة مائلة مثبتة في الزاوية.';

  @override
  String get replyComicSub => 'فقاعة صغيرة بذيل على طريقة القصص المصورة.';

  @override
  String get motionMatchDevice => 'مطابقة الجهاز';

  @override
  String get motionMatchDeviceCalmSub => 'جهازك يطلب تقليل الحركة الآن.';

  @override
  String get motionMatchDeviceFullSub => 'جهازك يسمح بالرسوم المتحركة الآن.';

  @override
  String get motionFullSub => 'كل ارتداد وانسياب ولمسة.';

  @override
  String get motionCalmSub => 'تثبت الزخارف. كل شيء آخر يعمل كما هو.';

  @override
  String get navigationPageFooter =>
      'كيف تتنقل بين الدردشات والموجز والاستكشاف والإعدادات.';

  @override
  String get navTabBarSub => 'ظاهر دائمًا، نقرة واحدة إلى أي مكان.';

  @override
  String get navOrbSub => 'اضغط واسحب من الزاوية. إيماءة تعتاد عليها.';

  @override
  String get languageSystemLabel => 'لغة الجهاز';

  @override
  String get languagePageFooter =>
      'القوائم ورسائل التطبيق. تبقى الدردشات باللغة التي يكتب بها الناس.';

  @override
  String get speakerPageFooter => 'اعرف من يتحدث بنظرة في الدردشات الجماعية.';

  @override
  String get speakerOffSub => 'الجميع يكتب بالحبر نفسه.';

  @override
  String get speakerNamesSub => 'لكل شخص لون على اسمه ووجهه.';

  @override
  String get speakerBubblesSub => 'ينتقل لونهم إلى رسائلهم أيضًا.';

  @override
  String get themePageAutoFooter =>
      'تُستخدم السمات الفاتحة في الوضع الفاتح والداكنة في الوضع الداكن.';

  @override
  String get themePageLightMode => 'الوضع الفاتح';

  @override
  String get themePageDarkMode => 'الوضع الداكن';

  @override
  String get themePageEssentials => 'الأساسيات';

  @override
  String get themePageEssentialsFooter => 'هادئة وأصيلة، بخمسة ألوان.';

  @override
  String get themePageCharacters => 'شخصيات';

  @override
  String get themePageCharactersFooter =>
      'التخطيط نفسه بشخصية خاصة. المس مطولًا أي سمة لمعاينتها.';

  @override
  String get themePageLightBadge => 'فاتح';

  @override
  String get themePageDarkBadge => 'داكن';

  @override
  String get themePageInUse => 'قيد الاستخدام';

  @override
  String get themePageUseLight => 'استخدامها في الوضع الفاتح';

  @override
  String get themePageUseDark => 'استخدامها في الوضع الداكن';

  @override
  String themePageUse(String name) {
    return 'استخدام $name';
  }

  @override
  String get acctActionPending => 'قيد الانتظار';

  @override
  String get chatSwipePin => 'تثبيت';

  @override
  String get chatSwipeUnpin => 'إلغاء التثبيت';

  @override
  String get chatSwipeMute => 'كتم';

  @override
  String get chatSwipeUnmute => 'إلغاء الكتم';

  @override
  String get chatSwipeArchive => 'أرشفة';

  @override
  String get appearanceMatchDeviceSubtitle =>
      'فاتح نهارًا وداكن ليلًا، مع هاتفك';

  @override
  String get appearanceOneThemeSubtitle => 'المظهر نفسه طوال اليوم';

  @override
  String get riName => 'الاسم';

  @override
  String get riDescription => 'الوصف';

  @override
  String get riVisibility => 'من يمكنه العثور عليها';

  @override
  String get riPublic => 'عامة';

  @override
  String get riPublicSub => 'يمكن لأي شخص العثور عليها في الاستكشاف';

  @override
  String get riPrivate => 'خاصة';

  @override
  String get riPrivateSub => 'يمكن فقط لمن تدعوهم الانضمام';

  @override
  String get riMessageLife => 'تختفي الرسائل بعد';

  @override
  String get riPassword => 'كلمة المرور';

  @override
  String get riRemovePassword => 'إزالة كلمة المرور';

  @override
  String get riSetPassword => 'تعيين كلمة المرور';

  @override
  String get riSharedContent => 'المحتوى المشترك';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عضو',
      many: '$count عضوًا',
      few: '$count أعضاء',
      two: 'عضوان',
      one: 'عضو واحد',
      zero: 'لا أعضاء',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مدعو',
      many: '$count مدعوًا',
      few: '$count مدعوين',
      two: 'مدعوان',
      one: 'مدعو واحد',
      zero: 'لا مدعوين',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => 'سحب';

  @override
  String get riNotifications => 'الإشعارات';

  @override
  String get riTranslation => 'الترجمة';

  @override
  String get riNameColours => 'ألوان الأسماء';

  @override
  String get riYouSuggested => 'اقتراحاتك';

  @override
  String get riTakeBack => 'تراجع';

  @override
  String get riLeaveRoom => 'مغادرة الغرفة';

  @override
  String get riLeaving => 'جارٍ المغادرة…';

  @override
  String get riDeleteRoom => 'حذف الغرفة';

  @override
  String get riDeleting => 'جارٍ الحذف…';

  @override
  String get riEndConversation => 'إنهاء المحادثة';

  @override
  String get riEnding => 'جارٍ الإنهاء…';

  @override
  String get riActionCall => 'اتصال';

  @override
  String get riActionVideo => 'فيديو';

  @override
  String get riActionMute => 'كتم';

  @override
  String get riActionUnmute => 'إلغاء الكتم';

  @override
  String get riActionMedia => 'الوسائط';

  @override
  String get riActionAdd => 'إضافة';

  @override
  String get roomHeaderStatusTyping => 'يكتب…';

  @override
  String get glassScreenLead => 'مقدار ما يظهر مما خلف الزجاج.';

  @override
  String get transcriptDayToday => 'اليوم';

  @override
  String get acctRowDevices => 'الأجهزة';

  @override
  String get acctThisDevice => 'هذا الجهاز';

  @override
  String get acctRemove => 'إزالة';

  @override
  String get acctRemoveDeviceTitle => 'إزالة هذا الجهاز؟';

  @override
  String get acctRemoveAllTitle => 'إزالة كل الأجهزة الأخرى؟';

  @override
  String get acctRemoveAll => 'إزالة الكل';

  @override
  String get acctActiveNow => 'نشط الآن';

  @override
  String get acctLoading => 'جارٍ التحميل…';

  @override
  String get acctDevicesLoadFailed => 'تعذر تحميل أجهزتك.';

  @override
  String get acctNoNotifications => 'الإشعارات لا تصل إلى هذا الجهاز';

  @override
  String get acctBlockedEmpty => 'لم تحظر أي شخص.';

  @override
  String get acctUnblock => 'إلغاء الحظر';

  @override
  String get pvSubtitle => 'تحكّم فيما يراه الآخرون وكيف يمكنهم الوصول إليك.';

  @override
  String get pvSectionProfile => 'الملف الشخصي';

  @override
  String get pvSectionMessages => 'الرسائل';

  @override
  String get pvSectionPeople => 'الأشخاص';

  @override
  String get pvSectionFeed => 'الموجز';

  @override
  String get pvAvatar => 'صورة الملف الشخصي';

  @override
  String get pvAvatarDesc => 'من يمكنه رؤية صورتك';

  @override
  String get pvOnline => 'حالة الاتصال';

  @override
  String get pvOnlineDesc => 'هل تظهر نشطًا الآن';

  @override
  String get pvLastSeen => 'آخر ظهور';

  @override
  String get pvLastSeenDesc => 'متى كنت متواجدًا آخر مرة';

  @override
  String get pvSendReceipts => 'إرسال إشعارات القراءة';

  @override
  String get pvSendReceiptsDesc => 'السماح للآخرين برؤية أنك قرأت رسائلهم';

  @override
  String get pvShowReceipts => 'إظهار إشعارات القراءة';

  @override
  String get pvShowReceiptsDesc => 'معرفة من قرأ رسائلك';

  @override
  String get pvShowReceiptsHint => 'يُحتسب فقط من يرسلون إشعارات القراءة.';

  @override
  String get pvFriendRequests => 'طلبات الصداقة';

  @override
  String get pvFriendRequestsDesc => 'من يمكنه إرسال طلبات صداقة إليك';

  @override
  String get pvSupervisedTitle => 'يضبط هذه الإعدادات الكبار المسؤولون عنك';

  @override
  String get pvEveryone => 'الجميع';

  @override
  String get pvFriends => 'الأصدقاء';

  @override
  String get pvNobody => 'لا أحد';

  @override
  String get pvOn => 'تشغيل';

  @override
  String get pvOff => 'إيقاف';

  @override
  String get pvAnyone => 'أي شخص';

  @override
  String get pvHighlights => 'أبرز لحظاتي';

  @override
  String get pvHighlightsDesc =>
      'هل تظهر صورك ومقاطعك في لوحات أصدقائك لهذا اليوم';

  @override
  String get pvPuzzle => 'نتيجتي في اللغز';

  @override
  String get pvPuzzleDesc => 'هل يرى أصدقاؤك أداءك في لغز اليوم';

  @override
  String get pvPast => 'ماضيّ';

  @override
  String get pvPastDesc =>
      'يُشارك اليوم دائمًا مع الأصدقاء، وهذا يفتح كل ما قبله';

  @override
  String get pvPoints => 'نقاطي';

  @override
  String get pvPointsDesc => 'هل تظهر النقاط التي تسجلها في لوحات أصدقائك';

  @override
  String get roomColorsPageTitle => 'من هو من';

  @override
  String get roomColorsPageHeader => 'اللون الذي يتحدث به كل شخص';

  @override
  String get roomColorsAuto => 'تلقائي';

  @override
  String get roomColorsReset => 'العودة إلى التلقائي';

  @override
  String get roomColorsOffFooter =>
      'ألوان المتحدثين متوقفة. تشغيلها هنا يشغّلها في كل الغرف.';

  @override
  String roomColorsSharedWith(String name) {
    return 'مشترك مع $name';
  }

  @override
  String get settingsScreenValueReplyQuote => 'اقتباس';

  @override
  String get replyQuoteSub => 'تظهر الرسالة الأصلية في أعلى الرد، داخل فقاعته.';

  @override
  String get riTabMedia => 'الصور ومقاطع الفيديو';

  @override
  String get riTabFiles => 'الملفات';

  @override
  String get riTabVoice => 'الرسائل الصوتية';

  @override
  String get riTabLinks => 'الروابط';

  @override
  String get riTabSaved => 'المحفوظة';

  @override
  String get riNone => 'لا شيء';

  @override
  String get riSavedNote =>
      'أنت فقط ترى ما تحفظه. الرسالة المثبّتة عكس ذلك: تراها الغرفة كلها.';

  @override
  String get riOwnerNote => 'الوسام يميّز منشئ هذه الغرفة.';

  @override
  String get famPair => 'إقران';

  @override
  String get famRelease => 'تحرير';

  @override
  String get famSettings => 'الإعدادات';

  @override
  String get famAddChild => 'إضافة طفل';

  @override
  String get famEmptyTitle => 'لا يوجد أطفال بعد';

  @override
  String get famOnlineNow => 'متصل الآن';

  @override
  String get famNotPaired => 'لم يُقرن بعد';

  @override
  String get famJustNow => 'الآن';

  @override
  String get apprEmptyTitle => 'لا شيء بانتظارك';

  @override
  String get apprEmptySub => 'أنت مطّلع على كل شيء.';

  @override
  String get apprNotYet => 'ليس بعد';

  @override
  String get apprAllow => 'السماح';

  @override
  String get compGeneral => 'عام';

  @override
  String get compStorage => 'التخزين';

  @override
  String get compTranslateInto => 'الترجمة إلى';

  @override
  String get compBrain => 'العقل';

  @override
  String laUnlinkProvider(String provider) {
    return 'إلغاء ربط $provider';
  }

  @override
  String laLinkProvider(String provider) {
    return 'ربط $provider';
  }

  @override
  String get laUnlink => 'إلغاء الربط';

  @override
  String get laLink => 'ربط';

  @override
  String get laLinked => 'مرتبط';

  @override
  String get laNotLinked => 'غير مرتبط';

  @override
  String rdSignOut(String name) {
    return 'تسجيل خروج $name';
  }

  @override
  String get rpContinue => 'متابعة';

  @override
  String get rpCopy => 'نسخ';

  @override
  String get rpSaved => 'حفظتها';

  @override
  String get rpBack => 'رجوع';

  @override
  String get rpKeep => 'ليس الآن، احتفظ بعبارتي الحالية';

  @override
  String get childSetupHeadingIos => 'من هو الطفل؟';

  @override
  String get childPairTitleIos => 'مرحبًا!';

  @override
  String get childPairBackIos => 'العودة إلى تسجيل الدخول';

  @override
  String get gamesHubTitle => 'لوحة الصدارة';

  @override
  String get gamesHubSubtitle => 'فائزو اليوم. ألغاز جديدة كل يوم.';

  @override
  String get gameTellFriendsMessage =>
      'سيصلهم إشعار بهذه النتيجة. يمكن إرساله مرة واحدة فقط.';

  @override
  String get deviceLoginScanTitleIos => 'امسح لتسجيل الدخول';

  @override
  String get deviceLoginConfirmTitleIos => 'تسجيل الدخول على هذا الجهاز؟';

  @override
  String get socialHeroCreateIos => 'اقتربت';

  @override
  String get socialHeroLinkIos => 'مرحبًا بعودتك';

  @override
  String socialSignInLinkIos(String provider) {
    return 'تسجيل الدخول وربط $provider';
  }

  @override
  String get serverTitleIos => 'الخادم';

  @override
  String get serverOnboardingTitleIos => 'اختر خادمًا';

  @override
  String get approvalGateAskIos => 'اطلب';

  @override
  String get friendRequestDraftIntroOutgoingSentence =>
      'أرسل بضعة أسطر. يمكنهم القبول أو الرفض.';

  @override
  String get requestDeclineIos => 'رفض';

  @override
  String get joinRequestAllowIos => 'سماح';

  @override
  String get changeRequestUseIos => 'استخدمه';

  @override
  String get settingsSearchHint => 'ابحث في الإعدادات';

  @override
  String settingsSearchNoResults(String query) {
    return 'لا نتائج لـ “$query”';
  }

  @override
  String get settingsSearchAccount => 'الحساب';

  @override
  String get settingsHubDiagnostics => 'التشخيص';

  @override
  String get settingsHubDiagnosticsSubtitle =>
      'سجلات لاستكشاف الأخطاء والإبلاغ عنها';

  @override
  String get settingsHubAdvancedFooter =>
      'لاستكشاف الأخطاء والاستضافة الذاتية. لا شيء هنا ضروري يوميًا.';

  @override
  String get settingsSearchKwLanguage => 'لغة، ترجمة، منطقة';

  @override
  String get settingsSearchKwUpdates => 'تحديث، إصدار، جديد';

  @override
  String get settingsSearchKwLinks => 'روابط، عنوان، معاينة';

  @override
  String get settingsSearchKwPresence => 'متصل، حالة، نقطة، نشط، أخضر';

  @override
  String get settingsSearchKwAutoplay => 'صور متحركة، تشغيل تلقائي';

  @override
  String get settingsSearchKwStickers => 'ملصقات، إيموجي، اقتراحات';

  @override
  String get settingsSearchKwPush => 'إشعارات، تنبيهات، صوت';

  @override
  String get settingsSearchKwGames => 'ألعاب، تذكير، يومي';

  @override
  String get settingsSearchKwFriends => 'أصدقاء، نشاط، نقاط';

  @override
  String get settingsSearchKwVideo => 'فيديو، مكالمة، جودة، كاميرا';

  @override
  String get settingsSearchKwStats => 'إحصاءات، شبكة، اتصال، تصحيح';

  @override
  String get settingsSearchKwTheme => 'سمة، داكن، فاتح، ألوان، ليلي';

  @override
  String get settingsSearchKwIcon => 'أيقونة التطبيق، شعار، الشاشة الرئيسية';

  @override
  String get settingsSearchKwGlass => 'زجاج، تمويه، شفافية';

  @override
  String get settingsSearchKwNavigation => 'شريط التبويب، تنقل، قائمة';

  @override
  String get settingsSearchKwMotion => 'حركة، رسوم متحركة، تقليل الحركة';

  @override
  String get settingsSearchKwCompanions => 'ذكاء اصطناعي، مساعد، ترجمة';

  @override
  String get settingsSearchKwChatList => 'قائمة الدردشات، صفوف، بطاقات، شبكة';

  @override
  String get settingsSearchKwChatStyle => 'نمط الدردشة، مضغوط، كلاسيكي';

  @override
  String get settingsSearchKwBubbles => 'فقاعات، رسائل، شكل';

  @override
  String get settingsSearchKwSpeakers => 'أسماء، ألوان، مجموعات';

  @override
  String get settingsSearchKwReply => 'رد، اقتباس';

  @override
  String get settingsSearchKwReport => 'خطأ، مشكلة، ملاحظات، دعم';

  @override
  String get settingsSearchKwLegal => 'خصوصية، شروط، قانوني، ترخيص';

  @override
  String get settingsSearchKwServer => 'خادم، استضافة ذاتية، مطور';

  @override
  String get settingsSearchKwDiagnostics => 'تشخيص، سجلات، تصحيح، مطور';

  @override
  String get settingsSearchKwPrivacy =>
      'خصوصية، ظهور، آخر ظهور، إيصالات القراءة';

  @override
  String get settingsSearchKwBlocked => 'محظور، حظر';

  @override
  String get settingsSearchKwDevices => 'أجهزة، جلسات، تسجيل الخروج';

  @override
  String get settingsSearchKwLinked => 'apple، google، تسجيل الدخول';

  @override
  String get settingsSearchKwRecovery =>
      'عبارة الاسترداد، كلمة المرور، نسخ احتياطي';

  @override
  String get settingsSearchKwFamily => 'عائلة، طفل، والد، موافقات';

  @override
  String get settingsSearchKwAccount => 'حساب، تسجيل الخروج، حذف، بريد';

  @override
  String get childPolicyScreenContactStateAllowedTalking => 'يتحدثان';

  @override
  String get childPolicyScreenContactStateTalking => 'تمت الموافقة';

  @override
  String get childPolicyScreenContactStateAllowedNotAdded =>
      'لم تتم الإضافة بعد';

  @override
  String get profileScreenSignOutConfirmTitle =>
      'هل تريد تسجيل الخروج على هذا الجهاز؟';

  @override
  String get profileScreenDeleteAccountConfirmTitle => 'هل تريد حذف حسابك؟';

  @override
  String get profileScreenDeleteAccountConfirmBody =>
      'تُحذف رسائلك وصورك وغرفك وأصدقاؤك، ويصبح اسم المستخدم متاحًا لأي شخص آخر.';

  @override
  String get glassPresetNameFrosted => 'مُصنفَر';

  @override
  String get glassPresetNameClear => 'شفاف';

  @override
  String settingsScreenDiagnosticsCountdown(int count) {
    return 'التشخيص بعد $count…';
  }

  @override
  String pairingCodeTitlePair(String name) {
    return 'إقران $name';
  }

  @override
  String pairingCodeTitleRelease(String name) {
    return 'تحرير $name';
  }

  @override
  String archivedChatsSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count محادثة',
      many: '$count محادثة',
      few: '$count محادثات',
      two: 'محادثتان',
      one: 'محادثة واحدة',
      zero: 'لا محادثات',
    );
    return '$_temp0';
  }

  @override
  String pinnedListSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count رسالة',
      many: '$count رسالة',
      few: '$count رسائل',
      two: 'رسالتان',
      one: 'رسالة واحدة',
      zero: '$count رسالة',
    );
    return '$_temp0';
  }

  @override
  String get voiceRecorderScreenTitle => 'رسالة صوتية';

  @override
  String get chatTargetSearchHint => 'بحث';

  @override
  String get marloweBrainTierSwiftDetail => 'إجابات سريعة، وأخف تنزيل';

  @override
  String get marloweBrainTierBalancedDetail => 'توازن جيد بين السرعة والعمق';

  @override
  String get marloweBrainTierDeepDetail =>
      'الأعمق تفكيرًا، ويحتاج إلى أكبر مساحة';

  @override
  String get reportFactDeviceId => 'معرّف الجهاز';

  @override
  String get reportFactUserId => 'معرّف المستخدم';

  @override
  String get reportFactUsername => 'اسم المستخدم';

  @override
  String get reportFactApp => 'التطبيق';

  @override
  String get reportFactDevice => 'الجهاز';

  @override
  String get reportFactSystem => 'النظام';

  @override
  String get reportFactDisplay => 'الشاشة';

  @override
  String get reportFactAppLanguage => 'لغة التطبيق';

  @override
  String get reportFactSystemLocale => 'لغة النظام';

  @override
  String get reportFactLog => 'السجل';

  @override
  String reportFactLogValue(int count) {
    return '$count حدثًا مرفقًا';
  }

  @override
  String reportProblemScreenshotN(int n) {
    return 'لقطة الشاشة $n';
  }

  @override
  String reportProblemRemoveScreenshot(int n) {
    return 'إزالة لقطة الشاشة $n';
  }

  @override
  String get reportFactLanguageFromSystem => 'من النظام';

  @override
  String get reportFactLanguageChosen => 'مختارة';

  @override
  String get pageSectionSeeAll => 'عرض الكل';

  @override
  String get discoverScreenSeeAllFriendsSemanticLabel => 'عرض كل الأصدقاء';

  @override
  String get discoverScreenSeeAllRoomsSemanticLabel => 'عرض كل غرفك';

  @override
  String groupCallScreenRingingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'يرنّ $count',
    );
    return '$_temp0';
  }

  @override
  String photoChromeWhenToday(String time) {
    return 'اليوم الساعة $time';
  }

  @override
  String photoChromeWhenYesterday(String time) {
    return 'أمس الساعة $time';
  }

  @override
  String photoChromeWhenDate(String date, String time) {
    return '$date الساعة $time';
  }

  @override
  String get photoChromeSaved => 'تم الحفظ';

  @override
  String get photoChromeSaveFailed => 'تعذّر الحفظ';

  @override
  String get photoChromeShareFailed => 'تعذّرت المشاركة';

  @override
  String photoChromeForwarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إعادة التوجيه إلى $count محادثات',
      one: 'تمت إعادة التوجيه',
    );
    return '$_temp0';
  }

  @override
  String get photoChromeForwardFailed => 'تعذّرت إعادة التوجيه';

  @override
  String get photoChromeDeleteFailed => 'تعذّر الحذف';

  @override
  String get photoChromeDeleteBody =>
      'سيؤدي هذا إلى إزالته لدى الجميع في هذه المحادثة. لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get roomContentMonthThis => 'هذا الشهر';

  @override
  String get roomContentMonthLast => 'الشهر الماضي';

  @override
  String get leaderboardOverall => 'اليوم';

  @override
  String get leaderboardFooter =>
      '1 نقطة لكل لغز تحلّه اليوم. عند التعادل، يتقدم من جاء أولًا مرات أكثر. ما زال التعادل قائمًا؟ تتشاركون المركز، بالترتيب الأبجدي.';

  @override
  String get leaderboardNotPlayed => 'لم تلعب بعد';

  @override
  String get leaderboardPlay => 'العب';

  @override
  String get leaderboardEmptyTitle => 'لا نتائج بعد اليوم';

  @override
  String get leaderboardEmptyBody => 'حلّ لغزًا وستكون الأول في القائمة.';

  @override
  String get pointComposerPickFirst => 'اختر واحدًا في الأعلى أولًا';

  @override
  String get momentStoryNext => 'التالي';

  @override
  String get momentStoryPrevious => 'السابق';

  @override
  String leaderboardSolved(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      solved,
      locale: localeName,
      other: '$solved من $total محلولة',
      zero: 'لم يُحلّ شيء بعد',
    );
    return '$_temp0';
  }

  @override
  String leaderboardWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count انتصارات',
      one: 'فوز واحد',
    );
    return '$_temp0';
  }

  @override
  String leaderboardEmptyAction(String game) {
    return 'العب $game';
  }

  @override
  String get diagCatApi => 'استدعاءات الخادم';

  @override
  String get diagCatConnection => 'الاتصال';

  @override
  String get diagCatDevice => 'الجهاز';

  @override
  String get diagCatError => 'الأخطاء';

  @override
  String get diagCatFrame => 'إطارات بطيئة';

  @override
  String get diagCatLayout => 'التخطيط';

  @override
  String get diagCatLifecycle => 'حالة التطبيق';

  @override
  String get diagCatLog => 'السجل';

  @override
  String get diagCatNav => 'التنقل';

  @override
  String get diagCatNetwork => 'الشبكة';

  @override
  String get diagCatSubscription => 'تحديثات مباشرة';

  @override
  String get diagSevTrace => 'تتبّع';

  @override
  String get diagSevDebug => 'تصحيح';

  @override
  String get diagSevInfo => 'معلومات';

  @override
  String get diagSevWarning => 'تحذير';

  @override
  String get diagSevError => 'خطأ';

  @override
  String get diagAll => 'الكل';

  @override
  String get diagSearchHint => 'ابحث في الاسم والتفاصيل والمحتوى';

  @override
  String get diagSummaryCopied => 'تم نسخ الملخص';

  @override
  String get diagShareLog => 'مشاركة السجل';

  @override
  String get diagCopySummary => 'نسخ الملخص';

  @override
  String get diagDeleteAll => 'حذف الكل';

  @override
  String get diagUndo => 'تراجع';

  @override
  String get diagDeleteLogTitle => 'حذف السجل بالكامل؟';

  @override
  String get diagDeleteLogBody =>
      'سيُحذف كل حدث سُجِّل حتى الآن مع سجل التشغيل السابق. وكل ما يحدث من الآن يُسجَّل كالمعتاد.';

  @override
  String get diagDelete => 'حذف';

  @override
  String get diagLogDeleted => 'تم حذف السجل';

  @override
  String get diagFilter => 'تصفية';

  @override
  String get diagMore => 'المزيد';

  @override
  String get diagLatest => 'الأحدث';

  @override
  String get diagJumpToLatest => 'الانتقال إلى الأحدث';

  @override
  String get diagPaused => 'متوقف مؤقتًا';

  @override
  String get diagPreparingLog => 'جارٍ تجهيز السجل…';

  @override
  String get diagEmptyNothingTitle => 'لم يُسجَّل شيء بعد';

  @override
  String get diagEmptyNothingHint =>
      'استخدم التطبيق قليلًا وستظهر الأحداث هنا.';

  @override
  String get diagEmptyHiddenTitle => 'لا توجد سوى أحداث مخفية حتى الآن';

  @override
  String get diagEmptyHiddenHint =>
      'اضغط على شارة باهتة في الأعلى لرؤيتها، أو اضغط عليها مطولًا لإعادتها إلى الكل.';

  @override
  String get diagEmptyNoMatchTitle => 'لا توجد أحداث مطابقة';

  @override
  String get diagEmptyNoMatchHint => 'اضغط على الكل في الأعلى لمسح التصفية.';

  @override
  String get diagApply => 'تطبيق';

  @override
  String get diagMinSeverity => 'الحد الأدنى للخطورة';

  @override
  String get diagEverything => 'كل شيء';

  @override
  String get diagHiddenFromAllHeader => 'مخفية من الكل';

  @override
  String get diagHiddenFromAllFooter =>
      'تُستبعد من الكل حتى تختارها في صف الشارات. اضغط مطولًا على شارة هناك للإعداد نفسه.';

  @override
  String get diagCollapseRepeats => 'دمج التكرارات';

  @override
  String get diagCollapseRepeatsSubtitle => 'اجمع تكرار الحدث نفسه في صف واحد';

  @override
  String get diagResetFilter => 'إعادة ضبط التصفية';

  @override
  String get diagBodyTruncated => 'اقتُطع المحتوى عند التسجيل';

  @override
  String get diagCopyEvent => 'نسخ الحدث';

  @override
  String get diagEventCopied => 'تم نسخ الحدث';

  @override
  String diagHiddenFromAll(String category) {
    return '$category مخفية من الكل';
  }

  @override
  String diagBackInAll(String category) {
    return '$category عادت إلى الكل';
  }

  @override
  String diagChipSemanticLabel(String category, int count) {
    return '$category، $count';
  }

  @override
  String diagChipHiddenSemanticLabel(String category, int count) {
    return '$category، $count، مخفية من الكل';
  }

  @override
  String diagEventCount(int shown, int total) {
    return '$shown من $total حدث';
  }

  @override
  String diagDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم إسقاط $count من الأحداث السابقة، ويبدأ السجل من منتصف القصة',
    );
    return '$_temp0';
  }

  @override
  String diagRepeatSpan(int count, String seconds) {
    return '×$count خلال $seconds ث';
  }

  @override
  String roomContentTabSemantic(String count, String label) {
    return '$label، $count عنصر';
  }

  @override
  String get mapAppsTitle => 'الخرائط';

  @override
  String get mapAppsChoose => 'فتح الموقع في';

  @override
  String get mapAppsRemember => 'استخدام كافتراضي';

  @override
  String get mapAppsAskEveryTime => 'السؤال في كل مرة';

  @override
  String get mapAppsBrowser => 'المتصفح';

  @override
  String get mapAppsSubtitle => 'اختر أين تُفتح المواقع المشتركة.';

  @override
  String get mapAppsUnavailable =>
      'تطبيق الخرائط الافتراضي غير متاح. اختر تطبيقًا آخر.';

  @override
  String get mapAppsNoInstalled =>
      'لم يتم العثور على تطبيق خرائط مدعوم. يمكنك استخدام المتصفح.';

  @override
  String get interactionAnswersSearch => 'البحث عن أشخاص أو إجابات';

  @override
  String get interactionFilterEmpty => 'لا توجد إجابات تطابق هذا الفلتر.';

  @override
  String get interactionRetry => 'المحاولة مجددًا';

  @override
  String get cameraEditorScreenCaptionHint => 'أضف تعليقًا…';

  @override
  String get cameraEditorScreenCaptionViewOnceHint =>
      'لا تعليقات على صور العرض لمرة واحدة';

  @override
  String get cameraEditorScreenAddFromCameraSemanticLabel => 'التقط صورة أخرى';

  @override
  String cameraEditorScreenDiscardAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'هل تريد تجاهل $count صور؟',
      one: 'هل تريد تجاهل هذه الصورة؟',
    );
    return '$_temp0';
  }

  @override
  String get cameraEditorScreenDiscardAllBody => 'ستفقد تعديلاتك وتعليقاتك.';

  @override
  String get cameraEditorScreenDiscardAllConfirm => 'تجاهل';

  @override
  String get galleryTrayRecentsTitle => 'الأحدث';

  @override
  String get galleryTrayBackToCameraLabel => 'العودة إلى الكاميرا';

  @override
  String get galleryTrayAllPhotosLabel => 'كل الصور';

  @override
  String get galleryTrayHandleLabel => 'الصور الأخيرة';

  @override
  String get galleryTrayAllowPrompt => 'شاهد صورك الأخيرة هنا';

  @override
  String get galleryTrayAllowButton => 'سماح';

  @override
  String get galleryTrayDeniedPrompt => 'الوصول إلى الصور متوقف';

  @override
  String get galleryTraySettingsButton => 'الإعدادات';

  @override
  String get galleryTrayLimitedNote => 'تُعرض فقط الصور التي سمحت بها';

  @override
  String get galleryTrayManageButton => 'إدارة';

  @override
  String get galleryTrayEmpty => 'لا توجد صور بعد';

  @override
  String galleryTrayAddSelectedButton(int count) {
    return 'إضافة ($count)';
  }

  @override
  String get galleryTrayCancelSelectionLabel => 'إلغاء التحديد';

  @override
  String galleryTraySelectedTitle(int count) {
    return 'تم تحديد $count';
  }

  @override
  String galleryTrayPhotoLabel(int index) {
    return 'صورة $index';
  }

  @override
  String get reactionLimitTitle => 'لقد بلغت الحد الأقصى للتفاعلات';

  @override
  String reactionLimitMessageBody(int limit) {
    return 'من أجل السرعة وراحة البال وليتألق كل رمز تعبيري، يمكنك إضافة ما يصل إلى $limit تفاعلات على الرسالة الواحدة، ولا أكثر. احذف تفاعلًا لتفسح المجال لآخر.';
  }

  @override
  String reactionLimitHighlightBody(int limit) {
    return 'في اللقطات المميزة، لكل شخص $limit تفاعلات فقط، ليبقى لكل تفاعل معنى. احذف تفاعلًا لتفسح المجال لمفضّل جديد.';
  }

  @override
  String get reactionLimitDismiss => 'حسنًا';

  @override
  String get reactionPickerYoursLabel => 'تفاعلاتك';

  @override
  String reactionPickerTakeBackSemantic(String emoji) {
    return 'إزالة تفاعلك $emoji';
  }

  @override
  String get momentCommentsTitle => 'التعليقات';

  @override
  String momentCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تعليق',
      many: '$count تعليقًا',
      few: '$count تعليقات',
      two: 'تعليقان',
      one: 'تعليق واحد',
      zero: 'تعليق',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentsEmptyTitle => 'لا توجد تعليقات بعد';

  @override
  String get momentCommentsEmptyBody =>
      'ابدأ المحادثة بكلمات أو ملصق أو صورة GIF.';

  @override
  String get momentCommentHint => 'أضف تعليقًا…';

  @override
  String momentCommentReplyHint(String name) {
    return 'الرد على $name…';
  }

  @override
  String momentCommentReplyingTo(String name) {
    return 'جارٍ الرد على $name';
  }

  @override
  String get momentCommentCancelReply => 'إلغاء الرد';

  @override
  String get momentCommentReply => 'رد';

  @override
  String momentCommentViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عرض $count رد',
      many: 'عرض $count ردًا',
      few: 'عرض $count ردود',
      two: 'عرض ردين',
      one: 'عرض رد واحد',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentHideReplies => 'إخفاء الردود';

  @override
  String get momentCommentDelete => 'حذف التعليق';

  @override
  String get momentCommentDeleteConfirm =>
      'هل تريد حذف هذا التعليق؟ ستُحذف ردوده أيضًا.';

  @override
  String get momentCommentDeleteConfirmButton => 'حذف';

  @override
  String get momentCommentSend => 'إرسال';

  @override
  String get momentCommentExpressions => 'الملصقات وصور GIF';

  @override
  String get momentCommentFailed => 'تعذّر نشر تعليقك. حاول مرة أخرى.';

  @override
  String get momentCommentAuthorBadge => 'الناشر';

  @override
  String get momentCommentLike => 'إعجاب';

  @override
  String get momentCommentStickerAlt => 'ملصق';

  @override
  String get momentCommentGifAlt => 'GIF';

  @override
  String get momentCommentPosted => 'تم نشر التعليق';

  @override
  String momentCommentsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'عرض كل التعليقات ($count)',
      many: 'عرض $count تعليقًا',
      few: 'عرض $count تعليقات',
      two: 'عرض التعليقين',
      one: 'عرض تعليق واحد',
    );
    return '$_temp0';
  }

  @override
  String momentReactorsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count آخرين',
      many: '$count شخصًا آخر',
      few: '$count أشخاص آخرين',
      two: 'شخصان آخران',
      one: 'شخص آخر',
    );
    return '$name و$_temp0';
  }

  @override
  String get storageKindPhotos => 'الصور';

  @override
  String get storageKindVideos => 'الفيديوهات';

  @override
  String get storageKindVideoMessages => 'ملاحظات الفيديو';

  @override
  String get storageKindVoice => 'الرسائل الصوتية';

  @override
  String get storageKindFiles => 'الملفات';

  @override
  String get storageKindStickers => 'الملصقات وصور GIF';

  @override
  String get storageKindChatHistory => 'سجل الدردشات';

  @override
  String get storageKindOther => 'أخرى';

  @override
  String get dataUsageKindCalls => 'المكالمات';

  @override
  String get dataStorageTitle => 'البيانات والتخزين';

  @override
  String get settingsSearchKwDataStorage =>
      'تخزين ذاكرة مؤقتة كاش مساحة مسح تنزيل تنزيل تلقائي استخدام البيانات خلوي جوال واي فاي wifi حفظ الصور معرض storage cache';

  @override
  String get storageUsageTitle => 'استخدام التخزين';

  @override
  String get dataUsageTitle => 'استخدام البيانات';

  @override
  String get dataStorageAutoDownloadHeader => 'التنزيل التلقائي للوسائط';

  @override
  String get dataStorageUsingCellular => 'عند استخدام الخلوي';

  @override
  String get dataStorageUsingWifi => 'عند استخدام Wi-Fi';

  @override
  String get dataStorageNowTag => 'الآن';

  @override
  String get autoDownloadReset => 'إعادة ضبط إعدادات التنزيل التلقائي';

  @override
  String get autoDownloadResetTitle =>
      'هل تريد استعادة إعدادات التنزيل التلقائي الافتراضية؟';

  @override
  String get dataStorageSaveHeader => 'حفظ في الصور';

  @override
  String get dataStorageSaveFooter =>
      'احفظ الصور ومقاطع الفيديو الجديدة من هذه الدردشات تلقائيًا في مكتبة الصور.';

  @override
  String get dataStorageCallsHeader => 'المكالمات';

  @override
  String get dataStorageLessDataForCalls => 'استخدام بيانات أقل للمكالمات';

  @override
  String get dataStorageCallsFooter =>
      'يستخدم بيانات أقل على الشبكات الضعيفة أو المحدودة، مع جودة صوت وفيديو أقل قليلًا.';

  @override
  String get dataStorageCallsNever => 'أبدًا';

  @override
  String get dataStorageCallsCellular => 'على الخلوي';

  @override
  String get dataStorageCallsAlways => 'دائمًا';

  @override
  String get dataStorageOff => 'مُعطّل';

  @override
  String get dataStorageChatsPrivate => 'الدردشات الخاصة';

  @override
  String get dataStorageChatsGroups => 'المجموعات';

  @override
  String get dataStorageChatsPublic => 'الغرف العامة';

  @override
  String get dataStorageNetCellular => 'الخلوي';

  @override
  String get dataStorageNetWifi => 'Wi-Fi';

  @override
  String get autoDownloadMaster => 'تنزيل الوسائط تلقائيًا';

  @override
  String get autoDownloadUsageHeader => 'استخدام البيانات';

  @override
  String get autoDownloadPresetLow => 'منخفض';

  @override
  String get autoDownloadPresetMedium => 'متوسط';

  @override
  String get autoDownloadPresetHigh => 'مرتفع';

  @override
  String get autoDownloadCustomFooter =>
      'لقد خصّصت هذه الإعدادات. حرّك شريط التمرير للعودة إلى إعداد مسبق.';

  @override
  String get autoDownloadTypesHeader => 'أنواع الوسائط';

  @override
  String get autoDownloadVideosTitle => 'الفيديوهات وملاحظات الفيديو';

  @override
  String get autoDownloadVoiceFooter =>
      'الرسائل الصوتية والملصقات صغيرة جدًا، لذا تُنزَّل تلقائيًا دائمًا.';

  @override
  String get autoDownloadAllChats => 'كل الدردشات';

  @override
  String autoDownloadUpToIn(String size, String chats) {
    return 'حتى $size في $chats';
  }

  @override
  String autoDownloadSummaryUpTo(String kind, String size) {
    return '$kind حتى $size';
  }

  @override
  String get autoDownloadSummaryVoiceOnly => 'الرسائل الصوتية فقط';

  @override
  String get autoDownloadInHeader => 'التنزيل التلقائي في';

  @override
  String get autoDownloadMaxSizeHeader => 'الحد الأقصى لحجم الملف';

  @override
  String autoDownloadMaxSizeVideoFooter(String size) {
    return 'تُنزَّل الفيديوهات حتى $size تلقائيًا. أما الأكبر منها فتنتظر نقرة منك.';
  }

  @override
  String autoDownloadMaxSizeFileFooter(String size) {
    return 'تُنزَّل الملفات حتى $size تلقائيًا. أما الأكبر منها فتنتظر نقرة منك.';
  }

  @override
  String get autoDownloadGateLoad => 'تنزيل الصورة';

  @override
  String get saveToPhotosHeader => 'الحفظ التلقائي';

  @override
  String get saveToPhotosFooter =>
      'تُضاف الصور ومقاطع الفيديو الجديدة التي تتلقاها في هذه الدردشات إلى مكتبة الصور عند تنزيلها.';

  @override
  String get saveToPhotosMaxVideoHeader => 'الحد الأقصى لحجم الفيديو';

  @override
  String get saveToPhotosNoAccess =>
      'اسمح بالوصول إلى مكتبة الصور من الإعدادات للحفظ التلقائي.';

  @override
  String get saveToPhotosPhotosAndVideos => 'الصور ومقاطع الفيديو';

  @override
  String get storageCalculating => 'جارٍ الحساب…';

  @override
  String storageShareOfFree(String percent) {
    return 'يستخدم MonkeyHub نسبة $percent من المساحة المتاحة.';
  }

  @override
  String get storageEmpty => 'لا يوجد شيء في الذاكرة المؤقتة حاليًا.';

  @override
  String storageClearAllButton(String size) {
    return 'مسح كل الذاكرة المؤقتة $size';
  }

  @override
  String storageClearSelectedButton(String size) {
    return 'مسح المحدد $size';
  }

  @override
  String storageClearChatButton(String size) {
    return 'مسح الذاكرة المؤقتة $size';
  }

  @override
  String get storageClearFooter =>
      'يبقى كل شيء في السحابة ويُنزَّل مجددًا متى احتجت إليه.';

  @override
  String get storageClearAllTitle => 'هل تريد مسح كل الذاكرة المؤقتة؟';

  @override
  String get storageClearSelectedTitle => 'هل تريد مسح العناصر المحددة؟';

  @override
  String get storageClearBody =>
      'تبقى رسائلك كما هي. تُنزَّل الوسائط مجددًا عند فتحها.';

  @override
  String storageClearConfirm(String size) {
    return 'مسح $size';
  }

  @override
  String storageFreed(String size) {
    return 'تم تحرير $size';
  }

  @override
  String storageCleanupTitle(String size) {
    return 'تحرير $size';
  }

  @override
  String get storageCleanupSubtitle => 'وسائط لم تفتحها منذ شهر';

  @override
  String get storageCleanupAction => 'تنظيف';

  @override
  String get storageCleanupFooter =>
      'يمسح فقط الوسائط التي لم يفتحها أحد منذ 30 يومًا. لا تُمَسّ الرسائل المحفوظة أبدًا.';

  @override
  String get storageAutoRemoveHeader => 'الإزالة التلقائية للوسائط المؤقتة';

  @override
  String get storageAutoRemoveFooter =>
      'تُزال الوسائط التي لم تفتحها طوال هذه المدة من هذا الجهاز لتوفير المساحة. تبقى في السحابة، وتُحفظ الرسائل المحفوظة دائمًا.';

  @override
  String get dataStorageKeepNever => 'أبدًا';

  @override
  String get dataStorageKeepMonth => 'شهر واحد';

  @override
  String get dataStorageKeepWeek => 'أسبوع واحد';

  @override
  String get dataStorageKeepDay => 'يوم واحد';

  @override
  String get storageLimitHeader => 'الحد الأقصى لحجم الذاكرة المؤقتة';

  @override
  String get storageLimitFooter =>
      'إذا تجاوزت الذاكرة المؤقتة هذا الحجم، تُزال أولًا الوسائط التي فتحتها منذ أطول مدة.';

  @override
  String get dataStorageLimitNone => 'بلا حد';

  @override
  String get storageTabChats => 'الدردشات';

  @override
  String get storageTabMedia => 'الوسائط';

  @override
  String get storageTabFiles => 'الملفات';

  @override
  String get storageNoChats => 'لم تُخزَّن أي دردشة مؤقتًا بعد.';

  @override
  String get storageNoMedia => 'لا توجد صور أو فيديوهات مخزنة مؤقتًا بعد.';

  @override
  String get storageNoFiles => 'لا توجد ملفات مخزنة مؤقتًا بعد.';

  @override
  String get storageOpenPhoto => 'فتح الصورة';

  @override
  String get storageOpenVideo => 'فتح الفيديو';

  @override
  String get storageSelect => 'تحديد';

  @override
  String storageChatShare(String percent) {
    return 'تستخدم هذه الدردشة $percent من الذاكرة المؤقتة.';
  }

  @override
  String get storageChatUnknown => 'دردشة غادرتها';

  @override
  String dataUsageSince(String date) {
    return 'منذ $date';
  }

  @override
  String get dataUsageAll => 'الكل';

  @override
  String get dataUsageNothingYet => 'لم يُحتسب أي شيء على هذه الشبكة بعد.';

  @override
  String get dataUsageTapHint => 'اضغط على فئة لرؤية ما أُرسل وما استُلم.';

  @override
  String get dataUsageSent => 'المُرسَل';

  @override
  String get dataUsageReceived => 'المُستلَم';

  @override
  String get dataUsageTotalHeader => 'إجمالي استخدام الشبكة';

  @override
  String get dataUsageFootnote =>
      'يحتسب الوسائط والمكالمات. الرسائل نفسها صغيرة جدًا ولا تُحتسب.';

  @override
  String get dataUsageReset => 'إعادة ضبط الإحصائيات';

  @override
  String get dataUsageResetTitle =>
      'هل تريد إعادة ضبط إحصائيات استخدام البيانات؟';

  @override
  String get dataUsageResetBody => 'يبدأ العدّ من جديد من الآن.';

  @override
  String get storageKindCompanions => 'الرفاق';

  @override
  String get storageCompanionsNote =>
      'لا يُمسح الرفاق مع ذاكرة التخزين المؤقت. اضغط عليهم لإدارة تنزيلاتهم.';

  @override
  String storageCategoryCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر، $size',
      many: '$count عنصرًا، $size',
      few: '$count عناصر، $size',
      two: 'عنصران، $size',
      one: 'عنصر واحد، $size',
      zero: 'لا عناصر، $size',
    );
    return '$_temp0';
  }

  @override
  String get storageSelectAll => 'تحديد الكل';

  @override
  String get storageDeselectAll => 'إلغاء التحديد';

  @override
  String get storageCategoryEmpty =>
      'لا يوجد شيء من هذا النوع في ذاكرة التخزين المؤقت حاليًا.';

  @override
  String get storageChatHistoryFooter =>
      'تتم إزالة النسخة الموجودة على هذا الجهاز فقط. تبقى الرسائل في الدردشة وتُحمَّل مجددًا عند فتحها في المرة القادمة.';

  @override
  String get storageCategoryHint =>
      'اضغط على فئة لترى محتواها، أو على دائرتها لاستبعادها.';

  @override
  String storageChatRemovedNamed(String names) {
    return '$names · محادثة محذوفة';
  }

  @override
  String get streaksLabel => 'السلاسل';

  @override
  String get streakAtRiskFooter => 'العب اليوم للحفاظ على سلسلتك.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'سلسلة $count يوم',
      many: 'سلسلة $count يومًا',
      few: 'سلسلة $count أيام',
      two: 'سلسلة يومين',
      one: 'سلسلة يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String recordsCheersMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'و$count آخرين',
      many: 'و$count آخرين',
      few: 'و$count آخرين',
      two: 'وشخصان آخران',
      one: 'وشخص آخر',
    );
    return '$_temp0';
  }

  @override
  String get recordsCheer => 'شجّع';

  @override
  String get myStreaksLabel => 'سلاسلي';

  @override
  String streakLongest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return 'أطول سلسلة لك: $_temp0';
  }

  @override
  String get streaksEmpty => 'لا أحد في سلسلة هنا بعد.';

  @override
  String videoTooLargeSnack(String size) {
    return 'الحد الأقصى لحجم الفيديو هو $size';
  }

  @override
  String videoShrinkPromptTitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو يتجاوز $size',
      many: '$count فيديو يتجاوز $size',
      few: '$count فيديوهات تتجاوز $size',
      two: 'فيديوهان يتجاوزان $size',
      one: 'هذا الفيديو يتجاوز $size',
      zero: '$count فيديوهات تتجاوز $size',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkPromptBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ستُضغط لتتّسع، فتوقّع أن تقل جودتها كثيرًا.',
      one: 'سيُضغط ليتّسع، فتوقّع أن تقل جودته كثيرًا.',
    );
    return '$_temp0';
  }

  @override
  String get videoShrinkPromptAction => 'اضغط وأرسل';

  @override
  String get videoShrinkWorkingSnack => 'جارٍ ضغط الفيديو…';

  @override
  String videoShrinkFailedSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فيديو طويلة جدًا ولن تتّسع في $size حتى بعد الضغط',
      one: 'طويل جدًا ولن يتّسع في $size حتى بعد الضغط',
    );
    return '$_temp0';
  }

  @override
  String photoHdOverCapSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صورة تجاوزت $size فأُرسلت بجودة عادية',
      many: '$count صورة تجاوزت $size فأُرسلت بجودة عادية',
      few: '$count صور تجاوزت $size فأُرسلت بجودة عادية',
      two: 'صورتان تجاوزتا $size فأُرسلتا بجودة عادية',
      one: 'صورة واحدة تجاوزت $size فأُرسلت بجودة عادية',
      zero: '$count صور تجاوزت $size فأُرسلت بجودة عادية',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkSendSmallOnly(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أرسل الـ $count الأصغر من $size فقط',
      one: 'أرسل الفيديو الأصغر من $size فقط',
    );
    return '$_temp0';
  }

  @override
  String get kbdGroupGeneral => 'عام';

  @override
  String get kbdGroupNavigation => 'التنقل';

  @override
  String get kbdGroupChat => 'داخل الدردشة';

  @override
  String get kbdGroupComposer => 'الكتابة';

  @override
  String get kbdGroupViewer => 'الصور والفيديوهات';

  @override
  String get kbdGroupCall => 'المكالمات';

  @override
  String get kbdCommandPalette => 'البحث في الدردشات والأوامر';

  @override
  String get kbdShowShortcuts => 'اختصارات لوحة المفاتيح';

  @override
  String get kbdSearch => 'بحث';

  @override
  String get kbdNewChat => 'محادثة جديدة';

  @override
  String get kbdSettings => 'الإعدادات';

  @override
  String get kbdBack => 'رجوع أو إغلاق';

  @override
  String kbdGoTo(String section) {
    return 'الانتقال إلى $section';
  }

  @override
  String get kbdNextChat => 'المحادثة التالية';

  @override
  String get kbdPreviousChat => 'المحادثة السابقة';

  @override
  String get kbdNextUnread => 'المحادثة غير المقروءة التالية';

  @override
  String get kbdCloseChat => 'إغلاق المحادثة';

  @override
  String get kbdRoomInfo => 'معلومات المحادثة';

  @override
  String get kbdSearchInChat => 'البحث في هذه المحادثة';

  @override
  String get kbdJumpToLatest => 'الانتقال إلى أحدث رسالة';

  @override
  String get kbdAttach => 'إرفاق ملفات';

  @override
  String get kbdVoiceCall => 'مكالمة صوتية';

  @override
  String get kbdVideoCall => 'مكالمة فيديو';

  @override
  String get kbdSend => 'إرسال';

  @override
  String get kbdNewline => 'سطر جديد';

  @override
  String get kbdEditLast => 'تعديل رسالتك الأخيرة';

  @override
  String get kbdBold => 'عريض';

  @override
  String get kbdItalic => 'مائل';

  @override
  String get kbdUnderline => 'تسطير';

  @override
  String get kbdPasteMedia => 'لصق صورة أو ملف';

  @override
  String get kbdEmoji => 'الرموز التعبيرية والملصقات';

  @override
  String get kbdViewerPrevious => 'السابق';

  @override
  String get kbdViewerNext => 'التالي';

  @override
  String get kbdZoomIn => 'تكبير';

  @override
  String get kbdZoomOut => 'تصغير';

  @override
  String get kbdZoomFit => 'ملاءمة للنافذة';

  @override
  String get kbdPlayPause => 'تشغيل أو إيقاف مؤقت';

  @override
  String get kbdCopyMedia => 'نسخ';

  @override
  String get kbdSaveMedia => 'حفظ';

  @override
  String get kbdToggleMute => 'كتم الميكروفون أو إلغاء كتمه';

  @override
  String get kbdToggleCamera => 'تشغيل الكاميرا أو إيقافها';

  @override
  String get kbdHangUp => 'إنهاء المكالمة';

  @override
  String get kbdGroupApp => 'التطبيق';

  @override
  String get kbdCloseWindow => 'إغلاق النافذة';

  @override
  String get kbdMinimizeWindow => 'تصغير';

  @override
  String get kbdFullScreen => 'ملء الشاشة';

  @override
  String get kbdHideApp => 'إخفاء MonkeyHub';

  @override
  String get kbdQuit => 'إنهاء MonkeyHub';

  @override
  String get kbdPanelTitle => 'اختصارات لوحة المفاتيح';

  @override
  String get kbdPanelSearchHint => 'البحث في الاختصارات';

  @override
  String get kbdPanelEmpty => 'لا توجد اختصارات مطابقة';

  @override
  String kbdPeekHint(String key) {
    return 'اضغط مطولًا على $key في أي وقت لعرض اختصارات الشاشة الحالية';
  }

  @override
  String kbdPeekSetting(String key) {
    return 'عرض الاختصارات عند الضغط مطولًا على $key';
  }

  @override
  String get kbdPaletteHint => 'انتقل إلى دردشة أو نفّذ أمرًا';

  @override
  String get kbdPaletteChats => 'الدردشات';

  @override
  String get kbdPaletteCommands => 'الأوامر';

  @override
  String get kbdPaletteEmpty => 'لم يتم العثور على شيء';

  @override
  String get kbdPaletteMove => 'تنقّل';

  @override
  String get kbdPaletteOpen => 'فتح';

  @override
  String get kbdPaletteClose => 'إغلاق';

  @override
  String get msgDeskReactLabel => 'تفاعل';

  @override
  String get msgDeskMoreLabel => 'المزيد';

  @override
  String get msgDeskInfoLabel => 'معلومات';

  @override
  String get kbdSeekBackward => 'رجوع 5 ثوانٍ';

  @override
  String get kbdSeekForward => 'تقديم 5 ثوانٍ';

  @override
  String get kbdMuteVideo => 'كتم صوت الفيديو أو إلغاء كتمه';

  @override
  String get viewerSavedToDownloads => 'تم الحفظ في التنزيلات';

  @override
  String get viewerDownloaded => 'تم التنزيل';

  @override
  String get viewerShowInFinder => 'عرض في Finder';

  @override
  String get viewerShowInFolder => 'عرض في المجلد';

  @override
  String get viewerCopied => 'تم النسخ';

  @override
  String get viewerCopyFailed => 'تعذّر النسخ';

  @override
  String get hoverCompactLayoutTitle => 'تخطيط مضغوط';

  @override
  String get hoverCompactLayoutSubtitle =>
      'صفوف أقصر وأزرار أصغر، مناسبة للماوس والشاشات الكبيرة.';

  @override
  String get layoutPagerPrevious => 'السابق';

  @override
  String get layoutPagerNext => 'التالي';

  @override
  String get resultSheetMistakes => 'الأخطاء';

  @override
  String get resultSheetHints => 'التلميحات';

  @override
  String get resultSheetStreak => 'السلسلة';

  @override
  String resultSheetStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أيام',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get resultSheetNone => 'لا شيء';

  @override
  String resultSheetToday(String game) {
    return '$game · اليوم';
  }

  @override
  String resultSheetYouFaster(String time) {
    return 'كنت أسرع بـ $time';
  }

  @override
  String resultSheetTheyFaster(String name, String time) {
    return 'كان $name أسرع بـ $time';
  }

  @override
  String get resultSheetSameTime => 'نفس وقتك';

  @override
  String get resultSheetFooter =>
      'الوقت وحده يحدد الترتيب. الأخطاء والتلميحات للفضوليين فقط.';

  @override
  String get resultSheetHintNoRecord =>
      'حُلّت بتلميحات، لذا لا يمكن أن تصبح رقمًا قياسيًا.';

  @override
  String get gameTierEasy => 'سهل';

  @override
  String get gameTierMedium => 'متوسط';

  @override
  String get gameTierHard => 'صعب';

  @override
  String get gameComingSoon => 'قريبًا';

  @override
  String get gameComingSoonName => 'لغز جديد';

  @override
  String get chatGameNameTicTacToe => 'إكس أو';

  @override
  String get chatGameNameConnectFour => 'أربعة في صف';

  @override
  String get chatGameNameCheckers => 'الداما';

  @override
  String get chatGameNameReversi => 'ريفرسي';

  @override
  String get chatGameNameDots => 'النقاط والمربعات';

  @override
  String get chatGameDescTicTacToe => 'ثلاثة في صف تفوز.';

  @override
  String get chatGameDescConnectFour => 'أسقط الأقراص. أربعة في صف تفوز.';

  @override
  String get chatGameDescCheckers => 'اقفز لتأسر. خذ كل القطع.';

  @override
  String get chatGameDescReversi => 'حاصر لتقلب. الأكثر أقراصًا يفوز.';

  @override
  String get chatGameDescDots => 'ارسم خطوطًا، أغلق المربعات، والعب مجددًا.';

  @override
  String get chatGameKindLive => 'لعبة مباشرة';

  @override
  String get chatGameKindTurns => 'بالتناوب';

  @override
  String get chatGameStatusWaiting => 'بانتظار اللاعبين';

  @override
  String get chatGameStatusPlaying => 'جارية';

  @override
  String get chatGameStatusPaused => 'متوقفة مؤقتًا';

  @override
  String get chatGameStatusFinished => 'انتهت';

  @override
  String get chatGameStatusEnded => 'انتهت بلا فائز';

  @override
  String get chatGameYourMove => 'دورك';

  @override
  String chatGameTurnOf(String name) {
    return 'دور $name';
  }

  @override
  String chatGameWaitingFor(String name) {
    return 'بانتظار $name';
  }

  @override
  String chatGameWonBy(String name) {
    return 'فاز $name';
  }

  @override
  String get chatGameYouWon => 'فزت';

  @override
  String get chatGameDraw => 'تعادل';

  @override
  String get chatGameNobodyWon => 'غادر الجميع، فلا فائز';

  @override
  String chatGameReasonTimeout(String name) {
    return 'نفد وقت $name';
  }

  @override
  String chatGameReasonResign(String name) {
    return 'استسلم $name';
  }

  @override
  String chatGameReasonLeft(String name) {
    return 'غادر $name';
  }

  @override
  String get chatGameOpenSeat => 'مقعد شاغر';

  @override
  String get chatGameReady => 'جاهز';

  @override
  String get chatGameNotReady => 'غير جاهز';

  @override
  String chatGameWatchingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يشاهدون',
      one: 'شخص واحد يشاهد',
    );
    return '$_temp0';
  }

  @override
  String get chatGameJoin => 'انضم';

  @override
  String get chatGameWatch => 'شاهد';

  @override
  String get chatGamePlay => 'العب';

  @override
  String get chatGameOpen => 'افتح';

  @override
  String get chatGameRematch => 'مباراة إعادة';

  @override
  String get chatGameNotRanked =>
      'للمتعة فقط. ألعاب الدردشة لا تُحتسب في سلاسلك أو أرقامك القياسية.';

  @override
  String get chatGameNotRankedShort => 'غير مُصنّفة';

  @override
  String get chatGameImReady => 'أنا جاهز';

  @override
  String get chatGameUnready => 'لست جاهزًا بعد';

  @override
  String get chatGameTakeSeat => 'اضغط للانضمام';

  @override
  String get chatGameLeaveSeat => 'غادر المقعد';

  @override
  String get chatGameStartsWhenReady => 'تبدأ عندما يكون الجميع جاهزين';

  @override
  String chatGameNeedPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بانتظار $count لاعبين آخرين',
      one: 'بانتظار لاعب واحد آخر',
    );
    return '$_temp0';
  }

  @override
  String get chatGameWatchingLabel => 'المشاهدون';

  @override
  String get chatGameAskSwap => 'اطلب التبديل';

  @override
  String chatGameSwapRequest(String name) {
    return 'يريد $name أخذ مكانك';
  }

  @override
  String get chatGameSwap => 'بدّل';

  @override
  String get chatGameDecline => 'رفض';

  @override
  String get chatGameAccept => 'قبول';

  @override
  String chatGameSwapAsked(String name) {
    return 'تم سؤال $name';
  }

  @override
  String get chatGameCancel => 'إلغاء';

  @override
  String get chatGameResign => 'استسلام';

  @override
  String get chatGameResignConfirm => 'هل تستسلم في هذه اللعبة؟';

  @override
  String get chatGameResignBody => 'ستُحتسب خسارة لك.';

  @override
  String get chatGameOfferDraw => 'اعرض التعادل';

  @override
  String get chatGameDrawOffered => 'تم عرض التعادل';

  @override
  String chatGameDrawOfferFrom(String name) {
    return 'يعرض $name التعادل';
  }

  @override
  String chatGamePausedTitle(String name) {
    return 'غادر $name اللعبة';
  }

  @override
  String get chatGamePausedMany => 'غادر بعض اللاعبين';

  @override
  String get chatGamePausedBody => 'سنحتفظ باللوحة لبعض الوقت.';

  @override
  String get chatGamePausedYou => 'تُستأنف اللعبة عند عودة الجميع.';

  @override
  String get chatGameLeave => 'مغادرة اللعبة';

  @override
  String get chatGameGo => 'انطلق!';

  @override
  String get chatGameNudge => 'تذكير';

  @override
  String get chatGameNudged => 'تم التذكير';

  @override
  String chatGameHoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقيت $count ساعات',
      one: 'بقيت ساعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String chatGameMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'بقيت $count دقائق',
      one: 'بقيت دقيقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get chatGameMoveFailed => 'لم تُرسل تلك الحركة';

  @override
  String get chatGameStale => 'تغيّرت اللوحة. حاول مجددًا.';

  @override
  String get chatGameStartTitle => 'العب لعبة';

  @override
  String get chatGameMenuItem => 'لعبة';

  @override
  String get chatGameModeLive => 'مباشر';

  @override
  String get chatGameBotEasyHint => 'يرتكب أخطاء. مناسب للتعلّم.';

  @override
  String get chatGameBotMediumHint => 'يلعب بإنصاف ويمنع فوزك.';

  @override
  String get chatGameBotHardHint => 'يفكر عدة حركات مسبقًا.';

  @override
  String get chatGameStart => 'ابدأ';

  @override
  String get chatGameErrAlreadyLive =>
      'توجد لعبة مباشرة هنا بالفعل. أنهِها أو غادرها أولًا.';

  @override
  String get chatGameErrTooMany =>
      'لديكما 3 ألعاب بالتناوب هنا بالفعل. أنهيا واحدة أولًا.';

  @override
  String get chatGameErrEphemeral => 'لا يمكن اللعب في دردشة تختفي رسائلها.';

  @override
  String get chatGameErrGeneric => 'حدث خطأ ما. حاول مجددًا.';

  @override
  String get chatGamePlayersTwo => 'لاعبان';

  @override
  String get chatGamePlayersUpToFour => '2–4 لاعبين';

  @override
  String get chatGameBotName => 'القرد';

  @override
  String get chatGameBotBadge => 'روبوت';

  @override
  String get chatGameNewGame => 'لعبة جديدة';

  @override
  String chatGameBannerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ألعاب',
      one: 'لعبة واحدة',
    );
    return '$_temp0';
  }

  @override
  String chatGameBannerYourMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'دورك في $count ألعاب',
      one: 'دورك في لعبة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get chatGameSheetTitle => 'الألعاب في هذه الدردشة';

  @override
  String get chatGameGone => 'هذه اللعبة لم تعد متاحة.';

  @override
  String get chatGameSeatsLabel => 'اللاعبون';

  @override
  String get gameFlowName => 'تدفّق';

  @override
  String get gameFutoshikiName => 'فوتوشيكي';

  @override
  String get gameNonogramName => 'نونوغرام';

  @override
  String get gameMinesweeperName => 'كاسحة الألغام';

  @override
  String get gameStarbattleName => 'معركة النجوم';

  @override
  String get gamePatchesName => 'الرُّقَع';

  @override
  String get gameFlowRule => 'صِل النقاط المتطابقة واملأ كل مربع';

  @override
  String get gameFutoshikiRule =>
      'من 1 إلى 5 مرة في كل صف وعمود، وكل إشارة صحيحة';

  @override
  String get gameNonogramRule => 'ظلّل المربعات لتطابق كل رقم';

  @override
  String get gameMinesweeperRule => 'افتح كل مربع آمن، دون حاجة إلى التخمين';

  @override
  String get gameStarbattleRule => 'نجمتان في كل صف وعمود ولون، دون تلامس';

  @override
  String get gamePatchesRule => 'قسّم اللوحة إلى مستطيلات، في كل واحد دليل';

  @override
  String get gameFlag => 'علَم';

  @override
  String get gameAutoDot => 'نقاط تلقائية';

  @override
  String boardCellName(int row, int col) {
    return 'الصف $row، العمود $col';
  }

  @override
  String get boardEmpty => 'فارغ';

  @override
  String get boardBlack => 'أسود';

  @override
  String get boardWhite => 'أبيض';

  @override
  String get boardLegalMove => 'حركة مسموحة';

  @override
  String get boardMoveHere => 'تحرك هنا';

  @override
  String boardColumnFilled(int column, int count, int total) {
    return 'العمود $column، $count من $total ممتلئ';
  }

  @override
  String boardSquareName(int number) {
    return 'المربع $number';
  }

  @override
  String get boardDarkMan => 'قطعة داكنة';

  @override
  String get boardDarkKing => 'ملك داكن';

  @override
  String get boardLightMan => 'قطعة فاتحة';

  @override
  String get boardLightKing => 'ملك فاتح';

  @override
  String boardBoxName(String cell) {
    return 'مربع، $cell';
  }

  @override
  String get boardOpen => 'مفتوح';

  @override
  String get boardDrawn => 'مرسوم';

  @override
  String boardClaimedBy(String name) {
    return 'استحوذ عليه $name';
  }

  @override
  String boardHorizontalEdge(int row, int col) {
    return 'خط أفقي، الصف $row، العمود $col';
  }

  @override
  String boardVerticalEdge(int row, int col) {
    return 'خط عمودي، الصف $row، العمود $col';
  }

  @override
  String get challengeAction => 'تحدَّ';

  @override
  String get challengeTitle => 'تغلّب على وقتي';

  @override
  String get challengeKind => 'تحدٍّ يومي';

  @override
  String challengeYouBeat(String time) {
    return 'تغلبت عليه بفارق $time';
  }

  @override
  String challengeStillStanding(String time) {
    return 'ما زال صامدًا بفارق $time';
  }

  @override
  String get challengeTie => 'تعادل تام';

  @override
  String get challengeClosed => 'أُغلقت تلك اللوحة';

  @override
  String get challengeYourTime => 'وقتك المطلوب تجاوزه';

  @override
  String get challengeSent => 'تم إرسال التحدي';

  @override
  String challengeTarget(String name, String time) {
    return '$name $time';
  }

  @override
  String challengeBeatName(String name, String time) {
    return 'تغلبت على وقت $name ($time)';
  }

  @override
  String challengeKept(String name, String time) {
    return 'يحتفظ به $name بفارق $time';
  }

  @override
  String challengeBackName(String name) {
    return 'رُدّ التحدي على $name';
  }

  @override
  String challengeBackRoom(String room) {
    return 'الرد في $room';
  }

  @override
  String challengeFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لعب $count صديق',
      many: 'لعب $count صديقًا',
      few: 'لعب $count أصدقاء',
      two: 'لعب صديقان',
      one: 'لعب صديق واحد',
      zero: 'لم يلعب أي من أصدقائك هنا بعد',
    );
    return '$_temp0';
  }

  @override
  String challengeYouAndFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لعبتَ أنت و$count صديق',
      many: 'لعبتَ أنت و$count صديقًا',
      few: 'لعبتَ أنت و$count أصدقاء',
      two: 'لعبتَ أنت وصديقان',
      one: 'لعبتَ أنت وصديق واحد',
      zero: 'أنت فقط من لعب حتى الآن',
    );
    return '$_temp0';
  }

  @override
  String get challengeFriendsOnlyNote =>
      'يظهر هنا أصدقاؤك فقط. ربما لعب أشخاص آخرون في هذه الدردشة أيضًا.';

  @override
  String get chatGameNameLiarsDice => 'نرد الكذّاب';

  @override
  String get chatGameNameImposter => 'المحتال';

  @override
  String get chatGameNameRace => 'سباق الألغاز';

  @override
  String get chatGameDescLiarsDice => 'زايِد على نرد مخفي واكشف الكذّاب.';

  @override
  String get chatGameDescImposter => 'أحدكم لا يعرف الكلمة. اكتشفوه.';

  @override
  String get chatGameDescRace => 'اللغز نفسه للجميع. الأسرع يفوز.';

  @override
  String chatGamePlayersRange(int min, int max) {
    return '$min–$max لاعبين';
  }

  @override
  String chatGameNeedsPeople(int count) {
    return 'يلزم $count أشخاص على الأقل';
  }

  @override
  String get chatGameVoiceOption => 'تلميحات صوتية';

  @override
  String get chatGameVoiceOptionHint => 'تحدّثوا في مكالمة بدل كتابة التلميحات';

  @override
  String get chatGamePuzzleOption => 'اللغز';

  @override
  String get chatGamePuzzleRandom => 'عشوائي';

  @override
  String chatGameStartNamed(String game) {
    return 'ابدأ $game';
  }

  @override
  String chatGameLdRoundDice(int count, int round) {
    return 'الجولة $round · $count نرد';
  }

  @override
  String get chatGameLdYourDice => 'نردك';

  @override
  String get chatGameLdNoBid => 'لا مزايدة بعد';

  @override
  String chatGameLdBidBy(String name) {
    return 'مزايدة $name';
  }

  @override
  String get chatGameLdYourBid => 'مزايدتك';

  @override
  String get chatGameLdBid => 'زايِد';

  @override
  String get chatGameLdLiar => 'كذّاب!';

  @override
  String get chatGameLdOnesWild => 'الواحد يُحسب لأي وجه';

  @override
  String get chatGameLdOnesOnly => 'المزايدة على الواحد: بلا بديل';

  @override
  String get chatGameLdHolds => 'المزايدة صحيحة';

  @override
  String get chatGameLdBusted => 'انكشف!';

  @override
  String chatGameLdThereWere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كان هناك $count',
      many: 'كان هناك $count',
      few: 'كان هناك $count',
      two: 'كان هناك اثنان',
      one: 'كان هناك واحد',
      zero: 'لم يكن هناك أي واحد',
    );
    return '$_temp0';
  }

  @override
  String chatGameLdLosesDie(String name) {
    return '$name يخسر نردًا';
  }

  @override
  String get chatGameLdYouLoseDie => 'خسرتَ نردًا';

  @override
  String chatGameLdCalled(String name) {
    return '$name قال: كذّاب';
  }

  @override
  String chatGameLdTimedOut(String name) {
    return 'انتهى وقت $name';
  }

  @override
  String get chatGameLdOut => 'خرج';

  @override
  String get chatGameLdQuantity => 'كم عددها';

  @override
  String get chatGameLdFace => 'أي وجه';

  @override
  String get chatGameLdFewer => 'أقل';

  @override
  String get chatGameLdMore => 'أكثر';

  @override
  String get chatGameLdPrompt => 'ارفع المزايدة أو قل كذّاب';

  @override
  String get chatGameLdOpenPrompt => 'افتتح المزايدة';

  @override
  String get chatGameImpHoldToSee => 'اضغط مطوّلًا لرؤية بطاقتك';

  @override
  String get chatGameImpYourWord => 'كلمتك';

  @override
  String get chatGameImpYouAre => 'أنت المحتال';

  @override
  String chatGameImpCategory(String category) {
    return 'الفئة: $category';
  }

  @override
  String get chatGameImpBlendIn => 'اندمج معهم. لا أحد غيرك يعرف.';

  @override
  String get chatGameImpKeepSecret =>
      'لا تقلها صراحةً. أعطِ تلميحات يفهمها الآخرون.';

  @override
  String get chatGameImpGotIt => 'فهمت';

  @override
  String chatGameImpLooked(int count, int total) {
    return 'نظر $count من $total';
  }

  @override
  String chatGameImpGiving(String name) {
    return '$name يقدّم تلميحًا';
  }

  @override
  String get chatGameImpYourClue => 'دورك لتقديم تلميح';

  @override
  String get chatGameImpClueHint => 'من كلمة إلى أربع كلمات';

  @override
  String get chatGameImpClueField => 'تلميحك';

  @override
  String get chatGameImpSend => 'إرسال';

  @override
  String get chatGameImpTooManyWords => 'أربع كلمات كحد أقصى';

  @override
  String get chatGameImpPassed => 'تخطّى';

  @override
  String get chatGameImpSpoke => 'تحدّث في المكالمة';

  @override
  String get chatGameImpJoinCall => 'انضم إلى المكالمة';

  @override
  String get chatGameImpOnCall => 'أنت في المكالمة';

  @override
  String get chatGameImpVoiceHint => 'قل تلميحك بصوت عالٍ ثم اضغط تم.';

  @override
  String get chatGameImpDone => 'تم';

  @override
  String get chatGameImpVoteTitle => 'من المحتال؟';

  @override
  String get chatGameImpVoteHint =>
      'اضغط على لاعب للتصويت. يمكنك التغيير حتى ينتهي الوقت.';

  @override
  String get chatGameImpSkip => 'تخطَّ التصويت';

  @override
  String chatGameImpVoted(int count, int total) {
    return 'صوّت $count من $total';
  }

  @override
  String get chatGameImpVotedBadge => 'صوّت';

  @override
  String get chatGameImpYourVote => 'صوتك';

  @override
  String get chatGameImpGuessing => 'المحتال يخمّن…';

  @override
  String get chatGameImpGuessHint => 'تم كشفك. خمّن الكلمة لتخطف الفوز.';

  @override
  String get chatGameImpGuessField => 'الكلمة هي…';

  @override
  String get chatGameImpGuess => 'خمّن';

  @override
  String chatGameImpWas(String name) {
    return '$name كان المحتال';
  }

  @override
  String get chatGameImpYouWere => 'كنتَ المحتال';

  @override
  String get chatGameImpTheWord => 'كانت الكلمة';

  @override
  String chatGameImpTheyGuessed(String guess) {
    return 'خمّن «$guess»';
  }

  @override
  String chatGameImpVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صوت',
      many: '$count صوتًا',
      few: '$count أصوات',
      two: 'صوتان',
      one: 'صوت واحد',
      zero: 'لا أصوات',
    );
    return '$_temp0';
  }

  @override
  String chatGameImpSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'امتنع $count',
      many: 'امتنع $count',
      few: 'امتنع $count',
      two: 'امتنع اثنان',
      one: 'امتنع واحد',
      zero: 'لم يمتنع أحد',
    );
    return '$_temp0';
  }

  @override
  String get chatGameImpReasonEscaped => 'لم يُستبعد أحد، فنجا المحتال.';

  @override
  String get chatGameImpReasonWrong => 'صوّت الفريق ضد الشخص الخطأ.';

  @override
  String get chatGameImpReasonGuessed => 'انكشف المحتال لكنه خمّن الكلمة.';

  @override
  String get chatGameImpReasonCaught => 'أمسك الفريق بالمحتال.';

  @override
  String get chatGameImpReasonImposterLeft => 'غادر المحتال اللعبة.';

  @override
  String get chatGameImpReasonCrewLeft => 'غادر باقي الفريق.';

  @override
  String get chatGameImpCrewWon => 'فاز الفريق';

  @override
  String get chatGameImpYourTeamWon => 'فاز فريقك';

  @override
  String chatGameImpImposterWon(String name) {
    return 'فاز $name بصفته المحتال';
  }

  @override
  String get chatGameImpYouWonImposter => 'فزتَ بصفتك المحتال';

  @override
  String get chatGameImpCardReveal => 'الجميع ينظر إلى بطاقته';

  @override
  String chatGameImpCardClues(int count, int total) {
    return 'التلميحات · $count من $total';
  }

  @override
  String get chatGameImpCardVote => 'التصويت جارٍ';

  @override
  String chatGameRaceFinishedCount(int count, int total) {
    return 'أنهى $count من $total';
  }

  @override
  String chatGameRaceYouPlaced(int rank) {
    return 'أنهيتَ في المركز $rank';
  }

  @override
  String get chatGameRaceWaiting => 'بانتظار الآخرين';

  @override
  String get chatGameRaceTimeUp => 'انتهى الوقت ولم ينهِ أحد.';

  @override
  String get chatGameRaceDnf => 'لم ينهِ';

  @override
  String get chatGameRaceLeft => 'غادر';

  @override
  String get chatGameRaceResults => 'النتائج';

  @override
  String get chatGameRaceSolved => 'حللتَه!';

  @override
  String get chatGamePartyLeaveConfirm => 'مغادرة هذه اللعبة؟';

  @override
  String get chatGamePartyLeaveBody => 'سيكمل الآخرون من دونك.';

  @override
  String get chatGameErrTooLate => 'فات الأوان، انتهى الوقت';

  @override
  String get chatGameErrBadClue =>
      'لا يمكن استخدام هذا التلميح. من كلمة إلى أربع، بلا روابط.';

  @override
  String get chatGameErrBadGuess => 'اكتب تخمينًا أولًا';

  @override
  String get chatGameErrNotSolved => 'اللغز لم يُحلّ بعد';

  @override
  String get chatGameNameChess => 'الشطرنج';

  @override
  String get chatGameDescChess => 'حقّق كش مات لتفوز.';

  @override
  String get chessPawn => 'بيدق';

  @override
  String get chessKnight => 'حصان';

  @override
  String get chessBishop => 'فيل';

  @override
  String get chessRook => 'قلعة';

  @override
  String get chessQueen => 'وزير';

  @override
  String get chessKing => 'ملك';

  @override
  String chessPieceWhite(String piece) {
    return '$piece، أبيض';
  }

  @override
  String chessPieceBlack(String piece) {
    return '$piece، أسود';
  }

  @override
  String chessPromoteTo(String piece) {
    return 'رقِّ إلى $piece';
  }

  @override
  String get kbdPeekDontShowAgain => 'لا تُظهرها مرة أخرى';

  @override
  String get kbdPeekTurnedOff =>
      'تم، لن تظهر مرة أخرى. يمكنك إعادة تفعيلها من الإعدادات.';

  @override
  String get chatGameBadgeTurns => 'بالتناوب';

  @override
  String get chatGameSectionBoards => 'ألعاب الطاولة';

  @override
  String get chatGameSectionParty => 'ألعاب جماعية';

  @override
  String get chatGameBoardsHintDm =>
      'العبا مباشرة الآن، أو بالتناوب متى ما سنح لكما الوقت.';

  @override
  String get chatGameBoardsHintGroup => 'مباشرة هنا. خذ مقعدك أو شاهد فقط.';

  @override
  String get chatGamePartyHint =>
      'الجميع يلعبون في الوقت نفسه، فاجمعوا الأصدقاء أولًا.';

  @override
  String get chatGameLiveTitle => 'العب مباشرة';

  @override
  String get chatGameLiveNow => 'الجميع يلعبون في الوقت نفسه، الآن.';

  @override
  String get chatGameLivePause =>
      'إذا خرج أحدهم يتوقف اللعب. أمامه دقيقتان للعودة وإلا يخسر.';

  @override
  String get chatGameTurnsTitle => 'العب بالتناوب';

  @override
  String get chatGameTurnsAnytime =>
      'العب حركتك متى شئت. كل حركة تظهر في الدردشة.';

  @override
  String get chatGameTurnsClock =>
      'يومان لكل حركة. نذكّره، ويمكنك تذكيره أيضًا.';

  @override
  String get chatGameHowWillYouPlay => 'كيف تريد أن تلعب؟';

  @override
  String get botHubTitle => 'العب ضد البوت';

  @override
  String botHubSubtitle(String bot) {
    return 'أنت و$bot فقط. تعلّم الحركات، ثم تغلّب على أصدقائك.';
  }

  @override
  String get botHubLevelTitle => 'أي مستوى؟';

  @override
  String get botHubPickGame => 'اختر لعبة';

  @override
  String get botHubCaption => 'تدريب';

  @override
  String botHubGameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count لعبة',
      many: '$count لعبة',
      few: '$count ألعاب',
      two: 'لعبتان',
      one: 'لعبة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get practiceNotRanked =>
      'للمتعة فقط. هذه الألعاب لا تُحتسب في سلاسلك أو أرقامك القياسية.';

  @override
  String get chatGameMvYouPlayed => 'أنت لعبت';

  @override
  String chatGameMvTheyPlayed(String name) {
    return '$name لعب';
  }

  @override
  String chatGameMvNumber(int count) {
    return 'الحركة $count';
  }

  @override
  String chatGameMvColumn(int count) {
    return 'العمود $count';
  }

  @override
  String get chatGameMvEarlier => 'حركة سابقة';

  @override
  String get chatGameMvSend => 'أرسل الحركة';

  @override
  String get chatGameMvUndo => 'تراجع';

  @override
  String get chatGameMvStagedHint => 'لم تُرسل بعد. غيّر رأيك أو اضغط إرسال.';

  @override
  String get chatGameMvSentToast => 'أُرسلت حركتك. الدور الآن على الطرف الآخر.';

  @override
  String get chatGameMvYourTurnSub => 'العب حركتك ثم أرسلها. خذ وقتك.';

  @override
  String get chatGameMvWaitingSub => 'سننبهك عندما يأتي دورك.';

  @override
  String get chatGameMvNudgeLater => 'يمكنك تذكيره بعد 12 ساعة بلا رد';

  @override
  String get chatGameMvForfeitNote => 'إذا انتهى الوقت، يخسر صاحب الدور';

  @override
  String get chatGameMvAgain => 'ما زال دورك. العب مرة أخرى!';

  @override
  String get chatGameMvSending => 'جارٍ الإرسال…';

  @override
  String get howToNext => 'التالي';

  @override
  String get howToWatchAgain => 'شاهد مجددًا';

  @override
  String get howToGotIt => 'فهمت';

  @override
  String get howToProTip => 'نصيحة';

  @override
  String howToStepSemantic(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get howToQueens1 => 'تاج واحد في كل صف وكل عمود وكل لون.';

  @override
  String get howToQueens2 => 'التيجان لا تتلامس، ولا حتى بشكل مائل.';

  @override
  String get howToQueens3 => 'اضغط مرة لـ ×، ومرتين لتاج، ومرة ثالثة للمسح.';

  @override
  String get howToQueens4 =>
      'مع تفعيل «تعليم تلقائي»، يوضع لك × على كل مربع يستبعده التاج. ثم انظر ماذا تبقّى.';

  @override
  String get howToTango1 => 'ضغطة للشمس وضغطتان للقمر. املأ كل المربعات.';

  @override
  String get howToTango2 => 'كل صف وكل عمود نصفه شموس ونصفه أقمار.';

  @override
  String get howToTango3 =>
      'ممنوع 3 متشابهة متتالية، أفقيًا أو عموديًا. اثنان لا بأس.';

  @override
  String get howToTango4 => '= يعني أنهما متشابهان، و× يعني أنهما مختلفان.';

  @override
  String get howToTangoTip =>
      'اثنان متشابهان جنبًا إلى جنب؟ المربعان على الطرفين يأخذان الرمز الآخر.';

  @override
  String get howToZip1 => 'ابدأ من 1 واسحب على الأرقام بالترتيب.';

  @override
  String get howToZip2 => 'مرّ على كل المربعات وانتهِ عند آخر رقم.';

  @override
  String get howToZip3 => 'أخطأت الطريق؟ اسحب للخلف وتتراجع.';

  @override
  String get howToZipTip =>
      'لا تترك مربعًا معزولًا. خذ الزوايا والحواف وأنت تمرّ بها.';

  @override
  String get howToSudoku1 => 'كل صف وعمود ومربع فيه من 1 إلى 6. بدون تكرار.';

  @override
  String get howToSudoku2 => 'اضغط على مربع، ثم على رقم.';

  @override
  String get howToSudoku3 =>
      'رقم مكرر في الصف أو العمود أو المربع نفسه؟ يتحول للأحمر.';

  @override
  String get howToSudoku4 =>
      'ابحث عن الخطوط التي ينقصها رقم واحد. نقاط مجانية.';

  @override
  String get howToFlow1 => 'اسحب من نقطة إلى توأمها لتمد الأنبوب.';

  @override
  String get howToFlow2 =>
      'الأنابيب لا تتقاطع، ولازم تمتلئ كل المربعات. خذ الطريق الأطول.';

  @override
  String get howToFlowTip =>
      'مرّر الأنابيب على الحواف أولًا. الوسط سيحلّ نفسه.';

  @override
  String get howToFutoshiki1 =>
      'املأ كل مربع برقم من 1 إلى 5. كل رقم يظهر مرة واحدة بالضبط في كل صف وعمود.';

  @override
  String get howToFutoshiki2 =>
      'الطرف المدبب من الإشارة يشير إلى الرقم الأصغر.';

  @override
  String get howToFutoshiki3 => 'إذا خالفت إشارة تتحول للأحمر.';

  @override
  String get howToFutoshikiTip =>
      'تتبّع السلاسل: إذا كان a < b < c فإن c لا يقل عن 3.';

  @override
  String get howToNonogram1 =>
      'كل رقم مجموعة من المربعات الملوّنة المتتالية بلا فراغ. 5 يعني 5 مربعات متجاورة.';

  @override
  String get howToNonogram2 =>
      '1 1 يعني مربعين منفصلين بينهما مربع فارغ واحد على الأقل. ويمكن أن يكون الفراغ أكبر.';

  @override
  String get howToNonogramOrder =>
      'الترتيب مهم: الصفوف تُقرأ من اليسار إلى اليمين، والأعمدة من الأعلى إلى الأسفل. يعني 1 3: أولًا 1 ثم 3.';

  @override
  String get howToNonogram3 =>
      'اضغط للتلوين، ومرة ثانية لـ ×، ومرة ثالثة للمسح. اسحب لتعمل الكثير دفعة واحدة.';

  @override
  String get howToNonogram4 => 'طابق كل الأدلة وستظهر الصورة المخفية.';

  @override
  String get howToNonogramTip =>
      'ابدأ بالأرقام الكبيرة. الرقم 7 في صف من 10 يغطي دائمًا المربعات الأربعة في الوسط.';

  @override
  String get howToMines1 =>
      'افتح كل مربع لا يحتوي على لغم. المناطق الفارغة تنفتح وحدها.';

  @override
  String get howToMines2 => 'الرقم يخبرك كم لغمًا يلمسه، والزوايا محسوبة.';

  @override
  String get howToMines3 => 'متأكد أنه لغم؟ اضغط مطولًا لتضع علمًا.';

  @override
  String get howToMines4 =>
      'إذا دست على لغم تُضاف 30 ثانية عقوبة. لكنك لن تحتاج للتخمين أبدًا.';

  @override
  String get howToMinesTip =>
      'رقم 1 بجانبه مربع مخفي واحد فقط؟ هذا المربع هو اللغم.';

  @override
  String get howToStars1 => 'نجمتان في كل صف وكل عمود وكل لون.';

  @override
  String get howToStars2 => 'النجوم لا تتلامس، ولا حتى بشكل مائل.';

  @override
  String get howToStarsControls =>
      'اضغط مرة لنقطة، ومرتين لنجمة، ومرة ثالثة للمسح.';

  @override
  String get howToStars3 =>
      'مع تفعيل «نقاط تلقائية»، تضع النجمة نقاطًا على المربعات حولها. وعندما يكتمل الصف بنجمتيه، توضع النقاط على باقيه أيضًا.';

  @override
  String get howToPatches1 =>
      'قسّم اللوحة إلى مستطيلات. كل مستطيل فيه دليل واحد بالضبط.';

  @override
  String get howToPatches2 =>
      'الشارة تحدّد شكل الرقعة: مربع أو طولي أو عرضي. الشارة المتقطّعة تعني أنها قد تكون أيًّا من الثلاثة. والرقم، إن وُجد، هو عدد خانات الشبكة التي تغطيها الرقعة.';

  @override
  String get howToPatches3 =>
      'اسحب من زاوية إلى زاوية لتقصّ رقعة. اضغط على رقعة لإزالتها.';

  @override
  String get howToPatches4 =>
      'الدليل الكبير الملاصق للحافة غالبًا يتّسع بطريقة واحدة فقط. ابدأ منه.';

  @override
  String get howToCode1 =>
      'هناك شيفرة سرية من 4 رموز مختلفة، بلا تكرار. فكّها.';

  @override
  String get howToCode2 => 'الأخضر: الرمز صحيح ومكانه صحيح.';

  @override
  String get howToCode3 =>
      'الأصفر: موجود في الشيفرة لكن في مكان آخر. الرمادي: غير موجود فيها إطلاقًا.';

  @override
  String get howToCode4 => 'لديك 6 محاولات. كلما احتجت أقل، كان أفضل.';

  @override
  String get howToCodeTip =>
      'استخدم محاولاتك الأولى على رموز جديدة. أن تتعلّم أفضل من أن تخمّن.';

  @override
  String get howToTtt1 =>
      'تناوبوا على وضع علاماتكم. من يصفّ 3 على خط واحد يفوز.';

  @override
  String get howToTtt2 => 'عند خصمك 2 على خط واحد؟ اسبقه إلى المربع الثالث.';

  @override
  String get howToC41 =>
      'اضغط على عمود لتُسقط قرصًا. سيسقط إلى أدنى خانة فارغة.';

  @override
  String get howToC42 =>
      'صفّ 4 على خط واحد لتفوز: أفقيًا أو عموديًا أو قطريًا.';

  @override
  String get howToC4Tip =>
      'العب في العمود الأوسط. يدخل في صفوف رباعية أكثر من أي عمود آخر.';

  @override
  String get howToCheckers1 =>
      'تتحرك القطع مربعًا واحدًا قطريًا للأمام. اضغط على القطعة، ثم على مكانها الجديد.';

  @override
  String get howToCheckers2 =>
      'اقفز فوق قطعة الخصم لتأخذها. إن استطعت القفز فهو إجباري. القطعة التي عليها القفز تظهر حولها حلقة.';

  @override
  String get howToCheckers3 =>
      'هبطت في مكان تستطيع منه القفز مجددًا؟ تابع. نقلة واحدة قد تأخذ عدة قطع.';

  @override
  String get howToCheckers4 =>
      'إذا وصلت قطعتك إلى الطرف الآخر تصبح ملكًا. والملوك يتحركون للخلف أيضًا، لكن مربعًا واحدًا فقط في كل مرة.';

  @override
  String get howToCheckersWin =>
      'تفوز إذا أخذت كل قطع خصمك أو تركته بلا نقلة. وإذا لعب كل منكما 40 نقلة بلا أسر ولا تحريك قطعة عادية، فهو تعادل.';

  @override
  String get howToCheckersTip =>
      'أبقِ صفك الأخير في مكانه. هذا يمنعهم من تتويج ملوك.';

  @override
  String get howToReversi1 =>
      'ضع قرصك بحيث تُحاصَر أقراص خصمك في خط بين قرصين لك. كل نقلة يجب أن تحاصر قرصًا واحدًا على الأقل.';

  @override
  String get howToReversi2 =>
      'كل قرص محاصر ينقلب إلى لونك، وفي كل الاتجاهات دفعة واحدة.';

  @override
  String get howToReversi3 =>
      'لا توجد نقلة متاحة؟ يُتخطّى دورك. وعندما لا يستطيع أحد اللعب، يفوز صاحب أكثر الأقراص.';

  @override
  String get howToReversiTip =>
      'استولِ على الزوايا. القرص في الزاوية لا يمكن قلبه أبدًا.';

  @override
  String get howToDots1 => 'تناوبوا على رسم خط بين نقطتين.';

  @override
  String get howToDots2 => 'أغلق مربعًا ويصبح لك. وتلعب مرة أخرى!';

  @override
  String get howToDots3 =>
      'انتبه للضلع الثالث في أي مربع. رسمه يعني أنك تهديه للاعب التالي.';

  @override
  String get howToDotsWin => 'عند رسم آخر خط، يفوز صاحب أكثر المربعات.';

  @override
  String get howToChess1 =>
      'اضغط على قطعة لترى أين يمكنها الذهاب، ثم اضغط على مربع.';

  @override
  String get howToChess2 => 'تحرك إلى مربع قطعة الخصم لتأخذها.';

  @override
  String get howToChess3 =>
      'أوصل جنديًا إلى الصف الأخير ليصبح وزيرًا، أو أي قطعة تختارها.';

  @override
  String get howToChess4 =>
      'الكش يعني أن الملك مهدَّد ويجب أن تنقذه. لا مخرج؟ كش مات وانتهت اللعبة. لا نقلة متاحة لكن ملكك ليس في كش؟ إنه تعادل.';

  @override
  String get howToChessTip => 'قبل كل نقلة، انظر ماذا يستطيع خصمك أن يأخذ.';

  @override
  String get howToLiars1 => 'يرمي الجميع 5 نرود سرًّا. ولا ترى إلا نردك.';

  @override
  String get howToLiars2 =>
      'في دورك، زايِد بأنّ هناك على الأقل عددًا معيّنًا من وجهٍ ما على الطاولة كلها، بحساب نرود الجميع. مثلًا «أربعة 3».';

  @override
  String get howToLiars3 =>
      'الـ1 جوكر: يُحسب كأي وجه. إلا إذا كانت المزايدة على الـ1 نفسه.';

  @override
  String get howToLiars4 =>
      'على اللاعب التالي أن يرفع: عددًا أكبر، أو العدد نفسه لوجه أعلى…';

  @override
  String get howToLiars5 => '…أو يقول: كذّاب! يكشف الجميع نرودهم ويبدأ العدّ.';

  @override
  String get howToLiars6 =>
      'العدد يساوي المزايدة أو أكثر؟ من قال «كذّاب» يخسر نردًا. أقل؟ صاحب المزايدة يخسر نردًا.';

  @override
  String get howToLiars7 => 'إذا نفدت نرودك تخرج. آخر من يبقى معه نرد يفوز.';

  @override
  String get howToLiarsClock =>
      '45 ثانية لكل دور. إذا انتهى الوقت تلعب اللعبة عنك.';

  @override
  String get howToLiarsTip =>
      'عُدّ زهراتك أولًا. لأن الواحد جوكر، فحوالي ثلث زهرات الآخرين يطابق الوجه الذي تزايد عليه.';

  @override
  String get howToImposter1 =>
      'الجميع يحصلون على الكلمة السرية نفسها، ما عدا المحتال: يعرف الفئة فقط.';

  @override
  String get howToImposter2 =>
      'تناوبوا على إعطاء تلميح قصير. أثبت أنك تعرف الكلمة دون أن تكشفها.';

  @override
  String get howToImposterVoice =>
      'في الوضع الصوتي: قل تلميحك بصوت عالٍ في المكالمة، ثم اضغط تم.';

  @override
  String get howToImposter3 =>
      'بعدها يصوّت الجميع على من يظنونه المحتال، أو يتخطّون التصويت.';

  @override
  String get howToImposter4 =>
      'انكشف؟ للمحتال فرصة أخيرة: إن خمّن الكلمة يخطف الفوز. صوّتوا على الشخص الخطأ، أو تعادلت الأصوات، أو تخطّى كثيرون التصويت؟ يفوز المحتال.';

  @override
  String get howToRace1 => 'يحصل الجميع على اللغز الجديد نفسه في اللحظة نفسها.';

  @override
  String get howToRace2 => 'حلّه على هاتفك. شريطك يُري الجميع كم اقتربت.';

  @override
  String get howToRace3 => 'أول من ينهي يفوز. أمامك 10 دقائق.';

  @override
  String get howToLive1 =>
      'الجميع يلعبون في الوقت نفسه. عندما يضغط الجميع على أنا جاهز، تبدأ اللعبة.';

  @override
  String get howToLive2 =>
      'خرج أحدهم من اللعبة؟ تتوقف للجميع. أمامه دقيقتان للعودة، وإلا يخسر بالانسحاب.';

  @override
  String get howToLive3 =>
      'يمكن لبقية المحادثة المشاهدة. يمكنهم طلب مقعد، ويمكن للاعب أن يتنازل عن مقعده.';

  @override
  String get howToTurns1 =>
      'قم بحركتك، ثم اضغط أرسل الحركة. ستظهر في المحادثة كرسالة.';

  @override
  String get howToTurns2 =>
      'لكل حركة يومان. نذكّره بعد 20 ساعة، وبعد 12 ساعة من الصمت يمكنك تذكيره بنفسك.';

  @override
  String get howToTurns3 =>
      'لا حركة خلال يومين؟ تُحسب خسارة. حتى 3 ألعاب في الوقت نفسه لكل محادثة.';

  @override
  String momentActivityGamesSolvedAll(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
    );
    return '$name حلّ ألعابًا: $_temp0';
  }

  @override
  String momentActivityGamesSolvedSome(int count, String name, int solved) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
    );
    return '$name حلّ $solved من $_temp0';
  }

  @override
  String momentActivityGamesPlayed(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
    );
    return '$name لعب ألعابًا: $_temp0';
  }

  @override
  String momentActivityHighlightsPosted(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
    );
    return '$name نشر لحظات: $_temp0';
  }

  @override
  String podiumSharedBy(int count, String names, int place) {
    return 'المركز $place، يتشاركه $count: $names';
  }

  @override
  String get myBestsLabel => 'أفضل أرقامي';

  @override
  String recordsSharedBy(int count, String name) {
    return '$name +$count';
  }

  @override
  String get reportSheetDisclosureMessage =>
      'يؤدي الإبلاغ إلى إرسال هذه الرسالة وآخر بضع رسائل في هذه الدردشة إلى مشرفي MonkeyHub لمراجعتها. لن يعرف الشخص أنك أبلغت عنه.';

  @override
  String get reportSheetDisclosureUser =>
      'يؤدي الإبلاغ إلى إرسال آخر بضع رسائل بينك وبين هذا الشخص إلى مشرفي MonkeyHub لمراجعتها. لن يعرف أنك أبلغت عنه.';

  @override
  String get reportSheetDisclosureRoom =>
      'يؤدي الإبلاغ إلى إرسال آخر بضع رسائل في هذه المجموعة إلى مشرفي MonkeyHub لمراجعتها. لن يعرف أحد هنا أنك أبلغت عنها.';

  @override
  String get reportSheetAlsoBlock => 'حظر هذا الشخص أيضًا';

  @override
  String get reportSentReviewed =>
      'شكرًا. يراجع مشرفونا البلاغات خلال 24 ساعة.';

  @override
  String get reportSentAndBlocked =>
      'شكرًا. يراجع مشرفونا البلاغات خلال 24 ساعة. لقد حظرت هذا الشخص.';

  @override
  String get reportTooMany => 'لقد أرسلت بلاغات كثيرة. حاول مرة أخرى بعد قليل.';

  @override
  String get reportFailed => 'تعذر إرسال البلاغ. حاول مرة أخرى.';

  @override
  String get riReportPerson => 'الإبلاغ عن هذا الشخص';

  @override
  String get riReportGroup => 'الإبلاغ عن هذه المجموعة';

  @override
  String get moderationActionRemoveMessage => 'إزالة الرسالة';

  @override
  String get moderationActionBan => 'حظر المستخدم';

  @override
  String get moderationActionUnban => 'إلغاء حظر المستخدم';

  @override
  String get moderationActionDismiss => 'تجاهل البلاغ';

  @override
  String get moderationConfirmRemoveTitle => 'إزالة هذه الرسالة؟';

  @override
  String get moderationConfirmRemoveBody =>
      'ستُحذف لدى الجميع في المحادثة. تحتفظ بطاقة البلاغ بنسختها.';

  @override
  String get moderationActionRemoveContent => 'إزالة اللحظة أو التعليق';

  @override
  String get moderationConfirmRemoveContentTitle =>
      'هل تريد إزالة هذه اللحظة أو التعليق؟';

  @override
  String get moderationConfirmRemoveContentBody =>
      'سيُحذف للجميع مع ردوده ووسائطه. تحتفظ بطاقة البلاغ بنسختها.';

  @override
  String get moderationConfirmBanTitle => 'حظر هذا الحساب؟';

  @override
  String get moderationConfirmBanBody =>
      'سيُسجَّل خروجه من كل مكان، ولن يتمكن من تسجيل الدخول مجددًا، وسيختفي من البحث ويغادر كل الغرف العامة. يمكنك إلغاء الحظر من هذه البطاقة.';

  @override
  String get moderationActionDone => 'تم';

  @override
  String get moderationActionFailed => 'لم تكتمل العملية. حاول مرة أخرى.';

  @override
  String get moderationCantBan => 'لا يمكن حظر المشرفين أو حسابات النظام.';

  @override
  String get messageFilterBlocked =>
      'لا يمكن إرسال هذه الرسالة لأنها قد تحتوي على لغة غير لائقة.';

  @override
  String get nameInappropriate =>
      'قد يحتوي هذا الاسم على لغة غير لائقة. يُرجى اختيار اسم آخر.';

  @override
  String get authErrorAccountSuspended =>
      'تم تعليق حسابك لمخالفته شروط الاستخدام.';

  @override
  String get authErrorLastGuardian =>
      'أنت الوصي الوحيد على حساب طفل. أضف وصيًا آخر أو احذف حساب الطفل أولاً.';

  @override
  String get authSuspendedDeleteAction => 'حذف حسابي';

  @override
  String get authSuspendedDeleteFailed =>
      'تعذّر علينا حذف حسابك من هنا. تواصل مع الدعم وسنتولى الأمر.';

  @override
  String get termsConsentPrefix => 'أوافق على ';

  @override
  String get termsConsentLink => 'شروط الاستخدام (EULA)';

  @override
  String get termsConsentSuffix =>
      ' وأدرك أنه لا تسامح إطلاقًا مع المحتوى المسيء أو المستخدمين المسيئين.';

  @override
  String get termsConsentSemanticLabel => 'الموافقة على شروط الاستخدام';

  @override
  String get termsMustAccept => 'يُرجى الموافقة على شروط الاستخدام للمتابعة.';

  @override
  String get termsSheetTitle => 'شروط الاستخدام';

  @override
  String get termsSheetBody =>
      'لمواصلة استخدام MonkeyHub، يُرجى الموافقة على شروط الاستخدام. لا مكان هنا للمحتوى المسيء أو السلوك المسيء، ويراجع مشرفونا المحتوى المُبلَّغ عنه.';

  @override
  String get termsSheetAccept => 'موافق ومتابعة';

  @override
  String get termsAcceptFailed => 'تعذر الحفظ. حاول مرة أخرى.';

  @override
  String get settingsHubContactSupport => 'التواصل مع الدعم';

  @override
  String get reportSheetDisclosureMoment =>
      'يؤدي الإبلاغ إلى إرسال هذه اللحظة إلى مشرفي MonkeyHub لمراجعتها. لن يعرف الشخص أنك أبلغت عنه.';

  @override
  String get reportSheetDisclosureComment =>
      'يؤدي الإبلاغ إلى إرسال هذا التعليق إلى مشرفي MonkeyHub لمراجعته. لن يعرف الشخص أنك أبلغت عنه.';

  @override
  String get sendLimitRateLimited =>
      'أنت ترسل بسرعة كبيرة. انتظر قليلًا ثم حاول مرة أخرى.';

  @override
  String get sendLimitStorageFull =>
      'مساحة التخزين لديك ممتلئة. احذف بعض الصور أو الملفات التي أرسلتها لتوفير مساحة.';

  @override
  String get sendLimitFileTooLarge =>
      'هذا الملف كبير جدًا بحيث لا يمكن إرساله.';

  @override
  String get sendLimitMessageTooLong =>
      'هذه الرسالة طويلة جدًا. جرّب تقسيمها إلى عدة رسائل.';

  @override
  String get limitTooOften => 'أنت تقوم بذلك كثيرًا. حاول مرة أخرى بعد قليل.';

  @override
  String get limitRoomFull => 'هذه الغرفة ممتلئة.';

  @override
  String get limitRemovedFromRoom =>
      'تمت إزالتك من هذه الغرفة. يمكن لأحد المشرفين دعوتك مرة أخرى.';

  @override
  String get limitTooManyRooms =>
      'أنت في عدد كبير جدًا من الغرف. غادر غرفة لم تعد تستخدمها أولًا.';

  @override
  String get limitRoomTextTooLong =>
      'هذا الاسم أو الوصف طويل جدًا. اجعل الأسماء أقل من 100 حرف والأوصاف أقل من 500.';

  @override
  String get limitNotYourFile =>
      'لا يمكن استخدام هذا الملف. اختره مرة أخرى وأعد المحاولة.';

  @override
  String get limitDeviceLoginBusy =>
      'رموز تسجيل الدخول مشغولة الآن. حاول مرة أخرى بعد دقيقة.';

  @override
  String get limitRequestMessages => 'لا يمكنك إرسال المزيد حتى يقبل طلبك.';

  @override
  String get mediaSendViewOnceTip => 'يمكنه فتحها مرة واحدة فقط';

  @override
  String get mediaSendSpoilerTip => 'مخفية تحت الغبار حتى يلمسها';

  @override
  String get mediaSendSpoilerNote => 'مخفية حتى اللمس';

  @override
  String get mediaSendSpoilerOnSemanticLabel => 'سبويلر: مفعّل';

  @override
  String get mediaSendSpoilerOffSemanticLabel => 'سبويلر: معطّل';

  @override
  String get mediaSpoilerRevealSemanticLabel => 'سبويلر. المس للإظهار';

  @override
  String get voiceTranscriptShow => 'عرض النص';

  @override
  String get voiceTranscriptHide => 'إخفاء النص';

  @override
  String voiceTranscriptCellularPrompt(String size) {
    return 'يكتب Bartleby النصوص على هاتفك. يحتاج أولًا إلى تنزيل لمرة واحدة بحجم $size.';
  }

  @override
  String voiceTranscriptDownloadAction(String size) {
    return 'تنزيل $size';
  }

  @override
  String voiceTranscriptDownloading(String received, String total) {
    return 'يستعد Bartleby · $received من $total';
  }

  @override
  String get voiceTranscriptOneTimeNote =>
      'مرة واحدة فقط. بعدها تعمل النصوص دون اتصال.';

  @override
  String get voiceTranscriptCancel => 'إلغاء';

  @override
  String get voiceTranscriptWorking => 'جارٍ التحويل إلى نص…';

  @override
  String get voiceTranscriptFailedNetwork => 'تعذّر تنزيل نموذج الكلام.';

  @override
  String voiceTranscriptFailedStorage(String size) {
    return 'لا توجد مساحة كافية. يحتاج نموذج الكلام إلى $size.';
  }

  @override
  String get voiceTranscriptFailedAudio => 'تعذّرت قراءة هذه الرسالة الصوتية.';

  @override
  String get voiceTranscriptFailed => 'تعذّر تحويل هذه الرسالة الصوتية إلى نص.';

  @override
  String get voiceTranscriptRetry => 'إعادة المحاولة';

  @override
  String get voiceTranscriptNoSpeech => 'لا يوجد كلام في هذه الرسالة الصوتية.';

  @override
  String get voiceTranscriptOnDevice => 'حُوِّل إلى نص على هذا الجهاز';

  @override
  String voiceTranscriptLanguageOnDevice(String language) {
    return '$language · على هذا الجهاز';
  }

  @override
  String get voiceTranscriptCopy => 'نسخ';

  @override
  String get voiceTranscriptCopied => 'تم نسخ النص';

  @override
  String get storageKindSpeechModel => 'نصوص الرسائل الصوتية';

  @override
  String get voiceTranscriptBuiltInCredit => 'التعرّف على الكلام من Apple';

  @override
  String voiceTranscriptBuiltInLanguageCredit(String language) {
    return '$language · التعرّف على الكلام من Apple';
  }

  @override
  String get voiceTranscriptUpgradeLink => 'نصوص أفضل';

  @override
  String voiceTranscriptUpgradeOffer(String size) {
    return 'اللغة أو الكلمات خاطئة؟ بتنزيل لمرة واحدة بحجم $size، يتعرّف Bartleby على اللغة المنطوقة بنفسه ويعرف قرابة 100 لغة. بعدها يعمل دون اتصال.';
  }

  @override
  String get voiceTranscriptNotNow => 'ليس الآن';

  @override
  String get appOnlyGetApp => 'احصل على التطبيق';

  @override
  String get appOnlyScanHint => 'امسح الرمز بهاتفك للحصول على التطبيق';

  @override
  String get appOnlyBlockedInApp => 'لقطات الشاشة وتسجيلها محظورة في التطبيق';

  @override
  String get appOnlyViewOnceTitle => 'تُفتح في التطبيق';

  @override
  String appOnlyViewOnceBody(String platform) {
    String _temp0 = intl.Intl.selectLogic(platform, {
      'web':
          'لا يستطيع متصفحك منع لقطات الشاشة، لذا لا تُفتح رسائل المشاهدة الواحدة هنا. افتحها في MonkeyHub على هاتفك، أو على كمبيوتر Mac أو Windows.',
      'other':
          'لا يستطيع Linux منع لقطات الشاشة، لذا لا تُفتح رسائل المشاهدة الواحدة هنا. افتحها في MonkeyHub على هاتفك، أو على كمبيوتر Mac أو Windows.',
    });
    return '$_temp0';
  }

  @override
  String get appOnlyViewOnceSealed => 'تبقى مختومة حتى تفتحها';

  @override
  String get appOnlySecretTitle => 'الغرف السرية تُفتح في التطبيق';

  @override
  String appOnlySecretBody(String platform) {
    String _temp0 = intl.Intl.selectLogic(platform, {
      'web':
          'لا يستطيع متصفحك منع لقطات الشاشة، لذا تبقى الغرف السرية مغلقة هنا ولا يُحمَّل منها شيء. افتح هذه الغرفة في MonkeyHub على هاتفك، أو على كمبيوتر Mac أو Windows.',
      'other':
          'لا يستطيع Linux منع لقطات الشاشة، لذا تبقى الغرف السرية مغلقة هنا ولا يُحمَّل منها شيء. افتح هذه الغرفة في MonkeyHub على هاتفك، أو على كمبيوتر Mac أو Windows.',
    });
    return '$_temp0';
  }

  @override
  String get appOnlySecretTimers => 'الرسائل هنا تختفي في موعدها رغم ذلك';

  @override
  String get appOnlySecretPreview => 'افتح التطبيق للقراءة';

  @override
  String get appOnlyTranscriptTitle => 'النصوص';

  @override
  String get appOnlyTranscriptBody =>
      'يحوّل MonkeyHub الرسائل الصوتية إلى نص على جهازك أنت، لا على خادم. لا يستطيع المتصفح فعل ذلك، لذا النصوص متاحة في التطبيق على هاتفك أو كمبيوترك.';

  @override
  String get appOnlyTranscriptOnDevice => 'تُنشأ على جهازك مباشرة';

  @override
  String get appOnlyTranscriptNoUpload =>
      'لا يُرسل أي صوت إلى أي مكان لتحويله إلى نص';

  @override
  String get appOnlyTranscriptOffline => 'يعمل دون اتصال بعد إعداده';

  @override
  String get liveCallChipVoice => 'مكالمة صوتية';

  @override
  String get liveCallChipVideo => 'مكالمة فيديو';

  @override
  String get companionBartlebyTagline => 'يحوّل الرسائل الصوتية إلى نص';

  @override
  String get companionBartlebyBlurb =>
      'يستمع Bartleby إلى الرسائل الصوتية ويحوّلها إلى نص، هنا على هاتفك. لا الصوت ولا الكلمات تغادر هاتفك أبدًا.';

  @override
  String get bartlebyQuote => '«أفضّل ألّا أرسل صوتك إلى أي مكان.»';

  @override
  String get bartlebyStatusEveryLanguage => 'جاهز لقرابة 100 لغة';

  @override
  String get bartlebyStatusBuiltInOnly => 'اللغات المدمجة فقط';

  @override
  String get bartlebyBuiltInHeader => 'لغات جاهزة دون تنزيل';

  @override
  String get bartlebyBuiltInFooter =>
      'جهازك يملك هذه اللغات مسبقًا لـ Siri والإملاء، لذا يستخدمها Bartleby أولًا دون تنزيل أي شيء. اللغات الأخرى تحتاج إلى التنزيل أدناه.';

  @override
  String get bartlebyBuiltInFooterModel =>
      'التنزيل أدناه يشمل هذه اللغات أيضًا، لذا يستخدمه Bartleby مع كل رسالة صوتية.';

  @override
  String get bartlebyBuiltInNone => 'لا توجد لغات على هذا الجهاز بعد';

  @override
  String get bartlebyModelTitle => 'نصوص أفضل';

  @override
  String get bartlebyModelDetail =>
      'يتعرّف على اللغة المنطوقة. قرابة 100 لغة، ويعمل دون اتصال';

  @override
  String bartlebyModelInstalled(String size) {
    return 'على هذا الجهاز · $size';
  }

  @override
  String bartlebyStorageUsed(String size) {
    return 'يشغل Bartleby مساحة $size على هذا الجهاز، بما فيها النصوص المحفوظة.';
  }

  @override
  String get bartlebyStorageEmpty =>
      'لا يشغل Bartleby أي مساحة على هذا الجهاز.';

  @override
  String get bartlebyCellularTitle => 'هل تريد التنزيل عبر بيانات الجوال؟';

  @override
  String bartlebyCellularBody(String size) {
    return 'هذا تنزيل لمرة واحدة بحجم $size. انتظر شبكة Wi-Fi إن كنت تفضّل عدم استهلاك باقة بياناتك.';
  }

  @override
  String get bartlebyRemoveKeepsTranscripts =>
      'تبقى النصوص الموجودة لديك محفوظة.';

  @override
  String get settingsSearchKwTranscripts => 'نص، رسالة صوتية، كلام، إملاء';

  @override
  String get chatGameTakeback => 'تراجع';

  @override
  String chatGameTakebackFrom(String name) {
    return 'يطلب $name التراجع عن آخر نقلة له';
  }

  @override
  String get chatGameTakebackAsked => 'أُرسل طلب التراجع';

  @override
  String chatGameTakebacksLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تبقّى $count تراجع',
      many: 'تبقّى $count تراجعًا',
      few: 'تبقّت $count تراجعات',
      two: 'تبقّى تراجعان',
      one: 'تبقّى تراجع واحد',
      zero: 'لم يتبقَّ لك أي تراجع',
    );
    return '$_temp0';
  }

  @override
  String get chatGameNoTakebacksHard => 'لا تراجع أمام الروبوت الصعب';

  @override
  String get chatGameYouResigned => 'لقد استسلمت';

  @override
  String get chatGameDrawAgreed => 'تم الاتفاق على التعادل';

  @override
  String chatGameBotPlaysOn(String name) {
    return 'يريد $name مواصلة اللعب';
  }

  @override
  String get chatGameDrawTooSoon => 'يمكنك عرض التعادل مجددًا بعد نقلتين';

  @override
  String get chatGameTakebackTooSoon => 'سبق رفض التراجع عن هذه النقلة';

  @override
  String get chatGameMoves => 'النقلات';

  @override
  String get chatGameBackToGame => 'العودة إلى النقلة الحالية';

  @override
  String get chatGameNoMovesYet => 'لا نقلات بعد';

  @override
  String get chatGameKeysReplay => 'استخدم ← و→ لاستعراض النقلات';

  @override
  String get partyLdAcesRule =>
      'للمزايدة على الـ1 يكفي النصف مقرّبًا للأعلى. وللخروج من الـ1 تحتاج الضعف زائد واحد.';

  @override
  String get partyRaceGrace => 'عندما ينهي أحدهم، يبقى أمام الباقين دقيقتان.';

  @override
  String get partyImposterClueRule => 'ليس الكلمة نفسها أبدًا';

  @override
  String get partyLdKeys => '↑ ↓ العدد · 1–6 الوجه · Enter مزايدة · L كذّاب';

  @override
  String get partyImposterVoteKeys => 'اضغط رقم الصف للتصويت · 0 للتخطي';

  @override
  String get dailyStandingsHintedNote =>
      'الحلول التي استُخدم فيها تلميح تأتي بعد الحلول التي لم تستخدم أي تلميح';

  @override
  String get howToPatchesControls =>
      'اسحب من زاوية إلى زاوية لتقصّ رقعة. اسحب جانب الرقعة أو زاويتها لتغيّر شكلها. اضغط على رقعة لإزالتها.';

  @override
  String dropConfirmTitle(String room) {
    return 'هل تريد الإرسال إلى $room؟';
  }

  @override
  String dropConfirmMore(int count) {
    return 'و$count أخرى';
  }

  @override
  String get dropConfirmSend => 'إرسال';

  @override
  String get streakCelebrateLabel => 'أيام متتالية';

  @override
  String get streakCelebrateTier1 => 'أنت في تقدم';

  @override
  String get streakCelebrateTier2 => 'مشتعل';

  @override
  String get streakCelebrateTier3 => 'لا يمكن إيقافك';

  @override
  String get streakCelebrateTier4 => 'أسطوري';

  @override
  String get powerSavingHeader => 'توفير الطاقة';

  @override
  String get powerSavingAuto => 'تلقائي';

  @override
  String get powerSavingAutoOffSub =>
      'يهدئ الحركات عند تشغيل وضع الطاقة المنخفضة أو توفير البطارية';

  @override
  String get powerSavingAutoOnSub => 'قيد التشغيل الآن: هاتفك يوفر الطاقة';

  @override
  String get powerSavingNever => 'أبدًا';

  @override
  String get powerSavingNeverSub => 'حركة كاملة حتى في وضع الطاقة المنخفضة';

  @override
  String get powerSavingAlways => 'دائمًا';

  @override
  String get powerSavingAlwaysSub =>
      'حركة هادئة لتوفير البطارية مهما كان إعداد الهاتف';

  @override
  String get profileDeletedAccount => 'حساب محذوف';
}
