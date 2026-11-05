import 'package:worklaw_maroc/features/employees/data/employees_repository.dart';
import 'package:worklaw_maroc/features/employees/domain/contract_type.dart';
import 'package:worklaw_maroc/features/employees/domain/employee.dart';
import 'package:worklaw_maroc/features/employees/domain/employee_sensitive_data.dart';

/// In-memory fake used by widget tests so nothing ever touches Supabase.
class FakeEmployeesRepository implements EmployeesRepository {
  List<Employee> employees = [];
  List<ContractType> contractTypes = [
    const ContractType(id: 'cdi', code: 'CDI', labelFr: 'CDI'),
  ];
  Map<String, EmployeeSensitiveData?> sensitiveDataByEmployeeId = {};

  @override
  Future<List<Employee>> fetchEmployees({
    required String organizationId,
    required EmployeeStatus status,
  }) async {
    return employees.where((e) => e.status == status).toList();
  }

  @override
  Future<Employee> fetchEmployee(String id) async {
    return employees.firstWhere((e) => e.id == id);
  }

  @override
  Future<EmployeeSensitiveData?> fetchSensitiveData(String employeeId) async {
    return sensitiveDataByEmployeeId[employeeId];
  }

  @override
  Future<List<ContractType>> fetchContractTypes() async => contractTypes;

  @override
  Future<Employee> createEmployee(Employee employee) async {
    employees.add(employee);
    return employee;
  }

  @override
  Future<Employee> updateEmployee(Employee employee) async {
    employees = [
      for (final e in employees) if (e.id == employee.id) employee else e,
    ];
    return employee;
  }

  @override
  Future<void> archiveEmployee(String id) async {}

  @override
  Future<void> upsertSensitiveData(EmployeeSensitiveData data) async {
    sensitiveDataByEmployeeId[data.employeeId] = data;
  }
}
