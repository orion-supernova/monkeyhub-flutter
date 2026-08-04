// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'KAN INTE NÅ SERVERN';

  @override
  String get bootErrorBody => 'Convex kunde inte starta.';

  @override
  String get bootErrorRetry => 'FÖRSÖK IGEN';

  @override
  String get incomingCallNotificationTitle => 'Inkommande samtal';

  @override
  String get incomingCallFallbackCaller => 'Någon ringer';

  @override
  String get settingsLanguageRowLabel => 'SPRÅK';

  @override
  String get languageScreenTitle => 'språk.';

  @override
  String get languageScreenSubtitle =>
      'välj språket för menyer och meddelanden i appen';

  @override
  String get languageOptionSystem => 'SYSTEM';

  @override
  String get languageOptionSystemSub => 'använd samma språk som din enhet';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => 'AKTIV';

  @override
  String get languageValueSystem => 'System';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack =>
      'kunde inte fråga just nu — försök igen';

  @override
  String get roomScreenGateSendMessages => 'skicka meddelanden här';

  @override
  String get roomScreenGateSendMedia => 'skicka bilder eller röstmeddelanden';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'högst $max åt gången';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'TA BORT $count MEDDELANDEN',
      one: 'TA BORT MEDDELANDE',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Detta tar bort dem för alla i den här chatten. Det går inte att ångra.';

  @override
  String get roomScreenDeleteConfirmButton => 'TA BORT FÖR ALLA';

  @override
  String get roomScreenJumpFailedSnack =>
      'kunde inte hoppa till det meddelandet';

  @override
  String get roomScreenViewOnceAlreadyViewed =>
      'du har redan öppnat det här fotot.';

  @override
  String get roomScreenViewOnceGone => 'det här fotot finns inte längre.';

  @override
  String get roomScreenViewOnceNetworkError => 'kunde inte läsa in fotot.';

  @override
  String get roomScreenFileReadFailedSnack => 'kunde inte läsa filen';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'filer får max vara $size';
  }

  @override
  String get roomScreenRoomGone => 'rummet är borta';

  @override
  String get roomScreenCopiedSnack => 'kopierat';

  @override
  String get roomScreenNameCopiedSnack => 'namnet kopierat';

  @override
  String get roomScreenPinLimitSnack =>
      'för många nålade meddelanden — nåla av ett först';

  @override
  String get roomScreenPinFailedSnack => 'kunde inte nåla det';

  @override
  String get roomScreenReportSentSnack =>
      'rapporten skickades privat. personen får ingen avisering om det.';

  @override
  String get roomScreenDeselectMessageSemantic => 'Avmarkera meddelande';

  @override
  String get roomScreenSelectMessageSemantic => 'Markera meddelande';

  @override
  String roomScreenMemberCountBadge(Object count) {
    return '$count INNE';
  }

  @override
  String roomScreenTtlSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sekunder',
      one: '$count sekund',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuter',
      one: '$count minut',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count timmar',
      one: '$count timme',
    );
    return '$_temp0';
  }

  @override
  String roomScreenEphemeralNotice(Object ttl) {
    return 'det här rummet är flyktigt. meddelanden försvinner efter $ttl, lästa eller olästa.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count MEDDELANDEN';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'Hemligt rum';

  @override
  String get roomScreenSecretSpaceBody =>
      'Meddelanden i det här rummet är flyktiga. De tas automatiskt bort enligt rummets säkerhetsinställningar.';

  @override
  String get roomScreenAutoDeleteTitle => 'Auto-radering';

  @override
  String get roomScreenAutoDeleteVaries => 'Varierar';

  @override
  String get roomScreenAutoDeleteTimed => 'Tidsstyrd';

  @override
  String get roomScreenNoCaptureTitle => 'Ingen skärmdump';

  @override
  String get roomScreenNoCaptureSubtitle => 'Skärmdumpar begränsade';

  @override
  String get roomScreenMorePrivacyTitle => 'Mycket mer integritet';

  @override
  String get roomScreenMorePrivacySubtitle =>
      'Njut av extra säkerhetsfunktioner ovanpå det redan starka fokuset på integritet.';

  @override
  String get roomScreenNoMessagesTitle => 'Inga meddelanden';

  @override
  String get roomScreenNoMessagesSubtitle =>
      'Starta konversationen genom att skicka ett meddelande';

  @override
  String get roomScreenViewProfilePictureSemantic => 'visa profilbild';

  @override
  String get roomScreenViewRoomPictureSemantic => 'visa rumsbild';

  @override
  String get messageBubbleFileFallbackName => 'dokument';

  @override
  String get messageBubbleAttachmentStatusFailed => 'misslyckades';

  @override
  String get messageBubbleAttachmentStatusSending => 'skickar…';

  @override
  String get messageBubbleViewOnceOpened => 'öppnat';

  @override
  String get messageBubbleViewOnceExpired => 'utgånget';

  @override
  String get messageBubbleViewOnceLabel => 'visa en gång';

  @override
  String get messageBubbleViewOnceTapToView => 'tryck för att visa';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Foto';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'engångsfoto, tryck för att visa';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'försök att skicka igen';

  @override
  String get messageBubbleDiscardSemanticLabel => 'ta bort';

  @override
  String get profileScreenAccountSection => 'KONTO';

  @override
  String get profileScreenAddEmailPlaceholder => 'lägg till e-post';

  @override
  String get profileScreenAddEmailTitle => 'lägg till e-post?';

  @override
  String get profileScreenAddNameTitle => 'lägg till namn?';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count väntar';
  }

  @override
  String get profileScreenApprovalsLabel => 'GODKÄNNANDEN';

  @override
  String get profileScreenApprovalsNothingWaiting => 'inget väntar';

  @override
  String get profileScreenApproveAction => 'GODKÄNN';

  @override
  String get profileScreenBlockAction => 'BLOCKERA';

  @override
  String get profileScreenBlockedDmWiped =>
      'blockerad och DM raderat. de meddelas inte.';

  @override
  String get profileScreenBlockedOnly => 'blockerad. de meddelas inte.';

  @override
  String get profileScreenBlockedUsers => 'BLOCKERADE ANVÄNDARE';

  @override
  String get profileScreenCancelAction => 'AVBRYT';

  @override
  String get profileScreenCancelRequestAction => 'AVBRYT FÖRFRÅGAN';

  @override
  String get profileScreenChangeAction => 'ÄNDRA';

  @override
  String get profileScreenChangeEmailTitle => 'ändra e-post?';

  @override
  String get profileScreenChangeNameTitle => 'ändra namn?';

  @override
  String get profileScreenChangeProfilePictureSemantic => 'ändra profilbild';

  @override
  String get profileScreenChangeRecoveryPhrase => 'ÄNDRA ÅTERSTÄLLNINGSFRAS';

  @override
  String get profileScreenChooseFromLibrary => 'VÄLJ FRÅN BIBLIOTEK';

  @override
  String get profileScreenCouldNotSaveImage => 'kunde inte spara bilden.';

  @override
  String get profileScreenDeleteAccount => 'RADERA KONTO';

  @override
  String get profileScreenEmailHint => 'valfritt — visas aldrig för någon';

  @override
  String get profileScreenEmailSectionLabel => 'E-POST';

  @override
  String get profileScreenErrorAlreadyFriends => 'ni är redan vänner.';

  @override
  String get profileScreenErrorGeneric => 'kunde inte slutföra det.';

  @override
  String get profileScreenErrorNotAccepting =>
      'de tar inte emot vänförfrågningar just nu.';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      'de har redan skickat dig en förfrågan — kolla dina förfrågningar.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'förfrågan redan skickad.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'du har blockerat den här användaren — ta bort blockeringen först.';

  @override
  String get profileScreenErrorUserNotFound => 'det går inte just nu.';

  @override
  String get profileScreenFamilyAddChild => 'lägg till ett barn';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count barn',
      one: '$count barn',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => 'FAMILJ';

  @override
  String get profileScreenFriendsChip => 'VÄNNER';

  @override
  String get profileScreenGrownUpOnlyNote =>
      'Bara en vuxen kan göra det här — det behövs deras kod eller lösenord.';

  @override
  String get profileScreenGuardiansCanSee =>
      'De kan se när du är online och vem du pratar med.';

  @override
  String get profileScreenHandPhoneBack => 'LÄMNA TILLBAKA TELEFONEN';

  @override
  String get profileScreenIncomingRequestChip => 'INKOMMANDE FÖRFRÅGAN';

  @override
  String get profileScreenJustTappedAction => 'TRYCKTE FEL';

  @override
  String get profileScreenLegalSection => 'JURIDISKT';

  @override
  String get profileScreenLicence => 'LICENS';

  @override
  String get profileScreenLinkedAccountsLabel => 'LÄNKADE KONTON';

  @override
  String get profileScreenLinkedAccountsNone => 'inget länkat';

  @override
  String get profileScreenMyGrownUps => 'MINA VUXNA';

  @override
  String get profileScreenNameHint => 'så här syns du i rummet';

  @override
  String get profileScreenNobodyLookingAfter =>
      'ingen tar hand om det här kontot än';

  @override
  String get profileScreenNotAcceptingRequestsAction =>
      'TAR INTE EMOT FÖRFRÅGNINGAR';

  @override
  String get profileScreenNotConnectedChip => 'INTE ANSLUTEN';

  @override
  String get profileScreenOpenDmAction => 'ÖPPNA DM';

  @override
  String get profileScreenPhotoPermissionDenied => 'fotobehörighet nekad.';

  @override
  String get profileScreenPrivacyPolicy => 'INTEGRITETSPOLICY';

  @override
  String get profileScreenPrivacySection => 'INTEGRITET';

  @override
  String get profileScreenProfilePictureTitle => 'PROFILBILD';

  @override
  String get profileScreenRedactedFriend =>
      'vissa fält är dolda på grund av deras inställningar.';

  @override
  String get profileScreenRedactedStranger =>
      'begränsad vy — de delar mer med vänner.';

  @override
  String get profileScreenReportAction => 'ANMÄL';

  @override
  String get profileScreenReportSent =>
      'anmälan skickad privat. de meddelas inte.';

  @override
  String get profileScreenRequestPendingChip => 'FÖRFRÅGAN VÄNTAR';

  @override
  String get profileScreenSaveAction => 'SPARA';

  @override
  String get profileScreenSavedToPhotos => 'sparad i foton.';

  @override
  String get profileScreenSaveToPhotos => 'SPARA I FOTON';

  @override
  String get profileScreenSendRequestAction => 'SKICKA FÖRFRÅGAN';

  @override
  String get profileScreenSetUpRecoveryPhrase => 'SKAPA ÅTERSTÄLLNINGSFRAS';

  @override
  String get profileScreenSignOut => 'LOGGA UT';

  @override
  String get profileScreenTakeSelfie => 'TA EN SELFIE';

  @override
  String get profileScreenTapAgainToConfirmDelete =>
      'TRYCK IGEN FÖR ATT BEKRÄFTA RADERING';

  @override
  String get profileScreenTermsOfService => 'ANVÄNDARVILLKOR';

  @override
  String get profileScreenThisPhoneSection => 'DEN HÄR TELEFONEN';

  @override
  String get profileScreenUnfriendAction => 'TA BORT SOM VÄN';

  @override
  String get profileScreenViewProfilePictureSemantic => 'visa profilbild';

  @override
  String get profileScreenVisibilityPreferences => 'SYNLIGHETSINSTÄLLNINGAR';

  @override
  String get cameraEditorScreenCropPresetFree => 'FRI';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'ORIG';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'avbryt beskärning';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'kassera foto';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'ångra';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'gör om';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'återställ beskärning';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'rotera';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'beskär';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'den här webbläsaren kan inte öppna HEIC-foton';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'kunde inte öppna bilden';

  @override
  String get cameraEditorScreenCropDoneButton => 'KLAR';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'ta om';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'lägg undan pennan';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'rita på fotot';

  @override
  String get cameraEditorScreenSendingButton => 'SKICKAR…';

  @override
  String get cameraEditorScreenSendButton => 'SKICKA';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'försvinner efter att ha öppnats en gång';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'rensa teckning';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel => 'visa en gång: på';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel => 'visa en gång: av';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'bläckfärg';

  @override
  String get glassScreenPanelLooks => 'STILAR';

  @override
  String get glassScreenPanelBottomBar => 'NEDRE FÄLTET';

  @override
  String get glassScreenPanelOtherSurfaces => 'ÖVRIGA YTOR';

  @override
  String get glassScreenPanelBarLayout => 'FÄLTLAYOUT';

  @override
  String get glassScreenTitle => 'glas.';

  @override
  String get glassScreenSubtitle =>
      'hur mycket av det som ligger bakom som syns igenom';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'ALLA $max PLATSER FULLA';
  }

  @override
  String get glassScreenSaveCurrentAs => 'SPARA NUVARANDE SOM…';

  @override
  String get glassScreenResetEveryDial => 'ÅTERSTÄLL ALLA REGLAGE';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'ÅTERSTÄLL TILL $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'skrivfältet, rubriker, samtalsknappar — allt som ligger ovanpå text snarare än ovanpå skrollande innehåll';

  @override
  String get glassScreenMatchBottomBar => 'MATCHA DET NEDRE FÄLTET';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'redigerad — spara som en ny stil, eller återställ den';

  @override
  String get glassScreenCustomPresetName => 'Anpassad';

  @override
  String get glassScreenUnsavedSubtitle =>
      'osparad — ge den ett namn för att behålla den';

  @override
  String get glassScreenSaveDialogTitle => 'spara den här looken som';

  @override
  String get glassScreenNoRoomToast => 'ingen plats — ta bort en look först';

  @override
  String get glassScreenRenameDialogTitle => 'byt namn';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'ta bort $name?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'looken stannar kvar på skärmen — den blir bara namnlös.';

  @override
  String get glassScreenKeepButton => 'behåll';

  @override
  String get glassScreenDeleteButton => 'ta bort';

  @override
  String get glassScreenNameHint => 'sen kväll';

  @override
  String get glassScreenCancelButton => 'avbryt';

  @override
  String get glassScreenSaveButton => 'spara';

  @override
  String get glassScreenPreviewRoomName => '# balkong';

  @override
  String get glassScreenPreviewOnlineCount => '4 online';

  @override
  String get glassScreenPreviewMessageHint => 'meddelande';

  @override
  String get glassScreenPreviewCollapseLabel => 'fäll ihop förhandsvisning';

  @override
  String get glassScreenPreviewExpandLabel => 'fäll ut förhandsvisning';

  @override
  String get glassScreenPreviewBadge => 'FÖRHANDSVISNING';

  @override
  String get glassScreenBuiltInLabel => 'inbyggd';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'skriv över $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'byt namn på $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'ta bort $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'återställ $label';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'skickade takfotona — takpannorna är helt spruckna';

  @override
  String get glassScreenBackdropMsgMert =>
      'okej men vem tar faktiskt med sig högtalaren';

  @override
  String get glassScreenBackdropGroupFamily => 'familj';

  @override
  String get glassScreenBackdropMsgFamily =>
      'Anne: middag kl 8, var inte sen igen';

  @override
  String get glassScreenBackdropMsgZeynep => 'jag är ute';

  @override
  String get glassScreenBackdropMsgKerem =>
      'stället i hörnet har riktigt bra kaffe';

  @override
  String get glassScreenBackdropGroupWork => 'jobb';

  @override
  String get glassScreenBackdropMsgWork =>
      'standup flyttat till 10:30 resten av veckan';

  @override
  String get glassScreenBackdropMsgElif =>
      'aldrig i livet. skicka den igen, jag tappade bort den';

  @override
  String get glassScreenBackdropMsgBaran => 'landade 👍';

  @override
  String get glassScreenBackdropMsgAyse =>
      'katten har lärt sig öppna balkongdörren';

  @override
  String get glassScreenBackdropMsgCan => 'vi ses på lördag då';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return 'som svar till $name';
  }

  @override
  String get replyIndicatorViewOnceLabel => 'foto · visas en gång';

  @override
  String get replyIndicatorVoiceMessageLabel => 'röstmeddelande';

  @override
  String get replyIndicatorDocumentLabel => 'dokument';

  @override
  String get replyIndicatorMessageRemoved => 'meddelandet togs bort';

  @override
  String get threadOverlayMessageNotFound =>
      'kunde inte hitta det meddelandet i den här tråden';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'kunde inte hitta tråden att svara i';

  @override
  String get threadOverlayStillSending =>
      'skickas fortfarande — försök igen om en stund';

  @override
  String get threadOverlayCopiedToast => 'kopierat';

  @override
  String get threadOverlayNameCopiedToast => 'namnet kopierat';

  @override
  String get threadOverlayPinLimitToast =>
      'för många nålade meddelanden — avnåla ett först';

  @override
  String get threadOverlayPinFailedToast => 'kunde inte nåla det';

  @override
  String get threadOverlayReportedToast => 'rapporterat';

  @override
  String get threadOverlayUnavailable => 'tråden är otillgänglig';

  @override
  String get roomInfoScreenNameRequiredError => 'namn krävs';

  @override
  String get roomInfoScreenSavedSnackbar => 'sparat';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'lösenord borttaget';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'lämna rummet?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'du kan gå med igen om det förblir öppet.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'LÄMNA';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'radera rummet?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'alla meddelanden här försvinner med det. det här är permanent.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'RADERA';

  @override
  String get roomInfoScreenConfirmCancelButton => 'AVBRYT';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'ett rum med det namnet finns redan';

  @override
  String get roomInfoScreenErrorNotOwner => 'bara ägaren kan göra det';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'du har inte behörighet';

  @override
  String get roomInfoScreenErrorRoomNotFound =>
      'det här rummet finns inte längre';

  @override
  String get roomInfoScreenRoomGone => 'rummet är borta';

  @override
  String get roomInfoScreenNameLabel => 'NAMN';

  @override
  String get roomInfoScreenNameHint => 'rumsnamn';

  @override
  String get roomInfoScreenDescriptionLabel => 'BESKRIVNING';

  @override
  String get roomInfoScreenDescriptionHint => 'en rad om rummet…';

  @override
  String get roomInfoScreenVisibilityLabel => 'SYNLIGHET';

  @override
  String get roomInfoScreenPublicTitle => 'offentligt';

  @override
  String get roomInfoScreenPublicSub => 'vem som helst kan hitta det';

  @override
  String get roomInfoScreenPrivateTitle => 'privat';

  @override
  String get roomInfoScreenPrivateSub => 'endast inbjudan';

  @override
  String get roomInfoScreenMessageLifeLabel => 'MEDDELANDETS LIVSLÄNGD';

  @override
  String roomInfoScreenTtlSeconds(Object value) {
    return '${value}s';
  }

  @override
  String roomInfoScreenTtlMinutes(Object value) {
    return '${value}min';
  }

  @override
  String roomInfoScreenTtlHours(Object value) {
    return '${value}h';
  }

  @override
  String get roomInfoScreenPasswordLabel => 'LÖSENORD';

  @override
  String get roomInfoScreenLockedBadge => 'LÅST';

  @override
  String get roomInfoScreenNoneBadge => 'INGET';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      'det här rummet är skyddat. av säkerhetsskäl visas inte det befintliga lösenordet — ange ett nytt för att ersätta det.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'byt lösenord…';

  @override
  String get roomInfoScreenSetPasswordHint => 'lås med ett lösenord…';

  @override
  String get roomInfoScreenRemovePasswordButton => 'TA BORT LÖSENORD';

  @override
  String get roomInfoScreenSharedContentLabel => 'DELAT INNEHÅLL';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return 'MEDLEMMAR · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => 'LÄMNAR…';

  @override
  String get roomInfoScreenLeaveRoomButton => 'LÄMNA RUMMET';

  @override
  String get roomInfoScreenDeletingButton => 'RADERAR…';

  @override
  String get roomInfoScreenDeleteButtonLabel => 'RADERA';

  @override
  String get roomInfoScreenHeaderConversation => 'KONVERSATION';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'RUMINSTÄLLNINGAR';

  @override
  String get roomInfoScreenViewProfilePictureSemantic => 'visa profilbild';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'visa rumsbild';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'ändra rumsbild';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'lägg till rumsbild';

  @override
  String get roomInfoScreenLoadingMembers => 'laddar medlemmar…';

  @override
  String get roomInfoScreenOwnerBadge => 'ÄGARE';

  @override
  String get roomInfoScreenSaveButton => 'SPARA';

  @override
  String get roomInfoScreenNoneCount => 'inga';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'kameraåtkomst är avstängd.\nslå på den i Inställningar för att ta ett foto.';

  @override
  String get cameraScreenOpeningSystemCamera => 'öppnar systemkameran…';

  @override
  String get cameraScreenCloseButtonLabel => 'stäng kameran';

  @override
  String get cameraScreenLowLightBoostOnLabel =>
      'förstärkning för svagt ljus: på';

  @override
  String get cameraScreenLowLightBoostOffLabel =>
      'förstärkning för svagt ljus: av';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'blixt: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'välj från bildbiblioteket';

  @override
  String get cameraScreenSwitchCameraLabel => 'byt kamera';

  @override
  String get cameraScreenTakePhotoLabel => 'ta foto';

  @override
  String get childPolicyScreenAddByUsernameLabel =>
      'LÄGG TILL MED ANVÄNDARNAMN';

  @override
  String get childPolicyScreenAddCta => 'LÄGG TILL';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'De får exakt samma befogenheter som du: varje förfrågan att godkänna, varje inställning att ändra och möjligheten att ta bort dig. $name ser dem som familj direkt.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'LÄGG TILL EN VUXEN';

  @override
  String get childPolicyScreenAddGuardianHint => 'deras användarnamn';

  @override
  String get childPolicyScreenAllowCta => 'TILLÅT';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'Du kommer inte att tillfrågas om dem igen — oavsett om $childName lägger till dem eller de lägger till $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'TILLÅT NÅGON';

  @override
  String get childPolicyScreenAskToAddLabel => 'BE OM LOV';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'bara familj — inga nya förfrågningar';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'de kan fråga dig om nya personer';

  @override
  String get childPolicyScreenBothFinalNote =>
      'Båda dessa är slutgiltiga. Att kliva åt sidan istället finns uppe under VUXNA.';

  @override
  String get childPolicyScreenCallsLabel => 'SAMTAL';

  @override
  String get childPolicyScreenCallsOffDesc => 'bara meddelanden';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'röst + video med tillåtna personer';

  @override
  String get childPolicyScreenCancelLabel => 'AVBRYT';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Avbryt';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'tillagd — förfrågan är på väg';

  @override
  String get childPolicyScreenContactAddedToList =>
      'tillagd i listan över tillåtna';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'SKAPA RUM';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'de kan inte starta rum';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'de kan starta sina egna privata rum';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Allt försvinner: deras meddelanden, foton, rum och vänner. Detta kan inte ångras, och användarnamnet blir ledigt för vem som helst.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'det gick inte att radera kontot — försök igen';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return 'RADERA ${name}S KONTO?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Meddelanden, foton, rum och vänner försvinner allihop. Kan inte ångras.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'RADERA ${name}S KONTO';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'RADERA FÖR ALLTID';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'det gick inte att lägga till dem — försök igen';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'det är deras eget användarnamn';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'ett barn kan inte vara en vuxen';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'det gick inte — försök igen';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'någon måste ta hand om dem — lägg till en till vuxen först';

  @override
  String get childPolicyScreenErrorNotYours =>
      'det där har du ingen rätt att ändra';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'inget konto med det användarnamnet';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'De blir ett vanligt konto med det här lösenordet, och alla vuxna förlorar all insyn. Det finns ingen väg tillbaka — du skulle behöva bli inbjuden som vem som helst.';

  @override
  String get childPolicyScreenGraduateCta => 'GÖR VUXEN';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'De behåller allt och får ett lösenord. Du förlorar all insyn. Oåterkalleligt.';

  @override
  String get childPolicyScreenGraduateDangerLabel => 'GÖR TILL VUXET KONTO';

  @override
  String get childPolicyScreenGraduateFailed =>
      'kunde inte göra dem vuxna — försök igen';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'GÖR $name VUXEN';
  }

  @override
  String get childPolicyScreenGraduateHint => 'ett lösenord för dem';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Att ta tillbaka ett rum tar också bort dem från det. Att ta tillbaka en person raderar även chatten — för dem båda.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Alla här kan godkänna, ändra inställningar och se allt. Vem som helst av dem kan agera på egen hand — ingen behöver vänta på de andra.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'tillagd — hen kan ta hand om dem nu';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name borttagen';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (du)';
  }

  @override
  String get childPolicyScreenLoading => 'laddar…';

  @override
  String get childPolicyScreenLockedLabel => 'LÅST';

  @override
  String get childPolicyScreenMediaLabel => 'BILDER + RÖST';

  @override
  String get childPolicyScreenMediaOffDesc => 'endast text';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'de kan skicka bilder, video och röstmeddelanden';

  @override
  String get childPolicyScreenNoRoomsYet => 'inga rum än';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Vem som helst här kan läggas till utan att du tillfrågas igen — oavsett vem av dem som tar initiativet.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Alltid avstängt för barn. Upptäck — listan över rum som tillhör personer du inte känner — är helt dold och kan inte slås på. Rum som någon bjuder in dem till fungerar fortfarande som vanligt.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'OFFENTLIGA RUM';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian kommer inte längre att se eller godkänna något för $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return 'TA BORT $name?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'TA BORT';

  @override
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count i rummet';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'VUXNA';

  @override
  String get childPolicyScreenSectionPeopleAllowed =>
      'PERSONER DU HAR TILLÅTIT';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'RUM DU HAR TILLÅTIT';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'VAD DE KAN GÖRA';

  @override
  String get childPolicyScreenSectionWhenDone => 'NÄR DE ÄR KLARA';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'inget händer förrän någon lägger till den andra';

  @override
  String get childPolicyScreenSendNowOnDesc => 'de tillfrågas direkt';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'SKICKA FÖRFRÅGAN NU';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'Du är ${name}s enda vuxna, så du kan inte bara kliva av — lägg till en till först, eller använd ett av dessa.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'KLIVA AV';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'Du förlorar all insyn i ${name}s konto — deras förfrågningar, deras kontakter, deras rum. De andra vuxna fortsätter att ta hand om dem.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'SLUTA ÖVERVAKA';

  @override
  String get childPolicyScreenStopSupervisingHeadline => 'SLUTA ÖVERVAKA?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'kunde inte ta tillbaka det — försök igen';

  @override
  String get childPolicyScreenTakeBackLabel => 'TA TILLBAKA';

  @override
  String get childPolicyScreenUsernameHint => 'användarnamn';

  @override
  String get childPolicyScreenYou => 'du';

  @override
  String get roomContentScreenDefaultDocumentName => 'dokument';

  @override
  String get roomContentScreenCouldntOpenFile => 'kunde inte öppna den filen';

  @override
  String get roomContentScreenCouldntShare => 'kunde inte dela dem';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'kopierade $count länkar',
      one: 'kopierat',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RADERA $count MEDDELANDEN',
      one: 'RADERA MEDDELANDE',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Detta tar bort dem för alla i den här chatten. Det kan inte ångras.';

  @override
  String get roomContentScreenDeleteForEveryone => 'RADERA FÖR ALLA';

  @override
  String get roomContentScreenCancelTooltip => 'Avbryt';

  @override
  String get roomContentScreenBackTooltip => 'Tillbaka';

  @override
  String get roomContentScreenSelectingLabel => 'VÄLJER';

  @override
  String get roomContentScreenSharedContentLabel => 'DELAT INNEHÅLL';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda',
      one: '$count vald',
      zero: 'inget valt',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'VÄLJ';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'ALLA';

  @override
  String get roomContentScreenEmptyMedia => 'inga foton eller videor än';

  @override
  String get roomContentScreenEmptyFiles => 'inga filer än';

  @override
  String get roomContentScreenEmptyVoice => 'inga röstmeddelanden än';

  @override
  String get roomContentScreenEmptyLinks => 'inga länkar än';

  @override
  String get roomContentScreenLoadFailed => 'kunde inte läsa in det';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Röstmeddelande från $name';
  }

  @override
  String get roomContentScreenForwardAction => 'VIDAREBEFORDRA';

  @override
  String get roomContentScreenCopyAction => 'KOPIERA';

  @override
  String get roomContentScreenSaveAction => 'SPARA';

  @override
  String get roomContentScreenShareAction => 'DELA';

  @override
  String get roomContentScreenInChatAction => 'I CHATTEN';

  @override
  String get roomContentScreenDeleteAction => 'TA BORT';

  @override
  String get messageActionMenuReplyLabel => 'SVARA';

  @override
  String get messageActionMenuForwardLabel => 'VIDAREBEFORDRA';

  @override
  String get messageActionMenuViewThreadLabel => 'VISA TRÅD';

  @override
  String get messageActionMenuCopyLabel => 'KOPIERA';

  @override
  String get messageActionMenuCopyNameLabel => 'KOPIERA NAMN';

  @override
  String get messageActionMenuPinLabel => 'FÄST';

  @override
  String get messageActionMenuUnpinLabel => 'LOSSA';

  @override
  String get messageActionMenuSelectLabel => 'VÄLJ';

  @override
  String get messageActionMenuProfileLabel => 'PROFIL';

  @override
  String get messageActionMenuDeleteLabel => 'TA BORT';

  @override
  String get messageActionMenuReportLabel => 'RAPPORTERA';

  @override
  String get themeScreenTitle => 'tema.';

  @override
  String get themeScreenTapToApplyHint =>
      'tryck för att använda · ⛶ för full förhandsgranskning';

  @override
  String get themeScreenFamilyBasicName => 'STANDARD';

  @override
  String get themeScreenFamilyBasicTagline => 'iOS-inspirerad · 5 paletter';

  @override
  String get themeScreenFamilyVaultName => 'VALV';

  @override
  String get themeScreenFamilyVaultTagline =>
      'privat dossier · noir + elfenben';

  @override
  String get themeScreenFamilyOthersName => 'ÖVRIGA';

  @override
  String get themeScreenFamilyOthersTagline => 'unika stämningar';

  @override
  String get themeScreenActiveBadge => 'AKTIV';

  @override
  String get themeScreenTapToApplyLabel => 'tryck för att använda';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return 'AKTIV — $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return 'ANVÄND $name';
  }

  @override
  String get themeScreenPreviewGreeting => 'hej, du.';

  @override
  String get themeScreenPreviewSectionLabel => 'KONVERSATION';

  @override
  String get themeScreenPreviewRoomOneName => 'designklubb';

  @override
  String get themeScreenPreviewRoomOneSub => 'mia: släppte den nya rutan.';

  @override
  String get themeScreenPreviewRoomTwoName => 'kammare · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => 'förseglas om 4h.';

  @override
  String get themeScreenPreviewBubbleQuestion => 'hur känns det här?';

  @override
  String get themeScreenPreviewBubbleAnswer => 'som den rätta.';

  @override
  String get callScreenVideoCallLabel => 'Videosamtal';

  @override
  String get callScreenVoiceCallLabel => 'Röstsamtal';

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · ringer…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · inkommande';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · ansluter…';
  }

  @override
  String get callScreenStatusConnected => 'ansluten';

  @override
  String get callScreenStatusEnded => 'samtalet avslutades';

  @override
  String get callScreenStatusFailed => 'samtalet misslyckades';

  @override
  String get callScreenStatusSwitching => 'byter enhet…';

  @override
  String get callScreenStatusMoved => 'flyttat';

  @override
  String get callScreenStatusReconnecting => 'återansluter…';

  @override
  String get callScreenPoorConnectionLabel => 'dålig anslutning';

  @override
  String get callScreenWeakConnectionLabel => 'svag anslutning';

  @override
  String get callScreenControlUnmute => 'ljud på';

  @override
  String get callScreenControlMute => 'ljud av';

  @override
  String get callScreenControlCamOn => 'kamera på';

  @override
  String get callScreenControlCamOff => 'kamera av';

  @override
  String get callScreenControlFlip => 'byt';

  @override
  String get callScreenControlSpeaker => 'högtalare';

  @override
  String get callScreenControlEnd => 'avsluta';

  @override
  String get linkPreviewCardLinkLabel => 'LÄNK';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name accepterade din förfrågan';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'förfrågan drogs tillbaka';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'förfrågan avvisades';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'du har blockerat den här användaren — häv blockeringen först.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'de tar inte emot vänförfrågningar just nu.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'kunde inte skicka. försök igen.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel =>
      'INKOMMANDE FÖRFRÅGAN';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'NY FÖRFRÅGAN';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name vill starta en konversation.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'skriv några rader. de kan godkänna eller avvisa.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'inget här sparas permanent förrän båda är överens.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'RUMSTYP';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'FLYKTIGT';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'STANDARD';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'LIVSLÄNGD';

  @override
  String friendRequestDraftScreenDurationSeconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String friendRequestDraftScreenDurationMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String friendRequestDraftScreenDurationHours(Object hours) {
    return '$hours h';
  }

  @override
  String get friendRequestDraftScreenHintWhisperOptional =>
      'viska en första rad · valfritt';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'lägg till ett första meddelande · valfritt';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'viska · försvinner automatiskt';

  @override
  String get friendRequestDraftScreenHintStartWith => 'något att börja med…';

  @override
  String get friendRequestDraftScreenApproveButton => 'GODKÄNN OCH ÖPPNA RUM';

  @override
  String get friendRequestDraftScreenDeclineButton => 'AVVISA';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'AVBRYT FÖRFRÅGAN';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => 'FRÅGA EN VUXEN';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'SKICKA FÖRFRÅGAN';

  @override
  String get discoverScreenTitle => 'upptäck.';

  @override
  String get discoverScreenCaptionPeople => 'personer';

  @override
  String get discoverScreenCaptionRooms => 'rum';

  @override
  String get discoverScreenCaptionRequests => 'förfrågningar';

  @override
  String get discoverScreenPeopleBandLabel => 'PERSONER';

  @override
  String get discoverScreenRoomsBandLabel => 'RUM';

  @override
  String get discoverScreenFindPeopleTitle => 'hitta personer';

  @override
  String get discoverScreenFindPeopleSubtitleChild =>
      'skriv ett helt användarnamn';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'sök på @användarnamn eller namn';

  @override
  String get discoverScreenRequestsSectionLabel => 'FÖRFRÅGNINGAR';

  @override
  String get discoverScreenInboxQuiet => 'tyst i inkorgen';

  @override
  String get discoverScreenNothingPending => 'inget skickat';

  @override
  String get discoverScreenYourPeopleLabel => 'DINA VÄNNER';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'ingen än — hitta personer ovan';

  @override
  String get discoverScreenNoFriendsYet => 'ingen än';

  @override
  String get discoverScreenSearchRoomsTitle => 'sök rum';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'hitta ett offentligt rum via namn';

  @override
  String get discoverScreenPublicRoomsLabel => 'OFFENTLIGA RUM';

  @override
  String get discoverScreenLoadingRooms => 'letar…';

  @override
  String get discoverScreenNoRoomsOpen => 'inget öppet just nu';

  @override
  String get discoverScreenIncomingLabel => 'inkommande';

  @override
  String get discoverScreenOutgoingLabel => 'utgående';

  @override
  String get discoverScreenIncomingLabelCaps => 'INKOMMANDE';

  @override
  String get discoverScreenOutgoingLabelCaps => 'UTGÅENDE';

  @override
  String get discoverScreenJumpPeopleLabel => 'personer';

  @override
  String get discoverScreenJumpRoomsLabel => 'rum';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Hoppa till $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'justera';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'ANVÄND FOTO';

  @override
  String get imageCropScreenSavingButton => 'SPARAR…';

  @override
  String get imageCropScreenCancelButton => 'AVBRYT';

  @override
  String get imageCropScreenHeicUnsupported =>
      'den här webbläsaren kan inte öppna HEIC-foton';

  @override
  String get imageCropScreenLoadFailed => 'kunde inte öppna bilden';

  @override
  String get imageCropScreenHintCircle =>
      'dra för att flytta, nyp för att zooma';

  @override
  String get imageCropScreenHintRect => 'dra och nyp för att rama in';

  @override
  String get loginScreenSignInHeroMuted => 'välkommen\n';

  @override
  String get loginScreenSignInHeroInk => 'tillbaka.';

  @override
  String get loginScreenSignInCta => 'LOGGA IN';

  @override
  String get loginScreenSignUpHeroMuted => 'ny\n';

  @override
  String get loginScreenSignUpHeroInk => 'här.';

  @override
  String get loginScreenSignUpCta => 'ÖPPNA KONTO';

  @override
  String get loginScreenResetHeroMuted => 'återställ\n';

  @override
  String get loginScreenResetHeroInk => 'lösenord.';

  @override
  String get loginScreenResetCta => 'ÅTERSTÄLL LÖSENORD';

  @override
  String get loginScreenErrorPasswordsDontMatch => 'Lösenorden matchar inte.';

  @override
  String get loginScreenErrorChoosePasswordFirst => 'Välj ett lösenord först.';

  @override
  String get loginScreenUsernameHint => 'användarnamn';

  @override
  String get loginScreenPasswordHint => 'lösenord';

  @override
  String get loginScreenConfirmPasswordHint => 'bekräfta lösenord';

  @override
  String get loginScreenNameOptionalHint => 'namn (valfritt)';

  @override
  String get loginScreenRecoveryPhraseHint =>
      'din återställningsfras på 12 ord';

  @override
  String get loginScreenNewPasswordHint => 'nytt lösenord';

  @override
  String get loginScreenBackToSignIn => '← tillbaka till inloggning';

  @override
  String get loginScreenForgotPassword => 'glömt lösenordet?';

  @override
  String get loginScreenSettingUpKidsPhone => 'skapa ett barnkonto';

  @override
  String get loginScreenLegalPrefix =>
      'Genom att öppna ett konto godkänner du ';

  @override
  String get loginScreenLegalTermsLink => 'Användarvillkoren';

  @override
  String get loginScreenLegalMiddle => ' och ';

  @override
  String get loginScreenLegalPrivacyLink => 'Integritetspolicyn';

  @override
  String get loginScreenLegalSuffix => '.';

  @override
  String get loginScreenAlreadyHerePrompt => 'redan här? ';

  @override
  String get loginScreenSignInLink => 'logga in';

  @override
  String get loginScreenNoAccountPrompt => 'inget konto? ';

  @override
  String get loginScreenOpenOneLink => 'öppna ett';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12 ord';
  }

  @override
  String get homeShellEmptyRoomHint => 'välj ett rum för att börja chatta';

  @override
  String get homeShellEmptySettingHint => 'välj en inställning';

  @override
  String get searchScreenHintPeople => 'sök personer…';

  @override
  String get searchScreenHintRooms => 'sök rum…';

  @override
  String get searchScreenPeoplePromptChild =>
      'skriv ett helt användarnamn för att hitta någon ny';

  @override
  String get searchScreenPeoplePromptDefault =>
      'sök efter användarnamn eller namn';

  @override
  String get searchScreenNoMatchChild =>
      'ingen matchar — nya personer behöver sitt\nhela användarnamn, exakt stavat';

  @override
  String get searchScreenNoMatchDefault => 'ingen matchar';

  @override
  String get searchScreenNoRoomsYet => 'inga offentliga rum än';

  @override
  String get searchScreenNoRoomsMatch => 'inga offentliga rum matchar';

  @override
  String get searchScreenActionAskToAdd => 'FRÅGA OM LOV';

  @override
  String get searchScreenActionSendRequest => 'SKICKA FÖRFRÅGAN';

  @override
  String get searchScreenActionCancel => 'AVBRYT';

  @override
  String get searchScreenActionApprove => 'GODKÄNN';

  @override
  String get searchScreenActionOpenDm => 'ÖPPNA DM';

  @override
  String get searchScreenAskedLabel => 'frågat';

  @override
  String get profileVisibilityScreenTitle => 'synlighetsinställningar.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'bestäm vad andra ser — och hur de kan nå dig.';

  @override
  String get profileVisibilityScreenSectionProfile => 'PROFIL';

  @override
  String get profileVisibilityScreenAvatarLabel => 'AVATAR';

  @override
  String get profileVisibilityScreenAvatarDesc => 'din profilbild';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => 'ONLINE / BORTA';

  @override
  String get profileVisibilityScreenOnlineAwayDesc =>
      'om du visas som aktiv just nu';

  @override
  String get profileVisibilityScreenLastSeenLabel => 'SENAST SEDD';

  @override
  String get profileVisibilityScreenLastSeenDesc => 'när du senast var aktiv';

  @override
  String get profileVisibilityScreenSectionMessages => 'MEDDELANDEN';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel =>
      'SKICKA LÄSKVITTON';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      'när det är på kan andra se att du har läst deras meddelanden';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel => 'VISA LÄSKVITTON';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      'se \"LÄST\"-märket på dina egna meddelanden när de har lästs';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      'endast läsare som har aktiverat SKICKA LÄSKVITTON bidrar till detta. andra förblir osynliga.';

  @override
  String get profileVisibilityScreenSectionPeople => 'PERSONER';

  @override
  String get profileVisibilityScreenFriendRequestsLabel => 'VÄNFÖRFRÅGNINGAR';

  @override
  String get profileVisibilityScreenFriendRequestsDesc =>
      'vem som kan skicka vänförfrågningar till dig';

  @override
  String get profileVisibilityScreenSupervisedTitle =>
      'DINA VUXNA STÄLLER IN DET HÄR';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      'Du kan se samma saker som alla andra ser här, men det är bara en vuxen som kan ändra det. De kan alltid se din bild, när du är online och när du senast var här.';

  @override
  String get profileVisibilityScreenOptionPublic => 'OFFENTLIG';

  @override
  String get profileVisibilityScreenOptionFriends => 'VÄNNER';

  @override
  String get profileVisibilityScreenOptionNobody => 'INGEN';

  @override
  String get profileVisibilityScreenOptionOn => 'PÅ';

  @override
  String get profileVisibilityScreenOptionOff => 'AV';

  @override
  String get profileVisibilityScreenOptionAnyone => 'ALLA';

  @override
  String get logoScreenTitle => 'app-logga.';

  @override
  String get logoScreenSubtitle => 'märket högst upp, du bestämmer.';

  @override
  String get logoScreenAutoLabel => 'AUTO';

  @override
  String get logoScreenAutoDescription =>
      'följer ditt tema. märket ändras med paletten.';

  @override
  String get logoScreenManualLabel => 'MANUELL';

  @override
  String get logoScreenManualDescription =>
      'välj valfritt märke, behåll ditt tema.';

  @override
  String get logoScreenAlwaysDefaultLabel => 'ALLTID STANDARD';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      'MonkeyHub-märket, oavsett tema.';

  @override
  String get logoScreenActiveBadge => 'AKTIV';

  @override
  String get logoScreenMonkeyCollectionHeader => 'APSAMLING';

  @override
  String get logoScreenThemesHeader => 'TEMAN';

  @override
  String get recoveryPhraseScreenCopiedSnackbar =>
      'kopierad — klistra in den på ett säkert ställe';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'bekräfta\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'det är du.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Ditt lösenord, så att ingen annan kan lägga till en återställningsfras på ditt konto.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'lösenord';

  @override
  String get recoveryPhraseScreenContinueButton => 'FORTSÄTT';

  @override
  String get recoveryPhraseScreenNotNowLink => 'inte nu';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'Ange ditt lösenord.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'spara\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => 'dessa ord.';

  @override
  String get recoveryPhraseScreenWordsBody =>
      'Dessa tolv ord är det enda sättet att komma tillbaka in i ditt konto om du glömmer ditt lösenord. Vi kan inte visa dem för dig igen, och vi kan inte återställa dem åt dig.';

  @override
  String get recoveryPhraseScreenCopyButton => 'KOPIERA';

  @override
  String get recoveryPhraseScreenPaperHint =>
      'Skriv gärna ner dem på papper om du kan. Allt på den här telefonen kan försvinna med telefonen.';

  @override
  String get recoveryPhraseScreenSavedButton => 'JAG SPARADE DEM';

  @override
  String get recoveryPhraseScreenBackLink => '← tillbaka';

  @override
  String get recoveryPhraseScreenKeepPhraseLink =>
      'inte nu — behåll min nuvarande fras';

  @override
  String get homeScreenProfileSemanticLabel => 'Din profil';

  @override
  String homeScreenGreeting(Object name) {
    return 'hej, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'Nytt rum';

  @override
  String get homeScreenEmptyRoomsMessage => 'inga rum än — skapa ett';

  @override
  String get groupCallScreenTitleVideo => 'Gruppvideosamtal';

  @override
  String get groupCallScreenTitleVoice => 'Gruppröstsamtal';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '$count i samtalet';
  }

  @override
  String get groupCallScreenReconnecting => 'återansluter…';

  @override
  String get groupCallScreenUnmuteLabel => 'ljud på';

  @override
  String get groupCallScreenMuteLabel => 'ljud av';

  @override
  String get groupCallScreenCamOnLabel => 'kamera på';

  @override
  String get groupCallScreenCamOffLabel => 'kamera av';

  @override
  String get groupCallScreenFlipLabel => 'vänd';

  @override
  String get groupCallScreenSpeakerLabel => 'högtalare';

  @override
  String get groupCallScreenLeaveLabel => 'lämna';

  @override
  String get groupCallScreenYouLabel => 'Du';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return 'Filtrerar efter $summary. Ändra filter';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => 'Filtrera chattar';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => 'Rensa filter';

  @override
  String get roomFilterDrawerClearLabel => 'rensa';

  @override
  String get roomFilterDrawerDimensionType => 'TYP';

  @override
  String get roomFilterDrawerDimensionNature => 'KARAKTÄR';

  @override
  String get roomFilterDrawerDimensionStatus => 'STATUS';

  @override
  String get roomFilterDrawerPanelClear => 'RENSA';

  @override
  String get roomFilterDrawerPanelDone => 'KLART';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chattar',
      one: '$count chatt',
    );
    return '$label, $_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return 'inget matchar $summary';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Visa alla $count chattar',
      one: 'Visa alla $count chatt',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'visa alla $count chattar',
      one: 'visa alla $count chatt',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'nytt rum';

  @override
  String get createRoomSheetTaglineSecret => 'INGET SPARAS';

  @override
  String get createRoomSheetTaglineRegular => 'EN PLATS SOM STANNAR';

  @override
  String get createRoomSheetNameLabel => 'NAMN';

  @override
  String get createRoomSheetNameHint => 'ge det ett ärligt namn…';

  @override
  String get createRoomSheetDescriptionLabel => 'BESKRIVNING · VALFRI';

  @override
  String get createRoomSheetDescriptionHint => 'en rad om rummet…';

  @override
  String get createRoomSheetVisibilityLabel => 'SYNLIGHET';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'offentligt';

  @override
  String get createRoomSheetVisibilityPublicSub =>
      'vem som helst kan hitta det';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'privat';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'endast med inbjudan';

  @override
  String get createRoomSheetTypeLabel => 'TYP';

  @override
  String get createRoomSheetTypeStandardTitle => 'standard';

  @override
  String get createRoomSheetTypeStandardSub => 'meddelanden sparas';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'flyktig';

  @override
  String get createRoomSheetTypeEphemeralSub => 'raderas automatiskt';

  @override
  String get createRoomSheetMessageLifeLabel => 'MEDDELANDETS LIVSLÄNGD';

  @override
  String createRoomSheetTtlSeconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String createRoomSheetTtlMinutes(Object minutes) {
    return '${minutes}min';
  }

  @override
  String createRoomSheetTtlHours(Object hours) {
    return '${hours}tim';
  }

  @override
  String get createRoomSheetPasswordLabel => 'LÖSENORD · VALFRITT';

  @override
  String get createRoomSheetPasswordHint => 'lås med en lösenfras…';

  @override
  String get createRoomSheetNameRequiredError => 'namn krävs';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Öppna rummet';

  @override
  String get createRoomSheetOpenRoomButton => 'ÖPPNA RUMMET';

  @override
  String get familyScreenTitle => 'FAMILJ';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count saker behöver ditt OK',
      one: '1 sak behöver ditt OK',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => 'online nu';

  @override
  String get familyScreenPresenceNotPaired => 'inte parkopplad än';

  @override
  String get familyScreenPresenceJustNow => 'just nu';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return '${minutes}min sedan';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return '${hours}tim sedan';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return '${days}d sedan';
  }

  @override
  String get familyScreenPairButton => 'PARKOPPLA';

  @override
  String get familyScreenReleaseButton => 'FRIGÖR';

  @override
  String get familyScreenSettingsButton => 'INSTÄLLNINGAR';

  @override
  String get familyScreenAddChildButton => 'LÄGG TILL BARN';

  @override
  String get familyScreenEmptyStateTitle => 'inga barn än';

  @override
  String get familyScreenEmptyStateBody =>
      'Skapa ett konto åt ditt barn och parkoppla det sedan med deras telefon.';

  @override
  String get reactionDetailsSheetTitle => 'REAKTIONER';

  @override
  String get reactionDetailsSheetEmptyState => 'inget kvar här längre';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personer',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => 'ALLA';

  @override
  String get reactionDetailsSheetYouBadge => 'DU';

  @override
  String get roomLayoutScreenTitle => 'chattlista.';

  @override
  String get roomLayoutScreenSubtitle =>
      'hur rum staplas, och hur du filtrerar dem';

  @override
  String get roomLayoutScreenLayoutSectionLabel => 'LAYOUT';

  @override
  String get roomLayoutScreenRowLayoutLabel => 'RADLAYOUT';

  @override
  String get roomLayoutScreenRowLayoutDescription =>
      'en kolumn, fullbredd. lätt att läsa på en blick.';

  @override
  String get roomLayoutScreenGridLayoutLabel => 'RUTNÄTSLAYOUT';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      'två kolumner, kompakt. fler rum på en blick.';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => 'FILTERKONTROLL';

  @override
  String get roomLayoutScreenChipRowLabel => 'ETIKETTRAD';

  @override
  String get roomLayoutScreenChipRowDescription =>
      'alltid synlig. ett tryck till valfritt filter, tar bara en rad.';

  @override
  String get roomLayoutScreenDrawerButtonLabel => 'UTFÄLLKNAPP';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      'en knapp som öppnas. inget i vägen förrän du ber om det.';

  @override
  String get roomLayoutScreenActiveBadge => 'AKTIV';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel =>
      'Hoppa till fäst meddelande';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => 'Alla fästa meddelanden';

  @override
  String get pinnedBannerTitleSingle => 'Fäst meddelande';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return 'Fäst meddelande  $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => 'chattstil.';

  @override
  String get pinnedBannerChatStyleSubtitle => 'hur rummet ser ut';

  @override
  String get pinnedBannerClassicLabel => 'KLASSISK';

  @override
  String get pinnedBannerClassicSubtitle =>
      'rubrik med kantlinje, platt skrivfält.';

  @override
  String get pinnedBannerCompactLabel => 'KOMPAKT';

  @override
  String get pinnedBannerCompactSubtitle =>
      'frostade ovaler som svävar över samtalet.';

  @override
  String get pinnedBannerActiveBadge => 'AKTIV';

  @override
  String get audioMessageMissingLabel => '[ljud saknas]';

  @override
  String get audioMessageUnavailableLabel => 'ljud otillgängligt';

  @override
  String get audioMessageRetryHint => 'tryck för att försöka igen';

  @override
  String get audioMessageLoadingLabel => 'laddar…';

  @override
  String get audioMessageUsernameRequiredError => 'Ange ditt användarnamn.';

  @override
  String get audioMessagePasswordRequiredError => 'Ange ditt lösenord.';

  @override
  String get audioMessageCancelSemanticLabel => 'Avbryt';

  @override
  String get audioMessageHeroCreateLine1 => 'nästan\n';

  @override
  String get audioMessageHeroCreateLine2 => 'framme.';

  @override
  String get audioMessageHeroLinkLine1 => 'välkommen\n';

  @override
  String get audioMessageHeroLinkLine2 => 'tillbaka.';

  @override
  String get audioMessageCreateSubtitle =>
      'Välj ett användarnamn så att din familj och dina vänner kan hitta dig.';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return 'Logga in en gång så kopplas $provider till ditt konto.';
  }

  @override
  String get audioMessageUsernameHint => 'användarnamn';

  @override
  String get audioMessageDisplayNameHint => 'visningsnamn (valfritt)';

  @override
  String get audioMessagePasswordHint => 'lösenord';

  @override
  String get audioMessageSwitchToLinkPrompt => 'Det kontot är mitt — logga in';

  @override
  String get audioMessageCreateAccountButton => 'SKAPA KONTO';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return 'LOGGA IN OCH KOPPLA $provider';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => 'Har du redan ett konto?';

  @override
  String get audioMessageSwitchToCreateModeLink => 'Ny här? Skapa ett konto';

  @override
  String get approvalsScreenTitle => 'GODKÄNNANDEN';

  @override
  String get approvalsScreenEmptyTitle => 'inget väntar';

  @override
  String get approvalsScreenEmptySubtitle => 'du är helt ikapp';

  @override
  String get approvalsScreenErrorNotGuardian => 'det där är inte upp till dig';

  @override
  String get approvalsScreenErrorAlreadyHandled =>
      'redan hanterat någon annanstans';

  @override
  String get approvalsScreenErrorGeneric =>
      'det gick inte att spara — försök igen';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child vill lägga till $other';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other vill lägga till $child';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child vill gå med i $room';
  }

  @override
  String get approvalsScreenSomeoneLower => 'någon';

  @override
  String get approvalsScreenSomeoneCapital => 'Någon';

  @override
  String get approvalsScreenRoomFallback => 'ett rum';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      'De får förfrågan. De väljer ändå själva om de vill tacka ja.';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$child kommer att se förfrågan och kan acceptera eller ignorera den.';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      'De kommer att kunna läsa och skriva där tills du återkallar det.';

  @override
  String get approvalsScreenNotYetButton => 'INTE ÄN';

  @override
  String get approvalsScreenAllowButton => 'TILLÅT';

  @override
  String get approvalsScreenForwardDirectMessageFallback => 'direktmeddelande';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'VIDAREBEFORDRA $count MEDDELANDEN',
      one: 'VIDAREBEFORDRA MEDDELANDE',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'inga andra chattar än';

  @override
  String get approvalsScreenForwardNoMatches => 'inga träffar';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'upp till $max chattar åt gången';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'sök chattar';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Avmarkera $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Markera $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'FÖRSVINNER';

  @override
  String get approvalsScreenForwardSendSemantic => 'Skicka';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'SKICKA TILL $count',
      zero: 'SKICKA',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => 'KOPPLADE KONTON';

  @override
  String get linkedAccountsScreenSubtitle =>
      'Konton du har kopplat till det här kontot, så att du kan logga in utan lösenord.';

  @override
  String get linkedAccountsScreenEmptyState =>
      'Det finns inget att koppla på den här enheten.';

  @override
  String get linkedAccountsScreenStatusChecking => 'Kontrollerar…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return 'Du kan logga in med $provider på alla dina enheter.';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return 'Lägg till $provider så slipper du skriva ditt lösenord.';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return 'KOPPLA BORT $provider';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => 'KOPPLA BORT';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return 'Ange ditt lösenord för att sluta logga in med $provider.';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return 'KOPPLA $provider';
  }

  @override
  String get linkedAccountsScreenLinkAction => 'KOPPLA';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return 'Ange ditt lösenord för att lägga till $provider som ett sätt att logga in.';
  }

  @override
  String get linkedAccountsScreenPillChecking => 'KONTROLLERAR';

  @override
  String get linkedAccountsScreenPillLinked => 'KOPPLAD';

  @override
  String get linkedAccountsScreenPillNotLinked => 'INTE KOPPLAD';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => 'RÖST';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'VIDEO';

  @override
  String get linkedAccountsScreenCallSheetTitle => 'Starta ett samtal';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle => 'Ring alla';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      'Ringer alla medlemmar i det här rummet';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle => 'Välj personer';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle =>
      'Välj vem du vill bjuda in';

  @override
  String get linkedAccountsScreenCallSheetCallFullError =>
      'Samtalet är fullt (max 6 personer)';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError =>
      'Kunde inte starta samtalet';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle => 'Bjud in till samtal';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers =>
      'Inga andra medlemmar här';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => 'Välj personer';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => 'Starta samtal';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return 'Starta samtal ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => 'hej';

  @override
  String get childPairScreenGreetingLine2 => 'dig.';

  @override
  String get childPairScreenIntro =>
      'Be en vuxen öppna MonkeyHub och trycka på ”para ihop en enhet”. Skanna sedan deras kod, eller skriv in de sex siffror de läser upp.';

  @override
  String get childPairScreenOrDivider => 'eller';

  @override
  String get childPairScreenGenericError => 'Något gick fel. Försök igen.';

  @override
  String get childPairScreenAccountGoneError => 'Det kontot finns inte längre.';

  @override
  String get childPairScreenScanButtonLabel => 'SKANNA DERAS KOD';

  @override
  String get childPairScreenNoCameraMessage =>
      'Ingen kamera här — skriv in de sex siffrorna istället.';

  @override
  String get childPairScreenStopScanning => 'sluta skanna';

  @override
  String get childPairScreenSubmitButtonLabel => 'SLÄPP IN MIG';

  @override
  String get childPairScreenBackToSignIn => '← tillbaka till inloggning';

  @override
  String get fileMessageUnavailable => 'filen finns inte längre';

  @override
  String get fileMessageOpenFailed => 'kunde inte öppna filen';

  @override
  String get fileMessageDefaultName => 'dokument';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return 'Spara $name';
  }

  @override
  String get fileMessageUploadFailedLabel => 'misslyckades';

  @override
  String get fileMessageSendingLabel => 'skickar…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · skickar…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return '$count min sedan';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return '$count h sedan';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return '$count d sedan';
  }

  @override
  String get fileMessageStandardBadge => 'STANDARD';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utkast · tryck för att visa',
      one: '$count utkast · tryck för att visa',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => 'GODKÄNN';

  @override
  String get fileMessageDeclineButton => 'AVVISA';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'SKICKAD $ago';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meddelanden väntar',
      one: '$count meddelande väntar',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => 'AVBRYT FÖRFRÅGAN';

  @override
  String get destructiveSheetCannotBeUndone => 'detta kan inte ångras';

  @override
  String get destructiveSheetCancelSemanticLabel => 'Avbryt';

  @override
  String get destructiveSheetCancelButtonLabel => 'AVBRYT';

  @override
  String get destructiveSheetHideLabel => 'DÖLJ';

  @override
  String get destructiveSheetViewLabel => 'VISA';

  @override
  String get destructiveSheetPairingMintError =>
      'Kunde inte skapa en kod — försök igen.';

  @override
  String get destructiveSheetPairingReleaseTitle => 'FRIGÖR';

  @override
  String get destructiveSheetPairingPairTitle => 'PARKOPPLA';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return 'Öppna profilen på ${name}s telefon, tryck på ”lämna tillbaka telefonen” och skriv in de här siffrorna.';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return 'Öppna MonkeyHub på ${name}s telefon och skanna den här — eller skriv in siffrorna.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'den här koden har gått ut';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'går ut om $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'NY KOD';

  @override
  String get destructiveSheetPairingOneUseNote =>
      'Kan bara användas en gång. En ny kod gör den gamla ogiltig.';

  @override
  String get deepOceanThemeAttachButtonLabel => 'Bifoga';

  @override
  String get deepOceanThemeCameraButtonLabel => 'Kamera';

  @override
  String get deepOceanThemeSendButtonLabel => 'Skicka';

  @override
  String get deepOceanThemeEphemeralHint => 'viska något som servern glömmer…';

  @override
  String get deepOceanThemeDefaultHint => 'säg något…';

  @override
  String get deepOceanThemeMessageHint => 'Meddelande';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'den här filen är borta';

  @override
  String get photoChromeMediaYouLabel => 'du';

  @override
  String get photoChromeCloseSemanticLabel => 'Stäng';

  @override
  String get photoChromeShowInChatSemanticLabel => 'Visa i chatten';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name skriver';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1 och $name2 skriver';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1, $name2 +$extra skriver';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => 'inkommande samtal';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'INKOMMANDE VIDEOSAMTAL';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'INKOMMANDE RÖSTSAMTAL';

  @override
  String get typingIndicatorDeclineButtonLabel => 'avvisa';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'avvisar…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'svara';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'ansluter…';

  @override
  String get messageStampNavigationTitle => 'navigering.';

  @override
  String get messageStampNavigationSubtitle =>
      'hur du rör dig mellan chatt, upptäck, flöde och inställningar';

  @override
  String get messageStampRadialOrbLabel => 'RADIELL ORB';

  @override
  String get messageStampRadialOrbDescription =>
      'håll intryckt och dra från hörnet. tyst i vila, en gest du växer in i.';

  @override
  String get messageStampBottomPillLabel => 'NEDRE KAPSEL';

  @override
  String get messageStampBottomPillDescription =>
      'klassiskt tryck. alltid synlig, ingen inlärningskurva.';

  @override
  String get messageStampActiveLabel => 'AKTIV';

  @override
  String get messageStampUploadingLabel => 'laddar upp';

  @override
  String get messageStampSendingLabel => 'skickar';

  @override
  String get messageStampFailedToSendLabel => 'kunde inte skickas';

  @override
  String get messageStampSeenLabel => 'läst';

  @override
  String messageStampCountdownSeconds(Object count) {
    return '${count}s';
  }

  @override
  String messageStampCountdownMinutes(Object count) {
    return '${count}min';
  }

  @override
  String get voiceRecorderScreenMicPermissionDeniedSnackbar =>
      'mikrofonåtkomst nekad';

  @override
  String get voiceRecorderScreenStatusRecording => 'SPELAR IN';

  @override
  String get voiceRecorderScreenStatusReady => 'KLAR';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'TRYCK FÖR ATT STARTA';

  @override
  String get voiceRecorderScreenReRecordButton => 'SPELA IN IGEN';

  @override
  String get voiceRecorderScreenStopButton => 'STOPPA';

  @override
  String get voiceRecorderScreenSendButton => 'SKICKA';

  @override
  String get voiceRecorderScreenRecordButton => 'SPELA IN';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => 'Alla';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => 'AVISERAR ALLA';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => 'ÄGARE';

  @override
  String get releaseDeviceScreenFallbackChildName => 'hen';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return 'Detta loggar ut $name från den här telefonen och lämnar tillbaka den — telefonen återgår till den vanliga inloggningsskärmen, och vem som helst kan använda den.';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'Hens konto, meddelanden och vänner finns kvar. Hen kan logga in igen när som helst.';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return 'Be en vuxen att öppna MonkeyHub, hitta $name under familj och trycka på ”släpp”.';
  }

  @override
  String get releaseDeviceScreenOrDivider => 'eller';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      'Om det bara finns den här telefonen kan en vuxen logga in här istället.';

  @override
  String get releaseDeviceScreenUsernameHint => 'en vuxens användarnamn';

  @override
  String get releaseDeviceScreenPasswordHint => 'hens lösenord';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => 'Logga ut';

  @override
  String get releaseDeviceScreenChecking => 'KONTROLLERAR…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return 'LOGGA UT $name';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => 'LÄMNA TILLBAKA TELEFONEN';

  @override
  String get releaseDeviceScreenErrorCodeExpired =>
      'Koden har gått ut. Be om en ny.';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      'Koden fungerade inte. Den kan redan ha använts.';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      'Det där fungerade inte. Kontrollera användarnamnet och lösenordet.';

  @override
  String get releaseDeviceScreenErrorGeneric => 'Något gick fel. Försök igen.';

  @override
  String get activeCallPillMoveHereSemanticLabel =>
      'Flytta samtalet till den här enheten';

  @override
  String activeCallPillCallWith(Object name) {
    return 'Samtal med $name';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return 'På $device';
  }

  @override
  String get activeCallPillMoveHereLabel => 'Flytta hit';

  @override
  String get activeCallPillUnknownCaller => 'Okänd';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'iOS-simulator';

  @override
  String get activeCallPillPlatformAndroid => 'Android-enhet';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'Windows-dator';

  @override
  String get activeCallPillPlatformLinux => 'Linux-enhet';

  @override
  String get activeCallPillPlatformBrowser => 'Webbläsare';

  @override
  String get activeCallPillPlatformOther => 'en annan enhet';

  @override
  String get activeCallPillPinnedHeader => 'FÄSTA';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'FÄSTA · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'inget är fäst längre';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Hoppa till meddelande från $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Lossa meddelande från $name';
  }

  @override
  String get callButtonErrorBusy => 'upptagen i ett annat samtal';

  @override
  String get callButtonErrorCallFailed => 'kunde inte starta samtalet';

  @override
  String get callButtonErrorNotMember => 'inte medlem i det här rummet';

  @override
  String get callButtonErrorGeneric => 'kunde inte starta samtalet';

  @override
  String get callButtonAlreadyOnCall => 'Du är redan i ett samtal';

  @override
  String get callButtonBusyElsewhere => 'Samtal pågår på en annan enhet';

  @override
  String get callButtonVoiceCallTooltip => 'röstsamtal';

  @override
  String get callButtonVideoCallTooltip => 'videosamtal';

  @override
  String get callButtonTooltip => 'samtal';

  @override
  String get callButtonReplyStyleTitle => 'svarsstil.';

  @override
  String get callButtonReplyStyleSubtitle =>
      'hur ett svar visar meddelandet det svarar på';

  @override
  String get callButtonReplyStylePhantomEchoLabel => 'FANTOMEKO';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      'en spökbubbla av ursprungsmeddelandet svävar ovanför, med en böjd anslutningslinje och grenikonen vid anslutningspunkten.';

  @override
  String get callButtonReplyStyleStickyNoteLabel => 'KLISTERLAPP';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      'ett lätt vridet kort i polaroidstil, fastklämt i bubblans hörn.';

  @override
  String get callButtonReplyStyleComicTailLabel => 'SERIESVANS';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      'en liten minibubbla av ursprungsmeddelandet med en triangelformad serietidningssvans som pekar nedåt.';

  @override
  String get callButtonReplyStyleClassicLabel => 'KLASSISK';

  @override
  String get callButtonReplyStyleClassicDescription =>
      'en accentfärgad citatbricka i rundad form, med en kopplingslinje och avatar — den bekanta känslan från WhatsApp.';

  @override
  String get callButtonReplyStyleActiveBadge => 'AKTIV';

  @override
  String get callButtonReplyPreviewSampleMessage =>
      'har du sett den nya demon förresten?';

  @override
  String get callButtonReplyPreviewSampleReply =>
      'ja, den där blureffekten är sjuk.';

  @override
  String get childSetupScreenErrorPickUsername =>
      'Välj ett användarnamn åt hen.';

  @override
  String get childSetupScreenErrorUsernameTaken =>
      'Det användarnamnet är redan upptaget.';

  @override
  String get childSetupScreenErrorChildNotAllowed =>
      'Endast ett vuxenkonto kan lägga till ett barn.';

  @override
  String get childSetupScreenErrorGeneric =>
      'Det gick inte att skapa kontot — försök igen.';

  @override
  String get childSetupScreenTitle => 'LÄGG TILL BARN';

  @override
  String get childSetupScreenHeading => 'vem\när hen?';

  @override
  String get childSetupScreenNameLabel => 'NAMN';

  @override
  String get childSetupScreenNameHint => 'vad du kallar hen';

  @override
  String get childSetupScreenUsernameLabel => 'ANVÄNDARNAMN';

  @override
  String get childSetupScreenUsernameHint => 'hur vänner hittar hen';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'VAD HEN FÅR';

  @override
  String get childSetupScreenBulletTalkImmediately =>
      'Hen kan prata med dig och sina syskon direkt.';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      'Alla andra behöver ditt godkännande först — både de hen vill lägga till, och de som vill lägga till hen.';

  @override
  String get childSetupScreenBulletPublicRoomsOff =>
      'Offentliga rum är avstängda tills du sätter på dem.';

  @override
  String get childSetupScreenBulletCantSignOut =>
      'Hen kan inte logga ut, och du kan alltid se hur det går för hen.';

  @override
  String get childSetupScreenCreateButton => 'SKAPA + PARKOPPLA';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return 'Skicka meddelande till $name';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => 'frågat';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'MEDLEMMAR';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'se alla $count';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return 'Se alla $count';
  }

  @override
  String get bubbleStyleScreenTitle => 'bubbelstil.';

  @override
  String get bubbleStyleScreenSubtitle => 'formen dina ord kommer i';

  @override
  String get bubbleStyleScreenTailedLabel => 'SVANSAD';

  @override
  String get bubbleStyleScreenTailedDescription =>
      'en svans avslutar varje meddelandeserie; raderna ovanför dras samman till ett enda block.';

  @override
  String get bubbleStyleScreenSoftLabel => 'MJUK';

  @override
  String get bubbleStyleScreenSoftDescription =>
      'ingen svans – en följd hålls ihop enbart genom sina indragna inre hörn.';

  @override
  String get bubbleStyleScreenPillLabel => 'KAPSEL';

  @override
  String get bubbleStyleScreenPillDescription =>
      'helt rundade kapslar, identiska på varje rad.';

  @override
  String get bubbleStyleScreenSlabLabel => 'PLATTA';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'fyrkantiga axlar – skarpa, tryckta, medvetna.';

  @override
  String get bubbleStyleScreenActiveBadge => 'AKTIV';

  @override
  String get bubbleStyleScreenPreviewQuestion => 'nå? hur ser det ut';

  @override
  String get bubbleStyleScreenPreviewReplyOne => 'bättre';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => 'mycket bättre';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => 'Video';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => 'Foto';

  @override
  String get incomingGroupCallScreenCallFullError =>
      'Det samtalet är fullt (max 6 personer)';

  @override
  String get incomingGroupCallScreenJoinFailedError =>
      'Det gick inte att ansluta till samtalet';

  @override
  String get incomingGroupCallScreenDefaultRoomName => 'Gruppsamtal';

  @override
  String get incomingGroupCallScreenDefaultStarterName => 'Någon';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starter startade ett videosamtal';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starter startade ett röstsamtal';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '$count redan med';
  }

  @override
  String get incomingGroupCallScreenDismissButton => 'Avvisa';

  @override
  String get incomingGroupCallScreenJoinButton => 'Anslut';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chattar',
      one: '$count chatt',
    );
    return '$_temp0';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meddelanden',
      one: '$count meddelande',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      'senaste meddelandet nyss';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'senaste meddelandet för ${hours}h sedan';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'senaste meddelandet igår';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'senaste meddelandet för $days dagar sedan';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'senaste meddelandet för ett tag sedan';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge =>
      'TA TILLBAKA';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return 'ska vi ta tillbaka $contactName från $childName?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'de kan inte längre nå varandra, och deras konversation försvinner också.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'de kan inte längre nå varandra. $contactName får inte veta det.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats · $messages kommer att raderas';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      'försvinner för båda, inklusive foton och röstmeddelanden. detta kan inte ångras.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'de delar också $count rum',
      one: 'de delar också $count rum',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'de här ligger kvar. ta tillbaka rummet från RUM-listan nedan om du vill bli av med dem.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'TA TILLBAKA & RADERA';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'tar bort $contactName och raderar $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'tar bort $contactName från listan över tillåtna kontakter.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Avbryt';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => 'AVBRYT';

  @override
  String get groupCallBannerCallFullError =>
      'Samtalet är fullt (max 6 personer)';

  @override
  String get groupCallBannerJoinFailedError =>
      'Det gick inte att ansluta till samtalet';

  @override
  String get groupCallBannerUnknownParticipant => 'Någon';

  @override
  String get groupCallBannerOngoingVideoCall => 'Pågående videosamtal';

  @override
  String get groupCallBannerOngoingVoiceCall => 'Pågående röstsamtal';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra i samtalet';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => 'Anslut till samtalet';

  @override
  String get groupCallBannerJoinButtonLabel => 'ANSLUT';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'ANSLUT TILL RUM';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '$count medlem',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => 'LÖSENORD';

  @override
  String get groupCallBannerPasswordHint => 'lösenfras…';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Anslut';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'ANSLUT';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Avbryt';

  @override
  String get groupCallBannerCancelButtonLabel => 'avbryt';

  @override
  String get viewOnceViewerBadgeLabel => 'VISAS EN GÅNG';

  @override
  String get viewOnceViewerSocialDividerOr => 'eller';

  @override
  String get viewOnceViewerAppleContinueButton => 'Fortsätt med Apple';

  @override
  String get viewOnceViewerGoogleContinueButton => 'Fortsätt med Google';

  @override
  String get discoverListsPeopleTitle => 'dina vänner.';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personer',
      one: '$count person',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => 'filtrera dina vänner…';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Rensa filter';

  @override
  String get discoverListsNoOneYet => 'ingen än';

  @override
  String discoverListsNoMatches(Object query) {
    return 'ingen matchar \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'RÖSTSAMTAL';

  @override
  String get discoverListsVideoCallLabel => 'VIDEOSAMTAL';

  @override
  String get approvalGateAlreadyAskedLabel => 'REDAN FRÅGAT';

  @override
  String get approvalGateAskGrownUpLabel => 'FRÅGA EN VUXEN';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return 'Du har redan frågat om $what.';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return 'En vuxen måste säga ja innan du kan $what.';
  }

  @override
  String get approvalGateDisabledBody =>
      'En vuxen har stängt av det här för tillfället.';

  @override
  String get approvalGateAlreadyAskedFooter =>
      'De får ett meddelande om det. Kolla igen snart.';

  @override
  String get approvalGateWillNotifyFooter =>
      'Vi berättar för dem. Du ser det här när de svarar.';

  @override
  String get approvalGateTalkToThemFooter =>
      'Du kan prata med dem om det om du tycker att det borde ändras.';

  @override
  String get approvalGateAskButton => 'FRÅGA';

  @override
  String get approvalGateNotNowButton => 'INTE NU';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => 'väntar på en vuxen';

  @override
  String get reportSheetTitle => 'ANMÄL';

  @override
  String get reportSheetSubtitle => 'berätta vad som är fel.';

  @override
  String get reportSheetPrivacyNote =>
      'anmälningar är privata — den andra personen meddelas inte.';

  @override
  String get reportSheetReasonSpamLabel => 'SPAM';

  @override
  String get reportSheetReasonSpamDescription =>
      'oönskad reklam eller upprepade meddelanden';

  @override
  String get reportSheetReasonHarassmentLabel => 'TRAKASSERIER';

  @override
  String get reportSheetReasonHarassmentDescription =>
      'trakasserier eller mobbning';

  @override
  String get reportSheetReasonImpersonationLabel => 'IDENTITETSSTÖLD';

  @override
  String get reportSheetReasonImpersonationDescription =>
      'utger sig för att vara någon annan';

  @override
  String get reportSheetReasonInappropriateLabel => 'OLÄMPLIGT';

  @override
  String get reportSheetReasonInappropriateDescription =>
      'sexuellt, våldsamt eller olagligt innehåll';

  @override
  String get reportSheetReasonOtherLabel => 'ANNAT';

  @override
  String get reportSheetReasonOtherDescription => 'något annat';

  @override
  String get reportSheetOtherNoteHint => 'vad hände?';

  @override
  String get reportSheetSubmitSemanticLabel => 'Skicka anmälan';

  @override
  String get reportSheetSubmitButton => 'SKICKA';

  @override
  String get reportSheetUpdateRequiredTitle => 'UPPDATERING KRÄVS';

  @override
  String get reportSheetUpdateAvailableTitle => 'UPPDATERING TILLGÄNGLIG';

  @override
  String get reportSheetUpdateMandatoryBody =>
      'Den här versionen är för gammal för att fungera som den ska. Uppdatera för att fortsätta.';

  @override
  String get reportSheetUpdateAvailableBody =>
      'Det finns en nyare version av MonkeyHub.';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => 'UPPDATERA';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'öppnar TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'öppnar App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'öppnar Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'öppnar nedladdningssidan';

  @override
  String get reportSheetUpdateActionReloads =>
      'laddar om med den nya versionen';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Senare';

  @override
  String get reportSheetUpdateLaterButton => 'SENARE';

  @override
  String get roomFilterBarAllChipLabel => 'alla';

  @override
  String roomFilterBarChipCountSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chattar',
      one: '$count chatt',
    );
    return '$label, $_temp0';
  }

  @override
  String composerReplyCardReplyingToLabel(Object name) {
    return 'SVARAR PÅ $name';
  }

  @override
  String get roomCardLockedBadge => 'LÅST';

  @override
  String get roomCardTimeAgoJustNow => 'just nu';

  @override
  String roomCardTimeAgoSeconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String roomCardTimeAgoMinutes(Object minutes) {
    return '${minutes}min';
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
    return '${weeks}v';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count inne';
  }

  @override
  String get roomCardMessagesFadeLabel => 'meddelanden bleknar';

  @override
  String get roomCardEnterLabel => '↗ gå in';

  @override
  String get roomCardBlockedScreenTitle => 'BLOCKERADE';

  @override
  String get roomCardBlockedEmptyState => 'du har inte blockerat någon.';

  @override
  String get roomCardUnblockButton => 'AVBLOCKERA';

  @override
  String get attachmentMenuPhotoLabel => 'foto';

  @override
  String get attachmentMenuVideoLabel => 'video';

  @override
  String get attachmentMenuCameraLabel => 'kamera';

  @override
  String get attachmentMenuVoiceLabel => 'röst';

  @override
  String get attachmentMenuFileLabel => 'fil';

  @override
  String get attachmentMenuConnectionRetrying => 'försöker igen…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'kan inte nå servern · tryck för att försöka igen';

  @override
  String get attachmentMenuConnectionReconnecting => 'återansluter…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Försök ansluta igen';

  @override
  String get roomGridTileLockedBadge => 'LÅST';

  @override
  String get roomGridTileEmptyLastMessage => 'tyst hittills';

  @override
  String get roomGridTileMemberCountLabel => 'INNE';

  @override
  String get roomGridTileThemeChipLabel => 'TEMA';

  @override
  String get bulkActionBarCancelLabel => 'AVBRYT';

  @override
  String get bulkActionBarSelectMessagesLabel => 'VÄLJ MEDDELANDEN';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count VALDA';
  }

  @override
  String get bulkActionBarForwardLabel => 'VIDAREBEFORDRA';

  @override
  String get bulkActionBarDeleteLabel => 'RADERA';

  @override
  String get bulkActionBarJumpBackLabel => 'TILLBAKA';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return 'TILLBAKA · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel =>
      'Tillbaka dit du hoppade från';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return 'Tillbaka dit du hoppade från, $depth kvar';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote =>
      'de får ingen avisering.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'ni är vänner just nu — att blockera tar bort vänskapen, så för att återansluta senare behöver du skicka en ny vänförfrågan.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'de försvinner från dina sökresultat och kan inte skicka meddelanden till dig.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'BLOCKERA';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return 'blockera $name?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'du delar $count rum med dem',
      one: 'du delar $count rum med dem',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'de här rummen förblir orörda. du kan själv lämna dem via varje rums inställningar.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'BLOCKERA';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'tar bort vänskapen och blockerar. befintlig chatthistorik finns kvar i ditt arkiv.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'de döljs från sökningar och kan inte nå dig.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'BLOCKERA & RADERA DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'raderar även din DM med dem — alla meddelanden, reaktioner och mediafiler försvinner.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Avbryt';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'AVBRYT';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle =>
      'Visa samtal på låsskärmen';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      'För att det ska ringa som ett riktigt telefonsamtal när skärmen är avstängd behöver MonkeyHub ha ”helskärmsaviseringar” påslaget. Nästa skärm tar dig direkt till inställningen.';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle =>
      'Missa aldrig ett samtal';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      'Vissa telefoner pausar appar i bakgrunden för att spara batteri, vilket kan tysta inkommande samtal. Tillåt MonkeyHub att köras utan begränsningar så att samtal alltid kommer fram.';

  @override
  String get bulkActionBarDialogNotNowButton => 'Inte nu';

  @override
  String get bulkActionBarDialogContinueButton => 'Fortsätt';

  @override
  String get reactionBubbleJumpToLatestLabel => 'HOPPA TILL SENASTE';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel => 'Hoppa till senaste';

  @override
  String get reactionBubblePickerTitle => 'REAGERA';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'inga senaste än';

  @override
  String get reactionBubblePasswordHint => 'lösenord';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return 'gå med i $roomName';
  }

  @override
  String get enterPublicRoomAskFailedMessage =>
      'kunde inte fråga just nu — försök igen';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'fel lösenord';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'kunde inte gå med — försök igen';

  @override
  String get enterPublicRoomFeedTabLabel => 'FLÖDE';

  @override
  String get enterPublicRoomFeedHeadlineSoon => 'snart.\n';

  @override
  String get enterPublicRoomFeedHeadlineDetail =>
      'dagliga stunder,\ndelade med rum.';

  @override
  String get enterPublicRoomFeedPipelineLabel => 'PÅ GÅNG';

  @override
  String get enterPublicRoomFeedBulletPrompt =>
      'en daglig fråga som rummet svarar på';

  @override
  String get enterPublicRoomFeedBulletVoiceNotes =>
      'röstmeddelanden som bleknar bort automatiskt med dagen';

  @override
  String get enterPublicRoomFeedBulletWallUpdates =>
      'en vägg med små, stillsamma uppdateringar från vänner';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'OFFENTLIG';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'PRIVAT';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'MEDLEM';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'FLYKTIG · $duration';
  }

  @override
  String enterPublicRoomEphemeralSecondsShort(Object seconds) {
    return '${seconds}s';
  }

  @override
  String enterPublicRoomEphemeralMinutesShort(Object minutes) {
    return '${minutes}min';
  }

  @override
  String enterPublicRoomEphemeralHoursShort(Object hours) {
    return '${hours}h';
  }

  @override
  String get countBadgeCaptureProtectionLabel => 'SKÄRMSKYDD';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      'skärmdumpar och skärminspelning visas svarta för systemet.';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      'skärminspelning och skärmspegling lägger en integritetsskärm över appen.';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      'skärmdumpar och inspelningar fungerar som vanligt utanför flyktiga rum.';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      'flyktiga rum (hemligheternas kammare) har alltid detta påslaget, oavsett.';

  @override
  String get countBadgeShowPasswordTooltip => 'visa lösenord';

  @override
  String get countBadgeHidePasswordTooltip => 'dölj lösenord';

  @override
  String get countBadgeProtectedLabel => 'SKYDDAD';

  @override
  String get countBadgeCaptureShieldActiveBody =>
      'skärminspelning eller skärmspegling är aktiv.';

  @override
  String get countBadgeCaptureShieldReassurance =>
      'inspelningen kan inte se dina samtal.';

  @override
  String get linkOpenerCouldNotOpenLink => 'Kunde inte öppna länken';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel =>
      'Skapa en återställningsfras';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'ingen återställningsfras — du kan bli utelåst för gott.';

  @override
  String get destinationsChatLabel => 'Chatt';

  @override
  String get destinationsChatShort => 'CHATT';

  @override
  String get destinationsDiscoverLabel => 'Upptäck';

  @override
  String get destinationsDiscoverShort => 'HITTA';

  @override
  String get destinationsFeedLabel => 'Flöde';

  @override
  String get destinationsFeedShort => 'FLÖDE';

  @override
  String get destinationsSettingsLabel => 'Inställningar';

  @override
  String get destinationsSettingsShort => 'INST';

  @override
  String get familyRequestStageSenderGuardianLabel => 'väntar på en vuxen';

  @override
  String get familyRequestStageRecipientLabel => 'väntar på dem';

  @override
  String get roomContentTabLabelMedia => 'MEDIA';

  @override
  String get roomContentTabLabelFiles => 'FILER';

  @override
  String get roomContentTabLabelVoice => 'RÖST';

  @override
  String get roomContentTabLabelLinks => 'LÄNKAR';

  @override
  String get roomContentTabHeaderMedia => 'media';

  @override
  String get roomContentTabHeaderFiles => 'filer';

  @override
  String get roomContentTabHeaderVoice => 'röst';

  @override
  String get roomContentTabHeaderLinks => 'länkar';

  @override
  String get roomFacetLabelDms => 'dm';

  @override
  String get roomFacetLabelGroups => 'grupper';

  @override
  String get roomFacetLabelPublic => 'publika';

  @override
  String get roomFacetLabelPrivate => 'privata';

  @override
  String get roomFacetLabelSecret => 'hemliga';

  @override
  String get roomFacetLabelLocked => 'låsta';

  @override
  String get roomFacetLabelUnread => 'olästa';

  @override
  String get roomFacetLabelMentions => 'omnämnanden';

  @override
  String get settingsScreenTitle => 'INSTÄLLNINGAR';

  @override
  String get settingsScreenTagline => 'utseende. känsla. du.';

  @override
  String get settingsScreenAccountHintChild =>
      'profil · sekretess · mina vuxna';

  @override
  String get settingsScreenAccountHintAdult =>
      'profil · familj · länkade konton · sekretess';

  @override
  String get settingsScreenSectionAppearance => 'UTSEENDE';

  @override
  String get settingsScreenSectionLayout => 'LAYOUT';

  @override
  String get settingsScreenSectionGeneral => 'ALLMÄNT';

  @override
  String get settingsScreenSectionLinks => 'LÄNKAR';

  @override
  String get settingsScreenSectionNotifications => 'NOTISER';

  @override
  String get settingsScreenRowTheme => 'TEMA';

  @override
  String get settingsScreenRowAppLogo => 'APPLOGGA';

  @override
  String get settingsScreenRowGlass => 'GLAS';

  @override
  String get settingsScreenRowChatList => 'CHATTLISTA';

  @override
  String get settingsScreenRowNavigation => 'NAVIGERING';

  @override
  String get settingsScreenRowChatStyle => 'CHATTSTIL';

  @override
  String get settingsScreenRowBubbleStyle => 'BUBBELSTIL';

  @override
  String get settingsScreenRowReplyStyle => 'SVARSSTIL';

  @override
  String get settingsScreenValueScrollList => 'Listvy';

  @override
  String get settingsScreenValueGridSheet => 'Rutnätsvy';

  @override
  String get settingsScreenValueRadialOrb => 'Radiell kula';

  @override
  String get settingsScreenValueBottomPill => 'Nedre oval';

  @override
  String get settingsScreenValueCustom => 'Anpassad';

  @override
  String settingsScreenValueEdited(Object name) {
    return '$name · redigerad';
  }

  @override
  String get settingsScreenValueClassic => 'Klassisk';

  @override
  String get settingsScreenValueCompact => 'Kompakt';

  @override
  String get settingsScreenValueBubbleTailed => 'Svansad';

  @override
  String get settingsScreenValueBubbleSoft => 'Mjuk';

  @override
  String get settingsScreenValueBubblePill => 'Oval';

  @override
  String get settingsScreenValueBubbleSlab => 'Kantig';

  @override
  String get settingsScreenValueReplyPhantomEcho => 'Fantomeko';

  @override
  String get settingsScreenValueReplyStickyNote => 'Klisterlapp';

  @override
  String get settingsScreenValueReplyComicTail => 'Seriesvans';

  @override
  String get settingsScreenValueLogoAuto => 'Auto';

  @override
  String get settingsScreenValueLogoManual => 'Manuell';

  @override
  String get settingsScreenShowLinkUrlsLabel => 'VISA LÄNKADRESSER';

  @override
  String get settingsScreenLinksUrlsOnBody =>
      'hela webbadressen visas bredvid förhandsgranskningen';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      'bara förhandsgranskning — renare bubblor, tryck för att öppna';

  @override
  String get settingsScreenPushNotificationsLabel => 'PUSHNOTISER';

  @override
  String get settingsScreenPushOnBody =>
      'pingar vid nya meddelanden och förfrågningar';

  @override
  String get settingsScreenPushOffBody =>
      'tyst — du ser bara saker när du öppnar appen';

  @override
  String get authErrorUsernameTaken => 'Det användarnamnet är redan taget.';

  @override
  String get authErrorUserNotFound => 'Inget konto med det användarnamnet.';

  @override
  String get authErrorWrongPassword => 'Fel lösenord.';

  @override
  String get authErrorInvalidRecoveryKey =>
      'Det användarnamnet och den återställningsfrasen matchar inte varandra.';

  @override
  String get authErrorTooManyAttempts =>
      'För många försök. Vänta 15 minuter och försök igen.';

  @override
  String get authErrorChildMustPair =>
      'Det där är ett barnkonto — be en vuxen om en parningskod.';

  @override
  String get authErrorPairingCodeExpired =>
      'Den koden har gått ut. Be om en ny.';

  @override
  String get authErrorPairingCodeInvalid =>
      'Den koden fungerade inte. Den kan redan ha använts.';

  @override
  String get authErrorUseSocialSignIn =>
      'Det kontot loggar in med Apple eller Google — använd knapparna nedan.';

  @override
  String get authErrorSocialTokenInvalid =>
      'Den inloggningen gick inte igenom. Försök igen.';

  @override
  String get authErrorSocialNonceMismatch =>
      'Inloggningen gick inte igenom. Försök igen.';

  @override
  String get authErrorSocialMisconfig =>
      'Inloggningen är inte redo på vår sida än. Försök igen senare.';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      'Det Apple- eller Google-kontot är redan länkat till ett annat MonkeyHub-konto.';

  @override
  String get authErrorSocialAlreadyLinked =>
      'Det är redan länkat till det här kontot.';

  @override
  String get authErrorSocialNotLinked =>
      'Det är inte länkat till det här kontot.';

  @override
  String get authErrorSocialLastCredential =>
      'Det är det enda sättet att komma in på det här kontot. Skapa ett lösenord först.';

  @override
  String get authErrorUsernameInvalid =>
      'Välj ett användarnamn på mellan 1 och 32 tecken.';

  @override
  String get glassKnobLabelFrost => 'FROSTNING';

  @override
  String get glassKnobHintFrost =>
      'hur mycket vitt som ligger på glaset. lägre för mer genomskinligt';

  @override
  String get glassKnobLabelBlur => 'OSKÄRPA';

  @override
  String get glassKnobHintBlur =>
      'frostat i toppen av skalan, klart glas i botten';

  @override
  String get glassKnobLabelSaturation => 'FÄRGLÄCKAGE';

  @override
  String get glassKnobHintSaturation =>
      'hur mycket färg som överlever oskärpan. efter 2 posteriseras den';

  @override
  String get glassKnobLabelRimOpacity => 'KANT';

  @override
  String get glassKnobHintRimOpacity =>
      'accentkonturen. noll för en kantlös yta';

  @override
  String get glassKnobLabelRimWidth => 'KANTBREDD';

  @override
  String get glassKnobHintRimWidth => 'tjockleken på den konturen';

  @override
  String get glassKnobLabelShadowOpacity => 'SKUGGA';

  @override
  String get glassKnobHintShadowOpacity =>
      'hur högt ytan svävar över det som ligger bakom';

  @override
  String get glassKnobLabelShadowBlur => 'SKUGGSPRIDNING';

  @override
  String get glassKnobHintShadowBlur => 'mjuk och bred, eller tät och hård';

  @override
  String get glassKnobLabelShadowY => 'SKUGGFALL';

  @override
  String get glassKnobHintShadowY => 'hur långt under ytan den faller';

  @override
  String get glassKnobLabelBarMargin => 'SIDOMARGINAL';

  @override
  String get glassKnobHintBarMargin =>
      'avståndet mellan fältet och skärmens kant';

  @override
  String get glassKnobLabelBarBottom => 'BOTTENAVSTÅND';

  @override
  String get glassKnobHintBarBottom => 'hur högt fältet svävar över botten';

  @override
  String get glassKnobLabelShellPadH => 'ÄNDPADDING';

  @override
  String get glassKnobHintShellPadH =>
      'från fältets kant till den första kapseln. håll den liten, annars ser ändarna övergivna ut';

  @override
  String get glassKnobLabelShellPadV => 'TOPPADDING';

  @override
  String get glassKnobHintShellPadV =>
      'från fältets kant till toppen av kapseln';

  @override
  String get glassKnobLabelIndicatorInset => 'KAPSELINDRAG';

  @override
  String get glassKnobHintIndicatorInset =>
      'hur långt in urvalskapseln sitter i sitt fack';

  @override
  String get glassKnobLabelSegmentPadV => 'RADPADDING';

  @override
  String get glassKnobHintSegmentPadV =>
      'luft ovanför och under ikonen och dess etikett';

  @override
  String get glassKnobLabelIconLabelGap => 'IKONAVSTÅND';

  @override
  String get glassKnobHintIconLabelGap =>
      'avståndet mellan en ikon och ordet under den';

  @override
  String get glassKnobLabelIconSize => 'IKONSTORLEK';

  @override
  String get glassKnobLabelLabelSize => 'ETIKETTSTORLEK';

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
