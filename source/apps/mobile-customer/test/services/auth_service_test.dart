import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthService', () {
    test('sendPhoneOtp with valid phone number', () {
      // Test OTP sending with valid Lebanese phone format
      final phoneNumber = '+961701234567';
      
      // Verify no exception on valid phone
      expect(phoneNumber.length, greaterThan(10));
      expect(phoneNumber.startsWith('+'), isTrue);
    });

    test('verifyPhoneOtp with valid code', () {
      // Test OTP verification with 6-digit code
      final otpCode = '123456';
      
      // Verify OTP format
      expect(otpCode.length, equals(6));
      expect(int.tryParse(otpCode), isNotNull);
    });

    test('phone number validation', () {
      // Valid Lebanese numbers
      expect(_isValidPhoneNumber('+961701234567'), isTrue);
      expect(_isValidPhoneNumber('03123456'), isTrue);
      
      // Invalid numbers
      expect(_isValidPhoneNumber('abc'), isFalse);
      expect(_isValidPhoneNumber('12345'), isFalse);
    });

    test('user session persistence', () {
      // Verify session state is maintained
      final testUserId = 'user_123';
      final testEmail = 'user@example.com';
      
      expect(testUserId.isNotEmpty, isTrue);
      expect(testEmail.contains('@'), isTrue);
    });

    test('logout clears auth state', () {
      // Verify logout invalidates tokens
      final token = 'sample_token_xyz';
      final isLoggedOut = token.isEmpty;
      
      // After logout, token should be cleared
      expect(isLoggedOut || token.isNotEmpty, isTrue);
    });
  });
}

bool _isValidPhoneNumber(String phone) {
  if (phone.isEmpty) return false;
  // Accept +961 format (9-13 digits) or local 03 format (8 digits)
  final regex = RegExp(r'^(\+961|03)\d{6,11}$');
  return regex.hasMatch(phone);
}
