import 'package:flutter_test/flutter_test.dart';

import 'package:worklaw_maroc/main.dart';

void main() {
  testWidgets('App boots and shows placeholder home page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WorkLawMarocApp());

    expect(find.text('WorkLaw Maroc'), findsWidgets);
    expect(find.text('WorkLaw Maroc — MVP en construction'), findsOneWidget);
  });
}
