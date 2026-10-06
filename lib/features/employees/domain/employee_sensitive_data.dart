/// Salary/CNSS/CIN. Only present when the current user is 'owner' or
/// 'admin' of the organization — RLS returns no row otherwise, which the
/// repository surfaces as `null`, not an error.
class EmployeeSensitiveData {
  const EmployeeSensitiveData({
    required this.employeeId,
    required this.organizationId,
    required this.salaryCurrency,
    this.cin,
    this.salaryAmount,
    this.cnssNumber,
  });

  final String employeeId;
  final String organizationId;
  final String? cin;
  final double? salaryAmount;
  final String salaryCurrency;
  final String? cnssNumber;

  factory EmployeeSensitiveData.fromJson(Map<String, dynamic> json) {
    return EmployeeSensitiveData(
      employeeId: json['employee_id'] as String,
      organizationId: json['organization_id'] as String,
      cin: json['cin'] as String?,
      salaryAmount: (json['salary_amount'] as num?)?.toDouble(),
      salaryCurrency: json['salary_currency'] as String,
      cnssNumber: json['cnss_number'] as String?,
    );
  }

  Map<String, dynamic> toUpsertJson() {
    return {
      'employee_id': employeeId,
      'organization_id': organizationId,
      'cin': cin,
      'salary_amount': salaryAmount,
      'salary_currency': salaryCurrency,
      'cnss_number': cnssNumber,
    };
  }
}
