class PasswordRules {
  const PasswordRules({required this.length, required this.hasLetter, required this.hasDigit, required this.noSpaces});
  final bool length;
  final bool hasLetter;
  final bool hasDigit;
  final bool noSpaces;

  bool get isValid => length && hasLetter && hasDigit && noSpaces;

  /// Exactly 6 characters, at least one letter, at least one digit, no whitespace.
  factory PasswordRules.evaluate(String p) => PasswordRules(
        length: p.length == 6,
        hasLetter: RegExp(r'[A-Za-z]').hasMatch(p),
        hasDigit: RegExp(r'\d').hasMatch(p),
        noSpaces: p.isNotEmpty && !RegExp(r'\s').hasMatch(p),
      );

  /// First unmet rule as a message, or null when valid.
  String? get firstError {
    if (!length) return 'Password must be exactly 6 characters';
    if (!hasLetter) return 'Include at least one letter';
    if (!hasDigit) return 'Include at least one digit';
    if (!noSpaces) return 'No spaces allowed';
    return null;
  }
}
