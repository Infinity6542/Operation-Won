import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Enhanced error handler with retry functionality and user-friendly messages
class EnhancedErrorHandler {
  static const Map<String, String> _errorMessages = {
    'network':
        'Network connection failed. Please check your internet connection.',
    'timeout': 'Request timed out. Please try again.',
    'server': 'Server error occurred. Please try again later.',
    'auth': 'Authentication failed. Please check your credentials.',
    'permission': 'Permission denied. Please check your access rights.',
  };

  /// Show error snackbar with retry action
  static void showErrorSnackBar({
    required BuildContext context,
    required String message,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 5),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getUserFriendlyMessage(message),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        action: onRetry != null
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Show detailed error dialog
  static Future<void> showErrorDialog({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              LucideIcons.circleAlert,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(_getUserFriendlyMessage(message)),
        actions: [
          if (onRetry != null)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Retry'),
            ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onDismiss?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Get user-friendly error message
  static String _getUserFriendlyMessage(String originalMessage) {
    final lowerMessage = originalMessage.toLowerCase();

    if (lowerMessage.contains('network') ||
        lowerMessage.contains('connection')) {
      return _errorMessages['network']!;
    } else if (lowerMessage.contains('timeout')) {
      return _errorMessages['timeout']!;
    } else if (lowerMessage.contains('server') ||
        lowerMessage.contains('500') ||
        lowerMessage.contains('502') ||
        lowerMessage.contains('503')) {
      return _errorMessages['server']!;
    } else if (lowerMessage.contains('auth') ||
        lowerMessage.contains('401') ||
        lowerMessage.contains('403')) {
      return _errorMessages['auth']!;
    } else if (lowerMessage.contains('permission') ||
        lowerMessage.contains('forbidden')) {
      return _errorMessages['permission']!;
    }

    // Return original message if no pattern matches, but clean it up
    return originalMessage.length > 100
        ? '${originalMessage.substring(0, 100)}...'
        : originalMessage;
  }

  /// Show loading dialog that can be dismissed
  static void showLoadingDialog({
    required BuildContext context,
    String message = 'Loading...',
    bool barrierDismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => PopScope(
        canPop: barrierDismissible,
        child: AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  /// Dismiss any currently showing dialog
  static void dismissDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
