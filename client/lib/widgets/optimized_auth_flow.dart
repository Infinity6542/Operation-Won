import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../pages/auth_page.dart';
import '../pages/home_page.dart';

/// Optimized authentication flow using Selector for better performance
class OptimizedAuthenticationFlow extends StatelessWidget {
  const OptimizedAuthenticationFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<AuthProvider, _AuthState>(
      selector: (context, authProvider) => _AuthState(
        isLoading: authProvider.isLoading,
        isLoggedIn: authProvider.isLoggedIn,
        error: authProvider.error,
      ),
      builder: (context, authState, child) {
        debugPrint(
            'AuthenticationFlow: isLoading=${authState.isLoading}, isLoggedIn=${authState.isLoggedIn}, error=${authState.error}');

        // Show error if there's one
        if (authState.error != null) {
          return const _ErrorScreen();
        }

        // Show loading screen while checking authentication
        if (authState.isLoading) {
          return const _LoadingScreen();
        }

        // Show main app if logged in, otherwise show auth page
        return authState.isLoggedIn ? const HomePage() : const AuthPage();
      },
    );
  }
}

/// Immutable state class for better optimization
class _AuthState {
  const _AuthState({
    required this.isLoading,
    required this.isLoggedIn,
    required this.error,
  });

  final bool isLoading;
  final bool isLoggedIn;
  final String? error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AuthState &&
          runtimeType == other.runtimeType &&
          isLoading == other.isLoading &&
          isLoggedIn == other.isLoggedIn &&
          error == other.error;

  @override
  int get hashCode => isLoading.hashCode ^ isLoggedIn.hashCode ^ error.hashCode;
}

/// Optimized error screen widget with const constructor
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.circleAlert,
                  color: Theme.of(context).colorScheme.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Connection Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Provider.of<AuthProvider>(context, listen: false)
                        .clearError();
                  },
                  icon: const Icon(LucideIcons.refreshCw),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Optimized loading screen widget with const constructor
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xff59dafb),
            ),
            SizedBox(height: 16),
            Text(
              'Loading...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
