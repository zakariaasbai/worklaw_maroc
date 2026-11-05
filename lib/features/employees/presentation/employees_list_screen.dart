import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:worklaw_maroc/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/language_selector.dart';
import '../application/employees_providers.dart';
import '../domain/employee.dart';

class EmployeesListScreen extends ConsumerStatefulWidget {
  const EmployeesListScreen({super.key});

  @override
  ConsumerState<EmployeesListScreen> createState() =>
      _EmployeesListScreenState();
}

class _EmployeesListScreenState extends ConsumerState<EmployeesListScreen> {
  EmployeeStatus _statusFilter = EmployeeStatus.active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final employeesAsync = ref.watch(employeesListProvider(_statusFilter));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.employeesListTitle),
        actions: const [
          Padding(padding: EdgeInsets.all(8), child: LanguageSelector()),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<EmployeeStatus>(
              segments: [
                ButtonSegment(
                  value: EmployeeStatus.active,
                  label: Text(l10n.employeesStatusActive),
                ),
                ButtonSegment(
                  value: EmployeeStatus.archived,
                  label: Text(l10n.employeesStatusArchived),
                ),
              ],
              selected: {_statusFilter},
              onSelectionChanged: (selection) {
                setState(() => _statusFilter = selection.first);
              },
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/employees/new'),
        tooltip: l10n.employeesAddTooltip,
        child: const Icon(Icons.add),
      ),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.employeesLoadError(error.toString())),
          ),
        ),
        data: (employees) {
          if (employees.isEmpty) {
            return Center(child: Text(l10n.employeesEmpty));
          }
          return ListView.separated(
            itemCount: employees.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final employee = employees[index];
              return ListTile(
                title: Text(employee.fullName),
                subtitle: Text(employee.position),
                trailing: Text(employee.employeeNumber),
                onTap: () => context.push('/employees/${employee.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
