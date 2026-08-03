import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../models/post.dart';

/// Graph neighbor walks (`getNextGraphPosts`).
class GraphRepository {
  GraphRepository(this._client);

  final ApiClient _client;

  /// Next neighbor posts for [postId] (`GET /graph/posts/{id}/next`).
  Future<List<Post>> getNextGraphPosts(String postId) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.graphNext(postId),
    );
    return _decodePosts(data);
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
