import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklaw_maroc/features/employees/application/employees_providers.dart';
import 'package:worklaw_maroc/features/employees/presentation/employees_list_screen.dart';
import 'package:worklaw_maroc/l10n/generated/app_localizations.dart';

import '../../../helpers/fake_employees_repository.dart';

Widget _wrap(Locale locale, FakeEmployeesRepository fake) {
  return ProviderScope(
    overrides: [
      employeesRepositoryProvider.overrideWithValue(fake),
      currentOrganizationIdProvider.overrideWith((ref) async => 'org-1'),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const EmployeesListScreen(),
    ),
  );
}

void main() {
  testWidgets('French: shows French labels and LTR direction', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const Locale('fr'), FakeEmployeesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Employés'), findsOneWidget);
    expect(find.text('Actifs'), findsOneWidget);
    expect(find.text('Archivés'), findsOneWidget);
    expect(find.text('Aucun employé.'), findsOneWidget);

    final direction = Directionality.of(tester.element(find.text('Employés')));
    expect(direction, TextDirection.ltr);
  });

  testWidgets('English: shows English labels and LTR direction', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const Locale('en'), FakeEmployeesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Employees'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Archived'), findsOneWidget);
    expect(find.text('No employees.'), findsOneWidget);

    final direction = Directionality.of(tester.element(find.text('Employees')));
    expect(direction, TextDirection.ltr);
  });

  testWidgets('Arabic: shows Arabic labels and switches to RTL direction', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const Locale('ar'), FakeEmployeesRepository()));
    await tester.pumpAndSettle();

    expect(find.text('الموظفون'), findsOneWidget);
    expect(find.text('نشطون'), findsOneWidget);
    expect(find.text('مؤرشفون'), findsOneWidget);
    expect(find.text('لا يوجد موظفون.'), findsOneWidget);

    final direction = Directionality.of(tester.element(find.text('الموظفون')));
    expect(direction, TextDirection.rtl);
  });
}
