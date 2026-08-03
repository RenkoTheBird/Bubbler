import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_session.dart';
import '../../data/models/post.dart';
import '../../data/models/topics.dart';
import '../../data/repositories/post_repository.dart';

/// Create / edit post form state — Swift `CreatePostViewModel`.
class CreatePostController extends ChangeNotifier {
  CreatePostController({
    required AuthSession authSession,
    required PostRepository postRepository,
    Post? post,
  })  : _authSession = authSession,
        _postRepository = postRepository,
        _editingPostId = post?.id,
        _content = post?.content ?? '',
        _selectedTopic = _initialTopic(post),
        _originalTopic = _initialOriginalTopic(post);

  final AuthSession _authSession;
  final PostRepository _postRepository;
  final String? _editingPostId;
  final String? _originalTopic;

  String _content;
  String _selectedTopic;
  bool _isSubmitting = false;
  String? _errorMessage;

  static String _initialTopic(Post? post) {
    final rawTopic = post?.topic?.trim();
    if (rawTopic == null || rawTopic.isEmpty) {
      return KnownTopics.defaultTopic;
    }
    return KnownTopics.resolve(rawTopic) ?? KnownTopics.defaultTopic;
  }

  static String? _initialOriginalTopic(Post? post) {
    if (post == null) return null;
    final rawTopic = post.topic?.trim();
    if (rawTopic == null || rawTopic.isEmpty) {
      return post.topic;
    }
    return KnownTopics.resolve(rawTopic) ?? post.topic;
  }

  String get content => _content;
  String get selectedTopic => _selectedTopic;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  bool get isEditing => _editingPostId != null;

  bool get canSubmit =>
      !_isSubmitting && _content.trim().isNotEmpty;

  @visibleForTesting
  String? get originalTopic => _originalTopic;

  @visibleForTesting
  String? get editingPostId => _editingPostId;

  void setContent(String value) {
    if (_content == value) return;
    _content = value;
    notifyListeners();
  }

  void setSelectedTopic(String topic) {
    if (_selectedTopic == topic) return;
    _selectedTopic = topic;
    notifyListeners();
  }

  /// Returns trimmed content on success, or `null` on validation/API failure.
  Future<String?> submit() async {
    final trimmedContent = _content.trim();
    if (trimmedContent.isEmpty) {
      _errorMessage = 'Write something before posting.';
      notifyListeners();
      return null;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final editingId = _editingPostId;
      if (editingId != null) {
        await _postRepository.updatePost(
          id: editingId,
          content: trimmedContent,
        );
        await _syncEditedTopic(editingId);
        _authSession.showSuccessMessage('Post updated!');
      } else {
        await _postRepository.createPost(
          content: trimmedContent,
          topic: _selectedTopic,
        );
        _authSession.showSuccessMessage('Post published!');
      }
      return trimmedContent;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Adds the newly chosen topic, then removes the previous one when it
  /// changed — Swift `syncEditedTopic`.
  Future<void> _syncEditedTopic(String postId) async {
    final original = _originalTopic;
    final topicChanged = original == null ||
        original.toLowerCase() != _selectedTopic.toLowerCase();

    if (!topicChanged) return;

    await _postRepository.addPostTopic(
      postId: postId,
      topic: _selectedTopic,
    );

    if (original != null &&
        original.toLowerCase() != _selectedTopic.toLowerCase()) {
      await _postRepository.removePostTopic(
        postId: postId,
        topic: original,
      );
    }
  }
}
