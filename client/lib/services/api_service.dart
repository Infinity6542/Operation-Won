import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_model.dart';
import '../models/channel_model.dart';
import '../models/event_model.dart';
import 'secure_storage_service.dart';

class ApiService {
  final Dio _dio;
  String? _token;
  bool _isRefreshing = false; // Flag to prevent concurrent token refreshes
  final List<Completer<void>> _refreshCompleters =
      []; // Queue for pending requests during refresh

  // Callback for when authentication fails (token revoked/invalid)
  Function()? onAuthenticationFailed;

  ApiService({required String baseUrl, this.onAuthenticationFailed})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
          headers: {
            'Content-Type': 'application/json',
          },
        )) {
    debugPrint('ApiService initialized with base URL: $baseUrl');

    // Add request interceptor for auth token and automatic refresh
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Skip auth for public endpoints
          if (!_isPublicEndpoint(options.path)) {
            if (_token != null) {
              options.headers['Authorization'] = 'Bearer $_token';
            } else {
              // Reject requests to protected endpoints when no token is available
              debugPrint(
                  'No token available for protected endpoint: ${options.path}');
              final response = Response(
                requestOptions: options,
                statusCode: 401,
                statusMessage: 'No authentication token available',
                data: {'error': 'Authentication required. Please log in.'},
              );
              handler.reject(DioException(
                requestOptions: options,
                response: response,
                type: DioExceptionType.badResponse,
                message: 'Authentication required. Please log in.',
              ));
              return;
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
            final responseData = error.response?.data?.toString() ?? '';

            // Check if token has been revoked
            if (responseData.contains('Token has been revoked') ||
                responseData.contains('revoked')) {
              debugPrint('Token has been revoked, clearing auth data...');
              await _clearToken();
              onAuthenticationFailed?.call();
              handler.next(error);
              return;
            }

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
            } else {
              // Refresh failed, clear token
              debugPrint('Token refresh failed, clearing auth data...');
              await _clearToken();
              onAuthenticationFailed?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
    _loadToken();
  }

  void setBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
    debugPrint('ApiService base URL updated to: $newBaseUrl');
  }

  bool _isPublicEndpoint(String path) {
    return path.startsWith('/auth/') ||
        path.startsWith('/health') ||
        path.startsWith('/metrics');
  }

  Future<void> _loadToken() async {
    _token = await SecureStorageService.getToken();
    if (_token != null) {
      debugPrint('Token loaded successfully.');
    } else {
      debugPrint('No token found in storage.');
    }
  }

  // Public method to ensure token is loaded before checking auth state
  Future<void> initializeToken() async {
    await _loadToken();
    debugPrint('[API] Token initialized. Token exists: ${_token != null}');
    if (_token != null) {
      debugPrint('[API] Token preview: ${_token!.substring(0, 20)}...');
      final claims = decodeToken();
      if (claims != null) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final isExpired = claims.exp <= now;
        debugPrint(
            '[API] Token expires at: ${claims.exp}, Current time: $now, Expired: $isExpired');

        // Don't clear expired tokens automatically - let the refresh mechanism handle it
        // This allows the refresh interceptor to attempt token refresh before clearing
        if (isExpired) {
          debugPrint(
              '[API] Token is expired but keeping for potential refresh');
        }
      } else {
        debugPrint('[API] Failed to decode token, clearing invalid token');
        await _clearToken();
      }
    }
  }

  // Validate token with server (useful for checking if token is blacklisted)
  Future<bool> validateTokenWithServer() async {
    if (_token == null) return false;

    try {
      // Try a simple authenticated request to verify token is still valid on server
      await _dio.get('/api/protected/events');
      return true;
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('401') ||
          errorString.contains('revoked') ||
          errorString.contains('unauthorized')) {
        debugPrint(
            '[API] Server token validation failed: token revoked/invalid');
        await _clearToken();
        onAuthenticationFailed?.call();
        return false;
      }
      // For network errors or other issues, assume token is still valid
      debugPrint('[API] Server token validation inconclusive: $e');
      return true;
    }
  }

  Future<void> _saveToken(String token) async {
    _token = token; // Set token first to avoid race conditions
    await SecureStorageService.saveAuthData(token: token);
  }

  Future<void> _clearToken() async {
    await SecureStorageService.clearAuthData();
    _token = null;
    // Reset refresh state when clearing tokens
    _isRefreshing = false;
    _completeAllPendingRefreshes();
  }

  // Public method to clear tokens (for auth failure handling)
  Future<void> clearAuthenticationData() async {
    await _clearToken();
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

      final loginData = AuthRequest(
        username: isEmail ? null : usernameOrEmail,
        email: isEmail ? usernameOrEmail : '',
        password: password,
      ).toJson();

      // Debug logging
      debugPrint(
          '[ApiService] Login attempt - Username: ${loginData['username']}, Email: ${loginData['email']}, Password length: ${password.length}');

      final response = await _dio.post(
        '/auth/login',
        data: loginData,
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

  // Token refresh functionality with concurrency control
  Future<bool> refreshToken() async {
    try {
      // If refresh is already in progress, wait for it to complete
      if (_isRefreshing) {
        final completer = Completer<void>();
        _refreshCompleters.add(completer);
        await completer.future;
        return _token !=
            null; // Return success based on whether we have a token after refresh
      }

      _isRefreshing = true;

      // Load the latest token from storage in case it was updated elsewhere
      await _loadToken();

      // Use the current token (even if expired) for refresh
      if (_token == null) {
        debugPrint('No token available for refresh');
        _isRefreshing = false;
        _completeAllPendingRefreshes();
        return false;
      }

      debugPrint('Attempting token refresh with existing token...');
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
        _isRefreshing = false;
        _completeAllPendingRefreshes();
        return true;
      }
      debugPrint('Token refresh response did not contain new token');
      _isRefreshing = false;
      _completeAllPendingRefreshes();
      return false;
    } catch (e) {
      debugPrint('Token refresh failed: $e');

      // Check if the error indicates the token was revoked
      if (e.toString().contains('Token has been revoked') ||
          e.toString().contains('revoked') ||
          e.toString().contains('401')) {
        debugPrint(
            'Token appears to be revoked during refresh, clearing local auth data...');
        await _clearToken();
        onAuthenticationFailed?.call();
      }

      _isRefreshing = false;
      _completeAllPendingRefreshes();
      return false;
    }
  }

  // Complete all pending refresh requests
  void _completeAllPendingRefreshes() {
    for (final completer in _refreshCompleters) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    _refreshCompleters.clear();
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

  Future<String> joinEvent(String inviteCode) async {
    try {
      debugPrint('[API] Joining event with invite code: $inviteCode');
      final response = await _dio.post(
        '/api/protected/events/join',
        data: {'invite_code': inviteCode},
      );

      debugPrint('[API] Join event response: ${response.data}');

      // Extract event name from response if available
      if (response.data is Map && response.data['event_name'] != null) {
        return response.data['event_name'].toString();
      }

      return 'Event'; // Fallback name
    } on DioException catch (e) {
      debugPrint('[API] DioException joining event: ${e.message}');
      debugPrint('[API] Response data: ${e.response?.data}');
      throw _handleError(e);
    } catch (e) {
      debugPrint('[API] General exception joining event: $e');
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
      throw Exception('Invalid response format: missing or null channel_uuid');
    } on DioException catch (e) {
      debugPrint('[API] DioException creating channel: ${e.message}');
      debugPrint('[API] Response data: ${e.response?.data}');
      throw _handleError(e);
    } catch (e) {
      debugPrint('[API] General exception creating channel: $e');
      rethrow;
    }
  }

  Future<void> deleteChannel(String channelUuid) async {
    try {
      debugPrint('[API] Deleting channel: $channelUuid');
      final response =
          await _dio.delete('/api/protected/channels/$channelUuid/delete');
      debugPrint('[API] Channel deletion response: ${response.data}');
    } on DioException catch (e) {
      debugPrint('[API] DioException deleting channel: ${e.message}');
      debugPrint('[API] Response data: ${e.response?.data}');
      throw _handleError(e);
    } catch (e) {
      debugPrint('[API] General exception deleting channel: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventUuid) async {
    try {
      debugPrint('[API] Deleting event: $eventUuid');
      final response =
          await _dio.delete('/api/protected/events/$eventUuid/delete');
      debugPrint('[API] Event deletion response: ${response.data}');
    } on DioException catch (e) {
      debugPrint('[API] DioException deleting event: ${e.message}');
      debugPrint('[API] Response data: ${e.response?.data}');
      throw _handleError(e);
    } catch (e) {
      debugPrint('[API] General exception deleting event: $e');
      rethrow;
    }
  }

  Future<void> updateChannel(String channelUuid, String newChannelName) async {
    try {
      debugPrint('[API] Updating channel: $channelUuid to $newChannelName');
      final response = await _dio.put(
        '/api/protected/channels/$channelUuid/update',
        data: {'channel_name': newChannelName},
      );
      debugPrint('[API] Channel update response: ${response.data}');
    } on DioException catch (e) {
      debugPrint('[API] DioException updating channel: ${e.message}');
      debugPrint('[API] Response data: ${e.response?.data}');
      throw _handleError(e);
    } catch (e) {
      debugPrint('[API] General exception updating channel: $e');
      rethrow;
    }
  }

  Future<void> updateEvent(String eventUuid, String newEventName,
      {String? newEventDescription}) async {
    try {
      debugPrint('[API] Updating event: $eventUuid to $newEventName');
      final response = await _dio.put(
        '/api/protected/events/$eventUuid/update',
        data: {
          'event_name': newEventName,
          if (newEventDescription != null)
            'event_description': newEventDescription,
        },
      );
      debugPrint('[API] Event update response: ${response.data}');
    } on DioException catch (e) {
      debugPrint('[API] DioException updating event: ${e.message}');
      debugPrint('[API] Response data: ${e.response?.data}');
      throw _handleError(e);
    } catch (e) {
      debugPrint('[API] General exception updating event: $e');
      rethrow;
    }
  }

  // Token management
  bool get isLoggedIn {
    if (_token == null) {
      debugPrint('[API] isLoggedIn: false (no token)');
      return false;
    }

    try {
      final claims = decodeToken();
      if (claims == null) {
        debugPrint('[API] isLoggedIn: false (invalid token)');
        return false;
      }

      // Check if token is expired
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final isValid = claims.exp > now;
      debugPrint(
          '[API] isLoggedIn: $isValid (expires: ${claims.exp}, now: $now)');
      return isValid;
    } catch (e) {
      debugPrint('[API] isLoggedIn: false (decode error: $e)');
      return false;
    }
  }

  // Check if we have any token that could potentially be used for refresh
  bool get hasTokenForRefresh {
    return _token != null && _token!.isNotEmpty;
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
    debugPrint('DioException occurred: ${e.type}');
    debugPrint('Error message: ${e.message}');
    debugPrint('Request URI: ${e.requestOptions.uri}');

    if (e.response != null) {
      debugPrint('Response status code: ${e.response!.statusCode}');
      debugPrint('Response data: ${e.response!.data}');

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
      // Network/connection errors
      debugPrint('No response received - connection error');
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
          return 'Connection timeout. Please check your internet connection.';
        case DioExceptionType.sendTimeout:
          return 'Request timeout. Please try again.';
        case DioExceptionType.receiveTimeout:
          return 'Response timeout. Please try again.';
        case DioExceptionType.connectionError:
          return 'Connection failed. Please check the server address and your network connection.';
        default:
          return 'Network error. Please check your connection and server address.';
      }
    }
  }
}
