// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'SERVEUR INACCESSIBLE';

  @override
  String get bootErrorBody => 'Convex ne s’est pas initialisé.';

  @override
  String get bootErrorRetry => 'RÉESSAYER';

  @override
  String get incomingCallNotificationTitle => 'Appel entrant';

  @override
  String get incomingCallFallbackCaller => 'Quelqu’un t’appelle';

  @override
  String get settingsLanguageRowLabel => 'LANGUE';

  @override
  String get languageScreenTitle => 'langue.';

  @override
  String get languageScreenSubtitle =>
      'choisis la langue des menus et des messages de l’app';

  @override
  String get languageOptionSystem => 'SYSTÈME';

  @override
  String get languageOptionSystemSub => 'utilise la langue de ton appareil';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => 'ACTIF';

  @override
  String get languageValueSystem => 'Système';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack =>
      'impossible de demander pour l’instant — réessaie';

  @override
  String get roomScreenGateSendMessages => 'envoyer des messages ici';

  @override
  String get roomScreenGateSendMedia =>
      'envoyer des photos ou des messages vocaux';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'jusqu’à $max à la fois';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'SUPPRIMER $count MESSAGES',
      one: 'SUPPRIMER LE MESSAGE',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Ça les supprime pour tout le monde dans cette conversation. C’est irréversible.';

  @override
  String get roomScreenDeleteConfirmButton => 'SUPPRIMER POUR TOUT LE MONDE';

  @override
  String get roomScreenJumpFailedSnack => 'impossible d’aller à ce message';

  @override
  String get roomScreenUnreadDivider => 'Messages non lus';

  @override
  String get roomScreenViewOnceAlreadyViewed =>
      'tu as déjà ouvert cette photo.';

  @override
  String get roomScreenViewOnceGone => 'cette photo n’est plus disponible.';

  @override
  String get roomScreenViewOnceNetworkError =>
      'impossible de charger cette photo.';

  @override
  String get roomScreenFileReadFailedSnack => 'impossible de lire ce fichier';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'les fichiers sont limités à $size';
  }

  @override
  String get roomScreenRoomGone => 'salon disparu';

  @override
  String get roomScreenCopiedSnack => 'copié';

  @override
  String get roomScreenNameCopiedSnack => 'nom copié';

  @override
  String get roomScreenPinLimitSnack =>
      'trop de messages épinglés — désépingle-en un d’abord';

  @override
  String get roomScreenPinFailedSnack => 'impossible d’épingler ça';

  @override
  String get roomScreenReportSentSnack =>
      'signalement envoyé en toute discrétion. la personne ne sera pas informée.';

  @override
  String get roomScreenDeselectMessageSemantic => 'Désélectionner le message';

  @override
  String get roomScreenSelectMessageSemantic => 'Sélectionner le message';

  @override
  String roomScreenMemberCountBadge(Object count) {
    return '$count DEDANS';
  }

  @override
  String roomScreenTtlSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count secondes',
      one: '$count seconde',
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
      other: '$count heures',
      one: '$count heure',
    );
    return '$_temp0';
  }

  @override
  String roomScreenEphemeralNotice(Object ttl) {
    return 'ce salon est éphémère. les messages disparaissent après $ttl, lus ou non.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count MESSAGES';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'Espace secret';

  @override
  String get roomScreenSecretSpaceBody =>
      'Les messages de ce salon sont éphémères. Ils sont automatiquement supprimés selon les règles de sécurité du salon.';

  @override
  String get roomScreenAutoDeleteTitle => 'Suppression auto';

  @override
  String get roomScreenAutoDeleteVaries => 'Variable';

  @override
  String get roomScreenAutoDeleteTimed => 'Minuté';

  @override
  String get roomScreenNoCaptureTitle => 'Sans capture';

  @override
  String get roomScreenNoCaptureSubtitle => 'Captures d\'écran restreintes';

  @override
  String get roomScreenMorePrivacyTitle => 'Encore plus de confidentialité';

  @override
  String get roomScreenMorePrivacySubtitle =>
      'Profite de fonctionnalités de sécurité supplémentaires, en plus de notre engagement déjà fort pour la confidentialité.';

  @override
  String get roomScreenNoMessagesTitle => 'Aucun message';

  @override
  String get roomScreenNoMessagesSubtitle =>
      'Lance la conversation en envoyant un message';

  @override
  String get roomScreenViewProfilePictureSemantic => 'voir la photo de profil';

  @override
  String get roomScreenViewRoomPictureSemantic => 'voir la photo du salon';

  @override
  String get messageBubbleFileFallbackName => 'document';

  @override
  String get messageBubbleAttachmentStatusFailed => 'échec';

  @override
  String get messageBubbleAttachmentStatusSending => 'envoi…';

  @override
  String get messageBubbleViewOnceOpened => 'ouverte';

  @override
  String get messageBubbleViewOnceExpired => 'expirée';

  @override
  String get messageBubbleViewOnceLabel => 'vue unique';

  @override
  String get messageBubbleViewOnceTapToView => 'touche pour voir';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Photo';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'photo à vue unique, touche pour voir';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'réessayer l\'envoi';

  @override
  String get messageBubbleDiscardSemanticLabel => 'supprimer';

  @override
  String get profileScreenAccountSection => 'COMPTE';

  @override
  String get profileScreenAddEmailPlaceholder => 'ajouter un e-mail';

  @override
  String get profileScreenAddEmailTitle => 'ajouter un e-mail ?';

  @override
  String get profileScreenAddNameTitle => 'ajouter un nom ?';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count en attente';
  }

  @override
  String get profileScreenApprovalsLabel => 'APPROBATIONS';

  @override
  String get profileScreenApprovalsNothingWaiting => 'rien en attente';

  @override
  String get profileScreenApproveAction => 'APPROUVER';

  @override
  String get profileScreenBlockAction => 'BLOQUER';

  @override
  String get profileScreenBlockedDmWiped =>
      'bloqué et DM supprimé. cette personne ne sera pas prévenue.';

  @override
  String get profileScreenBlockedOnly =>
      'bloqué. cette personne ne sera pas prévenue.';

  @override
  String get profileScreenBlockedUsers => 'UTILISATEURS BLOQUÉS';

  @override
  String get profileScreenCancelAction => 'ANNULER';

  @override
  String get profileScreenCancelRequestAction => 'ANNULER LA DEMANDE';

  @override
  String get profileScreenChangeAction => 'MODIFIER';

  @override
  String get profileScreenChangeEmailTitle => 'modifier l\'e-mail ?';

  @override
  String get profileScreenChangeNameTitle => 'modifier le nom ?';

  @override
  String get profileScreenChangeProfilePictureSemantic =>
      'modifier la photo de profil';

  @override
  String get profileScreenChangeRecoveryPhrase =>
      'MODIFIER LA PHRASE DE RÉCUPÉRATION';

  @override
  String get profileScreenChooseFromLibrary => 'CHOISIR DANS LA GALERIE';

  @override
  String get profileScreenCouldNotSaveImage =>
      'impossible d\'enregistrer l\'image.';

  @override
  String get profileScreenDeleteAccount => 'SUPPRIMER LE COMPTE';

  @override
  String get profileScreenEmailHint =>
      'facultatif — jamais visible par personne';

  @override
  String get profileScreenEmailSectionLabel => 'E-MAIL';

  @override
  String get profileScreenErrorAlreadyFriends => 'vous êtes déjà amis.';

  @override
  String get profileScreenErrorGeneric => 'impossible de faire ça.';

  @override
  String get profileScreenErrorNotAccepting =>
      'cette personne n\'accepte pas de demandes d\'ami en ce moment.';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      'cette personne t\'a déjà envoyé une demande — regarde tes demandes.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'demande déjà envoyée.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'tu as bloqué cette personne — débloque-la d\'abord.';

  @override
  String get profileScreenErrorUserNotFound =>
      'ce n\'est pas possible pour l\'instant.';

  @override
  String get profileScreenNameNotSaved =>
      'Impossible d\'enregistrer votre nom. Veuillez réessayer.';

  @override
  String get profileScreenFamilyAddChild => 'ajouter un enfant';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enfants',
      one: '$count enfant',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => 'FAMILLE';

  @override
  String get profileScreenFriendsChip => 'AMIS';

  @override
  String get profileScreenGrownUpOnlyNote =>
      'Seul un grand peut faire ça — il faut son code ou son mot de passe.';

  @override
  String get profileScreenGuardiansCanSee =>
      'Ils peuvent voir quand tu es en ligne et à qui tu parles.';

  @override
  String get profileScreenHandPhoneBack => 'RENDRE CE TÉLÉPHONE';

  @override
  String get profileScreenIncomingRequestChip => 'DEMANDE REÇUE';

  @override
  String get profileScreenJustTappedAction => 'TOUCHÉ PAR ERREUR';

  @override
  String get settingsScreenSectionHelpAndLegal => 'AIDE ET MENTIONS LÉGALES';

  @override
  String get settingsScreenLicence => 'LICENCE';

  @override
  String get profileScreenLinkedAccountsLabel => 'COMPTES LIÉS';

  @override
  String get profileScreenLinkedAccountsNone => 'aucun compte lié';

  @override
  String get profileScreenMyGrownUps => 'MES GRANDES PERSONNES';

  @override
  String get profileScreenNameHint => 'comment le salon te verra';

  @override
  String get profileScreenChangeUsernameTitle =>
      'changer de nom d’utilisateur ?';

  @override
  String get profileScreenChangeUsernameWarning =>
      'C’est avec ça que tu te connectes, donc tu saisiras le nouveau à partir de maintenant. Ton ancien nom d’utilisateur est libéré et quelqu’un d’autre peut le prendre, et tu ne pourras plus le changer pendant 30 jours. Les anciens messages qui te mentionnaient gardent l’ancien nom.';

  @override
  String get profileScreenUsernameHint => 'comment tes amis te trouvent';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return 'modifiable à nouveau le $date';
  }

  @override
  String get profileScreenUsernamePasswordTitle =>
      'confirme que c’est bien toi';

  @override
  String get profileScreenUsernamePasswordAction =>
      'CHANGER DE NOM D’UTILISATEUR';

  @override
  String get profileScreenUsernameProviderTitle => 'confirme avec ta connexion';

  @override
  String profileScreenUsernameChanged(String username) {
    return 'Tu es maintenant @$username.';
  }

  @override
  String get profileScreenUsernameNotSaved =>
      'Impossible de changer ton nom d’utilisateur. Réessaie.';

  @override
  String get usernameStatusChecking => 'vérification…';

  @override
  String get usernameStatusAvailable => 'disponible';

  @override
  String get usernameStatusTaken => 'déjà pris';

  @override
  String get usernameStatusReserved => 'indisponible';

  @override
  String get usernameStatusInvalid => '1–32 caractères';

  @override
  String get usernameStatusUnknown => 'vérification impossible';

  @override
  String get profileScreenNobodyLookingAfter =>
      'personne ne s’occupe encore de ce compte';

  @override
  String get profileScreenNotAcceptingRequestsAction =>
      'N’ACCEPTE PAS LES DEMANDES';

  @override
  String get profileScreenNotConnectedChip => 'AUCUN LIEN';

  @override
  String get profileScreenOpenDmAction => 'OUVRIR LE DM';

  @override
  String get profileScreenPhotoPermissionDenied => 'permission photo refusée.';

  @override
  String get settingsScreenPrivacyPolicy => 'POLITIQUE DE CONFIDENTIALITÉ';

  @override
  String get profileScreenPrivacySection => 'CONFIDENTIALITÉ';

  @override
  String get profileScreenProfilePictureTitle => 'PHOTO DE PROFIL';

  @override
  String get profileScreenRedactedFriend =>
      'certains champs sont masqués par ses paramètres.';

  @override
  String get profileScreenRedactedStranger =>
      'vue limitée — cette personne partage plus avec ses amis.';

  @override
  String get profileScreenReportAction => 'SIGNALER';

  @override
  String get profileScreenReportSent =>
      'signalement envoyé en privé. la personne ne sera pas prévenue.';

  @override
  String get profileScreenRequestPendingChip => 'DEMANDE EN ATTENTE';

  @override
  String get profileScreenSaveAction => 'ENREGISTRER';

  @override
  String get profileScreenSavedToPhotos => 'enregistré dans les photos.';

  @override
  String get profileScreenSaveToPhotos => 'ENREGISTRER DANS LES PHOTOS';

  @override
  String get profileScreenSendRequestAction => 'ENVOYER UNE DEMANDE';

  @override
  String get profileScreenSetUpRecoveryPhrase =>
      'CONFIGURER LA PHRASE DE RÉCUPÉRATION';

  @override
  String get profileScreenSignOut => 'SE DÉCONNECTER';

  @override
  String get profileScreenTakeSelfie => 'PRENDRE UN SELFIE';

  @override
  String get profileScreenTapAgainToConfirmDelete =>
      'APPUIE ENCORE POUR CONFIRMER LA SUPPRESSION';

  @override
  String get settingsScreenTermsOfService => 'CONDITIONS D’UTILISATION';

  @override
  String get profileScreenThisPhoneSection => 'CE TÉLÉPHONE';

  @override
  String get profileScreenUnfriendAction => 'RETIRER DES AMIS';

  @override
  String get profileScreenViewProfilePictureSemantic =>
      'afficher la photo de profil';

  @override
  String get profileScreenVisibilityPreferences => 'PRÉFÉRENCES DE VISIBILITÉ';

  @override
  String get cameraEditorScreenCropPresetFree => 'LIBRE';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'ORIG.';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel =>
      'annuler le recadrage';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel =>
      'abandonner la photo';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'annuler';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'rétablir';

  @override
  String get cameraEditorScreenResetCropSemanticLabel =>
      'réinitialiser le recadrage';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'pivoter';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'recadrer';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'ce navigateur ne peut pas ouvrir les photos HEIC';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'impossible d’ouvrir cette image';

  @override
  String get cameraEditorScreenCropDoneButton => 'TERMINÉ';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'reprendre la photo';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'ranger le stylo';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'dessiner sur la photo';

  @override
  String get cameraEditorScreenSendingButton => 'ENVOI…';

  @override
  String get cameraEditorScreenSendButton => 'ENVOYER';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'disparaît après la première ouverture';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'effacer le dessin';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel =>
      'vue unique : activée';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel =>
      'vue unique : désactivée';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD : activé';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD : désactivé';

  @override
  String get cameraEditorScreenHdNote => 'envoi en pleine résolution';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'couleur d’encre';

  @override
  String get glassScreenPanelLooks => 'STYLES';

  @override
  String get glassScreenPanelBottomBar => 'BARRE DU BAS';

  @override
  String get glassScreenPanelOtherSurfaces => 'AUTRES SURFACES';

  @override
  String get glassScreenPanelBarLayout => 'DISPOSITION DE LA BARRE';

  @override
  String get glassScreenTitle => 'verre.';

  @override
  String get glassScreenSubtitle =>
      'la part de ce qu’il y a derrière qui transparaît';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'TOUS LES $max EMPLACEMENTS SONT PLEINS';
  }

  @override
  String get glassScreenSaveCurrentAs => 'ENREGISTRER SOUS…';

  @override
  String get glassScreenResetEveryDial => 'RÉINITIALISER TOUS LES RÉGLAGES';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'RÉINITIALISER SUR $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'la barre de saisie, les en-têtes, les boutons d’appel — tout ce qui se trouve au-dessus du texte plutôt qu’au-dessus du contenu qui défile';

  @override
  String get glassScreenMatchBottomBar => 'ASSORTIR À LA BARRE DU BAS';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'modifié — enregistre-le comme nouveau style, ou réinitialise-le';

  @override
  String get glassScreenCustomPresetName => 'Personnalisé';

  @override
  String get glassScreenUnsavedSubtitle =>
      'non enregistré — donne-lui un nom pour le garder';

  @override
  String get glassScreenSaveDialogTitle => 'enregistrer ce look sous';

  @override
  String get glassScreenNoRoomToast =>
      'plus de place — supprime d\'abord un look';

  @override
  String get glassScreenRenameDialogTitle => 'renommer';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'supprimer $name ?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'le look reste à l\'écran — il perd juste son nom.';

  @override
  String get glassScreenKeepButton => 'garder';

  @override
  String get glassScreenDeleteButton => 'supprimer';

  @override
  String get glassScreenNameHint => 'soirée tardive';

  @override
  String get glassScreenCancelButton => 'annuler';

  @override
  String get glassScreenSaveButton => 'enregistrer';

  @override
  String get glassScreenPreviewRoomName => '# balcon';

  @override
  String get glassScreenPreviewOnlineCount => '4 en ligne';

  @override
  String get glassScreenPreviewMessageHint => 'message';

  @override
  String get glassScreenPreviewCollapseLabel => 'réduire l\'aperçu';

  @override
  String get glassScreenPreviewExpandLabel => 'agrandir l\'aperçu';

  @override
  String get glassScreenPreviewBadge => 'APERÇU';

  @override
  String get glassScreenBuiltInLabel => 'intégré';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'écraser $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'renommer $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'supprimer $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'réinitialiser $label';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'a envoyé les photos du toit — les tuiles sont toutes fissurées';

  @override
  String get glassScreenBackdropMsgMert =>
      'ok mais qui amène vraiment l\'enceinte';

  @override
  String get glassScreenBackdropGroupFamily => 'famille';

  @override
  String get glassScreenBackdropMsgFamily =>
      'Anne : dîner à 20h, ne sois pas encore en retard';

  @override
  String get glassScreenBackdropMsgZeynep => 'je suis dehors';

  @override
  String get glassScreenBackdropMsgKerem =>
      'l\'endroit du coin fait du bon café';

  @override
  String get glassScreenBackdropGroupWork => 'travail';

  @override
  String get glassScreenBackdropMsgWork =>
      'le standup passe à 10h30 pour le reste de la semaine';

  @override
  String get glassScreenBackdropMsgElif =>
      'pas possible. renvoie-le, je l\'ai perdu';

  @override
  String get glassScreenBackdropMsgBaran => 'atterri 👍';

  @override
  String get glassScreenBackdropMsgAyse =>
      'le chat a appris à ouvrir la porte du balcon';

  @override
  String get glassScreenBackdropMsgCan => 'à samedi alors';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return 'en réponse à $name';
  }

  @override
  String get replyIndicatorViewOnceLabel => 'photo · vue unique';

  @override
  String get replyIndicatorVoiceMessageLabel => 'message vocal';

  @override
  String get replyIndicatorDocumentLabel => 'document';

  @override
  String get replyIndicatorMessageRemoved => 'message supprimé';

  @override
  String get threadOverlayMessageNotFound =>
      'impossible de retrouver ce message dans ce fil';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'impossible de trouver le fil auquel répondre';

  @override
  String get threadOverlayStillSending =>
      'toujours en cours d\'envoi — réessaie dans une seconde';

  @override
  String get threadOverlayCopiedToast => 'copié';

  @override
  String get threadOverlayNameCopiedToast => 'nom copié';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'coordonnées copiées';

  @override
  String get threadOverlayPinLimitToast =>
      'trop de messages épinglés — désépingle-en un d\'abord';

  @override
  String get threadOverlayPinFailedToast => 'impossible d\'épingler ça';

  @override
  String get threadOverlayReportedToast => 'signalé';

  @override
  String get threadOverlayUnavailable => 'fil indisponible';

  @override
  String get roomInfoScreenNameRequiredError => 'le nom est requis';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'mot de passe supprimé';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'quitter le salon ?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'tu pourras le rejoindre s\'il reste ouvert.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'QUITTER';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'supprimer le salon ?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'tous les messages d\'ici disparaissent avec lui. c\'est définitif.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'SUPPRIMER';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      'mettre fin à cette conversation ?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName perd aussi cette conversation — tous les messages disparaissent pour vous deux. c\'est définitif.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'TERMINER';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'l\'autre personne';

  @override
  String get roomInfoScreenConfirmCancelButton => 'ANNULER';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'un salon avec ce nom existe déjà';

  @override
  String get roomInfoScreenErrorNotOwner =>
      'seul le propriétaire peut faire ça';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'tu n\'as pas la permission';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'ce salon a disparu';

  @override
  String get roomInfoScreenRoomGone => 'salon disparu';

  @override
  String get roomInfoScreenNameLabel => 'NOM';

  @override
  String get roomInfoScreenNameHint => 'nom du salon';

  @override
  String get roomInfoScreenDescriptionLabel => 'DESCRIPTION';

  @override
  String get roomInfoScreenDescriptionHint => 'une ligne à propos du salon…';

  @override
  String get roomInfoScreenVisibilityLabel => 'VISIBILITÉ';

  @override
  String get roomInfoScreenPublicTitle => 'public';

  @override
  String get roomInfoScreenPublicSub => 'tout le monde peut le trouver';

  @override
  String get roomInfoScreenPrivateTitle => 'privé';

  @override
  String get roomInfoScreenPrivateSub => 'sur invitation uniquement';

  @override
  String get roomInfoScreenMessageLifeLabel => 'DURÉE DE VIE DES MESSAGES';

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
  String get roomInfoScreenPasswordLabel => 'MOT DE PASSE';

  @override
  String get roomInfoScreenLockedBadge => 'VERROUILLÉ';

  @override
  String get roomInfoScreenNoneBadge => 'AUCUN';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      'ce salon est protégé. par sécurité, le mot de passe actuel n\'est pas affiché — entres-en un nouveau pour le remplacer.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'remplacer le mot de passe…';

  @override
  String get roomInfoScreenSetPasswordHint =>
      'verrouiller avec un mot de passe…';

  @override
  String get roomInfoScreenRemovePasswordButton => 'SUPPRIMER LE MOT DE PASSE';

  @override
  String get roomInfoScreenSharedContentLabel => 'CONTENU PARTAGÉ';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return 'MEMBRES · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => 'DÉPART…';

  @override
  String get roomInfoScreenLeaveRoomButton => 'QUITTER LE SALON';

  @override
  String get roomInfoScreenDeletingButton => 'SUPPRESSION…';

  @override
  String get roomInfoScreenDeleteButtonLabel => 'SUPPRIMER';

  @override
  String get roomInfoScreenEndingConversationButton => 'FIN EN COURS…';

  @override
  String get roomInfoScreenEndConversationButton =>
      'METTRE FIN À LA CONVERSATION';

  @override
  String get roomInfoScreenHeaderConversation => 'CONVERSATION';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'PARAMÈTRES DU SALON';

  @override
  String get roomInfoScreenViewProfilePictureSemantic =>
      'voir la photo de profil';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'voir la photo du salon';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic =>
      'changer la photo du salon';

  @override
  String get roomInfoScreenAddRoomPictureSemantic =>
      'ajouter une photo au salon';

  @override
  String get roomInfoScreenOwnerBadge => 'PROPRIÉTAIRE';

  @override
  String get roomInfoScreenNoneCount => 'aucun';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'l\'accès à la caméra est désactivé.\nactive-le dans Réglages pour prendre une photo.';

  @override
  String get cameraScreenOpeningSystemCamera =>
      'ouverture de l\'appareil photo du système…';

  @override
  String get cameraScreenCloseButtonLabel => 'fermer l\'appareil photo';

  @override
  String get cameraScreenLowLightBoostOnLabel =>
      'boost en basse lumière : activé';

  @override
  String get cameraScreenLowLightBoostOffLabel =>
      'boost en basse lumière : désactivé';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'flash : $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'choisir dans la galerie';

  @override
  String get cameraScreenSwitchCameraLabel => 'changer de caméra';

  @override
  String get cameraScreenTakePhotoLabel => 'prendre une photo';

  @override
  String get childPolicyScreenAddByUsernameLabel =>
      'AJOUTER PAR NOM D’UTILISATEUR';

  @override
  String get childPolicyScreenAddCta => 'AJOUTER';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'Cette personne obtient exactement les mêmes droits que toi : chaque demande à approuver, chaque réglage à modifier, et le pouvoir de te retirer. $name la considère aussitôt comme de la famille.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading =>
      'AJOUTER UNE GRANDE PERSONNE';

  @override
  String get childPolicyScreenAddGuardianHint => 'son nom d’utilisateur';

  @override
  String get childPolicyScreenAllowCta => 'AUTORISER';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'On ne te redemandera plus rien à ce sujet — que $childName ajoute cette personne, ou que cette personne ajoute $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'AUTORISER QUELQU’UN';

  @override
  String get childPolicyScreenAskToAddLabel => 'DEMANDER À AJOUTER';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'famille uniquement — pas de nouvelles demandes';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'peut te demander la permission pour de nouvelles personnes';

  @override
  String get childPolicyScreenBothFinalNote =>
      'Ces deux actions sont définitives. Pour te retirer à la place, c’est dans GRANDES PERSONNES.';

  @override
  String get childPolicyScreenCallsLabel => 'APPELS';

  @override
  String get childPolicyScreenCallsOffDesc => 'messages uniquement';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'voix + vidéo avec les personnes autorisées';

  @override
  String get childPolicyScreenCancelLabel => 'ANNULER';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Annuler';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'ajouté — la demande est en route';

  @override
  String get childPolicyScreenContactAddedToList =>
      'ajouté à la liste des autorisés';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'CRÉER DES SALONS';

  @override
  String get childPolicyScreenCreateRoomsOffDesc =>
      'ne peut pas créer de salons';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'peut créer ses propres salons privés';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Tout disparaît : ses messages, ses photos, ses salons et ses amis. C’est irréversible, et le nom d’utilisateur est libéré pour quelqu’un d’autre.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'impossible de supprimer le compte — réessaie';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return 'SUPPRIMER LE COMPTE DE $name ?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Messages, photos, salons et amis, tout disparaît. Irréversible.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'SUPPRIMER LE COMPTE DE $name';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'SUPPRIMER POUR TOUJOURS';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'impossible de l’ajouter — réessaie';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'c’est son propre nom d’utilisateur';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'un enfant ne peut pas être une grande personne';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'ça n’a pas marché — réessaie';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'quelqu’un doit s’occuper de lui — ajoute d’abord une autre grande personne';

  @override
  String get childPolicyScreenErrorNotYours =>
      'ce n’est pas à toi de changer ça';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'aucun compte avec ce pseudo';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'Il devient un compte normal avec ce mot de passe, et chaque grande personne perd toute visibilité. Impossible de revenir en arrière — il devrait être réinvité comme n’importe qui d’autre.';

  @override
  String get childPolicyScreenGraduateCta => 'DIPLÔMER';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'Il garde tout et reçoit un mot de passe. Tu perds toute visibilité. Irréversible.';

  @override
  String get childPolicyScreenGraduateDangerLabel =>
      'PASSER À UN COMPTE COMPLET';

  @override
  String get childPolicyScreenGraduateFailed =>
      'impossible de le diplômer — réessaie';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'DIPLÔMER $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'un mot de passe pour lui';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Retirer un salon les en fait sortir aussi. Retirer une personne supprime aussi leur conversation — pour les deux.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Tout le monde ici peut approuver, changer les réglages et tout voir. N’importe lequel peut agir seul — rien n’attend les autres.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'ajouté — il peut s’occuper de lui maintenant';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name retiré';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (toi)';
  }

  @override
  String get childPolicyScreenLoading => 'chargement…';

  @override
  String get childPolicyScreenLockedLabel => 'VERROUILLÉ';

  @override
  String get childPolicyScreenMediaLabel => 'PHOTOS + VOIX';

  @override
  String get childPolicyScreenMediaOffDesc => 'texte seulement';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'il peut envoyer des photos, vidéos et notes vocales';

  @override
  String get childPolicyScreenNoRoomsYet => 'pas encore de salon';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'N’importe qui ici peut être ajouté sans qu’on te redemande — peu importe qui commence.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Toujours désactivé pour les enfants. Découvrir — la liste des salons appartenant à des gens que tu ne connais pas — est complètement masqué et ne peut pas être activé. Les salons auxquels quelqu’un les invite continuent de fonctionner normalement.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'SALONS PUBLICS';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian ne verra plus ni n’approuvera plus rien pour $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return 'RETIRER $name ?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'RETIRER';

  @override
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count membres';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'GRANDES PERSONNES';

  @override
  String get childPolicyScreenSectionPeopleAllowed => 'PERSONNES AUTORISÉES';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'SALONS AUTORISÉS';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'CE QU’IL PEUT FAIRE';

  @override
  String get childPolicyScreenSectionWhenDone => 'QUAND C’EST TERMINÉ';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'rien ne se passe tant que l’un des deux n’ajoute pas l’autre';

  @override
  String get childPolicyScreenSendNowOnDesc =>
      'la personne reçoit ta demande tout de suite';

  @override
  String get childPolicyScreenSendRequestNowLabel =>
      'ENVOYER LA DEMANDE MAINTENANT';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'Tu es la seule grande personne de $name, alors tu ne peux pas juste partir — ajoute quelqu’un d’autre d’abord, ou utilise l’une de ces options.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'SE RETIRER';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'Tu perdras toute visibilité sur le compte de $name — ses demandes, ses contacts, ses salons. Les autres grandes personnes continuent de veiller sur $name.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'ARRÊTER DE SUPERVISER';

  @override
  String get childPolicyScreenStopSupervisingHeadline =>
      'ARRÊTER DE SUPERVISER ?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'impossible de les reprendre — réessaie';

  @override
  String get childPolicyScreenTakeBackLabel => 'REPRENDRE';

  @override
  String get childPolicyScreenUsernameHint => 'nom d’utilisateur';

  @override
  String get childPolicyScreenYou => 'toi';

  @override
  String get roomContentScreenDefaultDocumentName => 'document';

  @override
  String get roomContentScreenCouldntOpenFile =>
      'impossible d’ouvrir ce fichier';

  @override
  String get roomContentScreenCouldntShare => 'impossible de les partager';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count liens copiés',
      one: 'copié',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'SUPPRIMER $count MESSAGES',
      one: 'SUPPRIMER LE MESSAGE',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Ça les supprime pour tout le monde dans ce salon. C’est irréversible.';

  @override
  String get roomContentScreenDeleteForEveryone =>
      'SUPPRIMER POUR TOUT LE MONDE';

  @override
  String get roomContentScreenCancelTooltip => 'Annuler';

  @override
  String get roomContentScreenBackTooltip => 'Retour';

  @override
  String get roomContentScreenSelectingLabel => 'SÉLECTION';

  @override
  String get roomContentScreenSharedContentLabel => 'CONTENU PARTAGÉ';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sélectionnés',
      one: '$count sélectionné',
      zero: 'rien de sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'SÉLECTIONNER';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'TOUT';

  @override
  String get roomContentScreenEmptyMedia => 'pas encore de photos ni de vidéos';

  @override
  String get roomContentScreenEmptyFiles => 'pas encore de fichiers';

  @override
  String get roomContentScreenEmptyVoice => 'pas encore de notes vocales';

  @override
  String get roomContentScreenEmptyLinks => 'pas encore de liens';

  @override
  String get roomContentScreenEmptySaved =>
      'rien d’enregistré pour l’instant. appuie longuement sur un message et choisis ENREGISTRER.\n\nce que tu gardes ici n’appartient qu’à toi — un message épinglé, lui, est vu par toute la salle.';

  @override
  String get roomContentScreenLoadFailed => 'impossible de charger ça';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Message vocal de $name';
  }

  @override
  String get roomContentScreenForwardAction => 'TRANSFÉRER';

  @override
  String get roomContentScreenCopyAction => 'COPIER';

  @override
  String get roomContentScreenSaveAction => 'ENREGISTRER';

  @override
  String get roomContentScreenShareAction => 'PARTAGER';

  @override
  String get roomContentScreenInChatAction => 'DANS LE CHAT';

  @override
  String get roomContentScreenDeleteAction => 'SUPPRIMER';

  @override
  String get messageActionMenuReplyLabel => 'RÉPONDRE';

  @override
  String get messageActionMenuEditLabel => 'MODIFIER';

  @override
  String get messageStampEditedLabel => 'modifié';

  @override
  String get composerEditCardTitle => 'MODIFIER LE MESSAGE';

  @override
  String get spoilerRevealHint =>
      'Spoiler — activer pour révéler le texte masqué';

  @override
  String get formatToolbarFormatLabel => 'Format';

  @override
  String get formatToolbarBoldLabel => 'Gras';

  @override
  String get formatToolbarItalicLabel => 'Italique';

  @override
  String get formatToolbarStrikethroughLabel => 'Barré';

  @override
  String get formatToolbarUnderlineLabel => 'Souligné';

  @override
  String get formatToolbarSpoilerLabel => 'Spoiler';

  @override
  String get formatToolbarLinkLabel => 'Lien';

  @override
  String get formatToolbarCodeLabel => 'Code';

  @override
  String get linkInputSheetTitle => 'LIEN';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => 'APPLIQUER LE LIEN';

  @override
  String get linkInputSheetApplySub =>
      'Le texte sélectionné ouvrira cette adresse quand on le touche';

  @override
  String get linkInputSheetRemoveLabel => 'RETIRER LE LIEN';

  @override
  String get linkConfirmSheetTitle => 'OUVRIR CE LIEN ?';

  @override
  String get linkConfirmSheetOpenLabel => 'OUVRIR LE LIEN';

  @override
  String get linkConfirmSheetCancelLabel => 'ANNULER';

  @override
  String get roomScreenEditExpiredSnack =>
      'Trop tard pour modifier — les messages ne peuvent être modifiés que pendant 15 minutes.';

  @override
  String get roomScreenEditFailedSnack =>
      'Impossible d\'enregistrer la modification. Vérifie ta connexion et réessaie.';

  @override
  String get messageActionMenuForwardLabel => 'TRANSFÉRER';

  @override
  String get messageActionMenuViewThreadLabel => 'VOIR LE FIL';

  @override
  String get messageActionMenuCopyLabel => 'COPIER';

  @override
  String get messageActionMenuCopyNameLabel => 'COPIER LE NOM';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'COPIER LES COORDONNÉES';

  @override
  String get messageActionMenuPinLabel => 'ÉPINGLER';

  @override
  String get messageActionMenuUnpinLabel => 'DÉSÉPINGLER';

  @override
  String get messageActionMenuSelectLabel => 'SÉLECTIONNER';

  @override
  String get messageActionMenuProfileLabel => 'PROFIL';

  @override
  String get messageActionMenuDeleteLabel => 'SUPPRIMER';

  @override
  String get messageActionMenuReportLabel => 'SIGNALER';

  @override
  String get themeScreenTitle => 'thème.';

  @override
  String get themeScreenTapToApplyHint =>
      'appuie pour appliquer · ⛶ pour l\'aperçu complet';

  @override
  String get themeScreenFamilyBasicName => 'BASIQUE';

  @override
  String get themeScreenFamilyBasicTagline => 'inspiré d\'iOS · 5 palettes';

  @override
  String get themeScreenFamilyVaultName => 'COFFRE';

  @override
  String get themeScreenFamilyVaultTagline =>
      'dossier confidentiel · noir + ivoire';

  @override
  String get themeScreenFamilyOthersName => 'AUTRES';

  @override
  String get themeScreenFamilyOthersTagline => 'ambiances singulières';

  @override
  String get themeScreenActiveBadge => 'ACTIF';

  @override
  String get themeScreenTapToApplyLabel => 'appuie pour appliquer';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return 'ACTIF — $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return 'APPLIQUER $name';
  }

  @override
  String get themeScreenPreviewGreeting => 'hey, toi.';

  @override
  String get themeScreenPreviewSectionLabel => 'CONVERSATION';

  @override
  String get themeScreenPreviewRoomOneName => 'club design';

  @override
  String get themeScreenPreviewRoomOneSub => 'mia : a livré la nouvelle tuile.';

  @override
  String get themeScreenPreviewRoomTwoName => 'chambre · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => 'scellé dans 4h.';

  @override
  String get themeScreenPreviewBubbleQuestion => 'ça donne quoi ?';

  @override
  String get themeScreenPreviewBubbleAnswer => 'on dirait le bon.';

  @override
  String get callScreenVideoCallLabel => 'Appel vidéo';

  @override
  String get callScreenVoiceCallLabel => 'Appel vocal';

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · sonnerie…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · entrant';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · connexion…';
  }

  @override
  String get callScreenStatusConnected => 'connecté';

  @override
  String get callScreenStatusEnded => 'appel terminé';

  @override
  String get callScreenStatusFailed => 'échec de l\'appel';

  @override
  String get callScreenStatusSwitching => 'changement d\'appareil…';

  @override
  String get callScreenStatusMoved => 'déplacé';

  @override
  String get callScreenStatusReconnecting => 'reconnexion…';

  @override
  String get callScreenPoorConnectionLabel => 'mauvaise connexion';

  @override
  String get callScreenWeakConnectionLabel => 'connexion faible';

  @override
  String get callScreenControlUnmute => 'activer le micro';

  @override
  String get callScreenControlMute => 'couper le micro';

  @override
  String get callScreenControlCamOn => 'activer la caméra';

  @override
  String get callScreenControlCamOff => 'couper la caméra';

  @override
  String get callScreenControlFlip => 'basculer';

  @override
  String get callScreenControlSpeaker => 'haut-parleur';

  @override
  String get callScreenControlEnd => 'raccrocher';

  @override
  String get linkPreviewCardLinkLabel => 'LIEN';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name a accepté ta demande';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'cette demande a été retirée';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'demande refusée';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'tu as bloqué cette personne — débloque-la d\'abord.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'cette personne n\'accepte pas de demandes d\'ami en ce moment.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'impossible d\'envoyer. réessaie.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => 'DEMANDE REÇUE';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'NOUVELLE DEMANDE';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name veut démarrer une conversation.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'envoie quelques lignes. cette personne peut accepter ou refuser.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'rien ici ne reste nulle part tant que les deux personnes ne sont pas d\'accord.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'TYPE DE SALON';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'ÉPHÉMÈRE';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'STANDARD';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'DURÉE';

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
      'chuchote une première ligne · facultatif';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'ajoute un premier message · facultatif';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'chuchote · s\'efface automatiquement';

  @override
  String get friendRequestDraftScreenHintStartWith => 'de quoi commencer…';

  @override
  String get friendRequestDraftScreenApproveButton =>
      'ACCEPTER ET OUVRIR LE SALON';

  @override
  String get friendRequestDraftScreenDeclineButton => 'REFUSER';

  @override
  String get friendRequestDraftScreenCancelRequestButton =>
      'ANNULER LA DEMANDE';

  @override
  String get friendRequestDraftScreenAskGrownUpButton =>
      'DEMANDE À UNE GRANDE PERSONNE';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'ENVOYER LA DEMANDE';

  @override
  String get discoverScreenTitle => 'découvre.';

  @override
  String get discoverScreenCaptionPeople => 'gens';

  @override
  String get discoverScreenCaptionRooms => 'salons';

  @override
  String get discoverScreenCaptionRequests => 'demandes';

  @override
  String get discoverScreenPeopleBandLabel => 'GENS';

  @override
  String get discoverScreenRoomsBandLabel => 'SALONS';

  @override
  String get discoverScreenFindPeopleTitle => 'trouver des gens';

  @override
  String get discoverScreenFindPeopleSubtitleChild =>
      'tape un nom d\'utilisateur complet';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'cherche par @pseudo ou par nom';

  @override
  String get discoverScreenRequestsSectionLabel => 'DEMANDES';

  @override
  String get discoverScreenInboxQuiet => 'boîte tranquille';

  @override
  String get discoverScreenNothingPending => 'rien d\'envoyé';

  @override
  String get discoverScreenYourPeopleLabel => 'TES POTES';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'personne pour l\'instant — trouve des gens plus haut';

  @override
  String get discoverScreenNoFriendsYet => 'personne pour l\'instant';

  @override
  String get discoverScreenSearchRoomsTitle => 'chercher des salons';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'trouve un salon public par son nom';

  @override
  String get discoverScreenYourRoomsLabel => 'TES SALONS';

  @override
  String get discoverScreenNoRoomsYet => 'aucun salon pour l\'instant';

  @override
  String get discoverScreenIncomingLabel => 'reçues';

  @override
  String get discoverScreenOutgoingLabel => 'envoyées';

  @override
  String get discoverScreenIncomingLabelCaps => 'REÇUES';

  @override
  String get discoverScreenOutgoingLabelCaps => 'ENVOYÉES';

  @override
  String get discoverScreenJumpPeopleLabel => 'personnes';

  @override
  String get discoverScreenJumpRoomsLabel => 'salons';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Aller à $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'ajuster';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'UTILISER LA PHOTO';

  @override
  String get imageCropScreenSavingButton => 'ENREGISTREMENT…';

  @override
  String get imageCropScreenCancelButton => 'ANNULER';

  @override
  String get imageCropScreenHeicUnsupported =>
      'ce navigateur ne peut pas ouvrir les photos HEIC';

  @override
  String get imageCropScreenLoadFailed => 'impossible d’ouvrir cette image';

  @override
  String get imageCropScreenHintCircle =>
      'glisse pour déplacer, pince pour zoomer';

  @override
  String get imageCropScreenHintRect => 'glisse et pince pour cadrer';

  @override
  String get loginScreenSignInHeroMuted => 'content de\n';

  @override
  String get loginScreenSignInHeroInk => 'te revoir.';

  @override
  String get loginScreenSignInFirstHeroMuted => 'bonjour\n';

  @override
  String get loginScreenSignInFirstHeroInk => 'à toi.';

  @override
  String get loginScreenSignInCta => 'SE CONNECTER';

  @override
  String get loginScreenSignUpHeroMuted => 'nouveau\n';

  @override
  String get loginScreenSignUpHeroInk => 'membre.';

  @override
  String get loginScreenSignUpCta => 'OUVRIR UN COMPTE';

  @override
  String get loginScreenResetHeroMuted => 'réinitialise\n';

  @override
  String get loginScreenResetHeroInk => 'ton mot de passe.';

  @override
  String get loginScreenResetCta => 'RÉINITIALISER LE MOT DE PASSE';

  @override
  String get loginScreenErrorPasswordsDontMatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get loginScreenErrorChoosePasswordFirst =>
      'Choisis d’abord un mot de passe.';

  @override
  String get loginScreenUsernameHint => 'nom d’utilisateur';

  @override
  String get loginScreenPasswordHint => 'mot de passe';

  @override
  String get loginScreenConfirmPasswordHint => 'confirmer le mot de passe';

  @override
  String get loginScreenNameOptionalHint => 'nom (facultatif)';

  @override
  String get loginScreenRecoveryPhraseHint =>
      'ta phrase de récupération de 12 mots';

  @override
  String get loginScreenNewPasswordHint => 'nouveau mot de passe';

  @override
  String get loginScreenBackToSignIn => '← retour à la connexion';

  @override
  String get loginScreenForgotPassword => 'mot de passe oublié ?';

  @override
  String get loginScreenSettingUpKidsPhone => 'configurer un compte enfant';

  @override
  String get loginScreenLegalPrefix => 'En ouvrant un compte, tu acceptes les ';

  @override
  String get loginScreenLegalTermsLink => 'Conditions d’utilisation';

  @override
  String get loginScreenLegalMiddle => ' et la ';

  @override
  String get loginScreenLegalPrivacyLink => 'Politique de confidentialité';

  @override
  String get loginScreenLegalSuffix => '.';

  @override
  String get loginScreenAlreadyHerePrompt => 't\'es déjà là ? ';

  @override
  String get loginScreenSignInLink => 'se connecter';

  @override
  String get loginScreenNoAccountPrompt => 'pas de compte ? ';

  @override
  String get loginScreenOpenOneLink => 'en ouvrir un';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12 mots';
  }

  @override
  String get homeShellEmptyRoomHint =>
      'choisis un salon pour commencer à discuter';

  @override
  String get homeShellEmptySettingHint => 'choisis un paramètre';

  @override
  String get searchScreenHintPeople => 'rechercher des personnes…';

  @override
  String get searchScreenHintRooms => 'rechercher des salons…';

  @override
  String get searchScreenPeoplePromptChild =>
      'tape un pseudo complet pour trouver quelqu\'un de nouveau';

  @override
  String get searchScreenPeoplePromptDefault =>
      'recherche par pseudo ou par nom';

  @override
  String get searchScreenNoMatchChild =>
      'personne ne correspond — pour une nouvelle personne,\nil faut son pseudo complet, à la lettre près';

  @override
  String get searchScreenNoMatchDefault => 'personne ne correspond';

  @override
  String get searchScreenNoRoomsYet => 'pas encore de salon public';

  @override
  String get searchScreenNoRoomsMatch => 'aucun salon public ne correspond';

  @override
  String get searchScreenActionAskToAdd => 'DEMANDER L\'AJOUT';

  @override
  String get searchScreenActionSendRequest => 'ENVOYER UNE DEMANDE';

  @override
  String get searchScreenActionCancel => 'ANNULER';

  @override
  String get searchScreenActionApprove => 'APPROUVER';

  @override
  String get searchScreenActionOpenDm => 'OUVRIR LE DM';

  @override
  String get searchScreenAskedLabel => 'demandé';

  @override
  String get profileVisibilityScreenTitle => 'préférences de visibilité.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'contrôle ce que les autres voient — et comment ils peuvent te contacter.';

  @override
  String get profileVisibilityScreenSectionProfile => 'PROFIL';

  @override
  String get profileVisibilityScreenAvatarLabel => 'AVATAR';

  @override
  String get profileVisibilityScreenAvatarDesc => 'ta photo de profil';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => 'EN LIGNE / ABSENT';

  @override
  String get profileVisibilityScreenOnlineAwayDesc =>
      'si tu apparais actif en ce moment';

  @override
  String get profileVisibilityScreenLastSeenLabel => 'DERNIÈRE CONNEXION';

  @override
  String get profileVisibilityScreenLastSeenDesc =>
      'la dernière fois que tu étais dans le coin';

  @override
  String get profileVisibilityScreenSectionMessages => 'MESSAGES';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel =>
      'ENVOYER LES ACCUSÉS DE LECTURE';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      'activé, les autres peuvent voir que tu as lu leurs messages';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel =>
      'AFFICHER LES ACCUSÉS DE LECTURE';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      'voir la mention « VU » sur tes propres messages une fois lus';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      'seuls les lecteurs ayant activé ENVOYER LES ACCUSÉS DE LECTURE y contribuent. les autres restent invisibles.';

  @override
  String get profileVisibilityScreenSectionPeople => 'PERSONNES';

  @override
  String get profileVisibilityScreenFriendRequestsLabel => 'DEMANDES D\'AMI';

  @override
  String get profileVisibilityScreenFriendRequestsDesc =>
      'qui peut t\'envoyer des demandes d\'ami';

  @override
  String get profileVisibilityScreenSupervisedTitle =>
      'TES GRANDES PERSONNES RÈGLENT ÇA';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      'Tu peux voir ici tout ce que voient les autres, mais seule une grande personne peut le changer. Elle peut toujours voir ta photo, quand tu es en ligne et la dernière fois que tu étais là.';

  @override
  String get profileVisibilityScreenOptionPublic => 'PUBLIC';

  @override
  String get profileVisibilityScreenOptionFriends => 'AMIS';

  @override
  String get profileVisibilityScreenOptionNobody => 'PERSONNE';

  @override
  String get profileVisibilityScreenOptionOn => 'ACTIVÉ';

  @override
  String get profileVisibilityScreenOptionOff => 'DÉSACTIVÉ';

  @override
  String get profileVisibilityScreenOptionAnyone => 'TOUT LE MONDE';

  @override
  String get logoScreenTitle => 'logo de l\'appli.';

  @override
  String get logoScreenSubtitle =>
      'le symbole dans ton en-tête, à toi de voir.';

  @override
  String get logoScreenAutoLabel => 'AUTO';

  @override
  String get logoScreenAutoDescription =>
      'suit ton thème. le symbole change avec la palette.';

  @override
  String get logoScreenManualLabel => 'MANUEL';

  @override
  String get logoScreenManualDescription =>
      'choisis n\'importe quel symbole, garde ton thème.';

  @override
  String get logoScreenAlwaysDefaultLabel => 'TOUJOURS PAR DÉFAUT';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      'le symbole MonkeyHub, quel que soit le thème.';

  @override
  String get logoScreenActiveBadge => 'ACTIF';

  @override
  String get logoScreenMonkeyCollectionHeader => 'COLLECTION DE SINGES';

  @override
  String get logoScreenThemesHeader => 'THÈMES';

  @override
  String get recoveryPhraseScreenCopiedSnackbar =>
      'copié — colle-le dans un endroit sûr';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'confirme\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'que c\'est toi.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Ton mot de passe, pour que personne d\'autre ne puisse ajouter une phrase de récupération à ton compte.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'mot de passe';

  @override
  String get recoveryPhraseScreenContinueButton => 'CONTINUER';

  @override
  String get recoveryPhraseScreenNotNowLink => 'pas maintenant';

  @override
  String get recoveryPhraseScreenEnterPasswordError =>
      'Entre ton mot de passe.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'sauvegarde\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => 'ces mots.';

  @override
  String get recoveryPhraseScreenWordsBody =>
      'Ces douze mots sont ton seul moyen de retrouver l\'accès à ton compte si tu oublies ton mot de passe. On ne peut pas te les remontrer, et on ne peut pas les récupérer à ta place.';

  @override
  String get recoveryPhraseScreenCopyButton => 'COPIER';

  @override
  String get recoveryPhraseScreenPaperHint =>
      'Si tu peux, note-les sur papier. Tout ce qui est sur ce téléphone peut se perdre avec lui.';

  @override
  String get recoveryPhraseScreenSavedButton => 'JE LES AI SAUVEGARDÉS';

  @override
  String get recoveryPhraseScreenBackLink => '← retour';

  @override
  String get recoveryPhraseScreenKeepPhraseLink =>
      'pas maintenant — garder ma phrase actuelle';

  @override
  String get homeScreenProfileSemanticLabel => 'Ton profil';

  @override
  String homeScreenGreeting(Object name) {
    return 'salut, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'Nouveau salon';

  @override
  String get homeScreenEmptyRoomsMessage => 'pas encore de salon — crées-en un';

  @override
  String get groupCallScreenTitleVideo => 'Appel vidéo de groupe';

  @override
  String get groupCallScreenTitleVoice => 'Appel vocal de groupe';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '$count dans l\'appel';
  }

  @override
  String get groupCallScreenReconnecting => 'reconnexion…';

  @override
  String get groupCallScreenUnmuteLabel => 'activer micro';

  @override
  String get groupCallScreenMuteLabel => 'couper micro';

  @override
  String get groupCallScreenCamOnLabel => 'activer caméra';

  @override
  String get groupCallScreenCamOffLabel => 'couper caméra';

  @override
  String get groupCallScreenFlipLabel => 'retourner';

  @override
  String get groupCallScreenSpeakerLabel => 'haut-parleur';

  @override
  String get groupCallScreenLeaveLabel => 'quitter';

  @override
  String get groupCallScreenYouLabel => 'Toi';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return 'Filtré par $summary. Changer le filtre';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => 'Filtrer les salons';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => 'Effacer le filtre';

  @override
  String get roomFilterDrawerClearLabel => 'effacer';

  @override
  String get roomFilterDrawerDimensionType => 'TYPE';

  @override
  String get roomFilterDrawerDimensionNature => 'NATURE';

  @override
  String get roomFilterDrawerDimensionStatus => 'STATUT';

  @override
  String get roomFilterDrawerPanelClear => 'EFFACER';

  @override
  String get roomFilterDrawerPanelDone => 'TERMINÉ';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count salons',
      one: '$count salon',
    );
    return '$label, $_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return 'rien ne correspond à $summary';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Afficher tous les $count salons',
      one: 'Afficher $count salon',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'afficher tous les $count salons',
      one: 'afficher $count salon',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'nouveau salon';

  @override
  String get createRoomSheetTaglineSecret => 'RIEN NE SERA CONSERVÉ';

  @override
  String get createRoomSheetTaglineRegular => 'UN ESPACE QUI RESTE';

  @override
  String get createRoomSheetNameLabel => 'NOM';

  @override
  String get createRoomSheetNameHint => 'donne-lui un nom honnête…';

  @override
  String get createRoomSheetDescriptionLabel => 'DESCRIPTION · OPTIONNEL';

  @override
  String get createRoomSheetDescriptionHint => 'une ligne sur le salon…';

  @override
  String get createRoomSheetVisibilityLabel => 'VISIBILITÉ';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'public';

  @override
  String get createRoomSheetVisibilityPublicSub =>
      'tout le monde peut le trouver';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'privé';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'sur invitation uniquement';

  @override
  String get createRoomSheetTypeLabel => 'TYPE';

  @override
  String get createRoomSheetTypeStandardTitle => 'standard';

  @override
  String get createRoomSheetTypeStandardSub => 'les messages restent';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'éphémère';

  @override
  String get createRoomSheetTypeEphemeralSub => 's\'autodétruisent';

  @override
  String get createRoomSheetMessageLifeLabel => 'DURÉE DE VIE';

  @override
  String createRoomSheetTtlSeconds(Object seconds) {
    return '$seconds s';
  }

  @override
  String createRoomSheetTtlMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String createRoomSheetTtlHours(Object hours) {
    return '$hours h';
  }

  @override
  String get createRoomSheetPasswordLabel => 'MOT DE PASSE · OPTIONNEL';

  @override
  String get createRoomSheetPasswordHint =>
      'verrouille-le avec une phrase secrète…';

  @override
  String get createRoomSheetNameRequiredError => 'le nom est requis';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Ouvrir le salon';

  @override
  String get createRoomSheetOpenRoomButton => 'OUVRIR LE SALON';

  @override
  String get familyScreenTitle => 'FAMILLE';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count choses attendent ton accord',
      one: '1 chose attend ton accord',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => 'en ligne';

  @override
  String get familyScreenPresenceNotPaired => 'pas encore jumelé';

  @override
  String get familyScreenPresenceJustNow => 'à l\'instant';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return 'il y a $minutes min';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return 'il y a $hours h';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return 'il y a $days j';
  }

  @override
  String get familyScreenPairButton => 'JUMELER';

  @override
  String get familyScreenReleaseButton => 'DÉTACHER';

  @override
  String get familyScreenSettingsButton => 'RÉGLAGES';

  @override
  String get familyScreenAddChildButton => 'AJOUTER UN ENFANT';

  @override
  String get familyScreenEmptyStateTitle => 'pas encore d\'enfant';

  @override
  String get familyScreenEmptyStateBody =>
      'Crée un compte pour ton enfant, puis associe-le à son téléphone.';

  @override
  String get reactionDetailsSheetTitle => 'RÉACTIONS';

  @override
  String get reactionDetailsSheetEmptyState => 'il n\'y a plus rien ici';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes',
      one: '1 personne',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => 'TOUS';

  @override
  String get reactionDetailsSheetYouBadge => 'TOI';

  @override
  String get roomLayoutScreenTitle => 'liste des discussions.';

  @override
  String get roomLayoutScreenSubtitle =>
      'comment tes salons s\'organisent, et comment tu les filtres';

  @override
  String get roomLayoutScreenLayoutSectionLabel => 'DISPOSITION';

  @override
  String get roomLayoutScreenRowLayoutLabel => 'VUE LISTE';

  @override
  String get roomLayoutScreenRowLayoutDescription =>
      'une seule colonne, pleine largeur. facile à lire d\'un coup d\'œil.';

  @override
  String get roomLayoutScreenGridLayoutLabel => 'VUE GRILLE';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      'deux colonnes, compacte. plus de salons en un coup d\'œil.';

  @override
  String get roomLayoutScreenFilterControlSectionLabel =>
      'CONTRÔLE DES FILTRES';

  @override
  String get roomLayoutScreenChipRowLabel => 'RANGÉE DE PUCES';

  @override
  String get roomLayoutScreenChipRowDescription =>
      'toujours visible. un tap pour n\'importe quel filtre, une seule rangée d\'espace.';

  @override
  String get roomLayoutScreenDrawerButtonLabel => 'BOUTON TIROIR';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      'un bouton qui s\'ouvre. rien ne gêne la vue tant que tu ne le demandes pas.';

  @override
  String get roomLayoutScreenQuietRoomSectionLabel => 'SALONS SILENCIEUX';

  @override
  String get roomLayoutScreenPlainCornerLabel => 'coin vide';

  @override
  String get roomLayoutScreenPlainCornerDescription =>
      'un salon sans messages reste nu';

  @override
  String get roomLayoutScreenMonogramLabel => 'l\'initiale du salon';

  @override
  String get roomLayoutScreenMonogramDescription =>
      'une grande lettre pâle remplit le coin';

  @override
  String get roomLayoutScreenActiveBadge => 'ACTIF';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel =>
      'Aller au message épinglé';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => 'Tous les messages épinglés';

  @override
  String get pinnedBannerTitleSingle => 'Message épinglé';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return 'Message épinglé  $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => 'style de discussion.';

  @override
  String get pinnedBannerChatStyleSubtitle => 'à quoi ressemble le salon';

  @override
  String get pinnedBannerClassicLabel => 'CLASSIQUE';

  @override
  String get pinnedBannerClassicSubtitle =>
      'en-tête à bordure, barre de saisie plate.';

  @override
  String get pinnedBannerCompactLabel => 'COMPACT';

  @override
  String get pinnedBannerCompactSubtitle =>
      'capsules dépolies flottant au-dessus de la conversation.';

  @override
  String get pinnedBannerActiveBadge => 'ACTIF';

  @override
  String get audioMessageMissingLabel => '[audio manquant]';

  @override
  String get audioMessageUnavailableLabel => 'audio indisponible';

  @override
  String get audioMessageRetryHint => 'appuie pour réessayer';

  @override
  String get audioMessageLoadingLabel => 'chargement…';

  @override
  String get audioMessageUsernameRequiredError => 'Entre ton pseudo.';

  @override
  String get audioMessagePasswordRequiredError => 'Entre ton mot de passe.';

  @override
  String get audioMessageCancelSemanticLabel => 'Annuler';

  @override
  String get audioMessageHeroCreateLine1 => 'presque\n';

  @override
  String get audioMessageHeroCreateLine2 => 'au bout.';

  @override
  String get audioMessageHeroLinkLine1 => 'de retour\n';

  @override
  String get audioMessageHeroLinkLine2 => 'parmi nous.';

  @override
  String get audioMessageCreateSubtitle =>
      'Choisis un pseudo pour que ta famille et tes amis puissent te trouver.';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return 'Connecte-toi une fois et $provider sera lié à ton compte.';
  }

  @override
  String get audioMessageUsernameHint => 'pseudo';

  @override
  String get audioMessageDisplayNameHint => 'nom affiché (facultatif)';

  @override
  String get audioMessagePasswordHint => 'mot de passe';

  @override
  String get audioMessageSwitchToLinkPrompt =>
      'C\'est le mien — je me connecte';

  @override
  String get audioMessageCreateAccountButton => 'CRÉER UN COMPTE';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return 'SE CONNECTER ET LIER $provider';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => 'Tu as déjà un compte ?';

  @override
  String get audioMessageSwitchToCreateModeLink =>
      'Nouveau ici ? Crée un compte';

  @override
  String get approvalsScreenTitle => 'APPROBATIONS';

  @override
  String get approvalsScreenEmptyTitle => 'rien en attente';

  @override
  String get approvalsScreenEmptySubtitle => 'tu es à jour';

  @override
  String get approvalsScreenErrorNotGuardian =>
      'ce n\'est pas à toi de décider';

  @override
  String get approvalsScreenErrorAlreadyHandled => 'déjà traité ailleurs';

  @override
  String get approvalsScreenErrorGeneric =>
      'impossible d\'enregistrer — réessaie';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child veut ajouter $other';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other veut ajouter $child';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child veut rejoindre $room';
  }

  @override
  String get approvalsScreenSomeoneLower => 'quelqu\'un';

  @override
  String get approvalsScreenSomeoneCapital => 'Quelqu\'un';

  @override
  String get approvalsScreenRoomFallback => 'un salon';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      'Cette personne recevra la demande. C\'est toujours elle qui décide d\'accepter ou non.';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$child verra la demande et pourra l\'accepter ou l\'ignorer.';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      'Cette personne pourra y lire et y écrire jusqu\'à ce que tu retires cette autorisation.';

  @override
  String get approvalsScreenNotYetButton => 'PAS ENCORE';

  @override
  String get approvalsScreenAllowButton => 'AUTORISER';

  @override
  String get approvalsScreenForwardDirectMessageFallback => 'message privé';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'TRANSFÉRER $count MESSAGES',
      one: 'TRANSFÉRER LE MESSAGE',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet =>
      'pas encore d’autres discussions';

  @override
  String get approvalsScreenForwardNoMatches => 'rien ne correspond';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'jusqu’à $max discussions à la fois';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'rechercher des discussions';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Désélectionner $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Sélectionner $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'ÉPHÉMÈRE';

  @override
  String get approvalsScreenForwardSendSemantic => 'Envoyer';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ENVOYER À $count',
      zero: 'ENVOYER',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => 'COMPTES LIÉS';

  @override
  String get linkedAccountsScreenSubtitle =>
      'Les comptes que tu as liés à celui-ci, pour te connecter sans mot de passe.';

  @override
  String get linkedAccountsScreenEmptyState =>
      'Il n’y a rien à lier sur cet appareil.';

  @override
  String get linkedAccountsScreenStatusChecking => 'Vérification…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return 'Tu peux te connecter avec $provider sur n’importe lequel de tes appareils.';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return 'Ajoute $provider pour ne plus avoir à taper ton mot de passe.';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return 'DÉLIER $provider';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => 'DÉLIER';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return 'Entre ton mot de passe pour arrêter de te connecter avec $provider.';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return 'LIER $provider';
  }

  @override
  String get linkedAccountsScreenLinkAction => 'LIER';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return 'Entre ton mot de passe pour ajouter $provider comme méthode de connexion.';
  }

  @override
  String get linkedAccountsScreenPillChecking => 'VÉRIFICATION';

  @override
  String get linkedAccountsScreenPillLinked => 'LIÉ';

  @override
  String get linkedAccountsScreenPillNotLinked => 'NON LIÉ';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => 'VOCAL';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'VIDÉO';

  @override
  String get linkedAccountsScreenCallSheetTitle => 'Démarrer un appel';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle =>
      'Appeler tout le monde';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      'Fait sonner tous les membres de ce salon';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle =>
      'Choisir des personnes';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle =>
      'Choisis qui inviter';

  @override
  String get linkedAccountsScreenCallSheetCallFullError =>
      'Cet appel est complet (6 personnes max)';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError =>
      'Impossible de démarrer l’appel';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle => 'Inviter à l’appel';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers =>
      'Aucun autre membre ici';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople =>
      'Choisir des personnes';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => 'Démarrer l’appel';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return 'Démarrer l’appel ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => 'salut';

  @override
  String get childPairScreenGreetingLine2 => 'toi.';

  @override
  String get childPairScreenIntro =>
      'Demande à une grande personne d’ouvrir MonkeyHub et de toucher « associer un appareil ». Ensuite, scanne son code, ou tape les six chiffres qu’elle te dicte.';

  @override
  String get childPairScreenOrDivider => 'ou';

  @override
  String get childPairScreenGenericError =>
      'Une erreur est survenue. Réessaie.';

  @override
  String get profileScreenDeleteAccountFailed =>
      'Une erreur est survenue. Réessaie.';

  @override
  String get childPairScreenAccountGoneError => 'Ce compte n’existe plus.';

  @override
  String get childPairScreenScanButtonLabel => 'SCANNER SON CODE';

  @override
  String get childPairScreenNoCameraMessage =>
      'Pas de caméra ici — tape plutôt les six chiffres.';

  @override
  String get childPairScreenStopScanning => 'arrêter le scan';

  @override
  String get childPairScreenSubmitButtonLabel => 'LAISSE-MOI ENTRER';

  @override
  String get childPairScreenBackToSignIn => '← retour à la connexion';

  @override
  String get fileMessageUnavailable => 'le fichier n’est plus disponible';

  @override
  String get fileMessageOpenFailed => 'impossible d’ouvrir ce fichier';

  @override
  String get fileMessageDefaultName => 'document';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return 'Enregistrer $name';
  }

  @override
  String fileMessageViewSemanticLabel(Object name) {
    return 'Afficher $name';
  }

  @override
  String get textFileViewerDownloadTooltip => 'Télécharger';

  @override
  String get textFileViewerTruncatedNotice =>
      'Affichage d\'un extrait du fichier — téléchargez-le pour voir le reste.';

  @override
  String get fileMessageUploadFailedLabel => 'échec';

  @override
  String get fileMessageSendingLabel => 'envoi en cours…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · envoi en cours…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return 'il y a $count min';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return 'il y a $count h';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return 'il y a $count j';
  }

  @override
  String get fileMessageStandardBadge => 'STANDARD';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count brouillons de messages · appuie pour voir',
      one: '$count brouillon de message · appuie pour voir',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => 'ACCEPTER';

  @override
  String get fileMessageDeclineButton => 'REFUSER';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'ENVOYÉ $ago';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages en attente',
      one: '$count message en attente',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => 'ANNULER LA DEMANDE';

  @override
  String get destructiveSheetCannotBeUndone => 'ça ne peut pas être annulé';

  @override
  String get destructiveSheetCancelSemanticLabel => 'Annuler';

  @override
  String get destructiveSheetCancelButtonLabel => 'ANNULER';

  @override
  String get destructiveSheetHideLabel => 'MASQUER';

  @override
  String get destructiveSheetViewLabel => 'VOIR';

  @override
  String get destructiveSheetPairingMintError =>
      'Impossible de créer un code — réessaie.';

  @override
  String get destructiveSheetPairingReleaseTitle => 'LIBÉRER';

  @override
  String get destructiveSheetPairingPairTitle => 'JUMELER';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return 'Sur le téléphone de $name, ouvre son profil, appuie sur « rendre ce téléphone », puis tape ces chiffres.';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return 'Sur le téléphone de $name, ouvre MonkeyHub et scanne ceci — ou tape les chiffres.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'ce code a expiré';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'expire dans $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'NOUVEAU CODE';

  @override
  String get destructiveSheetPairingOneUseNote =>
      'Usage unique. Créer un nouveau code annule l’ancien.';

  @override
  String get deepOceanThemeAttachButtonLabel => 'Joindre';

  @override
  String get deepOceanThemeCameraButtonLabel => 'Appareil photo';

  @override
  String get deepOceanThemeSendButtonLabel => 'Envoyer';

  @override
  String get deepOceanThemeEphemeralHint => 'chuchote un truc…';

  @override
  String get deepOceanThemeDefaultHint => 'dis quelque chose…';

  @override
  String get deepOceanThemeMessageHint => 'Message';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'ce fichier a disparu';

  @override
  String get photoChromeMediaYouLabel => 'toi';

  @override
  String get photoChromeCloseSemanticLabel => 'Fermer';

  @override
  String get photoChromeFillToggleSemanticLabel => 'Ajuster ou remplir l’écran';

  @override
  String get photoChromeShowInChatSemanticLabel =>
      'Afficher dans la conversation';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return 'Élément $current sur $total';
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
  String get photoTrayDiscardSemanticLabel => 'abandonner ces photos';

  @override
  String get photoTrayRemoveSemanticLabel => 'retirer cette photo';

  @override
  String get photoTrayEditSemanticLabel =>
      'recadrer cette photo ou dessiner dessus';

  @override
  String get photoTrayAddMoreSemanticLabel => 'ajouter d’autres photos';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'vous pouvez envoyer $count photos à la fois';
  }

  @override
  String get photoTrayLoadFailedSnack =>
      'certaines de ces photos n’ont pas pu être ouvertes';

  @override
  String get mediaPickFailedMessage => 'impossible de l’ouvrir — réessaie';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name est en train d’écrire';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1 et $name2 sont en train d’écrire';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1, $name2 +$extra sont en train d’écrire';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => 'appel entrant';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'APPEL VIDÉO ENTRANT';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'APPEL VOCAL ENTRANT';

  @override
  String get typingIndicatorDeclineButtonLabel => 'refuser';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'refus en cours…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'accepter';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'connexion…';

  @override
  String get messageStampNavigationTitle => 'navigation.';

  @override
  String get messageStampNavigationSubtitle =>
      'comment tu navigues entre chat, découvrir, fil et réglages';

  @override
  String get messageStampRadialOrbLabel => 'ORBE RADIAL';

  @override
  String get messageStampRadialOrbDescription =>
      'maintiens puis glisse depuis le coin. discret au repos, un geste que tu apprivoises avec le temps.';

  @override
  String get messageStampBottomPillLabel => 'CAPSULE DU BAS';

  @override
  String get messageStampBottomPillDescription =>
      'appui classique. toujours visible, rien à apprendre.';

  @override
  String get messageStampActiveLabel => 'ACTIF';

  @override
  String get messageStampUploadingLabel => 'téléversement';

  @override
  String get messageStampSendingLabel => 'envoi';

  @override
  String get messageStampFailedToSendLabel => 'échec de l\'envoi';

  @override
  String get messageStampSentLabel => 'envoyé';

  @override
  String get messageStampDeliveredLabel => 'distribué';

  @override
  String get messageStampSeenLabel => 'vu';

  @override
  String get messageStampSavedLabel => 'enregistré';

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
      'permission du microphone refusée';

  @override
  String get voiceRecorderScreenStatusRecording => 'ENREGISTREMENT';

  @override
  String get voiceRecorderScreenStatusReady => 'PRÊT';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'APPUIE POUR COMMENCER';

  @override
  String get voiceRecorderScreenReRecordButton => 'RÉENREGISTRER';

  @override
  String get voiceRecorderScreenStopButton => 'ARRÊTER';

  @override
  String get voiceRecorderScreenSendButton => 'ENVOYER';

  @override
  String get voiceRecorderScreenRecordButton => 'ENREGISTRER';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => 'Tout le monde';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => 'NOTIFIE TOUS';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => 'PROPRIÉTAIRE';

  @override
  String get releaseDeviceScreenFallbackChildName => 'cette personne';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return 'Ça déconnecte $name de ce téléphone et le libère — l\'appareil revient à l\'écran de connexion normal, et n\'importe qui peut l\'utiliser.';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'Son compte, ses messages et ses amis sont tous conservés. La reconnexion est possible à tout moment.';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return 'Demande à une grande personne d\'ouvrir MonkeyHub, de trouver $name dans la famille, et d\'appuyer sur « libérer ».';
  }

  @override
  String get releaseDeviceScreenOrDivider => 'ou';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      'S\'il n\'y a que ce téléphone, une grande personne peut se connecter ici à la place.';

  @override
  String get releaseDeviceScreenUsernameHint =>
      'le nom d\'utilisateur d\'une grande personne';

  @override
  String get releaseDeviceScreenPasswordHint => 'son mot de passe';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => 'Se déconnecter';

  @override
  String get releaseDeviceScreenChecking => 'VÉRIFICATION…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return 'DÉCONNECTER $name';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => 'RENDS CE TÉLÉPHONE';

  @override
  String get releaseDeviceScreenErrorCodeExpired =>
      'Ce code a expiré. Demandes-en un nouveau.';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      'Ce code n\'a pas fonctionné. Il a peut-être déjà été utilisé.';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      'Ça n\'a pas fonctionné. Vérifie le nom d\'utilisateur et le mot de passe.';

  @override
  String get releaseDeviceScreenErrorGeneric =>
      'Un problème est survenu. Réessaie.';

  @override
  String get activeCallPillMoveHereSemanticLabel =>
      'Déplacer l\'appel vers cet appareil';

  @override
  String activeCallPillCallWith(Object name) {
    return 'Appel avec $name';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return 'Sur $device';
  }

  @override
  String get activeCallPillMoveHereLabel => 'Déplacer ici';

  @override
  String get activeCallPillUnknownCaller => 'Inconnu';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'Simulateur iOS';

  @override
  String get activeCallPillPlatformAndroid => 'Appareil Android';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'PC Windows';

  @override
  String get activeCallPillPlatformLinux => 'Appareil Linux';

  @override
  String get activeCallPillPlatformBrowser => 'Navigateur';

  @override
  String get activeCallPillPlatformOther => 'un autre appareil';

  @override
  String get activeCallPillPinnedHeader => 'ÉPINGLÉS';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'ÉPINGLÉS · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'plus rien d\'épinglé';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Aller au message de $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Désépingler le message de $name';
  }

  @override
  String get callButtonErrorBusy => 'occupé sur un autre appel';

  @override
  String get callButtonErrorCallFailed => 'impossible de démarrer l\'appel';

  @override
  String get callButtonErrorNotMember => 'pas membre de ce salon';

  @override
  String get callButtonErrorGeneric => 'impossible de démarrer l\'appel';

  @override
  String get callButtonAlreadyOnCall => 'Tu es déjà en appel';

  @override
  String get callButtonBusyElsewhere => 'Appel en cours sur un autre appareil';

  @override
  String get callButtonVoiceCallTooltip => 'appel vocal';

  @override
  String get callButtonVideoCallTooltip => 'appel vidéo';

  @override
  String get callButtonTooltip => 'appel';

  @override
  String get callButtonReplyStyleTitle => 'style de réponse.';

  @override
  String get callButtonReplyStyleSubtitle =>
      'comment une réponse affiche le message d\'origine';

  @override
  String get callButtonReplyStylePhantomEchoLabel => 'ÉCHO FANTÔME';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      'une bulle fantôme du message d\'origine flotte au-dessus, avec un connecteur courbe et l\'icône de branche au point de jonction.';

  @override
  String get callButtonReplyStyleStickyNoteLabel => 'POST-IT';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      'une carte façon polaroid, légèrement inclinée, épinglée au coin de la bulle.';

  @override
  String get callButtonReplyStyleComicTailLabel => 'QUEUE BD';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      'une petite bulle du message d\'origine avec une queue triangulaire façon BD, pointant vers le bas.';

  @override
  String get callButtonReplyStyleClassicLabel => 'CLASSIQUE';

  @override
  String get callButtonReplyStyleClassicDescription =>
      'capsule de citation teintée à la couleur d\'accent, avec une barre de connexion et l\'avatar — le style bien connu façon WhatsApp.';

  @override
  String get callButtonReplyStyleActiveBadge => 'ACTIF';

  @override
  String get callButtonReplyPreviewSampleMessage =>
      'au fait, t\'as vu la nouvelle démo ?';

  @override
  String get callButtonReplyPreviewSampleReply => 'ouais, ce flou déchire.';

  @override
  String get childSetupScreenErrorPickUsername =>
      'Choisis-lui un nom d\'utilisateur.';

  @override
  String get childSetupScreenErrorUsernameTaken =>
      'Ce nom d\'utilisateur est déjà pris.';

  @override
  String get childSetupScreenErrorChildNotAllowed =>
      'Seul le compte d\'une grande personne peut ajouter un enfant.';

  @override
  String get childSetupScreenErrorGeneric =>
      'Impossible de créer le compte — réessaie.';

  @override
  String get childSetupScreenTitle => 'AJOUTER UN ENFANT';

  @override
  String get childSetupScreenHeading => 'qui\nest-ce ?';

  @override
  String get childSetupScreenNameLabel => 'NOM';

  @override
  String get childSetupScreenNameHint => 'comment tu l\'appelles';

  @override
  String get childSetupScreenUsernameLabel => 'NOM D\'UTILISATEUR';

  @override
  String get childSetupScreenUsernameHint =>
      'comment les amis retrouvent ton enfant';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'CE QUE TON ENFANT AURA';

  @override
  String get childSetupScreenBulletTalkImmediately =>
      'Ton enfant pourra te parler tout de suite, à toi et à ses frères et sœurs.';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      'Tout le reste demande d\'abord ton accord — aussi bien pour les personnes que ton enfant veut ajouter, que pour celles qui veulent l\'ajouter.';

  @override
  String get childSetupScreenBulletPublicRoomsOff =>
      'Les salons publics sont désactivés jusqu\'à ce que tu les actives.';

  @override
  String get childSetupScreenBulletCantSignOut =>
      'Ton enfant ne peut pas se déconnecter, et tu peux toujours voir comment ça se passe.';

  @override
  String get childSetupScreenCreateButton => 'CRÉER + JUMELER';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return 'Envoyer un message à $name';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => 'demandé';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'MEMBRES';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'voir tout ($count)';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return 'Voir tout ($count)';
  }

  @override
  String get bubbleStyleScreenTitle => 'style de bulle.';

  @override
  String get bubbleStyleScreenSubtitle =>
      'la forme que prennent tes mots en arrivant';

  @override
  String get bubbleStyleScreenTailedLabel => 'À QUEUE';

  @override
  String get bubbleStyleScreenTailedDescription =>
      'une queue termine chaque série de messages ; les lignes au-dessus se resserrent en un seul bloc.';

  @override
  String get bubbleStyleScreenSoftLabel => 'DOUX';

  @override
  String get bubbleStyleScreenSoftDescription =>
      'pas de pointe — une série ne tient que par ses coins intérieurs resserrés.';

  @override
  String get bubbleStyleScreenPillLabel => 'CAPSULE';

  @override
  String get bubbleStyleScreenPillDescription =>
      'des capsules parfaitement arrondies, identiques sur chaque ligne.';

  @override
  String get bubbleStyleScreenSlabLabel => 'BLOC';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'épaules carrées — nettes, imprimées, délibérées.';

  @override
  String get bubbleStyleScreenActiveBadge => 'ACTIF';

  @override
  String get bubbleStyleScreenPreviewQuestion => 'alors ? ça donne quoi';

  @override
  String get bubbleStyleScreenPreviewReplyOne => 'mieux';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => 'bien mieux';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => 'Vidéo';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => 'Photo';

  @override
  String get incomingGroupCallScreenCallFullError =>
      'Cet appel est complet (6 personnes max)';

  @override
  String get incomingGroupCallScreenJoinFailedError =>
      'Impossible de rejoindre l\'appel';

  @override
  String get incomingGroupCallScreenDefaultRoomName => 'Appel de groupe';

  @override
  String get incomingGroupCallScreenDefaultStarterName => 'Quelqu\'un';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starter a démarré un appel vidéo';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starter a démarré un appel vocal';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '$count déjà connectés';
  }

  @override
  String get incomingGroupCallScreenDismissButton => 'Refuser';

  @override
  String get incomingGroupCallScreenJoinButton => 'Rejoindre';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversations',
      one: '$count conversation',
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
      'dernier message à l\'instant';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'dernier message il y a ${hours}h';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'dernier message hier';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'dernier message il y a $days jours';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'dernier message il y a un moment';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'REPRENDRE';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return 'retirer $contactName à $childName ?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'ils ne pourront plus se contacter, et leur conversation disparaît avec.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'ils ne pourront plus se contacter. $contactName n\'en saura rien.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats · $messages seront supprimés';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      'supprimés pour les deux, photos et messages vocaux compris. c\'est irréversible.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ils partagent aussi $count salons',
      one: 'ils partagent aussi $count salon',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'elles restent. retire la salle depuis la liste SALONS ci-dessous si tu veux t\'en débarrasser.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'RETIRER ET SUPPRIMER';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'retire $contactName et efface $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'retire $contactName de la liste des autorisés.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Annuler';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => 'ANNULER';

  @override
  String get groupCallBannerCallFullError =>
      'Cet appel est complet (6 personnes max)';

  @override
  String get groupCallBannerJoinFailedError =>
      'Impossible de rejoindre l\'appel';

  @override
  String get groupCallBannerUnknownParticipant => 'Quelqu\'un';

  @override
  String get groupCallBannerOngoingVideoCall => 'Appel vidéo en cours';

  @override
  String get groupCallBannerOngoingVoiceCall => 'Appel vocal en cours';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra dans l\'appel';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => 'Rejoindre l\'appel';

  @override
  String get groupCallBannerJoinButtonLabel => 'REJOINDRE';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'REJOINDRE LE SALON';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '$count membre',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => 'MOT DE PASSE';

  @override
  String get groupCallBannerPasswordHint => 'phrase de passe…';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Rejoindre';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'REJOINDRE';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Annuler';

  @override
  String get groupCallBannerCancelButtonLabel => 'annuler';

  @override
  String get viewOnceViewerBadgeLabel => 'VUE UNIQUE';

  @override
  String get socialButtonDividerOr => 'ou';

  @override
  String get socialButtonGoogleContinue => 'Continuer avec Google';

  @override
  String get discoverListsPeopleTitle => 'tes proches.';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes',
      one: '$count personne',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => 'filtre tes proches…';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Effacer le filtre';

  @override
  String get discoverListsNoOneYet => 'encore personne';

  @override
  String discoverListsNoMatches(Object query) {
    return 'personne ne correspond à « $query »';
  }

  @override
  String get discoverListsRoomsTitle => 'tes salons.';

  @override
  String discoverListsRoomsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count salons',
      one: '$count salon',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterRoomsHint => 'filtre tes salons…';

  @override
  String get discoverListsNoRoomsYet => 'aucun salon pour l\'instant';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return 'aucun salon ne correspond à « $query »';
  }

  @override
  String get discoverListsVoiceCallLabel => 'APPEL VOCAL';

  @override
  String get discoverListsVideoCallLabel => 'APPEL VIDÉO';

  @override
  String get approvalGateAlreadyAskedLabel => 'DÉJÀ DEMANDÉ';

  @override
  String get approvalGateAskGrownUpLabel => 'DEMANDE À UNE GRANDE PERSONNE';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return 'Tu as déjà demandé si tu pouvais $what.';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return 'Il faut qu\'une grande personne dise oui avant que tu puisses $what.';
  }

  @override
  String get approvalGateDisabledBody =>
      'Une grande personne a désactivé ça pour le moment.';

  @override
  String get approvalGateAlreadyAskedFooter =>
      'Ils vont recevoir un message à ce sujet. Repasse bientôt.';

  @override
  String get approvalGateWillNotifyFooter =>
      'On va les prévenir. Tu verras leur réponse ici dès qu\'ils répondront.';

  @override
  String get approvalGateTalkToThemFooter =>
      'Tu peux leur en parler si tu penses que ça devrait changer.';

  @override
  String get approvalGateAskButton => 'DEMANDER';

  @override
  String get approvalGateNotNowButton => 'PAS MAINTENANT';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel =>
      'en attente d\'une grande personne';

  @override
  String get reportSheetTitle => 'SIGNALEMENT';

  @override
  String get reportSheetSubtitle => 'dis-nous ce qui ne va pas.';

  @override
  String get reportSheetPrivacyNote =>
      'les signalements sont confidentiels — l\'autre personne n\'est pas prévenue.';

  @override
  String get reportSheetReasonSpamLabel => 'SPAM';

  @override
  String get reportSheetReasonSpamDescription =>
      'publicités non désirées ou messages répétés';

  @override
  String get reportSheetReasonHarassmentLabel => 'HARCÈLEMENT';

  @override
  String get reportSheetReasonHarassmentDescription =>
      's\'en prendre à quelqu\'un ou l\'intimider';

  @override
  String get reportSheetReasonImpersonationLabel => 'USURPATION D\'IDENTITÉ';

  @override
  String get reportSheetReasonImpersonationDescription =>
      'se faire passer pour quelqu\'un d\'autre';

  @override
  String get reportSheetReasonInappropriateLabel => 'INAPPROPRIÉ';

  @override
  String get reportSheetReasonInappropriateDescription =>
      'contenu sexuel, violent ou illégal';

  @override
  String get reportSheetReasonOtherLabel => 'AUTRE';

  @override
  String get reportSheetReasonOtherDescription => 'autre chose';

  @override
  String get reportSheetOtherNoteHint => 'qu\'est-ce qui s\'est passé ?';

  @override
  String get reportSheetSubmitSemanticLabel => 'Envoyer le signalement';

  @override
  String get reportSheetSubmitButton => 'ENVOYER';

  @override
  String get reportSheetUpdateRequiredTitle => 'MISE À JOUR REQUISE';

  @override
  String get reportSheetUpdateAvailableTitle => 'MISE À JOUR DISPONIBLE';

  @override
  String get reportSheetUpdateMandatoryBody =>
      'Cette version est trop ancienne pour continuer à fonctionner correctement. Mets à jour pour continuer.';

  @override
  String get reportSheetUpdateAvailableBody =>
      'Une nouvelle version de MonkeyHub est disponible.';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => 'METTRE À JOUR';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'ouvre TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'ouvre l\'App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'ouvre Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'ouvre la page de téléchargement';

  @override
  String get reportSheetUpdateActionReloads =>
      'recharge avec la nouvelle version';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Plus tard';

  @override
  String get reportSheetUpdateLaterButton => 'PLUS TARD';

  @override
  String get roomFilterBarAllChipLabel => 'tous';

  @override
  String roomFilterBarChipCountSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count discussions',
      one: '$count discussion',
    );
    return '$label, $_temp0';
  }

  @override
  String composerReplyCardReplyingToLabel(Object name) {
    return 'RÉPONSE À $name';
  }

  @override
  String get roomCardLockedBadge => 'VERROUILLÉ';

  @override
  String get roomCardTimeAgoJustNow => 'à l\'instant';

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
    return '${days}j';
  }

  @override
  String roomCardTimeAgoWeeks(Object weeks) {
    return '${weeks}sem';
  }

  @override
  String roomCardStartedAgo(Object ago) {
    return 'créé il y a $ago';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count dedans';
  }

  @override
  String get roomCardMessagesFadeLabel => 'messages éphémères';

  @override
  String get roomCardEnterLabel => '↗ entrer';

  @override
  String get roomCardBlockedScreenTitle => 'BLOQUÉS';

  @override
  String get roomCardBlockedEmptyState => 'tu n\'as bloqué personne.';

  @override
  String get roomCardUnblockButton => 'DÉBLOQUER';

  @override
  String get attachmentMenuPhotoLabel => 'photo';

  @override
  String get attachmentMenuVideoLabel => 'vidéo';

  @override
  String get attachmentMenuCameraLabel => 'caméra';

  @override
  String get attachmentMenuVoiceLabel => 'voix';

  @override
  String get attachmentMenuFileLabel => 'fichier';

  @override
  String get attachmentMenuConnectionRetrying => 'nouvelle tentative…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'impossible de joindre le serveur · touche pour réessayer';

  @override
  String get attachmentMenuConnectionReconnecting => 'reconnexion…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Réessayer la connexion';

  @override
  String get roomGridTileEmptyLastMessage => 'calme pour l\'instant';

  @override
  String get roomGridTileMemberCountLabel => 'DEDANS';

  @override
  String get roomGridTileThemeChipLabel => 'THÈME';

  @override
  String get bulkActionBarCancelLabel => 'ANNULER';

  @override
  String get bulkActionBarSelectMessagesLabel => 'SÉLECTIONNE DES MESSAGES';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count SÉLECTIONNÉ(S)';
  }

  @override
  String get bulkActionBarForwardLabel => 'TRANSFÉRER';

  @override
  String get bulkActionBarDeleteLabel => 'SUPPRIMER';

  @override
  String get bulkActionBarJumpBackLabel => 'RETOUR';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return 'RETOUR · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel =>
      'Retour à l\'endroit d\'où tu as sauté';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return 'Retour à l\'endroit d\'où tu as sauté, $depth restants';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote =>
      'cette personne ne sera pas prévenue.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'tu es actuellement ami(e) avec cette personne — bloquer met fin à cette amitié, donc pour renouer contact plus tard, tu devras lui envoyer une nouvelle demande d\'ami.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'cette personne disparaîtra de tes recherches et ne pourra plus t\'envoyer de messages.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'BLOQUER';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return 'bloquer $name ?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tu partages $count salons avec cette personne',
      one: 'tu partages $count salon avec cette personne',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'ces salons restent intacts. tu peux quitter n\'importe lequel toi-même depuis les paramètres de chaque salon.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'BLOQUER';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'supprime l\'amitié et bloque cette personne. l\'historique de discussion existant reste dans tes archives.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'cette personne est masquée des recherches et ne peut pas te contacter.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'BLOQUER ET SUPPRIMER LE DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'efface aussi ton DM avec cette personne — tous les messages, réactions et fichiers médias disparaissent.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Annuler';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'ANNULER';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle =>
      'Afficher les appels sur l\'écran de verrouillage';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      'Pour sonner comme un vrai appel téléphonique quand ton écran est éteint, MonkeyHub a besoin que les « notifications plein écran » soient activées. L\'écran suivant t\'emmène directement au réglage.';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle =>
      'Ne rate plus jamais un appel';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      'Certains téléphones mettent les applis en pause en arrière-plan pour économiser la batterie, ce qui peut empêcher tes appels entrants de sonner. Autorise MonkeyHub à fonctionner sans restriction pour que tes appels passent toujours.';

  @override
  String get bulkActionBarDialogNotNowButton => 'Pas maintenant';

  @override
  String get bulkActionBarDialogContinueButton => 'Continuer';

  @override
  String get reactionBubbleJumpToLatestLabel => 'DERNIER MESSAGE';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel =>
      'Aller au dernier message';

  @override
  String get reactionBubblePickerTitle => 'RÉAGIR';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'pas encore de récents';

  @override
  String get reactionBubbleSearchHint => 'rechercher un emoji';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'aucun résultat';

  @override
  String get reactionBubbleSearchBackSemanticLabel => 'Retour aux emojis';

  @override
  String get reactionBubblePasswordHint => 'mot de passe';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return 'rejoindre $roomName';
  }

  @override
  String get enterPublicRoomAskFailedMessage =>
      'impossible de demander pour le moment — réessaie';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'mot de passe incorrect';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'impossible de rejoindre — réessaie';

  @override
  String get feedBoardTitle => 'AUJOURD’HUI';

  @override
  String feedBoardEditionLabel(Object number) {
    return 'N°$number';
  }

  @override
  String get feedBoardHighlightsLabel => 'MOMENTS FORTS';

  @override
  String get feedBoardHighlightsEmpty => 'rien de capturé aujourd’hui';

  @override
  String get feedBoardPuzzleLabel => 'L’ÉNIGME';

  @override
  String get feedBoardPuzzleEmpty => 'l’énigme du jour n’est pas encore prête';

  @override
  String get feedBoardStandingsLabel => 'POINTS DE VIE';

  @override
  String get feedBoardStandingsEmpty => 'aucun point au tableau aujourd’hui';

  @override
  String get feedBoardActivityLabel => 'ACTIVITÉ';

  @override
  String get feedBoardActivityEmpty => 'calme pour l’instant aujourd’hui';

  @override
  String get feedBoardActivityNoFriends =>
      'ajoute un ami et sa journée apparaîtra ici';

  @override
  String get feedBoardLoadFailed =>
      'impossible de charger le tableau — réessaie dans un instant';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'PUBLIC';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'PRIVÉ';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'REJOINT';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'ÉPHÉMÈRE · $duration';
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
      'Tout le monde peut trouver ce salon et le rejoindre';

  @override
  String get roomBadgePrivateTooltip =>
      'Sur invitation seulement — invisible dans Découvre';

  @override
  String get roomBadgeLockedTooltip =>
      'Il te faut le mot de passe du salon pour entrer';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return 'Les messages disparaissent après $duration';
  }

  @override
  String get roomBadgeJoinedTooltip => 'Tu es déjà dans ce salon';

  @override
  String get roomInfoSheetDetailsLabel => 'LES DÉTAILS';

  @override
  String get roomInfoSheetNoDescription => 'pas encore de description';

  @override
  String get roomInfoSheetCreatedLabel => 'CRÉÉ LE';

  @override
  String get countBadgeCaptureProtectionLabel => 'PROTECTION CAPTURE D\'ÉCRAN';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      'les captures d\'écran et enregistrements d\'écran s\'affichent en noir pour le système.';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      'l\'enregistrement d\'écran et la recopie d\'écran font apparaître un bouclier de confidentialité sur l\'appli.';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      'hors des salons éphémères, les captures d\'écran et enregistrements fonctionnent normalement.';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      'les salons éphémères (la chambre des secrets) l\'activent toujours, quoi qu\'il arrive.';

  @override
  String get countBadgeShowPasswordTooltip => 'afficher le mot de passe';

  @override
  String get countBadgeHidePasswordTooltip => 'masquer le mot de passe';

  @override
  String get countBadgeProtectedLabel => 'PROTÉGÉ';

  @override
  String get countBadgeCaptureShieldActiveBody =>
      'un enregistrement d\'écran ou une recopie d\'écran est en cours.';

  @override
  String get countBadgeCaptureShieldReassurance =>
      'l\'enregistrement ne peut pas voir tes conversations.';

  @override
  String get linkOpenerCouldNotOpenLink => 'Impossible d\'ouvrir le lien';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel =>
      'Configurer une phrase de récupération';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'aucune phrase de récupération — tu risques de ne plus jamais pouvoir te reconnecter.';

  @override
  String get destinationsChatLabel => 'Chat';

  @override
  String get destinationsChatShort => 'CHAT';

  @override
  String get destinationsDiscoverLabel => 'Découvrir';

  @override
  String get destinationsDiscoverShort => 'TROUVER';

  @override
  String get destinationsFeedLabel => 'Fil';

  @override
  String get destinationsFeedShort => 'FIL';

  @override
  String get destinationsSettingsLabel => 'Réglages';

  @override
  String get destinationsSettingsShort => 'RÉG';

  @override
  String get familyRequestStageSenderGuardianLabel => 'en attente d\'un grand';

  @override
  String get familyRequestStageRecipientLabel => 'en attente de sa réponse';

  @override
  String get roomContentTabLabelMedia => 'MÉDIAS';

  @override
  String get roomContentTabLabelFiles => 'FICHIERS';

  @override
  String get roomContentTabLabelVoice => 'VOCAL';

  @override
  String get roomContentTabLabelLinks => 'LIENS';

  @override
  String get roomContentTabLabelSaved => 'ENREGISTRÉS';

  @override
  String get roomContentTabHeaderMedia => 'médias';

  @override
  String get roomContentTabHeaderFiles => 'fichiers';

  @override
  String get roomContentTabHeaderVoice => 'vocal';

  @override
  String get roomContentTabHeaderLinks => 'liens';

  @override
  String get roomContentTabHeaderSaved => 'enregistrés';

  @override
  String get roomFacetLabelDms => 'MP';

  @override
  String get roomFacetLabelGroups => 'groupes';

  @override
  String get roomFacetLabelPublic => 'public';

  @override
  String get roomFacetLabelPrivate => 'privé';

  @override
  String get roomFacetLabelSecret => 'secret';

  @override
  String get roomFacetLabelLocked => 'verrouillé';

  @override
  String get roomFacetLabelUnread => 'non lus';

  @override
  String get roomFacetLabelMentions => 'mentions';

  @override
  String get settingsScreenTitle => 'RÉGLAGES';

  @override
  String get settingsScreenTagline => 'style. ambiance. toi.';

  @override
  String get settingsScreenAccountHintChild =>
      'profil · confidentialité · mes grands';

  @override
  String get settingsScreenAccountHintAdult =>
      'profil · famille · comptes liés · confidentialité';

  @override
  String get settingsScreenSectionAppearance => 'APPARENCE';

  @override
  String get settingsScreenSectionChat => 'CHAT';

  @override
  String get settingsScreenSectionCompanions => 'COMPAGNONS';

  @override
  String get settingsScreenSectionGeneral => 'GÉNÉRAL';

  @override
  String get settingsScreenCheckForUpdatesLabel => 'VÉRIFIER LES MISES À JOUR';

  @override
  String get settingsScreenUpdateAvailableValue => 'MISE À JOUR DISPONIBLE';

  @override
  String get settingsScreenUpdateUpToDateSnackbar =>
      'Vous avez la dernière version.';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      'Impossible de vérifier les mises à jour sur cette version.';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      'Impossible de vérifier les mises à jour. Réessayez plus tard.';

  @override
  String get settingsScreenSectionNotifications => 'NOTIFICATIONS';

  @override
  String get reportProblemRowLabel => 'Signaler un problème';

  @override
  String get reportProblemRowValue => 'Envoyez-nous les détails';

  @override
  String get reportProblemIntro =>
      'Dites-nous ce qui n\'a pas fonctionné. Les informations sur votre app et votre appareil sont incluses automatiquement, ainsi qu\'un journal technique de ce que faisait l\'app — c\'est ce qui nous aide à trouver la cause.';

  @override
  String get reportProblemDescribeLabel => 'CE QUI S\'EST PASSÉ';

  @override
  String get reportProblemDescribeHint =>
      'L\'écran scintille, les boutons ne répondent pas…';

  @override
  String get reportProblemScreenshotsLabel => 'CAPTURES D\'ÉCRAN';

  @override
  String get reportProblemAddScreenshot => 'Ajouter une capture';

  @override
  String get reportProblemDetailsLabel => 'VOS INFORMATIONS';

  @override
  String get reportProblemCopyDetails => 'Copier les informations';

  @override
  String get reportProblemCopied => 'Copié';

  @override
  String get reportProblemSend => 'Envoyer le signalement';

  @override
  String get reportProblemSent => 'Signalement envoyé — merci !';

  @override
  String get reportProblemSendFailed =>
      'Impossible d\'envoyer le signalement. Vérifiez votre connexion et réessayez.';

  @override
  String get reportProblemTooMany =>
      'Vous venez d\'envoyer beaucoup de signalements. Réessayez un peu plus tard.';

  @override
  String get reportProblemShakeTitle => 'Signaler un problème ?';

  @override
  String get reportProblemShakeBody =>
      'Vous avez secoué votre téléphone. Ouvrir l\'écran de signalement ?';

  @override
  String get reportProblemShakeOpen => 'Signaler';

  @override
  String get reportProblemShakeDismiss => 'Pas maintenant';

  @override
  String get settingsCallDeliveryLockScreenLabel =>
      'Appels sur l\'écran de verrouillage';

  @override
  String get settingsCallDeliveryBackgroundLabel => 'Activité en arrière-plan';

  @override
  String get settingsCallDeliveryStatusOff => 'Appuyez pour autoriser';

  @override
  String get settingsScreenRowTheme => 'THÈME';

  @override
  String get settingsScreenRowAppLogo => 'LOGO APPLI';

  @override
  String get settingsScreenRowGlass => 'VERRE';

  @override
  String get settingsScreenRowChatList => 'LISTE DE CHATS';

  @override
  String get settingsScreenRowNavigation => 'NAVIGATION';

  @override
  String get settingsScreenRowChatStyle => 'STYLE DE CHAT';

  @override
  String get settingsScreenRowBubbleStyle => 'STYLE DE BULLE';

  @override
  String get settingsScreenRowReplyStyle => 'STYLE DE RÉPONSE';

  @override
  String get settingsScreenValueScrollList => 'Vue en liste';

  @override
  String get settingsScreenValueGridSheet => 'Vue en grille';

  @override
  String get settingsScreenValueRadialOrb => 'Orbe radial';

  @override
  String get settingsScreenValueBottomPill => 'Capsule du bas';

  @override
  String get settingsScreenValueCustom => 'Personnalisé';

  @override
  String settingsScreenValueEdited(Object name) {
    return '$name · modifié';
  }

  @override
  String get settingsScreenValueClassic => 'Classique';

  @override
  String get settingsScreenValueCompact => 'Compact';

  @override
  String get settingsScreenValueBubbleTailed => 'À queue';

  @override
  String get settingsScreenValueBubbleSoft => 'Doux';

  @override
  String get settingsScreenValueBubblePill => 'Capsule';

  @override
  String get settingsScreenValueBubbleSlab => 'Bloc';

  @override
  String get settingsScreenValueReplyPhantomEcho => 'Écho Fantôme';

  @override
  String get settingsScreenValueReplyStickyNote => 'Note Adhésive';

  @override
  String get settingsScreenValueReplyComicTail => 'Queue BD';

  @override
  String get settingsScreenValueLogoAuto => 'Auto';

  @override
  String get settingsScreenValueLogoManual => 'Manuel';

  @override
  String get settingsScreenShowLinkUrlsLabel => 'AFFICHER LES URL';

  @override
  String get settingsScreenLinksUrlsOnBody =>
      'les URL brutes apparaissent à côté de la carte d\'aperçu';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      'aperçu seulement — bulles plus épurées, appuie pour ouvrir';

  @override
  String get settingsScreenMenuBarLabel => 'ICÔNE DE LA BARRE DES MENUS';

  @override
  String get settingsScreenMenuBarOnBody =>
      'MonkeyHub reste dans la barre des menus avec son compteur de non-lus — cliquez pour afficher la fenêtre';

  @override
  String get settingsScreenMenuBarOffBody =>
      'actuellement désactivé — l’icône du Dock est le seul moyen de retrouver une fenêtre masquée';

  @override
  String get settingsScreenSectionCalls => 'APPELS';

  @override
  String get settingsScreenRowVideoQuality => 'Qualité vidéo';

  @override
  String get settingsScreenValueVideoQualityAuto => 'Auto';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel =>
      'AFFICHER LES STATS D\'APPEL';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      'résolution, débit, ping et perte de paquets en direct pendant les appels';

  @override
  String get videoQualityScreenTitle => 'Qualité vidéo';

  @override
  String get videoQualityScreenSubtitle =>
      'Choisis une résolution maximale pour la vidéo sortante';

  @override
  String get videoQualityScreenAutoSubtitle =>
      'S\'adapte automatiquement à ta connexion';

  @override
  String get videoQualityScreenHd1080Subtitle =>
      'Full HD — plus net, utilise plus de données';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD — idéal avec une connexion solide';

  @override
  String get videoQualityScreenFootnote =>
      'La résolution réelle dépend des caméras des deux appareils et des conditions du réseau.';

  @override
  String get callScreenControlOptions => 'Plus';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => 'Gigue';

  @override
  String get callScreenStatsLossLabel => 'Perte';

  @override
  String get callScreenSwapPreviewSemanticLabel =>
      'Changer la vue de la caméra';

  @override
  String get callOptionsSheetTitle => 'Options d\'appel';

  @override
  String get settingsScreenPushNotificationsLabel => 'NOTIFICATIONS PUSH';

  @override
  String get settingsScreenPushOnBody =>
      'te prévient pour les nouveaux messages et demandes';

  @override
  String get settingsScreenPushOffBody =>
      'silencieux — tu ne verras les choses qu\'en ouvrant l\'appli';

  @override
  String get settingsScreenGameRemindersLabel => 'RAPPEL QUOTIDIEN DES JEUX';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'un rappel à midi, seulement si tu n’as pas joué';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'aucun rappel — les jeux sont là quand tu passes';

  @override
  String get authErrorUsernameTaken => 'Ce nom d\'utilisateur est déjà pris.';

  @override
  String get authErrorUsernameReserved =>
      'Ce nom d\'utilisateur n\'est pas disponible. Choisissez-en un autre.';

  @override
  String get authErrorDisplayNameReserved =>
      'Ce nom n\'est pas disponible. Choisissez-en un autre.';

  @override
  String get authErrorUserNotFound =>
      'Aucun compte avec ce nom d\'utilisateur.';

  @override
  String get authErrorWrongPassword => 'Mot de passe incorrect.';

  @override
  String get authErrorInvalidRecoveryKey =>
      'Ce nom d\'utilisateur et cette phrase de récupération ne correspondent pas.';

  @override
  String get authErrorTooManyAttempts =>
      'Trop de tentatives. Attends 15 minutes et réessaie.';

  @override
  String get authErrorChildMustPair =>
      'C\'est un compte enfant — demande un code d\'appairage à un grand.';

  @override
  String get authErrorPairingCodeExpired =>
      'Ce code a expiré. Demandes-en un nouveau.';

  @override
  String get authErrorPairingCodeInvalid =>
      'Ce code n\'a pas fonctionné. Il a peut-être déjà été utilisé.';

  @override
  String get authErrorUseSocialSignIn =>
      'Ce compte se connecte avec Apple ou Google — utilise les boutons ci-dessous.';

  @override
  String get authErrorSocialTokenInvalid =>
      'Cette connexion n\'a pas fonctionné. Réessaie.';

  @override
  String get authErrorSocialNonceMismatch =>
      'La connexion n’a pas abouti. Réessaie.';

  @override
  String get authErrorSocialMisconfig =>
      'La connexion n’est pas encore configurée de notre côté. Réessaie plus tard.';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      'Ce compte Apple ou Google est déjà lié à un autre compte MonkeyHub.';

  @override
  String get authErrorSocialAlreadyLinked => 'C’est déjà lié à ce compte.';

  @override
  String get authErrorSocialNotLinked => 'Ce n’est pas lié à ce compte.';

  @override
  String get authErrorSocialLastCredential =>
      'C’est le seul moyen d’accéder à ce compte. Définis d’abord un mot de passe.';

  @override
  String get authErrorUsernameInvalid =>
      'Choisis un nom d’utilisateur entre 1 et 32 caractères.';

  @override
  String get authErrorUsernameChangedRecently =>
      'Tu as changé de nom d’utilisateur récemment. Tu pourras le changer à nouveau 30 jours après le dernier changement.';

  @override
  String get authErrorInboxHandleLocked =>
      'Ce compte reçoit les signalements de problèmes de tout le monde, son nom d’utilisateur est donc fixe.';

  @override
  String get glassKnobLabelFrost => 'GIVRE';

  @override
  String get glassKnobHintFrost =>
      'la quantité de blanc posée sur le verre. baisse pour plus de transparence';

  @override
  String get glassKnobLabelBlur => 'FLOU';

  @override
  String get glassKnobHintBlur =>
      'givré en haut de la plage, verre clair en bas';

  @override
  String get glassKnobLabelSaturation => 'BAVURE DE COULEUR';

  @override
  String get glassKnobHintSaturation =>
      'la part de couleur qui survit au flou. au-delà de 2, ça postérise';

  @override
  String get glassKnobLabelRimOpacity => 'BORDURE';

  @override
  String get glassKnobHintRimOpacity =>
      'le contour d’accentuation. mets zéro pour une surface sans bordure';

  @override
  String get glassKnobLabelRimWidth => 'LARGEUR DE BORDURE';

  @override
  String get glassKnobHintRimWidth => 'l’épaisseur de ce contour';

  @override
  String get glassKnobLabelShadowOpacity => 'OMBRE';

  @override
  String get glassKnobHintShadowOpacity =>
      'à quelle hauteur la surface flotte au-dessus de ce qu’il y a derrière elle';

  @override
  String get glassKnobLabelShadowBlur => 'ÉTALEMENT DE L’OMBRE';

  @override
  String get glassKnobHintShadowBlur => 'douce et large, ou serrée et dure';

  @override
  String get glassKnobLabelShadowY => 'DÉCALAGE DE L’OMBRE';

  @override
  String get glassKnobHintShadowY => 'jusqu’où l’ombre tombe sous la surface';

  @override
  String get glassKnobLabelBarMargin => 'MARGE LATÉRALE';

  @override
  String get glassKnobHintBarMargin =>
      'l’espace entre la barre et le bord de l’écran';

  @override
  String get glassKnobLabelBarBottom => 'MARGE BASSE';

  @override
  String get glassKnobHintBarBottom =>
      'à quelle hauteur la barre flotte au-dessus du bas de l’écran';

  @override
  String get glassKnobLabelShellPadH => 'MARGE DES BORDS';

  @override
  String get glassKnobHintShellPadH =>
      'du bord de la barre jusqu’à la première pastille. reste petit, sinon les extrémités semblent esseulées';

  @override
  String get glassKnobLabelShellPadV => 'MARGE DU HAUT';

  @override
  String get glassKnobHintShellPadV =>
      'du bord de la barre jusqu’au haut de la pastille';

  @override
  String get glassKnobLabelIndicatorInset => 'RETRAIT DE LA PASTILLE';

  @override
  String get glassKnobHintIndicatorInset =>
      'de combien la pastille de sélection s’enfonce dans son emplacement';

  @override
  String get glassKnobLabelSegmentPadV => 'MARGE DE RANGÉE';

  @override
  String get glassKnobHintSegmentPadV =>
      'l’espace au-dessus et en dessous de l’icône et de son étiquette';

  @override
  String get glassKnobLabelIconLabelGap => 'ESPACE ICÔNE';

  @override
  String get glassKnobHintIconLabelGap =>
      'l\'espace entre une icône et le mot en dessous';

  @override
  String get glassKnobLabelIconSize => 'TAILLE ICÔNE';

  @override
  String get glassKnobLabelLabelSize => 'TAILLE LIBELLÉ';

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
  String get settingsScreenRowMotion => 'MOUVEMENT';

  @override
  String get settingsScreenValueMotionFull => 'Complet';

  @override
  String get settingsScreenValueMotionCalm => 'Calme';

  @override
  String get settingsScreenValueMotionSystemFull =>
      'Comme l’appareil · complet';

  @override
  String get settingsScreenValueMotionSystemCalm => 'Comme l’appareil · calme';

  @override
  String get motionScreenTitle => 'mouvement.';

  @override
  String get motionScreenSubtitle => 'à quel point l’app bouge';

  @override
  String get motionScreenSystemLabel => 'COMME L’APPAREIL';

  @override
  String get motionScreenSystemSubtitleFull =>
      'ton appareil autorise l’animation en ce moment';

  @override
  String get motionScreenSystemSubtitleCalm =>
      'ton appareil demande moins de mouvement en ce moment';

  @override
  String get motionScreenFullLabel => 'COMPLET';

  @override
  String get motionScreenFullSubtitle => 'chaque dérive, lueur et fioriture';

  @override
  String get motionScreenCalmLabel => 'CALME';

  @override
  String get motionScreenCalmSubtitle =>
      'le décor s’immobilise — rien d’autre ne change';

  @override
  String get momentRailCaptureLabel => 'CAPTURER';

  @override
  String get momentRailYouLabel => 'toi';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author : $caption';
  }

  @override
  String get momentTagFate => 'DESTIN';

  @override
  String get momentTagJinx => 'POISSE';

  @override
  String get momentTagLuck => 'CHANCE';

  @override
  String get momentTagCalledIt => 'JE L’AVAIS DIT';

  @override
  String get momentTagNpc => 'PNJ';

  @override
  String get momentTagFateHint => 'quelles sont les chances';

  @override
  String get momentTagJinxHint => 'tu l’as bien cherché';

  @override
  String get momentTagLuckHint => 'ça a tourné en ta faveur';

  @override
  String get momentTagCalledItHint => 'tu l’avais vu venir';

  @override
  String get momentTagNpcHint => 'cerveau éteint';

  @override
  String get momentComposerTitle => 'qu’est-ce qui s’est passé ?';

  @override
  String get momentComposerCaptionHint => 'raconte';

  @override
  String get momentComposerTagPrompt => 'un point gagné ? ajoute-le';

  @override
  String get momentComposerCapture => 'appareil photo';

  @override
  String get momentComposerLibrary => 'galerie';

  @override
  String get momentComposerRemovePhoto => 'retirer la photo';

  @override
  String get momentComposerPost => 'PUBLIER';

  @override
  String get momentComposerErrorDailyCap =>
      'ça fait cinq aujourd’hui — gardes-en pour demain';

  @override
  String get momentComposerErrorNotAllowed =>
      'un tuteur a désactivé le partage de photos';

  @override
  String get momentComposerErrorTooLong => 'c’est un peu long — raccourcis';

  @override
  String get momentComposerErrorEmpty => 'ajoute une photo ou quelques mots';

  @override
  String get momentComposerErrorGeneric => 'publication impossible — réessaie';

  @override
  String get momentViewerDelete => 'supprimer';

  @override
  String get momentViewerDeleteConfirmHeadline => 'supprimer ça ?';

  @override
  String get momentViewerDeleteConfirmBody =>
      'ça disparaît du tableau de tout le monde et de tes archives, définitivement';

  @override
  String get momentViewerDeleteFailed => 'suppression impossible — réessaie';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who a publié un moment';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name a pris un $tag';
  }

  @override
  String get momentActivityJustNow => 'à l’instant';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '${count}min';
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
      other: '$count de plus aujourd’hui',
      one: '1 de plus aujourd’hui',
    );
    return '$_temp0';
  }

  @override
  String get puzzleScreenTitle => 'l’énigme.';

  @override
  String get puzzleScreenSubtitle => 'quatre symboles, six essais';

  @override
  String get puzzleSubmit => 'DEVINER';

  @override
  String get puzzleBackspace => 'effacer le dernier symbole';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'symbole $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'résolu en $count';
  }

  @override
  String get puzzleFailedTitle => 'plus d’essais';

  @override
  String get puzzleAnswerWas => 'LE CODE ÉTAIT';

  @override
  String get puzzleShare => 'COPIER LE RÉSULTAT';

  @override
  String get puzzleShareCopied => 'copié — envoie-le à un ami';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved =>
      'tu as déjà résolu celle d’aujourd’hui';

  @override
  String get puzzleErrorOutOfGuesses => 'plus d’essais aujourd’hui';

  @override
  String get puzzleErrorGeneric => 'envoi impossible — réessaie';

  @override
  String get puzzleScoreboardLabel => 'SCORES DU JOUR';

  @override
  String get puzzleScoreboardEmpty => 'personne n’a encore terminé aujourd’hui';

  @override
  String get puzzleTilePlay => 'joue l’énigme du jour';

  @override
  String puzzleTileInProgress(Object count) {
    return '$count restants';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '#$rank sur $total';
  }

  @override
  String get profileVisibilityScreenSectionFeed => 'FIL';

  @override
  String get profileVisibilityScreenFeedLabel => 'mes moments forts';

  @override
  String get profileVisibilityScreenFeedDesc =>
      'si les photos et vidéos que tu publies apparaissent sur les tableaux de tes amis ce jour-là';

  @override
  String get profileVisibilityScreenPuzzleLabel => 'mon score à l’énigme';

  @override
  String get profileVisibilityScreenPuzzleDesc =>
      'si tes amis voient comment tu t’en es sorti à l’énigme du jour';

  @override
  String get profileVisibilityScreenPointsPastLabel => 'mon passé';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      'aujourd’hui est toujours partagé avec tes amis — ceci ouvre tout ce qui précède';

  @override
  String get momentComposerVideo => 'vidéo';

  @override
  String get momentComposerErrorTooBig =>
      'cette vidéo est trop lourde — 20 Mo maximum';

  @override
  String get momentActivityPostedHighlightSelf => 'tu as publié un moment';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'tu as pris un $tag';
  }

  @override
  String pointLineSelf(Object tag) {
    return 'toi · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'qu’est-ce qui s’est passé ?';

  @override
  String get pointComposerNoteHint => 'choisis-en une puis raconte';

  @override
  String get pointComposerAdd => 'AJOUTER LE POINT';

  @override
  String get pointComposerAddPhoto => 'ajouter une photo';

  @override
  String get pointsBoardAdd => 'AJOUTER UN POINT';

  @override
  String get pointsExplainerOpen => 'c’est quoi ?';

  @override
  String get pointsExplainerTitle => 'le jeu des points';

  @override
  String get pointsExplainerIntro =>
      'Une blague qui dure, avec un score. Quand il t’arrive quelque chose — bien, mal ou juste bizarre — tu le notes et ça reste au tableau pour la journée.';

  @override
  String get pointsExplainerRuleHonour =>
      'Tu t’attribues tes propres points. Personne ne vérifie — c’est tout l’intérêt, et tes amis te le diront si tu exagères.';

  @override
  String get pointsExplainerRuleToday =>
      'Les points repartent à zéro chaque jour. Le tableau montre aujourd’hui ; ton historique reste à toi.';

  @override
  String get pointsExplainerRuleCap =>
      'Cinq d’un même type par jour, pour que personne ne transforme le tableau en n’importe quoi.';

  @override
  String get pointsExplainerGotIt => 'COMPRIS';

  @override
  String get momentTagFateExample =>
      'je suis tombé sur mon dentiste à l’étranger';

  @override
  String get momentTagJinxExample =>
      'j’ai lavé la voiture, il a plu à seize heures';

  @override
  String get momentTagLuckExample => 'j’ai eu le train à deux secondes près';

  @override
  String get momentTagCalledItExample =>
      'j’avais dit que la suite ferait un flop, elle a floppé';

  @override
  String get momentTagNpcExample => 'j’ai dit ‘vous aussi’ au serveur';

  @override
  String feedBoardEditionHint(Object number) {
    return 'jour $number du fil';
  }

  @override
  String get feedBoardHighlightsHint =>
      'photos et vidéos qui valent le coup d’œil';

  @override
  String get profileVisibilityScreenPointsLabel => 'mes points';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'si les points que tu notes apparaissent sur les tableaux de tes amis';

  @override
  String get momentComposerEditPhoto => 'modifier le cadrage';

  @override
  String get archiveScreenTitle => 'tes archives';

  @override
  String get archiveScreenEnd => 'c’est tout';

  @override
  String get archiveScreenEmptyTitle => 'rien de gardé pour l’instant';

  @override
  String get archiveScreenEmptyBody =>
      'les moments quittent les tableaux de tes amis après un jour, mais ils restent ici pour toi.';

  @override
  String get archiveScreenEmptyFriendTitle => 'rien ici';

  @override
  String get archiveScreenEmptyFriendBody =>
      'cette personne n’a encore rien publié que tu puisses voir.';

  @override
  String get archiveScreenPrivateTitle => 'son passé est privé';

  @override
  String get archiveScreenPrivateBody =>
      'tu peux toujours voir ce qu’elle publie aujourd’hui.';

  @override
  String get archiveScreenNotFriendTitle => 'vous n’êtes pas amis';

  @override
  String get archiveScreenNotFriendBody =>
      'tu ne peux remonter que les journées d’un ami.';

  @override
  String get archiveScreenErrorTitle => 'chargement impossible';

  @override
  String get archiveScreenErrorBody => 'vérifie ta connexion et réessaie.';

  @override
  String get feedBoardOpenArchive => 'archives';

  @override
  String get feedBoardGamesLabel => 'LES JEUX';

  @override
  String get feedBoardGamesOpen => 'tous les jeux';

  @override
  String get gamesScreenTitle => 'les jeux.';

  @override
  String get gamesScreenSubtitle =>
      'quatre grilles par jour, les mêmes pour tout le monde';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il en reste $count aujourd\'hui',
      one: 'il en reste un aujourd\'hui',
      zero: 'tout est fait aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => 'impossible de charger les jeux du jour';

  @override
  String get gamesRetry => 'RÉESSAYER';

  @override
  String get gameQueensName => 'reines';

  @override
  String get gameQueensRule =>
      'une couronne par ligne, colonne et couleur — jamais adjacentes';

  @override
  String get gameTangoName => 'tango';

  @override
  String get gameTangoRule =>
      'trois soleils, trois lunes, jamais trois à la suite';

  @override
  String get gameZipName => 'zip';

  @override
  String get gameZipRule =>
      'une ligne par toutes les cases, les nombres dans l\'ordre';

  @override
  String get gameSudokuName => 'mini sudoku';

  @override
  String get gameSudokuRule => 'de 1 à 6 une fois par ligne, colonne et bloc';

  @override
  String get gameCodeName => 'le code';

  @override
  String get gameStatusUnplayed => 'pas joué';

  @override
  String get gameStatusUnfinished => 'en cours';

  @override
  String get gameStatusGaveUp => 'abandonné';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'pause';

  @override
  String get gameResume => 'reprendre';

  @override
  String get gamePausedTitle => 'en pause';

  @override
  String get gamePausedBody => 'le chrono est arrêté et la grille masquée';

  @override
  String get gameUndo => 'annuler';

  @override
  String get gameClear => 'effacer';

  @override
  String get gameHint => 'indice';

  @override
  String get gameNotes => 'notes';

  @override
  String get gameErase => 'gomme';

  @override
  String get gameAutoCross => 'croix auto';

  @override
  String get gameGiveUp => 'abandonner';

  @override
  String get gameGiveUpTitle => 'afficher la solution ?';

  @override
  String get gameGiveUpBody =>
      'la grille du jour se ferme et sera comptée comme non résolue.';

  @override
  String get gameGiveUpCancel => 'CONTINUER';

  @override
  String get gameGiveUpConfirm => 'AFFICHER';

  @override
  String gameSolvedTitle(Object time) {
    return 'résolu en $time';
  }

  @override
  String get gameGaveUpTitle => 'la solution du jour';

  @override
  String get gameFirstInToday => 'premier aujourd\'hui';

  @override
  String gameRankLine(Object place, Object total) {
    return '$place sur $total pour l\'instant';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erreurs',
      one: '1 erreur',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count indices',
      one: '1 indice',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => 'TEMPS DU JOUR';

  @override
  String get gameStandingsEmpty => 'personne ne l\'a encore terminé';

  @override
  String get gameShare => 'COPIER LE RÉSULTAT';

  @override
  String get gameShareCopied => 'copié — colle-le à un ami';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => 'tous les jeux';

  @override
  String get gameElapsedSemantic => 'temps écoulé';

  @override
  String get gameErrorNotSolved => 'cette grille n\'est pas encore terminée';

  @override
  String get gameErrorAlreadyFinished => 'tu as déjà terminé celui du jour';

  @override
  String get gameErrorNoHint => 'pas d\'indice pour celui-ci';

  @override
  String get gameErrorGeneric => 'impossible de joindre les jeux — réessaie';

  @override
  String get gameInfoOpen => 'comment jouer';

  @override
  String get gameInfoLabel => 'COMMENT JOUER';

  @override
  String get gameInfoRulesLabel => 'LES RÈGLES';

  @override
  String get gameInfoControlsLabel => 'COMMANDES';

  @override
  String get gameInfoScoringTimed =>
      'le chrono tourne tant que la grille est à l\'écran et s\'arrête si tu mets en pause ou si tu sors. le plus rapide est en tête du jour.';

  @override
  String get gameInfoScoringGuesses =>
      'le score dépend du nombre d\'essais, pas du chrono.';

  @override
  String get gameInfoSameForEveryone =>
      'tout le monde a la même grille aujourd\'hui.';

  @override
  String get gameInfoQueensGoal =>
      'place une couronne dans chaque ligne, colonne et couleur.';

  @override
  String get gameInfoQueensRule1 =>
      'huit couronnes : une par ligne et une par colonne.';

  @override
  String get gameInfoQueensRule2 =>
      'chaque bloc de couleur reçoit aussi exactement une couronne.';

  @override
  String get gameInfoQueensRule3 =>
      'deux couronnes ne peuvent pas se toucher, même par un coin.';

  @override
  String get gameInfoQueensControls =>
      'touche une case une fois pour une croix qui l\'écarte, encore pour une couronne, encore pour l\'effacer.';

  @override
  String get gameInfoTangoGoal => 'remplis la grille de soleils et de lunes.';

  @override
  String get gameInfoTangoRule1 =>
      'chaque ligne et chaque colonne contient trois soleils et trois lunes.';

  @override
  String get gameInfoTangoRule2 =>
      'jamais trois identiques à la suite, en ligne comme en colonne.';

  @override
  String get gameInfoTangoRule3 =>
      'un = entre deux cases veut dire qu\'elles sont identiques ; un × qu\'elles diffèrent.';

  @override
  String get gameInfoTangoControls =>
      'touche une case pour un soleil, encore pour une lune, encore pour l\'effacer. les cases imprimées ne bougent pas.';

  @override
  String get gameInfoZipGoal =>
      'trace une seule ligne qui passe par toutes les cases.';

  @override
  String get gameInfoZipRule1 =>
      'commence sur le 1 et termine sur le dernier nombre.';

  @override
  String get gameInfoZipRule2 =>
      'passe par les nombres dans l\'ordre en chemin.';

  @override
  String get gameInfoZipRule3 =>
      'chaque case est utilisée exactement une fois.';

  @override
  String get gameInfoZipControls =>
      'fais glisser ton doigt pour tracer. reviens sur la ligne pour l\'effacer.';

  @override
  String get gameInfoSudokuGoal =>
      'remplis la grille avec les chiffres de 1 à 6.';

  @override
  String get gameInfoSudokuRule1 =>
      'chaque ligne utilise 1 à 6, une fois chacun.';

  @override
  String get gameInfoSudokuRule2 => 'chaque colonne aussi.';

  @override
  String get gameInfoSudokuRule3 => 'et chaque bloc de 2x3 aussi.';

  @override
  String get gameInfoSudokuControls =>
      'touche une case, puis un chiffre. retouche le même chiffre pour l\'effacer. le mode notes écrit de petites annotations.';

  @override
  String get gameInfoCodeGoal => 'devine le code caché de quatre symboles.';

  @override
  String get gameInfoCodeRule1 =>
      'six essais, et le code ne répète jamais un symbole.';

  @override
  String get gameInfoCodeRule2 => 'vert veut dire bon symbole, bonne place.';

  @override
  String get gameInfoCodeRule3 =>
      'jaune veut dire bon symbole, mauvaise place.';

  @override
  String get gameInfoCodeControls =>
      'touche des symboles pour composer un essai, puis envoie-le. la grille te dit à quel point tu étais proche.';

  @override
  String get savedMessagesTitle => 'Messages enregistrés';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'aucune discussion ne correspond à « $query »';
  }

  @override
  String get pullRevealSearchHint => 'rechercher des discussions…';

  @override
  String get pullRevealCollapseSemanticLabel =>
      'Masquer la recherche et les discussions archivées';

  @override
  String archivedChatsFolderLabel(Object count) {
    return 'discussions archivées ($count)';
  }

  @override
  String get archivedChatsFolderTitle => 'discussions archivées';

  @override
  String get pullRevealClearSearchSemanticLabel => 'Effacer la recherche';

  @override
  String get archivedChatsSheetTitle => 'CHATS ARCHIVÉS';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'CHATS ARCHIVÉS · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'plus rien d\'archivé';

  @override
  String get pinnedBadgeLabel => 'ÉPINGLÉ';

  @override
  String get chatRowActionMenuPinLabel => 'ÉPINGLER LE CHAT';

  @override
  String get chatRowActionMenuUnpinLabel => 'DÉSÉPINGLER LE CHAT';

  @override
  String get chatRowActionMenuArchiveLabel => 'ARCHIVER LE CHAT';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'DÉSARCHIVER LE CHAT';

  @override
  String get messageActionMenuSaveLabel => 'ENREGISTRER';

  @override
  String get messageActionMenuUnsaveLabel => 'RETIRER';

  @override
  String get roomScreenSaveLimitSnack =>
      'trop de messages enregistrés ici — retires-en un d’abord';

  @override
  String get roomScreenSaveFailedSnack => 'impossible d’enregistrer ça';

  @override
  String get threadOverlaySaveLimitToast =>
      'trop de messages enregistrés ici — retires-en un d’abord';

  @override
  String get threadOverlaySaveFailedToast => 'impossible d’enregistrer ça';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'toi seul vois les messages que tu enregistres ; un message épinglé, c’est l’inverse : toute la salle le voit.';

  @override
  String get roomInfoScreenOwnerBadgeNote =>
      'la petite médaille à côté d’un nom indique qui a créé cette salle.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return 'Aller au message enregistré de $name';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return 'Retirer des enregistrés le message de $name';
  }

  @override
  String get muteSheetTitle => 'METTRE EN SOURDINE';

  @override
  String get muteSheetSubtitle =>
      'Choisissez ce qui doit se taire, et pour combien de temps.';

  @override
  String get muteSheetNotificationsTitle => 'Notifications';

  @override
  String get muteSheetNotificationsSub => 'Aucune bannière, aucun son';

  @override
  String get muteSheetBadgesTitle => 'Compteur de non-lus';

  @override
  String get muteSheetBadgesSub =>
      'Aucun nombre sur la conversation, rien sur l\'icône de l\'app';

  @override
  String get muteSheetDurationLabel => 'PENDANT COMBIEN DE TEMPS';

  @override
  String get muteDurationHour => '1 heure';

  @override
  String get muteDurationEightHours => '8 heures';

  @override
  String get muteDurationWeek => '1 semaine';

  @override
  String get muteDurationAlways => 'Toujours';

  @override
  String get muteSheetConfirmButton => 'METTRE EN SOURDINE';

  @override
  String get muteSheetSaveButton => 'ENREGISTRER';

  @override
  String get muteSheetUnmuteButton => 'RÉACTIVER';

  @override
  String get muteSummaryAll =>
      'Rien de cette conversation ne vous parvient : ni notification, ni compteur de non-lus.';

  @override
  String get muteSummaryNotificationsOnly =>
      'Aucune notification. Le compteur de non-lus continue de monter.';

  @override
  String get muteSummaryBadgesOnly =>
      'Aucun compteur de non-lus. Les notifications arrivent toujours.';

  @override
  String get muteSummaryNothingPicked =>
      'Choisissez au moins une chose à faire taire.';

  @override
  String muteUntilSentence(String when) {
    return 'Jusqu\'à $when.';
  }

  @override
  String get muteUntilAlwaysSentence => 'Jusqu\'à ce que vous la réactiviez.';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String get mutedBadgeLabel => 'EN SOURDINE';

  @override
  String get chatRowActionMenuMuteLabel => 'METTRE EN SOURDINE';

  @override
  String get chatRowActionMenuUnmuteLabel => 'RÉACTIVER LA CONVERSATION';

  @override
  String get roomInfoScreenMuteLabel => 'SOURDINE';

  @override
  String get roomInfoScreenNotMutedRow => 'Pas en sourdine';

  @override
  String get attachmentMenuLocationLabel => 'position';

  @override
  String get locationSheetSendCurrent => 'Envoyer la position actuelle';

  @override
  String get locationSheetSendCurrentDetail => 'Où vous êtes en ce moment';

  @override
  String get locationSheetLiveHeading => 'PARTAGE EN DIRECT';

  @override
  String get locationSheetLiveDetail => 'S’arrête tout seul';

  @override
  String get locationShareFor15Minutes => 'Pendant 15 minutes';

  @override
  String get locationShareFor1Hour => 'Pendant 1 heure';

  @override
  String get locationShareFor8Hours => 'Pendant 8 heures';

  @override
  String get locationBubbleOpenInMaps => 'Ouvrir dans Plans';

  @override
  String get locationBubbleLiveBadge => 'EN DIRECT';

  @override
  String get locationBubbleEndedBadge => 'TERMINÉ';

  @override
  String locationBubbleLiveUntil(String time) {
    return 'En direct jusqu’à $time';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return 'Position en direct terminée à $time';
  }

  @override
  String get locationBubbleNoRecentUpdate => 'Aucune mise à jour récente';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters m';
  }

  @override
  String get locationBubbleStopSharing => 'Arrêter le partage';

  @override
  String get locationBubbleUnavailable => 'Position indisponible';

  @override
  String get locationBubbleNoMapsApp =>
      'Aucune application de cartes pour ouvrir ceci';

  @override
  String get locationBubbleCoordinatesCopied => 'Coordonnées copiées';

  @override
  String get locationCouldNotGetFix => 'Impossible d’obtenir votre position';

  @override
  String get locationCouldNotStartLiveShare =>
      'Impossible de démarrer le partage en direct';

  @override
  String get locationPermissionNeeded =>
      'L’accès à la position est nécessaire pour partager où vous êtes';

  @override
  String get locationPermissionBlockedTitle =>
      'L’accès à la position est désactivé';

  @override
  String get locationPermissionBlockedBody =>
      'MonkeyHub ne peut plus le demander ici. Activez l’accès à la position pour MonkeyHub dans Réglages.';

  @override
  String get locationServicesOffTitle =>
      'Les services de localisation sont désactivés';

  @override
  String get locationServicesOffBody =>
      'La localisation est désactivée sur cet appareil. Activez-la dans Réglages pour partager où vous êtes.';

  @override
  String get locationOpenSettings => 'Ouvrir les réglages';

  @override
  String get locationBackgroundSheetTitle => 'Si votre téléphone redémarre';

  @override
  String get locationBackgroundSheetBody =>
      'Votre partage en direct continue déjà quand vous quittez MonkeyHub. L’accès en arrière-plan couvre le reste : un redémarrage, une fermeture forcée, un téléphone tombé en panne de batterie qui revient.';

  @override
  String get locationBackgroundSheetKeepRunning => 'La reprendre toute seule';

  @override
  String get locationBackgroundSheetKeepRunningDetail =>
      'Votre téléphone vous demandera l’autorisation';

  @override
  String get locationBackgroundSheetAppOnly => 'La laisser arrêtée';

  @override
  String get locationBackgroundSheetAppOnlyDetail => 'Rien d’autre à autoriser';

  @override
  String get locationServiceNotificationTitle =>
      'Partage de votre position en direct';

  @override
  String get locationServiceNotificationBody =>
      'Touchez pour ouvrir la conversation, ou Arrêter pour y mettre fin';

  @override
  String get childPolicyScreenLocationLabel => 'Position';

  @override
  String get childPolicyScreenLocationOnDesc =>
      'Peut partager où il ou elle est, y compris en direct jusqu’à 8 heures';

  @override
  String get childPolicyScreenLocationOffDesc =>
      'Ne peut pas partager où il ou elle est';

  @override
  String get roomInfoScreenSavedMessagesLabel => 'MESSAGES ENREGISTRÉS';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      'toi seul peux les voir, et seulement depuis ce salon. ta discussion Messages enregistrés est distincte.';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      'rien d’enregistré pour l’instant. maintiens un message et choisis ENREGISTRER.';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return 'Aller au message enregistré de $name';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return 'Retirer des enregistrés le message de $name';
  }

  @override
  String get composerCaptureCameraModeLabel => 'appareil photo';

  @override
  String get composerCaptureVoiceModeLabel => 'message vocal';

  @override
  String get composerCaptureVideoNoteModeLabel => 'note vidéo';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode. Balayez à deux doigts ou utilisez les flèches pour changer de mode.';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '$mode sélectionné';
  }

  @override
  String get composerCaptureRecordingAnnouncement => 'Enregistrement démarré';

  @override
  String get composerCaptureLockedAnnouncement =>
      'Enregistrement verrouillé. Mains libres.';

  @override
  String get composerCaptureCancelledAnnouncement => 'Enregistrement supprimé';

  @override
  String get composerCaptureSentAnnouncement => 'Enregistrement envoyé';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return 'Enregistrement, $elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint =>
      'Maintenez pour enregistrer, glissez pour changer';

  @override
  String get composerCaptureTapForCameraHint =>
      'Appuyez pour la caméra, glissez pour changer';

  @override
  String get composerCaptureSlideToCancelHint => 'glissez pour annuler';

  @override
  String get composerCaptureReleaseToCancelHint => 'relâchez pour annuler';

  @override
  String get composerCaptureTapToSendHint => 'appuyez pour envoyer';

  @override
  String get composerCaptureSendingLabel => 'envoi…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return '$seconds s restantes';
  }

  @override
  String get composerCaptureCancelLabel => 'supprimer l\'enregistrement';

  @override
  String get composerCaptureSendLabel => 'envoyer l\'enregistrement';

  @override
  String get composerCaptureLockLabel =>
      'glissez vers le haut pour verrouiller l\'enregistrement';

  @override
  String get composerCaptureMicPermissionTitle => 'Microphone requis';

  @override
  String get composerCaptureMicPermissionBody =>
      'MonkeyHub a besoin de votre microphone pour enregistrer un message vocal. Activez-le dans les Réglages et réessayez.';

  @override
  String get composerCaptureCameraPermissionTitle => 'Appareil photo requis';

  @override
  String get composerCaptureCameraPermissionBody =>
      'MonkeyHub a besoin de votre appareil photo et de votre microphone pour enregistrer une note vidéo. Activez-les dans les Réglages et réessayez.';

  @override
  String get composerCaptureRestrictedBody =>
      'L\'enregistrement est désactivé par une restriction sur cet appareil.';

  @override
  String get composerCaptureOpenSettingsLabel => 'Ouvrir les Réglages';

  @override
  String get composerCaptureUnavailableSnack =>
      'L\'enregistrement n\'est pas disponible sur cet appareil.';

  @override
  String get composerCaptureInterruptedSnack => 'Enregistrement interrompu.';

  @override
  String get composerCaptureStorageSnack =>
      'Impossible d\'enregistrer. Vérifiez votre espace libre.';

  @override
  String get videoNoteMessagePlayLabel => 'lire la note vidéo';

  @override
  String get videoNoteMessagePauseLabel => 'mettre la note vidéo en pause';

  @override
  String get videoNoteMessageLoadingLabel => 'chargement de la note vidéo';

  @override
  String get videoNoteMessageUnavailableLabel => 'note vidéo indisponible';

  @override
  String get videoNoteMessageRetryLabel => 'réessayer la note vidéo';

  @override
  String get videoNoteMessageRetryHint => 'appuyez pour réessayer';

  @override
  String get videoNoteMessageDiscardLabel => 'supprimer la note vidéo';

  @override
  String get attachmentMenuVideoNoteLabel => 'note vidéo';

  @override
  String get cameraScreenPhotoModeLabel => 'PHOTO';

  @override
  String get cameraScreenVideoModeLabel => 'VIDÉO';

  @override
  String get cameraScreenStartRecordingLabel => 'démarrer l\'enregistrement';

  @override
  String get cameraScreenStopRecordingLabel => 'arrêter l\'enregistrement';

  @override
  String get cameraScreenVideoFailedSnack =>
      'Impossible d\'enregistrer cette vidéo.';

  @override
  String get scheduleSheetTitle => 'PROGRAMMER LE MESSAGE';

  @override
  String get scheduleSheetSubtitle =>
      'Écrivez-le maintenant. Il partira quand vous voudrez.';

  @override
  String get scheduleSheetWhenLabel => 'QUAND';

  @override
  String get schedulePresetInAnHour => 'Dans 1 heure';

  @override
  String get schedulePresetInEightHours => 'Dans 8 heures';

  @override
  String get schedulePresetTomorrowMorning => 'Demain matin';

  @override
  String get schedulePresetThisMorning => 'Ce matin';

  @override
  String get schedulePresetInAWeek => 'Dans 1 semaine';

  @override
  String get scheduleSheetCustomChip => 'Choisir une date';

  @override
  String get scheduleSheetConfirmButton => 'PROGRAMMER';

  @override
  String get scheduleSheetSaveButton => 'ENREGISTRER';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'Envoi $when.';
  }

  @override
  String scheduleWhenToday(String time) {
    return 'aujourd’hui à $time';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return 'demain à $time';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return 'le $date à $time';
  }

  @override
  String get scheduleTimePickerTitle => 'CHOISIR LA DATE ET L’HEURE';

  @override
  String get scheduleTimePickerBack => 'Choix rapides';

  @override
  String get scheduleTimePickerToday => 'Aujourd’hui';

  @override
  String get scheduleTimePickerTomorrow => 'Demain';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PROGRAMMÉS',
      one: '1 PROGRAMMÉ',
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
      other: '$count messages en attente d’envoi. Touchez pour les voir.',
      one: '1 message en attente d’envoi. Touchez pour le voir.',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => 'À VÉRIFIER';

  @override
  String get scheduledListTitle => 'PROGRAMMÉS';

  @override
  String get scheduledListSubtitle => 'Vous seul les voyez jusqu’à leur envoi.';

  @override
  String get scheduledListEmpty => 'Rien en attente d’envoi ici.';

  @override
  String get scheduledListSendNow => 'Envoyer maintenant';

  @override
  String get scheduledListChangeTime => 'Changer l’heure';

  @override
  String get scheduledListEdit => 'Modifier le texte';

  @override
  String get scheduledListDelete => 'Supprimer';

  @override
  String get scheduledListSending => 'Envoi…';

  @override
  String get scheduledListFailedTitle => 'Envoi impossible';

  @override
  String get scheduledListRetry => 'Réessayer';

  @override
  String get scheduleErrorOutOfRange =>
      'Choisissez une heure comprise entre deux minutes et un an à partir de maintenant.';

  @override
  String get scheduleErrorTooMany =>
      'Trop de messages en attente ici. Envoyez-en ou supprimez-en d’abord.';

  @override
  String get scheduleErrorNotInEphemeral =>
      'Les messages de cette conversation s’effacent d’eux-mêmes : impossible de les programmer.';

  @override
  String get scheduleErrorNotMember =>
      'Vous ne faites plus partie de cette conversation.';

  @override
  String get scheduleErrorBlocked =>
      'Vous devez d’abord débloquer cette personne.';

  @override
  String get scheduleErrorGeneric => 'Ça n’a pas marché. Réessayez.';

  @override
  String get scheduleEditTitle => 'MODIFIER LE MESSAGE';

  @override
  String get composerScheduleAction => 'Programmer ce message';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages en attente d’envoi',
      one: '1 message en attente d’envoi',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => 'AFFICHER COMME';

  @override
  String get scheduledIndicatorPill => 'Pastille';

  @override
  String get scheduledIndicatorBadge => 'Badge';

  @override
  String get scheduledIndicatorBoth => 'Les deux';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages déjà en attente',
      one: '1 message déjà en attente',
      zero: 'Rien en attente d’envoi',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => 'Comment ils apparaissent';

  @override
  String get scheduledIndicatorPillSub =>
      'Une barre au-dessus de la zone de texte. Touchez-la pour les voir.';

  @override
  String get scheduledIndicatorBadgeSub =>
      'Un compteur sur le bouton d’envoi. Rien ne s’affiche tant que vous n’écrivez pas.';

  @override
  String get scheduledIndicatorBothSub =>
      'La barre, plus le compteur pendant que vous écrivez.';

  @override
  String get scheduledBack => 'Retour';

  @override
  String get serverScreenTitle => 'serveur.';

  @override
  String get serverScreenSubtitle => 'où vivent votre compte et vos messages';

  @override
  String get serverOnboardingTitle => 'choisissez un serveur.';

  @override
  String get serverOnboardingSubtitle =>
      'cette version n\'en fournit aucun — indiquez le vôtre';

  @override
  String get serverStatusConnected => 'CONNECTÉ';

  @override
  String get serverStatusDisconnected => 'NON CONNECTÉ';

  @override
  String get serverBadgeDefault => 'PAR DÉFAUT';

  @override
  String get serverBadgeSelfHosted => 'AUTO-HÉBERGÉ';

  @override
  String get serverNoneConfigured => 'Pas encore de serveur';

  @override
  String get serverActiveNowLabel => 'UTILISÉ';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'Le serveur fourni avec l\'application.';

  @override
  String get serverChoiceOwn => 'Votre propre serveur';

  @override
  String get serverChoiceOwnSub =>
      'Un backend Convex que vous gérez vous-même.';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => 'COLLER';

  @override
  String get serverProblemMalformed => 'Ce n\'est pas une adresse web.';

  @override
  String get serverProblemBadScheme => 'Commencez par https:// ou http://.';

  @override
  String get serverProblemNoHost =>
      'Ajoutez l\'adresse de votre serveur après https://.';

  @override
  String get serverProblemCredentials =>
      'Retirez le nom d\'utilisateur et le mot de passe de l\'adresse.';

  @override
  String get serverInsecureTitle => 'NON CHIFFRÉ';

  @override
  String get serverInsecureBody =>
      'Les téléphones bloquent le http non chiffré : cette adresse ne se connectera pas sur iOS ni Android. Utilisez https, ou passez par un tunnel.';

  @override
  String get serverTestCta => 'TESTER LA CONNEXION';

  @override
  String get serverTestingLabel => 'Test en cours…';

  @override
  String get serverCheckReachable => 'Quelque chose a répondu';

  @override
  String get serverCheckConvex => 'C\'est un serveur Convex';

  @override
  String get serverCheckApp => 'MonkeyHub y est déployé';

  @override
  String get serverResultUnreachable => 'Rien n\'a répondu à cette adresse.';

  @override
  String get serverResultNotConvex =>
      'Quelque chose a répondu, mais ce n\'est pas un serveur Convex.';

  @override
  String get serverResultNotThisApp =>
      'C\'est un serveur Convex, mais MonkeyHub n\'y est pas déployé.';

  @override
  String get serverResultServerError =>
      'Le serveur a répondu, mais par une erreur.';

  @override
  String get serverResultReady => 'Prêt à se connecter.';

  @override
  String get serverConnectCta => 'SE CONNECTER';

  @override
  String get serverConnectAnywayCta => 'SE CONNECTER QUAND MÊME';

  @override
  String get serverAlreadyConnectedCta => 'DÉJÀ CONNECTÉ';

  @override
  String get serverUseDefaultCta => 'UTILISER LE SERVEUR PAR DÉFAUT';

  @override
  String get serverChangeCta => 'CHANGER DE SERVEUR';

  @override
  String get serverAdvancedLabel => 'AVANCÉ';

  @override
  String get serverSiteUrlExplain =>
      'La plupart des serveurs répondent à tout sur une seule adresse. Ne remplissez ceci que si le vôtre sert les actions HTTP ailleurs.';

  @override
  String get serverSiteUrlHint => 'Comme ci-dessus';

  @override
  String get serverSectionRecent => 'RÉCENTS';

  @override
  String get serverRecentForget => 'Oublier ce serveur';

  @override
  String get serverSwitchWarningTitle => 'CHANGER VOUS DÉCONNECTE';

  @override
  String get serverSwitchWarningBody =>
      'Les comptes et les conversations appartiennent à un seul serveur. Cet appareil se déconnecte, efface ce qu\'il a téléchargé et repart de zéro. Rien n\'est supprimé sur l\'un ou l\'autre serveur.';

  @override
  String get serverSwitchRolledBackTitle => 'CONNEXION IMPOSSIBLE';

  @override
  String serverSwitchRolledBackBody(String host) {
    return '$host n\'a pas répondu, rien n\'a changé. Vous devrez vous reconnecter.';
  }

  @override
  String get serverSwitchStrandedBody =>
      'Aucun des deux serveurs n\'a pu se connecter. Vérifiez l\'adresse et réessayez.';

  @override
  String get serverSwitchRefusedBody =>
      'Cet appareil est configuré pour un enfant et ne peut pas changer de serveur.';

  @override
  String serverChipSemantics(String server) {
    return 'Changer de serveur. Actuellement $server.';
  }

  @override
  String get serverValueDefault => 'Par défaut';

  @override
  String get settingsScreenRowServer => 'SERVEUR';

  @override
  String get settingsScreenSectionAdvanced => 'AVANCÉ';

  @override
  String get serverSwitchingLabel => 'Changement de serveur…';

  @override
  String get serverRoleExplainAction => 'Qu\'est-ce que cela signifie ?';

  @override
  String get serverBadgeRibbonHomeserver => 'MAISON';

  @override
  String get serverBadgeRibbonSelfHosted => 'PERSO';

  @override
  String get serverBadgeHomeserver => 'Servi depuis le homeserver';

  @override
  String get serverBadgeHomeserverSemantics =>
      'Servi depuis le homeserver. Touchez pour en savoir plus.';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'Serveur auto-hébergé : $server. Touchez pour en savoir plus.';
  }

  @override
  String get serverRoleHomeserverTitle => 'En cours sur le homeserver';

  @override
  String get serverRoleHomeserverBody =>
      'Les personnes qui gèrent MonkeyHub ont basculé le trafic vers leur serveur domestique pour un temps. Tout fonctionne pareil : c\'est volontaire, pas une panne.';

  @override
  String get serverRoleHomeserverWarnData =>
      'Ce que vous envoyez pendant cette période peut ne plus être là une fois le trafic revenu.';

  @override
  String get serverRoleHomeserverWarnSpeed =>
      'Une connexion domestique est plus lente que la normale : il peut y avoir de la latence.';

  @override
  String get serverRoleHomeserverWarnAuto =>
      'Vous n\'avez rien à faire. L\'application revient toute seule.';

  @override
  String get serverRoleSelfHostedTitle => 'Votre propre serveur';

  @override
  String get serverRoleSelfHostedBody =>
      'Cet appareil pointe vers un serveur que vous gérez. Modifiez-le dans Réglages › Avancé › Serveur.';

  @override
  String get serverValueHomeserver => 'Homeserver, pour le moment';

  @override
  String get serverChoiceCloudSubHomeserver =>
      'Servi depuis le homeserver pour un temps.';

  @override
  String get serverDirectiveChangedToast =>
      'Votre serveur a changé. Reconnexion…';

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
  String get roomAdminActionViewProfile => 'Voir le profil';

  @override
  String get roomAdminActionPromote => 'Nommer admin';

  @override
  String get roomAdminActionPromoteSub =>
      'Pourra inviter, exclure et modifier le groupe';

  @override
  String get roomAdminActionDemote => 'Retirer le rôle d\'admin';

  @override
  String get roomAdminActionDemoteSub =>
      'Reste dans le groupe en tant que membre';

  @override
  String get roomAdminActionTransfer => 'Transférer la propriété';

  @override
  String get roomAdminActionTransferSub => 'Tu restes admin';

  @override
  String get roomAdminActionRemove => 'Exclure du groupe';

  @override
  String get roomAdminAddFriendsRow => 'Ajouter des amis';

  @override
  String get roomAdminInviteLinkRow => 'Lien d\'invitation';

  @override
  String get roomAdminJoinRequestsRow => 'Demandes d\'accès';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return 'Confier le groupe à $name ?';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      'Cette personne devient propriétaire et peut supprimer le groupe. Tu restes admin, et elle seule peut te le rendre.';

  @override
  String get roomAdminTransferConfirmCta => 'TRANSFÉRER';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return 'Exclure $name ?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'Cette personne perd l\'accès au groupe et à tout son contenu. Elle peut être réinvitée, ou revenir par le lien d\'invitation.';

  @override
  String get roomAdminRemoveConfirmCta => 'EXCLURE';

  @override
  String get roomAdminGenericError => 'Ça n\'a pas marché. Réessaie.';

  @override
  String get roomAdminErrorNotMember => 'Tu n\'es plus dans ce groupe.';

  @override
  String get roomAdminErrorNotAdmin => 'Seuls les admins peuvent faire ça.';

  @override
  String get roomAdminErrorNotOwner =>
      'Seul le propriétaire du groupe peut faire ça.';

  @override
  String get roomAdminErrorNotGroup =>
      'Il n\'y a rien à administrer dans une conversation privée.';

  @override
  String get roomAdminErrorOwnerImmutable =>
      'Le rôle du propriétaire ne change qu\'en transférant le groupe.';

  @override
  String get roomAdminErrorInvitesLocked =>
      'Seuls les admins peuvent inviter dans ce groupe.';

  @override
  String get roomInviteSheetTitle => 'Lien d\'invitation';

  @override
  String get roomInviteSheetBlurb =>
      'Un lien et un code, et c\'est la même chose. Dès que tu en crées un nouveau, l\'ancien cesse de fonctionner.';

  @override
  String get roomInviteNoLinkYet =>
      'Ce groupe n\'a pas encore de lien d\'invitation.';

  @override
  String get roomInviteCreateButton => 'CRÉER UN LIEN';

  @override
  String get roomInviteRegenerateButton => 'NOUVEAU LIEN';

  @override
  String get roomInviteRevokeButton => 'RÉVOQUER LE LIEN';

  @override
  String get roomInviteCopyLink => 'Copier le lien';

  @override
  String get roomInviteCopyCode => 'Copier le code';

  @override
  String get roomInviteShare => 'Partager';

  @override
  String get roomInviteLinkCopied => 'Lien copié.';

  @override
  String get roomInviteCodeCopied => 'Code copié.';

  @override
  String get roomInviteRegenerateHeadline => 'Créer un nouveau lien ?';

  @override
  String get roomInviteRegenerateBody =>
      'Le lien et le code actuels cessent de fonctionner immédiatement, partout où ils ont été partagés. Les membres actuels restent.';

  @override
  String get roomInviteRegenerateConfirm => 'NOUVEAU LIEN';

  @override
  String get roomInviteRevokeHeadline => 'Révoquer ce lien ?';

  @override
  String get roomInviteRevokeBody =>
      'Personne ne pourra plus entrer par lien tant que tu n\'en crées pas un autre. Les membres actuels restent.';

  @override
  String get roomInviteRevokeConfirm => 'RÉVOQUER';

  @override
  String get roomInviteLimitsLabel => 'LIMITES';

  @override
  String get roomInviteExpiryLabel => 'Expire après';

  @override
  String get roomInviteMaxUsesLabel => 'Nombre d\'utilisations';

  @override
  String get roomInviteNeverExpires => 'Jamais';

  @override
  String get roomInviteUnlimited => 'Illimité';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count h';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count j';
  }

  @override
  String get roomInviteLimitsApplyToNew =>
      'Ça s\'applique au lien que tu vas créer.';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      'Ça s\'applique au prochain lien. Celui du dessus garde les limites avec lesquelles il a été créé.';

  @override
  String get roomInvitePermissionsLabel => 'AUTORISATIONS';

  @override
  String get roomInviteMembersCanInviteLabel =>
      'Les membres peuvent inviter leurs amis';

  @override
  String get roomInviteMembersCanInviteSub =>
      'Désactive-le et seuls les admins feront entrer du monde';

  @override
  String get roomInviteApprovalLabel => 'Approuver chaque arrivée';

  @override
  String get roomInviteApprovalSub =>
      'Ceux qui ont le lien demandent d\'abord, et un admin dit oui ou non';

  @override
  String roomInviteUsesCount(Object count) {
    return 'Utilisé $count fois';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$used utilisations sur $max';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return 'expire le $date';
  }

  @override
  String get roomInviteDeadExpired => 'Ce lien a expiré. Crées-en un nouveau.';

  @override
  String get roomInviteDeadExhausted =>
      'Ce lien n\'a plus d\'utilisations. Crées-en un nouveau.';

  @override
  String get roomInviteDeadRevoked => 'Ce lien a été révoqué.';

  @override
  String get roomInviteDeadGeneric => 'Ce lien ne fonctionne plus.';

  @override
  String get roomInviteFriendsTitle => 'Ajouter des amis';

  @override
  String get roomInviteFriendsBlurb =>
      'Ils recevront une invitation et pourront l\'accepter ou la refuser.';

  @override
  String get roomInviteFriendsSearchHint => 'Chercher des amis';

  @override
  String get roomInviteFriendsInviteButton => 'INVITER';

  @override
  String get roomInviteFriendsSent => 'Invité';

  @override
  String get roomInviteFriendsEmpty =>
      'Tous tes amis sont déjà là ou déjà invités.';

  @override
  String get roomInviteFriendsNoMatch => 'Aucun ami ne correspond.';

  @override
  String get roomInviteFriendsDone => 'OK';

  @override
  String get roomJoinRequestsTitle => 'Demandes d\'accès';

  @override
  String get roomJoinRequestsBlurb =>
      'Ces personnes ont utilisé le lien d\'invitation. Elles ne voient rien du groupe tant que tu n\'as pas dit oui.';

  @override
  String get roomJoinRequestsEmpty => 'Personne n\'attend.';

  @override
  String get roomJoinRequestsApprove => 'FAIRE ENTRER';

  @override
  String get roomJoinRequestsReject => 'NON';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return 'INVITÉS · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian => 'en attente d\'un parent';

  @override
  String get roomInfoScreenInviteWithdraw => 'RETIRER';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return 'de $inviter · $members membres';
  }

  @override
  String get roomInvitationCardJoin => 'REJOINDRE';

  @override
  String get discoverScreenJoinByCodeTitle => 'rejoindre avec un code';

  @override
  String get discoverScreenJoinByCodeSubtitle =>
      'ouvre un groupe que quelqu\'un t\'a partagé';

  @override
  String get joinInviteTitle => 'Rejoindre un groupe';

  @override
  String get joinInviteBack => 'Retour';

  @override
  String get joinInviteCodeBlurb =>
      'Saisis le code qu\'on t\'a partagé. Un lien d\'invitation complet marche aussi.';

  @override
  String get joinInviteCodeLabel => 'Code d\'invitation';

  @override
  String get joinInviteCodeHint => 'Colle le lien ou tape le code';

  @override
  String get joinInviteCodeInvalid =>
      'Ça ne ressemble pas à un code d\'invitation.';

  @override
  String get joinInviteLookupButton => 'CONTINUER';

  @override
  String get joinInviteLookupFailed =>
      'Impossible de vérifier ce code. Vérifie ta connexion et réessaie.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count membres';
  }

  @override
  String get joinInviteJoinButton => 'REJOINDRE LE GROUPE';

  @override
  String get joinInviteRequestButton => 'DEMANDER À ENTRER';

  @override
  String get joinInviteOpenNote =>
      'Tu verras les messages du groupe dès que tu l\'auras rejoint.';

  @override
  String get joinInviteApprovalNote =>
      'Un admin doit dire oui avant que tu puisses voir quoi que ce soit ici.';

  @override
  String get joinInviteOpenRoom => 'OUVRIR LE GROUPE';

  @override
  String get joinInvitePendingHeadline => 'En attente d\'un admin';

  @override
  String get joinInvitePendingBody =>
      'Tu recevras une notification dès que quelqu\'un répondra.';

  @override
  String get joinInviteBadLinkHeadline => 'Cette invitation ne marche pas';

  @override
  String get joinInviteBadLinkBody =>
      'Vérifie le code, ou demande un nouveau lien.';

  @override
  String get joinInviteExpiredHeadline => 'Cette invitation a expiré';

  @override
  String get joinInviteExpiredBody =>
      'Demande un nouveau lien à la personne qui t\'a invité.';

  @override
  String get joinInviteExhaustedHeadline => 'Cette invitation est épuisée';

  @override
  String get joinInviteExhaustedBody =>
      'Elle était réglée pour un nombre limité d\'utilisations. Demandes-en une autre.';

  @override
  String get joinInviteRevokedHeadline => 'Cette invitation a été remplacée';

  @override
  String get joinInviteRevokedBody =>
      'Un admin a créé un nouveau lien. Demande-lui l\'actuel.';

  @override
  String get joinInviteWrongServerHeadline =>
      'Cette invitation vient d\'un autre serveur';

  @override
  String joinInviteWrongServerBody(Object host) {
    return 'Elle appartient à $host. Ton compte est sur un autre serveur, donc ce groupe n\'est pas accessible d\'ici.';
  }

  @override
  String get roomInviteErrorNotFound =>
      'Ce code d\'invitation ne correspond à rien.';

  @override
  String get roomInviteErrorRevoked =>
      'Cette invitation a été remplacée. Demande le lien actuel.';

  @override
  String get roomInviteErrorExpired => 'Cette invitation a expiré.';

  @override
  String get roomInviteErrorExhausted => 'Cette invitation est épuisée.';

  @override
  String get roomInviteErrorAlreadyMember =>
      'Cette personne est déjà dans le groupe.';

  @override
  String get roomInviteErrorAlreadyInvited =>
      'Cette personne a déjà été invitée.';

  @override
  String get roomInviteErrorSelf => 'Tu es déjà dans ce groupe.';

  @override
  String get roomInviteErrorInvitationGone =>
      'Cette invitation n\'existe plus.';

  @override
  String get roomInviteErrorRequestPending =>
      'Tu as déjà demandé à entrer. Un admin répondra.';

  @override
  String get roomInviteErrorRequestGone =>
      'Quelqu\'un a déjà répondu à cette demande.';

  @override
  String get roomInviteErrorRoomPrivate =>
      'On ne rejoint ce groupe que sur invitation.';

  @override
  String get roomInviteErrorInvalidLimits => 'Ces limites ne sont pas valides.';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$child veut inviter $other dans $room';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$other a invité $child dans $room';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      'L\'invitation part, et c\'est toujours l\'autre personne qui décide.';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$child verra l\'invitation et pourra l\'accepter ou la refuser. En approuvant, tu lui donnes aussi accès à ce groupe si elle accepte.';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      'Tu ne peux pas t\'exclure toi-même. Quitte le groupe à la place.';

  @override
  String get roomAdminActionMessage => 'Envoyer un message';

  @override
  String get roomAdminActionVoiceCall => 'Appel audio';

  @override
  String get roomAdminActionVideoCall => 'Appel vidéo';

  @override
  String get roomAdminYouSuffix => 'toi';

  @override
  String get roomInfoScreenSetPasswordButton => 'DÉFINIR';

  @override
  String get roomInfoScreenPasswordSetSnackbar => 'Mot de passe défini.';

  @override
  String get roomInfoScreenPasswordSetState => 'Mot de passe actif';

  @override
  String get roomInfoScreenPasswordUnsetState => 'Aucun mot de passe';

  @override
  String get roomInfoScreenPasswordCancel => 'Annuler';

  @override
  String get roomInfoScreenEditSave => 'Enregistrer';

  @override
  String get roomInfoScreenEditCancel => 'Annuler';

  @override
  String get roomInviteRotatedToast =>
      'Nouveau lien créé. L\'ancien ne fonctionne plus.';

  @override
  String get roomInviteRevokedToast => 'Lien d\'invitation révoqué.';

  @override
  String get newChatMenuTitle => 'Nouvelle discussion';

  @override
  String get newChatMenuCreateTitle => 'Créer un salon';

  @override
  String get newChatMenuCreateSub => 'Lance un groupe et invite du monde';

  @override
  String get newChatMenuJoinTitle => 'Rejoindre avec un code';

  @override
  String get newChatMenuJoinSub =>
      'Ouvre un groupe que quelqu\'un t\'a partagé';

  @override
  String get shareSheetTitle => 'PARTAGER AVEC';

  @override
  String get shareSheetSuggestedHeading => 'SUGGESTIONS';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pièces jointes',
      one: '1 pièce jointe',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers dépassent la limite de $size et ont été ignorés',
      one: '1 fichier dépasse la limite de $size et a été ignoré',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return 'Envoyer à $title';
  }

  @override
  String get settingsScreenRowSpeakerColors => 'COULEURS DES AUTEURS';

  @override
  String get settingsScreenValueSpeakerOff => 'Désactivé';

  @override
  String get settingsScreenValueSpeakerName => 'Noms';

  @override
  String get settingsScreenValueSpeakerBubble => 'Noms + bulles';

  @override
  String get speakerColorScreenTitle => 'couleurs des auteurs.';

  @override
  String get speakerColorScreenSubtitle => 'qui a dit ça, sans lire le nom';

  @override
  String get speakerColorScreenOffLabel => 'DÉSACTIVÉ';

  @override
  String get speakerColorScreenOffDescription =>
      'tout le monde dans le salon écrit avec la même encre.';

  @override
  String get speakerColorScreenNameLabel => 'NOMS';

  @override
  String get speakerColorScreenNameDescription =>
      'chacun garde sa propre couleur, sur son nom et autour de son visage.';

  @override
  String get speakerColorScreenBubbleLabel => 'BULLES';

  @override
  String get speakerColorScreenBubbleDescription =>
      'la couleur passe aussi dans ses messages : une série de cinq dit encore qui a écrit.';

  @override
  String get roomInfoScreenSpeakerColorsLabel => 'COULEURS';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => 'Automatique';

  @override
  String get roomInfoScreenSpeakerColorsCustom => 'Personnalisé';

  @override
  String get roomColorsScreenTitle => 'qui est qui.';

  @override
  String get roomColorsScreenSubtitle => 'la couleur de chaque personne';

  @override
  String get roomColorsScreenOffTitle =>
      'les couleurs des auteurs sont désactivées';

  @override
  String get roomColorsScreenOffBody =>
      'pour l\'instant tout le monde s\'affiche avec la même encre. activez-les et chacun ici aura la sienne.';

  @override
  String get roomColorsScreenOffAction => 'ACTIVER';

  @override
  String get roomColorsScreenOffHint =>
      's\'applique à tous les salons, pas seulement à celui-ci. aussi dans les réglages.';

  @override
  String get roomColorsScreenAutoChip => 'AUTO';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return 'partagée avec $name';
  }

  @override
  String get roomColorsScreenResetAll => 'REVENIR À AUTOMATIQUE';

  @override
  String get roomColorsScreenLimitToast =>
      'C\'est le maximum qu\'un salon peut fixer.';

  @override
  String get roomColorsScreenFailedToast =>
      'Impossible d\'enregistrer cette couleur.';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return 'Couleur $index';
  }

  @override
  String get devicesScreenTitle => 'TES APPAREILS';

  @override
  String get devicesScreenSubtitle =>
      'Tous les endroits où tu t\'es connecté à ce compte.';

  @override
  String get devicesScreenLoading => 'vérification…';

  @override
  String get devicesScreenLoadFailed => 'impossible de charger tes appareils';

  @override
  String get devicesScreenThisDevice => 'CET APPAREIL';

  @override
  String get devicesScreenActiveNow => 'actif maintenant';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count minutes',
      one: 'il y a 1 minute',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count heures',
      one: 'il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications =>
      'les notifications n\'arrivent pas jusqu\'à celui-ci';

  @override
  String get devicesScreenRemove => 'RETIRER';

  @override
  String get devicesScreenRemoveTitle => 'RETIRER CET APPAREIL ?';

  @override
  String devicesScreenRemoveBody(Object name) {
    return '$name sera déconnecté et cessera de recevoir des notifications. Celui qui l\'a devra se reconnecter.';
  }

  @override
  String get devicesScreenRemoveConfirm => 'RETIRER';

  @override
  String get devicesScreenRemoveAll => 'Retirer tous les autres appareils';

  @override
  String get devicesScreenRemoveAllTitle =>
      'RETIRER TOUS LES AUTRES APPAREILS ?';

  @override
  String get devicesScreenRemoveAllBody =>
      'Ils seront tous déconnectés et cesseront de recevoir des notifications. Seul cet appareil reste connecté.';

  @override
  String get devicesScreenRemoveAllConfirm => 'TOUT RETIRER';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appareils retirés',
      one: '1 appareil retiré',
      zero: 'aucun autre appareil à retirer',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed => 'impossible de retirer cet appareil';

  @override
  String get devicesScreenFootnote =>
      'Retirer un appareil le déconnecte et coupe ses notifications. L\'effet est immédiat : la prochaine chose que cet appareil tentera le renverra à l\'écran de connexion.';

  @override
  String get attachmentMenuPollLabel => 'sondage';

  @override
  String get attachmentMenuChecklistLabel => 'liste';

  @override
  String get attachmentMenuEventLabel => 'événement';

  @override
  String get interactionKindPoll => 'SONDAGE';

  @override
  String get interactionKindQuiz => 'QUIZ';

  @override
  String get interactionKindChecklist => 'LISTE';

  @override
  String get interactionKindEvent => 'ÉVÉNEMENT';

  @override
  String get interactionBadgeAnonymous => 'ANONYME';

  @override
  String get interactionBadgeMultiple => 'MULTIPLE';

  @override
  String get interactionBadgeClosed => 'CLOS';

  @override
  String interactionPercent(int percent) {
    return '$percent %';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names +$count';
  }

  @override
  String get interactionSeeWhoAnswered => 'Voir qui a répondu';

  @override
  String interactionRemoveItem(String label) {
    return 'Retirer $label';
  }

  @override
  String interactionChoiceSemantics(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voix',
      one: '1 voix',
    );
    return '$label, $_temp0';
  }

  @override
  String get interactionAddItemHint => 'Ajouter une ligne';

  @override
  String get interactionRetract => 'Retirer';

  @override
  String get interactionClose => 'Clore';

  @override
  String interactionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voix',
      one: '1 voix',
    );
    return '$_temp0';
  }

  @override
  String interactionRsvpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réponses',
      one: '1 réponse',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$done sur $total faits';
  }

  @override
  String get interactionNoAnswers => 'Aucune réponse';

  @override
  String get interactionBeFirst => 'Sois le premier à répondre';

  @override
  String interactionFinalResults(String count) {
    return '$count · définitif';
  }

  @override
  String get interactionQuizRight => 'Correct';

  @override
  String get interactionQuizWrong => 'Presque';

  @override
  String interactionEventPast(String when) {
    return '$when · déjà passé';
  }

  @override
  String get interactionRespondentsTitlePoll => 'QUI A VOTÉ';

  @override
  String get interactionRespondentsTitleChecklist => 'QUI A COCHÉ';

  @override
  String get interactionRespondentsTitleEvent => 'QUI A RÉPONDU';

  @override
  String get interactionRespondentsFailed =>
      'Impossible de charger qui a répondu.';

  @override
  String get interactionRespondentsEmpty => 'Personne n\'a encore répondu.';

  @override
  String get interactionFilterAll => 'TOUS';

  @override
  String get interactionRsvpGoing => 'Je viens';

  @override
  String get interactionRsvpMaybe => 'Peut-être';

  @override
  String get interactionRsvpNo => 'Je ne peux pas';

  @override
  String get interactionComposePollTitle => 'nouveau sondage';

  @override
  String get interactionComposePollTagline => 'DEMANDE AU SALON';

  @override
  String get interactionComposeChecklistTitle => 'nouvelle liste';

  @override
  String get interactionComposeChecklistTagline => 'UNE LISTE QUE TOUS COCHENT';

  @override
  String get interactionComposeEventTitle => 'nouvel événement';

  @override
  String get interactionComposeEventTagline => 'VOIS QUI VIENT';

  @override
  String get interactionComposeQuestionLabel => 'QUESTION';

  @override
  String get interactionComposeQuestionHint => 'que veux-tu demander ?';

  @override
  String get interactionComposeTitleLabel => 'TITRE';

  @override
  String get interactionComposeTitleHint => 'à quoi sert cette liste ?';

  @override
  String get interactionComposeEventNameLabel => 'ÉVÉNEMENT';

  @override
  String get interactionComposeEventNameHint => 'il se passe quoi ?';

  @override
  String get interactionComposeOptionsLabel => 'OPTIONS';

  @override
  String get interactionComposeItemsLabel => 'LIGNES';

  @override
  String interactionComposeOptionHint(int index) {
    return 'option $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return 'ligne $index';
  }

  @override
  String get interactionComposeAddOption => 'Ajouter une option';

  @override
  String get interactionComposeAddItem => 'Ajouter une ligne';

  @override
  String get interactionComposeRemoveRow => 'Retirer';

  @override
  String get interactionComposeMarkCorrect => 'Marquer comme bonne réponse';

  @override
  String get interactionComposeMultipleTitle => 'réponses multiples';

  @override
  String get interactionComposeMultipleSub => 'en choisir plusieurs';

  @override
  String get interactionComposeAnonymousTitle => 'anonyme';

  @override
  String get interactionComposeAnonymousOffSub =>
      'tout le monde voit qui a voté';

  @override
  String get interactionComposeAnonymousOnSub => 'personne ne voit qui a voté';

  @override
  String get interactionComposeQuizTitle => 'mode quiz';

  @override
  String get interactionComposeQuizSub =>
      'une seule bonne réponse, sans retour';

  @override
  String get interactionComposeExplanationLabel => 'EXPLICATION';

  @override
  String get interactionComposeExplanationHint =>
      'affichée après la réponse (facultatif)';

  @override
  String get interactionComposeOthersMayCheckTitle =>
      'tout le monde peut cocher';

  @override
  String get interactionComposeOthersMayCheckSub => 'pas seulement toi';

  @override
  String get interactionComposeOthersMayAddTitle =>
      'tout le monde peut ajouter';

  @override
  String get interactionComposeOthersMayAddSub =>
      'la liste peut grandir ensuite';

  @override
  String get interactionComposeWhenLabel => 'QUAND';

  @override
  String get interactionComposePickStart => 'Choisis le début';

  @override
  String get interactionComposePickEnd => 'Ajouter une fin (facultatif)';

  @override
  String get interactionComposePlaceLabel => 'LIEU';

  @override
  String get interactionComposePlaceHint => 'où ? (facultatif)';

  @override
  String get interactionComposeSendPoll => 'ENVOYER LE SONDAGE';

  @override
  String get interactionComposeSendChecklist => 'ENVOYER LA LISTE';

  @override
  String get interactionComposeSendEvent => 'ENVOYER L\'ÉVÉNEMENT';

  @override
  String get interactionComposeErrorPrompt =>
      'Dis d\'abord ce que tu demandes.';

  @override
  String interactionComposeErrorOptions(int count) {
    return 'Un sondage a besoin d\'au moins $count options.';
  }

  @override
  String get interactionComposeErrorItems =>
      'Une liste a besoin d\'au moins une ligne.';

  @override
  String get interactionComposeErrorAnswer =>
      'Indique quelle option est la bonne.';

  @override
  String get interactionComposeErrorWhen => 'Choisis quand ça commence.';

  @override
  String get interactionComposeErrorEnd => 'La fin doit venir après le début.';

  @override
  String get interactionSendFailed => 'Ça n\'est pas parti.';

  @override
  String get interactionRefused => 'Ça n\'a pas été pris en compte.';

  @override
  String get messageReceiptsScreenTitle => 'INFOS DU MESSAGE';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$read sur $total l’ont lu';
  }

  @override
  String get messageReceiptsEmptyState =>
      'il n’y a encore personne d’autre dans ce salon';

  @override
  String get messageReceiptsSectionRead => 'LU';

  @override
  String get messageReceiptsSectionDelivered => 'REMIS';

  @override
  String get messageReceiptsSectionSent => 'ENVOYÉ';

  @override
  String get messageReceiptsSectionHidden => 'AUCUN ACCUSÉ';

  @override
  String get messageReceiptsStateHidden => 'non partagé';

  @override
  String get messageReceiptsStateWaiting => 'en attente';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name l’a lu $day à $time';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name l’a reçu $day à $time';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name ne l’a pas encore reçu';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name ne partage pas les accusés de lecture';
  }

  @override
  String get companionsScreenTitle => 'compagnons.';

  @override
  String get companionsScreenSubtitle =>
      'des aides qui vivent sur ce téléphone et n\'envoient rien nulle part';

  @override
  String get companionSebastianTagline => 'Traduit les messages';

  @override
  String get companionSebastianBlurb =>
      'Sebastian lit un message écrit dans une autre langue et te dit ce qu\'il raconte — ici, sur ton téléphone, sans que rien ne soit envoyé nulle part.';

  @override
  String get companionMarloweTagline => 'Aide générale';

  @override
  String get companionMarloweBlurb =>
      'Marlowe s\'occupe de tout ce qui n\'est pas de la traduction. Choisis un cerveau dès maintenant ; les compétences arriveront ensuite.';

  @override
  String get companionAssuranceOnDevice =>
      'Fonctionne entièrement sur cet appareil';

  @override
  String get companionAssurancePrivate =>
      'Tes messages ne quittent jamais ton téléphone';

  @override
  String get companionAssuranceOffline => 'Fonctionne sans connexion';

  @override
  String companionInstallAction(Object size) {
    return 'Installer · $size';
  }

  @override
  String get companionInstallOneTime =>
      'téléchargement unique, conservé jusqu\'à ce que tu le supprimes';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$received sur $total';
  }

  @override
  String get companionInstallQueued =>
      'En attente de la fin d\'un autre téléchargement';

  @override
  String get companionInstallCancel => 'Annuler';

  @override
  String get companionInstallRetry => 'Réessayer';

  @override
  String companionInstallReady(Object name) {
    return '$name est prêt';
  }

  @override
  String get companionInstallFailedNetwork =>
      'Le téléchargement n\'a pas pu aboutir. Vérifie ta connexion et réessaie.';

  @override
  String get companionInstallFailedStorage =>
      'Il n\'y a pas assez d\'espace sur cet appareil. Libère de la place et réessaie.';

  @override
  String get companionInstallFailedUnknown =>
      'Le téléchargement n\'a pas pu aboutir.';

  @override
  String get companionUnsupportedPlatform =>
      'Les compagnons ne sont pas encore disponibles dans cette version de l\'app.';

  @override
  String companionBrainNeedsMemory(String size) {
    return 'Nécessite $size de mémoire';
  }

  @override
  String get sebastianTierSeniorDetail => 'Traductions plus fines';

  @override
  String get sebastianTierJuniorDetail => 'Fonctionne sur tout téléphone';

  @override
  String get sebastianLanguageUnlisted =>
      'Pas une de ses langues — résultats approximatifs';

  @override
  String get companionStatusNotInstalled => 'Non installé';

  @override
  String get companionStatusOff => 'Désactivé';

  @override
  String companionStatusTranslatingInto(Object language) {
    return 'Traduit vers $language';
  }

  @override
  String get companionStatusNoBrain => 'Rien de téléchargé pour le moment';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count téléchargements prêts',
      one: '1 téléchargement prêt',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty =>
      'Rien de téléchargé — les compagnons n\'occupent aucun espace';

  @override
  String companionStorageUsed(Object size) {
    return 'Les compagnons occupent $size';
  }

  @override
  String get companionSectionGeneral => 'GÉNÉRAL';

  @override
  String get companionSectionStorage => 'STOCKAGE';

  @override
  String get companionBrainRemove => 'Supprimer';

  @override
  String companionBrainRemoveTitle(Object name) {
    return 'SUPPRIMER $name ?';
  }

  @override
  String companionRemoveTitle(Object name) {
    return 'SUPPRIMER $name ?';
  }

  @override
  String companionRemoveMessage(Object size) {
    return 'Cela libère $size. Tu peux le retélécharger à tout moment.';
  }

  @override
  String get companionRemoveConfirm => 'SUPPRIMER';

  @override
  String get sebastianEnableLabel => 'Laisser Sebastian traduire';

  @override
  String get sebastianEnableDetail =>
      'Désactive pour l\'arrêter sans supprimer le téléchargement';

  @override
  String get sebastianLanguageSection => 'TRADUIRE VERS';

  @override
  String get sebastianLanguageFollowApp => 'Comme l\'app';

  @override
  String sebastianBrainDetail(Object size) {
    return 'Sur cet appareil · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count traductions conservées',
      one: '1 traduction conservée',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => 'Effacer';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe ne sait encore rien faire — les compétences arrivent. Ce que tu peux faire dès maintenant, c\'est préparer un cerveau, pour que rien n\'attende un téléchargement le jour où elles arrivent.';

  @override
  String get marloweBrainsSection => 'CERVEAU';

  @override
  String get marloweBrainsCaption =>
      'Plus il est grand, mieux il réfléchit et plus il met de temps à répondre. Tu peux en garder plusieurs et passer de l’un à l’autre.';

  @override
  String get marloweBrainTierSwift => 'Rapide';

  @override
  String get marloweBrainTierBalanced => 'Équilibré';

  @override
  String get marloweBrainTierDeep => 'Approfondi';

  @override
  String get translationSlabShowOriginal => 'Voir l\'original';

  @override
  String get translationSlabFailed => 'Ce message n\'a pas pu être traduit.';

  @override
  String get translationSlabRetry => 'Réessayer';

  @override
  String translationSlabByCompanion(Object name) {
    return 'Traduit par $name';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return 'Depuis $language';
  }

  @override
  String get messageActionMenuTranslateLabel => 'TRADUIRE';

  @override
  String get messageActionMenuShowOriginalLabel => 'VOIR L\'ORIGINAL';

  @override
  String get roomTranslateTitle => 'Traduire cette conversation';

  @override
  String get roomTranslateStopTitle => 'Arrêter la traduction';

  @override
  String get roomTranslateSectionLabel => 'TRADUCTION';

  @override
  String get roomTranslateOnRow => 'Conversation traduite';

  @override
  String get roomTranslateOffRow => 'Désactivé';

  @override
  String get roomTranslateNeedsSetUp => 'Configurer Sebastian';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'Sebastian traduit · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return 'Lecture en $language';
  }

  @override
  String get roomTranslateStop => 'ARRÊTER';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return 'déjà en $language';
  }

  @override
  String get roomScreenTranslateRoomOffer =>
      'traduire aussi le reste de la conversation ?';

  @override
  String get roomScreenTranslateRoomOfferAction => 'TOUT TRADUIRE';

  @override
  String get settingsScreenCompanionsOff => 'Désactivé';

  @override
  String get settingsScreenCompanionsUnavailable => 'Indisponible';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return 'Également utilisé par $name';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return '$name utilise le même téléchargement et le perdra aussi.';
  }

  @override
  String get companionBrainInUse => 'ACTIF';

  @override
  String companionStatusUsingBrain(Object name) {
    return 'Utilise $name';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return 'Le téléchargement de $name continue — Réglages › Compagnons';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return 'Téléchargement · $percent %';
  }

  @override
  String get companionInstallPause => 'Suspendre';

  @override
  String get companionInstallResume => 'Reprendre';

  @override
  String get companionInstallDiscard => 'Abandonner';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return 'Suspendu · $received sur $total';
  }

  @override
  String get companionInstallFailedIntegrity =>
      'Le fichier téléchargé ne correspond pas à ce que cette version attend. Reprise depuis le début.';

  @override
  String companionBannerDownloading(
    Object name,
    Object received,
    Object total,
  ) {
    return '$name · $received sur $total';
  }

  @override
  String companionBannerPaused(Object name, Object received, Object total) {
    return '$name suspendu · $received sur $total';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name se réveille…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => 'RETRADUIRE';

  @override
  String get groupCallScreenShareLabel => 'partager';

  @override
  String get groupCallScreenStopShareLabel => 'arrêter';

  @override
  String get groupCallScreenShareStartingLabel => 'démarrage…';

  @override
  String get groupCallScreenRingingLabel => 'Sonnerie…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name partage son écran';
  }

  @override
  String get groupCallScreenYouAreSharing => 'Vous partagez votre écran';

  @override
  String get groupCallScreenMinimizeLabel => 'masquer';

  @override
  String get groupCallScreenDrawLabel => 'dessiner';

  @override
  String get callScreenControlShare => 'Partager';

  @override
  String get callScreenControlStopShare => 'Arrêter';

  @override
  String get callScreenControlShareStarting => 'Démarrage…';

  @override
  String get screenShareStopDrawing => 'Arrêter de dessiner';

  @override
  String get callScreenControlDraw => 'Dessiner';

  @override
  String get callScreenControlMinimize => 'Masquer';

  @override
  String get inCallPillOngoingCall => 'Appel en cours';

  @override
  String get inCallPillReturn => 'Revenir';

  @override
  String get inCallPillSharing => 'Partage de votre écran';

  @override
  String get inCallPillDrawSemanticLabel => 'Dessiner sur l\'écran partagé';

  @override
  String get inCallPillStopSharingSemanticLabel => 'Arrêter le partage';

  @override
  String get screenShareUnsupported =>
      'Le partage d\'écran n\'est pas disponible sur cet appareil';

  @override
  String get screenShareEphemeralWarning =>
      'La protection contre les captures est désactivée pendant le partage';

  @override
  String get screenShareNotificationTitle => 'Partage de votre écran';

  @override
  String get screenShareNotificationBody =>
      'Tout le monde dans l\'appel peut le voir';

  @override
  String get screenShareNotificationStop => 'Arrêter';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name partage déjà';
  }

  @override
  String get screenShareFailed => 'Impossible de démarrer le partage';

  @override
  String get screenSharePickerTitle => 'Partagez votre écran';

  @override
  String get screenSharePickerScreens => 'Écrans';

  @override
  String get screenSharePickerWindows => 'Fenêtres';

  @override
  String get screenSharePickerEmpty =>
      'Rien à partager pour l\'instant — autorisez l\'enregistrement de l\'écran dans Réglages Système et réessayez';

  @override
  String get gameTellFriends => 'PRÉVENIR TES AMIS';

  @override
  String get gameToldFriends => 'amis prévenus';

  @override
  String get gameTellFriendsTitle => 'prévenir tes amis ?';

  @override
  String get gameTellFriendsBody =>
      'ils reçoivent une notification avec ce résultat. envoi unique.';

  @override
  String get gameTellFriendsCancel => 'PAS MAINTENANT';

  @override
  String get gameTellFriendsConfirm => 'ENVOYER';

  @override
  String get gameTellFriendsSent => 'envoyé — ils sont au courant';

  @override
  String get gameTellFriendsPrivate =>
      'tes scores du jour sont privés, personne ne le verrait';

  @override
  String get gameTellFriendsFailed => 'envoi impossible';

  @override
  String get settingsScreenFriendActivityLabel => 'ACTIVITÉ DES AMIS';

  @override
  String get settingsScreenFriendActivityOnBody =>
      'moments, points et résultats au fil de leurs publications';

  @override
  String get settingsScreenFriendActivityOffBody =>
      'rien — leurs tableaux sont toujours là quand tu regardes';

  @override
  String get searchScreenActionWithGrownUp => 'CHEZ UN GRAND';

  @override
  String get newChatMenuSearchHint => 'cherche dans tes amis';

  @override
  String get newChatMenuNoFriendsYet =>
      'pas encore d’amis —\\ntrouve du monde dans Découvrir';

  @override
  String get newChatMenuNoFriendsMatch => 'aucun ami ne correspond';

  @override
  String get newChatMenuOpenDmFailed =>
      'impossible d’ouvrir ce chat — réessaie';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'CHOISIR PARMI TES CONTACTS';

  @override
  String get childPolicyScreenPickPersonHint => 'cherche un nom ou un pseudo';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'plus personne à ajouter parmi tes amis —\\ncherche quelqu’un d’autre';

  @override
  String get childPolicyScreenPickPersonNoMatch => 'personne ne correspond';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'TES AMIS';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'TOUS LES AUTRES';

  @override
  String get childPolicyScreenAddRoomLabel => 'AJOUTER UN SALON';

  @override
  String get childPolicyScreenPickRoomHeading => 'AJOUTER UN SALON';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'Un de tes propres salons. $name y entre tout de suite et peut y lire et écrire jusqu’à ce que tu le retires.';
  }

  @override
  String get childPolicyScreenPickRoomHint => 'cherche dans tes salons';

  @override
  String get childPolicyScreenPickRoomEmpty =>
      'plus aucun de tes salons à ajouter';

  @override
  String get childPolicyScreenPickRoomNoMatch => 'aucun salon ne correspond';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name est maintenant dans $room';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'impossible d’ajouter ce salon — réessaie';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'ce salon ne peut pas être ajouté ainsi';

  @override
  String get childPolicyScreenErrorRoomGone => 'ce salon n’existe plus';

  @override
  String get newChatMenuFriendsHeader => 'AMIS';

  @override
  String get roomChangeErrorGone =>
      'Cette suggestion a disparu — un admin y a peut-être répondu.';

  @override
  String get roomChangeErrorNotYours =>
      'Seule la personne qui l\'a proposée peut la retirer.';

  @override
  String get roomChangeErrorNoChange => 'C\'est déjà ce qui est écrit.';

  @override
  String get roomChangeErrorMissingValue =>
      'Impossible d\'enregistrer ça tel quel.';

  @override
  String get roomChangeRequestsTitle => 'Suggestions';

  @override
  String get roomChangeRequestsBlurb =>
      'Ce sont des membres qui les proposent. Rien ne change tant que tu n\'as pas dit oui.';

  @override
  String get roomChangeRequestsEmpty => 'Aucune suggestion.';

  @override
  String get roomChangeRequestsApprove => 'PRENDRE';

  @override
  String get roomChangeRequestsReject => 'NON';

  @override
  String get roomChangeRequestsPhotoLabel => 'Nouvelle photo du groupe';

  @override
  String get roomChangeRequestsNameLabel => 'Nouveau nom';

  @override
  String get roomChangeRequestsDescriptionLabel => 'Nouvelle description';

  @override
  String get roomChangeRequestsUnknownLabel =>
      'Un changement que cette app ne sait pas encore afficher';

  @override
  String get roomChangeRequestsClearedValue => 'rien — l\'enlever';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name a proposé';
  }

  @override
  String get roomAdminChangeRequestsRow => 'Suggestions';

  @override
  String get roomInfoScreenSuggestNote => 'un admin doit valider ça';

  @override
  String get roomInfoScreenSuggestAvatarNote =>
      'un admin valide les nouvelles photos';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic =>
      'Proposer une photo de groupe';

  @override
  String get roomInfoScreenSuggestionSentToast => 'Envoyé aux admins';

  @override
  String get roomInfoScreenSuggestionAppliedToast =>
      'C\'est fait — tu peux modifier ce groupe';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => 'Retiré';

  @override
  String get roomInfoScreenSuggestionsLabel => 'TES SUGGESTIONS';

  @override
  String get roomInfoScreenSuggestionPhoto => 'Une nouvelle photo de groupe';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return 'Nom : $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return 'Description : $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => 'Un changement';

  @override
  String get roomInfoScreenSuggestionPending => 'en attente d\'un admin';

  @override
  String get roomInfoScreenSuggestionWithdraw => 'RETIRER';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name a proposé une nouvelle photo de groupe';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name a proposé un nouveau nom';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name a proposé une nouvelle description';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suggestions t\'attendent',
      one: '$count suggestion t\'attend',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => 'VOIR';

  @override
  String get roomSuggestionBannerSemantic =>
      'Suggestions de membres en attente de ton avis';

  @override
  String get gameInfoPlay => 'JOUER';

  @override
  String get gameInfoContinue => 'CONTINUER';

  @override
  String get gameInfoSeeResult => 'VOIR TON RÉSULTAT';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return 'remis à $delivered sur $total';
  }

  @override
  String get messageReceiptsSentLabel => 'ENVOYÉ';

  @override
  String messageReceiptsSemanticDeliveredThenRead(
    Object deliveredDay,
    Object deliveredTime,
    Object name,
    Object readDay,
    Object readTime,
  ) {
    return '$name l’a reçu $deliveredDay à $deliveredTime et l’a lu $readDay à $readTime';
  }

  @override
  String get messageReceiptsStampRead => 'lu';

  @override
  String get messageReceiptsStampDelivered => 'remis';

  @override
  String get roomInviteCustom => 'Autre';

  @override
  String roomInviteCustomHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '$count heure',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '$count jour',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utilisations',
      one: '$count utilisation',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => 'Heures';

  @override
  String get roomInviteUnitDays => 'Jours';

  @override
  String get roomInviteStepperIncrease => 'Augmenter';

  @override
  String get roomInviteStepperDecrease => 'Diminuer';

  @override
  String get recordsLabel => 'RECORDS';

  @override
  String get recordsBlurb => 'le meilleur jamais réalisé — toi et tes amis';

  @override
  String recordsYourBest(Object value) {
    return 'le tien $value';
  }

  @override
  String get recordsNoneYet => 'personne encore';

  @override
  String get recordsEmpty =>
      'Résous un jeu et ton meilleur score arrivera ici.';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réussites',
      one: '$count réussite',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return 'établi le $date';
  }

  @override
  String recordsReactSemantic(Object name) {
    return 'Réagir au record de $name';
  }

  @override
  String get recordsReactFailed => 'impossible de réagir';

  @override
  String get recordsLoadFailed => 'impossible de charger les records';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game : record de $value par $name';
  }

  @override
  String get appearanceLabel => 'APPARENCE';

  @override
  String get appearanceMatchDevice => 'Comme l’appareil';

  @override
  String get appearanceMatchDeviceSub =>
      'clair le jour, sombre la nuit — comme ton téléphone';

  @override
  String get appearanceOneTheme => 'Un seul thème';

  @override
  String get appearanceOneThemeSub => 'le même look toute la journée';

  @override
  String get appearanceLightSlot => 'MODE CLAIR';

  @override
  String get appearanceDarkSlot => 'MODE SOMBRE';

  @override
  String get appearanceNow => 'ACTUEL';

  @override
  String appearanceAutoValue(Object name) {
    return 'auto · $name';
  }

  @override
  String get themeScreenAssignHint =>
      'touche un thème pour l’utiliser en mode clair ou sombre · ⛶ pour l’aperçu complet';

  @override
  String get themeScreenCarouselUseLight => 'UTILISER EN MODE CLAIR';

  @override
  String get themeScreenCarouselUseDark => 'UTILISER EN MODE SOMBRE';

  @override
  String get themeScreenCarouselIsLight => 'TON THÈME CLAIR';

  @override
  String get themeScreenCarouselIsDark => 'TON THÈME SOMBRE';

  @override
  String get onboardingThemeTitle => 'à ton image.';

  @override
  String get onboardingThemeBody =>
      'choisis un style. tu pourras le changer à tout moment dans les réglages.';

  @override
  String get onboardingThemeYourTheme => 'TON THÈME';

  @override
  String get onboardingThemeContinue => 'CONTINUER';

  @override
  String get dropHintNoTarget => 'déposez sur une conversation pour envoyer';

  @override
  String get dropNothingToSend => 'rien ici ne peut être envoyé';

  @override
  String dropSendPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'envoyer $count photos',
      one: 'envoyer la photo',
    );
    return '$_temp0';
  }

  @override
  String dropSendVideos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'envoyer $count vidéos',
      one: 'envoyer la vidéo',
    );
    return '$_temp0';
  }

  @override
  String dropSendAudio(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'envoyer $count fichiers audio',
      one: 'envoyer l’audio',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'envoyer $count fichiers',
      one: 'envoyer le fichier',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'envoyer $count éléments',
      one: 'envoyer l’élément',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => 'ajouter au message';

  @override
  String get dropSendLink => 'ajouter le lien';

  @override
  String dropTargetTo(String name) {
    return 'vers $name';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers dépassent $size',
      one: '1 fichier dépasse $size',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => 'les dossiers ne peuvent pas être envoyés';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers vides sont ignorés',
      one: 'un fichier vide est ignoré',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed =>
      'les pièces jointes ne sont pas autorisées ici';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seront envoyés comme fichiers',
      one: 'sera envoyé comme fichier',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ne s’afficheront pas partout',
      one: 'ne s’affichera pas partout',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => 'photo';

  @override
  String get dropKindVideo => 'vidéo';

  @override
  String get dropKindAudio => 'audio';

  @override
  String get dropKindFile => 'fichier';

  @override
  String get dropKindFolder => 'dossier';

  @override
  String get dropKindText => 'texte';

  @override
  String get dropKindLink => 'lien';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fichiers n’entrent pas dans cet envoi',
      one: '1 fichier n’entre pas dans cet envoi',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed => 'Impossible de faire ça. Réessaie.';

  @override
  String get expressionBackspace => 'Effacer';

  @override
  String get expressionCreateSticker => 'Créer un sticker';

  @override
  String get expressionDeleteSticker => 'Supprimer de mes stickers';

  @override
  String get expressionFavorite => 'Ajouter aux favoris';

  @override
  String get expressionFavorited => 'Ajouté aux favoris';

  @override
  String get expressionFavorites => 'Favoris';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF : $title';
  }

  @override
  String get expressionLoadFailed =>
      'Chargement impossible. Vérifie ta connexion.';

  @override
  String get expressionMediaNotAllowed =>
      'Tes réglages familiaux ne permettent pas d’envoyer des images.';

  @override
  String get expressionMyStickers => 'Mes stickers';

  @override
  String get expressionNoFavorites =>
      'Appuie longuement sur un GIF ou un sticker pour l’ajouter aux favoris.';

  @override
  String get expressionNoRecents =>
      'Les GIF et stickers que tu envoies apparaîtront ici.';

  @override
  String get expressionNoResults => 'Aucun résultat';

  @override
  String get expressionNoStickers => 'Pas encore de stickers ici.';

  @override
  String get expressionOpenPanel => 'Emoji, GIF et stickers';

  @override
  String get expressionOptionsHint => 'afficher les options';

  @override
  String expressionPackCredit(String author, String license) {
    return 'Illustrations : $author · $license';
  }

  @override
  String get expressionPlayGifHint => 'lire';

  @override
  String get expressionRecent => 'Récents';

  @override
  String get expressionReport => 'Signaler';

  @override
  String get expressionReported => 'Merci, c’est signalé.';

  @override
  String get expressionRetry => 'Réessayer';

  @override
  String get expressionSearchKlipy => 'Rechercher sur KLIPY';

  @override
  String get expressionShowKeyboard => 'Afficher le clavier';

  @override
  String get expressionSuggestionsLabel => 'Suggestions de stickers';

  @override
  String get expressionTabEmoji => 'Emoji';

  @override
  String get expressionTabGifs => 'GIF';

  @override
  String get expressionTabStickers => 'Stickers';

  @override
  String get expressionTrending => 'Tendances';

  @override
  String get expressionUnfavorite => 'Retirer des favoris';

  @override
  String get expressionUnfavorited => 'Retiré des favoris';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return 'Sticker $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel =>
      'Lecture auto des GIF et stickers';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      'Ils restent immobiles jusqu’à ce que tu en touches un. Économise des données.';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'Les GIF et stickers animés se lancent tout seuls. Réduire les animations les met en pause.';

  @override
  String get settingsStickerSuggestionsBody =>
      'Taper un seul emoji affiche des stickers assortis au-dessus du champ de message.';

  @override
  String get settingsStickerSuggestionsLabel => 'Suggestions de stickers';

  @override
  String get stickerMakerEmojiLabel => 'C’est quel emoji ?';

  @override
  String get stickerMakerFailed =>
      'Impossible d’enregistrer le sticker. Réessaie.';

  @override
  String get stickerMakerMoreEmoji => 'Plus d’emoji';

  @override
  String get stickerMakerPreview => 'Aperçu du sticker';

  @override
  String get stickerMakerRemoveBackground => 'Supprimer l’arrière-plan';

  @override
  String get stickerMakerSave => 'Enregistrer';

  @override
  String get stickerMakerSaved => 'Sticker ajouté à Mes stickers';

  @override
  String get stickerMakerShape => 'Forme';

  @override
  String get stickerMakerShapeCircle => 'Cercle';

  @override
  String get stickerMakerShapeOriginal => 'Originale';

  @override
  String get stickerMakerShapeRounded => 'Carré arrondi';

  @override
  String get stickerMakerTitle => 'Nouveau sticker';

  @override
  String get stickerMakerTooMany =>
      'Tu as atteint la limite de stickers. Supprimes-en un pour faire de la place.';

  @override
  String get expressionExpandPanel => 'Agrandir le panneau';

  @override
  String get expressionCollapsePanel => 'Réduire le panneau';

  @override
  String get expressionPackStore => 'Packs de stickers';

  @override
  String get expressionPackSearchHint => 'Rechercher des packs';

  @override
  String get expressionPacksAdded => 'Ajoutés';

  @override
  String get expressionPacksMore => 'Plus de packs';

  @override
  String get expressionPackAdd => 'Ajouter';

  @override
  String get expressionPackRemove => 'Retirer';

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
  String get expressionNoPacksFound => 'Aucun pack trouvé';

  @override
  String get expressionAllPacksAdded => 'Tu as ajouté tous les packs.';

  @override
  String expressionPackReorder(String title) {
    return 'Réorganiser $title';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return 'Ajouter le pack « $title »';
  }

  @override
  String expressionPackAddedToast(String title) {
    return '« $title » ajouté à tes stickers';
  }

  @override
  String get expressionPacksFromKlipy => 'Plus de stickers sur KLIPY';

  @override
  String expressionSearchKlipyFor(String query) {
    return 'Chercher « $query » sur KLIPY';
  }

  @override
  String get expressionHideKeyboard => 'Masquer le clavier';

  @override
  String get expressionSearchStickers => 'Rechercher des stickers';

  @override
  String get expressionYourStickers => 'Vos stickers';

  @override
  String get chatListYesterday => 'Hier';

  @override
  String get roomLayoutScreenCardsLayoutLabel => 'CARTES';

  @override
  String get roomLayoutScreenCardsLayoutDescription =>
      'chaque salon dans sa propre carte, chaque détail affiché.';

  @override
  String get homeScreenTitle => 'Discussions';

  @override
  String get glassScreenNativeLabel => 'Liquid Glass d’iOS';

  @override
  String get glassScreenNativeOnBody =>
      'iOS dessine lui-même la barre d’onglets. Les curseurs ci-dessous règlent le reste de l’app.';

  @override
  String get glassScreenNativeOffBody =>
      'MonkeyHub dessine son propre verre partout, réglé par les curseurs ci-dessous.';

  @override
  String get glassScreenHeading => 'Verre';

  @override
  String get glassStyleHeader => 'Style';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody =>
      'Le verre d’Apple, dessiné par iOS. Les boutons de l’app s’y accordent.';

  @override
  String get glassStyleFrostedTitle => 'Givré';

  @override
  String get glassStyleFrostedBody =>
      'Le verre de MonkeyHub. Réglez chaque curseur vous-même.';

  @override
  String get glassStyleRecommended => 'Recommandé';

  @override
  String get glassStyleLiquidFooter =>
      'Rien à régler : iOS gère le flou, la teinte et la lumière. Choisissez Givré pour façonner le verre vous-même.';

  @override
  String get acctSectionPrivacy => 'Confidentialité';

  @override
  String get acctSectionAccount => 'Compte';

  @override
  String get acctSectionFamily => 'Famille';

  @override
  String get acctSectionThisPhone => 'Ce téléphone';

  @override
  String get acctRowVisibility => 'Visibilité du profil';

  @override
  String get acctRowBlocked => 'Utilisateurs bloqués';

  @override
  String get acctRowApprovals => 'Approbations';

  @override
  String get acctNothingWaiting => 'Rien en attente';

  @override
  String get acctRowLinked => 'Comptes associés';

  @override
  String get acctRowScanToSignIn => 'Scanner pour se connecter';

  @override
  String get acctRowSetUpRecovery => 'Configurer la phrase de récupération';

  @override
  String get acctRowChangeRecovery => 'Changer la phrase de récupération';

  @override
  String get acctSignOut => 'Se déconnecter';

  @override
  String get acctDeleteAccount => 'Supprimer le compte';

  @override
  String get acctConfirmDelete => 'Touchez à nouveau pour supprimer';

  @override
  String get acctHandPhoneBack => 'Rendre ce téléphone';

  @override
  String get acctMyGrownUps => 'Mes adultes';

  @override
  String get acctActionMessage => 'Message';

  @override
  String get acctActionAddFriend => 'Ajouter';

  @override
  String get acctActionRequested => 'Demandé';

  @override
  String get acctActionAccept => 'Accepter';

  @override
  String get acctActionNotAccepting => 'Fermé';

  @override
  String get acctActionUnfriend => 'Retirer';

  @override
  String get acctActionBlock => 'Bloquer';

  @override
  String get acctActionReport => 'Signaler';

  @override
  String get acctStatusFriends => 'Vous êtes amis';

  @override
  String get acctStatusRequestSent => 'Demande envoyée';

  @override
  String get acctStatusWantsToConnect => 'Veut être ami avec vous';

  @override
  String get acctStatusNotConnected => 'Pas en contact';

  @override
  String get acctPresenceOnline => 'en ligne';

  @override
  String get acctPresenceAway => 'absent';

  @override
  String get acctPresenceOffline => 'hors ligne';

  @override
  String get acctProfilePhoto => 'Photo de profil';

  @override
  String get acctSaveToPhotos => 'Enregistrer dans Photos';

  @override
  String get acctTakeSelfie => 'Prendre un selfie';

  @override
  String get acctChooseFromLibrary => 'Choisir dans la photothèque';

  @override
  String get acctCancel => 'Annuler';

  @override
  String get acctSave => 'Enregistrer';

  @override
  String get acctChange => 'Modifier';

  @override
  String get acctNotNow => 'Pas maintenant';

  @override
  String get acctAddEmail => 'Ajouter un e-mail';

  @override
  String get acctEditNameTitle => 'Modifier le nom';

  @override
  String get acctAddNameTitle => 'Ajoutez votre nom';

  @override
  String get acctEditEmailTitle => 'Modifier l’e-mail';

  @override
  String get acctChangeUsernameTitle => 'Changer de nom d’utilisateur ?';

  @override
  String get onboardingLookTitle => 'À votre image';

  @override
  String get onboardingLookBody =>
      'Choisissez un style. Vous pourrez le changer à tout moment dans Réglages.';

  @override
  String get onboardingEssentials => 'Essentiels';

  @override
  String get onboardingEssentialsSub => 'Sobres et natifs';

  @override
  String get onboardingCharacters => 'Avec caractère';

  @override
  String get onboardingCharactersSub => 'La même app, plus de personnalité';

  @override
  String get onboardingLightMode => 'Mode clair';

  @override
  String get onboardingDarkMode => 'Mode sombre';

  @override
  String get onboardingNow => 'Actuel';

  @override
  String get onboardingContinue => 'Continuer';

  @override
  String get onboardingIconTitle => 'Votre icône d’app';

  @override
  String get onboardingIconBody =>
      'Gardez votre icône, laissez-la suivre votre thème ou choisissez-en une autre.';

  @override
  String get onboardingIconIosNote =>
      'iOS affiche une courte alerte à chaque changement d’icône.';

  @override
  String get onboardingGetStarted => 'C’est parti';

  @override
  String get appIconMatchTheme => 'Selon le thème';

  @override
  String get appIconCurrent => 'Actuelle';

  @override
  String get appIconSectionCollection => 'Collection MonkeyHub';

  @override
  String get appIconSectionThemes => 'Icônes des thèmes';

  @override
  String get appIconScreenTitle => 'Icône de l’app';

  @override
  String get appIconMatchFooter =>
      'Selon le thème change l’icône avec votre thème sombre, pour qu’elle ne bascule pas au fil de la journée.';

  @override
  String get loginTitleReturning => 'Bon retour';

  @override
  String get loginTitleFirst => 'Bienvenue sur MonkeyHub';

  @override
  String get loginTitleSignUp => 'Créez votre compte';

  @override
  String get loginTitleReset => 'Réinitialisez votre mot de passe';

  @override
  String get loginSubtitleSignIn =>
      'Connectez-vous pour reprendre là où vous en étiez.';

  @override
  String get loginSubtitleFirst =>
      'Connectez-vous, ou créez un compte en quelques secondes.';

  @override
  String get loginSubtitleSignUp =>
      'Un nom d’utilisateur et un mot de passe suffisent.';

  @override
  String get loginSubtitleReset =>
      'Saisissez votre phrase de récupération de 12 mots et choisissez un nouveau mot de passe.';

  @override
  String get loginCtaSignIn => 'Se connecter';

  @override
  String get loginCtaSignUp => 'Créer un compte';

  @override
  String get loginCtaReset => 'Réinitialiser';

  @override
  String get loginNoAccountPrompt => 'Nouveau ? ';

  @override
  String get loginCreateAccountLink => 'Créer un compte';

  @override
  String get loginHaveAccountPrompt => 'Déjà un compte ? ';

  @override
  String get loginSignInLink => 'Se connecter';

  @override
  String get loginForgotPassword => 'Mot de passe oublié ?';

  @override
  String get loginChildAccount => 'Configurer un compte enfant';

  @override
  String get loginBackToSignIn => 'Retour à la connexion';

  @override
  String get loginWithPhone => 'Se connecter avec votre téléphone';

  @override
  String get loginUsernameField => 'Nom d’utilisateur';

  @override
  String get loginPasswordField => 'Mot de passe';

  @override
  String get loginConfirmPasswordField => 'Confirmer le mot de passe';

  @override
  String get loginNameField => 'Nom (facultatif)';

  @override
  String get loginRecoveryPhraseField =>
      'Votre phrase de récupération de 12 mots';

  @override
  String get loginNewPasswordField => 'Nouveau mot de passe';

  @override
  String get roomHeaderStatusOnline => 'en ligne';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '$count membre',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => 'Réglages';

  @override
  String get settingsHubAccountHintAdult =>
      'Profil, famille, comptes associés et confidentialité';

  @override
  String get settingsHubAccountHintChild =>
      'Profil, confidentialité et tes adultes';

  @override
  String get settingsHubSectionGeneral => 'Général';

  @override
  String get settingsHubSectionNotifications => 'Notifications';

  @override
  String get settingsHubSectionCalls => 'Appels';

  @override
  String get settingsHubSectionAppearance => 'Apparence';

  @override
  String get settingsHubSectionCompanions => 'Compagnons';

  @override
  String get settingsHubSectionChats => 'Discussions';

  @override
  String get settingsHubSectionHelp => 'Aide et mentions légales';

  @override
  String get settingsHubSectionAdvanced => 'Avancé';

  @override
  String get settingsHubLanguage => 'Langue';

  @override
  String get settingsHubCheckForUpdates => 'Rechercher des mises à jour';

  @override
  String get settingsHubUpdateAvailable => 'Mise à jour disponible';

  @override
  String get settingsHubShowLinkUrls => 'Afficher l\'adresse des liens';

  @override
  String get settingsHubShowLinkUrlsSubtitle =>
      'Affiche l\'adresse à côté de chaque aperçu';

  @override
  String get settingsHubPush => 'Notifications push';

  @override
  String get settingsHubPushSubtitle => 'Nouveaux messages, appels et demandes';

  @override
  String get settingsHubGameReminders => 'Rappel de jeu quotidien';

  @override
  String get settingsHubGameRemindersSubtitle =>
      'Un petit rappel à midi si tu n\'as pas joué';

  @override
  String get settingsHubFriendActivity => 'Activité des amis';

  @override
  String get settingsHubFriendActivitySubtitle =>
      'Moments forts, points et résultats de tes amis';

  @override
  String get settingsHubMenuBar => 'Icône dans la barre des menus';

  @override
  String get settingsHubMenuBarSubtitle =>
      'Affiche le nombre de non-lus dans la barre des menus';

  @override
  String get settingsHubCallStats => 'Afficher les statistiques d\'appel';

  @override
  String get settingsHubCallStatsSubtitle =>
      'Résolution, débit et ping pendant les appels';

  @override
  String get settingsHubTheme => 'Thème';

  @override
  String get settingsHubAppIcon => 'Icône de l\'app';

  @override
  String get settingsHubGlass => 'Verre';

  @override
  String get settingsHubNavigation => 'Navigation';

  @override
  String get settingsHubMotion => 'Animations';

  @override
  String get settingsHubChatList => 'Liste des discussions';

  @override
  String get settingsHubChatStyle => 'Style des discussions';

  @override
  String get settingsHubBubbleStyle => 'Style des bulles';

  @override
  String get settingsHubSpeakerColors => 'Couleurs des membres';

  @override
  String get settingsHubReplyStyle => 'Style des réponses';

  @override
  String get settingsHubPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get settingsHubTerms => 'Conditions d\'utilisation';

  @override
  String get settingsHubLicence => 'Licence';

  @override
  String get settingsHubServer => 'Serveur';

  @override
  String get settingsHubLayoutRows => 'Lignes';

  @override
  String get settingsHubLayoutCards => 'Cartes';

  @override
  String get settingsHubLayoutGrid => 'Grille';

  @override
  String get settingsHubNavTabBar => 'Barre d\'onglets';

  @override
  String settingsHubThemeAuto(String name) {
    return 'Auto · $name';
  }

  @override
  String get chatListPageRowsSub =>
      'Un visage, un nom et le dernier message, comme dans Messages.';

  @override
  String get chatListPageCardsSub =>
      'Chaque salon dans sa propre carte, chaque détail affiché.';

  @override
  String get chatListPageGridSub =>
      'Deux colonnes de tuiles. Plus de salons d\'un coup d\'œil.';

  @override
  String get chatListPageLayoutHeader => 'Disposition';

  @override
  String get chatListPageFiltersHeader => 'Filtres';

  @override
  String get chatListPageChips => 'Pastilles';

  @override
  String get chatListPageChipsSub =>
      'Une rangée de filtres, toujours à portée de doigt.';

  @override
  String get chatListPageButton => 'Bouton';

  @override
  String get chatListPageButtonSub =>
      'Un bouton qui ouvre les filtres quand tu veux.';

  @override
  String get chatListPageEmptyHeader => 'Salons vides';

  @override
  String get chatListPagePlain => 'Sobre';

  @override
  String get chatListPagePlainSub => 'Un salon sans message reste dépouillé.';

  @override
  String get chatListPageInitial => 'Initiale';

  @override
  String get chatListPageInitialSub =>
      'Une grande lettre estompée remplit le coin vide.';

  @override
  String get chatListPageEmptyFooter =>
      'S\'applique à la disposition en grille.';

  @override
  String get chatStylePageFooter =>
      'Comment l\'en-tête et le champ de message sont dessinés.';

  @override
  String get chatStyleClassicSub =>
      'Un en-tête plein et un champ de message à plat.';

  @override
  String get chatStyleCompactSub =>
      'Des commandes givrées flottent sur la discussion.';

  @override
  String get bubbleTailedSub =>
      'Une queue sur le dernier message de chaque série, comme dans Messages.';

  @override
  String get bubbleSoftSub => 'Pas de queue. La série tient par ses coins.';

  @override
  String get bubblePillSub => 'Des capsules bien rondes pour chaque message.';

  @override
  String get bubbleSlabSub => 'Épaules carrées : nettes et assumées.';

  @override
  String get replyStylePageFooter =>
      'Comment une réponse montre le message auquel elle répond.';

  @override
  String get replyClassicSub =>
      'Une citation teintée au-dessus du message, façon WhatsApp.';

  @override
  String get replyPhantomSub =>
      'Un fantôme de l\'original flotte au-dessus, relié par une courbe.';

  @override
  String get replyStickySub => 'Une petite carte inclinée accrochée au coin.';

  @override
  String get replyComicSub => 'Une mini-bulle avec une queue de BD.';

  @override
  String get motionMatchDevice => 'Comme l\'appareil';

  @override
  String get motionMatchDeviceCalmSub =>
      'Ton appareil demande de réduire les animations.';

  @override
  String get motionMatchDeviceFullSub =>
      'Ton appareil autorise les animations.';

  @override
  String get motionFullSub => 'Chaque rebond, dérive et fioriture.';

  @override
  String get motionCalmSub =>
      'La décoration reste immobile. Le reste fonctionne pareil.';

  @override
  String get navigationPageFooter =>
      'Comment passer entre Discussions, Fil, Découvrir et Réglages.';

  @override
  String get navTabBarSub => 'Toujours visible, un toucher pour aller partout.';

  @override
  String get navOrbSub =>
      'Maintiens et glisse depuis le coin. Un geste qu\'on apprivoise.';

  @override
  String get languageSystemLabel => 'Langue de l\'appareil';

  @override
  String get languagePageFooter =>
      'Menus et messages de l\'app. Les discussions restent dans la langue de chacun.';

  @override
  String get speakerPageFooter =>
      'Repère qui parle d\'un coup d\'œil dans les groupes.';

  @override
  String get speakerOffSub => 'Tout le monde écrit de la même encre.';

  @override
  String get speakerNamesSub =>
      'Chacun garde une couleur sur son nom et son visage.';

  @override
  String get speakerBubblesSub =>
      'Leur couleur passe aussi dans leurs messages.';

  @override
  String get themePageAutoFooter =>
      'Les thèmes clairs servent en mode clair, les sombres en mode sombre.';

  @override
  String get themePageLightMode => 'Mode clair';

  @override
  String get themePageDarkMode => 'Mode sombre';

  @override
  String get themePageEssentials => 'Essentiels';

  @override
  String get themePageEssentialsFooter => 'Calmes et natifs, en cinq couleurs.';

  @override
  String get themePageCharacters => 'Caractères';

  @override
  String get themePageCharactersFooter =>
      'La même disposition, avec sa propre personnalité. Maintiens un thème pour l\'aperçu.';

  @override
  String get themePageLightBadge => 'Clair';

  @override
  String get themePageDarkBadge => 'Sombre';

  @override
  String get themePageInUse => 'Utilisé';

  @override
  String get themePageUseLight => 'Utiliser en mode clair';

  @override
  String get themePageUseDark => 'Utiliser en mode sombre';

  @override
  String themePageUse(String name) {
    return 'Utiliser $name';
  }

  @override
  String get acctCaptureTitle => 'Protection contre les captures';

  @override
  String get acctCaptureOnIos =>
      'L’enregistrement et la recopie affichent un écran de confidentialité.';

  @override
  String get acctCaptureOnAndroid =>
      'Les captures et enregistrements apparaissent noirs.';

  @override
  String get acctCaptureOff =>
      'Les captures et enregistrements fonctionnent normalement.';

  @override
  String get acctCaptureFooter =>
      'Les salons à messages éphémères l’activent toujours.';

  @override
  String get acctActionPending => 'En attente';

  @override
  String get chatSwipePin => 'Épingler';

  @override
  String get chatSwipeUnpin => 'Désépingler';

  @override
  String get chatSwipeMute => 'Silence';

  @override
  String get chatSwipeUnmute => 'Réactiver';

  @override
  String get chatSwipeArchive => 'Archiver';

  @override
  String get appearanceMatchDeviceSubtitle =>
      'Clair le jour, sombre la nuit, comme votre téléphone';

  @override
  String get appearanceOneThemeSubtitle => 'Le même style toute la journée';

  @override
  String get riName => 'Nom';

  @override
  String get riDescription => 'Description';

  @override
  String get riVisibility => 'Qui peut le trouver';

  @override
  String get riPublic => 'Public';

  @override
  String get riPublicSub => 'Tout le monde peut le trouver dans Découvrir';

  @override
  String get riPrivate => 'Privé';

  @override
  String get riPrivateSub => 'Seules les personnes invitées peuvent rejoindre';

  @override
  String get riMessageLife => 'Les messages disparaissent après';

  @override
  String get riPassword => 'Mot de passe';

  @override
  String get riRemovePassword => 'Supprimer le mot de passe';

  @override
  String get riSetPassword => 'Définir le mot de passe';

  @override
  String get riSharedContent => 'Contenu partagé';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invités',
      one: '1 invité',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => 'Retirer';

  @override
  String get riNotifications => 'Notifications';

  @override
  String get riTranslation => 'Traduction';

  @override
  String get riNameColours => 'Couleurs des noms';

  @override
  String get riYouSuggested => 'Vous avez suggéré';

  @override
  String get riTakeBack => 'Annuler';

  @override
  String get riLeaveRoom => 'Quitter le salon';

  @override
  String get riLeaving => 'Départ…';

  @override
  String get riDeleteRoom => 'Supprimer le salon';

  @override
  String get riDeleting => 'Suppression…';

  @override
  String get riEndConversation => 'Mettre fin à la conversation';

  @override
  String get riEnding => 'Fin en cours…';

  @override
  String get riActionCall => 'Appeler';

  @override
  String get riActionVideo => 'Vidéo';

  @override
  String get riActionMute => 'Silence';

  @override
  String get riActionUnmute => 'Réactiver';

  @override
  String get riActionMedia => 'Médias';

  @override
  String get riActionAdd => 'Ajouter';

  @override
  String get roomHeaderStatusTyping => 'écrit…';

  @override
  String get glassScreenLead => 'Ce qui transparaît de l’arrière-plan.';

  @override
  String get transcriptDayToday => 'Aujourd’hui';

  @override
  String get acctRowDevices => 'Appareils';

  @override
  String get acctThisDevice => 'Cet appareil';

  @override
  String get acctRemove => 'Retirer';

  @override
  String get acctRemoveDeviceTitle => 'Retirer cet appareil ?';

  @override
  String get acctRemoveAllTitle => 'Retirer tous les autres appareils ?';

  @override
  String get acctRemoveAll => 'Tout retirer';

  @override
  String get acctActiveNow => 'Actif maintenant';

  @override
  String get acctLoading => 'Chargement…';

  @override
  String get acctDevicesLoadFailed => 'Impossible de charger vos appareils.';

  @override
  String get acctNoNotifications =>
      'Les notifications n’arrivent pas sur celui-ci';

  @override
  String get acctBlockedEmpty => 'Vous n’avez bloqué personne.';

  @override
  String get acctUnblock => 'Débloquer';

  @override
  String get pvSubtitle =>
      'Choisissez ce que les autres voient et comment ils peuvent vous joindre.';

  @override
  String get pvSectionProfile => 'Profil';

  @override
  String get pvSectionMessages => 'Messages';

  @override
  String get pvSectionPeople => 'Personnes';

  @override
  String get pvSectionFeed => 'Fil';

  @override
  String get pvAvatar => 'Photo de profil';

  @override
  String get pvAvatarDesc => 'Qui peut voir votre photo';

  @override
  String get pvOnline => 'Statut en ligne';

  @override
  String get pvOnlineDesc => 'Si vous apparaissez actif en ce moment';

  @override
  String get pvLastSeen => 'Vu pour la dernière fois';

  @override
  String get pvLastSeenDesc => 'Quand vous étiez là pour la dernière fois';

  @override
  String get pvSendReceipts => 'Envoyer les accusés de lecture';

  @override
  String get pvSendReceiptsDesc =>
      'Permet aux autres de voir quand vous avez lu leurs messages';

  @override
  String get pvShowReceipts => 'Afficher les accusés de lecture';

  @override
  String get pvShowReceiptsDesc => 'Voir qui a lu vos messages';

  @override
  String get pvShowReceiptsHint =>
      'Seules les personnes qui envoient des accusés de lecture sont comptées.';

  @override
  String get pvFriendRequests => 'Demandes d’ami';

  @override
  String get pvFriendRequestsDesc => 'Qui peut vous envoyer des demandes';

  @override
  String get pvSupervisedTitle => 'Vos adultes choisissent ces réglages';

  @override
  String get pvEveryone => 'Tout le monde';

  @override
  String get pvFriends => 'Amis';

  @override
  String get pvNobody => 'Personne';

  @override
  String get pvOn => 'Activé';

  @override
  String get pvOff => 'Désactivé';

  @override
  String get pvAnyone => 'N’importe qui';

  @override
  String get pvHighlights => 'Mes moments forts';

  @override
  String get pvHighlightsDesc =>
      'Si vos photos et vidéos apparaissent sur les tableaux de vos amis du jour';

  @override
  String get pvPuzzle => 'Mon score au puzzle';

  @override
  String get pvPuzzleDesc =>
      'Si vos amis voient votre résultat au puzzle du jour';

  @override
  String get pvPast => 'Mon historique';

  @override
  String get pvPastDesc =>
      'Aujourd’hui est toujours partagé avec vos amis — ceci ouvre tout ce qui précède';

  @override
  String get pvPoints => 'Mes points';

  @override
  String get pvPointsDesc =>
      'Si les points que vous enregistrez apparaissent sur les tableaux de vos amis';
}
