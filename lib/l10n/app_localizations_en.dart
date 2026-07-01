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
}
