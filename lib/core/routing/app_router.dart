import 'package:go_router/go_router.dart';

import '../../features/employees/presentation/employee_detail_screen.dart';
import '../../features/employees/presentation/employee_form_screen.dart';
import '../../features/employees/presentation/employees_list_screen.dart';
import '../../shared/widgets/work_law_home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const WorkLawHomeScreen()),
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
