import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/screens/home_screen.dart';
import 'package:flutter_app/widgets/greeting_header.dart';

void main() {
  testWidgets('HomeScreen renders all sections at 420px', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: HomeScreen()),
    );
    await tester.pumpAndSettle();

    final greeting = GreetingHeader.greetingFor(DateTime.now());
    expect(find.textContaining(greeting.split(',').first), findsOneWidget);
    expect(find.text('Isabella'), findsOneWidget);
    expect(find.text("Today's Look"), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            (w.decoration?.hintText ?? '').startsWith('Search by occasion'),
      ),
      findsOneWidget,
    );
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Recently Added'), findsOneWidget);
  });
}
