// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mytrademate/main.dart';
import 'package:mytrademate/providers/theme_provider.dart';
import 'package:mytrademate/services/app_settings_service.dart';

void main() {
  testWidgets('App builds without errors', (WidgetTester tester) async {
    // Ensure enough viewport to avoid overflow in small test windows
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
          ChangeNotifierProvider.value(value: AppSettingsService()),
        ],
        child: const MyTradeMateApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
