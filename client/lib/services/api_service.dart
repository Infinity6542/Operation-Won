import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/auth_model.dart';
import '../models/channel_model.dart';
import '../models/event_model.dart';

class ApiService {
  static const String baseURL = 'http://localhost:8000';
  final Dio _dio;
  String? _token;

  ApiService() : _dio = Dio() {
    _dio.options.baseUrl = baseURL;
    _dio.options.connectTimeout = const Duration(seconds: 5);
    _dio.options.receiveTimeout = const Duration(seconds: 3);

    // Add request interceptor for auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_token != null) {
            options.headers['auth'] = 'Bearer $_token';
          }
          options.headers['Content-Type'] = 'application/json';
          handler.next(options);
        },
        onError: (error, handler) {
          // Log error for debugging
          debugPrint('API Error: ${error.message}');
          handler.next(error);
        },
      ),
    );

    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  // Public method to ensure token is loaded before checking auth state
  Future<void> initializeToken() async {
    await _loadToken();
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    _token = token;
  }

  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    _token = null;
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

  Future<AuthResponse> login(String email, String password) async {
    try {
      // Demo authentication for testing
      if (email == 'demo@demo.com' && password == 'password123') {
        const demoToken =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoxLCJ1c2VybmFtZSI6ImRlbW8iLCJleHAiOjE3NDA2ODQ0MDB9.demo_token';
        await _saveToken(demoToken);
        return AuthResponse(
          token: demoToken,
          message: 'Login successful',
        );
      }

      final response = await _dio.post(
        '/auth/login',
        data: AuthRequest(
          email: email,
          password: password,
        ).toJson(),
      );

      final authResponse = AuthResponse.fromJson(response.data);
      if (authResponse.token != null) {
        await _saveToken(authResponse.token!);
      }

      return authResponse;
    } on DioException catch (e) {
      // If it's a demo login failure, show helpful message
      if (email == 'demo@demo.com') {
        throw 'Demo login failed. Please check credentials.';
      }
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    await _clearToken();
  }

  // Event endpoints
  Future<List<EventResponse>> getEvents() async {
    try {
      final response = await _dio.get('/events');
      final List<dynamic> data = response.data;
      return data.map((json) => EventResponse.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> createEvent(String eventName,
      {String? eventDescription}) async {
    try {
      final response = await _dio.post(
        '/events/create',
        data: EventRequest(
          eventName: eventName,
          eventDescription: eventDescription ?? '',
        ).toJson(),
      );

      return response.data['event_uuid'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Channel endpoints
  Future<List<ChannelResponse>> getChannels() async {
    try {
      final response = await _dio.get('/channels');
      final List<dynamic> data = response.data;
      return data.map((json) => ChannelResponse.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<String> createChannel(String channelName, {String? eventUuid}) async {
    try {
      final response = await _dio.post(
        '/channels/create',
        data: ChannelRequest(
          channelName: channelName,
          eventUuid: eventUuid,
        ).toJson(),
      );

      return response.data['channel_uuid'];
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

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
