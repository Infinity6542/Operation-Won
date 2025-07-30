import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_model.dart';
import '../models/channel_model.dart';
import '../models/event_model.dart';
import 'secure_storage_service.dart';

class ApiService {
  static const String defaultBaseURL = 'http://localhost:8000';
  final Dio _dio;
  String? _token;
  String _baseUrl = defaultBaseURL;

  ApiService({String? baseUrl}) : _dio = Dio() {
    _baseUrl = baseUrl ?? defaultBaseURL;
    _dio.options.baseUrl = _baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);

    // Add request interceptor for auth token and automatic refresh
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Skip auth for public endpoints
          if (!_isPublicEndpoint(options.path)) {
            if (_token != null) {
              options.headers['Authorization'] = 'Bearer $_token';
            }
          }
          options.headers['Content-Type'] = 'application/json';
          handler.next(options);
        },
        onError: (error, handler) async {
          // Handle 401 errors with automatic token refresh
          if (error.response?.statusCode == 401 &&
              !_isPublicEndpoint(error.requestOptions.path) &&
              !error.requestOptions.path.contains('/refresh')) {
            debugPrint('Token expired, attempting refresh...');
            final refreshed = await refreshToken();

            if (refreshed) {
              // Retry the original request with new token
              final options = error.requestOptions;
              options.headers['Authorization'] = 'Bearer $_token';

              try {
                final response = await _dio.fetch(options);
                return handler.resolve(response);
              } catch (e) {
                debugPrint('Retry after refresh failed: $e');
              }
            }
          }

          debugPrint('API Error: ${error.message}');
          handler.next(error);
        },
      ),
    );

    _loadToken();
  }

  bool _isPublicEndpoint(String path) {
    return path.startsWith('/auth/') ||
        path.startsWith('/health') ||
        path.startsWith('/msg');
  }

  // Method to update the base URL
  void updateBaseUrl(String newBaseUrl) {
    if (_baseUrl != newBaseUrl) {
      _baseUrl = newBaseUrl;
      _dio.options.baseUrl = newBaseUrl;
      debugPrint('API Service: Updated base URL to $newBaseUrl');
    }
  }

  String get baseUrl => _baseUrl;

  Future<void> _loadToken() async {
    _token = await SecureStorageService.getToken();
  }

  // Public method to ensure token is loaded before checking auth state
  Future<void> initializeToken() async {
    await _loadToken();
  }

  Future<void> _saveToken(String token) async {
    await SecureStorageService.saveAuthData(token: token);
    _token = token;
  }

  Future<void> _clearToken() async {
    await SecureStorageService.clearAuthData();
    _token = null;
  }

  // Check if user is authenticated
  Future<bool> isAuthenticated() async {
    return await SecureStorageService.hasValidToken();
  }

  // Auth endpoints
  Future<AuthResponse> register(
      String username, String email, String password) async {
    try {
      final response = await _dio.post(
        '/auth/register',
        data: AuthRequest(
          username: username,
          email: email,
          password: password,
        ).toJson(),
      );

      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<AuthResponse> login(String usernameOrEmail, String password) async {
    try {
      // Determine if input is email or username
      bool isEmail = usernameOrEmail.contains('@');

      final response = await _dio.post(
        '/auth/login',
        data: AuthRequest(
          username: isEmail ? null : usernameOrEmail,
          email: isEmail ? usernameOrEmail : '',
          password: password,
        ).toJson(),
      );

      final authResponse = AuthResponse.fromJson(response.data);
      if (authResponse.token != null) {
        await _saveToken(authResponse.token!);
      }

      return authResponse;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      // Call logout endpoint to blacklist token
      if (_token != null) {
        await _dio.post('/api/logout');
      }
    } catch (e) {
      debugPrint('Logout API call failed: $e');
      // Continue with local logout even if API call fails
    } finally {
      await _clearToken();
    }
  }

  // Token refresh functionality
  Future<bool> refreshToken() async {
    try {
      // Use the current token (even if expired) for refresh
      if (_token == null) {
        debugPrint('No token available for refresh');
        return false;
      }

      final response = await _dio.post(
        '/api/refresh',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_token',
          },
        ),
      );

      final newToken = response.data['token'] as String?;
      if (newToken != null) {
        await _saveToken(newToken);
        debugPrint('Token refreshed successfully');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh failed: $e');
      return false;
    }
  }

  // Event endpoints
  Future<List<EventResponse>> getEvents() async {
    try {
      final response = await _dio.get('/api/protected/events');
      final List<dynamic> data = response.data;
      return data.map((json) => EventResponse.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> createEvent(String eventName,
      {String? eventDescription}) async {
    try {
      debugPrint('[API] Creating event: $eventName');
      final response = await _dio.post(
        '/api/protected/events/create',
        data: EventRequest(
          eventName: eventName,
          eventDescription: eventDescription ?? '',
        ).toJson(),
      );

      debugPrint('[API] Event creation response: ${response.data}');
      debugPrint('[API] Response data type: ${response.data.runtimeType}');

      // Handle both Map and String responses
      dynamic data = response.data;

      // If response is a String, try to parse it as JSON
      if (data is String) {
        debugPrint('[API] Response is String, attempting to parse as JSON');
        try {
          data = jsonDecode(data);
          debugPrint('[API] Successfully parsed JSON: $data');
        } catch (e) {
          debugPrint('[API] Failed to parse JSON string: $e');
          throw Exception('Invalid JSON response format');
        }
      }

      // Extract event_uuid from parsed data
      if (data is Map &&
          data.containsKey('event_uuid') &&
          data['event_uuid'] != null) {
        final eventUuid = data['event_uuid'];
        debugPrint('[API] Extracted event UUID: $eventUuid');
        return eventUuid.toString();
      }

      debugPrint(
          '[API] ERROR: Could not extract event_uuid from response: $data');
      throw Exception('Invalid response format: missing or null event_uuid');
    } on DioException catch (e) {
      debugPrint('[API] DioException creating event: ${e.message}');
      debugPrint('[API] Response data: ${e.response?.data}');
      throw _handleError(e);
    } catch (e) {
      debugPrint('[API] General exception creating event: $e');
      rethrow;
    }
  }

  // Channel endpoints
  Future<List<ChannelResponse>> getChannels() async {
    try {
      final response = await _dio.get('/api/protected/channels');
      final List<dynamic> data = response.data;
      return data.map((json) => ChannelResponse.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> createChannel(String channelName, {String? eventUuid}) async {
    try {
      debugPrint(
          '[API] Creating channel: $channelName with eventUuid: $eventUuid');
      final response = await _dio.post(
        '/api/protected/channels/create',
        data: ChannelRequest(
          channelName: channelName,
          eventUuid: eventUuid,
        ).toJson(),
      );

      debugPrint('[API] Channel creation response: ${response.data}');
      debugPrint('[API] Response data type: ${response.data.runtimeType}');

      // Check if the response contains channel_uuid
      if (response.data != null) {
        // Handle both Map and dynamic types
        dynamic data = response.data;

        // If response is a String, try to parse it as JSON
        if (data is String) {
          debugPrint('[API] Response is String, attempting to parse as JSON');
          try {
            data = jsonDecode(data);
            debugPrint('[API] Successfully parsed JSON: $data');
          } catch (e) {
            debugPrint('[API] Failed to parse JSON string: $e');
            throw Exception('Invalid JSON response format');
          }
        }

        if (data is Map<String, dynamic>) {
          debugPrint('[API] Response is Map<String, dynamic>');
          debugPrint('[API] Keys: ${data.keys.toList()}');
          if (data.containsKey('channel_uuid') &&
              data['channel_uuid'] != null) {
            final channelUuid = data['channel_uuid'];
            debugPrint('[API] Extracted channel UUID: $channelUuid');
            return channelUuid.toString();
          }
        } else if (data is Map) {
          debugPrint('[API] Response is generic Map');
          debugPrint('[API] Keys: ${data.keys.toList()}');
          if (data.containsKey('channel_uuid') &&
              data['channel_uuid'] != null) {
            final channelUuid = data['channel_uuid'];
            debugPrint('[API] Extracted channel UUID: $channelUuid');
            return channelUuid.toString();
          }
        } else {
          debugPrint(
              '[API] Response is neither Map<String, dynamic> nor Map: ${data.runtimeType}');
        }
      }

      debugPrint(
          '[API] ERROR: Could not extract channel_uuid from response: ${response.data}');
      throw Exception(
          'Invalid response format: missing or null channel_uuid'); // Fixed
    } on DioException catch (e) {
      debugPrint('[API] DioException creating channel: ${e.message}');
      debugPrint('[API] Response data: ${e.response?.data}');
      throw _handleError(e);
    } catch (e) {
      debugPrint('[API] General exception creating channel: $e');
      rethrow;
    }
  } // Debug version

  // Token management
  bool get isLoggedIn {
    if (_token == null) return false;

    try {
      final claims = decodeToken();
      if (claims == null) return false;

      // Check if token is expired
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return claims.exp > now;
    } catch (e) {
      return false;
    }
  }

  String? get token => _token;

  JWTClaims? decodeToken() {
    if (_token == null) return null;

    try {
      // Handle demo token
      if (_token!.contains('demo_token')) {
        return JWTClaims(
          userId: 1,
          username: 'demo',
          exp: DateTime.now()
                  .add(const Duration(days: 30))
                  .millisecondsSinceEpoch ~/
              1000,
        );
      }

      final parts = _token!.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payloadMap = jsonDecode(decoded);

      return JWTClaims.fromJson(payloadMap);
    } catch (e) {
      debugPrint('Error decoding token: $e');
      return null;
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final data = e.response!.data;

      if (data is String) {
        return data;
      } else if (data is Map && data.containsKey('error')) {
        return data['error'];
      }

      switch (statusCode) {
        case 400:
          return 'Invalid request. Please check your input.';
        case 401:
          return 'Authentication failed. Please login again.';
        case 403:
          return 'Access denied.';
        case 404:
          return 'Resource not found.';
        case 409:
          return 'Resource already exists.';
        case 500:
          return 'Server error. Please try again later.';
        default:
          return 'Request failed with status $statusCode';
      }
    } else {
      return 'Network error. Please check your connection.';
    }
  }
}
