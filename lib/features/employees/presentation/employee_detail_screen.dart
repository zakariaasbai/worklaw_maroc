import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:worklaw_maroc/l10n/generated/app_localizations.dart';
import '../application/employees_providers.dart';
import '../domain/employee.dart';

class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({required this.employeeId, super.key});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final employeeAsync = ref.watch(employeeDetailProvider(employeeId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.employeeDetailTitle)),
      body: employeeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.employeeGenericError(error.toString())),
          ),
        ),
        data: (employee) => _EmployeeDetailBody(employee: employee),
      ),
    );
  }
}

class _EmployeeDetailBody extends ConsumerWidget {
  const _EmployeeDetailBody({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final sensitiveAsync = ref.watch(
      employeeSensitiveDataProvider(employee.id),
    );
    final contractTypesAsync = ref.watch(contractTypesProvider);
    final contractTypeLabel = contractTypesAsync.maybeWhen(
      data: (types) {
        for (final type in types) {
          if (type.id == employee.contractTypeId) return type.labelFr;
        }
        return null;
      },
      orElse: () => null,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(employee.fullName, style: Theme.of(context).textTheme.headlineSmall),
            if (employee.status == EmployeeStatus.archived)
              Chip(label: Text(l10n.employeeArchivedChip)),
          ],
        ),
        const SizedBox(height: 16),
        _InfoTile(
          label: l10n.employeeFieldEmployeeNumber,
          value: employee.employeeNumber,
        ),
        _InfoTile(label: l10n.employeeFieldPosition, value: employee.position),
        _InfoTile(
          label: l10n.employeeFieldDepartment,
          value: employee.department ?? '—',
        ),
        _InfoTile(
          label: l10n.employeeFieldHireDate,
          value: _formatDate(employee.hireDate),
        ),
        _InfoTile(
          label: l10n.employeeFieldContractType,
          value: contractTypeLabel ?? employee.contractTypeId,
        ),
        _InfoTile(
          label: l10n.employeeFieldEmploymentType,
          value: employee.employmentType == EmploymentType.fullTime
              ? l10n.employmentTypeFullTime
              : l10n.employmentTypePartTime,
        ),
        _InfoTile(label: l10n.employeeFieldPhone, value: employee.phone ?? '—'),
        _InfoTile(label: l10n.employeeFieldEmail, value: employee.email ?? '—'),
        _InfoTile(
          label: l10n.employeeFieldAddress,
          value: employee.address ?? '—',
        ),
        _InfoTile(
          label: l10n.employeeFieldNationality,
          value: employee.nationality ?? '—',
        ),
        const SizedBox(height: 24),
        Text(
          l10n.employeeSensitiveSectionTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        sensitiveAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) =>
              Text(l10n.employeeGenericError(error.toString())),
          data: (sensitive) {
            if (sensitive == null) {
              return Text(l10n.employeeSensitiveHidden);
            }
            final salaryMissing = sensitive.salaryAmount == null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      salaryMissing
                          ? l10n.employeeSalaryMissing
                          : l10n.employeeSalaryValue(
                              sensitive.salaryAmount.toString(),
                              sensitive.salaryCurrency,
                            ),
                    ),
                    if (salaryMissing) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: l10n.employeeSalaryMissingTooltip,
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
                _InfoTile(
                  label: l10n.employeeFieldCin,
                  value: sensitive.cin ?? '—',
                ),
                _InfoTile(
                  label: l10n.employeeFieldCnss,
                  value: sensitive.cnssNumber ?? '—',
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => context.push('/employees/${employee.id}/edit'),
              child: Text(l10n.employeeEditButton),
            ),
            const SizedBox(width: 12),
            if (employee.status == EmployeeStatus.active)
              OutlinedButton(
                onPressed: () => _confirmArchive(context, ref, l10n),
                child: Text(l10n.employeeArchiveButton),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmArchive(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.employeeArchiveDialogTitle),
        content: Text(l10n.employeeArchiveDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.employeeArchiveDialogCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.employeeArchiveButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(employeesRepositoryProvider).archiveEmployee(employee.id);
    ref.invalidate(employeeDetailProvider(employee.id));
    ref.invalidate(employeesListProvider);
    if (context.mounted) context.pop();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
