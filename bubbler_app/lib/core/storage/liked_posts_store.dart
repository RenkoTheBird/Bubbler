import 'package:flutter/foundation.dart';

import '../../data/repositories/user_repository.dart';

/// Shared liked-post IDs so hearts stay consistent across Graph, Feed, and
/// Search. Mirrors Swift `LikedPostsStore`.
class LikedPostsStore extends ChangeNotifier {
  LikedPostsStore(this._userRepository);

  final UserRepository _userRepository;

  Set<String> _likedPostIds = {};

  Set<String> get likedPostIds => Set.unmodifiable(_likedPostIds);

  bool isLiked(String postId) => _likedPostIds.contains(postId);

  void setLiked(String postId, bool liked) {
    if (liked) {
      _likedPostIds = {..._likedPostIds, postId};
    } else {
      _likedPostIds = {..._likedPostIds}..remove(postId);
    }
    notifyListeners();
  }

  /// Reloads liked IDs from the server. Keeps the local set on failure.
  Future<void> refresh() async {
    try {
      final ids = await _userRepository.getLikedPostIds();
      _likedPostIds = ids.toSet();
      notifyListeners();
    } on Object {
      // Keep the local set if likes can't be loaded.
    }
  }

  void clear() {
    _likedPostIds = {};
    notifyListeners();
  }
}
