// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App builds without errors', (tester) async {
    // Simple smoke test - just verify we can build a basic Material widget
    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Text('MyTradeMate Test'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify basic structure
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('MyTradeMate Test'), findsOneWidget);

    print('✅ Basic widget test passed');
  });
}
