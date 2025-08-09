class AuthRequest {
  final String? username;
  final String email;
  final String password;

  AuthRequest({
    this.username,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      if (username != null) 'username': username,
      'email': email,
      'password': password,
    };
  }
}

class AuthResponse {
  final String? token;
  final String? message;

  AuthResponse({
    this.token,
    this.message,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'],
      message: json['message'],
    );
  }
}

class JWTClaims {
  final int userId;
  final String username;
  final int exp;

  JWTClaims({
    required this.userId,
    required this.username,
    required this.exp,
  });

  factory JWTClaims.fromJson(Map<String, dynamic> json) {
    return JWTClaims(
      userId: json['user_id'] ?? 0,
      username: json['username'] ?? '',
      exp: json['exp'] ?? 0,
    );
  }
}
