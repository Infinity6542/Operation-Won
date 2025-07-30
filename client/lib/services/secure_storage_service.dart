import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class SecureStorageService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      preferencesKeyPrefix: 'opwon_secure_',
    ),
    iOptions: IOSOptions(
      groupId: 'com.opwon.client.secure',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    lOptions: LinuxOptions(
      encryptedSharedPreferences: true,
    ),
    wOptions: WindowsOptions(
      encryptedSharedPreferences: true,
    ),
    mOptions: MacOsOptions(
      groupId: 'com.opwon.client.secure',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Keys for secure storage
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';

  // Token management
  static Future<void> saveAuthData({
    required String token,
    String? refreshToken,
    int? userId,
    String? username,
  }) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      
      if (refreshToken != null) {
        await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
      }
      
      if (userId != null) {
        await _secureStorage.write(key: _userIdKey, value: userId.toString());
      }
      
      if (username != null) {
        await _secureStorage.write(key: _usernameKey, value: username);
      }
      
      debugPrint('Auth data saved securely');
    } catch (e) {
      debugPrint('Error saving auth data: $e');
      rethrow;
    }
  }

  static Future<String?> getToken() async {
    try {
      return await _secureStorage.read(key: _tokenKey);
    } catch (e) {
      debugPrint('Error reading token: $e');
      return null;
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: _refreshTokenKey);
    } catch (e) {
      debugPrint('Error reading refresh token: $e');
      return null;
    }
  }

  static Future<int?> getUserId() async {
    try {
      final userIdStr = await _secureStorage.read(key: _userIdKey);
      return userIdStr != null ? int.tryParse(userIdStr) : null;
    } catch (e) {
      debugPrint('Error reading user ID: $e');
      return null;
    }
  }

  static Future<String?> getUsername() async {
    try {
      return await _secureStorage.read(key: _usernameKey);
    } catch (e) {
      debugPrint('Error reading username: $e');
      return null;
    }
  }

  static Future<void> clearAuthData() async {
    try {
      await Future.wait([
        _secureStorage.delete(key: _tokenKey),
        _secureStorage.delete(key: _refreshTokenKey),
        _secureStorage.delete(key: _userIdKey),
        _secureStorage.delete(key: _usernameKey),
      ]);
      debugPrint('Auth data cleared');
    } catch (e) {
      debugPrint('Error clearing auth data: $e');
      rethrow;
    }
  }

  static Future<bool> hasValidToken() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return false;
      }
      
      // Basic JWT validation - check if it has three parts
      final parts = token.split('.');
      if (parts.length != 3) {
        debugPrint('Invalid JWT format');
        return false;
      }
      
      // Decode payload to check expiration
      try {
        final payload = parts[1];
        // Add padding if needed
        String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        
        final decoded = utf8.decode(base64.decode(normalized));
        final payloadMap = json.decode(decoded) as Map<String, dynamic>;
        
        if (payloadMap.containsKey('exp')) {
          final exp = payloadMap['exp'] as num;
          final currentTime = DateTime.now().millisecondsSinceEpoch / 1000;
          
          if (currentTime >= exp) {
            debugPrint('Token has expired');
            return false;
          }
        }
        
        return true;
      } catch (e) {
        debugPrint('Error validating token: $e');
        return false;
      }
    } catch (e) {
      debugPrint('Error checking token validity: $e');
      return false;
    }
  }

  // Clear all secure storage (for debugging/development)
  static Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
      debugPrint('All secure storage cleared');
    } catch (e) {
      debugPrint('Error clearing all storage: $e');
    }
  }
}
