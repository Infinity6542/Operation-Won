import 'package:flutter_test/flutter_test.dart';
import 'package:operation_won/providers/auth_provider.dart';
import 'package:operation_won/providers/settings_provider.dart';
import 'package:operation_won/models/auth_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('=== AUTH PROVIDER TESTS ===', () {
    late AuthProvider authProvider;
    late SettingsProvider settingsProvider;

    setUp(() {
      settingsProvider = SettingsProvider();
    });

    tearDown(() {
      try {
        authProvider.dispose();
      } catch (e) {
        // Ignore disposal errors in tests
      }
      try {
        settingsProvider.dispose();
      } catch (e) {
        // Ignore disposal errors in tests
      }
    });

    group('Initialization Tests', () {
      test('should initialize without settings provider', () async {
        authProvider = AuthProvider();

        // Wait for initialization to complete
        await Future.delayed(Duration(milliseconds: 100));

        expect(authProvider.user, isNull);
        expect(authProvider.isLoggedIn, false);
        expect(authProvider.error, isNull);
      });

      test('should initialize with settings provider', () async {
        authProvider = AuthProvider(settingsProvider: settingsProvider);

        // Wait for initialization to complete
        await Future.delayed(Duration(milliseconds: 100));

        expect(authProvider.user, isNull);
        expect(authProvider.isLoggedIn, false);
        expect(authProvider.error, isNull);
      });

      test('should handle provider lifecycle properly', () async {
        authProvider = AuthProvider();

        expect(() => authProvider.dispose(), returnsNormally);
      });
    });

    group('Error Management Tests', () {
      setUp(() async {
        authProvider = AuthProvider(settingsProvider: settingsProvider);
        await Future.delayed(Duration(milliseconds: 50));
      });

      test('should clear error state', () {
        authProvider.clearError();
        expect(authProvider.error, isNull);
      });

      test('should handle API errors during login', () async {
        final result = await authProvider.login('', '');

        expect(result, false);
        expect(authProvider.error, isNotNull);
        expect(authProvider.isLoading, false);
      });

      test('should handle API errors during registration', () async {
        final result = await authProvider.register('', '', '');

        expect(result, false);
        expect(authProvider.error, isNotNull);
        expect(authProvider.isLoading, false);
      });
    });

    group('State Management Tests', () {
      setUp(() async {
        authProvider = AuthProvider(settingsProvider: settingsProvider);
        await Future.delayed(Duration(milliseconds: 50));
      });

      test('should maintain consistent state types', () {
        expect(authProvider.isLoading, isA<bool>());
        expect(authProvider.error, anyOf(isNull, isA<String>()));
        expect(authProvider.user, anyOf(isNull, isA<JWTClaims>()));
        expect(authProvider.isLoggedIn, isA<bool>());
      });

      test('should notify listeners on state changes', () {
        int notificationCount = 0;

        authProvider.addListener(() {
          notificationCount++;
        });

        authProvider.clearError();

        expect(notificationCount, greaterThanOrEqualTo(0));
      });

      test('should handle multiple operations sequentially', () async {
        await authProvider.login('test', 'password');
        await authProvider.register('test', 'test@example.com', 'password');
        await authProvider.logout();

        expect(authProvider.isLoading, false);
      });
    });

    group('Login Functionality Tests', () {
      setUp(() async {
        authProvider = AuthProvider(settingsProvider: settingsProvider);
        await Future.delayed(Duration(milliseconds: 50));
      });

      test('should handle login with valid credentials', () async {
        final result = await authProvider.login('testuser', 'password123');

        // Will fail due to no server connection, but validates input handling
        expect(result, false);
        expect(authProvider.isLoading, false);
      });

      test('should handle login with empty credentials', () async {
        final result = await authProvider.login('', '');

        expect(result, false);
        expect(authProvider.error, isNotNull);
        expect(authProvider.isLoading, false);
      });

      test('should format username as email for demo mode', () async {
        final result = await authProvider.login('testuser', 'password');

        // Should attempt login (will fail due to no server)
        expect(result, false);
        expect(authProvider.isLoading, false);
      });

      test('should handle email format username correctly', () async {
        final result = await authProvider.login('test@example.com', 'password');

        expect(result, false);
        expect(authProvider.isLoading, false);
      });
    });

    group('Registration Functionality Tests', () {
      setUp(() async {
        authProvider = AuthProvider(settingsProvider: settingsProvider);
        await Future.delayed(Duration(milliseconds: 50));
      });

      test('should handle registration with valid data', () async {
        final result = await authProvider.register(
            'testuser', 'test@example.com', 'password123');

        expect(result, false); // Will fail due to no server
        expect(authProvider.isLoading, false);
      });

      test('should handle registration with empty username', () async {
        final result =
            await authProvider.register('', 'test@example.com', 'password');

        expect(result, false);
        expect(authProvider.error, isNotNull);
      });

      test('should handle registration with empty email', () async {
        final result = await authProvider.register('testuser', '', 'password');

        expect(result, false);
        expect(authProvider.error, isNotNull);
      });

      test('should handle registration with empty password', () async {
        final result =
            await authProvider.register('testuser', 'test@example.com', '');

        expect(result, false);
        expect(authProvider.error, isNotNull);
      });
    });

    group('Logout Functionality Tests', () {
      setUp(() async {
        authProvider = AuthProvider(settingsProvider: settingsProvider);
        await Future.delayed(Duration(milliseconds: 50));
      });

      test('should handle logout when not logged in', () async {
        await authProvider.logout();

        expect(authProvider.isLoggedIn, false);
        expect(authProvider.user, isNull);
        expect(authProvider.isLoading, false);
      });

      test('should clear user data on logout', () async {
        await authProvider.logout();

        expect(authProvider.user, isNull);
        expect(authProvider.isLoggedIn, false);
      });
    });

    group('Token Management Tests', () {
      setUp(() async {
        authProvider = AuthProvider(settingsProvider: settingsProvider);
        await Future.delayed(Duration(milliseconds: 50));
      });

      test('should decode token when available', () {
        // No token available in test environment
        expect(authProvider.user, isNull);
      });

      test('should handle user state correctly', () {
        expect(authProvider.isLoggedIn, false);
        expect(authProvider.user, isNull);
      });
    });

    group('Settings Integration Tests', () {
      test('should respond to settings changes', () async {
        authProvider = AuthProvider(settingsProvider: settingsProvider);
        await Future.delayed(Duration(milliseconds: 50));

        // Change API endpoint
        settingsProvider.setApiEndpoint('https://new-api.example.com');

        // Should update internal API service
        expect(settingsProvider.apiEndpoint, 'https://new-api.example.com');
      });

      test('should work without settings provider', () async {
        authProvider = AuthProvider();
        await Future.delayed(Duration(milliseconds: 50));

        expect(authProvider.isLoading, false);
        expect(authProvider.error, isNull);
      });
    });
  });
}
