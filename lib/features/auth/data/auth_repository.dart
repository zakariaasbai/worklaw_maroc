import 'package:supabase_flutter/supabase_flutter.dart';

/// Abstraction over Supabase Auth so screens/tests never touch
/// Supabase.instance.client directly — widget tests override this with a
/// fake, no network involved.
abstract class AuthRepository {
  Stream<AuthState> get onAuthStateChange;

  Session? get currentSession;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String organizationName,
  });

  Future<AuthResponse> signIn({required String email, required String password});

  Future<void> signOut();

  Future<void> resetPasswordForEmail(String email, {String? redirectTo});

  Future<UserResponse> updatePassword(String newPassword);
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  @override
  Session? get currentSession => _client.auth.currentSession;

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String organizationName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'organization_name': organizationName},
    );
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<void> resetPasswordForEmail(String email, {String? redirectTo}) {
    return _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  @override
  Future<UserResponse> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}
