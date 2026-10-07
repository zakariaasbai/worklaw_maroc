import 'package:flutter_test/flutter_test.dart';
import 'package:worklaw_maroc/features/auth/domain/auth_validators.dart';

void main() {
  group('validateRequired', () {
    test('flags null and empty/whitespace-only values', () {
      expect(validateRequired(null), ValidationError.required);
      expect(validateRequired(''), ValidationError.required);
      expect(validateRequired('   '), ValidationError.required);
      expect(validateRequired('ok'), isNull);
    });
  });

  group('validateMaxLength', () {
    test('flags required when empty, tooLong when over the limit', () {
      expect(validateMaxLength('', 5), ValidationError.required);
      expect(validateMaxLength('123456', 5), ValidationError.tooLong);
      expect(validateMaxLength('12345', 5), isNull);
    });
  });

  group('validateEmail', () {
    test('flags required, invalid format, and accepts a valid email', () {
      expect(validateEmail(''), ValidationError.required);
      expect(validateEmail('not-an-email'), ValidationError.invalidEmail);
      expect(validateEmail('a@b'), ValidationError.invalidEmail);
      expect(validateEmail('a@b.com'), isNull);
    });
  });

  group('validatePassword', () {
    test('flags required and too-short, accepts the configured minimum', () {
      expect(validatePassword(''), ValidationError.required);
      expect(
        validatePassword('a' * (supabaseMinPasswordLength - 1)),
        ValidationError.passwordTooShort,
      );
      expect(
        validatePassword('a' * supabaseMinPasswordLength),
        isNull,
      );
    });
  });

  group('validatePasswordsMatch', () {
    test('flags mismatches and accepts identical values', () {
      expect(
        validatePasswordsMatch('secret123', 'different'),
        ValidationError.passwordsDontMatch,
      );
      expect(validatePasswordsMatch('secret123', 'secret123'), isNull);
    });
  });
}
