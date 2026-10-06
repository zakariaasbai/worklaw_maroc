import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/employees_providers.dart';
import '../domain/employee.dart';

class EmployeeDetailScreen extends ConsumerWidget {
  const EmployeeDetailScreen({required this.employeeId, super.key});

  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeAsync = ref.watch(employeeDetailProvider(employeeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Fiche employé')),
      body: employeeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur de chargement : $error'),
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
              const Chip(label: Text('Archivé')),
          ],
        ),
        const SizedBox(height: 16),
        _InfoTile(label: 'Identifiant interne', value: employee.employeeNumber),
        _InfoTile(label: 'Poste', value: employee.position),
        _InfoTile(label: 'Département', value: employee.department ?? '—'),
        _InfoTile(
          label: "Date d'embauche",
          value: _formatDate(employee.hireDate),
        ),
        _InfoTile(
          label: 'Type de contrat',
          value: contractTypeLabel ?? employee.contractTypeId,
        ),
        _InfoTile(
          label: 'Régime',
          value: employee.employmentType == EmploymentType.fullTime
              ? 'Temps plein'
              : 'Temps partiel',
        ),
        _InfoTile(label: 'Téléphone', value: employee.phone ?? '—'),
        _InfoTile(label: 'Email', value: employee.email ?? '—'),
        _InfoTile(label: 'Adresse', value: employee.address ?? '—'),
        _InfoTile(label: 'Nationalité', value: employee.nationality ?? '—'),
        const SizedBox(height: 24),
        Text(
          'Informations sensibles',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        sensitiveAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, stackTrace) => Text('Erreur : $error'),
          data: (sensitive) {
            if (sensitive == null) {
              return const Text(
                "Non visible avec votre rôle, ou pas encore renseignées.",
              );
            }
            final salaryMissing = sensitive.salaryAmount == null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      salaryMissing
                          ? 'Salaire : non renseigné'
                          : 'Salaire : ${sensitive.salaryAmount} ${sensitive.salaryCurrency}',
                    ),
                    if (salaryMissing) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message:
                            'Ce champ conditionne les futurs calculateurs (préavis, indemnité, solde de tout compte).',
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                          size: 20,
                        ),
                      ),
                    ],
                  ],
                ),
                _InfoTile(label: 'CIN', value: sensitive.cin ?? '—'),
                _InfoTile(
                  label: 'N° CNSS',
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
              child: const Text('Modifier'),
            ),
            const SizedBox(width: 12),
            if (employee.status == EmployeeStatus.active)
              OutlinedButton(
                onPressed: () => _confirmArchive(context, ref),
                child: const Text('Archiver'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archiver cet employé ?'),
        content: const Text(
          "L'employé restera consultable (historique des calculs), mais n'apparaîtra plus dans la liste active.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archiver'),
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
