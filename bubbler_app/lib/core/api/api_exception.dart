/// Client-side API failures, mirroring Swift `APIClientError`.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Non-HTTP or otherwise unusable response.
final class ApiInvalidResponse extends ApiException {
  const ApiInvalidResponse()
      : super('Unexpected response from the server.');
}

/// HTTP 401, or a missing access token for an authenticated call.
final class ApiUnauthorized extends ApiException {
  const ApiUnauthorized()
      : super('Your session has expired. Please log in again.');
}

/// Non-success HTTP status with a parsed or fallback message.
final class ApiServerError extends ApiException {
  const ApiServerError({
    required this.statusCode,
    required String message,
  }) : super(message);

  final int statusCode;
}
