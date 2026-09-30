// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => '서버에 연결할 수 없음';

  @override
  String get bootErrorBody => 'Convex가 초기화되지 않았어요.';

  @override
  String get bootErrorRetry => '다시 시도';

  @override
  String get incomingCallNotificationTitle => '수신 전화';

  @override
  String get incomingCallFallbackCaller => '누군가 전화하고 있어요';

  @override
  String get settingsLanguageRowLabel => '언어';

  @override
  String get languageScreenTitle => '언어.';

  @override
  String get languageScreenSubtitle => '앱의 메뉴와 메시지에 사용할 언어를 선택하세요';

  @override
  String get languageOptionSystem => '시스템';

  @override
  String get languageOptionSystemSub => '기기의 언어 설정을 따라요';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => '사용 중';

  @override
  String get languageValueSystem => '시스템';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack => '지금은 요청할 수 없어요 — 다시 시도해 주세요';

  @override
  String get roomScreenGateSendMessages => '여기서 메시지 보내기';

  @override
  String get roomScreenGateSendMedia => '사진이나 음성 메시지 보내기';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return '한 번에 최대 $max개까지';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '메시지 $count개 삭제',
      one: '메시지 $count개 삭제',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      '이 채팅에 있는 모든 사람에게서 삭제돼요. 되돌릴 수 없어요.';

  @override
  String get roomScreenDeleteConfirmButton => '모두에게서 삭제';

  @override
  String get roomScreenJumpFailedSnack => '그 메시지로 이동할 수 없어요';

  @override
  String get roomScreenUnreadDivider => '읽지 않은 메시지';

  @override
  String get roomScreenViewOnceAlreadyViewed => '이 사진은 이미 열어봤어요.';

  @override
  String get roomScreenViewOnceGone => '이 사진은 더 이상 볼 수 없어요.';

  @override
  String get roomScreenViewOnceNetworkError => '그 사진을 불러올 수 없어요.';

  @override
  String get roomScreenFileReadFailedSnack => '그 파일을 읽을 수 없어요';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return '파일은 최대 $size까지예요';
  }

  @override
  String get roomScreenRoomGone => '채팅방이 사라졌어요';

  @override
  String get roomScreenCopiedSnack => '복사됨';

  @override
  String get roomScreenNameCopiedSnack => '이름 복사됨';

  @override
  String get roomScreenPinLimitSnack => '고정 개수가 다 찼어요 — 하나를 먼저 해제하세요';

  @override
  String get roomScreenPinFailedSnack => '고정할 수 없어요';

  @override
  String get roomScreenReportSentSnack => '신고가 비공개로 접수됐어요. 상대방에게는 알리지 않아요.';

  @override
  String get roomScreenDeselectMessageSemantic => '메시지 선택 해제';

  @override
  String get roomScreenSelectMessageSemantic => '메시지 선택';

  @override
  String roomScreenMemberCountBadge(Object count) {
    return '$count명 참여 중';
  }

  @override
  String roomScreenTtlSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count초',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count분',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count시간',
    );
    return '$_temp0';
  }

  @override
  String roomScreenEphemeralNotice(Object ttl) {
    return '이 방은 휘발성 공간이에요. 읽었든 안 읽었든 메시지는 $ttl 후에 사라져요.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '메시지 $count개';
  }

  @override
  String get roomScreenSecretSpaceTitle => '비밀 공간';

  @override
  String get roomScreenSecretSpaceBody =>
      '이 방의 메시지는 휘발성이에요. 방의 보안 정책에 따라 자동으로 삭제돼요.';

  @override
  String get roomScreenAutoDeleteTitle => '자동 삭제';

  @override
  String get roomScreenAutoDeleteVaries => '다양함';

  @override
  String get roomScreenAutoDeleteTimed => '타이머';

  @override
  String get roomScreenNoCaptureTitle => '캡처 방지';

  @override
  String get roomScreenNoCaptureSubtitle => '스크린샷 제한';

  @override
  String get roomScreenMorePrivacyTitle => '훨씬 더 강력한 프라이버시';

  @override
  String get roomScreenMorePrivacySubtitle =>
      '이미 탄탄한 프라이버시 보호에 더해, 추가 보안 기능까지 누려보세요.';

  @override
  String get roomScreenNoMessagesTitle => '메시지 없음';

  @override
  String get roomScreenNoMessagesSubtitle => '메시지를 보내서 대화를 시작해보세요';

  @override
  String get roomScreenViewProfilePictureSemantic => '프로필 사진 보기';

  @override
  String get roomScreenViewRoomPictureSemantic => '방 사진 보기';

  @override
  String get messageBubbleFileFallbackName => '보낸 문서';

  @override
  String get messageBubbleAttachmentStatusFailed => '전송 실패';

  @override
  String get messageBubbleAttachmentStatusSending => '전송 중…';

  @override
  String get messageBubbleViewOnceOpened => '열람함';

  @override
  String get messageBubbleViewOnceExpired => '만료됨';

  @override
  String get messageBubbleViewOnceLabel => '한 번 보기';

  @override
  String get messageBubbleViewOnceTapToView => '탭하여 보기';

  @override
  String get messageBubbleViewOncePhotoLabel => '사진';

  @override
  String get messageBubbleViewOnceSemanticLabel => '한 번 보기 사진, 탭하여 보기';

  @override
  String get messageBubbleRetrySendingSemanticLabel => '다시 전송하기';

  @override
  String get messageBubbleDiscardSemanticLabel => '전송 취소';

  @override
  String get profileScreenAccountSection => '계정';

  @override
  String get profileScreenAddEmailPlaceholder => '이메일 추가';

  @override
  String get profileScreenAddEmailTitle => '이메일을 추가할까요?';

  @override
  String get profileScreenAddNameTitle => '이름을 추가할까요?';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count건 대기 중';
  }

  @override
  String get profileScreenApprovalsLabel => '승인 요청';

  @override
  String get profileScreenApprovalsNothingWaiting => '대기 중인 요청 없음';

  @override
  String get profileScreenApproveAction => '수락';

  @override
  String get profileScreenBlockAction => '차단';

  @override
  String get profileScreenBlockedDmWiped =>
      '차단했고 DM도 삭제했어요. 상대방에게는 알림이 가지 않아요.';

  @override
  String get profileScreenBlockedOnly => '차단했어요. 상대방에게는 알림이 가지 않아요.';

  @override
  String get profileScreenBlockedUsers => '차단한 사용자';

  @override
  String get profileScreenCancelAction => '취소';

  @override
  String get profileScreenCancelRequestAction => '보낸 요청 취소';

  @override
  String get profileScreenChangeAction => '변경';

  @override
  String get profileScreenChangeEmailTitle => '이메일을 변경할까요?';

  @override
  String get profileScreenChangeNameTitle => '이름을 변경할까요?';

  @override
  String get profileScreenChangeProfilePictureSemantic => '프로필 사진 변경';

  @override
  String get profileScreenChangeRecoveryPhrase => '복구 문구 변경';

  @override
  String get profileScreenChooseFromLibrary => '갤러리에서 선택';

  @override
  String get profileScreenCouldNotSaveImage => '이미지를 저장하지 못했어요.';

  @override
  String get profileScreenDeleteAccount => '계정 삭제';

  @override
  String get profileScreenEmailHint => '선택 사항 — 아무에게도 공개되지 않아요';

  @override
  String get profileScreenEmailSectionLabel => '이메일';

  @override
  String get profileScreenErrorAlreadyFriends => '이미 친구예요.';

  @override
  String get profileScreenErrorGeneric => '처리하지 못했어요.';

  @override
  String get profileScreenErrorNotAccepting => '상대방이 지금은 친구 요청을 받지 않고 있어요.';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      '상대방이 이미 나에게 요청을 보냈어요 — 요청 목록을 확인해 보세요.';

  @override
  String get profileScreenErrorRequestAlreadySent => '이미 요청을 보냈어요.';

  @override
  String get profileScreenErrorUnblockFirst => '이 사용자를 차단했어요 — 먼저 차단을 해제해 주세요.';

  @override
  String get profileScreenErrorUserNotFound => '지금은 할 수 없어요.';

  @override
  String get profileScreenNameNotSaved => '이름을 저장하지 못했어요. 다시 시도해 주세요.';

  @override
  String get profileScreenFamilyAddChild => '자녀 추가하기';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '자녀 $count명',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => '가족';

  @override
  String get profileScreenFriendsChip => '친구';

  @override
  String get profileScreenGrownUpOnlyNote =>
      '보호자만 할 수 있어요 — 보호자의 코드나 비밀번호가 필요해요.';

  @override
  String get profileScreenGuardiansCanSee => '보호자는 온라인 상태와 대화 상대를 볼 수 있어요.';

  @override
  String get profileScreenHandPhoneBack => '이 휴대폰 돌려주기';

  @override
  String get profileScreenIncomingRequestChip => '받은 요청';

  @override
  String get profileScreenJustTappedAction => '실수로 눌렀어요';

  @override
  String get settingsScreenSectionHelpAndLegal => '도움말 및 법적 정보';

  @override
  String get settingsScreenLicence => '오픈소스 라이선스';

  @override
  String get profileScreenLinkedAccountsLabel => '연결된 계정';

  @override
  String get profileScreenLinkedAccountsNone => '연결된 계정 없음';

  @override
  String get profileScreenMyGrownUps => '내 보호자';

  @override
  String get profileScreenNameHint => '채팅방에서 보이는 이름이에요';

  @override
  String get profileScreenChangeUsernameTitle => '사용자 이름을 변경할까요?';

  @override
  String get profileScreenChangeUsernameWarning =>
      '로그인에 쓰는 이름이라, 앞으로는 새 이름을 입력하게 됩니다. 이전 사용자 이름은 다른 사람이 가져갈 수 있도록 풀리고, 30일 동안은 다시 바꿀 수 없습니다. 나를 언급한 예전 메시지에는 이전 이름이 그대로 남습니다.';

  @override
  String get profileScreenUsernameHint => '친구들이 나를 찾는 이름';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return '$date에 다시 변경할 수 있어요';
  }

  @override
  String get profileScreenUsernamePasswordTitle => '본인 확인';

  @override
  String get profileScreenUsernamePasswordAction => '사용자 이름 변경';

  @override
  String get profileScreenUsernameProviderTitle => '로그인으로 확인';

  @override
  String profileScreenUsernameChanged(String username) {
    return '이제 @$username입니다.';
  }

  @override
  String get profileScreenUsernameNotSaved => '사용자 이름을 변경하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get usernameStatusChecking => '확인 중…';

  @override
  String get usernameStatusAvailable => '사용 가능';

  @override
  String get usernameStatusTaken => '이미 사용 중';

  @override
  String get usernameStatusReserved => '사용할 수 없음';

  @override
  String get usernameStatusInvalid => '1~32자';

  @override
  String get usernameStatusUnknown => '확인하지 못했습니다';

  @override
  String get profileScreenNobodyLookingAfter => '아직 이 계정을 돌봐주는 보호자가 없어요';

  @override
  String get profileScreenNotAcceptingRequestsAction => '친구 요청 받지 않음';

  @override
  String get profileScreenNotConnectedChip => '연결되지 않음';

  @override
  String get profileScreenOpenDmAction => 'DM 열기';

  @override
  String get profileScreenPhotoPermissionDenied => '사진 접근 권한이 거부되었어요.';

  @override
  String get settingsScreenPrivacyPolicy => '개인정보처리방침';

  @override
  String get profileScreenPrivacySection => '개인정보';

  @override
  String get profileScreenProfilePictureTitle => '프로필 사진';

  @override
  String get profileScreenRedactedFriend => '친구의 설정에 따라 일부 정보가 숨겨져 있어요.';

  @override
  String get profileScreenRedactedStranger =>
      '제한된 화면이에요 — 친구에게는 더 많은 정보를 공개해요.';

  @override
  String get profileScreenReportAction => '신고하기';

  @override
  String get profileScreenReportSent => '신고가 비공개로 접수됐어요. 상대방에게는 알림이 가지 않아요.';

  @override
  String get profileScreenRequestPendingChip => '보낸 요청';

  @override
  String get profileScreenSaveAction => '저장';

  @override
  String get profileScreenSavedToPhotos => '사진 앱에 저장됐어요.';

  @override
  String get profileScreenSaveToPhotos => '사진 앱에 저장하기';

  @override
  String get profileScreenSendRequestAction => '친구 요청 보내기';

  @override
  String get profileScreenSetUpRecoveryPhrase => '복구 문구 설정하기';

  @override
  String get profileScreenSignOut => '로그아웃';

  @override
  String get profileScreenTakeSelfie => '셀카 찍기';

  @override
  String get profileScreenTapAgainToConfirmDelete => '한 번 더 눌러서 삭제 확인';

  @override
  String get settingsScreenTermsOfService => '이용약관';

  @override
  String get profileScreenThisPhoneSection => '이 휴대폰';

  @override
  String get profileScreenUnfriendAction => '친구 끊기';

  @override
  String get profileScreenViewProfilePictureSemantic => '프로필 사진 보기';

  @override
  String get profileScreenVisibilityPreferences => '공개 범위 설정';

  @override
  String get cameraEditorScreenCropPresetFree => '자유';

  @override
  String get cameraEditorScreenCropPresetOriginal => '원본';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => '자르기 취소';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => '사진 버리기';

  @override
  String get cameraEditorScreenUndoSemanticLabel => '실행 취소';

  @override
  String get cameraEditorScreenRedoSemanticLabel => '다시 실행';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => '자르기 초기화';

  @override
  String get cameraEditorScreenRotateSemanticLabel => '회전';

  @override
  String get cameraEditorScreenCropSemanticLabel => '자르기';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      '이 브라우저에서는 HEIC 사진을 열 수 없어요';

  @override
  String get cameraEditorScreenImageLoadFailedMessage => '그 이미지를 열 수 없어요';

  @override
  String get cameraEditorScreenCropDoneButton => '완료';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => '다시 찍기';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => '펜 집어넣기';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => '사진에 그리기';

  @override
  String get cameraEditorScreenSendingButton => '전송 중…';

  @override
  String get cameraEditorScreenSendButton => '보내기';

  @override
  String get cameraEditorScreenViewOnceNote => '한 번 보면 사라져요';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => '그림 지우기';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel => '한 번 보기: 켜짐';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel => '한 번 보기: 꺼짐';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: 켬';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: 끔';

  @override
  String get cameraEditorScreenHdNote => '원본 해상도로 전송합니다';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => '펜 색상';

  @override
  String get glassScreenPanelLooks => '룩';

  @override
  String get glassScreenPanelBottomBar => '하단 바';

  @override
  String get glassScreenPanelOtherSurfaces => '기타 영역';

  @override
  String get glassScreenPanelBarLayout => '바 레이아웃';

  @override
  String get glassScreenTitle => '글래스.';

  @override
  String get glassScreenSubtitle => '배경이 얼마나 비쳐 보이는지';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return '슬롯 $max개 모두 가득 참';
  }

  @override
  String get glassScreenSaveCurrentAs => '새 룩으로 저장…';

  @override
  String get glassScreenResetEveryDial => '모든 다이얼 초기화';

  @override
  String glassScreenResetToPreset(Object name) {
    return '$name(으)로 초기화';
  }

  @override
  String get glassScreenSurfacesNote =>
      '입력창, 헤더, 통화 버튼처럼 스크롤되는 콘텐츠가 아니라 텍스트 위에 놓이는 요소예요';

  @override
  String get glassScreenMatchBottomBar => '하단 바에 맞추기';

  @override
  String get glassScreenPresetEditedSubtitle => '수정됨 — 새 룩으로 저장하거나 초기화하세요';

  @override
  String get glassScreenCustomPresetName => '커스텀';

  @override
  String get glassScreenUnsavedSubtitle => '저장 안 됨 — 이름을 지으면 저장돼요';

  @override
  String get glassScreenSaveDialogTitle => '이 룩 저장하기';

  @override
  String get glassScreenNoRoomToast => '공간이 없어요 — 룩을 먼저 삭제하세요';

  @override
  String get glassScreenRenameDialogTitle => '이름 바꾸기';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '$name 삭제할까요?';
  }

  @override
  String get glassScreenDeleteConfirmBody => '룩은 화면에 그대로 남아요 — 이름만 없어질 뿐이에요.';

  @override
  String get glassScreenKeepButton => '유지';

  @override
  String get glassScreenDeleteButton => '삭제';

  @override
  String get glassScreenNameHint => '심야';

  @override
  String get glassScreenCancelButton => '취소';

  @override
  String get glassScreenSaveButton => '저장';

  @override
  String get glassScreenPreviewRoomName => '# 발코니';

  @override
  String get glassScreenPreviewOnlineCount => '4명 접속 중';

  @override
  String get glassScreenPreviewMessageHint => '메시지';

  @override
  String get glassScreenPreviewCollapseLabel => '미리보기 접기';

  @override
  String get glassScreenPreviewExpandLabel => '미리보기 펼치기';

  @override
  String get glassScreenPreviewBadge => '미리보기';

  @override
  String get glassScreenBuiltInLabel => '기본 제공';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return '$name 덮어쓰기';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return '$name 이름 바꾸기';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return '$name 삭제';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return '$label 초기화';
  }

  @override
  String get glassScreenBackdropMsgDilan => '지붕 사진 보냈어 — 타일이 다 깨졌더라';

  @override
  String get glassScreenBackdropMsgMert => '근데 스피커는 진짜 누가 가져와?';

  @override
  String get glassScreenBackdropGroupFamily => '가족';

  @override
  String get glassScreenBackdropMsgFamily => '엄마: 저녁 8시야, 또 늦지 마';

  @override
  String get glassScreenBackdropMsgZeynep => '나 밖이야';

  @override
  String get glassScreenBackdropMsgKerem => '모퉁이 그 가게 커피 진짜 잘해';

  @override
  String get glassScreenBackdropGroupWork => '회사';

  @override
  String get glassScreenBackdropMsgWork => '이번 주 남은 요일 스탠드업 10시 30분으로 변경됐어';

  @override
  String get glassScreenBackdropMsgElif => '말도 안 돼. 다시 보내줘, 잃어버렸어';

  @override
  String get glassScreenBackdropMsgBaran => '착륙했어 👍';

  @override
  String get glassScreenBackdropMsgAyse => '고양이가 발코니 문 여는 법을 배웠어';

  @override
  String get glassScreenBackdropMsgCan => '그럼 토요일에 봐';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return '$name님에게 답장';
  }

  @override
  String get replyIndicatorViewOnceLabel => '사진 · 한 번 보기';

  @override
  String get replyIndicatorVoiceMessageLabel => '음성 메시지';

  @override
  String get replyIndicatorDocumentLabel => '문서';

  @override
  String get replyIndicatorMessageRemoved => '삭제된 메시지';

  @override
  String get threadOverlayMessageNotFound => '이 스레드에서 해당 메시지를 찾을 수 없어요';

  @override
  String get threadOverlayReplyTargetNotFound => '답장할 스레드를 찾을 수 없어요';

  @override
  String get threadOverlayStillSending => '아직 전송 중이에요. 잠시 후 다시 시도해 주세요';

  @override
  String get threadOverlayCopiedToast => '복사됨';

  @override
  String get threadOverlayNameCopiedToast => '이름 복사됨';

  @override
  String get threadOverlayCoordinatesCopiedToast => '좌표 복사됨';

  @override
  String get threadOverlayPinLimitToast => '고정한 메시지가 너무 많아요. 하나를 먼저 고정 해제해 주세요';

  @override
  String get threadOverlayPinFailedToast => '고정하지 못했어요';

  @override
  String get threadOverlayReportedToast => '신고됨';

  @override
  String get threadOverlayUnavailable => '스레드를 사용할 수 없어요';

  @override
  String get roomInfoScreenNameRequiredError => '이름을 입력해 주세요';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => '비밀번호 삭제됨';

  @override
  String get roomInfoScreenLeaveConfirmTitle => '방을 나가시겠어요?';

  @override
  String get roomInfoScreenLeaveConfirmBody => '방이 계속 열려 있으면 다시 참여할 수 있어요.';

  @override
  String get roomInfoScreenLeaveConfirmButton => '나가기';

  @override
  String get roomInfoScreenDeleteConfirmTitle => '방을 삭제하시겠어요?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      '이 방의 모든 메시지도 함께 사라져요. 이 작업은 되돌릴 수 없어요.';

  @override
  String get roomInfoScreenDeleteConfirmButton => '삭제';

  @override
  String get roomInfoScreenEndConversationConfirmTitle => '이 대화를 종료하시겠어요?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName님도 이 대화를 잃게 돼요 — 두 사람 모두의 메시지가 사라져요. 이 작업은 되돌릴 수 없어요.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => '종료';

  @override
  String get roomInfoScreenEndConversationPeerFallback => '상대방';

  @override
  String get roomInfoScreenConfirmCancelButton => '취소';

  @override
  String get roomInfoScreenErrorRoomExists => '이미 같은 이름의 방이 있어요';

  @override
  String get roomInfoScreenErrorNotOwner => '방장만 할 수 있어요';

  @override
  String get roomInfoScreenErrorNotAuthorized => '권한이 없어요';

  @override
  String get roomInfoScreenErrorRoomNotFound => '이 방은 사라졌어요';

  @override
  String get roomInfoScreenRoomGone => '사라진 방';

  @override
  String get roomInfoScreenNameLabel => '이름';

  @override
  String get roomInfoScreenNameHint => '방 이름';

  @override
  String get roomInfoScreenDescriptionLabel => '설명';

  @override
  String get roomInfoScreenDescriptionHint => '방에 대한 한 줄 소개…';

  @override
  String get roomInfoScreenVisibilityLabel => '공개 범위';

  @override
  String get roomInfoScreenPublicTitle => '공개';

  @override
  String get roomInfoScreenPublicSub => '누구나 찾을 수 있어요';

  @override
  String get roomInfoScreenPrivateTitle => '비공개';

  @override
  String get roomInfoScreenPrivateSub => '초대로만 참여할 수 있어요';

  @override
  String get roomInfoScreenMessageLifeLabel => '메시지 유지 시간';

  @override
  String roomInfoScreenTtlSeconds(Object value) {
    return '$value초';
  }

  @override
  String roomInfoScreenTtlMinutes(Object value) {
    return '$value분';
  }

  @override
  String roomInfoScreenTtlHours(Object value) {
    return '$value시간';
  }

  @override
  String get roomInfoScreenPasswordLabel => '비밀번호';

  @override
  String get roomInfoScreenLockedBadge => '잠김';

  @override
  String get roomInfoScreenNoneBadge => '없음';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      '이 방은 비밀번호로 보호되어 있어요. 보안을 위해 기존 비밀번호는 표시되지 않으니, 새 비밀번호를 입력하면 교체돼요.';

  @override
  String get roomInfoScreenReplacePasswordHint => '새 비밀번호로 교체…';

  @override
  String get roomInfoScreenSetPasswordHint => '비밀번호로 잠그기…';

  @override
  String get roomInfoScreenRemovePasswordButton => '비밀번호 삭제';

  @override
  String get roomInfoScreenSharedContentLabel => '공유 콘텐츠';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return '멤버 · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => '나가는 중…';

  @override
  String get roomInfoScreenLeaveRoomButton => '방 나가기';

  @override
  String get roomInfoScreenDeletingButton => '삭제하는 중…';

  @override
  String get roomInfoScreenDeleteButtonLabel => '삭제';

  @override
  String get roomInfoScreenEndingConversationButton => '종료하는 중…';

  @override
  String get roomInfoScreenEndConversationButton => '대화 종료';

  @override
  String get roomInfoScreenHeaderConversation => '대화';

  @override
  String get roomInfoScreenHeaderRoomSettings => '방 설정';

  @override
  String get roomInfoScreenViewProfilePictureSemantic => '프로필 사진 보기';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => '방 사진 보기';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => '방 사진 변경';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => '방 사진 추가';

  @override
  String get roomInfoScreenOwnerBadge => '방장';

  @override
  String get roomInfoScreenNoneCount => '없음';

  @override
  String get cameraScreenAccessDeniedMessage =>
      '카메라 접근 권한이 꺼져 있어요.\n사진을 찍으려면 설정에서 켜주세요.';

  @override
  String get cameraScreenOpeningSystemCamera => '시스템 카메라를 여는 중…';

  @override
  String get cameraScreenCloseButtonLabel => '카메라 닫기';

  @override
  String get cameraScreenLowLightBoostOnLabel => '저조도 부스트: 켜짐';

  @override
  String get cameraScreenLowLightBoostOffLabel => '저조도 부스트: 꺼짐';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return '플래시: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => '라이브러리에서 선택';

  @override
  String get cameraScreenSwitchCameraLabel => '카메라 전환';

  @override
  String get cameraScreenTakePhotoLabel => '사진 촬영';

  @override
  String get childPolicyScreenAddByUsernameLabel => '사용자 이름으로 추가';

  @override
  String get childPolicyScreenAddCta => '추가';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return '이 사람은 회원님과 똑같은 권한을 갖게 돼요. 승인할 요청, 바꿀 설정은 물론 회원님을 삭제할 권한까지 모두요. $name님은 이 사람을 바로 가족으로 인식해요.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => '보호자 추가';

  @override
  String get childPolicyScreenAddGuardianHint => '상대방의 사용자 이름';

  @override
  String get childPolicyScreenAllowCta => '허용';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return '$childName님이 이 사람을 추가하든, 이 사람이 $childName님을 추가하든 다시 묻지 않아요.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => '연락처 허용';

  @override
  String get childPolicyScreenAskToAddLabel => '추가 요청';

  @override
  String get childPolicyScreenAskToAddOffDesc => '가족만 — 새 요청 없음';

  @override
  String get childPolicyScreenAskToAddOnDesc => '새로운 사람에 대해 물어볼 수 있어요';

  @override
  String get childPolicyScreenBothFinalNote =>
      '두 가지 모두 되돌릴 수 없어요. 대신 손을 떼고 싶다면 보호자 섹션에서 할 수 있어요.';

  @override
  String get childPolicyScreenCallsLabel => '통화';

  @override
  String get childPolicyScreenCallsOffDesc => '메시지만';

  @override
  String get childPolicyScreenCallsOnDesc => '허용된 상대와 음성·영상 통화 가능해요';

  @override
  String get childPolicyScreenCancelLabel => '취소';

  @override
  String get childPolicyScreenCancelSemanticLabel => '취소';

  @override
  String get childPolicyScreenContactAddedRequestSent => '추가됨 — 요청을 보내는 중이에요';

  @override
  String get childPolicyScreenContactAddedToList => '허용 목록에 추가됐어요';

  @override
  String get childPolicyScreenCreateRoomsLabel => '방 만들기';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => '방을 만들 수 없어요';

  @override
  String get childPolicyScreenCreateRoomsOnDesc => '자신만의 비공개 방을 만들 수 있어요';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      '메시지, 사진, 방, 친구까지 모두 사라져요. 되돌릴 수 없으며, 사용자 이름은 다른 사람이 사용할 수 있게 돼요.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      '계정을 삭제하지 못했어요 — 다시 시도해 주세요';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return '$name님의 계정을 삭제할까요?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      '메시지, 사진, 방, 친구가 모두 사라져요. 되돌릴 수 없어요.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return '$name님의 계정 삭제';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => '완전히 삭제';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      '추가하지 못했어요 — 다시 시도해 주세요';

  @override
  String get childPolicyScreenErrorCannotAddSelf => '그건 아이 본인의 사용자 이름이에요';

  @override
  String get childPolicyScreenErrorChildNotAllowed => '아이는 보호자가 될 수 없어요';

  @override
  String get childPolicyScreenErrorGenericGuardian => '처리하지 못했어요 — 다시 시도해 주세요';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      '돌봐줄 보호자가 있어야 해요 — 먼저 다른 보호자를 추가해 주세요';

  @override
  String get childPolicyScreenErrorNotYours => '이건 변경할 권한이 없어요';

  @override
  String get childPolicyScreenErrorUserNotFound => '해당 아이디의 계정을 찾을 수 없어요';

  @override
  String get childPolicyScreenGraduateBlurb =>
      '이 비밀번호로 일반 계정이 되고, 모든 보호자는 더 이상 아무것도 볼 수 없게 돼요. 되돌릴 수 없으며, 이후에는 다른 사람과 마찬가지로 초대를 받아야 해요.';

  @override
  String get childPolicyScreenGraduateCta => '졸업하기';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      '모든 데이터는 그대로 유지되고 비밀번호가 생겨요. 보호자는 아무것도 볼 수 없게 돼요. 되돌릴 수 없어요.';

  @override
  String get childPolicyScreenGraduateDangerLabel => '정식 계정으로 전환하기';

  @override
  String get childPolicyScreenGraduateFailed => '전환하지 못했어요 — 다시 시도해 주세요';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return '$name 졸업시키기';
  }

  @override
  String get childPolicyScreenGraduateHint => '아이의 비밀번호';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      '방 허용을 취소하면 그 방에서도 나가게 돼요. 사람 허용을 취소하면 채팅방도 함께 삭제돼요 — 양쪽 모두에서요.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      '여기 있는 보호자는 모두 승인하고, 설정을 바꾸고, 모든 걸 볼 수 있어요. 누구든 혼자서 처리할 수 있고, 다른 사람의 동의를 기다릴 필요는 없어요.';

  @override
  String get childPolicyScreenGuardianAdded => '추가됐어요 — 이제 함께 돌볼 수 있어요';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name 삭제됨';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (나)';
  }

  @override
  String get childPolicyScreenLoading => '불러오는 중…';

  @override
  String get childPolicyScreenLockedLabel => '잠금';

  @override
  String get childPolicyScreenMediaLabel => '사진 + 음성';

  @override
  String get childPolicyScreenMediaOffDesc => '텍스트만';

  @override
  String get childPolicyScreenMediaOnDesc => '사진, 동영상, 음성 메시지를 보낼 수 있어요';

  @override
  String get childPolicyScreenNoRoomsYet => '아직 방이 없어요';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      '여기 있는 사람은 누구든 다시 묻지 않고 추가할 수 있어요 — 누가 먼저 시작하든요.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      '아이 계정에서는 항상 꺼져 있어요. 모르는 사람의 방 목록을 보여주는 \'발견하기\' 기능은 완전히 숨겨져 있고 켤 수 없어요. 누군가 초대한 방은 평소처럼 그대로 이용할 수 있어요.';

  @override
  String get childPolicyScreenPublicRoomsLabel => '공개 방';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian님은 앞으로 $child에 대해 아무것도 보거나 승인할 수 없어요.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return '$name님을 삭제할까요?';
  }

  @override
  String get childPolicyScreenRemoveLabel => '삭제하기';

  @override
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count명';
  }

  @override
  String get childPolicyScreenSectionGrownUps => '보호자';

  @override
  String get childPolicyScreenSectionPeopleAllowed => '허용한 사람';

  @override
  String get childPolicyScreenSectionRoomsAllowed => '허용한 방';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => '할 수 있는 것';

  @override
  String get childPolicyScreenSectionWhenDone => '계정을 정리할 때';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      '누군가 먼저 상대를 추가하기 전까지는 아무 일도 일어나지 않아요';

  @override
  String get childPolicyScreenSendNowOnDesc => '상대방이 바로 요청을 받게 돼요';

  @override
  String get childPolicyScreenSendRequestNowLabel => '지금 요청 보내기';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return '회원님은 $name의 유일한 보호자라 그냥 빠질 수 없어요. 먼저 다른 보호자를 추가하거나, 아래 방법 중 하나를 이용해 보세요.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => '보호자에서 빠지기';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return '$name의 계정에 대한 모든 정보를 볼 수 없게 돼요 — 요청도, 친구도, 채팅방도요. 다른 보호자들이 계속 돌봐줄 거예요.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => '보호자 그만두기';

  @override
  String get childPolicyScreenStopSupervisingHeadline => '보호자를 그만두시겠어요?';

  @override
  String get childPolicyScreenTakeBackFailed => '회수하지 못했어요 — 다시 시도해 주세요';

  @override
  String get childPolicyScreenTakeBackLabel => '회수하기';

  @override
  String get childPolicyScreenUsernameHint => '사용자 이름';

  @override
  String get childPolicyScreenYou => '회원님';

  @override
  String get roomContentScreenDefaultDocumentName => '문서';

  @override
  String get roomContentScreenCouldntOpenFile => '파일을 열 수 없었어요';

  @override
  String get roomContentScreenCouldntShare => '공유하지 못했어요';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '링크 $count개를 복사했어요',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '메시지 $count개 삭제',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody => '이 채팅방의 모든 사람에게서 삭제돼요. 되돌릴 수 없어요.';

  @override
  String get roomContentScreenDeleteForEveryone => '모두에게서 삭제';

  @override
  String get roomContentScreenCancelTooltip => '취소';

  @override
  String get roomContentScreenBackTooltip => '뒤로';

  @override
  String get roomContentScreenSelectingLabel => '선택 중';

  @override
  String get roomContentScreenSharedContentLabel => '공유 콘텐츠';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 선택됨',
      zero: '선택된 항목 없음',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => '선택';

  @override
  String get roomContentScreenSelectAllActiveLabel => '전체';

  @override
  String get roomContentScreenEmptyMedia => '아직 사진이나 동영상이 없어요';

  @override
  String get roomContentScreenEmptyFiles => '아직 파일이 없어요';

  @override
  String get roomContentScreenEmptyVoice => '아직 음성 메시지가 없어요';

  @override
  String get roomContentScreenEmptyLinks => '아직 링크가 없어요';

  @override
  String get roomContentScreenEmptySaved =>
      '아직 저장한 것이 없습니다. 메시지를 길게 눌러 저장을 선택하세요.\n\n여기에 보관한 것은 나만 볼 수 있습니다. 고정한 메시지는 방 전체가 봅니다.';

  @override
  String get roomContentScreenLoadFailed => '불러오지 못했어요';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return '$name님이 보낸 음성 메시지';
  }

  @override
  String get roomContentScreenForwardAction => '전달';

  @override
  String get roomContentScreenCopyAction => '복사';

  @override
  String get roomContentScreenSaveAction => '저장';

  @override
  String get roomContentScreenShareAction => '공유';

  @override
  String get roomContentScreenInChatAction => '채팅에서 보기';

  @override
  String get roomContentScreenDeleteAction => '삭제';

  @override
  String get messageActionMenuReplyLabel => '답장';

  @override
  String get messageActionMenuEditLabel => '수정';

  @override
  String get messageStampEditedLabel => '수정됨';

  @override
  String get composerEditCardTitle => '메시지 수정';

  @override
  String get spoilerRevealHint => '스포일러 — 활성화하면 숨겨진 텍스트가 표시돼요';

  @override
  String get formatToolbarFormatLabel => '서식';

  @override
  String get formatToolbarBoldLabel => '굵게';

  @override
  String get formatToolbarItalicLabel => '기울임';

  @override
  String get formatToolbarStrikethroughLabel => '취소선';

  @override
  String get formatToolbarUnderlineLabel => '밑줄';

  @override
  String get formatToolbarSpoilerLabel => '스포일러';

  @override
  String get formatToolbarLinkLabel => '링크';

  @override
  String get formatToolbarCodeLabel => '코드';

  @override
  String get linkInputSheetTitle => '링크';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => '링크 적용';

  @override
  String get linkInputSheetApplySub => '선택한 텍스트를 탭하면 이 주소가 열려요';

  @override
  String get linkInputSheetRemoveLabel => '링크 제거';

  @override
  String get linkConfirmSheetTitle => '이 링크를 열까요?';

  @override
  String get linkConfirmSheetOpenLabel => '링크 열기';

  @override
  String get linkConfirmSheetCancelLabel => '취소';

  @override
  String get roomScreenEditExpiredSnack =>
      '수정하기엔 너무 늦었어요 — 메시지는 15분 동안만 수정할 수 있어요.';

  @override
  String get roomScreenEditFailedSnack =>
      '수정 내용을 저장하지 못했어요. 연결을 확인하고 다시 시도해 주세요.';

  @override
  String get messageActionMenuForwardLabel => '전달';

  @override
  String get messageActionMenuViewThreadLabel => '스레드 보기';

  @override
  String get messageActionMenuCopyLabel => '복사';

  @override
  String get messageActionMenuCopyNameLabel => '이름 복사';

  @override
  String get messageActionMenuCopyCoordinatesLabel => '좌표 복사';

  @override
  String get messageActionMenuPinLabel => '고정';

  @override
  String get messageActionMenuUnpinLabel => '고정 해제';

  @override
  String get messageActionMenuSelectLabel => '선택';

  @override
  String get messageActionMenuProfileLabel => '프로필';

  @override
  String get messageActionMenuDeleteLabel => '삭제';

  @override
  String get messageActionMenuReportLabel => '신고';

  @override
  String get themeScreenTitle => '테마.';

  @override
  String get themeScreenTapToApplyHint => '탭하여 적용 · ⛶로 전체 미리보기';

  @override
  String get themeScreenFamilyBasicName => '베이직';

  @override
  String get themeScreenFamilyBasicTagline => 'iOS에서 영감을 받은 · 팔레트 5종';

  @override
  String get themeScreenFamilyVaultName => '볼트';

  @override
  String get themeScreenFamilyVaultTagline => '기밀 문서 · 느와르 + 아이보리';

  @override
  String get themeScreenFamilyOthersName => '기타';

  @override
  String get themeScreenFamilyOthersTagline => '저마다의 무드';

  @override
  String get themeScreenActiveBadge => '적용됨';

  @override
  String get themeScreenTapToApplyLabel => '탭하여 적용';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return '적용됨 — $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return '$name 적용하기';
  }

  @override
  String get themeScreenPreviewGreeting => '안녕, 너.';

  @override
  String get themeScreenPreviewSectionLabel => '대화';

  @override
  String get themeScreenPreviewRoomOneName => '디자인 클럽';

  @override
  String get themeScreenPreviewRoomOneSub => '미아: 새 타일 배포했어.';

  @override
  String get themeScreenPreviewRoomTwoName => '체임버 · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => '4시간 후 봉인.';

  @override
  String get themeScreenPreviewBubbleQuestion => '느낌이 어때?';

  @override
  String get themeScreenPreviewBubbleAnswer => '이게 맞는 것 같아.';

  @override
  String get callScreenVideoCallLabel => '수신 영상 통화';

  @override
  String get callScreenVoiceCallLabel => '수신 음성 통화';

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · 발신 중…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · 수신 중';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · 연결 중…';
  }

  @override
  String get callScreenStatusConnected => '연결됨';

  @override
  String get callScreenStatusEnded => '통화 종료';

  @override
  String get callScreenStatusFailed => '통화 실패';

  @override
  String get callScreenStatusSwitching => '기기 전환 중…';

  @override
  String get callScreenStatusMoved => '이동됨';

  @override
  String get callScreenStatusReconnecting => '재연결 중…';

  @override
  String get callScreenPoorConnectionLabel => '연결 불량';

  @override
  String get callScreenWeakConnectionLabel => '연결 약함';

  @override
  String get callScreenControlUnmute => '음소거 해제';

  @override
  String get callScreenControlMute => '음소거';

  @override
  String get callScreenControlCamOn => '카메라 켜기';

  @override
  String get callScreenControlCamOff => '카메라 끄기';

  @override
  String get callScreenControlFlip => '전환';

  @override
  String get callScreenControlSpeaker => '스피커';

  @override
  String get callScreenControlEnd => '종료';

  @override
  String get linkPreviewCardLinkLabel => '링크';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name님이 친구 요청을 수락했어요';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar => '그 요청이 취소됐어요';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => '요청이 거절됐어요';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      '이 사용자를 차단했어요 — 먼저 차단을 해제해 주세요.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      '상대방이 지금은 친구 요청을 받지 않고 있어요.';

  @override
  String get friendRequestDraftScreenErrorSendFailed => '보내지 못했어요. 다시 시도해 주세요.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => '받은 요청';

  @override
  String get friendRequestDraftScreenNewRequestLabel => '보낸 요청';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name님이 대화를 시작하고 싶어해요.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      '몇 마디 보내보세요. 상대방이 수락하거나 거절할 수 있어요.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      '서로 동의하기 전까지는 이 내용이 어디에도 영구히 저장되지 않아요.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => '채팅방 유형';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => '휘발성';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => '일반';

  @override
  String get friendRequestDraftScreenLifetimeLabel => '메시지 수명';

  @override
  String friendRequestDraftScreenDurationSeconds(Object seconds) {
    return '$seconds초';
  }

  @override
  String friendRequestDraftScreenDurationMinutes(Object minutes) {
    return '$minutes분';
  }

  @override
  String friendRequestDraftScreenDurationHours(Object hours) {
    return '$hours시간';
  }

  @override
  String get friendRequestDraftScreenHintWhisperOptional => '첫 마디 속삭이기 · 선택';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      '첫 메시지 남기기 · 선택';

  @override
  String get friendRequestDraftScreenHintWhisperFades => '속삭임 · 자동으로 사라짐';

  @override
  String get friendRequestDraftScreenHintStartWith => '무슨 말이든 좋아요…';

  @override
  String get friendRequestDraftScreenApproveButton => '받은 요청 수락하고 채팅방 열기';

  @override
  String get friendRequestDraftScreenDeclineButton => '받은 요청 거절하기';

  @override
  String get friendRequestDraftScreenCancelRequestButton => '보낸 요청 취소하기';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => '보호자에게 물어보기';

  @override
  String get friendRequestDraftScreenSendRequestButton => '요청 보내기';

  @override
  String get discoverScreenTitle => '탐색.';

  @override
  String get discoverScreenCaptionPeople => '사람';

  @override
  String get discoverScreenCaptionRooms => '채팅방';

  @override
  String get discoverScreenCaptionRequests => '요청';

  @override
  String get discoverScreenPeopleBandLabel => '사람들';

  @override
  String get discoverScreenRoomsBandLabel => '채팅방';

  @override
  String get discoverScreenFindPeopleTitle => '사람 찾기';

  @override
  String get discoverScreenFindPeopleSubtitleChild => '사용자 이름 전체를 입력하세요';

  @override
  String get discoverScreenFindPeopleSubtitleAdult => '@사용자 이름 또는 이름으로 검색';

  @override
  String get discoverScreenRequestsSectionLabel => '요청';

  @override
  String get discoverScreenInboxQuiet => '받은 요청 없음';

  @override
  String get discoverScreenNothingPending => '보낸 요청 없음';

  @override
  String get discoverScreenYourPeopleLabel => '내 사람들';

  @override
  String get discoverScreenNoFriendsYetWithHint => '아직 아무도 없어요 — 위에서 사람 찾기';

  @override
  String get discoverScreenNoFriendsYet => '아직 아무도 없어요';

  @override
  String get discoverScreenSearchRoomsTitle => '채팅방 검색';

  @override
  String get discoverScreenSearchRoomsSubtitle => '이름으로 공개 채팅방 찾기';

  @override
  String get discoverScreenYourRoomsLabel => '내 채팅방';

  @override
  String get discoverScreenNoRoomsYet => '아직 채팅방이 없어요';

  @override
  String get discoverScreenIncomingLabel => '수신';

  @override
  String get discoverScreenOutgoingLabel => '발신';

  @override
  String get discoverScreenIncomingLabelCaps => '수신';

  @override
  String get discoverScreenOutgoingLabelCaps => '발신';

  @override
  String get discoverScreenJumpPeopleLabel => '사람들';

  @override
  String get discoverScreenJumpRoomsLabel => '채팅방';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return '$label 섹션으로 이동';
  }

  @override
  String get imageCropScreenDefaultTitle => '조정';

  @override
  String get imageCropScreenDefaultConfirmLabel => '사진 사용';

  @override
  String get imageCropScreenSavingButton => '저장 중…';

  @override
  String get imageCropScreenCancelButton => '취소';

  @override
  String get imageCropScreenHeicUnsupported => '이 브라우저에서는 HEIC 사진을 열 수 없어요';

  @override
  String get imageCropScreenLoadFailed => '이미지를 열 수 없어요';

  @override
  String get imageCropScreenHintCircle => '드래그로 이동, 핀치로 확대/축소';

  @override
  String get imageCropScreenHintRect => '드래그와 핀치로 프레임 조정';

  @override
  String get loginScreenSignInHeroMuted => '다시\n';

  @override
  String get loginScreenSignInHeroInk => '환영해요.';

  @override
  String get loginScreenSignInFirstHeroMuted => '어서\n';

  @override
  String get loginScreenSignInFirstHeroInk => '오세요.';

  @override
  String get loginScreenSignInCta => '로그인';

  @override
  String get loginScreenSignUpHeroMuted => '새로운\n';

  @override
  String get loginScreenSignUpHeroInk => '멤버.';

  @override
  String get loginScreenSignUpCta => '계정 만들기';

  @override
  String get loginScreenResetHeroMuted => '비밀번호\n';

  @override
  String get loginScreenResetHeroInk => '재설정.';

  @override
  String get loginScreenResetCta => '비밀번호 재설정';

  @override
  String get loginScreenErrorPasswordsDontMatch => '비밀번호가 일치하지 않아요.';

  @override
  String get loginScreenErrorChoosePasswordFirst => '먼저 비밀번호를 설정해주세요.';

  @override
  String get loginScreenUsernameHint => '아이디';

  @override
  String get loginScreenPasswordHint => '비밀번호';

  @override
  String get loginScreenConfirmPasswordHint => '비밀번호 확인';

  @override
  String get loginScreenNameOptionalHint => '이름 (선택)';

  @override
  String get loginScreenRecoveryPhraseHint => '12단어 복구 구문';

  @override
  String get loginScreenNewPasswordHint => '새 비밀번호';

  @override
  String get loginScreenBackToSignIn => '← 로그인으로 돌아가기';

  @override
  String get loginScreenForgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get loginScreenSettingUpKidsPhone => '자녀 계정 설정하기';

  @override
  String get loginScreenLegalPrefix => '계정을 개설하면 다음 약관에 동의하는 거예요: ';

  @override
  String get loginScreenLegalTermsLink => '이용약관';

  @override
  String get loginScreenLegalMiddle => '과 ';

  @override
  String get loginScreenLegalPrivacyLink => '개인정보처리방침';

  @override
  String get loginScreenLegalSuffix => '에 동의하게 돼요.';

  @override
  String get loginScreenAlreadyHerePrompt => '이미 계정이 있으신가요? ';

  @override
  String get loginScreenSignInLink => '로그인';

  @override
  String get loginScreenNoAccountPrompt => '계정이 없으신가요? ';

  @override
  String get loginScreenOpenOneLink => '가입하기';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12단어';
  }

  @override
  String get homeShellEmptyRoomHint => '채팅을 시작하려면 방을 선택하세요';

  @override
  String get homeShellEmptySettingHint => '설정을 선택하세요';

  @override
  String get searchScreenHintPeople => '사람 검색…';

  @override
  String get searchScreenHintRooms => '방 검색…';

  @override
  String get searchScreenPeoplePromptChild => '새로운 사람을 찾으려면 아이디 전체를 정확히 입력하세요';

  @override
  String get searchScreenPeoplePromptDefault => '아이디나 이름으로 검색하세요';

  @override
  String get searchScreenNoMatchChild =>
      '일치하는 사람이 없어요 — 새로운 사람은\n아이디 전체를 정확히 입력해야 찾을 수 있어요';

  @override
  String get searchScreenNoMatchDefault => '일치하는 사람이 없어요';

  @override
  String get searchScreenNoRoomsYet => '아직 공개방이 없어요';

  @override
  String get searchScreenNoRoomsMatch => '일치하는 공개방이 없어요';

  @override
  String get searchScreenActionAskToAdd => '추가 요청';

  @override
  String get searchScreenActionSendRequest => '친구 요청';

  @override
  String get searchScreenActionCancel => '보낸 요청 취소';

  @override
  String get searchScreenActionApprove => '받은 요청 수락';

  @override
  String get searchScreenActionOpenDm => 'DM 열기';

  @override
  String get searchScreenAskedLabel => '요청함';

  @override
  String get profileVisibilityScreenTitle => '공개 범위 설정.';

  @override
  String get profileVisibilityScreenSubtitle =>
      '다른 사람에게 보이는 내 정보와 연락 방법을 관리해요.';

  @override
  String get profileVisibilityScreenSectionProfile => '프로필';

  @override
  String get profileVisibilityScreenAvatarLabel => '아바타';

  @override
  String get profileVisibilityScreenAvatarDesc => '내 프로필 사진';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => '온라인 / 자리비움';

  @override
  String get profileVisibilityScreenOnlineAwayDesc => '지금 활동 중인지 여부';

  @override
  String get profileVisibilityScreenLastSeenLabel => '마지막 접속';

  @override
  String get profileVisibilityScreenLastSeenDesc => '마지막으로 접속한 시간';

  @override
  String get profileVisibilityScreenSectionMessages => '메시지';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel => '읽음 표시 보내기';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      '켜면 상대방이 내가 메시지를 읽었는지 알 수 있어요';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel => '읽음 표시 보기';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      '내가 보낸 메시지를 상대가 읽으면 \"읽음\" 표시가 떠요';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      '\"읽음 알림 보내기\"를 켠 사람만 반영돼요. 나머지는 보이지 않아요.';

  @override
  String get profileVisibilityScreenSectionPeople => '사람들';

  @override
  String get profileVisibilityScreenFriendRequestsLabel => '친구 요청';

  @override
  String get profileVisibilityScreenFriendRequestsDesc =>
      '나에게 친구 요청을 보낼 수 있는 사람';

  @override
  String get profileVisibilityScreenSupervisedTitle => '보호자가 설정하는 항목이에요';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      '여기서 다른 사람들에게 보이는 내용을 확인할 수 있지만, 변경은 보호자만 할 수 있어요. 보호자는 내 사진, 온라인 상태, 마지막 접속 시간을 항상 볼 수 있어요.';

  @override
  String get profileVisibilityScreenOptionPublic => '전체 공개';

  @override
  String get profileVisibilityScreenOptionFriends => '친구만';

  @override
  String get profileVisibilityScreenOptionNobody => '없음';

  @override
  String get profileVisibilityScreenOptionOn => '켜짐';

  @override
  String get profileVisibilityScreenOptionOff => '꺼짐';

  @override
  String get profileVisibilityScreenOptionAnyone => '누구나';

  @override
  String get logoScreenTitle => '앱 로고.';

  @override
  String get logoScreenSubtitle => '헤더에 넣을 마크, 자유롭게 정하세요.';

  @override
  String get logoScreenAutoLabel => '자동';

  @override
  String get logoScreenAutoDescription => '테마를 따라가요. 팔레트에 맞춰 마크가 바뀌어요.';

  @override
  String get logoScreenManualLabel => '수동';

  @override
  String get logoScreenManualDescription => '마크는 자유롭게 고르고, 테마는 유지돼요.';

  @override
  String get logoScreenAlwaysDefaultLabel => '항상 기본값';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      '테마와 상관없이 MonkeyHub 마크를 사용해요.';

  @override
  String get logoScreenActiveBadge => '사용 중';

  @override
  String get logoScreenMonkeyCollectionHeader => '몽키 컬렉션';

  @override
  String get logoScreenThemesHeader => '테마';

  @override
  String get recoveryPhraseScreenCopiedSnackbar => '복사했어요 — 안전한 곳에 붙여넣어 두세요.';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => '확인\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => '본인이에요.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      '다른 사람이 내 계정에 복구 구문을 설정하지 못하도록 비밀번호를 확인해요.';

  @override
  String get recoveryPhraseScreenPasswordHint => '비밀번호';

  @override
  String get recoveryPhraseScreenContinueButton => '계속하기';

  @override
  String get recoveryPhraseScreenNotNowLink => '나중에';

  @override
  String get recoveryPhraseScreenEnterPasswordError => '비밀번호를 입력하세요.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => '저장\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => '이 단어들.';

  @override
  String get recoveryPhraseScreenWordsBody =>
      '이 열두 단어는 비밀번호를 잊었을 때 계정으로 돌아올 수 있는 유일한 방법이에요. 다시 보여드릴 수 없고, 저희가 대신 복구해 드릴 수도 없어요.';

  @override
  String get recoveryPhraseScreenCopyButton => '복사';

  @override
  String get recoveryPhraseScreenPaperHint =>
      '가능하면 종이에 적어 두세요. 휴대폰에 있는 건 휴대폰과 함께 사라질 수 있어요.';

  @override
  String get recoveryPhraseScreenSavedButton => '저장했어요';

  @override
  String get recoveryPhraseScreenBackLink => '← 뒤로';

  @override
  String get recoveryPhraseScreenKeepPhraseLink => '지금은 아니에요 — 기존 문구 유지';

  @override
  String get homeScreenProfileSemanticLabel => '내 프로필';

  @override
  String homeScreenGreeting(Object name) {
    return '$name님, 안녕하세요.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => '새 채팅방';

  @override
  String get homeScreenEmptyRoomsMessage => '아직 채팅방이 없어요 — 하나 만들어 보세요';

  @override
  String get groupCallScreenTitleVideo => '그룹 영상 통화';

  @override
  String get groupCallScreenTitleVoice => '그룹 음성 통화';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '통화 중 $count명';
  }

  @override
  String get groupCallScreenReconnecting => '재연결 중…';

  @override
  String get groupCallScreenUnmuteLabel => '음소거 해제';

  @override
  String get groupCallScreenMuteLabel => '음소거';

  @override
  String get groupCallScreenCamOnLabel => '카메라 켜기';

  @override
  String get groupCallScreenCamOffLabel => '카메라 끄기';

  @override
  String get groupCallScreenFlipLabel => '전환';

  @override
  String get groupCallScreenSpeakerLabel => '스피커';

  @override
  String get groupCallScreenLeaveLabel => '나가기';

  @override
  String get groupCallScreenYouLabel => '나';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return '$summary 기준으로 필터링 중이에요. 필터 변경';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => '채팅 필터';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => '필터 지우기';

  @override
  String get roomFilterDrawerClearLabel => '지우기';

  @override
  String get roomFilterDrawerDimensionType => '유형';

  @override
  String get roomFilterDrawerDimensionNature => '속성';

  @override
  String get roomFilterDrawerDimensionStatus => '상태';

  @override
  String get roomFilterDrawerPanelClear => '지우기';

  @override
  String get roomFilterDrawerPanelDone => '완료';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '채팅 $count개',
    );
    return '$label, $_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return '$summary에 맞는 채팅이 없어요';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '전체 채팅 $count개 보기',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '전체 채팅 $count개 보기',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => '새 방';

  @override
  String get createRoomSheetTaglineSecret => '아무것도 남지 않는 공간';

  @override
  String get createRoomSheetTaglineRegular => '계속 남아있는 공간';

  @override
  String get createRoomSheetNameLabel => '이름';

  @override
  String get createRoomSheetNameHint => '솔직한 이름을 지어보세요…';

  @override
  String get createRoomSheetDescriptionLabel => '설명 · 선택사항';

  @override
  String get createRoomSheetDescriptionHint => '방을 한 줄로 소개해보세요…';

  @override
  String get createRoomSheetVisibilityLabel => '공개 범위';

  @override
  String get createRoomSheetVisibilityPublicTitle => '공개';

  @override
  String get createRoomSheetVisibilityPublicSub => '누구나 찾을 수 있어요';

  @override
  String get createRoomSheetVisibilityPrivateTitle => '비공개';

  @override
  String get createRoomSheetVisibilityPrivateSub => '초대받은 사람만 들어올 수 있어요';

  @override
  String get createRoomSheetTypeLabel => '유형';

  @override
  String get createRoomSheetTypeStandardTitle => '일반';

  @override
  String get createRoomSheetTypeStandardSub => '메시지가 남아요';

  @override
  String get createRoomSheetTypeEphemeralTitle => '휘발성';

  @override
  String get createRoomSheetTypeEphemeralSub => '자동으로 삭제돼요';

  @override
  String get createRoomSheetMessageLifeLabel => '메시지 수명';

  @override
  String createRoomSheetTtlSeconds(Object seconds) {
    return '$seconds초';
  }

  @override
  String createRoomSheetTtlMinutes(Object minutes) {
    return '$minutes분';
  }

  @override
  String createRoomSheetTtlHours(Object hours) {
    return '$hours시간';
  }

  @override
  String get createRoomSheetPasswordLabel => '비밀번호 · 선택사항';

  @override
  String get createRoomSheetPasswordHint => '암호로 잠가보세요…';

  @override
  String get createRoomSheetNameRequiredError => '이름을 입력해주세요';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => '방 열기';

  @override
  String get createRoomSheetOpenRoomButton => '방 열기';

  @override
  String get familyScreenTitle => '가족';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count건의 승인이 필요해요',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => '지금 온라인';

  @override
  String get familyScreenPresenceNotPaired => '아직 연결되지 않음';

  @override
  String get familyScreenPresenceJustNow => '방금 전';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return '$minutes분 전';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return '$hours시간 전';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return '$days일 전';
  }

  @override
  String get familyScreenPairButton => '연결하기';

  @override
  String get familyScreenReleaseButton => '연결 해제';

  @override
  String get familyScreenSettingsButton => '설정';

  @override
  String get familyScreenAddChildButton => '자녀 추가';

  @override
  String get familyScreenEmptyStateTitle => '아직 자녀가 없어요';

  @override
  String get familyScreenEmptyStateBody => '자녀 계정을 만든 뒤, 자녀의 휴대폰과 연결해 보세요.';

  @override
  String get reactionDetailsSheetTitle => '리액션';

  @override
  String get reactionDetailsSheetEmptyState => '이제 남은 리액션이 없어요';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => '전체';

  @override
  String get reactionDetailsSheetYouBadge => '나';

  @override
  String get roomLayoutScreenTitle => '채팅 목록.';

  @override
  String get roomLayoutScreenSubtitle => '채팅방이 쌓이는 방식과 필터링 방법';

  @override
  String get roomLayoutScreenLayoutSectionLabel => '레이아웃';

  @override
  String get roomLayoutScreenRowLayoutLabel => '리스트형 레이아웃';

  @override
  String get roomLayoutScreenRowLayoutDescription =>
      '1단 구성, 화면 꽉 차게. 한눈에 보기 편해요.';

  @override
  String get roomLayoutScreenGridLayoutLabel => '그리드형 레이아웃';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      '2단 구성, 컴팩트하게. 한 화면에 더 많은 채팅방이 보여요.';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => '필터 방식';

  @override
  String get roomLayoutScreenChipRowLabel => '칩 바';

  @override
  String get roomLayoutScreenChipRowDescription =>
      '언제나 보여요. 탭 한 번으로 필터 선택, 한 줄이면 충분해요.';

  @override
  String get roomLayoutScreenDrawerButtonLabel => '드로어 버튼';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      '버튼 하나로 열어요. 필요할 때까지는 아무것도 가리지 않아요.';

  @override
  String get roomLayoutScreenQuietRoomSectionLabel => '조용한 방';

  @override
  String get roomLayoutScreenPlainCornerLabel => '빈 모서리';

  @override
  String get roomLayoutScreenPlainCornerDescription => '아직 아무 말도 없는 방은 그대로 둬요';

  @override
  String get roomLayoutScreenMonogramLabel => '방 이름 첫 글자';

  @override
  String get roomLayoutScreenMonogramDescription => '크고 옅은 글자가 빈 모서리를 채워요';

  @override
  String get roomLayoutScreenActiveBadge => '사용 중';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel => '고정된 메시지로 이동';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => '고정된 메시지 전체';

  @override
  String get pinnedBannerTitleSingle => '고정된 메시지';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return '고정된 메시지 $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => '채팅 스타일.';

  @override
  String get pinnedBannerChatStyleSubtitle => '채팅방이 보이는 방식';

  @override
  String get pinnedBannerClassicLabel => '클래식';

  @override
  String get pinnedBannerClassicSubtitle => '구분선이 있는 헤더, 플랫한 입력창.';

  @override
  String get pinnedBannerCompactLabel => '컴팩트';

  @override
  String get pinnedBannerCompactSubtitle => '대화 위에 떠 있는 프로스트 캡슐.';

  @override
  String get pinnedBannerActiveBadge => '사용 중';

  @override
  String get audioMessageMissingLabel => '[오디오 없음]';

  @override
  String get audioMessageUnavailableLabel => '오디오를 사용할 수 없음';

  @override
  String get audioMessageRetryHint => '탭하여 다시 시도';

  @override
  String get audioMessageLoadingLabel => '불러오는 중…';

  @override
  String get audioMessageUsernameRequiredError => '사용자 이름을 입력해 주세요.';

  @override
  String get audioMessagePasswordRequiredError => '비밀번호를 입력해 주세요.';

  @override
  String get audioMessageCancelSemanticLabel => '취소';

  @override
  String get audioMessageHeroCreateLine1 => '거의\n';

  @override
  String get audioMessageHeroCreateLine2 => '다 왔어요.';

  @override
  String get audioMessageHeroLinkLine1 => '돌아오신 걸\n';

  @override
  String get audioMessageHeroLinkLine2 => '환영해요.';

  @override
  String get audioMessageCreateSubtitle => '가족과 친구들이 찾을 수 있도록 사용자 이름을 정해 주세요.';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return '로그인 한 번으로 $provider 연동이 완료돼요.';
  }

  @override
  String get audioMessageUsernameHint => '사용자 이름';

  @override
  String get audioMessageDisplayNameHint => '표시 이름 (선택)';

  @override
  String get audioMessagePasswordHint => '비밀번호';

  @override
  String get audioMessageSwitchToLinkPrompt => '제 계정이에요 — 로그인하기';

  @override
  String get audioMessageCreateAccountButton => '계정 만들기';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return '로그인하고 $provider 연동하기';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => '이미 계정이 있으신가요?';

  @override
  String get audioMessageSwitchToCreateModeLink => '처음이신가요? 계정 만들기';

  @override
  String get approvalsScreenTitle => '승인 요청';

  @override
  String get approvalsScreenEmptyTitle => '대기 중인 요청이 없어요';

  @override
  String get approvalsScreenEmptySubtitle => '모두 처리했어요';

  @override
  String get approvalsScreenErrorNotGuardian => '이 요청은 회원님이 결정할 수 없어요';

  @override
  String get approvalsScreenErrorAlreadyHandled => '다른 곳에서 이미 처리됐어요';

  @override
  String get approvalsScreenErrorGeneric => '저장하지 못했어요 — 다시 시도해 주세요';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child님이 $other님을 추가하려고 해요';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other님이 $child님을 추가하려고 해요';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child님이 $room에 참여하려고 해요';
  }

  @override
  String get approvalsScreenSomeoneLower => '상대방';

  @override
  String get approvalsScreenSomeoneCapital => '상대방';

  @override
  String get approvalsScreenRoomFallback => '채팅방';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      '상대방에게 요청이 전달돼요. 수락 여부는 상대방이 정해요.';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$child님이 요청을 받고, 수락하거나 무시할 수 있어요.';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      '직접 취소하기 전까지는 그 방에서 읽고 쓸 수 있어요.';

  @override
  String get approvalsScreenNotYetButton => '나중에';

  @override
  String get approvalsScreenAllowButton => '허용';

  @override
  String get approvalsScreenForwardDirectMessageFallback => '다이렉트 메시지';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '메시지 $count개 전달',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => '아직 다른 채팅이 없어요';

  @override
  String get approvalsScreenForwardNoMatches => '일치하는 채팅이 없어요';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return '한 번에 최대 $max개 채팅까지';
  }

  @override
  String get approvalsScreenForwardSearchHint => '채팅 검색';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return '$title 선택 해제';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return '$title 선택';
  }

  @override
  String get approvalsScreenForwardFadesBadge => '사라짐';

  @override
  String get approvalsScreenForwardSendSemantic => '보내기';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 채팅에 보내기',
      zero: '보내기',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => '연결된 계정';

  @override
  String get linkedAccountsScreenSubtitle =>
      '비밀번호 없이 로그인할 수 있도록 이 계정에 연결해 둔 계정이에요.';

  @override
  String get linkedAccountsScreenEmptyState => '이 기기에서 연결할 수 있는 항목이 없어요.';

  @override
  String get linkedAccountsScreenStatusChecking => '확인 중…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return '어떤 기기에서든 $provider(으)로 로그인할 수 있어요.';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return '비밀번호를 입력하지 않아도 되도록 $provider을(를) 추가하세요.';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return '$provider 연결 해제';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => '연결 해제';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return '$provider(으)로 로그인하지 않으려면 비밀번호를 입력하세요.';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return '$provider 연결';
  }

  @override
  String get linkedAccountsScreenLinkAction => '연결';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return '$provider을(를) 로그인 방법으로 추가하려면 비밀번호를 입력하세요.';
  }

  @override
  String get linkedAccountsScreenPillChecking => '확인 중';

  @override
  String get linkedAccountsScreenPillLinked => '연결됨';

  @override
  String get linkedAccountsScreenPillNotLinked => '연결 안 됨';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => '음성';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => '영상';

  @override
  String get linkedAccountsScreenCallSheetTitle => '통화 시작';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle => '전체 통화';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      '이 채팅방 멤버 전체에게 전화를 걸어요.';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle => '인원 선택';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle =>
      '누구를 초대할지 선택해요.';

  @override
  String get linkedAccountsScreenCallSheetCallFullError =>
      '통화 인원이 가득 찼어요 (최대 6명)';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError => '통화를 시작할 수 없어요';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle => '통화에 초대';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers => '여기엔 다른 멤버가 없어요';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => '사람 선택';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => '통화 시작';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return '통화 시작 ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => '안녕';

  @override
  String get childPairScreenGreetingLine2 => '너.';

  @override
  String get childPairScreenIntro =>
      '보호자에게 몽키허브를 열고 \'기기 페어링하기\'를 눌러 달라고 부탁하세요. 그런 다음 보호자의 코드를 스캔하거나, 보호자가 불러주는 여섯 자리 숫자를 입력하세요.';

  @override
  String get childPairScreenOrDivider => '또는';

  @override
  String get childPairScreenGenericError => '문제가 발생했어요. 다시 시도해 주세요.';

  @override
  String get profileScreenDeleteAccountFailed => '문제가 발생했어요. 다시 시도해 주세요.';

  @override
  String get childPairScreenAccountGoneError => '그 계정은 더 이상 존재하지 않아요.';

  @override
  String get childPairScreenScanButtonLabel => '코드 스캔하기';

  @override
  String get childPairScreenNoCameraMessage =>
      '카메라를 사용할 수 없어요 — 대신 여섯 자리 숫자를 입력하세요.';

  @override
  String get childPairScreenStopScanning => '스캔 중지';

  @override
  String get childPairScreenSubmitButtonLabel => '입장하기';

  @override
  String get childPairScreenBackToSignIn => '← 로그인으로 돌아가기';

  @override
  String get fileMessageUnavailable => '파일을 더 이상 사용할 수 없어요';

  @override
  String get fileMessageOpenFailed => '파일을 열지 못했어요';

  @override
  String get fileMessageDefaultName => '문서';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return '$name 저장';
  }

  @override
  String fileMessageViewSemanticLabel(Object name) {
    return '$name 보기';
  }

  @override
  String get textFileViewerDownloadTooltip => '다운로드';

  @override
  String get textFileViewerTruncatedNotice =>
      '이 파일의 일부만 표시됩니다 — 나머지를 보려면 다운로드하세요.';

  @override
  String get fileMessageUploadFailedLabel => '실패';

  @override
  String get fileMessageSendingLabel => '보내는 중…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · 보내는 중…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return '$count분 전';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return '$count시간 전';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return '$count일 전';
  }

  @override
  String get fileMessageStandardBadge => '일반';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '받은 메시지 초안 $count개 · 눌러서 보기',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => '요청 수락';

  @override
  String get fileMessageDeclineButton => '요청 거절';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return '$ago 보냄';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '보낸 메시지 초안 $count개 대기 중',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => '요청 취소';

  @override
  String get destructiveSheetCannotBeUndone => '되돌릴 수 없어요';

  @override
  String get destructiveSheetCancelSemanticLabel => '취소';

  @override
  String get destructiveSheetCancelButtonLabel => '취소';

  @override
  String get destructiveSheetHideLabel => '숨기기';

  @override
  String get destructiveSheetViewLabel => '보기';

  @override
  String get destructiveSheetPairingMintError => '코드를 만들지 못했어요. 다시 시도해 주세요.';

  @override
  String get destructiveSheetPairingReleaseTitle => '반납';

  @override
  String get destructiveSheetPairingPairTitle => '페어링';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return '$name의 휴대폰에서 프로필을 열고 “이 휴대폰 돌려주기”를 탭한 다음, 이 숫자를 입력하세요.';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return '$name의 휴대폰에서 MonkeyHub를 열고 이걸 스캔하거나 숫자를 입력하세요.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => '코드가 만료됐어요';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return '$time 후 만료돼요';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => '새 코드';

  @override
  String get destructiveSheetPairingOneUseNote =>
      '한 번만 사용할 수 있어요. 새 코드를 만들면 기존 코드는 취소돼요.';

  @override
  String get deepOceanThemeAttachButtonLabel => '첨부';

  @override
  String get deepOceanThemeCameraButtonLabel => '카메라';

  @override
  String get deepOceanThemeSendButtonLabel => '보내기';

  @override
  String get deepOceanThemeEphemeralHint => '속삭여보세요…';

  @override
  String get deepOceanThemeDefaultHint => '아무 말이나 해보세요…';

  @override
  String get deepOceanThemeMessageHint => '메시지';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => '파일을 찾을 수 없어요';

  @override
  String get photoChromeMediaYouLabel => '나';

  @override
  String get photoChromeCloseSemanticLabel => '닫기';

  @override
  String get photoChromeFillToggleSemanticLabel => '화면에 맞추기 또는 꽉 채우기';

  @override
  String get photoChromeShowInChatSemanticLabel => '채팅에서 보기';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return '$total개 중 $current번째';
  }

  @override
  String photoTrayCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '사진 $count장',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => '이 사진들 취소';

  @override
  String get photoTrayRemoveSemanticLabel => '이 사진 빼기';

  @override
  String get photoTrayEditSemanticLabel => '이 사진 자르기 또는 그리기';

  @override
  String get photoTrayAddMoreSemanticLabel => '사진 더 추가';

  @override
  String photoTrayLimitSnack(Object count) {
    return '한 번에 사진 $count장까지 보낼 수 있어요';
  }

  @override
  String get photoTrayLoadFailedSnack => '일부 사진을 열 수 없었어요';

  @override
  String get mediaPickFailedMessage => '열 수 없었어요 — 다시 선택해 주세요';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name님이 입력 중이에요';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1님과 $name2님이 입력 중이에요';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1, $name2 외 $extra명이 입력 중이에요';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => '수신 전화';

  @override
  String get typingIndicatorIncomingVideoCallLabel => '수신 영상통화';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => '수신 음성통화';

  @override
  String get typingIndicatorDeclineButtonLabel => '거절';

  @override
  String get typingIndicatorDeclineButtonDeclining => '거절 중…';

  @override
  String get typingIndicatorAcceptButtonLabel => '수락';

  @override
  String get typingIndicatorAcceptButtonConnecting => '연결 중…';

  @override
  String get messageStampNavigationTitle => '내비게이션.';

  @override
  String get messageStampNavigationSubtitle =>
      '채팅, 디스커버, 피드, 설정 사이를 이동하는 방식이에요';

  @override
  String get messageStampRadialOrbLabel => '방사형 오브';

  @override
  String get messageStampRadialOrbDescription =>
      '모서리를 길게 눌러 드래그하세요. 평소엔 조용히 있다가, 쓸수록 손에 익는 제스처예요.';

  @override
  String get messageStampBottomPillLabel => '하단 캡슐';

  @override
  String get messageStampBottomPillDescription =>
      '고전적인 탭 방식. 항상 보이고, 따로 배울 필요가 없어요.';

  @override
  String get messageStampActiveLabel => '사용 중';

  @override
  String get messageStampUploadingLabel => '업로드 중';

  @override
  String get messageStampSendingLabel => '전송 중';

  @override
  String get messageStampFailedToSendLabel => '전송 실패';

  @override
  String get messageStampSentLabel => '전송됨';

  @override
  String get messageStampDeliveredLabel => '전달됨';

  @override
  String get messageStampSeenLabel => '읽음';

  @override
  String get messageStampSavedLabel => '저장됨';

  @override
  String messageStampCountdownSeconds(Object count) {
    return '$count초';
  }

  @override
  String messageStampCountdownMinutes(Object count) {
    return '$count분';
  }

  @override
  String get voiceRecorderScreenMicPermissionDeniedSnackbar => '마이크 권한이 거부되었어요';

  @override
  String get voiceRecorderScreenStatusRecording => '녹음 중';

  @override
  String get voiceRecorderScreenStatusReady => '준비 완료';

  @override
  String get voiceRecorderScreenStatusTapToStart => '탭하여 시작';

  @override
  String get voiceRecorderScreenReRecordButton => '다시 녹음';

  @override
  String get voiceRecorderScreenStopButton => '정지';

  @override
  String get voiceRecorderScreenSendButton => '보내기';

  @override
  String get voiceRecorderScreenRecordButton => '녹음';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => '모두';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => '전체 알림';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => '방장';

  @override
  String get releaseDeviceScreenFallbackChildName => '아이';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return '$name님을 이 휴대폰에서 로그아웃시키고 원래대로 돌려놔요 — 휴대폰은 원래의 로그인 화면으로 돌아가고, 누구나 사용할 수 있어요.';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      '계정, 메시지, 친구 목록은 모두 그대로 유지돼요. 언제든 다시 로그인할 수 있어요.';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return '보호자에게 MonkeyHub를 열고, 가족에서 $name님을 찾아 \"해제\"를 눌러 달라고 부탁하세요.';
  }

  @override
  String get releaseDeviceScreenOrDivider => '또는';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      '휴대폰이 이거 하나뿐이라면, 보호자가 여기서 대신 로그인할 수 있어요.';

  @override
  String get releaseDeviceScreenUsernameHint => '보호자의 아이디';

  @override
  String get releaseDeviceScreenPasswordHint => '비밀번호';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => '로그아웃';

  @override
  String get releaseDeviceScreenChecking => '확인 중…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return '$name님 로그아웃';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => '이 휴대폰 돌려주기';

  @override
  String get releaseDeviceScreenErrorCodeExpired => '코드가 만료됐어요. 새 코드를 요청해 주세요.';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      '코드가 작동하지 않았어요. 이미 사용된 코드일 수 있어요.';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      '작동하지 않았어요. 아이디와 비밀번호를 확인해 주세요.';

  @override
  String get releaseDeviceScreenErrorGeneric => '문제가 발생했어요. 다시 시도해 주세요.';

  @override
  String get activeCallPillMoveHereSemanticLabel => '통화를 이 기기로 옮기기';

  @override
  String activeCallPillCallWith(Object name) {
    return '$name님과 통화 중';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return '$device에서';
  }

  @override
  String get activeCallPillMoveHereLabel => '여기로 이동';

  @override
  String get activeCallPillUnknownCaller => '알 수 없음';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'iOS 시뮬레이터';

  @override
  String get activeCallPillPlatformAndroid => 'Android 기기';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'Windows PC';

  @override
  String get activeCallPillPlatformLinux => 'Linux 기기';

  @override
  String get activeCallPillPlatformBrowser => '브라우저';

  @override
  String get activeCallPillPlatformOther => '다른 기기';

  @override
  String get activeCallPillPinnedHeader => '고정된 메시지';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return '고정된 메시지 · $count';
  }

  @override
  String get activeCallPillNothingPinned => '더 이상 고정된 메시지가 없어요';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return '$name님의 메시지로 이동';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return '$name님의 메시지 고정 해제';
  }

  @override
  String get callButtonErrorBusy => '다른 통화 중이에요';

  @override
  String get callButtonErrorCallFailed => '통화를 시작할 수 없어요';

  @override
  String get callButtonErrorNotMember => '이 방의 멤버가 아니에요';

  @override
  String get callButtonErrorGeneric => '통화를 시작할 수 없어요';

  @override
  String get callButtonAlreadyOnCall => '이미 통화 중이에요';

  @override
  String get callButtonBusyElsewhere => '다른 기기에서 통화 중이에요';

  @override
  String get callButtonVoiceCallTooltip => '음성 통화';

  @override
  String get callButtonVideoCallTooltip => '영상 통화';

  @override
  String get callButtonTooltip => '통화';

  @override
  String get callButtonReplyStyleTitle => '답장 스타일.';

  @override
  String get callButtonReplyStyleSubtitle => '답장이 원본 메시지를 어떻게 보여주는지';

  @override
  String get callButtonReplyStylePhantomEchoLabel => '고스트 에코';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      '부모 메시지의 고스트 말풍선이 곡선형 연결선으로 위에 떠 있고, 연결 지점에 분기 아이콘이 표시돼요.';

  @override
  String get callButtonReplyStyleStickyNoteLabel => '포스트잇';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      '살짝 기울어진 폴라로이드 스타일 카드가 말풍선 모서리에 끼워져 있어요.';

  @override
  String get callButtonReplyStyleComicTailLabel => '코믹 꼬리';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      '작은 부모 미니 말풍선에 아래를 향한 만화책 스타일 삼각형 꼬리가 달려 있어요.';

  @override
  String get callButtonReplyStyleClassicLabel => '클래식';

  @override
  String get callButtonReplyStyleClassicDescription =>
      '포인트 컬러의 인용구 캡슐에 연결선 바와 아바타가 더해진, 익숙한 왓츠앱 스타일이에요.';

  @override
  String get callButtonReplyStyleActiveBadge => '활성';

  @override
  String get callButtonReplyPreviewSampleMessage => '근데 새 데모 봤어?';

  @override
  String get callButtonReplyPreviewSampleReply => '응, 그 블러 완전 미쳤어.';

  @override
  String get childSetupScreenErrorPickUsername => '아이의 사용자 이름을 정해 주세요.';

  @override
  String get childSetupScreenErrorUsernameTaken => '이미 사용 중인 사용자 이름이에요.';

  @override
  String get childSetupScreenErrorChildNotAllowed => '보호자 계정만 아이를 추가할 수 있어요.';

  @override
  String get childSetupScreenErrorGeneric => '계정을 만들지 못했어요. 다시 시도해 주세요.';

  @override
  String get childSetupScreenTitle => '아이 추가';

  @override
  String get childSetupScreenHeading => '이 아이는\n누구인가요?';

  @override
  String get childSetupScreenNameLabel => '이름';

  @override
  String get childSetupScreenNameHint => '부르는 이름';

  @override
  String get childSetupScreenUsernameLabel => '사용자 이름';

  @override
  String get childSetupScreenUsernameHint => '친구가 찾는 이름';

  @override
  String get childSetupScreenWhatTheyGetTitle => '아이가 할 수 있는 것';

  @override
  String get childSetupScreenBulletTalkImmediately =>
      '아이는 보호자님과 형제자매와 바로 대화할 수 있어요.';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      '그 밖의 모든 사람은 먼저 보호자의 승인이 필요해요 — 아이가 요청한 사람이든, 아이에게 요청한 사람이든요.';

  @override
  String get childSetupScreenBulletPublicRoomsOff =>
      '공개방은 보호자가 켜 주기 전까지 꺼져 있어요.';

  @override
  String get childSetupScreenBulletCantSignOut =>
      '아이는 로그아웃할 수 없고, 보호자는 언제든 아이의 상태를 확인할 수 있어요.';

  @override
  String get childSetupScreenCreateButton => '만들기 + 페어링';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return '$name에게 메시지 보내기';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => '요청함';

  @override
  String get childSetupScreenMemberCountUnitLabel => '명';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return '전체 $count개 보기';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return '전체 $count개 보기';
  }

  @override
  String get bubbleStyleScreenTitle => '말풍선 스타일.';

  @override
  String get bubbleStyleScreenSubtitle => '말이 도착하는 모양';

  @override
  String get bubbleStyleScreenTailedLabel => '꼬리형';

  @override
  String get bubbleStyleScreenTailedDescription =>
      '메시지 묶음마다 꼬리로 끝을 맺고, 위쪽 줄들은 하나의 블록으로 좁혀져요.';

  @override
  String get bubbleStyleScreenSoftLabel => '소프트';

  @override
  String get bubbleStyleScreenSoftDescription =>
      '꼬리 없음 — 이어지는 말풍선이 안쪽 모서리만 좁아지며 하나로 붙어요.';

  @override
  String get bubbleStyleScreenPillLabel => '캡슐';

  @override
  String get bubbleStyleScreenPillDescription => '완전히 둥근 캡슐 모양, 모든 줄에서 동일해요.';

  @override
  String get bubbleStyleScreenSlabLabel => '슬래브';

  @override
  String get bubbleStyleScreenSlabDescription =>
      '각진 모서리 — 날카롭고, 인쇄된 듯하고, 의도적이에요.';

  @override
  String get bubbleStyleScreenActiveBadge => '적용됨';

  @override
  String get bubbleStyleScreenPreviewQuestion => '그래서, 어때 보여요?';

  @override
  String get bubbleStyleScreenPreviewReplyOne => '나아요';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => '훨씬 나아요';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => '동영상';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => '사진';

  @override
  String get incomingGroupCallScreenCallFullError =>
      '참여하려는 통화방이 가득 찼어요 (최대 6명)';

  @override
  String get incomingGroupCallScreenJoinFailedError => '통화에 참여하지 못했어요';

  @override
  String get incomingGroupCallScreenDefaultRoomName => '그룹 통화';

  @override
  String get incomingGroupCallScreenDefaultStarterName => '누군가';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starter님이 영상 통화를 시작했어요';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starter님이 음성 통화를 시작했어요';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '이미 $count명 참여 중';
  }

  @override
  String get incomingGroupCallScreenDismissButton => '거절';

  @override
  String get incomingGroupCallScreenJoinButton => '참여';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '채팅 $count개',
    );
    return '$_temp0';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '메시지 $count개',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      '마지막 메시지 방금 전';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return '마지막 메시지 $hours시간 전';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      '마지막 메시지 어제';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return '마지막 메시지 $days일 전';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      '마지막 메시지 오래전';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => '연결 끊기';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return '$childName과(와) $contactName의 연결을 끊을까요?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      '더 이상 서로에게 연락할 수 없고, 나눈 대화도 함께 사라져요.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return '더 이상 서로에게 연락할 수 없어요. $contactName에게는 알리지 않아요.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats · $messages가 삭제돼요';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      '사진과 음성 메모를 포함해 두 사람 모두에게서 사라져요. 되돌릴 수 없어요.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '그 외에도 함께 있는 방이 $count개 있어요',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      '이 룸들은 그대로 남아요. 빼고 싶으면 아래 룸 목록에서 직접 빼주세요.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      '제거 및 삭제';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return '$contactName님을 제거하고 $messages을(를) 삭제해요.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return '$contactName님을 허용 목록에서 제거해요.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      '취소';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => '취소';

  @override
  String get groupCallBannerCallFullError => '통화 인원이 가득 찼어요 (최대 6명)';

  @override
  String get groupCallBannerJoinFailedError => '통화에 참가할 수 없어요';

  @override
  String get groupCallBannerUnknownParticipant => '누군가';

  @override
  String get groupCallBannerOngoingVideoCall => '진행 중인 영상 통화';

  @override
  String get groupCallBannerOngoingVoiceCall => '진행 중인 음성 통화';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra 통화 중';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => '통화 참가';

  @override
  String get groupCallBannerJoinButtonLabel => '참가';

  @override
  String get groupCallBannerJoinRoomSheetTitle => '룸 참가';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => '비밀번호';

  @override
  String get groupCallBannerPasswordHint => '암호…';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => '참가';

  @override
  String get groupCallBannerJoinRoomButtonLabel => '참가';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => '취소';

  @override
  String get groupCallBannerCancelButtonLabel => '취소';

  @override
  String get viewOnceViewerBadgeLabel => '한 번만 보기';

  @override
  String get socialButtonDividerOr => '또는';

  @override
  String get socialButtonGoogleContinue => 'Google로 계속하기';

  @override
  String get discoverListsPeopleTitle => '내 사람들.';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => '내 사람들 검색…';

  @override
  String get discoverListsClearFilterSemanticLabel => '필터 지우기';

  @override
  String get discoverListsNoOneYet => '아직 아무도 없어요';

  @override
  String discoverListsNoMatches(Object query) {
    return '\"$query\"에 해당하는 사람이 없어요';
  }

  @override
  String get discoverListsRoomsTitle => '내 채팅방.';

  @override
  String discoverListsRoomsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterRoomsHint => '내 채팅방 검색…';

  @override
  String get discoverListsNoRoomsYet => '아직 채팅방이 없어요';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return '\"$query\"에 해당하는 채팅방이 없어요';
  }

  @override
  String get discoverListsVoiceCallLabel => '음성 통화';

  @override
  String get discoverListsVideoCallLabel => '영상 통화';

  @override
  String get approvalGateAlreadyAskedLabel => '이미 요청함';

  @override
  String get approvalGateAskGrownUpLabel => '보호자에게 물어보기';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return '$what에 대해 이미 물어봤어요.';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return '$what 전에 보호자의 허락이 필요해요.';
  }

  @override
  String get approvalGateDisabledBody => '지금은 보호자가 이 기능을 꺼두었어요.';

  @override
  String get approvalGateAlreadyAskedFooter =>
      '보호자에게 메시지가 전달될 거예요. 잠시 후 다시 확인해 보세요.';

  @override
  String get approvalGateWillNotifyFooter => '보호자에게 알려드릴게요. 답이 오면 여기에 표시돼요.';

  @override
  String get approvalGateTalkToThemFooter => '이 설정을 바꾸고 싶다면 보호자와 직접 이야기해 보세요.';

  @override
  String get approvalGateAskButton => '물어보기';

  @override
  String get approvalGateNotNowButton => '나중에';

  @override
  String get approvalGateOkButton => '확인';

  @override
  String get approvalGateWaitingPillLabel => '보호자 대기 중';

  @override
  String get reportSheetTitle => '신고';

  @override
  String get reportSheetSubtitle => '어떤 문제인지 알려주세요.';

  @override
  String get reportSheetPrivacyNote => '신고 내용은 비공개예요. 상대방에게 알림이 가지 않아요.';

  @override
  String get reportSheetReasonSpamLabel => '스팸';

  @override
  String get reportSheetReasonSpamDescription => '원치 않는 광고나 반복되는 메시지';

  @override
  String get reportSheetReasonHarassmentLabel => '괴롭힘';

  @override
  String get reportSheetReasonHarassmentDescription => '특정인을 노리거나 괴롭히기';

  @override
  String get reportSheetReasonImpersonationLabel => '사칭';

  @override
  String get reportSheetReasonImpersonationDescription => '다른 사람인 척하기';

  @override
  String get reportSheetReasonInappropriateLabel => '부적절한 콘텐츠';

  @override
  String get reportSheetReasonInappropriateDescription =>
      '선정적이거나 폭력적이거나 불법적인 콘텐츠';

  @override
  String get reportSheetReasonOtherLabel => '기타';

  @override
  String get reportSheetReasonOtherDescription => '그 외 다른 문제';

  @override
  String get reportSheetOtherNoteHint => '무슨 일이 있었나요?';

  @override
  String get reportSheetSubmitSemanticLabel => '신고 제출';

  @override
  String get reportSheetSubmitButton => '제출';

  @override
  String get reportSheetUpdateRequiredTitle => '업데이트 필요';

  @override
  String get reportSheetUpdateAvailableTitle => '업데이트 가능';

  @override
  String get reportSheetUpdateMandatoryBody =>
      '이 버전은 너무 오래되어 정상적으로 작동하지 않아요. 계속하려면 업데이트해 주세요.';

  @override
  String get reportSheetUpdateAvailableBody => 'MonkeyHub의 새 버전이 있어요.';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => '업데이트';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'TestFlight에서 열려요';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'App Store에서 열려요';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'Google Play가 열려요';

  @override
  String get reportSheetUpdateActionOpensDownloadPage => '다운로드 페이지가 열려요';

  @override
  String get reportSheetUpdateActionReloads => '새 버전으로 새로고침돼요';

  @override
  String get reportSheetUpdateLaterSemanticLabel => '나중에';

  @override
  String get reportSheetUpdateLaterButton => '나중에';

  @override
  String get roomFilterBarAllChipLabel => '전체';

  @override
  String roomFilterBarChipCountSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '채팅 $count개',
    );
    return '$label, $_temp0';
  }

  @override
  String composerReplyCardReplyingToLabel(Object name) {
    return '$name님에게 답장';
  }

  @override
  String get roomCardLockedBadge => '잠김';

  @override
  String get roomCardTimeAgoJustNow => '방금 전';

  @override
  String roomCardTimeAgoSeconds(Object seconds) {
    return '$seconds초';
  }

  @override
  String roomCardTimeAgoMinutes(Object minutes) {
    return '$minutes분';
  }

  @override
  String roomCardTimeAgoHours(Object hours) {
    return '$hours시간';
  }

  @override
  String roomCardTimeAgoDays(Object days) {
    return '$days일';
  }

  @override
  String roomCardTimeAgoWeeks(Object weeks) {
    return '$weeks주';
  }

  @override
  String roomCardStartedAgo(Object ago) {
    return '$ago 전에 생성';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count명 참여 중';
  }

  @override
  String get roomCardMessagesFadeLabel => '메시지 사라짐';

  @override
  String get roomCardEnterLabel => '↗ 입장';

  @override
  String get roomCardBlockedScreenTitle => '차단 목록';

  @override
  String get roomCardBlockedEmptyState => '아직 차단한 사람이 없어요.';

  @override
  String get roomCardUnblockButton => '차단 해제';

  @override
  String get attachmentMenuPhotoLabel => '사진';

  @override
  String get attachmentMenuVideoLabel => '동영상';

  @override
  String get attachmentMenuCameraLabel => '카메라';

  @override
  String get attachmentMenuVoiceLabel => '음성';

  @override
  String get attachmentMenuFileLabel => '파일';

  @override
  String get attachmentMenuConnectionRetrying => '재시도 중…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      '서버에 연결할 수 없어요 · 탭하여 재시도';

  @override
  String get attachmentMenuConnectionReconnecting => '다시 연결하는 중…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel => '연결 재시도';

  @override
  String get roomGridTileEmptyLastMessage => '아직 조용해요';

  @override
  String get roomGridTileMemberCountLabel => '참여';

  @override
  String get roomGridTileThemeChipLabel => '테마';

  @override
  String get bulkActionBarCancelLabel => '취소';

  @override
  String get bulkActionBarSelectMessagesLabel => '메시지 선택';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count개 선택됨';
  }

  @override
  String get bulkActionBarForwardLabel => '전달';

  @override
  String get bulkActionBarDeleteLabel => '삭제';

  @override
  String get bulkActionBarJumpBackLabel => '뒤로';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return '뒤로 · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel => '이동하기 전 위치로 돌아가기';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return '이동하기 전 위치로 돌아가기, $depth개 남음';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote => '상대방에게는 알림이 가지 않아요.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      '현재 친구 사이예요 — 차단하면 친구 관계가 해제되며, 나중에 다시 연결하려면 새로 친구 요청을 보내야 해요.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      '상대방은 검색 결과에서 사라지고 더 이상 메시지를 보낼 수 없게 돼요.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => '차단';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return '$name님을 차단할까요?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이 사람과 함께 있는 방이 $count개예요',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      '이 방들은 그대로 유지돼요. 필요하다면 각 방의 설정에서 직접 나갈 수 있어요.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => '차단';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      '친구 관계를 해제하고 차단해요. 기존 대화 기록은 보관함에 남아요.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      '상대방은 검색에서 숨겨지고 더 이상 연락할 수 없게 돼요.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => '차단 및 DM 삭제';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      '상대방과의 DM도 함께 삭제돼요 — 모든 메시지, 반응, 미디어 파일이 사라져요.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => '취소';

  @override
  String get bulkActionBarBlockSheetCancelLabel => '취소';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle => '잠금 화면에 수신 전화 표시';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      '화면이 꺼져 있을 때도 실제 전화처럼 벨이 울리게 하려면 MonkeyHub에 \'전체 화면 알림\' 권한이 필요해요. 다음 화면에서 바로 설정으로 이동할 수 있어요.';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle => '전화를 놓치지 마세요';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      '일부 휴대폰은 배터리를 절약하기 위해 백그라운드 앱을 일시 정지하는데, 이로 인해 수신 전화가 울리지 않을 수 있어요. MonkeyHub가 제한 없이 실행되도록 허용하면 전화가 항상 제대로 수신돼요.';

  @override
  String get bulkActionBarDialogNotNowButton => '나중에';

  @override
  String get bulkActionBarDialogContinueButton => '계속';

  @override
  String get reactionBubbleJumpToLatestLabel => '최신으로 이동';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel => '최신으로 이동';

  @override
  String get reactionBubblePickerTitle => '반응';

  @override
  String get reactionBubbleNoRecentsPlaceholder => '아직 최근 사용한 이모지가 없어요';

  @override
  String get reactionBubbleSearchHint => '이모지 검색';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => '일치하는 이모지 없음';

  @override
  String get reactionBubbleSearchBackSemanticLabel => '이모지로 돌아가기';

  @override
  String get reactionBubblePasswordHint => '비밀번호';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return '$roomName에 참여';
  }

  @override
  String get enterPublicRoomAskFailedMessage => '지금은 요청할 수 없어요 — 다시 시도해 주세요';

  @override
  String get enterPublicRoomWrongPasswordMessage => '비밀번호가 틀렸어요';

  @override
  String get enterPublicRoomJoinFailedMessage => '참여하지 못했어요. 다시 시도해 주세요';

  @override
  String get feedBoardTitle => '오늘';

  @override
  String feedBoardEditionLabel(Object number) {
    return '제$number호';
  }

  @override
  String get feedBoardHighlightsLabel => '하이라이트';

  @override
  String get feedBoardHighlightsEmpty => '오늘은 아직 아무것도 없어요';

  @override
  String get feedBoardPuzzleLabel => '퍼즐';

  @override
  String get feedBoardPuzzleEmpty => '오늘의 퍼즐은 아직 준비 중이에요';

  @override
  String get feedBoardStandingsLabel => '라이프 포인트';

  @override
  String get feedBoardStandingsEmpty => '오늘은 아직 점수가 없어요';

  @override
  String get feedBoardActivityLabel => '활동';

  @override
  String get feedBoardActivityEmpty => '오늘은 아직 조용해요';

  @override
  String get feedBoardActivityNoFriends => '친구를 추가하면 친구의 하루가 여기에 나타나요';

  @override
  String get feedBoardLoadFailed => '보드를 불러오지 못했어요 — 잠시 후 다시 시도해 주세요';

  @override
  String get enterPublicRoomVisibilityPublicLabel => '공개';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => '비공개';

  @override
  String get enterPublicRoomJoinedBadgeLabel => '참여 중';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return '휘발성 · $duration';
  }

  @override
  String enterPublicRoomEphemeralSecondsShort(Object seconds) {
    return '$seconds초';
  }

  @override
  String enterPublicRoomEphemeralMinutesShort(Object minutes) {
    return '$minutes분';
  }

  @override
  String enterPublicRoomEphemeralHoursShort(Object hours) {
    return '$hours시간';
  }

  @override
  String get roomBadgePublicTooltip => '누구나 이 방을 찾아서 참여할 수 있어요';

  @override
  String get roomBadgePrivateTooltip => '초대 전용이라 탐색에 나오지 않아요';

  @override
  String get roomBadgeLockedTooltip => '참여하려면 방 비밀번호가 필요해요';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return '메시지는 $duration 뒤에 사라져요';
  }

  @override
  String get roomBadgeJoinedTooltip => '이미 이 방에 있어요';

  @override
  String get roomInfoSheetDetailsLabel => '세부 정보';

  @override
  String get roomInfoSheetNoDescription => '아직 설명이 없어요';

  @override
  String get roomInfoSheetCreatedLabel => '생성일';

  @override
  String get countBadgeCaptureProtectionLabel => '화면 캡처 보호';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      '스크린샷과 화면 녹화가 시스템에는 검은 화면으로 나와요.';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      '화면 녹화나 미러링을 하면 앱 위에 프라이버시 보호막이 표시돼요.';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      '휘발성 방이 아니면 스크린샷과 화면 녹화가 평소처럼 동작해요.';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      '휘발성 방(일명 \'비밀의 방\')은 이 설정과 상관없이 항상 켜져 있어요.';

  @override
  String get countBadgeShowPasswordTooltip => '비밀번호 표시';

  @override
  String get countBadgeHidePasswordTooltip => '비밀번호 숨기기';

  @override
  String get countBadgeProtectedLabel => '보호됨';

  @override
  String get countBadgeCaptureShieldActiveBody => '화면 녹화 또는 미러링이 진행 중이에요.';

  @override
  String get countBadgeCaptureShieldReassurance => '녹화 화면에는 대화 내용이 보이지 않아요.';

  @override
  String get linkOpenerCouldNotOpenLink => '링크를 열지 못했어요';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel => '복구 문구 설정하기';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      '복구 문구가 없어요 — 계정을 잃으면 다시 들어올 수 없어요.';

  @override
  String get destinationsChatLabel => '채팅';

  @override
  String get destinationsChatShort => '채팅';

  @override
  String get destinationsDiscoverLabel => '탐색';

  @override
  String get destinationsDiscoverShort => '찾기';

  @override
  String get destinationsFeedLabel => '피드';

  @override
  String get destinationsFeedShort => '피드';

  @override
  String get destinationsSettingsLabel => '설정';

  @override
  String get destinationsSettingsShort => '설정';

  @override
  String get familyRequestStageSenderGuardianLabel => '보호자 대기 중';

  @override
  String get familyRequestStageRecipientLabel => '상대방 대기 중';

  @override
  String get roomContentTabLabelMedia => '미디어';

  @override
  String get roomContentTabLabelFiles => '파일';

  @override
  String get roomContentTabLabelVoice => '음성';

  @override
  String get roomContentTabLabelLinks => '링크';

  @override
  String get roomContentTabLabelSaved => '저장됨';

  @override
  String get roomContentTabHeaderMedia => '미디어';

  @override
  String get roomContentTabHeaderFiles => '파일';

  @override
  String get roomContentTabHeaderVoice => '음성';

  @override
  String get roomContentTabHeaderLinks => '링크';

  @override
  String get roomContentTabHeaderSaved => '저장됨';

  @override
  String get roomFacetLabelDms => '1:1 채팅';

  @override
  String get roomFacetLabelGroups => '그룹';

  @override
  String get roomFacetLabelPublic => '공개';

  @override
  String get roomFacetLabelPrivate => '비공개';

  @override
  String get roomFacetLabelSecret => '시크릿';

  @override
  String get roomFacetLabelLocked => '잠금';

  @override
  String get roomFacetLabelUnread => '읽지 않음';

  @override
  String get roomFacetLabelMentions => '멘션';

  @override
  String get settingsScreenTitle => '설정';

  @override
  String get settingsScreenTagline => '생김새. 분위기. 당신답게.';

  @override
  String get settingsScreenAccountHintChild => '프로필 · 개인정보 · 내 보호자';

  @override
  String get settingsScreenAccountHintAdult => '프로필 · 가족 · 연결된 계정 · 개인정보';

  @override
  String get settingsScreenSectionAppearance => '외관';

  @override
  String get settingsScreenSectionChat => '채팅';

  @override
  String get settingsScreenSectionCompanions => '동반자';

  @override
  String get settingsScreenSectionGeneral => '일반';

  @override
  String get settingsScreenCheckForUpdatesLabel => '업데이트 확인';

  @override
  String get settingsScreenUpdateAvailableValue => '업데이트 있음';

  @override
  String get settingsScreenUpdateUpToDateSnackbar => '최신 버전을 사용 중입니다.';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      '이 빌드에서는 업데이트를 확인할 수 없습니다.';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      '업데이트를 확인할 수 없습니다. 나중에 다시 시도해 주세요.';

  @override
  String get settingsScreenSectionNotifications => '알림';

  @override
  String get reportProblemRowLabel => '문제 신고';

  @override
  String get reportProblemRowValue => '자세한 내용을 보내주세요';

  @override
  String get reportProblemIntro =>
      '무엇이 잘못되었는지 알려주세요. 앱과 기기 정보, 그리고 그때 앱이 무엇을 하고 있었는지 담은 기술 로그가 자동으로 함께 첨부됩니다. 원인을 찾는 데 바로 이것이 도움이 됩니다.';

  @override
  String get reportProblemDescribeLabel => '무슨 일이 있었나요';

  @override
  String get reportProblemDescribeHint => '화면이 깜빡여요, 버튼이 반응하지 않아요…';

  @override
  String get reportProblemScreenshotsLabel => '스크린샷';

  @override
  String get reportProblemAddScreenshot => '스크린샷 추가';

  @override
  String get reportProblemDetailsLabel => '내 정보';

  @override
  String get reportProblemCopyDetails => '정보 복사';

  @override
  String get reportProblemCopied => '복사됨';

  @override
  String get reportProblemSend => '신고 보내기';

  @override
  String get reportProblemSent => '신고를 보냈어요. 감사합니다!';

  @override
  String get reportProblemSendFailed => '신고를 보내지 못했어요. 연결을 확인하고 다시 시도해 주세요.';

  @override
  String get reportProblemTooMany => '짧은 시간에 신고를 너무 많이 보냈어요. 잠시 후에 다시 시도해 주세요.';

  @override
  String get reportProblemShakeTitle => '문제를 신고할까요?';

  @override
  String get reportProblemShakeBody => '기기를 흔드셨네요. 신고 화면을 열까요?';

  @override
  String get reportProblemShakeOpen => '신고';

  @override
  String get reportProblemShakeDismiss => '나중에';

  @override
  String get settingsCallDeliveryLockScreenLabel => '잠금 화면 통화';

  @override
  String get settingsCallDeliveryBackgroundLabel => '백그라운드 활동';

  @override
  String get settingsCallDeliveryStatusOff => '탭하여 허용';

  @override
  String get settingsScreenRowTheme => '테마';

  @override
  String get settingsScreenRowAppLogo => '앱 로고';

  @override
  String get settingsScreenRowGlass => '글래스';

  @override
  String get settingsScreenRowChatList => '채팅 목록';

  @override
  String get settingsScreenRowNavigation => '내비게이션';

  @override
  String get settingsScreenRowChatStyle => '채팅 스타일';

  @override
  String get settingsScreenRowBubbleStyle => '말풍선 스타일';

  @override
  String get settingsScreenRowReplyStyle => '답장 스타일';

  @override
  String get settingsScreenValueScrollList => '스크롤 목록';

  @override
  String get settingsScreenValueGridSheet => '그리드 시트';

  @override
  String get settingsScreenValueRadialOrb => '방사형 오브';

  @override
  String get settingsScreenValueBottomPill => '하단 캡슐';

  @override
  String get settingsScreenValueCustom => '커스텀';

  @override
  String settingsScreenValueEdited(Object name) {
    return '$name · 수정됨';
  }

  @override
  String get settingsScreenValueClassic => '클래식';

  @override
  String get settingsScreenValueCompact => '컴팩트';

  @override
  String get settingsScreenValueBubbleTailed => '꼬리형';

  @override
  String get settingsScreenValueBubbleSoft => '소프트';

  @override
  String get settingsScreenValueBubblePill => '캡슐';

  @override
  String get settingsScreenValueBubbleSlab => '슬래브';

  @override
  String get settingsScreenValueReplyPhantomEcho => '고스트 에코';

  @override
  String get settingsScreenValueReplyStickyNote => '포스트잇';

  @override
  String get settingsScreenValueReplyComicTail => '코믹 꼬리';

  @override
  String get settingsScreenValueLogoAuto => '자동';

  @override
  String get settingsScreenValueLogoManual => '수동';

  @override
  String get settingsScreenShowLinkUrlsLabel => '링크 URL 표시';

  @override
  String get settingsScreenLinksUrlsOnBody => '미리보기 카드와 함께 원본 URL이 표시돼요';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      '지금은 미리보기만 표시돼요 — 말풍선이 깔끔해지고, 탭하면 열려요';

  @override
  String get settingsScreenMenuBarLabel => '메뉴 막대 아이콘';

  @override
  String get settingsScreenMenuBarOnBody =>
      'MonkeyHub가 읽지 않은 개수와 함께 메뉴 막대에 표시됩니다 — 클릭하면 창이 열립니다';

  @override
  String get settingsScreenMenuBarOffBody =>
      '현재 꺼짐 — 숨긴 창으로 돌아가는 방법은 Dock 아이콘뿐입니다';

  @override
  String get settingsScreenSectionCalls => '통화';

  @override
  String get settingsScreenRowVideoQuality => '화질';

  @override
  String get settingsScreenValueVideoQualityAuto => '자동';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel => '통화 통계 표시';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      '통화 중 실시간 해상도, 비트레이트, 핑, 패킷 손실을 표시해요';

  @override
  String get videoQualityScreenTitle => '화질';

  @override
  String get videoQualityScreenSubtitle => '발신 영상의 해상도 상한을 선택하세요';

  @override
  String get videoQualityScreenAutoSubtitle => '연결 상태에 자동으로 맞춰져요';

  @override
  String get videoQualityScreenHd1080Subtitle =>
      'Full HD — 더 선명하지만 데이터를 더 사용해요';

  @override
  String get videoQualityScreenUhd4kSubtitle => 'Ultra HD — 강한 연결에서 가장 좋아요';

  @override
  String get videoQualityScreenFootnote =>
      '실제 해상도는 양쪽 기기의 카메라와 네트워크 상태에 따라 달라져요.';

  @override
  String get callScreenControlOptions => '더보기';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => '지터';

  @override
  String get callScreenStatsLossLabel => '손실';

  @override
  String get callScreenSwapPreviewSemanticLabel => '카메라 화면 전환';

  @override
  String get callOptionsSheetTitle => '통화 옵션';

  @override
  String get settingsScreenPushNotificationsLabel => '푸시 알림';

  @override
  String get settingsScreenPushOnBody => '새 메시지와 요청이 오면 알려드려요';

  @override
  String get settingsScreenPushOffBody => '알림 없이 조용해요 — 앱을 열어야 확인할 수 있어요';

  @override
  String get settingsScreenGameRemindersLabel => '매일 게임 알림';

  @override
  String get settingsScreenGameRemindersOnBody => '점심 무렵에 한 번, 아직 안 했을 때만';

  @override
  String get settingsScreenGameRemindersOffBody => '알림 없음 — 게임은 열어보면 그대로 있어요';

  @override
  String get authErrorUsernameTaken => '이미 사용 중인 사용자 이름이에요.';

  @override
  String get authErrorUsernameReserved => '사용할 수 없는 사용자 이름이에요. 다른 이름을 선택해 주세요.';

  @override
  String get authErrorDisplayNameReserved => '사용할 수 없는 이름이에요. 다른 이름을 선택해 주세요.';

  @override
  String get authErrorUserNotFound => '해당 사용자 이름으로 된 계정이 없어요.';

  @override
  String get authErrorWrongPassword => '비밀번호가 틀렸어요.';

  @override
  String get authErrorInvalidRecoveryKey => '사용자 이름과 복구 문구가 일치하지 않아요.';

  @override
  String get authErrorTooManyAttempts => '시도 횟수가 너무 많아요. 15분 후 다시 시도해 주세요.';

  @override
  String get authErrorChildMustPair => '아이 계정이에요 — 보호자에게 페어링 코드를 요청해 주세요.';

  @override
  String get authErrorPairingCodeExpired => '코드가 만료됐어요. 새 코드를 요청해 주세요.';

  @override
  String get authErrorPairingCodeInvalid => '코드가 작동하지 않았어요. 이미 사용된 코드일 수 있어요.';

  @override
  String get authErrorUseSocialSignIn =>
      '이 계정은 Apple 또는 Google로 로그인해요 — 아래 버튼을 이용해 주세요.';

  @override
  String get authErrorSocialTokenInvalid => '로그인이 완료되지 않았어요. 다시 시도해 주세요.';

  @override
  String get authErrorSocialNonceMismatch => '로그인이 완료되지 않았어요. 다시 시도해 주세요.';

  @override
  String get authErrorSocialMisconfig =>
      '저희 쪽에서 아직 로그인 설정이 완료되지 않았어요. 나중에 다시 시도해 주세요.';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      '해당 Apple 또는 Google 계정은 이미 다른 MonkeyHub 계정에 연결되어 있어요.';

  @override
  String get authErrorSocialAlreadyLinked => '이미 이 계정에 연결되어 있어요.';

  @override
  String get authErrorSocialNotLinked => '이 계정에 연결되어 있지 않아요.';

  @override
  String get authErrorSocialLastCredential =>
      '이 계정에 로그인할 수 있는 유일한 방법이에요. 먼저 비밀번호를 설정해 주세요.';

  @override
  String get authErrorUsernameInvalid => '사용자 이름은 1자에서 32자 사이로 입력해 주세요.';

  @override
  String get authErrorUsernameChangedRecently =>
      '최근에 사용자 이름을 변경했습니다. 마지막 변경으로부터 30일 후에 다시 변경할 수 있습니다.';

  @override
  String get authErrorInboxHandleLocked =>
      '이 계정은 모두의 문제 신고를 받기 때문에 사용자 이름이 고정되어 있습니다.';

  @override
  String get glassKnobLabelFrost => '프로스트';

  @override
  String get glassKnobHintFrost => '글래스에 하얀빛이 얼마나 덮이는지 조절해요. 내리면 투명해져요.';

  @override
  String get glassKnobLabelBlur => '블러';

  @override
  String get glassKnobHintBlur => '범위 위쪽은 프로스트 글래스, 아래쪽은 맑은 글래스예요.';

  @override
  String get glassKnobLabelSaturation => '색 번짐';

  @override
  String get glassKnobHintSaturation =>
      '블러를 거치고도 색이 얼마나 남는지 조절해요. 2를 넘으면 포스터화돼요.';

  @override
  String get glassKnobLabelRimOpacity => '테두리';

  @override
  String get glassKnobHintRimOpacity => '강조 테두리예요. 0이면 테두리 없는 표면이 돼요.';

  @override
  String get glassKnobLabelRimWidth => '테두리 두께';

  @override
  String get glassKnobHintRimWidth => '그 테두리의 두께예요.';

  @override
  String get glassKnobLabelShadowOpacity => '그림자';

  @override
  String get glassKnobHintShadowOpacity => '표면이 배경 위로 얼마나 떠 보이는지 조절해요.';

  @override
  String get glassKnobLabelShadowBlur => '그림자 스프레드';

  @override
  String get glassKnobHintShadowBlur => '부드럽고 넓게, 또는 좁고 진하게 조절해요.';

  @override
  String get glassKnobLabelShadowY => '그림자 거리';

  @override
  String get glassKnobHintShadowY => '표면 아래로 얼마나 떨어지는지 조절해요.';

  @override
  String get glassKnobLabelBarMargin => '좌우 간격';

  @override
  String get glassKnobHintBarMargin => '바와 화면 가장자리 사이의 간격이에요.';

  @override
  String get glassKnobLabelBarBottom => '하단 간격';

  @override
  String get glassKnobHintBarBottom => '바가 화면 하단에서 얼마나 떠 있는지 조절해요.';

  @override
  String get glassKnobLabelShellPadH => '끝 여백';

  @override
  String get glassKnobHintShellPadH =>
      '바 끝에서 첫 번째 캡슐까지의 간격이에요. 좁으면 끝부분이 동떨어져 보여요.';

  @override
  String get glassKnobLabelShellPadV => '위쪽 여백';

  @override
  String get glassKnobHintShellPadV => '바 가장자리에서 캡슐 위쪽까지의 간격이에요.';

  @override
  String get glassKnobLabelIndicatorInset => '캡슐 인셋';

  @override
  String get glassKnobHintIndicatorInset => '선택 캡슐이 슬롯 안쪽으로 얼마나 들어가 있는지 조절해요.';

  @override
  String get glassKnobLabelSegmentPadV => '행 여백';

  @override
  String get glassKnobHintSegmentPadV => '아이콘과 라벨 위아래의 여백이에요.';

  @override
  String get glassKnobLabelIconLabelGap => '아이콘 간격';

  @override
  String get glassKnobHintIconLabelGap => '아이콘과 아래 라벨 사이의 간격';

  @override
  String get glassKnobLabelIconSize => '아이콘 크기';

  @override
  String get glassKnobLabelLabelSize => '라벨 크기';

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
  String get settingsScreenRowMotion => '모션';

  @override
  String get settingsScreenValueMotionFull => '가득';

  @override
  String get settingsScreenValueMotionCalm => '차분';

  @override
  String get settingsScreenValueMotionSystemFull => '기기 설정 따름 · 가득';

  @override
  String get settingsScreenValueMotionSystemCalm => '기기 설정 따름 · 차분';

  @override
  String get motionScreenTitle => '모션.';

  @override
  String get motionScreenSubtitle => '앱이 얼마나 움직일지';

  @override
  String get motionScreenSystemLabel => '기기 설정 따름';

  @override
  String get motionScreenSystemSubtitleFull => '지금 기기가 애니메이션을 허용하고 있어요';

  @override
  String get motionScreenSystemSubtitleCalm => '지금 기기가 모션 줄이기를 요청하고 있어요';

  @override
  String get motionScreenFullLabel => '가득';

  @override
  String get motionScreenFullSubtitle => '모든 흐름, 빛, 장식';

  @override
  String get motionScreenCalmLabel => '차분';

  @override
  String get motionScreenCalmSubtitle => '장식이 멈춰요 — 다른 건 그대로예요';

  @override
  String get momentRailCaptureLabel => '촬영';

  @override
  String get momentRailYouLabel => '나';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String get momentTagFate => '우연';

  @override
  String get momentTagJinx => '자충수';

  @override
  String get momentTagLuck => '행운';

  @override
  String get momentTagCalledIt => '내가 그랬지';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => '이런 우연이';

  @override
  String get momentTagJinxHint => '자기가 자초한 일';

  @override
  String get momentTagLuckHint => '일이 잘 풀렸다';

  @override
  String get momentTagCalledItHint => '올 줄 알았다';

  @override
  String get momentTagNpcHint => '머리가 완전히 꺼짐';

  @override
  String get momentComposerTitle => '무슨 일이 있었나요?';

  @override
  String get momentComposerCaptionHint => '한마디 남겨보세요';

  @override
  String get momentComposerTagPrompt => '점수 땄나요? 지금 추가하세요';

  @override
  String get momentComposerCapture => '카메라';

  @override
  String get momentComposerLibrary => '보관함';

  @override
  String get momentComposerRemovePhoto => '사진 삭제';

  @override
  String get momentComposerPost => '올리기';

  @override
  String get momentComposerErrorDailyCap => '오늘 다섯 개째예요 — 내일도 남겨두세요';

  @override
  String get momentComposerErrorNotAllowed => '보호자가 사진 공유를 꺼두었어요';

  @override
  String get momentComposerErrorTooLong => '조금 길어요 — 줄여주세요';

  @override
  String get momentComposerErrorEmpty => '사진이나 몇 마디를 더해주세요';

  @override
  String get momentComposerErrorGeneric => '올리지 못했어요 — 다시 시도해주세요';

  @override
  String get momentViewerDelete => '삭제';

  @override
  String get momentViewerDeleteConfirmHeadline => '이걸 삭제할까요?';

  @override
  String get momentViewerDeleteConfirmBody => '모두의 보드와 내 보관함에서 영영 사라져요';

  @override
  String get momentViewerDeleteFailed => '삭제하지 못했어요 — 다시 시도해주세요';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who님이 하이라이트를 올렸어요';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name님이 $tag를 받았어요';
  }

  @override
  String get momentActivityJustNow => '방금';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '$count분';
  }

  @override
  String momentActivityHoursAgo(Object count) {
    return '$count시간';
  }

  @override
  String momentActivityMoreCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오늘 $count개 더',
    );
    return '$_temp0';
  }

  @override
  String get puzzleScreenTitle => '퍼즐.';

  @override
  String get puzzleScreenSubtitle => '기호 네 개, 여섯 번의 기회';

  @override
  String get puzzleSubmit => '추측';

  @override
  String get puzzleBackspace => '마지막 기호 지우기';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return '기호 $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return '$count번 만에 해결';
  }

  @override
  String get puzzleFailedTitle => '기회 소진';

  @override
  String get puzzleAnswerWas => '정답은';

  @override
  String get puzzleShare => '결과 복사';

  @override
  String get puzzleShareCopied => '복사했어요 — 친구에게 붙여넣기';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => '오늘 건 이미 풀었어요';

  @override
  String get puzzleErrorOutOfGuesses => '오늘 남은 기회가 없어요';

  @override
  String get puzzleErrorGeneric => '보내지 못했어요 — 다시 시도해주세요';

  @override
  String get puzzleScoreboardLabel => '오늘의 점수';

  @override
  String get puzzleScoreboardEmpty => '오늘은 아직 아무도 끝내지 않았어요';

  @override
  String get puzzleTilePlay => '오늘의 퍼즐 풀기';

  @override
  String puzzleTileInProgress(Object count) {
    return '$count번 남음';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '$total명 중 #$rank';
  }

  @override
  String get profileVisibilityScreenSectionFeed => '피드';

  @override
  String get profileVisibilityScreenFeedLabel => '내 하이라이트';

  @override
  String get profileVisibilityScreenFeedDesc =>
      '올린 사진과 동영상이 그날 친구들의 보드에 보일지 여부';

  @override
  String get profileVisibilityScreenPuzzleLabel => '내 퍼즐 점수';

  @override
  String get profileVisibilityScreenPuzzleDesc => '친구들이 오늘의 퍼즐 결과를 볼 수 있는지 여부';

  @override
  String get profileVisibilityScreenPointsPastLabel => '내 지난 기록';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      '오늘은 항상 친구와 공유돼요 — 이 설정은 그 이전 전부를 열어요';

  @override
  String get momentComposerVideo => '동영상';

  @override
  String get momentComposerErrorTooBig => '동영상이 너무 커요 — 최대 20MB';

  @override
  String get momentActivityPostedHighlightSelf => '하이라이트를 올렸어요';

  @override
  String momentActivityScoredSelf(Object tag) {
    return '$tag를 받았어요';
  }

  @override
  String pointLineSelf(Object tag) {
    return '나 · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => '무슨 일이 있었나요?';

  @override
  String get pointComposerNoteHint => '위에서 하나 고르고 이야기해 주세요';

  @override
  String get pointComposerAdd => '점수 추가';

  @override
  String get pointComposerAddPhoto => '사진 추가';

  @override
  String get pointsBoardAdd => '점수 추가하기';

  @override
  String get pointsExplainerOpen => '이게 뭔가요?';

  @override
  String get pointsExplainerTitle => '점수 게임';

  @override
  String get pointsExplainerIntro =>
      '점수를 매기며 이어가는 농담이에요. 좋은 일이든 나쁜 일이든 그냥 이상한 일이든, 기록하면 그날 보드에 올라가요.';

  @override
  String get pointsExplainerRuleHonour =>
      '점수는 스스로 줍니다. 아무도 확인하지 않아요 — 그게 재미고, 과하면 친구들이 말해줄 거예요.';

  @override
  String get pointsExplainerRuleToday =>
      '점수는 매일 초기화돼요. 보드는 오늘을 보여주고, 내 기록은 내게 남아요.';

  @override
  String get pointsExplainerRuleCap =>
      '같은 종류는 하루 다섯 개까지. 아무도 보드를 엉망으로 만들 수 없게요.';

  @override
  String get pointsExplainerGotIt => '알겠어요';

  @override
  String get momentTagFateExample => '다른 나라에서 치과 선생님을 마주쳤어요';

  @override
  String get momentTagJinxExample => '세차했더니 네 시에 비가 왔어요';

  @override
  String get momentTagLuckExample => '2초 차이로 기차를 탔어요';

  @override
  String get momentTagCalledItExample => '속편은 망한다고 했는데 진짜 망했어요';

  @override
  String get momentTagNpcExample => '종업원에게 ‘당신도요’라고 했어요';

  @override
  String feedBoardEditionHint(Object number) {
    return '피드 $number일째';
  }

  @override
  String get feedBoardHighlightsHint => '볼 만한 사진과 동영상';

  @override
  String get profileVisibilityScreenPointsLabel => '내 점수';

  @override
  String get profileVisibilityScreenPointsDesc => '기록한 점수가 친구들의 보드에 보일지 여부';

  @override
  String get momentComposerEditPhoto => '자르기 편집';

  @override
  String get archiveScreenTitle => '내 보관함';

  @override
  String get archiveScreenEnd => '여기까지예요';

  @override
  String get archiveScreenEmptyTitle => '아직 저장된 게 없어요';

  @override
  String get archiveScreenEmptyBody => '순간은 하루 뒤 친구들의 보드에서 사라지지만, 여기에는 남아 있어요.';

  @override
  String get archiveScreenEmptyFriendTitle => '여기엔 아무것도 없어요';

  @override
  String get archiveScreenEmptyFriendBody => '아직 볼 수 있는 게시물이 없어요.';

  @override
  String get archiveScreenPrivateTitle => '지난 기록은 비공개예요';

  @override
  String get archiveScreenPrivateBody => '오늘 올리는 건 계속 볼 수 있어요.';

  @override
  String get archiveScreenNotFriendTitle => '친구가 아니에요';

  @override
  String get archiveScreenNotFriendBody => '친구의 지난 날만 되돌아볼 수 있어요.';

  @override
  String get archiveScreenErrorTitle => '불러오지 못했어요';

  @override
  String get archiveScreenErrorBody => '연결을 확인하고 다시 시도해주세요.';

  @override
  String get feedBoardOpenArchive => '보관함';

  @override
  String get feedBoardGamesLabel => '게임';

  @override
  String get feedBoardGamesOpen => '전체 게임';

  @override
  String get gamesScreenTitle => '게임.';

  @override
  String get gamesScreenSubtitle => '하루 네 판, 모두에게 같은 문제';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오늘 $count개 남음',
      one: '오늘 1개 남음',
      zero: '오늘 다 풀었어',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => '오늘의 게임을 불러오지 못했어';

  @override
  String get gamesRetry => '다시 시도';

  @override
  String get gameQueensName => '퀸즈';

  @override
  String get gameQueensRule => '행·열·색마다 왕관 하나, 서로 붙으면 안 됨';

  @override
  String get gameTangoName => '탱고';

  @override
  String get gameTangoRule => '해 셋, 달 셋, 같은 것이 연속 셋은 금지';

  @override
  String get gameZipName => '집';

  @override
  String get gameZipRule => '모든 칸을 지나는 한 줄, 숫자는 순서대로';

  @override
  String get gameSudokuName => '미니 스도쿠';

  @override
  String get gameSudokuRule => '행·열·박스마다 1부터 6까지 한 번씩';

  @override
  String get gameCodeName => '코드';

  @override
  String get gameStatusUnplayed => '안 함';

  @override
  String get gameStatusUnfinished => '진행 중';

  @override
  String get gameStatusGaveUp => '포기';

  @override
  String gameRankBadge(Object rank) {
    return '$rank위';
  }

  @override
  String get gamePause => '일시정지';

  @override
  String get gameResume => '계속';

  @override
  String get gamePausedTitle => '일시정지됨';

  @override
  String get gamePausedBody => '시계는 멈췄고 보드는 가려져 있어';

  @override
  String get gameUndo => '되돌리기';

  @override
  String get gameClear => '지우기';

  @override
  String get gameHint => '힌트';

  @override
  String get gameNotes => '메모';

  @override
  String get gameErase => '지우개';

  @override
  String get gameAutoCross => '자동 X 표시';

  @override
  String get gameGiveUp => '포기';

  @override
  String get gameGiveUpTitle => '정답을 볼까?';

  @override
  String get gameGiveUpBody => '오늘 보드는 종료되고 미해결로 기록돼.';

  @override
  String get gameGiveUpCancel => '계속 풀기';

  @override
  String get gameGiveUpConfirm => '보여줘';

  @override
  String gameSolvedTitle(Object time) {
    return '$time 만에 해결';
  }

  @override
  String get gameGaveUpTitle => '오늘의 정답';

  @override
  String get gameFirstInToday => '오늘 첫 번째';

  @override
  String gameRankLine(Object place, Object total) {
    return '현재 $total명 중 $place위';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '실수 $count번',
      one: '실수 1번',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '힌트 $count번',
      one: '힌트 1번',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => '오늘의 기록';

  @override
  String get gameStandingsEmpty => '아직 아무도 못 끝냈어';

  @override
  String get gameShare => '결과 복사';

  @override
  String get gameShareCopied => '복사됨 — 친구에게 붙여넣어';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => '전체 게임';

  @override
  String get gameElapsedSemantic => '경과 시간';

  @override
  String get gameErrorNotSolved => '아직 다 안 끝났어';

  @override
  String get gameErrorAlreadyFinished => '오늘 건 이미 끝냈어';

  @override
  String get gameErrorNoHint => '이건 힌트가 없어';

  @override
  String get gameErrorGeneric => '게임에 연결하지 못했어 — 다시 시도해';

  @override
  String get gameInfoOpen => '게임 방법';

  @override
  String get gameInfoLabel => '게임 방법';

  @override
  String get gameInfoRulesLabel => '규칙';

  @override
  String get gameInfoControlsLabel => '조작';

  @override
  String get gameInfoScoringTimed =>
      '보드가 화면에 있는 동안만 시계가 돌고, 일시정지하거나 나가면 멈춰. 가장 빠르면 오늘 1위야.';

  @override
  String get gameInfoScoringGuesses => '시간이 아니라 몇 번 만에 맞혔는지로 점수가 매겨져.';

  @override
  String get gameInfoSameForEveryone => '오늘은 모두 같은 보드를 받아.';

  @override
  String get gameInfoQueensGoal => '모든 행, 열, 색에 왕관을 하나씩 놓아.';

  @override
  String get gameInfoQueensRule1 => '왕관 여덟 개, 각 행에 하나 각 열에 하나.';

  @override
  String get gameInfoQueensRule2 => '색 덩어리마다도 정확히 하나씩.';

  @override
  String get gameInfoQueensRule3 => '왕관끼리는 닿으면 안 돼. 모서리끼리도 안 돼.';

  @override
  String get gameInfoQueensControls => '칸을 한 번 누르면 X, 다시 누르면 왕관, 또 누르면 비워져.';

  @override
  String get gameInfoTangoGoal => '격자를 해와 달로 채워.';

  @override
  String get gameInfoTangoRule1 => '모든 행과 열에 해 셋, 달 셋.';

  @override
  String get gameInfoTangoRule2 => '같은 것이 셋 연속으로 붙으면 안 돼. 가로도 세로도.';

  @override
  String get gameInfoTangoRule3 => '칸 사이의 = 는 같다는 뜻, × 는 다르다는 뜻이야.';

  @override
  String get gameInfoTangoControls =>
      '칸을 누르면 해, 다시 누르면 달, 또 누르면 비워져. 미리 찍혀 있는 칸은 안 바뀌어.';

  @override
  String get gameInfoZipGoal => '모든 칸을 지나는 선을 하나 그려.';

  @override
  String get gameInfoZipRule1 => '1에서 시작해 마지막 숫자에서 끝내.';

  @override
  String get gameInfoZipRule2 => '가는 길에 숫자를 순서대로 지나가.';

  @override
  String get gameInfoZipRule3 => '모든 칸을 정확히 한 번씩 써.';

  @override
  String get gameInfoZipControls => '손가락을 끌어서 그려. 선 위로 되돌아가면 지워져.';

  @override
  String get gameInfoSudokuGoal => '격자를 1부터 6까지의 숫자로 채워.';

  @override
  String get gameInfoSudokuRule1 => '각 행에 1부터 6까지 한 번씩.';

  @override
  String get gameInfoSudokuRule2 => '각 열도 마찬가지야.';

  @override
  String get gameInfoSudokuRule3 => '2x3 박스도 마찬가지.';

  @override
  String get gameInfoSudokuControls =>
      '칸을 누른 다음 숫자를 눌러. 같은 숫자를 다시 누르면 지워져. 메모 모드에서는 작은 연필 표시가 들어가.';

  @override
  String get gameInfoCodeGoal => '숨겨진 기호 네 개짜리 코드를 알아내.';

  @override
  String get gameInfoCodeRule1 => '여섯 번의 기회, 코드에 같은 기호는 반복되지 않아.';

  @override
  String get gameInfoCodeRule2 => '초록은 기호도 자리도 맞다는 뜻.';

  @override
  String get gameInfoCodeRule3 => '노랑은 기호는 맞지만 자리가 틀렸다는 뜻.';

  @override
  String get gameInfoCodeControls => '기호를 눌러 추측을 만든 다음 보내. 얼마나 가까웠는지 보드가 알려줘.';

  @override
  String get savedMessagesTitle => '저장한 메시지';

  @override
  String homeScreenNoSearchResults(Object query) {
    return '\"$query\"와(과) 일치하는 채팅이 없어요';
  }

  @override
  String get pullRevealSearchHint => '채팅 검색…';

  @override
  String get pullRevealCollapseSemanticLabel => '검색과 보관된 채팅 숨기기';

  @override
  String archivedChatsFolderLabel(Object count) {
    return '보관된 채팅 ($count)';
  }

  @override
  String get archivedChatsFolderTitle => '보관된 채팅';

  @override
  String get pullRevealClearSearchSemanticLabel => '검색 지우기';

  @override
  String get archivedChatsSheetTitle => '보관된 채팅';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return '보관된 채팅 · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => '더 이상 보관된 채팅이 없어요';

  @override
  String get pinnedBadgeLabel => '고정됨';

  @override
  String get chatRowActionMenuPinLabel => '채팅 고정';

  @override
  String get chatRowActionMenuUnpinLabel => '채팅 고정 해제';

  @override
  String get chatRowActionMenuArchiveLabel => '채팅 보관';

  @override
  String get chatRowActionMenuUnarchiveLabel => '채팅 보관 해제';

  @override
  String get messageActionMenuSaveLabel => '저장';

  @override
  String get messageActionMenuUnsaveLabel => '저장 해제';

  @override
  String get roomScreenSaveLimitSnack => '여기 저장한 게 너무 많아요 — 하나를 먼저 해제하세요';

  @override
  String get roomScreenSaveFailedSnack => '저장할 수 없어요';

  @override
  String get threadOverlaySaveLimitToast => '여기 저장한 게 너무 많아요 — 하나를 먼저 해제하세요';

  @override
  String get threadOverlaySaveFailedToast => '저장할 수 없어요';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      '저장한 메시지는 나만 볼 수 있습니다. 고정한 메시지는 반대로 방 전체가 봅니다.';

  @override
  String get roomInfoScreenOwnerBadgeNote => '이름 옆의 작은 메달은 이 방을 만든 사람을 나타냅니다.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return '$name님의 저장한 메시지로 이동';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return '$name님의 메시지 저장 해제';
  }

  @override
  String get muteSheetTitle => '채팅 음소거';

  @override
  String get muteSheetSubtitle => '무엇을 조용히 할지, 얼마 동안 할지 고르세요.';

  @override
  String get muteSheetNotificationsTitle => '알림';

  @override
  String get muteSheetNotificationsSub => '배너 없음, 소리 없음';

  @override
  String get muteSheetBadgesTitle => '읽지 않은 수';

  @override
  String get muteSheetBadgesSub => '채팅에 숫자를 표시하지 않고 앱 아이콘에도 더하지 않습니다';

  @override
  String get muteSheetDurationLabel => '얼마 동안';

  @override
  String get muteDurationHour => '1시간';

  @override
  String get muteDurationEightHours => '8시간';

  @override
  String get muteDurationWeek => '1주';

  @override
  String get muteDurationAlways => '항상';

  @override
  String get muteSheetConfirmButton => '음소거';

  @override
  String get muteSheetSaveButton => '저장';

  @override
  String get muteSheetUnmuteButton => '음소거 해제';

  @override
  String get muteSummaryAll => '이 채팅에서는 아무것도 오지 않습니다. 알림도 읽지 않은 수도 없습니다.';

  @override
  String get muteSummaryNotificationsOnly => '알림이 없습니다. 읽지 않은 수는 계속 늘어납니다.';

  @override
  String get muteSummaryBadgesOnly => '읽지 않은 수가 표시되지 않습니다. 알림은 계속 옵니다.';

  @override
  String get muteSummaryNothingPicked => '조용히 할 항목을 하나 이상 고르세요.';

  @override
  String muteUntilSentence(String when) {
    return '$when까지.';
  }

  @override
  String get muteUntilAlwaysSentence => '직접 해제할 때까지.';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date $time';
  }

  @override
  String get mutedBadgeLabel => '음소거됨';

  @override
  String get chatRowActionMenuMuteLabel => '채팅 음소거';

  @override
  String get chatRowActionMenuUnmuteLabel => '채팅 음소거 해제';

  @override
  String get roomInfoScreenMuteLabel => '음소거';

  @override
  String get roomInfoScreenNotMutedRow => '음소거 안 함';

  @override
  String get attachmentMenuLocationLabel => '위치';

  @override
  String get locationSheetSendCurrent => '현재 위치 보내기';

  @override
  String get locationSheetSendCurrentDetail => '지금 있는 곳';

  @override
  String get locationSheetLiveHeading => '실시간 공유';

  @override
  String get locationSheetLiveDetail => '자동으로 종료됩니다';

  @override
  String get locationShareFor15Minutes => '15분 동안';

  @override
  String get locationShareFor1Hour => '1시간 동안';

  @override
  String get locationShareFor8Hours => '8시간 동안';

  @override
  String get locationBubbleOpenInMaps => '지도 앱에서 열기';

  @override
  String get locationBubbleLiveBadge => '실시간';

  @override
  String get locationBubbleEndedBadge => '종료됨';

  @override
  String locationBubbleLiveUntil(String time) {
    return '$time까지 실시간';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return '실시간 위치가 $time에 종료되었습니다';
  }

  @override
  String get locationBubbleNoRecentUpdate => '최근 업데이트 없음';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters m';
  }

  @override
  String get locationBubbleStopSharing => '공유 중지';

  @override
  String get locationBubbleUnavailable => '위치를 표시할 수 없음';

  @override
  String get locationBubbleNoMapsApp => '열 수 있는 지도 앱이 없습니다';

  @override
  String get locationBubbleCoordinatesCopied => '좌표가 복사되었습니다';

  @override
  String get locationCouldNotGetFix => '위치를 가져오지 못했습니다';

  @override
  String get locationCouldNotStartLiveShare => '실시간 공유를 시작하지 못했습니다';

  @override
  String get locationPermissionNeeded => '위치를 공유하려면 위치 접근 권한이 필요합니다';

  @override
  String get locationPermissionBlockedTitle => '위치 접근이 꺼져 있음';

  @override
  String get locationPermissionBlockedBody =>
      '여기서는 MonkeyHub가 다시 요청할 수 없습니다. 설정에서 MonkeyHub의 위치 접근을 켜 주세요.';

  @override
  String get locationServicesOffTitle => '위치 서비스가 꺼져 있음';

  @override
  String get locationServicesOffBody =>
      '이 기기에서 위치가 꺼져 있습니다. 위치를 공유하려면 설정에서 켜 주세요.';

  @override
  String get locationOpenSettings => '설정 열기';

  @override
  String get locationBackgroundSheetTitle => '휴대폰이 다시 시작되면';

  @override
  String get locationBackgroundSheetBody =>
      'MonkeyHub를 벗어나도 실시간 공유는 계속됩니다. 백그라운드 권한은 나머지를 맡습니다. 재시작, 강제 종료, 배터리가 나갔다가 다시 켜진 경우까지.';

  @override
  String get locationBackgroundSheetKeepRunning => '자동으로 다시 시작';

  @override
  String get locationBackgroundSheetKeepRunningDetail => '휴대폰이 허용을 요청합니다';

  @override
  String get locationBackgroundSheetAppOnly => '그대로 중지';

  @override
  String get locationBackgroundSheetAppOnlyDetail => '추가로 허용할 것 없음';

  @override
  String get locationServiceNotificationTitle => '실시간 위치 공유 중';

  @override
  String get locationServiceNotificationBody => '탭하면 채팅이 열리고, 중지를 누르면 바로 끝납니다';

  @override
  String get childPolicyScreenLocationLabel => '위치';

  @override
  String get childPolicyScreenLocationOnDesc =>
      '현재 위치를 공유할 수 있습니다(최대 8시간 실시간 공유 포함)';

  @override
  String get childPolicyScreenLocationOffDesc => '현재 위치를 공유할 수 없습니다';

  @override
  String get roomInfoScreenSavedMessagesLabel => '저장한 메시지';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      '이건 나만 볼 수 있고, 이 방에서만 모입니다. 저장한 메시지 채팅과는 별개예요.';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      '아직 저장한 게 없어요. 메시지를 길게 누르고 ‘저장’을 선택하세요.';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return '$name님의 저장한 메시지로 이동';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return '$name님의 메시지 저장 해제';
  }

  @override
  String get composerCaptureCameraModeLabel => '카메라';

  @override
  String get composerCaptureVoiceModeLabel => '음성 메시지';

  @override
  String get composerCaptureVideoNoteModeLabel => '영상 메시지';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode. 두 손가락으로 밀거나 화살표 키로 모드를 바꿀 수 있습니다.';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '$mode 선택됨';
  }

  @override
  String get composerCaptureRecordingAnnouncement => '녹음을 시작했습니다';

  @override
  String get composerCaptureLockedAnnouncement => '녹음이 고정되었습니다. 손을 떼도 됩니다.';

  @override
  String get composerCaptureCancelledAnnouncement => '녹음을 삭제했습니다';

  @override
  String get composerCaptureSentAnnouncement => '녹음을 보냈습니다';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return '녹음 중, $elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint => '길게 눌러 녹음, 스와이프하여 전환';

  @override
  String get composerCaptureTapForCameraHint => '탭하여 카메라, 스와이프하여 전환';

  @override
  String get composerCaptureSlideToCancelHint => '밀어서 취소';

  @override
  String get composerCaptureReleaseToCancelHint => '놓으면 취소';

  @override
  String get composerCaptureTapToSendHint => '탭하여 전송';

  @override
  String get composerCaptureSendingLabel => '보내는 중…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return '$seconds초 남음';
  }

  @override
  String get composerCaptureCancelLabel => '녹음 삭제';

  @override
  String get composerCaptureSendLabel => '녹음 보내기';

  @override
  String get composerCaptureLockLabel => '위로 밀어 녹음 고정';

  @override
  String get composerCaptureMicPermissionTitle => '마이크가 필요합니다';

  @override
  String get composerCaptureMicPermissionBody =>
      '음성 메시지를 녹음하려면 마이크가 필요합니다. 설정에서 켠 뒤 다시 시도해 주세요.';

  @override
  String get composerCaptureCameraPermissionTitle => '카메라가 필요합니다';

  @override
  String get composerCaptureCameraPermissionBody =>
      '영상 메시지를 녹화하려면 카메라와 마이크가 필요합니다. 설정에서 켠 뒤 다시 시도해 주세요.';

  @override
  String get composerCaptureRestrictedBody => '이 기기의 제한으로 녹음·녹화가 꺼져 있습니다.';

  @override
  String get composerCaptureOpenSettingsLabel => '설정 열기';

  @override
  String get composerCaptureUnavailableSnack => '이 기기에서는 녹음·녹화를 사용할 수 없습니다.';

  @override
  String get composerCaptureInterruptedSnack => '녹음이 중단되었습니다.';

  @override
  String get composerCaptureStorageSnack => '녹음을 저장하지 못했습니다. 저장 공간을 확인해 주세요.';

  @override
  String get videoNoteMessagePlayLabel => '영상 메시지 재생';

  @override
  String get videoNoteMessagePauseLabel => '영상 메시지 일시정지';

  @override
  String get videoNoteMessageLoadingLabel => '영상 메시지 불러오는 중';

  @override
  String get videoNoteMessageUnavailableLabel => '영상 메시지를 사용할 수 없습니다';

  @override
  String get videoNoteMessageRetryLabel => '영상 메시지 다시 시도';

  @override
  String get videoNoteMessageRetryHint => '탭하여 다시 시도';

  @override
  String get videoNoteMessageDiscardLabel => '영상 메시지 삭제';

  @override
  String get attachmentMenuVideoNoteLabel => '영상 메시지';

  @override
  String get cameraScreenPhotoModeLabel => '사진';

  @override
  String get cameraScreenVideoModeLabel => '동영상';

  @override
  String get cameraScreenStartRecordingLabel => '녹화 시작';

  @override
  String get cameraScreenStopRecordingLabel => '녹화 중지';

  @override
  String get cameraScreenVideoFailedSnack => '동영상을 녹화하지 못했습니다.';

  @override
  String get scheduleSheetTitle => '메시지 예약';

  @override
  String get scheduleSheetSubtitle => '지금 쓰고, 원할 때 보내세요.';

  @override
  String get scheduleSheetWhenLabel => '언제';

  @override
  String get schedulePresetInAnHour => '1시간 뒤';

  @override
  String get schedulePresetInEightHours => '8시간 뒤';

  @override
  String get schedulePresetTomorrowMorning => '내일 아침';

  @override
  String get schedulePresetThisMorning => '오늘 아침';

  @override
  String get schedulePresetInAWeek => '1주일 뒤';

  @override
  String get scheduleSheetCustomChip => '날짜 고르기';

  @override
  String get scheduleSheetConfirmButton => '예약';

  @override
  String get scheduleSheetSaveButton => '저장';

  @override
  String scheduleSendsAtSentence(String when) {
    return '$when에 보냅니다.';
  }

  @override
  String scheduleWhenToday(String time) {
    return '오늘 $time';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return '내일 $time';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return '$date $time';
  }

  @override
  String get scheduleTimePickerTitle => '날짜와 시간 고르기';

  @override
  String get scheduleTimePickerBack => '빠른 선택';

  @override
  String get scheduleTimePickerToday => '오늘';

  @override
  String get scheduleTimePickerTomorrow => '내일';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '예약 $count개',
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
      other: '보내기를 기다리는 메시지 $count개. 탭하면 볼 수 있습니다.',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => '확인 필요';

  @override
  String get scheduledListTitle => '예약됨';

  @override
  String get scheduledListSubtitle => '보내지기 전까지는 나만 볼 수 있어요.';

  @override
  String get scheduledListEmpty => '여기엔 보내기를 기다리는 게 없어요.';

  @override
  String get scheduledListSendNow => '지금 보내기';

  @override
  String get scheduledListChangeTime => '시간 바꾸기';

  @override
  String get scheduledListEdit => '내용 고치기';

  @override
  String get scheduledListDelete => '삭제';

  @override
  String get scheduledListSending => '보내는 중…';

  @override
  String get scheduledListFailedTitle => '보내지 못했어요';

  @override
  String get scheduledListRetry => '다시 시도';

  @override
  String get scheduleErrorOutOfRange => '지금부터 2분 뒤에서 1년 사이로 시간을 골라 주세요.';

  @override
  String get scheduleErrorTooMany =>
      '여기 기다리는 메시지가 너무 많아요. 먼저 몇 개를 보내거나 지워 주세요.';

  @override
  String get scheduleErrorNotInEphemeral => '이 채팅의 메시지는 저절로 사라져서 예약할 수 없어요.';

  @override
  String get scheduleErrorNotMember => '이제 이 채팅에 없어요.';

  @override
  String get scheduleErrorBlocked => '먼저 차단을 풀어야 해요.';

  @override
  String get scheduleErrorGeneric => '잘 안 됐어요. 다시 시도해 주세요.';

  @override
  String get scheduleEditTitle => '메시지 고치기';

  @override
  String get composerScheduleAction => '이 메시지 예약하기';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '보내기를 기다리는 메시지 $count개',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => '표시 방법';

  @override
  String get scheduledIndicatorPill => '바';

  @override
  String get scheduledIndicatorBadge => '배지';

  @override
  String get scheduledIndicatorBoth => '둘 다';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이미 기다리는 메시지 $count개',
      zero: '보내기를 기다리는 게 없어요',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => '어떻게 보여줄까요';

  @override
  String get scheduledIndicatorPillSub => '입력창 위의 바. 탭하면 목록이 열려요.';

  @override
  String get scheduledIndicatorBadgeSub =>
      '보내기 버튼의 숫자. 입력을 시작하기 전에는 아무것도 보이지 않아요.';

  @override
  String get scheduledIndicatorBothSub => '바와, 입력 중에 보이는 숫자까지.';

  @override
  String get scheduledBack => '뒤로';

  @override
  String get serverScreenTitle => '서버.';

  @override
  String get serverScreenSubtitle => '계정과 메시지가 있는 곳';

  @override
  String get serverOnboardingTitle => '서버를 선택하세요.';

  @override
  String get serverOnboardingSubtitle => '이 빌드에는 서버가 없습니다 — 직접 운영하는 서버를 지정하세요';

  @override
  String get serverStatusConnected => '연결됨';

  @override
  String get serverStatusDisconnected => '연결 안 됨';

  @override
  String get serverBadgeDefault => '기본';

  @override
  String get serverBadgeSelfHosted => '자체 호스팅';

  @override
  String get serverNoneConfigured => '아직 서버 없음';

  @override
  String get serverActiveNowLabel => '사용 중';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => '이 앱에 기본으로 설정된 서버입니다.';

  @override
  String get serverChoiceOwn => '내 서버';

  @override
  String get serverChoiceOwnSub => '직접 운영하는 Convex 백엔드입니다.';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => '붙여넣기';

  @override
  String get serverProblemMalformed => '웹 주소가 아닙니다.';

  @override
  String get serverProblemBadScheme => 'https:// 또는 http:// 로 시작하세요.';

  @override
  String get serverProblemNoHost => 'https:// 뒤에 서버 주소를 입력하세요.';

  @override
  String get serverProblemCredentials => '주소에서 사용자 이름과 비밀번호를 빼세요.';

  @override
  String get serverInsecureTitle => '암호화되지 않음';

  @override
  String get serverInsecureBody =>
      '휴대폰은 평문 http를 차단하므로 이 주소는 iOS와 Android에서 연결되지 않습니다. https를 쓰거나 터널을 통해 서버에 연결하세요.';

  @override
  String get serverTestCta => '연결 테스트';

  @override
  String get serverTestingLabel => '테스트 중…';

  @override
  String get serverCheckReachable => '응답이 있었습니다';

  @override
  String get serverCheckConvex => 'Convex 서버입니다';

  @override
  String get serverCheckApp => 'MonkeyHub가 배포되어 있습니다';

  @override
  String get serverResultUnreachable => '그 주소에서는 아무 응답도 없었습니다.';

  @override
  String get serverResultNotConvex => '응답은 있었지만 Convex 서버가 아닙니다.';

  @override
  String get serverResultNotThisApp => 'Convex 서버이지만 MonkeyHub가 배포되어 있지 않습니다.';

  @override
  String get serverResultServerError => '서버가 응답했지만 오류였습니다.';

  @override
  String get serverResultReady => '연결할 준비가 됐습니다.';

  @override
  String get serverConnectCta => '연결';

  @override
  String get serverConnectAnywayCta => '그래도 연결';

  @override
  String get serverAlreadyConnectedCta => '이미 연결됨';

  @override
  String get serverUseDefaultCta => '기본 서버 사용';

  @override
  String get serverChangeCta => '서버 변경';

  @override
  String get serverAdvancedLabel => '고급';

  @override
  String get serverSiteUrlExplain =>
      '대부분의 서버는 한 주소에서 모두 응답합니다. HTTP 액션을 다른 주소에서 제공할 때만 입력하세요.';

  @override
  String get serverSiteUrlHint => '위와 동일';

  @override
  String get serverSectionRecent => '최근';

  @override
  String get serverRecentForget => '이 서버 지우기';

  @override
  String get serverSwitchWarningTitle => '서버를 바꾸면 로그아웃됩니다';

  @override
  String get serverSwitchWarningBody =>
      '계정과 대화는 한 서버에 속합니다. 이 기기는 로그아웃하고, 내려받은 것을 지우고, 처음부터 시작합니다. 어느 서버에서도 데이터가 삭제되지는 않습니다.';

  @override
  String get serverSwitchRolledBackTitle => '연결하지 못했습니다';

  @override
  String serverSwitchRolledBackBody(String host) {
    return '$host에서 응답이 없어 아무것도 바뀌지 않았습니다. 다시 로그인해야 합니다.';
  }

  @override
  String get serverSwitchStrandedBody =>
      '두 서버 모두 연결되지 않았습니다. 주소를 확인하고 다시 시도하세요.';

  @override
  String get serverSwitchRefusedBody => '이 기기는 자녀용으로 설정되어 있어 서버를 바꿀 수 없습니다.';

  @override
  String serverChipSemantics(String server) {
    return '서버 변경. 현재 $server.';
  }

  @override
  String get serverValueDefault => '기본';

  @override
  String get settingsScreenRowServer => '서버';

  @override
  String get settingsScreenSectionAdvanced => '고급';

  @override
  String get serverSwitchingLabel => '서버를 전환하는 중…';

  @override
  String get serverRoleExplainAction => '무슨 뜻인가요?';

  @override
  String get serverBadgeRibbonHomeserver => '홈';

  @override
  String get serverBadgeRibbonSelfHosted => '자체';

  @override
  String get serverBadgeHomeserver => '홈서버에서 제공 중';

  @override
  String get serverBadgeHomeserverSemantics => '홈서버에서 제공 중입니다. 자세히 보려면 탭하세요.';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return '자체 호스팅 서버: $server. 자세히 보려면 탭하세요.';
  }

  @override
  String get serverRoleHomeserverTitle => '홈서버에서 실행 중';

  @override
  String get serverRoleHomeserverBody =>
      'MonkeyHub 운영진이 당분간 트래픽을 집에 있는 서버로 옮겼습니다. 동작은 그대로이며, 고장이 아니라 의도한 조치입니다.';

  @override
  String get serverRoleHomeserverWarnData =>
      '이 상태에서 보낸 내용은 트래픽이 되돌아간 뒤 남아 있지 않을 수 있습니다.';

  @override
  String get serverRoleHomeserverWarnSpeed => '가정용 회선은 평소보다 느려서 지연이 생길 수 있습니다.';

  @override
  String get serverRoleHomeserverWarnAuto => '아무것도 하지 않아도 됩니다. 앱이 알아서 돌아갑니다.';

  @override
  String get serverRoleSelfHostedTitle => '내 서버';

  @override
  String get serverRoleSelfHostedBody =>
      '이 기기는 직접 운영하는 서버를 가리킵니다. 설정 › 고급 › 서버 에서 바꿀 수 있습니다.';

  @override
  String get serverValueHomeserver => '당분간 홈서버';

  @override
  String get serverChoiceCloudSubHomeserver => '당분간 홈서버에서 제공되고 있습니다.';

  @override
  String get serverDirectiveChangedToast => '서버가 바뀌었습니다. 다시 연결하는 중…';

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
  String get roomAdminRoleAdmin => '관리자';

  @override
  String get roomAdminActionViewProfile => '프로필 보기';

  @override
  String get roomAdminActionPromote => '관리자로 지정';

  @override
  String get roomAdminActionPromoteSub => '초대하고, 멤버를 내보내고, 그룹을 수정할 수 있어요';

  @override
  String get roomAdminActionDemote => '관리자 해제';

  @override
  String get roomAdminActionDemoteSub => '멤버로 그룹에 남아요';

  @override
  String get roomAdminActionTransfer => '소유권 넘기기';

  @override
  String get roomAdminActionTransferSub => '당신은 관리자로 남아요';

  @override
  String get roomAdminActionRemove => '그룹에서 내보내기';

  @override
  String get roomAdminAddFriendsRow => '친구 추가';

  @override
  String get roomAdminInviteLinkRow => '초대 링크';

  @override
  String get roomAdminJoinRequestsRow => '참여 요청';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return '그룹을 $name님에게 넘길까요?';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      '그 사람이 소유자가 되고 그룹을 삭제할 수 있어요. 당신은 관리자로 남고, 돌려받는 건 그 사람만 할 수 있어요.';

  @override
  String get roomAdminTransferConfirmCta => '넘기기';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return '$name님을 내보낼까요?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      '그룹과 그 안의 모든 것에 접근할 수 없게 돼요. 다시 초대하거나, 초대 링크로 돌아올 수 있어요.';

  @override
  String get roomAdminRemoveConfirmCta => '내보내기';

  @override
  String get roomAdminGenericError => '안 됐어요. 다시 시도해 보세요.';

  @override
  String get roomAdminErrorNotMember => '이제 이 그룹에 없어요.';

  @override
  String get roomAdminErrorNotAdmin => '관리자만 할 수 있어요.';

  @override
  String get roomAdminErrorNotOwner => '그룹 소유자만 할 수 있어요.';

  @override
  String get roomAdminErrorNotGroup => '1:1 대화에는 관리할 게 없어요.';

  @override
  String get roomAdminErrorOwnerImmutable => '소유자의 역할은 그룹을 넘길 때만 바뀌어요.';

  @override
  String get roomAdminErrorInvitesLocked => '이 그룹에는 관리자만 초대할 수 있어요.';

  @override
  String get roomInviteSheetTitle => '초대 링크';

  @override
  String get roomInviteSheetBlurb =>
      '링크와 코드는 하나씩이고, 사실 같은 거예요. 새로 만들면 이전 것은 바로 안 통해요.';

  @override
  String get roomInviteNoLinkYet => '이 그룹에는 아직 초대 링크가 없어요.';

  @override
  String get roomInviteCreateButton => '링크 만들기';

  @override
  String get roomInviteRegenerateButton => '새 링크';

  @override
  String get roomInviteRevokeButton => '링크 폐기';

  @override
  String get roomInviteCopyLink => '링크 복사';

  @override
  String get roomInviteCopyCode => '코드 복사';

  @override
  String get roomInviteShare => '공유';

  @override
  String get roomInviteLinkCopied => '링크를 복사했어요.';

  @override
  String get roomInviteCodeCopied => '코드를 복사했어요.';

  @override
  String get roomInviteRegenerateHeadline => '새 링크를 만들까요?';

  @override
  String get roomInviteRegenerateBody =>
      '지금 링크와 코드는 공유된 모든 곳에서 즉시 안 통하게 돼요. 이미 그룹에 있는 사람은 그대로 남아요.';

  @override
  String get roomInviteRegenerateConfirm => '새 링크';

  @override
  String get roomInviteRevokeHeadline => '이 링크를 폐기할까요?';

  @override
  String get roomInviteRevokeBody =>
      '새로 만들기 전까지는 링크로 아무도 못 들어와요. 이미 그룹에 있는 사람은 그대로 남아요.';

  @override
  String get roomInviteRevokeConfirm => '폐기';

  @override
  String get roomInviteLimitsLabel => '제한';

  @override
  String get roomInviteExpiryLabel => '유효 기간';

  @override
  String get roomInviteMaxUsesLabel => '사용 횟수';

  @override
  String get roomInviteNeverExpires => '없음';

  @override
  String get roomInviteUnlimited => '무제한';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count시간';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count일';
  }

  @override
  String get roomInviteLimitsApplyToNew => '지금 만들 링크에 적용돼요.';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      '다음 링크에 적용돼요. 위의 링크는 만들어질 때의 제한을 그대로 유지해요.';

  @override
  String get roomInvitePermissionsLabel => '권한';

  @override
  String get roomInviteMembersCanInviteLabel => '멤버도 친구를 초대할 수 있음';

  @override
  String get roomInviteMembersCanInviteSub => '끄면 관리자만 사람을 데려올 수 있어요';

  @override
  String get roomInviteApprovalLabel => '참여를 하나씩 승인';

  @override
  String get roomInviteApprovalSub => '링크를 가진 사람이 먼저 요청하고, 관리자가 수락할지 정해요';

  @override
  String roomInviteUsesCount(Object count) {
    return '$count번 사용됨';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$max번 중 $used번';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return '$date까지';
  }

  @override
  String get roomInviteDeadExpired => '이 링크는 만료됐어요. 새로 만드세요.';

  @override
  String get roomInviteDeadExhausted => '이 링크는 사용 횟수를 다 썼어요. 새로 만드세요.';

  @override
  String get roomInviteDeadRevoked => '이 링크는 폐기됐어요.';

  @override
  String get roomInviteDeadGeneric => '이 링크는 더 이상 안 통해요.';

  @override
  String get roomInviteFriendsTitle => '친구 추가';

  @override
  String get roomInviteFriendsBlurb => '초대를 받고, 수락하거나 거절할 수 있어요.';

  @override
  String get roomInviteFriendsSearchHint => '친구 검색';

  @override
  String get roomInviteFriendsInviteButton => '초대';

  @override
  String get roomInviteFriendsSent => '초대함';

  @override
  String get roomInviteFriendsEmpty => '친구가 모두 이미 여기 있거나 이미 초대됐어요.';

  @override
  String get roomInviteFriendsNoMatch => '일치하는 친구가 없어요.';

  @override
  String get roomInviteFriendsDone => '완료';

  @override
  String get roomJoinRequestsTitle => '참여 요청';

  @override
  String get roomJoinRequestsBlurb =>
      '초대 링크를 쓴 사람들이에요. 승인하기 전까지는 그룹 안을 아무것도 못 봐요.';

  @override
  String get roomJoinRequestsEmpty => '기다리는 사람이 없어요.';

  @override
  String get roomJoinRequestsApprove => '들이기';

  @override
  String get roomJoinRequestsReject => '거절';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return '초대함 · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian => '보호자 확인 대기 중';

  @override
  String get roomInfoScreenInviteWithdraw => '취소';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return '$inviter님이 초대 · 멤버 $members명';
  }

  @override
  String get roomInvitationCardJoin => '참여';

  @override
  String get discoverScreenJoinByCodeTitle => '코드로 참여';

  @override
  String get discoverScreenJoinByCodeSubtitle => '누군가 공유한 그룹을 열어요';

  @override
  String get joinInviteTitle => '그룹 참여';

  @override
  String get joinInviteBack => '뒤로';

  @override
  String get joinInviteCodeBlurb => '공유받은 코드를 입력하세요. 초대 링크 전체를 붙여 넣어도 돼요.';

  @override
  String get joinInviteCodeLabel => '초대 코드';

  @override
  String get joinInviteCodeHint => '링크를 붙여넣거나 코드를 입력하세요';

  @override
  String get joinInviteCodeInvalid => '초대 코드 같지 않아요.';

  @override
  String get joinInviteLookupButton => '계속';

  @override
  String get joinInviteLookupFailed => '코드를 확인하지 못했어요. 연결을 확인하고 다시 시도해 보세요.';

  @override
  String joinInviteMemberCount(Object count) {
    return '멤버 $count명';
  }

  @override
  String get joinInviteJoinButton => '그룹 참여';

  @override
  String get joinInviteRequestButton => '참여 요청';

  @override
  String get joinInviteOpenNote => '참여하면 그룹의 메시지를 볼 수 있어요.';

  @override
  String get joinInviteApprovalNote => '여기 안을 보려면 먼저 관리자가 승인해야 해요.';

  @override
  String get joinInviteOpenRoom => '그룹 열기';

  @override
  String get joinInvitePendingHeadline => '관리자를 기다리는 중';

  @override
  String get joinInvitePendingBody => '누군가 답하면 바로 알림이 가요.';

  @override
  String get joinInviteBadLinkHeadline => '이 초대는 안 통해요';

  @override
  String get joinInviteBadLinkBody => '코드를 확인하거나, 새 링크를 받으세요.';

  @override
  String get joinInviteExpiredHeadline => '이 초대는 만료됐어요';

  @override
  String get joinInviteExpiredBody => '초대한 사람에게 새 링크를 받으세요.';

  @override
  String get joinInviteExhaustedHeadline => '이 초대는 다 쓰였어요';

  @override
  String get joinInviteExhaustedBody => '정해진 횟수만 쓸 수 있게 설정돼 있었어요. 새로 받으세요.';

  @override
  String get joinInviteRevokedHeadline => '이 초대는 교체됐어요';

  @override
  String get joinInviteRevokedBody => '관리자가 새 링크를 만들었어요. 지금 링크를 받으세요.';

  @override
  String get joinInviteWrongServerHeadline => '이 초대는 다른 서버의 것이에요';

  @override
  String joinInviteWrongServerBody(Object host) {
    return '$host에 속해 있어요. 계정이 다른 서버에 있어서 여기서는 이 그룹에 갈 수 없어요.';
  }

  @override
  String get roomInviteErrorNotFound => '그 초대 코드와 맞는 게 없어요.';

  @override
  String get roomInviteErrorRevoked => '그 초대는 교체됐어요. 지금 링크를 받으세요.';

  @override
  String get roomInviteErrorExpired => '그 초대는 만료됐어요.';

  @override
  String get roomInviteErrorExhausted => '그 초대는 다 쓰였어요.';

  @override
  String get roomInviteErrorAlreadyMember => '이미 이 그룹에 있어요.';

  @override
  String get roomInviteErrorAlreadyInvited => '이미 초대했어요.';

  @override
  String get roomInviteErrorSelf => '당신은 이미 이 그룹에 있어요.';

  @override
  String get roomInviteErrorInvitationGone => '그 초대는 이제 없어요.';

  @override
  String get roomInviteErrorRequestPending => '이미 참여를 요청했어요. 관리자가 답할 거예요.';

  @override
  String get roomInviteErrorRequestGone => '그 요청에는 이미 누가 답했어요.';

  @override
  String get roomInviteErrorRoomPrivate => '이 그룹에는 초대로만 들어올 수 있어요.';

  @override
  String get roomInviteErrorInvalidLimits => '그 제한은 쓸 수 없어요.';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$child이(가) $other을(를) $room에 초대하려고 해요';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$other이(가) $child을(를) $room에 초대했어요';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      '초대가 나가고, 참여할지는 상대가 정해요.';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$child이(가) 초대를 보고 수락하거나 거절할 수 있어요. 승인하면 수락했을 때 그 그룹에 들어가는 것도 허용돼요.';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      '자기 자신은 내보낼 수 없어요. 대신 그룹에서 나가세요.';

  @override
  String get roomAdminActionMessage => '메시지';

  @override
  String get roomAdminActionVoiceCall => '음성 통화';

  @override
  String get roomAdminActionVideoCall => '영상 통화';

  @override
  String get roomAdminYouSuffix => '나';

  @override
  String get roomInfoScreenSetPasswordButton => '설정';

  @override
  String get roomInfoScreenPasswordSetSnackbar => '비밀번호를 설정했어요.';

  @override
  String get roomInfoScreenPasswordSetState => '비밀번호 있음';

  @override
  String get roomInfoScreenPasswordUnsetState => '비밀번호 없음';

  @override
  String get roomInfoScreenPasswordCancel => '취소';

  @override
  String get roomInfoScreenEditSave => '저장';

  @override
  String get roomInfoScreenEditCancel => '취소';

  @override
  String get roomInviteRotatedToast => '새 링크를 만들었어요. 이전 링크는 이제 안 통해요.';

  @override
  String get roomInviteRevokedToast => '초대 링크를 폐기했어요.';

  @override
  String get newChatMenuTitle => '새 대화';

  @override
  String get newChatMenuCreateTitle => '방 만들기';

  @override
  String get newChatMenuCreateSub => '그룹을 만들고 사람을 초대해요';

  @override
  String get newChatMenuJoinTitle => '코드로 참여';

  @override
  String get newChatMenuJoinSub => '누군가 공유한 그룹을 열어요';

  @override
  String get shareSheetTitle => '보낼 대상';

  @override
  String get shareSheetSuggestedHeading => '추천';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '첨부 $count개',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '파일 $count개가 $size 제한을 넘어서 제외했어요',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return '$title에게 보내기';
  }

  @override
  String get settingsScreenRowSpeakerColors => '말한 사람 색상';

  @override
  String get settingsScreenValueSpeakerOff => '끄기';

  @override
  String get settingsScreenValueSpeakerName => '이름';

  @override
  String get settingsScreenValueSpeakerBubble => '이름 + 말풍선';

  @override
  String get speakerColorScreenTitle => '말한 사람 색상.';

  @override
  String get speakerColorScreenSubtitle => '이름을 읽지 않아도 누가 말했는지';

  @override
  String get speakerColorScreenOffLabel => '끄기';

  @override
  String get speakerColorScreenOffDescription => '방에 있는 모두가 같은 색으로 표시됩니다.';

  @override
  String get speakerColorScreenNameLabel => '이름';

  @override
  String get speakerColorScreenNameDescription =>
      '각자 고유한 색을 갖습니다. 이름과 프로필 테두리에 표시돼요.';

  @override
  String get speakerColorScreenBubbleLabel => '말풍선';

  @override
  String get speakerColorScreenBubbleDescription =>
      '색이 말풍선까지 이어져, 다섯 개가 연달아 와도 누가 썼는지 알 수 있어요.';

  @override
  String get roomInfoScreenSpeakerColorsLabel => '색상';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => '자동';

  @override
  String get roomInfoScreenSpeakerColorsCustom => '직접 지정';

  @override
  String get roomColorsScreenTitle => '누가 누구인지.';

  @override
  String get roomColorsScreenSubtitle => '각자가 말하는 색';

  @override
  String get roomColorsScreenOffTitle => '말한 사람 색상이 꺼져 있어요';

  @override
  String get roomColorsScreenOffBody =>
      '지금은 모두 같은 색으로 표시됩니다. 켜면 여기 있는 사람마다 고유한 색이 생겨요.';

  @override
  String get roomColorsScreenOffAction => '켜기';

  @override
  String get roomColorsScreenOffHint => '이 방뿐 아니라 모든 방에 적용됩니다. 설정에도 있어요.';

  @override
  String get roomColorsScreenAutoChip => '자동';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return '$name 님과 같은 색';
  }

  @override
  String get roomColorsScreenResetAll => '자동으로 되돌리기';

  @override
  String get roomColorsScreenLimitToast => '한 방에서 지정할 수 있는 색은 여기까지예요.';

  @override
  String get roomColorsScreenFailedToast => '그 색을 저장하지 못했어요.';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return '색 $index';
  }

  @override
  String get devicesScreenTitle => '내 기기';

  @override
  String get devicesScreenSubtitle => '이 계정으로 로그인한 모든 곳.';

  @override
  String get devicesScreenLoading => '확인 중…';

  @override
  String get devicesScreenLoadFailed => '기기를 불러오지 못했습니다';

  @override
  String get devicesScreenThisDevice => '이 기기';

  @override
  String get devicesScreenActiveNow => '지금 활동 중';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count분 전',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count시간 전',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일 전',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications => '이 기기에는 알림이 도착하지 않습니다';

  @override
  String get devicesScreenRemove => '삭제';

  @override
  String get devicesScreenRemoveTitle => '이 기기를 삭제할까요?';

  @override
  String devicesScreenRemoveBody(Object name) {
    return '$name은(는) 로그아웃되고 알림도 오지 않습니다. 그 기기를 가진 사람은 다시 로그인해야 합니다.';
  }

  @override
  String get devicesScreenRemoveConfirm => '삭제';

  @override
  String get devicesScreenRemoveAll => '다른 기기 모두 삭제';

  @override
  String get devicesScreenRemoveAllTitle => '다른 기기를 모두 삭제할까요?';

  @override
  String get devicesScreenRemoveAllBody =>
      '모두 로그아웃되고 알림도 오지 않습니다. 이 기기만 로그인 상태로 남습니다.';

  @override
  String get devicesScreenRemoveAllConfirm => '모두 삭제';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '기기 $count대를 삭제했습니다',
      zero: '삭제할 다른 기기가 없습니다',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed => '그 기기를 삭제하지 못했습니다';

  @override
  String get devicesScreenFootnote =>
      '기기를 삭제하면 로그아웃되고 알림도 중단됩니다. 즉시 적용되며, 그 기기가 다음에 무언가 하려는 순간 로그인 화면으로 돌아갑니다.';

  @override
  String get attachmentMenuPollLabel => '투표';

  @override
  String get attachmentMenuChecklistLabel => '체크리스트';

  @override
  String get attachmentMenuEventLabel => '일정';

  @override
  String get interactionKindPoll => '투표';

  @override
  String get interactionKindQuiz => '퀴즈';

  @override
  String get interactionKindChecklist => '체크리스트';

  @override
  String get interactionKindEvent => '일정';

  @override
  String get interactionBadgeAnonymous => '익명';

  @override
  String get interactionBadgeMultiple => '복수';

  @override
  String get interactionBadgeClosed => '마감';

  @override
  String interactionPercent(int percent) {
    return '$percent%';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names 외 $count명';
  }

  @override
  String get interactionSeeWhoAnswered => '누가 답했는지 보기';

  @override
  String interactionRemoveItem(String label) {
    return '$label 삭제';
  }

  @override
  String interactionChoiceSemantics(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count표',
    );
    return '$label, $_temp0';
  }

  @override
  String get interactionAddItemHint => '항목 추가';

  @override
  String get interactionRetract => '취소';

  @override
  String get interactionClose => '마감';

  @override
  String interactionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count표',
    );
    return '$_temp0';
  }

  @override
  String interactionRsvpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '답변 $count개',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$total개 중 $done개 완료';
  }

  @override
  String get interactionNoAnswers => '답변 없음';

  @override
  String get interactionBeFirst => '가장 먼저 답해 보세요';

  @override
  String interactionFinalResults(String count) {
    return '$count · 확정';
  }

  @override
  String get interactionQuizRight => '정답';

  @override
  String get interactionQuizWrong => '아깝네요';

  @override
  String interactionEventPast(String when) {
    return '$when · 이미 지났어요';
  }

  @override
  String get interactionRespondentsTitlePoll => '투표한 사람';

  @override
  String get interactionRespondentsTitleChecklist => '체크한 사람';

  @override
  String get interactionRespondentsTitleEvent => '답한 사람';

  @override
  String get interactionRespondentsFailed => '누가 답했는지 불러오지 못했어요.';

  @override
  String get interactionRespondentsEmpty => '아직 아무도 답하지 않았어요.';

  @override
  String get interactionFilterAll => '전체';

  @override
  String get interactionRsvpGoing => '갈게요';

  @override
  String get interactionRsvpMaybe => '아마도';

  @override
  String get interactionRsvpNo => '못 가요';

  @override
  String get interactionComposePollTitle => '새 투표';

  @override
  String get interactionComposePollTagline => '방에 물어보기';

  @override
  String get interactionComposeChecklistTitle => '새 체크리스트';

  @override
  String get interactionComposeChecklistTagline => '다 같이 체크하는 목록';

  @override
  String get interactionComposeEventTitle => '새 일정';

  @override
  String get interactionComposeEventTagline => '누가 오는지 보기';

  @override
  String get interactionComposeQuestionLabel => '질문';

  @override
  String get interactionComposeQuestionHint => '무엇을 물어볼까요?';

  @override
  String get interactionComposeTitleLabel => '제목';

  @override
  String get interactionComposeTitleHint => '어떤 목록인가요?';

  @override
  String get interactionComposeEventNameLabel => '일정';

  @override
  String get interactionComposeEventNameHint => '무슨 일인가요?';

  @override
  String get interactionComposeOptionsLabel => '선택지';

  @override
  String get interactionComposeItemsLabel => '항목';

  @override
  String interactionComposeOptionHint(int index) {
    return '선택지 $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return '항목 $index';
  }

  @override
  String get interactionComposeAddOption => '선택지 추가';

  @override
  String get interactionComposeAddItem => '항목 추가';

  @override
  String get interactionComposeRemoveRow => '삭제';

  @override
  String get interactionComposeMarkCorrect => '정답으로 표시';

  @override
  String get interactionComposeMultipleTitle => '복수 응답';

  @override
  String get interactionComposeMultipleSub => '여러 개 고를 수 있어요';

  @override
  String get interactionComposeAnonymousTitle => '익명';

  @override
  String get interactionComposeAnonymousOffSub => '누가 투표했는지 모두 볼 수 있어요';

  @override
  String get interactionComposeAnonymousOnSub => '누가 투표했는지 아무도 못 봐요';

  @override
  String get interactionComposeQuizTitle => '퀴즈 모드';

  @override
  String get interactionComposeQuizSub => '정답은 하나, 바꿀 수 없어요';

  @override
  String get interactionComposeExplanationLabel => '해설';

  @override
  String get interactionComposeExplanationHint => '답한 뒤에 보여요 (선택)';

  @override
  String get interactionComposeOthersMayCheckTitle => '누구나 체크 가능';

  @override
  String get interactionComposeOthersMayCheckSub => '나만이 아니에요';

  @override
  String get interactionComposeOthersMayAddTitle => '누구나 추가 가능';

  @override
  String get interactionComposeOthersMayAddSub => '나중에 늘릴 수 있어요';

  @override
  String get interactionComposeWhenLabel => '언제';

  @override
  String get interactionComposePickStart => '시작 시간 고르기';

  @override
  String get interactionComposePickEnd => '종료 추가 (선택)';

  @override
  String get interactionComposePlaceLabel => '장소';

  @override
  String get interactionComposePlaceHint => '어디서? (선택)';

  @override
  String get interactionComposeSendPoll => '투표 보내기';

  @override
  String get interactionComposeSendChecklist => '체크리스트 보내기';

  @override
  String get interactionComposeSendEvent => '일정 보내기';

  @override
  String get interactionComposeErrorPrompt => '먼저 무엇을 묻는지 적어 주세요.';

  @override
  String interactionComposeErrorOptions(int count) {
    return '투표에는 선택지가 $count개 이상 필요해요.';
  }

  @override
  String get interactionComposeErrorItems => '체크리스트에는 항목이 하나 이상 필요해요.';

  @override
  String get interactionComposeErrorAnswer => '어느 선택지가 정답인지 표시해 주세요.';

  @override
  String get interactionComposeErrorWhen => '언제 시작하는지 골라 주세요.';

  @override
  String get interactionComposeErrorEnd => '종료는 시작보다 뒤여야 해요.';

  @override
  String get interactionSendFailed => '보내지 못했어요.';

  @override
  String get interactionRefused => '처리되지 않았어요.';

  @override
  String get messageReceiptsScreenTitle => '메시지 정보';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$total명 중 $read명 읽음';
  }

  @override
  String get messageReceiptsEmptyState => '이 방에는 아직 다른 사람이 없습니다';

  @override
  String get messageReceiptsSectionRead => '읽음';

  @override
  String get messageReceiptsSectionDelivered => '전달됨';

  @override
  String get messageReceiptsSectionSent => '보냄';

  @override
  String get messageReceiptsSectionHidden => '확인 없음';

  @override
  String get messageReceiptsStateHidden => '공유 안 함';

  @override
  String get messageReceiptsStateWaiting => '대기 중';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name님이 $day $time에 읽었습니다';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name님이 $day $time에 받았습니다';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name님이 아직 받지 못했습니다';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name님은 읽음 확인을 공유하지 않습니다';
  }

  @override
  String get companionsScreenTitle => '동반자.';

  @override
  String get companionsScreenSubtitle => '이 휴대폰 안에 살면서 아무것도 밖으로 보내지 않는 도우미';

  @override
  String get companionSebastianTagline => '메시지를 번역합니다';

  @override
  String get companionSebastianBlurb =>
      'Sebastian은 다른 언어로 쓰인 메시지를 읽고 무슨 뜻인지 알려줍니다 — 이 휴대폰 안에서, 아무것도 밖으로 보내지 않고요.';

  @override
  String get companionMarloweTagline => '일반 도우미';

  @override
  String get companionMarloweBlurb =>
      'Marlowe는 번역 외의 모든 것을 맡습니다. 지금 두뇌를 하나 고르면, 기능은 그 주위로 하나씩 도착합니다.';

  @override
  String get companionAssuranceOnDevice => '전부 이 기기에서 실행됩니다';

  @override
  String get companionAssurancePrivate => '메시지는 휴대폰을 절대 벗어나지 않습니다';

  @override
  String get companionAssuranceOffline => '네트워크 없이도 작동합니다';

  @override
  String companionInstallAction(Object size) {
    return '설치 · $size';
  }

  @override
  String get companionInstallOneTime => '한 번만 내려받으면 삭제할 때까지 유지됩니다';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$total 중 $received';
  }

  @override
  String get companionInstallQueued => '다른 다운로드가 끝나기를 기다리는 중';

  @override
  String get companionInstallCancel => '취소';

  @override
  String get companionInstallRetry => '다시 시도';

  @override
  String companionInstallReady(Object name) {
    return '$name 준비 완료';
  }

  @override
  String get companionInstallFailedNetwork =>
      '다운로드를 마치지 못했습니다. 연결을 확인하고 다시 시도해 주세요.';

  @override
  String get companionInstallFailedStorage =>
      '이 기기에 공간이 부족합니다. 공간을 확보하고 다시 시도해 주세요.';

  @override
  String get companionInstallFailedUnknown => '다운로드를 마치지 못했습니다.';

  @override
  String get companionUnsupportedPlatform => '이 버전의 앱에서는 동반자를 아직 사용할 수 없습니다.';

  @override
  String companionBrainNeedsMemory(String size) {
    return '$size 메모리가 필요합니다';
  }

  @override
  String get sebastianTierSeniorDetail => '더 정확한 번역';

  @override
  String get sebastianTierJuniorDetail => '어떤 기기에서도 작동';

  @override
  String get sebastianLanguageUnlisted => '지원 언어가 아닙니다 — 결과가 거칠 수 있어요';

  @override
  String get companionStatusNotInstalled => '설치되지 않음';

  @override
  String get companionStatusOff => '꺼짐';

  @override
  String companionStatusTranslatingInto(Object language) {
    return '$language(으)로 번역 중';
  }

  @override
  String get companionStatusNoBrain => '아직 내려받은 것이 없습니다';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '다운로드 $count개 준비됨',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty => '내려받은 것이 없습니다 — 동반자가 차지하는 공간 없음';

  @override
  String companionStorageUsed(Object size) {
    return '동반자가 $size를 사용 중';
  }

  @override
  String get companionSectionGeneral => '일반';

  @override
  String get companionSectionStorage => '저장 공간';

  @override
  String get companionBrainRemove => '삭제';

  @override
  String companionBrainRemoveTitle(Object name) {
    return '$name을(를) 삭제할까요?';
  }

  @override
  String companionRemoveTitle(Object name) {
    return '$name을(를) 삭제할까요?';
  }

  @override
  String companionRemoveMessage(Object size) {
    return '$size를 확보합니다. 언제든 다시 내려받을 수 있습니다.';
  }

  @override
  String get companionRemoveConfirm => '삭제';

  @override
  String get sebastianEnableLabel => 'Sebastian이 번역하도록 허용';

  @override
  String get sebastianEnableDetail => '내려받은 파일은 그대로 두고 멈추려면 끄세요';

  @override
  String get sebastianLanguageSection => '번역할 언어';

  @override
  String get sebastianLanguageFollowApp => '앱과 동일';

  @override
  String sebastianBrainDetail(Object size) {
    return '이 기기에 저장됨 · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '번역 $count개 보관 중',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => '지우기';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe는 아직 아무것도 하지 못합니다 — 기능이 준비되는 중이에요. 지금 할 수 있는 일은 두뇌를 미리 준비해 두는 것, 그러면 기능이 도착했을 때 다운로드를 기다릴 일이 없습니다.';

  @override
  String get marloweBrainsSection => '두뇌';

  @override
  String get marloweBrainsCaption =>
      '클수록 더 잘 생각하고 더 느리게 답합니다. 여러 개를 두고 바꿔 쓸 수 있습니다.';

  @override
  String get marloweBrainTierSwift => '가벼움';

  @override
  String get marloweBrainTierBalanced => '균형';

  @override
  String get marloweBrainTierDeep => '깊이';

  @override
  String get translationSlabShowOriginal => '원문 보기';

  @override
  String get translationSlabFailed => '이 메시지는 번역하지 못했습니다.';

  @override
  String get translationSlabRetry => '다시 시도';

  @override
  String translationSlabByCompanion(Object name) {
    return '$name이(가) 번역함';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return '$language에서';
  }

  @override
  String get messageActionMenuTranslateLabel => '번역';

  @override
  String get messageActionMenuShowOriginalLabel => '원문 보기';

  @override
  String get roomTranslateTitle => '이 대화 번역';

  @override
  String get roomTranslateStopTitle => '번역 중지';

  @override
  String get roomTranslateSectionLabel => '번역';

  @override
  String get roomTranslateOnRow => '이 대화를 번역하는 중';

  @override
  String get roomTranslateOffRow => '꺼짐';

  @override
  String get roomTranslateNeedsSetUp => 'Sebastian 설정';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'Sebastian이 번역 중 · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return '$language(으)로 읽는 중';
  }

  @override
  String get roomTranslateStop => '중지';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return '이미 $language입니다';
  }

  @override
  String get roomScreenTranslateRoomOffer => '이 대화의 나머지도 번역할까요?';

  @override
  String get roomScreenTranslateRoomOfferAction => '전체 번역';

  @override
  String get settingsScreenCompanionsOff => '꺼짐';

  @override
  String get settingsScreenCompanionsUnavailable => '사용 불가';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return '$name도 사용 중';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return '$name도 같은 다운로드를 사용하고 있어 함께 사라집니다.';
  }

  @override
  String get companionBrainInUse => '사용 중';

  @override
  String companionStatusUsingBrain(Object name) {
    return '$name 사용 중';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name 다운로드가 계속됩니다 — 설정 › 동반자';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return '다운로드 중 · $percent%';
  }

  @override
  String get companionInstallPause => '일시정지';

  @override
  String get companionInstallResume => '이어받기';

  @override
  String get companionInstallDiscard => '버리기';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return '일시정지 · $total 중 $received';
  }

  @override
  String get companionInstallFailedIntegrity =>
      '내려받은 파일이 이 버전이 기대하는 것과 다릅니다. 처음부터 다시 시작합니다.';

  @override
  String companionBannerDownloading(
    Object name,
    Object received,
    Object total,
  ) {
    return '$name · $total 중 $received';
  }

  @override
  String companionBannerPaused(Object name, Object received, Object total) {
    return '$name 일시정지 · $total 중 $received';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name 깨어나는 중…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => '다시 번역';

  @override
  String get groupCallScreenShareLabel => '공유';

  @override
  String get groupCallScreenStopShareLabel => '공유 중지';

  @override
  String get groupCallScreenShareStartingLabel => '시작 중…';

  @override
  String get groupCallScreenRingingLabel => '연결 중…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name님이 화면을 공유하고 있어요';
  }

  @override
  String get groupCallScreenYouAreSharing => '내 화면을 공유하고 있어요';

  @override
  String get groupCallScreenMinimizeLabel => '숨기기';

  @override
  String get groupCallScreenDrawLabel => '그리기';

  @override
  String get callScreenControlShare => '공유';

  @override
  String get callScreenControlStopShare => '중지';

  @override
  String get callScreenControlShareStarting => '시작 중…';

  @override
  String get screenShareStopDrawing => '그리기 종료';

  @override
  String get callScreenControlDraw => '그리기';

  @override
  String get callScreenControlMinimize => '숨기기';

  @override
  String get inCallPillOngoingCall => '통화 중';

  @override
  String get inCallPillReturn => '돌아가기';

  @override
  String get inCallPillSharing => '내 화면 공유 중';

  @override
  String get inCallPillDrawSemanticLabel => '공유 화면에 그리기';

  @override
  String get inCallPillStopSharingSemanticLabel => '공유 중지';

  @override
  String get screenShareUnsupported => '이 기기에서는 화면 공유를 사용할 수 없어요';

  @override
  String get screenShareEphemeralWarning => '공유하는 동안 캡처 보호가 꺼져요';

  @override
  String get screenShareNotificationTitle => '내 화면 공유 중';

  @override
  String get screenShareNotificationBody => '통화 중인 모두가 볼 수 있어요';

  @override
  String get screenShareNotificationStop => '중지';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name님이 이미 공유 중이에요';
  }

  @override
  String get screenShareFailed => '공유를 시작할 수 없어요';

  @override
  String get screenSharePickerTitle => '화면 공유';

  @override
  String get screenSharePickerScreens => '화면';

  @override
  String get screenSharePickerWindows => '창';

  @override
  String get screenSharePickerEmpty =>
      '아직 공유할 것이 없어요 — 시스템 설정에서 화면 기록을 허용한 뒤 다시 시도하세요';

  @override
  String get gameTellFriends => '친구들에게 알리기';

  @override
  String get gameToldFriends => '알렸어요';

  @override
  String get gameTellFriendsTitle => '친구들에게 알릴까요?';

  @override
  String get gameTellFriendsBody => '이 결과가 알림으로 가요. 한 번만 보낼 수 있어요.';

  @override
  String get gameTellFriendsCancel => '나중에';

  @override
  String get gameTellFriendsConfirm => '보내기';

  @override
  String get gameTellFriendsSent => '보냈어요';

  @override
  String get gameTellFriendsPrivate => '데일리 점수가 비공개라 아무도 못 봐요';

  @override
  String get gameTellFriendsFailed => '보내지 못했어요';

  @override
  String get settingsScreenFriendActivityLabel => '친구 소식';

  @override
  String get settingsScreenFriendActivityOnBody => '올라오는 대로 하이라이트, 포인트, 게임 결과';

  @override
  String get settingsScreenFriendActivityOffBody => '없음 — 보드는 찾아가면 그대로 있어요';

  @override
  String get searchScreenActionWithGrownUp => '보호자 확인 중';

  @override
  String get newChatMenuSearchHint => '친구 검색';

  @override
  String get newChatMenuNoFriendsYet => '아직 친구가 없어요 —\\n탐색에서 사람을 찾아보세요';

  @override
  String get newChatMenuNoFriendsMatch => '일치하는 친구가 없어요';

  @override
  String get newChatMenuOpenDmFailed => '그 채팅을 열지 못했어요 — 다시 시도해 주세요';

  @override
  String get childPolicyScreenAddSomeoneLabel => '내 사람 중에서 고르기';

  @override
  String get childPolicyScreenPickPersonHint => '이름이나 사용자 이름 검색';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      '친구 중에 더 추가할 사람이 없어요 —\\n다른 사람을 검색해 보세요';

  @override
  String get childPolicyScreenPickPersonNoMatch => '일치하는 사람이 없어요';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => '내 친구';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => '그 밖의 사람';

  @override
  String get childPolicyScreenAddRoomLabel => '방 추가';

  @override
  String get childPolicyScreenPickRoomHeading => '방 추가';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return '내가 있는 방이에요. $name 은(는) 바로 들어가고, 되돌리기 전까지 읽고 쓸 수 있어요.';
  }

  @override
  String get childPolicyScreenPickRoomHint => '내 방 검색';

  @override
  String get childPolicyScreenPickRoomEmpty => '추가할 방이 더 없어요';

  @override
  String get childPolicyScreenPickRoomNoMatch => '일치하는 방이 없어요';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name 이(가) 이제 $room 에 있어요';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      '그 방을 추가하지 못했어요 — 다시 시도해 주세요';

  @override
  String get childPolicyScreenErrorRoomNotAllowed => '그 방은 이렇게 추가할 수 없어요';

  @override
  String get childPolicyScreenErrorRoomGone => '그 방은 더 이상 없어요';

  @override
  String get newChatMenuFriendsHeader => '친구';

  @override
  String get roomChangeErrorGone => '그 제안은 사라졌어요 — 관리자가 이미 처리했을 수 있어요.';

  @override
  String get roomChangeErrorNotYours => '제안한 사람만 취소할 수 있어요.';

  @override
  String get roomChangeErrorNoChange => '이미 그렇게 되어 있어요.';

  @override
  String get roomChangeErrorMissingValue => '이대로는 저장할 수 없어요.';

  @override
  String get roomChangeRequestsTitle => '제안';

  @override
  String get roomChangeRequestsBlurb =>
      '멤버들이 제안한 것들이에요. 승인하기 전까지는 아무것도 바뀌지 않아요.';

  @override
  String get roomChangeRequestsEmpty => '제안이 없어요.';

  @override
  String get roomChangeRequestsApprove => '적용';

  @override
  String get roomChangeRequestsReject => '아니요';

  @override
  String get roomChangeRequestsPhotoLabel => '새 그룹 사진';

  @override
  String get roomChangeRequestsNameLabel => '새 이름';

  @override
  String get roomChangeRequestsDescriptionLabel => '새 소개';

  @override
  String get roomChangeRequestsUnknownLabel => '이 앱이 아직 보여줄 수 없는 변경';

  @override
  String get roomChangeRequestsClearedValue => '없음 — 지우기';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name 님의 제안';
  }

  @override
  String get roomAdminChangeRequestsRow => '제안';

  @override
  String get roomInfoScreenSuggestNote => '관리자 승인이 필요해요';

  @override
  String get roomInfoScreenSuggestAvatarNote => '새 사진은 관리자가 승인해요';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic => '그룹 사진 제안하기';

  @override
  String get roomInfoScreenSuggestionSentToast => '관리자에게 보냈어요';

  @override
  String get roomInfoScreenSuggestionAppliedToast => '완료 — 이 그룹을 편집할 수 있어요';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => '취소했어요';

  @override
  String get roomInfoScreenSuggestionsLabel => '내 제안';

  @override
  String get roomInfoScreenSuggestionPhoto => '새 그룹 사진';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return '이름: $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return '소개: $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => '변경';

  @override
  String get roomInfoScreenSuggestionPending => '관리자 기다리는 중';

  @override
  String get roomInfoScreenSuggestionWithdraw => '취소';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name 님이 새 그룹 사진을 제안했어요';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name 님이 새 이름을 제안했어요';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name 님이 새 설명을 제안했어요';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '제안 $count개가 기다리고 있어요',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => '검토';

  @override
  String get roomSuggestionBannerSemantic => '검토를 기다리는 멤버 제안';

  @override
  String get gameInfoPlay => '플레이';

  @override
  String get gameInfoContinue => '이어서 하기';

  @override
  String get gameInfoSeeResult => '내 결과 보기';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return '$total명 중 $delivered명에게 전달됨';
  }

  @override
  String get messageReceiptsSentLabel => '보냄';

  @override
  String messageReceiptsSemanticDeliveredThenRead(
    Object deliveredDay,
    Object deliveredTime,
    Object name,
    Object readDay,
    Object readTime,
  ) {
    return '$name님이 $deliveredDay $deliveredTime에 받고 $readDay $readTime에 읽었습니다';
  }

  @override
  String get messageReceiptsStampRead => '읽음';

  @override
  String get messageReceiptsStampDelivered => '전달됨';

  @override
  String get roomInviteCustom => '직접 설정';

  @override
  String roomInviteCustomHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count시간',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count회',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => '시간';

  @override
  String get roomInviteUnitDays => '일';

  @override
  String get roomInviteStepperIncrease => '늘리기';

  @override
  String get roomInviteStepperDecrease => '줄이기';

  @override
  String get recordsLabel => '역대 기록';

  @override
  String get recordsBlurb => '지금까지의 최고 기록 — 나와 친구들';

  @override
  String recordsYourBest(Object value) {
    return '내 기록 $value';
  }

  @override
  String get recordsNoneYet => '아직 없음';

  @override
  String get recordsEmpty => '아무 게임이나 풀면 최고 기록이 여기 올라와요.';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count회 성공',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return '$date 달성';
  }

  @override
  String recordsReactSemantic(Object name) {
    return '$name님의 기록에 반응하기';
  }

  @override
  String get recordsReactFailed => '반응하지 못했어요';

  @override
  String get recordsLoadFailed => '기록을 불러오지 못했어요';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game: $name님의 기록 $value';
  }

  @override
  String get appearanceLabel => '화면 모드';

  @override
  String get appearanceMatchDevice => '기기 설정 따르기';

  @override
  String get appearanceMatchDeviceSub => '낮엔 밝게, 밤엔 어둡게 — 휴대폰에 맞춰서';

  @override
  String get appearanceOneTheme => '테마 하나';

  @override
  String get appearanceOneThemeSub => '하루 종일 같은 모습';

  @override
  String get appearanceLightSlot => '라이트 모드';

  @override
  String get appearanceDarkSlot => '다크 모드';

  @override
  String get appearanceNow => '지금';

  @override
  String appearanceAutoValue(Object name) {
    return '자동 · $name';
  }

  @override
  String get themeScreenAssignHint => '테마를 눌러 라이트·다크 모드에 적용 · ⛶ 전체 미리보기';

  @override
  String get themeScreenCarouselUseLight => '라이트 모드에 적용';

  @override
  String get themeScreenCarouselUseDark => '다크 모드에 적용';

  @override
  String get themeScreenCarouselIsLight => '내 라이트 테마';

  @override
  String get themeScreenCarouselIsDark => '내 다크 테마';

  @override
  String get onboardingThemeTitle => '나답게.';

  @override
  String get onboardingThemeBody => '원하는 모습을 골라요. 설정에서 언제든 바꿀 수 있어요.';

  @override
  String get onboardingThemeYourTheme => '내 테마';

  @override
  String get onboardingThemeContinue => '계속';

  @override
  String get dropHintNoTarget => '채팅 위에 놓으면 보내집니다';

  @override
  String get dropNothingToSend => '보낼 수 있는 것이 없어요';

  @override
  String dropSendPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '사진 $count장 보내기',
    );
    return '$_temp0';
  }

  @override
  String dropSendVideos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '동영상 $count개 보내기',
    );
    return '$_temp0';
  }

  @override
  String dropSendAudio(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오디오 $count개 보내기',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '파일 $count개 보내기',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 보내기',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => '메시지에 추가';

  @override
  String get dropSendLink => '링크 추가';

  @override
  String dropTargetTo(String name) {
    return '$name에게';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개가 $size을(를) 넘습니다',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => '폴더는 보낼 수 없어요';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '빈 파일 $count개는 건너뜁니다',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => '여기서는 첨부할 수 없어요';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개는 파일로 전송돼요',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개는 일부 기기에서 안 보일 수 있어요',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => '사진';

  @override
  String get dropKindVideo => '동영상';

  @override
  String get dropKindAudio => '오디오';

  @override
  String get dropKindFile => '파일';

  @override
  String get dropKindFolder => '폴더';

  @override
  String get dropKindText => '텍스트';

  @override
  String get dropKindLink => '링크';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개는 한 번에 보낼 수 없었어요',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed => '처리하지 못했어요. 다시 시도해 주세요.';

  @override
  String get expressionBackspace => '삭제';

  @override
  String get expressionCreateSticker => '스티커 만들기';

  @override
  String get expressionDeleteSticker => '내 스티커에서 삭제';

  @override
  String get expressionFavorite => '즐겨찾기에 추가';

  @override
  String get expressionFavorited => '즐겨찾기에 추가했어요';

  @override
  String get expressionFavorites => '즐겨찾기';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF: $title';
  }

  @override
  String get expressionLoadFailed => '불러오지 못했어요. 연결을 확인해 주세요.';

  @override
  String get expressionMediaNotAllowed => '가족 설정에서 사진 보내기가 허용되지 않아요.';

  @override
  String get expressionMyStickers => '내 스티커';

  @override
  String get expressionNoFavorites => 'GIF나 스티커를 길게 눌러 즐겨찾기에 추가하세요.';

  @override
  String get expressionNoRecents => '보낸 GIF와 스티커가 여기에 표시돼요.';

  @override
  String get expressionNoResults => '결과 없음';

  @override
  String get expressionNoStickers => '아직 스티커가 없어요.';

  @override
  String get expressionOpenPanel => '이모지, GIF, 스티커';

  @override
  String get expressionOptionsHint => '옵션 보기';

  @override
  String expressionPackCredit(String author, String license) {
    return '그림: $author · $license';
  }

  @override
  String get expressionPlayGifHint => '재생';

  @override
  String get expressionRecent => '최근';

  @override
  String get expressionReport => '신고';

  @override
  String get expressionReported => '감사합니다 — 신고했어요.';

  @override
  String get expressionRetry => '다시 시도';

  @override
  String get expressionSearchKlipy => 'KLIPY 검색';

  @override
  String get expressionShowKeyboard => '키보드 보기';

  @override
  String get expressionSuggestionsLabel => '스티커 추천';

  @override
  String get expressionTabEmoji => '이모지';

  @override
  String get expressionTabGifs => 'GIF';

  @override
  String get expressionTabStickers => '스티커';

  @override
  String get expressionTrending => '인기';

  @override
  String get expressionUnfavorite => '즐겨찾기에서 삭제';

  @override
  String get expressionUnfavorited => '즐겨찾기에서 삭제했어요';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return '스티커 $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel => 'GIF 및 스티커 자동 재생';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      '탭하기 전까지 멈춰 있어요. 데이터를 아낄 수 있어요.';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'GIF와 움직이는 스티커가 자동으로 재생돼요. 동작 줄이기를 켜면 멈춰요.';

  @override
  String get settingsStickerSuggestionsBody =>
      '이모지 하나만 입력하면 메시지 입력란 위에 어울리는 스티커가 표시돼요.';

  @override
  String get settingsStickerSuggestionsLabel => '스티커 추천';

  @override
  String get stickerMakerEmojiLabel => '어떤 이모지인가요?';

  @override
  String get stickerMakerFailed => '스티커를 저장하지 못했어요. 다시 시도해 주세요.';

  @override
  String get stickerMakerMoreEmoji => '이모지 더 보기';

  @override
  String get stickerMakerPreview => '스티커 미리보기';

  @override
  String get stickerMakerRemoveBackground => '배경 제거';

  @override
  String get stickerMakerSave => '저장';

  @override
  String get stickerMakerSaved => '내 스티커에 추가했어요';

  @override
  String get stickerMakerShape => '모양';

  @override
  String get stickerMakerShapeCircle => '원형';

  @override
  String get stickerMakerShapeOriginal => '원본';

  @override
  String get stickerMakerShapeRounded => '둥근 사각형';

  @override
  String get stickerMakerTitle => '새 스티커';

  @override
  String get stickerMakerTooMany => '스티커 한도에 도달했어요. 하나를 삭제해 공간을 만드세요.';

  @override
  String get expressionExpandPanel => '패널 펼치기';

  @override
  String get expressionCollapsePanel => '패널 접기';
}
