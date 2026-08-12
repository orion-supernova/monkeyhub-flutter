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
  String get bootErrorTitle => 'SERVIDOR INACESSÍVEL';

  @override
  String get bootErrorBody => 'O Convex não foi inicializado.';

  @override
  String get bootErrorRetry => 'TENTAR NOVAMENTE';

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
      'não foi possível pedir agora — tenta outra vez';

  @override
  String get roomScreenGateSendMessages => 'enviar mensagens aqui';

  @override
  String get roomScreenGateSendMedia => 'enviar fotos ou notas de voz';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'no máximo $max de cada vez';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ELIMINAR $count MENSAGENS',
      one: 'ELIMINAR MENSAGEM',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Isto elimina as mensagens para todos nesta conversa. Não é possível desfazer esta ação.';

  @override
  String get roomScreenDeleteConfirmButton => 'ELIMINAR PARA TODOS';

  @override
  String get roomScreenJumpFailedSnack =>
      'não foi possível saltar para essa mensagem';

  @override
  String get roomScreenViewOnceAlreadyViewed => 'já abriste esta fotografia.';

  @override
  String get roomScreenViewOnceGone =>
      'esta fotografia já não está disponível.';

  @override
  String get roomScreenViewOnceNetworkError =>
      'não foi possível carregar essa fotografia.';

  @override
  String get roomScreenFileReadFailedSnack =>
      'não foi possível ler esse ficheiro';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'os ficheiros têm um limite de $size';
  }

  @override
  String get roomScreenRoomGone => 'sala desapareceu';

  @override
  String get roomScreenCopiedSnack => 'copiado';

  @override
  String get roomScreenNameCopiedSnack => 'nome copiado';

  @override
  String get roomScreenPinLimitSnack =>
      'demasiadas mensagens fixadas — desafixa uma primeiro';

  @override
  String get roomScreenPinFailedSnack => 'não foi possível fixar essa mensagem';

  @override
  String get roomScreenReportSentSnack =>
      'denúncia enviada em privado. a outra pessoa não será notificada.';

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
    return 'esta sala é efémera. as mensagens desvanecem-se ao fim de $ttl, lidas ou não lidas.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count MENSAGENS';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'Espaço Secreto';

  @override
  String get roomScreenSecretSpaceBody =>
      'As mensagens desta sala são efémeras. São removidas automaticamente de acordo com a política de segurança da sala.';

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
  String get roomScreenViewProfilePictureSemantic => 'ver foto de perfil';

  @override
  String get roomScreenViewRoomPictureSemantic => 'ver foto da sala';

  @override
  String get messageBubbleFileFallbackName => 'documento';

  @override
  String get messageBubbleAttachmentStatusFailed => 'falhou';

  @override
  String get messageBubbleAttachmentStatusSending => 'a enviar…';

  @override
  String get messageBubbleViewOnceOpened => 'aberta';

  @override
  String get messageBubbleViewOnceExpired => 'expirada';

  @override
  String get messageBubbleViewOnceLabel => 'ver uma vez';

  @override
  String get messageBubbleViewOnceTapToView => 'toca para ver';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Foto';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'foto de visualização única, toca para ver';

  @override
  String get messageBubbleRetrySendingSemanticLabel =>
      'tentar enviar novamente';

  @override
  String get messageBubbleDiscardSemanticLabel => 'descartar';

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
  String get profileScreenEmailHint => 'opcional — nunca é mostrado a ninguém';

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
      'já te enviaram um pedido — vê os teus pedidos.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'pedido já enviado.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'bloqueaste este utilizador — desbloqueia-o primeiro.';

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
      'Só uma pessoa crescida pode fazer isto — é preciso o código ou a palavra-passe dela.';

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
  String get profileScreenLinkedAccountsNone => 'nenhuma conta ligada';

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
    return 'pode voltar a ser alterado a $date';
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
      'vista limitada — partilham mais com os amigos.';

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
  String get cameraEditorScreenCropPresetFree => 'LIVRE';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'ORIG.';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'cancelar o recorte';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'descartar a foto';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'desfazer';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'refazer';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'repor o recorte';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'rodar';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'recortar';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'este navegador não consegue abrir fotos HEIC';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'não conseguimos abrir essa imagem';

  @override
  String get cameraEditorScreenCropDoneButton => 'CONCLUÍDO';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'tirar novamente';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'guardar a caneta';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'desenhar na foto';

  @override
  String get cameraEditorScreenSendingButton => 'A ENVIAR…';

  @override
  String get cameraEditorScreenSendButton => 'ENVIAR';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'desaparece depois de ser aberta uma vez';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'limpar o desenho';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel =>
      'visualização única: ativada';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel =>
      'visualização única: desativada';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'cor da tinta';

  @override
  String get glassScreenPanelLooks => 'ESTILOS';

  @override
  String get glassScreenPanelBottomBar => 'BARRA INFERIOR';

  @override
  String get glassScreenPanelOtherSurfaces => 'OUTRAS SUPERFÍCIES';

  @override
  String get glassScreenPanelBarLayout => 'DISPOSIÇÃO DA BARRA';

  @override
  String get glassScreenTitle => 'vidro.';

  @override
  String get glassScreenSubtitle => 'quanto se vê do que está por trás';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'TODOS OS $max ESPAÇOS OCUPADOS';
  }

  @override
  String get glassScreenSaveCurrentAs => 'GUARDAR ATUAL COMO…';

  @override
  String get glassScreenResetEveryDial => 'REPOR TODOS OS COMANDOS';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'REPOR PARA $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'a caixa de mensagem, os cabeçalhos, os botões de chamada — tudo o que fica sobre texto em vez de sobre conteúdo que desliza';

  @override
  String get glassScreenMatchBottomBar => 'IGUALAR À BARRA INFERIOR';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'editado — guarda como um novo estilo, ou repõe';

  @override
  String get glassScreenCustomPresetName => 'Personalizado';

  @override
  String get glassScreenUnsavedSubtitle =>
      'não guardado — dá-lhe um nome para o manteres';

  @override
  String get glassScreenSaveDialogTitle => 'guardar este visual como';

  @override
  String get glassScreenNoRoomToast =>
      'sem espaço — elimina um visual primeiro';

  @override
  String get glassScreenRenameDialogTitle => 'mudar nome';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'eliminar $name?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'o visual continua no ecrã — só deixa de ter nome.';

  @override
  String get glassScreenKeepButton => 'manter';

  @override
  String get glassScreenDeleteButton => 'eliminar';

  @override
  String get glassScreenNameHint => 'noite tardia';

  @override
  String get glassScreenCancelButton => 'cancelar';

  @override
  String get glassScreenSaveButton => 'guardar';

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
  String get glassScreenPreviewBadge => 'PRÉ-VISUALIZAÇÃO';

  @override
  String get glassScreenBuiltInLabel => 'de série';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'substituir $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'mudar nome de $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'eliminar $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'repor $label';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'enviou as fotos do telhado — as telhas estão todas rachadas';

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
  String get replyIndicatorViewOnceLabel => 'foto · ver uma vez';

  @override
  String get replyIndicatorVoiceMessageLabel => 'mensagem de voz';

  @override
  String get replyIndicatorDocumentLabel => 'documento';

  @override
  String get replyIndicatorMessageRemoved => 'mensagem removida';

  @override
  String get threadOverlayMessageNotFound =>
      'não consegui encontrar essa mensagem neste tópico';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'não consegui encontrar o tópico para responder';

  @override
  String get threadOverlayStillSending =>
      'ainda a enviar — tenta novamente daqui a pouco';

  @override
  String get threadOverlayCopiedToast => 'copiado';

  @override
  String get threadOverlayNameCopiedToast => 'nome copiado';

  @override
  String get threadOverlayPinLimitToast =>
      'demasiadas mensagens fixadas — desafixa uma primeiro';

  @override
  String get threadOverlayPinFailedToast => 'não consegui fixar isso';

  @override
  String get threadOverlayReportedToast => 'denunciado';

  @override
  String get threadOverlayUnavailable => 'tópico indisponível';

  @override
  String get roomInfoScreenNameRequiredError => 'o nome é obrigatório';

  @override
  String get roomInfoScreenSavedSnackbar => 'guardado';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'palavra-passe removida';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'sair da sala?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'podes voltar a entrar se ela continuar aberta.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'SAIR';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'eliminar sala?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'todas as mensagens aqui desaparecem com ela. isto é permanente.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'ELIMINAR';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      'terminar esta conversa?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName também perde esta conversa — todas as mensagens desaparecem para os dois. isto é permanente.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'TERMINAR';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'a outra pessoa';

  @override
  String get roomInfoScreenConfirmCancelButton => 'CANCELAR';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'já existe uma sala com esse nome';

  @override
  String get roomInfoScreenErrorNotOwner => 'só o dono pode fazer isso';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'não tens permissão';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'esta sala já não existe';

  @override
  String get roomInfoScreenRoomGone => 'a sala desapareceu';

  @override
  String get roomInfoScreenNameLabel => 'NOME';

  @override
  String get roomInfoScreenNameHint => 'nome da sala';

  @override
  String get roomInfoScreenDescriptionLabel => 'DESCRIÇÃO';

  @override
  String get roomInfoScreenDescriptionHint => 'uma linha sobre a sala…';

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
      'esta sala está protegida. por motivos de segurança, a palavra-passe atual não é apresentada — introduz uma nova para a substituir.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'substituir palavra-passe…';

  @override
  String get roomInfoScreenSetPasswordHint => 'bloquear com uma palavra-passe…';

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
  String get roomInfoScreenViewProfilePictureSemantic => 'ver foto de perfil';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'ver foto da sala';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'alterar foto da sala';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'adicionar foto da sala';

  @override
  String get roomInfoScreenLoadingMembers => 'a carregar membros…';

  @override
  String get roomInfoScreenOwnerBadge => 'DONO';

  @override
  String get roomInfoScreenSaveButton => 'GUARDAR';

  @override
  String get roomInfoScreenNoneCount => 'nenhum';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'o acesso à câmara está desativado.\nativa-o nas Definições para tirares uma fotografia.';

  @override
  String get cameraScreenOpeningSystemCamera => 'a abrir a câmara do sistema…';

  @override
  String get cameraScreenCloseButtonLabel => 'fechar câmara';

  @override
  String get cameraScreenLowLightBoostOnLabel =>
      'reforço de pouca luz: ativado';

  @override
  String get cameraScreenLowLightBoostOffLabel =>
      'reforço de pouca luz: desativado';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'flash: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'escolher da galeria';

  @override
  String get cameraScreenSwitchCameraLabel => 'mudar de câmara';

  @override
  String get cameraScreenTakePhotoLabel => 'tirar fotografia';

  @override
  String get childPolicyScreenAddByUsernameLabel =>
      'ADICIONAR POR NOME DE UTILIZADOR';

  @override
  String get childPolicyScreenAddCta => 'ADICIONAR';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'Ficam com exatamente o que tu tens: todos os pedidos para aprovar, todas as definições para alterar e o poder de te remover. Para $name, são logo família.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'ADICIONAR UM CRESCIDO';

  @override
  String get childPolicyScreenAddGuardianHint =>
      'o nome de utilizador da pessoa';

  @override
  String get childPolicyScreenAllowCta => 'PERMITIR';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'Não te vão voltar a perguntar sobre essa pessoa — quer seja $childName a adicioná-la, quer seja ela a adicionar $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'PERMITIR ALGUÉM';

  @override
  String get childPolicyScreenAskToAddLabel => 'PEDIR PARA ADICIONAR';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'só família — sem pedidos novos';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'podem perguntar-te sobre pessoas novas';

  @override
  String get childPolicyScreenBothFinalNote =>
      'Ambas as opções são definitivas. Se preferires só retirar-te, isso está em CRESCIDOS.';

  @override
  String get childPolicyScreenCallsLabel => 'CHAMADAS';

  @override
  String get childPolicyScreenCallsOffDesc => 'só mensagens';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'voz + vídeo com as pessoas permitidas';

  @override
  String get childPolicyScreenCancelLabel => 'CANCELAR';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Cancelar';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'adicionado — o pedido está a caminho';

  @override
  String get childPolicyScreenContactAddedToList =>
      'adicionado à lista de permitidos';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'CRIAR SALAS';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'não podem criar salas';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'podem criar as suas próprias salas privadas';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Tudo desaparece: as mensagens, fotografias, salas e amigos da criança. Isto não pode ser desfeito, e o nome de utilizador fica livre para qualquer outra pessoa.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'não foi possível eliminar a conta — tenta outra vez';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return 'ELIMINAR A CONTA DE $name?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Mensagens, fotografias, salas e amigos, tudo desaparece. Não pode ser desfeito.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'ELIMINAR A CONTA DE $name';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'ELIMINAR PARA SEMPRE';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'não foi possível adicionar essa pessoa — tenta outra vez';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'esse é o nome de utilizador da própria criança';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'uma criança não pode ser um crescido';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'não foi possível fazer isso — tenta outra vez';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'alguém tem de cuidar dele — adiciona primeiro outro crescido';

  @override
  String get childPolicyScreenErrorNotYours => 'isso não é teu para mudares';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'não há nenhuma conta com esse nome de utilizador';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'Ele passa a ter uma conta normal com esta palavra-passe, e todos os crescidos perdem toda a visibilidade. Não há volta atrás — terias de ser convidado como qualquer outra pessoa.';

  @override
  String get childPolicyScreenGraduateCta => 'GRADUAR';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'Ele mantém tudo e recebe uma palavra-passe. Perdes toda a visibilidade. Irreversível.';

  @override
  String get childPolicyScreenGraduateDangerLabel =>
      'GRADUAR PARA CONTA COMPLETA';

  @override
  String get childPolicyScreenGraduateFailed =>
      'não foi possível graduar — tenta outra vez';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'GRADUAR $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'uma palavra-passe para ele';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Retirar uma sala também o remove dela. Retirar uma pessoa também apaga a conversa — para os dois.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Todos aqui podem aprovar, mudar definições e ver tudo. Qualquer um deles pode agir sozinho — ninguém espera pelos outros.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'adicionado — já pode cuidar dele agora';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name removido';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (tu)';
  }

  @override
  String get childPolicyScreenLoading => 'a carregar…';

  @override
  String get childPolicyScreenLockedLabel => 'BLOQUEADO';

  @override
  String get childPolicyScreenMediaLabel => 'FOTOS + VOZ';

  @override
  String get childPolicyScreenMediaOffDesc => 'só texto';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'pode enviar fotos, vídeos e notas de voz';

  @override
  String get childPolicyScreenNoRoomsYet => 'ainda sem salas';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Qualquer pessoa aqui pode ser adicionada sem te perguntar outra vez — seja quem for a começar.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Sempre desligado para crianças. O Descobrir — a lista de salas de pessoas que não conheces — fica completamente escondido e não pode ser ativado. Se alguém o convidar para uma sala, continua a funcionar normalmente.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'SALAS PÚBLICAS';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian deixa de ver ou aprovar o que quer que seja sobre $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return 'REMOVER $name?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'REMOVER';

  @override
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count membros';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'CRESCIDOS';

  @override
  String get childPolicyScreenSectionPeopleAllowed => 'PESSOAS QUE AUTORIZASTE';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'SALAS QUE AUTORIZASTE';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'O QUE ELE PODE FAZER';

  @override
  String get childPolicyScreenSectionWhenDone => 'QUANDO TERMINAR';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'nada acontece até alguém adicionar o outro';

  @override
  String get childPolicyScreenSendNowOnDesc => 'recebem o pedido de imediato';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'ENVIAR O PEDIDO AGORA';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'És o único adulto responsável por $name, por isso não podes simplesmente sair — adiciona primeiro outro adulto, ou usa uma destas opções.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'SAIR';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'Vais perder toda a visibilidade sobre a conta de $name — os seus pedidos, as suas pessoas, as suas salas. Os outros adultos continuam a cuidar de $name.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'PARAR DE SUPERVISIONAR';

  @override
  String get childPolicyScreenStopSupervisingHeadline =>
      'PARAR DE SUPERVISIONAR?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'não foi possível retirar — tenta outra vez';

  @override
  String get childPolicyScreenTakeBackLabel => 'RETIRAR';

  @override
  String get childPolicyScreenUsernameHint => 'nome de utilizador';

  @override
  String get childPolicyScreenYou => 'tu';

  @override
  String get roomContentScreenDefaultDocumentName => 'documento';

  @override
  String get roomContentScreenCouldntOpenFile =>
      'não foi possível abrir esse ficheiro';

  @override
  String get roomContentScreenCouldntShare => 'não foi possível partilhar isso';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links copiados',
      one: 'copiado',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ELIMINAR $count MENSAGENS',
      one: 'ELIMINAR MENSAGEM',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Isto remove-as para todos nesta sala. Não pode ser desfeito.';

  @override
  String get roomContentScreenDeleteForEveryone => 'ELIMINAR PARA TODOS';

  @override
  String get roomContentScreenCancelTooltip => 'Cancelar';

  @override
  String get roomContentScreenBackTooltip => 'Voltar';

  @override
  String get roomContentScreenSelectingLabel => 'A SELECIONAR';

  @override
  String get roomContentScreenSharedContentLabel => 'CONTEÚDO PARTILHADO';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '$count selecionado',
      zero: 'nada selecionado',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'SELECIONAR';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'TUDO';

  @override
  String get roomContentScreenEmptyMedia => 'ainda não há fotos nem vídeos';

  @override
  String get roomContentScreenEmptyFiles => 'ainda não há ficheiros';

  @override
  String get roomContentScreenEmptyVoice => 'ainda não há notas de voz';

  @override
  String get roomContentScreenEmptyLinks => 'ainda não há links';

  @override
  String get roomContentScreenEmptySaved =>
      'ainda não guardaste nada. mantém premida uma mensagem e escolhe GUARDAR.\n\no que guardas aqui é só teu — uma mensagem fixada é o que toda a sala vê.';

  @override
  String get roomContentScreenLoadFailed => 'não foi possível carregar isso';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Nota de voz de $name';
  }

  @override
  String get roomContentScreenForwardAction => 'REENCAMINHAR';

  @override
  String get roomContentScreenCopyAction => 'COPIAR';

  @override
  String get roomContentScreenSaveAction => 'GUARDAR';

  @override
  String get roomContentScreenShareAction => 'PARTILHAR';

  @override
  String get roomContentScreenInChatAction => 'NO CHAT';

  @override
  String get roomContentScreenDeleteAction => 'ELIMINAR';

  @override
  String get messageActionMenuReplyLabel => 'RESPONDER';

  @override
  String get messageActionMenuEditLabel => 'EDITAR';

  @override
  String get messageStampEditedLabel => 'editado';

  @override
  String get composerEditCardTitle => 'EDITAR MENSAGEM';

  @override
  String get spoilerRevealHint =>
      'Spoiler — ativar para revelar o texto oculto';

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
  String get linkConfirmSheetTitle => 'ABRIR ESTE LINK?';

  @override
  String get linkConfirmSheetOpenLabel => 'ABRIR LINK';

  @override
  String get linkConfirmSheetCancelLabel => 'CANCELAR';

  @override
  String get roomScreenEditExpiredSnack =>
      'Demasiado tarde para editar — as mensagens só podem ser editadas durante 15 minutos.';

  @override
  String get roomScreenEditFailedSnack =>
      'Não foi possível guardar a edição. Verifica a tua ligação e tenta novamente.';

  @override
  String get messageActionMenuForwardLabel => 'REENCAMINHAR';

  @override
  String get messageActionMenuViewThreadLabel => 'VER TÓPICO';

  @override
  String get messageActionMenuCopyLabel => 'COPIAR';

  @override
  String get messageActionMenuCopyNameLabel => 'COPIAR NOME';

  @override
  String get messageActionMenuPinLabel => 'FIXAR';

  @override
  String get messageActionMenuUnpinLabel => 'DESAFIXAR';

  @override
  String get messageActionMenuSelectLabel => 'SELECIONAR';

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
    return 'ATIVO — $name';
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
  String get callScreenStatusConnected => 'ligada';

  @override
  String get callScreenStatusEnded => 'chamada terminada';

  @override
  String get callScreenStatusFailed => 'chamada falhada';

  @override
  String get callScreenStatusSwitching => 'a mudar de dispositivo…';

  @override
  String get callScreenStatusMoved => 'transferida';

  @override
  String get callScreenStatusReconnecting => 'a reconectar…';

  @override
  String get callScreenPoorConnectionLabel => 'má ligação';

  @override
  String get callScreenWeakConnectionLabel => 'ligação fraca';

  @override
  String get callScreenControlUnmute => 'ativar som';

  @override
  String get callScreenControlMute => 'silenciar';

  @override
  String get callScreenControlCamOn => 'ligar câmara';

  @override
  String get callScreenControlCamOff => 'desligar câmara';

  @override
  String get callScreenControlFlip => 'virar';

  @override
  String get callScreenControlSpeaker => 'altifalante';

  @override
  String get callScreenControlEnd => 'terminar';

  @override
  String get linkPreviewCardLinkLabel => 'LINK';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name aceitou o teu pedido';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'esse pedido foi retirado';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'pedido recusado';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'bloqueaste este utilizador — desbloqueia primeiro.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'não estão a aceitar pedidos de amizade neste momento.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'não foi possível enviar. tenta outra vez.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => 'PEDIDO RECEBIDO';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'NOVO PEDIDO';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name quer começar uma conversa.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'manda umas linhas. podem aceitar ou recusar.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'nada aqui é permanente até ambos concordarem.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'TIPO DE SALA';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'EFÉMERA';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'NORMAL';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'DURAÇÃO';

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
      'sussurra uma primeira linha · opcional';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'adiciona uma primeira mensagem · opcional';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'sussurra · desvanece sozinho';

  @override
  String get friendRequestDraftScreenHintStartWith => 'algo para começar…';

  @override
  String get friendRequestDraftScreenApproveButton => 'APROVAR E ABRIR SALA';

  @override
  String get friendRequestDraftScreenDeclineButton => 'RECUSAR';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'CANCELAR PEDIDO';

  @override
  String get friendRequestDraftScreenAskGrownUpButton =>
      'PERGUNTAR A UM ADULTO';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'ENVIAR PEDIDO';

  @override
  String get discoverScreenTitle => 'descobre.';

  @override
  String get discoverScreenCaptionPeople => 'pessoas';

  @override
  String get discoverScreenCaptionRooms => 'salas';

  @override
  String get discoverScreenCaptionRequests => 'pedidos';

  @override
  String get discoverScreenPeopleBandLabel => 'PESSOAS';

  @override
  String get discoverScreenRoomsBandLabel => 'SALAS';

  @override
  String get discoverScreenFindPeopleTitle => 'encontrar pessoas';

  @override
  String get discoverScreenFindPeopleSubtitleChild =>
      'escreve o nome de utilizador completo';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'pesquisa por @utilizador ou nome';

  @override
  String get discoverScreenRequestsSectionLabel => 'PEDIDOS';

  @override
  String get discoverScreenInboxQuiet => 'caixa de entrada silenciosa';

  @override
  String get discoverScreenNothingPending => 'nada enviado';

  @override
  String get discoverScreenYourPeopleLabel => 'AS TUAS PESSOAS';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'ainda ninguém — encontra pessoas aí em cima';

  @override
  String get discoverScreenNoFriendsYet => 'ainda ninguém';

  @override
  String get discoverScreenSearchRoomsTitle => 'procurar salas';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'encontra uma sala pública pelo nome';

  @override
  String get discoverScreenPublicRoomsLabel => 'SALAS PÚBLICAS';

  @override
  String get discoverScreenLoadingRooms => 'a procurar…';

  @override
  String get discoverScreenNoRoomsOpen => 'nada aberto agora';

  @override
  String get discoverScreenIncomingLabel => 'recebidos';

  @override
  String get discoverScreenOutgoingLabel => 'enviados';

  @override
  String get discoverScreenIncomingLabelCaps => 'RECEBIDOS';

  @override
  String get discoverScreenOutgoingLabelCaps => 'ENVIADOS';

  @override
  String get discoverScreenJumpPeopleLabel => 'pessoas';

  @override
  String get discoverScreenJumpRoomsLabel => 'salas';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Ir para $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'ajustar';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'USAR FOTO';

  @override
  String get imageCropScreenSavingButton => 'A GUARDAR…';

  @override
  String get imageCropScreenCancelButton => 'CANCELAR';

  @override
  String get imageCropScreenHeicUnsupported =>
      'este navegador não consegue abrir fotos HEIC';

  @override
  String get imageCropScreenLoadFailed => 'não conseguimos abrir esta imagem';

  @override
  String get imageCropScreenHintCircle =>
      'arrasta para mover, belisca para ampliar';

  @override
  String get imageCropScreenHintRect => 'arrasta e belisca para enquadrar';

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
  String get searchScreenHintPeople => 'pesquisar pessoas…';

  @override
  String get searchScreenHintRooms => 'pesquisar salas…';

  @override
  String get searchScreenPeoplePromptChild =>
      'escreve o nome de utilizador completo para encontrares alguém novo';

  @override
  String get searchScreenPeoplePromptDefault =>
      'pesquisa por nome de utilizador ou nome';

  @override
  String get searchScreenNoMatchChild =>
      'ninguém encontrado — para pessoas novas é preciso\no nome de utilizador completo, escrito exatamente';

  @override
  String get searchScreenNoMatchDefault => 'ninguém encontrado';

  @override
  String get searchScreenNoRoomsYet => 'ainda não há salas públicas';

  @override
  String get searchScreenNoRoomsMatch => 'nenhuma sala pública corresponde';

  @override
  String get searchScreenActionAskToAdd => 'PEDIR PARA ADICIONAR';

  @override
  String get searchScreenActionSendRequest => 'ENVIAR PEDIDO';

  @override
  String get searchScreenActionCancel => 'CANCELAR';

  @override
  String get searchScreenActionApprove => 'APROVAR';

  @override
  String get searchScreenActionOpenDm => 'ABRIR DM';

  @override
  String get searchScreenAskedLabel => 'pedido';

  @override
  String get profileVisibilityScreenTitle => 'preferências de visibilidade.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'controla o que os outros veem — e como podem contactar-te.';

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
      'copiada — cola-a num sítio seguro';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'confirma\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'que és tu.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'A tua palavra-passe, para que mais ninguém possa adicionar uma frase de recuperação à tua conta.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'palavra-passe';

  @override
  String get recoveryPhraseScreenContinueButton => 'CONTINUAR';

  @override
  String get recoveryPhraseScreenNotNowLink => 'agora não';

  @override
  String get recoveryPhraseScreenEnterPasswordError =>
      'Introduz a tua palavra-passe.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'guarda\n';

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
      'agora não — manter a minha frase atual';

  @override
  String get homeScreenProfileSemanticLabel => 'O teu perfil';

  @override
  String homeScreenGreeting(Object name) {
    return 'olá, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'Nova sala';

  @override
  String get homeScreenEmptyRoomsMessage => 'ainda não tens salas — cria uma';

  @override
  String get groupCallScreenTitleVideo => 'Chamada de vídeo em grupo';

  @override
  String get groupCallScreenTitleVoice => 'Chamada de voz em grupo';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '$count na chamada';
  }

  @override
  String get groupCallScreenReconnecting => 'a reconectar…';

  @override
  String get groupCallScreenUnmuteLabel => 'ativar som';

  @override
  String get groupCallScreenMuteLabel => 'silenciar';

  @override
  String get groupCallScreenCamOnLabel => 'ligar câmara';

  @override
  String get groupCallScreenCamOffLabel => 'desligar câmara';

  @override
  String get groupCallScreenFlipLabel => 'virar';

  @override
  String get groupCallScreenSpeakerLabel => 'altifalante';

  @override
  String get groupCallScreenLeaveLabel => 'sair';

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
  String get roomFilterDrawerClearLabel => 'limpar';

  @override
  String get roomFilterDrawerDimensionType => 'TIPO';

  @override
  String get roomFilterDrawerDimensionNature => 'NATUREZA';

  @override
  String get roomFilterDrawerDimensionStatus => 'ESTADO';

  @override
  String get roomFilterDrawerPanelClear => 'LIMPAR';

  @override
  String get roomFilterDrawerPanelDone => 'CONCLUÍDO';

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
    return 'nada corresponde a $summary';
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
      other: 'mostrar todas as $count conversas',
      one: 'mostrar a $count conversa',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'nova sala';

  @override
  String get createRoomSheetTaglineSecret => 'NADA SERÁ GUARDADO';

  @override
  String get createRoomSheetTaglineRegular => 'UM ESPAÇO QUE FICA';

  @override
  String get createRoomSheetNameLabel => 'NOME';

  @override
  String get createRoomSheetNameHint => 'dá-lhe um nome honesto…';

  @override
  String get createRoomSheetDescriptionLabel => 'DESCRIÇÃO · OPCIONAL';

  @override
  String get createRoomSheetDescriptionHint => 'uma linha sobre a sala…';

  @override
  String get createRoomSheetVisibilityLabel => 'VISIBILIDADE';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'pública';

  @override
  String get createRoomSheetVisibilityPublicSub =>
      'toda a gente a pode encontrar';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'privada';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'só com convite';

  @override
  String get createRoomSheetTypeLabel => 'TIPO';

  @override
  String get createRoomSheetTypeStandardTitle => 'padrão';

  @override
  String get createRoomSheetTypeStandardSub => 'mensagens persistem';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'efémera';

  @override
  String get createRoomSheetTypeEphemeralSub => 'autoapagam-se';

  @override
  String get createRoomSheetMessageLifeLabel => 'VIDA DA MENSAGEM';

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
  String get createRoomSheetPasswordLabel => 'PALAVRA-PASSE · OPCIONAL';

  @override
  String get createRoomSheetPasswordHint => 'tranca-a com uma frase-passe…';

  @override
  String get createRoomSheetNameRequiredError => 'o nome é obrigatório';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Abrir a sala';

  @override
  String get createRoomSheetOpenRoomButton => 'ABRIR A SALA';

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
  String get reactionDetailsSheetTitle => 'REAÇÕES';

  @override
  String get reactionDetailsSheetEmptyState => 'já não há nada aqui';

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
  String get reactionDetailsSheetFilterAll => 'TODOS';

  @override
  String get reactionDetailsSheetYouBadge => 'TU';

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
  String get audioMessageUnavailableLabel => 'áudio indisponível';

  @override
  String get audioMessageRetryHint => 'toca para tentar novamente';

  @override
  String get audioMessageLoadingLabel => 'a carregar…';

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
  String get audioMessageUsernameHint => 'nome de utilizador';

  @override
  String get audioMessageDisplayNameHint => 'nome a apresentar (opcional)';

  @override
  String get audioMessagePasswordHint => 'palavra-passe';

  @override
  String get audioMessageSwitchToLinkPrompt => 'Esse é o meu — iniciar sessão';

  @override
  String get audioMessageCreateAccountButton => 'CRIAR CONTA';

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
      'não foi possível guardar — tenta novamente';

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
  String get approvalsScreenForwardDirectMessageFallback => 'mensagem direta';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ENCAMINHAR $count MENSAGENS',
      one: 'ENCAMINHAR MENSAGEM',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'ainda sem outras conversas';

  @override
  String get approvalsScreenForwardNoMatches => 'nada corresponde';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'até $max conversas de cada vez';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'procurar conversas';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Desmarcar $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Selecionar $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'DESVANECE';

  @override
  String get approvalsScreenForwardSendSemantic => 'Enviar';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ENVIAR PARA $count',
      zero: 'ENVIAR',
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
  String get linkedAccountsScreenCallSheetVoiceLabel => 'VOZ';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'VÍDEO';

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
  String get childPairScreenAccountGoneError => 'Essa conta já não existe.';

  @override
  String get childPairScreenScanButtonLabel => 'DIGITALIZA O CÓDIGO DELE';

  @override
  String get childPairScreenNoCameraMessage =>
      'Sem câmara aqui — escreve os seis números em vez disso.';

  @override
  String get childPairScreenStopScanning => 'parar de digitalizar';

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
      'A mostrar parte deste ficheiro — transfira-o para ver o resto.';

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
  String get fileMessageStandardBadge => 'PADRÃO';

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
  String get fileMessageApproveButton => 'APROVAR';

  @override
  String get fileMessageDeclineButton => 'RECUSAR';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'ENVIADO $ago';
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
  String get fileMessageCancelRequestButton => 'CANCELAR PEDIDO';

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
      'Não foi possível criar um código — tenta outra vez.';

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
    return 'No telemóvel de $name, abre o MonkeyHub e digitaliza isto — ou escreve os números.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'este código expirou';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'expira em $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'NOVO CÓDIGO';

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
  String get deepOceanThemeEphemeralHint =>
      'sussurra algo que o servidor vai esquecer…';

  @override
  String get deepOceanThemeDefaultHint => 'diz alguma coisa…';

  @override
  String get deepOceanThemeMessageHint => 'Mensagem';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'este ficheiro desapareceu';

  @override
  String get photoChromeMediaYouLabel => 'tu';

  @override
  String get photoChromeCloseSemanticLabel => 'Fechar';

  @override
  String get photoChromeShowInChatSemanticLabel => 'Mostrar na conversa';

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
  String get typingIndicatorUnknownCallerFallbackName => 'chamada a receber';

  @override
  String get typingIndicatorIncomingVideoCallLabel =>
      'CHAMADA DE VÍDEO A RECEBER';

  @override
  String get typingIndicatorIncomingVoiceCallLabel =>
      'CHAMADA DE VOZ A RECEBER';

  @override
  String get typingIndicatorDeclineButtonLabel => 'recusar';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'a recusar…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'aceitar';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'a ligar…';

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
      'permissão do microfone negada';

  @override
  String get voiceRecorderScreenStatusRecording => 'A GRAVAR';

  @override
  String get voiceRecorderScreenStatusReady => 'PRONTO';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'TOCA PARA COMEÇAR';

  @override
  String get voiceRecorderScreenReRecordButton => 'REGRAVAR';

  @override
  String get voiceRecorderScreenStopButton => 'PARAR';

  @override
  String get voiceRecorderScreenSendButton => 'ENVIAR';

  @override
  String get voiceRecorderScreenRecordButton => 'GRAVAR';

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
    return 'Isto termina a sessão de $name neste telemóvel e devolve-o — o telemóvel volta ao ecrã de início de sessão normal e qualquer pessoa pode usá-lo.';
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
  String get activeCallPillPinnedHeader => 'FIXADAS';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'FIXADAS · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'já não há nada fixado';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Ir para a mensagem de $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Desafixar mensagem de $name';
  }

  @override
  String get callButtonErrorBusy => 'ocupado noutra chamada';

  @override
  String get callButtonErrorCallFailed => 'não foi possível iniciar a chamada';

  @override
  String get callButtonErrorNotMember => 'não és membro desta sala';

  @override
  String get callButtonErrorGeneric => 'não foi possível iniciar a chamada';

  @override
  String get callButtonAlreadyOnCall => 'Já estás numa chamada';

  @override
  String get callButtonBusyElsewhere => 'Chamada em curso noutro dispositivo';

  @override
  String get callButtonVoiceCallTooltip => 'chamada de voz';

  @override
  String get callButtonVideoCallTooltip => 'videochamada';

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
      'pílula de citação com cor de destaque, barra de ligação e avatar — o visual clássico ao estilo WhatsApp.';

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
      'Não foi possível criar a conta — tenta outra vez.';

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
      'Todos os outros precisam primeiro da tua aprovação — tanto quando é ele(a) a pedir alguém, como quando alguém pede por ele(a).';

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
  String get childSetupScreenWaitingPillAskedLabel => 'pedido';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'MEMBROS';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'ver tudo ($count)';
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
      'sem ponta — uma sequência mantém-se coesa apenas pelos cantos interiores mais apertados.';

  @override
  String get bubbleStyleScreenPillLabel => 'CÁPSULA';

  @override
  String get bubbleStyleScreenPillDescription =>
      'cápsulas totalmente arredondadas, idênticas em cada linha.';

  @override
  String get bubbleStyleScreenSlabLabel => 'BLOCO';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'ombros quadrados — afiados, impressos, deliberados.';

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
      'última mensagem agora mesmo';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'última mensagem há ${hours}h';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'última mensagem ontem';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'última mensagem há $days dias';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'última mensagem há algum tempo';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'RETIRAR';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return 'afastar $contactName de $childName?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'deixam de se conseguir contactar, e a conversa entre os dois desaparece com isso.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'deixam de se conseguir contactar. $contactName não fica a saber.';
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
      'desaparece para os dois, incluindo fotos e notas de voz. isto não pode ser desfeito.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'também partilham $count salas',
      one: 'também partilham $count sala',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'estas ficam. retira a sala da lista de SALAS abaixo se as quiseres fora dela.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'RETIRAR E APAGAR';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'remove $contactName e apaga $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'remove $contactName da lista de permitidos.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Cancelar';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton =>
      'CANCELAR';

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
  String get groupCallBannerJoinButtonLabel => 'ENTRAR';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'ENTRAR NA SALA';

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
  String get groupCallBannerPasswordFieldLabel => 'PALAVRA-PASSE';

  @override
  String get groupCallBannerPasswordHint => 'frase secreta…';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Entrar';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'ENTRAR';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Cancelar';

  @override
  String get groupCallBannerCancelButtonLabel => 'cancelar';

  @override
  String get viewOnceViewerBadgeLabel => 'VER UMA VEZ';

  @override
  String get socialButtonDividerOr => 'ou';

  @override
  String get socialButtonGoogleContinue => 'Continuar com o Google';

  @override
  String get discoverListsPeopleTitle => 'as tuas pessoas.';

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
  String get discoverListsFilterHint => 'filtra as tuas pessoas…';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Limpar filtro';

  @override
  String get discoverListsNoOneYet => 'ainda ninguém';

  @override
  String discoverListsNoMatches(Object query) {
    return 'ninguém corresponde a \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'CHAMADA DE VOZ';

  @override
  String get discoverListsVideoCallLabel => 'CHAMADA DE VÍDEO';

  @override
  String get approvalGateAlreadyAskedLabel => 'JÁ PEDIDO';

  @override
  String get approvalGateAskGrownUpLabel => 'PERGUNTA A UM CRESCIDO';

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
  String get approvalGateAskButton => 'PERGUNTAR';

  @override
  String get approvalGateNotNowButton => 'AGORA NÃO';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => 'à espera de um crescido';

  @override
  String get reportSheetTitle => 'DENÚNCIA';

  @override
  String get reportSheetSubtitle => 'diz-nos o que se passa.';

  @override
  String get reportSheetPrivacyNote =>
      'as denúncias são privadas — a outra pessoa não é notificada.';

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
  String get reportSheetUpdateRequiredTitle => 'ATUALIZAÇÃO OBRIGATÓRIA';

  @override
  String get reportSheetUpdateAvailableTitle => 'ATUALIZAÇÃO DISPONÍVEL';

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
  String get reportSheetUpdateButtonTitle => 'ATUALIZAR';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'abre o TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'abre a App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'abre a Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'abre a página de transferência';

  @override
  String get reportSheetUpdateActionReloads => 'recarrega com a nova versão';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Mais tarde';

  @override
  String get reportSheetUpdateLaterButton => 'MAIS TARDE';

  @override
  String get roomFilterBarAllChipLabel => 'tudo';

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
    return 'A RESPONDER A $name';
  }

  @override
  String get roomCardLockedBadge => 'BLOQUEADA';

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
    return 'criada há $ago';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count dentro';
  }

  @override
  String get roomCardMessagesFadeLabel => 'mensagens desaparecem';

  @override
  String get roomCardEnterLabel => '↗ entrar';

  @override
  String get roomCardBlockedScreenTitle => 'BLOQUEADOS';

  @override
  String get roomCardBlockedEmptyState => 'ainda não bloqueaste ninguém.';

  @override
  String get roomCardUnblockButton => 'DESBLOQUEAR';

  @override
  String get attachmentMenuPhotoLabel => 'foto';

  @override
  String get attachmentMenuVideoLabel => 'vídeo';

  @override
  String get attachmentMenuCameraLabel => 'câmara';

  @override
  String get attachmentMenuVoiceLabel => 'voz';

  @override
  String get attachmentMenuFileLabel => 'ficheiro';

  @override
  String get attachmentMenuConnectionRetrying => 'a tentar novamente…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'não é possível contactar o servidor · toca para tentar novamente';

  @override
  String get attachmentMenuConnectionReconnecting => 'a ligar novamente…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Tentar ligar novamente';

  @override
  String get roomGridTileEmptyLastMessage => 'sossegado por agora';

  @override
  String get roomGridTileMemberCountLabel => 'DENTRO';

  @override
  String get roomGridTileThemeChipLabel => 'TEMA';

  @override
  String get bulkActionBarCancelLabel => 'CANCELAR';

  @override
  String get bulkActionBarSelectMessagesLabel => 'SELECIONAR MENSAGENS';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count SELECIONADAS';
  }

  @override
  String get bulkActionBarForwardLabel => 'REENCAMINHAR';

  @override
  String get bulkActionBarDeleteLabel => 'ELIMINAR';

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
  String get bulkActionBarBlockSheetNotNotifiedNote => 'não fica a saber.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'vocês são amigos atualmente — bloquear remove a amizade, por isso, para voltarem a falar mais tarde, terias de enviar um novo pedido de amizade.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'desaparece das tuas pesquisas e não te pode enviar mensagens.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'BLOQUEAR';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return 'bloquear $name?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'partilhas $count salas com essa pessoa',
      one: 'partilhas $count sala com essa pessoa',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'estas salas não são afetadas. podes sair de qualquer uma delas nas definições de cada sala.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'BLOQUEAR';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'remove a amizade e bloqueia. o histórico de conversa existente fica no teu arquivo.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'desaparece da pesquisa e não te consegue contactar.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'BLOQUEAR E ELIMINAR DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'também elimina a tua DM com essa pessoa — todas as mensagens, reações e ficheiros multimédia desaparecem.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Cancelar';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'CANCELAR';

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
  String get reactionBubblePickerTitle => 'REAGIR';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'ainda sem recentes';

  @override
  String get reactionBubbleSearchHint => 'procurar emoji';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'sem correspondências';

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
      'não foi possível pedir agora — tenta outra vez';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'palavra-passe errada';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'não foi possível entrar — tenta novamente';

  @override
  String get feedBoardTitle => 'HOJE';

  @override
  String feedBoardEditionLabel(Object number) {
    return 'N.º$number';
  }

  @override
  String get feedBoardHighlightsLabel => 'DESTAQUES';

  @override
  String get feedBoardHighlightsEmpty => 'ainda não há nada capturado hoje';

  @override
  String get feedBoardPuzzleLabel => 'O ENIGMA';

  @override
  String get feedBoardPuzzleEmpty => 'o enigma de hoje ainda não está pronto';

  @override
  String get feedBoardStandingsLabel => 'PONTOS DE VIDA';

  @override
  String get feedBoardStandingsEmpty => 'nenhum ponto no quadro hoje';

  @override
  String get feedBoardActivityLabel => 'ATIVIDADE';

  @override
  String get feedBoardActivityEmpty => 'hoje está calmo por enquanto';

  @override
  String get feedBoardActivityNoFriends =>
      'adiciona um amigo e o dia dele aparece aqui';

  @override
  String get feedBoardLoadFailed =>
      'não foi possível carregar o quadro — tenta daqui a pouco';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'PÚBLICA';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'PRIVADA';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'JÁ ENTRASTE';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'EFÉMERA · $duration';
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
      'Apenas por convite — não aparece em Descobre';

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
  String get roomInfoSheetNoDescription => 'ainda sem descrição';

  @override
  String get roomInfoSheetCreatedLabel => 'CRIADA EM';

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
      'sem frase de recuperação — podes não conseguir voltar a entrar.';

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
  String get roomContentTabLabelMedia => 'MULTIMÉDIA';

  @override
  String get roomContentTabLabelFiles => 'FICHEIROS';

  @override
  String get roomContentTabLabelVoice => 'VOZ';

  @override
  String get roomContentTabLabelLinks => 'LIGAÇÕES';

  @override
  String get roomContentTabLabelSaved => 'GUARDADAS';

  @override
  String get roomContentTabHeaderMedia => 'multimédia';

  @override
  String get roomContentTabHeaderFiles => 'ficheiros';

  @override
  String get roomContentTabHeaderVoice => 'voz';

  @override
  String get roomContentTabHeaderLinks => 'ligações';

  @override
  String get roomContentTabHeaderSaved => 'guardadas';

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
      'Diga-nos o que correu mal. Os dados da app e do seu dispositivo são incluídos automaticamente, juntamente com um registo técnico do que a app estava a fazer — é isso que nos ajuda a encontrar a causa.';

  @override
  String get reportProblemDescribeLabel => 'O QUE ACONTECEU';

  @override
  String get reportProblemDescribeHint =>
      'O ecrã tremeluz, os botões não respondem…';

  @override
  String get reportProblemScreenshotsLabel => 'CAPTURAS DE ECRÃ';

  @override
  String get reportProblemAddScreenshot => 'Adicionar captura de ecrã';

  @override
  String get reportProblemDetailsLabel => 'OS SEUS DADOS';

  @override
  String get reportProblemCopyDetails => 'Copiar dados';

  @override
  String get reportProblemCopied => 'Copiado';

  @override
  String get reportProblemSend => 'Enviar relatório';

  @override
  String get reportProblemSent => 'Relatório enviado — obrigado!';

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
      'apenas pré-visualização — balões mais limpos, toca para abrir';

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
      'Full HD — mais nítido, usa mais dados';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD — melhor numa ligação forte';

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
      'silencioso — só vês tudo quando abres a app';

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
      'Essa é uma conta de criança — pede a um crescido um código de emparelhamento.';

  @override
  String get authErrorPairingCodeExpired =>
      'Esse código expirou. Pede um novo.';

  @override
  String get authErrorPairingCodeInvalid =>
      'Esse código não funcionou. Pode já ter sido usado.';

  @override
  String get authErrorUseSocialSignIn =>
      'Essa conta inicia sessão com a Apple ou a Google — usa os botões abaixo.';

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
  String get glassKnobLabelFrost => 'FOSCO';

  @override
  String get glassKnobHintFrost =>
      'quanto branco fica sobre o vidro. desce para ficar transparente';

  @override
  String get glassKnobLabelBlur => 'DESFOQUE';

  @override
  String get glassKnobHintBlur =>
      'fosco no topo do intervalo, vidro transparente no fundo';

  @override
  String get glassKnobLabelSaturation => 'SANGRIA DE COR';

  @override
  String get glassKnobHintSaturation =>
      'quanta cor sobrevive ao desfoque. depois de 2, começa a posterizar';

  @override
  String get glassKnobLabelRimOpacity => 'ORLA';

  @override
  String get glassKnobHintRimOpacity =>
      'o contorno de destaque. zero para uma superfície sem orla';

  @override
  String get glassKnobLabelRimWidth => 'LARGURA DA ORLA';

  @override
  String get glassKnobHintRimWidth => 'espessura dessa orla';

  @override
  String get glassKnobLabelShadowOpacity => 'SOMBRA';

  @override
  String get glassKnobHintShadowOpacity =>
      'a que distância a superfície flutua acima do que está por trás';

  @override
  String get glassKnobLabelShadowBlur => 'DIFUSÃO DA SOMBRA';

  @override
  String get glassKnobHintShadowBlur => 'suave e larga, ou apertada e dura';

  @override
  String get glassKnobLabelShadowY => 'QUEDA DA SOMBRA';

  @override
  String get glassKnobHintShadowY => 'a que distância abaixo da superfície cai';

  @override
  String get glassKnobLabelBarMargin => 'MARGEM LATERAL';

  @override
  String get glassKnobHintBarMargin => 'espaço entre a barra e a borda do ecrã';

  @override
  String get glassKnobLabelBarBottom => 'ESPAÇO INFERIOR';

  @override
  String get glassKnobHintBarBottom =>
      'a que altura a barra flutua acima da base';

  @override
  String get glassKnobLabelShellPadH => 'ESPAÇAMENTO DAS PONTAS';

  @override
  String get glassKnobHintShellPadH =>
      'da borda da barra até à primeira cápsula. mantém pequeno, ou as pontas ficam isoladas';

  @override
  String get glassKnobLabelShellPadV => 'ESPAÇAMENTO SUPERIOR';

  @override
  String get glassKnobHintShellPadV =>
      'da borda da barra até ao topo da cápsula';

  @override
  String get glassKnobLabelIndicatorInset => 'RECUO DA CÁPSULA';

  @override
  String get glassKnobHintIndicatorInset =>
      'a que distância a cápsula de seleção fica dentro do seu compartimento';

  @override
  String get glassKnobLabelSegmentPadV => 'ESPAÇAMENTO DA LINHA';

  @override
  String get glassKnobHintSegmentPadV =>
      'espaço acima e abaixo do ícone e da sua etiqueta';

  @override
  String get glassKnobLabelIconLabelGap => 'ESPAÇO DO ÍCONE';

  @override
  String get glassKnobHintIconLabelGap =>
      'espaço entre um ícone e a palavra por baixo dele';

  @override
  String get glassKnobLabelIconSize => 'TAMANHO DO ÍCONE';

  @override
  String get glassKnobLabelLabelSize => 'TAMANHO DA ETIQUETA';

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
      'Igual ao dispositivo · completo';

  @override
  String get settingsScreenValueMotionSystemCalm =>
      'Igual ao dispositivo · calmo';

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
  String get motionScreenCalmSubtitle => 'a decoração para — mais nada muda';

  @override
  String get momentRailCaptureLabel => 'CAPTURAR';

  @override
  String get momentRailYouLabel => 'tu';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String get momentTagFate => 'DESTINO';

  @override
  String get momentTagJinx => 'AZAR';

  @override
  String get momentTagLuck => 'SORTE';

  @override
  String get momentTagCalledIt => 'EU AVISEI';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'que coincidência';

  @override
  String get momentTagJinxHint => 'foste tu que provocaste';

  @override
  String get momentTagLuckHint => 'correu a teu favor';

  @override
  String get momentTagCalledItHint => 'viste isso a chegar';

  @override
  String get momentTagNpcHint => 'cérebro desligado';

  @override
  String get momentComposerTitle => 'o que aconteceu?';

  @override
  String get momentComposerCaptionHint => 'diz alguma coisa';

  @override
  String get momentComposerTagPrompt => 'ganhaste um ponto? adiciona já';

  @override
  String get momentComposerCapture => 'câmara';

  @override
  String get momentComposerLibrary => 'galeria';

  @override
  String get momentComposerRemovePhoto => 'remover foto';

  @override
  String get momentComposerPost => 'PUBLICAR';

  @override
  String get momentComposerErrorDailyCap =>
      'já vão cinco hoje — guarda para amanhã';

  @override
  String get momentComposerErrorNotAllowed =>
      'um responsável desativou a partilha de fotos';

  @override
  String get momentComposerErrorTooLong => 'ficou um pouco longo — encurta';

  @override
  String get momentComposerErrorEmpty => 'adiciona uma foto ou umas palavras';

  @override
  String get momentComposerErrorGeneric =>
      'não foi possível publicar — tenta de novo';

  @override
  String get momentViewerDelete => 'eliminar';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who publicou um momento';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name levou um $tag';
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
  String momentActivityMoreCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count hoje',
      one: 'mais 1 hoje',
    );
    return '$_temp0';
  }

  @override
  String get puzzleScreenTitle => 'o enigma.';

  @override
  String get puzzleScreenSubtitle => 'quatro símbolos, seis tentativas';

  @override
  String get puzzleSubmit => 'ADIVINHAR';

  @override
  String get puzzleBackspace => 'apagar último símbolo';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'símbolo $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'resolvido em $count';
  }

  @override
  String get puzzleFailedTitle => 'sem tentativas';

  @override
  String get puzzleAnswerWas => 'O CÓDIGO ERA';

  @override
  String get puzzleShare => 'COPIAR RESULTADO';

  @override
  String get puzzleShareCopied => 'copiado — envia a um amigo';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'já resolveste o de hoje';

  @override
  String get puzzleErrorOutOfGuesses => 'não tens tentativas hoje';

  @override
  String get puzzleErrorGeneric => 'não foi possível enviar — tenta de novo';

  @override
  String get puzzleScoreboardLabel => 'PONTUAÇÕES DE HOJE';

  @override
  String get puzzleScoreboardEmpty => 'ainda ninguém terminou hoje';

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
      'hoje é sempre partilhado com os amigos — isto abre tudo o que veio antes';

  @override
  String get momentComposerVideo => 'vídeo';

  @override
  String get momentComposerErrorTooBig =>
      'esse vídeo é muito grande — máximo 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => 'publicaste um momento';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'levaste um $tag';
  }

  @override
  String pointLineSelf(Object tag) {
    return 'tu · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'o que aconteceu?';

  @override
  String get pointComposerNoteHint => 'escolhe uma acima e conta';

  @override
  String get pointComposerAdd => 'ADICIONAR PONTO';

  @override
  String get pointComposerAddPhoto => 'adicionar foto';

  @override
  String get pointsBoardAdd => 'ADICIONAR UM PONTO';

  @override
  String get pointsExplainerOpen => 'o que é isto?';

  @override
  String get pointsExplainerTitle => 'o jogo dos pontos';

  @override
  String get pointsExplainerIntro =>
      'Uma piada recorrente com marcador. Quando te acontece algo — bom, mau ou só estranho — registas e fica no quadro nesse dia.';

  @override
  String get pointsExplainerRuleHonour =>
      'Os pontos dás-te a ti próprio. Ninguém verifica — é essa a graça, e os teus amigos dizem-te se estiveres a exagerar.';

  @override
  String get pointsExplainerRuleToday =>
      'Os pontos reiniciam todos os dias. O quadro mostra hoje; o teu histórico é teu.';

  @override
  String get pointsExplainerRuleCap =>
      'Cinco de cada tipo por dia, para ninguém transformar o quadro num disparate.';

  @override
  String get pointsExplainerGotIt => 'PERCEBI';

  @override
  String get momentTagFateExample => 'encontrei o meu dentista noutro país';

  @override
  String get momentTagJinxExample => 'lavei o carro e choveu às quatro';

  @override
  String get momentTagLuckExample => 'apanhei o comboio por dois segundos';

  @override
  String get momentTagCalledItExample =>
      'disse que a sequela ia falhar, e falhou';

  @override
  String get momentTagNpcExample => 'disse ‘igualmente’ ao empregado';

  @override
  String feedBoardEditionHint(Object number) {
    return 'dia $number do feed';
  }

  @override
  String get feedBoardHighlightsHint => 'fotos e vídeos que valem uma olhada';

  @override
  String get profileVisibilityScreenPointsLabel => 'os meus pontos';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'se os pontos que registas aparecem nos quadros dos teus amigos';

  @override
  String get momentComposerEditPhoto => 'editar recorte';

  @override
  String get archiveScreenTitle => 'o teu arquivo';

  @override
  String get archiveScreenEnd => 'é tudo';

  @override
  String get archiveScreenEmptyTitle => 'ainda não guardaste nada';

  @override
  String get archiveScreenEmptyBody =>
      'os momentos saem dos quadros dos teus amigos ao fim de um dia, mas ficam aqui para ti.';

  @override
  String get archiveScreenEmptyFriendTitle => 'não há nada aqui';

  @override
  String get archiveScreenEmptyFriendBody =>
      'ainda não publicou nada que possas ver.';

  @override
  String get archiveScreenPrivateTitle => 'o passado é privado';

  @override
  String get archiveScreenPrivateBody =>
      'podes na mesma ver o que publicar hoje.';

  @override
  String get archiveScreenNotFriendTitle => 'não são amigos';

  @override
  String get archiveScreenNotFriendBody =>
      'só podes recuar nos dias de um amigo.';

  @override
  String get archiveScreenErrorTitle => 'não foi possível carregar';

  @override
  String get archiveScreenErrorBody => 'verifica a ligação e tenta de novo.';

  @override
  String get feedBoardOpenArchive => 'arquivo';

  @override
  String get feedBoardGamesLabel => 'OS JOGOS';

  @override
  String get feedBoardGamesOpen => 'todos os jogos';

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
  String get gamesLoadFailed => 'não foi possível carregar os jogos de hoje';

  @override
  String get gamesRetry => 'TENTAR DE NOVO';

  @override
  String get gameQueensName => 'rainhas';

  @override
  String get gameQueensRule =>
      'uma coroa por linha, coluna e cor — sem se tocarem';

  @override
  String get gameTangoName => 'tango';

  @override
  String get gameTangoRule => 'três sóis, três luas, nunca três seguidos';

  @override
  String get gameZipName => 'zip';

  @override
  String get gameZipRule =>
      'uma linha por todos os quadrados, números por ordem';

  @override
  String get gameSudokuName => 'mini sudoku';

  @override
  String get gameSudokuRule => 'de 1 a 6 uma vez por linha, coluna e caixa';

  @override
  String get gameCodeName => 'o código';

  @override
  String get gameStatusUnplayed => 'por jogar';

  @override
  String get gameStatusUnfinished => 'a decorrer';

  @override
  String get gameStatusGaveUp => 'desistiu';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'pausa';

  @override
  String get gameResume => 'continuar';

  @override
  String get gamePausedTitle => 'em pausa';

  @override
  String get gamePausedBody => 'o relógio está parado e o tabuleiro escondido';

  @override
  String get gameUndo => 'desfazer';

  @override
  String get gameClear => 'limpar';

  @override
  String get gameHint => 'dica';

  @override
  String get gameNotes => 'notas';

  @override
  String get gameErase => 'apagar';

  @override
  String get gameAutoCross => 'cruzes automáticas';

  @override
  String get gameGiveUp => 'desistir';

  @override
  String get gameGiveUpTitle => 'mostrar a solução?';

  @override
  String get gameGiveUpBody =>
      'o tabuleiro de hoje fecha e fica como não resolvido.';

  @override
  String get gameGiveUpCancel => 'CONTINUAR';

  @override
  String get gameGiveUpConfirm => 'MOSTRAR';

  @override
  String gameSolvedTitle(Object time) {
    return 'resolvido em $time';
  }

  @override
  String get gameGaveUpTitle => 'a solução de hoje';

  @override
  String get gameFirstInToday => 'o primeiro de hoje';

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
  String get gameStandingsLabel => 'TEMPOS DE HOJE';

  @override
  String get gameStandingsEmpty => 'ainda ninguém terminou este';

  @override
  String get gameShare => 'COPIAR RESULTADO';

  @override
  String get gameShareCopied => 'copiado — cola para um amigo';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => 'todos os jogos';

  @override
  String get gameElapsedSemantic => 'tempo decorrido';

  @override
  String get gameErrorNotSolved => 'esse tabuleiro ainda não está terminado';

  @override
  String get gameErrorAlreadyFinished => 'já terminaste o de hoje';

  @override
  String get gameErrorNoHint => 'este não tem dicas';

  @override
  String get gameErrorGeneric =>
      'não foi possível chegar aos jogos — tenta de novo';

  @override
  String get gameInfoOpen => 'como se joga';

  @override
  String get gameInfoLabel => 'COMO SE JOGA';

  @override
  String get gameInfoRulesLabel => 'AS REGRAS';

  @override
  String get gameInfoControlsLabel => 'CONTROLOS';

  @override
  String get gameInfoScoringTimed =>
      'o relógio corre enquanto o tabuleiro está no ecrã e para se pausares ou saíres. quem for mais rápido lidera a lista de hoje.';

  @override
  String get gameInfoScoringGuesses =>
      'a pontuação é pelo número de tentativas, não pelo tempo.';

  @override
  String get gameInfoSameForEveryone =>
      'hoje toda a gente joga o mesmo tabuleiro.';

  @override
  String get gameInfoGotIt => 'ENTENDI';

  @override
  String get gameInfoQueensGoal =>
      'coloca uma coroa em cada linha, coluna e cor.';

  @override
  String get gameInfoQueensRule1 =>
      'oito coroas: uma em cada linha e uma em cada coluna.';

  @override
  String get gameInfoQueensRule2 =>
      'cada bloco de cor leva também exatamente uma coroa.';

  @override
  String get gameInfoQueensRule3 =>
      'duas coroas não podem tocar-se, nem sequer por um canto.';

  @override
  String get gameInfoQueensControls =>
      'toca numa casa uma vez para uma cruz que a descarta, outra vez para uma coroa e outra para limpar.';

  @override
  String get gameInfoTangoGoal => 'preenche a grelha com sóis e luas.';

  @override
  String get gameInfoTangoRule1 =>
      'cada linha e coluna leva três sóis e três luas.';

  @override
  String get gameInfoTangoRule2 =>
      'nunca três iguais seguidos, na horizontal ou na vertical.';

  @override
  String get gameInfoTangoRule3 =>
      'um = entre duas casas significa que são iguais; um × que são diferentes.';

  @override
  String get gameInfoTangoControls =>
      'toca numa casa para um sol, outra vez para uma lua e outra para limpar. as casas impressas não mudam.';

  @override
  String get gameInfoZipGoal =>
      'desenha uma linha que passe por todos os quadrados.';

  @override
  String get gameInfoZipRule1 => 'começa no 1 e acaba no último número.';

  @override
  String get gameInfoZipRule2 =>
      'passa pelos números por ordem ao longo do caminho.';

  @override
  String get gameInfoZipRule3 => 'cada quadrado é usado exatamente uma vez.';

  @override
  String get gameInfoZipControls =>
      'arrasta o dedo para desenhar. volta por cima da linha para a apagar.';

  @override
  String get gameInfoSudokuGoal =>
      'preenche a grelha com os algarismos de 1 a 6.';

  @override
  String get gameInfoSudokuRule1 => 'cada linha usa de 1 a 6, uma vez cada.';

  @override
  String get gameInfoSudokuRule2 => 'cada coluna, igual.';

  @override
  String get gameInfoSudokuRule3 => 'e cada caixa de 2x3, também.';

  @override
  String get gameInfoSudokuControls =>
      'toca numa casa e depois num algarismo. toca no mesmo algarismo outra vez para apagar. o modo notas escreve marcas pequenas a lápis.';

  @override
  String get gameInfoCodeGoal =>
      'descobre o código escondido de quatro símbolos.';

  @override
  String get gameInfoCodeRule1 =>
      'seis tentativas, e o código nunca repete um símbolo.';

  @override
  String get gameInfoCodeRule2 =>
      'verde significa símbolo certo no lugar certo.';

  @override
  String get gameInfoCodeRule3 =>
      'amarelo significa símbolo certo no lugar errado.';

  @override
  String get gameInfoCodeControls =>
      'toca em símbolos para formar uma tentativa e envia-a. o tabuleiro diz-te quão perto estiveste.';

  @override
  String get savedMessagesTitle => 'Mensagens guardadas';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'nenhuma conversa corresponde a \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'pesquisar conversas…';

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
  String get archivedChatsSheetTitle => 'CONVERSAS ARQUIVADAS';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'CONVERSAS ARQUIVADAS · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'já não há nada arquivado';

  @override
  String get pinnedBadgeLabel => 'FIXADA';

  @override
  String get chatRowActionMenuPinLabel => 'FIXAR CONVERSA';

  @override
  String get chatRowActionMenuUnpinLabel => 'DESAFIXAR CONVERSA';

  @override
  String get chatRowActionMenuArchiveLabel => 'ARQUIVAR CONVERSA';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'DESARQUIVAR CONVERSA';

  @override
  String get messageActionMenuSaveLabel => 'GUARDAR';

  @override
  String get messageActionMenuUnsaveLabel => 'REMOVER';

  @override
  String get roomScreenSaveLimitSnack =>
      'demasiadas mensagens guardadas aqui — remove uma primeiro';

  @override
  String get roomScreenSaveFailedSnack =>
      'não foi possível guardar essa mensagem';

  @override
  String get threadOverlaySaveLimitToast =>
      'demasiadas mensagens guardadas aqui — remove uma primeiro';

  @override
  String get threadOverlaySaveFailedToast =>
      'não foi possível guardar essa mensagem';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'só tu vês as mensagens que guardas — uma mensagem fixada é o oposto: toda a sala a vê.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return 'Ir para a mensagem guardada de $name';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return 'Remover dos guardados a mensagem de $name';
  }

  @override
  String get muteSheetTitle => 'SILENCIAR CONVERSA';

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
  String get muteSheetDurationLabel => 'DURANTE QUANTO TEMPO';

  @override
  String get muteDurationHour => '1 hora';

  @override
  String get muteDurationEightHours => '8 horas';

  @override
  String get muteDurationWeek => '1 semana';

  @override
  String get muteDurationAlways => 'Sempre';

  @override
  String get muteSheetConfirmButton => 'SILENCIAR';

  @override
  String get muteSheetSaveButton => 'GUARDAR';

  @override
  String get muteSheetUnmuteButton => 'REATIVAR';

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
  String get chatRowActionMenuMuteLabel => 'SILENCIAR CONVERSA';

  @override
  String get chatRowActionMenuUnmuteLabel => 'REATIVAR CONVERSA';

  @override
  String get roomInfoScreenMuteLabel => 'SILÊNCIO';

  @override
  String get roomInfoScreenNotMutedRow => 'Não silenciada';

  @override
  String get attachmentMenuLocationLabel => 'localização';

  @override
  String get locationSheetSendCurrent => 'Enviar localização atual';

  @override
  String get locationSheetSendCurrentDetail => 'Onde estás agora';

  @override
  String get locationSheetLiveHeading => 'PARTILHAR EM DIRETO';

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
      'Pode partilhar onde está, incluindo em direto até 8 horas';

  @override
  String get childPolicyScreenLocationOffDesc => 'Não pode partilhar onde está';

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
  String get videoNoteMessagePlayLabel => 'reproduzir nota de vídeo';

  @override
  String get videoNoteMessagePauseLabel => 'pausar nota de vídeo';

  @override
  String get videoNoteMessageLoadingLabel => 'a carregar nota de vídeo';

  @override
  String get videoNoteMessageUnavailableLabel => 'nota de vídeo indisponível';

  @override
  String get videoNoteMessageRetryLabel => 'tentar novamente a nota de vídeo';

  @override
  String get videoNoteMessageRetryHint => 'toque para tentar novamente';

  @override
  String get videoNoteMessageDiscardLabel => 'descartar nota de vídeo';

  @override
  String get attachmentMenuVideoNoteLabel => 'nota de vídeo';

  @override
  String get cameraScreenPhotoModeLabel => 'FOTO';

  @override
  String get cameraScreenVideoModeLabel => 'VÍDEO';

  @override
  String get cameraScreenStartRecordingLabel => 'iniciar gravação';

  @override
  String get cameraScreenStopRecordingLabel => 'parar gravação';

  @override
  String get cameraScreenVideoFailedSnack =>
      'Não foi possível gravar esse vídeo.';

  @override
  String get scheduleSheetTitle => 'AGENDAR MENSAGEM';

  @override
  String get scheduleSheetSubtitle => 'Escreva agora. Sai quando você disser.';

  @override
  String get scheduleSheetWhenLabel => 'QUANDO';

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
  String get scheduleSheetConfirmButton => 'AGENDAR';

  @override
  String get scheduleSheetSaveButton => 'GUARDAR';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'Envia $when.';
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
  String get scheduleTimePickerTitle => 'ESCOLHER DATA E HORA';

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
  String scheduledPillJoin(String label, String time) {
    return '$label · $time';
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
  String get scheduledListTitle => 'AGENDADAS';

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
  String get scheduleEditTitle => 'EDITAR MENSAGEM';

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
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class AppLocalizationsPtBr extends AppLocalizationsPt {
  AppLocalizationsPtBr() : super('pt_BR');

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'SERVIDOR INACESSÍVEL';

  @override
  String get bootErrorBody => 'O Convex não inicializou.';

  @override
  String get bootErrorRetry => 'TENTAR NOVAMENTE';

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
      'não deu pra pedir agora — tente de novo';

  @override
  String get roomScreenGateSendMessages => 'enviar mensagens aqui';

  @override
  String get roomScreenGateSendMedia => 'enviar fotos ou áudios';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return 'até $max de cada vez';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'APAGAR $count MENSAGENS',
      one: 'APAGAR MENSAGEM',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody =>
      'Isso remove as mensagens para todos nessa conversa. Não é possível desfazer.';

  @override
  String get roomScreenDeleteConfirmButton => 'APAGAR PARA TODOS';

  @override
  String get roomScreenJumpFailedSnack => 'não deu pra ir até essa mensagem';

  @override
  String get roomScreenViewOnceAlreadyViewed => 'você já abriu essa foto.';

  @override
  String get roomScreenViewOnceGone => 'essa foto não está mais disponível.';

  @override
  String get roomScreenViewOnceNetworkError =>
      'não deu pra carregar essa foto.';

  @override
  String get roomScreenFileReadFailedSnack => 'não deu pra ler esse arquivo';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'arquivos têm limite de $size';
  }

  @override
  String get roomScreenRoomGone => 'sala sumiu';

  @override
  String get roomScreenCopiedSnack => 'copiado';

  @override
  String get roomScreenNameCopiedSnack => 'nome copiado';

  @override
  String get roomScreenPinLimitSnack =>
      'muitas mensagens fixadas — desafixe uma primeiro';

  @override
  String get roomScreenPinFailedSnack => 'não deu pra fixar isso';

  @override
  String get roomScreenReportSentSnack =>
      'denúncia enviada de forma privada. a pessoa não vai ser notificada.';

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
    return 'esta sala é temporária. as mensagens desaparecem após $ttl, lidas ou não.';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count MENSAGENS';
  }

  @override
  String get roomScreenSecretSpaceTitle => 'Espaço Secreto';

  @override
  String get roomScreenSecretSpaceBody =>
      'As mensagens desta sala são temporárias. Elas são removidas automaticamente de acordo com a política de segurança da sala.';

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
  String get roomScreenViewProfilePictureSemantic => 'ver foto de perfil';

  @override
  String get roomScreenViewRoomPictureSemantic => 'ver foto da sala';

  @override
  String get messageBubbleFileFallbackName => 'documento';

  @override
  String get messageBubbleAttachmentStatusFailed => 'falhou';

  @override
  String get messageBubbleAttachmentStatusSending => 'enviando…';

  @override
  String get messageBubbleViewOnceOpened => 'aberta';

  @override
  String get messageBubbleViewOnceExpired => 'expirada';

  @override
  String get messageBubbleViewOnceLabel => 'visualização única';

  @override
  String get messageBubbleViewOnceTapToView => 'toque para ver';

  @override
  String get messageBubbleViewOncePhotoLabel => 'Foto';

  @override
  String get messageBubbleViewOnceSemanticLabel =>
      'foto de visualização única, toque para ver';

  @override
  String get messageBubbleRetrySendingSemanticLabel =>
      'tentar enviar novamente';

  @override
  String get messageBubbleDiscardSemanticLabel => 'descartar';

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
  String get profileScreenEmailHint => 'opcional — nunca aparece para ninguém';

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
      'essa pessoa já te enviou um pedido — confira seus pedidos.';

  @override
  String get profileScreenErrorRequestAlreadySent => 'pedido já enviado.';

  @override
  String get profileScreenErrorUnblockFirst =>
      'você bloqueou essa pessoa — desbloqueie primeiro.';

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
      'Só uma pessoa grande pode fazer isso — é preciso o código ou a senha dela.';

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
  String get profileScreenLinkedAccountsNone => 'nada vinculado';

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
    return 'pode ser mudado de novo em $date';
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
      'visão limitada — essa pessoa compartilha mais com amigos.';

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
  String get cameraEditorScreenCropPresetFree => 'LIVRE';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'ORIG';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'cancelar corte';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => 'descartar foto';

  @override
  String get cameraEditorScreenUndoSemanticLabel => 'desfazer';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'refazer';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'redefinir corte';

  @override
  String get cameraEditorScreenRotateSemanticLabel => 'girar';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'cortar';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'este navegador não consegue abrir fotos HEIC';

  @override
  String get cameraEditorScreenImageLoadFailedMessage =>
      'não conseguimos abrir essa imagem';

  @override
  String get cameraEditorScreenCropDoneButton => 'PRONTO';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => 'tirar novamente';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'guardar a caneta';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => 'desenhar na foto';

  @override
  String get cameraEditorScreenSendingButton => 'ENVIANDO…';

  @override
  String get cameraEditorScreenSendButton => 'ENVIAR';

  @override
  String get cameraEditorScreenViewOnceNote =>
      'some depois de ser aberta uma vez';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => 'limpar desenho';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel =>
      'ver uma vez: ativado';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel =>
      'ver uma vez: desativado';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'cor da tinta';

  @override
  String get glassScreenPanelLooks => 'ESTILOS';

  @override
  String get glassScreenPanelBottomBar => 'BARRA INFERIOR';

  @override
  String get glassScreenPanelOtherSurfaces => 'OUTRAS SUPERFÍCIES';

  @override
  String get glassScreenPanelBarLayout => 'LAYOUT DA BARRA';

  @override
  String get glassScreenTitle => 'vidro.';

  @override
  String get glassScreenSubtitle => 'quanto do que está atrás transparece';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return 'TODOS OS $max ESPAÇOS OCUPADOS';
  }

  @override
  String get glassScreenSaveCurrentAs => 'SALVAR ATUAL COMO…';

  @override
  String get glassScreenResetEveryDial => 'REDEFINIR TODOS OS AJUSTES';

  @override
  String glassScreenResetToPreset(Object name) {
    return 'REDEFINIR PARA $name';
  }

  @override
  String get glassScreenSurfacesNote =>
      'o campo de mensagem, os cabeçalhos, os botões de chamada — tudo que fica sobre o texto, e não sobre o conteúdo que rola';

  @override
  String get glassScreenMatchBottomBar => 'IGUALAR À BARRA INFERIOR';

  @override
  String get glassScreenPresetEditedSubtitle =>
      'editado — salve como um novo estilo ou redefina';

  @override
  String get glassScreenCustomPresetName => 'Personalizado';

  @override
  String get glassScreenUnsavedSubtitle =>
      'não salvo — dê um nome para guardar';

  @override
  String get glassScreenSaveDialogTitle => 'salvar este visual como';

  @override
  String get glassScreenNoRoomToast => 'sem espaço — apague um visual primeiro';

  @override
  String get glassScreenRenameDialogTitle => 'renomear';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return 'apagar $name?';
  }

  @override
  String get glassScreenDeleteConfirmBody =>
      'o visual continua na tela — só deixa de ter um nome.';

  @override
  String get glassScreenKeepButton => 'manter';

  @override
  String get glassScreenDeleteButton => 'apagar';

  @override
  String get glassScreenNameHint => 'altas horas';

  @override
  String get glassScreenCancelButton => 'cancelar';

  @override
  String get glassScreenSaveButton => 'salvar';

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
  String get glassScreenPreviewBadge => 'PRÉVIA';

  @override
  String get glassScreenBuiltInLabel => 'integrado';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return 'sobrescrever $name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return 'renomear $name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return 'apagar $name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return 'redefinir $label';
  }

  @override
  String get glassScreenBackdropMsgDilan =>
      'mandou as fotos do telhado — as telhas estão todas rachadas';

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
  String get replyIndicatorViewOnceLabel => 'foto · visualização única';

  @override
  String get replyIndicatorVoiceMessageLabel => 'mensagem de voz';

  @override
  String get replyIndicatorDocumentLabel => 'documento';

  @override
  String get replyIndicatorMessageRemoved => 'mensagem removida';

  @override
  String get threadOverlayMessageNotFound =>
      'não encontrei essa mensagem neste tópico';

  @override
  String get threadOverlayReplyTargetNotFound =>
      'não encontrei o tópico para responder';

  @override
  String get threadOverlayStillSending =>
      'ainda enviando — tente de novo em instantes';

  @override
  String get threadOverlayCopiedToast => 'copiado';

  @override
  String get threadOverlayNameCopiedToast => 'nome copiado';

  @override
  String get threadOverlayPinLimitToast =>
      'muitas mensagens fixadas — desafixe uma primeiro';

  @override
  String get threadOverlayPinFailedToast => 'não consegui fixar isso';

  @override
  String get threadOverlayReportedToast => 'denunciado';

  @override
  String get threadOverlayUnavailable => 'tópico indisponível';

  @override
  String get roomInfoScreenNameRequiredError => 'nome é obrigatório';

  @override
  String get roomInfoScreenSavedSnackbar => 'salvo';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'senha removida';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'sair da sala?';

  @override
  String get roomInfoScreenLeaveConfirmBody =>
      'você pode entrar de novo se ela continuar aberta.';

  @override
  String get roomInfoScreenLeaveConfirmButton => 'SAIR';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'excluir sala?';

  @override
  String get roomInfoScreenDeleteConfirmBody =>
      'todas as mensagens daqui vão junto. isso é permanente.';

  @override
  String get roomInfoScreenDeleteConfirmButton => 'EXCLUIR';

  @override
  String get roomInfoScreenEndConversationConfirmTitle =>
      'encerrar esta conversa?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName também perde essa conversa — todas as mensagens somem para os dois. isso é permanente.';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => 'ENCERRAR';

  @override
  String get roomInfoScreenEndConversationPeerFallback => 'a outra pessoa';

  @override
  String get roomInfoScreenConfirmCancelButton => 'CANCELAR';

  @override
  String get roomInfoScreenErrorRoomExists =>
      'já existe uma sala com esse nome';

  @override
  String get roomInfoScreenErrorNotOwner => 'só o dono pode fazer isso';

  @override
  String get roomInfoScreenErrorNotAuthorized => 'você não tem permissão';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'essa sala não existe mais';

  @override
  String get roomInfoScreenRoomGone => 'sala sumiu';

  @override
  String get roomInfoScreenNameLabel => 'NOME';

  @override
  String get roomInfoScreenNameHint => 'nome da sala';

  @override
  String get roomInfoScreenDescriptionLabel => 'DESCRIÇÃO';

  @override
  String get roomInfoScreenDescriptionHint => 'uma linha sobre a sala…';

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
      'essa sala é protegida. por segurança, a senha atual não é exibida — digite uma nova para substituí-la.';

  @override
  String get roomInfoScreenReplacePasswordHint => 'substituir senha…';

  @override
  String get roomInfoScreenSetPasswordHint => 'trancar com uma senha…';

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
  String get roomInfoScreenViewProfilePictureSemantic => 'ver foto de perfil';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'ver foto da sala';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'alterar foto da sala';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'adicionar foto da sala';

  @override
  String get roomInfoScreenLoadingMembers => 'carregando membros…';

  @override
  String get roomInfoScreenOwnerBadge => 'DONO';

  @override
  String get roomInfoScreenSaveButton => 'SALVAR';

  @override
  String get roomInfoScreenNoneCount => 'nenhum';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'o acesso à câmera está desligado.\native-o nas Configurações para tirar uma foto.';

  @override
  String get cameraScreenOpeningSystemCamera => 'abrindo a câmera do sistema…';

  @override
  String get cameraScreenCloseButtonLabel => 'fechar câmera';

  @override
  String get cameraScreenLowLightBoostOnLabel => 'modo de pouca luz: ativado';

  @override
  String get cameraScreenLowLightBoostOffLabel =>
      'modo de pouca luz: desativado';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'flash: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'escolher da galeria';

  @override
  String get cameraScreenSwitchCameraLabel => 'trocar de câmera';

  @override
  String get cameraScreenTakePhotoLabel => 'tirar foto';

  @override
  String get childPolicyScreenAddByUsernameLabel => 'ADICIONAR POR USUÁRIO';

  @override
  String get childPolicyScreenAddCta => 'ADICIONAR';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'Essa pessoa recebe exatamente o que você tem: cada pedido para aprovar, cada configuração para mudar e o poder de te remover. $name já vê essa pessoa como família.';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => 'ADICIONAR UM ADULTO';

  @override
  String get childPolicyScreenAddGuardianHint => 'nome de usuário da pessoa';

  @override
  String get childPolicyScreenAllowCta => 'PERMITIR';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return 'Você não vai mais ser perguntado sobre essa pessoa — não importa se $childName adiciona ela ou se ela adiciona $childName.';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => 'PERMITIR ALGUÉM';

  @override
  String get childPolicyScreenAskToAddLabel => 'PEDIR PARA ADICIONAR';

  @override
  String get childPolicyScreenAskToAddOffDesc =>
      'só família — sem novos pedidos';

  @override
  String get childPolicyScreenAskToAddOnDesc =>
      'podem te perguntar sobre gente nova';

  @override
  String get childPolicyScreenBothFinalNote =>
      'As duas opções são definitivas. Para se afastar em vez disso, isso está em ADULTOS.';

  @override
  String get childPolicyScreenCallsLabel => 'CHAMADAS';

  @override
  String get childPolicyScreenCallsOffDesc => 'só mensagens';

  @override
  String get childPolicyScreenCallsOnDesc =>
      'voz + vídeo com quem for permitido';

  @override
  String get childPolicyScreenCancelLabel => 'CANCELAR';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'Cancelar';

  @override
  String get childPolicyScreenContactAddedRequestSent =>
      'adicionado — o pedido está a caminho';

  @override
  String get childPolicyScreenContactAddedToList =>
      'adicionado à lista de permitidos';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'CRIAR SALAS';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'não podem criar salas';

  @override
  String get childPolicyScreenCreateRoomsOnDesc =>
      'podem criar suas próprias salas privadas';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'Tudo desaparece: as mensagens, fotos, salas e os amigos. Isso não pode ser desfeito, e o nome de usuário fica livre para qualquer pessoa.';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'não foi possível excluir a conta — tente de novo';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return 'EXCLUIR A CONTA DE $name?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'Mensagens, fotos, salas e amigos, tudo vai embora. Não pode ser desfeito.';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return 'EXCLUIR A CONTA DE $name';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => 'EXCLUIR PARA SEMPRE';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      'não foi possível adicionar — tente de novo';

  @override
  String get childPolicyScreenErrorCannotAddSelf =>
      'esse é o nome de usuário da própria criança';

  @override
  String get childPolicyScreenErrorChildNotAllowed =>
      'uma criança não pode ser um adulto';

  @override
  String get childPolicyScreenErrorGenericGuardian =>
      'não foi possível fazer isso — tente de novo';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'alguém precisa cuidar da criança — adicione outra pessoa grande primeiro';

  @override
  String get childPolicyScreenErrorNotYours => 'não é você quem decide isso';

  @override
  String get childPolicyScreenErrorUserNotFound =>
      'nenhuma conta com esse nome de usuário';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'Ela vira uma conta normal com essa senha, e todas as pessoas grandes perdem toda a visibilidade. Não tem como voltar atrás — você teria que receber um convite como qualquer outra pessoa.';

  @override
  String get childPolicyScreenGraduateCta => 'FORMAR';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'Ela mantém tudo e recebe uma senha. Você perde toda a visibilidade. Irreversível.';

  @override
  String get childPolicyScreenGraduateDangerLabel =>
      'FORMAR PARA CONTA COMPLETA';

  @override
  String get childPolicyScreenGraduateFailed =>
      'não foi possível formá-la — tente de novo';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return 'FORMAR $name';
  }

  @override
  String get childPolicyScreenGraduateHint => 'uma senha para ela';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'Tirar uma sala de volta também remove a criança dela. Tirar uma pessoa de volta também apaga a conversa — dos dois lados.';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'Todo mundo aqui pode aprovar, mudar configurações e ver tudo. Qualquer um deles pode agir sozinho — nada espera pelos outros.';

  @override
  String get childPolicyScreenGuardianAdded =>
      'adicionado — agora pode cuidar da criança';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$name removido(a)';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (você)';
  }

  @override
  String get childPolicyScreenLoading => 'carregando…';

  @override
  String get childPolicyScreenLockedLabel => 'BLOQUEADO';

  @override
  String get childPolicyScreenMediaLabel => 'FOTOS + VOZ';

  @override
  String get childPolicyScreenMediaOffDesc => 'só texto';

  @override
  String get childPolicyScreenMediaOnDesc =>
      'pode enviar fotos, vídeos e notas de voz';

  @override
  String get childPolicyScreenNoRoomsYet => 'nenhuma sala ainda';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'Qualquer um daqui pode ser adicionado sem pedir sua permissão de novo — não importa quem comece.';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'Sempre desativado para crianças. Descobrir — a lista de salas de pessoas que você não conhece — fica totalmente oculta e não pode ser ativada. Salas para as quais alguém convida a criança continuam funcionando normalmente.';

  @override
  String get childPolicyScreenPublicRoomsLabel => 'SALAS PÚBLICAS';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian não vai mais ver nem aprovar nada para $child.';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return 'REMOVER $name?';
  }

  @override
  String get childPolicyScreenRemoveLabel => 'REMOVER';

  @override
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count na sala';
  }

  @override
  String get childPolicyScreenSectionGrownUps => 'PESSOAS GRANDES';

  @override
  String get childPolicyScreenSectionPeopleAllowed =>
      'PESSOAS QUE VOCÊ PERMITIU';

  @override
  String get childPolicyScreenSectionRoomsAllowed => 'SALAS QUE VOCÊ PERMITIU';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'O QUE PODEM FAZER';

  @override
  String get childPolicyScreenSectionWhenDone => 'ÚLTIMOS PASSOS';

  @override
  String get childPolicyScreenSendNowOffDesc =>
      'nada acontece até alguém adicionar o outro';

  @override
  String get childPolicyScreenSendNowOnDesc => 'eles recebem o pedido na hora';

  @override
  String get childPolicyScreenSendRequestNowLabel => 'ENVIAR PEDIDO AGORA';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return 'Você é o único adulto responsável por $name, então não pode simplesmente se afastar — adicione outro primeiro, ou use uma dessas opções.';
  }

  @override
  String get childPolicyScreenStepAwayLabel => 'AFASTAR-SE';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return 'Você vai perder toda a visibilidade sobre a conta de $name — os pedidos, as pessoas e as salas. Os outros adultos continuam cuidando de $name.';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => 'PARAR DE SUPERVISIONAR';

  @override
  String get childPolicyScreenStopSupervisingHeadline =>
      'PARAR DE SUPERVISIONAR?';

  @override
  String get childPolicyScreenTakeBackFailed =>
      'não deu pra retirar — tenta de novo';

  @override
  String get childPolicyScreenTakeBackLabel => 'RETIRAR';

  @override
  String get childPolicyScreenUsernameHint => 'nome de usuário';

  @override
  String get childPolicyScreenYou => 'você';

  @override
  String get roomContentScreenDefaultDocumentName => 'documento';

  @override
  String get roomContentScreenCouldntOpenFile =>
      'não deu pra abrir esse arquivo';

  @override
  String get roomContentScreenCouldntShare => 'não deu pra compartilhar isso';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count links copiados',
      one: 'copiado',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'APAGAR $count MENSAGENS',
      one: 'APAGAR MENSAGEM',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody =>
      'Isso remove tudo para todo mundo neste chat. Não dá pra desfazer.';

  @override
  String get roomContentScreenDeleteForEveryone => 'APAGAR PARA TODOS';

  @override
  String get roomContentScreenCancelTooltip => 'Cancelar';

  @override
  String get roomContentScreenBackTooltip => 'Voltar';

  @override
  String get roomContentScreenSelectingLabel => 'SELECIONANDO';

  @override
  String get roomContentScreenSharedContentLabel => 'CONTEÚDO COMPARTILHADO';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selecionados',
      one: '$count selecionado',
      zero: 'nada selecionado',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => 'SELECIONAR';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'TUDO';

  @override
  String get roomContentScreenEmptyMedia =>
      'ainda não tem fotos ou vídeos por aqui';

  @override
  String get roomContentScreenEmptyFiles => 'ainda não tem arquivos por aqui';

  @override
  String get roomContentScreenEmptyVoice =>
      'ainda não tem mensagens de voz por aqui';

  @override
  String get roomContentScreenEmptyLinks => 'ainda não tem links por aqui';

  @override
  String get roomContentScreenEmptySaved =>
      'nada salvo ainda. segure uma mensagem e escolha SALVAR.\n\no que você guarda aqui é só seu — uma mensagem fixada é o que a sala inteira vê.';

  @override
  String get roomContentScreenLoadFailed => 'não deu pra carregar isso';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return 'Mensagem de voz de $name';
  }

  @override
  String get roomContentScreenForwardAction => 'ENCAMINHAR';

  @override
  String get roomContentScreenCopyAction => 'COPIAR';

  @override
  String get roomContentScreenSaveAction => 'SALVAR';

  @override
  String get roomContentScreenShareAction => 'COMPARTILHAR';

  @override
  String get roomContentScreenInChatAction => 'NO CHAT';

  @override
  String get roomContentScreenDeleteAction => 'EXCLUIR';

  @override
  String get messageActionMenuReplyLabel => 'RESPONDER';

  @override
  String get messageActionMenuEditLabel => 'EDITAR';

  @override
  String get messageStampEditedLabel => 'editado';

  @override
  String get composerEditCardTitle => 'EDITAR MENSAGEM';

  @override
  String get spoilerRevealHint => 'Spoiler — ative para revelar o texto oculto';

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
  String get linkConfirmSheetTitle => 'ABRIR ESTE LINK?';

  @override
  String get linkConfirmSheetOpenLabel => 'ABRIR LINK';

  @override
  String get linkConfirmSheetCancelLabel => 'CANCELAR';

  @override
  String get roomScreenEditExpiredSnack =>
      'Tarde demais para editar — as mensagens só podem ser editadas por 15 minutos.';

  @override
  String get roomScreenEditFailedSnack =>
      'Não foi possível salvar a edição. Verifique sua conexão e tente de novo.';

  @override
  String get messageActionMenuForwardLabel => 'ENCAMINHAR';

  @override
  String get messageActionMenuViewThreadLabel => 'VER TÓPICO';

  @override
  String get messageActionMenuCopyLabel => 'COPIAR';

  @override
  String get messageActionMenuCopyNameLabel => 'COPIAR NOME';

  @override
  String get messageActionMenuPinLabel => 'FIXAR';

  @override
  String get messageActionMenuUnpinLabel => 'DESAFIXAR';

  @override
  String get messageActionMenuSelectLabel => 'SELECIONAR';

  @override
  String get messageActionMenuProfileLabel => 'PERFIL';

  @override
  String get messageActionMenuDeleteLabel => 'EXCLUIR';

  @override
  String get messageActionMenuReportLabel => 'DENUNCIAR';

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
    return 'ATIVO — $name';
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
  String callScreenStatusRinging(Object kind) {
    return '$kind · chamando…';
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
  String get callScreenStatusConnected => 'conectada';

  @override
  String get callScreenStatusEnded => 'chamada encerrada';

  @override
  String get callScreenStatusFailed => 'falha na chamada';

  @override
  String get callScreenStatusSwitching => 'trocando de dispositivo…';

  @override
  String get callScreenStatusMoved => 'movida';

  @override
  String get callScreenStatusReconnecting => 'reconectando…';

  @override
  String get callScreenPoorConnectionLabel => 'conexão ruim';

  @override
  String get callScreenWeakConnectionLabel => 'conexão fraca';

  @override
  String get callScreenControlUnmute => 'desmutar';

  @override
  String get callScreenControlMute => 'mutar';

  @override
  String get callScreenControlCamOn => 'ligar câmera';

  @override
  String get callScreenControlCamOff => 'desligar câmera';

  @override
  String get callScreenControlFlip => 'virar';

  @override
  String get callScreenControlSpeaker => 'viva-voz';

  @override
  String get callScreenControlEnd => 'encerrar';

  @override
  String get linkPreviewCardLinkLabel => 'LINK';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name aceitou seu pedido';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar =>
      'esse pedido foi retirado';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'pedido recusado';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'você bloqueou esse usuário — desbloqueie primeiro.';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      'essa pessoa não está aceitando pedidos de amizade no momento.';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      'não foi possível enviar. tente novamente.';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => 'PEDIDO RECEBIDO';

  @override
  String get friendRequestDraftScreenNewRequestLabel => 'NOVO PEDIDO';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name quer começar uma conversa.';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      'manda algumas linhas. a pessoa pode aceitar ou recusar.';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      'nada aqui é permanente até que os dois lados concordem.';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'TIPO DE SALA';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => 'EFÊMERA';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => 'PADRÃO';

  @override
  String get friendRequestDraftScreenLifetimeLabel => 'DURAÇÃO';

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
      'sussurre uma primeira linha · opcional';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      'adicione uma primeira mensagem · opcional';

  @override
  String get friendRequestDraftScreenHintWhisperFades =>
      'sussurre · desaparece sozinho';

  @override
  String get friendRequestDraftScreenHintStartWith => 'algo para começar…';

  @override
  String get friendRequestDraftScreenApproveButton => 'APROVAR E ABRIR SALA';

  @override
  String get friendRequestDraftScreenDeclineButton => 'RECUSAR';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'CANCELAR PEDIDO';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => 'PERGUNTE A UM ADULTO';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'ENVIAR PEDIDO';

  @override
  String get discoverScreenTitle => 'descobrir.';

  @override
  String get discoverScreenCaptionPeople => 'pessoas';

  @override
  String get discoverScreenCaptionRooms => 'salas';

  @override
  String get discoverScreenCaptionRequests => 'pedidos';

  @override
  String get discoverScreenPeopleBandLabel => 'PESSOAS';

  @override
  String get discoverScreenRoomsBandLabel => 'SALAS';

  @override
  String get discoverScreenFindPeopleTitle => 'encontrar pessoas';

  @override
  String get discoverScreenFindPeopleSubtitleChild =>
      'digite o nome de usuário completo';

  @override
  String get discoverScreenFindPeopleSubtitleAdult =>
      'busque por @usuário ou nome';

  @override
  String get discoverScreenRequestsSectionLabel => 'PEDIDOS';

  @override
  String get discoverScreenInboxQuiet => 'caixa de entrada silenciosa';

  @override
  String get discoverScreenNothingPending => 'nada enviado';

  @override
  String get discoverScreenYourPeopleLabel => 'SEUS AMIGOS';

  @override
  String get discoverScreenNoFriendsYetWithHint =>
      'ninguém ainda — encontre pessoas acima';

  @override
  String get discoverScreenNoFriendsYet => 'ninguém ainda';

  @override
  String get discoverScreenSearchRoomsTitle => 'buscar salas';

  @override
  String get discoverScreenSearchRoomsSubtitle =>
      'encontre uma sala pública pelo nome';

  @override
  String get discoverScreenPublicRoomsLabel => 'SALAS PÚBLICAS';

  @override
  String get discoverScreenLoadingRooms => 'procurando…';

  @override
  String get discoverScreenNoRoomsOpen => 'nada aberto no momento';

  @override
  String get discoverScreenIncomingLabel => 'recebidos';

  @override
  String get discoverScreenOutgoingLabel => 'enviados';

  @override
  String get discoverScreenIncomingLabelCaps => 'RECEBIDOS';

  @override
  String get discoverScreenOutgoingLabelCaps => 'ENVIADOS';

  @override
  String get discoverScreenJumpPeopleLabel => 'pessoas';

  @override
  String get discoverScreenJumpRoomsLabel => 'salas';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return 'Ir para $label';
  }

  @override
  String get imageCropScreenDefaultTitle => 'ajustar';

  @override
  String get imageCropScreenDefaultConfirmLabel => 'USAR FOTO';

  @override
  String get imageCropScreenSavingButton => 'SALVANDO…';

  @override
  String get imageCropScreenCancelButton => 'CANCELAR';

  @override
  String get imageCropScreenHeicUnsupported =>
      'este navegador não consegue abrir fotos HEIC';

  @override
  String get imageCropScreenLoadFailed => 'não foi possível abrir essa imagem';

  @override
  String get imageCropScreenHintCircle =>
      'arraste para mover, belisque para dar zoom';

  @override
  String get imageCropScreenHintRect => 'arraste e belisque para enquadrar';

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
  String get searchScreenHintPeople => 'buscar pessoas…';

  @override
  String get searchScreenHintRooms => 'buscar salas…';

  @override
  String get searchScreenPeoplePromptChild =>
      'digite o nome de usuário completo para encontrar alguém novo';

  @override
  String get searchScreenPeoplePromptDefault =>
      'busque por nome de usuário ou nome';

  @override
  String get searchScreenNoMatchChild =>
      'ninguém encontrado — gente nova precisa do nome de usuário\ncompleto, digitado exatamente';

  @override
  String get searchScreenNoMatchDefault => 'ninguém encontrado';

  @override
  String get searchScreenNoRoomsYet => 'ainda não há salas públicas';

  @override
  String get searchScreenNoRoomsMatch => 'nenhuma sala pública corresponde';

  @override
  String get searchScreenActionAskToAdd => 'PEDIR PARA ADICIONAR';

  @override
  String get searchScreenActionSendRequest => 'ENVIAR PEDIDO';

  @override
  String get searchScreenActionCancel => 'CANCELAR';

  @override
  String get searchScreenActionApprove => 'APROVAR';

  @override
  String get searchScreenActionOpenDm => 'ABRIR DM';

  @override
  String get searchScreenAskedLabel => 'pedido';

  @override
  String get profileVisibilityScreenTitle => 'preferências de visibilidade.';

  @override
  String get profileVisibilityScreenSubtitle =>
      'controle o que os outros veem — e como podem chegar até você.';

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
      'copiado — cole em um lugar seguro';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => 'confirme\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => 'que é você.';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'Sua senha, para que mais ninguém possa colocar uma frase de recuperação na sua conta.';

  @override
  String get recoveryPhraseScreenPasswordHint => 'senha';

  @override
  String get recoveryPhraseScreenContinueButton => 'CONTINUAR';

  @override
  String get recoveryPhraseScreenNotNowLink => 'agora não';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'Digite sua senha.';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => 'salve\n';

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
      'agora não — manter minha frase atual';

  @override
  String get homeScreenProfileSemanticLabel => 'Seu perfil';

  @override
  String homeScreenGreeting(Object name) {
    return 'e aí, $name.';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => 'Nova sala';

  @override
  String get homeScreenEmptyRoomsMessage => 'nenhuma sala ainda — crie uma';

  @override
  String get groupCallScreenTitleVideo => 'Chamada de vídeo em grupo';

  @override
  String get groupCallScreenTitleVoice => 'Chamada de voz em grupo';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '$count na chamada';
  }

  @override
  String get groupCallScreenReconnecting => 'reconectando…';

  @override
  String get groupCallScreenUnmuteLabel => 'ativar microfone';

  @override
  String get groupCallScreenMuteLabel => 'desativar microfone';

  @override
  String get groupCallScreenCamOnLabel => 'ativar câmera';

  @override
  String get groupCallScreenCamOffLabel => 'desativar câmera';

  @override
  String get groupCallScreenFlipLabel => 'virar';

  @override
  String get groupCallScreenSpeakerLabel => 'alto-falante';

  @override
  String get groupCallScreenLeaveLabel => 'sair';

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
  String get roomFilterDrawerClearLabel => 'limpar';

  @override
  String get roomFilterDrawerDimensionType => 'TIPO';

  @override
  String get roomFilterDrawerDimensionNature => 'NATUREZA';

  @override
  String get roomFilterDrawerDimensionStatus => 'STATUS';

  @override
  String get roomFilterDrawerPanelClear => 'LIMPAR';

  @override
  String get roomFilterDrawerPanelDone => 'PRONTO';

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
    return 'nada combina com $summary';
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
      other: 'mostrar todas as $count conversas',
      one: 'mostrar $count conversa',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => 'nova sala';

  @override
  String get createRoomSheetTaglineSecret => 'NADA SERÁ GUARDADO';

  @override
  String get createRoomSheetTaglineRegular => 'UM ESPAÇO QUE FICA';

  @override
  String get createRoomSheetNameLabel => 'NOME';

  @override
  String get createRoomSheetNameHint => 'dê um nome honesto…';

  @override
  String get createRoomSheetDescriptionLabel => 'DESCRIÇÃO · OPCIONAL';

  @override
  String get createRoomSheetDescriptionHint => 'uma linha sobre a sala…';

  @override
  String get createRoomSheetVisibilityLabel => 'VISIBILIDADE';

  @override
  String get createRoomSheetVisibilityPublicTitle => 'pública';

  @override
  String get createRoomSheetVisibilityPublicSub =>
      'qualquer um consegue encontrar';

  @override
  String get createRoomSheetVisibilityPrivateTitle => 'privada';

  @override
  String get createRoomSheetVisibilityPrivateSub => 'só com convite';

  @override
  String get createRoomSheetTypeLabel => 'TIPO';

  @override
  String get createRoomSheetTypeStandardTitle => 'padrão';

  @override
  String get createRoomSheetTypeStandardSub => 'mensagens permanecem';

  @override
  String get createRoomSheetTypeEphemeralTitle => 'efêmera';

  @override
  String get createRoomSheetTypeEphemeralSub => 'mensagens se apagam sozinhas';

  @override
  String get createRoomSheetMessageLifeLabel => 'VIDA DA MENSAGEM';

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
  String get createRoomSheetPasswordLabel => 'SENHA · OPCIONAL';

  @override
  String get createRoomSheetPasswordHint => 'tranque com uma frase secreta…';

  @override
  String get createRoomSheetNameRequiredError => 'nome é obrigatório';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'Abrir a sala';

  @override
  String get createRoomSheetOpenRoomButton => 'ABRIR A SALA';

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
  String get reactionDetailsSheetTitle => 'REAÇÕES';

  @override
  String get reactionDetailsSheetEmptyState => 'não tem mais nada aqui';

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
  String get reactionDetailsSheetFilterAll => 'TODOS';

  @override
  String get reactionDetailsSheetYouBadge => 'VOCÊ';

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
  String get audioMessageUnavailableLabel => 'áudio indisponível';

  @override
  String get audioMessageRetryHint => 'toque para tentar novamente';

  @override
  String get audioMessageLoadingLabel => 'carregando…';

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
  String get audioMessageUsernameHint => 'nome de usuário';

  @override
  String get audioMessageDisplayNameHint => 'nome de exibição (opcional)';

  @override
  String get audioMessagePasswordHint => 'senha';

  @override
  String get audioMessageSwitchToLinkPrompt => 'Essa conta é minha — entrar';

  @override
  String get audioMessageCreateAccountButton => 'CRIAR CONTA';

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
      'não foi possível salvar — tente de novo';

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
  String get approvalsScreenForwardDirectMessageFallback => 'mensagem direta';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ENCAMINHAR $count MENSAGENS',
      one: 'ENCAMINHAR MENSAGEM',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'nenhum outro chat ainda';

  @override
  String get approvalsScreenForwardNoMatches => 'nada encontrado';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return 'até $max chats por vez';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'buscar chats';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return 'Desmarcar $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return 'Selecionar $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => 'SOME';

  @override
  String get approvalsScreenForwardSendSemantic => 'Enviar';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ENVIAR PARA $count',
      zero: 'ENVIAR',
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
  String get linkedAccountsScreenCallSheetVoiceLabel => 'VOZ';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'VÍDEO';

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
  String get childPairScreenAccountGoneError => 'Essa conta não existe mais.';

  @override
  String get childPairScreenScanButtonLabel => 'ESCANEAR CÓDIGO DELE';

  @override
  String get childPairScreenNoCameraMessage =>
      'Sem câmera aqui — digite os seis números.';

  @override
  String get childPairScreenStopScanning => 'parar de escanear';

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
      'Mostrando parte deste arquivo — baixe-o para ver o resto.';

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
  String get fileMessageStandardBadge => 'PADRÃO';

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
  String get fileMessageApproveButton => 'APROVAR';

  @override
  String get fileMessageDeclineButton => 'RECUSAR';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return 'ENVIADO $ago';
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
  String get fileMessageCancelRequestButton => 'CANCELAR PEDIDO';

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
      'Não foi possível criar um código — tente de novo.';

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
    return 'No celular de $name, abra o MonkeyHub e escaneie isto — ou digite os números.';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'este código expirou';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'expira em $time';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => 'NOVO CÓDIGO';

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
  String get deepOceanThemeEphemeralHint =>
      'sussurre algo que o servidor vai esquecer…';

  @override
  String get deepOceanThemeDefaultHint => 'diga algo…';

  @override
  String get deepOceanThemeMessageHint => 'Mensagem';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'este arquivo sumiu';

  @override
  String get photoChromeMediaYouLabel => 'você';

  @override
  String get photoChromeCloseSemanticLabel => 'Fechar';

  @override
  String get photoChromeShowInChatSemanticLabel => 'Mostrar no chat';

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
  String get typingIndicatorUnknownCallerFallbackName => 'chamada recebida';

  @override
  String get typingIndicatorIncomingVideoCallLabel =>
      'CHAMADA DE VÍDEO RECEBIDA';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => 'CHAMADA DE VOZ RECEBIDA';

  @override
  String get typingIndicatorDeclineButtonLabel => 'recusar';

  @override
  String get typingIndicatorDeclineButtonDeclining => 'recusando…';

  @override
  String get typingIndicatorAcceptButtonLabel => 'aceitar';

  @override
  String get typingIndicatorAcceptButtonConnecting => 'conectando…';

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
      'permissão do microfone negada';

  @override
  String get voiceRecorderScreenStatusRecording => 'GRAVANDO';

  @override
  String get voiceRecorderScreenStatusReady => 'PRONTO';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'TOQUE PARA COMEÇAR';

  @override
  String get voiceRecorderScreenReRecordButton => 'REGRAVAR';

  @override
  String get voiceRecorderScreenStopButton => 'PARAR';

  @override
  String get voiceRecorderScreenSendButton => 'ENVIAR';

  @override
  String get voiceRecorderScreenRecordButton => 'GRAVAR';

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
    return 'Isso desconecta $name deste telefone e o devolve — o telefone volta para a tela de login normal, e qualquer pessoa pode usá-lo.';
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
  String get activeCallPillPinnedHeader => 'FIXADOS';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'FIXADOS · $count';
  }

  @override
  String get activeCallPillNothingPinned => 'nada mais fixado';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return 'Ir para a mensagem de $name';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return 'Desafixar mensagem de $name';
  }

  @override
  String get callButtonErrorBusy => 'ocupado em outra chamada';

  @override
  String get callButtonErrorCallFailed => 'não foi possível iniciar a chamada';

  @override
  String get callButtonErrorNotMember => 'não é membro desta sala';

  @override
  String get callButtonErrorGeneric => 'não foi possível iniciar a chamada';

  @override
  String get callButtonAlreadyOnCall => 'Você já está em uma chamada';

  @override
  String get callButtonBusyElsewhere =>
      'Chamada em andamento em outro dispositivo';

  @override
  String get callButtonVoiceCallTooltip => 'chamada de voz';

  @override
  String get callButtonVideoCallTooltip => 'chamada de vídeo';

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
      'cápsula de citação na cor de destaque, com barra de conexão e avatar — aquele visual clássico e familiar do WhatsApp.';

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
      'Não foi possível criar a conta — tente de novo.';

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
      'Para todo o resto, é preciso da sua aprovação antes — tanto quando ela pedir para adicionar alguém, quanto quando pedirem para adicioná-la.';

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
  String get childSetupScreenWaitingPillAskedLabel => 'pedido';

  @override
  String get childSetupScreenMemberCountUnitLabel => 'MEMBROS';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return 'ver todos ($count)';
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
      'sem rabicho — uma sequência se mantém unida só pelos cantos internos apertados.';

  @override
  String get bubbleStyleScreenPillLabel => 'CÁPSULA';

  @override
  String get bubbleStyleScreenPillDescription =>
      'cápsulas totalmente arredondadas, idênticas em cada linha.';

  @override
  String get bubbleStyleScreenSlabLabel => 'BLOCO';

  @override
  String get bubbleStyleScreenSlabDescription =>
      'ombros quadrados — nítidos, impressos, deliberados.';

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
      'última mensagem agora mesmo';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return 'última mensagem há ${hours}h';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      'última mensagem ontem';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return 'última mensagem há $days dias';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      'última mensagem há um tempo';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => 'TIRAR';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return 'tirar $contactName de $childName?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      'eles não vão mais conseguir se falar, e a conversa deles vai junto.';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return 'eles não vão mais conseguir se falar. $contactName não vai receber um aviso.';
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
      'some para os dois, incluindo fotos e áudios. isso não pode ser desfeito.';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'eles também compartilham $count salas',
      one: 'eles também compartilham $count sala',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      'elas continuam aqui. retome a sala na lista de SALAS abaixo se quiser tirá-la de lá.';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      'RETOMAR E EXCLUIR';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return 'remove $contactName e apaga $messages.';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return 'remove $contactName da lista de permitidos.';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'Cancelar';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton =>
      'CANCELAR';

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
  String get groupCallBannerJoinButtonLabel => 'ENTRAR';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'ENTRAR NA SALA';

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
  String get groupCallBannerPasswordFieldLabel => 'SENHA';

  @override
  String get groupCallBannerPasswordHint => 'frase secreta…';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => 'Entrar';

  @override
  String get groupCallBannerJoinRoomButtonLabel => 'ENTRAR';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'Cancelar';

  @override
  String get groupCallBannerCancelButtonLabel => 'cancelar';

  @override
  String get viewOnceViewerBadgeLabel => 'VER UMA VEZ';

  @override
  String get socialButtonDividerOr => 'ou';

  @override
  String get socialButtonGoogleContinue => 'Continuar com o Google';

  @override
  String get discoverListsPeopleTitle => 'seu pessoal.';

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
  String get discoverListsFilterHint => 'filtrar seu pessoal…';

  @override
  String get discoverListsClearFilterSemanticLabel => 'Limpar filtro';

  @override
  String get discoverListsNoOneYet => 'ninguém ainda';

  @override
  String discoverListsNoMatches(Object query) {
    return 'ninguém encontrado para \"$query\"';
  }

  @override
  String get discoverListsVoiceCallLabel => 'CHAMADA DE VOZ';

  @override
  String get discoverListsVideoCallLabel => 'CHAMADA DE VÍDEO';

  @override
  String get approvalGateAlreadyAskedLabel => 'JÁ PEDIU';

  @override
  String get approvalGateAskGrownUpLabel => 'PEÇA A UM ADULTO';

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
  String get approvalGateAskButton => 'PEDIR';

  @override
  String get approvalGateNotNowButton => 'AGORA NÃO';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => 'esperando um adulto';

  @override
  String get reportSheetTitle => 'DENÚNCIA';

  @override
  String get reportSheetSubtitle => 'conte pra gente o que está errado.';

  @override
  String get reportSheetPrivacyNote =>
      'denúncias são privadas — a outra pessoa não é avisada.';

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
  String get reportSheetUpdateRequiredTitle => 'ATUALIZAÇÃO NECESSÁRIA';

  @override
  String get reportSheetUpdateAvailableTitle => 'ATUALIZAÇÃO DISPONÍVEL';

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
  String get reportSheetUpdateButtonTitle => 'ATUALIZAR';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'abre o TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'abre a App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'abre o Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage =>
      'abre a página de download';

  @override
  String get reportSheetUpdateActionReloads => 'recarrega com a nova versão';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'Depois';

  @override
  String get reportSheetUpdateLaterButton => 'DEPOIS';

  @override
  String get roomFilterBarAllChipLabel => 'tudo';

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
    return 'RESPONDENDO A $name';
  }

  @override
  String get roomCardLockedBadge => 'TRANCADA';

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
    return 'criada há $ago';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count dentro';
  }

  @override
  String get roomCardMessagesFadeLabel => 'mensagens somem';

  @override
  String get roomCardEnterLabel => '↗ entrar';

  @override
  String get roomCardBlockedScreenTitle => 'BLOQUEADOS';

  @override
  String get roomCardBlockedEmptyState => 'você ainda não bloqueou ninguém.';

  @override
  String get roomCardUnblockButton => 'DESBLOQUEAR';

  @override
  String get attachmentMenuPhotoLabel => 'foto';

  @override
  String get attachmentMenuVideoLabel => 'vídeo';

  @override
  String get attachmentMenuCameraLabel => 'câmera';

  @override
  String get attachmentMenuVoiceLabel => 'voz';

  @override
  String get attachmentMenuFileLabel => 'arquivo';

  @override
  String get attachmentMenuConnectionRetrying => 'tentando novamente…';

  @override
  String get attachmentMenuConnectionCantReachServer =>
      'não foi possível conectar ao servidor · toque para tentar novamente';

  @override
  String get attachmentMenuConnectionReconnecting => 'reconectando…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel =>
      'Tentar conexão novamente';

  @override
  String get roomGridTileEmptyLastMessage => 'quieto por enquanto';

  @override
  String get roomGridTileMemberCountLabel => 'DENTRO';

  @override
  String get roomGridTileThemeChipLabel => 'TEMA';

  @override
  String get bulkActionBarCancelLabel => 'CANCELAR';

  @override
  String get bulkActionBarSelectMessagesLabel => 'SELECIONAR MENSAGENS';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count SELECIONADAS';
  }

  @override
  String get bulkActionBarForwardLabel => 'ENCAMINHAR';

  @override
  String get bulkActionBarDeleteLabel => 'EXCLUIR';

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
      'a pessoa não vai ser notificada.';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      'vocês são amigos no momento — bloquear encerra a amizade, então para se reconectar depois você vai precisar enviar um novo pedido de amizade.';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      'a pessoa vai sumir das suas buscas e não vai conseguir te mandar mensagem.';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'BLOQUEAR';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return 'bloquear $name?';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'você compartilha $count salas com essa pessoa',
      one: 'você compartilha $count sala com essa pessoa',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'essas salas continuam intactas. você pode sair de qualquer uma delas nas configurações de cada sala.';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'BLOQUEAR';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'remove a amizade e bloqueia. o histórico de conversa existente continua no seu arquivo.';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      'a pessoa fica escondida das buscas e não consegue te alcançar.';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'BLOQUEAR E EXCLUIR DM';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      'também apaga sua DM com essa pessoa — todas as mensagens, reações e arquivos de mídia somem.';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'Cancelar';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'CANCELAR';

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
  String get reactionBubblePickerTitle => 'REAGIR';

  @override
  String get reactionBubbleNoRecentsPlaceholder => 'ainda sem recentes';

  @override
  String get reactionBubbleSearchHint => 'buscar emoji';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => 'nenhum resultado';

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
      'não deu para pedir agora — tente de novo';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'senha errada';

  @override
  String get enterPublicRoomJoinFailedMessage =>
      'não deu pra entrar — tente de novo';

  @override
  String get feedBoardTitle => 'HOJE';

  @override
  String feedBoardEditionLabel(Object number) {
    return 'Nº$number';
  }

  @override
  String get feedBoardHighlightsLabel => 'DESTAQUES';

  @override
  String get feedBoardHighlightsEmpty => 'ainda não tem nada capturado hoje';

  @override
  String get feedBoardPuzzleLabel => 'O ENIGMA';

  @override
  String get feedBoardPuzzleEmpty => 'o enigma de hoje ainda não está pronto';

  @override
  String get feedBoardStandingsLabel => 'PONTOS DE VIDA';

  @override
  String get feedBoardStandingsEmpty => 'nenhum ponto no placar hoje';

  @override
  String get feedBoardActivityLabel => 'ATIVIDADE';

  @override
  String get feedBoardActivityEmpty => 'hoje está calmo por enquanto';

  @override
  String get feedBoardActivityNoFriends =>
      'adicione um amigo e o dia dele aparece aqui';

  @override
  String get feedBoardLoadFailed =>
      'não foi possível carregar o quadro — tente daqui a pouco';

  @override
  String get enterPublicRoomVisibilityPublicLabel => 'PÚBLICA';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => 'PRIVADA';

  @override
  String get enterPublicRoomJoinedBadgeLabel => 'PARTICIPANDO';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'EFÊMERA · $duration';
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
      'Somente por convite — não aparece em Descobrir';

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
  String get roomInfoSheetNoDescription => 'ainda sem descrição';

  @override
  String get roomInfoSheetCreatedLabel => 'CRIADA EM';

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
      'sem frase de recuperação — você pode não conseguir mais entrar.';

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
  String get roomContentTabLabelMedia => 'MÍDIA';

  @override
  String get roomContentTabLabelFiles => 'ARQUIVOS';

  @override
  String get roomContentTabLabelVoice => 'ÁUDIOS';

  @override
  String get roomContentTabLabelLinks => 'LINKS';

  @override
  String get roomContentTabLabelSaved => 'SALVAS';

  @override
  String get roomContentTabHeaderMedia => 'mídia';

  @override
  String get roomContentTabHeaderFiles => 'arquivos';

  @override
  String get roomContentTabHeaderVoice => 'áudios';

  @override
  String get roomContentTabHeaderLinks => 'links';

  @override
  String get roomContentTabHeaderSaved => 'salvas';

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
      'Conte o que deu errado. Os dados do app e do seu aparelho são incluídos automaticamente, junto com um registro técnico do que o app estava fazendo — é isso que ajuda a encontrar a causa.';

  @override
  String get reportProblemDescribeLabel => 'O QUE ACONTECEU';

  @override
  String get reportProblemDescribeHint =>
      'A tela pisca, os botões não respondem…';

  @override
  String get reportProblemScreenshotsLabel => 'CAPTURAS DE TELA';

  @override
  String get reportProblemAddScreenshot => 'Adicionar captura de tela';

  @override
  String get reportProblemDetailsLabel => 'SEUS DADOS';

  @override
  String get reportProblemCopyDetails => 'Copiar dados';

  @override
  String get reportProblemCopied => 'Copiado';

  @override
  String get reportProblemSend => 'Enviar relatório';

  @override
  String get reportProblemSent => 'Relatório enviado — obrigado!';

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
      'só a prévia — balões mais limpos, toque para abrir';

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
      'Full HD — mais nítido, usa mais dados';

  @override
  String get videoQualityScreenUhd4kSubtitle =>
      'Ultra HD — melhor em uma conexão forte';

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
      'silencioso — você só vê as coisas quando abre o app';

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
      'Essa é uma conta infantil — peça a um adulto um código de pareamento.';

  @override
  String get authErrorPairingCodeExpired =>
      'Esse código expirou. Peça um novo.';

  @override
  String get authErrorPairingCodeInvalid =>
      'Esse código não funcionou. Ele pode já ter sido usado.';

  @override
  String get authErrorUseSocialSignIn =>
      'Essa conta faz login com Apple ou Google — use os botões abaixo.';

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
  String get glassKnobLabelFrost => 'FOSCO';

  @override
  String get glassKnobHintFrost =>
      'quanto de branco fica sobre o vidro. diminua para ficar transparente';

  @override
  String get glassKnobLabelBlur => 'DESFOQUE';

  @override
  String get glassKnobHintBlur =>
      'fosco no topo da faixa, vidro nítido na base';

  @override
  String get glassKnobLabelSaturation => 'VAZAMENTO DE COR';

  @override
  String get glassKnobHintSaturation =>
      'quanto de cor sobrevive ao desfoque. depois de 2, começa a posterizar';

  @override
  String get glassKnobLabelRimOpacity => 'BORDA';

  @override
  String get glassKnobHintRimOpacity =>
      'o contorno de destaque. zero para uma superfície sem borda';

  @override
  String get glassKnobLabelRimWidth => 'ESPESSURA DA BORDA';

  @override
  String get glassKnobHintRimWidth => 'a espessura desse contorno';

  @override
  String get glassKnobLabelShadowOpacity => 'SOMBRA';

  @override
  String get glassKnobHintShadowOpacity =>
      'o quanto a superfície flutua acima do que está atrás dela';

  @override
  String get glassKnobLabelShadowBlur => 'DIFUSÃO DA SOMBRA';

  @override
  String get glassKnobHintShadowBlur => 'suave e ampla, ou firme e dura';

  @override
  String get glassKnobLabelShadowY => 'QUEDA DA SOMBRA';

  @override
  String get glassKnobHintShadowY => 'o quanto ela cai abaixo da superfície';

  @override
  String get glassKnobLabelBarMargin => 'MARGEM LATERAL';

  @override
  String get glassKnobHintBarMargin =>
      'o espaço entre a barra e a borda da tela';

  @override
  String get glassKnobLabelBarBottom => 'ESPAÇO INFERIOR';

  @override
  String get glassKnobHintBarBottom =>
      'o quanto a barra flutua acima da base da tela';

  @override
  String get glassKnobLabelShellPadH => 'PREENCHIMENTO DAS PONTAS';

  @override
  String get glassKnobHintShellPadH =>
      'da borda da barra até a primeira cápsula. mantenha pequeno, ou as pontas ficam isoladas';

  @override
  String get glassKnobLabelShellPadV => 'PREENCHIMENTO SUPERIOR';

  @override
  String get glassKnobHintShellPadV =>
      'da borda da barra até o topo da cápsula';

  @override
  String get glassKnobLabelIndicatorInset => 'RECUO DA CÁPSULA';

  @override
  String get glassKnobHintIndicatorInset =>
      'o quanto a cápsula de seleção fica recuada dentro do próprio espaço';

  @override
  String get glassKnobLabelSegmentPadV => 'PREENCHIMENTO DA LINHA';

  @override
  String get glassKnobHintSegmentPadV =>
      'o espaço acima e abaixo do ícone e do seu rótulo';

  @override
  String get glassKnobLabelIconLabelGap => 'ESPAÇO DO ÍCONE';

  @override
  String get glassKnobHintIconLabelGap =>
      'espaço entre um ícone e a palavra abaixo dele';

  @override
  String get glassKnobLabelIconSize => 'TAMANHO DO ÍCONE';

  @override
  String get glassKnobLabelLabelSize => 'TAMANHO DO RÓTULO';

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
      'Igual ao dispositivo · completo';

  @override
  String get settingsScreenValueMotionSystemCalm =>
      'Igual ao dispositivo · calmo';

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
  String get motionScreenCalmSubtitle => 'a decoração para — nada mais muda';

  @override
  String get momentRailCaptureLabel => 'CAPTURAR';

  @override
  String get momentRailYouLabel => 'você';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author: $caption';
  }

  @override
  String get momentTagFate => 'DESTINO';

  @override
  String get momentTagJinx => 'AZAR';

  @override
  String get momentTagLuck => 'SORTE';

  @override
  String get momentTagCalledIt => 'EU AVISEI';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'que coincidência';

  @override
  String get momentTagJinxHint => 'você mesmo causou';

  @override
  String get momentTagLuckHint => 'foi a seu favor';

  @override
  String get momentTagCalledItHint => 'você viu chegando';

  @override
  String get momentTagNpcHint => 'cérebro desligado';

  @override
  String get momentComposerTitle => 'o que aconteceu?';

  @override
  String get momentComposerCaptionHint => 'diga alguma coisa';

  @override
  String get momentComposerTagPrompt => 'ganhou um ponto? adicione já';

  @override
  String get momentComposerCapture => 'câmera';

  @override
  String get momentComposerLibrary => 'galeria';

  @override
  String get momentComposerRemovePhoto => 'remover foto';

  @override
  String get momentComposerPost => 'PUBLICAR';

  @override
  String get momentComposerErrorDailyCap =>
      'já são cinco hoje — guarde para amanhã';

  @override
  String get momentComposerErrorNotAllowed =>
      'um responsável desativou o compartilhamento de fotos';

  @override
  String get momentComposerErrorTooLong => 'ficou um pouco longo — encurte';

  @override
  String get momentComposerErrorEmpty =>
      'adicione uma foto ou algumas palavras';

  @override
  String get momentComposerErrorGeneric =>
      'não foi possível publicar — tente de novo';

  @override
  String get momentViewerDelete => 'excluir';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who publicou um momento';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name levou um $tag';
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
  String momentActivityMoreCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count hoje',
      one: 'mais 1 hoje',
    );
    return '$_temp0';
  }

  @override
  String get puzzleScreenTitle => 'o enigma.';

  @override
  String get puzzleScreenSubtitle => 'quatro símbolos, seis tentativas';

  @override
  String get puzzleSubmit => 'ADIVINHAR';

  @override
  String get puzzleBackspace => 'apagar último símbolo';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return 'símbolo $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return 'resolvido em $count';
  }

  @override
  String get puzzleFailedTitle => 'sem tentativas';

  @override
  String get puzzleAnswerWas => 'O CÓDIGO ERA';

  @override
  String get puzzleShare => 'COPIAR RESULTADO';

  @override
  String get puzzleShareCopied => 'copiado — mande para um amigo';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => 'você já resolveu o de hoje';

  @override
  String get puzzleErrorOutOfGuesses => 'você não tem tentativas hoje';

  @override
  String get puzzleErrorGeneric => 'não foi possível enviar — tente de novo';

  @override
  String get puzzleScoreboardLabel => 'PONTUAÇÕES DE HOJE';

  @override
  String get puzzleScoreboardEmpty => 'ninguém terminou hoje ainda';

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
      'hoje é sempre compartilhado com os amigos — isto abre tudo o que veio antes';

  @override
  String get momentComposerVideo => 'vídeo';

  @override
  String get momentComposerErrorTooBig =>
      'esse vídeo é muito grande — máximo 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => 'você publicou um momento';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'você levou um $tag';
  }

  @override
  String pointLineSelf(Object tag) {
    return 'você · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => 'o que aconteceu?';

  @override
  String get pointComposerNoteHint => 'escolha uma acima e conte';

  @override
  String get pointComposerAdd => 'ADICIONAR PONTO';

  @override
  String get pointComposerAddPhoto => 'adicionar foto';

  @override
  String get pointsBoardAdd => 'ADICIONAR UM PONTO';

  @override
  String get pointsExplainerOpen => 'o que é isso?';

  @override
  String get pointsExplainerTitle => 'o jogo dos pontos';

  @override
  String get pointsExplainerIntro =>
      'Uma piada recorrente com placar. Quando acontece algo com você — bom, ruim ou só estranho — você registra e fica no quadro naquele dia.';

  @override
  String get pointsExplainerRuleHonour =>
      'Os pontos você mesmo se dá. Ninguém confere — a graça é essa, e seus amigos avisam se você estiver exagerando.';

  @override
  String get pointsExplainerRuleToday =>
      'Os pontos zeram todo dia. O quadro mostra hoje; seu histórico é seu.';

  @override
  String get pointsExplainerRuleCap =>
      'Cinco de cada tipo por dia, para ninguém transformar o quadro em bobagem.';

  @override
  String get pointsExplainerGotIt => 'ENTENDI';

  @override
  String get momentTagFateExample => 'encontrei meu dentista em outro país';

  @override
  String get momentTagJinxExample => 'lavei o carro e choveu às quatro';

  @override
  String get momentTagLuckExample => 'peguei o trem por dois segundos';

  @override
  String get momentTagCalledItExample =>
      'falei que a continuação ia fracassar, e fracassou';

  @override
  String get momentTagNpcExample => 'falei ‘você também’ para o garçom';

  @override
  String feedBoardEditionHint(Object number) {
    return 'dia $number do feed';
  }

  @override
  String get feedBoardHighlightsHint => 'fotos e vídeos que valem uma olhada';

  @override
  String get profileVisibilityScreenPointsLabel => 'meus pontos';

  @override
  String get profileVisibilityScreenPointsDesc =>
      'se os pontos que você registra aparecem nos quadros dos seus amigos';

  @override
  String get momentComposerEditPhoto => 'editar recorte';

  @override
  String get archiveScreenTitle => 'seu arquivo';

  @override
  String get archiveScreenEnd => 'é tudo';

  @override
  String get archiveScreenEmptyTitle => 'você ainda não guardou nada';

  @override
  String get archiveScreenEmptyBody =>
      'os momentos saem dos quadros dos seus amigos depois de um dia, mas ficam aqui para você.';

  @override
  String get archiveScreenEmptyFriendTitle => 'não tem nada aqui';

  @override
  String get archiveScreenEmptyFriendBody =>
      'ainda não publicou nada que você possa ver.';

  @override
  String get archiveScreenPrivateTitle => 'o passado é privado';

  @override
  String get archiveScreenPrivateBody =>
      'você ainda vê o que for publicado hoje.';

  @override
  String get archiveScreenNotFriendTitle => 'vocês não são amigos';

  @override
  String get archiveScreenNotFriendBody =>
      'você só pode voltar nos dias de um amigo.';

  @override
  String get archiveScreenErrorTitle => 'não foi possível carregar';

  @override
  String get archiveScreenErrorBody => 'verifique sua conexão e tente de novo.';

  @override
  String get feedBoardOpenArchive => 'arquivo';

  @override
  String get feedBoardGamesLabel => 'OS JOGOS';

  @override
  String get feedBoardGamesOpen => 'todos os jogos';

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
  String get gamesLoadFailed => 'não deu para carregar os jogos de hoje';

  @override
  String get gamesRetry => 'TENTAR DE NOVO';

  @override
  String get gameQueensName => 'rainhas';

  @override
  String get gameQueensRule =>
      'uma coroa por linha, coluna e cor — sem encostar';

  @override
  String get gameTangoName => 'tango';

  @override
  String get gameTangoRule => 'três sóis, três luas, nunca três seguidos';

  @override
  String get gameZipName => 'zip';

  @override
  String get gameZipRule =>
      'uma linha por todos os quadrados, números em ordem';

  @override
  String get gameSudokuName => 'mini sudoku';

  @override
  String get gameSudokuRule => 'de 1 a 6 uma vez por linha, coluna e bloco';

  @override
  String get gameCodeName => 'o código';

  @override
  String get gameStatusUnplayed => 'não jogado';

  @override
  String get gameStatusUnfinished => 'em andamento';

  @override
  String get gameStatusGaveUp => 'desistiu';

  @override
  String gameRankBadge(Object rank) {
    return '#$rank';
  }

  @override
  String get gamePause => 'pausar';

  @override
  String get gameResume => 'continuar';

  @override
  String get gamePausedTitle => 'em pausa';

  @override
  String get gamePausedBody => 'o relógio está parado e o tabuleiro escondido';

  @override
  String get gameUndo => 'desfazer';

  @override
  String get gameClear => 'limpar';

  @override
  String get gameHint => 'dica';

  @override
  String get gameNotes => 'anotações';

  @override
  String get gameErase => 'apagar';

  @override
  String get gameAutoCross => 'cruzes automáticas';

  @override
  String get gameGiveUp => 'desistir';

  @override
  String get gameGiveUpTitle => 'mostrar a resposta?';

  @override
  String get gameGiveUpBody =>
      'o tabuleiro de hoje fecha e fica como não resolvido.';

  @override
  String get gameGiveUpCancel => 'CONTINUAR';

  @override
  String get gameGiveUpConfirm => 'MOSTRAR';

  @override
  String gameSolvedTitle(Object time) {
    return 'resolvido em $time';
  }

  @override
  String get gameGaveUpTitle => 'a resposta de hoje';

  @override
  String get gameFirstInToday => 'o primeiro de hoje';

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
  String get gameStandingsLabel => 'TEMPOS DE HOJE';

  @override
  String get gameStandingsEmpty => 'ninguém terminou esse ainda';

  @override
  String get gameShare => 'COPIAR RESULTADO';

  @override
  String get gameShareCopied => 'copiado — cola pra um amigo';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => 'todos os jogos';

  @override
  String get gameElapsedSemantic => 'tempo decorrido';

  @override
  String get gameErrorNotSolved => 'esse tabuleiro ainda não está completo';

  @override
  String get gameErrorAlreadyFinished => 'você já terminou o de hoje';

  @override
  String get gameErrorNoHint => 'esse não tem dica';

  @override
  String get gameErrorGeneric =>
      'não deu para conectar aos jogos — tente de novo';

  @override
  String get gameInfoOpen => 'como jogar';

  @override
  String get gameInfoLabel => 'COMO JOGAR';

  @override
  String get gameInfoRulesLabel => 'AS REGRAS';

  @override
  String get gameInfoControlsLabel => 'CONTROLES';

  @override
  String get gameInfoScoringTimed =>
      'o relógio corre enquanto o tabuleiro está na tela e para se você pausar ou sair. quem for mais rápido lidera a lista de hoje.';

  @override
  String get gameInfoScoringGuesses =>
      'a pontuação é pelo número de tentativas, não pelo tempo.';

  @override
  String get gameInfoSameForEveryone =>
      'hoje todo mundo joga o mesmo tabuleiro.';

  @override
  String get gameInfoGotIt => 'ENTENDI';

  @override
  String get gameInfoQueensGoal =>
      'coloque uma coroa em cada linha, coluna e cor.';

  @override
  String get gameInfoQueensRule1 =>
      'oito coroas: uma em cada linha e uma em cada coluna.';

  @override
  String get gameInfoQueensRule2 =>
      'cada bloco de cor recebe também exatamente uma coroa.';

  @override
  String get gameInfoQueensRule3 =>
      'duas coroas não podem se encostar, nem pela quina.';

  @override
  String get gameInfoQueensControls =>
      'toque numa casa uma vez para um X que a descarta, de novo para uma coroa e de novo para limpar.';

  @override
  String get gameInfoTangoGoal => 'preencha a grade com sóis e luas.';

  @override
  String get gameInfoTangoRule1 =>
      'cada linha e coluna tem três sóis e três luas.';

  @override
  String get gameInfoTangoRule2 =>
      'nunca três iguais seguidos, na horizontal ou na vertical.';

  @override
  String get gameInfoTangoRule3 =>
      'um = entre duas casas significa que são iguais; um × que são diferentes.';

  @override
  String get gameInfoTangoControls =>
      'toque numa casa para um sol, de novo para uma lua e de novo para limpar. as casas impressas não mudam.';

  @override
  String get gameInfoZipGoal =>
      'desenhe uma linha que passe por todos os quadrados.';

  @override
  String get gameInfoZipRule1 => 'comece no 1 e termine no último número.';

  @override
  String get gameInfoZipRule2 =>
      'passe pelos números em ordem ao longo do caminho.';

  @override
  String get gameInfoZipRule3 => 'cada quadrado é usado exatamente uma vez.';

  @override
  String get gameInfoZipControls =>
      'arraste o dedo para desenhar. volte por cima da linha para apagar.';

  @override
  String get gameInfoSudokuGoal =>
      'preencha a grade com os algarismos de 1 a 6.';

  @override
  String get gameInfoSudokuRule1 => 'cada linha usa de 1 a 6, uma vez cada.';

  @override
  String get gameInfoSudokuRule2 => 'cada coluna, igual.';

  @override
  String get gameInfoSudokuRule3 => 'e cada bloco de 2x3, também.';

  @override
  String get gameInfoSudokuControls =>
      'toque numa casa e depois num algarismo. toque no mesmo algarismo de novo para apagar. o modo anotações escreve marquinhas a lápis.';

  @override
  String get gameInfoCodeGoal =>
      'descubra o código escondido de quatro símbolos.';

  @override
  String get gameInfoCodeRule1 =>
      'seis tentativas, e o código nunca repete um símbolo.';

  @override
  String get gameInfoCodeRule2 =>
      'verde significa símbolo certo no lugar certo.';

  @override
  String get gameInfoCodeRule3 =>
      'amarelo significa símbolo certo no lugar errado.';

  @override
  String get gameInfoCodeControls =>
      'toque nos símbolos para montar um palpite e envie. o tabuleiro mostra o quão perto você chegou.';

  @override
  String get savedMessagesTitle => 'Mensagens salvas';

  @override
  String homeScreenNoSearchResults(Object query) {
    return 'nenhum chat corresponde a \"$query\"';
  }

  @override
  String get pullRevealSearchHint => 'buscar chats…';

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
  String get archivedChatsSheetTitle => 'CHATS ARQUIVADOS';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'CHATS ARQUIVADOS · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'nada mais arquivado';

  @override
  String get pinnedBadgeLabel => 'FIXADA';

  @override
  String get chatRowActionMenuPinLabel => 'FIXAR CHAT';

  @override
  String get chatRowActionMenuUnpinLabel => 'DESAFIXAR CHAT';

  @override
  String get chatRowActionMenuArchiveLabel => 'ARQUIVAR CHAT';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'DESARQUIVAR CHAT';

  @override
  String get messageActionMenuSaveLabel => 'SALVAR';

  @override
  String get messageActionMenuUnsaveLabel => 'REMOVER';

  @override
  String get roomScreenSaveLimitSnack =>
      'muitas mensagens salvas aqui — remova uma primeiro';

  @override
  String get roomScreenSaveFailedSnack => 'não deu pra salvar isso';

  @override
  String get threadOverlaySaveLimitToast =>
      'muitas mensagens salvas aqui — remova uma primeiro';

  @override
  String get threadOverlaySaveFailedToast => 'não deu pra salvar isso';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      'só você vê as mensagens que salva — uma mensagem fixada é o oposto: a sala inteira vê.';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return 'Ir para a mensagem salva de $name';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return 'Remover das salvas a mensagem de $name';
  }

  @override
  String get muteSheetTitle => 'SILENCIAR CONVERSA';

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
  String get muteSheetDurationLabel => 'POR QUANTO TEMPO';

  @override
  String get muteDurationHour => '1 hora';

  @override
  String get muteDurationEightHours => '8 horas';

  @override
  String get muteDurationWeek => '1 semana';

  @override
  String get muteDurationAlways => 'Sempre';

  @override
  String get muteSheetConfirmButton => 'SILENCIAR';

  @override
  String get muteSheetSaveButton => 'SALVAR';

  @override
  String get muteSheetUnmuteButton => 'REATIVAR';

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
  String get chatRowActionMenuMuteLabel => 'SILENCIAR CONVERSA';

  @override
  String get chatRowActionMenuUnmuteLabel => 'REATIVAR CONVERSA';

  @override
  String get roomInfoScreenMuteLabel => 'SILÊNCIO';

  @override
  String get roomInfoScreenNotMutedRow => 'Não silenciada';

  @override
  String get attachmentMenuLocationLabel => 'localização';

  @override
  String get locationSheetSendCurrent => 'Enviar localização atual';

  @override
  String get locationSheetSendCurrentDetail => 'Onde você está agora';

  @override
  String get locationSheetLiveHeading => 'COMPARTILHAR AO VIVO';

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
      'Pode compartilhar onde está, inclusive ao vivo por até 8 horas';

  @override
  String get childPolicyScreenLocationOffDesc =>
      'Não pode compartilhar onde está';

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
  String get videoNoteMessagePlayLabel => 'reproduzir nota de vídeo';

  @override
  String get videoNoteMessagePauseLabel => 'pausar nota de vídeo';

  @override
  String get videoNoteMessageLoadingLabel => 'carregando nota de vídeo';

  @override
  String get videoNoteMessageUnavailableLabel => 'nota de vídeo indisponível';

  @override
  String get videoNoteMessageRetryLabel => 'tentar novamente a nota de vídeo';

  @override
  String get videoNoteMessageRetryHint => 'toque para tentar de novo';

  @override
  String get videoNoteMessageDiscardLabel => 'descartar nota de vídeo';

  @override
  String get attachmentMenuVideoNoteLabel => 'nota de vídeo';

  @override
  String get cameraScreenPhotoModeLabel => 'FOTO';

  @override
  String get cameraScreenVideoModeLabel => 'VÍDEO';

  @override
  String get cameraScreenStartRecordingLabel => 'iniciar gravação';

  @override
  String get cameraScreenStopRecordingLabel => 'parar gravação';

  @override
  String get cameraScreenVideoFailedSnack =>
      'Não foi possível gravar esse vídeo.';

  @override
  String get scheduleSheetTitle => 'AGENDAR MENSAGEM';

  @override
  String get scheduleSheetSubtitle => 'Escreva agora. Sai quando você disser.';

  @override
  String get scheduleSheetWhenLabel => 'QUANDO';

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
  String get scheduleSheetConfirmButton => 'AGENDAR';

  @override
  String get scheduleSheetSaveButton => 'SALVAR';

  @override
  String scheduleSendsAtSentence(String when) {
    return 'Envia $when.';
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
  String get scheduleTimePickerTitle => 'ESCOLHER DATA E HORA';

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
  String scheduledPillJoin(String label, String time) {
    return '$label · $time';
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
  String get scheduledListTitle => 'AGENDADAS';

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
  String get scheduleEditTitle => 'EDITAR MENSAGEM';

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
}
