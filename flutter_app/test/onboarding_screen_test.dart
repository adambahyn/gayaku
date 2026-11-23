import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_app/screens/login_screen.dart';
import 'package:flutter_app/screens/onboarding_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('OnboardingScreen navigates through slides and completes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();

    // Slide 1
    expect(find.text('LANGKAH 1'), findsOneWidget);
    expect(find.text('Scan & Tambah Pakaian'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);
    expect(find.text('Lanjut'), findsOneWidget);

    // Tap Lanjut -> Slide 2
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('LANGKAH 2'), findsOneWidget);
    expect(find.text('Rekomendasi Padu Padan'), findsOneWidget);

    // Tap Lanjut -> Slide 3
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('LANGKAH 3'), findsOneWidget);
    expect(find.text('Favorit & Jadwal Mingguan'), findsOneWidget);

    // Tap Lanjut -> Slide 4
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    expect(find.text('LANGKAH 4'), findsOneWidget);
    expect(find.text('Alur Cepat Siap Pakai'), findsOneWidget);
    expect(find.text('Mulai & Masuk Akun'), findsOneWidget);

    // Tap Mulai & Masuk Akun -> Goes to LoginScreen
    await tester.tap(find.text('Mulai & Masuk Akun'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('has_seen_onboarding'), isTrue);
  });

  testWidgets('Lewati button completes onboarding directly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(640, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('has_seen_onboarding'), isTrue);
  });
}
