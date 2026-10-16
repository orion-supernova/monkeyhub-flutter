// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'Servidor inacessível';

  @override
  String get bootErrorBody => 'O Convex não foi inicializado.';

  @override
  String get bootErrorRetry => 'Tentar novamente';

  @override
  String get incomingCallNotificationTitle => 'Chamada a receber';

  @override
  String get incomingCallFallbackCaller => 'Alguém está a ligar';

  @override
  String get settingsLanguageRowLabel => 'IDIOMA';

  @override
  String get languageScreenTitle => 'idioma.';

  @override
  String get languageScreenSubtitle =>
      'escolhe o idioma dos menus e das mensagens da app';

  @override
  String get languageOptionSystem => 'SISTEMA';

  @override
  String get languageOptionSystemSub =>
      'usa o idioma definido no teu dispositivo';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => 'ATIVO';

  @override
  String get languageValueSystem => 'Sistema';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack =>
      'Não foi possível pedir agora. Tenta outra vez';

  @override
  String get roomScreenGateSendMessages => 'enviar mensagens aqui';

  @override
  String get roomScreenGateSendMedia => 'enviar fotos ou notas de voz';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'No máximo $max de cada vez';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminar $count mensagens',
      one: 'Eliminar mensagem',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Isto elimina as mensagens para todos nesta conversa. Não é possível desfazer esta ação.';

  @override
  String get roomScreenDeleteConfirmBodyOne =>
      'Isto elimina a mensagem para todos nesta conversa. Não é possível desfazer esta ação.';

  @override
  String get roomScreenDeleteConfirmButton => 'Eliminar para todos';

  @override
  String get roomScreenJumpFailedSnack =>
      'Não foi possível saltar para essa mensagem';

  @override
  String get roomScreenUnreadDivider => 'Mensagens não lidas';

  @override
  String get roomScreenViewOnceAlreadyViewed => 'Já abriste esta fotografia.';

  @override
  String get roomScreenViewOnceGone =>
      'Esta fotografia já não está disponível.';

  @override
  String get roomScreenViewOnceNetworkError =>
      'Não foi possível carregar essa fotografia.';

  @override
  String get roomScreenFileReadFailedSnack =>
      'Não foi possível ler esse ficheiro';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'Os ficheiros têm um limite de $size';
  }

  @override
  String get roomScreenRoomGone => 'Sala desapareceu';

  @override
  String get roomScreenCopiedSnack => 'Copiado';

  @override
  String get roomScreenNameCopiedSnack => 'Nome copiado';

  @override
  String get roomScreenPinLimitSnack =>
      'Demasiadas mensagens fixadas. Desafixa uma primeiro';

  @override
  String get roomScreenPinFailedSnack => 'Não foi possível fixar essa mensagem';

  @override
  String get roomScreenReportSentSnack =>
      'Denúncia enviada em privado. A outra pessoa não será notificada.';

  @override
  String get roomScreenDeselectMessageSemantic => 'Remover seleção da mensagem';

  @override
  String get roomScreenSelectMessageSemantic => 'Selecionar mensagem';

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
    return 'Esta sala é efémera. As mensagens desvanecem-se ao fim de $ttl, lidas ou não lidas.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count mensagens';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'Espaço Secreto';

  @override
  String get roomScreenSecretSpaceBody =>
      'As mensagens desta sala são efémeras. São removidas automaticamente de acordo com a política de segurança da sala.';

  @override
  String get roomReadOnlyFooter =>
      'Esta sala é só de leitura. Só o MonkeyHub publica aqui.';

  @override
  String get roomScreenAutoDeleteTitle => 'Eliminação Automática';

  @override
  String get roomScreenAutoDeleteVaries => 'Variável';

  @override
  String get roomScreenAutoDeleteTimed => 'Temporizado';

  @override
  String get roomScreenNoCaptureTitle => 'Sem Captura';

  @override
  String get roomScreenNoCaptureSubtitle => 'Capturas de Ecrã Restritas';

  @override
  String get roomScreenMorePrivacyTitle => 'Muito Mais Privacidade';

  @override
  String get roomScreenMorePrivacySubtitle =>
      'Aproveita funcionalidades de segurança extra, além do foco em privacidade já existente.';

  @override
  String get roomScreenNoMessagesTitle => 'Sem Mensagens';

  @override
  String get roomScreenNoMessagesSubtitle =>
      'Começa a conversa enviando uma mensagem';

  @override
  String get roomScreenViewProfilePictureSemantic => 'Ver foto de perfil';

  @override
  String get roomScreenViewRoomPictureSemantic => 'Ver foto da sala';

  @override
  String get messageBubbleFileFallbackName => 'Documento';

  @override
  String get messageBubbleAttachmentStatusFailed => 'Falhou';

  @override
  String get messageBubbleAttachmentStatusSending => 'A enviar…';

  @override
  String get messageBubbleViewOnceOpened => 'Aberta';

  @override
  String get messageBubbleViewOnceExpired => 'Expirada';

  @override
  String get messageBubbleViewOnceLabel => 'Ver uma vez';

  @override
  String get messageBubbleViewOnceTapToView => 'Toca para ver';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Foto';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'Foto de visualização única, toca para ver';

  @override
  String get messageBubblePlayOnceLabel => 'Reproduzir uma vez';

  @override
  String get messageBubblePlayOnceTapToPlay => 'Toca para reproduzir';

  @override
  String get messageBubblePlayOncePlayed => 'Reproduzido';

  @override
  String get messageBubblePlayOnceVoiceSemanticLabel =>
      'Mensagem de voz de reprodução única, toca para reproduzir';

  @override
  String get messageBubblePlayOnceVideoNoteSemanticLabel =>
      'Nota de vídeo de reprodução única, toca para reproduzir';

  @override
  String get replyIndicatorPlayOnceVoiceLabel =>
      'Mensagem de voz · reprodução única';

  @override
  String get replyIndicatorPlayOnceVideoNoteLabel =>
      'Nota de vídeo · reprodução única';

  @override
  String get roomScreenPlayOnceVoiceAlreadyPlayed =>
      'Já ouviste esta mensagem de voz.';

  @override
  String get roomScreenPlayOnceVoiceGone =>
      'Esta mensagem de voz já não está disponível.';

  @override
  String get roomScreenPlayOnceVoiceNetworkError =>
      'Não foi possível carregar essa mensagem de voz.';

  @override
  String get roomScreenPlayOnceVideoNoteAlreadyPlayed =>
      'Já viste esta nota de vídeo.';

  @override
  String get roomScreenPlayOnceVideoNoteGone =>
      'Esta nota de vídeo já não está disponível.';

  @override
  String get roomScreenPlayOnceVideoNoteNetworkError =>
      'Não foi possível carregar essa nota de vídeo.';

  @override
  String get messageBubbleRetrySendingSemanticLabel =>
      'Tentar enviar novamente';

  @override
  String get messageBubbleDiscardSemanticLabel => 'Descartar';

  @override
  String get profileScreenAccountSection => 'CONTA';

  @override
  String get profileScreenAddEmailPlaceholder => 'adicionar email';

  @override
  String get profileScreenAddEmailTitle => 'adicionar email?';

  @override
  String get profileScreenAddNameTitle => 'adicionar nome?';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count à espera';
  }

  @override
  String get profileScreenApprovalsLabel => 'APROVAÇÕES';

  @override
  String get profileScreenApprovalsNothingWaiting => 'nada à espera';

  @override
  String get profileScreenApproveAction => 'APROVAR';

  @override
  String get profileScreenBlockAction => 'BLOQUEAR';

  @override
  String get profileScreenBlockedDmWiped =>
      'bloqueado e a DM foi apagada. não vão ser notificados.';

  @override
  String get profileScreenBlockedOnly => 'bloqueado. não vão ser notificados.';

  @override
  String get profileScreenBlockedUsers => 'UTILIZADORES BLOQUEADOS';

  @override
  String get profileScreenCancelAction => 'CANCELAR';

  @override
  String get profileScreenCancelRequestAction => 'CANCELAR PEDIDO';

  @override
  String get profileScreenChangeAction => 'ALTERAR';

  @override
  String get profileScreenChangeEmailTitle => 'alterar o teu email?';

  @override
  String get profileScreenChangeNameTitle => 'alterar o teu nome?';

  @override
  String get profileScreenChangeProfilePictureSemantic =>
      'alterar foto de perfil';

  @override
  String get profileScreenChangeRecoveryPhrase =>
      'ALTERAR FRASE DE RECUPERAÇÃO';

  @override
  String get profileScreenChooseFromLibrary => 'ESCOLHER DA GALERIA';

  @override
  String get profileScreenCouldNotSaveImage =>
      'não foi possível guardar a imagem.';

  @override
  String get profileScreenDeleteAccount => 'ELIMINAR CONTA';

  @override
  String get profileScreenEmailHint => 'opcional, nunca é mostrado a ninguém';

  @override
  String get profileScreenEmailSectionLabel => 'EMAIL';

  @override
  String get profileScreenErrorAlreadyFriends => 'vocês já são amigos.';

  @override
  String get profileScreenErrorGeneric => 'não foi possível concluir isso.';

  @override
  String get profileScreenErrorNotAccepting =>
      'não estão a aceitar pedidos de amizade agora.';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      'já te enviaram um pedido. Vê os teus pedidos.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'pedido já enviado.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'bloqueaste este utilizador. Desbloqueia-o primeiro.';

  @override
  String get profileScreenErrorUserNotFound => 'isto não é possível agora.';

  @override
  String get profileScreenNameNotSaved =>
      'Não foi possível guardar o seu nome. Tente novamente.';

  @override
  String get profileScreenFamilyAddChild => 'adicionar uma criança';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count crianças',
      one: '$count criança',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => 'FAMÍLIA';

  @override
  String get profileScreenFriendsChip => 'AMIGOS';

  @override
  String get profileScreenGrownUpOnlyNote =>
      'Só uma pessoa crescida pode fazer isto. É preciso o código ou a palavra-passe dela.';

  @override
  String get profileScreenGuardiansCanSee =>
      'Podem ver quando estás online e com quem falas.';

  @override
  String get profileScreenHandPhoneBack => 'DEVOLVE ESTE TELEMÓVEL';

  @override
  String get profileScreenIncomingRequestChip => 'PEDIDO RECEBIDO';

  @override
  String get profileScreenJustTappedAction => 'FOI SEM QUERER';

  @override
  String get settingsScreenSectionHelpAndLegal => 'AJUDA E LEGAL';

  @override
  String get settingsScreenLicence => 'LICENÇA';

  @override
  String get profileScreenLinkedAccountsLabel => 'CONTAS LIGADAS';

  @override
  String get profileScreenLinkedAccountsNone => 'Nenhuma conta ligada';

  @override
  String get profileScreenMyGrownUps => 'OS MEUS GRANDES';

  @override
  String get profileScreenNameHint => 'como vais aparecer na sala';

  @override
  String get profileScreenChangeUsernameTitle => 'alterar nome de utilizador?';

  @override
  String get profileScreenChangeUsernameWarning =>
      'Inicias sessão com isto, por isso vais escrever o novo a partir de agora. O teu nome de utilizador antigo fica livre para outra pessoa o usar, e não o podes alterar novamente durante 30 dias. As mensagens antigas que te mencionaram mantêm o nome antigo.';

  @override
  String get profileScreenUsernameHint => 'como os teus amigos te encontram';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return 'Pode voltar a ser alterado a $date';
  }

  @override
  String get profileScreenUsernamePasswordTitle => 'confirma que és tu';

  @override
  String get profileScreenUsernamePasswordAction =>
      'ALTERAR NOME DE UTILIZADOR';

  @override
  String get profileScreenUsernameProviderTitle =>
      'confirma com o teu início de sessão';

  @override
  String profileScreenUsernameChanged(String username) {
    return 'Agora és @$username.';
  }

  @override
  String get profileScreenUsernameNotSaved =>
      'Não foi possível alterar o teu nome de utilizador. Tenta novamente.';

  @override
  String get usernameStatusChecking => 'a verificar…';

  @override
  String get usernameStatusAvailable => 'disponível';

  @override
  String get usernameStatusTaken => 'já está em uso';

  @override
  String get usernameStatusReserved => 'indisponível';

  @override
  String get usernameStatusInvalid => '1–32 caracteres';

  @override
  String get usernameStatusUnknown => 'não foi possível verificar';

  @override
  String get profileScreenNobodyLookingAfter =>
      'ainda ninguém cuida desta conta';

  @override
  String get profileScreenNotAcceptingRequestsAction => 'NÃO ACEITA PEDIDOS';

  @override
  String get profileScreenNotConnectedChip => 'SEM LIGAÇÃO';

  @override
  String get profileScreenOpenDmAction => 'ABRIR DM';

  @override
  String get profileScreenPhotoPermissionDenied => 'permissão de fotos negada.';

  @override
  String get settingsScreenPrivacyPolicy => 'POLÍTICA DE PRIVACIDADE';

  @override
  String get profileScreenPrivacySection => 'PRIVACIDADE';

  @override
  String get profileScreenProfilePictureTitle => 'FOTO DE PERFIL';

  @override
  String get profileScreenRedactedFriend =>
      'alguns campos estão ocultos pelas definições desta pessoa.';

  @override
  String get profileScreenRedactedStranger =>
      'vista limitada: partilham mais com os amigos.';

  @override
  String get profileScreenReportAction => 'DENUNCIAR';

  @override
  String get profileScreenReportSent =>
      'denúncia enviada em privado. não serão notificados.';

  @override
  String get profileScreenRequestPendingChip => 'PEDIDO PENDENTE';

  @override
  String get profileScreenSaveAction => 'GUARDAR';

  @override
  String get profileScreenSavedToPhotos => 'guardado em fotos.';

  @override
  String get profileScreenSaveToPhotos => 'GUARDAR EM FOTOS';

  @override
  String get profileScreenSendRequestAction => 'ENVIAR PEDIDO';

  @override
  String get profileScreenSetUpRecoveryPhrase =>
      'CONFIGURAR FRASE DE RECUPERAÇÃO';

  @override
  String get profileScreenSignOut => 'TERMINAR SESSÃO';

  @override
  String get profileScreenTakeSelfie => 'TIRAR UMA SELFIE';

  @override
  String get profileScreenTapAgainToConfirmDelete =>
      'TOCA DE NOVO PARA CONFIRMAR A ELIMINAÇÃO';

  @override
  String get settingsScreenTermsOfService => 'TERMOS DE SERVIÇO';

  @override
  String get profileScreenThisPhoneSection => 'ESTE TELEMÓVEL';

  @override
  String get profileScreenUnfriendAction => 'REMOVER AMIGO';

  @override
  String get profileScreenViewProfilePictureSemantic => 'ver foto de perfil';

  @override
  String get profileScreenVisibilityPreferences =>
      'PREFERÊNCIAS DE VISIBILIDADE';

  @override
  String get cameraEditorScreenCropPresetFree => 'Livre';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'Orig.';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'Cancelar o recorte';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'Descartar a foto';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'Desfazer';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'Refazer';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'Repor o recorte';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'Rodar';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'Recortar';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'Este navegador não consegue abrir fotos HEIC';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'Não conseguimos abrir essa imagem';

  @override
  String get cameraEditorScreenCropDoneButton => 'Concluído';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'Tirar novamente';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'Guardar a caneta';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'Desenhar na foto';

  @override
  String get cameraEditorScreenSendingButton => 'A enviar…';

  @override
  String get cameraEditorScreenSendButton => 'Enviar';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'Desaparece depois de ser aberta uma vez';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'Limpar o desenho';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel =>
      'Visualização única: ativada';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel =>
      'Visualização única: desativada';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: ativado';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: desativado';

  @override
  String get cameraEditorScreenHdNote => 'A enviar na resolução original';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'Cor da tinta';

  @override
  String get glassScreenPanelLooks => 'Estilos';

  @override
  String get glassScreenPanelBottomBar => 'Barra inferior';

  @override
  String get glassScreenPanelOtherSurfaces => 'Outras superfícies';

  @override
  String get glassScreenPanelBarLayout => 'Disposição da barra';

  @override
  String get glassScreenTitle => 'vidro.';

  @override
  String get glassScreenSubtitle => 'quanto se vê do que está por trás';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'Todos os $max espaços ocupados';
  }

  @override
  String get glassScreenSaveCurrentAs => 'Guardar atual como…';

  @override
  String get glassScreenResetEveryDial => 'Repor todos os comandos';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'Repor para $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'A caixa de mensagem, os cabeçalhos, os botões de chamada: tudo o que fica sobre texto em vez de sobre conteúdo que desliza';

  @override
  String get glassScreenMatchBottomBar => 'Igualar à barra inferior';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'Editado. Guarda como um novo estilo, ou repõe';

  @override
  String get glassScreenCustomPresetName => 'Personalizado';

  @override
  String get glassScreenUnsavedSubtitle =>
      'Não guardado. Dá-lhe um nome para o manteres';

  @override
  String get glassScreenSaveDialogTitle => 'Guardar este visual como';

  @override
  String get glassScreenNoRoomToast => 'Sem espaço. Elimina um visual primeiro';

  @override
  String get glassScreenRenameDialogTitle => 'Mudar nome';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'Eliminar $name?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'O visual continua no ecrã, só deixa de ter nome.';

  @override
  String get glassScreenKeepButton => 'Manter';

  @override
  String get glassScreenDeleteButton => 'Eliminar';

  @override
  String get glassScreenNameHint => 'Noite tardia';

  @override
  String get glassScreenCancelButton => 'Cancelar';

  @override
  String get glassScreenSaveButton => 'Guardar';

  @override
  String get glassScreenPreviewRoomName => '# varanda';

  @override
  String get glassScreenPreviewOnlineCount => '4 online';

  @override
  String get glassScreenPreviewMessageHint => 'mensagem';

  @override
  String get glassScreenPreviewCollapseLabel => 'recolher pré-visualização';

  @override
  String get glassScreenPreviewExpandLabel => 'expandir pré-visualização';

  @override
  String get glassScreenPreviewBadge => 'Pré-visualização';

  @override
  String get glassScreenBuiltInLabel => 'De série';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'Substituir $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'Mudar nome de $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'Eliminar $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'Repor $label';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'enviou as fotos do telhado, as telhas estão todas rachadas';

  @override
  String get glassScreenBackdropMsgMert =>
      'ok mas quem é que traz mesmo a coluna';

  @override
  String get glassScreenBackdropGroupFamily => 'família';

  @override
  String get glassScreenBackdropMsgFamily =>
      'Mãe: jantar às 8, não te atrases outra vez';

  @override
  String get glassScreenBackdropMsgZeynep => 'estou lá fora';

  @override
  String get glassScreenBackdropMsgKerem =>
      'o sítio da esquina é que faz o bom café';

  @override
  String get glassScreenBackdropGroupWork => 'trabalho';

  @override
  String get glassScreenBackdropMsgWork =>
      'o standup mudou para as 10:30 pelo resto da semana';

  @override
  String get glassScreenBackdropMsgElif =>
      'não acredito. manda outra vez, perdi isso';

  @override
  String get glassScreenBackdropMsgBaran => 'aterrei 👍';

  @override
  String get glassScreenBackdropMsgAyse =>
      'o gato aprendeu a abrir a porta da varanda';

  @override
  String get glassScreenBackdropMsgCan => 'então vemo-nos no sábado';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return 'em resposta a $name';
  }

  @override
  String get replyIndicatorViewOnceLabel => 'Foto · ver uma vez';

  @override
  String get replyIndicatorVoiceMessageLabel => 'Mensagem de voz';

  @override
  String get replyIndicatorDocumentLabel => 'Documento';

  @override
  String get replyIndicatorMessageRemoved => 'Mensagem removida';

  @override
  String get threadOverlayMessageNotFound =>
      'Não consegui encontrar essa mensagem neste tópico';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'Não consegui encontrar o tópico para responder';

  @override
  String get threadOverlayStillSending =>
      'Ainda a enviar. Tenta novamente daqui a pouco';

  @override
  String get threadOverlayCopiedToast => 'Copiado';

  @override
  String get threadOverlayNameCopiedToast => 'Nome copiado';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'Coordenadas copiadas';

  @override
  String get threadOverlayPinLimitToast =>
      'Demasiadas mensagens fixadas. Desafixa uma primeiro';

  @override
  String get threadOverlayPinFailedToast => 'Não consegui fixar isso';

  @override
  String get threadOverlayReportedToast => 'Denunciado';

  @override
  String get threadOverlayUnavailable => 'tópico indisponível';

  @override
  String get roomInfoScreenNameRequiredError => 'O nome é obrigatório';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'Palavra-passe removida';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'Sair da sala?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'Podes voltar a entrar se ela continuar aberta.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'Sair';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'Eliminar sala?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'Todas as mensagens aqui desaparecem com ela. Isto é permanente.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'Eliminar';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      'Terminar esta conversa?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName também perde esta conversa: todas as mensagens desaparecem para os dois. Isto é permanente.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'Terminar';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'A outra pessoa';

  @override
  String get roomInfoScreenConfirmCancelButton => 'CANCELAR';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'Já existe uma sala com esse nome';

  @override
  String get roomNameReservedError =>
      'Os nomes de sala não podem começar por dm:';

  @override
  String get roomInfoScreenErrorNotOwner => 'Só o dono pode fazer isso';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'Não tens permissão';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'Esta sala já não existe';

  @override
  String get roomInfoScreenRoomGone => 'A sala desapareceu';

  @override
  String get roomInfoScreenNameLabel => 'NOME';

  @override
  String get roomInfoScreenNameHint => 'Nome da sala';

  @override
  String get roomInfoScreenDescriptionLabel => 'DESCRIÇÃO';

  @override
  String get roomInfoScreenDescriptionHint => 'Uma linha sobre a sala';

  @override
  String get roomInfoScreenVisibilityLabel => 'VISIBILIDADE';

  @override
  String get roomInfoScreenPublicTitle => 'pública';

  @override
  String get roomInfoScreenPublicSub => 'qualquer pessoa pode encontrá-la';

  @override
  String get roomInfoScreenPrivateTitle => 'privada';

  @override
  String get roomInfoScreenPrivateSub => 'só com convite';

  @override
  String get roomInfoScreenMessageLifeLabel => 'VIDA DA MENSAGEM';

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
  String get roomInfoScreenPasswordLabel => 'PALAVRA-PASSE';

  @override
  String get roomInfoScreenLockedBadge => 'BLOQUEADA';

  @override
  String get roomInfoScreenNoneBadge => 'NENHUMA';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      'esta sala está protegida. Por motivos de segurança, a palavra-passe atual não é apresentada. Introduz uma nova para a substituir.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'Substituir palavra-passe';

  @override
  String get roomInfoScreenSetPasswordHint => 'Bloquear com uma palavra-passe';

  @override
  String get roomInfoScreenRemovePasswordButton => 'REMOVER PALAVRA-PASSE';

  @override
  String get roomInfoScreenSharedContentLabel => 'CONTEÚDO PARTILHADO';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return 'MEMBROS · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => 'A SAIR…';

  @override
  String get roomInfoScreenLeaveRoomButton => 'SAIR DA SALA';

  @override
  String get roomInfoScreenDeletingButton => 'A ELIMINAR…';

  @override
  String get roomInfoScreenDeleteButtonLabel => 'ELIMINAR';

  @override
  String get roomInfoScreenEndingConversationButton => 'A TERMINAR…';

  @override
  String get roomInfoScreenEndConversationButton => 'TERMINAR CONVERSA';

  @override
  String get roomInfoScreenHeaderConversation => 'CONVERSA';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'DEFINIÇÕES DA SALA';

  @override
  String get roomInfoScreenViewProfilePictureSemantic => 'Ver foto de perfil';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'Ver foto da sala';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'Alterar foto da sala';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'Adicionar foto da sala';

  @override
  String get roomInfoScreenOwnerBadge => 'DONO';

  @override
  String get roomInfoScreenNoneCount => 'nenhum';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'O acesso à câmara está desativado.\nAtiva-o nas Definições para tirares uma fotografia.';

  @override
  String get cameraScreenOpeningSystemCamera => 'A abrir a câmara do sistema…';

  @override
  String get cameraScreenCloseButtonLabel => 'Fechar câmara';

  @override
  String get cameraScreenLowLightBoostOnLabel =>
      'Reforço de pouca luz: ativado';

  @override
  String get cameraScreenLowLightBoostOffLabel =>
      'Reforço de pouca luz: desativado';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'Flash: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'Escolher da galeria';

  @override
  String get cameraScreenSwitchCameraLabel => 'Mudar de câmara';

  @override
  String get cameraScreenTakePhotoLabel => 'Tirar fotografia';

  @override
  String get childPolicyScreenAddByUsernameLabel =>
      'Adicionar por nome de utilizador';

  @override
  String get childPolicyScreenAddCta => 'Adicionar';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'Ficam com exatamente o que tu tens: todos os pedidos para aprovar, todas as definições para alterar e o poder de te remover. Para $name, são logo família.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'Adicionar um crescido';

  @override
  String get childPolicyScreenAddGuardianHint =>
      'O nome de utilizador da pessoa';

  @override
  String get childPolicyScreenAllowCta => 'Permitir';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'Não te vão voltar a perguntar sobre essa pessoa, quer seja $childName a adicioná-la, quer seja ela a adicionar $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'Permitir alguém';

  @override
  String get childPolicyScreenAskToAddLabel => 'Pedir para adicionar';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'Só família, sem pedidos novos';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'Podem perguntar-te sobre pessoas novas';

  @override
  String get childPolicyScreenBothFinalNote =>
      'Ambas as opções são definitivas. Se preferires só retirar-te, isso está em Crescidos, mais acima.';

  @override
  String get childPolicyScreenCallsLabel => 'Chamadas';

  @override
  String get childPolicyScreenCallsOffDesc => 'Só mensagens';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'Voz + vídeo com as pessoas permitidas';

  @override
  String get childPolicyScreenCancelLabel => 'Cancelar';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Cancelar';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'Adicionado. O pedido está a caminho';

  @override
  String get childPolicyScreenContactAddedToList =>
      'Adicionado à lista de permitidos';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'Criar salas';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'Não podem criar salas';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'Podem criar as suas próprias salas privadas';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Tudo desaparece: as mensagens, fotografias, salas e amigos da criança. Isto não pode ser desfeito, e o nome de utilizador fica livre para qualquer outra pessoa.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'Não foi possível eliminar a conta. Tenta outra vez';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return 'Eliminar a conta de $name?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Mensagens, fotografias, salas e amigos, tudo desaparece. Não pode ser desfeito.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'Eliminar a conta de $name';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'Eliminar para sempre';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'Não foi possível adicionar essa pessoa. Tenta outra vez';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'Esse é o nome de utilizador da própria criança';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'Uma criança não pode ser um crescido';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'Não foi possível fazer isso. Tenta outra vez';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'Alguém tem de cuidar dele. Adiciona primeiro outro crescido';

  @override
  String get childPolicyScreenErrorNotYours => 'Isso não é teu para mudares';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'Não há nenhuma conta com esse nome de utilizador';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'Ele passa a ter uma conta normal com esta palavra-passe, e todos os crescidos perdem toda a visibilidade. Não há volta atrás: terias de ser convidado como qualquer outra pessoa.';

  @override
  String get childPolicyScreenGraduateCta => 'Graduar';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'Ele mantém tudo e recebe uma palavra-passe. Perdes toda a visibilidade. Irreversível.';

  @override
  String get childPolicyScreenGraduateDangerLabel =>
      'Graduar para conta completa';

  @override
  String get childPolicyScreenGraduateFailed =>
      'Não foi possível graduar. Tenta outra vez';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'Graduar $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'Uma palavra-passe para ele';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Retirar uma sala também o remove dela. Retirar uma pessoa também apaga a conversa, para os dois.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Todos aqui podem aprovar, mudar definições e ver tudo. Qualquer um deles pode agir sozinho, ninguém espera pelos outros.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'Adicionado. Já pode cuidar dele agora';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name removido';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (tu)';
  }

  @override
  String get childPolicyScreenLoading => 'A carregar…';

  @override
  String get childPolicyScreenLockedLabel => 'Bloqueado';

  @override
  String get childPolicyScreenMediaLabel => 'Fotos + voz';

  @override
  String get childPolicyScreenMediaOffDesc => 'Só texto';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'Pode enviar fotos, vídeos e notas de voz';

  @override
  String get childPolicyScreenNoRoomsYet => 'Ainda sem salas';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Qualquer pessoa aqui pode ser adicionada sem te perguntar outra vez, seja quem for a começar.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Sempre desligado para crianças. O Descobrir (a lista de salas de pessoas que não conheces) fica completamente escondido e não pode ser ativado. Se alguém o convidar para uma sala, continua a funcionar normalmente.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'Salas públicas';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian deixa de ver ou aprovar o que quer que seja sobre $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return 'Remover $name?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'Remover';

  @override
  String childPolicyScreenRoomMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '1 membro',
    );
    return '$_temp0';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'Crescidos';

  @override
  String get childPolicyScreenSectionPeopleAllowed => 'Pessoas que autorizaste';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'Salas que autorizaste';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'O que ele pode fazer';

  @override
  String get childPolicyScreenSectionWhenDone => 'Quando terminar';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'Nada acontece até alguém adicionar o outro';

  @override
  String get childPolicyScreenSendNowOnDesc => 'Recebem o pedido de imediato';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'Enviar o pedido agora';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'És o único adulto responsável por $name, por isso não podes simplesmente sair. Adiciona primeiro outro adulto, ou usa uma destas opções.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'Sair';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'Vais perder toda a visibilidade sobre a conta de $name: os seus pedidos, as suas pessoas, as suas salas. Os outros adultos continuam a cuidar de $name.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'Parar de supervisionar';

  @override
  String get childPolicyScreenStopSupervisingHeadline =>
      'Parar de supervisionar?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'Não foi possível retirar. Tenta outra vez';

  @override
  String get childPolicyScreenTakeBackLabel => 'Retirar';

  @override
  String get childPolicyScreenUsernameHint => 'Nome de utilizador';

  @override
  String get childPolicyScreenYou => 'Tu';

  @override
  String get roomContentScreenDefaultDocumentName => 'Documento';

  @override
  String get roomContentScreenCouldntOpenFile =>
      'Não foi possível abrir esse ficheiro';

  @override
  String get roomContentScreenCouldntShare => 'Não foi possível partilhar isso';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links copiados',
      one: 'Copiado',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eliminar $count mensagens',
      one: 'Eliminar mensagem',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Isto remove-as para todos nesta sala. Não pode ser desfeito.';

  @override
  String get roomContentScreenDeleteForEveryone => 'Eliminar para todos';

  @override
  String get roomContentScreenCancelTooltip => 'Cancelar';

  @override
  String get roomContentScreenBackTooltip => 'Voltar';

  @override
  String get roomContentScreenSelectingLabel => 'A selecionar';

  @override
  String get roomContentScreenSharedContentLabel => 'Conteúdo partilhado';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '$count selecionado',
      zero: 'Nada selecionado',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'Selecionar';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'Tudo';

  @override
  String get roomContentScreenEmptyMedia => 'Ainda não há fotos nem vídeos';

  @override
  String get roomContentScreenEmptyFiles => 'Ainda não há ficheiros';

  @override
  String get roomContentScreenEmptyVoice => 'Ainda não há notas de voz';

  @override
  String get roomContentScreenEmptyLinks => 'Ainda não há links';

  @override
  String get roomContentScreenEmptySaved =>
      'Ainda não guardaste nada. Mantém premida uma mensagem e escolhe Guardar.\n\nO que guardas aqui é só teu. Uma mensagem fixada é o que toda a sala vê.';

  @override
  String get roomContentScreenLoadFailed => 'Não foi possível carregar isso';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Nota de voz de $name';
  }

  @override
  String get roomContentScreenForwardAction => 'Reencaminhar';

  @override
  String get roomContentScreenCopyAction => 'Copiar';

  @override
  String get roomContentScreenSaveAction => 'Guardar';

  @override
  String get roomContentScreenShareAction => 'Partilhar';

  @override
  String get roomContentScreenInChatAction => 'No chat';

  @override
  String get roomContentScreenDeleteAction => 'Eliminar';

  @override
  String get messageActionMenuReplyLabel => 'Responder';

  @override
  String get messageActionMenuEditLabel => 'Editar';

  @override
  String get messageStampEditedLabel => 'editado';

  @override
  String get composerEditCardTitle => 'Editar mensagem';

  @override
  String get spoilerRevealHint => 'Spoiler: ativar para revelar o texto oculto';

  @override
  String get formatToolbarFormatLabel => 'Formatar';

  @override
  String get formatToolbarBoldLabel => 'Negrito';

  @override
  String get formatToolbarItalicLabel => 'Itálico';

  @override
  String get formatToolbarStrikethroughLabel => 'Rasurado';

  @override
  String get formatToolbarUnderlineLabel => 'Sublinhado';

  @override
  String get formatToolbarSpoilerLabel => 'Spoiler';

  @override
  String get formatToolbarLinkLabel => 'Link';

  @override
  String get formatToolbarCodeLabel => 'Código';

  @override
  String get linkInputSheetTitle => 'LINK';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => 'APLICAR LINK';

  @override
  String get linkInputSheetApplySub =>
      'O texto selecionado abrirá este endereço quando lhe tocares';

  @override
  String get linkInputSheetRemoveLabel => 'REMOVER LINK';

  @override
  String get linkConfirmSheetTitle => 'Abrir este link?';

  @override
  String get linkConfirmSheetOpenLabel => 'Abrir link';

  @override
  String get linkConfirmSheetCancelLabel => 'Cancelar';

  @override
  String get roomScreenEditExpiredSnack =>
      'Demasiado tarde para editar. As mensagens só podem ser editadas durante 15 minutos.';

  @override
  String get roomScreenEditFailedSnack =>
      'Não foi possível guardar a edição. Verifica a tua ligação e tenta novamente.';

  @override
  String get messageActionMenuForwardLabel => 'Reencaminhar';

  @override
  String get messageActionMenuViewThreadLabel => 'Ver tópico';

  @override
  String get messageActionMenuCopyLabel => 'Copiar';

  @override
  String get messageActionMenuCopyNameLabel => 'Copiar nome';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'Copiar coordenadas';

  @override
  String get messageActionMenuPinLabel => 'Fixar';

  @override
  String get messageActionMenuUnpinLabel => 'Desafixar';

  @override
  String get messageActionMenuSelectLabel => 'Selecionar';

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
      'toca para aplicar · ⛶ para pré-visualização completa';

  @override
  String get themeScreenFamilyBasicName => 'BÁSICO';

  @override
  String get themeScreenFamilyBasicTagline => 'inspirado no iOS · 5 paletas';

  @override
  String get themeScreenFamilyVaultName => 'COFRE';

  @override
  String get themeScreenFamilyVaultTagline =>
      'dossiê confidencial · noir + marfim';

  @override
  String get themeScreenFamilyOthersName => 'OUTROS';

  @override
  String get themeScreenFamilyOthersTagline => 'atmosferas próprias';

  @override
  String get themeScreenActiveBadge => 'ATIVO';

  @override
  String get themeScreenTapToApplyLabel => 'toca para aplicar';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return 'ATIVO: $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return 'APLICAR $name';
  }

  @override
  String get themeScreenPreviewGreeting => 'hey, tu.';

  @override
  String get themeScreenPreviewSectionLabel => 'CONVERSA';

  @override
  String get themeScreenPreviewRoomOneName => 'clube de design';

  @override
  String get themeScreenPreviewRoomOneSub => 'mia: lançou o novo mosaico.';

  @override
  String get themeScreenPreviewRoomTwoName => 'câmara · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => 'selado em 4h.';

  @override
  String get themeScreenPreviewBubbleQuestion => 'que sensação dá isto?';

  @override
  String get themeScreenPreviewBubbleAnswer => 'parece a certa.';

  @override
  String get callScreenVideoCallLabel => 'Chamada de vídeo';

  @override
  String get callScreenVoiceCallLabel => 'Chamada de voz';

  @override
  String callScreenStatusCalling(String kind) {
    return '$kind · a ligar…';
  }

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · a tocar…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · a receber';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · a ligar…';
  }

  @override
  String get callScreenStatusConnected => 'Ligada';

  @override
  String get callScreenStatusEnded => 'Chamada terminada';

  @override
  String get callScreenStatusFailed => 'Chamada falhada';

  @override
  String get callScreenStatusSwitching => 'A mudar de dispositivo…';

  @override
  String get callScreenStatusMoved => 'Transferida';

  @override
  String get callScreenStatusReconnecting => 'A reconectar…';

  @override
  String get callScreenPoorConnectionLabel => 'Má ligação';

  @override
  String get callScreenWeakConnectionLabel => 'Ligação fraca';

  @override
  String get callScreenControlUnmute => 'Ativar som';

  @override
  String get callScreenControlMute => 'Silenciar';

  @override
  String get callScreenControlCamOn => 'Ligar câmara';

  @override
  String get callScreenControlCamOff => 'Desligar câmara';

  @override
  String get callScreenControlFlip => 'Virar';

  @override
  String get callScreenControlSpeaker => 'Altifalante';

  @override
  String get callAudioControlLabel => 'Áudio';

  @override
  String get callAudioSheetTitle => 'Áudio';

  @override
  String get callAudioRoutePhone => 'Telemóvel';

  @override
  String get callAudioRouteHeadphones => 'Auscultadores';

  @override
  String get callAudioRouteBluetooth => 'Bluetooth';

  @override
  String get callAudioRouteCar => 'Carro';

  @override
  String get callAudioRouteOther => 'Outro dispositivo';

  @override
  String get callAudioMicFollowsNote =>
      'O microfone muda com o dispositivo que escolheres.';

  @override
  String get callAudioMicrophoneHeader => 'Microfone';

  @override
  String get callAudioUnknownDevice => 'Dispositivo desconhecido';

  @override
  String get callAudioNoDevices => 'Nenhum dispositivo encontrado';

  @override
  String get callAudioSwitchFailed =>
      'Não foi possível mudar o dispositivo de áudio';

  @override
  String get callScreenControlEnd => 'Terminar';

  @override
  String get linkPreviewCardLinkLabel => 'Link';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name aceitou o teu pedido';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'Esse pedido foi retirado';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'Pedido recusado';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'Bloqueaste este utilizador. Desbloqueia primeiro.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'Não estão a aceitar pedidos de amizade neste momento.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'Não foi possível enviar. Tenta outra vez.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => 'Pedido recebido';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'Novo pedido';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name quer começar uma conversa.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'manda umas linhas. podem aceitar ou recusar.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'Nada aqui é permanente até ambos concordarem.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'Tipo de sala';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'Efémera';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'Normal';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'Duração';

  @override
  String friendRequestDraftScreenDurationSeconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String friendRequestDraftScreenDurationMinutes(Object minutes) {
    return '${minutes}min';
  }

  @override
  String friendRequestDraftScreenDurationHours(Object hours) {
    return '${hours}h';
  }

  @override
  String get friendRequestDraftScreenHintWhisperOptional =>
      'Sussurra uma primeira linha · opcional';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'Adiciona uma primeira mensagem · opcional';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'Sussurra · desvanece sozinho';

  @override
  String get friendRequestDraftScreenHintStartWith => 'Algo para começar';

  @override
  String get friendRequestDraftScreenApproveButton => 'Aprovar e abrir sala';

  @override
  String get friendRequestDraftScreenDeclineButton => 'Recusar';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'Cancelar pedido';

  @override
  String get friendRequestDraftScreenAskGrownUpButton =>
      'Perguntar a um adulto';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'Enviar pedido';

  @override
  String get discoverScreenTitle => 'descobre.';

  @override
  String get discoverScreenCaptionPeople => 'pessoas';

  @override
  String get discoverScreenCaptionRooms => 'salas';

  @override
  String get discoverScreenCaptionRequests => 'pedidos';

  @override
  String get discoverScreenPeopleBandLabel => 'Pessoas';

  @override
  String get discoverScreenRoomsBandLabel => 'Salas';

  @override
  String get discoverScreenFindPeopleTitle => 'Encontrar pessoas';

  @override
  String get discoverScreenFindPeopleSubtitleChild =>
      'Escreve o nome de utilizador completo';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'Pesquisa por @utilizador ou nome';

  @override
  String get discoverScreenRequestsSectionLabel => 'Pedidos';

  @override
  String get discoverScreenInboxQuiet => 'Caixa de entrada silenciosa';

  @override
  String get discoverScreenNothingPending => 'Nada enviado';

  @override
  String get discoverScreenYourPeopleLabel => 'Amigos';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'Ainda ninguém. Encontra pessoas aí em cima';

  @override
  String get discoverScreenNoFriendsYet => 'Ainda ninguém';

  @override
  String get discoverScreenSearchRoomsTitle => 'Procurar salas';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'Encontra uma sala pública pelo nome';

  @override
  String get discoverScreenYourRoomsLabel => 'Salas';

  @override
  String get discoverScreenNoRoomsYet => 'Ainda nenhuma sala';

  @override
  String get discoverScreenIncomingLabel => 'Recebidos';

  @override
  String get discoverScreenOutgoingLabel => 'Enviados';

  @override
  String get discoverScreenIncomingLabelCaps => 'RECEBIDOS';

  @override
  String get discoverScreenOutgoingLabelCaps => 'ENVIADOS';

  @override
  String get discoverScreenJumpPeopleLabel => 'Pessoas';

  @override
  String get discoverScreenJumpRoomsLabel => 'Salas';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Ir para $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'Ajustar';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'Usar foto';

  @override
  String get imageCropScreenSavingButton => 'A guardar…';

  @override
  String get imageCropScreenCancelButton => 'Cancelar';

  @override
  String get imageCropScreenHeicUnsupported =>
      'Este navegador não consegue abrir fotos HEIC';

  @override
  String get imageCropScreenLoadFailed => 'Não conseguimos abrir esta imagem';

  @override
  String get imageCropScreenHintCircle =>
      'Arrasta para mover, belisca para ampliar';

  @override
  String get imageCropScreenHintRect => 'Arrasta e belisca para enquadrar';

  @override
  String get loginScreenSignInHeroMuted => 'bem-vindo\n';

  @override
  String get loginScreenSignInHeroInk => 'de volta.';

  @override
  String get loginScreenSignInFirstHeroMuted => 'olá\n';

  @override
  String get loginScreenSignInFirstHeroInk => 'tudo bem.';

  @override
  String get loginScreenSignInCta => 'ENTRAR';

  @override
  String get loginScreenSignUpHeroMuted => 'novo\n';

  @override
  String get loginScreenSignUpHeroInk => 'membro.';

  @override
  String get loginScreenSignUpCta => 'ABRIR CONTA';

  @override
  String get loginScreenResetHeroMuted => 'repor\n';

  @override
  String get loginScreenResetHeroInk => 'palavra-passe.';

  @override
  String get loginScreenResetCta => 'REPOR PALAVRA-PASSE';

  @override
  String get loginScreenErrorPasswordsDontMatch =>
      'As palavras-passe não coincidem.';

  @override
  String get loginScreenErrorChoosePasswordFirst =>
      'Escolhe primeiro uma palavra-passe.';

  @override
  String get loginScreenUsernameHint => 'nome de utilizador';

  @override
  String get loginScreenPasswordHint => 'palavra-passe';

  @override
  String get loginScreenConfirmPasswordHint => 'confirmar palavra-passe';

  @override
  String get loginScreenNameOptionalHint => 'nome (opcional)';

  @override
  String get loginScreenRecoveryPhraseHint =>
      'a tua frase de recuperação de 12 palavras';

  @override
  String get loginScreenNewPasswordHint => 'nova palavra-passe';

  @override
  String get loginScreenBackToSignIn => '← voltar a entrar';

  @override
  String get loginScreenForgotPassword => 'esqueceste-te da palavra-passe?';

  @override
  String get loginScreenSettingUpKidsPhone => 'configurar uma conta infantil';

  @override
  String get loginScreenLegalPrefix => 'Ao abrires uma conta, aceitas os ';

  @override
  String get loginScreenLegalTermsLink => 'Termos de Utilização';

  @override
  String get loginScreenLegalMiddle => ' e a ';

  @override
  String get loginScreenLegalPrivacyLink => 'Política de Privacidade';

  @override
  String get loginScreenLegalSuffix => '.';

  @override
  String get loginScreenAlreadyHerePrompt => 'já tens conta? ';

  @override
  String get loginScreenSignInLink => 'entra';

  @override
  String get loginScreenNoAccountPrompt => 'não tens conta? ';

  @override
  String get loginScreenOpenOneLink => 'abre uma';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12 palavras';
  }

  @override
  String get homeShellEmptyRoomHint =>
      'escolhe uma sala para começares a conversar';

  @override
  String get homeShellEmptySettingHint => 'escolhe uma definição';

  @override
  String get searchScreenHintPeople => 'Pesquisar pessoas';

  @override
  String get searchScreenHintRooms => 'Pesquisar salas públicas';

  @override
  String get searchScreenPeoplePromptChild =>
      'Escreve o nome de utilizador completo para encontrares alguém novo';

  @override
  String get searchScreenPeoplePromptDefault =>
      'pesquisa por nome de utilizador ou nome';

  @override
  String get searchScreenNoMatchChild =>
      'Ninguém encontrado. Para pessoas novas é preciso\no nome de utilizador completo, escrito exatamente';

  @override
  String get searchScreenNoMatchDefault => 'Ninguém encontrado';

  @override
  String get searchScreenNoRoomsYet => 'Ainda não há salas públicas';

  @override
  String get searchScreenNoRoomsMatch => 'Nenhuma sala pública corresponde';

  @override
  String get searchScreenActionAskToAdd => 'Pedir para adicionar';

  @override
  String get searchScreenActionSendRequest => 'Enviar pedido';

  @override
  String get searchScreenActionCancel => 'Cancelar';

  @override
  String get searchScreenActionApprove => 'Aprovar';

  @override
  String get searchScreenActionOpenDm => 'Abrir DM';

  @override
  String get searchScreenAskedLabel => 'pedido';

  @override
  String get profileVisibilityScreenTitle => 'preferências de visibilidade.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'controla o que os outros veem, e como podem contactar-te.';

  @override
  String get profileVisibilityScreenSectionProfile => 'PERFIL';

  @override
  String get profileVisibilityScreenAvatarLabel => 'AVATAR';

  @override
  String get profileVisibilityScreenAvatarDesc => 'a tua foto de perfil';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => 'ONLINE / AUSENTE';

  @override
  String get profileVisibilityScreenOnlineAwayDesc =>
      'se apareces ativo neste momento';

  @override
  String get profileVisibilityScreenLastSeenLabel => 'VISTO PELA ÚLTIMA VEZ';

  @override
  String get profileVisibilityScreenLastSeenDesc =>
      'quando estiveste por aqui pela última vez';

  @override
  String get profileVisibilityScreenSectionMessages => 'MENSAGENS';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel =>
      'ENVIAR CONFIRMAÇÕES DE LEITURA';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      'quando ativado, os outros podem ver que leste as mensagens deles';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel =>
      'MOSTRAR CONFIRMAÇÕES DE LEITURA';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      'vê a marca \"VISTA\" nas tuas próprias mensagens quando forem lidas';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      'só os leitores que ativaram ENVIAR CONFIRMAÇÕES DE LEITURA contribuem para isto. os outros continuam invisíveis.';

  @override
  String get profileVisibilityScreenSectionPeople => 'PESSOAS';

  @override
  String get profileVisibilityScreenFriendRequestsLabel => 'PEDIDOS DE AMIZADE';

  @override
  String get profileVisibilityScreenFriendRequestsDesc =>
      'quem te pode enviar pedidos de amizade';

  @override
  String get profileVisibilityScreenSupervisedTitle =>
      'OS TEUS CRESCIDOS DEFINEM ISTO';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      'Aqui podes ver o que todos os outros veem, mas só um crescido pode mudar isso. Eles conseguem sempre ver a tua fotografia, quando estás online e quando estiveste por aqui pela última vez.';

  @override
  String get profileVisibilityScreenOptionPublic => 'PÚBLICO';

  @override
  String get profileVisibilityScreenOptionFriends => 'AMIGOS';

  @override
  String get profileVisibilityScreenOptionNobody => 'NINGUÉM';

  @override
  String get profileVisibilityScreenOptionOn => 'ATIVADO';

  @override
  String get profileVisibilityScreenOptionOff => 'DESATIVADO';

  @override
  String get profileVisibilityScreenOptionAnyone => 'QUALQUER PESSOA';

  @override
  String get logoScreenTitle => 'logótipo da app.';

  @override
  String get logoScreenSubtitle =>
      'o símbolo na tua barra superior, a decisão é tua.';

  @override
  String get logoScreenAutoLabel => 'AUTOMÁTICO';

  @override
  String get logoScreenAutoDescription =>
      'segue o teu tema. o símbolo muda consoante a paleta.';

  @override
  String get logoScreenManualLabel => 'MANUAL';

  @override
  String get logoScreenManualDescription =>
      'escolhe qualquer símbolo, mantém o teu tema.';

  @override
  String get logoScreenAlwaysDefaultLabel => 'SEMPRE PREDEFINIDO';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      'o símbolo do MonkeyHub, seja qual for o tema.';

  @override
  String get logoScreenActiveBadge => 'ATIVO';

  @override
  String get logoScreenMonkeyCollectionHeader => 'COLEÇÃO DE MACACOS';

  @override
  String get logoScreenThemesHeader => 'TEMAS';

  @override
  String get recoveryPhraseScreenCopiedSnackbar =>
      'Copiada. Cola-a num sítio seguro';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'Confirma\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'que és tu.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'A tua palavra-passe, para que mais ninguém possa adicionar uma frase de recuperação à tua conta.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'Palavra-passe';

  @override
  String get recoveryPhraseScreenContinueButton => 'CONTINUAR';

  @override
  String get recoveryPhraseScreenNotNowLink => 'agora não';

  @override
  String get recoveryPhraseScreenEnterPasswordError =>
      'Introduz a tua palavra-passe.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'Guarda\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => 'estas palavras.';

  @override
  String get recoveryPhraseScreenWordsBody =>
      'Estas doze palavras são a única forma de voltares a entrar na tua conta se esqueceres a tua palavra-passe. Não podemos voltar a mostrar-tas, nem podemos recuperá-las por ti.';

  @override
  String get recoveryPhraseScreenCopyButton => 'COPIAR';

  @override
  String get recoveryPhraseScreenPaperHint =>
      'Se puderes, escreve-as em papel. Tudo o que estiver neste telemóvel pode perder-se com o telemóvel.';

  @override
  String get recoveryPhraseScreenSavedButton => 'GUARDEI-AS';

  @override
  String get recoveryPhraseScreenBackLink => '← voltar';

  @override
  String get recoveryPhraseScreenKeepPhraseLink =>
      'agora não, manter a minha frase atual';

  @override
  String get homeScreenProfileSemanticLabel => 'O teu perfil';

  @override
  String homeScreenGreeting(Object name) {
    return 'olá, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'Nova sala';

  @override
  String get homeScreenEmptyRoomsMessage => 'Ainda não tens salas. Cria uma';

  @override
  String get groupCallScreenTitleVideo => 'Chamada de vídeo em grupo';

  @override
  String get groupCallScreenTitleVoice => 'Chamada de voz em grupo';

  @override
  String groupCallScreenParticipantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count na chamada',
      one: 'Só tu',
    );
    return '$_temp0';
  }

  @override
  String get groupCallScreenReconnecting => 'A reconectar…';

  @override
  String get groupCallScreenUnmuteLabel => 'Ativar som';

  @override
  String get groupCallScreenMuteLabel => 'Silenciar';

  @override
  String get groupCallScreenCamOnLabel => 'Ligar câmara';

  @override
  String get groupCallScreenCamOffLabel => 'Desligar câmara';

  @override
  String get groupCallScreenFlipLabel => 'Virar';

  @override
  String get groupCallScreenSpeakerLabel => 'Altifalante';

  @override
  String get groupCallScreenLeaveLabel => 'Sair';

  @override
  String get groupCallScreenYouLabel => 'Tu';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return 'A filtrar por $summary. Alterar filtro';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => 'Filtrar conversas';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => 'Limpar filtro';

  @override
  String get roomFilterDrawerClearLabel => 'Limpar';

  @override
  String get roomFilterDrawerDimensionType => 'Tipo';

  @override
  String get roomFilterDrawerDimensionNature => 'Natureza';

  @override
  String get roomFilterDrawerDimensionStatus => 'Estado';

  @override
  String get roomFilterDrawerPanelClear => 'Limpar';

  @override
  String get roomFilterDrawerPanelDone => 'Concluído';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversas',
      one: '$count conversa',
    );
    return '$label, $_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return 'Nada corresponde a $summary';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar todas as $count conversas',
      one: 'Mostrar a $count conversa',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar todas as $count conversas',
      one: 'Mostrar a $count conversa',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'Nova sala';

  @override
  String get createRoomSheetTaglineSecret => 'Nada será guardado';

  @override
  String get createRoomSheetTaglineRegular => 'Um espaço que fica';

  @override
  String get createRoomSheetNameLabel => 'Nome';

  @override
  String get createRoomSheetNameHint => 'Dá-lhe um nome honesto';

  @override
  String get createRoomSheetDescriptionLabel => 'Descrição · opcional';

  @override
  String get createRoomSheetDescriptionHint => 'Uma linha sobre a sala';

  @override
  String get createRoomSheetVisibilityLabel => 'Visibilidade';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'Pública';

  @override
  String get createRoomSheetVisibilityPublicSub =>
      'Toda a gente a pode encontrar';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'Privada';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'Só com convite';

  @override
  String get createRoomSheetTypeLabel => 'Tipo';

  @override
  String get createRoomSheetTypeStandardTitle => 'Padrão';

  @override
  String get createRoomSheetTypeStandardSub => 'Mensagens persistem';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'Efémera';

  @override
  String get createRoomSheetTypeEphemeralSub => 'Autoapagam-se';

  @override
  String get createRoomSheetMessageLifeLabel => 'Vida da mensagem';

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
    return '${hours}h';
  }

  @override
  String get createRoomSheetPasswordLabel => 'Palavra-passe · opcional';

  @override
  String get createRoomSheetPasswordHint => 'Tranca-a com uma frase-passe';

  @override
  String get createRoomSheetNameRequiredError => 'O nome é obrigatório';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Abrir a sala';

  @override
  String get createRoomSheetOpenRoomButton => 'Abrir a sala';

  @override
  String get familyScreenTitle => 'FAMÍLIA';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coisas precisam do teu OK',
      one: '1 coisa precisa do teu OK',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => 'online agora';

  @override
  String get familyScreenPresenceNotPaired => 'ainda não emparelhado';

  @override
  String get familyScreenPresenceJustNow => 'agora mesmo';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return 'há ${minutes}min';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return 'há ${hours}h';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return 'há ${days}d';
  }

  @override
  String get familyScreenPairButton => 'EMPARELHAR';

  @override
  String get familyScreenReleaseButton => 'LIBERTAR';

  @override
  String get familyScreenSettingsButton => 'DEFINIÇÕES';

  @override
  String get familyScreenAddChildButton => 'ADICIONAR CRIANÇA';

  @override
  String get familyScreenEmptyStateTitle => 'ainda sem crianças';

  @override
  String get familyScreenEmptyStateBody =>
      'Cria uma conta para a tua criança e depois emparelha-a com o telemóvel dela.';

  @override
  String get reactionDetailsSheetTitle => 'Reações';

  @override
  String get reactionDetailsSheetEmptyState => 'Já não há nada aqui';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas',
      one: '1 pessoa',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => 'Todos';

  @override
  String get reactionDetailsSheetYouBadge => 'Tu';

  @override
  String get roomLayoutScreenTitle => 'lista de conversas.';

  @override
  String get roomLayoutScreenSubtitle =>
      'como as salas se dispõem, e como as filtras';

  @override
  String get roomLayoutScreenLayoutSectionLabel => 'DISPOSIÇÃO';

  @override
  String get roomLayoutScreenRowLayoutLabel => 'LISTA';

  @override
  String get roomLayoutScreenRowLayoutDescription =>
      'uma coluna, de ponta a ponta. fácil de ler num relance.';

  @override
  String get roomLayoutScreenGridLayoutLabel => 'GRELHA';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      'duas colunas, compacto. mais salas num relance.';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => 'CONTROLO DE FILTROS';

  @override
  String get roomLayoutScreenChipRowLabel => 'LINHA DE CHIPS';

  @override
  String get roomLayoutScreenChipRowDescription =>
      'sempre à vista. um toque para qualquer filtro, ocupa uma linha.';

  @override
  String get roomLayoutScreenDrawerButtonLabel => 'BOTÃO DE GAVETA';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      'um botão que abre. nada no caminho até pedires.';

  @override
  String get roomLayoutScreenQuietRoomSectionLabel => 'SALAS EM SILÊNCIO';

  @override
  String get roomLayoutScreenPlainCornerLabel => 'canto vazio';

  @override
  String get roomLayoutScreenPlainCornerDescription =>
      'uma sala sem mensagens fica nua';

  @override
  String get roomLayoutScreenMonogramLabel => 'a inicial da sala';

  @override
  String get roomLayoutScreenMonogramDescription =>
      'uma letra grande e esbatida preenche o canto';

  @override
  String get roomLayoutScreenActiveBadge => 'ATIVO';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel =>
      'Saltar para a mensagem fixada';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => 'Todas as mensagens fixadas';

  @override
  String get pinnedBannerTitleSingle => 'Mensagem fixada';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return 'Mensagem fixada  $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => 'estilo de conversa.';

  @override
  String get pinnedBannerChatStyleSubtitle => 'como é o aspeto da sala';

  @override
  String get pinnedBannerClassicLabel => 'CLÁSSICO';

  @override
  String get pinnedBannerClassicSubtitle =>
      'cabeçalho com linha divisória, campo de escrita simples.';

  @override
  String get pinnedBannerCompactLabel => 'COMPACTO';

  @override
  String get pinnedBannerCompactSubtitle =>
      'pílulas foscas a pairar sobre a conversa.';

  @override
  String get pinnedBannerActiveBadge => 'ATIVO';

  @override
  String get audioMessageMissingLabel => '[áudio em falta]';

  @override
  String get audioMessageUnavailableLabel => 'Áudio indisponível';

  @override
  String get audioMessageRetryHint => 'Toca para tentar novamente';

  @override
  String get audioMessageLoadingLabel => 'A carregar…';

  @override
  String get audioMessageUsernameRequiredError =>
      'Introduz o teu nome de utilizador.';

  @override
  String get audioMessagePasswordRequiredError =>
      'Introduz a tua palavra-passe.';

  @override
  String get audioMessageCancelSemanticLabel => 'Cancelar';

  @override
  String get audioMessageHeroCreateLine1 => 'quase\n';

  @override
  String get audioMessageHeroCreateLine2 => 'lá.';

  @override
  String get audioMessageHeroLinkLine1 => 'bem-vindo(a)\n';

  @override
  String get audioMessageHeroLinkLine2 => 'de volta.';

  @override
  String get audioMessageCreateSubtitle =>
      'Escolhe um nome de utilizador para que a tua família e os teus amigos te consigam encontrar.';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return 'Inicia sessão uma vez e o $provider fica associado à tua conta.';
  }

  @override
  String get audioMessageUsernameHint => 'Nome de utilizador';

  @override
  String get audioMessageDisplayNameHint => 'Nome a apresentar (opcional)';

  @override
  String get audioMessagePasswordHint => 'Palavra-passe';

  @override
  String get audioMessageSwitchToLinkPrompt => 'Esse é o meu: iniciar sessão';

  @override
  String get audioMessageCreateAccountButton => 'Criar conta';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return 'INICIAR SESSÃO E LIGAR $provider';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => 'Já tens conta?';

  @override
  String get audioMessageSwitchToCreateModeLink =>
      'Novo por aqui? Cria uma conta';

  @override
  String get approvalsScreenTitle => 'APROVAÇÕES';

  @override
  String get approvalsScreenEmptyTitle => 'nada à espera';

  @override
  String get approvalsScreenEmptySubtitle => 'estás em dia';

  @override
  String get approvalsScreenErrorNotGuardian => 'essa decisão não é tua';

  @override
  String get approvalsScreenErrorAlreadyHandled => 'já foi tratado noutro lado';

  @override
  String get approvalsScreenErrorGeneric =>
      'não foi possível guardar. Tenta novamente';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child quer adicionar $other';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other quer adicionar $child';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child quer juntar-se a $room';
  }

  @override
  String get approvalsScreenSomeoneLower => 'alguém';

  @override
  String get approvalsScreenSomeoneCapital => 'Alguém';

  @override
  String get approvalsScreenRoomFallback => 'uma sala';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      'Vai receber o pedido. Continua a poder decidir se aceita ou não.';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$child vai ver o pedido e pode aceitá-lo ou ignorá-lo.';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      'Vai poder ler e escrever lá até retirares essa permissão.';

  @override
  String get approvalsScreenNotYetButton => 'AINDA NÃO';

  @override
  String get approvalsScreenAllowButton => 'PERMITIR';

  @override
  String get approvalsScreenForwardDirectMessageFallback => 'Mensagem direta';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encaminhar $count mensagens',
      one: 'Encaminhar mensagem',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'Ainda sem outras conversas';

  @override
  String get approvalsScreenForwardNoMatches => 'Nada corresponde';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'Até $max conversas de cada vez';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'Procurar conversas';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Desmarcar $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Selecionar $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'Desvanece';

  @override
  String get approvalsScreenForwardSendSemantic => 'Enviar';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar para $count',
      zero: 'Enviar',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => 'CONTAS ASSOCIADAS';

  @override
  String get linkedAccountsScreenSubtitle =>
      'Contas que associaste a esta, para poderes iniciar sessão sem palavra-passe.';

  @override
  String get linkedAccountsScreenEmptyState =>
      'Não há nada para associar neste dispositivo.';

  @override
  String get linkedAccountsScreenStatusChecking => 'A verificar…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return 'Podes iniciar sessão com $provider em qualquer um dos teus dispositivos.';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return 'Associa $provider para não teres de escrever a palavra-passe.';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return 'DESASSOCIAR $provider';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => 'DESASSOCIAR';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return 'Introduz a tua palavra-passe para deixares de iniciar sessão com $provider.';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return 'ASSOCIAR $provider';
  }

  @override
  String get linkedAccountsScreenLinkAction => 'ASSOCIAR';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return 'Introduz a tua palavra-passe para adicionares $provider como forma de iniciar sessão.';
  }

  @override
  String get linkedAccountsScreenPillChecking => 'A VERIFICAR';

  @override
  String get linkedAccountsScreenPillLinked => 'ASSOCIADA';

  @override
  String get linkedAccountsScreenPillNotLinked => 'NÃO ASSOCIADA';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => 'Voz';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'Vídeo';

  @override
  String get linkedAccountsScreenCallSheetTitle => 'Iniciar uma chamada';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle => 'Ligar a todos';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      'Chama todos os membros desta sala';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle =>
      'Escolher pessoas';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle =>
      'Escolhe quem convidar';

  @override
  String get linkedAccountsScreenCallSheetCallFullError =>
      'Essa chamada está cheia (máx. 6 pessoas)';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError =>
      'Não foi possível iniciar a chamada';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle =>
      'Convidar para a chamada';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers =>
      'Não há mais membros aqui';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => 'Seleciona pessoas';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => 'Iniciar chamada';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return 'Iniciar chamada ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => 'olá';

  @override
  String get childPairScreenGreetingLine2 => 'tu.';

  @override
  String get childPairScreenIntro =>
      'Pede a um crescido para abrir o MonkeyHub e tocar em “emparelhar dispositivo”. Depois digitaliza o código dele, ou escreve os seis números que ele te disser.';

  @override
  String get childPairScreenOrDivider => 'ou';

  @override
  String get childPairScreenGenericError => 'Algo correu mal. Tenta outra vez.';

  @override
  String get profileScreenDeleteAccountFailed =>
      'Algo correu mal. Tenta outra vez.';

  @override
  String get childPairScreenAccountGoneError => 'Essa conta já não existe.';

  @override
  String get childPairScreenScanButtonLabel => 'DIGITALIZA O CÓDIGO DELE';

  @override
  String get childPairScreenNoCameraMessage =>
      'Sem câmara aqui. Escreve os seis números em vez disso.';

  @override
  String get childPairScreenStopScanning => 'Parar de digitalizar';

  @override
  String get childPairScreenSubmitButtonLabel => 'DEIXA-ME ENTRAR';

  @override
  String get childPairScreenBackToSignIn => '← voltar ao início de sessão';

  @override
  String get fileMessageUnavailable => 'o ficheiro já não está disponível';

  @override
  String get fileMessageOpenFailed => 'não foi possível abrir esse ficheiro';

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
  String get textFileViewerDownloadTooltip => 'Transferir';

  @override
  String get textFileViewerTruncatedNotice =>
      'A mostrar parte deste ficheiro. Transfira-o para ver o resto.';

  @override
  String get fileMessageUploadFailedLabel => 'falhou';

  @override
  String get fileMessageSendingLabel => 'a enviar…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · a enviar…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return 'há ${count}m';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return 'há ${count}h';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return 'há ${count}d';
  }

  @override
  String get fileMessageStandardBadge => 'Padrão';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens em rascunho · toca para ver',
      one: '$count mensagem em rascunho · toca para ver',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => 'Aprovar';

  @override
  String get fileMessageDeclineButton => 'Recusar';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'Enviado $ago';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens pendentes',
      one: '$count mensagem pendente',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => 'Cancelar pedido';

  @override
  String get destructiveSheetCannotBeUndone => 'isto não pode ser desfeito';

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
      'Não foi possível criar um código. Tenta outra vez.';

  @override
  String get destructiveSheetPairingReleaseTitle => 'LIBERTAR';

  @override
  String get destructiveSheetPairingPairTitle => 'EMPARELHAR';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return 'No telemóvel de $name, abre o perfil, toca em “devolver este telemóvel” e escreve estes números.';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return 'No telemóvel de $name, abre o MonkeyHub e digitaliza isto, ou escreve os números.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'Este código expirou';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'Expira em $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'Novo código';

  @override
  String get destructiveSheetPairingOneUseNote =>
      'Só pode ser usado uma vez. Criar um novo código cancela o anterior.';

  @override
  String get deepOceanThemeAttachButtonLabel => 'Anexar';

  @override
  String get deepOceanThemeCameraButtonLabel => 'Câmara';

  @override
  String get deepOceanThemeSendButtonLabel => 'Enviar';

  @override
  String get deepOceanThemeEphemeralHint => 'Sussurra algo';

  @override
  String get deepOceanThemeDefaultHint => 'Diz alguma coisa';

  @override
  String get deepOceanThemeMessageHint => 'Mensagem';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'Este ficheiro desapareceu';

  @override
  String get photoChromeMediaYouLabel => 'Tu';

  @override
  String get photoChromeCloseSemanticLabel => 'Fechar';

  @override
  String get photoChromeFillToggleSemanticLabel =>
      'Ajustar ou preencher o ecrã';

  @override
  String get photoChromeShowInChatSemanticLabel => 'Mostrar na conversa';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return 'Item $current de $total';
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
  String get photoDeckBackToFirst => 'Voltar à primeira';

  @override
  String get inlinePickerCommentHint => 'Adicione um comentário ou envie';

  @override
  String get attachmentMenuGalleryLabel => 'Galeria';

  @override
  String inlinePickerVideoCompressNote(String size) {
    return 'Tem mais de $size, por isso será comprimido para enviar';
  }

  @override
  String messageMenuAlbumAll(int count) {
    return 'Todos ($count)';
  }

  @override
  String get messageMenuAlbumOne => 'Só este';

  @override
  String replyAlbumItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => 'Descartar estas fotos';

  @override
  String get photoTrayRemoveSemanticLabel => 'Remover esta foto';

  @override
  String get photoTrayEditSemanticLabel => 'Recortar ou desenhar nesta foto';

  @override
  String get photoTrayAddMoreSemanticLabel => 'Adicionar mais fotos';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'Pode enviar $count fotos de cada vez';
  }

  @override
  String get photoTrayLoadFailedSnack =>
      'Algumas dessas fotos não puderam ser abertas';

  @override
  String get mediaPickFailedMessage =>
      'Não foi possível abrir. Tenta escolher outra vez';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name está a escrever';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1 e $name2 estão a escrever';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1, $name2 +$extra pessoas estão a escrever';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => 'Chamada a receber';

  @override
  String get typingIndicatorIncomingVideoCallLabel =>
      'Chamada de vídeo a receber';

  @override
  String get typingIndicatorIncomingVoiceCallLabel =>
      'Chamada de voz a receber';

  @override
  String get typingIndicatorDeclineButtonLabel => 'Recusar';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'A recusar…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'Aceitar';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'A ligar…';

  @override
  String get messageStampNavigationTitle => 'navegação.';

  @override
  String get messageStampNavigationSubtitle =>
      'como navegas entre chat, descobrir, feed, definições';

  @override
  String get messageStampRadialOrbLabel => 'ORBE RADIAL';

  @override
  String get messageStampRadialOrbDescription =>
      'mantém premido + arrasta a partir do canto. discreto em repouso, um gesto que vais dominando com o tempo.';

  @override
  String get messageStampBottomPillLabel => 'CÁPSULA INFERIOR';

  @override
  String get messageStampBottomPillDescription =>
      'toque clássico. sempre visível, sem curva de aprendizagem.';

  @override
  String get messageStampActiveLabel => 'ATIVO';

  @override
  String get messageStampUploadingLabel => 'a carregar';

  @override
  String get messageStampSendingLabel => 'a enviar';

  @override
  String get messageStampFailedToSendLabel => 'falha ao enviar';

  @override
  String get messageStampSentLabel => 'enviado';

  @override
  String get messageStampDeliveredLabel => 'entregue';

  @override
  String get messageStampSeenLabel => 'visto';

  @override
  String get messageStampSavedLabel => 'guardada';

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
      'Permissão do microfone negada';

  @override
  String get voiceRecorderScreenStatusRecording => 'A gravar';

  @override
  String get voiceRecorderScreenStatusReady => 'Pronto';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'Toca para começar';

  @override
  String get voiceRecorderScreenReRecordButton => 'Regravar';

  @override
  String get voiceRecorderScreenStopButton => 'Parar';

  @override
  String get voiceRecorderScreenSendButton => 'Enviar';

  @override
  String get voiceRecorderScreenRecordButton => 'Gravar';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => 'Toda a gente';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => 'NOTIFICA TODOS';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => 'DONO';

  @override
  String get releaseDeviceScreenFallbackChildName => 'essa pessoa';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return 'Isto termina a sessão de $name neste telemóvel e devolve-o. O telemóvel volta ao ecrã de início de sessão normal e qualquer pessoa pode usá-lo.';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'A conta, as mensagens e os amigos mantêm-se todos. Pode voltar a iniciar sessão a qualquer momento.';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return 'Pede a um crescido que abra o MonkeyHub, encontre $name em família e toque em “libertar”.';
  }

  @override
  String get releaseDeviceScreenOrDivider => 'ou';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      'Se só houver este telemóvel, um crescido pode iniciar sessão aqui em vez disso.';

  @override
  String get releaseDeviceScreenUsernameHint =>
      'nome de utilizador de um crescido';

  @override
  String get releaseDeviceScreenPasswordHint => 'a respetiva palavra-passe';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => 'Terminar sessão';

  @override
  String get releaseDeviceScreenChecking => 'A VERIFICAR…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return 'TERMINAR SESSÃO DE $name';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => 'DEVOLVE ESTE TELEMÓVEL';

  @override
  String get releaseDeviceScreenErrorCodeExpired =>
      'Esse código expirou. Pede um novo.';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      'Esse código não funcionou. Pode já ter sido usado.';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      'Isso não funcionou. Verifica o nome de utilizador e a palavra-passe.';

  @override
  String get releaseDeviceScreenErrorGeneric =>
      'Algo correu mal. Tenta novamente.';

  @override
  String get activeCallPillMoveHereSemanticLabel =>
      'Mover a chamada para este dispositivo';

  @override
  String activeCallPillCallWith(Object name) {
    return 'Chamada com $name';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return 'Em $device';
  }

  @override
  String get activeCallPillMoveHereLabel => 'Mover aqui';

  @override
  String get activeCallPillUnknownCaller => 'Desconhecido';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'Simulador de iOS';

  @override
  String get activeCallPillPlatformAndroid => 'Dispositivo Android';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'PC Windows';

  @override
  String get activeCallPillPlatformLinux => 'Dispositivo Linux';

  @override
  String get activeCallPillPlatformBrowser => 'Navegador';

  @override
  String get activeCallPillPlatformOther => 'outro dispositivo';

  @override
  String get activeCallPillPinnedHeader => 'Fixadas';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'Fixadas · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'Já não há nada fixado';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Ir para a mensagem de $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Desafixar mensagem de $name';
  }

  @override
  String get callButtonErrorBusy => 'Ocupado noutra chamada';

  @override
  String get callButtonErrorCallFailed => 'Não foi possível iniciar a chamada';

  @override
  String get callButtonErrorNotMember => 'Não és membro desta sala';

  @override
  String get callButtonErrorGeneric => 'Não foi possível iniciar a chamada';

  @override
  String get callButtonAlreadyOnCall => 'Já estás numa chamada';

  @override
  String get callButtonBusyElsewhere => 'Chamada em curso noutro dispositivo';

  @override
  String get callButtonVoiceCallTooltip => 'Chamada de voz';

  @override
  String get callButtonVideoCallTooltip => 'Videochamada';

  @override
  String get callButtonTooltip => 'chamada';

  @override
  String get callButtonReplyStyleTitle => 'estilo de resposta.';

  @override
  String get callButtonReplyStyleSubtitle =>
      'como uma resposta mostra a mensagem a que responde';

  @override
  String get callButtonReplyStylePhantomEchoLabel => 'ECO FANTASMA';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      'uma bolha-fantasma da mensagem original paira por cima, com um conector curvo e o ícone de ramificação no ponto de junção.';

  @override
  String get callButtonReplyStyleStickyNoteLabel => 'NOTA ADESIVA';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      'um cartão estilo polaroid ligeiramente rodado, preso ao canto da bolha.';

  @override
  String get callButtonReplyStyleComicTailLabel => 'CAUDA BD';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      'uma mini-bolha da mensagem original com uma cauda triangular estilo banda desenhada a apontar para baixo.';

  @override
  String get callButtonReplyStyleClassicLabel => 'CLÁSSICO';

  @override
  String get callButtonReplyStyleClassicDescription =>
      'pílula de citação com cor de destaque, barra de ligação e avatar: o visual clássico ao estilo WhatsApp.';

  @override
  String get callButtonReplyStyleActiveBadge => 'ATIVO';

  @override
  String get callButtonReplyPreviewSampleMessage =>
      'então, já viste a nova demo?';

  @override
  String get callButtonReplyPreviewSampleReply =>
      'sim, esse desfoque é brutal.';

  @override
  String get childSetupScreenErrorPickUsername =>
      'Escolhe-lhe um nome de utilizador.';

  @override
  String get childSetupScreenErrorUsernameTaken =>
      'Esse nome de utilizador já está em uso.';

  @override
  String get childSetupScreenErrorChildNotAllowed =>
      'Só uma conta de adulto pode adicionar uma criança.';

  @override
  String get childSetupScreenErrorGeneric =>
      'Não foi possível criar a conta. Tenta outra vez.';

  @override
  String get childSetupScreenTitle => 'ADICIONAR CRIANÇA';

  @override
  String get childSetupScreenHeading => 'quem\né?';

  @override
  String get childSetupScreenNameLabel => 'NOME';

  @override
  String get childSetupScreenNameHint => 'como lhe chamas';

  @override
  String get childSetupScreenUsernameLabel => 'NOME DE UTILIZADOR';

  @override
  String get childSetupScreenUsernameHint => 'como os amigos o encontram';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'O QUE RECEBEM';

  @override
  String get childSetupScreenBulletTalkImmediately =>
      'Já pode falar contigo e com os irmãos e as irmãs.';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      'Todos os outros precisam primeiro da tua aprovação, tanto quando é ele(a) a pedir alguém, como quando alguém pede por ele(a).';

  @override
  String get childSetupScreenBulletPublicRoomsOff =>
      'As salas públicas ficam desligadas até as ativares.';

  @override
  String get childSetupScreenBulletCantSignOut =>
      'Não pode terminar sessão, e podes sempre ver como está.';

  @override
  String get childSetupScreenCreateButton => 'CRIAR + EMPARELHAR';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return 'Enviar mensagem a $name';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => 'Pedido';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'MEMBROS';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'Ver tudo ($count)';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return 'Ver tudo ($count)';
  }

  @override
  String get bubbleStyleScreenTitle => 'estilo de bolha.';

  @override
  String get bubbleStyleScreenSubtitle =>
      'o formato em que as tuas palavras chegam';

  @override
  String get bubbleStyleScreenTailedLabel => 'COM CAUDA';

  @override
  String get bubbleStyleScreenTailedDescription =>
      'uma cauda fecha cada sequência de mensagens; as linhas acima dela juntam-se num só bloco.';

  @override
  String get bubbleStyleScreenSoftLabel => 'SUAVE';

  @override
  String get bubbleStyleScreenSoftDescription =>
      'sem ponta: uma sequência mantém-se coesa apenas pelos cantos interiores mais apertados.';

  @override
  String get bubbleStyleScreenPillLabel => 'CÁPSULA';

  @override
  String get bubbleStyleScreenPillDescription =>
      'cápsulas totalmente arredondadas, idênticas em cada linha.';

  @override
  String get bubbleStyleScreenSlabLabel => 'BLOCO';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'ombros quadrados: afiados, impressos, deliberados.';

  @override
  String get bubbleStyleScreenActiveBadge => 'ATIVO';

  @override
  String get bubbleStyleScreenPreviewQuestion => 'então? como é que fica';

  @override
  String get bubbleStyleScreenPreviewReplyOne => 'melhor';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => 'muito melhor';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => 'Vídeo';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => 'Foto';

  @override
  String get incomingGroupCallScreenCallFullError =>
      'Esta chamada está cheia (máximo de 6 pessoas)';

  @override
  String get incomingGroupCallScreenJoinFailedError =>
      'Não foi possível entrar na chamada';

  @override
  String get incomingGroupCallScreenDefaultRoomName => 'Chamada de grupo';

  @override
  String get incomingGroupCallScreenDefaultStarterName => 'Alguém';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starter iniciou uma videochamada';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starter iniciou uma chamada de voz';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '$count já na chamada';
  }

  @override
  String get incomingGroupCallScreenDismissButton => 'Recusar';

  @override
  String get incomingGroupCallScreenJoinButton => 'Entrar';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversas',
      one: '$count conversa',
    );
    return '$_temp0';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens',
      one: '$count mensagem',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      'Última mensagem agora mesmo';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'Última mensagem há ${hours}h';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'Última mensagem ontem';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'Última mensagem há $days dias';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'Última mensagem há algum tempo';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'Retirar';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return 'Afastar $contactName de $childName?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'Deixam de se conseguir contactar, e a conversa entre os dois desaparece com isso.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'Deixam de se conseguir contactar. $contactName não fica a saber.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats · $messages serão eliminadas';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      'Desaparece para os dois, incluindo fotos e notas de voz. Isto não pode ser desfeito.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Também partilham $count salas',
      one: 'Também partilham $count sala',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'Estas ficam. Retira a sala da lista de Salas abaixo se as quiseres fora dela.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'Retirar e apagar';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'Remove $contactName e apaga $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'Remove $contactName da lista de permitidos.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Cancelar';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton =>
      'Cancelar';

  @override
  String get groupCallBannerCallFullError =>
      'Essa chamada está cheia (máx. 6 pessoas)';

  @override
  String get groupCallBannerJoinFailedError =>
      'Não foi possível entrar na chamada';

  @override
  String get groupCallBannerUnknownParticipant => 'Alguém';

  @override
  String get groupCallBannerOngoingVideoCall => 'Chamada de vídeo em curso';

  @override
  String get groupCallBannerOngoingVoiceCall => 'Chamada de voz em curso';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra na chamada';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => 'Entrar na chamada';

  @override
  String get groupCallBannerJoinButtonLabel => 'Entrar';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'Entrar na sala';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '$count membro',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => 'Palavra-passe';

  @override
  String get groupCallBannerPasswordHint => 'Frase secreta';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Entrar';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'Entrar';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Cancelar';

  @override
  String get groupCallBannerCancelButtonLabel => 'Cancelar';

  @override
  String get viewOnceViewerBadgeLabel => 'Ver uma vez';

  @override
  String get socialButtonDividerOr => 'ou';

  @override
  String get socialButtonGoogleContinue => 'Continuar com o Google';

  @override
  String get discoverListsPeopleTitle => 'Amigos';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas',
      one: '$count pessoa',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => 'Pesquisar amigos';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Limpar filtro';

  @override
  String get discoverListsNoOneYet => 'Ainda ninguém';

  @override
  String discoverListsNoMatches(Object query) {
    return 'Ninguém corresponde a \"$query\"';
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
  String get discoverListsFilterRoomsHint => 'Pesquisar nas tuas salas';

  @override
  String get discoverListsNoRoomsYet => 'Ainda nenhuma sala';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return 'Nenhuma sala corresponde a \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'CHAMADA DE VOZ';

  @override
  String get discoverListsVideoCallLabel => 'CHAMADA DE VÍDEO';

  @override
  String get approvalGateAlreadyAskedLabel => 'Já pedido';

  @override
  String get approvalGateAskGrownUpLabel => 'Pergunta a um crescido';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return 'Já perguntaste sobre $what.';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return 'Precisas que um crescido diga que sim antes de poderes $what.';
  }

  @override
  String get approvalGateDisabledBody =>
      'Um crescido desligou isto, por agora.';

  @override
  String get approvalGateAlreadyAskedFooter =>
      'Vão receber uma mensagem sobre isso. Volta a verificar daqui a pouco.';

  @override
  String get approvalGateWillNotifyFooter =>
      'Vamos avisá-los. Vais ver aqui quando responderem.';

  @override
  String get approvalGateTalkToThemFooter =>
      'Podes falar com eles sobre isso se achares que devia mudar.';

  @override
  String get approvalGateAskButton => 'Perguntar';

  @override
  String get approvalGateNotNowButton => 'AGORA NÃO';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => 'À espera de um crescido';

  @override
  String get reportSheetTitle => 'DENÚNCIA';

  @override
  String get reportSheetSubtitle => 'diz-nos o que se passa.';

  @override
  String get reportSheetPrivacyNote =>
      'as denúncias são privadas. A outra pessoa não é notificada.';

  @override
  String get reportSheetReasonSpamLabel => 'SPAM';

  @override
  String get reportSheetReasonSpamDescription =>
      'publicidade indesejada ou mensagens repetidas';

  @override
  String get reportSheetReasonHarassmentLabel => 'ASSÉDIO';

  @override
  String get reportSheetReasonHarassmentDescription =>
      'perseguição ou bullying';

  @override
  String get reportSheetReasonImpersonationLabel => 'IMPOSTURA';

  @override
  String get reportSheetReasonImpersonationDescription =>
      'fingir ser outra pessoa';

  @override
  String get reportSheetReasonInappropriateLabel => 'INAPROPRIADO';

  @override
  String get reportSheetReasonInappropriateDescription =>
      'conteúdo sexual, violento ou ilegal';

  @override
  String get reportSheetReasonOtherLabel => 'OUTRO';

  @override
  String get reportSheetReasonOtherDescription => 'outra coisa';

  @override
  String get reportSheetOtherNoteHint => 'o que aconteceu?';

  @override
  String get reportSheetSubmitSemanticLabel => 'Enviar denúncia';

  @override
  String get reportSheetSubmitButton => 'ENVIAR';

  @override
  String get reportSheetUpdateRequiredTitle => 'Atualização obrigatória';

  @override
  String get reportSheetUpdateAvailableTitle => 'Atualização disponível';

  @override
  String get reportSheetUpdateMandatoryBody =>
      'Esta versão é demasiado antiga para continuar a funcionar bem. Atualiza para continuar.';

  @override
  String get reportSheetUpdateAvailableBody =>
      'Está disponível uma versão mais recente do MonkeyHub.';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => 'Atualizar';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'Abre o TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'Abre a App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'Abre a Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'Abre a página de transferência';

  @override
  String get reportSheetUpdateActionReloads => 'Recarrega com a nova versão';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Mais tarde';

  @override
  String get reportSheetUpdateLaterButton => 'Mais tarde';

  @override
  String get roomFilterBarAllChipLabel => 'Tudo';

  @override
  String roomFilterBarChipCountSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversas',
      one: '$count conversa',
    );
    return '$label, $_temp0';
  }

  @override
  String composerReplyCardReplyingToLabel(Object name) {
    return 'A responder a $name';
  }

  @override
  String get roomCardLockedBadge => 'Bloqueada';

  @override
  String get roomCardTimeAgoJustNow => 'agora mesmo';

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
    return 'Criada há $ago';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count dentro';
  }

  @override
  String get roomCardMessagesFadeLabel => 'Mensagens desaparecem';

  @override
  String get roomCardEnterLabel => '↗ Entrar';

  @override
  String get roomCardBlockedScreenTitle => 'BLOQUEADOS';

  @override
  String get roomCardBlockedEmptyState => 'ainda não bloqueaste ninguém.';

  @override
  String get roomCardUnblockButton => 'DESBLOQUEAR';

  @override
  String get attachmentMenuPhotoLabel => 'Foto';

  @override
  String get attachmentMenuVideoLabel => 'Vídeo';

  @override
  String get attachmentMenuCameraLabel => 'Câmara';

  @override
  String get attachmentMenuVoiceLabel => 'Voz';

  @override
  String get attachmentMenuFileLabel => 'Ficheiro';

  @override
  String get attachmentMenuConnectionRetrying => 'A tentar novamente…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'Não é possível contactar o servidor · Toca para tentar novamente';

  @override
  String get attachmentMenuConnectionReconnecting => 'A ligar novamente…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Tentar ligar novamente';

  @override
  String get roomGridTileEmptyLastMessage => 'sossegado por agora';

  @override
  String get roomGridTileMemberCountLabel => 'Dentro';

  @override
  String get roomGridTileThemeChipLabel => 'TEMA';

  @override
  String get bulkActionBarCancelLabel => 'Cancelar';

  @override
  String get bulkActionBarSelectMessagesLabel => 'Selecionar mensagens';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count selecionadas';
  }

  @override
  String get bulkActionBarForwardLabel => 'Reencaminhar';

  @override
  String get bulkActionBarDeleteLabel => 'Eliminar';

  @override
  String get bulkActionBarJumpBackLabel => 'VOLTAR';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return 'VOLTAR · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel => 'Voltar para onde saltaste';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return 'Voltar para onde saltaste, faltam $depth';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote => 'Não fica a saber.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'Vocês são amigos atualmente. Bloquear remove a amizade, por isso, para voltarem a falar mais tarde, terias de enviar um novo pedido de amizade.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'Desaparece das tuas pesquisas e não te pode enviar mensagens.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'Bloquear';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return 'Bloquear $name?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Partilhas $count salas com essa pessoa',
      one: 'Partilhas $count sala com essa pessoa',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'Estas salas não são afetadas. Podes sair de qualquer uma delas nas definições de cada sala.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'Bloquear';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'Remove a amizade e bloqueia. O histórico de conversa existente fica no teu arquivo.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'Desaparece da pesquisa e não te consegue contactar.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'Bloquear e eliminar DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'Também elimina a tua DM com essa pessoa: todas as mensagens, reações e ficheiros multimédia desaparecem.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Cancelar';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'Cancelar';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle =>
      'Mostrar chamadas no ecrã de bloqueio';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      'Para tocar como uma verdadeira chamada telefónica quando o ecrã está desligado, o MonkeyHub precisa que as \"notificações de ecrã inteiro\" estejam ativadas. O ecrã seguinte leva-te diretamente a essa opção.';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle =>
      'Nunca percas uma chamada';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      'Alguns telemóveis pausam aplicações em segundo plano para poupar bateria, o que pode silenciar chamadas recebidas. Permite que o MonkeyHub funcione sem restrições para que as chamadas cheguem sempre.';

  @override
  String get bulkActionBarDialogNotNowButton => 'Agora não';

  @override
  String get bulkActionBarDialogContinueButton => 'Continuar';

  @override
  String get reactionBubbleJumpToLatestLabel => 'IR PARA A MAIS RECENTE';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel =>
      'Ir para a mais recente';

  @override
  String get reactionBubblePickerTitle => 'Reagir';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'Ainda sem recentes';

  @override
  String get reactionBubbleSearchHint => 'Procurar emoji';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'Sem correspondências';

  @override
  String get reactionBubbleSearchBackSemanticLabel => 'Voltar aos emojis';

  @override
  String get reactionBubblePasswordHint => 'palavra-passe';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return 'entrar em $roomName';
  }

  @override
  String get enterPublicRoomAskFailedMessage =>
      'Não foi possível pedir agora. Tenta outra vez';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'palavra-passe errada';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'não foi possível entrar. Tenta novamente';

  @override
  String get feedBoardTitle => 'HOJE';

  @override
  String feedBoardEditionLabel(Object number) {
    return 'N.º$number';
  }

  @override
  String get feedBoardHighlightsLabel => 'Destaques';

  @override
  String get feedBoardHighlightsEmpty => 'Ainda não há nada capturado hoje';

  @override
  String get feedBoardPuzzleLabel => 'O ENIGMA';

  @override
  String get feedBoardPuzzleEmpty => 'o enigma de hoje ainda não está pronto';

  @override
  String get feedBoardStandingsLabel => 'Pontos de vida';

  @override
  String get feedBoardStandingsEmpty => 'Nenhum ponto no quadro hoje';

  @override
  String get feedBoardActivityLabel => 'Atividade';

  @override
  String get feedBoardActivityEmpty => 'hoje está calmo por enquanto';

  @override
  String get feedBoardActivityNoFriends =>
      'Adiciona um amigo e o dia dele aparece aqui';

  @override
  String get feedBoardLoadFailed =>
      'Não foi possível carregar o quadro. Tenta daqui a pouco';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'Pública';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'Privada';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'Já entraste';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'Efémera · $duration';
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
  String get roomBadgePublicTooltip =>
      'Qualquer pessoa pode encontrar esta sala e entrar';

  @override
  String get roomBadgePrivateTooltip =>
      'Apenas por convite, não aparece em Descobre';

  @override
  String get roomBadgeLockedTooltip =>
      'Precisas da palavra-passe da sala para entrar';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return 'As mensagens desaparecem depois de $duration';
  }

  @override
  String get roomBadgeJoinedTooltip => 'Já estás nesta sala';

  @override
  String get roomInfoSheetDetailsLabel => 'OS DETALHES';

  @override
  String get roomInfoSheetNoDescription => 'Ainda sem descrição';

  @override
  String get roomInfoSheetCreatedLabel => 'Criada em';

  @override
  String get countBadgeCaptureProtectionLabel => 'PROTEÇÃO DE CAPTURA DE ECRÃ';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      'as capturas de ecrã e a gravação de ecrã aparecem a preto para o sistema.';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      'a gravação de ecrã e o espelhamento cobrem a app com um escudo de privacidade.';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      'as capturas de ecrã e as gravações funcionam normalmente fora de salas efémeras.';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      'as salas efémeras (a câmara dos segredos) forçam sempre isto, aconteça o que acontecer.';

  @override
  String get countBadgeShowPasswordTooltip => 'mostrar palavra-passe';

  @override
  String get countBadgeHidePasswordTooltip => 'ocultar palavra-passe';

  @override
  String get countBadgeProtectedLabel => 'PROTEGIDO';

  @override
  String get countBadgeCaptureShieldActiveBody =>
      'a gravação de ecrã ou o espelhamento está ativo.';

  @override
  String get countBadgeCaptureShieldReassurance =>
      'a gravação não consegue ver as tuas conversas.';

  @override
  String get linkOpenerCouldNotOpenLink => 'Não foi possível abrir a ligação';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel =>
      'Configurar uma frase de recuperação';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'Sem frase de recuperação, podes não conseguir voltar a entrar.';

  @override
  String get destinationsChatLabel => 'Conversas';

  @override
  String get destinationsChatShort => 'CONVERSAS';

  @override
  String get destinationsDiscoverLabel => 'Descobrir';

  @override
  String get destinationsDiscoverShort => 'PROCURAR';

  @override
  String get destinationsFeedLabel => 'Feed';

  @override
  String get destinationsFeedShort => 'FEED';

  @override
  String get destinationsSettingsLabel => 'Definições';

  @override
  String get destinationsSettingsShort => 'DEF';

  @override
  String get familyRequestStageSenderGuardianLabel => 'à espera de um grande';

  @override
  String get familyRequestStageRecipientLabel => 'à espera de resposta';

  @override
  String get roomContentTabLabelMedia => 'Multimédia';

  @override
  String get roomContentTabLabelFiles => 'Ficheiros';

  @override
  String get roomContentTabLabelVoice => 'Voz';

  @override
  String get roomContentTabLabelLinks => 'Ligações';

  @override
  String get roomContentTabLabelSaved => 'Guardadas';

  @override
  String get roomContentTabHeaderMedia => 'Multimédia';

  @override
  String get roomContentTabHeaderFiles => 'Ficheiros';

  @override
  String get roomContentTabHeaderVoice => 'Voz';

  @override
  String get roomContentTabHeaderLinks => 'Ligações';

  @override
  String get roomContentTabHeaderSaved => 'Guardadas';

  @override
  String get roomFacetLabelDms => 'individual';

  @override
  String get roomFacetLabelGroups => 'grupos';

  @override
  String get roomFacetLabelPublic => 'público';

  @override
  String get roomFacetLabelPrivate => 'privado';

  @override
  String get roomFacetLabelSecret => 'secreto';

  @override
  String get roomFacetLabelLocked => 'trancado';

  @override
  String get roomFacetLabelUnread => 'não lidas';

  @override
  String get roomFacetLabelMentions => 'menções';

  @override
  String get settingsScreenTitle => 'DEFINIÇÕES';

  @override
  String get settingsScreenTagline => 'aparência. sensação. tu.';

  @override
  String get settingsScreenAccountHintChild =>
      'perfil · privacidade · os meus grandes';

  @override
  String get settingsScreenAccountHintAdult =>
      'perfil · família · contas associadas · privacidade';

  @override
  String get settingsScreenSectionAppearance => 'APARÊNCIA';

  @override
  String get settingsScreenSectionChat => 'CONVERSAS';

  @override
  String get settingsScreenSectionCompanions => 'COMPANHEIROS';

  @override
  String get settingsScreenSectionGeneral => 'GERAL';

  @override
  String get settingsScreenCheckForUpdatesLabel => 'VERIFICAR ATUALIZAÇÕES';

  @override
  String get settingsScreenUpdateAvailableValue => 'ATUALIZAÇÃO DISPONÍVEL';

  @override
  String get settingsScreenUpdateUpToDateSnackbar =>
      'Tens a versão mais recente.';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      'Não é possível verificar atualizações nesta versão.';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      'Não foi possível verificar atualizações. Tenta mais tarde.';

  @override
  String get settingsScreenSectionNotifications => 'NOTIFICAÇÕES';

  @override
  String get reportProblemRowLabel => 'Comunicar um problema';

  @override
  String get reportProblemRowValue => 'Envie-nos os detalhes';

  @override
  String get reportProblemIntro =>
      'Diga-nos o que correu mal. Os dados da app e do seu dispositivo são incluídos automaticamente, juntamente com um registo técnico do que a app estava a fazer. É isso que nos ajuda a encontrar a causa.';

  @override
  String get reportProblemDescribeLabel => 'O que aconteceu';

  @override
  String get reportProblemDescribeHint =>
      'O ecrã tremeluz, os botões não respondem';

  @override
  String get reportProblemScreenshotsLabel => 'Capturas de ecrã';

  @override
  String get reportProblemAddScreenshot => 'Adicionar captura de ecrã';

  @override
  String get reportProblemDetailsLabel => 'Os seus dados';

  @override
  String get reportProblemCopyDetails => 'Copiar dados';

  @override
  String get reportProblemCopied => 'Copiado';

  @override
  String get reportProblemSend => 'Enviar relatório';

  @override
  String get reportProblemSent => 'Relatório enviado. Obrigado!';

  @override
  String get reportProblemSendFailed =>
      'Não foi possível enviar o relatório. Verifique a sua ligação e tente novamente.';

  @override
  String get reportProblemTooMany =>
      'Enviou muitos relatórios em pouco tempo. Tente novamente mais tarde.';

  @override
  String get reportProblemShakeTitle => 'Comunicar um problema?';

  @override
  String get reportProblemShakeBody =>
      'Abanou o telemóvel. Abrir o ecrã de relatório?';

  @override
  String get reportProblemShakeOpen => 'Comunicar';

  @override
  String get reportProblemShakeDismiss => 'Agora não';

  @override
  String get settingsCallDeliveryLockScreenLabel =>
      'Chamadas no ecrã de bloqueio';

  @override
  String get settingsCallDeliveryBackgroundLabel =>
      'Atividade em segundo plano';

  @override
  String get settingsCallDeliveryStatusOff => 'Toque para permitir';

  @override
  String get settingsScreenRowTheme => 'TEMA';

  @override
  String get settingsScreenRowAppLogo => 'LOGÓTIPO DA APP';

  @override
  String get settingsScreenRowGlass => 'VIDRO';

  @override
  String get settingsScreenRowChatList => 'LISTA DE CONVERSAS';

  @override
  String get settingsScreenRowNavigation => 'NAVEGAÇÃO';

  @override
  String get settingsScreenRowChatStyle => 'ESTILO DE CONVERSA';

  @override
  String get settingsScreenRowBubbleStyle => 'ESTILO DE BALÃO';

  @override
  String get settingsScreenRowReplyStyle => 'ESTILO DE RESPOSTA';

  @override
  String get settingsScreenValueScrollList => 'Lista deslizante';

  @override
  String get settingsScreenValueGridSheet => 'Grelha';

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
  String get settingsScreenValueClassic => 'Clássico';

  @override
  String get settingsScreenValueCompact => 'Compacto';

  @override
  String get settingsScreenValueBubbleTailed => 'Caudado';

  @override
  String get settingsScreenValueBubbleSoft => 'Suave';

  @override
  String get settingsScreenValueBubblePill => 'Cápsula';

  @override
  String get settingsScreenValueBubbleSlab => 'Bloco';

  @override
  String get settingsScreenValueReplyPhantomEcho => 'Eco Fantasma';

  @override
  String get settingsScreenValueReplyStickyNote => 'Nota Adesiva';

  @override
  String get settingsScreenValueReplyComicTail => 'Cauda Cómica';

  @override
  String get settingsScreenValueLogoAuto => 'Automático';

  @override
  String get settingsScreenValueLogoManual => 'Manual';

  @override
  String get settingsScreenShowLinkUrlsLabel => 'MOSTRAR URLS DOS LINKS';

  @override
  String get settingsScreenLinksUrlsOnBody =>
      'os URLs completos aparecem junto ao cartão de pré-visualização';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      'apenas pré-visualização: balões mais limpos, toca para abrir';

  @override
  String get settingsScreenMenuBarLabel => 'ÍCONE NA BARRA DE MENUS';

  @override
  String get settingsScreenMenuBarOnBody =>
      'O MonkeyHub fica na barra de menus com a contagem de não lidas. Clica para abrir a janela';

  @override
  String get settingsScreenMenuBarOffBody =>
      'desativado neste momento: o ícone da Dock é a única forma de recuperar uma janela oculta';

  @override
  String get settingsScreenSectionCalls => 'CHAMADAS';

  @override
  String get settingsScreenRowVideoQuality => 'Qualidade de vídeo';

  @override
  String get settingsScreenValueVideoQualityAuto => 'Automático';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel =>
      'MOSTRAR ESTATÍSTICAS DA CHAMADA';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      'resolução, taxa de bits, ping e perda de pacotes em tempo real durante as chamadas';

  @override
  String get videoQualityScreenTitle => 'Qualidade de vídeo';

  @override
  String get videoQualityScreenSubtitle =>
      'Escolhe um limite de resolução para o vídeo de saída';

  @override
  String get videoQualityScreenAutoSubtitle =>
      'Adapta-se automaticamente à tua ligação';

  @override
  String get videoQualityScreenHd1080Subtitle =>
      'Full HD, mais nítido, usa mais dados';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD, melhor numa ligação forte';

  @override
  String get videoQualityScreenFootnote =>
      'A resolução real depende das câmaras de ambos os dispositivos e das condições da rede.';

  @override
  String get callScreenControlOptions => 'Mais';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => 'Variação (jitter)';

  @override
  String get callScreenStatsLossLabel => 'Perda';

  @override
  String get callScreenSwapPreviewSemanticLabel => 'Alternar vista da câmara';

  @override
  String get callOptionsSheetTitle => 'Opções de chamada';

  @override
  String get settingsScreenPushNotificationsLabel => 'NOTIFICAÇÕES PUSH';

  @override
  String get settingsScreenPushOnBody =>
      'avisa-te de novas mensagens e pedidos';

  @override
  String get settingsScreenPushOffBody =>
      'silencioso: só vês tudo quando abres a app';

  @override
  String get settingsScreenGameRemindersLabel => 'LEMBRETE DIÁRIO DOS JOGOS';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'um toque à hora de almoço, só se ainda não jogaste';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'sem lembrete, os jogos continuam lá quando fores ver';

  @override
  String get authErrorUsernameTaken =>
      'Esse nome de utilizador já está em uso.';

  @override
  String get authErrorUsernameReserved =>
      'Esse nome de utilizador não está disponível. Escolha outro.';

  @override
  String get authErrorDisplayNameReserved =>
      'Esse nome não está disponível. Escolha outro.';

  @override
  String get authErrorUserNotFound =>
      'Não existe nenhuma conta com esse nome de utilizador.';

  @override
  String get authErrorWrongPassword => 'Palavra-passe incorreta.';

  @override
  String get authErrorInvalidRecoveryKey =>
      'Esse nome de utilizador e essa frase de recuperação não coincidem.';

  @override
  String get authErrorTooManyAttempts =>
      'Demasiadas tentativas. Espera 15 minutos e tenta novamente.';

  @override
  String get authErrorChildMustPair =>
      'Essa é uma conta de criança. Pede a um crescido um código de emparelhamento.';

  @override
  String get authErrorPairingCodeExpired =>
      'Esse código expirou. Pede um novo.';

  @override
  String get authErrorPairingCodeInvalid =>
      'Esse código não funcionou. Pode já ter sido usado.';

  @override
  String get authErrorUseSocialSignIn =>
      'Essa conta inicia sessão com a Apple ou a Google. Usa os botões abaixo.';

  @override
  String get authErrorSocialTokenInvalid =>
      'Esse início de sessão não foi concluído. Tenta novamente, por favor.';

  @override
  String get authErrorSocialNonceMismatch =>
      'Esse início de sessão não foi concluído. Por favor, tenta novamente.';

  @override
  String get authErrorSocialMisconfig =>
      'O início de sessão ainda não está configurado do nosso lado. Tenta novamente mais tarde.';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      'Essa conta Apple ou Google já está associada a uma conta MonkeyHub diferente.';

  @override
  String get authErrorSocialAlreadyLinked =>
      'Isso já está associado a esta conta.';

  @override
  String get authErrorSocialNotLinked =>
      'Isso não está associado a esta conta.';

  @override
  String get authErrorSocialLastCredential =>
      'Essa é a única forma de aceder a esta conta. Define uma palavra-passe primeiro.';

  @override
  String get authErrorUsernameInvalid =>
      'Escolhe um nome de utilizador com 1 a 32 caracteres.';

  @override
  String get authErrorUsernameChangedRecently =>
      'Alteraste o teu nome de utilizador recentemente. Podes alterá-lo novamente 30 dias após a última alteração.';

  @override
  String get authErrorInboxHandleLocked =>
      'Esta conta recebe os relatórios de problemas de toda a gente, por isso o nome de utilizador é fixo.';

  @override
  String get glassKnobLabelFrost => 'Fosco';

  @override
  String get glassKnobHintFrost =>
      'Quanto branco fica sobre o vidro. Desce para ficar transparente';

  @override
  String get glassKnobLabelBlur => 'Desfoque';

  @override
  String get glassKnobHintBlur =>
      'Fosco no topo do intervalo, vidro transparente no fundo';

  @override
  String get glassKnobLabelSaturation => 'Sangria de cor';

  @override
  String get glassKnobHintSaturation =>
      'Quanta cor sobrevive ao desfoque. Depois de 2, começa a posterizar';

  @override
  String get glassKnobLabelRimOpacity => 'Orla';

  @override
  String get glassKnobHintRimOpacity =>
      'Brilho da borda do vidro. Zero para uma superfície sem borda';

  @override
  String get glassKnobLabelRimWidth => 'Largura da orla';

  @override
  String get glassKnobHintRimWidth => 'Espessura dessa orla';

  @override
  String get glassKnobLabelShadowOpacity => 'Sombra';

  @override
  String get glassKnobHintShadowOpacity =>
      'A que distância a superfície flutua acima do que está por trás';

  @override
  String get glassKnobLabelShadowBlur => 'Difusão da sombra';

  @override
  String get glassKnobHintShadowBlur => 'Suave e larga, ou apertada e dura';

  @override
  String get glassKnobLabelShadowY => 'Queda da sombra';

  @override
  String get glassKnobHintShadowY => 'A que distância abaixo da superfície cai';

  @override
  String get glassKnobLabelBarMargin => 'Margem lateral';

  @override
  String get glassKnobHintBarMargin => 'Espaço entre a barra e a borda do ecrã';

  @override
  String get glassKnobLabelBarBottom => 'Espaço inferior';

  @override
  String get glassKnobHintBarBottom =>
      'A que altura a barra flutua acima da base';

  @override
  String get glassKnobLabelShellPadH => 'Espaçamento das pontas';

  @override
  String get glassKnobHintShellPadH =>
      'Da borda da barra até à primeira cápsula. Mantém pequeno, ou as pontas ficam isoladas';

  @override
  String get glassKnobLabelShellPadV => 'Espaçamento superior';

  @override
  String get glassKnobHintShellPadV =>
      'Da borda da barra até ao topo da cápsula';

  @override
  String get glassKnobLabelIndicatorInset => 'Recuo da cápsula';

  @override
  String get glassKnobHintIndicatorInset =>
      'A que distância a cápsula de seleção fica dentro do seu compartimento';

  @override
  String get glassKnobLabelSegmentPadV => 'Espaçamento da linha';

  @override
  String get glassKnobHintSegmentPadV =>
      'Espaço acima e abaixo do ícone e da sua etiqueta';

  @override
  String get glassKnobLabelIconLabelGap => 'Espaço do ícone';

  @override
  String get glassKnobHintIconLabelGap =>
      'Espaço entre um ícone e a palavra por baixo dele';

  @override
  String get glassKnobLabelIconSize => 'Tamanho do ícone';

  @override
  String get glassKnobLabelLabelSize => 'Tamanho da etiqueta';

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
  String get settingsScreenRowMotion => 'MOVIMENTO';

  @override
  String get settingsScreenValueMotionFull => 'Completo';

  @override
  String get settingsScreenValueMotionCalm => 'Calmo';

  @override
  String get settingsScreenValueMotionSystemFull =>
      'Igual ao dispositivo · Completo';

  @override
  String get settingsScreenValueMotionSystemCalm =>
      'Igual ao dispositivo · Calmo';

  @override
  String get motionScreenTitle => 'movimento.';

  @override
  String get motionScreenSubtitle => 'quanto a app se mexe';

  @override
  String get motionScreenSystemLabel => 'IGUAL AO DISPOSITIVO';

  @override
  String get motionScreenSystemSubtitleFull =>
      'o teu dispositivo permite animação neste momento';

  @override
  String get motionScreenSystemSubtitleCalm =>
      'o teu dispositivo pede menos movimento neste momento';

  @override
  String get motionScreenFullLabel => 'COMPLETO';

  @override
  String get motionScreenFullSubtitle => 'cada deriva, brilho e floreado';

  @override
  String get motionScreenCalmLabel => 'CALMO';

  @override
  String get motionScreenCalmSubtitle => 'a decoração para, mais nada muda';

  @override
  String get momentRailCaptureLabel => 'Capturar';

  @override
  String get momentRailYouLabel => 'Tu';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String momentRailPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destaques',
      one: '1 destaque',
    );
    return '$_temp0';
  }

  @override
  String momentRailPersonNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novos',
      one: '1 novo',
    );
    return '$_temp0';
  }

  @override
  String get momentRailAddHighlight => 'Adicionar um destaque';

  @override
  String get momentTagFate => 'Destino';

  @override
  String get momentTagJinx => 'Azar';

  @override
  String get momentTagLuck => 'Sorte';

  @override
  String get momentTagCalledIt => 'Eu avisei';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'Que coincidência';

  @override
  String get momentTagJinxHint => 'Foste tu que provocaste';

  @override
  String get momentTagLuckHint => 'Correu a teu favor';

  @override
  String get momentTagCalledItHint => 'Viste isso a chegar';

  @override
  String get momentTagNpcHint => 'Cérebro desligado';

  @override
  String get momentComposerTitle => 'Novo momento';

  @override
  String get momentComposerCaptionHint => 'Diz alguma coisa';

  @override
  String get momentComposerTagPrompt => 'ganhaste um ponto? adiciona já';

  @override
  String get momentComposerCapture => 'Câmara';

  @override
  String get momentComposerLibrary => 'Galeria';

  @override
  String get momentComposerRemovePhoto => 'Remover foto';

  @override
  String get momentComposerPost => 'Publicar';

  @override
  String get momentComposerErrorDailyCap =>
      'Já vão cinco hoje. Guarda para amanhã';

  @override
  String get momentComposerErrorNotAllowed =>
      'Um responsável desativou a partilha de fotos';

  @override
  String get momentComposerErrorTooLong => 'Ficou um pouco longo. Encurta';

  @override
  String get momentComposerErrorEmpty => 'Adiciona uma foto ou umas palavras';

  @override
  String get momentComposerErrorGeneric =>
      'Não foi possível publicar. Tenta de novo';

  @override
  String get momentViewerDelete => 'Eliminar';

  @override
  String get momentViewerDeleteConfirmHeadline => 'Eliminar isto?';

  @override
  String get momentViewerDeleteConfirmBody =>
      'Sai do painel de toda a gente e do teu arquivo, para sempre';

  @override
  String get momentViewerDeleteFailed =>
      'Não foi possível eliminar. Tenta de novo';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who publicou um momento';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name marcou um ponto: $tag';
  }

  @override
  String get momentActivityJustNow => 'agora';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '${count}min';
  }

  @override
  String momentActivityHoursAgo(Object count) {
    return '${count}h';
  }

  @override
  String get puzzleScreenTitle => 'o enigma.';

  @override
  String get puzzleScreenSubtitle => 'Quatro símbolos, seis tentativas';

  @override
  String get puzzleSubmit => 'Adivinhar';

  @override
  String get puzzleBackspace => 'Apagar último símbolo';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'Símbolo $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'Resolvido em $count';
  }

  @override
  String get puzzleFailedTitle => 'Sem tentativas';

  @override
  String get puzzleAnswerWas => 'O código era';

  @override
  String get puzzleShare => 'Copiar resultado';

  @override
  String get puzzleShareCopied => 'Copiado. Envia a um amigo';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'Já resolveste o de hoje';

  @override
  String get puzzleErrorOutOfGuesses => 'Não tens tentativas hoje';

  @override
  String get puzzleErrorGeneric => 'Não foi possível enviar. Tenta de novo';

  @override
  String get puzzleGuessWaiting =>
      'Sem ligação. O teu palpite está guardado e segue quando voltares';

  @override
  String get gameSubmitWaiting =>
      'Sem ligação. O teu tabuleiro feito está guardado e segue quando voltares';

  @override
  String get puzzleScoreboardLabel => 'Pontuações de hoje';

  @override
  String get puzzleScoreboardEmpty => 'Ainda ninguém terminou hoje';

  @override
  String get puzzleTilePlay => 'joga o enigma de hoje';

  @override
  String puzzleTileInProgress(Object count) {
    return 'faltam $count';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '#$rank de $total';
  }

  @override
  String get profileVisibilityScreenSectionFeed => 'FEED';

  @override
  String get profileVisibilityScreenFeedLabel => 'os meus destaques';

  @override
  String get profileVisibilityScreenFeedDesc =>
      'se as fotos e vídeos que publicas aparecem nos quadros dos teus amigos nesse dia';

  @override
  String get profileVisibilityScreenPuzzleLabel =>
      'a minha pontuação do enigma';

  @override
  String get profileVisibilityScreenPuzzleDesc =>
      'se os teus amigos veem como te saíste no enigma diário';

  @override
  String get profileVisibilityScreenPointsPastLabel => 'o meu passado';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      'hoje é sempre partilhado com os amigos. Isto abre tudo o que veio antes';

  @override
  String get momentComposerVideo => 'Vídeo';

  @override
  String get momentComposerErrorTooBig =>
      'Esse vídeo é muito grande (máximo 20 MB)';

  @override
  String get momentActivityPostedHighlightSelf => 'Publicaste um momento';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'Marcaste um ponto: $tag';
  }

  @override
  String momentActivityGameSolved(String game, String name) {
    return '$name resolveu $game';
  }

  @override
  String momentActivityGameSolvedSelf(String game) {
    return 'Resolveste $game';
  }

  @override
  String momentActivityGameMissed(String game, String name) {
    return '$name não resolveu $game';
  }

  @override
  String momentActivityGameMissedSelf(String game) {
    return 'Não resolveste $game';
  }

  @override
  String momentActivityCodeSolved(String name) {
    return '$name decifrou o código';
  }

  @override
  String get momentActivityCodeSolvedSelf => 'Decifraste o código';

  @override
  String momentActivityCodeMissed(String name) {
    return '$name não decifrou o código';
  }

  @override
  String get momentActivityCodeMissedSelf => 'Não decifraste o código';

  @override
  String pointLineSelf(Object tag) {
    return 'Tu · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'O que aconteceu?';

  @override
  String get pointComposerNoteHint => 'Escolhe uma acima e conta';

  @override
  String get pointComposerAdd => 'Adicionar um ponto';

  @override
  String get pointComposerAddPhoto => 'adicionar foto';

  @override
  String get pointsBoardAdd => 'Adicionar um ponto';

  @override
  String get pointsExplainerOpen => 'O que é isto?';

  @override
  String get pointsExplainerTitle => 'O jogo dos pontos';

  @override
  String get pointsExplainerIntro =>
      'Uma piada recorrente com marcador. Quando te acontece algo (bom, mau ou só estranho), registas e fica no quadro nesse dia.';

  @override
  String get pointsExplainerRuleHonour =>
      'Os pontos dás-te a ti próprio. Ninguém verifica, é essa a graça, e os teus amigos dizem-te se estiveres a exagerar.';

  @override
  String get pointsExplainerRuleToday =>
      'Os pontos reiniciam todos os dias. O quadro mostra hoje; o teu histórico é teu.';

  @override
  String get pointsExplainerRuleCap =>
      'Cinco de cada tipo por dia, para ninguém transformar o quadro num disparate.';

  @override
  String get pointsExplainerGotIt => 'Percebi';

  @override
  String get momentTagFateExample => 'Encontrei o meu dentista noutro país';

  @override
  String get momentTagJinxExample => 'Lavei o carro e choveu às quatro';

  @override
  String get momentTagLuckExample => 'Apanhei o comboio por dois segundos';

  @override
  String get momentTagCalledItExample =>
      'Disse que a sequela ia falhar, e falhou';

  @override
  String get momentTagNpcExample => 'Disse ‘igualmente’ ao empregado';

  @override
  String feedBoardEditionHint(Object number) {
    return 'Dia $number do feed';
  }

  @override
  String get feedBoardHighlightsHint => 'fotos e vídeos que valem uma olhada';

  @override
  String get profileVisibilityScreenPointsLabel => 'os meus pontos';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'se os pontos que registas aparecem nos quadros dos teus amigos';

  @override
  String get momentComposerEditPhoto => 'Editar recorte';

  @override
  String get archiveScreenTitle => 'O teu arquivo';

  @override
  String get archiveScreenEnd => 'É tudo';

  @override
  String get archiveScreenEmptyTitle => 'Ainda não guardaste nada';

  @override
  String get archiveScreenEmptyBody =>
      'Os momentos saem dos quadros dos teus amigos ao fim de um dia, mas ficam aqui para ti.';

  @override
  String get archiveScreenEmptyFriendTitle => 'Não há nada aqui';

  @override
  String get archiveScreenEmptyFriendBody =>
      'Ainda não publicou nada que possas ver.';

  @override
  String get archiveScreenPrivateTitle => 'O passado é privado';

  @override
  String get archiveScreenPrivateBody =>
      'Podes na mesma ver o que publicar hoje.';

  @override
  String get archiveScreenNotFriendTitle => 'Não são amigos';

  @override
  String get archiveScreenNotFriendBody =>
      'Só podes recuar nos dias de um amigo.';

  @override
  String get archiveScreenErrorTitle => 'Não foi possível carregar';

  @override
  String get archiveScreenErrorBody => 'Verifica a ligação e tenta de novo.';

  @override
  String get feedBoardOpenArchive => 'Arquivo';

  @override
  String get feedBoardGamesLabel => 'Jogos';

  @override
  String get feedBoardGamesOpen => 'Classificação';

  @override
  String get gamesScreenTitle => 'os jogos.';

  @override
  String get gamesScreenSubtitle =>
      'quatro tabuleiros por dia, os mesmos para todos';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'faltam $count hoje',
      one: 'falta um hoje',
      zero: 'tudo feito hoje',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => 'Não foi possível carregar os jogos de hoje';

  @override
  String get gamesRetry => 'Tentar de novo';

  @override
  String get gameQueensName => 'Rainhas';

  @override
  String get gameQueensRule =>
      'Uma coroa por linha, coluna e cor, sem se tocarem';

  @override
  String get gameTangoName => 'Tango';

  @override
  String get gameTangoRule => 'três sóis, três luas, nunca três seguidos';

  @override
  String get gameZipName => 'Zip';

  @override
  String get gameZipRule =>
      'uma linha por todos os quadrados, números por ordem';

  @override
  String get gameSudokuName => 'Mini sudoku';

  @override
  String get gameSudokuRule => 'de 1 a 6 uma vez por linha, coluna e bloco';

  @override
  String get gameCodeName => 'O código';

  @override
  String get gameStatusUnplayed => 'Por jogar';

  @override
  String get gameStatusUnfinished => 'A decorrer';

  @override
  String get gameStatusGaveUp => 'Desistiu';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'Pausa';

  @override
  String get gameResume => 'Continuar';

  @override
  String get gamePausedTitle => 'Em pausa';

  @override
  String get gamePausedBody => 'O relógio está parado e o tabuleiro escondido';

  @override
  String get gameUndo => 'Desfazer';

  @override
  String get gameClear => 'limpar';

  @override
  String get gameHint => 'Dica';

  @override
  String get gameNotes => 'notas';

  @override
  String get gameErase => 'apagar';

  @override
  String get gameAutoCross => 'Cruzes automáticas';

  @override
  String get gameGiveUp => 'Desistir';

  @override
  String get gameGiveUpTitle => 'Mostrar a solução?';

  @override
  String get gameGiveUpBody =>
      'O tabuleiro de hoje fecha e fica como não resolvido.';

  @override
  String get gameGiveUpCancel => 'Continuar';

  @override
  String get gameGiveUpConfirm => 'Mostrar';

  @override
  String gameSolvedTitle(Object time) {
    return 'Resolvido em $time';
  }

  @override
  String get gameGaveUpTitle => 'A solução de hoje';

  @override
  String get gameFirstInToday => 'O primeiro de hoje';

  @override
  String gameRankLine(Object place, Object total) {
    return '$place de $total até agora';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erros',
      one: '1 erro',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dicas',
      one: '1 dica',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => 'Tempos de hoje';

  @override
  String get gameStandingsEmpty => 'Ainda ninguém terminou este';

  @override
  String get gameShare => 'Copiar resultado';

  @override
  String get gameShareCopied => 'Copiado. Cola para um amigo';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number · $time';
  }

  @override
  String get gameBackToHub => 'Todos os jogos';

  @override
  String get gameElapsedSemantic => 'Tempo decorrido';

  @override
  String get gameErrorNotSolved => 'Esse tabuleiro ainda não está terminado';

  @override
  String get gameErrorAlreadyFinished => 'Já terminaste o de hoje';

  @override
  String get gameErrorNoHint => 'Este não tem dicas';

  @override
  String get gameHintWrong => 'Esta estava errada, por isso foi apagada.';

  @override
  String get gameHintWrongMore =>
      'Há mais para corrigir. Pede outra vez quando estiveres pronto.';

  @override
  String get gameHintWrongLast => 'Tudo o resto que puseste está certo.';

  @override
  String get gameHintReveal =>
      'Ainda nenhuma regra decide uma casa sozinha, por isso aqui tens uma.';

  @override
  String get gameHintQueensRegion =>
      'Só resta um lugar para uma coroa nesta cor.';

  @override
  String get gameHintQueensRow =>
      'Só resta um lugar para uma coroa nesta linha.';

  @override
  String get gameHintQueensCol =>
      'Só resta um lugar para uma coroa nesta coluna.';

  @override
  String get gameHintQueensRegionInRow =>
      'Esta cor só cabe nesta linha, por isso o resto da linha não pode ter coroa.';

  @override
  String get gameHintQueensRegionInCol =>
      'Esta cor só cabe nesta coluna, por isso o resto da coluna não pode ter coroa.';

  @override
  String get gameHintQueensRowInRegion =>
      'Esta linha só tem espaço numa cor, por isso o resto dessa cor não pode ter coroa.';

  @override
  String get gameHintQueensColInRegion =>
      'Esta coluna só tem espaço numa cor, por isso o resto dessa cor não pode ter coroa.';

  @override
  String get gameHintStarsRegion =>
      'Esta cor só tem espaço para as estrelas que ainda lhe faltam.';

  @override
  String get gameHintStarsRow =>
      'Esta linha só tem espaço para as estrelas que ainda lhe faltam.';

  @override
  String get gameHintStarsCol =>
      'Esta coluna só tem espaço para as estrelas que ainda lhe faltam.';

  @override
  String get gameHintTangoEqual =>
      'Um sinal = quer dizer que as duas casas são iguais.';

  @override
  String get gameHintTangoCross =>
      'Um sinal × quer dizer que as duas casas são opostas.';

  @override
  String get gameHintTangoPair =>
      'Duas lado a lado já são iguais, por isso a seguinte tem de ser a outra.';

  @override
  String get gameHintTangoSandwich =>
      'As casas de cada lado são iguais, por isso a do meio tem de ser a outra.';

  @override
  String get gameHintTangoRowSuns => 'Esta linha já tem os seus três sóis.';

  @override
  String get gameHintTangoRowMoons => 'Esta linha já tem as suas três luas.';

  @override
  String get gameHintTangoColSuns => 'Esta coluna já tem os seus três sóis.';

  @override
  String get gameHintTangoColMoons => 'Esta coluna já tem as suas três luas.';

  @override
  String gameHintLatinBox(int digit) {
    return 'Este é o único lugar para um $digit neste bloco.';
  }

  @override
  String gameHintLatinRow(int digit) {
    return 'Este é o único lugar para um $digit nesta linha.';
  }

  @override
  String gameHintLatinCol(int digit) {
    return 'Este é o único lugar para um $digit nesta coluna.';
  }

  @override
  String get gameHintLatinOnly =>
      'Só cabe aqui um número. Os outros já estão na sua linha, coluna ou bloco.';

  @override
  String get gameHintLatinOnlyLines =>
      'Só cabe aqui um número. Os outros já estão na sua linha ou coluna.';

  @override
  String get gameHintLatinOnlySigns =>
      'Só cabe aqui um número, contando a linha, a coluna e os sinais.';

  @override
  String get gameHintNonogramRowFill =>
      'Seja qual for a forma como a pista desta linha encaixa, cobre esta casa.';

  @override
  String get gameHintNonogramRowCross =>
      'Nenhuma forma de encaixar a pista desta linha chega a esta casa.';

  @override
  String get gameHintNonogramColFill =>
      'Seja qual for a forma como a pista desta coluna encaixa, cobre esta casa.';

  @override
  String get gameHintNonogramColCross =>
      'Nenhuma forma de encaixar a pista desta coluna chega a esta casa.';

  @override
  String get gameHintMinesStart => 'Começa aqui. Esta casa é sempre segura.';

  @override
  String get gameHintMinesSafe =>
      'Este número já tem todas as minas com bandeira, por isso as outras casas à volta são seguras.';

  @override
  String get gameHintMinesFlag =>
      'Este número precisa que todas as casas escondidas à volta dele sejam minas.';

  @override
  String get gameHintMinesProofSafe =>
      'Os números à volta desta casa provam que é segura.';

  @override
  String get gameHintMinesProofMine =>
      'Os números à volta desta casa provam que é uma mina.';

  @override
  String get gameHintFlowPipe => 'Aqui tens um tubo inteiro, de ponto a ponto.';

  @override
  String get gameHintPatchesOnly => 'Só cabe um retalho nesta pista.';

  @override
  String get gameHintPatchesCell =>
      'Uma casa aqui só pode pertencer a esta pista, e isso deixa-lhe um único retalho.';

  @override
  String get gameHintPatchesSqueeze =>
      'Os retalhos à volta só deixam uma forma de encaixar esta pista.';

  @override
  String get gameErrorGeneric =>
      'Não foi possível chegar aos jogos. Tenta de novo';

  @override
  String get gameInfoOpen => 'Como se joga';

  @override
  String get gameInfoScoringTimed =>
      'Ganha quem acaba mais depressa. O relógio para quando sais. Mesmo tempo, mesma posição.';

  @override
  String get gameInfoScoringGuesses =>
      'Ganha quem o descobrir com menos tentativas. O tempo não conta. Mesmas tentativas, mesma posição.';

  @override
  String get gameInfoSameForEveryone => 'Hoje, todos têm o mesmo puzzle.';

  @override
  String get savedMessagesTitle => 'Mensagens guardadas';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'nenhuma conversa corresponde a \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'Pesquisar conversas';

  @override
  String get pullRevealCollapseSemanticLabel =>
      'Ocultar pesquisa e conversas arquivadas';

  @override
  String archivedChatsFolderLabel(Object count) {
    return 'conversas arquivadas ($count)';
  }

  @override
  String get archivedChatsFolderTitle => 'conversas arquivadas';

  @override
  String get pullRevealClearSearchSemanticLabel => 'Limpar pesquisa';

  @override
  String get archivedChatsSheetTitle => 'Conversas arquivadas';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'Conversas arquivadas · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'Já não há nada arquivado';

  @override
  String get pinnedBadgeLabel => 'FIXADA';

  @override
  String get chatRowActionMenuPinLabel => 'Fixar conversa';

  @override
  String get chatRowActionMenuUnpinLabel => 'Desafixar conversa';

  @override
  String get chatRowActionMenuArchiveLabel => 'Arquivar conversa';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'Desarquivar conversa';

  @override
  String get messageActionMenuSaveLabel => 'Guardar';

  @override
  String get messageActionMenuUnsaveLabel => 'Remover';

  @override
  String get roomScreenSaveLimitSnack =>
      'Demasiadas mensagens guardadas aqui. Remove uma primeiro';

  @override
  String get roomScreenSaveFailedSnack =>
      'Não foi possível guardar essa mensagem';

  @override
  String get threadOverlaySaveLimitToast =>
      'Demasiadas mensagens guardadas aqui. Remove uma primeiro';

  @override
  String get threadOverlaySaveFailedToast =>
      'Não foi possível guardar essa mensagem';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'só tu vês as mensagens que guardas. Uma mensagem fixada é o oposto: toda a sala a vê.';

  @override
  String get roomInfoScreenOwnerBadgeNote =>
      'a pequena medalha ao lado de um nome indica quem criou esta sala.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return 'Ir para a mensagem guardada de $name';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return 'Remover dos guardados a mensagem de $name';
  }

  @override
  String get muteSheetTitle => 'Silenciar conversa';

  @override
  String get muteSheetSubtitle =>
      'Escolhe o que fica em silêncio e durante quanto tempo.';

  @override
  String get muteSheetNotificationsTitle => 'Notificações';

  @override
  String get muteSheetNotificationsSub => 'Sem aviso, sem som';

  @override
  String get muteSheetBadgesTitle => 'Contagem de não lidas';

  @override
  String get muteSheetBadgesSub =>
      'Sem número na conversa, nada no ícone da app';

  @override
  String get muteSheetDurationLabel => 'Durante quanto tempo';

  @override
  String get muteDurationHour => '1 hora';

  @override
  String get muteDurationEightHours => '8 horas';

  @override
  String get muteDurationWeek => '1 semana';

  @override
  String get muteDurationAlways => 'Sempre';

  @override
  String get muteSheetConfirmButton => 'Silenciar';

  @override
  String get muteSheetSaveButton => 'Guardar';

  @override
  String get muteSheetUnmuteButton => 'Reativar';

  @override
  String get muteSummaryAll =>
      'Nada desta conversa chega até ti: nem notificações, nem contagem de não lidas.';

  @override
  String get muteSummaryNotificationsOnly =>
      'Sem notificações. A contagem de não lidas continua a subir.';

  @override
  String get muteSummaryBadgesOnly =>
      'Sem contagem de não lidas. As notificações continuam a chegar.';

  @override
  String get muteSummaryNothingPicked =>
      'Escolhe pelo menos uma coisa para silenciar.';

  @override
  String muteUntilSentence(String when) {
    return 'Até $when.';
  }

  @override
  String get muteUntilAlwaysSentence => 'Até voltares a ligar.';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String get mutedBadgeLabel => 'SILENCIADA';

  @override
  String get chatRowActionMenuMuteLabel => 'Silenciar conversa';

  @override
  String get chatRowActionMenuUnmuteLabel => 'Reativar conversa';

  @override
  String get roomInfoScreenMuteLabel => 'SILÊNCIO';

  @override
  String get roomInfoScreenNotMutedRow => 'Não silenciada';

  @override
  String get attachmentMenuLocationLabel => 'Localização';

  @override
  String get locationSheetSendCurrent => 'Enviar localização atual';

  @override
  String get locationSheetSendCurrentDetail => 'Onde estás agora';

  @override
  String get locationSheetLiveHeading => 'Partilhar em direto';

  @override
  String get locationSheetLiveDetail => 'Termina sozinho';

  @override
  String get locationShareFor15Minutes => 'Durante 15 minutos';

  @override
  String get locationShareFor1Hour => 'Durante 1 hora';

  @override
  String get locationShareFor8Hours => 'Durante 8 horas';

  @override
  String get locationBubbleOpenInMaps => 'Abrir nos mapas';

  @override
  String get locationBubbleLiveBadge => 'EM DIRETO';

  @override
  String get locationBubbleEndedBadge => 'TERMINADO';

  @override
  String locationBubbleLiveUntil(String time) {
    return 'Em direto até às $time';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return 'Localização em direto terminou às $time';
  }

  @override
  String get locationBubbleNoRecentUpdate => 'Sem atualizações recentes';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters m';
  }

  @override
  String get locationBubbleStopSharing => 'Parar de partilhar';

  @override
  String get locationBubbleUnavailable => 'Localização indisponível';

  @override
  String get locationBubbleNoMapsApp =>
      'Não há nenhuma app de mapas para abrir isto';

  @override
  String get locationBubbleCoordinatesCopied => 'Coordenadas copiadas';

  @override
  String get locationCouldNotGetFix =>
      'Não foi possível obter a tua localização';

  @override
  String get locationCouldNotStartLiveShare =>
      'Não foi possível iniciar a partilha em direto';

  @override
  String get locationPermissionNeeded =>
      'É necessário acesso à localização para partilhares onde estás';

  @override
  String get locationPermissionBlockedTitle =>
      'O acesso à localização está desativado';

  @override
  String get locationPermissionBlockedBody =>
      'O MonkeyHub não pode voltar a pedir aqui. Ativa o acesso à localização para o MonkeyHub nas Definições.';

  @override
  String get locationServicesOffTitle =>
      'Os serviços de localização estão desativados';

  @override
  String get locationServicesOffBody =>
      'A localização está desativada neste dispositivo. Ativa-a nas Definições para partilhares onde estás.';

  @override
  String get locationOpenSettings => 'Abrir definições';

  @override
  String get locationBackgroundSheetTitle => 'Se o teu telemóvel reiniciar';

  @override
  String get locationBackgroundSheetBody =>
      'A tua partilha em direto já continua quando sais do MonkeyHub. O acesso em segundo plano trata do resto: um reinício, um fecho forçado, um telemóvel que fica sem bateria e volta.';

  @override
  String get locationBackgroundSheetKeepRunning => 'Retomar sozinha';

  @override
  String get locationBackgroundSheetKeepRunningDetail =>
      'O teu telemóvel vai pedir permissão';

  @override
  String get locationBackgroundSheetAppOnly => 'Deixar parada';

  @override
  String get locationBackgroundSheetAppOnlyDetail => 'Nada mais para permitir';

  @override
  String get locationServiceNotificationTitle =>
      'A partilhar a tua localização em direto';

  @override
  String get locationServiceNotificationBody =>
      'Toca para abrir a conversa ou em Parar para terminar já';

  @override
  String get childPolicyScreenLocationLabel => 'Localização';

  @override
  String get childPolicyScreenLocationOnDesc =>
      'Podem partilhar onde estão, incluindo em direto até 8 horas';

  @override
  String get childPolicyScreenLocationOffDesc =>
      'Não podem partilhar onde estão';

  @override
  String get roomInfoScreenSavedMessagesLabel => 'MENSAGENS GUARDADAS';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      'só tu as vês, e só a partir desta sala. a tua conversa Mensagens guardadas é à parte.';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      'ainda não há nada guardado. mantém uma mensagem premida e escolhe GUARDAR.';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return 'Ir para a mensagem guardada de $name';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return 'Remover dos guardados a mensagem de $name';
  }

  @override
  String get composerCaptureCameraModeLabel => 'câmera';

  @override
  String get composerCaptureVoiceModeLabel => 'mensagem de voz';

  @override
  String get composerCaptureVideoNoteModeLabel => 'nota de vídeo';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode. Deslize com dois dedos ou use as setas para mudar de modo.';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '$mode selecionado';
  }

  @override
  String get composerCaptureRecordingAnnouncement => 'Gravação iniciada';

  @override
  String get composerCaptureLockedAnnouncement =>
      'Gravação bloqueada. Mãos livres.';

  @override
  String get composerCaptureCancelledAnnouncement => 'Gravação descartada';

  @override
  String get composerCaptureSentAnnouncement => 'Gravação enviada';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return 'Gravando, $elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint =>
      'Segure para gravar, deslize para alternar';

  @override
  String get composerCaptureTapForCameraHint =>
      'Toque para a câmera, deslize para alternar';

  @override
  String get composerCaptureSlideToCancelHint => 'deslize para cancelar';

  @override
  String get composerCaptureReleaseToCancelHint => 'solte para cancelar';

  @override
  String get composerCaptureTapToSendHint => 'toque para enviar';

  @override
  String get composerCaptureSendingLabel => 'enviando…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return 'restam $seconds s';
  }

  @override
  String get composerCaptureLockedCancel => 'Cancelar';

  @override
  String get composerCaptureViewOnceLabel => 'Reproduzir uma vez';

  @override
  String get composerCaptureViewOnceVoiceHint => 'Só poderá ouvir uma vez';

  @override
  String get composerCaptureViewOnceVideoHint => 'Só poderá ver uma vez';

  @override
  String get composerCapturePauseLabel => 'Pausar gravação';

  @override
  String get composerCaptureResumeLabel => 'Retomar gravação';

  @override
  String get composerCaptureFlashLabel => 'Flash';

  @override
  String get composerCaptureReviewPlayLabel => 'Reproduzir gravação';

  @override
  String get composerCaptureReviewStopLabel => 'Parar reprodução';

  @override
  String get composerCaptureCancelLabel => 'descartar gravação';

  @override
  String get composerCaptureSendLabel => 'enviar gravação';

  @override
  String get composerCaptureLockLabel =>
      'deslize para cima para bloquear a gravação';

  @override
  String get composerCaptureMicPermissionTitle => 'Microfone necessário';

  @override
  String get composerCaptureMicPermissionBody =>
      'O MonkeyHub precisa do seu microfone para gravar uma mensagem de voz. Ative-o nas Definições e tente novamente.';

  @override
  String get composerCaptureCameraPermissionTitle => 'Câmera necessária';

  @override
  String get composerCaptureCameraPermissionBody =>
      'O MonkeyHub precisa da sua câmara e do seu microfone para gravar uma nota de vídeo. Ative-os nas Definições e tente novamente.';

  @override
  String get composerCaptureRestrictedBody =>
      'A gravação está desativada por uma restrição neste dispositivo.';

  @override
  String get composerCaptureOpenSettingsLabel => 'Abrir Definições';

  @override
  String get composerCaptureUnavailableSnack =>
      'A gravação não está disponível neste dispositivo.';

  @override
  String get composerCaptureInterruptedSnack => 'Gravação interrompida.';

  @override
  String get composerCaptureStorageSnack =>
      'Não foi possível guardar a gravação. Verifique o espaço livre.';

  @override
  String get videoNoteMessagePlayLabel => 'Reproduzir nota de vídeo';

  @override
  String get videoNoteMessagePauseLabel => 'Pausar nota de vídeo';

  @override
  String get videoNoteMessageLoadingLabel => 'A carregar nota de vídeo';

  @override
  String get videoNoteMessageUnavailableLabel => 'Nota de vídeo indisponível';

  @override
  String get videoNoteMessageRetryLabel => 'Tentar novamente a nota de vídeo';

  @override
  String get videoNoteMessageRetryHint => 'Toque para tentar novamente';

  @override
  String get videoNoteMessageDiscardLabel => 'Descartar nota de vídeo';

  @override
  String get videoNoteScrubHint =>
      'Afaste o dedo do círculo para avançar com mais precisão';

  @override
  String get videoNoteScrubHalf => 'Avanço a meia velocidade';

  @override
  String get videoNoteScrubFine => 'Avanço preciso';

  @override
  String videoNoteSpeedLabel(String speed) {
    return 'Velocidade de reprodução $speed';
  }

  @override
  String get videoNoteAutoAdvanceOn => 'Reprodução automática: sim';

  @override
  String get videoNoteAutoAdvanceOff => 'Reprodução automática: não';

  @override
  String get videoNoteAutoAdvanceSemanticLabel =>
      'Reproduzir automaticamente a próxima nota de vídeo';

  @override
  String get composerCaptureStartRecordingLabel => 'Começar a gravar';

  @override
  String get attachmentMenuVideoNoteLabel => 'Nota de vídeo';

  @override
  String get cameraScreenPhotoModeLabel => 'Foto';

  @override
  String get cameraScreenVideoModeLabel => 'Vídeo';

  @override
  String get cameraScreenStartRecordingLabel => 'Iniciar gravação';

  @override
  String get cameraScreenStopRecordingLabel => 'Parar gravação';

  @override
  String get cameraScreenVideoFailedSnack =>
      'Não foi possível gravar esse vídeo.';

  @override
  String get scheduleSheetTitle => 'Agendar mensagem';

  @override
  String get scheduleSheetSubtitle => 'Escreva agora. Sai quando você disser.';

  @override
  String get scheduleSheetWhenLabel => 'Quando';

  @override
  String get schedulePresetInAnHour => 'Daqui a 1 hora';

  @override
  String get schedulePresetInEightHours => 'Daqui a 8 horas';

  @override
  String get schedulePresetTomorrowMorning => 'Amanhã de manhã';

  @override
  String get schedulePresetThisMorning => 'Esta manhã';

  @override
  String get schedulePresetInAWeek => 'Daqui a 1 semana';

  @override
  String get scheduleSheetCustomChip => 'Escolher data';

  @override
  String get scheduleSheetConfirmButton => 'Agendar';

  @override
  String get scheduleSheetSaveButton => 'Guardar';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'Envia $when';
  }

  @override
  String scheduleWhenToday(String time) {
    return 'hoje às $time';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return 'amanhã às $time';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return 'a $date às $time';
  }

  @override
  String get scheduleTimePickerTitle => 'Escolher data e hora';

  @override
  String get scheduleTimePickerBack => 'Opções rápidas';

  @override
  String get scheduleTimePickerToday => 'Hoje';

  @override
  String get scheduleTimePickerTomorrow => 'Amanhã';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AGENDADAS',
      one: '1 AGENDADA',
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
      other: '$count mensagens à espera de envio. Toque para as ver.',
      one: '1 mensagem à espera de envio. Toque para a ver.',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => 'VEJA ISTO';

  @override
  String get scheduledListTitle => 'Agendadas';

  @override
  String get scheduledListSubtitle => 'Só você as vê até serem enviadas.';

  @override
  String get scheduledListEmpty => 'Nada à espera de envio aqui.';

  @override
  String get scheduledListSendNow => 'Enviar agora';

  @override
  String get scheduledListChangeTime => 'Mudar a hora';

  @override
  String get scheduledListEdit => 'Editar texto';

  @override
  String get scheduledListDelete => 'Eliminar';

  @override
  String get scheduledListSending => 'A enviar…';

  @override
  String get scheduledListFailedTitle => 'Não foi possível enviar';

  @override
  String get scheduledListRetry => 'Tentar de novo';

  @override
  String get scheduleErrorOutOfRange =>
      'Escolha uma hora entre dois minutos e um ano a partir de agora.';

  @override
  String get scheduleErrorTooMany =>
      'Demasiadas mensagens à espera aqui. Envie ou elimine algumas primeiro.';

  @override
  String get scheduleErrorNotInEphemeral =>
      'As mensagens desta conversa desaparecem sozinhas, por isso não podem ser agendadas.';

  @override
  String get scheduleErrorNotMember => 'Já não está nesta conversa.';

  @override
  String get scheduleErrorBlocked =>
      'Primeiro terá de desbloquear esta pessoa.';

  @override
  String get scheduleErrorGeneric => 'Não resultou. Tente de novo.';

  @override
  String get scheduleEditTitle => 'Editar mensagem';

  @override
  String get composerScheduleAction => 'Agendar esta mensagem';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens à espera de envio',
      one: '1 mensagem à espera de envio',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => 'Mostrar como';

  @override
  String get scheduledIndicatorPill => 'Cápsula';

  @override
  String get scheduledIndicatorBadge => 'Emblema';

  @override
  String get scheduledIndicatorBoth => 'Ambos';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens já à espera',
      one: '1 mensagem já à espera',
      zero: 'Nada à espera de envio',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => 'Como aparecem';

  @override
  String get scheduledIndicatorPillSub =>
      'Uma barra acima da caixa de texto. Toque para as ver.';

  @override
  String get scheduledIndicatorBadgeSub =>
      'Um número no botão de enviar. Não aparece nada até começar a escrever.';

  @override
  String get scheduledIndicatorBothSub =>
      'A barra, mais o número enquanto escreve.';

  @override
  String get scheduledBack => 'Voltar';

  @override
  String get serverScreenTitle => 'servidor.';

  @override
  String get serverScreenSubtitle =>
      'Onde vivem a sua conta e as suas mensagens';

  @override
  String get serverOnboardingTitle => 'escolha um servidor.';

  @override
  String get serverOnboardingSubtitle =>
      'Esta versão não veio com nenhum. Aponte-a para o seu';

  @override
  String get serverStatusConnected => 'Ligado';

  @override
  String get serverStatusDisconnected => 'Sem ligação';

  @override
  String get serverBadgeDefault => 'Predefinido';

  @override
  String get serverBadgeSelfHosted => 'Auto-alojado';

  @override
  String get serverNoneConfigured => 'Ainda sem servidor';

  @override
  String get serverActiveNowLabel => 'Em uso';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'O servidor que veio com esta aplicação.';

  @override
  String get serverChoiceOwn => 'O seu próprio servidor';

  @override
  String get serverChoiceOwnSub => 'Um backend Convex gerido por si.';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => 'Colar';

  @override
  String get serverProblemMalformed => 'Isso não é um endereço web.';

  @override
  String get serverProblemBadScheme => 'Comece com https:// ou http://.';

  @override
  String get serverProblemNoHost =>
      'Adicione o endereço do seu servidor a seguir a https://.';

  @override
  String get serverProblemCredentials =>
      'Retire o nome de utilizador e a palavra-passe do endereço.';

  @override
  String get serverInsecureTitle => 'Sem encriptação';

  @override
  String get serverInsecureBody =>
      'Os telemóveis bloqueiam http simples, por isso este endereço não vai ligar no iOS nem no Android. Use https, ou chegue ao seu servidor através de um túnel.';

  @override
  String get serverTestCta => 'Testar ligação';

  @override
  String get serverTestingLabel => 'A testar…';

  @override
  String get serverCheckReachable => 'Algo respondeu';

  @override
  String get serverCheckConvex => 'É um servidor Convex';

  @override
  String get serverCheckApp => 'Tem o MonkeyHub instalado';

  @override
  String get serverResultUnreachable => 'Nada respondeu nesse endereço.';

  @override
  String get serverResultNotConvex =>
      'Algo respondeu, mas não é um servidor Convex.';

  @override
  String get serverResultNotThisApp =>
      'É um servidor Convex, mas o MonkeyHub não está instalado nele.';

  @override
  String get serverResultServerError =>
      'O servidor respondeu, mas com um erro.';

  @override
  String get serverResultReady => 'Pronto a ligar.';

  @override
  String get serverConnectCta => 'Ligar';

  @override
  String get serverConnectAnywayCta => 'Ligar mesmo assim';

  @override
  String get serverAlreadyConnectedCta => 'Já ligado';

  @override
  String get serverUseDefaultCta => 'Usar o servidor predefinido';

  @override
  String get serverChangeCta => 'Mudar servidor';

  @override
  String get serverAdvancedLabel => 'Avançado';

  @override
  String get serverSiteUrlExplain =>
      'A maioria dos servidores responde a tudo num só endereço. Preencha isto apenas se o seu servir as ações HTTP noutro.';

  @override
  String get serverSiteUrlHint => 'Igual ao de cima';

  @override
  String get serverSectionRecent => 'Recentes';

  @override
  String get serverRecentForget => 'Esquecer este servidor';

  @override
  String get serverSwitchWarningTitle => 'Mudar termina a sessão';

  @override
  String get serverSwitchWarningBody =>
      'As contas e as conversas pertencem a um único servidor. Este dispositivo termina a sessão, limpa o que transferiu e começa de novo. Não se apaga nada em nenhum dos servidores.';

  @override
  String get serverSwitchRolledBackTitle => 'Não foi possível ligar';

  @override
  String serverSwitchRolledBackBody(String host) {
    return 'O $host não respondeu, por isso nada mudou. Vai ter de iniciar sessão de novo.';
  }

  @override
  String get serverSwitchStrandedBody =>
      'Nenhum dos servidores ligou. Verifique o endereço e tente de novo.';

  @override
  String get serverSwitchRefusedBody =>
      'Este dispositivo está configurado para uma criança e não pode mudar de servidor.';

  @override
  String serverChipSemantics(String server) {
    return 'Mudar de servidor. Atualmente $server.';
  }

  @override
  String get serverValueDefault => 'Predefinido';

  @override
  String get settingsScreenRowServer => 'SERVIDOR';

  @override
  String get settingsScreenSectionAdvanced => 'AVANÇADO';

  @override
  String get serverSwitchingLabel => 'A mudar de servidor…';

  @override
  String get serverRoleExplainAction => 'O que é que isto significa?';

  @override
  String get serverBadgeRibbonHomeserver => 'CASA';

  @override
  String get serverBadgeRibbonSelfHosted => 'PRÓPRIO';

  @override
  String get serverBadgeHomeserver => 'A servir a partir do homeserver';

  @override
  String get serverBadgeHomeserverSemantics =>
      'A servir a partir do homeserver. Toque para saber mais.';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'Servidor auto-alojado: $server. Toque para saber mais.';
  }

  @override
  String get serverRoleHomeserverTitle => 'A funcionar no homeserver';

  @override
  String get serverRoleHomeserverBody =>
      'Quem gere o MonkeyHub passou o tráfego para o servidor de casa durante algum tempo. Tudo funciona da mesma forma. É intencional, não é uma avaria.';

  @override
  String get serverRoleHomeserverWarnData =>
      'O que enviar enquanto isto durar pode não estar cá depois de o tráfego voltar.';

  @override
  String get serverRoleHomeserverWarnSpeed =>
      'Uma ligação doméstica é mais lenta do que a habitual, por isso pode haver atrasos.';

  @override
  String get serverRoleHomeserverWarnAuto =>
      'Não precisa de fazer nada. A aplicação volta sozinha.';

  @override
  String get serverRoleSelfHostedTitle => 'O seu próprio servidor';

  @override
  String get serverRoleSelfHostedBody =>
      'Este dispositivo aponta para um servidor seu. Altere em Definições › Avançado › Servidor.';

  @override
  String get serverValueHomeserver => 'Homeserver, para já';

  @override
  String get serverChoiceCloudSubHomeserver =>
      'A ser servido a partir do homeserver durante algum tempo.';

  @override
  String get serverDirectiveChangedToast =>
      'O seu servidor mudou. A ligar de novo…';

  @override
  String get loginScreenSignInWithPhone => 'sign in with your phone';

  @override
  String get loginScreenUsePasswordInstead => 'Usar uma palavra-passe';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      'Abre o MonkeyHub no telemóvel, vai ao teu perfil, toca em “Leia o código para entrar” e aponta a câmara para aqui, ou escreve o código abaixo.';

  @override
  String get deviceLoginScreenWaiting => 'A aguardar aprovação…';

  @override
  String get deviceLoginScreenApproved => 'Aprovado. A iniciar sessão…';

  @override
  String get deviceLoginScreenDenied =>
      'Pedido de início de sessão recusado no telemóvel';

  @override
  String get deviceLoginScreenGenericError =>
      'Algo correu mal. Experimenta um código novo';

  @override
  String get profileScreenScanToSignInLabel => 'Leia o código para entrar';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro =>
      'Aponta a câmara para o código no computador ou escreve-o abaixo.';

  @override
  String get deviceLoginScanScreenScanButtonLabel => 'Ler código';

  @override
  String get deviceLoginScanScreenConfirmTitle =>
      'Iniciar sessão neste dispositivo?';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return '$deviceInfo quer iniciar sessão como tu. Aprova só se fores tu, agora mesmo.';
  }

  @override
  String get deviceLoginScanScreenApproveButton => 'Aprovar';

  @override
  String get deviceLoginScanScreenDenyButton => 'Recusar';

  @override
  String get deviceLoginScanScreenSuccess =>
      'Sessão iniciada no teu outro dispositivo';

  @override
  String get deviceLoginScanScreenGenericError =>
      'Não foi possível aprovar. Tenta outra vez';

  @override
  String get authErrorDeviceLoginInvalid => 'Esse código não está certo.';

  @override
  String get authErrorDeviceLoginExpired =>
      'Esse código expirou. Obtém um novo no outro dispositivo.';

  @override
  String get deviceLoginScanScreenDeniedConfirmation =>
      'Pedido de início de sessão recusado';

  @override
  String get roomAdminRoleAdmin => 'Admin';

  @override
  String get roomAdminActionViewProfile => 'Ver perfil';

  @override
  String get roomAdminActionPromote => 'Tornar admin';

  @override
  String get roomAdminActionPromoteSub =>
      'Vai poder convidar, remover membros e editar o grupo';

  @override
  String get roomAdminActionDemote => 'Retirar admin';

  @override
  String get roomAdminActionDemoteSub => 'Continua no grupo como membro';

  @override
  String get roomAdminActionTransfer => 'Transferir o grupo';

  @override
  String get roomAdminActionTransferSub => 'Ficas como admin';

  @override
  String get roomAdminActionRemove => 'Remover do grupo';

  @override
  String get roomAdminAddFriendsRow => 'Adicionar amigos';

  @override
  String get roomAdminInviteLinkRow => 'Link de convite';

  @override
  String get roomAdminJoinRequestsRow => 'Pedidos para entrar';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return 'Entregar o grupo a $name?';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      'Passa a ser o dono e pode apagar o grupo. Ficas como admin, e só essa pessoa te pode devolver o grupo.';

  @override
  String get roomAdminTransferConfirmCta => 'Transferir';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return 'Remover $name?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'Perde o acesso ao grupo e a tudo o que lá está. Pode ser convidada outra vez, ou voltar pelo link de convite.';

  @override
  String get roomAdminRemoveConfirmCta => 'Remover';

  @override
  String get roomAdminGenericError => 'Não resultou. Tenta outra vez.';

  @override
  String get roomAdminErrorNotMember => 'Já não estás neste grupo.';

  @override
  String get roomAdminErrorNotAdmin => 'Só os admins podem fazer isso.';

  @override
  String get roomAdminErrorNotOwner => 'Só o dono do grupo pode fazer isso.';

  @override
  String get roomAdminErrorNotGroup =>
      'Numa conversa direta não há nada para administrar.';

  @override
  String get roomAdminErrorOwnerImmutable =>
      'O papel do dono só muda transferindo o grupo.';

  @override
  String get roomAdminErrorInvitesLocked =>
      'Só os admins podem convidar para este grupo.';

  @override
  String get roomInviteSheetTitle => 'Link de convite';

  @override
  String get roomInviteSheetBlurb =>
      'Um link e um código, e são a mesma coisa. Assim que fizeres um novo, o anterior deixa de funcionar.';

  @override
  String get roomInviteNoLinkYet => 'Este grupo ainda não tem link de convite.';

  @override
  String get roomInviteCreateButton => 'Criar link';

  @override
  String get roomInviteRegenerateButton => 'Novo link';

  @override
  String get roomInviteRevokeButton => 'Revogar link';

  @override
  String get roomInviteCopyLink => 'Copiar link';

  @override
  String get roomInviteCopyCode => 'Copiar código';

  @override
  String get roomInviteShare => 'Partilhar';

  @override
  String get roomInviteLinkCopied => 'Link copiado.';

  @override
  String get roomInviteCodeCopied => 'Código copiado.';

  @override
  String get roomInviteRegenerateHeadline => 'Fazer um link novo?';

  @override
  String get roomInviteRegenerateBody =>
      'O link e o código atuais deixam de funcionar de imediato, em todo o lado onde foram partilhados. Quem já está no grupo fica.';

  @override
  String get roomInviteRegenerateConfirm => 'Novo link';

  @override
  String get roomInviteRevokeHeadline => 'Revogar este link?';

  @override
  String get roomInviteRevokeBody =>
      'Ninguém novo entra por link até fazeres outro. Quem já está no grupo fica.';

  @override
  String get roomInviteRevokeConfirm => 'Revogar';

  @override
  String get roomInviteLimitsLabel => 'Limites';

  @override
  String get roomInviteExpiryLabel => 'Expira ao fim de';

  @override
  String get roomInviteMaxUsesLabel => 'Número de utilizações';

  @override
  String get roomInviteNeverExpires => 'Nunca';

  @override
  String get roomInviteUnlimited => 'Sem limite';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count h';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count d';
  }

  @override
  String get roomInviteLimitsApplyToNew => 'Aplicam-se ao link que criares.';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      'Aplicam-se ao próximo link. O de cima mantém os limites com que foi criado.';

  @override
  String get roomInvitePermissionsLabel => 'Permissões';

  @override
  String get roomInviteMembersCanInviteLabel =>
      'Os membros podem convidar amigos';

  @override
  String get roomInviteMembersCanInviteSub =>
      'Desliga e só os admins trazem pessoas';

  @override
  String get roomInviteApprovalLabel => 'Aprovar cada entrada';

  @override
  String get roomInviteApprovalSub =>
      'Quem tem o link pede primeiro, e um admin diz sim ou não';

  @override
  String roomInviteUsesCount(Object count) {
    return 'Usado $count vezes';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$used de $max utilizações';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return 'Expira a $date';
  }

  @override
  String get roomInviteDeadExpired => 'Este link expirou. Faz um novo.';

  @override
  String get roomInviteDeadExhausted =>
      'Este link esgotou as utilizações. Faz um novo.';

  @override
  String get roomInviteDeadRevoked => 'Este link foi revogado.';

  @override
  String get roomInviteDeadGeneric => 'Este link já não funciona.';

  @override
  String get roomInviteFriendsTitle => 'Adicionar amigos';

  @override
  String get roomInviteFriendsBlurb =>
      'Vão receber um convite e podem aceitar ou recusar.';

  @override
  String get roomInviteFriendsSearchHint => 'Procurar amigos';

  @override
  String get roomInviteFriendsInviteButton => 'Convidar';

  @override
  String get roomInviteFriendsSent => 'Convidado';

  @override
  String get roomInviteFriendsEmpty =>
      'Todos os teus amigos já estão aqui ou já foram convidados.';

  @override
  String get roomInviteFriendsNoMatch => 'Nenhum amigo corresponde a isso.';

  @override
  String get roomInviteFriendsDone => 'Pronto';

  @override
  String get roomJoinRequestsTitle => 'Pedidos para entrar';

  @override
  String get roomJoinRequestsBlurb =>
      'Estas pessoas usaram o link de convite. Não veem nada do grupo até dizeres que sim.';

  @override
  String get roomJoinRequestsEmpty => 'Ninguém à espera.';

  @override
  String get roomJoinRequestsApprove => 'DEIXAR ENTRAR';

  @override
  String get roomJoinRequestsReject => 'NÃO';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return 'CONVIDADOS · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian =>
      'À espera de um pai ou mãe';

  @override
  String get roomInfoScreenInviteWithdraw => 'RETIRAR';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return 'De $inviter · $members membros';
  }

  @override
  String get roomInvitationCardJoin => 'Entrar';

  @override
  String get discoverScreenJoinByCodeTitle => 'Entrar com um código';

  @override
  String get discoverScreenJoinByCodeSubtitle =>
      'Abre um grupo que alguém partilhou contigo';

  @override
  String get joinInviteTitle => 'Entrar num grupo';

  @override
  String get joinInviteBack => 'Voltar';

  @override
  String get joinInviteCodeBlurb =>
      'Escreve o código que partilharam contigo. Um link de convite completo também serve.';

  @override
  String get joinInviteCodeLabel => 'Código de convite';

  @override
  String get joinInviteCodeHint => 'Cola o link ou escreve o código';

  @override
  String get joinInviteCodeInvalid => 'Isso não parece um código de convite.';

  @override
  String get joinInviteLookupButton => 'Continuar';

  @override
  String get joinInviteLookupFailed =>
      'Não foi possível verificar o código. Vê a tua ligação e tenta outra vez.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count membros';
  }

  @override
  String get joinInviteJoinButton => 'Entrar no grupo';

  @override
  String get joinInviteRequestButton => 'Pedir para entrar';

  @override
  String get joinInviteOpenNote =>
      'Vais ver as mensagens do grupo assim que entrares.';

  @override
  String get joinInviteApprovalNote =>
      'Um admin tem de dizer que sim antes de poderes ver o que quer que seja aqui.';

  @override
  String get joinInviteOpenRoom => 'Abrir grupo';

  @override
  String get joinInvitePendingHeadline => 'À espera de um admin';

  @override
  String get joinInvitePendingBody =>
      'Recebes uma notificação assim que alguém responder.';

  @override
  String get joinInviteBadLinkHeadline => 'Este convite não funciona';

  @override
  String get joinInviteBadLinkBody => 'Confere o código, ou pede um link novo.';

  @override
  String get joinInviteExpiredHeadline => 'Este convite expirou';

  @override
  String get joinInviteExpiredBody => 'Pede um link novo a quem te convidou.';

  @override
  String get joinInviteExhaustedHeadline => 'Este convite esgotou';

  @override
  String get joinInviteExhaustedBody =>
      'Estava definido para funcionar um número limitado de vezes. Pede outro.';

  @override
  String get joinInviteRevokedHeadline => 'Este convite foi substituído';

  @override
  String get joinInviteRevokedBody =>
      'Um admin fez um link novo. Pede-lhe o atual.';

  @override
  String get joinInviteWrongServerHeadline =>
      'Este convite é de outro servidor';

  @override
  String joinInviteWrongServerBody(Object host) {
    return 'Pertence a $host. A tua conta está noutro servidor, por isso este grupo não é acessível daqui.';
  }

  @override
  String get roomInviteErrorNotFound =>
      'Esse código de convite não corresponde a nada.';

  @override
  String get roomInviteErrorRevoked =>
      'Esse convite foi substituído. Pede o link atual.';

  @override
  String get roomInviteErrorExpired => 'Esse convite expirou.';

  @override
  String get roomInviteErrorExhausted => 'Esse convite esgotou.';

  @override
  String get roomInviteErrorAlreadyMember => 'Já está neste grupo.';

  @override
  String get roomInviteErrorAlreadyInvited => 'Já foi convidado.';

  @override
  String get roomInviteErrorSelf => 'Já estás neste grupo.';

  @override
  String get roomInviteErrorInvitationGone => 'Esse convite já não existe.';

  @override
  String get roomInviteErrorRequestPending =>
      'Já pediste para entrar. Um admin vai responder.';

  @override
  String get roomInviteErrorRequestGone => 'Alguém já respondeu a esse pedido.';

  @override
  String get roomInviteErrorRoomPrivate =>
      'Só se entra neste grupo com convite.';

  @override
  String get roomInviteErrorInvalidLimits => 'Esses limites não são válidos.';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$child quer convidar $other para $room';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$other convidou $child para $room';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      'O convite segue, e quem decide continua a ser a outra pessoa.';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$child vai ver o convite e pode aceitar ou recusar. Aprovar também lhe dá acesso a esse grupo se aceitar.';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      'Não te podes remover a ti próprio. Sai do grupo em vez disso.';

  @override
  String get roomAdminActionMessage => 'Enviar mensagem';

  @override
  String get roomAdminActionVoiceCall => 'Chamada de voz';

  @override
  String get roomAdminActionVideoCall => 'Videochamada';

  @override
  String get roomAdminYouSuffix => 'Tu';

  @override
  String get roomInfoScreenSetPasswordButton => 'DEFINIR';

  @override
  String get roomInfoScreenPasswordSetSnackbar => 'Palavra-passe definida.';

  @override
  String get roomInfoScreenPasswordSetState => 'Com palavra-passe';

  @override
  String get roomInfoScreenPasswordUnsetState => 'Sem palavra-passe';

  @override
  String get roomInfoScreenPasswordCancel => 'Cancelar';

  @override
  String get roomInfoScreenEditSave => 'Guardar';

  @override
  String get roomInfoScreenEditCancel => 'Cancelar';

  @override
  String get roomInviteRotatedToast =>
      'Novo link criado. O anterior já não funciona.';

  @override
  String get roomInviteRevokedToast => 'Link de convite revogado.';

  @override
  String get newChatMenuTitle => 'Nova conversa';

  @override
  String get newChatMenuCreateTitle => 'Criar uma sala';

  @override
  String get newChatMenuCreateSub => 'Começa um grupo e convida pessoas';

  @override
  String get newChatMenuJoinTitle => 'Entrar com um código';

  @override
  String get newChatMenuJoinSub => 'Abre um grupo partilhado contigo';

  @override
  String get shareSheetTitle => 'Partilhar com';

  @override
  String get shareSheetSuggestedHeading => 'Sugeridos';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anexos',
      one: '1 anexo',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ficheiros excedem o limite de $size e ficaram de fora',
      one: '1 ficheiro excede o limite de $size e ficou de fora',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return 'Enviar para $title';
  }

  @override
  String get settingsScreenRowSpeakerColors => 'CORES DAS PESSOAS';

  @override
  String get settingsScreenValueSpeakerOff => 'Desligado';

  @override
  String get settingsScreenValueSpeakerName => 'Nomes';

  @override
  String get settingsScreenValueSpeakerBubble => 'Nomes + balões';

  @override
  String get speakerColorScreenTitle => 'cores das pessoas.';

  @override
  String get speakerColorScreenSubtitle => 'quem disse aquilo, sem ler o nome';

  @override
  String get speakerColorScreenOffLabel => 'DESLIGADO';

  @override
  String get speakerColorScreenOffDescription =>
      'toda a gente na sala escreve com a mesma tinta.';

  @override
  String get speakerColorScreenNameLabel => 'NOMES';

  @override
  String get speakerColorScreenNameDescription =>
      'cada pessoa fica com uma cor própria, no nome e à volta da cara.';

  @override
  String get speakerColorScreenBubbleLabel => 'BALÕES';

  @override
  String get speakerColorScreenBubbleDescription =>
      'a cor passa também para as mensagens, por isso uma sequência de cinco continua a dizer quem escreveu.';

  @override
  String get roomInfoScreenSpeakerColorsLabel => 'CORES';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => 'Automático';

  @override
  String get roomInfoScreenSpeakerColorsCustom => 'Personalizado';

  @override
  String get roomColorsScreenTitle => 'quem é quem.';

  @override
  String get roomColorsScreenSubtitle => 'a cor de cada pessoa';

  @override
  String get roomColorsScreenOffTitle =>
      'as cores das pessoas estão desligadas';

  @override
  String get roomColorsScreenOffBody =>
      'por agora toda a gente aparece com a mesma tinta. liga e cada pessoa aqui fica com a sua.';

  @override
  String get roomColorsScreenOffAction => 'LIGAR';

  @override
  String get roomColorsScreenOffHint =>
      'aplica-se a todas as salas, não só a esta. também está nas definições.';

  @override
  String get roomColorsScreenAutoChip => 'AUTO';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return 'partilhada com $name';
  }

  @override
  String get roomColorsScreenResetAll => 'VOLTAR A AUTOMÁTICO';

  @override
  String get roomColorsScreenLimitToast =>
      'É o máximo que uma sala pode fixar.';

  @override
  String get roomColorsScreenFailedToast =>
      'Não foi possível guardar essa cor.';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return 'Cor $index';
  }

  @override
  String get devicesScreenTitle => 'OS TEUS DISPOSITIVOS';

  @override
  String get devicesScreenSubtitle =>
      'Todos os sítios onde iniciaste sessão nesta conta.';

  @override
  String get devicesScreenLoading => 'a verificar…';

  @override
  String get devicesScreenLoadFailed =>
      'não foi possível carregar os teus dispositivos';

  @override
  String get devicesScreenThisDevice => 'ESTE DISPOSITIVO';

  @override
  String get devicesScreenActiveNow => 'ativo agora';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count minutos',
      one: 'há 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count horas',
      one: 'há 1 hora',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count dias',
      one: 'há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications =>
      'as notificações não chegam a este';

  @override
  String get devicesScreenRemove => 'REMOVER';

  @override
  String get devicesScreenRemoveTitle => 'REMOVER ESTE DISPOSITIVO?';

  @override
  String devicesScreenRemoveBody(Object name) {
    return 'A sessão em $name será terminada e deixará de receber notificações. Quem o tiver terá de iniciar sessão outra vez.';
  }

  @override
  String get devicesScreenRemoveConfirm => 'REMOVER';

  @override
  String get devicesScreenRemoveAll => 'Remover todos os outros dispositivos';

  @override
  String get devicesScreenRemoveAllTitle =>
      'REMOVER TODOS OS OUTROS DISPOSITIVOS?';

  @override
  String get devicesScreenRemoveAllBody =>
      'Todos terão a sessão terminada e deixarão de receber notificações. Só este dispositivo continua com sessão iniciada.';

  @override
  String get devicesScreenRemoveAllConfirm => 'REMOVER TODOS';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivos removidos',
      one: '1 dispositivo removido',
      zero: 'não há outros dispositivos para remover',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed =>
      'não foi possível remover esse dispositivo';

  @override
  String get devicesScreenFootnote =>
      'Remover um dispositivo termina a sua sessão e para as notificações. Tem efeito imediato: a próxima coisa que esse dispositivo tentar fazer devolve-o ao ecrã de início de sessão.';

  @override
  String get attachmentMenuPollLabel => 'Enquete';

  @override
  String get attachmentMenuChecklistLabel => 'Lista';

  @override
  String get attachmentMenuEventLabel => 'Evento';

  @override
  String get interactionKindPoll => 'Enquete';

  @override
  String get interactionKindQuiz => 'Quiz';

  @override
  String get interactionKindChecklist => 'Lista';

  @override
  String get interactionKindEvent => 'Evento';

  @override
  String get interactionBadgeAnonymous => 'Anónima';

  @override
  String get interactionBadgeMultiple => 'Várias';

  @override
  String get interactionBadgeClosed => 'Fechada';

  @override
  String interactionPercent(int percent) {
    return '$percent %';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names +$count';
  }

  @override
  String get interactionSeeWhoAnswered => 'Ver quem respondeu';

  @override
  String interactionRemoveItem(String label) {
    return 'Remover $label';
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
  String get interactionAddItemHint => 'Adicionar um item';

  @override
  String get interactionRetract => 'Retirar';

  @override
  String get interactionClose => 'Fechar';

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
      other: '$count respostas',
      one: '1 resposta',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$done de $total feitos';
  }

  @override
  String get interactionNoAnswers => 'Sem respostas';

  @override
  String get interactionBeFirst => 'Sê o primeiro a responder';

  @override
  String interactionFinalResults(String count) {
    return '$count · final';
  }

  @override
  String get interactionQuizRight => 'Certo';

  @override
  String get interactionQuizWrong => 'Quase';

  @override
  String interactionEventPast(String when) {
    return '$when · já passou';
  }

  @override
  String get interactionRespondentsTitlePoll => 'Quem votou';

  @override
  String get interactionRespondentsTitleChecklist => 'Quem marcou';

  @override
  String get interactionRespondentsTitleEvent => 'Quem respondeu';

  @override
  String get interactionRespondentsFailed =>
      'Não foi possível carregar quem respondeu.';

  @override
  String get interactionRespondentsEmpty => 'Ainda ninguém respondeu.';

  @override
  String get interactionFilterAll => 'Todos';

  @override
  String get interactionRsvpGoing => 'Vou';

  @override
  String get interactionRsvpMaybe => 'Talvez';

  @override
  String get interactionRsvpNo => 'Não posso';

  @override
  String get interactionComposePollTitle => 'Nova enquete';

  @override
  String get interactionComposePollTagline => 'Pergunta à sala';

  @override
  String get interactionComposeChecklistTitle => 'Nova lista';

  @override
  String get interactionComposeChecklistTagline => 'Uma lista que todos marcam';

  @override
  String get interactionComposeEventTitle => 'Novo evento';

  @override
  String get interactionComposeEventTagline => 'Vê quem vem';

  @override
  String get interactionComposeQuestionLabel => 'Pergunta';

  @override
  String get interactionComposeQuestionHint => 'O que queres perguntar?';

  @override
  String get interactionComposeTitleLabel => 'Título';

  @override
  String get interactionComposeTitleHint => 'Para que serve esta lista?';

  @override
  String get interactionComposeEventNameLabel => 'Evento';

  @override
  String get interactionComposeEventNameHint => 'O que vai acontecer?';

  @override
  String get interactionComposeOptionsLabel => 'Opções';

  @override
  String get interactionComposeItemsLabel => 'Itens';

  @override
  String interactionComposeOptionHint(int index) {
    return 'Opção $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return 'Item $index';
  }

  @override
  String get interactionComposeAddOption => 'Adicionar opção';

  @override
  String get interactionComposeAddItem => 'Adicionar item';

  @override
  String get interactionComposeRemoveRow => 'Remover';

  @override
  String get interactionComposeMarkCorrect => 'Marcar como resposta certa';

  @override
  String get interactionComposeMultipleTitle => 'Várias respostas';

  @override
  String get interactionComposeMultipleSub => 'Escolher mais do que uma';

  @override
  String get interactionComposeAnonymousTitle => 'Anónima';

  @override
  String get interactionComposeAnonymousOffSub => 'Todos veem quem votou';

  @override
  String get interactionComposeAnonymousOnSub => 'Ninguém vê quem votou';

  @override
  String get interactionComposeQuizTitle => 'Modo quiz';

  @override
  String get interactionComposeQuizSub =>
      'Uma só resposta certa, sem voltar atrás';

  @override
  String get interactionComposeExplanationLabel => 'Explicação';

  @override
  String get interactionComposeExplanationHint =>
      'Mostrada depois de responder (opcional)';

  @override
  String get interactionComposeOthersMayCheckTitle => 'Qualquer um pode marcar';

  @override
  String get interactionComposeOthersMayCheckSub => 'Não só tu';

  @override
  String get interactionComposeOthersMayAddTitle =>
      'Qualquer um pode adicionar';

  @override
  String get interactionComposeOthersMayAddSub => 'A lista pode crescer depois';

  @override
  String get interactionComposeWhenLabel => 'Quando';

  @override
  String get interactionComposePickStart => 'Escolhe o início';

  @override
  String get interactionComposePickEnd => 'Adicionar um fim (opcional)';

  @override
  String get interactionComposePlaceLabel => 'Local';

  @override
  String get interactionComposePlaceHint => 'Onde? (opcional)';

  @override
  String get interactionComposeSendPoll => 'Enviar a enquete';

  @override
  String get interactionComposeSendChecklist => 'Enviar a lista';

  @override
  String get interactionComposeSendEvent => 'Enviar o evento';

  @override
  String get interactionComposeErrorPrompt =>
      'Diz primeiro o que estás a perguntar.';

  @override
  String interactionComposeErrorOptions(int count) {
    return 'Uma enquete precisa de pelo menos $count opções.';
  }

  @override
  String get interactionComposeErrorItems =>
      'Uma lista precisa de pelo menos um item.';

  @override
  String get interactionComposeErrorAnswer => 'Marca qual é a opção certa.';

  @override
  String get interactionComposeErrorWhen => 'Escolhe quando começa.';

  @override
  String get interactionComposeErrorEnd => 'O fim tem de vir depois do início.';

  @override
  String get interactionSendFailed => 'Não foi enviado.';

  @override
  String get interactionRefused => 'Não foi registado.';

  @override
  String get messageReceiptsScreenTitle => 'Info da mensagem';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$read de $total leram';
  }

  @override
  String get messageReceiptsEmptyState =>
      'Ainda não há mais ninguém nesta sala';

  @override
  String get messageReceiptsSectionRead => 'Lido';

  @override
  String get messageReceiptsSectionDelivered => 'Entregue';

  @override
  String get messageReceiptsSectionSent => 'Enviado';

  @override
  String get messageReceiptsSectionHidden => 'Sem recibo';

  @override
  String get messageReceiptsStateHidden => 'Não partilhado';

  @override
  String get messageReceiptsStateWaiting => 'À espera';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name leu isto $day às $time';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name recebeu isto $day às $time';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name ainda não recebeu isto';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name não partilha recibos de leitura';
  }

  @override
  String get companionsScreenTitle => 'companheiros.';

  @override
  String get companionsScreenSubtitle =>
      'ajudantes que vivem neste telemóvel e não enviam nada para lado nenhum';

  @override
  String get companionSebastianTagline => 'Traduz mensagens';

  @override
  String get companionSebastianBlurb =>
      'O Sebastian lê uma mensagem escrita noutra língua e diz-te o que ela diz, aqui, no teu telemóvel, sem enviar nada para lado nenhum.';

  @override
  String get companionMarloweTagline => 'Ajuda geral';

  @override
  String get companionMarloweBlurb =>
      'Marlowe trata de tudo o que não seja tradução. Escolhe já um cérebro e as capacidades chegarão à volta disso.';

  @override
  String get companionAssuranceOnDevice =>
      'Funciona inteiramente neste dispositivo';

  @override
  String get companionAssurancePrivate =>
      'As tuas mensagens nunca saem do telemóvel';

  @override
  String get companionAssuranceOffline => 'Funciona sem ligação';

  @override
  String companionInstallAction(Object size) {
    return 'Instalar · $size';
  }

  @override
  String get companionInstallOneTime =>
      'Transferência única, fica até a removeres';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$received de $total';
  }

  @override
  String get companionInstallQueued =>
      'À espera que outra transferência termine';

  @override
  String get companionInstallCancel => 'Cancelar';

  @override
  String get companionInstallRetry => 'Tentar de novo';

  @override
  String companionInstallReady(Object name) {
    return '$name está pronto';
  }

  @override
  String get companionInstallFailedNetwork =>
      'A transferência não terminou. Verifica a ligação e tenta de novo.';

  @override
  String get companionInstallFailedStorage =>
      'Não há espaço suficiente neste dispositivo. Liberta algum e tenta de novo.';

  @override
  String get companionInstallFailedUnknown => 'A transferência não terminou.';

  @override
  String get companionUnsupportedPlatform =>
      'Os companheiros ainda não estão disponíveis nesta versão da app.';

  @override
  String companionBrainNeedsMemory(String size) {
    return 'Precisa de $size de memória';
  }

  @override
  String get sebastianTierSeniorDetail => 'Traduções mais precisas';

  @override
  String get sebastianTierJuniorDetail => 'Funciona em qualquer telemóvel';

  @override
  String get sebastianLanguageUnlisted =>
      'Não é uma das línguas dele, resultados imprecisos';

  @override
  String get companionStatusNotInstalled => 'Não instalado';

  @override
  String get companionStatusOff => 'Desligado';

  @override
  String companionStatusTranslatingInto(Object language) {
    return 'A traduzir para $language';
  }

  @override
  String get companionStatusNoBrain => 'Ainda não transferiste nada';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transferências prontas',
      one: '1 transferência pronta',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty =>
      'Nada transferido. Os companheiros não ocupam espaço';

  @override
  String companionStorageUsed(Object size) {
    return 'Os companheiros ocupam $size';
  }

  @override
  String get companionSectionGeneral => 'Geral';

  @override
  String get companionSectionStorage => 'Armazenamento';

  @override
  String get companionBrainRemove => 'Remover';

  @override
  String companionBrainRemoveTitle(Object name) {
    return 'REMOVER $name?';
  }

  @override
  String companionRemoveTitle(Object name) {
    return 'REMOVER $name?';
  }

  @override
  String companionRemoveMessage(Object size) {
    return 'Isto liberta $size. Podes voltar a transferir quando quiseres.';
  }

  @override
  String get companionRemoveConfirm => 'Remover';

  @override
  String get sebastianEnableLabel => 'Deixar o Sebastian traduzir';

  @override
  String get sebastianEnableDetail =>
      'Desliga para o parar sem apagar a transferência';

  @override
  String get sebastianLanguageSection => 'Traduzir para';

  @override
  String get sebastianLanguageFollowApp => 'O mesmo da app';

  @override
  String sebastianBrainDetail(Object size) {
    return 'Neste dispositivo · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count traduções guardadas',
      one: '1 tradução guardada',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => 'Limpar';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe ainda não faz nada, as capacidades estão a caminho. O que podes fazer já é deixar um cérebro pronto, para que nada fique à espera de uma transferência quando chegarem.';

  @override
  String get marloweBrainsSection => 'Cérebro';

  @override
  String get marloweBrainsCaption =>
      'Maior pensa melhor e responde mais devagar. Podes guardar mais do que um e alternar entre eles.';

  @override
  String get marloweBrainTierSwift => 'Rápido';

  @override
  String get marloweBrainTierBalanced => 'Equilibrado';

  @override
  String get marloweBrainTierDeep => 'Profundo';

  @override
  String get translationSlabShowOriginal => 'Ver original';

  @override
  String get translationSlabFailed =>
      'Não foi possível traduzir esta mensagem.';

  @override
  String get translationSlabRetry => 'Tentar de novo';

  @override
  String translationSlabByCompanion(Object name) {
    return 'Traduzido pelo $name';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return 'De $language';
  }

  @override
  String get messageActionMenuTranslateLabel => 'Traduzir';

  @override
  String get messageActionMenuShowOriginalLabel => 'Ver original';

  @override
  String get roomTranslateTitle => 'Traduzir esta conversa';

  @override
  String get roomTranslateStopTitle => 'Parar de traduzir';

  @override
  String get roomTranslateSectionLabel => 'TRADUÇÃO';

  @override
  String get roomTranslateOnRow => 'A traduzir esta conversa';

  @override
  String get roomTranslateOffRow => 'Desligado';

  @override
  String get roomTranslateNeedsSetUp => 'Configurar o Sebastian';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'O Sebastian está a traduzir · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return 'A ler em $language';
  }

  @override
  String get roomTranslateStop => 'PARAR';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return 'Já está em $language';
  }

  @override
  String get roomScreenTranslateRoomOffer =>
      'Traduzir também o resto da conversa?';

  @override
  String get roomScreenTranslateRoomOfferAction => 'Traduzir tudo';

  @override
  String get settingsScreenCompanionsOff => 'Desligado';

  @override
  String get settingsScreenCompanionsUnavailable => 'Indisponível';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return 'Também usado pelo $name';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return 'O $name usa a mesma transferência e também a vai perder.';
  }

  @override
  String get companionBrainInUse => 'Em uso';

  @override
  String companionStatusUsingBrain(Object name) {
    return 'A usar $name';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name continua a transferir: Definições › Companheiros';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return 'A transferir · $percent%';
  }

  @override
  String get companionInstallPause => 'Pausar';

  @override
  String get companionInstallResume => 'Retomar';

  @override
  String get companionInstallDiscard => 'Descartar';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return 'Em pausa · $received de $total';
  }

  @override
  String get companionInstallFailedIntegrity =>
      'O ficheiro transferido não corresponde ao que esta versão espera. A começar de novo.';

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
    return '$name em pausa · $received de $total';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return 'O $name está a acordar…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => 'Traduzir de novo';

  @override
  String get groupCallScreenShareLabel => 'Partilhar';

  @override
  String get groupCallScreenStopShareLabel => 'Parar partilha';

  @override
  String get groupCallScreenShareStartingLabel => 'Iniciando…';

  @override
  String get groupCallScreenRingingLabel => 'A chamar…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name está a partilhar o ecrã';
  }

  @override
  String get groupCallScreenYouAreSharing => 'Está a partilhar o seu ecrã';

  @override
  String get groupCallScreenMinimizeLabel => 'Ocultar';

  @override
  String get groupCallScreenDrawLabel => 'Desenhar';

  @override
  String get callScreenControlShare => 'Partilhar';

  @override
  String get callScreenControlStopShare => 'Parar';

  @override
  String get callScreenControlShareStarting => 'Iniciando…';

  @override
  String get screenShareStopDrawing => 'Parar de desenhar';

  @override
  String get screenShareDrawBoardIdle => 'Os desenhos aparecem aqui';

  @override
  String get screenShareOverlayHint =>
      'Mostra os desenhos sobre outras apps enquanto partilhas';

  @override
  String get screenShareOverlayAllow => 'Permitir';

  @override
  String get callScreenControlDraw => 'Desenhar';

  @override
  String get callScreenControlMinimize => 'Ocultar';

  @override
  String get inCallPillOngoingCall => 'Chamada em curso';

  @override
  String get inCallPillReturn => 'Voltar';

  @override
  String get inCallPillSharing => 'A partilhar o seu ecrã';

  @override
  String get inCallPillDrawSemanticLabel => 'Desenhar no ecrã partilhado';

  @override
  String get inCallPillStopSharingSemanticLabel => 'Parar de partilhar';

  @override
  String get screenShareUnsupported =>
      'A partilha de ecrã não está disponível neste dispositivo';

  @override
  String get screenShareEphemeralWarning =>
      'A proteção contra capturas fica desligada enquanto partilha';

  @override
  String get screenShareNotificationTitle => 'A partilhar o seu ecrã';

  @override
  String get screenShareNotificationBody => 'Todos na chamada podem vê-lo';

  @override
  String get screenShareNotificationStop => 'Parar';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name já está a partilhar';
  }

  @override
  String get screenShareFailed => 'Não foi possível começar a partilhar';

  @override
  String get screenSharePickerTitle => 'Partilhe o seu ecrã';

  @override
  String get screenSharePickerScreens => 'Ecrãs';

  @override
  String get screenSharePickerWindows => 'Janelas';

  @override
  String get screenSharePickerEmpty =>
      'Ainda nada para partilhar. Permita a gravação do ecrã nas Definições do Sistema e tente de novo';

  @override
  String get gameTellFriends => 'Avisar os amigos';

  @override
  String get gameToldFriends => 'Já sabem';

  @override
  String get gameTellFriendsTitle => 'Avisar os teus amigos?';

  @override
  String get gameTellFriendsBody =>
      'recebem uma notificação com este resultado. só pode ser enviado uma vez.';

  @override
  String get gameTellFriendsCancel => 'Agora não';

  @override
  String get gameTellFriendsConfirm => 'Enviar';

  @override
  String get gameTellFriendsSent => 'Enviado. Já sabem';

  @override
  String get gameTellFriendsPrivate =>
      'Os teus resultados diários são privados, ninguém veria isto';

  @override
  String get gameTellFriendsFailed => 'Não foi possível enviar';

  @override
  String get settingsScreenFriendActivityLabel => 'ATIVIDADE DOS AMIGOS';

  @override
  String get settingsScreenFriendActivityOnBody =>
      'momentos, pontos e resultados à medida que publicam';

  @override
  String get settingsScreenFriendActivityOffBody =>
      'nada, os quadros deles continuam lá quando olhares';

  @override
  String get searchScreenActionWithGrownUp => 'Com um grande';

  @override
  String get newChatMenuSearchHint => 'Procura nos teus amigos';

  @override
  String get newChatMenuNoFriendsYet =>
      'Ainda sem amigos. Encontra pessoas em Descobrir';

  @override
  String get newChatMenuNoFriendsMatch => 'Nenhum amigo corresponde';

  @override
  String get newChatMenuOpenDmFailed =>
      'Não foi possível abrir esse chat. Tenta de novo';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'Escolher das tuas pessoas';

  @override
  String get childPolicyScreenPickPersonHint =>
      'Procura um nome ou nome de utilizador';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'Já não há ninguém para adicionar dos teus amigos.\\nProcura outra pessoa';

  @override
  String get childPolicyScreenPickPersonNoMatch => 'Ninguém corresponde';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'Os teus amigos';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'Todos os outros';

  @override
  String get childPolicyScreenAddRoomLabel => 'Adicionar uma sala';

  @override
  String get childPolicyScreenPickRoomHeading => 'Adicionar uma sala';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'Uma das tuas próprias salas. $name entra já e pode ler e escrever lá até lhe retirares.';
  }

  @override
  String get childPolicyScreenPickRoomHint => 'Procura nas tuas salas';

  @override
  String get childPolicyScreenPickRoomEmpty =>
      'Não te restam salas para adicionar';

  @override
  String get childPolicyScreenPickRoomNoMatch => 'Nenhuma sala corresponde';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name já está em $room';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'Não foi possível adicionar essa sala. Tenta de novo';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'Essa sala não pode ser adicionada assim';

  @override
  String get childPolicyScreenErrorRoomGone => 'Essa sala já não existe';

  @override
  String get newChatMenuFriendsHeader => 'Amigos';

  @override
  String get roomChangeErrorGone =>
      'Essa sugestão já não existe. Um admin pode tê-la respondido.';

  @override
  String get roomChangeErrorNotYours => 'Só quem sugeriu pode retirá-la.';

  @override
  String get roomChangeErrorNoChange => 'Já é isso que está escrito.';

  @override
  String get roomChangeErrorMissingValue => 'Assim não dá para guardar.';

  @override
  String get roomChangeRequestsTitle => 'Sugestões';

  @override
  String get roomChangeRequestsBlurb =>
      'Foram os membros que sugeriram. Nada muda até dizeres que sim.';

  @override
  String get roomChangeRequestsEmpty => 'Não há sugestões.';

  @override
  String get roomChangeRequestsApprove => 'USAR';

  @override
  String get roomChangeRequestsReject => 'NÃO';

  @override
  String get roomChangeRequestsPhotoLabel => 'Nova foto do grupo';

  @override
  String get roomChangeRequestsNameLabel => 'Novo nome';

  @override
  String get roomChangeRequestsDescriptionLabel => 'Nova descrição';

  @override
  String get roomChangeRequestsUnknownLabel =>
      'Uma alteração que esta app ainda não sabe mostrar';

  @override
  String get roomChangeRequestsClearedValue => 'Nada, tirar';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name sugeriu';
  }

  @override
  String get roomAdminChangeRequestsRow => 'Sugestões';

  @override
  String get roomInfoScreenSuggestNote =>
      'Isto tem de ser aprovado por um admin';

  @override
  String get roomInfoScreenSuggestAvatarNote =>
      'As fotos novas são aprovadas por um admin';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic =>
      'Sugerir uma foto do grupo';

  @override
  String get roomInfoScreenSuggestionSentToast => 'Enviado aos admins';

  @override
  String get roomInfoScreenSuggestionAppliedToast =>
      'Pronto, podes editar este grupo';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => 'Retirado';

  @override
  String get roomInfoScreenSuggestionsLabel => 'SUGERISTE';

  @override
  String get roomInfoScreenSuggestionPhoto => 'Uma foto nova do grupo';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return 'Nome: $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return 'Descrição: $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => 'Uma alteração';

  @override
  String get roomInfoScreenSuggestionPending => 'À espera de um admin';

  @override
  String get roomInfoScreenSuggestionWithdraw => 'Retirar';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name sugeriu uma nova foto do grupo';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name sugeriu um novo nome';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name sugeriu uma nova descrição';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sugestões à tua espera',
      one: '$count sugestão à tua espera',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => 'Rever';

  @override
  String get roomSuggestionBannerSemantic =>
      'Sugestões de membros à espera da tua revisão';

  @override
  String get gameInfoPlay => 'Jogar';

  @override
  String get gameInfoContinue => 'Continuar';

  @override
  String get gameInfoSeeResult => 'Ver o teu resultado';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return 'Entregue a $delivered de $total';
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
    return '$name recebeu isto $deliveredDay às $deliveredTime e leu $readDay às $readTime';
  }

  @override
  String get messageReceiptsStampRead => 'Lida';

  @override
  String get messageReceiptsStampDelivered => 'Entregue';

  @override
  String get roomInviteCustom => 'Outro';

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
      other: '$count dias',
      one: '$count dia',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utilizações',
      one: '$count utilização',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => 'Horas';

  @override
  String get roomInviteUnitDays => 'Dias';

  @override
  String get roomInviteStepperIncrease => 'Aumentar';

  @override
  String get roomInviteStepperDecrease => 'Diminuir';

  @override
  String get recordsLabel => 'Recordes';

  @override
  String get recordsBlurb => 'O melhor de sempre: tu e os teus amigos';

  @override
  String recordsYourBest(Object value) {
    return 'O teu $value';
  }

  @override
  String get recordsNoneYet => 'Ninguém ainda';

  @override
  String get recordsEmpty =>
      'Resolve qualquer jogo e o teu melhor resultado aparece aqui.';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resolvidos',
      one: '$count resolvido',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return 'Feito a $date';
  }

  @override
  String recordsReactSemantic(Object name) {
    return 'Reagir ao recorde de $name';
  }

  @override
  String get recordsReactFailed => 'Não foi possível reagir';

  @override
  String get recordsLoadFailed => 'Não foi possível carregar os recordes';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game: recorde de $value por $name';
  }

  @override
  String get appearanceLabel => 'Aparência';

  @override
  String get appearanceMatchDevice => 'Como o dispositivo';

  @override
  String get appearanceMatchDeviceSub =>
      'Claro de dia, escuro à noite, como o teu telemóvel';

  @override
  String get appearanceOneTheme => 'Um só tema';

  @override
  String get appearanceOneThemeSub => 'O mesmo visual o dia todo';

  @override
  String get appearanceLightSlot => 'Modo claro';

  @override
  String get appearanceDarkSlot => 'Modo escuro';

  @override
  String get appearanceNow => 'Agora';

  @override
  String appearanceAutoValue(Object name) {
    return 'Auto · $name';
  }

  @override
  String get themeScreenAssignHint =>
      'toca num tema para o usar no modo claro ou escuro · ⛶ para pré-visualizar';

  @override
  String get themeScreenCarouselUseLight => 'USAR NO MODO CLARO';

  @override
  String get themeScreenCarouselUseDark => 'USAR NO MODO ESCURO';

  @override
  String get themeScreenCarouselIsLight => 'O TEU TEMA CLARO';

  @override
  String get themeScreenCarouselIsDark => 'O TEU TEMA ESCURO';

  @override
  String get onboardingThemeTitle => 'à tua maneira.';

  @override
  String get onboardingThemeBody =>
      'escolhe um visual. podes mudá-lo quando quiseres nas definições.';

  @override
  String get onboardingThemeYourTheme => 'O TEU TEMA';

  @override
  String get onboardingThemeContinue => 'CONTINUAR';

  @override
  String get dropHintNoTarget => 'Largue numa conversa para enviar';

  @override
  String get dropNothingToSend => 'Nada aqui pode ser enviado';

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
      other: 'Enviar $count áudios',
      one: 'Enviar áudio',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar $count ficheiros',
      one: 'Enviar ficheiro',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar $count itens',
      one: 'Enviar item',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => 'Adicionar à mensagem';

  @override
  String get dropSendLink => 'Adicionar ligação';

  @override
  String dropTargetTo(String name) {
    return 'Para $name';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ficheiros passam de $size',
      one: '1 ficheiro passa de $size',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => 'Não é possível enviar pastas';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A ignorar $count ficheiros vazios',
      one: 'A ignorar um ficheiro vazio',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => 'Não são permitidos anexos aqui';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seguem como ficheiros',
      one: 'Segue como ficheiro',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podem não aparecer em todo o lado',
      one: 'Pode não aparecer em todo o lado',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => 'foto';

  @override
  String get dropKindVideo => 'vídeo';

  @override
  String get dropKindAudio => 'áudio';

  @override
  String get dropKindFile => 'ficheiro';

  @override
  String get dropKindFolder => 'pasta';

  @override
  String get dropKindText => 'texto';

  @override
  String get dropKindLink => 'ligação';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ficheiros não couberam neste envio',
      one: '1 ficheiro não coube neste envio',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed =>
      'Não foi possível fazer isso. Tenta de novo.';

  @override
  String get expressionBackspace => 'Apagar';

  @override
  String get expressionCreateSticker => 'Criar um sticker';

  @override
  String get expressionDeleteSticker => 'Eliminar dos meus stickers';

  @override
  String get expressionFavorite => 'Adicionar aos favoritos';

  @override
  String get expressionFavorited => 'Adicionado aos favoritos';

  @override
  String get expressionFavorites => 'Favoritos';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF: $title';
  }

  @override
  String get expressionLoadFailed =>
      'Não foi possível carregar. Verifica a tua ligação.';

  @override
  String get expressionMediaNotAllowed =>
      'As definições da tua família não permitem enviar imagens.';

  @override
  String get expressionMyStickers => 'Os meus stickers';

  @override
  String get expressionNoFavorites =>
      'Mantém premido um GIF ou sticker para o adicionares aos favoritos.';

  @override
  String get expressionNoRecents =>
      'Os GIFs e stickers que enviares vão aparecer aqui.';

  @override
  String get expressionNoResults => 'Sem resultados';

  @override
  String get expressionNoStickers => 'Ainda não há stickers aqui.';

  @override
  String get expressionOpenPanel => 'Emojis, GIFs e stickers';

  @override
  String get expressionOptionsHint => 'Mostrar opções';

  @override
  String expressionPackCredit(String author, String license) {
    return 'Arte: $author · $license';
  }

  @override
  String get expressionPlayGifHint => 'reproduzir';

  @override
  String get expressionRecent => 'Recentes';

  @override
  String get expressionReport => 'Denunciar';

  @override
  String get expressionReported => 'Obrigado, foi denunciado.';

  @override
  String get expressionRetry => 'Tentar de novo';

  @override
  String get expressionSearchKlipy => 'Pesquisar no KLIPY';

  @override
  String get expressionShowKeyboard => 'Mostrar teclado';

  @override
  String get expressionSuggestionsLabel => 'Sugestões de stickers';

  @override
  String get expressionTabEmoji => 'Emojis';

  @override
  String get expressionTabGifs => 'GIFs';

  @override
  String get expressionTabStickers => 'Stickers';

  @override
  String get expressionTrending => 'Em destaque';

  @override
  String get expressionUnfavorite => 'Remover dos favoritos';

  @override
  String get expressionUnfavorited => 'Removido dos favoritos';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return 'Sticker $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel =>
      'Reproduzir GIFs e stickers automaticamente';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      'Ficam parados até tocares num. Poupa dados.';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'Os GIFs e stickers animados reproduzem-se sozinhos. Reduzir movimento põe-nos em pausa.';

  @override
  String get settingsAlbumCardsLabel => 'Álbuns de fotos como cartões';

  @override
  String get settingsAlbumCardsOffBody =>
      'Várias fotos numa mensagem aparecem em grelha.';

  @override
  String get settingsAlbumCardsOnBody =>
      'Várias fotos numa mensagem aparecem numa pilha que percorre a deslizar.';

  @override
  String get settingsStickerSuggestionsBody =>
      'Escrever um único emoji mostra stickers correspondentes acima do campo de mensagem.';

  @override
  String get settingsStickerSuggestionsLabel => 'Sugestões de stickers';

  @override
  String get stickerMakerEmojiLabel => 'Que emoji é?';

  @override
  String get stickerMakerFailed =>
      'Não foi possível guardar o sticker. Tenta de novo.';

  @override
  String get stickerMakerMoreEmoji => 'Mais emojis';

  @override
  String get stickerMakerPreview => 'Pré-visualização do sticker';

  @override
  String get stickerMakerRemoveBackground => 'Remover fundo';

  @override
  String get stickerMakerSave => 'Guardar';

  @override
  String get stickerMakerSaved => 'Sticker adicionado a Os meus stickers';

  @override
  String get stickerMakerShape => 'Forma';

  @override
  String get stickerMakerShapeCircle => 'Círculo';

  @override
  String get stickerMakerShapeOriginal => 'Original';

  @override
  String get stickerMakerShapeRounded => 'Quadrado arredondado';

  @override
  String get stickerMakerTitle => 'Novo sticker';

  @override
  String get stickerMakerTooMany =>
      'Chegaste ao limite de stickers. Elimina um para libertar espaço.';

  @override
  String get expressionExpandPanel => 'Expandir painel';

  @override
  String get expressionCollapsePanel => 'Reduzir painel';

  @override
  String get expressionPackStore => 'Packs de stickers';

  @override
  String get expressionPackSearchHint => 'Pesquisar packs de stickers';

  @override
  String get expressionPacksAdded => 'Adicionados';

  @override
  String get expressionPacksMore => 'Mais packs';

  @override
  String get expressionPackAdd => 'Adicionar';

  @override
  String get expressionPackRemove => 'Remover';

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
  String get expressionNoPacksFound => 'Nenhum pack encontrado';

  @override
  String get expressionAllPacksAdded => 'Já adicionaste todos os packs.';

  @override
  String expressionPackReorder(String title) {
    return 'Reordenar $title';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return 'Adicionar o pack «$title»';
  }

  @override
  String expressionPackAddedToast(String title) {
    return '«$title» adicionado aos teus stickers';
  }

  @override
  String get expressionPacksFromKlipy => 'Mais stickers do KLIPY';

  @override
  String expressionSearchKlipyFor(String query) {
    return 'Pesquisar «$query» no KLIPY';
  }

  @override
  String get expressionHideKeyboard => 'Ocultar teclado';

  @override
  String get expressionSearchStickers => 'Pesquisar stickers';

  @override
  String get expressionYourStickers => 'Os seus stickers';

  @override
  String get chatListYesterday => 'Ontem';

  @override
  String get roomLayoutScreenCardsLayoutLabel => 'CARTÕES';

  @override
  String get roomLayoutScreenCardsLayoutDescription =>
      'cada sala no seu próprio cartão, com todos os detalhes.';

  @override
  String get homeScreenTitle => 'Conversas';

  @override
  String get glassScreenNativeLabel => 'Liquid Glass do iOS';

  @override
  String get glassScreenNativeOnBody =>
      'A barra de separadores é desenhada pelo próprio iOS. Os controlos abaixo ajustam o resto da app.';

  @override
  String get glassScreenNativeOffBody =>
      'O MonkeyHub desenha o seu próprio vidro em todo o lado, ajustado pelos controlos abaixo.';

  @override
  String get glassScreenHeading => 'Vidro';

  @override
  String get glassStyleHeader => 'Estilo';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody =>
      'O vidro da própria Apple, desenhado pelo iOS. Os botões da app acompanham-no.';

  @override
  String get glassStyleFrostedTitle => 'Fosco';

  @override
  String get glassStyleFrostedBody =>
      'O vidro do próprio MonkeyHub. Ajuste cada controlo à sua maneira.';

  @override
  String get glassStyleRecommended => 'Recomendado';

  @override
  String get glassStyleLiquidFooter =>
      'Nada para ajustar: o iOS define o desfoque, a tonalidade e a luz. Escolha Fosco para moldar o vidro.';

  @override
  String get acctSectionPrivacy => 'Privacidade';

  @override
  String get acctSectionAccount => 'Conta';

  @override
  String get acctSectionFamily => 'Família';

  @override
  String get acctSectionThisPhone => 'Este telemóvel';

  @override
  String get acctRowVisibility => 'Visibilidade do perfil';

  @override
  String get acctRowBlocked => 'Utilizadores bloqueados';

  @override
  String get acctRowApprovals => 'Aprovações';

  @override
  String get acctNothingWaiting => 'Nada pendente';

  @override
  String get acctRowLinked => 'Contas associadas';

  @override
  String get acctRowScanToSignIn => 'Ler para iniciar sessão';

  @override
  String get acctRowSetUpRecovery => 'Configurar frase de recuperação';

  @override
  String get acctRowChangeRecovery => 'Alterar frase de recuperação';

  @override
  String get acctSignOut => 'Terminar sessão';

  @override
  String get acctDeleteAccount => 'Eliminar conta';

  @override
  String get acctConfirmDelete => 'Toque novamente para eliminar';

  @override
  String get acctHandPhoneBack => 'Devolver este telemóvel';

  @override
  String get acctMyGrownUps => 'Os meus responsáveis';

  @override
  String get acctActionMessage => 'Mensagem';

  @override
  String get acctActionAddFriend => 'Adicionar';

  @override
  String get acctActionRequested => 'Pedido';

  @override
  String get acctActionAccept => 'Aceitar';

  @override
  String get acctActionNotAccepting => 'Fechado';

  @override
  String get acctActionUnfriend => 'Remover';

  @override
  String get acctActionBlock => 'Bloquear';

  @override
  String get acctActionReport => 'Denunciar';

  @override
  String get acctStatusFriends => 'São amigos';

  @override
  String get acctStatusRequestSent => 'Pedido enviado';

  @override
  String get acctStatusWantsToConnect => 'Quer ser seu amigo';

  @override
  String get acctStatusNotConnected => 'Sem ligação';

  @override
  String get acctPresenceOnline => 'Online';

  @override
  String get acctPresenceAway => 'Ausente';

  @override
  String get acctPresenceOffline => 'Offline';

  @override
  String get acctProfilePhoto => 'Fotografia de perfil';

  @override
  String get acctSaveToPhotos => 'Guardar em Fotografias';

  @override
  String get acctTakeSelfie => 'Tirar uma selfie';

  @override
  String get acctChooseFromLibrary => 'Escolher da biblioteca';

  @override
  String get acctCancel => 'Cancelar';

  @override
  String get acctSave => 'Guardar';

  @override
  String get acctChange => 'Alterar';

  @override
  String get acctNotNow => 'Agora não';

  @override
  String get acctAddEmail => 'Adicionar e-mail';

  @override
  String get acctEditNameTitle => 'Editar nome';

  @override
  String get acctAddNameTitle => 'Adicione o seu nome';

  @override
  String get acctEditEmailTitle => 'Editar e-mail';

  @override
  String get acctChangeUsernameTitle => 'Alterar nome de utilizador?';

  @override
  String get onboardingLookTitle => 'À sua maneira';

  @override
  String get onboardingLookBody =>
      'Escolha um visual. Pode alterá-lo a qualquer momento nas Definições.';

  @override
  String get onboardingEssentials => 'Essenciais';

  @override
  String get onboardingEssentialsSub => 'Sóbrios e nativos';

  @override
  String get onboardingCharacters => 'Com personalidade';

  @override
  String get onboardingCharactersSub => 'A mesma app, mais personalidade';

  @override
  String get onboardingLightMode => 'Modo claro';

  @override
  String get onboardingDarkMode => 'Modo escuro';

  @override
  String get onboardingNow => 'Agora';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingIconTitle => 'O seu ícone da app';

  @override
  String get onboardingIconBody =>
      'Mantenha o seu ícone, deixe-o acompanhar o tema ou escolha outro qualquer.';

  @override
  String get onboardingIconIosNote =>
      'O iOS mostra um aviso breve sempre que o ícone muda.';

  @override
  String get onboardingGetStarted => 'Começar';

  @override
  String get appIconMatchTheme => 'Seguir o tema';

  @override
  String get appIconCurrent => 'Atual';

  @override
  String get appIconSectionCollection => 'Coleção MonkeyHub';

  @override
  String get appIconSectionThemes => 'Ícones dos temas';

  @override
  String get appIconScreenTitle => 'Ícone da app';

  @override
  String get appIconMatchFooter =>
      'Seguir o tema muda o ícone com o seu tema escuro, para não estar sempre a alternar ao longo do dia.';

  @override
  String get loginTitleReturning => 'Bem-vindo de volta';

  @override
  String get loginTitleFirst => 'Bem-vindo ao MonkeyHub';

  @override
  String get loginTitleSignUp => 'Crie a sua conta';

  @override
  String get loginTitleReset => 'Reponha a sua palavra-passe';

  @override
  String get loginSubtitleSignIn => 'Inicie sessão para continuar onde ficou.';

  @override
  String get loginSubtitleFirst =>
      'Inicie sessão ou crie uma conta em segundos.';

  @override
  String get loginSubtitleSignUp =>
      'Só precisa de um nome de utilizador e uma palavra-passe.';

  @override
  String get loginSubtitleReset =>
      'Introduza a sua frase de recuperação de 12 palavras e escolha uma nova palavra-passe.';

  @override
  String get loginCtaSignIn => 'Iniciar sessão';

  @override
  String get loginCtaSignUp => 'Criar conta';

  @override
  String get loginCtaReset => 'Repor palavra-passe';

  @override
  String get loginNoAccountPrompt => 'É novo? ';

  @override
  String get loginCreateAccountLink => 'Criar uma conta';

  @override
  String get loginHaveAccountPrompt => 'Já tem conta? ';

  @override
  String get loginSignInLink => 'Iniciar sessão';

  @override
  String get loginForgotPassword => 'Esqueceu-se da palavra-passe?';

  @override
  String get loginChildAccount => 'Configurar conta de criança';

  @override
  String get loginBackToSignIn => 'Voltar ao início de sessão';

  @override
  String get loginWithPhone => 'Iniciar sessão com o telemóvel';

  @override
  String get loginUsernameField => 'Nome de utilizador';

  @override
  String get loginPasswordField => 'Palavra-passe';

  @override
  String get loginConfirmPasswordField => 'Confirmar palavra-passe';

  @override
  String get loginNameField => 'Nome (opcional)';

  @override
  String get loginRecoveryPhraseField =>
      'A sua frase de recuperação de 12 palavras';

  @override
  String get loginNewPasswordField => 'Nova palavra-passe';

  @override
  String get roomHeaderStatusOnline => 'Online';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '$count membro',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => 'Definições';

  @override
  String get settingsHubAccountHintAdult =>
      'Perfil, família, contas associadas e privacidade';

  @override
  String get settingsHubAccountHintChild =>
      'Perfil, privacidade e os teus adultos';

  @override
  String get settingsHubSectionGeneral => 'Geral';

  @override
  String get settingsHubSectionNotifications => 'Notificações';

  @override
  String get settingsHubSectionCalls => 'Chamadas';

  @override
  String get settingsHubSectionAppearance => 'Aspeto';

  @override
  String get settingsHubSectionCompanions => 'Companheiros';

  @override
  String get settingsHubSectionChats => 'Conversas';

  @override
  String get settingsHubSectionHelp => 'Ajuda e informações legais';

  @override
  String get settingsHubSectionAdvanced => 'Avançado';

  @override
  String get settingsHubLanguage => 'Idioma';

  @override
  String get settingsHubCheckForUpdates => 'Procurar atualizações';

  @override
  String get settingsHubUpdateAvailable => 'Atualização disponível';

  @override
  String get settingsHubShowLinkUrls => 'Mostrar endereços das ligações';

  @override
  String get settingsHubShowLinkUrlsSubtitle =>
      'Mostra o endereço junto de cada pré-visualização';

  @override
  String get settingsHubPresenceDots => 'Mostrar quem está online';

  @override
  String get settingsHubPresenceDotsSubtitle =>
      'O ponto nas fotografias de perfil';

  @override
  String get settingsHubPush => 'Notificações push';

  @override
  String get settingsHubPushSubtitle => 'Novas mensagens, chamadas e pedidos';

  @override
  String get settingsHubGameReminders => 'Lembrete diário de jogo';

  @override
  String get settingsHubGameRemindersSubtitle =>
      'Um lembrete à hora de almoço se ainda não jogaste';

  @override
  String get settingsHubFriendActivity => 'Atividade de amigos';

  @override
  String get settingsHubFriendActivitySubtitle =>
      'Destaques, pontos e resultados de amigos';

  @override
  String get settingsHubMenuBar => 'Ícone na barra de menus';

  @override
  String get settingsHubMenuBarSubtitle =>
      'Mostra as não lidas na barra de menus';

  @override
  String get settingsHubCallStats => 'Mostrar estatísticas da chamada';

  @override
  String get settingsHubCallStatsSubtitle =>
      'Resolução, taxa de bits e ping nas chamadas';

  @override
  String get settingsHubTheme => 'Tema';

  @override
  String get settingsHubAppIcon => 'Ícone da app';

  @override
  String get settingsHubGlass => 'Vidro';

  @override
  String get settingsHubNavigation => 'Navegação';

  @override
  String get settingsHubMotion => 'Movimento';

  @override
  String get settingsHubChatList => 'Lista de conversas';

  @override
  String get settingsHubChatStyle => 'Estilo da conversa';

  @override
  String get settingsHubBubbleStyle => 'Estilo dos balões';

  @override
  String get settingsHubSpeakerColors => 'Cores por pessoa';

  @override
  String get settingsHubReplyStyle => 'Estilo das respostas';

  @override
  String get settingsHubPrivacyPolicy => 'Política de privacidade';

  @override
  String get settingsHubTerms => 'Termos de serviço';

  @override
  String get settingsHubLicence => 'Licença';

  @override
  String get settingsHubServer => 'Servidor';

  @override
  String get settingsHubLayoutRows => 'Linhas';

  @override
  String get settingsHubLayoutCards => 'Cartões';

  @override
  String get settingsHubLayoutGrid => 'Grelha';

  @override
  String get settingsHubNavTabBar => 'Barra de separadores';

  @override
  String settingsHubThemeAuto(String name) {
    return 'Automático · $name';
  }

  @override
  String get chatListPageRowsSub =>
      'Um rosto, um nome e a última mensagem, como no Mensagens.';

  @override
  String get chatListPageCardsSub =>
      'Cada sala no seu próprio cartão, com todos os detalhes.';

  @override
  String get chatListPageGridSub =>
      'Duas colunas de mosaicos. Mais salas num relance.';

  @override
  String get chatListPageLayoutHeader => 'Esquema';

  @override
  String get chatListPageFiltersHeader => 'Filtros';

  @override
  String get chatListPageChips => 'Etiquetas';

  @override
  String get chatListPageChipsSub => 'Uma fila de filtros, sempre a um toque.';

  @override
  String get chatListPageButton => 'Botão';

  @override
  String get chatListPageButtonSub =>
      'Um botão que abre os filtros quando quiseres.';

  @override
  String get chatListPageEmptyHeader => 'Salas vazias';

  @override
  String get chatListPagePlain => 'Simples';

  @override
  String get chatListPagePlainSub => 'Uma sala sem mensagens fica limpa.';

  @override
  String get chatListPageInitial => 'Inicial';

  @override
  String get chatListPageInitialSub =>
      'Uma letra grande e suave preenche o canto vazio.';

  @override
  String get chatListPageEmptyFooter => 'Aplica-se ao esquema em grelha.';

  @override
  String get chatStylePageFooter =>
      'Como o cabeçalho e o campo de mensagem aparecem.';

  @override
  String get chatStyleClassicSub =>
      'Cabeçalho sólido e campo de mensagem plano.';

  @override
  String get chatStyleCompactSub =>
      'Controlos foscos flutuam sobre a conversa.';

  @override
  String get bubbleTailedSub =>
      'Uma cauda na última mensagem de cada sequência, como no Mensagens.';

  @override
  String get bubbleSoftSub => 'Sem cauda. A sequência une-se pelos cantos.';

  @override
  String get bubblePillSub =>
      'Cápsulas totalmente arredondadas em cada mensagem.';

  @override
  String get bubbleSlabSub => 'Cantos retos: nítidos e decididos.';

  @override
  String get replyStylePageFooter =>
      'Como uma resposta mostra a mensagem a que responde.';

  @override
  String get replyClassicSub =>
      'Uma citação colorida acima da mensagem, estilo WhatsApp.';

  @override
  String get replyPhantomSub =>
      'Um fantasma do original flutua acima, ligado por uma curva.';

  @override
  String get replyStickySub => 'Um pequeno cartão inclinado preso ao canto.';

  @override
  String get replyComicSub => 'Um mini balão com cauda de banda desenhada.';

  @override
  String get motionMatchDevice => 'Igual ao dispositivo';

  @override
  String get motionMatchDeviceCalmSub =>
      'O teu dispositivo está a pedir menos movimento.';

  @override
  String get motionMatchDeviceFullSub => 'O teu dispositivo permite animações.';

  @override
  String get motionFullSub => 'Cada mola, deriva e floreado.';

  @override
  String get motionCalmSub =>
      'A decoração fica parada. O resto funciona igual.';

  @override
  String get navigationPageFooter =>
      'Como navegas entre Conversas, Feed, Descobrir e Definições.';

  @override
  String get navTabBarSub => 'Sempre visível, um toque para qualquer lado.';

  @override
  String get navOrbSub =>
      'Mantém e arrasta a partir do canto. Um gesto que se aprende.';

  @override
  String get languageSystemLabel => 'Idioma do dispositivo';

  @override
  String get languagePageFooter =>
      'Menus e mensagens da app. As conversas ficam na língua em que forem escritas.';

  @override
  String get speakerPageFooter =>
      'Percebe quem está a falar num relance nos grupos.';

  @override
  String get speakerOffSub => 'Todos escrevem com a mesma tinta.';

  @override
  String get speakerNamesSub => 'Cada pessoa tem uma cor no nome e na foto.';

  @override
  String get speakerBubblesSub => 'A cor também passa para as mensagens.';

  @override
  String get themePageAutoFooter =>
      'Os temas claros são usados no modo claro, os escuros no modo escuro.';

  @override
  String get themePageLightMode => 'Modo claro';

  @override
  String get themePageDarkMode => 'Modo escuro';

  @override
  String get themePageEssentials => 'Essenciais';

  @override
  String get themePageEssentialsFooter => 'Calmos e nativos, em cinco cores.';

  @override
  String get themePageCharacters => 'Com personalidade';

  @override
  String get themePageCharactersFooter =>
      'O mesmo esquema, com personalidade própria. Mantém premido um tema para ver.';

  @override
  String get themePageLightBadge => 'Claro';

  @override
  String get themePageDarkBadge => 'Escuro';

  @override
  String get themePageInUse => 'Em uso';

  @override
  String get themePageUseLight => 'Usar no modo claro';

  @override
  String get themePageUseDark => 'Usar no modo escuro';

  @override
  String themePageUse(String name) {
    return 'Usar $name';
  }

  @override
  String get acctCaptureTitle => 'Proteção contra captura de ecrã';

  @override
  String get acctCaptureOnIos =>
      'Gravações e espelhamento mostram uma proteção de privacidade.';

  @override
  String get acctCaptureOnAndroid => 'Capturas e gravações ficam pretas.';

  @override
  String get acctCaptureOff => 'Capturas e gravações funcionam normalmente.';

  @override
  String get acctCaptureFooter =>
      'Salas com mensagens temporárias ativam isto sempre.';

  @override
  String get acctActionPending => 'Pendente';

  @override
  String get chatSwipePin => 'Fixar';

  @override
  String get chatSwipeUnpin => 'Desafixar';

  @override
  String get chatSwipeMute => 'Silenciar';

  @override
  String get chatSwipeUnmute => 'Reativar';

  @override
  String get chatSwipeArchive => 'Arquivar';

  @override
  String get appearanceMatchDeviceSubtitle =>
      'Claro de dia e escuro à noite, como o seu telemóvel';

  @override
  String get appearanceOneThemeSubtitle => 'O mesmo visual o dia todo';

  @override
  String get riName => 'Nome';

  @override
  String get riDescription => 'Descrição';

  @override
  String get riVisibility => 'Quem a pode encontrar';

  @override
  String get riPublic => 'Pública';

  @override
  String get riPublicSub => 'Qualquer pessoa a pode encontrar em Descobrir';

  @override
  String get riPrivate => 'Privada';

  @override
  String get riPrivateSub => 'Só quem convidar pode entrar';

  @override
  String get riMessageLife => 'As mensagens desaparecem após';

  @override
  String get riPassword => 'Palavra-passe';

  @override
  String get riRemovePassword => 'Remover palavra-passe';

  @override
  String get riSetPassword => 'Definir palavra-passe';

  @override
  String get riSharedContent => 'Conteúdo partilhado';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '1 membro',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convidados',
      one: '1 convidado',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => 'Retirar';

  @override
  String get riNotifications => 'Notificações';

  @override
  String get riTranslation => 'Tradução';

  @override
  String get riNameColours => 'Cores dos nomes';

  @override
  String get riYouSuggested => 'Sugeriu';

  @override
  String get riTakeBack => 'Retirar';

  @override
  String get riLeaveRoom => 'Sair da sala';

  @override
  String get riLeaving => 'A sair…';

  @override
  String get riDeleteRoom => 'Eliminar sala';

  @override
  String get riDeleting => 'A eliminar…';

  @override
  String get riEndConversation => 'Terminar conversa';

  @override
  String get riEnding => 'A terminar…';

  @override
  String get riActionCall => 'Ligar';

  @override
  String get riActionVideo => 'Vídeo';

  @override
  String get riActionMute => 'Silenciar';

  @override
  String get riActionUnmute => 'Ativar som';

  @override
  String get riActionMedia => 'Multimédia';

  @override
  String get riActionAdd => 'Adicionar';

  @override
  String get roomHeaderStatusTyping => 'A escrever…';

  @override
  String get glassScreenLead => 'Quanto do que está atrás se vê.';

  @override
  String get transcriptDayToday => 'Hoje';

  @override
  String get acctRowDevices => 'Dispositivos';

  @override
  String get acctThisDevice => 'Este dispositivo';

  @override
  String get acctRemove => 'Remover';

  @override
  String get acctRemoveDeviceTitle => 'Remover este dispositivo?';

  @override
  String get acctRemoveAllTitle => 'Remover todos os outros dispositivos?';

  @override
  String get acctRemoveAll => 'Remover todos';

  @override
  String get acctActiveNow => 'Ativo agora';

  @override
  String get acctLoading => 'A carregar…';

  @override
  String get acctDevicesLoadFailed =>
      'Não foi possível carregar os seus dispositivos.';

  @override
  String get acctNoNotifications => 'As notificações não chegam a este';

  @override
  String get acctBlockedEmpty => 'Não bloqueou ninguém.';

  @override
  String get acctUnblock => 'Desbloquear';

  @override
  String get pvSubtitle =>
      'Controle o que os outros veem e como o podem contactar.';

  @override
  String get pvSectionProfile => 'Perfil';

  @override
  String get pvSectionMessages => 'Mensagens';

  @override
  String get pvSectionPeople => 'Pessoas';

  @override
  String get pvSectionFeed => 'Feed';

  @override
  String get pvAvatar => 'Fotografia de perfil';

  @override
  String get pvAvatarDesc => 'Quem pode ver a sua fotografia';

  @override
  String get pvOnline => 'Estado online';

  @override
  String get pvOnlineDesc => 'Se aparece ativo agora';

  @override
  String get pvLastSeen => 'Visto pela última vez';

  @override
  String get pvLastSeenDesc => 'Quando esteve por cá pela última vez';

  @override
  String get pvSendReceipts => 'Enviar confirmações de leitura';

  @override
  String get pvSendReceiptsDesc =>
      'Deixe os outros verem quando leu as mensagens deles';

  @override
  String get pvShowReceipts => 'Mostrar confirmações de leitura';

  @override
  String get pvShowReceiptsDesc => 'Ver quem leu as suas mensagens';

  @override
  String get pvShowReceiptsHint =>
      'Só contam as pessoas que enviam confirmações de leitura.';

  @override
  String get pvFriendRequests => 'Pedidos de amizade';

  @override
  String get pvFriendRequestsDesc => 'Quem lhe pode enviar pedidos de amizade';

  @override
  String get pvSupervisedTitle => 'Os seus responsáveis definem isto';

  @override
  String get pvEveryone => 'Todos';

  @override
  String get pvFriends => 'Amigos';

  @override
  String get pvNobody => 'Ninguém';

  @override
  String get pvOn => 'Ativado';

  @override
  String get pvOff => 'Desativado';

  @override
  String get pvAnyone => 'Qualquer pessoa';

  @override
  String get pvHighlights => 'Os meus destaques';

  @override
  String get pvHighlightsDesc =>
      'Se as suas fotos e vídeos aparecem nos murais dos amigos no dia';

  @override
  String get pvPuzzle => 'A minha pontuação no puzzle';

  @override
  String get pvPuzzleDesc => 'Se os amigos veem como foi no puzzle do dia';

  @override
  String get pvPast => 'O meu histórico';

  @override
  String get pvPastDesc =>
      'Hoje é sempre partilhado com amigos. Isto abre tudo o que veio antes';

  @override
  String get pvPoints => 'Os meus pontos';

  @override
  String get pvPointsDesc =>
      'Se os pontos que regista aparecem nos murais dos amigos';

  @override
  String get roomColorsPageTitle => 'Quem é quem';

  @override
  String get roomColorsPageHeader => 'A cor em que cada pessoa fala';

  @override
  String get roomColorsAuto => 'Automático';

  @override
  String get roomColorsReset => 'Voltar ao automático';

  @override
  String get roomColorsOffFooter =>
      'As cores por pessoa estão desativadas. Ativar aqui ativa-as em todas as salas.';

  @override
  String roomColorsSharedWith(String name) {
    return 'Partilhada com $name';
  }

  @override
  String get settingsScreenValueReplyQuote => 'Citação';

  @override
  String get replyQuoteSub =>
      'A mensagem original aparece no topo da resposta, dentro do balão.';

  @override
  String get riTabMedia => 'Fotos e vídeos';

  @override
  String get riTabFiles => 'Ficheiros';

  @override
  String get riTabVoice => 'Mensagens de voz';

  @override
  String get riTabLinks => 'Ligações';

  @override
  String get riTabSaved => 'Guardados';

  @override
  String get riNone => 'Nenhum';

  @override
  String get riSavedNote =>
      'Só você vê o que guarda. Uma mensagem fixada é o contrário: toda a sala a vê.';

  @override
  String get riOwnerNote => 'A medalha marca quem criou esta sala.';

  @override
  String get famPair => 'Emparelhar';

  @override
  String get famRelease => 'Libertar';

  @override
  String get famSettings => 'Definições';

  @override
  String get famAddChild => 'Adicionar criança';

  @override
  String get famEmptyTitle => 'Ainda sem crianças';

  @override
  String get famOnlineNow => 'Online agora';

  @override
  String get famNotPaired => 'Ainda não emparelhado';

  @override
  String get famJustNow => 'Agora mesmo';

  @override
  String get apprEmptyTitle => 'Nada pendente';

  @override
  String get apprEmptySub => 'Está tudo em dia.';

  @override
  String get apprNotYet => 'Ainda não';

  @override
  String get apprAllow => 'Permitir';

  @override
  String get compGeneral => 'Geral';

  @override
  String get compStorage => 'Armazenamento';

  @override
  String get compTranslateInto => 'Traduzir para';

  @override
  String get compBrain => 'Cérebro';

  @override
  String laUnlinkProvider(String provider) {
    return 'Desassociar $provider';
  }

  @override
  String laLinkProvider(String provider) {
    return 'Associar $provider';
  }

  @override
  String get laUnlink => 'Desassociar';

  @override
  String get laLink => 'Associar';

  @override
  String get laLinked => 'Associada';

  @override
  String get laNotLinked => 'Não associada';

  @override
  String rdSignOut(String name) {
    return 'Terminar a sessão de $name';
  }

  @override
  String get rpContinue => 'Continuar';

  @override
  String get rpCopy => 'Copiar';

  @override
  String get rpSaved => 'Já guardei';

  @override
  String get rpBack => 'Voltar';

  @override
  String get rpKeep => 'Agora não, manter a minha frase atual';

  @override
  String get childSetupHeadingIos => 'Quem é?';

  @override
  String get childPairTitleIos => 'Olá!';

  @override
  String get childPairBackIos => 'Voltar ao início de sessão';

  @override
  String get gamesHubTitle => 'Classificação';

  @override
  String get gamesHubSubtitle =>
      'Os vencedores de hoje. Puzzles novos todos os dias.';

  @override
  String get gameTellFriendsMessage =>
      'Vão receber uma notificação com este resultado. Só pode ser enviado uma vez.';

  @override
  String get deviceLoginScanTitleIos => 'Leia o código para entrar';

  @override
  String get deviceLoginConfirmTitleIos => 'Iniciar sessão neste dispositivo?';

  @override
  String get socialHeroCreateIos => 'Quase lá';

  @override
  String get socialHeroLinkIos => 'Bem-vindo de volta';

  @override
  String socialSignInLinkIos(String provider) {
    return 'Iniciar sessão e ligar $provider';
  }

  @override
  String get serverTitleIos => 'Servidor';

  @override
  String get serverOnboardingTitleIos => 'Escolha um servidor';

  @override
  String get approvalGateAskIos => 'Pedir';

  @override
  String get friendRequestDraftIntroOutgoingSentence =>
      'Manda umas linhas. Podem aceitar ou recusar.';

  @override
  String get requestDeclineIos => 'Recusar';

  @override
  String get joinRequestAllowIos => 'Permitir';

  @override
  String get changeRequestUseIos => 'Usar';

  @override
  String get settingsSearchHint => 'Pesquisar definições';

  @override
  String settingsSearchNoResults(String query) {
    return 'Sem resultados para «$query»';
  }

  @override
  String get settingsSearchAccount => 'Conta';

  @override
  String get settingsHubDiagnostics => 'Diagnóstico';

  @override
  String get settingsHubDiagnosticsSubtitle =>
      'Registos para resolver problemas e reportar erros';

  @override
  String get settingsHubAdvancedFooter =>
      'Para resolver problemas e alojar o seu próprio servidor. Nada aqui é necessário no dia a dia.';

  @override
  String get settingsSearchKwLanguage => 'idioma, língua, região';

  @override
  String get settingsSearchKwUpdates => 'atualização, versão, nova';

  @override
  String get settingsSearchKwLinks =>
      'ligações, url, endereço, pré-visualização';

  @override
  String get settingsSearchKwPresence =>
      'online, presença, estado, ponto, ativo, verde';

  @override
  String get settingsSearchKwAutoplay => 'gif, animação, reprodução automática';

  @override
  String get settingsSearchKwStickers => 'autocolantes, emoji, sugestões';

  @override
  String get settingsSearchKwPush => 'notificações, alertas, som';

  @override
  String get settingsSearchKwGames => 'jogos, lembrete, diário';

  @override
  String get settingsSearchKwFriends => 'amigos, atividade, pontos';

  @override
  String get settingsSearchKwVideo => 'vídeo, chamada, qualidade, câmara';

  @override
  String get settingsSearchKwStats => 'estatísticas, rede, ping, depuração';

  @override
  String get settingsSearchKwTheme => 'tema, escuro, claro, cores, noite';

  @override
  String get settingsSearchKwIcon => 'ícone, logótipo, ecrã principal';

  @override
  String get settingsSearchKwGlass => 'vidro, desfoque, fosco, transparência';

  @override
  String get settingsSearchKwNavigation =>
      'barra de separadores, navegação, menu';

  @override
  String get settingsSearchKwMotion => 'movimento, animação, reduzir movimento';

  @override
  String get settingsSearchKwCompanions => 'ia, assistente, traduzir, modelo';

  @override
  String get settingsSearchKwChatList =>
      'lista de conversas, linhas, cartões, grelha';

  @override
  String get settingsSearchKwChatStyle => 'estilo, compacto, clássico';

  @override
  String get settingsSearchKwBubbles => 'balões, mensagens, forma';

  @override
  String get settingsSearchKwSpeakers => 'nomes, cores, grupos';

  @override
  String get settingsSearchKwReply => 'responder, citação, conversa';

  @override
  String get settingsSearchKwReport => 'erro, problema, feedback, ajuda';

  @override
  String get settingsSearchKwLegal => 'privacidade, termos, legal, licença';

  @override
  String get settingsSearchKwServer =>
      'servidor, alojamento próprio, url, programador';

  @override
  String get settingsSearchKwDiagnostics =>
      'diagnóstico, registos, depuração, programador';

  @override
  String get settingsSearchKwPrivacy =>
      'privacidade, visibilidade, visto por último';

  @override
  String get settingsSearchKwBlocked => 'bloqueados, bloquear';

  @override
  String get settingsSearchKwDevices =>
      'dispositivos, sessões, terminar sessão';

  @override
  String get settingsSearchKwLinked => 'apple, google, iniciar sessão';

  @override
  String get settingsSearchKwRecovery =>
      'frase de recuperação, palavra-passe, cópia';

  @override
  String get settingsSearchKwCapture =>
      'captura de ecrã, gravação, privacidade';

  @override
  String get settingsSearchKwFamily => 'família, criança, pais, aprovações';

  @override
  String get settingsSearchKwAccount =>
      'conta, terminar sessão, eliminar, e-mail';

  @override
  String get childPolicyScreenContactStateAllowedTalking => 'Em contacto';

  @override
  String get childPolicyScreenContactStateTalking => 'Aprovado';

  @override
  String get childPolicyScreenContactStateAllowedNotAdded =>
      'Ainda não adicionado';

  @override
  String get profileScreenSignOutConfirmTitle =>
      'Terminar sessão neste dispositivo?';

  @override
  String get profileScreenDeleteAccountConfirmTitle => 'Eliminar a tua conta?';

  @override
  String get profileScreenDeleteAccountConfirmBody =>
      'As tuas mensagens, fotografias, salas e amigos desaparecem, e o teu nome de utilizador fica livre para outra pessoa.';

  @override
  String get glassPresetNameFrosted => 'Fosco';

  @override
  String get glassPresetNameClear => 'Transparente';

  @override
  String settingsScreenDiagnosticsCountdown(int count) {
    return 'Diagnóstico em $count…';
  }

  @override
  String pairingCodeTitlePair(String name) {
    return 'Emparelhar $name';
  }

  @override
  String pairingCodeTitleRelease(String name) {
    return 'Libertar $name';
  }

  @override
  String archivedChatsSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversas',
      one: '$count conversa',
    );
    return '$_temp0';
  }

  @override
  String pinnedListSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens',
      one: '$count mensagem',
    );
    return '$_temp0';
  }

  @override
  String get voiceRecorderScreenTitle => 'Mensagem de voz';

  @override
  String get chatTargetSearchHint => 'Pesquisar';

  @override
  String get marloweBrainTierSwiftDetail =>
      'Respostas rápidas, a transferência mais leve';

  @override
  String get marloweBrainTierBalancedDetail =>
      'Um bom equilíbrio entre rapidez e profundidade';

  @override
  String get marloweBrainTierDeepDetail =>
      'O mais ponderado, precisa de mais espaço';

  @override
  String get reportFactDeviceId => 'ID do dispositivo';

  @override
  String get reportFactUserId => 'ID de utilizador';

  @override
  String get reportFactUsername => 'Nome de utilizador';

  @override
  String get reportFactApp => 'App';

  @override
  String get reportFactDevice => 'Dispositivo';

  @override
  String get reportFactSystem => 'Sistema';

  @override
  String get reportFactDisplay => 'Ecrã';

  @override
  String get reportFactAppLanguage => 'Idioma da app';

  @override
  String get reportFactSystemLocale => 'Região do sistema';

  @override
  String get reportFactLog => 'Registo';

  @override
  String reportFactLogValue(int count) {
    return '$count eventos anexados';
  }

  @override
  String reportProblemScreenshotN(int n) {
    return 'Captura de ecrã $n';
  }

  @override
  String reportProblemRemoveScreenshot(int n) {
    return 'Remover captura de ecrã $n';
  }

  @override
  String get reportFactLanguageFromSystem => 'do sistema';

  @override
  String get reportFactLanguageChosen => 'escolhido';

  @override
  String get pageSectionSeeAll => 'Ver tudo';

  @override
  String get discoverScreenSeeAllFriendsSemanticLabel => 'Ver todos os amigos';

  @override
  String get discoverScreenSeeAllRoomsSemanticLabel =>
      'Ver todas as tuas salas';

  @override
  String groupCallScreenRingingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count a tocar',
    );
    return '$_temp0';
  }

  @override
  String photoChromeWhenToday(String time) {
    return 'Hoje às $time';
  }

  @override
  String photoChromeWhenYesterday(String time) {
    return 'Ontem às $time';
  }

  @override
  String photoChromeWhenDate(String date, String time) {
    return '$date às $time';
  }

  @override
  String get photoChromeSaved => 'Guardado';

  @override
  String get photoChromeSaveFailed => 'Não foi possível guardar';

  @override
  String get photoChromeShareFailed => 'Não foi possível partilhar';

  @override
  String photoChromeForwarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reencaminhado para $count conversas',
      one: 'Reencaminhado',
    );
    return '$_temp0';
  }

  @override
  String get photoChromeForwardFailed => 'Não foi possível reencaminhar';

  @override
  String get photoChromeDeleteFailed => 'Não foi possível eliminar';

  @override
  String get photoChromeDeleteBody =>
      'Isto remove-o para todos nesta sala. Não pode ser desfeito.';

  @override
  String get roomContentMonthThis => 'Este mês';

  @override
  String get roomContentMonthLast => 'Mês passado';

  @override
  String get leaderboardOverall => 'Hoje';

  @override
  String get leaderboardFooter =>
      '1 ponto por cada puzzle que resolves hoje. Em caso de empate, ganha quem ficou mais vezes em primeiro. Continua o empate? Partilham a posição, por ordem alfabética.';

  @override
  String get leaderboardNotPlayed => 'Ainda não jogaste';

  @override
  String get leaderboardPlay => 'Jogar';

  @override
  String get leaderboardEmptyTitle => 'Ainda não há pontuações hoje';

  @override
  String get leaderboardEmptyBody =>
      'Resolve um puzzle e ficas em primeiro na lista.';

  @override
  String get pointComposerPickFirst => 'Escolhe primeiro um em cima';

  @override
  String get momentStoryNext => 'Seguinte';

  @override
  String get momentStoryPrevious => 'Anterior';

  @override
  String leaderboardSolved(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      solved,
      locale: localeName,
      other: '$solved de $total resolvidos',
      one: '1 de $total resolvido',
      zero: 'Nada resolvido ainda',
    );
    return '$_temp0';
  }

  @override
  String leaderboardWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vitórias',
      one: '1 vitória',
    );
    return '$_temp0';
  }

  @override
  String leaderboardEmptyAction(String game) {
    return 'Jogar: $game';
  }

  @override
  String get diagCatApi => 'Chamadas ao servidor';

  @override
  String get diagCatConnection => 'Ligação';

  @override
  String get diagCatDevice => 'Dispositivo';

  @override
  String get diagCatError => 'Erros';

  @override
  String get diagCatFrame => 'Fotogramas lentos';

  @override
  String get diagCatLayout => 'Esquema';

  @override
  String get diagCatLifecycle => 'Estado da app';

  @override
  String get diagCatLog => 'Registo';

  @override
  String get diagCatNav => 'Navegação';

  @override
  String get diagCatNetwork => 'Rede';

  @override
  String get diagCatSubscription => 'Atualizações em direto';

  @override
  String get diagSevTrace => 'Rastreio';

  @override
  String get diagSevDebug => 'Depuração';

  @override
  String get diagSevInfo => 'Info';

  @override
  String get diagSevWarning => 'Aviso';

  @override
  String get diagSevError => 'Erro';

  @override
  String get diagAll => 'Tudo';

  @override
  String get diagSearchHint => 'Pesquisar nome, detalhe, conteúdo';

  @override
  String get diagSummaryCopied => 'Resumo copiado';

  @override
  String get diagShareLog => 'Partilhar registo';

  @override
  String get diagCopySummary => 'Copiar resumo';

  @override
  String get diagDeleteAll => 'Apagar tudo';

  @override
  String get diagUndo => 'Anular';

  @override
  String get diagDeleteLogTitle => 'Apagar o registo inteiro?';

  @override
  String get diagDeleteLogBody =>
      'Todos os eventos registados até agora são apagados, juntamente com o registo da sessão anterior. O que acontecer a partir de agora é registado como habitualmente.';

  @override
  String get diagDelete => 'Apagar';

  @override
  String get diagLogDeleted => 'Registo apagado';

  @override
  String get diagFilter => 'Filtrar';

  @override
  String get diagMore => 'Mais';

  @override
  String get diagLatest => 'Mais recentes';

  @override
  String get diagJumpToLatest => 'Ir para o mais recente';

  @override
  String get diagPaused => 'em pausa';

  @override
  String get diagPreparingLog => 'a preparar registo…';

  @override
  String get diagEmptyNothingTitle => 'Ainda nada registado';

  @override
  String get diagEmptyNothingHint =>
      'Usa a app durante um momento e os eventos aparecem aqui.';

  @override
  String get diagEmptyHiddenTitle => 'Por agora, só eventos ocultos';

  @override
  String get diagEmptyHiddenHint =>
      'Toca num chip esbatido acima para o ver, ou mantém premido para o devolver a Tudo.';

  @override
  String get diagEmptyNoMatchTitle => 'Nenhum evento corresponde';

  @override
  String get diagEmptyNoMatchHint => 'Toca em Tudo acima para limpar o filtro.';

  @override
  String get diagApply => 'Aplicar';

  @override
  String get diagMinSeverity => 'Gravidade mínima';

  @override
  String get diagEverything => 'Tudo';

  @override
  String get diagHiddenFromAllHeader => 'Ocultos em Tudo';

  @override
  String get diagHiddenFromAllFooter =>
      'Ficam fora de Tudo até serem escolhidos na fila de chips. Mantém premido um chip lá para o mesmo ajuste.';

  @override
  String get diagCollapseRepeats => 'Agrupar repetições';

  @override
  String get diagCollapseRepeatsSubtitle =>
      'Junta uma sequência do mesmo evento numa linha';

  @override
  String get diagResetFilter => 'Repor filtro';

  @override
  String get diagBodyTruncated => 'Conteúdo cortado no registo';

  @override
  String get diagCopyEvent => 'Copiar evento';

  @override
  String get diagEventCopied => 'Evento copiado';

  @override
  String diagHiddenFromAll(String category) {
    return '$category oculto em Tudo';
  }

  @override
  String diagBackInAll(String category) {
    return '$category de volta a Tudo';
  }

  @override
  String diagChipSemanticLabel(String category, int count) {
    return '$category, $count';
  }

  @override
  String diagChipHiddenSemanticLabel(String category, int count) {
    return '$category, $count, oculto em Tudo';
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
          '$count eventos anteriores descartados. O registo começa a meio da história',
      one:
          '$count evento anterior descartado. O registo começa a meio da história',
    );
    return '$_temp0';
  }

  @override
  String diagRepeatSpan(int count, String seconds) {
    return '×$count em $seconds s';
  }

  @override
  String roomContentTabSemantic(String count, String label) {
    return '$label, $count itens';
  }

  @override
  String get mapAppsTitle => 'Mapas';

  @override
  String get mapAppsChoose => 'Abrir localização em';

  @override
  String get mapAppsRemember => 'Usar como padrão';

  @override
  String get mapAppsAskEveryTime => 'Perguntar sempre';

  @override
  String get mapAppsBrowser => 'Navegador';

  @override
  String get mapAppsSubtitle =>
      'Escolha onde abrir as localizações partilhadas.';

  @override
  String get mapAppsUnavailable =>
      'A app de mapas padrão não está disponível. Escolha outra.';

  @override
  String get mapAppsNoInstalled =>
      'Nenhuma app de mapas compatível encontrada. Pode usar o navegador.';

  @override
  String get interactionAnswersSearch => 'Pesquisar pessoas ou respostas';

  @override
  String get interactionFilterEmpty =>
      'Nenhuma resposta corresponde a este filtro.';

  @override
  String get interactionRetry => 'Tentar novamente';

  @override
  String get cameraEditorScreenCaptionHint => 'Adicionar legenda…';

  @override
  String get cameraEditorScreenCaptionViewOnceHint =>
      'Sem legenda em fotos de visualização única';

  @override
  String get cameraEditorScreenAddFromCameraSemanticLabel =>
      'Tirar outra fotografia';

  @override
  String cameraEditorScreenDiscardAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Descartar $count fotografias?',
      one: 'Descartar esta fotografia?',
    );
    return '$_temp0';
  }

  @override
  String get cameraEditorScreenDiscardAllBody =>
      'As suas edições e legendas serão perdidas.';

  @override
  String get cameraEditorScreenDiscardAllConfirm => 'Descartar';

  @override
  String get galleryTrayRecentsTitle => 'Recentes';

  @override
  String get galleryTrayBackToCameraLabel => 'Voltar à câmara';

  @override
  String get galleryTrayAllPhotosLabel => 'Todas as fotografias';

  @override
  String get galleryTrayHandleLabel => 'Fotografias recentes';

  @override
  String get galleryTrayAllowPrompt => 'Veja aqui as suas fotografias recentes';

  @override
  String get galleryTrayAllowButton => 'Permitir';

  @override
  String get galleryTrayDeniedPrompt =>
      'O acesso às fotografias está desativado';

  @override
  String get galleryTraySettingsButton => 'Definições';

  @override
  String get galleryTrayLimitedNote =>
      'A mostrar apenas as fotografias que permitiu';

  @override
  String get galleryTrayManageButton => 'Gerir';

  @override
  String get galleryTrayEmpty => 'Ainda não há fotografias';

  @override
  String galleryTrayAddSelectedButton(int count) {
    return 'Adicionar ($count)';
  }

  @override
  String get galleryTrayCancelSelectionLabel => 'Cancelar seleção';

  @override
  String galleryTraySelectedTitle(int count) {
    return '$count selecionadas';
  }

  @override
  String galleryTrayPhotoLabel(int index) {
    return 'Fotografia $index';
  }

  @override
  String get reactionLimitTitle => 'Atingiste o limite de reações';

  @override
  String reactionLimitMessageBody(int limit) {
    return 'Pela rapidez, pela sanidade e para deixar cada emoji brilhar, podes adicionar até $limit reações a uma mensagem, nem mais uma. Retira uma para dar lugar a outra.';
  }

  @override
  String reactionLimitHighlightBody(int limit) {
    return 'Nos destaques, cada pessoa tem $limit reações, para que cada uma continue a dizer algo. Retira uma para dar lugar a uma nova favorita.';
  }

  @override
  String get reactionLimitDismiss => 'Entendido';

  @override
  String get reactionPickerYoursLabel => 'As tuas reações';

  @override
  String reactionPickerTakeBackSemantic(String emoji) {
    return 'Remover a tua reação $emoji';
  }

  @override
  String get momentCommentsTitle => 'Comentários';

  @override
  String momentCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comentários',
      one: '1 comentário',
      zero: 'Comentar',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentsEmptyTitle => 'Ainda sem comentários';

  @override
  String get momentCommentsEmptyBody =>
      'Começa a conversa com palavras, um autocolante ou um GIF.';

  @override
  String get momentCommentHint => 'Adiciona um comentário…';

  @override
  String momentCommentReplyHint(String name) {
    return 'Responder a $name…';
  }

  @override
  String momentCommentReplyingTo(String name) {
    return 'A responder a $name';
  }

  @override
  String get momentCommentCancelReply => 'Cancelar resposta';

  @override
  String get momentCommentReply => 'Responder';

  @override
  String momentCommentViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ver $count respostas',
      one: 'Ver 1 resposta',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentHideReplies => 'Ocultar respostas';

  @override
  String get momentCommentDelete => 'Eliminar comentário';

  @override
  String get momentCommentDeleteConfirm =>
      'Eliminar este comentário? As respostas também vão.';

  @override
  String get momentCommentDeleteConfirmButton => 'Eliminar';

  @override
  String get momentCommentSend => 'Enviar';

  @override
  String get momentCommentExpressions => 'Autocolantes e GIFs';

  @override
  String get momentCommentFailed =>
      'Não foi possível publicar o teu comentário. Tenta novamente.';

  @override
  String get momentCommentAuthorBadge => 'Autor';

  @override
  String get momentCommentLike => 'Gosto';

  @override
  String get momentCommentStickerAlt => 'Autocolante';

  @override
  String get momentCommentGifAlt => 'GIF';

  @override
  String get momentCommentPosted => 'Comentário publicado';

  @override
  String momentCommentsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ver os $count comentários',
      one: 'Ver 1 comentário',
    );
    return '$_temp0';
  }

  @override
  String momentReactorsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count pessoas',
      one: 'mais 1 pessoa',
    );
    return '$name e $_temp0';
  }

  @override
  String get storageKindPhotos => 'Fotografias';

  @override
  String get storageKindVideos => 'Vídeos';

  @override
  String get storageKindVideoMessages => 'Notas de vídeo';

  @override
  String get storageKindVoice => 'Mensagens de voz';

  @override
  String get storageKindFiles => 'Ficheiros';

  @override
  String get storageKindStickers => 'Autocolantes e GIFs';

  @override
  String get storageKindChatHistory => 'Histórico de conversas';

  @override
  String get storageKindOther => 'Outros';

  @override
  String get dataUsageKindCalls => 'Chamadas';

  @override
  String get dataStorageTitle => 'Dados e armazenamento';

  @override
  String get settingsSearchKwDataStorage =>
      'armazenamento cache memória espaço limpar transferir descarregar transferência automática dados utilização móveis wifi guardar fotografias galeria storage';

  @override
  String get storageUsageTitle => 'Utilização do armazenamento';

  @override
  String get dataUsageTitle => 'Utilização de dados';

  @override
  String get dataStorageAutoDownloadHeader =>
      'Transferência automática de multimédia';

  @override
  String get dataStorageUsingCellular => 'Com dados móveis';

  @override
  String get dataStorageUsingWifi => 'Com Wi-Fi';

  @override
  String get dataStorageNowTag => 'Agora';

  @override
  String get autoDownloadReset => 'Repor transferência automática';

  @override
  String get autoDownloadResetTitle =>
      'Repor as definições predefinidas de transferência automática?';

  @override
  String get dataStorageSaveHeader => 'Guardar em Fotografias';

  @override
  String get dataStorageSaveFooter =>
      'Guarda automaticamente as novas fotografias e vídeos destas conversas na tua fototeca.';

  @override
  String get dataStorageCallsHeader => 'Chamadas';

  @override
  String get dataStorageLessDataForCalls => 'Usar menos dados nas chamadas';

  @override
  String get dataStorageCallsFooter =>
      'Usa menos dados em redes fracas ou limitadas, com qualidade de áudio e vídeo ligeiramente inferior.';

  @override
  String get dataStorageCallsNever => 'Nunca';

  @override
  String get dataStorageCallsCellular => 'Com dados móveis';

  @override
  String get dataStorageCallsAlways => 'Sempre';

  @override
  String get dataStorageOff => 'Desligado';

  @override
  String get dataStorageChatsPrivate => 'Conversas privadas';

  @override
  String get dataStorageChatsGroups => 'Grupos';

  @override
  String get dataStorageChatsPublic => 'Salas públicas';

  @override
  String get dataStorageNetCellular => 'Dados móveis';

  @override
  String get dataStorageNetWifi => 'Wi-Fi';

  @override
  String get autoDownloadMaster => 'Transferir multimédia automaticamente';

  @override
  String get autoDownloadUsageHeader => 'Utilização de dados';

  @override
  String get autoDownloadPresetLow => 'Baixo';

  @override
  String get autoDownloadPresetMedium => 'Médio';

  @override
  String get autoDownloadPresetHigh => 'Alto';

  @override
  String get autoDownloadCustomFooter =>
      'Personalizaste estas definições. Move o controlo para voltar a uma predefinição.';

  @override
  String get autoDownloadTypesHeader => 'Tipos de multimédia';

  @override
  String get autoDownloadVideosTitle => 'Vídeos e notas de vídeo';

  @override
  String get autoDownloadVoiceFooter =>
      'As mensagens de voz e os autocolantes são muito pequenos, por isso são sempre transferidos automaticamente.';

  @override
  String get autoDownloadAllChats => 'Todas as conversas';

  @override
  String autoDownloadUpToIn(String size, String chats) {
    return 'Até $size em $chats';
  }

  @override
  String autoDownloadSummaryUpTo(String kind, String size) {
    return '$kind até $size';
  }

  @override
  String get autoDownloadSummaryVoiceOnly => 'Apenas mensagens de voz';

  @override
  String get autoDownloadInHeader => 'Transferir automaticamente em';

  @override
  String get autoDownloadMaxSizeHeader => 'Tamanho máximo do ficheiro';

  @override
  String autoDownloadMaxSizeVideoFooter(String size) {
    return 'Os vídeos até $size são transferidos automaticamente. Os maiores esperam por um toque.';
  }

  @override
  String autoDownloadMaxSizeFileFooter(String size) {
    return 'Os ficheiros até $size são transferidos automaticamente. Os maiores esperam por um toque.';
  }

  @override
  String get autoDownloadGateLoad => 'Transferir fotografia';

  @override
  String get saveToPhotosHeader => 'Guardar automaticamente';

  @override
  String get saveToPhotosFooter =>
      'As novas fotografias e vídeos que recebes nestas conversas são adicionados à tua fototeca à medida que são transferidos.';

  @override
  String get saveToPhotosMaxVideoHeader => 'Tamanho máximo do vídeo';

  @override
  String get saveToPhotosNoAccess =>
      'Permite o acesso à fototeca nas Definições para guardar automaticamente.';

  @override
  String get saveToPhotosPhotosAndVideos => 'Fotos e vídeos';

  @override
  String get storageCalculating => 'A calcular…';

  @override
  String storageShareOfFree(String percent) {
    return 'O MonkeyHub usa $percent do teu espaço livre.';
  }

  @override
  String get storageEmpty => 'Não há nada em cache neste momento.';

  @override
  String storageClearAllButton(String size) {
    return 'Limpar toda a cache $size';
  }

  @override
  String storageClearSelectedButton(String size) {
    return 'Limpar selecionados $size';
  }

  @override
  String storageClearChatButton(String size) {
    return 'Limpar cache $size';
  }

  @override
  String get storageClearFooter =>
      'Tudo fica na nuvem e é transferido de novo sempre que precisares.';

  @override
  String get storageClearAllTitle => 'Limpar toda a cache?';

  @override
  String get storageClearSelectedTitle => 'Limpar os itens selecionados?';

  @override
  String get storageClearBody =>
      'As tuas mensagens ficam. A multimédia é transferida de novo quando a abrires.';

  @override
  String storageClearConfirm(String size) {
    return 'Limpar $size';
  }

  @override
  String storageFreed(String size) {
    return '$size libertados';
  }

  @override
  String storageCleanupTitle(String size) {
    return 'Libertar $size';
  }

  @override
  String get storageCleanupSubtitle => 'Multimédia que não abres há um mês';

  @override
  String get storageCleanupAction => 'Limpar';

  @override
  String get storageCleanupFooter =>
      'Só limpa multimédia que ninguém viu nos últimos 30 dias. As Mensagens guardadas nunca são afetadas.';

  @override
  String get storageAutoRemoveHeader =>
      'Remover multimédia em cache automaticamente';

  @override
  String get storageAutoRemoveFooter =>
      'A multimédia que não abres há este tempo é removida deste dispositivo para poupar espaço. Continua na nuvem, e as Mensagens guardadas são sempre mantidas.';

  @override
  String get dataStorageKeepNever => 'Nunca';

  @override
  String get dataStorageKeepMonth => '1 mês';

  @override
  String get dataStorageKeepWeek => '1 semana';

  @override
  String get dataStorageKeepDay => '1 dia';

  @override
  String get storageLimitHeader => 'Tamanho máximo da cache';

  @override
  String get storageLimitFooter =>
      'Se a cache ultrapassar este tamanho, a multimédia aberta há mais tempo é removida primeiro.';

  @override
  String get dataStorageLimitNone => 'Sem limite';

  @override
  String get storageTabChats => 'Conversas';

  @override
  String get storageTabMedia => 'Multimédia';

  @override
  String get storageTabFiles => 'Ficheiros';

  @override
  String get storageNoChats => 'Nenhuma conversa tem nada em cache ainda.';

  @override
  String get storageNoMedia => 'Ainda não há fotografias nem vídeos em cache.';

  @override
  String get storageNoFiles => 'Ainda não há ficheiros em cache.';

  @override
  String get storageOpenPhoto => 'Abrir fotografia';

  @override
  String get storageOpenVideo => 'Abrir vídeo';

  @override
  String get storageSelect => 'Selecionar';

  @override
  String storageChatShare(String percent) {
    return 'Esta conversa usa $percent da tua cache.';
  }

  @override
  String get storageChatUnknown => 'Conversa que deixaste';

  @override
  String dataUsageSince(String date) {
    return 'Desde $date';
  }

  @override
  String get dataUsageAll => 'Todas';

  @override
  String get dataUsageNothingYet =>
      'Ainda não foi contabilizado nada nesta rede.';

  @override
  String get dataUsageTapHint =>
      'Toca numa categoria para ver o que foi enviado e recebido.';

  @override
  String get dataUsageSent => 'Enviado';

  @override
  String get dataUsageReceived => 'Recebido';

  @override
  String get dataUsageTotalHeader => 'Utilização total da rede';

  @override
  String get dataUsageFootnote =>
      'Conta multimédia e chamadas. As mensagens em si são minúsculas e não são incluídas.';

  @override
  String get dataUsageReset => 'Repor estatísticas';

  @override
  String get dataUsageResetTitle =>
      'Repor as estatísticas de utilização de dados?';

  @override
  String get dataUsageResetBody => 'A contagem recomeça a partir de agora.';

  @override
  String get storageKindCompanions => 'Companheiros';

  @override
  String get storageCompanionsNote =>
      'Os companheiros não são apagados com a cache. Toque neles para gerir as transferências.';

  @override
  String storageCategoryCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens, $size',
      one: '1 item, $size',
    );
    return '$_temp0';
  }

  @override
  String get storageSelectAll => 'Selecionar tudo';

  @override
  String get storageDeselectAll => 'Desmarcar tudo';

  @override
  String get storageCategoryEmpty =>
      'Neste momento não há nada deste tipo em cache.';

  @override
  String get storageChatHistoryFooter =>
      'Só a cópia neste dispositivo é removida. As mensagens continuam no chat e voltam a carregar da próxima vez que o abrir.';

  @override
  String get storageCategoryHint =>
      'Toque numa categoria para ver o que contém, ou no círculo para a deixar de fora.';

  @override
  String storageChatRemovedNamed(String names) {
    return '$names · conversa removida';
  }

  @override
  String get streaksLabel => 'Sequências';

  @override
  String get streakAtRiskFooter => 'Joga hoje para manter a tua sequência.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sequência de $count dias',
      one: 'Sequência de 1 dia',
    );
    return '$_temp0';
  }

  @override
  String recordsCheersMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'e mais $count',
      one: 'e mais 1',
    );
    return '$_temp0';
  }

  @override
  String get recordsCheer => 'Aplaudir';

  @override
  String get myStreaksLabel => 'As minhas sequências';

  @override
  String streakLongest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return 'A tua mais longa: $_temp0';
  }

  @override
  String get streaksEmpty => 'Ainda ninguém tem uma sequência aqui.';

  @override
  String videoTooLargeSnack(String size) {
    return 'Os vídeos têm um limite de $size';
  }

  @override
  String videoShrinkPromptTitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos passam de $size',
      one: 'Este vídeo passa de $size',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkPromptBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vão ser comprimidos para caber, por isso conta com uma imagem bem pior.',
      one:
          'Vai ser comprimido para caber, por isso conta com uma imagem bem pior.',
    );
    return '$_temp0';
  }

  @override
  String get videoShrinkPromptAction => 'Comprimir e enviar';

  @override
  String get videoShrinkWorkingSnack => 'A comprimir o vídeo…';

  @override
  String videoShrinkFailedSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count vídeos são demasiado longos para caber em $size, mesmo comprimidos',
      one: 'Demasiado longo para caber em $size, mesmo comprimido',
    );
    return '$_temp0';
  }

  @override
  String photoHdOverCapSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos passavam de $size e foram em qualidade normal',
      one: '1 foto passava de $size e foi em qualidade normal',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkSendSmallOnly(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar só os $count abaixo de $size',
      one: 'Enviar só o que fica abaixo de $size',
    );
    return '$_temp0';
  }

  @override
  String get kbdGroupGeneral => 'Geral';

  @override
  String get kbdGroupNavigation => 'Navegação';

  @override
  String get kbdGroupChat => 'Numa conversa';

  @override
  String get kbdGroupComposer => 'Escrita';

  @override
  String get kbdGroupViewer => 'Fotos e vídeos';

  @override
  String get kbdGroupCall => 'Chamadas';

  @override
  String get kbdCommandPalette => 'Pesquisar conversas e comandos';

  @override
  String get kbdShowShortcuts => 'Atalhos de teclado';

  @override
  String get kbdSearch => 'Pesquisar';

  @override
  String get kbdNewChat => 'Nova conversa';

  @override
  String get kbdSettings => 'Definições';

  @override
  String get kbdBack => 'Voltar ou fechar';

  @override
  String kbdGoTo(String section) {
    return 'Ir para $section';
  }

  @override
  String get kbdNextChat => 'Conversa seguinte';

  @override
  String get kbdPreviousChat => 'Conversa anterior';

  @override
  String get kbdNextUnread => 'Conversa não lida seguinte';

  @override
  String get kbdCloseChat => 'Fechar conversa';

  @override
  String get kbdRoomInfo => 'Informações da conversa';

  @override
  String get kbdSearchInChat => 'Pesquisar nesta conversa';

  @override
  String get kbdJumpToLatest => 'Saltar para a última mensagem';

  @override
  String get kbdAttach => 'Anexar ficheiros';

  @override
  String get kbdVoiceCall => 'Chamada de voz';

  @override
  String get kbdVideoCall => 'Videochamada';

  @override
  String get kbdSend => 'Enviar';

  @override
  String get kbdNewline => 'Nova linha';

  @override
  String get kbdEditLast => 'Editar a tua última mensagem';

  @override
  String get kbdBold => 'Negrito';

  @override
  String get kbdItalic => 'Itálico';

  @override
  String get kbdUnderline => 'Sublinhado';

  @override
  String get kbdPasteMedia => 'Colar uma foto ou ficheiro';

  @override
  String get kbdEmoji => 'Emojis e autocolantes';

  @override
  String get kbdViewerPrevious => 'Anterior';

  @override
  String get kbdViewerNext => 'Seguinte';

  @override
  String get kbdZoomIn => 'Ampliar';

  @override
  String get kbdZoomOut => 'Reduzir';

  @override
  String get kbdZoomFit => 'Ajustar à janela';

  @override
  String get kbdPlayPause => 'Reproduzir ou pausar';

  @override
  String get kbdCopyMedia => 'Copiar';

  @override
  String get kbdSaveMedia => 'Guardar';

  @override
  String get kbdToggleMute => 'Silenciar ou ativar o microfone';

  @override
  String get kbdToggleCamera => 'Ligar ou desligar a câmara';

  @override
  String get kbdHangUp => 'Desligar';

  @override
  String get kbdGroupApp => 'App';

  @override
  String get kbdCloseWindow => 'Fechar janela';

  @override
  String get kbdMinimizeWindow => 'Minimizar';

  @override
  String get kbdFullScreen => 'Ecrã completo';

  @override
  String get kbdHideApp => 'Ocultar MonkeyHub';

  @override
  String get kbdQuit => 'Sair do MonkeyHub';

  @override
  String get kbdPanelTitle => 'Atalhos de teclado';

  @override
  String get kbdPanelSearchHint => 'Pesquisar atalhos';

  @override
  String get kbdPanelEmpty => 'Nenhum atalho corresponde';

  @override
  String kbdPeekHint(String key) {
    return 'Mantém $key premida a qualquer momento para ver os atalhos deste ecrã';
  }

  @override
  String kbdPeekSetting(String key) {
    return 'Mostrar atalhos ao manter $key premida';
  }

  @override
  String get kbdPaletteHint => 'Ir para uma conversa ou executar um comando';

  @override
  String get kbdPaletteChats => 'Conversas';

  @override
  String get kbdPaletteCommands => 'Comandos';

  @override
  String get kbdPaletteEmpty => 'Nada encontrado';

  @override
  String get kbdPaletteMove => 'Navegar';

  @override
  String get kbdPaletteOpen => 'Abrir';

  @override
  String get kbdPaletteClose => 'Fechar';

  @override
  String get msgDeskReactLabel => 'Reagir';

  @override
  String get msgDeskMoreLabel => 'Mais';

  @override
  String get msgDeskInfoLabel => 'Info';

  @override
  String get kbdSeekBackward => 'Recuar 5 segundos';

  @override
  String get kbdSeekForward => 'Avançar 5 segundos';

  @override
  String get kbdMuteVideo => 'Silenciar ou ativar o som do vídeo';

  @override
  String get viewerSavedToDownloads => 'Guardado em Transferências';

  @override
  String get viewerDownloaded => 'Transferido';

  @override
  String get viewerShowInFinder => 'Mostrar no Finder';

  @override
  String get viewerShowInFolder => 'Mostrar na pasta';

  @override
  String get viewerCopied => 'Copiado';

  @override
  String get viewerCopyFailed => 'Não foi possível copiar';

  @override
  String get hoverCompactLayoutTitle => 'Esquema compacto';

  @override
  String get hoverCompactLayoutSubtitle =>
      'Linhas mais baixas e botões mais pequenos, pensados para rato e ecrã grande.';

  @override
  String get layoutPagerPrevious => 'Anterior';

  @override
  String get layoutPagerNext => 'Seguinte';

  @override
  String get resultSheetMistakes => 'Erros';

  @override
  String get resultSheetHints => 'Dicas';

  @override
  String get resultSheetStreak => 'Sequência';

  @override
  String resultSheetStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String get resultSheetNone => 'Nenhum';

  @override
  String resultSheetToday(String game) {
    return '$game · Hoje';
  }

  @override
  String resultSheetYouFaster(String time) {
    return 'Foste $time mais rápido';
  }

  @override
  String resultSheetTheyFaster(String name, String time) {
    return '$name foi $time mais rápido';
  }

  @override
  String get resultSheetSameTime => 'O mesmo tempo que tu';

  @override
  String get resultSheetFooter =>
      'Só o tempo decide a classificação. Erros e dicas são só para os curiosos.';

  @override
  String get resultSheetHintNoRecord =>
      'Resolvido com dicas, por isso não pode ser recorde.';

  @override
  String get gameTierEasy => 'Fácil';

  @override
  String get gameTierMedium => 'Médio';

  @override
  String get gameTierHard => 'Difícil';

  @override
  String get gameComingSoon => 'Em breve';

  @override
  String get gameComingSoonName => 'Novo quebra-cabeças';

  @override
  String get chatGameNameTicTacToe => 'Jogo do galo';

  @override
  String get chatGameNameConnectFour => '4 em linha';

  @override
  String get chatGameNameCheckers => 'Damas';

  @override
  String get chatGameNameReversi => 'Reversi';

  @override
  String get chatGameNameDots => 'Pontos e quadrados';

  @override
  String get chatGameDescTicTacToe => 'Três em linha ganha.';

  @override
  String get chatGameDescConnectFour =>
      'Larga as peças. Quatro em linha ganha.';

  @override
  String get chatGameDescCheckers => 'Salta para capturar. Come todas.';

  @override
  String get chatGameDescReversi => 'Cerca para virar. Quem tiver mais ganha.';

  @override
  String get chatGameDescDots =>
      'Traça linhas, fecha quadrados, joga outra vez.';

  @override
  String get chatGameKindLive => 'Jogo ao vivo';

  @override
  String get chatGameKindTurns => 'Por turnos';

  @override
  String get chatGameStatusWaiting => 'À espera';

  @override
  String get chatGameStatusPlaying => 'A decorrer';

  @override
  String get chatGameStatusPaused => 'Em pausa';

  @override
  String get chatGameStatusFinished => 'Terminado';

  @override
  String get chatGameStatusEnded => 'Encerrado';

  @override
  String get chatGameYourMove => 'É a tua vez';

  @override
  String chatGameTurnOf(String name) {
    return 'Vez de $name';
  }

  @override
  String chatGameWaitingFor(String name) {
    return 'À espera de $name';
  }

  @override
  String chatGameWonBy(String name) {
    return '$name ganhou';
  }

  @override
  String get chatGameYouWon => 'Ganhaste';

  @override
  String get chatGameDraw => 'Empate';

  @override
  String get chatGameNobodyWon => 'Todos saíram, ninguém ganhou';

  @override
  String chatGameReasonTimeout(String name) {
    return 'O tempo de $name acabou';
  }

  @override
  String chatGameReasonResign(String name) {
    return '$name desistiu';
  }

  @override
  String chatGameReasonLeft(String name) {
    return '$name saiu';
  }

  @override
  String get chatGameOpenSeat => 'Lugar livre';

  @override
  String get chatGameReady => 'Pronto';

  @override
  String get chatGameNotReady => 'Não está pronto';

  @override
  String chatGameWatchingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count a ver',
      one: '1 a ver',
    );
    return '$_temp0';
  }

  @override
  String get chatGameJoin => 'Entrar';

  @override
  String get chatGameWatch => 'Ver';

  @override
  String get chatGamePlay => 'Jogar';

  @override
  String get chatGameOpen => 'Abrir';

  @override
  String get chatGameRematch => 'Desforra';

  @override
  String get chatGameNotRanked =>
      'Só por diversão. Os jogos do chat não contam para as tuas sequências nem recordes.';

  @override
  String get chatGameNotRankedShort => 'Sem classificação';

  @override
  String get chatGameImReady => 'Estou pronto';

  @override
  String get chatGameUnready => 'Ainda não estou pronto';

  @override
  String get chatGameTakeSeat => 'Toca para entrar';

  @override
  String get chatGameLeaveSeat => 'Sair do lugar';

  @override
  String get chatGameStartsWhenReady => 'Começa quando todos estiverem prontos';

  @override
  String chatGameNeedPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $count jogadores',
      one: 'Falta 1 jogador',
    );
    return '$_temp0';
  }

  @override
  String get chatGameWatchingLabel => 'A ver';

  @override
  String get chatGameAskSwap => 'Pedir para trocar';

  @override
  String chatGameSwapRequest(String name) {
    return '$name quer ficar no teu lugar';
  }

  @override
  String get chatGameSwap => 'Trocar';

  @override
  String get chatGameDecline => 'Recusar';

  @override
  String get chatGameAccept => 'Aceitar';

  @override
  String chatGameSwapAsked(String name) {
    return 'Pedido enviado a $name';
  }

  @override
  String get chatGameCancel => 'Cancelar';

  @override
  String get chatGameResign => 'Desistir';

  @override
  String get chatGameResignConfirm => 'Desistir deste jogo?';

  @override
  String get chatGameResignBody => 'Conta como derrota para ti.';

  @override
  String get chatGameOfferDraw => 'Propor empate';

  @override
  String get chatGameDrawOffered => 'Empate proposto';

  @override
  String chatGameDrawOfferFrom(String name) {
    return '$name propõe empate';
  }

  @override
  String chatGamePausedTitle(String name) {
    return '$name saiu do jogo';
  }

  @override
  String get chatGamePausedMany => 'Jogadores saíram';

  @override
  String get chatGamePausedBody => 'Vamos guardar o tabuleiro um pouco.';

  @override
  String get chatGamePausedYou => 'O jogo continua quando todos voltarem.';

  @override
  String get chatGameLeave => 'Sair do jogo';

  @override
  String get chatGameGo => 'Já!';

  @override
  String get chatGameNudge => 'Lembrar';

  @override
  String get chatGameNudged => 'Lembrado';

  @override
  String chatGameHoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $count horas',
      one: 'Falta 1 hora',
    );
    return '$_temp0';
  }

  @override
  String chatGameMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $count minutos',
      one: 'Falta 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get chatGameMoveFailed => 'Essa jogada não foi enviada';

  @override
  String get chatGameStale => 'O tabuleiro mudou. Tenta outra vez.';

  @override
  String get chatGameStartTitle => 'Jogar um jogo';

  @override
  String get chatGameMenuItem => 'Jogo';

  @override
  String get chatGameModeLive => 'Ao vivo';

  @override
  String get chatGameBotEasyHint => 'Comete erros. Bom para aprender.';

  @override
  String get chatGameBotMediumHint => 'Joga bem e bloqueia as tuas vitórias.';

  @override
  String get chatGameBotHardHint => 'Pensa várias jogadas à frente.';

  @override
  String get chatGameStart => 'Começar';

  @override
  String get chatGameErrAlreadyLive =>
      'Já há um jogo ao vivo aqui. Termina-o ou sai primeiro.';

  @override
  String get chatGameErrTooMany =>
      'Já tens 3 jogos por turnos aqui. Termina um primeiro.';

  @override
  String get chatGameErrEphemeral =>
      'Não dá para jogar num chat onde as mensagens desaparecem.';

  @override
  String get chatGameErrGeneric => 'Algo correu mal. Tenta outra vez.';

  @override
  String get chatGamePlayersTwo => '2 jogadores';

  @override
  String get chatGamePlayersUpToFour => '2–4 jogadores';

  @override
  String get chatGameBotName => 'Macaco';

  @override
  String get chatGameBotBadge => 'Bot';

  @override
  String get chatGameNewGame => 'Novo jogo';

  @override
  String chatGameBannerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos',
      one: '1 jogo',
    );
    return '$_temp0';
  }

  @override
  String chatGameBannerYourMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A tua vez em $count',
      one: 'A tua vez em 1',
    );
    return '$_temp0';
  }

  @override
  String get chatGameSheetTitle => 'Jogos neste chat';

  @override
  String get chatGameGone => 'Este jogo já não está disponível.';

  @override
  String get chatGameSeatsLabel => 'Jogadores';

  @override
  String get gameFlowName => 'Fluxo';

  @override
  String get gameFutoshikiName => 'Futoshiki';

  @override
  String get gameNonogramName => 'Nonograma';

  @override
  String get gameMinesweeperName => 'Caça-minas';

  @override
  String get gameStarbattleName => 'Batalha de estrelas';

  @override
  String get gamePatchesName => 'Retalhos';

  @override
  String get gameFlowRule => 'liga os pontos iguais e preenche todas as casas';

  @override
  String get gameFutoshikiRule =>
      'de 1 a 5 uma vez por linha e coluna, todos os sinais certos';

  @override
  String get gameNonogramRule => 'pinta casas para bater com cada pista';

  @override
  String get gameMinesweeperRule =>
      'abre cada casa segura, sem precisar de adivinhar';

  @override
  String get gameStarbattleRule =>
      'duas estrelas por linha, coluna e cor, sem se tocarem';

  @override
  String get gamePatchesRule =>
      'divide o tabuleiro em retângulos, uma pista em cada';

  @override
  String get gameFlag => 'Bandeira';

  @override
  String get gameAutoDot => 'Pontos automáticos';

  @override
  String boardCellName(int row, int col) {
    return 'Linha $row, coluna $col';
  }

  @override
  String get boardEmpty => 'vazia';

  @override
  String get boardBlack => 'preta';

  @override
  String get boardWhite => 'branca';

  @override
  String get boardLegalMove => 'jogada válida';

  @override
  String get boardMoveHere => 'mover para aqui';

  @override
  String boardColumnFilled(int column, int count, int total) {
    return 'Coluna $column, $count de $total preenchidas';
  }

  @override
  String boardSquareName(int number) {
    return 'Casa $number';
  }

  @override
  String get boardDarkMan => 'peça escura';

  @override
  String get boardDarkKing => 'dama escura';

  @override
  String get boardLightMan => 'peça clara';

  @override
  String get boardLightKing => 'dama clara';

  @override
  String boardBoxName(String cell) {
    return 'Quadrado, $cell';
  }

  @override
  String get boardOpen => 'livre';

  @override
  String get boardDrawn => 'traçada';

  @override
  String boardClaimedBy(String name) {
    return 'de $name';
  }

  @override
  String boardHorizontalEdge(int row, int col) {
    return 'Linha horizontal, fila $row, coluna $col';
  }

  @override
  String boardVerticalEdge(int row, int col) {
    return 'Linha vertical, fila $row, coluna $col';
  }

  @override
  String get challengeAction => 'Desafiar';

  @override
  String get challengeTitle => 'Bate o meu tempo';

  @override
  String get challengeKind => 'Desafio diário';

  @override
  String challengeYouBeat(String time) {
    return 'Bateste por $time';
  }

  @override
  String challengeStillStanding(String time) {
    return 'Continua de pé, por $time';
  }

  @override
  String get challengeTie => 'Empate perfeito';

  @override
  String get challengeClosed => 'Esse tabuleiro já fechou';

  @override
  String get challengeYourTime => 'O teu tempo a bater';

  @override
  String get challengeSent => 'Desafio enviado';

  @override
  String challengeTarget(String name, String time) {
    return '$name $time';
  }

  @override
  String challengeBeatName(String name, String time) {
    return 'Bateste os $time de $name';
  }

  @override
  String challengeKept(String name, String time) {
    return '$name mantém, por $time';
  }

  @override
  String challengeBackName(String name) {
    return 'Devolve o desafio a $name';
  }

  @override
  String challengeBackRoom(String room) {
    return 'Responder em $room';
  }

  @override
  String challengeFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amigos jogaram',
      one: '1 amigo jogou',
      zero: 'Nenhum dos teus amigos daqui jogou ainda',
    );
    return '$_temp0';
  }

  @override
  String challengeYouAndFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tu e $count amigos jogaram',
      one: 'Tu e 1 amigo jogaram',
      zero: 'Por agora só tu jogaste',
    );
    return '$_temp0';
  }

  @override
  String get challengeFriendsOnlyNote =>
      'Só os teus amigos aparecem aqui. Outras pessoas desta conversa também podem ter jogado.';

  @override
  String get chatGameNameLiarsDice => 'Dados mentirosos';

  @override
  String get chatGameNameImposter => 'Impostor';

  @override
  String get chatGameNameRace => 'Corrida de puzzles';

  @override
  String get chatGameDescLiarsDice =>
      'Aposta em dados escondidos. Desmascara o mentiroso.';

  @override
  String get chatGameDescImposter =>
      'Alguém não sabe a palavra. Descobre quem.';

  @override
  String get chatGameDescRace =>
      'O mesmo puzzle para todos. Ganha o mais rápido.';

  @override
  String chatGamePlayersRange(int min, int max) {
    return '$min a $max jogadores';
  }

  @override
  String chatGameNeedsPeople(int count) {
    return 'Mínimo de $count pessoas';
  }

  @override
  String get chatGameVoiceOption => 'Pistas por voz';

  @override
  String get chatGameVoiceOptionHint =>
      'Falem numa chamada em vez de escrever as pistas';

  @override
  String get chatGamePuzzleOption => 'Puzzle';

  @override
  String get chatGamePuzzleRandom => 'Aleatório';

  @override
  String chatGameStartNamed(String game) {
    return 'Começar $game';
  }

  @override
  String chatGameLdRoundDice(int count, int round) {
    return 'Ronda $round · $count dados';
  }

  @override
  String get chatGameLdYourDice => 'Os teus dados';

  @override
  String get chatGameLdNoBid => 'Ainda sem aposta';

  @override
  String chatGameLdBidBy(String name) {
    return 'Aposta de $name';
  }

  @override
  String get chatGameLdYourBid => 'A tua aposta';

  @override
  String get chatGameLdBid => 'Apostar';

  @override
  String get chatGameLdLiar => 'Mentiroso!';

  @override
  String get chatGameLdOnesWild => 'Os 1 são jokers';

  @override
  String get chatGameLdOnesOnly => 'Aposta em 1: sem jokers';

  @override
  String get chatGameLdHolds => 'A aposta confirma-se';

  @override
  String get chatGameLdBusted => 'Apanhado!';

  @override
  String chatGameLdThereWere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Havia $count',
      one: 'Havia 1',
    );
    return '$_temp0';
  }

  @override
  String chatGameLdLosesDie(String name) {
    return '$name perde um dado';
  }

  @override
  String get chatGameLdYouLoseDie => 'Perdes um dado';

  @override
  String chatGameLdCalled(String name) {
    return '$name gritou mentiroso';
  }

  @override
  String chatGameLdTimedOut(String name) {
    return 'O tempo de $name acabou';
  }

  @override
  String get chatGameLdOut => 'Fora';

  @override
  String get chatGameLdQuantity => 'Quantos';

  @override
  String get chatGameLdFace => 'Que face';

  @override
  String get chatGameLdFewer => 'Menos';

  @override
  String get chatGameLdMore => 'Mais';

  @override
  String get chatGameLdPrompt => 'Sobe a aposta ou grita mentiroso';

  @override
  String get chatGameLdOpenPrompt => 'Abre as apostas';

  @override
  String get chatGameImpHoldToSee => 'Mantém premido para ver a tua carta';

  @override
  String get chatGameImpYourWord => 'A tua palavra';

  @override
  String get chatGameImpYouAre => 'És o impostor';

  @override
  String chatGameImpCategory(String category) {
    return 'Categoria: $category';
  }

  @override
  String get chatGameImpBlendIn => 'Disfarça. Mais ninguém sabe.';

  @override
  String get chatGameImpKeepSecret =>
      'Não a digas diretamente. Dá pistas que os outros percebam.';

  @override
  String get chatGameImpGotIt => 'Percebi';

  @override
  String chatGameImpLooked(int count, int total) {
    return '$count de $total já viram';
  }

  @override
  String chatGameImpGiving(String name) {
    return '$name está a dar a pista';
  }

  @override
  String get chatGameImpYourClue => 'É a tua vez de dar uma pista';

  @override
  String get chatGameImpClueHint => 'De uma a quatro palavras';

  @override
  String get chatGameImpClueField => 'A tua pista';

  @override
  String get chatGameImpSend => 'Enviar';

  @override
  String get chatGameImpTooManyWords => 'No máximo quatro palavras';

  @override
  String get chatGameImpPassed => 'Passou';

  @override
  String get chatGameImpSpoke => 'Falou na chamada';

  @override
  String get chatGameImpJoinCall => 'Entrar na chamada';

  @override
  String get chatGameImpOnCall => 'Estás na chamada';

  @override
  String get chatGameImpVoiceHint =>
      'Diz a tua pista em voz alta e toca em Concluído.';

  @override
  String get chatGameImpDone => 'Concluído';

  @override
  String get chatGameImpVoteTitle => 'Quem é o impostor?';

  @override
  String get chatGameImpVoteHint =>
      'Toca num jogador para votar. Podes mudar até o tempo acabar.';

  @override
  String get chatGameImpSkip => 'Não votar';

  @override
  String chatGameImpVoted(int count, int total) {
    return '$count de $total votaram';
  }

  @override
  String get chatGameImpVotedBadge => 'Votou';

  @override
  String get chatGameImpYourVote => 'O teu voto';

  @override
  String get chatGameImpGuessing => 'O impostor está a adivinhar…';

  @override
  String get chatGameImpGuessHint =>
      'Foste apanhado. Adivinha a palavra para roubar a vitória.';

  @override
  String get chatGameImpGuessField => 'A palavra é…';

  @override
  String get chatGameImpGuess => 'Adivinhar';

  @override
  String chatGameImpWas(String name) {
    return '$name era o impostor';
  }

  @override
  String get chatGameImpYouWere => 'Eras tu o impostor';

  @override
  String get chatGameImpTheWord => 'A palavra era';

  @override
  String chatGameImpTheyGuessed(String guess) {
    return 'Disse “$guess”';
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
      other: '$count não votaram',
      one: '1 não votou',
    );
    return '$_temp0';
  }

  @override
  String get chatGameImpReasonEscaped =>
      'Ninguém foi eliminado e o impostor escapou.';

  @override
  String get chatGameImpReasonWrong => 'A equipa eliminou a pessoa errada.';

  @override
  String get chatGameImpReasonGuessed =>
      'Foi apanhado, mas o impostor adivinhou a palavra.';

  @override
  String get chatGameImpReasonCaught => 'A equipa apanhou o impostor.';

  @override
  String get chatGameImpReasonImposterLeft => 'O impostor saiu do jogo.';

  @override
  String get chatGameImpReasonCrewLeft => 'O resto da equipa saiu.';

  @override
  String get chatGameImpCrewWon => 'A equipa ganhou';

  @override
  String get chatGameImpYourTeamWon => 'A tua equipa ganhou';

  @override
  String chatGameImpImposterWon(String name) {
    return '$name ganhou como impostor';
  }

  @override
  String get chatGameImpYouWonImposter => 'Ganhaste como impostor';

  @override
  String get chatGameImpCardReveal => 'A ver as cartas';

  @override
  String chatGameImpCardClues(int count, int total) {
    return 'Pistas · $count de $total';
  }

  @override
  String get chatGameImpCardVote => 'Votação';

  @override
  String chatGameRaceFinishedCount(int count, int total) {
    return '$count de $total terminaram';
  }

  @override
  String chatGameRaceYouPlaced(int rank) {
    return 'Terminaste em $rank.º';
  }

  @override
  String get chatGameRaceWaiting => 'À espera dos outros';

  @override
  String get chatGameRaceTimeUp => 'O tempo acabou. Ninguém terminou.';

  @override
  String get chatGameRaceDnf => 'Não terminou';

  @override
  String get chatGameRaceLeft => 'Saiu';

  @override
  String get chatGameRaceResults => 'Resultados';

  @override
  String get chatGameRaceSolved => 'Resolvido!';

  @override
  String get chatGamePartyLeaveConfirm => 'Sair deste jogo?';

  @override
  String get chatGamePartyLeaveBody => 'Os outros continuam sem ti.';

  @override
  String get chatGameErrTooLate => 'Tarde demais, o tempo acabou';

  @override
  String get chatGameErrBadClue =>
      'Essa pista não vale. De uma a quatro palavras, sem links.';

  @override
  String get chatGameErrBadGuess => 'Escreve primeiro um palpite';

  @override
  String get chatGameErrNotSolved => 'O tabuleiro ainda não está resolvido';

  @override
  String get chatGameNameChess => 'Xadrez';

  @override
  String get chatGameDescChess => 'Ganha com xeque-mate ao rei.';

  @override
  String get chessPawn => 'peão';

  @override
  String get chessKnight => 'cavalo';

  @override
  String get chessBishop => 'bispo';

  @override
  String get chessRook => 'torre';

  @override
  String get chessQueen => 'dama';

  @override
  String get chessKing => 'rei';

  @override
  String chessPieceWhite(String piece) {
    return '$piece, brancas';
  }

  @override
  String chessPieceBlack(String piece) {
    return '$piece, pretas';
  }

  @override
  String chessPromoteTo(String piece) {
    return 'Promover a $piece';
  }

  @override
  String get kbdPeekDontShowAgain => 'Não voltar a mostrar';

  @override
  String get kbdPeekTurnedOff =>
      'Feito, já não vai aparecer. Podes voltar a ativar nas Definições.';

  @override
  String get chatGameBadgeTurns => 'Por turnos';

  @override
  String get chatGameSectionBoards => 'Jogos de tabuleiro';

  @override
  String get chatGameSectionParty => 'Jogos de grupo';

  @override
  String get chatGameBoardsHintDm =>
      'Joguem ao vivo agora ou por turnos quando tiverem um bocadinho.';

  @override
  String get chatGameBoardsHintGroup =>
      'Ao vivo, aqui mesmo. Entra no jogo ou fica só a ver.';

  @override
  String get chatGamePartyHint =>
      'Joga toda a gente ao mesmo tempo, por isso junta a malta primeiro.';

  @override
  String get chatGameLiveTitle => 'Jogar ao vivo';

  @override
  String get chatGameLiveNow => 'Joga toda a gente ao mesmo tempo, agora.';

  @override
  String get chatGameLivePause =>
      'Alguém sai? O jogo fica em pausa. Tem 2 minutos para voltar, senão perde.';

  @override
  String get chatGameTurnsTitle => 'Jogar por turnos';

  @override
  String get chatGameTurnsAnytime =>
      'Joga quando quiseres. Cada jogada aparece no chat.';

  @override
  String get chatGameTurnsClock =>
      '2 dias por jogada. Mandamos um lembrete e tu também podes lembrar.';

  @override
  String get chatGameHowWillYouPlay => 'Como queres jogar?';

  @override
  String get botHubTitle => 'Jogar contra o bot';

  @override
  String botHubSubtitle(String bot) {
    return 'Só tu e o $bot. Aprende as jogadas e depois vai ganhar aos teus amigos.';
  }

  @override
  String get botHubLevelTitle => 'Que dificuldade?';

  @override
  String get botHubPickGame => 'Escolhe um jogo';

  @override
  String get botHubCaption => 'Treino';

  @override
  String botHubGameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos',
      one: '1 jogo',
    );
    return '$_temp0';
  }

  @override
  String get practiceNotRanked =>
      'Só por diversão. Estes jogos não contam para as tuas sequências nem recordes.';

  @override
  String get chatGameMvYouPlayed => 'Jogaste';

  @override
  String chatGameMvTheyPlayed(String name) {
    return '$name jogou';
  }

  @override
  String chatGameMvNumber(int count) {
    return 'Jogada $count';
  }

  @override
  String chatGameMvColumn(int count) {
    return 'Coluna $count';
  }

  @override
  String get chatGameMvEarlier => 'Jogada anterior';

  @override
  String get chatGameMvSend => 'Enviar jogada';

  @override
  String get chatGameMvUndo => 'Anular';

  @override
  String get chatGameMvStagedHint =>
      'Ainda não foi enviada. Muda de ideias ou carrega em Enviar.';

  @override
  String get chatGameMvSentToast =>
      'Jogada enviada. Agora é a vez do outro lado.';

  @override
  String get chatGameMvYourTurnSub =>
      'Faz a tua jogada e depois envia. Sem pressas.';

  @override
  String get chatGameMvWaitingSub => 'Avisamos-te quando for a tua vez.';

  @override
  String get chatGameMvNudgeLater =>
      'Podes lembrar depois de 12 horas sem resposta';

  @override
  String get chatGameMvForfeitNote =>
      'Se o tempo acabar, perde quem estiver na vez';

  @override
  String get chatGameMvAgain => 'Ainda é a tua vez. Joga outra vez!';

  @override
  String get chatGameMvSending => 'A enviar…';

  @override
  String get howToNext => 'Seguinte';

  @override
  String get howToWatchAgain => 'Ver outra vez';

  @override
  String get howToGotIt => 'Percebi';

  @override
  String get howToProTip => 'Dica';

  @override
  String howToStepSemantic(int step, int total) {
    return 'Passo $step de $total';
  }

  @override
  String get howToQueens1 => 'Uma coroa em cada linha, cada coluna e cada cor.';

  @override
  String get howToQueens2 => 'As coroas não se podem tocar. Nem na diagonal.';

  @override
  String get howToQueens3 =>
      'Toca uma vez para ×, duas para coroa, mais uma para apagar.';

  @override
  String get howToQueens4 =>
      'Com as Cruzes automáticas ligadas, cada casa que uma coroa exclui leva um × por ti. Depois vê o que sobra.';

  @override
  String get howToTango1 =>
      'Um toque é sol, dois é lua. Preenche todas as casas.';

  @override
  String get howToTango2 => 'Cada linha e coluna é metade sóis, metade luas.';

  @override
  String get howToTango3 =>
      'Nunca 3 iguais seguidos, na horizontal ou na vertical. 2 pode ser.';

  @override
  String get howToTango4 => '= quer dizer iguais. × quer dizer opostos.';

  @override
  String get howToTangoTip =>
      'Dois iguais lado a lado? As casas nas duas pontas levam o outro.';

  @override
  String get howToZip1 => 'Começa no 1 e arrasta pelos números por ordem.';

  @override
  String get howToZip2 => 'Passa por todas as casas e acaba no último número.';

  @override
  String get howToZip3 => 'Enganaste-te? É só arrastar para trás.';

  @override
  String get howToZipTip =>
      'Não deixes nenhuma casa isolada. Apanha os cantos e as bordas ao passar.';

  @override
  String get howToSudoku1 =>
      'Cada linha, coluna e bloco leva do 1 ao 6. Sem repetir.';

  @override
  String get howToSudoku2 => 'Toca numa casa e depois num número.';

  @override
  String get howToSudoku3 =>
      'Número repetido na mesma linha, coluna ou bloco? Fica a vermelho.';

  @override
  String get howToSudoku4 =>
      'Procura linhas a que só falta um número. É de borla.';

  @override
  String get howToFlow1 =>
      'Arrasta de um ponto até ao seu par para fazer o tubo.';

  @override
  String get howToFlow2 =>
      'Os tubos não se cruzam e todas as casas têm de ficar cheias. Dá a volta.';

  @override
  String get howToFlowTip =>
      'Leva primeiro os tubos pelas bordas. O meio resolve-se sozinho.';

  @override
  String get howToFutoshiki1 =>
      'Preenche cada casa com um número de 1 a 5. Cada linha e coluna leva cada número exatamente uma vez.';

  @override
  String get howToFutoshiki2 =>
      'A ponta do sinal aponta para o número mais pequeno.';

  @override
  String get howToFutoshiki3 => 'Se falhares um sinal, fica a vermelho.';

  @override
  String get howToFutoshikiTip =>
      'Segue as cadeias: se a < b < c, então c é pelo menos 3.';

  @override
  String get howToNonogram1 =>
      'Cada número é um bloco de casas pintadas, sem espaços. 5 são 5 casas seguidas.';

  @override
  String get howToNonogram2 =>
      '1 1 são duas casas soltas com pelo menos uma casa vazia entre elas. O espaço também pode ser maior.';

  @override
  String get howToNonogramOrder =>
      'A ordem conta: as linhas leem-se da esquerda para a direita e as colunas de cima para baixo. 1 3 é primeiro um 1, depois um 3.';

  @override
  String get howToNonogram3 =>
      'Toca para pintar, outra vez para ×, outra vez para apagar. Arrasta para fazer várias de uma vez.';

  @override
  String get howToNonogram4 =>
      'Acerta em todas as pistas e o desenho escondido aparece.';

  @override
  String get howToNonogramTip =>
      'Começa pelas pistas grandes. Um 7 numa linha de 10 cobre sempre as 4 do meio.';

  @override
  String get howToMines1 =>
      'Abre todas as casas que não têm mina. As zonas vazias abrem-se sozinhas.';

  @override
  String get howToMines2 =>
      'O número diz quantas minas lhe tocam, cantos incluídos.';

  @override
  String get howToMines3 =>
      'Tens a certeza que é mina? Mantém premido para pôr uma bandeira.';

  @override
  String get howToMines4 =>
      'Se pisares uma mina, levas 30 segundos de castigo. Mas nunca precisas de adivinhar.';

  @override
  String get howToMinesTip =>
      'Um 1 com uma só casa escondida ao lado? Essa casa é a mina.';

  @override
  String get howToStars1 =>
      'Duas estrelas em cada linha, cada coluna e cada cor.';

  @override
  String get howToStars2 => 'As estrelas não se podem tocar. Nem na diagonal.';

  @override
  String get howToStarsControls =>
      'Toca uma vez para ponto, duas para estrela, mais uma para apagar.';

  @override
  String get howToStars3 =>
      'Com os Pontos automáticos ligados, uma estrela marca com um ponto as casas à volta dela. Quando uma linha tem as suas 2, o resto também leva ponto.';

  @override
  String get howToPatches1 =>
      'Divide o tabuleiro em retângulos. Cada um tem exatamente uma pista.';

  @override
  String get howToPatches2 =>
      'O emblema é a forma do retalho: quadrado, alto ou largo. Um emblema tracejado quer dizer que pode ser qualquer uma das três. O número, quando existe, diz quantas casas o retalho ocupa.';

  @override
  String get howToPatches3 =>
      'Arrasta de canto a canto para cortar um retalho. Toca num retalho para o tirar.';

  @override
  String get howToPatches4 =>
      'Uma pista grande encostada à borda muitas vezes só encaixa de uma maneira. Começa por aí.';

  @override
  String get howToCode1 =>
      'Há um código secreto de 4 símbolos diferentes, sem repetições. Descobre-o.';

  @override
  String get howToCode2 => 'Verde: símbolo certo, sítio certo.';

  @override
  String get howToCode3 =>
      'Amarelo: está no código, mas noutro sítio. Cinzento: não está no código.';

  @override
  String get howToCode4 => 'Tens 6 tentativas. Quanto menos usares, melhor.';

  @override
  String get howToCodeTip =>
      'Gasta as primeiras tentativas em símbolos novos. Aprender vale mais do que adivinhar.';

  @override
  String get howToTtt1 =>
      'À vez, cada um põe a sua marca. Fazes 3 em linha e ganhas.';

  @override
  String get howToTtt2 =>
      'O outro já tem 2 em linha? Fica tu com a terceira casa primeiro.';

  @override
  String get howToC41 =>
      'Toca numa coluna para largar a peça. Cai até ao espaço livre mais em baixo.';

  @override
  String get howToC42 =>
      'Faz 4 em linha para ganhar: na horizontal, na vertical ou na diagonal.';

  @override
  String get howToC4Tip =>
      'Joga na coluna do meio. Faz parte de mais quatros do que qualquer outra.';

  @override
  String get howToCheckers1 =>
      'As peças andam uma casa na diagonal para a frente. Toca na peça e depois no destino.';

  @override
  String get howToCheckers2 =>
      'Salta por cima de uma peça rival para a capturar. Se podes saltar, és obrigado. A peça que tem de saltar fica com um anel.';

  @override
  String get howToCheckers3 =>
      'Caíste onde podes voltar a saltar? Continua. Uma jogada pode levar várias.';

  @override
  String get howToCheckers4 =>
      'Chegaste ao outro lado? A tua peça passa a dama. As damas também andam para trás, mas sempre só uma casa de cada vez.';

  @override
  String get howToCheckersWin =>
      'Ganha quem captura todas as peças ou deixa o outro sem jogadas. 40 jogadas de cada um sem capturas e sem mexer peças normais dá empate.';

  @override
  String get howToCheckersTip =>
      'Mantém a tua última fila em casa. Assim não conseguem coroar reis.';

  @override
  String get howToReversi1 =>
      'Põe uma peça de forma a que uma fila das dele fique presa entre duas tuas. Cada jogada tem de prender pelo menos uma.';

  @override
  String get howToReversi2 =>
      'Todas as peças presas passam para a tua cor, em todas as direções ao mesmo tempo.';

  @override
  String get howToReversi3 =>
      'Não tens jogada? Passas a vez. Quando ninguém consegue jogar, ganha quem tem mais peças.';

  @override
  String get howToReversiTip =>
      'Apanha os cantos. Uma peça num canto nunca pode ser virada.';

  @override
  String get howToDots1 => 'À vez, cada um traça uma linha entre dois pontos.';

  @override
  String get howToDots2 => 'Fechaste um quadrado? É teu. E voltas a jogar!';

  @override
  String get howToDots3 =>
      'Cuidado com o terceiro lado de um quadrado. Estás a oferecê-lo ao próximo.';

  @override
  String get howToDotsWin =>
      'Quando se traça a última linha, ganha quem tem mais quadrados.';

  @override
  String get howToChess1 =>
      'Toca numa peça para veres para onde pode ir e depois toca numa casa.';

  @override
  String get howToChess2 =>
      'Vai para a casa de uma peça rival para a capturar.';

  @override
  String get howToChess3 =>
      'Leva um peão até à última fila e ele passa a dama, ou ao que escolheres.';

  @override
  String get howToChess4 =>
      'Xeque é o rei estar a ser atacado e tens de o safar. Sem saída? Xeque-mate, acabou. Sem jogadas possíveis, mas sem estar em xeque? É empate.';

  @override
  String get howToChessTip => 'Antes de cada jogada, vê o que te podem comer.';

  @override
  String get howToLiars1 =>
      'Toda a gente lança 5 dados às escondidas. Só vês os teus.';

  @override
  String get howToLiars2 =>
      'Na tua vez, aposta que há pelo menos tantos dados de uma face na mesa toda, contando os de toda a gente. Tipo «quatro três».';

  @override
  String get howToLiars3 =>
      'O 1 é joker: conta como qualquer face. Exceto se a aposta for em 1.';

  @override
  String get howToLiars4 =>
      'O próximo tem de subir: mais dados, ou a mesma quantidade de uma face mais alta…';

  @override
  String get howToLiars5 =>
      '…ou gritar «mentiroso!». Toda a gente mostra os dados e conta-se.';

  @override
  String get howToLiars6 =>
      'Há pelo menos esses? Quem gritou perde um dado. Há menos? Perde quem apostou.';

  @override
  String get howToLiars7 =>
      'Ficaste sem dados? Estás fora. Ganha o último que ainda tiver dados.';

  @override
  String get howToLiarsClock =>
      '45 segundos por vez. Se o tempo acabar, o jogo joga por ti.';

  @override
  String get howToLiarsTip =>
      'Conta primeiro os teus dados. Como os 1 são curingas, cerca de um terço dos dados dos outros bate com a face que apostas.';

  @override
  String get howToImposter1 =>
      'Toda a gente recebe a mesma palavra secreta. Exceto o impostor, que só vê a categoria.';

  @override
  String get howToImposter2 =>
      'À vez, cada um dá uma pista curta. Mostra que sabes a palavra sem a entregar.';

  @override
  String get howToImposterVoice =>
      'No modo de voz: diz a tua pista em voz alta na chamada e toca em Concluído.';

  @override
  String get howToImposter3 =>
      'Depois, toda a gente vota em quem acha que é o impostor, ou não vota.';

  @override
  String get howToImposter4 =>
      'Apanhado? O impostor tem uma última hipótese: se acertar na palavra, rouba a vitória. Votaram na pessoa errada, houve empate ou muitos não votaram? Ganha o impostor.';

  @override
  String get howToRace1 =>
      'Toda a gente recebe o mesmo puzzle novinho ao mesmo tempo.';

  @override
  String get howToRace2 =>
      'Resolve no teu telemóvel. A tua barra mostra a toda a gente quanto falta.';

  @override
  String get howToRace3 => 'Quem acabar primeiro ganha. Tens 10 minutos.';

  @override
  String get howToLive1 =>
      'Toda a gente joga ao mesmo tempo. Quando todos tocam em Estou pronto, começa.';

  @override
  String get howToLive2 =>
      'Alguém saiu do jogo? Fica em pausa para todos. Tem 2 minutos para voltar, senão perde.';

  @override
  String get howToLive3 =>
      'O resto do chat pode ver. Podem pedir um lugar, e um jogador pode passar-lhes o seu.';

  @override
  String get howToTurns1 =>
      'Faz a tua jogada e toca em Enviar jogada. Chega ao chat como mensagem.';

  @override
  String get howToTurns2 =>
      'Cada jogada tem 2 dias. Lembramos ao fim de 20 horas e, depois de 12 horas de silêncio, podes ser tu a lembrar.';

  @override
  String get howToTurns3 =>
      'Dois dias sem jogar? É derrota. Até 3 jogos ao mesmo tempo por chat.';

  @override
  String momentActivityGamesSolvedAll(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos',
      one: '1 jogo',
    );
    return '$name resolveu $_temp0';
  }

  @override
  String momentActivityGamesSolvedSome(int count, String name, int solved) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos',
      one: '1 jogo',
    );
    return '$name resolveu $solved de $_temp0';
  }

  @override
  String momentActivityGamesPlayed(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos',
      one: '1 jogo',
    );
    return '$name jogou $_temp0';
  }

  @override
  String momentActivityHighlightsPosted(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count momentos',
      one: '1 momento',
    );
    return '$name publicou $_temp0';
  }

  @override
  String podiumSharedBy(int count, String names, int place) {
    return 'Lugar $place, partilhado por $count: $names';
  }

  @override
  String get myBestsLabel => 'Os meus recordes';

  @override
  String recordsSharedBy(int count, String name) {
    return '$name +$count';
  }

  @override
  String get reportSheetDisclosureMessage =>
      'Ao denunciar, esta mensagem e as últimas mensagens desta conversa são enviadas aos moderadores do MonkeyHub para análise. A pessoa não saberá que a denunciou.';

  @override
  String get reportSheetDisclosureUser =>
      'Ao denunciar, as suas últimas mensagens com esta pessoa são enviadas aos moderadores do MonkeyHub para análise. Ela não saberá que a denunciou.';

  @override
  String get reportSheetDisclosureRoom =>
      'Ao denunciar, as últimas mensagens deste grupo são enviadas aos moderadores do MonkeyHub para análise. Ninguém aqui saberá que o denunciou.';

  @override
  String get reportSheetAlsoBlock => 'Bloquear também esta pessoa';

  @override
  String get reportSentReviewed =>
      'Obrigado. Os nossos moderadores analisam as denúncias no prazo de 24 horas.';

  @override
  String get reportSentAndBlocked =>
      'Obrigado. Os nossos moderadores analisam as denúncias no prazo de 24 horas. Bloqueou esta pessoa.';

  @override
  String get reportTooMany =>
      'Enviou muitas denúncias. Tente novamente daqui a pouco.';

  @override
  String get reportFailed =>
      'Não foi possível enviar a denúncia. Tente novamente.';

  @override
  String get riReportPerson => 'Denunciar esta pessoa';

  @override
  String get riReportGroup => 'Denunciar este grupo';

  @override
  String get moderationActionRemoveMessage => 'Remover mensagem';

  @override
  String get moderationActionBan => 'Banir utilizador';

  @override
  String get moderationActionUnban => 'Levantar banimento';

  @override
  String get moderationActionDismiss => 'Arquivar denúncia';

  @override
  String get moderationConfirmRemoveTitle => 'Remover esta mensagem?';

  @override
  String get moderationConfirmRemoveBody =>
      'É eliminada para todos na conversa. O cartão da denúncia mantém a sua cópia.';

  @override
  String get moderationConfirmBanTitle => 'Banir esta conta?';

  @override
  String get moderationConfirmBanBody =>
      'A sessão é terminada em todo o lado, não pode voltar a entrar, desaparece da pesquisa e sai de todas as salas públicas. Pode levantar o banimento a partir deste cartão.';

  @override
  String get moderationActionDone => 'Feito';

  @override
  String get moderationActionFailed =>
      'Não foi possível concluir. Tente novamente.';

  @override
  String get moderationCantBan =>
      'Moderadores e contas do sistema não podem ser banidos.';

  @override
  String get messageFilterBlocked =>
      'Esta mensagem não pode ser enviada porque pode conter linguagem imprópria.';

  @override
  String get nameInappropriate =>
      'Esse nome pode conter linguagem imprópria. Escolha outro, por favor.';

  @override
  String get authErrorAccountSuspended =>
      'A sua conta foi suspensa por violar os Termos de Utilização.';

  @override
  String get termsConsentPrefix => 'Aceito os ';

  @override
  String get termsConsentLink => 'Termos de Utilização (EULA)';

  @override
  String get termsConsentSuffix =>
      ' e compreendo que não há qualquer tolerância para conteúdo impróprio ou utilizadores abusivos.';

  @override
  String get termsConsentSemanticLabel => 'Aceitar os Termos de Utilização';

  @override
  String get termsMustAccept =>
      'Aceite os Termos de Utilização para continuar.';

  @override
  String get termsSheetTitle => 'Termos de Utilização';

  @override
  String get termsSheetBody =>
      'Para continuar a usar o MonkeyHub, aceite os nossos Termos de Utilização. Aqui não há lugar para conteúdo impróprio nem comportamentos abusivos, e os nossos moderadores analisam o conteúdo denunciado.';

  @override
  String get termsSheetAccept => 'Aceitar e continuar';

  @override
  String get termsAcceptFailed => 'Não foi possível guardar. Tente novamente.';

  @override
  String get settingsHubContactSupport => 'Contactar o suporte';

  @override
  String get reportSheetDisclosureMoment =>
      'Denunciar envia este momento aos moderadores do MonkeyHub para revisão. A pessoa não saberá que a denunciou.';

  @override
  String get reportSheetDisclosureComment =>
      'Denunciar envia este comentário aos moderadores do MonkeyHub para revisão. A pessoa não saberá que a denunciou.';

  @override
  String get sendLimitRateLimited =>
      'Está a enviar demasiado depressa. Aguarde um pouco e tente novamente.';

  @override
  String get sendLimitStorageFull =>
      'O seu armazenamento está cheio. Apague algumas fotos ou ficheiros que enviou para libertar espaço.';

  @override
  String get sendLimitFileTooLarge =>
      'Esse ficheiro é demasiado grande para enviar.';

  @override
  String get sendLimitMessageTooLong =>
      'Essa mensagem é demasiado longa. Tente dividi-la em várias mensagens.';

  @override
  String get limitTooOften =>
      'Está a fazer isso com demasiada frequência. Tente novamente daqui a pouco.';

  @override
  String get limitRoomFull => 'Esta sala está cheia.';

  @override
  String get limitRemovedFromRoom =>
      'Foi removido desta sala. Um administrador pode voltar a convidá-lo.';

  @override
  String get limitTooManyRooms =>
      'Está em demasiadas salas. Saia primeiro de uma que já não usa.';

  @override
  String get limitRoomTextTooLong =>
      'Esse nome ou descrição é demasiado longo. Use menos de 100 caracteres no nome e menos de 500 na descrição.';

  @override
  String get limitNotYourFile =>
      'Não é possível usar esse ficheiro. Escolha-o novamente e tente outra vez.';

  @override
  String get limitDeviceLoginBusy =>
      'Os códigos de início de sessão estão ocupados neste momento. Tente novamente dentro de um minuto.';

  @override
  String get limitRequestMessages =>
      'Não pode enviar mais até a pessoa aceitar o seu pedido.';

  @override
  String get mediaSendViewOnceTip => 'Só poderá abrir uma vez';

  @override
  String get mediaSendSpoilerTip => 'Escondida sob pó até tocarem';

  @override
  String get mediaSendSpoilerNote => 'Escondida até tocarem';

  @override
  String get mediaSendSpoilerOnSemanticLabel => 'Spoiler: ativado';

  @override
  String get mediaSendSpoilerOffSemanticLabel => 'Spoiler: desativado';

  @override
  String get mediaSpoilerRevealSemanticLabel => 'Spoiler. Toque para revelar';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'Servidor inacessível';

  @override
  String get bootErrorBody => 'O Convex não inicializou.';

  @override
  String get bootErrorRetry => 'Tentar novamente';

  @override
  String get incomingCallNotificationTitle => 'Chamada recebida';

  @override
  String get incomingCallFallbackCaller => 'Alguém está te ligando';

  @override
  String get settingsLanguageRowLabel => 'IDIOMA';

  @override
  String get languageScreenTitle => 'idioma.';

  @override
  String get languageScreenSubtitle =>
      'escolha o idioma dos menus e mensagens do app';

  @override
  String get languageOptionSystem => 'SISTEMA';

  @override
  String get languageOptionSystemSub =>
      'segue o idioma configurado no seu aparelho';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => 'ATIVO';

  @override
  String get languageValueSystem => 'Sistema';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack =>
      'Não deu pra pedir agora. Tente de novo';

  @override
  String get roomScreenGateSendMessages => 'enviar mensagens aqui';

  @override
  String get roomScreenGateSendMedia => 'enviar fotos ou áudios';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'Até $max de cada vez';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Apagar $count mensagens',
      one: 'Apagar mensagem',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Isso remove as mensagens para todos nessa conversa. Não é possível desfazer.';

  @override
  String get roomScreenDeleteConfirmBodyOne =>
      'Isso remove a mensagem para todos nessa conversa. Não é possível desfazer.';

  @override
  String get roomScreenDeleteConfirmButton => 'Apagar para todos';

  @override
  String get roomScreenJumpFailedSnack => 'Não deu pra ir até essa mensagem';

  @override
  String get roomScreenUnreadDivider => 'Mensagens não lidas';

  @override
  String get roomScreenViewOnceAlreadyViewed => 'Você já abriu essa foto.';

  @override
  String get roomScreenViewOnceGone => 'Essa foto não está mais disponível.';

  @override
  String get roomScreenViewOnceNetworkError =>
      'Não deu pra carregar essa foto.';

  @override
  String get roomScreenFileReadFailedSnack => 'Não deu pra ler esse arquivo';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'Arquivos têm limite de $size';
  }

  @override
  String get roomScreenRoomGone => 'Sala sumiu';

  @override
  String get roomScreenCopiedSnack => 'Copiado';

  @override
  String get roomScreenNameCopiedSnack => 'Nome copiado';

  @override
  String get roomScreenPinLimitSnack =>
      'Muitas mensagens fixadas. Desafixe uma primeiro';

  @override
  String get roomScreenPinFailedSnack => 'Não deu pra fixar isso';

  @override
  String get roomScreenReportSentSnack =>
      'Denúncia enviada de forma privada. A pessoa não vai ser notificada.';

  @override
  String get roomScreenDeselectMessageSemantic => 'Desmarcar mensagem';

  @override
  String get roomScreenSelectMessageSemantic => 'Selecionar mensagem';

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
    return 'Esta sala é temporária. As mensagens desaparecem após $ttl, lidas ou não.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count mensagens';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'Espaço Secreto';

  @override
  String get roomScreenSecretSpaceBody =>
      'As mensagens desta sala são temporárias. Elas são removidas automaticamente de acordo com a política de segurança da sala.';

  @override
  String get roomReadOnlyFooter =>
      'Esta sala é só para leitura. Só o MonkeyHub publica aqui.';

  @override
  String get roomScreenAutoDeleteTitle => 'Exclusão Automática';

  @override
  String get roomScreenAutoDeleteVaries => 'Variável';

  @override
  String get roomScreenAutoDeleteTimed => 'Temporizado';

  @override
  String get roomScreenNoCaptureTitle => 'Sem Captura';

  @override
  String get roomScreenNoCaptureSubtitle => 'Capturas de Tela Restritas';

  @override
  String get roomScreenMorePrivacyTitle => 'Muito Mais Privacidade';

  @override
  String get roomScreenMorePrivacySubtitle =>
      'Aproveite recursos de segurança extras, somados ao foco em privacidade que já existe.';

  @override
  String get roomScreenNoMessagesTitle => 'Nenhuma Mensagem';

  @override
  String get roomScreenNoMessagesSubtitle =>
      'Comece a conversa enviando uma mensagem';

  @override
  String get roomScreenViewProfilePictureSemantic => 'Ver foto de perfil';

  @override
  String get roomScreenViewRoomPictureSemantic => 'Ver foto da sala';

  @override
  String get messageBubbleFileFallbackName => 'Documento';

  @override
  String get messageBubbleAttachmentStatusFailed => 'Falhou';

  @override
  String get messageBubbleAttachmentStatusSending => 'Enviando…';

  @override
  String get messageBubbleViewOnceOpened => 'Aberta';

  @override
  String get messageBubbleViewOnceExpired => 'Expirada';

  @override
  String get messageBubbleViewOnceLabel => 'Visualização única';

  @override
  String get messageBubbleViewOnceTapToView => 'Toque para ver';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Foto';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'Foto de visualização única, toque para ver';

  @override
  String get messageBubblePlayOnceLabel => 'Reproduzir uma vez';

  @override
  String get messageBubblePlayOnceTapToPlay => 'Toque para reproduzir';

  @override
  String get messageBubblePlayOncePlayed => 'Reproduzido';

  @override
  String get messageBubblePlayOnceVoiceSemanticLabel =>
      'Mensagem de voz de reprodução única, toque para reproduzir';

  @override
  String get messageBubblePlayOnceVideoNoteSemanticLabel =>
      'Nota de vídeo de reprodução única, toque para reproduzir';

  @override
  String get replyIndicatorPlayOnceVoiceLabel =>
      'Mensagem de voz · reprodução única';

  @override
  String get replyIndicatorPlayOnceVideoNoteLabel =>
      'Nota de vídeo · reprodução única';

  @override
  String get roomScreenPlayOnceVoiceAlreadyPlayed =>
      'Você já ouviu essa mensagem de voz.';

  @override
  String get roomScreenPlayOnceVoiceGone =>
      'Essa mensagem de voz não está mais disponível.';

  @override
  String get roomScreenPlayOnceVoiceNetworkError =>
      'Não deu pra carregar essa mensagem de voz.';

  @override
  String get roomScreenPlayOnceVideoNoteAlreadyPlayed =>
      'Você já assistiu essa nota de vídeo.';

  @override
  String get roomScreenPlayOnceVideoNoteGone =>
      'Essa nota de vídeo não está mais disponível.';

  @override
  String get roomScreenPlayOnceVideoNoteNetworkError =>
      'Não deu pra carregar essa nota de vídeo.';

  @override
  String get messageBubbleRetrySendingSemanticLabel =>
      'Tentar enviar novamente';

  @override
  String get messageBubbleDiscardSemanticLabel => 'Descartar';

  @override
  String get profileScreenAccountSection => 'CONTA';

  @override
  String get profileScreenAddEmailPlaceholder => 'adicionar e-mail';

  @override
  String get profileScreenAddEmailTitle => 'adicionar e-mail?';

  @override
  String get profileScreenAddNameTitle => 'adicionar nome?';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count aguardando';
  }

  @override
  String get profileScreenApprovalsLabel => 'APROVAÇÕES';

  @override
  String get profileScreenApprovalsNothingWaiting => 'nada pendente';

  @override
  String get profileScreenApproveAction => 'APROVAR';

  @override
  String get profileScreenBlockAction => 'BLOQUEAR';

  @override
  String get profileScreenBlockedDmWiped =>
      'bloqueado e DM apagada. a pessoa não será notificada.';

  @override
  String get profileScreenBlockedOnly =>
      'bloqueado. a pessoa não será notificada.';

  @override
  String get profileScreenBlockedUsers => 'USUÁRIOS BLOQUEADOS';

  @override
  String get profileScreenCancelAction => 'CANCELAR';

  @override
  String get profileScreenCancelRequestAction => 'CANCELAR PEDIDO';

  @override
  String get profileScreenChangeAction => 'ALTERAR';

  @override
  String get profileScreenChangeEmailTitle => 'alterar e-mail?';

  @override
  String get profileScreenChangeNameTitle => 'alterar nome?';

  @override
  String get profileScreenChangeProfilePictureSemantic =>
      'alterar foto de perfil';

  @override
  String get profileScreenChangeRecoveryPhrase =>
      'ALTERAR FRASE DE RECUPERAÇÃO';

  @override
  String get profileScreenChooseFromLibrary => 'ESCOLHER DA GALERIA';

  @override
  String get profileScreenCouldNotSaveImage =>
      'não foi possível salvar a imagem.';

  @override
  String get profileScreenDeleteAccount => 'EXCLUIR CONTA';

  @override
  String get profileScreenEmailHint => 'opcional, nunca aparece para ninguém';

  @override
  String get profileScreenEmailSectionLabel => 'E-MAIL';

  @override
  String get profileScreenErrorAlreadyFriends => 'vocês já são amigos.';

  @override
  String get profileScreenErrorGeneric => 'não foi possível concluir isso.';

  @override
  String get profileScreenErrorNotAccepting =>
      'essa pessoa não está aceitando pedidos de amizade no momento.';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      'essa pessoa já te enviou um pedido. Confira seus pedidos.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'pedido já enviado.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'você bloqueou essa pessoa. Desbloqueie primeiro.';

  @override
  String get profileScreenErrorUserNotFound =>
      'isso não é possível no momento.';

  @override
  String get profileScreenNameNotSaved =>
      'Não foi possível salvar seu nome. Tente de novo.';

  @override
  String get profileScreenFamilyAddChild => 'adicionar uma criança';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count crianças',
      one: '$count criança',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => 'FAMÍLIA';

  @override
  String get profileScreenFriendsChip => 'AMIGOS';

  @override
  String get profileScreenGrownUpOnlyNote =>
      'Só uma pessoa grande pode fazer isso. É preciso o código ou a senha dela.';

  @override
  String get profileScreenGuardiansCanSee =>
      'Eles podem ver quando você está online e com quem você conversa.';

  @override
  String get profileScreenHandPhoneBack => 'DEVOLVER ESTE CELULAR';

  @override
  String get profileScreenIncomingRequestChip => 'PEDIDO RECEBIDO';

  @override
  String get profileScreenJustTappedAction => 'TOQUEI SEM QUERER';

  @override
  String get settingsScreenSectionHelpAndLegal => 'AJUDA E JURÍDICO';

  @override
  String get settingsScreenLicence => 'LICENÇA';

  @override
  String get profileScreenLinkedAccountsLabel => 'CONTAS VINCULADAS';

  @override
  String get profileScreenLinkedAccountsNone => 'Nada vinculado';

  @override
  String get profileScreenMyGrownUps => 'MINHA GENTE GRANDE';

  @override
  String get profileScreenNameHint => 'como você vai aparecer na sala';

  @override
  String get profileScreenChangeUsernameTitle => 'mudar nome de usuário?';

  @override
  String get profileScreenChangeUsernameWarning =>
      'Você entra com isso, então vai digitar o novo daqui em diante. Seu nome de usuário antigo fica livre para outra pessoa pegar, e você não pode mudá-lo de novo por 30 dias. Mensagens antigas que marcaram você mantêm o nome antigo.';

  @override
  String get profileScreenUsernameHint => 'como seus amigos te encontram';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return 'Pode ser mudado de novo em $date';
  }

  @override
  String get profileScreenUsernamePasswordTitle => 'confirme que é você';

  @override
  String get profileScreenUsernamePasswordAction => 'MUDAR NOME DE USUÁRIO';

  @override
  String get profileScreenUsernameProviderTitle => 'confirme com seu login';

  @override
  String profileScreenUsernameChanged(String username) {
    return 'Agora você é @$username.';
  }

  @override
  String get profileScreenUsernameNotSaved =>
      'Não foi possível mudar seu nome de usuário. Tente novamente.';

  @override
  String get usernameStatusChecking => 'verificando…';

  @override
  String get usernameStatusAvailable => 'disponível';

  @override
  String get usernameStatusTaken => 'já está em uso';

  @override
  String get usernameStatusReserved => 'indisponível';

  @override
  String get usernameStatusInvalid => '1–32 caracteres';

  @override
  String get usernameStatusUnknown => 'não deu para verificar';

  @override
  String get profileScreenNobodyLookingAfter =>
      'ainda ninguém está cuidando dessa conta';

  @override
  String get profileScreenNotAcceptingRequestsAction => 'NÃO ACEITA PEDIDOS';

  @override
  String get profileScreenNotConnectedChip => 'NÃO CONECTADO';

  @override
  String get profileScreenOpenDmAction => 'ABRIR DM';

  @override
  String get profileScreenPhotoPermissionDenied => 'permissão de fotos negada.';

  @override
  String get settingsScreenPrivacyPolicy => 'POLÍTICA DE PRIVACIDADE';

  @override
  String get profileScreenPrivacySection => 'PRIVACIDADE';

  @override
  String get profileScreenProfilePictureTitle => 'FOTO DE PERFIL';

  @override
  String get profileScreenRedactedFriend =>
      'algumas informações estão ocultas por causa das configurações dessa pessoa.';

  @override
  String get profileScreenRedactedStranger =>
      'visão limitada: essa pessoa compartilha mais com amigos.';

  @override
  String get profileScreenReportAction => 'DENUNCIAR';

  @override
  String get profileScreenReportSent =>
      'denúncia enviada em sigilo. a pessoa não será notificada.';

  @override
  String get profileScreenRequestPendingChip => 'PEDIDO PENDENTE';

  @override
  String get profileScreenSaveAction => 'SALVAR';

  @override
  String get profileScreenSavedToPhotos => 'salvo nas fotos.';

  @override
  String get profileScreenSaveToPhotos => 'SALVAR NAS FOTOS';

  @override
  String get profileScreenSendRequestAction => 'ENVIAR PEDIDO';

  @override
  String get profileScreenSetUpRecoveryPhrase =>
      'CONFIGURAR FRASE DE RECUPERAÇÃO';

  @override
  String get profileScreenSignOut => 'SAIR';

  @override
  String get profileScreenTakeSelfie => 'TIRAR UMA SELFIE';

  @override
  String get profileScreenTapAgainToConfirmDelete =>
      'TOQUE DE NOVO PARA CONFIRMAR EXCLUSÃO';

  @override
  String get settingsScreenTermsOfService => 'TERMOS DE USO';

  @override
  String get profileScreenThisPhoneSection => 'ESTE CELULAR';

  @override
  String get profileScreenUnfriendAction => 'DESFAZER AMIZADE';

  @override
  String get profileScreenViewProfilePictureSemantic => 'ver foto de perfil';

  @override
  String get profileScreenVisibilityPreferences =>
      'PREFERÊNCIAS DE VISIBILIDADE';

  @override
  String get cameraEditorScreenCropPresetFree => 'Livre';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'Orig';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'Cancelar corte';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'Descartar foto';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'Desfazer';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'Refazer';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'Redefinir corte';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'Girar';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'Cortar';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'Este navegador não consegue abrir fotos HEIC';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'Não conseguimos abrir essa imagem';

  @override
  String get cameraEditorScreenCropDoneButton => 'Pronto';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'Tirar novamente';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'Guardar a caneta';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'Desenhar na foto';

  @override
  String get cameraEditorScreenSendingButton => 'Enviando…';

  @override
  String get cameraEditorScreenSendButton => 'Enviar';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'Some depois de ser aberta uma vez';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'Limpar desenho';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel =>
      'Ver uma vez: ativado';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel =>
      'Ver uma vez: desativado';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: ativado';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: desativado';

  @override
  String get cameraEditorScreenHdNote => 'Enviando na resolução original';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'Cor da tinta';

  @override
  String get glassScreenPanelLooks => 'Estilos';

  @override
  String get glassScreenPanelBottomBar => 'Barra inferior';

  @override
  String get glassScreenPanelOtherSurfaces => 'Outras superfícies';

  @override
  String get glassScreenPanelBarLayout => 'Layout da barra';

  @override
  String get glassScreenTitle => 'vidro.';

  @override
  String get glassScreenSubtitle => 'quanto do que está atrás transparece';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'Todos os $max espaços ocupados';
  }

  @override
  String get glassScreenSaveCurrentAs => 'Salvar atual como…';

  @override
  String get glassScreenResetEveryDial => 'Redefinir todos os ajustes';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'Redefinir para $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'O campo de mensagem, os cabeçalhos, os botões de chamada: tudo que fica sobre o texto, e não sobre o conteúdo que rola';

  @override
  String get glassScreenMatchBottomBar => 'Igualar à barra inferior';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'Editado. Salve como um novo estilo ou redefina';

  @override
  String get glassScreenCustomPresetName => 'Personalizado';

  @override
  String get glassScreenUnsavedSubtitle => 'Não salvo. Dê um nome para guardar';

  @override
  String get glassScreenSaveDialogTitle => 'Salvar este visual como';

  @override
  String get glassScreenNoRoomToast => 'Sem espaço. Apague um visual primeiro';

  @override
  String get glassScreenRenameDialogTitle => 'Renomear';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'Apagar $name?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'O visual continua na tela, só deixa de ter um nome.';

  @override
  String get glassScreenKeepButton => 'Manter';

  @override
  String get glassScreenDeleteButton => 'Apagar';

  @override
  String get glassScreenNameHint => 'Altas horas';

  @override
  String get glassScreenCancelButton => 'Cancelar';

  @override
  String get glassScreenSaveButton => 'Salvar';

  @override
  String get glassScreenPreviewRoomName => '# varanda';

  @override
  String get glassScreenPreviewOnlineCount => '4 online';

  @override
  String get glassScreenPreviewMessageHint => 'mensagem';

  @override
  String get glassScreenPreviewCollapseLabel => 'recolher prévia';

  @override
  String get glassScreenPreviewExpandLabel => 'expandir prévia';

  @override
  String get glassScreenPreviewBadge => 'Prévia';

  @override
  String get glassScreenBuiltInLabel => 'Integrado';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'Sobrescrever $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'Renomear $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'Apagar $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'Redefinir $label';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'mandou as fotos do telhado, as telhas estão todas rachadas';

  @override
  String get glassScreenBackdropMsgMert =>
      'ok mas quem tá levando a caixa de som mesmo';

  @override
  String get glassScreenBackdropGroupFamily => 'família';

  @override
  String get glassScreenBackdropMsgFamily =>
      'Mãe: jantar às 8, não se atrase de novo';

  @override
  String get glassScreenBackdropMsgZeynep => 'tô lá fora';

  @override
  String get glassScreenBackdropMsgKerem =>
      'aquele lugar da esquina manda bem no café';

  @override
  String get glassScreenBackdropGroupWork => 'trabalho';

  @override
  String get glassScreenBackdropMsgWork =>
      'o standup mudou pra 10:30 pro resto da semana';

  @override
  String get glassScreenBackdropMsgElif =>
      'não acredito. manda de novo, eu perdi';

  @override
  String get glassScreenBackdropMsgBaran => 'pousei 👍';

  @override
  String get glassScreenBackdropMsgAyse =>
      'o gato aprendeu a abrir a porta da varanda';

  @override
  String get glassScreenBackdropMsgCan => 'então a gente se vê no sábado';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return 'em resposta a $name';
  }

  @override
  String get replyIndicatorViewOnceLabel => 'Foto · visualização única';

  @override
  String get replyIndicatorVoiceMessageLabel => 'Mensagem de voz';

  @override
  String get replyIndicatorDocumentLabel => 'Documento';

  @override
  String get replyIndicatorMessageRemoved => 'Mensagem removida';

  @override
  String get threadOverlayMessageNotFound =>
      'Não encontrei essa mensagem neste tópico';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'Não encontrei o tópico para responder';

  @override
  String get threadOverlayStillSending =>
      'Ainda enviando. Tente de novo em instantes';

  @override
  String get threadOverlayCopiedToast => 'Copiado';

  @override
  String get threadOverlayNameCopiedToast => 'Nome copiado';

  @override
  String get threadOverlayCoordinatesCopiedToast => 'Coordenadas copiadas';

  @override
  String get threadOverlayPinLimitToast =>
      'Muitas mensagens fixadas. Desafixe uma primeiro';

  @override
  String get threadOverlayPinFailedToast => 'Não consegui fixar isso';

  @override
  String get threadOverlayReportedToast => 'Denunciado';

  @override
  String get threadOverlayUnavailable => 'tópico indisponível';

  @override
  String get roomInfoScreenNameRequiredError => 'Nome é obrigatório';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'Senha removida';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'Sair da sala?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'Você pode entrar de novo se ela continuar aberta.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'Sair';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'Excluir sala?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'Todas as mensagens daqui vão junto. Isso é permanente.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'Excluir';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      'Encerrar esta conversa?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName também perde essa conversa: todas as mensagens somem para os dois. Isso é permanente.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'Encerrar';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'A outra pessoa';

  @override
  String get roomInfoScreenConfirmCancelButton => 'CANCELAR';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'Já existe uma sala com esse nome';

  @override
  String get roomNameReservedError => 'Nomes de sala não podem começar com dm:';

  @override
  String get roomInfoScreenErrorNotOwner => 'Só o dono pode fazer isso';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'Você não tem permissão';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'Essa sala não existe mais';

  @override
  String get roomInfoScreenRoomGone => 'Sala sumiu';

  @override
  String get roomInfoScreenNameLabel => 'NOME';

  @override
  String get roomInfoScreenNameHint => 'Nome da sala';

  @override
  String get roomInfoScreenDescriptionLabel => 'DESCRIÇÃO';

  @override
  String get roomInfoScreenDescriptionHint => 'Uma linha sobre a sala';

  @override
  String get roomInfoScreenVisibilityLabel => 'VISIBILIDADE';

  @override
  String get roomInfoScreenPublicTitle => 'pública';

  @override
  String get roomInfoScreenPublicSub => 'qualquer um pode encontrar';

  @override
  String get roomInfoScreenPrivateTitle => 'privada';

  @override
  String get roomInfoScreenPrivateSub => 'somente por convite';

  @override
  String get roomInfoScreenMessageLifeLabel => 'VIDA DA MENSAGEM';

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
  String get roomInfoScreenPasswordLabel => 'SENHA';

  @override
  String get roomInfoScreenLockedBadge => 'TRANCADA';

  @override
  String get roomInfoScreenNoneBadge => 'NENHUMA';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      'essa sala é protegida. Por segurança, a senha atual não é exibida. Digite uma nova para substituí-la.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'Substituir senha';

  @override
  String get roomInfoScreenSetPasswordHint => 'Trancar com uma senha';

  @override
  String get roomInfoScreenRemovePasswordButton => 'REMOVER SENHA';

  @override
  String get roomInfoScreenSharedContentLabel => 'CONTEÚDO COMPARTILHADO';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return 'MEMBROS · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => 'SAINDO…';

  @override
  String get roomInfoScreenLeaveRoomButton => 'SAIR DA SALA';

  @override
  String get roomInfoScreenDeletingButton => 'EXCLUINDO…';

  @override
  String get roomInfoScreenDeleteButtonLabel => 'EXCLUIR';

  @override
  String get roomInfoScreenEndingConversationButton => 'ENCERRANDO…';

  @override
  String get roomInfoScreenEndConversationButton => 'ENCERRAR CONVERSA';

  @override
  String get roomInfoScreenHeaderConversation => 'CONVERSA';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'CONFIGURAÇÕES DA SALA';

  @override
  String get roomInfoScreenViewProfilePictureSemantic => 'Ver foto de perfil';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'Ver foto da sala';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'Alterar foto da sala';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'Adicionar foto da sala';

  @override
  String get roomInfoScreenOwnerBadge => 'DONO';

  @override
  String get roomInfoScreenNoneCount => 'nenhum';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'O acesso à câmera está desligado.\nAtive-o nas Configurações para tirar uma foto.';

  @override
  String get cameraScreenOpeningSystemCamera => 'Abrindo a câmera do sistema…';

  @override
  String get cameraScreenCloseButtonLabel => 'Fechar câmera';

  @override
  String get cameraScreenLowLightBoostOnLabel => 'Modo de pouca luz: ativado';

  @override
  String get cameraScreenLowLightBoostOffLabel =>
      'Modo de pouca luz: desativado';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'Flash: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'Escolher da galeria';

  @override
  String get cameraScreenSwitchCameraLabel => 'Trocar de câmera';

  @override
  String get cameraScreenTakePhotoLabel => 'Tirar foto';

  @override
  String get childPolicyScreenAddByUsernameLabel => 'Adicionar por usuário';

  @override
  String get childPolicyScreenAddCta => 'Adicionar';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'Essa pessoa recebe exatamente o que você tem: cada pedido para aprovar, cada configuração para mudar e o poder de te remover. $name já vê essa pessoa como família.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'Adicionar um adulto';

  @override
  String get childPolicyScreenAddGuardianHint => 'Nome de usuário da pessoa';

  @override
  String get childPolicyScreenAllowCta => 'Permitir';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'Você não vai mais ser perguntado sobre essa pessoa, não importa se $childName adiciona ela ou se ela adiciona $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'Permitir alguém';

  @override
  String get childPolicyScreenAskToAddLabel => 'Pedir para adicionar';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'Só família, sem novos pedidos';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'Podem te perguntar sobre gente nova';

  @override
  String get childPolicyScreenBothFinalNote =>
      'As duas opções são definitivas. Para se afastar em vez disso, vá em Adultos, mais acima.';

  @override
  String get childPolicyScreenCallsLabel => 'Chamadas';

  @override
  String get childPolicyScreenCallsOffDesc => 'Só mensagens';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'Voz + vídeo com quem for permitido';

  @override
  String get childPolicyScreenCancelLabel => 'Cancelar';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Cancelar';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'Adicionado. O pedido está a caminho';

  @override
  String get childPolicyScreenContactAddedToList =>
      'Adicionado à lista de permitidos';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'Criar salas';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'Não podem criar salas';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'Podem criar suas próprias salas privadas';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Tudo desaparece: as mensagens, fotos, salas e os amigos. Isso não pode ser desfeito, e o nome de usuário fica livre para qualquer pessoa.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'Não foi possível excluir a conta. Tente de novo';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return 'Excluir a conta de $name?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Mensagens, fotos, salas e amigos, tudo vai embora. Não pode ser desfeito.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'Excluir a conta de $name';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'Excluir para sempre';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'Não foi possível adicionar. Tente de novo';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'Esse é o nome de usuário da própria criança';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'Uma criança não pode ser um adulto';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'Não foi possível fazer isso. Tente de novo';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'Alguém precisa cuidar da criança. Adicione outra pessoa grande primeiro';

  @override
  String get childPolicyScreenErrorNotYours => 'Não é você quem decide isso';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'Nenhuma conta com esse nome de usuário';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'Ela vira uma conta normal com essa senha, e todas as pessoas grandes perdem toda a visibilidade. Não tem como voltar atrás: você teria que receber um convite como qualquer outra pessoa.';

  @override
  String get childPolicyScreenGraduateCta => 'Formar';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'Ela mantém tudo e recebe uma senha. Você perde toda a visibilidade. Irreversível.';

  @override
  String get childPolicyScreenGraduateDangerLabel =>
      'Formar para conta completa';

  @override
  String get childPolicyScreenGraduateFailed =>
      'Não foi possível formá-la. Tente de novo';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'Formar $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'Uma senha para ela';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Tirar uma sala de volta também remove a criança dela. Tirar uma pessoa de volta também apaga a conversa, dos dois lados.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Todo mundo aqui pode aprovar, mudar configurações e ver tudo. Qualquer um deles pode agir sozinho, nada espera pelos outros.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'Adicionado. Agora pode cuidar da criança';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name removido(a)';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (você)';
  }

  @override
  String get childPolicyScreenLoading => 'Carregando…';

  @override
  String get childPolicyScreenLockedLabel => 'Bloqueado';

  @override
  String get childPolicyScreenMediaLabel => 'Fotos + voz';

  @override
  String get childPolicyScreenMediaOffDesc => 'Só texto';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'Pode enviar fotos, vídeos e notas de voz';

  @override
  String get childPolicyScreenNoRoomsYet => 'Nenhuma sala ainda';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Qualquer um daqui pode ser adicionado sem pedir sua permissão de novo, não importa quem comece.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Sempre desativado para crianças. Descobrir (a lista de salas de pessoas que você não conhece) fica totalmente oculta e não pode ser ativada. Salas para as quais alguém convida a criança continuam funcionando normalmente.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'Salas públicas';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian não vai mais ver nem aprovar nada para $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return 'Remover $name?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'Remover';

  @override
  String childPolicyScreenRoomMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '1 membro',
    );
    return '$_temp0';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'Pessoas grandes';

  @override
  String get childPolicyScreenSectionPeopleAllowed =>
      'Pessoas que você permitiu';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'Salas que você permitiu';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'O que podem fazer';

  @override
  String get childPolicyScreenSectionWhenDone => 'Últimos passos';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'Nada acontece até alguém adicionar o outro';

  @override
  String get childPolicyScreenSendNowOnDesc => 'Eles recebem o pedido na hora';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'Enviar pedido agora';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'Você é o único adulto responsável por $name, então não pode simplesmente se afastar. Adicione outro primeiro, ou use uma dessas opções.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'Afastar-se';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'Você vai perder toda a visibilidade sobre a conta de $name: os pedidos, as pessoas e as salas. Os outros adultos continuam cuidando de $name.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'Parar de supervisionar';

  @override
  String get childPolicyScreenStopSupervisingHeadline =>
      'Parar de supervisionar?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'Não deu pra retirar. Tenta de novo';

  @override
  String get childPolicyScreenTakeBackLabel => 'Retirar';

  @override
  String get childPolicyScreenUsernameHint => 'Nome de usuário';

  @override
  String get childPolicyScreenYou => 'Você';

  @override
  String get roomContentScreenDefaultDocumentName => 'Documento';

  @override
  String get roomContentScreenCouldntOpenFile =>
      'Não deu pra abrir esse arquivo';

  @override
  String get roomContentScreenCouldntShare => 'Não deu pra compartilhar isso';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links copiados',
      one: 'Copiado',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Apagar $count mensagens',
      one: 'Apagar mensagem',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Isso remove tudo para todo mundo neste chat. Não dá pra desfazer.';

  @override
  String get roomContentScreenDeleteForEveryone => 'Apagar para todos';

  @override
  String get roomContentScreenCancelTooltip => 'Cancelar';

  @override
  String get roomContentScreenBackTooltip => 'Voltar';

  @override
  String get roomContentScreenSelectingLabel => 'Selecionando';

  @override
  String get roomContentScreenSharedContentLabel => 'Conteúdo compartilhado';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '$count selecionado',
      zero: 'Nada selecionado',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'Selecionar';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'Tudo';

  @override
  String get roomContentScreenEmptyMedia =>
      'Ainda não tem fotos ou vídeos por aqui';

  @override
  String get roomContentScreenEmptyFiles => 'Ainda não tem arquivos por aqui';

  @override
  String get roomContentScreenEmptyVoice =>
      'Ainda não tem mensagens de voz por aqui';

  @override
  String get roomContentScreenEmptyLinks => 'Ainda não tem links por aqui';

  @override
  String get roomContentScreenEmptySaved =>
      'Nada salvo ainda. Segure uma mensagem e escolha Salvar.\n\nO que você guarda aqui é só seu. Uma mensagem fixada é o que a sala inteira vê.';

  @override
  String get roomContentScreenLoadFailed => 'Não deu pra carregar isso';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Mensagem de voz de $name';
  }

  @override
  String get roomContentScreenForwardAction => 'Encaminhar';

  @override
  String get roomContentScreenCopyAction => 'Copiar';

  @override
  String get roomContentScreenSaveAction => 'Salvar';

  @override
  String get roomContentScreenShareAction => 'Compartilhar';

  @override
  String get roomContentScreenInChatAction => 'No chat';

  @override
  String get roomContentScreenDeleteAction => 'Excluir';

  @override
  String get messageActionMenuReplyLabel => 'Responder';

  @override
  String get messageActionMenuEditLabel => 'Editar';

  @override
  String get messageStampEditedLabel => 'editado';

  @override
  String get composerEditCardTitle => 'Editar mensagem';

  @override
  String get spoilerRevealHint => 'Spoiler: ative para revelar o texto oculto';

  @override
  String get formatToolbarFormatLabel => 'Formatar';

  @override
  String get formatToolbarBoldLabel => 'Negrito';

  @override
  String get formatToolbarItalicLabel => 'Itálico';

  @override
  String get formatToolbarStrikethroughLabel => 'Tachado';

  @override
  String get formatToolbarUnderlineLabel => 'Sublinhado';

  @override
  String get formatToolbarSpoilerLabel => 'Spoiler';

  @override
  String get formatToolbarLinkLabel => 'Link';

  @override
  String get formatToolbarCodeLabel => 'Código';

  @override
  String get linkInputSheetTitle => 'LINK';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => 'APLICAR LINK';

  @override
  String get linkInputSheetApplySub =>
      'O texto selecionado abrirá este endereço ao ser tocado';

  @override
  String get linkInputSheetRemoveLabel => 'REMOVER LINK';

  @override
  String get linkConfirmSheetTitle => 'Abrir este link?';

  @override
  String get linkConfirmSheetOpenLabel => 'Abrir link';

  @override
  String get linkConfirmSheetCancelLabel => 'Cancelar';

  @override
  String get roomScreenEditExpiredSnack =>
      'Tarde demais para editar. As mensagens só podem ser editadas por 15 minutos.';

  @override
  String get roomScreenEditFailedSnack =>
      'Não foi possível salvar a edição. Verifique sua conexão e tente de novo.';

  @override
  String get messageActionMenuForwardLabel => 'Encaminhar';

  @override
  String get messageActionMenuViewThreadLabel => 'Ver tópico';

  @override
  String get messageActionMenuCopyLabel => 'Copiar';

  @override
  String get messageActionMenuCopyNameLabel => 'Copiar nome';

  @override
  String get messageActionMenuCopyCoordinatesLabel => 'Copiar coordenadas';

  @override
  String get messageActionMenuPinLabel => 'Fixar';

  @override
  String get messageActionMenuUnpinLabel => 'Desafixar';

  @override
  String get messageActionMenuSelectLabel => 'Selecionar';

  @override
  String get messageActionMenuProfileLabel => 'Perfil';

  @override
  String get messageActionMenuDeleteLabel => 'Excluir';

  @override
  String get messageActionMenuReportLabel => 'Denunciar';

  @override
  String get themeScreenTitle => 'tema.';

  @override
  String get themeScreenTapToApplyHint =>
      'toque para aplicar · ⛶ para prévia completa';

  @override
  String get themeScreenFamilyBasicName => 'BÁSICO';

  @override
  String get themeScreenFamilyBasicTagline => 'inspirado no iOS · 5 paletas';

  @override
  String get themeScreenFamilyVaultName => 'COFRE';

  @override
  String get themeScreenFamilyVaultTagline =>
      'dossiê confidencial · noir + marfim';

  @override
  String get themeScreenFamilyOthersName => 'OUTROS';

  @override
  String get themeScreenFamilyOthersTagline => 'climas únicos';

  @override
  String get themeScreenActiveBadge => 'ATIVO';

  @override
  String get themeScreenTapToApplyLabel => 'toque para aplicar';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return 'ATIVO: $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return 'APLICAR $name';
  }

  @override
  String get themeScreenPreviewGreeting => 'oi, você.';

  @override
  String get themeScreenPreviewSectionLabel => 'CONVERSA';

  @override
  String get themeScreenPreviewRoomOneName => 'clube de design';

  @override
  String get themeScreenPreviewRoomOneSub => 'mia: lançou o novo tile.';

  @override
  String get themeScreenPreviewRoomTwoName => 'câmara · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => 'selada em 4h.';

  @override
  String get themeScreenPreviewBubbleQuestion => 'como isso parece pra você?';

  @override
  String get themeScreenPreviewBubbleAnswer => 'parece que é esse mesmo.';

  @override
  String get callScreenVideoCallLabel => 'Chamada de vídeo';

  @override
  String get callScreenVoiceCallLabel => 'Chamada de voz';

  @override
  String callScreenStatusCalling(String kind) {
    return '$kind · chamando…';
  }

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · tocando…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · tocando';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · conectando…';
  }

  @override
  String get callScreenStatusConnected => 'Conectada';

  @override
  String get callScreenStatusEnded => 'Chamada encerrada';

  @override
  String get callScreenStatusFailed => 'Falha na chamada';

  @override
  String get callScreenStatusSwitching => 'Trocando de dispositivo…';

  @override
  String get callScreenStatusMoved => 'Movida';

  @override
  String get callScreenStatusReconnecting => 'Reconectando…';

  @override
  String get callScreenPoorConnectionLabel => 'Conexão ruim';

  @override
  String get callScreenWeakConnectionLabel => 'Conexão fraca';

  @override
  String get callScreenControlUnmute => 'Desmutar';

  @override
  String get callScreenControlMute => 'Mutar';

  @override
  String get callScreenControlCamOn => 'Ligar câmera';

  @override
  String get callScreenControlCamOff => 'Desligar câmera';

  @override
  String get callScreenControlFlip => 'Virar';

  @override
  String get callScreenControlSpeaker => 'Viva-voz';

  @override
  String get callAudioControlLabel => 'Áudio';

  @override
  String get callAudioSheetTitle => 'Áudio';

  @override
  String get callAudioRoutePhone => 'Celular';

  @override
  String get callAudioRouteHeadphones => 'Fones de ouvido';

  @override
  String get callAudioRouteBluetooth => 'Bluetooth';

  @override
  String get callAudioRouteCar => 'Carro';

  @override
  String get callAudioRouteOther => 'Outro dispositivo';

  @override
  String get callAudioMicFollowsNote =>
      'O microfone muda junto com o dispositivo escolhido.';

  @override
  String get callAudioMicrophoneHeader => 'Microfone';

  @override
  String get callAudioUnknownDevice => 'Dispositivo desconhecido';

  @override
  String get callAudioNoDevices => 'Nenhum dispositivo encontrado';

  @override
  String get callAudioSwitchFailed =>
      'Não foi possível trocar o dispositivo de áudio';

  @override
  String get callScreenControlEnd => 'Encerrar';

  @override
  String get linkPreviewCardLinkLabel => 'Link';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name aceitou seu pedido';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'Esse pedido foi retirado';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'Pedido recusado';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'Você bloqueou esse usuário. Desbloqueie primeiro.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'Essa pessoa não está aceitando pedidos de amizade no momento.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'Não foi possível enviar. Tente novamente.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => 'Pedido recebido';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'Novo pedido';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name quer começar uma conversa.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'manda algumas linhas. a pessoa pode aceitar ou recusar.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'Nada aqui é permanente até que os dois lados concordem.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'Tipo de sala';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'Efêmera';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'Padrão';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'Duração';

  @override
  String friendRequestDraftScreenDurationSeconds(Object seconds) {
    return '${seconds}s';
  }

  @override
  String friendRequestDraftScreenDurationMinutes(Object minutes) {
    return '${minutes}min';
  }

  @override
  String friendRequestDraftScreenDurationHours(Object hours) {
    return '${hours}h';
  }

  @override
  String get friendRequestDraftScreenHintWhisperOptional =>
      'Sussurre uma primeira linha · opcional';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'Adicione uma primeira mensagem · opcional';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'Sussurre · desaparece sozinho';

  @override
  String get friendRequestDraftScreenHintStartWith => 'Algo para começar';

  @override
  String get friendRequestDraftScreenApproveButton => 'Aprovar e abrir sala';

  @override
  String get friendRequestDraftScreenDeclineButton => 'Recusar';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'Cancelar pedido';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => 'Pergunte a um adulto';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'Enviar pedido';

  @override
  String get discoverScreenTitle => 'descobrir.';

  @override
  String get discoverScreenCaptionPeople => 'pessoas';

  @override
  String get discoverScreenCaptionRooms => 'salas';

  @override
  String get discoverScreenCaptionRequests => 'pedidos';

  @override
  String get discoverScreenPeopleBandLabel => 'Pessoas';

  @override
  String get discoverScreenRoomsBandLabel => 'Salas';

  @override
  String get discoverScreenFindPeopleTitle => 'Encontrar pessoas';

  @override
  String get discoverScreenFindPeopleSubtitleChild =>
      'Digite o nome de usuário completo';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'Busque por @usuário ou nome';

  @override
  String get discoverScreenRequestsSectionLabel => 'Pedidos';

  @override
  String get discoverScreenInboxQuiet => 'Caixa de entrada silenciosa';

  @override
  String get discoverScreenNothingPending => 'Nada enviado';

  @override
  String get discoverScreenYourPeopleLabel => 'Amigos';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'Ninguém ainda. Encontre pessoas acima';

  @override
  String get discoverScreenNoFriendsYet => 'Ninguém ainda';

  @override
  String get discoverScreenSearchRoomsTitle => 'Buscar salas';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'Encontre uma sala pública pelo nome';

  @override
  String get discoverScreenYourRoomsLabel => 'Salas';

  @override
  String get discoverScreenNoRoomsYet => 'Nenhuma sala ainda';

  @override
  String get discoverScreenIncomingLabel => 'Recebidos';

  @override
  String get discoverScreenOutgoingLabel => 'Enviados';

  @override
  String get discoverScreenIncomingLabelCaps => 'RECEBIDOS';

  @override
  String get discoverScreenOutgoingLabelCaps => 'ENVIADOS';

  @override
  String get discoverScreenJumpPeopleLabel => 'Pessoas';

  @override
  String get discoverScreenJumpRoomsLabel => 'Salas';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Ir para $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'Ajustar';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'Usar foto';

  @override
  String get imageCropScreenSavingButton => 'Salvando…';

  @override
  String get imageCropScreenCancelButton => 'Cancelar';

  @override
  String get imageCropScreenHeicUnsupported =>
      'Este navegador não consegue abrir fotos HEIC';

  @override
  String get imageCropScreenLoadFailed => 'Não foi possível abrir essa imagem';

  @override
  String get imageCropScreenHintCircle =>
      'Arraste para mover, belisque para dar zoom';

  @override
  String get imageCropScreenHintRect => 'Arraste e belisque para enquadrar';

  @override
  String get loginScreenSignInHeroMuted => 'bem-vindo\n';

  @override
  String get loginScreenSignInHeroInk => 'de volta.';

  @override
  String get loginScreenSignInFirstHeroMuted => 'olá\n';

  @override
  String get loginScreenSignInFirstHeroInk => 'tudo bem.';

  @override
  String get loginScreenSignInCta => 'ENTRAR';

  @override
  String get loginScreenSignUpHeroMuted => 'cara\n';

  @override
  String get loginScreenSignUpHeroInk => 'nova.';

  @override
  String get loginScreenSignUpCta => 'ABRIR CONTA';

  @override
  String get loginScreenResetHeroMuted => 'redefinir\n';

  @override
  String get loginScreenResetHeroInk => 'senha.';

  @override
  String get loginScreenResetCta => 'REDEFINIR SENHA';

  @override
  String get loginScreenErrorPasswordsDontMatch => 'As senhas não coincidem.';

  @override
  String get loginScreenErrorChoosePasswordFirst =>
      'Escolha uma senha primeiro.';

  @override
  String get loginScreenUsernameHint => 'nome de usuário';

  @override
  String get loginScreenPasswordHint => 'senha';

  @override
  String get loginScreenConfirmPasswordHint => 'confirmar senha';

  @override
  String get loginScreenNameOptionalHint => 'nome (opcional)';

  @override
  String get loginScreenRecoveryPhraseHint =>
      'sua frase de recuperação de 12 palavras';

  @override
  String get loginScreenNewPasswordHint => 'nova senha';

  @override
  String get loginScreenBackToSignIn => '← voltar para o login';

  @override
  String get loginScreenForgotPassword => 'esqueceu a senha?';

  @override
  String get loginScreenSettingUpKidsPhone => 'configurar uma conta infantil';

  @override
  String get loginScreenLegalPrefix =>
      'Ao abrir uma conta, você concorda com os ';

  @override
  String get loginScreenLegalTermsLink => 'Termos de Uso';

  @override
  String get loginScreenLegalMiddle => ' e a ';

  @override
  String get loginScreenLegalPrivacyLink => 'Política de Privacidade';

  @override
  String get loginScreenLegalSuffix => '.';

  @override
  String get loginScreenAlreadyHerePrompt => 'já tem conta? ';

  @override
  String get loginScreenSignInLink => 'entrar';

  @override
  String get loginScreenNoAccountPrompt => 'não tem conta? ';

  @override
  String get loginScreenOpenOneLink => 'abrir uma';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12 palavras';
  }

  @override
  String get homeShellEmptyRoomHint =>
      'escolha uma sala para começar a conversar';

  @override
  String get homeShellEmptySettingHint => 'escolha uma configuração';

  @override
  String get searchScreenHintPeople => 'Buscar pessoas';

  @override
  String get searchScreenHintRooms => 'Buscar salas públicas';

  @override
  String get searchScreenPeoplePromptChild =>
      'Digite o nome de usuário completo para encontrar alguém novo';

  @override
  String get searchScreenPeoplePromptDefault =>
      'busque por nome de usuário ou nome';

  @override
  String get searchScreenNoMatchChild =>
      'Ninguém encontrado. Gente nova precisa do nome de usuário\ncompleto, digitado exatamente';

  @override
  String get searchScreenNoMatchDefault => 'Ninguém encontrado';

  @override
  String get searchScreenNoRoomsYet => 'Ainda não há salas públicas';

  @override
  String get searchScreenNoRoomsMatch => 'Nenhuma sala pública corresponde';

  @override
  String get searchScreenActionAskToAdd => 'Pedir para adicionar';

  @override
  String get searchScreenActionSendRequest => 'Enviar pedido';

  @override
  String get searchScreenActionCancel => 'Cancelar';

  @override
  String get searchScreenActionApprove => 'Aprovar';

  @override
  String get searchScreenActionOpenDm => 'Abrir DM';

  @override
  String get searchScreenAskedLabel => 'pedido';

  @override
  String get profileVisibilityScreenTitle => 'preferências de visibilidade.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'controle o que os outros veem, e como podem chegar até você.';

  @override
  String get profileVisibilityScreenSectionProfile => 'PERFIL';

  @override
  String get profileVisibilityScreenAvatarLabel => 'AVATAR';

  @override
  String get profileVisibilityScreenAvatarDesc => 'sua foto de perfil';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => 'ONLINE / AUSENTE';

  @override
  String get profileVisibilityScreenOnlineAwayDesc =>
      'se você aparece como ativo agora';

  @override
  String get profileVisibilityScreenLastSeenLabel => 'VISTO POR ÚLTIMO';

  @override
  String get profileVisibilityScreenLastSeenDesc =>
      'a última vez que você esteve por aqui';

  @override
  String get profileVisibilityScreenSectionMessages => 'MENSAGENS';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel =>
      'ENVIAR CONFIRMAÇÕES DE LEITURA';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      'quando ativado, os outros podem ver que você leu as mensagens deles';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel =>
      'MOSTRAR CONFIRMAÇÕES DE LEITURA';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      'veja a marca \"VISTO\" nas suas próprias mensagens quando forem lidas';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      'somente quem ativou ENVIAR CONFIRMAÇÃO DE LEITURA vai contribuir. os outros continuam invisíveis.';

  @override
  String get profileVisibilityScreenSectionPeople => 'PESSOAS';

  @override
  String get profileVisibilityScreenFriendRequestsLabel =>
      'SOLICITAÇÕES DE AMIZADE';

  @override
  String get profileVisibilityScreenFriendRequestsDesc =>
      'quem pode te enviar solicitações de amizade';

  @override
  String get profileVisibilityScreenSupervisedTitle =>
      'OS GRANDES CONFIGURAM ISSO';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      'Você pode ver aqui tudo o que os outros veem, mas só os grandes podem mudar isso. Eles sempre podem ver sua foto, quando você está online e quando foi a última vez que você esteve por aqui.';

  @override
  String get profileVisibilityScreenOptionPublic => 'PÚBLICO';

  @override
  String get profileVisibilityScreenOptionFriends => 'AMIGOS';

  @override
  String get profileVisibilityScreenOptionNobody => 'NINGUÉM';

  @override
  String get profileVisibilityScreenOptionOn => 'ATIVADO';

  @override
  String get profileVisibilityScreenOptionOff => 'DESATIVADO';

  @override
  String get profileVisibilityScreenOptionAnyone => 'QUALQUER UM';

  @override
  String get logoScreenTitle => 'logo do app.';

  @override
  String get logoScreenSubtitle =>
      'o símbolo no seu cabeçalho, a escolha é sua.';

  @override
  String get logoScreenAutoLabel => 'AUTO';

  @override
  String get logoScreenAutoDescription =>
      'segue seu tema. o símbolo muda com a paleta.';

  @override
  String get logoScreenManualLabel => 'MANUAL';

  @override
  String get logoScreenManualDescription =>
      'escolha qualquer símbolo, mantenha seu tema.';

  @override
  String get logoScreenAlwaysDefaultLabel => 'SEMPRE PADRÃO';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      'o símbolo do MonkeyHub, independente do tema.';

  @override
  String get logoScreenActiveBadge => 'ATIVO';

  @override
  String get logoScreenMonkeyCollectionHeader => 'COLEÇÃO DE MACACOS';

  @override
  String get logoScreenThemesHeader => 'TEMAS';

  @override
  String get recoveryPhraseScreenCopiedSnackbar =>
      'Copiado. Cole em um lugar seguro';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'Confirme\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'que é você.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Sua senha, para que mais ninguém possa colocar uma frase de recuperação na sua conta.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'Senha';

  @override
  String get recoveryPhraseScreenContinueButton => 'CONTINUAR';

  @override
  String get recoveryPhraseScreenNotNowLink => 'agora não';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'Digite sua senha.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'Salve\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => 'essas palavras.';

  @override
  String get recoveryPhraseScreenWordsBody =>
      'Essas doze palavras são a única forma de voltar a entrar na sua conta caso você esqueça sua senha. Não podemos mostrá-las de novo, e não podemos recuperá-las para você.';

  @override
  String get recoveryPhraseScreenCopyButton => 'COPIAR';

  @override
  String get recoveryPhraseScreenPaperHint =>
      'Se puder, anote em papel. Tudo neste celular pode se perder junto com ele.';

  @override
  String get recoveryPhraseScreenSavedButton => 'SALVEI AS PALAVRAS';

  @override
  String get recoveryPhraseScreenBackLink => '← voltar';

  @override
  String get recoveryPhraseScreenKeepPhraseLink =>
      'agora não, manter minha frase atual';

  @override
  String get homeScreenProfileSemanticLabel => 'Seu perfil';

  @override
  String homeScreenGreeting(Object name) {
    return 'e aí, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'Nova sala';

  @override
  String get homeScreenEmptyRoomsMessage => 'Nenhuma sala ainda. Crie uma';

  @override
  String get groupCallScreenTitleVideo => 'Chamada de vídeo em grupo';

  @override
  String get groupCallScreenTitleVoice => 'Chamada de voz em grupo';

  @override
  String groupCallScreenParticipantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count na chamada',
      one: 'Só você',
    );
    return '$_temp0';
  }

  @override
  String get groupCallScreenReconnecting => 'Reconectando…';

  @override
  String get groupCallScreenUnmuteLabel => 'Ativar microfone';

  @override
  String get groupCallScreenMuteLabel => 'Desativar microfone';

  @override
  String get groupCallScreenCamOnLabel => 'Ligar câmera';

  @override
  String get groupCallScreenCamOffLabel => 'Desligar câmera';

  @override
  String get groupCallScreenFlipLabel => 'Virar';

  @override
  String get groupCallScreenSpeakerLabel => 'Alto-falante';

  @override
  String get groupCallScreenLeaveLabel => 'Sair';

  @override
  String get groupCallScreenYouLabel => 'Você';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return 'Filtrando por $summary. Alterar filtro';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => 'Filtrar conversas';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => 'Limpar filtro';

  @override
  String get roomFilterDrawerClearLabel => 'Limpar';

  @override
  String get roomFilterDrawerDimensionType => 'Tipo';

  @override
  String get roomFilterDrawerDimensionNature => 'Natureza';

  @override
  String get roomFilterDrawerDimensionStatus => 'Status';

  @override
  String get roomFilterDrawerPanelClear => 'Limpar';

  @override
  String get roomFilterDrawerPanelDone => 'Pronto';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversas',
      one: '$count conversa',
    );
    return '$label, $_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return 'Nada combina com $summary';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar todas as $count conversas',
      one: 'Mostrar $count conversa',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mostrar todas as $count conversas',
      one: 'Mostrar $count conversa',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'Nova sala';

  @override
  String get createRoomSheetTaglineSecret => 'Nada será guardado';

  @override
  String get createRoomSheetTaglineRegular => 'Um espaço que fica';

  @override
  String get createRoomSheetNameLabel => 'Nome';

  @override
  String get createRoomSheetNameHint => 'Dê um nome honesto';

  @override
  String get createRoomSheetDescriptionLabel => 'Descrição · opcional';

  @override
  String get createRoomSheetDescriptionHint => 'Uma linha sobre a sala';

  @override
  String get createRoomSheetVisibilityLabel => 'Visibilidade';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'Pública';

  @override
  String get createRoomSheetVisibilityPublicSub =>
      'Qualquer um consegue encontrar';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'Privada';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'Só com convite';

  @override
  String get createRoomSheetTypeLabel => 'Tipo';

  @override
  String get createRoomSheetTypeStandardTitle => 'Padrão';

  @override
  String get createRoomSheetTypeStandardSub => 'Mensagens permanecem';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'Efêmera';

  @override
  String get createRoomSheetTypeEphemeralSub => 'Mensagens se apagam sozinhas';

  @override
  String get createRoomSheetMessageLifeLabel => 'Vida da mensagem';

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
    return '${hours}h';
  }

  @override
  String get createRoomSheetPasswordLabel => 'Senha · opcional';

  @override
  String get createRoomSheetPasswordHint => 'Tranque com uma frase secreta';

  @override
  String get createRoomSheetNameRequiredError => 'Nome é obrigatório';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Abrir a sala';

  @override
  String get createRoomSheetOpenRoomButton => 'Abrir a sala';

  @override
  String get familyScreenTitle => 'FAMÍLIA';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count coisas precisam da sua aprovação',
      one: '1 coisa precisa da sua aprovação',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => 'online agora';

  @override
  String get familyScreenPresenceNotPaired => 'ainda não pareado';

  @override
  String get familyScreenPresenceJustNow => 'agora mesmo';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return '${minutes}min atrás';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return '${hours}h atrás';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return '${days}d atrás';
  }

  @override
  String get familyScreenPairButton => 'PAREAR';

  @override
  String get familyScreenReleaseButton => 'DESVINCULAR';

  @override
  String get familyScreenSettingsButton => 'CONFIGURAÇÕES';

  @override
  String get familyScreenAddChildButton => 'ADICIONAR CRIANÇA';

  @override
  String get familyScreenEmptyStateTitle => 'nenhuma criança ainda';

  @override
  String get familyScreenEmptyStateBody =>
      'Crie uma conta para a sua criança, depois pareie com o celular dela.';

  @override
  String get reactionDetailsSheetTitle => 'Reações';

  @override
  String get reactionDetailsSheetEmptyState => 'Não tem mais nada aqui';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas',
      one: '1 pessoa',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => 'Todos';

  @override
  String get reactionDetailsSheetYouBadge => 'Você';

  @override
  String get roomLayoutScreenTitle => 'lista de conversas.';

  @override
  String get roomLayoutScreenSubtitle =>
      'como as salas se organizam e como você as filtra';

  @override
  String get roomLayoutScreenLayoutSectionLabel => 'LAYOUT';

  @override
  String get roomLayoutScreenRowLayoutLabel => 'LAYOUT EM LINHA';

  @override
  String get roomLayoutScreenRowLayoutDescription =>
      'uma coluna, ocupa a largura toda. fácil de ler de relance.';

  @override
  String get roomLayoutScreenGridLayoutLabel => 'LAYOUT EM GRADE';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      'duas colunas, compacto. mais salas em um único olhar.';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => 'CONTROLE DE FILTRO';

  @override
  String get roomLayoutScreenChipRowLabel => 'LINHA DE CHIPS';

  @override
  String get roomLayoutScreenChipRowDescription =>
      'sempre visível. um toque para qualquer filtro, uma linha de espaço.';

  @override
  String get roomLayoutScreenDrawerButtonLabel => 'BOTÃO DE GAVETA';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      'um botão que abre. nada no caminho até você pedir.';

  @override
  String get roomLayoutScreenQuietRoomSectionLabel => 'SALAS EM SILÊNCIO';

  @override
  String get roomLayoutScreenPlainCornerLabel => 'canto vazio';

  @override
  String get roomLayoutScreenPlainCornerDescription =>
      'uma sala sem mensagens fica nua';

  @override
  String get roomLayoutScreenMonogramLabel => 'a inicial da sala';

  @override
  String get roomLayoutScreenMonogramDescription =>
      'uma letra grande e apagada preenche o canto';

  @override
  String get roomLayoutScreenActiveBadge => 'ATIVO';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel =>
      'Ir para a mensagem fixada';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => 'Todas as mensagens fixadas';

  @override
  String get pinnedBannerTitleSingle => 'Mensagem fixada';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return 'Mensagem fixada  $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => 'estilo do chat.';

  @override
  String get pinnedBannerChatStyleSubtitle => 'como a sala parece';

  @override
  String get pinnedBannerClassicLabel => 'CLÁSSICO';

  @override
  String get pinnedBannerClassicSubtitle =>
      'cabeçalho com borda divisória, caixa de mensagem simples.';

  @override
  String get pinnedBannerCompactLabel => 'COMPACTO';

  @override
  String get pinnedBannerCompactSubtitle =>
      'cápsulas foscas flutuando sobre a conversa.';

  @override
  String get pinnedBannerActiveBadge => 'ATIVO';

  @override
  String get audioMessageMissingLabel => '[áudio ausente]';

  @override
  String get audioMessageUnavailableLabel => 'Áudio indisponível';

  @override
  String get audioMessageRetryHint => 'Toque para tentar novamente';

  @override
  String get audioMessageLoadingLabel => 'Carregando…';

  @override
  String get audioMessageUsernameRequiredError => 'Digite seu nome de usuário.';

  @override
  String get audioMessagePasswordRequiredError => 'Digite sua senha.';

  @override
  String get audioMessageCancelSemanticLabel => 'Cancelar';

  @override
  String get audioMessageHeroCreateLine1 => 'quase\n';

  @override
  String get audioMessageHeroCreateLine2 => 'lá.';

  @override
  String get audioMessageHeroLinkLine1 => 'bem-vindo\n';

  @override
  String get audioMessageHeroLinkLine2 => 'de volta.';

  @override
  String get audioMessageCreateSubtitle =>
      'Escolha um nome de usuário para que sua família e amigos consigam te encontrar.';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return 'Entre uma vez e o $provider fica vinculado à sua conta.';
  }

  @override
  String get audioMessageUsernameHint => 'Nome de usuário';

  @override
  String get audioMessageDisplayNameHint => 'Nome de exibição (opcional)';

  @override
  String get audioMessagePasswordHint => 'Senha';

  @override
  String get audioMessageSwitchToLinkPrompt => 'Essa conta é minha, entrar';

  @override
  String get audioMessageCreateAccountButton => 'Criar conta';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return 'ENTRAR E VINCULAR $provider';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => 'Já tem uma conta?';

  @override
  String get audioMessageSwitchToCreateModeLink =>
      'Novo por aqui? Criar uma conta';

  @override
  String get approvalsScreenTitle => 'APROVAÇÕES';

  @override
  String get approvalsScreenEmptyTitle => 'nada pendente';

  @override
  String get approvalsScreenEmptySubtitle => 'está tudo em dia';

  @override
  String get approvalsScreenErrorNotGuardian => 'essa decisão não é sua';

  @override
  String get approvalsScreenErrorAlreadyHandled =>
      'já foi resolvido em outro lugar';

  @override
  String get approvalsScreenErrorGeneric =>
      'não foi possível salvar. Tente de novo';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child quer adicionar $other';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other quer adicionar $child';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child quer entrar em $room';
  }

  @override
  String get approvalsScreenSomeoneLower => 'alguém';

  @override
  String get approvalsScreenSomeoneCapital => 'Alguém';

  @override
  String get approvalsScreenRoomFallback => 'uma sala';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      'Essa pessoa vai receber o pedido. A decisão de aceitar ou não continua sendo dela.';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$child vai ver o pedido e pode aceitar ou ignorar.';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      'Essa pessoa vai poder ler e postar lá até você revogar o acesso.';

  @override
  String get approvalsScreenNotYetButton => 'AGORA NÃO';

  @override
  String get approvalsScreenAllowButton => 'PERMITIR';

  @override
  String get approvalsScreenForwardDirectMessageFallback => 'Mensagem direta';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encaminhar $count mensagens',
      one: 'Encaminhar mensagem',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'Nenhum outro chat ainda';

  @override
  String get approvalsScreenForwardNoMatches => 'Nada encontrado';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'Até $max chats por vez';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'Buscar chats';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Desmarcar $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Selecionar $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'Some';

  @override
  String get approvalsScreenForwardSendSemantic => 'Enviar';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar para $count',
      zero: 'Enviar',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => 'CONTAS VINCULADAS';

  @override
  String get linkedAccountsScreenSubtitle =>
      'Contas que você vinculou a esta, para você conseguir entrar sem digitar senha.';

  @override
  String get linkedAccountsScreenEmptyState =>
      'Não há nada para vincular neste dispositivo.';

  @override
  String get linkedAccountsScreenStatusChecking => 'Verificando…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return 'Você pode entrar com $provider em qualquer um dos seus dispositivos.';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return 'Adicione $provider para não precisar digitar sua senha.';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return 'DESVINCULAR $provider';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => 'DESVINCULAR';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return 'Digite sua senha para parar de entrar com $provider.';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return 'VINCULAR $provider';
  }

  @override
  String get linkedAccountsScreenLinkAction => 'VINCULAR';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return 'Digite sua senha para adicionar $provider como uma forma de entrar.';
  }

  @override
  String get linkedAccountsScreenPillChecking => 'VERIFICANDO';

  @override
  String get linkedAccountsScreenPillLinked => 'VINCULADA';

  @override
  String get linkedAccountsScreenPillNotLinked => 'NÃO VINCULADA';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => 'Voz';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'Vídeo';

  @override
  String get linkedAccountsScreenCallSheetTitle => 'Iniciar uma chamada';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle =>
      'Ligar para todos';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      'Liga para todos os membros desta sala';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle =>
      'Escolher pessoas';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle =>
      'Escolha quem convidar';

  @override
  String get linkedAccountsScreenCallSheetCallFullError =>
      'Essa chamada está cheia (máx. 6 pessoas)';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError =>
      'Não foi possível iniciar a chamada';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle =>
      'Convidar para a chamada';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers =>
      'Não há outros membros aqui';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => 'Selecionar pessoas';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => 'Iniciar chamada';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return 'Iniciar chamada ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => 'oi';

  @override
  String get childPairScreenGreetingLine2 => 'você.';

  @override
  String get childPairScreenIntro =>
      'Peça para um adulto abrir o MonkeyHub e tocar em “parear um dispositivo”. Depois, escaneie o código dele ou digite os seis números que ele disser em voz alta.';

  @override
  String get childPairScreenOrDivider => 'ou';

  @override
  String get childPairScreenGenericError => 'Algo deu errado. Tente de novo.';

  @override
  String get profileScreenDeleteAccountFailed =>
      'Algo deu errado. Tente de novo.';

  @override
  String get childPairScreenAccountGoneError => 'Essa conta não existe mais.';

  @override
  String get childPairScreenScanButtonLabel => 'ESCANEAR CÓDIGO DELE';

  @override
  String get childPairScreenNoCameraMessage =>
      'Sem câmera aqui. Digite os seis números.';

  @override
  String get childPairScreenStopScanning => 'Parar de escanear';

  @override
  String get childPairScreenSubmitButtonLabel => 'ME DEIXA ENTRAR';

  @override
  String get childPairScreenBackToSignIn => '← voltar para o login';

  @override
  String get fileMessageUnavailable => 'o arquivo não está mais disponível';

  @override
  String get fileMessageOpenFailed => 'não foi possível abrir esse arquivo';

  @override
  String get fileMessageDefaultName => 'documento';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return 'Salvar $name';
  }

  @override
  String fileMessageViewSemanticLabel(Object name) {
    return 'Ver $name';
  }

  @override
  String get textFileViewerDownloadTooltip => 'Baixar';

  @override
  String get textFileViewerTruncatedNotice =>
      'Mostrando parte deste arquivo. Baixe-o para ver o resto.';

  @override
  String get fileMessageUploadFailedLabel => 'falhou';

  @override
  String get fileMessageSendingLabel => 'enviando…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · enviando…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return '${count}min atrás';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return '${count}h atrás';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return '${count}d atrás';
  }

  @override
  String get fileMessageStandardBadge => 'Padrão';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rascunhos de mensagem · toque para ver',
      one: '$count rascunho de mensagem · toque para ver',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => 'Aprovar';

  @override
  String get fileMessageDeclineButton => 'Recusar';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'Enviado $ago';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens pendentes',
      one: '$count mensagem pendente',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => 'Cancelar pedido';

  @override
  String get destructiveSheetCannotBeUndone => 'isso não pode ser desfeito';

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
      'Não foi possível criar um código. Tente de novo.';

  @override
  String get destructiveSheetPairingReleaseTitle => 'LIBERAR';

  @override
  String get destructiveSheetPairingPairTitle => 'PAREAR';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return 'No celular de $name, abra o perfil, toque em “devolver o celular” e digite estes números.';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return 'No celular de $name, abra o MonkeyHub e escaneie isto, ou digite os números.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'Este código expirou';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'Expira em $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'Novo código';

  @override
  String get destructiveSheetPairingOneUseNote =>
      'Uso único. Criar um novo código cancela o anterior.';

  @override
  String get deepOceanThemeAttachButtonLabel => 'Anexar';

  @override
  String get deepOceanThemeCameraButtonLabel => 'Câmera';

  @override
  String get deepOceanThemeSendButtonLabel => 'Enviar';

  @override
  String get deepOceanThemeEphemeralHint => 'Sussurre algo';

  @override
  String get deepOceanThemeDefaultHint => 'Diga algo';

  @override
  String get deepOceanThemeMessageHint => 'Mensagem';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'Este arquivo sumiu';

  @override
  String get photoChromeMediaYouLabel => 'Você';

  @override
  String get photoChromeCloseSemanticLabel => 'Fechar';

  @override
  String get photoChromeFillToggleSemanticLabel =>
      'Ajustar ou preencher a tela';

  @override
  String get photoChromeShowInChatSemanticLabel => 'Mostrar no chat';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return 'Item $current de $total';
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
  String get photoDeckBackToFirst => 'Voltar para a primeira';

  @override
  String get inlinePickerCommentHint => 'Adicione um comentário ou envie';

  @override
  String get attachmentMenuGalleryLabel => 'Galeria';

  @override
  String inlinePickerVideoCompressNote(String size) {
    return 'Passa de $size, então vai ser comprimido para enviar';
  }

  @override
  String messageMenuAlbumAll(int count) {
    return 'Todos ($count)';
  }

  @override
  String get messageMenuAlbumOne => 'Só este';

  @override
  String replyAlbumItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => 'Descartar estas fotos';

  @override
  String get photoTrayRemoveSemanticLabel => 'Remover esta foto';

  @override
  String get photoTrayEditSemanticLabel => 'Cortar ou desenhar nesta foto';

  @override
  String get photoTrayAddMoreSemanticLabel => 'Adicionar mais fotos';

  @override
  String photoTrayLimitSnack(Object count) {
    return 'Você pode enviar $count fotos por vez';
  }

  @override
  String get photoTrayLoadFailedSnack =>
      'Algumas dessas fotos não puderam ser abertas';

  @override
  String get mediaPickFailedMessage =>
      'Não deu pra abrir. Tente escolher de novo';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name está digitando';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1 e $name2 estão digitando';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1, $name2 +$extra estão digitando';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => 'Chamada recebida';

  @override
  String get typingIndicatorIncomingVideoCallLabel =>
      'Chamada de vídeo recebida';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'Chamada de voz recebida';

  @override
  String get typingIndicatorDeclineButtonLabel => 'Recusar';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'Recusando…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'Aceitar';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'Conectando…';

  @override
  String get messageStampNavigationTitle => 'navegação.';

  @override
  String get messageStampNavigationSubtitle =>
      'como você se move entre chat, descobrir, feed e configurações';

  @override
  String get messageStampRadialOrbLabel => 'ORBE RADIAL';

  @override
  String get messageStampRadialOrbDescription =>
      'segure e arraste a partir do canto. discreto em repouso, um gesto que você vai aprendendo aos poucos.';

  @override
  String get messageStampBottomPillLabel => 'CÁPSULA INFERIOR';

  @override
  String get messageStampBottomPillDescription =>
      'toque clássico. sempre visível, sem curva de aprendizado.';

  @override
  String get messageStampActiveLabel => 'ATIVO';

  @override
  String get messageStampUploadingLabel => 'enviando anexo';

  @override
  String get messageStampSendingLabel => 'enviando';

  @override
  String get messageStampFailedToSendLabel => 'falha ao enviar';

  @override
  String get messageStampSentLabel => 'enviado';

  @override
  String get messageStampDeliveredLabel => 'entregue';

  @override
  String get messageStampSeenLabel => 'visto';

  @override
  String get messageStampSavedLabel => 'salva';

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
      'Permissão do microfone negada';

  @override
  String get voiceRecorderScreenStatusRecording => 'Gravando';

  @override
  String get voiceRecorderScreenStatusReady => 'Pronto';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'Toque para começar';

  @override
  String get voiceRecorderScreenReRecordButton => 'Regravar';

  @override
  String get voiceRecorderScreenStopButton => 'Parar';

  @override
  String get voiceRecorderScreenSendButton => 'Enviar';

  @override
  String get voiceRecorderScreenRecordButton => 'Gravar';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => 'Todos';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => 'NOTIFICA TODOS';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => 'DONO';

  @override
  String get releaseDeviceScreenFallbackChildName => 'a criança';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return 'Isso desconecta $name deste telefone e o devolve: o telefone volta para a tela de login normal, e qualquer pessoa pode usá-lo.';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'A conta, as mensagens e os amigos continuam guardados. Dá para fazer login de novo quando quiser.';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return 'Peça para alguém grande abrir o MonkeyHub, encontrar $name na aba família e tocar em “liberar”.';
  }

  @override
  String get releaseDeviceScreenOrDivider => 'ou';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      'Se esse for o único telefone, alguém grande pode entrar por aqui.';

  @override
  String get releaseDeviceScreenUsernameHint =>
      'nome de usuário de alguém grande';

  @override
  String get releaseDeviceScreenPasswordHint => 'a senha dessa pessoa';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => 'Sair';

  @override
  String get releaseDeviceScreenChecking => 'VERIFICANDO…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return 'DESCONECTAR $name';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => 'DEVOLVA ESTE CELULAR';

  @override
  String get releaseDeviceScreenErrorCodeExpired =>
      'Esse código expirou. Peça um novo.';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      'Esse código não funcionou. Pode já ter sido usado.';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      'Isso não funcionou. Confira o nome de usuário e a senha.';

  @override
  String get releaseDeviceScreenErrorGeneric =>
      'Algo deu errado. Tente de novo.';

  @override
  String get activeCallPillMoveHereSemanticLabel =>
      'Mover a chamada para este dispositivo';

  @override
  String activeCallPillCallWith(Object name) {
    return 'Chamada com $name';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return 'Em $device';
  }

  @override
  String get activeCallPillMoveHereLabel => 'Mover aqui';

  @override
  String get activeCallPillUnknownCaller => 'Desconhecido';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'Simulador do iOS';

  @override
  String get activeCallPillPlatformAndroid => 'Dispositivo Android';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'PC Windows';

  @override
  String get activeCallPillPlatformLinux => 'Dispositivo Linux';

  @override
  String get activeCallPillPlatformBrowser => 'Navegador';

  @override
  String get activeCallPillPlatformOther => 'outro dispositivo';

  @override
  String get activeCallPillPinnedHeader => 'Fixados';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'Fixados · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'Nada mais fixado';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Ir para a mensagem de $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Desafixar mensagem de $name';
  }

  @override
  String get callButtonErrorBusy => 'Ocupado em outra chamada';

  @override
  String get callButtonErrorCallFailed => 'Não foi possível iniciar a chamada';

  @override
  String get callButtonErrorNotMember => 'Não é membro desta sala';

  @override
  String get callButtonErrorGeneric => 'Não foi possível iniciar a chamada';

  @override
  String get callButtonAlreadyOnCall => 'Você já está em uma chamada';

  @override
  String get callButtonBusyElsewhere =>
      'Chamada em andamento em outro dispositivo';

  @override
  String get callButtonVoiceCallTooltip => 'Chamada de voz';

  @override
  String get callButtonVideoCallTooltip => 'Chamada de vídeo';

  @override
  String get callButtonTooltip => 'chamada';

  @override
  String get callButtonReplyStyleTitle => 'estilo de resposta.';

  @override
  String get callButtonReplyStyleSubtitle =>
      'como uma resposta mostra a mensagem original';

  @override
  String get callButtonReplyStylePhantomEchoLabel => 'ECO FANTASMA';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      'a bolha fantasma da mensagem original flutua acima, com um conector curvo e o ícone de ramificação no ponto de junção.';

  @override
  String get callButtonReplyStyleStickyNoteLabel => 'NOTA ADESIVA';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      'um cartão estilo polaroide levemente girado, preso ao canto da bolha.';

  @override
  String get callButtonReplyStyleComicTailLabel => 'RABICHO DE HQ';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      'uma mini-bolha da mensagem original com um rabicho triangular estilo HQ apontando para baixo.';

  @override
  String get callButtonReplyStyleClassicLabel => 'CLÁSSICO';

  @override
  String get callButtonReplyStyleClassicDescription =>
      'cápsula de citação na cor de destaque, com barra de conexão e avatar: aquele visual clássico e familiar do WhatsApp.';

  @override
  String get callButtonReplyStyleActiveBadge => 'ATIVO';

  @override
  String get callButtonReplyPreviewSampleMessage =>
      'ei, você já viu a nova demo?';

  @override
  String get callButtonReplyPreviewSampleReply => 'aham, esse blur é irado.';

  @override
  String get childSetupScreenErrorPickUsername =>
      'Escolha um nome de usuário para a criança.';

  @override
  String get childSetupScreenErrorUsernameTaken =>
      'Esse nome de usuário já está em uso.';

  @override
  String get childSetupScreenErrorChildNotAllowed =>
      'Só uma conta de gente grande pode adicionar uma criança.';

  @override
  String get childSetupScreenErrorGeneric =>
      'Não foi possível criar a conta. Tente de novo.';

  @override
  String get childSetupScreenTitle => 'ADICIONAR CRIANÇA';

  @override
  String get childSetupScreenHeading => 'quem\né?';

  @override
  String get childSetupScreenNameLabel => 'NOME';

  @override
  String get childSetupScreenNameHint => 'como você chama essa pessoa';

  @override
  String get childSetupScreenUsernameLabel => 'NOME DE USUÁRIO';

  @override
  String get childSetupScreenUsernameHint =>
      'como os amigos encontram essa pessoa';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'O QUE A CRIANÇA GANHA';

  @override
  String get childSetupScreenBulletTalkImmediately =>
      'Ela já pode conversar com você e com os irmãos na hora.';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      'Para todo o resto, é preciso da sua aprovação antes, tanto quando ela pedir para adicionar alguém quanto quando pedirem para adicioná-la.';

  @override
  String get childSetupScreenBulletPublicRoomsOff =>
      'As salas públicas ficam desativadas até você ativá-las.';

  @override
  String get childSetupScreenBulletCantSignOut =>
      'Ela não consegue sair da conta, e você sempre pode ver como ela está indo.';

  @override
  String get childSetupScreenCreateButton => 'CRIAR + PAREAR';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return 'Enviar mensagem para $name';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => 'Pedido';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'MEMBROS';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'Ver todos ($count)';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return 'Ver todos ($count)';
  }

  @override
  String get bubbleStyleScreenTitle => 'estilo do balão.';

  @override
  String get bubbleStyleScreenSubtitle =>
      'o formato em que suas palavras chegam';

  @override
  String get bubbleStyleScreenTailedLabel => 'COM RABICHO';

  @override
  String get bubbleStyleScreenTailedDescription =>
      'um rabicho fecha cada sequência de mensagens; as linhas acima dele se juntam em um bloco só.';

  @override
  String get bubbleStyleScreenSoftLabel => 'SUAVE';

  @override
  String get bubbleStyleScreenSoftDescription =>
      'sem rabicho: uma sequência se mantém unida só pelos cantos internos apertados.';

  @override
  String get bubbleStyleScreenPillLabel => 'CÁPSULA';

  @override
  String get bubbleStyleScreenPillDescription =>
      'cápsulas totalmente arredondadas, idênticas em cada linha.';

  @override
  String get bubbleStyleScreenSlabLabel => 'BLOCO';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'ombros quadrados: nítidos, impressos, deliberados.';

  @override
  String get bubbleStyleScreenActiveBadge => 'ATIVO';

  @override
  String get bubbleStyleScreenPreviewQuestion => 'e aí? como ficou';

  @override
  String get bubbleStyleScreenPreviewReplyOne => 'melhor';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => 'muito melhor';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => 'Vídeo';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => 'Foto';

  @override
  String get incomingGroupCallScreenCallFullError =>
      'Essa chamada está cheia (máx. 6 pessoas)';

  @override
  String get incomingGroupCallScreenJoinFailedError =>
      'Não foi possível entrar na chamada';

  @override
  String get incomingGroupCallScreenDefaultRoomName => 'Chamada em grupo';

  @override
  String get incomingGroupCallScreenDefaultStarterName => 'Alguém';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starter iniciou uma chamada de vídeo';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starter iniciou uma chamada de voz';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '$count já dentro';
  }

  @override
  String get incomingGroupCallScreenDismissButton => 'Recusar';

  @override
  String get incomingGroupCallScreenJoinButton => 'Entrar';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversas',
      one: '$count conversa',
    );
    return '$_temp0';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens',
      one: '$count mensagem',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      'Última mensagem agora mesmo';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'Última mensagem há ${hours}h';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'Última mensagem ontem';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'Última mensagem há $days dias';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'Última mensagem há um tempo';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'Tirar';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return 'Tirar $contactName de $childName?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'Eles não vão mais conseguir se falar, e a conversa deles vai junto.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'Eles não vão mais conseguir se falar. $contactName não vai receber um aviso.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats · $messages serão apagadas';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      'Some para os dois, incluindo fotos e áudios. Isso não pode ser desfeito.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Eles também compartilham $count salas',
      one: 'Eles também compartilham $count sala',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'Elas continuam aqui. Retome a sala na lista de Salas abaixo se quiser tirá-la de lá.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'Retomar e excluir';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'Remove $contactName e apaga $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'Remove $contactName da lista de permitidos.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Cancelar';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton =>
      'Cancelar';

  @override
  String get groupCallBannerCallFullError =>
      'Essa chamada está cheia (máx. 6 pessoas)';

  @override
  String get groupCallBannerJoinFailedError =>
      'Não foi possível entrar na chamada';

  @override
  String get groupCallBannerUnknownParticipant => 'Alguém';

  @override
  String get groupCallBannerOngoingVideoCall => 'Chamada de vídeo em andamento';

  @override
  String get groupCallBannerOngoingVoiceCall => 'Chamada de voz em andamento';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra na chamada';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => 'Entrar na chamada';

  @override
  String get groupCallBannerJoinButtonLabel => 'Entrar';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'Entrar na sala';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '$count membro',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => 'Senha';

  @override
  String get groupCallBannerPasswordHint => 'Frase secreta';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Entrar';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'Entrar';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Cancelar';

  @override
  String get groupCallBannerCancelButtonLabel => 'Cancelar';

  @override
  String get viewOnceViewerBadgeLabel => 'Ver uma vez';

  @override
  String get socialButtonDividerOr => 'ou';

  @override
  String get socialButtonGoogleContinue => 'Continuar com o Google';

  @override
  String get discoverListsPeopleTitle => 'Amigos';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas',
      one: '$count pessoa',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => 'Buscar amigos';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Limpar filtro';

  @override
  String get discoverListsNoOneYet => 'Ninguém ainda';

  @override
  String discoverListsNoMatches(Object query) {
    return 'Ninguém encontrado para \"$query\"';
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
  String get discoverListsFilterRoomsHint => 'Buscar nas suas salas';

  @override
  String get discoverListsNoRoomsYet => 'Nenhuma sala ainda';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return 'Nenhuma sala encontrada para \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'CHAMADA DE VOZ';

  @override
  String get discoverListsVideoCallLabel => 'CHAMADA DE VÍDEO';

  @override
  String get approvalGateAlreadyAskedLabel => 'Já pediu';

  @override
  String get approvalGateAskGrownUpLabel => 'Peça a um adulto';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return 'Você já perguntou sobre $what.';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return 'Você precisa que um adulto diga sim antes de poder $what.';
  }

  @override
  String get approvalGateDisabledBody =>
      'Um adulto desativou isso por enquanto.';

  @override
  String get approvalGateAlreadyAskedFooter =>
      'Essa pessoa vai receber uma mensagem sobre isso. Volte a conferir em breve.';

  @override
  String get approvalGateWillNotifyFooter =>
      'Vamos avisar essa pessoa. Você vai ver a resposta aqui quando ela responder.';

  @override
  String get approvalGateTalkToThemFooter =>
      'Você pode conversar com essa pessoa sobre isso se achar que deveria mudar.';

  @override
  String get approvalGateAskButton => 'Pedir';

  @override
  String get approvalGateNotNowButton => 'AGORA NÃO';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => 'Esperando um adulto';

  @override
  String get reportSheetTitle => 'DENÚNCIA';

  @override
  String get reportSheetSubtitle => 'conte pra gente o que está errado.';

  @override
  String get reportSheetPrivacyNote =>
      'denúncias são privadas. A outra pessoa não é avisada.';

  @override
  String get reportSheetReasonSpamLabel => 'SPAM';

  @override
  String get reportSheetReasonSpamDescription =>
      'anúncios indesejados ou mensagens repetidas';

  @override
  String get reportSheetReasonHarassmentLabel => 'ASSÉDIO';

  @override
  String get reportSheetReasonHarassmentDescription =>
      'perseguição ou bullying';

  @override
  String get reportSheetReasonImpersonationLabel => 'PERSONIFICAÇÃO';

  @override
  String get reportSheetReasonImpersonationDescription =>
      'fingindo ser outra pessoa';

  @override
  String get reportSheetReasonInappropriateLabel => 'INAPROPRIADO';

  @override
  String get reportSheetReasonInappropriateDescription =>
      'conteúdo sexual, violento ou ilegal';

  @override
  String get reportSheetReasonOtherLabel => 'OUTRO';

  @override
  String get reportSheetReasonOtherDescription => 'outra coisa';

  @override
  String get reportSheetOtherNoteHint => 'o que aconteceu?';

  @override
  String get reportSheetSubmitSemanticLabel => 'Enviar denúncia';

  @override
  String get reportSheetSubmitButton => 'ENVIAR';

  @override
  String get reportSheetUpdateRequiredTitle => 'Atualização necessária';

  @override
  String get reportSheetUpdateAvailableTitle => 'Atualização disponível';

  @override
  String get reportSheetUpdateMandatoryBody =>
      'Essa versão está velha demais para continuar funcionando direito. Atualize para continuar.';

  @override
  String get reportSheetUpdateAvailableBody =>
      'Uma versão mais nova do MonkeyHub está disponível.';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => 'Atualizar';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'Abre o TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'Abre a App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'Abre o Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'Abre a página de download';

  @override
  String get reportSheetUpdateActionReloads => 'Recarrega com a nova versão';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Depois';

  @override
  String get reportSheetUpdateLaterButton => 'Depois';

  @override
  String get roomFilterBarAllChipLabel => 'Tudo';

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
    return 'Respondendo a $name';
  }

  @override
  String get roomCardLockedBadge => 'Trancada';

  @override
  String get roomCardTimeAgoJustNow => 'agora mesmo';

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
    return '${weeks}sem';
  }

  @override
  String roomCardStartedAgo(Object ago) {
    return 'Criada há $ago';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count dentro';
  }

  @override
  String get roomCardMessagesFadeLabel => 'Mensagens somem';

  @override
  String get roomCardEnterLabel => '↗ Entrar';

  @override
  String get roomCardBlockedScreenTitle => 'BLOQUEADOS';

  @override
  String get roomCardBlockedEmptyState => 'você ainda não bloqueou ninguém.';

  @override
  String get roomCardUnblockButton => 'DESBLOQUEAR';

  @override
  String get attachmentMenuPhotoLabel => 'Foto';

  @override
  String get attachmentMenuVideoLabel => 'Vídeo';

  @override
  String get attachmentMenuCameraLabel => 'Câmera';

  @override
  String get attachmentMenuVoiceLabel => 'Voz';

  @override
  String get attachmentMenuFileLabel => 'Arquivo';

  @override
  String get attachmentMenuConnectionRetrying => 'Tentando novamente…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'Não foi possível conectar ao servidor · Toque para tentar novamente';

  @override
  String get attachmentMenuConnectionReconnecting => 'Reconectando…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Tentar conexão novamente';

  @override
  String get roomGridTileEmptyLastMessage => 'quieto por enquanto';

  @override
  String get roomGridTileMemberCountLabel => 'Dentro';

  @override
  String get roomGridTileThemeChipLabel => 'TEMA';

  @override
  String get bulkActionBarCancelLabel => 'Cancelar';

  @override
  String get bulkActionBarSelectMessagesLabel => 'Selecionar mensagens';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count selecionadas';
  }

  @override
  String get bulkActionBarForwardLabel => 'Encaminhar';

  @override
  String get bulkActionBarDeleteLabel => 'Excluir';

  @override
  String get bulkActionBarJumpBackLabel => 'VOLTAR';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return 'VOLTAR · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel =>
      'Voltar para onde você pulou';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return 'Voltar para onde você pulou, faltam $depth';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote =>
      'A pessoa não vai ser notificada.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'Vocês são amigos no momento. Bloquear encerra a amizade, então para se reconectar depois você vai precisar enviar um novo pedido de amizade.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'A pessoa vai sumir das suas buscas e não vai conseguir te mandar mensagem.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'Bloquear';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return 'Bloquear $name?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Você compartilha $count salas com essa pessoa',
      one: 'Você compartilha $count sala com essa pessoa',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'Essas salas continuam intactas. Você pode sair de qualquer uma delas nas configurações de cada sala.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'Bloquear';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'Remove a amizade e bloqueia. O histórico de conversa existente continua no seu arquivo.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'A pessoa fica escondida das buscas e não consegue te alcançar.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'Bloquear e excluir DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'Também apaga sua DM com essa pessoa: todas as mensagens, reações e arquivos de mídia somem.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Cancelar';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'Cancelar';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle =>
      'Mostrar chamadas na tela de bloqueio';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      'Para tocar como uma ligação de verdade quando sua tela estiver desligada, o MonkeyHub precisa que as \"notificações em tela cheia\" estejam ativadas. A próxima tela te leva direto para essa opção.';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle =>
      'Nunca perca uma chamada';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      'Alguns celulares pausam apps em segundo plano para economizar bateria, o que pode silenciar chamadas recebidas. Permita que o MonkeyHub funcione sem restrições para que as chamadas sempre cheguem até você.';

  @override
  String get bulkActionBarDialogNotNowButton => 'Agora não';

  @override
  String get bulkActionBarDialogContinueButton => 'Continuar';

  @override
  String get reactionBubbleJumpToLatestLabel => 'IR PARA A MAIS RECENTE';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel =>
      'Ir para a mais recente';

  @override
  String get reactionBubblePickerTitle => 'Reagir';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'Ainda sem recentes';

  @override
  String get reactionBubbleSearchHint => 'Buscar emoji';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'Nenhum resultado';

  @override
  String get reactionBubbleSearchBackSemanticLabel => 'Voltar aos emojis';

  @override
  String get reactionBubblePasswordHint => 'senha';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return 'entrar em $roomName';
  }

  @override
  String get enterPublicRoomAskFailedMessage =>
      'Não deu para pedir agora. Tente de novo';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'senha errada';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'não deu pra entrar. Tente de novo';

  @override
  String get feedBoardTitle => 'HOJE';

  @override
  String feedBoardEditionLabel(Object number) {
    return 'Nº$number';
  }

  @override
  String get feedBoardHighlightsLabel => 'Destaques';

  @override
  String get feedBoardHighlightsEmpty => 'Ainda não tem nada capturado hoje';

  @override
  String get feedBoardPuzzleLabel => 'O ENIGMA';

  @override
  String get feedBoardPuzzleEmpty => 'o enigma de hoje ainda não está pronto';

  @override
  String get feedBoardStandingsLabel => 'Pontos de vida';

  @override
  String get feedBoardStandingsEmpty => 'Nenhum ponto no placar hoje';

  @override
  String get feedBoardActivityLabel => 'Atividade';

  @override
  String get feedBoardActivityEmpty => 'hoje está calmo por enquanto';

  @override
  String get feedBoardActivityNoFriends =>
      'Adicione um amigo e o dia dele aparece aqui';

  @override
  String get feedBoardLoadFailed =>
      'Não foi possível carregar o quadro. Tente daqui a pouco';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'Pública';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'Privada';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'Participando';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'Efêmera · $duration';
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
  String get roomBadgePublicTooltip =>
      'Qualquer pessoa pode encontrar esta sala e entrar';

  @override
  String get roomBadgePrivateTooltip =>
      'Somente por convite, não aparece em Descobrir';

  @override
  String get roomBadgeLockedTooltip =>
      'Você precisa da senha da sala para entrar';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return 'As mensagens somem depois de $duration';
  }

  @override
  String get roomBadgeJoinedTooltip => 'Você já está nesta sala';

  @override
  String get roomInfoSheetDetailsLabel => 'OS DETALHES';

  @override
  String get roomInfoSheetNoDescription => 'Ainda sem descrição';

  @override
  String get roomInfoSheetCreatedLabel => 'Criada em';

  @override
  String get countBadgeCaptureProtectionLabel =>
      'PROTEÇÃO CONTRA CAPTURA DE TELA';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      'capturas de tela e gravações de tela aparecem pretas para o sistema.';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      'gravação de tela e espelhamento cobrem o app com um escudo de privacidade.';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      'capturas de tela e gravações funcionam normalmente fora de salas efêmeras.';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      'salas efêmeras (a câmara secreta) sempre ativam isso à força, não importa o quê.';

  @override
  String get countBadgeShowPasswordTooltip => 'mostrar senha';

  @override
  String get countBadgeHidePasswordTooltip => 'ocultar senha';

  @override
  String get countBadgeProtectedLabel => 'PROTEGIDO';

  @override
  String get countBadgeCaptureShieldActiveBody =>
      'gravação de tela ou espelhamento está ativo.';

  @override
  String get countBadgeCaptureShieldReassurance =>
      'a gravação não consegue ver suas conversas.';

  @override
  String get linkOpenerCouldNotOpenLink => 'Não foi possível abrir o link';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel =>
      'Configurar uma frase de recuperação';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'Sem frase de recuperação, você pode não conseguir mais entrar.';

  @override
  String get destinationsChatLabel => 'Chat';

  @override
  String get destinationsChatShort => 'CHAT';

  @override
  String get destinationsDiscoverLabel => 'Descobrir';

  @override
  String get destinationsDiscoverShort => 'BUSCAR';

  @override
  String get destinationsFeedLabel => 'Feed';

  @override
  String get destinationsFeedShort => 'FEED';

  @override
  String get destinationsSettingsLabel => 'Configurações';

  @override
  String get destinationsSettingsShort => 'CONFIG';

  @override
  String get familyRequestStageSenderGuardianLabel => 'esperando gente grande';

  @override
  String get familyRequestStageRecipientLabel => 'esperando resposta';

  @override
  String get roomContentTabLabelMedia => 'Mídia';

  @override
  String get roomContentTabLabelFiles => 'Arquivos';

  @override
  String get roomContentTabLabelVoice => 'Áudios';

  @override
  String get roomContentTabLabelLinks => 'Links';

  @override
  String get roomContentTabLabelSaved => 'Salvas';

  @override
  String get roomContentTabHeaderMedia => 'Mídia';

  @override
  String get roomContentTabHeaderFiles => 'Arquivos';

  @override
  String get roomContentTabHeaderVoice => 'Áudios';

  @override
  String get roomContentTabHeaderLinks => 'Links';

  @override
  String get roomContentTabHeaderSaved => 'Salvas';

  @override
  String get roomFacetLabelDms => 'diretas';

  @override
  String get roomFacetLabelGroups => 'grupos';

  @override
  String get roomFacetLabelPublic => 'pública';

  @override
  String get roomFacetLabelPrivate => 'privada';

  @override
  String get roomFacetLabelSecret => 'secreta';

  @override
  String get roomFacetLabelLocked => 'trancada';

  @override
  String get roomFacetLabelUnread => 'não lidas';

  @override
  String get roomFacetLabelMentions => 'menções';

  @override
  String get settingsScreenTitle => 'CONFIGURAÇÕES';

  @override
  String get settingsScreenTagline => 'visual. sensação. você.';

  @override
  String get settingsScreenAccountHintChild =>
      'perfil · privacidade · minha gente grande';

  @override
  String get settingsScreenAccountHintAdult =>
      'perfil · família · contas vinculadas · privacidade';

  @override
  String get settingsScreenSectionAppearance => 'APARÊNCIA';

  @override
  String get settingsScreenSectionChat => 'CHAT';

  @override
  String get settingsScreenSectionCompanions => 'COMPANHEIROS';

  @override
  String get settingsScreenSectionGeneral => 'GERAL';

  @override
  String get settingsScreenCheckForUpdatesLabel => 'VERIFICAR ATUALIZAÇÕES';

  @override
  String get settingsScreenUpdateAvailableValue => 'ATUALIZAÇÃO DISPONÍVEL';

  @override
  String get settingsScreenUpdateUpToDateSnackbar =>
      'Você está na versão mais recente.';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      'Não é possível verificar atualizações nesta versão.';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      'Não foi possível verificar atualizações. Tente novamente mais tarde.';

  @override
  String get settingsScreenSectionNotifications => 'NOTIFICAÇÕES';

  @override
  String get reportProblemRowLabel => 'Relatar um problema';

  @override
  String get reportProblemRowValue => 'Envie os detalhes para nós';

  @override
  String get reportProblemIntro =>
      'Conte o que deu errado. Os dados do app e do seu aparelho são incluídos automaticamente, junto com um registro técnico do que o app estava fazendo. É isso que ajuda a encontrar a causa.';

  @override
  String get reportProblemDescribeLabel => 'O que aconteceu';

  @override
  String get reportProblemDescribeHint =>
      'A tela pisca, os botões não respondem';

  @override
  String get reportProblemScreenshotsLabel => 'Capturas de tela';

  @override
  String get reportProblemAddScreenshot => 'Adicionar captura de tela';

  @override
  String get reportProblemDetailsLabel => 'Seus dados';

  @override
  String get reportProblemCopyDetails => 'Copiar dados';

  @override
  String get reportProblemCopied => 'Copiado';

  @override
  String get reportProblemSend => 'Enviar relatório';

  @override
  String get reportProblemSent => 'Relatório enviado. Obrigado!';

  @override
  String get reportProblemSendFailed =>
      'Não foi possível enviar o relatório. Verifique sua conexão e tente de novo.';

  @override
  String get reportProblemTooMany =>
      'Você enviou muitos relatórios em pouco tempo. Tente de novo mais tarde.';

  @override
  String get reportProblemShakeTitle => 'Relatar um problema?';

  @override
  String get reportProblemShakeBody =>
      'Você sacudiu o celular. Abrir a tela de relatório?';

  @override
  String get reportProblemShakeOpen => 'Relatar';

  @override
  String get reportProblemShakeDismiss => 'Agora não';

  @override
  String get settingsCallDeliveryLockScreenLabel =>
      'Chamadas na tela de bloqueio';

  @override
  String get settingsCallDeliveryBackgroundLabel =>
      'Atividade em segundo plano';

  @override
  String get settingsCallDeliveryStatusOff => 'Toque para permitir';

  @override
  String get settingsScreenRowTheme => 'TEMA';

  @override
  String get settingsScreenRowAppLogo => 'LOGO DO APP';

  @override
  String get settingsScreenRowGlass => 'VIDRO';

  @override
  String get settingsScreenRowChatList => 'LISTA DE CHATS';

  @override
  String get settingsScreenRowNavigation => 'NAVEGAÇÃO';

  @override
  String get settingsScreenRowChatStyle => 'ESTILO DE CHAT';

  @override
  String get settingsScreenRowBubbleStyle => 'ESTILO DO BALÃO';

  @override
  String get settingsScreenRowReplyStyle => 'ESTILO DE RESPOSTA';

  @override
  String get settingsScreenValueScrollList => 'Lista rolável';

  @override
  String get settingsScreenValueGridSheet => 'Grade';

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
  String get settingsScreenValueClassic => 'Clássico';

  @override
  String get settingsScreenValueCompact => 'Compacto';

  @override
  String get settingsScreenValueBubbleTailed => 'Com cauda';

  @override
  String get settingsScreenValueBubbleSoft => 'Suave';

  @override
  String get settingsScreenValueBubblePill => 'Cápsula';

  @override
  String get settingsScreenValueBubbleSlab => 'Bloco';

  @override
  String get settingsScreenValueReplyPhantomEcho => 'Eco Fantasma';

  @override
  String get settingsScreenValueReplyStickyNote => 'Nota Adesiva';

  @override
  String get settingsScreenValueReplyComicTail => 'Cauda de Quadrinho';

  @override
  String get settingsScreenValueLogoAuto => 'Automático';

  @override
  String get settingsScreenValueLogoManual => 'Manual';

  @override
  String get settingsScreenShowLinkUrlsLabel => 'MOSTRAR URLS DOS LINKS';

  @override
  String get settingsScreenLinksUrlsOnBody =>
      'a URL completa aparece ao lado do card de prévia';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      'só a prévia: balões mais limpos, toque para abrir';

  @override
  String get settingsScreenMenuBarLabel => 'ÍCONE NA BARRA DE MENUS';

  @override
  String get settingsScreenMenuBarOnBody =>
      'O MonkeyHub fica na barra de menus com a contagem de não lidas. Clique para abrir a janela';

  @override
  String get settingsScreenMenuBarOffBody =>
      'desativado no momento. O ícone do Dock é o único jeito de trazer de volta uma janela oculta';

  @override
  String get settingsScreenSectionCalls => 'CHAMADAS';

  @override
  String get settingsScreenRowVideoQuality => 'Qualidade de vídeo';

  @override
  String get settingsScreenValueVideoQualityAuto => 'Automático';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel =>
      'MOSTRAR ESTATÍSTICAS DA CHAMADA';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      'resolução, taxa de bits, ping e perda de pacotes em tempo real durante as chamadas';

  @override
  String get videoQualityScreenTitle => 'Qualidade de vídeo';

  @override
  String get videoQualityScreenSubtitle =>
      'Escolha um limite de resolução para o vídeo de saída';

  @override
  String get videoQualityScreenAutoSubtitle =>
      'Adapta-se automaticamente à sua conexão';

  @override
  String get videoQualityScreenHd1080Subtitle =>
      'Full HD: mais nítido, usa mais dados';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD: melhor em uma conexão forte';

  @override
  String get videoQualityScreenFootnote =>
      'A resolução real depende das câmeras de ambos os dispositivos e das condições da rede.';

  @override
  String get callScreenControlOptions => 'Mais';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => 'Variação (jitter)';

  @override
  String get callScreenStatsLossLabel => 'Perda';

  @override
  String get callScreenSwapPreviewSemanticLabel =>
      'Alternar visualização da câmera';

  @override
  String get callOptionsSheetTitle => 'Opções de chamada';

  @override
  String get settingsScreenPushNotificationsLabel => 'NOTIFICAÇÕES PUSH';

  @override
  String get settingsScreenPushOnBody =>
      'avisa sobre novas mensagens e pedidos';

  @override
  String get settingsScreenPushOffBody =>
      'silencioso: você só vê as coisas quando abre o app';

  @override
  String get settingsScreenGameRemindersLabel => 'LEMBRETE DIÁRIO DOS JOGOS';

  @override
  String get settingsScreenGameRemindersOnBody =>
      'um toque na hora do almoço, só se você ainda não jogou';

  @override
  String get settingsScreenGameRemindersOffBody =>
      'sem lembrete. Os jogos continuam lá quando você for ver';

  @override
  String get authErrorUsernameTaken => 'Esse nome de usuário já está em uso.';

  @override
  String get authErrorUsernameReserved =>
      'Esse nome de usuário não está disponível. Escolha outro.';

  @override
  String get authErrorDisplayNameReserved =>
      'Esse nome não está disponível. Escolha outro.';

  @override
  String get authErrorUserNotFound =>
      'Não existe conta com esse nome de usuário.';

  @override
  String get authErrorWrongPassword => 'Senha incorreta.';

  @override
  String get authErrorInvalidRecoveryKey =>
      'Esse nome de usuário e essa frase de recuperação não coincidem.';

  @override
  String get authErrorTooManyAttempts =>
      'Muitas tentativas. Espere 15 minutos e tente de novo.';

  @override
  String get authErrorChildMustPair =>
      'Essa é uma conta infantil. Peça a um adulto um código de pareamento.';

  @override
  String get authErrorPairingCodeExpired =>
      'Esse código expirou. Peça um novo.';

  @override
  String get authErrorPairingCodeInvalid =>
      'Esse código não funcionou. Ele pode já ter sido usado.';

  @override
  String get authErrorUseSocialSignIn =>
      'Essa conta faz login com Apple ou Google. Use os botões abaixo.';

  @override
  String get authErrorSocialTokenInvalid =>
      'Esse login não foi concluído. Tente de novo.';

  @override
  String get authErrorSocialNonceMismatch =>
      'Esse login não foi concluído. Tente novamente.';

  @override
  String get authErrorSocialMisconfig =>
      'O login ainda não está configurado do nosso lado. Tente novamente mais tarde.';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      'Essa conta Apple ou Google já está vinculada a outra conta do MonkeyHub.';

  @override
  String get authErrorSocialAlreadyLinked =>
      'Isso já está vinculado a esta conta.';

  @override
  String get authErrorSocialNotLinked =>
      'Isso não está vinculado a esta conta.';

  @override
  String get authErrorSocialLastCredential =>
      'Essa é a única forma de entrar nesta conta. Defina uma senha primeiro.';

  @override
  String get authErrorUsernameInvalid =>
      'Escolha um nome de usuário com 1 a 32 caracteres.';

  @override
  String get authErrorUsernameChangedRecently =>
      'Você mudou seu nome de usuário recentemente. Pode mudar de novo 30 dias depois da última vez.';

  @override
  String get authErrorInboxHandleLocked =>
      'Esta conta recebe os relatórios de problemas de todo mundo, então o nome de usuário é fixo.';

  @override
  String get glassKnobLabelFrost => 'Fosco';

  @override
  String get glassKnobHintFrost =>
      'Quanto de branco fica sobre o vidro. Diminua para ficar transparente';

  @override
  String get glassKnobLabelBlur => 'Desfoque';

  @override
  String get glassKnobHintBlur =>
      'Fosco no topo da faixa, vidro nítido na base';

  @override
  String get glassKnobLabelSaturation => 'Vazamento de cor';

  @override
  String get glassKnobHintSaturation =>
      'Quanto de cor sobrevive ao desfoque. Depois de 2, começa a posterizar';

  @override
  String get glassKnobLabelRimOpacity => 'Borda';

  @override
  String get glassKnobHintRimOpacity =>
      'Brilho da borda do vidro. Zero para uma superfície sem borda';

  @override
  String get glassKnobLabelRimWidth => 'Espessura da borda';

  @override
  String get glassKnobHintRimWidth => 'A espessura desse contorno';

  @override
  String get glassKnobLabelShadowOpacity => 'Sombra';

  @override
  String get glassKnobHintShadowOpacity =>
      'O quanto a superfície flutua acima do que está atrás dela';

  @override
  String get glassKnobLabelShadowBlur => 'Difusão da sombra';

  @override
  String get glassKnobHintShadowBlur => 'Suave e ampla, ou firme e dura';

  @override
  String get glassKnobLabelShadowY => 'Queda da sombra';

  @override
  String get glassKnobHintShadowY => 'O quanto ela cai abaixo da superfície';

  @override
  String get glassKnobLabelBarMargin => 'Margem lateral';

  @override
  String get glassKnobHintBarMargin =>
      'O espaço entre a barra e a borda da tela';

  @override
  String get glassKnobLabelBarBottom => 'Espaço inferior';

  @override
  String get glassKnobHintBarBottom =>
      'O quanto a barra flutua acima da base da tela';

  @override
  String get glassKnobLabelShellPadH => 'Preenchimento das pontas';

  @override
  String get glassKnobHintShellPadH =>
      'Da borda da barra até a primeira cápsula. Mantenha pequeno, ou as pontas ficam isoladas';

  @override
  String get glassKnobLabelShellPadV => 'Preenchimento superior';

  @override
  String get glassKnobHintShellPadV =>
      'Da borda da barra até o topo da cápsula';

  @override
  String get glassKnobLabelIndicatorInset => 'Recuo da cápsula';

  @override
  String get glassKnobHintIndicatorInset =>
      'O quanto a cápsula de seleção fica recuada dentro do próprio espaço';

  @override
  String get glassKnobLabelSegmentPadV => 'Preenchimento da linha';

  @override
  String get glassKnobHintSegmentPadV =>
      'O espaço acima e abaixo do ícone e do seu rótulo';

  @override
  String get glassKnobLabelIconLabelGap => 'Espaço do ícone';

  @override
  String get glassKnobHintIconLabelGap =>
      'Espaço entre um ícone e a palavra abaixo dele';

  @override
  String get glassKnobLabelIconSize => 'Tamanho do ícone';

  @override
  String get glassKnobLabelLabelSize => 'Tamanho do rótulo';

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
  String get settingsScreenRowMotion => 'MOVIMENTO';

  @override
  String get settingsScreenValueMotionFull => 'Completo';

  @override
  String get settingsScreenValueMotionCalm => 'Calmo';

  @override
  String get settingsScreenValueMotionSystemFull =>
      'Igual ao dispositivo · Completo';

  @override
  String get settingsScreenValueMotionSystemCalm =>
      'Igual ao dispositivo · Calmo';

  @override
  String get motionScreenTitle => 'movimento.';

  @override
  String get motionScreenSubtitle => 'quanto o app se mexe';

  @override
  String get motionScreenSystemLabel => 'IGUAL AO DISPOSITIVO';

  @override
  String get motionScreenSystemSubtitleFull =>
      'seu dispositivo permite animação neste momento';

  @override
  String get motionScreenSystemSubtitleCalm =>
      'seu dispositivo pede menos movimento neste momento';

  @override
  String get motionScreenFullLabel => 'COMPLETO';

  @override
  String get motionScreenFullSubtitle => 'cada deriva, brilho e floreio';

  @override
  String get motionScreenCalmLabel => 'CALMO';

  @override
  String get motionScreenCalmSubtitle => 'a decoração para, nada mais muda';

  @override
  String get momentRailCaptureLabel => 'Capturar';

  @override
  String get momentRailYouLabel => 'Você';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String momentRailPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count destaques',
      one: '1 destaque',
    );
    return '$_temp0';
  }

  @override
  String momentRailPersonNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count novos',
      one: '1 novo',
    );
    return '$_temp0';
  }

  @override
  String get momentRailAddHighlight => 'Adicionar um destaque';

  @override
  String get momentTagFate => 'Destino';

  @override
  String get momentTagJinx => 'Azar';

  @override
  String get momentTagLuck => 'Sorte';

  @override
  String get momentTagCalledIt => 'Eu avisei';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'Que coincidência';

  @override
  String get momentTagJinxHint => 'Você mesmo causou';

  @override
  String get momentTagLuckHint => 'Foi a seu favor';

  @override
  String get momentTagCalledItHint => 'Você viu chegando';

  @override
  String get momentTagNpcHint => 'Cérebro desligado';

  @override
  String get momentComposerTitle => 'Novo momento';

  @override
  String get momentComposerCaptionHint => 'Diga alguma coisa';

  @override
  String get momentComposerTagPrompt => 'ganhou um ponto? adicione já';

  @override
  String get momentComposerCapture => 'Câmera';

  @override
  String get momentComposerLibrary => 'Galeria';

  @override
  String get momentComposerRemovePhoto => 'Remover foto';

  @override
  String get momentComposerPost => 'Publicar';

  @override
  String get momentComposerErrorDailyCap =>
      'Já são cinco hoje. Guarde para amanhã';

  @override
  String get momentComposerErrorNotAllowed =>
      'Um responsável desativou o compartilhamento de fotos';

  @override
  String get momentComposerErrorTooLong => 'Ficou um pouco longo. Encurte';

  @override
  String get momentComposerErrorEmpty =>
      'Adicione uma foto ou algumas palavras';

  @override
  String get momentComposerErrorGeneric =>
      'Não foi possível publicar. Tente de novo';

  @override
  String get momentViewerDelete => 'Excluir';

  @override
  String get momentViewerDeleteConfirmHeadline => 'Excluir isso?';

  @override
  String get momentViewerDeleteConfirmBody =>
      'Sai do painel de todo mundo e do seu arquivo, para sempre';

  @override
  String get momentViewerDeleteFailed =>
      'Não foi possível excluir. Tente de novo';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who publicou um momento';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name marcou um ponto: $tag';
  }

  @override
  String get momentActivityJustNow => 'agora';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '${count}min';
  }

  @override
  String momentActivityHoursAgo(Object count) {
    return '${count}h';
  }

  @override
  String get puzzleScreenTitle => 'o enigma.';

  @override
  String get puzzleScreenSubtitle => 'Quatro símbolos, seis tentativas';

  @override
  String get puzzleSubmit => 'Adivinhar';

  @override
  String get puzzleBackspace => 'Apagar último símbolo';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'Símbolo $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'Resolvido em $count';
  }

  @override
  String get puzzleFailedTitle => 'Sem tentativas';

  @override
  String get puzzleAnswerWas => 'O código era';

  @override
  String get puzzleShare => 'Copiar resultado';

  @override
  String get puzzleShareCopied => 'Copiado. Mande para um amigo';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'Você já resolveu o de hoje';

  @override
  String get puzzleErrorOutOfGuesses => 'Você não tem tentativas hoje';

  @override
  String get puzzleErrorGeneric => 'Não foi possível enviar. Tente de novo';

  @override
  String get puzzleGuessWaiting =>
      'Sem conexão. Seu palpite está salvo e vai assim que voltar';

  @override
  String get gameSubmitWaiting =>
      'Sem conexão. Seu tabuleiro pronto está salvo e vai assim que voltar';

  @override
  String get puzzleScoreboardLabel => 'Pontuações de hoje';

  @override
  String get puzzleScoreboardEmpty => 'Ninguém terminou hoje ainda';

  @override
  String get puzzleTilePlay => 'jogue o enigma de hoje';

  @override
  String puzzleTileInProgress(Object count) {
    return 'faltam $count';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '#$rank de $total';
  }

  @override
  String get profileVisibilityScreenSectionFeed => 'FEED';

  @override
  String get profileVisibilityScreenFeedLabel => 'meus destaques';

  @override
  String get profileVisibilityScreenFeedDesc =>
      'se as fotos e vídeos que você publica aparecem nos quadros dos seus amigos naquele dia';

  @override
  String get profileVisibilityScreenPuzzleLabel => 'minha pontuação do enigma';

  @override
  String get profileVisibilityScreenPuzzleDesc =>
      'se seus amigos veem como você foi no enigma diário';

  @override
  String get profileVisibilityScreenPointsPastLabel => 'meu passado';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      'hoje é sempre compartilhado com os amigos. Isto abre tudo o que veio antes';

  @override
  String get momentComposerVideo => 'Vídeo';

  @override
  String get momentComposerErrorTooBig =>
      'Esse vídeo é muito grande. Máximo 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => 'Você publicou um momento';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'Você marcou um ponto: $tag';
  }

  @override
  String momentActivityGameSolved(String game, String name) {
    return '$name resolveu $game';
  }

  @override
  String momentActivityGameSolvedSelf(String game) {
    return 'Você resolveu $game';
  }

  @override
  String momentActivityGameMissed(String game, String name) {
    return '$name não resolveu $game';
  }

  @override
  String momentActivityGameMissedSelf(String game) {
    return 'Você não resolveu $game';
  }

  @override
  String momentActivityCodeSolved(String name) {
    return '$name decifrou o código';
  }

  @override
  String get momentActivityCodeSolvedSelf => 'Você decifrou o código';

  @override
  String momentActivityCodeMissed(String name) {
    return '$name não decifrou o código';
  }

  @override
  String get momentActivityCodeMissedSelf => 'Você não decifrou o código';

  @override
  String pointLineSelf(Object tag) {
    return 'Você · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'O que aconteceu?';

  @override
  String get pointComposerNoteHint => 'Escolha uma acima e conte';

  @override
  String get pointComposerAdd => 'Adicionar um ponto';

  @override
  String get pointComposerAddPhoto => 'adicionar foto';

  @override
  String get pointsBoardAdd => 'Adicionar um ponto';

  @override
  String get pointsExplainerOpen => 'O que é isso?';

  @override
  String get pointsExplainerTitle => 'O jogo dos pontos';

  @override
  String get pointsExplainerIntro =>
      'Uma piada recorrente com placar. Quando acontece algo com você (bom, ruim ou só estranho), você registra e fica no quadro naquele dia.';

  @override
  String get pointsExplainerRuleHonour =>
      'Os pontos você mesmo se dá. Ninguém confere, a graça é essa, e seus amigos avisam se você estiver exagerando.';

  @override
  String get pointsExplainerRuleToday =>
      'Os pontos zeram todo dia. O quadro mostra hoje; seu histórico é seu.';

  @override
  String get pointsExplainerRuleCap =>
      'Cinco de cada tipo por dia, para ninguém transformar o quadro em bobagem.';

  @override
  String get pointsExplainerGotIt => 'Entendi';

  @override
  String get momentTagFateExample => 'Encontrei meu dentista em outro país';

  @override
  String get momentTagJinxExample => 'Lavei o carro e choveu às quatro';

  @override
  String get momentTagLuckExample => 'Peguei o trem por dois segundos';

  @override
  String get momentTagCalledItExample =>
      'Falei que a continuação ia fracassar, e fracassou';

  @override
  String get momentTagNpcExample => 'Falei ‘você também’ para o garçom';

  @override
  String feedBoardEditionHint(Object number) {
    return 'Dia $number do feed';
  }

  @override
  String get feedBoardHighlightsHint => 'fotos e vídeos que valem uma olhada';

  @override
  String get profileVisibilityScreenPointsLabel => 'meus pontos';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'se os pontos que você registra aparecem nos quadros dos seus amigos';

  @override
  String get momentComposerEditPhoto => 'Editar recorte';

  @override
  String get archiveScreenTitle => 'Seu arquivo';

  @override
  String get archiveScreenEnd => 'É tudo';

  @override
  String get archiveScreenEmptyTitle => 'Você ainda não guardou nada';

  @override
  String get archiveScreenEmptyBody =>
      'Os momentos saem dos quadros dos seus amigos depois de um dia, mas ficam aqui para você.';

  @override
  String get archiveScreenEmptyFriendTitle => 'Não tem nada aqui';

  @override
  String get archiveScreenEmptyFriendBody =>
      'Ainda não publicou nada que você possa ver.';

  @override
  String get archiveScreenPrivateTitle => 'O passado é privado';

  @override
  String get archiveScreenPrivateBody =>
      'Você ainda vê o que for publicado hoje.';

  @override
  String get archiveScreenNotFriendTitle => 'Vocês não são amigos';

  @override
  String get archiveScreenNotFriendBody =>
      'Você só pode voltar nos dias de um amigo.';

  @override
  String get archiveScreenErrorTitle => 'Não foi possível carregar';

  @override
  String get archiveScreenErrorBody => 'Verifique sua conexão e tente de novo.';

  @override
  String get feedBoardOpenArchive => 'Arquivo';

  @override
  String get feedBoardGamesLabel => 'Jogos';

  @override
  String get feedBoardGamesOpen => 'Ranking';

  @override
  String get gamesScreenTitle => 'os jogos.';

  @override
  String get gamesScreenSubtitle =>
      'quatro tabuleiros por dia, os mesmos para todo mundo';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'faltam $count hoje',
      one: 'falta um hoje',
      zero: 'tudo feito hoje',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => 'Não deu para carregar os jogos de hoje';

  @override
  String get gamesRetry => 'Tentar de novo';

  @override
  String get gameQueensName => 'Rainhas';

  @override
  String get gameQueensRule =>
      'Uma coroa por linha, coluna e cor, sem encostar';

  @override
  String get gameTangoName => 'Tango';

  @override
  String get gameTangoRule => 'três sóis, três luas, nunca três seguidos';

  @override
  String get gameZipName => 'Zip';

  @override
  String get gameZipRule =>
      'uma linha por todos os quadrados, números em ordem';

  @override
  String get gameSudokuName => 'Mini sudoku';

  @override
  String get gameSudokuRule => 'de 1 a 6 uma vez por linha, coluna e bloco';

  @override
  String get gameCodeName => 'O código';

  @override
  String get gameStatusUnplayed => 'Não jogado';

  @override
  String get gameStatusUnfinished => 'Em andamento';

  @override
  String get gameStatusGaveUp => 'Desistiu';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'Pausar';

  @override
  String get gameResume => 'Continuar';

  @override
  String get gamePausedTitle => 'Em pausa';

  @override
  String get gamePausedBody => 'O relógio está parado e o tabuleiro escondido';

  @override
  String get gameUndo => 'Desfazer';

  @override
  String get gameClear => 'limpar';

  @override
  String get gameHint => 'Dica';

  @override
  String get gameNotes => 'anotações';

  @override
  String get gameErase => 'apagar';

  @override
  String get gameAutoCross => 'Cruzes automáticas';

  @override
  String get gameGiveUp => 'Desistir';

  @override
  String get gameGiveUpTitle => 'Mostrar a resposta?';

  @override
  String get gameGiveUpBody =>
      'O tabuleiro de hoje fecha e fica como não resolvido.';

  @override
  String get gameGiveUpCancel => 'Continuar';

  @override
  String get gameGiveUpConfirm => 'Mostrar';

  @override
  String gameSolvedTitle(Object time) {
    return 'Resolvido em $time';
  }

  @override
  String get gameGaveUpTitle => 'A resposta de hoje';

  @override
  String get gameFirstInToday => 'O primeiro de hoje';

  @override
  String gameRankLine(Object place, Object total) {
    return '$place de $total até agora';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count erros',
      one: '1 erro',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dicas',
      one: '1 dica',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => 'Tempos de hoje';

  @override
  String get gameStandingsEmpty => 'Ninguém terminou esse ainda';

  @override
  String get gameShare => 'Copiar resultado';

  @override
  String get gameShareCopied => 'Copiado. Cola pra um amigo';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number · $time';
  }

  @override
  String get gameBackToHub => 'Todos os jogos';

  @override
  String get gameElapsedSemantic => 'Tempo decorrido';

  @override
  String get gameErrorNotSolved => 'Esse tabuleiro ainda não está completo';

  @override
  String get gameErrorAlreadyFinished => 'Você já terminou o de hoje';

  @override
  String get gameErrorNoHint => 'Esse não tem dica';

  @override
  String get gameHintWrong => 'Essa estava errada, então foi apagada.';

  @override
  String get gameHintWrongMore =>
      'Ainda tem mais pra corrigir. Peça de novo quando quiser.';

  @override
  String get gameHintWrongLast => 'Todo o resto que você colocou está certo.';

  @override
  String get gameHintReveal =>
      'Nenhuma regra resolve uma casa sozinha ainda, então aqui vai uma.';

  @override
  String get gameHintQueensRegion =>
      'Só sobrou um lugar pra uma coroa nessa cor.';

  @override
  String get gameHintQueensRow =>
      'Só sobrou um lugar pra uma coroa nessa linha.';

  @override
  String get gameHintQueensCol =>
      'Só sobrou um lugar pra uma coroa nessa coluna.';

  @override
  String get gameHintQueensRegionInRow =>
      'Essa cor só cabe nessa linha, então o resto da linha não pode ter coroa.';

  @override
  String get gameHintQueensRegionInCol =>
      'Essa cor só cabe nessa coluna, então o resto da coluna não pode ter coroa.';

  @override
  String get gameHintQueensRowInRegion =>
      'Essa linha só tem espaço em uma cor, então o resto dessa cor não pode ter coroa.';

  @override
  String get gameHintQueensColInRegion =>
      'Essa coluna só tem espaço em uma cor, então o resto dessa cor não pode ter coroa.';

  @override
  String get gameHintStarsRegion =>
      'Essa cor só tem espaço pras estrelas que ainda faltam.';

  @override
  String get gameHintStarsRow =>
      'Essa linha só tem espaço pras estrelas que ainda faltam.';

  @override
  String get gameHintStarsCol =>
      'Essa coluna só tem espaço pras estrelas que ainda faltam.';

  @override
  String get gameHintTangoEqual =>
      'Um sinal = quer dizer que as duas casas são iguais.';

  @override
  String get gameHintTangoCross =>
      'Um sinal × quer dizer que as duas casas são opostas.';

  @override
  String get gameHintTangoPair =>
      'Duas lado a lado já são iguais, então a próxima tem que ser a outra.';

  @override
  String get gameHintTangoSandwich =>
      'As casas dos dois lados são iguais, então a do meio tem que ser a outra.';

  @override
  String get gameHintTangoRowSuns => 'Essa linha já tem seus três sóis.';

  @override
  String get gameHintTangoRowMoons => 'Essa linha já tem suas três luas.';

  @override
  String get gameHintTangoColSuns => 'Essa coluna já tem seus três sóis.';

  @override
  String get gameHintTangoColMoons => 'Essa coluna já tem suas três luas.';

  @override
  String gameHintLatinBox(int digit) {
    return 'Esse é o único lugar pra um $digit nesse bloco.';
  }

  @override
  String gameHintLatinRow(int digit) {
    return 'Esse é o único lugar pra um $digit nessa linha.';
  }

  @override
  String gameHintLatinCol(int digit) {
    return 'Esse é o único lugar pra um $digit nessa coluna.';
  }

  @override
  String get gameHintLatinOnly =>
      'Só cabe um número aqui. Os outros já estão na linha, na coluna ou no bloco dele.';

  @override
  String get gameHintLatinOnlyLines =>
      'Só cabe um número aqui. Os outros já estão na linha ou na coluna dele.';

  @override
  String get gameHintLatinOnlySigns =>
      'Só cabe um número aqui contando a linha, a coluna e os sinais.';

  @override
  String get gameHintNonogramRowFill =>
      'Não importa como a dica dessa linha se encaixe, ela cobre essa casa.';

  @override
  String get gameHintNonogramRowCross =>
      'Nenhum jeito de encaixar a dica dessa linha chega nessa casa.';

  @override
  String get gameHintNonogramColFill =>
      'Não importa como a dica dessa coluna se encaixe, ela cobre essa casa.';

  @override
  String get gameHintNonogramColCross =>
      'Nenhum jeito de encaixar a dica dessa coluna chega nessa casa.';

  @override
  String get gameHintMinesStart => 'Comece aqui. Essa casa é sempre segura.';

  @override
  String get gameHintMinesSafe =>
      'Esse número já tem todas as minas com bandeira, então as outras casas em volta são seguras.';

  @override
  String get gameHintMinesFlag =>
      'Esse número precisa que toda casa escondida em volta dele seja mina.';

  @override
  String get gameHintMinesProofSafe =>
      'Os números em volta dessa casa provam que ela é segura.';

  @override
  String get gameHintMinesProofMine =>
      'Os números em volta dessa casa provam que ela é uma mina.';

  @override
  String get gameHintFlowPipe => 'Aqui vai um cano inteiro, de ponto a ponto.';

  @override
  String get gameHintPatchesOnly => 'Só cabe um retalho nessa pista.';

  @override
  String get gameHintPatchesCell =>
      'Uma casa aqui só pode ser dessa pista, e isso deixa um único retalho pra ela.';

  @override
  String get gameHintPatchesSqueeze =>
      'Os retalhos em volta deixam um jeito só de encaixar essa pista.';

  @override
  String get gameErrorGeneric =>
      'Não deu para conectar aos jogos. Tente de novo';

  @override
  String get gameInfoOpen => 'Como jogar';

  @override
  String get gameInfoScoringTimed =>
      'Ganha quem terminar mais rápido. O relógio para quando você sai. Mesmo tempo, mesma posição.';

  @override
  String get gameInfoScoringGuesses =>
      'Ganha quem descobrir com menos palpites. O tempo não conta. Mesmos palpites, mesma posição.';

  @override
  String get gameInfoSameForEveryone =>
      'Hoje todo mundo recebe o mesmo desafio.';

  @override
  String get savedMessagesTitle => 'Mensagens salvas';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'nenhum chat corresponde a \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'Buscar chats';

  @override
  String get pullRevealCollapseSemanticLabel =>
      'Ocultar busca e chats arquivados';

  @override
  String archivedChatsFolderLabel(Object count) {
    return 'chats arquivados ($count)';
  }

  @override
  String get archivedChatsFolderTitle => 'chats arquivados';

  @override
  String get pullRevealClearSearchSemanticLabel => 'Limpar busca';

  @override
  String get archivedChatsSheetTitle => 'Chats arquivados';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'Chats arquivados · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'Nada mais arquivado';

  @override
  String get pinnedBadgeLabel => 'FIXADA';

  @override
  String get chatRowActionMenuPinLabel => 'Fixar chat';

  @override
  String get chatRowActionMenuUnpinLabel => 'Desafixar chat';

  @override
  String get chatRowActionMenuArchiveLabel => 'Arquivar chat';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'Desarquivar chat';

  @override
  String get messageActionMenuSaveLabel => 'Salvar';

  @override
  String get messageActionMenuUnsaveLabel => 'Remover';

  @override
  String get roomScreenSaveLimitSnack =>
      'Muitas mensagens salvas aqui. Remova uma primeiro';

  @override
  String get roomScreenSaveFailedSnack => 'Não deu pra salvar isso';

  @override
  String get threadOverlaySaveLimitToast =>
      'Muitas mensagens salvas aqui. Remova uma primeiro';

  @override
  String get threadOverlaySaveFailedToast => 'Não deu pra salvar isso';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'só você vê as mensagens que salva. Uma mensagem fixada é o oposto: a sala inteira vê.';

  @override
  String get roomInfoScreenOwnerBadgeNote =>
      'a pequena medalha ao lado de um nome indica quem criou esta sala.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return 'Ir para a mensagem salva de $name';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return 'Remover das salvas a mensagem de $name';
  }

  @override
  String get muteSheetTitle => 'Silenciar conversa';

  @override
  String get muteSheetSubtitle =>
      'Escolha o que fica em silêncio e por quanto tempo.';

  @override
  String get muteSheetNotificationsTitle => 'Notificações';

  @override
  String get muteSheetNotificationsSub => 'Sem aviso, sem som';

  @override
  String get muteSheetBadgesTitle => 'Contagem de não lidas';

  @override
  String get muteSheetBadgesSub =>
      'Sem número na conversa, nada no ícone do app';

  @override
  String get muteSheetDurationLabel => 'Por quanto tempo';

  @override
  String get muteDurationHour => '1 hora';

  @override
  String get muteDurationEightHours => '8 horas';

  @override
  String get muteDurationWeek => '1 semana';

  @override
  String get muteDurationAlways => 'Sempre';

  @override
  String get muteSheetConfirmButton => 'Silenciar';

  @override
  String get muteSheetSaveButton => 'Salvar';

  @override
  String get muteSheetUnmuteButton => 'Reativar';

  @override
  String get muteSummaryAll =>
      'Nada desta conversa chega até você: nem notificações, nem contagem de não lidas.';

  @override
  String get muteSummaryNotificationsOnly =>
      'Sem notificações. A contagem de não lidas continua subindo.';

  @override
  String get muteSummaryBadgesOnly =>
      'Sem contagem de não lidas. As notificações continuam chegando.';

  @override
  String get muteSummaryNothingPicked =>
      'Escolha pelo menos uma coisa para silenciar.';

  @override
  String muteUntilSentence(String when) {
    return 'Até $when.';
  }

  @override
  String get muteUntilAlwaysSentence => 'Até você ligar de novo.';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date, $time';
  }

  @override
  String get mutedBadgeLabel => 'SILENCIADA';

  @override
  String get chatRowActionMenuMuteLabel => 'Silenciar conversa';

  @override
  String get chatRowActionMenuUnmuteLabel => 'Reativar conversa';

  @override
  String get roomInfoScreenMuteLabel => 'SILÊNCIO';

  @override
  String get roomInfoScreenNotMutedRow => 'Não silenciada';

  @override
  String get attachmentMenuLocationLabel => 'Localização';

  @override
  String get locationSheetSendCurrent => 'Enviar localização atual';

  @override
  String get locationSheetSendCurrentDetail => 'Onde você está agora';

  @override
  String get locationSheetLiveHeading => 'Compartilhar ao vivo';

  @override
  String get locationSheetLiveDetail => 'Termina sozinho';

  @override
  String get locationShareFor15Minutes => 'Por 15 minutos';

  @override
  String get locationShareFor1Hour => 'Por 1 hora';

  @override
  String get locationShareFor8Hours => 'Por 8 horas';

  @override
  String get locationBubbleOpenInMaps => 'Abrir no mapa';

  @override
  String get locationBubbleLiveBadge => 'AO VIVO';

  @override
  String get locationBubbleEndedBadge => 'ENCERRADO';

  @override
  String locationBubbleLiveUntil(String time) {
    return 'Ao vivo até $time';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return 'Localização ao vivo encerrada às $time';
  }

  @override
  String get locationBubbleNoRecentUpdate => 'Sem atualizações recentes';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters m';
  }

  @override
  String get locationBubbleStopSharing => 'Parar de compartilhar';

  @override
  String get locationBubbleUnavailable => 'Localização indisponível';

  @override
  String get locationBubbleNoMapsApp => 'Nenhum app de mapas para abrir isso';

  @override
  String get locationBubbleCoordinatesCopied => 'Coordenadas copiadas';

  @override
  String get locationCouldNotGetFix => 'Não foi possível obter sua localização';

  @override
  String get locationCouldNotStartLiveShare =>
      'Não foi possível iniciar o compartilhamento ao vivo';

  @override
  String get locationPermissionNeeded =>
      'É necessário acesso à localização para compartilhar onde você está';

  @override
  String get locationPermissionBlockedTitle =>
      'O acesso à localização está desativado';

  @override
  String get locationPermissionBlockedBody =>
      'O MonkeyHub não pode pedir de novo por aqui. Ative o acesso à localização para o MonkeyHub nos Ajustes.';

  @override
  String get locationServicesOffTitle =>
      'Os serviços de localização estão desativados';

  @override
  String get locationServicesOffBody =>
      'A localização está desativada neste dispositivo. Ative nos Ajustes para compartilhar onde você está.';

  @override
  String get locationOpenSettings => 'Abrir ajustes';

  @override
  String get locationBackgroundSheetTitle => 'Se o seu celular reiniciar';

  @override
  String get locationBackgroundSheetBody =>
      'Seu compartilhamento ao vivo já continua quando você sai do MonkeyHub. O acesso em segundo plano cobre o resto: uma reinicialização, um fechamento forçado, um celular que fica sem bateria e volta.';

  @override
  String get locationBackgroundSheetKeepRunning => 'Retomar sozinho';

  @override
  String get locationBackgroundSheetKeepRunningDetail =>
      'Seu celular vai pedir permissão';

  @override
  String get locationBackgroundSheetAppOnly => 'Deixar parado';

  @override
  String get locationBackgroundSheetAppOnlyDetail => 'Nada mais para permitir';

  @override
  String get locationServiceNotificationTitle =>
      'Compartilhando sua localização ao vivo';

  @override
  String get locationServiceNotificationBody =>
      'Toque para abrir a conversa ou em Parar para encerrar agora';

  @override
  String get childPolicyScreenLocationLabel => 'Localização';

  @override
  String get childPolicyScreenLocationOnDesc =>
      'Podem compartilhar onde estão, inclusive ao vivo por até 8 horas';

  @override
  String get childPolicyScreenLocationOffDesc =>
      'Não podem compartilhar onde estão';

  @override
  String get roomInfoScreenSavedMessagesLabel => 'MENSAGENS SALVAS';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      'só você vê essas, e só desta sala. seu chat Mensagens salvas é separado.';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      'nada salvo ainda. segure uma mensagem e escolha SALVAR.';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return 'Ir para a mensagem salva de $name';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return 'Remover das salvas a mensagem de $name';
  }

  @override
  String get composerCaptureCameraModeLabel => 'câmera';

  @override
  String get composerCaptureVoiceModeLabel => 'mensagem de voz';

  @override
  String get composerCaptureVideoNoteModeLabel => 'nota de vídeo';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode. Deslize com dois dedos ou use as setas para mudar de modo.';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '$mode selecionado';
  }

  @override
  String get composerCaptureRecordingAnnouncement => 'Gravação iniciada';

  @override
  String get composerCaptureLockedAnnouncement =>
      'Gravação bloqueada. Mãos livres.';

  @override
  String get composerCaptureCancelledAnnouncement => 'Gravação descartada';

  @override
  String get composerCaptureSentAnnouncement => 'Gravação enviada';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return 'Gravando, $elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint =>
      'Segure para gravar, deslize para alternar';

  @override
  String get composerCaptureTapForCameraHint =>
      'Toque para a câmera, deslize para alternar';

  @override
  String get composerCaptureSlideToCancelHint => 'deslize para cancelar';

  @override
  String get composerCaptureReleaseToCancelHint => 'solte para cancelar';

  @override
  String get composerCaptureTapToSendHint => 'toque para enviar';

  @override
  String get composerCaptureSendingLabel => 'enviando…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return 'restam $seconds s';
  }

  @override
  String get composerCaptureLockedCancel => 'Cancelar';

  @override
  String get composerCaptureViewOnceLabel => 'Reproduzir uma vez';

  @override
  String get composerCaptureViewOnceVoiceHint => 'Só vai poder ouvir uma vez';

  @override
  String get composerCaptureViewOnceVideoHint => 'Só vai poder ver uma vez';

  @override
  String get composerCapturePauseLabel => 'Pausar gravação';

  @override
  String get composerCaptureResumeLabel => 'Retomar gravação';

  @override
  String get composerCaptureFlashLabel => 'Flash';

  @override
  String get composerCaptureReviewPlayLabel => 'Reproduzir gravação';

  @override
  String get composerCaptureReviewStopLabel => 'Parar reprodução';

  @override
  String get composerCaptureCancelLabel => 'descartar gravação';

  @override
  String get composerCaptureSendLabel => 'enviar gravação';

  @override
  String get composerCaptureLockLabel =>
      'deslize para cima para bloquear a gravação';

  @override
  String get composerCaptureMicPermissionTitle => 'Microfone necessário';

  @override
  String get composerCaptureMicPermissionBody =>
      'O MonkeyHub precisa do seu microfone para gravar uma mensagem de voz. Ative nas Configurações e tente de novo.';

  @override
  String get composerCaptureCameraPermissionTitle => 'Câmera necessária';

  @override
  String get composerCaptureCameraPermissionBody =>
      'O MonkeyHub precisa da sua câmera e do seu microfone para gravar uma nota de vídeo. Ative nas Configurações e tente de novo.';

  @override
  String get composerCaptureRestrictedBody =>
      'A gravação está desativada por uma restrição neste dispositivo.';

  @override
  String get composerCaptureOpenSettingsLabel => 'Abrir Configurações';

  @override
  String get composerCaptureUnavailableSnack =>
      'A gravação não está disponível neste dispositivo.';

  @override
  String get composerCaptureInterruptedSnack => 'Gravação interrompida.';

  @override
  String get composerCaptureStorageSnack =>
      'Não foi possível salvar a gravação. Verifique o espaço livre.';

  @override
  String get videoNoteMessagePlayLabel => 'Reproduzir nota de vídeo';

  @override
  String get videoNoteMessagePauseLabel => 'Pausar nota de vídeo';

  @override
  String get videoNoteMessageLoadingLabel => 'Carregando nota de vídeo';

  @override
  String get videoNoteMessageUnavailableLabel => 'Nota de vídeo indisponível';

  @override
  String get videoNoteMessageRetryLabel => 'Tentar novamente a nota de vídeo';

  @override
  String get videoNoteMessageRetryHint => 'Toque para tentar de novo';

  @override
  String get videoNoteMessageDiscardLabel => 'Descartar nota de vídeo';

  @override
  String get videoNoteScrubHint =>
      'Afaste o dedo do círculo para avançar com mais precisão';

  @override
  String get videoNoteScrubHalf => 'Avanço a meia velocidade';

  @override
  String get videoNoteScrubFine => 'Avanço preciso';

  @override
  String videoNoteSpeedLabel(String speed) {
    return 'Velocidade de reprodução $speed';
  }

  @override
  String get videoNoteAutoAdvanceOn => 'Reprodução automática: sim';

  @override
  String get videoNoteAutoAdvanceOff => 'Reprodução automática: não';

  @override
  String get videoNoteAutoAdvanceSemanticLabel =>
      'Reproduzir automaticamente a próxima nota de vídeo';

  @override
  String get composerCaptureStartRecordingLabel => 'Começar a gravar';

  @override
  String get attachmentMenuVideoNoteLabel => 'Nota de vídeo';

  @override
  String get cameraScreenPhotoModeLabel => 'Foto';

  @override
  String get cameraScreenVideoModeLabel => 'Vídeo';

  @override
  String get cameraScreenStartRecordingLabel => 'Iniciar gravação';

  @override
  String get cameraScreenStopRecordingLabel => 'Parar gravação';

  @override
  String get cameraScreenVideoFailedSnack =>
      'Não foi possível gravar esse vídeo.';

  @override
  String get scheduleSheetTitle => 'Agendar mensagem';

  @override
  String get scheduleSheetSubtitle => 'Escreva agora. Sai quando você disser.';

  @override
  String get scheduleSheetWhenLabel => 'Quando';

  @override
  String get schedulePresetInAnHour => 'Daqui a 1 hora';

  @override
  String get schedulePresetInEightHours => 'Daqui a 8 horas';

  @override
  String get schedulePresetTomorrowMorning => 'Amanhã de manhã';

  @override
  String get schedulePresetThisMorning => 'Esta manhã';

  @override
  String get schedulePresetInAWeek => 'Daqui a 1 semana';

  @override
  String get scheduleSheetCustomChip => 'Escolher data';

  @override
  String get scheduleSheetConfirmButton => 'Agendar';

  @override
  String get scheduleSheetSaveButton => 'Salvar';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'Envia $when';
  }

  @override
  String scheduleWhenToday(String time) {
    return 'hoje às $time';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return 'amanhã às $time';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return 'em $date às $time';
  }

  @override
  String get scheduleTimePickerTitle => 'Escolher data e hora';

  @override
  String get scheduleTimePickerBack => 'Opções rápidas';

  @override
  String get scheduleTimePickerToday => 'Hoje';

  @override
  String get scheduleTimePickerTomorrow => 'Amanhã';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count AGENDADAS',
      one: '1 AGENDADA',
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
      other:
          '$count mensagens esperando para serem enviadas. Toque para vê-las.',
      one: '1 mensagem esperando para ser enviada. Toque para vê-la.',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => 'VEJA ISTO';

  @override
  String get scheduledListTitle => 'Agendadas';

  @override
  String get scheduledListSubtitle =>
      'Só você vê essas mensagens até elas serem enviadas.';

  @override
  String get scheduledListEmpty => 'Nada esperando para ser enviado aqui.';

  @override
  String get scheduledListSendNow => 'Enviar agora';

  @override
  String get scheduledListChangeTime => 'Mudar a hora';

  @override
  String get scheduledListEdit => 'Editar texto';

  @override
  String get scheduledListDelete => 'Excluir';

  @override
  String get scheduledListSending => 'Enviando…';

  @override
  String get scheduledListFailedTitle => 'Não foi possível enviar';

  @override
  String get scheduledListRetry => 'Tentar de novo';

  @override
  String get scheduleErrorOutOfRange =>
      'Escolha uma hora entre dois minutos e um ano a partir de agora.';

  @override
  String get scheduleErrorTooMany =>
      'Mensagens demais esperando aqui. Envie ou exclua algumas primeiro.';

  @override
  String get scheduleErrorNotInEphemeral =>
      'As mensagens desta conversa desaparecem sozinhas, por isso não podem ser agendadas.';

  @override
  String get scheduleErrorNotMember => 'Você não está mais nesta conversa.';

  @override
  String get scheduleErrorBlocked =>
      'Você precisa desbloquear essa pessoa primeiro.';

  @override
  String get scheduleErrorGeneric => 'Não deu certo. Tente de novo.';

  @override
  String get scheduleEditTitle => 'Editar mensagem';

  @override
  String get composerScheduleAction => 'Agendar esta mensagem';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens esperando para serem enviadas',
      one: '1 mensagem esperando para ser enviada',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => 'Mostrar como';

  @override
  String get scheduledIndicatorPill => 'Cápsula';

  @override
  String get scheduledIndicatorBadge => 'Selo';

  @override
  String get scheduledIndicatorBoth => 'Ambos';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens já esperando',
      one: '1 mensagem já esperando',
      zero: 'Nada esperando para ser enviado',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => 'Como aparecem';

  @override
  String get scheduledIndicatorPillSub =>
      'Uma barra acima da caixa de texto. Toque para vê-las.';

  @override
  String get scheduledIndicatorBadgeSub =>
      'Um número no botão de enviar. Nada aparece até você começar a digitar.';

  @override
  String get scheduledIndicatorBothSub =>
      'A barra, mais o número enquanto você digita.';

  @override
  String get scheduledBack => 'Voltar';

  @override
  String get serverScreenTitle => 'servidor.';

  @override
  String get serverScreenSubtitle => 'Onde ficam sua conta e suas mensagens';

  @override
  String get serverOnboardingTitle => 'escolha um servidor.';

  @override
  String get serverOnboardingSubtitle =>
      'Esta versão não veio com nenhum. Aponte para o seu';

  @override
  String get serverStatusConnected => 'Conectado';

  @override
  String get serverStatusDisconnected => 'Sem conexão';

  @override
  String get serverBadgeDefault => 'Padrão';

  @override
  String get serverBadgeSelfHosted => 'Auto-hospedado';

  @override
  String get serverNoneConfigured => 'Ainda sem servidor';

  @override
  String get serverActiveNowLabel => 'Em uso';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'O servidor que veio com este app.';

  @override
  String get serverChoiceOwn => 'Seu próprio servidor';

  @override
  String get serverChoiceOwnSub => 'Um backend Convex que você mesmo mantém.';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => 'Colar';

  @override
  String get serverProblemMalformed => 'Isso não é um endereço da web.';

  @override
  String get serverProblemBadScheme => 'Comece com https:// ou http://.';

  @override
  String get serverProblemNoHost =>
      'Adicione o endereço do seu servidor depois de https://.';

  @override
  String get serverProblemCredentials =>
      'Remova o usuário e a senha do endereço.';

  @override
  String get serverInsecureTitle => 'Sem criptografia';

  @override
  String get serverInsecureBody =>
      'Os celulares bloqueiam http simples, então este endereço não vai conectar no iOS nem no Android. Use https, ou acesse seu servidor por um túnel.';

  @override
  String get serverTestCta => 'Testar conexão';

  @override
  String get serverTestingLabel => 'Testando…';

  @override
  String get serverCheckReachable => 'Algo respondeu';

  @override
  String get serverCheckConvex => 'É um servidor Convex';

  @override
  String get serverCheckApp => 'Tem o MonkeyHub instalado';

  @override
  String get serverResultUnreachable => 'Nada respondeu nesse endereço.';

  @override
  String get serverResultNotConvex =>
      'Algo respondeu, mas não é um servidor Convex.';

  @override
  String get serverResultNotThisApp =>
      'É um servidor Convex, mas o MonkeyHub não está instalado nele.';

  @override
  String get serverResultServerError =>
      'O servidor respondeu, mas com um erro.';

  @override
  String get serverResultReady => 'Pronto para conectar.';

  @override
  String get serverConnectCta => 'Conectar';

  @override
  String get serverConnectAnywayCta => 'Conectar mesmo assim';

  @override
  String get serverAlreadyConnectedCta => 'Já conectado';

  @override
  String get serverUseDefaultCta => 'Usar o servidor padrão';

  @override
  String get serverChangeCta => 'Trocar servidor';

  @override
  String get serverAdvancedLabel => 'Avançado';

  @override
  String get serverSiteUrlExplain =>
      'A maioria dos servidores responde a tudo em um só endereço. Preencha isto só se o seu servir as ações HTTP em outro.';

  @override
  String get serverSiteUrlHint => 'Igual ao de cima';

  @override
  String get serverSectionRecent => 'Recentes';

  @override
  String get serverRecentForget => 'Esquecer este servidor';

  @override
  String get serverSwitchWarningTitle => 'Trocar desconecta você';

  @override
  String get serverSwitchWarningBody =>
      'Contas e conversas pertencem a um único servidor. Este aparelho sai da conta, limpa o que baixou e começa do zero. Nada é excluído em nenhum dos servidores.';

  @override
  String get serverSwitchRolledBackTitle => 'Não foi possível conectar';

  @override
  String serverSwitchRolledBackBody(String host) {
    return 'O $host não respondeu, então nada mudou. Vai precisar entrar de novo.';
  }

  @override
  String get serverSwitchStrandedBody =>
      'Nenhum dos servidores conectou. Confira o endereço e tente de novo.';

  @override
  String get serverSwitchRefusedBody =>
      'Este aparelho está configurado para uma criança e não pode trocar de servidor.';

  @override
  String serverChipSemantics(String server) {
    return 'Trocar de servidor. Atualmente $server.';
  }

  @override
  String get serverValueDefault => 'Padrão';

  @override
  String get settingsScreenRowServer => 'SERVIDOR';

  @override
  String get settingsScreenSectionAdvanced => 'AVANÇADO';

  @override
  String get serverSwitchingLabel => 'Trocando de servidor…';

  @override
  String get serverRoleExplainAction => 'O que isso significa?';

  @override
  String get serverBadgeRibbonHomeserver => 'CASA';

  @override
  String get serverBadgeRibbonSelfHosted => 'PRÓPRIO';

  @override
  String get serverBadgeHomeserver => 'Servindo pelo homeserver';

  @override
  String get serverBadgeHomeserverSemantics =>
      'Servindo pelo homeserver. Toque para saber mais.';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'Servidor auto-hospedado: $server. Toque para saber mais.';
  }

  @override
  String get serverRoleHomeserverTitle => 'Rodando no homeserver';

  @override
  String get serverRoleHomeserverBody =>
      'Quem cuida do MonkeyHub passou o tráfego para o servidor de casa por um tempo. Tudo funciona igual. Isso é intencional, não é falha.';

  @override
  String get serverRoleHomeserverWarnData =>
      'O que você enviar enquanto isso durar pode não estar aqui depois que o tráfego voltar.';

  @override
  String get serverRoleHomeserverWarnSpeed =>
      'Uma conexão doméstica é mais lenta que a de sempre, então pode travar.';

  @override
  String get serverRoleHomeserverWarnAuto =>
      'Você não precisa fazer nada. O app volta sozinho.';

  @override
  String get serverRoleSelfHostedTitle => 'Seu próprio servidor';

  @override
  String get serverRoleSelfHostedBody =>
      'Este aparelho aponta para um servidor seu. Mude em Configurações › Avançado › Servidor.';

  @override
  String get serverValueHomeserver => 'Homeserver, por enquanto';

  @override
  String get serverChoiceCloudSubHomeserver =>
      'Sendo servido pelo homeserver por um tempo.';

  @override
  String get serverDirectiveChangedToast => 'Seu servidor mudou. Reconectando…';

  @override
  String get loginScreenSignInWithPhone => 'sign in with your phone';

  @override
  String get loginScreenUsePasswordInstead => 'Usar uma senha';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      'Abra o MonkeyHub no celular, vá ao seu perfil, toque em “Escaneie para entrar” e aponte a câmera para cá, ou digite o código abaixo.';

  @override
  String get deviceLoginScreenWaiting => 'Aguardando aprovação…';

  @override
  String get deviceLoginScreenApproved => 'Aprovado, entrando…';

  @override
  String get deviceLoginScreenDenied => 'Pedido de entrada recusado no celular';

  @override
  String get deviceLoginScreenGenericError =>
      'Algo deu errado. Tente um código novo';

  @override
  String get profileScreenScanToSignInLabel => 'Escaneie para entrar';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro =>
      'Aponte a câmera para o código no computador ou digite-o abaixo.';

  @override
  String get deviceLoginScanScreenScanButtonLabel => 'Escanear código';

  @override
  String get deviceLoginScanScreenConfirmTitle => 'Entrar neste dispositivo?';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return '$deviceInfo quer entrar como você. Só aprove se for você, agora mesmo.';
  }

  @override
  String get deviceLoginScanScreenApproveButton => 'Aprovar';

  @override
  String get deviceLoginScanScreenDenyButton => 'Recusar';

  @override
  String get deviceLoginScanScreenSuccess =>
      'Você entrou no seu outro dispositivo';

  @override
  String get deviceLoginScanScreenGenericError =>
      'Não foi possível aprovar. Tente novamente';

  @override
  String get authErrorDeviceLoginInvalid => 'Esse código não está certo.';

  @override
  String get authErrorDeviceLoginExpired =>
      'Esse código expirou. Gere um novo no outro dispositivo.';

  @override
  String get deviceLoginScanScreenDeniedConfirmation =>
      'Pedido de entrada recusado';

  @override
  String get roomAdminRoleAdmin => 'Admin';

  @override
  String get roomAdminActionViewProfile => 'Ver perfil';

  @override
  String get roomAdminActionPromote => 'Tornar admin';

  @override
  String get roomAdminActionPromoteSub =>
      'Vai poder convidar, remover membros e editar o grupo';

  @override
  String get roomAdminActionDemote => 'Retirar admin';

  @override
  String get roomAdminActionDemoteSub => 'Continua no grupo como membro';

  @override
  String get roomAdminActionTransfer => 'Transferir o grupo';

  @override
  String get roomAdminActionTransferSub => 'Você continua como admin';

  @override
  String get roomAdminActionRemove => 'Remover do grupo';

  @override
  String get roomAdminAddFriendsRow => 'Adicionar amigos';

  @override
  String get roomAdminInviteLinkRow => 'Link de convite';

  @override
  String get roomAdminJoinRequestsRow => 'Pedidos para entrar';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return 'Entregar o grupo a $name?';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      'Vira dono e pode excluir o grupo. Você continua como admin, e só essa pessoa pode devolver o grupo.';

  @override
  String get roomAdminTransferConfirmCta => 'Transferir';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return 'Remover $name?';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'Perde o acesso ao grupo e a tudo que tem nele. Pode ser convidada de novo, ou voltar pelo link de convite.';

  @override
  String get roomAdminRemoveConfirmCta => 'Remover';

  @override
  String get roomAdminGenericError => 'Não deu certo. Tente de novo.';

  @override
  String get roomAdminErrorNotMember => 'Você não está mais neste grupo.';

  @override
  String get roomAdminErrorNotAdmin => 'Só os admins podem fazer isso.';

  @override
  String get roomAdminErrorNotOwner => 'Só o dono do grupo pode fazer isso.';

  @override
  String get roomAdminErrorNotGroup =>
      'Numa conversa direta não há nada para administrar.';

  @override
  String get roomAdminErrorOwnerImmutable =>
      'O papel do dono só muda transferindo o grupo.';

  @override
  String get roomAdminErrorInvitesLocked =>
      'Só os admins podem convidar para este grupo.';

  @override
  String get roomInviteSheetTitle => 'Link de convite';

  @override
  String get roomInviteSheetBlurb =>
      'Um link e um código, e são a mesma coisa. Assim que você criar um novo, o anterior para de funcionar.';

  @override
  String get roomInviteNoLinkYet => 'Este grupo ainda não tem link de convite.';

  @override
  String get roomInviteCreateButton => 'Criar link';

  @override
  String get roomInviteRegenerateButton => 'Novo link';

  @override
  String get roomInviteRevokeButton => 'Revogar link';

  @override
  String get roomInviteCopyLink => 'Copiar link';

  @override
  String get roomInviteCopyCode => 'Copiar código';

  @override
  String get roomInviteShare => 'Compartilhar';

  @override
  String get roomInviteLinkCopied => 'Link copiado.';

  @override
  String get roomInviteCodeCopied => 'Código copiado.';

  @override
  String get roomInviteRegenerateHeadline => 'Criar um link novo?';

  @override
  String get roomInviteRegenerateBody =>
      'O link e o código atuais param de funcionar na hora, em todo lugar onde foram compartilhados. Quem já está no grupo continua.';

  @override
  String get roomInviteRegenerateConfirm => 'Novo link';

  @override
  String get roomInviteRevokeHeadline => 'Revogar este link?';

  @override
  String get roomInviteRevokeBody =>
      'Ninguém novo entra por link até você criar outro. Quem já está no grupo continua.';

  @override
  String get roomInviteRevokeConfirm => 'Revogar';

  @override
  String get roomInviteLimitsLabel => 'Limites';

  @override
  String get roomInviteExpiryLabel => 'Expira ao fim de';

  @override
  String get roomInviteMaxUsesLabel => 'Número de usos';

  @override
  String get roomInviteNeverExpires => 'Nunca';

  @override
  String get roomInviteUnlimited => 'Sem limite';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count h';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count d';
  }

  @override
  String get roomInviteLimitsApplyToNew => 'Valem para o link que você criar.';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      'Valem para o próximo link. O de cima mantém os limites com que foi criado.';

  @override
  String get roomInvitePermissionsLabel => 'Permissões';

  @override
  String get roomInviteMembersCanInviteLabel =>
      'Os membros podem convidar amigos';

  @override
  String get roomInviteMembersCanInviteSub =>
      'Desligue e só os admins trazem gente';

  @override
  String get roomInviteApprovalLabel => 'Aprovar cada entrada';

  @override
  String get roomInviteApprovalSub =>
      'Quem tem o link pede primeiro, e um admin diz sim ou não';

  @override
  String roomInviteUsesCount(Object count) {
    return 'Usado $count vezes';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$used de $max usos';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return 'Expira a $date';
  }

  @override
  String get roomInviteDeadExpired => 'Este link expirou. Crie um novo.';

  @override
  String get roomInviteDeadExhausted =>
      'Este link acabou os usos. Crie um novo.';

  @override
  String get roomInviteDeadRevoked => 'Este link foi revogado.';

  @override
  String get roomInviteDeadGeneric => 'Este link já não funciona.';

  @override
  String get roomInviteFriendsTitle => 'Adicionar amigos';

  @override
  String get roomInviteFriendsBlurb =>
      'Vão receber um convite e podem aceitar ou recusar.';

  @override
  String get roomInviteFriendsSearchHint => 'Buscar amigos';

  @override
  String get roomInviteFriendsInviteButton => 'Convidar';

  @override
  String get roomInviteFriendsSent => 'Convidado';

  @override
  String get roomInviteFriendsEmpty =>
      'Todos os seus amigos já estão aqui ou já foram convidados.';

  @override
  String get roomInviteFriendsNoMatch => 'Nenhum amigo corresponde a isso.';

  @override
  String get roomInviteFriendsDone => 'Pronto';

  @override
  String get roomJoinRequestsTitle => 'Pedidos para entrar';

  @override
  String get roomJoinRequestsBlurb =>
      'Essas pessoas usaram o link de convite. Elas não veem nada do grupo até você dizer sim.';

  @override
  String get roomJoinRequestsEmpty => 'Ninguém à espera.';

  @override
  String get roomJoinRequestsApprove => 'DEIXAR ENTRAR';

  @override
  String get roomJoinRequestsReject => 'NÃO';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return 'CONVIDADOS · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian =>
      'Aguardando um responsável';

  @override
  String get roomInfoScreenInviteWithdraw => 'RETIRAR';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return 'De $inviter · $members membros';
  }

  @override
  String get roomInvitationCardJoin => 'Entrar';

  @override
  String get discoverScreenJoinByCodeTitle => 'Entrar com um código';

  @override
  String get discoverScreenJoinByCodeSubtitle =>
      'Abra um grupo que alguém compartilhou com você';

  @override
  String get joinInviteTitle => 'Entrar num grupo';

  @override
  String get joinInviteBack => 'Voltar';

  @override
  String get joinInviteCodeBlurb =>
      'Digite o código que compartilharam com você. Um link de convite completo também funciona.';

  @override
  String get joinInviteCodeLabel => 'Código de convite';

  @override
  String get joinInviteCodeHint => 'Cole o link ou digite o código';

  @override
  String get joinInviteCodeInvalid => 'Isso não parece um código de convite.';

  @override
  String get joinInviteLookupButton => 'Continuar';

  @override
  String get joinInviteLookupFailed =>
      'Não deu para verificar o código. Confira sua conexão e tente de novo.';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count membros';
  }

  @override
  String get joinInviteJoinButton => 'Entrar no grupo';

  @override
  String get joinInviteRequestButton => 'Pedir para entrar';

  @override
  String get joinInviteOpenNote =>
      'Você vai ver as mensagens do grupo assim que entrar.';

  @override
  String get joinInviteApprovalNote =>
      'Um admin precisa dizer sim antes de você poder ver qualquer coisa aqui.';

  @override
  String get joinInviteOpenRoom => 'Abrir grupo';

  @override
  String get joinInvitePendingHeadline => 'À espera de um admin';

  @override
  String get joinInvitePendingBody =>
      'Você recebe uma notificação assim que alguém responder.';

  @override
  String get joinInviteBadLinkHeadline => 'Este convite não funciona';

  @override
  String get joinInviteBadLinkBody => 'Confira o código, ou peça um link novo.';

  @override
  String get joinInviteExpiredHeadline => 'Este convite expirou';

  @override
  String get joinInviteExpiredBody =>
      'Peça um link novo para quem convidou você.';

  @override
  String get joinInviteExhaustedHeadline => 'Este convite esgotou';

  @override
  String get joinInviteExhaustedBody =>
      'Ele estava configurado para funcionar um número limitado de vezes. Peça outro.';

  @override
  String get joinInviteRevokedHeadline => 'Este convite foi substituído';

  @override
  String get joinInviteRevokedBody =>
      'Um admin criou um link novo. Peça o atual para essa pessoa.';

  @override
  String get joinInviteWrongServerHeadline =>
      'Este convite é de outro servidor';

  @override
  String joinInviteWrongServerBody(Object host) {
    return 'Pertence a $host. Sua conta está em outro servidor, então este grupo não é acessível daqui.';
  }

  @override
  String get roomInviteErrorNotFound =>
      'Esse código de convite não corresponde a nada.';

  @override
  String get roomInviteErrorRevoked =>
      'Esse convite foi substituído. Pede o link atual.';

  @override
  String get roomInviteErrorExpired => 'Esse convite expirou.';

  @override
  String get roomInviteErrorExhausted => 'Esse convite esgotou.';

  @override
  String get roomInviteErrorAlreadyMember => 'Já está neste grupo.';

  @override
  String get roomInviteErrorAlreadyInvited => 'Já foi convidado.';

  @override
  String get roomInviteErrorSelf => 'Você já está neste grupo.';

  @override
  String get roomInviteErrorInvitationGone => 'Esse convite já não existe.';

  @override
  String get roomInviteErrorRequestPending =>
      'Você já pediu para entrar. Um admin vai responder.';

  @override
  String get roomInviteErrorRequestGone => 'Alguém já respondeu a esse pedido.';

  @override
  String get roomInviteErrorRoomPrivate =>
      'Só se entra neste grupo com convite.';

  @override
  String get roomInviteErrorInvalidLimits => 'Esses limites não são válidos.';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$child quer convidar $other para $room';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$other convidou $child para $room';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      'O convite segue, e quem decide continua a ser a outra pessoa.';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$child vai ver o convite e pode aceitar ou recusar. Aprovar também dá acesso a esse grupo se aceitar.';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      'Você não pode remover a si mesmo. Saia do grupo em vez disso.';

  @override
  String get roomAdminActionMessage => 'Enviar mensagem';

  @override
  String get roomAdminActionVoiceCall => 'Chamada de voz';

  @override
  String get roomAdminActionVideoCall => 'Chamada de vídeo';

  @override
  String get roomAdminYouSuffix => 'Você';

  @override
  String get roomInfoScreenSetPasswordButton => 'DEFINIR';

  @override
  String get roomInfoScreenPasswordSetSnackbar => 'Senha definida.';

  @override
  String get roomInfoScreenPasswordSetState => 'Com senha';

  @override
  String get roomInfoScreenPasswordUnsetState => 'Sem senha';

  @override
  String get roomInfoScreenPasswordCancel => 'Cancelar';

  @override
  String get roomInfoScreenEditSave => 'Salvar';

  @override
  String get roomInfoScreenEditCancel => 'Cancelar';

  @override
  String get roomInviteRotatedToast =>
      'Novo link criado. O anterior não funciona mais.';

  @override
  String get roomInviteRevokedToast => 'Link de convite revogado.';

  @override
  String get newChatMenuTitle => 'Nova conversa';

  @override
  String get newChatMenuCreateTitle => 'Criar uma sala';

  @override
  String get newChatMenuCreateSub => 'Comece um grupo e convide pessoas';

  @override
  String get newChatMenuJoinTitle => 'Entrar com um código';

  @override
  String get newChatMenuJoinSub => 'Abra um grupo compartilhado com você';

  @override
  String get shareSheetTitle => 'Compartilhar com';

  @override
  String get shareSheetSuggestedHeading => 'Sugeridos';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anexos',
      one: '1 anexo',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos passam do limite de $size e ficaram de fora',
      one: '1 arquivo passa do limite de $size e ficou de fora',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return 'Enviar para $title';
  }

  @override
  String get settingsScreenRowSpeakerColors => 'CORES DAS PESSOAS';

  @override
  String get settingsScreenValueSpeakerOff => 'Desligado';

  @override
  String get settingsScreenValueSpeakerName => 'Nomes';

  @override
  String get settingsScreenValueSpeakerBubble => 'Nomes + balões';

  @override
  String get speakerColorScreenTitle => 'cores das pessoas.';

  @override
  String get speakerColorScreenSubtitle => 'quem disse aquilo, sem ler o nome';

  @override
  String get speakerColorScreenOffLabel => 'DESLIGADO';

  @override
  String get speakerColorScreenOffDescription =>
      'todo mundo na sala escreve com a mesma tinta.';

  @override
  String get speakerColorScreenNameLabel => 'NOMES';

  @override
  String get speakerColorScreenNameDescription =>
      'cada pessoa ganha uma cor só dela, no nome e em volta do rosto.';

  @override
  String get speakerColorScreenBubbleLabel => 'BALÕES';

  @override
  String get speakerColorScreenBubbleDescription =>
      'a cor vai junto para as mensagens, então uma sequência de cinco ainda diz quem escreveu.';

  @override
  String get roomInfoScreenSpeakerColorsLabel => 'CORES';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => 'Automático';

  @override
  String get roomInfoScreenSpeakerColorsCustom => 'Personalizado';

  @override
  String get roomColorsScreenTitle => 'quem é quem.';

  @override
  String get roomColorsScreenSubtitle => 'a cor de cada pessoa';

  @override
  String get roomColorsScreenOffTitle =>
      'as cores das pessoas estão desligadas';

  @override
  String get roomColorsScreenOffBody =>
      'por enquanto todo mundo aparece com a mesma tinta. ligue e cada pessoa aqui ganha a sua.';

  @override
  String get roomColorsScreenOffAction => 'LIGAR';

  @override
  String get roomColorsScreenOffHint =>
      'vale para todas as salas, não só esta. também está nas configurações.';

  @override
  String get roomColorsScreenAutoChip => 'AUTO';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return 'compartilhada com $name';
  }

  @override
  String get roomColorsScreenResetAll => 'VOLTAR AO AUTOMÁTICO';

  @override
  String get roomColorsScreenLimitToast =>
      'É o máximo que uma sala pode fixar.';

  @override
  String get roomColorsScreenFailedToast => 'Não foi possível salvar essa cor.';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return 'Cor $index';
  }

  @override
  String get devicesScreenTitle => 'SEUS DISPOSITIVOS';

  @override
  String get devicesScreenSubtitle =>
      'Todos os lugares onde você entrou nesta conta.';

  @override
  String get devicesScreenLoading => 'verificando…';

  @override
  String get devicesScreenLoadFailed =>
      'não foi possível carregar seus dispositivos';

  @override
  String get devicesScreenThisDevice => 'ESTE DISPOSITIVO';

  @override
  String get devicesScreenActiveNow => 'ativo agora';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count minutos',
      one: 'há 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count horas',
      one: 'há 1 hora',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'há $count dias',
      one: 'há 1 dia',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications =>
      'as notificações não estão chegando neste';

  @override
  String get devicesScreenRemove => 'REMOVER';

  @override
  String get devicesScreenRemoveTitle => 'REMOVER ESTE DISPOSITIVO?';

  @override
  String devicesScreenRemoveBody(Object name) {
    return '$name será desconectado e vai parar de receber notificações. Quem estiver com ele terá que entrar de novo.';
  }

  @override
  String get devicesScreenRemoveConfirm => 'REMOVER';

  @override
  String get devicesScreenRemoveAll => 'Remover todos os outros dispositivos';

  @override
  String get devicesScreenRemoveAllTitle =>
      'REMOVER TODOS OS OUTROS DISPOSITIVOS?';

  @override
  String get devicesScreenRemoveAllBody =>
      'Todos serão desconectados e vão parar de receber notificações. Só este dispositivo continua conectado.';

  @override
  String get devicesScreenRemoveAllConfirm => 'REMOVER TODOS';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivos removidos',
      one: '1 dispositivo removido',
      zero: 'não há outros dispositivos para remover',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed =>
      'não foi possível remover esse dispositivo';

  @override
  String get devicesScreenFootnote =>
      'Remover um dispositivo o desconecta e interrompe as notificações. Vale na hora: a próxima coisa que esse dispositivo tentar fazer o manda de volta para a tela de login.';

  @override
  String get attachmentMenuPollLabel => 'Enquete';

  @override
  String get attachmentMenuChecklistLabel => 'Lista';

  @override
  String get attachmentMenuEventLabel => 'Evento';

  @override
  String get interactionKindPoll => 'Enquete';

  @override
  String get interactionKindQuiz => 'Quiz';

  @override
  String get interactionKindChecklist => 'Lista';

  @override
  String get interactionKindEvent => 'Evento';

  @override
  String get interactionBadgeAnonymous => 'Anônima';

  @override
  String get interactionBadgeMultiple => 'Várias';

  @override
  String get interactionBadgeClosed => 'Fechada';

  @override
  String interactionPercent(int percent) {
    return '$percent %';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names +$count';
  }

  @override
  String get interactionSeeWhoAnswered => 'Ver quem respondeu';

  @override
  String interactionRemoveItem(String label) {
    return 'Remover $label';
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
  String get interactionAddItemHint => 'Adicionar um item';

  @override
  String get interactionRetract => 'Retirar';

  @override
  String get interactionClose => 'Fechar';

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
      other: '$count respostas',
      one: '1 resposta',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$done de $total feitos';
  }

  @override
  String get interactionNoAnswers => 'Sem respostas';

  @override
  String get interactionBeFirst => 'Seja o primeiro a responder';

  @override
  String interactionFinalResults(String count) {
    return '$count · final';
  }

  @override
  String get interactionQuizRight => 'Certo';

  @override
  String get interactionQuizWrong => 'Quase';

  @override
  String interactionEventPast(String when) {
    return '$when · já passou';
  }

  @override
  String get interactionRespondentsTitlePoll => 'Quem votou';

  @override
  String get interactionRespondentsTitleChecklist => 'Quem marcou';

  @override
  String get interactionRespondentsTitleEvent => 'Quem respondeu';

  @override
  String get interactionRespondentsFailed =>
      'Não deu para carregar quem respondeu.';

  @override
  String get interactionRespondentsEmpty => 'Ainda ninguém respondeu.';

  @override
  String get interactionFilterAll => 'Todos';

  @override
  String get interactionRsvpGoing => 'Vou';

  @override
  String get interactionRsvpMaybe => 'Talvez';

  @override
  String get interactionRsvpNo => 'Não posso';

  @override
  String get interactionComposePollTitle => 'Nova enquete';

  @override
  String get interactionComposePollTagline => 'Pergunta à sala';

  @override
  String get interactionComposeChecklistTitle => 'Nova lista';

  @override
  String get interactionComposeChecklistTagline => 'Uma lista que todos marcam';

  @override
  String get interactionComposeEventTitle => 'Novo evento';

  @override
  String get interactionComposeEventTagline => 'Veja quem vem';

  @override
  String get interactionComposeQuestionLabel => 'Pergunta';

  @override
  String get interactionComposeQuestionHint => 'O que você quer perguntar?';

  @override
  String get interactionComposeTitleLabel => 'Título';

  @override
  String get interactionComposeTitleHint => 'Para que serve esta lista?';

  @override
  String get interactionComposeEventNameLabel => 'Evento';

  @override
  String get interactionComposeEventNameHint => 'O que vai acontecer?';

  @override
  String get interactionComposeOptionsLabel => 'Opções';

  @override
  String get interactionComposeItemsLabel => 'Itens';

  @override
  String interactionComposeOptionHint(int index) {
    return 'Opção $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return 'Item $index';
  }

  @override
  String get interactionComposeAddOption => 'Adicionar opção';

  @override
  String get interactionComposeAddItem => 'Adicionar item';

  @override
  String get interactionComposeRemoveRow => 'Remover';

  @override
  String get interactionComposeMarkCorrect => 'Marcar como resposta certa';

  @override
  String get interactionComposeMultipleTitle => 'Várias respostas';

  @override
  String get interactionComposeMultipleSub => 'Escolher mais do que uma';

  @override
  String get interactionComposeAnonymousTitle => 'Anônima';

  @override
  String get interactionComposeAnonymousOffSub => 'Todos veem quem votou';

  @override
  String get interactionComposeAnonymousOnSub => 'Ninguém vê quem votou';

  @override
  String get interactionComposeQuizTitle => 'Modo quiz';

  @override
  String get interactionComposeQuizSub =>
      'Uma só resposta certa, sem mudar depois';

  @override
  String get interactionComposeExplanationLabel => 'Explicação';

  @override
  String get interactionComposeExplanationHint =>
      'Mostrada depois de responder (opcional)';

  @override
  String get interactionComposeOthersMayCheckTitle => 'Qualquer um pode marcar';

  @override
  String get interactionComposeOthersMayCheckSub => 'Não só você';

  @override
  String get interactionComposeOthersMayAddTitle =>
      'Qualquer um pode adicionar';

  @override
  String get interactionComposeOthersMayAddSub => 'A lista pode crescer depois';

  @override
  String get interactionComposeWhenLabel => 'Quando';

  @override
  String get interactionComposePickStart => 'Escolha o início';

  @override
  String get interactionComposePickEnd => 'Adicionar um fim (opcional)';

  @override
  String get interactionComposePlaceLabel => 'Local';

  @override
  String get interactionComposePlaceHint => 'Onde? (opcional)';

  @override
  String get interactionComposeSendPoll => 'Enviar a enquete';

  @override
  String get interactionComposeSendChecklist => 'Enviar a lista';

  @override
  String get interactionComposeSendEvent => 'Enviar o evento';

  @override
  String get interactionComposeErrorPrompt =>
      'Diga primeiro o que você está perguntando.';

  @override
  String interactionComposeErrorOptions(int count) {
    return 'Uma enquete precisa de pelo menos $count opções.';
  }

  @override
  String get interactionComposeErrorItems =>
      'Uma lista precisa de pelo menos um item.';

  @override
  String get interactionComposeErrorAnswer => 'Marque qual é a opção certa.';

  @override
  String get interactionComposeErrorWhen => 'Escolha quando começa.';

  @override
  String get interactionComposeErrorEnd => 'O fim tem de vir depois do início.';

  @override
  String get interactionSendFailed => 'Não foi enviado.';

  @override
  String get interactionRefused => 'Não foi registrado.';

  @override
  String get messageReceiptsScreenTitle => 'Info da mensagem';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$read de $total leram';
  }

  @override
  String get messageReceiptsEmptyState =>
      'Ainda não há mais ninguém nesta sala';

  @override
  String get messageReceiptsSectionRead => 'Lido';

  @override
  String get messageReceiptsSectionDelivered => 'Entregue';

  @override
  String get messageReceiptsSectionSent => 'Enviado';

  @override
  String get messageReceiptsSectionHidden => 'Sem confirmação';

  @override
  String get messageReceiptsStateHidden => 'Não compartilhado';

  @override
  String get messageReceiptsStateWaiting => 'Aguardando';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name leu isto $day às $time';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name recebeu isto $day às $time';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name ainda não recebeu isto';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name não compartilha confirmações de leitura';
  }

  @override
  String get companionsScreenTitle => 'companheiros.';

  @override
  String get companionsScreenSubtitle =>
      'ajudantes que vivem neste celular e não enviam nada para lugar nenhum';

  @override
  String get companionSebastianTagline => 'Traduz mensagens';

  @override
  String get companionSebastianBlurb =>
      'O Sebastian lê uma mensagem escrita em outro idioma e te diz o que ela diz, aqui, no seu celular, sem enviar nada para lugar nenhum.';

  @override
  String get companionMarloweTagline => 'Ajuda geral';

  @override
  String get companionMarloweBlurb =>
      'Marlowe cuida de tudo que não for tradução. Escolha um cérebro agora, e as habilidades vão chegar em volta disso.';

  @override
  String get companionAssuranceOnDevice =>
      'Funciona inteiramente neste dispositivo';

  @override
  String get companionAssurancePrivate =>
      'Suas mensagens nunca saem do seu celular';

  @override
  String get companionAssuranceOffline => 'Funciona sem internet';

  @override
  String companionInstallAction(Object size) {
    return 'Instalar · $size';
  }

  @override
  String get companionInstallOneTime =>
      'Download único, fica salvo até você remover';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$received de $total';
  }

  @override
  String get companionInstallQueued => 'Esperando outro download terminar';

  @override
  String get companionInstallCancel => 'Cancelar';

  @override
  String get companionInstallRetry => 'Tentar de novo';

  @override
  String companionInstallReady(Object name) {
    return '$name está pronto';
  }

  @override
  String get companionInstallFailedNetwork =>
      'O download não foi concluído. Verifique sua conexão e tente de novo.';

  @override
  String get companionInstallFailedStorage =>
      'Não há espaço suficiente neste dispositivo. Libere um pouco e tente de novo.';

  @override
  String get companionInstallFailedUnknown => 'O download não foi concluído.';

  @override
  String get companionUnsupportedPlatform =>
      'Os companheiros ainda não estão disponíveis nesta versão do app.';

  @override
  String companionBrainNeedsMemory(String size) {
    return 'Precisa de $size de memória';
  }

  @override
  String get sebastianTierSeniorDetail => 'Traduções mais precisas';

  @override
  String get sebastianTierJuniorDetail => 'Funciona em qualquer celular';

  @override
  String get sebastianLanguageUnlisted =>
      'Não é um dos idiomas dele. Resultados imprecisos';

  @override
  String get companionStatusNotInstalled => 'Não instalado';

  @override
  String get companionStatusOff => 'Desligado';

  @override
  String companionStatusTranslatingInto(Object language) {
    return 'A traduzir para $language';
  }

  @override
  String get companionStatusNoBrain => 'Você ainda não baixou nada';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count downloads prontos',
      one: '1 download pronto',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty =>
      'Nada baixado. Os companheiros não ocupam espaço';

  @override
  String companionStorageUsed(Object size) {
    return 'Os companheiros ocupam $size';
  }

  @override
  String get companionSectionGeneral => 'Geral';

  @override
  String get companionSectionStorage => 'Armazenamento';

  @override
  String get companionBrainRemove => 'Remover';

  @override
  String companionBrainRemoveTitle(Object name) {
    return 'REMOVER $name?';
  }

  @override
  String companionRemoveTitle(Object name) {
    return 'REMOVER $name?';
  }

  @override
  String companionRemoveMessage(Object size) {
    return 'Isso libera $size. Você pode baixar de novo quando quiser.';
  }

  @override
  String get companionRemoveConfirm => 'Remover';

  @override
  String get sebastianEnableLabel => 'Deixar o Sebastian traduzir';

  @override
  String get sebastianEnableDetail =>
      'Desligue para pará-lo sem apagar o download';

  @override
  String get sebastianLanguageSection => 'Traduzir para';

  @override
  String get sebastianLanguageFollowApp => 'O mesmo do app';

  @override
  String sebastianBrainDetail(Object size) {
    return 'Neste dispositivo · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count traduções guardadas',
      one: '1 tradução guardada',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => 'Limpar';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe ainda não faz nada: as habilidades estão a caminho. O que você já pode fazer é deixar um cérebro pronto, para que nada dependa de um download quando elas chegarem.';

  @override
  String get marloweBrainsSection => 'Cérebro';

  @override
  String get marloweBrainsCaption =>
      'Maior pensa melhor e responde mais devagar. Você pode guardar mais de um e alternar entre eles.';

  @override
  String get marloweBrainTierSwift => 'Rápido';

  @override
  String get marloweBrainTierBalanced => 'Equilibrado';

  @override
  String get marloweBrainTierDeep => 'Profundo';

  @override
  String get translationSlabShowOriginal => 'Ver original';

  @override
  String get translationSlabFailed =>
      'Não foi possível traduzir esta mensagem.';

  @override
  String get translationSlabRetry => 'Tentar de novo';

  @override
  String translationSlabByCompanion(Object name) {
    return 'Traduzido pelo $name';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return 'De $language';
  }

  @override
  String get messageActionMenuTranslateLabel => 'Traduzir';

  @override
  String get messageActionMenuShowOriginalLabel => 'Ver original';

  @override
  String get roomTranslateTitle => 'Traduzir esta conversa';

  @override
  String get roomTranslateStopTitle => 'Parar de traduzir';

  @override
  String get roomTranslateSectionLabel => 'TRADUÇÃO';

  @override
  String get roomTranslateOnRow => 'A traduzir esta conversa';

  @override
  String get roomTranslateOffRow => 'Desligado';

  @override
  String get roomTranslateNeedsSetUp => 'Configurar o Sebastian';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'O Sebastian está a traduzir · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return 'A ler em $language';
  }

  @override
  String get roomTranslateStop => 'PARAR';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return 'Já está em $language';
  }

  @override
  String get roomScreenTranslateRoomOffer =>
      'Traduzir o resto da conversa também?';

  @override
  String get roomScreenTranslateRoomOfferAction => 'Traduzir tudo';

  @override
  String get settingsScreenCompanionsOff => 'Desligado';

  @override
  String get settingsScreenCompanionsUnavailable => 'Indisponível';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return 'Também usado pela $name';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return 'A $name usa o mesmo download e também vai perdê-lo.';
  }

  @override
  String get companionBrainInUse => 'Em uso';

  @override
  String companionStatusUsingBrain(Object name) {
    return 'Usando $name';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name continua baixando. Configurações › Companheiros';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return 'Baixando · $percent%';
  }

  @override
  String get companionInstallPause => 'Pausar';

  @override
  String get companionInstallResume => 'Retomar';

  @override
  String get companionInstallDiscard => 'Descartar';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return 'Pausado · $received de $total';
  }

  @override
  String get companionInstallFailedIntegrity =>
      'O arquivo baixado não corresponde ao que esta versão espera. Começando de novo.';

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
    return '$name pausado · $received de $total';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name está acordando…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => 'Traduzir de novo';

  @override
  String get groupCallScreenShareLabel => 'Compartilhar';

  @override
  String get groupCallScreenStopShareLabel => 'Parar de compartilhar';

  @override
  String get groupCallScreenShareStartingLabel => 'Iniciando…';

  @override
  String get groupCallScreenRingingLabel => 'Chamando…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name está compartilhando a tela';
  }

  @override
  String get groupCallScreenYouAreSharing =>
      'Você está compartilhando sua tela';

  @override
  String get groupCallScreenMinimizeLabel => 'Ocultar';

  @override
  String get groupCallScreenDrawLabel => 'Desenhar';

  @override
  String get callScreenControlShare => 'Compartilhar';

  @override
  String get callScreenControlStopShare => 'Parar';

  @override
  String get callScreenControlShareStarting => 'Iniciando…';

  @override
  String get screenShareStopDrawing => 'Parar de desenhar';

  @override
  String get screenShareDrawBoardIdle => 'Os desenhos aparecem aqui';

  @override
  String get screenShareOverlayHint =>
      'Mostre os desenhos sobre outros apps enquanto compartilha';

  @override
  String get screenShareOverlayAllow => 'Permitir';

  @override
  String get callScreenControlDraw => 'Desenhar';

  @override
  String get callScreenControlMinimize => 'Ocultar';

  @override
  String get inCallPillOngoingCall => 'Chamada em andamento';

  @override
  String get inCallPillReturn => 'Voltar';

  @override
  String get inCallPillSharing => 'Compartilhando sua tela';

  @override
  String get inCallPillDrawSemanticLabel => 'Desenhar na tela compartilhada';

  @override
  String get inCallPillStopSharingSemanticLabel => 'Parar de compartilhar';

  @override
  String get screenShareUnsupported =>
      'Compartilhar a tela não está disponível neste dispositivo';

  @override
  String get screenShareEphemeralWarning =>
      'A proteção contra capturas fica desligada enquanto você compartilha';

  @override
  String get screenShareNotificationTitle => 'Compartilhando sua tela';

  @override
  String get screenShareNotificationBody => 'Todos na chamada podem ver';

  @override
  String get screenShareNotificationStop => 'Parar';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name já está compartilhando';
  }

  @override
  String get screenShareFailed => 'Não foi possível começar a compartilhar';

  @override
  String get screenSharePickerTitle => 'Compartilhe sua tela';

  @override
  String get screenSharePickerScreens => 'Telas';

  @override
  String get screenSharePickerWindows => 'Janelas';

  @override
  String get screenSharePickerEmpty =>
      'Nada para compartilhar ainda. Permita a gravação de tela nos Ajustes do Sistema e tente de novo';

  @override
  String get gameTellFriends => 'Avisar os amigos';

  @override
  String get gameToldFriends => 'Já sabem';

  @override
  String get gameTellFriendsTitle => 'Avisar seus amigos?';

  @override
  String get gameTellFriendsBody =>
      'eles recebem uma notificação com este resultado. só dá para enviar uma vez.';

  @override
  String get gameTellFriendsCancel => 'Agora não';

  @override
  String get gameTellFriendsConfirm => 'Enviar';

  @override
  String get gameTellFriendsSent => 'Enviado. Eles já sabem';

  @override
  String get gameTellFriendsPrivate =>
      'Seus resultados diários são privados, ninguém veria isso';

  @override
  String get gameTellFriendsFailed => 'Não deu para enviar';

  @override
  String get settingsScreenFriendActivityLabel => 'ATIVIDADE DOS AMIGOS';

  @override
  String get settingsScreenFriendActivityOnBody =>
      'momentos, pontos e resultados conforme eles postam';

  @override
  String get settingsScreenFriendActivityOffBody =>
      'nada. Os quadros deles continuam lá quando você olhar';

  @override
  String get searchScreenActionWithGrownUp => 'Com um adulto';

  @override
  String get newChatMenuSearchHint => 'Busque nos seus amigos';

  @override
  String get newChatMenuNoFriendsYet =>
      'Ainda sem amigos. Encontre pessoas em Descobrir';

  @override
  String get newChatMenuNoFriendsMatch => 'Nenhum amigo corresponde';

  @override
  String get newChatMenuOpenDmFailed =>
      'Não deu para abrir esse chat. Tente de novo';

  @override
  String get childPolicyScreenAddSomeoneLabel => 'Escolher das suas pessoas';

  @override
  String get childPolicyScreenPickPersonHint =>
      'Busque um nome ou nome de usuário';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      'Não sobrou ninguém para adicionar dos seus amigos,\\nbusque outra pessoa';

  @override
  String get childPolicyScreenPickPersonNoMatch => 'Ninguém corresponde';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'Seus amigos';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'Todo mundo mais';

  @override
  String get childPolicyScreenAddRoomLabel => 'Adicionar uma sala';

  @override
  String get childPolicyScreenPickRoomHeading => 'Adicionar uma sala';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'Uma das suas próprias salas. $name entra na hora e pode ler e escrever lá até você retirar.';
  }

  @override
  String get childPolicyScreenPickRoomHint => 'Busque nas suas salas';

  @override
  String get childPolicyScreenPickRoomEmpty =>
      'Não restam salas suas para adicionar';

  @override
  String get childPolicyScreenPickRoomNoMatch => 'Nenhuma sala corresponde';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name está em $room agora';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'Não deu para adicionar essa sala. Tente de novo';

  @override
  String get childPolicyScreenErrorRoomNotAllowed =>
      'Essa sala não pode ser adicionada assim';

  @override
  String get childPolicyScreenErrorRoomGone => 'Essa sala não existe mais';

  @override
  String get newChatMenuFriendsHeader => 'Amigos';

  @override
  String get roomChangeErrorGone =>
      'Essa sugestão sumiu. Algum admin deve ter respondido.';

  @override
  String get roomChangeErrorNotYours => 'Só quem sugeriu pode retirar.';

  @override
  String get roomChangeErrorNoChange => 'Já é isso que está escrito.';

  @override
  String get roomChangeErrorMissingValue => 'Assim não dá para salvar.';

  @override
  String get roomChangeRequestsTitle => 'Sugestões';

  @override
  String get roomChangeRequestsBlurb =>
      'Quem sugeriu foram os membros. Nada muda até você dizer que sim.';

  @override
  String get roomChangeRequestsEmpty => 'Nenhuma sugestão.';

  @override
  String get roomChangeRequestsApprove => 'USAR';

  @override
  String get roomChangeRequestsReject => 'NÃO';

  @override
  String get roomChangeRequestsPhotoLabel => 'Nova foto do grupo';

  @override
  String get roomChangeRequestsNameLabel => 'Novo nome';

  @override
  String get roomChangeRequestsDescriptionLabel => 'Nova descrição';

  @override
  String get roomChangeRequestsUnknownLabel =>
      'Uma mudança que este app ainda não sabe mostrar';

  @override
  String get roomChangeRequestsClearedValue => 'Nada, tirar';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name sugeriu';
  }

  @override
  String get roomAdminChangeRequestsRow => 'Sugestões';

  @override
  String get roomInfoScreenSuggestNote =>
      'Isso precisa da aprovação de um admin';

  @override
  String get roomInfoScreenSuggestAvatarNote =>
      'Fotos novas passam por um admin';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic =>
      'Sugerir uma foto do grupo';

  @override
  String get roomInfoScreenSuggestionSentToast => 'Enviado para os admins';

  @override
  String get roomInfoScreenSuggestionAppliedToast =>
      'Pronto, você pode editar este grupo';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => 'Retirado';

  @override
  String get roomInfoScreenSuggestionsLabel => 'VOCÊ SUGERIU';

  @override
  String get roomInfoScreenSuggestionPhoto => 'Uma foto nova do grupo';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return 'Nome: $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return 'Descrição: $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => 'Uma mudança';

  @override
  String get roomInfoScreenSuggestionPending => 'Esperando um admin';

  @override
  String get roomInfoScreenSuggestionWithdraw => 'Retirar';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name sugeriu uma nova foto do grupo';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name sugeriu um novo nome';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name sugeriu uma nova descrição';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sugestões esperando você',
      one: '$count sugestão esperando você',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => 'Revisar';

  @override
  String get roomSuggestionBannerSemantic =>
      'Sugestões de membros esperando sua revisão';

  @override
  String get gameInfoPlay => 'Jogar';

  @override
  String get gameInfoContinue => 'Continuar';

  @override
  String get gameInfoSeeResult => 'Ver seu resultado';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return 'Entregue a $delivered de $total';
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
    return '$name recebeu isto $deliveredDay às $deliveredTime e leu $readDay às $readTime';
  }

  @override
  String get messageReceiptsStampRead => 'Lida';

  @override
  String get messageReceiptsStampDelivered => 'Entregue';

  @override
  String get roomInviteCustom => 'Outro';

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
      other: '$count dias',
      one: '$count dia',
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
  String get roomInviteUnitDays => 'Dias';

  @override
  String get roomInviteStepperIncrease => 'Aumentar';

  @override
  String get roomInviteStepperDecrease => 'Diminuir';

  @override
  String get recordsLabel => 'Recordes';

  @override
  String get recordsBlurb => 'O melhor de todos os tempos: você e seus amigos';

  @override
  String recordsYourBest(Object value) {
    return 'O seu $value';
  }

  @override
  String get recordsNoneYet => 'Ninguém ainda';

  @override
  String get recordsEmpty =>
      'Resolva qualquer jogo e seu melhor resultado aparece aqui.';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count resolvidos',
      one: '$count resolvido',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return 'Feito em $date';
  }

  @override
  String recordsReactSemantic(Object name) {
    return 'Reagir ao recorde de $name';
  }

  @override
  String get recordsReactFailed => 'Não foi possível reagir';

  @override
  String get recordsLoadFailed => 'Não foi possível carregar os recordes';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game: recorde de $value por $name';
  }

  @override
  String get appearanceLabel => 'Aparência';

  @override
  String get appearanceMatchDevice => 'Igual ao aparelho';

  @override
  String get appearanceMatchDeviceSub =>
      'Claro de dia, escuro à noite, como o seu celular';

  @override
  String get appearanceOneTheme => 'Um só tema';

  @override
  String get appearanceOneThemeSub => 'O mesmo visual o dia todo';

  @override
  String get appearanceLightSlot => 'Modo claro';

  @override
  String get appearanceDarkSlot => 'Modo escuro';

  @override
  String get appearanceNow => 'Agora';

  @override
  String appearanceAutoValue(Object name) {
    return 'Auto · $name';
  }

  @override
  String get themeScreenAssignHint =>
      'toque num tema para usar no modo claro ou escuro · ⛶ para ver inteiro';

  @override
  String get themeScreenCarouselUseLight => 'USAR NO MODO CLARO';

  @override
  String get themeScreenCarouselUseDark => 'USAR NO MODO ESCURO';

  @override
  String get themeScreenCarouselIsLight => 'SEU TEMA CLARO';

  @override
  String get themeScreenCarouselIsDark => 'SEU TEMA ESCURO';

  @override
  String get onboardingThemeTitle => 'do seu jeito.';

  @override
  String get onboardingThemeBody =>
      'escolha um visual. dá para mudar quando quiser nos ajustes.';

  @override
  String get onboardingThemeYourTheme => 'SEU TEMA';

  @override
  String get onboardingThemeContinue => 'CONTINUAR';

  @override
  String get dropHintNoTarget => 'Solte em uma conversa para enviar';

  @override
  String get dropNothingToSend => 'Nada aqui pode ser enviado';

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
      other: 'Enviar $count áudios',
      one: 'Enviar áudio',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar $count arquivos',
      one: 'Enviar arquivo',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar $count itens',
      one: 'Enviar item',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => 'Adicionar à mensagem';

  @override
  String get dropSendLink => 'Adicionar link';

  @override
  String dropTargetTo(String name) {
    return 'Para $name';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count arquivos passam de $size',
      one: '1 arquivo passa de $size',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => 'Não dá para enviar pastas';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pulando $count arquivos vazios',
      one: 'Pulando um arquivo vazio',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => 'Anexos não são permitidos aqui';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vão como arquivos',
      one: 'Vai como arquivo',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count podem não aparecer em todo lugar',
      one: 'Pode não aparecer em todo lugar',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => 'foto';

  @override
  String get dropKindVideo => 'vídeo';

  @override
  String get dropKindAudio => 'áudio';

  @override
  String get dropKindFile => 'arquivo';

  @override
  String get dropKindFolder => 'pasta';

  @override
  String get dropKindText => 'texto';

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
      other: '$count arquivos não couberam neste envio',
      one: '1 arquivo não coube neste envio',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed =>
      'Não deu para fazer isso. Tente de novo.';

  @override
  String get expressionBackspace => 'Apagar';

  @override
  String get expressionCreateSticker => 'Criar uma figurinha';

  @override
  String get expressionDeleteSticker => 'Excluir das minhas figurinhas';

  @override
  String get expressionFavorite => 'Adicionar aos favoritos';

  @override
  String get expressionFavorited => 'Adicionado aos favoritos';

  @override
  String get expressionFavorites => 'Favoritos';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF: $title';
  }

  @override
  String get expressionLoadFailed =>
      'Não foi possível carregar. Verifique sua conexão.';

  @override
  String get expressionMediaNotAllowed =>
      'As configurações da sua família não permitem enviar imagens.';

  @override
  String get expressionMyStickers => 'Minhas figurinhas';

  @override
  String get expressionNoFavorites =>
      'Toque e segure um GIF ou figurinha para adicionar aos favoritos.';

  @override
  String get expressionNoRecents =>
      'Os GIFs e figurinhas que você enviar vão aparecer aqui.';

  @override
  String get expressionNoResults => 'Nenhum resultado';

  @override
  String get expressionNoStickers => 'Ainda não há figurinhas aqui.';

  @override
  String get expressionOpenPanel => 'Emojis, GIFs e figurinhas';

  @override
  String get expressionOptionsHint => 'Mostrar opções';

  @override
  String expressionPackCredit(String author, String license) {
    return 'Arte: $author · $license';
  }

  @override
  String get expressionPlayGifHint => 'reproduzir';

  @override
  String get expressionRecent => 'Recentes';

  @override
  String get expressionReport => 'Denunciar';

  @override
  String get expressionReported => 'Valeu, foi denunciado.';

  @override
  String get expressionRetry => 'Tentar de novo';

  @override
  String get expressionSearchKlipy => 'Buscar no KLIPY';

  @override
  String get expressionShowKeyboard => 'Mostrar teclado';

  @override
  String get expressionSuggestionsLabel => 'Sugestões de figurinhas';

  @override
  String get expressionTabEmoji => 'Emojis';

  @override
  String get expressionTabGifs => 'GIFs';

  @override
  String get expressionTabStickers => 'Figurinhas';

  @override
  String get expressionTrending => 'Em alta';

  @override
  String get expressionUnfavorite => 'Remover dos favoritos';

  @override
  String get expressionUnfavorited => 'Removido dos favoritos';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return 'Figurinha $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel =>
      'Reproduzir GIFs e figurinhas automaticamente';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      'Ficam paradas até você tocar em uma. Economiza dados.';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'GIFs e figurinhas animadas tocam sozinhos. Reduzir Movimento pausa tudo.';

  @override
  String get settingsAlbumCardsLabel => 'Álbuns de fotos como cartões';

  @override
  String get settingsAlbumCardsOffBody =>
      'Várias fotos em uma mensagem aparecem em grade.';

  @override
  String get settingsAlbumCardsOnBody =>
      'Várias fotos em uma mensagem aparecem em uma pilha que você desliza para ver.';

  @override
  String get settingsStickerSuggestionsBody =>
      'Digitar um único emoji mostra figurinhas correspondentes acima do campo de mensagem.';

  @override
  String get settingsStickerSuggestionsLabel => 'Sugestões de figurinhas';

  @override
  String get stickerMakerEmojiLabel => 'Qual emoji é?';

  @override
  String get stickerMakerFailed =>
      'Não foi possível salvar a figurinha. Tente de novo.';

  @override
  String get stickerMakerMoreEmoji => 'Mais emojis';

  @override
  String get stickerMakerPreview => 'Prévia da figurinha';

  @override
  String get stickerMakerRemoveBackground => 'Remover fundo';

  @override
  String get stickerMakerSave => 'Salvar';

  @override
  String get stickerMakerSaved => 'Figurinha adicionada a Minhas figurinhas';

  @override
  String get stickerMakerShape => 'Formato';

  @override
  String get stickerMakerShapeCircle => 'Círculo';

  @override
  String get stickerMakerShapeOriginal => 'Original';

  @override
  String get stickerMakerShapeRounded => 'Quadrado arredondado';

  @override
  String get stickerMakerTitle => 'Nova figurinha';

  @override
  String get stickerMakerTooMany =>
      'Você chegou ao limite de figurinhas. Exclua uma para liberar espaço.';

  @override
  String get expressionExpandPanel => 'Expandir painel';

  @override
  String get expressionCollapsePanel => 'Reduzir painel';

  @override
  String get expressionPackStore => 'Pacotes de figurinhas';

  @override
  String get expressionPackSearchHint => 'Buscar pacotes de figurinhas';

  @override
  String get expressionPacksAdded => 'Adicionados';

  @override
  String get expressionPacksMore => 'Mais pacotes';

  @override
  String get expressionPackAdd => 'Adicionar';

  @override
  String get expressionPackRemove => 'Remover';

  @override
  String expressionPackStickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count figurinhas',
      one: '1 figurinha',
    );
    return '$_temp0';
  }

  @override
  String get expressionNoPacksFound => 'Nenhum pacote encontrado';

  @override
  String get expressionAllPacksAdded => 'Você já adicionou todos os pacotes.';

  @override
  String expressionPackReorder(String title) {
    return 'Reordenar $title';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return 'Adicionar o pacote “$title”';
  }

  @override
  String expressionPackAddedToast(String title) {
    return '“$title” adicionado às suas figurinhas';
  }

  @override
  String get expressionPacksFromKlipy => 'Mais figurinhas do KLIPY';

  @override
  String expressionSearchKlipyFor(String query) {
    return 'Buscar “$query” no KLIPY';
  }

  @override
  String get expressionHideKeyboard => 'Ocultar teclado';

  @override
  String get expressionSearchStickers => 'Buscar figurinhas';

  @override
  String get expressionYourStickers => 'Suas figurinhas';

  @override
  String get chatListYesterday => 'Ontem';

  @override
  String get roomLayoutScreenCardsLayoutLabel => 'CARTÕES';

  @override
  String get roomLayoutScreenCardsLayoutDescription =>
      'cada sala no seu próprio cartão, com todos os detalhes.';

  @override
  String get homeScreenTitle => 'Conversas';

  @override
  String get glassScreenNativeLabel => 'Liquid Glass do iOS';

  @override
  String get glassScreenNativeOnBody =>
      'A barra de abas é desenhada pelo próprio iOS. Os controles abaixo ajustam o resto do app.';

  @override
  String get glassScreenNativeOffBody =>
      'O MonkeyHub desenha o próprio vidro em todo lugar, ajustado pelos controles abaixo.';

  @override
  String get glassScreenHeading => 'Vidro';

  @override
  String get glassStyleHeader => 'Estilo';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody =>
      'O vidro da própria Apple, desenhado pelo iOS. Os botões do app combinam com ele.';

  @override
  String get glassStyleFrostedTitle => 'Fosco';

  @override
  String get glassStyleFrostedBody =>
      'O vidro do próprio MonkeyHub. Ajuste cada controle do seu jeito.';

  @override
  String get glassStyleRecommended => 'Recomendado';

  @override
  String get glassStyleLiquidFooter =>
      'Nada para ajustar: o iOS define o desfoque, a tonalidade e a luz. Escolha Fosco para moldar o vidro você mesmo.';

  @override
  String get acctSectionPrivacy => 'Privacidade';

  @override
  String get acctSectionAccount => 'Conta';

  @override
  String get acctSectionFamily => 'Família';

  @override
  String get acctSectionThisPhone => 'Este celular';

  @override
  String get acctRowVisibility => 'Visibilidade do perfil';

  @override
  String get acctRowBlocked => 'Usuários bloqueados';

  @override
  String get acctRowApprovals => 'Aprovações';

  @override
  String get acctNothingWaiting => 'Nada pendente';

  @override
  String get acctRowLinked => 'Contas vinculadas';

  @override
  String get acctRowScanToSignIn => 'Escanear para entrar';

  @override
  String get acctRowSetUpRecovery => 'Configurar frase de recuperação';

  @override
  String get acctRowChangeRecovery => 'Alterar frase de recuperação';

  @override
  String get acctSignOut => 'Sair';

  @override
  String get acctDeleteAccount => 'Excluir conta';

  @override
  String get acctConfirmDelete => 'Toque de novo para excluir';

  @override
  String get acctHandPhoneBack => 'Devolver este celular';

  @override
  String get acctMyGrownUps => 'Meus responsáveis';

  @override
  String get acctActionMessage => 'Mensagem';

  @override
  String get acctActionAddFriend => 'Adicionar';

  @override
  String get acctActionRequested => 'Solicitado';

  @override
  String get acctActionAccept => 'Aceitar';

  @override
  String get acctActionNotAccepting => 'Fechado';

  @override
  String get acctActionUnfriend => 'Desfazer';

  @override
  String get acctActionBlock => 'Bloquear';

  @override
  String get acctActionReport => 'Denunciar';

  @override
  String get acctStatusFriends => 'Vocês são amigos';

  @override
  String get acctStatusRequestSent => 'Solicitação enviada';

  @override
  String get acctStatusWantsToConnect => 'Quer ser seu amigo';

  @override
  String get acctStatusNotConnected => 'Sem conexão';

  @override
  String get acctPresenceOnline => 'Online';

  @override
  String get acctPresenceAway => 'Ausente';

  @override
  String get acctPresenceOffline => 'Offline';

  @override
  String get acctProfilePhoto => 'Foto do perfil';

  @override
  String get acctSaveToPhotos => 'Salvar em Fotos';

  @override
  String get acctTakeSelfie => 'Tirar uma selfie';

  @override
  String get acctChooseFromLibrary => 'Escolher da biblioteca';

  @override
  String get acctCancel => 'Cancelar';

  @override
  String get acctSave => 'Salvar';

  @override
  String get acctChange => 'Alterar';

  @override
  String get acctNotNow => 'Agora não';

  @override
  String get acctAddEmail => 'Adicionar e-mail';

  @override
  String get acctEditNameTitle => 'Editar nome';

  @override
  String get acctAddNameTitle => 'Adicione seu nome';

  @override
  String get acctEditEmailTitle => 'Editar e-mail';

  @override
  String get acctChangeUsernameTitle => 'Alterar nome de usuário?';

  @override
  String get onboardingLookTitle => 'Do seu jeito';

  @override
  String get onboardingLookBody =>
      'Escolha um visual. Você pode mudar quando quiser em Ajustes.';

  @override
  String get onboardingEssentials => 'Essenciais';

  @override
  String get onboardingEssentialsSub => 'Sóbrios e nativos';

  @override
  String get onboardingCharacters => 'Com personalidade';

  @override
  String get onboardingCharactersSub => 'O mesmo app, mais personalidade';

  @override
  String get onboardingLightMode => 'Modo claro';

  @override
  String get onboardingDarkMode => 'Modo escuro';

  @override
  String get onboardingNow => 'Agora';

  @override
  String get onboardingContinue => 'Continuar';

  @override
  String get onboardingIconTitle => 'Seu ícone do app';

  @override
  String get onboardingIconBody =>
      'Mantenha seu ícone, deixe que ele siga o tema ou escolha qualquer outro.';

  @override
  String get onboardingIconIosNote =>
      'O iOS mostra um aviso rápido sempre que o ícone muda.';

  @override
  String get onboardingGetStarted => 'Começar';

  @override
  String get appIconMatchTheme => 'Seguir o tema';

  @override
  String get appIconCurrent => 'Atual';

  @override
  String get appIconSectionCollection => 'Coleção MonkeyHub';

  @override
  String get appIconSectionThemes => 'Ícones dos temas';

  @override
  String get appIconScreenTitle => 'Ícone do app';

  @override
  String get appIconMatchFooter =>
      'Seguir o tema troca o ícone junto com seu tema escuro, para ele não ficar mudando ao longo do dia.';

  @override
  String get loginTitleReturning => 'Que bom te ver de novo';

  @override
  String get loginTitleFirst => 'Boas-vindas ao MonkeyHub';

  @override
  String get loginTitleSignUp => 'Crie sua conta';

  @override
  String get loginTitleReset => 'Redefina sua senha';

  @override
  String get loginSubtitleSignIn => 'Entre para continuar de onde parou.';

  @override
  String get loginSubtitleFirst => 'Entre ou crie uma conta em segundos.';

  @override
  String get loginSubtitleSignUp =>
      'Só precisa de um nome de usuário e uma senha.';

  @override
  String get loginSubtitleReset =>
      'Digite sua frase de recuperação de 12 palavras e escolha uma nova senha.';

  @override
  String get loginCtaSignIn => 'Entrar';

  @override
  String get loginCtaSignUp => 'Criar conta';

  @override
  String get loginCtaReset => 'Redefinir senha';

  @override
  String get loginNoAccountPrompt => 'Novo por aqui? ';

  @override
  String get loginCreateAccountLink => 'Crie uma conta';

  @override
  String get loginHaveAccountPrompt => 'Já tem uma conta? ';

  @override
  String get loginSignInLink => 'Entrar';

  @override
  String get loginForgotPassword => 'Esqueceu a senha?';

  @override
  String get loginChildAccount => 'Configurar conta infantil';

  @override
  String get loginBackToSignIn => 'Voltar para entrar';

  @override
  String get loginWithPhone => 'Entrar com o celular';

  @override
  String get loginUsernameField => 'Nome de usuário';

  @override
  String get loginPasswordField => 'Senha';

  @override
  String get loginConfirmPasswordField => 'Confirmar senha';

  @override
  String get loginNameField => 'Nome (opcional)';

  @override
  String get loginRecoveryPhraseField =>
      'Sua frase de recuperação de 12 palavras';

  @override
  String get loginNewPasswordField => 'Nova senha';

  @override
  String get roomHeaderStatusOnline => 'Online';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '$count membro',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => 'Ajustes';

  @override
  String get settingsHubAccountHintAdult =>
      'Perfil, família, contas vinculadas e privacidade';

  @override
  String get settingsHubAccountHintChild =>
      'Perfil, privacidade e seus responsáveis';

  @override
  String get settingsHubSectionGeneral => 'Geral';

  @override
  String get settingsHubSectionNotifications => 'Notificações';

  @override
  String get settingsHubSectionCalls => 'Chamadas';

  @override
  String get settingsHubSectionAppearance => 'Aparência';

  @override
  String get settingsHubSectionCompanions => 'Companheiros';

  @override
  String get settingsHubSectionChats => 'Conversas';

  @override
  String get settingsHubSectionHelp => 'Ajuda e jurídico';

  @override
  String get settingsHubSectionAdvanced => 'Avançado';

  @override
  String get settingsHubLanguage => 'Idioma';

  @override
  String get settingsHubCheckForUpdates => 'Verificar atualizações';

  @override
  String get settingsHubUpdateAvailable => 'Atualização disponível';

  @override
  String get settingsHubShowLinkUrls => 'Mostrar endereços dos links';

  @override
  String get settingsHubShowLinkUrlsSubtitle =>
      'Mostra o endereço ao lado de cada prévia';

  @override
  String get settingsHubPresenceDots => 'Mostrar quem está online';

  @override
  String get settingsHubPresenceDotsSubtitle => 'A bolinha nas fotos de perfil';

  @override
  String get settingsHubPush => 'Notificações push';

  @override
  String get settingsHubPushSubtitle => 'Novas mensagens, chamadas e pedidos';

  @override
  String get settingsHubGameReminders => 'Lembrete diário de jogo';

  @override
  String get settingsHubGameRemindersSubtitle =>
      'Um lembrete na hora do almoço se você não jogou';

  @override
  String get settingsHubFriendActivity => 'Atividade de amigos';

  @override
  String get settingsHubFriendActivitySubtitle =>
      'Destaques, pontos e resultados de amigos';

  @override
  String get settingsHubMenuBar => 'Ícone na barra de menus';

  @override
  String get settingsHubMenuBarSubtitle =>
      'Mostra as não lidas na barra de menus';

  @override
  String get settingsHubCallStats => 'Mostrar estatísticas da chamada';

  @override
  String get settingsHubCallStatsSubtitle =>
      'Resolução, taxa de bits e ping nas chamadas';

  @override
  String get settingsHubTheme => 'Tema';

  @override
  String get settingsHubAppIcon => 'Ícone do app';

  @override
  String get settingsHubGlass => 'Vidro';

  @override
  String get settingsHubNavigation => 'Navegação';

  @override
  String get settingsHubMotion => 'Movimento';

  @override
  String get settingsHubChatList => 'Lista de conversas';

  @override
  String get settingsHubChatStyle => 'Estilo da conversa';

  @override
  String get settingsHubBubbleStyle => 'Estilo dos balões';

  @override
  String get settingsHubSpeakerColors => 'Cores por pessoa';

  @override
  String get settingsHubReplyStyle => 'Estilo das respostas';

  @override
  String get settingsHubPrivacyPolicy => 'Política de privacidade';

  @override
  String get settingsHubTerms => 'Termos de serviço';

  @override
  String get settingsHubLicence => 'Licença';

  @override
  String get settingsHubServer => 'Servidor';

  @override
  String get settingsHubLayoutRows => 'Linhas';

  @override
  String get settingsHubLayoutCards => 'Cartões';

  @override
  String get settingsHubLayoutGrid => 'Grade';

  @override
  String get settingsHubNavTabBar => 'Barra de abas';

  @override
  String settingsHubThemeAuto(String name) {
    return 'Automático · $name';
  }

  @override
  String get chatListPageRowsSub =>
      'Um rosto, um nome e a última mensagem, como no Mensagens.';

  @override
  String get chatListPageCardsSub =>
      'Cada sala no seu próprio cartão, com todos os detalhes.';

  @override
  String get chatListPageGridSub =>
      'Duas colunas de blocos. Mais salas num relance.';

  @override
  String get chatListPageLayoutHeader => 'Layout';

  @override
  String get chatListPageFiltersHeader => 'Filtros';

  @override
  String get chatListPageChips => 'Chips';

  @override
  String get chatListPageChipsSub =>
      'Uma fileira de filtros, sempre a um toque.';

  @override
  String get chatListPageButton => 'Botão';

  @override
  String get chatListPageButtonSub =>
      'Um botão que abre os filtros quando você quiser.';

  @override
  String get chatListPageEmptyHeader => 'Salas vazias';

  @override
  String get chatListPagePlain => 'Simples';

  @override
  String get chatListPagePlainSub => 'Uma sala sem mensagens fica limpa.';

  @override
  String get chatListPageInitial => 'Inicial';

  @override
  String get chatListPageInitialSub =>
      'Uma letra grande e suave preenche o canto vazio.';

  @override
  String get chatListPageEmptyFooter => 'Vale para o layout em grade.';

  @override
  String get chatStylePageFooter =>
      'Como o cabeçalho e o campo de mensagem aparecem.';

  @override
  String get chatStyleClassicSub =>
      'Cabeçalho sólido e campo de mensagem plano.';

  @override
  String get chatStyleCompactSub =>
      'Controles foscos flutuam sobre a conversa.';

  @override
  String get bubbleTailedSub =>
      'Uma cauda na última mensagem de cada sequência, como no Mensagens.';

  @override
  String get bubbleSoftSub => 'Sem cauda. A sequência se une pelos cantos.';

  @override
  String get bubblePillSub =>
      'Cápsulas totalmente arredondadas em cada mensagem.';

  @override
  String get bubbleSlabSub => 'Cantos retos: nítidos e decididos.';

  @override
  String get replyStylePageFooter =>
      'Como uma resposta mostra a mensagem que responde.';

  @override
  String get replyClassicSub =>
      'Uma citação colorida acima da mensagem, estilo WhatsApp.';

  @override
  String get replyPhantomSub =>
      'Um fantasma do original flutua acima, ligado por uma curva.';

  @override
  String get replyStickySub => 'Um cartãozinho inclinado preso no canto.';

  @override
  String get replyComicSub => 'Um mini balão com cauda de quadrinhos.';

  @override
  String get motionMatchDevice => 'Igual ao dispositivo';

  @override
  String get motionMatchDeviceCalmSub =>
      'Seu dispositivo está pedindo menos movimento agora.';

  @override
  String get motionMatchDeviceFullSub =>
      'Seu dispositivo permite animações agora.';

  @override
  String get motionFullSub => 'Cada mola, deriva e floreio.';

  @override
  String get motionCalmSub =>
      'A decoração fica parada. O resto funciona igual.';

  @override
  String get navigationPageFooter =>
      'Como você navega entre Conversas, Feed, Descobrir e Ajustes.';

  @override
  String get navTabBarSub => 'Sempre visível, um toque para qualquer lugar.';

  @override
  String get navOrbSub =>
      'Segure e arraste do canto. Um gesto que se aprende a amar.';

  @override
  String get languageSystemLabel => 'Idioma do dispositivo';

  @override
  String get languagePageFooter =>
      'Menus e mensagens do app. As conversas ficam no idioma em que forem escritas.';

  @override
  String get speakerPageFooter =>
      'Saiba quem está falando num relance nos grupos.';

  @override
  String get speakerOffSub => 'Todos escrevem com a mesma tinta.';

  @override
  String get speakerNamesSub => 'Cada pessoa tem uma cor no nome e na foto.';

  @override
  String get speakerBubblesSub => 'A cor também chega às mensagens.';

  @override
  String get themePageAutoFooter =>
      'Temas claros são usados no modo claro, escuros no modo escuro.';

  @override
  String get themePageLightMode => 'Modo claro';

  @override
  String get themePageDarkMode => 'Modo escuro';

  @override
  String get themePageEssentials => 'Essenciais';

  @override
  String get themePageEssentialsFooter => 'Calmos e nativos, em cinco cores.';

  @override
  String get themePageCharacters => 'Com personalidade';

  @override
  String get themePageCharactersFooter =>
      'O mesmo layout, com personalidade própria. Toque e segure um tema para ver.';

  @override
  String get themePageLightBadge => 'Claro';

  @override
  String get themePageDarkBadge => 'Escuro';

  @override
  String get themePageInUse => 'Em uso';

  @override
  String get themePageUseLight => 'Usar no modo claro';

  @override
  String get themePageUseDark => 'Usar no modo escuro';

  @override
  String themePageUse(String name) {
    return 'Usar $name';
  }

  @override
  String get acctCaptureTitle => 'Proteção contra captura de tela';

  @override
  String get acctCaptureOnIos =>
      'Gravações e espelhamento mostram uma proteção de privacidade.';

  @override
  String get acctCaptureOnAndroid => 'Capturas e gravações ficam pretas.';

  @override
  String get acctCaptureOff => 'Capturas e gravações funcionam normalmente.';

  @override
  String get acctCaptureFooter =>
      'Salas com mensagens temporárias sempre ativam isso.';

  @override
  String get acctActionPending => 'Pendente';

  @override
  String get chatSwipePin => 'Fixar';

  @override
  String get chatSwipeUnpin => 'Desafixar';

  @override
  String get chatSwipeMute => 'Silenciar';

  @override
  String get chatSwipeUnmute => 'Reativar';

  @override
  String get chatSwipeArchive => 'Arquivar';

  @override
  String get appearanceMatchDeviceSubtitle =>
      'Claro de dia e escuro à noite, como seu celular';

  @override
  String get appearanceOneThemeSubtitle => 'O mesmo visual o dia todo';

  @override
  String get riName => 'Nome';

  @override
  String get riDescription => 'Descrição';

  @override
  String get riVisibility => 'Quem pode encontrar';

  @override
  String get riPublic => 'Pública';

  @override
  String get riPublicSub => 'Qualquer pessoa pode encontrar em Descobrir';

  @override
  String get riPrivate => 'Privada';

  @override
  String get riPrivateSub => 'Só quem você convidar pode entrar';

  @override
  String get riMessageLife => 'As mensagens somem após';

  @override
  String get riPassword => 'Senha';

  @override
  String get riRemovePassword => 'Remover senha';

  @override
  String get riSetPassword => 'Definir senha';

  @override
  String get riSharedContent => 'Conteúdo compartilhado';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membros',
      one: '1 membro',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convidados',
      one: '1 convidado',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => 'Retirar';

  @override
  String get riNotifications => 'Notificações';

  @override
  String get riTranslation => 'Tradução';

  @override
  String get riNameColours => 'Cores dos nomes';

  @override
  String get riYouSuggested => 'Você sugeriu';

  @override
  String get riTakeBack => 'Desfazer';

  @override
  String get riLeaveRoom => 'Sair da sala';

  @override
  String get riLeaving => 'Saindo…';

  @override
  String get riDeleteRoom => 'Excluir sala';

  @override
  String get riDeleting => 'Excluindo…';

  @override
  String get riEndConversation => 'Encerrar conversa';

  @override
  String get riEnding => 'Encerrando…';

  @override
  String get riActionCall => 'Ligar';

  @override
  String get riActionVideo => 'Vídeo';

  @override
  String get riActionMute => 'Silenciar';

  @override
  String get riActionUnmute => 'Ativar som';

  @override
  String get riActionMedia => 'Mídia';

  @override
  String get riActionAdd => 'Adicionar';

  @override
  String get roomHeaderStatusTyping => 'Digitando…';

  @override
  String get glassScreenLead => 'Quanto do que está atrás aparece.';

  @override
  String get transcriptDayToday => 'Hoje';

  @override
  String get acctRowDevices => 'Dispositivos';

  @override
  String get acctThisDevice => 'Este dispositivo';

  @override
  String get acctRemove => 'Remover';

  @override
  String get acctRemoveDeviceTitle => 'Remover este dispositivo?';

  @override
  String get acctRemoveAllTitle => 'Remover todos os outros dispositivos?';

  @override
  String get acctRemoveAll => 'Remover todos';

  @override
  String get acctActiveNow => 'Ativo agora';

  @override
  String get acctLoading => 'Carregando…';

  @override
  String get acctDevicesLoadFailed =>
      'Não foi possível carregar seus dispositivos.';

  @override
  String get acctNoNotifications => 'As notificações não chegam a este';

  @override
  String get acctBlockedEmpty => 'Você não bloqueou ninguém.';

  @override
  String get acctUnblock => 'Desbloquear';

  @override
  String get pvSubtitle =>
      'Controle o que os outros veem e como podem falar com você.';

  @override
  String get pvSectionProfile => 'Perfil';

  @override
  String get pvSectionMessages => 'Mensagens';

  @override
  String get pvSectionPeople => 'Pessoas';

  @override
  String get pvSectionFeed => 'Feed';

  @override
  String get pvAvatar => 'Foto do perfil';

  @override
  String get pvAvatarDesc => 'Quem pode ver sua foto';

  @override
  String get pvOnline => 'Status online';

  @override
  String get pvOnlineDesc => 'Se você aparece ativo agora';

  @override
  String get pvLastSeen => 'Visto por último';

  @override
  String get pvLastSeenDesc => 'Quando você esteve por aqui pela última vez';

  @override
  String get pvSendReceipts => 'Enviar confirmações de leitura';

  @override
  String get pvSendReceiptsDesc =>
      'Deixe outras pessoas verem quando você leu as mensagens delas';

  @override
  String get pvShowReceipts => 'Mostrar confirmações de leitura';

  @override
  String get pvShowReceiptsDesc => 'Ver quem leu suas mensagens';

  @override
  String get pvShowReceiptsHint =>
      'Só contam as pessoas que enviam confirmações de leitura.';

  @override
  String get pvFriendRequests => 'Pedidos de amizade';

  @override
  String get pvFriendRequestsDesc => 'Quem pode enviar pedidos de amizade';

  @override
  String get pvSupervisedTitle => 'Seus responsáveis definem isto';

  @override
  String get pvEveryone => 'Todos';

  @override
  String get pvFriends => 'Amigos';

  @override
  String get pvNobody => 'Ninguém';

  @override
  String get pvOn => 'Ativado';

  @override
  String get pvOff => 'Desativado';

  @override
  String get pvAnyone => 'Qualquer pessoa';

  @override
  String get pvHighlights => 'Meus destaques';

  @override
  String get pvHighlightsDesc =>
      'Se suas fotos e vídeos aparecem nos murais dos amigos no dia';

  @override
  String get pvPuzzle => 'Minha pontuação no quebra-cabeça';

  @override
  String get pvPuzzleDesc =>
      'Se os amigos veem como você foi no quebra-cabeça do dia';

  @override
  String get pvPast => 'Meu histórico';

  @override
  String get pvPastDesc =>
      'Hoje é sempre compartilhado com amigos. Isto libera todo o resto';

  @override
  String get pvPoints => 'Meus pontos';

  @override
  String get pvPointsDesc =>
      'Se os pontos que você registra aparecem nos murais dos amigos';

  @override
  String get roomColorsPageTitle => 'Quem é quem';

  @override
  String get roomColorsPageHeader => 'A cor em que cada pessoa fala';

  @override
  String get roomColorsAuto => 'Automático';

  @override
  String get roomColorsReset => 'Voltar ao automático';

  @override
  String get roomColorsOffFooter =>
      'As cores por pessoa estão desativadas. Ativar aqui ativa em todas as salas.';

  @override
  String roomColorsSharedWith(String name) {
    return 'Compartilhada com $name';
  }

  @override
  String get settingsScreenValueReplyQuote => 'Citação';

  @override
  String get replyQuoteSub =>
      'A mensagem original aparece no topo da resposta, dentro do balão.';

  @override
  String get riTabMedia => 'Fotos e vídeos';

  @override
  String get riTabFiles => 'Arquivos';

  @override
  String get riTabVoice => 'Mensagens de voz';

  @override
  String get riTabLinks => 'Links';

  @override
  String get riTabSaved => 'Salvos';

  @override
  String get riNone => 'Nenhum';

  @override
  String get riSavedNote =>
      'Só você vê o que salva. Uma mensagem fixada é o contrário: a sala toda vê.';

  @override
  String get riOwnerNote => 'A medalha marca quem criou esta sala.';

  @override
  String get famPair => 'Parear';

  @override
  String get famRelease => 'Liberar';

  @override
  String get famSettings => 'Ajustes';

  @override
  String get famAddChild => 'Adicionar criança';

  @override
  String get famEmptyTitle => 'Nenhuma criança ainda';

  @override
  String get famOnlineNow => 'Online agora';

  @override
  String get famNotPaired => 'Ainda não pareado';

  @override
  String get famJustNow => 'Agora mesmo';

  @override
  String get apprEmptyTitle => 'Nada pendente';

  @override
  String get apprEmptySub => 'Tudo em dia.';

  @override
  String get apprNotYet => 'Ainda não';

  @override
  String get apprAllow => 'Permitir';

  @override
  String get compGeneral => 'Geral';

  @override
  String get compStorage => 'Armazenamento';

  @override
  String get compTranslateInto => 'Traduzir para';

  @override
  String get compBrain => 'Cérebro';

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
  String get laNotLinked => 'Não vinculada';

  @override
  String rdSignOut(String name) {
    return 'Desconectar $name';
  }

  @override
  String get rpContinue => 'Continuar';

  @override
  String get rpCopy => 'Copiar';

  @override
  String get rpSaved => 'Já salvei';

  @override
  String get rpBack => 'Voltar';

  @override
  String get rpKeep => 'Agora não, manter minha frase atual';

  @override
  String get childSetupHeadingIos => 'Quem é?';

  @override
  String get childPairTitleIos => 'Oi!';

  @override
  String get childPairBackIos => 'Voltar para entrar';

  @override
  String get gamesHubTitle => 'Ranking';

  @override
  String get gamesHubSubtitle =>
      'Os vencedores de hoje. Desafios novos todo dia.';

  @override
  String get gameTellFriendsMessage =>
      'Eles vão receber uma notificação com este resultado. Só dá para enviar uma vez.';

  @override
  String get deviceLoginScanTitleIos => 'Escaneie para entrar';

  @override
  String get deviceLoginConfirmTitleIos => 'Entrar neste dispositivo?';

  @override
  String get socialHeroCreateIos => 'Quase lá';

  @override
  String get socialHeroLinkIos => 'Que bom te ver de volta';

  @override
  String socialSignInLinkIos(String provider) {
    return 'Entrar e vincular $provider';
  }

  @override
  String get serverTitleIos => 'Servidor';

  @override
  String get serverOnboardingTitleIos => 'Escolha um servidor';

  @override
  String get approvalGateAskIos => 'Pedir';

  @override
  String get friendRequestDraftIntroOutgoingSentence =>
      'Manda algumas linhas. A pessoa pode aceitar ou recusar.';

  @override
  String get requestDeclineIos => 'Recusar';

  @override
  String get joinRequestAllowIos => 'Permitir';

  @override
  String get changeRequestUseIos => 'Usar';

  @override
  String get settingsSearchHint => 'Buscar nos ajustes';

  @override
  String settingsSearchNoResults(String query) {
    return 'Nenhum resultado para “$query”';
  }

  @override
  String get settingsSearchAccount => 'Conta';

  @override
  String get settingsHubDiagnostics => 'Diagnóstico';

  @override
  String get settingsHubDiagnosticsSubtitle =>
      'Registros para resolver problemas e relatar erros';

  @override
  String get settingsHubAdvancedFooter =>
      'Para resolver problemas e hospedar seu próprio servidor. Nada aqui é necessário no dia a dia.';

  @override
  String get settingsSearchKwLanguage => 'idioma, língua, região';

  @override
  String get settingsSearchKwUpdates => 'atualização, versão, nova';

  @override
  String get settingsSearchKwLinks => 'links, url, endereço, prévia';

  @override
  String get settingsSearchKwPresence =>
      'online, presença, status, bolinha, ativo, verde';

  @override
  String get settingsSearchKwAutoplay => 'gif, animação, reprodução automática';

  @override
  String get settingsSearchKwStickers => 'figurinhas, emoji, sugestões';

  @override
  String get settingsSearchKwPush => 'notificações, alertas, som';

  @override
  String get settingsSearchKwGames => 'jogos, lembrete, diário';

  @override
  String get settingsSearchKwFriends => 'amigos, atividade, pontos';

  @override
  String get settingsSearchKwVideo => 'vídeo, chamada, qualidade, câmera';

  @override
  String get settingsSearchKwStats => 'estatísticas, rede, ping, depuração';

  @override
  String get settingsSearchKwTheme => 'tema, escuro, claro, cores, noite';

  @override
  String get settingsSearchKwIcon => 'ícone, logo, tela inicial';

  @override
  String get settingsSearchKwGlass => 'vidro, desfoque, fosco, transparência';

  @override
  String get settingsSearchKwNavigation => 'barra de abas, navegação, menu';

  @override
  String get settingsSearchKwMotion => 'movimento, animação, reduzir movimento';

  @override
  String get settingsSearchKwCompanions => 'ia, assistente, traduzir, modelo';

  @override
  String get settingsSearchKwChatList =>
      'lista de conversas, linhas, cartões, grade';

  @override
  String get settingsSearchKwChatStyle => 'estilo, compacto, clássico';

  @override
  String get settingsSearchKwBubbles => 'balões, mensagens, formato';

  @override
  String get settingsSearchKwSpeakers => 'nomes, cores, grupos';

  @override
  String get settingsSearchKwReply => 'responder, citação, conversa';

  @override
  String get settingsSearchKwReport => 'bug, problema, feedback, ajuda';

  @override
  String get settingsSearchKwLegal => 'privacidade, termos, legal, licença';

  @override
  String get settingsSearchKwServer =>
      'servidor, auto-hospedado, url, desenvolvedor';

  @override
  String get settingsSearchKwDiagnostics =>
      'diagnóstico, registros, depuração, desenvolvedor';

  @override
  String get settingsSearchKwPrivacy =>
      'privacidade, visibilidade, visto por último';

  @override
  String get settingsSearchKwBlocked => 'bloqueados, bloquear';

  @override
  String get settingsSearchKwDevices => 'dispositivos, sessões, sair';

  @override
  String get settingsSearchKwLinked => 'apple, google, entrar';

  @override
  String get settingsSearchKwRecovery => 'frase de recuperação, senha, backup';

  @override
  String get settingsSearchKwCapture =>
      'captura de tela, gravação, privacidade';

  @override
  String get settingsSearchKwFamily => 'família, criança, pais, aprovações';

  @override
  String get settingsSearchKwAccount => 'conta, sair, excluir, e-mail';

  @override
  String get childPolicyScreenContactStateAllowedTalking => 'Conversando';

  @override
  String get childPolicyScreenContactStateTalking => 'Aprovado';

  @override
  String get childPolicyScreenContactStateAllowedNotAdded =>
      'Ainda não adicionado';

  @override
  String get profileScreenSignOutConfirmTitle => 'Sair neste dispositivo?';

  @override
  String get profileScreenDeleteAccountConfirmTitle => 'Excluir sua conta?';

  @override
  String get profileScreenDeleteAccountConfirmBody =>
      'Suas mensagens, fotos, salas e amigos são apagados, e seu nome de usuário fica livre para outra pessoa.';

  @override
  String get glassPresetNameFrosted => 'Fosco';

  @override
  String get glassPresetNameClear => 'Transparente';

  @override
  String settingsScreenDiagnosticsCountdown(int count) {
    return 'Diagnóstico em $count…';
  }

  @override
  String pairingCodeTitlePair(String name) {
    return 'Parear $name';
  }

  @override
  String pairingCodeTitleRelease(String name) {
    return 'Liberar $name';
  }

  @override
  String archivedChatsSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count conversas',
      one: '$count conversa',
    );
    return '$_temp0';
  }

  @override
  String pinnedListSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens',
      one: '$count mensagem',
    );
    return '$_temp0';
  }

  @override
  String get voiceRecorderScreenTitle => 'Mensagem de voz';

  @override
  String get chatTargetSearchHint => 'Buscar';

  @override
  String get marloweBrainTierSwiftDetail =>
      'Respostas rápidas, o download mais leve';

  @override
  String get marloweBrainTierBalancedDetail =>
      'Um bom equilíbrio entre rapidez e profundidade';

  @override
  String get marloweBrainTierDeepDetail =>
      'O mais ponderado, precisa de mais espaço';

  @override
  String get reportFactDeviceId => 'ID do dispositivo';

  @override
  String get reportFactUserId => 'ID de usuário';

  @override
  String get reportFactUsername => 'Nome de usuário';

  @override
  String get reportFactApp => 'App';

  @override
  String get reportFactDevice => 'Dispositivo';

  @override
  String get reportFactSystem => 'Sistema';

  @override
  String get reportFactDisplay => 'Tela';

  @override
  String get reportFactAppLanguage => 'Idioma do app';

  @override
  String get reportFactSystemLocale => 'Região do sistema';

  @override
  String get reportFactLog => 'Registro';

  @override
  String reportFactLogValue(int count) {
    return '$count eventos anexados';
  }

  @override
  String reportProblemScreenshotN(int n) {
    return 'Captura de tela $n';
  }

  @override
  String reportProblemRemoveScreenshot(int n) {
    return 'Remover captura de tela $n';
  }

  @override
  String get reportFactLanguageFromSystem => 'do sistema';

  @override
  String get reportFactLanguageChosen => 'escolhido';

  @override
  String get pageSectionSeeAll => 'Ver tudo';

  @override
  String get discoverScreenSeeAllFriendsSemanticLabel => 'Ver todos os amigos';

  @override
  String get discoverScreenSeeAllRoomsSemanticLabel =>
      'Ver todas as suas salas';

  @override
  String groupCallScreenRingingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chamando',
    );
    return '$_temp0';
  }

  @override
  String photoChromeWhenToday(String time) {
    return 'Hoje às $time';
  }

  @override
  String photoChromeWhenYesterday(String time) {
    return 'Ontem às $time';
  }

  @override
  String photoChromeWhenDate(String date, String time) {
    return '$date às $time';
  }

  @override
  String get photoChromeSaved => 'Salvo';

  @override
  String get photoChromeSaveFailed => 'Não foi possível salvar';

  @override
  String get photoChromeShareFailed => 'Não foi possível compartilhar';

  @override
  String photoChromeForwarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encaminhado para $count conversas',
      one: 'Encaminhado',
    );
    return '$_temp0';
  }

  @override
  String get photoChromeForwardFailed => 'Não foi possível encaminhar';

  @override
  String get photoChromeDeleteFailed => 'Não foi possível excluir';

  @override
  String get photoChromeDeleteBody =>
      'Isso remove para todo mundo neste chat. Não dá pra desfazer.';

  @override
  String get roomContentMonthThis => 'Este mês';

  @override
  String get roomContentMonthLast => 'Mês passado';

  @override
  String get leaderboardOverall => 'Hoje';

  @override
  String get leaderboardFooter =>
      '1 ponto por desafio resolvido hoje. Se empatar, fica na frente quem ficou mais vezes em primeiro. Ainda empatados? Vocês dividem a posição, em ordem alfabética.';

  @override
  String get leaderboardNotPlayed => 'Você ainda não jogou';

  @override
  String get leaderboardPlay => 'Jogar';

  @override
  String get leaderboardEmptyTitle => 'Nenhuma pontuação hoje ainda';

  @override
  String get leaderboardEmptyBody =>
      'Resolva um desafio e seja o primeiro da lista.';

  @override
  String get pointComposerPickFirst => 'Escolha um acima primeiro';

  @override
  String get momentStoryNext => 'Próximo';

  @override
  String get momentStoryPrevious => 'Anterior';

  @override
  String leaderboardSolved(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      solved,
      locale: localeName,
      other: '$solved de $total resolvidos',
      one: '1 de $total resolvido',
      zero: 'Nada resolvido ainda',
    );
    return '$_temp0';
  }

  @override
  String leaderboardWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vitórias',
      one: '1 vitória',
    );
    return '$_temp0';
  }

  @override
  String leaderboardEmptyAction(String game) {
    return 'Jogar: $game';
  }

  @override
  String get diagCatApi => 'Chamadas ao servidor';

  @override
  String get diagCatConnection => 'Conexão';

  @override
  String get diagCatDevice => 'Dispositivo';

  @override
  String get diagCatError => 'Erros';

  @override
  String get diagCatFrame => 'Quadros lentos';

  @override
  String get diagCatLayout => 'Layout';

  @override
  String get diagCatLifecycle => 'Estado do app';

  @override
  String get diagCatLog => 'Log';

  @override
  String get diagCatNav => 'Navegação';

  @override
  String get diagCatNetwork => 'Rede';

  @override
  String get diagCatSubscription => 'Atualizações ao vivo';

  @override
  String get diagSevTrace => 'Rastreamento';

  @override
  String get diagSevDebug => 'Depuração';

  @override
  String get diagSevInfo => 'Info';

  @override
  String get diagSevWarning => 'Aviso';

  @override
  String get diagSevError => 'Erro';

  @override
  String get diagAll => 'Tudo';

  @override
  String get diagSearchHint => 'Buscar nome, detalhe, conteúdo';

  @override
  String get diagSummaryCopied => 'Resumo copiado';

  @override
  String get diagShareLog => 'Compartilhar log';

  @override
  String get diagCopySummary => 'Copiar resumo';

  @override
  String get diagDeleteAll => 'Apagar tudo';

  @override
  String get diagUndo => 'Desfazer';

  @override
  String get diagDeleteLogTitle => 'Apagar o log inteiro?';

  @override
  String get diagDeleteLogBody =>
      'Todos os eventos registrados até agora são apagados, junto com o log da sessão anterior. O que acontecer daqui pra frente é registrado normalmente.';

  @override
  String get diagDelete => 'Apagar';

  @override
  String get diagLogDeleted => 'Log apagado';

  @override
  String get diagFilter => 'Filtrar';

  @override
  String get diagMore => 'Mais';

  @override
  String get diagLatest => 'Mais recentes';

  @override
  String get diagJumpToLatest => 'Ir para o mais recente';

  @override
  String get diagPaused => 'pausado';

  @override
  String get diagPreparingLog => 'preparando log…';

  @override
  String get diagEmptyNothingTitle => 'Nada registrado ainda';

  @override
  String get diagEmptyNothingHint =>
      'Use o app por um instante e os eventos aparecem aqui.';

  @override
  String get diagEmptyHiddenTitle => 'Por enquanto, só eventos ocultos';

  @override
  String get diagEmptyHiddenHint =>
      'Toque num chip apagado acima para ver, ou segure para trazê-lo de volta para Tudo.';

  @override
  String get diagEmptyNoMatchTitle => 'Nenhum evento corresponde';

  @override
  String get diagEmptyNoMatchHint =>
      'Toque em Tudo acima para limpar o filtro.';

  @override
  String get diagApply => 'Aplicar';

  @override
  String get diagMinSeverity => 'Gravidade mínima';

  @override
  String get diagEverything => 'Tudo';

  @override
  String get diagHiddenFromAllHeader => 'Ocultos em Tudo';

  @override
  String get diagHiddenFromAllFooter =>
      'Ficam fora de Tudo até serem escolhidos na fileira de chips. Segure um chip lá para o mesmo ajuste.';

  @override
  String get diagCollapseRepeats => 'Agrupar repetições';

  @override
  String get diagCollapseRepeatsSubtitle =>
      'Junta uma sequência do mesmo evento em uma linha';

  @override
  String get diagResetFilter => 'Redefinir filtro';

  @override
  String get diagBodyTruncated => 'Conteúdo cortado no registro';

  @override
  String get diagCopyEvent => 'Copiar evento';

  @override
  String get diagEventCopied => 'Evento copiado';

  @override
  String diagHiddenFromAll(String category) {
    return '$category oculto em Tudo';
  }

  @override
  String diagBackInAll(String category) {
    return '$category de volta em Tudo';
  }

  @override
  String diagChipSemanticLabel(String category, int count) {
    return '$category, $count';
  }

  @override
  String diagChipHiddenSemanticLabel(String category, int count) {
    return '$category, $count, oculto em Tudo';
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
          '$count eventos anteriores descartados, o log começa no meio da história',
      one:
          '$count evento anterior descartado, o log começa no meio da história',
    );
    return '$_temp0';
  }

  @override
  String diagRepeatSpan(int count, String seconds) {
    return '×$count em ${seconds}s';
  }

  @override
  String roomContentTabSemantic(String count, String label) {
    return '$label, $count itens';
  }

  @override
  String get mapAppsTitle => 'Mapas';

  @override
  String get mapAppsChoose => 'Abrir localização em';

  @override
  String get mapAppsRemember => 'Usar como padrão';

  @override
  String get mapAppsAskEveryTime => 'Perguntar sempre';

  @override
  String get mapAppsBrowser => 'Navegador';

  @override
  String get mapAppsSubtitle =>
      'Escolha onde abrir as localizações compartilhadas.';

  @override
  String get mapAppsUnavailable =>
      'Seu app de mapas padrão não está disponível. Escolha outro.';

  @override
  String get mapAppsNoInstalled =>
      'Nenhum app de mapas compatível encontrado. Você pode usar o navegador.';

  @override
  String get interactionAnswersSearch => 'Buscar pessoas ou respostas';

  @override
  String get interactionFilterEmpty =>
      'Nenhuma resposta corresponde a este filtro.';

  @override
  String get interactionRetry => 'Tentar novamente';

  @override
  String get cameraEditorScreenCaptionHint => 'Adicionar legenda…';

  @override
  String get cameraEditorScreenCaptionViewOnceHint =>
      'Sem legenda em fotos de visualização única';

  @override
  String get cameraEditorScreenAddFromCameraSemanticLabel => 'Tirar outra foto';

  @override
  String cameraEditorScreenDiscardAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Descartar $count fotos?',
      one: 'Descartar esta foto?',
    );
    return '$_temp0';
  }

  @override
  String get cameraEditorScreenDiscardAllBody =>
      'Suas edições e legendas serão perdidas.';

  @override
  String get cameraEditorScreenDiscardAllConfirm => 'Descartar';

  @override
  String get galleryTrayRecentsTitle => 'Recentes';

  @override
  String get galleryTrayBackToCameraLabel => 'Voltar para a câmera';

  @override
  String get galleryTrayAllPhotosLabel => 'Todas as fotos';

  @override
  String get galleryTrayHandleLabel => 'Fotos recentes';

  @override
  String get galleryTrayAllowPrompt => 'Veja suas fotos recentes aqui';

  @override
  String get galleryTrayAllowButton => 'Permitir';

  @override
  String get galleryTrayDeniedPrompt => 'O acesso às fotos está desativado';

  @override
  String get galleryTraySettingsButton => 'Ajustes';

  @override
  String get galleryTrayLimitedNote =>
      'Mostrando só as fotos que você permitiu';

  @override
  String get galleryTrayManageButton => 'Gerenciar';

  @override
  String get galleryTrayEmpty => 'Nenhuma foto ainda';

  @override
  String galleryTrayAddSelectedButton(int count) {
    return 'Adicionar ($count)';
  }

  @override
  String get galleryTrayCancelSelectionLabel => 'Cancelar seleção';

  @override
  String galleryTraySelectedTitle(int count) {
    return '$count selecionadas';
  }

  @override
  String galleryTrayPhotoLabel(int index) {
    return 'Foto $index';
  }

  @override
  String get reactionLimitTitle => 'Você atingiu o limite de reações';

  @override
  String reactionLimitMessageBody(int limit) {
    return 'Pela velocidade, pela sanidade e para deixar cada emoji brilhar, você pode adicionar até $limit reações a uma mensagem, nem uma a mais. Tire uma para abrir espaço para outra.';
  }

  @override
  String reactionLimitHighlightBody(int limit) {
    return 'Nos destaques, cada pessoa tem $limit reações, para que cada uma ainda diga algo. Tire uma para abrir espaço para uma nova favorita.';
  }

  @override
  String get reactionLimitDismiss => 'Entendi';

  @override
  String get reactionPickerYoursLabel => 'Suas reações';

  @override
  String reactionPickerTakeBackSemantic(String emoji) {
    return 'Remover sua reação $emoji';
  }

  @override
  String get momentCommentsTitle => 'Comentários';

  @override
  String momentCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comentários',
      one: '1 comentário',
      zero: 'Comentar',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentsEmptyTitle => 'Nenhum comentário ainda';

  @override
  String get momentCommentsEmptyBody =>
      'Comece a conversa com palavras, uma figurinha ou um GIF.';

  @override
  String get momentCommentHint => 'Adicione um comentário…';

  @override
  String momentCommentReplyHint(String name) {
    return 'Responder a $name…';
  }

  @override
  String momentCommentReplyingTo(String name) {
    return 'Respondendo a $name';
  }

  @override
  String get momentCommentCancelReply => 'Cancelar resposta';

  @override
  String get momentCommentReply => 'Responder';

  @override
  String momentCommentViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ver $count respostas',
      one: 'Ver 1 resposta',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentHideReplies => 'Ocultar respostas';

  @override
  String get momentCommentDelete => 'Excluir comentário';

  @override
  String get momentCommentDeleteConfirm =>
      'Excluir este comentário? As respostas também vão.';

  @override
  String get momentCommentDeleteConfirmButton => 'Excluir';

  @override
  String get momentCommentSend => 'Enviar';

  @override
  String get momentCommentExpressions => 'Figurinhas e GIFs';

  @override
  String get momentCommentFailed =>
      'Não foi possível publicar seu comentário. Tente de novo.';

  @override
  String get momentCommentAuthorBadge => 'Autor';

  @override
  String get momentCommentLike => 'Curtir';

  @override
  String get momentCommentStickerAlt => 'Figurinha';

  @override
  String get momentCommentGifAlt => 'GIF';

  @override
  String get momentCommentPosted => 'Comentário publicado';

  @override
  String momentCommentsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ver todos os $count comentários',
      one: 'Ver 1 comentário',
    );
    return '$_temp0';
  }

  @override
  String momentReactorsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count pessoas',
      one: 'mais 1 pessoa',
    );
    return '$name e $_temp0';
  }

  @override
  String get storageKindPhotos => 'Fotos';

  @override
  String get storageKindVideos => 'Vídeos';

  @override
  String get storageKindVideoMessages => 'Notas de vídeo';

  @override
  String get storageKindVoice => 'Mensagens de voz';

  @override
  String get storageKindFiles => 'Arquivos';

  @override
  String get storageKindStickers => 'Figurinhas e GIFs';

  @override
  String get storageKindChatHistory => 'Histórico de conversas';

  @override
  String get storageKindOther => 'Outros';

  @override
  String get dataUsageKindCalls => 'Chamadas';

  @override
  String get dataStorageTitle => 'Dados e Armazenamento';

  @override
  String get settingsSearchKwDataStorage =>
      'armazenamento cache memória espaço limpar baixar download automático dados uso de dados celular móvel wifi salvar fotos galeria storage';

  @override
  String get storageUsageTitle => 'Uso do Armazenamento';

  @override
  String get dataUsageTitle => 'Uso de Dados';

  @override
  String get dataStorageAutoDownloadHeader => 'Download automático de mídia';

  @override
  String get dataStorageUsingCellular => 'Usando Celular';

  @override
  String get dataStorageUsingWifi => 'Usando Wi-Fi';

  @override
  String get dataStorageNowTag => 'Agora';

  @override
  String get autoDownloadReset => 'Redefinir download automático';

  @override
  String get autoDownloadResetTitle =>
      'Restaurar as configurações padrão de download automático?';

  @override
  String get dataStorageSaveHeader => 'Salvar em Fotos';

  @override
  String get dataStorageSaveFooter =>
      'Salva automaticamente as novas fotos e vídeos dessas conversas na sua biblioteca de fotos.';

  @override
  String get dataStorageCallsHeader => 'Chamadas';

  @override
  String get dataStorageLessDataForCalls => 'Usar menos dados em chamadas';

  @override
  String get dataStorageCallsFooter =>
      'Usa menos dados em redes fracas ou limitadas, com qualidade de áudio e vídeo um pouco menor.';

  @override
  String get dataStorageCallsNever => 'Nunca';

  @override
  String get dataStorageCallsCellular => 'No celular';

  @override
  String get dataStorageCallsAlways => 'Sempre';

  @override
  String get dataStorageOff => 'Desligado';

  @override
  String get dataStorageChatsPrivate => 'Conversas privadas';

  @override
  String get dataStorageChatsGroups => 'Grupos';

  @override
  String get dataStorageChatsPublic => 'Salas públicas';

  @override
  String get dataStorageNetCellular => 'Celular';

  @override
  String get dataStorageNetWifi => 'Wi-Fi';

  @override
  String get autoDownloadMaster => 'Baixar mídia automaticamente';

  @override
  String get autoDownloadUsageHeader => 'Uso de dados';

  @override
  String get autoDownloadPresetLow => 'Baixo';

  @override
  String get autoDownloadPresetMedium => 'Médio';

  @override
  String get autoDownloadPresetHigh => 'Alto';

  @override
  String get autoDownloadCustomFooter =>
      'Você personalizou essas configurações. Mova o controle para voltar a uma predefinição.';

  @override
  String get autoDownloadTypesHeader => 'Tipos de mídia';

  @override
  String get autoDownloadVideosTitle => 'Vídeos e notas de vídeo';

  @override
  String get autoDownloadVoiceFooter =>
      'Mensagens de voz e figurinhas são bem leves, então sempre são baixadas automaticamente.';

  @override
  String get autoDownloadAllChats => 'Todas as conversas';

  @override
  String autoDownloadUpToIn(String size, String chats) {
    return 'Até $size em $chats';
  }

  @override
  String autoDownloadSummaryUpTo(String kind, String size) {
    return '$kind até $size';
  }

  @override
  String get autoDownloadSummaryVoiceOnly => 'Só mensagens de voz';

  @override
  String get autoDownloadInHeader => 'Baixar automaticamente em';

  @override
  String get autoDownloadMaxSizeHeader => 'Tamanho máximo do arquivo';

  @override
  String autoDownloadMaxSizeVideoFooter(String size) {
    return 'Vídeos de até $size são baixados automaticamente. Os maiores esperam um toque.';
  }

  @override
  String autoDownloadMaxSizeFileFooter(String size) {
    return 'Arquivos de até $size são baixados automaticamente. Os maiores esperam um toque.';
  }

  @override
  String get autoDownloadGateLoad => 'Baixar foto';

  @override
  String get saveToPhotosHeader => 'Salvar automaticamente';

  @override
  String get saveToPhotosFooter =>
      'Novas fotos e vídeos que você recebe nessas conversas são adicionados à sua biblioteca de fotos ao serem baixados.';

  @override
  String get saveToPhotosMaxVideoHeader => 'Tamanho máximo do vídeo';

  @override
  String get saveToPhotosNoAccess =>
      'Permita o acesso à biblioteca de fotos nos Ajustes para salvar automaticamente.';

  @override
  String get saveToPhotosPhotosAndVideos => 'Fotos e vídeos';

  @override
  String get storageCalculating => 'Calculando…';

  @override
  String storageShareOfFree(String percent) {
    return 'O MonkeyHub usa $percent do seu espaço livre.';
  }

  @override
  String get storageEmpty => 'Nada em cache no momento.';

  @override
  String storageClearAllButton(String size) {
    return 'Limpar todo o cache $size';
  }

  @override
  String storageClearSelectedButton(String size) {
    return 'Limpar selecionados $size';
  }

  @override
  String storageClearChatButton(String size) {
    return 'Limpar cache $size';
  }

  @override
  String get storageClearFooter =>
      'Tudo continua na nuvem e é baixado de novo quando você precisar.';

  @override
  String get storageClearAllTitle => 'Limpar todo o cache?';

  @override
  String get storageClearSelectedTitle => 'Limpar os itens selecionados?';

  @override
  String get storageClearBody =>
      'Suas mensagens ficam. A mídia é baixada de novo quando você abrir.';

  @override
  String storageClearConfirm(String size) {
    return 'Limpar $size';
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
  String get storageCleanupSubtitle => 'Mídia que você não abre há um mês';

  @override
  String get storageCleanupAction => 'Limpar';

  @override
  String get storageCleanupFooter =>
      'Só limpa mídia que ninguém viu em 30 dias. As Mensagens salvas nunca são afetadas.';

  @override
  String get storageAutoRemoveHeader =>
      'Remover mídia em cache automaticamente';

  @override
  String get storageAutoRemoveFooter =>
      'Mídia que você não abre há esse tempo é removida deste aparelho para liberar espaço. Ela continua na nuvem, e as Mensagens salvas são sempre mantidas.';

  @override
  String get dataStorageKeepNever => 'Nunca';

  @override
  String get dataStorageKeepMonth => '1 mês';

  @override
  String get dataStorageKeepWeek => '1 semana';

  @override
  String get dataStorageKeepDay => '1 dia';

  @override
  String get storageLimitHeader => 'Tamanho máximo do cache';

  @override
  String get storageLimitFooter =>
      'Se o cache passar desse tamanho, a mídia aberta há mais tempo é removida primeiro.';

  @override
  String get dataStorageLimitNone => 'Sem limite';

  @override
  String get storageTabChats => 'Conversas';

  @override
  String get storageTabMedia => 'Mídia';

  @override
  String get storageTabFiles => 'Arquivos';

  @override
  String get storageNoChats => 'Nenhuma conversa tem nada em cache ainda.';

  @override
  String get storageNoMedia => 'Ainda não há fotos nem vídeos em cache.';

  @override
  String get storageNoFiles => 'Ainda não há arquivos em cache.';

  @override
  String get storageOpenPhoto => 'Abrir foto';

  @override
  String get storageOpenVideo => 'Abrir vídeo';

  @override
  String get storageSelect => 'Selecionar';

  @override
  String storageChatShare(String percent) {
    return 'Esta conversa usa $percent do seu cache.';
  }

  @override
  String get storageChatUnknown => 'Conversa da qual você saiu';

  @override
  String dataUsageSince(String date) {
    return 'Desde $date';
  }

  @override
  String get dataUsageAll => 'Todas';

  @override
  String get dataUsageNothingYet => 'Nada foi contado nesta rede ainda.';

  @override
  String get dataUsageTapHint =>
      'Toque em uma categoria para ver o que foi enviado e recebido.';

  @override
  String get dataUsageSent => 'Enviado';

  @override
  String get dataUsageReceived => 'Recebido';

  @override
  String get dataUsageTotalHeader => 'Uso total da rede';

  @override
  String get dataUsageFootnote =>
      'Conta mídia e chamadas. As mensagens em si são minúsculas e não entram na conta.';

  @override
  String get dataUsageReset => 'Redefinir estatísticas';

  @override
  String get dataUsageResetTitle =>
      'Redefinir as estatísticas de uso de dados?';

  @override
  String get dataUsageResetBody => 'A contagem recomeça a partir de agora.';

  @override
  String get storageKindCompanions => 'Companheiros';

  @override
  String get storageCompanionsNote =>
      'Os companheiros não são apagados com o cache. Toque neles para gerenciar os downloads.';

  @override
  String storageCategoryCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens, $size',
      one: '1 item, $size',
    );
    return '$_temp0';
  }

  @override
  String get storageSelectAll => 'Selecionar tudo';

  @override
  String get storageDeselectAll => 'Desmarcar tudo';

  @override
  String get storageCategoryEmpty => 'Nada desse tipo está em cache agora.';

  @override
  String get storageChatHistoryFooter =>
      'Só a cópia neste aparelho é removida. As mensagens continuam no chat e carregam de novo na próxima vez que você abrir.';

  @override
  String get storageCategoryHint =>
      'Toque numa categoria para ver o que tem dentro, ou no círculo para deixá-la de fora.';

  @override
  String storageChatRemovedNamed(String names) {
    return '$names · conversa removida';
  }

  @override
  String get streaksLabel => 'Sequências';

  @override
  String get streakAtRiskFooter => 'Jogue hoje para manter sua sequência.';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sequência de $count dias',
      one: 'Sequência de 1 dia',
    );
    return '$_temp0';
  }

  @override
  String recordsCheersMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'e mais $count',
      one: 'e mais 1',
    );
    return '$_temp0';
  }

  @override
  String get recordsCheer => 'Aplaudir';

  @override
  String get myStreaksLabel => 'Minhas sequências';

  @override
  String streakLongest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return 'Sua mais longa: $_temp0';
  }

  @override
  String get streaksEmpty => 'Ninguém tem uma sequência aqui ainda.';

  @override
  String videoTooLargeSnack(String size) {
    return 'Vídeos têm limite de $size';
  }

  @override
  String videoShrinkPromptTitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos passam de $size',
      one: 'Este vídeo passa de $size',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkPromptBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Eles vão ser comprimidos pra caber, então a qualidade vai cair bastante.',
      one:
          'Ele vai ser comprimido pra caber, então a qualidade vai cair bastante.',
    );
    return '$_temp0';
  }

  @override
  String get videoShrinkPromptAction => 'Comprimir e enviar';

  @override
  String get videoShrinkWorkingSnack => 'Comprimindo vídeo…';

  @override
  String videoShrinkFailedSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count vídeos são longos demais pra caber em $size, mesmo comprimidos',
      one: 'Longo demais pra caber em $size, mesmo comprimido',
    );
    return '$_temp0';
  }

  @override
  String photoHdOverCapSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fotos passavam de $size e foram em qualidade padrão',
      one: '1 foto passava de $size e foi em qualidade padrão',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkSendSmallOnly(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Enviar só os $count abaixo de $size',
      one: 'Enviar só o que fica abaixo de $size',
    );
    return '$_temp0';
  }

  @override
  String get kbdGroupGeneral => 'Geral';

  @override
  String get kbdGroupNavigation => 'Navegação';

  @override
  String get kbdGroupChat => 'Em uma conversa';

  @override
  String get kbdGroupComposer => 'Escrita';

  @override
  String get kbdGroupViewer => 'Fotos e vídeos';

  @override
  String get kbdGroupCall => 'Chamadas';

  @override
  String get kbdCommandPalette => 'Buscar conversas e comandos';

  @override
  String get kbdShowShortcuts => 'Atalhos de teclado';

  @override
  String get kbdSearch => 'Buscar';

  @override
  String get kbdNewChat => 'Nova conversa';

  @override
  String get kbdSettings => 'Configurações';

  @override
  String get kbdBack => 'Voltar ou fechar';

  @override
  String kbdGoTo(String section) {
    return 'Ir para $section';
  }

  @override
  String get kbdNextChat => 'Próxima conversa';

  @override
  String get kbdPreviousChat => 'Conversa anterior';

  @override
  String get kbdNextUnread => 'Próxima conversa não lida';

  @override
  String get kbdCloseChat => 'Fechar conversa';

  @override
  String get kbdRoomInfo => 'Informações da conversa';

  @override
  String get kbdSearchInChat => 'Buscar nesta conversa';

  @override
  String get kbdJumpToLatest => 'Ir para a última mensagem';

  @override
  String get kbdAttach => 'Anexar arquivos';

  @override
  String get kbdVoiceCall => 'Chamada de voz';

  @override
  String get kbdVideoCall => 'Chamada de vídeo';

  @override
  String get kbdSend => 'Enviar';

  @override
  String get kbdNewline => 'Nova linha';

  @override
  String get kbdEditLast => 'Editar sua última mensagem';

  @override
  String get kbdBold => 'Negrito';

  @override
  String get kbdItalic => 'Itálico';

  @override
  String get kbdUnderline => 'Sublinhado';

  @override
  String get kbdPasteMedia => 'Colar uma foto ou arquivo';

  @override
  String get kbdEmoji => 'Emojis e figurinhas';

  @override
  String get kbdViewerPrevious => 'Anterior';

  @override
  String get kbdViewerNext => 'Próximo';

  @override
  String get kbdZoomIn => 'Ampliar';

  @override
  String get kbdZoomOut => 'Reduzir';

  @override
  String get kbdZoomFit => 'Ajustar à janela';

  @override
  String get kbdPlayPause => 'Reproduzir ou pausar';

  @override
  String get kbdCopyMedia => 'Copiar';

  @override
  String get kbdSaveMedia => 'Salvar';

  @override
  String get kbdToggleMute => 'Ativar ou desativar o microfone';

  @override
  String get kbdToggleCamera => 'Ligar ou desligar a câmera';

  @override
  String get kbdHangUp => 'Desligar';

  @override
  String get kbdGroupApp => 'App';

  @override
  String get kbdCloseWindow => 'Fechar janela';

  @override
  String get kbdMinimizeWindow => 'Minimizar';

  @override
  String get kbdFullScreen => 'Tela cheia';

  @override
  String get kbdHideApp => 'Ocultar MonkeyHub';

  @override
  String get kbdQuit => 'Encerrar MonkeyHub';

  @override
  String get kbdPanelTitle => 'Atalhos de teclado';

  @override
  String get kbdPanelSearchHint => 'Buscar atalhos';

  @override
  String get kbdPanelEmpty => 'Nenhum atalho encontrado';

  @override
  String kbdPeekHint(String key) {
    return 'Segure $key a qualquer momento para ver os atalhos desta tela';
  }

  @override
  String kbdPeekSetting(String key) {
    return 'Mostrar atalhos ao segurar $key';
  }

  @override
  String get kbdPaletteHint => 'Ir para uma conversa ou executar um comando';

  @override
  String get kbdPaletteChats => 'Conversas';

  @override
  String get kbdPaletteCommands => 'Comandos';

  @override
  String get kbdPaletteEmpty => 'Nada encontrado';

  @override
  String get kbdPaletteMove => 'Navegar';

  @override
  String get kbdPaletteOpen => 'Abrir';

  @override
  String get kbdPaletteClose => 'Fechar';

  @override
  String get msgDeskReactLabel => 'Reagir';

  @override
  String get msgDeskMoreLabel => 'Mais';

  @override
  String get msgDeskInfoLabel => 'Info';

  @override
  String get kbdSeekBackward => 'Voltar 5 segundos';

  @override
  String get kbdSeekForward => 'Avançar 5 segundos';

  @override
  String get kbdMuteVideo => 'Ativar ou desativar o som do vídeo';

  @override
  String get viewerSavedToDownloads => 'Salvo em Downloads';

  @override
  String get viewerDownloaded => 'Baixado';

  @override
  String get viewerShowInFinder => 'Mostrar no Finder';

  @override
  String get viewerShowInFolder => 'Mostrar na pasta';

  @override
  String get viewerCopied => 'Copiado';

  @override
  String get viewerCopyFailed => 'Não deu pra copiar';

  @override
  String get hoverCompactLayoutTitle => 'Layout compacto';

  @override
  String get hoverCompactLayoutSubtitle =>
      'Linhas mais baixas e botões menores, pensados para mouse e tela grande.';

  @override
  String get layoutPagerPrevious => 'Anterior';

  @override
  String get layoutPagerNext => 'Próximo';

  @override
  String get resultSheetMistakes => 'Erros';

  @override
  String get resultSheetHints => 'Dicas';

  @override
  String get resultSheetStreak => 'Sequência';

  @override
  String resultSheetStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '1 dia',
    );
    return '$_temp0';
  }

  @override
  String get resultSheetNone => 'Nenhum';

  @override
  String resultSheetToday(String game) {
    return '$game · Hoje';
  }

  @override
  String resultSheetYouFaster(String time) {
    return 'Você foi $time mais rápido';
  }

  @override
  String resultSheetTheyFaster(String name, String time) {
    return '$name foi $time mais rápido';
  }

  @override
  String get resultSheetSameTime => 'Mesmo tempo que você';

  @override
  String get resultSheetFooter =>
      'Só o tempo decide a classificação. Erros e dicas são só para os curiosos.';

  @override
  String get resultSheetHintNoRecord =>
      'Resolvido com dicas, então não pode virar recorde.';

  @override
  String get gameTierEasy => 'Fácil';

  @override
  String get gameTierMedium => 'Médio';

  @override
  String get gameTierHard => 'Difícil';

  @override
  String get gameComingSoon => 'Em breve';

  @override
  String get gameComingSoonName => 'Novo quebra-cabeça';

  @override
  String get chatGameNameTicTacToe => 'Jogo da velha';

  @override
  String get chatGameNameConnectFour => 'Lig 4';

  @override
  String get chatGameNameCheckers => 'Damas';

  @override
  String get chatGameNameReversi => 'Reversi';

  @override
  String get chatGameNameDots => 'Pontinhos';

  @override
  String get chatGameDescTicTacToe => 'Três em linha vence.';

  @override
  String get chatGameDescConnectFour =>
      'Solte as fichas. Quatro em linha vence.';

  @override
  String get chatGameDescCheckers => 'Pule para capturar. Pegue todas.';

  @override
  String get chatGameDescReversi => 'Cerque para virar. Quem tiver mais vence.';

  @override
  String get chatGameDescDots => 'Trace linhas, feche caixas, jogue de novo.';

  @override
  String get chatGameKindLive => 'Partida ao vivo';

  @override
  String get chatGameKindTurns => 'Por turnos';

  @override
  String get chatGameStatusWaiting => 'Aguardando';

  @override
  String get chatGameStatusPlaying => 'Em jogo';

  @override
  String get chatGameStatusPaused => 'Pausada';

  @override
  String get chatGameStatusFinished => 'Terminada';

  @override
  String get chatGameStatusEnded => 'Encerrada';

  @override
  String get chatGameYourMove => 'Sua vez';

  @override
  String chatGameTurnOf(String name) {
    return 'Vez de $name';
  }

  @override
  String chatGameWaitingFor(String name) {
    return 'Aguardando $name';
  }

  @override
  String chatGameWonBy(String name) {
    return '$name venceu';
  }

  @override
  String get chatGameYouWon => 'Você venceu';

  @override
  String get chatGameDraw => 'Empate';

  @override
  String get chatGameNobodyWon => 'Todos saíram, ninguém venceu';

  @override
  String chatGameReasonTimeout(String name) {
    return 'O tempo de $name acabou';
  }

  @override
  String chatGameReasonResign(String name) {
    return '$name desistiu';
  }

  @override
  String chatGameReasonLeft(String name) {
    return '$name saiu';
  }

  @override
  String get chatGameOpenSeat => 'Vaga livre';

  @override
  String get chatGameReady => 'Pronto';

  @override
  String get chatGameNotReady => 'Não está pronto';

  @override
  String chatGameWatchingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count assistindo',
      one: '1 assistindo',
    );
    return '$_temp0';
  }

  @override
  String get chatGameJoin => 'Entrar';

  @override
  String get chatGameWatch => 'Assistir';

  @override
  String get chatGamePlay => 'Jogar';

  @override
  String get chatGameOpen => 'Abrir';

  @override
  String get chatGameRematch => 'Revanche';

  @override
  String get chatGameNotRanked =>
      'Só por diversão. Jogos do chat não contam para suas sequências nem recordes.';

  @override
  String get chatGameNotRankedShort => 'Sem ranking';

  @override
  String get chatGameImReady => 'Estou pronto';

  @override
  String get chatGameUnready => 'Ainda não estou pronto';

  @override
  String get chatGameTakeSeat => 'Toque para entrar';

  @override
  String get chatGameLeaveSeat => 'Sair do lugar';

  @override
  String get chatGameStartsWhenReady => 'Começa quando todos estiverem prontos';

  @override
  String chatGameNeedPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $count jogadores',
      one: 'Falta 1 jogador',
    );
    return '$_temp0';
  }

  @override
  String get chatGameWatchingLabel => 'Assistindo';

  @override
  String get chatGameAskSwap => 'Pedir para trocar';

  @override
  String chatGameSwapRequest(String name) {
    return '$name quer entrar no seu lugar';
  }

  @override
  String get chatGameSwap => 'Trocar';

  @override
  String get chatGameDecline => 'Recusar';

  @override
  String get chatGameAccept => 'Aceitar';

  @override
  String chatGameSwapAsked(String name) {
    return 'Pedido enviado a $name';
  }

  @override
  String get chatGameCancel => 'Cancelar';

  @override
  String get chatGameResign => 'Desistir';

  @override
  String get chatGameResignConfirm => 'Desistir desta partida?';

  @override
  String get chatGameResignBody => 'Conta como derrota para você.';

  @override
  String get chatGameOfferDraw => 'Propor empate';

  @override
  String get chatGameDrawOffered => 'Empate proposto';

  @override
  String chatGameDrawOfferFrom(String name) {
    return '$name propõe empate';
  }

  @override
  String chatGamePausedTitle(String name) {
    return '$name saiu do jogo';
  }

  @override
  String get chatGamePausedMany => 'Jogadores saíram';

  @override
  String get chatGamePausedBody => 'Vamos segurar o tabuleiro um pouco.';

  @override
  String get chatGamePausedYou => 'O jogo continua quando todos voltarem.';

  @override
  String get chatGameLeave => 'Sair do jogo';

  @override
  String get chatGameGo => 'Já!';

  @override
  String get chatGameNudge => 'Cutucar';

  @override
  String get chatGameNudged => 'Cutucado';

  @override
  String chatGameHoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $count horas',
      one: 'Falta 1 hora',
    );
    return '$_temp0';
  }

  @override
  String chatGameMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Faltam $count minutos',
      one: 'Falta 1 minuto',
    );
    return '$_temp0';
  }

  @override
  String get chatGameMoveFailed => 'Essa jogada não foi enviada';

  @override
  String get chatGameStale => 'O tabuleiro mudou. Tente de novo.';

  @override
  String get chatGameStartTitle => 'Jogar um jogo';

  @override
  String get chatGameMenuItem => 'Jogo';

  @override
  String get chatGameModeLive => 'Ao vivo';

  @override
  String get chatGameBotEasyHint => 'Comete erros. Bom para aprender.';

  @override
  String get chatGameBotMediumHint => 'Joga direito e bloqueia suas vitórias.';

  @override
  String get chatGameBotHardHint => 'Pensa várias jogadas à frente.';

  @override
  String get chatGameStart => 'Começar';

  @override
  String get chatGameErrAlreadyLive =>
      'Já existe uma partida ao vivo aqui. Termine ou saia dela primeiro.';

  @override
  String get chatGameErrTooMany =>
      'Você já tem 3 partidas por turnos aqui. Termine uma primeiro.';

  @override
  String get chatGameErrEphemeral =>
      'Não dá para jogar em um chat onde as mensagens desaparecem.';

  @override
  String get chatGameErrGeneric => 'Algo deu errado. Tente de novo.';

  @override
  String get chatGamePlayersTwo => '2 jogadores';

  @override
  String get chatGamePlayersUpToFour => '2–4 jogadores';

  @override
  String get chatGameBotName => 'Macaco';

  @override
  String get chatGameBotBadge => 'Bot';

  @override
  String get chatGameNewGame => 'Novo jogo';

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
      other: 'Sua vez em $count',
      one: 'Sua vez em 1',
    );
    return '$_temp0';
  }

  @override
  String get chatGameSheetTitle => 'Jogos neste chat';

  @override
  String get chatGameGone => 'Este jogo não está mais disponível.';

  @override
  String get chatGameSeatsLabel => 'Jogadores';

  @override
  String get gameFlowName => 'Fluxo';

  @override
  String get gameFutoshikiName => 'Futoshiki';

  @override
  String get gameNonogramName => 'Nonograma';

  @override
  String get gameMinesweeperName => 'Campo minado';

  @override
  String get gameStarbattleName => 'Batalha de estrelas';

  @override
  String get gamePatchesName => 'Retalhos';

  @override
  String get gameFlowRule => 'ligue os pontos iguais e preencha todas as casas';

  @override
  String get gameFutoshikiRule =>
      'de 1 a 5 uma vez por linha e coluna, todo sinal valendo';

  @override
  String get gameNonogramRule => 'pinte casas para bater com cada pista';

  @override
  String get gameMinesweeperRule =>
      'abra cada casa segura, sem precisar chutar';

  @override
  String get gameStarbattleRule =>
      'duas estrelas por linha, coluna e cor, sem encostar';

  @override
  String get gamePatchesRule =>
      'divida o tabuleiro em retângulos, uma pista em cada';

  @override
  String get gameFlag => 'Bandeira';

  @override
  String get gameAutoDot => 'Pontos automáticos';

  @override
  String boardCellName(int row, int col) {
    return 'Linha $row, coluna $col';
  }

  @override
  String get boardEmpty => 'vazia';

  @override
  String get boardBlack => 'preta';

  @override
  String get boardWhite => 'branca';

  @override
  String get boardLegalMove => 'jogada válida';

  @override
  String get boardMoveHere => 'mover para cá';

  @override
  String boardColumnFilled(int column, int count, int total) {
    return 'Coluna $column, $count de $total preenchidas';
  }

  @override
  String boardSquareName(int number) {
    return 'Casa $number';
  }

  @override
  String get boardDarkMan => 'peça escura';

  @override
  String get boardDarkKing => 'dama escura';

  @override
  String get boardLightMan => 'peça clara';

  @override
  String get boardLightKing => 'dama clara';

  @override
  String boardBoxName(String cell) {
    return 'Caixa, $cell';
  }

  @override
  String get boardOpen => 'livre';

  @override
  String get boardDrawn => 'traçada';

  @override
  String boardClaimedBy(String name) {
    return 'de $name';
  }

  @override
  String boardHorizontalEdge(int row, int col) {
    return 'Linha horizontal, fileira $row, coluna $col';
  }

  @override
  String boardVerticalEdge(int row, int col) {
    return 'Linha vertical, fileira $row, coluna $col';
  }

  @override
  String get challengeAction => 'Desafiar';

  @override
  String get challengeTitle => 'Bata meu tempo';

  @override
  String get challengeKind => 'Desafio diário';

  @override
  String challengeYouBeat(String time) {
    return 'Você bateu por $time';
  }

  @override
  String challengeStillStanding(String time) {
    return 'Continua de pé, por $time';
  }

  @override
  String get challengeTie => 'Empate exato';

  @override
  String get challengeClosed => 'Esse tabuleiro já fechou';

  @override
  String get challengeYourTime => 'Seu tempo a bater';

  @override
  String get challengeSent => 'Desafio enviado';

  @override
  String challengeTarget(String name, String time) {
    return '$name $time';
  }

  @override
  String challengeBeatName(String name, String time) {
    return 'Você bateu os $time de $name';
  }

  @override
  String challengeKept(String name, String time) {
    return '$name mantém, por $time';
  }

  @override
  String challengeBackName(String name) {
    return 'Devolva o desafio para $name';
  }

  @override
  String challengeBackRoom(String room) {
    return 'Responder em $room';
  }

  @override
  String challengeFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count amigos jogaram',
      one: '1 amigo jogou',
      zero: 'Nenhum amigo seu daqui jogou ainda',
    );
    return '$_temp0';
  }

  @override
  String challengeYouAndFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Você e $count amigos jogaram',
      one: 'Você e 1 amigo jogaram',
      zero: 'Por enquanto só você jogou',
    );
    return '$_temp0';
  }

  @override
  String get challengeFriendsOnlyNote =>
      'Só seus amigos aparecem aqui. Outras pessoas desta conversa também podem ter jogado.';

  @override
  String get chatGameNameLiarsDice => 'Dado mentiroso';

  @override
  String get chatGameNameImposter => 'Impostor';

  @override
  String get chatGameNameRace => 'Corrida de quebra-cabeça';

  @override
  String get chatGameDescLiarsDice =>
      'Aposte em dados escondidos. Desmascare o mentiroso.';

  @override
  String get chatGameDescImposter =>
      'Alguém não sabe a palavra. Descubra quem.';

  @override
  String get chatGameDescRace =>
      'O mesmo quebra-cabeça para todos. Vence quem resolver primeiro.';

  @override
  String chatGamePlayersRange(int min, int max) {
    return '$min a $max jogadores';
  }

  @override
  String chatGameNeedsPeople(int count) {
    return 'Mínimo de $count pessoas';
  }

  @override
  String get chatGameVoiceOption => 'Dicas por voz';

  @override
  String get chatGameVoiceOptionHint =>
      'Fale numa chamada em vez de digitar as dicas';

  @override
  String get chatGamePuzzleOption => 'Quebra-cabeça';

  @override
  String get chatGamePuzzleRandom => 'Aleatório';

  @override
  String chatGameStartNamed(String game) {
    return 'Começar $game';
  }

  @override
  String chatGameLdRoundDice(int count, int round) {
    return 'Rodada $round · $count dados';
  }

  @override
  String get chatGameLdYourDice => 'Seus dados';

  @override
  String get chatGameLdNoBid => 'Nenhuma aposta ainda';

  @override
  String chatGameLdBidBy(String name) {
    return 'Aposta de $name';
  }

  @override
  String get chatGameLdYourBid => 'Sua aposta';

  @override
  String get chatGameLdBid => 'Apostar';

  @override
  String get chatGameLdLiar => 'Mentiroso!';

  @override
  String get chatGameLdOnesWild => 'Os 1 são coringas';

  @override
  String get chatGameLdOnesOnly => 'Aposta em 1: sem coringas';

  @override
  String get chatGameLdHolds => 'A aposta se confirmou';

  @override
  String get chatGameLdBusted => 'Pego no flagra!';

  @override
  String chatGameLdThereWere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Havia $count',
      one: 'Havia 1',
    );
    return '$_temp0';
  }

  @override
  String chatGameLdLosesDie(String name) {
    return '$name perde um dado';
  }

  @override
  String get chatGameLdYouLoseDie => 'Você perde um dado';

  @override
  String chatGameLdCalled(String name) {
    return '$name gritou mentiroso';
  }

  @override
  String chatGameLdTimedOut(String name) {
    return 'O tempo de $name acabou';
  }

  @override
  String get chatGameLdOut => 'Fora';

  @override
  String get chatGameLdQuantity => 'Quantos';

  @override
  String get chatGameLdFace => 'Qual face';

  @override
  String get chatGameLdFewer => 'Menos';

  @override
  String get chatGameLdMore => 'Mais';

  @override
  String get chatGameLdPrompt => 'Aumente a aposta ou grite mentiroso';

  @override
  String get chatGameLdOpenPrompt => 'Abra as apostas';

  @override
  String get chatGameImpHoldToSee => 'Segure para ver sua carta';

  @override
  String get chatGameImpYourWord => 'Sua palavra';

  @override
  String get chatGameImpYouAre => 'Você é o impostor';

  @override
  String chatGameImpCategory(String category) {
    return 'Categoria: $category';
  }

  @override
  String get chatGameImpBlendIn => 'Disfarce. Ninguém mais sabe.';

  @override
  String get chatGameImpKeepSecret =>
      'Não diga direto. Dê dicas que os outros entendam.';

  @override
  String get chatGameImpGotIt => 'Entendi';

  @override
  String chatGameImpLooked(int count, int total) {
    return '$count de $total já viram';
  }

  @override
  String chatGameImpGiving(String name) {
    return '$name está dando a dica';
  }

  @override
  String get chatGameImpYourClue => 'Sua vez de dar uma dica';

  @override
  String get chatGameImpClueHint => 'De uma a quatro palavras';

  @override
  String get chatGameImpClueField => 'Sua dica';

  @override
  String get chatGameImpSend => 'Enviar';

  @override
  String get chatGameImpTooManyWords => 'No máximo quatro palavras';

  @override
  String get chatGameImpPassed => 'Passou';

  @override
  String get chatGameImpSpoke => 'Falou na chamada';

  @override
  String get chatGameImpJoinCall => 'Entrar na chamada';

  @override
  String get chatGameImpOnCall => 'Você está na chamada';

  @override
  String get chatGameImpVoiceHint =>
      'Diga sua dica em voz alta e toque em Pronto.';

  @override
  String get chatGameImpDone => 'Pronto';

  @override
  String get chatGameImpVoteTitle => 'Quem é o impostor?';

  @override
  String get chatGameImpVoteHint =>
      'Toque num jogador para votar. Dá para mudar até o tempo acabar.';

  @override
  String get chatGameImpSkip => 'Pular voto';

  @override
  String chatGameImpVoted(int count, int total) {
    return '$count de $total votaram';
  }

  @override
  String get chatGameImpVotedBadge => 'Votou';

  @override
  String get chatGameImpYourVote => 'Seu voto';

  @override
  String get chatGameImpGuessing => 'O impostor está chutando…';

  @override
  String get chatGameImpGuessHint =>
      'Você foi pego. Acerte a palavra para roubar a vitória.';

  @override
  String get chatGameImpGuessField => 'A palavra é…';

  @override
  String get chatGameImpGuess => 'Chutar';

  @override
  String chatGameImpWas(String name) {
    return '$name era o impostor';
  }

  @override
  String get chatGameImpYouWere => 'Você era o impostor';

  @override
  String get chatGameImpTheWord => 'A palavra era';

  @override
  String chatGameImpTheyGuessed(String guess) {
    return 'Chutou “$guess”';
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
      other: '$count pularam',
      one: '1 pulou',
    );
    return '$_temp0';
  }

  @override
  String get chatGameImpReasonEscaped =>
      'Ninguém foi eliminado, e o impostor escapou.';

  @override
  String get chatGameImpReasonWrong => 'A equipe eliminou a pessoa errada.';

  @override
  String get chatGameImpReasonGuessed =>
      'Foi pego, mas o impostor acertou a palavra.';

  @override
  String get chatGameImpReasonCaught => 'A equipe pegou o impostor.';

  @override
  String get chatGameImpReasonImposterLeft => 'O impostor saiu do jogo.';

  @override
  String get chatGameImpReasonCrewLeft => 'O resto da equipe saiu.';

  @override
  String get chatGameImpCrewWon => 'A equipe venceu';

  @override
  String get chatGameImpYourTeamWon => 'Sua equipe venceu';

  @override
  String chatGameImpImposterWon(String name) {
    return '$name venceu como impostor';
  }

  @override
  String get chatGameImpYouWonImposter => 'Você venceu como impostor';

  @override
  String get chatGameImpCardReveal => 'Olhando as cartas';

  @override
  String chatGameImpCardClues(int count, int total) {
    return 'Dicas · $count de $total';
  }

  @override
  String get chatGameImpCardVote => 'Votação';

  @override
  String chatGameRaceFinishedCount(int count, int total) {
    return '$count de $total terminaram';
  }

  @override
  String chatGameRaceYouPlaced(int rank) {
    return 'Você terminou em $rankº';
  }

  @override
  String get chatGameRaceWaiting => 'Esperando os outros';

  @override
  String get chatGameRaceTimeUp => 'O tempo acabou. Ninguém terminou.';

  @override
  String get chatGameRaceDnf => 'Não terminou';

  @override
  String get chatGameRaceLeft => 'Saiu';

  @override
  String get chatGameRaceResults => 'Resultados';

  @override
  String get chatGameRaceSolved => 'Resolvido!';

  @override
  String get chatGamePartyLeaveConfirm => 'Sair deste jogo?';

  @override
  String get chatGamePartyLeaveBody => 'Os outros continuam sem você.';

  @override
  String get chatGameErrTooLate => 'Tarde demais, o tempo acabou';

  @override
  String get chatGameErrBadClue =>
      'Essa dica não vale. De uma a quatro palavras, sem links.';

  @override
  String get chatGameErrBadGuess => 'Digite um chute primeiro';

  @override
  String get chatGameErrNotSolved => 'O tabuleiro ainda não está resolvido';

  @override
  String get chatGameNameChess => 'Xadrez';

  @override
  String get chatGameDescChess => 'Vença com xeque-mate no rei.';

  @override
  String get chessPawn => 'peão';

  @override
  String get chessKnight => 'cavalo';

  @override
  String get chessBishop => 'bispo';

  @override
  String get chessRook => 'torre';

  @override
  String get chessQueen => 'dama';

  @override
  String get chessKing => 'rei';

  @override
  String chessPieceWhite(String piece) {
    return '$piece, brancas';
  }

  @override
  String chessPieceBlack(String piece) {
    return '$piece, pretas';
  }

  @override
  String chessPromoteTo(String piece) {
    return 'Promover a $piece';
  }

  @override
  String get kbdPeekDontShowAgain => 'Não mostrar mais';

  @override
  String get kbdPeekTurnedOff =>
      'Beleza, não vai aparecer mais. Dá pra ligar de novo nos Ajustes.';

  @override
  String get chatGameBadgeTurns => 'Por turnos';

  @override
  String get chatGameSectionBoards => 'Jogos de tabuleiro';

  @override
  String get chatGameSectionParty => 'Jogos de galera';

  @override
  String get chatGameBoardsHintDm =>
      'Joguem ao vivo agora ou por turnos quando tiverem um tempinho.';

  @override
  String get chatGameBoardsHintGroup =>
      'Ao vivo, aqui mesmo. Pega um lugar ou só assiste.';

  @override
  String get chatGamePartyHint =>
      'Todo mundo joga junto, então chama a galera antes.';

  @override
  String get chatGameLiveTitle => 'Jogar ao vivo';

  @override
  String get chatGameLiveNow => 'Todo mundo joga ao mesmo tempo, agora.';

  @override
  String get chatGameLivePause =>
      'Alguém saiu? O jogo pausa. São 2 minutos pra voltar, senão perde.';

  @override
  String get chatGameTurnsTitle => 'Jogar por turnos';

  @override
  String get chatGameTurnsAnytime =>
      'Jogue quando quiser. Cada jogada cai no chat.';

  @override
  String get chatGameTurnsClock =>
      '2 dias por jogada. A gente lembra a pessoa e você pode cutucar.';

  @override
  String get chatGameHowWillYouPlay => 'Como você quer jogar?';

  @override
  String get botHubTitle => 'Jogar contra o bot';

  @override
  String botHubSubtitle(String bot) {
    return 'Só você e o $bot. Aprenda as jogadas e depois vá ganhar dos seus amigos.';
  }

  @override
  String get botHubLevelTitle => 'Qual a dificuldade?';

  @override
  String get botHubPickGame => 'Escolha um jogo';

  @override
  String get botHubCaption => 'Treino';

  @override
  String botHubGameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos',
      one: '1 jogo',
    );
    return '$_temp0';
  }

  @override
  String get practiceNotRanked =>
      'Só por diversão. Esses jogos não contam para suas sequências nem recordes.';

  @override
  String get chatGameMvYouPlayed => 'Você jogou';

  @override
  String chatGameMvTheyPlayed(String name) {
    return '$name jogou';
  }

  @override
  String chatGameMvNumber(int count) {
    return 'Jogada $count';
  }

  @override
  String chatGameMvColumn(int count) {
    return 'Coluna $count';
  }

  @override
  String get chatGameMvEarlier => 'Jogada anterior';

  @override
  String get chatGameMvSend => 'Enviar jogada';

  @override
  String get chatGameMvUndo => 'Desfazer';

  @override
  String get chatGameMvStagedHint =>
      'Ainda não foi. Muda de ideia ou toca em Enviar.';

  @override
  String get chatGameMvSentToast =>
      'Jogada enviada. Agora é a vez do outro lado.';

  @override
  String get chatGameMvYourTurnSub => 'Faz sua jogada e manda. Sem pressa.';

  @override
  String get chatGameMvWaitingSub => 'A gente te avisa quando for sua vez.';

  @override
  String get chatGameMvNudgeLater =>
      'Dá pra cutucar depois de 12 horas sem resposta';

  @override
  String get chatGameMvForfeitNote => 'Se o tempo acabar, quem tá na vez perde';

  @override
  String get chatGameMvAgain => 'Ainda é sua vez. Joga de novo!';

  @override
  String get chatGameMvSending => 'Enviando…';

  @override
  String get howToNext => 'Próximo';

  @override
  String get howToWatchAgain => 'Ver de novo';

  @override
  String get howToGotIt => 'Entendi';

  @override
  String get howToProTip => 'Dica';

  @override
  String howToStepSemantic(int step, int total) {
    return 'Passo $step de $total';
  }

  @override
  String get howToQueens1 => 'Uma coroa em cada linha, cada coluna e cada cor.';

  @override
  String get howToQueens2 =>
      'As coroas não podem se encostar. Nem na diagonal.';

  @override
  String get howToQueens3 =>
      'Toque uma vez pra ×, duas pra coroa, mais uma pra apagar.';

  @override
  String get howToQueens4 =>
      'Com as Cruzes automáticas ligadas, toda casa que uma coroa descarta ganha um × pra você. Aí é só ver o que sobrou.';

  @override
  String get howToTango1 =>
      'Um toque é sol, dois é lua. Preencha todas as casas.';

  @override
  String get howToTango2 => 'Cada linha e coluna tem metade sóis, metade luas.';

  @override
  String get howToTango3 =>
      'Nunca 3 iguais seguidos, na horizontal ou na vertical. 2 pode.';

  @override
  String get howToTango4 => '= quer dizer iguais. × quer dizer opostos.';

  @override
  String get howToTangoTip =>
      'Dois iguais lado a lado? As casas nas duas pontas ficam com o outro.';

  @override
  String get howToZip1 =>
      'Comece no 1 e arraste passando pelos números em ordem.';

  @override
  String get howToZip2 =>
      'Passe por todas as casas e termine no último número.';

  @override
  String get howToZip3 => 'Errou o caminho? É só arrastar de volta.';

  @override
  String get howToZipTip =>
      'Não deixe nenhuma casa isolada. Pegue os cantos e as bordas no caminho.';

  @override
  String get howToSudoku1 =>
      'Cada linha, coluna e bloco tem de 1 a 6. Sem repetir.';

  @override
  String get howToSudoku2 => 'Toque numa casa e depois num número.';

  @override
  String get howToSudoku3 =>
      'Número repetido na mesma linha, coluna ou bloco? Fica vermelho.';

  @override
  String get howToSudoku4 =>
      'Procure linhas em que só falta um número. É ponto de graça.';

  @override
  String get howToFlow1 =>
      'Arraste de um ponto até o par dele pra fazer o cano.';

  @override
  String get howToFlow2 =>
      'Os canos não se cruzam e todas as casas precisam ser preenchidas. Dê a volta.';

  @override
  String get howToFlowTip =>
      'Passe os canos pelas bordas primeiro. O meio se resolve sozinho.';

  @override
  String get howToFutoshiki1 =>
      'Preencha cada casa com um número de 1 a 5. Cada linha e coluna tem cada número exatamente uma vez.';

  @override
  String get howToFutoshiki2 => 'A ponta do sinal aponta pro número menor.';

  @override
  String get howToFutoshiki3 => 'Desrespeitou um sinal? Ele fica vermelho.';

  @override
  String get howToFutoshikiTip =>
      'Siga as correntes: se a < b < c, então c é no mínimo 3.';

  @override
  String get howToNonogram1 =>
      'Cada número é um bloco de casas pintadas, sem espaços. 5 são 5 casas seguidas.';

  @override
  String get howToNonogram2 =>
      '1 1 são duas casas soltas com pelo menos uma casa vazia entre elas. O espaço também pode ser maior.';

  @override
  String get howToNonogramOrder =>
      'A ordem importa: as linhas são lidas da esquerda para a direita, e as colunas de cima para baixo. 1 3 é primeiro um 1, depois um 3.';

  @override
  String get howToNonogram3 =>
      'Toque pra pintar, de novo pra ×, de novo pra apagar. Arraste pra fazer várias de uma vez.';

  @override
  String get howToNonogram4 =>
      'Acerte todas as dicas e o desenho escondido aparece.';

  @override
  String get howToNonogramTip =>
      'Comece pelas pistas grandes. Um 7 numa linha de 10 sempre cobre as 4 do meio.';

  @override
  String get howToMines1 =>
      'Abra todas as casas que não são mina. As áreas vazias abrem sozinhas.';

  @override
  String get howToMines2 =>
      'O número diz quantas minas encostam nele, cantos também.';

  @override
  String get howToMines3 =>
      'Certeza que é mina? Segure pra colocar uma bandeira.';

  @override
  String get howToMines4 =>
      'Pisou numa mina, levou 30 segundos de castigo. Mas você nunca precisa chutar.';

  @override
  String get howToMinesTip =>
      'Um 1 com uma única casa escondida do lado? Essa casa é a mina.';

  @override
  String get howToStars1 =>
      'Duas estrelas em cada linha, cada coluna e cada cor.';

  @override
  String get howToStars2 =>
      'As estrelas não podem se encostar. Nem na diagonal.';

  @override
  String get howToStarsControls =>
      'Toque uma vez pra ponto, duas pra estrela, mais uma pra apagar.';

  @override
  String get howToStars3 =>
      'Com os Pontos automáticos ligados, uma estrela marca um ponto nas casas em volta dela. Quando uma linha tem as 2, o resto ganha ponto também.';

  @override
  String get howToPatches1 =>
      'Divida o tabuleiro em retângulos. Cada um tem exatamente uma pista.';

  @override
  String get howToPatches2 =>
      'O selo é a forma do retalho: quadrado, alto ou largo. Um selo tracejado quer dizer que pode ser qualquer uma das três. O número, quando tem, diz quantas casas o retalho ocupa.';

  @override
  String get howToPatches3 =>
      'Arraste de canto a canto pra cortar um retalho. Toque num retalho pra tirar.';

  @override
  String get howToPatches4 =>
      'Uma pista grande encostada na borda muitas vezes só encaixa de um jeito. Comece por ela.';

  @override
  String get howToCode1 =>
      'Tem um código secreto de 4 símbolos diferentes, sem repetir. Descubra qual é.';

  @override
  String get howToCode2 => 'Verde: símbolo certo, lugar certo.';

  @override
  String get howToCode3 =>
      'Amarelo: tá no código, mas em outro lugar. Cinza: não tá no código.';

  @override
  String get howToCode4 => 'Você tem 6 chances. Quanto menos usar, melhor.';

  @override
  String get howToCodeTip =>
      'Use os primeiros palpites em símbolos novos. Aprender vale mais que chutar.';

  @override
  String get howToTtt1 =>
      'Cada um na sua vez coloca a marca. Fez 3 em linha, ganhou.';

  @override
  String get howToTtt2 =>
      'O outro já tem 2 em linha? Pega a terceira casa antes dele.';

  @override
  String get howToC41 =>
      'Toque numa coluna pra soltar a ficha. Ela cai até o espaço livre mais baixo.';

  @override
  String get howToC42 =>
      'Faça 4 em linha pra ganhar: na horizontal, na vertical ou na diagonal.';

  @override
  String get howToC4Tip =>
      'Jogue na coluna do meio. Ela faz parte de mais sequências de 4 que qualquer outra.';

  @override
  String get howToCheckers1 =>
      'As peças andam uma casa na diagonal pra frente. Toque na peça e depois no destino.';

  @override
  String get howToCheckers2 =>
      'Pule por cima de uma peça rival pra capturar. Se dá pra pular, é obrigatório. A peça que precisa pular ganha um anel.';

  @override
  String get howToCheckers3 =>
      'Caiu num lugar onde dá pra pular de novo? Continue. Uma jogada pode levar várias.';

  @override
  String get howToCheckers4 =>
      'Chegou do outro lado? Sua peça vira dama. Damas andam pra trás também, mas sempre uma casa só.';

  @override
  String get howToCheckersWin =>
      'Ganha quem captura todas as peças ou deixa o outro sem jogada. 40 jogadas de cada um sem captura e sem mexer peça comum é empate.';

  @override
  String get howToCheckersTip =>
      'Mantenha sua última fileira em casa. Assim eles não conseguem virar rei.';

  @override
  String get howToReversi1 =>
      'Coloque uma peça de um jeito que uma fila das dele fique presa entre duas suas. Toda jogada tem que prender pelo menos uma.';

  @override
  String get howToReversi2 =>
      'Toda peça presa vira pra sua cor, em todas as direções de uma vez.';

  @override
  String get howToReversi3 =>
      'Sem jogada? Você passa a vez. Quando ninguém mais consegue jogar, ganha quem tem mais peças.';

  @override
  String get howToReversiTip =>
      'Pegue os cantos. Uma peça no canto nunca pode ser virada.';

  @override
  String get howToDots1 =>
      'Cada um na sua vez traça uma linha entre dois pontos.';

  @override
  String get howToDots2 => 'Fechou uma caixa, ela é sua. E você joga de novo!';

  @override
  String get howToDots3 =>
      'Cuidado com o terceiro lado de uma caixa. Isso entrega ela de bandeja pro próximo.';

  @override
  String get howToDotsWin =>
      'Quando a última linha é traçada, ganha quem tem mais caixas.';

  @override
  String get howToChess1 =>
      'Toque numa peça pra ver pra onde ela pode ir, depois toque numa casa.';

  @override
  String get howToChess2 => 'Vá pra casa de uma peça rival pra capturar.';

  @override
  String get howToChess3 =>
      'Leve um peão até a última fileira e ele vira rainha, ou o que você escolher.';

  @override
  String get howToChess4 =>
      'Xeque é quando o rei está sob ataque e você precisa salvá-lo. Sem saída? Xeque-mate, fim de jogo. Sem jogada possível, mas sem estar em xeque? É empate.';

  @override
  String get howToChessTip =>
      'Antes de cada jogada, veja o que eles podem capturar.';

  @override
  String get howToLiars1 =>
      'Todo mundo joga 5 dados escondido. Você só vê os seus.';

  @override
  String get howToLiars2 =>
      'Na sua vez, aposte que tem pelo menos tantos dados de uma face na mesa inteira, contando os de todo mundo. Tipo “quatro três”.';

  @override
  String get howToLiars3 =>
      'O 1 é coringa: conta como qualquer face. A não ser que a aposta seja no 1.';

  @override
  String get howToLiars4 =>
      'O próximo tem que subir: mais dados, ou a mesma quantidade de uma face maior…';

  @override
  String get howToLiars5 =>
      '…ou gritar “mentiroso!”. Todo mundo mostra os dados e conta.';

  @override
  String get howToLiars6 =>
      'Tem pelo menos isso? Quem gritou perde um dado. Tem menos? Quem apostou perde.';

  @override
  String get howToLiars7 =>
      'Acabaram seus dados, você tá fora. O último com dados ganha.';

  @override
  String get howToLiarsClock =>
      '45 segundos por vez. Se o tempo acabar, o jogo joga por você.';

  @override
  String get howToLiarsTip =>
      'Conte seus dados primeiro. Como os 1 são coringas, cerca de um terço dos dados dos outros bate com a face que você aposta.';

  @override
  String get howToImposter1 =>
      'Todo mundo recebe a mesma palavra secreta. Menos o impostor, que só vê a categoria.';

  @override
  String get howToImposter2 =>
      'Cada um dá uma dica curta na sua vez. Mostre que sabe a palavra sem entregar.';

  @override
  String get howToImposterVoice =>
      'No modo voz: fale sua dica em voz alta na chamada e toque em Pronto.';

  @override
  String get howToImposter3 =>
      'Depois, todo mundo vota em quem acha que é o impostor, ou pula o voto.';

  @override
  String get howToImposter4 =>
      'Pegaram o impostor? Ele tem uma última chance: se acertar a palavra, rouba a vitória. Votaram na pessoa errada, empatou ou muita gente pulou? O impostor ganha.';

  @override
  String get howToRace1 =>
      'Todo mundo recebe o mesmo quebra-cabeça novinho na mesma hora.';

  @override
  String get howToRace2 =>
      'Resolva no seu celular. Sua barra mostra pra todo mundo o quanto falta.';

  @override
  String get howToRace3 => 'Quem terminar primeiro ganha. Você tem 10 minutos.';

  @override
  String get howToLive1 =>
      'Todo mundo joga ao mesmo tempo. Quando todos tocam em Estou pronto, começa.';

  @override
  String get howToLive2 =>
      'Alguém saiu do jogo? Pausa pra todo mundo. A pessoa tem 2 minutos pra voltar, senão perde.';

  @override
  String get howToLive3 =>
      'O resto do chat pode assistir. Eles podem pedir um lugar, e um jogador pode passar o dele.';

  @override
  String get howToTurns1 =>
      'Faça sua jogada e toque em Enviar jogada. Ela chega no chat como mensagem.';

  @override
  String get howToTurns2 =>
      'Cada jogada tem 2 dias. A gente lembra a pessoa depois de 20 horas, e depois de 12 horas de silêncio você mesmo pode cutucar.';

  @override
  String get howToTurns3 =>
      'Ficou 2 dias sem jogar? É derrota. Até 3 partidas ao mesmo tempo por chat.';

  @override
  String momentActivityGamesSolvedAll(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos',
      one: '1 jogo',
    );
    return '$name resolveu $_temp0';
  }

  @override
  String momentActivityGamesSolvedSome(int count, String name, int solved) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos',
      one: '1 jogo',
    );
    return '$name resolveu $solved de $_temp0';
  }

  @override
  String momentActivityGamesPlayed(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jogos',
      one: '1 jogo',
    );
    return '$name jogou $_temp0';
  }

  @override
  String momentActivityHighlightsPosted(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count momentos',
      one: '1 momento',
    );
    return '$name publicou $_temp0';
  }

  @override
  String podiumSharedBy(int count, String names, int place) {
    return 'Posição $place, compartilhada por $count: $names';
  }

  @override
  String get myBestsLabel => 'Meus recordes';

  @override
  String recordsSharedBy(int count, String name) {
    return '$name +$count';
  }

  @override
  String get reportSheetDisclosureMessage =>
      'Ao denunciar, esta mensagem e as últimas mensagens desta conversa são enviadas aos moderadores do MonkeyHub para análise. A pessoa não vai saber que você a denunciou.';

  @override
  String get reportSheetDisclosureUser =>
      'Ao denunciar, suas últimas mensagens com esta pessoa são enviadas aos moderadores do MonkeyHub para análise. Ela não vai saber que você a denunciou.';

  @override
  String get reportSheetDisclosureRoom =>
      'Ao denunciar, as últimas mensagens deste grupo são enviadas aos moderadores do MonkeyHub para análise. Ninguém aqui vai saber que você o denunciou.';

  @override
  String get reportSheetAlsoBlock => 'Bloquear esta pessoa também';

  @override
  String get reportSentReviewed =>
      'Obrigado. Nossos moderadores analisam as denúncias em até 24 horas.';

  @override
  String get reportSentAndBlocked =>
      'Obrigado. Nossos moderadores analisam as denúncias em até 24 horas. Você bloqueou esta pessoa.';

  @override
  String get reportTooMany =>
      'Você enviou muitas denúncias. Tente de novo daqui a pouco.';

  @override
  String get reportFailed =>
      'Não foi possível enviar a denúncia. Tente de novo.';

  @override
  String get riReportPerson => 'Denunciar esta pessoa';

  @override
  String get riReportGroup => 'Denunciar este grupo';

  @override
  String get moderationActionRemoveMessage => 'Remover mensagem';

  @override
  String get moderationActionBan => 'Banir usuário';

  @override
  String get moderationActionUnban => 'Remover banimento';

  @override
  String get moderationActionDismiss => 'Arquivar denúncia';

  @override
  String get moderationConfirmRemoveTitle => 'Remover esta mensagem?';

  @override
  String get moderationConfirmRemoveBody =>
      'Ela é apagada para todos na conversa. O cartão da denúncia guarda a cópia dele.';

  @override
  String get moderationConfirmBanTitle => 'Banir esta conta?';

  @override
  String get moderationConfirmBanBody =>
      'A pessoa é desconectada em todo lugar, não consegue entrar de novo, some da busca e sai de todas as salas públicas. Você pode remover o banimento por este cartão.';

  @override
  String get moderationActionDone => 'Pronto';

  @override
  String get moderationActionFailed => 'Não deu certo. Tente de novo.';

  @override
  String get moderationCantBan =>
      'Moderadores e contas do sistema não podem ser banidos.';

  @override
  String get messageFilterBlocked =>
      'Esta mensagem não pode ser enviada porque pode conter linguagem imprópria.';

  @override
  String get nameInappropriate =>
      'Esse nome pode conter linguagem imprópria. Escolha outro, por favor.';

  @override
  String get authErrorAccountSuspended =>
      'Sua conta foi suspensa por violar os Termos de Uso.';

  @override
  String get termsConsentPrefix => 'Concordo com os ';

  @override
  String get termsConsentLink => 'Termos de Uso (EULA)';

  @override
  String get termsConsentSuffix =>
      ' e entendo que não há nenhuma tolerância para conteúdo impróprio ou usuários abusivos.';

  @override
  String get termsConsentSemanticLabel => 'Concordar com os Termos de Uso';

  @override
  String get termsMustAccept => 'Concorde com os Termos de Uso para continuar.';

  @override
  String get termsSheetTitle => 'Termos de Uso';

  @override
  String get termsSheetBody =>
      'Para continuar usando o MonkeyHub, concorde com nossos Termos de Uso. Aqui não tem lugar para conteúdo impróprio nem comportamento abusivo, e nossos moderadores analisam o conteúdo denunciado.';

  @override
  String get termsSheetAccept => 'Concordar e continuar';

  @override
  String get termsAcceptFailed => 'Não foi possível salvar. Tente de novo.';

  @override
  String get settingsHubContactSupport => 'Falar com o suporte';

  @override
  String get reportSheetDisclosureMoment =>
      'Denunciar envia este momento para os moderadores do MonkeyHub revisarem. A pessoa não vai saber que você a denunciou.';

  @override
  String get reportSheetDisclosureComment =>
      'Denunciar envia este comentário para os moderadores do MonkeyHub revisarem. A pessoa não vai saber que você a denunciou.';

  @override
  String get sendLimitRateLimited =>
      'Você está enviando rápido demais. Espere um pouco e tente de novo.';

  @override
  String get sendLimitStorageFull =>
      'Seu armazenamento está cheio. Apague algumas fotos ou arquivos que você enviou para liberar espaço.';

  @override
  String get sendLimitFileTooLarge =>
      'Esse arquivo é grande demais para enviar.';

  @override
  String get sendLimitMessageTooLong =>
      'Essa mensagem é longa demais. Tente dividi-la em algumas mensagens.';

  @override
  String get limitTooOften =>
      'Você está fazendo isso com muita frequência. Tente de novo daqui a pouco.';

  @override
  String get limitRoomFull => 'Esta sala está cheia.';

  @override
  String get limitRemovedFromRoom =>
      'Você foi removido desta sala. Um administrador pode convidar você de novo.';

  @override
  String get limitTooManyRooms =>
      'Você está em salas demais. Saia primeiro de uma que não usa mais.';

  @override
  String get limitRoomTextTooLong =>
      'Esse nome ou descrição é longo demais. Use menos de 100 caracteres no nome e menos de 500 na descrição.';

  @override
  String get limitNotYourFile =>
      'Não é possível usar esse arquivo. Escolha de novo e tente outra vez.';

  @override
  String get limitDeviceLoginBusy =>
      'Os códigos de login estão ocupados agora. Tente de novo em um minuto.';

  @override
  String get limitRequestMessages =>
      'Você não pode enviar mais até a pessoa aceitar seu pedido.';

  @override
  String get mediaSendViewOnceTip => 'Só vai poder abrir uma vez';

  @override
  String get mediaSendSpoilerTip => 'Escondida sob poeira até tocarem';

  @override
  String get mediaSendSpoilerNote => 'Escondida até tocarem';

  @override
  String get mediaSendSpoilerOnSemanticLabel => 'Spoiler: ativado';

  @override
  String get mediaSendSpoilerOffSemanticLabel => 'Spoiler: desativado';

  @override
  String get mediaSpoilerRevealSemanticLabel => 'Spoiler. Toque para revelar';
}
