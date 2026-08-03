import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../models/graph.dart';
import '../models/post.dart';

/// Ranked feed and graph session seed (`getFeed` / `getSessionFeed`).
class FeedRepository {
  FeedRepository(this._client);

  final ApiClient _client;

  /// Ranked feed. Optional [query] maps to `q` and seeds similar/opposite
  /// candidates.
  Future<List<Post>> getFeed({String? query}) async {
    final trimmed = query?.trim() ?? '';
    final data = await _client.authorizedRequest(
      path: Endpoints.feedMe,
      queryParameters: trimmed.isEmpty ? null : {'q': trimmed},
    );
    return _decodePosts(data);
  }

  /// Graph session seed queue (`GET /feed/me/session`).
  Future<GraphSessionFeed> getSessionFeed({bool diversify = false}) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.feedMeSession,
      queryParameters: diversify ? {'diversify': 'true'} : null,
    );
    return GraphSessionFeed.fromJson(_asJsonMap(data));
  }

  static List<Post> _decodePosts(dynamic data) {
    if (data is! List) {
      throw const ApiInvalidResponse();
    }
    return data
        .map((e) => Post.fromJson(_asJsonMap(e)))
        .toList();
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
