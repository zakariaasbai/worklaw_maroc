import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:worklaw_maroc/features/auth/data/auth_repository.dart';

/// In-memory fake used by widget tests so nothing ever touches
/// Supabase.instance or the network.
class FakeAuthRepository implements AuthRepository {
  Session? currentSessionOverride;
  final _controller = StreamController<AuthState>.broadcast();

  Object? signUpError;
  AuthResponse? signUpResponse;
  Object? signInError;
  Object? resetPasswordError;
  Object? updatePasswordError;

  bool signOutCalled = false;
  String? lastSignUpEmail;
  String? lastSignUpFullName;
  String? lastSignUpOrganizationName;

  @override
  Session? get currentSession => currentSessionOverride;

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  void emit(AuthChangeEvent event, {Session? session}) {
    currentSessionOverride = session ?? currentSessionOverride;
    _controller.add(AuthState(event, currentSessionOverride));
  }

  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String organizationName,
  }) async {
    lastSignUpEmail = email;
    lastSignUpFullName = fullName;
    lastSignUpOrganizationName = organizationName;
    if (signUpError != null) throw signUpError!;
    return signUpResponse ?? AuthResponse(session: null);
  }

  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    if (signInError != null) throw signInError!;
    return AuthResponse(session: currentSessionOverride);
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    currentSessionOverride = null;
  }

  @override
  Future<void> resetPasswordForEmail(String email, {String? redirectTo}) async {
    if (resetPasswordError != null) throw resetPasswordError!;
  }

  @override
  Future<UserResponse> updatePassword(String newPassword) async {
    if (updatePasswordError != null) throw updatePasswordError!;
    return UserResponse.fromJson({'id': 'fake-user-id'});
  }

  void dispose() => _controller.close();
}
