import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../models/preferences.dart';

/// Get / update recommendation preferences.
class PreferencesRepository {
  PreferencesRepository(this._client);

  final ApiClient _client;

  /// Current preferences (`GET /user/me/preferences`).
  Future<UserPreferences> getPreferences() async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMePreferences,
    );
    return UserPreferences.fromJson(_asJsonMap(data));
  }

  /// Replaces preferences (`PUT /user/me/preferences`).
  ///
  /// Callers should normalize [payload.strategyWeights] the same way as iOS
  /// before sending.
  Future<UserPreferences> updatePreferences(
    PreferencesUpdatePayload payload,
  ) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMePreferences,
      method: 'PUT',
      data: payload.toJson(),
      contentType: 'application/json',
    );
    return UserPreferences.fromJson(_asJsonMap(data));
  }

  static Map<String, dynamic> _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const ApiInvalidResponse();
  }
}
