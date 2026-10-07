/// Pure redirect logic for go_router — no BuildContext, no Supabase,
/// directly unit-testable with a mocked session state.
const publicAuthRoutes = {'/login', '/signup', '/forgot-password'};

/// Returns the path to redirect to, or null to allow the navigation as-is.
///
/// `isPasswordRecovery` takes priority over everything else: when a user
/// clicks a password-reset email link, Supabase briefly treats them as
/// signed in (so `hasSession` is true) but the only thing they should be
/// allowed to do is set a new password.
String? authRedirect({
  required bool hasSession,
  required bool isPasswordRecovery,
  required String location,
}) {
  if (isPasswordRecovery) {
    return location == '/reset-password' ? null : '/reset-password';
  }

  if (!hasSession) {
    return publicAuthRoutes.contains(location) ? null : '/login';
  }

  if (publicAuthRoutes.contains(location)) return '/employees';

  return null;
}
