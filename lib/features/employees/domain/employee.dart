enum EmployeeStatus {
  active,
  archived;

  static EmployeeStatus fromValue(String value) =>
      EmployeeStatus.values.firstWhere((e) => e.name == value);
}

enum EmploymentType {
  fullTime('full_time'),
  partTime('part_time');

  const EmploymentType(this.value);
  final String value;

  static EmploymentType fromValue(String value) =>
      EmploymentType.values.firstWhere((e) => e.value == value);
}

class Employee {
  const Employee({
    required this.id,
    required this.organizationId,
    required this.employeeNumber,
    required this.firstName,
    required this.lastName,
    required this.position,
    required this.hireDate,
    required this.contractTypeId,
    required this.employmentType,
    required this.status,
    this.dateOfBirth,
    this.nationality,
    this.address,
    this.phone,
    this.email,
    this.department,
    this.weeklyHours,
  });

  final String id;
  final String organizationId;
  final String employeeNumber;
  final String firstName;
  final String lastName;
  final DateTime? dateOfBirth;
  final String? nationality;
  final String? address;
  final String? phone;
  final String? email;
  final String position;
  final String? department;
  final DateTime hireDate;
  final String contractTypeId;
  final EmploymentType employmentType;
  final double? weeklyHours;
  final EmployeeStatus status;

  String get fullName => '$firstName $lastName';

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      employeeNumber: json['employee_number'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      dateOfBirth: json['date_of_birth'] == null
          ? null
          : DateTime.parse(json['date_of_birth'] as String),
      nationality: json['nationality'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      position: json['position'] as String,
      department: json['department'] as String?,
      hireDate: DateTime.parse(json['hire_date'] as String),
      contractTypeId: json['contract_type_id'] as String,
      employmentType: EmploymentType.fromValue(
        json['employment_type'] as String,
      ),
      weeklyHours: (json['weekly_hours'] as num?)?.toDouble(),
      status: EmployeeStatus.fromValue(json['status'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'organization_id': organizationId,
      'employee_number': employeeNumber,
      'first_name': firstName,
      'last_name': lastName,
      'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
      'nationality': nationality,
      'address': address,
      'phone': phone,
      'email': email,
      'position': position,
      'department': department,
      'hire_date': hireDate.toIso8601String().split('T').first,
      'contract_type_id': contractTypeId,
      'employment_type': employmentType.value,
      'weekly_hours': weeklyHours,
    };
  }
}
