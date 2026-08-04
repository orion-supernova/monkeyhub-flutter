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
  String get profileScreenLegalSection => '法的情報';

  @override
  String get profileScreenLicence => 'ライセンス';

  @override
  String get profileScreenLinkedAccountsLabel => '連携アカウント';

  @override
  String get profileScreenLinkedAccountsNone => '連携なし';

  @override
  String get profileScreenMyGrownUps => 'わたしの保護者';

  @override
  String get profileScreenNameHint => 'ルームでの見え方です';

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
  String get profileScreenPrivacyPolicy => 'プライバシーポリシー';

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
  String get profileScreenTermsOfService => '利用規約';

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
  String get roomInfoScreenSavedSnackbar => '保存しました';

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
  String get roomInfoScreenDescriptionHint => 'ルームについて一言…';

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
  String get roomInfoScreenReplacePasswordHint => 'パスフレーズを置き換え…';

  @override
  String get roomInfoScreenSetPasswordHint => 'パスフレーズでロック…';

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
  String get roomInfoScreenLoadingMembers => 'メンバーを読み込み中…';

  @override
  String get roomInfoScreenOwnerBadge => 'オーナー';

  @override
  String get roomInfoScreenSaveButton => '保存';

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
  String childPolicyScreenRoomMemberCount(Object count) {
    return '$count人';
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
  String get messageActionMenuForwardLabel => '転送';

  @override
  String get messageActionMenuViewThreadLabel => 'スレッドを見る';

  @override
  String get messageActionMenuCopyLabel => 'コピー';

  @override
  String get messageActionMenuCopyNameLabel => 'ファイル名をコピー';

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
  String get friendRequestDraftScreenHintStartWith => '何か話しかけてみよう…';

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
  String get discoverScreenYourPeopleLabel => '友達';

  @override
  String get discoverScreenNoFriendsYetWithHint => 'まだ誰もいない — 上で人をさがそう';

  @override
  String get discoverScreenNoFriendsYet => 'まだ誰もいない';

  @override
  String get discoverScreenSearchRoomsTitle => 'ルームをさがす';

  @override
  String get discoverScreenSearchRoomsSubtitle => '名前で公開ルームをさがす';

  @override
  String get discoverScreenPublicRoomsLabel => '公開ルーム';

  @override
  String get discoverScreenLoadingRooms => 'さがし中…';

  @override
  String get discoverScreenNoRoomsOpen => '今は開いているルームなし';

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
  String get searchScreenHintPeople => 'ユーザーを検索…';

  @override
  String get searchScreenHintRooms => 'ルームを検索…';

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
  String groupCallScreenParticipantCount(Object count) {
    return '$count人参加中';
  }

  @override
  String get groupCallScreenReconnecting => '再接続中…';

  @override
  String get groupCallScreenUnmuteLabel => 'ミュート解除';

  @override
  String get groupCallScreenMuteLabel => 'ミュート';

  @override
  String get groupCallScreenCamOnLabel => 'カメラオン';

  @override
  String get groupCallScreenCamOffLabel => 'カメラオフ';

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
  String get createRoomSheetNameHint => '正直な名前をつけて…';

  @override
  String get createRoomSheetDescriptionLabel => '説明・任意';

  @override
  String get createRoomSheetDescriptionHint => 'ルームについて一言…';

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
  String get createRoomSheetPasswordHint => '合言葉でロック…';

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
  String get deepOceanThemeEphemeralHint => 'サーバーが忘れることをささやいて…';

  @override
  String get deepOceanThemeDefaultHint => 'なにか話そう…';

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
  String get photoChromeShowInChatSemanticLabel => 'チャットで表示';

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
  String get messageStampSeenLabel => '既読';

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
  String get groupCallBannerPasswordHint => 'パスフレーズ…';

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
  String get viewOnceViewerSocialDividerOr => 'または';

  @override
  String get viewOnceViewerAppleContinueButton => 'Appleで続ける';

  @override
  String get viewOnceViewerGoogleContinueButton => 'Googleで続ける';

  @override
  String get discoverListsPeopleTitle => 'あなたの友だち。';

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
  String get discoverListsFilterHint => '友だちを絞り込む…';

  @override
  String get discoverListsClearFilterSemanticLabel => 'フィルターをクリア';

  @override
  String get discoverListsNoOneYet => 'まだ誰もいません';

  @override
  String discoverListsNoMatches(Object query) {
    return '「$query」に一致する人はいません';
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
  String get roomGridTileLockedBadge => 'ロック';

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
  String get enterPublicRoomFeedTabLabel => 'フィード';

  @override
  String get enterPublicRoomFeedHeadlineSoon => 'まもなく。\n';

  @override
  String get enterPublicRoomFeedHeadlineDetail => '日々の瞬間を、\nルームとシェア。';

  @override
  String get enterPublicRoomFeedPipelineLabel => '近日公開';

  @override
  String get enterPublicRoomFeedBulletPrompt => 'ルームで答える毎日のお題';

  @override
  String get enterPublicRoomFeedBulletVoiceNotes => 'その日のうちに自動で消えるボイスメモ';

  @override
  String get enterPublicRoomFeedBulletWallUpdates => '友達からのゆるい近況が並ぶウォール';

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
  String get roomContentTabHeaderMedia => 'メディア';

  @override
  String get roomContentTabHeaderFiles => 'ファイル';

  @override
  String get roomContentTabHeaderVoice => 'ボイス';

  @override
  String get roomContentTabHeaderLinks => 'リンク';

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
  String get settingsScreenSectionLayout => 'レイアウト';

  @override
  String get settingsScreenSectionGeneral => '一般';

  @override
  String get settingsScreenSectionLinks => 'リンク';

  @override
  String get settingsScreenSectionNotifications => '通知';

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
  String get settingsScreenPushNotificationsLabel => 'プッシュ通知';

  @override
  String get settingsScreenPushOnBody => '新着メッセージやリクエストをお知らせします';

  @override
  String get settingsScreenPushOffBody => '通知なし — アプリを開いたときだけ確認できます';

  @override
  String get authErrorUsernameTaken => 'そのユーザー名はすでに使われています。';

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
  String get glassKnobHintRimOpacity => 'アクセントとなる輪郭線。0にすると縁のないサーフェスに';

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
}
