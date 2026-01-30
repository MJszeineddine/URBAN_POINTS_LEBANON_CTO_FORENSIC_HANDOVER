import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class RoleValidator {
  final AuthService _authService;

  RoleValidator(this._authService);

  // Validate role for customer app
  Future<RoleValidationResult> validateForCustomerApp() async {
    try {
      // Check if user is authenticated
      if (!_authService.isAuthenticated) {
        return RoleValidationResult(
          isValid: false,
          reason: 'User is not authenticated',
          shouldSignOut: false,
        );
      }

      // Force refresh token to get latest custom claims
      await _authService.forceRefreshIdToken();

      // Get user role
      final role = await _authService.getUserRole();
      
      if (role == null) {
        return RoleValidationResult(
          isValid: false,
          reason: 'User role not found. Please try signing in again.',
          shouldSignOut: true,
        );
      }

      // Check if role is valid for customer app
      if (role != 'customer' && role != 'user') {
        return RoleValidationResult(
          isValid: false,
          reason: 'This app is for customers only. Your account has role: $role',
          shouldSignOut: true,
        );
      }

      // Check if user is active
      final isActive = await _authService.isUserActive();
      if (!isActive) {
        return RoleValidationResult(
          isValid: false,
          reason: 'Your account has been deactivated. Please contact support.',
          shouldSignOut: true,
        );
      }

      return RoleValidationResult(
        isValid: true,
        role: role,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Role validation error: $e');
      }
      return RoleValidationResult(
        isValid: false,
        reason: 'Error validating role: $e',
        shouldSignOut: false,
      );
    }
  }

  // Quick role check (without token refresh)
  Future<bool> quickRoleCheck() async {
    try {
      final role = await _authService.getUserRole();
      return role == 'customer' || role == 'user';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Quick role check error: $e');
      }
      return false;
    }
  }
}

class RoleValidationResult {
  final bool isValid;
  final String? reason;
  final String? role;
  final bool shouldSignOut;

  RoleValidationResult({
    required this.isValid,
    this.reason,
    this.role,
    this.shouldSignOut = false,
  });
}
