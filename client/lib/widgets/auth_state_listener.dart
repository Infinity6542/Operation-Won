import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/state_synchronization_service.dart';

/// Widget that listens to authentication state changes and triggers proper UI updates
class AuthStateListener extends StatefulWidget {
  const AuthStateListener({super.key, required this.child});

  final Widget child;

  @override
  State<AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<AuthStateListener> {
  bool? _wasLoggedIn;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Check if login state has changed
        final isCurrentlyLoggedIn = authProvider.isLoggedIn;

        if (_wasLoggedIn != null && _wasLoggedIn != isCurrentlyLoggedIn) {
          // State changed, handle appropriately
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (isCurrentlyLoggedIn) {
              // User just logged in, wait a bit longer for API service to be ready
              await Future.delayed(const Duration(milliseconds: 300));
              // Then refresh all data and request permissions
              StateSynchronizationService.handleSignIn(context);
            }
            // Note: Sign out is handled in the settings view where logout is triggered
          });
        }

        _wasLoggedIn = isCurrentlyLoggedIn;
        return widget.child;
      },
    );
  }
}
