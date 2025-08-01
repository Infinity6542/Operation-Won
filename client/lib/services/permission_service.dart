import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Check if microphone permission is granted
  static Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Request microphone permission with user-friendly dialog
  static Future<bool> requestMicrophonePermission([BuildContext? context]) async {
    final status = await Permission.microphone.status;
    
    // If already granted, return true
    if (status.isGranted) {
      return true;
    }
    
    // If permanently denied, show settings dialog
    if (status.isPermanentlyDenied) {
      if (context != null) {
        return await _showPermissionSettingsDialog(context);
      }
      return false;
    }
    
    // If denied but not permanently, show explanation dialog first
    if (status.isDenied && context != null) {
      final shouldRequest = await _showPermissionExplanationDialog(context);
      if (!shouldRequest) {
        return false;
      }
    }
    
    // Request the permission
    final result = await Permission.microphone.request();
    
    // Handle the result
    if (result.isGranted) {
      return true;
    } else if (result.isPermanentlyDenied && context != null) {
      return await _showPermissionSettingsDialog(context);
    }
    
    return false;
  }

  /// Request microphone permission at app startup
  static Future<bool> requestMicrophonePermissionAtStartup(BuildContext context) async {
    try {
      final status = await Permission.microphone.status;
      
      // If already granted, no need to request
      if (status.isGranted) {
        debugPrint('[Permissions] Microphone permission already granted');
        return true;
      }
      
      // Show explanation dialog and request permission
      return await requestMicrophonePermission(context);
    } catch (e) {
      debugPrint('[Permissions] Error requesting microphone permission: $e');
      return false;
    }
  }

  /// Show explanation dialog before requesting permission
  static Future<bool> _showPermissionExplanationDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.mic, color: Colors.blue),
              SizedBox(width: 8),
              Text('Microphone Permission'),
            ],
          ),
          content: const Text(
            'Operation Won needs access to your microphone to enable Push-to-Talk communication with your team.\n\n'
            'Your audio is only transmitted when you actively press and hold the PTT button.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not Now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Allow'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Show dialog to open app settings when permission is permanently denied
  static Future<bool> _showPermissionSettingsDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings, color: Colors.orange),
              SizedBox(width: 8),
              Text('Permission Required'),
            ],
          ),
          content: const Text(
            'Microphone permission is required for Push-to-Talk functionality.\n\n'
            'Please enable microphone access in your device settings to use voice communication.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop(false);
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  /// Check multiple permissions at once
  static Future<Map<Permission, PermissionStatus>> checkMultiplePermissions() async {
    return await [
      Permission.microphone,
    ].request();
  }

  /// Get permission status as human-readable string
  static String getPermissionStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'Granted';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      case PermissionStatus.provisional:
        return 'Provisional';
    }
  }

  /// Show a comprehensive permission status dialog (useful for debugging)
  static Future<void> showPermissionStatusDialog(BuildContext context) async {
    final micStatus = await Permission.microphone.status;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Status'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Microphone: ${getPermissionStatusText(micStatus)}'),
              const SizedBox(height: 8),
              if (!micStatus.isGranted)
                const Text(
                  'Note: Microphone permission is required for PTT functionality.',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
            ],
          ),
          actions: [
            if (!micStatus.isGranted)
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await requestMicrophonePermission(context);
                },
                child: const Text('Request Permission'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
