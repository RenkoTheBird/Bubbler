import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../models/search.dart';

/// Hybrid search (`GET /search?q=...`).
class SearchRepository {
  SearchRepository(this._client);

  final ApiClient _client;

  /// Keyword/topic/username hits plus semantic related posts.
  Future<SearchResponse> search(String query) async {
    final trimmed = query.trim();
    final data = await _client.authorizedRequest(
      path: Endpoints.search,
      queryParameters: {'q': trimmed},
    );
    return SearchResponse.fromJson(_asJsonMap(data));
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
