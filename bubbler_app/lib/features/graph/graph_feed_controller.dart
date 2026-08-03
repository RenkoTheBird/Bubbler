import 'package:flutter/foundation.dart';

import '../../core/auth/auth_session.dart';
import '../../data/models/graph.dart';
import '../../data/models/preferences.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/graph_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'graph_feed_ranking.dart';
import 'graph_feed_walk.dart';

/// Graph walk state — Swift `GraphFeedViewModel`.
///
/// Owns session retries (≤3, force diversify after first failure), the session
/// queue fallback, skip/explore advancement, and view-time tracking.
class GraphFeedController extends ChangeNotifier {
  GraphFeedController({
    required AuthSession authSession,
    required FeedRepository feedRepository,
    required GraphRepository graphRepository,
    required PreferencesRepository preferencesRepository,
    required UserRepository userRepository,
    required PostRepository postRepository,
    DateTime Function()? clock,
  })  : _authSession = authSession,
        _postRepository = postRepository {
    _walk = GraphFeedWalk(
      feedRepository: feedRepository,
      graphRepository: graphRepository,
      preferencesRepository: preferencesRepository,
      userRepository: userRepository,
      onUnauthorized: () {
        authSession.signOut();
      },
      notify: notifyListeners,
      clock: clock,
    );
  }

  final AuthSession _authSession;
  final PostRepository _postRepository;
  late final GraphFeedWalk _walk;

  GraphFeedNode? get currentNode => _walk.currentNode;
  List<GraphFeedNode> get nextChoices => _walk.nextChoices;
  bool get isLoading => _walk.isLoading;
  bool get isSubmitting => _walk.isSubmitting;
  String? get seedStrategyLabel => _walk.seedStrategyLabel;
  String? get errorMessage => _walk.errorMessage;
  String? get statusMessage => _walk.statusMessage;

  bool get hasCurrentPost => currentNode != null;

  String get currentTopicName =>
      currentNode?.topicName ?? 'Topicless bubble';

  bool get hasCurrentTopic => currentNode?.topicName != null;

  bool get isCurrentTopicPreferred =>
      currentNode?.isPreferredTopic == true;

  bool get isCurrentTopicBlacklisted =>
      currentNode?.isBlacklistedTopic == true;

  /// Visible for tests — live preference snapshot used for flag refresh.
  @visibleForTesting
  UserPreferences get preferences => _walk.preferences;

  /// Visible for tests — remaining session fallback posts.
  @visibleForTesting
  List<GraphFeedNode> get sessionQueue =>
      List.unmodifiable(_walk.sessionQueue);

  Future<void> load() async {
    if (_walk.isLoading) return;
    await _walk.loadSession(
      diversify: false,
      message: 'Building your graph session.',
    );
  }

  Future<void> refreshSession() async {
    await _walk.loadSession(
      diversify: true,
      message: 'Exploring a fresh path across topics.',
    );
  }

  Future<void> choose(GraphFeedNode node) async {
    await _walk.advance(
      interactionType: GraphInteractionType.explore,
      explicitNextNode: node,
      fallbackMessage: 'Following a connected post.',
    );
  }

  Future<void> skipCurrentPost() async {
    await _walk.advance(
      interactionType: GraphInteractionType.skip,
      explicitNextNode: null,
      fallbackMessage: 'Skipping ahead to the next bubble.',
    );
  }

  Future<void> togglePreferCurrentTopic() async {
    final topic = currentNode?.topicName;
    if (topic == null) return;

    _walk.isSubmitting = true;
    _walk.errorMessage = null;
    notifyListeners();

    try {
      final normalized = GraphFeedRanking.normalizedTopicName(topic);
      var updated = _walk.preferences;
      if (GraphFeedRanking.containsTopic(
        normalized,
        updated.preferredTopics,
      )) {
        updated = updated.unpreferTopic(topic);
        _walk.statusMessage = 'Removed $topic from preferred topics.';
      } else {
        updated = updated.preferTopic(topic);
        _walk.statusMessage = 'Preferred topic: $topic.';
      }

      await _walk.persistPreferences(updated);
      _walk.refreshPreferenceFlags();
    } catch (error) {
      _walk.handle(
        error,
        fallbackMessage: "We couldn't update topic preferences.",
      );
    }

    _walk.isSubmitting = false;
    notifyListeners();
  }

