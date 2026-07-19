import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DhyanLog'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Meditation attendance'**
  String get appTagline;

  /// No description provided for @loginIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Heartfulness ID'**
  String get loginIdLabel;

  /// No description provided for @loginIdHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. HFN-ABHY-001'**
  String get loginIdHint;

  /// No description provided for @loginSendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get loginSendCode;

  /// No description provided for @loginEnterId.
  ///
  /// In en, this message translates to:
  /// **'Enter your Heartfulness ID'**
  String get loginEnterId;

  /// No description provided for @loginHelp.
  ///
  /// In en, this message translates to:
  /// **'We send a one-time code to the email or phone on your Heartfulness record. Try a seeded ID such as HFN-PREC-001 (preceptor) or HFN-ABHY-001 (abhyasi).'**
  String get loginHelp;

  /// No description provided for @loginCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code sent to {destination}.'**
  String loginCodeSentTo(String destination);

  /// No description provided for @loginCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get loginCodeLabel;

  /// No description provided for @loginVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get loginVerify;

  /// No description provided for @loginUseDifferentId.
  ///
  /// In en, this message translates to:
  /// **'Use a different ID'**
  String get loginUseDifferentId;

  /// No description provided for @loginEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the code you received'**
  String get loginEnterCode;

  /// No description provided for @commonSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get commonSomethingWrong;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @errorOffline.
  ///
  /// In en, this message translates to:
  /// **'You appear to be offline. Check your connection and try again.'**
  String get errorOffline;

  /// No description provided for @errorSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorSessionExpired;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'The server had a problem. Please try again in a moment.'**
  String get errorServer;

  /// No description provided for @errorLocationOff.
  ///
  /// In en, this message translates to:
  /// **'Location (GPS) is turned off on this device. Turn it on and try again.'**
  String get errorLocationOff;

  /// No description provided for @errorLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied. Allow it so we can find the session near you.'**
  String get errorLocationDenied;

  /// No description provided for @errorLocationBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked. Enable it for DhyanLog in your device settings.'**
  String get errorLocationBlocked;

  /// No description provided for @errorLocationTimeout.
  ///
  /// In en, this message translates to:
  /// **'Could not get a GPS fix. Try again in the open, or join with the session code.'**
  String get errorLocationTimeout;

  /// No description provided for @homeLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get homeLogOut;

  /// No description provided for @homeDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get homeDeleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This deletes your app login so you can no longer sign in. Your Heartfulness membership and past attendance records are kept by the organization and are not removed. This cannot be undone.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete my login'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'Could not delete your account. Please try again.'**
  String get deleteAccountError;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @rolePreceptor.
  ///
  /// In en, this message translates to:
  /// **'Preceptor'**
  String get rolePreceptor;

  /// No description provided for @roleAbhyasi.
  ///
  /// In en, this message translates to:
  /// **'Abhyasi'**
  String get roleAbhyasi;

  /// No description provided for @roleMaster.
  ///
  /// In en, this message translates to:
  /// **'Master'**
  String get roleMaster;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Namaste, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeStartAttendance.
  ///
  /// In en, this message translates to:
  /// **'Start Attendance'**
  String get homeStartAttendance;

  /// No description provided for @homeGiveAttendance.
  ///
  /// In en, this message translates to:
  /// **'Give Attendance'**
  String get homeGiveAttendance;

  /// No description provided for @homeLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get homeLocationLabel;

  /// No description provided for @homeLocationGps.
  ///
  /// In en, this message translates to:
  /// **'My current location (GPS)'**
  String get homeLocationGps;

  /// No description provided for @attendSavedOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved offline'**
  String get attendSavedOfflineTitle;

  /// No description provided for @attendSavedOfflineMessage.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline, so we saved your attendance. It will be recorded automatically when your connection returns.'**
  String get attendSavedOfflineMessage;

  /// No description provided for @attendRecordedTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance recorded'**
  String get attendRecordedTitle;

  /// No description provided for @attendAlreadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Already recorded'**
  String get attendAlreadyTitle;

  /// No description provided for @attendRecordedMessage.
  ///
  /// In en, this message translates to:
  /// **'You have been added to this session.'**
  String get attendRecordedMessage;

  /// No description provided for @attendAlreadyMessage.
  ///
  /// In en, this message translates to:
  /// **'You were already in this session.'**
  String get attendAlreadyMessage;

  /// No description provided for @attendMultipleTitle.
  ///
  /// In en, this message translates to:
  /// **'Multiple sessions nearby'**
  String get attendMultipleTitle;

  /// No description provided for @attendNoneTitle.
  ///
  /// In en, this message translates to:
  /// **'No session found nearby'**
  String get attendNoneTitle;

  /// No description provided for @attendMultipleMessage.
  ///
  /// In en, this message translates to:
  /// **'We could not tell which session you are in. Enter the code shown by your preceptor.'**
  String get attendMultipleMessage;

  /// No description provided for @attendNoneMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter the code shown by your preceptor, or scan their QR.'**
  String get attendNoneMessage;

  /// No description provided for @attendCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Session code'**
  String get attendCodeLabel;

  /// No description provided for @attendCodeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. K7M2PQ'**
  String get attendCodeHint;

  /// No description provided for @attendJoinWithCode.
  ///
  /// In en, this message translates to:
  /// **'Join with code'**
  String get attendJoinWithCode;

  /// No description provided for @attendRetryGps.
  ///
  /// In en, this message translates to:
  /// **'Retry GPS'**
  String get attendRetryGps;

  /// No description provided for @attendContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get attendContinue;

  /// No description provided for @attendNearbyHeader.
  ///
  /// In en, this message translates to:
  /// **'Sessions detected near you:'**
  String get attendNearbyHeader;

  /// No description provided for @attendCandidateCode.
  ///
  /// In en, this message translates to:
  /// **'Code {code}'**
  String attendCandidateCode(String code);

  /// No description provided for @attendCandidateCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 attending} other{{count} attending}}'**
  String attendCandidateCount(int count);

  /// No description provided for @sessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Session'**
  String get sessionTitle;

  /// No description provided for @sessionAttendees.
  ///
  /// In en, this message translates to:
  /// **'Attendees'**
  String get sessionAttendees;

  /// No description provided for @sessionMeditatingFor.
  ///
  /// In en, this message translates to:
  /// **'Meditating for {duration}'**
  String sessionMeditatingFor(String duration);

  /// No description provided for @sessionEndAttendance.
  ///
  /// In en, this message translates to:
  /// **'End Attendance'**
  String get sessionEndAttendance;

  /// No description provided for @sessionStartMeditation.
  ///
  /// In en, this message translates to:
  /// **'Start Meditation'**
  String get sessionStartMeditation;

  /// No description provided for @sessionStopMeditation.
  ///
  /// In en, this message translates to:
  /// **'Stop Meditation'**
  String get sessionStopMeditation;

  /// No description provided for @sessionSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Session saved'**
  String get sessionSavedTitle;

  /// No description provided for @sessionSavedBody.
  ///
  /// In en, this message translates to:
  /// **'Finalized one record:\n• {count, plural, =1{1 attendee} other{{count} attendees}}\n• {minutes, plural, =1{1 min} other{{minutes} min}} meditation\n(written as a single row — the only DB write)'**
  String sessionSavedBody(int count, int minutes);

  /// No description provided for @sessionStatusCollecting.
  ///
  /// In en, this message translates to:
  /// **'Collecting attendance'**
  String get sessionStatusCollecting;

  /// No description provided for @sessionStatusMeditating.
  ///
  /// In en, this message translates to:
  /// **'Meditation in progress'**
  String get sessionStatusMeditating;

  /// No description provided for @sessionStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get sessionStatusEnded;

  /// No description provided for @sessionJoinPrompt.
  ///
  /// In en, this message translates to:
  /// **'Abhyasis join with this code'**
  String get sessionJoinPrompt;

  /// No description provided for @sessionCopyJoinLink.
  ///
  /// In en, this message translates to:
  /// **'Copy join link'**
  String get sessionCopyJoinLink;

  /// No description provided for @meditationWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting to begin'**
  String get meditationWaitingTitle;

  /// No description provided for @meditationWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'Your attendance is recorded. Stay on this screen — your phone will be silenced as soon as the preceptor begins the meditation.'**
  String get meditationWaitingBody;

  /// No description provided for @meditationInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Meditation in progress'**
  String get meditationInProgressTitle;

  /// No description provided for @meditationCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Meditation complete'**
  String get meditationCompleteTitle;

  /// No description provided for @meditationCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =0{Your sitting has ended.} =1{You meditated for 1 minute.} other{You meditated for {minutes} minutes.}}'**
  String meditationCompleteBody(int minutes);

  /// No description provided for @meditationAttendees.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 meditating} other{{count} meditating}}'**
  String meditationAttendees(int count);

  /// No description provided for @meditationMuted.
  ///
  /// In en, this message translates to:
  /// **'Notifications silenced'**
  String get meditationMuted;

  /// No description provided for @meditationMuteOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications not silenced'**
  String get meditationMuteOff;

  /// No description provided for @meditationMuteDisabled.
  ///
  /// In en, this message translates to:
  /// **'Silencing is turned off in your settings.'**
  String get meditationMuteDisabled;

  /// No description provided for @meditationMuteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'iOS does not let apps silence notifications. Turn on a Focus mode to avoid interruptions.'**
  String get meditationMuteUnsupported;

  /// No description provided for @meditationMutePermission.
  ///
  /// In en, this message translates to:
  /// **'Allow DhyanLog to silence notifications during meditation.'**
  String get meditationMutePermission;

  /// No description provided for @meditationMuteGrant.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get meditationMuteGrant;

  /// No description provided for @meditationLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get meditationLeave;

  /// No description provided for @meditationLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this screen?'**
  String get meditationLeaveTitle;

  /// No description provided for @meditationLeaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your attendance is already recorded and will not be lost. Leaving restores your notifications.'**
  String get meditationLeaveBody;

  /// No description provided for @meditationBackHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get meditationBackHome;

  /// No description provided for @homeHistory.
  ///
  /// In en, this message translates to:
  /// **'My meditations'**
  String get homeHistory;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'My meditations'**
  String get historyTitle;

  /// No description provided for @historyEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No meditations yet'**
  String get historyEmptyTitle;

  /// No description provided for @historyEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Sessions you attend will appear here once they finish.'**
  String get historyEmptyBody;

  /// No description provided for @historyLed.
  ///
  /// In en, this message translates to:
  /// **'You led'**
  String get historyLed;

  /// No description provided for @historyDuration.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 min} other{{minutes} min}}'**
  String historyDuration(int minutes);

  /// No description provided for @historyDurationUnknown.
  ///
  /// In en, this message translates to:
  /// **'Duration not recorded'**
  String get historyDurationUnknown;

  /// No description provided for @historySummarySessions.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 session} other{{count} sessions}}'**
  String historySummarySessions(int count);

  /// No description provided for @historySummaryTime.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m total'**
  String historySummaryTime(int hours, int minutes);

  /// No description provided for @historyLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get historyLoadMore;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsMuteTitle.
  ///
  /// In en, this message translates to:
  /// **'Silence notifications while meditating'**
  String get settingsMuteTitle;

  /// No description provided for @settingsMuteBody.
  ///
  /// In en, this message translates to:
  /// **'Turns on Do Not Disturb when a meditation begins, and restores your previous settings when it ends. Alarms still ring.'**
  String get settingsMuteBody;

  /// No description provided for @settingsMuteUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device. iOS gives apps no way to control Focus or Do Not Disturb.'**
  String get settingsMuteUnsupported;

  /// No description provided for @settingsMutePermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Needs Do Not Disturb access'**
  String get settingsMutePermissionNeeded;

  /// No description provided for @settingsMuteGrantAccess.
  ///
  /// In en, this message translates to:
  /// **'Grant access'**
  String get settingsMuteGrantAccess;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
