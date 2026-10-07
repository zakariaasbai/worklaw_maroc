import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/employees/presentation/employee_detail_screen.dart';
import '../../features/employees/presentation/employee_form_screen.dart';
import '../../features/employees/presentation/employees_list_screen.dart';
import '../../shared/widgets/work_law_home_screen.dart';
import 'auth_redirect.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final refreshNotifier = ref.watch(goRouterRefreshNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (context, state) => authRedirect(
      hasSession: authRepository.currentSession != null,
      isPasswordRecovery:
          refreshNotifier.lastEvent == AuthChangeEvent.passwordRecovery,
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const WorkLawHomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/employees',
        builder: (context, state) => const EmployeesListScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const EmployeeFormScreen(),
          ),
          GoRoute(
            path: ':id',
            builder: (context, state) => EmployeeDetailScreen(
              employeeId: state.pathParameters['id']!,
            ),
          ),
          GoRoute(
            path: ':id/edit',
            builder: (context, state) => EmployeeFormScreen(
              employeeId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
    ],
  );
});
