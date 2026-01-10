// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:urban_points_merchant/main.dart';

// Mock Firebase setup for testing
setupFirebaseAuthMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Mock Firebase Core
  FirebasePlatform.instance = MockFirebasePlatform();
}

// Mock Firebase Platform
class MockFirebasePlatform extends FirebasePlatform {
  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseApp();
  }

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    return MockFirebaseApp();
  }

  @override
  List<FirebaseAppPlatform> get apps {
    return [MockFirebaseApp()];
  }
}

// Mock Firebase App
class MockFirebaseApp extends FirebaseAppPlatform {
  MockFirebaseApp() : super(defaultFirebaseAppName, const FirebaseOptions(
    apiKey: 'mock-api-key',
    appId: 'mock-app-id',
    messagingSenderId: 'mock-sender-id',
    projectId: 'mock-project-id',
  ));

  @override
  Future<void> delete() async {}

  @override
  Future<void> setAutomaticDataCollectionEnabled(bool enabled) async {}

  @override
  Future<void> setAutomaticResourceManagementEnabled(bool enabled) async {}

  @override
  bool get isAutomaticDataCollectionEnabled => false;
}

void main() {
  setupFirebaseAuthMocks();

  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Initialize Firebase
    await Firebase.initializeApp();

    // Build our app and trigger a frame.
    await tester.pumpWidget(const UrbanPointsMerchantApp());

    // Verify that the app loads
    expect(find.byType(UrbanPointsMerchantApp), findsOneWidget);
  });
}
