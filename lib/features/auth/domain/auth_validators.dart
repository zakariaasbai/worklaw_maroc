/// Pure validation logic — no BuildContext, no l10n, no Supabase. Testable
/// in isolation; screens map these to localized strings at render time.
library;

/// Matches the `organization_name` / `full_name` length limit enforced by
/// handle_new_user() in supabase/migrations/20260917120000_create_organizations_schema.sql.
const signupTextFieldMaxLength = 200;

/// Mirrors the "Minimum password length" configured on the Supabase
/// project (Authentication → Providers → Email). Confirmed at 8 on the
/// remote project as of Milestone 4 — update here if that setting changes.
const supabaseMinPasswordLength = 8;

enum ValidationError {
  required,
  invalidEmail,
  tooLong,
  passwordTooShort,
  passwordsDontMatch,
}

ValidationError? validateRequired(String? value) {
  return (value == null || value.trim().isEmpty)
      ? ValidationError.required
      : null;
}

ValidationError? validateMaxLength(String? value, int maxLength) {
  final requiredError = validateRequired(value);
  if (requiredError != null) return requiredError;
  return value!.trim().length > maxLength ? ValidationError.tooLong : null;
}

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

ValidationError? validateEmail(String? value) {
  final requiredError = validateRequired(value);
  if (requiredError != null) return requiredError;
  return _emailPattern.hasMatch(value!.trim())
      ? null
      : ValidationError.invalidEmail;
}

ValidationError? validatePassword(String? value) {
  final requiredError = validateRequired(value);
  if (requiredError != null) return requiredError;
  return value!.length < supabaseMinPasswordLength
      ? ValidationError.passwordTooShort
      : null;
}

ValidationError? validatePasswordsMatch(String? password, String? confirmation) {
  return password == confirmation ? null : ValidationError.passwordsDontMatch;
}
