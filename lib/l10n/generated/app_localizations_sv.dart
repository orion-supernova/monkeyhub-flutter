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
  String get roomScreenUnreadDivider => 'OLÄSTA MEDDELANDEN';

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
  String get profileScreenNameNotSaved =>
      'Ditt namn kunde inte sparas. Försök igen.';

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
  String get settingsScreenSectionHelpAndLegal => 'HJÄLP OCH JURIDIK';

  @override
  String get settingsScreenLicence => 'LICENS';

  @override
  String get profileScreenLinkedAccountsLabel => 'LÄNKADE KONTON';

  @override
  String get profileScreenLinkedAccountsNone => 'inget länkat';

  @override
  String get profileScreenMyGrownUps => 'MINA VUXNA';

  @override
  String get profileScreenNameHint => 'så här syns du i rummet';

  @override
  String get profileScreenChangeUsernameTitle => 'byta användarnamn?';

  @override
  String get profileScreenChangeUsernameWarning =>
      'Du loggar in med det här, så du skriver det nya från och med nu. Ditt gamla användarnamn frigörs så att någon annan kan ta det, och du kan inte byta igen på 30 dagar. Äldre meddelanden som taggade dig behåller det gamla namnet.';

  @override
  String get profileScreenUsernameHint => 'så hittar dina vänner dig';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return 'kan bytas igen den $date';
  }

  @override
  String get profileScreenUsernamePasswordTitle => 'bekräfta att det är du';

  @override
  String get profileScreenUsernamePasswordAction => 'BYT ANVÄNDARNAMN';

  @override
  String get profileScreenUsernameProviderTitle =>
      'bekräfta med din inloggning';

  @override
  String profileScreenUsernameChanged(String username) {
    return 'Du är nu @$username.';
  }

  @override
  String get profileScreenUsernameNotSaved =>
      'Kunde inte byta ditt användarnamn. Försök igen.';

  @override
  String get usernameStatusChecking => 'kontrollerar…';

  @override
  String get usernameStatusAvailable => 'ledigt';

  @override
  String get usernameStatusTaken => 'redan taget';

  @override
  String get usernameStatusReserved => 'inte tillgängligt';

  @override
  String get usernameStatusInvalid => '1–32 tecken';

  @override
  String get usernameStatusUnknown => 'kunde inte kontrollera';

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
  String get settingsScreenPrivacyPolicy => 'INTEGRITETSPOLICY';

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
  String get settingsScreenTermsOfService => 'ANVÄNDARVILLKOR';

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
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: på';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: av';

  @override
  String get cameraEditorScreenHdNote => 'skickas i full upplösning';

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
  String get threadOverlayCoordinatesCopiedToast => 'koordinaterna kopierade';

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
  String get roomInfoScreenEndConversationConfirmTitle =>
      'avsluta den här konversationen?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName förlorar också konversationen — alla meddelanden försvinner för er båda. det här är permanent.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'AVSLUTA';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'den andra personen';

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
  String get roomInfoScreenEndingConversationButton => 'AVSLUTAR…';

  @override
  String get roomInfoScreenEndConversationButton => 'AVSLUTA KONVERSATIONEN';

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
  String get roomInfoScreenOwnerBadge => 'ÄGARE';

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
  String get roomContentScreenEmptySaved =>
      'inget sparat än. håll in ett meddelande och välj SPARA.\n\ndet du sparar här är bara ditt — ett fäst meddelande är det hela rummet ser.';

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
  String get messageActionMenuEditLabel => 'REDIGERA';

  @override
  String get messageStampEditedLabel => 'redigerat';

  @override
  String get composerEditCardTitle => 'REDIGERA MEDDELANDE';

  @override
  String get spoilerRevealHint =>
      'Spoiler — aktivera för att visa den dolda texten';

  @override
  String get formatToolbarFormatLabel => 'Formatera';

  @override
  String get formatToolbarBoldLabel => 'Fet';

  @override
  String get formatToolbarItalicLabel => 'Kursiv';

  @override
  String get formatToolbarStrikethroughLabel => 'Genomstruken';

  @override
  String get formatToolbarUnderlineLabel => 'Understruken';

  @override
  String get formatToolbarSpoilerLabel => 'Spoiler';

  @override
  String get formatToolbarLinkLabel => 'Länk';

  @override
  String get formatToolbarCodeLabel => 'Kod';

  @override
  String get linkInputSheetTitle => 'LÄNK';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => 'ANVÄND LÄNK';

  @override
  String get linkInputSheetApplySub =>
      'Den markerade texten öppnar den här adressen när du trycker på den';

  @override
  String get linkInputSheetRemoveLabel => 'TA BORT LÄNK';

  @override
  String get linkConfirmSheetTitle => 'ÖPPNA DEN HÄR LÄNKEN?';

  @override
  String get linkConfirmSheetOpenLabel => 'ÖPPNA LÄNK';

  @override
  String get linkConfirmSheetCancelLabel => 'AVBRYT';

  @override
  String get roomScreenEditExpiredSnack =>
      'För sent att redigera — meddelanden kan bara redigeras i 15 minuter.';

  @override
  String get roomScreenEditFailedSnack =>
      'Ändringen kunde inte sparas. Kontrollera din anslutning och försök igen.';

  @override
  String get messageActionMenuForwardLabel => 'VIDAREBEFORDRA';

  @override
  String get messageActionMenuViewThreadLabel => 'VISA TRÅD';

  @override
  String get messageActionMenuCopyLabel => 'KOPIERA';

  @override
  String get messageActionMenuCopyNameLabel => 'KOPIERA NAMN';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'KOPIERA KOORDINATER';

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
  String get discoverScreenYourRoomsLabel => 'DINA RUM';

  @override
  String get discoverScreenNoRoomsYet => 'inga rum än';

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
  String get loginScreenSignInFirstHeroMuted => 'hej\n';

  @override
  String get loginScreenSignInFirstHeroInk => 'på dig.';

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
  String get recoveryPhraseScreenConfirmHeroInk => 'att det är du.';

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
  String get roomLayoutScreenQuietRoomSectionLabel => 'TYSTA RUM';

  @override
  String get roomLayoutScreenPlainCornerLabel => 'tomt hörn';

  @override
  String get roomLayoutScreenPlainCornerDescription =>
      'ett rum utan meddelanden lämnas bart';

  @override
  String get roomLayoutScreenMonogramLabel => 'rummets initial';

  @override
  String get roomLayoutScreenMonogramDescription =>
      'en stor blek bokstav fyller hörnet';

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
  String fileMessageViewSemanticLabel(Object name) {
    return 'Visa $name';
  }

  @override
  String get textFileViewerDownloadTooltip => 'Ladda ner';

  @override
  String get textFileViewerTruncatedNotice =>
      'Visar en del av filen — ladda ner för att se resten.';

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
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return 'Objekt $current av $total';
  }

  @override
  String photoTrayCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foton',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => 'kasta dessa foton';

  @override
  String get photoTrayRemoveSemanticLabel => 'ta bort det här fotot';

  @override
  String get photoTrayEditSemanticLabel => 'beskär eller rita på det här fotot';

  @override
  String get photoTrayAddMoreSemanticLabel => 'lägg till fler foton';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'du kan skicka $count foton åt gången';
  }

  @override
  String get photoTrayLoadFailedSnack =>
      'några av de fotona gick inte att öppna';

  @override
  String get mediaPickFailedMessage => 'kunde inte öppna — försök välja igen';

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
  String get messageStampSentLabel => 'skickat';

  @override
  String get messageStampDeliveredLabel => 'levererat';

  @override
  String get messageStampSeenLabel => 'läst';

  @override
  String get messageStampSavedLabel => 'sparad';

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
  String get socialButtonDividerOr => 'eller';

  @override
  String get socialButtonGoogleContinue => 'Fortsätt med Google';

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
  String get discoverListsRoomsTitle => 'dina rum.';

  @override
  String discoverListsRoomsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rum',
      one: '$count rum',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterRoomsHint => 'filtrera dina rum…';

  @override
  String get discoverListsNoRoomsYet => 'inga rum än';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return 'inga rum matchar \"$query\"';
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
  String roomCardStartedAgo(Object ago) {
    return 'skapat för $ago sedan';
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
  String get reactionBubbleSearchHint => 'sök emoji';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'inga träffar';

  @override
  String get reactionBubbleSearchBackSemanticLabel => 'Tillbaka till emoji';

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
  String get feedBoardTitle => 'IDAG';

  @override
  String feedBoardEditionLabel(Object number) {
    return 'Nr$number';
  }

  @override
  String get feedBoardHighlightsLabel => 'HÖJDPUNKTER';

  @override
  String get feedBoardHighlightsEmpty => 'inget fångat idag än';

  @override
  String get feedBoardPuzzleLabel => 'PUSSLET';

  @override
  String get feedBoardPuzzleEmpty => 'dagens pussel är inte klart än';

  @override
  String get feedBoardStandingsLabel => 'LIVSPOÄNG';

  @override
  String get feedBoardStandingsEmpty => 'inga poäng på tavlan idag';

  @override
  String get feedBoardActivityLabel => 'AKTIVITET';

  @override
  String get feedBoardActivityEmpty => 'lugnt hittills idag';

  @override
  String get feedBoardActivityNoFriends =>
      'lägg till en vän så dyker deras dag upp här';

  @override
  String get feedBoardLoadFailed =>
      'kunde inte ladda tavlan — försök igen om en stund';

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
  String get roomBadgePublicTooltip =>
      'Vem som helst kan hitta det här rummet och gå med';

  @override
  String get roomBadgePrivateTooltip =>
      'Endast via inbjudan – syns inte i Upptäck';

  @override
  String get roomBadgeLockedTooltip =>
      'Du behöver rummets lösenord för att gå med';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return 'Meddelanden försvinner efter $duration';
  }

  @override
  String get roomBadgeJoinedTooltip => 'Du är redan med i det här rummet';

  @override
  String get roomInfoSheetDetailsLabel => 'DETALJERNA';

  @override
  String get roomInfoSheetNoDescription => 'ingen beskrivning än';

  @override
  String get roomInfoSheetCreatedLabel => 'SKAPAD';

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
  String get roomContentTabLabelSaved => 'SPARADE';

  @override
  String get roomContentTabHeaderMedia => 'media';

  @override
  String get roomContentTabHeaderFiles => 'filer';

  @override
  String get roomContentTabHeaderVoice => 'röst';

  @override
  String get roomContentTabHeaderLinks => 'länkar';

  @override
  String get roomContentTabHeaderSaved => 'sparade';

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
  String get settingsScreenSectionChat => 'CHATT';

  @override
  String get settingsScreenSectionGeneral => 'ALLMÄNT';

  @override
  String get settingsScreenCheckForUpdatesLabel => 'SÖK EFTER UPPDATERINGAR';

  @override
  String get settingsScreenUpdateAvailableValue => 'UPPDATERING TILLGÄNGLIG';

  @override
  String get settingsScreenUpdateUpToDateSnackbar =>
      'Du har den senaste versionen.';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      'Det går inte att söka efter uppdateringar i den här versionen.';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      'Det gick inte att söka efter uppdateringar. Försök igen senare.';

  @override
  String get settingsScreenSectionNotifications => 'NOTISER';

  @override
  String get reportProblemRowLabel => 'Rapportera ett problem';

  @override
  String get reportProblemRowValue => 'Skicka oss detaljerna';

  @override
  String get reportProblemIntro =>
      'Berätta vad som gick fel. Uppgifter om appen och din enhet skickas med automatiskt, tillsammans med en teknisk logg över vad appen gjorde — det är det som hjälper oss att hitta orsaken.';

  @override
  String get reportProblemDescribeLabel => 'VAD HÄNDE';

  @override
  String get reportProblemDescribeHint =>
      'Skärmen flimrar, knappar svarar inte…';

  @override
  String get reportProblemScreenshotsLabel => 'SKÄRMBILDER';

  @override
  String get reportProblemAddScreenshot => 'Lägg till skärmbild';

  @override
  String get reportProblemDetailsLabel => 'DINA UPPGIFTER';

  @override
  String get reportProblemCopyDetails => 'Kopiera uppgifter';

  @override
  String get reportProblemCopied => 'Kopierat';

  @override
  String get reportProblemSend => 'Skicka rapport';

  @override
  String get reportProblemSent => 'Rapporten är skickad — tack!';

  @override
  String get reportProblemSendFailed =>
      'Rapporten kunde inte skickas. Kontrollera din anslutning och försök igen.';

  @override
  String get reportProblemTooMany =>
      'Du har skickat många rapporter på kort tid. Försök igen lite senare.';

  @override
  String get reportProblemShakeTitle => 'Rapportera ett problem?';

  @override
  String get reportProblemShakeBody =>
      'Du skakade telefonen. Vill du öppna rapportskärmen?';

  @override
  String get reportProblemShakeOpen => 'Rapportera';

  @override
  String get reportProblemShakeDismiss => 'Inte nu';

  @override
  String get settingsCallDeliveryLockScreenLabel => 'Samtal på låsskärmen';

  @override
  String get settingsCallDeliveryBackgroundLabel => 'Bakgrundsaktivitet';

  @override
  String get settingsCallDeliveryStatusOff => 'Tryck för att tillåta';

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
  String get settingsScreenSectionCalls => 'SAMTAL';

  @override
  String get settingsScreenRowVideoQuality => 'Videokvalitet';

  @override
  String get settingsScreenValueVideoQualityAuto => 'Auto';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel => 'VISA SAMTALSSTATISTIK';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      'upplösning, bithastighet, ping och paketförlust i realtid under samtal';

  @override
  String get videoQualityScreenTitle => 'Videokvalitet';

  @override
  String get videoQualityScreenSubtitle =>
      'Välj ett upplösningstak för utgående video';

  @override
  String get videoQualityScreenAutoSubtitle =>
      'Anpassar sig automatiskt efter din anslutning';

  @override
  String get videoQualityScreenHd1080Subtitle =>
      'Full HD — skarpare, använder mer data';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD — bäst med en stark anslutning';

  @override
  String get videoQualityScreenFootnote =>
      'Den faktiska upplösningen beror på båda enheternas kameror och nätverksförhållanden.';

  @override
  String get callScreenControlOptions => 'Mer';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => 'Jitter';

  @override
  String get callScreenStatsLossLabel => 'Förlust';

  @override
  String get callScreenSwapPreviewSemanticLabel => 'Växla kameravy';

  @override
  String get callOptionsSheetTitle => 'Samtalsalternativ';

  @override
  String get settingsScreenPushNotificationsLabel => 'PUSHNOTISER';

  @override
  String get settingsScreenPushOnBody =>
      'pingar vid nya meddelanden och förfrågningar';

  @override
  String get settingsScreenPushOffBody =>
      'tyst — du ser bara saker när du öppnar appen';

  @override
  String get settingsScreenGameRemindersLabel => 'DAGLIG SPELPÅMINNELSE';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'en påminnelse vid lunch, bara om du inte spelat';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'ingen påminnelse — spelen finns kvar när du tittar';

  @override
  String get authErrorUsernameTaken => 'Det användarnamnet är redan taget.';

  @override
  String get authErrorUsernameReserved =>
      'Det användarnamnet är inte tillgängligt. Välj ett annat.';

  @override
  String get authErrorDisplayNameReserved =>
      'Det namnet är inte tillgängligt. Välj ett annat.';

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
  String get authErrorUsernameChangedRecently =>
      'Du har bytt användarnamn nyligen. Du kan byta igen 30 dagar efter det senaste bytet.';

  @override
  String get authErrorInboxHandleLocked =>
      'Det här kontot tar emot allas problemrapporter, så dess användarnamn är låst.';

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

  @override
  String get settingsScreenRowMotion => 'RÖRELSE';

  @override
  String get settingsScreenValueMotionFull => 'Full';

  @override
  String get settingsScreenValueMotionCalm => 'Lugn';

  @override
  String get settingsScreenValueMotionSystemFull => 'Följ enheten · full';

  @override
  String get settingsScreenValueMotionSystemCalm => 'Följ enheten · lugn';

  @override
  String get motionScreenTitle => 'rörelse.';

  @override
  String get motionScreenSubtitle => 'hur mycket appen rör sig';

  @override
  String get motionScreenSystemLabel => 'FÖLJ ENHETEN';

  @override
  String get motionScreenSystemSubtitleFull =>
      'din enhet tillåter animation just nu';

  @override
  String get motionScreenSystemSubtitleCalm =>
      'din enhet ber om mindre rörelse just nu';

  @override
  String get motionScreenFullLabel => 'FULL';

  @override
  String get motionScreenFullSubtitle => 'varje drift, glöd och krusidull';

  @override
  String get motionScreenCalmLabel => 'LUGN';

  @override
  String get motionScreenCalmSubtitle =>
      'dekoren står stilla — inget annat ändras';

  @override
  String get momentRailCaptureLabel => 'FÅNGA';

  @override
  String get momentRailYouLabel => 'du';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String get momentTagFate => 'ÖDE';

  @override
  String get momentTagJinx => 'OTUR';

  @override
  String get momentTagLuck => 'TUR';

  @override
  String get momentTagCalledIt => 'VAD VAR DET JAG SA';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'vilket sammanträffande';

  @override
  String get momentTagJinxHint => 'det där gjorde du mot dig själv';

  @override
  String get momentTagLuckHint => 'det gick din väg';

  @override
  String get momentTagCalledItHint => 'du såg det komma';

  @override
  String get momentTagNpcHint => 'hjärnan helt avstängd';

  @override
  String get momentComposerTitle => 'vad hände?';

  @override
  String get momentComposerCaptionHint => 'säg något om det';

  @override
  String get momentComposerTagPrompt => 'vunnit en poäng? lägg till den';

  @override
  String get momentComposerCapture => 'kamera';

  @override
  String get momentComposerLibrary => 'galleri';

  @override
  String get momentComposerRemovePhoto => 'ta bort foto';

  @override
  String get momentComposerPost => 'PUBLICERA';

  @override
  String get momentComposerErrorDailyCap =>
      'det blev fem idag — spara något till imorgon';

  @override
  String get momentComposerErrorNotAllowed =>
      'en vårdnadshavare har stängt av fotodelning';

  @override
  String get momentComposerErrorTooLong => 'lite väl långt — korta ner';

  @override
  String get momentComposerErrorEmpty => 'lägg till ett foto eller några ord';

  @override
  String get momentComposerErrorGeneric => 'kunde inte publicera — försök igen';

  @override
  String get momentViewerDelete => 'radera';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who lade upp ett ögonblick';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name tog en $tag';
  }

  @override
  String get momentActivityJustNow => 'nyss';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '${count}m';
  }

  @override
  String momentActivityHoursAgo(Object count) {
    return '${count}h';
  }

  @override
  String momentActivityMoreCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count till idag',
      one: '1 till idag',
    );
    return '$_temp0';
  }

  @override
  String get puzzleScreenTitle => 'pusslet.';

  @override
  String get puzzleScreenSubtitle => 'fyra symboler, sex försök';

  @override
  String get puzzleSubmit => 'GISSA';

  @override
  String get puzzleBackspace => 'radera sista symbolen';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'symbol $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'löst på $count';
  }

  @override
  String get puzzleFailedTitle => 'slut på försök';

  @override
  String get puzzleAnswerWas => 'KODEN VAR';

  @override
  String get puzzleShare => 'KOPIERA RESULTAT';

  @override
  String get puzzleShareCopied => 'kopierat — klistra in till en vän';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'du har redan löst dagens';

  @override
  String get puzzleErrorOutOfGuesses => 'inga försök kvar idag';

  @override
  String get puzzleErrorGeneric => 'kunde inte skicka — försök igen';

  @override
  String get puzzleScoreboardLabel => 'DAGENS RESULTAT';

  @override
  String get puzzleScoreboardEmpty => 'ingen har blivit klar idag än';

  @override
  String get puzzleTilePlay => 'spela dagens pussel';

  @override
  String puzzleTileInProgress(Object count) {
    return '$count kvar';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '#$rank av $total';
  }

  @override
  String get profileVisibilityScreenSectionFeed => 'FLÖDE';

  @override
  String get profileVisibilityScreenFeedLabel => 'mina höjdpunkter';

  @override
  String get profileVisibilityScreenFeedDesc =>
      'om foton och videor du lägger upp syns på vännernas tavlor den dagen';

  @override
  String get profileVisibilityScreenPuzzleLabel => 'mitt pusselresultat';

  @override
  String get profileVisibilityScreenPuzzleDesc =>
      'om vänner ser hur det gick för dig i dagens pussel';

  @override
  String get profileVisibilityScreenPointsPastLabel => 'mitt förflutna';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      'idag delas alltid med vänner — det här öppnar allt dessförinnan';

  @override
  String get momentComposerVideo => 'video';

  @override
  String get momentComposerErrorTooBig => 'videon är för stor — max 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => 'du lade upp ett ögonblick';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'du tog en $tag';
  }

  @override
  String pointLineSelf(Object tag) {
    return 'du · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'vad hände?';

  @override
  String get pointComposerNoteHint => 'välj en ovan och berätta';

  @override
  String get pointComposerAdd => 'LÄGG TILL POÄNG';

  @override
  String get pointComposerAddPhoto => 'lägg till foto';

  @override
  String get pointsBoardAdd => 'LÄGG TILL EN POÄNG';

  @override
  String get pointsExplainerOpen => 'vad är det här?';

  @override
  String get pointsExplainerTitle => 'poängleken';

  @override
  String get pointsExplainerIntro =>
      'Ett återkommande skämt som ni för protokoll över. När något händer dig — bra, dåligt eller bara märkligt — noterar du det och det ligger på tavlan den dagen.';

  @override
  String get pointsExplainerRuleHonour =>
      'Du delar ut dina egna poäng. Ingen kontrollerar — det är själva poängen, och dina vänner säger till om du tänjer på det.';

  @override
  String get pointsExplainerRuleToday =>
      'Poängen nollställs varje dag. Tavlan visar idag; din egen historik behåller du.';

  @override
  String get pointsExplainerRuleCap =>
      'Fem av varje sort per dag, så att ingen kan mala sönder tavlan.';

  @override
  String get pointsExplainerGotIt => 'JAG FATTAR';

  @override
  String get momentTagFateExample =>
      'sprang på min tandläkare i ett annat land';

  @override
  String get momentTagJinxExample => 'tvättade bilen, det regnade vid fyra';

  @override
  String get momentTagLuckExample => 'hann tåget med två sekunder till godo';

  @override
  String get momentTagCalledItExample =>
      'sa att uppföljaren skulle floppa, den floppade';

  @override
  String get momentTagNpcExample => 'sa ‘detsamma’ till servitören';

  @override
  String feedBoardEditionHint(Object number) {
    return 'dag $number av flödet';
  }

  @override
  String get feedBoardHighlightsHint => 'foton och videor värda en titt';

  @override
  String get profileVisibilityScreenPointsLabel => 'mina poäng';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'om poängen du noterar syns på vännernas tavlor';

  @override
  String get momentComposerEditPhoto => 'redigera beskärning';

  @override
  String get archiveScreenTitle => 'ditt arkiv';

  @override
  String get archiveScreenEnd => 'det var allt';

  @override
  String get archiveScreenEmptyTitle => 'inget sparat än';

  @override
  String get archiveScreenEmptyBody =>
      'ögonblick lämnar vännernas tavlor efter ett dygn, men de stannar här för dig.';

  @override
  String get archiveScreenEmptyFriendTitle => 'inget här';

  @override
  String get archiveScreenEmptyFriendBody =>
      'har inte lagt upp något du kan se än.';

  @override
  String get archiveScreenPrivateTitle => 'deras förflutna är privat';

  @override
  String get archiveScreenPrivateBody =>
      'du ser fortfarande det som läggs upp idag.';

  @override
  String get archiveScreenNotFriendTitle => 'ni är inte vänner';

  @override
  String get archiveScreenNotFriendBody =>
      'du kan bara bläddra bakåt bland en väns dagar.';

  @override
  String get archiveScreenErrorTitle => 'kunde inte laddas';

  @override
  String get archiveScreenErrorBody => 'kolla anslutningen och försök igen.';

  @override
  String get feedBoardOpenArchive => 'arkiv';

  @override
  String get feedBoardGamesLabel => 'SPELEN';

  @override
  String get feedBoardGamesOpen => 'alla spel';

  @override
  String get gamesScreenTitle => 'spelen.';

  @override
  String get gamesScreenSubtitle => 'fyra brickor om dagen, samma för alla';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kvar idag',
      one: 'en kvar idag',
      zero: 'allt klart idag',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => 'kunde inte ladda dagens spel';

  @override
  String get gamesRetry => 'FÖRSÖK IGEN';

  @override
  String get gameQueensName => 'damer';

  @override
  String get gameQueensRule =>
      'en krona per rad, kolumn och färg — aldrig intill varandra';

  @override
  String get gameTangoName => 'tango';

  @override
  String get gameTangoRule => 'tre solar, tre månar, aldrig tre i rad';

  @override
  String get gameZipName => 'zip';

  @override
  String get gameZipRule => 'en linje genom varje ruta, siffrorna i ordning';

  @override
  String get gameSudokuName => 'minisudoku';

  @override
  String get gameSudokuRule => '1 till 6 en gång per rad, kolumn och ruta';

  @override
  String get gameCodeName => 'koden';

  @override
  String get gameStatusUnplayed => 'ospelad';

  @override
  String get gameStatusUnfinished => 'pågår';

  @override
  String get gameStatusGaveUp => 'gav upp';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'pausa';

  @override
  String get gameResume => 'fortsätt';

  @override
  String get gamePausedTitle => 'pausat';

  @override
  String get gamePausedBody => 'klockan är stoppad och brickan dold';

  @override
  String get gameUndo => 'ångra';

  @override
  String get gameClear => 'rensa';

  @override
  String get gameHint => 'ledtråd';

  @override
  String get gameNotes => 'anteckningar';

  @override
  String get gameErase => 'sudda';

  @override
  String get gameAutoCross => 'autokryss';

  @override
  String get gameGiveUp => 'ge upp';

  @override
  String get gameGiveUpTitle => 'visa lösningen?';

  @override
  String get gameGiveUpBody => 'dagens bricka stängs och räknas som olöst.';

  @override
  String get gameGiveUpCancel => 'FORTSÄTT';

  @override
  String get gameGiveUpConfirm => 'VISA';

  @override
  String gameSolvedTitle(Object time) {
    return 'löst på $time';
  }

  @override
  String get gameGaveUpTitle => 'dagens lösning';

  @override
  String get gameFirstInToday => 'först idag';

  @override
  String gameRankLine(Object place, Object total) {
    return '$place av $total hittills';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missar',
      one: '1 miss',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ledtrådar',
      one: '1 ledtråd',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => 'DAGENS TIDER';

  @override
  String get gameStandingsEmpty => 'ingen har klarat den än';

  @override
  String get gameShare => 'KOPIERA RESULTAT';

  @override
  String get gameShareCopied => 'kopierat — klistra in till en vän';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => 'alla spel';

  @override
  String get gameElapsedSemantic => 'förfluten tid';

  @override
  String get gameErrorNotSolved => 'brickan är inte klar än';

  @override
  String get gameErrorAlreadyFinished => 'du har redan klarat dagens';

  @override
  String get gameErrorNoHint => 'ingen ledtråd för den här';

  @override
  String get gameErrorGeneric => 'kunde inte nå spelen — försök igen';

  @override
  String get gameInfoOpen => 'så spelar du';

  @override
  String get gameInfoLabel => 'SÅ SPELAR DU';

  @override
  String get gameInfoRulesLabel => 'REGLERNA';

  @override
  String get gameInfoControlsLabel => 'KONTROLLER';

  @override
  String get gameInfoScoringTimed =>
      'klockan går så länge brickan är uppe och stannar när du pausar eller lämnar. snabbast toppar dagens lista.';

  @override
  String get gameInfoScoringGuesses =>
      'poängen sätts av hur få gissningar du behöver, inte av klockan.';

  @override
  String get gameInfoSameForEveryone => 'alla får samma bricka idag.';

  @override
  String get gameInfoGotIt => 'OKEJ';

  @override
  String get gameInfoQueensGoal =>
      'placera en krona i varje rad, kolumn och färg.';

  @override
  String get gameInfoQueensRule1 =>
      'åtta kronor: en i varje rad och en i varje kolumn.';

  @override
  String get gameInfoQueensRule2 => 'varje färgblock får också exakt en krona.';

  @override
  String get gameInfoQueensRule3 =>
      'två kronor får inte nudda varandra, inte ens i ett hörn.';

  @override
  String get gameInfoQueensControls =>
      'tryck på en ruta en gång för ett kryss som stryker den, igen för en krona, igen för att tömma.';

  @override
  String get gameInfoTangoGoal => 'fyll rutnätet med solar och månar.';

  @override
  String get gameInfoTangoRule1 =>
      'varje rad och kolumn har tre solar och tre månar.';

  @override
  String get gameInfoTangoRule2 =>
      'aldrig tre likadana i rad, varken vågrätt eller lodrätt.';

  @override
  String get gameInfoTangoRule3 =>
      'ett = mellan två rutor betyder lika, ett × betyder olika.';

  @override
  String get gameInfoTangoControls =>
      'tryck på en ruta för en sol, igen för en måne, igen för att tömma. förtryckta rutor går inte att ändra.';

  @override
  String get gameInfoZipGoal => 'rita en linje som går genom varje ruta.';

  @override
  String get gameInfoZipRule1 => 'börja på 1 och sluta på det sista talet.';

  @override
  String get gameInfoZipRule2 => 'ta siffrorna i ordning på vägen.';

  @override
  String get gameInfoZipRule3 => 'varje ruta används exakt en gång.';

  @override
  String get gameInfoZipControls =>
      'dra fingret för att rita. dra tillbaka längs linjen för att sudda.';

  @override
  String get gameInfoSudokuGoal => 'fyll rutnätet med siffrorna 1 till 6.';

  @override
  String get gameInfoSudokuRule1 => 'varje rad använder 1 till 6, en gång var.';

  @override
  String get gameInfoSudokuRule2 => 'samma sak för varje kolumn.';

  @override
  String get gameInfoSudokuRule3 => 'och varje 2x3-ruta också.';

  @override
  String get gameInfoSudokuControls =>
      'tryck på en ruta och sedan på en siffra. tryck på samma siffra igen för att sudda. anteckningsläget skriver små blyertsmarkeringar i stället.';

  @override
  String get gameInfoCodeGoal => 'lista ut den dolda koden på fyra symboler.';

  @override
  String get gameInfoCodeRule1 =>
      'sex försök, och koden upprepar aldrig en symbol.';

  @override
  String get gameInfoCodeRule2 => 'grönt betyder rätt symbol på rätt plats.';

  @override
  String get gameInfoCodeRule3 => 'gult betyder rätt symbol på fel plats.';

  @override
  String get gameInfoCodeControls =>
      'tryck på symboler för att bygga en gissning och skicka den. brickan visar hur nära du var.';

  @override
  String get savedMessagesTitle => 'Sparade meddelanden';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'ingen chatt matchar \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'sök chattar…';

  @override
  String get pullRevealCollapseSemanticLabel =>
      'Dölj sök och arkiverade chattar';

  @override
  String archivedChatsFolderLabel(Object count) {
    return 'arkiverade chattar ($count)';
  }

  @override
  String get archivedChatsFolderTitle => 'arkiverade chattar';

  @override
  String get pullRevealClearSearchSemanticLabel => 'Rensa sökning';

  @override
  String get archivedChatsSheetTitle => 'ARKIVERADE CHATTAR';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'ARKIVERADE CHATTAR · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'inget är arkiverat längre';

  @override
  String get pinnedBadgeLabel => 'FÄST';

  @override
  String get chatRowActionMenuPinLabel => 'FÄST CHATTEN';

  @override
  String get chatRowActionMenuUnpinLabel => 'LOSSA CHATTEN';

  @override
  String get chatRowActionMenuArchiveLabel => 'ARKIVERA CHATTEN';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'AVARKIVERA CHATTEN';

  @override
  String get messageActionMenuSaveLabel => 'SPARA';

  @override
  String get messageActionMenuUnsaveLabel => 'TA BORT';

  @override
  String get roomScreenSaveLimitSnack =>
      'för många sparade här — ta bort en först';

  @override
  String get roomScreenSaveFailedSnack => 'kunde inte spara det';

  @override
  String get threadOverlaySaveLimitToast =>
      'för många sparade här — ta bort en först';

  @override
  String get threadOverlaySaveFailedToast => 'kunde inte spara det';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'bara du ser meddelandena du sparar — ett fäst meddelande är tvärtom: hela rummet ser det.';

  @override
  String get roomInfoScreenOwnerBadgeNote =>
      'den lilla medaljen bredvid ett namn visar vem som skapade det här rummet.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return 'Hoppa till sparat meddelande från $name';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return 'Ta bort sparat meddelande från $name';
  }

  @override
  String get muteSheetTitle => 'TYSTA CHATTEN';

  @override
  String get muteSheetSubtitle => 'Välj vad som ska tystna, och hur länge.';

  @override
  String get muteSheetNotificationsTitle => 'Aviseringar';

  @override
  String get muteSheetNotificationsSub => 'Ingen avisering, inget ljud';

  @override
  String get muteSheetBadgesTitle => 'Antal olästa';

  @override
  String get muteSheetBadgesSub =>
      'Ingen siffra på chatten, inget som läggs till appikonen';

  @override
  String get muteSheetDurationLabel => 'HUR LÄNGE';

  @override
  String get muteDurationHour => '1 timme';

  @override
  String get muteDurationEightHours => '8 timmar';

  @override
  String get muteDurationWeek => '1 vecka';

  @override
  String get muteDurationAlways => 'Alltid';

  @override
  String get muteSheetConfirmButton => 'TYSTA';

  @override
  String get muteSheetSaveButton => 'SPARA';

  @override
  String get muteSheetUnmuteButton => 'SLÅ PÅ LJUD';

  @override
  String get muteSummaryAll =>
      'Ingenting från den här chatten når dig – varken aviseringar eller antal olästa.';

  @override
  String get muteSummaryNotificationsOnly =>
      'Inga aviseringar. Antalet olästa fortsätter att öka.';

  @override
  String get muteSummaryBadgesOnly =>
      'Inget antal olästa. Aviseringar kommer fortfarande fram.';

  @override
  String get muteSummaryNothingPicked => 'Välj minst en sak att tysta.';

  @override
  String muteUntilSentence(String when) {
    return 'Till $when.';
  }

  @override
  String get muteUntilAlwaysSentence => 'Tills du slår på det igen.';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String get mutedBadgeLabel => 'TYSTAD';

  @override
  String get chatRowActionMenuMuteLabel => 'TYSTA CHATTEN';

  @override
  String get chatRowActionMenuUnmuteLabel => 'SLÅ PÅ LJUD FÖR CHATTEN';

  @override
  String get roomInfoScreenMuteLabel => 'TYSTA';

  @override
  String get roomInfoScreenNotMutedRow => 'Inte tystad';

  @override
  String get attachmentMenuLocationLabel => 'plats';

  @override
  String get locationSheetSendCurrent => 'Skicka nuvarande plats';

  @override
  String get locationSheetSendCurrentDetail => 'Där du är just nu';

  @override
  String get locationSheetLiveHeading => 'DELA LIVE';

  @override
  String get locationSheetLiveDetail => 'Stoppas av sig själv';

  @override
  String get locationShareFor15Minutes => 'I 15 minuter';

  @override
  String get locationShareFor1Hour => 'I 1 timme';

  @override
  String get locationShareFor8Hours => 'I 8 timmar';

  @override
  String get locationBubbleOpenInMaps => 'Öppna i kartor';

  @override
  String get locationBubbleLiveBadge => 'LIVE';

  @override
  String get locationBubbleEndedBadge => 'AVSLUTAD';

  @override
  String locationBubbleLiveUntil(String time) {
    return 'Live till $time';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return 'Live-platsen avslutades $time';
  }

  @override
  String get locationBubbleNoRecentUpdate => 'Ingen ny uppdatering';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters m';
  }

  @override
  String get locationBubbleStopSharing => 'Sluta dela';

  @override
  String get locationBubbleUnavailable => 'Platsen är inte tillgänglig';

  @override
  String get locationBubbleNoMapsApp => 'Ingen kartapp att öppna det här i';

  @override
  String get locationBubbleCoordinatesCopied => 'Koordinaterna kopierade';

  @override
  String get locationCouldNotGetFix => 'Kunde inte hämta din plats';

  @override
  String get locationCouldNotStartLiveShare => 'Kunde inte starta livedelning';

  @override
  String get locationPermissionNeeded =>
      'Platsåtkomst krävs för att dela var du är';

  @override
  String get locationPermissionBlockedTitle => 'Platsåtkomst är avstängd';

  @override
  String get locationPermissionBlockedBody =>
      'MonkeyHub kan inte fråga igen härifrån. Slå på platsåtkomst för MonkeyHub i Inställningar.';

  @override
  String get locationServicesOffTitle => 'Platstjänster är avstängda';

  @override
  String get locationServicesOffBody =>
      'Plats är avstängt på den här enheten. Slå på det i Inställningar för att dela var du är.';

  @override
  String get locationOpenSettings => 'Öppna inställningar';

  @override
  String get locationBackgroundSheetTitle => 'Om telefonen startas om';

  @override
  String get locationBackgroundSheetBody =>
      'Din direktdelning fortsätter redan när du lämnar MonkeyHub. Bakgrundsåtkomst täcker resten: en omstart, en tvångsavslutning, en telefon som får slut på batteri och kommer tillbaka.';

  @override
  String get locationBackgroundSheetKeepRunning => 'Återuppta av sig själv';

  @override
  String get locationBackgroundSheetKeepRunningDetail =>
      'Telefonen ber dig om tillåtelse';

  @override
  String get locationBackgroundSheetAppOnly => 'Låt den vara stoppad';

  @override
  String get locationBackgroundSheetAppOnlyDetail => 'Inget mer att tillåta';

  @override
  String get locationServiceNotificationTitle => 'Delar din position live';

  @override
  String get locationServiceNotificationBody =>
      'Tryck för att öppna chatten, eller Stoppa för att avsluta nu';

  @override
  String get childPolicyScreenLocationLabel => 'Plats';

  @override
  String get childPolicyScreenLocationOnDesc =>
      'Kan dela var hen är, även live i upp till 8 timmar';

  @override
  String get childPolicyScreenLocationOffDesc => 'Kan inte dela var hen är';

  @override
  String get roomInfoScreenSavedMessagesLabel => 'SPARADE MEDDELANDEN';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      'bara du ser dessa, och bara från det här rummet. din chatt Sparade meddelanden är separat.';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      'inget sparat än. håll in ett meddelande och välj SPARA.';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return 'Hoppa till sparat meddelande från $name';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return 'Ta bort sparat meddelande från $name';
  }

  @override
  String get composerCaptureCameraModeLabel => 'kamera';

  @override
  String get composerCaptureVoiceModeLabel => 'röstmeddelande';

  @override
  String get composerCaptureVideoNoteModeLabel => 'videonotis';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode. Svep med två fingrar eller använd piltangenterna för att byta läge.';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '$mode valt';
  }

  @override
  String get composerCaptureRecordingAnnouncement => 'Inspelning startad';

  @override
  String get composerCaptureLockedAnnouncement =>
      'Inspelning låst. Händerna fria.';

  @override
  String get composerCaptureCancelledAnnouncement => 'Inspelningen kasserades';

  @override
  String get composerCaptureSentAnnouncement => 'Inspelningen skickades';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return 'Spelar in, $elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint =>
      'Håll intryckt för att spela in, svep för att växla';

  @override
  String get composerCaptureTapForCameraHint =>
      'Tryck för kamera, svep för att växla';

  @override
  String get composerCaptureSlideToCancelHint => 'dra för att avbryta';

  @override
  String get composerCaptureReleaseToCancelHint => 'släpp för att avbryta';

  @override
  String get composerCaptureTapToSendHint => 'tryck för att skicka';

  @override
  String get composerCaptureSendingLabel => 'skickar…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return '$seconds s kvar';
  }

  @override
  String get composerCaptureCancelLabel => 'kasta inspelningen';

  @override
  String get composerCaptureSendLabel => 'skicka inspelningen';

  @override
  String get composerCaptureLockLabel => 'dra uppåt för att låsa inspelningen';

  @override
  String get composerCaptureMicPermissionTitle => 'Mikrofon krävs';

  @override
  String get composerCaptureMicPermissionBody =>
      'MonkeyHub behöver din mikrofon för att spela in ett röstmeddelande. Slå på den i Inställningar och försök igen.';

  @override
  String get composerCaptureCameraPermissionTitle => 'Kamera krävs';

  @override
  String get composerCaptureCameraPermissionBody =>
      'MonkeyHub behöver din kamera och mikrofon för att spela in en videonotis. Slå på dem i Inställningar och försök igen.';

  @override
  String get composerCaptureRestrictedBody =>
      'Inspelning är avstängd av en begränsning på den här enheten.';

  @override
  String get composerCaptureOpenSettingsLabel => 'Öppna Inställningar';

  @override
  String get composerCaptureUnavailableSnack =>
      'Inspelning är inte tillgänglig på den här enheten.';

  @override
  String get composerCaptureInterruptedSnack => 'Inspelningen stoppades.';

  @override
  String get composerCaptureStorageSnack =>
      'Det gick inte att spara inspelningen. Kontrollera ledigt utrymme.';

  @override
  String get videoNoteMessagePlayLabel => 'spela upp videonotis';

  @override
  String get videoNoteMessagePauseLabel => 'pausa videonotis';

  @override
  String get videoNoteMessageLoadingLabel => 'laddar videonotis';

  @override
  String get videoNoteMessageUnavailableLabel =>
      'videonotis är inte tillgänglig';

  @override
  String get videoNoteMessageRetryLabel => 'försök med videonotisen igen';

  @override
  String get videoNoteMessageRetryHint => 'tryck för att försöka igen';

  @override
  String get videoNoteMessageDiscardLabel => 'kasta videonotisen';

  @override
  String get attachmentMenuVideoNoteLabel => 'videonotis';

  @override
  String get cameraScreenPhotoModeLabel => 'FOTO';

  @override
  String get cameraScreenVideoModeLabel => 'VIDEO';

  @override
  String get cameraScreenStartRecordingLabel => 'starta inspelning';

  @override
  String get cameraScreenStopRecordingLabel => 'stoppa inspelning';

  @override
  String get cameraScreenVideoFailedSnack =>
      'Det gick inte att spela in videon.';

  @override
  String get scheduleSheetTitle => 'SCHEMALÄGG MEDDELANDE';

  @override
  String get scheduleSheetSubtitle =>
      'Skriv det nu. Det går iväg när du säger till.';

  @override
  String get scheduleSheetWhenLabel => 'NÄR';

  @override
  String get schedulePresetInAnHour => 'Om 1 timme';

  @override
  String get schedulePresetInEightHours => 'Om 8 timmar';

  @override
  String get schedulePresetTomorrowMorning => 'I morgon bitti';

  @override
  String get schedulePresetThisMorning => 'I morse';

  @override
  String get schedulePresetInAWeek => 'Om 1 vecka';

  @override
  String get scheduleSheetCustomChip => 'Välj datum';

  @override
  String get scheduleSheetConfirmButton => 'SCHEMALÄGG';

  @override
  String get scheduleSheetSaveButton => 'SPARA';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'Skickas $when.';
  }

  @override
  String scheduleWhenToday(String time) {
    return 'i dag $time';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return 'i morgon $time';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return '$date $time';
  }

  @override
  String get scheduleTimePickerTitle => 'VÄLJ DATUM OCH TID';

  @override
  String get scheduleTimePickerBack => 'Snabbval';

  @override
  String get scheduleTimePickerToday => 'I dag';

  @override
  String get scheduleTimePickerTomorrow => 'I morgon';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SCHEMALAGDA',
      one: '1 SCHEMALAGT',
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
      other: '$count meddelanden väntar på att skickas. Tryck för att se dem.',
      one: '1 meddelande väntar på att skickas. Tryck för att se det.',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => 'SE HÄR';

  @override
  String get scheduledListTitle => 'SCHEMALAGDA';

  @override
  String get scheduledListSubtitle => 'Bara du ser dem tills de skickas.';

  @override
  String get scheduledListEmpty => 'Inget väntar på att skickas här.';

  @override
  String get scheduledListSendNow => 'Skicka nu';

  @override
  String get scheduledListChangeTime => 'Ändra tid';

  @override
  String get scheduledListEdit => 'Ändra texten';

  @override
  String get scheduledListDelete => 'Ta bort';

  @override
  String get scheduledListSending => 'Skickar…';

  @override
  String get scheduledListFailedTitle => 'Kunde inte skickas';

  @override
  String get scheduledListRetry => 'Försök igen';

  @override
  String get scheduleErrorOutOfRange =>
      'Välj en tid mellan två minuter och ett år från nu.';

  @override
  String get scheduleErrorTooMany =>
      'För många meddelanden väntar här. Skicka eller ta bort några först.';

  @override
  String get scheduleErrorNotInEphemeral =>
      'Meddelanden här försvinner av sig själva, så de går inte att schemalägga.';

  @override
  String get scheduleErrorNotMember => 'Du är inte kvar i den här chatten.';

  @override
  String get scheduleErrorBlocked => 'Du behöver häva blockeringen först.';

  @override
  String get scheduleErrorGeneric => 'Det gick inte. Försök igen.';

  @override
  String get scheduleEditTitle => 'ÄNDRA MEDDELANDE';

  @override
  String get composerScheduleAction => 'Schemalägg det här meddelandet';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meddelanden väntar på att skickas',
      one: '1 meddelande väntar på att skickas',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => 'VISA SOM';

  @override
  String get scheduledIndicatorPill => 'Pillerknapp';

  @override
  String get scheduledIndicatorBadge => 'Bricka';

  @override
  String get scheduledIndicatorBoth => 'Båda';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meddelanden väntar redan',
      one: '1 meddelande väntar redan',
      zero: 'Inget väntar på att skickas',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => 'Hur de visas';

  @override
  String get scheduledIndicatorPillSub =>
      'En rad ovanför skrivfältet. Tryck för att se dem.';

  @override
  String get scheduledIndicatorBadgeSub =>
      'En siffra på skicka-knappen. Inget syns förrän du börjar skriva.';

  @override
  String get scheduledIndicatorBothSub =>
      'Raden, plus siffran medan du skriver.';

  @override
  String get scheduledBack => 'Tillbaka';

  @override
  String get serverScreenTitle => 'server.';

  @override
  String get serverScreenSubtitle =>
      'där ditt konto och dina meddelanden finns';

  @override
  String get serverOnboardingTitle => 'välj en server.';

  @override
  String get serverOnboardingSubtitle =>
      'den här versionen kom utan server – peka den mot din';

  @override
  String get serverStatusConnected => 'ANSLUTEN';

  @override
  String get serverStatusDisconnected => 'EJ ANSLUTEN';

  @override
  String get serverBadgeDefault => 'STANDARD';

  @override
  String get serverBadgeSelfHosted => 'EGEN SERVER';

  @override
  String get serverNoneConfigured => 'Ingen server ännu';

  @override
  String get serverActiveNowLabel => 'ANVÄNDS';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'Servern som följde med appen.';

  @override
  String get serverChoiceOwn => 'Din egen server';

  @override
  String get serverChoiceOwnSub => 'En Convex-backend som du kör själv.';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => 'KLISTRA IN';

  @override
  String get serverProblemMalformed => 'Det där är ingen webbadress.';

  @override
  String get serverProblemBadScheme => 'Börja med https:// eller http://.';

  @override
  String get serverProblemNoHost =>
      'Lägg till din servers adress efter https://.';

  @override
  String get serverProblemCredentials =>
      'Ta bort användarnamnet och lösenordet ur adressen.';

  @override
  String get serverInsecureTitle => 'OKRYPTERAD';

  @override
  String get serverInsecureBody =>
      'Telefoner blockerar okrypterad http, så den här adressen ansluter inte på iOS eller Android. Använd https, eller nå din server via en tunnel.';

  @override
  String get serverTestCta => 'TESTA ANSLUTNINGEN';

  @override
  String get serverTestingLabel => 'Testar…';

  @override
  String get serverCheckReachable => 'Något svarade';

  @override
  String get serverCheckConvex => 'Det är en Convex-server';

  @override
  String get serverCheckApp => 'MonkeyHub körs där';

  @override
  String get serverResultUnreachable => 'Ingenting svarade på den adressen.';

  @override
  String get serverResultNotConvex =>
      'Något svarade, men det är ingen Convex-server.';

  @override
  String get serverResultNotThisApp =>
      'Det är en Convex-server, men MonkeyHub finns inte där.';

  @override
  String get serverResultServerError => 'Servern svarade, men med ett fel.';

  @override
  String get serverResultReady => 'Redo att ansluta.';

  @override
  String get serverConnectCta => 'ANSLUT';

  @override
  String get serverConnectAnywayCta => 'ANSLUT ÄNDÅ';

  @override
  String get serverAlreadyConnectedCta => 'REDAN ANSLUTEN';

  @override
  String get serverUseDefaultCta => 'ANVÄND STANDARDSERVERN';

  @override
  String get serverChangeCta => 'BYT SERVER';

  @override
  String get serverAdvancedLabel => 'AVANCERAT';

  @override
  String get serverSiteUrlExplain =>
      'De flesta servrar svarar på allt via en adress. Fyll bara i det här om din levererar HTTP-actions någon annanstans.';

  @override
  String get serverSiteUrlHint => 'Samma som ovan';

  @override
  String get serverSectionRecent => 'SENASTE';

  @override
  String get serverRecentForget => 'Glöm den här servern';

  @override
  String get serverSwitchWarningTitle => 'BYTE LOGGAR UT DIG';

  @override
  String get serverSwitchWarningBody =>
      'Konton och chattar hör till en enda server. Den här enheten loggas ut, rensar det den laddat ner och börjar om. Inget raderas på någon av servrarna.';

  @override
  String get serverSwitchRolledBackTitle => 'KUNDE INTE ANSLUTA';

  @override
  String serverSwitchRolledBackBody(String host) {
    return '$host svarade inte, så ingenting ändrades. Du behöver logga in igen.';
  }

  @override
  String get serverSwitchStrandedBody =>
      'Ingen av servrarna gick att ansluta till. Kontrollera adressen och försök igen.';

  @override
  String get serverSwitchRefusedBody =>
      'Den här enheten är inställd för ett barn och kan inte byta server.';

  @override
  String serverChipSemantics(String server) {
    return 'Byt server. Just nu $server.';
  }

  @override
  String get serverValueDefault => 'Standard';

  @override
  String get settingsScreenRowServer => 'SERVER';

  @override
  String get settingsScreenSectionAdvanced => 'AVANCERAT';

  @override
  String get serverSwitchingLabel => 'Byter server…';

  @override
  String get serverBadgeHomeserver => 'Körs från hemservern';

  @override
  String get serverBadgeHomeserverSemantics =>
      'Körs från hemservern. Tryck för detaljer.';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'Egen server: $server. Tryck för detaljer.';
  }

  @override
  String get serverRoleHomeserverTitle => 'Kör på hemservern';

  @override
  String get serverRoleHomeserverBody =>
      'De som driver MonkeyHub har flyttat trafiken till sin hemmaserver ett tag. Allt fungerar likadant – det är avsiktligt, inte ett fel.';

  @override
  String get serverRoleHomeserverWarnData =>
      'Det du skickar medan det här pågår kanske inte finns kvar när trafiken flyttas tillbaka.';

  @override
  String get serverRoleHomeserverWarnSpeed =>
      'En hemmauppkoppling är långsammare än den vanliga, så det kan hacka.';

  @override
  String get serverRoleHomeserverWarnAuto =>
      'Du behöver inte göra något. Appen byter tillbaka av sig själv.';

  @override
  String get serverRoleSelfHostedTitle => 'Din egen server';

  @override
  String get serverRoleSelfHostedBody =>
      'Den här enheten pekar mot en server du kör. Ändra under Inställningar › Avancerat › Server.';

  @override
  String get serverValueHomeserver => 'Hemservern, tills vidare';

  @override
  String get serverChoiceCloudSubHomeserver =>
      'Levereras från hemservern ett tag.';

  @override
  String get serverDirectiveChangedToast =>
      'Din server har bytts. Ansluter igen…';

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
  String get roomAdminRoleAdmin => 'ADMIN';

  @override
  String get roomAdminActionViewProfile => 'Visa profil';

  @override
  String get roomAdminActionPromote => 'Gör till admin';

  @override
  String get roomAdminActionPromoteSub =>
      'Kan bjuda in, ta bort medlemmar och ändra gruppen';

  @override
  String get roomAdminActionDemote => 'Ta bort admin';

  @override
  String get roomAdminActionDemoteSub => 'Är kvar i gruppen som medlem';

  @override
  String get roomAdminActionTransfer => 'Överlåt gruppen';

  @override
  String get roomAdminActionTransferSub => 'Du blir kvar som admin';

  @override
  String get roomAdminActionRemove => 'Ta bort ur gruppen';

  @override
  String get roomAdminAddFriendsRow => 'Lägg till vänner';

  @override
  String get roomAdminInviteLinkRow => 'Inbjudningslänk';

  @override
  String get roomAdminJoinRequestsRow => 'Ansökningar';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return 'Lämna över gruppen till $name?';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      'Den personen blir ägare och kan radera gruppen. Du blir kvar som admin, och bara hen kan lämna tillbaka den.';

  @override
  String get roomAdminTransferConfirmCta => 'ÖVERLÅT';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return 'Ta bort $name?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'Personen förlorar åtkomst till gruppen och allt i den. Hen kan bjudas in igen, eller komma tillbaka via inbjudningslänken.';

  @override
  String get roomAdminRemoveConfirmCta => 'TA BORT';

  @override
  String get roomAdminGenericError => 'Det gick inte. Försök igen.';

  @override
  String get roomAdminErrorNotMember => 'Du är inte kvar i den här gruppen.';

  @override
  String get roomAdminErrorNotAdmin => 'Bara admins kan göra det.';

  @override
  String get roomAdminErrorNotOwner => 'Bara gruppens ägare kan göra det.';

  @override
  String get roomAdminErrorNotGroup =>
      'Det finns inget att administrera i en direktchatt.';

  @override
  String get roomAdminErrorOwnerImmutable =>
      'Ägarens roll ändras bara genom att gruppen överlåts.';

  @override
  String get roomAdminErrorInvitesLocked =>
      'Bara admins kan bjuda in till den här gruppen.';

  @override
  String get roomInviteSheetTitle => 'Inbjudningslänk';

  @override
  String get roomInviteSheetBlurb =>
      'En länk och en kod, och de är samma sak. Så fort du gör en ny slutar den gamla fungera.';

  @override
  String get roomInviteNoLinkYet => 'Gruppen har ingen inbjudningslänk än.';

  @override
  String get roomInviteCreateButton => 'SKAPA LÄNK';

  @override
  String get roomInviteRegenerateButton => 'NY LÄNK';

  @override
  String get roomInviteRevokeButton => 'SPÄRRA LÄNKEN';

  @override
  String get roomInviteCopyLink => 'Kopiera länk';

  @override
  String get roomInviteCopyCode => 'Kopiera kod';

  @override
  String get roomInviteShare => 'Dela';

  @override
  String get roomInviteLinkCopied => 'Länken kopierad.';

  @override
  String get roomInviteCodeCopied => 'Koden kopierad.';

  @override
  String get roomInviteRegenerateHeadline => 'Göra en ny länk?';

  @override
  String get roomInviteRegenerateBody =>
      'Den nuvarande länken och koden slutar fungera direkt, överallt där de har delats. Alla som redan är med är kvar.';

  @override
  String get roomInviteRegenerateConfirm => 'NY LÄNK';

  @override
  String get roomInviteRevokeHeadline => 'Spärra den här länken?';

  @override
  String get roomInviteRevokeBody =>
      'Ingen ny kan gå med via länk förrän du gör en till. Alla som redan är med är kvar.';

  @override
  String get roomInviteRevokeConfirm => 'SPÄRRA';

  @override
  String get roomInviteLimitsLabel => 'GRÄNSER';

  @override
  String get roomInviteExpiryLabel => 'Slutar gälla efter';

  @override
  String get roomInviteMaxUsesLabel => 'Antal användningar';

  @override
  String get roomInviteNeverExpires => 'Aldrig';

  @override
  String get roomInviteUnlimited => 'Obegränsat';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count h';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count d';
  }

  @override
  String get roomInviteLimitsApplyToNew => 'Gäller länken du skapar.';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      'Gäller nästa länk. Den ovanför behåller gränserna den skapades med.';

  @override
  String get roomInvitePermissionsLabel => 'BEHÖRIGHETER';

  @override
  String get roomInviteMembersCanInviteLabel => 'Medlemmar får bjuda in vänner';

  @override
  String get roomInviteMembersCanInviteSub =>
      'Stäng av så kan bara admins ta in folk';

  @override
  String get roomInviteApprovalLabel => 'Godkänn varje ny medlem';

  @override
  String get roomInviteApprovalSub =>
      'Den som har länken frågar först, och en admin säger ja eller nej';

  @override
  String roomInviteUsesCount(Object count) {
    return 'Använd $count gånger';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$used av $max användningar';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return 'slutar gälla $date';
  }

  @override
  String get roomInviteDeadExpired => 'Länken har slutat gälla. Gör en ny.';

  @override
  String get roomInviteDeadExhausted =>
      'Länken har inga användningar kvar. Gör en ny.';

  @override
  String get roomInviteDeadRevoked => 'Länken spärrades.';

  @override
  String get roomInviteDeadGeneric => 'Länken fungerar inte längre.';

  @override
  String get roomInviteFriendsTitle => 'Lägg till vänner';

  @override
  String get roomInviteFriendsBlurb =>
      'De får en inbjudan och kan tacka ja eller nej.';

  @override
  String get roomInviteFriendsSearchHint => 'Sök bland vänner';

  @override
  String get roomInviteFriendsInviteButton => 'BJUD IN';

  @override
  String get roomInviteFriendsSent => 'Inbjuden';

  @override
  String get roomInviteFriendsEmpty =>
      'Alla dina vänner är redan här eller redan inbjudna.';

  @override
  String get roomInviteFriendsNoMatch => 'Ingen vän matchar det.';

  @override
  String get roomInviteFriendsDone => 'KLAR';

  @override
  String get roomJoinRequestsTitle => 'Ansökningar';

  @override
  String get roomJoinRequestsBlurb =>
      'De här personerna har använt inbjudningslänken. De ser ingenting i gruppen förrän du säger ja.';

  @override
  String get roomJoinRequestsEmpty => 'Ingen väntar.';

  @override
  String get roomJoinRequestsApprove => 'SLÄPP IN';

  @override
  String get roomJoinRequestsReject => 'NEJ';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return 'INBJUDNA · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian => 'väntar på en förälder';

  @override
  String get roomInfoScreenInviteWithdraw => 'ÅTERKALLA';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return 'från $inviter · $members medlemmar';
  }

  @override
  String get roomInvitationCardJoin => 'GÅ MED';

  @override
  String get discoverScreenJoinByCodeTitle => 'gå med via kod';

  @override
  String get discoverScreenJoinByCodeSubtitle =>
      'öppna en grupp som någon delat med dig';

  @override
  String get joinInviteTitle => 'Gå med i en grupp';

  @override
  String get joinInviteBack => 'Tillbaka';

  @override
  String get joinInviteCodeBlurb =>
      'Skriv in koden någon delat med dig. En hel inbjudningslänk funkar också.';

  @override
  String get joinInviteCodeLabel => 'Inbjudningskod';

  @override
  String get joinInviteCodeHint => 'Klistra in länken eller skriv koden';

  @override
  String get joinInviteCodeInvalid =>
      'Det där ser inte ut som en inbjudningskod.';

  @override
  String get joinInviteLookupButton => 'FORTSÄTT';

  @override
  String get joinInviteLookupFailed =>
      'Kunde inte kolla koden. Kolla din uppkoppling och försök igen.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count medlemmar';
  }

  @override
  String get joinInviteJoinButton => 'GÅ MED I GRUPPEN';

  @override
  String get joinInviteRequestButton => 'BE ATT FÅ GÅ MED';

  @override
  String get joinInviteOpenNote =>
      'Du ser gruppens meddelanden så fort du gått med.';

  @override
  String get joinInviteApprovalNote =>
      'En admin måste säga ja innan du kan se något här inne.';

  @override
  String get joinInviteOpenRoom => 'ÖPPNA GRUPPEN';

  @override
  String get joinInvitePendingHeadline => 'Väntar på en admin';

  @override
  String get joinInvitePendingBody => 'Du får en notis så fort någon svarar.';

  @override
  String get joinInviteBadLinkHeadline => 'Inbjudan fungerar inte';

  @override
  String get joinInviteBadLinkBody => 'Kolla koden, eller be om en ny länk.';

  @override
  String get joinInviteExpiredHeadline => 'Inbjudan har gått ut';

  @override
  String get joinInviteExpiredBody => 'Be den som bjöd in dig om en ny länk.';

  @override
  String get joinInviteExhaustedHeadline => 'Inbjudan är förbrukad';

  @override
  String get joinInviteExhaustedBody =>
      'Den var satt att fungera ett begränsat antal gånger. Be om en ny.';

  @override
  String get joinInviteRevokedHeadline => 'Inbjudan har ersatts';

  @override
  String get joinInviteRevokedBody =>
      'En admin gjorde en ny länk. Be om den aktuella.';

  @override
  String get joinInviteWrongServerHeadline => 'Inbjudan gäller en annan server';

  @override
  String joinInviteWrongServerBody(Object host) {
    return 'Den hör till $host. Ditt konto ligger på en annan server, så gruppen går inte att nå härifrån.';
  }

  @override
  String get roomInviteErrorNotFound =>
      'Den inbjudningskoden matchar ingenting.';

  @override
  String get roomInviteErrorRevoked =>
      'Inbjudan har ersatts. Be om den aktuella länken.';

  @override
  String get roomInviteErrorExpired => 'Inbjudan har gått ut.';

  @override
  String get roomInviteErrorExhausted => 'Inbjudan är förbrukad.';

  @override
  String get roomInviteErrorAlreadyMember => 'Personen är redan med i gruppen.';

  @override
  String get roomInviteErrorAlreadyInvited => 'Personen är redan inbjuden.';

  @override
  String get roomInviteErrorSelf => 'Du är redan med i gruppen.';

  @override
  String get roomInviteErrorInvitationGone => 'Inbjudan finns inte längre.';

  @override
  String get roomInviteErrorRequestPending =>
      'Du har redan bett om att gå med. En admin svarar.';

  @override
  String get roomInviteErrorRequestGone =>
      'Någon har redan svarat på den ansökan.';

  @override
  String get roomInviteErrorRoomPrivate =>
      'Man kommer bara in i den här gruppen via inbjudan.';

  @override
  String get roomInviteErrorInvalidLimits => 'De gränserna gäller inte.';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$child vill bjuda in $other till $room';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$other bjöd in $child till $room';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      'Inbjudan skickas, och den andra personen bestämmer fortfarande själv.';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$child ser inbjudan och kan tacka ja eller nej. Godkänner du släpps hen också in i gruppen om hen tackar ja.';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      'Du kan inte ta bort dig själv. Lämna gruppen i stället.';

  @override
  String get roomAdminActionMessage => 'Skicka meddelande';

  @override
  String get roomAdminActionVoiceCall => 'Röstsamtal';

  @override
  String get roomAdminActionVideoCall => 'Videosamtal';

  @override
  String get roomAdminYouSuffix => 'du';

  @override
  String get roomInfoScreenSetPasswordButton => 'SPARA';

  @override
  String get roomInfoScreenPasswordSetSnackbar => 'Lösenord sparat.';

  @override
  String get roomInfoScreenPasswordSetState => 'Lösenord på';

  @override
  String get roomInfoScreenPasswordUnsetState => 'Inget lösenord';

  @override
  String get roomInfoScreenPasswordCancel => 'Avbryt';

  @override
  String get roomInfoScreenEditSave => 'Spara';

  @override
  String get roomInfoScreenEditCancel => 'Avbryt';

  @override
  String get roomInviteRotatedToast =>
      'Ny länk skapad. Den gamla fungerar inte längre.';

  @override
  String get roomInviteRevokedToast => 'Inbjudningslänken spärrad.';

  @override
  String get newChatMenuTitle => 'Ny chatt';

  @override
  String get newChatMenuCreateTitle => 'Skapa ett rum';

  @override
  String get newChatMenuCreateSub => 'Starta en grupp och bjud in folk';

  @override
  String get newChatMenuJoinTitle => 'Gå med via kod';

  @override
  String get newChatMenuJoinSub => 'Öppna en grupp som någon delat med dig';

  @override
  String get shareSheetTitle => 'DELA MED';

  @override
  String get shareSheetSuggestedHeading => 'FÖRSLAG';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bilagor',
      one: '1 bilaga',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filer är över gränsen på $size och togs inte med',
      one: '1 fil är över gränsen på $size och togs inte med',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return 'Skicka till $title';
  }

  @override
  String get settingsScreenRowSpeakerColors => 'PERSONFÄRGER';

  @override
  String get settingsScreenValueSpeakerOff => 'Av';

  @override
  String get settingsScreenValueSpeakerName => 'Namn';

  @override
  String get settingsScreenValueSpeakerBubble => 'Namn + bubblor';

  @override
  String get speakerColorScreenTitle => 'personfärger.';

  @override
  String get speakerColorScreenSubtitle =>
      'vem som sa det, utan att läsa namnet';

  @override
  String get speakerColorScreenOffLabel => 'AV';

  @override
  String get speakerColorScreenOffDescription =>
      'alla i rummet skriver med samma bläck.';

  @override
  String get speakerColorScreenNameLabel => 'NAMN';

  @override
  String get speakerColorScreenNameDescription =>
      'varje person får en egen färg, på namnet och runt ansiktet.';

  @override
  String get speakerColorScreenBubbleLabel => 'BUBBLOR';

  @override
  String get speakerColorScreenBubbleDescription =>
      'färgen följer med in i meddelandena, så en rad på fem säger fortfarande vem som skrev.';

  @override
  String get roomInfoScreenSpeakerColorsLabel => 'FÄRGER';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => 'Automatiskt';

  @override
  String get roomInfoScreenSpeakerColorsCustom => 'Eget';

  @override
  String get roomColorsScreenTitle => 'vem är vem.';

  @override
  String get roomColorsScreenSubtitle => 'färgen varje person talar i';

  @override
  String get roomColorsScreenOffTitle => 'personfärger är av';

  @override
  String get roomColorsScreenOffBody =>
      'just nu ritas alla med samma bläck. slå på så får var och en här en egen.';

  @override
  String get roomColorsScreenOffAction => 'SLÅ PÅ';

  @override
  String get roomColorsScreenOffHint =>
      'gäller alla rum, inte bara det här. finns även i inställningar.';

  @override
  String get roomColorsScreenAutoChip => 'AUTO';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return 'delas med $name';
  }

  @override
  String get roomColorsScreenResetAll => 'TILLBAKA TILL AUTOMATISKT';

  @override
  String get roomColorsScreenLimitToast =>
      'Fler färger än så kan ett rum inte fästa.';

  @override
  String get roomColorsScreenFailedToast => 'Kunde inte spara färgen.';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return 'Färg $index';
  }

  @override
  String get devicesScreenTitle => 'DINA ENHETER';

  @override
  String get devicesScreenSubtitle =>
      'Alla ställen där du har loggat in på det här kontot.';

  @override
  String get devicesScreenLoading => 'kollar…';

  @override
  String get devicesScreenLoadFailed => 'kunde inte ladda dina enheter';

  @override
  String get devicesScreenThisDevice => 'DEN HÄR ENHETEN';

  @override
  String get devicesScreenActiveNow => 'aktiv nu';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'för $count minuter sedan',
      one: 'för 1 minut sedan',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'för $count timmar sedan',
      one: 'för 1 timme sedan',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'för $count dagar sedan',
      one: 'för 1 dag sedan',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications => 'aviseringar når inte fram hit';

  @override
  String get devicesScreenRemove => 'TA BORT';

  @override
  String get devicesScreenRemoveTitle => 'TA BORT DEN HÄR ENHETEN?';

  @override
  String devicesScreenRemoveBody(Object name) {
    return '$name loggas ut och slutar ta emot aviseringar. Den som har enheten måste logga in igen.';
  }

  @override
  String get devicesScreenRemoveConfirm => 'TA BORT';

  @override
  String get devicesScreenRemoveAll => 'Ta bort alla andra enheter';

  @override
  String get devicesScreenRemoveAllTitle => 'TA BORT ALLA ANDRA ENHETER?';

  @override
  String get devicesScreenRemoveAllBody =>
      'Alla loggas ut och slutar ta emot aviseringar. Bara den här enheten förblir inloggad.';

  @override
  String get devicesScreenRemoveAllConfirm => 'TA BORT ALLA';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enheter borttagna',
      one: '1 enhet borttagen',
      zero: 'inga andra enheter att ta bort',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed => 'kunde inte ta bort den enheten';

  @override
  String get devicesScreenFootnote =>
      'Att ta bort en enhet loggar ut den och stoppar dess aviseringar. Det gäller direkt — nästa sak enheten försöker göra skickar den till inloggningsskärmen.';

  @override
  String get attachmentMenuPollLabel => 'omröstning';

  @override
  String get attachmentMenuChecklistLabel => 'lista';

  @override
  String get attachmentMenuEventLabel => 'händelse';

  @override
  String get interactionKindPoll => 'OMRÖSTNING';

  @override
  String get interactionKindQuiz => 'QUIZ';

  @override
  String get interactionKindChecklist => 'LISTA';

  @override
  String get interactionKindEvent => 'HÄNDELSE';

  @override
  String get interactionBadgeAnonymous => 'ANONYM';

  @override
  String get interactionBadgeMultiple => 'FLERA';

  @override
  String get interactionBadgeClosed => 'STÄNGD';

  @override
  String interactionPercent(int percent) {
    return '$percent %';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names +$count';
  }

  @override
  String get interactionSeeWhoAnswered => 'Se vilka som svarat';

  @override
  String interactionRemoveItem(String label) {
    return 'Ta bort $label';
  }

  @override
  String interactionChoiceSemantics(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count röster',
      one: '1 röst',
    );
    return '$label, $_temp0';
  }

  @override
  String get interactionAddItemHint => 'Lägg till en punkt';

  @override
  String get interactionRetract => 'Ta tillbaka';

  @override
  String get interactionClose => 'Stäng';

  @override
  String interactionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count röster',
      one: '1 röst',
    );
    return '$_temp0';
  }

  @override
  String interactionRsvpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count svar',
      one: '1 svar',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$done av $total klara';
  }

  @override
  String get interactionNoAnswers => 'Inga svar';

  @override
  String get interactionBeFirst => 'Bli först med att svara';

  @override
  String interactionFinalResults(String count) {
    return '$count · slutgiltigt';
  }

  @override
  String get interactionQuizRight => 'Rätt';

  @override
  String get interactionQuizWrong => 'Nästan';

  @override
  String interactionEventPast(String when) {
    return '$when · har redan varit';
  }

  @override
  String get interactionRespondentsTitlePoll => 'VILKA RÖSTADE';

  @override
  String get interactionRespondentsTitleChecklist => 'VILKA BOCKADE AV';

  @override
  String get interactionRespondentsTitleEvent => 'VILKA SVARADE';

  @override
  String get interactionRespondentsFailed =>
      'Kunde inte hämta vilka som svarat.';

  @override
  String get interactionRespondentsEmpty => 'Ingen har svarat än.';

  @override
  String get interactionFilterAll => 'ALLA';

  @override
  String get interactionRsvpGoing => 'Kommer';

  @override
  String get interactionRsvpMaybe => 'Kanske';

  @override
  String get interactionRsvpNo => 'Kan inte';

  @override
  String get interactionComposePollTitle => 'ny omröstning';

  @override
  String get interactionComposePollTagline => 'FRÅGA RUMMET';

  @override
  String get interactionComposeChecklistTitle => 'ny lista';

  @override
  String get interactionComposeChecklistTagline => 'EN LISTA ALLA KAN BOCKA AV';

  @override
  String get interactionComposeEventTitle => 'ny händelse';

  @override
  String get interactionComposeEventTagline => 'SE VILKA SOM KOMMER';

  @override
  String get interactionComposeQuestionLabel => 'FRÅGA';

  @override
  String get interactionComposeQuestionHint => 'vad vill du fråga?';

  @override
  String get interactionComposeTitleLabel => 'TITEL';

  @override
  String get interactionComposeTitleHint => 'vad är listan till för?';

  @override
  String get interactionComposeEventNameLabel => 'HÄNDELSE';

  @override
  String get interactionComposeEventNameHint => 'vad händer?';

  @override
  String get interactionComposeOptionsLabel => 'ALTERNATIV';

  @override
  String get interactionComposeItemsLabel => 'PUNKTER';

  @override
  String interactionComposeOptionHint(int index) {
    return 'alternativ $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return 'punkt $index';
  }

  @override
  String get interactionComposeAddOption => 'Lägg till alternativ';

  @override
  String get interactionComposeAddItem => 'Lägg till punkt';

  @override
  String get interactionComposeRemoveRow => 'Ta bort';

  @override
  String get interactionComposeMarkCorrect => 'Markera som rätt svar';

  @override
  String get interactionComposeMultipleTitle => 'flera svar';

  @override
  String get interactionComposeMultipleSub => 'välj mer än ett';

  @override
  String get interactionComposeAnonymousTitle => 'anonym';

  @override
  String get interactionComposeAnonymousOffSub => 'alla ser vilka som röstat';

  @override
  String get interactionComposeAnonymousOnSub => 'ingen ser vilka som röstat';

  @override
  String get interactionComposeQuizTitle => 'quizläge';

  @override
  String get interactionComposeQuizSub => 'ett rätt svar, går inte att ändra';

  @override
  String get interactionComposeExplanationLabel => 'FÖRKLARING';

  @override
  String get interactionComposeExplanationHint =>
      'visas efter svaret (valfritt)';

  @override
  String get interactionComposeOthersMayCheckTitle => 'alla får bocka av';

  @override
  String get interactionComposeOthersMayCheckSub => 'inte bara du';

  @override
  String get interactionComposeOthersMayAddTitle => 'alla får lägga till';

  @override
  String get interactionComposeOthersMayAddSub => 'listan kan växa senare';

  @override
  String get interactionComposeWhenLabel => 'NÄR';

  @override
  String get interactionComposePickStart => 'Välj en start';

  @override
  String get interactionComposePickEnd => 'Lägg till ett slut (valfritt)';

  @override
  String get interactionComposePlaceLabel => 'PLATS';

  @override
  String get interactionComposePlaceHint => 'var? (valfritt)';

  @override
  String get interactionComposeSendPoll => 'SKICKA OMRÖSTNINGEN';

  @override
  String get interactionComposeSendChecklist => 'SKICKA LISTAN';

  @override
  String get interactionComposeSendEvent => 'SKICKA HÄNDELSEN';

  @override
  String get interactionComposeErrorPrompt => 'Säg först vad du frågar om.';

  @override
  String interactionComposeErrorOptions(int count) {
    return 'En omröstning behöver minst $count alternativ.';
  }

  @override
  String get interactionComposeErrorItems => 'En lista behöver minst en punkt.';

  @override
  String get interactionComposeErrorAnswer =>
      'Markera vilket alternativ som är rätt.';

  @override
  String get interactionComposeErrorWhen => 'Välj när den börjar.';

  @override
  String get interactionComposeErrorEnd => 'Slutet måste komma efter starten.';

  @override
  String get interactionSendFailed => 'Det skickades inte.';

  @override
  String get interactionRefused => 'Det gick inte igenom.';
}
