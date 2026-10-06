import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/employees_providers.dart';
import '../domain/contract_type.dart';
import '../domain/employee.dart';
import '../domain/employee_sensitive_data.dart';

/// Shared create/edit form. `employeeId` null means create.
class EmployeeFormScreen extends ConsumerStatefulWidget {
  const EmployeeFormScreen({this.employeeId, super.key});

  final String? employeeId;

  @override
  ConsumerState<EmployeeFormScreen> createState() =>
      _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _employeeNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _positionController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _weeklyHoursController = TextEditingController();

  final _cinController = TextEditingController();
  final _salaryController = TextEditingController();
  final _cnssController = TextEditingController();

  DateTime? _hireDate;
  DateTime? _dateOfBirth;
  String? _contractTypeId;
  EmploymentType _employmentType = EmploymentType.fullTime;
  bool _saving = false;
  bool _prefilled = false;

  bool get _isEditing => widget.employeeId != null;

  @override
  void dispose() {
    _employeeNumberController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _positionController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _nationalityController.dispose();
    _weeklyHoursController.dispose();
    _cinController.dispose();
    _salaryController.dispose();
    _cnssController.dispose();
    super.dispose();
  }

  void _prefill(Employee employee, EmployeeSensitiveData? sensitive) {
    if (_prefilled) return;
    _prefilled = true;
    _employeeNumberController.text = employee.employeeNumber;
    _firstNameController.text = employee.firstName;
    _lastNameController.text = employee.lastName;
    _positionController.text = employee.position;
    _departmentController.text = employee.department ?? '';
    _phoneController.text = employee.phone ?? '';
    _emailController.text = employee.email ?? '';
    _addressController.text = employee.address ?? '';
    _nationalityController.text = employee.nationality ?? '';
    _weeklyHoursController.text = employee.weeklyHours?.toString() ?? '';
    _hireDate = employee.hireDate;
    _dateOfBirth = employee.dateOfBirth;
    _contractTypeId = employee.contractTypeId;
    _employmentType = employee.employmentType;
    if (sensitive != null) {
      _cinController.text = sensitive.cin ?? '';
      _salaryController.text = sensitive.salaryAmount?.toString() ?? '';
      _cnssController.text = sensitive.cnssNumber ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nouvel employé')),
        body: _buildForm(context, existing: null),
      );
    }

