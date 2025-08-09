import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../comms_state.dart';

/// Utility class for handling connection tests with proper error handling and loading states
class ConnectionTestUtil {
  static const Duration _connectionTimeout = Duration(seconds: 10);

  /// Test API connection with better error handling and timeout
  static Future<ConnectionTestResult> testApiConnection(String endpoint) async {
    try {
      final dio = Dio();
      dio.options.baseUrl = endpoint;
      dio.options.connectTimeout = _connectionTimeout;
      dio.options.receiveTimeout = _connectionTimeout;
      dio.options.headers = {
        'User-Agent': 'OperationWon-Client/1.0',
      };

      final response = await dio.get('/health');

      if (response.statusCode == 200) {
        return ConnectionTestResult.success('Connection successful');
      } else {
        return ConnectionTestResult.error(
            'Server responded with ${response.statusCode}');
      }
    } on DioException catch (e) {
      return ConnectionTestResult.error(_getDioErrorMessage(e));
    } catch (e) {
      return ConnectionTestResult.error('Unexpected error: ${e.toString()}');
    }
  }

  /// Test WebSocket connection with timeout
  static Future<ConnectionTestResult> testWebSocketConnection(
      CommsState commsState) async {
    try {
      final success =
          await commsState.testConnection().timeout(_connectionTimeout);

      if (success) {
        return ConnectionTestResult.success('WebSocket connection successful');
      } else {
        return ConnectionTestResult.error('WebSocket connection failed');
      }
    } catch (e) {
      return ConnectionTestResult.error(
          'WebSocket test failed: ${e.toString()}');
    }
  }

  /// Get user-friendly error message from DioException
  static String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout - server took too long to respond';
      case DioExceptionType.receiveTimeout:
        return 'Receive timeout - server response too slow';
      case DioExceptionType.connectionError:
        return 'Connection error - check your internet connection';
      case DioExceptionType.badResponse:
        return 'Server error (${e.response?.statusCode})';
      default:
        return 'Network error: ${e.message}';
    }
  }

  /// Show connection test dialog with loading state
  static Future<void> showConnectionTestDialog({
    required BuildContext context,
    required String title,
    required Future<ConnectionTestResult> Function() testFunction,
  }) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ConnectionTestDialog(),
    );

    try {
      final result = await testFunction();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        _showResultDialog(context, title, result);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        _showResultDialog(context, title,
            ConnectionTestResult.error('Test failed: ${e.toString()}'));
      }
    }
  }

  /// Show test result dialog
  static void _showResultDialog(
      BuildContext context, String title, ConnectionTestResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.isSuccess ? Icons.check_circle : Icons.error,
              color: result.isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Loading dialog for connection tests
class _ConnectionTestDialog extends StatelessWidget {
  const _ConnectionTestDialog();

  @override
  Widget build(BuildContext context) {
    return const AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Testing connection...'),
        ],
      ),
    );
  }
}

/// Result of connection test
class ConnectionTestResult {
  const ConnectionTestResult._(this.isSuccess, this.message);

  factory ConnectionTestResult.success(String message) =>
      ConnectionTestResult._(true, message);

  factory ConnectionTestResult.error(String message) =>
      ConnectionTestResult._(false, message);

  final bool isSuccess;
  final String message;
}
