// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get splashBrand => 'MONKEYHUB';

  @override
  String get bootErrorTitle => 'サーバーに接続できません';

  @override
  String get bootErrorBody => 'Convexが初期化されませんでした。';

  @override
  String get bootErrorRetry => '再試行';

  @override
  String get incomingCallNotificationTitle => '着信';

  @override
  String get incomingCallFallbackCaller => 'だれかから着信があります';

  @override
  String get settingsLanguageRowLabel => '言語';

  @override
  String get languageScreenTitle => '言語。';

  @override
  String get languageScreenSubtitle => 'アプリのメニューやメッセージで使う言語を選んでください';

  @override
  String get languageOptionSystem => 'システム';

  @override
  String get languageOptionSystemSub => '端末の言語設定に合わせます';

  @override
  String get languageOptionEnglish => 'ENGLISH';

  @override
  String get languageOptionTurkish => 'TÜRKÇE';

  @override
  String get languageScreenActiveBadge => '選択中';

  @override
  String get languageValueSystem => 'システム';

  @override
  String get languageValueEnglish => 'English';

  @override
  String get languageValueTurkish => 'Türkçe';

  @override
  String get roomScreenAskGrownUpFailedSnack =>
      '今はリクエストを送信できませんでした。もう一度お試しください';

  @override
  String get roomScreenGateSendMessages => 'ここでメッセージを送る';

  @override
  String get roomScreenGateSendMedia => '写真や音声メモを送る';

  @override
  String roomScreenMaxSelectionSnack(Object max) {
    return '一度に選べるのは$max件までです';
  }

  @override
  String roomScreenDeleteMessageHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のメッセージを削除',
    );
    return '$_temp0';
  }

  @override
  String get roomScreenDeleteConfirmBody => 'このチャットにいる全員から削除されます。元に戻すことはできません。';

  @override
  String get roomScreenDeleteConfirmButton => '全員に対して削除';

  @override
  String get roomScreenJumpFailedSnack => 'そのメッセージに移動できませんでした';

  @override
  String get roomScreenUnreadDivider => '未読メッセージ';

  @override
  String get roomScreenViewOnceAlreadyViewed => 'この写真はすでに開いています。';

  @override
  String get roomScreenViewOnceGone => 'この写真はもう利用できません。';

  @override
  String get roomScreenViewOnceNetworkError => 'その写真を読み込めませんでした。';

  @override
  String get roomScreenFileReadFailedSnack => 'そのファイルを読み込めませんでした';

  @override
  String roomScreenFileSizeCapSnack(Object size) {
    return 'ファイルは$sizeまでです';
  }

  @override
  String get roomScreenRoomGone => 'ルームは存在しません';

  @override
  String get roomScreenCopiedSnack => 'コピーしました';

  @override
  String get roomScreenNameCopiedSnack => '名前をコピーしました';

  @override
  String get roomScreenPinLimitSnack => 'ピン留めが多すぎます。先に1件解除してください';

  @override
  String get roomScreenPinFailedSnack => 'ピン留めできませんでした';

  @override
  String get roomScreenReportSentSnack => '通報を送信しました。相手には通知されません。';

  @override
  String get roomScreenDeselectMessageSemantic => 'メッセージの選択を解除';

  @override
  String get roomScreenSelectMessageSemantic => 'メッセージを選択';

  @override
  String roomScreenMemberCountBadge(Object count) {
    return 'メンバー$count人';
  }

  @override
  String roomScreenTtlSeconds(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count秒',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlMinutes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count分',
    );
    return '$_temp0';
  }

  @override
  String roomScreenTtlHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count時間',
    );
    return '$_temp0';
  }

  @override
  String roomScreenEphemeralNotice(Object ttl) {
    return 'このルームは一時的です。既読・未読を問わず、メッセージは$ttl後に消えます。';
  }

  @override
  String roomScreenThreadFoldCount(Object count) {
    return '$count件のメッセージ';
  }

  @override
  String get roomScreenSecretSpaceTitle => '秘密の空間';

  @override
  String get roomScreenSecretSpaceBody =>
      'このルームのメッセージは一時的です。ルームのセキュリティポリシーに基づき、自動的に削除されます。';

  @override
  String get roomScreenAutoDeleteTitle => '自動削除';

  @override
  String get roomScreenAutoDeleteVaries => '可変';

  @override
  String get roomScreenAutoDeleteTimed => 'タイマー制';

  @override
  String get roomScreenNoCaptureTitle => 'キャプチャ不可';

  @override
  String get roomScreenNoCaptureSubtitle => 'スクリーンショット禁止';

  @override
  String get roomScreenMorePrivacyTitle => 'さらに充実したプライバシー保護';

  @override
  String get roomScreenMorePrivacySubtitle =>
      'もとからあるプライバシー保護に加え、さらなるセキュリティ機能もご利用いただけます。';

  @override
  String get roomScreenNoMessagesTitle => 'メッセージがありません';

  @override
  String get roomScreenNoMessagesSubtitle => 'メッセージを送って会話を始めましょう';

  @override
  String get roomScreenViewProfilePictureSemantic => 'プロフィール写真を表示';

  @override
  String get roomScreenViewRoomPictureSemantic => 'ルーム写真を表示';

  @override
  String get messageBubbleFileFallbackName => '送信ファイル';

  @override
  String get messageBubbleAttachmentStatusFailed => '失敗';

  @override
  String get messageBubbleAttachmentStatusSending => '送信中…';

  @override
  String get messageBubbleViewOnceOpened => '開封済み';

  @override
  String get messageBubbleViewOnceExpired => '期限切れ';

  @override
  String get messageBubbleViewOnceLabel => '1回だけ表示';

  @override
  String get messageBubbleViewOnceTapToView => 'タップして表示';

  @override
  String get messageBubbleViewOncePhotoLabel => '写真';

  @override
  String get messageBubbleViewOnceSemanticLabel => '1回だけ表示の写真、タップして表示';

  @override
  String get messageBubbleRetrySendingSemanticLabel => '送信を再試行';

  @override
  String get messageBubbleDiscardSemanticLabel => '送信を破棄';

  @override
  String get profileScreenAccountSection => 'アカウント';

  @override
  String get profileScreenAddEmailPlaceholder => 'メールアドレスを追加';

  @override
  String get profileScreenAddEmailTitle => 'メールアドレスを追加しますか？';

  @override
  String get profileScreenAddNameTitle => '名前を追加しますか？';

  @override
  String profileScreenApprovalsCountWaiting(Object count) {
    return '$count件待機中';
  }

  @override
  String get profileScreenApprovalsLabel => '承認';

  @override
  String get profileScreenApprovalsNothingWaiting => '待機中なし';

  @override
  String get profileScreenApproveAction => '承認';

  @override
  String get profileScreenBlockAction => 'ブロック';

  @override
  String get profileScreenBlockedDmWiped => 'ブロックしてDMを削除しました。相手に通知されません。';

  @override
  String get profileScreenBlockedOnly => 'ブロックしました。相手に通知されません。';

  @override
  String get profileScreenBlockedUsers => 'ブロックしたユーザー';

  @override
  String get profileScreenCancelAction => 'キャンセル';

  @override
  String get profileScreenCancelRequestAction => 'リクエストを取り消す';

  @override
  String get profileScreenChangeAction => '変更';

  @override
  String get profileScreenChangeEmailTitle => 'メールアドレスを変更しますか？';

  @override
  String get profileScreenChangeNameTitle => '名前を変更しますか？';

  @override
  String get profileScreenChangeProfilePictureSemantic => 'プロフィール写真を変更';

  @override
  String get profileScreenChangeRecoveryPhrase => 'リカバリーフレーズを変更';

  @override
  String get profileScreenChooseFromLibrary => 'ライブラリから選択';

  @override
  String get profileScreenCouldNotSaveImage => '画像を保存できませんでした。';

  @override
  String get profileScreenDeleteAccount => 'アカウントを削除';

  @override
  String get profileScreenEmailHint => '任意（誰にも表示されません）';

  @override
  String get profileScreenEmailSectionLabel => 'メールアドレス';

  @override
  String get profileScreenErrorAlreadyFriends => 'すでにフレンドです。';

  @override
  String get profileScreenErrorGeneric => '実行できませんでした。';

  @override
  String get profileScreenErrorNotAccepting => '相手は現在、リクエストを受け付けていません。';

  @override
  String get profileScreenErrorRequestAlreadyReceived =>
      '相手からすでにリクエストが届いています。リクエストを確認してください。';

  @override
  String get profileScreenErrorRequestAlreadySent => 'すでにリクエストを送信済みです。';

  @override
  String get profileScreenErrorUnblockFirst =>
      'このユーザーをブロックしています。先にブロックを解除してください。';

  @override
  String get profileScreenErrorUserNotFound => '現在この操作はできません。';

  @override
  String get profileScreenNameNotSaved => '名前を保存できませんでした。もう一度お試しください。';

  @override
  String get profileScreenFamilyAddChild => 'お子様を追加';

  @override
  String profileScreenFamilyChildCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人のお子様',
    );
    return '$_temp0';
  }

  @override
  String get profileScreenFamilyLabel => 'ファミリー';

  @override
  String get profileScreenFriendsChip => 'フレンド';

  @override
  String get profileScreenGrownUpOnlyNote =>
      'これは保護者にしかできません。保護者のコードかパスワードが必要です。';

  @override
  String get profileScreenGuardiansCanSee =>
      '保護者は、あなたがオンラインかどうかや、誰と話しているかを見ることができます。';

  @override
  String get profileScreenHandPhoneBack => 'スマホを返す';

  @override
  String get profileScreenIncomingRequestChip => '受信リクエスト';

  @override
  String get profileScreenJustTappedAction => '誤タップ';

  @override
  String get settingsScreenSectionHelpAndLegal => 'ヘルプと法的情報';

  @override
  String get settingsScreenLicence => 'ライセンス';

  @override
  String get profileScreenLinkedAccountsLabel => '連携アカウント';

  @override
  String get profileScreenLinkedAccountsNone => '連携なし';

  @override
  String get profileScreenMyGrownUps => 'わたしの保護者';

  @override
  String get profileScreenNameHint => 'ルームでの見え方です';

  @override
  String get profileScreenChangeUsernameTitle => 'ユーザー名を変更しますか？';

  @override
  String get profileScreenChangeUsernameWarning =>
      'サインインに使う名前です。これからは新しい名前を入力します。古いユーザー名は解放され、他の人が取得できるようになります。また、30日間は再変更できません。あなたをメンションした過去のメッセージには古い名前が残ります。';

  @override
  String get profileScreenUsernameHint => '友だちがあなたを見つける名前';

  @override
  String profileScreenUsernameLockedUntil(String date) {
    return '$date に再変更できます';
  }

  @override
  String get profileScreenUsernamePasswordTitle => '本人確認';

  @override
  String get profileScreenUsernamePasswordAction => 'ユーザー名を変更';

  @override
  String get profileScreenUsernameProviderTitle => 'サインインで確認';

  @override
  String profileScreenUsernameChanged(String username) {
    return '@$username になりました。';
  }

  @override
  String get profileScreenUsernameNotSaved => 'ユーザー名を変更できませんでした。もう一度お試しください。';

  @override
  String get usernameStatusChecking => '確認中…';

  @override
  String get usernameStatusAvailable => '使えます';

  @override
  String get usernameStatusTaken => '使用済み';

  @override
  String get usernameStatusReserved => '使用できません';

  @override
  String get usernameStatusInvalid => '1〜32文字';

  @override
  String get usernameStatusUnknown => '確認できませんでした';

  @override
  String get profileScreenNobodyLookingAfter => 'まだこのアカウントを見守る保護者がいません';

  @override
  String get profileScreenNotAcceptingRequestsAction => 'リクエストを受け付けていません';

  @override
  String get profileScreenNotConnectedChip => '未接続';

  @override
  String get profileScreenOpenDmAction => 'DMを開く';

  @override
  String get profileScreenPhotoPermissionDenied => '写真へのアクセスが拒否されました。';

  @override
  String get settingsScreenPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get profileScreenPrivacySection => 'プライバシー';

  @override
  String get profileScreenProfilePictureTitle => 'プロフィール写真';

  @override
  String get profileScreenRedactedFriend => '一部の項目は本人の設定で非表示になっています。';

  @override
  String get profileScreenRedactedStranger => '限定表示中 — 友達にはもっと多く公開されています。';

  @override
  String get profileScreenReportAction => '報告';

  @override
  String get profileScreenReportSent => '報告を送信しました。相手に通知されることはありません。';

  @override
  String get profileScreenRequestPendingChip => '送信済みリクエスト';

  @override
  String get profileScreenSaveAction => '保存';

  @override
  String get profileScreenSavedToPhotos => '写真に保存しました。';

  @override
  String get profileScreenSaveToPhotos => '写真に保存';

  @override
  String get profileScreenSendRequestAction => 'リクエストを送る';

  @override
  String get profileScreenSetUpRecoveryPhrase => 'リカバリーフレーズを設定';

  @override
  String get profileScreenSignOut => 'ログアウト';

  @override
  String get profileScreenTakeSelfie => '自撮りを撮る';

  @override
  String get profileScreenTapAgainToConfirmDelete => 'もう一度タップして削除を確定';

  @override
  String get settingsScreenTermsOfService => '利用規約';

  @override
  String get profileScreenThisPhoneSection => 'このスマホ';

  @override
  String get profileScreenUnfriendAction => '友達解除';

  @override
  String get profileScreenViewProfilePictureSemantic => 'プロフィール写真を表示';

  @override
  String get profileScreenVisibilityPreferences => '公開設定';

  @override
  String get cameraEditorScreenCropPresetFree => 'フリー';

  @override
  String get cameraEditorScreenCropPresetOriginal => 'オリジナル';

  @override
  String get cameraEditorScreenCancelCropSemanticLabel => 'トリミングをキャンセル';

  @override
  String get cameraEditorScreenDiscardPhotoSemanticLabel => '写真を破棄';

  @override
  String get cameraEditorScreenUndoSemanticLabel => '元に戻す';

  @override
  String get cameraEditorScreenRedoSemanticLabel => 'やり直す';

  @override
  String get cameraEditorScreenResetCropSemanticLabel => 'トリミングをリセット';

  @override
  String get cameraEditorScreenRotateSemanticLabel => '回転';

  @override
  String get cameraEditorScreenCropSemanticLabel => 'トリミング';

  @override
  String get cameraEditorScreenHeicUnsupportedMessage =>
      'このブラウザではHEIC形式の写真を開けません';

  @override
  String get cameraEditorScreenImageLoadFailedMessage => 'この画像を開けませんでした';

  @override
  String get cameraEditorScreenCropDoneButton => '完了';

  @override
  String get cameraEditorScreenRetakeSemanticLabel => '撮り直す';

  @override
  String get cameraEditorScreenPenPutAwaySemanticLabel => 'ペンをしまう';

  @override
  String get cameraEditorScreenPenDrawSemanticLabel => '写真に描く';

  @override
  String get cameraEditorScreenSendingButton => '送信中…';

  @override
  String get cameraEditorScreenSendButton => '送信';

  @override
  String get cameraEditorScreenViewOnceNote => '一度開くと消えます';

  @override
  String get cameraEditorScreenClearDrawingSemanticLabel => '描画を消去';

  @override
  String get cameraEditorScreenViewOnceOnSemanticLabel => '一度だけ表示：オン';

  @override
  String get cameraEditorScreenViewOnceOffSemanticLabel => '一度だけ表示：オフ';

  @override
  String get cameraEditorScreenHdOnSemanticLabel => 'HD: オン';

  @override
  String get cameraEditorScreenHdOffSemanticLabel => 'HD: オフ';

  @override
  String get cameraEditorScreenHdNote => 'フル解像度で送信します';

  @override
  String get cameraEditorScreenInkColorSemanticLabel => 'インクの色';

  @override
  String get glassScreenPanelLooks => 'ルック';

  @override
  String get glassScreenPanelBottomBar => 'ボトムバー';

  @override
  String get glassScreenPanelOtherSurfaces => 'その他の要素';

  @override
  String get glassScreenPanelBarLayout => 'バーのレイアウト';

  @override
  String get glassScreenTitle => 'ガラス.';

  @override
  String get glassScreenSubtitle => '背景がどれくらい透けて見えるか';

  @override
  String glassScreenSaveSlotsFull(Object max) {
    return '全$maxスロット使用中';
  }

  @override
  String get glassScreenSaveCurrentAs => '名前を付けて保存…';

  @override
  String get glassScreenResetEveryDial => 'すべてのダイヤルをリセット';

  @override
  String glassScreenResetToPreset(Object name) {
    return '$nameにリセット';
  }

  @override
  String get glassScreenSurfacesNote =>
      '入力欄、ヘッダー、通話ボタンなど、スクロールするコンテンツではなくテキストの上に重なる要素';

  @override
  String get glassScreenMatchBottomBar => 'ボトムバーに合わせる';

  @override
  String get glassScreenPresetEditedSubtitle =>
      '編集済み — 新しいルックとして保存するか、リセットしてください';

  @override
  String get glassScreenCustomPresetName => 'カスタム';

  @override
  String get glassScreenUnsavedSubtitle => '未保存 — 名前をつけると保存されます';

  @override
  String get glassScreenSaveDialogTitle => 'この見た目に名前を付けて保存';

  @override
  String get glassScreenNoRoomToast => '空きがありません — 先に見た目を削除してください';

  @override
  String get glassScreenRenameDialogTitle => '名前を変更';

  @override
  String glassScreenDeleteConfirmTitle(Object name) {
    return '$nameを削除しますか？';
  }

  @override
  String get glassScreenDeleteConfirmBody => '見た目はそのまま残ります。名前がなくなるだけです。';

  @override
  String get glassScreenKeepButton => '残す';

  @override
  String get glassScreenDeleteButton => '削除';

  @override
  String get glassScreenNameHint => '深夜';

  @override
  String get glassScreenCancelButton => 'キャンセル';

  @override
  String get glassScreenSaveButton => '保存';

  @override
  String get glassScreenPreviewRoomName => '# ベランダ';

  @override
  String get glassScreenPreviewOnlineCount => '4人がオンライン';

  @override
  String get glassScreenPreviewMessageHint => 'メッセージ';

  @override
  String get glassScreenPreviewCollapseLabel => 'プレビューを折りたたむ';

  @override
  String get glassScreenPreviewExpandLabel => 'プレビューを展開する';

  @override
  String get glassScreenPreviewBadge => 'プレビュー';

  @override
  String get glassScreenBuiltInLabel => '標準';

  @override
  String glassScreenOverwriteTooltip(Object name) {
    return '$nameを上書き';
  }

  @override
  String glassScreenRenameTooltip(Object name) {
    return '$nameの名前を変更';
  }

  @override
  String glassScreenDeleteTooltip(Object name) {
    return '$nameを削除';
  }

  @override
  String glassScreenResetTooltip(Object label) {
    return '$labelをリセット';
  }

  @override
  String get glassScreenBackdropMsgDilan => '屋根の写真送ったよ、タイルが全部割れてた';

  @override
  String get glassScreenBackdropMsgMert => '了解。でも結局スピーカーは誰が持ってくるの？';

  @override
  String get glassScreenBackdropGroupFamily => '家族';

  @override
  String get glassScreenBackdropMsgFamily => 'ママ: 夕飯は8時、また遅れないでね';

  @override
  String get glassScreenBackdropMsgZeynep => '外にいるよ';

  @override
  String get glassScreenBackdropMsgKerem => 'あの角の店、コーヒーうまいよ';

  @override
  String get glassScreenBackdropGroupWork => '仕事';

  @override
  String get glassScreenBackdropMsgWork => '朝会、今週の残りは10:30スタートに変更だよ';

  @override
  String get glassScreenBackdropMsgElif => 'うそ、もう一回送って。なくしちゃった';

  @override
  String get glassScreenBackdropMsgBaran => '着いた👍';

  @override
  String get glassScreenBackdropMsgAyse => '猫、ベランダのドア開けられるようになったよ';

  @override
  String get glassScreenBackdropMsgCan => 'じゃあ土曜日にね';

  @override
  String replyIndicatorInReplyToSemanticLabel(Object name) {
    return '$nameへの返信';
  }

  @override
  String get replyIndicatorViewOnceLabel => '写真・一度だけ表示';

  @override
  String get replyIndicatorVoiceMessageLabel => 'ボイスメッセージ';

  @override
  String get replyIndicatorDocumentLabel => 'ドキュメント';

  @override
  String get replyIndicatorMessageRemoved => 'メッセージは削除されました';

  @override
  String get threadOverlayMessageNotFound => 'このスレッドにそのメッセージが見つかりませんでした';

  @override
  String get threadOverlayReplyTargetNotFound => '返信先のスレッドが見つかりませんでした';

  @override
  String get threadOverlayStillSending => 'まだ送信中です。少し待ってから試してください';

  @override
  String get threadOverlayCopiedToast => 'コピーしました';

  @override
  String get threadOverlayNameCopiedToast => '名前をコピーしました';

  @override
  String get threadOverlayCoordinatesCopiedToast => '座標をコピーしました';

  @override
  String get threadOverlayPinLimitToast => 'ピン留めが多すぎます。先に1つ解除してください';

  @override
  String get threadOverlayPinFailedToast => 'ピン留めできませんでした';

  @override
  String get threadOverlayReportedToast => '報告しました';

  @override
  String get threadOverlayUnavailable => 'スレッドは利用できません';

  @override
  String get roomInfoScreenNameRequiredError => '名前を入力してください';

  @override
  String get roomInfoScreenPasswordClearedSnackbar => 'パスワードを削除しました';

  @override
  String get roomInfoScreenLeaveConfirmTitle => 'ルームを退出しますか?';

  @override
  String get roomInfoScreenLeaveConfirmBody => 'ルームがオープンなままなら、また参加できます。';

  @override
  String get roomInfoScreenLeaveConfirmButton => '退出';

  @override
  String get roomInfoScreenDeleteConfirmTitle => 'ルームを削除しますか?';

  @override
  String get roomInfoScreenDeleteConfirmBody => 'ここにあるメッセージもすべて削除されます。元に戻せません。';

  @override
  String get roomInfoScreenDeleteConfirmButton => '削除';

  @override
  String get roomInfoScreenEndConversationConfirmTitle => 'この会話を終了しますか?';

  @override
  String roomInfoScreenEndConversationConfirmBody(String peerName) {
    return '$peerNameもこの会話を失います — お互いのメッセージがすべて消えます。元に戻せません。';
  }

  @override
  String get roomInfoScreenEndConversationConfirmButton => '終了';

  @override
  String get roomInfoScreenEndConversationPeerFallback => '相手';

  @override
  String get roomInfoScreenConfirmCancelButton => 'キャンセル';

  @override
  String get roomInfoScreenErrorRoomExists => 'その名前のルームはすでに存在します';

  @override
  String get roomInfoScreenErrorNotOwner => 'オーナーのみ操作できます';

  @override
  String get roomInfoScreenErrorNotAuthorized => '権限がありません';

  @override
  String get roomInfoScreenErrorRoomNotFound => 'このルームはもうありません';

  @override
  String get roomInfoScreenRoomGone => 'ルームがありません';

  @override
  String get roomInfoScreenNameLabel => '名前';

  @override
  String get roomInfoScreenNameHint => 'ルーム名';

  @override
  String get roomInfoScreenDescriptionLabel => '説明';

  @override
  String get roomInfoScreenDescriptionHint => 'ルームについて一言';

  @override
  String get roomInfoScreenVisibilityLabel => '公開設定';

  @override
  String get roomInfoScreenPublicTitle => '公開';

  @override
  String get roomInfoScreenPublicSub => '誰でも見つけられる';

  @override
  String get roomInfoScreenPrivateTitle => '非公開';

  @override
  String get roomInfoScreenPrivateSub => '招待制';

  @override
  String get roomInfoScreenMessageLifeLabel => 'メッセージ寿命';

  @override
  String roomInfoScreenTtlSeconds(Object value) {
    return '$value秒';
  }

  @override
  String roomInfoScreenTtlMinutes(Object value) {
    return '$value分';
  }

  @override
  String roomInfoScreenTtlHours(Object value) {
    return '$value時間';
  }

  @override
  String get roomInfoScreenPasswordLabel => 'パスワード';

  @override
  String get roomInfoScreenLockedBadge => 'ロック中';

  @override
  String get roomInfoScreenNoneBadge => 'なし';

  @override
  String get roomInfoScreenPasswordProtectedNote =>
      'このルームはパスワードで保護されています。セキュリティ上の理由により、既存のパスフレーズは表示されません。置き換えるには新しいパスフレーズを入力してください。';

  @override
  String get roomInfoScreenReplacePasswordHint => 'パスフレーズを置き換え';

  @override
  String get roomInfoScreenSetPasswordHint => 'パスフレーズでロック';

  @override
  String get roomInfoScreenRemovePasswordButton => 'パスワードを削除';

  @override
  String get roomInfoScreenSharedContentLabel => '共有コンテンツ';

  @override
  String roomInfoScreenMembersLabel(Object count) {
    return 'メンバー・$count';
  }

  @override
  String get roomInfoScreenLeavingButton => '退出中…';

  @override
  String get roomInfoScreenLeaveRoomButton => 'ルームを退出';

  @override
  String get roomInfoScreenDeletingButton => '削除中…';

  @override
  String get roomInfoScreenDeleteButtonLabel => '削除';

  @override
  String get roomInfoScreenEndingConversationButton => '終了中…';

  @override
  String get roomInfoScreenEndConversationButton => '会話を終了';

  @override
  String get roomInfoScreenHeaderConversation => '会話';

  @override
  String get roomInfoScreenHeaderRoomSettings => 'ルーム設定';

  @override
  String get roomInfoScreenViewProfilePictureSemantic => 'プロフィール写真を表示';

  @override
  String get roomInfoScreenViewRoomPictureSemantic => 'ルームの写真を表示';

  @override
  String get roomInfoScreenChangeRoomPictureSemantic => 'ルームの写真を変更';

  @override
  String get roomInfoScreenAddRoomPictureSemantic => 'ルームの写真を追加';

  @override
  String get roomInfoScreenOwnerBadge => 'オーナー';

  @override
  String get roomInfoScreenNoneCount => 'なし';

  @override
  String get cameraScreenAccessDeniedMessage =>
      'カメラへのアクセスがオフになっています。\n写真を撮るには設定でオンにしてください。';

  @override
  String get cameraScreenOpeningSystemCamera => 'システムカメラを起動中…';

  @override
  String get cameraScreenCloseButtonLabel => 'カメラを閉じる';

  @override
  String get cameraScreenLowLightBoostOnLabel => '低照度ブースト：オン';

  @override
  String get cameraScreenLowLightBoostOffLabel => '低照度ブースト：オフ';

  @override
  String cameraScreenFlashStatusLabel(Object mode) {
    return 'フラッシュ: $mode';
  }

  @override
  String get cameraScreenChooseFromLibraryLabel => 'ライブラリから選択';

  @override
  String get cameraScreenSwitchCameraLabel => 'カメラを切り替え';

  @override
  String get cameraScreenTakePhotoLabel => '写真を撮る';

  @override
  String get childPolicyScreenAddByUsernameLabel => 'ユーザー名で追加';

  @override
  String get childPolicyScreenAddCta => '追加';

  @override
  String childPolicyScreenAddGuardianBlurb(Object name) {
    return 'あなたとまったく同じ権限を持つことになります——承認待ちのリクエストすべて、変更できる設定すべて、そしてあなたを削除する権限も。$nameはその人をすぐに家族として認識します。';
  }

  @override
  String get childPolicyScreenAddGuardianHeading => '保護者を追加';

  @override
  String get childPolicyScreenAddGuardianHint => '相手のユーザー名';

  @override
  String get childPolicyScreenAllowCta => '許可';

  @override
  String childPolicyScreenAllowSomeoneBlurb(Object childName) {
    return '$childNameがその人を追加しても、その人が$childNameを追加しても、今後確認を求められることはありません。';
  }

  @override
  String get childPolicyScreenAllowSomeoneHeading => '相手を許可';

  @override
  String get childPolicyScreenAskToAddLabel => '追加をリクエスト';

  @override
  String get childPolicyScreenAskToAddOffDesc => '家族のみ — 新規リクエストなし';

  @override
  String get childPolicyScreenAskToAddOnDesc => '新しい人について保護者に確認できます';

  @override
  String get childPolicyScreenBothFinalNote =>
      'どちらも取り消せない操作です。保護者から抜けるだけなら、「保護者」セクションから行えます。';

  @override
  String get childPolicyScreenCallsLabel => '通話';

  @override
  String get childPolicyScreenCallsOffDesc => 'メッセージのみ';

  @override
  String get childPolicyScreenCallsOnDesc => '許可された相手との音声・ビデオ通話';

  @override
  String get childPolicyScreenCancelLabel => 'キャンセル';

  @override
  String get childPolicyScreenCancelSemanticLabel => 'キャンセル';

  @override
  String get childPolicyScreenContactAddedRequestSent => '追加しました — リクエストを送信中です';

  @override
  String get childPolicyScreenContactAddedToList => '許可リストに追加しました';

  @override
  String get childPolicyScreenCreateRoomsLabel => 'ルーム作成';

  @override
  String get childPolicyScreenCreateRoomsOffDesc => 'ルームを作成できません';

  @override
  String get childPolicyScreenCreateRoomsOnDesc => '自分専用の非公開ルームを作成できます';

  @override
  String get childPolicyScreenDeleteAccountBody =>
      'メッセージ、写真、ルーム、フレンド——すべてが削除されます。この操作は取り消せず、ユーザー名は誰でも使えるようになります。';

  @override
  String get childPolicyScreenDeleteAccountFailed =>
      'アカウントを削除できませんでした — もう一度お試しください';

  @override
  String childPolicyScreenDeleteAccountHeadline(Object name) {
    return '$nameのアカウントを削除しますか?';
  }

  @override
  String get childPolicyScreenDeleteDangerDetail =>
      'メッセージ、写真、ルーム、フレンドがすべて削除されます。取り消せません。';

  @override
  String childPolicyScreenDeleteDangerLabel(Object name) {
    return '$nameのアカウントを削除';
  }

  @override
  String get childPolicyScreenDeleteForeverCta => '完全に削除';

  @override
  String get childPolicyScreenErrorAddContactGeneric =>
      '追加できませんでした — もう一度お試しください';

  @override
  String get childPolicyScreenErrorCannotAddSelf => 'それは本人のユーザー名です';

  @override
  String get childPolicyScreenErrorChildNotAllowed => 'お子様は保護者になれません';

  @override
  String get childPolicyScreenErrorGenericGuardian => 'できませんでした。もう一度お試しください';

  @override
  String get childPolicyScreenErrorLastGuardian =>
      'だれかがこの子を見守る必要があります。先に別の保護者を追加してください';

  @override
  String get childPolicyScreenErrorNotYours => 'これはあなたが変更できるものではありません';

  @override
  String get childPolicyScreenErrorUserNotFound => 'そのユーザー名のアカウントが見つかりません';

  @override
  String get childPolicyScreenGraduateBlurb =>
      'このパスワードで通常のアカウントになり、保護者は全員、この子の情報が一切見えなくなります。元には戻せません。以後はほかの人と同じように招待してもらう必要があります。';

  @override
  String get childPolicyScreenGraduateCta => '卒業させる';

  @override
  String get childPolicyScreenGraduateDangerDetail =>
      'データはそのまま残り、パスワードが設定されます。あなたは何も見られなくなります。元には戻せません。';

  @override
  String get childPolicyScreenGraduateDangerLabel => '通常アカウントに卒業させる';

  @override
  String get childPolicyScreenGraduateFailed => '卒業させられませんでした。もう一度お試しください';

  @override
  String childPolicyScreenGraduateHeading(Object name) {
    return '$nameを卒業させる';
  }

  @override
  String get childPolicyScreenGraduateHint => 'この子のパスワード';

  @override
  String get childPolicyScreenGrantsFooterNote =>
      'ルームの許可を取り消すと、その子もルームから退出させられます。相手の許可を取り消すと、そのチャットも両方から削除されます。';

  @override
  String get childPolicyScreenGrownUpsDesc =>
      'ここにいる全員が承認や設定変更、すべての閲覧ができます。誰でも単独で操作でき、ほかの人の許可を待つ必要はありません。';

  @override
  String get childPolicyScreenGuardianAdded => '追加しました。これでこの子を見守れます';

  @override
  String childPolicyScreenGuardianRemoved(Object name) {
    return '$nameを削除しました';
  }

  @override
  String childPolicyScreenGuardianYouSuffix(Object name) {
    return '$name（自分）';
  }

  @override
  String get childPolicyScreenLoading => '読み込み中…';

  @override
  String get childPolicyScreenLockedLabel => 'ロック';

  @override
  String get childPolicyScreenMediaLabel => '写真+音声';

  @override
  String get childPolicyScreenMediaOffDesc => 'テキストのみ';

  @override
  String get childPolicyScreenMediaOnDesc => '写真・動画・ボイスメッセージを送れます';

  @override
  String get childPolicyScreenNoRoomsYet => 'まだルームがありません';

  @override
  String get childPolicyScreenPeopleAllowedDesc =>
      'ここにいる相手となら、どちらが始めても改めて確認せず追加できます。';

  @override
  String get childPolicyScreenPublicRoomsBody =>
      'お子様の場合は常にオフです。「見つける」（知らない人が持つルームの一覧）は完全に非表示になり、オンにすることはできません。誰かから招待されたルームは今まで通り利用できます。';

  @override
  String get childPolicyScreenPublicRoomsLabel => '公開ルーム';

  @override
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian) {
    return '$guardianは今後、$childに関する内容を閲覧・承認できなくなります。';
  }

  @override
  String childPolicyScreenRemoveGuardianHeadline(Object name) {
    return '$nameを削除しますか？';
  }

  @override
  String get childPolicyScreenRemoveLabel => '削除';

  @override
  String childPolicyScreenRoomMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人',
    );
    return '$_temp0';
  }

  @override
  String get childPolicyScreenSectionGrownUps => '保護者';

  @override
  String get childPolicyScreenSectionPeopleAllowed => '許可した相手';

  @override
  String get childPolicyScreenSectionRoomsAllowed => '許可したルーム';

  @override
  String get childPolicyScreenSectionWhatTheyCanDo => 'できること';

  @override
  String get childPolicyScreenSectionWhenDone => '利用を終えるとき';

  @override
  String get childPolicyScreenSendNowOffDesc => 'どちらかが相手を追加するまで何も起きません';

  @override
  String get childPolicyScreenSendNowOnDesc => '相手にはすぐにリクエストが届きます';

  @override
  String get childPolicyScreenSendRequestNowLabel => '今すぐリクエストを送る';

  @override
  String childPolicyScreenSoleGuardianNote(Object name) {
    return '$nameさんの保護者はあなたしかいないので、このまま抜けることはできません。先に別の保護者を追加するか、こちらのいずれかをお使いください。';
  }

  @override
  String get childPolicyScreenStepAwayLabel => '抜ける';

  @override
  String childPolicyScreenStopSupervisingBody(Object name) {
    return '$nameさんのアカウントの様子が一切わからなくなります。リクエストも、つながっている相手も、ルームも。ほかの保護者が引き続き見守ります。';
  }

  @override
  String get childPolicyScreenStopSupervisingCta => '見守りをやめる';

  @override
  String get childPolicyScreenStopSupervisingHeadline => '見守りをやめますか?';

  @override
  String get childPolicyScreenTakeBackFailed => '取り消せませんでした。もう一度お試しください。';

  @override
  String get childPolicyScreenTakeBackLabel => '取り消す';

  @override
  String get childPolicyScreenUsernameHint => 'ユーザー名';

  @override
  String get childPolicyScreenYou => 'あなた';

  @override
  String get roomContentScreenDefaultDocumentName => 'ドキュメント';

  @override
  String get roomContentScreenCouldntOpenFile => 'そのファイルを開けませんでした';

  @override
  String get roomContentScreenCouldntShare => '共有できませんでした';

  @override
  String roomContentScreenLinksCopied(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のリンクをコピーしました',
    );
    return '$_temp0';
  }

  @override
  String roomContentScreenDeleteHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のメッセージを削除',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenDeleteBody => 'このチャットにいる全員から削除されます。元に戻すことはできません。';

  @override
  String get roomContentScreenDeleteForEveryone => '全員から削除';

  @override
  String get roomContentScreenCancelTooltip => 'キャンセル';

  @override
  String get roomContentScreenBackTooltip => '戻る';

  @override
  String get roomContentScreenSelectingLabel => '選択中';

  @override
  String get roomContentScreenSharedContentLabel => '共有コンテンツ';

  @override
  String roomContentScreenSelectionCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件選択中',
      zero: '未選択',
    );
    return '$_temp0';
  }

  @override
  String get roomContentScreenSelectAllLabel => '選択';

  @override
  String get roomContentScreenSelectAllActiveLabel => 'すべて';

  @override
  String get roomContentScreenEmptyMedia => 'まだ写真や動画はありません';

  @override
  String get roomContentScreenEmptyFiles => 'まだファイルはありません';

  @override
  String get roomContentScreenEmptyVoice => 'まだボイスメッセージはありません';

  @override
  String get roomContentScreenEmptyLinks => 'まだリンクはありません';

  @override
  String get roomContentScreenEmptySaved =>
      'まだ何も保存されていません。メッセージを長押しして「保存」を選んでください。\n\nここに保存したものはあなただけに見えます。ピン留めしたメッセージはルーム全員に見えます。';

  @override
  String get roomContentScreenLoadFailed => '読み込めませんでした';

  @override
  String roomContentScreenVoiceMessageFrom(Object name) {
    return '$nameさんからのボイスメッセージ';
  }

  @override
  String get roomContentScreenForwardAction => '転送';

  @override
  String get roomContentScreenCopyAction => 'コピー';

  @override
  String get roomContentScreenSaveAction => '保存';

  @override
  String get roomContentScreenShareAction => '共有';

  @override
  String get roomContentScreenInChatAction => 'チャットで見る';

  @override
  String get roomContentScreenDeleteAction => '削除';

  @override
  String get messageActionMenuReplyLabel => '返信';

  @override
  String get messageActionMenuEditLabel => '編集';

  @override
  String get messageStampEditedLabel => '編集済み';

  @override
  String get composerEditCardTitle => 'メッセージを編集';

  @override
  String get spoilerRevealHint => 'スポイラー。有効にすると隠されたテキストが表示されます';

  @override
  String get formatToolbarFormatLabel => 'フォーマット';

  @override
  String get formatToolbarBoldLabel => '太字';

  @override
  String get formatToolbarItalicLabel => '斜体';

  @override
  String get formatToolbarStrikethroughLabel => '取り消し線';

  @override
  String get formatToolbarUnderlineLabel => '下線';

  @override
  String get formatToolbarSpoilerLabel => 'スポイラー';

  @override
  String get formatToolbarLinkLabel => 'リンク';

  @override
  String get formatToolbarCodeLabel => 'コード';

  @override
  String get linkInputSheetTitle => 'リンク';

  @override
  String get linkInputSheetHint => 'https://example.com';

  @override
  String get linkInputSheetApplyLabel => 'リンクを適用';

  @override
  String get linkInputSheetApplySub => '選択したテキストをタップするとこのアドレスが開きます';

  @override
  String get linkInputSheetRemoveLabel => 'リンクを削除';

  @override
  String get linkConfirmSheetTitle => 'このリンクを開きますか？';

  @override
  String get linkConfirmSheetOpenLabel => 'リンクを開く';

  @override
  String get linkConfirmSheetCancelLabel => 'キャンセル';

  @override
  String get roomScreenEditExpiredSnack =>
      '編集できる時間を過ぎました。メッセージを編集できるのは15分以内です。';

  @override
  String get roomScreenEditFailedSnack => '編集を保存できませんでした。接続を確認してもう一度お試しください。';

  @override
  String get messageActionMenuForwardLabel => '転送';

  @override
  String get messageActionMenuViewThreadLabel => 'スレッドを見る';

  @override
  String get messageActionMenuCopyLabel => 'コピー';

  @override
  String get messageActionMenuCopyNameLabel => 'ファイル名をコピー';

  @override
  String get messageActionMenuCopyCoordinatesLabel => '座標をコピー';

  @override
  String get messageActionMenuPinLabel => 'ピン留め';

  @override
  String get messageActionMenuUnpinLabel => 'ピン留め解除';

  @override
  String get messageActionMenuSelectLabel => '選択';

  @override
  String get messageActionMenuProfileLabel => 'プロフィール';

  @override
  String get messageActionMenuDeleteLabel => '削除';

  @override
  String get messageActionMenuReportLabel => '通報';

  @override
  String get themeScreenTitle => 'テーマ。';

  @override
  String get themeScreenTapToApplyHint => 'タップで適用 · ⛶で全画面プレビュー';

  @override
  String get themeScreenFamilyBasicName => 'ベーシック';

  @override
  String get themeScreenFamilyBasicTagline => 'iOS風 · 5パレット';

  @override
  String get themeScreenFamilyVaultName => 'ヴォールト';

  @override
  String get themeScreenFamilyVaultTagline => '極秘ファイル · ノワール+アイボリー';

  @override
  String get themeScreenFamilyOthersName => 'その他';

  @override
  String get themeScreenFamilyOthersTagline => '個性的なムード';

  @override
  String get themeScreenActiveBadge => '適用中';

  @override
  String get themeScreenTapToApplyLabel => 'タップで適用';

  @override
  String themeScreenCarouselActiveLabel(Object name) {
    return '適用中 — $name';
  }

  @override
  String themeScreenCarouselApplyLabel(Object name) {
    return '$nameを適用';
  }

  @override
  String get themeScreenPreviewGreeting => 'やあ、きみ。';

  @override
  String get themeScreenPreviewSectionLabel => '会話';

  @override
  String get themeScreenPreviewRoomOneName => 'デザイン部';

  @override
  String get themeScreenPreviewRoomOneSub => 'mia: 新しいタイルをリリースしたよ。';

  @override
  String get themeScreenPreviewRoomTwoName => 'チェンバー · ☾';

  @override
  String get themeScreenPreviewRoomTwoSub => '4時間で封印。';

  @override
  String get themeScreenPreviewBubbleQuestion => 'この感じ、どう?';

  @override
  String get themeScreenPreviewBubbleAnswer => 'これが正解、って感じ。';

  @override
  String get callScreenVideoCallLabel => '着信ビデオ通話';

  @override
  String get callScreenVoiceCallLabel => '着信音声通話';

  @override
  String callScreenStatusRinging(Object kind) {
    return '$kind・発信中…';
  }

  @override
  String callScreenStatusIncoming(Object kind) {
    return '$kind・着信中';
  }

  @override
  String callScreenStatusConnecting(Object kind) {
    return '$kind・接続中…';
  }

  @override
  String get callScreenStatusConnected => '接続済み';

  @override
  String get callScreenStatusEnded => '通話終了';

  @override
  String get callScreenStatusFailed => '通話失敗';

  @override
  String get callScreenStatusSwitching => 'デバイスを切り替え中…';

  @override
  String get callScreenStatusMoved => '移動済み';

  @override
  String get callScreenStatusReconnecting => '再接続中…';

  @override
  String get callScreenPoorConnectionLabel => '接続不良';

  @override
  String get callScreenWeakConnectionLabel => '接続不安定';

  @override
  String get callScreenControlUnmute => 'ミュート解除';

  @override
  String get callScreenControlMute => 'ミュート';

  @override
  String get callScreenControlCamOn => 'カメラON';

  @override
  String get callScreenControlCamOff => 'カメラOFF';

  @override
  String get callScreenControlFlip => '切替';

  @override
  String get callScreenControlSpeaker => 'スピーカー';

  @override
  String get callScreenControlEnd => '終了';

  @override
  String get linkPreviewCardLinkLabel => 'リンク';

  @override
  String friendRequestDraftScreenAcceptedSnackbar(Object name) {
    return '$nameさんがリクエストを承認しました';
  }

  @override
  String get friendRequestDraftScreenWithdrawnSnackbar => 'そのリクエストは取り消されました';

  @override
  String get friendRequestDraftScreenDeclinedSnackbar => 'リクエストが拒否されました';

  @override
  String get friendRequestDraftScreenErrorBlocked =>
      'このユーザーをブロックしています。先にブロックを解除してください。';

  @override
  String get friendRequestDraftScreenErrorNotAccepting =>
      '相手は現在フレンドリクエストを受け付けていません。';

  @override
  String get friendRequestDraftScreenErrorSendFailed =>
      '送信できませんでした。もう一度お試しください。';

  @override
  String get friendRequestDraftScreenIncomingRequestLabel => '受信リクエスト';

  @override
  String get friendRequestDraftScreenNewRequestLabel => '送信リクエスト';

  @override
  String friendRequestDraftScreenIntroIncoming(Object name) {
    return '$nameさんがあなたと話したがっています。';
  }

  @override
  String get friendRequestDraftScreenIntroOutgoing =>
      '簡単なメッセージを送りましょう。相手は承認か拒否かを選べます。';

  @override
  String get friendRequestDraftScreenIntroFooter =>
      '双方が同意するまで、ここでの内容はどこにも保存されません。';

  @override
  String get friendRequestDraftScreenRoomTypeLabel => 'ルームタイプ';

  @override
  String get friendRequestDraftScreenRoomTypeEphemeral => '自動消滅';

  @override
  String get friendRequestDraftScreenRoomTypeStandard => '標準';

  @override
  String get friendRequestDraftScreenLifetimeLabel => '有効期限';

  @override
  String friendRequestDraftScreenDurationSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String friendRequestDraftScreenDurationMinutes(Object minutes) {
    return '$minutes分';
  }

  @override
  String friendRequestDraftScreenDurationHours(Object hours) {
    return '$hours時間';
  }

  @override
  String get friendRequestDraftScreenHintWhisperOptional => '最初の一言をささやく・任意';

  @override
  String get friendRequestDraftScreenHintFirstMessageOptional =>
      '最初のメッセージを追加・任意';

  @override
  String get friendRequestDraftScreenHintWhisperFades => 'ささやき・自動で消える';

  @override
  String get friendRequestDraftScreenHintStartWith => '何か話しかけてみよう';

  @override
  String get friendRequestDraftScreenApproveButton => '承認してルームを開く';

  @override
  String get friendRequestDraftScreenDeclineButton => '断る';

  @override
  String get friendRequestDraftScreenCancelRequestButton => 'リクエストを取り消す';

  @override
  String get friendRequestDraftScreenAskGrownUpButton => '保護者に相談';

  @override
  String get friendRequestDraftScreenSendRequestButton => 'リクエストを送信';

  @override
  String get discoverScreenTitle => 'さがす。';

  @override
  String get discoverScreenCaptionPeople => 'ひと';

  @override
  String get discoverScreenCaptionRooms => 'ルーム';

  @override
  String get discoverScreenCaptionRequests => 'リクエスト';

  @override
  String get discoverScreenPeopleBandLabel => 'ひと';

  @override
  String get discoverScreenRoomsBandLabel => 'ルーム';

  @override
  String get discoverScreenFindPeopleTitle => '人をさがす';

  @override
  String get discoverScreenFindPeopleSubtitleChild => 'ユーザー名を全部入力';

  @override
  String get discoverScreenFindPeopleSubtitleAdult => '@ユーザー名か名前で検索';

  @override
  String get discoverScreenRequestsSectionLabel => 'リクエスト';

  @override
  String get discoverScreenInboxQuiet => '受信リクエストなし';

  @override
  String get discoverScreenNothingPending => '送信リクエストなし';

  @override
  String get discoverScreenYourPeopleLabel => '友だち';

  @override
  String get discoverScreenNoFriendsYetWithHint => 'まだ誰もいない — 上で人をさがそう';

  @override
  String get discoverScreenNoFriendsYet => 'まだ誰もいない';

  @override
  String get discoverScreenSearchRoomsTitle => 'ルームをさがす';

  @override
  String get discoverScreenSearchRoomsSubtitle => '名前で公開ルームをさがす';

  @override
  String get discoverScreenYourRoomsLabel => 'ルーム';

  @override
  String get discoverScreenNoRoomsYet => 'まだルームがない';

  @override
  String get discoverScreenIncomingLabel => '受信';

  @override
  String get discoverScreenOutgoingLabel => '送信';

  @override
  String get discoverScreenIncomingLabelCaps => '受信';

  @override
  String get discoverScreenOutgoingLabelCaps => '送信';

  @override
  String get discoverScreenJumpPeopleLabel => 'ユーザー';

  @override
  String get discoverScreenJumpRoomsLabel => 'ルーム';

  @override
  String discoverScreenJumpToSemanticLabel(Object label) {
    return '$labelへジャンプ';
  }

  @override
  String get imageCropScreenDefaultTitle => '調整';

  @override
  String get imageCropScreenDefaultConfirmLabel => '写真を使用';

  @override
  String get imageCropScreenSavingButton => '保存中…';

  @override
  String get imageCropScreenCancelButton => 'キャンセル';

  @override
  String get imageCropScreenHeicUnsupported => 'このブラウザではHEIC形式の写真を開けません';

  @override
  String get imageCropScreenLoadFailed => 'この画像を開けませんでした';

  @override
  String get imageCropScreenHintCircle => 'ドラッグで移動、ピンチでズーム';

  @override
  String get imageCropScreenHintRect => 'ドラッグとピンチで調整';

  @override
  String get loginScreenSignInHeroMuted => 'また\n';

  @override
  String get loginScreenSignInHeroInk => 'おかえり。';

  @override
  String get loginScreenSignInFirstHeroMuted => 'はじめまして\n';

  @override
  String get loginScreenSignInFirstHeroInk => 'ようこそ。';

  @override
  String get loginScreenSignInCta => 'ログイン';

  @override
  String get loginScreenSignUpHeroMuted => '新しい\n';

  @override
  String get loginScreenSignUpHeroInk => '顔。';

  @override
  String get loginScreenSignUpCta => 'アカウント開設';

  @override
  String get loginScreenResetHeroMuted => 'リセット\n';

  @override
  String get loginScreenResetHeroInk => 'パスワード。';

  @override
  String get loginScreenResetCta => 'パスワードをリセット';

  @override
  String get loginScreenErrorPasswordsDontMatch => 'パスワードが一致しません。';

  @override
  String get loginScreenErrorChoosePasswordFirst => '先にパスワードを入力してください。';

  @override
  String get loginScreenUsernameHint => 'ユーザー名';

  @override
  String get loginScreenPasswordHint => 'パスワード';

  @override
  String get loginScreenConfirmPasswordHint => 'パスワード（確認用）';

  @override
  String get loginScreenNameOptionalHint => '名前（任意）';

  @override
  String get loginScreenRecoveryPhraseHint => '12単語のリカバリーフレーズ';

  @override
  String get loginScreenNewPasswordHint => '新しいパスワード';

  @override
  String get loginScreenBackToSignIn => '← ログインに戻る';

  @override
  String get loginScreenForgotPassword => 'パスワードをお忘れですか？';

  @override
  String get loginScreenSettingUpKidsPhone => 'お子様のアカウントを設定';

  @override
  String get loginScreenLegalPrefix => 'アカウントを開設すると、以下に同意したことになります：';

  @override
  String get loginScreenLegalTermsLink => '利用規約';

  @override
  String get loginScreenLegalMiddle => 'と';

  @override
  String get loginScreenLegalPrivacyLink => 'プライバシーポリシー';

  @override
  String get loginScreenLegalSuffix => 'に同意したことになります。';

  @override
  String get loginScreenAlreadyHerePrompt => 'すでに登録済み？';

  @override
  String get loginScreenSignInLink => 'ログイン';

  @override
  String get loginScreenNoAccountPrompt => 'アカウントがない？';

  @override
  String get loginScreenOpenOneLink => '新規登録';

  @override
  String loginScreenWordCounter(Object count) {
    return '$count/12語';
  }

  @override
  String get homeShellEmptyRoomHint => 'ルームを選んでチャットを始めましょう';

  @override
  String get homeShellEmptySettingHint => '設定を選んでください';

  @override
  String get searchScreenHintPeople => 'ユーザーを検索';

  @override
  String get searchScreenHintRooms => '公開ルームを検索';

  @override
  String get searchScreenPeoplePromptChild => '新しい人を探すには、ユーザー名をすべて入力してね';

  @override
  String get searchScreenPeoplePromptDefault => 'ユーザー名または名前で検索';

  @override
  String get searchScreenNoMatchChild => '見つかりませんでした。新しい人を探すには\nユーザー名を正確に入力してね';

  @override
  String get searchScreenNoMatchDefault => '見つかりませんでした';

  @override
  String get searchScreenNoRoomsYet => '公開ルームはまだありません';

  @override
  String get searchScreenNoRoomsMatch => '一致する公開ルームがありません';

  @override
  String get searchScreenActionAskToAdd => '追加をお願い';

  @override
  String get searchScreenActionSendRequest => 'リクエスト送信';

  @override
  String get searchScreenActionCancel => 'リクエスト取消';

  @override
  String get searchScreenActionApprove => 'リクエスト承認';

  @override
  String get searchScreenActionOpenDm => 'DMを開く';

  @override
  String get searchScreenAskedLabel => '依頼済み';

  @override
  String get profileVisibilityScreenTitle => '公開設定。';

  @override
  String get profileVisibilityScreenSubtitle => '他の人に見える情報や、あなたへの連絡方法を管理できます。';

  @override
  String get profileVisibilityScreenSectionProfile => 'プロフィール';

  @override
  String get profileVisibilityScreenAvatarLabel => 'アバター';

  @override
  String get profileVisibilityScreenAvatarDesc => 'プロフィール写真';

  @override
  String get profileVisibilityScreenOnlineAwayLabel => 'オンライン / 退席中';

  @override
  String get profileVisibilityScreenOnlineAwayDesc => '今アクティブに見えるかどうか';

  @override
  String get profileVisibilityScreenLastSeenLabel => '最終ログイン';

  @override
  String get profileVisibilityScreenLastSeenDesc => '最後にオンラインだった時間';

  @override
  String get profileVisibilityScreenSectionMessages => 'メッセージ';

  @override
  String get profileVisibilityScreenSendReadReceiptsLabel => '既読を送信';

  @override
  String get profileVisibilityScreenSendReadReceiptsDesc =>
      'オンにすると、相手はあなたがメッセージを読んだことが分かります。';

  @override
  String get profileVisibilityScreenShowReadReceiptsLabel => '既読マークを表示';

  @override
  String get profileVisibilityScreenShowReadReceiptsDesc =>
      '相手が読むと、自分のメッセージに「既読」マークが付きます';

  @override
  String get profileVisibilityScreenShowReadReceiptsHint =>
      '「既読を送信」をオンにしている相手だけが既読としてカウントされます。オフの相手は表示されません。';

  @override
  String get profileVisibilityScreenSectionPeople => 'ユーザー';

  @override
  String get profileVisibilityScreenFriendRequestsLabel => '友達リクエスト';

  @override
  String get profileVisibilityScreenFriendRequestsDesc => '友達リクエストを送れる相手';

  @override
  String get profileVisibilityScreenSupervisedTitle => '保護者がこれらを設定しています';

  @override
  String get profileVisibilityScreenSupervisedBody =>
      'ここに表示される内容は他の人と同じですが、変更できるのは保護者だけです。保護者はいつでもあなたの写真、オンライン状況、最終アクセス時間を確認できます。';

  @override
  String get profileVisibilityScreenOptionPublic => '公開';

  @override
  String get profileVisibilityScreenOptionFriends => '友達';

  @override
  String get profileVisibilityScreenOptionNobody => 'なし';

  @override
  String get profileVisibilityScreenOptionOn => 'オン';

  @override
  String get profileVisibilityScreenOptionOff => 'オフ';

  @override
  String get profileVisibilityScreenOptionAnyone => '誰でも';

  @override
  String get logoScreenTitle => 'アプリのロゴ。';

  @override
  String get logoScreenSubtitle => 'ヘッダーに出るマークは、あなた次第。';

  @override
  String get logoScreenAutoLabel => '自動';

  @override
  String get logoScreenAutoDescription => 'テーマに合わせて変わります。パレットでマークが変化。';

  @override
  String get logoScreenManualLabel => '手動';

  @override
  String get logoScreenManualDescription => '好きなマークを選んで、テーマはそのまま。';

  @override
  String get logoScreenAlwaysDefaultLabel => '常にデフォルト';

  @override
  String get logoScreenAlwaysDefaultDescription =>
      'テーマに関わらず、MonkeyHubのマークになります。';

  @override
  String get logoScreenActiveBadge => '使用中';

  @override
  String get logoScreenMonkeyCollectionHeader => 'モンキーコレクション';

  @override
  String get logoScreenThemesHeader => 'テーマ';

  @override
  String get recoveryPhraseScreenCopiedSnackbar => 'コピーしました。安全な場所に貼り付けてください';

  @override
  String get recoveryPhraseScreenConfirmHeroMuted => '確認\n';

  @override
  String get recoveryPhraseScreenConfirmHeroInk => '本人です。';

  @override
  String get recoveryPhraseScreenPasswordBody =>
      'あなたのパスワードです。他人があなたのアカウントにリカバリーフレーズを設定できないようにするためのものです。';

  @override
  String get recoveryPhraseScreenPasswordHint => 'パスワード';

  @override
  String get recoveryPhraseScreenContinueButton => '続ける';

  @override
  String get recoveryPhraseScreenNotNowLink => '今はしない';

  @override
  String get recoveryPhraseScreenEnterPasswordError => 'パスワードを入力してください。';

  @override
  String get recoveryPhraseScreenSaveHeroMuted => '保存して\n';

  @override
  String get recoveryPhraseScreenSaveHeroInk => 'この言葉を。';

  @override
  String get recoveryPhraseScreenWordsBody =>
      'この12個の単語は、パスワードを忘れた場合にアカウントへ戻る唯一の方法です。もう一度表示することはできず、私たちが代わりに復元することもできません。';

  @override
  String get recoveryPhraseScreenCopyButton => 'コピー';

  @override
  String get recoveryPhraseScreenPaperHint =>
      'できれば紙に書き留めておいてください。この端末に保存したものは、端末と一緒に失われることがあります。';

  @override
  String get recoveryPhraseScreenSavedButton => '保存しました';

  @override
  String get recoveryPhraseScreenBackLink => '← 戻る';

  @override
  String get recoveryPhraseScreenKeepPhraseLink => '今はしない — 今のフレーズのままにする';

  @override
  String get homeScreenProfileSemanticLabel => 'あなたのプロフィール';

  @override
  String homeScreenGreeting(Object name) {
    return 'やあ、$name。';
  }

  @override
  String get homeScreenNewRoomSemanticLabel => '新しいルーム';

  @override
  String get homeScreenEmptyRoomsMessage => 'まだルームがありません — 作ってみましょう';

  @override
  String get groupCallScreenTitleVideo => 'グループビデオ通話';

  @override
  String get groupCallScreenTitleVoice => 'グループ音声通話';

  @override
  String groupCallScreenParticipantCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人参加中',
      one: '自分だけ',
    );
    return '$_temp0';
  }

  @override
  String get groupCallScreenReconnecting => '再接続中…';

  @override
  String get groupCallScreenUnmuteLabel => 'ミュート解除';

  @override
  String get groupCallScreenMuteLabel => 'ミュート';

  @override
  String get groupCallScreenCamOnLabel => 'カメラON';

  @override
  String get groupCallScreenCamOffLabel => 'カメラOFF';

  @override
  String get groupCallScreenFlipLabel => '切替';

  @override
  String get groupCallScreenSpeakerLabel => 'スピーカー';

  @override
  String get groupCallScreenLeaveLabel => '退出';

  @override
  String get groupCallScreenYouLabel => '自分';

  @override
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary) {
    return '$summaryで絞り込み中。フィルターを変更';
  }

  @override
  String get roomFilterDrawerButtonSemanticLabel => 'チャットを絞り込む';

  @override
  String roomFilterDrawerActiveSummary(Object count, Object summary) {
    return '$summary · $count';
  }

  @override
  String get roomFilterDrawerClearSemanticLabel => 'フィルターを解除';

  @override
  String get roomFilterDrawerClearLabel => 'クリア';

  @override
  String get roomFilterDrawerDimensionType => 'タイプ';

  @override
  String get roomFilterDrawerDimensionNature => '属性';

  @override
  String get roomFilterDrawerDimensionStatus => 'ステータス';

  @override
  String get roomFilterDrawerPanelClear => 'クリア';

  @override
  String get roomFilterDrawerPanelDone => '完了';

  @override
  String roomFilterDrawerFacetSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のチャット',
    );
    return '$label、$_temp0';
  }

  @override
  String roomFilterDrawerEmptyStateTitle(Object summary) {
    return '$summaryに一致するものがありません';
  }

  @override
  String roomFilterDrawerShowAllSemanticLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のチャットをすべて表示',
    );
    return '$_temp0';
  }

  @override
  String roomFilterDrawerShowAllLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件をすべて表示',
    );
    return '$_temp0';
  }

  @override
  String get createRoomSheetTitle => '新しいルーム';

  @override
  String get createRoomSheetTaglineSecret => '何も残らない';

  @override
  String get createRoomSheetTaglineRegular => 'ずっと残る場所';

  @override
  String get createRoomSheetNameLabel => '名前';

  @override
  String get createRoomSheetNameHint => '正直な名前をつけて';

  @override
  String get createRoomSheetDescriptionLabel => '説明・任意';

  @override
  String get createRoomSheetDescriptionHint => 'ルームについて一言';

  @override
  String get createRoomSheetVisibilityLabel => '公開設定';

  @override
  String get createRoomSheetVisibilityPublicTitle => '公開';

  @override
  String get createRoomSheetVisibilityPublicSub => '誰でも見つけられる';

  @override
  String get createRoomSheetVisibilityPrivateTitle => '非公開';

  @override
  String get createRoomSheetVisibilityPrivateSub => '招待制';

  @override
  String get createRoomSheetTypeLabel => 'タイプ';

  @override
  String get createRoomSheetTypeStandardTitle => '標準';

  @override
  String get createRoomSheetTypeStandardSub => 'メッセージは残る';

  @override
  String get createRoomSheetTypeEphemeralTitle => '一時的';

  @override
  String get createRoomSheetTypeEphemeralSub => '自動で消える';

  @override
  String get createRoomSheetMessageLifeLabel => 'メッセージの寿命';

  @override
  String createRoomSheetTtlSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String createRoomSheetTtlMinutes(Object minutes) {
    return '$minutes分';
  }

  @override
  String createRoomSheetTtlHours(Object hours) {
    return '$hours時間';
  }

  @override
  String get createRoomSheetPasswordLabel => 'パスワード・任意';

  @override
  String get createRoomSheetPasswordHint => '合言葉でロック';

  @override
  String get createRoomSheetNameRequiredError => '名前を入力してください';

  @override
  String get createRoomSheetOpenRoomSemanticLabel => 'ルームを開く';

  @override
  String get createRoomSheetOpenRoomButton => 'ルームを開く';

  @override
  String get familyScreenTitle => 'ファミリー';

  @override
  String familyScreenPendingBanner(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '承認待ちが$count件あります',
    );
    return '$_temp0';
  }

  @override
  String get familyScreenPresenceOnline => 'オンライン中';

  @override
  String get familyScreenPresenceNotPaired => 'まだペアリングされていません';

  @override
  String get familyScreenPresenceJustNow => 'たった今';

  @override
  String familyScreenPresenceMinutesAgo(Object minutes) {
    return '$minutes分前';
  }

  @override
  String familyScreenPresenceHoursAgo(Object hours) {
    return '$hours時間前';
  }

  @override
  String familyScreenPresenceDaysAgo(Object days) {
    return '$days日前';
  }

  @override
  String get familyScreenPairButton => 'ペアリング';

  @override
  String get familyScreenReleaseButton => '解除';

  @override
  String get familyScreenSettingsButton => '設定';

  @override
  String get familyScreenAddChildButton => 'お子様を追加';

  @override
  String get familyScreenEmptyStateTitle => 'お子様はまだいません';

  @override
  String get familyScreenEmptyStateBody => 'お子様のアカウントを作成し、スマートフォンとペアリングしましょう。';

  @override
  String get reactionDetailsSheetTitle => 'リアクション';

  @override
  String get reactionDetailsSheetEmptyState => 'もうリアクションはありません';

  @override
  String reactionDetailsSheetPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人',
    );
    return '$_temp0';
  }

  @override
  String get reactionDetailsSheetFilterAll => 'すべて';

  @override
  String get reactionDetailsSheetYouBadge => '自分';

  @override
  String get roomLayoutScreenTitle => 'チャット一覧。';

  @override
  String get roomLayoutScreenSubtitle => 'ルームの並び方と絞り込み方法';

  @override
  String get roomLayoutScreenLayoutSectionLabel => 'レイアウト';

  @override
  String get roomLayoutScreenRowLayoutLabel => 'リスト表示';

  @override
  String get roomLayoutScreenRowLayoutDescription => '1列でフル幅表示。ひと目で見やすい。';

  @override
  String get roomLayoutScreenGridLayoutLabel => 'グリッド表示';

  @override
  String get roomLayoutScreenGridLayoutDescription =>
      '2列でコンパクトに。一度に多くのルームが見渡せる。';

  @override
  String get roomLayoutScreenFilterControlSectionLabel => 'フィルター';

  @override
  String get roomLayoutScreenChipRowLabel => 'チップ行';

  @override
  String get roomLayoutScreenChipRowDescription =>
      '常に表示。フィルターはワンタップ、占めるのは1行だけ。';

  @override
  String get roomLayoutScreenDrawerButtonLabel => 'ドロワーボタン';

  @override
  String get roomLayoutScreenDrawerButtonDescription =>
      '開くのはボタンひとつ。呼ぶまでは邪魔にならない。';

  @override
  String get roomLayoutScreenQuietRoomSectionLabel => '静かなルーム';

  @override
  String get roomLayoutScreenPlainCornerLabel => '空いたまま';

  @override
  String get roomLayoutScreenPlainCornerDescription => 'まだ発言のないルームはそのまま';

  @override
  String get roomLayoutScreenMonogramLabel => 'ルームの頭文字';

  @override
  String get roomLayoutScreenMonogramDescription => '大きな薄い文字が空いた角を埋めます';

  @override
  String get roomLayoutScreenActiveBadge => '使用中';

  @override
  String get pinnedBannerJumpToPinnedSemanticLabel => 'ピン留めメッセージにジャンプ';

  @override
  String get pinnedBannerAllPinnedSemanticLabel => 'すべてのピン留めメッセージ';

  @override
  String get pinnedBannerTitleSingle => 'ピン留めメッセージ';

  @override
  String pinnedBannerTitleWithIndex(Object count, Object index) {
    return 'ピン留めメッセージ  $index/$count';
  }

  @override
  String get pinnedBannerChatStyleTitle => 'チャットスタイル。';

  @override
  String get pinnedBannerChatStyleSubtitle => 'ルームの見た目';

  @override
  String get pinnedBannerClassicLabel => 'クラシック';

  @override
  String get pinnedBannerClassicSubtitle => '境界線付きヘッダー、フラットな入力欄。';

  @override
  String get pinnedBannerCompactLabel => 'コンパクト';

  @override
  String get pinnedBannerCompactSubtitle => '会話の上に浮かぶ、すりガラスのカプセル。';

  @override
  String get pinnedBannerActiveBadge => '使用中';

  @override
  String get audioMessageMissingLabel => '[音声なし]';

  @override
  String get audioMessageUnavailableLabel => '音声を利用できません';

  @override
  String get audioMessageRetryHint => 'タップして再試行';

  @override
  String get audioMessageLoadingLabel => '読み込み中…';

  @override
  String get audioMessageUsernameRequiredError => 'ユーザー名を入力してください。';

  @override
  String get audioMessagePasswordRequiredError => 'パスワードを入力してください。';

  @override
  String get audioMessageCancelSemanticLabel => 'キャンセル';

  @override
  String get audioMessageHeroCreateLine1 => 'もうすぐ\n';

  @override
  String get audioMessageHeroCreateLine2 => 'です。';

  @override
  String get audioMessageHeroLinkLine1 => 'おかえり\n';

  @override
  String get audioMessageHeroLinkLine2 => 'なさい。';

  @override
  String get audioMessageCreateSubtitle => '家族や友だちがあなたを見つけられるように、ユーザー名を選びましょう。';

  @override
  String audioMessageLinkSubtitle(Object provider) {
    return '一度サインインするだけで、$providerがアカウントに連携されます。';
  }

  @override
  String get audioMessageUsernameHint => 'ユーザー名';

  @override
  String get audioMessageDisplayNameHint => '表示名（任意）';

  @override
  String get audioMessagePasswordHint => 'パスワード';

  @override
  String get audioMessageSwitchToLinkPrompt => 'それは自分のアカウントです。サインインする';

  @override
  String get audioMessageCreateAccountButton => 'アカウントを作成';

  @override
  String audioMessageSignInLinkButton(Object provider) {
    return 'サインインして$providerと連携';
  }

  @override
  String get audioMessageSwitchToLinkModeLink => 'すでにアカウントをお持ちですか？';

  @override
  String get audioMessageSwitchToCreateModeLink => '初めてですか？アカウントを作成';

  @override
  String get approvalsScreenTitle => '承認';

  @override
  String get approvalsScreenEmptyTitle => '承認待ちはありません';

  @override
  String get approvalsScreenEmptySubtitle => 'すべて対応済みです';

  @override
  String get approvalsScreenErrorNotGuardian => 'これはあなたが決めることではありません';

  @override
  String get approvalsScreenErrorAlreadyHandled => 'すでに他の場所で対応済みです';

  @override
  String get approvalsScreenErrorGeneric => '保存できませんでした。もう一度お試しください';

  @override
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other) {
    return '$childが$otherを追加しようとしています';
  }

  @override
  String approvalsScreenHeadlineContactIncoming(Object child, Object other) {
    return '$otherが$childを追加しようとしています';
  }

  @override
  String approvalsScreenHeadlineJoinRoom(Object child, Object room) {
    return '$childが$roomに参加しようとしています';
  }

  @override
  String get approvalsScreenSomeoneLower => '誰か';

  @override
  String get approvalsScreenSomeoneCapital => '誰か';

  @override
  String get approvalsScreenRoomFallback => 'あるルーム';

  @override
  String get approvalsScreenConsequenceContactOutgoing =>
      '相手にリクエストが届きます。承認するかは相手が選べます。';

  @override
  String approvalsScreenConsequenceContactIncoming(Object child) {
    return '$childにリクエストが届き、承認するか無視するかを選べます。';
  }

  @override
  String get approvalsScreenConsequenceJoinRoom =>
      '取り消すまで、相手はそこで読んだり書き込んだりできます。';

  @override
  String get approvalsScreenNotYetButton => 'あとで';

  @override
  String get approvalsScreenAllowButton => '許可';

  @override
  String get approvalsScreenForwardDirectMessageFallback => 'ダイレクトメッセージ';

  @override
  String approvalsScreenForwardTitle(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のメッセージを転送',
    );
    return '$_temp0';
  }

  @override
  String get approvalsScreenForwardNoChatsYet => 'ほかのチャットはまだありません';

  @override
  String get approvalsScreenForwardNoMatches => '一致する結果がありません';

  @override
  String approvalsScreenForwardMaxTargetsHint(Object max) {
    return '一度に最大$max件のチャットまで';
  }

  @override
  String get approvalsScreenForwardSearchHint => 'チャットを検索';

  @override
  String approvalsScreenForwardDeselectSemantic(Object title) {
    return '$titleの選択を解除';
  }

  @override
  String approvalsScreenForwardSelectSemantic(Object title) {
    return '$titleを選択';
  }

  @override
  String get approvalsScreenForwardFadesBadge => '消滅';

  @override
  String get approvalsScreenForwardSendSemantic => '送信';

  @override
  String approvalsScreenForwardSendButton(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件に送信',
      zero: '送信',
    );
    return '$_temp0';
  }

  @override
  String get linkedAccountsScreenTitle => '連携アカウント';

  @override
  String get linkedAccountsScreenSubtitle =>
      'パスワードを入力せずにサインインできるように、このアカウントに連携したアカウントです。';

  @override
  String get linkedAccountsScreenEmptyState => 'このデバイスで連携できるものはありません。';

  @override
  String get linkedAccountsScreenStatusChecking => '確認中…';

  @override
  String linkedAccountsScreenStatusLinked(Object provider) {
    return 'どのデバイスからでも$providerでサインインできます。';
  }

  @override
  String linkedAccountsScreenStatusNotLinked(Object provider) {
    return '$providerを追加すると、パスワードを入力しなくて済みます。';
  }

  @override
  String linkedAccountsScreenUnlinkTitle(Object provider) {
    return '$providerの連携を解除';
  }

  @override
  String get linkedAccountsScreenUnlinkAction => '解除';

  @override
  String linkedAccountsScreenUnlinkSubtitle(Object provider) {
    return '$providerでのサインインをやめるには、パスワードを入力してください。';
  }

  @override
  String linkedAccountsScreenLinkTitle(Object provider) {
    return '$providerと連携';
  }

  @override
  String get linkedAccountsScreenLinkAction => '連携';

  @override
  String linkedAccountsScreenLinkSubtitle(Object provider) {
    return '$providerをサインイン方法として追加するには、パスワードを入力してください。';
  }

  @override
  String get linkedAccountsScreenPillChecking => '確認中';

  @override
  String get linkedAccountsScreenPillLinked => '連携済み';

  @override
  String get linkedAccountsScreenPillNotLinked => '未連携';

  @override
  String get linkedAccountsScreenCallSheetVoiceLabel => '音声';

  @override
  String get linkedAccountsScreenCallSheetVideoLabel => 'ビデオ';

  @override
  String get linkedAccountsScreenCallSheetTitle => '通話を開始';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneTitle => '全員を呼び出す';

  @override
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle =>
      'このルームの全員を呼び出します';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleTitle => '参加者を選ぶ';

  @override
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle => '招待する人を選びます';

  @override
  String get linkedAccountsScreenCallSheetCallFullError => '通話は満員です（最大6人まで）';

  @override
  String get linkedAccountsScreenCallSheetStartFailedError => '通話を開始できませんでした';

  @override
  String get linkedAccountsScreenCallSheetInviteTitle => '通話に招待';

  @override
  String get linkedAccountsScreenCallSheetNoOtherMembers => '他のメンバーがいません';

  @override
  String get linkedAccountsScreenCallSheetSelectPeople => '参加者を選択';

  @override
  String get linkedAccountsScreenCallSheetStartCallLabel => '通話を開始';

  @override
  String linkedAccountsScreenCallSheetStartCallCount(Object count) {
    return '通話を開始 ($count)';
  }

  @override
  String get childPairScreenGreetingLine1 => 'やあ';

  @override
  String get childPairScreenGreetingLine2 => 'きみ。';

  @override
  String get childPairScreenIntro =>
      '保護者にMonkeyHubを開いて「デバイスをペアリング」をタップしてもらいましょう。表示されたコードをスキャンするか、読み上げられた6桁の数字を入力してください。';

  @override
  String get childPairScreenOrDivider => 'または';

  @override
  String get childPairScreenGenericError => '問題が発生しました。もう一度お試しください。';

  @override
  String get profileScreenDeleteAccountFailed => '問題が発生しました。もう一度お試しください。';

  @override
  String get childPairScreenAccountGoneError => 'そのアカウントはもう存在しません。';

  @override
  String get childPairScreenScanButtonLabel => '保護者のコードをスキャン';

  @override
  String get childPairScreenNoCameraMessage => 'カメラが使えません。代わりに6桁の数字を入力してください。';

  @override
  String get childPairScreenStopScanning => 'スキャンを中止';

  @override
  String get childPairScreenSubmitButtonLabel => '入れて';

  @override
  String get childPairScreenBackToSignIn => '← サインインに戻る';

  @override
  String get fileMessageUnavailable => 'ファイルはもう利用できません';

  @override
  String get fileMessageOpenFailed => 'ファイルを開けませんでした';

  @override
  String get fileMessageDefaultName => 'ドキュメント';

  @override
  String fileMessageSaveSemanticLabel(Object name) {
    return '$nameを保存';
  }

  @override
  String fileMessageViewSemanticLabel(Object name) {
    return '$nameを表示';
  }

  @override
  String get textFileViewerDownloadTooltip => 'ダウンロード';

  @override
  String get textFileViewerTruncatedNotice =>
      'このファイルの一部のみ表示しています — 残りを見るにはダウンロードしてください。';

  @override
  String get fileMessageUploadFailedLabel => '失敗';

  @override
  String get fileMessageSendingLabel => '送信中…';

  @override
  String fileMessageSizeSendingLabel(Object size) {
    return '$size・送信中…';
  }

  @override
  String fileMessageAgoMinutes(Object count) {
    return '$count分前';
  }

  @override
  String fileMessageAgoHours(Object count) {
    return '$count時間前';
  }

  @override
  String fileMessageAgoDays(Object count) {
    return '$count日前';
  }

  @override
  String get fileMessageStandardBadge => 'スタンダード';

  @override
  String fileMessageDraftMessagesTapToView(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '相手からの下書きメッセージ$count件・タップして表示',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageApproveButton => '承認';

  @override
  String get fileMessageDeclineButton => '拒否';

  @override
  String fileMessageSentAgoLabel(Object ago) {
    return '$agoに送信';
  }

  @override
  String fileMessageMessagesPending(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'メッセージ$count件が送信待ち',
    );
    return '$_temp0';
  }

  @override
  String get fileMessageCancelRequestButton => 'リクエストを取り消し';

  @override
  String get destructiveSheetCannotBeUndone => 'この操作は取り消せません';

  @override
  String get destructiveSheetCancelSemanticLabel => 'キャンセル';

  @override
  String get destructiveSheetCancelButtonLabel => 'キャンセル';

  @override
  String get destructiveSheetHideLabel => '非表示';

  @override
  String get destructiveSheetViewLabel => '表示';

  @override
  String get destructiveSheetPairingMintError => 'コードを作成できませんでした。もう一度お試しください。';

  @override
  String get destructiveSheetPairingReleaseTitle => '解除';

  @override
  String get destructiveSheetPairingPairTitle => 'ペアリング';

  @override
  String destructiveSheetPairingReleaseInstructions(Object name) {
    return '$nameさんのスマホでプロフィールを開き、「このスマホを返す」をタップして、この数字を入力してください。';
  }

  @override
  String destructiveSheetPairingPairInstructions(Object name) {
    return '$nameさんのスマホでMonkeyHubを開いてこれをスキャンするか、この数字を入力してください。';
  }

  @override
  String get destructiveSheetPairingCodeExpired => 'このコードの有効期限が切れました';

  @override
  String destructiveSheetPairingExpiresIn(Object time) {
    return 'あと$timeで失効します';
  }

  @override
  String get destructiveSheetPairingNewCodeButton => '新しいコード';

  @override
  String get destructiveSheetPairingOneUseNote =>
      '一度だけ使えます。新しいコードを作ると古いコードは無効になります。';

  @override
  String get deepOceanThemeAttachButtonLabel => '添付';

  @override
  String get deepOceanThemeCameraButtonLabel => 'カメラ';

  @override
  String get deepOceanThemeSendButtonLabel => '送信';

  @override
  String get deepOceanThemeEphemeralHint => 'ささやいて';

  @override
  String get deepOceanThemeDefaultHint => 'なにか話そう';

  @override
  String get deepOceanThemeMessageHint => 'メッセージ';

  @override
  String photoChromeMediaPositionLabel(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get photoChromeMediaGoneLabel => 'このファイルは見つかりません';

  @override
  String get photoChromeMediaYouLabel => '自分';

  @override
  String get photoChromeCloseSemanticLabel => '閉じる';

  @override
  String get photoChromeFillToggleSemanticLabel => '画面に合わせる／画面いっぱいに表示';

  @override
  String get photoChromeShowInChatSemanticLabel => 'チャットで表示';

  @override
  String photoChromeThumbnailSemanticLabel(Object current, Object total) {
    return '$total 件中 $current 件目';
  }

  @override
  String photoTrayCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '写真 $count 枚',
    );
    return '$_temp0';
  }

  @override
  String get photoTrayDiscardSemanticLabel => 'これらの写真を破棄';

  @override
  String get photoTrayRemoveSemanticLabel => 'この写真を外す';

  @override
  String get photoTrayEditSemanticLabel => 'この写真をトリミング・描き込み';

  @override
  String get photoTrayAddMoreSemanticLabel => '写真を追加';

  @override
  String photoTrayLimitSnack(Object count) {
    return '一度に送れる写真は $count 枚までです';
  }

  @override
  String get photoTrayLoadFailedSnack => '一部の写真を開けませんでした';

  @override
  String get mediaPickFailedMessage => '開けませんでした。もう一度選んでみてください';

  @override
  String typingIndicatorOnePersonTyping(Object name) {
    return '$nameが入力中…';
  }

  @override
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2) {
    return '$name1と$name2が入力中…';
  }

  @override
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  ) {
    return '$name1、$name2ほか$extra人が入力中…';
  }

  @override
  String get typingIndicatorUnknownCallerFallbackName => '着信';

  @override
  String get typingIndicatorIncomingVideoCallLabel => '着信中のビデオ通話';

  @override
  String get typingIndicatorIncomingVoiceCallLabel => '着信中の音声通話';

  @override
  String get typingIndicatorDeclineButtonLabel => '拒否';

  @override
  String get typingIndicatorDeclineButtonDeclining => '拒否中…';

  @override
  String get typingIndicatorAcceptButtonLabel => '応答';

  @override
  String get typingIndicatorAcceptButtonConnecting => '接続中…';

  @override
  String get messageStampNavigationTitle => 'ナビゲーション。';

  @override
  String get messageStampNavigationSubtitle => 'チャット、発見、フィード、設定の切り替え方法';

  @override
  String get messageStampRadialOrbLabel => 'ラジアルオーブ';

  @override
  String get messageStampRadialOrbDescription =>
      'コーナーを長押ししてドラッグ。ふだんは静かに佇み、使ううちに手に馴染んでいく。';

  @override
  String get messageStampBottomPillLabel => 'ボトムカプセル';

  @override
  String get messageStampBottomPillDescription => '定番のタップ操作。常に表示されていて、迷わず使える。';

  @override
  String get messageStampActiveLabel => '選択中';

  @override
  String get messageStampUploadingLabel => 'アップロード中';

  @override
  String get messageStampSendingLabel => '送信中';

  @override
  String get messageStampFailedToSendLabel => '送信に失敗しました';

  @override
  String get messageStampSentLabel => '送信済み';

  @override
  String get messageStampDeliveredLabel => '配信済み';

  @override
  String get messageStampSeenLabel => '既読';

  @override
  String get messageStampSavedLabel => '保存済み';

  @override
  String messageStampCountdownSeconds(Object count) {
    return '$count秒';
  }

  @override
  String messageStampCountdownMinutes(Object count) {
    return '$count分';
  }

  @override
  String get voiceRecorderScreenMicPermissionDeniedSnackbar =>
      'マイクへのアクセスが拒否されました';

  @override
  String get voiceRecorderScreenStatusRecording => '録音中';

  @override
  String get voiceRecorderScreenStatusReady => '準備完了';

  @override
  String get voiceRecorderScreenStatusTapToStart => 'タップして開始';

  @override
  String get voiceRecorderScreenReRecordButton => '録り直す';

  @override
  String get voiceRecorderScreenStopButton => '停止';

  @override
  String get voiceRecorderScreenSendButton => '送信';

  @override
  String get voiceRecorderScreenRecordButton => '録音';

  @override
  String get cyberpunkThemeMentionPickerEveryoneTitle => '全員';

  @override
  String get cyberpunkThemeMentionPickerNotifiesAllBadge => '全員に通知';

  @override
  String get cyberpunkThemeMentionPickerOwnerBadge => 'オーナー';

  @override
  String get releaseDeviceScreenFallbackChildName => 'お子様';

  @override
  String releaseDeviceScreenIntro(Object name) {
    return '$nameをこの端末からサインアウトさせて返却します。端末は通常のサインイン画面に戻り、誰でも使えるようになります。';
  }

  @override
  String get releaseDeviceScreenAccountKeptNote =>
      'アカウント、メッセージ、フレンドはすべて保持されます。いつでもまたサインインできます。';

  @override
  String releaseDeviceScreenAskGrownUp(Object name) {
    return '保護者にMonkeyHubを開いてもらい、ファミリーの中から$nameを見つけて「解除」をタップしてもらいましょう。';
  }

  @override
  String get releaseDeviceScreenOrDivider => 'または';

  @override
  String get releaseDeviceScreenOnePhoneNote =>
      'この端末しかない場合は、保護者がここからサインインすることもできます。';

  @override
  String get releaseDeviceScreenUsernameHint => '保護者のユーザー名';

  @override
  String get releaseDeviceScreenPasswordHint => '保護者のパスワード';

  @override
  String get releaseDeviceScreenSignOutSemanticLabel => 'サインアウト';

  @override
  String get releaseDeviceScreenChecking => '確認中…';

  @override
  String releaseDeviceScreenSignOutButton(Object name) {
    return '$nameをサインアウト';
  }

  @override
  String get releaseDeviceScreenHeaderTitle => 'このスマホを返してください';

  @override
  String get releaseDeviceScreenErrorCodeExpired =>
      'そのコードは期限切れです。新しいコードをもらってください。';

  @override
  String get releaseDeviceScreenErrorCodeInvalid =>
      'そのコードは無効です。すでに使用されている可能性があります。';

  @override
  String get releaseDeviceScreenErrorNotAGuardian =>
      'うまくいきませんでした。ユーザー名とパスワードを確認してください。';

  @override
  String get releaseDeviceScreenErrorGeneric => '問題が発生しました。もう一度お試しください。';

  @override
  String get activeCallPillMoveHereSemanticLabel => '通話をこの端末に移動';

  @override
  String activeCallPillCallWith(Object name) {
    return '$nameとの通話';
  }

  @override
  String activeCallPillOnDevice(Object device) {
    return '$deviceで';
  }

  @override
  String get activeCallPillMoveHereLabel => 'ここに移動';

  @override
  String get activeCallPillUnknownCaller => '不明';

  @override
  String get activeCallPillPlatformIphone => 'iPhone';

  @override
  String get activeCallPillPlatformIosSimulator => 'iOSシミュレーター';

  @override
  String get activeCallPillPlatformAndroid => 'Android端末';

  @override
  String get activeCallPillPlatformMac => 'Mac';

  @override
  String get activeCallPillPlatformWindows => 'Windows PC';

  @override
  String get activeCallPillPlatformLinux => 'Linux端末';

  @override
  String get activeCallPillPlatformBrowser => 'ブラウザ';

  @override
  String get activeCallPillPlatformOther => '他の端末';

  @override
  String get activeCallPillPinnedHeader => 'ピン留め';

  @override
  String activeCallPillPinnedHeaderCount(Object count) {
    return 'ピン留め・$count';
  }

  @override
  String get activeCallPillNothingPinned => 'もうピン留めはありません';

  @override
  String activeCallPillJumpToMessageSemanticLabel(Object name) {
    return '$nameのメッセージにジャンプ';
  }

  @override
  String activeCallPillUnpinMessageSemanticLabel(Object name) {
    return '$nameのメッセージのピン留めを解除';
  }

  @override
  String get callButtonErrorBusy => '他の通話中です';

  @override
  String get callButtonErrorCallFailed => '通話を開始できませんでした';

  @override
  String get callButtonErrorNotMember => 'このルームのメンバーではありません';

  @override
  String get callButtonErrorGeneric => '通話を開始できませんでした';

  @override
  String get callButtonAlreadyOnCall => 'すでに通話中です';

  @override
  String get callButtonBusyElsewhere => '他の端末で通話中です';

  @override
  String get callButtonVoiceCallTooltip => '音声通話';

  @override
  String get callButtonVideoCallTooltip => 'ビデオ通話';

  @override
  String get callButtonTooltip => '通話';

  @override
  String get callButtonReplyStyleTitle => '返信スタイル。';

  @override
  String get callButtonReplyStyleSubtitle => '返信に元のメッセージがどう表示されるか';

  @override
  String get callButtonReplyStylePhantomEchoLabel => 'ゴーストエコー';

  @override
  String get callButtonReplyStylePhantomEchoDescription =>
      '曲線の接続バーと結合点の分岐アイコンとともに、親メッセージのゴースト吹き出しが上に浮かびます。';

  @override
  String get callButtonReplyStyleStickyNoteLabel => '付箋';

  @override
  String get callButtonReplyStyleStickyNoteDescription =>
      '少し傾いたポラロイド風カードが、吹き出しの角にクリップで留められています。';

  @override
  String get callButtonReplyStyleComicTailLabel => 'コミック風しっぽ';

  @override
  String get callButtonReplyStyleComicTailDescription =>
      '小さな親メッセージのミニ吹き出しに、下向きのコミック風三角しっぽが付いています。';

  @override
  String get callButtonReplyStyleClassicLabel => 'クラシック';

  @override
  String get callButtonReplyStyleClassicDescription =>
      'アクセントカラーの引用カプセルに接続バーとアバターが付いた、おなじみのWhatsApp風デザインです。';

  @override
  String get callButtonReplyStyleActiveBadge => '使用中';

  @override
  String get callButtonReplyPreviewSampleMessage => 'ねえ、新しいデモ見た?';

  @override
  String get callButtonReplyPreviewSampleReply => 'うん、あのぼかしヤバい。';

  @override
  String get childSetupScreenErrorPickUsername => 'ユーザー名を選んでください。';

  @override
  String get childSetupScreenErrorUsernameTaken => 'そのユーザー名はすでに使われています。';

  @override
  String get childSetupScreenErrorChildNotAllowed => 'お子様を追加できるのは保護者アカウントのみです。';

  @override
  String get childSetupScreenErrorGeneric => 'アカウントを作成できませんでした。もう一度お試しください。';

  @override
  String get childSetupScreenTitle => 'お子様を追加';

  @override
  String get childSetupScreenHeading => 'その子は\nだれ?';

  @override
  String get childSetupScreenNameLabel => '名前';

  @override
  String get childSetupScreenNameHint => '呼び名';

  @override
  String get childSetupScreenUsernameLabel => 'ユーザー名';

  @override
  String get childSetupScreenUsernameHint => '友だちが見つけられる名前';

  @override
  String get childSetupScreenWhatTheyGetTitle => 'できること';

  @override
  String get childSetupScreenBulletTalkImmediately => 'あなたやきょうだいとは、すぐに話せます。';

  @override
  String get childSetupScreenBulletNeedsApproval =>
      'ほかの相手とやりとりするには保護者の許可が必要です。子どもから申請する場合も、相手から申請が来た場合も同じです。';

  @override
  String get childSetupScreenBulletPublicRoomsOff => '公開ルームは、オンにするまでオフのままです。';

  @override
  String get childSetupScreenBulletCantSignOut =>
      'サインアウトはできず、保護者はいつでも様子を確認できます。';

  @override
  String get childSetupScreenCreateButton => '作成してペアリング';

  @override
  String childSetupScreenFriendRowMessageSemanticLabel(Object name) {
    return '$nameにメッセージを送る';
  }

  @override
  String get childSetupScreenWaitingPillAskedLabel => '申請済み';

  @override
  String get childSetupScreenMemberCountUnitLabel => '人';

  @override
  String childSetupScreenSeeAllLabel(Object count) {
    return '全$count件を見る';
  }

  @override
  String childSetupScreenSeeAllSemanticLabel(Object count) {
    return '全$count件をすべて表示';
  }

  @override
  String get bubbleStyleScreenTitle => '吹き出しスタイル。';

  @override
  String get bubbleStyleScreenSubtitle => '言葉が届く、その形';

  @override
  String get bubbleStyleScreenTailedLabel => 'しっぽ付き';

  @override
  String get bubbleStyleScreenTailedDescription =>
      'しっぽが一続きのメッセージの最後を締めくくり、その上の行はひとつのブロックにまとまります。';

  @override
  String get bubbleStyleScreenSoftLabel => 'ソフト';

  @override
  String get bubbleStyleScreenSoftDescription =>
      'しっぽなし――内側の角を絞ることだけで、ひと続きのメッセージがまとまる。';

  @override
  String get bubbleStyleScreenPillLabel => 'カプセル';

  @override
  String get bubbleStyleScreenPillDescription => '完全に丸いカプセル型、どの行も同じ形。';

  @override
  String get bubbleStyleScreenSlabLabel => 'ブロック';

  @override
  String get bubbleStyleScreenSlabDescription =>
      '角ばった肩――シャープで、印刷物のようにきっぱりとした佇まい。';

  @override
  String get bubbleStyleScreenActiveBadge => '使用中';

  @override
  String get bubbleStyleScreenPreviewQuestion => 'で、どう見える?';

  @override
  String get bubbleStyleScreenPreviewReplyOne => '良くなった';

  @override
  String get bubbleStyleScreenPreviewReplyTwo => 'だいぶ良くなった';

  @override
  String get bubbleStyleScreenMediaTileVideoSemanticLabel => '動画';

  @override
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel => '写真';

  @override
  String get incomingGroupCallScreenCallFullError => 'この通話は満員です(最大6人)';

  @override
  String get incomingGroupCallScreenJoinFailedError => '通話に参加できませんでした';

  @override
  String get incomingGroupCallScreenDefaultRoomName => 'グループ通話';

  @override
  String get incomingGroupCallScreenDefaultStarterName => '誰か';

  @override
  String incomingGroupCallScreenStartedVideoCall(Object starter) {
    return '$starterさんがビデオ通話を開始しました';
  }

  @override
  String incomingGroupCallScreenStartedVoiceCall(Object starter) {
    return '$starterさんが音声通話を開始しました';
  }

  @override
  String incomingGroupCallScreenAlreadyJoinedCount(Object count) {
    return '$count人が参加中';
  }

  @override
  String get incomingGroupCallScreenDismissButton => '拒否';

  @override
  String get incomingGroupCallScreenJoinButton => '参加';

  @override
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のチャット',
    );
    return '$_temp0';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のメッセージ',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow =>
      '最後のメッセージはたった今';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  ) {
    return '最後のメッセージは$hours時間前';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday =>
      '最後のメッセージは昨日';

  @override
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  ) {
    return '最後のメッセージは$days日前';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo =>
      '最後のメッセージはしばらく前';

  @override
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge => '削除';

  @override
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  ) {
    return '$childNameから$contactNameを削除しますか?';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats =>
      '二人は連絡が取れなくなり、これまでのやり取りも消えます。';

  @override
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  ) {
    return '二人は連絡が取れなくなります。$contactNameに通知されることはありません。';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  ) {
    return '$chats・$messagesが削除されます';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail =>
      '写真やボイスメッセージも含め、双方から完全に削除されます。元に戻すことはできません。';

  @override
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '他に$count件のルームを共有しています',
    );
    return '$_temp0';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote =>
      '共有中のルームはそのまま残ります。除外したい場合は、下のルーム一覧からそのルームを削除してください。';

  @override
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete =>
      '解除して削除';

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  ) {
    return '$contactNameを削除し、$messagesを消去します。';
  }

  @override
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  ) {
    return '$contactNameを許可リストから削除します。';
  }

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel =>
      'キャンセル';

  @override
  String get incomingGroupCallScreenRemoveContactSheetCancelButton => 'キャンセル';

  @override
  String get groupCallBannerCallFullError => 'この通話は満員です（最大6人）';

  @override
  String get groupCallBannerJoinFailedError => '通話に参加できませんでした';

  @override
  String get groupCallBannerUnknownParticipant => '誰か';

  @override
  String get groupCallBannerOngoingVideoCall => 'ビデオ通話中';

  @override
  String get groupCallBannerOngoingVoiceCall => '音声通話中';

  @override
  String groupCallBannerParticipantsInCall(Object extra, Object names) {
    return '$names$extraが通話中';
  }

  @override
  String get groupCallBannerJoinCallSemanticLabel => '通話に参加';

  @override
  String get groupCallBannerJoinButtonLabel => '参加';

  @override
  String get groupCallBannerJoinRoomSheetTitle => 'ルームに参加';

  @override
  String groupCallBannerMemberCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人のメンバー',
    );
    return '$_temp0';
  }

  @override
  String get groupCallBannerPasswordFieldLabel => 'パスワード';

  @override
  String get groupCallBannerPasswordHint => 'パスフレーズ';

  @override
  String get groupCallBannerJoinRoomButtonSemanticLabel => '参加';

  @override
  String get groupCallBannerJoinRoomButtonLabel => '参加';

  @override
  String get groupCallBannerCancelButtonSemanticLabel => 'キャンセル';

  @override
  String get groupCallBannerCancelButtonLabel => 'キャンセル';

  @override
  String get viewOnceViewerBadgeLabel => '一度だけ';

  @override
  String get socialButtonDividerOr => 'または';

  @override
  String get socialButtonGoogleContinue => 'Googleで続ける';

  @override
  String get discoverListsPeopleTitle => '友だち';

  @override
  String discoverListsPeopleCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterHint => '友だちを検索';

  @override
  String get discoverListsClearFilterSemanticLabel => 'フィルターをクリア';

  @override
  String get discoverListsNoOneYet => 'まだ誰もいません';

  @override
  String discoverListsNoMatches(Object query) {
    return '「$query」に一致する人はいません';
  }

  @override
  String get discoverListsRoomsTitle => 'ルーム';

  @override
  String discoverListsRoomsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件',
    );
    return '$_temp0';
  }

  @override
  String get discoverListsFilterRoomsHint => '参加中のルームを検索';

  @override
  String get discoverListsNoRoomsYet => 'まだルームがありません';

  @override
  String discoverListsNoRoomsMatch(Object query) {
    return '「$query」に一致するルームはありません';
  }

  @override
  String get discoverListsVoiceCallLabel => '音声通話';

  @override
  String get discoverListsVideoCallLabel => 'ビデオ通話';

  @override
  String get approvalGateAlreadyAskedLabel => '申請済み';

  @override
  String get approvalGateAskGrownUpLabel => '保護者に聞いてみよう';

  @override
  String approvalGateAlreadyAskedBody(Object what) {
    return '$whatについては、もう聞いています。';
  }

  @override
  String approvalGateNeedApprovalBody(Object what) {
    return '$whatには、保護者の許可が必要です。';
  }

  @override
  String get approvalGateDisabledBody => '保護者が今はこれをオフにしています。';

  @override
  String get approvalGateAlreadyAskedFooter =>
      '保護者にメッセージが届きます。しばらくしてからまた確認してください。';

  @override
  String get approvalGateWillNotifyFooter => '保護者にはお知らせします。返事があればここに表示されます。';

  @override
  String get approvalGateTalkToThemFooter => '変えてほしいときは、保護者に直接話してみてください。';

  @override
  String get approvalGateAskButton => '聞く';

  @override
  String get approvalGateNotNowButton => 'あとで';

  @override
  String get approvalGateOkButton => 'OK';

  @override
  String get approvalGateWaitingPillLabel => '保護者の返事待ち';

  @override
  String get reportSheetTitle => '報告';

  @override
  String get reportSheetSubtitle => 'どんな問題か教えてください。';

  @override
  String get reportSheetPrivacyNote => '報告は非公開です。相手に通知されることはありません。';

  @override
  String get reportSheetReasonSpamLabel => 'スパム';

  @override
  String get reportSheetReasonSpamDescription => '迷惑な広告や同じメッセージの繰り返し';

  @override
  String get reportSheetReasonHarassmentLabel => '嫌がらせ';

  @override
  String get reportSheetReasonHarassmentDescription => '特定の人への攻撃やいじめ';

  @override
  String get reportSheetReasonImpersonationLabel => 'なりすまし';

  @override
  String get reportSheetReasonImpersonationDescription => '誰かになりすましている';

  @override
  String get reportSheetReasonInappropriateLabel => '不適切';

  @override
  String get reportSheetReasonInappropriateDescription => '性的、暴力的、または違法なコンテンツ';

  @override
  String get reportSheetReasonOtherLabel => 'その他';

  @override
  String get reportSheetReasonOtherDescription => 'その他の理由';

  @override
  String get reportSheetOtherNoteHint => '何がありましたか?';

  @override
  String get reportSheetSubmitSemanticLabel => '報告を送信';

  @override
  String get reportSheetSubmitButton => '送信';

  @override
  String get reportSheetUpdateRequiredTitle => 'アップデートが必要です';

  @override
  String get reportSheetUpdateAvailableTitle => 'アップデートがあります';

  @override
  String get reportSheetUpdateMandatoryBody =>
      'このバージョンは古すぎて正常に動作しません。続けるにはアップデートしてください。';

  @override
  String get reportSheetUpdateAvailableBody => 'MonkeyHubの新しいバージョンが利用できます。';

  @override
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  ) {
    return 'v$currentVersion → v$newVersion';
  }

  @override
  String get reportSheetUpdateButtonTitle => 'アップデート';

  @override
  String get reportSheetUpdateActionOpensTestflight => 'TestFlightが開きます';

  @override
  String get reportSheetUpdateActionOpensAppStore => 'App Storeが開きます';

  @override
  String get reportSheetUpdateActionOpensGooglePlay => 'Google Playを開きます';

  @override
  String get reportSheetUpdateActionOpensDownloadPage => 'ダウンロードページを開きます';

  @override
  String get reportSheetUpdateActionReloads => '新しいバージョンで再読み込みします';

  @override
  String get reportSheetUpdateLaterSemanticLabel => 'あとで';

  @override
  String get reportSheetUpdateLaterButton => 'あとで';

  @override
  String get roomFilterBarAllChipLabel => 'すべて';

  @override
  String roomFilterBarChipCountSemanticLabel(num count, Object label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のチャット',
    );
    return '$label、$_temp0';
  }

  @override
  String composerReplyCardReplyingToLabel(Object name) {
    return '$nameへの返信';
  }

  @override
  String get roomCardLockedBadge => 'ロック';

  @override
  String get roomCardTimeAgoJustNow => 'たった今';

  @override
  String roomCardTimeAgoSeconds(Object seconds) {
    return '$seconds秒';
  }

  @override
  String roomCardTimeAgoMinutes(Object minutes) {
    return '$minutes分';
  }

  @override
  String roomCardTimeAgoHours(Object hours) {
    return '$hours時間';
  }

  @override
  String roomCardTimeAgoDays(Object days) {
    return '$days日';
  }

  @override
  String roomCardTimeAgoWeeks(Object weeks) {
    return '$weeks週間';
  }

  @override
  String roomCardStartedAgo(Object ago) {
    return '$agoに作成';
  }

  @override
  String roomCardMemberCount(Object count) {
    return '$count人が参加中';
  }

  @override
  String get roomCardMessagesFadeLabel => '消えるメッセージ';

  @override
  String get roomCardEnterLabel => '↗ 入る';

  @override
  String get roomCardBlockedScreenTitle => 'ブロック済み';

  @override
  String get roomCardBlockedEmptyState => 'まだ誰もブロックしていません。';

  @override
  String get roomCardUnblockButton => 'ブロック解除';

  @override
  String get attachmentMenuPhotoLabel => '写真';

  @override
  String get attachmentMenuVideoLabel => '動画';

  @override
  String get attachmentMenuCameraLabel => 'カメラ';

  @override
  String get attachmentMenuVoiceLabel => '音声';

  @override
  String get attachmentMenuFileLabel => 'ファイル';

  @override
  String get attachmentMenuConnectionRetrying => '再試行中…';

  @override
  String get attachmentMenuConnectionCantReachServer => 'サーバーに接続できません・タップして再試行';

  @override
  String get attachmentMenuConnectionReconnecting => '再接続中…';

  @override
  String get attachmentMenuConnectionRetrySemanticLabel => '接続を再試行';

  @override
  String get roomGridTileEmptyLastMessage => 'まだ静かです';

  @override
  String get roomGridTileMemberCountLabel => '参加中';

  @override
  String get roomGridTileThemeChipLabel => 'テーマ';

  @override
  String get bulkActionBarCancelLabel => 'キャンセル';

  @override
  String get bulkActionBarSelectMessagesLabel => 'メッセージを選択';

  @override
  String bulkActionBarSelectedCountLabel(num count) {
    return '$count件選択中';
  }

  @override
  String get bulkActionBarForwardLabel => '転送';

  @override
  String get bulkActionBarDeleteLabel => '削除';

  @override
  String get bulkActionBarJumpBackLabel => '戻る';

  @override
  String bulkActionBarJumpBackLabelWithDepth(Object depth) {
    return '戻る・$depth';
  }

  @override
  String get bulkActionBarJumpBackSemanticLabel => '移動前の場所に戻る';

  @override
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth) {
    return '移動前の場所に戻る（あと$depth件）';
  }

  @override
  String get bulkActionBarBlockSheetNotNotifiedNote => '相手に通知は届きません。';

  @override
  String get bulkActionBarBlockSheetFriendWarning =>
      '現在フレンドですが、ブロックするとフレンド関係が解除されるため、再びつながるには新しくフレンド申請を送る必要があります。';

  @override
  String get bulkActionBarBlockSheetStrangerWarning =>
      '相手はあなたの検索結果に表示されなくなり、メッセージを送れなくなります。';

  @override
  String get bulkActionBarBlockSheetHeaderLabel => 'ブロック';

  @override
  String bulkActionBarBlockSheetTitle(Object name) {
    return '$nameをブロックしますか？';
  }

  @override
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'この相手と$count件のルームを共有しています',
    );
    return '$_temp0';
  }

  @override
  String get bulkActionBarBlockSheetSharedRoomsNote =>
      'これらのルームはそのまま残ります。退出したい場合は、各ルームの設定からいつでも自分で退出できます。';

  @override
  String get bulkActionBarBlockChoiceTileTitle => 'ブロック';

  @override
  String get bulkActionBarBlockChoiceTileFriendSub =>
      'フレンド関係を解除してブロックします。これまでのチャット履歴はアーカイブに残ります。';

  @override
  String get bulkActionBarBlockChoiceTileStrangerSub =>
      '相手は検索結果から非表示になり、あなたに連絡できなくなります。';

  @override
  String get bulkActionBarBlockDeleteDmTitle => 'ブロックしてDMを削除';

  @override
  String get bulkActionBarBlockDeleteDmSub =>
      '相手とのDMも完全に削除されます。メッセージ、リアクション、メディアファイルがすべて消えます。';

  @override
  String get bulkActionBarBlockSheetCancelSemanticLabel => 'キャンセル';

  @override
  String get bulkActionBarBlockSheetCancelLabel => 'キャンセル';

  @override
  String get bulkActionBarFullScreenIntentDialogTitle => '着信をロック画面に表示';

  @override
  String get bulkActionBarFullScreenIntentDialogBody =>
      '画面がオフのときも本物の電話のように着信音を鳴らすには、MonkeyHubで「全画面通知」をオンにする必要があります。次の画面でそのまま設定に移動します。';

  @override
  String get bulkActionBarBatteryExemptionDialogTitle => '着信を逃さない';

  @override
  String get bulkActionBarBatteryExemptionDialogBody =>
      '端末によっては、バッテリーを節約するためにバックグラウンドのアプリを一時停止し、着信が鳴らないことがあります。着信を確実に受け取れるよう、MonkeyHubを制限なく動作させてください。';

  @override
  String get bulkActionBarDialogNotNowButton => '今はしない';

  @override
  String get bulkActionBarDialogContinueButton => '続ける';

  @override
  String get reactionBubbleJumpToLatestLabel => '最新へ移動';

  @override
  String get reactionBubbleJumpToLatestSemanticLabel => '最新へ移動';

  @override
  String get reactionBubblePickerTitle => 'リアクション';

  @override
  String get reactionBubbleNoRecentsPlaceholder => '最近使った絵文字はまだありません';

  @override
  String get reactionBubbleSearchHint => '絵文字を検索';

  @override
  String get reactionBubbleSearchEmptyPlaceholder => '一致する絵文字なし';

  @override
  String get reactionBubbleSearchBackSemanticLabel => '絵文字一覧に戻る';

  @override
  String get reactionBubblePasswordHint => 'パスワード';

  @override
  String enterPublicRoomJoinWhat(Object roomName) {
    return '$roomNameに参加する';
  }

  @override
  String get enterPublicRoomAskFailedMessage => '今はリクエストを送れませんでした。もう一度お試しください。';

  @override
  String get enterPublicRoomWrongPasswordMessage => 'パスワードが違います';

  @override
  String get enterPublicRoomJoinFailedMessage => '参加できませんでした。もう一度お試しください';

  @override
  String get feedBoardTitle => '今日';

  @override
  String feedBoardEditionLabel(Object number) {
    return '第$number号';
  }

  @override
  String get feedBoardHighlightsLabel => 'ハイライト';

  @override
  String get feedBoardHighlightsEmpty => '今日はまだ何もありません';

  @override
  String get feedBoardPuzzleLabel => 'パズル';

  @override
  String get feedBoardPuzzleEmpty => '今日のパズルはまだ準備中です';

  @override
  String get feedBoardStandingsLabel => 'ライフポイント';

  @override
  String get feedBoardStandingsEmpty => '今日はまだポイントがありません';

  @override
  String get feedBoardActivityLabel => 'アクティビティ';

  @override
  String get feedBoardActivityEmpty => '今日はまだ静かです';

  @override
  String get feedBoardActivityNoFriends => '友だちを追加すると、その一日がここに表示されます';

  @override
  String get feedBoardLoadFailed => 'ボードを読み込めませんでした — 少ししてからもう一度お試しください';

  @override
  String get enterPublicRoomVisibilityPublicLabel => '公開';

  @override
  String get enterPublicRoomVisibilityPrivateLabel => '非公開';

  @override
  String get enterPublicRoomJoinedBadgeLabel => '参加済み';

  @override
  String enterPublicRoomEphemeralBadgeLabel(Object duration) {
    return 'エフェメラル・$duration';
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
    return '$hours時間';
  }

  @override
  String get roomBadgePublicTooltip => 'だれでもこのルームを見つけて参加できます';

  @override
  String get roomBadgePrivateTooltip => '招待制です。「さがす」には表示されません';

  @override
  String get roomBadgeLockedTooltip => '参加するにはルームのパスワードが必要です';

  @override
  String roomBadgeEphemeralTooltip(Object duration) {
    return 'メッセージは$duration後に消えます';
  }

  @override
  String get roomBadgeJoinedTooltip => 'すでにこのルームに参加しています';

  @override
  String get roomInfoSheetDetailsLabel => '詳細';

  @override
  String get roomInfoSheetNoDescription => 'まだ説明はありません';

  @override
  String get roomInfoSheetCreatedLabel => '作成日';

  @override
  String get countBadgeCaptureProtectionLabel => '画面キャプチャ保護';

  @override
  String get countBadgeCaptureProtectionOnAndroidBody =>
      'スクリーンショットや画面録画は、システム上では真っ黒に表示されます。';

  @override
  String get countBadgeCaptureProtectionOnIosBody =>
      '画面録画やミラーリング中は、アプリにプライバシーシールドがかかります。';

  @override
  String get countBadgeCaptureProtectionOffBody =>
      'エフェメラルルーム以外では、スクリーンショットや録画は通常どおり利用できます。';

  @override
  String get countBadgeCaptureProtectionForcedNote =>
      'エフェメラルルーム（秘密の部屋）では、この設定は常に強制的にオンになります。';

  @override
  String get countBadgeShowPasswordTooltip => 'パスワードを表示';

  @override
  String get countBadgeHidePasswordTooltip => 'パスワードを隠す';

  @override
  String get countBadgeProtectedLabel => '保護中';

  @override
  String get countBadgeCaptureShieldActiveBody => '画面録画またはミラーリングが実行中です。';

  @override
  String get countBadgeCaptureShieldReassurance => '録画にあなたの会話が映ることはありません。';

  @override
  String get linkOpenerCouldNotOpenLink => 'リンクを開けませんでした';

  @override
  String get linkOpenerRecoveryBannerSemanticLabel => 'リカバリーフレーズを設定する';

  @override
  String get linkOpenerRecoveryBannerMessage =>
      'リカバリーフレーズ未設定 — このままではアカウントに戻れなくなります。';

  @override
  String get destinationsChatLabel => 'チャット';

  @override
  String get destinationsChatShort => 'チャット';

  @override
  String get destinationsDiscoverLabel => '見つける';

  @override
  String get destinationsDiscoverShort => 'さがす';

  @override
  String get destinationsFeedLabel => 'フィード';

  @override
  String get destinationsFeedShort => 'フィード';

  @override
  String get destinationsSettingsLabel => '設定';

  @override
  String get destinationsSettingsShort => '設定';

  @override
  String get familyRequestStageSenderGuardianLabel => '保護者の承認待ち';

  @override
  String get familyRequestStageRecipientLabel => '相手の返答待ち';

  @override
  String get roomContentTabLabelMedia => 'メディア';

  @override
  String get roomContentTabLabelFiles => 'ファイル';

  @override
  String get roomContentTabLabelVoice => 'ボイス';

  @override
  String get roomContentTabLabelLinks => 'リンク';

  @override
  String get roomContentTabLabelSaved => '保存済み';

  @override
  String get roomContentTabHeaderMedia => 'メディア';

  @override
  String get roomContentTabHeaderFiles => 'ファイル';

  @override
  String get roomContentTabHeaderVoice => 'ボイス';

  @override
  String get roomContentTabHeaderLinks => 'リンク';

  @override
  String get roomContentTabHeaderSaved => '保存済み';

  @override
  String get roomFacetLabelDms => 'DM';

  @override
  String get roomFacetLabelGroups => 'グループ';

  @override
  String get roomFacetLabelPublic => '公開';

  @override
  String get roomFacetLabelPrivate => '非公開';

  @override
  String get roomFacetLabelSecret => 'シークレット';

  @override
  String get roomFacetLabelLocked => 'ロック';

  @override
  String get roomFacetLabelUnread => '未読';

  @override
  String get roomFacetLabelMentions => 'メンション';

  @override
  String get settingsScreenTitle => '設定';

  @override
  String get settingsScreenTagline => '見た目も、使い心地も、あなたらしく。';

  @override
  String get settingsScreenAccountHintChild => 'プロフィール・プライバシー・保護者';

  @override
  String get settingsScreenAccountHintAdult => 'プロフィール・ファミリー・連携アカウント・プライバシー';

  @override
  String get settingsScreenSectionAppearance => '外観';

  @override
  String get settingsScreenSectionChat => 'チャット';

  @override
  String get settingsScreenSectionCompanions => 'コンパニオン';

  @override
  String get settingsScreenSectionGeneral => '一般';

  @override
  String get settingsScreenCheckForUpdatesLabel => 'アップデートを確認';

  @override
  String get settingsScreenUpdateAvailableValue => 'アップデートあり';

  @override
  String get settingsScreenUpdateUpToDateSnackbar => '最新バージョンです。';

  @override
  String get settingsScreenUpdateUnsupportedSnackbar =>
      'このビルドではアップデートを確認できません。';

  @override
  String get settingsScreenUpdateErrorSnackbar =>
      'アップデートを確認できませんでした。後でもう一度お試しください。';

  @override
  String get settingsScreenSectionNotifications => '通知';

  @override
  String get reportProblemRowLabel => '問題を報告';

  @override
  String get reportProblemRowValue => '詳細をお送りください';

  @override
  String get reportProblemIntro =>
      '何が起きたか教えてください。アプリと端末の情報に加えて、そのときアプリが何をしていたかの技術ログも自動的に添付されます。原因の特定に役立つのはこの部分です。';

  @override
  String get reportProblemDescribeLabel => '何が起きたか';

  @override
  String get reportProblemDescribeHint => '画面がちらつく、ボタンが反応しない';

  @override
  String get reportProblemScreenshotsLabel => 'スクリーンショット';

  @override
  String get reportProblemAddScreenshot => 'スクリーンショットを追加';

  @override
  String get reportProblemDetailsLabel => 'あなたの情報';

  @override
  String get reportProblemCopyDetails => '情報をコピー';

  @override
  String get reportProblemCopied => 'コピーしました';

  @override
  String get reportProblemSend => 'レポートを送信';

  @override
  String get reportProblemSent => 'レポートを送信しました。ありがとうございます！';

  @override
  String get reportProblemSendFailed => 'レポートを送信できませんでした。接続を確認してもう一度お試しください。';

  @override
  String get reportProblemTooMany => '短い時間に多くのレポートが送信されました。しばらくしてからお試しください。';

  @override
  String get reportProblemShakeTitle => '問題を報告しますか？';

  @override
  String get reportProblemShakeBody => '端末を振りました。レポート画面を開きますか？';

  @override
  String get reportProblemShakeOpen => '報告する';

  @override
  String get reportProblemShakeDismiss => '今はしない';

  @override
  String get settingsCallDeliveryLockScreenLabel => 'ロック画面の着信';

  @override
  String get settingsCallDeliveryBackgroundLabel => 'バックグラウンド動作';

  @override
  String get settingsCallDeliveryStatusOff => 'タップして許可';

  @override
  String get settingsScreenRowTheme => 'テーマ';

  @override
  String get settingsScreenRowAppLogo => 'アプリロゴ';

  @override
  String get settingsScreenRowGlass => 'ガラス';

  @override
  String get settingsScreenRowChatList => 'チャットリスト';

  @override
  String get settingsScreenRowNavigation => 'ナビゲーション';

  @override
  String get settingsScreenRowChatStyle => 'チャットスタイル';

  @override
  String get settingsScreenRowBubbleStyle => '吹き出しスタイル';

  @override
  String get settingsScreenRowReplyStyle => '返信スタイル';

  @override
  String get settingsScreenValueScrollList => 'スクロールリスト';

  @override
  String get settingsScreenValueGridSheet => 'グリッドシート';

  @override
  String get settingsScreenValueRadialOrb => '放射状オーブ';

  @override
  String get settingsScreenValueBottomPill => '下部カプセル';

  @override
  String get settingsScreenValueCustom => 'カスタム';

  @override
  String settingsScreenValueEdited(Object name) {
    return '$name・編集済み';
  }

  @override
  String get settingsScreenValueClassic => 'クラシック';

  @override
  String get settingsScreenValueCompact => 'コンパクト';

  @override
  String get settingsScreenValueBubbleTailed => 'しっぽ';

  @override
  String get settingsScreenValueBubbleSoft => 'ソフト';

  @override
  String get settingsScreenValueBubblePill => 'カプセル';

  @override
  String get settingsScreenValueBubbleSlab => 'ブロック';

  @override
  String get settingsScreenValueReplyPhantomEcho => 'ゴーストエコー';

  @override
  String get settingsScreenValueReplyStickyNote => '付箋';

  @override
  String get settingsScreenValueReplyComicTail => 'コミックしっぽ';

  @override
  String get settingsScreenValueLogoAuto => '自動';

  @override
  String get settingsScreenValueLogoManual => '手動';

  @override
  String get settingsScreenShowLinkUrlsLabel => 'リンクURLを表示';

  @override
  String get settingsScreenLinksUrlsOnBody => 'プレビューカードと一緒に元のURLも表示されます';

  @override
  String get settingsScreenLinksUrlsOffBody =>
      '現在はプレビューのみ — すっきりした吹き出しで、タップで開けます';

  @override
  String get settingsScreenMenuBarLabel => 'メニューバーアイコン';

  @override
  String get settingsScreenMenuBarOnBody =>
      'MonkeyHub が未読数と一緒にメニューバーに常駐します — クリックでウインドウを表示';

  @override
  String get settingsScreenMenuBarOffBody =>
      '現在オフ — 隠れたウインドウに戻る手段は Dock アイコンだけです';

  @override
  String get settingsScreenSectionCalls => '通話';

  @override
  String get settingsScreenRowVideoQuality => 'ビデオ品質';

  @override
  String get settingsScreenValueVideoQualityAuto => '自動';

  @override
  String get settingsScreenValueVideoQuality1080p => '1080p';

  @override
  String get settingsScreenValueVideoQuality4k => '4K';

  @override
  String get settingsScreenShowNetworkStatsLabel => '通話統計を表示';

  @override
  String get settingsScreenShowNetworkStatsBody =>
      '通話中の解像度、ビットレート、Ping、パケットロスをリアルタイムで表示します';

  @override
  String get videoQualityScreenTitle => 'ビデオ品質';

  @override
  String get videoQualityScreenSubtitle => '送信ビデオの解像度の上限を選んでください';

  @override
  String get videoQualityScreenAutoSubtitle => '接続状況に自動的に適応します';

  @override
  String get videoQualityScreenHd1080Subtitle => 'フルHD — よりシャープですがデータ消費が増えます';

  @override
  String get videoQualityScreenUhd4kSubtitle => '4K — 高速な接続で最適です';

  @override
  String get videoQualityScreenFootnote =>
      '実際の解像度は両方のデバイスのカメラとネットワーク状況によって異なります。';

  @override
  String get callScreenControlOptions => 'その他';

  @override
  String get callScreenStatsRttLabel => 'RTT';

  @override
  String get callScreenStatsJitterLabel => 'ジッター';

  @override
  String get callScreenStatsLossLabel => 'ロス';

  @override
  String get callScreenSwapPreviewSemanticLabel => 'カメラ表示を切り替え';

  @override
  String get callOptionsSheetTitle => '通話オプション';

  @override
  String get settingsScreenPushNotificationsLabel => 'プッシュ通知';

  @override
  String get settingsScreenPushOnBody => '新着メッセージやリクエストをお知らせします';

  @override
  String get settingsScreenPushOffBody => '通知なし — アプリを開いたときだけ確認できます';

  @override
  String get settingsScreenGameRemindersLabel => '毎日のゲーム通知';

  @override
  String get settingsScreenGameRemindersOnBody => 'お昼に一度だけ、まだ遊んでいないときに';

  @override
  String get settingsScreenGameRemindersOffBody => '通知なし — ゲームはいつでもそこにあります';

  @override
  String get authErrorUsernameTaken => 'そのユーザー名はすでに使われています。';

  @override
  String get authErrorUsernameReserved => 'そのユーザー名は使用できません。別の名前を選んでください。';

  @override
  String get authErrorDisplayNameReserved => 'その名前は使用できません。別の名前を選んでください。';

  @override
  String get authErrorUserNotFound => 'そのユーザー名のアカウントは見つかりませんでした。';

  @override
  String get authErrorWrongPassword => 'パスワードが違います。';

  @override
  String get authErrorInvalidRecoveryKey => 'そのユーザー名とリカバリーフレーズが一致しません。';

  @override
  String get authErrorTooManyAttempts => '試行回数が多すぎます。15分待ってからもう一度お試しください。';

  @override
  String get authErrorChildMustPair => 'それはお子様用のアカウントです。保護者にペアリングコードをもらってください。';

  @override
  String get authErrorPairingCodeExpired => 'そのコードは期限切れです。新しいコードをもらってください。';

  @override
  String get authErrorPairingCodeInvalid =>
      'そのコードは使用できませんでした。すでに使われている可能性があります。';

  @override
  String get authErrorUseSocialSignIn =>
      'そのアカウントはAppleまたはGoogleでサインインします。下のボタンをご利用ください。';

  @override
  String get authErrorSocialTokenInvalid => 'サインインに失敗しました。もう一度お試しください。';

  @override
  String get authErrorSocialNonceMismatch => 'サインインを完了できませんでした。もう一度お試しください。';

  @override
  String get authErrorSocialMisconfig =>
      'サインイン機能がまだ準備できていません。しばらくしてからもう一度お試しください。';

  @override
  String get authErrorSocialLinkedToOtherAccount =>
      'そのAppleまたはGoogleアカウントは、すでに別のMonkeyHubアカウントに連携されています。';

  @override
  String get authErrorSocialAlreadyLinked => 'すでにこのアカウントに連携されています。';

  @override
  String get authErrorSocialNotLinked => 'このアカウントには連携されていません。';

  @override
  String get authErrorSocialLastCredential =>
      'サインインできる唯一の方法です。先にパスワードを設定してください。';

  @override
  String get authErrorUsernameInvalid => 'ユーザー名は1〜32文字で入力してください。';

  @override
  String get authErrorUsernameChangedRecently =>
      '最近ユーザー名を変更しています。前回の変更から30日後に再度変更できます。';

  @override
  String get authErrorInboxHandleLocked => 'このアカウントは全員の問題報告を受け取るため、ユーザー名は固定です。';

  @override
  String get glassKnobLabelFrost => 'すりガラス';

  @override
  String get glassKnobHintFrost => 'ガラスに乗る白さの量。下げると透け感が出ます';

  @override
  String get glassKnobLabelBlur => 'ぼかし';

  @override
  String get glassKnobHintBlur => '上限で全面すりガラス、下限で透明なガラスに';

  @override
  String get glassKnobLabelSaturation => '色のにじみ';

  @override
  String get glassKnobHintSaturation => 'ぼかしの中でどれだけ色が残るか。2を超えるとポスタリゼーションが起きます';

  @override
  String get glassKnobLabelRimOpacity => '縁';

  @override
  String get glassKnobHintRimOpacity => 'ガラスの縁の明るさ。0にすると枠線が消えます';

  @override
  String get glassKnobLabelRimWidth => '縁の太さ';

  @override
  String get glassKnobHintRimWidth => 'その輪郭線の太さ';

  @override
  String get glassKnobLabelShadowOpacity => '影';

  @override
  String get glassKnobHintShadowOpacity => '背面からどれだけ浮いて見えるか';

  @override
  String get glassKnobLabelShadowBlur => '影の広がり';

  @override
  String get glassKnobHintShadowBlur => '柔らかく広がるか、引き締まって濃くなるか';

  @override
  String get glassKnobLabelShadowY => '影の下がり';

  @override
  String get glassKnobHintShadowY => 'サーフェスからどれだけ下にずれるか';

  @override
  String get glassKnobLabelBarMargin => '左右の間隔';

  @override
  String get glassKnobHintBarMargin => 'バーと画面端の間隔';

  @override
  String get glassKnobLabelBarBottom => '下の間隔';

  @override
  String get glassKnobHintBarBottom => 'バーが下からどれだけ浮くか';

  @override
  String get glassKnobLabelShellPadH => '端のパディング';

  @override
  String get glassKnobHintShellPadH => 'バーの端から最初のカプセルまでの余白。小さすぎると端が浮いて見えます';

  @override
  String get glassKnobLabelShellPadV => '上のパディング';

  @override
  String get glassKnobHintShellPadV => 'バーの端からカプセルの上端までの余白';

  @override
  String get glassKnobLabelIndicatorInset => 'カプセルの内側余白';

  @override
  String get glassKnobHintIndicatorInset => '選択中のカプセルが枠の内側にどれだけ入り込むか';

  @override
  String get glassKnobLabelSegmentPadV => '行のパディング';

  @override
  String get glassKnobHintSegmentPadV => 'アイコンとラベルの上下の余白';

  @override
  String get glassKnobLabelIconLabelGap => 'アイコン間隔';

  @override
  String get glassKnobHintIconLabelGap => 'アイコンとその下の文字との間隔';

  @override
  String get glassKnobLabelIconSize => 'アイコンサイズ';

  @override
  String get glassKnobLabelLabelSize => 'ラベルサイズ';

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
  String get settingsScreenRowMotion => 'モーション';

  @override
  String get settingsScreenValueMotionFull => 'フル';

  @override
  String get settingsScreenValueMotionCalm => '控えめ';

  @override
  String get settingsScreenValueMotionSystemFull => '端末に合わせる · フル';

  @override
  String get settingsScreenValueMotionSystemCalm => '端末に合わせる · 控えめ';

  @override
  String get motionScreenTitle => 'モーション。';

  @override
  String get motionScreenSubtitle => 'アプリの動きの量';

  @override
  String get motionScreenSystemLabel => '端末に合わせる';

  @override
  String get motionScreenSystemSubtitleFull => '現在、端末はアニメーションを許可しています';

  @override
  String get motionScreenSystemSubtitleCalm => '現在、端末は動きを減らすよう求めています';

  @override
  String get motionScreenFullLabel => 'フル';

  @override
  String get motionScreenFullSubtitle => '漂い、光、装飾のすべて';

  @override
  String get motionScreenCalmLabel => '控えめ';

  @override
  String get motionScreenCalmSubtitle => '装飾は静止します — ほかは変わりません';

  @override
  String get momentRailCaptureLabel => '撮る';

  @override
  String get momentRailYouLabel => 'あなた';

  @override
  String momentRailCardSemanticLabel(Object author, Object caption) {
    return '$author：$caption';
  }

  @override
  String get momentTagFate => '偶然';

  @override
  String get momentTagJinx => '自爆';

  @override
  String get momentTagLuck => '幸運';

  @override
  String get momentTagCalledIt => '言ったとおり';

  @override
  String get momentTagNpc => 'NPC';

  @override
  String get momentTagFateHint => 'すごい偶然';

  @override
  String get momentTagJinxHint => '自分で招いた';

  @override
  String get momentTagLuckHint => 'うまくいった';

  @override
  String get momentTagCalledItHint => '予言どおり';

  @override
  String get momentTagNpcHint => '頭が完全にオフ';

  @override
  String get momentComposerTitle => '新しいハイライト';

  @override
  String get momentComposerCaptionHint => 'ひとこと添えて';

  @override
  String get momentComposerTagPrompt => 'ポイント獲得？ いま追加';

  @override
  String get momentComposerCapture => 'カメラ';

  @override
  String get momentComposerLibrary => 'ライブラリ';

  @override
  String get momentComposerRemovePhoto => '写真を削除';

  @override
  String get momentComposerPost => '投稿';

  @override
  String get momentComposerErrorDailyCap => '今日はもう5件 — 明日の分も残して';

  @override
  String get momentComposerErrorNotAllowed => '保護者が写真の共有をオフにしています';

  @override
  String get momentComposerErrorTooLong => '少し長すぎます — 短くしてください';

  @override
  String get momentComposerErrorEmpty => '写真か、ひとことを追加してください';

  @override
  String get momentComposerErrorGeneric => '投稿できませんでした — もう一度お試しください';

  @override
  String get momentViewerDelete => '削除';

  @override
  String get momentViewerDeleteConfirmHeadline => 'これを削除しますか？';

  @override
  String get momentViewerDeleteConfirmBody => 'みんなのボードからもアーカイブからも完全に消えます';

  @override
  String get momentViewerDeleteFailed => '削除できませんでした — もう一度お試しください';

  @override
  String momentActivityPostedHighlight(Object who) {
    return '$whoがハイライトを投稿';
  }

  @override
  String momentActivityScored(Object name, Object tag) {
    return '$nameがポイント獲得：$tag';
  }

  @override
  String get momentActivityJustNow => 'たった今';

  @override
  String momentActivityMinutesAgo(Object count) {
    return '$count分';
  }

  @override
  String momentActivityHoursAgo(Object count) {
    return '$count時間';
  }

  @override
  String momentActivityMoreCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今日はあと$count件',
    );
    return '$_temp0';
  }

  @override
  String get puzzleScreenTitle => 'パズル。';

  @override
  String get puzzleScreenSubtitle => '4つの記号、6回まで';

  @override
  String get puzzleSubmit => '予想する';

  @override
  String get puzzleBackspace => '最後の記号を削除';

  @override
  String puzzleSymbolSemanticLabel(Object number) {
    return '記号 $number';
  }

  @override
  String puzzleSolvedTitle(Object count) {
    return '$count回で正解';
  }

  @override
  String get puzzleFailedTitle => '回数切れ';

  @override
  String get puzzleAnswerWas => '正解はこちら';

  @override
  String get puzzleShare => '結果をコピー';

  @override
  String get puzzleShareCopied => 'コピーしました — 友だちに貼り付けて';

  @override
  String puzzleShareHeader(Object edition, Object score) {
    return 'MonkeyHub №$edition $score/6';
  }

  @override
  String get puzzleErrorAlreadySolved => '今日の分はすでに解けています';

  @override
  String get puzzleErrorOutOfGuesses => '今日の回数は残っていません';

  @override
  String get puzzleErrorGeneric => '送信できませんでした — もう一度お試しください';

  @override
  String get puzzleGuessWaiting => '接続がありません。予想は保存済みで、つながり次第送信されます';

  @override
  String get gameSubmitWaiting => '接続がありません。完成した盤面は保存済みで、つながり次第送信されます';

  @override
  String get puzzleScoreboardLabel => '今日のスコア';

  @override
  String get puzzleScoreboardEmpty => '今日はまだ誰も終えていません';

  @override
  String get puzzleTilePlay => '今日のパズルで遊ぶ';

  @override
  String puzzleTileInProgress(Object count) {
    return '残り$count回';
  }

  @override
  String puzzleTileRank(Object rank, Object total) {
    return '$total人中 #$rank';
  }

  @override
  String get profileVisibilityScreenSectionFeed => 'フィード';

  @override
  String get profileVisibilityScreenFeedLabel => 'わたしのハイライト';

  @override
  String get profileVisibilityScreenFeedDesc =>
      '投稿した写真や動画がその日、友だちのボードに表示されるかどうか';

  @override
  String get profileVisibilityScreenPuzzleLabel => 'わたしのパズル結果';

  @override
  String get profileVisibilityScreenPuzzleDesc => '日々のパズルの成績を友だちが見られるかどうか';

  @override
  String get profileVisibilityScreenPointsPastLabel => 'わたしの過去';

  @override
  String get profileVisibilityScreenPointsPastDesc =>
      '今日はつねに友だちと共有されます — これはそれ以前のすべてを開きます';

  @override
  String get momentComposerVideo => '動画';

  @override
  String get momentComposerErrorTooBig => 'この動画は大きすぎます — 最大20MB';

  @override
  String get momentActivityPostedHighlightSelf => 'ハイライトを投稿しました';

  @override
  String momentActivityScoredSelf(Object tag) {
    return 'ポイント獲得：$tag';
  }

  @override
  String pointLineSelf(Object tag) {
    return 'あなた · $tag';
  }

  @override
  String pointLineOther(Object name, Object tag) {
    return '$name · $tag';
  }

  @override
  String get pointComposerTitle => '何があった？';

  @override
  String get pointComposerNoteHint => '上からひとつ選んで、そのあと書いてください';

  @override
  String get pointComposerAdd => 'ポイントを追加';

  @override
  String get pointComposerAddPhoto => '写真を追加';

  @override
  String get pointsBoardAdd => 'ポイントを追加';

  @override
  String get pointsExplainerOpen => 'これは何？';

  @override
  String get pointsExplainerTitle => 'ポイントのゲーム';

  @override
  String get pointsExplainerIntro =>
      '点数をつけて楽しむ、続きもののネタです。よいことも悪いことも、ただ妙なことも、起きたら記録すればその日のボードに載ります。';

  @override
  String get pointsExplainerRuleHonour =>
      'ポイントは自己申告です。誰も確認しません — そこが面白いところで、やりすぎれば友だちが言ってくれます。';

  @override
  String get pointsExplainerRuleToday =>
      'ポイントは毎日リセットされます。ボードは今日の分で、自分の履歴は残ります。';

  @override
  String get pointsExplainerRuleCap => '同じ種類は1日5件まで。ボードが意味をなさなくなるのを防ぐためです。';

  @override
  String get pointsExplainerGotIt => 'わかった';

  @override
  String get momentTagFateExample => '別の国で歯医者にばったり会った';

  @override
  String get momentTagJinxExample => '洗車したら4時に雨が降った';

  @override
  String get momentTagLuckExample => '2秒差で電車に間に合った';

  @override
  String get momentTagCalledItExample => '続編はコケると言ったら、本当にコケた';

  @override
  String get momentTagNpcExample => '店員に「あなたも」と言ってしまった';

  @override
  String feedBoardEditionHint(Object number) {
    return 'フィード$number日目';
  }

  @override
  String get feedBoardHighlightsHint => '見る価値のある写真と動画';

  @override
  String get profileVisibilityScreenPointsLabel => 'わたしのポイント';

  @override
  String get profileVisibilityScreenPointsDesc => '記録したポイントを友だちのボードに表示するかどうか';

  @override
  String get momentComposerEditPhoto => 'トリミングを編集';

  @override
  String get archiveScreenTitle => 'あなたのアーカイブ';

  @override
  String get archiveScreenEnd => '以上です';

  @override
  String get archiveScreenEmptyTitle => 'まだ何も残っていません';

  @override
  String get archiveScreenEmptyBody => '投稿は1日で友だちのボードから消えますが、ここにはあなたのために残ります。';

  @override
  String get archiveScreenEmptyFriendTitle => 'ここには何もありません';

  @override
  String get archiveScreenEmptyFriendBody => 'まだあなたが見られる投稿はありません。';

  @override
  String get archiveScreenPrivateTitle => 'この人の過去は非公開です';

  @override
  String get archiveScreenPrivateBody => '今日の投稿はこれまでどおり見られます。';

  @override
  String get archiveScreenNotFriendTitle => '友だちではありません';

  @override
  String get archiveScreenNotFriendBody => '友だちの過去の日だけをさかのぼれます。';

  @override
  String get archiveScreenErrorTitle => '読み込めませんでした';

  @override
  String get archiveScreenErrorBody => '接続を確認してもう一度お試しください。';

  @override
  String get feedBoardOpenArchive => 'アーカイブ';

  @override
  String get feedBoardGamesLabel => 'ゲーム';

  @override
  String get feedBoardGamesOpen => 'ランキング';

  @override
  String get gamesScreenTitle => 'ゲーム。';

  @override
  String get gamesScreenSubtitle => '毎日4つの盤面、全員が同じもの';

  @override
  String gamesRemaining(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今日は残り$countつ',
      one: '今日は残り1つ',
      zero: '今日はすべて完了',
    );
    return '$_temp0';
  }

  @override
  String get gamesLoadFailed => '今日のゲームを読み込めませんでした';

  @override
  String get gamesRetry => '再試行';

  @override
  String get gameQueensName => 'クイーンズ';

  @override
  String get gameQueensRule => '各行・各列・各色に王冠1つ、隣接は不可';

  @override
  String get gameTangoName => 'タンゴ';

  @override
  String get gameTangoRule => '太陽3つ、月3つ、同じものが3つ続かない';

  @override
  String get gameZipName => 'ジップ';

  @override
  String get gameZipRule => 'すべてのマスを通る1本の線、数字は順番どおり';

  @override
  String get gameSudokuName => 'ミニ数独';

  @override
  String get gameSudokuRule => '各行・各列・各ブロックに1〜6を1回ずつ';

  @override
  String get gameCodeName => 'コード';

  @override
  String get gameStatusUnplayed => '未プレイ';

  @override
  String get gameStatusUnfinished => 'プレイ中';

  @override
  String get gameStatusGaveUp => 'ギブアップ';

  @override
  String gameRankBadge(Object rank) {
    return '$rank位';
  }

  @override
  String get gamePause => '一時停止';

  @override
  String get gameResume => '再開';

  @override
  String get gamePausedTitle => '一時停止中';

  @override
  String get gamePausedBody => '時計は止まり、盤面は隠れています';

  @override
  String get gameUndo => '元に戻す';

  @override
  String get gameClear => 'クリア';

  @override
  String get gameHint => 'ヒント';

  @override
  String get gameNotes => 'メモ';

  @override
  String get gameErase => '消す';

  @override
  String get gameAutoCross => '自動バツ';

  @override
  String get gameGiveUp => 'ギブアップ';

  @override
  String get gameGiveUpTitle => '答えを表示しますか？';

  @override
  String get gameGiveUpBody => '今日の盤面は終了し、未解決として記録されます。';

  @override
  String get gameGiveUpCancel => '続ける';

  @override
  String get gameGiveUpConfirm => '表示する';

  @override
  String gameSolvedTitle(Object time) {
    return '$time でクリア';
  }

  @override
  String get gameGaveUpTitle => '今日の答え';

  @override
  String get gameFirstInToday => '今日の一番乗り';

  @override
  String gameRankLine(Object place, Object total) {
    return '現在 $total 人中 $place 位';
  }

  @override
  String gameMistakeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ミス $count 回',
      one: 'ミス 1 回',
    );
    return '$_temp0';
  }

  @override
  String gameHintCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ヒント $count 回',
      one: 'ヒント 1 回',
    );
    return '$_temp0';
  }

  @override
  String get gameStandingsLabel => '今日のタイム';

  @override
  String get gameStandingsEmpty => 'まだ誰も終えていません';

  @override
  String get gameShare => '結果をコピー';

  @override
  String get gameShareCopied => 'コピーしました — 友だちに貼り付けて';

  @override
  String gameShareLine(Object name, Object number, Object time) {
    return 'MonkeyHub $name №$number — $time';
  }

  @override
  String get gameBackToHub => 'すべて';

  @override
  String get gameElapsedSemantic => '経過時間';

  @override
  String get gameErrorNotSolved => 'その盤面はまだ完成していません';

  @override
  String get gameErrorAlreadyFinished => '今日の分はもう終えています';

  @override
  String get gameErrorNoHint => 'これにはヒントがありません';

  @override
  String get gameErrorGeneric => 'ゲームに接続できませんでした — もう一度お試しください';

  @override
  String get gameInfoOpen => '遊び方';

  @override
  String get gameInfoLabel => '遊び方';

  @override
  String get gameInfoRulesLabel => 'ルール';

  @override
  String get gameInfoControlsLabel => 'タップのしかた';

  @override
  String get gameInfoScoringTimed => 'いちばん早く解いた人の勝ち。画面を離れると時計は止まります。';

  @override
  String get gameInfoScoringGuesses => '少ない回数で当てた人の勝ち。時間は関係ありません。';

  @override
  String get gameInfoSameForEveryone => '今日はみんな同じパズルです。';

  @override
  String get gameInfoQueensGoal => '盤に王冠を8つ置こう。';

  @override
  String get gameInfoQueensRule1 => 'どの横の列にも王冠は1つだけ。';

  @override
  String get gameInfoQueensRule2 => 'どの縦の列にも王冠は1つだけ。';

  @override
  String get gameInfoQueensRule3 => 'どの色にも王冠は1つだけ。';

  @override
  String get gameInfoQueensControls => '1回タップで×（ここには置かない）。2回で王冠。もう1回で消す。';

  @override
  String get gameInfoTangoGoal => '全部のマスに太陽か月を入れよう。';

  @override
  String get gameInfoTangoRule1 => 'どの横の列も太陽3つと月3つ。';

  @override
  String get gameInfoTangoRule2 => 'どの縦の列も太陽3つと月3つ。';

  @override
  String get gameInfoTangoRule3 => '同じものを3つ続けて並べない。2つならOK。';

  @override
  String get gameInfoTangoControls =>
      '1回タップで太陽、2回で月、もう1回で消す。最初から入っているマスは変えられません。';

  @override
  String get gameInfoZipGoal => '全部のマスを通る1本の線を引こう。';

  @override
  String get gameInfoZipRule1 => '1からスタート。';

  @override
  String get gameInfoZipRule2 => '数字を順番に通る：1、2、3…';

  @override
  String get gameInfoZipRule3 => '全部のマスを通る。同じマスは1回だけ。';

  @override
  String get gameInfoZipControls => '指でなぞって線を引く。戻ると消えます。';

  @override
  String get gameInfoSudokuGoal => 'マスを1〜6の数字でうめよう。';

  @override
  String get gameInfoSudokuRule1 => 'どの横の列にも1・2・3・4・5・6。同じ数字はダメ。';

  @override
  String get gameInfoSudokuRule2 => '縦の列も同じ。';

  @override
  String get gameInfoSudokuRule3 => 'ブロックも同じ。ブロックは2行×3列。';

  @override
  String get gameInfoSudokuControls =>
      'マスをタップして、数字をタップ。もう一度押すと消えます。メモで小さな数字を書けます。';

  @override
  String get gameInfoCodeGoal => '4つの記号のひみつのコードを当てよう。';

  @override
  String get gameInfoCodeRule1 => 'コードは4つともちがう記号。同じ記号はなし。';

  @override
  String get gameInfoCodeRule2 => 'チャンスは6回。';

  @override
  String get gameInfoCodeRule3 => '緑：記号も場所も正解。';

  @override
  String get gameInfoCodeControls => '記号を4つタップして、「予想する」をタップ。';

  @override
  String get savedMessagesTitle => '保存済みメッセージ';

  @override
  String homeScreenNoSearchResults(Object query) {
    return '「$query」に一致するチャットはありません';
  }

  @override
  String get pullRevealSearchHint => 'チャットを検索';

  @override
  String get pullRevealCollapseSemanticLabel => '検索とアーカイブ済みチャットを非表示';

  @override
  String archivedChatsFolderLabel(Object count) {
    return 'アーカイブ済みチャット ($count)';
  }

  @override
  String get archivedChatsFolderTitle => 'アーカイブ済みチャット';

  @override
  String get pullRevealClearSearchSemanticLabel => '検索をクリア';

  @override
  String get archivedChatsSheetTitle => 'アーカイブ済みチャット';

  @override
  String archivedChatsSheetTitleCount(Object count) {
    return 'アーカイブ済みチャット・$count';
  }

  @override
  String get archivedChatsSheetEmptyMessage => 'もうアーカイブされたものはありません';

  @override
  String get pinnedBadgeLabel => 'ピン留め';

  @override
  String get chatRowActionMenuPinLabel => 'チャットをピン留め';

  @override
  String get chatRowActionMenuUnpinLabel => 'チャットのピン留めを解除';

  @override
  String get chatRowActionMenuArchiveLabel => 'チャットをアーカイブ';

  @override
  String get chatRowActionMenuUnarchiveLabel => 'チャットのアーカイブを解除';

  @override
  String get messageActionMenuSaveLabel => '保存';

  @override
  String get messageActionMenuUnsaveLabel => '保存を解除';

  @override
  String get roomScreenSaveLimitSnack => 'ここの保存が多すぎます。先に1件解除してください';

  @override
  String get roomScreenSaveFailedSnack => '保存できませんでした';

  @override
  String get threadOverlaySaveLimitToast => 'ここの保存が多すぎます。先に1件解除してください';

  @override
  String get threadOverlaySaveFailedToast => '保存できませんでした';

  @override
  String get roomInfoScreenSharedContentSavedNote =>
      '保存したメッセージが見えるのはあなただけです。ピン留めしたメッセージはその逆で、ルーム全員に見えます。';

  @override
  String get roomInfoScreenOwnerBadgeNote => '名前の横にある小さいメダルは、このルームを作成した人を示します。';

  @override
  String roomContentScreenSavedJumpSemantic(Object name) {
    return '$nameの保存したメッセージにジャンプ';
  }

  @override
  String roomContentScreenUnsaveSemantic(Object name) {
    return '$nameのメッセージの保存を解除';
  }

  @override
  String get muteSheetTitle => 'チャットをミュート';

  @override
  String get muteSheetSubtitle => '何を静かにするか、どのくらいの間かを選びます。';

  @override
  String get muteSheetNotificationsTitle => '通知';

  @override
  String get muteSheetNotificationsSub => 'バナーなし、音なし';

  @override
  String get muteSheetBadgesTitle => '未読件数';

  @override
  String get muteSheetBadgesSub => 'チャットに数字を出さず、アプリアイコンにも足しません';

  @override
  String get muteSheetDurationLabel => 'ミュートする期間';

  @override
  String get muteDurationHour => '1時間';

  @override
  String get muteDurationEightHours => '8時間';

  @override
  String get muteDurationWeek => '1週間';

  @override
  String get muteDurationAlways => 'ずっと';

  @override
  String get muteSheetConfirmButton => 'ミュート';

  @override
  String get muteSheetSaveButton => '保存';

  @override
  String get muteSheetUnmuteButton => 'ミュート解除';

  @override
  String get muteSummaryAll => 'このチャットからは何も届きません。通知も未読件数もありません。';

  @override
  String get muteSummaryNotificationsOnly => '通知はありません。未読件数は増え続けます。';

  @override
  String get muteSummaryBadgesOnly => '未読件数は表示されません。通知は届きます。';

  @override
  String get muteSummaryNothingPicked => '静かにするものを少なくとも1つ選んでください。';

  @override
  String muteUntilSentence(String when) {
    return '$when まで。';
  }

  @override
  String get muteUntilAlwaysSentence => '自分で解除するまでずっと。';

  @override
  String muteUntilDateAndTime(String date, String time) {
    return '$date $time';
  }

  @override
  String get mutedBadgeLabel => 'ミュート中';

  @override
  String get chatRowActionMenuMuteLabel => 'チャットをミュート';

  @override
  String get chatRowActionMenuUnmuteLabel => 'ミュートを解除';

  @override
  String get roomInfoScreenMuteLabel => 'ミュート';

  @override
  String get roomInfoScreenNotMutedRow => 'ミュートしていません';

  @override
  String get attachmentMenuLocationLabel => '位置情報';

  @override
  String get locationSheetSendCurrent => '現在地を送信';

  @override
  String get locationSheetSendCurrentDetail => 'いまいる場所';

  @override
  String get locationSheetLiveHeading => 'リアルタイム共有';

  @override
  String get locationSheetLiveDetail => '自動で終了します';

  @override
  String get locationShareFor15Minutes => '15分間';

  @override
  String get locationShareFor1Hour => '1時間';

  @override
  String get locationShareFor8Hours => '8時間';

  @override
  String get locationBubbleOpenInMaps => '地図アプリで開く';

  @override
  String get locationBubbleLiveBadge => 'ライブ';

  @override
  String get locationBubbleEndedBadge => '終了';

  @override
  String locationBubbleLiveUntil(String time) {
    return '$timeまで共有中';
  }

  @override
  String locationBubbleLiveEnded(String time) {
    return 'リアルタイムの位置情報は$timeに終了しました';
  }

  @override
  String get locationBubbleNoRecentUpdate => '最近の更新がありません';

  @override
  String locationBubbleAccuracy(int meters) {
    return '±$meters m';
  }

  @override
  String get locationBubbleStopSharing => '共有を停止';

  @override
  String get locationBubbleUnavailable => '位置情報を表示できません';

  @override
  String get locationBubbleNoMapsApp => '開ける地図アプリがありません';

  @override
  String get locationBubbleCoordinatesCopied => '座標をコピーしました';

  @override
  String get locationCouldNotGetFix => '現在地を取得できませんでした';

  @override
  String get locationCouldNotStartLiveShare => 'リアルタイム共有を開始できませんでした';

  @override
  String get locationPermissionNeeded => '現在地を共有するには位置情報へのアクセスが必要です';

  @override
  String get locationPermissionBlockedTitle => '位置情報へのアクセスがオフです';

  @override
  String get locationPermissionBlockedBody =>
      'MonkeyHubはここから再度リクエストできません。設定でMonkeyHubの位置情報アクセスをオンにしてください。';

  @override
  String get locationServicesOffTitle => '位置情報サービスがオフです';

  @override
  String get locationServicesOffBody =>
      'この端末で位置情報がオフになっています。現在地を共有するには設定でオンにしてください。';

  @override
  String get locationOpenSettings => '設定を開く';

  @override
  String get locationBackgroundSheetTitle => '端末が再起動したら';

  @override
  String get locationBackgroundSheetBody =>
      'MonkeyHub を離れてもライブ共有は続きます。バックグラウンドの許可は残りを引き受けます — 再起動、強制終了、バッテリー切れからの復帰。';

  @override
  String get locationBackgroundSheetKeepRunning => '自動で再開する';

  @override
  String get locationBackgroundSheetKeepRunningDetail => '端末が許可を求めます';

  @override
  String get locationBackgroundSheetAppOnly => 'そのまま止める';

  @override
  String get locationBackgroundSheetAppOnlyDetail => '追加の許可は不要';

  @override
  String get locationServiceNotificationTitle => '現在地をライブ共有中';

  @override
  String get locationServiceNotificationBody => 'タップでチャットを開く、停止で今すぐ終了';

  @override
  String get childPolicyScreenLocationLabel => '位置情報';

  @override
  String get childPolicyScreenLocationOnDesc => '現在地を共有できます（最長8時間のリアルタイム共有を含む）';

  @override
  String get childPolicyScreenLocationOffDesc => '現在地を共有できません';

  @override
  String get roomInfoScreenSavedMessagesLabel => '保存したメッセージ';

  @override
  String get roomInfoScreenSavedMessagesCaption =>
      'これらはあなたにしか見えず、このルームのものだけです。保存済みメッセージのチャットとは別です。';

  @override
  String get roomInfoScreenSavedMessagesEmpty =>
      'まだ何も保存されていません。メッセージを長押しして「保存」を選んでください。';

  @override
  String roomInfoScreenSavedMessageJumpSemantic(Object name) {
    return '$nameの保存したメッセージにジャンプ';
  }

  @override
  String roomInfoScreenSavedMessageUnsaveSemantic(Object name) {
    return '$nameのメッセージの保存を解除';
  }

  @override
  String get composerCaptureCameraModeLabel => 'カメラ';

  @override
  String get composerCaptureVoiceModeLabel => 'ボイスメッセージ';

  @override
  String get composerCaptureVideoNoteModeLabel => 'ビデオメッセージ';

  @override
  String composerCaptureModeButtonLabel(String mode) {
    return '$mode。2本指でスワイプするか矢印キーでモードを変更できます。';
  }

  @override
  String composerCaptureModeAnnouncement(String mode) {
    return '$modeを選択しました';
  }

  @override
  String get composerCaptureRecordingAnnouncement => '録音を開始しました';

  @override
  String get composerCaptureLockedAnnouncement => '録音をロックしました。手を離せます。';

  @override
  String get composerCaptureCancelledAnnouncement => '録音を破棄しました';

  @override
  String get composerCaptureSentAnnouncement => '録音を送信しました';

  @override
  String composerCaptureRecordingLabel(String elapsed) {
    return '録音中、$elapsed';
  }

  @override
  String get composerCaptureHoldToRecordHint => '長押しで録音、スワイプで切り替え';

  @override
  String get composerCaptureTapForCameraHint => 'タップでカメラ、スワイプで切り替え';

  @override
  String get composerCaptureSlideToCancelHint => 'スライドでキャンセル';

  @override
  String get composerCaptureReleaseToCancelHint => '離してキャンセル';

  @override
  String get composerCaptureTapToSendHint => 'タップで送信';

  @override
  String get composerCaptureSendingLabel => '送信中…';

  @override
  String composerCaptureTimeLeft(int seconds) {
    return '残り$seconds秒';
  }

  @override
  String get composerCaptureCancelLabel => '録音を破棄';

  @override
  String get composerCaptureSendLabel => '録音を送信';

  @override
  String get composerCaptureLockLabel => '上にスライドして録音をロック';

  @override
  String get composerCaptureMicPermissionTitle => 'マイクが必要です';

  @override
  String get composerCaptureMicPermissionBody =>
      'ボイスメッセージを録音するにはマイクが必要です。設定でオンにしてからもう一度お試しください。';

  @override
  String get composerCaptureCameraPermissionTitle => 'カメラが必要です';

  @override
  String get composerCaptureCameraPermissionBody =>
      'ビデオメッセージを録画するにはカメラとマイクが必要です。設定でオンにしてからもう一度お試しください。';

  @override
  String get composerCaptureRestrictedBody => 'この端末の制限により録音・録画が無効になっています。';

  @override
  String get composerCaptureOpenSettingsLabel => '設定を開く';

  @override
  String get composerCaptureUnavailableSnack => 'この端末では録音・録画を利用できません。';

  @override
  String get composerCaptureInterruptedSnack => '録音を停止しました。';

  @override
  String get composerCaptureStorageSnack => '録音を保存できませんでした。空き容量を確認してください。';

  @override
  String get videoNoteMessagePlayLabel => 'ビデオメッセージを再生';

  @override
  String get videoNoteMessagePauseLabel => 'ビデオメッセージを一時停止';

  @override
  String get videoNoteMessageLoadingLabel => 'ビデオメッセージを読み込み中';

  @override
  String get videoNoteMessageUnavailableLabel => 'ビデオメッセージを利用できません';

  @override
  String get videoNoteMessageRetryLabel => 'ビデオメッセージを再試行';

  @override
  String get videoNoteMessageRetryHint => 'タップで再試行';

  @override
  String get videoNoteMessageDiscardLabel => 'ビデオメッセージを破棄';

  @override
  String get attachmentMenuVideoNoteLabel => 'ビデオ';

  @override
  String get cameraScreenPhotoModeLabel => '写真';

  @override
  String get cameraScreenVideoModeLabel => 'ビデオ';

  @override
  String get cameraScreenStartRecordingLabel => '録画を開始';

  @override
  String get cameraScreenStopRecordingLabel => '録画を停止';

  @override
  String get cameraScreenVideoFailedSnack => '動画を録画できませんでした。';

  @override
  String get scheduleSheetTitle => 'メッセージを予約';

  @override
  String get scheduleSheetSubtitle => '今書いて、送るのは好きなときに。';

  @override
  String get scheduleSheetWhenLabel => 'いつ送る';

  @override
  String get schedulePresetInAnHour => '1時間後';

  @override
  String get schedulePresetInEightHours => '8時間後';

  @override
  String get schedulePresetTomorrowMorning => '明日の朝';

  @override
  String get schedulePresetThisMorning => '今朝';

  @override
  String get schedulePresetInAWeek => '1週間後';

  @override
  String get scheduleSheetCustomChip => '日付を選ぶ';

  @override
  String get scheduleSheetConfirmButton => '予約する';

  @override
  String get scheduleSheetSaveButton => '保存';

  @override
  String scheduleSendsAtSentence(String when) {
    return '$whenに送信されます';
  }

  @override
  String scheduleWhenToday(String time) {
    return '今日の$time';
  }

  @override
  String scheduleWhenTomorrow(String time) {
    return '明日の$time';
  }

  @override
  String scheduleWhenDated(String date, String time) {
    return '$dateの$time';
  }

  @override
  String get scheduleTimePickerTitle => '日付と時刻を選ぶ';

  @override
  String get scheduleTimePickerBack => 'かんたん選択';

  @override
  String get scheduleTimePickerToday => '今日';

  @override
  String get scheduleTimePickerTomorrow => '明日';

  @override
  String scheduledPillLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '予約 $count 件',
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
      other: '送信待ちのメッセージが$count件あります。タップして表示します。',
    );
    return '$_temp0';
  }

  @override
  String get scheduledPillAttention => '要確認';

  @override
  String get scheduledListTitle => '予約済み';

  @override
  String get scheduledListSubtitle => '送信されるまで、これらはあなたにしか見えません。';

  @override
  String get scheduledListEmpty => 'ここに送信待ちのものはありません。';

  @override
  String get scheduledListSendNow => '今すぐ送る';

  @override
  String get scheduledListChangeTime => '時刻を変える';

  @override
  String get scheduledListEdit => '本文を編集';

  @override
  String get scheduledListDelete => '削除';

  @override
  String get scheduledListSending => '送信中…';

  @override
  String get scheduledListFailedTitle => '送信できませんでした';

  @override
  String get scheduledListRetry => 'もう一度試す';

  @override
  String get scheduleErrorOutOfRange => '今から2分後〜1年後の間で時刻を選んでください。';

  @override
  String get scheduleErrorTooMany => 'ここで待っているメッセージが多すぎます。まずいくつか送るか削除してください。';

  @override
  String get scheduleErrorNotInEphemeral => 'このチャットのメッセージは自動で消えるため、予約できません。';

  @override
  String get scheduleErrorNotMember => 'あなたはもうこのチャットにいません。';

  @override
  String get scheduleErrorBlocked => 'まずブロックを解除してください。';

  @override
  String get scheduleErrorGeneric => 'うまくいきませんでした。もう一度試してください。';

  @override
  String get scheduleEditTitle => 'メッセージを編集';

  @override
  String get composerScheduleAction => 'このメッセージを予約';

  @override
  String composerScheduledBadgeSemantics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '送信待ちのメッセージ$count件',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAs => '表示方法';

  @override
  String get scheduledIndicatorPill => 'バー';

  @override
  String get scheduledIndicatorBadge => 'バッジ';

  @override
  String get scheduledIndicatorBoth => '両方';

  @override
  String scheduleSheetQueuedRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'すでに$count件が送信待ち',
      zero: '送信待ちのものはありません',
    );
    return '$_temp0';
  }

  @override
  String get scheduledListShowAsRow => '表示のしかた';

  @override
  String get scheduledIndicatorPillSub => '入力欄の上のバー。タップすると一覧が開きます。';

  @override
  String get scheduledIndicatorBadgeSub => '送信ボタンの数字。入力を始めるまで何も表示されません。';

  @override
  String get scheduledIndicatorBothSub => 'バーと、入力中に出る数字の両方。';

  @override
  String get scheduledBack => '戻る';

  @override
  String get serverScreenTitle => 'サーバー。';

  @override
  String get serverScreenSubtitle => 'アカウントとメッセージが置かれる場所';

  @override
  String get serverOnboardingTitle => 'サーバーを選ぶ。';

  @override
  String get serverOnboardingSubtitle =>
      'このビルドにはサーバーが含まれていません。ご自分のサーバーを指定してください';

  @override
  String get serverStatusConnected => '接続中';

  @override
  String get serverStatusDisconnected => '未接続';

  @override
  String get serverBadgeDefault => '既定';

  @override
  String get serverBadgeSelfHosted => 'セルフホスト';

  @override
  String get serverNoneConfigured => 'サーバー未設定';

  @override
  String get serverActiveNowLabel => '使用中';

  @override
  String get serverChoiceCloud => 'MonkeyHub';

  @override
  String get serverChoiceCloudSub => 'このアプリに最初から設定されているサーバーです。';

  @override
  String get serverChoiceOwn => '自分のサーバー';

  @override
  String get serverChoiceOwnSub => '自分で運用している Convex バックエンド。';

  @override
  String get serverAddressHint => 'https://chat.example.com';

  @override
  String get serverAddressPaste => '貼り付け';

  @override
  String get serverProblemMalformed => 'これはウェブアドレスではありません。';

  @override
  String get serverProblemBadScheme => 'https:// または http:// で始めてください。';

  @override
  String get serverProblemNoHost => 'https:// のあとにサーバーのアドレスを入力してください。';

  @override
  String get serverProblemCredentials => 'アドレスからユーザー名とパスワードを取り除いてください。';

  @override
  String get serverInsecureTitle => '暗号化されていません';

  @override
  String get serverInsecureBody =>
      'スマートフォンは平文の http を遮断するため、このアドレスは iOS でも Android でも接続できません。https を使うか、トンネル経由でサーバーに接続してください。';

  @override
  String get serverTestCta => '接続をテスト';

  @override
  String get serverTestingLabel => 'テスト中…';

  @override
  String get serverCheckReachable => '応答がありました';

  @override
  String get serverCheckConvex => 'Convex サーバーです';

  @override
  String get serverCheckApp => 'MonkeyHub が動いています';

  @override
  String get serverResultUnreachable => 'そのアドレスからは応答がありませんでした。';

  @override
  String get serverResultNotConvex => '応答はありましたが、Convex サーバーではありません。';

  @override
  String get serverResultNotThisApp => 'Convex サーバーですが、MonkeyHub は配置されていません。';

  @override
  String get serverResultServerError => 'サーバーは応答しましたが、エラーを返しました。';

  @override
  String get serverResultReady => '接続できます。';

  @override
  String get serverConnectCta => '接続';

  @override
  String get serverConnectAnywayCta => 'それでも接続';

  @override
  String get serverAlreadyConnectedCta => '接続済み';

  @override
  String get serverUseDefaultCta => '既定のサーバーを使う';

  @override
  String get serverChangeCta => 'サーバーを変更';

  @override
  String get serverAdvancedLabel => '詳細設定';

  @override
  String get serverSiteUrlExplain =>
      'ほとんどのサーバーは 1 つのアドレスですべてに応答します。http アクションを別のアドレスで提供している場合のみ入力してください。';

  @override
  String get serverSiteUrlHint => '上と同じ';

  @override
  String get serverSectionRecent => '最近';

  @override
  String get serverRecentForget => 'このサーバーを削除';

  @override
  String get serverSwitchWarningTitle => '切り替えるとサインアウトします';

  @override
  String get serverSwitchWarningBody =>
      'アカウントとチャットは 1 つのサーバーに属します。この端末はサインアウトし、ダウンロード済みのデータを消して、最初から始めます。どちらのサーバー上のデータも削除されません。';

  @override
  String get serverSwitchRolledBackTitle => '接続できませんでした';

  @override
  String serverSwitchRolledBackBody(String host) {
    return '$host から応答がなかったため、何も変わっていません。もう一度サインインしてください。';
  }

  @override
  String get serverSwitchStrandedBody =>
      'どちらのサーバーにも接続できませんでした。アドレスを確認して、もう一度お試しください。';

  @override
  String get serverSwitchRefusedBody => 'この端末はお子さま用に設定されているため、サーバーを変更できません。';

  @override
  String serverChipSemantics(String server) {
    return 'サーバーを変更します。現在は $server です。';
  }

  @override
  String get serverValueDefault => '既定';

  @override
  String get settingsScreenRowServer => 'サーバー';

  @override
  String get settingsScreenSectionAdvanced => '詳細設定';

  @override
  String get serverSwitchingLabel => 'サーバーを切り替えています…';

  @override
  String get serverRoleExplainAction => 'これはどういう意味ですか？';

  @override
  String get serverBadgeRibbonHomeserver => 'ホーム';

  @override
  String get serverBadgeRibbonSelfHosted => 'セルフ';

  @override
  String get serverBadgeHomeserver => 'ホームサーバーで稼働中';

  @override
  String get serverBadgeHomeserverSemantics => 'ホームサーバーで稼働中です。詳細はタップしてください。';

  @override
  String serverBadgeSelfHostedSemantics(String server) {
    return 'セルフホストのサーバー: $server。詳細はタップしてください。';
  }

  @override
  String get serverRoleHomeserverTitle => 'ホームサーバーで動作中';

  @override
  String get serverRoleHomeserverBody =>
      'MonkeyHub の運営者が、しばらくのあいだトラフィックを自宅のサーバーに切り替えています。動作はこれまでどおりで、故障ではなく意図的なものです。';

  @override
  String get serverRoleHomeserverWarnData =>
      'この間に送ったものは、トラフィックが戻ったあと残っていない場合があります。';

  @override
  String get serverRoleHomeserverWarnSpeed => '家庭回線は通常より遅いため、動作がもたつくことがあります。';

  @override
  String get serverRoleHomeserverWarnAuto => '操作は不要です。アプリは自動的に元へ戻ります。';

  @override
  String get serverRoleSelfHostedTitle => '自分のサーバー';

  @override
  String get serverRoleSelfHostedBody =>
      'この端末はご自分のサーバーを指しています。設定 › 詳細設定 › サーバー で変更できます。';

  @override
  String get serverValueHomeserver => '当面はホームサーバー';

  @override
  String get serverChoiceCloudSubHomeserver => 'しばらくのあいだホームサーバーから提供されています。';

  @override
  String get serverDirectiveChangedToast => 'サーバーが切り替わりました。再接続しています…';

  @override
  String get loginScreenSignInWithPhone => 'sign in with your phone';

  @override
  String get loginScreenUsePasswordInstead => 'パスワードを使う';

  @override
  String get deviceLoginScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScreenIntro =>
      'スマホでMonkeyHubを開き、プロフィールの「スキャンしてサインイン」をタップして、カメラをここに向けてください。下のコードを入力することもできます。';

  @override
  String get deviceLoginScreenWaiting => '承認を待っています…';

  @override
  String get deviceLoginScreenApproved => '承認されました。サインインしています…';

  @override
  String get deviceLoginScreenDenied => 'スマホでサインインのリクエストが拒否されました';

  @override
  String get deviceLoginScreenGenericError => '問題が発生しました。新しいコードでお試しください';

  @override
  String get profileScreenScanToSignInLabel => 'スキャンしてサインイン';

  @override
  String get deviceLoginScanScreenHeroMuted => 'Scan to\n';

  @override
  String get deviceLoginScanScreenHeroInk => 'sign in';

  @override
  String get deviceLoginScanScreenIntro => 'パソコンに表示されたコードにカメラを向けるか、下に入力してください。';

  @override
  String get deviceLoginScanScreenScanButtonLabel => 'コードをスキャン';

  @override
  String get deviceLoginScanScreenConfirmTitle => 'このデバイスでサインインしますか？';

  @override
  String deviceLoginScanScreenConfirmBody(Object deviceInfo) {
    return '$deviceInfo があなたとしてサインインしようとしています。今あなた自身が操作している場合だけ承認してください。';
  }

  @override
  String get deviceLoginScanScreenApproveButton => '承認';

  @override
  String get deviceLoginScanScreenDenyButton => '拒否';

  @override
  String get deviceLoginScanScreenSuccess => 'もう一方のデバイスでサインインしました';

  @override
  String get deviceLoginScanScreenGenericError => '承認できませんでした。もう一度お試しください';

  @override
  String get authErrorDeviceLoginInvalid => 'このコードは正しくありません。';

  @override
  String get authErrorDeviceLoginExpired =>
      'このコードは期限切れです。もう一方のデバイスで新しいコードを表示してください。';

  @override
  String get deviceLoginScanScreenDeniedConfirmation => 'サインインのリクエストを拒否しました';

  @override
  String get roomAdminRoleAdmin => '管理者';

  @override
  String get roomAdminActionViewProfile => 'プロフィールを見る';

  @override
  String get roomAdminActionPromote => '管理者にする';

  @override
  String get roomAdminActionPromoteSub => '招待、メンバーの削除、グループの編集ができるようになります';

  @override
  String get roomAdminActionDemote => '管理者から外す';

  @override
  String get roomAdminActionDemoteSub => 'メンバーとしてグループに残ります';

  @override
  String get roomAdminActionTransfer => 'オーナーを譲る';

  @override
  String get roomAdminActionTransferSub => 'あなたは管理者として残ります';

  @override
  String get roomAdminActionRemove => 'グループから削除';

  @override
  String get roomAdminAddFriendsRow => '友だちを追加';

  @override
  String get roomAdminInviteLinkRow => '招待リンク';

  @override
  String get roomAdminJoinRequestsRow => '参加リクエスト';

  @override
  String roomAdminTransferConfirmHeadline(Object name) {
    return 'グループを$nameさんに譲りますか？';
  }

  @override
  String get roomAdminTransferConfirmBody =>
      'その人がオーナーになり、グループを削除できるようになります。あなたは管理者として残り、返してもらえるかどうかはその人次第です。';

  @override
  String get roomAdminTransferConfirmCta => '譲る';

  @override
  String roomAdminRemoveConfirmHeadline(Object name) {
    return '$nameさんを削除しますか？';
  }

  @override
  String get roomAdminRemoveConfirmBody =>
      'グループとその中身にアクセスできなくなります。あらためて招待することも、招待リンクから戻ってくることもできます。';

  @override
  String get roomAdminRemoveConfirmCta => '削除';

  @override
  String get roomAdminGenericError => 'うまくいきませんでした。もう一度お試しください。';

  @override
  String get roomAdminErrorNotMember => 'このグループのメンバーではなくなっています。';

  @override
  String get roomAdminErrorNotAdmin => 'これができるのは管理者だけです。';

  @override
  String get roomAdminErrorNotOwner => 'これができるのはグループのオーナーだけです。';

  @override
  String get roomAdminErrorNotGroup => '1対1のチャットに管理するものはありません。';

  @override
  String get roomAdminErrorOwnerImmutable => 'オーナーの役割は、グループを譲ることでしか変わりません。';

  @override
  String get roomAdminErrorInvitesLocked => 'このグループに招待できるのは管理者だけです。';

  @override
  String get roomInviteSheetTitle => '招待リンク';

  @override
  String get roomInviteSheetBlurb =>
      'リンクとコードはひとつずつで、中身は同じものです。新しく作ると、前のものはその場で使えなくなります。';

  @override
  String get roomInviteNoLinkYet => 'このグループにはまだ招待リンクがありません。';

  @override
  String get roomInviteCreateButton => 'リンクを作る';

  @override
  String get roomInviteRegenerateButton => '新しいリンク';

  @override
  String get roomInviteRevokeButton => 'リンクを無効にする';

  @override
  String get roomInviteCopyLink => 'リンクをコピー';

  @override
  String get roomInviteCopyCode => 'コードをコピー';

  @override
  String get roomInviteShare => '共有';

  @override
  String get roomInviteLinkCopied => 'リンクをコピーしました。';

  @override
  String get roomInviteCodeCopied => 'コードをコピーしました。';

  @override
  String get roomInviteRegenerateHeadline => '新しいリンクを作りますか？';

  @override
  String get roomInviteRegenerateBody =>
      '今のリンクとコードは、共有された場所すべてで直ちに使えなくなります。すでにいるメンバーはそのまま残ります。';

  @override
  String get roomInviteRegenerateConfirm => '新しいリンク';

  @override
  String get roomInviteRevokeHeadline => 'このリンクを無効にしますか？';

  @override
  String get roomInviteRevokeBody =>
      '新しく作るまで、リンクからは誰も参加できません。すでにいるメンバーはそのまま残ります。';

  @override
  String get roomInviteRevokeConfirm => '無効にする';

  @override
  String get roomInviteLimitsLabel => '制限';

  @override
  String get roomInviteExpiryLabel => '有効期限';

  @override
  String get roomInviteMaxUsesLabel => '使える回数';

  @override
  String get roomInviteNeverExpires => 'なし';

  @override
  String get roomInviteUnlimited => '無制限';

  @override
  String roomInviteExpiryHours(Object count) {
    return '$count時間';
  }

  @override
  String roomInviteExpiryDays(Object count) {
    return '$count日';
  }

  @override
  String get roomInviteLimitsApplyToNew => 'これから作るリンクに適用されます。';

  @override
  String get roomInviteLimitsApplyOnRegenerate =>
      '次に作るリンクに適用されます。上のリンクは、作られたときの制限のままです。';

  @override
  String get roomInvitePermissionsLabel => '権限';

  @override
  String get roomInviteMembersCanInviteLabel => 'メンバーも友だちを招待できる';

  @override
  String get roomInviteMembersCanInviteSub => 'オフにすると、人を招けるのは管理者だけになります';

  @override
  String get roomInviteApprovalLabel => '参加をひとりずつ承認する';

  @override
  String get roomInviteApprovalSub => 'リンクを持つ人はまず申請し、管理者が可否を決めます';

  @override
  String roomInviteUsesCount(Object count) {
    return '$count回使われました';
  }

  @override
  String roomInviteUsesOfMax(Object max, Object used) {
    return '$max回中$used回';
  }

  @override
  String roomInviteExpiresOn(Object date) {
    return '$dateまで';
  }

  @override
  String get roomInviteDeadExpired => 'このリンクは期限切れです。新しく作ってください。';

  @override
  String get roomInviteDeadExhausted => 'このリンクは使える回数を使い切りました。新しく作ってください。';

  @override
  String get roomInviteDeadRevoked => 'このリンクは無効にされました。';

  @override
  String get roomInviteDeadGeneric => 'このリンクはもう使えません。';

  @override
  String get roomInviteFriendsTitle => '友だちを追加';

  @override
  String get roomInviteFriendsBlurb => '招待が届き、承諾か辞退かを選べます。';

  @override
  String get roomInviteFriendsSearchHint => '友だちを検索';

  @override
  String get roomInviteFriendsInviteButton => '招待';

  @override
  String get roomInviteFriendsSent => '招待済み';

  @override
  String get roomInviteFriendsEmpty => '友だちは全員すでにここにいるか、招待済みです。';

  @override
  String get roomInviteFriendsNoMatch => '該当する友だちはいません。';

  @override
  String get roomInviteFriendsDone => '完了';

  @override
  String get roomJoinRequestsTitle => '参加リクエスト';

  @override
  String get roomJoinRequestsBlurb =>
      '招待リンクを使った人たちです。あなたが承認するまで、グループの中は何も見えません。';

  @override
  String get roomJoinRequestsEmpty => '待っている人はいません。';

  @override
  String get roomJoinRequestsApprove => '入れる';

  @override
  String get roomJoinRequestsReject => '断る';

  @override
  String roomInfoScreenInvitedLabel(Object count) {
    return '招待済み · $count';
  }

  @override
  String get roomInfoScreenInviteAwaitingGuardian => '保護者の確認待ち';

  @override
  String get roomInfoScreenInviteWithdraw => '取り消す';

  @override
  String roomInvitationCardFrom(Object inviter, Object members) {
    return '$inviterさんから · メンバー$members人';
  }

  @override
  String get roomInvitationCardJoin => '参加';

  @override
  String get discoverScreenJoinByCodeTitle => 'コードで参加';

  @override
  String get discoverScreenJoinByCodeSubtitle => '共有されたグループを開きます';

  @override
  String get joinInviteTitle => 'グループに参加';

  @override
  String get joinInviteBack => '戻る';

  @override
  String get joinInviteCodeBlurb => '共有されたコードを入力してください。招待リンクをそのまま貼っても使えます。';

  @override
  String get joinInviteCodeLabel => '招待コード';

  @override
  String get joinInviteCodeHint => 'リンクを貼るか、コードを入力';

  @override
  String get joinInviteCodeInvalid => '招待コードではないようです。';

  @override
  String get joinInviteLookupButton => '次へ';

  @override
  String get joinInviteLookupFailed => 'コードを確認できませんでした。通信状況を確かめてもう一度お試しください。';

  @override
  String joinInviteMemberCount(Object count) {
    return 'メンバー$count人';
  }

  @override
  String get joinInviteJoinButton => 'グループに参加';

  @override
  String get joinInviteRequestButton => '参加を申請';

  @override
  String get joinInviteOpenNote => '参加すると、グループのメッセージが見えるようになります。';

  @override
  String get joinInviteApprovalNote => 'ここの中身が見えるようになるには、まず管理者の承認が必要です。';

  @override
  String get joinInviteOpenRoom => 'グループを開く';

  @override
  String get joinInvitePendingHeadline => '管理者の返事待ちです';

  @override
  String get joinInvitePendingBody => '誰かが答えたらすぐに通知が届きます。';

  @override
  String get joinInviteBadLinkHeadline => 'この招待は使えません';

  @override
  String get joinInviteBadLinkBody => 'コードを確かめるか、新しいリンクをもらってください。';

  @override
  String get joinInviteExpiredHeadline => 'この招待は期限切れです';

  @override
  String get joinInviteExpiredBody => '招待してくれた人に新しいリンクをもらってください。';

  @override
  String get joinInviteExhaustedHeadline => 'この招待は使い切られています';

  @override
  String get joinInviteExhaustedBody => '使える回数が決められていました。新しいものをもらってください。';

  @override
  String get joinInviteRevokedHeadline => 'この招待は差し替えられました';

  @override
  String get joinInviteRevokedBody => '管理者が新しいリンクを作りました。今のものをもらってください。';

  @override
  String get joinInviteWrongServerHeadline => 'この招待は別のサーバーのものです';

  @override
  String joinInviteWrongServerBody(Object host) {
    return '$hostのものです。あなたのアカウントは別のサーバーにあるため、ここからこのグループには入れません。';
  }

  @override
  String get roomInviteErrorNotFound => 'その招待コードに一致するものはありません。';

  @override
  String get roomInviteErrorRevoked => 'その招待は差し替えられました。今のリンクをもらってください。';

  @override
  String get roomInviteErrorExpired => 'その招待は期限切れです。';

  @override
  String get roomInviteErrorExhausted => 'その招待は使い切られています。';

  @override
  String get roomInviteErrorAlreadyMember => 'その人はすでにこのグループにいます。';

  @override
  String get roomInviteErrorAlreadyInvited => 'その人はすでに招待済みです。';

  @override
  String get roomInviteErrorSelf => 'あなたはすでにこのグループにいます。';

  @override
  String get roomInviteErrorInvitationGone => 'その招待はもうありません。';

  @override
  String get roomInviteErrorRequestPending => 'すでに参加を申請しています。管理者が答えます。';

  @override
  String get roomInviteErrorRequestGone => 'そのリクエストには誰かがすでに答えました。';

  @override
  String get roomInviteErrorRoomPrivate => 'このグループには招待でしか参加できません。';

  @override
  String get roomInviteErrorInvalidLimits => 'その制限は使えません。';

  @override
  String approvalsScreenHeadlineRoomInviteOutgoing(
    Object child,
    Object other,
    Object room,
  ) {
    return '$childが$otherを$roomに招待しようとしています';
  }

  @override
  String approvalsScreenHeadlineRoomInviteIncoming(
    Object child,
    Object other,
    Object room,
  ) {
    return '$otherが$childを$roomに招待しました';
  }

  @override
  String get approvalsScreenConsequenceRoomInviteOutgoing =>
      '招待が送られます。参加するかどうかは相手が決めます。';

  @override
  String approvalsScreenConsequenceRoomInviteIncoming(Object child) {
    return '$childに招待が表示され、承諾か辞退かを選べます。承認すると、承諾した場合にそのグループへの参加も許可されます。';
  }

  @override
  String get roomAdminErrorCannotRemoveSelf =>
      '自分を削除することはできません。かわりにグループから退出してください。';

  @override
  String get roomAdminActionMessage => 'メッセージ';

  @override
  String get roomAdminActionVoiceCall => '音声通話';

  @override
  String get roomAdminActionVideoCall => 'ビデオ通話';

  @override
  String get roomAdminYouSuffix => '自分';

  @override
  String get roomInfoScreenSetPasswordButton => '設定';

  @override
  String get roomInfoScreenPasswordSetSnackbar => 'パスワードを設定しました。';

  @override
  String get roomInfoScreenPasswordSetState => 'パスワードあり';

  @override
  String get roomInfoScreenPasswordUnsetState => 'パスワードなし';

  @override
  String get roomInfoScreenPasswordCancel => 'キャンセル';

  @override
  String get roomInfoScreenEditSave => '保存';

  @override
  String get roomInfoScreenEditCancel => 'キャンセル';

  @override
  String get roomInviteRotatedToast => '新しいリンクを作成しました。以前のリンクはもう使えません。';

  @override
  String get roomInviteRevokedToast => '招待リンクを無効にしました。';

  @override
  String get newChatMenuTitle => '新しいチャット';

  @override
  String get newChatMenuCreateTitle => 'ルームを作成';

  @override
  String get newChatMenuCreateSub => 'グループを作って人を招待します';

  @override
  String get newChatMenuJoinTitle => 'コードで参加';

  @override
  String get newChatMenuJoinSub => '共有されたグループを開きます';

  @override
  String get shareSheetTitle => '送信先';

  @override
  String get shareSheetSuggestedHeading => '候補';

  @override
  String shareSheetPreviewItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '添付$count件',
    );
    return '$_temp0';
  }

  @override
  String shareSheetTooLargeDropped(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のファイルが$sizeの上限を超えたため除外しました',
    );
    return '$_temp0';
  }

  @override
  String shareSheetSendToSemantic(String title) {
    return '$titleに送信';
  }

  @override
  String get settingsScreenRowSpeakerColors => '話し手の色';

  @override
  String get settingsScreenValueSpeakerOff => 'オフ';

  @override
  String get settingsScreenValueSpeakerName => '名前';

  @override
  String get settingsScreenValueSpeakerBubble => '名前＋吹き出し';

  @override
  String get speakerColorScreenTitle => '話し手の色。';

  @override
  String get speakerColorScreenSubtitle => '名前を読まなくても、誰の発言かわかる';

  @override
  String get speakerColorScreenOffLabel => 'オフ';

  @override
  String get speakerColorScreenOffDescription => '部屋の全員が同じ色で表示されます。';

  @override
  String get speakerColorScreenNameLabel => '名前';

  @override
  String get speakerColorScreenNameDescription => '一人ひとりに専用の色。名前とアイコンの縁につきます。';

  @override
  String get speakerColorScreenBubbleLabel => '吹き出し';

  @override
  String get speakerColorScreenBubbleDescription =>
      '色は吹き出しにも広がるので、5件続いても誰の発言かわかります。';

  @override
  String get roomInfoScreenSpeakerColorsLabel => 'カラー';

  @override
  String get roomInfoScreenSpeakerColorsAutomatic => '自動';

  @override
  String get roomInfoScreenSpeakerColorsCustom => 'カスタム';

  @override
  String get roomColorsScreenTitle => '誰が誰か。';

  @override
  String get roomColorsScreenSubtitle => 'それぞれの人の色';

  @override
  String get roomColorsScreenOffTitle => '話し手の色はオフです';

  @override
  String get roomColorsScreenOffBody =>
      '今は全員が同じ色で表示されます。オンにすると、ここにいる一人ひとりに専用の色がつきます。';

  @override
  String get roomColorsScreenOffAction => 'オンにする';

  @override
  String get roomColorsScreenOffHint => 'この部屋だけでなく、すべての部屋に適用されます。設定にもあります。';

  @override
  String get roomColorsScreenAutoChip => '自動';

  @override
  String roomColorsScreenAlsoUsedBy(Object name) {
    return '$name と同じ色';
  }

  @override
  String get roomColorsScreenResetAll => '自動に戻す';

  @override
  String get roomColorsScreenLimitToast => '1つの部屋で固定できる色はここまでです。';

  @override
  String get roomColorsScreenFailedToast => 'その色を保存できませんでした。';

  @override
  String roomColorsScreenSwatchSemantic(Object index) {
    return '色 $index';
  }

  @override
  String get devicesScreenTitle => 'デバイス';

  @override
  String get devicesScreenSubtitle => 'このアカウントでサインインしたすべての場所。';

  @override
  String get devicesScreenLoading => '確認中…';

  @override
  String get devicesScreenLoadFailed => 'デバイスを読み込めませんでした';

  @override
  String get devicesScreenThisDevice => 'このデバイス';

  @override
  String get devicesScreenActiveNow => '現在アクティブ';

  @override
  String devicesScreenMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count分前',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count時間前',
    );
    return '$_temp0';
  }

  @override
  String devicesScreenDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日前',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenNoNotifications => 'このデバイスには通知が届いていません';

  @override
  String get devicesScreenRemove => '削除';

  @override
  String get devicesScreenRemoveTitle => 'このデバイスを削除しますか？';

  @override
  String devicesScreenRemoveBody(Object name) {
    return '$name はサインアウトされ、通知も届かなくなります。その端末を持っている人は、もう一度サインインする必要があります。';
  }

  @override
  String get devicesScreenRemoveConfirm => '削除';

  @override
  String get devicesScreenRemoveAll => '他のデバイスをすべて削除';

  @override
  String get devicesScreenRemoveAllTitle => '他のデバイスをすべて削除しますか？';

  @override
  String get devicesScreenRemoveAllBody =>
      'すべてサインアウトされ、通知も届かなくなります。サインインしたままになるのはこの端末だけです。';

  @override
  String get devicesScreenRemoveAllConfirm => 'すべて削除';

  @override
  String devicesScreenRemovedCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count台のデバイスを削除しました',
      zero: '削除できる他のデバイスはありません',
    );
    return '$_temp0';
  }

  @override
  String get devicesScreenRemoveFailed => 'そのデバイスを削除できませんでした';

  @override
  String get devicesScreenFootnote =>
      'デバイスを削除すると、サインアウトされ通知も止まります。すぐに反映され、その端末が次に何かしようとした時点でログイン画面に戻ります。';

  @override
  String get attachmentMenuPollLabel => '投票';

  @override
  String get attachmentMenuChecklistLabel => 'チェックリスト';

  @override
  String get attachmentMenuEventLabel => '予定';

  @override
  String get interactionKindPoll => '投票';

  @override
  String get interactionKindQuiz => 'クイズ';

  @override
  String get interactionKindChecklist => 'チェックリスト';

  @override
  String get interactionKindEvent => '予定';

  @override
  String get interactionBadgeAnonymous => '匿名';

  @override
  String get interactionBadgeMultiple => '複数可';

  @override
  String get interactionBadgeClosed => '締切';

  @override
  String interactionPercent(int percent) {
    return '$percent%';
  }

  @override
  String interactionAndMore(int count, String names) {
    return '$names 他$count人';
  }

  @override
  String get interactionSeeWhoAnswered => '回答した人を見る';

  @override
  String interactionRemoveItem(String label) {
    return '$label を削除';
  }

  @override
  String interactionChoiceSemantics(int count, String label) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count票',
    );
    return '$label、$_temp0';
  }

  @override
  String get interactionAddItemHint => '項目を追加';

  @override
  String get interactionRetract => '取り消す';

  @override
  String get interactionClose => '締め切る';

  @override
  String interactionVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count票',
    );
    return '$_temp0';
  }

  @override
  String interactionRsvpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の返事',
    );
    return '$_temp0';
  }

  @override
  String interactionChecklistProgress(int done, int total) {
    return '$total件中$done件 完了';
  }

  @override
  String get interactionNoAnswers => '回答なし';

  @override
  String get interactionBeFirst => '最初に答えてみよう';

  @override
  String interactionFinalResults(String count) {
    return '$count · 確定';
  }

  @override
  String get interactionQuizRight => '正解';

  @override
  String get interactionQuizWrong => '惜しい';

  @override
  String interactionEventPast(String when) {
    return '$when · 終了';
  }

  @override
  String get interactionRespondentsTitlePoll => '投票した人';

  @override
  String get interactionRespondentsTitleChecklist => 'チェックした人';

  @override
  String get interactionRespondentsTitleEvent => '返事した人';

  @override
  String get interactionRespondentsFailed => '回答した人を読み込めませんでした。';

  @override
  String get interactionRespondentsEmpty => 'まだ誰も答えていません。';

  @override
  String get interactionFilterAll => 'すべて';

  @override
  String get interactionRsvpGoing => '行く';

  @override
  String get interactionRsvpMaybe => 'たぶん';

  @override
  String get interactionRsvpNo => '行けない';

  @override
  String get interactionComposePollTitle => '新しい投票';

  @override
  String get interactionComposePollTagline => 'みんなに聞く';

  @override
  String get interactionComposeChecklistTitle => '新しいチェックリスト';

  @override
  String get interactionComposeChecklistTagline => 'みんなでチェックするリスト';

  @override
  String get interactionComposeEventTitle => '新しい予定';

  @override
  String get interactionComposeEventTagline => '誰が来るか見る';

  @override
  String get interactionComposeQuestionLabel => '質問';

  @override
  String get interactionComposeQuestionHint => '何を聞きたい？';

  @override
  String get interactionComposeTitleLabel => 'タイトル';

  @override
  String get interactionComposeTitleHint => '何のためのリスト？';

  @override
  String get interactionComposeEventNameLabel => '予定';

  @override
  String get interactionComposeEventNameHint => '何がある？';

  @override
  String get interactionComposeOptionsLabel => '選択肢';

  @override
  String get interactionComposeItemsLabel => '項目';

  @override
  String interactionComposeOptionHint(int index) {
    return '選択肢 $index';
  }

  @override
  String interactionComposeItemHint(int index) {
    return '項目 $index';
  }

  @override
  String get interactionComposeAddOption => '選択肢を追加';

  @override
  String get interactionComposeAddItem => '項目を追加';

  @override
  String get interactionComposeRemoveRow => '削除';

  @override
  String get interactionComposeMarkCorrect => '正解として選ぶ';

  @override
  String get interactionComposeMultipleTitle => '複数回答';

  @override
  String get interactionComposeMultipleSub => 'いくつでも選べる';

  @override
  String get interactionComposeAnonymousTitle => '匿名';

  @override
  String get interactionComposeAnonymousOffSub => '誰が投票したか全員に見える';

  @override
  String get interactionComposeAnonymousOnSub => '誰が投票したか誰にも見えない';

  @override
  String get interactionComposeQuizTitle => 'クイズモード';

  @override
  String get interactionComposeQuizSub => '正解はひとつ、あとから変えられない';

  @override
  String get interactionComposeExplanationLabel => '解説';

  @override
  String get interactionComposeExplanationHint => '回答後に表示（任意）';

  @override
  String get interactionComposeOthersMayCheckTitle => '誰でもチェックできる';

  @override
  String get interactionComposeOthersMayCheckSub => 'あなただけではない';

  @override
  String get interactionComposeOthersMayAddTitle => '誰でも追加できる';

  @override
  String get interactionComposeOthersMayAddSub => 'あとから増やせる';

  @override
  String get interactionComposeWhenLabel => 'いつ';

  @override
  String get interactionComposePickStart => '開始を選ぶ';

  @override
  String get interactionComposePickEnd => '終了を追加（任意）';

  @override
  String get interactionComposePlaceLabel => '場所';

  @override
  String get interactionComposePlaceHint => 'どこ？（任意）';

  @override
  String get interactionComposeSendPoll => '投票を送る';

  @override
  String get interactionComposeSendChecklist => 'リストを送る';

  @override
  String get interactionComposeSendEvent => '予定を送る';

  @override
  String get interactionComposeErrorPrompt => 'まず何を聞くのか書いてください。';

  @override
  String interactionComposeErrorOptions(int count) {
    return '投票には選択肢が$countつ以上必要です。';
  }

  @override
  String get interactionComposeErrorItems => 'リストには項目が1つ以上必要です。';

  @override
  String get interactionComposeErrorAnswer => 'どれが正解か選んでください。';

  @override
  String get interactionComposeErrorWhen => 'いつ始まるか選んでください。';

  @override
  String get interactionComposeErrorEnd => '終了は開始より後にしてください。';

  @override
  String get interactionSendFailed => '送れませんでした。';

  @override
  String get interactionRefused => '反映されませんでした。';

  @override
  String get messageReceiptsScreenTitle => 'メッセージ情報';

  @override
  String messageReceiptsSummary(Object read, Object total) {
    return '$total 人中 $read 人が既読';
  }

  @override
  String get messageReceiptsEmptyState => 'このルームにはまだ他に誰もいません';

  @override
  String get messageReceiptsSectionRead => '既読';

  @override
  String get messageReceiptsSectionDelivered => '配信済み';

  @override
  String get messageReceiptsSectionSent => '送信済み';

  @override
  String get messageReceiptsSectionHidden => '受信確認なし';

  @override
  String get messageReceiptsStateHidden => '非公開';

  @override
  String get messageReceiptsStateWaiting => '未配信';

  @override
  String messageReceiptsSemanticRead(Object day, Object name, Object time) {
    return '$name が $day $time に既読';
  }

  @override
  String messageReceiptsSemanticDelivered(
    Object day,
    Object name,
    Object time,
  ) {
    return '$name が $day $time に受信';
  }

  @override
  String messageReceiptsSemanticSent(Object name) {
    return '$name はまだ受信していません';
  }

  @override
  String messageReceiptsSemanticHidden(Object name) {
    return '$name は既読通知を共有していません';
  }

  @override
  String get companionsScreenTitle => 'コンパニオン。';

  @override
  String get companionsScreenSubtitle => 'この端末の中だけで動き、どこにも送信しない相棒たち';

  @override
  String get companionSebastianTagline => 'メッセージを翻訳します';

  @override
  String get companionSebastianBlurb =>
      'Sebastian は別の言語で書かれたメッセージを読んで、その意味を教えてくれます — この端末の中だけで、どこにも何も送らずに。';

  @override
  String get companionMarloweTagline => '汎用アシスタント';

  @override
  String get companionMarloweBlurb =>
      'Marlowe は翻訳以外のすべてを引き受けます。まず頭脳を選んでおけば、できることは後から増えていきます。';

  @override
  String get companionAssuranceOnDevice => 'すべてこの端末の中で動きます';

  @override
  String get companionAssurancePrivate => 'メッセージが端末の外に出ることはありません';

  @override
  String get companionAssuranceOffline => '通信がなくても使えます';

  @override
  String companionInstallAction(Object size) {
    return 'インストール · $size';
  }

  @override
  String get companionInstallOneTime => 'ダウンロードは一度だけ。削除するまで残ります';

  @override
  String companionInstallProgress(Object received, Object total) {
    return '$total 中 $received';
  }

  @override
  String get companionInstallQueued => '別のダウンロードの完了を待っています';

  @override
  String get companionInstallCancel => 'キャンセル';

  @override
  String get companionInstallRetry => '再試行';

  @override
  String companionInstallReady(Object name) {
    return '$name の準備ができました';
  }

  @override
  String get companionInstallFailedNetwork =>
      'ダウンロードを完了できませんでした。接続を確認してもう一度お試しください。';

  @override
  String get companionInstallFailedStorage =>
      'この端末の空き容量が足りません。空きを作ってもう一度お試しください。';

  @override
  String get companionInstallFailedUnknown => 'ダウンロードを完了できませんでした。';

  @override
  String get companionUnsupportedPlatform => 'このバージョンのアプリではコンパニオンはまだ利用できません。';

  @override
  String companionBrainNeedsMemory(String size) {
    return '$size のメモリが必要です';
  }

  @override
  String get sebastianTierSeniorDetail => 'より正確な翻訳';

  @override
  String get sebastianTierJuniorDetail => 'どの端末でも動作します';

  @override
  String get sebastianLanguageUnlisted => '対応言語ではありません — 精度は落ちます';

  @override
  String get companionStatusNotInstalled => '未インストール';

  @override
  String get companionStatusOff => 'オフ';

  @override
  String companionStatusTranslatingInto(Object language) {
    return '$languageに翻訳中';
  }

  @override
  String get companionStatusNoBrain => 'まだ何もダウンロードしていません';

  @override
  String companionStatusBrainsReady(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ダウンロード $count 件が準備済み',
    );
    return '$_temp0';
  }

  @override
  String get companionStorageEmpty => '何もダウンロードしていません — コンパニオンは容量を使っていません';

  @override
  String companionStorageUsed(Object size) {
    return 'コンパニオンが $size 使用中';
  }

  @override
  String get companionSectionGeneral => '一般';

  @override
  String get companionSectionStorage => 'ストレージ';

  @override
  String get companionBrainRemove => '削除';

  @override
  String companionBrainRemoveTitle(Object name) {
    return '$nameを削除しますか？';
  }

  @override
  String companionRemoveTitle(Object name) {
    return '$name を削除しますか？';
  }

  @override
  String companionRemoveMessage(Object size) {
    return '$size の空き容量ができます。いつでも再ダウンロードできます。';
  }

  @override
  String get companionRemoveConfirm => '削除';

  @override
  String get sebastianEnableLabel => 'Sebastian に翻訳させる';

  @override
  String get sebastianEnableDetail => 'ダウンロードを消さずに止めるにはオフにします';

  @override
  String get sebastianLanguageSection => '翻訳先の言語';

  @override
  String get sebastianLanguageFollowApp => 'アプリと同じ';

  @override
  String sebastianBrainDetail(Object size) {
    return 'この端末に保存済み · $size';
  }

  @override
  String sebastianCacheCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '翻訳 $count 件を保存中',
    );
    return '$_temp0';
  }

  @override
  String get sebastianCacheClear => '消去';

  @override
  String get marloweSkillsComingSoon =>
      'Marlowe はまだ何もできません — できることは準備中です。いまできるのは頭脳を用意しておくこと。そうすれば、機能が届いたときにダウンロードを待たずにすみます。';

  @override
  String get marloweBrainsSection => '頭脳';

  @override
  String get marloweBrainsCaption => '大きいほどよく考え、返答は遅くなります。複数を保持して切り替えられます。';

  @override
  String get marloweBrainTierSwift => '軽快';

  @override
  String get marloweBrainTierBalanced => 'バランス';

  @override
  String get marloweBrainTierDeep => '高精度';

  @override
  String get translationSlabShowOriginal => '原文を表示';

  @override
  String get translationSlabFailed => 'このメッセージは翻訳できませんでした。';

  @override
  String get translationSlabRetry => '再試行';

  @override
  String translationSlabByCompanion(Object name) {
    return '$name が翻訳';
  }

  @override
  String translationSlabFromLanguage(Object language) {
    return '$languageから';
  }

  @override
  String get messageActionMenuTranslateLabel => '翻訳';

  @override
  String get messageActionMenuShowOriginalLabel => '原文を表示';

  @override
  String get roomTranslateTitle => 'このチャットを翻訳';

  @override
  String get roomTranslateStopTitle => '翻訳を停止';

  @override
  String get roomTranslateSectionLabel => '翻訳';

  @override
  String get roomTranslateOnRow => 'このチャットを翻訳中';

  @override
  String get roomTranslateOffRow => 'オフ';

  @override
  String get roomTranslateNeedsSetUp => 'Sebastian を設定';

  @override
  String roomTranslateWorking(Object done, Object total) {
    return 'Sebastian が翻訳中 · $done/$total';
  }

  @override
  String roomTranslateReading(Object language) {
    return '$languageで読んでいます';
  }

  @override
  String get roomTranslateStop => '停止';

  @override
  String roomScreenAlreadyInLanguageSnack(Object language) {
    return 'すでに$languageです';
  }

  @override
  String get roomScreenTranslateRoomOffer => 'このチャットの残りも翻訳しますか？';

  @override
  String get roomScreenTranslateRoomOfferAction => 'すべて翻訳';

  @override
  String get settingsScreenCompanionsOff => 'オフ';

  @override
  String get settingsScreenCompanionsUnavailable => '利用不可';

  @override
  String companionBrainAlsoUsedBy(Object name) {
    return '$name も使用中';
  }

  @override
  String companionBrainSharedWarning(Object name) {
    return '$name も同じダウンロードを使っているため、一緒に失われます。';
  }

  @override
  String get companionBrainInUse => '使用中';

  @override
  String companionStatusUsingBrain(Object name) {
    return '$name を使用中';
  }

  @override
  String companionInstallContinuesInBackground(Object name) {
    return '$name のダウンロードは続きます — 設定 › コンパニオン';
  }

  @override
  String settingsScreenCompanionsDownloading(Object percent) {
    return 'ダウンロード中 · $percent%';
  }

  @override
  String get companionInstallPause => '一時停止';

  @override
  String get companionInstallResume => '再開';

  @override
  String get companionInstallDiscard => '破棄';

  @override
  String companionInstallPausedAt(Object received, Object total) {
    return '一時停止 · $total 中 $received';
  }

  @override
  String get companionInstallFailedIntegrity =>
      'ダウンロードしたファイルがこのバージョンの想定と一致しません。最初からやり直します。';

  @override
  String companionBannerDownloading(
    Object name,
    Object received,
    Object total,
  ) {
    return '$name · $total 中 $received';
  }

  @override
  String companionBannerPaused(Object name, Object received, Object total) {
    return '$name 一時停止 · $total 中 $received';
  }

  @override
  String translationSlabWakingUp(Object name) {
    return '$name が起きています…';
  }

  @override
  String get messageActionMenuTranslateAgainLabel => '翻訳し直す';

  @override
  String get groupCallScreenShareLabel => '共有';

  @override
  String get groupCallScreenStopShareLabel => '共有を停止';

  @override
  String get groupCallScreenShareStartingLabel => '開始中…';

  @override
  String get groupCallScreenRingingLabel => '呼び出し中…';

  @override
  String groupCallScreenSharingBy(String name) {
    return '$nameが画面を共有しています';
  }

  @override
  String get groupCallScreenYouAreSharing => '画面を共有中です';

  @override
  String get groupCallScreenMinimizeLabel => '隠す';

  @override
  String get groupCallScreenDrawLabel => '描く';

  @override
  String get callScreenControlShare => '共有';

  @override
  String get callScreenControlStopShare => '停止';

  @override
  String get callScreenControlShareStarting => '開始中…';

  @override
  String get screenShareStopDrawing => '描画を終了';

  @override
  String get callScreenControlDraw => '描く';

  @override
  String get callScreenControlMinimize => '隠す';

  @override
  String get inCallPillOngoingCall => '通話中';

  @override
  String get inCallPillReturn => '戻る';

  @override
  String get inCallPillSharing => '画面を共有中';

  @override
  String get inCallPillDrawSemanticLabel => '共有画面に描く';

  @override
  String get inCallPillStopSharingSemanticLabel => '共有を停止';

  @override
  String get screenShareUnsupported => 'このデバイスでは画面共有を利用できません';

  @override
  String get screenShareEphemeralWarning => '共有中はキャプチャ保護がオフになります';

  @override
  String get screenShareNotificationTitle => '画面を共有中';

  @override
  String get screenShareNotificationBody => '通話の参加者全員に表示されます';

  @override
  String get screenShareNotificationStop => '停止';

  @override
  String screenShareSomeoneElsePresenting(String name) {
    return '$nameがすでに共有しています';
  }

  @override
  String get screenShareFailed => '共有を開始できませんでした';

  @override
  String get screenSharePickerTitle => '画面を共有';

  @override
  String get screenSharePickerScreens => '画面';

  @override
  String get screenSharePickerWindows => 'ウィンドウ';

  @override
  String get screenSharePickerEmpty =>
      '共有できるものがまだありません — システム設定で画面収録を許可してからもう一度お試しください';

  @override
  String get gameTellFriends => '友だちに知らせる';

  @override
  String get gameToldFriends => '知らせました';

  @override
  String get gameTellFriendsTitle => '友だちに知らせますか？';

  @override
  String get gameTellFriendsBody => 'この結果が通知で届きます。送れるのは一度だけです。';

  @override
  String get gameTellFriendsCancel => '今はしない';

  @override
  String get gameTellFriendsConfirm => '送る';

  @override
  String get gameTellFriendsSent => '送りました';

  @override
  String get gameTellFriendsPrivate => 'デイリーの成績が非公開なので、誰にも表示されません';

  @override
  String get gameTellFriendsFailed => '送れませんでした';

  @override
  String get settingsScreenFriendActivityLabel => '友だちの動き';

  @override
  String get settingsScreenFriendActivityOnBody => '投稿されたハイライト・ポイント・ゲーム結果';

  @override
  String get settingsScreenFriendActivityOffBody => '通知なし — ボードは見に行けばあります';

  @override
  String get searchScreenActionWithGrownUp => 'おとなが確認中';

  @override
  String get newChatMenuSearchHint => '友だちを検索';

  @override
  String get newChatMenuNoFriendsYet => 'まだ友だちがいません — 「見つける」で探してみよう';

  @override
  String get newChatMenuNoFriendsMatch => '該当する友だちがいません';

  @override
  String get newChatMenuOpenDmFailed => 'そのチャットを開けませんでした — もう一度お試しください';

  @override
  String get childPolicyScreenAddSomeoneLabel => '自分の知り合いから選ぶ';

  @override
  String get childPolicyScreenPickPersonHint => '名前かユーザー名で検索';

  @override
  String get childPolicyScreenPickPersonEmpty =>
      '友だちから追加できる人はもういません —\\nほかの人を検索できます';

  @override
  String get childPolicyScreenPickPersonNoMatch => '該当する人がいません';

  @override
  String get childPolicyScreenPickPersonFriendsHeader => 'あなたの友だち';

  @override
  String get childPolicyScreenPickPersonEveryoneHeader => 'そのほかの人';

  @override
  String get childPolicyScreenAddRoomLabel => 'ルームを追加';

  @override
  String get childPolicyScreenPickRoomHeading => 'ルームを追加';

  @override
  String childPolicyScreenPickRoomBlurb(String name) {
    return 'あなた自身のルームです。$name はすぐに参加し、あなたが取り消すまで読み書きできます。';
  }

  @override
  String get childPolicyScreenPickRoomHint => '自分のルームを検索';

  @override
  String get childPolicyScreenPickRoomEmpty => '追加できるルームはもうありません';

  @override
  String get childPolicyScreenPickRoomNoMatch => '該当するルームがありません';

  @override
  String childPolicyScreenRoomAdded(String name, String room) {
    return '$name が $room に参加しました';
  }

  @override
  String get childPolicyScreenErrorAddRoomGeneric =>
      'そのルームを追加できませんでした — もう一度お試しください';

  @override
  String get childPolicyScreenErrorRoomNotAllowed => 'そのルームはこの方法では追加できません';

  @override
  String get childPolicyScreenErrorRoomGone => 'そのルームはもう存在しません';

  @override
  String get newChatMenuFriendsHeader => '友だち';

  @override
  String get roomChangeErrorGone => 'その提案はもうありません。管理者が答えたのかもしれません。';

  @override
  String get roomChangeErrorNotYours => '提案した本人だけが取り下げられます。';

  @override
  String get roomChangeErrorNoChange => 'すでにそうなっています。';

  @override
  String get roomChangeErrorMissingValue => 'このままでは保存できません。';

  @override
  String get roomChangeRequestsTitle => '提案';

  @override
  String get roomChangeRequestsBlurb => 'メンバーからの提案です。あなたが承認するまで何も変わりません。';

  @override
  String get roomChangeRequestsEmpty => '提案はありません。';

  @override
  String get roomChangeRequestsApprove => '採用';

  @override
  String get roomChangeRequestsReject => '見送る';

  @override
  String get roomChangeRequestsPhotoLabel => '新しいグループ写真';

  @override
  String get roomChangeRequestsNameLabel => '新しい名前';

  @override
  String get roomChangeRequestsDescriptionLabel => '新しい説明';

  @override
  String get roomChangeRequestsUnknownLabel => 'このアプリではまだ表示できない変更';

  @override
  String get roomChangeRequestsClearedValue => 'なし — 削除する';

  @override
  String roomChangeRequestsSuggestedBy(Object name) {
    return '$name の提案';
  }

  @override
  String get roomAdminChangeRequestsRow => '提案';

  @override
  String get roomInfoScreenSuggestNote => '管理者の承認が必要です';

  @override
  String get roomInfoScreenSuggestAvatarNote => '新しい写真は管理者が承認します';

  @override
  String get roomInfoScreenSuggestRoomPictureSemantic => 'グループ写真を提案';

  @override
  String get roomInfoScreenSuggestionSentToast => '管理者に送りました';

  @override
  String get roomInfoScreenSuggestionAppliedToast => '完了 — このグループは編集できます';

  @override
  String get roomInfoScreenSuggestionWithdrawnToast => '取り下げました';

  @override
  String get roomInfoScreenSuggestionsLabel => 'あなたの提案';

  @override
  String get roomInfoScreenSuggestionPhoto => '新しいグループ写真';

  @override
  String roomInfoScreenSuggestionName(Object value) {
    return '名前: $value';
  }

  @override
  String roomInfoScreenSuggestionDescription(Object value) {
    return '説明: $value';
  }

  @override
  String get roomInfoScreenSuggestionOther => '変更';

  @override
  String get roomInfoScreenSuggestionPending => '管理者の返事待ち';

  @override
  String get roomInfoScreenSuggestionWithdraw => '取り下げる';

  @override
  String roomSuggestionBannerPhoto(Object name) {
    return '$name が新しいグループ写真を提案しました';
  }

  @override
  String roomSuggestionBannerName(Object name) {
    return '$name が新しい名前を提案しました';
  }

  @override
  String roomSuggestionBannerDescription(Object name) {
    return '$name が新しい説明を提案しました';
  }

  @override
  String roomSuggestionBannerMany(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の提案が確認を待っています',
    );
    return '$_temp0';
  }

  @override
  String get roomSuggestionBannerReview => '確認';

  @override
  String get roomSuggestionBannerSemantic => '確認を待っているメンバーの提案';

  @override
  String get gameInfoPlay => 'プレイする';

  @override
  String get gameInfoContinue => '続きをプレイ';

  @override
  String get gameInfoSeeResult => '結果を見る';

  @override
  String messageReceiptsDeliveredSummary(Object delivered, Object total) {
    return '$total 人中 $delivered 人に配信済み';
  }

  @override
  String get messageReceiptsSentLabel => '送信';

  @override
  String messageReceiptsSemanticDeliveredThenRead(
    Object deliveredDay,
    Object deliveredTime,
    Object name,
    Object readDay,
    Object readTime,
  ) {
    return '$name が $deliveredDay $deliveredTime に受信し、$readDay $readTime に既読';
  }

  @override
  String get messageReceiptsStampRead => '既読';

  @override
  String get messageReceiptsStampDelivered => '配信';

  @override
  String get roomInviteCustom => 'カスタム';

  @override
  String roomInviteCustomHours(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 時間',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 日',
    );
    return '$_temp0';
  }

  @override
  String roomInviteCustomUses(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 回',
    );
    return '$_temp0';
  }

  @override
  String get roomInviteUnitHours => '時間';

  @override
  String get roomInviteUnitDays => '日';

  @override
  String get roomInviteStepperIncrease => '増やす';

  @override
  String get roomInviteStepperDecrease => '減らす';

  @override
  String get recordsLabel => '歴代記録';

  @override
  String get recordsBlurb => 'これまでのベスト — あなたと友達';

  @override
  String recordsYourBest(Object value) {
    return 'あなた $value';
  }

  @override
  String get recordsNoneYet => 'まだ誰もいません';

  @override
  String get recordsEmpty => 'どれかのゲームをクリアすると、ベストがここに載ります。';

  @override
  String recordsSolves(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 回クリア',
    );
    return '$_temp0';
  }

  @override
  String recordsSetOn(Object date) {
    return '$date に達成';
  }

  @override
  String recordsReactSemantic(Object name) {
    return '$name の記録にリアクション';
  }

  @override
  String get recordsReactFailed => 'リアクションできませんでした';

  @override
  String get recordsLoadFailed => '記録を読み込めませんでした';

  @override
  String recordsHolderSemantic(Object game, Object name, Object value) {
    return '$game：$name の記録 $value';
  }

  @override
  String get appearanceLabel => '外観';

  @override
  String get appearanceMatchDevice => '端末に合わせる';

  @override
  String get appearanceMatchDeviceSub => '昼はライト、夜はダーク — スマホに合わせて';

  @override
  String get appearanceOneTheme => 'ひとつのテーマ';

  @override
  String get appearanceOneThemeSub => '一日中同じ見た目';

  @override
  String get appearanceLightSlot => 'ライトモード';

  @override
  String get appearanceDarkSlot => 'ダークモード';

  @override
  String get appearanceNow => '表示中';

  @override
  String appearanceAutoValue(Object name) {
    return '自動 · $name';
  }

  @override
  String get themeScreenAssignHint => 'タップでライト／ダークモードに設定 · ⛶で全画面プレビュー';

  @override
  String get themeScreenCarouselUseLight => 'ライトモードで使う';

  @override
  String get themeScreenCarouselUseDark => 'ダークモードで使う';

  @override
  String get themeScreenCarouselIsLight => 'ライトモードのテーマ';

  @override
  String get themeScreenCarouselIsDark => 'ダークモードのテーマ';

  @override
  String get onboardingThemeTitle => '自分らしく。';

  @override
  String get onboardingThemeBody => '見た目を選びましょう。設定からいつでも変えられます。';

  @override
  String get onboardingThemeYourTheme => 'テーマ';

  @override
  String get onboardingThemeContinue => '続ける';

  @override
  String get dropHintNoTarget => 'チャットにドロップして送信';

  @override
  String get dropNothingToSend => '送れるものがありません';

  @override
  String dropSendPhotos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '写真を$count枚送信',
    );
    return '$_temp0';
  }

  @override
  String dropSendVideos(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '動画を$count本送信',
    );
    return '$_temp0';
  }

  @override
  String dropSendAudio(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '音声を$count件送信',
    );
    return '$_temp0';
  }

  @override
  String dropSendFiles(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ファイルを$count件送信',
    );
    return '$_temp0';
  }

  @override
  String dropSendItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件を送信',
    );
    return '$_temp0';
  }

  @override
  String get dropSendText => 'メッセージに追加';

  @override
  String get dropSendLink => 'リンクを追加';

  @override
  String dropTargetTo(String name) {
    return '$name へ';
  }

  @override
  String dropNoticeTooLarge(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件が$sizeを超えています',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeFolder => 'フォルダは送れません';

  @override
  String dropNoticeEmpty(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '空のファイル$count件をスキップします',
    );
    return '$_temp0';
  }

  @override
  String get dropNoticeNotAllowed => 'ここでは添付できません';

  @override
  String dropNoticeAsFile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件はファイルとして送信されます',
    );
    return '$_temp0';
  }

  @override
  String dropNoticeFragile(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件は表示できない端末があります',
    );
    return '$_temp0';
  }

  @override
  String get dropKindPhoto => '写真';

  @override
  String get dropKindVideo => '動画';

  @override
  String get dropKindAudio => '音声';

  @override
  String get dropKindFile => 'ファイル';

  @override
  String get dropKindFolder => 'フォルダ';

  @override
  String get dropKindText => 'テキスト';

  @override
  String get dropKindLink => 'リンク';

  @override
  String dropMoreCount(Object count) {
    return '+$count';
  }

  @override
  String dropNoticeBatchFull(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件は一度に送れませんでした',
    );
    return '$_temp0';
  }

  @override
  String get expressionActionFailed => '実行できませんでした。もう一度お試しください。';

  @override
  String get expressionBackspace => '削除';

  @override
  String get expressionCreateSticker => 'スタンプを作る';

  @override
  String get expressionDeleteSticker => 'マイスタンプから削除';

  @override
  String get expressionFavorite => 'お気に入りに追加';

  @override
  String get expressionFavorited => 'お気に入りに追加しました';

  @override
  String get expressionFavorites => 'お気に入り';

  @override
  String expressionGifSemantics(String title) {
    return 'GIF：$title';
  }

  @override
  String get expressionLoadFailed => '読み込めませんでした。接続を確認してください。';

  @override
  String get expressionMediaNotAllowed => 'ファミリー設定で画像の送信が許可されていません。';

  @override
  String get expressionMyStickers => 'マイスタンプ';

  @override
  String get expressionNoFavorites => 'GIFやスタンプを長押しするとお気に入りに追加できます。';

  @override
  String get expressionNoRecents => '送信したGIFやスタンプがここに表示されます。';

  @override
  String get expressionNoResults => '見つかりませんでした';

  @override
  String get expressionNoStickers => 'スタンプはまだありません。';

  @override
  String get expressionOpenPanel => '絵文字・GIF・スタンプ';

  @override
  String get expressionOptionsHint => 'オプションを表示';

  @override
  String expressionPackCredit(String author, String license) {
    return 'イラスト：$author · $license';
  }

  @override
  String get expressionPlayGifHint => '再生';

  @override
  String get expressionRecent => '最近';

  @override
  String get expressionReport => '報告する';

  @override
  String get expressionReported => '報告しました。ありがとうございます。';

  @override
  String get expressionRetry => '再試行';

  @override
  String get expressionSearchKlipy => 'KLIPYを検索';

  @override
  String get expressionShowKeyboard => 'キーボードを表示';

  @override
  String get expressionSuggestionsLabel => 'おすすめスタンプ';

  @override
  String get expressionTabEmoji => '絵文字';

  @override
  String get expressionTabGifs => 'GIF';

  @override
  String get expressionTabStickers => 'スタンプ';

  @override
  String get expressionTrending => 'トレンド';

  @override
  String get expressionUnfavorite => 'お気に入りから削除';

  @override
  String get expressionUnfavorited => 'お気に入りから削除しました';

  @override
  String replyIndicatorStickerLabel(String emoji) {
    return 'スタンプ $emoji';
  }

  @override
  String get settingsAutoplayExpressionsLabel => 'GIFとスタンプを自動再生';

  @override
  String get settingsAutoplayExpressionsOffBody =>
      'タップするまで静止したままです。データを節約できます。';

  @override
  String get settingsAutoplayExpressionsOnBody =>
      'GIFやアニメーションスタンプが自動で再生されます。「視差効果を減らす」がオンなら一時停止します。';

  @override
  String get settingsStickerSuggestionsBody =>
      '絵文字を1つだけ入力すると、入力欄の上に合うスタンプが表示されます。';

  @override
  String get settingsStickerSuggestionsLabel => 'おすすめスタンプ';

  @override
  String get stickerMakerEmojiLabel => 'どの絵文字？';

  @override
  String get stickerMakerFailed => 'スタンプを保存できませんでした。もう一度お試しください。';

  @override
  String get stickerMakerMoreEmoji => 'ほかの絵文字';

  @override
  String get stickerMakerPreview => 'スタンプのプレビュー';

  @override
  String get stickerMakerRemoveBackground => '背景を削除';

  @override
  String get stickerMakerSave => '保存';

  @override
  String get stickerMakerSaved => 'マイスタンプに追加しました';

  @override
  String get stickerMakerShape => '形';

  @override
  String get stickerMakerShapeCircle => '円';

  @override
  String get stickerMakerShapeOriginal => 'オリジナル';

  @override
  String get stickerMakerShapeRounded => '角丸四角';

  @override
  String get stickerMakerTitle => '新しいスタンプ';

  @override
  String get stickerMakerTooMany => 'スタンプの上限に達しました。1つ削除して空きを作ってください。';

  @override
  String get expressionExpandPanel => 'パネルを広げる';

  @override
  String get expressionCollapsePanel => 'パネルを縮める';

  @override
  String get expressionPackStore => 'スタンプパック';

  @override
  String get expressionPackSearchHint => 'スタンプパックを検索';

  @override
  String get expressionPacksAdded => '追加済み';

  @override
  String get expressionPacksMore => 'その他のパック';

  @override
  String get expressionPackAdd => '追加';

  @override
  String get expressionPackRemove => '削除';

  @override
  String expressionPackStickerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count個のスタンプ',
    );
    return '$_temp0';
  }

  @override
  String get expressionNoPacksFound => '該当するパックはありません';

  @override
  String get expressionAllPacksAdded => 'すべてのパックを追加しました。';

  @override
  String expressionPackReorder(String title) {
    return '$titleを並べ替え';
  }

  @override
  String expressionAddPackFromSticker(String title) {
    return '「$title」パックを追加';
  }

  @override
  String expressionPackAddedToast(String title) {
    return '「$title」をスタンプに追加しました';
  }

  @override
  String get expressionPacksFromKlipy => 'KLIPYのスタンプをもっと見る';

  @override
  String expressionSearchKlipyFor(String query) {
    return 'KLIPYで「$query」を検索';
  }

  @override
  String get expressionHideKeyboard => 'キーボードを閉じる';

  @override
  String get expressionSearchStickers => 'スタンプを検索';

  @override
  String get expressionYourStickers => 'あなたのスタンプ';

  @override
  String get chatListYesterday => '昨日';

  @override
  String get roomLayoutScreenCardsLayoutLabel => 'カード';

  @override
  String get roomLayoutScreenCardsLayoutDescription => 'ルームごとにカード表示。詳細もすべて表示。';

  @override
  String get homeScreenTitle => 'チャット';

  @override
  String get glassScreenNativeLabel => 'iOS Liquid Glass';

  @override
  String get glassScreenNativeOnBody =>
      'タブバーをiOS自身が描画します。下のスライダーはアプリのその他の部分を調整します。';

  @override
  String get glassScreenNativeOffBody =>
      'MonkeyHubが独自のガラスをすべての場所で描画します。下のスライダーで調整できます。';

  @override
  String get glassScreenHeading => 'ガラス';

  @override
  String get glassStyleHeader => 'スタイル';

  @override
  String get glassStyleLiquidTitle => 'Liquid Glass';

  @override
  String get glassStyleLiquidBody => 'iOSが描くApple純正のガラス。アプリ内のボタンもそれに合わせます。';

  @override
  String get glassStyleFrostedTitle => 'すりガラス';

  @override
  String get glassStyleFrostedBody => 'MonkeyHub独自のガラス。すべてを自分で調整できます。';

  @override
  String get glassStyleRecommended => 'おすすめ';

  @override
  String get glassStyleLiquidFooter =>
      '調整は不要です。ぼかし・色味・光はiOSが決めます。自分で調整するには「すりガラス」を選んでください。';

  @override
  String get acctSectionPrivacy => 'プライバシー';

  @override
  String get acctSectionAccount => 'アカウント';

  @override
  String get acctSectionFamily => 'ファミリー';

  @override
  String get acctSectionThisPhone => 'このスマートフォン';

  @override
  String get acctRowVisibility => 'プロフィールの公開範囲';

  @override
  String get acctRowBlocked => 'ブロック中のユーザー';

  @override
  String get acctRowApprovals => '承認';

  @override
  String get acctNothingWaiting => '保留中なし';

  @override
  String get acctRowLinked => 'リンク済みアカウント';

  @override
  String get acctRowScanToSignIn => 'スキャンしてサインイン';

  @override
  String get acctRowSetUpRecovery => '復元フレーズを設定';

  @override
  String get acctRowChangeRecovery => '復元フレーズを変更';

  @override
  String get acctSignOut => 'サインアウト';

  @override
  String get acctDeleteAccount => 'アカウントを削除';

  @override
  String get acctConfirmDelete => 'もう一度タップして削除';

  @override
  String get acctHandPhoneBack => 'このスマートフォンを返す';

  @override
  String get acctMyGrownUps => '見守ってくれる大人';

  @override
  String get acctActionMessage => 'メッセージ';

  @override
  String get acctActionAddFriend => '追加';

  @override
  String get acctActionRequested => '申請済み';

  @override
  String get acctActionAccept => '承認';

  @override
  String get acctActionNotAccepting => '受付停止';

  @override
  String get acctActionUnfriend => '友達解除';

  @override
  String get acctActionBlock => 'ブロック';

  @override
  String get acctActionReport => '報告';

  @override
  String get acctStatusFriends => '友達です';

  @override
  String get acctStatusRequestSent => 'リクエスト送信済み';

  @override
  String get acctStatusWantsToConnect => '友達になりたがっています';

  @override
  String get acctStatusNotConnected => 'つながっていません';

  @override
  String get acctPresenceOnline => 'オンライン';

  @override
  String get acctPresenceAway => '離席中';

  @override
  String get acctPresenceOffline => 'オフライン';

  @override
  String get acctProfilePhoto => 'プロフィール写真';

  @override
  String get acctSaveToPhotos => '写真に保存';

  @override
  String get acctTakeSelfie => 'セルフィーを撮る';

  @override
  String get acctChooseFromLibrary => 'ライブラリから選択';

  @override
  String get acctCancel => 'キャンセル';

  @override
  String get acctSave => '保存';

  @override
  String get acctChange => '変更';

  @override
  String get acctNotNow => '今はしない';

  @override
  String get acctAddEmail => 'メールを追加';

  @override
  String get acctEditNameTitle => '名前を編集';

  @override
  String get acctAddNameTitle => '名前を追加';

  @override
  String get acctEditEmailTitle => 'メールを編集';

  @override
  String get acctChangeUsernameTitle => 'ユーザー名を変更しますか？';

  @override
  String get onboardingLookTitle => '自分らしく';

  @override
  String get onboardingLookBody => '見た目を選びましょう。設定からいつでも変更できます。';

  @override
  String get onboardingEssentials => 'ベーシック';

  @override
  String get onboardingEssentialsSub => '落ち着いた純正スタイル';

  @override
  String get onboardingCharacters => '個性派';

  @override
  String get onboardingCharactersSub => '同じアプリに、もっと個性を';

  @override
  String get onboardingLightMode => 'ライトモード';

  @override
  String get onboardingDarkMode => 'ダークモード';

  @override
  String get onboardingNow => '現在';

  @override
  String get onboardingContinue => '続ける';

  @override
  String get onboardingIconTitle => 'アプリアイコン';

  @override
  String get onboardingIconBody => '今のアイコンのまま、テーマに合わせる、好きなものを選ぶ、から選べます。';

  @override
  String get onboardingIconIosNote => 'アイコンを変更するたびに、iOSが短い通知を表示します。';

  @override
  String get onboardingGetStarted => 'はじめる';

  @override
  String get appIconMatchTheme => 'テーマに合わせる';

  @override
  String get appIconCurrent => '現在';

  @override
  String get appIconSectionCollection => 'MonkeyHub コレクション';

  @override
  String get appIconSectionThemes => 'テーマのアイコン';

  @override
  String get appIconScreenTitle => 'アプリアイコン';

  @override
  String get appIconMatchFooter =>
      '「テーマに合わせる」はダークモードのテーマに合わせてアイコンを変えるので、日中に何度も切り替わりません。';

  @override
  String get loginTitleReturning => 'おかえりなさい';

  @override
  String get loginTitleFirst => 'MonkeyHubへようこそ';

  @override
  String get loginTitleSignUp => 'アカウントを作成';

  @override
  String get loginTitleReset => 'パスワードをリセット';

  @override
  String get loginSubtitleSignIn => 'サインインして、続きから始めましょう。';

  @override
  String get loginSubtitleFirst => 'サインイン、または数秒でアカウントを作成できます。';

  @override
  String get loginSubtitleSignUp => '必要なのはユーザー名とパスワードだけです。';

  @override
  String get loginSubtitleReset => '12語のリカバリーフレーズを入力し、新しいパスワードを設定してください。';

  @override
  String get loginCtaSignIn => 'サインイン';

  @override
  String get loginCtaSignUp => 'アカウントを作成';

  @override
  String get loginCtaReset => 'パスワードをリセット';

  @override
  String get loginNoAccountPrompt => 'はじめての方は ';

  @override
  String get loginCreateAccountLink => 'アカウントを作成';

  @override
  String get loginHaveAccountPrompt => 'アカウントをお持ちの方は ';

  @override
  String get loginSignInLink => 'サインイン';

  @override
  String get loginForgotPassword => 'パスワードをお忘れですか？';

  @override
  String get loginChildAccount => '子ども用アカウントを設定';

  @override
  String get loginBackToSignIn => 'サインインに戻る';

  @override
  String get loginWithPhone => 'スマートフォンでサインイン';

  @override
  String get loginUsernameField => 'ユーザー名';

  @override
  String get loginPasswordField => 'パスワード';

  @override
  String get loginConfirmPasswordField => 'パスワード（確認）';

  @override
  String get loginNameField => '名前（任意）';

  @override
  String get loginRecoveryPhraseField => '12語のリカバリーフレーズ';

  @override
  String get loginNewPasswordField => '新しいパスワード';

  @override
  String get roomHeaderStatusOnline => 'オンライン';

  @override
  String roomHeaderStatusMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'メンバー$count人',
    );
    return '$_temp0';
  }

  @override
  String get settingsHubTitle => '設定';

  @override
  String get settingsHubAccountHintAdult => 'プロフィール、ファミリー、リンク済みアカウント、プライバシー';

  @override
  String get settingsHubAccountHintChild => 'プロフィール、プライバシー、保護者';

  @override
  String get settingsHubSectionGeneral => '一般';

  @override
  String get settingsHubSectionNotifications => '通知';

  @override
  String get settingsHubSectionCalls => '通話';

  @override
  String get settingsHubSectionAppearance => '外観';

  @override
  String get settingsHubSectionCompanions => 'コンパニオン';

  @override
  String get settingsHubSectionChats => 'チャット';

  @override
  String get settingsHubSectionHelp => 'ヘルプと法的情報';

  @override
  String get settingsHubSectionAdvanced => '詳細';

  @override
  String get settingsHubLanguage => '言語';

  @override
  String get settingsHubCheckForUpdates => 'アップデートを確認';

  @override
  String get settingsHubUpdateAvailable => 'アップデートあり';

  @override
  String get settingsHubShowLinkUrls => 'リンクのアドレスを表示';

  @override
  String get settingsHubShowLinkUrlsSubtitle => 'リンクプレビューの横にアドレスを表示';

  @override
  String get settingsHubPresenceDots => 'オンラインの人を表示';

  @override
  String get settingsHubPresenceDotsSubtitle => 'プロフィール写真の点';

  @override
  String get settingsHubPush => 'プッシュ通知';

  @override
  String get settingsHubPushSubtitle => '新着メッセージ、通話、リクエスト';

  @override
  String get settingsHubGameReminders => '毎日のゲームリマインダー';

  @override
  String get settingsHubGameRemindersSubtitle => 'まだ遊んでいなければお昼に1回お知らせ';

  @override
  String get settingsHubFriendActivity => '友達のアクティビティ';

  @override
  String get settingsHubFriendActivitySubtitle => '友達のハイライト、ポイント、ゲーム結果';

  @override
  String get settingsHubMenuBar => 'メニューバーアイコン';

  @override
  String get settingsHubMenuBarSubtitle => '未読数をメニューバーに表示';

  @override
  String get settingsHubCallStats => '通話の統計を表示';

  @override
  String get settingsHubCallStatsSubtitle => '通話中の解像度、ビットレート、Ping';

  @override
  String get settingsHubTheme => 'テーマ';

  @override
  String get settingsHubAppIcon => 'アプリアイコン';

  @override
  String get settingsHubGlass => 'ガラス';

  @override
  String get settingsHubNavigation => 'ナビゲーション';

  @override
  String get settingsHubMotion => '動き';

  @override
  String get settingsHubChatList => 'チャットリスト';

  @override
  String get settingsHubChatStyle => 'チャットのスタイル';

  @override
  String get settingsHubBubbleStyle => '吹き出しのスタイル';

  @override
  String get settingsHubSpeakerColors => '話者の色';

  @override
  String get settingsHubReplyStyle => '返信のスタイル';

  @override
  String get settingsHubPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get settingsHubTerms => '利用規約';

  @override
  String get settingsHubLicence => 'ライセンス';

  @override
  String get settingsHubServer => 'サーバー';

  @override
  String get settingsHubLayoutRows => 'リスト';

  @override
  String get settingsHubLayoutCards => 'カード';

  @override
  String get settingsHubLayoutGrid => 'グリッド';

  @override
  String get settingsHubNavTabBar => 'タブバー';

  @override
  String settingsHubThemeAuto(String name) {
    return '自動 · $name';
  }

  @override
  String get chatListPageRowsSub => '顔、名前、最新メッセージ。メッセージアプリのように。';

  @override
  String get chatListPageCardsSub => 'ルームごとにカード表示。詳細もすべて表示。';

  @override
  String get chatListPageGridSub => '2列のタイル。ひと目で多くのルームを。';

  @override
  String get chatListPageLayoutHeader => 'レイアウト';

  @override
  String get chatListPageFiltersHeader => 'フィルタ';

  @override
  String get chatListPageChips => 'チップ';

  @override
  String get chatListPageChipsSub => 'フィルタが一列に並び、いつでもワンタップ。';

  @override
  String get chatListPageButton => 'ボタン';

  @override
  String get chatListPageButtonSub => '必要なときだけフィルタを開くボタン。';

  @override
  String get chatListPageEmptyHeader => '空のルーム';

  @override
  String get chatListPagePlain => 'シンプル';

  @override
  String get chatListPagePlainSub => 'まだ会話のないルームは何も表示しません。';

  @override
  String get chatListPageInitial => '頭文字';

  @override
  String get chatListPageInitialSub => '大きく淡い文字が空いた角を埋めます。';

  @override
  String get chatListPageEmptyFooter => 'グリッドレイアウトに適用されます。';

  @override
  String get chatStylePageFooter => '会話のヘッダーと入力欄の表示方法。';

  @override
  String get chatStyleClassicSub => 'しっかりしたヘッダーとフラットな入力欄。';

  @override
  String get chatStyleCompactSub => 'すりガラスのボタンが会話の上に浮かびます。';

  @override
  String get bubbleTailedSub => '連続の最後のメッセージにしっぽ。メッセージアプリのように。';

  @override
  String get bubbleSoftSub => 'しっぽなし。角の形で連続をまとめます。';

  @override
  String get bubblePillSub => 'すべてのメッセージが丸いカプセルに。';

  @override
  String get bubbleSlabSub => '角ばった肩：シャープで意図的。';

  @override
  String get replyStylePageFooter => '返信が元のメッセージをどう表示するか。';

  @override
  String get replyClassicSub => 'メッセージの上に色付きの引用。WhatsApp風。';

  @override
  String get replyPhantomSub => '元メッセージの影が上に浮かび、曲線でつながります。';

  @override
  String get replyStickySub => '角に留めた小さな傾いたカード。';

  @override
  String get replyComicSub => 'マンガ風のしっぽ付きミニ吹き出し。';

  @override
  String get motionMatchDevice => 'デバイスに合わせる';

  @override
  String get motionMatchDeviceCalmSub => '今、デバイスは視差効果を減らす設定です。';

  @override
  String get motionMatchDeviceFullSub => '今、デバイスはアニメーションを許可しています。';

  @override
  String get motionFullSub => 'すべてのバネ、漂い、演出を。';

  @override
  String get motionCalmSub => '装飾は静止。それ以外は同じように動作します。';

  @override
  String get navigationPageFooter => 'チャット、フィード、見つける、設定の切り替え方法。';

  @override
  String get navTabBarSub => '常に表示。どこへでもワンタップ。';

  @override
  String get navOrbSub => '角から長押ししてドラッグ。慣れるほど心地よい操作。';

  @override
  String get languageSystemLabel => 'デバイスの言語';

  @override
  String get languagePageFooter => 'メニューとアプリのメッセージ。チャットは書かれた言語のままです。';

  @override
  String get speakerPageFooter => 'グループチャットで誰が話しているかひと目で。';

  @override
  String get speakerOffSub => 'みんな同じ色で表示されます。';

  @override
  String get speakerNamesSub => '名前と顔にそれぞれの色が付きます。';

  @override
  String get speakerBubblesSub => 'その色はメッセージにも反映されます。';

  @override
  String get themePageAutoFooter => 'ライトテーマはライトモード、ダークテーマはダークモードで使われます。';

  @override
  String get themePageLightMode => 'ライトモード';

  @override
  String get themePageDarkMode => 'ダークモード';

  @override
  String get themePageEssentials => 'ベーシック';

  @override
  String get themePageEssentialsFooter => '落ち着いたネイティブな見た目を5色で。';

  @override
  String get themePageCharacters => 'キャラクター';

  @override
  String get themePageCharactersFooter => 'レイアウトはそのまま、個性をプラス。長押しでプレビュー。';

  @override
  String get themePageLightBadge => 'ライト';

  @override
  String get themePageDarkBadge => 'ダーク';

  @override
  String get themePageInUse => '使用中';

  @override
  String get themePageUseLight => 'ライトモードで使う';

  @override
  String get themePageUseDark => 'ダークモードで使う';

  @override
  String themePageUse(String name) {
    return '$nameを使う';
  }

  @override
  String get acctCaptureTitle => '画面キャプチャ保護';

  @override
  String get acctCaptureOnIos => '録画やミラーリング時はプライバシー画面が表示されます。';

  @override
  String get acctCaptureOnAndroid => 'スクリーンショットや録画は黒く表示されます。';

  @override
  String get acctCaptureOff => 'スクリーンショットや録画は通常どおり使えます。';

  @override
  String get acctCaptureFooter => '消えるメッセージのルームでは常にオンになります。';

  @override
  String get acctActionPending => '保留中';

  @override
  String get chatSwipePin => 'ピン';

  @override
  String get chatSwipeUnpin => 'ピン解除';

  @override
  String get chatSwipeMute => '通知オフ';

  @override
  String get chatSwipeUnmute => '通知オン';

  @override
  String get chatSwipeArchive => 'アーカイブ';

  @override
  String get appearanceMatchDeviceSubtitle => 'スマホに合わせて、昼はライト、夜はダーク';

  @override
  String get appearanceOneThemeSubtitle => '一日中同じ見た目';

  @override
  String get riName => '名前';

  @override
  String get riDescription => '説明';

  @override
  String get riVisibility => '見つけられる人';

  @override
  String get riPublic => '公開';

  @override
  String get riPublicSub => '誰でも「見つける」で見つけられます';

  @override
  String get riPrivate => '非公開';

  @override
  String get riPrivateSub => '招待した人だけが参加できます';

  @override
  String get riMessageLife => 'メッセージが消えるまで';

  @override
  String get riPassword => 'パスワード';

  @override
  String get riRemovePassword => 'パスワードを削除';

  @override
  String get riSetPassword => 'パスワードを設定';

  @override
  String get riSharedContent => '共有コンテンツ';

  @override
  String riMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'メンバー $count人',
    );
    return '$_temp0';
  }

  @override
  String riInvited(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '招待中 $count人',
    );
    return '$_temp0';
  }

  @override
  String get riWithdraw => '取り消す';

  @override
  String get riNotifications => '通知';

  @override
  String get riTranslation => '翻訳';

  @override
  String get riNameColours => '名前の色';

  @override
  String get riYouSuggested => 'あなたの提案';

  @override
  String get riTakeBack => '取り下げる';

  @override
  String get riLeaveRoom => 'ルームを退出';

  @override
  String get riLeaving => '退出中…';

  @override
  String get riDeleteRoom => 'ルームを削除';

  @override
  String get riDeleting => '削除中…';

  @override
  String get riEndConversation => '会話を終了';

  @override
  String get riEnding => '終了中…';

  @override
  String get riActionCall => '通話';

  @override
  String get riActionVideo => 'ビデオ';

  @override
  String get riActionMute => '消音';

  @override
  String get riActionUnmute => '消音解除';

  @override
  String get riActionMedia => 'メディア';

  @override
  String get riActionAdd => '追加';

  @override
  String get roomHeaderStatusTyping => '入力中…';

  @override
  String get glassScreenLead => '背景をどれだけ透かすか。';

  @override
  String get transcriptDayToday => '今日';

  @override
  String get acctRowDevices => 'デバイス';

  @override
  String get acctThisDevice => 'このデバイス';

  @override
  String get acctRemove => '削除';

  @override
  String get acctRemoveDeviceTitle => 'このデバイスを削除しますか？';

  @override
  String get acctRemoveAllTitle => '他のすべてのデバイスを削除しますか？';

  @override
  String get acctRemoveAll => 'すべて削除';

  @override
  String get acctActiveNow => 'アクティブ';

  @override
  String get acctLoading => '読み込み中…';

  @override
  String get acctDevicesLoadFailed => 'デバイスを読み込めませんでした。';

  @override
  String get acctNoNotifications => 'このデバイスには通知が届いていません';

  @override
  String get acctBlockedEmpty => 'ブロック中のユーザーはいません。';

  @override
  String get acctUnblock => 'ブロック解除';

  @override
  String get pvSubtitle => '他の人に見える内容と、連絡できる方法を管理します。';

  @override
  String get pvSectionProfile => 'プロフィール';

  @override
  String get pvSectionMessages => 'メッセージ';

  @override
  String get pvSectionPeople => '人';

  @override
  String get pvSectionFeed => 'フィード';

  @override
  String get pvAvatar => 'プロフィール写真';

  @override
  String get pvAvatarDesc => '写真を見られる人';

  @override
  String get pvOnline => 'オンライン状態';

  @override
  String get pvOnlineDesc => '今アクティブに見えるかどうか';

  @override
  String get pvLastSeen => '最終ログイン';

  @override
  String get pvLastSeenDesc => '最後にいた時間';

  @override
  String get pvSendReceipts => '既読を送信';

  @override
  String get pvSendReceiptsDesc => 'メッセージを読んだことを相手に表示します';

  @override
  String get pvShowReceipts => '既読を表示';

  @override
  String get pvShowReceiptsDesc => 'メッセージを読んだ人を確認';

  @override
  String get pvShowReceiptsHint => '既読を送信している人だけが数えられます。';

  @override
  String get pvFriendRequests => '友達リクエスト';

  @override
  String get pvFriendRequestsDesc => '友達リクエストを送れる人';

  @override
  String get pvSupervisedTitle => 'これは見守る大人が設定します';

  @override
  String get pvEveryone => '全員';

  @override
  String get pvFriends => '友達';

  @override
  String get pvNobody => 'なし';

  @override
  String get pvOn => 'オン';

  @override
  String get pvOff => 'オフ';

  @override
  String get pvAnyone => '誰でも';

  @override
  String get pvHighlights => 'マイハイライト';

  @override
  String get pvHighlightsDesc => '写真や動画をその日の友達のボードに表示するかどうか';

  @override
  String get pvPuzzle => 'パズルのスコア';

  @override
  String get pvPuzzleDesc => 'デイリーパズルの結果を友達に見せるかどうか';

  @override
  String get pvPast => '過去の記録';

  @override
  String get pvPastDesc => '今日の分は常に友達と共有されます。これはそれ以前の記録を公開します';

  @override
  String get pvPoints => 'マイポイント';

  @override
  String get pvPointsDesc => '記録したポイントを友達のボードに表示するかどうか';

  @override
  String get roomColorsPageTitle => 'メンバーの色';

  @override
  String get roomColorsPageHeader => 'それぞれの発言の色';

  @override
  String get roomColorsAuto => '自動';

  @override
  String get roomColorsReset => '自動に戻す';

  @override
  String get roomColorsOffFooter => '話者の色はオフです。ここでオンにするとすべてのルームでオンになります。';

  @override
  String roomColorsSharedWith(String name) {
    return '$nameと同じ色';
  }

  @override
  String get settingsScreenValueReplyQuote => '引用';

  @override
  String get replyQuoteSub => '元のメッセージが返信の吹き出しの上部に表示されます。';

  @override
  String get riTabMedia => '写真とビデオ';

  @override
  String get riTabFiles => 'ファイル';

  @override
  String get riTabVoice => 'ボイスメッセージ';

  @override
  String get riTabLinks => 'リンク';

  @override
  String get riTabSaved => '保存済み';

  @override
  String get riNone => 'なし';

  @override
  String get riSavedNote => '保存した内容は自分だけに表示されます。ピン留めは逆で、ルーム全員に表示されます。';

  @override
  String get riOwnerNote => 'メダルはこのルームの作成者を示します。';

  @override
  String get famPair => 'ペアリング';

  @override
  String get famRelease => '解除';

  @override
  String get famSettings => '設定';

  @override
  String get famAddChild => '子どもを追加';

  @override
  String get famEmptyTitle => 'まだ子どもがいません';

  @override
  String get famOnlineNow => 'オンライン';

  @override
  String get famNotPaired => '未ペアリング';

  @override
  String get famJustNow => 'たった今';

  @override
  String get apprEmptyTitle => '保留中のものはありません';

  @override
  String get apprEmptySub => 'すべて確認済みです。';

  @override
  String get apprNotYet => 'まだ';

  @override
  String get apprAllow => '許可';

  @override
  String get compGeneral => '一般';

  @override
  String get compStorage => 'ストレージ';

  @override
  String get compTranslateInto => '翻訳先';

  @override
  String get compBrain => '頭脳';

  @override
  String laUnlinkProvider(String provider) {
    return '$provider のリンクを解除';
  }

  @override
  String laLinkProvider(String provider) {
    return '$provider をリンク';
  }

  @override
  String get laUnlink => 'リンク解除';

  @override
  String get laLink => 'リンク';

  @override
  String get laLinked => 'リンク済み';

  @override
  String get laNotLinked => '未リンク';

  @override
  String rdSignOut(String name) {
    return '$name をサインアウト';
  }

  @override
  String get rpContinue => '続ける';

  @override
  String get rpCopy => 'コピー';

  @override
  String get rpSaved => '保存しました';

  @override
  String get rpBack => '戻る';

  @override
  String get rpKeep => '今はしない（現在のフレーズを使う）';

  @override
  String get childSetupHeadingIos => 'どなたですか？';

  @override
  String get childPairTitleIos => 'こんにちは！';

  @override
  String get childPairBackIos => 'サインインに戻る';

  @override
  String get gamesHubTitle => 'ランキング';

  @override
  String get gamesHubSubtitle => '今日の勝者。パズルは毎日新しくなります。';

  @override
  String get gameTellFriendsMessage => 'この結果が通知で届きます。送信できるのは1回だけです。';

  @override
  String get deviceLoginScanTitleIos => 'スキャンしてサインイン';

  @override
  String get deviceLoginConfirmTitleIos => 'このデバイスでサインインしますか？';

  @override
  String get socialHeroCreateIos => 'あと少し';

  @override
  String get socialHeroLinkIos => 'おかえりなさい';

  @override
  String socialSignInLinkIos(String provider) {
    return 'サインインして$providerと連携';
  }

  @override
  String get serverTitleIos => 'サーバー';

  @override
  String get serverOnboardingTitleIos => 'サーバーを選択';

  @override
  String get approvalGateAskIos => 'お願いする';

  @override
  String get friendRequestDraftIntroOutgoingSentence =>
      '簡単なメッセージを送りましょう。相手は承認か拒否かを選べます。';

  @override
  String get requestDeclineIos => '拒否';

  @override
  String get joinRequestAllowIos => '許可';

  @override
  String get changeRequestUseIos => '適用';

  @override
  String get settingsSearchHint => '設定を検索';

  @override
  String settingsSearchNoResults(String query) {
    return '「$query」の結果はありません';
  }

  @override
  String get settingsSearchAccount => 'アカウント';

  @override
  String get settingsHubDiagnostics => '診断';

  @override
  String get settingsHubDiagnosticsSubtitle => 'トラブル対応と不具合報告のためのログ';

  @override
  String get settingsHubAdvancedFooter => 'トラブル対応とセルフホスト向けです。普段は使いません。';

  @override
  String get settingsSearchKwLanguage => '言語, 翻訳, 地域';

  @override
  String get settingsSearchKwUpdates => 'アップデート, バージョン, 新しい';

  @override
  String get settingsSearchKwLinks => 'リンク, URL, アドレス, プレビュー';

  @override
  String get settingsSearchKwPresence => 'オンライン, 状態, ステータス, 点, アクティブ, 緑';

  @override
  String get settingsSearchKwAutoplay => 'GIF, アニメーション, 自動再生';

  @override
  String get settingsSearchKwStickers => 'ステッカー, 絵文字, 候補';

  @override
  String get settingsSearchKwPush => '通知, アラート, サウンド';

  @override
  String get settingsSearchKwGames => 'ゲーム, リマインダー, 毎日';

  @override
  String get settingsSearchKwFriends => '友達, アクティビティ, ポイント';

  @override
  String get settingsSearchKwVideo => 'ビデオ, 通話, 画質, カメラ';

  @override
  String get settingsSearchKwStats => '統計, ネットワーク, ping, デバッグ';

  @override
  String get settingsSearchKwTheme => 'テーマ, ダーク, ライト, 色, 夜';

  @override
  String get settingsSearchKwIcon => 'アイコン, ロゴ, ホーム画面';

  @override
  String get settingsSearchKwGlass => 'ガラス, ぼかし, すりガラス, 透明';

  @override
  String get settingsSearchKwNavigation => 'タブバー, ナビゲーション, メニュー';

  @override
  String get settingsSearchKwMotion => '動き, アニメーション, 視差効果を減らす';

  @override
  String get settingsSearchKwCompanions => 'AI, アシスタント, 翻訳, モデル';

  @override
  String get settingsSearchKwChatList => 'チャット一覧, 行, カード, グリッド';

  @override
  String get settingsSearchKwChatStyle => 'チャットスタイル, コンパクト, クラシック';

  @override
  String get settingsSearchKwBubbles => '吹き出し, メッセージ, 形';

  @override
  String get settingsSearchKwSpeakers => '名前, 色, グループ';

  @override
  String get settingsSearchKwReply => '返信, 引用, スレッド';

  @override
  String get settingsSearchKwReport => '不具合, 問題, フィードバック, サポート';

  @override
  String get settingsSearchKwLegal => 'プライバシー, 規約, 法的, ライセンス';

  @override
  String get settingsSearchKwServer => 'サーバー, セルフホスト, URL, 開発者';

  @override
  String get settingsSearchKwDiagnostics => '診断, ログ, デバッグ, 開発者';

  @override
  String get settingsSearchKwPrivacy => 'プライバシー, 公開範囲, 最終ログイン, 既読';

  @override
  String get settingsSearchKwBlocked => 'ブロック, 人';

  @override
  String get settingsSearchKwDevices => 'デバイス, セッション, サインアウト';

  @override
  String get settingsSearchKwLinked => 'Apple, Google, サインイン';

  @override
  String get settingsSearchKwRecovery => '復元フレーズ, パスワード, バックアップ';

  @override
  String get settingsSearchKwCapture => 'スクリーンショット, 画面収録, プライバシー';

  @override
  String get settingsSearchKwFamily => '家族, 子ども, 保護者, 承認';

  @override
  String get settingsSearchKwAccount => 'アカウント, サインアウト, 削除, メール';

  @override
  String get childPolicyScreenContactStateAllowedTalking => '会話中';

  @override
  String get childPolicyScreenContactStateTalking => '承認済み';

  @override
  String get childPolicyScreenContactStateAllowedNotAdded => '未追加';

  @override
  String get profileScreenSignOutConfirmTitle => 'このデバイスからサインアウトしますか？';

  @override
  String get profileScreenDeleteAccountConfirmTitle => 'アカウントを削除しますか？';

  @override
  String get profileScreenDeleteAccountConfirmBody =>
      'メッセージ、写真、ルーム、フレンドがすべて削除され、ユーザー名は誰でも使えるようになります。';

  @override
  String get glassPresetNameFrosted => 'すりガラス';

  @override
  String get glassPresetNameClear => 'クリア';

  @override
  String settingsScreenDiagnosticsCountdown(int count) {
    return '診断まであと$count…';
  }

  @override
  String pairingCodeTitlePair(String name) {
    return '$nameとペアリング';
  }

  @override
  String pairingCodeTitleRelease(String name) {
    return '$nameを解除';
  }

  @override
  String archivedChatsSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のチャット',
    );
    return '$_temp0';
  }

  @override
  String pinnedListSheetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のメッセージ',
    );
    return '$_temp0';
  }

  @override
  String get voiceRecorderScreenTitle => 'ボイスメッセージ';

  @override
  String get chatTargetSearchHint => '検索';

  @override
  String get marloweBrainTierSwiftDetail => 'すばやい応答、いちばん軽いダウンロード';

  @override
  String get marloweBrainTierBalancedDetail => '速さと深さのバランス型';

  @override
  String get marloweBrainTierDeepDetail => 'いちばん思慮深く、容量も最大';

  @override
  String get reportFactDeviceId => 'デバイスID';

  @override
  String get reportFactUserId => 'ユーザーID';

  @override
  String get reportFactUsername => 'ユーザー名';

  @override
  String get reportFactApp => 'アプリ';

  @override
  String get reportFactDevice => 'デバイス';

  @override
  String get reportFactSystem => 'システム';

  @override
  String get reportFactDisplay => 'ディスプレイ';

  @override
  String get reportFactAppLanguage => 'アプリの言語';

  @override
  String get reportFactSystemLocale => 'システムの地域';

  @override
  String get reportFactLog => 'ログ';

  @override
  String reportFactLogValue(int count) {
    return '$count件のイベントを添付';
  }

  @override
  String reportProblemScreenshotN(int n) {
    return 'スクリーンショット$n';
  }

  @override
  String reportProblemRemoveScreenshot(int n) {
    return 'スクリーンショット$nを削除';
  }

  @override
  String get reportFactLanguageFromSystem => 'システム設定';

  @override
  String get reportFactLanguageChosen => '手動で選択';

  @override
  String get pageSectionSeeAll => 'すべて表示';

  @override
  String get discoverScreenSeeAllFriendsSemanticLabel => '友だちをすべて表示';

  @override
  String get discoverScreenSeeAllRoomsSemanticLabel => '参加中のルームをすべて表示';

  @override
  String groupCallScreenRingingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人を呼び出し中',
    );
    return '$_temp0';
  }

  @override
  String photoChromeWhenToday(String time) {
    return '今日 $time';
  }

  @override
  String photoChromeWhenYesterday(String time) {
    return '昨日 $time';
  }

  @override
  String photoChromeWhenDate(String date, String time) {
    return '$date $time';
  }

  @override
  String get photoChromeSaved => '保存しました';

  @override
  String get photoChromeSaveFailed => '保存できませんでした';

  @override
  String get photoChromeShareFailed => '共有できませんでした';

  @override
  String photoChromeForwarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のチャットに転送しました',
    );
    return '$_temp0';
  }

  @override
  String get photoChromeForwardFailed => '転送できませんでした';

  @override
  String get photoChromeDeleteFailed => '削除できませんでした';

  @override
  String get photoChromeDeleteBody => 'このチャットにいる全員から削除されます。元に戻すことはできません。';

  @override
  String get roomContentMonthThis => '今月';

  @override
  String get roomContentMonthLast => '先月';

  @override
  String get gameInfoGoalLabel => '目標';

  @override
  String get gameInfoExampleLabel => '例';

  @override
  String get gameInfoWinLabel => '勝ち方';

  @override
  String get gameInfoQueensRule4 => '王冠どうしはくっつけない。ななめもダメ。';

  @override
  String get gameInfoQueensExample =>
      'ここに王冠を置くと、同じ横の列・縦の列・色と、まわりの8マスには、もう置けません。';

  @override
  String get gameInfoTangoRule4 => '= は2マスが同じ。× は2マスがちがう。';

  @override
  String get gameInfoTangoExample => '太陽、太陽、空き？ 空きマスは月に決まり。';

  @override
  String get gameInfoZipRule4 => '上・下・左・右に進む。ななめはダメ。';

  @override
  String get gameInfoZipRule5 => '最後の数字でゴール。';

  @override
  String get gameInfoZipExample => '1から2へ行く？ 必要なら遠回りしよう。空きマスを残してはダメ。';

  @override
  String get gameInfoSudokuExample => '横の列に1・2・4・5・6がある？ 空きマスは3。';

  @override
  String get gameInfoCodeRule4 => '黄色：記号は正解、場所がちがう。';

  @override
  String get gameInfoCodeRule5 => 'グレー：その記号はコードにない。';

  @override
  String get gameInfoCodeExample => '緑・黄・グレー・グレーなら：1つは場所も正解、1つは別の場所、2つはコードにない。';

  @override
  String get leaderboardOverall => '今日';

  @override
  String get leaderboardFooter => '今日解いたパズル1つにつき1ポイント。同点なら、1位になった回数が多い人が上。';

  @override
  String get leaderboardNotPlayed => 'まだプレイしていません';

  @override
  String get leaderboardPlay => 'プレイ';

  @override
  String get leaderboardEmptyTitle => '今日のスコアはまだありません';

  @override
  String get leaderboardEmptyBody => 'パズルを解いて、ランキングの1位になろう。';

  @override
  String get leaderboardGamesHeader => '今日のパズル';

  @override
  String get pointComposerPickFirst => 'まず上から1つ選んで';

  @override
  String get momentStoryNext => '次へ';

  @override
  String get momentStoryPrevious => '前へ';

  @override
  String leaderboardSolved(int solved, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      solved,
      locale: localeName,
      other: '$total問中$solved問クリア',
      zero: 'まだ解いていません',
    );
    return '$_temp0';
  }

  @override
  String leaderboardWins(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count勝',
    );
    return '$_temp0';
  }

  @override
  String leaderboardEmptyAction(String game) {
    return '$gameをプレイ';
  }

  @override
  String get diagCatApi => 'サーバー呼び出し';

  @override
  String get diagCatConnection => '接続';

  @override
  String get diagCatDevice => 'デバイス';

  @override
  String get diagCatError => 'エラー';

  @override
  String get diagCatFrame => '遅いフレーム';

  @override
  String get diagCatLayout => 'レイアウト';

  @override
  String get diagCatLifecycle => 'アプリの状態';

  @override
  String get diagCatLog => 'ログ';

  @override
  String get diagCatNav => 'ナビゲーション';

  @override
  String get diagCatNetwork => 'ネットワーク';

  @override
  String get diagCatSubscription => 'ライブ更新';

  @override
  String get diagSevTrace => 'トレース';

  @override
  String get diagSevDebug => 'デバッグ';

  @override
  String get diagSevInfo => '情報';

  @override
  String get diagSevWarning => '警告';

  @override
  String get diagSevError => 'エラー';

  @override
  String get diagAll => 'すべて';

  @override
  String get diagSearchHint => '名前・詳細・本文を検索';

  @override
  String get diagSummaryCopied => '概要をコピーしました';

  @override
  String get diagShareLog => 'ログを共有';

  @override
  String get diagCopySummary => '概要をコピー';

  @override
  String get diagDeleteAll => 'すべて削除';

  @override
  String get diagUndo => '取り消す';

  @override
  String get diagDeleteLogTitle => 'ログをすべて削除しますか?';

  @override
  String get diagDeleteLogBody =>
      'これまでに記録したイベントと、前回起動時のログがすべて消えます。これから起きることは通常どおり記録されます。';

  @override
  String get diagDelete => '削除';

  @override
  String get diagLogDeleted => 'ログを削除しました';

  @override
  String get diagFilter => 'フィルタ';

  @override
  String get diagMore => 'その他';

  @override
  String get diagLatest => '最新';

  @override
  String get diagJumpToLatest => '最新へ移動';

  @override
  String get diagPaused => '一時停止中';

  @override
  String get diagPreparingLog => 'ログを準備中…';

  @override
  String get diagEmptyNothingTitle => 'まだ何も記録されていません';

  @override
  String get diagEmptyNothingHint => '少しアプリを使うと、ここにイベントが表示されます。';

  @override
  String get diagEmptyHiddenTitle => '今のところ非表示のイベントだけです';

  @override
  String get diagEmptyHiddenHint => '上の薄いチップをタップすると表示、長押しで「すべて」に戻せます。';

  @override
  String get diagEmptyNoMatchTitle => '一致するイベントはありません';

  @override
  String get diagEmptyNoMatchHint => '上の「すべて」をタップするとフィルタを解除できます。';

  @override
  String get diagApply => '適用';

  @override
  String get diagMinSeverity => '最小の重要度';

  @override
  String get diagEverything => 'すべて';

  @override
  String get diagHiddenFromAllHeader => '「すべて」で非表示';

  @override
  String get diagHiddenFromAllFooter =>
      'チップ列で選ぶまで「すべて」から除外されます。チップを長押ししても同じ切り替えができます。';

  @override
  String get diagCollapseRepeats => '繰り返しをまとめる';

  @override
  String get diagCollapseRepeatsSubtitle => '同じイベントの連続を1行にまとめます';

  @override
  String get diagResetFilter => 'フィルタをリセット';

  @override
  String get diagBodyTruncated => '記録時に本文を切り詰めました';

  @override
  String get diagCopyEvent => 'イベントをコピー';

  @override
  String get diagEventCopied => 'イベントをコピーしました';

  @override
  String diagHiddenFromAll(String category) {
    return '$categoryを「すべて」で非表示にしました';
  }

  @override
  String diagBackInAll(String category) {
    return '$categoryを「すべて」に戻しました';
  }

  @override
  String diagChipSemanticLabel(String category, int count) {
    return '$category、$count';
  }

  @override
  String diagChipHiddenSemanticLabel(String category, int count) {
    return '$category、$count、「すべて」で非表示';
  }

  @override
  String diagEventCount(int shown, int total) {
    return '$total件中$shown件のイベント';
  }

  @override
  String diagDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '以前のイベント$count件を破棄しました — ログは途中から始まります',
    );
    return '$_temp0';
  }

  @override
  String diagRepeatSpan(int count, String seconds) {
    return '$seconds秒で×$count';
  }

  @override
  String roomContentTabSemantic(String count, String label) {
    return '$label、$count件';
  }

  @override
  String get mapAppsTitle => 'マップ';

  @override
  String get mapAppsChoose => '位置情報を開くアプリ';

  @override
  String get mapAppsRemember => 'デフォルトに設定';

  @override
  String get mapAppsAskEveryTime => '毎回確認する';

  @override
  String get mapAppsBrowser => 'ブラウザ';

  @override
  String get mapAppsSubtitle => '共有された位置情報を開くアプリを選びます。';

  @override
  String get mapAppsUnavailable => 'デフォルトのマップアプリを利用できません。別のアプリを選んでください。';

  @override
  String get mapAppsNoInstalled => '対応するマップアプリが見つかりません。ブラウザを利用できます。';

  @override
  String get interactionAnswersSearch => '名前や回答を検索';

  @override
  String get interactionFilterEmpty => 'このフィルターに一致する回答はありません。';

  @override
  String get interactionRetry => '再試行';

  @override
  String get cameraEditorScreenCaptionHint => 'キャプションを追加…';

  @override
  String get cameraEditorScreenCaptionViewOnceHint => '1回表示の写真にはキャプションを付けられません';

  @override
  String get cameraEditorScreenAddFromCameraSemanticLabel => 'もう1枚撮る';

  @override
  String cameraEditorScreenDiscardAllTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count枚の写真を破棄しますか？',
      one: 'この写真を破棄しますか？',
    );
    return '$_temp0';
  }

  @override
  String get cameraEditorScreenDiscardAllBody => '編集内容とキャプションは失われます。';

  @override
  String get cameraEditorScreenDiscardAllConfirm => '破棄';

  @override
  String get galleryTrayRecentsTitle => '最近の項目';

  @override
  String get galleryTrayBackToCameraLabel => 'カメラに戻る';

  @override
  String get galleryTrayAllPhotosLabel => 'すべての写真';

  @override
  String get galleryTrayHandleLabel => '最近の写真';

  @override
  String get galleryTrayAllowPrompt => '最近の写真をここに表示';

  @override
  String get galleryTrayAllowButton => '許可';

  @override
  String get galleryTrayDeniedPrompt => '写真へのアクセスがオフです';

  @override
  String get galleryTraySettingsButton => '設定';

  @override
  String get galleryTrayLimitedNote => '許可した写真のみ表示しています';

  @override
  String get galleryTrayManageButton => '管理';

  @override
  String get galleryTrayEmpty => 'まだ写真がありません';

  @override
  String galleryTrayPhotoLabel(int index) {
    return '写真 $index';
  }

  @override
  String get reactionLimitTitle => 'リアクションの上限に達しました';

  @override
  String reactionLimitMessageBody(int limit) {
    return 'スピードと平穏のため、そして一つひとつの絵文字が輝けるように、1つのメッセージにつけられるリアクションは$limit個までです。新しいものをつけるには、どれかを取り消してください。';
  }

  @override
  String reactionLimitHighlightBody(int limit) {
    return 'ハイライトへのリアクションは1人$limit個まで。だからこそ、一つひとつに気持ちがこもります。新しいお気に入りをつけるには、どれかを取り消してください。';
  }

  @override
  String get reactionLimitDismiss => 'OK';

  @override
  String get reactionPickerYoursLabel => 'あなたのリアクション';

  @override
  String reactionPickerTakeBackSemantic(String emoji) {
    return '$emojiのリアクションを取り消す';
  }

  @override
  String get momentCommentsTitle => 'コメント';

  @override
  String momentCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コメント$count件',
      zero: 'コメント',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentsEmptyTitle => 'まだコメントはありません';

  @override
  String get momentCommentsEmptyBody => 'ひとこと、ステッカー、GIFで会話を始めよう。';

  @override
  String get momentCommentHint => 'コメントを追加…';

  @override
  String momentCommentReplyHint(String name) {
    return '$nameさんに返信…';
  }

  @override
  String momentCommentReplyingTo(String name) {
    return '$nameさんに返信中';
  }

  @override
  String get momentCommentCancelReply => '返信をキャンセル';

  @override
  String get momentCommentReply => '返信';

  @override
  String momentCommentViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の返信を表示',
    );
    return '$_temp0';
  }

  @override
  String get momentCommentHideReplies => '返信を非表示';

  @override
  String get momentCommentDelete => 'コメントを削除';

  @override
  String get momentCommentDeleteConfirm => 'このコメントを削除しますか？返信も削除されます。';

  @override
  String get momentCommentDeleteConfirmButton => '削除';

  @override
  String get momentCommentSend => '送信';

  @override
  String get momentCommentExpressions => 'ステッカーとGIF';

  @override
  String get momentCommentFailed => 'コメントを投稿できませんでした。もう一度お試しください。';

  @override
  String get momentCommentAuthorBadge => '投稿者';

  @override
  String get momentCommentLike => 'いいね';

  @override
  String get momentCommentStickerAlt => 'ステッカー';

  @override
  String get momentCommentGifAlt => 'GIF';

  @override
  String get momentCommentPosted => 'コメントを投稿しました';

  @override
  String momentCommentsViewAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'コメント$count件をすべて見る',
    );
    return '$_temp0';
  }

  @override
  String momentReactorsSummary(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人',
    );
    return '$nameさん他$_temp0';
  }

  @override
  String get storageKindPhotos => '写真';

  @override
  String get storageKindVideos => '動画';

  @override
  String get storageKindVideoMessages => 'ビデオメッセージ';

  @override
  String get storageKindVoice => 'ボイスメッセージ';

  @override
  String get storageKindFiles => 'ファイル';

  @override
  String get storageKindStickers => 'ステッカーとGIF';

  @override
  String get storageKindChatHistory => 'チャット履歴';

  @override
  String get storageKindOther => 'その他';

  @override
  String get dataUsageKindCalls => '通話';

  @override
  String get dataStorageTitle => 'データとストレージ';

  @override
  String get settingsSearchKwDataStorage =>
      'ストレージ キャッシュ 容量 空き容量 削除 ダウンロード 自動ダウンロード データ使用量 モバイル通信 モバイル wifi Wi-Fi 写真に保存 ギャラリー storage cache';

  @override
  String get storageUsageTitle => 'ストレージ使用量';

  @override
  String get dataUsageTitle => 'データ使用量';

  @override
  String get dataStorageAutoDownloadHeader => 'メディアの自動ダウンロード';

  @override
  String get dataStorageUsingCellular => 'モバイル通信使用時';

  @override
  String get dataStorageUsingWifi => 'Wi-Fi使用時';

  @override
  String get dataStorageNowTag => '現在';

  @override
  String get autoDownloadReset => '自動ダウンロード設定をリセット';

  @override
  String get autoDownloadResetTitle => '自動ダウンロードの設定をデフォルトに戻しますか？';

  @override
  String get dataStorageSaveHeader => '写真に保存';

  @override
  String get dataStorageSaveFooter => 'これらのチャットの新しい写真とビデオを自動的に写真ライブラリに保存します。';

  @override
  String get dataStorageCallsHeader => '通話';

  @override
  String get dataStorageLessDataForCalls => '通話のデータ使用量を節約';

  @override
  String get dataStorageCallsFooter =>
      '電波が弱いときや従量制のネットワークでデータ使用量を抑えます。音声と映像の品質は少し下がります。';

  @override
  String get dataStorageCallsNever => 'しない';

  @override
  String get dataStorageCallsCellular => 'モバイル通信時';

  @override
  String get dataStorageCallsAlways => '常に';

  @override
  String get dataStorageOff => 'オフ';

  @override
  String get dataStorageChatsPrivate => '個人チャット';

  @override
  String get dataStorageChatsGroups => 'グループ';

  @override
  String get dataStorageChatsPublic => '公開ルーム';

  @override
  String get dataStorageNetCellular => 'モバイル通信';

  @override
  String get dataStorageNetWifi => 'Wi-Fi';

  @override
  String get autoDownloadMaster => 'メディアの自動ダウンロード';

  @override
  String get autoDownloadUsageHeader => 'データ使用量';

  @override
  String get autoDownloadPresetLow => '低';

  @override
  String get autoDownloadPresetMedium => '中';

  @override
  String get autoDownloadPresetHigh => '高';

  @override
  String get autoDownloadCustomFooter =>
      '設定がカスタマイズされています。スライダーを動かすとプリセットに戻ります。';

  @override
  String get autoDownloadTypesHeader => 'メディアの種類';

  @override
  String get autoDownloadVideosTitle => '動画とビデオメッセージ';

  @override
  String get autoDownloadVoiceFooter =>
      'ボイスメッセージとステッカーはサイズが小さいため、常に自動でダウンロードされます。';

  @override
  String get autoDownloadAllChats => 'すべてのチャット';

  @override
  String autoDownloadUpToIn(String size, String chats) {
    return '$chatsで最大$size';
  }

  @override
  String autoDownloadSummaryUpTo(String kind, String size) {
    return '$kind（最大$size）';
  }

  @override
  String get autoDownloadSummaryVoiceOnly => 'ボイスメッセージのみ';

  @override
  String get autoDownloadInHeader => '自動ダウンロードする場所';

  @override
  String get autoDownloadMaxSizeHeader => '最大ファイルサイズ';

  @override
  String autoDownloadMaxSizeVideoFooter(String size) {
    return '$sizeまでの動画は自動でダウンロードされます。それより大きい動画はタップするとダウンロードされます。';
  }

  @override
  String autoDownloadMaxSizeFileFooter(String size) {
    return '$sizeまでのファイルは自動でダウンロードされます。それより大きいファイルはタップするとダウンロードされます。';
  }

  @override
  String get autoDownloadGateLoad => '写真をダウンロード';

  @override
  String get saveToPhotosHeader => '自動保存';

  @override
  String get saveToPhotosFooter =>
      'これらのチャットで受信した新しい写真とビデオは、ダウンロードされると写真ライブラリに追加されます。';

  @override
  String get saveToPhotosMaxVideoHeader => '最大動画サイズ';

  @override
  String get saveToPhotosNoAccess => '自動保存するには、設定で写真ライブラリへのアクセスを許可してください。';

  @override
  String get saveToPhotosPhotosAndVideos => '写真とビデオ';

  @override
  String get storageCalculating => '計算中…';

  @override
  String storageShareOfFree(String percent) {
    return 'MonkeyHubは空き容量の$percentを使用しています。';
  }

  @override
  String get storageEmpty => '現在キャッシュはありません。';

  @override
  String storageClearAllButton(String size) {
    return 'すべてのキャッシュを削除 $size';
  }

  @override
  String storageClearSelectedButton(String size) {
    return '選択項目を削除 $size';
  }

  @override
  String storageClearChatButton(String size) {
    return 'キャッシュを削除 $size';
  }

  @override
  String get storageClearFooter => 'すべてクラウドに残り、必要なときに再びダウンロードされます。';

  @override
  String get storageClearAllTitle => 'すべてのキャッシュを削除しますか？';

  @override
  String get storageClearSelectedTitle => '選択した項目を削除しますか？';

  @override
  String get storageClearBody => 'メッセージは消えません。メディアは開くと再びダウンロードされます。';

  @override
  String storageClearConfirm(String size) {
    return '$sizeを削除';
  }

  @override
  String storageFreed(String size) {
    return '$sizeを解放しました';
  }

  @override
  String storageCleanupTitle(String size) {
    return '$sizeを解放';
  }

  @override
  String get storageCleanupSubtitle => '1か月開いていないメディア';

  @override
  String get storageCleanupAction => '削除';

  @override
  String get storageCleanupFooter =>
      '30日間誰も見ていないメディアだけを削除します。保存済みメッセージには影響しません。';

  @override
  String get storageAutoRemoveHeader => 'キャッシュしたメディアの自動削除';

  @override
  String get storageAutoRemoveFooter =>
      'この期間開いていないメディアは、容量を節約するためこのデバイスから削除されます。クラウドには残り、保存済みメッセージは常に保持されます。';

  @override
  String get dataStorageKeepNever => 'しない';

  @override
  String get dataStorageKeepMonth => '1か月';

  @override
  String get dataStorageKeepWeek => '1週間';

  @override
  String get dataStorageKeepDay => '1日';

  @override
  String get storageLimitHeader => '最大キャッシュサイズ';

  @override
  String get storageLimitFooter =>
      'キャッシュがこのサイズを超えると、最後に開いてから最も時間が経ったメディアから削除されます。';

  @override
  String get dataStorageLimitNone => '制限なし';

  @override
  String get storageTabChats => 'チャット';

  @override
  String get storageTabMedia => 'メディア';

  @override
  String get storageTabFiles => 'ファイル';

  @override
  String get storageNoChats => 'キャッシュされたチャットはまだありません。';

  @override
  String get storageNoMedia => 'キャッシュされた写真やビデオはまだありません。';

  @override
  String get storageNoFiles => 'キャッシュされたファイルはまだありません。';

  @override
  String get storageOpenPhoto => '写真を開く';

  @override
  String get storageOpenVideo => '動画を開く';

  @override
  String get storageSelect => '選択';

  @override
  String storageChatShare(String percent) {
    return 'このチャットはキャッシュの$percentを使用しています。';
  }

  @override
  String get storageChatUnknown => '退出したチャット';

  @override
  String dataUsageSince(String date) {
    return '$date以降';
  }

  @override
  String get dataUsageAll => 'すべて';

  @override
  String get dataUsageNothingYet => 'このネットワークではまだ何も計測されていません。';

  @override
  String get dataUsageTapHint => 'カテゴリをタップすると送受信の内訳が表示されます。';

  @override
  String get dataUsageSent => '送信';

  @override
  String get dataUsageReceived => '受信';

  @override
  String get dataUsageTotalHeader => 'ネットワーク使用量の合計';

  @override
  String get dataUsageFootnote => 'メディアと通話を計測します。メッセージ自体はごく小さいため含まれません。';

  @override
  String get dataUsageReset => '統計をリセット';

  @override
  String get dataUsageResetTitle => 'データ使用量の統計をリセットしますか？';

  @override
  String get dataUsageResetBody => '今から再びカウントを開始します。';

  @override
  String get storageKindCompanions => 'コンパニオン';

  @override
  String get storageCompanionsNote =>
      'コンパニオンはキャッシュと一緒には削除されません。タップしてダウンロードを管理できます。';

  @override
  String storageCategoryCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件、$size',
    );
    return '$_temp0';
  }

  @override
  String get storageSelectAll => 'すべて選択';

  @override
  String get storageDeselectAll => '選択解除';

  @override
  String get storageCategoryEmpty => '現在、この種類のキャッシュはありません。';

  @override
  String get storageChatHistoryFooter =>
      '削除されるのはこの端末上のコピーだけです。メッセージはチャットに残り、次に開いたときに再度読み込まれます。';

  @override
  String get storageCategoryHint => 'カテゴリをタップすると中身を表示、丸をタップすると対象から外せます。';

  @override
  String storageChatRemovedNamed(String names) {
    return '$names · 削除されたチャット';
  }
}
