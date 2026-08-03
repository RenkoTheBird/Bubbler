import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_session.dart';
import '../../data/models/post.dart';
import '../../data/repositories/feed_repository.dart';

/// Ranked feed state — Swift `FeedViewModel`.
class RankedFeedController extends ChangeNotifier {
  RankedFeedController({
    required AuthSession authSession,
    required FeedRepository feedRepository,
  })  : _authSession = authSession,
        _feedRepository = feedRepository;

  final AuthSession _authSession;
  final FeedRepository _feedRepository;

  /// `null` means the mixed "All" feed; otherwise a KnownTopics value.
  String? _selectedTopic;
  List<Post> _posts = const [];
  String? _errorMessage;
  bool _isLoading = false;

  String? get selectedTopic => _selectedTopic;
  List<Post> get posts => List.unmodifiable(_posts);
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  Future<void> selectTopic(String? topic) async {
    final String? normalized;
    if (topic == null) {
      normalized = null;
    } else {
      final trimmed = topic.trim();
      normalized = trimmed.isEmpty ? null : trimmed.toLowerCase();
    }

    if (_selectedTopic == normalized && _posts.isNotEmpty) {
      return;
    }

    _selectedTopic = normalized;
    _posts = const [];
    notifyListeners();
    await loadFeed();
  }

  Future<void> loadFeed() async {
    if (_authSession.accessToken == null) {
      _posts = const [];
      _errorMessage = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _feedRepository.getFeed(query: _selectedTopic);
      _posts = prioritize(posts: fetched, topic: _selectedTopic);
    } on ApiUnauthorized catch (error) {
      _posts = const [];
      _errorMessage = error.message;
      await _authSession.signOut();
    } catch (error) {
      _posts = const [];
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void removePost(String id) {
    final next = _posts.where((post) => post.id != id).toList(growable: false);
    if (next.length == _posts.length) return;
    _posts = next;
    notifyListeners();
  }

  void updatePostContent({required String id, required String content}) {
    final index = _posts.indexWhere((post) => post.id == id);
    if (index < 0) return;
    _posts = [
      for (var i = 0; i < _posts.length; i++)
        if (i == index) _posts[i].copyWith(content: content) else _posts[i],
    ];
    notifyListeners();
  }

  /// Keeps same-topic posts first while preserving relative order within each
  /// group — Swift `FeedViewModel.prioritize`.
  @visibleForTesting
  static List<Post> prioritize({
    required List<Post> posts,
    required String? topic,
  }) {
    if (topic == null) return List<Post>.from(posts);

    final indexed = posts.asMap().entries.toList();
    indexed.sort((lhs, rhs) {
      final leftMatch = matchesTopic(lhs.value, topic);
      final rightMatch = matchesTopic(rhs.value, topic);
      if (leftMatch != rightMatch) {
        return leftMatch && !rightMatch ? -1 : 1;
      }
      return lhs.key.compareTo(rhs.key);
    });
    return indexed.map((e) => e.value).toList(growable: false);
  }

  @visibleForTesting
  static bool matchesTopic(Post post, String topic) {
    final postTopic = post.topic?.trim();
    if (postTopic == null || postTopic.isEmpty) return false;
    return postTopic.toLowerCase() == topic.toLowerCase();
  }
}
