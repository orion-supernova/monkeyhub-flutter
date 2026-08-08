import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('pt', 'BR'),
    Locale('sv'),
    Locale('tr'),
    Locale('zh'),
  ];

  /// Brand wordmark on the splash screen while the app boots. Proper noun — keep identical across locales, do not translate.
  ///
  /// In en, this message translates to:
  /// **'MONKEYHUB'**
  String get splashBrand;

  /// All-caps label shown when the app fails to connect to the backend on launch.
  ///
  /// In en, this message translates to:
  /// **'CAN’T REACH SERVER'**
  String get bootErrorTitle;

  /// Explanatory line under the boot-error title. 'Convex' is the backend platform's proper noun — keep untranslated.
  ///
  /// In en, this message translates to:
  /// **'Convex didn’t initialize.'**
  String get bootErrorBody;

  /// All-caps button label to retry connecting to the server after a boot error.
  ///
  /// In en, this message translates to:
  /// **'RETRY'**
  String get bootErrorRetry;

  /// Title of the OS/browser notification shown for an incoming 1:1 call.
  ///
  /// In en, this message translates to:
  /// **'Incoming call'**
  String get incomingCallNotificationTitle;

  /// Fallback body text for the incoming-call notification when the caller's name hasn't loaded yet.
  ///
  /// In en, this message translates to:
  /// **'Someone is calling'**
  String get incomingCallFallbackCaller;

  /// All-caps row label in Settings > General that opens the language picker screen.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get settingsLanguageRowLabel;

  /// Lowercase display heading at the top of the language picker screen, matching the app's other picker-screen headings (e.g. 'theme.', 'reply style.').
  ///
  /// In en, this message translates to:
  /// **'language.'**
  String get languageScreenTitle;

  /// Small caption under the language screen's heading, explaining what the setting affects.
  ///
  /// In en, this message translates to:
  /// **'choose the language for menus and messages from the app'**
  String get languageScreenSubtitle;

  /// All-caps option label: follow the device's system language instead of a fixed choice.
  ///
  /// In en, this message translates to:
  /// **'SYSTEM'**
  String get languageOptionSystem;

  /// One-line description under the SYSTEM language option.
  ///
  /// In en, this message translates to:
  /// **'match your device\'s language setting'**
  String get languageOptionSystemSub;

  /// All-caps option label to force the app into English regardless of system language.
  ///
  /// In en, this message translates to:
  /// **'ENGLISH'**
  String get languageOptionEnglish;

  /// All-caps option label to force the app into Turkish regardless of system language. This is the Turkish word for 'Turkish' and is the same string in both the English and Turkish ARB files — language names in a language picker are conventionally shown in their own language (autonym), not translated.
  ///
  /// In en, this message translates to:
  /// **'TÜRKÇE'**
  String get languageOptionTurkish;

  /// Small all-caps badge marking which language option is currently selected.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get languageScreenActiveBadge;

  /// Sentence-case value shown next to the LANGUAGE row in the main Settings list (e.g. 'Scroll list', 'Classic', 'Radial orb' are sibling values for other rows) when the language follows the system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get languageValueSystem;

  /// Sentence-case value shown next to the LANGUAGE row in the main Settings list when English is pinned. Language autonym — keep untranslated.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageValueEnglish;

  /// Sentence-case value shown next to the LANGUAGE row in the main Settings list when Turkish is pinned. Language autonym — same string in both ARB files, keep untranslated.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get languageValueTurkish;

  /// SnackBar shown when the child-guard approval request itself fails to send (network/API error) after tapping ASK.
  ///
  /// In en, this message translates to:
  /// **'couldn’t ask right now — try again'**
  String get roomScreenAskGrownUpFailedSnack;

  /// The 'what' fragment passed to the shared approval-gate sheet when a send is blocked by a family/child guard; the sheet embeds it into a sentence like 'You need a grown-up to say yes before you can {what}.'
  ///
  /// In en, this message translates to:
  /// **'send messages here'**
  String get roomScreenGateSendMessages;

  /// The 'what' fragment passed to the shared approval-gate sheet when a supervised account without media permission taps the attach/camera button.
  ///
  /// In en, this message translates to:
  /// **'send pictures or voice notes'**
  String get roomScreenGateSendMedia;

  /// SnackBar shown when the user tries to select more messages than the multi-select cap allows. {max} is the numeric cap.
  ///
  /// In en, this message translates to:
  /// **'up to {max} at a time'**
  String roomScreenMaxSelectionSnack(Object max);

  /// All-caps headline of the confirm-sheet shown before bulk-deleting selected messages. {count} is how many messages are selected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{DELETE MESSAGE} other{DELETE {count} MESSAGES}}'**
  String roomScreenDeleteMessageHeadline(num count);

  /// Body copy of the confirm-sheet warning before a bulk delete-for-everyone.
  ///
  /// In en, this message translates to:
  /// **'This removes them for everyone in this chat. It cannot be undone.'**
  String get roomScreenDeleteConfirmBody;

  /// All-caps destructive confirm button label on the bulk-delete confirm sheet.
  ///
  /// In en, this message translates to:
  /// **'DELETE FOR EVERYONE'**
  String get roomScreenDeleteConfirmButton;

  /// SnackBar shown when the app cannot locate/scroll to a message the user tried to jump to (via reply tether, pin, or room-info result), e.g. it was deleted or is offline.
  ///
  /// In en, this message translates to:
  /// **'couldn’t jump to that message'**
  String get roomScreenJumpFailedSnack;

  /// SnackBar shown when trying to reopen a view-once photo that was already viewed by this user.
  ///
  /// In en, this message translates to:
  /// **'you’ve already opened this photo.'**
  String get roomScreenViewOnceAlreadyViewed;

  /// SnackBar shown when a view-once photo has been deleted from the server before it could be viewed.
  ///
  /// In en, this message translates to:
  /// **'this photo is no longer available.'**
  String get roomScreenViewOnceGone;

  /// SnackBar shown when fetching a view-once photo fails due to a network error.
  ///
  /// In en, this message translates to:
  /// **'couldn’t load that photo.'**
  String get roomScreenViewOnceNetworkError;

  /// SnackBar shown when reading the bytes of a file picked from the OS file browser fails.
  ///
  /// In en, this message translates to:
  /// **'couldn’t read that file'**
  String get roomScreenFileReadFailedSnack;

  /// SnackBar shown when a picked file exceeds the max upload size. {size} is a pre-formatted human-readable size string like '25 MB'.
  ///
  /// In en, this message translates to:
  /// **'files are capped at {size}'**
  String roomScreenFileSizeCapSnack(Object size);

  /// Fallback body text shown in place of the whole chat screen when the room can no longer be found (e.g. it expired or was deleted).
  ///
  /// In en, this message translates to:
  /// **'room gone'**
  String get roomScreenRoomGone;

  /// SnackBar confirming a message's text was copied to the clipboard from the long-press action menu.
  ///
  /// In en, this message translates to:
  /// **'copied'**
  String get roomScreenCopiedSnack;

  /// SnackBar confirming a file's name was copied to the clipboard from the long-press action menu.
  ///
  /// In en, this message translates to:
  /// **'name copied'**
  String get roomScreenNameCopiedSnack;

  /// SnackBar shown when pinning a message fails because the room already has the maximum number of pinned messages.
  ///
  /// In en, this message translates to:
  /// **'too many pins — unpin one first'**
  String get roomScreenPinLimitSnack;

  /// SnackBar shown for any other (non-limit) failure to pin a message.
  ///
  /// In en, this message translates to:
  /// **'couldn’t pin that'**
  String get roomScreenPinFailedSnack;

  /// SnackBar confirming a message report was submitted, reassuring the reporter it's confidential.
  ///
  /// In en, this message translates to:
  /// **'report sent privately. they won’t be notified.'**
  String get roomScreenReportSentSnack;

  /// Screen-reader semantic label for a selected message row's tap target while multi-select is active (tapping again deselects it).
  ///
  /// In en, this message translates to:
  /// **'Deselect message'**
  String get roomScreenDeselectMessageSemantic;

  /// Screen-reader semantic label for an unselected message row's tap target while multi-select is active.
  ///
  /// In en, this message translates to:
  /// **'Select message'**
  String get roomScreenSelectMessageSemantic;

  /// All-caps chip badge in the room header showing how many members are in a (non-DM) room. {count} is the member count.
  ///
  /// In en, this message translates to:
  /// **'{count} INSIDE'**
  String roomScreenMemberCountBadge(Object count);

  /// Duration unit used to describe an ephemeral room's message lifetime when under a minute, e.g. 'messages dissolve after {ttl}'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} second} other{{count} seconds}}'**
  String roomScreenTtlSeconds(num count);

  /// Duration unit used to describe an ephemeral room's message lifetime when under an hour.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} minute} other{{count} minutes}}'**
  String roomScreenTtlMinutes(num count);

  /// Duration unit used to describe an ephemeral room's message lifetime of an hour or more.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} hour} other{{count} hours}}'**
  String roomScreenTtlHours(num count);

  /// Lowercase caption in the room intro card for ephemeral rooms, explaining the message lifetime. {ttl} is a pre-formatted duration string like '10 minutes'.
  ///
  /// In en, this message translates to:
  /// **'this room is ephemeral. messages dissolve after {ttl}, read or unread.'**
  String roomScreenEphemeralNotice(Object ttl);

  /// All-caps label on the thread-fold chip showing how many loaded messages are folded/collapsed into it.
  ///
  /// In en, this message translates to:
  /// **'{count} MESSAGES'**
  String roomScreenThreadFoldCount(Object count);

  /// Title heading of the empty-state welcome card shown at the top of a brand-new ephemeral room's transcript.
  ///
  /// In en, this message translates to:
  /// **'Secret Space'**
  String get roomScreenSecretSpaceTitle;

  /// Explanatory body text under the 'Secret Space' welcome title.
  ///
  /// In en, this message translates to:
  /// **'Messages in this room are ephemeral. They are automatically removed based on the room’s security policy.'**
  String get roomScreenSecretSpaceBody;

  /// Title of one of the feature cards in the ephemeral-room welcome view.
  ///
  /// In en, this message translates to:
  /// **'Auto-Delete'**
  String get roomScreenAutoDeleteTitle;

  /// Subtitle of the Auto-Delete feature card when the room has a custom (non-fixed) message lifetime.
  ///
  /// In en, this message translates to:
  /// **'Varies'**
  String get roomScreenAutoDeleteVaries;

  /// Subtitle of the Auto-Delete feature card when the room has no explicit message lifetime configured.
  ///
  /// In en, this message translates to:
  /// **'Timed'**
  String get roomScreenAutoDeleteTimed;

  /// Title of the screenshot-protection feature card in the ephemeral-room welcome view.
  ///
  /// In en, this message translates to:
  /// **'No Capture'**
  String get roomScreenNoCaptureTitle;

  /// Subtitle of the 'No Capture' feature card.
  ///
  /// In en, this message translates to:
  /// **'Screenshots Restricted'**
  String get roomScreenNoCaptureSubtitle;

  /// Title of the full-width feature card summarizing extra privacy protections in an ephemeral room.
  ///
  /// In en, this message translates to:
  /// **'Much More Privacy'**
  String get roomScreenMorePrivacyTitle;

  /// Subtitle body text of the full-width 'Much More Privacy' feature card.
  ///
  /// In en, this message translates to:
  /// **'Enjoy extra security features on top of already existing privacy focus.'**
  String get roomScreenMorePrivacySubtitle;

  /// Title of the empty-state placeholder shown for a brand-new, non-ephemeral room with no messages yet.
  ///
  /// In en, this message translates to:
  /// **'No Messages'**
  String get roomScreenNoMessagesTitle;

  /// Subtitle under 'No Messages' encouraging the user to send the first message.
  ///
  /// In en, this message translates to:
  /// **'Start the conversation by sending a message'**
  String get roomScreenNoMessagesSubtitle;

  /// Screen-reader semantic label for tapping a DM peer's avatar in the liquid-style header to open it fullscreen.
  ///
  /// In en, this message translates to:
  /// **'view profile picture'**
  String get roomScreenViewProfilePictureSemantic;

  /// Screen-reader semantic label for tapping a group room's avatar in the liquid-style header to open it fullscreen.
  ///
  /// In en, this message translates to:
  /// **'view room picture'**
  String get roomScreenViewRoomPictureSemantic;

  /// Fallback display name for an outgoing file attachment when the file has no name (message_bubble.dart, OutboundFileRow's fileName).
  ///
  /// In en, this message translates to:
  /// **'document'**
  String get messageBubbleFileFallbackName;

  /// Short status word shown under a sending attachment (view-once photo tile caption, and outbound voice-note row) when the send failed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get messageBubbleAttachmentStatusFailed;

  /// Short status word shown under an attachment still uploading (view-once photo tile caption, and outbound voice-note row).
  ///
  /// In en, this message translates to:
  /// **'sending…'**
  String get messageBubbleAttachmentStatusSending;

  /// Caption on a view-once photo tile once its single view has been spent (shown to both sender and viewer).
  ///
  /// In en, this message translates to:
  /// **'opened'**
  String get messageBubbleViewOnceOpened;

  /// Caption on a view-once photo tile for the recipient once it burned without ever being opened.
  ///
  /// In en, this message translates to:
  /// **'expired'**
  String get messageBubbleViewOnceExpired;

  /// Caption on the sender's own copy of an unopened view-once photo tile.
  ///
  /// In en, this message translates to:
  /// **'view once'**
  String get messageBubbleViewOnceLabel;

  /// Caption on a still-openable view-once photo tile, shown to the recipient.
  ///
  /// In en, this message translates to:
  /// **'tap to view'**
  String get messageBubbleViewOnceTapToView;

  /// Small label word under the wax-seal badge on a sealed view-once photo tile.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get messageBubbleViewOncePhotoLabel;

  /// Screen-reader semantic label for the tappable sealed view-once photo tile.
  ///
  /// In en, this message translates to:
  /// **'view once photo, tap to view'**
  String get messageBubbleViewOnceSemanticLabel;

  /// Screen-reader semantic label for the retry (refresh icon) control on a failed outgoing attachment.
  ///
  /// In en, this message translates to:
  /// **'retry sending'**
  String get messageBubbleRetrySendingSemanticLabel;

  /// Screen-reader semantic label for the discard (close icon) control that deletes a failed outgoing attachment.
  ///
  /// In en, this message translates to:
  /// **'discard'**
  String get messageBubbleDiscardSemanticLabel;

  /// All-caps section header on the own-profile screen, above sign-out/delete/recovery-phrase rows.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get profileScreenAccountSection;

  /// Placeholder text shown next to the mail icon when the user has no email set on their own profile.
  ///
  /// In en, this message translates to:
  /// **'add email'**
  String get profileScreenAddEmailPlaceholder;

  /// Dialog/sheet title shown when tapping to add an email that isn't set yet.
  ///
  /// In en, this message translates to:
  /// **'add email?'**
  String get profileScreenAddEmailTitle;

  /// Dialog/sheet title shown when tapping to add a display name that isn't set yet.
  ///
  /// In en, this message translates to:
  /// **'add name?'**
  String get profileScreenAddNameTitle;

  /// APPROVALS row value showing how many family approval requests are pending.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String profileScreenApprovalsCountWaiting(Object count);

  /// All-caps row label linking to the family approvals screen (guardian view).
  ///
  /// In en, this message translates to:
  /// **'APPROVALS'**
  String get profileScreenApprovalsLabel;

  /// APPROVALS row value when there are zero pending family approval requests.
  ///
  /// In en, this message translates to:
  /// **'nothing waiting'**
  String get profileScreenApprovalsNothingWaiting;

  /// All-caps friendship action button shown when the viewed profile sent the current user an incoming friend request.
  ///
  /// In en, this message translates to:
  /// **'APPROVE'**
  String get profileScreenApproveAction;

  /// All-caps danger button on another user's profile that opens the block confirmation flow.
  ///
  /// In en, this message translates to:
  /// **'BLOCK'**
  String get profileScreenBlockAction;

  /// SnackBar confirming a block action that also deleted the shared DM.
  ///
  /// In en, this message translates to:
  /// **'blocked & DM wiped. they won’t be notified.'**
  String get profileScreenBlockedDmWiped;

  /// SnackBar confirming a block action without deleting the DM.
  ///
  /// In en, this message translates to:
  /// **'blocked. they won’t be notified.'**
  String get profileScreenBlockedOnly;

  /// All-caps row label linking to the blocked-users list under PRIVACY.
  ///
  /// In en, this message translates to:
  /// **'BLOCKED USERS'**
  String get profileScreenBlockedUsers;

  /// All-caps CANCEL button, reused for the edit-field sheet and the avatar-picker sheet.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get profileScreenCancelAction;

  /// All-caps friendship action button shown when the current user has an outgoing friend request pending.
  ///
  /// In en, this message translates to:
  /// **'CANCEL REQUEST'**
  String get profileScreenCancelRequestAction;

  /// All-caps confirm button in the 'just tapped vs change' dialog before editing name/email.
  ///
  /// In en, this message translates to:
  /// **'CHANGE'**
  String get profileScreenChangeAction;

  /// Dialog/sheet title shown when tapping to change an existing email.
  ///
  /// In en, this message translates to:
  /// **'change email?'**
  String get profileScreenChangeEmailTitle;

  /// Dialog/sheet title shown when tapping to change an existing display name.
  ///
  /// In en, this message translates to:
  /// **'change name?'**
  String get profileScreenChangeNameTitle;

  /// Screen-reader semantic label on the camera badge over one's own avatar.
  ///
  /// In en, this message translates to:
  /// **'change profile picture'**
  String get profileScreenChangeProfilePictureSemantic;

  /// All-caps row label shown when the account already has a recovery phrase set.
  ///
  /// In en, this message translates to:
  /// **'CHANGE RECOVERY PHRASE'**
  String get profileScreenChangeRecoveryPhrase;

  /// All-caps option in the avatar-picker sheet to pick a photo from the device gallery.
  ///
  /// In en, this message translates to:
  /// **'CHOOSE FROM LIBRARY'**
  String get profileScreenChooseFromLibrary;

  /// SnackBar shown when saving the avatar image to the device photo library fails.
  ///
  /// In en, this message translates to:
  /// **'couldn’t save image.'**
  String get profileScreenCouldNotSaveImage;

  /// All-caps danger button label for the account-deletion row before the confirm tap.
  ///
  /// In en, this message translates to:
  /// **'DELETE ACCOUNT'**
  String get profileScreenDeleteAccount;

  /// Hint text under the email field explaining it's an optional, private note.
  ///
  /// In en, this message translates to:
  /// **'optional — never shown to anyone'**
  String get profileScreenEmailHint;

  /// All-caps field label in the read-only profile view of someone else's profile.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get profileScreenEmailSectionLabel;

  /// SnackBar error shown when a friend request fails because the two users are already friends.
  ///
  /// In en, this message translates to:
  /// **'you’re already friends.'**
  String get profileScreenErrorAlreadyFriends;

  /// Fallback SnackBar error for an unrecognized friendship-action failure.
  ///
  /// In en, this message translates to:
  /// **'couldn’t complete that.'**
  String get profileScreenErrorGeneric;

  /// SnackBar error shown when the target user has disabled incoming friend requests.
  ///
  /// In en, this message translates to:
  /// **'they’re not accepting friend requests right now.'**
  String get profileScreenErrorNotAccepting;

  /// SnackBar error shown when trying to send a request to someone who already sent you one.
  ///
  /// In en, this message translates to:
  /// **'they already sent you a request — check requests.'**
  String get profileScreenErrorRequestAlreadyReceived;

  /// SnackBar error shown when a friend request was already sent and pending.
  ///
  /// In en, this message translates to:
  /// **'request already sent.'**
  String get profileScreenErrorRequestAlreadySent;

  /// SnackBar error shown when trying to friend/DM someone the current user has blocked.
  ///
  /// In en, this message translates to:
  /// **'you blocked this user — unblock them first.'**
  String get profileScreenErrorUnblockFirst;

  /// Deliberately vague SnackBar error shown for USER_NOT_FOUND, which also covers being blocked by the other user — must stay non-specific.
  ///
  /// In en, this message translates to:
  /// **'this isn’t possible right now.'**
  String get profileScreenErrorUserNotFound;

  /// Snackbar shown when saving the profile display name failed for a reason with no specific message, e.g. no connection.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save your name. Please try again.'**
  String get profileScreenNameNotSaved;

  /// FAMILY row value shown when the guardian has no children added yet.
  ///
  /// In en, this message translates to:
  /// **'add a child'**
  String get profileScreenFamilyAddChild;

  /// FAMILY row value showing how many children are on the guardian's account.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} child} other{{count} children}}'**
  String profileScreenFamilyChildCount(num count);

  /// All-caps label reused for both the guardian's row linking to the family screen and the child's 'who looks after me' section header.
  ///
  /// In en, this message translates to:
  /// **'FAMILY'**
  String get profileScreenFamilyLabel;

  /// All-caps status chip shown on someone else's profile when the two users are friends.
  ///
  /// In en, this message translates to:
  /// **'FRIENDS'**
  String get profileScreenFriendsChip;

  /// Explanatory note under the 'hand this phone back' action on a child's account.
  ///
  /// In en, this message translates to:
  /// **'Only a grown-up can do this — it needs their code or password.'**
  String get profileScreenGrownUpOnlyNote;

  /// Explanatory line under the guardians list on a child's account, describing what guardians can see.
  ///
  /// In en, this message translates to:
  /// **'They can see when you’re online and who you talk to.'**
  String get profileScreenGuardiansCanSee;

  /// All-caps action button on a child's account that starts releasing the device back to a guardian.
  ///
  /// In en, this message translates to:
  /// **'HAND THIS PHONE BACK'**
  String get profileScreenHandPhoneBack;

  /// All-caps status chip shown when the viewed profile sent the current user a friend request.
  ///
  /// In en, this message translates to:
  /// **'INCOMING REQUEST'**
  String get profileScreenIncomingRequestChip;

  /// All-caps dismiss button in the confirm dialog before editing name/email, meaning 'that was an accidental tap'.
  ///
  /// In en, this message translates to:
  /// **'JUST TAPPED'**
  String get profileScreenJustTappedAction;

  /// All-caps section header grouping Report a Problem with the privacy policy / terms / licence links, shown to every account including children.
  ///
  /// In en, this message translates to:
  /// **'HELP & LEGAL'**
  String get settingsScreenSectionHelpAndLegal;

  /// All-caps row label linking to the app's open-source licence page.
  ///
  /// In en, this message translates to:
  /// **'LICENCE'**
  String get settingsScreenLicence;

  /// All-caps row label linking to the social sign-in providers management screen.
  ///
  /// In en, this message translates to:
  /// **'LINKED ACCOUNTS'**
  String get profileScreenLinkedAccountsLabel;

  /// LINKED ACCOUNTS row value shown when no social provider is linked to the account.
  ///
  /// In en, this message translates to:
  /// **'nothing linked'**
  String get profileScreenLinkedAccountsNone;

  /// All-caps card title on a child's account listing their guardians.
  ///
  /// In en, this message translates to:
  /// **'MY GROWN-UPS'**
  String get profileScreenMyGrownUps;

  /// Hint text under the display-name field explaining what it's for.
  ///
  /// In en, this message translates to:
  /// **'how the room will read you'**
  String get profileScreenNameHint;

  /// Guardians-card body text on a child's account when no guardian is set yet.
  ///
  /// In en, this message translates to:
  /// **'nobody looking after this account yet'**
  String get profileScreenNobodyLookingAfter;

  /// All-caps disabled-state label on the friendship action button when the target isn't accepting friend requests.
  ///
  /// In en, this message translates to:
  /// **'NOT ACCEPTING REQUESTS'**
  String get profileScreenNotAcceptingRequestsAction;

  /// All-caps status chip shown on someone else's profile when there's no friendship or pending request.
  ///
  /// In en, this message translates to:
  /// **'NOT CONNECTED'**
  String get profileScreenNotConnectedChip;

  /// All-caps friendship action button shown when viewing a friend's profile, opens the direct message.
  ///
  /// In en, this message translates to:
  /// **'OPEN DM'**
  String get profileScreenOpenDmAction;

  /// SnackBar shown when photo library access is denied while trying to save an avatar.
  ///
  /// In en, this message translates to:
  /// **'photo permission denied.'**
  String get profileScreenPhotoPermissionDenied;

  /// All-caps row label linking to the app's privacy policy.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY POLICY'**
  String get settingsScreenPrivacyPolicy;

  /// All-caps section header above visibility/blocked-users rows on one's own profile.
  ///
  /// In en, this message translates to:
  /// **'PRIVACY'**
  String get profileScreenPrivacySection;

  /// All-caps title of the avatar-picker bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'PROFILE PICTURE'**
  String get profileScreenProfilePictureTitle;

  /// Banner text on another friend's profile when some of their fields are hidden by their visibility settings.
  ///
  /// In en, this message translates to:
  /// **'some fields are hidden by their settings.'**
  String get profileScreenRedactedFriend;

  /// Banner text on a non-friend's profile when their view is limited by visibility settings.
  ///
  /// In en, this message translates to:
  /// **'limited view — they share more with friends.'**
  String get profileScreenRedactedStranger;

  /// All-caps danger button on another user's profile that opens the report flow.
  ///
  /// In en, this message translates to:
  /// **'REPORT'**
  String get profileScreenReportAction;

  /// SnackBar confirming a report was submitted.
  ///
  /// In en, this message translates to:
  /// **'report sent privately. they won’t be notified.'**
  String get profileScreenReportSent;

  /// All-caps status chip shown when the current user has an outgoing friend request to this profile.
  ///
  /// In en, this message translates to:
  /// **'REQUEST PENDING'**
  String get profileScreenRequestPendingChip;

  /// All-caps save button in the name/email edit sheet.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get profileScreenSaveAction;

  /// SnackBar confirming the avatar image was saved to the device photo library.
  ///
  /// In en, this message translates to:
  /// **'saved to photos.'**
  String get profileScreenSavedToPhotos;

  /// All-caps option in the avatar-picker sheet to download the current avatar to the device.
  ///
  /// In en, this message translates to:
  /// **'SAVE TO PHOTOS'**
  String get profileScreenSaveToPhotos;

  /// All-caps friendship action button shown when there's no existing friendship or request.
  ///
  /// In en, this message translates to:
  /// **'SEND REQUEST'**
  String get profileScreenSendRequestAction;

  /// All-caps row label shown when the account has no recovery phrase set yet.
  ///
  /// In en, this message translates to:
  /// **'SET UP RECOVERY PHRASE'**
  String get profileScreenSetUpRecoveryPhrase;

  /// All-caps sign-out row action label.
  ///
  /// In en, this message translates to:
  /// **'SIGN OUT'**
  String get profileScreenSignOut;

  /// All-caps option in the avatar-picker sheet to open the in-app camera.
  ///
  /// In en, this message translates to:
  /// **'TAKE A SELFIE'**
  String get profileScreenTakeSelfie;

  /// All-caps armed-state label on the delete-account row after the first tap, before the second confirming tap.
  ///
  /// In en, this message translates to:
  /// **'TAP AGAIN TO CONFIRM DELETE'**
  String get profileScreenTapAgainToConfirmDelete;

  /// All-caps row label linking to the app's terms of service.
  ///
  /// In en, this message translates to:
  /// **'TERMS OF SERVICE'**
  String get settingsScreenTermsOfService;

  /// All-caps section header above the 'hand this phone back' row on a child's account.
  ///
  /// In en, this message translates to:
  /// **'THIS PHONE'**
  String get profileScreenThisPhoneSection;

  /// All-caps button shown alongside the main friendship action when the two users are already friends.
  ///
  /// In en, this message translates to:
  /// **'UNFRIEND'**
  String get profileScreenUnfriendAction;

  /// Screen-reader semantic label on the tappable avatar that opens the fullscreen viewer.
  ///
  /// In en, this message translates to:
  /// **'view profile picture'**
  String get profileScreenViewProfilePictureSemantic;

  /// All-caps row label linking to the profile-visibility settings screen.
  ///
  /// In en, this message translates to:
  /// **'VISIBILITY PREFERENCES'**
  String get profileScreenVisibilityPreferences;

  /// All-caps chip label in the crop-ratio rail selecting an unconstrained (freeform) crop.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get cameraEditorScreenCropPresetFree;

  /// All-caps chip label in the crop-ratio rail selecting the photo's original aspect ratio.
  ///
  /// In en, this message translates to:
  /// **'ORIG'**
  String get cameraEditorScreenCropPresetOriginal;

  /// Screen-reader label for the top-left X button while in crop mode; it discards the in-progress crop and returns to the draw tool.
  ///
  /// In en, this message translates to:
  /// **'cancel crop'**
  String get cameraEditorScreenCancelCropSemanticLabel;

  /// Screen-reader label for the top-left X button outside crop mode; it closes the editor without sending the photo.
  ///
  /// In en, this message translates to:
  /// **'discard photo'**
  String get cameraEditorScreenDiscardPhotoSemanticLabel;

  /// Screen-reader label for the undo button that removes the last drawn stroke.
  ///
  /// In en, this message translates to:
  /// **'undo'**
  String get cameraEditorScreenUndoSemanticLabel;

  /// Screen-reader label for the redo button that restores the last undone stroke.
  ///
  /// In en, this message translates to:
  /// **'redo'**
  String get cameraEditorScreenRedoSemanticLabel;

  /// Screen-reader label for the button that resets the crop back to the full, uncropped frame.
  ///
  /// In en, this message translates to:
  /// **'reset crop'**
  String get cameraEditorScreenResetCropSemanticLabel;

  /// Screen-reader label for the button that rotates the photo 90 degrees.
  ///
  /// In en, this message translates to:
  /// **'rotate'**
  String get cameraEditorScreenRotateSemanticLabel;

  /// Screen-reader label for the button that enters crop mode.
  ///
  /// In en, this message translates to:
  /// **'crop'**
  String get cameraEditorScreenCropSemanticLabel;

  /// Error message shown in place of the photo when a web browser cannot decode a HEIC image.
  ///
  /// In en, this message translates to:
  /// **'this browser can’t open HEIC photos'**
  String get cameraEditorScreenHeicUnsupportedMessage;

  /// Generic error message shown in place of the photo when it fails to decode for a reason other than HEIC-on-web.
  ///
  /// In en, this message translates to:
  /// **'couldn’t open that image'**
  String get cameraEditorScreenImageLoadFailedMessage;

  /// All-caps pill button that confirms the crop and exits crop mode back to the draw tool.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get cameraEditorScreenCropDoneButton;

  /// Screen-reader label for the icon button that discards this photo and reopens the camera.
  ///
  /// In en, this message translates to:
  /// **'retake'**
  String get cameraEditorScreenRetakeSemanticLabel;

  /// Screen-reader label for the pen toggle button when the drawing tool is currently armed (tapping disarms it).
  ///
  /// In en, this message translates to:
  /// **'put the pen away'**
  String get cameraEditorScreenPenPutAwaySemanticLabel;

  /// Screen-reader label for the pen toggle button when the drawing tool is off (tapping arms it).
  ///
  /// In en, this message translates to:
  /// **'draw on the photo'**
  String get cameraEditorScreenPenDrawSemanticLabel;

  /// All-caps pill button label shown while the photo is being exported/sent.
  ///
  /// In en, this message translates to:
  /// **'SENDING…'**
  String get cameraEditorScreenSendingButton;

  /// All-caps pill button label that sends the edited photo.
  ///
  /// In en, this message translates to:
  /// **'SEND'**
  String get cameraEditorScreenSendButton;

  /// Small caption shown above the send bar explaining that view-once is armed for this photo.
  ///
  /// In en, this message translates to:
  /// **'disappears after it’s opened once'**
  String get cameraEditorScreenViewOnceNote;

  /// Screen-reader label for the trash icon in the pen tray that clears all drawn strokes.
  ///
  /// In en, this message translates to:
  /// **'clear drawing'**
  String get cameraEditorScreenClearDrawingSemanticLabel;

  /// Screen-reader label for the circled-1 view-once toggle when it is currently enabled.
  ///
  /// In en, this message translates to:
  /// **'view once: on'**
  String get cameraEditorScreenViewOnceOnSemanticLabel;

  /// Screen-reader label for the circled-1 view-once toggle when it is currently disabled.
  ///
  /// In en, this message translates to:
  /// **'view once: off'**
  String get cameraEditorScreenViewOnceOffSemanticLabel;

  /// Screen-reader label for each color swatch in the pen tray's color picker.
  ///
  /// In en, this message translates to:
  /// **'ink colour'**
  String get cameraEditorScreenInkColorSemanticLabel;

  /// All-caps sticky-header title for the 'looks' (presets) panel on the glass tuning screen.
  ///
  /// In en, this message translates to:
  /// **'LOOKS'**
  String get glassScreenPanelLooks;

  /// All-caps sticky-header title for the bottom-nav-bar dials panel on the glass tuning screen.
  ///
  /// In en, this message translates to:
  /// **'BOTTOM BAR'**
  String get glassScreenPanelBottomBar;

  /// All-caps sticky-header title for the composer/headers/call-buttons dials panel.
  ///
  /// In en, this message translates to:
  /// **'OTHER SURFACES'**
  String get glassScreenPanelOtherSurfaces;

  /// All-caps sticky-header title for the bottom-bar geometry/layout dials panel.
  ///
  /// In en, this message translates to:
  /// **'BAR LAYOUT'**
  String get glassScreenPanelBarLayout;

  /// Lowercase display heading at the top of the glass tuning screen, matching the app's other picker-screen headings.
  ///
  /// In en, this message translates to:
  /// **'glass.'**
  String get glassScreenTitle;

  /// Caption under the glass screen heading explaining what the transparency dials control.
  ///
  /// In en, this message translates to:
  /// **'how much of what is behind comes through'**
  String get glassScreenSubtitle;

  /// All-caps disabled-state label on the save-look button when every preset slot is used; {max} is the max slot count constant.
  ///
  /// In en, this message translates to:
  /// **'ALL {max} SLOTS FULL'**
  String glassScreenSaveSlotsFull(Object max);

  /// All-caps button label prompting the user to save the current glass tuning as a new named look.
  ///
  /// In en, this message translates to:
  /// **'SAVE CURRENT AS…'**
  String get glassScreenSaveCurrentAs;

  /// All-caps reset-button label shown when there is no active preset, resetting every slider to the untuned recipe.
  ///
  /// In en, this message translates to:
  /// **'RESET EVERY DIAL'**
  String get glassScreenResetEveryDial;

  /// All-caps reset-button label shown when an active preset exists; {name} is the (already-uppercased) preset name.
  ///
  /// In en, this message translates to:
  /// **'RESET TO {name}'**
  String glassScreenResetToPreset(Object name);

  /// Explanatory note under the 'other surfaces' panel header describing which UI elements those dials affect.
  ///
  /// In en, this message translates to:
  /// **'the composer, headers, call buttons — anything that sits over text rather than over scrolling content'**
  String get glassScreenSurfacesNote;

  /// All-caps button label that copies the bottom bar's glass tuning onto the other-surfaces config.
  ///
  /// In en, this message translates to:
  /// **'MATCH THE BOTTOM BAR'**
  String get glassScreenMatchBottomBar;

  /// Subtitle under the active preset row once its dials have drifted from the preset's saved values.
  ///
  /// In en, this message translates to:
  /// **'edited — save it as a new look, or reset it'**
  String get glassScreenPresetEditedSubtitle;

  /// Display name for the synthetic 'no preset selected' row shown when the tuning has no name yet.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get glassScreenCustomPresetName;

  /// Subtitle under the synthetic 'Custom' preset row explaining the tuning isn't saved yet.
  ///
  /// In en, this message translates to:
  /// **'unsaved — give it a name to keep it'**
  String get glassScreenUnsavedSubtitle;

  /// Lowercase dialog title prompting for a name when saving the current glass tuning as a new preset.
  ///
  /// In en, this message translates to:
  /// **'save this look as'**
  String get glassScreenSaveDialogTitle;

  /// Snackbar message shown when trying to save a new preset but all slots are full.
  ///
  /// In en, this message translates to:
  /// **'no room — delete a look first'**
  String get glassScreenNoRoomToast;

  /// Lowercase dialog title prompting for a new name when renaming an existing preset.
  ///
  /// In en, this message translates to:
  /// **'rename'**
  String get glassScreenRenameDialogTitle;

  /// Confirmation dialog title before deleting a saved glass preset; {name} is the preset's (user-given) name.
  ///
  /// In en, this message translates to:
  /// **'delete {name}?'**
  String glassScreenDeleteConfirmTitle(Object name);

  /// Body text in the delete-preset confirmation dialog explaining the tuning itself isn't lost.
  ///
  /// In en, this message translates to:
  /// **'the look stays on screen — it just stops having a name.'**
  String get glassScreenDeleteConfirmBody;

  /// Lowercase button label to cancel deleting a preset and keep it.
  ///
  /// In en, this message translates to:
  /// **'keep'**
  String get glassScreenKeepButton;

  /// Lowercase button label to confirm deleting a preset.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get glassScreenDeleteButton;

  /// Example placeholder hint text in the text field used to name a new saved glass look.
  ///
  /// In en, this message translates to:
  /// **'late night'**
  String get glassScreenNameHint;

  /// Lowercase button label to dismiss the name-entry dialog without saving.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get glassScreenCancelButton;

  /// Lowercase button label to confirm the entered name and save it.
  ///
  /// In en, this message translates to:
  /// **'save'**
  String get glassScreenSaveButton;

  /// Sample room/channel name shown in the surfaces preview's fake chat header, used only to demonstrate the glass header/composer look.
  ///
  /// In en, this message translates to:
  /// **'# balcony'**
  String get glassScreenPreviewRoomName;

  /// Sample online-count text next to the fake room name in the surfaces preview header.
  ///
  /// In en, this message translates to:
  /// **'4 online'**
  String get glassScreenPreviewOnlineCount;

  /// Placeholder text mimicking a composer's hint inside the surfaces preview's fake message-composer row.
  ///
  /// In en, this message translates to:
  /// **'message'**
  String get glassScreenPreviewMessageHint;

  /// Screen-reader label for the preview toggle button when the preview is expanded (tapping collapses it).
  ///
  /// In en, this message translates to:
  /// **'collapse preview'**
  String get glassScreenPreviewCollapseLabel;

  /// Screen-reader label for the preview toggle button when the preview is collapsed (tapping expands it).
  ///
  /// In en, this message translates to:
  /// **'expand preview'**
  String get glassScreenPreviewExpandLabel;

  /// All-caps tag on the floating preview toggle control, labelling the pinned area above it as a preview.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get glassScreenPreviewBadge;

  /// Lowercase subtitle under a built-in (non-deletable, non-renameable) glass preset's name.
  ///
  /// In en, this message translates to:
  /// **'built in'**
  String get glassScreenBuiltInLabel;

  /// Screen-reader/tooltip label on a preset row's save icon that overwrites the saved preset with the current tuning; {name} is the preset's name.
  ///
  /// In en, this message translates to:
  /// **'overwrite {name}'**
  String glassScreenOverwriteTooltip(Object name);

  /// Screen-reader/tooltip label on a preset row's edit icon that opens the rename dialog; {name} is the preset's name.
  ///
  /// In en, this message translates to:
  /// **'rename {name}'**
  String glassScreenRenameTooltip(Object name);

  /// Screen-reader/tooltip label on a preset row's delete icon; {name} is the preset's name.
  ///
  /// In en, this message translates to:
  /// **'delete {name}'**
  String glassScreenDeleteTooltip(Object name);

  /// Screen-reader/tooltip label on a small undo/reset icon button, used both for a single dial's reset (label = the dial's name) and for a whole panel's reset (label = the panel's title).
  ///
  /// In en, this message translates to:
  /// **'reset {label}'**
  String glassScreenResetTooltip(Object label);

  /// Sample chat-message body in the glass screen's scrolling backdrop preview, used only to show glass blur over realistic content.
  ///
  /// In en, this message translates to:
  /// **'sent the roof photos — the tiles are all cracked'**
  String get glassScreenBackdropMsgDilan;

  /// Sample chat-message body in the backdrop preview list.
  ///
  /// In en, this message translates to:
  /// **'ok but who is actually bringing the speaker'**
  String get glassScreenBackdropMsgMert;

  /// Sample group-chat name in the backdrop preview list (one of the rows is a group chat rather than a 1:1).
  ///
  /// In en, this message translates to:
  /// **'family'**
  String get glassScreenBackdropGroupFamily;

  /// Sample message body for the 'family' group row in the backdrop preview, itself quoting a sender named Anne (Turkish for 'mom').
  ///
  /// In en, this message translates to:
  /// **'Anne: dinner at 8, do not be late again'**
  String get glassScreenBackdropMsgFamily;

  /// Sample chat-message body in the backdrop preview list.
  ///
  /// In en, this message translates to:
  /// **'i am outside'**
  String get glassScreenBackdropMsgZeynep;

  /// Sample chat-message body in the backdrop preview list.
  ///
  /// In en, this message translates to:
  /// **'that place on the corner does the good coffee'**
  String get glassScreenBackdropMsgKerem;

  /// Sample group-chat name in the backdrop preview list. Translated as 'mesai' rather than 'iş' to avoid Dart's locale-unaware toUpperCase() mangling the Turkish dotless/dotted i in the avatar-initial logic.
  ///
  /// In en, this message translates to:
  /// **'work'**
  String get glassScreenBackdropGroupWork;

  /// Sample message body for the 'work' group row in the backdrop preview.
  ///
  /// In en, this message translates to:
  /// **'standup moved to 10:30 for the rest of the week'**
  String get glassScreenBackdropMsgWork;

  /// Sample chat-message body in the backdrop preview list.
  ///
  /// In en, this message translates to:
  /// **'no way. send it again i lost it'**
  String get glassScreenBackdropMsgElif;

  /// Sample chat-message body in the backdrop preview list.
  ///
  /// In en, this message translates to:
  /// **'landed 👍'**
  String get glassScreenBackdropMsgBaran;

  /// Sample chat-message body in the backdrop preview list.
  ///
  /// In en, this message translates to:
  /// **'the cat has learned to open the balcony door'**
  String get glassScreenBackdropMsgAyse;

  /// Sample chat-message body in the backdrop preview list.
  ///
  /// In en, this message translates to:
  /// **'see you saturday then'**
  String get glassScreenBackdropMsgCan;

  /// Accessibility (Semantics) label on the compact reply-tether connector, read by screen readers; {name} is the quoted parent message's sender name.
  ///
  /// In en, this message translates to:
  /// **'in reply to {name}'**
  String replyIndicatorInReplyToSemanticLabel(Object name);

  /// Fallback text snippet shown in a reply quote when the quoted parent message is a view-once photo (no persistent thumbnail available).
  ///
  /// In en, this message translates to:
  /// **'photo · view once'**
  String get replyIndicatorViewOnceLabel;

  /// Fallback text snippet shown in a reply quote when the quoted parent message is an audio/voice note (no thumbnail exists for audio).
  ///
  /// In en, this message translates to:
  /// **'voice message'**
  String get replyIndicatorVoiceMessageLabel;

  /// Fallback text snippet shown in a reply quote when the quoted parent message is a file/document attachment.
  ///
  /// In en, this message translates to:
  /// **'document'**
  String get replyIndicatorDocumentLabel;

  /// Italic muted caption shown in place of the quoted text/media when the parent message being replied to has been deleted. Reused identically across all four reply-style designs (phantom echo, sticky note, comic tail, classic quote).
  ///
  /// In en, this message translates to:
  /// **'message removed'**
  String get replyIndicatorMessageRemoved;

  /// Toast shown in the thread overlay when jumping to a reply's parent (via tether tap) or hopping back along the jump-back trail fails because the target message isn't in this thread.
  ///
  /// In en, this message translates to:
  /// **'couldn’t find that message in this thread'**
  String get threadOverlayMessageNotFound;

  /// Toast shown in the thread overlay if sending fails because no valid reply target could be resolved in the current thread.
  ///
  /// In en, this message translates to:
  /// **'couldn’t find the thread to reply to'**
  String get threadOverlayReplyTargetNotFound;

  /// Toast shown when the user tries to reply to a message that is itself still a pending/unsent (optimistic) message in the thread overlay.
  ///
  /// In en, this message translates to:
  /// **'still sending — try again in a second'**
  String get threadOverlayStillSending;

  /// Toast shown in the thread overlay after copying a message's text content to the clipboard via the long-press action menu.
  ///
  /// In en, this message translates to:
  /// **'copied'**
  String get threadOverlayCopiedToast;

  /// Toast shown in the thread overlay after copying a file message's file name to the clipboard via the long-press action menu.
  ///
  /// In en, this message translates to:
  /// **'name copied'**
  String get threadOverlayNameCopiedToast;

  /// Toast shown in the thread overlay when pinning a message fails because the room has hit its pin limit (backend returns PIN_LIMIT_REACHED).
  ///
  /// In en, this message translates to:
  /// **'too many pins — unpin one first'**
  String get threadOverlayPinLimitToast;

  /// Generic toast shown in the thread overlay when pinning a message fails for any reason other than the pin limit.
  ///
  /// In en, this message translates to:
  /// **'couldn’t pin that'**
  String get threadOverlayPinFailedToast;

  /// Toast shown in the thread overlay after successfully submitting a report on a message via the long-press action menu's report sheet.
  ///
  /// In en, this message translates to:
  /// **'reported'**
  String get threadOverlayReportedToast;

  /// Body text shown centered in the thread overlay when the thread has finished loading but turned out to be empty/unavailable (e.g. root message deleted or expired).
  ///
  /// In en, this message translates to:
  /// **'thread unavailable'**
  String get threadOverlayUnavailable;

  /// Inline error under the room-info form when the room name field is left empty on save, and the same message shown for the server-side ROOM_NAME_REQUIRED error.
  ///
  /// In en, this message translates to:
  /// **'name is required'**
  String get roomInfoScreenNameRequiredError;

  /// Snackbar shown after successfully saving room-info changes.
  ///
  /// In en, this message translates to:
  /// **'saved'**
  String get roomInfoScreenSavedSnackbar;

  /// Snackbar shown after removing a room's password.
  ///
  /// In en, this message translates to:
  /// **'password cleared'**
  String get roomInfoScreenPasswordClearedSnackbar;

  /// Title of the confirmation dialog before a user leaves a room.
  ///
  /// In en, this message translates to:
  /// **'leave room?'**
  String get roomInfoScreenLeaveConfirmTitle;

  /// Body text of the leave-room confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'you can rejoin if it stays open.'**
  String get roomInfoScreenLeaveConfirmBody;

  /// All-caps confirm button label in the leave-room confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'LEAVE'**
  String get roomInfoScreenLeaveConfirmButton;

  /// Title of the confirmation dialog before the room owner deletes the room.
  ///
  /// In en, this message translates to:
  /// **'delete room?'**
  String get roomInfoScreenDeleteConfirmTitle;

  /// Body text of the delete-room confirmation dialog, warning the action is irreversible.
  ///
  /// In en, this message translates to:
  /// **'every message in here goes with it. this is permanent.'**
  String get roomInfoScreenDeleteConfirmBody;

  /// All-caps confirm button label in the delete-room confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get roomInfoScreenDeleteConfirmButton;

  /// Title of the confirmation dialog before either participant ends (deletes) a 1:1 DM.
  ///
  /// In en, this message translates to:
  /// **'end this conversation?'**
  String get roomInfoScreenEndConversationConfirmTitle;

  /// Body text of the end-conversation confirmation dialog for a DM, warning that deleting it removes it for the other participant as well.
  ///
  /// In en, this message translates to:
  /// **'{peerName} loses this conversation too — every message disappears for both of you. this is permanent.'**
  String roomInfoScreenEndConversationConfirmBody(String peerName);

  /// All-caps confirm button label in the end-conversation (DM delete) confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'END'**
  String get roomInfoScreenEndConversationConfirmButton;

  /// Fallback used in place of the peer's name in the end-conversation dialog body when the DM peer hasn't loaded yet.
  ///
  /// In en, this message translates to:
  /// **'the other person'**
  String get roomInfoScreenEndConversationPeerFallback;

  /// All-caps cancel button label shared by the leave/delete confirmation dialogs on this screen.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get roomInfoScreenConfirmCancelButton;

  /// Error message shown when saving a room name that collides with an existing room (server ROOM_EXISTS error).
  ///
  /// In en, this message translates to:
  /// **'a room with that name already exists'**
  String get roomInfoScreenErrorRoomExists;

  /// Error message shown when a non-owner attempts an owner-only action (server NOT_OWNER error).
  ///
  /// In en, this message translates to:
  /// **'only the owner can do that'**
  String get roomInfoScreenErrorNotOwner;

  /// Error message shown for a generic permission failure (server NOT_AUTHORIZED error).
  ///
  /// In en, this message translates to:
  /// **'you don’t have permission'**
  String get roomInfoScreenErrorNotAuthorized;

  /// Error message shown when an action targets a room that no longer exists (server ROOM_NOT_FOUND error).
  ///
  /// In en, this message translates to:
  /// **'this room is gone'**
  String get roomInfoScreenErrorRoomNotFound;

  /// Body text shown as the entire screen content when the room being viewed can no longer be found.
  ///
  /// In en, this message translates to:
  /// **'room gone'**
  String get roomInfoScreenRoomGone;

  /// All-caps field label above the room name text input.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get roomInfoScreenNameLabel;

  /// Placeholder hint text inside the room name text input.
  ///
  /// In en, this message translates to:
  /// **'room name'**
  String get roomInfoScreenNameHint;

  /// All-caps field label above the room description text input.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION'**
  String get roomInfoScreenDescriptionLabel;

  /// Placeholder hint text inside the room description text input.
  ///
  /// In en, this message translates to:
  /// **'one line about the room…'**
  String get roomInfoScreenDescriptionHint;

  /// All-caps section label above the public/private visibility toggle.
  ///
  /// In en, this message translates to:
  /// **'VISIBILITY'**
  String get roomInfoScreenVisibilityLabel;

  /// Title of the 'public' option in the room visibility segmented control.
  ///
  /// In en, this message translates to:
  /// **'public'**
  String get roomInfoScreenPublicTitle;

  /// Subtitle explaining the 'public' visibility option.
  ///
  /// In en, this message translates to:
  /// **'anyone can find it'**
  String get roomInfoScreenPublicSub;

  /// Title of the 'private' option in the room visibility segmented control.
  ///
  /// In en, this message translates to:
  /// **'private'**
  String get roomInfoScreenPrivateTitle;

  /// Subtitle explaining the 'private' visibility option.
  ///
  /// In en, this message translates to:
  /// **'invite only'**
  String get roomInfoScreenPrivateSub;

  /// All-caps section label above the message-lifetime (disappearing messages) picker for an ephemeral room.
  ///
  /// In en, this message translates to:
  /// **'MESSAGE LIFE'**
  String get roomInfoScreenMessageLifeLabel;

  /// Short abbreviated duration label for a message-lifetime option under a minute, e.g. '30s'. {value} is the number of seconds.
  ///
  /// In en, this message translates to:
  /// **'{value}s'**
  String roomInfoScreenTtlSeconds(Object value);

  /// Short abbreviated duration label for a message-lifetime option under an hour, e.g. '5m'. {value} is the number of minutes.
  ///
  /// In en, this message translates to:
  /// **'{value}m'**
  String roomInfoScreenTtlMinutes(Object value);

  /// Short abbreviated duration label for a message-lifetime option of an hour or more, e.g. '1h'. {value} is the number of hours.
  ///
  /// In en, this message translates to:
  /// **'{value}h'**
  String roomInfoScreenTtlHours(Object value);

  /// All-caps section label above the room password controls (owner only).
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get roomInfoScreenPasswordLabel;

  /// All-caps small badge shown next to PASSWORD when the room currently has a password set.
  ///
  /// In en, this message translates to:
  /// **'LOCKED'**
  String get roomInfoScreenLockedBadge;

  /// All-caps small label shown next to PASSWORD when the room has no password set.
  ///
  /// In en, this message translates to:
  /// **'NONE'**
  String get roomInfoScreenNoneBadge;

  /// Explanatory caption shown under the PASSWORD section when the room already has a password, before the replace-password field.
  ///
  /// In en, this message translates to:
  /// **'this room is protected. the existing passphrase isn’t shown for security — enter a new one to replace it.'**
  String get roomInfoScreenPasswordProtectedNote;

  /// Placeholder hint text in the password field when the room already has a password (entering one replaces it).
  ///
  /// In en, this message translates to:
  /// **'replace passphrase…'**
  String get roomInfoScreenReplacePasswordHint;

  /// Placeholder hint text in the password field when the room has no password yet.
  ///
  /// In en, this message translates to:
  /// **'lock with a passphrase…'**
  String get roomInfoScreenSetPasswordHint;

  /// All-caps button label to clear the room's existing password.
  ///
  /// In en, this message translates to:
  /// **'REMOVE PASSWORD'**
  String get roomInfoScreenRemovePasswordButton;

  /// All-caps section label above the media/files/voice/links shared-content group.
  ///
  /// In en, this message translates to:
  /// **'SHARED CONTENT'**
  String get roomInfoScreenSharedContentLabel;

  /// All-caps section label above the member list, showing the total member count. {count} is the number of members.
  ///
  /// In en, this message translates to:
  /// **'MEMBERS · {count}'**
  String roomInfoScreenMembersLabel(Object count);

  /// All-caps button label shown in place of LEAVE ROOM while the leave action is in progress.
  ///
  /// In en, this message translates to:
  /// **'LEAVING…'**
  String get roomInfoScreenLeavingButton;

  /// All-caps button label to leave the current room.
  ///
  /// In en, this message translates to:
  /// **'LEAVE ROOM'**
  String get roomInfoScreenLeaveRoomButton;

  /// All-caps button label shown in place of DELETE while the delete action is in progress (owner only).
  ///
  /// In en, this message translates to:
  /// **'DELETING…'**
  String get roomInfoScreenDeletingButton;

  /// All-caps danger button label to permanently delete the room (owner only).
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get roomInfoScreenDeleteButtonLabel;

  /// All-caps button label shown in place of END CONVERSATION while the action is in progress.
  ///
  /// In en, this message translates to:
  /// **'ENDING…'**
  String get roomInfoScreenEndingConversationButton;

  /// All-caps danger button label to end (delete) a 1:1 DM. Shown to either participant, unlike room delete which is owner-only.
  ///
  /// In en, this message translates to:
  /// **'END CONVERSATION'**
  String get roomInfoScreenEndConversationButton;

  /// All-caps small header label shown above the title when this screen is showing info for a 1:1 DM.
  ///
  /// In en, this message translates to:
  /// **'CONVERSATION'**
  String get roomInfoScreenHeaderConversation;

  /// All-caps small header label shown above the title when this screen is showing settings for a group room.
  ///
  /// In en, this message translates to:
  /// **'ROOM SETTINGS'**
  String get roomInfoScreenHeaderRoomSettings;

  /// Screen-reader semantic label on the tappable DM peer avatar that opens it fullscreen.
  ///
  /// In en, this message translates to:
  /// **'view profile picture'**
  String get roomInfoScreenViewProfilePictureSemantic;

  /// Screen-reader semantic label on the tappable room avatar that opens it fullscreen.
  ///
  /// In en, this message translates to:
  /// **'view room picture'**
  String get roomInfoScreenViewRoomPictureSemantic;

  /// Screen-reader semantic label on the camera badge button when the room already has a picture.
  ///
  /// In en, this message translates to:
  /// **'change room picture'**
  String get roomInfoScreenChangeRoomPictureSemantic;

  /// Screen-reader semantic label on the camera badge button when the room has no picture yet.
  ///
  /// In en, this message translates to:
  /// **'add room picture'**
  String get roomInfoScreenAddRoomPictureSemantic;

  /// Placeholder text shown in the members list while the member subscription hasn't returned data yet.
  ///
  /// In en, this message translates to:
  /// **'loading members…'**
  String get roomInfoScreenLoadingMembers;

  /// All-caps small badge shown next to the room creator's name in the member list.
  ///
  /// In en, this message translates to:
  /// **'OWNER'**
  String get roomInfoScreenOwnerBadge;

  /// All-caps primary button label to save changes to the room.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get roomInfoScreenSaveButton;

  /// Lowercase label shown instead of a zero count on a shared-content row (media/files/voice/links) when it is confirmed empty.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get roomInfoScreenNoneCount;

  /// Body text shown on the camera screen when the OS has denied camera permission. Two-line, lowercase sentence-fragment style; 'Settings' refers to the device's system Settings app.
  ///
  /// In en, this message translates to:
  /// **'camera access is off.\nturn it on in Settings to take a photo.'**
  String get cameraScreenAccessDeniedMessage;

  /// Transient status text shown for a fraction of a second while the in-app camera screen falls back to the OS's native camera picker (hardware unavailable or failed to start).
  ///
  /// In en, this message translates to:
  /// **'opening the system camera…'**
  String get cameraScreenOpeningSystemCamera;

  /// Screen-reader semanticLabel for the X button that dismisses the in-app camera screen.
  ///
  /// In en, this message translates to:
  /// **'close camera'**
  String get cameraScreenCloseButtonLabel;

  /// Screen-reader semanticLabel for the moon-icon toggle button, when the exposure boost for dark scenes is currently enabled.
  ///
  /// In en, this message translates to:
  /// **'low-light boost: on'**
  String get cameraScreenLowLightBoostOnLabel;

  /// Screen-reader semanticLabel for the moon-icon toggle button, when the exposure boost for dark scenes is currently disabled.
  ///
  /// In en, this message translates to:
  /// **'low-light boost: off'**
  String get cameraScreenLowLightBoostOffLabel;

  /// Screen-reader semanticLabel for the flash-mode button. {mode} is the raw FlashMode enum name (off/auto/always), deliberately left untranslated per enum .name convention, so it is interpolated as-is into the localized 'flash:' prefix.
  ///
  /// In en, this message translates to:
  /// **'flash: {mode}'**
  String cameraScreenFlashStatusLabel(Object mode);

  /// Screen-reader semanticLabel for the photo-library icon button that lets the user pick an existing photo instead of taking a new one.
  ///
  /// In en, this message translates to:
  /// **'choose from library'**
  String get cameraScreenChooseFromLibraryLabel;

  /// Screen-reader semanticLabel for the button that flips between the front and back camera lens.
  ///
  /// In en, this message translates to:
  /// **'switch camera'**
  String get cameraScreenSwitchCameraLabel;

  /// Screen-reader semanticLabel for the main circular shutter button that captures a photo.
  ///
  /// In en, this message translates to:
  /// **'take photo'**
  String get cameraScreenTakePhotoLabel;

  /// Default all-caps button label under the allowed-contacts list to add someone by their username.
  ///
  /// In en, this message translates to:
  /// **'ADD BY USERNAME'**
  String get childPolicyScreenAddByUsernameLabel;

  /// All-caps CTA button label on the add-a-grown-up prompt sheet.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get childPolicyScreenAddCta;

  /// Explanatory body text on the add-a-grown-up prompt sheet; {name} is the child's display name.
  ///
  /// In en, this message translates to:
  /// **'They get exactly what you have: every request to approve, every setting to change, and the power to remove you. {name} sees them as family straight away.'**
  String childPolicyScreenAddGuardianBlurb(Object name);

  /// All-caps heading of the add-a-grown-up prompt sheet; also reused as the ADD BY USERNAME-style button label in the GROWN-UPS section.
  ///
  /// In en, this message translates to:
  /// **'ADD A GROWN-UP'**
  String get childPolicyScreenAddGuardianHeading;

  /// Text-field placeholder hint on the add-a-grown-up prompt sheet.
  ///
  /// In en, this message translates to:
  /// **'their username'**
  String get childPolicyScreenAddGuardianHint;

  /// All-caps CTA button label on the allow-a-contact-by-username sheet.
  ///
  /// In en, this message translates to:
  /// **'ALLOW'**
  String get childPolicyScreenAllowCta;

  /// Explanatory body text on the allow-a-contact-by-username sheet; {childName} is the child's display name, used twice.
  ///
  /// In en, this message translates to:
  /// **'You won’t be asked about them again — whether {childName} adds them or they add {childName}.'**
  String childPolicyScreenAllowSomeoneBlurb(Object childName);

  /// All-caps heading of the allow-a-contact-by-username sheet.
  ///
  /// In en, this message translates to:
  /// **'ALLOW SOMEONE'**
  String get childPolicyScreenAllowSomeoneHeading;

  /// All-caps toggle label for the child-can-request-new-contacts permission.
  ///
  /// In en, this message translates to:
  /// **'ASK TO ADD'**
  String get childPolicyScreenAskToAddLabel;

  /// Toggle sub-description shown when the ASK TO ADD permission is off.
  ///
  /// In en, this message translates to:
  /// **'family only — no new requests'**
  String get childPolicyScreenAskToAddOffDesc;

  /// Toggle sub-description shown when the ASK TO ADD permission is on.
  ///
  /// In en, this message translates to:
  /// **'they can ask you about new people'**
  String get childPolicyScreenAskToAddOnDesc;

  /// Note under the WHEN THEY'RE DONE section header for a guardian who is not the sole guardian; references the GROWN-UPS section by its translated name.
  ///
  /// In en, this message translates to:
  /// **'Both of these are final. Stepping away instead is up in GROWN-UPS.'**
  String get childPolicyScreenBothFinalNote;

  /// All-caps toggle label for the child's calling permission.
  ///
  /// In en, this message translates to:
  /// **'CALLS'**
  String get childPolicyScreenCallsLabel;

  /// Toggle sub-description shown when the CALLS permission is off.
  ///
  /// In en, this message translates to:
  /// **'messages only'**
  String get childPolicyScreenCallsOffDesc;

  /// Toggle sub-description shown when the CALLS permission is on.
  ///
  /// In en, this message translates to:
  /// **'voice + video with people they’re allowed'**
  String get childPolicyScreenCallsOnDesc;

  /// All-caps Cancel button label, shared by the add-contact and add-guardian/graduate prompt sheets.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get childPolicyScreenCancelLabel;

  /// Screen-reader semantic label for the Cancel button on the prompt sheet (heading style, not all-caps).
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get childPolicyScreenCancelSemanticLabel;

  /// Snackbar shown after allowing a contact by username, when the friend request is sent immediately.
  ///
  /// In en, this message translates to:
  /// **'added — the request is on its way'**
  String get childPolicyScreenContactAddedRequestSent;

  /// Snackbar shown after allowing a contact by username, when the request is deferred (not sent immediately).
  ///
  /// In en, this message translates to:
  /// **'added to the allowed list'**
  String get childPolicyScreenContactAddedToList;

  /// All-caps toggle label for the child's ability to create their own rooms.
  ///
  /// In en, this message translates to:
  /// **'MAKE ROOMS'**
  String get childPolicyScreenCreateRoomsLabel;

  /// Toggle sub-description shown when the MAKE ROOMS permission is off.
  ///
  /// In en, this message translates to:
  /// **'they can’t start rooms'**
  String get childPolicyScreenCreateRoomsOffDesc;

  /// Toggle sub-description shown when the MAKE ROOMS permission is on.
  ///
  /// In en, this message translates to:
  /// **'they can start their own private rooms'**
  String get childPolicyScreenCreateRoomsOnDesc;

  /// Body text of the confirmation sheet before permanently deleting the child's account.
  ///
  /// In en, this message translates to:
  /// **'Everything goes: their messages, photos, rooms, and friends. This cannot be undone, and the username is freed for anyone else.'**
  String get childPolicyScreenDeleteAccountBody;

  /// Snackbar shown when deleting the child's account fails.
  ///
  /// In en, this message translates to:
  /// **'couldn’t delete the account — try again'**
  String get childPolicyScreenDeleteAccountFailed;

  /// All-caps headline of the confirmation sheet before deleting the child's account; {name} is already upper-cased by the caller.
  ///
  /// In en, this message translates to:
  /// **'DELETE {name}’S ACCOUNT?'**
  String childPolicyScreenDeleteAccountHeadline(Object name);

  /// Detail line under the DELETE ACCOUNT danger-zone button.
  ///
  /// In en, this message translates to:
  /// **'Messages, photos, rooms and friends all go. Cannot be undone.'**
  String get childPolicyScreenDeleteDangerDetail;

  /// All-caps danger-zone button label to delete the child's account; {name} is already upper-cased by the caller.
  ///
  /// In en, this message translates to:
  /// **'DELETE {name}’S ACCOUNT'**
  String childPolicyScreenDeleteDangerLabel(Object name);

  /// All-caps confirm button label on the delete-account confirmation sheet.
  ///
  /// In en, this message translates to:
  /// **'DELETE FOREVER'**
  String get childPolicyScreenDeleteForeverCta;

  /// Fallback error snackbar when adding a contact by username fails for an unrecognized reason.
  ///
  /// In en, this message translates to:
  /// **'couldn’t add them — try again'**
  String get childPolicyScreenErrorAddContactGeneric;

  /// Error snackbar when the guardian tries to add the child's own username as a contact.
  ///
  /// In en, this message translates to:
  /// **'that’s their own username'**
  String get childPolicyScreenErrorCannotAddSelf;

  /// Error snackbar when trying to add a child account as a guardian.
  ///
  /// In en, this message translates to:
  /// **'a child can’t be a grown-up'**
  String get childPolicyScreenErrorChildNotAllowed;

  /// Fallback error snackbar for guardian-management actions (add/remove) that fail for an unrecognized reason.
  ///
  /// In en, this message translates to:
  /// **'couldn’t do that — try again'**
  String get childPolicyScreenErrorGenericGuardian;

  /// Error snackbar when trying to remove the child's only remaining guardian.
  ///
  /// In en, this message translates to:
  /// **'someone has to look after them — add another grown-up first'**
  String get childPolicyScreenErrorLastGuardian;

  /// Error snackbar when the current user isn't authorized to make this change (used for both add-contact and guardian actions).
  ///
  /// In en, this message translates to:
  /// **'that’s not yours to change'**
  String get childPolicyScreenErrorNotYours;

  /// Error snackbar when a username entered (for a new contact or new guardian) doesn't match any account.
  ///
  /// In en, this message translates to:
  /// **'no account with that username'**
  String get childPolicyScreenErrorUserNotFound;

  /// Explanatory body text on the graduate-child-to-adult-account prompt sheet.
  ///
  /// In en, this message translates to:
  /// **'They become a normal account with this password, and every grown-up loses all visibility. There is no way back — you would have to be invited like anyone else.'**
  String get childPolicyScreenGraduateBlurb;

  /// All-caps CTA button label on the graduate-child prompt sheet.
  ///
  /// In en, this message translates to:
  /// **'GRADUATE'**
  String get childPolicyScreenGraduateCta;

  /// Detail line under the GRADUATE TO A FULL ACCOUNT danger-zone button.
  ///
  /// In en, this message translates to:
  /// **'They keep everything and get a password. You lose all visibility. Irreversible.'**
  String get childPolicyScreenGraduateDangerDetail;

  /// All-caps danger-zone button label to graduate the child to a normal adult account.
  ///
  /// In en, this message translates to:
  /// **'GRADUATE TO A FULL ACCOUNT'**
  String get childPolicyScreenGraduateDangerLabel;

  /// Snackbar shown when graduating the child to an adult account fails.
  ///
  /// In en, this message translates to:
  /// **'couldn’t graduate them — try again'**
  String get childPolicyScreenGraduateFailed;

  /// All-caps headline of the graduate-child prompt sheet; {name} is already upper-cased by the caller.
  ///
  /// In en, this message translates to:
  /// **'GRADUATE {name}'**
  String childPolicyScreenGraduateHeading(Object name);

  /// Password-field placeholder hint on the graduate-child prompt sheet.
  ///
  /// In en, this message translates to:
  /// **'a password for them'**
  String get childPolicyScreenGraduateHint;

  /// Footnote under the ROOMS YOU'VE ALLOWED list explaining what revoking does.
  ///
  /// In en, this message translates to:
  /// **'Taking a room back also removes them from it. Taking a person back deletes their chat as well — for both of them.'**
  String get childPolicyScreenGrantsFooterNote;

  /// Explanatory text under the GROWN-UPS section header.
  ///
  /// In en, this message translates to:
  /// **'Everyone here can approve, change settings, and see everything. Any of them can act alone — nothing waits on the others.'**
  String get childPolicyScreenGrownUpsDesc;

  /// Snackbar shown after successfully adding a new guardian.
  ///
  /// In en, this message translates to:
  /// **'added — they can look after them now'**
  String get childPolicyScreenGuardianAdded;

  /// Snackbar shown after successfully removing another guardian; {name} is that guardian's display name.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String childPolicyScreenGuardianRemoved(Object name);

  /// Guardian row title suffix marking which guardian in the list is the current user; {name} is the guardian's display name.
  ///
  /// In en, this message translates to:
  /// **'{name} (you)'**
  String childPolicyScreenGuardianYouSuffix(Object name);

  /// Placeholder text shown while the allowed-contacts/rooms grants list is loading.
  ///
  /// In en, this message translates to:
  /// **'loading…'**
  String get childPolicyScreenLoading;

  /// Small all-caps badge next to a fixed (non-toggleable) policy note, e.g. PUBLIC ROOMS.
  ///
  /// In en, this message translates to:
  /// **'LOCKED'**
  String get childPolicyScreenLockedLabel;

  /// All-caps toggle label for the child's ability to send photos/video/voice notes.
  ///
  /// In en, this message translates to:
  /// **'PHOTOS + VOICE'**
  String get childPolicyScreenMediaLabel;

  /// Toggle sub-description shown when the PHOTOS + VOICE permission is off.
  ///
  /// In en, this message translates to:
  /// **'text only'**
  String get childPolicyScreenMediaOffDesc;

  /// Toggle sub-description shown when the PHOTOS + VOICE permission is on.
  ///
  /// In en, this message translates to:
  /// **'they can send pictures, video and voice notes'**
  String get childPolicyScreenMediaOnDesc;

  /// Empty-state placeholder shown when the child has no allowed rooms.
  ///
  /// In en, this message translates to:
  /// **'no rooms yet'**
  String get childPolicyScreenNoRoomsYet;

  /// Explanatory text under the PEOPLE YOU'VE ALLOWED section header.
  ///
  /// In en, this message translates to:
  /// **'Anyone here can be added without asking you again — whichever of them starts it.'**
  String get childPolicyScreenPeopleAllowedDesc;

  /// Explanatory body text for the fixed (locked) PUBLIC ROOMS policy note.
  ///
  /// In en, this message translates to:
  /// **'Always off for kids. Discover — the list of rooms belonging to people you don’t know — is hidden completely and can’t be switched on. Rooms someone invites them to still work as normal.'**
  String get childPolicyScreenPublicRoomsBody;

  /// All-caps label for the fixed (locked) public-rooms policy note.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC ROOMS'**
  String get childPolicyScreenPublicRoomsLabel;

  /// Body text of the confirmation sheet before removing another guardian; {guardian} is that guardian's name, {child} is the child's name.
  ///
  /// In en, this message translates to:
  /// **'{guardian} will no longer see or approve anything for {child}.'**
  String childPolicyScreenRemoveGuardianBody(Object child, Object guardian);

  /// All-caps headline of the confirmation sheet before removing another guardian; {name} is already upper-cased by the caller.
  ///
  /// In en, this message translates to:
  /// **'REMOVE {name}?'**
  String childPolicyScreenRemoveGuardianHeadline(Object name);

  /// All-caps action label — both the confirm button when removing a guardian and the inline row action for a guardian who isn't the current user.
  ///
  /// In en, this message translates to:
  /// **'REMOVE'**
  String get childPolicyScreenRemoveLabel;

  /// Short subtitle on an allowed-room row showing how many members are in it.
  ///
  /// In en, this message translates to:
  /// **'{count} in'**
  String childPolicyScreenRoomMemberCount(Object count);

  /// All-caps section header listing the child's guardians.
  ///
  /// In en, this message translates to:
  /// **'GROWN-UPS'**
  String get childPolicyScreenSectionGrownUps;

  /// All-caps section header listing contacts pre-approved for the child.
  ///
  /// In en, this message translates to:
  /// **'PEOPLE YOU’VE ALLOWED'**
  String get childPolicyScreenSectionPeopleAllowed;

  /// All-caps section header listing rooms pre-approved for the child.
  ///
  /// In en, this message translates to:
  /// **'ROOMS YOU’VE ALLOWED'**
  String get childPolicyScreenSectionRoomsAllowed;

  /// All-caps section header over the child's permission toggles.
  ///
  /// In en, this message translates to:
  /// **'WHAT THEY CAN DO'**
  String get childPolicyScreenSectionWhatTheyCanDo;

  /// All-caps section header over the graduate/delete danger-zone actions.
  ///
  /// In en, this message translates to:
  /// **'WHEN THEY’RE DONE'**
  String get childPolicyScreenSectionWhenDone;

  /// Sub-description on the allow-contact sheet's send-now toggle, shown when send-now is off.
  ///
  /// In en, this message translates to:
  /// **'nothing happens until someone adds the other'**
  String get childPolicyScreenSendNowOffDesc;

  /// Sub-description on the allow-contact sheet's send-now toggle, shown when send-now is on.
  ///
  /// In en, this message translates to:
  /// **'they get asked straight away'**
  String get childPolicyScreenSendNowOnDesc;

  /// All-caps label for the send-request-now toggle on the allow-contact sheet.
  ///
  /// In en, this message translates to:
  /// **'SEND THE REQUEST NOW'**
  String get childPolicyScreenSendRequestNowLabel;

  /// Note under WHEN THEY'RE DONE shown when the current guardian is the child's only guardian; {name} is the child's display name.
  ///
  /// In en, this message translates to:
  /// **'You’re {name}’s only grown-up, so you can’t just step away — add another first, or use one of these.'**
  String childPolicyScreenSoleGuardianNote(Object name);

  /// All-caps inline row action label for the current user to remove themself as guardian.
  ///
  /// In en, this message translates to:
  /// **'STEP AWAY'**
  String get childPolicyScreenStepAwayLabel;

  /// Body text of the confirmation sheet when the current guardian removes themself; {name} is the child's display name.
  ///
  /// In en, this message translates to:
  /// **'You’ll lose every bit of visibility into {name}’s account — their requests, their people, their rooms. The other grown-ups keep looking after them.'**
  String childPolicyScreenStopSupervisingBody(Object name);

  /// All-caps confirm button label when the current guardian removes themself.
  ///
  /// In en, this message translates to:
  /// **'STOP SUPERVISING'**
  String get childPolicyScreenStopSupervisingCta;

  /// All-caps headline of the confirmation sheet when the current guardian removes themself.
  ///
  /// In en, this message translates to:
  /// **'STOP SUPERVISING?'**
  String get childPolicyScreenStopSupervisingHeadline;

  /// Snackbar shown when revoking a contact or room grant fails.
  ///
  /// In en, this message translates to:
  /// **'couldn’t take them back — try again'**
  String get childPolicyScreenTakeBackFailed;

  /// Default all-caps inline row action label to revoke an allowed contact or room.
  ///
  /// In en, this message translates to:
  /// **'TAKE BACK'**
  String get childPolicyScreenTakeBackLabel;

  /// Text-field placeholder hint on the allow-contact-by-username sheet.
  ///
  /// In en, this message translates to:
  /// **'username'**
  String get childPolicyScreenUsernameHint;

  /// Placeholder name used for the current guardian in the guardian-removed snackbar; in practice this branch is unreachable today since removing yourself navigates away instead of showing the snackbar, but is localized for correctness.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get childPolicyScreenYou;

  /// Fallback name used when a shared file message has no file name — shown as the row title/badge source and passed as the saved file's name.
  ///
  /// In en, this message translates to:
  /// **'document'**
  String get roomContentScreenDefaultDocumentName;

  /// Snackbar shown when tapping a shared file to save/open it fails.
  ///
  /// In en, this message translates to:
  /// **'couldn’t open that file'**
  String get roomContentScreenCouldntOpenFile;

  /// Snackbar shown when sharing the selected items via the OS share sheet fails.
  ///
  /// In en, this message translates to:
  /// **'couldn’t share those'**
  String get roomContentScreenCouldntShare;

  /// Snackbar confirming link URL(s) were copied to the clipboard from the LINKS tab; count is how many links were copied.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{copied} other{copied {count} links}}'**
  String roomContentScreenLinksCopied(num count);

  /// All-caps headline of the destructive confirm sheet before deleting the selected shared message(s); count is how many are selected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{DELETE MESSAGE} other{DELETE {count} MESSAGES}}'**
  String roomContentScreenDeleteHeadline(num count);

  /// Body copy of the destructive confirm sheet, warning that deleting removes the message(s) for everyone in the room and can't be undone.
  ///
  /// In en, this message translates to:
  /// **'This removes them for everyone in this chat. It cannot be undone.'**
  String get roomContentScreenDeleteBody;

  /// All-caps confirm button label on the destructive sheet for permanently deleting the selected shared message(s) for everyone in the room.
  ///
  /// In en, this message translates to:
  /// **'DELETE FOR EVERYONE'**
  String get roomContentScreenDeleteForEveryone;

  /// Tooltip for the header's close (X) icon button, shown while multi-select mode is active.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get roomContentScreenCancelTooltip;

  /// Tooltip for the header's back chevron icon button, shown when not in multi-select mode.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get roomContentScreenBackTooltip;

  /// All-caps small header eyebrow label shown while multi-select mode is active on the shared-content browser.
  ///
  /// In en, this message translates to:
  /// **'SELECTING'**
  String get roomContentScreenSelectingLabel;

  /// All-caps small header eyebrow label for the shared-content browser screen, shown when not selecting.
  ///
  /// In en, this message translates to:
  /// **'SHARED CONTENT'**
  String get roomContentScreenSharedContentLabel;

  /// Header subtitle shown in multi-select mode reporting how many shared items are currently picked; count is the number selected.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{nothing picked} other{{count} selected}}'**
  String roomContentScreenSelectionCount(num count);

  /// All-caps header pill button label to enter multi-select mode on the shared-content browser.
  ///
  /// In en, this message translates to:
  /// **'SELECT'**
  String get roomContentScreenSelectAllLabel;

  /// All-caps header pill button label to select every item on screen, shown once multi-select mode is already active.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get roomContentScreenSelectAllActiveLabel;

  /// Empty-state copy for the MEDIA tab of the shared-content browser when the room has nothing shared yet.
  ///
  /// In en, this message translates to:
  /// **'no photos or videos yet'**
  String get roomContentScreenEmptyMedia;

  /// Empty-state copy for the FILES tab of the shared-content browser when the room has nothing shared yet.
  ///
  /// In en, this message translates to:
  /// **'no files yet'**
  String get roomContentScreenEmptyFiles;

  /// Empty-state copy for the VOICE tab of the shared-content browser when the room has nothing shared yet.
  ///
  /// In en, this message translates to:
  /// **'no voice notes yet'**
  String get roomContentScreenEmptyVoice;

  /// Empty-state copy for the LINKS tab of the shared-content browser when the room has nothing shared yet.
  ///
  /// In en, this message translates to:
  /// **'no links yet'**
  String get roomContentScreenEmptyLinks;

  /// Empty-state copy shown in place of the tab's normal empty message when loading the shared-content list failed.
  ///
  /// In en, this message translates to:
  /// **'couldn’t load that'**
  String get roomContentScreenLoadFailed;

  /// Semantic/accessibility label for a voice-note row in the VOICE tab, naming who sent it; {name} is the sender's display name.
  ///
  /// In en, this message translates to:
  /// **'Voice message from {name}'**
  String roomContentScreenVoiceMessageFrom(Object name);

  /// All-caps bulk-action bar button label to forward the selected shared items to another room.
  ///
  /// In en, this message translates to:
  /// **'FORWARD'**
  String get roomContentScreenForwardAction;

  /// All-caps bulk-action bar button label to copy the selected link URLs to the clipboard, shown only on the LINKS tab.
  ///
  /// In en, this message translates to:
  /// **'COPY'**
  String get roomContentScreenCopyAction;

  /// All-caps bulk-action bar button label to save the selected photos/videos to the device's photo library.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get roomContentScreenSaveAction;

  /// All-caps bulk-action bar button label to share the selected shared items via the OS share sheet.
  ///
  /// In en, this message translates to:
  /// **'SHARE'**
  String get roomContentScreenShareAction;

  /// All-caps bulk-action bar button label to jump to the single selected item in the chat transcript.
  ///
  /// In en, this message translates to:
  /// **'IN CHAT'**
  String get roomContentScreenInChatAction;

  /// All-caps bulk-action bar button label to delete the selected shared message(s) for everyone in the room.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get roomContentScreenDeleteAction;

  /// All-caps row label in the long-press message action menu; replies to the selected message.
  ///
  /// In en, this message translates to:
  /// **'REPLY'**
  String get messageActionMenuReplyLabel;

  /// All-caps row label in the long-press message action menu; forwards the selected message to another chat/room.
  ///
  /// In en, this message translates to:
  /// **'FORWARD'**
  String get messageActionMenuForwardLabel;

  /// All-caps row label in the long-press message action menu, shown when the message has a parent/thread; opens the reply thread for the message.
  ///
  /// In en, this message translates to:
  /// **'VIEW THREAD'**
  String get messageActionMenuViewThreadLabel;

  /// All-caps row label in the long-press message action menu; copies the message's text body to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'COPY'**
  String get messageActionMenuCopyLabel;

  /// All-caps row label in the long-press message action menu, shown only for document bubbles; copies the document's filename to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'COPY NAME'**
  String get messageActionMenuCopyNameLabel;

  /// All-caps row label in the long-press message action menu; pins the message to the room. Shown only when the message is not already pinned.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get messageActionMenuPinLabel;

  /// All-caps row label in the long-press message action menu; unpins an already-pinned message. Shown only when the message is currently pinned.
  ///
  /// In en, this message translates to:
  /// **'UNPIN'**
  String get messageActionMenuUnpinLabel;

  /// All-caps row label in the long-press message action menu; enters multi-select mode on the transcript with this message already picked.
  ///
  /// In en, this message translates to:
  /// **'SELECT'**
  String get messageActionMenuSelectLabel;

  /// All-caps row label in the long-press message action menu, shown on other people's messages; opens the sender's profile.
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get messageActionMenuProfileLabel;

  /// All-caps destructive row label in the long-press message action menu, shown on the current user's own messages; deletes the message.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get messageActionMenuDeleteLabel;

  /// All-caps destructive row label in the long-press message action menu, shown on other people's messages; reports the message.
  ///
  /// In en, this message translates to:
  /// **'REPORT'**
  String get messageActionMenuReportLabel;

  /// Lowercase display heading at the top of the theme picker screen.
  ///
  /// In en, this message translates to:
  /// **'theme.'**
  String get themeScreenTitle;

  /// Caption under the theme screen heading explaining how to use the picker (⛶ glyph kept as-is, decorative).
  ///
  /// In en, this message translates to:
  /// **'tap to apply · ⛶ for full preview'**
  String get themeScreenTapToApplyHint;

  /// All-caps group header label for the 'BASIC' theme family card (5 palette variants).
  ///
  /// In en, this message translates to:
  /// **'BASIC'**
  String get themeScreenFamilyBasicName;

  /// Small tagline under the BASIC theme family header describing its style and variant count.
  ///
  /// In en, this message translates to:
  /// **'ios-inspired · 5 palettes'**
  String get themeScreenFamilyBasicTagline;

  /// All-caps group header label for the 'VAULT' theme family card (noir + ivory variants).
  ///
  /// In en, this message translates to:
  /// **'VAULT'**
  String get themeScreenFamilyVaultName;

  /// Small tagline under the VAULT theme family header describing its style and variants.
  ///
  /// In en, this message translates to:
  /// **'private dossier · noir + ivory'**
  String get themeScreenFamilyVaultTagline;

  /// All-caps group header label for the 'OTHERS' catch-all theme family card (standalone singular-mood themes).
  ///
  /// In en, this message translates to:
  /// **'OTHERS'**
  String get themeScreenFamilyOthersName;

  /// Small tagline under the OTHERS theme family header.
  ///
  /// In en, this message translates to:
  /// **'singular moods'**
  String get themeScreenFamilyOthersTagline;

  /// Small all-caps badge shown on the currently-applied theme's grid tile.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get themeScreenActiveBadge;

  /// Small hint label shown on a non-active theme's grid tile.
  ///
  /// In en, this message translates to:
  /// **'tap to apply'**
  String get themeScreenTapToApplyLabel;

  /// All-caps CTA pill label in the full-screen theme preview carousel when the shown theme is already applied; {name} is the theme's display name, already uppercased.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE — {name}'**
  String themeScreenCarouselActiveLabel(Object name);

  /// All-caps CTA pill label in the full-screen theme preview carousel when the shown theme is not yet applied; {name} is the theme's display name, already uppercased.
  ///
  /// In en, this message translates to:
  /// **'APPLY {name}'**
  String themeScreenCarouselApplyLabel(Object name);

  /// Lowercase display heading inside the mock chat preview shown when previewing a theme in the carousel.
  ///
  /// In en, this message translates to:
  /// **'hey, you.'**
  String get themeScreenPreviewGreeting;

  /// All-caps section label above the mock message bubbles in the theme preview carousel.
  ///
  /// In en, this message translates to:
  /// **'CONVERSATION'**
  String get themeScreenPreviewSectionLabel;

  /// Mock room name shown in the sample room list inside the theme preview carousel.
  ///
  /// In en, this message translates to:
  /// **'design club'**
  String get themeScreenPreviewRoomOneName;

  /// Mock room subtitle (last-message preview) shown under the first sample room in the theme preview carousel.
  ///
  /// In en, this message translates to:
  /// **'mia: shipped the new tile.'**
  String get themeScreenPreviewRoomOneSub;

  /// Mock ephemeral room name shown in the sample room list inside the theme preview carousel (☾ kept as decorative glyph).
  ///
  /// In en, this message translates to:
  /// **'chamber · ☾'**
  String get themeScreenPreviewRoomTwoName;

  /// Mock room subtitle showing the countdown for an ephemeral sample room in the theme preview carousel.
  ///
  /// In en, this message translates to:
  /// **'sealed in 4h.'**
  String get themeScreenPreviewRoomTwoSub;

  /// First mock chat bubble (received) shown in the theme preview carousel.
  ///
  /// In en, this message translates to:
  /// **'how does this feel?'**
  String get themeScreenPreviewBubbleQuestion;

  /// Second mock chat bubble (sent) shown in the theme preview carousel, replying to the first.
  ///
  /// In en, this message translates to:
  /// **'like the right one.'**
  String get themeScreenPreviewBubbleAnswer;

  /// Call-kind label prefixed to pre-active call statuses (ringing/incoming/connecting) on the call screen, distinguishing video calls from voice calls.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get callScreenVideoCallLabel;

  /// Call-kind label prefixed to pre-active call statuses (ringing/incoming/connecting) on the call screen, distinguishing voice calls from video calls.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get callScreenVoiceCallLabel;

  /// Status line shown while an outgoing call is ringing. {kind} is the localized 'Video call'/'Voice call' label.
  ///
  /// In en, this message translates to:
  /// **'{kind} · ringing…'**
  String callScreenStatusRinging(Object kind);

  /// Status line shown while an incoming call is ringing. {kind} is the localized 'Video call'/'Voice call' label.
  ///
  /// In en, this message translates to:
  /// **'{kind} · incoming'**
  String callScreenStatusIncoming(Object kind);

  /// Status line shown while a call is connecting. {kind} is the localized 'Video call'/'Voice call' label.
  ///
  /// In en, this message translates to:
  /// **'{kind} · connecting…'**
  String callScreenStatusConnecting(Object kind);

  /// Status word used only as a fallback path (the active call state normally shows a live elapsed-time timer instead of this text).
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get callScreenStatusConnected;

  /// Status line shown briefly when a call ends, used only if no more specific error message is available.
  ///
  /// In en, this message translates to:
  /// **'call ended'**
  String get callScreenStatusEnded;

  /// Status line shown briefly when a call fails, used only if no more specific error message is available.
  ///
  /// In en, this message translates to:
  /// **'call failed'**
  String get callScreenStatusFailed;

  /// Status text (both as the status line and as a floating overlay chip) shown while the call is being handed off/renegotiated to another device.
  ///
  /// In en, this message translates to:
  /// **'switching device…'**
  String get callScreenStatusSwitching;

  /// Status line shown briefly right before the call screen closes because the call moved to another of the user's devices.
  ///
  /// In en, this message translates to:
  /// **'moved'**
  String get callScreenStatusMoved;

  /// Floating overlay chip text shown while the call connection is being re-established (ICE restart recovery).
  ///
  /// In en, this message translates to:
  /// **'reconnecting…'**
  String get callScreenStatusReconnecting;

  /// Floating overlay chip text shown when the live call-quality monitor reports a poor connection.
  ///
  /// In en, this message translates to:
  /// **'poor connection'**
  String get callScreenPoorConnectionLabel;

  /// Floating overlay chip text shown when the live call-quality monitor reports a weak (but not fully poor) connection.
  ///
  /// In en, this message translates to:
  /// **'weak connection'**
  String get callScreenWeakConnectionLabel;

  /// Small label under the mic control button in the call screen's bottom control bar, shown when the call is currently muted (tapping unmutes).
  ///
  /// In en, this message translates to:
  /// **'unmute'**
  String get callScreenControlUnmute;

  /// Small label under the mic control button in the call screen's bottom control bar, shown when the call is currently unmuted (tapping mutes).
  ///
  /// In en, this message translates to:
  /// **'mute'**
  String get callScreenControlMute;

  /// Small label under the camera control button, shown when the local camera is off (tapping turns it on).
  ///
  /// In en, this message translates to:
  /// **'cam on'**
  String get callScreenControlCamOn;

  /// Small label under the camera control button, shown when the local camera is on (tapping turns it off).
  ///
  /// In en, this message translates to:
  /// **'cam off'**
  String get callScreenControlCamOff;

  /// Small label under the camera-switch (front/back) control button in the call screen's bottom control bar.
  ///
  /// In en, this message translates to:
  /// **'flip'**
  String get callScreenControlFlip;

  /// Small label under the speaker/earpiece toggle control button in the call screen's bottom control bar.
  ///
  /// In en, this message translates to:
  /// **'speaker'**
  String get callScreenControlSpeaker;

  /// Small label under the red hang-up (end call) button in the call screen's bottom control bar.
  ///
  /// In en, this message translates to:
  /// **'end'**
  String get callScreenControlEnd;

  /// All-caps mono badge shown above the domain in the bare/failed link-preview card (link_preview_card.dart), when a URL preview has no title/description to show.
  ///
  /// In en, this message translates to:
  /// **'LINK'**
  String get linkPreviewCardLinkLabel;

  /// Snackbar shown when the other person accepts a friend request; {name} is their display name
  ///
  /// In en, this message translates to:
  /// **'{name} accepted your request'**
  String friendRequestDraftScreenAcceptedSnackbar(Object name);

  /// Snackbar shown to the receiver when the sender withdrew/cancelled their friend request while this screen was open
  ///
  /// In en, this message translates to:
  /// **'that request was withdrawn'**
  String get friendRequestDraftScreenWithdrawnSnackbar;

  /// Snackbar shown to the sender when the friend request was declined
  ///
  /// In en, this message translates to:
  /// **'request declined'**
  String get friendRequestDraftScreenDeclinedSnackbar;

  /// Error snackbar when trying to message someone you've blocked, in the friend request draft composer
  ///
  /// In en, this message translates to:
  /// **'you blocked this user — unblock first.'**
  String get friendRequestDraftScreenErrorBlocked;

  /// Error snackbar when the target user currently has friend requests disabled
  ///
  /// In en, this message translates to:
  /// **'they\'re not accepting friend requests right now.'**
  String get friendRequestDraftScreenErrorNotAccepting;

  /// Generic fallback error snackbar when sending a draft message/request fails
  ///
  /// In en, this message translates to:
  /// **'couldn\'t send. try again.'**
  String get friendRequestDraftScreenErrorSendFailed;

  /// All-caps header label shown above an incoming friend request draft thread
  ///
  /// In en, this message translates to:
  /// **'INCOMING REQUEST'**
  String get friendRequestDraftScreenIncomingRequestLabel;

  /// All-caps header label shown above a new outgoing friend request draft thread
  ///
  /// In en, this message translates to:
  /// **'NEW REQUEST'**
  String get friendRequestDraftScreenNewRequestLabel;

  /// Intro card text shown to the receiver of a friend request; {name} is the sender's display name
  ///
  /// In en, this message translates to:
  /// **'{name} wants to start a conversation.'**
  String friendRequestDraftScreenIntroIncoming(Object name);

  /// Intro card text shown to the sender composing a new friend request
  ///
  /// In en, this message translates to:
  /// **'send a few lines. they can approve or decline.'**
  String get friendRequestDraftScreenIntroOutgoing;

  /// Secondary intro card text explaining the draft thread is ephemeral until the request is approved
  ///
  /// In en, this message translates to:
  /// **'nothing here lives anywhere permanent until both sides agree.'**
  String get friendRequestDraftScreenIntroFooter;

  /// All-caps section label above the room-type picker chips when composing a new friend request
  ///
  /// In en, this message translates to:
  /// **'ROOM TYPE'**
  String get friendRequestDraftScreenRoomTypeLabel;

  /// All-caps chip label for the self-destructing/secret room type option
  ///
  /// In en, this message translates to:
  /// **'EPHEMERAL'**
  String get friendRequestDraftScreenRoomTypeEphemeral;

  /// All-caps chip label for the regular (non-ephemeral) room type option
  ///
  /// In en, this message translates to:
  /// **'STANDARD'**
  String get friendRequestDraftScreenRoomTypeStandard;

  /// All-caps label above the message-lifetime chips shown when ephemeral room type is selected
  ///
  /// In en, this message translates to:
  /// **'LIFETIME'**
  String get friendRequestDraftScreenLifetimeLabel;

  /// Compact duration display for a lifetime under a minute, e.g. '30s' — shown on lifetime chips/labels
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String friendRequestDraftScreenDurationSeconds(Object seconds);

  /// Compact duration display for a lifetime under an hour, e.g. '5m' — shown on lifetime chips/labels
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String friendRequestDraftScreenDurationMinutes(Object minutes);

  /// Compact duration display for a lifetime of an hour or more, e.g. '1h' — shown on lifetime chips/labels
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String friendRequestDraftScreenDurationHours(Object hours);

  /// Composer hint text when composing a fresh ephemeral/secret friend request with an optional first message
  ///
  /// In en, this message translates to:
  /// **'whisper a first line · optional'**
  String get friendRequestDraftScreenHintWhisperOptional;

  /// Composer hint text when composing a fresh standard friend request with an optional first message
  ///
  /// In en, this message translates to:
  /// **'add a first message · optional'**
  String get friendRequestDraftScreenHintFirstMessageOptional;

  /// Composer hint text for an ephemeral/secret draft thread once the request already exists
  ///
  /// In en, this message translates to:
  /// **'whisper · auto-fades'**
  String get friendRequestDraftScreenHintWhisperFades;

  /// Composer hint text for a standard draft thread once the request already exists
  ///
  /// In en, this message translates to:
  /// **'something to start with…'**
  String get friendRequestDraftScreenHintStartWith;

  /// All-caps primary button label to approve an incoming friend request and open the resulting room
  ///
  /// In en, this message translates to:
  /// **'APPROVE & OPEN ROOM'**
  String get friendRequestDraftScreenApproveButton;

  /// All-caps secondary button label to decline an incoming friend request
  ///
  /// In en, this message translates to:
  /// **'DECLINE'**
  String get friendRequestDraftScreenDeclineButton;

  /// All-caps text button to cancel an outgoing friend request that's still pending
  ///
  /// In en, this message translates to:
  /// **'CANCEL REQUEST'**
  String get friendRequestDraftScreenCancelRequestButton;

  /// All-caps primary CTA label shown instead of Send Request when the current user is a supervised child account
  ///
  /// In en, this message translates to:
  /// **'ASK A GROWN-UP'**
  String get friendRequestDraftScreenAskGrownUpButton;

  /// All-caps primary CTA button label to send a fresh friend request
  ///
  /// In en, this message translates to:
  /// **'SEND REQUEST'**
  String get friendRequestDraftScreenSendRequestButton;

  /// Discover screen's large page heading, lowercase sentence-fragment style.
  ///
  /// In en, this message translates to:
  /// **'discover.'**
  String get discoverScreenTitle;

  /// One word in the small mono caption row under the page title, joined with ' · ' (e.g. 'people · rooms · requests').
  ///
  /// In en, this message translates to:
  /// **'people'**
  String get discoverScreenCaptionPeople;

  /// One word in the small mono caption row under the page title, joined with ' · '.
  ///
  /// In en, this message translates to:
  /// **'rooms'**
  String get discoverScreenCaptionRooms;

  /// One word in the small mono caption row under the page title, joined with ' · '; always present.
  ///
  /// In en, this message translates to:
  /// **'requests'**
  String get discoverScreenCaptionRequests;

  /// All-caps section band label marking the start of the people world.
  ///
  /// In en, this message translates to:
  /// **'PEOPLE'**
  String get discoverScreenPeopleBandLabel;

  /// All-caps section band label marking the start of the rooms world.
  ///
  /// In en, this message translates to:
  /// **'ROOMS'**
  String get discoverScreenRoomsBandLabel;

  /// Title of the door row/button that opens people search.
  ///
  /// In en, this message translates to:
  /// **'find people'**
  String get discoverScreenFindPeopleTitle;

  /// Subtitle under 'find people' shown to a child account, explaining they must type a full exact username.
  ///
  /// In en, this message translates to:
  /// **'type a whole username'**
  String get discoverScreenFindPeopleSubtitleChild;

  /// Subtitle under 'find people' shown to a non-child account, explaining search options.
  ///
  /// In en, this message translates to:
  /// **'search by @username or name'**
  String get discoverScreenFindPeopleSubtitleAdult;

  /// All-caps section header label for the friend requests section.
  ///
  /// In en, this message translates to:
  /// **'REQUESTS'**
  String get discoverScreenRequestsSectionLabel;

  /// Empty-state line shown when there are no incoming friend requests.
  ///
  /// In en, this message translates to:
  /// **'inbox quiet'**
  String get discoverScreenInboxQuiet;

  /// Empty-state line shown when there are no outgoing friend requests.
  ///
  /// In en, this message translates to:
  /// **'nothing pending'**
  String get discoverScreenNothingPending;

  /// All-caps section header label above the friends list.
  ///
  /// In en, this message translates to:
  /// **'YOUR PEOPLE'**
  String get discoverScreenYourPeopleLabel;

  /// Empty-state line for the friends list when people search is available, pointing up at the search door.
  ///
  /// In en, this message translates to:
  /// **'no one yet — find people above'**
  String get discoverScreenNoFriendsYetWithHint;

  /// Empty-state line for the friends list when people search is not available (no hint to search).
  ///
  /// In en, this message translates to:
  /// **'no one yet'**
  String get discoverScreenNoFriendsYet;

  /// Title of the door row/button that opens public room search.
  ///
  /// In en, this message translates to:
  /// **'search rooms'**
  String get discoverScreenSearchRoomsTitle;

  /// Subtitle under 'search rooms' explaining what the search does.
  ///
  /// In en, this message translates to:
  /// **'find a public room by name'**
  String get discoverScreenSearchRoomsSubtitle;

  /// All-caps section header label above the public rooms preview list.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC ROOMS'**
  String get discoverScreenPublicRoomsLabel;

  /// Empty-state line shown while the public rooms list is still loading for the first time.
  ///
  /// In en, this message translates to:
  /// **'looking…'**
  String get discoverScreenLoadingRooms;

  /// Empty-state line shown when the public rooms list finished loading and is empty.
  ///
  /// In en, this message translates to:
  /// **'nothing open right now'**
  String get discoverScreenNoRoomsOpen;

  /// Lowercase label for the incoming-requests segment control tab, also spoken as part of its accessibility label ('incoming, {count}').
  ///
  /// In en, this message translates to:
  /// **'incoming'**
  String get discoverScreenIncomingLabel;

  /// Lowercase label for the outgoing-requests segment control tab, also spoken as part of its accessibility label ('outgoing, {count}').
  ///
  /// In en, this message translates to:
  /// **'outgoing'**
  String get discoverScreenOutgoingLabel;

  /// Pre-uppercased display text for the incoming segment tab (e.g. 'INCOMING · 3'). Kept as a separate already-cased value rather than derived via .toUpperCase() at runtime, since Dart's default case mapping is not locale-aware and would mis-case Turkish dotted-i words.
  ///
  /// In en, this message translates to:
  /// **'INCOMING'**
  String get discoverScreenIncomingLabelCaps;

  /// Pre-uppercased display text for the outgoing segment tab (e.g. 'OUTGOING · 2'). Kept as a separate already-cased value for the same Turkish dotted-İ reason as discoverScreenIncomingLabelCaps.
  ///
  /// In en, this message translates to:
  /// **'OUTGOING'**
  String get discoverScreenOutgoingLabelCaps;

  /// Label on the small chip button that jumps the page down to the PEOPLE world.
  ///
  /// In en, this message translates to:
  /// **'people'**
  String get discoverScreenJumpPeopleLabel;

  /// Label on the small chip button that jumps the page down to the ROOMS world.
  ///
  /// In en, this message translates to:
  /// **'rooms'**
  String get discoverScreenJumpRoomsLabel;

  /// Screen-reader accessibility label for a world-jump chip button, where {label} is the already-localized world name ('people'/'rooms').
  ///
  /// In en, this message translates to:
  /// **'Jump to {label}'**
  String discoverScreenJumpToSemanticLabel(Object label);

  /// Default top-bar title on the image crop screen (avatar/photo cropper), used when no custom title is passed in.
  ///
  /// In en, this message translates to:
  /// **'adjust'**
  String get imageCropScreenDefaultTitle;

  /// Default label on the confirm (all-caps pill) button of the image crop screen, used when no custom confirmLabel is passed in.
  ///
  /// In en, this message translates to:
  /// **'USE PHOTO'**
  String get imageCropScreenDefaultConfirmLabel;

  /// All-caps confirm-button label shown on the image crop screen while the crop is being processed/uploaded.
  ///
  /// In en, this message translates to:
  /// **'SAVING…'**
  String get imageCropScreenSavingButton;

  /// All-caps cancel button label on the image crop screen, closes the screen without saving.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get imageCropScreenCancelButton;

  /// Error copy shown in place of the photo on the crop screen when running on web and the picked image is an unsupported HEIC file.
  ///
  /// In en, this message translates to:
  /// **'this browser can\'t open HEIC photos'**
  String get imageCropScreenHeicUnsupported;

  /// Generic error copy shown in place of the photo on the crop screen when the image failed to decode for any other reason.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t open that image'**
  String get imageCropScreenLoadFailed;

  /// Small caption hint under the crop window when cropping to a circle (avatar), explaining the pan/zoom gesture.
  ///
  /// In en, this message translates to:
  /// **'drag to move, pinch to zoom'**
  String get imageCropScreenHintCircle;

  /// Small caption hint under the crop window when cropping to a rectangle, explaining the pan/zoom gesture.
  ///
  /// In en, this message translates to:
  /// **'drag and pinch to frame'**
  String get imageCropScreenHintRect;

  /// Sign-in screen headline, muted (first-line) fragment. Pairs with loginScreenSignInHeroInk to read as one two-line phrase (e.g. English: welcome / back.).
  ///
  /// In en, this message translates to:
  /// **'welcome\n'**
  String get loginScreenSignInHeroMuted;

  /// Sign-in screen headline, emphasized (second-line, ink-colored) fragment, paired with loginScreenSignInHeroMuted.
  ///
  /// In en, this message translates to:
  /// **'back.'**
  String get loginScreenSignInHeroInk;

  /// First half of the two-tone sign-in hero, in the muted colour, shown ONLY on a device that has never completed a sign-in. Pairs with loginScreenSignInFirstHeroInk, rendered immediately after it in the ink colour. Keep the trailing newline — it puts the two halves on separate lines. Lowercase is the app's house style. A returning device gets loginScreenSignInHeroMuted/Ink ("welcome back.") instead, so this variant must NOT imply the person has been here before. Prefer a fixed greeting in your language that splits across the two halves over a literal rendering of "hello there".
  ///
  /// In en, this message translates to:
  /// **'hello\n'**
  String get loginScreenSignInFirstHeroMuted;

  /// Second half of the first-run sign-in hero, in the ink colour, shown ONLY on a device that has never completed a sign-in. Follows loginScreenSignInFirstHeroMuted on its own line and ends the sentence, so it carries the full stop.
  ///
  /// In en, this message translates to:
  /// **'there.'**
  String get loginScreenSignInFirstHeroInk;

  /// All-caps submit button label shown while the login screen is in sign-in mode.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN'**
  String get loginScreenSignInCta;

  /// Sign-up screen headline, muted (first-line) fragment, paired with loginScreenSignUpHeroInk.
  ///
  /// In en, this message translates to:
  /// **'new\n'**
  String get loginScreenSignUpHeroMuted;

  /// Sign-up screen headline, emphasized (second-line) fragment, paired with loginScreenSignUpHeroMuted (English idiom 'new face'; Turkish rendered as 'yeni üye' = new member).
  ///
  /// In en, this message translates to:
  /// **'face.'**
  String get loginScreenSignUpHeroInk;

  /// All-caps submit button label shown while the login screen is in sign-up mode.
  ///
  /// In en, this message translates to:
  /// **'OPEN ACCOUNT'**
  String get loginScreenSignUpCta;

  /// Password-reset screen headline, muted (first-line) fragment, paired with loginScreenResetHeroInk.
  ///
  /// In en, this message translates to:
  /// **'reset\n'**
  String get loginScreenResetHeroMuted;

  /// Password-reset screen headline, emphasized (second-line) fragment, paired with loginScreenResetHeroMuted.
  ///
  /// In en, this message translates to:
  /// **'password.'**
  String get loginScreenResetHeroInk;

  /// All-caps submit button label shown while the login screen is in password-reset mode.
  ///
  /// In en, this message translates to:
  /// **'RESET PASSWORD'**
  String get loginScreenResetCta;

  /// Inline error banner shown on sign-up when the password and confirm-password fields differ.
  ///
  /// In en, this message translates to:
  /// **'Passwords don’t match.'**
  String get loginScreenErrorPasswordsDontMatch;

  /// Inline error banner shown on sign-up if the user tries to open the recovery-phrase gate before entering a password.
  ///
  /// In en, this message translates to:
  /// **'Choose a password first.'**
  String get loginScreenErrorChoosePasswordFirst;

  /// Placeholder text inside the username text field (all modes).
  ///
  /// In en, this message translates to:
  /// **'username'**
  String get loginScreenUsernameHint;

  /// Placeholder text inside the password field on sign-in and sign-up.
  ///
  /// In en, this message translates to:
  /// **'password'**
  String get loginScreenPasswordHint;

  /// Placeholder text inside the confirm-password field on sign-up.
  ///
  /// In en, this message translates to:
  /// **'confirm password'**
  String get loginScreenConfirmPasswordHint;

  /// Placeholder text inside the optional display-name field on sign-up.
  ///
  /// In en, this message translates to:
  /// **'name (optional)'**
  String get loginScreenNameOptionalHint;

  /// Placeholder text inside the multi-line recovery-phrase field on the password-reset screen.
  ///
  /// In en, this message translates to:
  /// **'your 12-word recovery phrase'**
  String get loginScreenRecoveryPhraseHint;

  /// Placeholder text inside the new-password field on the password-reset screen.
  ///
  /// In en, this message translates to:
  /// **'new password'**
  String get loginScreenNewPasswordHint;

  /// Footer link on the password-reset screen that returns to sign-in mode.
  ///
  /// In en, this message translates to:
  /// **'← back to sign in'**
  String get loginScreenBackToSignIn;

  /// Footer link on the sign-in screen that switches to password-reset mode.
  ///
  /// In en, this message translates to:
  /// **'forgot password?'**
  String get loginScreenForgotPassword;

  /// Footer link on the sign-in screen that switches to the child-device pairing flow.
  ///
  /// In en, this message translates to:
  /// **'set up a child account'**
  String get loginScreenSettingUpKidsPhone;

  /// First (non-tappable) fragment of the sign-up legal disclosure sentence, immediately followed by the Terms link (loginScreenLegalTermsLink).
  ///
  /// In en, this message translates to:
  /// **'By opening an account you agree to the '**
  String get loginScreenLegalPrefix;

  /// Tappable 'Terms of Service' fragment inside the sign-up legal disclosure sentence; opens the Terms of Service page.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get loginScreenLegalTermsLink;

  /// Middle (non-tappable) connector fragment of the sign-up legal disclosure sentence, between the Terms and Privacy Policy links.
  ///
  /// In en, this message translates to:
  /// **' and the '**
  String get loginScreenLegalMiddle;

  /// Tappable 'Privacy Policy' fragment inside the sign-up legal disclosure sentence; opens the Privacy Policy page.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get loginScreenLegalPrivacyLink;

  /// Final (non-tappable) fragment of the sign-up legal disclosure sentence, after the Privacy Policy link. Turkish moves the sentence's verb here (SOV word order) so the full concatenation reads naturally: 'Hesap açarak Kullanım Şartları'nı ve Gizlilik Politikası'nı kabul etmiş olursun.'
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get loginScreenLegalSuffix;

  /// Non-tappable lead-in text of the mode-toggle footer link, shown in sign-up mode (paired with loginScreenSignInLink) to switch back to sign-in.
  ///
  /// In en, this message translates to:
  /// **'already here? '**
  String get loginScreenAlreadyHerePrompt;

  /// Tappable action word of the mode-toggle footer link in sign-up mode, following loginScreenAlreadyHerePrompt.
  ///
  /// In en, this message translates to:
  /// **'sign in'**
  String get loginScreenSignInLink;

  /// Non-tappable lead-in text of the mode-toggle footer link, shown in sign-in mode (paired with loginScreenOpenOneLink) to switch to sign-up.
  ///
  /// In en, this message translates to:
  /// **'no account? '**
  String get loginScreenNoAccountPrompt;

  /// Tappable action word of the mode-toggle footer link in sign-in mode, following loginScreenNoAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'open one'**
  String get loginScreenOpenOneLink;

  /// Live word-count readout under the recovery-phrase field on the password-reset screen (e.g. '7/12 words'). Simple interpolation, always shown regardless of count value.
  ///
  /// In en, this message translates to:
  /// **'{count}/12 words'**
  String loginScreenWordCounter(Object count);

  /// Desktop two-pane chat layout: hint text shown in the right-hand detail pane when no room is selected yet (lib/screens/home_shell.dart, _EmptyRoomHint).
  ///
  /// In en, this message translates to:
  /// **'pick a room to start chatting'**
  String get homeShellEmptyRoomHint;

  /// Desktop two-pane settings layout: hint text shown in the right-hand detail pane when no settings sub-screen is selected yet (lib/screens/home_shell.dart, _SettingsEmptyHint).
  ///
  /// In en, this message translates to:
  /// **'pick a setting'**
  String get homeShellEmptySettingHint;

  /// Search screen: TextField hint text when searching for people (SearchMode.people).
  ///
  /// In en, this message translates to:
  /// **'search people…'**
  String get searchScreenHintPeople;

  /// Search screen: TextField hint text when searching for public rooms (SearchMode.rooms).
  ///
  /// In en, this message translates to:
  /// **'search rooms…'**
  String get searchScreenHintRooms;

  /// People-search empty state (query not yet typed) shown to a child account, explaining that only an exact full username finds someone new.
  ///
  /// In en, this message translates to:
  /// **'type a whole username to find someone new'**
  String get searchScreenPeoplePromptChild;

  /// People-search empty state (query not yet typed) shown to a regular (non-child) account.
  ///
  /// In en, this message translates to:
  /// **'search by username or name'**
  String get searchScreenPeoplePromptDefault;

  /// People-search no-results state for a child account; explains new people need the exact full username. Contains a literal newline (\n) for a two-line message — preserve it.
  ///
  /// In en, this message translates to:
  /// **'no one matches — new people need their\nwhole username, spelled exactly'**
  String get searchScreenNoMatchChild;

  /// People-search no-results state for a regular (non-child) account.
  ///
  /// In en, this message translates to:
  /// **'no one matches'**
  String get searchScreenNoMatchDefault;

  /// Rooms-search empty state shown when there are no public rooms at all (empty query, no results).
  ///
  /// In en, this message translates to:
  /// **'no public rooms yet'**
  String get searchScreenNoRoomsYet;

  /// Rooms-search empty state shown when the typed query matches no public rooms.
  ///
  /// In en, this message translates to:
  /// **'no public rooms match'**
  String get searchScreenNoRoomsMatch;

  /// All-caps pill button label on a person row: for a child account, sends a friend-add request through their grown-up for approval rather than directly.
  ///
  /// In en, this message translates to:
  /// **'ASK TO ADD'**
  String get searchScreenActionAskToAdd;

  /// All-caps pill button label on a person row: sends a direct friend request (non-child account, no existing relationship).
  ///
  /// In en, this message translates to:
  /// **'SEND REQUEST'**
  String get searchScreenActionSendRequest;

  /// All-caps pill button label on a person row: cancels an outgoing (already-sent) friend request.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get searchScreenActionCancel;

  /// All-caps pill button label on a person row: approves an incoming pending friend request.
  ///
  /// In en, this message translates to:
  /// **'APPROVE'**
  String get searchScreenActionApprove;

  /// All-caps pill button label on a person row: opens the existing direct-message room with a friend.
  ///
  /// In en, this message translates to:
  /// **'OPEN DM'**
  String get searchScreenActionOpenDm;

  /// Small pill label on a public room row shown when a child has already asked their grown-up to join that room this session (WaitingPill label).
  ///
  /// In en, this message translates to:
  /// **'asked'**
  String get searchScreenAskedLabel;

  /// Lowercase display heading at the top of the Profile Visibility screen
  ///
  /// In en, this message translates to:
  /// **'visibility preferences.'**
  String get profileVisibilityScreenTitle;

  /// Caption under the screen title explaining what the screen does
  ///
  /// In en, this message translates to:
  /// **'control what others see — and how they can reach you.'**
  String get profileVisibilityScreenSubtitle;

  /// All-caps section header grouping avatar/status/last-seen visibility rows
  ///
  /// In en, this message translates to:
  /// **'PROFILE'**
  String get profileVisibilityScreenSectionProfile;

  /// All-caps row label for the avatar visibility control
  ///
  /// In en, this message translates to:
  /// **'AVATAR'**
  String get profileVisibilityScreenAvatarLabel;

  /// Small description under the AVATAR row label
  ///
  /// In en, this message translates to:
  /// **'your profile picture'**
  String get profileVisibilityScreenAvatarDesc;

  /// All-caps row label for the online/away status visibility control
  ///
  /// In en, this message translates to:
  /// **'ONLINE / AWAY'**
  String get profileVisibilityScreenOnlineAwayLabel;

  /// Small description under the ONLINE / AWAY row label
  ///
  /// In en, this message translates to:
  /// **'whether you appear active right now'**
  String get profileVisibilityScreenOnlineAwayDesc;

  /// All-caps row label for the last-seen visibility control
  ///
  /// In en, this message translates to:
  /// **'LAST SEEN'**
  String get profileVisibilityScreenLastSeenLabel;

  /// Small description under the LAST SEEN row label
  ///
  /// In en, this message translates to:
  /// **'the time you were last around'**
  String get profileVisibilityScreenLastSeenDesc;

  /// All-caps section header grouping read-receipt rows
  ///
  /// In en, this message translates to:
  /// **'MESSAGES'**
  String get profileVisibilityScreenSectionMessages;

  /// All-caps row label for the outgoing read-receipt visibility control
  ///
  /// In en, this message translates to:
  /// **'SEND READ RECEIPTS'**
  String get profileVisibilityScreenSendReadReceiptsLabel;

  /// Small description under the SEND READ RECEIPTS row label
  ///
  /// In en, this message translates to:
  /// **'when on, others can see that you\'ve read their messages'**
  String get profileVisibilityScreenSendReadReceiptsDesc;

  /// All-caps row label for the local toggle that shows the SEEN mark on your own messages
  ///
  /// In en, this message translates to:
  /// **'SHOW READ RECEIPTS'**
  String get profileVisibilityScreenShowReadReceiptsLabel;

  /// Small description under the SHOW READ RECEIPTS row label
  ///
  /// In en, this message translates to:
  /// **'see the \"SEEN\" mark on your own messages once they\'re read'**
  String get profileVisibilityScreenShowReadReceiptsDesc;

  /// Small info hint below the SHOW READ RECEIPTS toggle, explaining the reciprocity requirement
  ///
  /// In en, this message translates to:
  /// **'only readers who turned on SEND READ RECEIPTS will contribute. others stay invisible.'**
  String get profileVisibilityScreenShowReadReceiptsHint;

  /// All-caps section header grouping the friend-requests row
  ///
  /// In en, this message translates to:
  /// **'PEOPLE'**
  String get profileVisibilityScreenSectionPeople;

  /// All-caps row label for who can send friend requests
  ///
  /// In en, this message translates to:
  /// **'FRIEND REQUESTS'**
  String get profileVisibilityScreenFriendRequestsLabel;

  /// Small description under the FRIEND REQUESTS row label
  ///
  /// In en, this message translates to:
  /// **'who can send you friend requests'**
  String get profileVisibilityScreenFriendRequestsDesc;

  /// All-caps title of the notice box shown to a child/read-only account explaining these settings are guardian-controlled
  ///
  /// In en, this message translates to:
  /// **'YOUR GROWN-UPS SET THESE'**
  String get profileVisibilityScreenSupervisedTitle;

  /// Body copy of the supervised/read-only notice box explaining guardian control
  ///
  /// In en, this message translates to:
  /// **'You can see what everyone else sees here, but only a grown-up can change it. They can always see your picture, when you\'re online and when you were last around.'**
  String get profileVisibilityScreenSupervisedBody;

  /// Segmented-control option label: field visible to everyone
  ///
  /// In en, this message translates to:
  /// **'PUBLIC'**
  String get profileVisibilityScreenOptionPublic;

  /// Segmented-control option label: field visible to friends only
  ///
  /// In en, this message translates to:
  /// **'FRIENDS'**
  String get profileVisibilityScreenOptionFriends;

  /// Segmented-control option label: field visible to nobody / no one can do this (reused for both tri-state and binary controls)
  ///
  /// In en, this message translates to:
  /// **'NOBODY'**
  String get profileVisibilityScreenOptionNobody;

  /// Segmented-control option label: boolean toggle is on
  ///
  /// In en, this message translates to:
  /// **'ON'**
  String get profileVisibilityScreenOptionOn;

  /// Segmented-control option label: boolean toggle is off
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get profileVisibilityScreenOptionOff;

  /// Segmented-control option label: anyone can send a friend request
  ///
  /// In en, this message translates to:
  /// **'ANYONE'**
  String get profileVisibilityScreenOptionAnyone;

  /// Lowercase display heading at the top of the App Logo screen.
  ///
  /// In en, this message translates to:
  /// **'app logo.'**
  String get logoScreenTitle;

  /// Caption line under the App Logo screen title, next to a small accent tick mark.
  ///
  /// In en, this message translates to:
  /// **'the mark in your header, your call.'**
  String get logoScreenSubtitle;

  /// All-caps mode card label: logo automatically follows the active theme.
  ///
  /// In en, this message translates to:
  /// **'AUTO'**
  String get logoScreenAutoLabel;

  /// Sub-text under the AUTO logo mode card explaining that behavior.
  ///
  /// In en, this message translates to:
  /// **'follows your theme. mark changes with the palette.'**
  String get logoScreenAutoDescription;

  /// All-caps mode card label: user manually picks a specific logo mark.
  ///
  /// In en, this message translates to:
  /// **'MANUAL'**
  String get logoScreenManualLabel;

  /// Sub-text under the MANUAL logo mode card explaining that behavior.
  ///
  /// In en, this message translates to:
  /// **'pick any mark, keep your theme.'**
  String get logoScreenManualDescription;

  /// All-caps mode card label: always use the canonical MonkeyHub mark.
  ///
  /// In en, this message translates to:
  /// **'ALWAYS DEFAULT'**
  String get logoScreenAlwaysDefaultLabel;

  /// Sub-text under the ALWAYS DEFAULT logo mode card explaining that behavior. MonkeyHub is the brand name and stays untranslated.
  ///
  /// In en, this message translates to:
  /// **'the MonkeyHub mark, regardless of theme.'**
  String get logoScreenAlwaysDefaultDescription;

  /// Small all-caps badge shown next to a dot indicator on the currently active logo mode card.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get logoScreenActiveBadge;

  /// All-caps section header above the grid of monkey mascot logo tiles in the manual logo picker.
  ///
  /// In en, this message translates to:
  /// **'MONKEY COLLECTION'**
  String get logoScreenMonkeyCollectionHeader;

  /// All-caps section header above the grid of theme-based logo tiles in the manual logo picker.
  ///
  /// In en, this message translates to:
  /// **'THEMES'**
  String get logoScreenThemesHeader;

  /// SnackBar message shown after the user taps COPY and the recovery phrase is copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'copied — paste it somewhere safe'**
  String get recoveryPhraseScreenCopiedSnackbar;

  /// Muted (dim) first line of the two-line hero heading on the password-confirmation step, paired with recoveryPhraseScreenConfirmHeroInk on the next line.
  ///
  /// In en, this message translates to:
  /// **'confirm\n'**
  String get recoveryPhraseScreenConfirmHeroMuted;

  /// Ink (emphasized) second line of the hero heading on the password-confirmation step, following recoveryPhraseScreenConfirmHeroMuted.
  ///
  /// In en, this message translates to:
  /// **'it’s you.'**
  String get recoveryPhraseScreenConfirmHeroInk;

  /// Body copy above the password field explaining why the password step exists before showing the recovery phrase.
  ///
  /// In en, this message translates to:
  /// **'Your password, so nobody else can put a recovery phrase on your account.'**
  String get recoveryPhraseScreenPasswordBody;

  /// Hint text inside the password text field on the confirmation step.
  ///
  /// In en, this message translates to:
  /// **'password'**
  String get recoveryPhraseScreenPasswordHint;

  /// All-caps primary button label to move from the password step to the show-recovery-words step.
  ///
  /// In en, this message translates to:
  /// **'CONTINUE'**
  String get recoveryPhraseScreenContinueButton;

  /// Lowercase text-link label letting a dismissible password step be skipped (backs out of the screen).
  ///
  /// In en, this message translates to:
  /// **'not now'**
  String get recoveryPhraseScreenNotNowLink;

  /// Inline validation error shown when the user taps CONTINUE with an empty password field.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get recoveryPhraseScreenEnterPasswordError;

  /// Muted (dim) first line of the two-line hero heading on the show-recovery-words step, paired with recoveryPhraseScreenSaveHeroInk on the next line.
  ///
  /// In en, this message translates to:
  /// **'save\n'**
  String get recoveryPhraseScreenSaveHeroMuted;

  /// Ink (emphasized) second line of the hero heading on the show-recovery-words step, following recoveryPhraseScreenSaveHeroMuted.
  ///
  /// In en, this message translates to:
  /// **'these words.'**
  String get recoveryPhraseScreenSaveHeroInk;

  /// Explanatory body text above the twelve-word recovery phrase grid, warning the words won't be shown again.
  ///
  /// In en, this message translates to:
  /// **'These twelve words are the only way back into your account if you forget your password. We can’t show them to you again, and we can’t recover them for you.'**
  String get recoveryPhraseScreenWordsBody;

  /// All-caps secondary (outlined) button label to copy the full recovery phrase to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'COPY'**
  String get recoveryPhraseScreenCopyButton;

  /// Small caption below the COPY button, warning that clipboard/phone storage isn't durable and paper is safer.
  ///
  /// In en, this message translates to:
  /// **'If you can, write them on paper. Anything on this phone can be lost with the phone.'**
  String get recoveryPhraseScreenPaperHint;

  /// All-caps primary button label the user taps to confirm they saved the recovery words and proceed.
  ///
  /// In en, this message translates to:
  /// **'I SAVED THEM'**
  String get recoveryPhraseScreenSavedButton;

  /// Lowercase back-arrow text link shown only during signup (setup mode) to back out of the recovery-phrase screen without cost.
  ///
  /// In en, this message translates to:
  /// **'← back'**
  String get recoveryPhraseScreenBackLink;

  /// Lowercase text link letting the user decline regenerating/rotating their recovery phrase and keep the existing one.
  ///
  /// In en, this message translates to:
  /// **'not now — keep my current phrase'**
  String get recoveryPhraseScreenKeepPhraseLink;

  /// Accessibility/semantic label for the tappable avatar in the home screen header that opens the signed-in user's own profile.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get homeScreenProfileSemanticLabel;

  /// Casual lowercase greeting heading in the home screen header, e.g. 'hey, murat.' {name} is the signed-in user's own first name, lowercased by the caller.
  ///
  /// In en, this message translates to:
  /// **'hey, {name}.'**
  String homeScreenGreeting(Object name);

  /// Accessibility/semantic label for the '+' button in the home screen header that opens the create-room sheet.
  ///
  /// In en, this message translates to:
  /// **'New room'**
  String get homeScreenNewRoomSemanticLabel;

  /// Lowercase empty-state message shown on the home screen when the signed-in user has zero rooms at all (genuinely empty account, not just filtered down to nothing).
  ///
  /// In en, this message translates to:
  /// **'no rooms yet — create one'**
  String get homeScreenEmptyRoomsMessage;

  /// Header title on the group call screen when the call is a video call.
  ///
  /// In en, this message translates to:
  /// **'Group video call'**
  String get groupCallScreenTitleVideo;

  /// Header title on the group call screen when the call is voice-only.
  ///
  /// In en, this message translates to:
  /// **'Group voice call'**
  String get groupCallScreenTitleVoice;

  /// Pill badge in the group call header showing how many people (including you) are currently in the call.
  ///
  /// In en, this message translates to:
  /// **'{count} in call'**
  String groupCallScreenParticipantCount(Object count);

  /// Lowercase status chip shown at the top of the group call screen when any participant's connection is recovering.
  ///
  /// In en, this message translates to:
  /// **'reconnecting…'**
  String get groupCallScreenReconnecting;

  /// Label under the mic control button in the call tray, shown when the local user is currently muted (tapping unmutes).
  ///
  /// In en, this message translates to:
  /// **'unmute'**
  String get groupCallScreenUnmuteLabel;

  /// Label under the mic control button in the call tray, shown when the local user is currently unmuted (tapping mutes).
  ///
  /// In en, this message translates to:
  /// **'mute'**
  String get groupCallScreenMuteLabel;

  /// Label under the camera control button in the call tray, shown when local video is off (tapping turns it on).
  ///
  /// In en, this message translates to:
  /// **'cam on'**
  String get groupCallScreenCamOnLabel;

  /// Label under the camera control button in the call tray, shown when local video is on (tapping turns it off).
  ///
  /// In en, this message translates to:
  /// **'cam off'**
  String get groupCallScreenCamOffLabel;

  /// Label under the camera-flip control button in the call tray (switches front/back camera).
  ///
  /// In en, this message translates to:
  /// **'flip'**
  String get groupCallScreenFlipLabel;

  /// Label under the speaker toggle control button in the call tray.
  ///
  /// In en, this message translates to:
  /// **'speaker'**
  String get groupCallScreenSpeakerLabel;

  /// Label under the red end-call control button in the call tray.
  ///
  /// In en, this message translates to:
  /// **'leave'**
  String get groupCallScreenLeaveLabel;

  /// Name label shown on the local participant's own video tile in the group call grid.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get groupCallScreenYouLabel;

  /// Screen-reader label for the room-filter header button (RoomFilterButton) when a filter is currently active. {summary} is a generated string like 'dms + secret' built from active facet labels — not a hardcoded literal.
  ///
  /// In en, this message translates to:
  /// **'Filtering by {summary}. Change filter'**
  String roomFilterDrawerButtonActiveSemanticLabel(Object summary);

  /// Screen-reader label for the room-filter header button (RoomFilterButton) when no filter is active.
  ///
  /// In en, this message translates to:
  /// **'Filter chats'**
  String get roomFilterDrawerButtonSemanticLabel;

  /// Pill text in ActiveFilterCue showing the active filter summary and how many rooms currently match it, e.g. 'dms + secret · 3'. {summary} is generated from facet labels, {count} is the match count.
  ///
  /// In en, this message translates to:
  /// **'{summary} · {count}'**
  String roomFilterDrawerActiveSummary(Object count, Object summary);

  /// Screen-reader label for the small 'clear' control next to the active-filter summary pill (ActiveFilterCue).
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get roomFilterDrawerClearSemanticLabel;

  /// Lowercase terse text label of the tappable 'clear' control next to the active-filter summary pill (ActiveFilterCue).
  ///
  /// In en, this message translates to:
  /// **'clear'**
  String get roomFilterDrawerClearLabel;

  /// All-caps section header in the filter panel above the 'dms/groups' facet group (FacetDimension.type).
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get roomFilterDrawerDimensionType;

  /// All-caps section header in the filter panel above the 'public/private/secret/locked' facet group (FacetDimension.nature).
  ///
  /// In en, this message translates to:
  /// **'NATURE'**
  String get roomFilterDrawerDimensionNature;

  /// All-caps section header in the filter panel above the 'unread/mentions' facet group (FacetDimension.status).
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get roomFilterDrawerDimensionStatus;

  /// All-caps button label in the filter panel footer that clears all selected facets; disabled (greyed out) when nothing is selected.
  ///
  /// In en, this message translates to:
  /// **'CLEAR'**
  String get roomFilterDrawerPanelClear;

  /// All-caps filled button label in the filter panel footer that collapses the panel back down.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get roomFilterDrawerPanelDone;

  /// Screen-reader label for one facet row in the filter panel (e.g. a 'locked' or 'unread' toggle), stating the facet name and how many chats currently match it. {label} comes from the RoomFacet enum's display label (shared data model, left untranslated here).
  ///
  /// In en, this message translates to:
  /// **'{label}, {count, plural, one{{count} chat} other{{count} chats}}'**
  String roomFilterDrawerFacetSemanticLabel(num count, Object label);

  /// Lowercase sentence-fragment heading shown when an active filter leaves zero rooms (FilteredEmptyState). {summary} is the generated active-filter summary string.
  ///
  /// In en, this message translates to:
  /// **'nothing matches {summary}'**
  String roomFilterDrawerEmptyStateTitle(Object summary);

  /// Screen-reader label for the escape-hatch chip in FilteredEmptyState that clears the filter and shows every room again.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Show all {count} chat} other{Show all {count} chats}}'**
  String roomFilterDrawerShowAllSemanticLabel(num count);

  /// Lowercase visible text of the escape-hatch chip in FilteredEmptyState that clears the filter and shows every room again.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{show all {count} chat} other{show all {count} chats}}'**
  String roomFilterDrawerShowAllLabel(num count);

  /// Large lowercase heading title at the top of the create-room bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'new room'**
  String get createRoomSheetTitle;

  /// All-caps tracked-letter tagline under the heading, shown when the ephemeral/secret room type is selected.
  ///
  /// In en, this message translates to:
  /// **'NOTHING WILL BE KEPT'**
  String get createRoomSheetTaglineSecret;

  /// All-caps tracked-letter tagline under the heading, shown when the standard/regular room type is selected.
  ///
  /// In en, this message translates to:
  /// **'A SPACE THAT STAYS'**
  String get createRoomSheetTaglineRegular;

  /// All-caps field label above the room name text input.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get createRoomSheetNameLabel;

  /// Placeholder hint text inside the room name input field.
  ///
  /// In en, this message translates to:
  /// **'name it something honest…'**
  String get createRoomSheetNameHint;

  /// All-caps field label above the optional room description text input.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION · OPTIONAL'**
  String get createRoomSheetDescriptionLabel;

  /// Placeholder hint text inside the room description input field.
  ///
  /// In en, this message translates to:
  /// **'one line about the room…'**
  String get createRoomSheetDescriptionHint;

  /// All-caps section label above the public/private visibility segmented picker.
  ///
  /// In en, this message translates to:
  /// **'VISIBILITY'**
  String get createRoomSheetVisibilityLabel;

  /// Title text on the 'public' segment of the visibility picker.
  ///
  /// In en, this message translates to:
  /// **'public'**
  String get createRoomSheetVisibilityPublicTitle;

  /// Subtitle text explaining the 'public' visibility option.
  ///
  /// In en, this message translates to:
  /// **'anyone can find it'**
  String get createRoomSheetVisibilityPublicSub;

  /// Title text on the 'private' segment of the visibility picker.
  ///
  /// In en, this message translates to:
  /// **'private'**
  String get createRoomSheetVisibilityPrivateTitle;

  /// Subtitle text explaining the 'private' visibility option.
  ///
  /// In en, this message translates to:
  /// **'invite only'**
  String get createRoomSheetVisibilityPrivateSub;

  /// All-caps section label above the room-type segmented picker (standard vs ephemeral).
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get createRoomSheetTypeLabel;

  /// Title text on the 'standard' segment of the room-type picker.
  ///
  /// In en, this message translates to:
  /// **'standard'**
  String get createRoomSheetTypeStandardTitle;

  /// Subtitle text explaining the 'standard' room type (messages are not auto-deleted).
  ///
  /// In en, this message translates to:
  /// **'messages persist'**
  String get createRoomSheetTypeStandardSub;

  /// Title text on the 'ephemeral' segment of the room-type picker.
  ///
  /// In en, this message translates to:
  /// **'ephemeral'**
  String get createRoomSheetTypeEphemeralTitle;

  /// Subtitle text explaining the 'ephemeral' room type (messages self-destruct).
  ///
  /// In en, this message translates to:
  /// **'auto-deletes'**
  String get createRoomSheetTypeEphemeralSub;

  /// All-caps label above the message-lifetime (TTL) chip picker, shown only for ephemeral rooms.
  ///
  /// In en, this message translates to:
  /// **'MESSAGE LIFE'**
  String get createRoomSheetMessageLifeLabel;

  /// Compact duration label for a message lifetime under a minute, e.g. '30s' / '30sn'.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String createRoomSheetTtlSeconds(Object seconds);

  /// Compact duration label for a message lifetime under an hour, e.g. '5m' / '5dk'.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String createRoomSheetTtlMinutes(Object minutes);

  /// Compact duration label for a message lifetime of an hour or more, e.g. '1h' / '1sa'.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String createRoomSheetTtlHours(Object hours);

  /// All-caps field label above the optional room password input.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD · OPTIONAL'**
  String get createRoomSheetPasswordLabel;

  /// Placeholder hint text inside the room password input field.
  ///
  /// In en, this message translates to:
  /// **'lock with a passphrase…'**
  String get createRoomSheetPasswordHint;

  /// Inline error message shown when the user tries to create a room without entering a name.
  ///
  /// In en, this message translates to:
  /// **'name is required'**
  String get createRoomSheetNameRequiredError;

  /// Screen-reader accessibility label for the submit button that creates and opens the room.
  ///
  /// In en, this message translates to:
  /// **'Open the room'**
  String get createRoomSheetOpenRoomSemanticLabel;

  /// All-caps label on the submit button that creates the room and navigates into it.
  ///
  /// In en, this message translates to:
  /// **'OPEN THE ROOM'**
  String get createRoomSheetOpenRoomButton;

  /// All-caps header title on the Family dashboard screen, next to the back arrow.
  ///
  /// In en, this message translates to:
  /// **'FAMILY'**
  String get familyScreenTitle;

  /// Tappable banner on the Family screen showing how many pending approvals (e.g. friend requests, requests) are waiting for the guardian's decision.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 thing needs your OK} other{{count} things need your OK}}'**
  String familyScreenPendingBanner(num count);

  /// Presence label next to a child's status dot on their card when they are currently online.
  ///
  /// In en, this message translates to:
  /// **'online now'**
  String get familyScreenPresenceOnline;

  /// Presence label shown for a child account that has never been paired to a device (no last-seen timestamp yet).
  ///
  /// In en, this message translates to:
  /// **'not paired yet'**
  String get familyScreenPresenceNotPaired;

  /// Presence label meaning the child's device was seen within the last minute (or is 'away' but seen under 5 minutes ago).
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get familyScreenPresenceJustNow;

  /// Presence label showing how many minutes ago the child's device was last seen, abbreviated (e.g. '5m ago').
  ///
  /// In en, this message translates to:
  /// **'{minutes}m ago'**
  String familyScreenPresenceMinutesAgo(Object minutes);

  /// Presence label showing how many hours ago the child's device was last seen, abbreviated (e.g. '3h ago').
  ///
  /// In en, this message translates to:
  /// **'{hours}h ago'**
  String familyScreenPresenceHoursAgo(Object hours);

  /// Presence label showing how many days ago the child's device was last seen, abbreviated (e.g. '2d ago').
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String familyScreenPresenceDaysAgo(Object days);

  /// All-caps action button under a child's card to generate a pairing code that links their phone.
  ///
  /// In en, this message translates to:
  /// **'PAIR'**
  String get familyScreenPairButton;

  /// All-caps action button under a child's card to unpair/sign out their device.
  ///
  /// In en, this message translates to:
  /// **'RELEASE'**
  String get familyScreenReleaseButton;

  /// All-caps action button under a child's card to open that child's policy/settings screen.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get familyScreenSettingsButton;

  /// All-caps outlined button at the bottom of the Family screen list to add a new child account.
  ///
  /// In en, this message translates to:
  /// **'ADD A CHILD'**
  String get familyScreenAddChildButton;

  /// Lowercase headline shown in the empty state when the guardian has no children set up yet.
  ///
  /// In en, this message translates to:
  /// **'no children yet'**
  String get familyScreenEmptyStateTitle;

  /// Body copy under the empty-state headline on the Family screen, explaining the next step to onboard a child.
  ///
  /// In en, this message translates to:
  /// **'Add an account for your child, then pair it to their phone.'**
  String get familyScreenEmptyStateBody;

  /// All-caps section header at the top of the reaction-details bottom sheet (long-press a reaction chip to see who reacted).
  ///
  /// In en, this message translates to:
  /// **'REACTIONS'**
  String get reactionDetailsSheetTitle;

  /// Empty-state copy shown in the reaction-details sheet when every reaction on the message has since been taken back.
  ///
  /// In en, this message translates to:
  /// **'nothing here anymore'**
  String get reactionDetailsSheetEmptyState;

  /// Subtitle under the REACTIONS header in the reaction-details sheet, counting distinct people who reacted to the message.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 person} other{{count} people}}'**
  String reactionDetailsSheetPeopleCount(num count);

  /// All-caps label on the first filter pill in the reaction-details sheet, showing every reactor regardless of which emoji they used.
  ///
  /// In en, this message translates to:
  /// **'ALL'**
  String get reactionDetailsSheetFilterAll;

  /// All-caps badge next to the current user's own name in the reaction-details sheet's list of reactors.
  ///
  /// In en, this message translates to:
  /// **'YOU'**
  String get reactionDetailsSheetYouBadge;

  /// Room Layout settings screen — main heading (lowercase sentence-fragment display style)
  ///
  /// In en, this message translates to:
  /// **'chat list.'**
  String get roomLayoutScreenTitle;

  /// Room Layout settings screen — caption under the title explaining the page's purpose
  ///
  /// In en, this message translates to:
  /// **'how rooms stack, and how you filter them'**
  String get roomLayoutScreenSubtitle;

  /// All-caps section header above the room-list layout options (row/grid)
  ///
  /// In en, this message translates to:
  /// **'LAYOUT'**
  String get roomLayoutScreenLayoutSectionLabel;

  /// All-caps label on the option card for the single-column room list layout
  ///
  /// In en, this message translates to:
  /// **'ROW LAYOUT'**
  String get roomLayoutScreenRowLayoutLabel;

  /// Small description text under the ROW LAYOUT option card
  ///
  /// In en, this message translates to:
  /// **'one column, full bleed. easy to read at a glance.'**
  String get roomLayoutScreenRowLayoutDescription;

  /// All-caps label on the option card for the two-column grid room list layout
  ///
  /// In en, this message translates to:
  /// **'GRID LAYOUT'**
  String get roomLayoutScreenGridLayoutLabel;

  /// Small description text under the GRID LAYOUT option card
  ///
  /// In en, this message translates to:
  /// **'two columns, compact. more rooms in one look.'**
  String get roomLayoutScreenGridLayoutDescription;

  /// All-caps section header above the filter-style options (chip row / drawer button)
  ///
  /// In en, this message translates to:
  /// **'FILTER CONTROL'**
  String get roomLayoutScreenFilterControlSectionLabel;

  /// All-caps label on the option card for the always-visible filter-chip row style
  ///
  /// In en, this message translates to:
  /// **'CHIP ROW'**
  String get roomLayoutScreenChipRowLabel;

  /// Small description text under the CHIP ROW option card
  ///
  /// In en, this message translates to:
  /// **'always on show. one tap to any filter, one row of space.'**
  String get roomLayoutScreenChipRowDescription;

  /// All-caps label on the option card for the collapsible drawer-button filter style
  ///
  /// In en, this message translates to:
  /// **'DRAWER BUTTON'**
  String get roomLayoutScreenDrawerButtonLabel;

  /// Small description text under the DRAWER BUTTON option card
  ///
  /// In en, this message translates to:
  /// **'one button that opens. nothing in the way until you ask.'**
  String get roomLayoutScreenDrawerButtonDescription;

  /// All-caps section label on the room layout screen, above the choice of what a grid tile shows when the room has no messages yet.
  ///
  /// In en, this message translates to:
  /// **'QUIET ROOMS'**
  String get roomLayoutScreenQuietRoomSectionLabel;

  /// Label for the option that leaves a quiet grid tile's corner empty (room layout screen).
  ///
  /// In en, this message translates to:
  /// **'plain corner'**
  String get roomLayoutScreenPlainCornerLabel;

  /// One-line description of the plain-corner option for quiet grid tiles.
  ///
  /// In en, this message translates to:
  /// **'a room with nothing said yet stays bare'**
  String get roomLayoutScreenPlainCornerDescription;

  /// Label for the option that fills a quiet grid tile's corner with the room's first letter (room layout screen).
  ///
  /// In en, this message translates to:
  /// **'the room\'s initial'**
  String get roomLayoutScreenMonogramLabel;

  /// One-line description of the monogram option for quiet grid tiles.
  ///
  /// In en, this message translates to:
  /// **'a big faded letter fills the empty corner'**
  String get roomLayoutScreenMonogramDescription;

  /// Small all-caps badge shown on whichever layout/filter option card is currently selected
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get roomLayoutScreenActiveBadge;

  /// Semantic/accessibility label for the tappable pinned-message row in the pinned banner strip (lib/widgets/pinned_banner.dart) — jumps the transcript to the active pin.
  ///
  /// In en, this message translates to:
  /// **'Jump to pinned message'**
  String get pinnedBannerJumpToPinnedSemanticLabel;

  /// Semantic/accessibility label for the list-icon button in the pinned banner strip that opens the full list of pinned messages.
  ///
  /// In en, this message translates to:
  /// **'All pinned messages'**
  String get pinnedBannerAllPinnedSemanticLabel;

  /// Small title line shown above the pinned-message preview in the banner strip when there is exactly one pin in the room.
  ///
  /// In en, this message translates to:
  /// **'Pinned message'**
  String get pinnedBannerTitleSingle;

  /// Small title line shown above the pinned-message preview in the banner strip when there are multiple pins; {index} is the 1-based position of the currently shown pin and {count} is the total number of pins in the room.
  ///
  /// In en, this message translates to:
  /// **'Pinned message  {index}/{count}'**
  String pinnedBannerTitleWithIndex(Object count, Object index);

  /// Large lowercase heading fragment at the top of the Chat Style settings screen (lib/screens/chat_style_screen.dart), where the user picks between Classic and Compact chat chrome.
  ///
  /// In en, this message translates to:
  /// **'chat style.'**
  String get pinnedBannerChatStyleTitle;

  /// Small caption under the 'chat style.' heading, next to a short accent-colored divider line, describing what the screen's setting controls.
  ///
  /// In en, this message translates to:
  /// **'how the room looks'**
  String get pinnedBannerChatStyleSubtitle;

  /// All-caps label on the option card for the 'classic' chat chrome style (divider-bordered header, flat composer) on the Chat Style screen.
  ///
  /// In en, this message translates to:
  /// **'CLASSIC'**
  String get pinnedBannerClassicLabel;

  /// Small mono-style description under the CLASSIC option card explaining the visual traits of that chat style.
  ///
  /// In en, this message translates to:
  /// **'divider-bordered header, flat composer.'**
  String get pinnedBannerClassicSubtitle;

  /// All-caps label on the option card for the 'compact' chat chrome style (frosted glass pills floating over the transcript) on the Chat Style screen.
  ///
  /// In en, this message translates to:
  /// **'COMPACT'**
  String get pinnedBannerCompactLabel;

  /// Small mono-style description under the COMPACT option card explaining the visual traits of that chat style.
  ///
  /// In en, this message translates to:
  /// **'frosted pills floating over the conversation.'**
  String get pinnedBannerCompactSubtitle;

  /// Small all-caps badge shown next to a dot indicator on whichever chat-style option card is currently selected.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get pinnedBannerActiveBadge;

  /// Shown in place of the audio bubble player when a message has no storage id at all (audio_message.dart).
  ///
  /// In en, this message translates to:
  /// **'[audio missing]'**
  String get audioMessageMissingLabel;

  /// Shown when the backend has no URL for the audio file (e.g. burned view-once note or swept blob) — no retry is offered.
  ///
  /// In en, this message translates to:
  /// **'audio unavailable'**
  String get audioMessageUnavailableLabel;

  /// Caption next to the retry disc/icon when an audio note fails to load.
  ///
  /// In en, this message translates to:
  /// **'tap to retry'**
  String get audioMessageRetryHint;

  /// Placeholder shown instead of the elapsed/total duration readout while an audio note's duration is not yet known.
  ///
  /// In en, this message translates to:
  /// **'loading…'**
  String get audioMessageLoadingLabel;

  /// Inline form error on the social sign-up/link screen when the username field is submitted empty.
  ///
  /// In en, this message translates to:
  /// **'Enter your username.'**
  String get audioMessageUsernameRequiredError;

  /// Inline form error on the social sign-up/link screen when linking an existing account and the password field is empty.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get audioMessagePasswordRequiredError;

  /// Screen-reader label for the close (X) control on the social username screen.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get audioMessageCancelSemanticLabel;

  /// First line of the two-tone hero heading shown in create-account mode of the social username screen (combines with line 2 to read 'almost there.').
  ///
  /// In en, this message translates to:
  /// **'almost\n'**
  String get audioMessageHeroCreateLine1;

  /// Second line of the hero heading in create-account mode, rendered in the accent color.
  ///
  /// In en, this message translates to:
  /// **'there.'**
  String get audioMessageHeroCreateLine2;

  /// First line of the two-tone hero heading shown in link-existing-account mode of the social username screen (combines with line 2 to read 'welcome back.').
  ///
  /// In en, this message translates to:
  /// **'welcome\n'**
  String get audioMessageHeroLinkLine1;

  /// Second line of the hero heading in link mode, rendered in the accent color.
  ///
  /// In en, this message translates to:
  /// **'back.'**
  String get audioMessageHeroLinkLine2;

  /// Body copy under the hero heading, shown in create-account mode.
  ///
  /// In en, this message translates to:
  /// **'Pick a username so your family and friends can find you.'**
  String get audioMessageCreateSubtitle;

  /// Body copy under the hero heading in link mode; {provider} is the social provider name (e.g. Google, Apple).
  ///
  /// In en, this message translates to:
  /// **'Sign in once and {provider} is attached to your account.'**
  String audioMessageLinkSubtitle(Object provider);

  /// Hint text for the username text field on the social username screen.
  ///
  /// In en, this message translates to:
  /// **'username'**
  String get audioMessageUsernameHint;

  /// Hint text for the optional display-name field shown in create-account mode.
  ///
  /// In en, this message translates to:
  /// **'display name (optional)'**
  String get audioMessageDisplayNameHint;

  /// Hint text for the password field shown in link-existing-account mode.
  ///
  /// In en, this message translates to:
  /// **'password'**
  String get audioMessagePasswordHint;

  /// Link shown under a 'username taken' error, offering to switch into link-existing-account mode.
  ///
  /// In en, this message translates to:
  /// **'That one’s mine — sign in'**
  String get audioMessageSwitchToLinkPrompt;

  /// All-caps primary CTA button label in create-account mode.
  ///
  /// In en, this message translates to:
  /// **'CREATE ACCOUNT'**
  String get audioMessageCreateAccountButton;

  /// All-caps primary CTA button label in link-existing-account mode; {provider} is the social provider name. The whole result is uppercased in code afterward to force the provider name to caps too, so keep this value already fully uppercase.
  ///
  /// In en, this message translates to:
  /// **'SIGN IN & LINK {provider}'**
  String audioMessageSignInLinkButton(Object provider);

  /// Bottom link in create-account mode, switches to link-existing-account mode.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get audioMessageSwitchToLinkModeLink;

  /// Bottom link in link-existing-account mode, switches to create-account mode.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get audioMessageSwitchToCreateModeLink;

  /// All-caps screen header on the guardian approvals inbox app bar.
  ///
  /// In en, this message translates to:
  /// **'APPROVALS'**
  String get approvalsScreenTitle;

  /// Empty-state title shown when the approvals queue has nothing pending.
  ///
  /// In en, this message translates to:
  /// **'nothing waiting'**
  String get approvalsScreenEmptyTitle;

  /// Empty-state subtitle under 'nothing waiting'.
  ///
  /// In en, this message translates to:
  /// **'you\'re all caught up'**
  String get approvalsScreenEmptySubtitle;

  /// Snackbar error shown when the current guardian isn't authorized to decide this request.
  ///
  /// In en, this message translates to:
  /// **'that\'s not yours to decide'**
  String get approvalsScreenErrorNotGuardian;

  /// Snackbar error shown when the request was already resolved (e.g. by another guardian) before this decision landed.
  ///
  /// In en, this message translates to:
  /// **'already handled somewhere else'**
  String get approvalsScreenErrorAlreadyHandled;

  /// Generic snackbar error shown when approving/denying a queue item fails to save.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t save that — try again'**
  String get approvalsScreenErrorGeneric;

  /// Queue card headline: the guardian's own child wants to add someone as a contact. {child} and {other} are display names.
  ///
  /// In en, this message translates to:
  /// **'{child} wants to add {other}'**
  String approvalsScreenHeadlineContactOutgoing(Object child, Object other);

  /// Queue card headline: an outside person wants to add the guardian's child as a contact. {other} and {child} are display names.
  ///
  /// In en, this message translates to:
  /// **'{other} wants to add {child}'**
  String approvalsScreenHeadlineContactIncoming(Object child, Object other);

  /// Queue card headline: the guardian's child wants to join a room. {child} is a display name, {room} is a room name.
  ///
  /// In en, this message translates to:
  /// **'{child} wants to join {room}'**
  String approvalsScreenHeadlineJoinRoom(Object child, Object room);

  /// Mid-sentence fallback for the other party's name in an outgoing-contact headline when their display name isn't known yet.
  ///
  /// In en, this message translates to:
  /// **'someone'**
  String get approvalsScreenSomeoneLower;

  /// Sentence-initial fallback for the other party's name in an incoming-contact headline when their display name isn't known yet.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get approvalsScreenSomeoneCapital;

  /// Fallback room name in the join-room headline when the room's real name isn't cached yet.
  ///
  /// In en, this message translates to:
  /// **'a room'**
  String get approvalsScreenRoomFallback;

  /// Explanatory line under an outgoing-contact-request queue card, clarifying that approving doesn't force the other person to accept.
  ///
  /// In en, this message translates to:
  /// **'They\'ll get the request. They still choose whether to say yes.'**
  String get approvalsScreenConsequenceContactOutgoing;

  /// Explanatory line under an incoming-contact-request queue card, clarifying that approving just lets the child see the request. {child} is a display name.
  ///
  /// In en, this message translates to:
  /// **'{child} will see the request and can accept or ignore it.'**
  String approvalsScreenConsequenceContactIncoming(Object child);

  /// Explanatory line under a join-room queue card, clarifying the scope and reversibility of the permission.
  ///
  /// In en, this message translates to:
  /// **'They\'ll be able to read and post there until you take it back.'**
  String get approvalsScreenConsequenceJoinRoom;

  /// All-caps button label to decline/defer a queue item.
  ///
  /// In en, this message translates to:
  /// **'NOT YET'**
  String get approvalsScreenNotYetButton;

  /// All-caps button label to approve a queue item.
  ///
  /// In en, this message translates to:
  /// **'ALLOW'**
  String get approvalsScreenAllowButton;

  /// Fallback title for a DM in the forward-target list when the peer's profile isn't cached yet.
  ///
  /// In en, this message translates to:
  /// **'direct message'**
  String get approvalsScreenForwardDirectMessageFallback;

  /// All-caps sheet title showing how many messages are about to be forwarded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{FORWARD MESSAGE} other{FORWARD {count} MESSAGES}}'**
  String approvalsScreenForwardTitle(num count);

  /// Empty-state text in the forward-target list when the user has no other chats to forward into.
  ///
  /// In en, this message translates to:
  /// **'no other chats yet'**
  String get approvalsScreenForwardNoChatsYet;

  /// Empty-state text in the forward-target list when the search query matches no chats.
  ///
  /// In en, this message translates to:
  /// **'nothing matches'**
  String get approvalsScreenForwardNoMatches;

  /// Caption shown once the max number of forward targets is picked, explaining the cap. {max} is the numeric limit.
  ///
  /// In en, this message translates to:
  /// **'up to {max} chats at a time'**
  String approvalsScreenForwardMaxTargetsHint(Object max);

  /// Hint text in the forward-target sheet's search field.
  ///
  /// In en, this message translates to:
  /// **'search chats'**
  String get approvalsScreenForwardSearchHint;

  /// Screen-reader semantic label for a room row that is currently selected as a forward target. {title} is the room/chat title.
  ///
  /// In en, this message translates to:
  /// **'Deselect {title}'**
  String approvalsScreenForwardDeselectSemantic(Object title);

  /// Screen-reader semantic label for a room row that is not currently selected as a forward target. {title} is the room/chat title.
  ///
  /// In en, this message translates to:
  /// **'Select {title}'**
  String approvalsScreenForwardSelectSemantic(Object title);

  /// All-caps tiny badge on a room row marking it as an ephemeral/self-destructing room.
  ///
  /// In en, this message translates to:
  /// **'FADES'**
  String get approvalsScreenForwardFadesBadge;

  /// Screen-reader semantic label for the forward sheet's send button.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get approvalsScreenForwardSendSemantic;

  /// All-caps send button label in the forward sheet, showing how many chats are selected as targets.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{SEND} other{SEND TO {count}}}'**
  String approvalsScreenForwardSendButton(num count);

  /// All-caps screen header on the Linked Accounts screen, next to the back button.
  ///
  /// In en, this message translates to:
  /// **'LINKED ACCOUNTS'**
  String get linkedAccountsScreenTitle;

  /// Explanatory line under the Linked Accounts screen title.
  ///
  /// In en, this message translates to:
  /// **'Accounts you’ve attached to this one, so you can sign in without a password.'**
  String get linkedAccountsScreenSubtitle;

  /// Shown instead of provider cards when no social sign-in providers are available on this device.
  ///
  /// In en, this message translates to:
  /// **'There’s nothing to link on this device.'**
  String get linkedAccountsScreenEmptyState;

  /// Body text on a provider card while the linked-status is still being fetched (linked == null).
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get linkedAccountsScreenStatusChecking;

  /// Body text on a provider card when that provider (e.g. Apple, Google) is linked. {provider} is the provider's display name.
  ///
  /// In en, this message translates to:
  /// **'You can sign in with {provider} on any of your devices.'**
  String linkedAccountsScreenStatusLinked(Object provider);

  /// Body text on a provider card when that provider is not linked. {provider} is the provider's display name.
  ///
  /// In en, this message translates to:
  /// **'Add {provider} so you don’t have to type your password.'**
  String linkedAccountsScreenStatusNotLinked(Object provider);

  /// All-caps title of the password-confirmation sheet shown when unlinking a provider, and also the all-caps label on the Unlink button itself. {provider} is the already-uppercased provider name (e.g. APPLE).
  ///
  /// In en, this message translates to:
  /// **'UNLINK {provider}'**
  String linkedAccountsScreenUnlinkTitle(Object provider);

  /// All-caps confirm-button label on the password prompt sheet used to detach a linked provider.
  ///
  /// In en, this message translates to:
  /// **'UNLINK'**
  String get linkedAccountsScreenUnlinkAction;

  /// Subtitle on the password prompt sheet shown when unlinking a provider. {provider} is the provider's display name.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to stop signing in with {provider}.'**
  String linkedAccountsScreenUnlinkSubtitle(Object provider);

  /// All-caps title of the password-confirmation sheet shown when linking a new provider. {provider} is the already-uppercased provider name (e.g. APPLE).
  ///
  /// In en, this message translates to:
  /// **'LINK {provider}'**
  String linkedAccountsScreenLinkTitle(Object provider);

  /// All-caps confirm-button label on the password prompt sheet used to attach a new provider.
  ///
  /// In en, this message translates to:
  /// **'LINK'**
  String get linkedAccountsScreenLinkAction;

  /// Subtitle on the password prompt sheet shown when linking a new provider. {provider} is the provider's display name.
  ///
  /// In en, this message translates to:
  /// **'Enter your password to add {provider} as a way to sign in.'**
  String linkedAccountsScreenLinkSubtitle(Object provider);

  /// All-caps status pill on a provider card while the linked-status is unknown.
  ///
  /// In en, this message translates to:
  /// **'CHECKING'**
  String get linkedAccountsScreenPillChecking;

  /// All-caps status pill on a provider card when the provider is linked.
  ///
  /// In en, this message translates to:
  /// **'LINKED'**
  String get linkedAccountsScreenPillLinked;

  /// All-caps status pill on a provider card when the provider is not linked.
  ///
  /// In en, this message translates to:
  /// **'NOT LINKED'**
  String get linkedAccountsScreenPillNotLinked;

  /// All-caps chip label choosing an audio-only group call in the start-call bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'VOICE'**
  String get linkedAccountsScreenCallSheetVoiceLabel;

  /// All-caps chip label choosing a video group call in the start-call bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'VIDEO'**
  String get linkedAccountsScreenCallSheetVideoLabel;

  /// Title of the bottom sheet used to start a group call from a room header.
  ///
  /// In en, this message translates to:
  /// **'Start a call'**
  String get linkedAccountsScreenCallSheetTitle;

  /// Title of the 'ring the whole room' option row in the start-call sheet.
  ///
  /// In en, this message translates to:
  /// **'Call everyone'**
  String get linkedAccountsScreenCallSheetCallEveryoneTitle;

  /// Subtitle/caption under the 'Call everyone' option row.
  ///
  /// In en, this message translates to:
  /// **'Ring all members of this room'**
  String get linkedAccountsScreenCallSheetCallEveryoneSubtitle;

  /// Title of the 'pick specific members' option row in the start-call sheet.
  ///
  /// In en, this message translates to:
  /// **'Choose people'**
  String get linkedAccountsScreenCallSheetChoosePeopleTitle;

  /// Subtitle/caption under the 'Choose people' option row.
  ///
  /// In en, this message translates to:
  /// **'Pick who to invite'**
  String get linkedAccountsScreenCallSheetChoosePeopleSubtitle;

  /// Snackbar error shown when starting a call fails because the room already has the max participants.
  ///
  /// In en, this message translates to:
  /// **'That call is full (max 6 people)'**
  String get linkedAccountsScreenCallSheetCallFullError;

  /// Generic snackbar error shown when starting a group call fails for any other reason.
  ///
  /// In en, this message translates to:
  /// **'Could not start the call'**
  String get linkedAccountsScreenCallSheetStartFailedError;

  /// Title of the member-picker bottom sheet used to choose who to invite to a call.
  ///
  /// In en, this message translates to:
  /// **'Invite to call'**
  String get linkedAccountsScreenCallSheetInviteTitle;

  /// Empty-state text in the member picker when the room has no other members to invite.
  ///
  /// In en, this message translates to:
  /// **'No other members here'**
  String get linkedAccountsScreenCallSheetNoOtherMembers;

  /// Disabled-state label on the invite/start button in the member picker when nobody is selected yet.
  ///
  /// In en, this message translates to:
  /// **'Select people'**
  String get linkedAccountsScreenCallSheetSelectPeople;

  /// Screen-reader semantic label for the start-call button in the member picker sheet (static, regardless of selection count).
  ///
  /// In en, this message translates to:
  /// **'Start call'**
  String get linkedAccountsScreenCallSheetStartCallLabel;

  /// Visible label on the start-call button in the member picker once at least one person is selected; {count} is the number of people selected.
  ///
  /// In en, this message translates to:
  /// **'Start call ({count})'**
  String linkedAccountsScreenCallSheetStartCallCount(Object count);

  /// First line of the hero greeting on the child pairing screen; rendered above 'you.' in a muted color, lowercase display-heading fragment.
  ///
  /// In en, this message translates to:
  /// **'hello'**
  String get childPairScreenGreetingLine1;

  /// Second line of the hero greeting, completes 'hello / you.' as a playful direct-address fragment on the child pairing screen.
  ///
  /// In en, this message translates to:
  /// **'you.'**
  String get childPairScreenGreetingLine2;

  /// Body copy under the hero heading on the child pairing screen, explaining how to get paired to a parent's account.
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up to open MonkeyHub and tap “pair a device”. Then scan their code, or type the six numbers they read out.'**
  String get childPairScreenIntro;

  /// Tiny lowercase divider word between the QR-scan button and the manual six-digit code entry field.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get childPairScreenOrDivider;

  /// Fallback error message shown on the child pairing screen when the pairing code redemption fails for an unrecognized reason.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get childPairScreenGenericError;

  /// Error shown on the child pairing screen specifically for USER_NOT_FOUND — here it means the child's account was deleted, not that a typed username didn't match (no username is typed on this screen).
  ///
  /// In en, this message translates to:
  /// **'That account isn’t there any more.'**
  String get childPairScreenAccountGoneError;

  /// All-caps label on the button that opens the QR scanner on the child pairing screen.
  ///
  /// In en, this message translates to:
  /// **'SCAN THEIR CODE'**
  String get childPairScreenScanButtonLabel;

  /// Fallback message shown inside the scanner panel when the camera is denied or unavailable, on the child pairing screen.
  ///
  /// In en, this message translates to:
  /// **'No camera here — type the six numbers instead.'**
  String get childPairScreenNoCameraMessage;

  /// Lowercase tappable label under the live QR scanner preview that cancels scanning and returns to the scan button.
  ///
  /// In en, this message translates to:
  /// **'stop scanning'**
  String get childPairScreenStopScanning;

  /// All-caps primary submit button label on the child pairing screen, tapped to redeem the six-digit code.
  ///
  /// In en, this message translates to:
  /// **'LET ME IN'**
  String get childPairScreenSubmitButtonLabel;

  /// Lowercase back-navigation link (with a leading arrow glyph) shown on the child pairing screen when it was reached from the adult login form.
  ///
  /// In en, this message translates to:
  /// **'← back to sign in'**
  String get childPairScreenBackToSignIn;

  /// SnackBar shown in FileMessage when tapping a document fails because the underlying blob was deleted (FileUnavailable).
  ///
  /// In en, this message translates to:
  /// **'file is no longer available'**
  String get fileMessageUnavailable;

  /// SnackBar shown in FileMessage on any other failure while trying to save/open a tapped document.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t open that file'**
  String get fileMessageOpenFailed;

  /// Fallback shown in place of a document's name/size in FileMessage and OutboundFileRow when the real fileName or size is unknown.
  ///
  /// In en, this message translates to:
  /// **'document'**
  String get fileMessageDefaultName;

  /// Screen-reader semanticLabel on the tappable FileMessage row; {name} is the document's file name.
  ///
  /// In en, this message translates to:
  /// **'Save {name}'**
  String fileMessageSaveSemanticLabel(Object name);

  /// Screen-reader semanticLabel on the tappable FileMessage row for a plain-text attachment, where tapping opens the in-app viewer instead of downloading; {name} is the document's file name.
  ///
  /// In en, this message translates to:
  /// **'View {name}'**
  String fileMessageViewSemanticLabel(Object name);

  /// Tooltip on TextFileViewerScreen's trailing icon button, which downloads the file being previewed.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get textFileViewerDownloadTooltip;

  /// Banner shown above the text body in TextFileViewerScreen when the file was too large to preview in full and was cut off.
  ///
  /// In en, this message translates to:
  /// **'Showing part of this file — download to see the rest.'**
  String get textFileViewerTruncatedNotice;

  /// Caption under a document's name in OutboundFileRow when the upload of that file failed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get fileMessageUploadFailedLabel;

  /// Caption under a document's name in OutboundFileRow while it is uploading and its size is not yet known.
  ///
  /// In en, this message translates to:
  /// **'sending…'**
  String get fileMessageSendingLabel;

  /// Caption under a document's name in OutboundFileRow while uploading; {size} is an already-formatted file size like '2.4 MB'.
  ///
  /// In en, this message translates to:
  /// **'{size} · sending…'**
  String fileMessageSizeSendingLabel(Object size);

  /// Terse relative-time label on a friend request card for an age under an hour, e.g. '5m ago'.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String fileMessageAgoMinutes(Object count);

  /// Terse relative-time label on a friend request card for an age under a day, e.g. '3h ago'.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String fileMessageAgoHours(Object count);

  /// Terse relative-time label on a friend request card for an age of a day or more, e.g. '2d ago'.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String fileMessageAgoDays(Object count);

  /// All-caps chip on an incoming friend request card marking a non-ephemeral (standard) room, shown opposite the ephemeral/secret badge.
  ///
  /// In en, this message translates to:
  /// **'STANDARD'**
  String get fileMessageStandardBadge;

  /// Row on an incoming friend request card hinting there are multiple draft messages attached; tapping the card opens them.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} draft message · tap to view} other{{count} draft messages · tap to view}}'**
  String fileMessageDraftMessagesTapToView(num count);

  /// All-caps primary button on an incoming friend request card that accepts the request.
  ///
  /// In en, this message translates to:
  /// **'APPROVE'**
  String get fileMessageApproveButton;

  /// All-caps secondary button on an incoming friend request card that rejects the request.
  ///
  /// In en, this message translates to:
  /// **'DECLINE'**
  String get fileMessageDeclineButton;

  /// All-caps label on an outgoing friend request card; {ago} is an already-uppercased relative time like '5M AGO' / '5DK ÖNCE'. Turkish reorders it so the verb comes last, matching natural word order.
  ///
  /// In en, this message translates to:
  /// **'SENT {ago}'**
  String fileMessageSentAgoLabel(Object ago);

  /// Row on an outgoing friend request card showing how many draft messages are still waiting to be delivered once the request is accepted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} message pending} other{{count} messages pending}}'**
  String fileMessageMessagesPending(num count);

  /// All-caps button on an outgoing friend request card that withdraws the pending request.
  ///
  /// In en, this message translates to:
  /// **'CANCEL REQUEST'**
  String get fileMessageCancelRequestButton;

  /// Subtitle under the destructive action tile in the generic "are you sure?" confirm bottom sheet (lib/widgets/destructive_sheet.dart, _ConfirmSheet), warning the action is irreversible.
  ///
  /// In en, this message translates to:
  /// **'this cannot be undone'**
  String get destructiveSheetCannotBeUndone;

  /// Screen-reader semantic label for the Cancel control at the bottom of the destructive confirm sheet.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get destructiveSheetCancelSemanticLabel;

  /// All-caps visible label of the Cancel button at the bottom of the destructive confirm sheet.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get destructiveSheetCancelButtonLabel;

  /// All-caps toggle label shown when the "shared rooms" panel (SharedRoomsPanel) is expanded; tapping collapses it.
  ///
  /// In en, this message translates to:
  /// **'HIDE'**
  String get destructiveSheetHideLabel;

  /// All-caps toggle label shown when the "shared rooms" panel (SharedRoomsPanel) is collapsed; tapping expands it to list the shared rooms.
  ///
  /// In en, this message translates to:
  /// **'VIEW'**
  String get destructiveSheetViewLabel;

  /// Error message on the pairing/release code screen (lib/screens/pairing_code_screen.dart) shown when minting a new code fails.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t make a code — try again.'**
  String get destructiveSheetPairingMintError;

  /// All-caps header prefix (followed by the child's name) shown when this screen is generating a "hand phone back" release code.
  ///
  /// In en, this message translates to:
  /// **'RELEASE'**
  String get destructiveSheetPairingReleaseTitle;

  /// All-caps header prefix (followed by the child's name) shown when this screen is generating a device-pairing code.
  ///
  /// In en, this message translates to:
  /// **'PAIR'**
  String get destructiveSheetPairingPairTitle;

  /// Instructional body text on the release-code screen telling the guardian what to do on the child's phone. {name} is the child's display name.
  ///
  /// In en, this message translates to:
  /// **'On {name}’s phone, open their profile, tap “hand this phone back”, and type these numbers.'**
  String destructiveSheetPairingReleaseInstructions(Object name);

  /// Instructional body text on the pairing-code screen telling the guardian what to do on the child's phone. {name} is the child's display name.
  ///
  /// In en, this message translates to:
  /// **'On {name}’s phone, open MonkeyHub and scan this — or type the numbers.'**
  String destructiveSheetPairingPairInstructions(Object name);

  /// Lowercase status line shown under the code once its countdown reaches zero.
  ///
  /// In en, this message translates to:
  /// **'this code has expired'**
  String get destructiveSheetPairingCodeExpired;

  /// Countdown status line shown under the code while it is still valid; {time} is a formatted mm:ss string (e.g. "4:59").
  ///
  /// In en, this message translates to:
  /// **'expires in {time}'**
  String destructiveSheetPairingExpiresIn(Object time);

  /// All-caps button label to mint a fresh pairing/release code.
  ///
  /// In en, this message translates to:
  /// **'NEW CODE'**
  String get destructiveSheetPairingNewCodeButton;

  /// Small footnote under the NEW CODE button explaining code semantics.
  ///
  /// In en, this message translates to:
  /// **'One use only. Making a new code cancels the old one.'**
  String get destructiveSheetPairingOneUseNote;

  /// Screen-reader semantic label for the composer's attach-file circular button (chat_composer.dart, both classic and used for accessibility).
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get deepOceanThemeAttachButtonLabel;

  /// Screen-reader semantic label for the composer's camera-shortcut circular button (chat_composer.dart).
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get deepOceanThemeCameraButtonLabel;

  /// Screen-reader semantic label for the composer's send-message circular button (chat_composer.dart).
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get deepOceanThemeSendButtonLabel;

  /// TextField hintText shown in the chat composer when composing an ephemeral (self-destructing) message; used in both ChatComposerClassic and ChatComposerLiquid.
  ///
  /// In en, this message translates to:
  /// **'whisper something the server will forget…'**
  String get deepOceanThemeEphemeralHint;

  /// TextField hintText shown in ChatComposerClassic for a normal (non-ephemeral) message.
  ///
  /// In en, this message translates to:
  /// **'say something…'**
  String get deepOceanThemeDefaultHint;

  /// TextField hintText shown in ChatComposerLiquid for a normal (non-ephemeral) message; terser than the classic composer's hint to fit the glass-pill input style.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get deepOceanThemeMessageHint;

  /// Position indicator overlaid on the fullscreen media pager (e.g. '2 / 8') showing the current item's index out of the total number of swipeable media items.
  ///
  /// In en, this message translates to:
  /// **'{current} / {total}'**
  String photoChromeMediaPositionLabel(Object current, Object total);

  /// Shown centered in the fullscreen media pager page when a message's media attachment has no storage id, i.e. the file is missing or unavailable.
  ///
  /// In en, this message translates to:
  /// **'this file is gone'**
  String get photoChromeMediaGoneLabel;

  /// Fallback sender-name label at the top of the fullscreen media pager, shown when the message's senderName is empty (the viewer's own message).
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get photoChromeMediaYouLabel;

  /// Accessibility/semantic label for the circular close (X) button in the fullscreen media pager's top chrome bar.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get photoChromeCloseSemanticLabel;

  /// Accessibility/semantic label for the button in the fullscreen media pager that pops back and jumps to this message's location in the chat thread.
  ///
  /// In en, this message translates to:
  /// **'Show in chat'**
  String get photoChromeShowInChatSemanticLabel;

  /// Typing indicator label (room header, typing row, compact pill) when exactly one person is typing; {name} is the typist's display name.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing'**
  String typingIndicatorOnePersonTyping(Object name);

  /// Typing indicator label when exactly two people are typing at once; {name1}/{name2} are their display names.
  ///
  /// In en, this message translates to:
  /// **'{name1} and {name2} are typing'**
  String typingIndicatorTwoPeopleTyping(Object name1, Object name2);

  /// Typing indicator label when three or more people are typing; shows the first two names plus how many more, e.g. 'mom, dad +2 are typing'. {extra} is the remaining count passed as a string.
  ///
  /// In en, this message translates to:
  /// **'{name1}, {name2} +{extra} are typing'**
  String typingIndicatorManyPeopleTyping(
    Object extra,
    Object name1,
    Object name2,
  );

  /// Fallback shown in place of the caller's name on the incoming-call screen when the peer's display name is unknown.
  ///
  /// In en, this message translates to:
  /// **'incoming call'**
  String get typingIndicatorUnknownCallerFallbackName;

  /// All-caps pill label on the incoming call screen identifying the call as video. Value is already upper-cased in the ARB itself (code no longer calls .toUpperCase() on it) because Dart's String.toUpperCase() isn't locale-aware and would mangle the Turkish dotted İ.
  ///
  /// In en, this message translates to:
  /// **'INCOMING VIDEO CALL'**
  String get typingIndicatorIncomingVideoCallLabel;

  /// All-caps pill label on the incoming call screen identifying the call as voice/audio. Same pre-uppercased treatment as the video-call label, for the same Turkish-casing reason.
  ///
  /// In en, this message translates to:
  /// **'INCOMING VOICE CALL'**
  String get typingIndicatorIncomingVoiceCallLabel;

  /// Caption under the red hang-up button on the incoming call screen, idle/tappable state.
  ///
  /// In en, this message translates to:
  /// **'decline'**
  String get typingIndicatorDeclineButtonLabel;

  /// Caption under the red hang-up button while the reject action is in flight (button disabled).
  ///
  /// In en, this message translates to:
  /// **'declining…'**
  String get typingIndicatorDeclineButtonDeclining;

  /// Caption under the green accept button on the incoming call screen, idle/tappable state.
  ///
  /// In en, this message translates to:
  /// **'accept'**
  String get typingIndicatorAcceptButtonLabel;

  /// Caption under the green accept button while the accept action is in flight (button disabled).
  ///
  /// In en, this message translates to:
  /// **'connecting…'**
  String get typingIndicatorAcceptButtonConnecting;

  /// Lowercase display heading at the top of the navigation-style picker screen (NavigationScreen).
  ///
  /// In en, this message translates to:
  /// **'navigation.'**
  String get messageStampNavigationTitle;

  /// Caption under the 'navigation.' heading explaining what this settings screen controls.
  ///
  /// In en, this message translates to:
  /// **'how you move between chat, discover, feed, settings'**
  String get messageStampNavigationSubtitle;

  /// All-caps label on the option card for the radial floating-orb navigation style.
  ///
  /// In en, this message translates to:
  /// **'RADIAL ORB'**
  String get messageStampRadialOrbLabel;

  /// Sub-description text under the RADIAL ORB navigation style option card.
  ///
  /// In en, this message translates to:
  /// **'hold + drag from the corner. a quiet idle, a gesture you grow into.'**
  String get messageStampRadialOrbDescription;

  /// All-caps label on the option card for the classic bottom pill-bar navigation style.
  ///
  /// In en, this message translates to:
  /// **'BOTTOM PILL'**
  String get messageStampBottomPillLabel;

  /// Sub-description text under the BOTTOM PILL navigation style option card.
  ///
  /// In en, this message translates to:
  /// **'classic tap. always visible, no learning curve.'**
  String get messageStampBottomPillDescription;

  /// Small all-caps badge shown on the navigation-style option card that is currently selected.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get messageStampActiveLabel;

  /// Screen-reader semanticLabel on the upward-arrow icon shown in a message's timestamp stamp while an attachment is uploading.
  ///
  /// In en, this message translates to:
  /// **'uploading'**
  String get messageStampUploadingLabel;

  /// Screen-reader semanticLabel on the clock icon shown in a message's timestamp stamp while the message is pending/sending.
  ///
  /// In en, this message translates to:
  /// **'sending'**
  String get messageStampSendingLabel;

  /// Screen-reader semanticLabel on the error icon shown in a message's timestamp stamp when sending failed.
  ///
  /// In en, this message translates to:
  /// **'failed to send'**
  String get messageStampFailedToSendLabel;

  /// Screen-reader semanticLabel on the double-check icon shown in a message's timestamp stamp once it has been seen by others.
  ///
  /// In en, this message translates to:
  /// **'seen'**
  String get messageStampSeenLabel;

  /// Terse remaining-seconds countdown (e.g. '42s') shown inline in an ephemeral message's stamp before it self-destructs.
  ///
  /// In en, this message translates to:
  /// **'{count}s'**
  String messageStampCountdownSeconds(Object count);

  /// Terse remaining-minutes countdown (e.g. '3m') shown inline in an ephemeral message's stamp before it self-destructs.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String messageStampCountdownMinutes(Object count);

  /// SnackBar message shown when the user denies microphone permission while trying to start a voice recording.
  ///
  /// In en, this message translates to:
  /// **'microphone permission denied'**
  String get voiceRecorderScreenMicPermissionDeniedSnackbar;

  /// All-caps status label at the top of the voice recorder screen shown while actively recording.
  ///
  /// In en, this message translates to:
  /// **'RECORDING'**
  String get voiceRecorderScreenStatusRecording;

  /// All-caps status label at the top of the voice recorder screen shown after a recording has finished and is ready to send.
  ///
  /// In en, this message translates to:
  /// **'READY'**
  String get voiceRecorderScreenStatusReady;

  /// All-caps status label at the top of the voice recorder screen shown before recording has started.
  ///
  /// In en, this message translates to:
  /// **'TAP TO START'**
  String get voiceRecorderScreenStatusTapToStart;

  /// All-caps secondary button label letting the user discard the current recording and record again.
  ///
  /// In en, this message translates to:
  /// **'RE-RECORD'**
  String get voiceRecorderScreenReRecordButton;

  /// All-caps primary action button label shown while recording, to stop the recording.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get voiceRecorderScreenStopButton;

  /// All-caps primary action button label shown after recording, to send the voice note.
  ///
  /// In en, this message translates to:
  /// **'SEND'**
  String get voiceRecorderScreenSendButton;

  /// All-caps primary action button label shown before recording starts, to begin recording.
  ///
  /// In en, this message translates to:
  /// **'RECORD'**
  String get voiceRecorderScreenRecordButton;

  /// Title of the special row in the @-mention picker (mention_picker.dart) that lets the user tag the whole room with @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get cyberpunkThemeMentionPickerEveryoneTitle;

  /// All-caps trailing badge on the 'Everyone' row of the @-mention picker, warning that picking it notifies every room member.
  ///
  /// In en, this message translates to:
  /// **'NOTIFIES ALL'**
  String get cyberpunkThemeMentionPickerNotifiesAllBadge;

  /// All-caps trailing badge shown next to a room owner's name in the @-mention picker list.
  ///
  /// In en, this message translates to:
  /// **'OWNER'**
  String get cyberpunkThemeMentionPickerOwnerBadge;

  /// Fallback pronoun substituted for the child's name on the release-device screen when no session name is available (rare).
  ///
  /// In en, this message translates to:
  /// **'them'**
  String get releaseDeviceScreenFallbackChildName;

  /// Explanatory body text at the top of the release-device screen describing what releasing does. {name} is the child's display name.
  ///
  /// In en, this message translates to:
  /// **'This signs {name} out of this phone and hands it back — the phone returns to the normal sign-in screen, and anyone can use it.'**
  String releaseDeviceScreenIntro(Object name);

  /// Reassurance note clarifying that releasing the device does not delete the child's account.
  ///
  /// In en, this message translates to:
  /// **'Their account, messages and friends are all kept. They can be signed back in any time.'**
  String get releaseDeviceScreenAccountKeptNote;

  /// Instructs the reader to ask a guardian to release the device from their own phone via the code flow. {name} is the child's display name; MonkeyHub stays untranslated.
  ///
  /// In en, this message translates to:
  /// **'Ask a grown-up to open MonkeyHub, find {name} under family, and tap “release”.'**
  String releaseDeviceScreenAskGrownUp(Object name);

  /// Small divider label between the two release methods (code entry vs. guardian password).
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get releaseDeviceScreenOrDivider;

  /// Explains the fallback password-based release method when there's no second device to generate a code.
  ///
  /// In en, this message translates to:
  /// **'If there’s only this one phone, a grown-up can sign in here instead.'**
  String get releaseDeviceScreenOnePhoneNote;

  /// Hint text in the guardian username field on the release-device screen.
  ///
  /// In en, this message translates to:
  /// **'a grown-up’s username'**
  String get releaseDeviceScreenUsernameHint;

  /// Hint text in the guardian password field on the release-device screen.
  ///
  /// In en, this message translates to:
  /// **'their password'**
  String get releaseDeviceScreenPasswordHint;

  /// Screen-reader semantic label for the sign-out action button.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get releaseDeviceScreenSignOutSemanticLabel;

  /// All-caps button label shown while the release request is in flight.
  ///
  /// In en, this message translates to:
  /// **'CHECKING…'**
  String get releaseDeviceScreenChecking;

  /// All-caps primary button label to sign the named child out; {name} is the child's display name, already uppercased by the caller.
  ///
  /// In en, this message translates to:
  /// **'SIGN {name} OUT'**
  String releaseDeviceScreenSignOutButton(Object name);

  /// All-caps header title bar text for the release-device screen.
  ///
  /// In en, this message translates to:
  /// **'HAND THIS PHONE BACK'**
  String get releaseDeviceScreenHeaderTitle;

  /// Error message shown when the release/pairing code has expired.
  ///
  /// In en, this message translates to:
  /// **'That code has run out. Ask for a new one.'**
  String get releaseDeviceScreenErrorCodeExpired;

  /// Error message shown when the release/pairing code is invalid.
  ///
  /// In en, this message translates to:
  /// **'That code didn’t work. It may have been used already.'**
  String get releaseDeviceScreenErrorCodeInvalid;

  /// Deliberately generic error shown when guardian username/password fails, so a child can't learn which usernames belong to guardians.
  ///
  /// In en, this message translates to:
  /// **'That didn’t work. Check the username and password.'**
  String get releaseDeviceScreenErrorNotAGuardian;

  /// Fallback error message for any unexpected release failure.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get releaseDeviceScreenErrorGeneric;

  /// Accessibility semanticLabel on the tappable active-call pill (top-of-screen banner shown when a call is active on another of the user's devices); tapping transfers the call here.
  ///
  /// In en, this message translates to:
  /// **'Move call to this device'**
  String get activeCallPillMoveHereSemanticLabel;

  /// Bold title line inside the active-call pill, e.g. 'Call with Alice'. {name} is the peer's display name (or a fallback if unknown).
  ///
  /// In en, this message translates to:
  /// **'Call with {name}'**
  String activeCallPillCallWith(Object name);

  /// Small caption under the call title inside the active-call pill, showing which device is currently on the call, e.g. 'On iPhone'. {device} is either the device's given name or a platform fallback label.
  ///
  /// In en, this message translates to:
  /// **'On {device}'**
  String activeCallPillOnDevice(Object device);

  /// Short action label inside a small pill badge at the end of the active-call banner, inviting the user to tap and move the call to this device.
  ///
  /// In en, this message translates to:
  /// **'Move here'**
  String get activeCallPillMoveHereLabel;

  /// Fallback for the peer's display name in the active-call pill when the backend call record has no peerName.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get activeCallPillUnknownCaller;

  /// Fallback device label in the active-call pill when no custom device name is set and the accepting platform is 'ios'. Brand name, kept untranslated.
  ///
  /// In en, this message translates to:
  /// **'iPhone'**
  String get activeCallPillPlatformIphone;

  /// Fallback device label in the active-call pill for the accepting platform 'ios-simulator' (developer/testing builds).
  ///
  /// In en, this message translates to:
  /// **'iOS Simulator'**
  String get activeCallPillPlatformIosSimulator;

  /// Fallback device label in the active-call pill for the accepting platform 'android' when no custom device name is set.
  ///
  /// In en, this message translates to:
  /// **'Android device'**
  String get activeCallPillPlatformAndroid;

  /// Fallback device label in the active-call pill for the accepting platform 'macos'. Brand name, kept untranslated.
  ///
  /// In en, this message translates to:
  /// **'Mac'**
  String get activeCallPillPlatformMac;

  /// Fallback device label in the active-call pill for the accepting platform 'windows'.
  ///
  /// In en, this message translates to:
  /// **'Windows PC'**
  String get activeCallPillPlatformWindows;

  /// Fallback device label in the active-call pill for the accepting platform 'linux'.
  ///
  /// In en, this message translates to:
  /// **'Linux device'**
  String get activeCallPillPlatformLinux;

  /// Fallback device label in the active-call pill for the accepting platform 'web'.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get activeCallPillPlatformBrowser;

  /// Generic fallback device label in the active-call pill used when the accepting platform is missing or unrecognized.
  ///
  /// In en, this message translates to:
  /// **'another device'**
  String get activeCallPillPlatformOther;

  /// All-caps header of the pinned-messages bottom sheet when there are currently zero pins in the room.
  ///
  /// In en, this message translates to:
  /// **'PINNED'**
  String get activeCallPillPinnedHeader;

  /// All-caps header of the pinned-messages bottom sheet showing how many messages are pinned in this room, e.g. 'PINNED · 3'.
  ///
  /// In en, this message translates to:
  /// **'PINNED · {count}'**
  String activeCallPillPinnedHeaderCount(Object count);

  /// Lowercase empty-state sentence fragment shown inside the pinned-messages sheet if the last pin gets removed while the sheet is still open.
  ///
  /// In en, this message translates to:
  /// **'nothing pinned anymore'**
  String get activeCallPillNothingPinned;

  /// Accessibility semanticLabel on a tappable row in the pinned-messages sheet; tapping scrolls the chat transcript to that pinned message. {name} is the sender's display name.
  ///
  /// In en, this message translates to:
  /// **'Jump to message from {name}'**
  String activeCallPillJumpToMessageSemanticLabel(Object name);

  /// Accessibility semanticLabel on the small unpin icon button next to each row in the pinned-messages sheet. {name} is the sender's display name.
  ///
  /// In en, this message translates to:
  /// **'Unpin message from {name}'**
  String activeCallPillUnpinMessageSemanticLabel(Object name);

  /// SnackBar message in CallButton._friendlyError when the callee is busy on another call (backend error contains BUSY).
  ///
  /// In en, this message translates to:
  /// **'busy on another call'**
  String get callButtonErrorBusy;

  /// SnackBar message in CallButton._friendlyError when the backend reports CALL_FAILED.
  ///
  /// In en, this message translates to:
  /// **'could not start call'**
  String get callButtonErrorCallFailed;

  /// SnackBar message in CallButton._friendlyError when the backend reports NOT_A_MEMBER.
  ///
  /// In en, this message translates to:
  /// **'not a member of this room'**
  String get callButtonErrorNotMember;

  /// Fallback SnackBar message in CallButton._friendlyError for any unrecognized call-start error.
  ///
  /// In en, this message translates to:
  /// **'could not start call'**
  String get callButtonErrorGeneric;

  /// Reason shown (via SnackBar) when the user taps a disabled CallButton while already in a call on this device.
  ///
  /// In en, this message translates to:
  /// **'You\'re already on a call'**
  String get callButtonAlreadyOnCall;

  /// Reason shown (via SnackBar) when the user taps a disabled CallButton while busy on another of their devices.
  ///
  /// In en, this message translates to:
  /// **'Call in progress on another device'**
  String get callButtonBusyElsewhere;

  /// Tooltip on the direct audio-call icon button/circle in the room header (CallButton _face helper).
  ///
  /// In en, this message translates to:
  /// **'voice call'**
  String get callButtonVoiceCallTooltip;

  /// Tooltip on the direct video-call icon button/circle in the room header (CallButton _face helper).
  ///
  /// In en, this message translates to:
  /// **'video call'**
  String get callButtonVideoCallTooltip;

  /// Tooltip on the combined call-picker icon button/circle (opens a Voice/Video call chooser) shown on narrow headers.
  ///
  /// In en, this message translates to:
  /// **'call'**
  String get callButtonTooltip;

  /// Lowercase display-fragment page heading on the reply-style picker screen (ReplyStyleScreen).
  ///
  /// In en, this message translates to:
  /// **'reply style.'**
  String get callButtonReplyStyleTitle;

  /// Caption line under the reply-style screen title, explaining what the picker controls.
  ///
  /// In en, this message translates to:
  /// **'how a reply shows its parent'**
  String get callButtonReplyStyleSubtitle;

  /// ALL-CAPS card title naming the 'phantom echo' reply-preview visual style option.
  ///
  /// In en, this message translates to:
  /// **'PHANTOM ECHO'**
  String get callButtonReplyStylePhantomEchoLabel;

  /// Lowercase descriptive sentence under the PHANTOM ECHO reply-style card explaining how it looks.
  ///
  /// In en, this message translates to:
  /// **'a ghost-bubble of the parent floats above with a curved connector and the branch icon at the join point.'**
  String get callButtonReplyStylePhantomEchoDescription;

  /// ALL-CAPS card title naming the 'sticky note' reply-preview visual style option.
  ///
  /// In en, this message translates to:
  /// **'STICKY NOTE'**
  String get callButtonReplyStyleStickyNoteLabel;

  /// Lowercase descriptive sentence under the STICKY NOTE reply-style card explaining how it looks.
  ///
  /// In en, this message translates to:
  /// **'a slightly rotated polaroid-style card clipped to the bubble corner.'**
  String get callButtonReplyStyleStickyNoteDescription;

  /// ALL-CAPS card title naming the 'comic tail' reply-preview visual style option.
  ///
  /// In en, this message translates to:
  /// **'COMIC TAIL'**
  String get callButtonReplyStyleComicTailLabel;

  /// Lowercase descriptive sentence under the COMIC TAIL reply-style card explaining how it looks.
  ///
  /// In en, this message translates to:
  /// **'a small parent mini-bubble with a comic-book triangle tail pointing down.'**
  String get callButtonReplyStyleComicTailDescription;

  /// ALL-CAPS card title naming the 'classic' (WhatsApp-style) reply-preview visual style option.
  ///
  /// In en, this message translates to:
  /// **'CLASSIC'**
  String get callButtonReplyStyleClassicLabel;

  /// Lowercase descriptive sentence under the CLASSIC reply-style card explaining how it looks.
  ///
  /// In en, this message translates to:
  /// **'accent-tinted quote pill with a tether bar and avatar — the familiar WhatsApp-style look.'**
  String get callButtonReplyStyleClassicDescription;

  /// Small ALL-CAPS badge on the currently-selected reply-style card in the picker.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get callButtonReplyStyleActiveBadge;

  /// Sample parent-message content shown inside the live reply-style preview bubble (demo content, not real user data).
  ///
  /// In en, this message translates to:
  /// **'hey did you see the new demo though?'**
  String get callButtonReplyPreviewSampleMessage;

  /// Sample reply-bubble text shown under the parent preview in the reply-style picker's live preview.
  ///
  /// In en, this message translates to:
  /// **'yeah, that blur is sick.'**
  String get callButtonReplyPreviewSampleReply;

  /// Inline error shown on the Add a Child form when the username field is left empty at submit time; also reused as the humanized message for a USERNAME_REQUIRED backend error.
  ///
  /// In en, this message translates to:
  /// **'Pick a username for them.'**
  String get childSetupScreenErrorPickUsername;

  /// Inline error on the Add a Child form when the backend reports the chosen username is already in use.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken.'**
  String get childSetupScreenErrorUsernameTaken;

  /// Inline error on the Add a Child form when the backend refuses account creation because the caller isn't a guardian/adult account.
  ///
  /// In en, this message translates to:
  /// **'Only a grown-up account can add a child.'**
  String get childSetupScreenErrorChildNotAllowed;

  /// Fallback inline error on the Add a Child form for any unrecognized failure creating the child account.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t create the account — try again.'**
  String get childSetupScreenErrorGeneric;

  /// All-caps header label next to the back arrow at the top of the Add a Child screen.
  ///
  /// In en, this message translates to:
  /// **'ADD A CHILD'**
  String get childSetupScreenTitle;

  /// Large lowercase two-line display heading on the Add a Child form, above the name/username fields, matching the app's terse fragment-style headings (e.g. 'settings.', 'reply style.').
  ///
  /// In en, this message translates to:
  /// **'who\nare they?'**
  String get childSetupScreenHeading;

  /// All-caps field label above the child's display-name text field on the Add a Child form.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get childSetupScreenNameLabel;

  /// Lowercase placeholder/hint text inside the child's name text field on the Add a Child form.
  ///
  /// In en, this message translates to:
  /// **'what you call them'**
  String get childSetupScreenNameHint;

  /// All-caps field label above the child's username text field on the Add a Child form.
  ///
  /// In en, this message translates to:
  /// **'USERNAME'**
  String get childSetupScreenUsernameLabel;

  /// Lowercase placeholder/hint text inside the child's username text field on the Add a Child form.
  ///
  /// In en, this message translates to:
  /// **'how friends find them'**
  String get childSetupScreenUsernameHint;

  /// All-caps section header above the bullet list explaining what a newly created child account can do, on the Add a Child form.
  ///
  /// In en, this message translates to:
  /// **'WHAT THEY GET'**
  String get childSetupScreenWhatTheyGetTitle;

  /// First bullet in the 'what they get' explainer list on the Add a Child form.
  ///
  /// In en, this message translates to:
  /// **'They can talk to you and their brothers and sisters right away.'**
  String get childSetupScreenBulletTalkImmediately;

  /// Second bullet in the 'what they get' explainer list on the Add a Child form, explaining the guardian-approval gate on new contacts.
  ///
  /// In en, this message translates to:
  /// **'Everyone else needs your OK first — both people they ask for, and people who ask for them.'**
  String get childSetupScreenBulletNeedsApproval;

  /// Third bullet in the 'what they get' explainer list on the Add a Child form.
  ///
  /// In en, this message translates to:
  /// **'Public rooms are switched off until you turn them on.'**
  String get childSetupScreenBulletPublicRoomsOff;

  /// Fourth bullet in the 'what they get' explainer list on the Add a Child form.
  ///
  /// In en, this message translates to:
  /// **'They can’t sign out, and you can always see how they’re doing.'**
  String get childSetupScreenBulletCantSignOut;

  /// All-caps primary submit-button label on the Add a Child form; creates the child account and proceeds straight to device pairing.
  ///
  /// In en, this message translates to:
  /// **'CREATE + PAIR'**
  String get childSetupScreenCreateButton;

  /// Screen-reader semantic label for a friend row in Discover; {name} is the friend's display name (user data, not translated). Tapping opens or starts a DM with them.
  ///
  /// In en, this message translates to:
  /// **'Message {name}'**
  String childSetupScreenFriendRowMessageSemanticLabel(Object name);

  /// Lowercase status-pill text shown on a public-room tile in Discover when a child has already asked a grown-up for approval to join that room.
  ///
  /// In en, this message translates to:
  /// **'asked'**
  String get childSetupScreenWaitingPillAskedLabel;

  /// Short all-caps unit label next to the numeric member count on a public-room tile in Discover (e.g. '42 IN'). Translated as the Turkish word for 'member' since a literal preposition doesn't read naturally as a compact badge unit in Turkish.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get childSetupScreenMemberCountUnitLabel;

  /// Lowercase visible label on the trailing row of a capped preview list in Discover (e.g. friends/rooms), showing the full count; {count} is the total number of items.
  ///
  /// In en, this message translates to:
  /// **'see all {count}'**
  String childSetupScreenSeeAllLabel(Object count);

  /// Screen-reader semantic label for the same 'see all' row in Discover's capped preview list; {count} is the total number of items.
  ///
  /// In en, this message translates to:
  /// **'See all {count}'**
  String childSetupScreenSeeAllSemanticLabel(Object count);

  /// Display heading at the top of the bubble style picker screen (lowercase sentence-fragment style, matches other settings detail screens).
  ///
  /// In en, this message translates to:
  /// **'bubble style.'**
  String get bubbleStyleScreenTitle;

  /// Caption line under the bubble style screen title, next to a small accent divider.
  ///
  /// In en, this message translates to:
  /// **'the shape your words arrive in'**
  String get bubbleStyleScreenSubtitle;

  /// All-caps option label for the 'tailed' bubble style card.
  ///
  /// In en, this message translates to:
  /// **'TAILED'**
  String get bubbleStyleScreenTailedLabel;

  /// Small mono-caption description under the TAILED option card, explaining the visual behavior.
  ///
  /// In en, this message translates to:
  /// **'a tail closes each run of messages; the rows above it tighten into one block.'**
  String get bubbleStyleScreenTailedDescription;

  /// All-caps option label for the 'soft' bubble style card.
  ///
  /// In en, this message translates to:
  /// **'SOFT'**
  String get bubbleStyleScreenSoftLabel;

  /// Small mono-caption description under the SOFT option card, explaining the visual behavior.
  ///
  /// In en, this message translates to:
  /// **'no tail — a run holds together through its tightened inner corners alone.'**
  String get bubbleStyleScreenSoftDescription;

  /// All-caps option label for the 'pill' bubble style card.
  ///
  /// In en, this message translates to:
  /// **'PILL'**
  String get bubbleStyleScreenPillLabel;

  /// Small mono-caption description under the PILL option card, explaining the visual behavior.
  ///
  /// In en, this message translates to:
  /// **'fully rounded capsules, identical on every row.'**
  String get bubbleStyleScreenPillDescription;

  /// All-caps option label for the 'slab' bubble style card.
  ///
  /// In en, this message translates to:
  /// **'SLAB'**
  String get bubbleStyleScreenSlabLabel;

  /// Small mono-caption description under the SLAB option card, explaining the visual behavior.
  ///
  /// In en, this message translates to:
  /// **'square shoulders — sharp, printed, deliberate.'**
  String get bubbleStyleScreenSlabDescription;

  /// Small all-caps badge shown next to the currently selected bubble style card.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get bubbleStyleScreenActiveBadge;

  /// First line of the sample three-message preview shown inside each style card — an incoming message from the other person.
  ///
  /// In en, this message translates to:
  /// **'so? how does it look'**
  String get bubbleStyleScreenPreviewQuestion;

  /// Second line of the sample preview conversation — first outgoing message in a two-message run.
  ///
  /// In en, this message translates to:
  /// **'better'**
  String get bubbleStyleScreenPreviewReplyOne;

  /// Third line of the sample preview conversation — second/last outgoing message in the run.
  ///
  /// In en, this message translates to:
  /// **'much better'**
  String get bubbleStyleScreenPreviewReplyTwo;

  /// Accessibility semanticLabel read by screen readers for a video tile in the shared-media grid.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get bubbleStyleScreenMediaTileVideoSemanticLabel;

  /// Accessibility semanticLabel read by screen readers for a photo tile in the shared-media grid.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get bubbleStyleScreenMediaTilePhotoSemanticLabel;

  /// SnackBar error shown when joining an incoming group call fails because it already has the maximum number of participants.
  ///
  /// In en, this message translates to:
  /// **'That call is full (max 6 people)'**
  String get incomingGroupCallScreenCallFullError;

  /// SnackBar error shown when joining an incoming group call fails for any reason other than the call being full.
  ///
  /// In en, this message translates to:
  /// **'Could not join the call'**
  String get incomingGroupCallScreenJoinFailedError;

  /// Fallback room-name heading on the incoming group call screen, used while the invite payload's real room name hasn't loaded yet.
  ///
  /// In en, this message translates to:
  /// **'Group call'**
  String get incomingGroupCallScreenDefaultRoomName;

  /// Fallback caller name on the incoming group call screen, used while the invite payload's starter name hasn't loaded yet.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get incomingGroupCallScreenDefaultStarterName;

  /// Caption on the incoming group call screen for a video-type invite; {starter} is the caller's display name.
  ///
  /// In en, this message translates to:
  /// **'{starter} started a video call'**
  String incomingGroupCallScreenStartedVideoCall(Object starter);

  /// Caption on the incoming group call screen for a voice-type invite; {starter} is the caller's display name.
  ///
  /// In en, this message translates to:
  /// **'{starter} started a voice call'**
  String incomingGroupCallScreenStartedVoiceCall(Object starter);

  /// Appended (after ' · ') to the started-call caption when more than one person is already on the call; {count} is how many are already in. Plain interpolation, not ICU plural — it is only ever shown when count > 1.
  ///
  /// In en, this message translates to:
  /// **'{count} already in'**
  String incomingGroupCallScreenAlreadyJoinedCount(Object count);

  /// Label under the round button that declines/dismisses the incoming group call invite.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get incomingGroupCallScreenDismissButton;

  /// Label under the round button that joins the incoming group call.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get incomingGroupCallScreenJoinButton;

  /// Count of shared DM chats, used inside the remove-contact confirmation sheet's deletion summary line.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} chat} other{{count} chats}}'**
  String incomingGroupCallScreenRemoveContactSheetChatsCount(num count);

  /// Count of messages that would be deleted; used in the remove-contact sheet's deletion summary line and the destructive choice tile's subtitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} message} other{{count} messages}}'**
  String incomingGroupCallScreenRemoveContactSheetMessagesCount(num count);

  /// Recency caption in the remove-contact sheet when the pair's last shared message was sent under an hour ago.
  ///
  /// In en, this message translates to:
  /// **'last message just now'**
  String get incomingGroupCallScreenRemoveContactSheetLastMessageJustNow;

  /// Recency caption in the remove-contact sheet when the last message was sent 1-23 hours ago; {hours} is the whole-hour count.
  ///
  /// In en, this message translates to:
  /// **'last message {hours}h ago'**
  String incomingGroupCallScreenRemoveContactSheetLastMessageHoursAgo(
    Object hours,
  );

  /// Recency caption in the remove-contact sheet when the last message was sent exactly one day ago.
  ///
  /// In en, this message translates to:
  /// **'last message yesterday'**
  String get incomingGroupCallScreenRemoveContactSheetLastMessageYesterday;

  /// Recency caption in the remove-contact sheet when the last message was sent 2-29 days ago; {days} is the day count.
  ///
  /// In en, this message translates to:
  /// **'last message {days} days ago'**
  String incomingGroupCallScreenRemoveContactSheetLastMessageDaysAgo(
    Object days,
  );

  /// Recency caption in the remove-contact sheet when the last shared message is 30+ days old.
  ///
  /// In en, this message translates to:
  /// **'last message a while ago'**
  String get incomingGroupCallScreenRemoveContactSheetLastMessageAWhileAgo;

  /// All-caps eyebrow label at the top of the remove-contact confirmation sheet; also reused verbatim as the destructive choice tile's title when there are no shared chats to delete.
  ///
  /// In en, this message translates to:
  /// **'TAKE BACK'**
  String get incomingGroupCallScreenRemoveContactSheetTitleBadge;

  /// Lowercase confirmation headline in the remove-contact sheet; {contactName} is the contact being removed, {childName} is the child they're being removed from. IMPORTANT for the merge/codegen step: since no ARB placeholder metadata is declared, flutter gen-l10n alphabetizes undeclared placeholders for the generated method's positional parameter order — for this message that means the generated signature is (childName, contactName), i.e. 'childName' first because it sorts before 'contactName'. The call site in remove_contact_sheet.dart already passes arguments in that (childName, contactName) order — keep it that way after merge.
  ///
  /// In en, this message translates to:
  /// **'take {contactName} away from {childName}?'**
  String incomingGroupCallScreenRemoveContactSheetHeadline(
    Object childName,
    Object contactName,
  );

  /// Explanatory body text in the remove-contact sheet, shown when the pair has shared chats that will be deleted.
  ///
  /// In en, this message translates to:
  /// **'they won’t be able to reach each other, and their conversation goes with it.'**
  String get incomingGroupCallScreenRemoveContactSheetBodyWithChats;

  /// Explanatory body text in the remove-contact sheet, shown when the pair has no shared chats to delete; {contactName} is the contact being removed.
  ///
  /// In en, this message translates to:
  /// **'they won’t be able to reach each other. {contactName} won’t be told.'**
  String incomingGroupCallScreenRemoveContactSheetBodyWithoutChats(
    Object contactName,
  );

  /// Bold summary line inside the destructive-warning box in the remove-contact sheet. {chats} and {messages} are the already-localized chat-count / message-count phrases (from incomingGroupCallScreenRemoveContactSheetChatsCount / MessagesCount), not raw numbers. 'chats' sorts before 'messages' alphabetically so no parameter-order gotcha here — call order matches text order.
  ///
  /// In en, this message translates to:
  /// **'{chats} · {messages} will be deleted'**
  String incomingGroupCallScreenRemoveContactSheetDeletionSummary(
    Object chats,
    Object messages,
  );

  /// Fine-print detail line under the deletion summary in the remove-contact sheet's destructive-warning box.
  ///
  /// In en, this message translates to:
  /// **'gone for both of them, including photos and voice notes. this can’t be undone.'**
  String get incomingGroupCallScreenRemoveContactSheetDeletionDetail;

  /// Headline over the panel listing group rooms the pair still shares after the contact is removed (these rooms are NOT deleted by this action); {count} is how many rooms.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{they also share {count} room} other{they also share {count} rooms}}'**
  String incomingGroupCallScreenRemoveContactSheetSharedRoomsHeadline(
    num count,
  );

  /// Note under the shared-rooms panel explaining that shared group rooms survive this action; 'ROOMS'/'ODALAR' refers to the app's Rooms list/tab label elsewhere in the UI.
  ///
  /// In en, this message translates to:
  /// **'these stay. take the room back from the ROOMS list below if you want them out of it.'**
  String get incomingGroupCallScreenRemoveContactSheetSharedRoomsNote;

  /// All-caps title of the destructive confirm button in the remove-contact sheet, shown when removing the contact also wipes shared chat history.
  ///
  /// In en, this message translates to:
  /// **'TAKE BACK & DELETE'**
  String get incomingGroupCallScreenRemoveContactSheetChoiceTitleWithDelete;

  /// Subtitle under the destructive confirm button when there is chat history to wipe; {contactName} is the contact being removed, {messages} is the pre-formatted message-count phrase. 'contactName' sorts before 'messages' alphabetically so call order matches text order.
  ///
  /// In en, this message translates to:
  /// **'removes {contactName} and wipes {messages}.'**
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithChats(
    Object contactName,
    Object messages,
  );

  /// Subtitle under the destructive confirm button when there is no chat history to wipe; {contactName} is the contact being removed.
  ///
  /// In en, this message translates to:
  /// **'removes {contactName} from the allowed list.'**
  String incomingGroupCallScreenRemoveContactSheetChoiceSubWithoutChats(
    Object contactName,
  );

  /// Screen-reader semantic label for the cancel control at the bottom of the remove-contact sheet.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get incomingGroupCallScreenRemoveContactSheetCancelSemanticLabel;

  /// All-caps visible label of the cancel button at the bottom of the remove-contact sheet.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get incomingGroupCallScreenRemoveContactSheetCancelButton;

  /// Snackbar error shown in the group call banner when the user tries to join a call that has reached its 6-person cap.
  ///
  /// In en, this message translates to:
  /// **'That call is full (max 6 people)'**
  String get groupCallBannerCallFullError;

  /// Snackbar error shown in the group call banner when joining an ongoing call fails for any other reason.
  ///
  /// In en, this message translates to:
  /// **'Could not join the call'**
  String get groupCallBannerJoinFailedError;

  /// Fallback display name in the group call banner's participant list when a participant record has no name.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get groupCallBannerUnknownParticipant;

  /// Title text in the group call banner when the active room call is a video call.
  ///
  /// In en, this message translates to:
  /// **'Ongoing video call'**
  String get groupCallBannerOngoingVideoCall;

  /// Title text in the group call banner when the active room call is a voice-only call.
  ///
  /// In en, this message translates to:
  /// **'Ongoing voice call'**
  String get groupCallBannerOngoingVoiceCall;

  /// Subtitle in the group call banner listing who's currently in the call, e.g. "Alice, Bob +3 in the call". {names} is a comma-joined list of participant names, {extra} is an optional " +N" overflow count (both may already contain leading formatting).
  ///
  /// In en, this message translates to:
  /// **'{names}{extra} in the call'**
  String groupCallBannerParticipantsInCall(Object extra, Object names);

  /// Screen-reader semantic label for the JOIN pill button in the ongoing-call banner.
  ///
  /// In en, this message translates to:
  /// **'Join call'**
  String get groupCallBannerJoinCallSemanticLabel;

  /// All-caps label on the pill button in the group call banner that joins the ongoing call.
  ///
  /// In en, this message translates to:
  /// **'JOIN'**
  String get groupCallBannerJoinButtonLabel;

  /// All-caps section header at the top of the join-room confirmation bottom sheet.
  ///
  /// In en, this message translates to:
  /// **'JOIN ROOM'**
  String get groupCallBannerJoinRoomSheetTitle;

  /// Member count shown under the room name in the join-room confirmation sheet, e.g. "12 members".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
  String groupCallBannerMemberCount(num count);

  /// All-caps field label above the password input in the join-room sheet for locked rooms.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get groupCallBannerPasswordFieldLabel;

  /// Placeholder hint text inside the password field on the join-room sheet.
  ///
  /// In en, this message translates to:
  /// **'passphrase…'**
  String get groupCallBannerPasswordHint;

  /// Screen-reader semantic label for the confirm-join button on the join-room sheet.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get groupCallBannerJoinRoomButtonSemanticLabel;

  /// All-caps label on the main confirm button in the join-room sheet.
  ///
  /// In en, this message translates to:
  /// **'JOIN'**
  String get groupCallBannerJoinRoomButtonLabel;

  /// Screen-reader semantic label for the dismiss/cancel button on the join-room sheet.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get groupCallBannerCancelButtonSemanticLabel;

  /// Lowercase text button that dismisses the join-room sheet without joining.
  ///
  /// In en, this message translates to:
  /// **'cancel'**
  String get groupCallBannerCancelButtonLabel;

  /// All-caps badge label in the fullscreen view-once photo viewer, shown beside a '1' marker, telling the user this photo can only be viewed once and will not be shown again.
  ///
  /// In en, this message translates to:
  /// **'VIEW ONCE'**
  String get viewOnceViewerBadgeLabel;

  /// Divider word between the Apple and Google 'continue with' buttons on sign-in/login screens (default value of SocialSignInButtons.dividerLabel when the caller doesn't override it).
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get socialButtonDividerOr;

  /// Visible label and screen-reader semanticLabel on the app's own themed 'Continue with Google' button.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get socialButtonGoogleContinue;

  /// Lowercase fragment-style heading at the top of the full people list screen (opened from Discover's "see all" row).
  ///
  /// In en, this message translates to:
  /// **'your people.'**
  String get discoverListsPeopleTitle;

  /// Caption under the people-list title showing how many friends the user has, e.g. "12 people".
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} person} other{{count} people}}'**
  String discoverListsPeopleCount(num count);

  /// Hint text in the search/filter TextField on the full people list screen.
  ///
  /// In en, this message translates to:
  /// **'filter your people…'**
  String get discoverListsFilterHint;

  /// Screen-reader semantic label for the small close/clear icon button that resets the people-list filter field.
  ///
  /// In en, this message translates to:
  /// **'Clear filter'**
  String get discoverListsClearFilterSemanticLabel;

  /// Empty-state line shown on the people list when the user has zero friends.
  ///
  /// In en, this message translates to:
  /// **'no one yet'**
  String get discoverListsNoOneYet;

  /// Empty-state line shown when the user's filter text on the people list matches no friends; {query} is the text they typed.
  ///
  /// In en, this message translates to:
  /// **'no one matches \"{query}\"'**
  String discoverListsNoMatches(Object query);

  /// All-caps action row label in the call-kind picker popover (choose voice vs video call).
  ///
  /// In en, this message translates to:
  /// **'VOICE CALL'**
  String get discoverListsVoiceCallLabel;

  /// All-caps action row label in the call-kind picker popover (choose voice vs video call).
  ///
  /// In en, this message translates to:
  /// **'VIDEO CALL'**
  String get discoverListsVideoCallLabel;

  /// All-caps header badge in the approval-gate sheet when the child has already sent an approval request for this action.
  ///
  /// In en, this message translates to:
  /// **'ALREADY ASKED'**
  String get approvalGateAlreadyAskedLabel;

  /// All-caps header badge in the approval-gate sheet prompting the child to ask a guardian before proceeding.
  ///
  /// In en, this message translates to:
  /// **'ASK A GROWN-UP'**
  String get approvalGateAskGrownUpLabel;

  /// Main body sentence in the approval-gate sheet when a request is already pending; {what} is the localized action phrase passed by the caller (e.g. "send messages").
  ///
  /// In en, this message translates to:
  /// **'You already asked about {what}.'**
  String approvalGateAlreadyAskedBody(Object what);

  /// Main body sentence in the approval-gate sheet explaining a grown-up must approve before the child can do {what}.
  ///
  /// In en, this message translates to:
  /// **'You need a grown-up to say yes before you can {what}.'**
  String approvalGateNeedApprovalBody(Object what);

  /// Main body sentence in the approval-gate sheet shown when the action is disabled outright and asking isn't even possible.
  ///
  /// In en, this message translates to:
  /// **'A grown-up has switched this off for now.'**
  String get approvalGateDisabledBody;

  /// Secondary/footer line in the approval-gate sheet when a request is already pending, reassuring the child it was sent.
  ///
  /// In en, this message translates to:
  /// **'They’ll get a message about it. Check back soon.'**
  String get approvalGateAlreadyAskedFooter;

  /// Secondary/footer line in the approval-gate sheet explaining what happens after the child taps ASK.
  ///
  /// In en, this message translates to:
  /// **'We’ll let them know. You’ll see it here when they answer.'**
  String get approvalGateWillNotifyFooter;

  /// Secondary/footer line in the approval-gate sheet shown when the action is disabled outright, suggesting the child talk to their guardian in person.
  ///
  /// In en, this message translates to:
  /// **'You can talk to them about it if you think it should change.'**
  String get approvalGateTalkToThemFooter;

  /// All-caps primary button label in the approval-gate sheet that sends the approval request.
  ///
  /// In en, this message translates to:
  /// **'ASK'**
  String get approvalGateAskButton;

  /// All-caps secondary button label in the approval-gate sheet that dismisses without sending a request, shown alongside the ASK button.
  ///
  /// In en, this message translates to:
  /// **'NOT NOW'**
  String get approvalGateNotNowButton;

  /// All-caps secondary button label in the approval-gate sheet used to dismiss when asking isn't offered (already asked or disabled outright).
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get approvalGateOkButton;

  /// Default lowercase caption on the small inline WaitingPill chip shown on a room/person row the child already asked about, used when the caller doesn't supply a more specific label.
  ///
  /// In en, this message translates to:
  /// **'waiting for a grown-up'**
  String get approvalGateWaitingPillLabel;

  /// All-caps small label at the top of the report sheet (report_sheet.dart).
  ///
  /// In en, this message translates to:
  /// **'REPORT'**
  String get reportSheetTitle;

  /// Lowercase display heading in the report sheet, right under the REPORT label.
  ///
  /// In en, this message translates to:
  /// **'tell us what’s wrong.'**
  String get reportSheetSubtitle;

  /// Reassurance line in the report sheet explaining reports are anonymous.
  ///
  /// In en, this message translates to:
  /// **'reports are private — the other person isn’t notified.'**
  String get reportSheetPrivacyNote;

  /// All-caps report-reason option label (report_sheet.dart). Underlying code value 'SPAM' is unchanged — only the displayed label is localized.
  ///
  /// In en, this message translates to:
  /// **'SPAM'**
  String get reportSheetReasonSpamLabel;

  /// Lowercase helper text under the SPAM report-reason option.
  ///
  /// In en, this message translates to:
  /// **'unwanted ads or repeated messages'**
  String get reportSheetReasonSpamDescription;

  /// All-caps report-reason option label (report_sheet.dart).
  ///
  /// In en, this message translates to:
  /// **'HARASSMENT'**
  String get reportSheetReasonHarassmentLabel;

  /// Lowercase helper text under the HARASSMENT report-reason option.
  ///
  /// In en, this message translates to:
  /// **'targeting or bullying'**
  String get reportSheetReasonHarassmentDescription;

  /// All-caps report-reason option label (report_sheet.dart).
  ///
  /// In en, this message translates to:
  /// **'IMPERSONATION'**
  String get reportSheetReasonImpersonationLabel;

  /// Lowercase helper text under the IMPERSONATION report-reason option.
  ///
  /// In en, this message translates to:
  /// **'pretending to be someone'**
  String get reportSheetReasonImpersonationDescription;

  /// All-caps report-reason option label (report_sheet.dart).
  ///
  /// In en, this message translates to:
  /// **'INAPPROPRIATE'**
  String get reportSheetReasonInappropriateLabel;

  /// Lowercase helper text under the INAPPROPRIATE report-reason option.
  ///
  /// In en, this message translates to:
  /// **'sexual, violent, or illegal content'**
  String get reportSheetReasonInappropriateDescription;

  /// All-caps report-reason option label (report_sheet.dart).
  ///
  /// In en, this message translates to:
  /// **'OTHER'**
  String get reportSheetReasonOtherLabel;

  /// Lowercase helper text under the OTHER report-reason option.
  ///
  /// In en, this message translates to:
  /// **'something else'**
  String get reportSheetReasonOtherDescription;

  /// Hint text in the free-form note field shown when OTHER is selected as report reason.
  ///
  /// In en, this message translates to:
  /// **'what happened?'**
  String get reportSheetOtherNoteHint;

  /// Screen-reader semanticLabel for the report sheet's submit button.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get reportSheetSubmitSemanticLabel;

  /// All-caps label on the report sheet's submit button.
  ///
  /// In en, this message translates to:
  /// **'SUBMIT'**
  String get reportSheetSubmitButton;

  /// All-caps title in update_sheet.dart shown when the running build is below minimum supported version (mandatory update).
  ///
  /// In en, this message translates to:
  /// **'UPDATE REQUIRED'**
  String get reportSheetUpdateRequiredTitle;

  /// All-caps title in update_sheet.dart shown for an optional app update.
  ///
  /// In en, this message translates to:
  /// **'UPDATE AVAILABLE'**
  String get reportSheetUpdateAvailableTitle;

  /// Body copy in the mandatory update sheet explaining why the update can't be skipped.
  ///
  /// In en, this message translates to:
  /// **'This version is too old to keep working properly. Update to carry on.'**
  String get reportSheetUpdateMandatoryBody;

  /// Body copy in the optional update sheet. MonkeyHub is the app's brand name and stays untranslated.
  ///
  /// In en, this message translates to:
  /// **'A newer version of MonkeyHub is available.'**
  String get reportSheetUpdateAvailableBody;

  /// Version-transition line in the update sheet, e.g. 'v1.3.9 → v1.3.10'. Placeholders are the running app version and the new release version; the format itself is language-neutral so the Turkish value is identical.
  ///
  /// In en, this message translates to:
  /// **'v{currentVersion} → v{newVersion}'**
  String reportSheetUpdateVersionArrow(
    Object currentVersion,
    Object newVersion,
  );

  /// All-caps primary button label in the update sheet.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get reportSheetUpdateButtonTitle;

  /// Subtext under the UPDATE button describing where it sends the user (TestFlight channel). TestFlight is Apple's product name, kept untranslated.
  ///
  /// In en, this message translates to:
  /// **'opens TestFlight'**
  String get reportSheetUpdateActionOpensTestflight;

  /// Subtext under the UPDATE button for the App Store release channel. App Store is Apple's product name, kept untranslated.
  ///
  /// In en, this message translates to:
  /// **'opens the App Store'**
  String get reportSheetUpdateActionOpensAppStore;

  /// Subtext under the UPDATE button for the Google Play release channel. Google Play is the product name, kept untranslated.
  ///
  /// In en, this message translates to:
  /// **'opens Google Play'**
  String get reportSheetUpdateActionOpensGooglePlay;

  /// Subtext under the UPDATE button for APK/DMG/Windows/Linux release channels.
  ///
  /// In en, this message translates to:
  /// **'opens the download page'**
  String get reportSheetUpdateActionOpensDownloadPage;

  /// Subtext under the UPDATE button for the web release channel.
  ///
  /// In en, this message translates to:
  /// **'reloads with the new version'**
  String get reportSheetUpdateActionReloads;

  /// Screen-reader semanticLabel for the update sheet's dismiss/skip action.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get reportSheetUpdateLaterSemanticLabel;

  /// All-caps label on the update sheet's secondary 'not now' button.
  ///
  /// In en, this message translates to:
  /// **'LATER'**
  String get reportSheetUpdateLaterButton;

  /// Label on the reset chip in RoomFilterBar (lib/widgets/room_filter_bar.dart) that clears all facet filters and shows every room; reads as active whenever no facet is selected.
  ///
  /// In en, this message translates to:
  /// **'all'**
  String get roomFilterBarAllChipLabel;

  /// Screen-reader semanticLabel for a facet chip in RoomFilterBar that has a room count attached (e.g. 'unread, 3 chats'); combines the facet's own display label with how many chats match it.
  ///
  /// In en, this message translates to:
  /// **'{label}, {count, plural, one{{count} chat} other{{count} chats}}'**
  String roomFilterBarChipCountSemanticLabel(num count, Object label);

  /// All-caps small label shown above the composer's reply-preview card, identifying whose message is being replied to. {name} is the sender's display name, already uppercased by the caller (Dart passes m.senderName.toUpperCase() as the argument), so no case-suffix is appended to the placeholder in either language.
  ///
  /// In en, this message translates to:
  /// **'REPLYING TO {name}'**
  String composerReplyCardReplyingToLabel(Object name);

  /// All-caps chip badge on a room card indicating the room requires a password to join.
  ///
  /// In en, this message translates to:
  /// **'LOCKED'**
  String get roomCardLockedBadge;

  /// Terse relative-time label on a room card when the last message was sent less than 30 seconds ago.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get roomCardTimeAgoJustNow;

  /// Terse relative-time label on a room card, e.g. '45s' meaning 45 seconds ago (seconds is an int).
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String roomCardTimeAgoSeconds(Object seconds);

  /// Terse relative-time label on a room card, e.g. '5m' meaning 5 minutes ago (minutes is an int).
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String roomCardTimeAgoMinutes(Object minutes);

  /// Terse relative-time label on a room card, e.g. '3h' meaning 3 hours ago (hours is an int).
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String roomCardTimeAgoHours(Object hours);

  /// Terse relative-time label on a room card, e.g. '2d' meaning 2 days ago (days is an int).
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String roomCardTimeAgoDays(Object days);

  /// Terse relative-time label on a room card, e.g. '3w' meaning 3 weeks ago (weeks is an int).
  ///
  /// In en, this message translates to:
  /// **'{weeks}w'**
  String roomCardTimeAgoWeeks(Object weeks);

  /// Timestamp on a room card that has no messages yet, e.g. 'started 3d ago'. {ago} is a pre-formatted relative time from the roomCardTimeAgo* strings.
  ///
  /// In en, this message translates to:
  /// **'started {ago}'**
  String roomCardStartedAgo(Object ago);

  /// Room card footer showing how many members are currently in a (non-DM) room, e.g. '5 inside' (count is an int).
  ///
  /// In en, this message translates to:
  /// **'{count} inside'**
  String roomCardMemberCount(Object count);

  /// Small tag next to an hourglass icon on an ephemeral room's card, indicating messages disappear over time.
  ///
  /// In en, this message translates to:
  /// **'messages fade'**
  String get roomCardMessagesFadeLabel;

  /// Terse call-to-action label at the bottom-right of a (non-ephemeral) room card, tap to enter the room.
  ///
  /// In en, this message translates to:
  /// **'↗ enter'**
  String get roomCardEnterLabel;

  /// All-caps header title on the Blocked Users screen listing people the current user has blocked.
  ///
  /// In en, this message translates to:
  /// **'BLOCKED'**
  String get roomCardBlockedScreenTitle;

  /// Empty-state copy on the Blocked Users screen when the user's block list is empty.
  ///
  /// In en, this message translates to:
  /// **'you haven’t blocked anyone.'**
  String get roomCardBlockedEmptyState;

  /// All-caps pill button on the Blocked Users screen list row to unblock that person.
  ///
  /// In en, this message translates to:
  /// **'UNBLOCK'**
  String get roomCardUnblockButton;

  /// Label under the photo/gallery icon in the attachment picker sheet (attachment_menu.dart).
  ///
  /// In en, this message translates to:
  /// **'photo'**
  String get attachmentMenuPhotoLabel;

  /// Label under the video icon in the attachment picker sheet (attachment_menu.dart).
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get attachmentMenuVideoLabel;

  /// Label under the camera icon in the attachment picker sheet (attachment_menu.dart).
  ///
  /// In en, this message translates to:
  /// **'camera'**
  String get attachmentMenuCameraLabel;

  /// Label under the voice-recording icon in the attachment picker sheet (attachment_menu.dart); tile is hidden on web.
  ///
  /// In en, this message translates to:
  /// **'voice'**
  String get attachmentMenuVoiceLabel;

  /// Label under the file icon in the attachment picker sheet (attachment_menu.dart).
  ///
  /// In en, this message translates to:
  /// **'file'**
  String get attachmentMenuFileLabel;

  /// Status text in the top-of-screen connection banner while a reconnect attempt is in flight (connection_banner.dart).
  ///
  /// In en, this message translates to:
  /// **'retrying…'**
  String get attachmentMenuConnectionRetrying;

  /// Status text in the connection banner when the socket is stalled and not currently retrying; tapping the banner retries (connection_banner.dart).
  ///
  /// In en, this message translates to:
  /// **'can’t reach server · tap to retry'**
  String get attachmentMenuConnectionCantReachServer;

  /// Status text in the connection banner during the general reconnecting phase (not yet stalled) (connection_banner.dart).
  ///
  /// In en, this message translates to:
  /// **'reconnecting…'**
  String get attachmentMenuConnectionReconnecting;

  /// Screen-reader semantic label for the tappable connection banner in its stalled state (connection_banner.dart).
  ///
  /// In en, this message translates to:
  /// **'Retry connection'**
  String get attachmentMenuConnectionRetrySemanticLabel;

  /// Placeholder subtitle on a room grid tile when the room has no last message yet.
  ///
  /// In en, this message translates to:
  /// **'quiet so far'**
  String get roomGridTileEmptyLastMessage;

  /// Short all-caps label following the numeric member count on a (non-DM) room grid tile, e.g. '5 IN'.
  ///
  /// In en, this message translates to:
  /// **'IN'**
  String get roomGridTileMemberCountLabel;

  /// All-caps label on the theme-picker chip (theme_chip.dart) that opens a swatch popover.
  ///
  /// In en, this message translates to:
  /// **'THEME'**
  String get roomGridTileThemeChipLabel;

  /// All-caps button label to dismiss the transcript multi-select bar without acting on the selection.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get bulkActionBarCancelLabel;

  /// All-caps placeholder shown in the multi-select bar's center when no messages are picked yet.
  ///
  /// In en, this message translates to:
  /// **'SELECT MESSAGES'**
  String get bulkActionBarSelectMessagesLabel;

  /// All-caps counter shown in the multi-select bar once at least one message is picked; {count} is the number selected.
  ///
  /// In en, this message translates to:
  /// **'{count} SELECTED'**
  String bulkActionBarSelectedCountLabel(num count);

  /// All-caps button label to forward the selected messages elsewhere.
  ///
  /// In en, this message translates to:
  /// **'FORWARD'**
  String get bulkActionBarForwardLabel;

  /// All-caps destructive button label to delete the selected messages.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get bulkActionBarDeleteLabel;

  /// All-caps pill label letting the reader jump back one hop to the message they jumped away from (single hop, no depth shown).
  ///
  /// In en, this message translates to:
  /// **'BACK'**
  String get bulkActionBarJumpBackLabel;

  /// All-caps pill label letting the reader jump back, shown when the jump trail is 2+ hops deep; {depth} is how many hops are queued.
  ///
  /// In en, this message translates to:
  /// **'BACK · {depth}'**
  String bulkActionBarJumpBackLabelWithDepth(Object depth);

  /// Screen-reader label for the jump-back pill when the trail is a single hop.
  ///
  /// In en, this message translates to:
  /// **'Back to where you jumped from'**
  String get bulkActionBarJumpBackSemanticLabel;

  /// Screen-reader label for the jump-back pill when the trail is 2+ hops deep; {depth} is how many hops remain.
  ///
  /// In en, this message translates to:
  /// **'Back to where you jumped from, {depth} to go'**
  String bulkActionBarJumpBackSemanticLabelWithDepth(Object depth);

  /// First sentence of the block-confirmation sheet's subtitle, always shown regardless of friend status.
  ///
  /// In en, this message translates to:
  /// **'they won’t be notified.'**
  String get bulkActionBarBlockSheetNotNotifiedNote;

  /// Second sentence of the block-confirmation sheet's subtitle, shown when the target is currently a friend.
  ///
  /// In en, this message translates to:
  /// **'you’re currently friends — blocking removes the friendship, so to reconnect later you’d have to send a new friend request.'**
  String get bulkActionBarBlockSheetFriendWarning;

  /// Second sentence of the block-confirmation sheet's subtitle, shown when the target is not currently a friend.
  ///
  /// In en, this message translates to:
  /// **'they’ll disappear from your search and can’t message you.'**
  String get bulkActionBarBlockSheetStrangerWarning;

  /// All-caps small section label at the top of the block-confirmation sheet, above the title.
  ///
  /// In en, this message translates to:
  /// **'BLOCK'**
  String get bulkActionBarBlockSheetHeaderLabel;

  /// Lowercase-fragment-style headline on the block-confirmation sheet asking the user to confirm; {name} is the target person's display name.
  ///
  /// In en, this message translates to:
  /// **'block {name}?'**
  String bulkActionBarBlockSheetTitle(Object name);

  /// Headline of the shared-rooms warning panel on the block-confirmation sheet; {count} is the number of group rooms shared with the target.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{you share {count} room with them} other{you share {count} rooms with them}}'**
  String bulkActionBarBlockSheetSharedRoomsHeadline(num count);

  /// Body note under the shared-rooms warning panel on the block-confirmation sheet.
  ///
  /// In en, this message translates to:
  /// **'these rooms stay untouched. you can leave any of them yourself from each room’s settings.'**
  String get bulkActionBarBlockSheetSharedRoomsNote;

  /// All-caps title of the first choice tile on the block-confirmation sheet — block without deleting the DM.
  ///
  /// In en, this message translates to:
  /// **'BLOCK'**
  String get bulkActionBarBlockChoiceTileTitle;

  /// Subtitle of the block-only choice tile, shown when the target is currently a friend.
  ///
  /// In en, this message translates to:
  /// **'remove friendship and block. existing chat history stays in your archive.'**
  String get bulkActionBarBlockChoiceTileFriendSub;

  /// Subtitle of the block-only choice tile, shown when the target is not currently a friend.
  ///
  /// In en, this message translates to:
  /// **'they’re hidden from search and can’t reach you.'**
  String get bulkActionBarBlockChoiceTileStrangerSub;

  /// All-caps title of the second choice tile on the block-confirmation sheet, shown only when a DM with the target exists — blocks and wipes the DM.
  ///
  /// In en, this message translates to:
  /// **'BLOCK & DELETE DM'**
  String get bulkActionBarBlockDeleteDmTitle;

  /// Subtitle of the block-and-delete-DM choice tile.
  ///
  /// In en, this message translates to:
  /// **'also wipes your DM with them — every message, reaction, and media file is gone.'**
  String get bulkActionBarBlockDeleteDmSub;

  /// Screen-reader label for the cancel control at the bottom of the block-confirmation sheet.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bulkActionBarBlockSheetCancelSemanticLabel;

  /// All-caps visible label for the cancel control at the bottom of the block-confirmation sheet.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get bulkActionBarBlockSheetCancelLabel;

  /// Title of the Android pre-prompt dialog asking the user to enable full-screen-intent notifications for incoming calls.
  ///
  /// In en, this message translates to:
  /// **'Show calls on the lock screen'**
  String get bulkActionBarFullScreenIntentDialogTitle;

  /// Body copy of the Android full-screen-intent pre-prompt dialog explaining why the permission is needed.
  ///
  /// In en, this message translates to:
  /// **'To ring like a real phone call when your screen is off, MonkeyHub needs \"full-screen notifications\" turned on. The next screen takes you straight to the switch.'**
  String get bulkActionBarFullScreenIntentDialogBody;

  /// Title of the Android pre-prompt dialog asking the user to exempt the app from battery optimization.
  ///
  /// In en, this message translates to:
  /// **'Never miss a call'**
  String get bulkActionBarBatteryExemptionDialogTitle;

  /// Body copy of the Android battery-optimization pre-prompt dialog explaining why the exemption is needed.
  ///
  /// In en, this message translates to:
  /// **'Some phones pause apps in the background to save battery, which can silence incoming calls. Allow MonkeyHub to run unrestricted so calls always come through.'**
  String get bulkActionBarBatteryExemptionDialogBody;

  /// Decline button label shared by both Android reliability pre-prompt dialogs (full-screen-intent and battery exemption).
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get bulkActionBarDialogNotNowButton;

  /// Accept button label shared by both Android reliability pre-prompt dialogs, proceeds to the system settings screen.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get bulkActionBarDialogContinueButton;

  /// All-caps label on the floating glass pill (scroll_to_latest.dart) that jumps the reader back to the newest message in a reversed chat transcript.
  ///
  /// In en, this message translates to:
  /// **'JUMP TO LATEST'**
  String get reactionBubbleJumpToLatestLabel;

  /// Screen-reader semantic label for the same jump-to-latest pill (scroll_to_latest.dart).
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get reactionBubbleJumpToLatestSemanticLabel;

  /// All-caps header at the top of the emoji reaction picker bottom sheet (reaction_picker_sheet.dart), reached via the + button on the floating reaction pill.
  ///
  /// In en, this message translates to:
  /// **'REACT'**
  String get reactionBubblePickerTitle;

  /// Lowercase placeholder shown in the emoji picker's Recents tab when the user hasn't picked any emoji yet (reaction_picker_sheet.dart).
  ///
  /// In en, this message translates to:
  /// **'no recents yet'**
  String get reactionBubbleNoRecentsPlaceholder;

  /// Lowercase hint text inside the password field on the password confirmation bottom sheet (password_prompt_sheet.dart), shown before linking/unlinking a social identity or similar sensitive account action.
  ///
  /// In en, this message translates to:
  /// **'password'**
  String get reactionBubblePasswordHint;

  /// Fed as the `what` argument into the shared approval-gate sheet (widgets/approval_gate.dart) when a child taps a public room they don't yet belong to; that sheet embeds it into its own localized sentence (e.g. 'want to {what}?'). {roomName} is the room's user-given name, interpolated as-is.
  ///
  /// In en, this message translates to:
  /// **'join {roomName}'**
  String enterPublicRoomJoinWhat(Object roomName);

  /// SnackBar shown to a child when their request to ask a guardian for permission to join a room fails to submit.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t ask right now — try again'**
  String get enterPublicRoomAskFailedMessage;

  /// SnackBar shown when joining a password-protected public room fails because the entered password was wrong.
  ///
  /// In en, this message translates to:
  /// **'wrong password'**
  String get enterPublicRoomWrongPasswordMessage;

  /// SnackBar shown when joining a public room fails for any reason other than a wrong password.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t join — try again'**
  String get enterPublicRoomJoinFailedMessage;

  /// All-caps wordmark in the masthead of the Feed tab's board, beside the app brand mark. Everything on the board is scoped to the current day, which is what this names.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get feedBoardTitle;

  /// Edition stamp at the right end of the Feed masthead's rule, like a newspaper issue number. {number} is the count of days since the Feed launched. '№' is the numero sign; substitute the conventional abbreviation for 'number' in your language if '№' is not used (e.g. 'No.', 'Nr.', '#').
  ///
  /// In en, this message translates to:
  /// **'№{number}'**
  String feedBoardEditionLabel(Object number);

  /// All-caps band label for the Feed section showing photos and videos friends captured today — a good sunset, a stray cat, anything worth a look.
  ///
  /// In en, this message translates to:
  /// **'HIGHLIGHTS'**
  String get feedBoardHighlightsLabel;

  /// Muted single line shown under the HIGHLIGHTS band when nobody, including the viewer, has posted a highlight today. Lowercase and conversational to match the app's other empty states.
  ///
  /// In en, this message translates to:
  /// **'nothing captured yet today'**
  String get feedBoardHighlightsEmpty;

  /// All-caps band label for the Feed section holding the once-a-day logic puzzle and everyone's scores.
  ///
  /// In en, this message translates to:
  /// **'THE PUZZLE'**
  String get feedBoardPuzzleLabel;

  /// Muted single line shown under THE PUZZLE band before the daily puzzle is available.
  ///
  /// In en, this message translates to:
  /// **'today\'s puzzle isn\'t ready yet'**
  String get feedBoardPuzzleEmpty;

  /// All-caps band label for the Feed section tallying the points friends award themselves for real-world moments.
  ///
  /// In en, this message translates to:
  /// **'LIFE POINTS'**
  String get feedBoardStandingsLabel;

  /// Muted single line shown under the STANDINGS band when nobody has awarded themselves a point today.
  ///
  /// In en, this message translates to:
  /// **'no points on the board today'**
  String get feedBoardStandingsEmpty;

  /// All-caps band label for the Feed's chronological list of everything friends did today.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY'**
  String get feedBoardActivityLabel;

  /// Muted single line shown under the ACTIVITY band when the viewer has friends but none of them have done anything today.
  ///
  /// In en, this message translates to:
  /// **'quiet so far today'**
  String get feedBoardActivityEmpty;

  /// Muted single line shown under the ACTIVITY band when the viewer has no friends yet — explains what would fill the section, rather than only reporting that it is empty.
  ///
  /// In en, this message translates to:
  /// **'add a friend and their day shows up here'**
  String get feedBoardActivityNoFriends;

  /// Board-level failure line shown above every section when the feed subscription errored and no payload ever arrived. Deliberately distinct from the per-section empty states, which mean 'nothing happened today' rather than 'this did not load'.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t load the board — try again in a moment'**
  String get feedBoardLoadFailed;

  /// All-caps badge label shown on a room card/chip when the room is public (widgets/visibility_badge.dart).
  ///
  /// In en, this message translates to:
  /// **'PUBLIC'**
  String get enterPublicRoomVisibilityPublicLabel;

  /// All-caps badge label shown on a room card/chip when the room is private (widgets/visibility_badge.dart).
  ///
  /// In en, this message translates to:
  /// **'PRIVATE'**
  String get enterPublicRoomVisibilityPrivateLabel;

  /// All-caps badge on a room card in Discover/search marking a room the viewer is already a member of.
  ///
  /// In en, this message translates to:
  /// **'JOINED'**
  String get enterPublicRoomJoinedBadgeLabel;

  /// Non-dense badge label for an ephemeral room, e.g. 'EPHEMERAL · 5m'. {duration} is a pre-formatted short string produced by enterPublicRoomEphemeralSecondsShort/MinutesShort/HoursShort.
  ///
  /// In en, this message translates to:
  /// **'EPHEMERAL · {duration}'**
  String enterPublicRoomEphemeralBadgeLabel(Object duration);

  /// Compact duration suffix for an ephemeral room's remaining time-to-live in seconds, e.g. '45s'. Also used standalone in the dense badge variant.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String enterPublicRoomEphemeralSecondsShort(Object seconds);

  /// Compact duration suffix for an ephemeral room's remaining time-to-live in minutes, e.g. '5m'. Also used standalone in the dense badge variant.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String enterPublicRoomEphemeralMinutesShort(Object minutes);

  /// Compact duration suffix for an ephemeral room's remaining time-to-live in hours, e.g. '2h'. Also used standalone in the dense badge variant.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String enterPublicRoomEphemeralHoursShort(Object hours);

  /// Tap-to-explain tooltip on the PUBLIC room badge (widgets/visibility_badge.dart).
  ///
  /// In en, this message translates to:
  /// **'Anyone can find this room and join it'**
  String get roomBadgePublicTooltip;

  /// Tap-to-explain tooltip on the PRIVATE room badge (widgets/visibility_badge.dart). Never shown for DMs.
  ///
  /// In en, this message translates to:
  /// **'Invite only — it won\'t show up in Discover'**
  String get roomBadgePrivateTooltip;

  /// Tap-to-explain tooltip on the LOCKED room badge, shown when the room needs a password to join.
  ///
  /// In en, this message translates to:
  /// **'You\'ll need the room password to join'**
  String get roomBadgeLockedTooltip;

  /// Tap-to-explain tooltip on the ephemeral room badge. {duration} is a pre-formatted short string like '5m', produced by enterPublicRoomEphemeralSecondsShort/MinutesShort/HoursShort.
  ///
  /// In en, this message translates to:
  /// **'Messages disappear after {duration}'**
  String roomBadgeEphemeralTooltip(Object duration);

  /// Tap-to-explain tooltip on the JOINED badge in Discover/search, marking a room the viewer is already a member of.
  ///
  /// In en, this message translates to:
  /// **'You\'re already in this room'**
  String get roomBadgeJoinedTooltip;

  /// Section heading in the room info sheet, above the labelled lines describing the room's visibility, password and self-destruct settings. Rendered in caps.
  ///
  /// In en, this message translates to:
  /// **'THE DETAILS'**
  String get roomInfoSheetDetailsLabel;

  /// Stands in for the description in the room info sheet when the room's owner never wrote one. Quiet, lowercase.
  ///
  /// In en, this message translates to:
  /// **'no description yet'**
  String get roomInfoSheetNoDescription;

  /// Label on the room info sheet line whose body is the date the room was created. Rendered in caps.
  ///
  /// In en, this message translates to:
  /// **'CREATED'**
  String get roomInfoSheetCreatedLabel;

  /// All-caps section label above the capture-protection toggle row in settings (lib/widgets/capture_protection_toggle.dart).
  ///
  /// In en, this message translates to:
  /// **'SCREEN CAPTURE PROTECTION'**
  String get countBadgeCaptureProtectionLabel;

  /// Explanatory body text shown when capture protection is ON, on Android, under the SCREEN CAPTURE PROTECTION label.
  ///
  /// In en, this message translates to:
  /// **'screenshots + screen recording show as black to the system.'**
  String get countBadgeCaptureProtectionOnAndroidBody;

  /// Explanatory body text shown when capture protection is ON, on iOS/other platforms, under the SCREEN CAPTURE PROTECTION label.
  ///
  /// In en, this message translates to:
  /// **'screen recording + mirroring drops a privacy shield over the app.'**
  String get countBadgeCaptureProtectionOnIosBody;

  /// Explanatory body text shown when capture protection is OFF, under the SCREEN CAPTURE PROTECTION label.
  ///
  /// In en, this message translates to:
  /// **'screenshots and recordings work normally outside ephemeral rooms.'**
  String get countBadgeCaptureProtectionOffBody;

  /// Accent-colored note under the capture-protection toggle explaining ephemeral rooms always force protection on.
  ///
  /// In en, this message translates to:
  /// **'ephemeral (chamber of secrets) rooms always force this on regardless.'**
  String get countBadgeCaptureProtectionForcedNote;

  /// IconButton tooltip on the eye icon in PasswordField when the password is currently hidden (tap reveals it).
  ///
  /// In en, this message translates to:
  /// **'show password'**
  String get countBadgeShowPasswordTooltip;

  /// IconButton tooltip on the eye icon in PasswordField when the password is currently visible (tap hides it).
  ///
  /// In en, this message translates to:
  /// **'hide password'**
  String get countBadgeHidePasswordTooltip;

  /// All-caps heading shown inside the full-screen capture shield overlay (lib/widgets/capture_shield.dart) when screen recording is detected.
  ///
  /// In en, this message translates to:
  /// **'PROTECTED'**
  String get countBadgeProtectedLabel;

  /// Body text in the capture shield overlay explaining why the blur shield appeared.
  ///
  /// In en, this message translates to:
  /// **'screen recording or mirroring is active.'**
  String get countBadgeCaptureShieldActiveBody;

  /// Reassurance line in the capture shield overlay, shown below the active-recording message.
  ///
  /// In en, this message translates to:
  /// **'the recording can\'t see your conversations.'**
  String get countBadgeCaptureShieldReassurance;

  /// SnackBar message shown when a tapped link fails to open in both the Custom Tabs/SafariViewController surface and the external-launch fallback (lib/services/link_opener.dart, LinkOpener.open).
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get linkOpenerCouldNotOpenLink;

  /// Screen-reader semanticLabel on the tappable recovery-phrase warning banner (lib/widgets/recovery_banner.dart, RecoveryPhraseBanner) shown when an account has no recovery phrase set.
  ///
  /// In en, this message translates to:
  /// **'Set up a recovery phrase'**
  String get linkOpenerRecoveryBannerSemanticLabel;

  /// Body copy inside the same recovery-phrase warning banner, lowercase sentence-fragment style, telling the user they risk permanent lockout without a recovery phrase set.
  ///
  /// In en, this message translates to:
  /// **'no recovery phrase — you could not get back in.'**
  String get linkOpenerRecoveryBannerMessage;

  /// Nav label for the Chat section, shown under the icon in the bottom pill / side rail.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get destinationsChatLabel;

  /// All-caps short form of the Chat nav destination — screen-reader label for the icon-only radial menu (the fan is icon-only, this string is never drawn, only announced).
  ///
  /// In en, this message translates to:
  /// **'CHAT'**
  String get destinationsChatShort;

  /// Nav label for the Discover section (rooms/people search).
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get destinationsDiscoverLabel;

  /// All-caps short form of the Discover nav destination — screen-reader-only label for the radial menu.
  ///
  /// In en, this message translates to:
  /// **'FIND'**
  String get destinationsDiscoverShort;

  /// Nav label for the Feed section.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get destinationsFeedLabel;

  /// All-caps short form of the Feed nav destination — screen-reader-only label for the radial menu.
  ///
  /// In en, this message translates to:
  /// **'FEED'**
  String get destinationsFeedShort;

  /// Nav label for the Settings section.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get destinationsSettingsLabel;

  /// All-caps short form of the Settings nav destination — screen-reader-only label for the radial menu.
  ///
  /// In en, this message translates to:
  /// **'SET'**
  String get destinationsSettingsShort;

  /// Status pill shown to the SENDER of a friend/room request while it awaits the recipient's guardian's approval. Deliberately vague about which side — never discloses that the recipient is a child.
  ///
  /// In en, this message translates to:
  /// **'waiting for a grown-up'**
  String get familyRequestStageSenderGuardianLabel;

  /// Status pill shown to the sender while the request awaits the recipient (adult) or the recipient's own decision after their guardian already approved. Deliberately vague, same string covers both cases.
  ///
  /// In en, this message translates to:
  /// **'waiting for them'**
  String get familyRequestStageRecipientLabel;

  /// All-caps pill-nav tab label for the Media bucket in the shared-content browser.
  ///
  /// In en, this message translates to:
  /// **'MEDIA'**
  String get roomContentTabLabelMedia;

  /// All-caps pill-nav tab label for the Files bucket in the shared-content browser.
  ///
  /// In en, this message translates to:
  /// **'FILES'**
  String get roomContentTabLabelFiles;

  /// All-caps pill-nav tab label for the Voice notes bucket in the shared-content browser.
  ///
  /// In en, this message translates to:
  /// **'VOICE'**
  String get roomContentTabLabelVoice;

  /// All-caps pill-nav tab label for the Links bucket in the shared-content browser.
  ///
  /// In en, this message translates to:
  /// **'LINKS'**
  String get roomContentTabLabelLinks;

  /// Lowercase form of the Media tab name, used in the shared-content screen's large heading (app's lowercase heading voice, e.g. 'settings.').
  ///
  /// In en, this message translates to:
  /// **'media'**
  String get roomContentTabHeaderMedia;

  /// Lowercase form of the Files tab name, used in the shared-content screen's large heading.
  ///
  /// In en, this message translates to:
  /// **'files'**
  String get roomContentTabHeaderFiles;

  /// Lowercase form of the Voice tab name, used in the shared-content screen's large heading.
  ///
  /// In en, this message translates to:
  /// **'voice'**
  String get roomContentTabHeaderVoice;

  /// Lowercase form of the Links tab name, used in the shared-content screen's large heading.
  ///
  /// In en, this message translates to:
  /// **'links'**
  String get roomContentTabHeaderLinks;

  /// Lowercase chip/filter label for the 'direct messages' (1:1 chat) facet in the chat-list filter bar/drawer.
  ///
  /// In en, this message translates to:
  /// **'dms'**
  String get roomFacetLabelDms;

  /// Lowercase chip/filter label for the 'group chat' facet.
  ///
  /// In en, this message translates to:
  /// **'groups'**
  String get roomFacetLabelGroups;

  /// Lowercase chip/filter label for the 'public room' visibility facet.
  ///
  /// In en, this message translates to:
  /// **'public'**
  String get roomFacetLabelPublic;

  /// Lowercase chip/filter label for the 'private room' visibility facet.
  ///
  /// In en, this message translates to:
  /// **'private'**
  String get roomFacetLabelPrivate;

  /// Lowercase chip/filter label for the 'secret/ephemeral room' facet.
  ///
  /// In en, this message translates to:
  /// **'secret'**
  String get roomFacetLabelSecret;

  /// Lowercase chip/filter label for the 'password-locked room' facet.
  ///
  /// In en, this message translates to:
  /// **'locked'**
  String get roomFacetLabelLocked;

  /// Lowercase chip/filter label for the 'has unread messages' status facet.
  ///
  /// In en, this message translates to:
  /// **'unread'**
  String get roomFacetLabelUnread;

  /// Lowercase chip/filter label for the 'has a mention of me' status facet.
  ///
  /// In en, this message translates to:
  /// **'mentions'**
  String get roomFacetLabelMentions;

  /// All-caps header at the top of the main Settings screen, next to the brand mark.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsScreenTitle;

  /// Lowercase sentence-fragment tagline under the Settings header, matching the app's other picker-screen headings (e.g. 'theme.', 'reply style.').
  ///
  /// In en, this message translates to:
  /// **'look. feel. you.'**
  String get settingsScreenTagline;

  /// Breadcrumb caption under a child account's name on the account card, listing what's reachable from there.
  ///
  /// In en, this message translates to:
  /// **'profile · privacy · my grown-ups'**
  String get settingsScreenAccountHintChild;

  /// Breadcrumb caption under an adult account's name on the account card, listing what's reachable from there.
  ///
  /// In en, this message translates to:
  /// **'profile · family · linked accounts · privacy'**
  String get settingsScreenAccountHintAdult;

  /// All-caps section header grouping Theme/App Logo/Glass rows.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get settingsScreenSectionAppearance;

  /// All-caps section header grouping the Chat List/Chat Style/Bubble Style/Reply Style rows.
  ///
  /// In en, this message translates to:
  /// **'CHAT'**
  String get settingsScreenSectionChat;

  /// All-caps section header grouping the Language row and the Check for Updates row.
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get settingsScreenSectionGeneral;

  /// All-caps label on the Settings row that manually re-runs the app update check against the backend.
  ///
  /// In en, this message translates to:
  /// **'CHECK FOR UPDATES'**
  String get settingsScreenCheckForUpdatesLabel;

  /// All-caps trailing value on the Check for Updates row when a newer build has been found (by either the launch check or a previous manual tap).
  ///
  /// In en, this message translates to:
  /// **'UPDATE AVAILABLE'**
  String get settingsScreenUpdateAvailableValue;

  /// SnackBar shown after a manual Check for Updates tap finds no newer build.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version.'**
  String get settingsScreenUpdateUpToDateSnackbar;

  /// SnackBar shown after a manual Check for Updates tap on a build with no meaningful "latest" to compare against (debug build, simulator, or an unrecognised channel).
  ///
  /// In en, this message translates to:
  /// **'Can\'t check for updates on this build.'**
  String get settingsScreenUpdateUnsupportedSnackbar;

  /// SnackBar shown after a manual Check for Updates tap fails (offline, backend unreachable).
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates. Try again later.'**
  String get settingsScreenUpdateErrorSnackbar;

  /// All-caps section header above the Push Notifications toggle.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get settingsScreenSectionNotifications;

  /// Settings row that opens the problem-report screen. Also the title of that screen.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportProblemRowLabel;

  /// Right-aligned hint on the Settings row for reporting a problem.
  ///
  /// In en, this message translates to:
  /// **'Send us the details'**
  String get reportProblemRowValue;

  /// Short paragraph at the top of the problem-report screen explaining what will be sent.
  ///
  /// In en, this message translates to:
  /// **'Tell us what went wrong. Your app and device details are included automatically, along with a technical log of what the app was doing — that\'s what helps us find the cause.'**
  String get reportProblemIntro;

  /// All-caps section header above the free-text field where the user describes the problem.
  ///
  /// In en, this message translates to:
  /// **'WHAT HAPPENED'**
  String get reportProblemDescribeLabel;

  /// Placeholder text inside the problem description field, giving examples of useful detail.
  ///
  /// In en, this message translates to:
  /// **'The screen flickers, buttons don\'t respond…'**
  String get reportProblemDescribeHint;

  /// All-caps section header above the optional screenshot attachments.
  ///
  /// In en, this message translates to:
  /// **'SCREENSHOTS'**
  String get reportProblemScreenshotsLabel;

  /// Button that opens the photo picker to attach a screenshot to the report.
  ///
  /// In en, this message translates to:
  /// **'Add screenshot'**
  String get reportProblemAddScreenshot;

  /// All-caps section header above the read-only device and account identifiers included in the report.
  ///
  /// In en, this message translates to:
  /// **'YOUR DETAILS'**
  String get reportProblemDetailsLabel;

  /// Button that copies the device and account identifiers to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy details'**
  String get reportProblemCopyDetails;

  /// Brief confirmation shown after copying the device details to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get reportProblemCopied;

  /// Primary button that sends the problem report. Tapping it uploads and delivers the report; there is no further confirmation step.
  ///
  /// In en, this message translates to:
  /// **'Send report'**
  String get reportProblemSend;

  /// Confirmation shown after the problem report has been sent successfully.
  ///
  /// In en, this message translates to:
  /// **'Report sent — thank you!'**
  String get reportProblemSent;

  /// Shown when sending the problem report failed for a technical reason, e.g. no connection.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the report. Check your connection and try again.'**
  String get reportProblemSendFailed;

  /// Shown when this device has filed too many problem reports in a short time and has to wait.
  ///
  /// In en, this message translates to:
  /// **'You\'ve sent a lot of reports just now. Please try again a bit later.'**
  String get reportProblemTooMany;

  /// Title of the sheet that appears when the user shakes the device, offering to open the problem-report screen.
  ///
  /// In en, this message translates to:
  /// **'Report a problem?'**
  String get reportProblemShakeTitle;

  /// Body of the shake-triggered sheet, explaining why it appeared.
  ///
  /// In en, this message translates to:
  /// **'You shook your phone. Open the report screen?'**
  String get reportProblemShakeBody;

  /// Confirm button on the shake sheet; opens the problem-report screen.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportProblemShakeOpen;

  /// Dismiss button on the shake sheet; closes it without opening the report screen.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get reportProblemShakeDismiss;

  /// Android-only settings row label for full-screen-intent access, which lets an incoming call take over the lock screen.
  ///
  /// In en, this message translates to:
  /// **'Lock screen calls'**
  String get settingsCallDeliveryLockScreenLabel;

  /// Android-only settings row label for the battery-optimization exemption that keeps the app awake enough to receive calls.
  ///
  /// In en, this message translates to:
  /// **'Background activity'**
  String get settingsCallDeliveryBackgroundLabel;

  /// Status shown on an Android call-delivery settings row when the OS permission is missing. Doubles as the call to action: tapping the row opens the system settings page.
  ///
  /// In en, this message translates to:
  /// **'Tap to allow'**
  String get settingsCallDeliveryStatusOff;

  /// All-caps row label that opens the Theme picker screen.
  ///
  /// In en, this message translates to:
  /// **'THEME'**
  String get settingsScreenRowTheme;

  /// All-caps row label that opens the App Logo picker screen.
  ///
  /// In en, this message translates to:
  /// **'APP LOGO'**
  String get settingsScreenRowAppLogo;

  /// All-caps row label that opens the Glass (liquid-glass tuning) screen.
  ///
  /// In en, this message translates to:
  /// **'GLASS'**
  String get settingsScreenRowGlass;

  /// All-caps row label that opens the Chat List layout picker.
  ///
  /// In en, this message translates to:
  /// **'CHAT LIST'**
  String get settingsScreenRowChatList;

  /// All-caps row label that opens the Navigation style picker.
  ///
  /// In en, this message translates to:
  /// **'NAVIGATION'**
  String get settingsScreenRowNavigation;

  /// All-caps row label that opens the Chat Style picker.
  ///
  /// In en, this message translates to:
  /// **'CHAT STYLE'**
  String get settingsScreenRowChatStyle;

  /// All-caps row label that opens the Bubble Style picker.
  ///
  /// In en, this message translates to:
  /// **'BUBBLE STYLE'**
  String get settingsScreenRowBubbleStyle;

  /// All-caps row label that opens the Reply Style picker.
  ///
  /// In en, this message translates to:
  /// **'REPLY STYLE'**
  String get settingsScreenRowReplyStyle;

  /// Sentence-case value shown next to CHAT LIST when the room list layout is a scrolling list.
  ///
  /// In en, this message translates to:
  /// **'Scroll list'**
  String get settingsScreenValueScrollList;

  /// Sentence-case value shown next to CHAT LIST when the room list layout is a grid.
  ///
  /// In en, this message translates to:
  /// **'Grid sheet'**
  String get settingsScreenValueGridSheet;

  /// Sentence-case value shown next to NAVIGATION when the nav style is the radial fan menu.
  ///
  /// In en, this message translates to:
  /// **'Radial orb'**
  String get settingsScreenValueRadialOrb;

  /// Sentence-case value shown next to NAVIGATION when the nav style is the floating bottom pill.
  ///
  /// In en, this message translates to:
  /// **'Bottom pill'**
  String get settingsScreenValueBottomPill;

  /// Sentence-case value shown next to GLASS when the live glass profile doesn't match any saved preset.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settingsScreenValueCustom;

  /// Value shown next to GLASS when a saved preset has been tuned away from its saved values. {name} is the preset's own name.
  ///
  /// In en, this message translates to:
  /// **'{name} · edited'**
  String settingsScreenValueEdited(Object name);

  /// Sentence-case value shown next to CHAT STYLE or REPLY STYLE when set to the classic variant — one shared key since both rows show the identical word.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get settingsScreenValueClassic;

  /// Sentence-case value shown next to CHAT STYLE when set to the compact variant.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get settingsScreenValueCompact;

  /// Sentence-case value shown next to BUBBLE STYLE for the tailed bubble shape.
  ///
  /// In en, this message translates to:
  /// **'Tailed'**
  String get settingsScreenValueBubbleTailed;

  /// Sentence-case value shown next to BUBBLE STYLE for the soft bubble shape.
  ///
  /// In en, this message translates to:
  /// **'Soft'**
  String get settingsScreenValueBubbleSoft;

  /// Sentence-case value shown next to BUBBLE STYLE for the pill bubble shape.
  ///
  /// In en, this message translates to:
  /// **'Pill'**
  String get settingsScreenValueBubblePill;

  /// Sentence-case value shown next to BUBBLE STYLE for the slab bubble shape.
  ///
  /// In en, this message translates to:
  /// **'Slab'**
  String get settingsScreenValueBubbleSlab;

  /// Title-case value shown next to REPLY STYLE for the phantom-echo reply preview style.
  ///
  /// In en, this message translates to:
  /// **'Phantom Echo'**
  String get settingsScreenValueReplyPhantomEcho;

  /// Title-case value shown next to REPLY STYLE for the sticky-note reply preview style.
  ///
  /// In en, this message translates to:
  /// **'Sticky Note'**
  String get settingsScreenValueReplyStickyNote;

  /// Title-case value shown next to REPLY STYLE for the comic-tail reply preview style.
  ///
  /// In en, this message translates to:
  /// **'Comic Tail'**
  String get settingsScreenValueReplyComicTail;

  /// Sentence-case value shown next to APP LOGO when the icon follows the active theme automatically.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsScreenValueLogoAuto;

  /// Sentence-case value shown next to APP LOGO when the icon is pinned to a specific choice, if no theme/monkey name matched.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get settingsScreenValueLogoManual;

  /// All-caps label on the Show Link URLs toggle row.
  ///
  /// In en, this message translates to:
  /// **'SHOW LINK URLS'**
  String get settingsScreenShowLinkUrlsLabel;

  /// Caption under SHOW LINK URLS when the toggle is on.
  ///
  /// In en, this message translates to:
  /// **'raw URLs appear alongside the preview card'**
  String get settingsScreenLinksUrlsOnBody;

  /// Caption under SHOW LINK URLS when the toggle is off.
  ///
  /// In en, this message translates to:
  /// **'currently preview only — cleaner bubbles, tap to open'**
  String get settingsScreenLinksUrlsOffBody;

  /// All-caps section header above the call-related settings (video quality, network stats).
  ///
  /// In en, this message translates to:
  /// **'CALLS'**
  String get settingsScreenSectionCalls;

  /// Settings disclosure row label that opens the video quality tier picker.
  ///
  /// In en, this message translates to:
  /// **'Video quality'**
  String get settingsScreenRowVideoQuality;

  /// Value shown next to Video quality when the auto (adaptive) tier is selected. Also the tier's own label on the picker screen.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settingsScreenValueVideoQualityAuto;

  /// Value shown next to Video quality when the 1080p tier is selected. Numeric — left untranslated in every locale.
  ///
  /// In en, this message translates to:
  /// **'1080p'**
  String get settingsScreenValueVideoQuality1080p;

  /// Value shown next to Video quality when the 4K tier is selected. Numeric — left untranslated in every locale.
  ///
  /// In en, this message translates to:
  /// **'4K'**
  String get settingsScreenValueVideoQuality4k;

  /// All-caps label on the Show Call Stats toggle row (also reused as the in-call options sheet row label).
  ///
  /// In en, this message translates to:
  /// **'SHOW CALL STATS'**
  String get settingsScreenShowNetworkStatsLabel;

  /// Caption under SHOW CALL STATS describing what the toggle does.
  ///
  /// In en, this message translates to:
  /// **'live resolution, bitrate, ping, and packet loss during calls'**
  String get settingsScreenShowNetworkStatsBody;

  /// Title of the video quality tier picker screen.
  ///
  /// In en, this message translates to:
  /// **'Video quality'**
  String get videoQualityScreenTitle;

  /// Subtitle under the Video quality screen title.
  ///
  /// In en, this message translates to:
  /// **'Choose a resolution ceiling for outgoing video'**
  String get videoQualityScreenSubtitle;

  /// Description under the Auto tier card.
  ///
  /// In en, this message translates to:
  /// **'Adapts to your connection automatically'**
  String get videoQualityScreenAutoSubtitle;

  /// Description under the 1080p tier card.
  ///
  /// In en, this message translates to:
  /// **'Full HD — sharper, uses more data'**
  String get videoQualityScreenHd1080Subtitle;

  /// Description under the 4K tier card.
  ///
  /// In en, this message translates to:
  /// **'Ultra HD — best on a strong connection'**
  String get videoQualityScreenUhd4kSubtitle;

  /// Small print at the bottom of the Video quality screen — no capability check backs the tiers, so hardware or network can still negotiate a call down from what's selected.
  ///
  /// In en, this message translates to:
  /// **'Actual resolution depends on both devices\' cameras and network conditions.'**
  String get videoQualityScreenFootnote;

  /// Label under the call screen's control-bar button that opens the call options sheet (network stats toggle, video quality).
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get callScreenControlOptions;

  /// Abbreviation label preceding the round-trip-time value in the in-call network stats panel.
  ///
  /// In en, this message translates to:
  /// **'RTT'**
  String get callScreenStatsRttLabel;

  /// Label preceding the jitter value in the in-call network stats panel.
  ///
  /// In en, this message translates to:
  /// **'Jitter'**
  String get callScreenStatsJitterLabel;

  /// Label preceding the packet-loss percentage in the in-call network stats panel.
  ///
  /// In en, this message translates to:
  /// **'Loss'**
  String get callScreenStatsLossLabel;

  /// Accessibility label for tapping the full-screen video or the small preview tile to swap which feed is shown large during a video call.
  ///
  /// In en, this message translates to:
  /// **'Swap camera views'**
  String get callScreenSwapPreviewSemanticLabel;

  /// Title of the in-call bottom sheet holding the network stats toggle and video quality picker.
  ///
  /// In en, this message translates to:
  /// **'Call options'**
  String get callOptionsSheetTitle;

  /// All-caps label on the Push Notifications toggle row.
  ///
  /// In en, this message translates to:
  /// **'PUSH NOTIFICATIONS'**
  String get settingsScreenPushNotificationsLabel;

  /// Caption under PUSH NOTIFICATIONS when the toggle is on.
  ///
  /// In en, this message translates to:
  /// **'pings for new messages + requests'**
  String get settingsScreenPushOnBody;

  /// Caption under PUSH NOTIFICATIONS when the toggle is off.
  ///
  /// In en, this message translates to:
  /// **'silent — you’ll only see things when you open the app'**
  String get settingsScreenPushOffBody;

  /// Shown on signup when USERNAME_TAKEN comes back from the backend.
  ///
  /// In en, this message translates to:
  /// **'That username is already taken.'**
  String get authErrorUsernameTaken;

  /// Shown at signup when the requested username contains a reserved brand term and cannot be registered. Deliberately does not name the blocked term.
  ///
  /// In en, this message translates to:
  /// **'That username isn\'t available. Please pick a different one.'**
  String get authErrorUsernameReserved;

  /// Shown when the requested display name contains a reserved brand term, at signup or when editing a profile. Refers to the name field, not the username, and deliberately does not name the blocked term.
  ///
  /// In en, this message translates to:
  /// **'That name isn\'t available. Please pick a different one.'**
  String get authErrorDisplayNameReserved;

  /// Shown on login when USER_NOT_FOUND comes back from the backend. Some screens override this with more specific copy (e.g. the child pairing screen).
  ///
  /// In en, this message translates to:
  /// **'No account with that username.'**
  String get authErrorUserNotFound;

  /// Shown on login when WRONG_PASSWORD comes back from the backend.
  ///
  /// In en, this message translates to:
  /// **'Wrong password.'**
  String get authErrorWrongPassword;

  /// Shown on password reset when INVALID_RECOVERY_KEY comes back. Deliberately vague — this one code covers 'no such user', 'that's a child account', and 'wrong phrase' so a stranger probing the reset flow can't distinguish which.
  ///
  /// In en, this message translates to:
  /// **'That username and recovery phrase don’t match.'**
  String get authErrorInvalidRecoveryKey;

  /// Shown when TOO_MANY_ATTEMPTS (rate limit) comes back from the backend.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Wait 15 minutes and try again.'**
  String get authErrorTooManyAttempts;

  /// Shown on login when CHILD_MUST_PAIR comes back — a child account can't password-login, only pair.
  ///
  /// In en, this message translates to:
  /// **'That’s a kid’s account — ask a grown-up for a pairing code.'**
  String get authErrorChildMustPair;

  /// Shown on the child pairing screen when PAIRING_CODE_EXPIRED comes back.
  ///
  /// In en, this message translates to:
  /// **'That code has run out. Ask for a new one.'**
  String get authErrorPairingCodeExpired;

  /// Shown on the child pairing screen when PAIRING_CODE_INVALID comes back.
  ///
  /// In en, this message translates to:
  /// **'That code didn’t work. It may have been used already.'**
  String get authErrorPairingCodeInvalid;

  /// Shown on login when USE_SOCIAL_SIGN_IN comes back — the account has no password because it was created via a social provider.
  ///
  /// In en, this message translates to:
  /// **'That account signs in with Apple or Google — use the buttons below.'**
  String get authErrorUseSocialSignIn;

  /// Shown when SOCIAL_TOKEN_INVALID comes back from a failed Apple/Google sign-in.
  ///
  /// In en, this message translates to:
  /// **'That sign-in didn’t go through. Please try again.'**
  String get authErrorSocialTokenInvalid;

  /// Shown when SOCIAL_NONCE_MISMATCH comes back — identical copy to SOCIAL_TOKEN_INVALID, both mean 'start over' to the user.
  ///
  /// In en, this message translates to:
  /// **'That sign-in didn’t go through. Please try again.'**
  String get authErrorSocialNonceMismatch;

  /// Shown when SOCIAL_MISCONFIG comes back — a server-side configuration problem, not the user's fault.
  ///
  /// In en, this message translates to:
  /// **'Sign-in isn’t set up yet on our side. Try again later.'**
  String get authErrorSocialMisconfig;

  /// Shown when SOCIAL_LINKED_TO_OTHER_ACCOUNT comes back while trying to link a social account.
  ///
  /// In en, this message translates to:
  /// **'That Apple or Google account is already linked to a different MonkeyHub account.'**
  String get authErrorSocialLinkedToOtherAccount;

  /// Shown when SOCIAL_ALREADY_LINKED comes back.
  ///
  /// In en, this message translates to:
  /// **'That’s already linked to this account.'**
  String get authErrorSocialAlreadyLinked;

  /// Shown when SOCIAL_NOT_LINKED comes back while trying to unlink a social account that was never linked.
  ///
  /// In en, this message translates to:
  /// **'That isn’t linked to this account.'**
  String get authErrorSocialNotLinked;

  /// Shown when SOCIAL_LAST_CREDENTIAL comes back — unlinking would leave the account with no way to sign in.
  ///
  /// In en, this message translates to:
  /// **'That’s the only way into this account. Set a password first.'**
  String get authErrorSocialLastCredential;

  /// Shown when USERNAME_INVALID comes back from username normalisation.
  ///
  /// In en, this message translates to:
  /// **'Pick a username between 1 and 32 characters.'**
  String get authErrorUsernameInvalid;

  /// All-caps name of the 'frost' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'FROST'**
  String get glassKnobLabelFrost;

  /// One-line caption under the 'frost' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'how much white sits on the glass. down for see-through'**
  String get glassKnobHintFrost;

  /// All-caps name of the 'blur' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'BLUR'**
  String get glassKnobLabelBlur;

  /// One-line caption under the 'blur' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'frosted at the top of the range, clear glass at the bottom'**
  String get glassKnobHintBlur;

  /// All-caps name of the 'colour bleed' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'COLOUR BLEED'**
  String get glassKnobLabelSaturation;

  /// One-line caption under the 'colour bleed' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'how much colour survives the blur. past 2 it posterizes'**
  String get glassKnobHintSaturation;

  /// All-caps name of the 'rim' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'RIM'**
  String get glassKnobLabelRimOpacity;

  /// One-line caption under the 'rim' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'the accent outline. zero for a borderless surface'**
  String get glassKnobHintRimOpacity;

  /// All-caps name of the 'rim width' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'RIM WIDTH'**
  String get glassKnobLabelRimWidth;

  /// One-line caption under the 'rim width' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'thickness of that outline'**
  String get glassKnobHintRimWidth;

  /// All-caps name of the 'shadow' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'SHADOW'**
  String get glassKnobLabelShadowOpacity;

  /// One-line caption under the 'shadow' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'how far the surface floats above what is behind it'**
  String get glassKnobHintShadowOpacity;

  /// All-caps name of the 'shadow spread' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'SHADOW SPREAD'**
  String get glassKnobLabelShadowBlur;

  /// One-line caption under the 'shadow spread' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'soft and wide, or tight and hard'**
  String get glassKnobHintShadowBlur;

  /// All-caps name of the 'shadow drop' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'SHADOW DROP'**
  String get glassKnobLabelShadowY;

  /// One-line caption under the 'shadow drop' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'how far below the surface it falls'**
  String get glassKnobHintShadowY;

  /// All-caps name of the 'side margin' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'SIDE MARGIN'**
  String get glassKnobLabelBarMargin;

  /// One-line caption under the 'side margin' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'gap between the bar and the edge of the screen'**
  String get glassKnobHintBarMargin;

  /// All-caps name of the 'bottom gap' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'BOTTOM GAP'**
  String get glassKnobLabelBarBottom;

  /// One-line caption under the 'bottom gap' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'how high the bar floats off the bottom'**
  String get glassKnobHintBarBottom;

  /// All-caps name of the 'end padding' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'END PADDING'**
  String get glassKnobLabelShellPadH;

  /// One-line caption under the 'end padding' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'bar edge to the first pill. small, or the ends look marooned'**
  String get glassKnobHintShellPadH;

  /// All-caps name of the 'top padding' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'TOP PADDING'**
  String get glassKnobLabelShellPadV;

  /// One-line caption under the 'top padding' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'bar edge to the top of the pill'**
  String get glassKnobHintShellPadV;

  /// All-caps name of the 'pill inset' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'PILL INSET'**
  String get glassKnobLabelIndicatorInset;

  /// One-line caption under the 'pill inset' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'how far the selection pill sits inside its slot'**
  String get glassKnobHintIndicatorInset;

  /// All-caps name of the 'row padding' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'ROW PADDING'**
  String get glassKnobLabelSegmentPadV;

  /// One-line caption under the 'row padding' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'air above and below the icon and its label'**
  String get glassKnobHintSegmentPadV;

  /// All-caps name of the 'icon gap' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'ICON GAP'**
  String get glassKnobLabelIconLabelGap;

  /// One-line caption under the 'icon gap' slider explaining what it does to the look.
  ///
  /// In en, this message translates to:
  /// **'space between an icon and the word under it'**
  String get glassKnobHintIconLabelGap;

  /// All-caps name of the 'icon size' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'ICON SIZE'**
  String get glassKnobLabelIconSize;

  /// All-caps name of the 'label size' dial in the Glass tuning screen. Sourced by GlassKnob.id (a stable persistence key, never itself translated).
  ///
  /// In en, this message translates to:
  /// **'LABEL SIZE'**
  String get glassKnobLabelLabelSize;

  /// All-caps option label for Spanish in the language picker. This is the language's own autonym (how it names itself), conventionally shown the same way regardless of the active UI language — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'ESPAÑOL'**
  String get languageOptionSpanish;

  /// Sentence-case value shown next to the LANGUAGE row in Settings when Spanish is the active/pinned language. Same autonym as languageOptionSpanish, same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageValueSpanish;

  /// All-caps option label for French in the language picker. This is the language's own autonym (how it names itself), conventionally shown the same way regardless of the active UI language — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'FRANÇAIS'**
  String get languageOptionFrench;

  /// Sentence-case value shown next to the LANGUAGE row in Settings when French is the active/pinned language. Same autonym as languageOptionFrench, same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageValueFrench;

  /// All-caps option label for European (Portugal) Portuguese in the language picker, distinct from Brazilian Portuguese (languageOptionPortugueseBrazil). Autonym — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'PORTUGUÊS (PORTUGAL)'**
  String get languageOptionPortuguese;

  /// Sentence-case value shown next to the LANGUAGE row in Settings when European (Portugal) Portuguese is the active/pinned language. Autonym — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'Português (Portugal)'**
  String get languageValuePortuguese;

  /// All-caps option label for Swedish in the language picker. This is the language's own autonym (how it names itself), conventionally shown the same way regardless of the active UI language — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'SVENSKA'**
  String get languageOptionSwedish;

  /// Sentence-case value shown next to the LANGUAGE row in Settings when Swedish is the active/pinned language. Same autonym as languageOptionSwedish, same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'Svenska'**
  String get languageValueSwedish;

  /// All-caps option label for Brazilian Portuguese in the language picker, distinct from European Portuguese (languageOptionPortuguese). Autonym — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'PORTUGUÊS (BRASIL)'**
  String get languageOptionPortugueseBrazil;

  /// Sentence-case value shown next to the LANGUAGE row in Settings when Brazilian Portuguese is the active/pinned language. Autonym — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'Português (Brasil)'**
  String get languageValuePortugueseBrazil;

  /// Option label for Arabic in the language picker. Modern Standard Arabic (the language's own autonym, script has no letter-case distinction so this equals languageValueArabic). Autonym — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageOptionArabic;

  /// Value shown next to the LANGUAGE row in Settings when Arabic is the active/pinned language. Same autonym as languageOptionArabic, same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get languageValueArabic;

  /// Option label for Chinese in the language picker. Simplified Chinese (the language's own autonym, script has no letter-case distinction so this equals languageValueChinese). Autonym — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageOptionChinese;

  /// Value shown next to the LANGUAGE row in Settings when Chinese is the active/pinned language. Same autonym as languageOptionChinese, same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageValueChinese;

  /// Option label for Hindi in the language picker. Hindi (the language's own autonym, Devanagari script has no letter-case distinction so this equals languageValueHindi). Autonym — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageOptionHindi;

  /// Value shown next to the LANGUAGE row in Settings when Hindi is the active/pinned language. Same autonym as languageOptionHindi, same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageValueHindi;

  /// Option label for Korean in the language picker. Korean (the language's own autonym, script has no letter-case distinction so this equals languageValueKorean). Autonym — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageOptionKorean;

  /// Value shown next to the LANGUAGE row in Settings when Korean is the active/pinned language. Same autonym as languageOptionKorean, same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageValueKorean;

  /// Option label for Japanese in the language picker. Japanese (the language's own autonym, script has no letter-case distinction so this equals languageValueJapanese). Autonym — same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageOptionJapanese;

  /// Value shown next to the LANGUAGE row in Settings when Japanese is the active/pinned language. Same autonym as languageOptionJapanese, same string in every ARB file, never translated.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageValueJapanese;

  /// All-caps label for the Settings > Appearance row that opens the motion screen, where the user chooses how much the app animates.
  ///
  /// In en, this message translates to:
  /// **'MOTION'**
  String get settingsScreenRowMotion;

  /// Value shown on the Settings MOTION row when the user has explicitly chosen full motion, overriding the device's accessibility setting.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get settingsScreenValueMotionFull;

  /// Value shown on the Settings MOTION row when the user has explicitly chosen reduced motion, overriding the device's accessibility setting.
  ///
  /// In en, this message translates to:
  /// **'Calm'**
  String get settingsScreenValueMotionCalm;

  /// Value on the Settings MOTION row when the user follows the device setting AND the device currently allows animation. The '·' separates the mode from what it currently resolves to.
  ///
  /// In en, this message translates to:
  /// **'Match device · full'**
  String get settingsScreenValueMotionSystemFull;

  /// Value on the Settings MOTION row when the user follows the device setting AND the device currently requests reduced motion. The '·' separates the mode from what it currently resolves to.
  ///
  /// In en, this message translates to:
  /// **'Match device · calm'**
  String get settingsScreenValueMotionSystemCalm;

  /// Lowercase page title of the motion settings screen, with a full stop. Matches the house style of the other settings sub-screens ('language.', 'theme.').
  ///
  /// In en, this message translates to:
  /// **'motion.'**
  String get motionScreenTitle;

  /// One-line subtitle under the motion screen's title, next to a short accent rule.
  ///
  /// In en, this message translates to:
  /// **'how much the app moves'**
  String get motionScreenSubtitle;

  /// All-caps label of the motion option that follows the device's own reduce-motion accessibility setting. This is the default.
  ///
  /// In en, this message translates to:
  /// **'MATCH DEVICE'**
  String get motionScreenSystemLabel;

  /// Sub-line under the MATCH DEVICE motion option, shown when the device's reduce-motion setting is currently OFF, so following it means full animation.
  ///
  /// In en, this message translates to:
  /// **'your device allows animation right now'**
  String get motionScreenSystemSubtitleFull;

  /// Sub-line under the MATCH DEVICE motion option, shown when the device's reduce-motion setting is currently ON, so following it means calm animation.
  ///
  /// In en, this message translates to:
  /// **'your device asks for reduced motion right now'**
  String get motionScreenSystemSubtitleCalm;

  /// All-caps label of the motion option that always renders every animation, even if the device asks for reduced motion.
  ///
  /// In en, this message translates to:
  /// **'FULL'**
  String get motionScreenFullLabel;

  /// Sub-line under the FULL motion option describing what it enables.
  ///
  /// In en, this message translates to:
  /// **'every drift, glow and flourish'**
  String get motionScreenFullSubtitle;

  /// All-caps label of the motion option that suppresses decorative animation regardless of the device setting.
  ///
  /// In en, this message translates to:
  /// **'CALM'**
  String get motionScreenCalmLabel;

  /// Sub-line under the CALM motion option. Reassures the user that only decorative motion stops: scrolling, sheets and gestures behave exactly as before.
  ///
  /// In en, this message translates to:
  /// **'decoration holds still — nothing else changes'**
  String get motionScreenCalmSubtitle;

  /// All-caps label on the leading tile of the Feed highlights rail, which opens the composer to capture or pick a photo.
  ///
  /// In en, this message translates to:
  /// **'CAPTURE'**
  String get momentRailCaptureLabel;

  /// Lowercase author label under a card in the Feed highlights rail when the moment is the viewer's own, shown instead of their name.
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get momentRailYouLabel;

  /// Screen-reader label for a card in the Feed highlights rail. {author} is the person's display name, {caption} is the text they wrote. NOTE: parameters are emitted in ALPHABETICAL order (author, caption), which here matches reading order.
  ///
  /// In en, this message translates to:
  /// **'{author}: {caption}'**
  String momentRailCardSemanticLabel(Object author, Object caption);

  /// All-caps name of the scoring category for an improbable coincidence — running into your dentist abroad, spotting a celebrity. 'What are the odds', with no benefit implied.
  ///
  /// In en, this message translates to:
  /// **'FATE'**
  String get momentTagFate;

  /// All-caps name of the scoring category for doing something reasonable and having the timing make it pointless — washing the car and then it rains. Translates the Turkish 'kerizlik': the universe mocking your effort. NOT 'silly' or 'goofy'; the point is self-inflicted bad timing.
  ///
  /// In en, this message translates to:
  /// **'JINX'**
  String get momentTagJinx;

  /// All-caps name of the scoring category for things going your way — catching the train with seconds to spare, finding parking outside. The mirror of JINX.
  ///
  /// In en, this message translates to:
  /// **'LUCK'**
  String get momentTagLuck;

  /// All-caps name of the scoring category for predicting something out loud that then happened.
  ///
  /// In en, this message translates to:
  /// **'CALLED IT'**
  String get momentTagCalledIt;

  /// All-caps name of the scoring category for a total autopilot moment — saying 'you too' to a waiter, putting the cereal in the fridge. From the gaming term for a non-player character who acts on a script; keep it untranslated if the term is used as-is in your language.
  ///
  /// In en, this message translates to:
  /// **'NPC'**
  String get momentTagNpc;

  /// One-line explanation under the FATE category in the moment composer's picker.
  ///
  /// In en, this message translates to:
  /// **'what are the odds'**
  String get momentTagFateHint;

  /// One-line explanation under the JINX category in the moment composer's picker — the bad timing was a consequence of your own action.
  ///
  /// In en, this message translates to:
  /// **'you did it to yourself'**
  String get momentTagJinxHint;

  /// One-line explanation under the LUCK category in the moment composer's picker.
  ///
  /// In en, this message translates to:
  /// **'that went your way'**
  String get momentTagLuckHint;

  /// One-line explanation under the CALLED IT category in the moment composer's picker.
  ///
  /// In en, this message translates to:
  /// **'you saw it coming'**
  String get momentTagCalledItHint;

  /// One-line explanation under the NPC category in the moment composer's picker — acting on autopilot, not thinking.
  ///
  /// In en, this message translates to:
  /// **'brain fully off'**
  String get momentTagNpcHint;

  /// Lowercase title at the top of the sheet for composing a new Feed moment. Conversational, inviting the user to share something from their day.
  ///
  /// In en, this message translates to:
  /// **'what happened?'**
  String get momentComposerTitle;

  /// Placeholder text in the caption field of the moment composer.
  ///
  /// In en, this message translates to:
  /// **'say something about it'**
  String get momentComposerCaptionHint;

  /// Small hint above the row of scoring categories in the moment composer, explaining that picking one is optional and makes the moment count on the standings board.
  ///
  /// In en, this message translates to:
  /// **'won a point? add it now'**
  String get momentComposerTagPrompt;

  /// Label on the button in the moment composer that opens the in-app camera.
  ///
  /// In en, this message translates to:
  /// **'camera'**
  String get momentComposerCapture;

  /// Label on the button in the moment composer that opens the device photo library.
  ///
  /// In en, this message translates to:
  /// **'library'**
  String get momentComposerLibrary;

  /// Screen-reader label for the X button that clears the chosen photo in the moment composer.
  ///
  /// In en, this message translates to:
  /// **'remove photo'**
  String get momentComposerRemovePhoto;

  /// All-caps label on the button that publishes the moment in the composer.
  ///
  /// In en, this message translates to:
  /// **'POST'**
  String get momentComposerPost;

  /// Error under the composer when the user has already awarded themselves the daily maximum (20) of one scoring category. Light-hearted; the cap exists so the standings board stays meaningful, not as a punishment.
  ///
  /// In en, this message translates to:
  /// **'that\'s five of those today — save some for tomorrow'**
  String get momentComposerErrorDailyCap;

  /// Error under the composer when a supervised (child) account tries to post a photo but their guardian has disabled media.
  ///
  /// In en, this message translates to:
  /// **'a guardian has turned photo sharing off'**
  String get momentComposerErrorNotAllowed;

  /// Error under the composer when the caption exceeds 280 characters.
  ///
  /// In en, this message translates to:
  /// **'that\'s a bit long — trim it down'**
  String get momentComposerErrorTooLong;

  /// Error under the composer when the user tries to post with neither a photo nor any text.
  ///
  /// In en, this message translates to:
  /// **'add a photo or a few words'**
  String get momentComposerErrorEmpty;

  /// Generic error under the composer when publishing fails for an unrecognised reason.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t post that — try again'**
  String get momentComposerErrorGeneric;

  /// Label on the action that permanently removes the viewer's own moment from the Feed, shown only on moments they wrote.
  ///
  /// In en, this message translates to:
  /// **'delete'**
  String get momentViewerDelete;

  /// Activity-river line for an untagged moment. {who} is a display name, or the localized word for 'you' when it is the viewer's own.
  ///
  /// In en, this message translates to:
  /// **'{who} posted a highlight'**
  String momentActivityPostedHighlight(Object who);

  /// Activity-river line for a moment that scored. {name} is a display name (or 'you'); {tag} is the localized category name such as JINX or FATE. 'took a' is idiomatic for earning a point in this game. NOTE: gen-l10n emits parameters in ALPHABETICAL order (name, tag), which here matches reading order.
  ///
  /// In en, this message translates to:
  /// **'{name} took a {tag}'**
  String momentActivityScored(Object name, Object tag);

  /// Compact timestamp on an activity row for something that happened less than a minute ago. Keep it very short — it sits in a narrow column beside a name.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get momentActivityJustNow;

  /// Compact timestamp on an activity row, in minutes. Keep it very short (one letter suffix) — it sits in a narrow column beside a name.
  ///
  /// In en, this message translates to:
  /// **'{count}m'**
  String momentActivityMinutesAgo(Object count);

  /// Compact timestamp on an activity row, in hours. Keep it very short (one letter suffix) — it sits in a narrow column beside a name.
  ///
  /// In en, this message translates to:
  /// **'{count}h'**
  String momentActivityHoursAgo(Object count);

  /// Muted line at the end of a truncated activity river, stating how many entries are not shown. Says what was hidden rather than letting the list stop silently.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 more today} other{{count} more today}}'**
  String momentActivityMoreCount(num count);

  /// Lowercase page title of the daily puzzle screen, with a full stop, matching the house style of the other sub-screens ('language.', 'motion.').
  ///
  /// In en, this message translates to:
  /// **'the puzzle.'**
  String get puzzleScreenTitle;

  /// One-line subtitle under the puzzle screen's title, next to a short accent rule. States the rules in the fewest possible words.
  ///
  /// In en, this message translates to:
  /// **'four symbols, six tries'**
  String get puzzleScreenSubtitle;

  /// All-caps label on the button that submits the composed row of symbols.
  ///
  /// In en, this message translates to:
  /// **'GUESS'**
  String get puzzleSubmit;

  /// Screen-reader label for the backspace key on the puzzle keypad.
  ///
  /// In en, this message translates to:
  /// **'delete last symbol'**
  String get puzzleBackspace;

  /// Screen-reader label for a symbol key on the puzzle keypad. {number} is its position in the alphabet, 1-6. The symbols are abstract shapes with no names, so they are identified by number.
  ///
  /// In en, this message translates to:
  /// **'symbol {number}'**
  String puzzleSymbolSemanticLabel(Object number);

  /// Headline shown when the player has cracked the code. {count} is how many guesses it took.
  ///
  /// In en, this message translates to:
  /// **'solved in {count}'**
  String puzzleSolvedTitle(Object count);

  /// Headline shown when the player has used all six tries without solving the puzzle.
  ///
  /// In en, this message translates to:
  /// **'out of guesses'**
  String get puzzleFailedTitle;

  /// All-caps label above the revealed answer, shown only after the player has run out of guesses.
  ///
  /// In en, this message translates to:
  /// **'THE CODE WAS'**
  String get puzzleAnswerWas;

  /// All-caps label on the action that copies the shareable emoji grid to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'COPY RESULT'**
  String get puzzleShare;

  /// Confirmation shown after the puzzle result grid is copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'copied — paste it to a friend'**
  String get puzzleShareCopied;

  /// First line of the copied puzzle result, above the emoji grid. {edition} is the day number; {score} is the number of guesses used, or the letter X if unsolved. 'MonkeyHub' is a proper noun — keep it identical across locales. NOTE: parameters are emitted in ALPHABETICAL order (edition, score), which here matches reading order.
  ///
  /// In en, this message translates to:
  /// **'MonkeyHub №{edition} {score}/6'**
  String puzzleShareHeader(Object edition, Object score);

  /// Error shown if a guess is submitted after the puzzle has been solved — normally only reachable from a stale screen.
  ///
  /// In en, this message translates to:
  /// **'you already solved today\'s'**
  String get puzzleErrorAlreadySolved;

  /// Error shown if a guess is submitted after all six tries have been used.
  ///
  /// In en, this message translates to:
  /// **'no guesses left today'**
  String get puzzleErrorOutOfGuesses;

  /// Generic error when submitting a puzzle guess fails for an unrecognised reason.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t send that guess — try again'**
  String get puzzleErrorGeneric;

  /// All-caps band label above the list of friends who have finished today's puzzle.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S SCORES'**
  String get puzzleScoreboardLabel;

  /// Muted line shown under TODAY'S SCORES when no friend, including the viewer, has completed the puzzle.
  ///
  /// In en, this message translates to:
  /// **'nobody has finished yet today'**
  String get puzzleScoreboardEmpty;

  /// Label on the Feed board's puzzle tile when the viewer has not started today's puzzle.
  ///
  /// In en, this message translates to:
  /// **'play today\'s puzzle'**
  String get puzzleTilePlay;

  /// Label on the Feed board's puzzle tile mid-game. {count} is how many guesses remain.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String puzzleTileInProgress(Object count);

  /// Where the viewer placed among friends who finished today's puzzle, shown on the Feed board's puzzle tile. NOTE: parameters are emitted in ALPHABETICAL order (rank, total), which here matches reading order.
  ///
  /// In en, this message translates to:
  /// **'#{rank} of {total}'**
  String puzzleTileRank(Object rank, Object total);

  /// All-caps section header in the profile visibility screen, grouping the three controls for what friends can see on the Feed board (moments, puzzle score, past points).
  ///
  /// In en, this message translates to:
  /// **'FEED'**
  String get profileVisibilityScreenSectionFeed;

  /// Label for the control deciding whether the user's photos and points appear on friends' Feed boards.
  ///
  /// In en, this message translates to:
  /// **'my highlights'**
  String get profileVisibilityScreenFeedLabel;

  /// Explanation under the 'my moments' visibility control. 'for the day' matters: moments drop off friends' boards after 24 hours regardless of this setting.
  ///
  /// In en, this message translates to:
  /// **'whether the photos and videos you post show up on friends\' boards for the day'**
  String get profileVisibilityScreenFeedDesc;

  /// Label for the control deciding whether the user's daily puzzle result is visible to friends.
  ///
  /// In en, this message translates to:
  /// **'my puzzle score'**
  String get profileVisibilityScreenPuzzleLabel;

  /// Explanation under the 'my puzzle score' visibility control.
  ///
  /// In en, this message translates to:
  /// **'whether friends see how you did on the daily puzzle'**
  String get profileVisibilityScreenPuzzleDesc;

  /// Label for the control deciding whether friends can look further back than today on the user's Feed history.
  ///
  /// In en, this message translates to:
  /// **'my past'**
  String get profileVisibilityScreenPointsPastLabel;

  /// Explanation under the 'my past' visibility control. Makes clear that turning it off does NOT hide today, only history.
  ///
  /// In en, this message translates to:
  /// **'today is always shared with friends — this opens up everything before it'**
  String get profileVisibilityScreenPointsPastDesc;

  /// Label on the button in the moment composer that picks a video from the device library.
  ///
  /// In en, this message translates to:
  /// **'video'**
  String get momentComposerVideo;

  /// Error under the composer when a picked video exceeds the 20 MB upload limit. Shown at pick time, before any upload starts.
  ///
  /// In en, this message translates to:
  /// **'that video\'s too large — 20 MB max'**
  String get momentComposerErrorTooBig;

  /// Activity-river line for the VIEWER'S OWN untagged moment. Separate from momentActivityPostedHighlight (which names another person) because languages with verb agreement — Turkish, Japanese, Korean and others — cannot conjugate correctly from an interpolated name. Write this in the second person.
  ///
  /// In en, this message translates to:
  /// **'you posted a highlight'**
  String get momentActivityPostedHighlightSelf;

  /// Activity-river line for the VIEWER'S OWN point. {tag} is the localized category name such as JINX. Second person; see momentActivityPostedHighlightSelf for why this is a separate key.
  ///
  /// In en, this message translates to:
  /// **'you took a {tag}'**
  String momentActivityScoredSelf(Object tag);

  /// Compact header above your own point on the points board. {tag} is the localized category name. Very short — the sentence underneath is the actual content.
  ///
  /// In en, this message translates to:
  /// **'you · {tag}'**
  String pointLineSelf(Object tag);

  /// Compact header above someone else's point on the points board. {name} is their display name, {tag} the localized category. NOTE: parameters are emitted in ALPHABETICAL order (name, tag), matching reading order here.
  ///
  /// In en, this message translates to:
  /// **'{name} · {tag}'**
  String pointLineOther(Object name, Object tag);

  /// Title of the sheet for logging a point. Conversational — a point is a small story, not a form.
  ///
  /// In en, this message translates to:
  /// **'what happened?'**
  String get pointComposerTitle;

  /// Placeholder in the point composer's text field before a category has been chosen.
  ///
  /// In en, this message translates to:
  /// **'pick one above, then tell the story'**
  String get pointComposerNoteHint;

  /// All-caps label on the button that logs the point.
  ///
  /// In en, this message translates to:
  /// **'ADD POINT'**
  String get pointComposerAdd;

  /// Label on the optional photo button in the point composer. Optional is the point: most points are just a sentence.
  ///
  /// In en, this message translates to:
  /// **'add a photo'**
  String get pointComposerAddPhoto;

  /// All-caps label on the button under the points board that opens the point composer.
  ///
  /// In en, this message translates to:
  /// **'ADD A POINT'**
  String get pointsBoardAdd;

  /// Label on the small chip that opens the explainer for the points game. Appears on the POINTS section header and in the composer.
  ///
  /// In en, this message translates to:
  /// **'what\'s this?'**
  String get pointsExplainerOpen;

  /// Title of the sheet explaining what the points board is.
  ///
  /// In en, this message translates to:
  /// **'the points game'**
  String get pointsExplainerTitle;

  /// Opening paragraph of the points explainer. Sets up that this is a game friends play about real life, not a social feed.
  ///
  /// In en, this message translates to:
  /// **'A running joke you keep score of. When something happens to you — good, bad or just strange — you log it and it goes on the board for the day.'**
  String get pointsExplainerIntro;

  /// Bullet in the points explainer covering the honour system.
  ///
  /// In en, this message translates to:
  /// **'You award your own points. Nobody checks — that\'s the fun, and your friends will tell you if you\'re pushing it.'**
  String get pointsExplainerRuleHonour;

  /// Bullet in the points explainer covering the daily reset.
  ///
  /// In en, this message translates to:
  /// **'Points reset every day. The board shows today; your own history is yours to keep.'**
  String get pointsExplainerRuleToday;

  /// Bullet in the points explainer covering the daily per-category cap.
  ///
  /// In en, this message translates to:
  /// **'Five of any one kind per day, so nobody can farm the board into nonsense.'**
  String get pointsExplainerRuleCap;

  /// All-caps label on the button that dismisses the points explainer.
  ///
  /// In en, this message translates to:
  /// **'GOT IT'**
  String get pointsExplainerGotIt;

  /// Concrete example under the FATE category, and the composer's placeholder once FATE is picked. Should read like something a real person typed.
  ///
  /// In en, this message translates to:
  /// **'ran into my dentist in another country'**
  String get momentTagFateExample;

  /// Concrete example under the JINX category. This is the canonical case: you did a reasonable thing and the timing made it pointless.
  ///
  /// In en, this message translates to:
  /// **'washed the car, it rained at four'**
  String get momentTagJinxExample;

  /// Concrete example under the LUCK category.
  ///
  /// In en, this message translates to:
  /// **'caught the train with two seconds to spare'**
  String get momentTagLuckExample;

  /// Concrete example under the CALLED IT category.
  ///
  /// In en, this message translates to:
  /// **'said the sequel would flop, it flopped'**
  String get momentTagCalledItExample;

  /// Concrete example under the NPC category. Uses curly quotes deliberately, matching the app's typography.
  ///
  /// In en, this message translates to:
  /// **'said ‘you too’ to the waiter'**
  String get momentTagNpcExample;

  /// Explains the № stamp in the Feed masthead when tapped. {number} is how many days the feed has been running.
  ///
  /// In en, this message translates to:
  /// **'day {number} of the feed'**
  String feedBoardEditionHint(Object number);

  /// Sub-line under the HIGHLIGHTS band clarifying that this section is media, as distinct from the points board below it.
  ///
  /// In en, this message translates to:
  /// **'photos and videos worth a look'**
  String get feedBoardHighlightsHint;

  /// Label for the control deciding whether the user's points (JINX, FATE, etc.) appear on friends' boards. Separate from 'my moments', which covers photo highlights.
  ///
  /// In en, this message translates to:
  /// **'my points'**
  String get profileVisibilityScreenPointsLabel;

  /// Explanation under the 'my points' visibility control.
  ///
  /// In en, this message translates to:
  /// **'whether the points you log show up on friends\' boards'**
  String get profileVisibilityScreenPointsDesc;

  /// Screen-reader label for the crop button over the chosen photo in the composer, which re-opens the cropper on the original image.
  ///
  /// In en, this message translates to:
  /// **'edit crop'**
  String get momentComposerEditPhoto;

  /// Lowercase title of the screen showing every moment the user has kept, grouped by day.
  ///
  /// In en, this message translates to:
  /// **'your archive'**
  String get archiveScreenTitle;

  /// Muted line at the bottom of the archive once every page has loaded.
  ///
  /// In en, this message translates to:
  /// **'that\'s everything'**
  String get archiveScreenEnd;

  /// Title of the archive's empty state for the viewer's own archive.
  ///
  /// In en, this message translates to:
  /// **'nothing kept yet'**
  String get archiveScreenEmptyTitle;

  /// Body of the archive's empty state for the viewer's own archive. Explains what the archive is for.
  ///
  /// In en, this message translates to:
  /// **'moments leave your friends\' boards after a day, but they stay here for you.'**
  String get archiveScreenEmptyBody;

  /// Title of the archive's empty state when viewing a friend who has kept nothing.
  ///
  /// In en, this message translates to:
  /// **'nothing here'**
  String get archiveScreenEmptyFriendTitle;

  /// Body of the archive's empty state when viewing a friend who has kept nothing.
  ///
  /// In en, this message translates to:
  /// **'they haven\'t posted anything you can see yet.'**
  String get archiveScreenEmptyFriendBody;

  /// Title shown when a friend has not opened their history to friends.
  ///
  /// In en, this message translates to:
  /// **'their past is private'**
  String get archiveScreenPrivateTitle;

  /// Body shown when a friend's history is private. Reassures that today is unaffected.
  ///
  /// In en, this message translates to:
  /// **'you can still see what they post today.'**
  String get archiveScreenPrivateBody;

  /// Title shown when trying to view the archive of someone who is no longer a friend.
  ///
  /// In en, this message translates to:
  /// **'not friends'**
  String get archiveScreenNotFriendTitle;

  /// Body shown when trying to view a non-friend's archive.
  ///
  /// In en, this message translates to:
  /// **'you can only look back through a friend\'s days.'**
  String get archiveScreenNotFriendBody;

  /// Title of the archive's generic error state.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t load that'**
  String get archiveScreenErrorTitle;

  /// Body of the archive's generic error state.
  ///
  /// In en, this message translates to:
  /// **'check your connection and try again.'**
  String get archiveScreenErrorBody;

  /// Label on the control in the HIGHLIGHTS section header that opens the user's own archive of kept moments.
  ///
  /// In en, this message translates to:
  /// **'archive'**
  String get feedBoardOpenArchive;

  /// All-caps band label for the Feed section holding today's four logic games (Queens, Tango, Zip, Mini Sudoku) as small board thumbnails.
  ///
  /// In en, this message translates to:
  /// **'THE GAMES'**
  String get feedBoardGamesLabel;

  /// Label on the control in the THE GAMES section header that opens the games hub, where all of today's boards and everyone's times live.
  ///
  /// In en, this message translates to:
  /// **'all games'**
  String get feedBoardGamesOpen;

  /// Lowercase page title of the games hub, with a full stop, matching the house style of the other sub-screens ('the puzzle.', 'language.').
  ///
  /// In en, this message translates to:
  /// **'the games.'**
  String get gamesScreenTitle;

  /// One-line subtitle under the games hub title, next to a short accent rule. States what the daily games are in the fewest possible words; the point being made is that every player worldwide gets the identical boards.
  ///
  /// In en, this message translates to:
  /// **'four boards a day, the same four for everyone'**
  String get gamesScreenSubtitle;

  /// Muted line under the games hub subtitle. {count} is how many of today's four boards the player has not finished yet.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{all done today} =1{one left today} other{{count} left today}}'**
  String gamesRemaining(num count);

  /// Shown on the games hub when today's boards could not be fetched at all — a network failure, not an empty day.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t load today\'s games'**
  String get gamesLoadFailed;

  /// All-caps action under the games hub's load-failure message; refetches today's boards.
  ///
  /// In en, this message translates to:
  /// **'TRY AGAIN'**
  String get gamesRetry;

  /// Name of the Queens daily game, shown on its tile and as the title of its board screen. Lowercase, house style. The game is about placing crowns on a coloured grid.
  ///
  /// In en, this message translates to:
  /// **'queens'**
  String get gameQueensName;

  /// Queens' rules in one line, under its title. Exactly one crown goes in each row, each column and each coloured region, and no two crowns may be adjacent, including diagonally.
  ///
  /// In en, this message translates to:
  /// **'one crown per row, column and colour — never touching'**
  String get gameQueensRule;

  /// Name of the Tango daily game, shown on its tile and as the title of its board screen. Lowercase, house style. The game fills a grid with suns and moons.
  ///
  /// In en, this message translates to:
  /// **'tango'**
  String get gameTangoName;

  /// Tango's rules in one line, under its title. Each row and column holds three of each symbol, and the same symbol may never appear three times consecutively.
  ///
  /// In en, this message translates to:
  /// **'three suns, three moons, never three in a row'**
  String get gameTangoRule;

  /// Name of the Zip daily game, shown on its tile and as the title of its board screen. Lowercase, house style. The game draws a single line through every square of a grid.
  ///
  /// In en, this message translates to:
  /// **'zip'**
  String get gameZipName;

  /// Zip's rules in one line, under its title. One unbroken line must pass through every square exactly once while visiting the numbered dots in ascending order.
  ///
  /// In en, this message translates to:
  /// **'one line through every square, numbers in order'**
  String get gameZipRule;

  /// Name of the Mini Sudoku daily game, shown on its tile and as the title of its board screen. Lowercase, house style. A 6x6 sudoku rather than the usual 9x9.
  ///
  /// In en, this message translates to:
  /// **'mini sudoku'**
  String get gameSudokuName;

  /// Mini Sudoku's rules in one line, under its title. The grid is 6x6 and its boxes are two rows tall by three columns wide.
  ///
  /// In en, this message translates to:
  /// **'1 to 6 once per row, column and box'**
  String get gameSudokuRule;

  /// Name of the symbol-code puzzle on its tile in the games hub, where it sits beside the four newer boards. It is the same game the dedicated puzzle screen calls 'the puzzle.'; here it needs a shorter name that distinguishes it from its four neighbours.
  ///
  /// In en, this message translates to:
  /// **'the code'**
  String get gameCodeName;

  /// Status on a game tile the viewer has not opened today.
  ///
  /// In en, this message translates to:
  /// **'not played'**
  String get gameStatusUnplayed;

  /// Status on a game tile the viewer has started but not finished today.
  ///
  /// In en, this message translates to:
  /// **'in progress'**
  String get gameStatusUnfinished;

  /// Status shown in place of a time, on a tile or a leaderboard row, when the player asked to see the answer instead of solving the board.
  ///
  /// In en, this message translates to:
  /// **'gave up'**
  String get gameStatusGaveUp;

  /// Small badge next to a solved time on a game tile. {rank} is the viewer's 1-based place among friends who have finished that board today.
  ///
  /// In en, this message translates to:
  /// **'#{rank}'**
  String gameRankBadge(Object rank);

  /// Tooltip on the pause control in a game board's top bar. Stops the stopwatch and hides the board.
  ///
  /// In en, this message translates to:
  /// **'pause'**
  String get gamePause;

  /// Tooltip on the same control while a game board is paused. Restarts the stopwatch and uncovers the board.
  ///
  /// In en, this message translates to:
  /// **'resume'**
  String get gameResume;

  /// Headline on the card that covers a game board while it is paused.
  ///
  /// In en, this message translates to:
  /// **'paused'**
  String get gamePausedTitle;

  /// Explains the pause card. The board is deliberately covered as well as the clock stopped, so pausing cannot be used as free thinking time.
  ///
  /// In en, this message translates to:
  /// **'the clock is stopped and the board is hidden'**
  String get gamePausedBody;

  /// Label on the tool that takes back the last move on a game board.
  ///
  /// In en, this message translates to:
  /// **'undo'**
  String get gameUndo;

  /// Label on the tool that wipes a game board back to empty. Only Zip has one, where it erases the whole drawn line.
  ///
  /// In en, this message translates to:
  /// **'clear'**
  String get gameClear;

  /// Label on the tool that reveals one correct square. Counted against the player and shown beside their result.
  ///
  /// In en, this message translates to:
  /// **'hint'**
  String get gameHint;

  /// Label on the Mini Sudoku toggle that makes the keypad write small pencil marks instead of answers.
  ///
  /// In en, this message translates to:
  /// **'notes'**
  String get gameNotes;

  /// Screen-reader label for the backspace key on the Mini Sudoku keypad, which empties the selected square.
  ///
  /// In en, this message translates to:
  /// **'erase'**
  String get gameErase;

  /// Label on the Queens toggle that faintly crosses out every square a placed crown rules out, so the player does not have to track it by hand.
  ///
  /// In en, this message translates to:
  /// **'auto-cross'**
  String get gameAutoCross;

  /// Label on the tool that ends today's board and shows its answer.
  ///
  /// In en, this message translates to:
  /// **'give up'**
  String get gameGiveUp;

  /// Title of the confirmation asked before a player gives up on a board.
  ///
  /// In en, this message translates to:
  /// **'show the answer?'**
  String get gameGiveUpTitle;

  /// Body of the give-up confirmation. States both consequences: the board can no longer be played today, and the result is recorded as a failure.
  ///
  /// In en, this message translates to:
  /// **'today\'s board closes and it goes down as unsolved.'**
  String get gameGiveUpBody;

  /// All-caps dismissal on the give-up confirmation; returns to the board.
  ///
  /// In en, this message translates to:
  /// **'KEEP TRYING'**
  String get gameGiveUpCancel;

  /// All-caps confirmation on the give-up dialog; ends the board and reveals the answer.
  ///
  /// In en, this message translates to:
  /// **'SHOW IT'**
  String get gameGiveUpConfirm;

  /// Headline on the result card once a board is solved. {time} is a stopwatch reading such as 2:41, already formatted and never localized — digits and a colon read the same everywhere and the leaderboard compares them side by side.
  ///
  /// In en, this message translates to:
  /// **'solved in {time}'**
  String gameSolvedTitle(Object time);

  /// Headline on the result card when the player gave up and the board is showing the solution instead of their own work.
  ///
  /// In en, this message translates to:
  /// **'today\'s answer'**
  String get gameGaveUpTitle;

  /// Shown under a result instead of a rank when nobody else has finished that board yet. Avoids reporting a podium of one.
  ///
  /// In en, this message translates to:
  /// **'first one in today'**
  String get gameFirstInToday;

  /// Shown under a result. {place} is the viewer's 1-based position and {total} how many friends have finished that board today. 'so far' because more people will finish later and the position can slip. NOTE: parameters are emitted in ALPHABETICAL order (place, total), which here matches reading order.
  ///
  /// In en, this message translates to:
  /// **'{place} of {total} so far'**
  String gameRankLine(Object place, Object total);

  /// Part of the advisory line under a game result. {count} is how many moves broke a rule. Never used to rank anyone — it is shown, not scored.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 mistake} other{{count} mistakes}}'**
  String gameMistakeCount(num count);

  /// Part of the advisory line under a game result. {count} is how many squares the player had revealed for them.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hint} other{{count} hints}}'**
  String gameHintCount(num count);

  /// All-caps header above the per-game leaderboard of friends who have finished that board today, fastest first.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S TIMES'**
  String get gameStandingsLabel;

  /// Muted line where a game's leaderboard would be, when no friend — and not the viewer either — has completed that board today.
  ///
  /// In en, this message translates to:
  /// **'nobody\'s finished this one yet'**
  String get gameStandingsEmpty;

  /// All-caps action on a finished game's result card; copies a one-line result to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'COPY RESULT'**
  String get gameShare;

  /// Confirmation shown after a game result is copied to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'copied — paste it to a friend'**
  String get gameShareCopied;

  /// The whole copied game result, one line. {name} is the game's own localized name, {number} the day's edition number, {time} a stopwatch reading or the localized 'gave up'. 'MonkeyHub' is a proper noun — keep it identical across locales. NOTE: parameters are emitted in ALPHABETICAL order (name, number, time), which here matches reading order.
  ///
  /// In en, this message translates to:
  /// **'MonkeyHub {name} №{number} — {time}'**
  String gameShareLine(Object name, Object number, Object time);

  /// Tooltip on the back arrow in a game board's top bar, which returns to the games hub.
  ///
  /// In en, this message translates to:
  /// **'all games'**
  String get gameBackToHub;

  /// Screen-reader label for the running stopwatch in a game board's top bar.
  ///
  /// In en, this message translates to:
  /// **'elapsed time'**
  String get gameElapsedSemantic;

  /// Error shown when a submitted game board does not actually satisfy its rules — normally only reachable from a stale screen.
  ///
  /// In en, this message translates to:
  /// **'that board isn\'t finished yet'**
  String get gameErrorNotSolved;

  /// Error shown when an action arrives for a board the player has already completed or given up on today.
  ///
  /// In en, this message translates to:
  /// **'you already finished today\'s'**
  String get gameErrorAlreadyFinished;

  /// Error shown when a hint is asked for on a board that has none. Zip is the case: any line covering every square in order wins, so there is no single next-correct move to point at.
  ///
  /// In en, this message translates to:
  /// **'no hint for this one'**
  String get gameErrorNoHint;

  /// Generic error when a daily-game action fails for an unrecognised reason.
  ///
  /// In en, this message translates to:
  /// **'couldn\'t reach the games — try again'**
  String get gameErrorGeneric;

  /// Screen-reader label and tooltip for the small question-mark button on a game tile, which opens the sheet explaining that game.
  ///
  /// In en, this message translates to:
  /// **'how to play'**
  String get gameInfoOpen;

  /// All-caps eyebrow above the game's name at the top of the how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'HOW TO PLAY'**
  String get gameInfoLabel;

  /// All-caps header above the bulleted rules in the how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'THE RULES'**
  String get gameInfoRulesLabel;

  /// All-caps header above the line explaining what to tap or drag, in the how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'CONTROLS'**
  String get gameInfoControlsLabel;

  /// Closing line of the how-to-play sheet for the four timed boards. Says both how the stopwatch behaves and what winning means, because a player should not discover either by seeing their name on a leaderboard.
  ///
  /// In en, this message translates to:
  /// **'the clock runs while the board is on screen and stops when you pause or leave. finish fastest and you top today\'s list.'**
  String get gameInfoScoringTimed;

  /// Closing line of the how-to-play sheet for the symbol-code puzzle — the one game on the hub that is ranked by guesses rather than by time.
  ///
  /// In en, this message translates to:
  /// **'scored by how few guesses it takes, not by the clock.'**
  String get gameInfoScoringGuesses;

  /// Muted footnote at the bottom of the how-to-play sheet. The point being made is that the boards are identical for every player worldwide, which is what makes comparing results meaningful.
  ///
  /// In en, this message translates to:
  /// **'everyone gets the same board today.'**
  String get gameInfoSameForEveryone;

  /// All-caps button that closes the how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'GOT IT'**
  String get gameInfoGotIt;

  /// One-sentence description of what the player is trying to do in Queens, at the top of its how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'place one crown in every row, column and colour.'**
  String get gameInfoQueensGoal;

  /// First rule bullet in the Queens how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'eight crowns: one in each row, one in each column.'**
  String get gameInfoQueensRule1;

  /// Second rule bullet in the Queens how-to-play sheet. The board is divided into coloured regions and each holds exactly one crown.
  ///
  /// In en, this message translates to:
  /// **'each colour block gets exactly one crown too.'**
  String get gameInfoQueensRule2;

  /// Third rule bullet in the Queens how-to-play sheet. Crowns may not be adjacent horizontally, vertically or diagonally.
  ///
  /// In en, this message translates to:
  /// **'no two crowns may touch — not even at a corner.'**
  String get gameInfoQueensRule3;

  /// Explains the Queens board's controls: a tap cycles a square through empty, the player's own cross, and a crown.
  ///
  /// In en, this message translates to:
  /// **'tap a square once for a cross to rule it out, again for a crown, again to clear it.'**
  String get gameInfoQueensControls;

  /// One-sentence description of what the player is trying to do in Tango, at the top of its how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'fill the grid with suns and moons.'**
  String get gameInfoTangoGoal;

  /// First rule bullet in the Tango how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'every row and column holds three suns and three moons.'**
  String get gameInfoTangoRule1;

  /// Second rule bullet in the Tango how-to-play sheet. No run of three identical symbols horizontally or vertically.
  ///
  /// In en, this message translates to:
  /// **'never three of the same next to each other, across or down.'**
  String get gameInfoTangoRule2;

  /// Third rule bullet in the Tango how-to-play sheet. Explains the two operators printed on the edges between adjacent squares. Keep the '=' and '×' symbols as they are.
  ///
  /// In en, this message translates to:
  /// **'= between two squares means they match. × means they differ.'**
  String get gameInfoTangoRule3;

  /// Explains the Tango board's controls. 'printed squares' are the ones the puzzle starts with, which cannot be changed.
  ///
  /// In en, this message translates to:
  /// **'tap a square for a sun, again for a moon, again to clear. printed squares don\'t move.'**
  String get gameInfoTangoControls;

  /// One-sentence description of what the player is trying to do in Zip, at the top of its how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'draw one line that goes through every square.'**
  String get gameInfoZipGoal;

  /// First rule bullet in the Zip how-to-play sheet. The board has numbered dots and the line must begin at 1 and end at the highest one.
  ///
  /// In en, this message translates to:
  /// **'start on 1 and finish on the last number.'**
  String get gameInfoZipRule1;

  /// Second rule bullet in the Zip how-to-play sheet. The numbered dots must be visited in ascending order.
  ///
  /// In en, this message translates to:
  /// **'touch the numbers in order along the way.'**
  String get gameInfoZipRule2;

  /// Third rule bullet in the Zip how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'every square gets used exactly once.'**
  String get gameInfoZipRule3;

  /// Explains the Zip board's controls. The line is drawn with a drag and retracts when the finger moves back along it.
  ///
  /// In en, this message translates to:
  /// **'drag your finger to draw. drag back over the line to rub it out.'**
  String get gameInfoZipControls;

  /// One-sentence description of what the player is trying to do in Mini Sudoku, at the top of its how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'fill the grid with the digits 1 to 6.'**
  String get gameInfoSudokuGoal;

  /// First rule bullet in the Mini Sudoku how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'each row uses 1 to 6, once each.'**
  String get gameInfoSudokuRule1;

  /// Second rule bullet in the Mini Sudoku how-to-play sheet. Reads as a continuation of the row rule immediately above it.
  ///
  /// In en, this message translates to:
  /// **'so does each column.'**
  String get gameInfoSudokuRule2;

  /// Third rule bullet in the Mini Sudoku how-to-play sheet. The 6x6 grid is divided into boxes two rows tall and three columns wide.
  ///
  /// In en, this message translates to:
  /// **'and so does each 2x3 box.'**
  String get gameInfoSudokuRule3;

  /// Explains the Mini Sudoku board's controls, including the notes toggle that switches the keypad to writing small pencil marks.
  ///
  /// In en, this message translates to:
  /// **'tap a square, then a digit. tap the same digit again to clear it. notes writes small pencil marks instead.'**
  String get gameInfoSudokuControls;

  /// One-sentence description of what the player is trying to do in the symbol-code puzzle, at the top of its how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'work out the hidden four-symbol code.'**
  String get gameInfoCodeGoal;

  /// First rule bullet in the symbol-code puzzle's how-to-play sheet.
  ///
  /// In en, this message translates to:
  /// **'six tries, and the code never repeats a symbol.'**
  String get gameInfoCodeRule1;

  /// Second rule bullet in the symbol-code puzzle's how-to-play sheet, describing the colour a correctly-placed symbol is shown in.
  ///
  /// In en, this message translates to:
  /// **'green means right symbol, right place.'**
  String get gameInfoCodeRule2;

  /// Third rule bullet in the symbol-code puzzle's how-to-play sheet, describing the colour a misplaced symbol is shown in.
  ///
  /// In en, this message translates to:
  /// **'yellow means right symbol, wrong place.'**
  String get gameInfoCodeRule3;

  /// Explains the symbol-code puzzle's controls: symbols are tapped onto the current row and the row is then submitted for feedback.
  ///
  /// In en, this message translates to:
  /// **'tap symbols to build a guess, then send it. the board tells you how close you were.'**
  String get gameInfoCodeControls;

  /// Room-list display name for the self-chat room every account has (name starting with 'dm:self:'), shown in place of a friend's display name in RoomCard/RoomGridTile.
  ///
  /// In en, this message translates to:
  /// **'Saved Messages'**
  String get savedMessagesTitle;

  /// All-caps mono section label above the pinned group in the chat list (Saved Messages plus any user-pinned rooms), matching the TYPE/NATURE/STATUS dimension-label style in RoomFilterPanel.
  ///
  /// In en, this message translates to:
  /// **'PINNED'**
  String get homeScreenPinnedSectionLabel;

  /// Lowercase empty-state shown in the chat list when the pull-reveal search field's query matches no chats. {query} is the raw text the user typed.
  ///
  /// In en, this message translates to:
  /// **'no chats match \"{query}\"'**
  String homeScreenNoSearchResults(Object query);

  /// Hint text in the search field revealed by pulling down at the top of the chat list.
  ///
  /// In en, this message translates to:
  /// **'search chats…'**
  String get pullRevealSearchHint;

  /// Accessibility label for the chevron that collapses the pull-reveal panel (search field + Archived Chats row) back to hidden.
  ///
  /// In en, this message translates to:
  /// **'Hide search and archived chats'**
  String get pullRevealCollapseSemanticLabel;

  /// Label and accessibility label for the row inside the pull-reveal panel that opens the Archived Chats sheet. {count} is how many rooms are currently archived; the row is hidden entirely when count is 0.
  ///
  /// In en, this message translates to:
  /// **'archived chats ({count})'**
  String archivedChatsFolderLabel(Object count);

  /// All-caps header of the Archived Chats sheet when there are currently zero archived rooms (only reachable if the last one is unarchived while the sheet is open).
  ///
  /// In en, this message translates to:
  /// **'ARCHIVED CHATS'**
  String get archivedChatsSheetTitle;

  /// All-caps header of the Archived Chats sheet showing how many rooms are archived, e.g. 'ARCHIVED CHATS · 3'.
  ///
  /// In en, this message translates to:
  /// **'ARCHIVED CHATS · {count}'**
  String archivedChatsSheetTitleCount(Object count);

  /// Lowercase empty-state sentence shown inside the Archived Chats sheet if the last archived room is unarchived while the sheet is still open.
  ///
  /// In en, this message translates to:
  /// **'nothing archived anymore'**
  String get archivedChatsSheetEmptyMessage;

  /// All-caps pill badge label (and tooltip) shown on a chat-list row the viewer has pinned, matching the VisibilityBadge/LockedBadge style. Per-viewer state, so it never appears for anyone but the person who pinned it.
  ///
  /// In en, this message translates to:
  /// **'PINNED'**
  String get pinnedBadgeLabel;

  /// All-caps row label in the chat-list long-press action menu that pins the chat, matching messageActionMenuPinLabel's style.
  ///
  /// In en, this message translates to:
  /// **'PIN CHAT'**
  String get chatRowActionMenuPinLabel;

  /// All-caps row label in the chat-list long-press action menu that unpins an already-pinned chat.
  ///
  /// In en, this message translates to:
  /// **'UNPIN CHAT'**
  String get chatRowActionMenuUnpinLabel;

  /// All-caps row label in the chat-list long-press action menu that archives the chat, removing it from the main list.
  ///
  /// In en, this message translates to:
  /// **'ARCHIVE CHAT'**
  String get chatRowActionMenuArchiveLabel;

  /// All-caps row label in the chat-list long-press action menu (and inside the Archived Chats sheet) that restores an archived chat to the main list.
  ///
  /// In en, this message translates to:
  /// **'UNARCHIVE CHAT'**
  String get chatRowActionMenuUnarchiveLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'es',
    'fr',
    'hi',
    'ja',
    'ko',
    'pt',
    'sv',
    'tr',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'pt':
      {
        switch (locale.countryCode) {
          case 'BR':
            return AppLocalizationsPtBr();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'sv':
      return AppLocalizationsSv();
    case 'tr':
      return AppLocalizationsTr();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
