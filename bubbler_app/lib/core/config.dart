/// Runtime configuration for the Bubbler API client.
///
/// Mirrors `APIConfig` in the Swift `APIClient`.
abstract final class AppConfig {
  /// Local backend default used by the iOS client during development.
  static const String baseUrl = String.fromEnvironment(
    'BUBBLER_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
