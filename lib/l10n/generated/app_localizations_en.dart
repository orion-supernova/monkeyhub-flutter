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
  String get bootErrorTitle => 'Can’t reach server';

  @override
  String get bootErrorBody => 'Convex didn’t initialize.';

  @override
  String get bootErrorRetry => 'Retry';

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
      'Couldn’t ask right now. Try again';

  @override
  String get roomScreenGateSendMessages => 'send messages here';

  @override
  String get roomScreenGateSendMedia => 'send pictures or voice notes';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'Up to $max at a time';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count messages',
      one: 'Delete message',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'This removes them for everyone in this chat. It cannot be undone.';

  @override
  String get roomScreenDeleteConfirmButton => 'Delete for everyone';

  @override
  String get roomScreenJumpFailedSnack => 'Couldn’t jump to that message';

  @override
  String get roomScreenUnreadDivider => 'Unread messages';

  @override
  String get roomScreenViewOnceAlreadyViewed =>
      'You’ve already opened this photo.';

  @override
  String get roomScreenViewOnceGone => 'This photo is no longer available.';

  @override
  String get roomScreenViewOnceNetworkError => 'Couldn’t load that photo.';

  @override
  String get roomScreenFileReadFailedSnack => 'Couldn’t read that file';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'Files are capped at $size';
  }

  @override
  String get roomScreenRoomGone => 'Room gone';

  @override
  String get roomScreenCopiedSnack => 'Copied';

  @override
  String get roomScreenNameCopiedSnack => 'Name copied';

  @override
  String get roomScreenPinLimitSnack => 'Too many pins. Unpin one first';

  @override
  String get roomScreenPinFailedSnack => 'Couldn’t pin that';

  @override
  String get roomScreenReportSentSnack =>
      'Report sent privately. They won’t be notified.';

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
    return 'This room is ephemeral. Messages dissolve after $ttl, read or unread.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count messages';
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
  String get roomScreenViewProfilePictureSemantic => 'View profile picture';

  @override
  String get roomScreenViewRoomPictureSemantic => 'View room picture';

  @override
  String get messageBubbleFileFallbackName => 'Document';

  @override
  String get messageBubbleAttachmentStatusFailed => 'Failed';

  @override
  String get messageBubbleAttachmentStatusSending => 'Sending…';

  @override
  String get messageBubbleViewOnceOpened => 'Opened';

  @override
  String get messageBubbleViewOnceExpired => 'Expired';

  @override
  String get messageBubbleViewOnceLabel => 'View once';

  @override
  String get messageBubbleViewOnceTapToView => 'Tap to view';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Photo';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'View once photo, tap to view';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'Retry sending';

  @override
  String get messageBubbleDiscardSemanticLabel => 'Discard';

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
  String get profileScreenEmailHint => 'optional, never shown to anyone';

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
      'they already sent you a request. Check requests.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'request already sent.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'you blocked this user. Unblock them first.';

  @override
  String get profileScreenErrorUserNotFound => 'this isn’t possible right now.';

  @override
  String get profileScreenNameNotSaved =>
      'Couldn\'t save your name. Please try again.';

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
      'Only a grown-up can do this. It needs their code or password.';

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
  String get settingsScreenSectionHelpAndLegal => 'HELP & LEGAL';

  @override
  String get settingsScreenLicence => 'LICENCE';

  @override
  String get profileScreenLinkedAccountsLabel => 'LINKED ACCOUNTS';

  @override
  String get profileScreenLinkedAccountsNone => 'Nothing linked';

  @override
  String get profileScreenMyGrownUps => 'MY GROWN-UPS';

  @override
  String get profileScreenNameHint => 'how the room will read you';

  @override
  String get profileScreenChangeUsernameTitle => 'change username?';

  @override
  String get profileScreenChangeUsernameWarning =>
      'You sign in with this, so the new one is what you\'ll type from now on. Your old username is freed for anyone else to take, and you can\'t change it again for 30 days. Older messages that tagged you keep the old name.';

  @override
  String get profileScreenUsernameHint => 'how friends find you';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return 'Changeable again on $date';
  }

  @override
  String get profileScreenUsernamePasswordTitle => 'confirm it\'s you';

  @override
  String get profileScreenUsernamePasswordAction => 'CHANGE USERNAME';

  @override
  String get profileScreenUsernameProviderTitle => 'confirm with your sign-in';

  @override
  String profileScreenUsernameChanged(String username) {
    return 'You\'re now @$username.';
  }

  @override
  String get profileScreenUsernameNotSaved =>
      'Couldn\'t change your username. Please try again.';

  @override
  String get usernameStatusChecking => 'checking…';

  @override
  String get usernameStatusAvailable => 'available';

  @override
  String get usernameStatusTaken => 'already taken';

  @override
  String get usernameStatusReserved => 'not available';

  @override
  String get usernameStatusInvalid => '1–32 characters';

  @override
  String get usernameStatusUnknown => 'couldn\'t check';

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
  String get settingsScreenPrivacyPolicy => 'PRIVACY POLICY';

  @override
  String get profileScreenPrivacySection => 'PRIVACY';

  @override
  String get profileScreenProfilePictureTitle => 'PROFILE PICTURE';

  @override
  String get profileScreenRedactedFriend =>
      'some fields are hidden by their settings.';

  @override
  String get profileScreenRedactedStranger =>
      'limited view. They share more with friends.';

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
  String get settingsScreenTermsOfService => 'TERMS OF SERVICE';

  @override
  String get profileScreenThisPhoneSection => 'THIS PHONE';

  @override
  String get profileScreenUnfriendAction => 'UNFRIEND';

  @override
  String get profileScreenViewProfilePictureSemantic => 'view profile picture';

  @override
  String get profileScreenVisibilityPreferences => 'VISIBILITY PREFERENCES';

  @override
  String get cameraEditorScreenCropPresetFree => 'Free';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'Original';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'Cancel crop';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'Discard photo';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'Undo';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'Redo';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'Reset crop';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'Rotate';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'Crop';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'This browser can’t open HEIC photos';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'Couldn’t open that image';

  @override
  String get cameraEditorScreenCropDoneButton => 'Done';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'Retake';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'Put the pen away';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'Draw on the photo';

  @override
  String get cameraEditorScreenSendingButton => 'Sending…';

  @override
  String get cameraEditorScreenSendButton => 'Send';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'Disappears after it’s opened once';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'Clear drawing';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel => 'View once: on';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel => 'View once: off';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: on';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: off';

  @override
  String get cameraEditorScreenHdNote => 'Sending at full resolution';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'Ink colour';

  @override
  String get glassScreenPanelLooks => 'Looks';

  @override
  String get glassScreenPanelBottomBar => 'Bottom bar';

  @override
  String get glassScreenPanelOtherSurfaces => 'Other surfaces';

  @override
  String get glassScreenPanelBarLayout => 'Bar layout';

  @override
  String get glassScreenTitle => 'glass.';

  @override
  String get glassScreenSubtitle => 'how much of what is behind comes through';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'All $max slots full';
  }

  @override
  String get glassScreenSaveCurrentAs => 'Save current as…';

  @override
  String get glassScreenResetEveryDial => 'Reset every dial';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'Reset to $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'The composer, headers, call buttons: anything that sits over text rather than over scrolling content';

  @override
  String get glassScreenMatchBottomBar => 'Match the bottom bar';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'Edited. Save it as a new look, or reset it';

  @override
  String get glassScreenCustomPresetName => 'Custom';

  @override
  String get glassScreenUnsavedSubtitle => 'Unsaved. Give it a name to keep it';

  @override
  String get glassScreenSaveDialogTitle => 'Save this look as';

  @override
  String get glassScreenNoRoomToast => 'No room. Delete a look first';

  @override
  String get glassScreenRenameDialogTitle => 'Rename';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'Delete $name?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'The look stays on screen. It just stops having a name.';

  @override
  String get glassScreenKeepButton => 'Keep';

  @override
  String get glassScreenDeleteButton => 'Delete';

  @override
  String get glassScreenNameHint => 'Late night';

  @override
  String get glassScreenCancelButton => 'Cancel';

  @override
  String get glassScreenSaveButton => 'Save';

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
  String get glassScreenPreviewBadge => 'Preview';

  @override
  String get glassScreenBuiltInLabel => 'Built in';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'Overwrite $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'Rename $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'Delete $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'Reset $label';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'sent the roof photos, the tiles are all cracked';

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
  String get replyIndicatorViewOnceLabel => 'Photo · view once';

  @override
  String get replyIndicatorVoiceMessageLabel => 'Voice message';

  @override
  String get replyIndicatorDocumentLabel => 'Document';

  @override
  String get replyIndicatorMessageRemoved => 'Message removed';

  @override
  String get threadOverlayMessageNotFound =>
      'Couldn’t find that message in this thread';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'Couldn’t find the thread to reply to';

  @override
  String get threadOverlayStillSending =>
      'Still sending. Try again in a second';

  @override
  String get threadOverlayCopiedToast => 'Copied';

  @override
  String get threadOverlayNameCopiedToast => 'Name copied';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'Coordinates copied';

  @override
  String get threadOverlayPinLimitToast => 'Too many pins. Unpin one first';

  @override
  String get threadOverlayPinFailedToast => 'Couldn’t pin that';

  @override
  String get threadOverlayReportedToast => 'Reported';

  @override
  String get threadOverlayUnavailable => 'thread unavailable';

  @override
  String get roomInfoScreenNameRequiredError => 'Name is required';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'Password cleared';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'Leave room?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'You can rejoin if it stays open.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'Leave';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'Delete room?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'Every message in here goes with it. This is permanent.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'Delete';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      'End this conversation?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName loses this conversation too: every message disappears for both of you. This is permanent.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'End';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'The other person';

  @override
  String get roomInfoScreenConfirmCancelButton => 'CANCEL';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'A room with that name already exists';

  @override
  String get roomInfoScreenErrorNotOwner => 'Only the owner can do that';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'You don’t have permission';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'This room is gone';

  @override
  String get roomInfoScreenRoomGone => 'Room gone';

  @override
  String get roomInfoScreenNameLabel => 'NAME';

  @override
  String get roomInfoScreenNameHint => 'Room name';

  @override
  String get roomInfoScreenDescriptionLabel => 'DESCRIPTION';

  @override
  String get roomInfoScreenDescriptionHint => 'One line about the room';

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
      'this room is protected. the existing passphrase isn’t shown for security, so enter a new one to replace it.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'Replace passphrase';

  @override
  String get roomInfoScreenSetPasswordHint => 'Lock with a passphrase';

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
  String get roomInfoScreenEndingConversationButton => 'ENDING…';

  @override
  String get roomInfoScreenEndConversationButton => 'END CONVERSATION';

  @override
  String get roomInfoScreenHeaderConversation => 'CONVERSATION';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'ROOM SETTINGS';

  @override
  String get roomInfoScreenViewProfilePictureSemantic => 'View profile picture';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'View room picture';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'Change room picture';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'Add room picture';

  @override
  String get roomInfoScreenOwnerBadge => 'OWNER';

  @override
  String get roomInfoScreenNoneCount => 'none';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'Camera access is off.\nTurn it on in Settings to take a photo.';

  @override
  String get cameraScreenOpeningSystemCamera => 'Opening the system camera…';

  @override
  String get cameraScreenCloseButtonLabel => 'Close camera';

  @override
  String get cameraScreenLowLightBoostOnLabel => 'Low-light boost: on';

  @override
  String get cameraScreenLowLightBoostOffLabel => 'Low-light boost: off';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'Flash: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'Choose from library';

  @override
  String get cameraScreenSwitchCameraLabel => 'Switch camera';

  @override
  String get cameraScreenTakePhotoLabel => 'Take photo';

  @override
  String get childPolicyScreenAddByUsernameLabel => 'Add by username';

  @override
  String get childPolicyScreenAddCta => 'Add';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'They get exactly what you have: every request to approve, every setting to change, and the power to remove you. $name sees them as family straight away.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'Add a grown-up';

  @override
  String get childPolicyScreenAddGuardianHint => 'Their username';

  @override
  String get childPolicyScreenAllowCta => 'Allow';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'You won’t be asked about them again, whether $childName adds them or they add $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'Allow someone';

  @override
  String get childPolicyScreenAskToAddLabel => 'Ask to add';

  @override
  String get childPolicyScreenAskToAddOffDesc => 'Family only, no new requests';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'They can ask you about new people';

  @override
  String get childPolicyScreenBothFinalNote =>
      'Both of these are final. To step away instead, use Grown-ups above.';

  @override
  String get childPolicyScreenCallsLabel => 'Calls';

  @override
  String get childPolicyScreenCallsOffDesc => 'Messages only';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'Voice + video with people they’re allowed';

  @override
  String get childPolicyScreenCancelLabel => 'Cancel';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Cancel';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'Added. The request is on its way';

  @override
  String get childPolicyScreenContactAddedToList => 'Added to the allowed list';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'Make rooms';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'They can’t start rooms';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'They can start their own private rooms';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Everything goes: their messages, photos, rooms, and friends. This cannot be undone, and the username is freed for anyone else.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'Couldn’t delete the account. Try again';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return 'Delete $name’s account?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Messages, photos, rooms and friends all go. Cannot be undone.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'Delete $name’s account';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'Delete forever';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'Couldn’t add them. Try again';

  @override
  String get childPolicyScreenErrorCannotAddSelf => 'That’s their own username';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'A child can’t be a grown-up';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'Couldn’t do that. Try again';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'Someone has to look after them. Add another grown-up first';

  @override
  String get childPolicyScreenErrorNotYours => 'That’s not yours to change';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'No account with that username';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'They become a normal account with this password, and every grown-up loses all visibility. There is no way back: you would have to be invited like anyone else.';

  @override
  String get childPolicyScreenGraduateCta => 'Graduate';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'They keep everything and get a password. You lose all visibility. Irreversible.';

  @override
  String get childPolicyScreenGraduateDangerLabel =>
      'Graduate to a full account';

  @override
  String get childPolicyScreenGraduateFailed =>
      'Couldn’t graduate them. Try again';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'Graduate $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'A password for them';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Taking a room back also removes them from it. Taking a person back deletes their chat as well, for both of them.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Everyone here can approve, change settings, and see everything. Any of them can act alone; nothing waits on the others.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'Added. They can look after them now';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name removed';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (you)';
  }

  @override
  String get childPolicyScreenLoading => 'Loading…';

  @override
  String get childPolicyScreenLockedLabel => 'Locked';

  @override
  String get childPolicyScreenMediaLabel => 'Photos + voice';

  @override
  String get childPolicyScreenMediaOffDesc => 'Text only';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'They can send pictures, video and voice notes';

  @override
  String get childPolicyScreenNoRoomsYet => 'No rooms yet';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Anyone here can be added without asking you again, whichever of them starts it.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Always off for kids. Discover (the list of rooms belonging to people you don’t know) is hidden completely and can’t be switched on. Rooms someone invites them to still work as normal.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'Public rooms';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian will no longer see or approve anything for $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return 'Remove $name?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'Remove';

  @override
  String childPolicyScreenRoomMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'Grown-ups';

  @override
  String get childPolicyScreenSectionPeopleAllowed => 'People you’ve allowed';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'Rooms you’ve allowed';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'What they can do';

  @override
  String get childPolicyScreenSectionWhenDone => 'When they’re done';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'Nothing happens until someone adds the other';

  @override
  String get childPolicyScreenSendNowOnDesc => 'They get asked straight away';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'Send the request now';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'You’re $name’s only grown-up, so you can’t just step away. Add another first, or use one of these.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'Step away';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'You’ll lose every bit of visibility into $name’s account: their requests, their people, their rooms. The other grown-ups keep looking after them.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'Stop supervising';

  @override
  String get childPolicyScreenStopSupervisingHeadline => 'Stop supervising?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'Couldn’t take them back. Try again';

  @override
  String get childPolicyScreenTakeBackLabel => 'Take back';

  @override
  String get childPolicyScreenUsernameHint => 'Username';

  @override
  String get childPolicyScreenYou => 'You';

  @override
  String get roomContentScreenDefaultDocumentName => 'Document';

  @override
  String get roomContentScreenCouldntOpenFile => 'Couldn’t open that file';

  @override
  String get roomContentScreenCouldntShare => 'Couldn’t share those';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Copied $count links',
      one: 'Copied',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count messages',
      one: 'Delete message',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'This removes them for everyone in this chat. It cannot be undone.';

  @override
  String get roomContentScreenDeleteForEveryone => 'Delete for everyone';

  @override
  String get roomContentScreenCancelTooltip => 'Cancel';

  @override
  String get roomContentScreenBackTooltip => 'Back';

  @override
  String get roomContentScreenSelectingLabel => 'Selecting';

  @override
  String get roomContentScreenSharedContentLabel => 'Shared content';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      zero: 'Nothing picked',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'Select';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'All';

  @override
  String get roomContentScreenEmptyMedia => 'No photos or videos yet';

  @override
  String get roomContentScreenEmptyFiles => 'No files yet';

  @override
  String get roomContentScreenEmptyVoice => 'No voice notes yet';

  @override
  String get roomContentScreenEmptyLinks => 'No links yet';

  @override
  String get roomContentScreenEmptySaved =>
      'Nothing saved yet. Hold a message and choose Save.\n\nWhat you keep here is private to you. A pinned message is what the whole room sees.';

  @override
  String get roomContentScreenLoadFailed => 'Couldn’t load that';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Voice message from $name';
  }

  @override
  String get roomContentScreenForwardAction => 'Forward';

  @override
  String get roomContentScreenCopyAction => 'Copy';

  @override
  String get roomContentScreenSaveAction => 'Save';

  @override
  String get roomContentScreenShareAction => 'Share';

  @override
  String get roomContentScreenInChatAction => 'In chat';

  @override
  String get roomContentScreenDeleteAction => 'Delete';

  @override
  String get messageActionMenuReplyLabel => 'Reply';

  @override
  String get messageActionMenuEditLabel => 'Edit';

  @override
  String get messageStampEditedLabel => 'edited';

  @override
  String get composerEditCardTitle => 'Edit message';

  @override
  String get spoilerRevealHint => 'Spoiler. Activate to reveal the hidden text';

  @override
  String get formatToolbarFormatLabel => 'Format';

  @override
  String get formatToolbarBoldLabel => 'Bold';

  @override
  String get formatToolbarItalicLabel => 'Italic';

  @override
  String get formatToolbarStrikethroughLabel => 'Strikethrough';

  @override
  String get formatToolbarUnderlineLabel => 'Underline';

  @override
  String get formatToolbarSpoilerLabel => 'Spoiler';

  @override
  String get formatToolbarLinkLabel => 'Link';

  @override
  String get formatToolbarCodeLabel => 'Code';

  @override
  String get linkInputSheetTitle => 'LINK';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => 'APPLY LINK';

  @override
  String get linkInputSheetApplySub =>
      'The selected text will open this address when tapped';

  @override
  String get linkInputSheetRemoveLabel => 'REMOVE LINK';

  @override
  String get linkConfirmSheetTitle => 'Open this link?';

  @override
  String get linkConfirmSheetOpenLabel => 'Open link';

  @override
  String get linkConfirmSheetCancelLabel => 'Cancel';

  @override
  String get roomScreenEditExpiredSnack =>
      'Too late to edit. Messages can only be edited for 15 minutes.';

  @override
  String get roomScreenEditFailedSnack =>
      'Couldn\'t save the edit. Check your connection and try again.';

  @override
  String get messageActionMenuForwardLabel => 'Forward';

  @override
  String get messageActionMenuViewThreadLabel => 'View thread';

  @override
  String get messageActionMenuCopyLabel => 'Copy';

  @override
  String get messageActionMenuCopyNameLabel => 'Copy name';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'Copy coordinates';

  @override
  String get messageActionMenuPinLabel => 'Pin';

  @override
  String get messageActionMenuUnpinLabel => 'Unpin';

  @override
  String get messageActionMenuSelectLabel => 'Select';

  @override
  String get messageActionMenuProfileLabel => 'Profile';

  @override
  String get messageActionMenuDeleteLabel => 'Delete';

  @override
  String get messageActionMenuReportLabel => 'Report';

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
    return 'ACTIVE: $name';
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
  String callScreenStatusCalling(String kind) {
    return '$kind · calling…';
  }

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
  String get callScreenStatusConnected => 'Connected';

  @override
  String get callScreenStatusEnded => 'Call ended';

  @override
  String get callScreenStatusFailed => 'Call failed';

  @override
  String get callScreenStatusSwitching => 'Switching device…';

  @override
  String get callScreenStatusMoved => 'Moved';

  @override
  String get callScreenStatusReconnecting => 'Reconnecting…';

  @override
  String get callScreenPoorConnectionLabel => 'Poor connection';

  @override
  String get callScreenWeakConnectionLabel => 'Weak connection';

  @override
  String get callScreenControlUnmute => 'Unmute';

  @override
  String get callScreenControlMute => 'Mute';

  @override
  String get callScreenControlCamOn => 'Camera on';

  @override
  String get callScreenControlCamOff => 'Camera off';

  @override
  String get callScreenControlFlip => 'Flip';

  @override
  String get callScreenControlSpeaker => 'Speaker';

  @override
  String get callScreenControlEnd => 'End';

  @override
  String get linkPreviewCardLinkLabel => 'Link';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name accepted your request';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'That request was withdrawn';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'Request declined';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'You blocked this user. Unblock first.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'They\'re not accepting friend requests right now.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'Couldn\'t send. Try again.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => 'Incoming request';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'New request';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name wants to start a conversation.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'send a few lines. they can approve or decline.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'Nothing here lives anywhere permanent until both sides agree.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'Room type';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'Ephemeral';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'Standard';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'Lifetime';

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
      'Whisper a first line · optional';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'Add a first message · optional';

  @override
  String get friendRequestDraftScreenHintWhisperFades => 'Whisper · auto-fades';

  @override
  String get friendRequestDraftScreenHintStartWith => 'Something to start with';

  @override
  String get friendRequestDraftScreenApproveButton => 'Approve & open room';

  @override
  String get friendRequestDraftScreenDeclineButton => 'Decline';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'Cancel request';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => 'Ask a grown-up';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'Send request';

  @override
  String get discoverScreenTitle => 'discover.';

  @override
  String get discoverScreenCaptionPeople => 'people';

  @override
  String get discoverScreenCaptionRooms => 'rooms';

  @override
  String get discoverScreenCaptionRequests => 'requests';

  @override
  String get discoverScreenPeopleBandLabel => 'People';

  @override
  String get discoverScreenRoomsBandLabel => 'Rooms';

  @override
  String get discoverScreenFindPeopleTitle => 'Find people';

  @override
  String get discoverScreenFindPeopleSubtitleChild => 'Type a whole username';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'Search by @username or name';

  @override
  String get discoverScreenRequestsSectionLabel => 'Requests';

  @override
  String get discoverScreenInboxQuiet => 'Inbox quiet';

  @override
  String get discoverScreenNothingPending => 'Nothing pending';

  @override
  String get discoverScreenYourPeopleLabel => 'Friends';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'No one yet. Find people above';

  @override
  String get discoverScreenNoFriendsYet => 'No one yet';

  @override
  String get discoverScreenSearchRoomsTitle => 'Search rooms';

  @override
  String get discoverScreenSearchRoomsSubtitle => 'Find a public room by name';

  @override
  String get discoverScreenYourRoomsLabel => 'Rooms';

  @override
  String get discoverScreenNoRoomsYet => 'No rooms yet';

  @override
  String get discoverScreenIncomingLabel => 'Incoming';

  @override
  String get discoverScreenOutgoingLabel => 'Outgoing';

  @override
  String get discoverScreenIncomingLabelCaps => 'INCOMING';

  @override
  String get discoverScreenOutgoingLabelCaps => 'OUTGOING';

  @override
  String get discoverScreenJumpPeopleLabel => 'People';

  @override
  String get discoverScreenJumpRoomsLabel => 'Rooms';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Jump to $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'Adjust';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'Use photo';

  @override
  String get imageCropScreenSavingButton => 'Saving…';

  @override
  String get imageCropScreenCancelButton => 'Cancel';

  @override
  String get imageCropScreenHeicUnsupported =>
      'This browser can\'t open HEIC photos';

  @override
  String get imageCropScreenLoadFailed => 'Couldn\'t open that image';

  @override
  String get imageCropScreenHintCircle => 'Drag to move, pinch to zoom';

  @override
  String get imageCropScreenHintRect => 'Drag and pinch to frame';

  @override
  String get loginScreenSignInHeroMuted => 'welcome\n';

  @override
  String get loginScreenSignInHeroInk => 'back.';

  @override
  String get loginScreenSignInFirstHeroMuted => 'hello\n';

  @override
  String get loginScreenSignInFirstHeroInk => 'there.';

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
  String get searchScreenHintPeople => 'Search people';

  @override
  String get searchScreenHintRooms => 'Search public rooms';

  @override
  String get searchScreenPeoplePromptChild =>
      'Type a whole username to find someone new';

  @override
  String get searchScreenPeoplePromptDefault => 'search by username or name';

  @override
  String get searchScreenNoMatchChild =>
      'No one matches. New people need their\nwhole username, spelled exactly';

  @override
  String get searchScreenNoMatchDefault => 'No one matches';

  @override
  String get searchScreenNoRoomsYet => 'No public rooms yet';

  @override
  String get searchScreenNoRoomsMatch => 'No public rooms match';

  @override
  String get searchScreenActionAskToAdd => 'Ask to add';

  @override
  String get searchScreenActionSendRequest => 'Send request';

  @override
  String get searchScreenActionCancel => 'Cancel';

  @override
  String get searchScreenActionApprove => 'Approve';

  @override
  String get searchScreenActionOpenDm => 'Open DM';

  @override
  String get searchScreenAskedLabel => 'asked';

  @override
  String get profileVisibilityScreenTitle => 'visibility preferences.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'control what others see, and how they can reach you.';

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
      'Copied. Paste it somewhere safe';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'Confirm\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'it’s you.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Your password, so nobody else can put a recovery phrase on your account.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'Password';

  @override
  String get recoveryPhraseScreenContinueButton => 'CONTINUE';

  @override
  String get recoveryPhraseScreenNotNowLink => 'not now';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'Enter your password.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'Save\n';

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
      'not now, keep my current phrase';

  @override
  String get homeScreenProfileSemanticLabel => 'Your profile';

  @override
  String homeScreenGreeting(Object name) {
    return 'hey, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'New room';

  @override
  String get homeScreenEmptyRoomsMessage => 'No rooms yet. Create one';

  @override
  String get groupCallScreenTitleVideo => 'Group video call';

  @override
  String get groupCallScreenTitleVoice => 'Group voice call';

  @override
  String groupCallScreenParticipantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in call',
      one: 'Just you',
    );
    return '$_temp0';
  }

  @override
  String get groupCallScreenReconnecting => 'Reconnecting…';

  @override
  String get groupCallScreenUnmuteLabel => 'Unmute';

  @override
  String get groupCallScreenMuteLabel => 'Mute';

  @override
  String get groupCallScreenCamOnLabel => 'Camera on';

  @override
  String get groupCallScreenCamOffLabel => 'Camera off';

  @override
  String get groupCallScreenFlipLabel => 'Flip';

  @override
  String get groupCallScreenSpeakerLabel => 'Speaker';

  @override
  String get groupCallScreenLeaveLabel => 'Leave';

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
  String get roomFilterDrawerClearLabel => 'Clear';

  @override
  String get roomFilterDrawerDimensionType => 'Type';

  @override
  String get roomFilterDrawerDimensionNature => 'Nature';

  @override
  String get roomFilterDrawerDimensionStatus => 'Status';

  @override
  String get roomFilterDrawerPanelClear => 'Clear';

  @override
  String get roomFilterDrawerPanelDone => 'Done';

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
    return 'Nothing matches $summary';
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
      other: 'Show all $count chats',
      one: 'Show all $count chat',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'New room';

  @override
  String get createRoomSheetTaglineSecret => 'Nothing will be kept';

  @override
  String get createRoomSheetTaglineRegular => 'A space that stays';

  @override
  String get createRoomSheetNameLabel => 'Name';

  @override
  String get createRoomSheetNameHint => 'Name it something honest';

  @override
  String get createRoomSheetDescriptionLabel => 'Description · optional';

  @override
  String get createRoomSheetDescriptionHint => 'One line about the room';

  @override
  String get createRoomSheetVisibilityLabel => 'Visibility';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'Public';

  @override
  String get createRoomSheetVisibilityPublicSub => 'Anyone can find it';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'Private';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'Invite only';

  @override
  String get createRoomSheetTypeLabel => 'Type';

  @override
  String get createRoomSheetTypeStandardTitle => 'Standard';

  @override
  String get createRoomSheetTypeStandardSub => 'Messages persist';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'Ephemeral';

  @override
  String get createRoomSheetTypeEphemeralSub => 'Auto-deletes';

  @override
  String get createRoomSheetMessageLifeLabel => 'Message life';

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
  String get createRoomSheetPasswordLabel => 'Password · optional';

  @override
  String get createRoomSheetPasswordHint => 'Lock with a passphrase';

  @override
  String get createRoomSheetNameRequiredError => 'Name is required';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Open the room';

  @override
  String get createRoomSheetOpenRoomButton => 'Open the room';

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
  String get reactionDetailsSheetTitle => 'Reactions';

  @override
  String get reactionDetailsSheetEmptyState => 'Nothing here anymore';

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
  String get reactionDetailsSheetFilterAll => 'All';

  @override
  String get reactionDetailsSheetYouBadge => 'You';

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
  String get roomLayoutScreenQuietRoomSectionLabel => 'QUIET ROOMS';

  @override
  String get roomLayoutScreenPlainCornerLabel => 'plain corner';

  @override
  String get roomLayoutScreenPlainCornerDescription =>
      'a room with nothing said yet stays bare';

  @override
  String get roomLayoutScreenMonogramLabel => 'the room\'s initial';

  @override
  String get roomLayoutScreenMonogramDescription =>
      'a big faded letter fills the empty corner';

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
  String get audioMessageUnavailableLabel => 'Audio unavailable';

  @override
  String get audioMessageRetryHint => 'Tap to retry';

  @override
  String get audioMessageLoadingLabel => 'Loading…';

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
  String get audioMessageUsernameHint => 'Username';

  @override
  String get audioMessageDisplayNameHint => 'Display name (optional)';

  @override
  String get audioMessagePasswordHint => 'Password';

  @override
  String get audioMessageSwitchToLinkPrompt => 'That one’s mine. Sign in';

  @override
  String get audioMessageCreateAccountButton => 'Create account';

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
  String get approvalsScreenErrorGeneric => 'couldn\'t save that, try again';

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
  String get approvalsScreenForwardDirectMessageFallback => 'Direct message';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Forward $count messages',
      one: 'Forward message',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'No other chats yet';

  @override
  String get approvalsScreenForwardNoMatches => 'Nothing matches';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'Up to $max chats at a time';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'Search chats';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Deselect $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Select $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'Fades';

  @override
  String get approvalsScreenForwardSendSemantic => 'Send';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send to $count',
      zero: 'Send',
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
  String get linkedAccountsScreenCallSheetVoiceLabel => 'Voice';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'Video';

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
  String get profileScreenDeleteAccountFailed =>
      'Something went wrong. Try again.';

  @override
  String get childPairScreenAccountGoneError =>
      'That account isn’t there any more.';

  @override
  String get childPairScreenScanButtonLabel => 'SCAN THEIR CODE';

  @override
  String get childPairScreenNoCameraMessage =>
      'No camera here. Type the six numbers instead.';

  @override
  String get childPairScreenStopScanning => 'Stop scanning';

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
  String fileMessageViewSemanticLabel(Object name) {
    return 'View $name';
  }

  @override
  String get textFileViewerDownloadTooltip => 'Download';

  @override
  String get textFileViewerTruncatedNotice =>
      'Showing part of this file. Download to see the rest.';

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
  String get fileMessageStandardBadge => 'Standard';

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
  String get fileMessageApproveButton => 'Approve';

  @override
  String get fileMessageDeclineButton => 'Decline';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'Sent $ago';
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
  String get fileMessageCancelRequestButton => 'Cancel request';

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
      'Couldn’t make a code. Try again.';

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
    return 'On $name’s phone, open MonkeyHub and scan this, or type the numbers.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'This code has expired';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'Expires in $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'New code';

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
  String get deepOceanThemeEphemeralHint => 'Whisper something';

  @override
  String get deepOceanThemeDefaultHint => 'Say something';

  @override
  String get deepOceanThemeMessageHint => 'Message';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'This file is gone';

  @override
  String get photoChromeMediaYouLabel => 'You';

  @override
  String get photoChromeCloseSemanticLabel => 'Close';

  @override
  String get photoChromeFillToggleSemanticLabel => 'Fit or fill the screen';

  @override
  String get photoChromeShowInChatSemanticLabel => 'Show in chat';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return 'Item $current of $total';
  }

  @override
  String photoTrayCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get photoDeckBackToFirst => 'Back to first';

  @override
  String get inlinePickerCommentHint => 'Add comment or send';

  @override
  String get attachmentMenuGalleryLabel => 'Gallery';

  @override
  String inlinePickerVideoCompressNote(String size) {
    return 'Over $size, so it\'ll be compressed to send';
  }

  @override
  String messageMenuAlbumAll(int count) {
    return 'All $count';
  }

  @override
  String get messageMenuAlbumOne => 'This one';

  @override
  String replyAlbumItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => 'Discard these photos';

  @override
  String get photoTrayRemoveSemanticLabel => 'Remove this photo';

  @override
  String get photoTrayEditSemanticLabel => 'Crop or draw on this photo';

  @override
  String get photoTrayAddMoreSemanticLabel => 'Add more photos';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'You can send $count photos at a time';
  }

  @override
  String get photoTrayLoadFailedSnack =>
      'Some of those photos couldn’t be opened';

  @override
  String get mediaPickFailedMessage =>
      'Couldn’t open that. Try picking it again';

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
  String get typingIndicatorUnknownCallerFallbackName => 'Incoming call';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'Incoming video call';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'Incoming voice call';

  @override
  String get typingIndicatorDeclineButtonLabel => 'Decline';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'Declining…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'Accept';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'Connecting…';

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
  String get messageStampSentLabel => 'sent';

  @override
  String get messageStampDeliveredLabel => 'delivered';

  @override
  String get messageStampSeenLabel => 'seen';

  @override
  String get messageStampSavedLabel => 'saved';

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
      'Microphone permission denied';

  @override
  String get voiceRecorderScreenStatusRecording => 'Recording';

  @override
  String get voiceRecorderScreenStatusReady => 'Ready';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'Tap to start';

  @override
  String get voiceRecorderScreenReRecordButton => 'Re-record';

  @override
  String get voiceRecorderScreenStopButton => 'Stop';

  @override
  String get voiceRecorderScreenSendButton => 'Send';

  @override
  String get voiceRecorderScreenRecordButton => 'Record';

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
    return 'This signs $name out of this phone and hands it back. The phone returns to the normal sign-in screen, and anyone can use it.';
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
  String get activeCallPillPinnedHeader => 'Pinned';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'Pinned · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'Nothing pinned anymore';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Jump to message from $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Unpin message from $name';
  }

  @override
  String get callButtonErrorBusy => 'Busy on another call';

  @override
  String get callButtonErrorCallFailed => 'Could not start call';

  @override
  String get callButtonErrorNotMember => 'Not a member of this room';

  @override
  String get callButtonErrorGeneric => 'Could not start call';

  @override
  String get callButtonAlreadyOnCall => 'You\'re already on a call';

  @override
  String get callButtonBusyElsewhere => 'Call in progress on another device';

  @override
  String get callButtonVoiceCallTooltip => 'Voice call';

  @override
  String get callButtonVideoCallTooltip => 'Video call';

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
      'accent-tinted quote pill with a tether bar and avatar: the familiar WhatsApp-style look.';

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
      'Couldn’t create the account. Try again.';

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
      'Everyone else needs your OK first: both people they ask for, and people who ask for them.';

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
  String get childSetupScreenWaitingPillAskedLabel => 'Asked';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'IN';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'See all $count';
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
      'no tail. A run holds together through its tightened inner corners alone.';

  @override
  String get bubbleStyleScreenPillLabel => 'PILL';

  @override
  String get bubbleStyleScreenPillDescription =>
      'fully rounded capsules, identical on every row.';

  @override
  String get bubbleStyleScreenSlabLabel => 'SLAB';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'square shoulders: sharp, printed, deliberate.';

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
      'Last message just now';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'Last message ${hours}h ago';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'Last message yesterday';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'Last message $days days ago';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'Last message a while ago';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'Take back';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return 'Take $contactName away from $childName?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'They won’t be able to reach each other, and their conversation goes with it.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'They won’t be able to reach each other. $contactName won’t be told.';
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
      'Gone for both of them, including photos and voice notes. This can’t be undone.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'They also share $count rooms',
      one: 'They also share $count room',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'These stay. Take the room back from the Rooms list below if you want them out of it.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'Take back & delete';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'Removes $contactName and wipes $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'Removes $contactName from the allowed list.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Cancel';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => 'Cancel';

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
  String get groupCallBannerJoinButtonLabel => 'Join';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'Join room';

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
  String get groupCallBannerPasswordFieldLabel => 'Password';

  @override
  String get groupCallBannerPasswordHint => 'Passphrase';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Join';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'Join';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Cancel';

  @override
  String get groupCallBannerCancelButtonLabel => 'Cancel';

  @override
  String get viewOnceViewerBadgeLabel => 'View once';

  @override
  String get socialButtonDividerOr => 'or';

  @override
  String get socialButtonGoogleContinue => 'Continue with Google';

  @override
  String get discoverListsPeopleTitle => 'Friends';

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
  String get discoverListsFilterHint => 'Search friends';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Clear filter';

  @override
  String get discoverListsNoOneYet => 'No one yet';

  @override
  String discoverListsNoMatches(Object query) {
    return 'No one matches \"$query\"';
  }

  @override
  String get discoverListsRoomsTitle => 'Rooms';

  @override
  String discoverListsRoomsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rooms',
      one: '$count room',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterRoomsHint => 'Search your rooms';

  @override
  String get discoverListsNoRoomsYet => 'No rooms yet';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return 'No rooms match \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'VOICE CALL';

  @override
  String get discoverListsVideoCallLabel => 'VIDEO CALL';

  @override
  String get approvalGateAlreadyAskedLabel => 'Already asked';

  @override
  String get approvalGateAskGrownUpLabel => 'Ask a grown-up';

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
  String get approvalGateAskButton => 'Ask';

  @override
  String get approvalGateNotNowButton => 'NOT NOW';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => 'Waiting for a grown-up';

  @override
  String get reportSheetTitle => 'REPORT';

  @override
  String get reportSheetSubtitle => 'tell us what’s wrong.';

  @override
  String get reportSheetPrivacyNote =>
      'reports are private. The other person isn’t notified.';

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
  String get reportSheetUpdateRequiredTitle => 'Update required';

  @override
  String get reportSheetUpdateAvailableTitle => 'Update available';

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
  String get reportSheetUpdateButtonTitle => 'Update';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'Opens TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'Opens the App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'Opens Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'Opens the download page';

  @override
  String get reportSheetUpdateActionReloads => 'Reloads with the new version';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Later';

  @override
  String get reportSheetUpdateLaterButton => 'Later';

  @override
  String get roomFilterBarAllChipLabel => 'All';

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
    return 'Replying to $name';
  }

  @override
  String get roomCardLockedBadge => 'Locked';

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
  String roomCardStartedAgo(Object ago) {
    return 'Started $ago';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count inside';
  }

  @override
  String get roomCardMessagesFadeLabel => 'Messages fade';

  @override
  String get roomCardEnterLabel => '↗ Enter';

  @override
  String get roomCardBlockedScreenTitle => 'BLOCKED';

  @override
  String get roomCardBlockedEmptyState => 'you haven’t blocked anyone.';

  @override
  String get roomCardUnblockButton => 'UNBLOCK';

  @override
  String get attachmentMenuPhotoLabel => 'Photo';

  @override
  String get attachmentMenuVideoLabel => 'Video';

  @override
  String get attachmentMenuCameraLabel => 'Camera';

  @override
  String get attachmentMenuVoiceLabel => 'Voice';

  @override
  String get attachmentMenuFileLabel => 'File';

  @override
  String get attachmentMenuConnectionRetrying => 'Retrying…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'Can’t reach the server · Tap to retry';

  @override
  String get attachmentMenuConnectionReconnecting => 'Reconnecting…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel => 'Retry connection';

  @override
  String get roomGridTileEmptyLastMessage => 'quiet so far';

  @override
  String get roomGridTileMemberCountLabel => 'In';

  @override
  String get roomGridTileThemeChipLabel => 'THEME';

  @override
  String get bulkActionBarCancelLabel => 'Cancel';

  @override
  String get bulkActionBarSelectMessagesLabel => 'Select messages';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count selected';
  }

  @override
  String get bulkActionBarForwardLabel => 'Forward';

  @override
  String get bulkActionBarDeleteLabel => 'Delete';

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
      'They won’t be notified.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'You’re currently friends. Blocking removes the friendship, so to reconnect later you’d have to send a new friend request.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'They’ll disappear from your search and can’t message you.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'Block';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return 'Block $name?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You share $count rooms with them',
      one: 'You share $count room with them',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'These rooms stay untouched. You can leave any of them yourself from each room’s settings.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'Block';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'Remove friendship and block. Existing chat history stays in your archive.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'They’re hidden from search and can’t reach you.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'Block & delete DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'Also wipes your DM with them: every message, reaction, and media file is gone.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Cancel';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'Cancel';

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
  String get reactionBubblePickerTitle => 'React';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'No recents yet';

  @override
  String get reactionBubbleSearchHint => 'Search emoji';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'No matches';

  @override
  String get reactionBubbleSearchBackSemanticLabel => 'Back to emoji';

  @override
  String get reactionBubblePasswordHint => 'password';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return 'join $roomName';
  }

  @override
  String get enterPublicRoomAskFailedMessage =>
      'Couldn\'t ask right now. Try again';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'wrong password';

  @override
  String get enterPublicRoomJoinFailedMessage => 'couldn\'t join, try again';

  @override
  String get feedBoardTitle => 'TODAY';

  @override
  String feedBoardEditionLabel(Object number) {
    return '№$number';
  }

  @override
  String get feedBoardHighlightsLabel => 'Highlights';

  @override
  String get feedBoardHighlightsEmpty => 'Nothing captured yet today';

  @override
  String get feedBoardPuzzleLabel => 'THE PUZZLE';

  @override
  String get feedBoardPuzzleEmpty => 'today\'s puzzle isn\'t ready yet';

  @override
  String get feedBoardStandingsLabel => 'Life points';

  @override
  String get feedBoardStandingsEmpty => 'No points on the board today';

  @override
  String get feedBoardActivityLabel => 'Activity';

  @override
  String get feedBoardActivityEmpty => 'quiet so far today';

  @override
  String get feedBoardActivityNoFriends =>
      'Add a friend and their day shows up here';

  @override
  String get feedBoardLoadFailed =>
      'Couldn\'t load the board. Try again in a moment';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'Public';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'Private';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'Joined';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'Ephemeral · $duration';
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
  String get roomBadgePublicTooltip => 'Anyone can find this room and join it';

  @override
  String get roomBadgePrivateTooltip =>
      'Invite only. It won\'t show up in Discover';

  @override
  String get roomBadgeLockedTooltip => 'You\'ll need the room password to join';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return 'Messages disappear after $duration';
  }

  @override
  String get roomBadgeJoinedTooltip => 'You\'re already in this room';

  @override
  String get roomInfoSheetDetailsLabel => 'THE DETAILS';

  @override
  String get roomInfoSheetNoDescription => 'No description yet';

  @override
  String get roomInfoSheetCreatedLabel => 'Created';

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
      'No recovery phrase. You could not get back in.';

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
  String get roomContentTabLabelMedia => 'Media';

  @override
  String get roomContentTabLabelFiles => 'Files';

  @override
  String get roomContentTabLabelVoice => 'Voice';

  @override
  String get roomContentTabLabelLinks => 'Links';

  @override
  String get roomContentTabLabelSaved => 'Saved';

  @override
  String get roomContentTabHeaderMedia => 'Media';

  @override
  String get roomContentTabHeaderFiles => 'Files';

  @override
  String get roomContentTabHeaderVoice => 'Voice';

  @override
  String get roomContentTabHeaderLinks => 'Links';

  @override
  String get roomContentTabHeaderSaved => 'Saved';

  @override
  String get roomFacetLabelDms => 'DMs';

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
  String get settingsScreenSectionChat => 'CHAT';

  @override
  String get settingsScreenSectionCompanions => 'COMPANIONS';

  @override
  String get settingsScreenSectionGeneral => 'GENERAL';

  @override
  String get settingsScreenCheckForUpdatesLabel => 'CHECK FOR UPDATES';

  @override
  String get settingsScreenUpdateAvailableValue => 'UPDATE AVAILABLE';

  @override
  String get settingsScreenUpdateUpToDateSnackbar =>
      'You\'re on the latest version.';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      'Can\'t check for updates on this build.';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      'Couldn\'t check for updates. Try again later.';

  @override
  String get settingsScreenSectionNotifications => 'NOTIFICATIONS';

  @override
  String get reportProblemRowLabel => 'Report a problem';

  @override
  String get reportProblemRowValue => 'Send us the details';

  @override
  String get reportProblemIntro =>
      'Tell us what went wrong. Your app and device details are included automatically, along with a technical log of what the app was doing. That’s what helps us find the cause.';

  @override
  String get reportProblemDescribeLabel => 'What happened';

  @override
  String get reportProblemDescribeHint =>
      'The screen flickers, buttons don’t respond';

  @override
  String get reportProblemScreenshotsLabel => 'Screenshots';

  @override
  String get reportProblemAddScreenshot => 'Add screenshot';

  @override
  String get reportProblemDetailsLabel => 'Your details';

  @override
  String get reportProblemCopyDetails => 'Copy details';

  @override
  String get reportProblemCopied => 'Copied';

  @override
  String get reportProblemSend => 'Send report';

  @override
  String get reportProblemSent => 'Report sent. Thank you!';

  @override
  String get reportProblemSendFailed =>
      'Couldn’t send the report. Check your connection and try again.';

  @override
  String get reportProblemTooMany =>
      'You’ve sent a lot of reports just now. Please try again a bit later.';

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
      'currently preview only: cleaner bubbles, tap to open';

  @override
  String get settingsScreenMenuBarLabel => 'MENU BAR ICON';

  @override
  String get settingsScreenMenuBarOnBody =>
      'MonkeyHub sits in the menu bar with its unread count. Click it for the window';

  @override
  String get settingsScreenMenuBarOffBody =>
      'currently off. The Dock icon is the only way back to a hidden window';

  @override
  String get settingsScreenSectionCalls => 'CALLS';

  @override
  String get settingsScreenRowVideoQuality => 'Video quality';

  @override
  String get settingsScreenValueVideoQualityAuto => 'Auto';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel => 'SHOW CALL STATS';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      'live resolution, bitrate, ping, and packet loss during calls';

  @override
  String get videoQualityScreenTitle => 'Video quality';

  @override
  String get videoQualityScreenSubtitle =>
      'Choose a resolution ceiling for outgoing video';

  @override
  String get videoQualityScreenAutoSubtitle =>
      'Adapts to your connection automatically';

  @override
  String get videoQualityScreenHd1080Subtitle =>
      'Full HD: sharper, uses more data';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD: best on a strong connection';

  @override
  String get videoQualityScreenFootnote =>
      'Actual resolution depends on both devices\' cameras and network conditions.';

  @override
  String get callScreenControlOptions => 'More';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => 'Jitter';

  @override
  String get callScreenStatsLossLabel => 'Loss';

  @override
  String get callScreenSwapPreviewSemanticLabel => 'Swap camera views';

  @override
  String get callOptionsSheetTitle => 'Call options';

  @override
  String get settingsScreenPushNotificationsLabel => 'PUSH NOTIFICATIONS';

  @override
  String get settingsScreenPushOnBody => 'pings for new messages + requests';

  @override
  String get settingsScreenPushOffBody =>
      'silent. You’ll only see things when you open the app';

  @override
  String get settingsScreenGameRemindersLabel => 'DAILY GAME REMINDER';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'one nudge at lunchtime, only if you haven’t played';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'no reminder. The games are still there when you look';

  @override
  String get authErrorUsernameTaken => 'That username is already taken.';

  @override
  String get authErrorUsernameReserved =>
      'That username isn\'t available. Please pick a different one.';

  @override
  String get authErrorDisplayNameReserved =>
      'That name isn\'t available. Please pick a different one.';

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
      'That’s a kid’s account. Ask a grown-up for a pairing code.';

  @override
  String get authErrorPairingCodeExpired =>
      'That code has run out. Ask for a new one.';

  @override
  String get authErrorPairingCodeInvalid =>
      'That code didn’t work. It may have been used already.';

  @override
  String get authErrorUseSocialSignIn =>
      'That account signs in with Apple or Google. Use the buttons below.';

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
  String get authErrorUsernameChangedRecently =>
      'You\'ve changed your username recently. You can change it again 30 days after the last one.';

  @override
  String get authErrorInboxHandleLocked =>
      'This account receives everyone\'s problem reports, so its username is fixed.';

  @override
  String get glassKnobLabelFrost => 'Frost';

  @override
  String get glassKnobHintFrost =>
      'How much white sits on the glass. Down for see-through';

  @override
  String get glassKnobLabelBlur => 'Blur';

  @override
  String get glassKnobHintBlur =>
      'Frosted at the top of the range, clear glass at the bottom';

  @override
  String get glassKnobLabelSaturation => 'Colour bleed';

  @override
  String get glassKnobHintSaturation =>
      'How much colour survives the blur. Past 2 it posterizes';

  @override
  String get glassKnobLabelRimOpacity => 'Rim';

  @override
  String get glassKnobHintRimOpacity =>
      'Brightness of the glass edge. Zero for a borderless surface';

  @override
  String get glassKnobLabelRimWidth => 'Rim width';

  @override
  String get glassKnobHintRimWidth => 'Thickness of that outline';

  @override
  String get glassKnobLabelShadowOpacity => 'Shadow';

  @override
  String get glassKnobHintShadowOpacity =>
      'How far the surface floats above what is behind it';

  @override
  String get glassKnobLabelShadowBlur => 'Shadow spread';

  @override
  String get glassKnobHintShadowBlur => 'Soft and wide, or tight and hard';

  @override
  String get glassKnobLabelShadowY => 'Shadow drop';

  @override
  String get glassKnobHintShadowY => 'How far below the surface it falls';

  @override
  String get glassKnobLabelBarMargin => 'Side margin';

  @override
  String get glassKnobHintBarMargin =>
      'Gap between the bar and the edge of the screen';

  @override
  String get glassKnobLabelBarBottom => 'Bottom gap';

  @override
  String get glassKnobHintBarBottom => 'How high the bar floats off the bottom';

  @override
  String get glassKnobLabelShellPadH => 'End padding';

  @override
  String get glassKnobHintShellPadH =>
      'Bar edge to the first pill. Small, or the ends look marooned';

  @override
  String get glassKnobLabelShellPadV => 'Top padding';

  @override
  String get glassKnobHintShellPadV => 'Bar edge to the top of the pill';

  @override
  String get glassKnobLabelIndicatorInset => 'Pill inset';

  @override
  String get glassKnobHintIndicatorInset =>
      'How far the selection pill sits inside its slot';

  @override
  String get glassKnobLabelSegmentPadV => 'Row padding';

  @override
  String get glassKnobHintSegmentPadV =>
      'Air above and below the icon and its label';

  @override
  String get glassKnobLabelIconLabelGap => 'Icon gap';

  @override
  String get glassKnobHintIconLabelGap =>
      'Space between an icon and the word under it';

  @override
  String get glassKnobLabelIconSize => 'Icon size';

  @override
  String get glassKnobLabelLabelSize => 'Label size';

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
  String get settingsScreenRowMotion => 'MOTION';

  @override
  String get settingsScreenValueMotionFull => 'Full';

  @override
  String get settingsScreenValueMotionCalm => 'Calm';

  @override
  String get settingsScreenValueMotionSystemFull => 'Match device · Full';

  @override
  String get settingsScreenValueMotionSystemCalm => 'Match device · Calm';

  @override
  String get motionScreenTitle => 'motion.';

  @override
  String get motionScreenSubtitle => 'how much the app moves';

  @override
  String get motionScreenSystemLabel => 'MATCH DEVICE';

  @override
  String get motionScreenSystemSubtitleFull =>
      'your device allows animation right now';

  @override
  String get motionScreenSystemSubtitleCalm =>
      'your device asks for reduced motion right now';

  @override
  String get motionScreenFullLabel => 'FULL';

  @override
  String get motionScreenFullSubtitle => 'every drift, glow and flourish';

  @override
  String get motionScreenCalmLabel => 'CALM';

  @override
  String get motionScreenCalmSubtitle =>
      'decoration holds still, nothing else changes';

  @override
  String get momentRailCaptureLabel => 'Capture';

  @override
  String get momentRailYouLabel => 'You';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String momentRailPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count highlights',
      one: '1 highlight',
    );
    return '$_temp0';
  }

  @override
  String momentRailPersonNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new',
      one: '1 new',
    );
    return '$_temp0';
  }

  @override
  String get momentRailAddHighlight => 'Add a highlight';

  @override
  String get momentTagFate => 'Fate';

  @override
  String get momentTagJinx => 'Jinx';

  @override
  String get momentTagLuck => 'Luck';

  @override
  String get momentTagCalledIt => 'Called it';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'What are the odds';

  @override
  String get momentTagJinxHint => 'You did it to yourself';

  @override
  String get momentTagLuckHint => 'That went your way';

  @override
  String get momentTagCalledItHint => 'You saw it coming';

  @override
  String get momentTagNpcHint => 'Brain fully off';

  @override
  String get momentComposerTitle => 'New highlight';

  @override
  String get momentComposerCaptionHint => 'Say something about it';

  @override
  String get momentComposerTagPrompt => 'won a point? add it now';

  @override
  String get momentComposerCapture => 'Camera';

  @override
  String get momentComposerLibrary => 'Library';

  @override
  String get momentComposerRemovePhoto => 'Remove photo';

  @override
  String get momentComposerPost => 'Post';

  @override
  String get momentComposerErrorDailyCap =>
      'That\'s five of those today. Save some for tomorrow';

  @override
  String get momentComposerErrorNotAllowed =>
      'A guardian has turned photo sharing off';

  @override
  String get momentComposerErrorTooLong => 'That\'s a bit long. Trim it down';

  @override
  String get momentComposerErrorEmpty => 'Add a photo or a few words';

  @override
  String get momentComposerErrorGeneric => 'Couldn\'t post that. Try again';

  @override
  String get momentViewerDelete => 'Delete';

  @override
  String get momentViewerDeleteConfirmHeadline => 'Delete this?';

  @override
  String get momentViewerDeleteConfirmBody =>
      'It leaves everyone\'s board and your archive, for good';

  @override
  String get momentViewerDeleteFailed => 'Couldn\'t delete that. Try again';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who posted a highlight';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name logged a point: $tag';
  }

  @override
  String get momentActivityJustNow => 'now';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '${count}m';
  }

  @override
  String momentActivityHoursAgo(Object count) {
    return '${count}h';
  }

  @override
  String get puzzleScreenTitle => 'the puzzle.';

  @override
  String get puzzleScreenSubtitle => 'Four symbols, six tries';

  @override
  String get puzzleSubmit => 'Guess';

  @override
  String get puzzleBackspace => 'Delete last symbol';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'Symbol $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'Solved in $count';
  }

  @override
  String get puzzleFailedTitle => 'Out of guesses';

  @override
  String get puzzleAnswerWas => 'The code was';

  @override
  String get puzzleShare => 'Copy result';

  @override
  String get puzzleShareCopied => 'Copied. Paste it to a friend';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'You already solved today\'s';

  @override
  String get puzzleErrorOutOfGuesses => 'No guesses left today';

  @override
  String get puzzleErrorGeneric => 'Couldn\'t send that guess. Try again';

  @override
  String get puzzleGuessWaiting =>
      'No connection. Your guess is saved and goes through when you\'re back';

  @override
  String get gameSubmitWaiting =>
      'No connection. Your finished board is saved and goes in when you\'re back';

  @override
  String get puzzleScoreboardLabel => 'Today\'s scores';

  @override
  String get puzzleScoreboardEmpty => 'Nobody has finished yet today';

  @override
  String get puzzleTilePlay => 'play today\'s puzzle';

  @override
  String puzzleTileInProgress(Object count) {
    return '$count left';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '#$rank of $total';
  }

  @override
  String get profileVisibilityScreenSectionFeed => 'FEED';

  @override
  String get profileVisibilityScreenFeedLabel => 'my highlights';

  @override
  String get profileVisibilityScreenFeedDesc =>
      'whether the photos and videos you post show up on friends\' boards for the day';

  @override
  String get profileVisibilityScreenPuzzleLabel => 'my puzzle score';

  @override
  String get profileVisibilityScreenPuzzleDesc =>
      'whether friends see how you did on the daily puzzle';

  @override
  String get profileVisibilityScreenPointsPastLabel => 'my past';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      'today is always shared with friends. This opens up everything before it';

  @override
  String get momentComposerVideo => 'Video';

  @override
  String get momentComposerErrorTooBig => 'That video\'s too large. 20 MB max';

  @override
  String get momentActivityPostedHighlightSelf => 'You posted a highlight';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'You logged a point: $tag';
  }

  @override
  String momentActivityGameSolved(String game, String name) {
    return '$name solved $game';
  }

  @override
  String momentActivityGameSolvedSelf(String game) {
    return 'You solved $game';
  }

  @override
  String momentActivityGameMissed(String game, String name) {
    return '$name didn\'t solve $game';
  }

  @override
  String momentActivityGameMissedSelf(String game) {
    return 'You didn\'t solve $game';
  }

  @override
  String momentActivityCodeSolved(String name) {
    return '$name cracked the code';
  }

  @override
  String get momentActivityCodeSolvedSelf => 'You cracked the code';

  @override
  String momentActivityCodeMissed(String name) {
    return '$name didn\'t crack the code';
  }

  @override
  String get momentActivityCodeMissedSelf => 'You didn\'t crack the code';

  @override
  String pointLineSelf(Object tag) {
    return 'You · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'What happened?';

  @override
  String get pointComposerNoteHint => 'Pick one above, then tell the story';

  @override
  String get pointComposerAdd => 'Add a point';

  @override
  String get pointComposerAddPhoto => 'add a photo';

  @override
  String get pointsBoardAdd => 'Add a point';

  @override
  String get pointsExplainerOpen => 'What\'s this?';

  @override
  String get pointsExplainerTitle => 'The points game';

  @override
  String get pointsExplainerIntro =>
      'A running joke you keep score of. When something happens to you (good, bad or just strange), you log it and it goes on the board for the day.';

  @override
  String get pointsExplainerRuleHonour =>
      'You award your own points. Nobody checks. That\'s the fun, and your friends will tell you if you\'re pushing it.';

  @override
  String get pointsExplainerRuleToday =>
      'Points reset every day. The board shows today; your own history is yours to keep.';

  @override
  String get pointsExplainerRuleCap =>
      'Five of any one kind per day, so nobody can farm the board into nonsense.';

  @override
  String get pointsExplainerGotIt => 'Got it';

  @override
  String get momentTagFateExample => 'Ran into my dentist in another country';

  @override
  String get momentTagJinxExample => 'Washed the car, it rained at four';

  @override
  String get momentTagLuckExample =>
      'Caught the train with two seconds to spare';

  @override
  String get momentTagCalledItExample =>
      'Said the sequel would flop, it flopped';

  @override
  String get momentTagNpcExample => 'Said ‘you too’ to the waiter';

  @override
  String feedBoardEditionHint(Object number) {
    return 'Day $number of the feed';
  }

  @override
  String get feedBoardHighlightsHint => 'photos and videos worth a look';

  @override
  String get profileVisibilityScreenPointsLabel => 'my points';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'whether the points you log show up on friends\' boards';

  @override
  String get momentComposerEditPhoto => 'Edit crop';

  @override
  String get archiveScreenTitle => 'Your archive';

  @override
  String get archiveScreenEnd => 'That\'s everything';

  @override
  String get archiveScreenEmptyTitle => 'Nothing kept yet';

  @override
  String get archiveScreenEmptyBody =>
      'Moments leave your friends\' boards after a day, but they stay here for you.';

  @override
  String get archiveScreenEmptyFriendTitle => 'Nothing here';

  @override
  String get archiveScreenEmptyFriendBody =>
      'They haven\'t posted anything you can see yet.';

  @override
  String get archiveScreenPrivateTitle => 'Their past is private';

  @override
  String get archiveScreenPrivateBody =>
      'You can still see what they post today.';

  @override
  String get archiveScreenNotFriendTitle => 'Not friends';

  @override
  String get archiveScreenNotFriendBody =>
      'You can only look back through a friend\'s days.';

  @override
  String get archiveScreenErrorTitle => 'Couldn\'t load that';

  @override
  String get archiveScreenErrorBody => 'Check your connection and try again.';

  @override
  String get feedBoardOpenArchive => 'Archive';

  @override
  String get feedBoardGamesLabel => 'Games';

  @override
  String get feedBoardGamesOpen => 'Leaderboard';

  @override
  String get gamesScreenTitle => 'the games.';

  @override
  String get gamesScreenSubtitle =>
      'four boards a day, the same four for everyone';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count left today',
      one: 'one left today',
      zero: 'all done today',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => 'Couldn\'t load today\'s games';

  @override
  String get gamesRetry => 'Try again';

  @override
  String get gameQueensName => 'Queens';

  @override
  String get gameQueensRule =>
      'One crown per row, column and colour, never touching';

  @override
  String get gameTangoName => 'Tango';

  @override
  String get gameTangoRule => 'three suns, three moons, never three in a row';

  @override
  String get gameZipName => 'Zip';

  @override
  String get gameZipRule => 'one line through every square, numbers in order';

  @override
  String get gameSudokuName => 'Mini sudoku';

  @override
  String get gameSudokuRule => '1 to 6 once per row, column and box';

  @override
  String get gameCodeName => 'The code';

  @override
  String get gameStatusUnplayed => 'Not played';

  @override
  String get gameStatusUnfinished => 'In progress';

  @override
  String get gameStatusGaveUp => 'Gave up';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'Pause';

  @override
  String get gameResume => 'Resume';

  @override
  String get gamePausedTitle => 'Paused';

  @override
  String get gamePausedBody => 'The clock is stopped and the board is hidden';

  @override
  String get gameUndo => 'Undo';

  @override
  String get gameClear => 'clear';

  @override
  String get gameHint => 'Hint';

  @override
  String get gameNotes => 'notes';

  @override
  String get gameErase => 'erase';

  @override
  String get gameAutoCross => 'Auto-cross';

  @override
  String get gameGiveUp => 'Give up';

  @override
  String get gameGiveUpTitle => 'Show the answer?';

  @override
  String get gameGiveUpBody =>
      'Today\'s board closes and it goes down as unsolved.';

  @override
  String get gameGiveUpCancel => 'Keep trying';

  @override
  String get gameGiveUpConfirm => 'Show it';

  @override
  String gameSolvedTitle(Object time) {
    return 'Solved in $time';
  }

  @override
  String get gameGaveUpTitle => 'Today\'s answer';

  @override
  String get gameFirstInToday => 'First one in today';

  @override
  String gameRankLine(Object place, Object total) {
    return '$place of $total so far';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mistakes',
      one: '1 mistake',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hints',
      one: '1 hint',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => 'Today\'s times';

  @override
  String get gameStandingsEmpty => 'Nobody\'s finished this one yet';

  @override
  String get gameShare => 'Copy result';

  @override
  String get gameShareCopied => 'Copied. Paste it to a friend';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number · $time';
  }

  @override
  String get gameBackToHub => 'All games';

  @override
  String get gameElapsedSemantic => 'Elapsed time';

  @override
  String get gameErrorNotSolved => 'That board isn\'t finished yet';

  @override
  String get gameErrorAlreadyFinished => 'You already finished today\'s';

  @override
  String get gameErrorNoHint => 'No hint for this one';

  @override
  String get gameErrorGeneric => 'Couldn\'t reach the games. Try again';

  @override
  String get gameInfoOpen => 'How to play';

  @override
  String get gameInfoLabel => 'How to play';

  @override
  String get gameInfoRulesLabel => 'The rules';

  @override
  String get gameInfoControlsLabel => 'What to tap';

  @override
  String get gameInfoScoringTimed =>
      'Finish fastest to win. The clock stops when you leave.';

  @override
  String get gameInfoScoringGuesses =>
      'Crack it in the fewest guesses to win. Time doesn\'t count.';

  @override
  String get gameInfoSameForEveryone => 'Everyone gets the same puzzle today.';

  @override
  String get gameInfoQueensGoal => 'Put 8 crowns on the board.';

  @override
  String get gameInfoQueensRule1 => 'Every row gets exactly 1 crown.';

  @override
  String get gameInfoQueensRule2 => 'Every column gets exactly 1 crown.';

  @override
  String get gameInfoQueensRule3 => 'Every colour gets exactly 1 crown.';

  @override
  String get gameInfoQueensControls =>
      'Tap once for × (no crown here). Tap twice for a crown. Tap again to clear.';

  @override
  String get gameInfoTangoGoal => 'Fill every square with a sun or a moon.';

  @override
  String get gameInfoTangoRule1 => 'Every row has 3 suns and 3 moons.';

  @override
  String get gameInfoTangoRule2 => 'Every column has 3 suns and 3 moons.';

  @override
  String get gameInfoTangoRule3 => 'Never 3 of the same in a line. 2 is fine.';

  @override
  String get gameInfoTangoControls =>
      'Tap once for a sun, twice for a moon, again to clear. Squares that start filled can\'t change.';

  @override
  String get gameInfoZipGoal => 'Draw one line through every square.';

  @override
  String get gameInfoZipRule1 => 'Start on 1.';

  @override
  String get gameInfoZipRule2 => 'Visit the numbers in order: 1, 2, 3…';

  @override
  String get gameInfoZipRule3 => 'Fill every square. Use each square once.';

  @override
  String get gameInfoZipControls =>
      'Drag your finger to draw. Drag back to undo.';

  @override
  String get gameInfoSudokuGoal => 'Fill the grid with the numbers 1 to 6.';

  @override
  String get gameInfoSudokuRule1 =>
      'Every row has 1, 2, 3, 4, 5 and 6. No repeats.';

  @override
  String get gameInfoSudokuRule2 => 'Every column too.';

  @override
  String get gameInfoSudokuRule3 =>
      'Every box too. A box is 2 rows by 3 columns.';

  @override
  String get gameInfoSudokuControls =>
      'Tap a square, then a number. Tap the number again to erase. Notes adds small pencil marks.';

  @override
  String get gameInfoCodeGoal => 'Guess the secret code of 4 symbols.';

  @override
  String get gameInfoCodeRule1 =>
      'The code uses 4 different symbols. No repeats.';

  @override
  String get gameInfoCodeRule2 => 'You get 6 guesses.';

  @override
  String get gameInfoCodeRule3 => 'Green: right symbol, right spot.';

  @override
  String get gameInfoCodeControls => 'Tap 4 symbols, then tap Guess.';

  @override
  String get savedMessagesTitle => 'Saved Messages';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'no chats match \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'Search chats';

  @override
  String get pullRevealCollapseSemanticLabel =>
      'Hide search and archived chats';

  @override
  String archivedChatsFolderLabel(Object count) {
    return 'archived chats ($count)';
  }

  @override
  String get archivedChatsFolderTitle => 'archived chats';

  @override
  String get pullRevealClearSearchSemanticLabel => 'Clear search';

  @override
  String get archivedChatsSheetTitle => 'Archived chats';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'Archived chats · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'Nothing archived anymore';

  @override
  String get pinnedBadgeLabel => 'PINNED';

  @override
  String get chatRowActionMenuPinLabel => 'Pin chat';

  @override
  String get chatRowActionMenuUnpinLabel => 'Unpin chat';

  @override
  String get chatRowActionMenuArchiveLabel => 'Archive chat';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'Unarchive chat';

  @override
  String get messageActionMenuSaveLabel => 'Save';

  @override
  String get messageActionMenuUnsaveLabel => 'Unsave';

  @override
  String get roomScreenSaveLimitSnack =>
      'Too many saved here. Unsave one first';

  @override
  String get roomScreenSaveFailedSnack => 'Couldn’t save that';

  @override
  String get threadOverlaySaveLimitToast =>
      'Too many saved here. Unsave one first';

  @override
  String get threadOverlaySaveFailedToast => 'Couldn’t save that';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'only you can see the messages you save. A pinned message is the opposite: the whole room sees it.';

  @override
  String get roomInfoScreenOwnerBadgeNote =>
      'the small medal next to a name marks whoever created this room.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return 'Jump to saved message from $name';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return 'Unsave message from $name';
  }

  @override
  String get muteSheetTitle => 'Mute chat';

  @override
  String get muteSheetSubtitle => 'Pick what goes quiet, and for how long.';

  @override
  String get muteSheetNotificationsTitle => 'Notifications';

  @override
  String get muteSheetNotificationsSub => 'No banner, no sound';

  @override
  String get muteSheetBadgesTitle => 'Unread counts';

  @override
  String get muteSheetBadgesSub =>
      'No number on the chat, nothing added to the app icon';

  @override
  String get muteSheetDurationLabel => 'For how long';

  @override
  String get muteDurationHour => '1 hour';

  @override
  String get muteDurationEightHours => '8 hours';

  @override
  String get muteDurationWeek => '1 week';

  @override
  String get muteDurationAlways => 'Always';

  @override
  String get muteSheetConfirmButton => 'Mute';

  @override
  String get muteSheetSaveButton => 'Save';

  @override
  String get muteSheetUnmuteButton => 'Unmute';

  @override
  String get muteSummaryAll =>
      'Nothing from this chat reaches you: no notifications, no unread count.';

  @override
  String get muteSummaryNotificationsOnly =>
      'No notifications. The unread count keeps climbing.';

  @override
  String get muteSummaryBadgesOnly =>
      'No unread count. Notifications still come through.';

  @override
  String get muteSummaryNothingPicked => 'Pick at least one thing to silence.';

  @override
  String muteUntilSentence(String when) {
    return 'Until $when.';
  }

  @override
  String get muteUntilAlwaysSentence => 'Until you turn it back on.';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String get mutedBadgeLabel => 'MUTED';

  @override
  String get chatRowActionMenuMuteLabel => 'Mute chat';

  @override
  String get chatRowActionMenuUnmuteLabel => 'Unmute chat';

  @override
  String get roomInfoScreenMuteLabel => 'MUTE';

  @override
  String get roomInfoScreenNotMutedRow => 'Not muted';

  @override
  String get attachmentMenuLocationLabel => 'Location';

  @override
  String get locationSheetSendCurrent => 'Send current location';

  @override
  String get locationSheetSendCurrentDetail => 'Where you are right now';

  @override
  String get locationSheetLiveHeading => 'Share live';

  @override
  String get locationSheetLiveDetail => 'Stops on its own';

  @override
  String get locationShareFor15Minutes => 'For 15 minutes';

  @override
  String get locationShareFor1Hour => 'For 1 hour';

  @override
  String get locationShareFor8Hours => 'For 8 hours';

  @override
  String get locationBubbleOpenInMaps => 'Open in maps';

  @override
  String get locationBubbleLiveBadge => 'LIVE';

  @override
  String get locationBubbleEndedBadge => 'ENDED';

  @override
  String locationBubbleLiveUntil(String time) {
    return 'Live until $time';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return 'Live location ended at $time';
  }

  @override
  String get locationBubbleNoRecentUpdate => 'No recent update';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters m';
  }

  @override
  String get locationBubbleStopSharing => 'Stop sharing';

  @override
  String get locationBubbleUnavailable => 'Location unavailable';

  @override
  String get locationBubbleNoMapsApp => 'No maps app to open this in';

  @override
  String get locationBubbleCoordinatesCopied => 'Coordinates copied';

  @override
  String get locationCouldNotGetFix => 'Couldn’t get your location';

  @override
  String get locationCouldNotStartLiveShare => 'Couldn’t start live sharing';

  @override
  String get locationPermissionNeeded =>
      'Location access is needed to share where you are';

  @override
  String get locationPermissionBlockedTitle => 'Location access is off';

  @override
  String get locationPermissionBlockedBody =>
      'MonkeyHub can’t ask again from here. Turn on location access for MonkeyHub in Settings.';

  @override
  String get locationServicesOffTitle => 'Location services are off';

  @override
  String get locationServicesOffBody =>
      'Location is switched off for this device. Turn it on in Settings to share where you are.';

  @override
  String get locationOpenSettings => 'Open settings';

  @override
  String get locationBackgroundSheetTitle => 'If your phone restarts';

  @override
  String get locationBackgroundSheetBody =>
      'Your live share already keeps going when you leave MonkeyHub. Background access covers the rest: a restart, a force-quit, a phone that runs out of battery and comes back.';

  @override
  String get locationBackgroundSheetKeepRunning => 'Pick it back up';

  @override
  String get locationBackgroundSheetKeepRunningDetail =>
      'Your phone will ask you to allow this';

  @override
  String get locationBackgroundSheetAppOnly => 'Leave it stopped';

  @override
  String get locationBackgroundSheetAppOnlyDetail => 'Nothing else to allow';

  @override
  String get locationServiceNotificationTitle => 'Sharing your live location';

  @override
  String get locationServiceNotificationBody =>
      'Tap to open the chat, or Stop to end it now';

  @override
  String get childPolicyScreenLocationLabel => 'Location';

  @override
  String get childPolicyScreenLocationOnDesc =>
      'They can share where they are, including live for up to 8 hours';

  @override
  String get childPolicyScreenLocationOffDesc =>
      'They can’t share where they are';

  @override
  String get roomInfoScreenSavedMessagesLabel => 'SAVED MESSAGES';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      'only you can see these, and only from this room. your Saved Messages chat is separate.';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      'nothing saved yet. hold a message and choose SAVE.';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return 'Jump to saved message from $name';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return 'Unsave message from $name';
  }

  @override
  String get composerCaptureCameraModeLabel => 'camera';

  @override
  String get composerCaptureVoiceModeLabel => 'voice message';

  @override
  String get composerCaptureVideoNoteModeLabel => 'video note';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode. Swipe with two fingers or use the arrow keys to change mode.';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '$mode selected';
  }

  @override
  String get composerCaptureRecordingAnnouncement => 'Recording started';

  @override
  String get composerCaptureLockedAnnouncement =>
      'Recording locked. Hands free.';

  @override
  String get composerCaptureCancelledAnnouncement => 'Recording discarded';

  @override
  String get composerCaptureSentAnnouncement => 'Recording sent';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return 'Recording, $elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint =>
      'Hold to record, swipe to switch';

  @override
  String get composerCaptureTapForCameraHint =>
      'Tap for camera, swipe to switch';

  @override
  String get composerCaptureSlideToCancelHint => 'slide to cancel';

  @override
  String get composerCaptureReleaseToCancelHint => 'release to cancel';

  @override
  String get composerCaptureTapToSendHint => 'tap to send';

  @override
  String get composerCaptureSendingLabel => 'sending…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return '${seconds}s left';
  }

  @override
  String get composerCaptureCancelLabel => 'discard recording';

  @override
  String get composerCaptureSendLabel => 'send recording';

  @override
  String get composerCaptureLockLabel => 'slide up to lock recording';

  @override
  String get composerCaptureMicPermissionTitle => 'Microphone needed';

  @override
  String get composerCaptureMicPermissionBody =>
      'MonkeyHub needs your microphone to record a voice message. Turn it on in Settings and try again.';

  @override
  String get composerCaptureCameraPermissionTitle => 'Camera needed';

  @override
  String get composerCaptureCameraPermissionBody =>
      'MonkeyHub needs your camera and microphone to record a video note. Turn them on in Settings and try again.';

  @override
  String get composerCaptureRestrictedBody =>
      'Recording is turned off by a restriction on this device.';

  @override
  String get composerCaptureOpenSettingsLabel => 'Open Settings';

  @override
  String get composerCaptureUnavailableSnack =>
      'Recording isn\'t available on this device.';

  @override
  String get composerCaptureInterruptedSnack => 'Recording stopped.';

  @override
  String get composerCaptureStorageSnack =>
      'Couldn\'t save the recording. Check your free space.';

  @override
  String get videoNoteMessagePlayLabel => 'Play video note';

  @override
  String get videoNoteMessagePauseLabel => 'Pause video note';

  @override
  String get videoNoteMessageLoadingLabel => 'Loading video note';

  @override
  String get videoNoteMessageUnavailableLabel => 'Video note unavailable';

  @override
  String get videoNoteMessageRetryLabel => 'Retry video note';

  @override
  String get videoNoteMessageRetryHint => 'Tap to retry';

  @override
  String get videoNoteMessageDiscardLabel => 'Discard video note';

  @override
  String get attachmentMenuVideoNoteLabel => 'Video note';

  @override
  String get cameraScreenPhotoModeLabel => 'Photo';

  @override
  String get cameraScreenVideoModeLabel => 'Video';

  @override
  String get cameraScreenStartRecordingLabel => 'Start recording';

  @override
  String get cameraScreenStopRecordingLabel => 'Stop recording';

  @override
  String get cameraScreenVideoFailedSnack => 'Couldn\'t record that video.';

  @override
  String get scheduleSheetTitle => 'Schedule message';

  @override
  String get scheduleSheetSubtitle => 'Write it now. It goes out when you say.';

  @override
  String get scheduleSheetWhenLabel => 'When';

  @override
  String get schedulePresetInAnHour => 'In 1 hour';

  @override
  String get schedulePresetInEightHours => 'In 8 hours';

  @override
  String get schedulePresetTomorrowMorning => 'Tomorrow morning';

  @override
  String get schedulePresetThisMorning => 'This morning';

  @override
  String get schedulePresetInAWeek => 'In 1 week';

  @override
  String get scheduleSheetCustomChip => 'Pick a date';

  @override
  String get scheduleSheetConfirmButton => 'Schedule';

  @override
  String get scheduleSheetSaveButton => 'Save';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'Sends $when';
  }

  @override
  String scheduleWhenToday(String time) {
    return 'today at $time';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return 'tomorrow at $time';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return '$date at $time';
  }

  @override
  String get scheduleTimePickerTitle => 'Pick a date & time';

  @override
  String get scheduleTimePickerBack => 'Quick picks';

  @override
  String get scheduleTimePickerToday => 'Today';

  @override
  String get scheduleTimePickerTomorrow => 'Tomorrow';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SCHEDULED',
      one: '1 SCHEDULED',
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
      other: '$count messages waiting to send. Tap to see them.',
      one: '1 message waiting to send. Tap to see it.',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => 'NEEDS YOU';

  @override
  String get scheduledListTitle => 'Scheduled';

  @override
  String get scheduledListSubtitle => 'Only you can see these until they send.';

  @override
  String get scheduledListEmpty => 'Nothing waiting to send here.';

  @override
  String get scheduledListSendNow => 'Send now';

  @override
  String get scheduledListChangeTime => 'Change time';

  @override
  String get scheduledListEdit => 'Edit text';

  @override
  String get scheduledListDelete => 'Delete';

  @override
  String get scheduledListSending => 'Sending…';

  @override
  String get scheduledListFailedTitle => 'Couldn’t send';

  @override
  String get scheduledListRetry => 'Try again';

  @override
  String get scheduleErrorOutOfRange =>
      'Pick a time between two minutes and a year from now.';

  @override
  String get scheduleErrorTooMany =>
      'Too many messages waiting here. Send or delete some first.';

  @override
  String get scheduleErrorNotInEphemeral =>
      'Messages here fade on their own, so they can’t be scheduled.';

  @override
  String get scheduleErrorNotMember => 'You’re not in this chat any more.';

  @override
  String get scheduleErrorBlocked => 'You’ll need to unblock them first.';

  @override
  String get scheduleErrorGeneric => 'That didn’t work. Try again.';

  @override
  String get scheduleEditTitle => 'Edit message';

  @override
  String get composerScheduleAction => 'Schedule this message';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages waiting to send',
      one: '1 message waiting to send',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => 'Show as';

  @override
  String get scheduledIndicatorPill => 'Pill';

  @override
  String get scheduledIndicatorBadge => 'Badge';

  @override
  String get scheduledIndicatorBoth => 'Both';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages already waiting',
      one: '1 message already waiting',
      zero: 'Nothing waiting to send',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => 'How these show up';

  @override
  String get scheduledIndicatorPillSub =>
      'A bar above the message box. Tap it to see them.';

  @override
  String get scheduledIndicatorBadgeSub =>
      'A count on the send button. Nothing shows until you start typing.';

  @override
  String get scheduledIndicatorBothSub =>
      'The bar, plus the count while you type.';

  @override
  String get scheduledBack => 'Back';

  @override
  String get serverScreenTitle => 'server.';

  @override
  String get serverScreenSubtitle => 'Where your account and messages live';

  @override
  String get serverOnboardingTitle => 'pick a server.';

  @override
  String get serverOnboardingSubtitle =>
      'This build didn\'t come with one. Point it at yours';

  @override
  String get serverStatusConnected => 'Connected';

  @override
  String get serverStatusDisconnected => 'Not connected';

  @override
  String get serverBadgeDefault => 'Default';

  @override
  String get serverBadgeSelfHosted => 'Self-hosted';

  @override
  String get serverNoneConfigured => 'No server yet';

  @override
  String get serverActiveNowLabel => 'In use';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'The server this app came with.';

  @override
  String get serverChoiceOwn => 'Your own server';

  @override
  String get serverChoiceOwnSub => 'A Convex backend you run yourself.';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => 'Paste';

  @override
  String get serverProblemMalformed => 'That isn\'t a web address.';

  @override
  String get serverProblemBadScheme => 'Start it with https:// or http://.';

  @override
  String get serverProblemNoHost =>
      'Add your server\'s address after https://.';

  @override
  String get serverProblemCredentials =>
      'Take the username and password out of the address.';

  @override
  String get serverInsecureTitle => 'Not encrypted';

  @override
  String get serverInsecureBody =>
      'Phones block plain http, so this address won\'t connect on iOS or Android. Use https, or reach your server through a tunnel.';

  @override
  String get serverTestCta => 'Test connection';

  @override
  String get serverTestingLabel => 'Testing…';

  @override
  String get serverCheckReachable => 'Something answered';

  @override
  String get serverCheckConvex => 'It\'s a Convex server';

  @override
  String get serverCheckApp => 'It\'s running MonkeyHub';

  @override
  String get serverResultUnreachable => 'Nothing answered at that address.';

  @override
  String get serverResultNotConvex =>
      'Something answered, but it isn\'t a Convex server.';

  @override
  String get serverResultNotThisApp =>
      'That\'s a Convex server, but MonkeyHub isn\'t deployed on it.';

  @override
  String get serverResultServerError =>
      'The server answered, but with an error.';

  @override
  String get serverResultReady => 'Ready to connect.';

  @override
  String get serverConnectCta => 'Connect';

  @override
  String get serverConnectAnywayCta => 'Connect anyway';

  @override
  String get serverAlreadyConnectedCta => 'Already connected';

  @override
  String get serverUseDefaultCta => 'Use the default server';

  @override
  String get serverChangeCta => 'Change server';

  @override
  String get serverAdvancedLabel => 'Advanced';

  @override
  String get serverSiteUrlExplain =>
      'Most servers answer everything on one address. Fill this in only if yours serves HTTP actions somewhere else.';

  @override
  String get serverSiteUrlHint => 'Same as above';

  @override
  String get serverSectionRecent => 'Recent';

  @override
  String get serverRecentForget => 'Forget this server';

  @override
  String get serverSwitchWarningTitle => 'Switching signs you out';

  @override
  String get serverSwitchWarningBody =>
      'Accounts and chats belong to one server. This device signs out, clears what it downloaded, and starts fresh. Nothing is deleted on either server.';

  @override
  String get serverSwitchRolledBackTitle => 'Couldn\'t connect';

  @override
  String serverSwitchRolledBackBody(String host) {
    return '$host didn\'t answer, so nothing changed. You\'ll need to sign in again.';
  }

  @override
  String get serverSwitchStrandedBody =>
      'Neither server would connect. Check the address and try again.';

  @override
  String get serverSwitchRefusedBody =>
      'This device is set up for a child and can\'t change servers.';

  @override
  String serverChipSemantics(String server) {
    return 'Change server. Currently $server.';
  }

  @override
  String get serverValueDefault => 'Default';

  @override
  String get settingsScreenRowServer => 'SERVER';

  @override
  String get settingsScreenSectionAdvanced => 'ADVANCED';

  @override
  String get serverSwitchingLabel => 'Switching server…';

  @override
  String get serverRoleExplainAction => 'What does this mean?';

  @override
  String get serverBadgeRibbonHomeserver => 'HOME';

  @override
  String get serverBadgeRibbonSelfHosted => 'SELF';

  @override
  String get serverBadgeHomeserver => 'Serving from homeserver';

  @override
  String get serverBadgeHomeserverSemantics =>
      'Serving from the homeserver. Tap for details.';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'Self-hosted server: $server. Tap for details.';
  }

  @override
  String get serverRoleHomeserverTitle => 'Running on the homeserver';

  @override
  String get serverRoleHomeserverBody =>
      'The people who run MonkeyHub have moved traffic to their home server for a while. Everything works the same way. This is deliberate, not a fault.';

  @override
  String get serverRoleHomeserverWarnData =>
      'Anything you send while this is up may not be here after traffic moves back.';

  @override
  String get serverRoleHomeserverWarnSpeed =>
      'A home connection is slower than the usual one, so things may lag.';

  @override
  String get serverRoleHomeserverWarnAuto =>
      'You do not need to do anything. The app moves back on its own.';

  @override
  String get serverRoleSelfHostedTitle => 'Your own server';

  @override
  String get serverRoleSelfHostedBody =>
      'This device is pointed at a server you run. Change it under Settings › Advanced › Server.';

  @override
  String get serverValueHomeserver => 'Homeserver, for now';

  @override
  String get serverChoiceCloudSubHomeserver =>
      'Being served from the homeserver for a while.';

  @override
  String get serverDirectiveChangedToast =>
      'Your server changed. Reconnecting…';

  @override
  String get loginScreenSignInWithPhone => 'sign in with your phone';

  @override
  String get loginScreenUsePasswordInstead => 'Use a password instead';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      'Open MonkeyHub on your phone, go to your profile, tap “Scan to sign in” and point the camera here, or type the code below.';

  @override
  String get deviceLoginScreenWaiting => 'Waiting for approval…';

  @override
  String get deviceLoginScreenApproved => 'Approved. Signing you in…';

  @override
  String get deviceLoginScreenDenied => 'Sign-in request denied on your phone';

  @override
  String get deviceLoginScreenGenericError =>
      'Something went wrong. Try a new code';

  @override
  String get profileScreenScanToSignInLabel => 'Scan to sign in';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro =>
      'Point your camera at the code shown on your computer, or type it in below.';

  @override
  String get deviceLoginScanScreenScanButtonLabel => 'Scan code';

  @override
  String get deviceLoginScanScreenConfirmTitle => 'Sign in on this device?';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return '$deviceInfo wants to sign in as you. Only approve this if it’s you, right now.';
  }

  @override
  String get deviceLoginScanScreenApproveButton => 'Approve';

  @override
  String get deviceLoginScanScreenDenyButton => 'Deny';

  @override
  String get deviceLoginScanScreenSuccess => 'Signed in on your other device';

  @override
  String get deviceLoginScanScreenGenericError => 'Couldn’t approve. Try again';

  @override
  String get authErrorDeviceLoginInvalid => 'That code isn’t right.';

  @override
  String get authErrorDeviceLoginExpired =>
      'That code has expired. Get a new one on the other device.';

  @override
  String get deviceLoginScanScreenDeniedConfirmation =>
      'Sign-in request denied';

  @override
  String get roomAdminRoleAdmin => 'Admin';

  @override
  String get roomAdminActionViewProfile => 'View profile';

  @override
  String get roomAdminActionPromote => 'Make admin';

  @override
  String get roomAdminActionPromoteSub =>
      'They can invite, remove members and edit the group';

  @override
  String get roomAdminActionDemote => 'Remove admin';

  @override
  String get roomAdminActionDemoteSub => 'They stay in the group as a member';

  @override
  String get roomAdminActionTransfer => 'Transfer ownership';

  @override
  String get roomAdminActionTransferSub => 'You stay on as an admin';

  @override
  String get roomAdminActionRemove => 'Remove from group';

  @override
  String get roomAdminAddFriendsRow => 'Add friends';

  @override
  String get roomAdminInviteLinkRow => 'Invite link';

  @override
  String get roomAdminJoinRequestsRow => 'Join requests';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return 'Hand the group to $name?';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      'They become the owner and can delete the group. You stay on as an admin, and only they can hand it back.';

  @override
  String get roomAdminTransferConfirmCta => 'Transfer';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return 'Remove $name?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'They lose access to the group and everything in it. They can be invited back, or come back through the invite link.';

  @override
  String get roomAdminRemoveConfirmCta => 'Remove';

  @override
  String get roomAdminGenericError => 'That didn\'t work. Try again.';

  @override
  String get roomAdminErrorNotMember => 'You\'re not in this group any more.';

  @override
  String get roomAdminErrorNotAdmin => 'Only admins can do that.';

  @override
  String get roomAdminErrorNotOwner => 'Only the group\'s owner can do that.';

  @override
  String get roomAdminErrorNotGroup =>
      'There\'s nothing to manage in a direct chat.';

  @override
  String get roomAdminErrorOwnerImmutable =>
      'The owner\'s role can only change by transferring the group.';

  @override
  String get roomAdminErrorInvitesLocked =>
      'Only admins can invite people to this group.';

  @override
  String get roomInviteSheetTitle => 'Invite link';

  @override
  String get roomInviteSheetBlurb =>
      'One link and one code, and they\'re the same thing. Make a new one and the old one stops working immediately.';

  @override
  String get roomInviteNoLinkYet => 'This group has no invite link yet.';

  @override
  String get roomInviteCreateButton => 'Create link';

  @override
  String get roomInviteRegenerateButton => 'New link';

  @override
  String get roomInviteRevokeButton => 'Revoke link';

  @override
  String get roomInviteCopyLink => 'Copy link';

  @override
  String get roomInviteCopyCode => 'Copy code';

  @override
  String get roomInviteShare => 'Share';

  @override
  String get roomInviteLinkCopied => 'Link copied.';

  @override
  String get roomInviteCodeCopied => 'Code copied.';

  @override
  String get roomInviteRegenerateHeadline => 'Make a new link?';

  @override
  String get roomInviteRegenerateBody =>
      'The current link and code stop working straight away, everywhere they\'ve been shared. Anyone already in the group stays in.';

  @override
  String get roomInviteRegenerateConfirm => 'New link';

  @override
  String get roomInviteRevokeHeadline => 'Revoke this link?';

  @override
  String get roomInviteRevokeBody =>
      'Nobody new can join by link until you make another one. Anyone already in the group stays in.';

  @override
  String get roomInviteRevokeConfirm => 'Revoke';

  @override
  String get roomInviteLimitsLabel => 'Limits';

  @override
  String get roomInviteExpiryLabel => 'Expires after';

  @override
  String get roomInviteMaxUsesLabel => 'Number of uses';

  @override
  String get roomInviteNeverExpires => 'Never';

  @override
  String get roomInviteUnlimited => 'Any';

  @override
  String roomInviteExpiryHours(Object count) {
    return '${count}h';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '${count}d';
  }

  @override
  String get roomInviteLimitsApplyToNew =>
      'These apply to the link you create.';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      'These apply to the next link. The one above keeps the limits it was made with.';

  @override
  String get roomInvitePermissionsLabel => 'Permissions';

  @override
  String get roomInviteMembersCanInviteLabel => 'Members can invite friends';

  @override
  String get roomInviteMembersCanInviteSub =>
      'Turn this off and only admins can bring people in';

  @override
  String get roomInviteApprovalLabel => 'Approve each join';

  @override
  String get roomInviteApprovalSub =>
      'People with the link ask first, and an admin says yes or no';

  @override
  String roomInviteUsesCount(Object count) {
    return 'Used $count times';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$used of $max uses';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return 'Expires $date';
  }

  @override
  String get roomInviteDeadExpired => 'This link has expired. Make a new one.';

  @override
  String get roomInviteDeadExhausted =>
      'This link has run out of uses. Make a new one.';

  @override
  String get roomInviteDeadRevoked => 'This link was revoked.';

  @override
  String get roomInviteDeadGeneric => 'This link no longer works.';

  @override
  String get roomInviteFriendsTitle => 'Add friends';

  @override
  String get roomInviteFriendsBlurb =>
      'They\'ll get an invite and can accept or decline.';

  @override
  String get roomInviteFriendsSearchHint => 'Search friends';

  @override
  String get roomInviteFriendsInviteButton => 'Invite';

  @override
  String get roomInviteFriendsSent => 'Invited';

  @override
  String get roomInviteFriendsEmpty =>
      'Everyone you\'re friends with is already here or already invited.';

  @override
  String get roomInviteFriendsNoMatch => 'No friends match that.';

  @override
  String get roomInviteFriendsDone => 'Done';

  @override
  String get roomJoinRequestsTitle => 'Join requests';

  @override
  String get roomJoinRequestsBlurb =>
      'These people used the invite link. They can\'t see anything in the group until you say yes.';

  @override
  String get roomJoinRequestsEmpty => 'Nobody\'s waiting.';

  @override
  String get roomJoinRequestsApprove => 'LET IN';

  @override
  String get roomJoinRequestsReject => 'NO';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return 'INVITED · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian => 'Waiting on a parent';

  @override
  String get roomInfoScreenInviteWithdraw => 'WITHDRAW';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return 'From $inviter · $members members';
  }

  @override
  String get roomInvitationCardJoin => 'Join';

  @override
  String get discoverScreenJoinByCodeTitle => 'Join with a code';

  @override
  String get discoverScreenJoinByCodeSubtitle =>
      'Open a group someone shared with you';

  @override
  String get joinInviteTitle => 'Join a group';

  @override
  String get joinInviteBack => 'Back';

  @override
  String get joinInviteCodeBlurb =>
      'Enter the code someone shared with you. A full invite link works here too.';

  @override
  String get joinInviteCodeLabel => 'Invite code';

  @override
  String get joinInviteCodeHint => 'Paste the link, or type the code';

  @override
  String get joinInviteCodeInvalid => 'That doesn\'t look like an invite code.';

  @override
  String get joinInviteLookupButton => 'Continue';

  @override
  String get joinInviteLookupFailed =>
      'Couldn\'t check that code. Check your connection and try again.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count members';
  }

  @override
  String get joinInviteJoinButton => 'Join group';

  @override
  String get joinInviteRequestButton => 'Ask to join';

  @override
  String get joinInviteOpenNote =>
      'You\'ll be able to see the group\'s messages once you join.';

  @override
  String get joinInviteApprovalNote =>
      'An admin has to say yes before you can see anything in here.';

  @override
  String get joinInviteOpenRoom => 'Open group';

  @override
  String get joinInvitePendingHeadline => 'Waiting for an admin';

  @override
  String get joinInvitePendingBody =>
      'You\'ll get a notification as soon as somebody answers.';

  @override
  String get joinInviteBadLinkHeadline => 'This invite doesn\'t work';

  @override
  String get joinInviteBadLinkBody => 'Check the code, or ask for a new link.';

  @override
  String get joinInviteExpiredHeadline => 'This invite has expired';

  @override
  String get joinInviteExpiredBody =>
      'Ask whoever invited you for a fresh link.';

  @override
  String get joinInviteExhaustedHeadline => 'This invite is used up';

  @override
  String get joinInviteExhaustedBody =>
      'It was set to work a limited number of times. Ask for a new one.';

  @override
  String get joinInviteRevokedHeadline => 'This invite was replaced';

  @override
  String get joinInviteRevokedBody =>
      'An admin made a new link. Ask them for the current one.';

  @override
  String get joinInviteWrongServerHeadline =>
      'This invite is for another server';

  @override
  String joinInviteWrongServerBody(Object host) {
    return 'It belongs to $host. Your account lives on a different server, so this group isn\'t reachable from here.';
  }

  @override
  String get roomInviteErrorNotFound =>
      'That invite code doesn\'t match anything.';

  @override
  String get roomInviteErrorRevoked =>
      'That invite was replaced. Ask for the current link.';

  @override
  String get roomInviteErrorExpired => 'That invite has expired.';

  @override
  String get roomInviteErrorExhausted => 'That invite has been used up.';

  @override
  String get roomInviteErrorAlreadyMember => 'They\'re already in this group.';

  @override
  String get roomInviteErrorAlreadyInvited => 'They\'ve already been invited.';

  @override
  String get roomInviteErrorSelf => 'You\'re already in this group.';

  @override
  String get roomInviteErrorInvitationGone => 'That invite is no longer there.';

  @override
  String get roomInviteErrorRequestPending =>
      'You\'ve already asked to join. An admin will answer.';

  @override
  String get roomInviteErrorRequestGone =>
      'Somebody already answered that request.';

  @override
  String get roomInviteErrorRoomPrivate =>
      'This group can only be joined with an invite.';

  @override
  String get roomInviteErrorInvalidLimits => 'Those limits aren\'t valid.';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$child wants to invite $other to $room';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$other invited $child to $room';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      'The invite goes out, and the other person still decides.';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$child will see the invite and can accept or decline. Approving also lets them into that group if they accept.';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      'You can\'t remove yourself. Leave the group instead.';

  @override
  String get roomAdminActionMessage => 'Message';

  @override
  String get roomAdminActionVoiceCall => 'Voice call';

  @override
  String get roomAdminActionVideoCall => 'Video call';

  @override
  String get roomAdminYouSuffix => 'You';

  @override
  String get roomInfoScreenSetPasswordButton => 'SET';

  @override
  String get roomInfoScreenPasswordSetSnackbar => 'Password set.';

  @override
  String get roomInfoScreenPasswordSetState => 'Password on';

  @override
  String get roomInfoScreenPasswordUnsetState => 'No password';

  @override
  String get roomInfoScreenPasswordCancel => 'Cancel';

  @override
  String get roomInfoScreenEditSave => 'Save';

  @override
  String get roomInfoScreenEditCancel => 'Cancel';

  @override
  String get roomInviteRotatedToast =>
      'New link created. The old one no longer works.';

  @override
  String get roomInviteRevokedToast => 'Invite link revoked.';

  @override
  String get newChatMenuTitle => 'New chat';

  @override
  String get newChatMenuCreateTitle => 'Create a room';

  @override
  String get newChatMenuCreateSub => 'Start a group and invite people';

  @override
  String get newChatMenuJoinTitle => 'Join with a code';

  @override
  String get newChatMenuJoinSub => 'Open a group shared with you';

  @override
  String get shareSheetTitle => 'Share to';

  @override
  String get shareSheetSuggestedHeading => 'Suggested';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files are over the $size limit and were left out',
      one: '1 file is over the $size limit and was left out',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return 'Send to $title';
  }

  @override
  String get settingsScreenRowSpeakerColors => 'SPEAKER COLOURS';

  @override
  String get settingsScreenValueSpeakerOff => 'Off';

  @override
  String get settingsScreenValueSpeakerName => 'Names';

  @override
  String get settingsScreenValueSpeakerBubble => 'Names + bubbles';

  @override
  String get speakerColorScreenTitle => 'speaker colours.';

  @override
  String get speakerColorScreenSubtitle =>
      'who said that, without reading the name';

  @override
  String get speakerColorScreenOffLabel => 'OFF';

  @override
  String get speakerColorScreenOffDescription =>
      'everyone in the room writes in the same ink.';

  @override
  String get speakerColorScreenNameLabel => 'NAMES';

  @override
  String get speakerColorScreenNameDescription =>
      'each person keeps a colour of their own, on their name and around their face.';

  @override
  String get speakerColorScreenBubbleLabel => 'BUBBLES';

  @override
  String get speakerColorScreenBubbleDescription =>
      'the colour carries into their messages too, so a run of five still says who wrote it.';

  @override
  String get roomInfoScreenSpeakerColorsLabel => 'COLOURS';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => 'Automatic';

  @override
  String get roomInfoScreenSpeakerColorsCustom => 'Custom';

  @override
  String get roomColorsScreenTitle => 'who\'s who.';

  @override
  String get roomColorsScreenSubtitle => 'the colour each person speaks in';

  @override
  String get roomColorsScreenOffTitle => 'speaker colours are off';

  @override
  String get roomColorsScreenOffBody =>
      'everyone is drawn in the same ink right now. turn it on and each person here gets one of their own.';

  @override
  String get roomColorsScreenOffAction => 'TURN ON';

  @override
  String get roomColorsScreenOffHint =>
      'applies to every room, not just this one. also in settings.';

  @override
  String get roomColorsScreenAutoChip => 'AUTO';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return 'shared with $name';
  }

  @override
  String get roomColorsScreenResetAll => 'BACK TO AUTOMATIC';

  @override
  String get roomColorsScreenLimitToast =>
      'That\'s as many colours as one room can pin.';

  @override
  String get roomColorsScreenFailedToast => 'Couldn\'t save that colour.';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return 'Colour $index';
  }

  @override
  String get devicesScreenTitle => 'YOUR DEVICES';

  @override
  String get devicesScreenSubtitle =>
      'Everywhere you\'ve signed in to this account.';

  @override
  String get devicesScreenLoading => 'checking…';

  @override
  String get devicesScreenLoadFailed => 'couldn’t load your devices';

  @override
  String get devicesScreenThisDevice => 'THIS DEVICE';

  @override
  String get devicesScreenActiveNow => 'active now';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications =>
      'notifications aren’t reaching this one';

  @override
  String get devicesScreenRemove => 'REMOVE';

  @override
  String get devicesScreenRemoveTitle => 'REMOVE THIS DEVICE?';

  @override
  String devicesScreenRemoveBody(Object name) {
    return '$name will be signed out and will stop receiving notifications. Whoever has it will have to sign in again.';
  }

  @override
  String get devicesScreenRemoveConfirm => 'REMOVE';

  @override
  String get devicesScreenRemoveAll => 'Remove all other devices';

  @override
  String get devicesScreenRemoveAllTitle => 'REMOVE ALL OTHER DEVICES?';

  @override
  String get devicesScreenRemoveAllBody =>
      'They\'ll all be signed out and will stop receiving notifications. Only this device stays signed in.';

  @override
  String get devicesScreenRemoveAllConfirm => 'REMOVE ALL';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices removed',
      one: '1 device removed',
      zero: 'no other devices to remove',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed => 'couldn’t remove that device';

  @override
  String get devicesScreenFootnote =>
      'Removing a device signs it out and stops its notifications. It takes effect immediately: the next thing that device tries to do will send it back to the login screen.';

  @override
  String get attachmentMenuPollLabel => 'Poll';

  @override
  String get attachmentMenuChecklistLabel => 'Checklist';

  @override
  String get attachmentMenuEventLabel => 'Event';

  @override
  String get interactionKindPoll => 'Poll';

  @override
  String get interactionKindQuiz => 'Quiz';

  @override
  String get interactionKindChecklist => 'Checklist';

  @override
  String get interactionKindEvent => 'Event';

  @override
  String get interactionBadgeAnonymous => 'Anonymous';

  @override
  String get interactionBadgeMultiple => 'Multi';

  @override
  String get interactionBadgeClosed => 'Closed';

  @override
  String interactionPercent(int percent) {
    return '$percent%';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names +$count';
  }

  @override
  String get interactionSeeWhoAnswered => 'See who answered';

  @override
  String interactionRemoveItem(String label) {
    return 'Remove $label';
  }

  @override
  String interactionChoiceSemantics(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return '$label, $_temp0';
  }

  @override
  String get interactionAddItemHint => 'Add an item';

  @override
  String get interactionRetract => 'Retract';

  @override
  String get interactionClose => 'Close';

  @override
  String interactionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return '$_temp0';
  }

  @override
  String interactionRsvpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$done of $total done';
  }

  @override
  String get interactionNoAnswers => 'No answers';

  @override
  String get interactionBeFirst => 'Be the first to answer';

  @override
  String interactionFinalResults(String count) {
    return '$count · final';
  }

  @override
  String get interactionQuizRight => 'Correct';

  @override
  String get interactionQuizWrong => 'Not quite';

  @override
  String interactionEventPast(String when) {
    return '$when · already happened';
  }

  @override
  String get interactionRespondentsTitlePoll => 'Who voted';

  @override
  String get interactionRespondentsTitleChecklist => 'Who ticked';

  @override
  String get interactionRespondentsTitleEvent => 'Who replied';

  @override
  String get interactionRespondentsFailed => 'Couldn\'t load who answered.';

  @override
  String get interactionRespondentsEmpty => 'Nobody has answered yet.';

  @override
  String get interactionFilterAll => 'All';

  @override
  String get interactionRsvpGoing => 'Going';

  @override
  String get interactionRsvpMaybe => 'Maybe';

  @override
  String get interactionRsvpNo => 'Can\'t';

  @override
  String get interactionComposePollTitle => 'New poll';

  @override
  String get interactionComposePollTagline => 'Ask the room';

  @override
  String get interactionComposeChecklistTitle => 'New checklist';

  @override
  String get interactionComposeChecklistTagline => 'A list everyone can tick';

  @override
  String get interactionComposeEventTitle => 'New event';

  @override
  String get interactionComposeEventTagline => 'See who is coming';

  @override
  String get interactionComposeQuestionLabel => 'Question';

  @override
  String get interactionComposeQuestionHint => 'What are you asking?';

  @override
  String get interactionComposeTitleLabel => 'Title';

  @override
  String get interactionComposeTitleHint => 'What is this list for?';

  @override
  String get interactionComposeEventNameLabel => 'Event';

  @override
  String get interactionComposeEventNameHint => 'What\'s happening?';

  @override
  String get interactionComposeOptionsLabel => 'Options';

  @override
  String get interactionComposeItemsLabel => 'Items';

  @override
  String interactionComposeOptionHint(int index) {
    return 'Option $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return 'Item $index';
  }

  @override
  String get interactionComposeAddOption => 'Add option';

  @override
  String get interactionComposeAddItem => 'Add item';

  @override
  String get interactionComposeRemoveRow => 'Remove';

  @override
  String get interactionComposeMarkCorrect => 'Mark as the correct answer';

  @override
  String get interactionComposeMultipleTitle => 'Multiple answers';

  @override
  String get interactionComposeMultipleSub => 'Pick more than one';

  @override
  String get interactionComposeAnonymousTitle => 'Anonymous';

  @override
  String get interactionComposeAnonymousOffSub => 'Everyone sees who voted';

  @override
  String get interactionComposeAnonymousOnSub => 'Nobody sees who voted';

  @override
  String get interactionComposeQuizTitle => 'Quiz mode';

  @override
  String get interactionComposeQuizSub => 'One right answer, no changing it';

  @override
  String get interactionComposeExplanationLabel => 'Explanation';

  @override
  String get interactionComposeExplanationHint =>
      'Shown after answering (optional)';

  @override
  String get interactionComposeOthersMayCheckTitle => 'Anyone can tick';

  @override
  String get interactionComposeOthersMayCheckSub => 'Not just you';

  @override
  String get interactionComposeOthersMayAddTitle => 'Anyone can add';

  @override
  String get interactionComposeOthersMayAddSub => 'The list can grow later';

  @override
  String get interactionComposeWhenLabel => 'When';

  @override
  String get interactionComposePickStart => 'Pick a start';

  @override
  String get interactionComposePickEnd => 'Add an end (optional)';

  @override
  String get interactionComposePlaceLabel => 'Place';

  @override
  String get interactionComposePlaceHint => 'Where? (optional)';

  @override
  String get interactionComposeSendPoll => 'Send poll';

  @override
  String get interactionComposeSendChecklist => 'Send checklist';

  @override
  String get interactionComposeSendEvent => 'Send event';

  @override
  String get interactionComposeErrorPrompt => 'Say what you\'re asking first.';

  @override
  String interactionComposeErrorOptions(int count) {
    return 'A poll needs at least $count options.';
  }

  @override
  String get interactionComposeErrorItems =>
      'A checklist needs at least one item.';

  @override
  String get interactionComposeErrorAnswer =>
      'Mark which option is the right one.';

  @override
  String get interactionComposeErrorWhen => 'Pick when it starts.';

  @override
  String get interactionComposeErrorEnd =>
      'The end has to come after the start.';

  @override
  String get interactionSendFailed => 'That didn\'t send.';

  @override
  String get interactionRefused => 'That didn\'t go through.';

  @override
  String get messageReceiptsScreenTitle => 'Message info';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$read of $total read';
  }

  @override
  String get messageReceiptsEmptyState => 'Nobody else is in this room yet';

  @override
  String get messageReceiptsSectionRead => 'Read';

  @override
  String get messageReceiptsSectionDelivered => 'Delivered';

  @override
  String get messageReceiptsSectionSent => 'Sent';

  @override
  String get messageReceiptsSectionHidden => 'No receipts';

  @override
  String get messageReceiptsStateHidden => 'Not shared';

  @override
  String get messageReceiptsStateWaiting => 'Waiting';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name read this $day at $time';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name received this $day at $time';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name hasn’t received this yet';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name doesn’t share read receipts';
  }

  @override
  String get companionsScreenTitle => 'companions.';

  @override
  String get companionsScreenSubtitle =>
      'helpers that live on this phone and never phone home';

  @override
  String get companionSebastianTagline => 'Translates messages';

  @override
  String get companionSebastianBlurb =>
      'Sebastian reads a message written in another language and tells you what it says, here on your phone, with nothing sent anywhere.';

  @override
  String get companionMarloweTagline => 'General help';

  @override
  String get companionMarloweBlurb =>
      'Marlowe handles everything that isn\'t translation. Pick a brain now, and the skills will arrive around it.';

  @override
  String get companionAssuranceOnDevice => 'Runs entirely on this device';

  @override
  String get companionAssurancePrivate =>
      'Your messages never leave your phone';

  @override
  String get companionAssuranceOffline => 'Works with no signal';

  @override
  String companionInstallAction(Object size) {
    return 'Install · $size';
  }

  @override
  String get companionInstallOneTime =>
      'One-time download, kept until you remove it';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$received of $total';
  }

  @override
  String get companionInstallQueued => 'Waiting for another download to finish';

  @override
  String get companionInstallCancel => 'Cancel';

  @override
  String get companionInstallRetry => 'Try again';

  @override
  String companionInstallReady(Object name) {
    return '$name is ready';
  }

  @override
  String get companionInstallFailedNetwork =>
      'The download couldn\'t finish. Check your connection and try again.';

  @override
  String get companionInstallFailedStorage =>
      'There isn\'t enough space on this device. Free some up and try again.';

  @override
  String get companionInstallFailedUnknown => 'The download couldn\'t finish.';

  @override
  String get companionUnsupportedPlatform =>
      'Companions aren\'t available in this version of the app yet.';

  @override
  String companionBrainNeedsMemory(String size) {
    return 'Needs $size of memory';
  }

  @override
  String get sebastianTierSeniorDetail => 'Sharper translations';

  @override
  String get sebastianTierJuniorDetail => 'Runs on any phone';

  @override
  String get sebastianLanguageUnlisted =>
      'Not one of his languages, so expect rough results';

  @override
  String get companionStatusNotInstalled => 'Not installed';

  @override
  String get companionStatusOff => 'Off';

  @override
  String companionStatusTranslatingInto(Object language) {
    return 'Translating into $language';
  }

  @override
  String get companionStatusNoBrain => 'Nothing downloaded yet';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads ready',
      one: '1 download ready',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty =>
      'Nothing downloaded. Companions are using no space';

  @override
  String companionStorageUsed(Object size) {
    return 'Companions are using $size';
  }

  @override
  String get companionSectionGeneral => 'General';

  @override
  String get companionSectionStorage => 'Storage';

  @override
  String get companionBrainRemove => 'Remove';

  @override
  String companionBrainRemoveTitle(Object name) {
    return 'REMOVE $name?';
  }

  @override
  String companionRemoveTitle(Object name) {
    return 'REMOVE $name?';
  }

  @override
  String companionRemoveMessage(Object size) {
    return 'This frees $size. You can download it again at any time.';
  }

  @override
  String get companionRemoveConfirm => 'Remove';

  @override
  String get sebastianEnableLabel => 'Let Sebastian translate';

  @override
  String get sebastianEnableDetail =>
      'Turn off to stop him without deleting the download';

  @override
  String get sebastianLanguageSection => 'Translate into';

  @override
  String get sebastianLanguageFollowApp => 'Same as the app';

  @override
  String sebastianBrainDetail(Object size) {
    return 'On this device · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count translations kept',
      one: '1 translation kept',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => 'Clear';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe can\'t do anything yet; the skills are still on the way. What you can do now is get a brain ready, so nothing is waiting on a download when they land.';

  @override
  String get marloweBrainsSection => 'Brain';

  @override
  String get marloweBrainsCaption =>
      'Bigger thinks better and answers slower. You can keep more than one and switch between them.';

  @override
  String get marloweBrainTierSwift => 'Swift';

  @override
  String get marloweBrainTierBalanced => 'Balanced';

  @override
  String get marloweBrainTierDeep => 'Deep';

  @override
  String get translationSlabShowOriginal => 'Show original';

  @override
  String get translationSlabFailed => 'Couldn\'t translate this one.';

  @override
  String get translationSlabRetry => 'Try again';

  @override
  String translationSlabByCompanion(Object name) {
    return 'Translated by $name';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return 'From $language';
  }

  @override
  String get messageActionMenuTranslateLabel => 'Translate';

  @override
  String get messageActionMenuShowOriginalLabel => 'Show original';

  @override
  String get roomTranslateTitle => 'Translate this chat';

  @override
  String get roomTranslateStopTitle => 'Stop translating';

  @override
  String get roomTranslateSectionLabel => 'TRANSLATION';

  @override
  String get roomTranslateOnRow => 'Translating this chat';

  @override
  String get roomTranslateOffRow => 'Off';

  @override
  String get roomTranslateNeedsSetUp => 'Set up Sebastian';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'Sebastian is translating · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return 'Reading in $language';
  }

  @override
  String get roomTranslateStop => 'STOP';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return 'Already in $language';
  }

  @override
  String get roomScreenTranslateRoomOffer =>
      'Translate the rest of this chat too?';

  @override
  String get roomScreenTranslateRoomOfferAction => 'Translate all';

  @override
  String get settingsScreenCompanionsOff => 'Off';

  @override
  String get settingsScreenCompanionsUnavailable => 'Unavailable';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return 'Also used by $name';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return '$name uses the same download and will lose it too.';
  }

  @override
  String get companionBrainInUse => 'In use';

  @override
  String companionStatusUsingBrain(Object name) {
    return 'Using $name';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name keeps downloading. Settings › Companions';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return 'Downloading · $percent%';
  }

  @override
  String get companionInstallPause => 'Pause';

  @override
  String get companionInstallResume => 'Resume';

  @override
  String get companionInstallDiscard => 'Discard';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return 'Paused · $received of $total';
  }

  @override
  String get companionInstallFailedIntegrity =>
      'The downloaded file didn\'t match what this version expects. Starting over.';

  @override
  String companionBannerDownloading(
    Object name,
    Object received,
    Object total,
  ) {
    return '$name · $received of $total';
  }

  @override
  String companionBannerPaused(Object name, Object received, Object total) {
    return '$name paused · $received of $total';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name is waking up…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => 'Translate again';

  @override
  String get groupCallScreenShareLabel => 'Share';

  @override
  String get groupCallScreenStopShareLabel => 'Stop sharing';

  @override
  String get groupCallScreenShareStartingLabel => 'Starting…';

  @override
  String get groupCallScreenRingingLabel => 'Ringing…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name is sharing their screen';
  }

  @override
  String get groupCallScreenYouAreSharing => 'You are sharing your screen';

  @override
  String get groupCallScreenMinimizeLabel => 'Hide';

  @override
  String get groupCallScreenDrawLabel => 'Draw';

  @override
  String get callScreenControlShare => 'Share';

  @override
  String get callScreenControlStopShare => 'Stop';

  @override
  String get callScreenControlShareStarting => 'Starting…';

  @override
  String get screenShareStopDrawing => 'Stop drawing';

  @override
  String get screenShareDrawBoardIdle => 'Drawings appear here';

  @override
  String get screenShareOverlayHint =>
      'Show drawings over other apps while you share';

  @override
  String get screenShareOverlayAllow => 'Allow';

  @override
  String get callScreenControlDraw => 'Draw';

  @override
  String get callScreenControlMinimize => 'Hide';

  @override
  String get inCallPillOngoingCall => 'Call in progress';

  @override
  String get inCallPillReturn => 'Return';

  @override
  String get inCallPillSharing => 'Sharing your screen';

  @override
  String get inCallPillDrawSemanticLabel => 'Draw on the shared screen';

  @override
  String get inCallPillStopSharingSemanticLabel => 'Stop sharing';

  @override
  String get screenShareUnsupported =>
      'Screen sharing isn\'t available on this device';

  @override
  String get screenShareEphemeralWarning =>
      'Capture protection is off while you share';

  @override
  String get screenShareNotificationTitle => 'Sharing your screen';

  @override
  String get screenShareNotificationBody => 'Everyone on the call can see it';

  @override
  String get screenShareNotificationStop => 'Stop';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name is already sharing';
  }

  @override
  String get screenShareFailed => 'Couldn\'t start sharing';

  @override
  String get screenSharePickerTitle => 'Share your screen';

  @override
  String get screenSharePickerScreens => 'Screens';

  @override
  String get screenSharePickerWindows => 'Windows';

  @override
  String get screenSharePickerEmpty =>
      'Nothing to share yet. Allow screen recording in System Settings and try again';

  @override
  String get gameTellFriends => 'Tell friends';

  @override
  String get gameToldFriends => 'Friends told';

  @override
  String get gameTellFriendsTitle => 'Tell your friends?';

  @override
  String get gameTellFriendsBody =>
      'they get a notification with this result. it can only be sent once.';

  @override
  String get gameTellFriendsCancel => 'Not now';

  @override
  String get gameTellFriendsConfirm => 'Send it';

  @override
  String get gameTellFriendsSent => 'Sent. They know';

  @override
  String get gameTellFriendsPrivate =>
      'Your daily scores are private, so nobody would see this';

  @override
  String get gameTellFriendsFailed => 'Couldn’t send that';

  @override
  String get settingsScreenFriendActivityLabel => 'FRIEND ACTIVITY';

  @override
  String get settingsScreenFriendActivityOnBody =>
      'highlights, points and game results as friends post them';

  @override
  String get settingsScreenFriendActivityOffBody =>
      'nothing. Their boards are still there when you look';

  @override
  String get searchScreenActionWithGrownUp => 'With a grown-up';

  @override
  String get newChatMenuSearchHint => 'Search your friends';

  @override
  String get newChatMenuNoFriendsYet =>
      'No friends yet. Find people in Discover';

  @override
  String get newChatMenuNoFriendsMatch => 'No friends match';

  @override
  String get newChatMenuOpenDmFailed => 'Couldn’t open that chat. Try again';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'Pick from your people';

  @override
  String get childPolicyScreenPickPersonHint => 'Search a name or username';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'No one left to add from your friends,\\nsearch for anyone else';

  @override
  String get childPolicyScreenPickPersonNoMatch => 'No one matches';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'Your friends';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'Everyone else';

  @override
  String get childPolicyScreenAddRoomLabel => 'Add a room';

  @override
  String get childPolicyScreenPickRoomHeading => 'Add a room';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'One of your own rooms. $name joins straight away and can read and post there until you take it back.';
  }

  @override
  String get childPolicyScreenPickRoomHint => 'Search your rooms';

  @override
  String get childPolicyScreenPickRoomEmpty => 'No rooms of yours left to add';

  @override
  String get childPolicyScreenPickRoomNoMatch => 'No rooms match';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name is in $room now';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'Couldn’t add that room. Try again';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'That room can’t be added this way';

  @override
  String get childPolicyScreenErrorRoomGone => 'That room no longer exists';

  @override
  String get newChatMenuFriendsHeader => 'Friends';

  @override
  String get roomChangeErrorGone =>
      'That suggestion is gone. An admin may have answered it.';

  @override
  String get roomChangeErrorNotYours =>
      'Only the person who suggested it can take it back.';

  @override
  String get roomChangeErrorNoChange => 'That\'s already what it says.';

  @override
  String get roomChangeErrorMissingValue => 'That can\'t be saved as it is.';

  @override
  String get roomChangeRequestsTitle => 'Suggestions';

  @override
  String get roomChangeRequestsBlurb =>
      'Members suggested these. Nothing changes until you say yes.';

  @override
  String get roomChangeRequestsEmpty => 'Nothing suggested.';

  @override
  String get roomChangeRequestsApprove => 'USE IT';

  @override
  String get roomChangeRequestsReject => 'NO';

  @override
  String get roomChangeRequestsPhotoLabel => 'New group picture';

  @override
  String get roomChangeRequestsNameLabel => 'New name';

  @override
  String get roomChangeRequestsDescriptionLabel => 'New description';

  @override
  String get roomChangeRequestsUnknownLabel =>
      'A change this app can\'t show yet';

  @override
  String get roomChangeRequestsClearedValue => 'Nothing, take it off';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name suggested';
  }

  @override
  String get roomAdminChangeRequestsRow => 'Suggestions';

  @override
  String get roomInfoScreenSuggestNote => 'An admin has to approve this';

  @override
  String get roomInfoScreenSuggestAvatarNote =>
      'An admin approves new pictures';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic =>
      'Suggest a group picture';

  @override
  String get roomInfoScreenSuggestionSentToast => 'Sent to the admins';

  @override
  String get roomInfoScreenSuggestionAppliedToast =>
      'Done. You can edit this group';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => 'Taken back';

  @override
  String get roomInfoScreenSuggestionsLabel => 'YOU SUGGESTED';

  @override
  String get roomInfoScreenSuggestionPhoto => 'A new group picture';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return 'Name: $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return 'Description: $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => 'A change';

  @override
  String get roomInfoScreenSuggestionPending => 'Waiting on an admin';

  @override
  String get roomInfoScreenSuggestionWithdraw => 'Take back';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name suggested a new group photo';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name suggested a new name';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name suggested a new description';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suggestions waiting for you',
      one: '$count suggestion waiting for you',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => 'Review';

  @override
  String get roomSuggestionBannerSemantic =>
      'Member suggestions waiting for your review';

  @override
  String get gameInfoPlay => 'Play';

  @override
  String get gameInfoContinue => 'Continue';

  @override
  String get gameInfoSeeResult => 'See your result';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return '$delivered of $total delivered';
  }

  @override
  String get messageReceiptsSentLabel => 'Sent';

  @override
  String messageReceiptsSemanticDeliveredThenRead(
    Object deliveredDay,
    Object deliveredTime,
    Object name,
    Object readDay,
    Object readTime,
  ) {
    return '$name received this $deliveredDay at $deliveredTime and read it $readDay at $readTime';
  }

  @override
  String get messageReceiptsStampRead => 'Read';

  @override
  String get messageReceiptsStampDelivered => 'Delivered';

  @override
  String get roomInviteCustom => 'Custom';

  @override
  String roomInviteCustomHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '$count day',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uses',
      one: '$count use',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => 'Hours';

  @override
  String get roomInviteUnitDays => 'Days';

  @override
  String get roomInviteStepperIncrease => 'Increase';

  @override
  String get roomInviteStepperDecrease => 'Decrease';

  @override
  String get recordsLabel => 'All-time';

  @override
  String get recordsBlurb =>
      'The best anyone has ever done: you and your friends';

  @override
  String recordsYourBest(Object value) {
    return 'Yours $value';
  }

  @override
  String get recordsNoneYet => 'Nobody yet';

  @override
  String get recordsEmpty => 'Solve any game and your best lands here.';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count solves',
      one: '$count solve',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return 'Set $date';
  }

  @override
  String recordsReactSemantic(Object name) {
    return 'React to $name\'s record';
  }

  @override
  String get recordsReactFailed => 'Couldn’t react to that';

  @override
  String get recordsLoadFailed => 'Couldn’t load the records';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game: record $value by $name';
  }

  @override
  String get appearanceLabel => 'Appearance';

  @override
  String get appearanceMatchDevice => 'Match device';

  @override
  String get appearanceMatchDeviceSub =>
      'Light by day, dark by night, with your phone';

  @override
  String get appearanceOneTheme => 'One theme';

  @override
  String get appearanceOneThemeSub => 'The same look all day';

  @override
  String get appearanceLightSlot => 'Light mode';

  @override
  String get appearanceDarkSlot => 'Dark mode';

  @override
  String get appearanceNow => 'Now';

  @override
  String appearanceAutoValue(Object name) {
    return 'Auto · $name';
  }

  @override
  String get themeScreenAssignHint =>
      'tap a theme to use it in light or dark mode · ⛶ for full preview';

  @override
  String get themeScreenCarouselUseLight => 'USE IN LIGHT MODE';

  @override
  String get themeScreenCarouselUseDark => 'USE IN DARK MODE';

  @override
  String get themeScreenCarouselIsLight => 'YOUR LIGHT THEME';

  @override
  String get themeScreenCarouselIsDark => 'YOUR DARK THEME';

  @override
  String get onboardingThemeTitle => 'make it yours.';

  @override
  String get onboardingThemeBody =>
      'pick a look. you can change it any time in settings.';

  @override
  String get onboardingThemeYourTheme => 'YOUR THEME';

  @override
  String get onboardingThemeContinue => 'CONTINUE';

  @override
  String get dropHintNoTarget => 'Drop on a chat to send';

  @override
  String get dropNothingToSend => 'Nothing here can be sent';

  @override
  String dropSendPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count photos',
      one: 'Send photo',
    );
    return '$_temp0';
  }

  @override
  String dropSendVideos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count videos',
      one: 'Send video',
    );
    return '$_temp0';
  }

  @override
  String dropSendAudio(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count audio files',
      one: 'Send audio',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count files',
      one: 'Send file',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send $count items',
      one: 'Send item',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => 'Add to message';

  @override
  String get dropSendLink => 'Add link';

  @override
  String dropTargetTo(String name) {
    return 'To $name';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files are over $size',
      one: '1 file is over $size',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => 'Folders can’t be sent';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skipping $count empty files',
      one: 'Skipping an empty file',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => 'Attachments aren’t allowed here';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count will be sent as files',
      one: 'Will be sent as a file',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count may not preview everywhere',
      one: 'May not preview everywhere',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => 'photo';

  @override
  String get dropKindVideo => 'video';

  @override
  String get dropKindAudio => 'audio';

  @override
  String get dropKindFile => 'file';

  @override
  String get dropKindFolder => 'folder';

  @override
  String get dropKindText => 'text';

  @override
  String get dropKindLink => 'link';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files didn’t fit in this send',
      one: '1 file didn’t fit in this send',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed => 'Couldn’t do that. Try again.';

  @override
  String get expressionBackspace => 'Delete';

  @override
  String get expressionCreateSticker => 'Make a sticker';

  @override
  String get expressionDeleteSticker => 'Delete from my stickers';

  @override
  String get expressionFavorite => 'Add to favorites';

  @override
  String get expressionFavorited => 'Added to favorites';

  @override
  String get expressionFavorites => 'Favorites';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF: $title';
  }

  @override
  String get expressionLoadFailed => 'Couldn’t load. Check your connection.';

  @override
  String get expressionMediaNotAllowed =>
      'Your family settings don’t allow sending pictures.';

  @override
  String get expressionMyStickers => 'My stickers';

  @override
  String get expressionNoFavorites =>
      'Long-press a GIF or sticker to add it to favorites.';

  @override
  String get expressionNoRecents =>
      'GIFs and stickers you send will show up here.';

  @override
  String get expressionNoResults => 'No results';

  @override
  String get expressionNoStickers => 'No stickers here yet.';

  @override
  String get expressionOpenPanel => 'Emoji, GIFs and stickers';

  @override
  String get expressionOptionsHint => 'Show options';

  @override
  String expressionPackCredit(String author, String license) {
    return 'Art: $author · $license';
  }

  @override
  String get expressionPlayGifHint => 'play';

  @override
  String get expressionRecent => 'Recent';

  @override
  String get expressionReport => 'Report';

  @override
  String get expressionReported => 'Thanks, it’s been reported.';

  @override
  String get expressionRetry => 'Try again';

  @override
  String get expressionSearchKlipy => 'Search KLIPY';

  @override
  String get expressionShowKeyboard => 'Show keyboard';

  @override
  String get expressionSuggestionsLabel => 'Sticker suggestions';

  @override
  String get expressionTabEmoji => 'Emoji';

  @override
  String get expressionTabGifs => 'GIFs';

  @override
  String get expressionTabStickers => 'Stickers';

  @override
  String get expressionTrending => 'Trending';

  @override
  String get expressionUnfavorite => 'Remove from favorites';

  @override
  String get expressionUnfavorited => 'Removed from favorites';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return 'Sticker $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel => 'Autoplay GIFs & stickers';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      'They stay still until you tap one. Saves data.';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'GIFs and animated stickers play by themselves. Reduce Motion pauses them.';

  @override
  String get settingsAlbumCardsLabel => 'Photo albums as cards';

  @override
  String get settingsAlbumCardsOffBody =>
      'Several photos in one message are laid out as a grid.';

  @override
  String get settingsAlbumCardsOnBody =>
      'Several photos in one message come as a stack you swipe through.';

  @override
  String get settingsStickerSuggestionsBody =>
      'Typing a single emoji shows matching stickers above the message field.';

  @override
  String get settingsStickerSuggestionsLabel => 'Sticker suggestions';

  @override
  String get stickerMakerEmojiLabel => 'Which emoji is it?';

  @override
  String get stickerMakerFailed => 'Couldn’t save the sticker. Try again.';

  @override
  String get stickerMakerMoreEmoji => 'More emoji';

  @override
  String get stickerMakerPreview => 'Sticker preview';

  @override
  String get stickerMakerRemoveBackground => 'Remove background';

  @override
  String get stickerMakerSave => 'Save';

  @override
  String get stickerMakerSaved => 'Sticker added to My stickers';

  @override
  String get stickerMakerShape => 'Shape';

  @override
  String get stickerMakerShapeCircle => 'Circle';

  @override
  String get stickerMakerShapeOriginal => 'Original';

  @override
  String get stickerMakerShapeRounded => 'Rounded square';

  @override
  String get stickerMakerTitle => 'New sticker';

  @override
  String get stickerMakerTooMany =>
      'You’ve reached the sticker limit. Delete one to make room.';

  @override
  String get expressionExpandPanel => 'Expand panel';

  @override
  String get expressionCollapsePanel => 'Shrink panel';

  @override
  String get expressionPackStore => 'Sticker packs';

  @override
  String get expressionPackSearchHint => 'Search sticker packs';

  @override
  String get expressionPacksAdded => 'Added';

  @override
  String get expressionPacksMore => 'More packs';

  @override
  String get expressionPackAdd => 'Add';

  @override
  String get expressionPackRemove => 'Remove';

  @override
  String expressionPackStickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stickers',
      one: '1 sticker',
    );
    return '$_temp0';
  }

  @override
  String get expressionNoPacksFound => 'No packs match';

  @override
  String get expressionAllPacksAdded => 'You’ve added every pack.';

  @override
  String expressionPackReorder(String title) {
    return 'Reorder $title';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return 'Add the “$title” pack';
  }

  @override
  String expressionPackAddedToast(String title) {
    return '“$title” added to your stickers';
  }

  @override
  String get expressionPacksFromKlipy => 'More stickers from KLIPY';

  @override
  String expressionSearchKlipyFor(String query) {
    return 'Search “$query” on KLIPY';
  }

  @override
  String get expressionHideKeyboard => 'Hide keyboard';

  @override
  String get expressionSearchStickers => 'Search stickers';

  @override
  String get expressionYourStickers => 'Your stickers';

  @override
  String get chatListYesterday => 'Yesterday';

  @override
  String get roomLayoutScreenCardsLayoutLabel => 'CARDS';

  @override
  String get roomLayoutScreenCardsLayoutDescription =>
      'every room in its own card, every detail spelled out.';

  @override
  String get homeScreenTitle => 'Chats';

  @override
  String get glassScreenNativeLabel => 'iOS Liquid Glass';

  @override
  String get glassScreenNativeOnBody =>
      'The tab bar is drawn by iOS itself. The sliders below tune the rest of the app.';

  @override
  String get glassScreenNativeOffBody =>
      'MonkeyHub draws its own glass everywhere, tuned by the sliders below.';

  @override
  String get glassScreenHeading => 'Glass';

  @override
  String get glassStyleHeader => 'Style';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody =>
      'Apple\'s own glass, drawn by iOS. Buttons across the app match it.';

  @override
  String get glassStyleFrostedTitle => 'Frosted';

  @override
  String get glassStyleFrostedBody =>
      'MonkeyHub\'s own glass. Shape every dial yourself.';

  @override
  String get glassStyleRecommended => 'Recommended';

  @override
  String get glassStyleLiquidFooter =>
      'Nothing to tune: iOS sets the blur, tint and light. Choose Frosted to shape the glass yourself.';

  @override
  String get acctSectionPrivacy => 'Privacy';

  @override
  String get acctSectionAccount => 'Account';

  @override
  String get acctSectionFamily => 'Family';

  @override
  String get acctSectionThisPhone => 'This phone';

  @override
  String get acctRowVisibility => 'Profile visibility';

  @override
  String get acctRowBlocked => 'Blocked users';

  @override
  String get acctRowApprovals => 'Approvals';

  @override
  String get acctNothingWaiting => 'None waiting';

  @override
  String get acctRowLinked => 'Linked accounts';

  @override
  String get acctRowScanToSignIn => 'Scan to sign in';

  @override
  String get acctRowSetUpRecovery => 'Set up recovery phrase';

  @override
  String get acctRowChangeRecovery => 'Change recovery phrase';

  @override
  String get acctSignOut => 'Sign out';

  @override
  String get acctDeleteAccount => 'Delete account';

  @override
  String get acctConfirmDelete => 'Tap again to delete';

  @override
  String get acctHandPhoneBack => 'Hand this phone back';

  @override
  String get acctMyGrownUps => 'My grown-ups';

  @override
  String get acctActionMessage => 'Message';

  @override
  String get acctActionAddFriend => 'Add';

  @override
  String get acctActionRequested => 'Requested';

  @override
  String get acctActionAccept => 'Accept';

  @override
  String get acctActionNotAccepting => 'Closed';

  @override
  String get acctActionUnfriend => 'Unfriend';

  @override
  String get acctActionBlock => 'Block';

  @override
  String get acctActionReport => 'Report';

  @override
  String get acctStatusFriends => 'Friends';

  @override
  String get acctStatusRequestSent => 'Request sent';

  @override
  String get acctStatusWantsToConnect => 'Wants to be friends';

  @override
  String get acctStatusNotConnected => 'Not connected';

  @override
  String get acctPresenceOnline => 'Online';

  @override
  String get acctPresenceAway => 'Away';

  @override
  String get acctPresenceOffline => 'Offline';

  @override
  String get acctProfilePhoto => 'Profile photo';

  @override
  String get acctSaveToPhotos => 'Save to Photos';

  @override
  String get acctTakeSelfie => 'Take a selfie';

  @override
  String get acctChooseFromLibrary => 'Choose from library';

  @override
  String get acctCancel => 'Cancel';

  @override
  String get acctSave => 'Save';

  @override
  String get acctChange => 'Change';

  @override
  String get acctNotNow => 'Not now';

  @override
  String get acctAddEmail => 'Add email';

  @override
  String get acctEditNameTitle => 'Edit name';

  @override
  String get acctAddNameTitle => 'Add your name';

  @override
  String get acctEditEmailTitle => 'Edit email';

  @override
  String get acctChangeUsernameTitle => 'Change username?';

  @override
  String get onboardingLookTitle => 'Make it yours';

  @override
  String get onboardingLookBody =>
      'Pick a look. You can change it any time in Settings.';

  @override
  String get onboardingEssentials => 'Essentials';

  @override
  String get onboardingEssentialsSub => 'Calm and native';

  @override
  String get onboardingCharacters => 'Characters';

  @override
  String get onboardingCharactersSub => 'Same app, more personality';

  @override
  String get onboardingLightMode => 'Light mode';

  @override
  String get onboardingDarkMode => 'Dark mode';

  @override
  String get onboardingNow => 'Now';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingIconTitle => 'Your app icon';

  @override
  String get onboardingIconBody =>
      'Keep the icon you have, let it follow your theme, or pick any mark.';

  @override
  String get onboardingIconIosNote =>
      'iOS shows a short notice whenever the icon changes.';

  @override
  String get onboardingGetStarted => 'Get started';

  @override
  String get appIconMatchTheme => 'Match theme';

  @override
  String get appIconCurrent => 'Current';

  @override
  String get appIconSectionCollection => 'MonkeyHub collection';

  @override
  String get appIconSectionThemes => 'Theme icons';

  @override
  String get appIconScreenTitle => 'App icon';

  @override
  String get appIconMatchFooter =>
      'Match theme changes the icon along with your dark-mode theme, so it never flips back and forth during the day.';

  @override
  String get loginTitleReturning => 'Welcome back';

  @override
  String get loginTitleFirst => 'Welcome to MonkeyHub';

  @override
  String get loginTitleSignUp => 'Create your account';

  @override
  String get loginTitleReset => 'Reset your password';

  @override
  String get loginSubtitleSignIn => 'Sign in to pick up where you left off.';

  @override
  String get loginSubtitleFirst =>
      'Sign in, or create an account in a few seconds.';

  @override
  String get loginSubtitleSignUp =>
      'A username and a password is all it takes.';

  @override
  String get loginSubtitleReset =>
      'Enter your 12-word recovery phrase and choose a new password.';

  @override
  String get loginCtaSignIn => 'Sign in';

  @override
  String get loginCtaSignUp => 'Create account';

  @override
  String get loginCtaReset => 'Reset password';

  @override
  String get loginNoAccountPrompt => 'New here? ';

  @override
  String get loginCreateAccountLink => 'Create an account';

  @override
  String get loginHaveAccountPrompt => 'Already have an account? ';

  @override
  String get loginSignInLink => 'Sign in';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginChildAccount => 'Set up a child account';

  @override
  String get loginBackToSignIn => 'Back to sign in';

  @override
  String get loginWithPhone => 'Sign in with your phone';

  @override
  String get loginUsernameField => 'Username';

  @override
  String get loginPasswordField => 'Password';

  @override
  String get loginConfirmPasswordField => 'Confirm password';

  @override
  String get loginNameField => 'Name (optional)';

  @override
  String get loginRecoveryPhraseField => 'Your 12-word recovery phrase';

  @override
  String get loginNewPasswordField => 'New password';

  @override
  String get roomHeaderStatusOnline => 'Online';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => 'Settings';

  @override
  String get settingsHubAccountHintAdult =>
      'Profile, family, linked accounts and privacy';

  @override
  String get settingsHubAccountHintChild =>
      'Profile, privacy and your grown-ups';

  @override
  String get settingsHubSectionGeneral => 'General';

  @override
  String get settingsHubSectionNotifications => 'Notifications';

  @override
  String get settingsHubSectionCalls => 'Calls';

  @override
  String get settingsHubSectionAppearance => 'Appearance';

  @override
  String get settingsHubSectionCompanions => 'Companions';

  @override
  String get settingsHubSectionChats => 'Chats';

  @override
  String get settingsHubSectionHelp => 'Help & legal';

  @override
  String get settingsHubSectionAdvanced => 'Advanced';

  @override
  String get settingsHubLanguage => 'Language';

  @override
  String get settingsHubCheckForUpdates => 'Check for updates';

  @override
  String get settingsHubUpdateAvailable => 'Update available';

  @override
  String get settingsHubShowLinkUrls => 'Show link addresses';

  @override
  String get settingsHubShowLinkUrlsSubtitle =>
      'Print the address next to each link preview';

  @override
  String get settingsHubPresenceDots => 'Show who\'s online';

  @override
  String get settingsHubPresenceDotsSubtitle => 'The dot on profile pictures';

  @override
  String get settingsHubPush => 'Push notifications';

  @override
  String get settingsHubPushSubtitle => 'New messages, calls and requests';

  @override
  String get settingsHubGameReminders => 'Daily game reminder';

  @override
  String get settingsHubGameRemindersSubtitle =>
      'One nudge at lunchtime if you haven\'t played';

  @override
  String get settingsHubFriendActivity => 'Friend activity';

  @override
  String get settingsHubFriendActivitySubtitle =>
      'Highlights, points and game results from friends';

  @override
  String get settingsHubMenuBar => 'Menu bar icon';

  @override
  String get settingsHubMenuBarSubtitle =>
      'Shows your unread count in the menu bar';

  @override
  String get settingsHubCallStats => 'Show call stats';

  @override
  String get settingsHubCallStatsSubtitle =>
      'Resolution, bitrate and ping during calls';

  @override
  String get settingsHubTheme => 'Theme';

  @override
  String get settingsHubAppIcon => 'App icon';

  @override
  String get settingsHubGlass => 'Glass';

  @override
  String get settingsHubNavigation => 'Navigation';

  @override
  String get settingsHubMotion => 'Motion';

  @override
  String get settingsHubChatList => 'Chat list';

  @override
  String get settingsHubChatStyle => 'Chat style';

  @override
  String get settingsHubBubbleStyle => 'Bubble style';

  @override
  String get settingsHubSpeakerColors => 'Speaker colours';

  @override
  String get settingsHubReplyStyle => 'Reply style';

  @override
  String get settingsHubPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsHubTerms => 'Terms of service';

  @override
  String get settingsHubLicence => 'Licence';

  @override
  String get settingsHubServer => 'Server';

  @override
  String get settingsHubLayoutRows => 'Rows';

  @override
  String get settingsHubLayoutCards => 'Cards';

  @override
  String get settingsHubLayoutGrid => 'Grid';

  @override
  String get settingsHubNavTabBar => 'Tab bar';

  @override
  String settingsHubThemeAuto(String name) {
    return 'Auto · $name';
  }

  @override
  String get chatListPageRowsSub =>
      'A face, a name and the latest message, like Messages.';

  @override
  String get chatListPageCardsSub =>
      'Every room in its own card, every detail spelled out.';

  @override
  String get chatListPageGridSub =>
      'Two columns of tiles. More rooms at a glance.';

  @override
  String get chatListPageLayoutHeader => 'Layout';

  @override
  String get chatListPageFiltersHeader => 'Filters';

  @override
  String get chatListPageChips => 'Chips';

  @override
  String get chatListPageChipsSub => 'A row of filters, always one tap away.';

  @override
  String get chatListPageButton => 'Button';

  @override
  String get chatListPageButtonSub =>
      'One button that opens the filters when you ask.';

  @override
  String get chatListPageEmptyHeader => 'Empty rooms';

  @override
  String get chatListPagePlain => 'Plain';

  @override
  String get chatListPagePlainSub => 'A room with nothing said yet stays bare.';

  @override
  String get chatListPageInitial => 'Initial';

  @override
  String get chatListPageInitialSub =>
      'A large faded letter fills the empty corner.';

  @override
  String get chatListPageEmptyFooter => 'Applies to the grid layout.';

  @override
  String get chatStylePageFooter =>
      'How a conversation\'s header and message field are drawn.';

  @override
  String get chatStyleClassicSub => 'A solid header and a flat message field.';

  @override
  String get chatStyleCompactSub =>
      'Frosted controls float over the conversation.';

  @override
  String get bubbleTailedSub =>
      'A tail on the last message of each run, like Messages.';

  @override
  String get bubbleSoftSub => 'No tail. A run holds together by its corners.';

  @override
  String get bubblePillSub => 'Fully rounded capsules on every message.';

  @override
  String get bubbleSlabSub => 'Square shoulders: sharp and deliberate.';

  @override
  String get replyStylePageFooter =>
      'How a reply shows the message it answers.';

  @override
  String get replyClassicSub =>
      'A tinted quote above the message, WhatsApp style.';

  @override
  String get replyPhantomSub =>
      'A ghost of the original floats above, joined by a curve.';

  @override
  String get replyStickySub => 'A small tilted card clipped to the corner.';

  @override
  String get replyComicSub => 'A mini bubble with a comic-book tail.';

  @override
  String get motionMatchDevice => 'Match device';

  @override
  String get motionMatchDeviceCalmSub =>
      'Your device is asking for reduced motion right now.';

  @override
  String get motionMatchDeviceFullSub =>
      'Your device allows animation right now.';

  @override
  String get motionFullSub => 'Every spring, drift and flourish.';

  @override
  String get motionCalmSub =>
      'Decoration holds still. Everything else works the same.';

  @override
  String get navigationPageFooter =>
      'How you move between Chats, Feed, Discover and Settings.';

  @override
  String get navTabBarSub => 'Always visible, one tap to anywhere.';

  @override
  String get navOrbSub =>
      'Hold and drag from the corner. A gesture you grow into.';

  @override
  String get languageSystemLabel => 'Device language';

  @override
  String get languagePageFooter =>
      'Menus and app messages. Chats stay in whatever language people write in.';

  @override
  String get speakerPageFooter =>
      'Tell who\'s talking at a glance in group chats.';

  @override
  String get speakerOffSub => 'Everyone writes in the same ink.';

  @override
  String get speakerNamesSub =>
      'Each person keeps a colour on their name and face.';

  @override
  String get speakerBubblesSub =>
      'Their colour carries into their messages too.';

  @override
  String get themePageAutoFooter =>
      'Light themes are used in light mode, dark ones in dark mode.';

  @override
  String get themePageLightMode => 'Light mode';

  @override
  String get themePageDarkMode => 'Dark mode';

  @override
  String get themePageEssentials => 'Essentials';

  @override
  String get themePageEssentialsFooter => 'Calm and native, in five colours.';

  @override
  String get themePageCharacters => 'Characters';

  @override
  String get themePageCharactersFooter =>
      'The same layout, with a personality of its own. Touch and hold any theme to preview it.';

  @override
  String get themePageLightBadge => 'Light';

  @override
  String get themePageDarkBadge => 'Dark';

  @override
  String get themePageInUse => 'In use';

  @override
  String get themePageUseLight => 'Use in light mode';

  @override
  String get themePageUseDark => 'Use in dark mode';

  @override
  String themePageUse(String name) {
    return 'Use $name';
  }

  @override
  String get acctCaptureTitle => 'Screen capture protection';

  @override
  String get acctCaptureOnIos =>
      'Recording and mirroring show a privacy shield.';

  @override
  String get acctCaptureOnAndroid =>
      'Screenshots and recordings come out black.';

  @override
  String get acctCaptureOff => 'Screenshots and recordings work normally.';

  @override
  String get acctCaptureFooter =>
      'Rooms with disappearing messages always turn this on.';

  @override
  String get acctActionPending => 'Pending';

  @override
  String get chatSwipePin => 'Pin';

  @override
  String get chatSwipeUnpin => 'Unpin';

  @override
  String get chatSwipeMute => 'Mute';

  @override
  String get chatSwipeUnmute => 'Unmute';

  @override
  String get chatSwipeArchive => 'Archive';

  @override
  String get appearanceMatchDeviceSubtitle =>
      'Light by day, dark by night, with your phone';

  @override
  String get appearanceOneThemeSubtitle => 'The same look all day';

  @override
  String get riName => 'Name';

  @override
  String get riDescription => 'Description';

  @override
  String get riVisibility => 'Who can find it';

  @override
  String get riPublic => 'Public';

  @override
  String get riPublicSub => 'Anyone can find it in Discover';

  @override
  String get riPrivate => 'Private';

  @override
  String get riPrivateSub => 'Only people you invite can join';

  @override
  String get riMessageLife => 'Messages disappear after';

  @override
  String get riPassword => 'Password';

  @override
  String get riRemovePassword => 'Remove password';

  @override
  String get riSetPassword => 'Set password';

  @override
  String get riSharedContent => 'Shared content';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invited',
      one: '1 invited',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => 'Withdraw';

  @override
  String get riNotifications => 'Notifications';

  @override
  String get riTranslation => 'Translation';

  @override
  String get riNameColours => 'Name colours';

  @override
  String get riYouSuggested => 'You suggested';

  @override
  String get riTakeBack => 'Take back';

  @override
  String get riLeaveRoom => 'Leave room';

  @override
  String get riLeaving => 'Leaving…';

  @override
  String get riDeleteRoom => 'Delete room';

  @override
  String get riDeleting => 'Deleting…';

  @override
  String get riEndConversation => 'End conversation';

  @override
  String get riEnding => 'Ending…';

  @override
  String get riActionCall => 'Call';

  @override
  String get riActionVideo => 'Video';

  @override
  String get riActionMute => 'Mute';

  @override
  String get riActionUnmute => 'Unmute';

  @override
  String get riActionMedia => 'Media';

  @override
  String get riActionAdd => 'Add';

  @override
  String get roomHeaderStatusTyping => 'Typing…';

  @override
  String get glassScreenLead => 'How much of what’s behind comes through.';

  @override
  String get transcriptDayToday => 'Today';

  @override
  String get acctRowDevices => 'Devices';

  @override
  String get acctThisDevice => 'This device';

  @override
  String get acctRemove => 'Remove';

  @override
  String get acctRemoveDeviceTitle => 'Remove this device?';

  @override
  String get acctRemoveAllTitle => 'Remove all other devices?';

  @override
  String get acctRemoveAll => 'Remove all';

  @override
  String get acctActiveNow => 'Active now';

  @override
  String get acctLoading => 'Loading…';

  @override
  String get acctDevicesLoadFailed => 'Couldn\'t load your devices.';

  @override
  String get acctNoNotifications => 'Notifications aren\'t reaching this one';

  @override
  String get acctBlockedEmpty => 'You haven\'t blocked anyone.';

  @override
  String get acctUnblock => 'Unblock';

  @override
  String get pvSubtitle =>
      'Control what others see and how they can reach you.';

  @override
  String get pvSectionProfile => 'Profile';

  @override
  String get pvSectionMessages => 'Messages';

  @override
  String get pvSectionPeople => 'People';

  @override
  String get pvSectionFeed => 'Feed';

  @override
  String get pvAvatar => 'Profile photo';

  @override
  String get pvAvatarDesc => 'Who can see your picture';

  @override
  String get pvOnline => 'Online status';

  @override
  String get pvOnlineDesc => 'Whether you appear active right now';

  @override
  String get pvLastSeen => 'Last seen';

  @override
  String get pvLastSeenDesc => 'When you were last around';

  @override
  String get pvSendReceipts => 'Send read receipts';

  @override
  String get pvSendReceiptsDesc =>
      'Let others see when you\'ve read their messages';

  @override
  String get pvShowReceipts => 'Show read receipts';

  @override
  String get pvShowReceiptsDesc => 'See who has read your messages';

  @override
  String get pvShowReceiptsHint =>
      'Only people who send read receipts are counted.';

  @override
  String get pvFriendRequests => 'Friend requests';

  @override
  String get pvFriendRequestsDesc => 'Who can send you friend requests';

  @override
  String get pvSupervisedTitle => 'Your grown-ups set these';

  @override
  String get pvEveryone => 'Everyone';

  @override
  String get pvFriends => 'Friends';

  @override
  String get pvNobody => 'Nobody';

  @override
  String get pvOn => 'On';

  @override
  String get pvOff => 'Off';

  @override
  String get pvAnyone => 'Anyone';

  @override
  String get pvHighlights => 'My highlights';

  @override
  String get pvHighlightsDesc =>
      'Whether your photos and videos show on friends\' boards for the day';

  @override
  String get pvPuzzle => 'My puzzle score';

  @override
  String get pvPuzzleDesc =>
      'Whether friends see how you did on the daily puzzle';

  @override
  String get pvPast => 'My past';

  @override
  String get pvPastDesc =>
      'Today is always shared with friends. This opens up everything before it';

  @override
  String get pvPoints => 'My points';

  @override
  String get pvPointsDesc =>
      'Whether the points you log show on friends\' boards';

  @override
  String get roomColorsPageTitle => 'Who\'s who';

  @override
  String get roomColorsPageHeader => 'The colour each person speaks in';

  @override
  String get roomColorsAuto => 'Automatic';

  @override
  String get roomColorsReset => 'Back to automatic';

  @override
  String get roomColorsOffFooter =>
      'Speaker colours are off. Turning them on here turns them on in every room.';

  @override
  String roomColorsSharedWith(String name) {
    return 'Shared with $name';
  }

  @override
  String get settingsScreenValueReplyQuote => 'Quote';

  @override
  String get replyQuoteSub =>
      'The original sits at the top of the reply, inside its bubble.';

  @override
  String get riTabMedia => 'Photos and videos';

  @override
  String get riTabFiles => 'Files';

  @override
  String get riTabVoice => 'Voice messages';

  @override
  String get riTabLinks => 'Links';

  @override
  String get riTabSaved => 'Saved';

  @override
  String get riNone => 'None';

  @override
  String get riSavedNote =>
      'Only you see what you save. A pinned message is the opposite: the whole room sees it.';

  @override
  String get riOwnerNote => 'The medal marks whoever created this room.';

  @override
  String get famPair => 'Pair';

  @override
  String get famRelease => 'Release';

  @override
  String get famSettings => 'Settings';

  @override
  String get famAddChild => 'Add a child';

  @override
  String get famEmptyTitle => 'No children yet';

  @override
  String get famOnlineNow => 'Online now';

  @override
  String get famNotPaired => 'Not paired yet';

  @override
  String get famJustNow => 'Just now';

  @override
  String get apprEmptyTitle => 'Nothing waiting';

  @override
  String get apprEmptySub => 'You\'re all caught up.';

  @override
  String get apprNotYet => 'Not yet';

  @override
  String get apprAllow => 'Allow';

  @override
  String get compGeneral => 'General';

  @override
  String get compStorage => 'Storage';

  @override
  String get compTranslateInto => 'Translate into';

  @override
  String get compBrain => 'Brain';

  @override
  String laUnlinkProvider(String provider) {
    return 'Unlink $provider';
  }

  @override
  String laLinkProvider(String provider) {
    return 'Link $provider';
  }

  @override
  String get laUnlink => 'Unlink';

  @override
  String get laLink => 'Link';

  @override
  String get laLinked => 'Linked';

  @override
  String get laNotLinked => 'Not linked';

  @override
  String rdSignOut(String name) {
    return 'Sign $name out';
  }

  @override
  String get rpContinue => 'Continue';

  @override
  String get rpCopy => 'Copy';

  @override
  String get rpSaved => 'I saved them';

  @override
  String get rpBack => 'Back';

  @override
  String get rpKeep => 'Not now, keep my current phrase';

  @override
  String get childSetupHeadingIos => 'Who are they?';

  @override
  String get childPairTitleIos => 'Hello!';

  @override
  String get childPairBackIos => 'Back to sign in';

  @override
  String get gamesHubTitle => 'Leaderboard';

  @override
  String get gamesHubSubtitle => 'Today\'s winners. New puzzles every day.';

  @override
  String get gameTellFriendsMessage =>
      'They\'ll get a notification with this result. It can only be sent once.';

  @override
  String get deviceLoginScanTitleIos => 'Scan to sign in';

  @override
  String get deviceLoginConfirmTitleIos => 'Sign in on this device?';

  @override
  String get socialHeroCreateIos => 'Almost there';

  @override
  String get socialHeroLinkIos => 'Welcome back';

  @override
  String socialSignInLinkIos(String provider) {
    return 'Sign in & link $provider';
  }

  @override
  String get serverTitleIos => 'Server';

  @override
  String get serverOnboardingTitleIos => 'Pick a server';

  @override
  String get approvalGateAskIos => 'Ask';

  @override
  String get friendRequestDraftIntroOutgoingSentence =>
      'Send a few lines. They can approve or decline.';

  @override
  String get requestDeclineIos => 'Decline';

  @override
  String get joinRequestAllowIos => 'Allow';

  @override
  String get changeRequestUseIos => 'Use it';

  @override
  String get settingsSearchHint => 'Search settings';

  @override
  String settingsSearchNoResults(String query) {
    return 'No results for “$query”';
  }

  @override
  String get settingsSearchAccount => 'Account';

  @override
  String get settingsHubDiagnostics => 'Diagnostics';

  @override
  String get settingsHubDiagnosticsSubtitle =>
      'Logs for troubleshooting and bug reports';

  @override
  String get settingsHubAdvancedFooter =>
      'For troubleshooting and self-hosting. Nothing here is needed day to day.';

  @override
  String get settingsSearchKwLanguage =>
      'language, translation, locale, region';

  @override
  String get settingsSearchKwUpdates => 'update, version, new, upgrade';

  @override
  String get settingsSearchKwLinks => 'links, url, address, preview';

  @override
  String get settingsSearchKwPresence =>
      'online, presence, status, dot, active, green';

  @override
  String get settingsSearchKwAutoplay => 'gif, animation, autoplay, motion';

  @override
  String get settingsSearchKwStickers => 'stickers, emoji, suggestions';

  @override
  String get settingsSearchKwPush => 'notifications, alerts, sound, badge';

  @override
  String get settingsSearchKwGames => 'games, reminder, daily, puzzle';

  @override
  String get settingsSearchKwFriends => 'friends, activity, points, highlights';

  @override
  String get settingsSearchKwVideo => 'video, call, quality, camera, data';

  @override
  String get settingsSearchKwStats =>
      'call stats, network, bitrate, ping, debug';

  @override
  String get settingsSearchKwTheme =>
      'theme, dark, light, colours, night, appearance';

  @override
  String get settingsSearchKwIcon => 'app icon, logo, home screen';

  @override
  String get settingsSearchKwGlass =>
      'glass, liquid glass, blur, frosted, transparency';

  @override
  String get settingsSearchKwNavigation =>
      'tab bar, navigation, menu, bottom bar';

  @override
  String get settingsSearchKwMotion =>
      'motion, animation, reduce motion, effects';

  @override
  String get settingsSearchKwCompanions =>
      'ai, assistant, translate, model, companion';

  @override
  String get settingsSearchKwChatList =>
      'chat list, rows, cards, grid, filter, layout';

  @override
  String get settingsSearchKwChatStyle =>
      'chat style, compact, classic, header';

  @override
  String get settingsSearchKwBubbles => 'bubbles, messages, tail, shape';

  @override
  String get settingsSearchKwSpeakers => 'names, colours, groups, who\'s who';

  @override
  String get settingsSearchKwReply => 'reply, quote, thread';

  @override
  String get settingsSearchKwReport => 'bug, problem, feedback, support, help';

  @override
  String get settingsSearchKwLegal => 'privacy, terms, legal, licence, policy';

  @override
  String get settingsSearchKwServer =>
      'server, self-host, url, backend, developer';

  @override
  String get settingsSearchKwDiagnostics =>
      'diagnostics, logs, debug, developer, crash';

  @override
  String get settingsSearchKwPrivacy =>
      'privacy, visibility, who can see, last seen, read receipts';

  @override
  String get settingsSearchKwBlocked => 'blocked, block, people';

  @override
  String get settingsSearchKwDevices =>
      'devices, sessions, sign out, phone, computer';

  @override
  String get settingsSearchKwLinked => 'apple, google, sign in, linked';

  @override
  String get settingsSearchKwRecovery =>
      'recovery phrase, password, backup, forgot';

  @override
  String get settingsSearchKwCapture =>
      'screenshot, screen recording, capture, privacy';

  @override
  String get settingsSearchKwFamily =>
      'family, child, parent, approvals, grown-ups';

  @override
  String get settingsSearchKwAccount =>
      'account, sign out, delete, email, username';

  @override
  String get childPolicyScreenContactStateAllowedTalking => 'Talking';

  @override
  String get childPolicyScreenContactStateTalking => 'Approved';

  @override
  String get childPolicyScreenContactStateAllowedNotAdded => 'Not added yet';

  @override
  String get profileScreenSignOutConfirmTitle => 'Sign out on this device?';

  @override
  String get profileScreenDeleteAccountConfirmTitle => 'Delete your account?';

  @override
  String get profileScreenDeleteAccountConfirmBody =>
      'Your messages, photos, rooms and friends all go, and your username is freed for anyone else.';

  @override
  String get glassPresetNameFrosted => 'Frosted';

  @override
  String get glassPresetNameClear => 'Clear';

  @override
  String settingsScreenDiagnosticsCountdown(int count) {
    return 'Diagnostics in $count…';
  }

  @override
  String pairingCodeTitlePair(String name) {
    return 'Pair $name';
  }

  @override
  String pairingCodeTitleRelease(String name) {
    return 'Release $name';
  }

  @override
  String archivedChatsSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chats',
      one: '$count chat',
    );
    return '$_temp0';
  }

  @override
  String pinnedListSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '$count message',
    );
    return '$_temp0';
  }

  @override
  String get voiceRecorderScreenTitle => 'Voice message';

  @override
  String get chatTargetSearchHint => 'Search';

  @override
  String get marloweBrainTierSwiftDetail =>
      'Quick answers, the lightest download';

  @override
  String get marloweBrainTierBalancedDetail => 'A good mix of speed and depth';

  @override
  String get marloweBrainTierDeepDetail =>
      'The most thoughtful, needs the most space';

  @override
  String get reportFactDeviceId => 'Device ID';

  @override
  String get reportFactUserId => 'User ID';

  @override
  String get reportFactUsername => 'Username';

  @override
  String get reportFactApp => 'App';

  @override
  String get reportFactDevice => 'Device';

  @override
  String get reportFactSystem => 'System';

  @override
  String get reportFactDisplay => 'Display';

  @override
  String get reportFactAppLanguage => 'App language';

  @override
  String get reportFactSystemLocale => 'System locale';

  @override
  String get reportFactLog => 'Log';

  @override
  String reportFactLogValue(int count) {
    return '$count events attached';
  }

  @override
  String reportProblemScreenshotN(int n) {
    return 'Screenshot $n';
  }

  @override
  String reportProblemRemoveScreenshot(int n) {
    return 'Remove screenshot $n';
  }

  @override
  String get reportFactLanguageFromSystem => 'from system';

  @override
  String get reportFactLanguageChosen => 'chosen';

  @override
  String get pageSectionSeeAll => 'See all';

  @override
  String get discoverScreenSeeAllFriendsSemanticLabel => 'See all friends';

  @override
  String get discoverScreenSeeAllRoomsSemanticLabel => 'See all your rooms';

  @override
  String groupCallScreenRingingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ringing',
    );
    return '$_temp0';
  }

  @override
  String photoChromeWhenToday(String time) {
    return 'Today at $time';
  }

  @override
  String photoChromeWhenYesterday(String time) {
    return 'Yesterday at $time';
  }

  @override
  String photoChromeWhenDate(String date, String time) {
    return '$date at $time';
  }

  @override
  String get photoChromeSaved => 'Saved';

  @override
  String get photoChromeSaveFailed => 'Couldn’t save that';

  @override
  String get photoChromeShareFailed => 'Couldn’t share that';

  @override
  String photoChromeForwarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Forwarded to $count chats',
      one: 'Forwarded',
    );
    return '$_temp0';
  }

  @override
  String get photoChromeForwardFailed => 'Couldn’t forward that';

  @override
  String get photoChromeDeleteFailed => 'Couldn’t delete that';

  @override
  String get photoChromeDeleteBody =>
      'This removes it for everyone in this chat. It can’t be undone.';

  @override
  String get roomContentMonthThis => 'This month';

  @override
  String get roomContentMonthLast => 'Last month';

  @override
  String get gameInfoGoalLabel => 'Goal';

  @override
  String get gameInfoExampleLabel => 'Example';

  @override
  String get gameInfoWinLabel => 'How you win';

  @override
  String get gameInfoQueensRule4 =>
      'Crowns can\'t touch. Not even corner to corner.';

  @override
  String get gameInfoQueensExample =>
      'One crown here means: no other crown in its row, its column, its colour, or the 8 squares around it.';

  @override
  String get gameInfoTangoRule4 =>
      '= means the 2 squares match. × means they\'re different.';

  @override
  String get gameInfoTangoExample =>
      'Sun, sun, empty? The empty square must be a moon.';

  @override
  String get gameInfoZipRule4 => 'Move up, down, left or right. No diagonals.';

  @override
  String get gameInfoZipRule5 => 'Finish on the last number.';

  @override
  String get gameInfoZipExample =>
      'Going from 1 to 2? Take the long way if you must. No square can be left empty.';

  @override
  String get gameInfoSudokuExample =>
      'A row already has 1, 2, 4, 5 and 6? The empty square is 3.';

  @override
  String get gameInfoCodeRule4 => 'Yellow: right symbol, wrong spot.';

  @override
  String get gameInfoCodeRule5 => 'Grey: that symbol isn\'t in the code.';

  @override
  String get gameInfoCodeExample =>
      'Green, yellow, grey, grey means: 1 symbol is in the right spot, 1 belongs somewhere else, 2 aren\'t in the code.';

  @override
  String get leaderboardOverall => 'Today';

  @override
  String get leaderboardFooter =>
      '1 point for every puzzle you solve today. A tie goes to whoever came first more often.';

  @override
  String get leaderboardNotPlayed => 'Not played yet';

  @override
  String get leaderboardPlay => 'Play';

  @override
  String get leaderboardEmptyTitle => 'No scores yet today';

  @override
  String get leaderboardEmptyBody =>
      'Solve a puzzle and you\'ll be first on the board.';

  @override
  String get pointComposerPickFirst => 'Pick one above first';

  @override
  String get momentStoryNext => 'Next';

  @override
  String get momentStoryPrevious => 'Previous';

  @override
  String leaderboardSolved(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      solved,
      locale: localeName,
      other: '$solved of $total solved',
      zero: 'Nothing solved yet',
    );
    return '$_temp0';
  }

  @override
  String leaderboardWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wins',
      one: '1 win',
    );
    return '$_temp0';
  }

  @override
  String leaderboardEmptyAction(String game) {
    return 'Play $game';
  }

  @override
  String get diagCatApi => 'Server calls';

  @override
  String get diagCatConnection => 'Connection';

  @override
  String get diagCatDevice => 'Device';

  @override
  String get diagCatError => 'Errors';

  @override
  String get diagCatFrame => 'Slow frames';

  @override
  String get diagCatLayout => 'Layout';

  @override
  String get diagCatLifecycle => 'App state';

  @override
  String get diagCatLog => 'Log';

  @override
  String get diagCatNav => 'Navigation';

  @override
  String get diagCatNetwork => 'Network';

  @override
  String get diagCatSubscription => 'Live updates';

  @override
  String get diagSevTrace => 'Trace';

  @override
  String get diagSevDebug => 'Debug';

  @override
  String get diagSevInfo => 'Info';

  @override
  String get diagSevWarning => 'Warning';

  @override
  String get diagSevError => 'Error';

  @override
  String get diagAll => 'All';

  @override
  String get diagSearchHint => 'Search name, detail, body';

  @override
  String get diagSummaryCopied => 'Summary copied';

  @override
  String get diagShareLog => 'Share log';

  @override
  String get diagCopySummary => 'Copy summary';

  @override
  String get diagDeleteAll => 'Delete all';

  @override
  String get diagUndo => 'Undo';

  @override
  String get diagDeleteLogTitle => 'Delete the whole log?';

  @override
  String get diagDeleteLogBody =>
      'Every event captured so far goes, along with the previous run\'s log. Anything that happens from now on is captured as usual.';

  @override
  String get diagDelete => 'Delete';

  @override
  String get diagLogDeleted => 'Log deleted';

  @override
  String get diagFilter => 'Filter';

  @override
  String get diagMore => 'More';

  @override
  String get diagLatest => 'Latest';

  @override
  String get diagJumpToLatest => 'Jump to latest';

  @override
  String get diagPaused => 'paused';

  @override
  String get diagPreparingLog => 'preparing log…';

  @override
  String get diagEmptyNothingTitle => 'Nothing captured yet';

  @override
  String get diagEmptyNothingHint =>
      'Use the app for a moment and events will appear here.';

  @override
  String get diagEmptyHiddenTitle => 'Only hidden events so far';

  @override
  String get diagEmptyHiddenHint =>
      'Tap a dimmed chip above to see it, or long-press it to bring it back into All.';

  @override
  String get diagEmptyNoMatchTitle => 'No events match';

  @override
  String get diagEmptyNoMatchHint => 'Tap All above to clear the filter.';

  @override
  String get diagApply => 'Apply';

  @override
  String get diagMinSeverity => 'Minimum severity';

  @override
  String get diagEverything => 'Everything';

  @override
  String get diagHiddenFromAllHeader => 'Hidden from All';

  @override
  String get diagHiddenFromAllFooter =>
      'Left out of All until picked on the chip row. Long-press a chip there for the same switch.';

  @override
  String get diagCollapseRepeats => 'Collapse repeats';

  @override
  String get diagCollapseRepeatsSubtitle =>
      'Fold a run of the same event into one row';

  @override
  String get diagResetFilter => 'Reset filter';

  @override
  String get diagBodyTruncated => 'Body truncated at capture';

  @override
  String get diagCopyEvent => 'Copy event';

  @override
  String get diagEventCopied => 'Event copied';

  @override
  String diagHiddenFromAll(String category) {
    return '$category hidden from All';
  }

  @override
  String diagBackInAll(String category) {
    return '$category back in All';
  }

  @override
  String diagChipSemanticLabel(String category, int count) {
    return '$category, $count';
  }

  @override
  String diagChipHiddenSemanticLabel(String category, int count) {
    return '$category, $count, hidden from All';
  }

  @override
  String diagEventCount(int shown, int total) {
    return '$shown of $total events';
  }

  @override
  String diagDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count earlier events dropped, so the log starts mid-story',
      one: '$count earlier event dropped, so the log starts mid-story',
    );
    return '$_temp0';
  }

  @override
  String diagRepeatSpan(int count, String seconds) {
    return '×$count over ${seconds}s';
  }

  @override
  String roomContentTabSemantic(String count, String label) {
    return '$label, $count items';
  }

  @override
  String get mapAppsTitle => 'Maps';

  @override
  String get mapAppsChoose => 'Open location in';

  @override
  String get mapAppsRemember => 'Use as default';

  @override
  String get mapAppsAskEveryTime => 'Ask every time';

  @override
  String get mapAppsBrowser => 'Browser';

  @override
  String get mapAppsSubtitle => 'Choose where shared locations open.';

  @override
  String get mapAppsUnavailable =>
      'Your default maps app is unavailable. Choose another.';

  @override
  String get mapAppsNoInstalled =>
      'No supported maps apps found. You can use your browser.';

  @override
  String get interactionAnswersSearch => 'Search people or answers';

  @override
  String get interactionFilterEmpty => 'No answers match this filter.';

  @override
  String get interactionRetry => 'Try again';

  @override
  String get cameraEditorScreenCaptionHint => 'Add a caption…';

  @override
  String get cameraEditorScreenCaptionViewOnceHint =>
      'No captions on view-once photos';

  @override
  String get cameraEditorScreenAddFromCameraSemanticLabel =>
      'Take another photo';

  @override
  String cameraEditorScreenDiscardAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Discard $count photos?',
      one: 'Discard this photo?',
    );
    return '$_temp0';
  }

  @override
  String get cameraEditorScreenDiscardAllBody =>
      'Your edits and captions will be lost.';

  @override
  String get cameraEditorScreenDiscardAllConfirm => 'Discard';

  @override
  String get galleryTrayRecentsTitle => 'Recents';

  @override
  String get galleryTrayBackToCameraLabel => 'Back to camera';

  @override
  String get galleryTrayAllPhotosLabel => 'All photos';

  @override
  String get galleryTrayHandleLabel => 'Recent photos';

  @override
  String get galleryTrayAllowPrompt => 'See your recent photos here';

  @override
  String get galleryTrayAllowButton => 'Allow';

  @override
  String get galleryTrayDeniedPrompt => 'Photo access is off';

  @override
  String get galleryTraySettingsButton => 'Settings';

  @override
  String get galleryTrayLimitedNote => 'Showing only the photos you’ve allowed';

  @override
  String get galleryTrayManageButton => 'Manage';

  @override
  String get galleryTrayEmpty => 'No photos yet';

  @override
  String galleryTrayAddSelectedButton(int count) {
    return 'Add ($count)';
  }

  @override
  String get galleryTrayCancelSelectionLabel => 'Cancel selection';

  @override
  String galleryTraySelectedTitle(int count) {
    return '$count selected';
  }

  @override
  String galleryTrayPhotoLabel(int index) {
    return 'Photo $index';
  }

  @override
  String get reactionLimitTitle => 'You\'ve reached the reaction limit';

  @override
  String reactionLimitMessageBody(int limit) {
    return 'For the sake of speed, sanity and letting every emoji shine, you can add up to $limit reactions to a message, but no more. Take one back to make room for another.';
  }

  @override
  String reactionLimitHighlightBody(int limit) {
    return 'Highlights keep it to $limit reactions per person, so each one still says something. Take one back to make room for a new favorite.';
  }

  @override
  String get reactionLimitDismiss => 'Got it';

  @override
  String get reactionPickerYoursLabel => 'Your reactions';

  @override
  String reactionPickerTakeBackSemantic(String emoji) {
    return 'Remove your $emoji reaction';
  }

  @override
  String get momentCommentsTitle => 'Comments';

  @override
  String momentCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
      zero: 'Comment',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentsEmptyTitle => 'No comments yet';

  @override
  String get momentCommentsEmptyBody =>
      'Start the conversation with a few words, a sticker or a GIF.';

  @override
  String get momentCommentHint => 'Add a comment…';

  @override
  String momentCommentReplyHint(String name) {
    return 'Reply to $name…';
  }

  @override
  String momentCommentReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get momentCommentCancelReply => 'Cancel reply';

  @override
  String get momentCommentReply => 'Reply';

  @override
  String momentCommentViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'View $count replies',
      one: 'View 1 reply',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentHideReplies => 'Hide replies';

  @override
  String get momentCommentDelete => 'Delete comment';

  @override
  String get momentCommentDeleteConfirm =>
      'Delete this comment? Any replies to it go too.';

  @override
  String get momentCommentDeleteConfirmButton => 'Delete';

  @override
  String get momentCommentSend => 'Send';

  @override
  String get momentCommentExpressions => 'Stickers and GIFs';

  @override
  String get momentCommentFailed => 'Couldn\'t post your comment. Try again.';

  @override
  String get momentCommentAuthorBadge => 'Author';

  @override
  String get momentCommentLike => 'Like';

  @override
  String get momentCommentStickerAlt => 'Sticker';

  @override
  String get momentCommentGifAlt => 'GIF';

  @override
  String get momentCommentPosted => 'Comment posted';

  @override
  String momentCommentsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'View all $count comments',
      one: 'View 1 comment',
    );
    return '$_temp0';
  }

  @override
  String momentReactorsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count others',
      one: '1 other',
    );
    return '$name and $_temp0';
  }

  @override
  String get storageKindPhotos => 'Photos';

  @override
  String get storageKindVideos => 'Videos';

  @override
  String get storageKindVideoMessages => 'Video messages';

  @override
  String get storageKindVoice => 'Voice messages';

  @override
  String get storageKindFiles => 'Files';

  @override
  String get storageKindStickers => 'Stickers and GIFs';

  @override
  String get storageKindChatHistory => 'Chat history';

  @override
  String get storageKindOther => 'Other';

  @override
  String get dataUsageKindCalls => 'Calls';

  @override
  String get dataStorageTitle => 'Data and Storage';

  @override
  String get settingsSearchKwDataStorage =>
      'storage cache memory space clear download auto download data usage cellular mobile wifi save to photos gallery';

  @override
  String get storageUsageTitle => 'Storage Usage';

  @override
  String get dataUsageTitle => 'Data Usage';

  @override
  String get dataStorageAutoDownloadHeader => 'Automatic media download';

  @override
  String get dataStorageUsingCellular => 'Using Cellular';

  @override
  String get dataStorageUsingWifi => 'Using Wi-Fi';

  @override
  String get dataStorageNowTag => 'Now';

  @override
  String get autoDownloadReset => 'Reset auto-download settings';

  @override
  String get autoDownloadResetTitle =>
      'Restore the default auto-download settings?';

  @override
  String get dataStorageSaveHeader => 'Save to Photos';

  @override
  String get dataStorageSaveFooter =>
      'Automatically save new photos and videos from these chats to your photo library.';

  @override
  String get dataStorageCallsHeader => 'Calls';

  @override
  String get dataStorageLessDataForCalls => 'Use less data for calls';

  @override
  String get dataStorageCallsFooter =>
      'Uses less data on weak or metered networks, with slightly lower audio and video quality.';

  @override
  String get dataStorageCallsNever => 'Never';

  @override
  String get dataStorageCallsCellular => 'On cellular';

  @override
  String get dataStorageCallsAlways => 'Always';

  @override
  String get dataStorageOff => 'Off';

  @override
  String get dataStorageChatsPrivate => 'Private chats';

  @override
  String get dataStorageChatsGroups => 'Groups';

  @override
  String get dataStorageChatsPublic => 'Public rooms';

  @override
  String get dataStorageNetCellular => 'Cellular';

  @override
  String get dataStorageNetWifi => 'Wi-Fi';

  @override
  String get autoDownloadMaster => 'Auto-download media';

  @override
  String get autoDownloadUsageHeader => 'Data usage';

  @override
  String get autoDownloadPresetLow => 'Low';

  @override
  String get autoDownloadPresetMedium => 'Medium';

  @override
  String get autoDownloadPresetHigh => 'High';

  @override
  String get autoDownloadCustomFooter =>
      'You\'ve customized these settings. Move the slider to switch back to a preset.';

  @override
  String get autoDownloadTypesHeader => 'Types of media';

  @override
  String get autoDownloadVideosTitle => 'Videos and video messages';

  @override
  String get autoDownloadVoiceFooter =>
      'Voice messages and stickers are tiny, so they always download automatically.';

  @override
  String get autoDownloadAllChats => 'All chats';

  @override
  String autoDownloadUpToIn(String size, String chats) {
    return '$chats, up to $size';
  }

  @override
  String autoDownloadSummaryUpTo(String kind, String size) {
    return '$kind up to $size';
  }

  @override
  String get autoDownloadSummaryVoiceOnly => 'Voice messages only';

  @override
  String get autoDownloadInHeader => 'Download automatically in';

  @override
  String get autoDownloadMaxSizeHeader => 'Maximum file size';

  @override
  String autoDownloadMaxSizeVideoFooter(String size) {
    return 'Videos up to $size download automatically. Larger ones wait for a tap.';
  }

  @override
  String autoDownloadMaxSizeFileFooter(String size) {
    return 'Files up to $size download automatically. Larger ones wait for a tap.';
  }

  @override
  String get autoDownloadGateLoad => 'Download photo';

  @override
  String get saveToPhotosHeader => 'Save automatically';

  @override
  String get saveToPhotosFooter =>
      'New photos and videos you receive in these chats are added to your photo library as they download.';

  @override
  String get saveToPhotosMaxVideoHeader => 'Maximum video size';

  @override
  String get saveToPhotosNoAccess =>
      'Allow photo library access in Settings to save automatically.';

  @override
  String get saveToPhotosPhotosAndVideos => 'Photos and videos';

  @override
  String get storageCalculating => 'Calculating…';

  @override
  String storageShareOfFree(String percent) {
    return 'MonkeyHub uses $percent of your free space.';
  }

  @override
  String get storageEmpty => 'Nothing is cached right now.';

  @override
  String storageClearAllButton(String size) {
    return 'Clear entire cache $size';
  }

  @override
  String storageClearSelectedButton(String size) {
    return 'Clear selected $size';
  }

  @override
  String storageClearChatButton(String size) {
    return 'Clear cache $size';
  }

  @override
  String get storageClearFooter =>
      'Everything stays in the cloud and downloads again whenever you need it.';

  @override
  String get storageClearAllTitle => 'Clear the entire cache?';

  @override
  String get storageClearSelectedTitle => 'Clear the selected items?';

  @override
  String get storageClearBody =>
      'Your messages stay. Media downloads again when you open it.';

  @override
  String storageClearConfirm(String size) {
    return 'Clear $size';
  }

  @override
  String storageFreed(String size) {
    return 'Freed $size';
  }

  @override
  String storageCleanupTitle(String size) {
    return 'Free up $size';
  }

  @override
  String get storageCleanupSubtitle => 'Media you haven\'t opened in a month';

  @override
  String get storageCleanupAction => 'Clean';

  @override
  String get storageCleanupFooter =>
      'Only clears media nobody has looked at in 30 days. Saved Messages is never touched.';

  @override
  String get storageAutoRemoveHeader => 'Auto-remove cached media';

  @override
  String get storageAutoRemoveFooter =>
      'Media you haven\'t opened for this long is removed from this device to save space. It stays in the cloud, and Saved Messages is always kept.';

  @override
  String get dataStorageKeepNever => 'Never';

  @override
  String get dataStorageKeepMonth => '1 month';

  @override
  String get dataStorageKeepWeek => '1 week';

  @override
  String get dataStorageKeepDay => '1 day';

  @override
  String get storageLimitHeader => 'Maximum cache size';

  @override
  String get storageLimitFooter =>
      'If the cache grows past this, the media you opened longest ago is removed first.';

  @override
  String get dataStorageLimitNone => 'No limit';

  @override
  String get storageTabChats => 'Chats';

  @override
  String get storageTabMedia => 'Media';

  @override
  String get storageTabFiles => 'Files';

  @override
  String get storageNoChats => 'No chat has anything cached yet.';

  @override
  String get storageNoMedia => 'No photos or videos are cached yet.';

  @override
  String get storageNoFiles => 'No files are cached yet.';

  @override
  String get storageOpenPhoto => 'Open photo';

  @override
  String get storageOpenVideo => 'Open video';

  @override
  String get storageSelect => 'Select';

  @override
  String storageChatShare(String percent) {
    return 'This chat uses $percent of your cache.';
  }

  @override
  String get storageChatUnknown => 'Chat you left';

  @override
  String dataUsageSince(String date) {
    return 'Since $date';
  }

  @override
  String get dataUsageAll => 'All';

  @override
  String get dataUsageNothingYet =>
      'Nothing has been counted on this network yet.';

  @override
  String get dataUsageTapHint =>
      'Tap a category to see what was sent and received.';

  @override
  String get dataUsageSent => 'Sent';

  @override
  String get dataUsageReceived => 'Received';

  @override
  String get dataUsageTotalHeader => 'Total network usage';

  @override
  String get dataUsageFootnote =>
      'Counts media and calls. Messages themselves are tiny and aren\'t included.';

  @override
  String get dataUsageReset => 'Reset statistics';

  @override
  String get dataUsageResetTitle => 'Reset data usage statistics?';

  @override
  String get dataUsageResetBody => 'Counting starts again from now.';

  @override
  String get storageKindCompanions => 'Companions';

  @override
  String get storageCompanionsNote =>
      'Companions aren\'t cleared with the cache. Tap them to manage their downloads.';

  @override
  String storageCategoryCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items, $size',
      one: '1 item, $size',
    );
    return '$_temp0';
  }

  @override
  String get storageSelectAll => 'Select all';

  @override
  String get storageDeselectAll => 'Deselect all';

  @override
  String get storageCategoryEmpty =>
      'Nothing of this kind is cached right now.';

  @override
  String get storageChatHistoryFooter =>
      'Only the copy on this device is removed. Messages stay in the chat and load again the next time you open it.';

  @override
  String get storageCategoryHint =>
      'Tap a category to see what\'s inside, or its circle to leave it out.';

  @override
  String storageChatRemovedNamed(String names) {
    return '$names · removed chat';
  }

  @override
  String get streaksLabel => 'Streaks';

  @override
  String get streakAtRiskFooter => 'Play today to keep your streak.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count day streak',
      one: '1 day streak',
    );
    return '$_temp0';
  }

  @override
  String recordsCheersMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String get recordsCheer => 'Cheer';

  @override
  String get myStreaksLabel => 'My streaks';

  @override
  String streakLongest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Your longest: $_temp0';
  }

  @override
  String get streaksEmpty => 'Nobody is on a streak here yet.';

  @override
  String videoTooLargeSnack(String size) {
    return 'Videos are capped at $size';
  }

  @override
  String videoShrinkPromptTitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos are over $size',
      one: 'This video is over $size',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkPromptBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'They\'ll be squeezed down to fit, so expect them to look a lot softer.',
      one: 'It\'ll be squeezed down to fit, so expect it to look a lot softer.',
    );
    return '$_temp0';
  }

  @override
  String get videoShrinkPromptAction => 'Compress and send';

  @override
  String get videoShrinkWorkingSnack => 'Compressing video…';

  @override
  String videoShrinkFailedSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos are too long to fit in $size, even compressed',
      one: 'Too long to fit in $size, even compressed',
    );
    return '$_temp0';
  }

  @override
  String photoHdOverCapSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos were over $size, so they went at standard quality',
      one: '1 photo was over $size, so it went at standard quality',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkSendSmallOnly(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Send only the $count under $size',
      one: 'Send only the one under $size',
    );
    return '$_temp0';
  }

  @override
  String get kbdGroupGeneral => 'General';

  @override
  String get kbdGroupNavigation => 'Navigation';

  @override
  String get kbdGroupChat => 'In a chat';

  @override
  String get kbdGroupComposer => 'Writing';

  @override
  String get kbdGroupViewer => 'Photos and videos';

  @override
  String get kbdGroupCall => 'Calls';

  @override
  String get kbdCommandPalette => 'Search chats and commands';

  @override
  String get kbdShowShortcuts => 'Keyboard shortcuts';

  @override
  String get kbdSearch => 'Search';

  @override
  String get kbdNewChat => 'New chat';

  @override
  String get kbdSettings => 'Settings';

  @override
  String get kbdBack => 'Go back or close';

  @override
  String kbdGoTo(String section) {
    return 'Go to $section';
  }

  @override
  String get kbdNextChat => 'Next chat';

  @override
  String get kbdPreviousChat => 'Previous chat';

  @override
  String get kbdNextUnread => 'Next unread chat';

  @override
  String get kbdCloseChat => 'Close chat';

  @override
  String get kbdRoomInfo => 'Chat info';

  @override
  String get kbdSearchInChat => 'Search in this chat';

  @override
  String get kbdJumpToLatest => 'Jump to latest message';

  @override
  String get kbdAttach => 'Attach files';

  @override
  String get kbdVoiceCall => 'Voice call';

  @override
  String get kbdVideoCall => 'Video call';

  @override
  String get kbdSend => 'Send';

  @override
  String get kbdNewline => 'New line';

  @override
  String get kbdEditLast => 'Edit your last message';

  @override
  String get kbdBold => 'Bold';

  @override
  String get kbdItalic => 'Italic';

  @override
  String get kbdUnderline => 'Underline';

  @override
  String get kbdPasteMedia => 'Paste a photo or file';

  @override
  String get kbdEmoji => 'Emoji and stickers';

  @override
  String get kbdViewerPrevious => 'Previous';

  @override
  String get kbdViewerNext => 'Next';

  @override
  String get kbdZoomIn => 'Zoom in';

  @override
  String get kbdZoomOut => 'Zoom out';

  @override
  String get kbdZoomFit => 'Fit to window';

  @override
  String get kbdPlayPause => 'Play or pause';

  @override
  String get kbdCopyMedia => 'Copy';

  @override
  String get kbdSaveMedia => 'Save';

  @override
  String get kbdToggleMute => 'Mute or unmute';

  @override
  String get kbdToggleCamera => 'Camera on or off';

  @override
  String get kbdHangUp => 'Hang up';

  @override
  String get kbdGroupApp => 'App';

  @override
  String get kbdCloseWindow => 'Close window';

  @override
  String get kbdMinimizeWindow => 'Minimize';

  @override
  String get kbdFullScreen => 'Full screen';

  @override
  String get kbdHideApp => 'Hide MonkeyHub';

  @override
  String get kbdQuit => 'Quit MonkeyHub';

  @override
  String get kbdPanelTitle => 'Keyboard Shortcuts';

  @override
  String get kbdPanelSearchHint => 'Search shortcuts';

  @override
  String get kbdPanelEmpty => 'No shortcuts match';

  @override
  String kbdPeekHint(String key) {
    return 'Hold $key anytime to see the shortcuts for the screen you\'re on';
  }

  @override
  String kbdPeekSetting(String key) {
    return 'Show shortcuts while holding $key';
  }

  @override
  String get kbdPaletteHint => 'Jump to a chat or run a command';

  @override
  String get kbdPaletteChats => 'Chats';

  @override
  String get kbdPaletteCommands => 'Commands';

  @override
  String get kbdPaletteEmpty => 'Nothing found';

  @override
  String get kbdPaletteMove => 'Move';

  @override
  String get kbdPaletteOpen => 'Open';

  @override
  String get kbdPaletteClose => 'Close';

  @override
  String get msgDeskReactLabel => 'React';

  @override
  String get msgDeskMoreLabel => 'More';

  @override
  String get msgDeskInfoLabel => 'Info';

  @override
  String get kbdSeekBackward => 'Back 5 seconds';

  @override
  String get kbdSeekForward => 'Forward 5 seconds';

  @override
  String get kbdMuteVideo => 'Mute or unmute video';

  @override
  String get viewerSavedToDownloads => 'Saved to Downloads';

  @override
  String get viewerDownloaded => 'Downloaded';

  @override
  String get viewerShowInFinder => 'Show in Finder';

  @override
  String get viewerShowInFolder => 'Show in folder';

  @override
  String get viewerCopied => 'Copied';

  @override
  String get viewerCopyFailed => 'Couldn’t copy that';

  @override
  String get hoverCompactLayoutTitle => 'Compact layout';

  @override
  String get hoverCompactLayoutSubtitle =>
      'Shorter rows and smaller buttons, sized for a mouse and a big screen.';

  @override
  String get layoutPagerPrevious => 'Previous';

  @override
  String get layoutPagerNext => 'Next';

  @override
  String get resultSheetMistakes => 'Mistakes';

  @override
  String get resultSheetHints => 'Hints';

  @override
  String get resultSheetStreak => 'Streak';

  @override
  String resultSheetStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get resultSheetNone => 'None';

  @override
  String resultSheetToday(String game) {
    return '$game · Today';
  }

  @override
  String resultSheetYouFaster(String time) {
    return 'You were $time faster';
  }

  @override
  String resultSheetTheyFaster(String name, String time) {
    return '$name was $time faster';
  }

  @override
  String get resultSheetSameTime => 'Same time as you';

  @override
  String get resultSheetFooter =>
      'Only the time decides the ranking. Mistakes and hints are just for the curious.';

  @override
  String get resultSheetHintNoRecord =>
      'Solved with hints, so it can’t set an all-time record.';

  @override
  String get gameTierEasy => 'Easy';

  @override
  String get gameTierMedium => 'Medium';

  @override
  String get gameTierHard => 'Hard';

  @override
  String get gameComingSoon => 'Coming soon';

  @override
  String get gameComingSoonName => 'New puzzle';

  @override
  String get chatGameNameTicTacToe => 'Tic-tac-toe';

  @override
  String get chatGameNameConnectFour => 'Connect Four';

  @override
  String get chatGameNameCheckers => 'Checkers';

  @override
  String get chatGameNameReversi => 'Reversi';

  @override
  String get chatGameNameDots => 'Dots and Boxes';

  @override
  String get chatGameDescTicTacToe => 'Three in a row wins.';

  @override
  String get chatGameDescConnectFour => 'Drop discs. Four in a row wins.';

  @override
  String get chatGameDescCheckers => 'Jump to capture. Take every piece.';

  @override
  String get chatGameDescReversi => 'Outflank to flip. Most discs wins.';

  @override
  String get chatGameDescDots => 'Draw lines, close boxes, go again.';

  @override
  String get chatGameKindLive => 'Live game';

  @override
  String get chatGameKindTurns => 'Turn by turn';

  @override
  String get chatGameStatusWaiting => 'Waiting';

  @override
  String get chatGameStatusPlaying => 'Playing';

  @override
  String get chatGameStatusPaused => 'Paused';

  @override
  String get chatGameStatusFinished => 'Finished';

  @override
  String get chatGameStatusEnded => 'Ended';

  @override
  String get chatGameYourMove => 'Your move';

  @override
  String chatGameTurnOf(String name) {
    return '$name\'s move';
  }

  @override
  String chatGameWaitingFor(String name) {
    return 'Waiting for $name';
  }

  @override
  String chatGameWonBy(String name) {
    return '$name won';
  }

  @override
  String get chatGameYouWon => 'You won';

  @override
  String get chatGameDraw => 'Draw';

  @override
  String get chatGameNobodyWon => 'Everyone left, so nobody won';

  @override
  String chatGameReasonTimeout(String name) {
    return '$name ran out of time';
  }

  @override
  String chatGameReasonResign(String name) {
    return '$name resigned';
  }

  @override
  String chatGameReasonLeft(String name) {
    return '$name left';
  }

  @override
  String get chatGameOpenSeat => 'Open seat';

  @override
  String get chatGameReady => 'Ready';

  @override
  String get chatGameNotReady => 'Not ready';

  @override
  String chatGameWatchingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count watching',
      one: '1 watching',
    );
    return '$_temp0';
  }

  @override
  String get chatGameJoin => 'Join';

  @override
  String get chatGameWatch => 'Watch';

  @override
  String get chatGamePlay => 'Play';

  @override
  String get chatGameOpen => 'Open';

  @override
  String get chatGameRematch => 'Rematch';

  @override
  String get chatGameNotRanked =>
      'Just for fun. Chat games don’t count toward your streaks or records.';

  @override
  String get chatGameNotRankedShort => 'Not ranked';

  @override
  String get chatGameImReady => 'I’m ready';

  @override
  String get chatGameUnready => 'Not ready yet';

  @override
  String get chatGameTakeSeat => 'Tap to join';

  @override
  String get chatGameLeaveSeat => 'Leave seat';

  @override
  String get chatGameStartsWhenReady => 'Starts when everyone is ready';

  @override
  String chatGameNeedPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Waiting for $count more players',
      one: 'Waiting for 1 more player',
    );
    return '$_temp0';
  }

  @override
  String get chatGameWatchingLabel => 'Watching';

  @override
  String get chatGameAskSwap => 'Ask to swap in';

  @override
  String chatGameSwapRequest(String name) {
    return '$name wants to swap in';
  }

  @override
  String get chatGameSwap => 'Swap';

  @override
  String get chatGameDecline => 'Decline';

  @override
  String get chatGameAccept => 'Accept';

  @override
  String chatGameSwapAsked(String name) {
    return 'Asked $name';
  }

  @override
  String get chatGameCancel => 'Cancel';

  @override
  String get chatGameResign => 'Resign';

  @override
  String get chatGameResignConfirm => 'Resign this game?';

  @override
  String get chatGameResignBody => 'It counts as a loss for you.';

  @override
  String get chatGameOfferDraw => 'Offer draw';

  @override
  String get chatGameDrawOffered => 'Draw offered';

  @override
  String chatGameDrawOfferFrom(String name) {
    return '$name offers a draw';
  }

  @override
  String chatGamePausedTitle(String name) {
    return '$name left the game';
  }

  @override
  String get chatGamePausedMany => 'Players left the game';

  @override
  String get chatGamePausedBody => 'We’ll hold the board for a bit.';

  @override
  String get chatGamePausedYou => 'The game resumes when everyone is back.';

  @override
  String get chatGameLeave => 'Leave game';

  @override
  String get chatGameGo => 'Go!';

  @override
  String get chatGameNudge => 'Nudge';

  @override
  String get chatGameNudged => 'Nudged';

  @override
  String chatGameHoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours left',
      one: '1 hour left',
    );
    return '$_temp0';
  }

  @override
  String chatGameMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes left',
      one: '1 minute left',
    );
    return '$_temp0';
  }

  @override
  String get chatGameMoveFailed => 'That move didn’t go through';

  @override
  String get chatGameStale => 'The board changed. Try again.';

  @override
  String get chatGameStartTitle => 'Play a game';

  @override
  String get chatGameMenuItem => 'Game';

  @override
  String get chatGameModeLive => 'Live';

  @override
  String get chatGameModeTurns => 'Take turns';

  @override
  String get chatGameModeBot => 'Vs bot';

  @override
  String get chatGameModeLiveHint =>
      'Everyone plays at once. Leaving pauses the game.';

  @override
  String get chatGameModeTurnsHint =>
      'Move whenever you like. You each get a notification on your turn, and a turn lasts up to 2 days.';

  @override
  String get chatGameModeBotHint =>
      'Just you and the bot. Nothing is posted in the chat.';

  @override
  String get chatGameBotEasyHint => 'Makes mistakes. Good for learning.';

  @override
  String get chatGameBotMediumHint => 'Plays fair and blocks your wins.';

  @override
  String get chatGameBotHardHint => 'Thinks several moves ahead.';

  @override
  String get chatGameStart => 'Start';

  @override
  String get chatGameErrAlreadyLive =>
      'There’s already a live game here. Finish it or leave it first.';

  @override
  String get chatGameErrTooMany =>
      'You already have 3 turn games going here. Finish one first.';

  @override
  String get chatGameErrGeneric => 'Something went wrong. Try again.';

  @override
  String get chatGamePlayersTwo => '2 players';

  @override
  String get chatGamePlayersUpToFour => '2–4 players';

  @override
  String get chatGameBotName => 'Monkey';

  @override
  String get chatGameBotBadge => 'Bot';

  @override
  String get chatGameNewGame => 'New game';

  @override
  String chatGameBannerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count games',
      one: '1 game',
    );
    return '$_temp0';
  }

  @override
  String chatGameBannerYourMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Your move in $count',
      one: 'Your move in 1',
    );
    return '$_temp0';
  }

  @override
  String get chatGameSheetTitle => 'Games in this chat';

  @override
  String get chatGameGone => 'This game isn’t available any more.';

  @override
  String get chatGameSeatsLabel => 'Players';

  @override
  String get gameFlowName => 'Flow';

  @override
  String get gameFutoshikiName => 'Futoshiki';

  @override
  String get gameNonogramName => 'Nonogram';

  @override
  String get gameMinesweeperName => 'Minesweeper';

  @override
  String get gameStarbattleName => 'Star battle';

  @override
  String get gameFlowRule => 'join matching dots, fill every square';

  @override
  String get gameFutoshikiRule =>
      '1 to 5 once per row and column, every sign true';

  @override
  String get gameNonogramRule => 'shade squares to match every clue';

  @override
  String get gameMinesweeperRule =>
      'open every safe square, no guessing needed';

  @override
  String get gameStarbattleRule =>
      'two stars per row, column and colour, never touching';

  @override
  String get gameFlag => 'Flag';

  @override
  String get gameAutoDot => 'Auto-dot';

  @override
  String get gameInfoFlowGoal =>
      'Join every pair of matching dots with a pipe.';

  @override
  String get gameInfoFlowRule1 =>
      'Each pipe joins 2 dots of the same colour and number.';

  @override
  String get gameInfoFlowRule2 => 'Pipes can\'t cross or share a square.';

  @override
  String get gameInfoFlowRule3 => 'Fill every square. None can be left empty.';

  @override
  String get gameInfoFlowRule4 => 'Move up, down, left or right. No diagonals.';

  @override
  String get gameInfoFlowExample =>
      'No straight way through? Bend the pipe around the others. Every square still has to be filled.';

  @override
  String get gameInfoFlowControls =>
      'Drag from a dot to draw its pipe. Drag back to undo. Drawing across a pipe cuts it.';

  @override
  String get gameInfoFutoshikiGoal => 'Fill the grid with the numbers 1 to 5.';

  @override
  String get gameInfoFutoshikiRule1 =>
      'Every row has 1, 2, 3, 4 and 5. No repeats.';

  @override
  String get gameInfoFutoshikiRule2 => 'Every column too.';

  @override
  String get gameInfoFutoshikiRule3 =>
      'A < or > between 2 squares must be true. It points at the smaller number.';

  @override
  String get gameInfoFutoshikiExample =>
      'A sign points at this square? Then it can\'t be 5, because its neighbour is bigger.';

  @override
  String get gameInfoFutoshikiControls =>
      'Tap a square, then a number. Tap the number again to erase. Notes adds small pencil marks.';

  @override
  String get gameInfoNonogramGoal =>
      'Shade squares to reveal the hidden picture.';

  @override
  String get gameInfoNonogramRule1 =>
      'The numbers by each row and column are its shaded runs, in order.';

  @override
  String get gameInfoNonogramRule2 =>
      'Runs are kept apart by at least 1 empty square.';

  @override
  String get gameInfoNonogramRule3 => '0 means the whole line is empty.';

  @override
  String get gameInfoNonogramExample =>
      'A row of 10 with the clue 10? Shade it all. With 4 4, both runs fit, with a gap between them.';

  @override
  String get gameInfoNonogramControls =>
      'Tap once to shade, twice for × (empty), again to clear. Drag to mark several squares at once.';

  @override
  String get gameInfoMinesweeperGoal => 'Open every square that isn\'t a mine.';

  @override
  String get gameInfoMinesweeperRule1 =>
      'A number says how many mines touch that square, corners included.';

  @override
  String get gameInfoMinesweeperRule2 =>
      'Every square can be worked out. You never have to guess.';

  @override
  String get gameInfoMinesweeperRule3 =>
      'Hit a mine and 30 seconds go on your time. Then keep going.';

  @override
  String get gameInfoMinesweeperExample =>
      'A 1 with only one closed square next to it? That square is the mine. Flag it.';

  @override
  String get gameInfoMinesweeperControls =>
      'Tap to open a square. Long-press, or switch on Flag, to mark a mine.';

  @override
  String get gameInfoStarbattleGoal =>
      'Put 2 stars in every row, column and colour.';

  @override
  String get gameInfoStarbattleRule1 => 'Every row gets exactly 2 stars.';

  @override
  String get gameInfoStarbattleRule2 => 'Every column gets exactly 2 stars.';

  @override
  String get gameInfoStarbattleRule3 => 'Every colour gets exactly 2 stars.';

  @override
  String get gameInfoStarbattleRule4 =>
      'Stars can\'t touch. Not even corner to corner.';

  @override
  String get gameInfoStarbattleExample =>
      'One star here means: no other star in the 8 squares around it, and one more to find in its row, column and colour.';

  @override
  String get gameInfoStarbattleControls =>
      'Tap once for a dot (no star here). Tap twice for a star. Tap again to clear.';

  @override
  String boardCellName(int row, int col) {
    return 'Row $row, column $col';
  }

  @override
  String get boardEmpty => 'empty';

  @override
  String get boardBlack => 'black';

  @override
  String get boardWhite => 'white';

  @override
  String get boardLegalMove => 'legal move';

  @override
  String get boardMoveHere => 'move here';

  @override
  String boardColumnFilled(int column, int count, int total) {
    return 'Column $column, $count of $total filled';
  }

  @override
  String boardSquareName(int number) {
    return 'Square $number';
  }

  @override
  String get boardDarkMan => 'dark piece';

  @override
  String get boardDarkKing => 'dark king';

  @override
  String get boardLightMan => 'light piece';

  @override
  String get boardLightKing => 'light king';

  @override
  String boardBoxName(String cell) {
    return 'Box, $cell';
  }

  @override
  String get boardOpen => 'open';

  @override
  String get boardDrawn => 'drawn';

  @override
  String boardClaimedBy(String name) {
    return 'claimed by $name';
  }

  @override
  String boardHorizontalEdge(int row, int col) {
    return 'Horizontal line, row $row, column $col';
  }

  @override
  String boardVerticalEdge(int row, int col) {
    return 'Vertical line, row $row, column $col';
  }

  @override
  String get challengeAction => 'Challenge';

  @override
  String get challengeTitle => 'Beat my time';

  @override
  String get challengeKind => 'Daily challenge';

  @override
  String challengeYouBeat(String time) {
    return 'You beat it by $time';
  }

  @override
  String challengeStillStanding(String time) {
    return 'Still standing, by $time';
  }

  @override
  String get challengeTie => 'A dead heat';

  @override
  String get challengeClosed => 'That board has closed';

  @override
  String get challengeYourTime => 'Your time to beat';

  @override
  String get challengeSent => 'Challenge sent';

  @override
  String challengeTarget(String name, String time) {
    return '$name $time';
  }

  @override
  String challengeBeatName(String name, String time) {
    return 'You beat $name’s $time';
  }

  @override
  String challengeKept(String name, String time) {
    return '$name keeps it, by $time';
  }

  @override
  String get chatGameNameLiarsDice => 'Liar’s Dice';

  @override
  String get chatGameNameImposter => 'Imposter';

  @override
  String get chatGameNameRace => 'Puzzle Race';

  @override
  String get chatGameDescLiarsDice => 'Bid on hidden dice. Call out the liar.';

  @override
  String get chatGameDescImposter =>
      'One of you doesn’t know the word. Find them.';

  @override
  String get chatGameDescRace => 'Same puzzle for all. Fastest solve wins.';

  @override
  String chatGamePlayersRange(int min, int max) {
    return '$min–$max players';
  }

  @override
  String get chatGamePartySection => 'Party';

  @override
  String get chatGamePartyLiveOnly =>
      'Party games are played live, with everyone at once.';

  @override
  String get chatGameNeedsThree => 'Needs a group of 3 or more';

  @override
  String get chatGameVoiceOption => 'Voice clues';

  @override
  String get chatGameVoiceOptionHint =>
      'Talk on a call instead of typing clues';

  @override
  String get chatGamePuzzleOption => 'Puzzle';

  @override
  String get chatGamePuzzleRandom => 'Random';

  @override
  String chatGameStartNamed(String game) {
    return 'Start $game';
  }

  @override
  String chatGameLdRoundDice(int count, int round) {
    return 'Round $round · $count dice';
  }

  @override
  String get chatGameLdYourDice => 'Your dice';

  @override
  String get chatGameLdNoBid => 'No bid yet';

  @override
  String chatGameLdBidBy(String name) {
    return '$name’s bid';
  }

  @override
  String get chatGameLdYourBid => 'Your bid';

  @override
  String get chatGameLdBid => 'Bid';

  @override
  String get chatGameLdLiar => 'Liar!';

  @override
  String get chatGameLdOnesWild => '1s are wild';

  @override
  String get chatGameLdOnesOnly => 'Bid on 1s: no wilds';

  @override
  String get chatGameLdHolds => 'The bid holds';

  @override
  String get chatGameLdBusted => 'Busted!';

  @override
  String chatGameLdThereWere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'There were $count',
      one: 'There was 1',
    );
    return '$_temp0';
  }

  @override
  String chatGameLdLosesDie(String name) {
    return '$name loses a die';
  }

  @override
  String get chatGameLdYouLoseDie => 'You lose a die';

  @override
  String chatGameLdCalled(String name) {
    return '$name called liar';
  }

  @override
  String chatGameLdTimedOut(String name) {
    return 'Time ran out for $name';
  }

  @override
  String get chatGameLdOut => 'Out';

  @override
  String get chatGameLdQuantity => 'How many';

  @override
  String get chatGameLdFace => 'Which face';

  @override
  String get chatGameLdFewer => 'Fewer';

  @override
  String get chatGameLdMore => 'More';

  @override
  String get chatGameLdPrompt => 'Raise the bid or call liar';

  @override
  String get chatGameLdOpenPrompt => 'Open the bidding';

  @override
  String get chatGameImpHoldToSee => 'Hold to see your card';

  @override
  String get chatGameImpYourWord => 'Your word';

  @override
  String get chatGameImpYouAre => 'You’re the imposter';

  @override
  String chatGameImpCategory(String category) {
    return 'Category: $category';
  }

  @override
  String get chatGameImpBlendIn => 'Blend in. Nobody else knows.';

  @override
  String get chatGameImpKeepSecret =>
      'Don’t say it outright. Give clues the others will get.';

  @override
  String get chatGameImpGotIt => 'Got it';

  @override
  String chatGameImpLooked(int count, int total) {
    return '$count of $total have looked';
  }

  @override
  String chatGameImpGiving(String name) {
    return '$name is giving a clue';
  }

  @override
  String get chatGameImpYourClue => 'Your turn to give a clue';

  @override
  String get chatGameImpClueHint => 'One to four words';

  @override
  String get chatGameImpClueField => 'Your clue';

  @override
  String get chatGameImpSend => 'Send';

  @override
  String get chatGameImpTooManyWords => 'Four words at most';

  @override
  String get chatGameImpPassed => 'Passed';

  @override
  String get chatGameImpSpoke => 'Spoke on the call';

  @override
  String get chatGameImpJoinCall => 'Join the call';

  @override
  String get chatGameImpOnCall => 'You’re on the call';

  @override
  String get chatGameImpVoiceHint => 'Say your clue out loud, then tap Done.';

  @override
  String get chatGameImpDone => 'Done';

  @override
  String get chatGameImpVoteTitle => 'Who’s the imposter?';

  @override
  String get chatGameImpVoteHint =>
      'Tap a player to vote. You can change it until time runs out.';

  @override
  String get chatGameImpSkip => 'Skip vote';

  @override
  String chatGameImpVoted(int count, int total) {
    return '$count of $total voted';
  }

  @override
  String get chatGameImpVotedBadge => 'Voted';

  @override
  String get chatGameImpYourVote => 'Your vote';

  @override
  String get chatGameImpGuessing => 'The imposter is guessing…';

  @override
  String get chatGameImpGuessHint =>
      'You were caught. Name the word to steal the win.';

  @override
  String get chatGameImpGuessField => 'The word is…';

  @override
  String get chatGameImpGuess => 'Guess';

  @override
  String chatGameImpWas(String name) {
    return '$name was the imposter';
  }

  @override
  String get chatGameImpYouWere => 'You were the imposter';

  @override
  String get chatGameImpTheWord => 'The word was';

  @override
  String chatGameImpTheyGuessed(String guess) {
    return 'Guessed “$guess”';
  }

  @override
  String chatGameImpVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return '$_temp0';
  }

  @override
  String chatGameImpSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skipped',
      one: '1 skipped',
    );
    return '$_temp0';
  }

  @override
  String get chatGameImpReasonEscaped =>
      'Nobody was voted out, so the imposter got away.';

  @override
  String get chatGameImpReasonWrong => 'The crew voted out the wrong player.';

  @override
  String get chatGameImpReasonGuessed =>
      'Caught, but the imposter guessed the word.';

  @override
  String get chatGameImpReasonCaught => 'The crew caught the imposter.';

  @override
  String get chatGameImpReasonImposterLeft => 'The imposter left the game.';

  @override
  String get chatGameImpReasonCrewLeft => 'The rest of the crew left.';

  @override
  String get chatGameImpCrewWon => 'The crew won';

  @override
  String get chatGameImpYourTeamWon => 'Your team won';

  @override
  String chatGameImpImposterWon(String name) {
    return '$name won as the imposter';
  }

  @override
  String get chatGameImpYouWonImposter => 'You won as the imposter';

  @override
  String get chatGameImpCardReveal => 'Looking at cards';

  @override
  String chatGameImpCardClues(int count, int total) {
    return 'Clues · $count of $total';
  }

  @override
  String get chatGameImpCardVote => 'Voting';

  @override
  String chatGameRaceFinishedCount(int count, int total) {
    return '$count of $total finished';
  }

  @override
  String chatGameRaceYouPlaced(int rank) {
    return 'You finished #$rank';
  }

  @override
  String get chatGameRaceWaiting => 'Waiting for the others';

  @override
  String get chatGameRaceTimeUp => 'Time’s up. Nobody finished.';

  @override
  String get chatGameRaceDnf => 'Didn’t finish';

  @override
  String get chatGameRaceLeft => 'Left';

  @override
  String get chatGameRaceResults => 'Results';

  @override
  String get chatGameRaceSolved => 'Solved!';

  @override
  String get chatGamePartyLeaveConfirm => 'Leave this game?';

  @override
  String get chatGamePartyLeaveBody => 'The others play on without you.';

  @override
  String get chatGameErrTooLate => 'Too late, time ran out';

  @override
  String get chatGameErrBadClue =>
      'That clue can’t be used. One to four words, no links.';

  @override
  String get chatGameErrBadGuess => 'Type a guess first';

  @override
  String get chatGameErrNotSolved => 'That board isn’t solved yet';

  @override
  String get chatGameNameChess => 'Chess';

  @override
  String get chatGameDescChess => 'Checkmate the king to win.';

  @override
  String get chessPawn => 'pawn';

  @override
  String get chessKnight => 'knight';

  @override
  String get chessBishop => 'bishop';

  @override
  String get chessRook => 'rook';

  @override
  String get chessQueen => 'queen';

  @override
  String get chessKing => 'king';

  @override
  String chessPieceWhite(String piece) {
    return '$piece, white';
  }

  @override
  String chessPieceBlack(String piece) {
    return '$piece, black';
  }

  @override
  String chessPromoteTo(String piece) {
    return 'Promote to $piece';
  }
}
