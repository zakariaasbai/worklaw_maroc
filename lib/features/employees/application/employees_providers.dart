import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/employees_repository.dart';
import '../domain/contract_type.dart';
import '../domain/employee.dart';
import '../domain/employee_sensitive_data.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final employeesRepositoryProvider = Provider<EmployeesRepository>((ref) {
  return EmployeesRepository(ref.watch(supabaseClientProvider));
});

/// The organization the current user manages employees for.
///
/// Simplification for the current MVP: a user is only ever expected to act
/// within one organization at a time, so this takes the first organization
/// returned for the signed-in user. There is no organization switcher yet
/// — if/when a user can belong to several organizations from the UI, this
/// provider is where that selection would plug in.
final currentOrganizationIdProvider = FutureProvider<String>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final rows = await client.from('organizations').select('id').limit(1);
  if (rows.isEmpty) {
    throw StateError('Signed-in user has no organization.');
  }
  return rows.first['id'] as String;
});

final contractTypesProvider = FutureProvider<List<ContractType>>((ref) async {
  return ref.watch(employeesRepositoryProvider).fetchContractTypes();
});

final employeesListProvider =
    FutureProvider.family<List<Employee>, EmployeeStatus>((
      ref,
      status,
    ) async {
      final organizationId = await ref.watch(
        currentOrganizationIdProvider.future,
      );
      return ref
          .watch(employeesRepositoryProvider)
          .fetchEmployees(organizationId: organizationId, status: status);
    });

final employeeDetailProvider = FutureProvider.family<Employee, String>((
  ref,
  employeeId,
) async {
  return ref.watch(employeesRepositoryProvider).fetchEmployee(employeeId);
});

/// Null when the row doesn't exist, or the current user isn't owner/admin
/// — RLS makes both cases indistinguishable, which is intentional.
final employeeSensitiveDataProvider =
    FutureProvider.family<EmployeeSensitiveData?, String>((
      ref,
      employeeId,
    ) async {
      return ref
          .watch(employeesRepositoryProvider)
          .fetchSensitiveData(employeeId);
    });
