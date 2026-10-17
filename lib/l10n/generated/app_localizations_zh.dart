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
  String get roomScreenDeleteConfirmBodyOne => '这会把这条消息从聊天里所有人那删除，且无法撤销。';

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
  String get roomReadOnlyFooter => '这是只读房间，只有 MonkeyHub 会在这里发消息。';

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
  String get messageBubblePlayOnceLabel => '仅播放一次';

  @override
  String get messageBubblePlayOnceTapToPlay => '轻点播放';

  @override
  String get messageBubblePlayOncePlayed => '已播放';

  @override
  String get messageBubblePlayOnceVoiceSemanticLabel => '仅可播放一次的语音消息，轻点播放';

  @override
  String get messageBubblePlayOnceVideoNoteSemanticLabel => '仅可播放一次的视频留言，轻点播放';

  @override
  String get replyIndicatorPlayOnceVoiceLabel => '语音消息 · 仅播放一次';

  @override
  String get replyIndicatorPlayOnceVideoNoteLabel => '视频留言 · 仅播放一次';

  @override
  String get roomScreenPlayOnceVoiceAlreadyPlayed => '你已经听过这条语音消息了。';

  @override
  String get roomScreenPlayOnceVoiceGone => '这条语音消息已不可用。';

  @override
  String get roomScreenPlayOnceVoiceNetworkError => '无法加载这条语音消息。';

  @override
  String get roomScreenPlayOnceVideoNoteAlreadyPlayed => '你已经看过这条视频留言了。';

  @override
  String get roomScreenPlayOnceVideoNoteGone => '这条视频留言已不可用。';

  @override
  String get roomScreenPlayOnceVideoNoteNetworkError => '无法加载这条视频留言。';

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
      '对方已经给你发过请求了，去看看请求列表吧。';

  @override
  String get profileScreenErrorRequestAlreadySent => '请求已经发送过了。';

  @override
  String get profileScreenErrorUnblockFirst => '你已经拉黑了这个人，先取消拉黑吧。';

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
  String get profileScreenGrownUpOnlyNote => '只有大人才能这么做，需要他们的验证码或密码。';

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
  String get profileScreenRedactedStranger => '内容有限，加为好友可以看到更多。';

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
  String get glassScreenSurfacesNote => '输入框、顶部栏、通话按钮：所有浮在文字上方、而非滚动内容上方的元素';

  @override
  String get glassScreenMatchBottomBar => '匹配底部栏';

  @override
  String get glassScreenPresetEditedSubtitle => '已修改，另存为新外观，或重置';

  @override
  String get glassScreenCustomPresetName => '自定义';

  @override
  String get glassScreenUnsavedSubtitle => '未保存，给它起个名字才能保留';

  @override
  String get glassScreenSaveDialogTitle => '保存此效果为';

  @override
  String get glassScreenNoRoomToast => '空间不足，请先删除一个效果';

  @override
  String get glassScreenRenameDialogTitle => '重命名';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '删除$name？';
  }

  @override
  String get glassScreenDeleteConfirmBody => '效果仍会留在屏幕上，只是不再有名字。';

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
  String get glassScreenBackdropMsgDilan => '发了屋顶的照片，瓦片全裂了';

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
    return '$peerName 也会失去这段对话。你们双方的所有消息都会消失，且无法恢复。';
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
  String get roomNameReservedError => '房间名称不能以 dm: 开头';

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
  String get roomInfoScreenDescriptionHint => '用一句话介绍这个房间';

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
      '此聊天室已设密码保护。出于安全原因,系统不会显示当前密码，输入新密码即可替换。';

  @override
  String get roomInfoScreenReplacePasswordHint => '替换密码';

  @override
  String get roomInfoScreenSetPasswordHint => '设置密码以锁定';

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
    return '以后不会再为这件事询问你了，无论是$childName添加他们，还是他们添加$childName。';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => '允许某人';

  @override
  String get childPolicyScreenAskToAddLabel => '申请添加';

  @override
  String get childPolicyScreenAskToAddOffDesc => '仅限家人，不接受新请求';

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
  String get childPolicyScreenContactAddedRequestSent => '已添加，请求正在发送';

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
  String get childPolicyScreenDeleteAccountFailed => '无法删除账号，请重试';

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
  String get childPolicyScreenErrorAddContactGeneric => '无法添加，请重试';

  @override
  String get childPolicyScreenErrorCannotAddSelf => '这是他们自己的用户名';

  @override
  String get childPolicyScreenErrorChildNotAllowed => '孩子不能成为大人';

  @override
  String get childPolicyScreenErrorGenericGuardian => '没能完成，再试一次';

  @override
  String get childPolicyScreenErrorLastGuardian => '得有人照顾孩子，请先添加另一位大人';

  @override
  String get childPolicyScreenErrorNotYours => '这不是你能更改的';

  @override
  String get childPolicyScreenErrorUserNotFound => '找不到这个用户名对应的账号';

  @override
  String get childPolicyScreenGraduateBlurb =>
      '孩子会用这个密码变成普通账号,所有大人都将失去查看权限。此操作不可撤销，之后你就得像其他人一样,被邀请后才能重新加入。';

  @override
  String get childPolicyScreenGraduateCta => '毕业';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      '孩子保留一切,并获得一个密码。你将失去所有查看权限。不可撤销。';

  @override
  String get childPolicyScreenGraduateDangerLabel => '毕业成为完整账号';

  @override
  String get childPolicyScreenGraduateFailed => '毕业失败，再试一次';

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
      '这里的每一位都能批准请求、修改设置、查看所有内容。任何一位都可以单独操作，不用等其他人。';

  @override
  String get childPolicyScreenGuardianAdded => '添加成功，现在可以照顾孩子了';

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
      '这里的任何人都能直接添加,不需要再次征求你的同意，不管是谁先发起。';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      '对孩子始终关闭。发现（那些属于陌生人的房间列表）完全隐藏,且无法开启。别人邀请孩子加入的房间仍可正常使用。';

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
  String childPolicyScreenRoomMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
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
    return '你是$name唯一的大人,不能直接退出。请先添加另一位大人,或者试试下面这些方式。';
  }

  @override
  String get childPolicyScreenStepAwayLabel => '退出';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return '你会失去查看$name账号的所有权限：他们的请求、联系人、聊天室,你都看不到了。其他大人会继续照看他们。';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => '停止监护';

  @override
  String get childPolicyScreenStopSupervisingHeadline => '停止监护?';

  @override
  String get childPolicyScreenTakeBackFailed => '没能收回，再试一次';

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
    return '使用中：$name';
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
  String callScreenStatusCalling(String kind) {
    return '$kind · 呼叫中…';
  }

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind · 响铃中…';
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
  String get callAudioControlLabel => '音频';

  @override
  String get callAudioSheetTitle => '音频';

  @override
  String get callAudioRoutePhone => '手机';

  @override
  String get callAudioRouteHeadphones => '耳机';

  @override
  String get callAudioRouteBluetooth => '蓝牙';

  @override
  String get callAudioRouteCar => '汽车';

  @override
  String get callAudioRouteOther => '其他设备';

  @override
  String get callAudioMicFollowsNote => '麦克风会随所选设备一起切换。';

  @override
  String get callAudioMicrophoneHeader => '麦克风';

  @override
  String get callAudioUnknownDevice => '未知设备';

  @override
  String get callAudioNoDevices => '未找到设备';

  @override
  String get callAudioSwitchFailed => '无法切换音频设备';

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
  String get friendRequestDraftScreenHintStartWith => '先说点什么';

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
  String get discoverScreenYourPeopleLabel => '好友';

  @override
  String get discoverScreenNoFriendsYetWithHint => '还没有人 · 去上面找人吧';

  @override
  String get discoverScreenNoFriendsYet => '还没有人';

  @override
  String get discoverScreenSearchRoomsTitle => '搜索房间';

  @override
  String get discoverScreenSearchRoomsSubtitle => '按名称搜索公开房间';

  @override
  String get discoverScreenYourRoomsLabel => '房间';

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
  String get searchScreenHintPeople => '搜索用户';

  @override
  String get searchScreenHintRooms => '搜索公开房间';

  @override
  String get searchScreenPeoplePromptChild => '输入完整用户名才能找到新朋友';

  @override
  String get searchScreenPeoplePromptDefault => '按用户名或昵称搜索';

  @override
  String get searchScreenNoMatchChild => '没有匹配结果。添加新朋友\n需要完整且准确的用户名';

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
  String get recoveryPhraseScreenCopiedSnackbar => '已复制，粘贴到安全的地方';

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
  String get recoveryPhraseScreenKeepPhraseLink => '暂不，保留我目前的恢复短语';

  @override
  String get homeScreenProfileSemanticLabel => '你的个人资料';

  @override
  String homeScreenGreeting(Object name) {
    return '嗨，$name。';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => '新建房间';

  @override
  String get homeScreenEmptyRoomsMessage => '还没有房间，创建一个吧';

  @override
  String get groupCallScreenTitleVideo => '群组视频通话';

  @override
  String get groupCallScreenTitleVoice => '群组语音通话';

  @override
  String groupCallScreenParticipantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人通话中',
      one: '只有你',
    );
    return '$_temp0';
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
  String get createRoomSheetNameHint => '起个诚实的名字';

  @override
  String get createRoomSheetDescriptionLabel => '描述 · 选填';

  @override
  String get createRoomSheetDescriptionHint => '用一句话介绍一下';

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
  String get createRoomSheetPasswordHint => '用密码把它锁上';

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
  String get textFileViewerTruncatedNotice => '仅显示部分内容，下载以查看完整文件。';

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
    return '在$name的手机上打开MonkeyHub扫一下这个，或者直接输入数字。';
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
  String get deepOceanThemeEphemeralHint => '说点悄悄话';

  @override
  String get deepOceanThemeDefaultHint => '说点什么';

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
  String get photoDeckBackToFirst => '回到第一张';

  @override
  String get inlinePickerCommentHint => '添加评论或直接发送';

  @override
  String get attachmentMenuGalleryLabel => '相册';

  @override
  String inlinePickerVideoCompressNote(String size) {
    return '超过 $size，将压缩后发送';
  }

  @override
  String messageMenuAlbumAll(int count) {
    return '全部（$count）';
  }

  @override
  String get messageMenuAlbumOne => '仅此一项';

  @override
  String replyAlbumItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项',
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
    return '这样$name就会从这部手机退出登录并交还手机，手机会回到平时的登录界面,谁都能使用。';
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
      '带主题色的引用胶囊，配有连线条和头像，熟悉的 WhatsApp 风格。';

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
      '其他人都需要先经过你同意，无论是ta主动添加的人，还是主动添加ta的人。';

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
  String get bubbleStyleScreenSoftDescription => '没有尾巴，连续消息仅靠收紧的内角衔接在一起。';

  @override
  String get bubbleStyleScreenPillLabel => '胶囊';

  @override
  String get bubbleStyleScreenPillDescription => '完全圆润的胶囊形状,每一行都一样。';

  @override
  String get bubbleStyleScreenSlabLabel => '块状';

  @override
  String get bubbleStyleScreenSlabDescription => '方正边角：锐利、工整、干脆。';

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
  String get groupCallBannerPasswordHint => '暗号';

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
  String get discoverListsPeopleTitle => '好友';

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
  String get discoverListsFilterHint => '搜索好友';

  @override
  String get discoverListsClearFilterSemanticLabel => '清除筛选';

  @override
  String get discoverListsNoOneYet => '还没有人';

  @override
  String discoverListsNoMatches(Object query) {
    return '没有找到匹配「$query」的人';
  }

  @override
  String get discoverListsRoomsTitle => '房间';

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
  String get discoverListsFilterRoomsHint => '搜索你的房间';

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
  String get reportSheetPrivacyNote => '举报是保密的，对方不会收到通知。';

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
      '你们目前是好友。屏蔽会解除好友关系，以后想重新联系就得重新发送好友请求。';

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
      '同时清空你与对方的私信，所有消息、表情回应和媒体文件都会被删除。';

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
  String get feedBoardLoadFailed => '无法加载看板，请稍后再试';

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
      '告诉我们出了什么问题。应用和设备信息会自动附上，还会附上一份记录应用当时运行情况的技术日志，正是这些帮助我们找到原因。';

  @override
  String get reportProblemDescribeLabel => '发生了什么';

  @override
  String get reportProblemDescribeHint => '屏幕闪烁、按钮没反应';

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
  String get settingsScreenLinksUrlsOffBody => '当前仅显示预览，气泡更简洁，点击即可打开';

  @override
  String get settingsScreenMenuBarLabel => '菜单栏图标';

  @override
  String get settingsScreenMenuBarOnBody => 'MonkeyHub 会带着未读数量停留在菜单栏，点按即可打开窗口';

  @override
  String get settingsScreenMenuBarOffBody => '当前已关闭。想找回隐藏的窗口只能通过 Dock 图标';

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
  String get videoQualityScreenHd1080Subtitle => '全高清：更清晰，占用更多流量';

  @override
  String get videoQualityScreenUhd4kSubtitle => '超高清：网络良好时效果最佳';

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
  String get settingsScreenPushOffBody => '静音，只有打开App才能看到';

  @override
  String get settingsScreenGameRemindersLabel => '每日游戏提醒';

  @override
  String get settingsScreenGameRemindersOnBody => '中午提醒一次，只在你还没玩的时候';

  @override
  String get settingsScreenGameRemindersOffBody => '不提醒，游戏随时都在';

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
  String get authErrorChildMustPair => '这是一个儿童账号，请向大人索要配对码。';

  @override
  String get authErrorPairingCodeExpired => '该配对码已过期，请重新申请一个。';

  @override
  String get authErrorPairingCodeInvalid => '该配对码无效，可能已被使用过。';

  @override
  String get authErrorUseSocialSignIn => '该账号使用Apple或Google登录，请点击下方按钮。';

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
  String get glassKnobHintRimOpacity => '玻璃边缘的亮度。设为零可隐藏边框';

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
  String get motionScreenCalmSubtitle => '装饰静止，其他一切照旧';

  @override
  String get momentRailCaptureLabel => '拍摄';

  @override
  String get momentRailYouLabel => '你';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author：$caption';
  }

  @override
  String momentRailPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个精彩瞬间',
    );
    return '$_temp0';
  }

  @override
  String momentRailPersonNewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个新的',
    );
    return '$_temp0';
  }

  @override
  String get momentRailAddHighlight => '添加精彩瞬间';

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
  String get momentComposerTitle => '新瞬间';

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
  String get momentComposerErrorDailyCap => '今天已经五个了，给明天留点';

  @override
  String get momentComposerErrorNotAllowed => '监护人已关闭照片分享';

  @override
  String get momentComposerErrorTooLong => '有点长，精简一下';

  @override
  String get momentComposerErrorEmpty => '加一张照片或几句话';

  @override
  String get momentComposerErrorGeneric => '发布失败，请重试';

  @override
  String get momentViewerDelete => '删除';

  @override
  String get momentViewerDeleteConfirmHeadline => '删除这条？';

  @override
  String get momentViewerDeleteConfirmBody => '它会从所有人的看板和你的归档中永久消失';

  @override
  String get momentViewerDeleteFailed => '删除失败，请重试';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$who 发布了一个瞬间';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$name 得了一分：$tag';
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
  String get puzzleShareCopied => '已复制，发给朋友';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => '今天的你已经解开了';

  @override
  String get puzzleErrorOutOfGuesses => '今天没有剩余次数';

  @override
  String get puzzleErrorGeneric => '发送失败，请重试';

  @override
  String get puzzleGuessWaiting => '没有网络。你的猜测已保存，恢复连接后会自动发送';

  @override
  String get gameSubmitWaiting => '没有网络。你完成的棋盘已保存，恢复连接后会自动提交';

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
  String get profileVisibilityScreenPointsPastDesc => '今天始终与好友共享，此项开放的是今天之前的全部';

  @override
  String get momentComposerVideo => '视频';

  @override
  String get momentComposerErrorTooBig => '这个视频太大了，最大 20 MB';

  @override
  String get momentActivityPostedHighlightSelf => '你发布了一个瞬间';

  @override
  String momentActivityScoredSelf(Object tag) {
    return '你得了一分：$tag';
  }

  @override
  String momentActivityGameSolved(String game, String name) {
    return '$name 解开了：$game';
  }

  @override
  String momentActivityGameSolvedSelf(String game) {
    return '你解开了：$game';
  }

  @override
  String momentActivityGameMissed(String game, String name) {
    return '$name 没解开：$game';
  }

  @override
  String momentActivityGameMissedSelf(String game) {
    return '你没解开：$game';
  }

  @override
  String momentActivityCodeSolved(String name) {
    return '$name 破解了密码';
  }

  @override
  String get momentActivityCodeSolvedSelf => '你破解了密码';

  @override
  String momentActivityCodeMissed(String name) {
    return '$name 没破解密码';
  }

  @override
  String get momentActivityCodeMissedSelf => '你没破解密码';

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
  String get pointComposerAdd => '添加一个积分';

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
      '一个记着分数的长期玩笑。当你遇到什么事（好的、坏的，或者只是离奇），就记下来，它会在当天出现在看板上。';

  @override
  String get pointsExplainerRuleHonour => '分是你自己给的。没人核对，这正是乐趣所在，过头了朋友自然会说你。';

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
  String get feedBoardGamesLabel => '游戏';

  @override
  String get feedBoardGamesOpen => '排行榜';

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
  String get gameShareCopied => '已复制，粘贴给好友';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number · $time';
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
  String get gameHintWrong => '这一步错了，已经清掉了。';

  @override
  String get gameHintWrongMore => '还有要改的地方。准备好了再来问。';

  @override
  String get gameHintWrongLast => '你放的其他都对。';

  @override
  String get gameHintReveal => '暂时没有哪条规则能单独确定一个格子，所以直接给你一个。';

  @override
  String get gameHintQueensRegion => '这个颜色里只剩一个位置能放王冠。';

  @override
  String get gameHintQueensRow => '这一行里只剩一个位置能放王冠。';

  @override
  String get gameHintQueensCol => '这一列里只剩一个位置能放王冠。';

  @override
  String get gameHintQueensRegionInRow => '这个颜色只能落在这一行，所以这一行的其他格子不能放王冠。';

  @override
  String get gameHintQueensRegionInCol => '这个颜色只能落在这一列，所以这一列的其他格子不能放王冠。';

  @override
  String get gameHintQueensRowInRegion => '这一行只在一种颜色里有空位，所以那个颜色的其他格子不能放王冠。';

  @override
  String get gameHintQueensColInRegion => '这一列只在一种颜色里有空位，所以那个颜色的其他格子不能放王冠。';

  @override
  String get gameHintStarsRegion => '这个颜色剩下的空位刚好够放还缺的星星。';

  @override
  String get gameHintStarsRow => '这一行剩下的空位刚好够放还缺的星星。';

  @override
  String get gameHintStarsCol => '这一列剩下的空位刚好够放还缺的星星。';

  @override
  String get gameHintTangoEqual => '= 号表示两个格子一样。';

  @override
  String get gameHintTangoCross => '× 号表示两个格子相反。';

  @override
  String get gameHintTangoPair => '相邻的两个已经一样了，所以下一个得是另一种。';

  @override
  String get gameHintTangoSandwich => '两边的格子一样，所以中间得是另一种。';

  @override
  String get gameHintTangoRowSuns => '这一行已经有三个太阳了。';

  @override
  String get gameHintTangoRowMoons => '这一行已经有三个月亮了。';

  @override
  String get gameHintTangoColSuns => '这一列已经有三个太阳了。';

  @override
  String get gameHintTangoColMoons => '这一列已经有三个月亮了。';

  @override
  String gameHintLatinBox(int digit) {
    return '这个宫里，$digit 只能放在这里。';
  }

  @override
  String gameHintLatinRow(int digit) {
    return '这一行里，$digit 只能放在这里。';
  }

  @override
  String gameHintLatinCol(int digit) {
    return '这一列里，$digit 只能放在这里。';
  }

  @override
  String get gameHintLatinOnly => '这里只能填一个数字。其他数字已经在它所在的行、列或宫里了。';

  @override
  String get gameHintLatinOnlyLines => '这里只能填一个数字。其他数字已经在它所在的行或列里了。';

  @override
  String get gameHintLatinOnlySigns => '算上它所在的行、列和符号，这里只能填一个数字。';

  @override
  String get gameHintNonogramRowFill => '这一行的数字不管怎么摆，都会盖住这个格子。';

  @override
  String get gameHintNonogramRowCross => '这一行的数字不管怎么摆，都碰不到这个格子。';

  @override
  String get gameHintNonogramColFill => '这一列的数字不管怎么摆，都会盖住这个格子。';

  @override
  String get gameHintNonogramColCross => '这一列的数字不管怎么摆，都碰不到这个格子。';

  @override
  String get gameHintMinesStart => '从这里开始。这个格子一定安全。';

  @override
  String get gameHintMinesSafe => '这个数字周围的雷都已经插旗了，所以周围其他格子都安全。';

  @override
  String get gameHintMinesFlag => '这个数字要求周围每个没翻开的格子都是雷。';

  @override
  String get gameHintMinesProofSafe => '这个格子周围的数字证明它是安全的。';

  @override
  String get gameHintMinesProofMine => '这个格子周围的数字证明它是雷。';

  @override
  String get gameHintFlowPipe => '这是一整条管道，从一个点连到另一个点。';

  @override
  String get gameHintPatchesOnly => '这个提示只放得下一种拼块。';

  @override
  String get gameHintPatchesCell => '这里有个格子只能归这个提示，所以它的拼块就定了。';

  @override
  String get gameHintPatchesSqueeze => '周围的拼块让这个提示只剩一种放法。';

  @override
  String get gameErrorGeneric => '无法连接游戏，请重试';

  @override
  String get gameInfoOpen => '玩法说明';

  @override
  String get gameInfoScoringTimed => '最快完成的人赢。离开时计时会暂停。用时相同，名次相同。';

  @override
  String get gameInfoScoringGuesses => '猜的次数最少的人赢。不计时间。次数相同，名次相同。';

  @override
  String get gameInfoSameForEveryone => '今天每个人的题目都一样。';

  @override
  String get savedMessagesTitle => '保存的消息';

  @override
  String homeScreenNoSearchResults(Object query) {
    return '没有与\"$query\"匹配的聊天';
  }

  @override
  String get pullRevealSearchHint => '搜索聊天';

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
  String get childPolicyScreenLocationOnDesc => '他们可以共享所在位置，包括最长 8 小时的实时共享';

  @override
  String get childPolicyScreenLocationOffDesc => '他们不能共享所在位置';

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
  String get composerCaptureLockedCancel => '取消';

  @override
  String get composerCaptureViewOnceLabel => '仅播放一次';

  @override
  String get composerCaptureViewOnceVoiceHint => '对方只能听一次';

  @override
  String get composerCaptureViewOnceVideoHint => '对方只能看一次';

  @override
  String get composerCapturePauseLabel => '暂停录制';

  @override
  String get composerCaptureResumeLabel => '继续录制';

  @override
  String get composerCaptureFlashLabel => '闪光灯';

  @override
  String get composerCaptureReviewPlayLabel => '播放录音';

  @override
  String get composerCaptureReviewStopLabel => '停止播放';

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
  String get videoNoteScrubHint => '手指远离圆圈可更精细地拖动';

  @override
  String get videoNoteScrubHalf => '半速拖动';

  @override
  String get videoNoteScrubFine => '精细拖动';

  @override
  String videoNoteSpeedLabel(String speed) {
    return '播放速度 $speed';
  }

  @override
  String get videoNoteAutoAdvanceOn => '自动播放：开';

  @override
  String get videoNoteAutoAdvanceOff => '自动播放：关';

  @override
  String get videoNoteAutoAdvanceSemanticLabel => '自动播放下一条视频留言';

  @override
  String get composerCaptureStartRecordingLabel => '开始录制';

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
    return '将在$when发送';
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
  String get scheduledListDeleteHeadline => '删除定时消息';

  @override
  String get scheduledListDeleteBody => '这条消息将不会发送。';

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
  String get serverOnboardingSubtitle => '此版本未附带服务器，请指向你自己的服务器';

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
      'MonkeyHub 的运营者暂时把流量切到了他们家里的服务器。一切照常运作，这是有意为之，不是故障。';

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
  String get loginScreenUsePasswordInstead => '改用密码';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      '在手机上打开 MonkeyHub，进入个人资料，点按“扫码登录”，然后将相机对准这里，也可以输入下方的代码。';

  @override
  String get deviceLoginScreenWaiting => '正在等待确认…';

  @override
  String get deviceLoginScreenApproved => '已确认，正在登录…';

  @override
  String get deviceLoginScreenDenied => '已在手机上拒绝登录请求';

  @override
  String get deviceLoginScreenGenericError => '出了点问题，请换个新码再试';

  @override
  String get profileScreenScanToSignInLabel => '扫码登录';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro => '将相机对准电脑上显示的代码，或在下方输入。';

  @override
  String get deviceLoginScanScreenScanButtonLabel => '扫码';

  @override
  String get deviceLoginScanScreenConfirmTitle => '要在此设备上登录吗？';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return '$deviceInfo 想以你的身份登录。只有此刻是你本人在操作时才批准。';
  }

  @override
  String get deviceLoginScanScreenApproveButton => '批准';

  @override
  String get deviceLoginScanScreenDenyButton => '拒绝';

  @override
  String get deviceLoginScanScreenSuccess => '已在你的另一台设备上登录';

  @override
  String get deviceLoginScanScreenGenericError => '无法批准，请重试';

  @override
  String get authErrorDeviceLoginInvalid => '这个代码不对。';

  @override
  String get authErrorDeviceLoginExpired => '这个代码已过期，请在另一台设备上获取新码。';

  @override
  String get deviceLoginScanScreenDeniedConfirmation => '已拒绝登录请求';

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
  String get newChatMenuJoinSub => '打开分享给你的群组';

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
      '移除设备会将其退出登录并停止通知。立即生效：该设备下一次尝试操作时就会回到登录界面。';

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
  String get messageReceiptsScreenTitle => '消息详情';

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
      'Sebastian 会读懂用其他语言写的消息，并告诉你它在说什么，就在你的手机上完成，不会把任何内容发送到别处。';

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
  String get sebastianLanguageUnlisted => '不在他的语言范围内，结果可能粗糙';

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
  String get companionStorageEmpty => '没有下载任何内容，伙伴不占空间';

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
      'Marlowe 目前还什么都做不了，能力还在路上。你现在能做的，是先准备好一个大脑，等能力上线时就不用再等下载了。';

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
    return '$name 仍在下载：设置 › 伙伴';
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
  String get screenShareDrawBoardIdle => '涂画会显示在这里';

  @override
  String get screenShareOverlayHint => '共享时在其他应用上方显示涂画';

  @override
  String get screenShareOverlayAllow => '允许';

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
  String get screenSharePickerEmpty => '暂时没有可共享的内容，请在系统设置中允许屏幕录制后重试';

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
  String get settingsScreenFriendActivityOffBody => '没有通知，你去看时他们的板子还在';

  @override
  String get searchScreenActionWithGrownUp => '等大人确认';

  @override
  String get newChatMenuSearchHint => '搜索你的好友';

  @override
  String get newChatMenuNoFriendsYet => '还没有好友，去发现页找找人';

  @override
  String get newChatMenuNoFriendsMatch => '没有匹配的好友';

  @override
  String get newChatMenuOpenDmFailed => '打不开那个聊天，请重试';

  @override
  String get childPolicyScreenAddSomeoneLabel => '从你的联系人里挑';

  @override
  String get childPolicyScreenPickPersonHint => '搜索名字或用户名';

  @override
  String get childPolicyScreenPickPersonEmpty => '好友里没有可添加的人了，\\n可以搜索其他人';

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
  String get childPolicyScreenErrorAddRoomGeneric => '添加那个房间失败，请重试';

  @override
  String get childPolicyScreenErrorRoomNotAllowed => '那个房间不能这样添加';

  @override
  String get childPolicyScreenErrorRoomGone => '那个房间已经不存在了';

  @override
  String get newChatMenuFriendsHeader => '好友';

  @override
  String get roomChangeErrorGone => '这条建议已经没了，可能有管理员处理过了。';

  @override
  String get roomChangeErrorNotYours => '只有提出的人才能收回。';

  @override
  String get roomChangeErrorNoChange => '现在就是这样写的。';

  @override
  String get roomChangeErrorMissingValue => '这样没法保存。';

  @override
  String get roomChangeRequestsTitle => '建议';

  @override
  String get roomChangeRequestsBlurb => '这些是成员提的。你同意之前什么都不会变。';

  @override
  String get roomChangeRequestsEmpty => '没有建议。';

  @override
  String get roomChangeRequestsApprove => '采用';

  @override
  String get roomChangeRequestsReject => '不用';

  @override
  String get roomChangeRequestsPhotoLabel => '新的群组照片';

  @override
  String get roomChangeRequestsNameLabel => '新名字';

  @override
  String get roomChangeRequestsDescriptionLabel => '新简介';

  @override
  String get roomChangeRequestsUnknownLabel => '这个版本还显示不了的改动';

  @override
  String get roomChangeRequestsClearedValue => '留空（删掉）';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name 提的';
  }

  @override
  String get roomAdminChangeRequestsRow => '建议';

  @override
  String get roomInfoScreenSuggestNote => '这个要管理员同意';

  @override
  String get roomInfoScreenSuggestAvatarNote => '新照片由管理员批准';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic => '建议一张群组照片';

  @override
  String get roomInfoScreenSuggestionSentToast => '已发给管理员';

  @override
  String get roomInfoScreenSuggestionAppliedToast => '好了，这个群你可以直接改';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => '已收回';

  @override
  String get roomInfoScreenSuggestionsLabel => '你提的建议';

  @override
  String get roomInfoScreenSuggestionPhoto => '一张新的群组照片';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return '名字：$value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return '简介：$value';
  }

  @override
  String get roomInfoScreenSuggestionOther => '一处改动';

  @override
  String get roomInfoScreenSuggestionPending => '等管理员';

  @override
  String get roomInfoScreenSuggestionWithdraw => '收回';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name 提议换一张新的群组照片';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name 提议换一个新名称';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name 提议换一段新的描述';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '有 $count 条建议等你处理',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => '查看';

  @override
  String get roomSuggestionBannerSemantic => '等你审核的成员建议';

  @override
  String get gameInfoPlay => '开始玩';

  @override
  String get gameInfoContinue => '继续玩';

  @override
  String get gameInfoSeeResult => '查看你的结果';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return '已送达 $total 人中的 $delivered 人';
  }

  @override
  String get messageReceiptsSentLabel => '已发送';

  @override
  String messageReceiptsSemanticDeliveredThenRead(
    Object deliveredDay,
    Object deliveredTime,
    Object name,
    Object readDay,
    Object readTime,
  ) {
    return '$name 于 $deliveredDay $deliveredTime 收到，$readDay $readTime 已读';
  }

  @override
  String get messageReceiptsStampRead => '已读';

  @override
  String get messageReceiptsStampDelivered => '已送达';

  @override
  String get roomInviteCustom => '自定义';

  @override
  String roomInviteCustomHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 次',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => '小时';

  @override
  String get roomInviteUnitDays => '天';

  @override
  String get roomInviteStepperIncrease => '增加';

  @override
  String get roomInviteStepperDecrease => '减少';

  @override
  String get recordsLabel => '历史纪录';

  @override
  String get recordsBlurb => '有史以来最好的成绩：你和你的朋友';

  @override
  String recordsYourBest(Object value) {
    return '你的 $value';
  }

  @override
  String get recordsNoneYet => '暂无';

  @override
  String get recordsEmpty => '完成任意一个游戏，你的最佳成绩就会出现在这里。';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '完成 $count 次',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return '$date 创下';
  }

  @override
  String recordsReactSemantic(Object name) {
    return '回应 $name 的纪录';
  }

  @override
  String get recordsReactFailed => '无法回应';

  @override
  String get recordsLoadFailed => '无法加载纪录';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game：$name 的纪录 $value';
  }

  @override
  String get appearanceLabel => '外观';

  @override
  String get appearanceMatchDevice => '跟随设备';

  @override
  String get appearanceMatchDeviceSub => '白天浅色，夜晚深色，跟着你的手机';

  @override
  String get appearanceOneTheme => '固定主题';

  @override
  String get appearanceOneThemeSub => '全天同一个样子';

  @override
  String get appearanceLightSlot => '浅色模式';

  @override
  String get appearanceDarkSlot => '深色模式';

  @override
  String get appearanceNow => '当前';

  @override
  String appearanceAutoValue(Object name) {
    return '自动 · $name';
  }

  @override
  String get themeScreenAssignHint => '点按主题用于浅色或深色模式 · ⛶ 全屏预览';

  @override
  String get themeScreenCarouselUseLight => '用于浅色模式';

  @override
  String get themeScreenCarouselUseDark => '用于深色模式';

  @override
  String get themeScreenCarouselIsLight => '你的浅色主题';

  @override
  String get themeScreenCarouselIsDark => '你的深色主题';

  @override
  String get onboardingThemeTitle => '由你定义。';

  @override
  String get onboardingThemeBody => '选一个风格。随时可以在设置里更改。';

  @override
  String get onboardingThemeYourTheme => '你的主题';

  @override
  String get onboardingThemeContinue => '继续';

  @override
  String get dropHintNoTarget => '拖放到聊天上即可发送';

  @override
  String get dropNothingToSend => '这里没有可以发送的内容';

  @override
  String dropSendPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发送 $count 张照片',
    );
    return '$_temp0';
  }

  @override
  String dropSendVideos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发送 $count 个视频',
    );
    return '$_temp0';
  }

  @override
  String dropSendAudio(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发送 $count 个音频',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发送 $count 个文件',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发送 $count 项',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => '添加到消息';

  @override
  String get dropSendLink => '添加链接';

  @override
  String dropTargetTo(String name) {
    return '发给 $name';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件超过 $size',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => '无法发送文件夹';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已跳过 $count 个空文件',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => '此处不允许发送附件';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项将作为文件发送',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项可能无法在所有设备上预览',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => '照片';

  @override
  String get dropKindVideo => '视频';

  @override
  String get dropKindAudio => '音频';

  @override
  String get dropKindFile => '文件';

  @override
  String get dropKindFolder => '文件夹';

  @override
  String get dropKindText => '文本';

  @override
  String get dropKindLink => '链接';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件未能放进这次发送',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed => '操作失败，请重试。';

  @override
  String get expressionBackspace => '删除';

  @override
  String get expressionCreateSticker => '制作贴纸';

  @override
  String get expressionDeleteSticker => '从我的贴纸中删除';

  @override
  String get expressionFavorite => '添加到收藏';

  @override
  String get expressionFavorited => '已添加到收藏';

  @override
  String get expressionFavorites => '收藏';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF：$title';
  }

  @override
  String get expressionLoadFailed => '加载失败，请检查网络连接。';

  @override
  String get expressionMediaNotAllowed => '你的家庭设置不允许发送图片。';

  @override
  String get expressionMyStickers => '我的贴纸';

  @override
  String get expressionNoFavorites => '长按 GIF 或贴纸即可添加到收藏。';

  @override
  String get expressionNoRecents => '你发送的 GIF 和贴纸会显示在这里。';

  @override
  String get expressionNoResults => '无结果';

  @override
  String get expressionNoStickers => '这里还没有贴纸。';

  @override
  String get expressionOpenPanel => '表情、GIF 和贴纸';

  @override
  String get expressionOptionsHint => '显示选项';

  @override
  String expressionPackCredit(String author, String license) {
    return '作者：$author · $license';
  }

  @override
  String get expressionPlayGifHint => '播放';

  @override
  String get expressionRecent => '最近';

  @override
  String get expressionReport => '举报';

  @override
  String get expressionReported => '谢谢，已举报。';

  @override
  String get expressionRetry => '重试';

  @override
  String get expressionSearchKlipy => '搜索 KLIPY';

  @override
  String get expressionShowKeyboard => '显示键盘';

  @override
  String get expressionSuggestionsLabel => '贴纸推荐';

  @override
  String get expressionTabEmoji => '表情';

  @override
  String get expressionTabGifs => 'GIF';

  @override
  String get expressionTabStickers => '贴纸';

  @override
  String get expressionTrending => '热门';

  @override
  String get expressionUnfavorite => '取消收藏';

  @override
  String get expressionUnfavorited => '已取消收藏';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return '贴纸 $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel => '自动播放 GIF 和贴纸';

  @override
  String get settingsAutoplayExpressionsOffBody => '点击前保持静止，更省流量。';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'GIF 和动态贴纸会自动播放。开启“减弱动态效果”时会暂停。';

  @override
  String get settingsAlbumCardsLabel => '照片相册以卡片显示';

  @override
  String get settingsAlbumCardsOffBody => '一条消息中的多张照片以网格排列。';

  @override
  String get settingsAlbumCardsOnBody => '一条消息中的多张照片以卡片叠放显示，滑动即可翻看。';

  @override
  String get settingsStickerSuggestionsBody => '只输入一个表情时，会在输入框上方显示匹配的贴纸。';

  @override
  String get settingsStickerSuggestionsLabel => '贴纸推荐';

  @override
  String get stickerMakerEmojiLabel => '是哪个表情？';

  @override
  String get stickerMakerFailed => '贴纸保存失败，请重试。';

  @override
  String get stickerMakerMoreEmoji => '更多表情';

  @override
  String get stickerMakerPreview => '贴纸预览';

  @override
  String get stickerMakerRemoveBackground => '去除背景';

  @override
  String get stickerMakerSave => '保存';

  @override
  String get stickerMakerSaved => '贴纸已添加到“我的贴纸”';

  @override
  String get stickerMakerShape => '形状';

  @override
  String get stickerMakerShapeCircle => '圆形';

  @override
  String get stickerMakerShapeOriginal => '原图';

  @override
  String get stickerMakerShapeRounded => '圆角方形';

  @override
  String get stickerMakerTitle => '新贴纸';

  @override
  String get stickerMakerTooMany => '贴纸数量已达上限。删除一个以腾出空间。';

  @override
  String get expressionExpandPanel => '展开面板';

  @override
  String get expressionCollapsePanel => '收起面板';

  @override
  String get expressionPackStore => '贴纸包';

  @override
  String get expressionPackSearchHint => '搜索贴纸包';

  @override
  String get expressionPacksAdded => '已添加';

  @override
  String get expressionPacksMore => '更多贴纸包';

  @override
  String get expressionPackAdd => '添加';

  @override
  String get expressionPackRemove => '移除';

  @override
  String expressionPackStickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个贴纸',
    );
    return '$_temp0';
  }

  @override
  String get expressionNoPacksFound => '没有匹配的贴纸包';

  @override
  String get expressionAllPacksAdded => '你已添加所有贴纸包。';

  @override
  String expressionPackReorder(String title) {
    return '重新排序 $title';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return '添加“$title”贴纸包';
  }

  @override
  String expressionPackAddedToast(String title) {
    return '已将“$title”添加到你的贴纸';
  }

  @override
  String get expressionPacksFromKlipy => '更多来自 KLIPY 的贴纸';

  @override
  String expressionSearchKlipyFor(String query) {
    return '在 KLIPY 上搜索“$query”';
  }

  @override
  String get expressionHideKeyboard => '隐藏键盘';

  @override
  String get expressionSearchStickers => '搜索贴纸';

  @override
  String get expressionYourStickers => '你的贴纸';

  @override
  String get chatListYesterday => '昨天';

  @override
  String get roomLayoutScreenCardsLayoutLabel => '卡片';

  @override
  String get roomLayoutScreenCardsLayoutDescription => '每个房间一张卡片，所有细节一目了然。';

  @override
  String get homeScreenTitle => '聊天';

  @override
  String get glassScreenNativeLabel => 'iOS 液态玻璃';

  @override
  String get glassScreenNativeOnBody => '标签栏由 iOS 自身绘制。下方的滑块调整应用的其余部分。';

  @override
  String get glassScreenNativeOffBody => 'MonkeyHub 在所有地方绘制自己的玻璃效果，可用下方滑块调整。';

  @override
  String get glassScreenHeading => '玻璃';

  @override
  String get glassStyleHeader => '样式';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody => '由 iOS 绘制的 Apple 原生玻璃，应用中的按钮也与之一致。';

  @override
  String get glassStyleFrostedTitle => '磨砂';

  @override
  String get glassStyleFrostedBody => 'MonkeyHub 自己的玻璃效果，每个参数都可自行调整。';

  @override
  String get glassStyleRecommended => '推荐';

  @override
  String get glassStyleLiquidFooter => '无需调整：模糊、色调和光线由 iOS 决定。选择“磨砂”即可自行调整。';

  @override
  String get acctSectionPrivacy => '隐私';

  @override
  String get acctSectionAccount => '账户';

  @override
  String get acctSectionFamily => '家庭';

  @override
  String get acctSectionThisPhone => '这部手机';

  @override
  String get acctRowVisibility => '个人资料可见性';

  @override
  String get acctRowBlocked => '已屏蔽的用户';

  @override
  String get acctRowApprovals => '审批';

  @override
  String get acctNothingWaiting => '无待处理';

  @override
  String get acctRowLinked => '关联账户';

  @override
  String get acctRowScanToSignIn => '扫码登录';

  @override
  String get acctRowSetUpRecovery => '设置恢复短语';

  @override
  String get acctRowChangeRecovery => '更改恢复短语';

  @override
  String get acctSignOut => '退出登录';

  @override
  String get acctDeleteAccount => '删除账户';

  @override
  String get acctConfirmDelete => '再次轻点以删除';

  @override
  String get acctHandPhoneBack => '交还这部手机';

  @override
  String get acctMyGrownUps => '我的监护人';

  @override
  String get acctActionMessage => '发消息';

  @override
  String get acctActionAddFriend => '添加';

  @override
  String get acctActionRequested => '已申请';

  @override
  String get acctActionAccept => '接受';

  @override
  String get acctActionNotAccepting => '未开放';

  @override
  String get acctActionUnfriend => '删好友';

  @override
  String get acctActionBlock => '屏蔽';

  @override
  String get acctActionReport => '举报';

  @override
  String get acctStatusFriends => '你们是好友';

  @override
  String get acctStatusRequestSent => '已发送请求';

  @override
  String get acctStatusWantsToConnect => '想加你为好友';

  @override
  String get acctStatusNotConnected => '尚未建立联系';

  @override
  String get acctPresenceOnline => '在线';

  @override
  String get acctPresenceAway => '离开';

  @override
  String get acctPresenceOffline => '离线';

  @override
  String get acctProfilePhoto => '头像';

  @override
  String get acctSaveToPhotos => '存储到照片';

  @override
  String get acctTakeSelfie => '自拍';

  @override
  String get acctChooseFromLibrary => '从图库选取';

  @override
  String get acctCancel => '取消';

  @override
  String get acctSave => '保存';

  @override
  String get acctChange => '更改';

  @override
  String get acctNotNow => '暂不';

  @override
  String get acctAddEmail => '添加邮箱';

  @override
  String get acctEditNameTitle => '编辑名字';

  @override
  String get acctAddNameTitle => '添加名字';

  @override
  String get acctEditEmailTitle => '编辑邮箱';

  @override
  String get acctChangeUsernameTitle => '更改用户名？';

  @override
  String get onboardingLookTitle => '打造你的专属风格';

  @override
  String get onboardingLookBody => '选一个外观。随时可以在设置中更改。';

  @override
  String get onboardingEssentials => '基础';

  @override
  String get onboardingEssentialsSub => '简洁原生';

  @override
  String get onboardingCharacters => '个性';

  @override
  String get onboardingCharactersSub => '同一个应用，更多个性';

  @override
  String get onboardingLightMode => '浅色模式';

  @override
  String get onboardingDarkMode => '深色模式';

  @override
  String get onboardingNow => '当前';

  @override
  String get onboardingContinue => '继续';

  @override
  String get onboardingIconTitle => '你的应用图标';

  @override
  String get onboardingIconBody => '保留当前图标、让它跟随主题，或任选一个。';

  @override
  String get onboardingIconIosNote => '每次更换图标时，iOS 都会显示一条简短提示。';

  @override
  String get onboardingGetStarted => '开始使用';

  @override
  String get appIconMatchTheme => '跟随主题';

  @override
  String get appIconCurrent => '当前';

  @override
  String get appIconSectionCollection => 'MonkeyHub 系列';

  @override
  String get appIconSectionThemes => '主题图标';

  @override
  String get appIconScreenTitle => '应用图标';

  @override
  String get appIconMatchFooter => '“跟随主题”会随深色模式主题更换图标，白天不会来回切换。';

  @override
  String get loginTitleReturning => '欢迎回来';

  @override
  String get loginTitleFirst => '欢迎来到 MonkeyHub';

  @override
  String get loginTitleSignUp => '创建你的账户';

  @override
  String get loginTitleReset => '重置密码';

  @override
  String get loginSubtitleSignIn => '登录，从上次离开的地方继续。';

  @override
  String get loginSubtitleFirst => '登录，或几秒钟创建一个账户。';

  @override
  String get loginSubtitleSignUp => '只需一个用户名和密码。';

  @override
  String get loginSubtitleReset => '输入你的 12 个单词恢复短语，并设置新密码。';

  @override
  String get loginCtaSignIn => '登录';

  @override
  String get loginCtaSignUp => '创建账户';

  @override
  String get loginCtaReset => '重置密码';

  @override
  String get loginNoAccountPrompt => '新用户？';

  @override
  String get loginCreateAccountLink => '创建账户';

  @override
  String get loginHaveAccountPrompt => '已有账户？';

  @override
  String get loginSignInLink => '登录';

  @override
  String get loginForgotPassword => '忘记密码？';

  @override
  String get loginChildAccount => '设置儿童账户';

  @override
  String get loginBackToSignIn => '返回登录';

  @override
  String get loginWithPhone => '用手机登录';

  @override
  String get loginUsernameField => '用户名';

  @override
  String get loginPasswordField => '密码';

  @override
  String get loginConfirmPasswordField => '确认密码';

  @override
  String get loginNameField => '姓名（可选）';

  @override
  String get loginRecoveryPhraseField => '你的 12 个单词恢复短语';

  @override
  String get loginNewPasswordField => '新密码';

  @override
  String get roomHeaderStatusOnline => '在线';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位成员',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => '设置';

  @override
  String get settingsHubAccountHintAdult => '个人资料、家庭、关联账户和隐私';

  @override
  String get settingsHubAccountHintChild => '个人资料、隐私和你的监护人';

  @override
  String get settingsHubSectionGeneral => '通用';

  @override
  String get settingsHubSectionNotifications => '通知';

  @override
  String get settingsHubSectionCalls => '通话';

  @override
  String get settingsHubSectionAppearance => '外观';

  @override
  String get settingsHubSectionCompanions => '伙伴';

  @override
  String get settingsHubSectionChats => '聊天';

  @override
  String get settingsHubSectionHelp => '帮助与法律';

  @override
  String get settingsHubSectionAdvanced => '高级';

  @override
  String get settingsHubLanguage => '语言';

  @override
  String get settingsHubCheckForUpdates => '检查更新';

  @override
  String get settingsHubUpdateAvailable => '有可用更新';

  @override
  String get settingsHubShowLinkUrls => '显示链接地址';

  @override
  String get settingsHubShowLinkUrlsSubtitle => '在每个链接预览旁显示地址';

  @override
  String get settingsHubPresenceDots => '显示谁在线';

  @override
  String get settingsHubPresenceDotsSubtitle => '头像上的圆点';

  @override
  String get settingsHubPush => '推送通知';

  @override
  String get settingsHubPushSubtitle => '新消息、通话和请求';

  @override
  String get settingsHubGameReminders => '每日游戏提醒';

  @override
  String get settingsHubGameRemindersSubtitle => '如果还没玩，午饭时提醒一次';

  @override
  String get settingsHubFriendActivity => '好友动态';

  @override
  String get settingsHubFriendActivitySubtitle => '好友的精彩瞬间、积分和游戏结果';

  @override
  String get settingsHubMenuBar => '菜单栏图标';

  @override
  String get settingsHubMenuBarSubtitle => '在菜单栏显示未读数';

  @override
  String get settingsHubCallStats => '显示通话统计';

  @override
  String get settingsHubCallStatsSubtitle => '通话中的分辨率、码率和延迟';

  @override
  String get settingsHubTheme => '主题';

  @override
  String get settingsHubAppIcon => 'App 图标';

  @override
  String get settingsHubGlass => '玻璃';

  @override
  String get settingsHubNavigation => '导航';

  @override
  String get settingsHubMotion => '动效';

  @override
  String get settingsHubChatList => '聊天列表';

  @override
  String get settingsHubChatStyle => '聊天样式';

  @override
  String get settingsHubBubbleStyle => '气泡样式';

  @override
  String get settingsHubSpeakerColors => '发言人颜色';

  @override
  String get settingsHubReplyStyle => '回复样式';

  @override
  String get settingsHubPrivacyPolicy => '隐私政策';

  @override
  String get settingsHubTerms => '服务条款';

  @override
  String get settingsHubLicence => '许可协议';

  @override
  String get settingsHubServer => '服务器';

  @override
  String get settingsHubLayoutRows => '列表';

  @override
  String get settingsHubLayoutCards => '卡片';

  @override
  String get settingsHubLayoutGrid => '网格';

  @override
  String get settingsHubNavTabBar => '标签栏';

  @override
  String settingsHubThemeAuto(String name) {
    return '自动 · $name';
  }

  @override
  String get chatListPageRowsSub => '头像、名字和最新消息，就像“信息”一样。';

  @override
  String get chatListPageCardsSub => '每个房间一张卡片，所有细节一目了然。';

  @override
  String get chatListPageGridSub => '两列方块，一眼看到更多房间。';

  @override
  String get chatListPageLayoutHeader => '布局';

  @override
  String get chatListPageFiltersHeader => '筛选';

  @override
  String get chatListPageChips => '标签';

  @override
  String get chatListPageChipsSub => '一排筛选，随时一点即达。';

  @override
  String get chatListPageButton => '按钮';

  @override
  String get chatListPageButtonSub => '一个按钮，需要时再打开筛选。';

  @override
  String get chatListPageEmptyHeader => '空房间';

  @override
  String get chatListPagePlain => '简洁';

  @override
  String get chatListPagePlainSub => '还没人说话的房间保持空白。';

  @override
  String get chatListPageInitial => '首字母';

  @override
  String get chatListPageInitialSub => '一个淡淡的大字母填满空白角落。';

  @override
  String get chatListPageEmptyFooter => '适用于网格布局。';

  @override
  String get chatStylePageFooter => '会话标题栏和输入框的显示方式。';

  @override
  String get chatStyleClassicSub => '实心标题栏和扁平输入框。';

  @override
  String get chatStyleCompactSub => '磨砂控件悬浮在对话之上。';

  @override
  String get bubbleTailedSub => '每组最后一条消息带尾巴，就像“信息”。';

  @override
  String get bubbleSoftSub => '无尾巴，用圆角把连续消息连成一组。';

  @override
  String get bubblePillSub => '每条消息都是圆润的胶囊。';

  @override
  String get bubbleSlabSub => '方正的边角：利落而坚定。';

  @override
  String get replyStylePageFooter => '回复如何显示它所回复的消息。';

  @override
  String get replyClassicSub => '消息上方的彩色引用，WhatsApp 风格。';

  @override
  String get replyPhantomSub => '原消息的虚影浮在上方，以曲线相连。';

  @override
  String get replyStickySub => '别在角落的小小斜卡片。';

  @override
  String get replyComicSub => '带漫画尾巴的小气泡。';

  @override
  String get motionMatchDevice => '跟随设备';

  @override
  String get motionMatchDeviceCalmSub => '你的设备目前要求减弱动态效果。';

  @override
  String get motionMatchDeviceFullSub => '你的设备目前允许动画。';

  @override
  String get motionFullSub => '每一次回弹、漂移和点缀。';

  @override
  String get motionCalmSub => '装饰保持静止，其余一切照常。';

  @override
  String get navigationPageFooter => '在聊天、动态、发现和设置之间切换的方式。';

  @override
  String get navTabBarSub => '始终可见，一点即达任意位置。';

  @override
  String get navOrbSub => '从角落按住拖动，越用越顺手的手势。';

  @override
  String get languageSystemLabel => '设备语言';

  @override
  String get languagePageFooter => '菜单和应用提示。聊天内容保持对方书写的语言。';

  @override
  String get speakerPageFooter => '在群聊里一眼看出谁在说话。';

  @override
  String get speakerOffSub => '大家用同一种颜色书写。';

  @override
  String get speakerNamesSub => '每个人的名字和头像都有自己的颜色。';

  @override
  String get speakerBubblesSub => '颜色也会延续到他们的消息里。';

  @override
  String get themePageAutoFooter => '浅色主题用于浅色模式，深色主题用于深色模式。';

  @override
  String get themePageLightMode => '浅色模式';

  @override
  String get themePageDarkMode => '深色模式';

  @override
  String get themePageEssentials => '基础';

  @override
  String get themePageEssentialsFooter => '沉静原生，五种配色。';

  @override
  String get themePageCharacters => '个性';

  @override
  String get themePageCharactersFooter => '布局不变，个性十足。长按任一主题即可预览。';

  @override
  String get themePageLightBadge => '浅色';

  @override
  String get themePageDarkBadge => '深色';

  @override
  String get themePageInUse => '使用中';

  @override
  String get themePageUseLight => '用于浅色模式';

  @override
  String get themePageUseDark => '用于深色模式';

  @override
  String themePageUse(String name) {
    return '使用 $name';
  }

  @override
  String get acctActionPending => '待审核';

  @override
  String get chatSwipePin => '置顶';

  @override
  String get chatSwipeUnpin => '取消置顶';

  @override
  String get chatSwipeMute => '免打扰';

  @override
  String get chatSwipeUnmute => '取消免打扰';

  @override
  String get chatSwipeArchive => '归档';

  @override
  String get appearanceMatchDeviceSubtitle => '跟随手机，白天浅色、夜晚深色';

  @override
  String get appearanceOneThemeSubtitle => '全天同一外观';

  @override
  String get riName => '名称';

  @override
  String get riDescription => '简介';

  @override
  String get riVisibility => '谁能找到它';

  @override
  String get riPublic => '公开';

  @override
  String get riPublicSub => '任何人都能在发现中找到';

  @override
  String get riPrivate => '私密';

  @override
  String get riPrivateSub => '只有你邀请的人能加入';

  @override
  String get riMessageLife => '消息消失时间';

  @override
  String get riPassword => '密码';

  @override
  String get riRemovePassword => '移除密码';

  @override
  String get riSetPassword => '设置密码';

  @override
  String get riSharedContent => '共享内容';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位成员',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已邀请 $count 人',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => '撤回';

  @override
  String get riNotifications => '通知';

  @override
  String get riTranslation => '翻译';

  @override
  String get riNameColours => '名字颜色';

  @override
  String get riYouSuggested => '你的建议';

  @override
  String get riTakeBack => '撤回';

  @override
  String get riLeaveRoom => '退出房间';

  @override
  String get riLeaving => '正在退出…';

  @override
  String get riDeleteRoom => '删除房间';

  @override
  String get riDeleting => '正在删除…';

  @override
  String get riEndConversation => '结束对话';

  @override
  String get riEnding => '正在结束…';

  @override
  String get riActionCall => '通话';

  @override
  String get riActionVideo => '视频';

  @override
  String get riActionMute => '静音';

  @override
  String get riActionUnmute => '取消静音';

  @override
  String get riActionMedia => '媒体';

  @override
  String get riActionAdd => '添加';

  @override
  String get roomHeaderStatusTyping => '正在输入…';

  @override
  String get glassScreenLead => '背后内容透出的程度。';

  @override
  String get transcriptDayToday => '今天';

  @override
  String get acctRowDevices => '设备';

  @override
  String get acctThisDevice => '本机';

  @override
  String get acctRemove => '移除';

  @override
  String get acctRemoveDeviceTitle => '移除此设备？';

  @override
  String get acctRemoveAllTitle => '移除所有其他设备？';

  @override
  String get acctRemoveAll => '全部移除';

  @override
  String get acctActiveNow => '当前活跃';

  @override
  String get acctLoading => '加载中…';

  @override
  String get acctDevicesLoadFailed => '无法加载你的设备。';

  @override
  String get acctNoNotifications => '通知无法送达此设备';

  @override
  String get acctBlockedEmpty => '你还没有屏蔽任何人。';

  @override
  String get acctUnblock => '取消屏蔽';

  @override
  String get pvSubtitle => '控制别人能看到什么，以及如何联系你。';

  @override
  String get pvSectionProfile => '个人资料';

  @override
  String get pvSectionMessages => '消息';

  @override
  String get pvSectionPeople => '联系人';

  @override
  String get pvSectionFeed => '动态';

  @override
  String get pvAvatar => '头像';

  @override
  String get pvAvatarDesc => '谁能看到你的头像';

  @override
  String get pvOnline => '在线状态';

  @override
  String get pvOnlineDesc => '你现在是否显示为活跃';

  @override
  String get pvLastSeen => '最近上线';

  @override
  String get pvLastSeenDesc => '你上次出现的时间';

  @override
  String get pvSendReceipts => '发送已读回执';

  @override
  String get pvSendReceiptsDesc => '让别人看到你已读他们的消息';

  @override
  String get pvShowReceipts => '显示已读回执';

  @override
  String get pvShowReceiptsDesc => '查看谁读了你的消息';

  @override
  String get pvShowReceiptsHint => '只统计发送已读回执的人。';

  @override
  String get pvFriendRequests => '好友请求';

  @override
  String get pvFriendRequestsDesc => '谁能向你发送好友请求';

  @override
  String get pvSupervisedTitle => '这些由你的监护人设置';

  @override
  String get pvEveryone => '所有人';

  @override
  String get pvFriends => '好友';

  @override
  String get pvNobody => '没有人';

  @override
  String get pvOn => '开';

  @override
  String get pvOff => '关';

  @override
  String get pvAnyone => '任何人';

  @override
  String get pvHighlights => '我的精彩';

  @override
  String get pvHighlightsDesc => '你的照片和视频是否在当天显示在好友的看板上';

  @override
  String get pvPuzzle => '我的谜题成绩';

  @override
  String get pvPuzzleDesc => '好友能否看到你每日谜题的成绩';

  @override
  String get pvPast => '我的过往';

  @override
  String get pvPastDesc => '今天的内容始终与好友共享，此项会开放之前的全部记录';

  @override
  String get pvPoints => '我的积分';

  @override
  String get pvPointsDesc => '你记录的积分是否显示在好友的看板上';

  @override
  String get roomColorsPageTitle => '谁是谁';

  @override
  String get roomColorsPageHeader => '每个人说话的颜色';

  @override
  String get roomColorsAuto => '自动';

  @override
  String get roomColorsReset => '恢复自动';

  @override
  String get roomColorsOffFooter => '发言人颜色已关闭。在此开启会在所有房间开启。';

  @override
  String roomColorsSharedWith(String name) {
    return '与 $name 相同';
  }

  @override
  String get settingsScreenValueReplyQuote => '引用';

  @override
  String get replyQuoteSub => '原消息显示在回复气泡内的顶部。';

  @override
  String get riTabMedia => '照片和视频';

  @override
  String get riTabFiles => '文件';

  @override
  String get riTabVoice => '语音消息';

  @override
  String get riTabLinks => '链接';

  @override
  String get riTabSaved => '已保存';

  @override
  String get riNone => '无';

  @override
  String get riSavedNote => '你保存的内容只有你能看到。置顶消息则相反，整个房间都能看到。';

  @override
  String get riOwnerNote => '奖章标示房间的创建者。';

  @override
  String get famPair => '配对';

  @override
  String get famRelease => '解除';

  @override
  String get famSettings => '设置';

  @override
  String get famAddChild => '添加孩子';

  @override
  String get famEmptyTitle => '还没有孩子';

  @override
  String get famOnlineNow => '在线';

  @override
  String get famNotPaired => '尚未配对';

  @override
  String get famJustNow => '刚刚';

  @override
  String get apprEmptyTitle => '没有待处理事项';

  @override
  String get apprEmptySub => '全部处理完了。';

  @override
  String get apprNotYet => '暂不';

  @override
  String get apprAllow => '允许';

  @override
  String get compGeneral => '通用';

  @override
  String get compStorage => '存储';

  @override
  String get compTranslateInto => '翻译成';

  @override
  String get compBrain => '大脑';

  @override
  String laUnlinkProvider(String provider) {
    return '取消关联 $provider';
  }

  @override
  String laLinkProvider(String provider) {
    return '关联 $provider';
  }

  @override
  String get laUnlink => '取消关联';

  @override
  String get laLink => '关联';

  @override
  String get laLinked => '已关联';

  @override
  String get laNotLinked => '未关联';

  @override
  String rdSignOut(String name) {
    return '让 $name 退出登录';
  }

  @override
  String get rpContinue => '继续';

  @override
  String get rpCopy => '复制';

  @override
  String get rpSaved => '我已保存';

  @override
  String get rpBack => '返回';

  @override
  String get rpKeep => '暂不，保留当前短语';

  @override
  String get childSetupHeadingIos => '这是谁？';

  @override
  String get childPairTitleIos => '你好！';

  @override
  String get childPairBackIos => '返回登录';

  @override
  String get gamesHubTitle => '排行榜';

  @override
  String get gamesHubSubtitle => '今天的赢家。每天都有新题目。';

  @override
  String get gameTellFriendsMessage => '他们会收到这条成绩的通知。只能发送一次。';

  @override
  String get deviceLoginScanTitleIos => '扫码登录';

  @override
  String get deviceLoginConfirmTitleIos => '要在此设备上登录吗？';

  @override
  String get socialHeroCreateIos => '马上就好';

  @override
  String get socialHeroLinkIos => '欢迎回来';

  @override
  String socialSignInLinkIos(String provider) {
    return '登录并关联 $provider';
  }

  @override
  String get serverTitleIos => '服务器';

  @override
  String get serverOnboardingTitleIos => '选择服务器';

  @override
  String get approvalGateAskIos => '询问';

  @override
  String get friendRequestDraftIntroOutgoingSentence => '写几句话吧,对方可以同意或拒绝。';

  @override
  String get requestDeclineIos => '拒绝';

  @override
  String get joinRequestAllowIos => '允许';

  @override
  String get changeRequestUseIos => '采用';

  @override
  String get settingsSearchHint => '搜索设置';

  @override
  String settingsSearchNoResults(String query) {
    return '没有“$query”的结果';
  }

  @override
  String get settingsSearchAccount => '账户';

  @override
  String get settingsHubDiagnostics => '诊断';

  @override
  String get settingsHubDiagnosticsSubtitle => '用于排查问题和报告错误的日志';

  @override
  String get settingsHubAdvancedFooter => '用于排查问题和自建服务器，日常无需使用。';

  @override
  String get settingsSearchKwLanguage => '语言, 翻译, 地区';

  @override
  String get settingsSearchKwUpdates => '更新, 版本, 新';

  @override
  String get settingsSearchKwLinks => '链接, 网址, 地址, 预览';

  @override
  String get settingsSearchKwPresence => '在线, 状态, 圆点, 活跃, 绿色';

  @override
  String get settingsSearchKwAutoplay => '动图, 动画, 自动播放';

  @override
  String get settingsSearchKwStickers => '贴纸, 表情, 建议';

  @override
  String get settingsSearchKwPush => '通知, 提醒, 声音';

  @override
  String get settingsSearchKwGames => '游戏, 提醒, 每日';

  @override
  String get settingsSearchKwFriends => '好友, 动态, 积分';

  @override
  String get settingsSearchKwVideo => '视频, 通话, 画质, 摄像头';

  @override
  String get settingsSearchKwStats => '统计, 网络, 延迟, 调试';

  @override
  String get settingsSearchKwTheme => '主题, 深色, 浅色, 颜色, 夜间';

  @override
  String get settingsSearchKwIcon => '应用图标, 标志, 主屏幕';

  @override
  String get settingsSearchKwGlass => '玻璃, 模糊, 磨砂, 透明';

  @override
  String get settingsSearchKwNavigation => '标签栏, 导航, 菜单';

  @override
  String get settingsSearchKwMotion => '动效, 动画, 减弱动态效果';

  @override
  String get settingsSearchKwCompanions => '人工智能, 助手, 翻译, 模型';

  @override
  String get settingsSearchKwChatList => '聊天列表, 行, 卡片, 网格';

  @override
  String get settingsSearchKwChatStyle => '聊天样式, 紧凑, 经典';

  @override
  String get settingsSearchKwBubbles => '气泡, 消息, 形状';

  @override
  String get settingsSearchKwSpeakers => '名字, 颜色, 群组';

  @override
  String get settingsSearchKwReply => '回复, 引用, 话题';

  @override
  String get settingsSearchKwReport => '错误, 问题, 反馈, 帮助';

  @override
  String get settingsSearchKwLegal => '隐私, 条款, 法律, 许可';

  @override
  String get settingsSearchKwServer => '服务器, 自建, 网址, 开发者';

  @override
  String get settingsSearchKwDiagnostics => '诊断, 日志, 调试, 开发者';

  @override
  String get settingsSearchKwPrivacy => '隐私, 可见性, 最后在线, 已读';

  @override
  String get settingsSearchKwBlocked => '已屏蔽, 屏蔽';

  @override
  String get settingsSearchKwDevices => '设备, 会话, 退出';

  @override
  String get settingsSearchKwLinked => '苹果, 谷歌, 登录';

  @override
  String get settingsSearchKwRecovery => '恢复短语, 密码, 备份';

  @override
  String get settingsSearchKwFamily => '家庭, 孩子, 家长, 审批';

  @override
  String get settingsSearchKwAccount => '账户, 退出, 删除, 邮箱';

  @override
  String get childPolicyScreenContactStateAllowedTalking => '正在聊天';

  @override
  String get childPolicyScreenContactStateTalking => '已批准';

  @override
  String get childPolicyScreenContactStateAllowedNotAdded => '尚未添加';

  @override
  String get profileScreenSignOutConfirmTitle => '要在此设备上退出登录吗？';

  @override
  String get profileScreenDeleteAccountConfirmTitle => '要删除你的账户吗？';

  @override
  String get profileScreenDeleteAccountConfirmBody =>
      '你的消息、照片、房间和好友都会被删除，用户名也会释放给其他人使用。';

  @override
  String get glassPresetNameFrosted => '磨砂';

  @override
  String get glassPresetNameClear => '透明';

  @override
  String settingsScreenDiagnosticsCountdown(int count) {
    return '还差 $count 次进入诊断…';
  }

  @override
  String pairingCodeTitlePair(String name) {
    return '配对 $name';
  }

  @override
  String pairingCodeTitleRelease(String name) {
    return '归还 $name';
  }

  @override
  String archivedChatsSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个聊天',
    );
    return '$_temp0';
  }

  @override
  String pinnedListSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条消息',
    );
    return '$_temp0';
  }

  @override
  String get voiceRecorderScreenTitle => '语音消息';

  @override
  String get chatTargetSearchHint => '搜索';

  @override
  String get marloweBrainTierSwiftDetail => '回答快，下载最小';

  @override
  String get marloweBrainTierBalancedDetail => '速度与深度兼顾';

  @override
  String get marloweBrainTierDeepDetail => '思考最深入，占用空间最大';

  @override
  String get reportFactDeviceId => '设备 ID';

  @override
  String get reportFactUserId => '用户 ID';

  @override
  String get reportFactUsername => '用户名';

  @override
  String get reportFactApp => '应用';

  @override
  String get reportFactDevice => '设备';

  @override
  String get reportFactSystem => '系统';

  @override
  String get reportFactDisplay => '显示屏';

  @override
  String get reportFactAppLanguage => '应用语言';

  @override
  String get reportFactSystemLocale => '系统区域';

  @override
  String get reportFactLog => '日志';

  @override
  String reportFactLogValue(int count) {
    return '已附加 $count 个事件';
  }

  @override
  String reportProblemScreenshotN(int n) {
    return '截图 $n';
  }

  @override
  String reportProblemRemoveScreenshot(int n) {
    return '移除截图 $n';
  }

  @override
  String get reportFactLanguageFromSystem => '跟随系统';

  @override
  String get reportFactLanguageChosen => '手动选择';

  @override
  String get pageSectionSeeAll => '查看全部';

  @override
  String get discoverScreenSeeAllFriendsSemanticLabel => '查看全部好友';

  @override
  String get discoverScreenSeeAllRoomsSemanticLabel => '查看你的全部房间';

  @override
  String groupCallScreenRingingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人响铃中',
    );
    return '$_temp0';
  }

  @override
  String photoChromeWhenToday(String time) {
    return '今天 $time';
  }

  @override
  String photoChromeWhenYesterday(String time) {
    return '昨天 $time';
  }

  @override
  String photoChromeWhenDate(String date, String time) {
    return '$date $time';
  }

  @override
  String get photoChromeSaved => '已保存';

  @override
  String get photoChromeSaveFailed => '无法保存';

  @override
  String get photoChromeShareFailed => '无法分享';

  @override
  String photoChromeForwarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已转发到 $count 个聊天',
    );
    return '$_temp0';
  }

  @override
  String get photoChromeForwardFailed => '无法转发';

  @override
  String get photoChromeDeleteFailed => '无法删除';

  @override
  String get photoChromeDeleteBody => '此操作会为聊天中的所有人删除,且无法撤销。';

  @override
  String get roomContentMonthThis => '本月';

  @override
  String get roomContentMonthLast => '上个月';

  @override
  String get leaderboardOverall => '今天';

  @override
  String get leaderboardFooter =>
      '今天每解出一题得 1 分。同分时，拿第一次数多的人排前面。仍然同分则并列名次，按名字排序。';

  @override
  String get leaderboardNotPlayed => '还没玩';

  @override
  String get leaderboardPlay => '开始';

  @override
  String get leaderboardEmptyTitle => '今天还没有成绩';

  @override
  String get leaderboardEmptyBody => '解出一道题，你就是榜上第一名。';

  @override
  String get pointComposerPickFirst => '先在上面选一个';

  @override
  String get momentStoryNext => '下一个';

  @override
  String get momentStoryPrevious => '上一个';

  @override
  String leaderboardSolved(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      solved,
      locale: localeName,
      other: '$total 题解出 $solved 题',
      zero: '还没解出',
    );
    return '$_temp0';
  }

  @override
  String leaderboardWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '赢了 $count 次',
    );
    return '$_temp0';
  }

  @override
  String leaderboardEmptyAction(String game) {
    return '玩$game';
  }

  @override
  String get diagCatApi => '服务器调用';

  @override
  String get diagCatConnection => '连接';

  @override
  String get diagCatDevice => '设备';

  @override
  String get diagCatError => '错误';

  @override
  String get diagCatFrame => '慢帧';

  @override
  String get diagCatLayout => '布局';

  @override
  String get diagCatLifecycle => '应用状态';

  @override
  String get diagCatLog => '日志';

  @override
  String get diagCatNav => '导航';

  @override
  String get diagCatNetwork => '网络';

  @override
  String get diagCatSubscription => '实时更新';

  @override
  String get diagSevTrace => '跟踪';

  @override
  String get diagSevDebug => '调试';

  @override
  String get diagSevInfo => '信息';

  @override
  String get diagSevWarning => '警告';

  @override
  String get diagSevError => '错误';

  @override
  String get diagAll => '全部';

  @override
  String get diagSearchHint => '搜索名称、详情、正文';

  @override
  String get diagSummaryCopied => '已复制摘要';

  @override
  String get diagShareLog => '分享日志';

  @override
  String get diagCopySummary => '复制摘要';

  @override
  String get diagDeleteAll => '全部删除';

  @override
  String get diagUndo => '撤销';

  @override
  String get diagDeleteLogTitle => '删除整个日志?';

  @override
  String get diagDeleteLogBody => '目前记录的所有事件以及上次运行的日志都会被删除。之后发生的事件照常记录。';

  @override
  String get diagDelete => '删除';

  @override
  String get diagLogDeleted => '日志已删除';

  @override
  String get diagFilter => '筛选';

  @override
  String get diagMore => '更多';

  @override
  String get diagLatest => '最新';

  @override
  String get diagJumpToLatest => '跳到最新';

  @override
  String get diagPaused => '已暂停';

  @override
  String get diagPreparingLog => '正在准备日志…';

  @override
  String get diagEmptyNothingTitle => '尚未记录任何内容';

  @override
  String get diagEmptyNothingHint => '使用一会儿应用,事件就会显示在这里。';

  @override
  String get diagEmptyHiddenTitle => '目前只有隐藏的事件';

  @override
  String get diagEmptyHiddenHint => '轻点上方变暗的标签即可查看,长按可把它放回“全部”。';

  @override
  String get diagEmptyNoMatchTitle => '没有匹配的事件';

  @override
  String get diagEmptyNoMatchHint => '轻点上方的“全部”即可清除筛选。';

  @override
  String get diagApply => '应用';

  @override
  String get diagMinSeverity => '最低严重级别';

  @override
  String get diagEverything => '全部';

  @override
  String get diagHiddenFromAllHeader => '在“全部”中隐藏';

  @override
  String get diagHiddenFromAllFooter => '在标签行中选中之前不会出现在“全部”里。长按那里的标签也能切换。';

  @override
  String get diagCollapseRepeats => '折叠重复项';

  @override
  String get diagCollapseRepeatsSubtitle => '把连续的相同事件合并为一行';

  @override
  String get diagResetFilter => '重置筛选';

  @override
  String get diagBodyTruncated => '记录时正文已截断';

  @override
  String get diagCopyEvent => '复制事件';

  @override
  String get diagEventCopied => '已复制事件';

  @override
  String diagHiddenFromAll(String category) {
    return '已在“全部”中隐藏$category';
  }

  @override
  String diagBackInAll(String category) {
    return '$category已回到“全部”';
  }

  @override
  String diagChipSemanticLabel(String category, int count) {
    return '$category,$count';
  }

  @override
  String diagChipHiddenSemanticLabel(String category, int count) {
    return '$category,$count,已在“全部”中隐藏';
  }

  @override
  String diagEventCount(int shown, int total) {
    return '$total 个事件中的 $shown 个';
  }

  @override
  String diagDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已丢弃 $count 个较早的事件，日志从中途开始',
    );
    return '$_temp0';
  }

  @override
  String diagRepeatSpan(int count, String seconds) {
    return '$seconds 秒内 ×$count';
  }

  @override
  String roomContentTabSemantic(String count, String label) {
    return '$label，$count 项';
  }

  @override
  String get mapAppsTitle => '地图';

  @override
  String get mapAppsChoose => '打开位置的应用';

  @override
  String get mapAppsRemember => '设为默认应用';

  @override
  String get mapAppsAskEveryTime => '每次询问';

  @override
  String get mapAppsBrowser => '浏览器';

  @override
  String get mapAppsSubtitle => '选择用于打开共享位置的应用。';

  @override
  String get mapAppsUnavailable => '默认地图应用不可用，请选择其他应用。';

  @override
  String get mapAppsNoInstalled => '未找到支持的地图应用，可以使用浏览器。';

  @override
  String get interactionAnswersSearch => '搜索用户或回答';

  @override
  String get interactionFilterEmpty => '没有符合此筛选条件的回答。';

  @override
  String get interactionRetry => '重试';

  @override
  String get cameraEditorScreenCaptionHint => '添加说明…';

  @override
  String get cameraEditorScreenCaptionViewOnceHint => '一次性查看的照片不能添加说明';

  @override
  String get cameraEditorScreenAddFromCameraSemanticLabel => '再拍一张';

  @override
  String cameraEditorScreenDiscardAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '要放弃这 $count 张照片吗？',
      one: '要放弃这张照片吗？',
    );
    return '$_temp0';
  }

  @override
  String get cameraEditorScreenDiscardAllBody => '你的编辑和说明将会丢失。';

  @override
  String get cameraEditorScreenDiscardAllConfirm => '放弃';

  @override
  String get galleryTrayRecentsTitle => '最近项目';

  @override
  String get galleryTrayBackToCameraLabel => '返回相机';

  @override
  String get galleryTrayAllPhotosLabel => '所有照片';

  @override
  String get galleryTrayHandleLabel => '最近的照片';

  @override
  String get galleryTrayAllowPrompt => '在这里查看最近的照片';

  @override
  String get galleryTrayAllowButton => '允许';

  @override
  String get galleryTrayDeniedPrompt => '照片访问权限已关闭';

  @override
  String get galleryTraySettingsButton => '设置';

  @override
  String get galleryTrayLimitedNote => '仅显示你已允许的照片';

  @override
  String get galleryTrayManageButton => '管理';

  @override
  String get galleryTrayEmpty => '还没有照片';

  @override
  String galleryTrayAddSelectedButton(int count) {
    return '添加 ($count)';
  }

  @override
  String get galleryTrayCancelSelectionLabel => '取消选择';

  @override
  String galleryTraySelectedTitle(int count) {
    return '已选择 $count 项';
  }

  @override
  String galleryTrayPhotoLabel(int index) {
    return '照片 $index';
  }

  @override
  String get reactionLimitTitle => '已达到回应上限';

  @override
  String reactionLimitMessageBody(int limit) {
    return '为了速度、为了清净，也为了让每个表情都能闪耀，每条消息最多只能添加 $limit 个回应。想换一个的话，先撤回一个吧。';
  }

  @override
  String reactionLimitHighlightBody(int limit) {
    return '精彩瞬间每人最多 $limit 个回应，让每一个都有分量。想添加新的最爱，先撤回一个吧。';
  }

  @override
  String get reactionLimitDismiss => '知道了';

  @override
  String get reactionPickerYoursLabel => '你的回应';

  @override
  String reactionPickerTakeBackSemantic(String emoji) {
    return '撤回你的 $emoji 回应';
  }

  @override
  String get momentCommentsTitle => '评论';

  @override
  String momentCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条评论',
      zero: '评论',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentsEmptyTitle => '还没有评论';

  @override
  String get momentCommentsEmptyBody => '用一句话、一张贴纸或一个 GIF 开启对话吧。';

  @override
  String get momentCommentHint => '添加评论…';

  @override
  String momentCommentReplyHint(String name) {
    return '回复 $name…';
  }

  @override
  String momentCommentReplyingTo(String name) {
    return '正在回复 $name';
  }

  @override
  String get momentCommentCancelReply => '取消回复';

  @override
  String get momentCommentReply => '回复';

  @override
  String momentCommentViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '查看 $count 条回复',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentHideReplies => '隐藏回复';

  @override
  String get momentCommentDelete => '删除评论';

  @override
  String get momentCommentDeleteConfirm => '删除这条评论？它的回复也会一并删除。';

  @override
  String get momentCommentDeleteConfirmButton => '删除';

  @override
  String get momentCommentSend => '发送';

  @override
  String get momentCommentExpressions => '贴纸和 GIF';

  @override
  String get momentCommentFailed => '评论发布失败，请重试。';

  @override
  String get momentCommentAuthorBadge => '作者';

  @override
  String get momentCommentLike => '赞';

  @override
  String get momentCommentStickerAlt => '贴纸';

  @override
  String get momentCommentGifAlt => 'GIF';

  @override
  String get momentCommentPosted => '评论已发布';

  @override
  String momentCommentsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '查看全部 $count 条评论',
    );
    return '$_temp0';
  }

  @override
  String momentReactorsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$name 和其他 $_temp0';
  }

  @override
  String get storageKindPhotos => '照片';

  @override
  String get storageKindVideos => '视频';

  @override
  String get storageKindVideoMessages => '视频留言';

  @override
  String get storageKindVoice => '语音消息';

  @override
  String get storageKindFiles => '文件';

  @override
  String get storageKindStickers => '贴纸和 GIF';

  @override
  String get storageKindChatHistory => '聊天记录';

  @override
  String get storageKindOther => '其他';

  @override
  String get dataUsageKindCalls => '通话';

  @override
  String get dataStorageTitle => '数据与存储';

  @override
  String get settingsSearchKwDataStorage =>
      '存储 缓存 内存 空间 清理 清除 下载 自动下载 流量 数据用量 蜂窝网络 移动数据 wifi 无线 保存到照片 相册 storage cache';

  @override
  String get storageUsageTitle => '存储用量';

  @override
  String get dataUsageTitle => '数据用量';

  @override
  String get dataStorageAutoDownloadHeader => '自动下载媒体';

  @override
  String get dataStorageUsingCellular => '使用蜂窝网络时';

  @override
  String get dataStorageUsingWifi => '使用 Wi-Fi 时';

  @override
  String get dataStorageNowTag => '当前';

  @override
  String get autoDownloadReset => '重置自动下载设置';

  @override
  String get autoDownloadResetTitle => '恢复默认的自动下载设置？';

  @override
  String get dataStorageSaveHeader => '存储到照片';

  @override
  String get dataStorageSaveFooter => '自动将这些聊天中的新照片和视频保存到你的照片图库。';

  @override
  String get dataStorageCallsHeader => '通话';

  @override
  String get dataStorageLessDataForCalls => '通话时节省流量';

  @override
  String get dataStorageCallsFooter => '在信号弱或按流量计费的网络上节省流量，音视频质量会略有降低。';

  @override
  String get dataStorageCallsNever => '永不';

  @override
  String get dataStorageCallsCellular => '蜂窝网络下';

  @override
  String get dataStorageCallsAlways => '始终';

  @override
  String get dataStorageOff => '关闭';

  @override
  String get dataStorageChatsPrivate => '私聊';

  @override
  String get dataStorageChatsGroups => '群聊';

  @override
  String get dataStorageChatsPublic => '公开房间';

  @override
  String get dataStorageNetCellular => '蜂窝网络';

  @override
  String get dataStorageNetWifi => 'Wi-Fi';

  @override
  String get autoDownloadMaster => '自动下载媒体';

  @override
  String get autoDownloadUsageHeader => '数据用量';

  @override
  String get autoDownloadPresetLow => '低';

  @override
  String get autoDownloadPresetMedium => '中';

  @override
  String get autoDownloadPresetHigh => '高';

  @override
  String get autoDownloadCustomFooter => '你已自定义这些设置。拖动滑块可切回预设。';

  @override
  String get autoDownloadTypesHeader => '媒体类型';

  @override
  String get autoDownloadVideosTitle => '视频和视频留言';

  @override
  String get autoDownloadVoiceFooter => '语音消息和贴纸很小，所以总是会自动下载。';

  @override
  String get autoDownloadAllChats => '所有聊天';

  @override
  String autoDownloadUpToIn(String size, String chats) {
    return '$chats，最大 $size';
  }

  @override
  String autoDownloadSummaryUpTo(String kind, String size) {
    return '$kind（最大 $size）';
  }

  @override
  String get autoDownloadSummaryVoiceOnly => '仅语音消息';

  @override
  String get autoDownloadInHeader => '自动下载范围';

  @override
  String get autoDownloadMaxSizeHeader => '最大文件大小';

  @override
  String autoDownloadMaxSizeVideoFooter(String size) {
    return '$size以内的视频会自动下载，更大的需轻点下载。';
  }

  @override
  String autoDownloadMaxSizeFileFooter(String size) {
    return '$size以内的文件会自动下载，更大的需轻点下载。';
  }

  @override
  String get autoDownloadGateLoad => '下载照片';

  @override
  String get saveToPhotosHeader => '自动保存';

  @override
  String get saveToPhotosFooter => '在这些聊天中收到的新照片和视频下载后会添加到你的照片图库。';

  @override
  String get saveToPhotosMaxVideoHeader => '最大视频大小';

  @override
  String get saveToPhotosNoAccess => '请在“设置”中允许访问照片图库以自动保存。';

  @override
  String get saveToPhotosPhotosAndVideos => '照片和视频';

  @override
  String get storageCalculating => '正在计算…';

  @override
  String storageShareOfFree(String percent) {
    return 'MonkeyHub 占用了你 $percent 的可用空间。';
  }

  @override
  String get storageEmpty => '当前没有缓存。';

  @override
  String storageClearAllButton(String size) {
    return '清除全部缓存 $size';
  }

  @override
  String storageClearSelectedButton(String size) {
    return '清除所选 $size';
  }

  @override
  String storageClearChatButton(String size) {
    return '清除缓存 $size';
  }

  @override
  String get storageClearFooter => '所有内容都保留在云端，需要时会重新下载。';

  @override
  String get storageClearAllTitle => '清除全部缓存？';

  @override
  String get storageClearSelectedTitle => '清除所选项目？';

  @override
  String get storageClearBody => '你的消息会保留。媒体在打开时会重新下载。';

  @override
  String storageClearConfirm(String size) {
    return '清除 $size';
  }

  @override
  String storageFreed(String size) {
    return '已释放 $size';
  }

  @override
  String storageCleanupTitle(String size) {
    return '释放 $size';
  }

  @override
  String get storageCleanupSubtitle => '一个月内未打开的媒体';

  @override
  String get storageCleanupAction => '清理';

  @override
  String get storageCleanupFooter => '只清除 30 天内无人查看的媒体。保存的消息永远不会被清除。';

  @override
  String get storageAutoRemoveHeader => '自动清除缓存媒体';

  @override
  String get storageAutoRemoveFooter =>
      '超过这段时间未打开的媒体会从此设备中移除以节省空间。它们仍保留在云端，保存的消息始终保留。';

  @override
  String get dataStorageKeepNever => '永不';

  @override
  String get dataStorageKeepMonth => '1 个月';

  @override
  String get dataStorageKeepWeek => '1 周';

  @override
  String get dataStorageKeepDay => '1 天';

  @override
  String get storageLimitHeader => '最大缓存大小';

  @override
  String get storageLimitFooter => '缓存超过此大小时，会先移除最久未打开的媒体。';

  @override
  String get dataStorageLimitNone => '无限制';

  @override
  String get storageTabChats => '聊天';

  @override
  String get storageTabMedia => '媒体';

  @override
  String get storageTabFiles => '文件';

  @override
  String get storageNoChats => '还没有任何聊天产生缓存。';

  @override
  String get storageNoMedia => '还没有缓存的照片或视频。';

  @override
  String get storageNoFiles => '还没有缓存的文件。';

  @override
  String get storageOpenPhoto => '打开照片';

  @override
  String get storageOpenVideo => '打开视频';

  @override
  String get storageSelect => '选择';

  @override
  String storageChatShare(String percent) {
    return '此聊天占用了 $percent 的缓存。';
  }

  @override
  String get storageChatUnknown => '已退出的聊天';

  @override
  String dataUsageSince(String date) {
    return '自 $date 起';
  }

  @override
  String get dataUsageAll => '全部';

  @override
  String get dataUsageNothingYet => '此网络上还没有统计数据。';

  @override
  String get dataUsageTapHint => '轻点类别可查看发送和接收的数据。';

  @override
  String get dataUsageSent => '已发送';

  @override
  String get dataUsageReceived => '已接收';

  @override
  String get dataUsageTotalHeader => '网络总用量';

  @override
  String get dataUsageFootnote => '统计媒体和通话。消息本身很小，不计入在内。';

  @override
  String get dataUsageReset => '重置统计';

  @override
  String get dataUsageResetTitle => '重置数据用量统计？';

  @override
  String get dataUsageResetBody => '将从现在起重新统计。';

  @override
  String get storageKindCompanions => '伙伴';

  @override
  String get storageCompanionsNote => '伙伴不会随缓存一起清除。轻点即可管理它们的下载内容。';

  @override
  String storageCategoryCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项，$size',
    );
    return '$_temp0';
  }

  @override
  String get storageSelectAll => '全选';

  @override
  String get storageDeselectAll => '取消全选';

  @override
  String get storageCategoryEmpty => '目前没有此类缓存。';

  @override
  String get storageChatHistoryFooter => '只会删除此设备上的副本。消息仍保留在聊天中，下次打开时会重新加载。';

  @override
  String get storageCategoryHint => '轻点类别查看其中内容，轻点圆圈可将其排除。';

  @override
  String storageChatRemovedNamed(String names) {
    return '$names · 已移除的聊天';
  }

  @override
  String get streaksLabel => '连胜';

  @override
  String get streakAtRiskFooter => '今天玩一局，保持你的连胜。';

  @override
  String streakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '连续 $count 天',
    );
    return '$_temp0';
  }

  @override
  String recordsCheersMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '等另外 $count 人',
    );
    return '$_temp0';
  }

  @override
  String get recordsCheer => '点赞';

  @override
  String get myStreaksLabel => '我的连胜';

  @override
  String streakLongest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '你的最长连胜：$_temp0';
  }

  @override
  String get streaksEmpty => '这里还没有人在连胜。';

  @override
  String videoTooLargeSnack(String size) {
    return '视频大小上限为 $size';
  }

  @override
  String videoShrinkPromptTitle(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个视频超过了 $size',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkPromptBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '会压缩到合适的大小，画质会明显变差。',
    );
    return '$_temp0';
  }

  @override
  String get videoShrinkPromptAction => '压缩并发送';

  @override
  String get videoShrinkWorkingSnack => '正在压缩视频…';

  @override
  String videoShrinkFailedSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个视频太长，压缩后也超过 $size',
    );
    return '$_temp0';
  }

  @override
  String photoHdOverCapSnack(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张照片超过 $size，已按标准画质发送',
    );
    return '$_temp0';
  }

  @override
  String videoShrinkSendSmallOnly(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '只发送不超过 $size 的 $count 个',
    );
    return '$_temp0';
  }

  @override
  String get kbdGroupGeneral => '通用';

  @override
  String get kbdGroupNavigation => '导航';

  @override
  String get kbdGroupChat => '聊天中';

  @override
  String get kbdGroupComposer => '输入';

  @override
  String get kbdGroupViewer => '照片和视频';

  @override
  String get kbdGroupCall => '通话';

  @override
  String get kbdCommandPalette => '搜索聊天和命令';

  @override
  String get kbdShowShortcuts => '键盘快捷键';

  @override
  String get kbdSearch => '搜索';

  @override
  String get kbdNewChat => '新聊天';

  @override
  String get kbdSettings => '设置';

  @override
  String get kbdBack => '返回或关闭';

  @override
  String kbdGoTo(String section) {
    return '前往$section';
  }

  @override
  String get kbdNextChat => '下一个聊天';

  @override
  String get kbdPreviousChat => '上一个聊天';

  @override
  String get kbdNextUnread => '下一个未读聊天';

  @override
  String get kbdCloseChat => '关闭聊天';

  @override
  String get kbdRoomInfo => '聊天信息';

  @override
  String get kbdSearchInChat => '在此聊天中搜索';

  @override
  String get kbdJumpToLatest => '跳转到最新消息';

  @override
  String get kbdAttach => '添加文件';

  @override
  String get kbdVoiceCall => '语音通话';

  @override
  String get kbdVideoCall => '视频通话';

  @override
  String get kbdSend => '发送';

  @override
  String get kbdNewline => '换行';

  @override
  String get kbdEditLast => '编辑你的最后一条消息';

  @override
  String get kbdBold => '粗体';

  @override
  String get kbdItalic => '斜体';

  @override
  String get kbdUnderline => '下划线';

  @override
  String get kbdPasteMedia => '粘贴照片或文件';

  @override
  String get kbdEmoji => '表情和贴纸';

  @override
  String get kbdViewerPrevious => '上一个';

  @override
  String get kbdViewerNext => '下一个';

  @override
  String get kbdZoomIn => '放大';

  @override
  String get kbdZoomOut => '缩小';

  @override
  String get kbdZoomFit => '适合窗口大小';

  @override
  String get kbdPlayPause => '播放或暂停';

  @override
  String get kbdCopyMedia => '复制';

  @override
  String get kbdSaveMedia => '保存';

  @override
  String get kbdToggleMute => '静音或取消静音';

  @override
  String get kbdToggleCamera => '开启或关闭摄像头';

  @override
  String get kbdHangUp => '挂断';

  @override
  String get kbdGroupApp => '应用';

  @override
  String get kbdCloseWindow => '关闭窗口';

  @override
  String get kbdMinimizeWindow => '最小化';

  @override
  String get kbdFullScreen => '全屏';

  @override
  String get kbdHideApp => '隐藏 MonkeyHub';

  @override
  String get kbdQuit => '退出 MonkeyHub';

  @override
  String get kbdPanelTitle => '键盘快捷键';

  @override
  String get kbdPanelSearchHint => '搜索快捷键';

  @override
  String get kbdPanelEmpty => '没有匹配的快捷键';

  @override
  String kbdPeekHint(String key) {
    return '随时按住 $key 即可查看当前页面的快捷键';
  }

  @override
  String kbdPeekSetting(String key) {
    return '按住 $key 时显示快捷键';
  }

  @override
  String get kbdPaletteHint => '跳转到聊天或执行命令';

  @override
  String get kbdPaletteChats => '聊天';

  @override
  String get kbdPaletteCommands => '命令';

  @override
  String get kbdPaletteEmpty => '未找到结果';

  @override
  String get kbdPaletteMove => '移动';

  @override
  String get kbdPaletteOpen => '打开';

  @override
  String get kbdPaletteClose => '关闭';

  @override
  String get msgDeskReactLabel => '回应';

  @override
  String get msgDeskMoreLabel => '更多';

  @override
  String get msgDeskInfoLabel => '信息';

  @override
  String get kbdSeekBackward => '后退 5 秒';

  @override
  String get kbdSeekForward => '前进 5 秒';

  @override
  String get kbdMuteVideo => '视频静音或取消静音';

  @override
  String get viewerSavedToDownloads => '已保存到“下载”';

  @override
  String get viewerDownloaded => '已下载';

  @override
  String get viewerShowInFinder => '在 Finder 中显示';

  @override
  String get viewerShowInFolder => '在文件夹中显示';

  @override
  String get viewerCopied => '已复制';

  @override
  String get viewerCopyFailed => '无法复制';

  @override
  String get hoverCompactLayoutTitle => '紧凑布局';

  @override
  String get hoverCompactLayoutSubtitle => '行更矮、按钮更小，适合鼠标和大屏幕。';

  @override
  String get layoutPagerPrevious => '上一页';

  @override
  String get layoutPagerNext => '下一页';

  @override
  String get resultSheetMistakes => '失误';

  @override
  String get resultSheetHints => '提示';

  @override
  String get resultSheetStreak => '连胜';

  @override
  String resultSheetStreakDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天',
    );
    return '$_temp0';
  }

  @override
  String get resultSheetNone => '无';

  @override
  String resultSheetToday(String game) {
    return '$game · 今天';
  }

  @override
  String resultSheetYouFaster(String time) {
    return '你快了 $time';
  }

  @override
  String resultSheetTheyFaster(String name, String time) {
    return '$name 快了 $time';
  }

  @override
  String get resultSheetSameTime => '和你用时相同';

  @override
  String get resultSheetFooter => '排名只看用时。失误和提示仅供参考。';

  @override
  String get resultSheetHintNoRecord => '使用了提示，因此不能成为历史纪录。';

  @override
  String get gameTierEasy => '简单';

  @override
  String get gameTierMedium => '中等';

  @override
  String get gameTierHard => '困难';

  @override
  String get gameComingSoon => '即将推出';

  @override
  String get gameComingSoonName => '新谜题';

  @override
  String get chatGameNameTicTacToe => '井字棋';

  @override
  String get chatGameNameConnectFour => '四子棋';

  @override
  String get chatGameNameCheckers => '西洋跳棋';

  @override
  String get chatGameNameReversi => '黑白棋';

  @override
  String get chatGameNameDots => '点格棋';

  @override
  String get chatGameDescTicTacToe => '三子连线获胜。';

  @override
  String get chatGameDescConnectFour => '投下棋子，四子连线获胜。';

  @override
  String get chatGameDescCheckers => '跳吃对方，吃光获胜。';

  @override
  String get chatGameDescReversi => '夹住翻转，多者获胜。';

  @override
  String get chatGameDescDots => '连线围格，再走一步。';

  @override
  String get chatGameKindLive => '实时对局';

  @override
  String get chatGameKindTurns => '轮流对局';

  @override
  String get chatGameStatusWaiting => '等待中';

  @override
  String get chatGameStatusPlaying => '进行中';

  @override
  String get chatGameStatusPaused => '已暂停';

  @override
  String get chatGameStatusFinished => '已结束';

  @override
  String get chatGameStatusEnded => '已终止';

  @override
  String get chatGameYourMove => '轮到你';

  @override
  String chatGameTurnOf(String name) {
    return '轮到 $name';
  }

  @override
  String chatGameWaitingFor(String name) {
    return '等待 $name';
  }

  @override
  String chatGameWonBy(String name) {
    return '$name 获胜';
  }

  @override
  String get chatGameYouWon => '你赢了';

  @override
  String get chatGameDraw => '平局';

  @override
  String get chatGameNobodyWon => '所有人都离开了，无人获胜';

  @override
  String chatGameReasonTimeout(String name) {
    return '$name 超时';
  }

  @override
  String chatGameReasonResign(String name) {
    return '$name 认输';
  }

  @override
  String chatGameReasonLeft(String name) {
    return '$name 离开了';
  }

  @override
  String get chatGameOpenSeat => '空位';

  @override
  String get chatGameReady => '已准备';

  @override
  String get chatGameNotReady => '未准备';

  @override
  String chatGameWatchingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人观战',
    );
    return '$_temp0';
  }

  @override
  String get chatGameJoin => '加入';

  @override
  String get chatGameWatch => '观战';

  @override
  String get chatGamePlay => '去下棋';

  @override
  String get chatGameOpen => '打开';

  @override
  String get chatGameRematch => '再来一局';

  @override
  String get chatGameNotRanked => '仅供娱乐。聊天游戏不计入连胜或纪录。';

  @override
  String get chatGameNotRankedShort => '不计排名';

  @override
  String get chatGameImReady => '我准备好了';

  @override
  String get chatGameUnready => '还没准备好';

  @override
  String get chatGameTakeSeat => '点击加入';

  @override
  String get chatGameLeaveSeat => '离开座位';

  @override
  String get chatGameStartsWhenReady => '所有人准备好后开始';

  @override
  String chatGameNeedPlayers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还需 $count 名玩家',
    );
    return '$_temp0';
  }

  @override
  String get chatGameWatchingLabel => '观战';

  @override
  String get chatGameAskSwap => '请求换人';

  @override
  String chatGameSwapRequest(String name) {
    return '$name 想换你上场';
  }

  @override
  String get chatGameSwap => '换人';

  @override
  String get chatGameDecline => '拒绝';

  @override
  String get chatGameAccept => '接受';

  @override
  String chatGameSwapAsked(String name) {
    return '已询问 $name';
  }

  @override
  String get chatGameCancel => '取消';

  @override
  String get chatGameResign => '认输';

  @override
  String get chatGameResignConfirm => '认输这局吗？';

  @override
  String get chatGameResignBody => '这会算你输。';

  @override
  String get chatGameOfferDraw => '提议和棋';

  @override
  String get chatGameDrawOffered => '已提议和棋';

  @override
  String chatGameDrawOfferFrom(String name) {
    return '$name 提议和棋';
  }

  @override
  String chatGamePausedTitle(String name) {
    return '$name 离开了游戏';
  }

  @override
  String get chatGamePausedMany => '有玩家离开了';

  @override
  String get chatGamePausedBody => '棋盘会保留一会儿。';

  @override
  String get chatGamePausedYou => '所有人回来后继续。';

  @override
  String get chatGameLeave => '退出游戏';

  @override
  String get chatGameGo => '开始！';

  @override
  String get chatGameNudge => '提醒';

  @override
  String get chatGameNudged => '已提醒';

  @override
  String chatGameHoursLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩余 $count 小时',
    );
    return '$_temp0';
  }

  @override
  String chatGameMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩余 $count 分钟',
    );
    return '$_temp0';
  }

  @override
  String get chatGameMoveFailed => '这一步没有发出';

  @override
  String get chatGameStale => '棋盘已变化，请重试。';

  @override
  String get chatGameStartTitle => '玩个游戏';

  @override
  String get chatGameMenuItem => '游戏';

  @override
  String get chatGameModeLive => '实时';

  @override
  String get chatGameBotEasyHint => '会犯错，适合练习。';

  @override
  String get chatGameBotMediumHint => '正常发挥，会堵住你的胜着。';

  @override
  String get chatGameBotHardHint => '会提前算好几步。';

  @override
  String get chatGameStart => '开始';

  @override
  String get chatGameErrAlreadyLive => '这里已有一局实时对局，请先结束或退出。';

  @override
  String get chatGameErrTooMany => '这里已有 3 局轮流对局，请先完成一局。';

  @override
  String get chatGameErrEphemeral => '消息会消失的聊天里不能玩游戏。';

  @override
  String get chatGameErrGeneric => '出了点问题，请重试。';

  @override
  String get chatGamePlayersTwo => '2 人';

  @override
  String get chatGamePlayersUpToFour => '2–4 人';

  @override
  String get chatGameBotName => '小猴';

  @override
  String get chatGameBotBadge => '机器人';

  @override
  String get chatGameNewGame => '新游戏';

  @override
  String chatGameBannerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 局游戏',
    );
    return '$_temp0';
  }

  @override
  String chatGameBannerYourMoves(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 局轮到你',
    );
    return '$_temp0';
  }

  @override
  String get chatGameSheetTitle => '此聊天中的游戏';

  @override
  String get chatGameGone => '此对局已不可用。';

  @override
  String get chatGameSeatsLabel => '玩家';

  @override
  String get gameFlowName => '管道';

  @override
  String get gameFutoshikiName => '不等号';

  @override
  String get gameNonogramName => '数织';

  @override
  String get gameMinesweeperName => '扫雷';

  @override
  String get gameStarbattleName => '星战';

  @override
  String get gamePatchesName => '拼布';

  @override
  String get gameFlowRule => '连接相同的点，填满每一格';

  @override
  String get gameFutoshikiRule => '每行每列 1 到 5 各一次，符号全部成立';

  @override
  String get gameNonogramRule => '涂黑格子，让每条提示都对上';

  @override
  String get gameMinesweeperRule => '打开所有安全格子，无需猜测';

  @override
  String get gameStarbattleRule => '每行、每列、每色各两颗星，且不相邻';

  @override
  String get gamePatchesRule => '把棋盘切成长方形，每块里一个提示';

  @override
  String get gameFlag => '插旗';

  @override
  String get gameAutoDot => '自动打点';

  @override
  String boardCellName(int row, int col) {
    return '第 $row 行，第 $col 列';
  }

  @override
  String get boardEmpty => '空';

  @override
  String get boardBlack => '黑';

  @override
  String get boardWhite => '白';

  @override
  String get boardLegalMove => '可落子';

  @override
  String get boardMoveHere => '移到这里';

  @override
  String boardColumnFilled(int column, int count, int total) {
    return '第 $column 列，已填 $count/$total';
  }

  @override
  String boardSquareName(int number) {
    return '第 $number 格';
  }

  @override
  String get boardDarkMan => '深色棋子';

  @override
  String get boardDarkKing => '深色王棋';

  @override
  String get boardLightMan => '浅色棋子';

  @override
  String get boardLightKing => '浅色王棋';

  @override
  String boardBoxName(String cell) {
    return '格子，$cell';
  }

  @override
  String get boardOpen => '未占';

  @override
  String get boardDrawn => '已画';

  @override
  String boardClaimedBy(String name) {
    return '归 $name';
  }

  @override
  String boardHorizontalEdge(int row, int col) {
    return '横线，第 $row 行，第 $col 列';
  }

  @override
  String boardVerticalEdge(int row, int col) {
    return '竖线，第 $row 行，第 $col 列';
  }

  @override
  String get challengeAction => '发起挑战';

  @override
  String get challengeTitle => '来破我的纪录';

  @override
  String get challengeKind => '每日挑战';

  @override
  String challengeYouBeat(String time) {
    return '你快了 $time';
  }

  @override
  String challengeStillStanding(String time) {
    return '纪录保持，差 $time';
  }

  @override
  String get challengeTie => '完全打平';

  @override
  String get challengeClosed => '该棋盘已关闭';

  @override
  String get challengeYourTime => '你的纪录';

  @override
  String get challengeSent => '挑战已发送';

  @override
  String challengeTarget(String name, String time) {
    return '$name $time';
  }

  @override
  String challengeBeatName(String name, String time) {
    return '你打破了 $name 的 $time';
  }

  @override
  String challengeKept(String name, String time) {
    return '$name 守住了，差 $time';
  }

  @override
  String challengeBackName(String name) {
    return '向$name回敬挑战';
  }

  @override
  String challengeBackRoom(String room) {
    return '在$room中回复';
  }

  @override
  String challengeFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位好友玩过了',
      zero: '这里还没有好友玩过',
    );
    return '$_temp0';
  }

  @override
  String challengeYouAndFriendsPlayed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '你和 $count 位好友玩过了',
      zero: '目前只有你玩过',
    );
    return '$_temp0';
  }

  @override
  String get challengeFriendsOnlyNote => '这里只显示你的好友。这个聊天里的其他人可能也玩过。';

  @override
  String get chatGameNameLiarsDice => '吹牛骰';

  @override
  String get chatGameNameImposter => '谁是卧底';

  @override
  String get chatGameNameRace => '解谜竞速';

  @override
  String get chatGameDescLiarsDice => '对暗骰叫点，揭穿吹牛的人。';

  @override
  String get chatGameDescImposter => '有一个人不知道词语，把他找出来。';

  @override
  String get chatGameDescRace => '同一道谜题，最快解开的人获胜。';

  @override
  String chatGamePlayersRange(int min, int max) {
    return '$min–$max 人';
  }

  @override
  String chatGameNeedsPeople(int count) {
    return '至少需要 $count 人';
  }

  @override
  String get chatGameVoiceOption => '语音提示';

  @override
  String get chatGameVoiceOptionHint => '在通话中说出提示，而不是打字';

  @override
  String get chatGamePuzzleOption => '谜题';

  @override
  String get chatGamePuzzleRandom => '随机';

  @override
  String chatGameStartNamed(String game) {
    return '开始$game';
  }

  @override
  String chatGameLdRoundDice(int count, int round) {
    return '第 $round 轮 · $count 颗骰子';
  }

  @override
  String get chatGameLdYourDice => '你的骰子';

  @override
  String get chatGameLdNoBid => '还没有人叫点';

  @override
  String chatGameLdBidBy(String name) {
    return '$name 的叫点';
  }

  @override
  String get chatGameLdYourBid => '你的叫点';

  @override
  String get chatGameLdBid => '叫点';

  @override
  String get chatGameLdLiar => '开！';

  @override
  String get chatGameLdOnesWild => '1 点可当任意点';

  @override
  String get chatGameLdOnesOnly => '叫 1 点时 1 不再万能';

  @override
  String get chatGameLdHolds => '叫点成立';

  @override
  String get chatGameLdBusted => '被拆穿！';

  @override
  String chatGameLdThereWere(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '实际有 $count 个',
    );
    return '$_temp0';
  }

  @override
  String chatGameLdLosesDie(String name) {
    return '$name 失去一颗骰子';
  }

  @override
  String get chatGameLdYouLoseDie => '你失去一颗骰子';

  @override
  String chatGameLdCalled(String name) {
    return '$name 开了';
  }

  @override
  String chatGameLdTimedOut(String name) {
    return '$name 超时了';
  }

  @override
  String get chatGameLdOut => '出局';

  @override
  String get chatGameLdQuantity => '数量';

  @override
  String get chatGameLdFace => '哪个点数';

  @override
  String get chatGameLdFewer => '减少';

  @override
  String get chatGameLdMore => '增加';

  @override
  String get chatGameLdPrompt => '加注或者开';

  @override
  String get chatGameLdOpenPrompt => '开始叫点';

  @override
  String get chatGameImpHoldToSee => '长按查看你的卡片';

  @override
  String get chatGameImpYourWord => '你的词语';

  @override
  String get chatGameImpYouAre => '你是卧底';

  @override
  String chatGameImpCategory(String category) {
    return '类别：$category';
  }

  @override
  String get chatGameImpBlendIn => '混进去，没人知道。';

  @override
  String get chatGameImpKeepSecret => '别直接说出来，给出队友能懂的提示。';

  @override
  String get chatGameImpGotIt => '知道了';

  @override
  String chatGameImpLooked(int count, int total) {
    return '$total 人中已有 $count 人查看';
  }

  @override
  String chatGameImpGiving(String name) {
    return '$name 正在给提示';
  }

  @override
  String get chatGameImpYourClue => '轮到你给提示了';

  @override
  String get chatGameImpClueHint => '一到四个词';

  @override
  String get chatGameImpClueField => '你的提示';

  @override
  String get chatGameImpSend => '发送';

  @override
  String get chatGameImpTooManyWords => '最多四个词';

  @override
  String get chatGameImpPassed => '跳过了';

  @override
  String get chatGameImpSpoke => '已在通话中发言';

  @override
  String get chatGameImpJoinCall => '加入通话';

  @override
  String get chatGameImpOnCall => '你已在通话中';

  @override
  String get chatGameImpVoiceHint => '大声说出提示，然后点按“完成”。';

  @override
  String get chatGameImpDone => '完成';

  @override
  String get chatGameImpVoteTitle => '谁是卧底？';

  @override
  String get chatGameImpVoteHint => '点按玩家投票，时间结束前可以更改。';

  @override
  String get chatGameImpSkip => '弃权';

  @override
  String chatGameImpVoted(int count, int total) {
    return '$total 人中 $count 人已投票';
  }

  @override
  String get chatGameImpVotedBadge => '已投票';

  @override
  String get chatGameImpYourVote => '你的票';

  @override
  String get chatGameImpGuessing => '卧底正在猜词…';

  @override
  String get chatGameImpGuessHint => '你被抓到了。猜中词语就能反败为胜。';

  @override
  String get chatGameImpGuessField => '词语是……';

  @override
  String get chatGameImpGuess => '猜';

  @override
  String chatGameImpWas(String name) {
    return '$name 是卧底';
  }

  @override
  String get chatGameImpYouWere => '你是卧底';

  @override
  String get chatGameImpTheWord => '词语是';

  @override
  String chatGameImpTheyGuessed(String guess) {
    return '猜的是“$guess”';
  }

  @override
  String chatGameImpVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 票',
    );
    return '$_temp0';
  }

  @override
  String chatGameImpSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人弃权',
    );
    return '$_temp0';
  }

  @override
  String get chatGameImpReasonEscaped => '没有人被投出，卧底逃脱了。';

  @override
  String get chatGameImpReasonWrong => '大家投错了人。';

  @override
  String get chatGameImpReasonGuessed => '卧底被抓，但猜中了词语。';

  @override
  String get chatGameImpReasonCaught => '大家抓到了卧底。';

  @override
  String get chatGameImpReasonImposterLeft => '卧底离开了游戏。';

  @override
  String get chatGameImpReasonCrewLeft => '其他人都离开了。';

  @override
  String get chatGameImpCrewWon => '平民获胜';

  @override
  String get chatGameImpYourTeamWon => '你的队伍获胜';

  @override
  String chatGameImpImposterWon(String name) {
    return '卧底 $name 获胜';
  }

  @override
  String get chatGameImpYouWonImposter => '你作为卧底获胜';

  @override
  String get chatGameImpCardReveal => '正在查看卡片';

  @override
  String chatGameImpCardClues(int count, int total) {
    return '提示 · $count/$total';
  }

  @override
  String get chatGameImpCardVote => '投票中';

  @override
  String chatGameRaceFinishedCount(int count, int total) {
    return '$total 人中 $count 人完成';
  }

  @override
  String chatGameRaceYouPlaced(int rank) {
    return '你获得第 $rank 名';
  }

  @override
  String get chatGameRaceWaiting => '等待其他人';

  @override
  String get chatGameRaceTimeUp => '时间到，没有人完成。';

  @override
  String get chatGameRaceDnf => '未完成';

  @override
  String get chatGameRaceLeft => '已离开';

  @override
  String get chatGameRaceResults => '结果';

  @override
  String get chatGameRaceSolved => '解开了！';

  @override
  String get chatGamePartyLeaveConfirm => '要退出这局游戏吗？';

  @override
  String get chatGamePartyLeaveBody => '其他人会继续游戏。';

  @override
  String get chatGameErrTooLate => '太晚了，时间已到';

  @override
  String get chatGameErrBadClue => '这个提示不能用。一到四个词，不能有链接。';

  @override
  String get chatGameErrBadGuess => '请先输入答案';

  @override
  String get chatGameErrNotSolved => '还没有解开';

  @override
  String get chatGameNameChess => '国际象棋';

  @override
  String get chatGameDescChess => '将死对方的王即获胜。';

  @override
  String get chessPawn => '兵';

  @override
  String get chessKnight => '马';

  @override
  String get chessBishop => '象';

  @override
  String get chessRook => '车';

  @override
  String get chessQueen => '后';

  @override
  String get chessKing => '王';

  @override
  String chessPieceWhite(String piece) {
    return '$piece（白方）';
  }

  @override
  String chessPieceBlack(String piece) {
    return '$piece（黑方）';
  }

  @override
  String chessPromoteTo(String piece) {
    return '升变为$piece';
  }

  @override
  String get kbdPeekDontShowAgain => '不再显示';

  @override
  String get kbdPeekTurnedOff => '好的，不会再弹出了。可以随时在设置里重新打开。';

  @override
  String get chatGameBadgeTurns => '轮流';

  @override
  String get chatGameSectionBoards => '棋盘游戏';

  @override
  String get chatGameSectionParty => '派对游戏';

  @override
  String get chatGameBoardsHintDm => '现在就实时玩，或者有空时轮流下。';

  @override
  String get chatGameBoardsHintGroup => '就在这儿实时玩。上桌或者围观都行。';

  @override
  String get chatGamePartyHint => '大家同时玩，先把人叫齐吧。';

  @override
  String get chatGameLiveTitle => '实时玩';

  @override
  String get chatGameLiveNow => '大家同一时间，现在就玩。';

  @override
  String get chatGameLivePause => '有人离开会暂停。2 分钟内不回来就算输。';

  @override
  String get chatGameTurnsTitle => '轮流玩';

  @override
  String get chatGameTurnsAnytime => '想什么时候走都行，每一步都会发到聊天里。';

  @override
  String get chatGameTurnsClock => '每步 2 天。我们会提醒对方，你也能催一下。';

  @override
  String get chatGameHowWillYouPlay => '想怎么玩？';

  @override
  String get botHubTitle => '和机器人玩';

  @override
  String botHubSubtitle(String bot) {
    return '只有你和$bot。先练熟招数，再去赢朋友。';
  }

  @override
  String get botHubLevelTitle => '要多难？';

  @override
  String get botHubPickGame => '选个游戏';

  @override
  String get botHubCaption => '练习';

  @override
  String botHubGameCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 款游戏',
    );
    return '$_temp0';
  }

  @override
  String get practiceNotRanked => '仅供娱乐。这些对局不计入连胜或纪录。';

  @override
  String get chatGameMvYouPlayed => '你走了一步';

  @override
  String chatGameMvTheyPlayed(String name) {
    return '$name 走了一步';
  }

  @override
  String chatGameMvNumber(int count) {
    return '第 $count 步';
  }

  @override
  String chatGameMvColumn(int count) {
    return '第 $count 列';
  }

  @override
  String get chatGameMvEarlier => '之前的一步';

  @override
  String get chatGameMvSend => '发送这步';

  @override
  String get chatGameMvUndo => '撤销';

  @override
  String get chatGameMvStagedHint => '还没发出去。想改就改，或者点发送。';

  @override
  String get chatGameMvSentToast => '已发送，轮到对方了。';

  @override
  String get chatGameMvYourTurnSub => '走好这步再发送，不着急。';

  @override
  String get chatGameMvWaitingSub => '轮到你时会通知你。';

  @override
  String get chatGameMvNudgeLater => '对方 12 小时没动静时可以催一下';

  @override
  String get chatGameMvForfeitNote => '时间用完，轮到的人就输了';

  @override
  String get chatGameMvAgain => '还是你的回合，再走一步！';

  @override
  String get chatGameMvSending => '发送中…';

  @override
  String get howToNext => '下一步';

  @override
  String get howToWatchAgain => '再看一遍';

  @override
  String get howToGotIt => '懂了';

  @override
  String get howToProTip => '小技巧';

  @override
  String howToStepSemantic(int step, int total) {
    return '第 $step 步，共 $total 步';
  }

  @override
  String get howToQueens1 => '每行、每列、每种颜色，各放一顶王冠。';

  @override
  String get howToQueens2 => '王冠不能挨着，斜着挨也不行。';

  @override
  String get howToQueens3 => '点一下打 ×，点两下放王冠，再点一下清掉。';

  @override
  String get howToQueens4 => '开启“自动打叉”后，被王冠排除的格子都会自动打上 ×。然后看看还剩哪些格子。';

  @override
  String get howToTango1 => '点一下是太阳，点两下是月亮。把格子全填满。';

  @override
  String get howToTango2 => '每行每列都是一半太阳、一半月亮。';

  @override
  String get howToTango3 => '同样的不能横着或竖着连着 3 个，2 个没问题。';

  @override
  String get howToTango4 => '= 表示两个一样，× 表示两个相反。';

  @override
  String get howToTangoTip => '两个相同的挨在一起？两头的格子就是另一种。';

  @override
  String get howToZip1 => '从 1 出发，按顺序划过每个数字。';

  @override
  String get howToZip2 => '走遍所有格子，在最后一个数字收尾。';

  @override
  String get howToZip3 => '走错了？往回划就撤销了。';

  @override
  String get howToZipTip => '别把哪个格子孤立出来。路过角落和边缘时顺手带上。';

  @override
  String get howToSudoku1 => '每行、每列、每个宫都是 1 到 6，不能重复。';

  @override
  String get howToSudoku2 => '先点格子，再点数字。';

  @override
  String get howToSudoku3 => '同一行、同一列或同一宫出现重复数字？会变红。';

  @override
  String get howToSudoku4 => '找只差一个数字的行或列，白送的。';

  @override
  String get howToFlow1 => '从一个点划到同色的另一个点，连成管道。';

  @override
  String get howToFlow2 => '管道不能交叉，每个格子都要填满。绕远一点也没关系。';

  @override
  String get howToFlowTip => '先把管道沿着边缘铺。中间自然就理顺了。';

  @override
  String get howToFutoshiki1 => '在每个格子里填 1 到 5。每行每列，每个数字恰好出现一次。';

  @override
  String get howToFutoshiki2 => '符号尖的那头指向小的数字。';

  @override
  String get howToFutoshiki3 => '不符合符号就会变红。';

  @override
  String get howToFutoshikiTip => '顺着不等号链看：如果 a < b < c，那 c 至少是 3。';

  @override
  String get howToNonogram1 => '每个数字代表一段连续涂色的格子，中间不能有空。5 就是连着涂 5 格。';

  @override
  String get howToNonogram2 => '1 1 是两个单独的格子，中间至少空一格，空得更多也行。';

  @override
  String get howToNonogramOrder => '顺序很重要：行从左往右读，列从上往下读。1 3 就是先 1 格，再 3 格。';

  @override
  String get howToNonogram3 => '点一下涂色，再点打 ×，再点清除。拖动可以一次涂一大片。';

  @override
  String get howToNonogram4 => '所有提示都对上，隐藏的图案就出来了。';

  @override
  String get howToNonogramTip => '从大数字入手。10 格一行里的 7，无论怎么放都会盖住中间 4 格。';

  @override
  String get howToMines1 => '打开所有没有雷的格子。空白区域会自己展开。';

  @override
  String get howToMines2 => '数字表示周围有几颗雷，斜角也算。';

  @override
  String get howToMines3 => '确定是雷？长按插旗。';

  @override
  String get howToMines4 => '踩到雷罚 30 秒。不过你从来都不用靠猜。';

  @override
  String get howToMinesTip => '某个 1 旁边只有一个没翻开的格子？那格就是雷。';

  @override
  String get howToStars1 => '每行、每列、每种颜色，各放 2 颗星。';

  @override
  String get howToStars2 => '星星不能挨着，斜着挨也不行。';

  @override
  String get howToStarsControls => '点一下打点，点两下放星星，再点一下清掉。';

  @override
  String get howToStars3 => '开启“自动打点”后，星星周围的格子会自动打点。一行凑齐 2 颗星，其余格子也会被打点。';

  @override
  String get howToPatches1 => '把棋盘切成长方形，每块里正好有一个提示。';

  @override
  String get howToPatches2 =>
      '徽章就是拼块的形状：正方形、竖长或横宽。虚线徽章表示这三种都可以。有数字时，数字是拼块占的格子数。';

  @override
  String get howToPatches3 => '从一个角拖到对角，切出一块拼块。点一下拼块就能拿掉。';

  @override
  String get howToPatches4 => '贴着边的大提示往往只有一种放法。从那里开始。';

  @override
  String get howToCode1 => '有一串由 4 个不同符号组成的密码，符号不会重复。破解它。';

  @override
  String get howToCode2 => '绿色：符号对，位置也对。';

  @override
  String get howToCode3 => '黄色：密码里有，但位置不对。灰色：密码里根本没有。';

  @override
  String get howToCode4 => '你有 6 次机会，用得越少越厉害。';

  @override
  String get howToCodeTip => '前几次先试没用过的符号。摸清情况比瞎猜强。';

  @override
  String get howToTtt1 => '轮流放下你的标记，先连成 3 个的赢。';

  @override
  String get howToTtt2 => '对方已经连了 2 个？抢先占住第三格。';

  @override
  String get howToC41 => '点一列放下棋子，它会落到最底下的空位。';

  @override
  String get howToC42 => '连成 4 个就赢：横、竖、斜都算。';

  @override
  String get howToC4Tip => '下中间那一列。它能参与的四连比哪一列都多。';

  @override
  String get howToCheckers1 => '棋子斜着向前走一格。先点棋子，再点要去的格子。';

  @override
  String get howToCheckers2 => '跳过对方的棋子就能吃掉它。能跳就必须跳，必须跳的棋子会出现一个圈。';

  @override
  String get howToCheckers3 => '落下后还能接着跳？继续跳，一步就能吃好几个。';

  @override
  String get howToCheckers4 => '走到对面底线就升为王，王还能往后走，但每次仍然只走一格。';

  @override
  String get howToCheckersWin =>
      '吃光对方的棋子，或让对方无路可走，就赢了。双方各走 40 步都没有吃子、也没有移动普通棋子，就是平局。';

  @override
  String get howToCheckersTip => '守住自己的底线那一排。这样对方就没法升王。';

  @override
  String get howToReversi1 => '落子时，把对方的一排棋子夹在你的两颗棋子之间。每一步都必须至少夹住一颗。';

  @override
  String get howToReversi2 => '被夹住的棋子全部翻成你的颜色，所有方向一起翻。';

  @override
  String get howToReversi3 => '没地方下？这回合跳过。双方都下不了时，棋子多的赢。';

  @override
  String get howToReversiTip => '抢角。角上的棋子永远不会被翻转。';

  @override
  String get howToDots1 => '轮流在两个点之间画一条线。';

  @override
  String get howToDots2 => '封住一个格子就归你，而且你还能再画一条！';

  @override
  String get howToDots3 => '小心别画格子的第三条边，那等于把格子送给下一个人。';

  @override
  String get howToDotsWin => '最后一条线画完时，格子最多的人赢。';

  @override
  String get howToChess1 => '点一个棋子，看它能走到哪，再点目标格。';

  @override
  String get howToChess2 => '走到对方棋子的格子上就能吃掉它。';

  @override
  String get howToChess3 => '把兵走到最后一行，它就能变成后，或者你选的其他棋子。';

  @override
  String get howToChess4 => '将军就是王被攻击了，必须马上解围。无路可逃？将死，游戏结束。没有能走的棋但也没被将军？那就是和棋。';

  @override
  String get howToChessTip => '每走一步前，先看看对方能吃掉什么。';

  @override
  String get howToLiars1 => '每人偷偷摇 5 颗骰子，你只能看到自己的。';

  @override
  String get howToLiars2 => '轮到你时，叫全桌某个点数至少有几个，所有人的骰子都算。比如“4 个 3”。';

  @override
  String get howToLiars3 => '1 点是万能的，可以当任何点数。除非叫的就是 1。';

  @override
  String get howToLiars4 => '下一个人必须往上加：要么个数更多，要么同样个数但点数更大…';

  @override
  String get howToLiars5 => '…或者直接“开！”。所有人亮出骰子一起数。';

  @override
  String get howToLiars6 => '实际至少有那么多？开的人丢一颗骰子。不够？叫的人丢一颗。';

  @override
  String get howToLiars7 => '骰子没了就出局，最后还有骰子的人赢。';

  @override
  String get howToLiarsClock => '每回合 45 秒，超时系统会替你出手。';

  @override
  String get howToLiarsTip => '先数自己的骰子。因为 1 是万能的，别人的骰子里大约三分之一会符合你叫的点数。';

  @override
  String get howToImposter1 => '大家拿到同一个秘密词，只有卧底拿到的是类别。';

  @override
  String get howToImposter2 => '轮流给一个简短提示，证明你知道这个词，但别说漏嘴。';

  @override
  String get howToImposterVoice => '语音模式：在通话里把提示说出来，然后点完成。';

  @override
  String get howToImposter3 => '然后大家投票，选出你觉得是卧底的人，也可以弃权。';

  @override
  String get howToImposter4 => '抓到了？卧底还有最后一次机会：猜中词就反杀。投错人、平票或者弃权的人太多？卧底赢。';

  @override
  String get howToRace1 => '所有人同时拿到同一道全新的谜题。';

  @override
  String get howToRace2 => '在自己的手机上解，你的进度条会让大家看到你有多接近。';

  @override
  String get howToRace3 => '先完成的人赢，限时 10 分钟。';

  @override
  String get howToLive1 => '大家同时开玩。所有人都点了“我准备好了”就开始。';

  @override
  String get howToLive2 => '有人离开了游戏？所有人一起暂停。2 分钟内不回来就算认输。';

  @override
  String get howToLive3 => '群里其他人可以观战，也可以申请上场，玩家可以把座位让出来。';

  @override
  String get howToTurns1 => '走完一步后点“发送这步”，它会作为一条消息发到聊天里。';

  @override
  String get howToTurns2 => '每步有 2 天时间。20 小时后我们会提醒对方，安静 12 小时后你也可以亲自提醒。';

  @override
  String get howToTurns3 => '2 天没走就算输。每个聊天最多同时进行 3 局。';

  @override
  String momentActivityGamesSolvedAll(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个游戏',
    );
    return '$name 解开了 $_temp0';
  }

  @override
  String momentActivityGamesSolvedSome(int count, String name, int solved) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个',
    );
    return '$name 解开了 $_temp0中的 $solved 个';
  }

  @override
  String momentActivityGamesPlayed(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个游戏',
    );
    return '$name 玩了 $_temp0';
  }

  @override
  String momentActivityHighlightsPosted(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个瞬间',
    );
    return '$name 发布了 $_temp0';
  }

  @override
  String podiumSharedBy(int count, String names, int place) {
    return '第 $place 名，$count 人并列：$names';
  }

  @override
  String get myBestsLabel => '我的最佳';

  @override
  String recordsSharedBy(int count, String name) {
    return '$name +$count';
  }

  @override
  String get reportSheetDisclosureMessage =>
      '举报后，这条消息及此聊天中最近的几条消息会发送给 MonkeyHub 管理员审核。对方不会知道你举报了他们。';

  @override
  String get reportSheetDisclosureUser =>
      '举报后，你与此人最近的几条消息会发送给 MonkeyHub 管理员审核。对方不会知道你举报了他们。';

  @override
  String get reportSheetDisclosureRoom =>
      '举报后，此群组中最近的几条消息会发送给 MonkeyHub 管理员审核。这里的任何人都不会知道你举报了它。';

  @override
  String get reportSheetAlsoBlock => '同时屏蔽此人';

  @override
  String get reportSentReviewed => '谢谢。我们的管理员会在 24 小时内审核举报。';

  @override
  String get reportSentAndBlocked => '谢谢。我们的管理员会在 24 小时内审核举报。你已屏蔽此人。';

  @override
  String get reportTooMany => '你发送的举报太多了。请稍后再试。';

  @override
  String get reportFailed => '无法发送举报。请重试。';

  @override
  String get riReportPerson => '举报此人';

  @override
  String get riReportGroup => '举报此群组';

  @override
  String get moderationActionRemoveMessage => '移除消息';

  @override
  String get moderationActionBan => '封禁用户';

  @override
  String get moderationActionUnban => '解除封禁';

  @override
  String get moderationActionDismiss => '驳回举报';

  @override
  String get moderationConfirmRemoveTitle => '要移除这条消息吗？';

  @override
  String get moderationConfirmRemoveBody => '这条消息会对对话中的所有人删除。举报卡片会保留副本。';

  @override
  String get moderationConfirmBanTitle => '要封禁此账号吗？';

  @override
  String get moderationConfirmBanBody =>
      '对方将在所有设备上退出登录，无法再次登录，不会出现在搜索中，并会退出所有公开房间。你可以在此卡片上解除封禁。';

  @override
  String get moderationActionDone => '完成';

  @override
  String get moderationActionFailed => '操作未完成。请重试。';

  @override
  String get moderationCantBan => '管理员和系统账号无法被封禁。';

  @override
  String get messageFilterBlocked => '这条消息可能包含不当用语，因此无法发送。';

  @override
  String get nameInappropriate => '该名称可能包含不当用语。请换一个。';

  @override
  String get authErrorAccountSuspended => '你的账号因违反使用条款已被停用。';

  @override
  String get termsConsentPrefix => '我同意';

  @override
  String get termsConsentLink => '使用条款（EULA）';

  @override
  String get termsConsentSuffix => '，并理解对不良内容或滥用行为的用户零容忍。';

  @override
  String get termsConsentSemanticLabel => '同意使用条款';

  @override
  String get termsMustAccept => '请同意使用条款以继续。';

  @override
  String get termsSheetTitle => '使用条款';

  @override
  String get termsSheetBody =>
      '要继续使用 MonkeyHub，请同意我们的使用条款。这里不容许不良内容或滥用行为，被举报的内容会由我们的管理员审核。';

  @override
  String get termsSheetAccept => '同意并继续';

  @override
  String get termsAcceptFailed => '无法保存。请重试。';

  @override
  String get settingsHubContactSupport => '联系支持';

  @override
  String get reportSheetDisclosureMoment =>
      '举报会将这条动态发送给 MonkeyHub 管理员审核。对方不会知道你举报了他们。';

  @override
  String get reportSheetDisclosureComment =>
      '举报会将这条评论发送给 MonkeyHub 管理员审核。对方不会知道你举报了他们。';

  @override
  String get sendLimitRateLimited => '你发送得太快了。请稍等片刻再试。';

  @override
  String get sendLimitStorageFull => '你的存储空间已满。删除一些已发送的照片或文件以释放空间。';

  @override
  String get sendLimitFileTooLarge => '该文件太大，无法发送。';

  @override
  String get sendLimitMessageTooLong => '这条消息太长了。试着拆分成几条发送。';

  @override
  String get limitTooOften => '操作过于频繁，请稍后再试。';

  @override
  String get limitRoomFull => '此房间已满。';

  @override
  String get limitRemovedFromRoom => '你已被移出此房间。管理员可以重新邀请你。';

  @override
  String get limitTooManyRooms => '你加入的房间太多了。请先退出一个不再使用的房间。';

  @override
  String get limitRoomTextTooLong => '名称或简介太长。名称请少于 100 个字符，简介少于 500 个字符。';

  @override
  String get limitNotYourFile => '无法使用该文件。请重新选择后再试。';

  @override
  String get limitDeviceLoginBusy => '登录码暂时繁忙，请一分钟后再试。';

  @override
  String get limitRequestMessages => '在对方接受你的请求前，你无法再发送消息。';

  @override
  String get mediaSendViewOnceTip => '对方只能打开一次';

  @override
  String get mediaSendSpoilerTip => '被尘埃遮住，点一下才显示';

  @override
  String get mediaSendSpoilerNote => '点一下才显示';

  @override
  String get mediaSendSpoilerOnSemanticLabel => '剧透：开';

  @override
  String get mediaSendSpoilerOffSemanticLabel => '剧透：关';

  @override
  String get mediaSpoilerRevealSemanticLabel => '剧透。点按显示';

  @override
  String get roomScreenCaptureOpenTitle => '可被截屏';

  @override
  String get roomScreenCaptureOpenSubtitle => '应用内已禁止';

  @override
  String get captureNoticeRoomTitle => '此处无法阻止截屏';

  @override
  String get captureNoticeRoomBody =>
      '此设备无法阻止截屏或录屏，因此这个房间里的任何内容都可能在这里被截取。适用于 iPhone、Android、Mac 和 Windows 的 MonkeyHub 应用可以阻止。';

  @override
  String get captureNoticeViewOnceTitle => '在这里可能被截取';

  @override
  String get captureNoticeViewOnceBody =>
      '此设备无法阻止截屏，因此你在这里打开的内容可能被保存。在适用于 iPhone、Android、Mac 或 Windows 的 MonkeyHub 应用中则无法保存。无论在哪里打开，你都只能查看一次。';

  @override
  String get captureNoticeGetApp => '获取应用';

  @override
  String get captureNoticeGotIt => '知道了';

  @override
  String get captureNoticeOpenAnyway => '仍然打开';

  @override
  String get captureNoticeNotNow => '暂不';

  @override
  String get voiceTranscriptShow => '显示转写文字';

  @override
  String get voiceTranscriptHide => '隐藏转写文字';

  @override
  String voiceTranscriptCellularPrompt(String size) {
    return '转写在你的手机上完成。语音模型只需下载一次（$size）。';
  }

  @override
  String voiceTranscriptDownloadAction(String size) {
    return '下载 $size';
  }

  @override
  String voiceTranscriptDownloading(String received, String total) {
    return '正在下载语音模型 · $received / $total';
  }

  @override
  String get voiceTranscriptOneTimeNote => '只需一次。之后转写可离线使用。';

  @override
  String get voiceTranscriptCancel => '取消';

  @override
  String get voiceTranscriptWorking => '正在转写…';

  @override
  String get voiceTranscriptFailedNetwork => '无法下载语音模型。';

  @override
  String voiceTranscriptFailedStorage(String size) {
    return '可用空间不足。语音模型需要 $size。';
  }

  @override
  String get voiceTranscriptFailedAudio => '无法读取这条语音消息。';

  @override
  String get voiceTranscriptFailed => '无法转写这条语音消息。';

  @override
  String get voiceTranscriptRetry => '重试';

  @override
  String get voiceTranscriptNoSpeech => '这条语音消息里没有说话内容。';

  @override
  String get voiceTranscriptOnDevice => '在此设备上转写';

  @override
  String voiceTranscriptLanguageOnDevice(String language) {
    return '$language · 在此设备上';
  }

  @override
  String get voiceTranscriptCopy => '复制';

  @override
  String get voiceTranscriptCopied => '已复制转写文字';

  @override
  String get storageKindSpeechModel => '语音转写';

  @override
  String get voiceTranscriptBuiltInCredit => 'Apple 语音识别';

  @override
  String voiceTranscriptBuiltInLanguageCredit(String language) {
    return '$language · Apple 语音识别';
  }

  @override
  String get voiceTranscriptUpgradeLink => '更好的转写';

  @override
  String voiceTranscriptUpgradeOffer(String size) {
    return '语言或文字不对？MonkeyHub 语音模型能自己听出说的是哪种语言，支持近 100 种语言。只需下载一次（$size），之后可离线使用。';
  }

  @override
  String get voiceTranscriptNotNow => '暂不';
}
