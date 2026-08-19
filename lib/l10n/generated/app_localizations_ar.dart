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
      'تعذّر إرسال الطلب الآن — حاول مرة أخرى';

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
  String get roomScreenDeleteConfirmButton => 'حذف للجميع';

  @override
  String get roomScreenJumpFailedSnack => 'تعذّر الانتقال إلى تلك الرسالة';

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
  String get roomScreenPinLimitSnack =>
      'التثبيت ممتلئ — ألغِ تثبيت رسالة أولاً';

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
  String get profileScreenEmailHint => 'اختياري — لن يُعرض لأي شخص';

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
      'لقد أرسل لك طلبًا بالفعل — تحقّق من الطلبات.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'تم إرسال الطلب بالفعل.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'لقد حظرت هذا المستخدم — قم بإلغاء الحظر عنه أولًا.';

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
      'عرض محدود — يشارك المزيد مع أصدقائه.';

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
      'شريط الكتابة، والرؤوس، وأزرار الاتصال — أي عنصر يظهر فوق النص لا فوق المحتوى القابل للتمرير';

  @override
  String get glassScreenMatchBottomBar => 'مطابقة الشريط السفلي';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'معدَّل — احفظه كمظهر جديد أو أعد تعيينه';

  @override
  String get glassScreenCustomPresetName => 'مخصص';

  @override
  String get glassScreenUnsavedSubtitle =>
      'غير محفوظ — امنحه اسمًا للاحتفاظ به';

  @override
  String get glassScreenSaveDialogTitle => 'احفظ هذا المظهر باسم';

  @override
  String get glassScreenNoRoomToast => 'لا توجد مساحة — احذف مظهرًا أولاً';

  @override
  String get glassScreenRenameDialogTitle => 'إعادة تسمية';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'حذف $name؟';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'يبقى المظهر على الشاشة — فقط يفقد اسمه.';

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
  String get glassScreenBackdropMsgDilan => 'أرسل صور السطح — البلاط كله متشقق';

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
      'لا تزال قيد الإرسال — حاول مجدداً بعد قليل';

  @override
  String get threadOverlayCopiedToast => 'تم النسخ';

  @override
  String get threadOverlayNameCopiedToast => 'تم نسخ الاسم';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'تم نسخ الإحداثيات';

  @override
  String get threadOverlayPinLimitToast =>
      'عدد الرسائل المثبّتة كبير جداً — ألغِ تثبيت واحدة أولاً';

  @override
  String get threadOverlayPinFailedToast => 'تعذّر تثبيت الرسالة';

  @override
  String get threadOverlayReportedToast => 'تم الإبلاغ';

  @override
  String get threadOverlayUnavailable => 'السلسلة غير متاحة';

  @override
  String get roomInfoScreenNameRequiredError => 'الاسم مطلوب';

  @override
  String get roomInfoScreenSavedSnackbar => 'تم الحفظ';

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
    return 'سيفقد $peerName هذه المحادثة أيضاً — تختفي كل رسالة لديكما. هذا إجراء نهائي.';
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
  String get roomInfoScreenDescriptionHint => 'سطر واحد عن الغرفة…';

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
      'هذه الغرفة محمية بكلمة مرور. لا تُعرض كلمة المرور الحالية لأسباب أمنية — أدخل كلمة جديدة لاستبدالها.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'استبدال كلمة المرور…';

  @override
  String get roomInfoScreenSetPasswordHint => 'أقفل بكلمة مرور…';

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
  String get roomInfoScreenLoadingMembers => 'جارٍ تحميل الأعضاء…';

  @override
  String get roomInfoScreenOwnerBadge => 'المالك';

  @override
  String get roomInfoScreenSaveButton => 'حفظ';

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
  String get childPolicyScreenAskToAddOffDesc => 'العائلة فقط — لا طلبات جديدة';

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
      'تمت الإضافة — الطلب في طريقه';

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
      'تعذّر حذف الحساب — حاول مرة أخرى';

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
      'تعذّرت إضافته — حاول مرة أخرى';

  @override
  String get childPolicyScreenErrorCannotAddSelf => 'هذا اسم مستخدم الطفل نفسه';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'لا يمكن للطفل أن يكون ولي أمر';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'تعذّر تنفيذ ذلك — حاول مرة أخرى';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'لا بد أن يعتني بهم أحد — أضف وليّ أمر آخر أولاً';

  @override
  String get childPolicyScreenErrorNotYours => 'ليس من حقك تغيير هذا';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'لا يوجد حساب باسم المستخدم هذا';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'سيصبح حسابًا عاديًا بكلمة المرور هذه، ويفقد جميع أولياء الأمور كل قدرة على الاطلاع. لا عودة عن هذا القرار — سيتعيّن دعوته من جديد كأي شخص آخر.';

  @override
  String get childPolicyScreenGraduateCta => 'تخريج';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'يحتفظ بكل شيء ويحصل على كلمة مرور. تفقد أنت كل قدرة على الاطلاع. لا رجعة في ذلك.';

  @override
  String get childPolicyScreenGraduateDangerLabel => 'تخريج إلى حساب كامل';

  @override
  String get childPolicyScreenGraduateFailed => 'تعذّر تخريجه — حاول مرة أخرى';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'تخريج $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'كلمة مرور له';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'سحب الإذن عن غرفة يُخرجه منها أيضًا. وسحب الإذن عن شخص يحذف محادثتهما كذلك — لدى الطرفين.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'يمكن لأي شخص هنا الموافقة وتغيير الإعدادات ورؤية كل شيء. يمكن لأي منهم التصرف بمفرده — لا شيء ينتظر البقية.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'تمت الإضافة — يمكنه الاعتناء به الآن';

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
      'يمكن إضافة أي شخص هنا دون سؤالك مجددًا — أيًا كان من يبدأ الأمر.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'معطّلة دائمًا للأطفال. أما اكتشاف — قائمة الغرف التي يملكها أشخاص لا تعرفهم — فمخفية بالكامل ولا يمكن تفعيلها. الغرف التي يُدعى إليها لا تزال تعمل بشكل طبيعي.';

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
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count فيها';
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
    return 'أنتَ ولي الأمر الوحيد لـ$name، لذا لا يمكنك التنحي وحسب — أضف وليّ أمر آخر أولاً، أو استخدم أحد هذه الخيارات.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'التنحي';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'ستفقد كل قدرة على متابعة حساب $name — طلباته، وأشخاصه، وغرفه. سيستمر باقي أولياء الأمور في رعايته.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'إيقاف الإشراف';

  @override
  String get childPolicyScreenStopSupervisingHeadline => 'إيقاف الإشراف؟';

  @override
  String get childPolicyScreenTakeBackFailed => 'تعذّر السحب — حاول مرة أخرى';

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
      'لم تحفظ شيئًا بعد. اضغط مطوّلًا على رسالة واختر حفظ.\n\nما تحفظه هنا يخصّك وحدك — أما الرسالة المثبّتة فتراها الغرفة كلها.';

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
  String get spoilerRevealHint => 'سبويلر — فعِّل لإظهار النص المخفي';

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
      'فات أوان التعديل — لا يمكن تعديل الرسائل إلا خلال 15 دقيقة.';

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
    return 'نشط — $name';
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
  String callScreenStatusRinging(Object kind) {
    return '$kind · جارٍ الاتصال…';
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
  String get callScreenControlFlip => 'تبديل';

  @override
  String get callScreenControlSpeaker => 'مكبر الصوت';

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
      'لقد حظرت هذا المستخدم — ألغِ الحظر أولاً.';

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
  String get friendRequestDraftScreenHintStartWith => 'شيء لتبدأ به…';

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
  String get discoverScreenYourPeopleLabel => 'أشخاصك';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'لا أحد بعد — ابحث عن أشخاص في الأعلى';

  @override
  String get discoverScreenNoFriendsYet => 'لا أحد بعد';

  @override
  String get discoverScreenSearchRoomsTitle => 'البحث عن غرف';

  @override
  String get discoverScreenSearchRoomsSubtitle => 'ابحث عن غرفة عامة بالاسم';

  @override
  String get discoverScreenPublicRoomsLabel => 'الغرف العامة';

  @override
  String get discoverScreenLoadingRooms => 'يبحث…';

  @override
  String get discoverScreenNoRoomsOpen => 'لا غرف مفتوحة الآن';

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
  String get searchScreenHintPeople => 'ابحث عن أشخاص…';

  @override
  String get searchScreenHintRooms => 'ابحث عن غرف…';

  @override
  String get searchScreenPeoplePromptChild =>
      'اكتب اسم المستخدم كاملاً للعثور على شخص جديد';

  @override
  String get searchScreenPeoplePromptDefault => 'ابحث باسم المستخدم أو الاسم';

  @override
  String get searchScreenNoMatchChild =>
      'لا يوجد تطابق — يحتاج الأشخاص الجدد إلى\nاسم المستخدم كاملاً بالتهجئة الصحيحة';

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
      'تحكم فيما يراه الآخرون — وكيف يمكنهم التواصل معك.';

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
      'تم النسخ — الصقها في مكان آمن';

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
      'ليس الآن — احتفظ بعبارتي الحالية';

  @override
  String get homeScreenProfileSemanticLabel => 'ملفك الشخصي';

  @override
  String homeScreenGreeting(Object name) {
    return 'أهلاً يا $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'غرفة جديدة';

  @override
  String get homeScreenEmptyRoomsMessage => 'لا توجد غرف بعد — أنشئ واحدة';

  @override
  String get groupCallScreenTitleVideo => 'مكالمة فيديو جماعية';

  @override
  String get groupCallScreenTitleVoice => 'مكالمة صوتية جماعية';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '$count في المكالمة';
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
  String get createRoomSheetNameHint => 'سمّها باسم صادق…';

  @override
  String get createRoomSheetDescriptionLabel => 'الوصف · اختياري';

  @override
  String get createRoomSheetDescriptionHint => 'سطر واحد عن الغرفة…';

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
  String get createRoomSheetPasswordHint => 'اقفلها بعبارة مرور…';

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
  String get roomLayoutScreenMonogramLabel => 'الحرف الأول للغرفة';

  @override
  String get roomLayoutScreenMonogramDescription =>
      'حرف كبير باهت يملأ الزاوية الفارغة';

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
  String get audioMessageSwitchToLinkPrompt => 'هذا الحساب لي — تسجيل الدخول';

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
  String get approvalsScreenErrorGeneric => 'تعذّر الحفظ — حاول مرة أخرى';

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
  String get childPairScreenAccountGoneError => 'هذا الحساب لم يعد موجودًا.';

  @override
  String get childPairScreenScanButtonLabel => 'امسح رمزه ضوئيًا';

  @override
  String get childPairScreenNoCameraMessage =>
      'لا توجد كاميرا هنا — أدخل الأرقام الستة بدلاً من ذلك.';

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
      'يتم عرض جزء من هذا الملف — نزّله لرؤية الباقي.';

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
      'تعذّر إنشاء الرمز — حاول مرة أخرى.';

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
    return 'على هاتف $name، افتح تطبيق MonkeyHub وامسح هذا الرمز — أو اكتب الأرقام.';
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
  String get deepOceanThemeEphemeralHint => 'اهمس بشيء سينساه الخادم…';

  @override
  String get deepOceanThemeDefaultHint => 'قل شيئًا…';

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
  String get photoChromeShowInChatSemanticLabel => 'عرض في المحادثة';

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
    return 'سيسجّل هذا خروج $name من هذا الهاتف ويعيده — يعود الهاتف إلى شاشة تسجيل الدخول المعتادة، ويصبح بإمكان أي شخص استخدامه.';
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
      'كبسولة اقتباس بلون مميز، مع شريط ربط وصورة رمزية — المظهر المألوف بطراز واتساب.';

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
      'تعذّر إنشاء الحساب — حاول مرة أخرى.';

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
      'أما كل شخص آخر فيحتاج إلى موافقتك أولاً — سواء الذين يطلب التواصل معهم، أو الذين يطلبون التواصل معه.';

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
      'بدون ذيل — تتماسك مجموعة الرسائل عبر زواياها الداخلية المشدودة فقط.';

  @override
  String get bubbleStyleScreenPillLabel => 'كبسولة';

  @override
  String get bubbleStyleScreenPillDescription =>
      'كبسولات مستديرة بالكامل، متطابقة في كل صف.';

  @override
  String get bubbleStyleScreenSlabLabel => 'كتلة';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'زوايا مربّعة — حادة، مطبوعة، مقصودة.';

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
  String get groupCallBannerPasswordHint => 'عبارة المرور…';

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
  String get discoverListsPeopleTitle => 'أشخاصك.';

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
  String get discoverListsFilterHint => 'تصفية أشخاصك…';

  @override
  String get discoverListsClearFilterSemanticLabel => 'مسح التصفية';

  @override
  String get discoverListsNoOneYet => 'لا أحد بعد';

  @override
  String discoverListsNoMatches(Object query) {
    return 'لا أحد يطابق \"$query\"';
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
      'البلاغات سرية — لن يتم إخطار الشخص الآخر.';

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
      'أنتما صديقان حاليًا — الحظر يلغي هذه الصداقة، لذا ستحتاج إلى إرسال طلب صداقة جديد لإعادة التواصل لاحقًا.';

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
      'كما يمسح محادثتك الخاصة معه بالكامل — تُحذف كل رسالة وتفاعل وملف وسائط.';

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
      'تعذّر إرسال الطلب الآن — حاول مرة أخرى';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'كلمة المرور غير صحيحة';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'تعذّر الانضمام — حاول مرة أخرى';

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
  String get feedBoardLoadFailed =>
      'تعذّر تحميل اللوحة — أعد المحاولة بعد قليل';

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
  String get roomBadgePrivateTooltip => 'بالدعوة فقط — لا تظهر في الاستكشاف';

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
  String get countBadgeCaptureProtectionLabel => 'حماية من التقاط الشاشة';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      'تظهر لقطات الشاشة وتسجيلات الشاشة سوداء بالنسبة للنظام.';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      'عند تسجيل الشاشة أو نسخها، يظهر درع خصوصية فوق التطبيق.';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      'تعمل لقطات الشاشة والتسجيلات بشكل طبيعي خارج الغرف المؤقتة.';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      'تُفعّل الغرف المؤقتة (حجرة الأسرار) هذا دائمًا، بصرف النظر عن الإعداد.';

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
      'لا توجد عبارة استرداد — لن تتمكن من العودة إلى حسابك.';

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
      'أخبرنا بما حدث. تُضاف معلومات التطبيق والجهاز تلقائيًا، ومعها سجل تقني لما كان التطبيق يفعله — وهذا ما يساعدنا في معرفة السبب.';

  @override
  String get reportProblemDescribeLabel => 'ماذا حدث';

  @override
  String get reportProblemDescribeHint => 'الشاشة ترتجف، الأزرار لا تستجيب…';

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
  String get reportProblemSent => 'تم إرسال البلاغ — شكرًا لك!';

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
      'حاليًا معاينة فقط — فقاعات أنظف، اضغط للفتح';

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
      'دقة عالية جدًا — أوضح، يستخدم بيانات أكثر';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'دقة فائقة الوضوح — الأفضل مع اتصال قوي';

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
      'صامت — لن ترى شيئًا إلا عند فتح التطبيق';

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
      'هذا حساب طفل — اطلب من ولي الأمر رمز اقتران.';

  @override
  String get authErrorPairingCodeExpired =>
      'انتهت صلاحية هذا الرمز. اطلب رمزًا جديدًا.';

  @override
  String get authErrorPairingCodeInvalid =>
      'لم يعمل هذا الرمز. ربما يكون قد استُخدم بالفعل.';

  @override
  String get authErrorUseSocialSignIn =>
      'هذا الحساب يسجّل الدخول عبر Apple أو Google — استخدم الأزرار أدناه.';

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
  String get glassKnobHintRimOpacity =>
      'خط الحافة المميز. اجعله صفرًا لسطح بلا حدود.';

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
  String get motionScreenCalmSubtitle => 'تتوقف الزخارف — ولا يتغير شيء آخر';

  @override
  String get momentRailCaptureLabel => 'التقاط';

  @override
  String get momentRailYouLabel => 'أنت';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

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
  String get momentComposerTitle => 'ماذا حدث؟';

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
  String get momentComposerErrorDailyCap =>
      'صارت خمسًا اليوم — أبقِ شيئًا للغد';

  @override
  String get momentComposerErrorNotAllowed => 'أوقف وليّ الأمر مشاركة الصور';

  @override
  String get momentComposerErrorTooLong => 'طويل قليلًا — اختصره';

  @override
  String get momentComposerErrorEmpty => 'أضف صورة أو بضع كلمات';

  @override
  String get momentComposerErrorGeneric => 'تعذّر النشر — حاول مجددًا';

  @override
  String get momentViewerDelete => 'حذف';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who نشر لحظة';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name حصل على $tag';
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
  String momentActivityMoreCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أخرى اليوم',
      many: '$count أخرى اليوم',
      few: '$count أخرى اليوم',
      two: 'اثنان آخران اليوم',
      one: 'واحد آخر اليوم',
      zero: 'لا مزيد اليوم',
    );
    return '$_temp0';
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
  String get puzzleShareCopied => 'تم النسخ — أرسلها إلى صديق';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'لقد حللت لغز اليوم بالفعل';

  @override
  String get puzzleErrorOutOfGuesses => 'لا محاولات متبقية اليوم';

  @override
  String get puzzleErrorGeneric => 'تعذّر الإرسال — حاول مجددًا';

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
      'اليوم يُشارك دائمًا مع الأصدقاء — هذا يفتح كل ما قبله';

  @override
  String get momentComposerVideo => 'فيديو';

  @override
  String get momentComposerErrorTooBig =>
      'هذا الفيديو كبير جدًا — الحد الأقصى 20 ميغابايت';

  @override
  String get momentActivityPostedHighlightSelf => 'نشرت لحظة';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'حصلت على $tag';
  }

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
  String get pointComposerAdd => 'إضافة نقطة';

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
      'نكتة متكررة تحتفظون بنتيجتها. عندما يحدث لك شيء — جيد أو سيئ أو غريب فحسب — تسجّله فيبقى على اللوحة ذلك اليوم.';

  @override
  String get pointsExplainerRuleHonour =>
      'أنت من يمنح نفسه النقاط. لا أحد يتحقق — وهذه هي المتعة، وأصدقاؤك سيخبرونك إن بالغت.';

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
  String get feedBoardGamesOpen => 'كل الألعاب';

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
  String get gameQueensRule => 'تاج واحد في كل صف وعمود ولون — دون تلامس';

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
  String get gameShareCopied => 'تم النسخ — الصقه لصديق';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
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
  String get gameErrorGeneric => 'تعذّر الوصول إلى الألعاب — حاول مجددًا';

  @override
  String get gameInfoOpen => 'كيف تلعب';

  @override
  String get gameInfoLabel => 'كيف تلعب';

  @override
  String get gameInfoRulesLabel => 'القواعد';

  @override
  String get gameInfoControlsLabel => 'التحكّم';

  @override
  String get gameInfoScoringTimed =>
      'الوقت يعمل ما دام اللوح ظاهرًا، ويتوقّف عند الإيقاف أو الخروج. الأسرع يتصدّر قائمة اليوم.';

  @override
  String get gameInfoScoringGuesses => 'النتيجة بعدد المحاولات، لا بالوقت.';

  @override
  String get gameInfoSameForEveryone => 'الجميع يحصل على نفس اللوح اليوم.';

  @override
  String get gameInfoGotIt => 'فهمت';

  @override
  String get gameInfoQueensGoal => 'ضع تاجًا واحدًا في كل صف وعمود ولون.';

  @override
  String get gameInfoQueensRule1 =>
      'ثمانية تيجان: واحد في كل صف وواحد في كل عمود.';

  @override
  String get gameInfoQueensRule2 =>
      'كل كتلة لونية تحصل أيضًا على تاج واحد بالضبط.';

  @override
  String get gameInfoQueensRule3 =>
      'لا يجوز أن يتلامس تاجان — ولا حتى من الزاوية.';

  @override
  String get gameInfoQueensControls =>
      'اضغط المربع مرة لوضع علامة استبعاد، ومرة أخرى للتاج، ومرة ثالثة للمسح.';

  @override
  String get gameInfoTangoGoal => 'املأ الشبكة بالشموس والأقمار.';

  @override
  String get gameInfoTangoRule1 => 'كل صف وعمود يحتوي ثلاث شموس وثلاثة أقمار.';

  @override
  String get gameInfoTangoRule2 =>
      'لا ثلاثة متشابهة متجاورة، أفقيًا أو رأسيًا.';

  @override
  String get gameInfoTangoRule3 =>
      'علامة = بين مربعين تعني تطابقهما، و× تعني اختلافهما.';

  @override
  String get gameInfoTangoControls =>
      'اضغط المربع لشمس، ومرة أخرى لقمر، ومرة ثالثة للمسح. المربعات المطبوعة ثابتة.';

  @override
  String get gameInfoZipGoal => 'ارسم خطًا واحدًا يمرّ بكل مربع.';

  @override
  String get gameInfoZipRule1 => 'ابدأ من 1 وانتهِ عند آخر رقم.';

  @override
  String get gameInfoZipRule2 => 'مُرّ بالأرقام بالترتيب في طريقك.';

  @override
  String get gameInfoZipRule3 => 'كل مربع يُستخدم مرة واحدة بالضبط.';

  @override
  String get gameInfoZipControls => 'اسحب إصبعك للرسم، وارجع فوق الخط لمحوه.';

  @override
  String get gameInfoSudokuGoal => 'املأ الشبكة بالأرقام من 1 إلى 6.';

  @override
  String get gameInfoSudokuRule1 => 'كل صف يستخدم 1 إلى 6 مرة واحدة لكل رقم.';

  @override
  String get gameInfoSudokuRule2 => 'وكذلك كل عمود.';

  @override
  String get gameInfoSudokuRule3 => 'وكذلك كل مربع 2×3.';

  @override
  String get gameInfoSudokuControls =>
      'اضغط مربعًا ثم رقمًا. اضغط الرقم نفسه مجددًا للمسح. وضع الملاحظات يكتب علامات صغيرة بدلًا من ذلك.';

  @override
  String get gameInfoCodeGoal =>
      'اكتشف الشيفرة المخفيّة المكوّنة من أربعة رموز.';

  @override
  String get gameInfoCodeRule1 => 'ست محاولات، والشيفرة لا تكرّر أي رمز.';

  @override
  String get gameInfoCodeRule2 => 'الأخضر يعني الرمز الصحيح في المكان الصحيح.';

  @override
  String get gameInfoCodeRule3 => 'الأصفر يعني الرمز الصحيح في المكان الخطأ.';

  @override
  String get gameInfoCodeControls =>
      'اضغط الرموز لبناء تخمين ثم أرسله. سيخبرك اللوح كم اقتربت.';

  @override
  String get savedMessagesTitle => 'الرسائل المحفوظة';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'لا توجد محادثات تطابق \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'ابحث عن محادثات…';

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
      'المحفوظات هنا كثيرة — ألغِ حفظ واحدة أولاً';

  @override
  String get roomScreenSaveFailedSnack => 'تعذّر حفظ ذلك';

  @override
  String get threadOverlaySaveLimitToast =>
      'المحفوظات هنا كثيرة — ألغِ حفظ واحدة أولاً';

  @override
  String get threadOverlaySaveFailedToast => 'تعذّر حفظ ذلك';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'أنت وحدك من يرى الرسائل التي تحفظها — والرسالة المثبّتة عكس ذلك تمامًا: تراها الغرفة كلها.';

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
      'لن يصلك شيء من هذه المحادثة — لا إشعارات ولا عدّاد غير مقروء.';

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
      'يمكنه مشاركة مكانه، بما في ذلك مباشرةً حتى 8 ساعات';

  @override
  String get childPolicyScreenLocationOffDesc => 'لا يمكنه مشاركة مكانه';

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
    return 'تُرسَل $when.';
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
      'لم يأتِ هذا الإصدار بخادم — وجّهه إلى خادمك';

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
      'معظم الخوادم تجيب على كل شيء من عنوان واحد. املأ هذا فقط إذا كان خادمك يقدّم إجراءات HTTP من مكان آخر.';

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
      'قام مشغّلو MonkeyHub بنقل حركة البيانات إلى خادمهم المنزلي لفترة. كل شيء يعمل كالمعتاد — هذا إجراء مقصود وليس عطلًا.';

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