    final employeeAsync = ref.watch(employeeDetailProvider(widget.employeeId!));
    final sensitiveAsync = ref.watch(
      employeeSensitiveDataProvider(widget.employeeId!),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier employé')),
      body: employeeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Erreur : $error')),
        data: (employee) {
          final sensitive = sensitiveAsync.asData?.value;
          _prefill(employee, sensitive);
          return _buildForm(context, existing: employee);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required Employee? existing}) {
    final contractTypesAsync = ref.watch(contractTypesProvider);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _employeeNumberController,
            decoration: const InputDecoration(
              labelText: 'Identifiant employé interne *',
            ),
            validator: _requiredValidator,
          ),
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: 'Prénom *'),
            validator: _requiredValidator,
          ),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: 'Nom *'),
            validator: _requiredValidator,
          ),
          TextFormField(
            controller: _positionController,
            decoration: const InputDecoration(labelText: 'Poste *'),
            validator: _requiredValidator,
          ),
          TextFormField(
            controller: _departmentController,
            decoration: const InputDecoration(labelText: 'Département'),
          ),
          _DatePickerField(
            label: "Date d'embauche *",
            value: _hireDate,
            onChanged: (date) => setState(() => _hireDate = date),
          ),
          _DatePickerField(
            label: 'Date de naissance',
            value: _dateOfBirth,
            onChanged: (date) => setState(() => _dateOfBirth = date),
          ),
          contractTypesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, stackTrace) =>
                Text('Impossible de charger les types de contrat : $error'),
            data: (types) => DropdownButtonFormField<String>(
              value: _contractTypeId,
              decoration: const InputDecoration(labelText: 'Type de contrat *'),
              items: types
                  .map(
                    (ContractType t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(t.labelFr),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _contractTypeId = value),
              validator: (value) =>
                  value == null ? 'Champ obligatoire' : null,
            ),
          ),
          DropdownButtonFormField<EmploymentType>(
            value: _employmentType,
            decoration: const InputDecoration(labelText: 'Régime de travail *'),
            items: const [
              DropdownMenuItem(
                value: EmploymentType.fullTime,
                child: Text('Temps plein'),
              ),
              DropdownMenuItem(
                value: EmploymentType.partTime,
                child: Text('Temps partiel'),
              ),
            ],
            onChanged: (value) =>
                setState(() => _employmentType = value ?? _employmentType),
          ),
          if (_employmentType == EmploymentType.partTime)
            TextFormField(
              controller: _weeklyHoursController,
              decoration: const InputDecoration(
                labelText: 'Heures hebdomadaires',
              ),
              keyboardType: TextInputType.number,
            ),
          TextFormField(
            controller: _nationalityController,
            decoration: const InputDecoration(labelText: 'Nationalité'),
          ),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(labelText: 'Adresse'),
          ),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(labelText: 'Téléphone'),
          ),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 24),
          Text(
            'Informations sensibles',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Text(
            'Visible et modifiable uniquement par owner/admin — un membre '
            "sans ces droits verra une erreur s'il tente d'enregistrer.",
            style: TextStyle(fontSize: 12),
          ),
          TextFormField(
            controller: _cinController,
            decoration: const InputDecoration(labelText: 'CIN'),
          ),
          TextFormField(
            controller: _salaryController,
            decoration: const InputDecoration(
              labelText: 'Salaire (MAD)',
              helperText: 'Conditionne les futurs calculateurs si renseigné',
            ),
            keyboardType: TextInputType.number,
          ),
          TextFormField(
            controller: _cnssController,
            decoration: const InputDecoration(labelText: 'N° CNSS'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : () => _submit(existing),
            child: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit(Employee? existing) async {
    if (!_formKey.currentState!.validate()) return;
    if (_hireDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La date d'embauche est obligatoire.")),
      );
      return;
    }
    if (_contractTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le type de contrat est obligatoire.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final String organizationId;
      if (existing != null) {
        organizationId = existing.organizationId;
      } else {
        organizationId = await ref.read(currentOrganizationIdProvider.future);
      }

      final employee = Employee(
        id: existing?.id ?? '',
        organizationId: organizationId,
        employeeNumber: _employeeNumberController.text.trim(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        dateOfBirth: _dateOfBirth,
        nationality: _emptyToNull(_nationalityController.text),
        address: _emptyToNull(_addressController.text),
        phone: _emptyToNull(_phoneController.text),
        email: _emptyToNull(_emailController.text),
        position: _positionController.text.trim(),
        department: _emptyToNull(_departmentController.text),
        hireDate: _hireDate!,
        contractTypeId: _contractTypeId!,
        employmentType: _employmentType,
        weeklyHours: double.tryParse(_weeklyHoursController.text),
        status: existing?.status ?? EmployeeStatus.active,
      );

      final repository = ref.read(employeesRepositoryProvider);
      final saved = existing == null
          ? await repository.createEmployee(employee)
          : await repository.updateEmployee(employee);

      final hasSensitiveInput = _cinController.text.trim().isNotEmpty ||
          _salaryController.text.trim().isNotEmpty ||
          _cnssController.text.trim().isNotEmpty;
      if (hasSensitiveInput) {
        try {
          await repository.upsertSensitiveData(
            EmployeeSensitiveData(
              employeeId: saved.id,
              organizationId: organizationId,
              cin: _emptyToNull(_cinController.text),
              salaryAmount: double.tryParse(_salaryController.text),
              salaryCurrency: 'MAD',
              cnssNumber: _emptyToNull(_cnssController.text),
            ),
          );
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Employé enregistré, mais vous n'avez pas les droits "
                  'pour modifier les informations sensibles.',
                ),
              ),
            );
          }
        }
      }

      ref.invalidate(employeesListProvider);
      if (existing != null) {
        ref.invalidate(employeeDetailProvider(existing.id));
        ref.invalidate(employeeSensitiveDataProvider(existing.id));
      }

      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  String? _requiredValidator(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? ''
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(labelText: label),
      controller: TextEditingController(text: text),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
