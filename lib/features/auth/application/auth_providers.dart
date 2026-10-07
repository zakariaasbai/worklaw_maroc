import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../employees/application/employees_providers.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

/// Feeds go_router's `refreshListenable` so the router re-evaluates
/// `redirect` on every auth state change (sign in, sign out, password
/// recovery link), and exposes the last event so `redirect` can special-case
/// `passwordRecovery` without a separate stream subscription there.
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((authState) {
      lastEvent = authState.event;
      notifyListeners();
    });
  }

  AuthChangeEvent? lastEvent;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final goRouterRefreshNotifierProvider = Provider<GoRouterRefreshNotifier>((
  ref,
) {
  final notifier = GoRouterRefreshNotifier(
    ref.watch(authRepositoryProvider).onAuthStateChange,
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});
