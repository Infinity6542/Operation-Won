import 'package:package_info_plus/package_info_plus.dart';

class VersionService {
  static PackageInfo? _packageInfo;

  static Future<void> initialize() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  // x.x.x
  static String get version {
    return _packageInfo?.version ?? 'Unknown';
  }

  // x
  static String get buildNumber {
    return _packageInfo?.buildNumber ?? 'Unknown';
  }

  /// Get the app name
  static String get appName {
    return _packageInfo?.appName ?? 'Operation Won';
  }

  /// Get the package name
  // static String get packageName {
  //   return _packageInfo?.packageName ?? 'Unknown';
  // }

  // x.x.x+x
  static String get formattedVersion {
    if (_packageInfo == null) return 'Unknown';
    return '${_packageInfo!.version}+${_packageInfo!.buildNumber}';
  }

  /// Get formatted version with app name (e.g., "Operation Won v0.0.3")
  static String get fullVersionString {
    if (_packageInfo == null) return 'Operation Won - Unknown Version';
    return '${_packageInfo!.appName} v${_packageInfo!.version}';
  }

  /// Check if version service is initialized
  static bool get isInitialized => _packageInfo != null;
}
