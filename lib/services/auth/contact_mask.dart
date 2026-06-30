/// Privacy-safe rendering of the contact an OTP was sent to, for display in the
/// verify step. Reveals just enough for the member to recognise it.
///
/// `asha.rao@example.org` -> `a***@example.org`; `+91 90000 11111` -> `***1111`.
String maskContact(String contact) {
  final value = contact.trim();
  if (value.isEmpty) return '';
  final at = value.indexOf('@');
  if (at > 0) {
    final domain = value.substring(at); // includes '@'
    return '${value[0]}***$domain';
  }
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= 4) return '***$digits';
  return '***${digits.substring(digits.length - 4)}';
}
