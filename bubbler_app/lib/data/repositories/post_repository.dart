import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../models/post.dart';

/// Create / update / delete posts and topic mutations.
class PostRepository {
  PostRepository(this._client);

  final ApiClient _client;

  /// Creates a post for the signed-in user (`POST /user/me/posts`).
  Future<Post> createPost({
    required String content,
    required String topic,
  }) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMePosts,
      method: 'POST',
      data: {
        'post': content,
        'topic': topic,
      },
      contentType: 'application/json',
    );
    return Post.fromJson(_asJsonMap(data));
  }

  /// Updates post body (`PUT /user/me/posts/{id}`).
  Future<void> updatePost({
    required String id,
    required String content,
  }) async {
    await _client.authorizedRequest(
      path: Endpoints.userMePost(id),
      method: 'PUT',
      data: {'post': content},
      contentType: 'application/json',
    );
  }

  /// Deletes a post (`DELETE /user/me/posts/{id}`).
  Future<void> deletePost(String id) async {
    await _client.authorizedRequest(
      path: Endpoints.userMePost(id),
      method: 'DELETE',
    );
  }

  /// Adds a topic tag (`POST /user/me/posts/{id}/topics`).
  Future<Post> addPostTopic({
    required String postId,
    required String topic,
  }) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMePostTopics(postId),
      method: 'POST',
      data: {'topic': topic},
      contentType: 'application/json',
    );
    return Post.fromJson(_asJsonMap(data));
  }

  /// Removes a topic tag (`DELETE /user/me/posts/{id}/topics/{topic}`).
  Future<Post> removePostTopic({
    required String postId,
    required String topic,
  }) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMePostTopic(postId, topic),
      method: 'DELETE',
    );
    return Post.fromJson(_asJsonMap(data));
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