  Future<void> toggleBlacklistCurrentTopic() async {
    final current = currentNode;
    final topic = current?.topicName;
    if (current == null || topic == null) return;

    _walk.isSubmitting = true;
    _walk.errorMessage = null;
    notifyListeners();

    try {
      final normalized = GraphFeedRanking.normalizedTopicName(topic);
      final wasBlacklisted = GraphFeedRanking.containsTopic(
        normalized,
        _walk.preferences.blacklistedTopics,
      );

      if (wasBlacklisted) {
        await _walk.persistPreferences(
          _walk.preferences.unblacklistTopic(topic),
        );
        _walk.refreshPreferenceFlags();
        _walk.statusMessage = 'Removed $topic from blacklist.';
      } else {
        await _walk.persistPreferences(
          _walk.preferences.blacklistTopic(topic),
        );
        _walk.nextChoices = const [];
        _walk.sessionQueue = [];

        await _walk.recordInteraction(current, GraphInteractionType.skip);

        await _walk.loadSession(
          diversify: true,
          message: 'Blacklisted $topic. Exploring other bubbles.',
        );
      }
    } catch (error) {
      _walk.handle(
        error,
        fallbackMessage: "We couldn't update topic preferences.",
      );
    }

    _walk.isSubmitting = false;
    notifyListeners();
  }

  void updateCurrentPostContent(String content) {
    final current = currentNode;
    if (current == null) return;
    _walk.currentNode = GraphFeedNode(
      post: current.post.copyWith(content: content),
      isPreferredTopic: current.isPreferredTopic,
      isBlacklistedTopic: current.isBlacklistedTopic,
    );
    notifyListeners();
  }

  /// Reloads preferences after [PostCard] owns the prefs update.
  Future<void> syncTopicPreferences() async {
    try {
      await _walk.reloadPreferences();
      _walk.refreshPreferenceFlags();

      final current = currentNode;
      if (current != null && current.isBlacklistedTopic) {
        _walk.nextChoices = const [];
        _walk.sessionQueue = [];
        await _walk.recordInteraction(current, GraphInteractionType.skip);
        await _walk.loadSession(
          diversify: true,
          message: 'Topic blacklisted. Exploring other bubbles.',
        );
      } else {
        notifyListeners();
      }
    } catch (error) {
      _walk.handle(
        error,
        fallbackMessage: "We couldn't refresh topic preferences.",
      );
      notifyListeners();
    }
  }

  Future<void> deleteCurrentPost() async {
    final current = currentNode;
    if (current == null) return;

    _walk.isSubmitting = true;
    _walk.errorMessage = null;
    notifyListeners();

    try {
      await _postRepository.deletePost(current.id);
      _authSession.showSuccessMessage('Post deleted.');
      await _walk.advanceAfterCurrentPostRemoved(
        successMessage: 'Deleted your post and moved ahead.',
      );
    } catch (error) {
      _walk.handle(
        error,
        fallbackMessage: "We couldn't delete that post.",
      );
    }

    _walk.isSubmitting = false;
    notifyListeners();
  }

  /// Called when [PostCard] already deleted the current post via the API.
  Future<void> handleCurrentPostDeleted() async {
    await _walk.advanceAfterCurrentPostRemoved(
      successMessage: 'Deleted your post and moved ahead.',
    );
    notifyListeners();
  }

  String viewTimeText({DateTime? at}) {
    final elapsedSeconds = _walk.viewTime(at: at).floor();
    return '${elapsedSeconds}s tracked';
  }

  @visibleForTesting
  double viewTime({DateTime? at}) => _walk.viewTime(at: at);
}
