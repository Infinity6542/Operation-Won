import 'package:flutter/material.dart';
import 'package:operation_won/utils/error_handler.dart';

/// Utility for immediate UI feedback after operations
class UIFeedbackHelper {
  /// Show success feedback with optional callback
  static void showSuccess({
    required BuildContext context,
    required String message,
    VoidCallback? onComplete,
    Duration duration = const Duration(seconds: 3),
  }) {
    EnhancedErrorHandler.showSuccessSnackBar(
      context: context,
      message: message,
      duration: duration,
    );

    // Call completion callback after a brief delay
    if (onComplete != null) {
      Future.delayed(const Duration(milliseconds: 100), onComplete);
    }
  }

  /// Show error feedback with retry option
  static void showError({
    required BuildContext context,
    required String message,
    VoidCallback? onRetry,
    Duration duration = const Duration(seconds: 5),
  }) {
    EnhancedErrorHandler.showErrorSnackBar(
      context: context,
      message: message,
      onRetry: onRetry,
      duration: duration,
    );
  }

  /// Show operation in progress
  static void showInProgress({
    required BuildContext context,
    required String message,
  }) {
    EnhancedErrorHandler.showSuccessSnackBar(
      context: context,
      message: message,
      duration: const Duration(seconds: 2),
      showProgress: true,
    );
  }

  /// Force a widget rebuild by triggering a setState-like update
  static void forceRebuild(BuildContext context) {
    // This ensures any Consumer widgets listening to providers will rebuild
    if (context.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          // Trigger a rebuild by invalidating the context
          (context as Element).markNeedsBuild();
        }
      });
    }
  }
}
