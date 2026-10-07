import 'package:worklaw_maroc/l10n/generated/app_localizations.dart';

import '../domain/auth_validators.dart';

String? mapValidationError(ValidationError? error, AppLocalizations l10n) {
  switch (error) {
    case null:
      return null;
    case ValidationError.required:
      return l10n.validationRequired;
    case ValidationError.invalidEmail:
      return l10n.validationInvalidEmail;
    case ValidationError.tooLong:
      return l10n.validationTooLong(signupTextFieldMaxLength);
    case ValidationError.passwordTooShort:
      return l10n.validationPasswordTooShort(supabaseMinPasswordLength);
    case ValidationError.passwordsDontMatch:
      return l10n.validationPasswordsDontMatch;
  }
}
