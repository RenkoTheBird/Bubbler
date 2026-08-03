import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../models/graph.dart';
import '../models/interaction.dart';
import '../models/post.dart';
import '../models/user.dart';

/// Profile, posts, interactions, likes, and account deletion.
class UserRepository {
  UserRepository(this._client);

  final ApiClient _client;

  /// Own profile (`GET /user/me/profile`).
  Future<User> getProfile() async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMeProfile,
    );
    return User.fromJson(_asJsonMap(data));
  }

  /// Public profile by username (`GET /user/{username}/profile`).
  Future<User> getUser(String username) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userProfile(username),
    );
    return User.fromJson(_asJsonMap(data));
  }

  /// Updates email (`PUT /user/me/profile/email`).
  Future<User> updateEmail(String email) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMeProfileEmail,
      method: 'PUT',
      data: {'email': email},
      contentType: 'application/json',
    );
    return User.fromJson(_asJsonMap(data));
  }

  /// Updates password (`PUT /user/me/profile/password`).
  Future<void> updatePassword({
    required String emailOrUsername,
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    await _client.authorizedRequest(
      path: Endpoints.userMeProfilePassword,
      method: 'PUT',
      data: {
        'email_or_username': emailOrUsername,
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_new_password': confirmNewPassword,
      },
      contentType: 'application/json',
    );
  }

  /// Own posts (`GET /user/me/posts`).
  Future<List<Post>> getMyPosts() async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMePosts,
    );
    return _decodePosts(data);
  }

  /// Public posts for [username] (`GET /user/{username}/posts`).
  Future<List<Post>> getUserPosts(String username) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userPosts(username),
    );
    return _decodePosts(data);
  }

  /// Recent interactions for the Bubble Trail (`GET /user/me`, capped at 20).
  Future<List<Interaction>> getMyInteractions() async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMe,
    );
    return _decodeInteractions(data);
  }

  /// All liked post IDs for the current user (`GET /user/me/likes`).
  Future<List<String>> getLikedPostIds() async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMeLikes,
    );
    if (data is! List) {
      throw const ApiInvalidResponse();
    }
    return data.map((e) => e as String).toList();
  }

  /// Records a graph interaction (`POST /user/me/interactions`).
  Future<void> recordInteraction(GraphInteractionPayload payload) async {
    await _client.authorizedRequest(
      path: Endpoints.userMeInteractions,
      method: 'POST',
      data: payload.toJson(),
      contentType: 'application/json',
    );
  }

  /// Removes a like (`DELETE /user/me/interactions/{postId}/like`).
  Future<void> deleteLike(String postId) async {
    await _client.authorizedRequest(
      path: Endpoints.userMeInteractionLike(postId),
      method: 'DELETE',
    );
  }

  /// Deletes the signed-in account (`DELETE /user/me`).
  Future<void> deleteAccount() async {
    await _client.authorizedRequest(
      path: Endpoints.userMe,
      method: 'DELETE',
    );
  }

  static List<Post> _decodePosts(dynamic data) {
    if (data is! List) {
      throw const ApiInvalidResponse();
    }
    return data
        .map((e) => Post.fromJson(_asJsonMap(e)))
        .toList();
  }

  static List<Interaction> _decodeInteractions(dynamic data) {
    if (data is! List) {
      throw const ApiInvalidResponse();
    }
    return data
        .map((e) => Interaction.fromJson(_asJsonMap(e)))
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
