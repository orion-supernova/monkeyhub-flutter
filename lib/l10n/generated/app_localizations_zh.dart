// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => '无法连接服务器';

  @override
  String get bootErrorBody => 'Convex 初始化失败。';

  @override
  String get bootErrorRetry => '重试';

  @override
  String get incomingCallNotificationTitle => '来电';

  @override
  String get incomingCallFallbackCaller => '有人正在呼叫你';

  @override
  String get settingsLanguageRowLabel => '语言';

  @override
  String get languageScreenTitle => '语言。';

  @override
  String get languageScreenSubtitle => '选择应用内菜单和消息使用的语言';

  @override
  String get languageOptionSystem => '系统';

  @override
  String get languageOptionSystemSub => '与设备的语言设置保持一致';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => '当前';

  @override
  String get languageValueSystem => '系统';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack => '现在问不了，再试一次';

  @override
  String get roomScreenGateSendMessages => '在这里发消息';

  @override
  String get roomScreenGateSendMedia => '发送图片或语音';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return '一次最多选择 $max 条';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '删除 $count 条消息',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody => '这会把消息从聊天里所有人那删除，且无法撤销。';

  @override
  String get roomScreenDeleteConfirmButton => '为所有人删除';

  @override
  String get roomScreenJumpFailedSnack => '无法跳转到该消息';

  @override
  String get roomScreenUnreadDivider => '未读消息';

  @override
  String get roomScreenViewOnceAlreadyViewed => '你已经打开过这张照片了。';

  @override
  String get roomScreenViewOnceGone => '这张照片已不可用。';

  @override
  String get roomScreenViewOnceNetworkError => '无法加载这张照片。';

  @override
  String get roomScreenFileReadFailedSnack => '无法读取该文件';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return '文件大小上限为 $size';
  }

  @override
  String get roomScreenRoomGone => '聊天室已不存在';

  @override
  String get roomScreenCopiedSnack => '已复制';

  @override
  String get roomScreenNameCopiedSnack => '文件名已复制';

  @override
  String get roomScreenPinLimitSnack => '置顶太多了，先取消一条';

  @override
  String get roomScreenPinFailedSnack => '无法置顶这条消息';

  @override
  String get roomScreenReportSentSnack => '举报已私密发送，对方不会收到通知。';

  @override
  String get roomScreenDeselectMessageSemantic => '取消选择消息';

  @override
  String get roomScreenSelectMessageSemantic => '选择消息';

  @override
  String roomScreenMemberCountBadge(Object count) {
    return '$count 人在内';
  }

  @override
  String roomScreenTtlSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 秒',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时',
    );
    return '$_temp0';
  }

  @override
  String roomScreenEphemeralNotice(Object ttl) {
    return '这是一个限时房间，消息无论已读还是未读，都会在 $ttl 后自动消失。';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count 条消息';
  }

  @override
  String get roomScreenSecretSpaceTitle => '秘密空间';

  @override
  String get roomScreenSecretSpaceBody => '这个房间里的消息是限时的，会根据房间的安全策略自动删除。';

  @override
  String get roomScreenAutoDeleteTitle => '自动删除';

  @override
  String get roomScreenAutoDeleteVaries => '不固定';

  @override
  String get roomScreenAutoDeleteTimed => '定时';

  @override
  String get roomScreenNoCaptureTitle => '禁止截屏';

  @override
  String get roomScreenNoCaptureSubtitle => '截屏受限';

  @override
  String get roomScreenMorePrivacyTitle => '更多隐私保护';

  @override
  String get roomScreenMorePrivacySubtitle => '在原有隐私保护基础上，享受更多安全功能。';

  @override
  String get roomScreenNoMessagesTitle => '暂无消息';

  @override
  String get roomScreenNoMessagesSubtitle => '发送一条消息，开启对话吧';

  @override
  String get roomScreenViewProfilePictureSemantic => '查看头像';

  @override
  String get roomScreenViewRoomPictureSemantic => '查看房间头像';

  @override
  String get messageBubbleFileFallbackName => '已发送文档';

  @override
  String get messageBubbleAttachmentStatusFailed => '发送失败';

  @override
  String get messageBubbleAttachmentStatusSending => '发送中…';

  @override
  String get messageBubbleViewOnceOpened => '已查看';

  @override
  String get messageBubbleViewOnceExpired => '已过期';

  @override
  String get messageBubbleViewOnceLabel => '阅后即焚';

  @override
  String get messageBubbleViewOnceTapToView => '点击查看';

  @override
  String get messageBubbleViewOncePhotoLabel => '照片';

  @override
  String get messageBubbleViewOnceSemanticLabel => '阅后即焚照片，点击查看';

  @override
  String get messageBubbleRetrySendingSemanticLabel => '重新发送';

  @override
  String get messageBubbleDiscardSemanticLabel => '放弃发送';

  @override
  String get profileScreenAccountSection => '账户';

  @override
  String get profileScreenAddEmailPlaceholder => '添加邮箱';

  @override
  String get profileScreenAddEmailTitle => '添加邮箱？';

  @override
  String get profileScreenAddNameTitle => '添加名字？';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count 项待批准';
  }

  @override
  String get profileScreenApprovalsLabel => '审批';

  @override
  String get profileScreenApprovalsNothingWaiting => '暂无待批准';

  @override
  String get profileScreenApproveAction => '接受';

  @override
  String get profileScreenBlockAction => '拉黑';

  @override
  String get profileScreenBlockedDmWiped => '已拉黑，私信记录也清空了，对方不会收到通知。';

  @override
  String get profileScreenBlockedOnly => '已拉黑，对方不会收到通知。';

  @override
  String get profileScreenBlockedUsers => '黑名单';

  @override
  String get profileScreenCancelAction => '取消';

  @override
  String get profileScreenCancelRequestAction => '取消请求';

  @override
  String get profileScreenChangeAction => '修改';

  @override
  String get profileScreenChangeEmailTitle => '修改邮箱？';

  @override
  String get profileScreenChangeNameTitle => '修改名字？';

  @override
  String get profileScreenChangeProfilePictureSemantic => '更换头像';

  @override
  String get profileScreenChangeRecoveryPhrase => '修改恢复短语';

  @override
  String get profileScreenChooseFromLibrary => '从相册选择';

  @override
  String get profileScreenCouldNotSaveImage => '图片保存失败。';

  @override
  String get profileScreenDeleteAccount => '删除账号';

  @override
  String get profileScreenEmailHint => '选填，不会展示给任何人';

  @override
  String get profileScreenEmailSectionLabel => '邮箱';

  @override
  String get profileScreenErrorAlreadyFriends => '你们已经是好友了。';

  @override
  String get profileScreenErrorGeneric => '没能完成这个操作。';

  @override
  String get profileScreenErrorNotAccepting => '对方现在不接受好友请求。';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      '对方已经给你发过请求了——去看看请求列表吧。';

  @override
  String get profileScreenErrorRequestAlreadySent => '请求已经发送过了。';

  @override
  String get profileScreenErrorUnblockFirst => '你已经拉黑了这个人——先取消拉黑吧。';

  @override
  String get profileScreenErrorUserNotFound => '此操作目前无法进行。';

  @override
  String get profileScreenNameNotSaved => '无法保存你的名称，请重试。';

  @override
  String get profileScreenFamilyAddChild => '添加孩子';

  @override
  String profileScreenFamilyChildCount(num count) {
    return '$count 个孩子';
  }

  @override
  String get profileScreenFamilyLabel => '家庭';

  @override
  String get profileScreenFriendsChip => '好友';

  @override
  String get profileScreenGrownUpOnlyNote => '只有大人才能这么做——需要他们的验证码或密码。';

  @override
  String get profileScreenGuardiansCanSee => '他们能看到你什么时候在线，还有你在跟谁聊天。';

  @override
  String get profileScreenHandPhoneBack => '归还手机';

  @override
  String get profileScreenIncomingRequestChip => '收到的请求';

  @override
  String get profileScreenJustTappedAction => '手滑了';

  @override
  String get settingsScreenSectionHelpAndLegal => '帮助与法律';

  @override
  String get settingsScreenLicence => '许可证';

  @override
  String get profileScreenLinkedAccountsLabel => '关联账号';

  @override
  String get profileScreenLinkedAccountsNone => '未关联任何账号';

  @override
  String get profileScreenMyGrownUps => '我的大人';

  @override
  String get profileScreenNameHint => '这是聊天室里显示的名字';

  @override
  String get profileScreenChangeUsernameTitle => '更改用户名？';

  @override
  String get profileScreenChangeUsernameWarning =>
      '你用它登录，所以以后要输入新的用户名。旧的用户名会被释放，其他人可以使用，并且 30 天内不能再次更改。之前提到你的旧消息仍会显示旧的用户名。';

  @override
  String get profileScreenUsernameHint => '朋友这样找到你';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return '$date 起可再次更改';
  }

  @override
  String get profileScreenUsernamePasswordTitle => '确认是你本人';

  @override
  String get profileScreenUsernamePasswordAction => '更改用户名';

  @override
  String get profileScreenUsernameProviderTitle => '用你的登录方式确认';

  @override
  String profileScreenUsernameChanged(String username) {
    return '你现在是 @$username。';
  }

  @override
  String get profileScreenUsernameNotSaved => '无法更改你的用户名。请重试。';

  @override
  String get usernameStatusChecking => '检查中…';

  @override
  String get usernameStatusAvailable => '可以使用';

  @override
  String get usernameStatusTaken => '已被使用';

  @override
  String get usernameStatusReserved => '无法使用';

  @override
  String get usernameStatusInvalid => '1–32 个字符';

  @override
  String get usernameStatusUnknown => '无法检查';

  @override
  String get profileScreenNobodyLookingAfter => '还没有大人在照看这个账号';

  @override
  String get profileScreenNotAcceptingRequestsAction => '不接受好友请求';

  @override
  String get profileScreenNotConnectedChip => '未添加好友';

  @override
  String get profileScreenOpenDmAction => '打开私信';

  @override
  String get profileScreenPhotoPermissionDenied => '相册权限被拒绝。';

  @override
  String get settingsScreenPrivacyPolicy => '隐私政策';

  @override
  String get profileScreenPrivacySection => '隐私';

  @override
  String get profileScreenProfilePictureTitle => '头像';

  @override
  String get profileScreenRedactedFriend => '部分资料因对方的隐私设置被隐藏。';

  @override
  String get profileScreenRedactedStranger => '内容有限——加为好友可以看到更多。';

  @override
  String get profileScreenReportAction => '举报';

  @override
  String get profileScreenReportSent => '举报已提交，对方不会收到通知。';

  @override
  String get profileScreenRequestPendingChip => '请求已发送';

  @override
  String get profileScreenSaveAction => '保存';

  @override
  String get profileScreenSavedToPhotos => '已保存到相册。';

  @override
  String get profileScreenSaveToPhotos => '保存到相册';

  @override
  String get profileScreenSendRequestAction => '发送请求';

  @override
  String get profileScreenSetUpRecoveryPhrase => '设置恢复短语';

  @override
  String get profileScreenSignOut => '退出登录';

  @override
  String get profileScreenTakeSelfie => '拍摄自拍';

  @override
  String get profileScreenTapAgainToConfirmDelete => '再次点击确认删除';

  @override
  String get settingsScreenTermsOfService => '服务条款';

  @override
  String get profileScreenThisPhoneSection => '这部手机';

  @override
  String get profileScreenUnfriendAction => '删除好友';

  @override
  String get profileScreenViewProfilePictureSemantic => '查看头像';

  @override
  String get profileScreenVisibilityPreferences => '可见性设置';

  @override
  String get cameraEditorScreenCropPresetFree => '自由';

  @override
  String get cameraEditorScreenCropPresetOriginal => '原始';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => '取消裁剪';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => '放弃照片';

  @override
  String get cameraEditorScreenUndoSemanticLabel => '撤销';

  @override
  String get cameraEditorScreenRedoSemanticLabel => '重做';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => '重置裁剪';

  @override
  String get cameraEditorScreenRotateSemanticLabel => '旋转';

  @override
  String get cameraEditorScreenCropSemanticLabel => '裁剪';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage => '此浏览器无法打开 HEIC 格式照片';

  @override
  String get cameraEditorScreenImageLoadFailedMessage => '无法打开这张图片';

  @override
  String get cameraEditorScreenCropDoneButton => '完成';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => '重拍';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => '收起画笔';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => '在照片上绘画';

  @override
  String get cameraEditorScreenSendingButton => '发送中…';

  @override
  String get cameraEditorScreenSendButton => '发送';

  @override
  String get cameraEditorScreenViewOnceNote => '打开一次后就会消失';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => '清除涂鸦';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel => '阅后即焚：已开启';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel => '阅后即焚：已关闭';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD：开';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD：关';

  @override
  String get cameraEditorScreenHdNote => '将以原始分辨率发送';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => '画笔颜色';

  @override
  String get glassScreenPanelLooks => '外观';

  @override
  String get glassScreenPanelBottomBar => '底部栏';

  @override
  String get glassScreenPanelOtherSurfaces => '其他表面';

  @override
  String get glassScreenPanelBarLayout => '栏布局';

  @override
  String get glassScreenTitle => '玻璃.';

  @override
  String get glassScreenSubtitle => '背后的内容能透出来多少';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return '全部 $max 个位置已满';
  }

  @override
  String get glassScreenSaveCurrentAs => '将当前外观另存为…';

  @override
  String get glassScreenResetEveryDial => '重置所有旋钮';

  @override
  String glassScreenResetToPreset(Object name) {
    return '重置为 $name';
  }

  @override
  String get glassScreenSurfacesNote => '输入框、顶部栏、通话按钮——所有浮在文字上方、而非滚动内容上方的元素';

  @override
  String get glassScreenMatchBottomBar => '匹配底部栏';

  @override
  String get glassScreenPresetEditedSubtitle => '已修改——另存为新外观，或重置';

  @override
  String get glassScreenCustomPresetName => '自定义';

  @override
  String get glassScreenUnsavedSubtitle => '未保存 — 给它起个名字才能保留';

  @override
  String get glassScreenSaveDialogTitle => '保存此效果为';

  @override
  String get glassScreenNoRoomToast => '空间不足 — 请先删除一个效果';

  @override
  String get glassScreenRenameDialogTitle => '重命名';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '删除$name？';
  }

  @override
  String get glassScreenDeleteConfirmBody => '效果仍会留在屏幕上 — 只是不再有名字。';

  @override
  String get glassScreenKeepButton => '保留';

  @override
  String get glassScreenDeleteButton => '删除';

  @override
  String get glassScreenNameHint => '深夜';

  @override
  String get glassScreenCancelButton => '取消';

  @override
  String get glassScreenSaveButton => '保存';

  @override
  String get glassScreenPreviewRoomName => '# 阳台';

  @override
  String get glassScreenPreviewOnlineCount => '4人在线';

  @override
  String get glassScreenPreviewMessageHint => '消息';

  @override
  String get glassScreenPreviewCollapseLabel => '收起预览';

  @override
  String get glassScreenPreviewExpandLabel => '展开预览';

  @override
  String get glassScreenPreviewBadge => '预览';

  @override
  String get glassScreenBuiltInLabel => '内置';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return '覆盖$name';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return '重命名$name';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return '删除$name';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return '重置$label';
  }

  @override
  String get glassScreenBackdropMsgDilan => '发了屋顶的照片——瓦片全裂了';

  @override
  String get glassScreenBackdropMsgMert => '行，但到底谁带音箱';

  @override
  String get glassScreenBackdropGroupFamily => '家人';

  @override
  String get glassScreenBackdropMsgFamily => '妈：晚饭8点，别再迟到了';

  @override
  String get glassScreenBackdropMsgZeynep => '我在外面了';

  @override
  String get glassScreenBackdropMsgKerem => '拐角那家咖啡不错';

  @override
  String get glassScreenBackdropGroupWork => '工作';

  @override
  String get glassScreenBackdropMsgWork => '站会这周剩下的时间都改到10:30了';

  @override
  String get glassScreenBackdropMsgElif => '不是吧，再发一次，我弄丢了';

  @override
  String get glassScreenBackdropMsgBaran => '落地啦👍';

  @override
  String get glassScreenBackdropMsgAyse => '猫学会开阳台门了';

  @override
  String get glassScreenBackdropMsgCan => '那周六见';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return '回复 $name';
  }

  @override
  String get replyIndicatorViewOnceLabel => '照片 · 阅后即焚';

  @override
  String get replyIndicatorVoiceMessageLabel => '语音消息';

  @override
  String get replyIndicatorDocumentLabel => '文件';

  @override
  String get replyIndicatorMessageRemoved => '消息已删除';

  @override
  String get threadOverlayMessageNotFound => '在这个话题串中找不到该消息';

  @override
  String get threadOverlayReplyTargetNotFound => '找不到要回复的话题串';

  @override
  String get threadOverlayStillSending => '还在发送中，稍后再试';

  @override
  String get threadOverlayCopiedToast => '已复制';

  @override
  String get threadOverlayNameCopiedToast => '已复制文件名';

  @override
  String get threadOverlayCoordinatesCopiedToast => '已复制坐标';

  @override
  String get threadOverlayPinLimitToast => '置顶已达上限，先取消一个';

  @override
  String get threadOverlayPinFailedToast => '置顶失败';

  @override
  String get threadOverlayReportedToast => '已举报';

  @override
  String get threadOverlayUnavailable => '话题串不可用';

  @override
  String get roomInfoScreenNameRequiredError => '名称不能为空';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => '密码已清除';

  @override
  String get roomInfoScreenLeaveConfirmTitle => '离开房间？';

  @override
  String get roomInfoScreenLeaveConfirmBody => '如果房间还开着，你可以重新加入。';

  @override
  String get roomInfoScreenLeaveConfirmButton => '离开';

  @override
  String get roomInfoScreenDeleteConfirmTitle => '删除房间？';

  @override
  String get roomInfoScreenDeleteConfirmBody => '这里的所有消息都会一并删除，无法恢复。';

  @override
  String get roomInfoScreenDeleteConfirmButton => '删除';

  @override
  String get roomInfoScreenEndConversationConfirmTitle => '结束这段对话？';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerName 也会失去这段对话 — 你们双方的所有消息都会消失，且无法恢复。';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => '结束';

  @override
  String get roomInfoScreenEndConversationPeerFallback => '对方';

  @override
  String get roomInfoScreenConfirmCancelButton => '取消';

  @override
  String get roomInfoScreenErrorRoomExists => '已经有同名房间了';

  @override
  String get roomInfoScreenErrorNotOwner => '只有房主才能这么做';

  @override
  String get roomInfoScreenErrorNotAuthorized => '你没有权限';

  @override
  String get roomInfoScreenErrorRoomNotFound => '这个房间已经不存在了';

  @override
  String get roomInfoScreenRoomGone => '房间已不存在';

  @override
  String get roomInfoScreenNameLabel => '名称';

  @override
  String get roomInfoScreenNameHint => '房间名称';

  @override
  String get roomInfoScreenDescriptionLabel => '描述';

  @override
  String get roomInfoScreenDescriptionHint => '用一句话介绍这个房间…';

  @override
  String get roomInfoScreenVisibilityLabel => '可见性';

  @override
  String get roomInfoScreenPublicTitle => '公开';

  @override
  String get roomInfoScreenPublicSub => '任何人都能找到';

  @override
  String get roomInfoScreenPrivateTitle => '私密';

  @override
  String get roomInfoScreenPrivateSub => '仅限邀请';

  @override
  String get roomInfoScreenMessageLifeLabel => '消息时效';

  @override
  String roomInfoScreenTtlSeconds(Object value) {
    return '$value秒';
  }

  @override
  String roomInfoScreenTtlMinutes(Object value) {
    return '$value分钟';
  }

  @override
  String roomInfoScreenTtlHours(Object value) {
    return '$value小时';
  }

  @override
  String get roomInfoScreenPasswordLabel => '密码';

  @override
  String get roomInfoScreenLockedBadge => '已锁定';

  @override
  String get roomInfoScreenNoneBadge => '无';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      '此聊天室已设密码保护。出于安全原因,系统不会显示当前密码——输入新密码即可替换。';

  @override
  String get roomInfoScreenReplacePasswordHint => '替换密码…';

  @override
  String get roomInfoScreenSetPasswordHint => '设置密码以锁定…';

  @override
  String get roomInfoScreenRemovePasswordButton => '移除密码';

  @override
  String get roomInfoScreenSharedContentLabel => '共享内容';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return '成员 · $count';
  }

  @override
  String get roomInfoScreenLeavingButton => '退出中…';

  @override
  String get roomInfoScreenLeaveRoomButton => '退出聊天室';

  @override
  String get roomInfoScreenDeletingButton => '删除中…';

  @override
  String get roomInfoScreenDeleteButtonLabel => '删除';

  @override
  String get roomInfoScreenEndingConversationButton => '结束中…';

  @override
  String get roomInfoScreenEndConversationButton => '结束对话';

  @override
  String get roomInfoScreenHeaderConversation => '对话';

  @override
  String get roomInfoScreenHeaderRoomSettings => '聊天室设置';

  @override
  String get roomInfoScreenViewProfilePictureSemantic => '查看头像';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => '查看聊天室头像';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => '更改聊天室头像';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => '添加聊天室头像';

  @override
  String get roomInfoScreenOwnerBadge => '房主';

  @override
  String get roomInfoScreenNoneCount => '无';

  @override
  String get cameraScreenAccessDeniedMessage => '相机权限未开启。\n请前往「设置」开启后再拍照。';

  @override
  String get cameraScreenOpeningSystemCamera => '正在打开系统相机…';

  @override
  String get cameraScreenCloseButtonLabel => '关闭相机';

  @override
  String get cameraScreenLowLightBoostOnLabel => '弱光增强:已开启';

  @override
  String get cameraScreenLowLightBoostOffLabel => '弱光增强:已关闭';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return '闪光灯：$mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => '从相册选择';

  @override
  String get cameraScreenSwitchCameraLabel => '切换摄像头';

  @override
  String get cameraScreenTakePhotoLabel => '拍照';

  @override
  String get childPolicyScreenAddByUsernameLabel => '按用户名添加';

  @override
  String get childPolicyScreenAddCta => '添加';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return '他们将拥有和你完全相同的权限：审批每一个请求、更改每一项设置，甚至可以把你移除。$name会立刻把他们当作家人。';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => '添加大人';

  @override
  String get childPolicyScreenAddGuardianHint => '对方的用户名';

  @override
  String get childPolicyScreenAllowCta => '允许';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return '以后不会再为这件事询问你了——无论是$childName添加他们，还是他们添加$childName。';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => '允许某人';

  @override
  String get childPolicyScreenAskToAddLabel => '申请添加';

  @override
  String get childPolicyScreenAskToAddOffDesc => '仅限家人——不接受新请求';

  @override
  String get childPolicyScreenAskToAddOnDesc => '他们可以向你申请添加新联系人';

  @override
  String get childPolicyScreenBothFinalNote => '这两项操作都无法撤销。如果只是想退出，请到“大人”里操作。';

  @override
  String get childPolicyScreenCallsLabel => '通话';

  @override
  String get childPolicyScreenCallsOffDesc => '仅限消息';

  @override
  String get childPolicyScreenCallsOnDesc => '可以和被允许的联系人语音、视频通话';

  @override
  String get childPolicyScreenCancelLabel => '取消';

  @override
  String get childPolicyScreenCancelSemanticLabel => '取消';

  @override
  String get childPolicyScreenContactAddedRequestSent => '已添加——请求正在发送';

  @override
  String get childPolicyScreenContactAddedToList => '已添加到允许列表';

  @override
  String get childPolicyScreenCreateRoomsLabel => '创建房间';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => '他们不能创建房间';

  @override
  String get childPolicyScreenCreateRoomsOnDesc => '他们可以创建自己的私密房间';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      '一切都会消失：他们的消息、照片、房间和好友。此操作无法撤销，用户名也会被释放给其他人使用。';

  @override
  String get childPolicyScreenDeleteAccountFailed => '无法删除账号——请重试';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return '删除$name的账号？';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail => '消息、照片、房间和好友都会被删除，且无法撤销。';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return '删除$name的账号';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => '永久删除';

  @override
  String get childPolicyScreenErrorAddContactGeneric => '无法添加——请重试';

  @override
  String get childPolicyScreenErrorCannotAddSelf => '这是他们自己的用户名';

  @override
  String get childPolicyScreenErrorChildNotAllowed => '孩子不能成为大人';

  @override
  String get childPolicyScreenErrorGenericGuardian => '没能完成——再试一次';

  @override
  String get childPolicyScreenErrorLastGuardian => '得有人照顾孩子——请先添加另一位大人';

  @override
  String get childPolicyScreenErrorNotYours => '这不是你能更改的';

  @override
  String get childPolicyScreenErrorUserNotFound => '找不到这个用户名对应的账号';

  @override
  String get childPolicyScreenGraduateBlurb =>
      '孩子会用这个密码变成普通账号,所有大人都将失去查看权限。此操作不可撤销——之后你就得像其他人一样,被邀请后才能重新加入。';

  @override
  String get childPolicyScreenGraduateCta => '毕业';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      '孩子保留一切,并获得一个密码。你将失去所有查看权限。不可撤销。';

  @override
  String get childPolicyScreenGraduateDangerLabel => '毕业成为完整账号';

  @override
  String get childPolicyScreenGraduateFailed => '毕业失败——再试一次';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return '让 $name 毕业';
  }

  @override
  String get childPolicyScreenGraduateHint => '给孩子的密码';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      '撤回房间的同时,也会把孩子移出该房间。撤回联系人的同时,还会删除双方的聊天记录。';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      '这里的每一位都能批准请求、修改设置、查看所有内容。任何一位都可以单独操作——不用等其他人。';

  @override
  String get childPolicyScreenGuardianAdded => '添加成功——现在可以照顾孩子了';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '已移除 $name';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name (你)';
  }

  @override
  String get childPolicyScreenLoading => '加载中…';

  @override
  String get childPolicyScreenLockedLabel => '已锁定';

  @override
  String get childPolicyScreenMediaLabel => '照片和语音';

  @override
  String get childPolicyScreenMediaOffDesc => '仅文字';

  @override
  String get childPolicyScreenMediaOnDesc => '可以发送图片、视频和语音消息';

  @override
  String get childPolicyScreenNoRoomsYet => '暂无房间';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      '这里的任何人都能直接添加,不需要再次征求你的同意——不管是谁先发起。';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      '对孩子始终关闭。发现——那些属于陌生人的房间列表——完全隐藏,且无法开启。别人邀请孩子加入的房间仍可正常使用。';

  @override
  String get childPolicyScreenPublicRoomsLabel => '公开房间';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardian 将无法再为 $child 查看或批准任何内容。';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return '移除 $name？';
  }

  @override
  String get childPolicyScreenRemoveLabel => '移除';

  @override
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count 人';
  }

  @override
  String get childPolicyScreenSectionGrownUps => '大人';

  @override
  String get childPolicyScreenSectionPeopleAllowed => '你已允许的联系人';

  @override
  String get childPolicyScreenSectionRoomsAllowed => '你已允许的房间';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => '孩子能做什么';

  @override
  String get childPolicyScreenSectionWhenDone => '不再需要该账号时';

  @override
  String get childPolicyScreenSendNowOffDesc => '要等有人添加对方才会生效';

  @override
  String get childPolicyScreenSendNowOnDesc => '对方会立刻收到请求';

  @override
  String get childPolicyScreenSendRequestNowLabel => '立即发送请求';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return '你是$name唯一的大人,不能直接退出——请先添加另一位大人,或者试试下面这些方式。';
  }

  @override
  String get childPolicyScreenStepAwayLabel => '退出';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return '你会失去查看$name账号的所有权限——他们的请求、联系人、聊天室,你都看不到了。其他大人会继续照看他们。';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => '停止监护';

  @override
  String get childPolicyScreenStopSupervisingHeadline => '停止监护?';

  @override
  String get childPolicyScreenTakeBackFailed => '没能收回——再试一次';

  @override
  String get childPolicyScreenTakeBackLabel => '收回';

  @override
  String get childPolicyScreenUsernameHint => '用户名';

  @override
  String get childPolicyScreenYou => '你';

  @override
  String get roomContentScreenDefaultDocumentName => '文档';

  @override
  String get roomContentScreenCouldntOpenFile => '没能打开这个文件';

  @override
  String get roomContentScreenCouldntShare => '没能分享这些内容';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已复制 $count 个链接',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '删除 $count 条消息',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody => '此操作会为聊天中的所有人删除,且无法撤销。';

  @override
  String get roomContentScreenDeleteForEveryone => '为所有人删除';

  @override
  String get roomContentScreenCancelTooltip => '取消';

  @override
  String get roomContentScreenBackTooltip => '返回';

  @override
  String get roomContentScreenSelectingLabel => '选择中';

  @override
  String get roomContentScreenSharedContentLabel => '共享内容';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选择 $count 项',
      zero: '未选择任何内容',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => '选择';

  @override
  String get roomContentScreenSelectAllActiveLabel => '全选';

  @override
  String get roomContentScreenEmptyMedia => '还没有照片或视频';

  @override
  String get roomContentScreenEmptyFiles => '还没有文件';

  @override
  String get roomContentScreenEmptyVoice => '还没有语音消息';

  @override
  String get roomContentScreenEmptyLinks => '还没有链接';

  @override
  String get roomContentScreenEmptySaved =>
      '还没有保存任何内容。长按一条消息并选择保存。\n\n你在这里保存的内容只有你能看到；置顶的消息则是整个房间都能看到。';

  @override
  String get roomContentScreenLoadFailed => '没能加载';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return '来自$name的语音消息';
  }

  @override
  String get roomContentScreenForwardAction => '转发';

  @override
  String get roomContentScreenCopyAction => '复制';

  @override
  String get roomContentScreenSaveAction => '保存';

  @override
  String get roomContentScreenShareAction => '分享';

  @override
  String get roomContentScreenInChatAction => '跳转到聊天';

  @override
  String get roomContentScreenDeleteAction => '删除';

  @override
  String get messageActionMenuReplyLabel => '回复';

  @override
  String get messageActionMenuEditLabel => '编辑';

  @override
  String get messageStampEditedLabel => '已编辑';

  @override
  String get composerEditCardTitle => '编辑消息';

  @override
  String get spoilerRevealHint => '剧透，激活后可显示隐藏的文字';

  @override
  String get formatToolbarFormatLabel => '格式';

  @override
  String get formatToolbarBoldLabel => '粗体';

  @override
  String get formatToolbarItalicLabel => '斜体';

  @override
  String get formatToolbarStrikethroughLabel => '删除线';

  @override
  String get formatToolbarUnderlineLabel => '下划线';

  @override
  String get formatToolbarSpoilerLabel => '剧透';

  @override
  String get formatToolbarLinkLabel => '链接';

  @override
  String get formatToolbarCodeLabel => '代码';

  @override
  String get linkInputSheetTitle => '链接';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => '应用链接';

  @override
  String get linkInputSheetApplySub => '点按所选文字将打开此地址';

  @override
  String get linkInputSheetRemoveLabel => '移除链接';

  @override
  String get linkConfirmSheetTitle => '打开此链接？';

  @override
  String get linkConfirmSheetOpenLabel => '打开链接';

  @override
  String get linkConfirmSheetCancelLabel => '取消';

  @override
  String get roomScreenEditExpiredSnack => '来不及编辑了，消息只能在 15 分钟内编辑。';

  @override
  String get roomScreenEditFailedSnack => '无法保存编辑。请检查网络连接后重试。';

  @override
  String get messageActionMenuForwardLabel => '转发';

  @override
  String get messageActionMenuViewThreadLabel => '查看话题串';

  @override
  String get messageActionMenuCopyLabel => '复制';

  @override
  String get messageActionMenuCopyNameLabel => '复制文件名';

  @override
  String get messageActionMenuCopyCoordinatesLabel => '复制坐标';

  @override
  String get messageActionMenuPinLabel => '置顶';

  @override
  String get messageActionMenuUnpinLabel => '取消置顶';

  @override
  String get messageActionMenuSelectLabel => '多选';

  @override
  String get messageActionMenuProfileLabel => '资料';

  @override
  String get messageActionMenuDeleteLabel => '删除';

  @override
  String get messageActionMenuReportLabel => '举报';

  @override
  String get themeScreenTitle => '主题。';

  @override
  String get themeScreenTapToApplyHint => '点击应用 · ⛶ 查看完整预览';

  @override
  String get themeScreenFamilyBasicName => '基础';

  @override
  String get themeScreenFamilyBasicTagline => 'iOS 风格 · 5 种配色';

  @override
  String get themeScreenFamilyVaultName => '保险库';

  @override
  String get themeScreenFamilyVaultTagline => '私密档案 · 暗黑 + 象牙白';

  @override
  String get themeScreenFamilyOthersName => '其他';

  @override
  String get themeScreenFamilyOthersTagline => '独特氛围';

  @override
  String get themeScreenActiveBadge => '使用中';

  @override
  String get themeScreenTapToApplyLabel => '点击应用';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return '使用中 — $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return '应用 $name';
  }

  @override
  String get themeScreenPreviewGreeting => '嘿，你。';

  @override
  String get themeScreenPreviewSectionLabel => '对话';

  @override
  String get themeScreenPreviewRoomOneName => '设计俱乐部';

  @override
  String get themeScreenPreviewRoomOneSub => 'mia:上线了新卡片。';

  @override
  String get themeScreenPreviewRoomTwoName => '密室 · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => '4小时后封存。';

  @override
  String get themeScreenPreviewBubbleQuestion => '感觉怎么样？';

  @override
  String get themeScreenPreviewBubbleAnswer => '感觉就是它了。';

  @override
  String get callScreenVideoCallLabel => '视频来电';

  @override
  String get callScreenVoiceCallLabel => '语音来电';

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · 呼叫中…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind · 来电';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind · 连接中…';
  }

  @override
  String get callScreenStatusConnected => '已连接';

  @override
  String get callScreenStatusEnded => '通话已结束';

  @override
  String get callScreenStatusFailed => '通话失败';

  @override
  String get callScreenStatusSwitching => '正在切换设备…';

  @override
  String get callScreenStatusMoved => '已转移';

  @override
  String get callScreenStatusReconnecting => '重新连接中…';

  @override
  String get callScreenPoorConnectionLabel => '网络连接差';

  @override
  String get callScreenWeakConnectionLabel => '网络信号弱';

  @override
  String get callScreenControlUnmute => '取消静音';

  @override
  String get callScreenControlMute => '静音';

  @override
  String get callScreenControlCamOn => '开镜头';

  @override
  String get callScreenControlCamOff => '关镜头';

  @override
  String get callScreenControlFlip => '翻转';

  @override
  String get callScreenControlSpeaker => '扬声器';

  @override
  String get callScreenControlEnd => '挂断';

  @override
  String get linkPreviewCardLinkLabel => '链接';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$name 接受了你的请求';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar => '对方撤回了该请求';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => '请求已被拒绝';

  @override
  String get friendRequestDraftScreenErrorBlocked => '你已拉黑该用户,请先解除拉黑。';

  @override
  String get friendRequestDraftScreenErrorNotAccepting => '对方现在不接受好友请求。';

  @override
  String get friendRequestDraftScreenErrorSendFailed => '发送失败,请重试。';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => '对方发来的请求';

  @override
  String get friendRequestDraftScreenNewRequestLabel => '我发出的请求';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$name 想找你聊天。';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing => '写几句话吧,对方可以同意或拒绝。';

  @override
  String get friendRequestDraftScreenIntroFooter => '双方都同意之前,这里的内容不会永久保留。';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => '房间类型';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => '阅后即焚';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => '标准';

  @override
  String get friendRequestDraftScreenLifetimeLabel => '有效期';

  @override
  String friendRequestDraftScreenDurationSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String friendRequestDraftScreenDurationMinutes(Object minutes) {
    return '$minutes分钟';
  }

  @override
  String friendRequestDraftScreenDurationHours(Object hours) {
    return '$hours小时';
  }

  @override
  String get friendRequestDraftScreenHintWhisperOptional => '写句悄悄话 · 可选';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional => '加一句开场白 · 可选';

  @override
  String get friendRequestDraftScreenHintWhisperFades => '悄悄话 · 自动消失';

  @override
  String get friendRequestDraftScreenHintStartWith => '先说点什么…';

  @override
  String get friendRequestDraftScreenApproveButton => '接受请求并打开房间';

  @override
  String get friendRequestDraftScreenDeclineButton => '拒绝请求';

  @override
  String get friendRequestDraftScreenCancelRequestButton => '撤回请求';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => '问问大人';

  @override
  String get friendRequestDraftScreenSendRequestButton => '发送请求';

  @override
  String get discoverScreenTitle => '发现。';

  @override
  String get discoverScreenCaptionPeople => '用户';

  @override
  String get discoverScreenCaptionRooms => '房间';

  @override
  String get discoverScreenCaptionRequests => '请求';

  @override
  String get discoverScreenPeopleBandLabel => '用户';

  @override
  String get discoverScreenRoomsBandLabel => '房间';

  @override
  String get discoverScreenFindPeopleTitle => '找人';

  @override
  String get discoverScreenFindPeopleSubtitleChild => '需要输入完整用户名';

  @override
  String get discoverScreenFindPeopleSubtitleAdult => '通过 @用户名 或昵称搜索';

  @override
  String get discoverScreenRequestsSectionLabel => '请求';

  @override
  String get discoverScreenInboxQuiet => '收件箱静悄悄';

  @override
  String get discoverScreenNothingPending => '尚未发送';

  @override
  String get discoverScreenYourPeopleLabel => '我的好友';

  @override
  String get discoverScreenNoFriendsYetWithHint => '还没有人 · 去上面找人吧';

  @override
  String get discoverScreenNoFriendsYet => '还没有人';

  @override
  String get discoverScreenSearchRoomsTitle => '搜索房间';

  @override
  String get discoverScreenSearchRoomsSubtitle => '按名称搜索公开房间';

  @override
  String get discoverScreenYourRoomsLabel => '我的房间';

  @override
  String get discoverScreenNoRoomsYet => '还没有房间';

  @override
  String get discoverScreenIncomingLabel => '收到';

  @override
  String get discoverScreenOutgoingLabel => '发出';

  @override
  String get discoverScreenIncomingLabelCaps => '收到';

  @override
  String get discoverScreenOutgoingLabelCaps => '发出';

  @override
  String get discoverScreenJumpPeopleLabel => '用户';

  @override
  String get discoverScreenJumpRoomsLabel => '房间';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return '跳转到$label';
  }

  @override
  String get imageCropScreenDefaultTitle => '调整';

  @override
  String get imageCropScreenDefaultConfirmLabel => '使用照片';

  @override
  String get imageCropScreenSavingButton => '保存中…';

  @override
  String get imageCropScreenCancelButton => '取消';

  @override
  String get imageCropScreenHeicUnsupported => '此浏览器无法打开 HEIC 格式的照片';

  @override
  String get imageCropScreenLoadFailed => '无法打开该图片';

  @override
  String get imageCropScreenHintCircle => '拖动移动,双指缩放';

  @override
  String get imageCropScreenHintRect => '拖动和捏合调整取景框';

  @override
  String get loginScreenSignInHeroMuted => '欢迎\n';

  @override
  String get loginScreenSignInHeroInk => '回来。';

  @override
  String get loginScreenSignInFirstHeroMuted => '欢迎\n';

  @override
  String get loginScreenSignInFirstHeroInk => '光临。';

  @override
  String get loginScreenSignInCta => '登录';

  @override
  String get loginScreenSignUpHeroMuted => '新\n';

  @override
  String get loginScreenSignUpHeroInk => '面孔。';

  @override
  String get loginScreenSignUpCta => '开通账号';

  @override
  String get loginScreenResetHeroMuted => '重置\n';

  @override
  String get loginScreenResetHeroInk => '密码。';

  @override
  String get loginScreenResetCta => '重置密码';

  @override
  String get loginScreenErrorPasswordsDontMatch => '两次输入的密码不一致。';

  @override
  String get loginScreenErrorChoosePasswordFirst => '请先设置密码。';

  @override
  String get loginScreenUsernameHint => '用户名';

  @override
  String get loginScreenPasswordHint => '密码';

  @override
  String get loginScreenConfirmPasswordHint => '确认密码';

  @override
  String get loginScreenNameOptionalHint => '昵称(选填)';

  @override
  String get loginScreenRecoveryPhraseHint => '你的12词恢复短语';

  @override
  String get loginScreenNewPasswordHint => '新密码';

  @override
  String get loginScreenBackToSignIn => '← 返回登录';

  @override
  String get loginScreenForgotPassword => '忘记密码?';

  @override
  String get loginScreenSettingUpKidsPhone => '设置儿童账号';

  @override
  String get loginScreenLegalPrefix => '开通账号即表示你同意';

  @override
  String get loginScreenLegalTermsLink => '服务条款';

  @override
  String get loginScreenLegalMiddle => '和';

  @override
  String get loginScreenLegalPrivacyLink => '隐私政策';

  @override
  String get loginScreenLegalSuffix => '。';

  @override
  String get loginScreenAlreadyHerePrompt => '已经有账号了？';

  @override
  String get loginScreenSignInLink => '登录';

  @override
  String get loginScreenNoAccountPrompt => '还没有账号？';

  @override
  String get loginScreenOpenOneLink => '去注册';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12 个词';
  }

  @override
  String get homeShellEmptyRoomHint => '选一个聊天室开始聊天';

  @override
  String get homeShellEmptySettingHint => '选一项设置';

  @override
  String get searchScreenHintPeople => '搜索用户…';

  @override
  String get searchScreenHintRooms => '搜索聊天室…';

  @override
  String get searchScreenPeoplePromptChild => '输入完整用户名才能找到新朋友';

  @override
  String get searchScreenPeoplePromptDefault => '按用户名或昵称搜索';

  @override
  String get searchScreenNoMatchChild => '没有匹配结果 —— 添加新朋友\n需要完整且准确的用户名';

  @override
  String get searchScreenNoMatchDefault => '没有匹配结果';

  @override
  String get searchScreenNoRoomsYet => '暂无公开聊天室';

  @override
  String get searchScreenNoRoomsMatch => '没有匹配的公开聊天室';

  @override
  String get searchScreenActionAskToAdd => '申请添加';

  @override
  String get searchScreenActionSendRequest => '发送请求';

  @override
  String get searchScreenActionCancel => '撤回请求';

  @override
  String get searchScreenActionApprove => '接受请求';

  @override
  String get searchScreenActionOpenDm => '打开私聊';

  @override
  String get searchScreenAskedLabel => '已申请';

  @override
  String get profileVisibilityScreenTitle => '可见性偏好。';

  @override
  String get profileVisibilityScreenSubtitle => '控制别人能看到什么，以及他们能怎样联系到你。';

  @override
  String get profileVisibilityScreenSectionProfile => '个人资料';

  @override
  String get profileVisibilityScreenAvatarLabel => '头像';

  @override
  String get profileVisibilityScreenAvatarDesc => '你的头像图片';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => '在线 / 离开';

  @override
  String get profileVisibilityScreenOnlineAwayDesc => '你现在是否显示为活跃状态';

  @override
  String get profileVisibilityScreenLastSeenLabel => '最后在线时间';

  @override
  String get profileVisibilityScreenLastSeenDesc => '你上次在线的时间';

  @override
  String get profileVisibilityScreenSectionMessages => '消息';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel => '发送已读回执';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      '开启后，别人可以看到你已读了他们的消息';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel => '显示已读回执';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      '对方读过后，在你自己的消息上看到“已读”标记';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      '只有开启了“发送已读回执”的人才会计入已读状态，其他人则不会显示。';

  @override
  String get profileVisibilityScreenSectionPeople => '人员';

  @override
  String get profileVisibilityScreenFriendRequestsLabel => '好友请求';

  @override
  String get profileVisibilityScreenFriendRequestsDesc => '谁可以向你发送好友请求';

  @override
  String get profileVisibilityScreenSupervisedTitle => '这些由你的大人设置';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      '你可以看到这里其他人能看到的内容，但只有大人才能修改。他们始终能看到你的头像、你是否在线，以及你上次在线的时间。';

  @override
  String get profileVisibilityScreenOptionPublic => '公开';

  @override
  String get profileVisibilityScreenOptionFriends => '好友';

  @override
  String get profileVisibilityScreenOptionNobody => '无人';

  @override
  String get profileVisibilityScreenOptionOn => '开';

  @override
  String get profileVisibilityScreenOptionOff => '关';

  @override
  String get profileVisibilityScreenOptionAnyone => '任何人';

  @override
  String get logoScreenTitle => '应用标志。';

  @override
  String get logoScreenSubtitle => '顶栏上的标志，你说了算。';

  @override
  String get logoScreenAutoLabel => '自动';

  @override
  String get logoScreenAutoDescription => '跟随你的主题，标志随配色变化。';

  @override
  String get logoScreenManualLabel => '手动';

  @override
  String get logoScreenManualDescription => '任选标志，主题不变。';

  @override
  String get logoScreenAlwaysDefaultLabel => '始终默认';

  @override
  String get logoScreenAlwaysDefaultDescription => '始终使用 MonkeyHub 标志，与主题无关。';

  @override
  String get logoScreenActiveBadge => '使用中';

  @override
  String get logoScreenMonkeyCollectionHeader => '猴子合集';

  @override
  String get logoScreenThemesHeader => '主题';

  @override
  String get recoveryPhraseScreenCopiedSnackbar => '已复制 — 粘贴到安全的地方';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => '确认\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => '是你本人。';

  @override
  String get recoveryPhraseScreenPasswordBody => '验证密码，防止他人为你的账户设置恢复短语。';

  @override
  String get recoveryPhraseScreenPasswordHint => '密码';

  @override
  String get recoveryPhraseScreenContinueButton => '继续';

  @override
  String get recoveryPhraseScreenNotNowLink => '暂不';

  @override
  String get recoveryPhraseScreenEnterPasswordError => '请输入密码。';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => '保存\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => '这些词。';

  @override
  String get recoveryPhraseScreenWordsBody =>
      '这十二个词是你忘记密码后找回账户的唯一方式。我们无法再次显示给你，也无法帮你找回。';

  @override
  String get recoveryPhraseScreenCopyButton => '复制';

  @override
  String get recoveryPhraseScreenPaperHint => '如果可以，把它们写在纸上。手机里的东西可能会随手机一起丢失。';

  @override
  String get recoveryPhraseScreenSavedButton => '我已保存';

  @override
  String get recoveryPhraseScreenBackLink => '← 返回';

  @override
  String get recoveryPhraseScreenKeepPhraseLink => '暂不——保留我目前的恢复短语';

  @override
  String get homeScreenProfileSemanticLabel => '你的个人资料';

  @override
  String homeScreenGreeting(Object name) {
    return '嗨，$name。';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => '新建房间';

  @override
  String get homeScreenEmptyRoomsMessage => '还没有房间——创建一个吧';

  @override
  String get groupCallScreenTitleVideo => '群组视频通话';

  @override
  String get groupCallScreenTitleVoice => '群组语音通话';

  @override
  String groupCallScreenParticipantCount(Object count) {
    return '$count 人通话中';
  }

  @override
  String get groupCallScreenReconnecting => '重新连接中…';

  @override
  String get groupCallScreenUnmuteLabel => '取消静音';

  @override
  String get groupCallScreenMuteLabel => '静音';

  @override
  String get groupCallScreenCamOnLabel => '开镜头';

  @override
  String get groupCallScreenCamOffLabel => '关镜头';

  @override
  String get groupCallScreenFlipLabel => '翻转';

  @override
  String get groupCallScreenSpeakerLabel => '扬声器';

  @override
  String get groupCallScreenLeaveLabel => '离开';

  @override
  String get groupCallScreenYouLabel => '你';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return '正在按$summary筛选。更改筛选';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => '筛选聊天';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => '清除筛选';

  @override
  String get roomFilterDrawerClearLabel => '清除';

  @override
  String get roomFilterDrawerDimensionType => '类型';

  @override
  String get roomFilterDrawerDimensionNature => '性质';

  @override
  String get roomFilterDrawerDimensionStatus => '状态';

  @override
  String get roomFilterDrawerPanelClear => '清除';

  @override
  String get roomFilterDrawerPanelDone => '完成';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个聊天',
    );
    return '$label，$_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return '没有符合$summary的聊天';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '显示全部 $count 个聊天',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '显示全部 $count 个聊天',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => '新聊天室';

  @override
  String get createRoomSheetTaglineSecret => '什么都不会留下';

  @override
  String get createRoomSheetTaglineRegular => '留得住的空间';

  @override
  String get createRoomSheetNameLabel => '名称';

  @override
  String get createRoomSheetNameHint => '起个诚实的名字…';

  @override
  String get createRoomSheetDescriptionLabel => '描述 · 选填';

  @override
  String get createRoomSheetDescriptionHint => '用一句话介绍一下…';

  @override
  String get createRoomSheetVisibilityLabel => '可见性';

  @override
  String get createRoomSheetVisibilityPublicTitle => '公开';

  @override
  String get createRoomSheetVisibilityPublicSub => '任何人都能找到';

  @override
  String get createRoomSheetVisibilityPrivateTitle => '私密';

  @override
  String get createRoomSheetVisibilityPrivateSub => '仅限邀请';

  @override
  String get createRoomSheetTypeLabel => '类型';

  @override
  String get createRoomSheetTypeStandardTitle => '标准';

  @override
  String get createRoomSheetTypeStandardSub => '消息会保留';

  @override
  String get createRoomSheetTypeEphemeralTitle => '阅后即焚';

  @override
  String get createRoomSheetTypeEphemeralSub => '自动删除';

  @override
  String get createRoomSheetMessageLifeLabel => '消息有效期';

  @override
  String createRoomSheetTtlSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String createRoomSheetTtlMinutes(Object minutes) {
    return '$minutes分钟';
  }

  @override
  String createRoomSheetTtlHours(Object hours) {
    return '$hours小时';
  }

  @override
  String get createRoomSheetPasswordLabel => '密码 · 选填';

  @override
  String get createRoomSheetPasswordHint => '用密码把它锁上…';

  @override
  String get createRoomSheetNameRequiredError => '名称不能为空';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => '打开聊天室';

  @override
  String get createRoomSheetOpenRoomButton => '打开聊天室';

  @override
  String get familyScreenTitle => '家庭';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件事等你确认',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => '在线';

  @override
  String get familyScreenPresenceNotPaired => '还没配对';

  @override
  String get familyScreenPresenceJustNow => '刚刚';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return '$minutes分钟前';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return '$hours小时前';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return '$days天前';
  }

  @override
  String get familyScreenPairButton => '配对';

  @override
  String get familyScreenReleaseButton => '解绑';

  @override
  String get familyScreenSettingsButton => '设置';

  @override
  String get familyScreenAddChildButton => '添加孩子';

  @override
  String get familyScreenEmptyStateTitle => '还没有孩子';

  @override
  String get familyScreenEmptyStateBody => '给孩子创建一个账号,然后绑定到他们的手机。';

  @override
  String get reactionDetailsSheetTitle => '回应';

  @override
  String get reactionDetailsSheetEmptyState => '这里已经没有回应了';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => '全部';

  @override
  String get reactionDetailsSheetYouBadge => '你';

  @override
  String get roomLayoutScreenTitle => '聊天列表。';

  @override
  String get roomLayoutScreenSubtitle => '聊天室如何排列,以及你如何筛选它们';

  @override
  String get roomLayoutScreenLayoutSectionLabel => '布局';

  @override
  String get roomLayoutScreenRowLayoutLabel => '列表布局';

  @override
  String get roomLayoutScreenRowLayoutDescription => '单列显示,通栏铺满,一目了然。';

  @override
  String get roomLayoutScreenGridLayoutLabel => '网格布局';

  @override
  String get roomLayoutScreenGridLayoutDescription => '两列紧凑排列,一眼看到更多房间。';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => '筛选方式';

  @override
  String get roomLayoutScreenChipRowLabel => '标签行';

  @override
  String get roomLayoutScreenChipRowDescription => '常驻显示,一键切换筛选,只占一行空间。';

  @override
  String get roomLayoutScreenDrawerButtonLabel => '抽屉按钮';

  @override
  String get roomLayoutScreenDrawerButtonDescription => '一按即开的按钮,不用时不占地方。';

  @override
  String get roomLayoutScreenQuietRoomSectionLabel => '安静的房间';

  @override
  String get roomLayoutScreenPlainCornerLabel => '留白';

  @override
  String get roomLayoutScreenPlainCornerDescription => '还没人说话的房间保持简洁';

  @override
  String get roomLayoutScreenMonogramLabel => '房间首字母';

  @override
  String get roomLayoutScreenMonogramDescription => '一个巨大的淡色字母填满空角';

  @override
  String get roomLayoutScreenActiveBadge => '使用中';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel => '跳转到置顶消息';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => '所有置顶消息';

  @override
  String get pinnedBannerTitleSingle => '置顶消息';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return '置顶消息 $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => '聊天样式。';

  @override
  String get pinnedBannerChatStyleSubtitle => '聊天室的外观';

  @override
  String get pinnedBannerClassicLabel => '经典';

  @override
  String get pinnedBannerClassicSubtitle => '带分隔线的顶栏,扁平输入栏。';

  @override
  String get pinnedBannerCompactLabel => '紧凑';

  @override
  String get pinnedBannerCompactSubtitle => '悬浮在对话上方的磨砂胶囊。';

  @override
  String get pinnedBannerActiveBadge => '使用中';

  @override
  String get audioMessageMissingLabel => '[音频缺失]';

  @override
  String get audioMessageUnavailableLabel => '语音不可用';

  @override
  String get audioMessageRetryHint => '点击重试';

  @override
  String get audioMessageLoadingLabel => '加载中…';

  @override
  String get audioMessageUsernameRequiredError => '请输入用户名。';

  @override
  String get audioMessagePasswordRequiredError => '请输入密码。';

  @override
  String get audioMessageCancelSemanticLabel => '取消';

  @override
  String get audioMessageHeroCreateLine1 => '马上\n';

  @override
  String get audioMessageHeroCreateLine2 => '就好了。';

  @override
  String get audioMessageHeroLinkLine1 => '欢迎\n';

  @override
  String get audioMessageHeroLinkLine2 => '回来。';

  @override
  String get audioMessageCreateSubtitle => '选一个用户名,方便家人朋友找到你。';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return '登录一次,$provider 就会关联到你的账号。';
  }

  @override
  String get audioMessageUsernameHint => '用户名';

  @override
  String get audioMessageDisplayNameHint => '显示名称(选填)';

  @override
  String get audioMessagePasswordHint => '密码';

  @override
  String get audioMessageSwitchToLinkPrompt => '那是我的账号,去登录';

  @override
  String get audioMessageCreateAccountButton => '创建账号';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return '登录并关联 $provider';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => '已经有账号了?';

  @override
  String get audioMessageSwitchToCreateModeLink => '新用户?创建账号';

  @override
  String get approvalsScreenTitle => '审批';

  @override
  String get approvalsScreenEmptyTitle => '暂无待办';

  @override
  String get approvalsScreenEmptySubtitle => '你都处理完啦';

  @override
  String get approvalsScreenErrorNotGuardian => '这不是你能决定的';

  @override
  String get approvalsScreenErrorAlreadyHandled => '已经在别的地方处理过了';

  @override
  String get approvalsScreenErrorGeneric => '保存失败,再试一次';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$child 想添加 $other';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$other 想添加 $child';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$child 想加入 $room';
  }

  @override
  String get approvalsScreenSomeoneLower => '某人';

  @override
  String get approvalsScreenSomeoneCapital => '有人';

  @override
  String get approvalsScreenRoomFallback => '一个房间';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      '对方会收到这条请求。是否同意,由对方决定。';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$child 会看到这条请求,可以选择接受或忽略。';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom => '在你收回权限前,他们可以在里面查看和发送消息。';

  @override
  String get approvalsScreenNotYetButton => '暂不';

  @override
  String get approvalsScreenAllowButton => '允许';

  @override
  String get approvalsScreenForwardDirectMessageFallback => '私信';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '转发 $count 条消息',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => '还没有其他聊天';

  @override
  String get approvalsScreenForwardNoMatches => '没有匹配结果';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return '最多同时选择 $max 个聊天';
  }

  @override
  String get approvalsScreenForwardSearchHint => '搜索聊天';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return '取消选择 $title';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return '选择 $title';
  }

  @override
  String get approvalsScreenForwardFadesBadge => '自毁';

  @override
  String get approvalsScreenForwardSendSemantic => '发送';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发送至 $count 个聊天',
      zero: '发送',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => '已关联账号';

  @override
  String get linkedAccountsScreenSubtitle => '你已关联到这个账号的其他账号,让你无需密码即可登录。';

  @override
  String get linkedAccountsScreenEmptyState => '这台设备上没有可关联的账号。';

  @override
  String get linkedAccountsScreenStatusChecking => '检查中…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return '你可以在任意设备上使用 $provider 登录。';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return '添加 $provider,这样你就不用输入密码了。';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return '取消关联 $provider';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => '取消关联';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return '输入密码以停止使用 $provider 登录。';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return '关联 $provider';
  }

  @override
  String get linkedAccountsScreenLinkAction => '关联';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return '输入密码,将 $provider 添加为登录方式。';
  }

  @override
  String get linkedAccountsScreenPillChecking => '检查中';

  @override
  String get linkedAccountsScreenPillLinked => '已关联';

  @override
  String get linkedAccountsScreenPillNotLinked => '未关联';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => '语音';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => '视频';

  @override
  String get linkedAccountsScreenCallSheetTitle => '发起通话';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle => '呼叫所有人';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle => '呼叫该聊天室的所有成员';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle => '选择成员';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle => '选择要邀请的人';

  @override
  String get linkedAccountsScreenCallSheetCallFullError => '通话人数已满（最多6人）';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError => '无法发起通话';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle => '邀请加入通话';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers => '这里没有其他成员';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => '选择成员';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => '发起通话';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return '发起通话（$count）';
  }

  @override
  String get childPairScreenGreetingLine1 => '你好';

  @override
  String get childPairScreenGreetingLine2 => '你。';

  @override
  String get childPairScreenIntro =>
      '请大人打开 MonkeyHub，然后点击“配对设备”。接着扫描对方的验证码，或者输入对方读给你听的6位数字。';

  @override
  String get childPairScreenOrDivider => '或';

  @override
  String get childPairScreenGenericError => '出错了，请重试。';

  @override
  String get profileScreenDeleteAccountFailed => '出错了，请重试。';

  @override
  String get childPairScreenAccountGoneError => '这个账号已经不存在了。';

  @override
  String get childPairScreenScanButtonLabel => '扫描对方的验证码';

  @override
  String get childPairScreenNoCameraMessage => '没有摄像头，请改为输入6位数字。';

  @override
  String get childPairScreenStopScanning => '停止扫描';

  @override
  String get childPairScreenSubmitButtonLabel => '放我进去';

  @override
  String get childPairScreenBackToSignIn => '← 返回登录';

  @override
  String get fileMessageUnavailable => '文件已不存在';

  @override
  String get fileMessageOpenFailed => '无法打开该文件';

  @override
  String get fileMessageDefaultName => '文档';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return '保存 $name';
  }

  @override
  String fileMessageViewSemanticLabel(Object name) {
    return '查看 $name';
  }

  @override
  String get textFileViewerDownloadTooltip => '下载';

  @override
  String get textFileViewerTruncatedNotice => '仅显示部分内容——下载以查看完整文件。';

  @override
  String get fileMessageUploadFailedLabel => '失败';

  @override
  String get fileMessageSendingLabel => '发送中…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size · 发送中…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return '$count分钟前';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return '$count小时前';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return '$count天前';
  }

  @override
  String get fileMessageStandardBadge => '标准';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '对方发来 $count 条消息 · 点击查看',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => '同意';

  @override
  String get fileMessageDeclineButton => '拒绝';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return '$ago发送';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条消息待发送',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => '取消请求';

  @override
  String get destructiveSheetCannotBeUndone => '此操作无法撤销';

  @override
  String get destructiveSheetCancelSemanticLabel => '取消';

  @override
  String get destructiveSheetCancelButtonLabel => '取消';

  @override
  String get destructiveSheetHideLabel => '收起';

  @override
  String get destructiveSheetViewLabel => '展开';

  @override
  String get destructiveSheetPairingMintError => '生成失败，请重试。';

  @override
  String get destructiveSheetPairingReleaseTitle => '归还';

  @override
  String get destructiveSheetPairingPairTitle => '配对';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return '在$name的手机上打开TA的个人资料，点击“归还手机”，然后输入这些数字。';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return '在$name的手机上打开MonkeyHub扫一下这个——或者直接输入数字。';
  }

  @override
  String get destructiveSheetPairingCodeExpired => '此码已过期';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return '$time后过期';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => '生成新码';

  @override
  String get destructiveSheetPairingOneUseNote => '仅限一次使用，生成新码会让旧码失效。';

  @override
  String get deepOceanThemeAttachButtonLabel => '添加附件';

  @override
  String get deepOceanThemeCameraButtonLabel => '相机';

  @override
  String get deepOceanThemeSendButtonLabel => '发送';

  @override
  String get deepOceanThemeEphemeralHint => '说点悄悄话…';

  @override
  String get deepOceanThemeDefaultHint => '说点什么…';

  @override
  String get deepOceanThemeMessageHint => '消息';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => '这个文件不见了';

  @override
  String get photoChromeMediaYouLabel => '你';

  @override
  String get photoChromeCloseSemanticLabel => '关闭';

  @override
  String get photoChromeFillToggleSemanticLabel => '适应屏幕或填满屏幕';

  @override
  String get photoChromeShowInChatSemanticLabel => '在聊天中显示';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return '第 $current 项，共 $total 项';
  }

  @override
  String photoTrayCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张照片',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => '放弃这些照片';

  @override
  String get photoTrayRemoveSemanticLabel => '移除这张照片';

  @override
  String get photoTrayEditSemanticLabel => '裁剪或涂画这张照片';

  @override
  String get photoTrayAddMoreSemanticLabel => '再加照片';

  @override
  String photoTrayLimitSnack(Object count) {
    return '一次最多发送 $count 张照片';
  }

  @override
  String get photoTrayLoadFailedSnack => '有些照片打不开';

  @override
  String get mediaPickFailedMessage => '打不开，请重新选择';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$name正在输入';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1和$name2正在输入';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1、$name2 等$extra人正在输入';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => '来电';

  @override
  String get typingIndicatorIncomingVideoCallLabel => '视频通话来电';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => '语音通话来电';

  @override
  String get typingIndicatorDeclineButtonLabel => '拒接';

  @override
  String get typingIndicatorDeclineButtonDeclining => '拒接中…';

  @override
  String get typingIndicatorAcceptButtonLabel => '接听';

  @override
  String get typingIndicatorAcceptButtonConnecting => '连接中…';

  @override
  String get messageStampNavigationTitle => '导航。';

  @override
  String get messageStampNavigationSubtitle => '你在聊天、发现、动态和设置之间切换的方式';

  @override
  String get messageStampRadialOrbLabel => '径向光球';

  @override
  String get messageStampRadialOrbDescription =>
      '长按 + 从角落拖动。平时安静待机,一个越用越顺手的手势。';

  @override
  String get messageStampBottomPillLabel => '底部胶囊';

  @override
  String get messageStampBottomPillDescription => '经典点击。始终可见,零学习成本。';

  @override
  String get messageStampActiveLabel => '使用中';

  @override
  String get messageStampUploadingLabel => '正在上传';

  @override
  String get messageStampSendingLabel => '正在发送';

  @override
  String get messageStampFailedToSendLabel => '发送失败';

  @override
  String get messageStampSentLabel => '已发送';

  @override
  String get messageStampDeliveredLabel => '已送达';

  @override
  String get messageStampSeenLabel => '已读';

  @override
  String get messageStampSavedLabel => '已保存';

  @override
  String messageStampCountdownSeconds(Object count) {
    return '$count秒';
  }

  @override
  String messageStampCountdownMinutes(Object count) {
    return '$count分';
  }

  @override
  String get voiceRecorderScreenMicPermissionDeniedSnackbar => '麦克风权限被拒绝';

  @override
  String get voiceRecorderScreenStatusRecording => '录音中';

  @override
  String get voiceRecorderScreenStatusReady => '已就绪';

  @override
  String get voiceRecorderScreenStatusTapToStart => '点击开始';

  @override
  String get voiceRecorderScreenReRecordButton => '重新录制';

  @override
  String get voiceRecorderScreenStopButton => '停止';

  @override
  String get voiceRecorderScreenSendButton => '发送';

  @override
  String get voiceRecorderScreenRecordButton => '录制';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => '所有人';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => '通知全员';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => '群主';

  @override
  String get releaseDeviceScreenFallbackChildName => 'TA';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return '这样$name就会从这部手机退出登录并交还手机——手机会回到平时的登录界面,谁都能使用。';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote => '账号、消息和好友都会保留,随时都能重新登录。';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return '请一位大人打开 MonkeyHub,在“家庭”里找到$name,然后点击“释放”。';
  }

  @override
  String get releaseDeviceScreenOrDivider => '或';

  @override
  String get releaseDeviceScreenOnePhoneNote => '如果只有这一部手机,大人也可以直接在这里登录。';

  @override
  String get releaseDeviceScreenUsernameHint => '大人的用户名';

  @override
  String get releaseDeviceScreenPasswordHint => '大人的密码';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => '退出登录';

  @override
  String get releaseDeviceScreenChecking => '检查中…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return '退出$name登录';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => '把手机还回去';

  @override
  String get releaseDeviceScreenErrorCodeExpired => '这个验证码已过期,去申请一个新的吧。';

  @override
  String get releaseDeviceScreenErrorCodeInvalid => '验证码不对,可能已经被用过了。';

  @override
  String get releaseDeviceScreenErrorNotAGuardian => '没成功,检查一下用户名和密码。';

  @override
  String get releaseDeviceScreenErrorGeneric => '出错了,再试一次吧。';

  @override
  String get activeCallPillMoveHereSemanticLabel => '把通话转到这台设备';

  @override
  String activeCallPillCallWith(Object name) {
    return '与$name通话';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return '在 $device 上';
  }

  @override
  String get activeCallPillMoveHereLabel => '转到这里';

  @override
  String get activeCallPillUnknownCaller => '未知';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'iOS 模拟器';

  @override
  String get activeCallPillPlatformAndroid => 'Android 设备';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'Windows 电脑';

  @override
  String get activeCallPillPlatformLinux => 'Linux 设备';

  @override
  String get activeCallPillPlatformBrowser => '浏览器';

  @override
  String get activeCallPillPlatformOther => '另一台设备';

  @override
  String get activeCallPillPinnedHeader => '置顶消息';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return '置顶消息 · $count';
  }

  @override
  String get activeCallPillNothingPinned => '没有置顶消息了';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return '跳转到$name的消息';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return '取消置顶$name的消息';
  }

  @override
  String get callButtonErrorBusy => '对方正在通话中';

  @override
  String get callButtonErrorCallFailed => '无法发起通话';

  @override
  String get callButtonErrorNotMember => '不是该聊天室的成员';

  @override
  String get callButtonErrorGeneric => '无法发起通话';

  @override
  String get callButtonAlreadyOnCall => '你已经在通话中了';

  @override
  String get callButtonBusyElsewhere => '另一台设备上正在通话';

  @override
  String get callButtonVoiceCallTooltip => '语音通话';

  @override
  String get callButtonVideoCallTooltip => '视频通话';

  @override
  String get callButtonTooltip => '通话';

  @override
  String get callButtonReplyStyleTitle => '回复样式。';

  @override
  String get callButtonReplyStyleSubtitle => '回复如何展示原消息';

  @override
  String get callButtonReplyStylePhantomEchoLabel => '幽灵残影';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      '父消息的幽灵气泡漂浮在上方，通过一条弯曲的连线相连，交汇处带有分支图标。';

  @override
  String get callButtonReplyStyleStickyNoteLabel => '便利贴';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      '一张略微倾斜的拍立得风格卡片，夹在气泡角落。';

  @override
  String get callButtonReplyStyleComicTailLabel => '漫画尾巴';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      '一个小型父消息迷你气泡，带有指向下方的漫画风格三角尾巴。';

  @override
  String get callButtonReplyStyleClassicLabel => '经典';

  @override
  String get callButtonReplyStyleClassicDescription =>
      '带主题色的引用胶囊，配有连线条和头像——熟悉的 WhatsApp 风格。';

  @override
  String get callButtonReplyStyleActiveBadge => '使用中';

  @override
  String get callButtonReplyPreviewSampleMessage => '嘿，你看到新出的演示了吗？';

  @override
  String get callButtonReplyPreviewSampleReply => '看到了，那个模糊效果绝了。';

  @override
  String get childSetupScreenErrorPickUsername => '给ta起一个用户名吧。';

  @override
  String get childSetupScreenErrorUsernameTaken => '这个用户名已经被占用了。';

  @override
  String get childSetupScreenErrorChildNotAllowed => '只有大人账户才能添加孩子。';

  @override
  String get childSetupScreenErrorGeneric => '账户创建失败，请重试。';

  @override
  String get childSetupScreenTitle => '添加孩子';

  @override
  String get childSetupScreenHeading => 'ta是\n谁？';

  @override
  String get childSetupScreenNameLabel => '名字';

  @override
  String get childSetupScreenNameHint => '你平时怎么称呼ta';

  @override
  String get childSetupScreenUsernameLabel => '用户名';

  @override
  String get childSetupScreenUsernameHint => '朋友们怎么找到ta';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'ta能做什么';

  @override
  String get childSetupScreenBulletTalkImmediately => 'ta可以立刻和你还有ta的兄弟姐妹聊天。';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      '其他人都需要先经过你同意——无论是ta主动添加的人，还是主动添加ta的人。';

  @override
  String get childSetupScreenBulletPublicRoomsOff => '公开房间默认关闭，除非你手动开启。';

  @override
  String get childSetupScreenBulletCantSignOut => 'ta无法自行退出登录，你也可以随时查看ta的动态。';

  @override
  String get childSetupScreenCreateButton => '创建并配对';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return '给$name发消息';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => '已申请';

  @override
  String get childSetupScreenMemberCountUnitLabel => '人';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return '查看全部 $count';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return '查看全部 $count';
  }

  @override
  String get bubbleStyleScreenTitle => '气泡样式。';

  @override
  String get bubbleStyleScreenSubtitle => '你的文字以怎样的形状出现';

  @override
  String get bubbleStyleScreenTailedLabel => '尾状';

  @override
  String get bubbleStyleScreenTailedDescription =>
      '每组连续消息以尾巴收尾；上方的消息行会合并成一个整体。';

  @override
  String get bubbleStyleScreenSoftLabel => '柔和';

  @override
  String get bubbleStyleScreenSoftDescription => '没有尾巴——连续消息仅靠收紧的内角衔接在一起。';

  @override
  String get bubbleStyleScreenPillLabel => '胶囊';

  @override
  String get bubbleStyleScreenPillDescription => '完全圆润的胶囊形状,每一行都一样。';

  @override
  String get bubbleStyleScreenSlabLabel => '块状';

  @override
  String get bubbleStyleScreenSlabDescription => '方正边角——锐利、工整、干脆。';

  @override
  String get bubbleStyleScreenActiveBadge => '使用中';

  @override
  String get bubbleStyleScreenPreviewQuestion => '所以呢?看起来怎么样';

  @override
  String get bubbleStyleScreenPreviewReplyOne => '好一点了';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => '好多了';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => '视频';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => '照片';

  @override
  String get incomingGroupCallScreenCallFullError => '通话人数已满(最多 6 人)';

  @override
  String get incomingGroupCallScreenJoinFailedError => '无法加入该通话';

  @override
  String get incomingGroupCallScreenDefaultRoomName => '群组通话';

  @override
  String get incomingGroupCallScreenDefaultStarterName => '某人';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starter 发起了视频通话';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starter 发起了语音通话';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '已有 $count 人在通话中';
  }

  @override
  String get incomingGroupCallScreenDismissButton => '拒绝';

  @override
  String get incomingGroupCallScreenJoinButton => '加入';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个聊天',
    );
    return '$_temp0';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条消息',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      '最后一条消息:刚刚';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return '最后一条消息:$hours 小时前';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      '最后一条消息:昨天';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return '最后一条消息:$days 天前';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      '最后一条消息:很久以前';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => '收回';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return '要把 $contactName 从 $childName 身边带走吗?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      '他们以后没法再联系彼此了,聊天记录也会一起消失。';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return '他们以后没法再联系彼此了。$contactName 不会收到通知。';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats · $messages 将被删除';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      '双方都会被清空,包括照片和语音消息,且无法恢复。';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '他们还共同加入了 $count 个群聊',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      '这些会保留下来。不想要的话,去下面的「房间」列表里移除就行。';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      '移除并删除';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return '移除 $contactName,并清空 $messages。';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return '将 $contactName 从允许列表中移除。';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      '取消';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => '取消';

  @override
  String get groupCallBannerCallFullError => '通话人数已满(最多 6 人)';

  @override
  String get groupCallBannerJoinFailedError => '无法加入通话';

  @override
  String get groupCallBannerUnknownParticipant => '某人';

  @override
  String get groupCallBannerOngoingVideoCall => '视频通话进行中';

  @override
  String get groupCallBannerOngoingVoiceCall => '语音通话进行中';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extra 正在通话中';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => '加入通话';

  @override
  String get groupCallBannerJoinButtonLabel => '加入';

  @override
  String get groupCallBannerJoinRoomSheetTitle => '加入房间';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位成员',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => '密码';

  @override
  String get groupCallBannerPasswordHint => '暗号…';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => '加入';

  @override
  String get groupCallBannerJoinRoomButtonLabel => '加入';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => '取消';

  @override
  String get groupCallBannerCancelButtonLabel => '取消';

  @override
  String get viewOnceViewerBadgeLabel => '阅后即焚';

  @override
  String get socialButtonDividerOr => '或';

  @override
  String get socialButtonGoogleContinue => '通过 Google 继续';

  @override
  String get discoverListsPeopleTitle => '你的好友。';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => '筛选你的好友…';

  @override
  String get discoverListsClearFilterSemanticLabel => '清除筛选';

  @override
  String get discoverListsNoOneYet => '还没有人';

  @override
  String discoverListsNoMatches(Object query) {
    return '没有找到匹配「$query」的人';
  }

  @override
  String get discoverListsRoomsTitle => '你的房间。';

  @override
  String discoverListsRoomsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个房间',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterRoomsHint => '筛选你的房间…';

  @override
  String get discoverListsNoRoomsYet => '还没有房间';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return '没有找到匹配「$query」的房间';
  }

  @override
  String get discoverListsVoiceCallLabel => '语音通话';

  @override
  String get discoverListsVideoCallLabel => '视频通话';

  @override
  String get approvalGateAlreadyAskedLabel => '已请求';

  @override
  String get approvalGateAskGrownUpLabel => '问问大人';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return '你已经问过$what了。';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return '你需要先获得大人的同意才能$what。';
  }

  @override
  String get approvalGateDisabledBody => '大人暂时关闭了这个功能。';

  @override
  String get approvalGateAlreadyAskedFooter => '他们会收到通知,过一会儿再来看看吧。';

  @override
  String get approvalGateWillNotifyFooter => '我们会通知他们,他们回复后你会在这里看到。';

  @override
  String get approvalGateTalkToThemFooter => '如果你觉得应该改一下,可以直接找他们聊聊。';

  @override
  String get approvalGateAskButton => '询问';

  @override
  String get approvalGateNotNowButton => '暂不';

  @override
  String get approvalGateOkButton => '好的';

  @override
  String get approvalGateWaitingPillLabel => '等待大人回应';

  @override
  String get reportSheetTitle => '举报';

  @override
  String get reportSheetSubtitle => '告诉我们出了什么问题。';

  @override
  String get reportSheetPrivacyNote => '举报是保密的——对方不会收到通知。';

  @override
  String get reportSheetReasonSpamLabel => '垃圾信息';

  @override
  String get reportSheetReasonSpamDescription => '不请自来的广告或重复消息';

  @override
  String get reportSheetReasonHarassmentLabel => '骚扰';

  @override
  String get reportSheetReasonHarassmentDescription => '针对性攻击或欺凌';

  @override
  String get reportSheetReasonImpersonationLabel => '冒充';

  @override
  String get reportSheetReasonImpersonationDescription => '冒充他人身份';

  @override
  String get reportSheetReasonInappropriateLabel => '不当内容';

  @override
  String get reportSheetReasonInappropriateDescription => '色情、暴力或违法内容';

  @override
  String get reportSheetReasonOtherLabel => '其他';

  @override
  String get reportSheetReasonOtherDescription => '其他情况';

  @override
  String get reportSheetOtherNoteHint => '发生了什么?';

  @override
  String get reportSheetSubmitSemanticLabel => '提交举报';

  @override
  String get reportSheetSubmitButton => '提交';

  @override
  String get reportSheetUpdateRequiredTitle => '需要更新';

  @override
  String get reportSheetUpdateAvailableTitle => '有可用更新';

  @override
  String get reportSheetUpdateMandatoryBody => '此版本过旧,已无法正常使用。请更新后继续。';

  @override
  String get reportSheetUpdateAvailableBody => 'MonkeyHub 有新版本可用。';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => '更新';

  @override
  String get reportSheetUpdateActionOpensTestflight => '打开 TestFlight';

  @override
  String get reportSheetUpdateActionOpensAppStore => '打开 App Store';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => '打开 Google Play';

  @override
  String get reportSheetUpdateActionOpensDownloadPage => '打开下载页面';

  @override
  String get reportSheetUpdateActionReloads => '重新加载新版本';

  @override
  String get reportSheetUpdateLaterSemanticLabel => '稍后';

  @override
  String get reportSheetUpdateLaterButton => '稍后';

  @override
  String get roomFilterBarAllChipLabel => '全部';

  @override
  String roomFilterBarChipCountSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个聊天',
    );
    return '$label，$_temp0';
  }

  @override
  String composerReplyCardReplyingToLabel(Object name) {
    return '回复 $name';
  }

  @override
  String get roomCardLockedBadge => '已锁定';

  @override
  String get roomCardTimeAgoJustNow => '刚刚';

  @override
  String roomCardTimeAgoSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String roomCardTimeAgoMinutes(Object minutes) {
    return '$minutes分钟';
  }

  @override
  String roomCardTimeAgoHours(Object hours) {
    return '$hours小时';
  }

  @override
  String roomCardTimeAgoDays(Object days) {
    return '$days天';
  }

  @override
  String roomCardTimeAgoWeeks(Object weeks) {
    return '$weeks周';
  }

  @override
  String roomCardStartedAgo(Object ago) {
    return '$ago前创建';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count 人在线';
  }

  @override
  String get roomCardMessagesFadeLabel => '消息渐隐';

  @override
  String get roomCardEnterLabel => '↗ 进入';

  @override
  String get roomCardBlockedScreenTitle => '已屏蔽';

  @override
  String get roomCardBlockedEmptyState => '你还没有屏蔽任何人。';

  @override
  String get roomCardUnblockButton => '取消屏蔽';

  @override
  String get attachmentMenuPhotoLabel => '照片';

  @override
  String get attachmentMenuVideoLabel => '视频';

  @override
  String get attachmentMenuCameraLabel => '拍照';

  @override
  String get attachmentMenuVoiceLabel => '语音';

  @override
  String get attachmentMenuFileLabel => '文件';

  @override
  String get attachmentMenuConnectionRetrying => '重试中…';

  @override
  String get attachmentMenuConnectionCantReachServer => '无法连接服务器 · 点击重试';

  @override
  String get attachmentMenuConnectionReconnecting => '重新连接中…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel => '重试连接';

  @override
  String get roomGridTileEmptyLastMessage => '暂时很安静';

  @override
  String get roomGridTileMemberCountLabel => '在线';

  @override
  String get roomGridTileThemeChipLabel => '主题';

  @override
  String get bulkActionBarCancelLabel => '取消';

  @override
  String get bulkActionBarSelectMessagesLabel => '选择消息';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '已选 $count 项';
  }

  @override
  String get bulkActionBarForwardLabel => '转发';

  @override
  String get bulkActionBarDeleteLabel => '删除';

  @override
  String get bulkActionBarJumpBackLabel => '返回';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return '返回 · $depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel => '返回到你跳转前的位置';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return '返回到你跳转前的位置，还剩 $depth 步';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote => '对方不会收到通知。';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      '你们目前是好友——屏蔽会解除好友关系，以后想重新联系就得重新发送好友请求。';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      '对方会从你的搜索结果中消失，也无法再给你发消息。';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => '屏蔽';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return '屏蔽 $name？';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '你们有 $count 个共同房间',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      '这些房间不受影响，你可以在各房间的设置中自行退出。';

  @override
  String get bulkActionBarBlockChoiceTileTitle => '屏蔽';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      '解除好友关系并屏蔽对方，已有的聊天记录仍会保留在你的存档中。';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub => '对方会从搜索中隐藏，也无法联系到你。';

  @override
  String get bulkActionBarBlockDeleteDmTitle => '屏蔽并删除私信';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      '同时清空你与对方的私信——所有消息、表情回应和媒体文件都会被删除。';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => '取消';

  @override
  String get bulkActionBarBlockSheetCancelLabel => '取消';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle => '在锁屏上显示来电';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      '为了在锁屏时也能像真实来电一样响铃，MonkeyHub 需要开启“全屏通知”权限。下一步会直接带你去打开这个开关。';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle => '不错过任何来电';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      '有些手机会为了省电而在后台暂停应用，这可能导致来电被静音。请允许 MonkeyHub 不受限制地运行，确保来电畅通无阻。';

  @override
  String get bulkActionBarDialogNotNowButton => '暂不';

  @override
  String get bulkActionBarDialogContinueButton => '继续';

  @override
  String get reactionBubbleJumpToLatestLabel => '跳到最新';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel => '跳到最新';

  @override
  String get reactionBubblePickerTitle => '回应';

  @override
  String get reactionBubbleNoRecentsPlaceholder => '暂无最近使用';

  @override
  String get reactionBubbleSearchHint => '搜索表情';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => '没有匹配的表情';

  @override
  String get reactionBubbleSearchBackSemanticLabel => '返回表情列表';

  @override
  String get reactionBubblePasswordHint => '密码';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return '加入 $roomName';
  }

  @override
  String get enterPublicRoomAskFailedMessage => '现在无法发送申请，请重试';

  @override
  String get enterPublicRoomWrongPasswordMessage => '密码错误';

  @override
  String get enterPublicRoomJoinFailedMessage => '加入失败，请重试';

  @override
  String get feedBoardTitle => '今天';

  @override
  String feedBoardEditionLabel(Object number) {
    return '第$number期';
  }

  @override
  String get feedBoardHighlightsLabel => '精彩瞬间';

  @override
  String get feedBoardHighlightsEmpty => '今天还没有内容';

  @override
  String get feedBoardPuzzleLabel => '谜题';

  @override
  String get feedBoardPuzzleEmpty => '今天的谜题还没准备好';

  @override
  String get feedBoardStandingsLabel => '生活积分';

  @override
  String get feedBoardStandingsEmpty => '今天还没有积分';

  @override
  String get feedBoardActivityLabel => '动态';

  @override
  String get feedBoardActivityEmpty => '今天还很安静';

  @override
  String get feedBoardActivityNoFriends => '添加好友后，他们的一天会显示在这里';

  @override
  String get feedBoardLoadFailed => '无法加载看板 — 请稍后再试';

  @override
  String get enterPublicRoomVisibilityPublicLabel => '公开';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => '私密';

  @override
  String get enterPublicRoomJoinedBadgeLabel => '已加入';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return '限时 · $duration';
  }

  @override
  String enterPublicRoomEphemeralSecondsShort(Object seconds) {
    return '$seconds秒';
  }

  @override
  String enterPublicRoomEphemeralMinutesShort(Object minutes) {
    return '$minutes分';
  }

  @override
  String enterPublicRoomEphemeralHoursShort(Object hours) {
    return '$hours时';
  }

  @override
  String get roomBadgePublicTooltip => '任何人都能找到并加入这个房间';

  @override
  String get roomBadgePrivateTooltip => '仅限邀请，不会出现在发现页';

  @override
  String get roomBadgeLockedTooltip => '加入需要房间密码';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return '消息会在 $duration 后消失';
  }

  @override
  String get roomBadgeJoinedTooltip => '你已经在这个房间里了';

  @override
  String get roomInfoSheetDetailsLabel => '详细信息';

  @override
  String get roomInfoSheetNoDescription => '还没有简介';

  @override
  String get roomInfoSheetCreatedLabel => '创建于';

  @override
  String get countBadgeCaptureProtectionLabel => '截屏录屏保护';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody => '截图和录屏在系统中会显示为黑屏。';

  @override
  String get countBadgeCaptureProtectionOnIosBody => '录屏或投屏时，应用会被覆盖一层隐私保护层。';

  @override
  String get countBadgeCaptureProtectionOffBody => '在限时房间之外，截图和录屏可以正常使用。';

  @override
  String get countBadgeCaptureProtectionForcedNote => '限时房间（密室）始终会强制开启此功能。';

  @override
  String get countBadgeShowPasswordTooltip => '显示密码';

  @override
  String get countBadgeHidePasswordTooltip => '隐藏密码';

  @override
  String get countBadgeProtectedLabel => '已保护';

  @override
  String get countBadgeCaptureShieldActiveBody => '正在录屏或投屏。';

  @override
  String get countBadgeCaptureShieldReassurance => '录屏看不到你的聊天内容。';

  @override
  String get linkOpenerCouldNotOpenLink => '无法打开链接';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel => '设置恢复短语';

  @override
  String get linkOpenerRecoveryBannerMessage => '未设置恢复短语，你将无法找回账号。';

  @override
  String get destinationsChatLabel => '聊天';

  @override
  String get destinationsChatShort => '聊天';

  @override
  String get destinationsDiscoverLabel => '发现';

  @override
  String get destinationsDiscoverShort => '查找';

  @override
  String get destinationsFeedLabel => '动态';

  @override
  String get destinationsFeedShort => '动态';

  @override
  String get destinationsSettingsLabel => '设置';

  @override
  String get destinationsSettingsShort => '设置';

  @override
  String get familyRequestStageSenderGuardianLabel => '等待大人确认';

  @override
  String get familyRequestStageRecipientLabel => '等待对方';

  @override
  String get roomContentTabLabelMedia => '媒体';

  @override
  String get roomContentTabLabelFiles => '文件';

  @override
  String get roomContentTabLabelVoice => '语音';

  @override
  String get roomContentTabLabelLinks => '链接';

  @override
  String get roomContentTabLabelSaved => '已保存';

  @override
  String get roomContentTabHeaderMedia => '媒体';

  @override
  String get roomContentTabHeaderFiles => '文件';

  @override
  String get roomContentTabHeaderVoice => '语音';

  @override
  String get roomContentTabHeaderLinks => '链接';

  @override
  String get roomContentTabHeaderSaved => '已保存';

  @override
  String get roomFacetLabelDms => '私聊';

  @override
  String get roomFacetLabelGroups => '群聊';

  @override
  String get roomFacetLabelPublic => '公开';

  @override
  String get roomFacetLabelPrivate => '私密';

  @override
  String get roomFacetLabelSecret => '秘密';

  @override
  String get roomFacetLabelLocked => '锁定';

  @override
  String get roomFacetLabelUnread => '未读';

  @override
  String get roomFacetLabelMentions => '提及';

  @override
  String get settingsScreenTitle => '设置';

  @override
  String get settingsScreenTagline => '外观、质感、你。';

  @override
  String get settingsScreenAccountHintChild => '资料 · 隐私 · 我的大人';

  @override
  String get settingsScreenAccountHintAdult => '资料 · 家庭 · 关联账号 · 隐私';

  @override
  String get settingsScreenSectionAppearance => '外观';

  @override
  String get settingsScreenSectionChat => '聊天';

  @override
  String get settingsScreenSectionCompanions => '伙伴';

  @override
  String get settingsScreenSectionGeneral => '通用';

  @override
  String get settingsScreenCheckForUpdatesLabel => '检查更新';

  @override
  String get settingsScreenUpdateAvailableValue => '有可用更新';

  @override
  String get settingsScreenUpdateUpToDateSnackbar => '你已是最新版本。';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar => '此版本无法检查更新。';

  @override
  String get settingsScreenUpdateErrorSnackbar => '无法检查更新，请稍后重试。';

  @override
  String get settingsScreenSectionNotifications => '通知';

  @override
  String get reportProblemRowLabel => '报告问题';

  @override
  String get reportProblemRowValue => '把详情发给我们';

  @override
  String get reportProblemIntro =>
      '告诉我们出了什么问题。应用和设备信息会自动附上，还会附上一份记录应用当时运行情况的技术日志——正是这些帮助我们找到原因。';

  @override
  String get reportProblemDescribeLabel => '发生了什么';

  @override
  String get reportProblemDescribeHint => '屏幕闪烁、按钮没反应……';

  @override
  String get reportProblemScreenshotsLabel => '截图';

  @override
  String get reportProblemAddScreenshot => '添加截图';

  @override
  String get reportProblemDetailsLabel => '你的信息';

  @override
  String get reportProblemCopyDetails => '复制信息';

  @override
  String get reportProblemCopied => '已复制';

  @override
  String get reportProblemSend => '发送报告';

  @override
  String get reportProblemSent => '报告已发送，谢谢！';

  @override
  String get reportProblemSendFailed => '报告发送失败。请检查网络连接后重试。';

  @override
  String get reportProblemTooMany => '你刚刚发送了很多报告，请稍后再试。';

  @override
  String get reportProblemShakeTitle => '要报告问题吗？';

  @override
  String get reportProblemShakeBody => '你摇了手机。要打开报告页面吗？';

  @override
  String get reportProblemShakeOpen => '报告';

  @override
  String get reportProblemShakeDismiss => '暂不';

  @override
  String get settingsCallDeliveryLockScreenLabel => '锁屏来电';

  @override
  String get settingsCallDeliveryBackgroundLabel => '后台活动';

  @override
  String get settingsCallDeliveryStatusOff => '点按以允许';

  @override
  String get settingsScreenRowTheme => '主题';

  @override
  String get settingsScreenRowAppLogo => '应用图标';

  @override
  String get settingsScreenRowGlass => '玻璃';

  @override
  String get settingsScreenRowChatList => '聊天列表';

  @override
  String get settingsScreenRowNavigation => '导航';

  @override
  String get settingsScreenRowChatStyle => '聊天样式';

  @override
  String get settingsScreenRowBubbleStyle => '气泡样式';

  @override
  String get settingsScreenRowReplyStyle => '回复样式';

  @override
  String get settingsScreenValueScrollList => '滚动列表';

  @override
  String get settingsScreenValueGridSheet => '网格视图';

  @override
  String get settingsScreenValueRadialOrb => '环形光球';

  @override
  String get settingsScreenValueBottomPill => '底部胶囊';

  @override
  String get settingsScreenValueCustom => '自定义';

  @override
  String settingsScreenValueEdited(Object name) {
    return '$name · 已编辑';
  }

  @override
  String get settingsScreenValueClassic => '经典';

  @override
  String get settingsScreenValueCompact => '紧凑';

  @override
  String get settingsScreenValueBubbleTailed => '尾状';

  @override
  String get settingsScreenValueBubbleSoft => '柔和';

  @override
  String get settingsScreenValueBubblePill => '胶囊';

  @override
  String get settingsScreenValueBubbleSlab => '块状';

  @override
  String get settingsScreenValueReplyPhantomEcho => '幽灵残影';

  @override
  String get settingsScreenValueReplyStickyNote => '便利贴';

  @override
  String get settingsScreenValueReplyComicTail => '漫画尾巴';

  @override
  String get settingsScreenValueLogoAuto => '自动';

  @override
  String get settingsScreenValueLogoManual => '手动';

  @override
  String get settingsScreenShowLinkUrlsLabel => '显示链接网址';

  @override
  String get settingsScreenLinksUrlsOnBody => '预览卡片旁会显示原始网址';

  @override
  String get settingsScreenLinksUrlsOffBody => '当前仅显示预览——气泡更简洁，点击即可打开';

  @override
  String get settingsScreenMenuBarLabel => '菜单栏图标';

  @override
  String get settingsScreenMenuBarOnBody =>
      'MonkeyHub 会带着未读数量停留在菜单栏 — 点按即可打开窗口';

  @override
  String get settingsScreenMenuBarOffBody => '当前已关闭 — 想找回隐藏的窗口只能通过 Dock 图标';

  @override
  String get settingsScreenSectionCalls => '通话';

  @override
  String get settingsScreenRowVideoQuality => '视频画质';

  @override
  String get settingsScreenValueVideoQualityAuto => '自动';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel => '显示通话统计';

  @override
  String get settingsScreenShowNetworkStatsBody => '通话期间实时显示分辨率、比特率、延迟和丢包率';

  @override
  String get videoQualityScreenTitle => '视频画质';

  @override
  String get videoQualityScreenSubtitle => '选择传出视频的分辨率上限';

  @override
  String get videoQualityScreenAutoSubtitle => '自动适应你的网络状况';

  @override
  String get videoQualityScreenHd1080Subtitle => '全高清——更清晰，占用更多流量';

  @override
  String get videoQualityScreenUhd4kSubtitle => '超高清——网络良好时效果最佳';

  @override
  String get videoQualityScreenFootnote => '实际分辨率取决于双方设备的摄像头和网络状况。';

  @override
  String get callScreenControlOptions => '更多';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => '抖动';

  @override
  String get callScreenStatsLossLabel => '丢包';

  @override
  String get callScreenSwapPreviewSemanticLabel => '切换摄像头视图';

  @override
  String get callOptionsSheetTitle => '通话选项';

  @override
  String get settingsScreenPushNotificationsLabel => '推送通知';

  @override
  String get settingsScreenPushOnBody => '新消息和请求都会提醒你';

  @override
  String get settingsScreenPushOffBody => '静音——只有打开App才能看到';

  @override
  String get settingsScreenGameRemindersLabel => '每日游戏提醒';

  @override
  String get settingsScreenGameRemindersOnBody => '中午提醒一次，只在你还没玩的时候';

  @override
  String get settingsScreenGameRemindersOffBody => '不提醒——游戏随时都在';

  @override
  String get authErrorUsernameTaken => '该用户名已被占用。';

  @override
  String get authErrorUsernameReserved => '该用户名不可用，请换一个。';

  @override
  String get authErrorDisplayNameReserved => '该名称不可用，请换一个。';

  @override
  String get authErrorUserNotFound => '没有使用该用户名的账号。';

  @override
  String get authErrorWrongPassword => '密码错误。';

  @override
  String get authErrorInvalidRecoveryKey => '该用户名与恢复短语不匹配。';

  @override
  String get authErrorTooManyAttempts => '尝试次数过多，请等待15分钟后再试。';

  @override
  String get authErrorChildMustPair => '这是一个儿童账号——请向大人索要配对码。';

  @override
  String get authErrorPairingCodeExpired => '该配对码已过期，请重新申请一个。';

  @override
  String get authErrorPairingCodeInvalid => '该配对码无效，可能已被使用过。';

  @override
  String get authErrorUseSocialSignIn => '该账号使用Apple或Google登录——请点击下方按钮。';

  @override
  String get authErrorSocialTokenInvalid => '登录未成功，请重试。';

  @override
  String get authErrorSocialNonceMismatch => '本次登录未能完成，请重试。';

  @override
  String get authErrorSocialMisconfig => '登录功能尚未配置完成，请稍后再试。';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      '该 Apple 或 Google 账号已绑定到另一个 MonkeyHub 账号。';

  @override
  String get authErrorSocialAlreadyLinked => '该账号已绑定到此账号。';

  @override
  String get authErrorSocialNotLinked => '该账号未绑定到此账号。';

  @override
  String get authErrorSocialLastCredential => '这是登录此账号的唯一方式，请先设置密码。';

  @override
  String get authErrorUsernameInvalid => '用户名长度需在 1 到 32 个字符之间。';

  @override
  String get authErrorUsernameChangedRecently =>
      '你最近更改过用户名。距离上次更改 30 天后才能再次更改。';

  @override
  String get authErrorInboxHandleLocked => '此账号接收所有人的问题反馈，因此用户名固定。';

  @override
  String get glassKnobLabelFrost => '磨砂';

  @override
  String get glassKnobHintFrost => '玻璃上覆盖的白色程度，调低可透视';

  @override
  String get glassKnobLabelBlur => '模糊';

  @override
  String get glassKnobHintBlur => '调到顶端时磨砂感最强，调到底端则是清澈玻璃';

  @override
  String get glassKnobLabelSaturation => '色彩溢出';

  @override
  String get glassKnobHintSaturation => '模糊后残留的色彩程度，超过 2 会出现色调分离';

  @override
  String get glassKnobLabelRimOpacity => '边框';

  @override
  String get glassKnobHintRimOpacity => '强调色边框，设为零则无边框';

  @override
  String get glassKnobLabelRimWidth => '边框宽度';

  @override
  String get glassKnobHintRimWidth => '该边框的粗细';

  @override
  String get glassKnobLabelShadowOpacity => '阴影';

  @override
  String get glassKnobHintShadowOpacity => '该表面悬浮在背景上方的程度';

  @override
  String get glassKnobLabelShadowBlur => '阴影扩散';

  @override
  String get glassKnobHintShadowBlur => '柔和宽泛，或紧凑锐利';

  @override
  String get glassKnobLabelShadowY => '阴影下移';

  @override
  String get glassKnobHintShadowY => '阴影落在表面下方的距离';

  @override
  String get glassKnobLabelBarMargin => '侧边间距';

  @override
  String get glassKnobHintBarMargin => '导航栏与屏幕边缘之间的间距';

  @override
  String get glassKnobLabelBarBottom => '底部间距';

  @override
  String get glassKnobHintBarBottom => '导航栏悬浮在底部上方的高度';

  @override
  String get glassKnobLabelShellPadH => '两端内边距';

  @override
  String get glassKnobHintShellPadH => '导航栏边缘到第一个胶囊的间距，太小两端会显得孤零零的';

  @override
  String get glassKnobLabelShellPadV => '顶部内边距';

  @override
  String get glassKnobHintShellPadV => '导航栏边缘到胶囊顶部的间距';

  @override
  String get glassKnobLabelIndicatorInset => '胶囊内缩';

  @override
  String get glassKnobHintIndicatorInset => '选中胶囊在其卡槽内向内收缩的距离';

  @override
  String get glassKnobLabelSegmentPadV => '行内边距';

  @override
  String get glassKnobHintSegmentPadV => '图标与文字标签上下的留白';

  @override
  String get glassKnobLabelIconLabelGap => '图标间距';

  @override
  String get glassKnobHintIconLabelGap => '图标与下方文字之间的间距';

  @override
  String get glassKnobLabelIconSize => '图标大小';

  @override
  String get glassKnobLabelLabelSize => '文字大小';

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
  String get settingsScreenRowMotion => '动效';

  @override
  String get settingsScreenValueMotionFull => '完整';

  @override
  String get settingsScreenValueMotionCalm => '安静';

  @override
  String get settingsScreenValueMotionSystemFull => '跟随设备 · 完整';

  @override
  String get settingsScreenValueMotionSystemCalm => '跟随设备 · 安静';

  @override
  String get motionScreenTitle => '动效。';

  @override
  String get motionScreenSubtitle => '应用的动态程度';

  @override
  String get motionScreenSystemLabel => '跟随设备';

  @override
  String get motionScreenSystemSubtitleFull => '你的设备目前允许动画';

  @override
  String get motionScreenSystemSubtitleCalm => '你的设备目前要求减少动态效果';

  @override
  String get motionScreenFullLabel => '完整';

  @override
  String get motionScreenFullSubtitle => '每一次飘移、光晕与点缀';

  @override
  String get motionScreenCalmLabel => '安静';

  @override
  String get motionScreenCalmSubtitle => '装饰静止 — 其他一切照旧';

  @override
  String get momentRailCaptureLabel => '拍摄';

  @override
  String get momentRailYouLabel => '你';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author：$caption';
  }

  @override
  String get momentTagFate => '巧合';

  @override
  String get momentTagJinx => '自作自受';

  @override
  String get momentTagLuck => '走运';

  @override
  String get momentTagCalledIt => '我就说吧';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => '也太巧了';

  @override
  String get momentTagJinxHint => '这是你自找的';

  @override
  String get momentTagLuckHint => '事情如你所愿';

  @override
  String get momentTagCalledItHint => '你早就料到了';

  @override
  String get momentTagNpcHint => '大脑完全关机';

  @override
  String get momentComposerTitle => '发生什么了？';

  @override
  String get momentComposerCaptionHint => '说点什么';

  @override
  String get momentComposerTagPrompt => '拿到分了？现在就加';

  @override
  String get momentComposerCapture => '相机';

  @override
  String get momentComposerLibrary => '相册';

  @override
  String get momentComposerRemovePhoto => '移除照片';

  @override
  String get momentComposerPost => '发布';

  @override
  String get momentComposerErrorDailyCap => '今天已经五个了 — 给明天留点';

  @override
  String get momentComposerErrorNotAllowed => '监护人已关闭照片分享';

  @override
  String get momentComposerErrorTooLong => '有点长 — 精简一下';

  @override
  String get momentComposerErrorEmpty => '加一张照片或几句话';

  @override
  String get momentComposerErrorGeneric => '发布失败 — 请重试';

  @override
  String get momentViewerDelete => '删除';

  @override
  String get momentViewerDeleteConfirmHeadline => '删除这条？';

  @override
  String get momentViewerDeleteConfirmBody => '它会从所有人的看板和你的归档中永久消失';

  @override
  String get momentViewerDeleteFailed => '删除失败 — 请重试';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who 发布了一个瞬间';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name 拿到一个 $tag';
  }

  @override
  String get momentActivityJustNow => '刚刚';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '$count分';
  }

  @override
  String momentActivityHoursAgo(Object count) {
    return '$count小时';
  }

  @override
  String momentActivityMoreCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天还有 $count 条',
    );
    return '$_temp0';
  }

  @override
  String get puzzleScreenTitle => '谜题。';

  @override
  String get puzzleScreenSubtitle => '四个符号，六次机会';

  @override
  String get puzzleSubmit => '猜';

  @override
  String get puzzleBackspace => '删除最后一个符号';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return '符号 $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return '$count 次解开';
  }

  @override
  String get puzzleFailedTitle => '次数已用完';

  @override
  String get puzzleAnswerWas => '答案是';

  @override
  String get puzzleShare => '复制结果';

  @override
  String get puzzleShareCopied => '已复制 — 发给朋友';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => '今天的你已经解开了';

  @override
  String get puzzleErrorOutOfGuesses => '今天没有剩余次数';

  @override
  String get puzzleErrorGeneric => '发送失败 — 请重试';

  @override
  String get puzzleScoreboardLabel => '今日成绩';

  @override
  String get puzzleScoreboardEmpty => '今天还没有人完成';

  @override
  String get puzzleTilePlay => '来玩今天的谜题';

  @override
  String puzzleTileInProgress(Object count) {
    return '还剩 $count 次';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '第 $rank 名 / 共 $total 人';
  }

  @override
  String get profileVisibilityScreenSectionFeed => '动态';

  @override
  String get profileVisibilityScreenFeedLabel => '我的精彩瞬间';

  @override
  String get profileVisibilityScreenFeedDesc => '你发布的照片和视频当天是否出现在好友的看板上';

  @override
  String get profileVisibilityScreenPuzzleLabel => '我的谜题成绩';

  @override
  String get profileVisibilityScreenPuzzleDesc => '好友能否看到你每日谜题的表现';

  @override
  String get profileVisibilityScreenPointsPastLabel => '我的过往';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      '今天始终与好友共享 — 此项开放的是今天之前的全部';

  @override
  String get momentComposerVideo => '视频';

  @override
  String get momentComposerErrorTooBig => '这个视频太大了 — 最大 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => '你发布了一个瞬间';

  @override
  String momentActivityScoredSelf(Object tag) {
    return '你拿到一个 $tag';
  }

  @override
  String pointLineSelf(Object tag) {
    return '你 · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => '发生什么了？';

  @override
  String get pointComposerNoteHint => '先在上面选一个，然后讲讲';

  @override
  String get pointComposerAdd => '添加积分';

  @override
  String get pointComposerAddPhoto => '添加照片';

  @override
  String get pointsBoardAdd => '添加一个积分';

  @override
  String get pointsExplainerOpen => '这是什么？';

  @override
  String get pointsExplainerTitle => '积分游戏';

  @override
  String get pointsExplainerIntro =>
      '一个记着分数的长期玩笑。当你遇到什么事 — 好的、坏的，或者只是离奇 — 就记下来，它会在当天出现在看板上。';

  @override
  String get pointsExplainerRuleHonour => '分是你自己给的。没人核对 — 这正是乐趣所在，过头了朋友自然会说你。';

  @override
  String get pointsExplainerRuleToday => '积分每天清零。看板显示今天；你自己的记录归你保留。';

  @override
  String get pointsExplainerRuleCap => '同一种每天五个，免得有人把看板刷成一堆废话。';

  @override
  String get pointsExplainerGotIt => '知道了';

  @override
  String get momentTagFateExample => '在另一个国家撞见了我的牙医';

  @override
  String get momentTagJinxExample => '洗完车，四点就下雨了';

  @override
  String get momentTagLuckExample => '差两秒赶上了火车';

  @override
  String get momentTagCalledItExample => '我说续集会扑，果然扑了';

  @override
  String get momentTagNpcExample => '对服务员说了‘你也是’';

  @override
  String feedBoardEditionHint(Object number) {
    return '动态第 $number 天';
  }

  @override
  String get feedBoardHighlightsHint => '值得一看的照片和视频';

  @override
  String get profileVisibilityScreenPointsLabel => '我的积分';

  @override
  String get profileVisibilityScreenPointsDesc => '你记录的积分是否出现在好友的看板上';

  @override
  String get momentComposerEditPhoto => '编辑裁剪';

  @override
  String get archiveScreenTitle => '你的存档';

  @override
  String get archiveScreenEnd => '就这些了';

  @override
  String get archiveScreenEmptyTitle => '还没有保存任何内容';

  @override
  String get archiveScreenEmptyBody => '瞬间一天后会从好友的看板消失，但会一直留在这里。';

  @override
  String get archiveScreenEmptyFriendTitle => '这里什么都没有';

  @override
  String get archiveScreenEmptyFriendBody => '还没有发布你能看到的内容。';

  @override
  String get archiveScreenPrivateTitle => '对方的过往是私密的';

  @override
  String get archiveScreenPrivateBody => '你仍然能看到今天发布的内容。';

  @override
  String get archiveScreenNotFriendTitle => '你们不是好友';

  @override
  String get archiveScreenNotFriendBody => '只能回看好友的日子。';

  @override
  String get archiveScreenErrorTitle => '加载失败';

  @override
  String get archiveScreenErrorBody => '检查网络后重试。';

  @override
  String get feedBoardOpenArchive => '存档';

  @override
  String get feedBoardGamesLabel => '今日游戏';

  @override
  String get feedBoardGamesOpen => '全部游戏';

  @override
  String get gamesScreenTitle => '游戏。';

  @override
  String get gamesScreenSubtitle => '每天四道题，所有人都一样';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今天还剩 $count 个',
      one: '今天还剩 1 个',
      zero: '今天全部完成',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => '无法加载今天的游戏';

  @override
  String get gamesRetry => '重试';

  @override
  String get gameQueensName => '皇后';

  @override
  String get gameQueensRule => '每行、每列、每色各一顶王冠，且不相邻';

  @override
  String get gameTangoName => '探戈';

  @override
  String get gameTangoRule => '三个太阳、三个月亮，不能连续三个相同';

  @override
  String get gameZipName => '连线';

  @override
  String get gameZipRule => '一条线经过每一格，数字按顺序';

  @override
  String get gameSudokuName => '迷你数独';

  @override
  String get gameSudokuRule => '每行、每列、每宫各填 1 到 6 一次';

  @override
  String get gameCodeName => '密码';

  @override
  String get gameStatusUnplayed => '未开始';

  @override
  String get gameStatusUnfinished => '进行中';

  @override
  String get gameStatusGaveUp => '已放弃';

  @override
  String gameRankBadge(Object rank) {
    return '第$rank名';
  }

  @override
  String get gamePause => '暂停';

  @override
  String get gameResume => '继续';

  @override
  String get gamePausedTitle => '已暂停';

  @override
  String get gamePausedBody => '计时已停止，棋盘已隐藏';

  @override
  String get gameUndo => '撤销';

  @override
  String get gameClear => '清空';

  @override
  String get gameHint => '提示';

  @override
  String get gameNotes => '笔记';

  @override
  String get gameErase => '擦除';

  @override
  String get gameAutoCross => '自动打叉';

  @override
  String get gameGiveUp => '放弃';

  @override
  String get gameGiveUpTitle => '显示答案？';

  @override
  String get gameGiveUpBody => '今天的棋盘将结束，并记为未解出。';

  @override
  String get gameGiveUpCancel => '继续尝试';

  @override
  String get gameGiveUpConfirm => '显示';

  @override
  String gameSolvedTitle(Object time) {
    return '用时 $time 解出';
  }

  @override
  String get gameGaveUpTitle => '今天的答案';

  @override
  String get gameFirstInToday => '今天第一个';

  @override
  String gameRankLine(Object place, Object total) {
    return '目前 $total 人中第 $place 名';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次失误',
      one: '1 次失误',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次提示',
      one: '1 次提示',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => '今日成绩';

  @override
  String get gameStandingsEmpty => '还没有人完成';

  @override
  String get gameShare => '复制成绩';

  @override
  String get gameShareCopied => '已复制 — 粘贴给好友';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => '全部游戏';

  @override
  String get gameElapsedSemantic => '已用时间';

  @override
  String get gameErrorNotSolved => '这局还没完成';

  @override
  String get gameErrorAlreadyFinished => '你今天已经完成了';

  @override
  String get gameErrorNoHint => '这局没有提示';

  @override
  String get gameErrorGeneric => '无法连接游戏 — 请重试';

  @override
  String get gameInfoOpen => '玩法说明';

  @override
  String get gameInfoLabel => '玩法说明';

  @override
  String get gameInfoRulesLabel => '规则';

  @override
  String get gameInfoControlsLabel => '操作';

  @override
  String get gameInfoScoringTimed => '棋盘在屏幕上时计时进行，暂停或离开即停止。用时最短的人排在今天第一。';

  @override
  String get gameInfoScoringGuesses => '按猜的次数计分，与用时无关。';

  @override
  String get gameInfoSameForEveryone => '今天所有人拿到的是同一道题。';

  @override
  String get gameInfoGotIt => '知道了';

  @override
  String get gameInfoQueensGoal => '在每一行、每一列和每种颜色中各放一顶王冠。';

  @override
  String get gameInfoQueensRule1 => '八顶王冠：每行一顶，每列一顶。';

  @override
  String get gameInfoQueensRule2 => '每个颜色块也恰好放一顶王冠。';

  @override
  String get gameInfoQueensRule3 => '任意两顶王冠都不能相邻，连对角也不行。';

  @override
  String get gameInfoQueensControls => '点一下方格打叉排除，再点放王冠，再点清空。';

  @override
  String get gameInfoTangoGoal => '用太阳和月亮填满格子。';

  @override
  String get gameInfoTangoRule1 => '每行每列各有三个太阳和三个月亮。';

  @override
  String get gameInfoTangoRule2 => '横向或纵向都不能连续出现三个相同的。';

  @override
  String get gameInfoTangoRule3 => '两格之间的 = 表示相同，× 表示不同。';

  @override
  String get gameInfoTangoControls => '点方格放太阳，再点放月亮，再点清空。题目自带的格子不能改。';

  @override
  String get gameInfoZipGoal => '画一条经过每一格的线。';

  @override
  String get gameInfoZipRule1 => '从 1 开始，在最后一个数字上结束。';

  @override
  String get gameInfoZipRule2 => '沿途按顺序经过每个数字。';

  @override
  String get gameInfoZipRule3 => '每一格恰好经过一次。';

  @override
  String get gameInfoZipControls => '拖动手指画线。沿线往回拖即可擦除。';

  @override
  String get gameInfoSudokuGoal => '用数字 1 到 6 填满格子。';

  @override
  String get gameInfoSudokuRule1 => '每行用 1 到 6 各一次。';

  @override
  String get gameInfoSudokuRule2 => '每列也一样。';

  @override
  String get gameInfoSudokuRule3 => '每个 2x3 的宫也一样。';

  @override
  String get gameInfoSudokuControls => '先点方格，再点数字。再点同一个数字即可清除。笔记模式写的是小号铅笔标记。';

  @override
  String get gameInfoCodeGoal => '推理出隐藏的四个符号密码。';

  @override
  String get gameInfoCodeRule1 => '六次机会，密码中不会出现重复符号。';

  @override
  String get gameInfoCodeRule2 => '绿色表示符号对、位置也对。';

  @override
  String get gameInfoCodeRule3 => '黄色表示符号对但位置不对。';

  @override
  String get gameInfoCodeControls => '点击符号组成一次猜测，然后提交。棋盘会告诉你差多少。';

  @override
  String get savedMessagesTitle => '保存的消息';

  @override
  String homeScreenNoSearchResults(Object query) {
    return '没有与\"$query\"匹配的聊天';
  }

  @override
  String get pullRevealSearchHint => '搜索聊天…';

  @override
  String get pullRevealCollapseSemanticLabel => '隐藏搜索和已归档的聊天';

  @override
  String archivedChatsFolderLabel(Object count) {
    return '已归档聊天（$count）';
  }

  @override
  String get archivedChatsFolderTitle => '已归档聊天';

  @override
  String get pullRevealClearSearchSemanticLabel => '清除搜索';

  @override
  String get archivedChatsSheetTitle => '已归档聊天';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return '已归档聊天 · $count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => '没有已归档的内容了';

  @override
  String get pinnedBadgeLabel => '已置顶';

  @override
  String get chatRowActionMenuPinLabel => '置顶聊天';

  @override
  String get chatRowActionMenuUnpinLabel => '取消置顶聊天';

  @override
  String get chatRowActionMenuArchiveLabel => '归档聊天';

  @override
  String get chatRowActionMenuUnarchiveLabel => '取消归档聊天';

  @override
  String get messageActionMenuSaveLabel => '保存';

  @override
  String get messageActionMenuUnsaveLabel => '取消保存';

  @override
  String get roomScreenSaveLimitSnack => '这里保存的太多了，先取消一条';

  @override
  String get roomScreenSaveFailedSnack => '无法保存这条消息';

  @override
  String get threadOverlaySaveLimitToast => '这里保存的太多了，先取消一条';

  @override
  String get threadOverlaySaveFailedToast => '无法保存这条消息';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      '你保存的消息只有你能看到；置顶的消息正相反，整个房间都能看到。';

  @override
  String get roomInfoScreenOwnerBadgeNote => '名字旁边的小奖章表示这个房间是谁创建的。';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return '跳转到$name保存的消息';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return '取消保存$name的消息';
  }

  @override
  String get muteSheetTitle => '静音聊天';

  @override
  String get muteSheetSubtitle => '选择要静音的内容和时长。';

  @override
  String get muteSheetNotificationsTitle => '通知';

  @override
  String get muteSheetNotificationsSub => '没有横幅，没有声音';

  @override
  String get muteSheetBadgesTitle => '未读计数';

  @override
  String get muteSheetBadgesSub => '聊天上不显示数字，也不计入应用图标';

  @override
  String get muteSheetDurationLabel => '静音多久';

  @override
  String get muteDurationHour => '1 小时';

  @override
  String get muteDurationEightHours => '8 小时';

  @override
  String get muteDurationWeek => '1 周';

  @override
  String get muteDurationAlways => '一直';

  @override
  String get muteSheetConfirmButton => '静音';

  @override
  String get muteSheetSaveButton => '保存';

  @override
  String get muteSheetUnmuteButton => '取消静音';

  @override
  String get muteSummaryAll => '这个聊天不会打扰你：没有通知，也没有未读计数。';

  @override
  String get muteSummaryNotificationsOnly => '没有通知。未读计数仍会继续增加。';

  @override
  String get muteSummaryBadgesOnly => '没有未读计数。通知仍会送达。';

  @override
  String get muteSummaryNothingPicked => '至少选择一项要静音的内容。';

  @override
  String muteUntilSentence(String when) {
    return '直到 $when。';
  }

  @override
  String get muteUntilAlwaysSentence => '直到你重新打开。';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date $time';
  }

  @override
  String get mutedBadgeLabel => '已静音';

  @override
  String get chatRowActionMenuMuteLabel => '静音聊天';

  @override
  String get chatRowActionMenuUnmuteLabel => '取消静音';

  @override
  String get roomInfoScreenMuteLabel => '静音';

  @override
  String get roomInfoScreenNotMutedRow => '未静音';

  @override
  String get attachmentMenuLocationLabel => '位置';

  @override
  String get locationSheetSendCurrent => '发送当前位置';

  @override
  String get locationSheetSendCurrentDetail => '你现在所在的位置';

  @override
  String get locationSheetLiveHeading => '实时共享';

  @override
  String get locationSheetLiveDetail => '会自动结束';

  @override
  String get locationShareFor15Minutes => '15 分钟';

  @override
  String get locationShareFor1Hour => '1 小时';

  @override
  String get locationShareFor8Hours => '8 小时';

  @override
  String get locationBubbleOpenInMaps => '在地图中打开';

  @override
  String get locationBubbleLiveBadge => '实时';

  @override
  String get locationBubbleEndedBadge => '已结束';

  @override
  String locationBubbleLiveUntil(String time) {
    return '实时共享至 $time';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return '实时位置已于 $time 结束';
  }

  @override
  String get locationBubbleNoRecentUpdate => '最近没有更新';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters 米';
  }

  @override
  String get locationBubbleStopSharing => '停止共享';

  @override
  String get locationBubbleUnavailable => '位置不可用';

  @override
  String get locationBubbleNoMapsApp => '没有可打开的地图应用';

  @override
  String get locationBubbleCoordinatesCopied => '坐标已复制';

  @override
  String get locationCouldNotGetFix => '无法获取你的位置';

  @override
  String get locationCouldNotStartLiveShare => '无法开始实时共享';

  @override
  String get locationPermissionNeeded => '共享你的位置需要位置权限';

  @override
  String get locationPermissionBlockedTitle => '位置权限已关闭';

  @override
  String get locationPermissionBlockedBody =>
      'MonkeyHub 无法在此再次请求。请在“设置”中为 MonkeyHub 开启位置权限。';

  @override
  String get locationServicesOffTitle => '定位服务已关闭';

  @override
  String get locationServicesOffBody => '此设备已关闭定位。请在“设置”中开启后再共享你的位置。';

  @override
  String get locationOpenSettings => '打开设置';

  @override
  String get locationBackgroundSheetTitle => '如果手机重启';

  @override
  String get locationBackgroundSheetBody =>
      '离开 MonkeyHub 后，实时共享本来就会继续。后台权限负责其余情况：重启、强制退出，或者手机没电后重新开机。';

  @override
  String get locationBackgroundSheetKeepRunning => '自动恢复共享';

  @override
  String get locationBackgroundSheetKeepRunningDetail => '手机会请求你的许可';

  @override
  String get locationBackgroundSheetAppOnly => '就让它停下';

  @override
  String get locationBackgroundSheetAppOnlyDetail => '无需其他权限';

  @override
  String get locationServiceNotificationTitle => '正在共享实时位置';

  @override
  String get locationServiceNotificationBody => '点按可打开聊天，点“停止”立即结束';

  @override
  String get childPolicyScreenLocationLabel => '位置';

  @override
  String get childPolicyScreenLocationOnDesc => '可以共享所在位置，包括最长 8 小时的实时共享';

  @override
  String get childPolicyScreenLocationOffDesc => '不能共享所在位置';

  @override
  String get roomInfoScreenSavedMessagesLabel => '保存的消息';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      '只有你能看到，而且只来自这个房间。你的“保存的消息”聊天是单独的。';

  @override
  String get roomInfoScreenSavedMessagesEmpty => '还没有保存任何内容。长按消息并选择“保存”。';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return '跳转到$name保存的消息';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return '取消保存$name的消息';
  }

  @override
  String get composerCaptureCameraModeLabel => '相机';

  @override
  String get composerCaptureVoiceModeLabel => '语音消息';

  @override
  String get composerCaptureVideoNoteModeLabel => '视频留言';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode。用两根手指滑动或使用方向键切换模式。';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '已选择$mode';
  }

  @override
  String get composerCaptureRecordingAnnouncement => '已开始录制';

  @override
  String get composerCaptureLockedAnnouncement => '录制已锁定，可松手。';

  @override
  String get composerCaptureCancelledAnnouncement => '已丢弃录制';

  @override
  String get composerCaptureSentAnnouncement => '已发送录制';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return '录制中，$elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint => '长按录制，滑动切换';

  @override
  String get composerCaptureTapForCameraHint => '轻点打开相机，滑动切换';

  @override
  String get composerCaptureSlideToCancelHint => '滑动取消';

  @override
  String get composerCaptureReleaseToCancelHint => '松开取消';

  @override
  String get composerCaptureTapToSendHint => '点按发送';

  @override
  String get composerCaptureSendingLabel => '发送中…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return '剩余 $seconds 秒';
  }

  @override
  String get composerCaptureCancelLabel => '丢弃录制';

  @override
  String get composerCaptureSendLabel => '发送录制';

  @override
  String get composerCaptureLockLabel => '向上滑动锁定录制';

  @override
  String get composerCaptureMicPermissionTitle => '需要麦克风权限';

  @override
  String get composerCaptureMicPermissionBody => '录制语音消息需要使用麦克风。请在“设置”中开启后重试。';

  @override
  String get composerCaptureCameraPermissionTitle => '需要相机权限';

  @override
  String get composerCaptureCameraPermissionBody =>
      '录制视频留言需要使用相机和麦克风。请在“设置”中开启后重试。';

  @override
  String get composerCaptureRestrictedBody => '此设备上的限制已关闭录制功能。';

  @override
  String get composerCaptureOpenSettingsLabel => '打开设置';

  @override
  String get composerCaptureUnavailableSnack => '此设备不支持录制。';

  @override
  String get composerCaptureInterruptedSnack => '录制已停止。';

  @override
  String get composerCaptureStorageSnack => '无法保存录制内容，请检查可用空间。';

  @override
  String get videoNoteMessagePlayLabel => '播放视频留言';

  @override
  String get videoNoteMessagePauseLabel => '暂停视频留言';

  @override
  String get videoNoteMessageLoadingLabel => '正在加载视频留言';

  @override
  String get videoNoteMessageUnavailableLabel => '视频留言不可用';

  @override
  String get videoNoteMessageRetryLabel => '重试视频留言';

  @override
  String get videoNoteMessageRetryHint => '点按重试';

  @override
  String get videoNoteMessageDiscardLabel => '丢弃视频留言';

  @override
  String get attachmentMenuVideoNoteLabel => '视频留言';

  @override
  String get cameraScreenPhotoModeLabel => '照片';

  @override
  String get cameraScreenVideoModeLabel => '视频';

  @override
  String get cameraScreenStartRecordingLabel => '开始录制';

  @override
  String get cameraScreenStopRecordingLabel => '停止录制';

  @override
  String get cameraScreenVideoFailedSnack => '无法录制该视频。';

  @override
  String get scheduleSheetTitle => '定时发送';

  @override
  String get scheduleSheetSubtitle => '现在写好，到点再发。';

  @override
  String get scheduleSheetWhenLabel => '什么时候发';

  @override
  String get schedulePresetInAnHour => '1 小时后';

  @override
  String get schedulePresetInEightHours => '8 小时后';

  @override
  String get schedulePresetTomorrowMorning => '明天早上';

  @override
  String get schedulePresetThisMorning => '今天早上';

  @override
  String get schedulePresetInAWeek => '1 周后';

  @override
  String get scheduleSheetCustomChip => '选择日期';

  @override
  String get scheduleSheetConfirmButton => '定时发送';

  @override
  String get scheduleSheetSaveButton => '保存';

  @override
  String scheduleSendsAtSentence(String when) {
    return '将在$when发送。';
  }

  @override
  String scheduleWhenToday(String time) {
    return '今天 $time';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return '明天 $time';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return '$date $time';
  }

  @override
  String get scheduleTimePickerTitle => '选择日期和时间';

  @override
  String get scheduleTimePickerBack => '快捷选项';

  @override
  String get scheduleTimePickerToday => '今天';

  @override
  String get scheduleTimePickerTomorrow => '明天';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条待发',
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
      other: '有 $count 条消息等待发送。点按查看。',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => '需要处理';

  @override
  String get scheduledListTitle => '待发送';

  @override
  String get scheduledListSubtitle => '发送之前，只有你能看到它们。';

  @override
  String get scheduledListEmpty => '这里没有等待发送的消息。';

  @override
  String get scheduledListSendNow => '立即发送';

  @override
  String get scheduledListChangeTime => '修改时间';

  @override
  String get scheduledListEdit => '修改内容';

  @override
  String get scheduledListDelete => '删除';

  @override
  String get scheduledListSending => '正在发送…';

  @override
  String get scheduledListFailedTitle => '没能发出去';

  @override
  String get scheduledListRetry => '重试';

  @override
  String get scheduleErrorOutOfRange => '请选择从现在起两分钟到一年之间的时间。';

  @override
  String get scheduleErrorTooMany => '这里等待发送的消息太多了。请先发送或删除一些。';

  @override
  String get scheduleErrorNotInEphemeral => '这个聊天里的消息会自动消失，所以不能定时发送。';

  @override
  String get scheduleErrorNotMember => '你已经不在这个聊天里了。';

  @override
  String get scheduleErrorBlocked => '你需要先解除拉黑。';

  @override
  String get scheduleErrorGeneric => '没成功，请再试一次。';

  @override
  String get scheduleEditTitle => '修改消息';

  @override
  String get composerScheduleAction => '定时发送这条消息';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 条消息等待发送',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => '显示方式';

  @override
  String get scheduledIndicatorPill => '横条';

  @override
  String get scheduledIndicatorBadge => '角标';

  @override
  String get scheduledIndicatorBoth => '两者';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已有 $count 条在等待',
      zero: '没有等待发送的消息',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => '如何显示';

  @override
  String get scheduledIndicatorPillSub => '输入框上方的横条。点按即可查看。';

  @override
  String get scheduledIndicatorBadgeSub => '发送按钮上的数字。开始输入前不会显示任何内容。';

  @override
  String get scheduledIndicatorBothSub => '横条，加上输入时的数字。';

  @override
  String get scheduledBack => '返回';

  @override
  String get serverScreenTitle => '服务器。';

  @override
  String get serverScreenSubtitle => '你的账号和消息所在的地方';

  @override
  String get serverOnboardingTitle => '选择一个服务器。';

  @override
  String get serverOnboardingSubtitle => '此版本未附带服务器 — 请指向你自己的服务器';

  @override
  String get serverStatusConnected => '已连接';

  @override
  String get serverStatusDisconnected => '未连接';

  @override
  String get serverBadgeDefault => '默认';

  @override
  String get serverBadgeSelfHosted => '自托管';

  @override
  String get serverNoneConfigured => '尚未选择服务器';

  @override
  String get serverActiveNowLabel => '使用中';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => '本应用自带的服务器。';

  @override
  String get serverChoiceOwn => '你自己的服务器';

  @override
  String get serverChoiceOwnSub => '由你自己运行的 Convex 后端。';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => '粘贴';

  @override
  String get serverProblemMalformed => '这不是一个网址。';

  @override
  String get serverProblemBadScheme => '请以 https:// 或 http:// 开头。';

  @override
  String get serverProblemNoHost => '请在 https:// 后面填写服务器地址。';

  @override
  String get serverProblemCredentials => '请从地址中去掉用户名和密码。';

  @override
  String get serverInsecureTitle => '未加密';

  @override
  String get serverInsecureBody =>
      '手机会阻止明文 http，因此该地址在 iOS 和 Android 上无法连接。请使用 https，或通过隧道访问你的服务器。';

  @override
  String get serverTestCta => '测试连接';

  @override
  String get serverTestingLabel => '正在测试…';

  @override
  String get serverCheckReachable => '有响应';

  @override
  String get serverCheckConvex => '这是 Convex 服务器';

  @override
  String get serverCheckApp => '正在运行 MonkeyHub';

  @override
  String get serverResultUnreachable => '该地址没有任何响应。';

  @override
  String get serverResultNotConvex => '有响应，但那不是 Convex 服务器。';

  @override
  String get serverResultNotThisApp => '这是 Convex 服务器，但上面没有部署 MonkeyHub。';

  @override
  String get serverResultServerError => '服务器有响应，但返回了错误。';

  @override
  String get serverResultReady => '可以连接。';

  @override
  String get serverConnectCta => '连接';

  @override
  String get serverConnectAnywayCta => '仍然连接';

  @override
  String get serverAlreadyConnectedCta => '已连接';

  @override
  String get serverUseDefaultCta => '使用默认服务器';

  @override
  String get serverChangeCta => '更换服务器';

  @override
  String get serverAdvancedLabel => '高级';

  @override
  String get serverSiteUrlExplain =>
      '大多数服务器在同一个地址上处理所有请求。只有当你的服务器把 HTTP actions 放在别处时才需要填写。';

  @override
  String get serverSiteUrlHint => '与上面相同';

  @override
  String get serverSectionRecent => '最近使用';

  @override
  String get serverRecentForget => '忘记此服务器';

  @override
  String get serverSwitchWarningTitle => '切换会退出登录';

  @override
  String get serverSwitchWarningBody =>
      '账号和聊天属于某一台服务器。本设备会退出登录、清除已下载的内容，并重新开始。两台服务器上的数据都不会被删除。';

  @override
  String get serverSwitchRolledBackTitle => '无法连接';

  @override
  String serverSwitchRolledBackBody(String host) {
    return '$host 没有响应，因此没有任何改变。你需要重新登录。';
  }

  @override
  String get serverSwitchStrandedBody => '两台服务器都无法连接。请检查地址后重试。';

  @override
  String get serverSwitchRefusedBody => '此设备已设置为儿童使用，无法更换服务器。';

  @override
  String serverChipSemantics(String server) {
    return '更换服务器。当前为 $server。';
  }

  @override
  String get serverValueDefault => '默认';

  @override
  String get settingsScreenRowServer => '服务器';

  @override
  String get settingsScreenSectionAdvanced => '高级';

  @override
  String get serverSwitchingLabel => '正在切换服务器…';

  @override
  String get serverRoleExplainAction => '这是什么意思？';

  @override
  String get serverBadgeRibbonHomeserver => '家庭';

  @override
  String get serverBadgeRibbonSelfHosted => '自建';

  @override
  String get serverBadgeHomeserver => '由家庭服务器提供服务';

  @override
  String get serverBadgeHomeserverSemantics => '正在由家庭服务器提供服务。点按查看详情。';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return '自托管服务器：$server。点按查看详情。';
  }

  @override
  String get serverRoleHomeserverTitle => '正在家庭服务器上运行';

  @override
  String get serverRoleHomeserverBody =>
      'MonkeyHub 的运营者暂时把流量切到了他们家里的服务器。一切照常运作 — 这是有意为之，不是故障。';

  @override
  String get serverRoleHomeserverWarnData => '在此期间发送的内容，在流量切回后可能不会保留。';

  @override
  String get serverRoleHomeserverWarnSpeed => '家庭宽带比平时的线路慢，可能会有卡顿。';

  @override
  String get serverRoleHomeserverWarnAuto => '你不需要做任何事。应用会自动切回去。';

  @override
  String get serverRoleSelfHostedTitle => '你自己的服务器';

  @override
  String get serverRoleSelfHostedBody => '此设备指向你自己运行的服务器。可在 设置 › 高级 › 服务器 中更改。';

  @override
  String get serverValueHomeserver => '暂时使用家庭服务器';

  @override
  String get serverChoiceCloudSubHomeserver => '暂时由家庭服务器提供服务。';

  @override
  String get serverDirectiveChangedToast => '你的服务器已切换。正在重新连接…';

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
  String get roomAdminRoleAdmin => '管理员';

  @override
  String get roomAdminActionViewProfile => '查看资料';

  @override
  String get roomAdminActionPromote => '设为管理员';

  @override
  String get roomAdminActionPromoteSub => '可以邀请他人、移出成员、修改群组';

  @override
  String get roomAdminActionDemote => '取消管理员';

  @override
  String get roomAdminActionDemoteSub => '仍以成员身份留在群里';

  @override
  String get roomAdminActionTransfer => '转让群主';

  @override
  String get roomAdminActionTransferSub => '你会留任管理员';

  @override
  String get roomAdminActionRemove => '移出群组';

  @override
  String get roomAdminAddFriendsRow => '添加好友';

  @override
  String get roomAdminInviteLinkRow => '邀请链接';

  @override
  String get roomAdminJoinRequestsRow => '入群申请';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return '把群交给 $name？';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      '对方将成为群主，可以解散群组。你会留任管理员，能不能拿回来只取决于对方。';

  @override
  String get roomAdminTransferConfirmCta => '转让';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return '把 $name 移出群组？';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      '对方将失去群组及其中所有内容的访问权。你可以再次邀请，对方也可以通过邀请链接回来。';

  @override
  String get roomAdminRemoveConfirmCta => '移出';

  @override
  String get roomAdminGenericError => '没成功，请再试一次。';

  @override
  String get roomAdminErrorNotMember => '你已经不在这个群里了。';

  @override
  String get roomAdminErrorNotAdmin => '只有管理员能这么做。';

  @override
  String get roomAdminErrorNotOwner => '只有群主能这么做。';

  @override
  String get roomAdminErrorNotGroup => '单聊没有什么可管理的。';

  @override
  String get roomAdminErrorOwnerImmutable => '群主的身份只能通过转让群组来改变。';

  @override
  String get roomAdminErrorInvitesLocked => '这个群只有管理员能邀请人。';

  @override
  String get roomInviteSheetTitle => '邀请链接';

  @override
  String get roomInviteSheetBlurb => '一条链接和一个口令码，其实是同一样东西。一旦生成新的，旧的立刻失效。';

  @override
  String get roomInviteNoLinkYet => '这个群还没有邀请链接。';

  @override
  String get roomInviteCreateButton => '生成链接';

  @override
  String get roomInviteRegenerateButton => '换新链接';

  @override
  String get roomInviteRevokeButton => '作废链接';

  @override
  String get roomInviteCopyLink => '复制链接';

  @override
  String get roomInviteCopyCode => '复制口令码';

  @override
  String get roomInviteShare => '分享';

  @override
  String get roomInviteLinkCopied => '链接已复制。';

  @override
  String get roomInviteCodeCopied => '口令码已复制。';

  @override
  String get roomInviteRegenerateHeadline => '换一条新链接？';

  @override
  String get roomInviteRegenerateBody => '当前链接和口令码会在所有分享过的地方立刻失效。已经在群里的人不受影响。';

  @override
  String get roomInviteRegenerateConfirm => '换新链接';

  @override
  String get roomInviteRevokeHeadline => '作废这条链接？';

  @override
  String get roomInviteRevokeBody => '在你生成新链接之前，没人能通过链接进群。已经在群里的人不受影响。';

  @override
  String get roomInviteRevokeConfirm => '作废';

  @override
  String get roomInviteLimitsLabel => '限制';

  @override
  String get roomInviteExpiryLabel => '有效期';

  @override
  String get roomInviteMaxUsesLabel => '可用次数';

  @override
  String get roomInviteNeverExpires => '永久';

  @override
  String get roomInviteUnlimited => '不限';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count 小时';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count 天';
  }

  @override
  String get roomInviteLimitsApplyToNew => '这些设置对你即将生成的链接生效。';

  @override
  String get roomInviteLimitsApplyOnRegenerate => '这些设置对下一条链接生效。上面那条保持生成时的限制。';

  @override
  String get roomInvitePermissionsLabel => '权限';

  @override
  String get roomInviteMembersCanInviteLabel => '成员可以邀请好友';

  @override
  String get roomInviteMembersCanInviteSub => '关掉之后，只有管理员能带人进来';

  @override
  String get roomInviteApprovalLabel => '逐个审批入群';

  @override
  String get roomInviteApprovalSub => '拿到链接的人先申请，由管理员决定同意与否';

  @override
  String roomInviteUsesCount(Object count) {
    return '已使用 $count 次';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '已用 $used/$max 次';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return '$date 到期';
  }

  @override
  String get roomInviteDeadExpired => '这条链接已过期，请生成新的。';

  @override
  String get roomInviteDeadExhausted => '这条链接的可用次数已用完，请生成新的。';

  @override
  String get roomInviteDeadRevoked => '这条链接已被作废。';

  @override
  String get roomInviteDeadGeneric => '这条链接已经无效。';

  @override
  String get roomInviteFriendsTitle => '添加好友';

  @override
  String get roomInviteFriendsBlurb => '他们会收到邀请，可以接受或拒绝。';

  @override
  String get roomInviteFriendsSearchHint => '搜索好友';

  @override
  String get roomInviteFriendsInviteButton => '邀请';

  @override
  String get roomInviteFriendsSent => '已邀请';

  @override
  String get roomInviteFriendsEmpty => '你的好友都已经在群里，或者已经邀请过了。';

  @override
  String get roomInviteFriendsNoMatch => '没有匹配的好友。';

  @override
  String get roomInviteFriendsDone => '完成';

  @override
  String get roomJoinRequestsTitle => '入群申请';

  @override
  String get roomJoinRequestsBlurb => '这些人用了邀请链接。在你同意之前，他们看不到群里的任何内容。';

  @override
  String get roomJoinRequestsEmpty => '没有人在等。';

  @override
  String get roomJoinRequestsApprove => '放进来';

  @override
  String get roomJoinRequestsReject => '拒绝';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return '已邀请 · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian => '等待家长确认';

  @override
  String get roomInfoScreenInviteWithdraw => '撤回';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return '来自 $inviter · $members 名成员';
  }

  @override
  String get roomInvitationCardJoin => '加入';

  @override
  String get discoverScreenJoinByCodeTitle => '用口令码加入';

  @override
  String get discoverScreenJoinByCodeSubtitle => '打开别人分享给你的群组';

  @override
  String get joinInviteTitle => '加入群组';

  @override
  String get joinInviteBack => '返回';

  @override
  String get joinInviteCodeBlurb => '输入别人分享给你的口令码。直接粘贴整条邀请链接也可以。';

  @override
  String get joinInviteCodeLabel => '邀请口令码';

  @override
  String get joinInviteCodeHint => '粘贴链接或输入口令码';

  @override
  String get joinInviteCodeInvalid => '这看起来不像邀请口令码。';

  @override
  String get joinInviteLookupButton => '继续';

  @override
  String get joinInviteLookupFailed => '无法核对这个口令码。检查网络后再试一次。';

  @override
  String joinInviteMemberCount(Object count) {
    return '$count 名成员';
  }

  @override
  String get joinInviteJoinButton => '加入群组';

  @override
  String get joinInviteRequestButton => '申请加入';

  @override
  String get joinInviteOpenNote => '加入后你就能看到群里的消息。';

  @override
  String get joinInviteApprovalNote => '要先有管理员同意，你才能看到这里的内容。';

  @override
  String get joinInviteOpenRoom => '打开群组';

  @override
  String get joinInvitePendingHeadline => '等待管理员处理';

  @override
  String get joinInvitePendingBody => '一有人答复就会通知你。';

  @override
  String get joinInviteBadLinkHeadline => '这个邀请无效';

  @override
  String get joinInviteBadLinkBody => '检查一下口令码，或者要一条新链接。';

  @override
  String get joinInviteExpiredHeadline => '这个邀请已过期';

  @override
  String get joinInviteExpiredBody => '找邀请你的人要一条新链接。';

  @override
  String get joinInviteExhaustedHeadline => '这个邀请已用完';

  @override
  String get joinInviteExhaustedBody => '它被设成只能用有限次数。再要一个吧。';

  @override
  String get joinInviteRevokedHeadline => '这个邀请已被替换';

  @override
  String get joinInviteRevokedBody => '管理员换了新链接，找他们要当前的那条。';

  @override
  String get joinInviteWrongServerHeadline => '这个邀请属于另一台服务器';

  @override
  String joinInviteWrongServerBody(Object host) {
    return '它属于 $host。你的账号在另一台服务器上，所以从这里进不了这个群。';
  }

  @override
  String get roomInviteErrorNotFound => '没有找到与这个口令码对应的群组。';

  @override
  String get roomInviteErrorRevoked => '这个邀请已被替换，去要当前的链接。';

  @override
  String get roomInviteErrorExpired => '这个邀请已过期。';

  @override
  String get roomInviteErrorExhausted => '这个邀请已用完。';

  @override
  String get roomInviteErrorAlreadyMember => '对方已经在这个群里了。';

  @override
  String get roomInviteErrorAlreadyInvited => '已经邀请过对方了。';

  @override
  String get roomInviteErrorSelf => '你已经在这个群里了。';

  @override
  String get roomInviteErrorInvitationGone => '那个邀请已经不在了。';

  @override
  String get roomInviteErrorRequestPending => '你已经申请过了，管理员会答复。';

  @override
  String get roomInviteErrorRequestGone => '已经有人处理过这条申请了。';

  @override
  String get roomInviteErrorRoomPrivate => '这个群只能通过邀请加入。';

  @override
  String get roomInviteErrorInvalidLimits => '这些限制不可用。';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$child 想邀请 $other 加入 $room';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$other 邀请 $child 加入 $room';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      '邀请会发出去，是否加入仍由对方决定。';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$child 会看到这个邀请，可以接受或拒绝。你同意的话，也就允许孩子在接受后进入那个群。';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf => '你不能把自己移出群组。请改用退出群组。';

  @override
  String get roomAdminActionMessage => '发消息';

  @override
  String get roomAdminActionVoiceCall => '语音通话';

  @override
  String get roomAdminActionVideoCall => '视频通话';

  @override
  String get roomAdminYouSuffix => '你';

  @override
  String get roomInfoScreenSetPasswordButton => '设置';

  @override
  String get roomInfoScreenPasswordSetSnackbar => '密码已设置。';

  @override
  String get roomInfoScreenPasswordSetState => '已设密码';

  @override
  String get roomInfoScreenPasswordUnsetState => '未设密码';

  @override
  String get roomInfoScreenPasswordCancel => '取消';

  @override
  String get roomInfoScreenEditSave => '保存';

  @override
  String get roomInfoScreenEditCancel => '取消';

  @override
  String get roomInviteRotatedToast => '已生成新链接，旧链接已失效。';

  @override
  String get roomInviteRevokedToast => '邀请链接已作废。';

  @override
  String get newChatMenuTitle => '新聊天';

  @override
  String get newChatMenuCreateTitle => '创建房间';

  @override
  String get newChatMenuCreateSub => '创建群组并邀请他人';

  @override
  String get newChatMenuJoinTitle => '用口令码加入';

  @override
  String get newChatMenuJoinSub => '打开别人分享给你的群组';

  @override
  String get shareSheetTitle => '分享到';

  @override
  String get shareSheetSuggestedHeading => '推荐';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个附件',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件超过 $size 上限，已略过',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return '发送给 $title';
  }

  @override
  String get settingsScreenRowSpeakerColors => '发言人颜色';

  @override
  String get settingsScreenValueSpeakerOff => '关闭';

  @override
  String get settingsScreenValueSpeakerName => '名字';

  @override
  String get settingsScreenValueSpeakerBubble => '名字 + 气泡';

  @override
  String get speakerColorScreenTitle => '发言人颜色。';

  @override
  String get speakerColorScreenSubtitle => '不用看名字也知道是谁说的';

  @override
  String get speakerColorScreenOffLabel => '关闭';

  @override
  String get speakerColorScreenOffDescription => '房间里的所有人都用同一种颜色显示。';

  @override
  String get speakerColorScreenNameLabel => '名字';

  @override
  String get speakerColorScreenNameDescription => '每个人都有自己的颜色，显示在名字和头像圈上。';

  @override
  String get speakerColorScreenBubbleLabel => '气泡';

  @override
  String get speakerColorScreenBubbleDescription => '颜色也会延伸到气泡里，连发五条也知道是谁写的。';

  @override
  String get roomInfoScreenSpeakerColorsLabel => '颜色';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => '自动';

  @override
  String get roomInfoScreenSpeakerColorsCustom => '自定义';

  @override
  String get roomColorsScreenTitle => '谁是谁。';

  @override
  String get roomColorsScreenSubtitle => '每个人说话的颜色';

  @override
  String get roomColorsScreenOffTitle => '发言人颜色已关闭';

  @override
  String get roomColorsScreenOffBody => '现在所有人都用同一种颜色显示。打开后，这里的每个人都会有自己的颜色。';

  @override
  String get roomColorsScreenOffAction => '打开';

  @override
  String get roomColorsScreenOffHint => '对所有房间生效，不只是这一个。设置里也有。';

  @override
  String get roomColorsScreenAutoChip => '自动';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return '与 $name 相同';
  }

  @override
  String get roomColorsScreenResetAll => '恢复自动';

  @override
  String get roomColorsScreenLimitToast => '一个房间最多只能固定这么多颜色。';

  @override
  String get roomColorsScreenFailedToast => '无法保存该颜色。';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return '颜色 $index';
  }

  @override
  String get devicesScreenTitle => '你的设备';

  @override
  String get devicesScreenSubtitle => '你登录过此账号的所有地方。';

  @override
  String get devicesScreenLoading => '正在检查…';

  @override
  String get devicesScreenLoadFailed => '无法加载你的设备';

  @override
  String get devicesScreenThisDevice => '当前设备';

  @override
  String get devicesScreenActiveNow => '当前活跃';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications => '通知无法送达此设备';

  @override
  String get devicesScreenRemove => '移除';

  @override
  String get devicesScreenRemoveTitle => '移除此设备？';

  @override
  String devicesScreenRemoveBody(Object name) {
    return '$name 将被退出登录，并停止接收通知。持有该设备的人必须重新登录。';
  }

  @override
  String get devicesScreenRemoveConfirm => '移除';

  @override
  String get devicesScreenRemoveAll => '移除其他所有设备';

  @override
  String get devicesScreenRemoveAllTitle => '移除其他所有设备？';

  @override
  String get devicesScreenRemoveAllBody => '它们都将被退出登录，并停止接收通知。只有当前设备保持登录。';

  @override
  String get devicesScreenRemoveAllConfirm => '全部移除';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已移除 $count 台设备',
      zero: '没有其他设备可移除',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed => '无法移除该设备';

  @override
  String get devicesScreenFootnote =>
      '移除设备会将其退出登录并停止通知。立即生效——该设备下一次尝试操作时就会回到登录界面。';

  @override
  String get attachmentMenuPollLabel => '投票';

  @override
  String get attachmentMenuChecklistLabel => '清单';

  @override
  String get attachmentMenuEventLabel => '活动';

  @override
  String get interactionKindPoll => '投票';

  @override
  String get interactionKindQuiz => '测验';

  @override
  String get interactionKindChecklist => '清单';

  @override
  String get interactionKindEvent => '活动';

  @override
  String get interactionBadgeAnonymous => '匿名';

  @override
  String get interactionBadgeMultiple => '多选';

  @override
  String get interactionBadgeClosed => '已结束';

  @override
  String interactionPercent(int percent) {
    return '$percent%';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names 等 $count 人';
  }

  @override
  String get interactionSeeWhoAnswered => '看看谁回应了';

  @override
  String interactionRemoveItem(String label) {
    return '删除 $label';
  }

  @override
  String interactionChoiceSemantics(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 票',
    );
    return '$label，$_temp0';
  }

  @override
  String get interactionAddItemHint => '添加一项';

  @override
  String get interactionRetract => '撤回';

  @override
  String get interactionClose => '结束';

  @override
  String interactionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 票',
    );
    return '$_temp0';
  }

  @override
  String interactionRsvpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条回应',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$total 项已完成 $done 项';
  }

  @override
  String get interactionNoAnswers => '没有回应';

  @override
  String get interactionBeFirst => '来做第一个回应的人';

  @override
  String interactionFinalResults(String count) {
    return '$count · 最终';
  }

  @override
  String get interactionQuizRight => '答对了';

  @override
  String get interactionQuizWrong => '差一点';

  @override
  String interactionEventPast(String when) {
    return '$when · 已经过去';
  }

  @override
  String get interactionRespondentsTitlePoll => '谁投了票';

  @override
  String get interactionRespondentsTitleChecklist => '谁打了勾';

  @override
  String get interactionRespondentsTitleEvent => '谁回应了';

  @override
  String get interactionRespondentsFailed => '无法加载谁回应了。';

  @override
  String get interactionRespondentsEmpty => '还没有人回应。';

  @override
  String get interactionFilterAll => '全部';

  @override
  String get interactionRsvpGoing => '参加';

  @override
  String get interactionRsvpMaybe => '也许';

  @override
  String get interactionRsvpNo => '去不了';

  @override
  String get interactionComposePollTitle => '新投票';

  @override
  String get interactionComposePollTagline => '问问大家';

  @override
  String get interactionComposeChecklistTitle => '新清单';

  @override
  String get interactionComposeChecklistTagline => '大家都能打勾的清单';

  @override
  String get interactionComposeEventTitle => '新活动';

  @override
  String get interactionComposeEventTagline => '看看谁会来';

  @override
  String get interactionComposeQuestionLabel => '问题';

  @override
  String get interactionComposeQuestionHint => '你想问什么？';

  @override
  String get interactionComposeTitleLabel => '标题';

  @override
  String get interactionComposeTitleHint => '这份清单做什么用？';

  @override
  String get interactionComposeEventNameLabel => '活动';

  @override
  String get interactionComposeEventNameHint => '要做什么？';

  @override
  String get interactionComposeOptionsLabel => '选项';

  @override
  String get interactionComposeItemsLabel => '条目';

  @override
  String interactionComposeOptionHint(int index) {
    return '选项 $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return '条目 $index';
  }

  @override
  String get interactionComposeAddOption => '添加选项';

  @override
  String get interactionComposeAddItem => '添加条目';

  @override
  String get interactionComposeRemoveRow => '删除';

  @override
  String get interactionComposeMarkCorrect => '标记为正确答案';

  @override
  String get interactionComposeMultipleTitle => '多选';

  @override
  String get interactionComposeMultipleSub => '可以选多个';

  @override
  String get interactionComposeAnonymousTitle => '匿名';

  @override
  String get interactionComposeAnonymousOffSub => '所有人都能看到谁投了票';

  @override
  String get interactionComposeAnonymousOnSub => '没有人能看到谁投了票';

  @override
  String get interactionComposeQuizTitle => '测验模式';

  @override
  String get interactionComposeQuizSub => '只有一个正确答案，不能改';

  @override
  String get interactionComposeExplanationLabel => '解释';

  @override
  String get interactionComposeExplanationHint => '回答后显示（可选）';

  @override
  String get interactionComposeOthersMayCheckTitle => '任何人都能打勾';

  @override
  String get interactionComposeOthersMayCheckSub => '不只是你';

  @override
  String get interactionComposeOthersMayAddTitle => '任何人都能添加';

  @override
  String get interactionComposeOthersMayAddSub => '之后还能再加';

  @override
  String get interactionComposeWhenLabel => '时间';

  @override
  String get interactionComposePickStart => '选择开始时间';

  @override
  String get interactionComposePickEnd => '添加结束时间（可选）';

  @override
  String get interactionComposePlaceLabel => '地点';

  @override
  String get interactionComposePlaceHint => '在哪里？（可选）';

  @override
  String get interactionComposeSendPoll => '发送投票';

  @override
  String get interactionComposeSendChecklist => '发送清单';

  @override
  String get interactionComposeSendEvent => '发送活动';

  @override
  String get interactionComposeErrorPrompt => '先写下你要问什么。';

  @override
  String interactionComposeErrorOptions(int count) {
    return '投票至少需要 $count 个选项。';
  }

  @override
  String get interactionComposeErrorItems => '清单至少需要一个条目。';

  @override
  String get interactionComposeErrorAnswer => '标出哪个选项是正确的。';

  @override
  String get interactionComposeErrorWhen => '选择开始的时间。';

  @override
  String get interactionComposeErrorEnd => '结束时间要在开始之后。';

  @override
  String get interactionSendFailed => '没有发送成功。';

  @override
  String get interactionRefused => '没有生效。';

  @override
  String get messageReceiptsScreenTitle => '已读成员';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$total 人中 $read 人已读';
  }

  @override
  String get messageReceiptsEmptyState => '这个房间里还没有其他人';

  @override
  String get messageReceiptsSectionRead => '已读';

  @override
  String get messageReceiptsSectionDelivered => '已送达';

  @override
  String get messageReceiptsSectionSent => '已发送';

  @override
  String get messageReceiptsSectionHidden => '无回执';

  @override
  String get messageReceiptsStateHidden => '未共享';

  @override
  String get messageReceiptsStateWaiting => '等待中';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name 于 $day $time 已读';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name 于 $day $time 收到';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name 尚未收到';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name 未共享已读回执';
  }

  @override
  String get companionsScreenTitle => '伙伴。';

  @override
  String get companionsScreenSubtitle => '住在这台手机里、从不往外传数据的小帮手';

  @override
  String get companionSebastianTagline => '翻译消息';

  @override
  String get companionSebastianBlurb =>
      'Sebastian 会读懂用其他语言写的消息，并告诉你它在说什么——就在你的手机上完成，不会把任何内容发送到别处。';

  @override
  String get companionMarloweTagline => '通用助手';

  @override
  String get companionMarloweBlurb => 'Marlowe 负责翻译以外的一切。先选一个大脑，能力会陆续到来。';

  @override
  String get companionAssuranceOnDevice => '完全在这台设备上运行';

  @override
  String get companionAssurancePrivate => '你的消息永远不会离开手机';

  @override
  String get companionAssuranceOffline => '没有网络也能用';

  @override
  String companionInstallAction(Object size) {
    return '安装 · $size';
  }

  @override
  String get companionInstallOneTime => '只需下载一次，除非你删除，否则一直保留';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$received / $total';
  }

  @override
  String get companionInstallQueued => '正在等待另一个下载完成';

  @override
  String get companionInstallCancel => '取消';

  @override
  String get companionInstallRetry => '重试';

  @override
  String companionInstallReady(Object name) {
    return '$name 准备好了';
  }

  @override
  String get companionInstallFailedNetwork => '下载未能完成。请检查网络连接后重试。';

  @override
  String get companionInstallFailedStorage => '这台设备的空间不足。请清理一些空间后重试。';

  @override
  String get companionInstallFailedUnknown => '下载未能完成。';

  @override
  String get companionUnsupportedPlatform => '此版本的应用暂不支持伙伴功能。';

  @override
  String companionBrainNeedsMemory(String size) {
    return '需要 $size 内存';
  }

  @override
  String get sebastianTierSeniorDetail => '更精准的翻译';

  @override
  String get sebastianTierJuniorDetail => '任何手机都能运行';

  @override
  String get sebastianLanguageUnlisted => '不在他的语言范围内 — 结果可能粗糙';

  @override
  String get companionStatusNotInstalled => '未安装';

  @override
  String get companionStatusOff => '已关闭';

  @override
  String companionStatusTranslatingInto(Object language) {
    return '正在翻译成$language';
  }

  @override
  String get companionStatusNoBrain => '还没有下载任何内容';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个下载已就绪',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty => '没有下载任何内容——伙伴不占空间';

  @override
  String companionStorageUsed(Object size) {
    return '伙伴占用 $size';
  }

  @override
  String get companionSectionGeneral => '通用';

  @override
  String get companionSectionStorage => '存储';

  @override
  String get companionBrainRemove => '删除';

  @override
  String companionBrainRemoveTitle(Object name) {
    return '删除$name？';
  }

  @override
  String companionRemoveTitle(Object name) {
    return '删除 $name？';
  }

  @override
  String companionRemoveMessage(Object size) {
    return '这会释放 $size。你随时可以重新下载。';
  }

  @override
  String get companionRemoveConfirm => '删除';

  @override
  String get sebastianEnableLabel => '让 Sebastian 翻译';

  @override
  String get sebastianEnableDetail => '关闭即可停用他，同时保留已下载的内容';

  @override
  String get sebastianLanguageSection => '翻译成';

  @override
  String get sebastianLanguageFollowApp => '与应用相同';

  @override
  String sebastianBrainDetail(Object size) {
    return '在这台设备上 · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已保存 $count 条翻译',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => '清除';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe 目前还什么都做不了——能力还在路上。你现在能做的，是先准备好一个大脑，等能力上线时就不用再等下载了。';

  @override
  String get marloweBrainsSection => '大脑';

  @override
  String get marloweBrainsCaption => '越大思考得越好，回答也越慢。你可以保留多个并随时切换。';

  @override
  String get marloweBrainTierSwift => '轻快';

  @override
  String get marloweBrainTierBalanced => '均衡';

  @override
  String get marloweBrainTierDeep => '深度';

  @override
  String get translationSlabShowOriginal => '显示原文';

  @override
  String get translationSlabFailed => '这条消息无法翻译。';

  @override
  String get translationSlabRetry => '重试';

  @override
  String translationSlabByCompanion(Object name) {
    return '由 $name 翻译';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return '译自$language';
  }

  @override
  String get messageActionMenuTranslateLabel => '翻译';

  @override
  String get messageActionMenuShowOriginalLabel => '显示原文';

  @override
  String get roomTranslateTitle => '翻译此聊天';

  @override
  String get roomTranslateStopTitle => '停止翻译';

  @override
  String get roomTranslateSectionLabel => '翻译';

  @override
  String get roomTranslateOnRow => '正在翻译此聊天';

  @override
  String get roomTranslateOffRow => '已关闭';

  @override
  String get roomTranslateNeedsSetUp => '设置 Sebastian';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'Sebastian 正在翻译 · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return '以$language阅读';
  }

  @override
  String get roomTranslateStop => '停止';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return '已经是$language了';
  }

  @override
  String get roomScreenTranslateRoomOffer => '要把这个聊天的其余部分也翻译了吗？';

  @override
  String get roomScreenTranslateRoomOfferAction => '全部翻译';

  @override
  String get settingsScreenCompanionsOff => '已关闭';

  @override
  String get settingsScreenCompanionsUnavailable => '不可用';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return '$name 也在使用';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return '$name 使用的是同一个下载，也会一并失去。';
  }

  @override
  String get companionBrainInUse => '使用中';

  @override
  String companionStatusUsingBrain(Object name) {
    return '正在使用$name';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name 仍在下载 — 设置 › 伙伴';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return '下载中 · $percent%';
  }

  @override
  String get companionInstallPause => '暂停';

  @override
  String get companionInstallResume => '继续';

  @override
  String get companionInstallDiscard => '丢弃';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return '已暂停 · $received / $total';
  }

  @override
  String get companionInstallFailedIntegrity => '下载的文件与此版本预期的不符，将重新开始。';

  @override
  String companionBannerDownloading(
    Object name,
    Object received,
    Object total,
  ) {
    return '$name · $received / $total';
  }

  @override
  String companionBannerPaused(Object name, Object received, Object total) {
    return '$name 已暂停 · $received / $total';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name 正在唤醒…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => '重新翻译';

  @override
  String get groupCallScreenShareLabel => '共享';

  @override
  String get groupCallScreenStopShareLabel => '停止共享';

  @override
  String get groupCallScreenShareStartingLabel => '启动中…';

  @override
  String get groupCallScreenRingingLabel => '呼叫中…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$name 正在共享屏幕';
  }

  @override
  String get groupCallScreenYouAreSharing => '你正在共享屏幕';

  @override
  String get groupCallScreenMinimizeLabel => '隐藏';

  @override
  String get groupCallScreenDrawLabel => '绘制';

  @override
  String get callScreenControlShare => '共享';

  @override
  String get callScreenControlStopShare => '停止';

  @override
  String get callScreenControlShareStarting => '启动中…';

  @override
  String get screenShareStopDrawing => '停止绘制';

  @override
  String get callScreenControlDraw => '绘制';

  @override
  String get callScreenControlMinimize => '隐藏';

  @override
  String get inCallPillOngoingCall => '通话进行中';

  @override
  String get inCallPillReturn => '返回';

  @override
  String get inCallPillSharing => '正在共享你的屏幕';

  @override
  String get inCallPillDrawSemanticLabel => '在共享屏幕上绘制';

  @override
  String get inCallPillStopSharingSemanticLabel => '停止共享';

  @override
  String get screenShareUnsupported => '此设备不支持屏幕共享';

  @override
  String get screenShareEphemeralWarning => '共享期间截屏保护已关闭';

  @override
  String get screenShareNotificationTitle => '正在共享你的屏幕';

  @override
  String get screenShareNotificationBody => '通话中的所有人都能看到';

  @override
  String get screenShareNotificationStop => '停止';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$name 已在共享';
  }

  @override
  String get screenShareFailed => '无法开始共享';

  @override
  String get screenSharePickerTitle => '共享你的屏幕';

  @override
  String get screenSharePickerScreens => '屏幕';

  @override
  String get screenSharePickerWindows => '窗口';

  @override
  String get screenSharePickerEmpty => '暂时没有可共享的内容——请在系统设置中允许屏幕录制后重试';

  @override
  String get gameTellFriends => '告诉好友';

  @override
  String get gameToldFriends => '已告诉';

  @override
  String get gameTellFriendsTitle => '告诉好友吗？';

  @override
  String get gameTellFriendsBody => '他们会收到这条结果的通知。只能发一次。';

  @override
  String get gameTellFriendsCancel => '暂不';

  @override
  String get gameTellFriendsConfirm => '发送';

  @override
  String get gameTellFriendsSent => '已发送';

  @override
  String get gameTellFriendsPrivate => '你的每日成绩不公开，没人看得到';

  @override
  String get gameTellFriendsFailed => '发送失败';

  @override
  String get settingsScreenFriendActivityLabel => '好友动态';

  @override
  String get settingsScreenFriendActivityOnBody => '好友发布的动态、点数和游戏成绩';

  @override
  String get settingsScreenFriendActivityOffBody => '没有通知 — 你去看时他们的板子还在';

  @override
  String get searchScreenActionWithGrownUp => '等大人确认';

  @override
  String get newChatMenuSearchHint => '搜索你的好友';

  @override
  String get newChatMenuNoFriendsYet => '还没有好友 —\\n去发现页找找人';

  @override
  String get newChatMenuNoFriendsMatch => '没有匹配的好友';

  @override
  String get newChatMenuOpenDmFailed => '打不开那个聊天 — 请重试';

  @override
  String get childPolicyScreenAddSomeoneLabel => '从你的联系人里挑';

  @override
  String get childPolicyScreenPickPersonHint => '搜索名字或用户名';

  @override
  String get childPolicyScreenPickPersonEmpty => '好友里没有可添加的人了 —\\n可以搜索其他人';

  @override
  String get childPolicyScreenPickPersonNoMatch => '没有匹配的人';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => '你的好友';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => '其他人';

  @override
  String get childPolicyScreenAddRoomLabel => '添加房间';

  @override
  String get childPolicyScreenPickRoomHeading => '添加房间';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return '你自己的房间。$name 会立刻加入，在你收回之前都能在那里阅读和发言。';
  }

  @override
  String get childPolicyScreenPickRoomHint => '搜索你的房间';

  @override
  String get childPolicyScreenPickRoomEmpty => '没有可添加的房间了';

  @override
  String get childPolicyScreenPickRoomNoMatch => '没有匹配的房间';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name 现在在 $room 里';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric => '添加那个房间失败 — 请重试';

  @override
  String get childPolicyScreenErrorRoomNotAllowed => '那个房间不能这样添加';

  @override
  String get childPolicyScreenErrorRoomGone => '那个房间已经不存在了';
}
