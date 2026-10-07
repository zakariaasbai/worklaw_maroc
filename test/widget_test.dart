import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:worklaw_maroc/features/auth/application/auth_providers.dart';
import 'package:worklaw_maroc/main.dart';

import 'helpers/fake_auth_repository.dart';

void main() {
  testWidgets(
    'App boots without a session and redirects to the login screen',
    (WidgetTester tester) async {
      final fake = FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fake)],
          child: const WorkLawMarocApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connexion'), findsWidgets);
    },
  );
}
