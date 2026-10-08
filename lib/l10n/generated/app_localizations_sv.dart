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
  String get bootErrorTitle => 'Kan inte nå servern';

  @override
  String get bootErrorBody => 'Convex kunde inte starta.';

  @override
  String get bootErrorRetry => 'Försök igen';

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
      'Kunde inte fråga just nu — försök igen';

  @override
  String get roomScreenGateSendMessages => 'skicka meddelanden här';

  @override
  String get roomScreenGateSendMedia => 'skicka bilder eller röstmeddelanden';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'Högst $max åt gången';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ta bort $count meddelanden',
      one: 'Ta bort meddelande',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Detta tar bort dem för alla i den här chatten. Det går inte att ångra.';

  @override
  String get roomScreenDeleteConfirmButton => 'Ta bort för alla';

  @override
  String get roomScreenJumpFailedSnack =>
      'Kunde inte hoppa till det meddelandet';

  @override
  String get roomScreenUnreadDivider => 'Olästa meddelanden';

  @override
  String get roomScreenViewOnceAlreadyViewed =>
      'Du har redan öppnat det här fotot.';

  @override
  String get roomScreenViewOnceGone => 'Det här fotot finns inte längre.';

  @override
  String get roomScreenViewOnceNetworkError => 'Kunde inte läsa in fotot.';

  @override
  String get roomScreenFileReadFailedSnack => 'Kunde inte läsa filen';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'Filer får max vara $size';
  }

  @override
  String get roomScreenRoomGone => 'Rummet är borta';

  @override
  String get roomScreenCopiedSnack => 'Kopierat';

  @override
  String get roomScreenNameCopiedSnack => 'Namnet kopierat';

  @override
  String get roomScreenPinLimitSnack =>
      'För många nålade meddelanden — nåla av ett först';

  @override
  String get roomScreenPinFailedSnack => 'Kunde inte nåla det';

  @override
  String get roomScreenReportSentSnack =>
      'Rapporten skickades privat. Personen får ingen avisering om det.';

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
    return 'Det här rummet är flyktigt. Meddelanden försvinner efter $ttl, lästa eller olästa.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count meddelanden';
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
  String get roomScreenViewProfilePictureSemantic => 'Visa profilbild';

  @override
  String get roomScreenViewRoomPictureSemantic => 'Visa rumsbild';

  @override
  String get messageBubbleFileFallbackName => 'Dokument';

  @override
  String get messageBubbleAttachmentStatusFailed => 'Misslyckades';

  @override
  String get messageBubbleAttachmentStatusSending => 'Skickar…';

  @override
  String get messageBubbleViewOnceOpened => 'Öppnat';

  @override
  String get messageBubbleViewOnceExpired => 'Utgånget';

  @override
  String get messageBubbleViewOnceLabel => 'Visa en gång';

  @override
  String get messageBubbleViewOnceTapToView => 'Tryck för att visa';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Foto';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'Engångsfoto, tryck för att visa';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'Försök att skicka igen';

  @override
  String get messageBubbleDiscardSemanticLabel => 'Ta bort';

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
  String get profileScreenLinkedAccountsNone => 'Inget länkat';

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
    return 'Kan bytas igen den $date';
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
  String get cameraEditorScreenCropPresetFree => 'Fri';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'Orig';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'Avbryt beskärning';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'Kassera foto';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'Ångra';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'Gör om';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'Återställ beskärning';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'Rotera';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'Beskär';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'Den här webbläsaren kan inte öppna HEIC-foton';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'Kunde inte öppna bilden';

  @override
  String get cameraEditorScreenCropDoneButton => 'Klar';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'Ta om';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'Lägg undan pennan';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'Rita på fotot';

  @override
  String get cameraEditorScreenSendingButton => 'Skickar…';

  @override
  String get cameraEditorScreenSendButton => 'Skicka';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'Försvinner efter att ha öppnats en gång';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'Rensa teckning';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel => 'Visa en gång: på';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel => 'Visa en gång: av';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: på';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: av';

  @override
  String get cameraEditorScreenHdNote => 'Skickas i full upplösning';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'Bläckfärg';

  @override
  String get glassScreenPanelLooks => 'Stilar';

  @override
  String get glassScreenPanelBottomBar => 'Nedre fältet';

  @override
  String get glassScreenPanelOtherSurfaces => 'Övriga ytor';

  @override
  String get glassScreenPanelBarLayout => 'Fältlayout';

  @override
  String get glassScreenTitle => 'glas.';

  @override
  String get glassScreenSubtitle =>
      'hur mycket av det som ligger bakom som syns igenom';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'Alla $max platser fulla';
  }

  @override
  String get glassScreenSaveCurrentAs => 'Spara nuvarande som…';

  @override
  String get glassScreenResetEveryDial => 'Återställ alla reglage';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'Återställ till $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'Skrivfältet, rubriker, samtalsknappar — allt som ligger ovanpå text snarare än ovanpå skrollande innehåll';

  @override
  String get glassScreenMatchBottomBar => 'Matcha det nedre fältet';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'Redigerad — spara som en ny stil, eller återställ den';

  @override
  String get glassScreenCustomPresetName => 'Anpassad';

  @override
  String get glassScreenUnsavedSubtitle =>
      'Osparad — ge den ett namn för att behålla den';

  @override
  String get glassScreenSaveDialogTitle => 'Spara den här looken som';

  @override
  String get glassScreenNoRoomToast => 'Ingen plats — ta bort en look först';

  @override
  String get glassScreenRenameDialogTitle => 'Byt namn';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'Ta bort $name?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'Looken stannar kvar på skärmen — den blir bara namnlös.';

  @override
  String get glassScreenKeepButton => 'Behåll';

  @override
  String get glassScreenDeleteButton => 'Ta bort';

  @override
  String get glassScreenNameHint => 'Sen kväll';

  @override
  String get glassScreenCancelButton => 'Avbryt';

  @override
  String get glassScreenSaveButton => 'Spara';

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
  String get glassScreenPreviewBadge => 'Förhandsvisning';

  @override
  String get glassScreenBuiltInLabel => 'Inbyggd';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'Skriv över $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'Byt namn på $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'Ta bort $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'Återställ $label';
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
  String get replyIndicatorViewOnceLabel => 'Foto · visas en gång';

  @override
  String get replyIndicatorVoiceMessageLabel => 'Röstmeddelande';

  @override
  String get replyIndicatorDocumentLabel => 'Dokument';

  @override
  String get replyIndicatorMessageRemoved => 'Meddelandet togs bort';

  @override
  String get threadOverlayMessageNotFound =>
      'Kunde inte hitta det meddelandet i den här tråden';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'Kunde inte hitta tråden att svara i';

  @override
  String get threadOverlayStillSending =>
      'Skickas fortfarande — försök igen om en stund';

  @override
  String get threadOverlayCopiedToast => 'Kopierat';

  @override
  String get threadOverlayNameCopiedToast => 'Namnet kopierat';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'Koordinaterna kopierade';

  @override
  String get threadOverlayPinLimitToast =>
      'För många nålade meddelanden — avnåla ett först';

  @override
  String get threadOverlayPinFailedToast => 'Kunde inte nåla det';

  @override
  String get threadOverlayReportedToast => 'Rapporterat';

  @override
  String get threadOverlayUnavailable => 'tråden är otillgänglig';

  @override
  String get roomInfoScreenNameRequiredError => 'Namn krävs';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'Lösenord borttaget';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'Lämna rummet?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'Du kan gå med igen om det förblir öppet.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'Lämna';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'Radera rummet?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'Alla meddelanden här försvinner med det. Det här är permanent.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'Radera';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      'Avsluta den här konversationen?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName förlorar också konversationen — alla meddelanden försvinner för er båda. Det här är permanent.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'Avsluta';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'Den andra personen';

  @override
  String get roomInfoScreenConfirmCancelButton => 'AVBRYT';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'Ett rum med det namnet finns redan';

  @override
  String get roomInfoScreenErrorNotOwner => 'Bara ägaren kan göra det';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'Du har inte behörighet';

  @override
  String get roomInfoScreenErrorRoomNotFound =>
      'Det här rummet finns inte längre';

  @override
  String get roomInfoScreenRoomGone => 'Rummet är borta';

  @override
  String get roomInfoScreenNameLabel => 'NAMN';

  @override
  String get roomInfoScreenNameHint => 'Rumsnamn';

  @override
  String get roomInfoScreenDescriptionLabel => 'BESKRIVNING';

  @override
  String get roomInfoScreenDescriptionHint => 'En rad om rummet';

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
  String get roomInfoScreenReplacePasswordHint => 'Byt lösenord';

  @override
  String get roomInfoScreenSetPasswordHint => 'Lås med ett lösenord';

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
  String get roomInfoScreenViewProfilePictureSemantic => 'Visa profilbild';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'Visa rumsbild';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'Ändra rumsbild';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'Lägg till rumsbild';

  @override
  String get roomInfoScreenOwnerBadge => 'ÄGARE';

  @override
  String get roomInfoScreenNoneCount => 'inga';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'Kameraåtkomst är avstängd.\nSlå på den i Inställningar för att ta ett foto.';

  @override
  String get cameraScreenOpeningSystemCamera => 'Öppnar systemkameran…';

  @override
  String get cameraScreenCloseButtonLabel => 'Stäng kameran';

  @override
  String get cameraScreenLowLightBoostOnLabel =>
      'Förstärkning för svagt ljus: på';

  @override
  String get cameraScreenLowLightBoostOffLabel =>
      'Förstärkning för svagt ljus: av';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'Blixt: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'Välj från bildbiblioteket';

  @override
  String get cameraScreenSwitchCameraLabel => 'Byt kamera';

  @override
  String get cameraScreenTakePhotoLabel => 'Ta foto';

  @override
  String get childPolicyScreenAddByUsernameLabel =>
      'Lägg till med användarnamn';

  @override
  String get childPolicyScreenAddCta => 'Lägg till';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'De får exakt samma befogenheter som du: varje förfrågan att godkänna, varje inställning att ändra och möjligheten att ta bort dig. $name ser dem som familj direkt.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'Lägg till en vuxen';

  @override
  String get childPolicyScreenAddGuardianHint => 'Deras användarnamn';

  @override
  String get childPolicyScreenAllowCta => 'Tillåt';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'Du kommer inte att tillfrågas om dem igen — oavsett om $childName lägger till dem eller de lägger till $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'Tillåt någon';

  @override
  String get childPolicyScreenAskToAddLabel => 'Be om lov';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'Bara familj — inga nya förfrågningar';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'De kan fråga dig om nya personer';

  @override
  String get childPolicyScreenBothFinalNote =>
      'Båda dessa är slutgiltiga. Att kliva åt sidan i stället finns under Vuxna längre upp.';

  @override
  String get childPolicyScreenCallsLabel => 'Samtal';

  @override
  String get childPolicyScreenCallsOffDesc => 'Bara meddelanden';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'Röst + video med tillåtna personer';

  @override
  String get childPolicyScreenCancelLabel => 'Avbryt';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Avbryt';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'Tillagd — förfrågan är på väg';

  @override
  String get childPolicyScreenContactAddedToList =>
      'Tillagd i listan över tillåtna';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'Skapa rum';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'De kan inte starta rum';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'De kan starta sina egna privata rum';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Allt försvinner: deras meddelanden, foton, rum och vänner. Detta kan inte ångras, och användarnamnet blir ledigt för vem som helst.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'Det gick inte att radera kontot — försök igen';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return 'Radera ${name}s konto?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Meddelanden, foton, rum och vänner försvinner allihop. Kan inte ångras.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'Radera ${name}s konto';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'Radera för alltid';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'Det gick inte att lägga till dem — försök igen';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'Det är deras eget användarnamn';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'Ett barn kan inte vara en vuxen';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'Det gick inte — försök igen';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'Någon måste ta hand om dem — lägg till en till vuxen först';

  @override
  String get childPolicyScreenErrorNotYours =>
      'Det där har du ingen rätt att ändra';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'Inget konto med det användarnamnet';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'De blir ett vanligt konto med det här lösenordet, och alla vuxna förlorar all insyn. Det finns ingen väg tillbaka — du skulle behöva bli inbjuden som vem som helst.';

  @override
  String get childPolicyScreenGraduateCta => 'Gör vuxen';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'De behåller allt och får ett lösenord. Du förlorar all insyn. Oåterkalleligt.';

  @override
  String get childPolicyScreenGraduateDangerLabel => 'Gör till vuxet konto';

  @override
  String get childPolicyScreenGraduateFailed =>
      'Kunde inte göra dem vuxna — försök igen';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'Gör $name vuxen';
  }

  @override
  String get childPolicyScreenGraduateHint => 'Ett lösenord för dem';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Att ta tillbaka ett rum tar också bort dem från det. Att ta tillbaka en person raderar även chatten — för dem båda.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Alla här kan godkänna, ändra inställningar och se allt. Vem som helst av dem kan agera på egen hand — ingen behöver vänta på de andra.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'Tillagd — hen kan ta hand om dem nu';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name borttagen';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (du)';
  }

  @override
  String get childPolicyScreenLoading => 'Laddar…';

  @override
  String get childPolicyScreenLockedLabel => 'Låst';

  @override
  String get childPolicyScreenMediaLabel => 'Bilder + röst';

  @override
  String get childPolicyScreenMediaOffDesc => 'Endast text';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'De kan skicka bilder, video och röstmeddelanden';

  @override
  String get childPolicyScreenNoRoomsYet => 'Inga rum än';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Vem som helst här kan läggas till utan att du tillfrågas igen — oavsett vem av dem som tar initiativet.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Alltid avstängt för barn. Upptäck — listan över rum som tillhör personer du inte känner — är helt dold och kan inte slås på. Rum som någon bjuder in dem till fungerar fortfarande som vanligt.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'Offentliga rum';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian kommer inte längre att se eller godkänna något för $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return 'Ta bort $name?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'Ta bort';

  @override
  String childPolicyScreenRoomMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return '$_temp0';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'Vuxna';

  @override
  String get childPolicyScreenSectionPeopleAllowed =>
      'Personer du har tillåtit';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'Rum du har tillåtit';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'Vad de kan göra';

  @override
  String get childPolicyScreenSectionWhenDone => 'När de är klara';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'Inget händer förrän någon lägger till den andra';

  @override
  String get childPolicyScreenSendNowOnDesc => 'De tillfrågas direkt';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'Skicka förfrågan nu';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'Du är ${name}s enda vuxna, så du kan inte bara kliva av — lägg till en till först, eller använd ett av dessa.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'Kliva av';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'Du förlorar all insyn i ${name}s konto — deras förfrågningar, deras kontakter, deras rum. De andra vuxna fortsätter att ta hand om dem.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'Sluta övervaka';

  @override
  String get childPolicyScreenStopSupervisingHeadline => 'Sluta övervaka?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'Kunde inte ta tillbaka det — försök igen';

  @override
  String get childPolicyScreenTakeBackLabel => 'Ta tillbaka';

  @override
  String get childPolicyScreenUsernameHint => 'Användarnamn';

  @override
  String get childPolicyScreenYou => 'Du';

  @override
  String get roomContentScreenDefaultDocumentName => 'Dokument';

  @override
  String get roomContentScreenCouldntOpenFile => 'Kunde inte öppna den filen';

  @override
  String get roomContentScreenCouldntShare => 'Kunde inte dela dem';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kopierade $count länkar',
      one: 'Kopierat',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Radera $count meddelanden',
      one: 'Radera meddelande',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Detta tar bort dem för alla i den här chatten. Det kan inte ångras.';

  @override
  String get roomContentScreenDeleteForEveryone => 'Radera för alla';

  @override
  String get roomContentScreenCancelTooltip => 'Avbryt';

  @override
  String get roomContentScreenBackTooltip => 'Tillbaka';

  @override
  String get roomContentScreenSelectingLabel => 'Väljer';

  @override
  String get roomContentScreenSharedContentLabel => 'Delat innehåll';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda',
      one: '$count vald',
      zero: 'Inget valt',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'Välj';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'Alla';

  @override
  String get roomContentScreenEmptyMedia => 'Inga foton eller videor än';

  @override
  String get roomContentScreenEmptyFiles => 'Inga filer än';

  @override
  String get roomContentScreenEmptyVoice => 'Inga röstmeddelanden än';

  @override
  String get roomContentScreenEmptyLinks => 'Inga länkar än';

  @override
  String get roomContentScreenEmptySaved =>
      'Inget sparat än. Håll in ett meddelande och välj Spara.\n\nDet du sparar här är bara ditt — ett fäst meddelande är det hela rummet ser.';

  @override
  String get roomContentScreenLoadFailed => 'Kunde inte läsa in det';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Röstmeddelande från $name';
  }

  @override
  String get roomContentScreenForwardAction => 'Vidarebefordra';

  @override
  String get roomContentScreenCopyAction => 'Kopiera';

  @override
  String get roomContentScreenSaveAction => 'Spara';

  @override
  String get roomContentScreenShareAction => 'Dela';

  @override
  String get roomContentScreenInChatAction => 'I chatten';

  @override
  String get roomContentScreenDeleteAction => 'Ta bort';

  @override
  String get messageActionMenuReplyLabel => 'Svara';

  @override
  String get messageActionMenuEditLabel => 'Redigera';

  @override
  String get messageStampEditedLabel => 'redigerat';

  @override
  String get composerEditCardTitle => 'Redigera meddelande';

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
  String get linkConfirmSheetTitle => 'Öppna den här länken?';

  @override
  String get linkConfirmSheetOpenLabel => 'Öppna länk';

  @override
  String get linkConfirmSheetCancelLabel => 'Avbryt';

  @override
  String get roomScreenEditExpiredSnack =>
      'För sent att redigera — meddelanden kan bara redigeras i 15 minuter.';

  @override
  String get roomScreenEditFailedSnack =>
      'Ändringen kunde inte sparas. Kontrollera din anslutning och försök igen.';

  @override
  String get messageActionMenuForwardLabel => 'Vidarebefordra';

  @override
  String get messageActionMenuViewThreadLabel => 'Visa tråd';

  @override
  String get messageActionMenuCopyLabel => 'Kopiera';

  @override
  String get messageActionMenuCopyNameLabel => 'Kopiera namn';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'Kopiera koordinater';

  @override
  String get messageActionMenuPinLabel => 'Fäst';

  @override
  String get messageActionMenuUnpinLabel => 'Lossa';

  @override
  String get messageActionMenuSelectLabel => 'Välj';

  @override
  String get messageActionMenuProfileLabel => 'Profil';

  @override
  String get messageActionMenuDeleteLabel => 'Ta bort';

  @override
  String get messageActionMenuReportLabel => 'Rapportera';

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
  String get callScreenStatusConnected => 'Ansluten';

  @override
  String get callScreenStatusEnded => 'Samtalet avslutades';

  @override
  String get callScreenStatusFailed => 'Samtalet misslyckades';

  @override
  String get callScreenStatusSwitching => 'Byter enhet…';

  @override
  String get callScreenStatusMoved => 'Flyttat';

  @override
  String get callScreenStatusReconnecting => 'Återansluter…';

  @override
  String get callScreenPoorConnectionLabel => 'Dålig anslutning';

  @override
  String get callScreenWeakConnectionLabel => 'Svag anslutning';

  @override
  String get callScreenControlUnmute => 'Ljud på';

  @override
  String get callScreenControlMute => 'Ljud av';

  @override
  String get callScreenControlCamOn => 'Kamera på';

  @override
  String get callScreenControlCamOff => 'Kamera av';

  @override
  String get callScreenControlFlip => 'Byt';

  @override
  String get callScreenControlSpeaker => 'Högtalare';

  @override
  String get callScreenControlEnd => 'Avsluta';

  @override
  String get linkPreviewCardLinkLabel => 'Länk';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name accepterade din förfrågan';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'Förfrågan drogs tillbaka';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'Förfrågan avvisades';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'Du har blockerat den här användaren — häv blockeringen först.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'De tar inte emot vänförfrågningar just nu.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'Kunde inte skicka. Försök igen.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel =>
      'Inkommande förfrågan';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'Ny förfrågan';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name vill starta en konversation.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'skriv några rader. de kan godkänna eller avvisa.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'Inget här sparas permanent förrän båda är överens.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'Rumstyp';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'Flyktigt';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'Standard';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'Livslängd';

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
      'Viska en första rad · valfritt';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'Lägg till ett första meddelande · valfritt';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'Viska · försvinner automatiskt';

  @override
  String get friendRequestDraftScreenHintStartWith => 'Något att börja med';

  @override
  String get friendRequestDraftScreenApproveButton => 'Godkänn och öppna rum';

  @override
  String get friendRequestDraftScreenDeclineButton => 'Avvisa';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'Avbryt förfrågan';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => 'Fråga en vuxen';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'Skicka förfrågan';

  @override
  String get discoverScreenTitle => 'upptäck.';

  @override
  String get discoverScreenCaptionPeople => 'personer';

  @override
  String get discoverScreenCaptionRooms => 'rum';

  @override
  String get discoverScreenCaptionRequests => 'förfrågningar';

  @override
  String get discoverScreenPeopleBandLabel => 'Personer';

  @override
  String get discoverScreenRoomsBandLabel => 'Rum';

  @override
  String get discoverScreenFindPeopleTitle => 'Hitta personer';

  @override
  String get discoverScreenFindPeopleSubtitleChild =>
      'Skriv ett helt användarnamn';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'Sök på @användarnamn eller namn';

  @override
  String get discoverScreenRequestsSectionLabel => 'Förfrågningar';

  @override
  String get discoverScreenInboxQuiet => 'Tyst i inkorgen';

  @override
  String get discoverScreenNothingPending => 'Inget skickat';

  @override
  String get discoverScreenYourPeopleLabel => 'Vänner';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'Ingen än — hitta personer ovan';

  @override
  String get discoverScreenNoFriendsYet => 'Ingen än';

  @override
  String get discoverScreenSearchRoomsTitle => 'Sök rum';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'Hitta ett offentligt rum via namn';

  @override
  String get discoverScreenYourRoomsLabel => 'Rum';

  @override
  String get discoverScreenNoRoomsYet => 'Inga rum än';

  @override
  String get discoverScreenIncomingLabel => 'Inkommande';

  @override
  String get discoverScreenOutgoingLabel => 'Utgående';

  @override
  String get discoverScreenIncomingLabelCaps => 'INKOMMANDE';

  @override
  String get discoverScreenOutgoingLabelCaps => 'UTGÅENDE';

  @override
  String get discoverScreenJumpPeopleLabel => 'Personer';

  @override
  String get discoverScreenJumpRoomsLabel => 'Rum';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Hoppa till $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'Justera';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'Använd foto';

  @override
  String get imageCropScreenSavingButton => 'Sparar…';

  @override
  String get imageCropScreenCancelButton => 'Avbryt';

  @override
  String get imageCropScreenHeicUnsupported =>
      'Den här webbläsaren kan inte öppna HEIC-foton';

  @override
  String get imageCropScreenLoadFailed => 'Kunde inte öppna bilden';

  @override
  String get imageCropScreenHintCircle =>
      'Dra för att flytta, nyp för att zooma';

  @override
  String get imageCropScreenHintRect => 'Dra och nyp för att rama in';

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
  String get searchScreenHintPeople => 'Sök personer';

  @override
  String get searchScreenHintRooms => 'Sök offentliga rum';

  @override
  String get searchScreenPeoplePromptChild =>
      'Skriv ett helt användarnamn för att hitta någon ny';

  @override
  String get searchScreenPeoplePromptDefault =>
      'sök efter användarnamn eller namn';

  @override
  String get searchScreenNoMatchChild =>
      'Ingen matchar — nya personer behöver sitt\nhela användarnamn, exakt stavat';

  @override
  String get searchScreenNoMatchDefault => 'Ingen matchar';

  @override
  String get searchScreenNoRoomsYet => 'Inga offentliga rum än';

  @override
  String get searchScreenNoRoomsMatch => 'Inga offentliga rum matchar';

  @override
  String get searchScreenActionAskToAdd => 'Fråga om lov';

  @override
  String get searchScreenActionSendRequest => 'Skicka förfrågan';

  @override
  String get searchScreenActionCancel => 'Avbryt';

  @override
  String get searchScreenActionApprove => 'Godkänn';

  @override
  String get searchScreenActionOpenDm => 'Öppna DM';

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
      'Kopierad — klistra in den på ett säkert ställe';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'Bekräfta\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'att det är du.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Ditt lösenord, så att ingen annan kan lägga till en återställningsfras på ditt konto.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'Lösenord';

  @override
  String get recoveryPhraseScreenContinueButton => 'FORTSÄTT';

  @override
  String get recoveryPhraseScreenNotNowLink => 'inte nu';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'Ange ditt lösenord.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'Spara\n';

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
  String get homeScreenEmptyRoomsMessage => 'Inga rum än — skapa ett';

  @override
  String get groupCallScreenTitleVideo => 'Gruppvideosamtal';

  @override
  String get groupCallScreenTitleVoice => 'Gruppröstsamtal';

  @override
  String groupCallScreenParticipantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count i samtalet',
      one: 'Bara du',
    );
    return '$_temp0';
  }

  @override
  String get groupCallScreenReconnecting => 'Återansluter…';

  @override
  String get groupCallScreenUnmuteLabel => 'Ljud på';

  @override
  String get groupCallScreenMuteLabel => 'Ljud av';

  @override
  String get groupCallScreenCamOnLabel => 'Kamera på';

  @override
  String get groupCallScreenCamOffLabel => 'Kamera av';

  @override
  String get groupCallScreenFlipLabel => 'Vänd';

  @override
  String get groupCallScreenSpeakerLabel => 'Högtalare';

  @override
  String get groupCallScreenLeaveLabel => 'Lämna';

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
  String get roomFilterDrawerClearLabel => 'Rensa';

  @override
  String get roomFilterDrawerDimensionType => 'Typ';

  @override
  String get roomFilterDrawerDimensionNature => 'Karaktär';

  @override
  String get roomFilterDrawerDimensionStatus => 'Status';

  @override
  String get roomFilterDrawerPanelClear => 'Rensa';

  @override
  String get roomFilterDrawerPanelDone => 'Klart';

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
    return 'Inget matchar $summary';
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
      other: 'Visa alla $count chattar',
      one: 'Visa alla $count chatt',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'Nytt rum';

  @override
  String get createRoomSheetTaglineSecret => 'Inget sparas';

  @override
  String get createRoomSheetTaglineRegular => 'En plats som stannar';

  @override
  String get createRoomSheetNameLabel => 'Namn';

  @override
  String get createRoomSheetNameHint => 'Ge det ett ärligt namn';

  @override
  String get createRoomSheetDescriptionLabel => 'Beskrivning · valfri';

  @override
  String get createRoomSheetDescriptionHint => 'En rad om rummet';

  @override
  String get createRoomSheetVisibilityLabel => 'Synlighet';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'Offentligt';

  @override
  String get createRoomSheetVisibilityPublicSub =>
      'Vem som helst kan hitta det';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'Privat';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'Endast med inbjudan';

  @override
  String get createRoomSheetTypeLabel => 'Typ';

  @override
  String get createRoomSheetTypeStandardTitle => 'Standard';

  @override
  String get createRoomSheetTypeStandardSub => 'Meddelanden sparas';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'Flyktig';

  @override
  String get createRoomSheetTypeEphemeralSub => 'Raderas automatiskt';

  @override
  String get createRoomSheetMessageLifeLabel => 'Meddelandets livslängd';

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
  String get createRoomSheetPasswordLabel => 'Lösenord · valfritt';

  @override
  String get createRoomSheetPasswordHint => 'Lås med en lösenfras';

  @override
  String get createRoomSheetNameRequiredError => 'Namn krävs';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Öppna rummet';

  @override
  String get createRoomSheetOpenRoomButton => 'Öppna rummet';

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
  String get reactionDetailsSheetTitle => 'Reaktioner';

  @override
  String get reactionDetailsSheetEmptyState => 'Inget kvar här längre';

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
  String get reactionDetailsSheetFilterAll => 'Alla';

  @override
  String get reactionDetailsSheetYouBadge => 'Du';

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
  String get audioMessageUnavailableLabel => 'Ljud otillgängligt';

  @override
  String get audioMessageRetryHint => 'Tryck för att försöka igen';

  @override
  String get audioMessageLoadingLabel => 'Laddar…';

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
  String get audioMessageUsernameHint => 'Användarnamn';

  @override
  String get audioMessageDisplayNameHint => 'Visningsnamn (valfritt)';

  @override
  String get audioMessagePasswordHint => 'Lösenord';

  @override
  String get audioMessageSwitchToLinkPrompt => 'Det kontot är mitt — logga in';

  @override
  String get audioMessageCreateAccountButton => 'Skapa konto';

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
  String get approvalsScreenForwardDirectMessageFallback => 'Direktmeddelande';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vidarebefordra $count meddelanden',
      one: 'Vidarebefordra meddelande',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'Inga andra chattar än';

  @override
  String get approvalsScreenForwardNoMatches => 'Inga träffar';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'Upp till $max chattar åt gången';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'Sök chattar';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Avmarkera $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Markera $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'Försvinner';

  @override
  String get approvalsScreenForwardSendSemantic => 'Skicka';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skicka till $count',
      zero: 'Skicka',
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
  String get linkedAccountsScreenCallSheetVoiceLabel => 'Röst';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'Video';

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
  String get profileScreenDeleteAccountFailed => 'Något gick fel. Försök igen.';

  @override
  String get childPairScreenAccountGoneError => 'Det kontot finns inte längre.';

  @override
  String get childPairScreenScanButtonLabel => 'SKANNA DERAS KOD';

  @override
  String get childPairScreenNoCameraMessage =>
      'Ingen kamera här — skriv in de sex siffrorna istället.';

  @override
  String get childPairScreenStopScanning => 'Sluta skanna';

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
  String get fileMessageStandardBadge => 'Standard';

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
  String get fileMessageApproveButton => 'Godkänn';

  @override
  String get fileMessageDeclineButton => 'Avvisa';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'Skickad $ago';
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
  String get fileMessageCancelRequestButton => 'Avbryt förfrågan';

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
  String get destructiveSheetPairingCodeExpired => 'Den här koden har gått ut';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'Går ut om $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'Ny kod';

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
  String get deepOceanThemeEphemeralHint => 'Viska något';

  @override
  String get deepOceanThemeDefaultHint => 'Säg något';

  @override
  String get deepOceanThemeMessageHint => 'Meddelande';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'Den här filen är borta';

  @override
  String get photoChromeMediaYouLabel => 'Du';

  @override
  String get photoChromeCloseSemanticLabel => 'Stäng';

  @override
  String get photoChromeFillToggleSemanticLabel => 'Anpassa eller fyll skärmen';

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
  String get photoTrayDiscardSemanticLabel => 'Kasta dessa foton';

  @override
  String get photoTrayRemoveSemanticLabel => 'Ta bort det här fotot';

  @override
  String get photoTrayEditSemanticLabel => 'Beskär eller rita på det här fotot';

  @override
  String get photoTrayAddMoreSemanticLabel => 'Lägg till fler foton';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'Du kan skicka $count foton åt gången';
  }

  @override
  String get photoTrayLoadFailedSnack =>
      'Några av de fotona gick inte att öppna';

  @override
  String get mediaPickFailedMessage => 'Kunde inte öppna — försök välja igen';

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
  String get typingIndicatorUnknownCallerFallbackName => 'Inkommande samtal';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'Inkommande videosamtal';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'Inkommande röstsamtal';

  @override
  String get typingIndicatorDeclineButtonLabel => 'Avvisa';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'Avvisar…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'Svara';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'Ansluter…';

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
      'Mikrofonåtkomst nekad';

  @override
  String get voiceRecorderScreenStatusRecording => 'Spelar in';

  @override
  String get voiceRecorderScreenStatusReady => 'Klar';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'Tryck för att starta';

  @override
  String get voiceRecorderScreenReRecordButton => 'Spela in igen';

  @override
  String get voiceRecorderScreenStopButton => 'Stoppa';

  @override
  String get voiceRecorderScreenSendButton => 'Skicka';

  @override
  String get voiceRecorderScreenRecordButton => 'Spela in';

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
  String get activeCallPillPinnedHeader => 'Fästa';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'Fästa · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'Inget är fäst längre';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Hoppa till meddelande från $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Lossa meddelande från $name';
  }

  @override
  String get callButtonErrorBusy => 'Upptagen i ett annat samtal';

  @override
  String get callButtonErrorCallFailed => 'Kunde inte starta samtalet';

  @override
  String get callButtonErrorNotMember => 'Inte medlem i det här rummet';

  @override
  String get callButtonErrorGeneric => 'Kunde inte starta samtalet';

  @override
  String get callButtonAlreadyOnCall => 'Du är redan i ett samtal';

  @override
  String get callButtonBusyElsewhere => 'Samtal pågår på en annan enhet';

  @override
  String get callButtonVoiceCallTooltip => 'Röstsamtal';

  @override
  String get callButtonVideoCallTooltip => 'Videosamtal';

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
  String get childSetupScreenWaitingPillAskedLabel => 'Frågat';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'MEDLEMMAR';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'Se alla $count';
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
      'Senaste meddelandet nyss';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'Senaste meddelandet för ${hours}h sedan';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'Senaste meddelandet igår';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'Senaste meddelandet för $days dagar sedan';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'Senaste meddelandet för ett tag sedan';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge =>
      'Ta tillbaka';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return 'Ska vi ta tillbaka $contactName från $childName?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'De kan inte längre nå varandra, och deras konversation försvinner också.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'De kan inte längre nå varandra. $contactName får inte veta det.';
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
      'Försvinner för båda, inklusive foton och röstmeddelanden. Detta kan inte ångras.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'De delar också $count rum',
      one: 'De delar också $count rum',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'De här ligger kvar. Ta tillbaka rummet från Rum-listan nedan om du vill bli av med dem.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'Ta tillbaka & radera';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'Tar bort $contactName och raderar $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'Tar bort $contactName från listan över tillåtna kontakter.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Avbryt';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => 'Avbryt';

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
  String get groupCallBannerJoinButtonLabel => 'Anslut';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'Anslut till rum';

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
  String get groupCallBannerPasswordFieldLabel => 'Lösenord';

  @override
  String get groupCallBannerPasswordHint => 'Lösenfras';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Anslut';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'Anslut';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Avbryt';

  @override
  String get groupCallBannerCancelButtonLabel => 'Avbryt';

  @override
  String get viewOnceViewerBadgeLabel => 'Visas en gång';

  @override
  String get socialButtonDividerOr => 'eller';

  @override
  String get socialButtonGoogleContinue => 'Fortsätt med Google';

  @override
  String get discoverListsPeopleTitle => 'Vänner';

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
  String get discoverListsFilterHint => 'Sök vänner';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Rensa filter';

  @override
  String get discoverListsNoOneYet => 'Ingen än';

  @override
  String discoverListsNoMatches(Object query) {
    return 'Ingen matchar \"$query\"';
  }

  @override
  String get discoverListsRoomsTitle => 'Rum';

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
  String get discoverListsFilterRoomsHint => 'Sök bland dina rum';

  @override
  String get discoverListsNoRoomsYet => 'Inga rum än';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return 'Inga rum matchar \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'RÖSTSAMTAL';

  @override
  String get discoverListsVideoCallLabel => 'VIDEOSAMTAL';

  @override
  String get approvalGateAlreadyAskedLabel => 'Redan frågat';

  @override
  String get approvalGateAskGrownUpLabel => 'Fråga en vuxen';

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
  String get approvalGateAskButton => 'Fråga';

  @override
  String get approvalGateNotNowButton => 'INTE NU';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => 'Väntar på en vuxen';

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
  String get reportSheetUpdateRequiredTitle => 'Uppdatering krävs';

  @override
  String get reportSheetUpdateAvailableTitle => 'Uppdatering tillgänglig';

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
  String get reportSheetUpdateButtonTitle => 'Uppdatera';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'Öppnar TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'Öppnar App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'Öppnar Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'Öppnar nedladdningssidan';

  @override
  String get reportSheetUpdateActionReloads =>
      'Laddar om med den nya versionen';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Senare';

  @override
  String get reportSheetUpdateLaterButton => 'Senare';

  @override
  String get roomFilterBarAllChipLabel => 'Alla';

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
    return 'Svarar på $name';
  }

  @override
  String get roomCardLockedBadge => 'Låst';

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
    return 'Skapat för $ago sedan';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count inne';
  }

  @override
  String get roomCardMessagesFadeLabel => 'Meddelanden bleknar';

  @override
  String get roomCardEnterLabel => '↗ Gå in';

  @override
  String get roomCardBlockedScreenTitle => 'BLOCKERADE';

  @override
  String get roomCardBlockedEmptyState => 'du har inte blockerat någon.';

  @override
  String get roomCardUnblockButton => 'AVBLOCKERA';

  @override
  String get attachmentMenuPhotoLabel => 'Foto';

  @override
  String get attachmentMenuVideoLabel => 'Video';

  @override
  String get attachmentMenuCameraLabel => 'Kamera';

  @override
  String get attachmentMenuVoiceLabel => 'Röst';

  @override
  String get attachmentMenuFileLabel => 'Fil';

  @override
  String get attachmentMenuConnectionRetrying => 'Försöker igen…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'Kan inte nå servern · Tryck för att försöka igen';

  @override
  String get attachmentMenuConnectionReconnecting => 'Återansluter…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Försök ansluta igen';

  @override
  String get roomGridTileEmptyLastMessage => 'tyst hittills';

  @override
  String get roomGridTileMemberCountLabel => 'Inne';

  @override
  String get roomGridTileThemeChipLabel => 'TEMA';

  @override
  String get bulkActionBarCancelLabel => 'Avbryt';

  @override
  String get bulkActionBarSelectMessagesLabel => 'Välj meddelanden';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count valda';
  }

  @override
  String get bulkActionBarForwardLabel => 'Vidarebefordra';

  @override
  String get bulkActionBarDeleteLabel => 'Radera';

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
      'De får ingen avisering.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'Ni är vänner just nu — att blockera tar bort vänskapen, så för att återansluta senare behöver du skicka en ny vänförfrågan.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'De försvinner från dina sökresultat och kan inte skicka meddelanden till dig.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'Blockera';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return 'Blockera $name?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Du delar $count rum med dem',
      one: 'Du delar $count rum med dem',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'De här rummen förblir orörda. Du kan själv lämna dem via varje rums inställningar.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'Blockera';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'Tar bort vänskapen och blockerar. Befintlig chatthistorik finns kvar i ditt arkiv.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'De döljs från sökningar och kan inte nå dig.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'Blockera & radera DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'Raderar även din DM med dem — alla meddelanden, reaktioner och mediafiler försvinner.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Avbryt';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'Avbryt';

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
  String get reactionBubblePickerTitle => 'Reagera';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'Inga senaste än';

  @override
  String get reactionBubbleSearchHint => 'Sök emoji';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'Inga träffar';

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
      'Kunde inte fråga just nu — försök igen';

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
  String get feedBoardHighlightsLabel => 'Höjdpunkter';

  @override
  String get feedBoardHighlightsEmpty => 'Inget fångat idag än';

  @override
  String get feedBoardPuzzleLabel => 'PUSSLET';

  @override
  String get feedBoardPuzzleEmpty => 'dagens pussel är inte klart än';

  @override
  String get feedBoardStandingsLabel => 'Livspoäng';

  @override
  String get feedBoardStandingsEmpty => 'Inga poäng på tavlan idag';

  @override
  String get feedBoardActivityLabel => 'Aktivitet';

  @override
  String get feedBoardActivityEmpty => 'lugnt hittills idag';

  @override
  String get feedBoardActivityNoFriends =>
      'Lägg till en vän så dyker deras dag upp här';

  @override
  String get feedBoardLoadFailed =>
      'Kunde inte ladda tavlan — försök igen om en stund';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'Offentlig';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'Privat';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'Medlem';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'Flyktig · $duration';
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
  String get roomInfoSheetNoDescription => 'Ingen beskrivning än';

  @override
  String get roomInfoSheetCreatedLabel => 'Skapad';

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
      'Ingen återställningsfras — du kan bli utelåst för gott.';

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
  String get roomContentTabLabelMedia => 'Media';

  @override
  String get roomContentTabLabelFiles => 'Filer';

  @override
  String get roomContentTabLabelVoice => 'Röst';

  @override
  String get roomContentTabLabelLinks => 'Länkar';

  @override
  String get roomContentTabLabelSaved => 'Sparade';

  @override
  String get roomContentTabHeaderMedia => 'Media';

  @override
  String get roomContentTabHeaderFiles => 'Filer';

  @override
  String get roomContentTabHeaderVoice => 'Röst';

  @override
  String get roomContentTabHeaderLinks => 'Länkar';

  @override
  String get roomContentTabHeaderSaved => 'Sparade';

  @override
  String get roomFacetLabelDms => 'DM';

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
  String get settingsScreenSectionCompanions => 'FÖLJESLAGARE';

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
  String get reportProblemDescribeLabel => 'Vad hände';

  @override
  String get reportProblemDescribeHint =>
      'Skärmen flimrar, knappar svarar inte';

  @override
  String get reportProblemScreenshotsLabel => 'Skärmbilder';

  @override
  String get reportProblemAddScreenshot => 'Lägg till skärmbild';

  @override
  String get reportProblemDetailsLabel => 'Dina uppgifter';

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
  String get settingsScreenMenuBarLabel => 'MENYRADSIKON';

  @override
  String get settingsScreenMenuBarOnBody =>
      'MonkeyHub ligger i menyraden med antalet olästa — klicka för att ta fram fönstret';

  @override
  String get settingsScreenMenuBarOffBody =>
      'avstängd just nu — Dock-ikonen är enda vägen tillbaka till ett dolt fönster';

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
  String get glassKnobLabelFrost => 'Frostning';

  @override
  String get glassKnobHintFrost =>
      'Hur mycket vitt som ligger på glaset. Lägre för mer genomskinligt';

  @override
  String get glassKnobLabelBlur => 'Oskärpa';

  @override
  String get glassKnobHintBlur =>
      'Frostat i toppen av skalan, klart glas i botten';

  @override
  String get glassKnobLabelSaturation => 'Färgläckage';

  @override
  String get glassKnobHintSaturation =>
      'Hur mycket färg som överlever oskärpan. Efter 2 posteriseras den';

  @override
  String get glassKnobLabelRimOpacity => 'Kant';

  @override
  String get glassKnobHintRimOpacity =>
      'Glaskantens ljusstyrka. Noll för en yta utan kant';

  @override
  String get glassKnobLabelRimWidth => 'Kantbredd';

  @override
  String get glassKnobHintRimWidth => 'Tjockleken på den konturen';

  @override
  String get glassKnobLabelShadowOpacity => 'Skugga';

  @override
  String get glassKnobHintShadowOpacity =>
      'Hur högt ytan svävar över det som ligger bakom';

  @override
  String get glassKnobLabelShadowBlur => 'Skuggspridning';

  @override
  String get glassKnobHintShadowBlur => 'Mjuk och bred, eller tät och hård';

  @override
  String get glassKnobLabelShadowY => 'Skuggfall';

  @override
  String get glassKnobHintShadowY => 'Hur långt under ytan den faller';

  @override
  String get glassKnobLabelBarMargin => 'Sidomarginal';

  @override
  String get glassKnobHintBarMargin =>
      'Avståndet mellan fältet och skärmens kant';

  @override
  String get glassKnobLabelBarBottom => 'Bottenavstånd';

  @override
  String get glassKnobHintBarBottom => 'Hur högt fältet svävar över botten';

  @override
  String get glassKnobLabelShellPadH => 'Ändpadding';

  @override
  String get glassKnobHintShellPadH =>
      'Från fältets kant till den första kapseln. Håll den liten, annars ser ändarna övergivna ut';

  @override
  String get glassKnobLabelShellPadV => 'Toppadding';

  @override
  String get glassKnobHintShellPadV =>
      'Från fältets kant till toppen av kapseln';

  @override
  String get glassKnobLabelIndicatorInset => 'Kapselindrag';

  @override
  String get glassKnobHintIndicatorInset =>
      'Hur långt in urvalskapseln sitter i sitt fack';

  @override
  String get glassKnobLabelSegmentPadV => 'Radpadding';

  @override
  String get glassKnobHintSegmentPadV =>
      'Luft ovanför och under ikonen och dess etikett';

  @override
  String get glassKnobLabelIconLabelGap => 'Ikonavstånd';

  @override
  String get glassKnobHintIconLabelGap =>
      'Avståndet mellan en ikon och ordet under den';

  @override
  String get glassKnobLabelIconSize => 'Ikonstorlek';

  @override
  String get glassKnobLabelLabelSize => 'Etikettstorlek';

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
  String get settingsScreenValueMotionSystemFull => 'Följ enheten · Full';

  @override
  String get settingsScreenValueMotionSystemCalm => 'Följ enheten · Lugn';

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
  String get momentRailCaptureLabel => 'Fånga';

  @override
  String get momentRailYouLabel => 'Du';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String get momentTagFate => 'Öde';

  @override
  String get momentTagJinx => 'Otur';

  @override
  String get momentTagLuck => 'Tur';

  @override
  String get momentTagCalledIt => 'Vad var det jag sa';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'Vilket sammanträffande';

  @override
  String get momentTagJinxHint => 'Det där gjorde du mot dig själv';

  @override
  String get momentTagLuckHint => 'Det gick din väg';

  @override
  String get momentTagCalledItHint => 'Du såg det komma';

  @override
  String get momentTagNpcHint => 'Hjärnan helt avstängd';

  @override
  String get momentComposerTitle => 'Nytt ögonblick';

  @override
  String get momentComposerCaptionHint => 'Säg något om det';

  @override
  String get momentComposerTagPrompt => 'vunnit en poäng? lägg till den';

  @override
  String get momentComposerCapture => 'Kamera';

  @override
  String get momentComposerLibrary => 'Galleri';

  @override
  String get momentComposerRemovePhoto => 'Ta bort foto';

  @override
  String get momentComposerPost => 'Publicera';

  @override
  String get momentComposerErrorDailyCap =>
      'Det blev fem idag — spara något till imorgon';

  @override
  String get momentComposerErrorNotAllowed =>
      'En vårdnadshavare har stängt av fotodelning';

  @override
  String get momentComposerErrorTooLong => 'Lite väl långt — korta ner';

  @override
  String get momentComposerErrorEmpty => 'Lägg till ett foto eller några ord';

  @override
  String get momentComposerErrorGeneric => 'Kunde inte publicera — försök igen';

  @override
  String get momentViewerDelete => 'Radera';

  @override
  String get momentViewerDeleteConfirmHeadline => 'Radera det här?';

  @override
  String get momentViewerDeleteConfirmBody =>
      'Den försvinner från allas tavla och från ditt arkiv, för alltid';

  @override
  String get momentViewerDeleteFailed => 'Kunde inte radera — försök igen';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who lade upp ett ögonblick';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name fick en poäng: $tag';
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
  String get puzzleScreenSubtitle => 'Fyra symboler, sex försök';

  @override
  String get puzzleSubmit => 'Gissa';

  @override
  String get puzzleBackspace => 'Radera sista symbolen';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'Symbol $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'Löst på $count';
  }

  @override
  String get puzzleFailedTitle => 'Slut på försök';

  @override
  String get puzzleAnswerWas => 'Koden var';

  @override
  String get puzzleShare => 'Kopiera resultat';

  @override
  String get puzzleShareCopied => 'Kopierat — klistra in till en vän';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'Du har redan löst dagens';

  @override
  String get puzzleErrorOutOfGuesses => 'Inga försök kvar idag';

  @override
  String get puzzleErrorGeneric => 'Kunde inte skicka — försök igen';

  @override
  String get puzzleGuessWaiting =>
      'Ingen anslutning. Din gissning är sparad och skickas när du är tillbaka';

  @override
  String get gameSubmitWaiting =>
      'Ingen anslutning. Din färdiga bräda är sparad och skickas när du är tillbaka';

  @override
  String get puzzleScoreboardLabel => 'Dagens resultat';

  @override
  String get puzzleScoreboardEmpty => 'Ingen har blivit klar idag än';

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
  String get momentComposerVideo => 'Video';

  @override
  String get momentComposerErrorTooBig => 'Videon är för stor — max 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => 'Du lade upp ett ögonblick';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'Du fick en poäng: $tag';
  }

  @override
  String pointLineSelf(Object tag) {
    return 'Du · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'Vad hände?';

  @override
  String get pointComposerNoteHint => 'Välj en ovan och berätta';

  @override
  String get pointComposerAdd => 'Lägg till en poäng';

  @override
  String get pointComposerAddPhoto => 'lägg till foto';

  @override
  String get pointsBoardAdd => 'Lägg till en poäng';

  @override
  String get pointsExplainerOpen => 'Vad är det här?';

  @override
  String get pointsExplainerTitle => 'Poängleken';

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
  String get pointsExplainerGotIt => 'Jag fattar';

  @override
  String get momentTagFateExample =>
      'Sprang på min tandläkare i ett annat land';

  @override
  String get momentTagJinxExample => 'Tvättade bilen, det regnade vid fyra';

  @override
  String get momentTagLuckExample => 'Hann tåget med två sekunder till godo';

  @override
  String get momentTagCalledItExample =>
      'Sa att uppföljaren skulle floppa, den floppade';

  @override
  String get momentTagNpcExample => 'Sa ‘detsamma’ till servitören';

  @override
  String feedBoardEditionHint(Object number) {
    return 'Dag $number av flödet';
  }

  @override
  String get feedBoardHighlightsHint => 'foton och videor värda en titt';

  @override
  String get profileVisibilityScreenPointsLabel => 'mina poäng';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'om poängen du noterar syns på vännernas tavlor';

  @override
  String get momentComposerEditPhoto => 'Redigera beskärning';

  @override
  String get archiveScreenTitle => 'Ditt arkiv';

  @override
  String get archiveScreenEnd => 'Det var allt';

  @override
  String get archiveScreenEmptyTitle => 'Inget sparat än';

  @override
  String get archiveScreenEmptyBody =>
      'Ögonblick lämnar vännernas tavlor efter ett dygn, men de stannar här för dig.';

  @override
  String get archiveScreenEmptyFriendTitle => 'Inget här';

  @override
  String get archiveScreenEmptyFriendBody =>
      'Har inte lagt upp något du kan se än.';

  @override
  String get archiveScreenPrivateTitle => 'Deras förflutna är privat';

  @override
  String get archiveScreenPrivateBody =>
      'Du ser fortfarande det som läggs upp idag.';

  @override
  String get archiveScreenNotFriendTitle => 'Ni är inte vänner';

  @override
  String get archiveScreenNotFriendBody =>
      'Du kan bara bläddra bakåt bland en väns dagar.';

  @override
  String get archiveScreenErrorTitle => 'Kunde inte laddas';

  @override
  String get archiveScreenErrorBody => 'Kolla anslutningen och försök igen.';

  @override
  String get feedBoardOpenArchive => 'Arkiv';

  @override
  String get feedBoardGamesLabel => 'Spel';

  @override
  String get feedBoardGamesOpen => 'Topplista';

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
  String get gamesLoadFailed => 'Kunde inte ladda dagens spel';

  @override
  String get gamesRetry => 'Försök igen';

  @override
  String get gameQueensName => 'Damer';

  @override
  String get gameQueensRule =>
      'En krona per rad, kolumn och färg — aldrig intill varandra';

  @override
  String get gameTangoName => 'Tango';

  @override
  String get gameTangoRule => 'tre solar, tre månar, aldrig tre i rad';

  @override
  String get gameZipName => 'Zip';

  @override
  String get gameZipRule => 'en linje genom varje ruta, siffrorna i ordning';

  @override
  String get gameSudokuName => 'Minisudoku';

  @override
  String get gameSudokuRule => '1 till 6 en gång per rad, kolumn och ruta';

  @override
  String get gameCodeName => 'Koden';

  @override
  String get gameStatusUnplayed => 'Ospelad';

  @override
  String get gameStatusUnfinished => 'Pågår';

  @override
  String get gameStatusGaveUp => 'Gav upp';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'Pausa';

  @override
  String get gameResume => 'Fortsätt';

  @override
  String get gamePausedTitle => 'Pausat';

  @override
  String get gamePausedBody => 'Klockan är stoppad och brickan dold';

  @override
  String get gameUndo => 'Ångra';

  @override
  String get gameClear => 'rensa';

  @override
  String get gameHint => 'Ledtråd';

  @override
  String get gameNotes => 'anteckningar';

  @override
  String get gameErase => 'sudda';

  @override
  String get gameAutoCross => 'Autokryss';

  @override
  String get gameGiveUp => 'Ge upp';

  @override
  String get gameGiveUpTitle => 'Visa lösningen?';

  @override
  String get gameGiveUpBody => 'Dagens bricka stängs och räknas som olöst.';

  @override
  String get gameGiveUpCancel => 'Fortsätt';

  @override
  String get gameGiveUpConfirm => 'Visa';

  @override
  String gameSolvedTitle(Object time) {
    return 'Löst på $time';
  }

  @override
  String get gameGaveUpTitle => 'Dagens lösning';

  @override
  String get gameFirstInToday => 'Först idag';

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
  String get gameStandingsLabel => 'Dagens tider';

  @override
  String get gameStandingsEmpty => 'Ingen har klarat den än';

  @override
  String get gameShare => 'Kopiera resultat';

  @override
  String get gameShareCopied => 'Kopierat — klistra in till en vän';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => 'Alla spel';

  @override
  String get gameElapsedSemantic => 'Förfluten tid';

  @override
  String get gameErrorNotSolved => 'Brickan är inte klar än';

  @override
  String get gameErrorAlreadyFinished => 'Du har redan klarat dagens';

  @override
  String get gameErrorNoHint => 'Ingen ledtråd för den här';

  @override
  String get gameErrorGeneric => 'Kunde inte nå spelen — försök igen';

  @override
  String get gameInfoOpen => 'Så spelar du';

  @override
  String get gameInfoLabel => 'Så spelar du';

  @override
  String get gameInfoRulesLabel => 'Reglerna';

  @override
  String get gameInfoControlsLabel => 'Vad du trycker på';

  @override
  String get gameInfoScoringTimed =>
      'Snabbast vinner. Klockan stannar när du lämnar.';

  @override
  String get gameInfoScoringGuesses =>
      'Färst gissningar vinner. Tiden räknas inte.';

  @override
  String get gameInfoSameForEveryone => 'Alla får samma pussel i dag.';

  @override
  String get gameInfoQueensGoal => 'Placera 8 kronor på brädet.';

  @override
  String get gameInfoQueensRule1 => 'Varje rad får exakt 1 krona.';

  @override
  String get gameInfoQueensRule2 => 'Varje kolumn får exakt 1 krona.';

  @override
  String get gameInfoQueensRule3 => 'Varje färg får exakt 1 krona.';

  @override
  String get gameInfoQueensControls =>
      'Tryck en gång: × (ingen krona här). Två gånger: krona. Igen: rensa.';

  @override
  String get gameInfoTangoGoal => 'Fyll varje ruta med en sol eller en måne.';

  @override
  String get gameInfoTangoRule1 => 'Varje rad har 3 solar och 3 månar.';

  @override
  String get gameInfoTangoRule2 => 'Varje kolumn har 3 solar och 3 månar.';

  @override
  String get gameInfoTangoRule3 => 'Aldrig 3 likadana i rad. 2 går bra.';

  @override
  String get gameInfoTangoControls =>
      'Tryck en gång: sol. Två gånger: måne. Igen: rensa. Rutor som är ifyllda från början går inte att ändra.';

  @override
  String get gameInfoZipGoal => 'Dra ett enda streck genom alla rutor.';

  @override
  String get gameInfoZipRule1 => 'Börja på 1.';

  @override
  String get gameInfoZipRule2 => 'Besök talen i ordning: 1, 2, 3…';

  @override
  String get gameInfoZipRule3 => 'Fyll alla rutor. Varje ruta bara en gång.';

  @override
  String get gameInfoZipControls =>
      'Dra med fingret för att rita. Dra tillbaka för att ångra.';

  @override
  String get gameInfoSudokuGoal => 'Fyll rutnätet med talen 1 till 6.';

  @override
  String get gameInfoSudokuRule1 =>
      'Varje rad har 1, 2, 3, 4, 5 och 6. Inga dubbletter.';

  @override
  String get gameInfoSudokuRule2 => 'Varje kolumn också.';

  @override
  String get gameInfoSudokuRule3 =>
      'Varje box också. En box är 2 rader gånger 3 kolumner.';

  @override
  String get gameInfoSudokuControls =>
      'Tryck på en ruta, sedan på en siffra. Tryck igen för att sudda. Anteckningar ger små blyertsmärken.';

  @override
  String get gameInfoCodeGoal => 'Gissa den hemliga koden med 4 symboler.';

  @override
  String get gameInfoCodeRule1 =>
      'Koden har 4 olika symboler. Inga dubbletter.';

  @override
  String get gameInfoCodeRule2 => 'Du får 6 gissningar.';

  @override
  String get gameInfoCodeRule3 => 'Grön: rätt symbol, rätt plats.';

  @override
  String get gameInfoCodeControls => 'Tryck på 4 symboler och sedan på Gissa.';

  @override
  String get savedMessagesTitle => 'Sparade meddelanden';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'ingen chatt matchar \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'Sök chattar';

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
  String get archivedChatsSheetTitle => 'Arkiverade chattar';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'Arkiverade chattar · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'Inget är arkiverat längre';

  @override
  String get pinnedBadgeLabel => 'FÄST';

  @override
  String get chatRowActionMenuPinLabel => 'Fäst chatten';

  @override
  String get chatRowActionMenuUnpinLabel => 'Lossa chatten';

  @override
  String get chatRowActionMenuArchiveLabel => 'Arkivera chatten';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'Avarkivera chatten';

  @override
  String get messageActionMenuSaveLabel => 'Spara';

  @override
  String get messageActionMenuUnsaveLabel => 'Ta bort';

  @override
  String get roomScreenSaveLimitSnack =>
      'För många sparade här — ta bort en först';

  @override
  String get roomScreenSaveFailedSnack => 'Kunde inte spara det';

  @override
  String get threadOverlaySaveLimitToast =>
      'För många sparade här — ta bort en först';

  @override
  String get threadOverlaySaveFailedToast => 'Kunde inte spara det';

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
  String get muteSheetTitle => 'Tysta chatten';

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
  String get muteSheetDurationLabel => 'Hur länge';

  @override
  String get muteDurationHour => '1 timme';

  @override
  String get muteDurationEightHours => '8 timmar';

  @override
  String get muteDurationWeek => '1 vecka';

  @override
  String get muteDurationAlways => 'Alltid';

  @override
  String get muteSheetConfirmButton => 'Tysta';

  @override
  String get muteSheetSaveButton => 'Spara';

  @override
  String get muteSheetUnmuteButton => 'Slå på ljud';

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
  String get chatRowActionMenuMuteLabel => 'Tysta chatten';

  @override
  String get chatRowActionMenuUnmuteLabel => 'Slå på ljud för chatten';

  @override
  String get roomInfoScreenMuteLabel => 'TYSTA';

  @override
  String get roomInfoScreenNotMutedRow => 'Inte tystad';

  @override
  String get attachmentMenuLocationLabel => 'Plats';

  @override
  String get locationSheetSendCurrent => 'Skicka nuvarande plats';

  @override
  String get locationSheetSendCurrentDetail => 'Där du är just nu';

  @override
  String get locationSheetLiveHeading => 'Dela live';

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
      'De kan dela var de är, även live i upp till 8 timmar';

  @override
  String get childPolicyScreenLocationOffDesc => 'De kan inte dela var de är';

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
  String get videoNoteMessagePlayLabel => 'Spela upp videonotis';

  @override
  String get videoNoteMessagePauseLabel => 'Pausa videonotis';

  @override
  String get videoNoteMessageLoadingLabel => 'Laddar videonotis';

  @override
  String get videoNoteMessageUnavailableLabel =>
      'Videonotis är inte tillgänglig';

  @override
  String get videoNoteMessageRetryLabel => 'Försök med videonotisen igen';

  @override
  String get videoNoteMessageRetryHint => 'Tryck för att försöka igen';

  @override
  String get videoNoteMessageDiscardLabel => 'Kasta videonotisen';

  @override
  String get attachmentMenuVideoNoteLabel => 'Videonotis';

  @override
  String get cameraScreenPhotoModeLabel => 'Foto';

  @override
  String get cameraScreenVideoModeLabel => 'Video';

  @override
  String get cameraScreenStartRecordingLabel => 'Starta inspelning';

  @override
  String get cameraScreenStopRecordingLabel => 'Stoppa inspelning';

  @override
  String get cameraScreenVideoFailedSnack =>
      'Det gick inte att spela in videon.';

  @override
  String get scheduleSheetTitle => 'Schemalägg meddelande';

  @override
  String get scheduleSheetSubtitle =>
      'Skriv det nu. Det går iväg när du säger till.';

  @override
  String get scheduleSheetWhenLabel => 'När';

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
  String get scheduleSheetConfirmButton => 'Schemalägg';

  @override
  String get scheduleSheetSaveButton => 'Spara';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'Skickas $when';
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
  String get scheduleTimePickerTitle => 'Välj datum och tid';

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
  String get scheduledListTitle => 'Schemalagda';

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
  String get scheduleEditTitle => 'Ändra meddelande';

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
  String get scheduledListShowAs => 'Visa som';

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
      'Där ditt konto och dina meddelanden finns';

  @override
  String get serverOnboardingTitle => 'välj en server.';

  @override
  String get serverOnboardingSubtitle =>
      'Den här versionen kom utan server – peka den mot din';

  @override
  String get serverStatusConnected => 'Ansluten';

  @override
  String get serverStatusDisconnected => 'Ej ansluten';

  @override
  String get serverBadgeDefault => 'Standard';

  @override
  String get serverBadgeSelfHosted => 'Egen server';

  @override
  String get serverNoneConfigured => 'Ingen server ännu';

  @override
  String get serverActiveNowLabel => 'Används';

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
  String get serverAddressPaste => 'Klistra in';

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
  String get serverInsecureTitle => 'Okrypterad';

  @override
  String get serverInsecureBody =>
      'Telefoner blockerar okrypterad http, så den här adressen ansluter inte på iOS eller Android. Använd https, eller nå din server via en tunnel.';

  @override
  String get serverTestCta => 'Testa anslutningen';

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
  String get serverConnectCta => 'Anslut';

  @override
  String get serverConnectAnywayCta => 'Anslut ändå';

  @override
  String get serverAlreadyConnectedCta => 'Redan ansluten';

  @override
  String get serverUseDefaultCta => 'Använd standardservern';

  @override
  String get serverChangeCta => 'Byt server';

  @override
  String get serverAdvancedLabel => 'Avancerat';

  @override
  String get serverSiteUrlExplain =>
      'De flesta servrar svarar på allt via en adress. Fyll bara i det här om din levererar HTTP-actions någon annanstans.';

  @override
  String get serverSiteUrlHint => 'Samma som ovan';

  @override
  String get serverSectionRecent => 'Senaste';

  @override
  String get serverRecentForget => 'Glöm den här servern';

  @override
  String get serverSwitchWarningTitle => 'Byte loggar ut dig';

  @override
  String get serverSwitchWarningBody =>
      'Konton och chattar hör till en enda server. Den här enheten loggas ut, rensar det den laddat ner och börjar om. Inget raderas på någon av servrarna.';

  @override
  String get serverSwitchRolledBackTitle => 'Kunde inte ansluta';

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
  String get serverRoleExplainAction => 'Vad betyder det här?';

  @override
  String get serverBadgeRibbonHomeserver => 'HEM';

  @override
  String get serverBadgeRibbonSelfHosted => 'EGEN';

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
  String get loginScreenUsePasswordInstead => 'Använd lösenord i stället';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      'Öppna MonkeyHub på telefonen, gå till din profil, tryck på ”Skanna för att logga in” och rikta kameran hit – eller skriv koden nedan.';

  @override
  String get deviceLoginScreenWaiting => 'Väntar på godkännande…';

  @override
  String get deviceLoginScreenApproved => 'Godkänt – loggar in dig…';

  @override
  String get deviceLoginScreenDenied => 'Inloggningen nekades på din telefon';

  @override
  String get deviceLoginScreenGenericError =>
      'Något gick fel – prova en ny kod';

  @override
  String get profileScreenScanToSignInLabel => 'Skanna för att logga in';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro =>
      'Rikta kameran mot koden på datorn eller skriv in den nedan.';

  @override
  String get deviceLoginScanScreenScanButtonLabel => 'Skanna kod';

  @override
  String get deviceLoginScanScreenConfirmTitle =>
      'Logga in på den här enheten?';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return '$deviceInfo vill logga in som du. Godkänn bara om det är du, just nu.';
  }

  @override
  String get deviceLoginScanScreenApproveButton => 'Godkänn';

  @override
  String get deviceLoginScanScreenDenyButton => 'Neka';

  @override
  String get deviceLoginScanScreenSuccess => 'Inloggad på din andra enhet';

  @override
  String get deviceLoginScanScreenGenericError =>
      'Kunde inte godkänna – försök igen';

  @override
  String get authErrorDeviceLoginInvalid => 'Den koden stämmer inte.';

  @override
  String get authErrorDeviceLoginExpired =>
      'Koden har gått ut – hämta en ny på den andra enheten.';

  @override
  String get deviceLoginScanScreenDeniedConfirmation =>
      'Inloggningsförfrågan nekad';

  @override
  String get roomAdminRoleAdmin => 'Admin';

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
  String get roomAdminTransferConfirmCta => 'Överlåt';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return 'Ta bort $name?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'Personen förlorar åtkomst till gruppen och allt i den. Hen kan bjudas in igen, eller komma tillbaka via inbjudningslänken.';

  @override
  String get roomAdminRemoveConfirmCta => 'Ta bort';

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
  String get roomInviteCreateButton => 'Skapa länk';

  @override
  String get roomInviteRegenerateButton => 'Ny länk';

  @override
  String get roomInviteRevokeButton => 'Spärra länken';

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
  String get roomInviteRegenerateConfirm => 'Ny länk';

  @override
  String get roomInviteRevokeHeadline => 'Spärra den här länken?';

  @override
  String get roomInviteRevokeBody =>
      'Ingen ny kan gå med via länk förrän du gör en till. Alla som redan är med är kvar.';

  @override
  String get roomInviteRevokeConfirm => 'Spärra';

  @override
  String get roomInviteLimitsLabel => 'Gränser';

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
  String get roomInvitePermissionsLabel => 'Behörigheter';

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
    return 'Slutar gälla $date';
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
  String get roomInviteFriendsInviteButton => 'Bjud in';

  @override
  String get roomInviteFriendsSent => 'Inbjuden';

  @override
  String get roomInviteFriendsEmpty =>
      'Alla dina vänner är redan här eller redan inbjudna.';

  @override
  String get roomInviteFriendsNoMatch => 'Ingen vän matchar det.';

  @override
  String get roomInviteFriendsDone => 'Klar';

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
  String get roomInfoScreenInviteAwaitingGuardian => 'Väntar på en förälder';

  @override
  String get roomInfoScreenInviteWithdraw => 'ÅTERKALLA';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return 'Från $inviter · $members medlemmar';
  }

  @override
  String get roomInvitationCardJoin => 'Gå med';

  @override
  String get discoverScreenJoinByCodeTitle => 'Gå med via kod';

  @override
  String get discoverScreenJoinByCodeSubtitle =>
      'Öppna en grupp som någon delat med dig';

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
  String get joinInviteLookupButton => 'Fortsätt';

  @override
  String get joinInviteLookupFailed =>
      'Kunde inte kolla koden. Kolla din uppkoppling och försök igen.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count medlemmar';
  }

  @override
  String get joinInviteJoinButton => 'Gå med i gruppen';

  @override
  String get joinInviteRequestButton => 'Be att få gå med';

  @override
  String get joinInviteOpenNote =>
      'Du ser gruppens meddelanden så fort du gått med.';

  @override
  String get joinInviteApprovalNote =>
      'En admin måste säga ja innan du kan se något här inne.';

  @override
  String get joinInviteOpenRoom => 'Öppna gruppen';

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
  String get roomAdminYouSuffix => 'Du';

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
  String get newChatMenuJoinSub => 'Öppna en grupp som delats med dig';

  @override
  String get shareSheetTitle => 'Dela med';

  @override
  String get shareSheetSuggestedHeading => 'Förslag';

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
  String get attachmentMenuPollLabel => 'Omröstning';

  @override
  String get attachmentMenuChecklistLabel => 'Lista';

  @override
  String get attachmentMenuEventLabel => 'Händelse';

  @override
  String get interactionKindPoll => 'Omröstning';

  @override
  String get interactionKindQuiz => 'Quiz';

  @override
  String get interactionKindChecklist => 'Lista';

  @override
  String get interactionKindEvent => 'Händelse';

  @override
  String get interactionBadgeAnonymous => 'Anonym';

  @override
  String get interactionBadgeMultiple => 'Flera';

  @override
  String get interactionBadgeClosed => 'Stängd';

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
  String get interactionRespondentsTitlePoll => 'Vilka röstade';

  @override
  String get interactionRespondentsTitleChecklist => 'Vilka bockade av';

  @override
  String get interactionRespondentsTitleEvent => 'Vilka svarade';

  @override
  String get interactionRespondentsFailed =>
      'Kunde inte hämta vilka som svarat.';

  @override
  String get interactionRespondentsEmpty => 'Ingen har svarat än.';

  @override
  String get interactionFilterAll => 'Alla';

  @override
  String get interactionRsvpGoing => 'Kommer';

  @override
  String get interactionRsvpMaybe => 'Kanske';

  @override
  String get interactionRsvpNo => 'Kan inte';

  @override
  String get interactionComposePollTitle => 'Ny omröstning';

  @override
  String get interactionComposePollTagline => 'Fråga rummet';

  @override
  String get interactionComposeChecklistTitle => 'Ny lista';

  @override
  String get interactionComposeChecklistTagline => 'En lista alla kan bocka av';

  @override
  String get interactionComposeEventTitle => 'Ny händelse';

  @override
  String get interactionComposeEventTagline => 'Se vilka som kommer';

  @override
  String get interactionComposeQuestionLabel => 'Fråga';

  @override
  String get interactionComposeQuestionHint => 'Vad vill du fråga?';

  @override
  String get interactionComposeTitleLabel => 'Titel';

  @override
  String get interactionComposeTitleHint => 'Vad är listan till för?';

  @override
  String get interactionComposeEventNameLabel => 'Händelse';

  @override
  String get interactionComposeEventNameHint => 'Vad händer?';

  @override
  String get interactionComposeOptionsLabel => 'Alternativ';

  @override
  String get interactionComposeItemsLabel => 'Punkter';

  @override
  String interactionComposeOptionHint(int index) {
    return 'Alternativ $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return 'Punkt $index';
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
  String get interactionComposeMultipleTitle => 'Flera svar';

  @override
  String get interactionComposeMultipleSub => 'Välj mer än ett';

  @override
  String get interactionComposeAnonymousTitle => 'Anonym';

  @override
  String get interactionComposeAnonymousOffSub => 'Alla ser vilka som röstat';

  @override
  String get interactionComposeAnonymousOnSub => 'Ingen ser vilka som röstat';

  @override
  String get interactionComposeQuizTitle => 'Quizläge';

  @override
  String get interactionComposeQuizSub => 'Ett rätt svar, går inte att ändra';

  @override
  String get interactionComposeExplanationLabel => 'Förklaring';

  @override
  String get interactionComposeExplanationHint =>
      'Visas efter svaret (valfritt)';

  @override
  String get interactionComposeOthersMayCheckTitle => 'Alla får bocka av';

  @override
  String get interactionComposeOthersMayCheckSub => 'Inte bara du';

  @override
  String get interactionComposeOthersMayAddTitle => 'Alla får lägga till';

  @override
  String get interactionComposeOthersMayAddSub => 'Listan kan växa senare';

  @override
  String get interactionComposeWhenLabel => 'När';

  @override
  String get interactionComposePickStart => 'Välj en start';

  @override
  String get interactionComposePickEnd => 'Lägg till ett slut (valfritt)';

  @override
  String get interactionComposePlaceLabel => 'Plats';

  @override
  String get interactionComposePlaceHint => 'Var? (valfritt)';

  @override
  String get interactionComposeSendPoll => 'Skicka omröstningen';

  @override
  String get interactionComposeSendChecklist => 'Skicka listan';

  @override
  String get interactionComposeSendEvent => 'Skicka händelsen';

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

  @override
  String get messageReceiptsScreenTitle => 'Meddelandeinfo';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$read av $total har läst';
  }

  @override
  String get messageReceiptsEmptyState =>
      'Det finns ingen annan i det här rummet än';

  @override
  String get messageReceiptsSectionRead => 'Läst';

  @override
  String get messageReceiptsSectionDelivered => 'Levererat';

  @override
  String get messageReceiptsSectionSent => 'Skickat';

  @override
  String get messageReceiptsSectionHidden => 'Ingen kvittens';

  @override
  String get messageReceiptsStateHidden => 'Delas inte';

  @override
  String get messageReceiptsStateWaiting => 'Väntar';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name läste det här $day kl. $time';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name fick det här $day kl. $time';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name har inte fått det här än';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name delar inte läskvitton';
  }

  @override
  String get companionsScreenTitle => 'följeslagare.';

  @override
  String get companionsScreenSubtitle =>
      'hjälpredor som bor i den här telefonen och aldrig skickar något vidare';

  @override
  String get companionSebastianTagline => 'Översätter meddelanden';

  @override
  String get companionSebastianBlurb =>
      'Sebastian läser ett meddelande på ett annat språk och berättar vad det står — här i telefonen, utan att något skickas någonstans.';

  @override
  String get companionMarloweTagline => 'Allmän hjälp';

  @override
  String get companionMarloweBlurb =>
      'Marlowe sköter allt som inte är översättning. Välj en hjärna nu, så kommer färdigheterna efter hand.';

  @override
  String get companionAssuranceOnDevice => 'Körs helt på den här enheten';

  @override
  String get companionAssurancePrivate =>
      'Dina meddelanden lämnar aldrig telefonen';

  @override
  String get companionAssuranceOffline => 'Fungerar utan uppkoppling';

  @override
  String companionInstallAction(Object size) {
    return 'Installera · $size';
  }

  @override
  String get companionInstallOneTime =>
      'Engångsnedladdning, sparas tills du tar bort den';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$received av $total';
  }

  @override
  String get companionInstallQueued =>
      'Väntar på att en annan nedladdning ska bli klar';

  @override
  String get companionInstallCancel => 'Avbryt';

  @override
  String get companionInstallRetry => 'Försök igen';

  @override
  String companionInstallReady(Object name) {
    return '$name är redo';
  }

  @override
  String get companionInstallFailedNetwork =>
      'Nedladdningen kunde inte slutföras. Kontrollera anslutningen och försök igen.';

  @override
  String get companionInstallFailedStorage =>
      'Det finns inte tillräckligt med utrymme på enheten. Frigör lite och försök igen.';

  @override
  String get companionInstallFailedUnknown =>
      'Nedladdningen kunde inte slutföras.';

  @override
  String get companionUnsupportedPlatform =>
      'Följeslagare är inte tillgängliga i den här versionen av appen än.';

  @override
  String companionBrainNeedsMemory(String size) {
    return 'Kräver $size minne';
  }

  @override
  String get sebastianTierSeniorDetail => 'Skarpare översättningar';

  @override
  String get sebastianTierJuniorDetail => 'Fungerar på alla telefoner';

  @override
  String get sebastianLanguageUnlisted =>
      'Inte ett av hans språk – räkna med grova resultat';

  @override
  String get companionStatusNotInstalled => 'Inte installerad';

  @override
  String get companionStatusOff => 'Av';

  @override
  String companionStatusTranslatingInto(Object language) {
    return 'Översätter till $language';
  }

  @override
  String get companionStatusNoBrain => 'Inget nedladdat än';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nedladdningar redo',
      one: '1 nedladdning redo',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty =>
      'Inget nedladdat — följeslagarna tar ingen plats';

  @override
  String companionStorageUsed(Object size) {
    return 'Följeslagarna använder $size';
  }

  @override
  String get companionSectionGeneral => 'Allmänt';

  @override
  String get companionSectionStorage => 'Lagring';

  @override
  String get companionBrainRemove => 'Ta bort';

  @override
  String companionBrainRemoveTitle(Object name) {
    return 'TA BORT $name?';
  }

  @override
  String companionRemoveTitle(Object name) {
    return 'TA BORT $name?';
  }

  @override
  String companionRemoveMessage(Object size) {
    return 'Det frigör $size. Du kan ladda ner den igen när du vill.';
  }

  @override
  String get companionRemoveConfirm => 'Ta bort';

  @override
  String get sebastianEnableLabel => 'Låt Sebastian översätta';

  @override
  String get sebastianEnableDetail =>
      'Stäng av för att stoppa honom utan att radera nedladdningen';

  @override
  String get sebastianLanguageSection => 'Översätt till';

  @override
  String get sebastianLanguageFollowApp => 'Samma som appen';

  @override
  String sebastianBrainDetail(Object size) {
    return 'På den här enheten · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count översättningar sparade',
      one: '1 översättning sparad',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => 'Rensa';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe kan inte göra något än — färdigheterna är på väg. Det du kan göra nu är att ha en hjärna redo, så att inget väntar på en nedladdning när de landar.';

  @override
  String get marloweBrainsSection => 'Hjärna';

  @override
  String get marloweBrainsCaption =>
      'Större tänker bättre och svarar långsammare. Du kan behålla flera och byta mellan dem.';

  @override
  String get marloweBrainTierSwift => 'Snabb';

  @override
  String get marloweBrainTierBalanced => 'Balanserad';

  @override
  String get marloweBrainTierDeep => 'Djup';

  @override
  String get translationSlabShowOriginal => 'Visa originalet';

  @override
  String get translationSlabFailed =>
      'Det här meddelandet kunde inte översättas.';

  @override
  String get translationSlabRetry => 'Försök igen';

  @override
  String translationSlabByCompanion(Object name) {
    return 'Översatt av $name';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return 'Från $language';
  }

  @override
  String get messageActionMenuTranslateLabel => 'Översätt';

  @override
  String get messageActionMenuShowOriginalLabel => 'Visa originalet';

  @override
  String get roomTranslateTitle => 'Översätt den här chatten';

  @override
  String get roomTranslateStopTitle => 'Sluta översätta';

  @override
  String get roomTranslateSectionLabel => 'ÖVERSÄTTNING';

  @override
  String get roomTranslateOnRow => 'Översätter den här chatten';

  @override
  String get roomTranslateOffRow => 'Av';

  @override
  String get roomTranslateNeedsSetUp => 'Konfigurera Sebastian';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'Sebastian översätter · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return 'Läser på $language';
  }

  @override
  String get roomTranslateStop => 'STOPPA';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return 'Redan på $language';
  }

  @override
  String get roomScreenTranslateRoomOffer =>
      'Översätta resten av chatten också?';

  @override
  String get roomScreenTranslateRoomOfferAction => 'Översätt allt';

  @override
  String get settingsScreenCompanionsOff => 'Av';

  @override
  String get settingsScreenCompanionsUnavailable => 'Otillgängligt';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return 'Används även av $name';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return '$name använder samma nedladdning och förlorar den också.';
  }

  @override
  String get companionBrainInUse => 'Aktiv';

  @override
  String companionStatusUsingBrain(Object name) {
    return 'Använder $name';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name fortsätter laddas ner — Inställningar › Följeslagare';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return 'Laddar ner · $percent %';
  }

  @override
  String get companionInstallPause => 'Pausa';

  @override
  String get companionInstallResume => 'Återuppta';

  @override
  String get companionInstallDiscard => 'Kasta';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return 'Pausad · $received av $total';
  }

  @override
  String get companionInstallFailedIntegrity =>
      'Den nedladdade filen matchade inte vad den här versionen väntar sig. Börjar om.';

  @override
  String companionBannerDownloading(
    Object name,
    Object received,
    Object total,
  ) {
    return '$name · $received av $total';
  }

  @override
  String companionBannerPaused(Object name, Object received, Object total) {
    return '$name pausad · $received av $total';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name vaknar…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => 'Översätt igen';

  @override
  String get groupCallScreenShareLabel => 'Dela';

  @override
  String get groupCallScreenStopShareLabel => 'Sluta dela';

  @override
  String get groupCallScreenShareStartingLabel => 'Startar…';

  @override
  String get groupCallScreenRingingLabel => 'Ringer…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name delar sin skärm';
  }

  @override
  String get groupCallScreenYouAreSharing => 'Du delar din skärm';

  @override
  String get groupCallScreenMinimizeLabel => 'Dölj';

  @override
  String get groupCallScreenDrawLabel => 'Rita';

  @override
  String get callScreenControlShare => 'Dela';

  @override
  String get callScreenControlStopShare => 'Stoppa';

  @override
  String get callScreenControlShareStarting => 'Startar…';

  @override
  String get screenShareStopDrawing => 'Sluta rita';

  @override
  String get callScreenControlDraw => 'Rita';

  @override
  String get callScreenControlMinimize => 'Dölj';

  @override
  String get inCallPillOngoingCall => 'Samtal pågår';

  @override
  String get inCallPillReturn => 'Tillbaka';

  @override
  String get inCallPillSharing => 'Delar din skärm';

  @override
  String get inCallPillDrawSemanticLabel => 'Rita på den delade skärmen';

  @override
  String get inCallPillStopSharingSemanticLabel => 'Sluta dela';

  @override
  String get screenShareUnsupported =>
      'Skärmdelning finns inte på den här enheten';

  @override
  String get screenShareEphemeralWarning =>
      'Skärmbildsskyddet är av medan du delar';

  @override
  String get screenShareNotificationTitle => 'Delar din skärm';

  @override
  String get screenShareNotificationBody => 'Alla i samtalet kan se den';

  @override
  String get screenShareNotificationStop => 'Stoppa';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name delar redan';
  }

  @override
  String get screenShareFailed => 'Kunde inte börja dela';

  @override
  String get screenSharePickerTitle => 'Dela din skärm';

  @override
  String get screenSharePickerScreens => 'Skärmar';

  @override
  String get screenSharePickerWindows => 'Fönster';

  @override
  String get screenSharePickerEmpty =>
      'Inget att dela än — tillåt skärminspelning i Systeminställningar och försök igen';

  @override
  String get gameTellFriends => 'Berätta för vänner';

  @override
  String get gameToldFriends => 'Vännerna vet';

  @override
  String get gameTellFriendsTitle => 'Berätta för dina vänner?';

  @override
  String get gameTellFriendsBody =>
      'de får en avisering med det här resultatet. kan bara skickas en gång.';

  @override
  String get gameTellFriendsCancel => 'Inte nu';

  @override
  String get gameTellFriendsConfirm => 'Skicka';

  @override
  String get gameTellFriendsSent => 'Skickat — de vet';

  @override
  String get gameTellFriendsPrivate =>
      'Dina dagsresultat är privata, ingen skulle se det här';

  @override
  String get gameTellFriendsFailed => 'Kunde inte skicka';

  @override
  String get settingsScreenFriendActivityLabel => 'VÄNNERS AKTIVITET';

  @override
  String get settingsScreenFriendActivityOnBody =>
      'ögonblick, poäng och resultat när de läggs upp';

  @override
  String get settingsScreenFriendActivityOffBody =>
      'inget — deras tavlor finns kvar när du tittar';

  @override
  String get searchScreenActionWithGrownUp => 'Hos en vuxen';

  @override
  String get newChatMenuSearchHint => 'Sök bland dina vänner';

  @override
  String get newChatMenuNoFriendsYet => 'Inga vänner än — hitta folk i Upptäck';

  @override
  String get newChatMenuNoFriendsMatch => 'Ingen vän matchar';

  @override
  String get newChatMenuOpenDmFailed =>
      'Kunde inte öppna den chatten — försök igen';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'Välj bland dina personer';

  @override
  String get childPolicyScreenPickPersonHint =>
      'Sök på namn eller användarnamn';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'Ingen kvar att lägga till bland dina vänner —\\nsök efter någon annan';

  @override
  String get childPolicyScreenPickPersonNoMatch => 'Ingen matchar';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'Dina vänner';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'Alla andra';

  @override
  String get childPolicyScreenAddRoomLabel => 'Lägg till ett rum';

  @override
  String get childPolicyScreenPickRoomHeading => 'Lägg till ett rum';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'Ett av dina egna rum. $name går med direkt och kan läsa och skriva där tills du tar tillbaka det.';
  }

  @override
  String get childPolicyScreenPickRoomHint => 'Sök bland dina rum';

  @override
  String get childPolicyScreenPickRoomEmpty => 'Inga rum kvar att lägga till';

  @override
  String get childPolicyScreenPickRoomNoMatch => 'Inget rum matchar';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name är nu i $room';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'Kunde inte lägga till det rummet — försök igen';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'Det rummet kan inte läggas till så här';

  @override
  String get childPolicyScreenErrorRoomGone => 'Det rummet finns inte längre';

  @override
  String get newChatMenuFriendsHeader => 'Vänner';

  @override
  String get roomChangeErrorGone =>
      'Förslaget är borta — en admin kan ha svarat på det.';

  @override
  String get roomChangeErrorNotYours =>
      'Bara den som föreslog det kan ta tillbaka det.';

  @override
  String get roomChangeErrorNoChange => 'Det står redan så.';

  @override
  String get roomChangeErrorMissingValue => 'Det går inte att spara så här.';

  @override
  String get roomChangeRequestsTitle => 'Förslag';

  @override
  String get roomChangeRequestsBlurb =>
      'Medlemmar har föreslagit det här. Inget ändras förrän du säger ja.';

  @override
  String get roomChangeRequestsEmpty => 'Inga förslag.';

  @override
  String get roomChangeRequestsApprove => 'TA DEN';

  @override
  String get roomChangeRequestsReject => 'NEJ';

  @override
  String get roomChangeRequestsPhotoLabel => 'Ny gruppbild';

  @override
  String get roomChangeRequestsNameLabel => 'Nytt namn';

  @override
  String get roomChangeRequestsDescriptionLabel => 'Ny beskrivning';

  @override
  String get roomChangeRequestsUnknownLabel =>
      'En ändring appen inte kan visa än';

  @override
  String get roomChangeRequestsClearedValue => 'Inget — ta bort den';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name föreslog';
  }

  @override
  String get roomAdminChangeRequestsRow => 'Förslag';

  @override
  String get roomInfoScreenSuggestNote => 'En admin måste godkänna det här';

  @override
  String get roomInfoScreenSuggestAvatarNote => 'En admin godkänner nya bilder';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic => 'Föreslå en gruppbild';

  @override
  String get roomInfoScreenSuggestionSentToast => 'Skickat till adminerna';

  @override
  String get roomInfoScreenSuggestionAppliedToast =>
      'Klart — du kan redigera gruppen';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => 'Tillbakataget';

  @override
  String get roomInfoScreenSuggestionsLabel => 'DU FÖRESLOG';

  @override
  String get roomInfoScreenSuggestionPhoto => 'En ny gruppbild';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return 'Namn: $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return 'Beskrivning: $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => 'En ändring';

  @override
  String get roomInfoScreenSuggestionPending => 'Väntar på en admin';

  @override
  String get roomInfoScreenSuggestionWithdraw => 'Ta tillbaka';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name föreslog en ny gruppbild';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name föreslog ett nytt namn';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name föreslog en ny beskrivning';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count förslag väntar på dig',
      one: '$count förslag väntar på dig',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => 'Granska';

  @override
  String get roomSuggestionBannerSemantic =>
      'Medlemsförslag som väntar på din granskning';

  @override
  String get gameInfoPlay => 'Spela';

  @override
  String get gameInfoContinue => 'Fortsätt';

  @override
  String get gameInfoSeeResult => 'Se ditt resultat';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return 'Levererat till $delivered av $total';
  }

  @override
  String get messageReceiptsSentLabel => 'Skickat';

  @override
  String messageReceiptsSemanticDeliveredThenRead(
    Object deliveredDay,
    Object deliveredTime,
    Object name,
    Object readDay,
    Object readTime,
  ) {
    return '$name fick det här $deliveredDay kl. $deliveredTime och läste det $readDay kl. $readTime';
  }

  @override
  String get messageReceiptsStampRead => 'Läst';

  @override
  String get messageReceiptsStampDelivered => 'Levererat';

  @override
  String get roomInviteCustom => 'Annat';

  @override
  String roomInviteCustomHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count timmar',
      one: '$count timme',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar',
      one: '$count dag',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gånger',
      one: '$count gång',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => 'Timmar';

  @override
  String get roomInviteUnitDays => 'Dagar';

  @override
  String get roomInviteStepperIncrease => 'Öka';

  @override
  String get roomInviteStepperDecrease => 'Minska';

  @override
  String get recordsLabel => 'Genom tiderna';

  @override
  String get recordsBlurb => 'Det bästa någon har gjort — du och dina vänner';

  @override
  String recordsYourBest(Object value) {
    return 'Ditt $value';
  }

  @override
  String get recordsNoneYet => 'Ingen än';

  @override
  String get recordsEmpty => 'Lös valfritt spel så hamnar ditt bästa här.';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lösta',
      one: '$count löst',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return 'Satt $date';
  }

  @override
  String recordsReactSemantic(Object name) {
    return 'Reagera på ${name}s rekord';
  }

  @override
  String get recordsReactFailed => 'Det gick inte att reagera';

  @override
  String get recordsLoadFailed => 'Det gick inte att läsa in rekorden';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game: rekord $value av $name';
  }

  @override
  String get appearanceLabel => 'Utseende';

  @override
  String get appearanceMatchDevice => 'Som enheten';

  @override
  String get appearanceMatchDeviceSub =>
      'Ljust på dagen, mörkt på natten — som din telefon';

  @override
  String get appearanceOneTheme => 'Ett tema';

  @override
  String get appearanceOneThemeSub => 'Samma utseende hela dagen';

  @override
  String get appearanceLightSlot => 'Ljust läge';

  @override
  String get appearanceDarkSlot => 'Mörkt läge';

  @override
  String get appearanceNow => 'Nu';

  @override
  String appearanceAutoValue(Object name) {
    return 'Auto · $name';
  }

  @override
  String get themeScreenAssignHint =>
      'tryck på ett tema för att använda det i ljust eller mörkt läge · ⛶ för förhandsvisning';

  @override
  String get themeScreenCarouselUseLight => 'ANVÄND I LJUST LÄGE';

  @override
  String get themeScreenCarouselUseDark => 'ANVÄND I MÖRKT LÄGE';

  @override
  String get themeScreenCarouselIsLight => 'DITT LJUSA TEMA';

  @override
  String get themeScreenCarouselIsDark => 'DITT MÖRKA TEMA';

  @override
  String get onboardingThemeTitle => 'gör den till din.';

  @override
  String get onboardingThemeBody =>
      'välj ett utseende. du kan ändra det när som helst i inställningarna.';

  @override
  String get onboardingThemeYourTheme => 'DITT TEMA';

  @override
  String get onboardingThemeContinue => 'FORTSÄTT';

  @override
  String get dropHintNoTarget => 'Släpp på en chatt för att skicka';

  @override
  String get dropNothingToSend => 'Inget här går att skicka';

  @override
  String dropSendPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skicka $count foton',
      one: 'Skicka foto',
    );
    return '$_temp0';
  }

  @override
  String dropSendVideos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skicka $count videor',
      one: 'Skicka video',
    );
    return '$_temp0';
  }

  @override
  String dropSendAudio(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skicka $count ljudfiler',
      one: 'Skicka ljud',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skicka $count filer',
      one: 'Skicka fil',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Skicka $count objekt',
      one: 'Skicka objekt',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => 'Lägg till i meddelandet';

  @override
  String get dropSendLink => 'Lägg till länk';

  @override
  String dropTargetTo(String name) {
    return 'Till $name';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filer är över $size',
      one: '1 fil är över $size',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => 'Mappar går inte att skicka';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hoppar över $count tomma filer',
      one: 'Hoppar över en tom fil',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => 'Bilagor är inte tillåtna här';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count skickas som filer',
      one: 'Skickas som fil',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visas kanske inte överallt',
      one: 'Visas kanske inte överallt',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => 'foto';

  @override
  String get dropKindVideo => 'video';

  @override
  String get dropKindAudio => 'ljud';

  @override
  String get dropKindFile => 'fil';

  @override
  String get dropKindFolder => 'mapp';

  @override
  String get dropKindText => 'text';

  @override
  String get dropKindLink => 'länk';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filer fick inte plats i den här sändningen',
      one: '1 fil fick inte plats i den här sändningen',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed => 'Det gick inte. Försök igen.';

  @override
  String get expressionBackspace => 'Radera';

  @override
  String get expressionCreateSticker => 'Gör ett klistermärke';

  @override
  String get expressionDeleteSticker => 'Ta bort från mina klistermärken';

  @override
  String get expressionFavorite => 'Lägg till i favoriter';

  @override
  String get expressionFavorited => 'Tillagd i favoriter';

  @override
  String get expressionFavorites => 'Favoriter';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF: $title';
  }

  @override
  String get expressionLoadFailed => 'Kunde inte ladda. Kolla din anslutning.';

  @override
  String get expressionMediaNotAllowed =>
      'Dina familjeinställningar tillåter inte att du skickar bilder.';

  @override
  String get expressionMyStickers => 'Mina klistermärken';

  @override
  String get expressionNoFavorites =>
      'Tryck länge på en GIF eller ett klistermärke för att lägga till i favoriter.';

  @override
  String get expressionNoRecents =>
      'GIF:ar och klistermärken du skickar visas här.';

  @override
  String get expressionNoResults => 'Inga resultat';

  @override
  String get expressionNoStickers => 'Inga klistermärken här än.';

  @override
  String get expressionOpenPanel => 'Emoji, GIF:ar och klistermärken';

  @override
  String get expressionOptionsHint => 'Visa alternativ';

  @override
  String expressionPackCredit(String author, String license) {
    return 'Bild: $author · $license';
  }

  @override
  String get expressionPlayGifHint => 'spela upp';

  @override
  String get expressionRecent => 'Senaste';

  @override
  String get expressionReport => 'Rapportera';

  @override
  String get expressionReported => 'Tack – den är rapporterad.';

  @override
  String get expressionRetry => 'Försök igen';

  @override
  String get expressionSearchKlipy => 'Sök på KLIPY';

  @override
  String get expressionShowKeyboard => 'Visa tangentbord';

  @override
  String get expressionSuggestionsLabel => 'Förslag på klistermärken';

  @override
  String get expressionTabEmoji => 'Emoji';

  @override
  String get expressionTabGifs => 'GIF:ar';

  @override
  String get expressionTabStickers => 'Klistermärken';

  @override
  String get expressionTrending => 'Populärt';

  @override
  String get expressionUnfavorite => 'Ta bort från favoriter';

  @override
  String get expressionUnfavorited => 'Borttagen från favoriter';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return 'Klistermärke $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel =>
      'Spela upp GIF:ar och klistermärken automatiskt';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      'De står still tills du trycker på en. Sparar data.';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'GIF:ar och animerade klistermärken spelas upp av sig själva. Minska rörelse pausar dem.';

  @override
  String get settingsStickerSuggestionsBody =>
      'Skriver du en enda emoji visas matchande klistermärken ovanför meddelandefältet.';

  @override
  String get settingsStickerSuggestionsLabel => 'Förslag på klistermärken';

  @override
  String get stickerMakerEmojiLabel => 'Vilken emoji är det?';

  @override
  String get stickerMakerFailed =>
      'Kunde inte spara klistermärket. Försök igen.';

  @override
  String get stickerMakerMoreEmoji => 'Fler emoji';

  @override
  String get stickerMakerPreview => 'Förhandsvisning av klistermärke';

  @override
  String get stickerMakerRemoveBackground => 'Ta bort bakgrund';

  @override
  String get stickerMakerSave => 'Spara';

  @override
  String get stickerMakerSaved =>
      'Klistermärket har lagts till i Mina klistermärken';

  @override
  String get stickerMakerShape => 'Form';

  @override
  String get stickerMakerShapeCircle => 'Cirkel';

  @override
  String get stickerMakerShapeOriginal => 'Original';

  @override
  String get stickerMakerShapeRounded => 'Rundad kvadrat';

  @override
  String get stickerMakerTitle => 'Nytt klistermärke';

  @override
  String get stickerMakerTooMany =>
      'Du har nått gränsen för klistermärken. Ta bort ett för att göra plats.';

  @override
  String get expressionExpandPanel => 'Expandera panelen';

  @override
  String get expressionCollapsePanel => 'Minska panelen';

  @override
  String get expressionPackStore => 'Klistermärkespaket';

  @override
  String get expressionPackSearchHint => 'Sök klistermärkespaket';

  @override
  String get expressionPacksAdded => 'Tillagda';

  @override
  String get expressionPacksMore => 'Fler paket';

  @override
  String get expressionPackAdd => 'Lägg till';

  @override
  String get expressionPackRemove => 'Ta bort';

  @override
  String expressionPackStickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klistermärken',
      one: '1 klistermärke',
    );
    return '$_temp0';
  }

  @override
  String get expressionNoPacksFound => 'Inga paket matchar';

  @override
  String get expressionAllPacksAdded => 'Du har lagt till alla paket.';

  @override
  String expressionPackReorder(String title) {
    return 'Ändra ordning på $title';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return 'Lägg till paketet ”$title”';
  }

  @override
  String expressionPackAddedToast(String title) {
    return '”$title” har lagts till i dina klistermärken';
  }

  @override
  String get expressionPacksFromKlipy => 'Fler klistermärken från KLIPY';

  @override
  String expressionSearchKlipyFor(String query) {
    return 'Sök ”$query” på KLIPY';
  }

  @override
  String get expressionHideKeyboard => 'Dölj tangentbordet';

  @override
  String get expressionSearchStickers => 'Sök klistermärken';

  @override
  String get expressionYourStickers => 'Dina klistermärken';

  @override
  String get chatListYesterday => 'Igår';

  @override
  String get roomLayoutScreenCardsLayoutLabel => 'KORT';

  @override
  String get roomLayoutScreenCardsLayoutDescription =>
      'varje rum på ett eget kort, varje detalj utskriven.';

  @override
  String get homeScreenTitle => 'Chattar';

  @override
  String get glassScreenNativeLabel => 'iOS Liquid Glass';

  @override
  String get glassScreenNativeOnBody =>
      'Flikfältet ritas av iOS själv. Reglagen nedan justerar resten av appen.';

  @override
  String get glassScreenNativeOffBody =>
      'MonkeyHub ritar sitt eget glas överallt, justerat med reglagen nedan.';

  @override
  String get glassScreenHeading => 'Glas';

  @override
  String get glassStyleHeader => 'Stil';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody =>
      'Apples eget glas, ritat av iOS. Knapparna i appen matchar det.';

  @override
  String get glassStyleFrostedTitle => 'Frostat';

  @override
  String get glassStyleFrostedBody =>
      'MonkeyHubs eget glas. Forma varje reglage själv.';

  @override
  String get glassStyleRecommended => 'Rekommenderas';

  @override
  String get glassStyleLiquidFooter =>
      'Inget att justera: iOS styr oskärpa, ton och ljus. Välj Frostat för att forma glaset själv.';

  @override
  String get acctSectionPrivacy => 'Integritet';

  @override
  String get acctSectionAccount => 'Konto';

  @override
  String get acctSectionFamily => 'Familj';

  @override
  String get acctSectionThisPhone => 'Den här telefonen';

  @override
  String get acctRowVisibility => 'Profilens synlighet';

  @override
  String get acctRowBlocked => 'Blockerade användare';

  @override
  String get acctRowApprovals => 'Godkännanden';

  @override
  String get acctNothingWaiting => 'Inget väntar';

  @override
  String get acctRowLinked => 'Länkade konton';

  @override
  String get acctRowScanToSignIn => 'Skanna för att logga in';

  @override
  String get acctRowSetUpRecovery => 'Skapa återställningsfras';

  @override
  String get acctRowChangeRecovery => 'Byt återställningsfras';

  @override
  String get acctSignOut => 'Logga ut';

  @override
  String get acctDeleteAccount => 'Radera konto';

  @override
  String get acctConfirmDelete => 'Tryck igen för att radera';

  @override
  String get acctHandPhoneBack => 'Lämna tillbaka telefonen';

  @override
  String get acctMyGrownUps => 'Mina vuxna';

  @override
  String get acctActionMessage => 'Meddela';

  @override
  String get acctActionAddFriend => 'Lägg till';

  @override
  String get acctActionRequested => 'Skickad';

  @override
  String get acctActionAccept => 'Godkänn';

  @override
  String get acctActionNotAccepting => 'Stängt';

  @override
  String get acctActionUnfriend => 'Ta bort';

  @override
  String get acctActionBlock => 'Blockera';

  @override
  String get acctActionReport => 'Anmäl';

  @override
  String get acctStatusFriends => 'Ni är vänner';

  @override
  String get acctStatusRequestSent => 'Förfrågan skickad';

  @override
  String get acctStatusWantsToConnect => 'Vill bli vänner';

  @override
  String get acctStatusNotConnected => 'Inte kopplade';

  @override
  String get acctPresenceOnline => 'Online';

  @override
  String get acctPresenceAway => 'Borta';

  @override
  String get acctPresenceOffline => 'Offline';

  @override
  String get acctProfilePhoto => 'Profilbild';

  @override
  String get acctSaveToPhotos => 'Spara i Bilder';

  @override
  String get acctTakeSelfie => 'Ta en selfie';

  @override
  String get acctChooseFromLibrary => 'Välj från biblioteket';

  @override
  String get acctCancel => 'Avbryt';

  @override
  String get acctSave => 'Spara';

  @override
  String get acctChange => 'Ändra';

  @override
  String get acctNotNow => 'Inte nu';

  @override
  String get acctAddEmail => 'Lägg till e-post';

  @override
  String get acctEditNameTitle => 'Redigera namn';

  @override
  String get acctAddNameTitle => 'Lägg till ditt namn';

  @override
  String get acctEditEmailTitle => 'Redigera e-post';

  @override
  String get acctChangeUsernameTitle => 'Byta användarnamn?';

  @override
  String get onboardingLookTitle => 'Gör den till din';

  @override
  String get onboardingLookBody =>
      'Välj ett utseende. Du kan ändra det när som helst i Inställningar.';

  @override
  String get onboardingEssentials => 'Grundteman';

  @override
  String get onboardingEssentialsSub => 'Lugna och inbyggda';

  @override
  String get onboardingCharacters => 'Med karaktär';

  @override
  String get onboardingCharactersSub => 'Samma app, mer personlighet';

  @override
  String get onboardingLightMode => 'Ljust läge';

  @override
  String get onboardingDarkMode => 'Mörkt läge';

  @override
  String get onboardingNow => 'Nu';

  @override
  String get onboardingContinue => 'Fortsätt';

  @override
  String get onboardingIconTitle => 'Din appikon';

  @override
  String get onboardingIconBody =>
      'Behåll din ikon, låt den följa ditt tema eller välj vilken som helst.';

  @override
  String get onboardingIconIosNote =>
      'iOS visar ett kort meddelande varje gång ikonen ändras.';

  @override
  String get onboardingGetStarted => 'Kom igång';

  @override
  String get appIconMatchTheme => 'Följ temat';

  @override
  String get appIconCurrent => 'Nuvarande';

  @override
  String get appIconSectionCollection => 'MonkeyHub-samlingen';

  @override
  String get appIconSectionThemes => 'Temaikoner';

  @override
  String get appIconScreenTitle => 'Appikon';

  @override
  String get appIconMatchFooter =>
      'Följ temat byter ikon tillsammans med ditt mörka tema, så att den inte växlar fram och tillbaka under dagen.';

  @override
  String get loginTitleReturning => 'Välkommen tillbaka';

  @override
  String get loginTitleFirst => 'Välkommen till MonkeyHub';

  @override
  String get loginTitleSignUp => 'Skapa ditt konto';

  @override
  String get loginTitleReset => 'Återställ ditt lösenord';

  @override
  String get loginSubtitleSignIn => 'Logga in och fortsätt där du slutade.';

  @override
  String get loginSubtitleFirst =>
      'Logga in, eller skapa ett konto på några sekunder.';

  @override
  String get loginSubtitleSignUp =>
      'Ett användarnamn och ett lösenord är allt som behövs.';

  @override
  String get loginSubtitleReset =>
      'Ange din återställningsfras på 12 ord och välj ett nytt lösenord.';

  @override
  String get loginCtaSignIn => 'Logga in';

  @override
  String get loginCtaSignUp => 'Skapa konto';

  @override
  String get loginCtaReset => 'Återställ lösenord';

  @override
  String get loginNoAccountPrompt => 'Ny här? ';

  @override
  String get loginCreateAccountLink => 'Skapa ett konto';

  @override
  String get loginHaveAccountPrompt => 'Har du redan ett konto? ';

  @override
  String get loginSignInLink => 'Logga in';

  @override
  String get loginForgotPassword => 'Glömt lösenordet?';

  @override
  String get loginChildAccount => 'Konfigurera ett barnkonto';

  @override
  String get loginBackToSignIn => 'Tillbaka till inloggning';

  @override
  String get loginWithPhone => 'Logga in med telefonen';

  @override
  String get loginUsernameField => 'Användarnamn';

  @override
  String get loginPasswordField => 'Lösenord';

  @override
  String get loginConfirmPasswordField => 'Bekräfta lösenord';

  @override
  String get loginNameField => 'Namn (valfritt)';

  @override
  String get loginRecoveryPhraseField => 'Din återställningsfras på 12 ord';

  @override
  String get loginNewPasswordField => 'Nytt lösenord';

  @override
  String get roomHeaderStatusOnline => 'Online';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '$count medlem',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => 'Inställningar';

  @override
  String get settingsHubAccountHintAdult =>
      'Profil, familj, länkade konton och integritet';

  @override
  String get settingsHubAccountHintChild => 'Profil, integritet och dina vuxna';

  @override
  String get settingsHubSectionGeneral => 'Allmänt';

  @override
  String get settingsHubSectionNotifications => 'Notiser';

  @override
  String get settingsHubSectionCalls => 'Samtal';

  @override
  String get settingsHubSectionAppearance => 'Utseende';

  @override
  String get settingsHubSectionCompanions => 'Följeslagare';

  @override
  String get settingsHubSectionChats => 'Chattar';

  @override
  String get settingsHubSectionHelp => 'Hjälp och juridik';

  @override
  String get settingsHubSectionAdvanced => 'Avancerat';

  @override
  String get settingsHubLanguage => 'Språk';

  @override
  String get settingsHubCheckForUpdates => 'Sök efter uppdateringar';

  @override
  String get settingsHubUpdateAvailable => 'Uppdatering finns';

  @override
  String get settingsHubShowLinkUrls => 'Visa länkadresser';

  @override
  String get settingsHubShowLinkUrlsSubtitle =>
      'Visar adressen bredvid varje förhandsvisning';

  @override
  String get settingsHubPresenceDots => 'Visa vem som är online';

  @override
  String get settingsHubPresenceDotsSubtitle => 'Pricken på profilbilder';

  @override
  String get settingsHubPush => 'Pushnotiser';

  @override
  String get settingsHubPushSubtitle =>
      'Nya meddelanden, samtal och förfrågningar';

  @override
  String get settingsHubGameReminders => 'Daglig spelpåminnelse';

  @override
  String get settingsHubGameRemindersSubtitle =>
      'En påminnelse vid lunch om du inte har spelat';

  @override
  String get settingsHubFriendActivity => 'Vänaktivitet';

  @override
  String get settingsHubFriendActivitySubtitle =>
      'Höjdpunkter, poäng och spelresultat från vänner';

  @override
  String get settingsHubMenuBar => 'Menyradssymbol';

  @override
  String get settingsHubMenuBarSubtitle => 'Visar olästa i menyraden';

  @override
  String get settingsHubCallStats => 'Visa samtalsstatistik';

  @override
  String get settingsHubCallStatsSubtitle =>
      'Upplösning, bithastighet och ping under samtal';

  @override
  String get settingsHubTheme => 'Tema';

  @override
  String get settingsHubAppIcon => 'Appsymbol';

  @override
  String get settingsHubGlass => 'Glas';

  @override
  String get settingsHubNavigation => 'Navigering';

  @override
  String get settingsHubMotion => 'Rörelse';

  @override
  String get settingsHubChatList => 'Chattlista';

  @override
  String get settingsHubChatStyle => 'Chattstil';

  @override
  String get settingsHubBubbleStyle => 'Bubbelstil';

  @override
  String get settingsHubSpeakerColors => 'Talarfärger';

  @override
  String get settingsHubReplyStyle => 'Svarsstil';

  @override
  String get settingsHubPrivacyPolicy => 'Integritetspolicy';

  @override
  String get settingsHubTerms => 'Användarvillkor';

  @override
  String get settingsHubLicence => 'Licens';

  @override
  String get settingsHubServer => 'Server';

  @override
  String get settingsHubLayoutRows => 'Rader';

  @override
  String get settingsHubLayoutCards => 'Kort';

  @override
  String get settingsHubLayoutGrid => 'Rutnät';

  @override
  String get settingsHubNavTabBar => 'Flikfält';

  @override
  String settingsHubThemeAuto(String name) {
    return 'Auto · $name';
  }

  @override
  String get chatListPageRowsSub =>
      'Ett ansikte, ett namn och senaste meddelandet, som i Meddelanden.';

  @override
  String get chatListPageCardsSub =>
      'Varje rum på ett eget kort, varje detalj utskriven.';

  @override
  String get chatListPageGridSub =>
      'Två kolumner med rutor. Fler rum på en gång.';

  @override
  String get chatListPageLayoutHeader => 'Layout';

  @override
  String get chatListPageFiltersHeader => 'Filter';

  @override
  String get chatListPageChips => 'Chips';

  @override
  String get chatListPageChipsSub => 'En rad filter, alltid ett tryck bort.';

  @override
  String get chatListPageButton => 'Knapp';

  @override
  String get chatListPageButtonSub =>
      'En knapp som öppnar filtren när du vill.';

  @override
  String get chatListPageEmptyHeader => 'Tomma rum';

  @override
  String get chatListPagePlain => 'Enkel';

  @override
  String get chatListPagePlainSub =>
      'Ett rum där inget sagts ännu förblir tomt.';

  @override
  String get chatListPageInitial => 'Initial';

  @override
  String get chatListPageInitialSub =>
      'En stor blek bokstav fyller det tomma hörnet.';

  @override
  String get chatListPageEmptyFooter => 'Gäller rutnätslayouten.';

  @override
  String get chatStylePageFooter =>
      'Hur konversationens rubrik och meddelandefält ritas.';

  @override
  String get chatStyleClassicSub =>
      'En fast rubrik och ett platt meddelandefält.';

  @override
  String get chatStyleCompactSub =>
      'Frostade kontroller svävar över konversationen.';

  @override
  String get bubbleTailedSub =>
      'En svans på sista meddelandet i varje följd, som i Meddelanden.';

  @override
  String get bubbleSoftSub => 'Ingen svans. Följden hålls ihop av hörnen.';

  @override
  String get bubblePillSub => 'Helt rundade kapslar för varje meddelande.';

  @override
  String get bubbleSlabSub => 'Fyrkantiga axlar: skarpa och avsiktliga.';

  @override
  String get replyStylePageFooter =>
      'Hur ett svar visar meddelandet det besvarar.';

  @override
  String get replyClassicSub =>
      'Ett tonat citat ovanför meddelandet, som i WhatsApp.';

  @override
  String get replyPhantomSub =>
      'Ett spöke av originalet svävar ovanför, förbundet med en kurva.';

  @override
  String get replyStickySub => 'Ett litet lutande kort fäst i hörnet.';

  @override
  String get replyComicSub => 'En minibubbla med serietidningssvans.';

  @override
  String get motionMatchDevice => 'Som enheten';

  @override
  String get motionMatchDeviceCalmSub =>
      'Din enhet ber om minskad rörelse just nu.';

  @override
  String get motionMatchDeviceFullSub =>
      'Din enhet tillåter animering just nu.';

  @override
  String get motionFullSub => 'Varje fjädring, glidning och krusidull.';

  @override
  String get motionCalmSub =>
      'Dekorationer står still. Allt annat fungerar som vanligt.';

  @override
  String get navigationPageFooter =>
      'Hur du rör dig mellan Chattar, Flöde, Upptäck och Inställningar.';

  @override
  String get navTabBarSub => 'Alltid synlig, ett tryck till var som helst.';

  @override
  String get navOrbSub => 'Håll och dra från hörnet. En gest man växer in i.';

  @override
  String get languageSystemLabel => 'Enhetens språk';

  @override
  String get languagePageFooter =>
      'Menyer och appmeddelanden. Chattar förblir på det språk folk skriver.';

  @override
  String get speakerPageFooter => 'Se direkt vem som pratar i gruppchattar.';

  @override
  String get speakerOffSub => 'Alla skriver med samma bläck.';

  @override
  String get speakerNamesSub => 'Varje person får en färg på namn och ansikte.';

  @override
  String get speakerBubblesSub => 'Färgen följer med in i meddelandena också.';

  @override
  String get themePageAutoFooter =>
      'Ljusa teman används i ljust läge, mörka i mörkt läge.';

  @override
  String get themePageLightMode => 'Ljust läge';

  @override
  String get themePageDarkMode => 'Mörkt läge';

  @override
  String get themePageEssentials => 'Grundteman';

  @override
  String get themePageEssentialsFooter => 'Lugna och inbyggda, i fem färger.';

  @override
  String get themePageCharacters => 'Karaktärer';

  @override
  String get themePageCharactersFooter =>
      'Samma layout, med en egen personlighet. Håll på ett tema för att förhandsvisa.';

  @override
  String get themePageLightBadge => 'Ljust';

  @override
  String get themePageDarkBadge => 'Mörkt';

  @override
  String get themePageInUse => 'Används';

  @override
  String get themePageUseLight => 'Använd i ljust läge';

  @override
  String get themePageUseDark => 'Använd i mörkt läge';

  @override
  String themePageUse(String name) {
    return 'Använd $name';
  }

  @override
  String get acctCaptureTitle => 'Skydd mot skärminspelning';

  @override
  String get acctCaptureOnIos =>
      'Inspelning och skärmdelning visar ett integritetsskydd.';

  @override
  String get acctCaptureOnAndroid =>
      'Skärmbilder och inspelningar blir svarta.';

  @override
  String get acctCaptureOff =>
      'Skärmbilder och inspelningar fungerar som vanligt.';

  @override
  String get acctCaptureFooter =>
      'Rum med försvinnande meddelanden slår alltid på detta.';

  @override
  String get acctActionPending => 'Väntar';

  @override
  String get chatSwipePin => 'Fäst';

  @override
  String get chatSwipeUnpin => 'Lossa';

  @override
  String get chatSwipeMute => 'Tysta';

  @override
  String get chatSwipeUnmute => 'Slå på';

  @override
  String get chatSwipeArchive => 'Arkivera';

  @override
  String get appearanceMatchDeviceSubtitle =>
      'Ljust på dagen, mörkt på kvällen, som din telefon';

  @override
  String get appearanceOneThemeSubtitle => 'Samma utseende hela dagen';

  @override
  String get riName => 'Namn';

  @override
  String get riDescription => 'Beskrivning';

  @override
  String get riVisibility => 'Vem kan hitta det';

  @override
  String get riPublic => 'Offentligt';

  @override
  String get riPublicSub => 'Alla kan hitta det i Upptäck';

  @override
  String get riPrivate => 'Privat';

  @override
  String get riPrivateSub => 'Bara de du bjuder in kan gå med';

  @override
  String get riMessageLife => 'Meddelanden försvinner efter';

  @override
  String get riPassword => 'Lösenord';

  @override
  String get riRemovePassword => 'Ta bort lösenord';

  @override
  String get riSetPassword => 'Ange lösenord';

  @override
  String get riSharedContent => 'Delat innehåll';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inbjudna',
      one: '1 inbjuden',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => 'Dra tillbaka';

  @override
  String get riNotifications => 'Aviseringar';

  @override
  String get riTranslation => 'Översättning';

  @override
  String get riNameColours => 'Namnfärger';

  @override
  String get riYouSuggested => 'Du föreslog';

  @override
  String get riTakeBack => 'Ta tillbaka';

  @override
  String get riLeaveRoom => 'Lämna rummet';

  @override
  String get riLeaving => 'Lämnar…';

  @override
  String get riDeleteRoom => 'Radera rummet';

  @override
  String get riDeleting => 'Raderar…';

  @override
  String get riEndConversation => 'Avsluta konversationen';

  @override
  String get riEnding => 'Avslutar…';

  @override
  String get riActionCall => 'Ring';

  @override
  String get riActionVideo => 'Video';

  @override
  String get riActionMute => 'Tysta';

  @override
  String get riActionUnmute => 'Slå på ljud';

  @override
  String get riActionMedia => 'Media';

  @override
  String get riActionAdd => 'Lägg till';

  @override
  String get roomHeaderStatusTyping => 'Skriver…';

  @override
  String get glassScreenLead => 'Hur mycket av det bakom som syns igenom.';

  @override
  String get transcriptDayToday => 'Idag';

  @override
  String get acctRowDevices => 'Enheter';

  @override
  String get acctThisDevice => 'Den här enheten';

  @override
  String get acctRemove => 'Ta bort';

  @override
  String get acctRemoveDeviceTitle => 'Ta bort den här enheten?';

  @override
  String get acctRemoveAllTitle => 'Ta bort alla andra enheter?';

  @override
  String get acctRemoveAll => 'Ta bort alla';

  @override
  String get acctActiveNow => 'Aktiv nu';

  @override
  String get acctLoading => 'Laddar…';

  @override
  String get acctDevicesLoadFailed => 'Kunde inte läsa in dina enheter.';

  @override
  String get acctNoNotifications => 'Aviseringar når inte den här';

  @override
  String get acctBlockedEmpty => 'Du har inte blockerat någon.';

  @override
  String get acctUnblock => 'Avblockera';

  @override
  String get pvSubtitle => 'Styr vad andra ser och hur de kan nå dig.';

  @override
  String get pvSectionProfile => 'Profil';

  @override
  String get pvSectionMessages => 'Meddelanden';

  @override
  String get pvSectionPeople => 'Personer';

  @override
  String get pvSectionFeed => 'Flöde';

  @override
  String get pvAvatar => 'Profilbild';

  @override
  String get pvAvatarDesc => 'Vem kan se din bild';

  @override
  String get pvOnline => 'Onlinestatus';

  @override
  String get pvOnlineDesc => 'Om du syns som aktiv just nu';

  @override
  String get pvLastSeen => 'Senast sedd';

  @override
  String get pvLastSeenDesc => 'När du senast var här';

  @override
  String get pvSendReceipts => 'Skicka läskvitton';

  @override
  String get pvSendReceiptsDesc =>
      'Låt andra se när du har läst deras meddelanden';

  @override
  String get pvShowReceipts => 'Visa läskvitton';

  @override
  String get pvShowReceiptsDesc => 'Se vem som har läst dina meddelanden';

  @override
  String get pvShowReceiptsHint => 'Bara de som skickar läskvitton räknas.';

  @override
  String get pvFriendRequests => 'Vänförfrågningar';

  @override
  String get pvFriendRequestsDesc => 'Vem kan skicka vänförfrågningar';

  @override
  String get pvSupervisedTitle => 'Dina vuxna ställer in detta';

  @override
  String get pvEveryone => 'Alla';

  @override
  String get pvFriends => 'Vänner';

  @override
  String get pvNobody => 'Ingen';

  @override
  String get pvOn => 'På';

  @override
  String get pvOff => 'Av';

  @override
  String get pvAnyone => 'Vem som helst';

  @override
  String get pvHighlights => 'Mina höjdpunkter';

  @override
  String get pvHighlightsDesc =>
      'Om dina bilder och videor syns på vännernas tavlor för dagen';

  @override
  String get pvPuzzle => 'Mitt pusselresultat';

  @override
  String get pvPuzzleDesc => 'Om vänner ser hur det gick på dagens pussel';

  @override
  String get pvPast => 'Min historik';

  @override
  String get pvPastDesc =>
      'Idag delas alltid med vänner — det här öppnar allt före det';

  @override
  String get pvPoints => 'Mina poäng';

  @override
  String get pvPointsDesc => 'Om poängen du loggar syns på vännernas tavlor';

  @override
  String get roomColorsPageTitle => 'Vem är vem';

  @override
  String get roomColorsPageHeader => 'Färgen varje person pratar i';

  @override
  String get roomColorsAuto => 'Automatisk';

  @override
  String get roomColorsReset => 'Tillbaka till automatiskt';

  @override
  String get roomColorsOffFooter =>
      'Talarfärger är av. Slår du på dem här blir de på i alla rum.';

  @override
  String roomColorsSharedWith(String name) {
    return 'Delas med $name';
  }

  @override
  String get settingsScreenValueReplyQuote => 'Citat';

  @override
  String get replyQuoteSub =>
      'Originalet visas överst i svaret, inuti bubblan.';

  @override
  String get riTabMedia => 'Bilder och videor';

  @override
  String get riTabFiles => 'Filer';

  @override
  String get riTabVoice => 'Röstmeddelanden';

  @override
  String get riTabLinks => 'Länkar';

  @override
  String get riTabSaved => 'Sparade';

  @override
  String get riNone => 'Inga';

  @override
  String get riSavedNote =>
      'Bara du ser det du sparar. Ett fäst meddelande är tvärtom — hela rummet ser det.';

  @override
  String get riOwnerNote => 'Medaljen visar vem som skapade rummet.';

  @override
  String get famPair => 'Para ihop';

  @override
  String get famRelease => 'Släpp';

  @override
  String get famSettings => 'Inställningar';

  @override
  String get famAddChild => 'Lägg till ett barn';

  @override
  String get famEmptyTitle => 'Inga barn än';

  @override
  String get famOnlineNow => 'Online nu';

  @override
  String get famNotPaired => 'Inte ihopparad än';

  @override
  String get famJustNow => 'Nyss';

  @override
  String get apprEmptyTitle => 'Inget väntar';

  @override
  String get apprEmptySub => 'Allt är klart.';

  @override
  String get apprNotYet => 'Inte än';

  @override
  String get apprAllow => 'Tillåt';

  @override
  String get compGeneral => 'Allmänt';

  @override
  String get compStorage => 'Lagring';

  @override
  String get compTranslateInto => 'Översätt till';

  @override
  String get compBrain => 'Hjärna';

  @override
  String laUnlinkProvider(String provider) {
    return 'Koppla bort $provider';
  }

  @override
  String laLinkProvider(String provider) {
    return 'Koppla $provider';
  }

  @override
  String get laUnlink => 'Koppla bort';

  @override
  String get laLink => 'Koppla';

  @override
  String get laLinked => 'Kopplad';

  @override
  String get laNotLinked => 'Inte kopplad';

  @override
  String rdSignOut(String name) {
    return 'Logga ut $name';
  }

  @override
  String get rpContinue => 'Fortsätt';

  @override
  String get rpCopy => 'Kopiera';

  @override
  String get rpSaved => 'Jag har sparat dem';

  @override
  String get rpBack => 'Tillbaka';

  @override
  String get rpKeep => 'Inte nu – behåll min nuvarande fras';

  @override
  String get childSetupHeadingIos => 'Vem är det?';

  @override
  String get childPairTitleIos => 'Hej!';

  @override
  String get childPairBackIos => 'Tillbaka till inloggning';

  @override
  String get gamesHubTitle => 'Topplista';

  @override
  String get gamesHubSubtitle => 'Dagens vinnare. Nya pussel varje dag.';

  @override
  String get gameTellFriendsMessage =>
      'De får en avisering med resultatet. Det kan bara skickas en gång.';

  @override
  String get deviceLoginScanTitleIos => 'Skanna för att logga in';

  @override
  String get deviceLoginConfirmTitleIos => 'Logga in på den här enheten?';

  @override
  String get socialHeroCreateIos => 'Nästan klart';

  @override
  String get socialHeroLinkIos => 'Välkommen tillbaka';

  @override
  String socialSignInLinkIos(String provider) {
    return 'Logga in och koppla $provider';
  }

  @override
  String get serverTitleIos => 'Server';

  @override
  String get serverOnboardingTitleIos => 'Välj en server';

  @override
  String get approvalGateAskIos => 'Fråga';

  @override
  String get friendRequestDraftIntroOutgoingSentence =>
      'Skriv några rader. De kan godkänna eller avvisa.';

  @override
  String get requestDeclineIos => 'Avböj';

  @override
  String get joinRequestAllowIos => 'Tillåt';

  @override
  String get changeRequestUseIos => 'Använd';

  @override
  String get settingsSearchHint => 'Sök i inställningar';

  @override
  String settingsSearchNoResults(String query) {
    return 'Inga resultat för ”$query”';
  }

  @override
  String get settingsSearchAccount => 'Konto';

  @override
  String get settingsHubDiagnostics => 'Diagnostik';

  @override
  String get settingsHubDiagnosticsSubtitle =>
      'Loggar för felsökning och felrapporter';

  @override
  String get settingsHubAdvancedFooter =>
      'För felsökning och egen server. Inget här behövs i vardagen.';

  @override
  String get settingsSearchKwLanguage => 'språk, översättning, region';

  @override
  String get settingsSearchKwUpdates => 'uppdatering, version, ny';

  @override
  String get settingsSearchKwLinks => 'länkar, url, adress, förhandsvisning';

  @override
  String get settingsSearchKwPresence =>
      'online, närvaro, status, prick, aktiv, grön';

  @override
  String get settingsSearchKwAutoplay => 'gif, animation, autouppspelning';

  @override
  String get settingsSearchKwStickers => 'klistermärken, emoji, förslag';

  @override
  String get settingsSearchKwPush => 'notiser, aviseringar, ljud';

  @override
  String get settingsSearchKwGames => 'spel, påminnelse, daglig';

  @override
  String get settingsSearchKwFriends => 'vänner, aktivitet, poäng';

  @override
  String get settingsSearchKwVideo => 'video, samtal, kvalitet, kamera';

  @override
  String get settingsSearchKwStats => 'statistik, nätverk, ping, felsökning';

  @override
  String get settingsSearchKwTheme => 'tema, mörk, ljus, färger, natt';

  @override
  String get settingsSearchKwIcon => 'appikon, logga, hemskärm';

  @override
  String get settingsSearchKwGlass => 'glas, oskärpa, frostat, transparens';

  @override
  String get settingsSearchKwNavigation => 'flikfält, navigering, meny';

  @override
  String get settingsSearchKwMotion => 'rörelse, animation, minska rörelse';

  @override
  String get settingsSearchKwCompanions => 'ai, assistent, översätt, modell';

  @override
  String get settingsSearchKwChatList => 'chattlista, rader, kort, rutnät';

  @override
  String get settingsSearchKwChatStyle => 'chattstil, kompakt, klassisk';

  @override
  String get settingsSearchKwBubbles => 'bubblor, meddelanden, form';

  @override
  String get settingsSearchKwSpeakers => 'namn, färger, grupper';

  @override
  String get settingsSearchKwReply => 'svar, citat, tråd';

  @override
  String get settingsSearchKwReport => 'bugg, problem, feedback, hjälp';

  @override
  String get settingsSearchKwLegal => 'integritet, villkor, juridik, licens';

  @override
  String get settingsSearchKwServer => 'server, egen server, url, utvecklare';

  @override
  String get settingsSearchKwDiagnostics =>
      'diagnostik, loggar, felsökning, utvecklare';

  @override
  String get settingsSearchKwPrivacy =>
      'integritet, synlighet, senast sedd, läskvitton';

  @override
  String get settingsSearchKwBlocked => 'blockerade, blockera';

  @override
  String get settingsSearchKwDevices => 'enheter, sessioner, logga ut';

  @override
  String get settingsSearchKwLinked => 'apple, google, logga in';

  @override
  String get settingsSearchKwRecovery =>
      'återställningsfras, lösenord, säkerhetskopia';

  @override
  String get settingsSearchKwCapture =>
      'skärmdump, skärminspelning, integritet';

  @override
  String get settingsSearchKwFamily => 'familj, barn, förälder, godkännanden';

  @override
  String get settingsSearchKwAccount => 'konto, logga ut, radera, e-post';

  @override
  String get childPolicyScreenContactStateAllowedTalking => 'Pratar';

  @override
  String get childPolicyScreenContactStateTalking => 'Godkänd';

  @override
  String get childPolicyScreenContactStateAllowedNotAdded => 'Inte tillagd än';

  @override
  String get profileScreenSignOutConfirmTitle => 'Logga ut på den här enheten?';

  @override
  String get profileScreenDeleteAccountConfirmTitle => 'Radera ditt konto?';

  @override
  String get profileScreenDeleteAccountConfirmBody =>
      'Dina meddelanden, foton, rum och vänner försvinner, och ditt användarnamn blir ledigt för någon annan.';

  @override
  String get glassPresetNameFrosted => 'Frostat';

  @override
  String get glassPresetNameClear => 'Klart';

  @override
  String settingsScreenDiagnosticsCountdown(int count) {
    return 'Diagnostik om $count…';
  }

  @override
  String pairingCodeTitlePair(String name) {
    return 'Parkoppla $name';
  }

  @override
  String pairingCodeTitleRelease(String name) {
    return 'Frigör $name';
  }

  @override
  String archivedChatsSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chattar',
      one: '$count chatt',
    );
    return '$_temp0';
  }

  @override
  String pinnedListSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meddelanden',
      one: '$count meddelande',
    );
    return '$_temp0';
  }

  @override
  String get voiceRecorderScreenTitle => 'Röstmeddelande';

  @override
  String get chatTargetSearchHint => 'Sök';

  @override
  String get marloweBrainTierSwiftDetail =>
      'Snabba svar, den lättaste nedladdningen';

  @override
  String get marloweBrainTierBalancedDetail =>
      'En bra blandning av fart och djup';

  @override
  String get marloweBrainTierDeepDetail =>
      'Den mest eftertänksamma, kräver mest utrymme';

  @override
  String get reportFactDeviceId => 'Enhets-ID';

  @override
  String get reportFactUserId => 'Användar-ID';

  @override
  String get reportFactUsername => 'Användarnamn';

  @override
  String get reportFactApp => 'App';

  @override
  String get reportFactDevice => 'Enhet';

  @override
  String get reportFactSystem => 'System';

  @override
  String get reportFactDisplay => 'Skärm';

  @override
  String get reportFactAppLanguage => 'Appspråk';

  @override
  String get reportFactSystemLocale => 'Systemregion';

  @override
  String get reportFactLog => 'Logg';

  @override
  String reportFactLogValue(int count) {
    return '$count händelser bifogade';
  }

  @override
  String reportProblemScreenshotN(int n) {
    return 'Skärmbild $n';
  }

  @override
  String reportProblemRemoveScreenshot(int n) {
    return 'Ta bort skärmbild $n';
  }

  @override
  String get reportFactLanguageFromSystem => 'från systemet';

  @override
  String get reportFactLanguageChosen => 'valt';

  @override
  String get pageSectionSeeAll => 'Visa alla';

  @override
  String get discoverScreenSeeAllFriendsSemanticLabel => 'Visa alla vänner';

  @override
  String get discoverScreenSeeAllRoomsSemanticLabel => 'Visa alla dina rum';

  @override
  String groupCallScreenRingingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ringer',
    );
    return '$_temp0';
  }

  @override
  String photoChromeWhenToday(String time) {
    return 'I dag $time';
  }

  @override
  String photoChromeWhenYesterday(String time) {
    return 'I går $time';
  }

  @override
  String photoChromeWhenDate(String date, String time) {
    return '$date $time';
  }

  @override
  String get photoChromeSaved => 'Sparad';

  @override
  String get photoChromeSaveFailed => 'Kunde inte spara';

  @override
  String get photoChromeShareFailed => 'Kunde inte dela';

  @override
  String photoChromeForwarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vidarebefordrad till $count chattar',
      one: 'Vidarebefordrad',
    );
    return '$_temp0';
  }

  @override
  String get photoChromeForwardFailed => 'Kunde inte vidarebefordra';

  @override
  String get photoChromeDeleteFailed => 'Kunde inte radera';

  @override
  String get photoChromeDeleteBody =>
      'Det tas bort för alla i den här chatten. Det kan inte ångras.';

  @override
  String get roomContentMonthThis => 'Den här månaden';

  @override
  String get roomContentMonthLast => 'Förra månaden';

  @override
  String get gameInfoGoalLabel => 'Mål';

  @override
  String get gameInfoExampleLabel => 'Exempel';

  @override
  String get gameInfoWinLabel => 'Så vinner du';

  @override
  String get gameInfoQueensRule4 =>
      'Kronor får inte nudda varandra. Inte ens hörn mot hörn.';

  @override
  String get gameInfoQueensExample =>
      'En krona här betyder: ingen annan krona i samma rad, kolumn eller färg, eller i de 8 rutorna runt den.';

  @override
  String get gameInfoTangoRule4 =>
      '= betyder att de 2 rutorna är lika. × att de är olika.';

  @override
  String get gameInfoTangoExample =>
      'Sol, sol, tom? Den tomma rutan måste vara en måne.';

  @override
  String get gameInfoZipRule4 =>
      'Gå upp, ner, vänster eller höger. Inga diagonaler.';

  @override
  String get gameInfoZipRule5 => 'Sluta på det sista talet.';

  @override
  String get gameInfoZipExample =>
      'Ska du från 1 till 2? Ta en omväg om du måste. Ingen ruta får bli tom.';

  @override
  String get gameInfoSudokuExample =>
      'Har en rad redan 1, 2, 4, 5 och 6? Den tomma rutan är 3.';

  @override
  String get gameInfoCodeRule4 => 'Gul: rätt symbol, fel plats.';

  @override
  String get gameInfoCodeRule5 => 'Grå: den symbolen finns inte i koden.';

  @override
  String get gameInfoCodeExample =>
      'Grön, gul, grå, grå betyder: 1 symbol står rätt, 1 hör hemma någon annanstans, 2 finns inte i koden.';

  @override
  String get leaderboardOverall => 'I dag';

  @override
  String get leaderboardFooter =>
      '1 poäng för varje pussel du löser i dag. Vid lika vinner den som kom först flest gånger.';

  @override
  String get leaderboardNotPlayed => 'Inte spelat än';

  @override
  String get leaderboardPlay => 'Spela';

  @override
  String get leaderboardEmptyTitle => 'Inga resultat än i dag';

  @override
  String get leaderboardEmptyBody =>
      'Lös ett pussel så hamnar du först på listan.';

  @override
  String get leaderboardGamesHeader => 'Dagens pussel';

  @override
  String get pointComposerPickFirst => 'Välj en ovan först';

  @override
  String get momentStoryNext => 'Nästa';

  @override
  String get momentStoryPrevious => 'Föregående';

  @override
  String leaderboardSolved(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      solved,
      locale: localeName,
      other: '$solved av $total lösta',
      one: '1 av $total löst',
      zero: 'Inget löst än',
    );
    return '$_temp0';
  }

  @override
  String leaderboardWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vinster',
      one: '1 vinst',
    );
    return '$_temp0';
  }

  @override
  String leaderboardEmptyAction(String game) {
    return 'Spela $game';
  }

  @override
  String get diagCatApi => 'Serveranrop';

  @override
  String get diagCatConnection => 'Anslutning';

  @override
  String get diagCatDevice => 'Enhet';

  @override
  String get diagCatError => 'Fel';

  @override
  String get diagCatFrame => 'Långsamma bildrutor';

  @override
  String get diagCatLayout => 'Layout';

  @override
  String get diagCatLifecycle => 'Appläge';

  @override
  String get diagCatLog => 'Logg';

  @override
  String get diagCatNav => 'Navigering';

  @override
  String get diagCatNetwork => 'Nätverk';

  @override
  String get diagCatSubscription => 'Liveuppdateringar';

  @override
  String get diagSevTrace => 'Spårning';

  @override
  String get diagSevDebug => 'Felsökning';

  @override
  String get diagSevInfo => 'Info';

  @override
  String get diagSevWarning => 'Varning';

  @override
  String get diagSevError => 'Fel';

  @override
  String get diagAll => 'Alla';

  @override
  String get diagSearchHint => 'Sök namn, detalj, innehåll';

  @override
  String get diagSummaryCopied => 'Sammanfattning kopierad';

  @override
  String get diagShareLog => 'Dela logg';

  @override
  String get diagCopySummary => 'Kopiera sammanfattning';

  @override
  String get diagDeleteAll => 'Radera allt';

  @override
  String get diagUndo => 'Ångra';

  @override
  String get diagDeleteLogTitle => 'Radera hela loggen?';

  @override
  String get diagDeleteLogBody =>
      'Alla händelser som fångats hittills försvinner, liksom förra körningens logg. Allt som händer härifrån fångas som vanligt.';

  @override
  String get diagDelete => 'Radera';

  @override
  String get diagLogDeleted => 'Loggen raderad';

  @override
  String get diagFilter => 'Filtrera';

  @override
  String get diagMore => 'Mer';

  @override
  String get diagLatest => 'Senaste';

  @override
  String get diagJumpToLatest => 'Hoppa till senaste';

  @override
  String get diagPaused => 'pausad';

  @override
  String get diagPreparingLog => 'förbereder logg…';

  @override
  String get diagEmptyNothingTitle => 'Inget fångat än';

  @override
  String get diagEmptyNothingHint =>
      'Använd appen en stund så dyker händelser upp här.';

  @override
  String get diagEmptyHiddenTitle => 'Bara dolda händelser hittills';

  @override
  String get diagEmptyHiddenHint =>
      'Tryck på en nedtonad etikett ovan för att se den, eller håll in för att ta tillbaka den till Alla.';

  @override
  String get diagEmptyNoMatchTitle => 'Inga händelser matchar';

  @override
  String get diagEmptyNoMatchHint =>
      'Tryck på Alla ovan för att rensa filtret.';

  @override
  String get diagApply => 'Använd';

  @override
  String get diagMinSeverity => 'Lägsta allvarlighetsgrad';

  @override
  String get diagEverything => 'Allt';

  @override
  String get diagHiddenFromAllHeader => 'Dolda i Alla';

  @override
  String get diagHiddenFromAllFooter =>
      'Utelämnas ur Alla tills de väljs i etikettraden. Håll in en etikett där för samma reglage.';

  @override
  String get diagCollapseRepeats => 'Slå ihop upprepningar';

  @override
  String get diagCollapseRepeatsSubtitle =>
      'Samla en serie av samma händelse på en rad';

  @override
  String get diagResetFilter => 'Återställ filter';

  @override
  String get diagBodyTruncated => 'Innehållet kortades vid fångst';

  @override
  String get diagCopyEvent => 'Kopiera händelse';

  @override
  String get diagEventCopied => 'Händelsen kopierad';

  @override
  String diagHiddenFromAll(String category) {
    return '$category dold i Alla';
  }

  @override
  String diagBackInAll(String category) {
    return '$category tillbaka i Alla';
  }

  @override
  String diagChipSemanticLabel(String category, int count) {
    return '$category, $count';
  }

  @override
  String diagChipHiddenSemanticLabel(String category, int count) {
    return '$category, $count, dold i Alla';
  }

  @override
  String diagEventCount(int shown, int total) {
    return '$shown av $total händelser';
  }

  @override
  String diagDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tidigare händelser kastades – loggen börjar mitt i förloppet',
      one: '$count tidigare händelse kastades – loggen börjar mitt i förloppet',
    );
    return '$_temp0';
  }

  @override
  String diagRepeatSpan(int count, String seconds) {
    return '×$count på $seconds s';
  }

  @override
  String roomContentTabSemantic(String count, String label) {
    return '$label, $count objekt';
  }

  @override
  String get mapAppsTitle => 'Kartor';

  @override
  String get mapAppsChoose => 'Öppna plats i';

  @override
  String get mapAppsRemember => 'Använd som standard';

  @override
  String get mapAppsAskEveryTime => 'Fråga varje gång';

  @override
  String get mapAppsBrowser => 'Webbläsare';

  @override
  String get mapAppsSubtitle => 'Välj var delade platser ska öppnas.';

  @override
  String get mapAppsUnavailable =>
      'Din förvalda kartapp är inte tillgänglig. Välj en annan.';

  @override
  String get mapAppsNoInstalled =>
      'Ingen kartapp som stöds hittades. Du kan använda webbläsaren.';

  @override
  String get interactionAnswersSearch => 'Sök personer eller svar';

  @override
  String get interactionFilterEmpty => 'Inga svar matchar det här filtret.';

  @override
  String get interactionRetry => 'Försök igen';

  @override
  String get cameraEditorScreenCaptionHint => 'Lägg till bildtext…';

  @override
  String get cameraEditorScreenCaptionViewOnceHint =>
      'Inga bildtexter på engångsfoton';

  @override
  String get cameraEditorScreenAddFromCameraSemanticLabel => 'Ta ett foto till';

  @override
  String cameraEditorScreenDiscardAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Slänga $count foton?',
      one: 'Slänga det här fotot?',
    );
    return '$_temp0';
  }

  @override
  String get cameraEditorScreenDiscardAllBody =>
      'Dina ändringar och bildtexter försvinner.';

  @override
  String get cameraEditorScreenDiscardAllConfirm => 'Släng';

  @override
  String get galleryTrayRecentsTitle => 'Senaste';

  @override
  String get galleryTrayBackToCameraLabel => 'Tillbaka till kameran';

  @override
  String get galleryTrayAllPhotosLabel => 'Alla foton';

  @override
  String get galleryTrayHandleLabel => 'Senaste foton';

  @override
  String get galleryTrayAllowPrompt => 'Se dina senaste foton här';

  @override
  String get galleryTrayAllowButton => 'Tillåt';

  @override
  String get galleryTrayDeniedPrompt => 'Åtkomst till bilder är av';

  @override
  String get galleryTraySettingsButton => 'Inställningar';

  @override
  String get galleryTrayLimitedNote => 'Visar bara foton du har tillåtit';

  @override
  String get galleryTrayManageButton => 'Hantera';

  @override
  String get galleryTrayEmpty => 'Inga foton än';

  @override
  String galleryTrayPhotoLabel(int index) {
    return 'Foto $index';
  }

  @override
  String get reactionLimitTitle => 'Du har nått reaktionsgränsen';

  @override
  String reactionLimitMessageBody(int limit) {
    return 'För snabbhetens, förståndets och varje emojis skull kan du lägga till upp till $limit reaktioner på ett meddelande, men inte fler. Ta tillbaka en för att få plats med en ny.';
  }

  @override
  String reactionLimitHighlightBody(int limit) {
    return 'I höjdpunkter har var och en $limit reaktioner, så att varje reaktion fortfarande betyder något. Ta tillbaka en för att få plats med en ny favorit.';
  }

  @override
  String get reactionLimitDismiss => 'Uppfattat';

  @override
  String get reactionPickerYoursLabel => 'Dina reaktioner';

  @override
  String reactionPickerTakeBackSemantic(String emoji) {
    return 'Ta bort din $emoji-reaktion';
  }

  @override
  String get momentCommentsTitle => 'Kommentarer';

  @override
  String momentCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kommentarer',
      one: '1 kommentar',
      zero: 'Kommentera',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentsEmptyTitle => 'Inga kommentarer än';

  @override
  String get momentCommentsEmptyBody =>
      'Starta samtalet med några ord, ett klistermärke eller en GIF.';

  @override
  String get momentCommentHint => 'Skriv en kommentar…';

  @override
  String momentCommentReplyHint(String name) {
    return 'Svara $name…';
  }

  @override
  String momentCommentReplyingTo(String name) {
    return 'Svarar $name';
  }

  @override
  String get momentCommentCancelReply => 'Avbryt svar';

  @override
  String get momentCommentReply => 'Svara';

  @override
  String momentCommentViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Visa $count svar',
      one: 'Visa 1 svar',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentHideReplies => 'Dölj svar';

  @override
  String get momentCommentDelete => 'Radera kommentar';

  @override
  String get momentCommentDeleteConfirm =>
      'Radera den här kommentaren? Svaren försvinner också.';

  @override
  String get momentCommentDeleteConfirmButton => 'Radera';

  @override
  String get momentCommentSend => 'Skicka';

  @override
  String get momentCommentExpressions => 'Klistermärken och GIF:ar';

  @override
  String get momentCommentFailed =>
      'Det gick inte att publicera din kommentar. Försök igen.';

  @override
  String get momentCommentAuthorBadge => 'Skapare';

  @override
  String get momentCommentLike => 'Gilla';

  @override
  String get momentCommentStickerAlt => 'Klistermärke';

  @override
  String get momentCommentGifAlt => 'GIF';

  @override
  String get momentCommentPosted => 'Kommentaren publicerad';

  @override
  String momentCommentsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Visa alla $count kommentarer',
      one: 'Visa 1 kommentar',
    );
    return '$_temp0';
  }

  @override
  String momentReactorsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count till',
      one: '1 till',
    );
    return '$name och $_temp0';
  }

  @override
  String get storageKindPhotos => 'Bilder';

  @override
  String get storageKindVideos => 'Videor';

  @override
  String get storageKindVideoMessages => 'Videonotiser';

  @override
  String get storageKindVoice => 'Röstmeddelanden';

  @override
  String get storageKindFiles => 'Filer';

  @override
  String get storageKindStickers => 'Klistermärken och GIF:ar';

  @override
  String get storageKindChatHistory => 'Chatthistorik';

  @override
  String get storageKindOther => 'Övrigt';

  @override
  String get dataUsageKindCalls => 'Samtal';

  @override
  String get dataStorageTitle => 'Data och lagring';

  @override
  String get settingsSearchKwDataStorage =>
      'lagring cache minne utrymme rensa ladda ner automatisk nedladdning dataanvändning mobildata mobil wifi spara bilder galleri storage';

  @override
  String get storageUsageTitle => 'Lagringsanvändning';

  @override
  String get dataUsageTitle => 'Dataanvändning';

  @override
  String get dataStorageAutoDownloadHeader => 'Automatisk nedladdning av media';

  @override
  String get dataStorageUsingCellular => 'Med mobildata';

  @override
  String get dataStorageUsingWifi => 'Med Wi-Fi';

  @override
  String get dataStorageNowTag => 'Nu';

  @override
  String get autoDownloadReset => 'Återställ automatisk nedladdning';

  @override
  String get autoDownloadResetTitle =>
      'Återställa standardinställningarna för automatisk nedladdning?';

  @override
  String get dataStorageSaveHeader => 'Spara i Bilder';

  @override
  String get dataStorageSaveFooter =>
      'Spara nya bilder och videor från de här chattarna automatiskt i ditt bildbibliotek.';

  @override
  String get dataStorageCallsHeader => 'Samtal';

  @override
  String get dataStorageLessDataForCalls => 'Använd mindre data för samtal';

  @override
  String get dataStorageCallsFooter =>
      'Använder mindre data på svaga eller begränsade nätverk, med något lägre ljud- och videokvalitet.';

  @override
  String get dataStorageCallsNever => 'Aldrig';

  @override
  String get dataStorageCallsCellular => 'Med mobildata';

  @override
  String get dataStorageCallsAlways => 'Alltid';

  @override
  String get dataStorageOff => 'Av';

  @override
  String get dataStorageChatsPrivate => 'Privata chattar';

  @override
  String get dataStorageChatsGroups => 'Grupper';

  @override
  String get dataStorageChatsPublic => 'Offentliga rum';

  @override
  String get dataStorageNetCellular => 'Mobildata';

  @override
  String get dataStorageNetWifi => 'Wi-Fi';

  @override
  String get autoDownloadMaster => 'Ladda ner media automatiskt';

  @override
  String get autoDownloadUsageHeader => 'Dataanvändning';

  @override
  String get autoDownloadPresetLow => 'Låg';

  @override
  String get autoDownloadPresetMedium => 'Medel';

  @override
  String get autoDownloadPresetHigh => 'Hög';

  @override
  String get autoDownloadCustomFooter =>
      'Du har anpassat inställningarna. Dra i reglaget för att byta tillbaka till en förinställning.';

  @override
  String get autoDownloadTypesHeader => 'Medietyper';

  @override
  String get autoDownloadVideosTitle => 'Videor och videonotiser';

  @override
  String get autoDownloadVoiceFooter =>
      'Röstmeddelanden och klistermärken är små, så de laddas alltid ner automatiskt.';

  @override
  String get autoDownloadAllChats => 'Alla chattar';

  @override
  String autoDownloadUpToIn(String size, String chats) {
    return 'Upp till $size i $chats';
  }

  @override
  String autoDownloadSummaryUpTo(String kind, String size) {
    return '$kind upp till $size';
  }

  @override
  String get autoDownloadSummaryVoiceOnly => 'Bara röstmeddelanden';

  @override
  String get autoDownloadInHeader => 'Ladda ner automatiskt i';

  @override
  String get autoDownloadMaxSizeHeader => 'Maximal filstorlek';

  @override
  String autoDownloadMaxSizeVideoFooter(String size) {
    return 'Videor upp till $size laddas ner automatiskt. Större väntar tills du trycker.';
  }

  @override
  String autoDownloadMaxSizeFileFooter(String size) {
    return 'Filer upp till $size laddas ner automatiskt. Större väntar tills du trycker.';
  }

  @override
  String get autoDownloadGateLoad => 'Ladda ner bild';

  @override
  String get saveToPhotosHeader => 'Spara automatiskt';

  @override
  String get saveToPhotosFooter =>
      'Nya bilder och videor du får i de här chattarna läggs till i ditt bildbibliotek när de laddas ner.';

  @override
  String get saveToPhotosMaxVideoHeader => 'Maximal videostorlek';

  @override
  String get saveToPhotosNoAccess =>
      'Tillåt åtkomst till bildbiblioteket i Inställningar för att spara automatiskt.';

  @override
  String get saveToPhotosPhotosAndVideos => 'Bilder och videor';

  @override
  String get storageCalculating => 'Beräknar…';

  @override
  String storageShareOfFree(String percent) {
    return 'MonkeyHub använder $percent av ditt lediga utrymme.';
  }

  @override
  String get storageEmpty => 'Inget är cachat just nu.';

  @override
  String storageClearAllButton(String size) {
    return 'Rensa hela cachen $size';
  }

  @override
  String storageClearSelectedButton(String size) {
    return 'Rensa markerade $size';
  }

  @override
  String storageClearChatButton(String size) {
    return 'Rensa cache $size';
  }

  @override
  String get storageClearFooter =>
      'Allt finns kvar i molnet och laddas ner igen när du behöver det.';

  @override
  String get storageClearAllTitle => 'Rensa hela cachen?';

  @override
  String get storageClearSelectedTitle => 'Rensa markerade objekt?';

  @override
  String get storageClearBody =>
      'Dina meddelanden finns kvar. Media laddas ner igen när du öppnar den.';

  @override
  String storageClearConfirm(String size) {
    return 'Rensa $size';
  }

  @override
  String storageFreed(String size) {
    return '$size frigjort';
  }

  @override
  String storageCleanupTitle(String size) {
    return 'Frigör $size';
  }

  @override
  String get storageCleanupSubtitle => 'Media du inte har öppnat på en månad';

  @override
  String get storageCleanupAction => 'Rensa';

  @override
  String get storageCleanupFooter =>
      'Rensar bara media som ingen har tittat på på 30 dagar. Sparade meddelanden rörs aldrig.';

  @override
  String get storageAutoRemoveHeader => 'Ta bort cachad media automatiskt';

  @override
  String get storageAutoRemoveFooter =>
      'Media du inte har öppnat på så här länge tas bort från enheten för att spara utrymme. Den finns kvar i molnet, och Sparade meddelanden behålls alltid.';

  @override
  String get dataStorageKeepNever => 'Aldrig';

  @override
  String get dataStorageKeepMonth => '1 månad';

  @override
  String get dataStorageKeepWeek => '1 vecka';

  @override
  String get dataStorageKeepDay => '1 dag';

  @override
  String get storageLimitHeader => 'Maximal cachestorlek';

  @override
  String get storageLimitFooter =>
      'Om cachen blir större än så tas den media du öppnade för längst tid sedan bort först.';

  @override
  String get dataStorageLimitNone => 'Ingen gräns';

  @override
  String get storageTabChats => 'Chattar';

  @override
  String get storageTabMedia => 'Media';

  @override
  String get storageTabFiles => 'Filer';

  @override
  String get storageNoChats => 'Ingen chatt har något cachat än.';

  @override
  String get storageNoMedia => 'Inga bilder eller videor är cachade än.';

  @override
  String get storageNoFiles => 'Inga filer är cachade än.';

  @override
  String get storageOpenPhoto => 'Öppna bild';

  @override
  String get storageOpenVideo => 'Öppna video';

  @override
  String get storageSelect => 'Välj';

  @override
  String storageChatShare(String percent) {
    return 'Den här chatten använder $percent av din cache.';
  }

  @override
  String get storageChatUnknown => 'Chatt du har lämnat';

  @override
  String dataUsageSince(String date) {
    return 'Sedan $date';
  }

  @override
  String get dataUsageAll => 'Alla';

  @override
  String get dataUsageNothingYet =>
      'Inget har räknats på det här nätverket än.';

  @override
  String get dataUsageTapHint =>
      'Tryck på en kategori för att se vad som skickats och tagits emot.';

  @override
  String get dataUsageSent => 'Skickat';

  @override
  String get dataUsageReceived => 'Mottaget';

  @override
  String get dataUsageTotalHeader => 'Total nätverksanvändning';

  @override
  String get dataUsageFootnote =>
      'Räknar media och samtal. Själva meddelandena är små och räknas inte med.';

  @override
  String get dataUsageReset => 'Nollställ statistik';

  @override
  String get dataUsageResetTitle =>
      'Nollställa statistiken för dataanvändning?';

  @override
  String get dataUsageResetBody => 'Räkningen börjar om från nu.';

  @override
  String get storageKindCompanions => 'Följeslagare';

  @override
  String get storageCompanionsNote =>
      'Följeslagare rensas inte med cachen. Tryck på dem för att hantera deras nedladdningar.';

  @override
  String storageCategoryCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count objekt, $size',
      one: '1 objekt, $size',
    );
    return '$_temp0';
  }

  @override
  String get storageSelectAll => 'Markera alla';

  @override
  String get storageDeselectAll => 'Avmarkera alla';

  @override
  String get storageCategoryEmpty =>
      'Inget av den här typen är cachat just nu.';

  @override
  String get storageChatHistoryFooter =>
      'Bara kopian på den här enheten tas bort. Meddelandena finns kvar i chatten och laddas igen nästa gång du öppnar den.';

  @override
  String get storageCategoryHint =>
      'Tryck på en kategori för att se vad den innehåller, eller på cirkeln för att lämna den utanför.';

  @override
  String storageChatRemovedNamed(String names) {
    return '$names · borttagen chatt';
  }
}
