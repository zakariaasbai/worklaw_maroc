import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/contract_type.dart';
import '../domain/employee.dart';
import '../domain/employee_sensitive_data.dart';

/// All Supabase access for the employees feature. Screens never call
/// Supabase directly — they go through this repository, so the query/RLS
/// logic stays testable independently of the UI.
class EmployeesRepository {
  EmployeesRepository(this._client);

  final SupabaseClient _client;

  Future<List<Employee>> fetchEmployees({
    required String organizationId,
    required EmployeeStatus status,
  }) async {
    final rows = await _client
        .from('employees')
        .select()
        .eq('organization_id', organizationId)
        .eq('status', status.name)
        .order('last_name');
    return rows.map(Employee.fromJson).toList();
  }

  Future<Employee> fetchEmployee(String id) async {
    final row = await _client.from('employees').select().eq('id', id).single();
    return Employee.fromJson(row);
  }

  /// Returns null if the row doesn't exist or the current user's role
  /// doesn't grant access (RLS returns no row in both cases) — not an
  /// error, and the UI should treat both the same way (hide the section).
  Future<EmployeeSensitiveData?> fetchSensitiveData(String employeeId) async {
    final rows = await _client
        .from('employee_sensitive_data')
        .select()
        .eq('employee_id', employeeId);
    if (rows.isEmpty) return null;
    return EmployeeSensitiveData.fromJson(rows.first);
  }

  Future<List<ContractType>> fetchContractTypes() async {
    final rows = await _client
        .from('contract_types')
        .select()
        .eq('is_active', true)
        .order('code');
    return rows.map(ContractType.fromJson).toList();
  }

  Future<Employee> createEmployee(Employee employee) async {
    final row = await _client
        .from('employees')
        .insert(employee.toInsertJson())
        .select()
        .single();
    return Employee.fromJson(row);
  }

  Future<Employee> updateEmployee(Employee employee) async {
    final row = await _client
        .from('employees')
        .update(employee.toInsertJson())
        .eq('id', employee.id)
        .select()
        .single();
    return Employee.fromJson(row);
  }

  Future<void> archiveEmployee(String id) async {
    await _client
        .from('employees')
        .update({'status': EmployeeStatus.archived.name})
        .eq('id', id);
  }

  /// Create or replace the sensitive-data row. Silently does nothing
  /// useful for a caller without owner/admin rights — RLS rejects the
  /// write, which surfaces as a PostgrestException the caller should show
  /// to the user rather than swallow.
  Future<void> upsertSensitiveData(EmployeeSensitiveData data) async {
    await _client
        .from('employee_sensitive_data')
        .upsert(data.toUpsertJson());
  }
}
