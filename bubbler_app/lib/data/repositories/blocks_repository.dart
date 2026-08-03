import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/endpoints.dart';
import '../models/blocked_user.dart';
import '../models/user.dart';

/// List / block / unblock users.
class BlocksRepository {
  BlocksRepository(this._client);

  final ApiClient _client;

  /// Blocked users for the signed-in account (`GET /user/me/blocks`).
  Future<List<BlockedUser>> getBlockedUsers() async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMeBlocks,
    );
    if (data is! List) {
      throw const ApiInvalidResponse();
    }
    return data
        .map((e) => BlockedUser.fromJson(_asJsonMap(e)))
        .toList();
  }

  /// Blocks [username] (`POST /user/me/blocks/{username}`).
  Future<User> blockUser(String username) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMeBlock(username),
      method: 'POST',
    );
    return User.fromJson(_asJsonMap(data));
  }

  /// Unblocks [username] (`DELETE /user/me/blocks/{username}`).
  Future<User> unblockUser(String username) async {
    final data = await _client.authorizedRequest(
      path: Endpoints.userMeBlock(username),
      method: 'DELETE',
    );
    return User.fromJson(_asJsonMap(data));
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
