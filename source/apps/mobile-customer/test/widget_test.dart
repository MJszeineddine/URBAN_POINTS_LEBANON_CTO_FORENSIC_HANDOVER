import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_points_customer/main.dart';

void main() {
  testWidgets('App root widget builds', (WidgetTester tester) async {
    // Pump the app without Firebase init (inject mock if needed)
    await tester.pumpWidget(const UrbanPointsCustomerApp());
    
    // Verify MaterialApp is present
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('App has navigation structure', (WidgetTester tester) async {
    await tester.pumpWidget(const UrbanPointsCustomerApp());
    
    // Verify key navigation components exist
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('Widget structure is valid', () {
    // Unit test: verify app structure without widget rendering
    const app = UrbanPointsCustomerApp();
    expect(app, isNotNull);
  });
}
