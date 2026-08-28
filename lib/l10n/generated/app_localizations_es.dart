// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'SERVIDOR INALCANZABLE';

  @override
  String get bootErrorBody => 'Convex no se pudo iniciar.';

  @override
  String get bootErrorRetry => 'REINTENTAR';

  @override
  String get incomingCallNotificationTitle => 'Llamada entrante';

  @override
  String get incomingCallFallbackCaller => 'Alguien te está llamando';

  @override
  String get settingsLanguageRowLabel => 'IDIOMA';

  @override
  String get languageScreenTitle => 'idioma.';

  @override
  String get languageScreenSubtitle =>
      'elige el idioma de los menús y mensajes de la app';

  @override
  String get languageOptionSystem => 'SISTEMA';

  @override
  String get languageOptionSystemSub =>
      'usa el idioma configurado en tu dispositivo';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => 'ACTIVO';

  @override
  String get languageValueSystem => 'Sistema';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack =>
      'no se pudo preguntar ahora — inténtalo de nuevo';

  @override
  String get roomScreenGateSendMessages => 'enviar mensajes aquí';

  @override
  String get roomScreenGateSendMedia => 'enviar fotos o notas de voz';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'máximo $max a la vez';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ELIMINAR $count MENSAJES',
      one: 'ELIMINAR MENSAJE',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Esto los eliminará para todos en este chat. No se puede deshacer.';

  @override
  String get roomScreenDeleteConfirmButton => 'ELIMINAR PARA TODOS';

  @override
  String get roomScreenJumpFailedSnack => 'no se pudo ir a ese mensaje';

  @override
  String get roomScreenUnreadDivider => 'MENSAJES NO LEÍDOS';

  @override
  String get roomScreenViewOnceAlreadyViewed => 'ya abriste esta foto.';

  @override
  String get roomScreenViewOnceGone => 'esta foto ya no está disponible.';

  @override
  String get roomScreenViewOnceNetworkError => 'no se pudo cargar la foto.';

  @override
  String get roomScreenFileReadFailedSnack => 'no se pudo leer el archivo';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'los archivos tienen un límite de $size';
  }

  @override
  String get roomScreenRoomGone => 'la sala ya no existe';

  @override
  String get roomScreenCopiedSnack => 'copiado';

  @override
  String get roomScreenNameCopiedSnack => 'nombre copiado';

  @override
  String get roomScreenPinLimitSnack =>
      'demasiados mensajes fijados — quita uno primero';

  @override
  String get roomScreenPinFailedSnack => 'no se pudo fijar ese mensaje';

  @override
  String get roomScreenReportSentSnack =>
      'reporte enviado en privado. no se le notificará a la otra persona.';

  @override
  String get roomScreenDeselectMessageSemantic => 'Deseleccionar mensaje';

  @override
  String get roomScreenSelectMessageSemantic => 'Seleccionar mensaje';

  @override
  String roomScreenMemberCountBadge(Object count) {
    return '$count DENTRO';
  }

  @override
  String roomScreenTtlSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segundos',
      one: '$count segundo',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutos',
      one: '$count minuto',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '$count hora',
    );
    return '$_temp0';
  }

  @override
  String roomScreenEphemeralNotice(Object ttl) {
    return 'esta sala es efímera. los mensajes se desvanecen después de $ttl, se hayan leído o no.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count MENSAJES';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'Espacio Secreto';

  @override
  String get roomScreenSecretSpaceBody =>
      'Los mensajes de esta sala son efímeros. Se eliminan automáticamente según la política de seguridad de la sala.';

  @override
  String get roomScreenAutoDeleteTitle => 'Eliminación Automática';

  @override
  String get roomScreenAutoDeleteVaries => 'Variable';

  @override
  String get roomScreenAutoDeleteTimed => 'Temporizado';

  @override
  String get roomScreenNoCaptureTitle => 'Sin Capturas';

  @override
  String get roomScreenNoCaptureSubtitle => 'Capturas Restringidas';

  @override
  String get roomScreenMorePrivacyTitle => 'Mucha Más Privacidad';

  @override
  String get roomScreenMorePrivacySubtitle =>
      'Disfruta de funciones de seguridad adicionales, además del enfoque en privacidad que ya tenemos.';

  @override
  String get roomScreenNoMessagesTitle => 'Sin Mensajes';

  @override
  String get roomScreenNoMessagesSubtitle =>
      'Inicia la conversación enviando un mensaje';

  @override
  String get roomScreenViewProfilePictureSemantic => 'ver foto de perfil';

  @override
  String get roomScreenViewRoomPictureSemantic => 'ver foto de la sala';

  @override
  String get messageBubbleFileFallbackName => 'documento';

  @override
  String get messageBubbleAttachmentStatusFailed => 'fallida';

  @override
  String get messageBubbleAttachmentStatusSending => 'enviando…';

  @override
  String get messageBubbleViewOnceOpened => 'abierta';

  @override
  String get messageBubbleViewOnceExpired => 'caducada';

  @override
  String get messageBubbleViewOnceLabel => 'vista única';

  @override
  String get messageBubbleViewOnceTapToView => 'toca para ver';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Foto';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'foto de vista única, toca para ver';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'reintentar envío';

  @override
  String get messageBubbleDiscardSemanticLabel => 'descartar';

  @override
  String get profileScreenAccountSection => 'CUENTA';

  @override
  String get profileScreenAddEmailPlaceholder => 'añadir correo';

  @override
  String get profileScreenAddEmailTitle => '¿añadir correo?';

  @override
  String get profileScreenAddNameTitle => '¿añadir nombre?';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count en espera';
  }

  @override
  String get profileScreenApprovalsLabel => 'APROBACIONES';

  @override
  String get profileScreenApprovalsNothingWaiting => 'nada en espera';

  @override
  String get profileScreenApproveAction => 'APROBAR';

  @override
  String get profileScreenBlockAction => 'BLOQUEAR';

  @override
  String get profileScreenBlockedDmWiped =>
      'bloqueado y se borró el DM. no se le notificará.';

  @override
  String get profileScreenBlockedOnly => 'bloqueado. no se le notificará.';

  @override
  String get profileScreenBlockedUsers => 'USUARIOS BLOQUEADOS';

  @override
  String get profileScreenCancelAction => 'CANCELAR';

  @override
  String get profileScreenCancelRequestAction => 'CANCELAR SOLICITUD';

  @override
  String get profileScreenChangeAction => 'CAMBIAR';

  @override
  String get profileScreenChangeEmailTitle => '¿cambiar correo?';

  @override
  String get profileScreenChangeNameTitle => '¿cambiar nombre?';

  @override
  String get profileScreenChangeProfilePictureSemantic =>
      'cambiar foto de perfil';

  @override
  String get profileScreenChangeRecoveryPhrase =>
      'CAMBIAR FRASE DE RECUPERACIÓN';

  @override
  String get profileScreenChooseFromLibrary => 'ELEGIR DE LA GALERÍA';

  @override
  String get profileScreenCouldNotSaveImage => 'no se pudo guardar la imagen.';

  @override
  String get profileScreenDeleteAccount => 'ELIMINAR CUENTA';

  @override
  String get profileScreenEmailHint => 'opcional — nunca se muestra a nadie';

  @override
  String get profileScreenEmailSectionLabel => 'CORREO';

  @override
  String get profileScreenErrorAlreadyFriends => 'ya son amigos.';

  @override
  String get profileScreenErrorGeneric => 'no se pudo completar eso.';

  @override
  String get profileScreenErrorNotAccepting =>
      'no está aceptando solicitudes de amistad ahora mismo.';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      'ya te envió una solicitud — revisa tus solicitudes.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'solicitud ya enviada.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'bloqueaste a este usuario — desbloquéalo primero.';

  @override
  String get profileScreenErrorUserNotFound =>
      'esto no es posible ahora mismo.';

  @override
  String get profileScreenNameNotSaved =>
      'No se ha podido guardar tu nombre. Inténtalo de nuevo.';

  @override
  String get profileScreenFamilyAddChild => 'añadir un hijo';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hijos',
      one: '$count hijo',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => 'FAMILIA';

  @override
  String get profileScreenFriendsChip => 'AMIGOS';

  @override
  String get profileScreenGrownUpOnlyNote =>
      'Solo un mayor puede hacer esto — necesita su código o contraseña.';

  @override
  String get profileScreenGuardiansCanSee =>
      'Pueden ver cuándo estás en línea y con quién hablas.';

  @override
  String get profileScreenHandPhoneBack => 'DEVOLVER ESTE TELÉFONO';

  @override
  String get profileScreenIncomingRequestChip => 'SOLICITUD RECIBIDA';

  @override
  String get profileScreenJustTappedAction => 'TOQUÉ SIN QUERER';

  @override
  String get settingsScreenSectionHelpAndLegal => 'AYUDA Y LEGAL';

  @override
  String get settingsScreenLicence => 'LICENCIA';

  @override
  String get profileScreenLinkedAccountsLabel => 'CUENTAS VINCULADAS';

  @override
  String get profileScreenLinkedAccountsNone => 'ninguna cuenta vinculada';

  @override
  String get profileScreenMyGrownUps => 'MIS MAYORES';

  @override
  String get profileScreenNameHint => 'así te verán en la sala';

  @override
  String get profileScreenChangeUsernameTitle => '¿cambiar nombre de usuario?';

  @override
  String get profileScreenChangeUsernameWarning =>
      'Inicias sesión con esto, así que a partir de ahora escribirás el nuevo. Tu nombre de usuario anterior queda libre para que lo tome otra persona, y no podrás cambiarlo de nuevo durante 30 días. Los mensajes antiguos que te mencionaron conservan el nombre anterior.';

  @override
  String get profileScreenUsernameHint => 'así te encuentran tus amigos';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return 'se podrá cambiar de nuevo el $date';
  }

  @override
  String get profileScreenUsernamePasswordTitle => 'confirma que eres tú';

  @override
  String get profileScreenUsernamePasswordAction => 'CAMBIAR NOMBRE DE USUARIO';

  @override
  String get profileScreenUsernameProviderTitle =>
      'confirma con tu inicio de sesión';

  @override
  String profileScreenUsernameChanged(String username) {
    return 'Ahora eres @$username.';
  }

  @override
  String get profileScreenUsernameNotSaved =>
      'No se pudo cambiar tu nombre de usuario. Inténtalo de nuevo.';

  @override
  String get usernameStatusChecking => 'comprobando…';

  @override
  String get usernameStatusAvailable => 'disponible';

  @override
  String get usernameStatusTaken => 'ya está en uso';

  @override
  String get usernameStatusReserved => 'no disponible';

  @override
  String get usernameStatusInvalid => '1–32 caracteres';

  @override
  String get usernameStatusUnknown => 'no se pudo comprobar';

  @override
  String get profileScreenNobodyLookingAfter =>
      'todavía nadie está cuidando esta cuenta';

  @override
  String get profileScreenNotAcceptingRequestsAction => 'NO ACEPTA SOLICITUDES';

  @override
  String get profileScreenNotConnectedChip => 'SIN VÍNCULO';

  @override
  String get profileScreenOpenDmAction => 'ABRIR DM';

  @override
  String get profileScreenPhotoPermissionDenied => 'permiso de fotos denegado.';

  @override
  String get settingsScreenPrivacyPolicy => 'POLÍTICA DE PRIVACIDAD';

  @override
  String get profileScreenPrivacySection => 'PRIVACIDAD';

  @override
  String get profileScreenProfilePictureTitle => 'FOTO DE PERFIL';

  @override
  String get profileScreenRedactedFriend =>
      'algunos campos están ocultos por su configuración.';

  @override
  String get profileScreenRedactedStranger =>
      'vista limitada — comparten más con sus amigos.';

  @override
  String get profileScreenReportAction => 'DENUNCIAR';

  @override
  String get profileScreenReportSent =>
      'denuncia enviada en privado. no se les notificará.';

  @override
  String get profileScreenRequestPendingChip => 'SOLICITUD PENDIENTE';

  @override
  String get profileScreenSaveAction => 'GUARDAR';

  @override
  String get profileScreenSavedToPhotos => 'guardado en fotos.';

  @override
  String get profileScreenSaveToPhotos => 'GUARDAR EN FOTOS';

  @override
  String get profileScreenSendRequestAction => 'ENVIAR SOLICITUD';

  @override
  String get profileScreenSetUpRecoveryPhrase =>
      'CONFIGURAR FRASE DE RECUPERACIÓN';

  @override
  String get profileScreenSignOut => 'CERRAR SESIÓN';

  @override
  String get profileScreenTakeSelfie => 'TOMAR UNA SELFIE';

  @override
  String get profileScreenTapAgainToConfirmDelete =>
      'TOCA DE NUEVO PARA CONFIRMAR ELIMINACIÓN';

  @override
  String get settingsScreenTermsOfService => 'TÉRMINOS DE SERVICIO';

  @override
  String get profileScreenThisPhoneSection => 'ESTE TELÉFONO';

  @override
  String get profileScreenUnfriendAction => 'ELIMINAR AMISTAD';

  @override
  String get profileScreenViewProfilePictureSemantic => 'ver foto de perfil';

  @override
  String get profileScreenVisibilityPreferences =>
      'PREFERENCIAS DE VISIBILIDAD';

  @override
  String get cameraEditorScreenCropPresetFree => 'LIBRE';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'ORIG.';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'cancelar recorte';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'descartar foto';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'deshacer';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'rehacer';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'restablecer recorte';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'girar';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'recortar';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'este navegador no puede abrir fotos HEIC';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'no pudimos abrir esa imagen';

  @override
  String get cameraEditorScreenCropDoneButton => 'LISTO';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'tomar otra foto';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'guardar el lápiz';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'dibujar en la foto';

  @override
  String get cameraEditorScreenSendingButton => 'ENVIANDO…';

  @override
  String get cameraEditorScreenSendButton => 'ENVIAR';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'desaparece después de abrirse una vez';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'borrar dibujo';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel =>
      'ver una vez: activado';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel =>
      'ver una vez: desactivado';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: activado';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: desactivado';

  @override
  String get cameraEditorScreenHdNote => 'se enviará en resolución completa';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'color de tinta';

  @override
  String get glassScreenPanelLooks => 'ESTILOS';

  @override
  String get glassScreenPanelBottomBar => 'BARRA INFERIOR';

  @override
  String get glassScreenPanelOtherSurfaces => 'OTRAS SUPERFICIES';

  @override
  String get glassScreenPanelBarLayout => 'DISEÑO DE LA BARRA';

  @override
  String get glassScreenTitle => 'cristal.';

  @override
  String get glassScreenSubtitle => 'cuánto se transparenta lo que hay detrás';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'TODOS LOS $max ESPACIOS LLENOS';
  }

  @override
  String get glassScreenSaveCurrentAs => 'GUARDAR ACTUAL COMO…';

  @override
  String get glassScreenResetEveryDial => 'RESTABLECER TODOS LOS MANDOS';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'RESTABLECER A $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'el cuadro de mensaje, los encabezados, los botones de llamada: todo lo que se apoya sobre texto en vez de sobre contenido que se desplaza';

  @override
  String get glassScreenMatchBottomBar => 'IGUALAR A LA BARRA INFERIOR';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'editado — guárdalo como un nuevo estilo o restablécelo';

  @override
  String get glassScreenCustomPresetName => 'Personalizado';

  @override
  String get glassScreenUnsavedSubtitle =>
      'sin guardar — ponle un nombre para conservarlo';

  @override
  String get glassScreenSaveDialogTitle => 'guardar este estilo como';

  @override
  String get glassScreenNoRoomToast =>
      'sin espacio — elimina un estilo primero';

  @override
  String get glassScreenRenameDialogTitle => 'renombrar';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '¿eliminar $name?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'el estilo se queda en pantalla — solo deja de tener nombre.';

  @override
  String get glassScreenKeepButton => 'conservar';

  @override
  String get glassScreenDeleteButton => 'eliminar';

  @override
  String get glassScreenNameHint => 'trasnoche';

  @override
  String get glassScreenCancelButton => 'cancelar';

  @override
  String get glassScreenSaveButton => 'guardar';

  @override
  String get glassScreenPreviewRoomName => '# balcón';

  @override
  String get glassScreenPreviewOnlineCount => '4 en línea';

  @override
  String get glassScreenPreviewMessageHint => 'mensaje';

  @override
  String get glassScreenPreviewCollapseLabel => 'contraer vista previa';

  @override
  String get glassScreenPreviewExpandLabel => 'expandir vista previa';

  @override
  String get glassScreenPreviewBadge => 'VISTA PREVIA';

  @override
  String get glassScreenBuiltInLabel => 'integrado';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'sobrescribir $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'renombrar $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'eliminar $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'restablecer $label';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'envió las fotos del techo — las tejas están todas agrietadas';

  @override
  String get glassScreenBackdropMsgMert =>
      'ok pero quién trae el altavoz al final';

  @override
  String get glassScreenBackdropGroupFamily => 'familia';

  @override
  String get glassScreenBackdropMsgFamily =>
      'Mamá: cena a las 8, no llegues tarde otra vez';

  @override
  String get glassScreenBackdropMsgZeynep => 'estoy afuera';

  @override
  String get glassScreenBackdropMsgKerem =>
      'el sitio de la esquina hace un café buenísimo';

  @override
  String get glassScreenBackdropGroupWork => 'trabajo';

  @override
  String get glassScreenBackdropMsgWork =>
      'el standup se movió a las 10:30 para el resto de la semana';

  @override
  String get glassScreenBackdropMsgElif =>
      'no puede ser. mándalo otra vez, lo perdí';

  @override
  String get glassScreenBackdropMsgBaran => 'aterricé 👍';

  @override
  String get glassScreenBackdropMsgAyse =>
      'el gato aprendió a abrir la puerta del balcón';

  @override
  String get glassScreenBackdropMsgCan => 'nos vemos el sábado entonces';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return 'en respuesta a $name';
  }

  @override
  String get replyIndicatorViewOnceLabel => 'foto · ver una vez';

  @override
  String get replyIndicatorVoiceMessageLabel => 'mensaje de voz';

  @override
  String get replyIndicatorDocumentLabel => 'documento';

  @override
  String get replyIndicatorMessageRemoved => 'mensaje eliminado';

  @override
  String get threadOverlayMessageNotFound =>
      'no encontré ese mensaje en este hilo';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'no encontré el hilo al que responder';

  @override
  String get threadOverlayStillSending =>
      'aún se está enviando — inténtalo de nuevo en un momento';

  @override
  String get threadOverlayCopiedToast => 'copiado';

  @override
  String get threadOverlayNameCopiedToast => 'nombre copiado';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'coordenadas copiadas';

  @override
  String get threadOverlayPinLimitToast =>
      'demasiados mensajes fijados — desfija uno primero';

  @override
  String get threadOverlayPinFailedToast => 'no pude fijar eso';

  @override
  String get threadOverlayReportedToast => 'reportado';

  @override
  String get threadOverlayUnavailable => 'hilo no disponible';

  @override
  String get roomInfoScreenNameRequiredError => 'el nombre es obligatorio';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'contraseña eliminada';

  @override
  String get roomInfoScreenLeaveConfirmTitle => '¿salir de la sala?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'puedes volver a unirte si sigue abierta.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'SALIR';

  @override
  String get roomInfoScreenDeleteConfirmTitle => '¿eliminar la sala?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'todos los mensajes de aquí se van con ella. esto es permanente.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'ELIMINAR';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      '¿terminar esta conversación?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName también pierde esta conversación — todos los mensajes desaparecen para ambos. esto es permanente.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'TERMINAR';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'la otra persona';

  @override
  String get roomInfoScreenConfirmCancelButton => 'CANCELAR';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'ya existe una sala con ese nombre';

  @override
  String get roomInfoScreenErrorNotOwner => 'solo el dueño puede hacer eso';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'no tienes permiso';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'esta sala ya no existe';

  @override
  String get roomInfoScreenRoomGone => 'sala no encontrada';

  @override
  String get roomInfoScreenNameLabel => 'NOMBRE';

  @override
  String get roomInfoScreenNameHint => 'nombre de la sala';

  @override
  String get roomInfoScreenDescriptionLabel => 'DESCRIPCIÓN';

  @override
  String get roomInfoScreenDescriptionHint => 'una línea sobre la sala…';

  @override
  String get roomInfoScreenVisibilityLabel => 'VISIBILIDAD';

  @override
  String get roomInfoScreenPublicTitle => 'pública';

  @override
  String get roomInfoScreenPublicSub => 'cualquiera puede encontrarla';

  @override
  String get roomInfoScreenPrivateTitle => 'privada';

  @override
  String get roomInfoScreenPrivateSub => 'solo con invitación';

  @override
  String get roomInfoScreenMessageLifeLabel => 'VIDA DEL MENSAJE';

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
  String get roomInfoScreenPasswordLabel => 'CONTRASEÑA';

  @override
  String get roomInfoScreenLockedBadge => 'BLOQUEADA';

  @override
  String get roomInfoScreenNoneBadge => 'NINGUNA';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      'esta sala está protegida. la contraseña actual no se muestra por seguridad — escribe una nueva para reemplazarla.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'reemplazar contraseña…';

  @override
  String get roomInfoScreenSetPasswordHint => 'bloquear con una contraseña…';

  @override
  String get roomInfoScreenRemovePasswordButton => 'QUITAR CONTRASEÑA';

  @override
  String get roomInfoScreenSharedContentLabel => 'CONTENIDO COMPARTIDO';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return 'MIEMBROS · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => 'SALIENDO…';

  @override
  String get roomInfoScreenLeaveRoomButton => 'SALIR DE LA SALA';

  @override
  String get roomInfoScreenDeletingButton => 'ELIMINANDO…';

  @override
  String get roomInfoScreenDeleteButtonLabel => 'ELIMINAR';

  @override
  String get roomInfoScreenEndingConversationButton => 'TERMINANDO…';

  @override
  String get roomInfoScreenEndConversationButton => 'TERMINAR CONVERSACIÓN';

  @override
  String get roomInfoScreenHeaderConversation => 'CONVERSACIÓN';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'AJUSTES DE LA SALA';

  @override
  String get roomInfoScreenViewProfilePictureSemantic => 'ver foto de perfil';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'ver foto de la sala';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic =>
      'cambiar foto de la sala';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'añadir foto de la sala';

  @override
  String get roomInfoScreenOwnerBadge => 'PROPIETARIO';

  @override
  String get roomInfoScreenNoneCount => 'ninguno';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'el acceso a la cámara está desactivado.\nactívalo en Ajustes para tomar una foto.';

  @override
  String get cameraScreenOpeningSystemCamera =>
      'abriendo la cámara del sistema…';

  @override
  String get cameraScreenCloseButtonLabel => 'cerrar cámara';

  @override
  String get cameraScreenLowLightBoostOnLabel => 'modo de poca luz: activado';

  @override
  String get cameraScreenLowLightBoostOffLabel =>
      'modo de poca luz: desactivado';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'flash: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'elegir de la galería';

  @override
  String get cameraScreenSwitchCameraLabel => 'cambiar de cámara';

  @override
  String get cameraScreenTakePhotoLabel => 'tomar foto';

  @override
  String get childPolicyScreenAddByUsernameLabel =>
      'AGREGAR POR NOMBRE DE USUARIO';

  @override
  String get childPolicyScreenAddCta => 'AGREGAR';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'Tendrán exactamente lo mismo que tú: cada solicitud por aprobar, cada ajuste por cambiar y el poder de eliminarte a ti. Para $name, son familia desde el primer momento.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'AGREGAR UN ADULTO';

  @override
  String get childPolicyScreenAddGuardianHint => 'su nombre de usuario';

  @override
  String get childPolicyScreenAllowCta => 'PERMITIR';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'No te lo volveremos a preguntar, sin importar si $childName agrega a esta persona o esta persona agrega a $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'PERMITIR A ALGUIEN';

  @override
  String get childPolicyScreenAskToAddLabel => 'PEDIR AGREGAR';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'solo familia — sin solicitudes nuevas';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'pueden pedirte permiso para agregar a gente nueva';

  @override
  String get childPolicyScreenBothFinalNote =>
      'Ambas son definitivas. Retirarte en su lugar está en ADULTOS.';

  @override
  String get childPolicyScreenCallsLabel => 'LLAMADAS';

  @override
  String get childPolicyScreenCallsOffDesc => 'solo mensajes';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'voz y video con las personas permitidas';

  @override
  String get childPolicyScreenCancelLabel => 'CANCELAR';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Cancelar';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'agregado — la solicitud va en camino';

  @override
  String get childPolicyScreenContactAddedToList =>
      'agregado a la lista de permitidos';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'CREAR SALAS';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'no pueden crear salas';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'pueden crear sus propias salas privadas';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Todo desaparece: sus mensajes, fotos, salas y amigos. Esto no se puede deshacer, y el nombre de usuario queda libre para cualquier otra persona.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'no se pudo eliminar la cuenta — inténtalo de nuevo';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return '¿ELIMINAR LA CUENTA DE $name?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Mensajes, fotos, salas y amigos, todo desaparece. No se puede deshacer.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'ELIMINAR LA CUENTA DE $name';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'ELIMINAR PARA SIEMPRE';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'no se pudo agregar — inténtalo de nuevo';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'ese es su propio nombre de usuario';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'un menor no puede ser un adulto';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'no se pudo hacer eso — inténtalo de nuevo';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'alguien tiene que cuidar de ellos — añade a otro mayor primero';

  @override
  String get childPolicyScreenErrorNotYours =>
      'no tienes permiso para cambiar eso';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'no hay ninguna cuenta con ese nombre de usuario';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'Se convierten en una cuenta normal con esta contraseña, y todos los mayores pierden toda la visibilidad. No hay vuelta atrás: tendrías que recibir una invitación, como cualquier otra persona.';

  @override
  String get childPolicyScreenGraduateCta => 'GRADUAR';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'Conservan todo y reciben una contraseña. Pierdes toda la visibilidad. Irreversible.';

  @override
  String get childPolicyScreenGraduateDangerLabel =>
      'GRADUAR A CUENTA COMPLETA';

  @override
  String get childPolicyScreenGraduateFailed =>
      'no se pudo completar la graduación — inténtalo de nuevo';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'GRADUAR A $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'una contraseña para ellos';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Quitar una sala también les saca de ella. Quitar a una persona también borra su chat — para los dos.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Todos los que están aquí pueden aprobar, cambiar los ajustes y verlo todo. Cualquiera de ellos puede actuar por su cuenta — no hace falta esperar a los demás.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'añadido — ya pueden cuidar de ellos';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name eliminado';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (tú)';
  }

  @override
  String get childPolicyScreenLoading => 'cargando…';

  @override
  String get childPolicyScreenLockedLabel => 'BLOQUEADO';

  @override
  String get childPolicyScreenMediaLabel => 'FOTOS + VOZ';

  @override
  String get childPolicyScreenMediaOffDesc => 'solo texto';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'pueden enviar fotos, vídeos y notas de voz';

  @override
  String get childPolicyScreenNoRoomsYet => 'todavía no hay salas';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Cualquiera de aquí puede añadirse sin volver a pedirte permiso — no importa quién dé el primer paso.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Siempre desactivado para los niños. Descubre — la lista de salas de personas que no conoces — está completamente oculta y no se puede activar. Las salas a las que alguien les invite siguen funcionando con normalidad.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'SALAS PÚBLICAS';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian ya no podrá ver ni aprobar nada relacionado con $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return '¿ELIMINAR A $name?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'ELIMINAR';

  @override
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count miembros';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'MAYORES';

  @override
  String get childPolicyScreenSectionPeopleAllowed =>
      'PERSONAS QUE HAS PERMITIDO';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'SALAS QUE HAS PERMITIDO';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'QUÉ PUEDEN HACER';

  @override
  String get childPolicyScreenSectionWhenDone => 'AL TERMINAR';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'no pasa nada hasta que alguien añada al otro';

  @override
  String get childPolicyScreenSendNowOnDesc => 'se les pregunta enseguida';

  @override
  String get childPolicyScreenSendRequestNowLabel =>
      'ENVIAR LA SOLICITUD AHORA';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'Eres la única persona mayor de $name, así que no puedes simplemente alejarte — añade a otra primero, o usa una de estas.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'ALEJARSE';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'Perderás toda la visibilidad sobre la cuenta de $name — sus solicitudes, su gente, sus salas. Las demás personas mayores seguirán cuidando de $name.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'DEJAR DE SUPERVISAR';

  @override
  String get childPolicyScreenStopSupervisingHeadline =>
      '¿DEJAR DE SUPERVISAR?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'no se pudo revocar — inténtalo de nuevo';

  @override
  String get childPolicyScreenTakeBackLabel => 'REVOCAR';

  @override
  String get childPolicyScreenUsernameHint => 'nombre de usuario';

  @override
  String get childPolicyScreenYou => 'tú';

  @override
  String get roomContentScreenDefaultDocumentName => 'documento';

  @override
  String get roomContentScreenCouldntOpenFile => 'no se pudo abrir ese archivo';

  @override
  String get roomContentScreenCouldntShare =>
      'no se pudieron compartir esos elementos';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces copiados',
      one: 'enlace copiado',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ELIMINAR $count MENSAJES',
      one: 'ELIMINAR MENSAJE',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Se eliminará para todos en este chat. No se puede deshacer.';

  @override
  String get roomContentScreenDeleteForEveryone => 'ELIMINAR PARA TODOS';

  @override
  String get roomContentScreenCancelTooltip => 'Cancelar';

  @override
  String get roomContentScreenBackTooltip => 'Atrás';

  @override
  String get roomContentScreenSelectingLabel => 'SELECCIONANDO';

  @override
  String get roomContentScreenSharedContentLabel => 'CONTENIDO COMPARTIDO';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados',
      one: '$count seleccionado',
      zero: 'nada seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'SELECCIONAR';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'TODOS';

  @override
  String get roomContentScreenEmptyMedia => 'aún no hay fotos ni videos';

  @override
  String get roomContentScreenEmptyFiles => 'aún no hay archivos';

  @override
  String get roomContentScreenEmptyVoice => 'aún no hay notas de voz';

  @override
  String get roomContentScreenEmptyLinks => 'aún no hay enlaces';

  @override
  String get roomContentScreenEmptySaved =>
      'aún no has guardado nada. mantén pulsado un mensaje y elige GUARDAR.\n\nlo que guardas aquí es solo tuyo: un mensaje fijado es lo que ve toda la sala.';

  @override
  String get roomContentScreenLoadFailed => 'no se pudo cargar eso';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Mensaje de voz de $name';
  }

  @override
  String get roomContentScreenForwardAction => 'REENVIAR';

  @override
  String get roomContentScreenCopyAction => 'COPIAR';

  @override
  String get roomContentScreenSaveAction => 'GUARDAR';

  @override
  String get roomContentScreenShareAction => 'COMPARTIR';

  @override
  String get roomContentScreenInChatAction => 'VER EN CHAT';

  @override
  String get roomContentScreenDeleteAction => 'ELIMINAR';

  @override
  String get messageActionMenuReplyLabel => 'RESPONDER';

  @override
  String get messageActionMenuEditLabel => 'EDITAR';

  @override
  String get messageStampEditedLabel => 'editado';

  @override
  String get composerEditCardTitle => 'EDITAR MENSAJE';

  @override
  String get spoilerRevealHint =>
      'Spoiler — actívalo para mostrar el texto oculto';

  @override
  String get formatToolbarFormatLabel => 'Formato';

  @override
  String get formatToolbarBoldLabel => 'Negrita';

  @override
  String get formatToolbarItalicLabel => 'Cursiva';

  @override
  String get formatToolbarStrikethroughLabel => 'Tachado';

  @override
  String get formatToolbarUnderlineLabel => 'Subrayado';

  @override
  String get formatToolbarSpoilerLabel => 'Spoiler';

  @override
  String get formatToolbarLinkLabel => 'Enlace';

  @override
  String get formatToolbarCodeLabel => 'Código';

  @override
  String get linkInputSheetTitle => 'ENLACE';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => 'APLICAR ENLACE';

  @override
  String get linkInputSheetApplySub =>
      'El texto seleccionado abrirá esta dirección al tocarlo';

  @override
  String get linkInputSheetRemoveLabel => 'QUITAR ENLACE';

  @override
  String get linkConfirmSheetTitle => '¿ABRIR ESTE ENLACE?';

  @override
  String get linkConfirmSheetOpenLabel => 'ABRIR ENLACE';

  @override
  String get linkConfirmSheetCancelLabel => 'CANCELAR';

  @override
  String get roomScreenEditExpiredSnack =>
      'Demasiado tarde para editar — los mensajes solo se pueden editar durante 15 minutos.';

  @override
  String get roomScreenEditFailedSnack =>
      'No se ha podido guardar la edición. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get messageActionMenuForwardLabel => 'REENVIAR';

  @override
  String get messageActionMenuViewThreadLabel => 'VER HILO';

  @override
  String get messageActionMenuCopyLabel => 'COPIAR';

  @override
  String get messageActionMenuCopyNameLabel => 'COPIAR NOMBRE';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'COPIAR COORDENADAS';

  @override
  String get messageActionMenuPinLabel => 'FIJAR';

  @override
  String get messageActionMenuUnpinLabel => 'DESFIJAR';

  @override
  String get messageActionMenuSelectLabel => 'SELECCIONAR';

  @override
  String get messageActionMenuProfileLabel => 'PERFIL';

  @override
  String get messageActionMenuDeleteLabel => 'ELIMINAR';

  @override
  String get messageActionMenuReportLabel => 'DENUNCIAR';

  @override
  String get themeScreenTitle => 'tema.';

  @override
  String get themeScreenTapToApplyHint =>
      'toca para aplicar · ⛶ para vista previa completa';

  @override
  String get themeScreenFamilyBasicName => 'BÁSICO';

  @override
  String get themeScreenFamilyBasicTagline => 'inspirado en ios · 5 paletas';

  @override
  String get themeScreenFamilyVaultName => 'BÓVEDA';

  @override
  String get themeScreenFamilyVaultTagline => 'dosier privado · noir + marfil';

  @override
  String get themeScreenFamilyOthersName => 'OTROS';

  @override
  String get themeScreenFamilyOthersTagline => 'modos únicos';

  @override
  String get themeScreenActiveBadge => 'ACTIVO';

  @override
  String get themeScreenTapToApplyLabel => 'toca para aplicar';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return 'ACTIVO — $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return 'APLICAR $name';
  }

  @override
  String get themeScreenPreviewGreeting => 'hola, tú.';

  @override
  String get themeScreenPreviewSectionLabel => 'CONVERSACIÓN';

  @override
  String get themeScreenPreviewRoomOneName => 'club de diseño';

  @override
  String get themeScreenPreviewRoomOneSub => 'mia: lanzó el nuevo tile.';

  @override
  String get themeScreenPreviewRoomTwoName => 'cámara · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => 'se sella en 4h.';

  @override
  String get themeScreenPreviewBubbleQuestion => '¿cómo se siente esto?';

  @override
  String get themeScreenPreviewBubbleAnswer => 'como la elección correcta.';

  @override
  String get callScreenVideoCallLabel => 'Videollamada';

  @override
  String get callScreenVoiceCallLabel => 'Llamada de voz';

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · llamando…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · entrante';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · conectando…';
  }

  @override
  String get callScreenStatusConnected => 'conectado';

  @override
  String get callScreenStatusEnded => 'llamada finalizada';

  @override
  String get callScreenStatusFailed => 'llamada fallida';

  @override
  String get callScreenStatusSwitching => 'cambiando de dispositivo…';

  @override
  String get callScreenStatusMoved => 'movida';

  @override
  String get callScreenStatusReconnecting => 'reconectando…';

  @override
  String get callScreenPoorConnectionLabel => 'mala conexión';

  @override
  String get callScreenWeakConnectionLabel => 'conexión débil';

  @override
  String get callScreenControlUnmute => 'activar';

  @override
  String get callScreenControlMute => 'silenciar';

  @override
  String get callScreenControlCamOn => 'activar cámara';

  @override
  String get callScreenControlCamOff => 'desactivar cámara';

  @override
  String get callScreenControlFlip => 'voltear';

  @override
  String get callScreenControlSpeaker => 'altavoz';

  @override
  String get callScreenControlEnd => 'colgar';

  @override
  String get linkPreviewCardLinkLabel => 'ENLACE';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name aceptó tu solicitud';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'esa solicitud fue retirada';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'solicitud rechazada';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'bloqueaste a este usuario — desbloquéalo primero.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'no está aceptando solicitudes de amistad en este momento.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'no se pudo enviar. inténtalo de nuevo.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel =>
      'SOLICITUD ENTRANTE';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'NUEVA SOLICITUD';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name quiere iniciar una conversación.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'envía unas líneas. podrá aceptarla o rechazarla.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'nada de esto se guarda de forma permanente hasta que ambas partes estén de acuerdo.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'TIPO DE SALA';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'EFÍMERA';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'ESTÁNDAR';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'DURACIÓN';

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
      'susurra una primera línea · opcional';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'añade un primer mensaje · opcional';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'susurra · se desvanece solo';

  @override
  String get friendRequestDraftScreenHintStartWith => 'algo para empezar…';

  @override
  String get friendRequestDraftScreenApproveButton => 'APROBAR Y ABRIR SALA';

  @override
  String get friendRequestDraftScreenDeclineButton => 'RECHAZAR';

  @override
  String get friendRequestDraftScreenCancelRequestButton =>
      'CANCELAR SOLICITUD';

  @override
  String get friendRequestDraftScreenAskGrownUpButton =>
      'PREGÚNTALE A UN MAYOR';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'ENVIAR SOLICITUD';

  @override
  String get discoverScreenTitle => 'descubre.';

  @override
  String get discoverScreenCaptionPeople => 'gente';

  @override
  String get discoverScreenCaptionRooms => 'salas';

  @override
  String get discoverScreenCaptionRequests => 'solicitudes';

  @override
  String get discoverScreenPeopleBandLabel => 'GENTE';

  @override
  String get discoverScreenRoomsBandLabel => 'SALAS';

  @override
  String get discoverScreenFindPeopleTitle => 'buscar gente';

  @override
  String get discoverScreenFindPeopleSubtitleChild =>
      'escribe el nombre de usuario completo';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'busca por @usuario o nombre';

  @override
  String get discoverScreenRequestsSectionLabel => 'SOLICITUDES';

  @override
  String get discoverScreenInboxQuiet => 'bandeja tranquila';

  @override
  String get discoverScreenNothingPending => 'nada enviado';

  @override
  String get discoverScreenYourPeopleLabel => 'TU GENTE';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'nadie todavía — busca gente arriba';

  @override
  String get discoverScreenNoFriendsYet => 'nadie todavía';

  @override
  String get discoverScreenSearchRoomsTitle => 'buscar salas';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'busca una sala pública por nombre';

  @override
  String get discoverScreenYourRoomsLabel => 'TUS SALAS';

  @override
  String get discoverScreenNoRoomsYet => 'ninguna sala todavía';

  @override
  String get discoverScreenIncomingLabel => 'entrantes';

  @override
  String get discoverScreenOutgoingLabel => 'salientes';

  @override
  String get discoverScreenIncomingLabelCaps => 'ENTRANTES';

  @override
  String get discoverScreenOutgoingLabelCaps => 'SALIENTES';

  @override
  String get discoverScreenJumpPeopleLabel => 'personas';

  @override
  String get discoverScreenJumpRoomsLabel => 'salas';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Ir a $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'ajustar';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'USAR FOTO';

  @override
  String get imageCropScreenSavingButton => 'GUARDANDO…';

  @override
  String get imageCropScreenCancelButton => 'CANCELAR';

  @override
  String get imageCropScreenHeicUnsupported =>
      'este navegador no puede abrir fotos HEIC';

  @override
  String get imageCropScreenLoadFailed => 'no se pudo abrir esa imagen';

  @override
  String get imageCropScreenHintCircle =>
      'arrastra para mover, pellizca para hacer zoom';

  @override
  String get imageCropScreenHintRect => 'arrastra y pellizca para encuadrar';

  @override
  String get loginScreenSignInHeroMuted => 'bienvenido\n';

  @override
  String get loginScreenSignInHeroInk => 'de nuevo.';

  @override
  String get loginScreenSignInFirstHeroMuted => 'hola\n';

  @override
  String get loginScreenSignInFirstHeroInk => 'qué tal.';

  @override
  String get loginScreenSignInCta => 'INICIAR SESIÓN';

  @override
  String get loginScreenSignUpHeroMuted => 'cara\n';

  @override
  String get loginScreenSignUpHeroInk => 'nueva.';

  @override
  String get loginScreenSignUpCta => 'ABRIR CUENTA';

  @override
  String get loginScreenResetHeroMuted => 'restablecer\n';

  @override
  String get loginScreenResetHeroInk => 'contraseña.';

  @override
  String get loginScreenResetCta => 'RESTABLECER CONTRASEÑA';

  @override
  String get loginScreenErrorPasswordsDontMatch =>
      'Las contraseñas no coinciden.';

  @override
  String get loginScreenErrorChoosePasswordFirst =>
      'Elige primero una contraseña.';

  @override
  String get loginScreenUsernameHint => 'nombre de usuario';

  @override
  String get loginScreenPasswordHint => 'contraseña';

  @override
  String get loginScreenConfirmPasswordHint => 'confirmar contraseña';

  @override
  String get loginScreenNameOptionalHint => 'nombre (opcional)';

  @override
  String get loginScreenRecoveryPhraseHint =>
      'tu frase de recuperación de 12 palabras';

  @override
  String get loginScreenNewPasswordHint => 'nueva contraseña';

  @override
  String get loginScreenBackToSignIn => '← volver a iniciar sesión';

  @override
  String get loginScreenForgotPassword => '¿olvidaste tu contraseña?';

  @override
  String get loginScreenSettingUpKidsPhone => 'configura una cuenta infantil';

  @override
  String get loginScreenLegalPrefix => 'Al abrir una cuenta, aceptas los ';

  @override
  String get loginScreenLegalTermsLink => 'Términos';

  @override
  String get loginScreenLegalMiddle => ' y la ';

  @override
  String get loginScreenLegalPrivacyLink => 'Política de Privacidad';

  @override
  String get loginScreenLegalSuffix => '.';

  @override
  String get loginScreenAlreadyHerePrompt => '¿ya tienes cuenta? ';

  @override
  String get loginScreenSignInLink => 'inicia sesión';

  @override
  String get loginScreenNoAccountPrompt => '¿no tienes cuenta? ';

  @override
  String get loginScreenOpenOneLink => 'abre una';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12 palabras';
  }

  @override
  String get homeShellEmptyRoomHint => 'elige una sala para empezar a chatear';

  @override
  String get homeShellEmptySettingHint => 'elige un ajuste';

  @override
  String get searchScreenHintPeople => 'buscar personas…';

  @override
  String get searchScreenHintRooms => 'buscar salas…';

  @override
  String get searchScreenPeoplePromptChild =>
      'escribe el nombre de usuario completo para encontrar a alguien nuevo';

  @override
  String get searchScreenPeoplePromptDefault =>
      'busca por nombre de usuario o nombre';

  @override
  String get searchScreenNoMatchChild =>
      'nadie coincide — la gente nueva necesita\nsu nombre de usuario completo, letra por letra';

  @override
  String get searchScreenNoMatchDefault => 'nadie coincide';

  @override
  String get searchScreenNoRoomsYet => 'aún no hay salas públicas';

  @override
  String get searchScreenNoRoomsMatch => 'ninguna sala pública coincide';

  @override
  String get searchScreenActionAskToAdd => 'PEDIR AGREGAR';

  @override
  String get searchScreenActionSendRequest => 'ENVIAR SOLICITUD';

  @override
  String get searchScreenActionCancel => 'CANCELAR';

  @override
  String get searchScreenActionApprove => 'APROBAR';

  @override
  String get searchScreenActionOpenDm => 'ABRIR DM';

  @override
  String get searchScreenAskedLabel => 'pedido';

  @override
  String get profileVisibilityScreenTitle => 'preferencias de visibilidad.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'controla qué ven los demás — y cómo pueden contactarte.';

  @override
  String get profileVisibilityScreenSectionProfile => 'PERFIL';

  @override
  String get profileVisibilityScreenAvatarLabel => 'AVATAR';

  @override
  String get profileVisibilityScreenAvatarDesc => 'tu foto de perfil';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => 'EN LÍNEA / AUSENTE';

  @override
  String get profileVisibilityScreenOnlineAwayDesc =>
      'si apareces como activo en este momento';

  @override
  String get profileVisibilityScreenLastSeenLabel => 'ÚLTIMA VEZ';

  @override
  String get profileVisibilityScreenLastSeenDesc =>
      'la última vez que estuviste por aquí';

  @override
  String get profileVisibilityScreenSectionMessages => 'MENSAJES';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel =>
      'ENVIAR CONFIRMACIONES DE LECTURA';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      'cuando está activado, los demás pueden ver que has leído sus mensajes';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel =>
      'MOSTRAR CONFIRMACIONES DE LECTURA';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      'ver la marca \"VISTO\" en tus propios mensajes en cuanto los lean';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      'solo contribuirán los lectores que hayan activado ENVIAR CONFIRMACIONES DE LECTURA. los demás permanecerán invisibles.';

  @override
  String get profileVisibilityScreenSectionPeople => 'PERSONAS';

  @override
  String get profileVisibilityScreenFriendRequestsLabel =>
      'SOLICITUDES DE AMISTAD';

  @override
  String get profileVisibilityScreenFriendRequestsDesc =>
      'quién puede enviarte solicitudes de amistad';

  @override
  String get profileVisibilityScreenSupervisedTitle =>
      'TUS MAYORES CONFIGURAN ESTO';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      'Aquí puedes ver lo mismo que ven los demás, pero solo un mayor puede cambiarlo. Ellos siempre pueden ver tu foto, cuándo estás conectado y cuándo fue la última vez que estuviste por aquí.';

  @override
  String get profileVisibilityScreenOptionPublic => 'PÚBLICO';

  @override
  String get profileVisibilityScreenOptionFriends => 'AMIGOS';

  @override
  String get profileVisibilityScreenOptionNobody => 'NADIE';

  @override
  String get profileVisibilityScreenOptionOn => 'ACTIVADO';

  @override
  String get profileVisibilityScreenOptionOff => 'DESACTIVADO';

  @override
  String get profileVisibilityScreenOptionAnyone => 'CUALQUIERA';

  @override
  String get logoScreenTitle => 'logo de la app.';

  @override
  String get logoScreenSubtitle => 'el símbolo en tu encabezado, tú decides.';

  @override
  String get logoScreenAutoLabel => 'AUTO';

  @override
  String get logoScreenAutoDescription =>
      'sigue tu tema. el símbolo cambia con la paleta.';

  @override
  String get logoScreenManualLabel => 'MANUAL';

  @override
  String get logoScreenManualDescription =>
      'elige cualquier símbolo, conserva tu tema.';

  @override
  String get logoScreenAlwaysDefaultLabel => 'SIEMPRE PREDETERMINADO';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      'el símbolo de MonkeyHub, sin importar el tema.';

  @override
  String get logoScreenActiveBadge => 'ACTIVO';

  @override
  String get logoScreenMonkeyCollectionHeader => 'COLECCIÓN DE MONOS';

  @override
  String get logoScreenThemesHeader => 'TEMAS';

  @override
  String get recoveryPhraseScreenCopiedSnackbar =>
      'copiado — pégalo en un lugar seguro';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'confirma\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'que eres tú.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Tu contraseña, para que nadie más pueda poner una frase de recuperación en tu cuenta.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'contraseña';

  @override
  String get recoveryPhraseScreenContinueButton => 'CONTINUAR';

  @override
  String get recoveryPhraseScreenNotNowLink => 'ahora no';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'Ingresa tu contraseña.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'guarda\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => 'estas palabras.';

  @override
  String get recoveryPhraseScreenWordsBody =>
      'Estas doce palabras son la única forma de volver a tu cuenta si olvidas tu contraseña. No podemos volver a mostrártelas, y no podemos recuperarlas por ti.';

  @override
  String get recoveryPhraseScreenCopyButton => 'COPIAR';

  @override
  String get recoveryPhraseScreenPaperHint =>
      'Si puedes, anótalas en papel. Todo lo que hay en este teléfono puede perderse junto con el teléfono.';

  @override
  String get recoveryPhraseScreenSavedButton => 'LAS GUARDÉ';

  @override
  String get recoveryPhraseScreenBackLink => '← atrás';

  @override
  String get recoveryPhraseScreenKeepPhraseLink =>
      'ahora no — conservar mi frase actual';

  @override
  String get homeScreenProfileSemanticLabel => 'Tu perfil';

  @override
  String homeScreenGreeting(Object name) {
    return 'hola, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'Nueva sala';

  @override
  String get homeScreenEmptyRoomsMessage => 'aún no tienes salas — crea una';

  @override
  String get groupCallScreenTitleVideo => 'Videollamada grupal';

  @override
  String get groupCallScreenTitleVoice => 'Llamada de voz grupal';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '$count en la llamada';
  }

  @override
  String get groupCallScreenReconnecting => 'reconectando…';

  @override
  String get groupCallScreenUnmuteLabel => 'activar';

  @override
  String get groupCallScreenMuteLabel => 'silenciar';

  @override
  String get groupCallScreenCamOnLabel => 'encender cámara';

  @override
  String get groupCallScreenCamOffLabel => 'apagar cámara';

  @override
  String get groupCallScreenFlipLabel => 'voltear';

  @override
  String get groupCallScreenSpeakerLabel => 'altavoz';

  @override
  String get groupCallScreenLeaveLabel => 'salir';

  @override
  String get groupCallScreenYouLabel => 'Tú';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return 'Filtrando por $summary. Cambiar filtro';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => 'Filtrar chats';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => 'Borrar filtro';

  @override
  String get roomFilterDrawerClearLabel => 'borrar';

  @override
  String get roomFilterDrawerDimensionType => 'TIPO';

  @override
  String get roomFilterDrawerDimensionNature => 'NATURALEZA';

  @override
  String get roomFilterDrawerDimensionStatus => 'ESTADO';

  @override
  String get roomFilterDrawerPanelClear => 'BORRAR';

  @override
  String get roomFilterDrawerPanelDone => 'LISTO';

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
    return 'nada coincide con $summary';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar todos los $count chats',
      one: 'Mostrar el $count chat',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mostrar todos los $count chats',
      one: 'mostrar el $count chat',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'nueva sala';

  @override
  String get createRoomSheetTaglineSecret => 'NADA SE GUARDARÁ';

  @override
  String get createRoomSheetTaglineRegular => 'UN ESPACIO QUE QUEDA';

  @override
  String get createRoomSheetNameLabel => 'NOMBRE';

  @override
  String get createRoomSheetNameHint => 'ponle un nombre honesto…';

  @override
  String get createRoomSheetDescriptionLabel => 'DESCRIPCIÓN · OPCIONAL';

  @override
  String get createRoomSheetDescriptionHint => 'una línea sobre la sala…';

  @override
  String get createRoomSheetVisibilityLabel => 'VISIBILIDAD';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'pública';

  @override
  String get createRoomSheetVisibilityPublicSub =>
      'cualquiera puede encontrarla';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'privada';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'solo por invitación';

  @override
  String get createRoomSheetTypeLabel => 'TIPO';

  @override
  String get createRoomSheetTypeStandardTitle => 'estándar';

  @override
  String get createRoomSheetTypeStandardSub => 'los mensajes permanecen';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'efímera';

  @override
  String get createRoomSheetTypeEphemeralSub => 'se autoeliminan';

  @override
  String get createRoomSheetMessageLifeLabel => 'VIDA DEL MENSAJE';

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
  String get createRoomSheetPasswordLabel => 'CONTRASEÑA · OPCIONAL';

  @override
  String get createRoomSheetPasswordHint => 'ciérrala con una contraseña…';

  @override
  String get createRoomSheetNameRequiredError => 'el nombre es obligatorio';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Abrir la sala';

  @override
  String get createRoomSheetOpenRoomButton => 'ABRIR LA SALA';

  @override
  String get familyScreenTitle => 'FAMILIA';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cosas necesitan tu aprobación',
      one: '1 cosa necesita tu aprobación',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => 'en línea ahora';

  @override
  String get familyScreenPresenceNotPaired => 'aún sin emparejar';

  @override
  String get familyScreenPresenceJustNow => 'ahora mismo';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return 'hace ${minutes}m';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return 'hace ${hours}h';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return 'hace ${days}d';
  }

  @override
  String get familyScreenPairButton => 'EMPAREJAR';

  @override
  String get familyScreenReleaseButton => 'LIBERAR';

  @override
  String get familyScreenSettingsButton => 'AJUSTES';

  @override
  String get familyScreenAddChildButton => 'AÑADIR HIJO/A';

  @override
  String get familyScreenEmptyStateTitle => 'aún no hay hijos';

  @override
  String get familyScreenEmptyStateBody =>
      'Crea una cuenta para tu hijo o hija y vincúlala a su teléfono.';

  @override
  String get reactionDetailsSheetTitle => 'REACCIONES';

  @override
  String get reactionDetailsSheetEmptyState => 'ya no hay nada aquí';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas',
      one: '1 persona',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => 'TODOS';

  @override
  String get reactionDetailsSheetYouBadge => 'TÚ';

  @override
  String get roomLayoutScreenTitle => 'lista de chats.';

  @override
  String get roomLayoutScreenSubtitle =>
      'cómo se apilan las salas, y cómo las filtras';

  @override
  String get roomLayoutScreenLayoutSectionLabel => 'DISPOSICIÓN';

  @override
  String get roomLayoutScreenRowLayoutLabel => 'DISPOSICIÓN EN FILA';

  @override
  String get roomLayoutScreenRowLayoutDescription =>
      'una columna, a todo lo ancho. fácil de leer de un vistazo.';

  @override
  String get roomLayoutScreenGridLayoutLabel => 'DISPOSICIÓN EN CUADRÍCULA';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      'dos columnas, compacto. más salas de un vistazo.';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => 'CONTROL DE FILTROS';

  @override
  String get roomLayoutScreenChipRowLabel => 'FILA DE CHIPS';

  @override
  String get roomLayoutScreenChipRowDescription =>
      'siempre visible. un toque para cualquier filtro, una fila de espacio.';

  @override
  String get roomLayoutScreenDrawerButtonLabel => 'BOTÓN DESPLEGABLE';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      'un botón que se despliega. nada te estorba hasta que tú lo pidas.';

  @override
  String get roomLayoutScreenQuietRoomSectionLabel => 'SALAS EN SILENCIO';

  @override
  String get roomLayoutScreenPlainCornerLabel => 'esquina vacía';

  @override
  String get roomLayoutScreenPlainCornerDescription =>
      'una sala sin mensajes se queda desnuda';

  @override
  String get roomLayoutScreenMonogramLabel => 'la inicial de la sala';

  @override
  String get roomLayoutScreenMonogramDescription =>
      'una letra grande y tenue llena la esquina';

  @override
  String get roomLayoutScreenActiveBadge => 'ACTIVO';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel => 'Ir al mensaje fijado';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => 'Todos los mensajes fijados';

  @override
  String get pinnedBannerTitleSingle => 'Mensaje fijado';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return 'Mensaje fijado  $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => 'estilo de chat.';

  @override
  String get pinnedBannerChatStyleSubtitle => 'cómo se ve la sala';

  @override
  String get pinnedBannerClassicLabel => 'CLÁSICO';

  @override
  String get pinnedBannerClassicSubtitle =>
      'cabecera con línea divisoria, área de escritura plana.';

  @override
  String get pinnedBannerCompactLabel => 'COMPACTO';

  @override
  String get pinnedBannerCompactSubtitle =>
      'píldoras esmeriladas flotando sobre la conversación.';

  @override
  String get pinnedBannerActiveBadge => 'ACTIVO';

  @override
  String get audioMessageMissingLabel => '[audio no disponible]';

  @override
  String get audioMessageUnavailableLabel => 'audio no disponible';

  @override
  String get audioMessageRetryHint => 'toca para reintentar';

  @override
  String get audioMessageLoadingLabel => 'cargando…';

  @override
  String get audioMessageUsernameRequiredError =>
      'Escribe tu nombre de usuario.';

  @override
  String get audioMessagePasswordRequiredError => 'Escribe tu contraseña.';

  @override
  String get audioMessageCancelSemanticLabel => 'Cancelar';

  @override
  String get audioMessageHeroCreateLine1 => 'casi\n';

  @override
  String get audioMessageHeroCreateLine2 => 'ahí.';

  @override
  String get audioMessageHeroLinkLine1 => 'bienvenido\n';

  @override
  String get audioMessageHeroLinkLine2 => 'de nuevo.';

  @override
  String get audioMessageCreateSubtitle =>
      'Elige un nombre de usuario para que tu familia y amigos puedan encontrarte.';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return 'Inicia sesión una vez y $provider quedará vinculado a tu cuenta.';
  }

  @override
  String get audioMessageUsernameHint => 'nombre de usuario';

  @override
  String get audioMessageDisplayNameHint => 'nombre para mostrar (opcional)';

  @override
  String get audioMessagePasswordHint => 'contraseña';

  @override
  String get audioMessageSwitchToLinkPrompt =>
      'Esa cuenta es mía — inicia sesión';

  @override
  String get audioMessageCreateAccountButton => 'CREAR CUENTA';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return 'INICIAR SESIÓN Y VINCULAR $provider';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => '¿Ya tienes una cuenta?';

  @override
  String get audioMessageSwitchToCreateModeLink =>
      '¿Nuevo por aquí? Crea una cuenta';

  @override
  String get approvalsScreenTitle => 'APROBACIONES';

  @override
  String get approvalsScreenEmptyTitle => 'nada pendiente';

  @override
  String get approvalsScreenEmptySubtitle => 'estás al día';

  @override
  String get approvalsScreenErrorNotGuardian => 'esa decisión no es tuya';

  @override
  String get approvalsScreenErrorAlreadyHandled =>
      'ya se resolvió desde otro lado';

  @override
  String get approvalsScreenErrorGeneric =>
      'no se pudo guardar — inténtalo de nuevo';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child quiere agregar a $other';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other quiere agregar a $child';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child quiere unirse a $room';
  }

  @override
  String get approvalsScreenSomeoneLower => 'alguien';

  @override
  String get approvalsScreenSomeoneCapital => 'Alguien';

  @override
  String get approvalsScreenRoomFallback => 'una sala';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      'Recibirá la solicitud. Aun así, decide si acepta o no.';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$child verá la solicitud y podrá aceptarla o ignorarla.';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      'Podrá leer y escribir ahí hasta que le retires el permiso.';

  @override
  String get approvalsScreenNotYetButton => 'AHORA NO';

  @override
  String get approvalsScreenAllowButton => 'PERMITIR';

  @override
  String get approvalsScreenForwardDirectMessageFallback => 'mensaje directo';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'REENVIAR $count MENSAJES',
      one: 'REENVIAR MENSAJE',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'aún no hay otros chats';

  @override
  String get approvalsScreenForwardNoMatches => 'no hay coincidencias';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'hasta $max chats a la vez';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'buscar chats';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Deseleccionar $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Seleccionar $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'DESAPARECE';

  @override
  String get approvalsScreenForwardSendSemantic => 'Enviar';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ENVIAR A $count',
      zero: 'ENVIAR',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => 'CUENTAS VINCULADAS';

  @override
  String get linkedAccountsScreenSubtitle =>
      'Cuentas que has vinculado a esta, para que puedas iniciar sesión sin contraseña.';

  @override
  String get linkedAccountsScreenEmptyState =>
      'No hay nada que vincular en este dispositivo.';

  @override
  String get linkedAccountsScreenStatusChecking => 'Comprobando…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return 'Puedes iniciar sesión con $provider en cualquiera de tus dispositivos.';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return 'Añade $provider para que no tengas que escribir tu contraseña.';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return 'DESVINCULAR $provider';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => 'DESVINCULAR';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return 'Escribe tu contraseña para dejar de iniciar sesión con $provider.';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return 'VINCULAR $provider';
  }

  @override
  String get linkedAccountsScreenLinkAction => 'VINCULAR';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return 'Escribe tu contraseña para añadir $provider como forma de iniciar sesión.';
  }

  @override
  String get linkedAccountsScreenPillChecking => 'COMPROBANDO';

  @override
  String get linkedAccountsScreenPillLinked => 'VINCULADA';

  @override
  String get linkedAccountsScreenPillNotLinked => 'NO VINCULADA';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => 'VOZ';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'VIDEO';

  @override
  String get linkedAccountsScreenCallSheetTitle => 'Iniciar una llamada';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle => 'Llamar a todos';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      'Llama a todos los miembros de esta sala';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle =>
      'Elegir personas';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle =>
      'Elige a quién invitar';

  @override
  String get linkedAccountsScreenCallSheetCallFullError =>
      'Esa llamada está llena (máximo 6 personas)';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError =>
      'No se pudo iniciar la llamada';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle => 'Invitar a la llamada';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers =>
      'No hay más miembros aquí';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => 'Selecciona personas';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => 'Iniciar llamada';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return 'Iniciar llamada ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => 'hola';

  @override
  String get childPairScreenGreetingLine2 => 'tú.';

  @override
  String get childPairScreenIntro =>
      'Pídele a un mayor que abra MonkeyHub y toque “emparejar un dispositivo”. Luego escanea su código, o escribe los seis números que te diga.';

  @override
  String get childPairScreenOrDivider => 'o';

  @override
  String get childPairScreenGenericError =>
      'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get childPairScreenAccountGoneError => 'Esa cuenta ya no existe.';

  @override
  String get childPairScreenScanButtonLabel => 'ESCANEA SU CÓDIGO';

  @override
  String get childPairScreenNoCameraMessage =>
      'No hay cámara aquí — escribe los seis números en su lugar.';

  @override
  String get childPairScreenStopScanning => 'dejar de escanear';

  @override
  String get childPairScreenSubmitButtonLabel => 'DÉJAME ENTRAR';

  @override
  String get childPairScreenBackToSignIn => '← volver a iniciar sesión';

  @override
  String get fileMessageUnavailable => 'el archivo ya no está disponible';

  @override
  String get fileMessageOpenFailed => 'no se pudo abrir ese archivo';

  @override
  String get fileMessageDefaultName => 'documento';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return 'Guardar $name';
  }

  @override
  String fileMessageViewSemanticLabel(Object name) {
    return 'Ver $name';
  }

  @override
  String get textFileViewerDownloadTooltip => 'Descargar';

  @override
  String get textFileViewerTruncatedNotice =>
      'Mostrando parte de este archivo — descárgalo para ver el resto.';

  @override
  String get fileMessageUploadFailedLabel => 'fallido';

  @override
  String get fileMessageSendingLabel => 'enviando…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · enviando…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return 'hace $count min';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return 'hace $count h';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return 'hace $count d';
  }

  @override
  String get fileMessageStandardBadge => 'ESTÁNDAR';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes en borrador · toca para ver',
      one: '$count mensaje en borrador · toca para ver',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => 'APROBAR';

  @override
  String get fileMessageDeclineButton => 'RECHAZAR';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'ENVIADO $ago';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes pendientes',
      one: '$count mensaje pendiente',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => 'CANCELAR SOLICITUD';

  @override
  String get destructiveSheetCannotBeUndone => 'esto no se puede deshacer';

  @override
  String get destructiveSheetCancelSemanticLabel => 'Cancelar';

  @override
  String get destructiveSheetCancelButtonLabel => 'CANCELAR';

  @override
  String get destructiveSheetHideLabel => 'OCULTAR';

  @override
  String get destructiveSheetViewLabel => 'VER';

  @override
  String get destructiveSheetPairingMintError =>
      'No se pudo crear el código — inténtalo de nuevo.';

  @override
  String get destructiveSheetPairingReleaseTitle => 'LIBERAR';

  @override
  String get destructiveSheetPairingPairTitle => 'EMPAREJAR';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return 'En el teléfono de $name, abre su perfil, toca «devolver este teléfono» y escribe estos números.';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return 'En el teléfono de $name, abre MonkeyHub y escanea esto — o escribe los números.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'este código ha caducado';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'caduca en $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'NUEVO CÓDIGO';

  @override
  String get destructiveSheetPairingOneUseNote =>
      'Solo se puede usar una vez. Crear un código nuevo cancela el anterior.';

  @override
  String get deepOceanThemeAttachButtonLabel => 'Adjuntar';

  @override
  String get deepOceanThemeCameraButtonLabel => 'Cámara';

  @override
  String get deepOceanThemeSendButtonLabel => 'Enviar';

  @override
  String get deepOceanThemeEphemeralHint =>
      'susurra algo que el servidor olvidará…';

  @override
  String get deepOceanThemeDefaultHint => 'di algo…';

  @override
  String get deepOceanThemeMessageHint => 'Mensaje';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'este archivo desapareció';

  @override
  String get photoChromeMediaYouLabel => 'tú';

  @override
  String get photoChromeCloseSemanticLabel => 'Cerrar';

  @override
  String get photoChromeShowInChatSemanticLabel => 'Mostrar en el chat';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return 'Elemento $current de $total';
  }

  @override
  String photoTrayCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos',
      one: '1 foto',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => 'descartar estas fotos';

  @override
  String get photoTrayRemoveSemanticLabel => 'quitar esta foto';

  @override
  String get photoTrayEditSemanticLabel => 'recortar o dibujar en esta foto';

  @override
  String get photoTrayAddMoreSemanticLabel => 'añadir más fotos';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'puedes enviar $count fotos a la vez';
  }

  @override
  String get photoTrayLoadFailedSnack =>
      'no se pudieron abrir algunas de esas fotos';

  @override
  String get mediaPickFailedMessage => 'no se pudo abrir — vuelve a elegirlo';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name está escribiendo';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1 y $name2 están escribiendo';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1, $name2 +$extra están escribiendo';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => 'llamada entrante';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'VIDEOLLAMADA ENTRANTE';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'LLAMADA DE VOZ ENTRANTE';

  @override
  String get typingIndicatorDeclineButtonLabel => 'rechazar';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'rechazando…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'aceptar';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'conectando…';

  @override
  String get messageStampNavigationTitle => 'navegación.';

  @override
  String get messageStampNavigationSubtitle =>
      'cómo te mueves entre chat, descubrir, feed y ajustes';

  @override
  String get messageStampRadialOrbLabel => 'ORBE RADIAL';

  @override
  String get messageStampRadialOrbDescription =>
      'mantén pulsado y arrastra desde la esquina. tranquilo en reposo, un gesto al que te acostumbras con el tiempo.';

  @override
  String get messageStampBottomPillLabel => 'CÁPSULA INFERIOR';

  @override
  String get messageStampBottomPillDescription =>
      'toque clásico. siempre visible, sin curva de aprendizaje.';

  @override
  String get messageStampActiveLabel => 'ACTIVO';

  @override
  String get messageStampUploadingLabel => 'subiendo';

  @override
  String get messageStampSendingLabel => 'enviando';

  @override
  String get messageStampFailedToSendLabel => 'no se pudo enviar';

  @override
  String get messageStampSentLabel => 'enviado';

  @override
  String get messageStampDeliveredLabel => 'entregado';

  @override
  String get messageStampSeenLabel => 'visto';

  @override
  String get messageStampSavedLabel => 'guardado';

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
      'permiso de micrófono denegado';

  @override
  String get voiceRecorderScreenStatusRecording => 'GRABANDO';

  @override
  String get voiceRecorderScreenStatusReady => 'LISTO';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'TOCA PARA EMPEZAR';

  @override
  String get voiceRecorderScreenReRecordButton => 'REGRABAR';

  @override
  String get voiceRecorderScreenStopButton => 'PARAR';

  @override
  String get voiceRecorderScreenSendButton => 'ENVIAR';

  @override
  String get voiceRecorderScreenRecordButton => 'GRABAR';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => 'Todos';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => 'NOTIFICA A TODOS';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => 'PROPIETARIO';

  @override
  String get releaseDeviceScreenFallbackChildName => 'esta persona';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return 'Esto cierra la sesión de $name en este teléfono y lo devuelve — el teléfono vuelve a la pantalla de inicio de sesión normal, y cualquiera puede usarlo.';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'Su cuenta, mensajes y amigos se conservan. Puede volver a iniciar sesión cuando quiera.';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return 'Pide a un mayor que abra MonkeyHub, busque a $name en Familia y toque “soltar”.';
  }

  @override
  String get releaseDeviceScreenOrDivider => 'o';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      'Si solo hay este teléfono, un mayor puede iniciar sesión aquí en su lugar.';

  @override
  String get releaseDeviceScreenUsernameHint => 'nombre de usuario de un mayor';

  @override
  String get releaseDeviceScreenPasswordHint => 'su contraseña';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => 'Cerrar sesión';

  @override
  String get releaseDeviceScreenChecking => 'COMPROBANDO…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return 'CERRAR SESIÓN DE $name';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => 'DEVUELVE ESTE TELÉFONO';

  @override
  String get releaseDeviceScreenErrorCodeExpired =>
      'Ese código ha caducado. Pide uno nuevo.';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      'Ese código no funcionó. Puede que ya se haya usado.';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      'Eso no funcionó. Revisa el nombre de usuario y la contraseña.';

  @override
  String get releaseDeviceScreenErrorGeneric =>
      'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get activeCallPillMoveHereSemanticLabel =>
      'Mover llamada a este dispositivo';

  @override
  String activeCallPillCallWith(Object name) {
    return 'Llamada con $name';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return 'En $device';
  }

  @override
  String get activeCallPillMoveHereLabel => 'Mover aquí';

  @override
  String get activeCallPillUnknownCaller => 'Desconocido';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'Simulador de iOS';

  @override
  String get activeCallPillPlatformAndroid => 'Dispositivo Android';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'PC con Windows';

  @override
  String get activeCallPillPlatformLinux => 'Dispositivo Linux';

  @override
  String get activeCallPillPlatformBrowser => 'Navegador';

  @override
  String get activeCallPillPlatformOther => 'otro dispositivo';

  @override
  String get activeCallPillPinnedHeader => 'FIJADOS';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'FIJADOS · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'ya no hay nada fijado';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Ir al mensaje de $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Dejar de fijar el mensaje de $name';
  }

  @override
  String get callButtonErrorBusy => 'ocupado en otra llamada';

  @override
  String get callButtonErrorCallFailed => 'no se pudo iniciar la llamada';

  @override
  String get callButtonErrorNotMember => 'no eres miembro de esta sala';

  @override
  String get callButtonErrorGeneric => 'no se pudo iniciar la llamada';

  @override
  String get callButtonAlreadyOnCall => 'Ya estás en una llamada';

  @override
  String get callButtonBusyElsewhere => 'Llamada en curso en otro dispositivo';

  @override
  String get callButtonVoiceCallTooltip => 'llamada de voz';

  @override
  String get callButtonVideoCallTooltip => 'videollamada';

  @override
  String get callButtonTooltip => 'llamada';

  @override
  String get callButtonReplyStyleTitle => 'estilo de respuesta.';

  @override
  String get callButtonReplyStyleSubtitle =>
      'cómo una respuesta muestra el mensaje al que responde';

  @override
  String get callButtonReplyStylePhantomEchoLabel => 'ECO FANTASMA';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      'una burbuja fantasma del mensaje original flota arriba, con un conector curvo y el ícono de rama en el punto de unión.';

  @override
  String get callButtonReplyStyleStickyNoteLabel => 'NOTA ADHESIVA';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      'una tarjeta estilo polaroid ligeramente girada, sujeta a la esquina de la burbuja.';

  @override
  String get callButtonReplyStyleComicTailLabel => 'COLA DE CÓMIC';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      'una pequeña mini-burbuja del mensaje original con una cola triangular estilo cómic que apunta hacia abajo.';

  @override
  String get callButtonReplyStyleClassicLabel => 'CLÁSICO';

  @override
  String get callButtonReplyStyleClassicDescription =>
      'cápsula de cita con tono de acento, barra de conexión y avatar — el look clásico al estilo WhatsApp que ya conoces.';

  @override
  String get callButtonReplyStyleActiveBadge => 'ACTIVO';

  @override
  String get callButtonReplyPreviewSampleMessage =>
      'oye, ¿viste la demo nueva?';

  @override
  String get callButtonReplyPreviewSampleReply =>
      'sí, ese desenfoque está increíble.';

  @override
  String get childSetupScreenErrorPickUsername =>
      'Elige un nombre de usuario para ellos.';

  @override
  String get childSetupScreenErrorUsernameTaken =>
      'Ese nombre de usuario ya está en uso.';

  @override
  String get childSetupScreenErrorChildNotAllowed =>
      'Solo la cuenta de un mayor puede añadir a un niño.';

  @override
  String get childSetupScreenErrorGeneric =>
      'No se pudo crear la cuenta — inténtalo de nuevo.';

  @override
  String get childSetupScreenTitle => 'AÑADIR UN NIÑO';

  @override
  String get childSetupScreenHeading => '¿quién\nes?';

  @override
  String get childSetupScreenNameLabel => 'NOMBRE';

  @override
  String get childSetupScreenNameHint => 'cómo le dices';

  @override
  String get childSetupScreenUsernameLabel => 'NOMBRE DE USUARIO';

  @override
  String get childSetupScreenUsernameHint => 'cómo lo encuentran sus amigos';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'QUÉ OBTIENEN';

  @override
  String get childSetupScreenBulletTalkImmediately =>
      'Pueden hablar contigo y con sus hermanos de inmediato.';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      'Todos los demás necesitan tu aprobación primero — tanto las personas que ellos pidan agregar, como las que pidan agregarlos a ellos.';

  @override
  String get childSetupScreenBulletPublicRoomsOff =>
      'Las salas públicas están desactivadas hasta que tú las actives.';

  @override
  String get childSetupScreenBulletCantSignOut =>
      'No pueden cerrar sesión, y tú siempre puedes ver cómo les va.';

  @override
  String get childSetupScreenCreateButton => 'CREAR + VINCULAR';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return 'Enviar mensaje a $name';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => 'pedido';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'MIEMBROS';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'ver todo ($count)';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return 'Ver todo ($count)';
  }

  @override
  String get bubbleStyleScreenTitle => 'estilo de burbuja.';

  @override
  String get bubbleStyleScreenSubtitle => 'la forma en que llegan tus palabras';

  @override
  String get bubbleStyleScreenTailedLabel => 'CON COLA';

  @override
  String get bubbleStyleScreenTailedDescription =>
      'una cola cierra cada serie de mensajes; las filas superiores se juntan en un solo bloque.';

  @override
  String get bubbleStyleScreenSoftLabel => 'SUAVE';

  @override
  String get bubbleStyleScreenSoftDescription =>
      'sin cola — una serie se mantiene unida solo por sus esquinas internas cerradas.';

  @override
  String get bubbleStyleScreenPillLabel => 'CÁPSULA';

  @override
  String get bubbleStyleScreenPillDescription =>
      'cápsulas totalmente redondeadas, iguales en cada fila.';

  @override
  String get bubbleStyleScreenSlabLabel => 'BLOQUE';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'hombros cuadrados — nítidos, impresos, decididos.';

  @override
  String get bubbleStyleScreenActiveBadge => 'ACTIVO';

  @override
  String get bubbleStyleScreenPreviewQuestion => '¿y? ¿cómo se ve?';

  @override
  String get bubbleStyleScreenPreviewReplyOne => 'mejor';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => 'mucho mejor';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => 'Video';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => 'Foto';

  @override
  String get incomingGroupCallScreenCallFullError =>
      'Esa llamada está llena (máximo 6 personas)';

  @override
  String get incomingGroupCallScreenJoinFailedError =>
      'No se pudo unir a la llamada';

  @override
  String get incomingGroupCallScreenDefaultRoomName => 'Llamada grupal';

  @override
  String get incomingGroupCallScreenDefaultStarterName => 'Alguien';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starter inició una videollamada';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starter inició una llamada de voz';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '$count ya dentro';
  }

  @override
  String get incomingGroupCallScreenDismissButton => 'Rechazar';

  @override
  String get incomingGroupCallScreenJoinButton => 'Unirse';

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
      other: '$count mensajes',
      one: '$count mensaje',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      'último mensaje hace un momento';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'último mensaje hace $hours h';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'último mensaje ayer';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'último mensaje hace $days días';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'último mensaje hace un tiempo';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'RETIRAR';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return '¿quitar a $contactName de los contactos de $childName?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'ya no podrán contactarse entre sí, y su conversación desaparecerá con ello.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'ya no podrán contactarse entre sí. $contactName no se enterará.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats · $messages se eliminarán';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      'desaparecerán para ambos, incluidas fotos y notas de voz. esto no se puede deshacer.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'también comparten $count salas',
      one: 'también comparten $count sala',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'estas se quedan. si quieres sacarlas, recupera la sala en la lista de SALAS de abajo.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'RECUPERAR Y ELIMINAR';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'elimina a $contactName y borra $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'elimina a $contactName de la lista de permitidos.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Cancelar';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton =>
      'CANCELAR';

  @override
  String get groupCallBannerCallFullError =>
      'Esa llamada está llena (máximo 6 personas)';

  @override
  String get groupCallBannerJoinFailedError => 'No se pudo unir a la llamada';

  @override
  String get groupCallBannerUnknownParticipant => 'Alguien';

  @override
  String get groupCallBannerOngoingVideoCall => 'Videollamada en curso';

  @override
  String get groupCallBannerOngoingVoiceCall => 'Llamada de voz en curso';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra en la llamada';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => 'Unirse a la llamada';

  @override
  String get groupCallBannerJoinButtonLabel => 'UNIRSE';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'UNIRSE A LA SALA';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '$count miembro',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => 'CONTRASEÑA';

  @override
  String get groupCallBannerPasswordHint => 'frase de acceso…';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Unirse';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'UNIRSE';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Cancelar';

  @override
  String get groupCallBannerCancelButtonLabel => 'cancelar';

  @override
  String get viewOnceViewerBadgeLabel => 'VER UNA VEZ';

  @override
  String get socialButtonDividerOr => 'o';

  @override
  String get socialButtonGoogleContinue => 'Continuar con Google';

  @override
  String get discoverListsPeopleTitle => 'tu gente.';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas',
      one: '$count persona',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => 'filtra tu gente…';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Borrar filtro';

  @override
  String get discoverListsNoOneYet => 'nadie todavía';

  @override
  String discoverListsNoMatches(Object query) {
    return 'nadie coincide con \"$query\"';
  }

  @override
  String get discoverListsRoomsTitle => 'tus salas.';

  @override
  String discoverListsRoomsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count salas',
      one: '$count sala',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterRoomsHint => 'filtra tus salas…';

  @override
  String get discoverListsNoRoomsYet => 'ninguna sala todavía';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return 'ninguna sala coincide con \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'LLAMADA DE VOZ';

  @override
  String get discoverListsVideoCallLabel => 'VIDEOLLAMADA';

  @override
  String get approvalGateAlreadyAskedLabel => 'YA PEDIDO';

  @override
  String get approvalGateAskGrownUpLabel => 'PREGÚNTALE A UN MAYOR';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return 'Ya preguntaste sobre $what.';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return 'Necesitas que un mayor diga que sí antes de poder $what.';
  }

  @override
  String get approvalGateDisabledBody =>
      'Un mayor ha desactivado esto por ahora.';

  @override
  String get approvalGateAlreadyAskedFooter =>
      'Les llegará un mensaje sobre esto. Vuelve a revisar pronto.';

  @override
  String get approvalGateWillNotifyFooter =>
      'Les avisaremos. Lo verás aquí cuando respondan.';

  @override
  String get approvalGateTalkToThemFooter =>
      'Puedes hablar con ellos si crees que esto debería cambiar.';

  @override
  String get approvalGateAskButton => 'PREGUNTAR';

  @override
  String get approvalGateNotNowButton => 'AHORA NO';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => 'esperando a un mayor';

  @override
  String get reportSheetTitle => 'DENUNCIAR';

  @override
  String get reportSheetSubtitle => 'cuéntanos qué pasó.';

  @override
  String get reportSheetPrivacyNote =>
      'las denuncias son privadas — no se avisa a la otra persona.';

  @override
  String get reportSheetReasonSpamLabel => 'SPAM';

  @override
  String get reportSheetReasonSpamDescription =>
      'anuncios no deseados o mensajes repetidos';

  @override
  String get reportSheetReasonHarassmentLabel => 'ACOSO';

  @override
  String get reportSheetReasonHarassmentDescription =>
      'meterse con alguien o hacer bullying';

  @override
  String get reportSheetReasonImpersonationLabel => 'SUPLANTACIÓN';

  @override
  String get reportSheetReasonImpersonationDescription =>
      'hacerse pasar por otra persona';

  @override
  String get reportSheetReasonInappropriateLabel => 'INAPROPIADO';

  @override
  String get reportSheetReasonInappropriateDescription =>
      'contenido sexual, violento o ilegal';

  @override
  String get reportSheetReasonOtherLabel => 'OTRO';

  @override
  String get reportSheetReasonOtherDescription => 'otra cosa';

  @override
  String get reportSheetOtherNoteHint => '¿qué pasó?';

  @override
  String get reportSheetSubmitSemanticLabel => 'Enviar denuncia';

  @override
  String get reportSheetSubmitButton => 'ENVIAR';

  @override
  String get reportSheetUpdateRequiredTitle => 'ACTUALIZACIÓN REQUERIDA';

  @override
  String get reportSheetUpdateAvailableTitle => 'ACTUALIZACIÓN DISPONIBLE';

  @override
  String get reportSheetUpdateMandatoryBody =>
      'Esta versión es demasiado antigua para seguir funcionando bien. Actualiza para continuar.';

  @override
  String get reportSheetUpdateAvailableBody =>
      'Hay una nueva versión de MonkeyHub disponible.';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => 'ACTUALIZAR';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'abre TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'abre la App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'abre Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'abre la página de descarga';

  @override
  String get reportSheetUpdateActionReloads => 'recarga con la nueva versión';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Más tarde';

  @override
  String get reportSheetUpdateLaterButton => 'MÁS TARDE';

  @override
  String get roomFilterBarAllChipLabel => 'todos';

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
    return 'RESPONDIENDO A $name';
  }

  @override
  String get roomCardLockedBadge => 'BLOQUEADA';

  @override
  String get roomCardTimeAgoJustNow => 'ahora mismo';

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
    return '${weeks}sem';
  }

  @override
  String roomCardStartedAgo(Object ago) {
    return 'creada hace $ago';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count dentro';
  }

  @override
  String get roomCardMessagesFadeLabel => 'mensajes se desvanecen';

  @override
  String get roomCardEnterLabel => '↗ entrar';

  @override
  String get roomCardBlockedScreenTitle => 'BLOQUEADOS';

  @override
  String get roomCardBlockedEmptyState => 'no has bloqueado a nadie.';

  @override
  String get roomCardUnblockButton => 'DESBLOQUEAR';

  @override
  String get attachmentMenuPhotoLabel => 'foto';

  @override
  String get attachmentMenuVideoLabel => 'video';

  @override
  String get attachmentMenuCameraLabel => 'cámara';

  @override
  String get attachmentMenuVoiceLabel => 'voz';

  @override
  String get attachmentMenuFileLabel => 'archivo';

  @override
  String get attachmentMenuConnectionRetrying => 'reintentando…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'no se puede conectar con el servidor · toca para reintentar';

  @override
  String get attachmentMenuConnectionReconnecting => 'reconectando…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Reintentar conexión';

  @override
  String get roomGridTileEmptyLastMessage => 'tranquilo por ahora';

  @override
  String get roomGridTileMemberCountLabel => 'DENTRO';

  @override
  String get roomGridTileThemeChipLabel => 'TEMA';

  @override
  String get bulkActionBarCancelLabel => 'CANCELAR';

  @override
  String get bulkActionBarSelectMessagesLabel => 'SELECCIONAR MENSAJES';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count SELECCIONADOS';
  }

  @override
  String get bulkActionBarForwardLabel => 'REENVIAR';

  @override
  String get bulkActionBarDeleteLabel => 'ELIMINAR';

  @override
  String get bulkActionBarJumpBackLabel => 'VOLVER';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return 'VOLVER · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel => 'Volver a donde saltaste';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return 'Volver a donde saltaste, quedan $depth';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote => 'no se le notificará.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'ahora mismo son amigos — bloquear termina la amistad, así que para reconectar más tarde tendrías que enviar una nueva solicitud de amistad.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'desaparecerá de tus búsquedas y no podrá escribirte.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'BLOQUEAR';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return '¿bloquear a $name?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'compartes $count salas con esta persona',
      one: 'compartes $count sala con esta persona',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'estas salas quedan intactas. puedes salir de cualquiera de ellas desde los ajustes de cada sala.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'BLOQUEAR';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'termina la amistad y bloquea. el historial de chat existente permanece en tu archivo.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'se oculta de las búsquedas y no puede contactarte.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'BLOQUEAR Y ELIMINAR DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'también borra tu DM con esta persona — todos los mensajes, reacciones y archivos multimedia desaparecen.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Cancelar';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'CANCELAR';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle =>
      'Mostrar llamadas en la pantalla de bloqueo';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      'Para sonar como una llamada real cuando la pantalla está apagada, MonkeyHub necesita que actives las \"notificaciones de pantalla completa\". La siguiente pantalla te lleva directo a ese interruptor.';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle =>
      'Nunca te pierdas una llamada';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      'Algunos teléfonos pausan las apps en segundo plano para ahorrar batería, lo que puede silenciar las llamadas entrantes. Permite que MonkeyHub funcione sin restricciones para que las llamadas siempre te lleguen.';

  @override
  String get bulkActionBarDialogNotNowButton => 'Ahora no';

  @override
  String get bulkActionBarDialogContinueButton => 'Continuar';

  @override
  String get reactionBubbleJumpToLatestLabel => 'IR AL ÚLTIMO';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel => 'Ir al último';

  @override
  String get reactionBubblePickerTitle => 'REACCIONAR';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'aún no hay recientes';

  @override
  String get reactionBubbleSearchHint => 'buscar emoji';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'sin coincidencias';

  @override
  String get reactionBubbleSearchBackSemanticLabel => 'Volver a los emojis';

  @override
  String get reactionBubblePasswordHint => 'contraseña';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return 'unirte a $roomName';
  }

  @override
  String get enterPublicRoomAskFailedMessage =>
      'no pudimos preguntar ahora mismo — inténtalo de nuevo';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'contraseña incorrecta';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'no se pudo unir — inténtalo de nuevo';

  @override
  String get feedBoardTitle => 'HOY';

  @override
  String feedBoardEditionLabel(Object number) {
    return 'N.º$number';
  }

  @override
  String get feedBoardHighlightsLabel => 'DESTACADOS';

  @override
  String get feedBoardHighlightsEmpty => 'hoy todavía no hay nada';

  @override
  String get feedBoardPuzzleLabel => 'EL PUZLE';

  @override
  String get feedBoardPuzzleEmpty => 'el puzle de hoy aún no está listo';

  @override
  String get feedBoardStandingsLabel => 'PUNTOS DE VIDA';

  @override
  String get feedBoardStandingsEmpty => 'hoy no hay puntos en el marcador';

  @override
  String get feedBoardActivityLabel => 'ACTIVIDAD';

  @override
  String get feedBoardActivityEmpty => 'hoy está tranquilo por ahora';

  @override
  String get feedBoardActivityNoFriends =>
      'añade a un amigo y su día aparecerá aquí';

  @override
  String get feedBoardLoadFailed =>
      'no se pudo cargar el tablero — inténtalo en un momento';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'PÚBLICA';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'PRIVADA';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'UNIDO';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'EFÍMERA · $duration';
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
      'Cualquiera puede encontrar esta sala y unirse';

  @override
  String get roomBadgePrivateTooltip =>
      'Solo por invitación: no aparece en Descubre';

  @override
  String get roomBadgeLockedTooltip =>
      'Necesitas la contraseña de la sala para entrar';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return 'Los mensajes desaparecen después de $duration';
  }

  @override
  String get roomBadgeJoinedTooltip => 'Ya estás en esta sala';

  @override
  String get roomInfoSheetDetailsLabel => 'LOS DETALLES';

  @override
  String get roomInfoSheetNoDescription => 'todavía sin descripción';

  @override
  String get roomInfoSheetCreatedLabel => 'CREADA';

  @override
  String get countBadgeCaptureProtectionLabel =>
      'PROTECCIÓN DE CAPTURA DE PANTALLA';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      'las capturas de pantalla y la grabación de pantalla aparecen en negro para el sistema.';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      'la grabación de pantalla y la duplicación de pantalla activan un escudo de privacidad sobre la app.';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      'las capturas de pantalla y grabaciones funcionan con normalidad fuera de las salas efímeras.';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      'las salas efímeras (cámara secreta) siempre tienen esto activado, pase lo que pase.';

  @override
  String get countBadgeShowPasswordTooltip => 'mostrar contraseña';

  @override
  String get countBadgeHidePasswordTooltip => 'ocultar contraseña';

  @override
  String get countBadgeProtectedLabel => 'PROTEGIDO';

  @override
  String get countBadgeCaptureShieldActiveBody =>
      'hay una grabación de pantalla o duplicación de pantalla activa.';

  @override
  String get countBadgeCaptureShieldReassurance =>
      'la grabación no puede ver tus conversaciones.';

  @override
  String get linkOpenerCouldNotOpenLink => 'No se pudo abrir el enlace';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel =>
      'Configura una frase de recuperación';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'sin frase de recuperación — no podrías volver a entrar.';

  @override
  String get destinationsChatLabel => 'Chat';

  @override
  String get destinationsChatShort => 'CHAT';

  @override
  String get destinationsDiscoverLabel => 'Descubrir';

  @override
  String get destinationsDiscoverShort => 'BUSCAR';

  @override
  String get destinationsFeedLabel => 'Feed';

  @override
  String get destinationsFeedShort => 'FEED';

  @override
  String get destinationsSettingsLabel => 'Ajustes';

  @override
  String get destinationsSettingsShort => 'AJU';

  @override
  String get familyRequestStageSenderGuardianLabel => 'esperando a los mayores';

  @override
  String get familyRequestStageRecipientLabel => 'esperando su respuesta';

  @override
  String get roomContentTabLabelMedia => 'MULTIMEDIA';

  @override
  String get roomContentTabLabelFiles => 'ARCHIVOS';

  @override
  String get roomContentTabLabelVoice => 'VOZ';

  @override
  String get roomContentTabLabelLinks => 'ENLACES';

  @override
  String get roomContentTabLabelSaved => 'GUARDADOS';

  @override
  String get roomContentTabHeaderMedia => 'multimedia';

  @override
  String get roomContentTabHeaderFiles => 'archivos';

  @override
  String get roomContentTabHeaderVoice => 'voz';

  @override
  String get roomContentTabHeaderLinks => 'enlaces';

  @override
  String get roomContentTabHeaderSaved => 'guardados';

  @override
  String get roomFacetLabelDms => 'directos';

  @override
  String get roomFacetLabelGroups => 'grupos';

  @override
  String get roomFacetLabelPublic => 'público';

  @override
  String get roomFacetLabelPrivate => 'privado';

  @override
  String get roomFacetLabelSecret => 'secreto';

  @override
  String get roomFacetLabelLocked => 'bloqueado';

  @override
  String get roomFacetLabelUnread => 'sin leer';

  @override
  String get roomFacetLabelMentions => 'menciones';

  @override
  String get settingsScreenTitle => 'AJUSTES';

  @override
  String get settingsScreenTagline => 'estilo. sensación. tú.';

  @override
  String get settingsScreenAccountHintChild =>
      'perfil · privacidad · mis mayores';

  @override
  String get settingsScreenAccountHintAdult =>
      'perfil · familia · cuentas vinculadas · privacidad';

  @override
  String get settingsScreenSectionAppearance => 'APARIENCIA';

  @override
  String get settingsScreenSectionChat => 'CHAT';

  @override
  String get settingsScreenSectionCompanions => 'COMPAÑEROS';

  @override
  String get settingsScreenSectionGeneral => 'GENERAL';

  @override
  String get settingsScreenCheckForUpdatesLabel => 'BUSCAR ACTUALIZACIONES';

  @override
  String get settingsScreenUpdateAvailableValue => 'ACTUALIZACIÓN DISPONIBLE';

  @override
  String get settingsScreenUpdateUpToDateSnackbar =>
      'Tienes la última versión.';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      'No se pueden buscar actualizaciones en esta versión.';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      'No se pudieron buscar actualizaciones. Inténtalo más tarde.';

  @override
  String get settingsScreenSectionNotifications => 'NOTIFICACIONES';

  @override
  String get reportProblemRowLabel => 'Informar de un problema';

  @override
  String get reportProblemRowValue => 'Envíanos los detalles';

  @override
  String get reportProblemIntro =>
      'Cuéntanos qué ha fallado. Los datos de tu app y tu dispositivo se incluyen automáticamente, junto con un registro técnico de lo que estaba haciendo la app: eso es lo que nos ayuda a encontrar la causa.';

  @override
  String get reportProblemDescribeLabel => 'QUÉ HA PASADO';

  @override
  String get reportProblemDescribeHint =>
      'La pantalla parpadea, los botones no responden…';

  @override
  String get reportProblemScreenshotsLabel => 'CAPTURAS';

  @override
  String get reportProblemAddScreenshot => 'Añadir captura';

  @override
  String get reportProblemDetailsLabel => 'TUS DATOS';

  @override
  String get reportProblemCopyDetails => 'Copiar datos';

  @override
  String get reportProblemCopied => 'Copiado';

  @override
  String get reportProblemSend => 'Enviar informe';

  @override
  String get reportProblemSent => 'Informe enviado. ¡Gracias!';

  @override
  String get reportProblemSendFailed =>
      'No se ha podido enviar el informe. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get reportProblemTooMany =>
      'Has enviado muchos informes en poco tiempo. Inténtalo de nuevo más tarde.';

  @override
  String get reportProblemShakeTitle => '¿Informar de un problema?';

  @override
  String get reportProblemShakeBody =>
      'Has agitado el teléfono. ¿Abrimos la pantalla de informe?';

  @override
  String get reportProblemShakeOpen => 'Informar';

  @override
  String get reportProblemShakeDismiss => 'Ahora no';

  @override
  String get settingsCallDeliveryLockScreenLabel =>
      'Llamadas en pantalla de bloqueo';

  @override
  String get settingsCallDeliveryBackgroundLabel =>
      'Actividad en segundo plano';

  @override
  String get settingsCallDeliveryStatusOff => 'Toca para permitir';

  @override
  String get settingsScreenRowTheme => 'TEMA';

  @override
  String get settingsScreenRowAppLogo => 'LOGO DE LA APP';

  @override
  String get settingsScreenRowGlass => 'VIDRIO';

  @override
  String get settingsScreenRowChatList => 'LISTA DE CHATS';

  @override
  String get settingsScreenRowNavigation => 'NAVEGACIÓN';

  @override
  String get settingsScreenRowChatStyle => 'ESTILO DE CHAT';

  @override
  String get settingsScreenRowBubbleStyle => 'ESTILO DE BURBUJA';

  @override
  String get settingsScreenRowReplyStyle => 'ESTILO DE RESPUESTA';

  @override
  String get settingsScreenValueScrollList => 'Lista deslizable';

  @override
  String get settingsScreenValueGridSheet => 'Cuadrícula';

  @override
  String get settingsScreenValueRadialOrb => 'Orbe radial';

  @override
  String get settingsScreenValueBottomPill => 'Cápsula inferior';

  @override
  String get settingsScreenValueCustom => 'Personalizado';

  @override
  String settingsScreenValueEdited(Object name) {
    return '$name · editado';
  }

  @override
  String get settingsScreenValueClassic => 'Clásico';

  @override
  String get settingsScreenValueCompact => 'Compacto';

  @override
  String get settingsScreenValueBubbleTailed => 'Con cola';

  @override
  String get settingsScreenValueBubbleSoft => 'Suave';

  @override
  String get settingsScreenValueBubblePill => 'Cápsula';

  @override
  String get settingsScreenValueBubbleSlab => 'Bloque';

  @override
  String get settingsScreenValueReplyPhantomEcho => 'Eco fantasma';

  @override
  String get settingsScreenValueReplyStickyNote => 'Nota adhesiva';

  @override
  String get settingsScreenValueReplyComicTail => 'Cola de cómic';

  @override
  String get settingsScreenValueLogoAuto => 'Automático';

  @override
  String get settingsScreenValueLogoManual => 'Manual';

  @override
  String get settingsScreenShowLinkUrlsLabel => 'MOSTRAR URLS DE ENLACES';

  @override
  String get settingsScreenLinksUrlsOnBody =>
      'las URLs completas aparecen junto a la tarjeta de vista previa';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      'solo vista previa — burbujas más limpias, toca para abrir';

  @override
  String get settingsScreenMenuBarLabel => 'ICONO EN LA BARRA DE MENÚS';

  @override
  String get settingsScreenMenuBarOnBody =>
      'MonkeyHub se queda en la barra de menús con su recuento de mensajes sin leer: haz clic para abrir la ventana';

  @override
  String get settingsScreenMenuBarOffBody =>
      'ahora mismo desactivado: el icono del Dock es la única forma de recuperar una ventana oculta';

  @override
  String get settingsScreenSectionCalls => 'LLAMADAS';

  @override
  String get settingsScreenRowVideoQuality => 'Calidad de video';

  @override
  String get settingsScreenValueVideoQualityAuto => 'Automático';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel =>
      'MOSTRAR ESTADÍSTICAS DE LA LLAMADA';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      'resolución, velocidad de bits, ping y pérdida de paquetes en vivo durante las llamadas';

  @override
  String get videoQualityScreenTitle => 'Calidad de video';

  @override
  String get videoQualityScreenSubtitle =>
      'Elige un límite de resolución para el video saliente';

  @override
  String get videoQualityScreenAutoSubtitle =>
      'Se adapta automáticamente a tu conexión';

  @override
  String get videoQualityScreenHd1080Subtitle =>
      'Full HD — más nítido, usa más datos';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD — mejor con una conexión fuerte';

  @override
  String get videoQualityScreenFootnote =>
      'La resolución real depende de las cámaras de ambos dispositivos y de las condiciones de la red.';

  @override
  String get callScreenControlOptions => 'Más';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => 'Fluctuación (jitter)';

  @override
  String get callScreenStatsLossLabel => 'Pérdida';

  @override
  String get callScreenSwapPreviewSemanticLabel => 'Cambiar vista de la cámara';

  @override
  String get callOptionsSheetTitle => 'Opciones de llamada';

  @override
  String get settingsScreenPushNotificationsLabel => 'NOTIFICACIONES PUSH';

  @override
  String get settingsScreenPushOnBody =>
      'te avisa de mensajes nuevos y solicitudes';

  @override
  String get settingsScreenPushOffBody =>
      'silencioso — solo verás las cosas cuando abras la app';

  @override
  String get settingsScreenGameRemindersLabel =>
      'RECORDATORIO DIARIO DE JUEGOS';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'un aviso al mediodía, solo si no has jugado';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'sin recordatorio — los juegos siguen ahí cuando entres';

  @override
  String get authErrorUsernameTaken => 'Ese nombre de usuario ya está en uso.';

  @override
  String get authErrorUsernameReserved =>
      'Ese nombre de usuario no está disponible. Elige otro.';

  @override
  String get authErrorDisplayNameReserved =>
      'Ese nombre no está disponible. Elige otro.';

  @override
  String get authErrorUserNotFound =>
      'No hay ninguna cuenta con ese nombre de usuario.';

  @override
  String get authErrorWrongPassword => 'Contraseña incorrecta.';

  @override
  String get authErrorInvalidRecoveryKey =>
      'Ese nombre de usuario y esa frase de recuperación no coinciden.';

  @override
  String get authErrorTooManyAttempts =>
      'Demasiados intentos. Espera 15 minutos y vuelve a intentarlo.';

  @override
  String get authErrorChildMustPair =>
      'Esa es una cuenta infantil — pídele un código de emparejamiento a un mayor.';

  @override
  String get authErrorPairingCodeExpired =>
      'Ese código caducó. Pide uno nuevo.';

  @override
  String get authErrorPairingCodeInvalid =>
      'Ese código no funcionó. Puede que ya se haya usado.';

  @override
  String get authErrorUseSocialSignIn =>
      'Esa cuenta inicia sesión con Apple o Google — usa los botones de abajo.';

  @override
  String get authErrorSocialTokenInvalid =>
      'Ese inicio de sesión no se completó. Inténtalo de nuevo.';

  @override
  String get authErrorSocialNonceMismatch =>
      'Ese inicio de sesión no se completó. Inténtalo de nuevo.';

  @override
  String get authErrorSocialMisconfig =>
      'El inicio de sesión aún no está configurado de nuestro lado. Inténtalo más tarde.';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      'Esa cuenta de Apple o Google ya está vinculada a otra cuenta de MonkeyHub.';

  @override
  String get authErrorSocialAlreadyLinked =>
      'Eso ya está vinculado a esta cuenta.';

  @override
  String get authErrorSocialNotLinked => 'Eso no está vinculado a esta cuenta.';

  @override
  String get authErrorSocialLastCredential =>
      'Esa es la única forma de entrar a esta cuenta. Primero configura una contraseña.';

  @override
  String get authErrorUsernameInvalid =>
      'Elige un nombre de usuario de entre 1 y 32 caracteres.';

  @override
  String get authErrorUsernameChangedRecently =>
      'Has cambiado tu nombre de usuario hace poco. Podrás volver a cambiarlo 30 días después del último cambio.';

  @override
  String get authErrorInboxHandleLocked =>
      'Esta cuenta recibe los informes de problemas de todos, así que su nombre de usuario es fijo.';

  @override
  String get glassKnobLabelFrost => 'ESMERILADO';

  @override
  String get glassKnobHintFrost =>
      'cuánto blanco hay sobre el cristal. bájalo para que sea transparente';

  @override
  String get glassKnobLabelBlur => 'DESENFOQUE';

  @override
  String get glassKnobHintBlur =>
      'esmerilado en la parte alta del rango, cristal transparente en la parte baja';

  @override
  String get glassKnobLabelSaturation => 'FUGA DE COLOR';

  @override
  String get glassKnobHintSaturation =>
      'cuánto color sobrevive al desenfoque. pasado el 2, se posteriza';

  @override
  String get glassKnobLabelRimOpacity => 'BORDE';

  @override
  String get glassKnobHintRimOpacity =>
      'el contorno de acento. ponlo en cero para una superficie sin borde';

  @override
  String get glassKnobLabelRimWidth => 'GROSOR DEL BORDE';

  @override
  String get glassKnobHintRimWidth => 'el grosor de ese contorno';

  @override
  String get glassKnobLabelShadowOpacity => 'SOMBRA';

  @override
  String get glassKnobHintShadowOpacity =>
      'cuánto flota la superficie sobre lo que hay detrás';

  @override
  String get glassKnobLabelShadowBlur => 'DIFUSIÓN DE SOMBRA';

  @override
  String get glassKnobHintShadowBlur => 'suave y amplia, o ajustada y dura';

  @override
  String get glassKnobLabelShadowY => 'CAÍDA DE SOMBRA';

  @override
  String get glassKnobHintShadowY => 'cuánto cae por debajo de la superficie';

  @override
  String get glassKnobLabelBarMargin => 'MARGEN LATERAL';

  @override
  String get glassKnobHintBarMargin =>
      'espacio entre la barra y el borde de la pantalla';

  @override
  String get glassKnobLabelBarBottom => 'ESPACIO INFERIOR';

  @override
  String get glassKnobHintBarBottom =>
      'cuánto flota la barra por encima del borde inferior';

  @override
  String get glassKnobLabelShellPadH => 'RELLENO DE EXTREMOS';

  @override
  String get glassKnobHintShellPadH =>
      'del borde de la barra a la primera cápsula. mantenlo pequeño, o los extremos parecen varados';

  @override
  String get glassKnobLabelShellPadV => 'RELLENO SUPERIOR';

  @override
  String get glassKnobHintShellPadV =>
      'del borde de la barra a la parte superior de la cápsula';

  @override
  String get glassKnobLabelIndicatorInset => 'MARGEN DE CÁPSULA';

  @override
  String get glassKnobHintIndicatorInset =>
      'qué tan adentro de su ranura está la cápsula de selección';

  @override
  String get glassKnobLabelSegmentPadV => 'RELLENO DE FILA';

  @override
  String get glassKnobHintSegmentPadV =>
      'el aire por encima y por debajo del ícono y su etiqueta';

  @override
  String get glassKnobLabelIconLabelGap => 'ESPACIO DEL ICONO';

  @override
  String get glassKnobHintIconLabelGap =>
      'espacio entre un icono y la palabra que tiene debajo';

  @override
  String get glassKnobLabelIconSize => 'TAMAÑO DEL ICONO';

  @override
  String get glassKnobLabelLabelSize => 'TAMAÑO DE LA ETIQUETA';

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
  String get settingsScreenRowMotion => 'MOVIMIENTO';

  @override
  String get settingsScreenValueMotionFull => 'Completo';

  @override
  String get settingsScreenValueMotionCalm => 'Tranquilo';

  @override
  String get settingsScreenValueMotionSystemFull =>
      'Igual que el dispositivo · completo';

  @override
  String get settingsScreenValueMotionSystemCalm =>
      'Igual que el dispositivo · tranquilo';

  @override
  String get motionScreenTitle => 'movimiento.';

  @override
  String get motionScreenSubtitle => 'cuánto se mueve la app';

  @override
  String get motionScreenSystemLabel => 'IGUAL QUE EL DISPOSITIVO';

  @override
  String get motionScreenSystemSubtitleFull =>
      'tu dispositivo permite animación ahora mismo';

  @override
  String get motionScreenSystemSubtitleCalm =>
      'tu dispositivo pide menos movimiento ahora mismo';

  @override
  String get motionScreenFullLabel => 'COMPLETO';

  @override
  String get motionScreenFullSubtitle => 'cada deriva, brillo y detalle';

  @override
  String get motionScreenCalmLabel => 'TRANQUILO';

  @override
  String get motionScreenCalmSubtitle =>
      'la decoración se detiene — nada más cambia';

  @override
  String get momentRailCaptureLabel => 'CAPTURAR';

  @override
  String get momentRailYouLabel => 'tú';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String get momentTagFate => 'DESTINO';

  @override
  String get momentTagJinx => 'GAFE';

  @override
  String get momentTagLuck => 'SUERTE';

  @override
  String get momentTagCalledIt => 'LO DIJE';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'qué casualidad';

  @override
  String get momentTagJinxHint => 'te lo buscaste';

  @override
  String get momentTagLuckHint => 'salió a tu favor';

  @override
  String get momentTagCalledItHint => 'lo viste venir';

  @override
  String get momentTagNpcHint => 'cerebro apagado';

  @override
  String get momentComposerTitle => '¿qué ha pasado?';

  @override
  String get momentComposerCaptionHint => 'cuenta algo';

  @override
  String get momentComposerTagPrompt => '¿has ganado un punto? añádelo';

  @override
  String get momentComposerCapture => 'cámara';

  @override
  String get momentComposerLibrary => 'galería';

  @override
  String get momentComposerRemovePhoto => 'quitar foto';

  @override
  String get momentComposerPost => 'PUBLICAR';

  @override
  String get momentComposerErrorDailyCap =>
      'ya van cinco hoy — deja algo para mañana';

  @override
  String get momentComposerErrorNotAllowed =>
      'un tutor ha desactivado compartir fotos';

  @override
  String get momentComposerErrorTooLong => 'se ha alargado un poco — recórtalo';

  @override
  String get momentComposerErrorEmpty => 'añade una foto o unas palabras';

  @override
  String get momentComposerErrorGeneric =>
      'no se pudo publicar — inténtalo de nuevo';

  @override
  String get momentViewerDelete => 'eliminar';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who ha publicado un momento';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name se ha llevado un $tag';
  }

  @override
  String get momentActivityJustNow => 'ahora';

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
      other: '$count más hoy',
      one: '1 más hoy',
    );
    return '$_temp0';
  }

  @override
  String get puzzleScreenTitle => 'el puzle.';

  @override
  String get puzzleScreenSubtitle => 'cuatro símbolos, seis intentos';

  @override
  String get puzzleSubmit => 'ADIVINAR';

  @override
  String get puzzleBackspace => 'borrar último símbolo';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'símbolo $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'resuelto en $count';
  }

  @override
  String get puzzleFailedTitle => 'sin intentos';

  @override
  String get puzzleAnswerWas => 'EL CÓDIGO ERA';

  @override
  String get puzzleShare => 'COPIAR RESULTADO';

  @override
  String get puzzleShareCopied => 'copiado — pégaselo a un amigo';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'ya has resuelto el de hoy';

  @override
  String get puzzleErrorOutOfGuesses => 'hoy no te quedan intentos';

  @override
  String get puzzleErrorGeneric => 'no se pudo enviar — inténtalo de nuevo';

  @override
  String get puzzleScoreboardLabel => 'PUNTUACIONES DE HOY';

  @override
  String get puzzleScoreboardEmpty => 'hoy todavía no ha terminado nadie';

  @override
  String get puzzleTilePlay => 'juega el puzle de hoy';

  @override
  String puzzleTileInProgress(Object count) {
    return 'quedan $count';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '#$rank de $total';
  }

  @override
  String get profileVisibilityScreenSectionFeed => 'FEED';

  @override
  String get profileVisibilityScreenFeedLabel => 'mis destacados';

  @override
  String get profileVisibilityScreenFeedDesc =>
      'si las fotos y vídeos que publicas aparecen ese día en los tableros de tus amigos';

  @override
  String get profileVisibilityScreenPuzzleLabel => 'mi puntuación del puzle';

  @override
  String get profileVisibilityScreenPuzzleDesc =>
      'si tus amigos ven cómo te ha ido en el puzle diario';

  @override
  String get profileVisibilityScreenPointsPastLabel => 'mi pasado';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      'hoy siempre se comparte con tus amigos — esto abre todo lo anterior';

  @override
  String get momentComposerVideo => 'vídeo';

  @override
  String get momentComposerErrorTooBig =>
      'ese vídeo es muy grande — 20 MB máximo';

  @override
  String get momentActivityPostedHighlightSelf => 'has publicado un momento';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'te has llevado un $tag';
  }

  @override
  String pointLineSelf(Object tag) {
    return 'tú · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => '¿qué ha pasado?';

  @override
  String get pointComposerNoteHint => 'elige una arriba y cuéntalo';

  @override
  String get pointComposerAdd => 'AÑADIR PUNTO';

  @override
  String get pointComposerAddPhoto => 'añadir foto';

  @override
  String get pointsBoardAdd => 'AÑADIR UN PUNTO';

  @override
  String get pointsExplainerOpen => '¿qué es esto?';

  @override
  String get pointsExplainerTitle => 'el juego de los puntos';

  @override
  String get pointsExplainerIntro =>
      'Una broma recurrente con marcador. Cuando te pasa algo — bueno, malo o simplemente raro — lo apuntas y queda en el tablero ese día.';

  @override
  String get pointsExplainerRuleHonour =>
      'Los puntos te los das tú. Nadie lo comprueba: esa es la gracia, y tus amigos ya te dirán si te pasas.';

  @override
  String get pointsExplainerRuleToday =>
      'Los puntos se reinician cada día. El tablero muestra hoy; tu historial es tuyo.';

  @override
  String get pointsExplainerRuleCap =>
      'Cinco de cada tipo al día, para que nadie convierta el tablero en un disparate.';

  @override
  String get pointsExplainerGotIt => 'ENTENDIDO';

  @override
  String get momentTagFateExample => 'me encontré a mi dentista en otro país';

  @override
  String get momentTagJinxExample => 'lavé el coche y llovió a las cuatro';

  @override
  String get momentTagLuckExample => 'cogí el tren por dos segundos';

  @override
  String get momentTagCalledItExample =>
      'dije que la secuela sería un fracaso, y lo fue';

  @override
  String get momentTagNpcExample => 'le dije ‘igualmente’ al camarero';

  @override
  String feedBoardEditionHint(Object number) {
    return 'día $number del feed';
  }

  @override
  String get feedBoardHighlightsHint => 'fotos y vídeos que merecen un vistazo';

  @override
  String get profileVisibilityScreenPointsLabel => 'mis puntos';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'si los puntos que apuntas aparecen en los tableros de tus amigos';

  @override
  String get momentComposerEditPhoto => 'editar recorte';

  @override
  String get archiveScreenTitle => 'tu archivo';

  @override
  String get archiveScreenEnd => 'eso es todo';

  @override
  String get archiveScreenEmptyTitle => 'aún no has guardado nada';

  @override
  String get archiveScreenEmptyBody =>
      'los momentos desaparecen de los tableros de tus amigos tras un día, pero aquí se quedan para ti.';

  @override
  String get archiveScreenEmptyFriendTitle => 'aquí no hay nada';

  @override
  String get archiveScreenEmptyFriendBody =>
      'todavía no ha publicado nada que puedas ver.';

  @override
  String get archiveScreenPrivateTitle => 'su pasado es privado';

  @override
  String get archiveScreenPrivateBody => 'aún puedes ver lo que publique hoy.';

  @override
  String get archiveScreenNotFriendTitle => 'no sois amigos';

  @override
  String get archiveScreenNotFriendBody =>
      'solo puedes mirar atrás en los días de un amigo.';

  @override
  String get archiveScreenErrorTitle => 'no se pudo cargar';

  @override
  String get archiveScreenErrorBody =>
      'comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get feedBoardOpenArchive => 'archivo';

  @override
  String get feedBoardGamesLabel => 'LOS JUEGOS';

  @override
  String get feedBoardGamesOpen => 'todos los juegos';

  @override
  String get gamesScreenTitle => 'los juegos.';

  @override
  String get gamesScreenSubtitle =>
      'cuatro tableros al día, los mismos para todos';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'quedan $count hoy',
      one: 'queda uno hoy',
      zero: 'todo hecho hoy',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => 'no se pudieron cargar los juegos de hoy';

  @override
  String get gamesRetry => 'REINTENTAR';

  @override
  String get gameQueensName => 'reinas';

  @override
  String get gameQueensRule =>
      'una corona por fila, columna y color — sin tocarse';

  @override
  String get gameTangoName => 'tango';

  @override
  String get gameTangoRule => 'tres soles, tres lunas, nunca tres seguidos';

  @override
  String get gameZipName => 'zip';

  @override
  String get gameZipRule =>
      'una línea por todas las casillas, los números en orden';

  @override
  String get gameSudokuName => 'mini sudoku';

  @override
  String get gameSudokuRule => 'del 1 al 6 una vez por fila, columna y caja';

  @override
  String get gameCodeName => 'el código';

  @override
  String get gameStatusUnplayed => 'sin jugar';

  @override
  String get gameStatusUnfinished => 'en curso';

  @override
  String get gameStatusGaveUp => 'se rindió';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'pausa';

  @override
  String get gameResume => 'continuar';

  @override
  String get gamePausedTitle => 'en pausa';

  @override
  String get gamePausedBody => 'el reloj está parado y el tablero oculto';

  @override
  String get gameUndo => 'deshacer';

  @override
  String get gameClear => 'borrar';

  @override
  String get gameHint => 'pista';

  @override
  String get gameNotes => 'notas';

  @override
  String get gameErase => 'borrar';

  @override
  String get gameAutoCross => 'cruces automáticas';

  @override
  String get gameGiveUp => 'rendirse';

  @override
  String get gameGiveUpTitle => '¿mostrar la solución?';

  @override
  String get gameGiveUpBody =>
      'el tablero de hoy se cierra y queda como no resuelto.';

  @override
  String get gameGiveUpCancel => 'SEGUIR';

  @override
  String get gameGiveUpConfirm => 'MOSTRAR';

  @override
  String gameSolvedTitle(Object time) {
    return 'resuelto en $time';
  }

  @override
  String get gameGaveUpTitle => 'la solución de hoy';

  @override
  String get gameFirstInToday => 'el primero de hoy';

  @override
  String gameRankLine(Object place, Object total) {
    return '$place de $total hasta ahora';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count errores',
      one: '1 error',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pistas',
      one: '1 pista',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => 'TIEMPOS DE HOY';

  @override
  String get gameStandingsEmpty => 'nadie lo ha terminado todavía';

  @override
  String get gameShare => 'COPIAR RESULTADO';

  @override
  String get gameShareCopied => 'copiado — pégaselo a un amigo';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => 'todos los juegos';

  @override
  String get gameElapsedSemantic => 'tiempo transcurrido';

  @override
  String get gameErrorNotSolved => 'ese tablero aún no está terminado';

  @override
  String get gameErrorAlreadyFinished => 'ya terminaste el de hoy';

  @override
  String get gameErrorNoHint => 'esta no tiene pistas';

  @override
  String get gameErrorGeneric =>
      'no se pudo conectar con los juegos — inténtalo de nuevo';

  @override
  String get gameInfoOpen => 'cómo se juega';

  @override
  String get gameInfoLabel => 'CÓMO SE JUEGA';

  @override
  String get gameInfoRulesLabel => 'LAS REGLAS';

  @override
  String get gameInfoControlsLabel => 'CONTROLES';

  @override
  String get gameInfoScoringTimed =>
      'el reloj corre mientras el tablero está en pantalla y se para si pausas o sales. el más rápido encabeza la lista de hoy.';

  @override
  String get gameInfoScoringGuesses =>
      'se puntúa por cuántos intentos necesitas, no por el tiempo.';

  @override
  String get gameInfoSameForEveryone => 'hoy todos juegan el mismo tablero.';

  @override
  String get gameInfoGotIt => 'ENTENDIDO';

  @override
  String get gameInfoQueensGoal =>
      'coloca una corona en cada fila, columna y color.';

  @override
  String get gameInfoQueensRule1 =>
      'ocho coronas: una en cada fila y una en cada columna.';

  @override
  String get gameInfoQueensRule2 =>
      'cada bloque de color lleva también exactamente una corona.';

  @override
  String get gameInfoQueensRule3 =>
      'dos coronas no pueden tocarse, ni siquiera por una esquina.';

  @override
  String get gameInfoQueensControls =>
      'toca una casilla una vez para una cruz que la descarta, otra vez para una corona y otra para vaciarla.';

  @override
  String get gameInfoTangoGoal => 'rellena la cuadrícula con soles y lunas.';

  @override
  String get gameInfoTangoRule1 =>
      'cada fila y columna lleva tres soles y tres lunas.';

  @override
  String get gameInfoTangoRule2 =>
      'nunca tres iguales seguidos, ni en horizontal ni en vertical.';

  @override
  String get gameInfoTangoRule3 =>
      'un = entre dos casillas significa que son iguales; una × que son distintas.';

  @override
  String get gameInfoTangoControls =>
      'toca una casilla para un sol, otra vez para una luna y otra para vaciarla. las casillas impresas no se mueven.';

  @override
  String get gameInfoZipGoal =>
      'dibuja una línea que pase por todas las casillas.';

  @override
  String get gameInfoZipRule1 =>
      'empieza en el 1 y termina en el último número.';

  @override
  String get gameInfoZipRule2 =>
      've tocando los números en orden por el camino.';

  @override
  String get gameInfoZipRule3 => 'cada casilla se usa exactamente una vez.';

  @override
  String get gameInfoZipControls =>
      'arrastra el dedo para dibujar. vuelve sobre la línea para borrarla.';

  @override
  String get gameInfoSudokuGoal =>
      'rellena la cuadrícula con los dígitos del 1 al 6.';

  @override
  String get gameInfoSudokuRule1 =>
      'cada fila usa del 1 al 6, una vez cada uno.';

  @override
  String get gameInfoSudokuRule2 => 'cada columna, igual.';

  @override
  String get gameInfoSudokuRule3 => 'y cada caja de 2x3, también.';

  @override
  String get gameInfoSudokuControls =>
      'toca una casilla y luego un dígito. toca el mismo dígito otra vez para borrarlo. con notas escribes marcas pequeñas a lápiz.';

  @override
  String get gameInfoCodeGoal =>
      'descubre el código oculto de cuatro símbolos.';

  @override
  String get gameInfoCodeRule1 =>
      'seis intentos, y el código nunca repite un símbolo.';

  @override
  String get gameInfoCodeRule2 =>
      'verde significa símbolo correcto en el lugar correcto.';

  @override
  String get gameInfoCodeRule3 =>
      'amarillo significa símbolo correcto en el lugar equivocado.';

  @override
  String get gameInfoCodeControls =>
      'toca símbolos para formar un intento y envíalo. el tablero te dice cuánto te acercaste.';

  @override
  String get savedMessagesTitle => 'Mensajes guardados';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'ningún chat coincide con \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'buscar chats…';

  @override
  String get pullRevealCollapseSemanticLabel =>
      'Ocultar búsqueda y chats archivados';

  @override
  String archivedChatsFolderLabel(Object count) {
    return 'chats archivados ($count)';
  }

  @override
  String get archivedChatsFolderTitle => 'chats archivados';

  @override
  String get pullRevealClearSearchSemanticLabel => 'Borrar búsqueda';

  @override
  String get archivedChatsSheetTitle => 'CHATS ARCHIVADOS';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'CHATS ARCHIVADOS · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'ya no hay nada archivado';

  @override
  String get pinnedBadgeLabel => 'FIJADA';

  @override
  String get chatRowActionMenuPinLabel => 'FIJAR CHAT';

  @override
  String get chatRowActionMenuUnpinLabel => 'DESFIJAR CHAT';

  @override
  String get chatRowActionMenuArchiveLabel => 'ARCHIVAR CHAT';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'DESARCHIVAR CHAT';

  @override
  String get messageActionMenuSaveLabel => 'GUARDAR';

  @override
  String get messageActionMenuUnsaveLabel => 'QUITAR';

  @override
  String get roomScreenSaveLimitSnack =>
      'demasiados mensajes guardados aquí — quita uno primero';

  @override
  String get roomScreenSaveFailedSnack => 'no se pudo guardar ese mensaje';

  @override
  String get threadOverlaySaveLimitToast =>
      'demasiados mensajes guardados aquí — quita uno primero';

  @override
  String get threadOverlaySaveFailedToast => 'no se pudo guardar ese mensaje';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'solo tú ves los mensajes que guardas; un mensaje fijado es lo contrario: lo ve toda la sala.';

  @override
  String get roomInfoScreenOwnerBadgeNote =>
      'la pequeña medalla junto a un nombre indica quién creó esta sala.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return 'Ir al mensaje guardado de $name';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return 'Quitar de guardados el mensaje de $name';
  }

  @override
  String get muteSheetTitle => 'SILENCIAR CHAT';

  @override
  String get muteSheetSubtitle => 'Elige qué se calla y durante cuánto tiempo.';

  @override
  String get muteSheetNotificationsTitle => 'Notificaciones';

  @override
  String get muteSheetNotificationsSub => 'Sin aviso, sin sonido';

  @override
  String get muteSheetBadgesTitle => 'Contador de no leídos';

  @override
  String get muteSheetBadgesSub =>
      'Sin número en el chat, nada en el icono de la app';

  @override
  String get muteSheetDurationLabel => 'DURANTE CUÁNTO TIEMPO';

  @override
  String get muteDurationHour => '1 hora';

  @override
  String get muteDurationEightHours => '8 horas';

  @override
  String get muteDurationWeek => '1 semana';

  @override
  String get muteDurationAlways => 'Siempre';

  @override
  String get muteSheetConfirmButton => 'SILENCIAR';

  @override
  String get muteSheetSaveButton => 'GUARDAR';

  @override
  String get muteSheetUnmuteButton => 'REACTIVAR';

  @override
  String get muteSummaryAll =>
      'Nada de este chat te llega: ni notificaciones ni contador de no leídos.';

  @override
  String get muteSummaryNotificationsOnly =>
      'Sin notificaciones. El contador de no leídos sigue subiendo.';

  @override
  String get muteSummaryBadgesOnly =>
      'Sin contador de no leídos. Las notificaciones siguen llegando.';

  @override
  String get muteSummaryNothingPicked =>
      'Elige al menos una cosa que silenciar.';

  @override
  String muteUntilSentence(String when) {
    return 'Hasta $when.';
  }

  @override
  String get muteUntilAlwaysSentence => 'Hasta que vuelvas a activarlo.';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String get mutedBadgeLabel => 'SILENCIADO';

  @override
  String get chatRowActionMenuMuteLabel => 'SILENCIAR CHAT';

  @override
  String get chatRowActionMenuUnmuteLabel => 'REACTIVAR CHAT';

  @override
  String get roomInfoScreenMuteLabel => 'SILENCIO';

  @override
  String get roomInfoScreenNotMutedRow => 'Sin silenciar';

  @override
  String get attachmentMenuLocationLabel => 'ubicación';

  @override
  String get locationSheetSendCurrent => 'Enviar ubicación actual';

  @override
  String get locationSheetSendCurrentDetail => 'Dónde estás ahora mismo';

  @override
  String get locationSheetLiveHeading => 'COMPARTIR EN DIRECTO';

  @override
  String get locationSheetLiveDetail => 'Se detiene solo';

  @override
  String get locationShareFor15Minutes => 'Durante 15 minutos';

  @override
  String get locationShareFor1Hour => 'Durante 1 hora';

  @override
  String get locationShareFor8Hours => 'Durante 8 horas';

  @override
  String get locationBubbleOpenInMaps => 'Abrir en mapas';

  @override
  String get locationBubbleLiveBadge => 'EN VIVO';

  @override
  String get locationBubbleEndedBadge => 'FINALIZADO';

  @override
  String locationBubbleLiveUntil(String time) {
    return 'En directo hasta las $time';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return 'La ubicación en directo terminó a las $time';
  }

  @override
  String get locationBubbleNoRecentUpdate => 'Sin actualizaciones recientes';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters m';
  }

  @override
  String get locationBubbleStopSharing => 'Dejar de compartir';

  @override
  String get locationBubbleUnavailable => 'Ubicación no disponible';

  @override
  String get locationBubbleNoMapsApp =>
      'No hay ninguna app de mapas para abrir esto';

  @override
  String get locationBubbleCoordinatesCopied => 'Coordenadas copiadas';

  @override
  String get locationCouldNotGetFix => 'No se pudo obtener tu ubicación';

  @override
  String get locationCouldNotStartLiveShare =>
      'No se pudo iniciar la ubicación en directo';

  @override
  String get locationPermissionNeeded =>
      'Se necesita acceso a la ubicación para compartir dónde estás';

  @override
  String get locationPermissionBlockedTitle =>
      'El acceso a la ubicación está desactivado';

  @override
  String get locationPermissionBlockedBody =>
      'MonkeyHub no puede volver a pedirlo desde aquí. Activa el acceso a la ubicación para MonkeyHub en Ajustes.';

  @override
  String get locationServicesOffTitle =>
      'Los servicios de ubicación están desactivados';

  @override
  String get locationServicesOffBody =>
      'La ubicación está desactivada en este dispositivo. Actívala en Ajustes para compartir dónde estás.';

  @override
  String get locationOpenSettings => 'Abrir ajustes';

  @override
  String get locationBackgroundSheetTitle => 'Si tu teléfono se reinicia';

  @override
  String get locationBackgroundSheetBody =>
      'Tu ubicación en directo ya sigue funcionando cuando sales de MonkeyHub. El acceso en segundo plano cubre lo demás: un reinicio, un cierre forzado, un teléfono que se queda sin batería y vuelve.';

  @override
  String get locationBackgroundSheetKeepRunning => 'Que se reanude sola';

  @override
  String get locationBackgroundSheetKeepRunningDetail =>
      'Tu teléfono te pedirá permiso';

  @override
  String get locationBackgroundSheetAppOnly => 'Que se quede parada';

  @override
  String get locationBackgroundSheetAppOnlyDetail => 'Nada más que permitir';

  @override
  String get locationServiceNotificationTitle =>
      'Compartiendo tu ubicación en directo';

  @override
  String get locationServiceNotificationBody =>
      'Toca para abrir el chat o pulsa Detener para terminar ya';

  @override
  String get childPolicyScreenLocationLabel => 'Ubicación';

  @override
  String get childPolicyScreenLocationOnDesc =>
      'Puede compartir dónde está, incluso en directo hasta 8 horas';

  @override
  String get childPolicyScreenLocationOffDesc =>
      'No puede compartir dónde está';

  @override
  String get roomInfoScreenSavedMessagesLabel => 'MENSAJES GUARDADOS';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      'solo tú puedes verlos, y solo desde esta sala. tu chat Mensajes guardados es aparte.';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      'todavía no hay nada guardado. mantén pulsado un mensaje y elige GUARDAR.';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return 'Ir al mensaje guardado de $name';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return 'Quitar de guardados el mensaje de $name';
  }

  @override
  String get composerCaptureCameraModeLabel => 'cámara';

  @override
  String get composerCaptureVoiceModeLabel => 'mensaje de voz';

  @override
  String get composerCaptureVideoNoteModeLabel => 'nota de vídeo';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode. Desliza con dos dedos o usa las flechas para cambiar de modo.';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '$mode seleccionado';
  }

  @override
  String get composerCaptureRecordingAnnouncement => 'Grabación iniciada';

  @override
  String get composerCaptureLockedAnnouncement =>
      'Grabación bloqueada. Manos libres.';

  @override
  String get composerCaptureCancelledAnnouncement => 'Grabación descartada';

  @override
  String get composerCaptureSentAnnouncement => 'Grabación enviada';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return 'Grabando, $elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint =>
      'Mantén presionado para grabar, desliza para cambiar';

  @override
  String get composerCaptureTapForCameraHint =>
      'Toca para la cámara, desliza para cambiar';

  @override
  String get composerCaptureSlideToCancelHint => 'desliza para cancelar';

  @override
  String get composerCaptureReleaseToCancelHint => 'suelta para cancelar';

  @override
  String get composerCaptureTapToSendHint => 'toca para enviar';

  @override
  String get composerCaptureSendingLabel => 'enviando…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return 'quedan $seconds s';
  }

  @override
  String get composerCaptureCancelLabel => 'descartar grabación';

  @override
  String get composerCaptureSendLabel => 'enviar grabación';

  @override
  String get composerCaptureLockLabel =>
      'desliza hacia arriba para bloquear la grabación';

  @override
  String get composerCaptureMicPermissionTitle => 'Se necesita el micrófono';

  @override
  String get composerCaptureMicPermissionBody =>
      'MonkeyHub necesita tu micrófono para grabar un mensaje de voz. Actívalo en Ajustes e inténtalo de nuevo.';

  @override
  String get composerCaptureCameraPermissionTitle => 'Se necesita la cámara';

  @override
  String get composerCaptureCameraPermissionBody =>
      'MonkeyHub necesita tu cámara y tu micrófono para grabar una nota de vídeo. Actívalos en Ajustes e inténtalo de nuevo.';

  @override
  String get composerCaptureRestrictedBody =>
      'La grabación está desactivada por una restricción de este dispositivo.';

  @override
  String get composerCaptureOpenSettingsLabel => 'Abrir Ajustes';

  @override
  String get composerCaptureUnavailableSnack =>
      'La grabación no está disponible en este dispositivo.';

  @override
  String get composerCaptureInterruptedSnack => 'Grabación detenida.';

  @override
  String get composerCaptureStorageSnack =>
      'No se pudo guardar la grabación. Comprueba el espacio libre.';

  @override
  String get videoNoteMessagePlayLabel => 'reproducir nota de vídeo';

  @override
  String get videoNoteMessagePauseLabel => 'pausar nota de vídeo';

  @override
  String get videoNoteMessageLoadingLabel => 'cargando nota de vídeo';

  @override
  String get videoNoteMessageUnavailableLabel => 'nota de vídeo no disponible';

  @override
  String get videoNoteMessageRetryLabel => 'reintentar nota de vídeo';

  @override
  String get videoNoteMessageRetryHint => 'toca para reintentar';

  @override
  String get videoNoteMessageDiscardLabel => 'descartar nota de vídeo';

  @override
  String get attachmentMenuVideoNoteLabel => 'nota de vídeo';

  @override
  String get cameraScreenPhotoModeLabel => 'FOTO';

  @override
  String get cameraScreenVideoModeLabel => 'VÍDEO';

  @override
  String get cameraScreenStartRecordingLabel => 'empezar a grabar';

  @override
  String get cameraScreenStopRecordingLabel => 'detener la grabación';

  @override
  String get cameraScreenVideoFailedSnack => 'No se pudo grabar ese vídeo.';

  @override
  String get scheduleSheetTitle => 'PROGRAMAR MENSAJE';

  @override
  String get scheduleSheetSubtitle => 'Escríbelo ahora. Sale cuando tú digas.';

  @override
  String get scheduleSheetWhenLabel => 'CUÁNDO';

  @override
  String get schedulePresetInAnHour => 'En 1 hora';

  @override
  String get schedulePresetInEightHours => 'En 8 horas';

  @override
  String get schedulePresetTomorrowMorning => 'Mañana por la mañana';

  @override
  String get schedulePresetThisMorning => 'Esta mañana';

  @override
  String get schedulePresetInAWeek => 'En 1 semana';

  @override
  String get scheduleSheetCustomChip => 'Elegir fecha';

  @override
  String get scheduleSheetConfirmButton => 'PROGRAMAR';

  @override
  String get scheduleSheetSaveButton => 'GUARDAR';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'Se envía $when.';
  }

  @override
  String scheduleWhenToday(String time) {
    return 'hoy a las $time';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return 'mañana a las $time';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return 'el $date a las $time';
  }

  @override
  String get scheduleTimePickerTitle => 'ELIGE FECHA Y HORA';

  @override
  String get scheduleTimePickerBack => 'Opciones rápidas';

  @override
  String get scheduleTimePickerToday => 'Hoy';

  @override
  String get scheduleTimePickerTomorrow => 'Mañana';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PROGRAMADOS',
      one: '1 PROGRAMADO',
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
      other: '$count mensajes pendientes de enviar. Toca para verlos.',
      one: '1 mensaje pendiente de enviar. Toca para verlo.',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => 'REVÍSALO';

  @override
  String get scheduledListTitle => 'PROGRAMADOS';

  @override
  String get scheduledListSubtitle => 'Solo tú los ves hasta que se envíen.';

  @override
  String get scheduledListEmpty => 'Aquí no hay nada pendiente de enviar.';

  @override
  String get scheduledListSendNow => 'Enviar ahora';

  @override
  String get scheduledListChangeTime => 'Cambiar la hora';

  @override
  String get scheduledListEdit => 'Editar texto';

  @override
  String get scheduledListDelete => 'Eliminar';

  @override
  String get scheduledListSending => 'Enviando…';

  @override
  String get scheduledListFailedTitle => 'No se pudo enviar';

  @override
  String get scheduledListRetry => 'Reintentar';

  @override
  String get scheduleErrorOutOfRange =>
      'Elige una hora entre dos minutos y un año a partir de ahora.';

  @override
  String get scheduleErrorTooMany =>
      'Hay demasiados mensajes pendientes aquí. Envía o elimina algunos primero.';

  @override
  String get scheduleErrorNotInEphemeral =>
      'Los mensajes de este chat se desvanecen solos, así que no se pueden programar.';

  @override
  String get scheduleErrorNotMember => 'Ya no estás en este chat.';

  @override
  String get scheduleErrorBlocked =>
      'Primero tendrás que desbloquear a esta persona.';

  @override
  String get scheduleErrorGeneric => 'No ha funcionado. Inténtalo de nuevo.';

  @override
  String get scheduleEditTitle => 'EDITAR MENSAJE';

  @override
  String get composerScheduleAction => 'Programar este mensaje';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes pendientes de enviar',
      one: '1 mensaje pendiente de enviar',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => 'MOSTRAR COMO';

  @override
  String get scheduledIndicatorPill => 'Píldora';

  @override
  String get scheduledIndicatorBadge => 'Insignia';

  @override
  String get scheduledIndicatorBoth => 'Ambos';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes ya en espera',
      one: '1 mensaje ya en espera',
      zero: 'Nada pendiente de enviar',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => 'Cómo se muestran';

  @override
  String get scheduledIndicatorPillSub =>
      'Una barra sobre el cuadro de texto. Tócala para verlos.';

  @override
  String get scheduledIndicatorBadgeSub =>
      'Un número en el botón de enviar. No se ve nada hasta que empiezas a escribir.';

  @override
  String get scheduledIndicatorBothSub =>
      'La barra, más el número mientras escribes.';

  @override
  String get scheduledBack => 'Atrás';

  @override
  String get serverScreenTitle => 'servidor.';

  @override
  String get serverScreenSubtitle => 'donde viven tu cuenta y tus mensajes';

  @override
  String get serverOnboardingTitle => 'elige un servidor.';

  @override
  String get serverOnboardingSubtitle =>
      'esta versión no trae ninguno: apúntala al tuyo';

  @override
  String get serverStatusConnected => 'CONECTADO';

  @override
  String get serverStatusDisconnected => 'SIN CONEXIÓN';

  @override
  String get serverBadgeDefault => 'PREDETERMINADO';

  @override
  String get serverBadgeSelfHosted => 'AUTOALOJADO';

  @override
  String get serverNoneConfigured => 'Aún sin servidor';

  @override
  String get serverActiveNowLabel => 'EN USO';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'El servidor con el que vino esta app.';

  @override
  String get serverChoiceOwn => 'Tu propio servidor';

  @override
  String get serverChoiceOwnSub => 'Un backend Convex que gestionas tú.';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => 'PEGAR';

  @override
  String get serverProblemMalformed => 'Eso no es una dirección web.';

  @override
  String get serverProblemBadScheme => 'Empieza con https:// o http://.';

  @override
  String get serverProblemNoHost =>
      'Añade la dirección de tu servidor después de https://.';

  @override
  String get serverProblemCredentials =>
      'Quita el usuario y la contraseña de la dirección.';

  @override
  String get serverInsecureTitle => 'SIN CIFRAR';

  @override
  String get serverInsecureBody =>
      'Los teléfonos bloquean http sin cifrar, así que esta dirección no conectará en iOS ni Android. Usa https o llega a tu servidor por un túnel.';

  @override
  String get serverTestCta => 'PROBAR CONEXIÓN';

  @override
  String get serverTestingLabel => 'Probando…';

  @override
  String get serverCheckReachable => 'Algo respondió';

  @override
  String get serverCheckConvex => 'Es un servidor Convex';

  @override
  String get serverCheckApp => 'Tiene MonkeyHub desplegado';

  @override
  String get serverResultUnreachable => 'Nada respondió en esa dirección.';

  @override
  String get serverResultNotConvex =>
      'Algo respondió, pero no es un servidor Convex.';

  @override
  String get serverResultNotThisApp =>
      'Es un servidor Convex, pero MonkeyHub no está desplegado ahí.';

  @override
  String get serverResultServerError =>
      'El servidor respondió, pero con un error.';

  @override
  String get serverResultReady => 'Listo para conectar.';

  @override
  String get serverConnectCta => 'CONECTAR';

  @override
  String get serverConnectAnywayCta => 'CONECTAR IGUALMENTE';

  @override
  String get serverAlreadyConnectedCta => 'YA CONECTADO';

  @override
  String get serverUseDefaultCta => 'USAR EL SERVIDOR PREDETERMINADO';

  @override
  String get serverChangeCta => 'CAMBIAR SERVIDOR';

  @override
  String get serverAdvancedLabel => 'AVANZADO';

  @override
  String get serverSiteUrlExplain =>
      'La mayoría de los servidores responden todo en una sola dirección. Rellena esto solo si el tuyo sirve las acciones HTTP en otra.';

  @override
  String get serverSiteUrlHint => 'Igual que arriba';

  @override
  String get serverSectionRecent => 'RECIENTES';

  @override
  String get serverRecentForget => 'Olvidar este servidor';

  @override
  String get serverSwitchWarningTitle => 'CAMBIAR CIERRA TU SESIÓN';

  @override
  String get serverSwitchWarningBody =>
      'Las cuentas y los chats pertenecen a un solo servidor. Este dispositivo cierra sesión, borra lo que descargó y empieza de cero. No se borra nada en ninguno de los dos servidores.';

  @override
  String get serverSwitchRolledBackTitle => 'NO SE PUDO CONECTAR';

  @override
  String serverSwitchRolledBackBody(String host) {
    return '$host no respondió, así que nada cambió. Tendrás que iniciar sesión otra vez.';
  }

  @override
  String get serverSwitchStrandedBody =>
      'Ninguno de los dos servidores conectó. Revisa la dirección e inténtalo otra vez.';

  @override
  String get serverSwitchRefusedBody =>
      'Este dispositivo está configurado para un menor y no puede cambiar de servidor.';

  @override
  String serverChipSemantics(String server) {
    return 'Cambiar de servidor. Ahora: $server.';
  }

  @override
  String get serverValueDefault => 'Predeterminado';

  @override
  String get settingsScreenRowServer => 'SERVIDOR';

  @override
  String get settingsScreenSectionAdvanced => 'AVANZADO';

  @override
  String get serverSwitchingLabel => 'Cambiando de servidor…';

  @override
  String get serverBadgeHomeserver => 'Sirviendo desde el homeserver';

  @override
  String get serverBadgeHomeserverSemantics =>
      'Sirviendo desde el homeserver. Toca para ver los detalles.';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'Servidor autoalojado: $server. Toca para ver los detalles.';
  }

  @override
  String get serverRoleHomeserverTitle => 'Funcionando en el homeserver';

  @override
  String get serverRoleHomeserverBody =>
      'Quienes gestionan MonkeyHub han movido el tráfico a su servidor doméstico durante un tiempo. Todo funciona igual: es algo intencionado, no una avería.';

  @override
  String get serverRoleHomeserverWarnData =>
      'Puede que lo que envíes mientras esto esté activo no siga aquí cuando el tráfico vuelva.';

  @override
  String get serverRoleHomeserverWarnSpeed =>
      'Una conexión doméstica es más lenta que la habitual, así que puede ir con retraso.';

  @override
  String get serverRoleHomeserverWarnAuto =>
      'No tienes que hacer nada. La app vuelve sola.';

  @override
  String get serverRoleSelfHostedTitle => 'Tu propio servidor';

  @override
  String get serverRoleSelfHostedBody =>
      'Este dispositivo apunta a un servidor tuyo. Cámbialo en Ajustes › Avanzado › Servidor.';

  @override
  String get serverValueHomeserver => 'Homeserver, por ahora';

  @override
  String get serverChoiceCloudSubHomeserver =>
      'Se está sirviendo desde el homeserver por un tiempo.';

  @override
  String get serverDirectiveChangedToast =>
      'Tu servidor ha cambiado. Reconectando…';

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
  String get roomAdminActionViewProfile => 'Ver perfil';

  @override
  String get roomAdminActionPromote => 'Hacer admin';

  @override
  String get roomAdminActionPromoteSub =>
      'Podrá invitar, expulsar y editar el grupo';

  @override
  String get roomAdminActionDemote => 'Quitar admin';

  @override
  String get roomAdminActionDemoteSub => 'Sigue en el grupo como miembro';

  @override
  String get roomAdminActionTransfer => 'Transferir propiedad';

  @override
  String get roomAdminActionTransferSub => 'Tú te quedas como admin';

  @override
  String get roomAdminActionRemove => 'Expulsar del grupo';

  @override
  String get roomAdminAddFriendsRow => 'Añadir amigos';

  @override
  String get roomAdminInviteLinkRow => 'Enlace de invitación';

  @override
  String get roomAdminJoinRequestsRow => 'Solicitudes para unirse';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return '¿Entregar el grupo a $name?';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      'Pasa a ser el propietario y puede borrar el grupo. Tú te quedas como admin, y solo esa persona puede devolvértelo.';

  @override
  String get roomAdminTransferConfirmCta => 'TRANSFERIR';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return '¿Expulsar a $name?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'Pierde el acceso al grupo y a todo lo que hay dentro. Se le puede volver a invitar, o puede entrar con el enlace.';

  @override
  String get roomAdminRemoveConfirmCta => 'EXPULSAR';

  @override
  String get roomAdminGenericError => 'No ha funcionado. Inténtalo de nuevo.';

  @override
  String get roomAdminErrorNotMember => 'Ya no estás en este grupo.';

  @override
  String get roomAdminErrorNotAdmin => 'Eso solo lo pueden hacer los admins.';

  @override
  String get roomAdminErrorNotOwner =>
      'Eso solo lo puede hacer el propietario del grupo.';

  @override
  String get roomAdminErrorNotGroup =>
      'En un chat directo no hay nada que administrar.';

  @override
  String get roomAdminErrorOwnerImmutable =>
      'El rol del propietario solo cambia transfiriendo el grupo.';

  @override
  String get roomAdminErrorInvitesLocked =>
      'A este grupo solo pueden invitar los admins.';

  @override
  String get roomInviteSheetTitle => 'Enlace de invitación';

  @override
  String get roomInviteSheetBlurb =>
      'Un enlace y un código, y son lo mismo. En cuanto creas uno nuevo, el anterior deja de funcionar.';

  @override
  String get roomInviteNoLinkYet =>
      'Este grupo todavía no tiene enlace de invitación.';

  @override
  String get roomInviteCreateButton => 'CREAR ENLACE';

  @override
  String get roomInviteRegenerateButton => 'NUEVO ENLACE';

  @override
  String get roomInviteRevokeButton => 'REVOCAR ENLACE';

  @override
  String get roomInviteCopyLink => 'Copiar enlace';

  @override
  String get roomInviteCopyCode => 'Copiar código';

  @override
  String get roomInviteShare => 'Compartir';

  @override
  String get roomInviteLinkCopied => 'Enlace copiado.';

  @override
  String get roomInviteCodeCopied => 'Código copiado.';

  @override
  String get roomInviteRegenerateHeadline => '¿Crear un enlace nuevo?';

  @override
  String get roomInviteRegenerateBody =>
      'El enlace y el código actuales dejan de funcionar al instante, en todos los sitios donde se hayan compartido. Quien ya esté en el grupo se queda.';

  @override
  String get roomInviteRegenerateConfirm => 'NUEVO ENLACE';

  @override
  String get roomInviteRevokeHeadline => '¿Revocar este enlace?';

  @override
  String get roomInviteRevokeBody =>
      'Nadie nuevo podrá entrar con el enlace hasta que crees otro. Quien ya esté en el grupo se queda.';

  @override
  String get roomInviteRevokeConfirm => 'REVOCAR';

  @override
  String get roomInviteLimitsLabel => 'LÍMITES';

  @override
  String get roomInviteExpiryLabel => 'Caduca en';

  @override
  String get roomInviteMaxUsesLabel => 'Número de usos';

  @override
  String get roomInviteNeverExpires => 'Nunca';

  @override
  String get roomInviteUnlimited => 'Sin límite';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count h';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count d';
  }

  @override
  String get roomInviteLimitsApplyToNew => 'Se aplican al enlace que crees.';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      'Se aplican al próximo enlace. El de arriba conserva los límites con los que se creó.';

  @override
  String get roomInvitePermissionsLabel => 'PERMISOS';

  @override
  String get roomInviteMembersCanInviteLabel =>
      'Los miembros pueden invitar amigos';

  @override
  String get roomInviteMembersCanInviteSub =>
      'Desactívalo y solo los admins podrán traer gente';

  @override
  String get roomInviteApprovalLabel => 'Aprobar cada entrada';

  @override
  String get roomInviteApprovalSub =>
      'Quien tenga el enlace lo pide primero, y un admin dice sí o no';

  @override
  String roomInviteUsesCount(Object count) {
    return 'Usado $count veces';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$used de $max usos';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return 'caduca el $date';
  }

  @override
  String get roomInviteDeadExpired =>
      'Este enlace ha caducado. Crea uno nuevo.';

  @override
  String get roomInviteDeadExhausted =>
      'Este enlace se ha quedado sin usos. Crea uno nuevo.';

  @override
  String get roomInviteDeadRevoked => 'Este enlace fue revocado.';

  @override
  String get roomInviteDeadGeneric => 'Este enlace ya no funciona.';

  @override
  String get roomInviteFriendsTitle => 'Añadir amigos';

  @override
  String get roomInviteFriendsBlurb =>
      'Recibirán una invitación y podrán aceptarla o rechazarla.';

  @override
  String get roomInviteFriendsSearchHint => 'Buscar amigos';

  @override
  String get roomInviteFriendsInviteButton => 'INVITAR';

  @override
  String get roomInviteFriendsSent => 'Invitado';

  @override
  String get roomInviteFriendsEmpty =>
      'Todos tus amigos ya están aquí o ya están invitados.';

  @override
  String get roomInviteFriendsNoMatch => 'Ningún amigo coincide con eso.';

  @override
  String get roomInviteFriendsDone => 'LISTO';

  @override
  String get roomJoinRequestsTitle => 'Solicitudes para unirse';

  @override
  String get roomJoinRequestsBlurb =>
      'Estas personas han usado el enlace. No ven nada del grupo hasta que digas que sí.';

  @override
  String get roomJoinRequestsEmpty => 'No hay nadie esperando.';

  @override
  String get roomJoinRequestsApprove => 'DEJAR ENTRAR';

  @override
  String get roomJoinRequestsReject => 'NO';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return 'INVITADOS · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian =>
      'esperando a un padre o madre';

  @override
  String get roomInfoScreenInviteWithdraw => 'RETIRAR';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return 'de $inviter · $members miembros';
  }

  @override
  String get roomInvitationCardJoin => 'UNIRME';

  @override
  String get discoverScreenJoinByCodeTitle => 'unirse con un código';

  @override
  String get discoverScreenJoinByCodeSubtitle =>
      'abre un grupo que alguien te ha compartido';

  @override
  String get joinInviteTitle => 'Unirse a un grupo';

  @override
  String get joinInviteBack => 'Atrás';

  @override
  String get joinInviteCodeBlurb =>
      'Introduce el código que te han compartido. Un enlace de invitación completo también vale.';

  @override
  String get joinInviteCodeLabel => 'Código de invitación';

  @override
  String get joinInviteCodeHint => 'Pega el enlace o escribe el código';

  @override
  String get joinInviteCodeInvalid => 'Eso no parece un código de invitación.';

  @override
  String get joinInviteLookupButton => 'CONTINUAR';

  @override
  String get joinInviteLookupFailed =>
      'No se ha podido comprobar el código. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count miembros';
  }

  @override
  String get joinInviteJoinButton => 'UNIRME AL GRUPO';

  @override
  String get joinInviteRequestButton => 'PEDIR ENTRAR';

  @override
  String get joinInviteOpenNote =>
      'Podrás ver los mensajes del grupo en cuanto entres.';

  @override
  String get joinInviteApprovalNote =>
      'Un admin tiene que decir que sí antes de que puedas ver nada aquí dentro.';

  @override
  String get joinInviteOpenRoom => 'ABRIR GRUPO';

  @override
  String get joinInvitePendingHeadline => 'Esperando a un admin';

  @override
  String get joinInvitePendingBody =>
      'Recibirás una notificación en cuanto alguien responda.';

  @override
  String get joinInviteBadLinkHeadline => 'Esta invitación no funciona';

  @override
  String get joinInviteBadLinkBody =>
      'Revisa el código o pide un enlace nuevo.';

  @override
  String get joinInviteExpiredHeadline => 'Esta invitación ha caducado';

  @override
  String get joinInviteExpiredBody =>
      'Pídele un enlace nuevo a quien te invitó.';

  @override
  String get joinInviteExhaustedHeadline => 'Esta invitación está agotada';

  @override
  String get joinInviteExhaustedBody =>
      'Estaba configurada para funcionar un número limitado de veces. Pide otra.';

  @override
  String get joinInviteRevokedHeadline => 'Esta invitación fue sustituida';

  @override
  String get joinInviteRevokedBody =>
      'Un admin creó un enlace nuevo. Pídele el actual.';

  @override
  String get joinInviteWrongServerHeadline =>
      'Esta invitación es de otro servidor';

  @override
  String joinInviteWrongServerBody(Object host) {
    return 'Pertenece a $host. Tu cuenta está en otro servidor, así que este grupo no es accesible desde aquí.';
  }

  @override
  String get roomInviteErrorNotFound =>
      'Ese código de invitación no coincide con nada.';

  @override
  String get roomInviteErrorRevoked =>
      'Esa invitación fue sustituida. Pide el enlace actual.';

  @override
  String get roomInviteErrorExpired => 'Esa invitación ha caducado.';

  @override
  String get roomInviteErrorExhausted => 'Esa invitación está agotada.';

  @override
  String get roomInviteErrorAlreadyMember => 'Ya está en este grupo.';

  @override
  String get roomInviteErrorAlreadyInvited => 'Ya se le ha invitado.';

  @override
  String get roomInviteErrorSelf => 'Ya estás en este grupo.';

  @override
  String get roomInviteErrorInvitationGone => 'Esa invitación ya no está.';

  @override
  String get roomInviteErrorRequestPending =>
      'Ya has pedido entrar. Un admin responderá.';

  @override
  String get roomInviteErrorRequestGone =>
      'Alguien ya respondió a esa solicitud.';

  @override
  String get roomInviteErrorRoomPrivate =>
      'A este grupo solo se entra con invitación.';

  @override
  String get roomInviteErrorInvalidLimits => 'Esos límites no son válidos.';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$child quiere invitar a $other a $room';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$other ha invitado a $child a $room';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      'La invitación se envía, y la otra persona sigue decidiendo.';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$child verá la invitación y podrá aceptarla o rechazarla. Aprobarla también le da acceso a ese grupo si acepta.';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      'No puedes expulsarte a ti mismo. Sal del grupo en su lugar.';

  @override
  String get roomAdminActionMessage => 'Enviar mensaje';

  @override
  String get roomAdminActionVoiceCall => 'Llamada de voz';

  @override
  String get roomAdminActionVideoCall => 'Videollamada';

  @override
  String get roomAdminYouSuffix => 'tú';

  @override
  String get roomInfoScreenSetPasswordButton => 'PONER';

  @override
  String get roomInfoScreenPasswordSetSnackbar => 'Contraseña establecida.';

  @override
  String get roomInfoScreenPasswordSetState => 'Con contraseña';

  @override
  String get roomInfoScreenPasswordUnsetState => 'Sin contraseña';

  @override
  String get roomInfoScreenPasswordCancel => 'Cancelar';

  @override
  String get roomInfoScreenEditSave => 'Guardar';

  @override
  String get roomInfoScreenEditCancel => 'Cancelar';

  @override
  String get roomInviteRotatedToast =>
      'Enlace nuevo creado. El anterior ya no funciona.';

  @override
  String get roomInviteRevokedToast => 'Enlace de invitación revocado.';

  @override
  String get newChatMenuTitle => 'Nuevo chat';

  @override
  String get newChatMenuCreateTitle => 'Crear una sala';

  @override
  String get newChatMenuCreateSub => 'Empieza un grupo e invita a gente';

  @override
  String get newChatMenuJoinTitle => 'Unirse con un código';

  @override
  String get newChatMenuJoinSub => 'Abre un grupo que alguien te ha compartido';

  @override
  String get shareSheetTitle => 'COMPARTIR CON';

  @override
  String get shareSheetSuggestedHeading => 'SUGERIDOS';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos adjuntos',
      one: '1 archivo adjunto',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos superan el límite de $size y se han omitido',
      one: '1 archivo supera el límite de $size y se ha omitido',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return 'Enviar a $title';
  }

  @override
  String get settingsScreenRowSpeakerColors => 'COLORES POR PERSONA';

  @override
  String get settingsScreenValueSpeakerOff => 'Desactivado';

  @override
  String get settingsScreenValueSpeakerName => 'Nombres';

  @override
  String get settingsScreenValueSpeakerBubble => 'Nombres + burbujas';

  @override
  String get speakerColorScreenTitle => 'colores por persona.';

  @override
  String get speakerColorScreenSubtitle => 'quién lo dijo, sin leer el nombre';

  @override
  String get speakerColorScreenOffLabel => 'DESACTIVADO';

  @override
  String get speakerColorScreenOffDescription =>
      'todos en la sala escriben con la misma tinta.';

  @override
  String get speakerColorScreenNameLabel => 'NOMBRES';

  @override
  String get speakerColorScreenNameDescription =>
      'cada persona tiene un color propio, en su nombre y alrededor de su cara.';

  @override
  String get speakerColorScreenBubbleLabel => 'BURBUJAS';

  @override
  String get speakerColorScreenBubbleDescription =>
      'el color pasa también a sus mensajes, así que una racha de cinco sigue diciendo quién escribió.';

  @override
  String get roomInfoScreenSpeakerColorsLabel => 'COLORES';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => 'Automático';

  @override
  String get roomInfoScreenSpeakerColorsCustom => 'Personalizado';

  @override
  String get roomColorsScreenTitle => 'quién es quién.';

  @override
  String get roomColorsScreenSubtitle =>
      'el color con el que habla cada persona';

  @override
  String get roomColorsScreenOffTitle =>
      'los colores por persona están desactivados';

  @override
  String get roomColorsScreenOffBody =>
      'ahora mismo todos se dibujan con la misma tinta. actívalo y cada persona de aquí tendrá el suyo.';

  @override
  String get roomColorsScreenOffAction => 'ACTIVAR';

  @override
  String get roomColorsScreenOffHint =>
      'se aplica a todas las salas, no solo a esta. también está en ajustes.';

  @override
  String get roomColorsScreenAutoChip => 'AUTO';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return 'compartido con $name';
  }

  @override
  String get roomColorsScreenResetAll => 'VOLVER A AUTOMÁTICO';

  @override
  String get roomColorsScreenLimitToast =>
      'Es todo lo que una sala puede fijar.';

  @override
  String get roomColorsScreenFailedToast => 'No se pudo guardar ese color.';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return 'Color $index';
  }

  @override
  String get devicesScreenTitle => 'TUS DISPOSITIVOS';

  @override
  String get devicesScreenSubtitle =>
      'Todos los sitios donde has iniciado sesión con esta cuenta.';

  @override
  String get devicesScreenLoading => 'comprobando…';

  @override
  String get devicesScreenLoadFailed =>
      'no se pudieron cargar tus dispositivos';

  @override
  String get devicesScreenThisDevice => 'ESTE DISPOSITIVO';

  @override
  String get devicesScreenActiveNow => 'activo ahora';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count minutos',
      one: 'hace 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count horas',
      one: 'hace 1 hora',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'hace $count días',
      one: 'hace 1 día',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications =>
      'las notificaciones no llegan a este';

  @override
  String get devicesScreenRemove => 'QUITAR';

  @override
  String get devicesScreenRemoveTitle => '¿QUITAR ESTE DISPOSITIVO?';

  @override
  String devicesScreenRemoveBody(Object name) {
    return 'Se cerrará la sesión de $name y dejará de recibir notificaciones. Quien lo tenga tendrá que iniciar sesión otra vez.';
  }

  @override
  String get devicesScreenRemoveConfirm => 'QUITAR';

  @override
  String get devicesScreenRemoveAll => 'Quitar todos los demás dispositivos';

  @override
  String get devicesScreenRemoveAllTitle =>
      '¿QUITAR TODOS LOS DEMÁS DISPOSITIVOS?';

  @override
  String get devicesScreenRemoveAllBody =>
      'Se cerrará la sesión en todos y dejarán de recibir notificaciones. Solo este dispositivo sigue con la sesión iniciada.';

  @override
  String get devicesScreenRemoveAllConfirm => 'QUITAR TODOS';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivos quitados',
      one: '1 dispositivo quitado',
      zero: 'no hay otros dispositivos que quitar',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed => 'no se pudo quitar ese dispositivo';

  @override
  String get devicesScreenFootnote =>
      'Quitar un dispositivo cierra su sesión y detiene sus notificaciones. Surte efecto de inmediato: lo siguiente que intente hacer ese dispositivo lo devolverá a la pantalla de inicio de sesión.';

  @override
  String get attachmentMenuPollLabel => 'encuesta';

  @override
  String get attachmentMenuChecklistLabel => 'lista';

  @override
  String get attachmentMenuEventLabel => 'evento';

  @override
  String get interactionKindPoll => 'ENCUESTA';

  @override
  String get interactionKindQuiz => 'CUESTIONARIO';

  @override
  String get interactionKindChecklist => 'LISTA';

  @override
  String get interactionKindEvent => 'EVENTO';

  @override
  String get interactionBadgeAnonymous => 'ANÓNIMA';

  @override
  String get interactionBadgeMultiple => 'VARIAS';

  @override
  String get interactionBadgeClosed => 'CERRADA';

  @override
  String interactionPercent(int percent) {
    return '$percent %';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names +$count';
  }

  @override
  String get interactionSeeWhoAnswered => 'Ver quién respondió';

  @override
  String interactionRemoveItem(String label) {
    return 'Quitar $label';
  }

  @override
  String interactionChoiceSemantics(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
    );
    return '$label, $_temp0';
  }

  @override
  String get interactionAddItemHint => 'Añadir un elemento';

  @override
  String get interactionRetract => 'Retirar';

  @override
  String get interactionClose => 'Cerrar';

  @override
  String interactionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
    );
    return '$_temp0';
  }

  @override
  String interactionRsvpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count respuestas',
      one: '1 respuesta',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$done de $total hechos';
  }

  @override
  String get interactionNoAnswers => 'Sin respuestas';

  @override
  String get interactionBeFirst => 'Sé el primero en responder';

  @override
  String interactionFinalResults(String count) {
    return '$count · final';
  }

  @override
  String get interactionQuizRight => 'Correcto';

  @override
  String get interactionQuizWrong => 'Casi';

  @override
  String interactionEventPast(String when) {
    return '$when · ya pasó';
  }

  @override
  String get interactionRespondentsTitlePoll => 'QUIÉN VOTÓ';

  @override
  String get interactionRespondentsTitleChecklist => 'QUIÉN MARCÓ';

  @override
  String get interactionRespondentsTitleEvent => 'QUIÉN RESPONDIÓ';

  @override
  String get interactionRespondentsFailed =>
      'No se pudo cargar quién respondió.';

  @override
  String get interactionRespondentsEmpty => 'Todavía no ha respondido nadie.';

  @override
  String get interactionFilterAll => 'TODOS';

  @override
  String get interactionRsvpGoing => 'Voy';

  @override
  String get interactionRsvpMaybe => 'Quizá';

  @override
  String get interactionRsvpNo => 'No puedo';

  @override
  String get interactionComposePollTitle => 'nueva encuesta';

  @override
  String get interactionComposePollTagline => 'PREGUNTA A LA SALA';

  @override
  String get interactionComposeChecklistTitle => 'nueva lista';

  @override
  String get interactionComposeChecklistTagline => 'UNA LISTA QUE TODOS MARCAN';

  @override
  String get interactionComposeEventTitle => 'nuevo evento';

  @override
  String get interactionComposeEventTagline => 'MIRA QUIÉN VIENE';

  @override
  String get interactionComposeQuestionLabel => 'PREGUNTA';

  @override
  String get interactionComposeQuestionHint => '¿qué quieres preguntar?';

  @override
  String get interactionComposeTitleLabel => 'TÍTULO';

  @override
  String get interactionComposeTitleHint => '¿para qué es esta lista?';

  @override
  String get interactionComposeEventNameLabel => 'EVENTO';

  @override
  String get interactionComposeEventNameHint => '¿qué se celebra?';

  @override
  String get interactionComposeOptionsLabel => 'OPCIONES';

  @override
  String get interactionComposeItemsLabel => 'ELEMENTOS';

  @override
  String interactionComposeOptionHint(int index) {
    return 'opción $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return 'elemento $index';
  }

  @override
  String get interactionComposeAddOption => 'Añadir opción';

  @override
  String get interactionComposeAddItem => 'Añadir elemento';

  @override
  String get interactionComposeRemoveRow => 'Quitar';

  @override
  String get interactionComposeMarkCorrect => 'Marcar como respuesta correcta';

  @override
  String get interactionComposeMultipleTitle => 'varias respuestas';

  @override
  String get interactionComposeMultipleSub => 'elegir más de una';

  @override
  String get interactionComposeAnonymousTitle => 'anónima';

  @override
  String get interactionComposeAnonymousOffSub => 'todos ven quién votó';

  @override
  String get interactionComposeAnonymousOnSub => 'nadie ve quién votó';

  @override
  String get interactionComposeQuizTitle => 'modo cuestionario';

  @override
  String get interactionComposeQuizSub =>
      'una sola respuesta correcta, sin cambiarla';

  @override
  String get interactionComposeExplanationLabel => 'EXPLICACIÓN';

  @override
  String get interactionComposeExplanationHint =>
      'se muestra al responder (opcional)';

  @override
  String get interactionComposeOthersMayCheckTitle => 'cualquiera puede marcar';

  @override
  String get interactionComposeOthersMayCheckSub => 'no solo tú';

  @override
  String get interactionComposeOthersMayAddTitle => 'cualquiera puede añadir';

  @override
  String get interactionComposeOthersMayAddSub =>
      'la lista puede crecer después';

  @override
  String get interactionComposeWhenLabel => 'CUÁNDO';

  @override
  String get interactionComposePickStart => 'Elige el inicio';

  @override
  String get interactionComposePickEnd => 'Añadir un final (opcional)';

  @override
  String get interactionComposePlaceLabel => 'LUGAR';

  @override
  String get interactionComposePlaceHint => '¿dónde? (opcional)';

  @override
  String get interactionComposeSendPoll => 'ENVIAR ENCUESTA';

  @override
  String get interactionComposeSendChecklist => 'ENVIAR LISTA';

  @override
  String get interactionComposeSendEvent => 'ENVIAR EVENTO';

  @override
  String get interactionComposeErrorPrompt =>
      'Di primero qué quieres preguntar.';

  @override
  String interactionComposeErrorOptions(int count) {
    return 'Una encuesta necesita al menos $count opciones.';
  }

  @override
  String get interactionComposeErrorItems =>
      'Una lista necesita al menos un elemento.';

  @override
  String get interactionComposeErrorAnswer =>
      'Marca cuál es la opción correcta.';

  @override
  String get interactionComposeErrorWhen => 'Elige cuándo empieza.';

  @override
  String get interactionComposeErrorEnd =>
      'El final tiene que ir después del inicio.';

  @override
  String get interactionSendFailed => 'No se envió.';

  @override
  String get interactionRefused => 'No se pudo registrar.';

  @override
  String get messageReceiptsScreenTitle => 'VISTO POR';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$read de $total lo han leído';
  }

  @override
  String get messageReceiptsEmptyState =>
      'todavía no hay nadie más en esta sala';

  @override
  String get messageReceiptsSectionRead => 'LEÍDO';

  @override
  String get messageReceiptsSectionDelivered => 'ENTREGADO';

  @override
  String get messageReceiptsSectionSent => 'ENVIADO';

  @override
  String get messageReceiptsSectionHidden => 'SIN CONFIRMACIÓN';

  @override
  String get messageReceiptsStateHidden => 'no se comparte';

  @override
  String get messageReceiptsStateWaiting => 'en espera';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name lo leyó el $day a las $time';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name lo recibió el $day a las $time';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name todavía no lo ha recibido';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name no comparte confirmaciones de lectura';
  }

  @override
  String get companionsScreenTitle => 'compañeros.';

  @override
  String get companionsScreenSubtitle =>
      'ayudantes que viven en este teléfono y no envían nada a ninguna parte';

  @override
  String get companionSebastianTagline => 'Traduce mensajes';

  @override
  String get companionSebastianBlurb =>
      'Sebastian lee un mensaje escrito en otro idioma y te dice lo que pone — aquí, en tu teléfono, sin enviar nada a ninguna parte.';

  @override
  String get companionMarloweTagline => 'Ayuda general';

  @override
  String get companionMarloweBlurb =>
      'Marlowe se encarga de todo lo que no sea traducir. Elige un cerebro ahora y las habilidades irán llegando alrededor.';

  @override
  String get companionAssuranceOnDevice =>
      'Funciona por completo en este dispositivo';

  @override
  String get companionAssurancePrivate =>
      'Tus mensajes nunca salen del teléfono';

  @override
  String get companionAssuranceOffline => 'Funciona sin conexión';

  @override
  String companionInstallAction(Object size) {
    return 'Instalar · $size';
  }

  @override
  String get companionInstallOneTime =>
      'descarga única, se conserva hasta que la elimines';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$received de $total';
  }

  @override
  String get companionInstallQueued => 'Esperando a que termine otra descarga';

  @override
  String get companionInstallCancel => 'Cancelar';

  @override
  String get companionInstallRetry => 'Reintentar';

  @override
  String companionInstallReady(Object name) {
    return '$name está listo';
  }

  @override
  String get companionInstallFailedNetwork =>
      'La descarga no pudo completarse. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String get companionInstallFailedStorage =>
      'No hay espacio suficiente en este dispositivo. Libera algo e inténtalo de nuevo.';

  @override
  String get companionInstallFailedUnknown =>
      'La descarga no pudo completarse.';

  @override
  String get companionUnsupportedPlatform =>
      'Los compañeros aún no están disponibles en esta versión de la app.';

  @override
  String companionBrainNeedsMemory(String size) {
    return 'Necesita $size de memoria';
  }

  @override
  String get sebastianTierSeniorDetail => 'Traducciones más precisas';

  @override
  String get sebastianTierJuniorDetail => 'Funciona en cualquier teléfono';

  @override
  String get sebastianLanguageUnlisted =>
      'No es uno de sus idiomas: los resultados serán toscos';

  @override
  String get companionStatusNotInstalled => 'No instalado';

  @override
  String get companionStatusOff => 'Desactivado';

  @override
  String companionStatusTranslatingInto(Object language) {
    return 'Traduciendo al $language';
  }

  @override
  String get companionStatusNoBrain => 'Aún no has descargado nada';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count descargas listas',
      one: '1 descarga lista',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty =>
      'Nada descargado: los compañeros no ocupan espacio';

  @override
  String companionStorageUsed(Object size) {
    return 'Los compañeros ocupan $size';
  }

  @override
  String get companionSectionGeneral => 'GENERAL';

  @override
  String get companionSectionStorage => 'ALMACENAMIENTO';

  @override
  String get companionBrainRemove => 'Eliminar';

  @override
  String companionBrainRemoveTitle(Object name) {
    return '¿ELIMINAR $name?';
  }

  @override
  String companionRemoveTitle(Object name) {
    return '¿ELIMINAR $name?';
  }

  @override
  String companionRemoveMessage(Object size) {
    return 'Esto libera $size. Puedes volver a descargarlo cuando quieras.';
  }

  @override
  String get companionRemoveConfirm => 'ELIMINAR';

  @override
  String get sebastianEnableLabel => 'Dejar que Sebastian traduzca';

  @override
  String get sebastianEnableDetail =>
      'Desactívalo para detenerlo sin borrar la descarga';

  @override
  String get sebastianLanguageSection => 'TRADUCIR A';

  @override
  String get sebastianLanguageFollowApp => 'El mismo que la app';

  @override
  String sebastianBrainDetail(Object size) {
    return 'En este dispositivo · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count traducciones guardadas',
      one: '1 traducción guardada',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => 'Borrar';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe todavía no puede hacer nada: las habilidades están en camino. Lo que sí puedes hacer ahora es dejar un cerebro listo, para que nada dependa de una descarga cuando lleguen.';

  @override
  String get marloweBrainsSection => 'CEREBRO';

  @override
  String get marloweBrainsCaption =>
      'Cuanto más grande, mejor piensa y más tarda en responder. Puedes tener varios y cambiar entre ellos.';

  @override
  String get marloweBrainTierSwift => 'Ligero';

  @override
  String get marloweBrainTierBalanced => 'Equilibrado';

  @override
  String get marloweBrainTierDeep => 'Profundo';

  @override
  String get translationSlabShowOriginal => 'Ver original';

  @override
  String get translationSlabFailed => 'No se pudo traducir este mensaje.';

  @override
  String get translationSlabRetry => 'Reintentar';

  @override
  String translationSlabByCompanion(Object name) {
    return 'Traducido por $name';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return 'Desde $language';
  }

  @override
  String get messageActionMenuTranslateLabel => 'TRADUCIR';

  @override
  String get messageActionMenuShowOriginalLabel => 'VER ORIGINAL';

  @override
  String get roomTranslateTitle => 'Traducir este chat';

  @override
  String get roomTranslateStopTitle => 'Dejar de traducir';

  @override
  String get roomTranslateSectionLabel => 'TRADUCCIÓN';

  @override
  String get roomTranslateOnRow => 'Traduciendo este chat';

  @override
  String get roomTranslateOffRow => 'Desactivado';

  @override
  String get roomTranslateNeedsSetUp => 'Configurar a Sebastian';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'Sebastian está traduciendo · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return 'Leyendo en $language';
  }

  @override
  String get roomTranslateStop => 'PARAR';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return 'ya está en $language';
  }

  @override
  String get roomScreenTranslateRoomOffer =>
      '¿traducir también el resto del chat?';

  @override
  String get roomScreenTranslateRoomOfferAction => 'TRADUCIR TODO';

  @override
  String get settingsScreenCompanionsOff => 'Desactivado';

  @override
  String get settingsScreenCompanionsUnavailable => 'No disponible';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return 'También lo usa $name';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return '$name usa la misma descarga y también la perderá.';
  }

  @override
  String get companionBrainInUse => 'EN USO';

  @override
  String companionStatusUsingBrain(Object name) {
    return 'Usando $name';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name sigue descargándose — Ajustes › Compañeros';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return 'Descargando · $percent%';
  }

  @override
  String get companionInstallPause => 'Pausar';

  @override
  String get companionInstallResume => 'Reanudar';

  @override
  String get companionInstallDiscard => 'Descartar';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return 'En pausa · $received de $total';
  }

  @override
  String get companionInstallFailedIntegrity =>
      'El archivo descargado no coincide con lo que espera esta versión. Se empezará de nuevo.';

  @override
  String companionBannerDownloading(
    Object name,
    Object received,
    Object total,
  ) {
    return '$name · $received de $total';
  }

  @override
  String companionBannerPaused(Object name, Object received, Object total) {
    return '$name en pausa · $received de $total';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name está despertando…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => 'TRADUCIR DE NUEVO';
}
