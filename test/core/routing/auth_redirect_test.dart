import 'package:flutter_test/flutter_test.dart';
import 'package:worklaw_maroc/core/routing/auth_redirect.dart';

void main() {
  group('authRedirect', () {
    test('sends an unauthenticated user to /login from a protected route', () {
      final result = authRedirect(
        hasSession: false,
        isPasswordRecovery: false,
        location: '/employees',
      );
      expect(result, '/login');
    });

    test('lets an unauthenticated user reach public auth routes', () {
      for (final route in publicAuthRoutes) {
        final result = authRedirect(
          hasSession: false,
          isPasswordRecovery: false,
          location: route,
        );
        expect(result, isNull, reason: 'expected $route to stay reachable');
      }
    });

    test('sends a signed-in user away from public auth routes', () {
      final result = authRedirect(
        hasSession: true,
        isPasswordRecovery: false,
        location: '/login',
      );
      expect(result, '/employees');
    });

    test('lets a signed-in user reach protected routes', () {
      final result = authRedirect(
        hasSession: true,
        isPasswordRecovery: false,
        location: '/employees',
      );
      expect(result, isNull);
    });

    test('password recovery pins the user to /reset-password regardless of location', () {
      final result = authRedirect(
        hasSession: true,
        isPasswordRecovery: true,
        location: '/employees',
      );
      expect(result, '/reset-password');
    });

    test('password recovery allows /reset-password itself', () {
      final result = authRedirect(
        hasSession: true,
        isPasswordRecovery: true,
        location: '/reset-password',
      );
      expect(result, isNull);
    });

    test('password recovery takes priority even over no session', () {
      final result = authRedirect(
        hasSession: false,
        isPasswordRecovery: true,
        location: '/login',
      );
      expect(result, '/reset-password');
    });
  });
}
