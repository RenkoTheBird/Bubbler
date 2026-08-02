import '../../core/api/api_client.dart';
import '../../core/api/endpoints.dart';

/// Login / register response from `/auth/*` (Swift `AuthResponse`).
class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.tokenType,
    required this.userId,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      userId: json['user_id'] as int,
    );
  }

  final String accessToken;
  final String tokenType;
  final int userId;
}

/// Auth domain verbs formerly on Swift `APIClient` (`login` / `register`).
class AuthRepository {
  AuthRepository(this._client);

  final ApiClient _client;

  /// OAuth2 password form: field `username` is the account email.
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final json = await _client.postForm(
      Endpoints.authLogin,
      {
        'username': email,
        'password': password,
      },
    );
    return AuthResponse.fromJson(json);
  }

  /// Registers a user. [dateOfBirth] is encoded as a local calendar day
  /// (`YYYY-MM-DD`), not a UTC instant, matching the iOS client.
  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    required DateTime dateOfBirth,
  }) async {
    final json = await _client.postJson(
      Endpoints.authRegister,
      {
        'username': username,
        'email': email,
        'password': password,
        'date_of_birth': formatDateOfBirth(dateOfBirth),
      },
    );
    return AuthResponse.fromJson(json);
  }

  /// Local calendar day string — avoids DOB shifting across time zones.
  static String formatDateOfBirth(DateTime dateOfBirth) {
    final local = dateOfBirth.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
