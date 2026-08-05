// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DhyanLog';

  @override
  String get appTagline => 'Meditation attendance';

  @override
  String get loginIdLabel => 'Heartfulness ID';

  @override
  String get loginIdHint => 'e.g. HFN-ABHY-001';

  @override
  String get loginSendCode => 'Send code';

  @override
  String get loginEnterId => 'Enter your Heartfulness ID';

  @override
  String get loginHelp =>
      'We send a one-time code to the email or phone on your Heartfulness record. Try a seeded ID such as HFN-PREC-001 (preceptor) or HFN-ABHY-001 (abhyasi).';

  @override
  String loginCodeSentTo(String destination) {
    return 'Enter the 6-digit code sent to $destination.';
  }

  @override
  String get loginCodeLabel => 'Code';

  @override
  String get loginVerify => 'Verify';

  @override
  String get loginUseDifferentId => 'Use a different ID';

  @override
  String get loginEnterCode => 'Enter the code you received';

  @override
  String get commonSomethingWrong => 'Something went wrong. Please try again.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get errorOffline =>
      'You appear to be offline. Check your connection and try again.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorServer =>
      'The server had a problem. Please try again in a moment.';

  @override
  String get errorLocationOff =>
      'Location (GPS) is turned off on this device. Turn it on and try again.';

  @override
  String get errorLocationDenied =>
      'Location permission was denied. Allow it so we can find the session near you.';

  @override
  String get errorLocationBlocked =>
      'Location permission is blocked. Enable it for DhyanLog in your device settings.';

  @override
  String get errorLocationTimeout =>
      'Could not get a GPS fix. Try again in the open, or join with the session code.';

  @override
  String get homeLogOut => 'Log out';

  @override
  String get homeDeleteAccount => 'Delete account';

  @override
  String get deleteAccountTitle => 'Delete account?';

  @override
  String get deleteAccountBody =>
      'This deletes your app login so you can no longer sign in. Your Heartfulness membership and past attendance records are kept by the organization and are not removed. This cannot be undone.';

  @override
  String get deleteAccountConfirm => 'Delete my login';

  @override
  String get deleteAccountError =>
      'Could not delete your account. Please try again.';

  @override
  String get commonDone => 'Done';

  @override
  String get commonOk => 'OK';

  @override
  String get rolePreceptor => 'Preceptor';

  @override
  String get roleAbhyasi => 'Abhyasi';

  @override
  String get roleMaster => 'Master';

  @override
  String homeGreeting(String name) {
    return 'Namaste, $name';
  }

  @override
  String get homeStartAttendance => 'Start Attendance';

  @override
  String get homeGiveAttendance => 'Give Attendance';

  @override
  String get homeLocationLabel => 'Your location';

  @override
  String get homeLocationGps => 'My current location (GPS)';

  @override
  String get attendSavedOfflineTitle => 'Saved offline';

  @override
  String get attendSavedOfflineMessage =>
      'You\'re offline, so we saved your attendance. It will be recorded automatically when your connection returns.';

  @override
  String get attendRecordedTitle => 'Attendance recorded';

  @override
  String get attendAlreadyTitle => 'Already recorded';

  @override
  String get attendRecordedMessage => 'You have been added to this session.';

  @override
  String get attendAlreadyMessage => 'You were already in this session.';

  @override
  String get attendMultipleTitle => 'Multiple sessions nearby';

  @override
  String get attendNoneTitle => 'No session found nearby';

  @override
  String get attendMultipleMessage =>
      'We could not tell which session you are in. Enter the code shown by your preceptor.';

  @override
  String get attendNoneMessage =>
      'Enter the code shown by your preceptor, or scan their QR.';

  @override
  String get attendCodeLabel => 'Session code';

  @override
  String get attendCodeHint => 'e.g. K7M2PQ';

  @override
  String get attendJoinWithCode => 'Join with code';

  @override
  String get attendRetryGps => 'Retry GPS';

  @override
  String get attendContinue => 'Continue';

  @override
  String get attendNearbyHeader => 'Sessions detected near you:';

  @override
  String attendCandidateCode(String code) {
    return 'Code $code';
  }

  @override
  String attendCandidateCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attending',
      one: '1 attending',
    );
    return '$_temp0';
  }

  @override
  String get sessionTitle => 'Session';

  @override
  String get sessionAttendees => 'Attendees';

  @override
  String get sessionCheckedInTitle => 'Checked in';

  @override
  String get sessionNoAttendeesYet => 'No one has checked in yet';

  @override
  String get sessionRosterCapped => 'Large gathering — showing the count only';

  @override
  String sessionMeditatingFor(String duration) {
    return 'Meditating for $duration';
  }

  @override
  String get sessionStopMeditation => 'Stop Meditation';

  @override
  String get sessionSavedTitle => 'Session saved';

  @override
  String sessionSavedBody(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attendees',
      one: '1 attendee',
    );
    String _temp1 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      one: '1 min',
    );
    return 'Finalized one record:\n• $_temp0\n• $_temp1 meditation\n(written as a single row — the only DB write)';
  }

  @override
  String get sessionStatusCollecting => 'Collecting attendance';

  @override
  String get sessionStatusMeditating => 'Meditation in progress';

  @override
  String get sessionStatusEnded => 'Ended';

  @override
  String get sessionJoinPrompt => 'Abhyasis join with this code';

  @override
  String get sessionCopyJoinLink => 'Copy join link';

  @override
  String get meditationWaitingTitle => 'Waiting to begin';

  @override
  String get meditationWaitingBody =>
      'Your attendance is recorded. Stay on this screen — your phone will be silenced as soon as the preceptor begins the meditation.';

  @override
  String get meditationInProgressTitle => 'Meditation in progress';

  @override
  String get meditationCompleteTitle => 'Meditation complete';

  @override
  String meditationCompleteBody(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'You meditated for $minutes minutes.',
      one: 'You meditated for 1 minute.',
      zero: 'Your sitting has ended.',
    );
    return '$_temp0';
  }

  @override
  String meditationAttendees(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meditating',
      one: '1 meditating',
    );
    return '$_temp0';
  }

  @override
  String get meditationMuted => 'Notifications silenced';

  @override
  String get meditationMuteOff => 'Notifications not silenced';

  @override
  String get meditationMuteDisabled =>
      'Silencing is turned off in your settings.';

  @override
  String get meditationMuteUnsupported =>
      'iOS does not let apps silence notifications. Turn on a Focus mode to avoid interruptions.';

  @override
  String get meditationMutePermission =>
      'Allow DhyanLog to silence notifications during meditation.';

  @override
  String get meditationMuteGrant => 'Allow';

  @override
  String get meditationLeave => 'Leave';

  @override
  String get meditationLeaveTitle => 'Leave this screen?';

  @override
  String get meditationLeaveBody =>
      'Your attendance is already recorded and will not be lost. Leaving restores your notifications.';

  @override
  String get meditationBackHome => 'Back to home';

  @override
  String get homeHistory => 'My meditations';

  @override
  String get homeSettings => 'Settings';

  @override
  String get historyTitle => 'My meditations';

  @override
  String get historyEmptyTitle => 'No meditations yet';

  @override
  String get historyEmptyBody =>
      'Sessions you attend will appear here once they finish.';

  @override
  String get historyLed => 'You led';

  @override
  String historyDuration(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String get historyDurationUnknown => 'Duration not recorded';

  @override
  String historySummarySessions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
    );
    return '$_temp0';
  }

  @override
  String historySummaryTime(int hours, int minutes) {
    return '${hours}h ${minutes}m total';
  }

  @override
  String get historyLoadMore => 'Load more';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsMuteTitle => 'Silence notifications while meditating';

  @override
  String get settingsMuteBody =>
      'Turns on Do Not Disturb when a meditation begins, and restores your previous settings when it ends. Alarms still ring.';

  @override
  String get settingsMuteUnsupported =>
      'Not available on this device. iOS gives apps no way to control Focus or Do Not Disturb.';

  @override
  String get settingsMutePermissionNeeded => 'Needs Do Not Disturb access';

  @override
  String get settingsMuteGrantAccess => 'Grant access';
}
