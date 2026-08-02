import 'package:dio/dio.dart';

import '../config.dart';
import 'api_exception.dart';
import 'endpoints.dart';

/// Backend `/health` payload (formerly `BackendHealth` in Swift).
class BackendHealth {
  const BackendHealth({
    required this.status,
    required this.database,
  });

  factory BackendHealth.fromJson(Map<String, dynamic> json) {
    return BackendHealth(
      status: json['status'] as String,
      database: json['database'] as String,
    );
  }

  final String status;
  final String database;

  bool get isOk => status == 'ok';
}

/// Thin HTTP transport: headers, JSON/form bodies, error mapping, and health.
///
/// Domain verbs live in repositories; this class replaces the transport half of
/// Swift `APIClient` plus `BackendConnection`’s health check.
class ApiClient {
  ApiClient({
    Dio? dio,
    String? Function()? accessTokenProvider,
    String? baseUrl,
  })  : _accessTokenProvider = accessTokenProvider,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: _normalizeBaseUrl(baseUrl ?? AppConfig.baseUrl),
                connectTimeout: AppConfig.connectTimeout,
                receiveTimeout: AppConfig.receiveTimeout,
                headers: const {
                  Headers.acceptHeader: Headers.jsonContentType,
                },
              ),
            );

  final Dio _dio;
  final String? Function()? _accessTokenProvider;

  Dio get dio => _dio;

  /// `GET /health` — folded from Swift `BackendConnection` / `BackendClient`.
  Future<BackendHealth> health() async {
    final data = await _send(
      Endpoints.health,
      method: 'GET',
      // Health probes should fail fast relative to normal API calls.
      receiveTimeout: const Duration(seconds: 5),
    );
    final map = _asJsonMap(data);
    return BackendHealth.fromJson(map);
  }

  /// `application/x-www-form-urlencoded` POST (OAuth2 password login).
  Future<Map<String, dynamic>> postForm(
    String path,
    Map<String, dynamic> fields,
  ) async {
    final data = await _send(
      path,
      method: 'POST',
      data: fields,
      contentType: Headers.formUrlEncodedContentType,
    );
    return _asJsonMap(data);
  }

  /// JSON POST without a Bearer token.
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final data = await _send(
      path,
      method: 'POST',
      data: body,
      contentType: Headers.jsonContentType,
    );
    return _asJsonMap(data);
  }

  /// Authenticated request; throws [ApiUnauthorized] when no token is available.
  Future<dynamic> authorizedRequest({
    required String path,
    String method = 'GET',
    Object? data,
    Map<String, dynamic>? queryParameters,
    String? contentType,
  }) async {
    return _send(
      path,
      method: method,
      data: data,
      queryParameters: queryParameters,
      contentType: contentType,
      authenticated: true,
    );
  }

  Future<dynamic> _send(
    String path, {
    required String method,
    Object? data,
    Map<String, dynamic>? queryParameters,
    String? contentType,
    bool authenticated = false,
    Duration? receiveTimeout,
  }) async {
    final headers = <String, dynamic>{};

    if (authenticated) {
      final token = _accessTokenProvider?.call();
      if (token == null || token.isEmpty) {
        throw const ApiUnauthorized();
      }
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final response = await _dio.request<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers: headers,
          contentType: contentType,
          receiveTimeout: receiveTimeout,
          responseType: ResponseType.json,
        ),
      );
      return response.data;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  ApiException _mapDioException(DioException error) {
    final response = error.response;
    if (response == null) {
      return const ApiInvalidResponse();
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode == 401) {
      return const ApiUnauthorized();
    }

    final message = _extractDetail(response.data) ??
        'Request failed with status $statusCode.';
    return ApiServerError(statusCode: statusCode, message: message);
  }

  static String? _extractDetail(dynamic data) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is Map) {
        // e.g. health 503: {"status":"error","database":"unavailable"}
        final status = detail['status'];
        final database = detail['database'];
        if (status is String && database is String) {
          return '$status ($database)';
        }
        return detail.toString();
      }
      if (detail is List) {
        // FastAPI validation errors
        return detail.map((item) {
          if (item is Map && item['msg'] != null) {
            return item['msg'].toString();
          }
          return item.toString();
        }).join('; ');
      }
    }
    return null;
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

  static String _normalizeBaseUrl(String baseUrl) {
    if (baseUrl.endsWith('/')) {
      return baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }
}
