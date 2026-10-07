import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:worklaw_maroc/features/auth/application/auth_providers.dart';
import 'package:worklaw_maroc/features/auth/presentation/signup_screen.dart';
import 'package:worklaw_maroc/l10n/generated/app_localizations.dart';

import '../../../helpers/fake_auth_repository.dart';

Widget _wrap(FakeAuthRepository fake) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(fake)],
    child: MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SignupScreen(),
    ),
  );
}

void main() {
  testWidgets('shows validation errors when submitting an empty form', (
    tester,
  ) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_wrap(fake));

    await tester.tap(find.text('Créer le compte'));
    await tester.pump();

    expect(find.text('Champ obligatoire'), findsWidgets);
    expect(fake.lastSignUpEmail, isNull);
  });

  testWidgets('flags mismatched passwords', (tester) async {
    final fake = FakeAuthRepository();
    await tester.pumpWidget(_wrap(fake));

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom complet'), 'Jane Doe');
    await tester.enterText(
      find.widgetWithText(TextFormField, "Nom de l'entreprise"),
      'Acme SARL',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'jane@example.com');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'longenough1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
      'different',
    );

    await tester.tap(find.text('Créer le compte'));
    await tester.pump();

    expect(find.text('Les mots de passe ne correspondent pas'), findsOneWidget);
    expect(fake.lastSignUpEmail, isNull);
  });

  testWidgets(
    'shows the email-confirmation message when signUp returns no session',
    (tester) async {
      final fake = FakeAuthRepository();
      await tester.pumpWidget(_wrap(fake));

      await tester.enterText(find.widgetWithText(TextFormField, 'Nom complet'), 'Jane Doe');
      await tester.enterText(
        find.widgetWithText(TextFormField, "Nom de l'entreprise"),
        'Acme SARL',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'jane@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Mot de passe'),
        'longenough1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
        'longenough1',
      );

      await tester.tap(find.text('Créer le compte'));
      await tester.pumpAndSettle();

      expect(fake.lastSignUpEmail, 'jane@example.com');
      expect(fake.lastSignUpFullName, 'Jane Doe');
      expect(fake.lastSignUpOrganizationName, 'Acme SARL');
      expect(
        find.textContaining('Un email de confirmation a été envoyé'),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows a generic error message when signUp throws', (
    tester,
  ) async {
    final fake = FakeAuthRepository()..signUpError = Exception('boom');
    await tester.pumpWidget(_wrap(fake));

    await tester.enterText(find.widgetWithText(TextFormField, 'Nom complet'), 'Jane Doe');
    await tester.enterText(
      find.widgetWithText(TextFormField, "Nom de l'entreprise"),
      'Acme SARL',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'jane@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mot de passe'),
      'longenough1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmer le mot de passe'),
      'longenough1',
    );

    await tester.tap(find.text('Créer le compte'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Impossible de créer le compte'),
      findsOneWidget,
    );
  });
}
