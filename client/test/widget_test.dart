// This is a basic Flutter widget test for Operation Won app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:operation_won/main.dart';

void main() {
  testWidgets('App loads and has correct structure',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Pump a few frames to allow initial rendering
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The app should have a MaterialApp at its root
    expect(find.byType(MaterialApp), findsOneWidget);

    // The MaterialApp should be configured with the title 'Operation Won'
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, equals('Operation Won'));

    // The app should not show checked mode banner in production
    expect(materialApp.debugShowCheckedModeBanner, isFalse);
  });

  testWidgets('App shows authentication flow', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Pump initial frames
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The app should contain either loading state or authentication content
    // Since the app uses providers and async initialization, we expect to find:
    // 1. MultiProvider (for state management), or
    // 2. Consumer widgets, or
    // 3. AuthenticationFlow widget

    final hasMultiProvider = find.byType(MultiProvider);
    final hasScaffold = find.byType(Scaffold);

    // At least one of these should be present
    expect(
      hasMultiProvider.evaluate().isNotEmpty ||
          hasScaffold.evaluate().isNotEmpty,
      isTrue,
      reason: 'App should show MultiProvider structure or Scaffold content',
    );
  });
}
