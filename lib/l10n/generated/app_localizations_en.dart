// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'CAN’T REACH SERVER';

  @override
  String get bootErrorBody => 'Convex didn’t initialize.';

  @override
  String get bootErrorRetry => 'RETRY';

  @override
  String get incomingCallNotificationTitle => 'Incoming call';

  @override
  String get incomingCallFallbackCaller => 'Someone is calling';

  @override
  String get settingsLanguageRowLabel => 'LANGUAGE';

  @override
  String get languageScreenTitle => 'language.';

  @override
  String get languageScreenSubtitle =>
      'choose the language for menus and messages from the app';

  @override
  String get languageOptionSystem => 'SYSTEM';

  @override
  String get languageOptionSystemSub => 'match your device\'s language setting';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => 'ACTIVE';

  @override
  String get languageValueSystem => 'System';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack =>
      'couldn’t ask right now — try again';

  @override
  String get roomScreenGateSendMessages => 'send messages here';

  @override
  String get roomScreenGateSendMedia => 'send pictures or voice notes';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'up to $max at a time';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'DELETE $count MESSAGES',
      one: 'DELETE MESSAGE',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'This removes them for everyone in this chat. It cannot be undone.';

  @override
  String get roomScreenDeleteConfirmButton => 'DELETE FOR EVERYONE';

  @override
  String get roomScreenJumpFailedSnack => 'couldn’t jump to that message';

  @override
  String get roomScreenViewOnceAlreadyViewed =>
      'you’ve already opened this photo.';

  @override
  String get roomScreenViewOnceGone => 'this photo is no longer available.';

  @override
  String get roomScreenViewOnceNetworkError => 'couldn’t load that photo.';

  @override
  String get roomScreenFileReadFailedSnack => 'couldn’t read that file';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'files are capped at $size';
  }

  @override
  String get roomScreenRoomGone => 'room gone';

  @override
  String get roomScreenCopiedSnack => 'copied';

  @override
  String get roomScreenNameCopiedSnack => 'name copied';

  @override
  String get roomScreenPinLimitSnack => 'too many pins — unpin one first';

  @override
  String get roomScreenPinFailedSnack => 'couldn’t pin that';

  @override
  String get roomScreenReportSentSnack =>
      'report sent privately. they won’t be notified.';

  @override
  String get roomScreenDeselectMessageSemantic => 'Deselect message';

  @override
  String get roomScreenSelectMessageSemantic => 'Select message';

  @override
  String roomScreenMemberCountBadge(Object count) {
    return '$count INSIDE';
  }

  @override
  String roomScreenTtlSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '$count second',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    return '$_temp0';
  }

  @override
  String roomScreenEphemeralNotice(Object ttl) {
    return 'this room is ephemeral. messages dissolve after $ttl, read or unread.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count MESSAGES';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'Secret Space';

  @override
  String get roomScreenSecretSpaceBody =>
      'Messages in this room are ephemeral. They are automatically removed based on the room’s security policy.';

  @override
  String get roomScreenAutoDeleteTitle => 'Auto-Delete';

  @override
  String get roomScreenAutoDeleteVaries => 'Varies';

  @override
  String get roomScreenAutoDeleteTimed => 'Timed';

  @override
  String get roomScreenNoCaptureTitle => 'No Capture';

  @override
  String get roomScreenNoCaptureSubtitle => 'Screenshots Restricted';

  @override
  String get roomScreenMorePrivacyTitle => 'Much More Privacy';

  @override
  String get roomScreenMorePrivacySubtitle =>
      'Enjoy extra security features on top of already existing privacy focus.';

  @override
  String get roomScreenNoMessagesTitle => 'No Messages';

  @override
  String get roomScreenNoMessagesSubtitle =>
      'Start the conversation by sending a message';

  @override
  String get roomScreenViewProfilePictureSemantic => 'view profile picture';

  @override
  String get roomScreenViewRoomPictureSemantic => 'view room picture';

  @override
  String get messageBubbleFileFallbackName => 'document';

  @override
  String get messageBubbleAttachmentStatusFailed => 'failed';

  @override
  String get messageBubbleAttachmentStatusSending => 'sending…';

  @override
  String get messageBubbleViewOnceOpened => 'opened';

  @override
  String get messageBubbleViewOnceExpired => 'expired';

  @override
  String get messageBubbleViewOnceLabel => 'view once';

  @override
  String get messageBubbleViewOnceTapToView => 'tap to view';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Photo';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'view once photo, tap to view';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'retry sending';

  @override
  String get messageBubbleDiscardSemanticLabel => 'discard';

  @override
  String get profileScreenAccountSection => 'ACCOUNT';

  @override
  String get profileScreenAddEmailPlaceholder => 'add email';

  @override
  String get profileScreenAddEmailTitle => 'add email?';

  @override
  String get profileScreenAddNameTitle => 'add name?';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count waiting';
  }

  @override
  String get profileScreenApprovalsLabel => 'APPROVALS';

  @override
  String get profileScreenApprovalsNothingWaiting => 'nothing waiting';

  @override
  String get profileScreenApproveAction => 'APPROVE';

  @override
  String get profileScreenBlockAction => 'BLOCK';

  @override
  String get profileScreenBlockedDmWiped =>
      'blocked & DM wiped. they won’t be notified.';

  @override
  String get profileScreenBlockedOnly => 'blocked. they won’t be notified.';

  @override
  String get profileScreenBlockedUsers => 'BLOCKED USERS';

  @override
  String get profileScreenCancelAction => 'CANCEL';

  @override
  String get profileScreenCancelRequestAction => 'CANCEL REQUEST';

  @override
  String get profileScreenChangeAction => 'CHANGE';

  @override
  String get profileScreenChangeEmailTitle => 'change email?';

  @override
  String get profileScreenChangeNameTitle => 'change name?';

  @override
  String get profileScreenChangeProfilePictureSemantic =>
      'change profile picture';

  @override
  String get profileScreenChangeRecoveryPhrase => 'CHANGE RECOVERY PHRASE';

  @override
  String get profileScreenChooseFromLibrary => 'CHOOSE FROM LIBRARY';

  @override
  String get profileScreenCouldNotSaveImage => 'couldn’t save image.';

  @override
  String get profileScreenDeleteAccount => 'DELETE ACCOUNT';

  @override
  String get profileScreenEmailHint => 'optional — never shown to anyone';

  @override
  String get profileScreenEmailSectionLabel => 'EMAIL';

  @override
  String get profileScreenErrorAlreadyFriends => 'you’re already friends.';

  @override
  String get profileScreenErrorGeneric => 'couldn’t complete that.';

  @override
  String get profileScreenErrorNotAccepting =>
      'they’re not accepting friend requests right now.';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      'they already sent you a request — check requests.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'request already sent.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'you blocked this user — unblock them first.';

  @override
  String get profileScreenErrorUserNotFound => 'this isn’t possible right now.';

  @override
  String get profileScreenFamilyAddChild => 'add a child';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count children',
      one: '$count child',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => 'FAMILY';

  @override
  String get profileScreenFriendsChip => 'FRIENDS';

  @override
  String get profileScreenGrownUpOnlyNote =>
      'Only a grown-up can do this — it needs their code or password.';

  @override
  String get profileScreenGuardiansCanSee =>
      'They can see when you’re online and who you talk to.';

  @override
  String get profileScreenHandPhoneBack => 'HAND THIS PHONE BACK';

  @override
  String get profileScreenIncomingRequestChip => 'INCOMING REQUEST';

  @override
  String get profileScreenJustTappedAction => 'JUST TAPPED';

  @override
  String get profileScreenLegalSection => 'LEGAL';

  @override
  String get profileScreenLicence => 'LICENCE';

  @override
  String get profileScreenLinkedAccountsLabel => 'LINKED ACCOUNTS';

  @override
  String get profileScreenLinkedAccountsNone => 'nothing linked';

  @override
  String get profileScreenMyGrownUps => 'MY GROWN-UPS';

  @override
  String get profileScreenNameHint => 'how the room will read you';

  @override
  String get profileScreenNobodyLookingAfter =>
      'nobody looking after this account yet';

  @override
  String get profileScreenNotAcceptingRequestsAction =>
      'NOT ACCEPTING REQUESTS';

  @override
  String get profileScreenNotConnectedChip => 'NOT CONNECTED';

  @override
  String get profileScreenOpenDmAction => 'OPEN DM';

  @override
  String get profileScreenPhotoPermissionDenied => 'photo permission denied.';

  @override
  String get profileScreenPrivacyPolicy => 'PRIVACY POLICY';

  @override
  String get profileScreenPrivacySection => 'PRIVACY';

  @override
  String get profileScreenProfilePictureTitle => 'PROFILE PICTURE';

  @override
  String get profileScreenRedactedFriend =>
      'some fields are hidden by their settings.';

  @override
  String get profileScreenRedactedStranger =>
      'limited view — they share more with friends.';

  @override
  String get profileScreenReportAction => 'REPORT';

  @override
  String get profileScreenReportSent =>
      'report sent privately. they won’t be notified.';

  @override
  String get profileScreenRequestPendingChip => 'REQUEST PENDING';

  @override
  String get profileScreenSaveAction => 'SAVE';

  @override
  String get profileScreenSavedToPhotos => 'saved to photos.';

  @override
  String get profileScreenSaveToPhotos => 'SAVE TO PHOTOS';

  @override
  String get profileScreenSendRequestAction => 'SEND REQUEST';

  @override
  String get profileScreenSetUpRecoveryPhrase => 'SET UP RECOVERY PHRASE';

  @override
  String get profileScreenSignOut => 'SIGN OUT';

  @override
  String get profileScreenTakeSelfie => 'TAKE A SELFIE';

  @override
  String get profileScreenTapAgainToConfirmDelete =>
      'TAP AGAIN TO CONFIRM DELETE';

  @override
  String get profileScreenTermsOfService => 'TERMS OF SERVICE';

  @override
  String get profileScreenThisPhoneSection => 'THIS PHONE';

  @override
  String get profileScreenUnfriendAction => 'UNFRIEND';

  @override
  String get profileScreenViewProfilePictureSemantic => 'view profile picture';

  @override
  String get profileScreenVisibilityPreferences => 'VISIBILITY PREFERENCES';

  @override
  String get cameraEditorScreenCropPresetFree => 'FREE';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'ORIG';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'cancel crop';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'discard photo';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'undo';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'redo';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'reset crop';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'rotate';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'crop';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'this browser can’t open HEIC photos';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'couldn’t open that image';

  @override
  String get cameraEditorScreenCropDoneButton => 'DONE';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'retake';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'put the pen away';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'draw on the photo';

  @override
  String get cameraEditorScreenSendingButton => 'SENDING…';

  @override
  String get cameraEditorScreenSendButton => 'SEND';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'disappears after it’s opened once';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'clear drawing';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel => 'view once: on';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel => 'view once: off';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'ink colour';

  @override
  String get glassScreenPanelLooks => 'LOOKS';

  @override
  String get glassScreenPanelBottomBar => 'BOTTOM BAR';

  @override
  String get glassScreenPanelOtherSurfaces => 'OTHER SURFACES';

  @override
  String get glassScreenPanelBarLayout => 'BAR LAYOUT';

  @override
  String get glassScreenTitle => 'glass.';

  @override
  String get glassScreenSubtitle => 'how much of what is behind comes through';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'ALL $max SLOTS FULL';
  }

  @override
  String get glassScreenSaveCurrentAs => 'SAVE CURRENT AS…';

  @override
  String get glassScreenResetEveryDial => 'RESET EVERY DIAL';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'RESET TO $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'the composer, headers, call buttons — anything that sits over text rather than over scrolling content';

  @override
  String get glassScreenMatchBottomBar => 'MATCH THE BOTTOM BAR';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'edited — save it as a new look, or reset it';

  @override
  String get glassScreenCustomPresetName => 'Custom';

  @override
  String get glassScreenUnsavedSubtitle =>
      'unsaved — give it a name to keep it';

  @override
  String get glassScreenSaveDialogTitle => 'save this look as';

  @override
  String get glassScreenNoRoomToast => 'no room — delete a look first';

  @override
  String get glassScreenRenameDialogTitle => 'rename';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'delete $name?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'the look stays on screen — it just stops having a name.';

  @override
  String get glassScreenKeepButton => 'keep';

  @override
  String get glassScreenDeleteButton => 'delete';

  @override
  String get glassScreenNameHint => 'late night';

  @override
  String get glassScreenCancelButton => 'cancel';

  @override
  String get glassScreenSaveButton => 'save';

  @override
  String get glassScreenPreviewRoomName => '# balcony';

  @override
  String get glassScreenPreviewOnlineCount => '4 online';

  @override
  String get glassScreenPreviewMessageHint => 'message';

  @override
  String get glassScreenPreviewCollapseLabel => 'collapse preview';

  @override
  String get glassScreenPreviewExpandLabel => 'expand preview';

  @override
  String get glassScreenPreviewBadge => 'PREVIEW';

  @override
  String get glassScreenBuiltInLabel => 'built in';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'overwrite $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'rename $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'delete $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'reset $label';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'sent the roof photos — the tiles are all cracked';

  @override
  String get glassScreenBackdropMsgMert =>
      'ok but who is actually bringing the speaker';

  @override
  String get glassScreenBackdropGroupFamily => 'family';

  @override
  String get glassScreenBackdropMsgFamily =>
      'Anne: dinner at 8, do not be late again';

  @override
  String get glassScreenBackdropMsgZeynep => 'i am outside';

  @override
  String get glassScreenBackdropMsgKerem =>
      'that place on the corner does the good coffee';

  @override
  String get glassScreenBackdropGroupWork => 'work';

  @override
  String get glassScreenBackdropMsgWork =>
      'standup moved to 10:30 for the rest of the week';

  @override
  String get glassScreenBackdropMsgElif => 'no way. send it again i lost it';

  @override
  String get glassScreenBackdropMsgBaran => 'landed 👍';

  @override
  String get glassScreenBackdropMsgAyse =>
      'the cat has learned to open the balcony door';

  @override
  String get glassScreenBackdropMsgCan => 'see you saturday then';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return 'in reply to $name';
  }

  @override
  String get replyIndicatorViewOnceLabel => 'photo · view once';

  @override
  String get replyIndicatorVoiceMessageLabel => 'voice message';

  @override
  String get replyIndicatorDocumentLabel => 'document';

  @override
  String get replyIndicatorMessageRemoved => 'message removed';

  @override
  String get threadOverlayMessageNotFound =>
      'couldn’t find that message in this thread';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'couldn’t find the thread to reply to';

  @override
  String get threadOverlayStillSending =>
      'still sending — try again in a second';

  @override
  String get threadOverlayCopiedToast => 'copied';

  @override
  String get threadOverlayNameCopiedToast => 'name copied';

  @override
  String get threadOverlayPinLimitToast => 'too many pins — unpin one first';

  @override
  String get threadOverlayPinFailedToast => 'couldn’t pin that';

  @override
  String get threadOverlayReportedToast => 'reported';

  @override
  String get threadOverlayUnavailable => 'thread unavailable';

  @override
  String get roomInfoScreenNameRequiredError => 'name is required';

  @override
  String get roomInfoScreenSavedSnackbar => 'saved';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'password cleared';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'leave room?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'you can rejoin if it stays open.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'LEAVE';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'delete room?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'every message in here goes with it. this is permanent.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'DELETE';

  @override
  String get roomInfoScreenConfirmCancelButton => 'CANCEL';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'a room with that name already exists';

  @override
  String get roomInfoScreenErrorNotOwner => 'only the owner can do that';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'you don’t have permission';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'this room is gone';

  @override
  String get roomInfoScreenRoomGone => 'room gone';

  @override
  String get roomInfoScreenNameLabel => 'NAME';

  @override
  String get roomInfoScreenNameHint => 'room name';

  @override
  String get roomInfoScreenDescriptionLabel => 'DESCRIPTION';

  @override
  String get roomInfoScreenDescriptionHint => 'one line about the room…';

  @override
  String get roomInfoScreenVisibilityLabel => 'VISIBILITY';

  @override
  String get roomInfoScreenPublicTitle => 'public';

  @override
  String get roomInfoScreenPublicSub => 'anyone can find it';

  @override
  String get roomInfoScreenPrivateTitle => 'private';

  @override
  String get roomInfoScreenPrivateSub => 'invite only';

  @override
  String get roomInfoScreenMessageLifeLabel => 'MESSAGE LIFE';

  @override
  String roomInfoScreenTtlSeconds(Object value) {
    return '${value}s';
  }

  @override
  String roomInfoScreenTtlMinutes(Object value) {
    return '${value}m';
  }

  @override
  String roomInfoScreenTtlHours(Object value) {
    return '${value}h';
  }

  @override
  String get roomInfoScreenPasswordLabel => 'PASSWORD';

  @override
  String get roomInfoScreenLockedBadge => 'LOCKED';

  @override
  String get roomInfoScreenNoneBadge => 'NONE';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      'this room is protected. the existing passphrase isn’t shown for security — enter a new one to replace it.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'replace passphrase…';

  @override
  String get roomInfoScreenSetPasswordHint => 'lock with a passphrase…';

  @override
  String get roomInfoScreenRemovePasswordButton => 'REMOVE PASSWORD';

  @override
  String get roomInfoScreenSharedContentLabel => 'SHARED CONTENT';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return 'MEMBERS · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => 'LEAVING…';

  @override
  String get roomInfoScreenLeaveRoomButton => 'LEAVE ROOM';

  @override
  String get roomInfoScreenDeletingButton => 'DELETING…';

  @override
  String get roomInfoScreenDeleteButtonLabel => 'DELETE';

  @override
  String get roomInfoScreenHeaderConversation => 'CONVERSATION';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'ROOM SETTINGS';

  @override
  String get roomInfoScreenViewProfilePictureSemantic => 'view profile picture';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'view room picture';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'change room picture';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'add room picture';

  @override
  String get roomInfoScreenLoadingMembers => 'loading members…';

  @override
  String get roomInfoScreenOwnerBadge => 'OWNER';

  @override
  String get roomInfoScreenSaveButton => 'SAVE';

  @override
  String get roomInfoScreenNoneCount => 'none';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'camera access is off.\nturn it on in Settings to take a photo.';

  @override
  String get cameraScreenOpeningSystemCamera => 'opening the system camera…';

  @override
  String get cameraScreenCloseButtonLabel => 'close camera';

  @override
  String get cameraScreenLowLightBoostOnLabel => 'low-light boost: on';

  @override
  String get cameraScreenLowLightBoostOffLabel => 'low-light boost: off';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'flash: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'choose from library';

  @override
  String get cameraScreenSwitchCameraLabel => 'switch camera';

  @override
  String get cameraScreenTakePhotoLabel => 'take photo';

  @override
  String get childPolicyScreenAddByUsernameLabel => 'ADD BY USERNAME';

  @override
  String get childPolicyScreenAddCta => 'ADD';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'They get exactly what you have: every request to approve, every setting to change, and the power to remove you. $name sees them as family straight away.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'ADD A GROWN-UP';

  @override
  String get childPolicyScreenAddGuardianHint => 'their username';

  @override
  String get childPolicyScreenAllowCta => 'ALLOW';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'You won’t be asked about them again — whether $childName adds them or they add $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'ALLOW SOMEONE';

  @override
  String get childPolicyScreenAskToAddLabel => 'ASK TO ADD';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'family only — no new requests';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'they can ask you about new people';

  @override
  String get childPolicyScreenBothFinalNote =>
      'Both of these are final. Stepping away instead is up in GROWN-UPS.';

  @override
  String get childPolicyScreenCallsLabel => 'CALLS';

  @override
  String get childPolicyScreenCallsOffDesc => 'messages only';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'voice + video with people they’re allowed';

  @override
  String get childPolicyScreenCancelLabel => 'CANCEL';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Cancel';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'added — the request is on its way';

  @override
  String get childPolicyScreenContactAddedToList => 'added to the allowed list';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'MAKE ROOMS';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'they can’t start rooms';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'they can start their own private rooms';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Everything goes: their messages, photos, rooms, and friends. This cannot be undone, and the username is freed for anyone else.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'couldn’t delete the account — try again';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return 'DELETE $name’S ACCOUNT?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Messages, photos, rooms and friends all go. Cannot be undone.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'DELETE $name’S ACCOUNT';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'DELETE FOREVER';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'couldn’t add them — try again';

  @override
  String get childPolicyScreenErrorCannotAddSelf => 'that’s their own username';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'a child can’t be a grown-up';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'couldn’t do that — try again';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'someone has to look after them — add another grown-up first';

  @override
  String get childPolicyScreenErrorNotYours => 'that’s not yours to change';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'no account with that username';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'They become a normal account with this password, and every grown-up loses all visibility. There is no way back — you would have to be invited like anyone else.';

  @override
  String get childPolicyScreenGraduateCta => 'GRADUATE';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'They keep everything and get a password. You lose all visibility. Irreversible.';

  @override
  String get childPolicyScreenGraduateDangerLabel =>
      'GRADUATE TO A FULL ACCOUNT';

  @override
  String get childPolicyScreenGraduateFailed =>
      'couldn’t graduate them — try again';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'GRADUATE $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'a password for them';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Taking a room back also removes them from it. Taking a person back deletes their chat as well — for both of them.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Everyone here can approve, change settings, and see everything. Any of them can act alone — nothing waits on the others.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'added — they can look after them now';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name removed';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (you)';
  }

  @override
  String get childPolicyScreenLoading => 'loading…';

  @override
  String get childPolicyScreenLockedLabel => 'LOCKED';

  @override
  String get childPolicyScreenMediaLabel => 'PHOTOS + VOICE';

  @override
  String get childPolicyScreenMediaOffDesc => 'text only';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'they can send pictures, video and voice notes';

  @override
  String get childPolicyScreenNoRoomsYet => 'no rooms yet';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Anyone here can be added without asking you again — whichever of them starts it.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Always off for kids. Discover — the list of rooms belonging to people you don’t know — is hidden completely and can’t be switched on. Rooms someone invites them to still work as normal.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'PUBLIC ROOMS';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian will no longer see or approve anything for $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return 'REMOVE $name?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'REMOVE';

  @override
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count in';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'GROWN-UPS';

  @override
  String get childPolicyScreenSectionPeopleAllowed => 'PEOPLE YOU’VE ALLOWED';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'ROOMS YOU’VE ALLOWED';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'WHAT THEY CAN DO';

  @override
  String get childPolicyScreenSectionWhenDone => 'WHEN THEY’RE DONE';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'nothing happens until someone adds the other';

  @override
  String get childPolicyScreenSendNowOnDesc => 'they get asked straight away';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'SEND THE REQUEST NOW';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'You’re $name’s only grown-up, so you can’t just step away — add another first, or use one of these.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'STEP AWAY';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'You’ll lose every bit of visibility into $name’s account — their requests, their people, their rooms. The other grown-ups keep looking after them.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'STOP SUPERVISING';

  @override
  String get childPolicyScreenStopSupervisingHeadline => 'STOP SUPERVISING?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'couldn’t take them back — try again';

  @override
  String get childPolicyScreenTakeBackLabel => 'TAKE BACK';

  @override
  String get childPolicyScreenUsernameHint => 'username';

  @override
  String get childPolicyScreenYou => 'you';

  @override
  String get roomContentScreenDefaultDocumentName => 'document';

  @override
  String get roomContentScreenCouldntOpenFile => 'couldn’t open that file';

  @override
  String get roomContentScreenCouldntShare => 'couldn’t share those';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'copied $count links',
      one: 'copied',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'DELETE $count MESSAGES',
      one: 'DELETE MESSAGE',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'This removes them for everyone in this chat. It cannot be undone.';

  @override
  String get roomContentScreenDeleteForEveryone => 'DELETE FOR EVERYONE';

  @override
  String get roomContentScreenCancelTooltip => 'Cancel';

  @override
  String get roomContentScreenBackTooltip => 'Back';

  @override
  String get roomContentScreenSelectingLabel => 'SELECTING';

  @override
  String get roomContentScreenSharedContentLabel => 'SHARED CONTENT';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      zero: 'nothing picked',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'SELECT';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'ALL';

  @override
  String get roomContentScreenEmptyMedia => 'no photos or videos yet';

  @override
  String get roomContentScreenEmptyFiles => 'no files yet';

  @override
  String get roomContentScreenEmptyVoice => 'no voice notes yet';

  @override
  String get roomContentScreenEmptyLinks => 'no links yet';

  @override
  String get roomContentScreenLoadFailed => 'couldn’t load that';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Voice message from $name';
  }

  @override
  String get roomContentScreenForwardAction => 'FORWARD';

  @override
  String get roomContentScreenCopyAction => 'COPY';

  @override
  String get roomContentScreenSaveAction => 'SAVE';

  @override
  String get roomContentScreenShareAction => 'SHARE';

  @override
  String get roomContentScreenInChatAction => 'IN CHAT';

  @override
  String get roomContentScreenDeleteAction => 'DELETE';

  @override
  String get messageActionMenuReplyLabel => 'REPLY';

  @override
  String get messageActionMenuForwardLabel => 'FORWARD';

  @override
  String get messageActionMenuViewThreadLabel => 'VIEW THREAD';

  @override
  String get messageActionMenuCopyLabel => 'COPY';

  @override
  String get messageActionMenuCopyNameLabel => 'COPY NAME';

  @override
  String get messageActionMenuPinLabel => 'PIN';

  @override
  String get messageActionMenuUnpinLabel => 'UNPIN';

  @override
  String get messageActionMenuSelectLabel => 'SELECT';

  @override
  String get messageActionMenuProfileLabel => 'PROFILE';

  @override
  String get messageActionMenuDeleteLabel => 'DELETE';

  @override
  String get messageActionMenuReportLabel => 'REPORT';

  @override
  String get themeScreenTitle => 'theme.';

  @override
  String get themeScreenTapToApplyHint => 'tap to apply · ⛶ for full preview';

  @override
  String get themeScreenFamilyBasicName => 'BASIC';

  @override
  String get themeScreenFamilyBasicTagline => 'ios-inspired · 5 palettes';

  @override
  String get themeScreenFamilyVaultName => 'VAULT';

  @override
  String get themeScreenFamilyVaultTagline => 'private dossier · noir + ivory';

  @override
  String get themeScreenFamilyOthersName => 'OTHERS';

  @override
  String get themeScreenFamilyOthersTagline => 'singular moods';

  @override
  String get themeScreenActiveBadge => 'ACTIVE';

  @override
  String get themeScreenTapToApplyLabel => 'tap to apply';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return 'ACTIVE — $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return 'APPLY $name';
  }

  @override
  String get themeScreenPreviewGreeting => 'hey, you.';

  @override
  String get themeScreenPreviewSectionLabel => 'CONVERSATION';

  @override
  String get themeScreenPreviewRoomOneName => 'design club';

  @override
  String get themeScreenPreviewRoomOneSub => 'mia: shipped the new tile.';

  @override
  String get themeScreenPreviewRoomTwoName => 'chamber · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => 'sealed in 4h.';

  @override
  String get themeScreenPreviewBubbleQuestion => 'how does this feel?';

  @override
  String get themeScreenPreviewBubbleAnswer => 'like the right one.';

  @override
  String get callScreenVideoCallLabel => 'Video call';

  @override
  String get callScreenVoiceCallLabel => 'Voice call';

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · ringing…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · incoming';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · connecting…';
  }

  @override
  String get callScreenStatusConnected => 'connected';

  @override
  String get callScreenStatusEnded => 'call ended';

  @override
  String get callScreenStatusFailed => 'call failed';

  @override
  String get callScreenStatusSwitching => 'switching device…';

  @override
  String get callScreenStatusMoved => 'moved';

  @override
  String get callScreenStatusReconnecting => 'reconnecting…';

  @override
  String get callScreenPoorConnectionLabel => 'poor connection';

  @override
  String get callScreenWeakConnectionLabel => 'weak connection';

  @override
  String get callScreenControlUnmute => 'unmute';

  @override
  String get callScreenControlMute => 'mute';

  @override
  String get callScreenControlCamOn => 'cam on';

  @override
  String get callScreenControlCamOff => 'cam off';

  @override
  String get callScreenControlFlip => 'flip';

  @override
  String get callScreenControlSpeaker => 'speaker';

  @override
  String get callScreenControlEnd => 'end';

  @override
  String get linkPreviewCardLinkLabel => 'LINK';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name accepted your request';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'that request was withdrawn';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'request declined';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'you blocked this user — unblock first.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'they\'re not accepting friend requests right now.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'couldn\'t send. try again.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => 'INCOMING REQUEST';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'NEW REQUEST';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name wants to start a conversation.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'send a few lines. they can approve or decline.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'nothing here lives anywhere permanent until both sides agree.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'ROOM TYPE';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'EPHEMERAL';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'STANDARD';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'LIFETIME';

  @override
  String friendRequestDraftScreenDurationSeconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String friendRequestDraftScreenDurationMinutes(Object minutes) {
    return '${minutes}m';
  }

  @override
  String friendRequestDraftScreenDurationHours(Object hours) {
    return '${hours}h';
  }

  @override
  String get friendRequestDraftScreenHintWhisperOptional =>
      'whisper a first line · optional';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'add a first message · optional';

  @override
  String get friendRequestDraftScreenHintWhisperFades => 'whisper · auto-fades';

  @override
  String get friendRequestDraftScreenHintStartWith =>
      'something to start with…';

  @override
  String get friendRequestDraftScreenApproveButton => 'APPROVE & OPEN ROOM';

  @override
  String get friendRequestDraftScreenDeclineButton => 'DECLINE';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'CANCEL REQUEST';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => 'ASK A GROWN-UP';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'SEND REQUEST';

  @override
  String get discoverScreenTitle => 'discover.';

  @override
  String get discoverScreenCaptionPeople => 'people';

  @override
  String get discoverScreenCaptionRooms => 'rooms';

  @override
  String get discoverScreenCaptionRequests => 'requests';

  @override
  String get discoverScreenPeopleBandLabel => 'PEOPLE';

  @override
  String get discoverScreenRoomsBandLabel => 'ROOMS';

  @override
  String get discoverScreenFindPeopleTitle => 'find people';

  @override
  String get discoverScreenFindPeopleSubtitleChild => 'type a whole username';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'search by @username or name';

  @override
  String get discoverScreenRequestsSectionLabel => 'REQUESTS';

  @override
  String get discoverScreenInboxQuiet => 'inbox quiet';

  @override
  String get discoverScreenNothingPending => 'nothing pending';

  @override
  String get discoverScreenYourPeopleLabel => 'YOUR PEOPLE';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'no one yet — find people above';

  @override
  String get discoverScreenNoFriendsYet => 'no one yet';

  @override
  String get discoverScreenSearchRoomsTitle => 'search rooms';

  @override
  String get discoverScreenSearchRoomsSubtitle => 'find a public room by name';

  @override
  String get discoverScreenPublicRoomsLabel => 'PUBLIC ROOMS';

  @override
  String get discoverScreenLoadingRooms => 'looking…';

  @override
  String get discoverScreenNoRoomsOpen => 'nothing open right now';

  @override
  String get discoverScreenIncomingLabel => 'incoming';

  @override
  String get discoverScreenOutgoingLabel => 'outgoing';

  @override
  String get discoverScreenIncomingLabelCaps => 'INCOMING';

  @override
  String get discoverScreenOutgoingLabelCaps => 'OUTGOING';

  @override
  String get discoverScreenJumpPeopleLabel => 'people';

  @override
  String get discoverScreenJumpRoomsLabel => 'rooms';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Jump to $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'adjust';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'USE PHOTO';

  @override
  String get imageCropScreenSavingButton => 'SAVING…';

  @override
  String get imageCropScreenCancelButton => 'CANCEL';

  @override
  String get imageCropScreenHeicUnsupported =>
      'this browser can\'t open HEIC photos';

  @override
  String get imageCropScreenLoadFailed => 'couldn\'t open that image';

  @override
  String get imageCropScreenHintCircle => 'drag to move, pinch to zoom';

  @override
  String get imageCropScreenHintRect => 'drag and pinch to frame';

  @override
  String get loginScreenSignInHeroMuted => 'welcome\n';

  @override
  String get loginScreenSignInHeroInk => 'back.';

  @override
  String get loginScreenSignInCta => 'SIGN IN';

  @override
  String get loginScreenSignUpHeroMuted => 'new\n';

  @override
  String get loginScreenSignUpHeroInk => 'face.';

  @override
  String get loginScreenSignUpCta => 'OPEN ACCOUNT';

  @override
  String get loginScreenResetHeroMuted => 'reset\n';

  @override
  String get loginScreenResetHeroInk => 'password.';

  @override
  String get loginScreenResetCta => 'RESET PASSWORD';

  @override
  String get loginScreenErrorPasswordsDontMatch => 'Passwords don’t match.';

  @override
  String get loginScreenErrorChoosePasswordFirst => 'Choose a password first.';

  @override
  String get loginScreenUsernameHint => 'username';

  @override
  String get loginScreenPasswordHint => 'password';

  @override
  String get loginScreenConfirmPasswordHint => 'confirm password';

  @override
  String get loginScreenNameOptionalHint => 'name (optional)';

  @override
  String get loginScreenRecoveryPhraseHint => 'your 12-word recovery phrase';

  @override
  String get loginScreenNewPasswordHint => 'new password';

  @override
  String get loginScreenBackToSignIn => '← back to sign in';

  @override
  String get loginScreenForgotPassword => 'forgot password?';

  @override
  String get loginScreenSettingUpKidsPhone => 'set up a child account';

  @override
  String get loginScreenLegalPrefix =>
      'By opening an account you agree to the ';

  @override
  String get loginScreenLegalTermsLink => 'Terms';

  @override
  String get loginScreenLegalMiddle => ' and the ';

  @override
  String get loginScreenLegalPrivacyLink => 'Privacy Policy';

  @override
  String get loginScreenLegalSuffix => '.';

  @override
  String get loginScreenAlreadyHerePrompt => 'already here? ';

  @override
  String get loginScreenSignInLink => 'sign in';

  @override
  String get loginScreenNoAccountPrompt => 'no account? ';

  @override
  String get loginScreenOpenOneLink => 'open one';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12 words';
  }

  @override
  String get homeShellEmptyRoomHint => 'pick a room to start chatting';

  @override
  String get homeShellEmptySettingHint => 'pick a setting';

  @override
  String get searchScreenHintPeople => 'search people…';

  @override
  String get searchScreenHintRooms => 'search rooms…';

  @override
  String get searchScreenPeoplePromptChild =>
      'type a whole username to find someone new';

  @override
  String get searchScreenPeoplePromptDefault => 'search by username or name';

  @override
  String get searchScreenNoMatchChild =>
      'no one matches — new people need their\nwhole username, spelled exactly';

  @override
  String get searchScreenNoMatchDefault => 'no one matches';

  @override
  String get searchScreenNoRoomsYet => 'no public rooms yet';

  @override
  String get searchScreenNoRoomsMatch => 'no public rooms match';

  @override
  String get searchScreenActionAskToAdd => 'ASK TO ADD';

  @override
  String get searchScreenActionSendRequest => 'SEND REQUEST';

  @override
  String get searchScreenActionCancel => 'CANCEL';

  @override
  String get searchScreenActionApprove => 'APPROVE';

  @override
  String get searchScreenActionOpenDm => 'OPEN DM';

  @override
  String get searchScreenAskedLabel => 'asked';

  @override
  String get profileVisibilityScreenTitle => 'visibility preferences.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'control what others see — and how they can reach you.';

  @override
  String get profileVisibilityScreenSectionProfile => 'PROFILE';

  @override
  String get profileVisibilityScreenAvatarLabel => 'AVATAR';

  @override
  String get profileVisibilityScreenAvatarDesc => 'your profile picture';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => 'ONLINE / AWAY';

  @override
  String get profileVisibilityScreenOnlineAwayDesc =>
      'whether you appear active right now';

  @override
  String get profileVisibilityScreenLastSeenLabel => 'LAST SEEN';

  @override
  String get profileVisibilityScreenLastSeenDesc =>
      'the time you were last around';

  @override
  String get profileVisibilityScreenSectionMessages => 'MESSAGES';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel =>
      'SEND READ RECEIPTS';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      'when on, others can see that you\'ve read their messages';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel =>
      'SHOW READ RECEIPTS';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      'see the \"SEEN\" mark on your own messages once they\'re read';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      'only readers who turned on SEND READ RECEIPTS will contribute. others stay invisible.';

  @override
  String get profileVisibilityScreenSectionPeople => 'PEOPLE';

  @override
  String get profileVisibilityScreenFriendRequestsLabel => 'FRIEND REQUESTS';

  @override
  String get profileVisibilityScreenFriendRequestsDesc =>
      'who can send you friend requests';

  @override
  String get profileVisibilityScreenSupervisedTitle =>
      'YOUR GROWN-UPS SET THESE';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      'You can see what everyone else sees here, but only a grown-up can change it. They can always see your picture, when you\'re online and when you were last around.';

  @override
  String get profileVisibilityScreenOptionPublic => 'PUBLIC';

  @override
  String get profileVisibilityScreenOptionFriends => 'FRIENDS';

  @override
  String get profileVisibilityScreenOptionNobody => 'NOBODY';

  @override
  String get profileVisibilityScreenOptionOn => 'ON';

  @override
  String get profileVisibilityScreenOptionOff => 'OFF';

  @override
  String get profileVisibilityScreenOptionAnyone => 'ANYONE';

  @override
  String get logoScreenTitle => 'app logo.';

  @override
  String get logoScreenSubtitle => 'the mark in your header, your call.';

  @override
  String get logoScreenAutoLabel => 'AUTO';

  @override
  String get logoScreenAutoDescription =>
      'follows your theme. mark changes with the palette.';

  @override
  String get logoScreenManualLabel => 'MANUAL';

  @override
  String get logoScreenManualDescription => 'pick any mark, keep your theme.';

  @override
  String get logoScreenAlwaysDefaultLabel => 'ALWAYS DEFAULT';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      'the MonkeyHub mark, regardless of theme.';

  @override
  String get logoScreenActiveBadge => 'ACTIVE';

  @override
  String get logoScreenMonkeyCollectionHeader => 'MONKEY COLLECTION';

  @override
  String get logoScreenThemesHeader => 'THEMES';

  @override
  String get recoveryPhraseScreenCopiedSnackbar =>
      'copied — paste it somewhere safe';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'confirm\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'it’s you.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Your password, so nobody else can put a recovery phrase on your account.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'password';

  @override
  String get recoveryPhraseScreenContinueButton => 'CONTINUE';

  @override
  String get recoveryPhraseScreenNotNowLink => 'not now';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'Enter your password.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'save\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => 'these words.';

  @override
  String get recoveryPhraseScreenWordsBody =>
      'These twelve words are the only way back into your account if you forget your password. We can’t show them to you again, and we can’t recover them for you.';

  @override
  String get recoveryPhraseScreenCopyButton => 'COPY';

  @override
  String get recoveryPhraseScreenPaperHint =>
      'If you can, write them on paper. Anything on this phone can be lost with the phone.';

  @override
  String get recoveryPhraseScreenSavedButton => 'I SAVED THEM';

  @override
  String get recoveryPhraseScreenBackLink => '← back';

  @override
  String get recoveryPhraseScreenKeepPhraseLink =>
      'not now — keep my current phrase';

  @override
  String get homeScreenProfileSemanticLabel => 'Your profile';

  @override
  String homeScreenGreeting(Object name) {
    return 'hey, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'New room';

  @override
  String get homeScreenEmptyRoomsMessage => 'no rooms yet — create one';

  @override
  String get groupCallScreenTitleVideo => 'Group video call';

  @override
  String get groupCallScreenTitleVoice => 'Group voice call';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '$count in call';
  }

  @override
  String get groupCallScreenReconnecting => 'reconnecting…';

  @override
  String get groupCallScreenUnmuteLabel => 'unmute';

  @override
  String get groupCallScreenMuteLabel => 'mute';

  @override
  String get groupCallScreenCamOnLabel => 'cam on';

  @override
  String get groupCallScreenCamOffLabel => 'cam off';

  @override
  String get groupCallScreenFlipLabel => 'flip';

  @override
  String get groupCallScreenSpeakerLabel => 'speaker';

  @override
  String get groupCallScreenLeaveLabel => 'leave';

  @override
  String get groupCallScreenYouLabel => 'You';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return 'Filtering by $summary. Change filter';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => 'Filter chats';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => 'Clear filter';

  @override
  String get roomFilterDrawerClearLabel => 'clear';

  @override
  String get roomFilterDrawerDimensionType => 'TYPE';

  @override
  String get roomFilterDrawerDimensionNature => 'NATURE';

  @override
  String get roomFilterDrawerDimensionStatus => 'STATUS';

  @override
  String get roomFilterDrawerPanelClear => 'CLEAR';

  @override
  String get roomFilterDrawerPanelDone => 'DONE';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '$count chat',
    );
    return '$label, $_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return 'nothing matches $summary';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show all $count chats',
      one: 'Show all $count chat',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'show all $count chats',
      one: 'show all $count chat',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'new room';

  @override
  String get createRoomSheetTaglineSecret => 'NOTHING WILL BE KEPT';

  @override
  String get createRoomSheetTaglineRegular => 'A SPACE THAT STAYS';

  @override
  String get createRoomSheetNameLabel => 'NAME';

  @override
  String get createRoomSheetNameHint => 'name it something honest…';

  @override
  String get createRoomSheetDescriptionLabel => 'DESCRIPTION · OPTIONAL';

  @override
  String get createRoomSheetDescriptionHint => 'one line about the room…';

  @override
  String get createRoomSheetVisibilityLabel => 'VISIBILITY';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'public';

  @override
  String get createRoomSheetVisibilityPublicSub => 'anyone can find it';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'private';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'invite only';

  @override
  String get createRoomSheetTypeLabel => 'TYPE';

  @override
  String get createRoomSheetTypeStandardTitle => 'standard';

  @override
  String get createRoomSheetTypeStandardSub => 'messages persist';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'ephemeral';

  @override
  String get createRoomSheetTypeEphemeralSub => 'auto-deletes';

  @override
  String get createRoomSheetMessageLifeLabel => 'MESSAGE LIFE';

  @override
  String createRoomSheetTtlSeconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String createRoomSheetTtlMinutes(Object minutes) {
    return '${minutes}m';
  }

  @override
  String createRoomSheetTtlHours(Object hours) {
    return '${hours}h';
  }

  @override
  String get createRoomSheetPasswordLabel => 'PASSWORD · OPTIONAL';

  @override
  String get createRoomSheetPasswordHint => 'lock with a passphrase…';

  @override
  String get createRoomSheetNameRequiredError => 'name is required';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Open the room';

  @override
  String get createRoomSheetOpenRoomButton => 'OPEN THE ROOM';

  @override
  String get familyScreenTitle => 'FAMILY';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count things need your OK',
      one: '1 thing needs your OK',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => 'online now';

  @override
  String get familyScreenPresenceNotPaired => 'not paired yet';

  @override
  String get familyScreenPresenceJustNow => 'just now';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return '${minutes}m ago';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return '${hours}h ago';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return '${days}d ago';
  }

  @override
  String get familyScreenPairButton => 'PAIR';

  @override
  String get familyScreenReleaseButton => 'RELEASE';

  @override
  String get familyScreenSettingsButton => 'SETTINGS';

  @override
  String get familyScreenAddChildButton => 'ADD A CHILD';

  @override
  String get familyScreenEmptyStateTitle => 'no children yet';

  @override
  String get familyScreenEmptyStateBody =>
      'Add an account for your child, then pair it to their phone.';

  @override
  String get reactionDetailsSheetTitle => 'REACTIONS';

  @override
  String get reactionDetailsSheetEmptyState => 'nothing here anymore';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => 'ALL';

  @override
  String get reactionDetailsSheetYouBadge => 'YOU';

  @override
  String get roomLayoutScreenTitle => 'chat list.';

  @override
  String get roomLayoutScreenSubtitle =>
      'how rooms stack, and how you filter them';

  @override
  String get roomLayoutScreenLayoutSectionLabel => 'LAYOUT';

  @override
  String get roomLayoutScreenRowLayoutLabel => 'ROW LAYOUT';

  @override
  String get roomLayoutScreenRowLayoutDescription =>
      'one column, full bleed. easy to read at a glance.';

  @override
  String get roomLayoutScreenGridLayoutLabel => 'GRID LAYOUT';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      'two columns, compact. more rooms in one look.';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => 'FILTER CONTROL';

  @override
  String get roomLayoutScreenChipRowLabel => 'CHIP ROW';

  @override
  String get roomLayoutScreenChipRowDescription =>
      'always on show. one tap to any filter, one row of space.';

  @override
  String get roomLayoutScreenDrawerButtonLabel => 'DRAWER BUTTON';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      'one button that opens. nothing in the way until you ask.';

  @override
  String get roomLayoutScreenActiveBadge => 'ACTIVE';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel => 'Jump to pinned message';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => 'All pinned messages';

  @override
  String get pinnedBannerTitleSingle => 'Pinned message';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return 'Pinned message  $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => 'chat style.';

  @override
  String get pinnedBannerChatStyleSubtitle => 'how the room looks';

  @override
  String get pinnedBannerClassicLabel => 'CLASSIC';

  @override
  String get pinnedBannerClassicSubtitle =>
      'divider-bordered header, flat composer.';

  @override
  String get pinnedBannerCompactLabel => 'COMPACT';

  @override
  String get pinnedBannerCompactSubtitle =>
      'frosted pills floating over the conversation.';

  @override
  String get pinnedBannerActiveBadge => 'ACTIVE';

  @override
  String get audioMessageMissingLabel => '[audio missing]';

  @override
  String get audioMessageUnavailableLabel => 'audio unavailable';

  @override
  String get audioMessageRetryHint => 'tap to retry';

  @override
  String get audioMessageLoadingLabel => 'loading…';

  @override
  String get audioMessageUsernameRequiredError => 'Enter your username.';

  @override
  String get audioMessagePasswordRequiredError => 'Enter your password.';

  @override
  String get audioMessageCancelSemanticLabel => 'Cancel';

  @override
  String get audioMessageHeroCreateLine1 => 'almost\n';

  @override
  String get audioMessageHeroCreateLine2 => 'there.';

  @override
  String get audioMessageHeroLinkLine1 => 'welcome\n';

  @override
  String get audioMessageHeroLinkLine2 => 'back.';

  @override
  String get audioMessageCreateSubtitle =>
      'Pick a username so your family and friends can find you.';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return 'Sign in once and $provider is attached to your account.';
  }

  @override
  String get audioMessageUsernameHint => 'username';

  @override
  String get audioMessageDisplayNameHint => 'display name (optional)';

  @override
  String get audioMessagePasswordHint => 'password';

  @override
  String get audioMessageSwitchToLinkPrompt => 'That one’s mine — sign in';

  @override
  String get audioMessageCreateAccountButton => 'CREATE ACCOUNT';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return 'SIGN IN & LINK $provider';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => 'Already have an account?';

  @override
  String get audioMessageSwitchToCreateModeLink =>
      'New here? Create an account';

  @override
  String get approvalsScreenTitle => 'APPROVALS';

  @override
  String get approvalsScreenEmptyTitle => 'nothing waiting';

  @override
  String get approvalsScreenEmptySubtitle => 'you\'re all caught up';

  @override
  String get approvalsScreenErrorNotGuardian => 'that\'s not yours to decide';

  @override
  String get approvalsScreenErrorAlreadyHandled =>
      'already handled somewhere else';

  @override
  String get approvalsScreenErrorGeneric => 'couldn\'t save that — try again';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child wants to add $other';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other wants to add $child';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child wants to join $room';
  }

  @override
  String get approvalsScreenSomeoneLower => 'someone';

  @override
  String get approvalsScreenSomeoneCapital => 'Someone';

  @override
  String get approvalsScreenRoomFallback => 'a room';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      'They\'ll get the request. They still choose whether to say yes.';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$child will see the request and can accept or ignore it.';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      'They\'ll be able to read and post there until you take it back.';

  @override
  String get approvalsScreenNotYetButton => 'NOT YET';

  @override
  String get approvalsScreenAllowButton => 'ALLOW';

  @override
  String get approvalsScreenForwardDirectMessageFallback => 'direct message';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'FORWARD $count MESSAGES',
      one: 'FORWARD MESSAGE',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'no other chats yet';

  @override
  String get approvalsScreenForwardNoMatches => 'nothing matches';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'up to $max chats at a time';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'search chats';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Deselect $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Select $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'FADES';

  @override
  String get approvalsScreenForwardSendSemantic => 'Send';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'SEND TO $count',
      zero: 'SEND',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => 'LINKED ACCOUNTS';

  @override
  String get linkedAccountsScreenSubtitle =>
      'Accounts you’ve attached to this one, so you can sign in without a password.';

  @override
  String get linkedAccountsScreenEmptyState =>
      'There’s nothing to link on this device.';

  @override
  String get linkedAccountsScreenStatusChecking => 'Checking…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return 'You can sign in with $provider on any of your devices.';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return 'Add $provider so you don’t have to type your password.';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return 'UNLINK $provider';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => 'UNLINK';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return 'Enter your password to stop signing in with $provider.';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return 'LINK $provider';
  }

  @override
  String get linkedAccountsScreenLinkAction => 'LINK';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return 'Enter your password to add $provider as a way to sign in.';
  }

  @override
  String get linkedAccountsScreenPillChecking => 'CHECKING';

  @override
  String get linkedAccountsScreenPillLinked => 'LINKED';

  @override
  String get linkedAccountsScreenPillNotLinked => 'NOT LINKED';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => 'VOICE';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'VIDEO';

  @override
  String get linkedAccountsScreenCallSheetTitle => 'Start a call';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle => 'Call everyone';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      'Ring all members of this room';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle => 'Choose people';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle =>
      'Pick who to invite';

  @override
  String get linkedAccountsScreenCallSheetCallFullError =>
      'That call is full (max 6 people)';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError =>
      'Could not start the call';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle => 'Invite to call';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers =>
      'No other members here';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => 'Select people';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => 'Start call';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return 'Start call ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => 'hello';

  @override
  String get childPairScreenGreetingLine2 => 'you.';

  @override
  String get childPairScreenIntro =>
      'Ask a grown-up to open MonkeyHub and tap “pair a device”. Then scan their code, or type the six numbers they read out.';

  @override
  String get childPairScreenOrDivider => 'or';

  @override
  String get childPairScreenGenericError => 'Something went wrong. Try again.';

  @override
  String get childPairScreenAccountGoneError =>
      'That account isn’t there any more.';

  @override
  String get childPairScreenScanButtonLabel => 'SCAN THEIR CODE';

  @override
  String get childPairScreenNoCameraMessage =>
      'No camera here — type the six numbers instead.';

  @override
  String get childPairScreenStopScanning => 'stop scanning';

  @override
  String get childPairScreenSubmitButtonLabel => 'LET ME IN';

  @override
  String get childPairScreenBackToSignIn => '← back to sign in';

  @override
  String get fileMessageUnavailable => 'file is no longer available';

  @override
  String get fileMessageOpenFailed => 'couldn\'t open that file';

  @override
  String get fileMessageDefaultName => 'document';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return 'Save $name';
  }

  @override
  String get fileMessageUploadFailedLabel => 'failed';

  @override
  String get fileMessageSendingLabel => 'sending…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · sending…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return '${count}m ago';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return '${count}h ago';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return '${count}d ago';
  }

  @override
  String get fileMessageStandardBadge => 'STANDARD';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count draft messages · tap to view',
      one: '$count draft message · tap to view',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => 'APPROVE';

  @override
  String get fileMessageDeclineButton => 'DECLINE';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'SENT $ago';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages pending',
      one: '$count message pending',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => 'CANCEL REQUEST';

  @override
  String get destructiveSheetCannotBeUndone => 'this cannot be undone';

  @override
  String get destructiveSheetCancelSemanticLabel => 'Cancel';

  @override
  String get destructiveSheetCancelButtonLabel => 'CANCEL';

  @override
  String get destructiveSheetHideLabel => 'HIDE';

  @override
  String get destructiveSheetViewLabel => 'VIEW';

  @override
  String get destructiveSheetPairingMintError =>
      'Couldn’t make a code — try again.';

  @override
  String get destructiveSheetPairingReleaseTitle => 'RELEASE';

  @override
  String get destructiveSheetPairingPairTitle => 'PAIR';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return 'On $name’s phone, open their profile, tap “hand this phone back”, and type these numbers.';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return 'On $name’s phone, open MonkeyHub and scan this — or type the numbers.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'this code has expired';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'expires in $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'NEW CODE';

  @override
  String get destructiveSheetPairingOneUseNote =>
      'One use only. Making a new code cancels the old one.';

  @override
  String get deepOceanThemeAttachButtonLabel => 'Attach';

  @override
  String get deepOceanThemeCameraButtonLabel => 'Camera';

  @override
  String get deepOceanThemeSendButtonLabel => 'Send';

  @override
  String get deepOceanThemeEphemeralHint =>
      'whisper something the server will forget…';

  @override
  String get deepOceanThemeDefaultHint => 'say something…';

  @override
  String get deepOceanThemeMessageHint => 'Message';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'this file is gone';

  @override
  String get photoChromeMediaYouLabel => 'you';

  @override
  String get photoChromeCloseSemanticLabel => 'Close';

  @override
  String get photoChromeShowInChatSemanticLabel => 'Show in chat';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name is typing';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1 and $name2 are typing';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1, $name2 +$extra are typing';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => 'incoming call';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'INCOMING VIDEO CALL';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'INCOMING VOICE CALL';

  @override
  String get typingIndicatorDeclineButtonLabel => 'decline';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'declining…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'accept';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'connecting…';

  @override
  String get messageStampNavigationTitle => 'navigation.';

  @override
  String get messageStampNavigationSubtitle =>
      'how you move between chat, discover, feed, settings';

  @override
  String get messageStampRadialOrbLabel => 'RADIAL ORB';

  @override
  String get messageStampRadialOrbDescription =>
      'hold + drag from the corner. a quiet idle, a gesture you grow into.';

  @override
  String get messageStampBottomPillLabel => 'BOTTOM PILL';

  @override
  String get messageStampBottomPillDescription =>
      'classic tap. always visible, no learning curve.';

  @override
  String get messageStampActiveLabel => 'ACTIVE';

  @override
  String get messageStampUploadingLabel => 'uploading';

  @override
  String get messageStampSendingLabel => 'sending';

  @override
  String get messageStampFailedToSendLabel => 'failed to send';

  @override
  String get messageStampSeenLabel => 'seen';

  @override
  String messageStampCountdownSeconds(Object count) {
    return '${count}s';
  }

  @override
  String messageStampCountdownMinutes(Object count) {
    return '${count}m';
  }

  @override
  String get voiceRecorderScreenMicPermissionDeniedSnackbar =>
      'microphone permission denied';

  @override
  String get voiceRecorderScreenStatusRecording => 'RECORDING';

  @override
  String get voiceRecorderScreenStatusReady => 'READY';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'TAP TO START';

  @override
  String get voiceRecorderScreenReRecordButton => 'RE-RECORD';

  @override
  String get voiceRecorderScreenStopButton => 'STOP';

  @override
  String get voiceRecorderScreenSendButton => 'SEND';

  @override
  String get voiceRecorderScreenRecordButton => 'RECORD';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => 'Everyone';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => 'NOTIFIES ALL';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => 'OWNER';

  @override
  String get releaseDeviceScreenFallbackChildName => 'them';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return 'This signs $name out of this phone and hands it back — the phone returns to the normal sign-in screen, and anyone can use it.';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'Their account, messages and friends are all kept. They can be signed back in any time.';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return 'Ask a grown-up to open MonkeyHub, find $name under family, and tap “release”.';
  }

  @override
  String get releaseDeviceScreenOrDivider => 'or';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      'If there’s only this one phone, a grown-up can sign in here instead.';

  @override
  String get releaseDeviceScreenUsernameHint => 'a grown-up’s username';

  @override
  String get releaseDeviceScreenPasswordHint => 'their password';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => 'Sign out';

  @override
  String get releaseDeviceScreenChecking => 'CHECKING…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return 'SIGN $name OUT';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => 'HAND THIS PHONE BACK';

  @override
  String get releaseDeviceScreenErrorCodeExpired =>
      'That code has run out. Ask for a new one.';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      'That code didn’t work. It may have been used already.';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      'That didn’t work. Check the username and password.';

  @override
  String get releaseDeviceScreenErrorGeneric =>
      'Something went wrong. Try again.';

  @override
  String get activeCallPillMoveHereSemanticLabel => 'Move call to this device';

  @override
  String activeCallPillCallWith(Object name) {
    return 'Call with $name';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return 'On $device';
  }

  @override
  String get activeCallPillMoveHereLabel => 'Move here';

  @override
  String get activeCallPillUnknownCaller => 'Unknown';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'iOS Simulator';

  @override
  String get activeCallPillPlatformAndroid => 'Android device';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'Windows PC';

  @override
  String get activeCallPillPlatformLinux => 'Linux device';

  @override
  String get activeCallPillPlatformBrowser => 'Browser';

  @override
  String get activeCallPillPlatformOther => 'another device';

  @override
  String get activeCallPillPinnedHeader => 'PINNED';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'PINNED · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'nothing pinned anymore';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Jump to message from $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Unpin message from $name';
  }

  @override
  String get callButtonErrorBusy => 'busy on another call';

  @override
  String get callButtonErrorCallFailed => 'could not start call';

  @override
  String get callButtonErrorNotMember => 'not a member of this room';

  @override
  String get callButtonErrorGeneric => 'could not start call';

  @override
  String get callButtonAlreadyOnCall => 'You\'re already on a call';

  @override
  String get callButtonBusyElsewhere => 'Call in progress on another device';

  @override
  String get callButtonVoiceCallTooltip => 'voice call';

  @override
  String get callButtonVideoCallTooltip => 'video call';

  @override
  String get callButtonTooltip => 'call';

  @override
  String get callButtonReplyStyleTitle => 'reply style.';

  @override
  String get callButtonReplyStyleSubtitle => 'how a reply shows its parent';

  @override
  String get callButtonReplyStylePhantomEchoLabel => 'PHANTOM ECHO';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      'a ghost-bubble of the parent floats above with a curved connector and the branch icon at the join point.';

  @override
  String get callButtonReplyStyleStickyNoteLabel => 'STICKY NOTE';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      'a slightly rotated polaroid-style card clipped to the bubble corner.';

  @override
  String get callButtonReplyStyleComicTailLabel => 'COMIC TAIL';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      'a small parent mini-bubble with a comic-book triangle tail pointing down.';

  @override
  String get callButtonReplyStyleClassicLabel => 'CLASSIC';

  @override
  String get callButtonReplyStyleClassicDescription =>
      'accent-tinted quote pill with a tether bar and avatar — the familiar WhatsApp-style look.';

  @override
  String get callButtonReplyStyleActiveBadge => 'ACTIVE';

  @override
  String get callButtonReplyPreviewSampleMessage =>
      'hey did you see the new demo though?';

  @override
  String get callButtonReplyPreviewSampleReply => 'yeah, that blur is sick.';

  @override
  String get childSetupScreenErrorPickUsername => 'Pick a username for them.';

  @override
  String get childSetupScreenErrorUsernameTaken =>
      'That username is already taken.';

  @override
  String get childSetupScreenErrorChildNotAllowed =>
      'Only a grown-up account can add a child.';

  @override
  String get childSetupScreenErrorGeneric =>
      'Couldn’t create the account — try again.';

  @override
  String get childSetupScreenTitle => 'ADD A CHILD';

  @override
  String get childSetupScreenHeading => 'who\nare they?';

  @override
  String get childSetupScreenNameLabel => 'NAME';

  @override
  String get childSetupScreenNameHint => 'what you call them';

  @override
  String get childSetupScreenUsernameLabel => 'USERNAME';

  @override
  String get childSetupScreenUsernameHint => 'how friends find them';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'WHAT THEY GET';

  @override
  String get childSetupScreenBulletTalkImmediately =>
      'They can talk to you and their brothers and sisters right away.';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      'Everyone else needs your OK first — both people they ask for, and people who ask for them.';

  @override
  String get childSetupScreenBulletPublicRoomsOff =>
      'Public rooms are switched off until you turn them on.';

  @override
  String get childSetupScreenBulletCantSignOut =>
      'They can’t sign out, and you can always see how they’re doing.';

  @override
  String get childSetupScreenCreateButton => 'CREATE + PAIR';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return 'Message $name';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => 'asked';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'IN';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'see all $count';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return 'See all $count';
  }

  @override
  String get bubbleStyleScreenTitle => 'bubble style.';

  @override
  String get bubbleStyleScreenSubtitle => 'the shape your words arrive in';

  @override
  String get bubbleStyleScreenTailedLabel => 'TAILED';

  @override
  String get bubbleStyleScreenTailedDescription =>
      'a tail closes each run of messages; the rows above it tighten into one block.';

  @override
  String get bubbleStyleScreenSoftLabel => 'SOFT';

  @override
  String get bubbleStyleScreenSoftDescription =>
      'no tail — a run holds together through its tightened inner corners alone.';

  @override
  String get bubbleStyleScreenPillLabel => 'PILL';

  @override
  String get bubbleStyleScreenPillDescription =>
      'fully rounded capsules, identical on every row.';

  @override
  String get bubbleStyleScreenSlabLabel => 'SLAB';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'square shoulders — sharp, printed, deliberate.';

  @override
  String get bubbleStyleScreenActiveBadge => 'ACTIVE';

  @override
  String get bubbleStyleScreenPreviewQuestion => 'so? how does it look';

  @override
  String get bubbleStyleScreenPreviewReplyOne => 'better';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => 'much better';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => 'Video';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => 'Photo';

  @override
  String get incomingGroupCallScreenCallFullError =>
      'That call is full (max 6 people)';

  @override
  String get incomingGroupCallScreenJoinFailedError =>
      'Could not join the call';

  @override
  String get incomingGroupCallScreenDefaultRoomName => 'Group call';

  @override
  String get incomingGroupCallScreenDefaultStarterName => 'Someone';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starter started a video call';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starter started a voice call';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '$count already in';
  }

  @override
  String get incomingGroupCallScreenDismissButton => 'Dismiss';

  @override
  String get incomingGroupCallScreenJoinButton => 'Join';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '$count chat',
    );
    return '$_temp0';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '$count message',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      'last message just now';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'last message ${hours}h ago';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'last message yesterday';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'last message $days days ago';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'last message a while ago';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'TAKE BACK';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return 'take $contactName away from $childName?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'they won’t be able to reach each other, and their conversation goes with it.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'they won’t be able to reach each other. $contactName won’t be told.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats · $messages will be deleted';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      'gone for both of them, including photos and voice notes. this can’t be undone.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'they also share $count rooms',
      one: 'they also share $count room',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'these stay. take the room back from the ROOMS list below if you want them out of it.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'TAKE BACK & DELETE';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'removes $contactName and wipes $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'removes $contactName from the allowed list.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Cancel';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => 'CANCEL';

  @override
  String get groupCallBannerCallFullError => 'That call is full (max 6 people)';

  @override
  String get groupCallBannerJoinFailedError => 'Could not join the call';

  @override
  String get groupCallBannerUnknownParticipant => 'Someone';

  @override
  String get groupCallBannerOngoingVideoCall => 'Ongoing video call';

  @override
  String get groupCallBannerOngoingVoiceCall => 'Ongoing voice call';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra in the call';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => 'Join call';

  @override
  String get groupCallBannerJoinButtonLabel => 'JOIN';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'JOIN ROOM';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => 'PASSWORD';

  @override
  String get groupCallBannerPasswordHint => 'passphrase…';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Join';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'JOIN';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Cancel';

  @override
  String get groupCallBannerCancelButtonLabel => 'cancel';

  @override
  String get viewOnceViewerBadgeLabel => 'VIEW ONCE';

  @override
  String get viewOnceViewerSocialDividerOr => 'or';

  @override
  String get viewOnceViewerAppleContinueButton => 'Continue with Apple';

  @override
  String get viewOnceViewerGoogleContinueButton => 'Continue with Google';

  @override
  String get discoverListsPeopleTitle => 'your people.';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '$count person',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => 'filter your people…';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Clear filter';

  @override
  String get discoverListsNoOneYet => 'no one yet';

  @override
  String discoverListsNoMatches(Object query) {
    return 'no one matches \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'VOICE CALL';

  @override
  String get discoverListsVideoCallLabel => 'VIDEO CALL';

  @override
  String get approvalGateAlreadyAskedLabel => 'ALREADY ASKED';

  @override
  String get approvalGateAskGrownUpLabel => 'ASK A GROWN-UP';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return 'You already asked about $what.';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return 'You need a grown-up to say yes before you can $what.';
  }

  @override
  String get approvalGateDisabledBody =>
      'A grown-up has switched this off for now.';

  @override
  String get approvalGateAlreadyAskedFooter =>
      'They’ll get a message about it. Check back soon.';

  @override
  String get approvalGateWillNotifyFooter =>
      'We’ll let them know. You’ll see it here when they answer.';

  @override
  String get approvalGateTalkToThemFooter =>
      'You can talk to them about it if you think it should change.';

  @override
  String get approvalGateAskButton => 'ASK';

  @override
  String get approvalGateNotNowButton => 'NOT NOW';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => 'waiting for a grown-up';

  @override
  String get reportSheetTitle => 'REPORT';

  @override
  String get reportSheetSubtitle => 'tell us what’s wrong.';

  @override
  String get reportSheetPrivacyNote =>
      'reports are private — the other person isn’t notified.';

  @override
  String get reportSheetReasonSpamLabel => 'SPAM';

  @override
  String get reportSheetReasonSpamDescription =>
      'unwanted ads or repeated messages';

  @override
  String get reportSheetReasonHarassmentLabel => 'HARASSMENT';

  @override
  String get reportSheetReasonHarassmentDescription => 'targeting or bullying';

  @override
  String get reportSheetReasonImpersonationLabel => 'IMPERSONATION';

  @override
  String get reportSheetReasonImpersonationDescription =>
      'pretending to be someone';

  @override
  String get reportSheetReasonInappropriateLabel => 'INAPPROPRIATE';

  @override
  String get reportSheetReasonInappropriateDescription =>
      'sexual, violent, or illegal content';

  @override
  String get reportSheetReasonOtherLabel => 'OTHER';

  @override
  String get reportSheetReasonOtherDescription => 'something else';

  @override
  String get reportSheetOtherNoteHint => 'what happened?';

  @override
  String get reportSheetSubmitSemanticLabel => 'Submit report';

  @override
  String get reportSheetSubmitButton => 'SUBMIT';

  @override
  String get reportSheetUpdateRequiredTitle => 'UPDATE REQUIRED';

  @override
  String get reportSheetUpdateAvailableTitle => 'UPDATE AVAILABLE';

  @override
  String get reportSheetUpdateMandatoryBody =>
      'This version is too old to keep working properly. Update to carry on.';

  @override
  String get reportSheetUpdateAvailableBody =>
      'A newer version of MonkeyHub is available.';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => 'UPDATE';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'opens TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'opens the App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'opens Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'opens the download page';

  @override
  String get reportSheetUpdateActionReloads => 'reloads with the new version';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Later';

  @override
  String get reportSheetUpdateLaterButton => 'LATER';

  @override
  String get roomFilterBarAllChipLabel => 'all';

  @override
  String roomFilterBarChipCountSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '$count chat',
    );
    return '$label, $_temp0';
  }

  @override
  String composerReplyCardReplyingToLabel(Object name) {
    return 'REPLYING TO $name';
  }

  @override
  String get roomCardLockedBadge => 'LOCKED';

  @override
  String get roomCardTimeAgoJustNow => 'just now';

  @override
  String roomCardTimeAgoSeconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String roomCardTimeAgoMinutes(Object minutes) {
    return '${minutes}m';
  }

  @override
  String roomCardTimeAgoHours(Object hours) {
    return '${hours}h';
  }

  @override
  String roomCardTimeAgoDays(Object days) {
    return '${days}d';
  }

  @override
  String roomCardTimeAgoWeeks(Object weeks) {
    return '${weeks}w';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count inside';
  }

  @override
  String get roomCardMessagesFadeLabel => 'messages fade';

  @override
  String get roomCardEnterLabel => '↗ enter';

  @override
  String get roomCardBlockedScreenTitle => 'BLOCKED';

  @override
  String get roomCardBlockedEmptyState => 'you haven’t blocked anyone.';

  @override
  String get roomCardUnblockButton => 'UNBLOCK';

  @override
  String get attachmentMenuPhotoLabel => 'photo';

  @override
  String get attachmentMenuVideoLabel => 'video';

  @override
  String get attachmentMenuCameraLabel => 'camera';

  @override
  String get attachmentMenuVoiceLabel => 'voice';

  @override
  String get attachmentMenuFileLabel => 'file';

  @override
  String get attachmentMenuConnectionRetrying => 'retrying…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'can’t reach server · tap to retry';

  @override
  String get attachmentMenuConnectionReconnecting => 'reconnecting…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel => 'Retry connection';

  @override
  String get roomGridTileLockedBadge => 'LOCKED';

  @override
  String get roomGridTileEmptyLastMessage => 'quiet so far';

  @override
  String get roomGridTileMemberCountLabel => 'IN';

  @override
  String get roomGridTileThemeChipLabel => 'THEME';

  @override
  String get bulkActionBarCancelLabel => 'CANCEL';

  @override
  String get bulkActionBarSelectMessagesLabel => 'SELECT MESSAGES';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count SELECTED';
  }

  @override
  String get bulkActionBarForwardLabel => 'FORWARD';

  @override
  String get bulkActionBarDeleteLabel => 'DELETE';

  @override
  String get bulkActionBarJumpBackLabel => 'BACK';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return 'BACK · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel =>
      'Back to where you jumped from';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return 'Back to where you jumped from, $depth to go';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote =>
      'they won’t be notified.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'you’re currently friends — blocking removes the friendship, so to reconnect later you’d have to send a new friend request.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'they’ll disappear from your search and can’t message you.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'BLOCK';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return 'block $name?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'you share $count rooms with them',
      one: 'you share $count room with them',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'these rooms stay untouched. you can leave any of them yourself from each room’s settings.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'BLOCK';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'remove friendship and block. existing chat history stays in your archive.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'they’re hidden from search and can’t reach you.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'BLOCK & DELETE DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'also wipes your DM with them — every message, reaction, and media file is gone.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Cancel';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'CANCEL';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle =>
      'Show calls on the lock screen';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      'To ring like a real phone call when your screen is off, MonkeyHub needs \"full-screen notifications\" turned on. The next screen takes you straight to the switch.';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle => 'Never miss a call';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      'Some phones pause apps in the background to save battery, which can silence incoming calls. Allow MonkeyHub to run unrestricted so calls always come through.';

  @override
  String get bulkActionBarDialogNotNowButton => 'Not now';

  @override
  String get bulkActionBarDialogContinueButton => 'Continue';

  @override
  String get reactionBubbleJumpToLatestLabel => 'JUMP TO LATEST';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel => 'Jump to latest';

  @override
  String get reactionBubblePickerTitle => 'REACT';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'no recents yet';

  @override
  String get reactionBubblePasswordHint => 'password';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return 'join $roomName';
  }

  @override
  String get enterPublicRoomAskFailedMessage =>
      'couldn\'t ask right now — try again';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'wrong password';

  @override
  String get enterPublicRoomJoinFailedMessage => 'couldn\'t join — try again';

  @override
  String get enterPublicRoomFeedTabLabel => 'FEED';

  @override
  String get enterPublicRoomFeedHeadlineSoon => 'soon.\n';

  @override
  String get enterPublicRoomFeedHeadlineDetail =>
      'daily moments,\nshared with rooms.';

  @override
  String get enterPublicRoomFeedPipelineLabel => 'IN THE PIPE';

  @override
  String get enterPublicRoomFeedBulletPrompt =>
      'a daily prompt the room responds to';

  @override
  String get enterPublicRoomFeedBulletVoiceNotes =>
      'voice notes that auto-fade with the day';

  @override
  String get enterPublicRoomFeedBulletWallUpdates =>
      'a wall of small, slow updates from friends';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'PUBLIC';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'PRIVATE';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'JOINED';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'EPHEMERAL · $duration';
  }

  @override
  String enterPublicRoomEphemeralSecondsShort(Object seconds) {
    return '${seconds}s';
  }

  @override
  String enterPublicRoomEphemeralMinutesShort(Object minutes) {
    return '${minutes}m';
  }

  @override
  String enterPublicRoomEphemeralHoursShort(Object hours) {
    return '${hours}h';
  }

  @override
  String get countBadgeCaptureProtectionLabel => 'SCREEN CAPTURE PROTECTION';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      'screenshots + screen recording show as black to the system.';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      'screen recording + mirroring drops a privacy shield over the app.';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      'screenshots and recordings work normally outside ephemeral rooms.';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      'ephemeral (chamber of secrets) rooms always force this on regardless.';

  @override
  String get countBadgeShowPasswordTooltip => 'show password';

  @override
  String get countBadgeHidePasswordTooltip => 'hide password';

  @override
  String get countBadgeProtectedLabel => 'PROTECTED';

  @override
  String get countBadgeCaptureShieldActiveBody =>
      'screen recording or mirroring is active.';

  @override
  String get countBadgeCaptureShieldReassurance =>
      'the recording can\'t see your conversations.';

  @override
  String get linkOpenerCouldNotOpenLink => 'Could not open link';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel =>
      'Set up a recovery phrase';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'no recovery phrase — you could not get back in.';

  @override
  String get destinationsChatLabel => 'Chat';

  @override
  String get destinationsChatShort => 'CHAT';

  @override
  String get destinationsDiscoverLabel => 'Discover';

  @override
  String get destinationsDiscoverShort => 'FIND';

  @override
  String get destinationsFeedLabel => 'Feed';

  @override
  String get destinationsFeedShort => 'FEED';

  @override
  String get destinationsSettingsLabel => 'Settings';

  @override
  String get destinationsSettingsShort => 'SET';

  @override
  String get familyRequestStageSenderGuardianLabel => 'waiting for a grown-up';

  @override
  String get familyRequestStageRecipientLabel => 'waiting for them';

  @override
  String get roomContentTabLabelMedia => 'MEDIA';

  @override
  String get roomContentTabLabelFiles => 'FILES';

  @override
  String get roomContentTabLabelVoice => 'VOICE';

  @override
  String get roomContentTabLabelLinks => 'LINKS';

  @override
  String get roomContentTabHeaderMedia => 'media';

  @override
  String get roomContentTabHeaderFiles => 'files';

  @override
  String get roomContentTabHeaderVoice => 'voice';

  @override
  String get roomContentTabHeaderLinks => 'links';

  @override
  String get roomFacetLabelDms => 'dms';

  @override
  String get roomFacetLabelGroups => 'groups';

  @override
  String get roomFacetLabelPublic => 'public';

  @override
  String get roomFacetLabelPrivate => 'private';

  @override
  String get roomFacetLabelSecret => 'secret';

  @override
  String get roomFacetLabelLocked => 'locked';

  @override
  String get roomFacetLabelUnread => 'unread';

  @override
  String get roomFacetLabelMentions => 'mentions';

  @override
  String get settingsScreenTitle => 'SETTINGS';

  @override
  String get settingsScreenTagline => 'look. feel. you.';

  @override
  String get settingsScreenAccountHintChild =>
      'profile · privacy · my grown-ups';

  @override
  String get settingsScreenAccountHintAdult =>
      'profile · family · linked accounts · privacy';

  @override
  String get settingsScreenSectionAppearance => 'APPEARANCE';

  @override
  String get settingsScreenSectionLayout => 'LAYOUT';

  @override
  String get settingsScreenSectionGeneral => 'GENERAL';

  @override
  String get settingsScreenSectionLinks => 'LINKS';

  @override
  String get settingsScreenSectionNotifications => 'NOTIFICATIONS';

  @override
  String get reportProblemRowLabel => 'Report a problem';

  @override
  String get reportProblemRowValue => 'Send us the details';

  @override
  String get reportProblemIntro =>
      'Tell us what went wrong. Your app and device details are included automatically — they help us find the cause.';

  @override
  String get reportProblemDescribeLabel => 'WHAT HAPPENED';

  @override
  String get reportProblemDescribeHint =>
      'The screen flickers, buttons don\'t respond…';

  @override
  String get reportProblemScreenshotsLabel => 'SCREENSHOTS';

  @override
  String get reportProblemAddScreenshot => 'Add screenshot';

  @override
  String get reportProblemDetailsLabel => 'YOUR DETAILS';

  @override
  String get reportProblemCopyDetails => 'Copy details';

  @override
  String get reportProblemCopied => 'Copied';

  @override
  String get reportProblemSend => 'Send report';

  @override
  String reportProblemEmailInstead(String email) {
    return 'Or email $email';
  }

  @override
  String get reportProblemShakeTitle => 'Report a problem?';

  @override
  String get reportProblemShakeBody =>
      'You shook your phone. Open the report screen?';

  @override
  String get reportProblemShakeOpen => 'Report';

  @override
  String get reportProblemShakeDismiss => 'Not now';

  @override
  String get settingsCallDeliveryLockScreenLabel => 'Lock screen calls';

  @override
  String get settingsCallDeliveryBackgroundLabel => 'Background activity';

  @override
  String get settingsCallDeliveryStatusOff => 'Tap to allow';

  @override
  String get settingsScreenRowTheme => 'THEME';

  @override
  String get settingsScreenRowAppLogo => 'APP LOGO';

  @override
  String get settingsScreenRowGlass => 'GLASS';

  @override
  String get settingsScreenRowChatList => 'CHAT LIST';

  @override
  String get settingsScreenRowNavigation => 'NAVIGATION';

  @override
  String get settingsScreenRowChatStyle => 'CHAT STYLE';

  @override
  String get settingsScreenRowBubbleStyle => 'BUBBLE STYLE';

  @override
  String get settingsScreenRowReplyStyle => 'REPLY STYLE';

  @override
  String get settingsScreenValueScrollList => 'Scroll list';

  @override
  String get settingsScreenValueGridSheet => 'Grid sheet';

  @override
  String get settingsScreenValueRadialOrb => 'Radial orb';

  @override
  String get settingsScreenValueBottomPill => 'Bottom pill';

  @override
  String get settingsScreenValueCustom => 'Custom';

  @override
  String settingsScreenValueEdited(Object name) {
    return '$name · edited';
  }

  @override
  String get settingsScreenValueClassic => 'Classic';

  @override
  String get settingsScreenValueCompact => 'Compact';

  @override
  String get settingsScreenValueBubbleTailed => 'Tailed';

  @override
  String get settingsScreenValueBubbleSoft => 'Soft';

  @override
  String get settingsScreenValueBubblePill => 'Pill';

  @override
  String get settingsScreenValueBubbleSlab => 'Slab';

  @override
  String get settingsScreenValueReplyPhantomEcho => 'Phantom Echo';

  @override
  String get settingsScreenValueReplyStickyNote => 'Sticky Note';

  @override
  String get settingsScreenValueReplyComicTail => 'Comic Tail';

  @override
  String get settingsScreenValueLogoAuto => 'Auto';

  @override
  String get settingsScreenValueLogoManual => 'Manual';

  @override
  String get settingsScreenShowLinkUrlsLabel => 'SHOW LINK URLS';

  @override
  String get settingsScreenLinksUrlsOnBody =>
      'raw URLs appear alongside the preview card';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      'currently preview only — cleaner bubbles, tap to open';

  @override
  String get settingsScreenPushNotificationsLabel => 'PUSH NOTIFICATIONS';

  @override
  String get settingsScreenPushOnBody => 'pings for new messages + requests';

  @override
  String get settingsScreenPushOffBody =>
      'silent — you’ll only see things when you open the app';

  @override
  String get authErrorUsernameTaken => 'That username is already taken.';

  @override
  String get authErrorUserNotFound => 'No account with that username.';

  @override
  String get authErrorWrongPassword => 'Wrong password.';

  @override
  String get authErrorInvalidRecoveryKey =>
      'That username and recovery phrase don’t match.';

  @override
  String get authErrorTooManyAttempts =>
      'Too many tries. Wait 15 minutes and try again.';

  @override
  String get authErrorChildMustPair =>
      'That’s a kid’s account — ask a grown-up for a pairing code.';

  @override
  String get authErrorPairingCodeExpired =>
      'That code has run out. Ask for a new one.';

  @override
  String get authErrorPairingCodeInvalid =>
      'That code didn’t work. It may have been used already.';

  @override
  String get authErrorUseSocialSignIn =>
      'That account signs in with Apple or Google — use the buttons below.';

  @override
  String get authErrorSocialTokenInvalid =>
      'That sign-in didn’t go through. Please try again.';

  @override
  String get authErrorSocialNonceMismatch =>
      'That sign-in didn’t go through. Please try again.';

  @override
  String get authErrorSocialMisconfig =>
      'Sign-in isn’t set up yet on our side. Try again later.';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      'That Apple or Google account is already linked to a different MonkeyHub account.';

  @override
  String get authErrorSocialAlreadyLinked =>
      'That’s already linked to this account.';

  @override
  String get authErrorSocialNotLinked => 'That isn’t linked to this account.';

  @override
  String get authErrorSocialLastCredential =>
      'That’s the only way into this account. Set a password first.';

  @override
  String get authErrorUsernameInvalid =>
      'Pick a username between 1 and 32 characters.';

  @override
  String get glassKnobLabelFrost => 'FROST';

  @override
  String get glassKnobHintFrost =>
      'how much white sits on the glass. down for see-through';

  @override
  String get glassKnobLabelBlur => 'BLUR';

  @override
  String get glassKnobHintBlur =>
      'frosted at the top of the range, clear glass at the bottom';

  @override
  String get glassKnobLabelSaturation => 'COLOUR BLEED';

  @override
  String get glassKnobHintSaturation =>
      'how much colour survives the blur. past 2 it posterizes';

  @override
  String get glassKnobLabelRimOpacity => 'RIM';

  @override
  String get glassKnobHintRimOpacity =>
      'the accent outline. zero for a borderless surface';

  @override
  String get glassKnobLabelRimWidth => 'RIM WIDTH';

  @override
  String get glassKnobHintRimWidth => 'thickness of that outline';

  @override
  String get glassKnobLabelShadowOpacity => 'SHADOW';

  @override
  String get glassKnobHintShadowOpacity =>
      'how far the surface floats above what is behind it';

  @override
  String get glassKnobLabelShadowBlur => 'SHADOW SPREAD';

  @override
  String get glassKnobHintShadowBlur => 'soft and wide, or tight and hard';

  @override
  String get glassKnobLabelShadowY => 'SHADOW DROP';

  @override
  String get glassKnobHintShadowY => 'how far below the surface it falls';

  @override
  String get glassKnobLabelBarMargin => 'SIDE MARGIN';

  @override
  String get glassKnobHintBarMargin =>
      'gap between the bar and the edge of the screen';

  @override
  String get glassKnobLabelBarBottom => 'BOTTOM GAP';

  @override
  String get glassKnobHintBarBottom => 'how high the bar floats off the bottom';

  @override
  String get glassKnobLabelShellPadH => 'END PADDING';

  @override
  String get glassKnobHintShellPadH =>
      'bar edge to the first pill. small, or the ends look marooned';

  @override
  String get glassKnobLabelShellPadV => 'TOP PADDING';

  @override
  String get glassKnobHintShellPadV => 'bar edge to the top of the pill';

  @override
  String get glassKnobLabelIndicatorInset => 'PILL INSET';

  @override
  String get glassKnobHintIndicatorInset =>
      'how far the selection pill sits inside its slot';

  @override
  String get glassKnobLabelSegmentPadV => 'ROW PADDING';

  @override
  String get glassKnobHintSegmentPadV =>
      'air above and below the icon and its label';

  @override
  String get glassKnobLabelIconLabelGap => 'ICON GAP';

  @override
  String get glassKnobHintIconLabelGap =>
      'space between an icon and the word under it';

  @override
  String get glassKnobLabelIconSize => 'ICON SIZE';

  @override
  String get glassKnobLabelLabelSize => 'LABEL SIZE';

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
}
