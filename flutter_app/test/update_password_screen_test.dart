import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/screens/update_password_screen.dart';

/// The recovery link lands here, so the screen has to ask for the password
/// twice and refuse a mismatch before anything reaches the backend.
void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: UpdatePasswordScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('asks for the new password twice', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Buat Password Baru'), findsOneWidget);
    expect(find.text('Simpan Password'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('a mismatched confirmation keeps the user on the screen', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField).at(0), 'rahasia-baru');
    await tester.enterText(find.byType(TextField).at(1), 'beda-sekali');
    await tester.tap(find.text('Simpan Password'));
    await tester.pumpAndSettle();

    expect(find.text('Konfirmasi password tidak cocok.'), findsOneWidget);
    expect(find.byType(UpdatePasswordScreen), findsOneWidget);
  });
}
