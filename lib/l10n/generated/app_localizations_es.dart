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
  String get bootErrorTitle => 'Servidor inalcanzable';

  @override
  String get bootErrorBody => 'Convex no se pudo iniciar.';

  @override
  String get bootErrorRetry => 'Reintentar';

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
      'No se pudo preguntar ahora. Inténtalo de nuevo';

  @override
  String get roomScreenGateSendMessages => 'enviar mensajes aquí';

  @override
  String get roomScreenGateSendMedia => 'enviar fotos o notas de voz';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'Máximo $max a la vez';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminar $count mensajes',
      one: 'Eliminar mensaje',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Esto los eliminará para todos en este chat. No se puede deshacer.';

  @override
  String get roomScreenDeleteConfirmButton => 'Eliminar para todos';

  @override
  String get roomScreenJumpFailedSnack => 'No se pudo ir a ese mensaje';

  @override
  String get roomScreenUnreadDivider => 'Mensajes no leídos';

  @override
  String get roomScreenViewOnceAlreadyViewed => 'Ya abriste esta foto.';

  @override
  String get roomScreenViewOnceGone => 'Esta foto ya no está disponible.';

  @override
  String get roomScreenViewOnceNetworkError => 'No se pudo cargar la foto.';

  @override
  String get roomScreenFileReadFailedSnack => 'No se pudo leer el archivo';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'Los archivos tienen un límite de $size';
  }

  @override
  String get roomScreenRoomGone => 'La sala ya no existe';

  @override
  String get roomScreenCopiedSnack => 'Copiado';

  @override
  String get roomScreenNameCopiedSnack => 'Nombre copiado';

  @override
  String get roomScreenPinLimitSnack =>
      'Demasiados mensajes fijados. Quita uno primero';

  @override
  String get roomScreenPinFailedSnack => 'No se pudo fijar ese mensaje';

  @override
  String get roomScreenReportSentSnack =>
      'Reporte enviado en privado. No se le notificará a la otra persona.';

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
    return 'Esta sala es efímera. Los mensajes se desvanecen después de $ttl, se hayan leído o no.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count mensajes';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'Espacio Secreto';

  @override
  String get roomScreenSecretSpaceBody =>
      'Los mensajes de esta sala son efímeros. Se eliminan automáticamente según la política de seguridad de la sala.';

  @override
  String get roomReadOnlyFooter =>
      'Esta sala es de solo lectura. Aquí solo publica MonkeyHub.';

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
  String get roomScreenViewProfilePictureSemantic => 'Ver foto de perfil';

  @override
  String get roomScreenViewRoomPictureSemantic => 'Ver foto de la sala';

  @override
  String get messageBubbleFileFallbackName => 'Documento';

  @override
  String get messageBubbleAttachmentStatusFailed => 'Fallida';

  @override
  String get messageBubbleAttachmentStatusSending => 'Enviando…';

  @override
  String get messageBubbleViewOnceOpened => 'Abierta';

  @override
  String get messageBubbleViewOnceExpired => 'Caducada';

  @override
  String get messageBubbleViewOnceLabel => 'Vista única';

  @override
  String get messageBubbleViewOnceTapToView => 'Toca para ver';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Foto';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'Foto de vista única, toca para ver';

  @override
  String get messageBubblePlayOnceLabel => 'Reproducir una vez';

  @override
  String get messageBubblePlayOnceTapToPlay => 'Toca para reproducir';

  @override
  String get messageBubblePlayOncePlayed => 'Reproducido';

  @override
  String get messageBubblePlayOnceVoiceSemanticLabel =>
      'Mensaje de voz de una sola reproducción, toca para reproducir';

  @override
  String get messageBubblePlayOnceVideoNoteSemanticLabel =>
      'Nota de vídeo de una sola reproducción, toca para reproducir';

  @override
  String get replyIndicatorPlayOnceVoiceLabel =>
      'Mensaje de voz · una sola vez';

  @override
  String get replyIndicatorPlayOnceVideoNoteLabel =>
      'Nota de vídeo · una sola vez';

  @override
  String get roomScreenPlayOnceVoiceAlreadyPlayed =>
      'Ya escuchaste este mensaje de voz.';

  @override
  String get roomScreenPlayOnceVoiceGone =>
      'Este mensaje de voz ya no está disponible.';

  @override
  String get roomScreenPlayOnceVoiceNetworkError =>
      'No se pudo cargar el mensaje de voz.';

  @override
  String get roomScreenPlayOnceVideoNoteAlreadyPlayed =>
      'Ya viste esta nota de vídeo.';

  @override
  String get roomScreenPlayOnceVideoNoteGone =>
      'Esta nota de vídeo ya no está disponible.';

  @override
  String get roomScreenPlayOnceVideoNoteNetworkError =>
      'No se pudo cargar la nota de vídeo.';

  @override
  String get messageBubbleRetrySendingSemanticLabel => 'Reintentar envío';

  @override
  String get messageBubbleDiscardSemanticLabel => 'Descartar';

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
  String get profileScreenEmailHint => 'opcional, nunca se muestra a nadie';

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
      'ya te envió una solicitud. Revisa tus solicitudes.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'solicitud ya enviada.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'bloqueaste a este usuario. Desbloquéalo primero.';

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
      'Solo un mayor puede hacer esto: necesita su código o contraseña.';

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
  String get profileScreenLinkedAccountsNone => 'Ninguna cuenta vinculada';

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
    return 'Se podrá cambiar de nuevo el $date';
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
      'vista limitada. Comparten más con sus amigos.';

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
  String get cameraEditorScreenCropPresetFree => 'Libre';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'Orig.';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'Cancelar recorte';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'Descartar foto';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'Deshacer';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'Rehacer';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'Restablecer recorte';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'Girar';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'Recortar';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'Este navegador no puede abrir fotos HEIC';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'No pudimos abrir esa imagen';

  @override
  String get cameraEditorScreenCropDoneButton => 'Listo';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'Tomar otra foto';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'Guardar el lápiz';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'Dibujar en la foto';

  @override
  String get cameraEditorScreenSendingButton => 'Enviando…';

  @override
  String get cameraEditorScreenSendButton => 'Enviar';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'Desaparece después de abrirse una vez';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'Borrar dibujo';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel =>
      'Ver una vez: activado';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel =>
      'Ver una vez: desactivado';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: activado';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: desactivado';

  @override
  String get cameraEditorScreenHdNote => 'Se enviará en resolución completa';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'Color de tinta';

  @override
  String get glassScreenPanelLooks => 'Estilos';

  @override
  String get glassScreenPanelBottomBar => 'Barra inferior';

  @override
  String get glassScreenPanelOtherSurfaces => 'Otras superficies';

  @override
  String get glassScreenPanelBarLayout => 'Diseño de la barra';

  @override
  String get glassScreenTitle => 'cristal.';

  @override
  String get glassScreenSubtitle => 'cuánto se transparenta lo que hay detrás';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'Todos los $max espacios llenos';
  }

  @override
  String get glassScreenSaveCurrentAs => 'Guardar actual como…';

  @override
  String get glassScreenResetEveryDial => 'Restablecer todos los mandos';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'Restablecer a $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'El cuadro de mensaje, los encabezados, los botones de llamada: todo lo que se apoya sobre texto en vez de sobre contenido que se desplaza';

  @override
  String get glassScreenMatchBottomBar => 'Igualar a la barra inferior';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'Editado. Guárdalo como un nuevo estilo o restablécelo';

  @override
  String get glassScreenCustomPresetName => 'Personalizado';

  @override
  String get glassScreenUnsavedSubtitle =>
      'Sin guardar. Ponle un nombre para conservarlo';

  @override
  String get glassScreenSaveDialogTitle => 'Guardar este estilo como';

  @override
  String get glassScreenNoRoomToast => 'Sin espacio. Elimina un estilo primero';

  @override
  String get glassScreenRenameDialogTitle => 'Renombrar';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '¿Eliminar $name?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'El estilo se queda en pantalla, solo deja de tener nombre.';

  @override
  String get glassScreenKeepButton => 'Conservar';

  @override
  String get glassScreenDeleteButton => 'Eliminar';

  @override
  String get glassScreenNameHint => 'Trasnoche';

  @override
  String get glassScreenCancelButton => 'Cancelar';

  @override
  String get glassScreenSaveButton => 'Guardar';

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
  String get glassScreenPreviewBadge => 'Vista previa';

  @override
  String get glassScreenBuiltInLabel => 'Integrado';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'Sobrescribir $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'Renombrar $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'Eliminar $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'Restablecer $label';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'envió las fotos del techo, las tejas están todas agrietadas';

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
  String get replyIndicatorViewOnceLabel => 'Foto · ver una vez';

  @override
  String get replyIndicatorVoiceMessageLabel => 'Mensaje de voz';

  @override
  String get replyIndicatorDocumentLabel => 'Documento';

  @override
  String get replyIndicatorMessageRemoved => 'Mensaje eliminado';

  @override
  String get threadOverlayMessageNotFound =>
      'No encontré ese mensaje en este hilo';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'No encontré el hilo al que responder';

  @override
  String get threadOverlayStillSending =>
      'Aún se está enviando. Inténtalo de nuevo en un momento';

  @override
  String get threadOverlayCopiedToast => 'Copiado';

  @override
  String get threadOverlayNameCopiedToast => 'Nombre copiado';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'Coordenadas copiadas';

  @override
  String get threadOverlayPinLimitToast =>
      'Demasiados mensajes fijados. Desfija uno primero';

  @override
  String get threadOverlayPinFailedToast => 'No pude fijar eso';

  @override
  String get threadOverlayReportedToast => 'Reportado';

  @override
  String get threadOverlayUnavailable => 'hilo no disponible';

  @override
  String get roomInfoScreenNameRequiredError => 'El nombre es obligatorio';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'Contraseña eliminada';

  @override
  String get roomInfoScreenLeaveConfirmTitle => '¿Salir de la sala?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'Puedes volver a unirte si sigue abierta.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'Salir';

  @override
  String get roomInfoScreenDeleteConfirmTitle => '¿Eliminar la sala?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'Todos los mensajes de aquí se van con ella. Esto es permanente.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'Eliminar';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      '¿Terminar esta conversación?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName también pierde esta conversación: todos los mensajes desaparecen para ambos. Esto es permanente.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'Terminar';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'La otra persona';

  @override
  String get roomInfoScreenConfirmCancelButton => 'CANCELAR';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'Ya existe una sala con ese nombre';

  @override
  String get roomNameReservedError =>
      'Los nombres de sala no pueden empezar por dm:';

  @override
  String get roomInfoScreenErrorNotOwner => 'Solo el dueño puede hacer eso';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'No tienes permiso';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'Esta sala ya no existe';

  @override
  String get roomInfoScreenRoomGone => 'Sala no encontrada';

  @override
  String get roomInfoScreenNameLabel => 'NOMBRE';

  @override
  String get roomInfoScreenNameHint => 'Nombre de la sala';

  @override
  String get roomInfoScreenDescriptionLabel => 'DESCRIPCIÓN';

  @override
  String get roomInfoScreenDescriptionHint => 'Una línea sobre la sala';

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
      'esta sala está protegida. la contraseña actual no se muestra por seguridad, así que escribe una nueva para reemplazarla.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'Reemplazar contraseña';

  @override
  String get roomInfoScreenSetPasswordHint => 'Bloquear con una contraseña';

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
  String get roomInfoScreenViewProfilePictureSemantic => 'Ver foto de perfil';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'Ver foto de la sala';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic =>
      'Cambiar foto de la sala';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'Añadir foto de la sala';

  @override
  String get roomInfoScreenOwnerBadge => 'PROPIETARIO';

  @override
  String get roomInfoScreenNoneCount => 'ninguno';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'El acceso a la cámara está desactivado.\nActívalo en Ajustes para tomar una foto.';

  @override
  String get cameraScreenOpeningSystemCamera =>
      'Abriendo la cámara del sistema…';

  @override
  String get cameraScreenCloseButtonLabel => 'Cerrar cámara';

  @override
  String get cameraScreenLowLightBoostOnLabel => 'Modo de poca luz: activado';

  @override
  String get cameraScreenLowLightBoostOffLabel =>
      'Modo de poca luz: desactivado';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'Flash: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'Elegir de la galería';

  @override
  String get cameraScreenSwitchCameraLabel => 'Cambiar de cámara';

  @override
  String get cameraScreenTakePhotoLabel => 'Tomar foto';

  @override
  String get childPolicyScreenAddByUsernameLabel =>
      'Agregar por nombre de usuario';

  @override
  String get childPolicyScreenAddCta => 'Agregar';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'Tendrán exactamente lo mismo que tú: cada solicitud por aprobar, cada ajuste por cambiar y el poder de eliminarte a ti. Para $name, son familia desde el primer momento.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'Agregar un adulto';

  @override
  String get childPolicyScreenAddGuardianHint => 'Su nombre de usuario';

  @override
  String get childPolicyScreenAllowCta => 'Permitir';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'No te lo volveremos a preguntar, sin importar si $childName agrega a esta persona o esta persona agrega a $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'Permitir a alguien';

  @override
  String get childPolicyScreenAskToAddLabel => 'Pedir agregar';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'Solo familia, sin solicitudes nuevas';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'Pueden pedirte permiso para agregar a gente nueva';

  @override
  String get childPolicyScreenBothFinalNote =>
      'Ambas son definitivas. Para retirarte en su lugar, ve a Adultos, más arriba.';

  @override
  String get childPolicyScreenCallsLabel => 'Llamadas';

  @override
  String get childPolicyScreenCallsOffDesc => 'Solo mensajes';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'Voz y video con las personas permitidas';

  @override
  String get childPolicyScreenCancelLabel => 'Cancelar';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Cancelar';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'Agregado. La solicitud va en camino';

  @override
  String get childPolicyScreenContactAddedToList =>
      'Agregado a la lista de permitidos';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'Crear salas';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'No pueden crear salas';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'Pueden crear sus propias salas privadas';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Todo desaparece: sus mensajes, fotos, salas y amigos. Esto no se puede deshacer, y el nombre de usuario queda libre para cualquier otra persona.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'No se pudo eliminar la cuenta. Inténtalo de nuevo';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return '¿Eliminar la cuenta de $name?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Mensajes, fotos, salas y amigos, todo desaparece. No se puede deshacer.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'Eliminar la cuenta de $name';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'Eliminar para siempre';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'No se pudo agregar. Inténtalo de nuevo';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'Ese es su propio nombre de usuario';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'Un menor no puede ser un adulto';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'No se pudo hacer eso. Inténtalo de nuevo';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'Alguien tiene que cuidar de ellos. Añade a otro mayor primero';

  @override
  String get childPolicyScreenErrorNotYours =>
      'No tienes permiso para cambiar eso';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'No hay ninguna cuenta con ese nombre de usuario';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'Se convierten en una cuenta normal con esta contraseña, y todos los mayores pierden toda la visibilidad. No hay vuelta atrás: tendrías que recibir una invitación, como cualquier otra persona.';

  @override
  String get childPolicyScreenGraduateCta => 'Graduar';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'Conservan todo y reciben una contraseña. Pierdes toda la visibilidad. Irreversible.';

  @override
  String get childPolicyScreenGraduateDangerLabel =>
      'Graduar a cuenta completa';

  @override
  String get childPolicyScreenGraduateFailed =>
      'No se pudo completar la graduación. Inténtalo de nuevo';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'Graduar a $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'Una contraseña para ellos';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Quitar una sala también les saca de ella. Quitar a una persona también borra su chat, para los dos.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Todos los que están aquí pueden aprobar, cambiar los ajustes y verlo todo. Cualquiera de ellos puede actuar por su cuenta; no hace falta esperar a los demás.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'Añadido. Ya pueden cuidar de ellos';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name eliminado';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (tú)';
  }

  @override
  String get childPolicyScreenLoading => 'Cargando…';

  @override
  String get childPolicyScreenLockedLabel => 'Bloqueado';

  @override
  String get childPolicyScreenMediaLabel => 'Fotos + voz';

  @override
  String get childPolicyScreenMediaOffDesc => 'Solo texto';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'Pueden enviar fotos, vídeos y notas de voz';

  @override
  String get childPolicyScreenNoRoomsYet => 'Todavía no hay salas';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Cualquiera de aquí puede añadirse sin volver a pedirte permiso, no importa quién dé el primer paso.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Siempre desactivado para los niños. Descubre (la lista de salas de personas que no conoces) está completamente oculta y no se puede activar. Las salas a las que alguien les invite siguen funcionando con normalidad.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'Salas públicas';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian ya no podrá ver ni aprobar nada relacionado con $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return '¿Eliminar a $name?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'Eliminar';

  @override
  String childPolicyScreenRoomMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'Mayores';

  @override
  String get childPolicyScreenSectionPeopleAllowed =>
      'Personas que has permitido';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'Salas que has permitido';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'Qué pueden hacer';

  @override
  String get childPolicyScreenSectionWhenDone => 'Al terminar';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'No pasa nada hasta que alguien añada al otro';

  @override
  String get childPolicyScreenSendNowOnDesc => 'Se les pregunta enseguida';

  @override
  String get childPolicyScreenSendRequestNowLabel =>
      'Enviar la solicitud ahora';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'Eres la única persona mayor de $name, así que no puedes simplemente alejarte. Añade a otra primero, o usa una de estas.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'Alejarse';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'Perderás toda la visibilidad sobre la cuenta de $name: sus solicitudes, su gente, sus salas. Las demás personas mayores seguirán cuidando de $name.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'Dejar de supervisar';

  @override
  String get childPolicyScreenStopSupervisingHeadline =>
      '¿Dejar de supervisar?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'No se pudo revocar. Inténtalo de nuevo';

  @override
  String get childPolicyScreenTakeBackLabel => 'Revocar';

  @override
  String get childPolicyScreenUsernameHint => 'Nombre de usuario';

  @override
  String get childPolicyScreenYou => 'Tú';

  @override
  String get roomContentScreenDefaultDocumentName => 'Documento';

  @override
  String get roomContentScreenCouldntOpenFile => 'No se pudo abrir ese archivo';

  @override
  String get roomContentScreenCouldntShare =>
      'No se pudieron compartir esos elementos';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enlaces copiados',
      one: 'Enlace copiado',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminar $count mensajes',
      one: 'Eliminar mensaje',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Se eliminará para todos en este chat. No se puede deshacer.';

  @override
  String get roomContentScreenDeleteForEveryone => 'Eliminar para todos';

  @override
  String get roomContentScreenCancelTooltip => 'Cancelar';

  @override
  String get roomContentScreenBackTooltip => 'Atrás';

  @override
  String get roomContentScreenSelectingLabel => 'Seleccionando';

  @override
  String get roomContentScreenSharedContentLabel => 'Contenido compartido';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seleccionados',
      one: '$count seleccionado',
      zero: 'Nada seleccionado',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'Seleccionar';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'Todos';

  @override
  String get roomContentScreenEmptyMedia => 'Aún no hay fotos ni videos';

  @override
  String get roomContentScreenEmptyFiles => 'Aún no hay archivos';

  @override
  String get roomContentScreenEmptyVoice => 'Aún no hay notas de voz';

  @override
  String get roomContentScreenEmptyLinks => 'Aún no hay enlaces';

  @override
  String get roomContentScreenEmptySaved =>
      'Aún no has guardado nada. Mantén pulsado un mensaje y elige Guardar.\n\nLo que guardas aquí es solo tuyo: un mensaje fijado es lo que ve toda la sala.';

  @override
  String get roomContentScreenLoadFailed => 'No se pudo cargar eso';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Mensaje de voz de $name';
  }

  @override
  String get roomContentScreenForwardAction => 'Reenviar';

  @override
  String get roomContentScreenCopyAction => 'Copiar';

  @override
  String get roomContentScreenSaveAction => 'Guardar';

  @override
  String get roomContentScreenShareAction => 'Compartir';

  @override
  String get roomContentScreenInChatAction => 'Ver en chat';

  @override
  String get roomContentScreenDeleteAction => 'Eliminar';

  @override
  String get messageActionMenuReplyLabel => 'Responder';

  @override
  String get messageActionMenuEditLabel => 'Editar';

  @override
  String get messageStampEditedLabel => 'editado';

  @override
  String get composerEditCardTitle => 'Editar mensaje';

  @override
  String get spoilerRevealHint =>
      'Spoiler. Actívalo para mostrar el texto oculto';

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
  String get linkConfirmSheetTitle => '¿Abrir este enlace?';

  @override
  String get linkConfirmSheetOpenLabel => 'Abrir enlace';

  @override
  String get linkConfirmSheetCancelLabel => 'Cancelar';

  @override
  String get roomScreenEditExpiredSnack =>
      'Demasiado tarde para editar. Los mensajes solo se pueden editar durante 15 minutos.';

  @override
  String get roomScreenEditFailedSnack =>
      'No se ha podido guardar la edición. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get messageActionMenuForwardLabel => 'Reenviar';

  @override
  String get messageActionMenuViewThreadLabel => 'Ver hilo';

  @override
  String get messageActionMenuCopyLabel => 'Copiar';

  @override
  String get messageActionMenuCopyNameLabel => 'Copiar nombre';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'Copiar coordenadas';

  @override
  String get messageActionMenuPinLabel => 'Fijar';

  @override
  String get messageActionMenuUnpinLabel => 'Desfijar';

  @override
  String get messageActionMenuSelectLabel => 'Seleccionar';

  @override
  String get messageActionMenuProfileLabel => 'Perfil';

  @override
  String get messageActionMenuDeleteLabel => 'Eliminar';

  @override
  String get messageActionMenuReportLabel => 'Denunciar';

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
    return 'ACTIVO: $name';
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
  String callScreenStatusCalling(String kind) {
    return '$kind · llamando…';
  }

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · sonando…';
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
  String get callScreenStatusConnected => 'Conectado';

  @override
  String get callScreenStatusEnded => 'Llamada finalizada';

  @override
  String get callScreenStatusFailed => 'Llamada fallida';

  @override
  String get callScreenStatusSwitching => 'Cambiando de dispositivo…';

  @override
  String get callScreenStatusMoved => 'Movida';

  @override
  String get callScreenStatusReconnecting => 'Reconectando…';

  @override
  String get callScreenPoorConnectionLabel => 'Mala conexión';

  @override
  String get callScreenWeakConnectionLabel => 'Conexión débil';

  @override
  String get callScreenControlUnmute => 'Activar';

  @override
  String get callScreenControlMute => 'Silenciar';

  @override
  String get callScreenControlCamOn => 'Activar cámara';

  @override
  String get callScreenControlCamOff => 'Desactivar cámara';

  @override
  String get callScreenControlFlip => 'Voltear';

  @override
  String get callScreenControlSpeaker => 'Altavoz';

  @override
  String get callAudioControlLabel => 'Audio';

  @override
  String get callAudioSheetTitle => 'Audio';

  @override
  String get callAudioRoutePhone => 'Teléfono';

  @override
  String get callAudioRouteHeadphones => 'Auriculares';

  @override
  String get callAudioRouteBluetooth => 'Bluetooth';

  @override
  String get callAudioRouteCar => 'Coche';

  @override
  String get callAudioRouteOther => 'Otro dispositivo';

  @override
  String get callAudioMicFollowsNote =>
      'El micrófono cambia con el dispositivo que elijas.';

  @override
  String get callAudioMicrophoneHeader => 'Micrófono';

  @override
  String get callAudioUnknownDevice => 'Dispositivo desconocido';

  @override
  String get callAudioNoDevices => 'No se encontraron dispositivos';

  @override
  String get callAudioSwitchFailed =>
      'No se pudo cambiar el dispositivo de audio';

  @override
  String get callScreenControlEnd => 'Colgar';

  @override
  String get linkPreviewCardLinkLabel => 'Enlace';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name aceptó tu solicitud';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'Esa solicitud fue retirada';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'Solicitud rechazada';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'Bloqueaste a este usuario. Desbloquéalo primero.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'No está aceptando solicitudes de amistad en este momento.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'No se pudo enviar. Inténtalo de nuevo.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel =>
      'Solicitud entrante';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'Nueva solicitud';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name quiere iniciar una conversación.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'envía unas líneas. podrá aceptarla o rechazarla.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'Nada de esto se guarda de forma permanente hasta que ambas partes estén de acuerdo.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'Tipo de sala';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'Efímera';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'Estándar';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'Duración';

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
      'Susurra una primera línea · opcional';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'Añade un primer mensaje · opcional';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'Susurra · se desvanece solo';

  @override
  String get friendRequestDraftScreenHintStartWith => 'Algo para empezar';

  @override
  String get friendRequestDraftScreenApproveButton => 'Aprobar y abrir sala';

  @override
  String get friendRequestDraftScreenDeclineButton => 'Rechazar';

  @override
  String get friendRequestDraftScreenCancelRequestButton =>
      'Cancelar solicitud';

  @override
  String get friendRequestDraftScreenAskGrownUpButton =>
      'Pregúntale a un mayor';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'Enviar solicitud';

  @override
  String get discoverScreenTitle => 'descubre.';

  @override
  String get discoverScreenCaptionPeople => 'gente';

  @override
  String get discoverScreenCaptionRooms => 'salas';

  @override
  String get discoverScreenCaptionRequests => 'solicitudes';

  @override
  String get discoverScreenPeopleBandLabel => 'Gente';

  @override
  String get discoverScreenRoomsBandLabel => 'Salas';

  @override
  String get discoverScreenFindPeopleTitle => 'Buscar gente';

  @override
  String get discoverScreenFindPeopleSubtitleChild =>
      'Escribe el nombre de usuario completo';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'Busca por @usuario o nombre';

  @override
  String get discoverScreenRequestsSectionLabel => 'Solicitudes';

  @override
  String get discoverScreenInboxQuiet => 'Bandeja tranquila';

  @override
  String get discoverScreenNothingPending => 'Nada enviado';

  @override
  String get discoverScreenYourPeopleLabel => 'Amigos';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'Nadie todavía. Busca gente arriba';

  @override
  String get discoverScreenNoFriendsYet => 'Nadie todavía';

  @override
  String get discoverScreenSearchRoomsTitle => 'Buscar salas';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'Busca una sala pública por nombre';

  @override
  String get discoverScreenYourRoomsLabel => 'Salas';

  @override
  String get discoverScreenNoRoomsYet => 'Ninguna sala todavía';

  @override
  String get discoverScreenIncomingLabel => 'Entrantes';

  @override
  String get discoverScreenOutgoingLabel => 'Salientes';

  @override
  String get discoverScreenIncomingLabelCaps => 'ENTRANTES';

  @override
  String get discoverScreenOutgoingLabelCaps => 'SALIENTES';

  @override
  String get discoverScreenJumpPeopleLabel => 'Personas';

  @override
  String get discoverScreenJumpRoomsLabel => 'Salas';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Ir a $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'Ajustar';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'Usar foto';

  @override
  String get imageCropScreenSavingButton => 'Guardando…';

  @override
  String get imageCropScreenCancelButton => 'Cancelar';

  @override
  String get imageCropScreenHeicUnsupported =>
      'Este navegador no puede abrir fotos HEIC';

  @override
  String get imageCropScreenLoadFailed => 'No se pudo abrir esa imagen';

  @override
  String get imageCropScreenHintCircle =>
      'Arrastra para mover, pellizca para hacer zoom';

  @override
  String get imageCropScreenHintRect => 'Arrastra y pellizca para encuadrar';

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
  String get searchScreenHintPeople => 'Buscar personas';

  @override
  String get searchScreenHintRooms => 'Buscar salas públicas';

  @override
  String get searchScreenPeoplePromptChild =>
      'Escribe el nombre de usuario completo para encontrar a alguien nuevo';

  @override
  String get searchScreenPeoplePromptDefault =>
      'busca por nombre de usuario o nombre';

  @override
  String get searchScreenNoMatchChild =>
      'Nadie coincide. La gente nueva necesita\nsu nombre de usuario completo, letra por letra';

  @override
  String get searchScreenNoMatchDefault => 'Nadie coincide';

  @override
  String get searchScreenNoRoomsYet => 'Aún no hay salas públicas';

  @override
  String get searchScreenNoRoomsMatch => 'Ninguna sala pública coincide';

  @override
  String get searchScreenActionAskToAdd => 'Pedir agregar';

  @override
  String get searchScreenActionSendRequest => 'Enviar solicitud';

  @override
  String get searchScreenActionCancel => 'Cancelar';

  @override
  String get searchScreenActionApprove => 'Aprobar';

  @override
  String get searchScreenActionOpenDm => 'Abrir DM';

  @override
  String get searchScreenAskedLabel => 'pedido';

  @override
  String get profileVisibilityScreenTitle => 'preferencias de visibilidad.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'controla qué ven los demás y cómo pueden contactarte.';

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
      'Copiado. Pégalo en un lugar seguro';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'Confirma\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'que eres tú.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Tu contraseña, para que nadie más pueda poner una frase de recuperación en tu cuenta.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'Contraseña';

  @override
  String get recoveryPhraseScreenContinueButton => 'CONTINUAR';

  @override
  String get recoveryPhraseScreenNotNowLink => 'ahora no';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'Ingresa tu contraseña.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'Guarda\n';

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
      'ahora no, conservar mi frase actual';

  @override
  String get homeScreenProfileSemanticLabel => 'Tu perfil';

  @override
  String homeScreenGreeting(Object name) {
    return 'hola, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'Nueva sala';

  @override
  String get homeScreenEmptyRoomsMessage => 'Aún no tienes salas. Crea una';

  @override
  String get groupCallScreenTitleVideo => 'Videollamada grupal';

  @override
  String get groupCallScreenTitleVoice => 'Llamada de voz grupal';

  @override
  String groupCallScreenParticipantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count en la llamada',
      one: 'Solo tú',
    );
    return '$_temp0';
  }

  @override
  String get groupCallScreenReconnecting => 'Reconectando…';

  @override
  String get groupCallScreenUnmuteLabel => 'Activar';

  @override
  String get groupCallScreenMuteLabel => 'Silenciar';

  @override
  String get groupCallScreenCamOnLabel => 'Activar cámara';

  @override
  String get groupCallScreenCamOffLabel => 'Desactivar cámara';

  @override
  String get groupCallScreenFlipLabel => 'Voltear';

  @override
  String get groupCallScreenSpeakerLabel => 'Altavoz';

  @override
  String get groupCallScreenLeaveLabel => 'Salir';

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
  String get roomFilterDrawerClearLabel => 'Borrar';

  @override
  String get roomFilterDrawerDimensionType => 'Tipo';

  @override
  String get roomFilterDrawerDimensionNature => 'Naturaleza';

  @override
  String get roomFilterDrawerDimensionStatus => 'Estado';

  @override
  String get roomFilterDrawerPanelClear => 'Borrar';

  @override
  String get roomFilterDrawerPanelDone => 'Listo';

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
    return 'Nada coincide con $summary';
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
      other: 'Mostrar todos los $count chats',
      one: 'Mostrar el $count chat',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'Nueva sala';

  @override
  String get createRoomSheetTaglineSecret => 'Nada se guardará';

  @override
  String get createRoomSheetTaglineRegular => 'Un espacio que queda';

  @override
  String get createRoomSheetNameLabel => 'Nombre';

  @override
  String get createRoomSheetNameHint => 'Ponle un nombre honesto';

  @override
  String get createRoomSheetDescriptionLabel => 'Descripción · opcional';

  @override
  String get createRoomSheetDescriptionHint => 'Una línea sobre la sala';

  @override
  String get createRoomSheetVisibilityLabel => 'Visibilidad';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'Pública';

  @override
  String get createRoomSheetVisibilityPublicSub =>
      'Cualquiera puede encontrarla';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'Privada';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'Solo por invitación';

  @override
  String get createRoomSheetTypeLabel => 'Tipo';

  @override
  String get createRoomSheetTypeStandardTitle => 'Estándar';

  @override
  String get createRoomSheetTypeStandardSub => 'Los mensajes permanecen';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'Efímera';

  @override
  String get createRoomSheetTypeEphemeralSub => 'Se autoeliminan';

  @override
  String get createRoomSheetMessageLifeLabel => 'Vida del mensaje';

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
  String get createRoomSheetPasswordLabel => 'Contraseña · opcional';

  @override
  String get createRoomSheetPasswordHint => 'Ciérrala con una contraseña';

  @override
  String get createRoomSheetNameRequiredError => 'El nombre es obligatorio';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Abrir la sala';

  @override
  String get createRoomSheetOpenRoomButton => 'Abrir la sala';

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
  String get reactionDetailsSheetTitle => 'Reacciones';

  @override
  String get reactionDetailsSheetEmptyState => 'Ya no hay nada aquí';

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
  String get reactionDetailsSheetFilterAll => 'Todos';

  @override
  String get reactionDetailsSheetYouBadge => 'Tú';

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
  String get audioMessageUnavailableLabel => 'Audio no disponible';

  @override
  String get audioMessageRetryHint => 'Toca para reintentar';

  @override
  String get audioMessageLoadingLabel => 'Cargando…';

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
  String get audioMessageUsernameHint => 'Nombre de usuario';

  @override
  String get audioMessageDisplayNameHint => 'Nombre para mostrar (opcional)';

  @override
  String get audioMessagePasswordHint => 'Contraseña';

  @override
  String get audioMessageSwitchToLinkPrompt =>
      'Esa cuenta es mía, inicia sesión';

  @override
  String get audioMessageCreateAccountButton => 'Crear cuenta';

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
      'no se pudo guardar, inténtalo de nuevo';

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
  String get approvalsScreenForwardDirectMessageFallback => 'Mensaje directo';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reenviar $count mensajes',
      one: 'Reenviar mensaje',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'Aún no hay otros chats';

  @override
  String get approvalsScreenForwardNoMatches => 'No hay coincidencias';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'Hasta $max chats a la vez';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'Buscar chats';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Deseleccionar $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Seleccionar $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'Desaparece';

  @override
  String get approvalsScreenForwardSendSemantic => 'Enviar';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar a $count',
      zero: 'Enviar',
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
  String get linkedAccountsScreenCallSheetVoiceLabel => 'Voz';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'Video';

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
  String get profileScreenDeleteAccountFailed =>
      'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get childPairScreenAccountGoneError => 'Esa cuenta ya no existe.';

  @override
  String get childPairScreenScanButtonLabel => 'ESCANEA SU CÓDIGO';

  @override
  String get childPairScreenNoCameraMessage =>
      'No hay cámara aquí. Escribe los seis números en su lugar.';

  @override
  String get childPairScreenStopScanning => 'Dejar de escanear';

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
      'Mostrando parte de este archivo. Descárgalo para ver el resto.';

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
  String get fileMessageStandardBadge => 'Estándar';

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
  String get fileMessageApproveButton => 'Aprobar';

  @override
  String get fileMessageDeclineButton => 'Rechazar';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'Enviado $ago';
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
  String get fileMessageCancelRequestButton => 'Cancelar solicitud';

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
      'No se pudo crear el código. Inténtalo de nuevo.';

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
    return 'En el teléfono de $name, abre MonkeyHub y escanea esto, o escribe los números.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'Este código ha caducado';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'Caduca en $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'Nuevo código';

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
  String get deepOceanThemeEphemeralHint => 'Susurra algo';

  @override
  String get deepOceanThemeDefaultHint => 'Di algo';

  @override
  String get deepOceanThemeMessageHint => 'Mensaje';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'Este archivo desapareció';

  @override
  String get photoChromeMediaYouLabel => 'Tú';

  @override
  String get photoChromeCloseSemanticLabel => 'Cerrar';

  @override
  String get photoChromeFillToggleSemanticLabel =>
      'Ajustar o llenar la pantalla';

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
  String get photoDeckBackToFirst => 'Volver a la primera';

  @override
  String get inlinePickerCommentHint => 'Añade un comentario o envía';

  @override
  String get attachmentMenuGalleryLabel => 'Galería';

  @override
  String inlinePickerVideoCompressNote(String size) {
    return 'Supera $size, así que se comprimirá para enviarlo';
  }

  @override
  String messageMenuAlbumAll(int count) {
    return 'Todos ($count)';
  }

  @override
  String get messageMenuAlbumOne => 'Solo este';

  @override
  String replyAlbumItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => 'Descartar estas fotos';

  @override
  String get photoTrayRemoveSemanticLabel => 'Quitar esta foto';

  @override
  String get photoTrayEditSemanticLabel => 'Recortar o dibujar en esta foto';

  @override
  String get photoTrayAddMoreSemanticLabel => 'Añadir más fotos';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'Puedes enviar $count fotos a la vez';
  }

  @override
  String get photoTrayLoadFailedSnack =>
      'No se pudieron abrir algunas de esas fotos';

  @override
  String get mediaPickFailedMessage => 'No se pudo abrir. Vuelve a elegirlo';

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
  String get typingIndicatorUnknownCallerFallbackName => 'Llamada entrante';

  @override
  String get typingIndicatorIncomingVideoCallLabel => 'Videollamada entrante';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'Llamada de voz entrante';

  @override
  String get typingIndicatorDeclineButtonLabel => 'Rechazar';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'Rechazando…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'Aceptar';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'Conectando…';

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
      'Permiso de micrófono denegado';

  @override
  String get voiceRecorderScreenStatusRecording => 'Grabando';

  @override
  String get voiceRecorderScreenStatusReady => 'Listo';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'Toca para empezar';

  @override
  String get voiceRecorderScreenReRecordButton => 'Regrabar';

  @override
  String get voiceRecorderScreenStopButton => 'Parar';

  @override
  String get voiceRecorderScreenSendButton => 'Enviar';

  @override
  String get voiceRecorderScreenRecordButton => 'Grabar';

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
    return 'Esto cierra la sesión de $name en este teléfono y lo devuelve. El teléfono vuelve a la pantalla de inicio de sesión normal, y cualquiera puede usarlo.';
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
  String get activeCallPillPinnedHeader => 'Fijados';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'Fijados · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'Ya no hay nada fijado';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Ir al mensaje de $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Dejar de fijar el mensaje de $name';
  }

  @override
  String get callButtonErrorBusy => 'Ocupado en otra llamada';

  @override
  String get callButtonErrorCallFailed => 'No se pudo iniciar la llamada';

  @override
  String get callButtonErrorNotMember => 'No eres miembro de esta sala';

  @override
  String get callButtonErrorGeneric => 'No se pudo iniciar la llamada';

  @override
  String get callButtonAlreadyOnCall => 'Ya estás en una llamada';

  @override
  String get callButtonBusyElsewhere => 'Llamada en curso en otro dispositivo';

  @override
  String get callButtonVoiceCallTooltip => 'Llamada de voz';

  @override
  String get callButtonVideoCallTooltip => 'Videollamada';

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
      'cápsula de cita con tono de acento, barra de conexión y avatar: el look clásico al estilo WhatsApp que ya conoces.';

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
      'No se pudo crear la cuenta. Inténtalo de nuevo.';

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
      'Todos los demás necesitan tu aprobación primero: tanto las personas que ellos pidan agregar, como las que pidan agregarlos a ellos.';

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
  String get childSetupScreenWaitingPillAskedLabel => 'Pedido';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'MIEMBROS';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'Ver todo ($count)';
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
      'sin cola. Una serie se mantiene unida solo por sus esquinas internas cerradas.';

  @override
  String get bubbleStyleScreenPillLabel => 'CÁPSULA';

  @override
  String get bubbleStyleScreenPillDescription =>
      'cápsulas totalmente redondeadas, iguales en cada fila.';

  @override
  String get bubbleStyleScreenSlabLabel => 'BLOQUE';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'hombros cuadrados: nítidos, impresos, decididos.';

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
      'Último mensaje hace un momento';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'Último mensaje hace $hours h';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'Último mensaje ayer';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'Último mensaje hace $days días';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'Último mensaje hace un tiempo';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'Retirar';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return '¿Quitar a $contactName de los contactos de $childName?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'Ya no podrán contactarse entre sí, y su conversación desaparecerá con ello.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'Ya no podrán contactarse entre sí. $contactName no se enterará.';
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
      'Desaparecerán para ambos, incluidas fotos y notas de voz. Esto no se puede deshacer.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'También comparten $count salas',
      one: 'También comparten $count sala',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'Estas se quedan. Si quieres sacarlas, recupera la sala en la lista de Salas de abajo.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'Recuperar y eliminar';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'Elimina a $contactName y borra $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'Elimina a $contactName de la lista de permitidos.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Cancelar';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton =>
      'Cancelar';

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
  String get groupCallBannerJoinButtonLabel => 'Unirse';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'Unirse a la sala';

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
  String get groupCallBannerPasswordFieldLabel => 'Contraseña';

  @override
  String get groupCallBannerPasswordHint => 'Frase de acceso';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Unirse';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'Unirse';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Cancelar';

  @override
  String get groupCallBannerCancelButtonLabel => 'Cancelar';

  @override
  String get viewOnceViewerBadgeLabel => 'Ver una vez';

  @override
  String get socialButtonDividerOr => 'o';

  @override
  String get socialButtonGoogleContinue => 'Continuar con Google';

  @override
  String get discoverListsPeopleTitle => 'Amigos';

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
  String get discoverListsFilterHint => 'Buscar amigos';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Borrar filtro';

  @override
  String get discoverListsNoOneYet => 'Nadie todavía';

  @override
  String discoverListsNoMatches(Object query) {
    return 'Nadie coincide con \"$query\"';
  }

  @override
  String get discoverListsRoomsTitle => 'Salas';

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
  String get discoverListsFilterRoomsHint => 'Buscar en tus salas';

  @override
  String get discoverListsNoRoomsYet => 'Ninguna sala todavía';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return 'Ninguna sala coincide con \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'LLAMADA DE VOZ';

  @override
  String get discoverListsVideoCallLabel => 'VIDEOLLAMADA';

  @override
  String get approvalGateAlreadyAskedLabel => 'Ya pedido';

  @override
  String get approvalGateAskGrownUpLabel => 'Pregúntale a un mayor';

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
  String get approvalGateAskButton => 'Preguntar';

  @override
  String get approvalGateNotNowButton => 'AHORA NO';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => 'Esperando a un mayor';

  @override
  String get reportSheetTitle => 'DENUNCIAR';

  @override
  String get reportSheetSubtitle => 'cuéntanos qué pasó.';

  @override
  String get reportSheetPrivacyNote =>
      'las denuncias son privadas, no se avisa a la otra persona.';

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
  String get reportSheetUpdateRequiredTitle => 'Actualización requerida';

  @override
  String get reportSheetUpdateAvailableTitle => 'Actualización disponible';

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
  String get reportSheetUpdateButtonTitle => 'Actualizar';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'Abre TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'Abre la App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'Abre Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'Abre la página de descarga';

  @override
  String get reportSheetUpdateActionReloads => 'Recarga con la nueva versión';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Más tarde';

  @override
  String get reportSheetUpdateLaterButton => 'Más tarde';

  @override
  String get roomFilterBarAllChipLabel => 'Todos';

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
    return 'Respondiendo a $name';
  }

  @override
  String get roomCardLockedBadge => 'Bloqueada';

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
    return 'Creada hace $ago';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count dentro';
  }

  @override
  String get roomCardMessagesFadeLabel => 'Mensajes se desvanecen';

  @override
  String get roomCardEnterLabel => '↗ Entrar';

  @override
  String get roomCardBlockedScreenTitle => 'BLOQUEADOS';

  @override
  String get roomCardBlockedEmptyState => 'no has bloqueado a nadie.';

  @override
  String get roomCardUnblockButton => 'DESBLOQUEAR';

  @override
  String get attachmentMenuPhotoLabel => 'Foto';

  @override
  String get attachmentMenuVideoLabel => 'Video';

  @override
  String get attachmentMenuCameraLabel => 'Cámara';

  @override
  String get attachmentMenuVoiceLabel => 'Voz';

  @override
  String get attachmentMenuFileLabel => 'Archivo';

  @override
  String get attachmentMenuConnectionRetrying => 'Reintentando…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'No se puede conectar con el servidor · Toca para reintentar';

  @override
  String get attachmentMenuConnectionReconnecting => 'Reconectando…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Reintentar conexión';

  @override
  String get roomGridTileEmptyLastMessage => 'tranquilo por ahora';

  @override
  String get roomGridTileMemberCountLabel => 'Dentro';

  @override
  String get roomGridTileThemeChipLabel => 'TEMA';

  @override
  String get bulkActionBarCancelLabel => 'Cancelar';

  @override
  String get bulkActionBarSelectMessagesLabel => 'Seleccionar mensajes';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count seleccionados';
  }

  @override
  String get bulkActionBarForwardLabel => 'Reenviar';

  @override
  String get bulkActionBarDeleteLabel => 'Eliminar';

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
  String get bulkActionBarBlockSheetNotNotifiedNote => 'No se le notificará.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'Ahora mismo son amigos. Bloquear termina la amistad, así que para reconectar más tarde tendrías que enviar una nueva solicitud de amistad.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'Desaparecerá de tus búsquedas y no podrá escribirte.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'Bloquear';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return '¿Bloquear a $name?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Compartes $count salas con esta persona',
      one: 'Compartes $count sala con esta persona',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'Estas salas quedan intactas. Puedes salir de cualquiera de ellas desde los ajustes de cada sala.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'Bloquear';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'Termina la amistad y bloquea. El historial de chat existente permanece en tu archivo.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'Se oculta de las búsquedas y no puede contactarte.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'Bloquear y eliminar DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'También borra tu DM con esta persona: todos los mensajes, reacciones y archivos multimedia desaparecen.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Cancelar';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'Cancelar';

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
  String get reactionBubblePickerTitle => 'Reaccionar';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'Aún no hay recientes';

  @override
  String get reactionBubbleSearchHint => 'Buscar emoji';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'Sin coincidencias';

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
      'No pudimos preguntar ahora mismo. Inténtalo de nuevo';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'contraseña incorrecta';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'no se pudo unir, inténtalo de nuevo';

  @override
  String get feedBoardTitle => 'HOY';

  @override
  String feedBoardEditionLabel(Object number) {
    return 'N.º$number';
  }

  @override
  String get feedBoardHighlightsLabel => 'Destacados';

  @override
  String get feedBoardHighlightsEmpty => 'Hoy todavía no hay nada';

  @override
  String get feedBoardPuzzleLabel => 'EL PUZLE';

  @override
  String get feedBoardPuzzleEmpty => 'el puzle de hoy aún no está listo';

  @override
  String get feedBoardStandingsLabel => 'Puntos de vida';

  @override
  String get feedBoardStandingsEmpty => 'Hoy no hay puntos en el marcador';

  @override
  String get feedBoardActivityLabel => 'Actividad';

  @override
  String get feedBoardActivityEmpty => 'hoy está tranquilo por ahora';

  @override
  String get feedBoardActivityNoFriends =>
      'Añade a un amigo y su día aparecerá aquí';

  @override
  String get feedBoardLoadFailed =>
      'No se pudo cargar el tablero. Inténtalo en un momento';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'Pública';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'Privada';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'Unido';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'Efímera · $duration';
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
  String get roomInfoSheetNoDescription => 'Todavía sin descripción';

  @override
  String get roomInfoSheetCreatedLabel => 'Creada';

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
      'Sin frase de recuperación, no podrías volver a entrar.';

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
  String get roomContentTabLabelMedia => 'Multimedia';

  @override
  String get roomContentTabLabelFiles => 'Archivos';

  @override
  String get roomContentTabLabelVoice => 'Voz';

  @override
  String get roomContentTabLabelLinks => 'Enlaces';

  @override
  String get roomContentTabLabelSaved => 'Guardados';

  @override
  String get roomContentTabHeaderMedia => 'Multimedia';

  @override
  String get roomContentTabHeaderFiles => 'Archivos';

  @override
  String get roomContentTabHeaderVoice => 'Voz';

  @override
  String get roomContentTabHeaderLinks => 'Enlaces';

  @override
  String get roomContentTabHeaderSaved => 'Guardados';

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
  String get reportProblemDescribeLabel => 'Qué ha pasado';

  @override
  String get reportProblemDescribeHint =>
      'La pantalla parpadea, los botones no responden';

  @override
  String get reportProblemScreenshotsLabel => 'Capturas';

  @override
  String get reportProblemAddScreenshot => 'Añadir captura';

  @override
  String get reportProblemDetailsLabel => 'Tus datos';

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
      'solo vista previa: burbujas más limpias, toca para abrir';

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
      'Full HD: más nítido, usa más datos';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD: mejor con una conexión fuerte';

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
      'silencioso. Solo verás las cosas cuando abras la app';

  @override
  String get settingsScreenGameRemindersLabel =>
      'RECORDATORIO DIARIO DE JUEGOS';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'un aviso al mediodía, solo si no has jugado';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'sin recordatorio. Los juegos siguen ahí cuando entres';

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
      'Esa es una cuenta infantil. Pídele un código de emparejamiento a un mayor.';

  @override
  String get authErrorPairingCodeExpired =>
      'Ese código caducó. Pide uno nuevo.';

  @override
  String get authErrorPairingCodeInvalid =>
      'Ese código no funcionó. Puede que ya se haya usado.';

  @override
  String get authErrorUseSocialSignIn =>
      'Esa cuenta inicia sesión con Apple o Google. Usa los botones de abajo.';

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
  String get glassKnobLabelFrost => 'Esmerilado';

  @override
  String get glassKnobHintFrost =>
      'Cuánto blanco hay sobre el cristal. Bájalo para que sea transparente';

  @override
  String get glassKnobLabelBlur => 'Desenfoque';

  @override
  String get glassKnobHintBlur =>
      'Esmerilado en la parte alta del rango, cristal transparente en la parte baja';

  @override
  String get glassKnobLabelSaturation => 'Fuga de color';

  @override
  String get glassKnobHintSaturation =>
      'Cuánto color sobrevive al desenfoque. Pasado el 2, se posteriza';

  @override
  String get glassKnobLabelRimOpacity => 'Borde';

  @override
  String get glassKnobHintRimOpacity =>
      'Brillo del borde del cristal. Cero para una superficie sin borde';

  @override
  String get glassKnobLabelRimWidth => 'Grosor del borde';

  @override
  String get glassKnobHintRimWidth => 'El grosor de ese contorno';

  @override
  String get glassKnobLabelShadowOpacity => 'Sombra';

  @override
  String get glassKnobHintShadowOpacity =>
      'Cuánto flota la superficie sobre lo que hay detrás';

  @override
  String get glassKnobLabelShadowBlur => 'Difusión de sombra';

  @override
  String get glassKnobHintShadowBlur => 'Suave y amplia, o ajustada y dura';

  @override
  String get glassKnobLabelShadowY => 'Caída de sombra';

  @override
  String get glassKnobHintShadowY => 'Cuánto cae por debajo de la superficie';

  @override
  String get glassKnobLabelBarMargin => 'Margen lateral';

  @override
  String get glassKnobHintBarMargin =>
      'Espacio entre la barra y el borde de la pantalla';

  @override
  String get glassKnobLabelBarBottom => 'Espacio inferior';

  @override
  String get glassKnobHintBarBottom =>
      'Cuánto flota la barra por encima del borde inferior';

  @override
  String get glassKnobLabelShellPadH => 'Relleno de extremos';

  @override
  String get glassKnobHintShellPadH =>
      'Del borde de la barra a la primera cápsula. Mantenlo pequeño, o los extremos parecen varados';

  @override
  String get glassKnobLabelShellPadV => 'Relleno superior';

  @override
  String get glassKnobHintShellPadV =>
      'Del borde de la barra a la parte superior de la cápsula';

  @override
  String get glassKnobLabelIndicatorInset => 'Margen de cápsula';

  @override
  String get glassKnobHintIndicatorInset =>
      'Qué tan adentro de su ranura está la cápsula de selección';

  @override
  String get glassKnobLabelSegmentPadV => 'Relleno de fila';

  @override
  String get glassKnobHintSegmentPadV =>
      'El aire por encima y por debajo del ícono y su etiqueta';

  @override
  String get glassKnobLabelIconLabelGap => 'Espacio del icono';

  @override
  String get glassKnobHintIconLabelGap =>
      'Espacio entre un icono y la palabra que tiene debajo';

  @override
  String get glassKnobLabelIconSize => 'Tamaño del icono';

  @override
  String get glassKnobLabelLabelSize => 'Tamaño de la etiqueta';

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
      'Igual que el dispositivo · Completo';

  @override
  String get settingsScreenValueMotionSystemCalm =>
      'Igual que el dispositivo · Tranquilo';

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
      'la decoración se detiene, nada más cambia';

  @override
  String get momentRailCaptureLabel => 'Capturar';

  @override
  String get momentRailYouLabel => 'Tú';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String momentRailPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destacados',
      one: '1 destacado',
    );
    return '$_temp0';
  }

  @override
  String momentRailPersonNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuevos',
      one: '1 nuevo',
    );
    return '$_temp0';
  }

  @override
  String get momentRailAddHighlight => 'Añadir un destacado';

  @override
  String get momentTagFate => 'Destino';

  @override
  String get momentTagJinx => 'Gafe';

  @override
  String get momentTagLuck => 'Suerte';

  @override
  String get momentTagCalledIt => 'Lo dije';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'Qué casualidad';

  @override
  String get momentTagJinxHint => 'Te lo buscaste';

  @override
  String get momentTagLuckHint => 'Salió a tu favor';

  @override
  String get momentTagCalledItHint => 'Lo viste venir';

  @override
  String get momentTagNpcHint => 'Cerebro apagado';

  @override
  String get momentComposerTitle => 'Nuevo momento';

  @override
  String get momentComposerCaptionHint => 'Cuenta algo';

  @override
  String get momentComposerTagPrompt => '¿has ganado un punto? añádelo';

  @override
  String get momentComposerCapture => 'Cámara';

  @override
  String get momentComposerLibrary => 'Galería';

  @override
  String get momentComposerRemovePhoto => 'Quitar foto';

  @override
  String get momentComposerPost => 'Publicar';

  @override
  String get momentComposerErrorDailyCap =>
      'Ya van cinco hoy. Deja algo para mañana';

  @override
  String get momentComposerErrorNotAllowed =>
      'Un tutor ha desactivado compartir fotos';

  @override
  String get momentComposerErrorTooLong => 'Se ha alargado un poco. Recórtalo';

  @override
  String get momentComposerErrorEmpty => 'Añade una foto o unas palabras';

  @override
  String get momentComposerErrorGeneric =>
      'No se pudo publicar. Inténtalo de nuevo';

  @override
  String get momentViewerDelete => 'Eliminar';

  @override
  String get momentViewerDeleteConfirmHeadline => '¿Eliminar esto?';

  @override
  String get momentViewerDeleteConfirmBody =>
      'Desaparece del tablón de todos y de tu archivo, para siempre';

  @override
  String get momentViewerDeleteFailed =>
      'No se pudo eliminar. Inténtalo de nuevo';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who ha publicado un momento';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name ha sumado un punto: $tag';
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
  String get puzzleScreenTitle => 'el puzle.';

  @override
  String get puzzleScreenSubtitle => 'Cuatro símbolos, seis intentos';

  @override
  String get puzzleSubmit => 'Adivinar';

  @override
  String get puzzleBackspace => 'Borrar último símbolo';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'Símbolo $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'Resuelto en $count';
  }

  @override
  String get puzzleFailedTitle => 'Sin intentos';

  @override
  String get puzzleAnswerWas => 'El código era';

  @override
  String get puzzleShare => 'Copiar resultado';

  @override
  String get puzzleShareCopied => 'Copiado. Pégaselo a un amigo';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'Ya has resuelto el de hoy';

  @override
  String get puzzleErrorOutOfGuesses => 'Hoy no te quedan intentos';

  @override
  String get puzzleErrorGeneric => 'No se pudo enviar. Inténtalo de nuevo';

  @override
  String get puzzleGuessWaiting =>
      'Sin conexión. Tu intento está guardado y se enviará al volver';

  @override
  String get gameSubmitWaiting =>
      'Sin conexión. Tu tablero terminado está guardado y se enviará al volver';

  @override
  String get puzzleScoreboardLabel => 'Puntuaciones de hoy';

  @override
  String get puzzleScoreboardEmpty => 'Hoy todavía no ha terminado nadie';

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
      'hoy siempre se comparte con tus amigos. Esto abre todo lo anterior';

  @override
  String get momentComposerVideo => 'Vídeo';

  @override
  String get momentComposerErrorTooBig =>
      'Ese vídeo es muy grande. 20 MB máximo';

  @override
  String get momentActivityPostedHighlightSelf => 'Has publicado un momento';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'Has sumado un punto: $tag';
  }

  @override
  String momentActivityGameSolved(String game, String name) {
    return '$name ha resuelto $game';
  }

  @override
  String momentActivityGameSolvedSelf(String game) {
    return 'Has resuelto $game';
  }

  @override
  String momentActivityGameMissed(String game, String name) {
    return '$name no ha resuelto $game';
  }

  @override
  String momentActivityGameMissedSelf(String game) {
    return 'No has resuelto $game';
  }

  @override
  String momentActivityCodeSolved(String name) {
    return '$name ha descifrado el código';
  }

  @override
  String get momentActivityCodeSolvedSelf => 'Has descifrado el código';

  @override
  String momentActivityCodeMissed(String name) {
    return '$name no ha descifrado el código';
  }

  @override
  String get momentActivityCodeMissedSelf => 'No has descifrado el código';

  @override
  String pointLineSelf(Object tag) {
    return 'Tú · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => '¿Qué ha pasado?';

  @override
  String get pointComposerNoteHint => 'Elige una arriba y cuéntalo';

  @override
  String get pointComposerAdd => 'Añadir un punto';

  @override
  String get pointComposerAddPhoto => 'añadir foto';

  @override
  String get pointsBoardAdd => 'Añadir un punto';

  @override
  String get pointsExplainerOpen => '¿Qué es esto?';

  @override
  String get pointsExplainerTitle => 'El juego de los puntos';

  @override
  String get pointsExplainerIntro =>
      'Una broma recurrente con marcador. Cuando te pasa algo (bueno, malo o simplemente raro), lo apuntas y queda en el tablero ese día.';

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
  String get pointsExplainerGotIt => 'Entendido';

  @override
  String get momentTagFateExample => 'Me encontré a mi dentista en otro país';

  @override
  String get momentTagJinxExample => 'Lavé el coche y llovió a las cuatro';

  @override
  String get momentTagLuckExample => 'Cogí el tren por dos segundos';

  @override
  String get momentTagCalledItExample =>
      'Dije que la secuela sería un fracaso, y lo fue';

  @override
  String get momentTagNpcExample => 'Le dije ‘igualmente’ al camarero';

  @override
  String feedBoardEditionHint(Object number) {
    return 'Día $number del feed';
  }

  @override
  String get feedBoardHighlightsHint => 'fotos y vídeos que merecen un vistazo';

  @override
  String get profileVisibilityScreenPointsLabel => 'mis puntos';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'si los puntos que apuntas aparecen en los tableros de tus amigos';

  @override
  String get momentComposerEditPhoto => 'Editar recorte';

  @override
  String get archiveScreenTitle => 'Tu archivo';

  @override
  String get archiveScreenEnd => 'Eso es todo';

  @override
  String get archiveScreenEmptyTitle => 'Aún no has guardado nada';

  @override
  String get archiveScreenEmptyBody =>
      'Los momentos desaparecen de los tableros de tus amigos tras un día, pero aquí se quedan para ti.';

  @override
  String get archiveScreenEmptyFriendTitle => 'Aquí no hay nada';

  @override
  String get archiveScreenEmptyFriendBody =>
      'Todavía no ha publicado nada que puedas ver.';

  @override
  String get archiveScreenPrivateTitle => 'Su pasado es privado';

  @override
  String get archiveScreenPrivateBody => 'Aún puedes ver lo que publique hoy.';

  @override
  String get archiveScreenNotFriendTitle => 'No sois amigos';

  @override
  String get archiveScreenNotFriendBody =>
      'Solo puedes mirar atrás en los días de un amigo.';

  @override
  String get archiveScreenErrorTitle => 'No se pudo cargar';

  @override
  String get archiveScreenErrorBody =>
      'Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get feedBoardOpenArchive => 'Archivo';

  @override
  String get feedBoardGamesLabel => 'Juegos';

  @override
  String get feedBoardGamesOpen => 'Clasificación';

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
  String get gamesLoadFailed => 'No se pudieron cargar los juegos de hoy';

  @override
  String get gamesRetry => 'Reintentar';

  @override
  String get gameQueensName => 'Reinas';

  @override
  String get gameQueensRule =>
      'Una corona por fila, columna y color, sin tocarse';

  @override
  String get gameTangoName => 'Tango';

  @override
  String get gameTangoRule => 'tres soles, tres lunas, nunca tres seguidos';

  @override
  String get gameZipName => 'Zip';

  @override
  String get gameZipRule =>
      'una línea por todas las casillas, los números en orden';

  @override
  String get gameSudokuName => 'Mini sudoku';

  @override
  String get gameSudokuRule => 'del 1 al 6 una vez por fila, columna y caja';

  @override
  String get gameCodeName => 'El código';

  @override
  String get gameStatusUnplayed => 'Sin jugar';

  @override
  String get gameStatusUnfinished => 'En curso';

  @override
  String get gameStatusGaveUp => 'Se rindió';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'Pausa';

  @override
  String get gameResume => 'Continuar';

  @override
  String get gamePausedTitle => 'En pausa';

  @override
  String get gamePausedBody => 'El reloj está parado y el tablero oculto';

  @override
  String get gameUndo => 'Deshacer';

  @override
  String get gameClear => 'borrar';

  @override
  String get gameHint => 'Pista';

  @override
  String get gameNotes => 'notas';

  @override
  String get gameErase => 'borrar';

  @override
  String get gameAutoCross => 'Cruces automáticas';

  @override
  String get gameGiveUp => 'Rendirse';

  @override
  String get gameGiveUpTitle => '¿Mostrar la solución?';

  @override
  String get gameGiveUpBody =>
      'El tablero de hoy se cierra y queda como no resuelto.';

  @override
  String get gameGiveUpCancel => 'Seguir';

  @override
  String get gameGiveUpConfirm => 'Mostrar';

  @override
  String gameSolvedTitle(Object time) {
    return 'Resuelto en $time';
  }

  @override
  String get gameGaveUpTitle => 'La solución de hoy';

  @override
  String get gameFirstInToday => 'El primero de hoy';

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
  String get gameStandingsLabel => 'Tiempos de hoy';

  @override
  String get gameStandingsEmpty => 'Nadie lo ha terminado todavía';

  @override
  String get gameShare => 'Copiar resultado';

  @override
  String get gameShareCopied => 'Copiado. Pégaselo a un amigo';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number · $time';
  }

  @override
  String get gameBackToHub => 'Todos los juegos';

  @override
  String get gameElapsedSemantic => 'Tiempo transcurrido';

  @override
  String get gameErrorNotSolved => 'Ese tablero aún no está terminado';

  @override
  String get gameErrorAlreadyFinished => 'Ya terminaste el de hoy';

  @override
  String get gameErrorNoHint => 'Esta no tiene pistas';

  @override
  String get gameHintWrong => 'Esta estaba mal, así que se ha borrado.';

  @override
  String get gameHintWrongMore =>
      'Hay más cosas que arreglar. Vuelve a pedir cuando quieras.';

  @override
  String get gameHintWrongLast => 'Todo lo demás que has puesto está bien.';

  @override
  String get gameHintReveal =>
      'Ninguna regla decide una casilla por sí sola todavía, así que aquí tienes una.';

  @override
  String get gameHintQueensRegion =>
      'Solo queda un sitio para una corona en este color.';

  @override
  String get gameHintQueensRow =>
      'Solo queda un sitio para una corona en esta fila.';

  @override
  String get gameHintQueensCol =>
      'Solo queda un sitio para una corona en esta columna.';

  @override
  String get gameHintQueensRegionInRow =>
      'Este color solo cabe en esta fila, así que el resto de la fila no puede tener corona.';

  @override
  String get gameHintQueensRegionInCol =>
      'Este color solo cabe en esta columna, así que el resto de la columna no puede tener corona.';

  @override
  String get gameHintQueensRowInRegion =>
      'Esta fila solo tiene sitio en un color, así que el resto de ese color no puede tener corona.';

  @override
  String get gameHintQueensColInRegion =>
      'Esta columna solo tiene sitio en un color, así que el resto de ese color no puede tener corona.';

  @override
  String get gameHintStarsRegion =>
      'A este color solo le queda sitio para las estrellas que aún necesita.';

  @override
  String get gameHintStarsRow =>
      'A esta fila solo le queda sitio para las estrellas que aún necesita.';

  @override
  String get gameHintStarsCol =>
      'A esta columna solo le queda sitio para las estrellas que aún necesita.';

  @override
  String get gameHintTangoEqual =>
      'Un signo = significa que las dos casillas son iguales.';

  @override
  String get gameHintTangoCross =>
      'Un signo × significa que las dos casillas son opuestas.';

  @override
  String get gameHintTangoPair =>
      'Hay dos iguales seguidas, así que la siguiente tiene que ser la otra.';

  @override
  String get gameHintTangoSandwich =>
      'Las casillas de los lados son iguales, así que la del medio tiene que ser la otra.';

  @override
  String get gameHintTangoRowSuns => 'Esta fila ya tiene sus tres soles.';

  @override
  String get gameHintTangoRowMoons => 'Esta fila ya tiene sus tres lunas.';

  @override
  String get gameHintTangoColSuns => 'Esta columna ya tiene sus tres soles.';

  @override
  String get gameHintTangoColMoons => 'Esta columna ya tiene sus tres lunas.';

  @override
  String gameHintLatinBox(int digit) {
    return 'Este es el único sitio para un $digit en esta caja.';
  }

  @override
  String gameHintLatinRow(int digit) {
    return 'Este es el único sitio para un $digit en esta fila.';
  }

  @override
  String gameHintLatinCol(int digit) {
    return 'Este es el único sitio para un $digit en esta columna.';
  }

  @override
  String get gameHintLatinOnly =>
      'Aquí solo cabe un número. Los demás ya están en su fila, columna o caja.';

  @override
  String get gameHintLatinOnlyLines =>
      'Aquí solo cabe un número. Los demás ya están en su fila o columna.';

  @override
  String get gameHintLatinOnlySigns =>
      'Aquí solo cabe un número si cuentas su fila, su columna y los signos.';

  @override
  String get gameHintNonogramRowFill =>
      'Encaje como encaje la pista de esta fila, cubre esta casilla.';

  @override
  String get gameHintNonogramRowCross =>
      'Ninguna forma de encajar la pista de esta fila llega a esta casilla.';

  @override
  String get gameHintNonogramColFill =>
      'Encaje como encaje la pista de esta columna, cubre esta casilla.';

  @override
  String get gameHintNonogramColCross =>
      'Ninguna forma de encajar la pista de esta columna llega a esta casilla.';

  @override
  String get gameHintMinesStart =>
      'Empieza aquí. Esta casilla siempre es segura.';

  @override
  String get gameHintMinesSafe =>
      'Este número ya tiene todas sus minas con bandera, así que las demás casillas a su alrededor son seguras.';

  @override
  String get gameHintMinesFlag =>
      'Este número necesita que todas las casillas ocultas a su alrededor sean minas.';

  @override
  String get gameHintMinesProofSafe =>
      'Los números alrededor de esta casilla demuestran que es segura.';

  @override
  String get gameHintMinesProofMine =>
      'Los números alrededor de esta casilla demuestran que es una mina.';

  @override
  String get gameHintFlowPipe =>
      'Aquí tienes una tubería entera, de punto a punto.';

  @override
  String get gameHintPatchesOnly => 'En esta pista solo cabe un parche.';

  @override
  String get gameHintPatchesCell =>
      'Una casilla de aquí solo puede ser de esta pista, y eso le deja un único parche.';

  @override
  String get gameHintPatchesSqueeze =>
      'Los parches de alrededor dejan a esta pista una sola forma de encajar.';

  @override
  String get gameErrorGeneric =>
      'No se pudo conectar con los juegos. Inténtalo de nuevo';

  @override
  String get gameInfoOpen => 'Cómo se juega';

  @override
  String get gameInfoScoringTimed =>
      'Gana quien termina más rápido. El reloj se para si sales. Mismo tiempo, mismo puesto.';

  @override
  String get gameInfoScoringGuesses =>
      'Gana quien lo descifra con menos intentos. El tiempo no cuenta. Mismos intentos, mismo puesto.';

  @override
  String get gameInfoSameForEveryone => 'Hoy todos tienen el mismo puzle.';

  @override
  String get savedMessagesTitle => 'Mensajes guardados';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'ningún chat coincide con \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'Buscar chats';

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
  String get archivedChatsSheetTitle => 'Chats archivados';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'Chats archivados · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'Ya no hay nada archivado';

  @override
  String get pinnedBadgeLabel => 'FIJADA';

  @override
  String get chatRowActionMenuPinLabel => 'Fijar chat';

  @override
  String get chatRowActionMenuUnpinLabel => 'Desfijar chat';

  @override
  String get chatRowActionMenuArchiveLabel => 'Archivar chat';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'Desarchivar chat';

  @override
  String get messageActionMenuSaveLabel => 'Guardar';

  @override
  String get messageActionMenuUnsaveLabel => 'Quitar';

  @override
  String get roomScreenSaveLimitSnack =>
      'Demasiados mensajes guardados aquí. Quita uno primero';

  @override
  String get roomScreenSaveFailedSnack => 'No se pudo guardar ese mensaje';

  @override
  String get threadOverlaySaveLimitToast =>
      'Demasiados mensajes guardados aquí. Quita uno primero';

  @override
  String get threadOverlaySaveFailedToast => 'No se pudo guardar ese mensaje';

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
  String get muteSheetTitle => 'Silenciar chat';

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
  String get muteSheetDurationLabel => 'Durante cuánto tiempo';

  @override
  String get muteDurationHour => '1 hora';

  @override
  String get muteDurationEightHours => '8 horas';

  @override
  String get muteDurationWeek => '1 semana';

  @override
  String get muteDurationAlways => 'Siempre';

  @override
  String get muteSheetConfirmButton => 'Silenciar';

  @override
  String get muteSheetSaveButton => 'Guardar';

  @override
  String get muteSheetUnmuteButton => 'Reactivar';

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
  String get chatRowActionMenuMuteLabel => 'Silenciar chat';

  @override
  String get chatRowActionMenuUnmuteLabel => 'Reactivar chat';

  @override
  String get roomInfoScreenMuteLabel => 'SILENCIO';

  @override
  String get roomInfoScreenNotMutedRow => 'Sin silenciar';

  @override
  String get attachmentMenuLocationLabel => 'Ubicación';

  @override
  String get locationSheetSendCurrent => 'Enviar ubicación actual';

  @override
  String get locationSheetSendCurrentDetail => 'Dónde estás ahora mismo';

  @override
  String get locationSheetLiveHeading => 'Compartir en directo';

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
      'Pueden compartir dónde están, incluso en directo hasta 8 horas';

  @override
  String get childPolicyScreenLocationOffDesc =>
      'No pueden compartir dónde están';

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
  String get composerCaptureLockedCancel => 'Cancelar';

  @override
  String get composerCaptureViewOnceLabel => 'Reproducir una vez';

  @override
  String get composerCaptureViewOnceVoiceHint =>
      'Solo podrá escucharlo una vez';

  @override
  String get composerCaptureViewOnceVideoHint => 'Solo podrá verlo una vez';

  @override
  String get composerCapturePauseLabel => 'Pausar grabación';

  @override
  String get composerCaptureResumeLabel => 'Reanudar grabación';

  @override
  String get composerCaptureFlashLabel => 'Flash';

  @override
  String get composerCaptureReviewPlayLabel => 'Reproducir grabación';

  @override
  String get composerCaptureReviewStopLabel => 'Detener reproducción';

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
  String get videoNoteMessagePlayLabel => 'Reproducir nota de vídeo';

  @override
  String get videoNoteMessagePauseLabel => 'Pausar nota de vídeo';

  @override
  String get videoNoteMessageLoadingLabel => 'Cargando nota de vídeo';

  @override
  String get videoNoteMessageUnavailableLabel => 'Nota de vídeo no disponible';

  @override
  String get videoNoteMessageRetryLabel => 'Reintentar nota de vídeo';

  @override
  String get videoNoteMessageRetryHint => 'Toca para reintentar';

  @override
  String get videoNoteMessageDiscardLabel => 'Descartar nota de vídeo';

  @override
  String get videoNoteScrubHint =>
      'Aleja el dedo del círculo para avanzar con más precisión';

  @override
  String get videoNoteScrubHalf => 'Avance a media velocidad';

  @override
  String get videoNoteScrubFine => 'Avance preciso';

  @override
  String videoNoteSpeedLabel(String speed) {
    return 'Velocidad de reproducción $speed';
  }

  @override
  String get videoNoteAutoAdvanceOn => 'Reproducción automática: sí';

  @override
  String get videoNoteAutoAdvanceOff => 'Reproducción automática: no';

  @override
  String get videoNoteAutoAdvanceSemanticLabel =>
      'Reproducir automáticamente la siguiente nota de vídeo';

  @override
  String get composerCaptureStartRecordingLabel => 'Empezar a grabar';

  @override
  String get attachmentMenuVideoNoteLabel => 'Nota de vídeo';

  @override
  String get cameraScreenPhotoModeLabel => 'Foto';

  @override
  String get cameraScreenVideoModeLabel => 'Vídeo';

  @override
  String get cameraScreenStartRecordingLabel => 'Empezar a grabar';

  @override
  String get cameraScreenStopRecordingLabel => 'Detener la grabación';

  @override
  String get cameraScreenVideoFailedSnack => 'No se pudo grabar ese vídeo.';

  @override
  String get scheduleSheetTitle => 'Programar mensaje';

  @override
  String get scheduleSheetSubtitle => 'Escríbelo ahora. Sale cuando tú digas.';

  @override
  String get scheduleSheetWhenLabel => 'Cuándo';

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
  String get scheduleSheetConfirmButton => 'Programar';

  @override
  String get scheduleSheetSaveButton => 'Guardar';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'Se envía $when';
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
  String get scheduleTimePickerTitle => 'Elige fecha y hora';

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
  String get scheduledListTitle => 'Programados';

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
  String get scheduleEditTitle => 'Editar mensaje';

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
  String get scheduledListShowAs => 'Mostrar como';

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
  String get serverScreenSubtitle => 'Donde viven tu cuenta y tus mensajes';

  @override
  String get serverOnboardingTitle => 'elige un servidor.';

  @override
  String get serverOnboardingSubtitle =>
      'Esta versión no trae ninguno: apúntala al tuyo';

  @override
  String get serverStatusConnected => 'Conectado';

  @override
  String get serverStatusDisconnected => 'Sin conexión';

  @override
  String get serverBadgeDefault => 'Predeterminado';

  @override
  String get serverBadgeSelfHosted => 'Autoalojado';

  @override
  String get serverNoneConfigured => 'Aún sin servidor';

  @override
  String get serverActiveNowLabel => 'En uso';

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
  String get serverAddressPaste => 'Pegar';

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
  String get serverInsecureTitle => 'Sin cifrar';

  @override
  String get serverInsecureBody =>
      'Los teléfonos bloquean http sin cifrar, así que esta dirección no conectará en iOS ni Android. Usa https o llega a tu servidor por un túnel.';

  @override
  String get serverTestCta => 'Probar conexión';

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
  String get serverConnectCta => 'Conectar';

  @override
  String get serverConnectAnywayCta => 'Conectar igualmente';

  @override
  String get serverAlreadyConnectedCta => 'Ya conectado';

  @override
  String get serverUseDefaultCta => 'Usar el servidor predeterminado';

  @override
  String get serverChangeCta => 'Cambiar servidor';

  @override
  String get serverAdvancedLabel => 'Avanzado';

  @override
  String get serverSiteUrlExplain =>
      'La mayoría de los servidores responden todo en una sola dirección. Rellena esto solo si el tuyo sirve las acciones HTTP en otra.';

  @override
  String get serverSiteUrlHint => 'Igual que arriba';

  @override
  String get serverSectionRecent => 'Recientes';

  @override
  String get serverRecentForget => 'Olvidar este servidor';

  @override
  String get serverSwitchWarningTitle => 'Cambiar cierra tu sesión';

  @override
  String get serverSwitchWarningBody =>
      'Las cuentas y los chats pertenecen a un solo servidor. Este dispositivo cierra sesión, borra lo que descargó y empieza de cero. No se borra nada en ninguno de los dos servidores.';

  @override
  String get serverSwitchRolledBackTitle => 'No se pudo conectar';

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
  String get serverRoleExplainAction => '¿Qué significa esto?';

  @override
  String get serverBadgeRibbonHomeserver => 'CASA';

  @override
  String get serverBadgeRibbonSelfHosted => 'PROPIO';

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
  String get loginScreenUsePasswordInstead => 'Usar una contraseña';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      'Abre MonkeyHub en tu teléfono, ve a tu perfil, toca «Escanea para entrar» y apunta la cámara aquí, o escribe el código de abajo.';

  @override
  String get deviceLoginScreenWaiting => 'Esperando aprobación…';

  @override
  String get deviceLoginScreenApproved => 'Aprobado. Iniciando sesión…';

  @override
  String get deviceLoginScreenDenied =>
      'Solicitud de inicio de sesión rechazada en tu teléfono';

  @override
  String get deviceLoginScreenGenericError =>
      'Algo salió mal. Prueba con un código nuevo';

  @override
  String get profileScreenScanToSignInLabel => 'Escanea para entrar';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro =>
      'Apunta la cámara al código que aparece en tu ordenador o escríbelo abajo.';

  @override
  String get deviceLoginScanScreenScanButtonLabel => 'Escanear código';

  @override
  String get deviceLoginScanScreenConfirmTitle =>
      '¿Iniciar sesión en este dispositivo?';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return '$deviceInfo quiere iniciar sesión con tu cuenta. Apruébalo solo si eres tú, ahora mismo.';
  }

  @override
  String get deviceLoginScanScreenApproveButton => 'Aprobar';

  @override
  String get deviceLoginScanScreenDenyButton => 'Rechazar';

  @override
  String get deviceLoginScanScreenSuccess =>
      'Sesión iniciada en tu otro dispositivo';

  @override
  String get deviceLoginScanScreenGenericError =>
      'No se pudo aprobar. Inténtalo de nuevo';

  @override
  String get authErrorDeviceLoginInvalid => 'Ese código no es correcto.';

  @override
  String get authErrorDeviceLoginExpired =>
      'Ese código ha caducado. Consigue uno nuevo en el otro dispositivo.';

  @override
  String get deviceLoginScanScreenDeniedConfirmation =>
      'Solicitud de inicio de sesión rechazada';

  @override
  String get roomAdminRoleAdmin => 'Admin';

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
  String get roomAdminTransferConfirmCta => 'Transferir';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return '¿Expulsar a $name?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'Pierde el acceso al grupo y a todo lo que hay dentro. Se le puede volver a invitar, o puede entrar con el enlace.';

  @override
  String get roomAdminRemoveConfirmCta => 'Expulsar';

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
  String get roomInviteCreateButton => 'Crear enlace';

  @override
  String get roomInviteRegenerateButton => 'Nuevo enlace';

  @override
  String get roomInviteRevokeButton => 'Revocar enlace';

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
  String get roomInviteRegenerateConfirm => 'Nuevo enlace';

  @override
  String get roomInviteRevokeHeadline => '¿Revocar este enlace?';

  @override
  String get roomInviteRevokeBody =>
      'Nadie nuevo podrá entrar con el enlace hasta que crees otro. Quien ya esté en el grupo se queda.';

  @override
  String get roomInviteRevokeConfirm => 'Revocar';

  @override
  String get roomInviteLimitsLabel => 'Límites';

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
  String get roomInvitePermissionsLabel => 'Permisos';

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
    return 'Caduca el $date';
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
  String get roomInviteFriendsInviteButton => 'Invitar';

  @override
  String get roomInviteFriendsSent => 'Invitado';

  @override
  String get roomInviteFriendsEmpty =>
      'Todos tus amigos ya están aquí o ya están invitados.';

  @override
  String get roomInviteFriendsNoMatch => 'Ningún amigo coincide con eso.';

  @override
  String get roomInviteFriendsDone => 'Listo';

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
      'Esperando a un padre o madre';

  @override
  String get roomInfoScreenInviteWithdraw => 'RETIRAR';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return 'De $inviter · $members miembros';
  }

  @override
  String get roomInvitationCardJoin => 'Unirme';

  @override
  String get discoverScreenJoinByCodeTitle => 'Unirse con un código';

  @override
  String get discoverScreenJoinByCodeSubtitle =>
      'Abre un grupo que alguien te ha compartido';

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
  String get joinInviteLookupButton => 'Continuar';

  @override
  String get joinInviteLookupFailed =>
      'No se ha podido comprobar el código. Revisa tu conexión e inténtalo de nuevo.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count miembros';
  }

  @override
  String get joinInviteJoinButton => 'Unirme al grupo';

  @override
  String get joinInviteRequestButton => 'Pedir entrar';

  @override
  String get joinInviteOpenNote =>
      'Podrás ver los mensajes del grupo en cuanto entres.';

  @override
  String get joinInviteApprovalNote =>
      'Un admin tiene que decir que sí antes de que puedas ver nada aquí dentro.';

  @override
  String get joinInviteOpenRoom => 'Abrir grupo';

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
  String get roomAdminYouSuffix => 'Tú';

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
  String get newChatMenuJoinSub => 'Abre un grupo compartido contigo';

  @override
  String get shareSheetTitle => 'Compartir con';

  @override
  String get shareSheetSuggestedHeading => 'Sugeridos';

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
  String get attachmentMenuPollLabel => 'Encuesta';

  @override
  String get attachmentMenuChecklistLabel => 'Lista';

  @override
  String get attachmentMenuEventLabel => 'Evento';

  @override
  String get interactionKindPoll => 'Encuesta';

  @override
  String get interactionKindQuiz => 'Cuestionario';

  @override
  String get interactionKindChecklist => 'Lista';

  @override
  String get interactionKindEvent => 'Evento';

  @override
  String get interactionBadgeAnonymous => 'Anónima';

  @override
  String get interactionBadgeMultiple => 'Varias';

  @override
  String get interactionBadgeClosed => 'Cerrada';

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
  String get interactionRespondentsTitlePoll => 'Quién votó';

  @override
  String get interactionRespondentsTitleChecklist => 'Quién marcó';

  @override
  String get interactionRespondentsTitleEvent => 'Quién respondió';

  @override
  String get interactionRespondentsFailed =>
      'No se pudo cargar quién respondió.';

  @override
  String get interactionRespondentsEmpty => 'Todavía no ha respondido nadie.';

  @override
  String get interactionFilterAll => 'Todos';

  @override
  String get interactionRsvpGoing => 'Voy';

  @override
  String get interactionRsvpMaybe => 'Quizá';

  @override
  String get interactionRsvpNo => 'No puedo';

  @override
  String get interactionComposePollTitle => 'Nueva encuesta';

  @override
  String get interactionComposePollTagline => 'Pregunta a la sala';

  @override
  String get interactionComposeChecklistTitle => 'Nueva lista';

  @override
  String get interactionComposeChecklistTagline => 'Una lista que todos marcan';

  @override
  String get interactionComposeEventTitle => 'Nuevo evento';

  @override
  String get interactionComposeEventTagline => 'Mira quién viene';

  @override
  String get interactionComposeQuestionLabel => 'Pregunta';

  @override
  String get interactionComposeQuestionHint => '¿Qué quieres preguntar?';

  @override
  String get interactionComposeTitleLabel => 'Título';

  @override
  String get interactionComposeTitleHint => '¿Para qué es esta lista?';

  @override
  String get interactionComposeEventNameLabel => 'Evento';

  @override
  String get interactionComposeEventNameHint => '¿Qué se celebra?';

  @override
  String get interactionComposeOptionsLabel => 'Opciones';

  @override
  String get interactionComposeItemsLabel => 'Elementos';

  @override
  String interactionComposeOptionHint(int index) {
    return 'Opción $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return 'Elemento $index';
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
  String get interactionComposeMultipleTitle => 'Varias respuestas';

  @override
  String get interactionComposeMultipleSub => 'Elegir más de una';

  @override
  String get interactionComposeAnonymousTitle => 'Anónima';

  @override
  String get interactionComposeAnonymousOffSub => 'Todos ven quién votó';

  @override
  String get interactionComposeAnonymousOnSub => 'Nadie ve quién votó';

  @override
  String get interactionComposeQuizTitle => 'Modo cuestionario';

  @override
  String get interactionComposeQuizSub =>
      'Una sola respuesta correcta, sin cambiarla';

  @override
  String get interactionComposeExplanationLabel => 'Explicación';

  @override
  String get interactionComposeExplanationHint =>
      'Se muestra al responder (opcional)';

  @override
  String get interactionComposeOthersMayCheckTitle => 'Cualquiera puede marcar';

  @override
  String get interactionComposeOthersMayCheckSub => 'No solo tú';

  @override
  String get interactionComposeOthersMayAddTitle => 'Cualquiera puede añadir';

  @override
  String get interactionComposeOthersMayAddSub =>
      'La lista puede crecer después';

  @override
  String get interactionComposeWhenLabel => 'Cuándo';

  @override
  String get interactionComposePickStart => 'Elige el inicio';

  @override
  String get interactionComposePickEnd => 'Añadir un final (opcional)';

  @override
  String get interactionComposePlaceLabel => 'Lugar';

  @override
  String get interactionComposePlaceHint => '¿Dónde? (opcional)';

  @override
  String get interactionComposeSendPoll => 'Enviar encuesta';

  @override
  String get interactionComposeSendChecklist => 'Enviar lista';

  @override
  String get interactionComposeSendEvent => 'Enviar evento';

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
  String get messageReceiptsScreenTitle => 'Info del mensaje';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$read de $total lo han leído';
  }

  @override
  String get messageReceiptsEmptyState =>
      'Todavía no hay nadie más en esta sala';

  @override
  String get messageReceiptsSectionRead => 'Leído';

  @override
  String get messageReceiptsSectionDelivered => 'Entregado';

  @override
  String get messageReceiptsSectionSent => 'Enviado';

  @override
  String get messageReceiptsSectionHidden => 'Sin confirmación';

  @override
  String get messageReceiptsStateHidden => 'No se comparte';

  @override
  String get messageReceiptsStateWaiting => 'En espera';

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
      'Sebastian lee un mensaje escrito en otro idioma y te dice lo que pone, aquí, en tu teléfono, sin enviar nada a ninguna parte.';

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
      'Descarga única, se conserva hasta que la elimines';

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
  String get companionSectionGeneral => 'General';

  @override
  String get companionSectionStorage => 'Almacenamiento';

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
  String get companionRemoveConfirm => 'Eliminar';

  @override
  String get sebastianEnableLabel => 'Dejar que Sebastian traduzca';

  @override
  String get sebastianEnableDetail =>
      'Desactívalo para detenerlo sin borrar la descarga';

  @override
  String get sebastianLanguageSection => 'Traducir a';

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
  String get marloweBrainsSection => 'Cerebro';

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
  String get messageActionMenuTranslateLabel => 'Traducir';

  @override
  String get messageActionMenuShowOriginalLabel => 'Ver original';

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
    return 'Ya está en $language';
  }

  @override
  String get roomScreenTranslateRoomOffer =>
      '¿Traducir también el resto del chat?';

  @override
  String get roomScreenTranslateRoomOfferAction => 'Traducir todo';

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
  String get companionBrainInUse => 'En uso';

  @override
  String companionStatusUsingBrain(Object name) {
    return 'Usando $name';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name sigue descargándose. Ajustes › Compañeros';
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
  String get messageActionMenuTranslateAgainLabel => 'Traducir de nuevo';

  @override
  String get groupCallScreenShareLabel => 'Compartir';

  @override
  String get groupCallScreenStopShareLabel => 'Dejar de compartir';

  @override
  String get groupCallScreenShareStartingLabel => 'Iniciando…';

  @override
  String get groupCallScreenRingingLabel => 'Llamando…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name está compartiendo su pantalla';
  }

  @override
  String get groupCallScreenYouAreSharing => 'Estás compartiendo tu pantalla';

  @override
  String get groupCallScreenMinimizeLabel => 'Ocultar';

  @override
  String get groupCallScreenDrawLabel => 'Dibujar';

  @override
  String get callScreenControlShare => 'Compartir';

  @override
  String get callScreenControlStopShare => 'Detener';

  @override
  String get callScreenControlShareStarting => 'Iniciando…';

  @override
  String get screenShareStopDrawing => 'Dejar de dibujar';

  @override
  String get screenShareDrawBoardIdle => 'Los dibujos aparecen aquí';

  @override
  String get screenShareOverlayHint =>
      'Muestra los dibujos sobre otras apps mientras compartes';

  @override
  String get screenShareOverlayAllow => 'Permitir';

  @override
  String get callScreenControlDraw => 'Dibujar';

  @override
  String get callScreenControlMinimize => 'Ocultar';

  @override
  String get inCallPillOngoingCall => 'Llamada en curso';

  @override
  String get inCallPillReturn => 'Volver';

  @override
  String get inCallPillSharing => 'Compartiendo tu pantalla';

  @override
  String get inCallPillDrawSemanticLabel => 'Dibujar en la pantalla compartida';

  @override
  String get inCallPillStopSharingSemanticLabel => 'Dejar de compartir';

  @override
  String get screenShareUnsupported =>
      'Compartir pantalla no está disponible en este dispositivo';

  @override
  String get screenShareEphemeralWarning =>
      'La protección contra capturas está desactivada mientras compartes';

  @override
  String get screenShareNotificationTitle => 'Compartiendo tu pantalla';

  @override
  String get screenShareNotificationBody => 'Todos en la llamada pueden verla';

  @override
  String get screenShareNotificationStop => 'Detener';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name ya está compartiendo';
  }

  @override
  String get screenShareFailed => 'No se pudo empezar a compartir';

  @override
  String get screenSharePickerTitle => 'Comparte tu pantalla';

  @override
  String get screenSharePickerScreens => 'Pantallas';

  @override
  String get screenSharePickerWindows => 'Ventanas';

  @override
  String get screenSharePickerEmpty =>
      'Nada que compartir todavía. Permite la grabación de pantalla en Ajustes del Sistema e inténtalo de nuevo';

  @override
  String get gameTellFriends => 'Avisar a tus amigos';

  @override
  String get gameToldFriends => 'Ya lo saben';

  @override
  String get gameTellFriendsTitle => '¿Avisar a tus amigos?';

  @override
  String get gameTellFriendsBody =>
      'reciben una notificación con este resultado. solo se puede enviar una vez.';

  @override
  String get gameTellFriendsCancel => 'Ahora no';

  @override
  String get gameTellFriendsConfirm => 'Enviar';

  @override
  String get gameTellFriendsSent => 'Enviado, ya lo saben';

  @override
  String get gameTellFriendsPrivate =>
      'Tus resultados diarios son privados, nadie lo vería';

  @override
  String get gameTellFriendsFailed => 'No se pudo enviar';

  @override
  String get settingsScreenFriendActivityLabel => 'ACTIVIDAD DE AMIGOS';

  @override
  String get settingsScreenFriendActivityOnBody =>
      'momentos, puntos y resultados según los publican';

  @override
  String get settingsScreenFriendActivityOffBody =>
      'nada. Sus tableros siguen ahí cuando mires';

  @override
  String get searchScreenActionWithGrownUp => 'Con un adulto';

  @override
  String get newChatMenuSearchHint => 'Busca entre tus amigos';

  @override
  String get newChatMenuNoFriendsYet =>
      'Aún no tienes amigos. Busca gente en Descubrir';

  @override
  String get newChatMenuNoFriendsMatch => 'Ningún amigo coincide';

  @override
  String get newChatMenuOpenDmFailed =>
      'No se pudo abrir ese chat. Inténtalo de nuevo';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'Elige de tu gente';

  @override
  String get childPolicyScreenPickPersonHint => 'Busca un nombre o usuario';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'No queda nadie por añadir de tus amigos,\\nbusca a cualquier otra persona';

  @override
  String get childPolicyScreenPickPersonNoMatch => 'Nadie coincide';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'Tus amigos';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'Todos los demás';

  @override
  String get childPolicyScreenAddRoomLabel => 'Añadir una sala';

  @override
  String get childPolicyScreenPickRoomHeading => 'Añadir una sala';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'Una de tus propias salas. $name entra enseguida y puede leer y escribir ahí hasta que se lo quites.';
  }

  @override
  String get childPolicyScreenPickRoomHint => 'Busca entre tus salas';

  @override
  String get childPolicyScreenPickRoomEmpty => 'No te quedan salas por añadir';

  @override
  String get childPolicyScreenPickRoomNoMatch => 'Ninguna sala coincide';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name ya está en $room';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'No se pudo añadir esa sala. Inténtalo de nuevo';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'Esa sala no se puede añadir así';

  @override
  String get childPolicyScreenErrorRoomGone => 'Esa sala ya no existe';

  @override
  String get newChatMenuFriendsHeader => 'Amigos';

  @override
  String get roomChangeErrorGone =>
      'Esa sugerencia ya no está. Puede que un admin la haya respondido.';

  @override
  String get roomChangeErrorNotYours => 'Solo quien la hizo puede retirarla.';

  @override
  String get roomChangeErrorNoChange => 'Eso ya es lo que dice.';

  @override
  String get roomChangeErrorMissingValue => 'Así no se puede guardar.';

  @override
  String get roomChangeRequestsTitle => 'Sugerencias';

  @override
  String get roomChangeRequestsBlurb =>
      'Las han sugerido los miembros. No cambia nada hasta que digas que sí.';

  @override
  String get roomChangeRequestsEmpty => 'No hay sugerencias.';

  @override
  String get roomChangeRequestsApprove => 'USARLA';

  @override
  String get roomChangeRequestsReject => 'NO';

  @override
  String get roomChangeRequestsPhotoLabel => 'Nueva foto del grupo';

  @override
  String get roomChangeRequestsNameLabel => 'Nuevo nombre';

  @override
  String get roomChangeRequestsDescriptionLabel => 'Nueva descripción';

  @override
  String get roomChangeRequestsUnknownLabel =>
      'Un cambio que esta app aún no sabe mostrar';

  @override
  String get roomChangeRequestsClearedValue => 'Nada, quitarla';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name lo sugirió';
  }

  @override
  String get roomAdminChangeRequestsRow => 'Sugerencias';

  @override
  String get roomInfoScreenSuggestNote => 'Esto lo tiene que aprobar un admin';

  @override
  String get roomInfoScreenSuggestAvatarNote =>
      'Un admin aprueba las fotos nuevas';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic =>
      'Sugerir una foto del grupo';

  @override
  String get roomInfoScreenSuggestionSentToast => 'Enviado a los admins';

  @override
  String get roomInfoScreenSuggestionAppliedToast =>
      'Listo, puedes editar este grupo';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => 'Retirado';

  @override
  String get roomInfoScreenSuggestionsLabel => 'TUS SUGERENCIAS';

  @override
  String get roomInfoScreenSuggestionPhoto => 'Una foto nueva del grupo';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return 'Nombre: $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return 'Descripción: $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => 'Un cambio';

  @override
  String get roomInfoScreenSuggestionPending => 'Esperando a un admin';

  @override
  String get roomInfoScreenSuggestionWithdraw => 'Retirar';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name sugirió una nueva foto del grupo';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name sugirió un nuevo nombre';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name sugirió una nueva descripción';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sugerencias te esperan',
      one: '$count sugerencia te espera',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => 'Revisar';

  @override
  String get roomSuggestionBannerSemantic =>
      'Sugerencias de miembros pendientes de tu revisión';

  @override
  String get gameInfoPlay => 'Jugar';

  @override
  String get gameInfoContinue => 'Continuar';

  @override
  String get gameInfoSeeResult => 'Ver tu resultado';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return 'Entregado a $delivered de $total';
  }

  @override
  String get messageReceiptsSentLabel => 'Enviado';

  @override
  String messageReceiptsSemanticDeliveredThenRead(
    Object deliveredDay,
    Object deliveredTime,
    Object name,
    Object readDay,
    Object readTime,
  ) {
    return '$name lo recibió el $deliveredDay a las $deliveredTime y lo leyó el $readDay a las $readTime';
  }

  @override
  String get messageReceiptsStampRead => 'Leído';

  @override
  String get messageReceiptsStampDelivered => 'Entregado';

  @override
  String get roomInviteCustom => 'Otro';

  @override
  String roomInviteCustomHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count horas',
      one: '$count hora',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '$count día',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count usos',
      one: '$count uso',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => 'Horas';

  @override
  String get roomInviteUnitDays => 'Días';

  @override
  String get roomInviteStepperIncrease => 'Aumentar';

  @override
  String get roomInviteStepperDecrease => 'Disminuir';

  @override
  String get recordsLabel => 'Histórico';

  @override
  String get recordsBlurb => 'Lo mejor que nadie ha hecho: tú y tus amigos';

  @override
  String recordsYourBest(Object value) {
    return 'El tuyo $value';
  }

  @override
  String get recordsNoneYet => 'Nadie todavía';

  @override
  String get recordsEmpty =>
      'Resuelve cualquier juego y tu mejor marca aparecerá aquí.';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resueltos',
      one: '$count resuelto',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return 'Logrado el $date';
  }

  @override
  String recordsReactSemantic(Object name) {
    return 'Reaccionar al récord de $name';
  }

  @override
  String get recordsReactFailed => 'No se pudo reaccionar';

  @override
  String get recordsLoadFailed => 'No se pudieron cargar los récords';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game: récord de $value de $name';
  }

  @override
  String get appearanceLabel => 'Apariencia';

  @override
  String get appearanceMatchDevice => 'Como el dispositivo';

  @override
  String get appearanceMatchDeviceSub =>
      'Claro de día, oscuro de noche, como tu móvil';

  @override
  String get appearanceOneTheme => 'Un solo tema';

  @override
  String get appearanceOneThemeSub => 'El mismo aspecto todo el día';

  @override
  String get appearanceLightSlot => 'Modo claro';

  @override
  String get appearanceDarkSlot => 'Modo oscuro';

  @override
  String get appearanceNow => 'Ahora';

  @override
  String appearanceAutoValue(Object name) {
    return 'Auto · $name';
  }

  @override
  String get themeScreenAssignHint =>
      'toca un tema para usarlo en modo claro u oscuro · ⛶ para vista completa';

  @override
  String get themeScreenCarouselUseLight => 'USAR EN MODO CLARO';

  @override
  String get themeScreenCarouselUseDark => 'USAR EN MODO OSCURO';

  @override
  String get themeScreenCarouselIsLight => 'TU TEMA CLARO';

  @override
  String get themeScreenCarouselIsDark => 'TU TEMA OSCURO';

  @override
  String get onboardingThemeTitle => 'hazlo tuyo.';

  @override
  String get onboardingThemeBody =>
      'elige un estilo. puedes cambiarlo cuando quieras en ajustes.';

  @override
  String get onboardingThemeYourTheme => 'TU TEMA';

  @override
  String get onboardingThemeContinue => 'CONTINUAR';

  @override
  String get dropHintNoTarget => 'Suéltalo sobre un chat para enviarlo';

  @override
  String get dropNothingToSend => 'Aquí no hay nada que se pueda enviar';

  @override
  String dropSendPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar $count fotos',
      one: 'Enviar foto',
    );
    return '$_temp0';
  }

  @override
  String dropSendVideos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar $count vídeos',
      one: 'Enviar vídeo',
    );
    return '$_temp0';
  }

  @override
  String dropSendAudio(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar $count audios',
      one: 'Enviar audio',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar $count archivos',
      one: 'Enviar archivo',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar $count elementos',
      one: 'Enviar elemento',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => 'Añadir al mensaje';

  @override
  String get dropSendLink => 'Añadir enlace';

  @override
  String dropTargetTo(String name) {
    return 'A $name';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos pasan de $size',
      one: '1 archivo pasa de $size',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => 'No se pueden enviar carpetas';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se omiten $count archivos vacíos',
      one: 'Se omite un archivo vacío',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => 'Aquí no se permiten adjuntos';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count se enviarán como archivos',
      one: 'Se enviará como archivo',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pueden no verse en todos los dispositivos',
      one: 'Puede no verse en todos los dispositivos',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => 'foto';

  @override
  String get dropKindVideo => 'vídeo';

  @override
  String get dropKindAudio => 'audio';

  @override
  String get dropKindFile => 'archivo';

  @override
  String get dropKindFolder => 'carpeta';

  @override
  String get dropKindText => 'texto';

  @override
  String get dropKindLink => 'enlace';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count archivos no caben en este envío',
      one: '1 archivo no cabe en este envío',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed =>
      'No se ha podido hacer. Inténtalo de nuevo.';

  @override
  String get expressionBackspace => 'Borrar';

  @override
  String get expressionCreateSticker => 'Crear un sticker';

  @override
  String get expressionDeleteSticker => 'Eliminar de mis stickers';

  @override
  String get expressionFavorite => 'Añadir a favoritos';

  @override
  String get expressionFavorited => 'Añadido a favoritos';

  @override
  String get expressionFavorites => 'Favoritos';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF: $title';
  }

  @override
  String get expressionLoadFailed =>
      'No se ha podido cargar. Comprueba tu conexión.';

  @override
  String get expressionMediaNotAllowed =>
      'Tus ajustes familiares no permiten enviar imágenes.';

  @override
  String get expressionMyStickers => 'Mis stickers';

  @override
  String get expressionNoFavorites =>
      'Mantén pulsado un GIF o sticker para añadirlo a favoritos.';

  @override
  String get expressionNoRecents =>
      'Los GIF y stickers que envíes aparecerán aquí.';

  @override
  String get expressionNoResults => 'Sin resultados';

  @override
  String get expressionNoStickers => 'Aún no hay stickers.';

  @override
  String get expressionOpenPanel => 'Emojis, GIF y stickers';

  @override
  String get expressionOptionsHint => 'Mostrar opciones';

  @override
  String expressionPackCredit(String author, String license) {
    return 'Arte: $author · $license';
  }

  @override
  String get expressionPlayGifHint => 'reproducir';

  @override
  String get expressionRecent => 'Recientes';

  @override
  String get expressionReport => 'Denunciar';

  @override
  String get expressionReported => 'Gracias, ya se ha denunciado.';

  @override
  String get expressionRetry => 'Reintentar';

  @override
  String get expressionSearchKlipy => 'Buscar en KLIPY';

  @override
  String get expressionShowKeyboard => 'Mostrar teclado';

  @override
  String get expressionSuggestionsLabel => 'Stickers sugeridos';

  @override
  String get expressionTabEmoji => 'Emojis';

  @override
  String get expressionTabGifs => 'GIF';

  @override
  String get expressionTabStickers => 'Stickers';

  @override
  String get expressionTrending => 'Tendencias';

  @override
  String get expressionUnfavorite => 'Quitar de favoritos';

  @override
  String get expressionUnfavorited => 'Quitado de favoritos';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return 'Sticker $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel =>
      'Reproducir GIF y stickers automáticamente';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      'Se quedan quietos hasta que tocas uno. Ahorra datos.';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'Los GIF y stickers animados se reproducen solos. Reducir movimiento los pausa.';

  @override
  String get settingsAlbumCardsLabel => 'Álbumes de fotos como tarjetas';

  @override
  String get settingsAlbumCardsOffBody =>
      'Varias fotos en un mensaje se muestran en cuadrícula.';

  @override
  String get settingsAlbumCardsOnBody =>
      'Varias fotos en un mensaje llegan como una pila que recorres deslizando.';

  @override
  String get settingsStickerSuggestionsBody =>
      'Al escribir un solo emoji, aparecen stickers relacionados encima del campo de mensaje.';

  @override
  String get settingsStickerSuggestionsLabel => 'Stickers sugeridos';

  @override
  String get stickerMakerEmojiLabel => '¿Qué emoji es?';

  @override
  String get stickerMakerFailed =>
      'No se ha podido guardar el sticker. Inténtalo de nuevo.';

  @override
  String get stickerMakerMoreEmoji => 'Más emojis';

  @override
  String get stickerMakerPreview => 'Vista previa del sticker';

  @override
  String get stickerMakerRemoveBackground => 'Quitar fondo';

  @override
  String get stickerMakerSave => 'Guardar';

  @override
  String get stickerMakerSaved => 'Sticker añadido a Mis stickers';

  @override
  String get stickerMakerShape => 'Forma';

  @override
  String get stickerMakerShapeCircle => 'Círculo';

  @override
  String get stickerMakerShapeOriginal => 'Original';

  @override
  String get stickerMakerShapeRounded => 'Cuadrado redondeado';

  @override
  String get stickerMakerTitle => 'Nuevo sticker';

  @override
  String get stickerMakerTooMany =>
      'Has llegado al límite de stickers. Borra uno para hacer sitio.';

  @override
  String get expressionExpandPanel => 'Ampliar panel';

  @override
  String get expressionCollapsePanel => 'Reducir panel';

  @override
  String get expressionPackStore => 'Packs de stickers';

  @override
  String get expressionPackSearchHint => 'Buscar packs de stickers';

  @override
  String get expressionPacksAdded => 'Añadidos';

  @override
  String get expressionPacksMore => 'Más packs';

  @override
  String get expressionPackAdd => 'Añadir';

  @override
  String get expressionPackRemove => 'Quitar';

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
  String get expressionNoPacksFound => 'Ningún pack coincide';

  @override
  String get expressionAllPacksAdded => 'Ya has añadido todos los packs.';

  @override
  String expressionPackReorder(String title) {
    return 'Reordenar $title';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return 'Añadir el pack «$title»';
  }

  @override
  String expressionPackAddedToast(String title) {
    return '«$title» añadido a tus stickers';
  }

  @override
  String get expressionPacksFromKlipy => 'Más stickers de KLIPY';

  @override
  String expressionSearchKlipyFor(String query) {
    return 'Buscar «$query» en KLIPY';
  }

  @override
  String get expressionHideKeyboard => 'Ocultar teclado';

  @override
  String get expressionSearchStickers => 'Buscar stickers';

  @override
  String get expressionYourStickers => 'Tus stickers';

  @override
  String get chatListYesterday => 'Ayer';

  @override
  String get roomLayoutScreenCardsLayoutLabel => 'TARJETAS';

  @override
  String get roomLayoutScreenCardsLayoutDescription =>
      'cada sala en su propia tarjeta, con todos los detalles.';

  @override
  String get homeScreenTitle => 'Chats';

  @override
  String get glassScreenNativeLabel => 'Liquid Glass de iOS';

  @override
  String get glassScreenNativeOnBody =>
      'iOS dibuja la barra de pestañas. Los controles de abajo ajustan el resto de la app.';

  @override
  String get glassScreenNativeOffBody =>
      'MonkeyHub dibuja su propio cristal en toda la app, ajustado con los controles de abajo.';

  @override
  String get glassScreenHeading => 'Cristal';

  @override
  String get glassStyleHeader => 'Estilo';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody =>
      'El cristal de Apple, dibujado por iOS. Los botones de la app lo acompañan.';

  @override
  String get glassStyleFrostedTitle => 'Esmerilado';

  @override
  String get glassStyleFrostedBody =>
      'El cristal propio de MonkeyHub. Ajusta cada control a tu gusto.';

  @override
  String get glassStyleRecommended => 'Recomendado';

  @override
  String get glassStyleLiquidFooter =>
      'No hay nada que ajustar: iOS define el desenfoque, el tono y la luz. Elige Esmerilado para darle forma tú.';

  @override
  String get acctSectionPrivacy => 'Privacidad';

  @override
  String get acctSectionAccount => 'Cuenta';

  @override
  String get acctSectionFamily => 'Familia';

  @override
  String get acctSectionThisPhone => 'Este teléfono';

  @override
  String get acctRowVisibility => 'Visibilidad del perfil';

  @override
  String get acctRowBlocked => 'Usuarios bloqueados';

  @override
  String get acctRowApprovals => 'Aprobaciones';

  @override
  String get acctNothingWaiting => 'Nada pendiente';

  @override
  String get acctRowLinked => 'Cuentas vinculadas';

  @override
  String get acctRowScanToSignIn => 'Escanear para iniciar sesión';

  @override
  String get acctRowSetUpRecovery => 'Configurar frase de recuperación';

  @override
  String get acctRowChangeRecovery => 'Cambiar frase de recuperación';

  @override
  String get acctSignOut => 'Cerrar sesión';

  @override
  String get acctDeleteAccount => 'Eliminar cuenta';

  @override
  String get acctConfirmDelete => 'Toca de nuevo para eliminar';

  @override
  String get acctHandPhoneBack => 'Devolver este teléfono';

  @override
  String get acctMyGrownUps => 'Mis adultos';

  @override
  String get acctActionMessage => 'Mensaje';

  @override
  String get acctActionAddFriend => 'Añadir';

  @override
  String get acctActionRequested => 'Solicitado';

  @override
  String get acctActionAccept => 'Aceptar';

  @override
  String get acctActionNotAccepting => 'Cerrado';

  @override
  String get acctActionUnfriend => 'Quitar';

  @override
  String get acctActionBlock => 'Bloquear';

  @override
  String get acctActionReport => 'Denunciar';

  @override
  String get acctStatusFriends => 'Sois amigos';

  @override
  String get acctStatusRequestSent => 'Solicitud enviada';

  @override
  String get acctStatusWantsToConnect => 'Quiere ser tu amigo';

  @override
  String get acctStatusNotConnected => 'Sin conexión';

  @override
  String get acctPresenceOnline => 'En línea';

  @override
  String get acctPresenceAway => 'Ausente';

  @override
  String get acctPresenceOffline => 'Desconectado';

  @override
  String get acctProfilePhoto => 'Foto de perfil';

  @override
  String get acctSaveToPhotos => 'Guardar en Fotos';

  @override
  String get acctTakeSelfie => 'Hacer un selfie';

  @override
  String get acctChooseFromLibrary => 'Elegir de la fototeca';

  @override
  String get acctCancel => 'Cancelar';

  @override
  String get acctSave => 'Guardar';

  @override
  String get acctChange => 'Cambiar';

  @override
  String get acctNotNow => 'Ahora no';

  @override
  String get acctAddEmail => 'Añadir correo';

  @override
  String get acctEditNameTitle => 'Editar nombre';

  @override
  String get acctAddNameTitle => 'Añade tu nombre';

  @override
  String get acctEditEmailTitle => 'Editar correo';

  @override
  String get acctChangeUsernameTitle => '¿Cambiar nombre de usuario?';

  @override
  String get onboardingLookTitle => 'Hazlo tuyo';

  @override
  String get onboardingLookBody =>
      'Elige un estilo. Puedes cambiarlo cuando quieras en Ajustes.';

  @override
  String get onboardingEssentials => 'Esenciales';

  @override
  String get onboardingEssentialsSub => 'Sobrios y nativos';

  @override
  String get onboardingCharacters => 'Con carácter';

  @override
  String get onboardingCharactersSub => 'La misma app, más personalidad';

  @override
  String get onboardingLightMode => 'Modo claro';

  @override
  String get onboardingDarkMode => 'Modo oscuro';

  @override
  String get onboardingNow => 'Ahora';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingIconTitle => 'Tu icono de la app';

  @override
  String get onboardingIconBody =>
      'Conserva tu icono, deja que siga tu tema o elige cualquier otro.';

  @override
  String get onboardingIconIosNote =>
      'iOS muestra un aviso breve cada vez que cambia el icono.';

  @override
  String get onboardingGetStarted => 'Empezar';

  @override
  String get appIconMatchTheme => 'Según el tema';

  @override
  String get appIconCurrent => 'Actual';

  @override
  String get appIconSectionCollection => 'Colección MonkeyHub';

  @override
  String get appIconSectionThemes => 'Iconos de temas';

  @override
  String get appIconScreenTitle => 'Icono de la app';

  @override
  String get appIconMatchFooter =>
      'Según el tema cambia el icono junto con tu tema oscuro, así no cambia una y otra vez durante el día.';

  @override
  String get loginTitleReturning => 'Hola de nuevo';

  @override
  String get loginTitleFirst => 'Te damos la bienvenida a MonkeyHub';

  @override
  String get loginTitleSignUp => 'Crea tu cuenta';

  @override
  String get loginTitleReset => 'Restablece tu contraseña';

  @override
  String get loginSubtitleSignIn =>
      'Inicia sesión para seguir donde lo dejaste.';

  @override
  String get loginSubtitleFirst =>
      'Inicia sesión o crea una cuenta en segundos.';

  @override
  String get loginSubtitleSignUp =>
      'Solo necesitas un nombre de usuario y una contraseña.';

  @override
  String get loginSubtitleReset =>
      'Introduce tu frase de recuperación de 12 palabras y elige una contraseña nueva.';

  @override
  String get loginCtaSignIn => 'Iniciar sesión';

  @override
  String get loginCtaSignUp => 'Crear cuenta';

  @override
  String get loginCtaReset => 'Restablecer contraseña';

  @override
  String get loginNoAccountPrompt => '¿Eres nuevo? ';

  @override
  String get loginCreateAccountLink => 'Crea una cuenta';

  @override
  String get loginHaveAccountPrompt => '¿Ya tienes cuenta? ';

  @override
  String get loginSignInLink => 'Inicia sesión';

  @override
  String get loginForgotPassword => '¿Olvidaste la contraseña?';

  @override
  String get loginChildAccount => 'Configurar una cuenta infantil';

  @override
  String get loginBackToSignIn => 'Volver a iniciar sesión';

  @override
  String get loginWithPhone => 'Inicia sesión con tu teléfono';

  @override
  String get loginUsernameField => 'Nombre de usuario';

  @override
  String get loginPasswordField => 'Contraseña';

  @override
  String get loginConfirmPasswordField => 'Confirmar contraseña';

  @override
  String get loginNameField => 'Nombre (opcional)';

  @override
  String get loginRecoveryPhraseField =>
      'Tu frase de recuperación de 12 palabras';

  @override
  String get loginNewPasswordField => 'Contraseña nueva';

  @override
  String get roomHeaderStatusOnline => 'En línea';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '$count miembro',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => 'Ajustes';

  @override
  String get settingsHubAccountHintAdult =>
      'Perfil, familia, cuentas vinculadas y privacidad';

  @override
  String get settingsHubAccountHintChild => 'Perfil, privacidad y tus adultos';

  @override
  String get settingsHubSectionGeneral => 'General';

  @override
  String get settingsHubSectionNotifications => 'Notificaciones';

  @override
  String get settingsHubSectionCalls => 'Llamadas';

  @override
  String get settingsHubSectionAppearance => 'Apariencia';

  @override
  String get settingsHubSectionCompanions => 'Compañeros';

  @override
  String get settingsHubSectionChats => 'Chats';

  @override
  String get settingsHubSectionHelp => 'Ayuda y aspectos legales';

  @override
  String get settingsHubSectionAdvanced => 'Avanzado';

  @override
  String get settingsHubLanguage => 'Idioma';

  @override
  String get settingsHubCheckForUpdates => 'Buscar actualizaciones';

  @override
  String get settingsHubUpdateAvailable => 'Actualización disponible';

  @override
  String get settingsHubShowLinkUrls => 'Mostrar direcciones de enlaces';

  @override
  String get settingsHubShowLinkUrlsSubtitle =>
      'Muestra la dirección junto a cada vista previa';

  @override
  String get settingsHubPresenceDots => 'Mostrar quién está en línea';

  @override
  String get settingsHubPresenceDotsSubtitle =>
      'El punto en las fotos de perfil';

  @override
  String get settingsHubPush => 'Notificaciones push';

  @override
  String get settingsHubPushSubtitle =>
      'Mensajes nuevos, llamadas y solicitudes';

  @override
  String get settingsHubGameReminders => 'Recordatorio de juego diario';

  @override
  String get settingsHubGameRemindersSubtitle =>
      'Un aviso a la hora de comer si no has jugado';

  @override
  String get settingsHubFriendActivity => 'Actividad de amigos';

  @override
  String get settingsHubFriendActivitySubtitle =>
      'Momentos, puntos y resultados de tus amigos';

  @override
  String get settingsHubMenuBar => 'Icono en la barra de menús';

  @override
  String get settingsHubMenuBarSubtitle =>
      'Muestra los no leídos en la barra de menús';

  @override
  String get settingsHubCallStats => 'Mostrar estadísticas de llamada';

  @override
  String get settingsHubCallStatsSubtitle =>
      'Resolución, tasa de bits y ping durante la llamada';

  @override
  String get settingsHubTheme => 'Tema';

  @override
  String get settingsHubAppIcon => 'Icono de la app';

  @override
  String get settingsHubGlass => 'Cristal';

  @override
  String get settingsHubNavigation => 'Navegación';

  @override
  String get settingsHubMotion => 'Movimiento';

  @override
  String get settingsHubChatList => 'Lista de chats';

  @override
  String get settingsHubChatStyle => 'Estilo del chat';

  @override
  String get settingsHubBubbleStyle => 'Estilo de burbujas';

  @override
  String get settingsHubSpeakerColors => 'Colores por persona';

  @override
  String get settingsHubReplyStyle => 'Estilo de respuesta';

  @override
  String get settingsHubPrivacyPolicy => 'Política de privacidad';

  @override
  String get settingsHubTerms => 'Términos del servicio';

  @override
  String get settingsHubLicence => 'Licencia';

  @override
  String get settingsHubServer => 'Servidor';

  @override
  String get settingsHubLayoutRows => 'Filas';

  @override
  String get settingsHubLayoutCards => 'Tarjetas';

  @override
  String get settingsHubLayoutGrid => 'Cuadrícula';

  @override
  String get settingsHubNavTabBar => 'Barra de pestañas';

  @override
  String settingsHubThemeAuto(String name) {
    return 'Automático · $name';
  }

  @override
  String get chatListPageRowsSub =>
      'Una cara, un nombre y el último mensaje, como en Mensajes.';

  @override
  String get chatListPageCardsSub =>
      'Cada sala en su propia tarjeta, con todos los detalles.';

  @override
  String get chatListPageGridSub =>
      'Dos columnas de mosaicos. Más salas de un vistazo.';

  @override
  String get chatListPageLayoutHeader => 'Diseño';

  @override
  String get chatListPageFiltersHeader => 'Filtros';

  @override
  String get chatListPageChips => 'Chips';

  @override
  String get chatListPageChipsSub => 'Una fila de filtros, siempre a un toque.';

  @override
  String get chatListPageButton => 'Botón';

  @override
  String get chatListPageButtonSub =>
      'Un botón que abre los filtros cuando quieras.';

  @override
  String get chatListPageEmptyHeader => 'Salas vacías';

  @override
  String get chatListPagePlain => 'Simple';

  @override
  String get chatListPagePlainSub => 'Una sala sin mensajes se queda limpia.';

  @override
  String get chatListPageInitial => 'Inicial';

  @override
  String get chatListPageInitialSub =>
      'Una letra grande y tenue llena el rincón vacío.';

  @override
  String get chatListPageEmptyFooter => 'Se aplica al diseño en cuadrícula.';

  @override
  String get chatStylePageFooter =>
      'Cómo se dibujan la cabecera y el campo de mensaje.';

  @override
  String get chatStyleClassicSub => 'Cabecera sólida y campo de mensaje plano.';

  @override
  String get chatStyleCompactSub =>
      'Controles esmerilados flotan sobre la conversación.';

  @override
  String get bubbleTailedSub =>
      'Una cola en el último mensaje de cada tanda, como en Mensajes.';

  @override
  String get bubbleSoftSub => 'Sin cola. La tanda se une por sus esquinas.';

  @override
  String get bubblePillSub =>
      'Cápsulas totalmente redondeadas en cada mensaje.';

  @override
  String get bubbleSlabSub => 'Hombros cuadrados: nítidos y decididos.';

  @override
  String get replyStylePageFooter =>
      'Cómo muestra una respuesta el mensaje al que responde.';

  @override
  String get replyClassicSub =>
      'Una cita coloreada sobre el mensaje, al estilo WhatsApp.';

  @override
  String get replyPhantomSub =>
      'Un fantasma del original flota encima, unido por una curva.';

  @override
  String get replyStickySub =>
      'Una tarjeta pequeña e inclinada sujeta a la esquina.';

  @override
  String get replyComicSub => 'Una minibúrbuja con cola de cómic.';

  @override
  String get motionMatchDevice => 'Igual que el dispositivo';

  @override
  String get motionMatchDeviceCalmSub =>
      'Tu dispositivo pide reducir el movimiento ahora.';

  @override
  String get motionMatchDeviceFullSub =>
      'Tu dispositivo permite animaciones ahora.';

  @override
  String get motionFullSub => 'Cada rebote, deriva y floritura.';

  @override
  String get motionCalmSub =>
      'La decoración se queda quieta. Todo lo demás igual.';

  @override
  String get navigationPageFooter =>
      'Cómo te mueves entre Chats, Feed, Descubrir y Ajustes.';

  @override
  String get navTabBarSub => 'Siempre visible, a un toque de todo.';

  @override
  String get navOrbSub =>
      'Mantén y arrastra desde la esquina. Un gesto que se disfruta.';

  @override
  String get languageSystemLabel => 'Idioma del dispositivo';

  @override
  String get languagePageFooter =>
      'Menús y mensajes de la app. Los chats siguen en el idioma en que se escriban.';

  @override
  String get speakerPageFooter =>
      'Sabe quién habla de un vistazo en los grupos.';

  @override
  String get speakerOffSub => 'Todos escriben con la misma tinta.';

  @override
  String get speakerNamesSub =>
      'Cada persona tiene un color en su nombre y su foto.';

  @override
  String get speakerBubblesSub => 'Su color también llega a sus mensajes.';

  @override
  String get themePageAutoFooter =>
      'Los temas claros se usan en modo claro y los oscuros en modo oscuro.';

  @override
  String get themePageLightMode => 'Modo claro';

  @override
  String get themePageDarkMode => 'Modo oscuro';

  @override
  String get themePageEssentials => 'Esenciales';

  @override
  String get themePageEssentialsFooter =>
      'Tranquilos y nativos, en cinco colores.';

  @override
  String get themePageCharacters => 'Con carácter';

  @override
  String get themePageCharactersFooter =>
      'El mismo diseño, con personalidad propia. Mantén pulsado un tema para verlo.';

  @override
  String get themePageLightBadge => 'Claro';

  @override
  String get themePageDarkBadge => 'Oscuro';

  @override
  String get themePageInUse => 'En uso';

  @override
  String get themePageUseLight => 'Usar en modo claro';

  @override
  String get themePageUseDark => 'Usar en modo oscuro';

  @override
  String themePageUse(String name) {
    return 'Usar $name';
  }

  @override
  String get acctCaptureTitle => 'Protección de captura de pantalla';

  @override
  String get acctCaptureOnIos =>
      'Al grabar o duplicar se muestra un escudo de privacidad.';

  @override
  String get acctCaptureOnAndroid =>
      'Las capturas y grabaciones salen en negro.';

  @override
  String get acctCaptureOff =>
      'Las capturas y grabaciones funcionan con normalidad.';

  @override
  String get acctCaptureFooter =>
      'Las salas con mensajes temporales siempre lo activan.';

  @override
  String get acctActionPending => 'Pendiente';

  @override
  String get chatSwipePin => 'Fijar';

  @override
  String get chatSwipeUnpin => 'Desfijar';

  @override
  String get chatSwipeMute => 'Silenciar';

  @override
  String get chatSwipeUnmute => 'Activar';

  @override
  String get chatSwipeArchive => 'Archivar';

  @override
  String get appearanceMatchDeviceSubtitle =>
      'Claro de día y oscuro de noche, como tu teléfono';

  @override
  String get appearanceOneThemeSubtitle => 'El mismo estilo todo el día';

  @override
  String get riName => 'Nombre';

  @override
  String get riDescription => 'Descripción';

  @override
  String get riVisibility => 'Quién puede encontrarla';

  @override
  String get riPublic => 'Pública';

  @override
  String get riPublicSub => 'Cualquiera puede encontrarla en Descubrir';

  @override
  String get riPrivate => 'Privada';

  @override
  String get riPrivateSub => 'Solo pueden unirse las personas que invites';

  @override
  String get riMessageLife => 'Los mensajes desaparecen tras';

  @override
  String get riPassword => 'Contraseña';

  @override
  String get riRemovePassword => 'Quitar contraseña';

  @override
  String get riSetPassword => 'Establecer contraseña';

  @override
  String get riSharedContent => 'Contenido compartido';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count miembros',
      one: '1 miembro',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitados',
      one: '1 invitado',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => 'Retirar';

  @override
  String get riNotifications => 'Notificaciones';

  @override
  String get riTranslation => 'Traducción';

  @override
  String get riNameColours => 'Colores de nombres';

  @override
  String get riYouSuggested => 'Has sugerido';

  @override
  String get riTakeBack => 'Retirar';

  @override
  String get riLeaveRoom => 'Salir de la sala';

  @override
  String get riLeaving => 'Saliendo…';

  @override
  String get riDeleteRoom => 'Eliminar sala';

  @override
  String get riDeleting => 'Eliminando…';

  @override
  String get riEndConversation => 'Terminar conversación';

  @override
  String get riEnding => 'Terminando…';

  @override
  String get riActionCall => 'Llamar';

  @override
  String get riActionVideo => 'Vídeo';

  @override
  String get riActionMute => 'Silenciar';

  @override
  String get riActionUnmute => 'Activar';

  @override
  String get riActionMedia => 'Multimedia';

  @override
  String get riActionAdd => 'Añadir';

  @override
  String get roomHeaderStatusTyping => 'Escribiendo…';

  @override
  String get glassScreenLead => 'Cuánto se ve de lo que hay detrás.';

  @override
  String get transcriptDayToday => 'Hoy';

  @override
  String get acctRowDevices => 'Dispositivos';

  @override
  String get acctThisDevice => 'Este dispositivo';

  @override
  String get acctRemove => 'Quitar';

  @override
  String get acctRemoveDeviceTitle => '¿Quitar este dispositivo?';

  @override
  String get acctRemoveAllTitle => '¿Quitar todos los demás dispositivos?';

  @override
  String get acctRemoveAll => 'Quitar todos';

  @override
  String get acctActiveNow => 'Activo ahora';

  @override
  String get acctLoading => 'Cargando…';

  @override
  String get acctDevicesLoadFailed => 'No se pudieron cargar tus dispositivos.';

  @override
  String get acctNoNotifications => 'Las notificaciones no llegan a este';

  @override
  String get acctBlockedEmpty => 'No has bloqueado a nadie.';

  @override
  String get acctUnblock => 'Desbloquear';

  @override
  String get pvSubtitle =>
      'Controla lo que ven los demás y cómo pueden contactarte.';

  @override
  String get pvSectionProfile => 'Perfil';

  @override
  String get pvSectionMessages => 'Mensajes';

  @override
  String get pvSectionPeople => 'Personas';

  @override
  String get pvSectionFeed => 'Feed';

  @override
  String get pvAvatar => 'Foto de perfil';

  @override
  String get pvAvatarDesc => 'Quién puede ver tu foto';

  @override
  String get pvOnline => 'Estado en línea';

  @override
  String get pvOnlineDesc => 'Si apareces activo ahora';

  @override
  String get pvLastSeen => 'Última vez';

  @override
  String get pvLastSeenDesc => 'Cuándo estuviste por última vez';

  @override
  String get pvSendReceipts => 'Enviar confirmaciones de lectura';

  @override
  String get pvSendReceiptsDesc =>
      'Deja que otros vean cuándo has leído sus mensajes';

  @override
  String get pvShowReceipts => 'Mostrar confirmaciones de lectura';

  @override
  String get pvShowReceiptsDesc => 'Ver quién ha leído tus mensajes';

  @override
  String get pvShowReceiptsHint =>
      'Solo cuentan quienes envían confirmaciones de lectura.';

  @override
  String get pvFriendRequests => 'Solicitudes de amistad';

  @override
  String get pvFriendRequestsDesc => 'Quién puede enviarte solicitudes';

  @override
  String get pvSupervisedTitle => 'Tus adultos eligen esto';

  @override
  String get pvEveryone => 'Todos';

  @override
  String get pvFriends => 'Amigos';

  @override
  String get pvNobody => 'Nadie';

  @override
  String get pvOn => 'Sí';

  @override
  String get pvOff => 'No';

  @override
  String get pvAnyone => 'Cualquiera';

  @override
  String get pvHighlights => 'Mis momentos';

  @override
  String get pvHighlightsDesc =>
      'Si tus fotos y vídeos aparecen en los tableros de tus amigos del día';

  @override
  String get pvPuzzle => 'Mi puntuación del puzle';

  @override
  String get pvPuzzleDesc => 'Si tus amigos ven cómo te fue en el puzle diario';

  @override
  String get pvPast => 'Mi historial';

  @override
  String get pvPastDesc =>
      'Hoy siempre se comparte con amigos; esto abre todo lo anterior';

  @override
  String get pvPoints => 'Mis puntos';

  @override
  String get pvPointsDesc =>
      'Si los puntos que registras aparecen en los tableros de tus amigos';

  @override
  String get roomColorsPageTitle => 'Quién es quién';

  @override
  String get roomColorsPageHeader => 'El color en el que habla cada persona';

  @override
  String get roomColorsAuto => 'Automático';

  @override
  String get roomColorsReset => 'Volver a automático';

  @override
  String get roomColorsOffFooter =>
      'Los colores por persona están desactivados. Activarlos aquí los activa en todas las salas.';

  @override
  String roomColorsSharedWith(String name) {
    return 'Compartido con $name';
  }

  @override
  String get settingsScreenValueReplyQuote => 'Cita';

  @override
  String get replyQuoteSub =>
      'El original aparece arriba de la respuesta, dentro de su burbuja.';

  @override
  String get riTabMedia => 'Fotos y vídeos';

  @override
  String get riTabFiles => 'Archivos';

  @override
  String get riTabVoice => 'Mensajes de voz';

  @override
  String get riTabLinks => 'Enlaces';

  @override
  String get riTabSaved => 'Guardados';

  @override
  String get riNone => 'Ninguno';

  @override
  String get riSavedNote =>
      'Solo tú ves lo que guardas. Un mensaje fijado es lo contrario: lo ve toda la sala.';

  @override
  String get riOwnerNote => 'La medalla marca a quien creó esta sala.';

  @override
  String get famPair => 'Vincular';

  @override
  String get famRelease => 'Liberar';

  @override
  String get famSettings => 'Ajustes';

  @override
  String get famAddChild => 'Añadir un niño';

  @override
  String get famEmptyTitle => 'Aún no hay niños';

  @override
  String get famOnlineNow => 'En línea ahora';

  @override
  String get famNotPaired => 'Aún sin vincular';

  @override
  String get famJustNow => 'Justo ahora';

  @override
  String get apprEmptyTitle => 'Nada pendiente';

  @override
  String get apprEmptySub => 'Estás al día.';

  @override
  String get apprNotYet => 'Todavía no';

  @override
  String get apprAllow => 'Permitir';

  @override
  String get compGeneral => 'General';

  @override
  String get compStorage => 'Almacenamiento';

  @override
  String get compTranslateInto => 'Traducir al';

  @override
  String get compBrain => 'Cerebro';

  @override
  String laUnlinkProvider(String provider) {
    return 'Desvincular $provider';
  }

  @override
  String laLinkProvider(String provider) {
    return 'Vincular $provider';
  }

  @override
  String get laUnlink => 'Desvincular';

  @override
  String get laLink => 'Vincular';

  @override
  String get laLinked => 'Vinculada';

  @override
  String get laNotLinked => 'No vinculada';

  @override
  String rdSignOut(String name) {
    return 'Cerrar la sesión de $name';
  }

  @override
  String get rpContinue => 'Continuar';

  @override
  String get rpCopy => 'Copiar';

  @override
  String get rpSaved => 'Ya las guardé';

  @override
  String get rpBack => 'Atrás';

  @override
  String get rpKeep => 'Ahora no, mantener mi frase actual';

  @override
  String get childSetupHeadingIos => '¿Quién es?';

  @override
  String get childPairTitleIos => '¡Hola!';

  @override
  String get childPairBackIos => 'Volver a iniciar sesión';

  @override
  String get gamesHubTitle => 'Clasificación';

  @override
  String get gamesHubSubtitle =>
      'Los ganadores de hoy. Puzles nuevos cada día.';

  @override
  String get gameTellFriendsMessage =>
      'Recibirán una notificación con este resultado. Solo se puede enviar una vez.';

  @override
  String get deviceLoginScanTitleIos => 'Escanea para entrar';

  @override
  String get deviceLoginConfirmTitleIos =>
      '¿Iniciar sesión en este dispositivo?';

  @override
  String get socialHeroCreateIos => 'Ya casi';

  @override
  String get socialHeroLinkIos => 'Hola de nuevo';

  @override
  String socialSignInLinkIos(String provider) {
    return 'Iniciar sesión y vincular $provider';
  }

  @override
  String get serverTitleIos => 'Servidor';

  @override
  String get serverOnboardingTitleIos => 'Elige un servidor';

  @override
  String get approvalGateAskIos => 'Preguntar';

  @override
  String get friendRequestDraftIntroOutgoingSentence =>
      'Envía unas líneas. Podrá aceptarla o rechazarla.';

  @override
  String get requestDeclineIos => 'Rechazar';

  @override
  String get joinRequestAllowIos => 'Permitir';

  @override
  String get changeRequestUseIos => 'Usar';

  @override
  String get settingsSearchHint => 'Buscar en ajustes';

  @override
  String settingsSearchNoResults(String query) {
    return 'No hay resultados para “$query”';
  }

  @override
  String get settingsSearchAccount => 'Cuenta';

  @override
  String get settingsHubDiagnostics => 'Diagnóstico';

  @override
  String get settingsHubDiagnosticsSubtitle =>
      'Registros para resolver problemas e informar errores';

  @override
  String get settingsHubAdvancedFooter =>
      'Para resolver problemas y alojar tu propio servidor. Nada de esto hace falta a diario.';

  @override
  String get settingsSearchKwLanguage => 'idioma, lengua, región';

  @override
  String get settingsSearchKwUpdates => 'actualizar, versión, nueva';

  @override
  String get settingsSearchKwLinks => 'enlaces, url, dirección, vista previa';

  @override
  String get settingsSearchKwPresence =>
      'en línea, presencia, estado, punto, activo, verde';

  @override
  String get settingsSearchKwAutoplay =>
      'gif, animación, reproducción automática';

  @override
  String get settingsSearchKwStickers => 'stickers, emoji, sugerencias';

  @override
  String get settingsSearchKwPush => 'notificaciones, alertas, sonido';

  @override
  String get settingsSearchKwGames => 'juegos, recordatorio, diario';

  @override
  String get settingsSearchKwFriends => 'amigos, actividad, puntos';

  @override
  String get settingsSearchKwVideo => 'vídeo, llamada, calidad, cámara';

  @override
  String get settingsSearchKwStats => 'estadísticas, red, ping, depuración';

  @override
  String get settingsSearchKwTheme => 'tema, oscuro, claro, colores, noche';

  @override
  String get settingsSearchKwIcon => 'icono, logo, pantalla de inicio';

  @override
  String get settingsSearchKwGlass =>
      'cristal, desenfoque, esmerilado, transparencia';

  @override
  String get settingsSearchKwNavigation =>
      'barra de pestañas, navegación, menú';

  @override
  String get settingsSearchKwMotion =>
      'movimiento, animación, reducir movimiento';

  @override
  String get settingsSearchKwCompanions => 'ia, asistente, traducir, modelo';

  @override
  String get settingsSearchKwChatList =>
      'lista de chats, filas, tarjetas, cuadrícula';

  @override
  String get settingsSearchKwChatStyle => 'estilo, compacto, clásico';

  @override
  String get settingsSearchKwBubbles => 'burbujas, mensajes, forma';

  @override
  String get settingsSearchKwSpeakers => 'nombres, colores, grupos';

  @override
  String get settingsSearchKwReply => 'responder, cita, hilo';

  @override
  String get settingsSearchKwReport => 'error, problema, comentarios, ayuda';

  @override
  String get settingsSearchKwLegal => 'privacidad, términos, legal, licencia';

  @override
  String get settingsSearchKwServer =>
      'servidor, autoalojado, url, desarrollador';

  @override
  String get settingsSearchKwDiagnostics =>
      'diagnóstico, registros, depuración, desarrollador';

  @override
  String get settingsSearchKwPrivacy =>
      'privacidad, visibilidad, última vez, leído';

  @override
  String get settingsSearchKwBlocked => 'bloqueados, bloquear';

  @override
  String get settingsSearchKwDevices => 'dispositivos, sesiones, cerrar sesión';

  @override
  String get settingsSearchKwLinked => 'apple, google, iniciar sesión';

  @override
  String get settingsSearchKwRecovery =>
      'frase de recuperación, contraseña, copia';

  @override
  String get settingsSearchKwCapture =>
      'captura de pantalla, grabación, privacidad';

  @override
  String get settingsSearchKwFamily => 'familia, hijo, padres, aprobaciones';

  @override
  String get settingsSearchKwAccount =>
      'cuenta, cerrar sesión, eliminar, correo';

  @override
  String get childPolicyScreenContactStateAllowedTalking => 'Hablando';

  @override
  String get childPolicyScreenContactStateTalking => 'Aprobado';

  @override
  String get childPolicyScreenContactStateAllowedNotAdded => 'Aún sin agregar';

  @override
  String get profileScreenSignOutConfirmTitle =>
      '¿Cerrar sesión en este dispositivo?';

  @override
  String get profileScreenDeleteAccountConfirmTitle => '¿Eliminar tu cuenta?';

  @override
  String get profileScreenDeleteAccountConfirmBody =>
      'Se borran tus mensajes, fotos, salas y amigos, y tu nombre de usuario queda libre para otra persona.';

  @override
  String get glassPresetNameFrosted => 'Esmerilado';

  @override
  String get glassPresetNameClear => 'Transparente';

  @override
  String settingsScreenDiagnosticsCountdown(int count) {
    return 'Diagnóstico en $count…';
  }

  @override
  String pairingCodeTitlePair(String name) {
    return 'Emparejar a $name';
  }

  @override
  String pairingCodeTitleRelease(String name) {
    return 'Liberar a $name';
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
      other: '$count mensajes',
      one: '$count mensaje',
    );
    return '$_temp0';
  }

  @override
  String get voiceRecorderScreenTitle => 'Mensaje de voz';

  @override
  String get chatTargetSearchHint => 'Buscar';

  @override
  String get marloweBrainTierSwiftDetail =>
      'Respuestas rápidas, la descarga más ligera';

  @override
  String get marloweBrainTierBalancedDetail =>
      'Buen equilibrio entre rapidez y profundidad';

  @override
  String get marloweBrainTierDeepDetail =>
      'El más reflexivo, necesita más espacio';

  @override
  String get reportFactDeviceId => 'ID del dispositivo';

  @override
  String get reportFactUserId => 'ID de usuario';

  @override
  String get reportFactUsername => 'Nombre de usuario';

  @override
  String get reportFactApp => 'App';

  @override
  String get reportFactDevice => 'Dispositivo';

  @override
  String get reportFactSystem => 'Sistema';

  @override
  String get reportFactDisplay => 'Pantalla';

  @override
  String get reportFactAppLanguage => 'Idioma de la app';

  @override
  String get reportFactSystemLocale => 'Región del sistema';

  @override
  String get reportFactLog => 'Registro';

  @override
  String reportFactLogValue(int count) {
    return '$count eventos adjuntos';
  }

  @override
  String reportProblemScreenshotN(int n) {
    return 'Captura $n';
  }

  @override
  String reportProblemRemoveScreenshot(int n) {
    return 'Quitar captura $n';
  }

  @override
  String get reportFactLanguageFromSystem => 'del sistema';

  @override
  String get reportFactLanguageChosen => 'elegido';

  @override
  String get pageSectionSeeAll => 'Ver todo';

  @override
  String get discoverScreenSeeAllFriendsSemanticLabel => 'Ver todos los amigos';

  @override
  String get discoverScreenSeeAllRoomsSemanticLabel => 'Ver todas tus salas';

  @override
  String groupCallScreenRingingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sonando',
    );
    return '$_temp0';
  }

  @override
  String photoChromeWhenToday(String time) {
    return 'Hoy a las $time';
  }

  @override
  String photoChromeWhenYesterday(String time) {
    return 'Ayer a las $time';
  }

  @override
  String photoChromeWhenDate(String date, String time) {
    return '$date a las $time';
  }

  @override
  String get photoChromeSaved => 'Guardado';

  @override
  String get photoChromeSaveFailed => 'No se pudo guardar';

  @override
  String get photoChromeShareFailed => 'No se pudo compartir';

  @override
  String photoChromeForwarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reenviado a $count chats',
      one: 'Reenviado',
    );
    return '$_temp0';
  }

  @override
  String get photoChromeForwardFailed => 'No se pudo reenviar';

  @override
  String get photoChromeDeleteFailed => 'No se pudo eliminar';

  @override
  String get photoChromeDeleteBody =>
      'Se eliminará para todos en este chat. No se puede deshacer.';

  @override
  String get roomContentMonthThis => 'Este mes';

  @override
  String get roomContentMonthLast => 'El mes pasado';

  @override
  String get leaderboardOverall => 'Hoy';

  @override
  String get leaderboardFooter =>
      '1 punto por cada puzle que resuelvas hoy. En caso de empate, gana quien quedó primero más veces. ¿Sigue el empate? Compartís el puesto, por orden alfabético.';

  @override
  String get leaderboardNotPlayed => 'Aún no has jugado';

  @override
  String get leaderboardPlay => 'Jugar';

  @override
  String get leaderboardEmptyTitle => 'Aún no hay puntuaciones hoy';

  @override
  String get leaderboardEmptyBody =>
      'Resuelve un puzle y serás el primero de la lista.';

  @override
  String get pointComposerPickFirst => 'Primero elige uno arriba';

  @override
  String get momentStoryNext => 'Siguiente';

  @override
  String get momentStoryPrevious => 'Anterior';

  @override
  String leaderboardSolved(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      solved,
      locale: localeName,
      other: '$solved de $total resueltos',
      one: '1 de $total resuelto',
      zero: 'Nada resuelto aún',
    );
    return '$_temp0';
  }

  @override
  String leaderboardWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count victorias',
      one: '1 victoria',
    );
    return '$_temp0';
  }

  @override
  String leaderboardEmptyAction(String game) {
    return 'Jugar: $game';
  }

  @override
  String get diagCatApi => 'Llamadas al servidor';

  @override
  String get diagCatConnection => 'Conexión';

  @override
  String get diagCatDevice => 'Dispositivo';

  @override
  String get diagCatError => 'Errores';

  @override
  String get diagCatFrame => 'Fotogramas lentos';

  @override
  String get diagCatLayout => 'Diseño';

  @override
  String get diagCatLifecycle => 'Estado de la app';

  @override
  String get diagCatLog => 'Registro';

  @override
  String get diagCatNav => 'Navegación';

  @override
  String get diagCatNetwork => 'Red';

  @override
  String get diagCatSubscription => 'Actualizaciones en vivo';

  @override
  String get diagSevTrace => 'Rastreo';

  @override
  String get diagSevDebug => 'Depuración';

  @override
  String get diagSevInfo => 'Info';

  @override
  String get diagSevWarning => 'Advertencia';

  @override
  String get diagSevError => 'Error';

  @override
  String get diagAll => 'Todo';

  @override
  String get diagSearchHint => 'Buscar nombre, detalle, contenido';

  @override
  String get diagSummaryCopied => 'Resumen copiado';

  @override
  String get diagShareLog => 'Compartir registro';

  @override
  String get diagCopySummary => 'Copiar resumen';

  @override
  String get diagDeleteAll => 'Borrar todo';

  @override
  String get diagUndo => 'Deshacer';

  @override
  String get diagDeleteLogTitle => '¿Borrar todo el registro?';

  @override
  String get diagDeleteLogBody =>
      'Se borran todos los eventos registrados hasta ahora y el registro de la sesión anterior. Lo que pase a partir de ahora se registra como siempre.';

  @override
  String get diagDelete => 'Borrar';

  @override
  String get diagLogDeleted => 'Registro borrado';

  @override
  String get diagFilter => 'Filtrar';

  @override
  String get diagMore => 'Más';

  @override
  String get diagLatest => 'Lo último';

  @override
  String get diagJumpToLatest => 'Ir a lo último';

  @override
  String get diagPaused => 'en pausa';

  @override
  String get diagPreparingLog => 'preparando registro…';

  @override
  String get diagEmptyNothingTitle => 'Aún no se ha registrado nada';

  @override
  String get diagEmptyNothingHint =>
      'Usa la app un momento y los eventos aparecerán aquí.';

  @override
  String get diagEmptyHiddenTitle => 'Por ahora solo hay eventos ocultos';

  @override
  String get diagEmptyHiddenHint =>
      'Toca una etiqueta atenuada de arriba para verla, o mantenla pulsada para devolverla a Todo.';

  @override
  String get diagEmptyNoMatchTitle => 'Ningún evento coincide';

  @override
  String get diagEmptyNoMatchHint => 'Toca Todo arriba para quitar el filtro.';

  @override
  String get diagApply => 'Aplicar';

  @override
  String get diagMinSeverity => 'Gravedad mínima';

  @override
  String get diagEverything => 'Todo';

  @override
  String get diagHiddenFromAllHeader => 'Ocultos en Todo';

  @override
  String get diagHiddenFromAllFooter =>
      'Quedan fuera de Todo hasta que los elijas en la fila de etiquetas. Mantén pulsada una etiqueta allí para el mismo ajuste.';

  @override
  String get diagCollapseRepeats => 'Agrupar repeticiones';

  @override
  String get diagCollapseRepeatsSubtitle =>
      'Junta una serie del mismo evento en una fila';

  @override
  String get diagResetFilter => 'Restablecer filtro';

  @override
  String get diagBodyTruncated => 'Contenido recortado al registrar';

  @override
  String get diagCopyEvent => 'Copiar evento';

  @override
  String get diagEventCopied => 'Evento copiado';

  @override
  String diagHiddenFromAll(String category) {
    return '$category oculto en Todo';
  }

  @override
  String diagBackInAll(String category) {
    return '$category vuelve a Todo';
  }

  @override
  String diagChipSemanticLabel(String category, int count) {
    return '$category, $count';
  }

  @override
  String diagChipHiddenSemanticLabel(String category, int count) {
    return '$category, $count, oculto en Todo';
  }

  @override
  String diagEventCount(int shown, int total) {
    return '$shown de $total eventos';
  }

  @override
  String diagDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se descartaron $count eventos anteriores: el registro empieza a mitad de historia',
      one:
          'Se descartó $count evento anterior: el registro empieza a mitad de historia',
    );
    return '$_temp0';
  }

  @override
  String diagRepeatSpan(int count, String seconds) {
    return '×$count en $seconds s';
  }

  @override
  String roomContentTabSemantic(String count, String label) {
    return '$label, $count elementos';
  }

  @override
  String get mapAppsTitle => 'Mapas';

  @override
  String get mapAppsChoose => 'Abrir ubicación en';

  @override
  String get mapAppsRemember => 'Usar por defecto';

  @override
  String get mapAppsAskEveryTime => 'Preguntar siempre';

  @override
  String get mapAppsBrowser => 'Navegador';

  @override
  String get mapAppsSubtitle =>
      'Elige dónde abrir las ubicaciones compartidas.';

  @override
  String get mapAppsUnavailable =>
      'Tu app de mapas predeterminada no está disponible. Elige otra.';

  @override
  String get mapAppsNoInstalled =>
      'No hay apps de mapas compatibles. Puedes usar el navegador.';

  @override
  String get interactionAnswersSearch => 'Buscar personas o respuestas';

  @override
  String get interactionFilterEmpty =>
      'Ninguna respuesta coincide con este filtro.';

  @override
  String get interactionRetry => 'Reintentar';

  @override
  String get cameraEditorScreenCaptionHint => 'Añade un pie de foto…';

  @override
  String get cameraEditorScreenCaptionViewOnceHint =>
      'Sin pie de foto en fotos de una sola vista';

  @override
  String get cameraEditorScreenAddFromCameraSemanticLabel => 'Hacer otra foto';

  @override
  String cameraEditorScreenDiscardAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Descartar $count fotos?',
      one: '¿Descartar esta foto?',
    );
    return '$_temp0';
  }

  @override
  String get cameraEditorScreenDiscardAllBody =>
      'Se perderán tus ediciones y pies de foto.';

  @override
  String get cameraEditorScreenDiscardAllConfirm => 'Descartar';

  @override
  String get galleryTrayRecentsTitle => 'Recientes';

  @override
  String get galleryTrayBackToCameraLabel => 'Volver a la cámara';

  @override
  String get galleryTrayAllPhotosLabel => 'Todas las fotos';

  @override
  String get galleryTrayHandleLabel => 'Fotos recientes';

  @override
  String get galleryTrayAllowPrompt => 'Ve aquí tus fotos recientes';

  @override
  String get galleryTrayAllowButton => 'Permitir';

  @override
  String get galleryTrayDeniedPrompt =>
      'El acceso a las fotos está desactivado';

  @override
  String get galleryTraySettingsButton => 'Ajustes';

  @override
  String get galleryTrayLimitedNote =>
      'Solo se muestran las fotos que has permitido';

  @override
  String get galleryTrayManageButton => 'Gestionar';

  @override
  String get galleryTrayEmpty => 'Aún no hay fotos';

  @override
  String galleryTrayAddSelectedButton(int count) {
    return 'Añadir ($count)';
  }

  @override
  String get galleryTrayCancelSelectionLabel => 'Cancelar selección';

  @override
  String galleryTraySelectedTitle(int count) {
    return '$count seleccionadas';
  }

  @override
  String galleryTrayPhotoLabel(int index) {
    return 'Foto $index';
  }

  @override
  String get reactionLimitTitle => 'Has llegado al límite de reacciones';

  @override
  String reactionLimitMessageBody(int limit) {
    return 'Por la velocidad, la cordura y para que cada emoji brille, puedes añadir hasta $limit reacciones a un mensaje, ni una más. Quita una para hacer sitio a otra.';
  }

  @override
  String reactionLimitHighlightBody(int limit) {
    return 'En los destacados cada persona tiene $limit reacciones, para que cada una siga diciendo algo. Quita una para hacer sitio a tu nueva favorita.';
  }

  @override
  String get reactionLimitDismiss => 'Entendido';

  @override
  String get reactionPickerYoursLabel => 'Tus reacciones';

  @override
  String reactionPickerTakeBackSemantic(String emoji) {
    return 'Quitar tu reacción $emoji';
  }

  @override
  String get momentCommentsTitle => 'Comentarios';

  @override
  String momentCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comentarios',
      one: '1 comentario',
      zero: 'Comentar',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentsEmptyTitle => 'Aún no hay comentarios';

  @override
  String get momentCommentsEmptyBody =>
      'Empieza la conversación: unas palabras, un sticker o un GIF.';

  @override
  String get momentCommentHint => 'Añade un comentario…';

  @override
  String momentCommentReplyHint(String name) {
    return 'Responder a $name…';
  }

  @override
  String momentCommentReplyingTo(String name) {
    return 'Respondiendo a $name';
  }

  @override
  String get momentCommentCancelReply => 'Cancelar respuesta';

  @override
  String get momentCommentReply => 'Responder';

  @override
  String momentCommentViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ver $count respuestas',
      one: 'Ver 1 respuesta',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentHideReplies => 'Ocultar respuestas';

  @override
  String get momentCommentDelete => 'Eliminar comentario';

  @override
  String get momentCommentDeleteConfirm =>
      '¿Eliminar este comentario? Sus respuestas también se irán.';

  @override
  String get momentCommentDeleteConfirmButton => 'Eliminar';

  @override
  String get momentCommentSend => 'Enviar';

  @override
  String get momentCommentExpressions => 'Stickers y GIFs';

  @override
  String get momentCommentFailed =>
      'No se pudo publicar tu comentario. Inténtalo de nuevo.';

  @override
  String get momentCommentAuthorBadge => 'Autor';

  @override
  String get momentCommentLike => 'Me gusta';

  @override
  String get momentCommentStickerAlt => 'Sticker';

  @override
  String get momentCommentGifAlt => 'GIF';

  @override
  String get momentCommentPosted => 'Comentario publicado';

  @override
  String momentCommentsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ver los $count comentarios',
      one: 'Ver 1 comentario',
    );
    return '$_temp0';
  }

  @override
  String momentReactorsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personas más',
      one: '1 persona más',
    );
    return '$name y $_temp0';
  }

  @override
  String get storageKindPhotos => 'Fotos';

  @override
  String get storageKindVideos => 'Vídeos';

  @override
  String get storageKindVideoMessages => 'Notas de vídeo';

  @override
  String get storageKindVoice => 'Mensajes de voz';

  @override
  String get storageKindFiles => 'Archivos';

  @override
  String get storageKindStickers => 'Stickers y GIFs';

  @override
  String get storageKindChatHistory => 'Historial de chats';

  @override
  String get storageKindOther => 'Otros';

  @override
  String get dataUsageKindCalls => 'Llamadas';

  @override
  String get dataStorageTitle => 'Datos y almacenamiento';

  @override
  String get settingsSearchKwDataStorage =>
      'almacenamiento caché memoria espacio borrar descargar descarga automática datos uso de datos móviles wifi guardar fotos galería storage cache';

  @override
  String get storageUsageTitle => 'Uso del almacenamiento';

  @override
  String get dataUsageTitle => 'Uso de datos';

  @override
  String get dataStorageAutoDownloadHeader =>
      'Descarga automática de multimedia';

  @override
  String get dataStorageUsingCellular => 'Con datos móviles';

  @override
  String get dataStorageUsingWifi => 'Con Wi-Fi';

  @override
  String get dataStorageNowTag => 'Ahora';

  @override
  String get autoDownloadReset => 'Restablecer descarga automática';

  @override
  String get autoDownloadResetTitle =>
      '¿Restaurar los ajustes predeterminados de descarga automática?';

  @override
  String get dataStorageSaveHeader => 'Guardar en Fotos';

  @override
  String get dataStorageSaveFooter =>
      'Guarda automáticamente las fotos y vídeos nuevos de estos chats en tu fototeca.';

  @override
  String get dataStorageCallsHeader => 'Llamadas';

  @override
  String get dataStorageLessDataForCalls => 'Usar menos datos en llamadas';

  @override
  String get dataStorageCallsFooter =>
      'Usa menos datos en redes débiles o con límite, con una calidad de audio y vídeo un poco menor.';

  @override
  String get dataStorageCallsNever => 'Nunca';

  @override
  String get dataStorageCallsCellular => 'Con datos móviles';

  @override
  String get dataStorageCallsAlways => 'Siempre';

  @override
  String get dataStorageOff => 'Desactivado';

  @override
  String get dataStorageChatsPrivate => 'Chats privados';

  @override
  String get dataStorageChatsGroups => 'Grupos';

  @override
  String get dataStorageChatsPublic => 'Salas públicas';

  @override
  String get dataStorageNetCellular => 'Datos móviles';

  @override
  String get dataStorageNetWifi => 'Wi-Fi';

  @override
  String get autoDownloadMaster => 'Descargar multimedia automáticamente';

  @override
  String get autoDownloadUsageHeader => 'Uso de datos';

  @override
  String get autoDownloadPresetLow => 'Bajo';

  @override
  String get autoDownloadPresetMedium => 'Medio';

  @override
  String get autoDownloadPresetHigh => 'Alto';

  @override
  String get autoDownloadCustomFooter =>
      'Personalizaste estos ajustes. Mueve el control para volver a un preajuste.';

  @override
  String get autoDownloadTypesHeader => 'Tipos de multimedia';

  @override
  String get autoDownloadVideosTitle => 'Vídeos y notas de vídeo';

  @override
  String get autoDownloadVoiceFooter =>
      'Los mensajes de voz y los stickers ocupan muy poco, así que siempre se descargan automáticamente.';

  @override
  String get autoDownloadAllChats => 'Todos los chats';

  @override
  String autoDownloadUpToIn(String size, String chats) {
    return 'Hasta $size en $chats';
  }

  @override
  String autoDownloadSummaryUpTo(String kind, String size) {
    return '$kind hasta $size';
  }

  @override
  String get autoDownloadSummaryVoiceOnly => 'Solo mensajes de voz';

  @override
  String get autoDownloadInHeader => 'Descargar automáticamente en';

  @override
  String get autoDownloadMaxSizeHeader => 'Tamaño máximo de archivo';

  @override
  String autoDownloadMaxSizeVideoFooter(String size) {
    return 'Los vídeos de hasta $size se descargan automáticamente. Los más grandes esperan a que los toques.';
  }

  @override
  String autoDownloadMaxSizeFileFooter(String size) {
    return 'Los archivos de hasta $size se descargan automáticamente. Los más grandes esperan a que los toques.';
  }

  @override
  String get autoDownloadGateLoad => 'Descargar foto';

  @override
  String get saveToPhotosHeader => 'Guardar automáticamente';

  @override
  String get saveToPhotosFooter =>
      'Las fotos y vídeos nuevos que recibas en estos chats se añaden a tu fototeca al descargarse.';

  @override
  String get saveToPhotosMaxVideoHeader => 'Tamaño máximo de vídeo';

  @override
  String get saveToPhotosNoAccess =>
      'Permite el acceso a la fototeca en Ajustes para guardar automáticamente.';

  @override
  String get saveToPhotosPhotosAndVideos => 'Fotos y vídeos';

  @override
  String get storageCalculating => 'Calculando…';

  @override
  String storageShareOfFree(String percent) {
    return 'MonkeyHub usa el $percent de tu espacio libre.';
  }

  @override
  String get storageEmpty => 'No hay nada en caché ahora mismo.';

  @override
  String storageClearAllButton(String size) {
    return 'Borrar toda la caché $size';
  }

  @override
  String storageClearSelectedButton(String size) {
    return 'Borrar selección $size';
  }

  @override
  String storageClearChatButton(String size) {
    return 'Borrar caché $size';
  }

  @override
  String get storageClearFooter =>
      'Todo sigue en la nube y se vuelve a descargar cuando lo necesites.';

  @override
  String get storageClearAllTitle => '¿Borrar toda la caché?';

  @override
  String get storageClearSelectedTitle =>
      '¿Borrar los elementos seleccionados?';

  @override
  String get storageClearBody =>
      'Tus mensajes se quedan. El contenido multimedia se vuelve a descargar al abrirlo.';

  @override
  String storageClearConfirm(String size) {
    return 'Borrar $size';
  }

  @override
  String storageFreed(String size) {
    return '$size liberados';
  }

  @override
  String storageCleanupTitle(String size) {
    return 'Liberar $size';
  }

  @override
  String get storageCleanupSubtitle =>
      'Multimedia que no abres desde hace un mes';

  @override
  String get storageCleanupAction => 'Limpiar';

  @override
  String get storageCleanupFooter =>
      'Solo borra el contenido que nadie ha visto en 30 días. Mensajes guardados nunca se toca.';

  @override
  String get storageAutoRemoveHeader =>
      'Eliminar multimedia en caché automáticamente';

  @override
  String get storageAutoRemoveFooter =>
      'El contenido que no abras durante este tiempo se quita del dispositivo para ahorrar espacio. Sigue en la nube, y Mensajes guardados siempre se conserva.';

  @override
  String get dataStorageKeepNever => 'Nunca';

  @override
  String get dataStorageKeepMonth => '1 mes';

  @override
  String get dataStorageKeepWeek => '1 semana';

  @override
  String get dataStorageKeepDay => '1 día';

  @override
  String get storageLimitHeader => 'Tamaño máximo de caché';

  @override
  String get storageLimitFooter =>
      'Si la caché supera este tamaño, se elimina primero el contenido que abriste hace más tiempo.';

  @override
  String get dataStorageLimitNone => 'Sin límite';

  @override
  String get storageTabChats => 'Chats';

  @override
  String get storageTabMedia => 'Multimedia';

  @override
  String get storageTabFiles => 'Archivos';

  @override
  String get storageNoChats => 'Ningún chat tiene nada en caché todavía.';

  @override
  String get storageNoMedia => 'Todavía no hay fotos ni vídeos en caché.';

  @override
  String get storageNoFiles => 'Todavía no hay archivos en caché.';

  @override
  String get storageOpenPhoto => 'Abrir foto';

  @override
  String get storageOpenVideo => 'Abrir vídeo';

  @override
  String get storageSelect => 'Seleccionar';

  @override
  String storageChatShare(String percent) {
    return 'Este chat usa el $percent de tu caché.';
  }

  @override
  String get storageChatUnknown => 'Chat que dejaste';

  @override
  String dataUsageSince(String date) {
    return 'Desde $date';
  }

  @override
  String get dataUsageAll => 'Todas';

  @override
  String get dataUsageNothingYet => 'Aún no se ha contado nada en esta red.';

  @override
  String get dataUsageTapHint =>
      'Toca una categoría para ver lo enviado y lo recibido.';

  @override
  String get dataUsageSent => 'Enviado';

  @override
  String get dataUsageReceived => 'Recibido';

  @override
  String get dataUsageTotalHeader => 'Uso total de red';

  @override
  String get dataUsageFootnote =>
      'Cuenta multimedia y llamadas. Los mensajes en sí ocupan muy poco y no se incluyen.';

  @override
  String get dataUsageReset => 'Restablecer estadísticas';

  @override
  String get dataUsageResetTitle =>
      '¿Restablecer las estadísticas de uso de datos?';

  @override
  String get dataUsageResetBody => 'El conteo empieza de nuevo desde ahora.';

  @override
  String get storageKindCompanions => 'Compañeros';

  @override
  String get storageCompanionsNote =>
      'Los compañeros no se borran con la caché. Tócalos para gestionar sus descargas.';

  @override
  String storageCategoryCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos, $size',
      one: '1 elemento, $size',
    );
    return '$_temp0';
  }

  @override
  String get storageSelectAll => 'Seleccionar todo';

  @override
  String get storageDeselectAll => 'Deseleccionar';

  @override
  String get storageCategoryEmpty =>
      'Ahora mismo no hay nada de este tipo en caché.';

  @override
  String get storageChatHistoryFooter =>
      'Solo se elimina la copia de este dispositivo. Los mensajes siguen en el chat y se vuelven a cargar la próxima vez que lo abras.';

  @override
  String get storageCategoryHint =>
      'Toca una categoría para ver qué contiene, o su círculo para dejarla fuera.';

  @override
  String storageChatRemovedNamed(String names) {
    return '$names · chat eliminado';
  }

  @override
  String get streaksLabel => 'Rachas';

  @override
  String get streakAtRiskFooter => 'Juega hoy para mantener tu racha.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Racha de $count días',
      one: 'Racha de 1 día',
    );
    return '$_temp0';
  }

  @override
  String recordsCheersMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'y $count más',
      one: 'y 1 más',
    );
    return '$_temp0';
  }

  @override
  String get recordsCheer => 'Aplaudir';

  @override
  String get myStreaksLabel => 'Mis rachas';

  @override
  String streakLongest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return 'Tu racha más larga: $_temp0';
  }

  @override
  String get streaksEmpty => 'Aquí nadie tiene racha todavía.';

  @override
  String videoTooLargeSnack(String size) {
    return 'Los vídeos tienen un límite de $size';
  }

  @override
  String videoShrinkPromptTitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos pasan de $size',
      one: 'Este vídeo pasa de $size',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkPromptBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se comprimirán para que quepan, así que se verán bastante peor.',
      one: 'Se comprimirá para que quepa, así que se verá bastante peor.',
    );
    return '$_temp0';
  }

  @override
  String get videoShrinkPromptAction => 'Comprimir y enviar';

  @override
  String get videoShrinkWorkingSnack => 'Comprimiendo vídeo…';

  @override
  String videoShrinkFailedSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count vídeos son demasiado largos para caber en $size, incluso comprimidos',
      one: 'Es demasiado largo para caber en $size, incluso comprimido',
    );
    return '$_temp0';
  }

  @override
  String photoHdOverCapSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos pasaban de $size y se enviaron en calidad estándar',
      one: '1 foto pasaba de $size y se envió en calidad estándar',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkSendSmallOnly(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar solo los $count que no pasan de $size',
      one: 'Enviar solo el que no pasa de $size',
    );
    return '$_temp0';
  }

  @override
  String get kbdGroupGeneral => 'General';

  @override
  String get kbdGroupNavigation => 'Navegación';

  @override
  String get kbdGroupChat => 'En un chat';

  @override
  String get kbdGroupComposer => 'Escribir';

  @override
  String get kbdGroupViewer => 'Fotos y vídeos';

  @override
  String get kbdGroupCall => 'Llamadas';

  @override
  String get kbdCommandPalette => 'Buscar chats y comandos';

  @override
  String get kbdShowShortcuts => 'Atajos de teclado';

  @override
  String get kbdSearch => 'Buscar';

  @override
  String get kbdNewChat => 'Nuevo chat';

  @override
  String get kbdSettings => 'Ajustes';

  @override
  String get kbdBack => 'Volver o cerrar';

  @override
  String kbdGoTo(String section) {
    return 'Ir a $section';
  }

  @override
  String get kbdNextChat => 'Chat siguiente';

  @override
  String get kbdPreviousChat => 'Chat anterior';

  @override
  String get kbdNextUnread => 'Siguiente chat no leído';

  @override
  String get kbdCloseChat => 'Cerrar chat';

  @override
  String get kbdRoomInfo => 'Info del chat';

  @override
  String get kbdSearchInChat => 'Buscar en este chat';

  @override
  String get kbdJumpToLatest => 'Ir al último mensaje';

  @override
  String get kbdAttach => 'Adjuntar archivos';

  @override
  String get kbdVoiceCall => 'Llamada de voz';

  @override
  String get kbdVideoCall => 'Videollamada';

  @override
  String get kbdSend => 'Enviar';

  @override
  String get kbdNewline => 'Nueva línea';

  @override
  String get kbdEditLast => 'Editar tu último mensaje';

  @override
  String get kbdBold => 'Negrita';

  @override
  String get kbdItalic => 'Cursiva';

  @override
  String get kbdUnderline => 'Subrayado';

  @override
  String get kbdPasteMedia => 'Pegar una foto o archivo';

  @override
  String get kbdEmoji => 'Emojis y stickers';

  @override
  String get kbdViewerPrevious => 'Anterior';

  @override
  String get kbdViewerNext => 'Siguiente';

  @override
  String get kbdZoomIn => 'Ampliar';

  @override
  String get kbdZoomOut => 'Reducir';

  @override
  String get kbdZoomFit => 'Ajustar a la ventana';

  @override
  String get kbdPlayPause => 'Reproducir o pausar';

  @override
  String get kbdCopyMedia => 'Copiar';

  @override
  String get kbdSaveMedia => 'Guardar';

  @override
  String get kbdToggleMute => 'Silenciar o activar el micro';

  @override
  String get kbdToggleCamera => 'Activar o desactivar la cámara';

  @override
  String get kbdHangUp => 'Colgar';

  @override
  String get kbdGroupApp => 'App';

  @override
  String get kbdCloseWindow => 'Cerrar ventana';

  @override
  String get kbdMinimizeWindow => 'Minimizar';

  @override
  String get kbdFullScreen => 'Pantalla completa';

  @override
  String get kbdHideApp => 'Ocultar MonkeyHub';

  @override
  String get kbdQuit => 'Salir de MonkeyHub';

  @override
  String get kbdPanelTitle => 'Atajos de teclado';

  @override
  String get kbdPanelSearchHint => 'Buscar atajos';

  @override
  String get kbdPanelEmpty => 'Ningún atajo coincide';

  @override
  String kbdPeekHint(String key) {
    return 'Mantén pulsada $key en cualquier momento para ver los atajos de la pantalla en la que estás';
  }

  @override
  String kbdPeekSetting(String key) {
    return 'Mostrar atajos al mantener pulsada $key';
  }

  @override
  String get kbdPaletteHint => 'Ir a un chat o ejecutar un comando';

  @override
  String get kbdPaletteChats => 'Chats';

  @override
  String get kbdPaletteCommands => 'Comandos';

  @override
  String get kbdPaletteEmpty => 'No se encontró nada';

  @override
  String get kbdPaletteMove => 'Moverse';

  @override
  String get kbdPaletteOpen => 'Abrir';

  @override
  String get kbdPaletteClose => 'Cerrar';

  @override
  String get msgDeskReactLabel => 'Reaccionar';

  @override
  String get msgDeskMoreLabel => 'Más';

  @override
  String get msgDeskInfoLabel => 'Info';

  @override
  String get kbdSeekBackward => 'Retroceder 5 segundos';

  @override
  String get kbdSeekForward => 'Avanzar 5 segundos';

  @override
  String get kbdMuteVideo => 'Silenciar o activar el sonido del vídeo';

  @override
  String get viewerSavedToDownloads => 'Guardado en Descargas';

  @override
  String get viewerDownloaded => 'Descargado';

  @override
  String get viewerShowInFinder => 'Mostrar en Finder';

  @override
  String get viewerShowInFolder => 'Mostrar en la carpeta';

  @override
  String get viewerCopied => 'Copiado';

  @override
  String get viewerCopyFailed => 'No se pudo copiar';

  @override
  String get hoverCompactLayoutTitle => 'Diseño compacto';

  @override
  String get hoverCompactLayoutSubtitle =>
      'Filas más bajas y botones más pequeños, pensados para ratón y pantalla grande.';

  @override
  String get layoutPagerPrevious => 'Anterior';

  @override
  String get layoutPagerNext => 'Siguiente';

  @override
  String get resultSheetMistakes => 'Errores';

  @override
  String get resultSheetHints => 'Pistas';

  @override
  String get resultSheetStreak => 'Racha';

  @override
  String resultSheetStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '1 día',
    );
    return '$_temp0';
  }

  @override
  String get resultSheetNone => 'Ninguno';

  @override
  String resultSheetToday(String game) {
    return '$game · Hoy';
  }

  @override
  String resultSheetYouFaster(String time) {
    return 'Fuiste $time más rápido';
  }

  @override
  String resultSheetTheyFaster(String name, String time) {
    return '$name fue $time más rápido';
  }

  @override
  String get resultSheetSameTime => 'El mismo tiempo que tú';

  @override
  String get resultSheetFooter =>
      'Solo el tiempo decide la clasificación. Los errores y las pistas son solo por curiosidad.';

  @override
  String get resultSheetHintNoRecord =>
      'Resuelto con pistas, así que no puede ser un récord histórico.';

  @override
  String get gameTierEasy => 'Fácil';

  @override
  String get gameTierMedium => 'Media';

  @override
  String get gameTierHard => 'Difícil';

  @override
  String get gameComingSoon => 'Próximamente';

  @override
  String get gameComingSoonName => 'Nuevo puzle';

  @override
  String get chatGameNameTicTacToe => 'Tres en raya';

  @override
  String get chatGameNameConnectFour => 'Conecta 4';

  @override
  String get chatGameNameCheckers => 'Damas';

  @override
  String get chatGameNameReversi => 'Reversi';

  @override
  String get chatGameNameDots => 'Puntos y cajas';

  @override
  String get chatGameDescTicTacToe => 'Gana quien haga tres en raya.';

  @override
  String get chatGameDescConnectFour => 'Suelta fichas. Cuatro en línea gana.';

  @override
  String get chatGameDescCheckers => 'Salta para capturar. Cómelas todas.';

  @override
  String get chatGameDescReversi =>
      'Encierra para voltear. Gana quien tenga más.';

  @override
  String get chatGameDescDots => 'Traza líneas, cierra cajas y repite.';

  @override
  String get chatGameKindLive => 'Partida en vivo';

  @override
  String get chatGameKindTurns => 'Por turnos';

  @override
  String get chatGameStatusWaiting => 'Esperando';

  @override
  String get chatGameStatusPlaying => 'En juego';

  @override
  String get chatGameStatusPaused => 'En pausa';

  @override
  String get chatGameStatusFinished => 'Terminada';

  @override
  String get chatGameStatusEnded => 'Finalizada';

  @override
  String get chatGameYourMove => 'Te toca';

  @override
  String chatGameTurnOf(String name) {
    return 'Le toca a $name';
  }

  @override
  String chatGameWaitingFor(String name) {
    return 'Esperando a $name';
  }

  @override
  String chatGameWonBy(String name) {
    return 'Ganó $name';
  }

  @override
  String get chatGameYouWon => 'Ganaste';

  @override
  String get chatGameDraw => 'Empate';

  @override
  String get chatGameNobodyWon => 'Todos se fueron, nadie ganó';

  @override
  String chatGameReasonTimeout(String name) {
    return 'A $name se le acabó el tiempo';
  }

  @override
  String chatGameReasonResign(String name) {
    return '$name se rindió';
  }

  @override
  String chatGameReasonLeft(String name) {
    return '$name se fue';
  }

  @override
  String get chatGameOpenSeat => 'Sitio libre';

  @override
  String get chatGameReady => 'Listo';

  @override
  String get chatGameNotReady => 'No listo';

  @override
  String chatGameWatchingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mirando',
      one: '1 mirando',
    );
    return '$_temp0';
  }

  @override
  String get chatGameJoin => 'Unirse';

  @override
  String get chatGameWatch => 'Mirar';

  @override
  String get chatGamePlay => 'Jugar';

  @override
  String get chatGameOpen => 'Abrir';

  @override
  String get chatGameRematch => 'Revancha';

  @override
  String get chatGameNotRanked =>
      'Solo por diversión. Los juegos del chat no cuentan para tus rachas ni récords.';

  @override
  String get chatGameNotRankedShort => 'Sin clasificación';

  @override
  String get chatGameImReady => 'Estoy listo';

  @override
  String get chatGameUnready => 'Aún no estoy listo';

  @override
  String get chatGameTakeSeat => 'Toca para unirte';

  @override
  String get chatGameLeaveSeat => 'Dejar el sitio';

  @override
  String get chatGameStartsWhenReady => 'Empieza cuando todos estén listos';

  @override
  String chatGameNeedPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltan $count jugadores',
      one: 'Falta 1 jugador',
    );
    return '$_temp0';
  }

  @override
  String get chatGameWatchingLabel => 'Mirando';

  @override
  String get chatGameAskSwap => 'Pedir el cambio';

  @override
  String chatGameSwapRequest(String name) {
    return '$name quiere entrar por ti';
  }

  @override
  String get chatGameSwap => 'Cambiar';

  @override
  String get chatGameDecline => 'Rechazar';

  @override
  String get chatGameAccept => 'Aceptar';

  @override
  String chatGameSwapAsked(String name) {
    return 'Se lo pediste a $name';
  }

  @override
  String get chatGameCancel => 'Cancelar';

  @override
  String get chatGameResign => 'Rendirse';

  @override
  String get chatGameResignConfirm => '¿Rendirte en esta partida?';

  @override
  String get chatGameResignBody => 'Contará como derrota.';

  @override
  String get chatGameOfferDraw => 'Ofrecer tablas';

  @override
  String get chatGameDrawOffered => 'Tablas ofrecidas';

  @override
  String chatGameDrawOfferFrom(String name) {
    return '$name ofrece tablas';
  }

  @override
  String chatGamePausedTitle(String name) {
    return '$name salió de la partida';
  }

  @override
  String get chatGamePausedMany => 'Algunos jugadores se fueron';

  @override
  String get chatGamePausedBody => 'Guardamos el tablero un rato.';

  @override
  String get chatGamePausedYou => 'La partida sigue cuando todos vuelvan.';

  @override
  String get chatGameLeave => 'Salir de la partida';

  @override
  String get chatGameGo => '¡Ya!';

  @override
  String get chatGameNudge => 'Avisar';

  @override
  String get chatGameNudged => 'Avisado';

  @override
  String chatGameHoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count horas',
      one: 'Queda 1 hora',
    );
    return '$_temp0';
  }

  @override
  String chatGameMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Quedan $count minutos',
      one: 'Queda 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get chatGameMoveFailed => 'Esa jugada no se envió';

  @override
  String get chatGameStale => 'El tablero cambió. Inténtalo de nuevo.';

  @override
  String get chatGameStartTitle => 'Jugar una partida';

  @override
  String get chatGameMenuItem => 'Juego';

  @override
  String get chatGameModeLive => 'En vivo';

  @override
  String get chatGameBotEasyHint => 'Comete errores. Ideal para aprender.';

  @override
  String get chatGameBotMediumHint =>
      'Juega limpio y bloquea tus jugadas ganadoras.';

  @override
  String get chatGameBotHardHint => 'Piensa varias jugadas por delante.';

  @override
  String get chatGameStart => 'Empezar';

  @override
  String get chatGameErrAlreadyLive =>
      'Ya hay una partida en vivo aquí. Termínala o sal primero.';

  @override
  String get chatGameErrTooMany =>
      'Ya tienes 3 partidas por turnos aquí. Termina una primero.';

  @override
  String get chatGameErrEphemeral =>
      'No se puede jugar en un chat donde los mensajes desaparecen.';

  @override
  String get chatGameErrGeneric => 'Algo salió mal. Inténtalo de nuevo.';

  @override
  String get chatGamePlayersTwo => '2 jugadores';

  @override
  String get chatGamePlayersUpToFour => '2–4 jugadores';

  @override
  String get chatGameBotName => 'Mono';

  @override
  String get chatGameBotBadge => 'Bot';

  @override
  String get chatGameNewGame => 'Nueva partida';

  @override
  String chatGameBannerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count partidas',
      one: '1 partida',
    );
    return '$_temp0';
  }

  @override
  String chatGameBannerYourMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Te toca en $count',
      one: 'Te toca en 1',
    );
    return '$_temp0';
  }

  @override
  String get chatGameSheetTitle => 'Partidas en este chat';

  @override
  String get chatGameGone => 'Esta partida ya no está disponible.';

  @override
  String get chatGameSeatsLabel => 'Jugadores';

  @override
  String get gameFlowName => 'Flujo';

  @override
  String get gameFutoshikiName => 'Futoshiki';

  @override
  String get gameNonogramName => 'Nonograma';

  @override
  String get gameMinesweeperName => 'Buscaminas';

  @override
  String get gameStarbattleName => 'Batalla de estrellas';

  @override
  String get gamePatchesName => 'Parches';

  @override
  String get gameFlowRule => 'une los puntos iguales y llena cada casilla';

  @override
  String get gameFutoshikiRule =>
      'del 1 al 5 una vez por fila y columna, con cada signo cierto';

  @override
  String get gameNonogramRule => 'rellena casillas para cumplir cada pista';

  @override
  String get gameMinesweeperRule => 'abre cada casilla segura, sin adivinar';

  @override
  String get gameStarbattleRule =>
      'dos estrellas por fila, columna y color, sin tocarse';

  @override
  String get gamePatchesRule =>
      'divide el tablero en rectángulos, una pista en cada uno';

  @override
  String get gameFlag => 'Bandera';

  @override
  String get gameAutoDot => 'Puntos automáticos';

  @override
  String boardCellName(int row, int col) {
    return 'Fila $row, columna $col';
  }

  @override
  String get boardEmpty => 'vacía';

  @override
  String get boardBlack => 'negra';

  @override
  String get boardWhite => 'blanca';

  @override
  String get boardLegalMove => 'jugada válida';

  @override
  String get boardMoveHere => 'mover aquí';

  @override
  String boardColumnFilled(int column, int count, int total) {
    return 'Columna $column, $count de $total ocupadas';
  }

  @override
  String boardSquareName(int number) {
    return 'Casilla $number';
  }

  @override
  String get boardDarkMan => 'ficha oscura';

  @override
  String get boardDarkKing => 'dama oscura';

  @override
  String get boardLightMan => 'ficha clara';

  @override
  String get boardLightKing => 'dama clara';

  @override
  String boardBoxName(String cell) {
    return 'Caja, $cell';
  }

  @override
  String get boardOpen => 'libre';

  @override
  String get boardDrawn => 'trazada';

  @override
  String boardClaimedBy(String name) {
    return 'de $name';
  }

  @override
  String boardHorizontalEdge(int row, int col) {
    return 'Línea horizontal, fila $row, columna $col';
  }

  @override
  String boardVerticalEdge(int row, int col) {
    return 'Línea vertical, fila $row, columna $col';
  }

  @override
  String get challengeAction => 'Retar';

  @override
  String get challengeTitle => 'Supera mi tiempo';

  @override
  String get challengeKind => 'Reto diario';

  @override
  String challengeYouBeat(String time) {
    return 'Lo superaste por $time';
  }

  @override
  String challengeStillStanding(String time) {
    return 'Sigue en pie, por $time';
  }

  @override
  String get challengeTie => 'Empate exacto';

  @override
  String get challengeClosed => 'Ese tablero ya cerró';

  @override
  String get challengeYourTime => 'Tu tiempo a batir';

  @override
  String get challengeSent => 'Reto enviado';

  @override
  String challengeTarget(String name, String time) {
    return '$name $time';
  }

  @override
  String challengeBeatName(String name, String time) {
    return 'Superaste el $time de $name';
  }

  @override
  String challengeKept(String name, String time) {
    return '$name lo mantiene, por $time';
  }

  @override
  String challengeBackName(String name) {
    return 'Devuélvele el reto a $name';
  }

  @override
  String challengeBackRoom(String room) {
    return 'Responder en $room';
  }

  @override
  String challengeFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amigos han jugado',
      one: '1 amigo ha jugado',
      zero: 'Ninguno de tus amigos de aquí ha jugado todavía',
    );
    return '$_temp0';
  }

  @override
  String challengeYouAndFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tú y $count amigos han jugado',
      one: 'Tú y 1 amigo han jugado',
      zero: 'De momento solo has jugado tú',
    );
    return '$_temp0';
  }

  @override
  String get challengeFriendsOnlyNote =>
      'Aquí solo aparecen tus amigos. Otras personas de este chat también pueden haber jugado.';

  @override
  String get chatGameNameLiarsDice => 'Dados mentirosos';

  @override
  String get chatGameNameImposter => 'Impostor';

  @override
  String get chatGameNameRace => 'Carrera de puzles';

  @override
  String get chatGameDescLiarsDice =>
      'Apuesta sobre dados ocultos. Descubre al mentiroso.';

  @override
  String get chatGameDescImposter => 'Alguien no sabe la palabra. Encuéntralo.';

  @override
  String get chatGameDescRace =>
      'El mismo puzle para todos. Gana el más rápido.';

  @override
  String chatGamePlayersRange(int min, int max) {
    return '$min–$max jugadores';
  }

  @override
  String chatGameNeedsPeople(int count) {
    return 'Mínimo $count personas';
  }

  @override
  String get chatGameVoiceOption => 'Pistas por voz';

  @override
  String get chatGameVoiceOptionHint =>
      'Habla en una llamada en vez de escribir las pistas';

  @override
  String get chatGamePuzzleOption => 'Puzle';

  @override
  String get chatGamePuzzleRandom => 'Al azar';

  @override
  String chatGameStartNamed(String game) {
    return 'Empezar $game';
  }

  @override
  String chatGameLdRoundDice(int count, int round) {
    return 'Ronda $round · $count dados';
  }

  @override
  String get chatGameLdYourDice => 'Tus dados';

  @override
  String get chatGameLdNoBid => 'Aún no hay apuesta';

  @override
  String chatGameLdBidBy(String name) {
    return 'Apuesta de $name';
  }

  @override
  String get chatGameLdYourBid => 'Tu apuesta';

  @override
  String get chatGameLdBid => 'Apostar';

  @override
  String get chatGameLdLiar => '¡Mentiroso!';

  @override
  String get chatGameLdOnesWild => 'Los 1 son comodines';

  @override
  String get chatGameLdOnesOnly => 'Apuesta a 1: sin comodines';

  @override
  String get chatGameLdHolds => 'La apuesta se cumple';

  @override
  String get chatGameLdBusted => '¡Pillado!';

  @override
  String chatGameLdThereWere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Había $count',
      one: 'Había 1',
    );
    return '$_temp0';
  }

  @override
  String chatGameLdLosesDie(String name) {
    return '$name pierde un dado';
  }

  @override
  String get chatGameLdYouLoseDie => 'Pierdes un dado';

  @override
  String chatGameLdCalled(String name) {
    return '$name dijo mentiroso';
  }

  @override
  String chatGameLdTimedOut(String name) {
    return 'Se le acabó el tiempo a $name';
  }

  @override
  String get chatGameLdOut => 'Fuera';

  @override
  String get chatGameLdQuantity => 'Cuántos';

  @override
  String get chatGameLdFace => 'Qué cara';

  @override
  String get chatGameLdFewer => 'Menos';

  @override
  String get chatGameLdMore => 'Más';

  @override
  String get chatGameLdPrompt => 'Sube la apuesta o di mentiroso';

  @override
  String get chatGameLdOpenPrompt => 'Abre la apuesta';

  @override
  String get chatGameImpHoldToSee => 'Mantén pulsado para ver tu carta';

  @override
  String get chatGameImpYourWord => 'Tu palabra';

  @override
  String get chatGameImpYouAre => 'Eres el impostor';

  @override
  String chatGameImpCategory(String category) {
    return 'Categoría: $category';
  }

  @override
  String get chatGameImpBlendIn => 'Disimula. Nadie más lo sabe.';

  @override
  String get chatGameImpKeepSecret =>
      'No la digas tal cual. Da pistas que los demás entiendan.';

  @override
  String get chatGameImpGotIt => 'Entendido';

  @override
  String chatGameImpLooked(int count, int total) {
    return '$count de $total ya miraron';
  }

  @override
  String chatGameImpGiving(String name) {
    return '$name está dando su pista';
  }

  @override
  String get chatGameImpYourClue => 'Te toca dar una pista';

  @override
  String get chatGameImpClueHint => 'De una a cuatro palabras';

  @override
  String get chatGameImpClueField => 'Tu pista';

  @override
  String get chatGameImpSend => 'Enviar';

  @override
  String get chatGameImpTooManyWords => 'Cuatro palabras como máximo';

  @override
  String get chatGameImpPassed => 'Pasó';

  @override
  String get chatGameImpSpoke => 'Lo dijo en la llamada';

  @override
  String get chatGameImpJoinCall => 'Unirse a la llamada';

  @override
  String get chatGameImpOnCall => 'Estás en la llamada';

  @override
  String get chatGameImpVoiceHint => 'Di tu pista en voz alta y toca Listo.';

  @override
  String get chatGameImpDone => 'Listo';

  @override
  String get chatGameImpVoteTitle => '¿Quién es el impostor?';

  @override
  String get chatGameImpVoteHint =>
      'Toca a un jugador para votar. Puedes cambiarlo hasta que acabe el tiempo.';

  @override
  String get chatGameImpSkip => 'No votar';

  @override
  String chatGameImpVoted(int count, int total) {
    return 'Han votado $count de $total';
  }

  @override
  String get chatGameImpVotedBadge => 'Votó';

  @override
  String get chatGameImpYourVote => 'Tu voto';

  @override
  String get chatGameImpGuessing => 'El impostor está adivinando…';

  @override
  String get chatGameImpGuessHint =>
      'Te pillaron. Adivina la palabra para robar la victoria.';

  @override
  String get chatGameImpGuessField => 'La palabra es…';

  @override
  String get chatGameImpGuess => 'Adivinar';

  @override
  String chatGameImpWas(String name) {
    return '$name era el impostor';
  }

  @override
  String get chatGameImpYouWere => 'Eras el impostor';

  @override
  String get chatGameImpTheWord => 'La palabra era';

  @override
  String chatGameImpTheyGuessed(String guess) {
    return 'Dijo «$guess»';
  }

  @override
  String chatGameImpVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votos',
      one: '1 voto',
    );
    return '$_temp0';
  }

  @override
  String chatGameImpSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count no votaron',
      one: '1 no votó',
    );
    return '$_temp0';
  }

  @override
  String get chatGameImpReasonEscaped =>
      'Nadie fue expulsado y el impostor escapó.';

  @override
  String get chatGameImpReasonWrong =>
      'El equipo expulsó a la persona equivocada.';

  @override
  String get chatGameImpReasonGuessed =>
      'Lo pillaron, pero el impostor adivinó la palabra.';

  @override
  String get chatGameImpReasonCaught => 'El equipo atrapó al impostor.';

  @override
  String get chatGameImpReasonImposterLeft =>
      'El impostor salió de la partida.';

  @override
  String get chatGameImpReasonCrewLeft => 'El resto del equipo se fue.';

  @override
  String get chatGameImpCrewWon => 'Ganó el equipo';

  @override
  String get chatGameImpYourTeamWon => 'Ganó tu equipo';

  @override
  String chatGameImpImposterWon(String name) {
    return '$name ganó como impostor';
  }

  @override
  String get chatGameImpYouWonImposter => 'Ganaste como impostor';

  @override
  String get chatGameImpCardReveal => 'Mirando las cartas';

  @override
  String chatGameImpCardClues(int count, int total) {
    return 'Pistas · $count de $total';
  }

  @override
  String get chatGameImpCardVote => 'Votando';

  @override
  String chatGameRaceFinishedCount(int count, int total) {
    return '$count de $total terminaron';
  }

  @override
  String chatGameRaceYouPlaced(int rank) {
    return 'Terminaste en el puesto $rank';
  }

  @override
  String get chatGameRaceWaiting => 'Esperando a los demás';

  @override
  String get chatGameRaceTimeUp => 'Se acabó el tiempo. Nadie terminó.';

  @override
  String get chatGameRaceDnf => 'No terminó';

  @override
  String get chatGameRaceLeft => 'Se fue';

  @override
  String get chatGameRaceResults => 'Resultados';

  @override
  String get chatGameRaceSolved => '¡Resuelto!';

  @override
  String get chatGamePartyLeaveConfirm => '¿Salir de la partida?';

  @override
  String get chatGamePartyLeaveBody => 'Los demás siguen jugando sin ti.';

  @override
  String get chatGameErrTooLate => 'Demasiado tarde, se acabó el tiempo';

  @override
  String get chatGameErrBadClue =>
      'Esa pista no vale. De una a cuatro palabras, sin enlaces.';

  @override
  String get chatGameErrBadGuess => 'Escribe una respuesta primero';

  @override
  String get chatGameErrNotSolved => 'El tablero aún no está resuelto';

  @override
  String get chatGameNameChess => 'Ajedrez';

  @override
  String get chatGameDescChess => 'Gana con jaque mate al rey.';

  @override
  String get chessPawn => 'peón';

  @override
  String get chessKnight => 'caballo';

  @override
  String get chessBishop => 'alfil';

  @override
  String get chessRook => 'torre';

  @override
  String get chessQueen => 'dama';

  @override
  String get chessKing => 'rey';

  @override
  String chessPieceWhite(String piece) {
    return '$piece, blancas';
  }

  @override
  String chessPieceBlack(String piece) {
    return '$piece, negras';
  }

  @override
  String chessPromoteTo(String piece) {
    return 'Coronar como $piece';
  }

  @override
  String get kbdPeekDontShowAgain => 'No mostrar más';

  @override
  String get kbdPeekTurnedOff =>
      'Listo, ya no te saldrá. Puedes volver a activarlo en Ajustes.';

  @override
  String get chatGameBadgeTurns => 'Por turnos';

  @override
  String get chatGameSectionBoards => 'Juegos de mesa';

  @override
  String get chatGameSectionParty => 'Juegos en grupo';

  @override
  String get chatGameBoardsHintDm =>
      'Juega en vivo ahora o por turnos cuando tengas un rato.';

  @override
  String get chatGameBoardsHintGroup =>
      'En vivo, aquí mismo. Únete o solo mira.';

  @override
  String get chatGamePartyHint =>
      'Juegan todos a la vez, así que junta a la banda primero.';

  @override
  String get chatGameLiveTitle => 'Jugar en vivo';

  @override
  String get chatGameLiveNow => 'Todos juegan a la vez, ahora mismo.';

  @override
  String get chatGameLivePause =>
      '¿Alguien se va? Se pausa. Tiene 2 minutos para volver o pierde.';

  @override
  String get chatGameTurnsTitle => 'Jugar por turnos';

  @override
  String get chatGameTurnsAnytime =>
      'Mueve cuando quieras. Cada jugada aparece en el chat.';

  @override
  String get chatGameTurnsClock =>
      '2 días por jugada. Le avisamos, y tú también puedes avisarle.';

  @override
  String get chatGameHowWillYouPlay => '¿Cómo quieres jugar?';

  @override
  String get botHubTitle => 'Jugar contra el bot';

  @override
  String botHubSubtitle(String bot) {
    return 'Solo tú y $bot. Aprende las jugadas y luego gánales a tus amigos.';
  }

  @override
  String get botHubLevelTitle => '¿Qué nivel?';

  @override
  String get botHubPickGame => 'Elige un juego';

  @override
  String get botHubCaption => 'Práctica';

  @override
  String botHubGameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count juegos',
      one: '1 juego',
    );
    return '$_temp0';
  }

  @override
  String get practiceNotRanked =>
      'Solo por diversión. Estas partidas no cuentan para tus rachas ni récords.';

  @override
  String get chatGameMvYouPlayed => 'Jugaste';

  @override
  String chatGameMvTheyPlayed(String name) {
    return '$name jugó';
  }

  @override
  String chatGameMvNumber(int count) {
    return 'Jugada $count';
  }

  @override
  String chatGameMvColumn(int count) {
    return 'Columna $count';
  }

  @override
  String get chatGameMvEarlier => 'Jugada anterior';

  @override
  String get chatGameMvSend => 'Enviar jugada';

  @override
  String get chatGameMvUndo => 'Deshacer';

  @override
  String get chatGameMvStagedHint =>
      'Todavía no se ha enviado. Cámbiala o dale a Enviar.';

  @override
  String get chatGameMvSentToast => 'Jugada enviada. Ahora le toca mover.';

  @override
  String get chatGameMvYourTurnSub =>
      'Haz tu jugada y luego envíala. Sin prisa.';

  @override
  String get chatGameMvWaitingSub => 'Te avisamos cuando te toque.';

  @override
  String get chatGameMvNudgeLater =>
      'Puedes avisarle tras 12 horas sin respuesta';

  @override
  String get chatGameMvForfeitNote =>
      'Si se acaba el tiempo, pierde quien tenga el turno';

  @override
  String get chatGameMvAgain => 'Sigue siendo tu turno. ¡Otra vez!';

  @override
  String get chatGameMvSending => 'Enviando…';

  @override
  String get howToNext => 'Siguiente';

  @override
  String get howToWatchAgain => 'Ver otra vez';

  @override
  String get howToGotIt => 'Entendido';

  @override
  String get howToProTip => 'Truco';

  @override
  String howToStepSemantic(int step, int total) {
    return 'Paso $step de $total';
  }

  @override
  String get howToQueens1 =>
      'Una corona en cada fila, cada columna y cada color.';

  @override
  String get howToQueens2 =>
      'Las coronas no se pueden tocar. Ni siquiera en diagonal.';

  @override
  String get howToQueens3 =>
      'Toca una vez para ×, dos para corona y otra más para borrar.';

  @override
  String get howToQueens4 =>
      'Con la opción Cruces automáticas, cada casilla que descarta una corona recibe una × sola. Luego mira qué queda.';

  @override
  String get howToTango1 =>
      'Un toque, sol. Dos toques, luna. Llena todas las casillas.';

  @override
  String get howToTango2 => 'Cada fila y columna es mitad soles, mitad lunas.';

  @override
  String get howToTango3 =>
      'Nunca 3 iguales seguidos, ni en horizontal ni en vertical. 2 sí vale.';

  @override
  String get howToTango4 =>
      '= significa que son iguales. × significa que son distintos.';

  @override
  String get howToTangoTip =>
      '¿Dos iguales juntos? Las casillas de los dos extremos llevan el otro.';

  @override
  String get howToZip1 =>
      'Empieza en el 1 y arrastra pasando por los números en orden.';

  @override
  String get howToZip2 =>
      'Pasa por todas las casillas y acaba en el último número.';

  @override
  String get howToZip3 =>
      '¿Te has equivocado? Arrastra hacia atrás y se deshace.';

  @override
  String get howToZipTip =>
      'No dejes ninguna casilla aislada. Barre esquinas y bordes al pasar.';

  @override
  String get howToSudoku1 =>
      'Cada fila, columna y caja lleva del 1 al 6. Sin repetir.';

  @override
  String get howToSudoku2 => 'Toca una casilla y luego un número.';

  @override
  String get howToSudoku3 =>
      '¿Un número repetido en la misma fila, columna o caja? Se pone en rojo.';

  @override
  String get howToSudoku4 =>
      'Busca líneas a las que solo les falte un número. Puntos gratis.';

  @override
  String get howToFlow1 =>
      'Arrastra desde un punto hasta su pareja para trazar la tubería.';

  @override
  String get howToFlow2 =>
      'Las tuberías no se cruzan y hay que llenar todas las casillas. Da la vuelta.';

  @override
  String get howToFlowTip =>
      'Lleva primero las tuberías por los bordes. El centro se resuelve solo.';

  @override
  String get howToFutoshiki1 =>
      'Llena cada casilla con un número del 1 al 5. Cada fila y columna lleva cada número exactamente una vez.';

  @override
  String get howToFutoshiki2 =>
      'La punta del signo señala el número más pequeño.';

  @override
  String get howToFutoshiki3 => '¿Rompes un signo? Se pone en rojo.';

  @override
  String get howToFutoshikiTip =>
      'Sigue las cadenas: si a < b < c, entonces c es al menos 3.';

  @override
  String get howToNonogram1 =>
      'Cada número es un tramo de casillas pintadas sin huecos. 5 son 5 casillas seguidas.';

  @override
  String get howToNonogram2 =>
      '1 1 son dos casillas sueltas con al menos una casilla vacía entre ellas. El hueco también puede ser mayor.';

  @override
  String get howToNonogramOrder =>
      'El orden importa: las filas se leen de izquierda a derecha y las columnas, de arriba abajo. 1 3 es primero un 1 y luego un 3.';

  @override
  String get howToNonogram3 =>
      'Toca para pintar, otra vez para ×, otra más para borrar. Arrastra para hacer muchas de golpe.';

  @override
  String get howToNonogram4 =>
      'Acierta todas las pistas y aparece el dibujo escondido.';

  @override
  String get howToNonogramTip =>
      'Empieza por las pistas grandes. Un 7 en una fila de 10 siempre cubre las 4 del centro.';

  @override
  String get howToMines1 =>
      'Abre todas las casillas que no tengan mina. Las zonas vacías se abren solas.';

  @override
  String get howToMines2 =>
      'Un número te dice cuántas minas lo tocan, esquinas incluidas.';

  @override
  String get howToMines3 =>
      '¿Seguro que es una mina? Mantén pulsado para ponerle bandera.';

  @override
  String get howToMines4 =>
      'Si pisas una mina, te comes 30 segundos de castigo. Pero nunca hace falta adivinar.';

  @override
  String get howToMinesTip =>
      '¿Un 1 con una sola casilla oculta al lado? Esa casilla es la mina.';

  @override
  String get howToStars1 =>
      'Dos estrellas en cada fila, cada columna y cada color.';

  @override
  String get howToStars2 =>
      'Las estrellas no se pueden tocar. Ni siquiera en diagonal.';

  @override
  String get howToStarsControls =>
      'Toca una vez para punto, dos para estrella y otra más para borrar.';

  @override
  String get howToStars3 =>
      'Con la opción Puntos automáticos, una estrella marca con un punto las casillas de su alrededor. Cuando una fila tiene sus 2, el resto también se marca.';

  @override
  String get howToPatches1 =>
      'Divide el tablero en rectángulos. Cada uno tiene exactamente una pista.';

  @override
  String get howToPatches2 =>
      'La insignia es la forma del parche: cuadrado, alto o ancho. Una insignia discontinua significa que puede ser cualquiera de las tres. El número, si lo hay, indica cuántas casillas cubre el parche.';

  @override
  String get howToPatches3 =>
      'Arrastra de esquina a esquina para cortar un parche. Toca un parche para quitarlo.';

  @override
  String get howToPatches4 =>
      'Una pista grande pegada al borde suele encajar de una sola forma. Empieza por ahí.';

  @override
  String get howToCode1 =>
      'Hay un código secreto de 4 símbolos distintos, sin repetir. Descífralo.';

  @override
  String get howToCode2 => 'Verde: símbolo correcto en su sitio.';

  @override
  String get howToCode3 =>
      'Amarillo: está en el código, pero en otro sitio. Gris: no está en el código.';

  @override
  String get howToCode4 => 'Tienes 6 intentos. Cuantos menos uses, mejor.';

  @override
  String get howToCodeTip =>
      'Usa tus primeros intentos en símbolos nuevos. Aprender gana a adivinar.';

  @override
  String get howToTtt1 => 'Por turnos, pon tu ficha. Haz 3 en raya y ganas.';

  @override
  String get howToTtt2 =>
      '¿Tiene 2 en línea? Quítale la tercera casilla antes que él.';

  @override
  String get howToC41 =>
      'Toca una columna para soltar una ficha. Cae hasta el hueco libre más bajo.';

  @override
  String get howToC42 =>
      'Junta 4 en línea para ganar: en horizontal, en vertical o en diagonal.';

  @override
  String get howToC4Tip =>
      'Juega en la columna del centro. Forma parte de más cuatros que ninguna otra.';

  @override
  String get howToCheckers1 =>
      'Las fichas avanzan una casilla en diagonal. Toca una ficha y luego adónde va.';

  @override
  String get howToCheckers2 =>
      'Salta por encima de una ficha rival para comértela. Si puedes saltar, tienes que hacerlo. La ficha que debe saltar sale con un aro.';

  @override
  String get howToCheckers3 =>
      '¿Caes donde puedes volver a saltar? Sigue. En un solo movimiento te puedes comer varias.';

  @override
  String get howToCheckers4 =>
      'Llega al otro lado y tu ficha se corona dama. Las damas también van hacia atrás, pero solo una casilla cada vez.';

  @override
  String get howToCheckersWin =>
      'Gana quien se come todas las fichas rivales o deja al otro sin movimientos. Si pasan 40 jugadas de cada uno sin capturas y sin mover ninguna ficha normal, es empate.';

  @override
  String get howToCheckersTip =>
      'Mantén tu última fila en casa. Así no pueden coronar reyes.';

  @override
  String get howToReversi1 =>
      'Pon una ficha de forma que una fila de las suyas quede atrapada entre dos tuyas. Cada jugada tiene que atrapar al menos una.';

  @override
  String get howToReversi2 =>
      'Todas las fichas atrapadas cambian a tu color, en todas las direcciones a la vez.';

  @override
  String get howToReversi3 =>
      '¿No tienes jugada? Te saltas el turno. Cuando nadie puede mover, gana quien tenga más fichas.';

  @override
  String get howToReversiTip =>
      'Hazte con las esquinas. Una ficha en una esquina no se puede voltear nunca.';

  @override
  String get howToDots1 => 'Por turnos, dibuja una línea entre dos puntos.';

  @override
  String get howToDots2 => 'Cierra una caja y es tuya. ¡Y vuelves a jugar!';

  @override
  String get howToDots3 =>
      'Ojo con el tercer lado de una caja. Se la estás regalando al siguiente.';

  @override
  String get howToDotsWin =>
      'Cuando se dibuja la última línea, gana quien tenga más cajas.';

  @override
  String get howToChess1 =>
      'Toca una pieza para ver adónde puede ir y luego toca una casilla.';

  @override
  String get howToChess2 =>
      'Muévete a la casilla de una pieza rival para comértela.';

  @override
  String get howToChess3 =>
      'Lleva un peón a la última fila y se convierte en dama, o en lo que elijas.';

  @override
  String get howToChess4 =>
      'Jaque es que atacan a tu rey y tienes que sacarlo de ahí. ¿No hay salida? Jaque mate y se acabó. ¿No puedes mover pero no estás en jaque? Son tablas.';

  @override
  String get howToChessTip => 'Antes de cada jugada, mira qué te pueden comer.';

  @override
  String get howToLiars1 =>
      'Todos tiran 5 dados en secreto. Tú solo ves los tuyos.';

  @override
  String get howToLiars2 =>
      'En tu turno, apuesta que hay al menos tantos dados de una cara en toda la mesa, contando los de todos. Por ejemplo, «cuatro treses».';

  @override
  String get howToLiars3 =>
      'Los unos son comodines: cuentan como cualquier cara. Salvo si la apuesta es a unos.';

  @override
  String get howToLiars4 =>
      'El siguiente tiene que subir: más dados, o los mismos de una cara más alta…';

  @override
  String get howToLiars5 =>
      '…o gritar «¡mentiroso!». Todos enseñan sus dados y se cuentan.';

  @override
  String get howToLiars6 =>
      '¿Hay al menos esos? Quien dijo mentiroso pierde un dado. ¿Hay menos? Lo pierde quien apostó.';

  @override
  String get howToLiars7 =>
      'Si te quedas sin dados, fuera. Gana el último que tenga dados.';

  @override
  String get howToLiarsClock =>
      '45 segundos por turno. Si se acaba, el juego mueve por ti.';

  @override
  String get howToLiarsTip =>
      'Cuenta primero tus dados. Como los 1 son comodines, más o menos un tercio de los dados de los demás coinciden con la cara que apuestas.';

  @override
  String get howToImposter1 =>
      'Todos reciben la misma palabra secreta. Menos el impostor, que solo ve la categoría.';

  @override
  String get howToImposter2 =>
      'Por turnos, da una pista corta. Demuestra que sabes la palabra sin regalarla.';

  @override
  String get howToImposterVoice =>
      'En modo voz: di tu pista en voz alta en la llamada y toca Listo.';

  @override
  String get howToImposter3 =>
      'Luego todos votan a quien creen que es el impostor, o no votan.';

  @override
  String get howToImposter4 =>
      '¿Lo pillasteis? El impostor tiene una última oportunidad: si adivina la palabra, se lleva la victoria. ¿Echáis a otro, hay empate o demasiados no votan? Gana el impostor.';

  @override
  String get howToRace1 =>
      'Todos reciben el mismo puzle nuevecito en el mismo momento.';

  @override
  String get howToRace2 =>
      'Resuélvelo en tu móvil. Tu barra les enseña a todos lo cerca que estás.';

  @override
  String get howToRace3 => 'Gana el primero en terminar. Tienes 10 minutos.';

  @override
  String get howToLive1 =>
      'Todos juegan a la vez. En cuanto todos tocan Estoy listo, empieza.';

  @override
  String get howToLive2 =>
      '¿Alguien sale del juego? Se pausa para todos. Tiene 2 minutos para volver o pierde.';

  @override
  String get howToLive3 =>
      'Los demás del chat pueden mirar. Pueden pedir sitio y un jugador puede cederles el suyo.';

  @override
  String get howToTurns1 =>
      'Haz tu jugada y toca Enviar jugada. Llega al chat como un mensaje.';

  @override
  String get howToTurns2 =>
      'Cada jugada tiene 2 días. Le avisamos a las 20 horas y, tras 12 horas sin noticias, puedes avisarle tú.';

  @override
  String get howToTurns3 =>
      '¿Sin jugada en 2 días? Cuenta como derrota. Hasta 3 partidas a la vez por chat.';

  @override
  String momentActivityGamesSolvedAll(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count juegos',
      one: '1 juego',
    );
    return '$name ha resuelto $_temp0';
  }

  @override
  String momentActivityGamesSolvedSome(int count, String name, int solved) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count juegos',
      one: '1 juego',
    );
    return '$name ha resuelto $solved de $_temp0';
  }

  @override
  String momentActivityGamesPlayed(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count juegos',
      one: '1 juego',
    );
    return '$name ha jugado $_temp0';
  }

  @override
  String momentActivityHighlightsPosted(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count momentos',
      one: '1 momento',
    );
    return '$name ha publicado $_temp0';
  }

  @override
  String podiumSharedBy(int count, String names, int place) {
    return 'Puesto $place, compartido por $count: $names';
  }

  @override
  String get myBestsLabel => 'Mis mejores marcas';

  @override
  String recordsSharedBy(int count, String name) {
    return '$name +$count';
  }

  @override
  String get reportSheetDisclosureMessage =>
      'Al denunciar, este mensaje y los últimos mensajes de este chat se envían a los moderadores de MonkeyHub para su revisión. La persona no sabrá que la denunciaste.';

  @override
  String get reportSheetDisclosureUser =>
      'Al denunciar, tus últimos mensajes con esta persona se envían a los moderadores de MonkeyHub para su revisión. No sabrá que la denunciaste.';

  @override
  String get reportSheetDisclosureRoom =>
      'Al denunciar, los últimos mensajes de este grupo se envían a los moderadores de MonkeyHub para su revisión. Nadie aquí sabrá que lo denunciaste.';

  @override
  String get reportSheetAlsoBlock => 'Bloquear también a esta persona';

  @override
  String get reportSentReviewed =>
      'Gracias. Nuestros moderadores revisan las denuncias en un plazo de 24 horas.';

  @override
  String get reportSentAndBlocked =>
      'Gracias. Nuestros moderadores revisan las denuncias en un plazo de 24 horas. Has bloqueado a esta persona.';

  @override
  String get reportTooMany =>
      'Has enviado muchas denuncias. Inténtalo de nuevo en un rato.';

  @override
  String get reportFailed =>
      'No se pudo enviar la denuncia. Inténtalo de nuevo.';

  @override
  String get riReportPerson => 'Denunciar a esta persona';

  @override
  String get riReportGroup => 'Denunciar este grupo';

  @override
  String get moderationActionRemoveMessage => 'Eliminar mensaje';

  @override
  String get moderationActionBan => 'Suspender usuario';

  @override
  String get moderationActionUnban => 'Quitar suspensión';

  @override
  String get moderationActionDismiss => 'Descartar denuncia';

  @override
  String get moderationConfirmRemoveTitle => '¿Eliminar este mensaje?';

  @override
  String get moderationConfirmRemoveBody =>
      'Se borra para todos en la conversación. La tarjeta de la denuncia conserva su copia.';

  @override
  String get moderationConfirmBanTitle => '¿Suspender esta cuenta?';

  @override
  String get moderationConfirmBanBody =>
      'Se cerrará su sesión en todas partes, no podrá volver a entrar, desaparecerá de las búsquedas y saldrá de todas las salas públicas. Puedes quitar la suspensión desde esta tarjeta.';

  @override
  String get moderationActionDone => 'Hecho';

  @override
  String get moderationActionFailed =>
      'No se pudo completar. Inténtalo de nuevo.';

  @override
  String get moderationCantBan =>
      'No se puede suspender a moderadores ni a cuentas del sistema.';

  @override
  String get messageFilterBlocked =>
      'Este mensaje no se puede enviar porque puede contener lenguaje inapropiado.';

  @override
  String get nameInappropriate =>
      'Ese nombre puede contener lenguaje inapropiado. Elige otro, por favor.';

  @override
  String get authErrorAccountSuspended =>
      'Tu cuenta ha sido suspendida por infringir las Condiciones de uso.';

  @override
  String get termsConsentPrefix => 'Acepto las ';

  @override
  String get termsConsentLink => 'Condiciones de uso (EULA)';

  @override
  String get termsConsentSuffix =>
      ' y entiendo que no se tolera en absoluto el contenido inapropiado ni a los usuarios abusivos.';

  @override
  String get termsConsentSemanticLabel => 'Aceptar las Condiciones de uso';

  @override
  String get termsMustAccept => 'Acepta las Condiciones de uso para continuar.';

  @override
  String get termsSheetTitle => 'Condiciones de uso';

  @override
  String get termsSheetBody =>
      'Para seguir usando MonkeyHub, acepta nuestras Condiciones de uso. Aquí no hay lugar para contenido inapropiado ni comportamientos abusivos, y nuestros moderadores revisan el contenido denunciado.';

  @override
  String get termsSheetAccept => 'Aceptar y continuar';

  @override
  String get termsAcceptFailed => 'No se pudo guardar. Inténtalo de nuevo.';

  @override
  String get settingsHubContactSupport => 'Contactar con soporte';

  @override
  String get reportSheetDisclosureMoment =>
      'Al denunciar, este momento se envía a los moderadores de MonkeyHub para que lo revisen. La persona no sabrá que la denunciaste.';

  @override
  String get reportSheetDisclosureComment =>
      'Al denunciar, este comentario se envía a los moderadores de MonkeyHub para que lo revisen. La persona no sabrá que la denunciaste.';

  @override
  String get sendLimitRateLimited =>
      'Estás enviando demasiado rápido. Espera un momento y vuelve a intentarlo.';

  @override
  String get sendLimitStorageFull =>
      'Tu almacenamiento está lleno. Elimina algunas fotos o archivos que hayas enviado para liberar espacio.';

  @override
  String get sendLimitFileTooLarge =>
      'Ese archivo es demasiado grande para enviarlo.';

  @override
  String get sendLimitMessageTooLong =>
      'Ese mensaje es demasiado largo. Prueba a dividirlo en varios mensajes.';

  @override
  String get limitTooOften =>
      'Lo estás haciendo demasiado a menudo. Vuelve a intentarlo dentro de un rato.';

  @override
  String get limitRoomFull => 'Esta sala está llena.';

  @override
  String get limitRemovedFromRoom =>
      'Te sacaron de esta sala. Un administrador puede volver a invitarte.';

  @override
  String get limitTooManyRooms =>
      'Estás en demasiadas salas. Primero sal de una que ya no uses.';

  @override
  String get limitRoomTextTooLong =>
      'Ese nombre o descripción es demasiado largo. Usa menos de 100 caracteres en el nombre y menos de 500 en la descripción.';

  @override
  String get limitNotYourFile =>
      'No se puede usar ese archivo. Vuelve a elegirlo e inténtalo de nuevo.';

  @override
  String get limitDeviceLoginBusy =>
      'Los códigos de inicio de sesión están ocupados ahora mismo. Vuelve a intentarlo en un minuto.';

  @override
  String get limitRequestMessages =>
      'No puedes enviar más hasta que acepte tu solicitud.';
}
