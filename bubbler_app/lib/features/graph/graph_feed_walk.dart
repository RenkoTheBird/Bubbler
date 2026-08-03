import '../../core/api/api_exception.dart';
import '../../data/models/graph.dart';
import '../../data/models/preferences.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/graph_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/user_repository.dart';
import 'graph_feed_ranking.dart';

/// Mutable graph-walk state and async session/advance mechanics.
///
/// Owned by [GraphFeedController]; kept separate so the notifier stays a thin
/// UI-facing facade over the Swift `GraphFeedViewModel` rules.
class GraphFeedWalk {
  GraphFeedWalk({
    required FeedRepository feedRepository,
    required GraphRepository graphRepository,
    required PreferencesRepository preferencesRepository,
    required UserRepository userRepository,
    required void Function() onUnauthorized,
    required void Function() notify,
    DateTime Function()? clock,
  })  : _feedRepository = feedRepository,
        _graphRepository = graphRepository,
        _preferencesRepository = preferencesRepository,
        _userRepository = userRepository,
        _onUnauthorized = onUnauthorized,
        _notify = notify,
        _clock = clock ?? DateTime.now;

  final FeedRepository _feedRepository;
  final GraphRepository _graphRepository;
  final PreferencesRepository _preferencesRepository;
  final UserRepository _userRepository;
  final void Function() _onUnauthorized;
  final void Function() _notify;
  final DateTime Function() _clock;

  GraphFeedNode? currentNode;
  List<GraphFeedNode> nextChoices = const [];
  List<GraphFeedNode> sessionQueue = [];
  bool isLoading = false;
  bool isSubmitting = false;
  String? seedStrategyLabel;
  String? errorMessage;
  String? statusMessage;
  DateTime? currentPostStartedAt;
  UserPreferences preferences = UserPreferences.placeholder;

  double viewTime({DateTime? at}) {
    final started = currentPostStartedAt;
    if (started == null) return 0;
    final now = at ?? _clock();
    final seconds = now.difference(started).inMicroseconds / 1e6;
    return seconds < 0 ? 0 : seconds;
  }

  Future<void> reloadPreferences() async {
    preferences =
        (await _preferencesRepository.getPreferences()).sanitized();
  }

  Future<void> persistPreferences(UserPreferences updated) async {
    preferences = (await _preferencesRepository
            .updatePreferences(updated.sanitized().updatePayload))
        .sanitized();
  }

  Future<void> loadSession({
    required bool diversify,
    required String message,
  }) async {
    isLoading = true;
    errorMessage = null;
    statusMessage = message;
    _notify();

    try {
      await reloadPreferences();

      final sessionNodes =
          await fetchUsableSessionNodes(diversify: diversify);
      final firstNode = sessionNodes.first;

      sessionQueue = sessionNodes.skip(1).toList();
      await setCurrentNode(firstNode);

      if (errorMessage == null) {
        final seedNote =
            seedStrategyLabel != null ? ' $seedStrategyLabel.' : '';
        final nodeForStatus = currentNode ?? firstNode;
        statusMessage = GraphFeedRanking.statusMessage(
          node: nodeForStatus,
          seedStrategyLabel: seedStrategyLabel,
          defaultMessage: 'Session ready.$seedNote',
        );
      }
    } catch (error) {
      currentNode = null;
      nextChoices = const [];
      sessionQueue = [];
      seedStrategyLabel = null;
      handle(
        error,
        fallbackMessage: "We couldn't build a graph session right now.",
      );
    }

    isLoading = false;
    _notify();
  }

  Future<void> advance({
    required GraphInteractionType interactionType,
    required GraphFeedNode? explicitNextNode,
    required String fallbackMessage,
  }) async {
    final current = currentNode;
    if (current == null) {
      await loadSession(
        diversify: false,
        message: 'Building your graph session.',
      );
      return;
    }

    isSubmitting = true;
    errorMessage = null;
    _notify();

    try {
      await recordInteraction(current, interactionType);

      if (explicitNextNode != null) {
        await setCurrentNode(explicitNextNode);
        final nowCurrent = currentNode;
        if (errorMessage == null && nowCurrent != null) {
          statusMessage = GraphFeedRanking.statusMessage(
            node: nowCurrent,
            seedStrategyLabel: seedStrategyLabel,
            defaultMessage: fallbackMessage,
          );
        }
      } else {
        final nextNode = nextAutomaticNode(excluding: current.id);
        if (nextNode != null) {
          await setCurrentNode(nextNode);
          final nowCurrent = currentNode;
          if (errorMessage == null && nowCurrent != null) {
            statusMessage = GraphFeedRanking.statusMessage(
              node: nowCurrent,
              seedStrategyLabel: seedStrategyLabel,
              defaultMessage: fallbackMessage,
            );
          }
        } else {
          await loadSession(
            diversify: true,
            message: 'Loading a fresh cross-topic path.',
          );
        }
      }
    } catch (error) {
      handle(error, fallbackMessage: "We couldn't save that interaction.");
    }

    isSubmitting = false;
    _notify();
  }

  Future<void> advanceAfterCurrentPostRemoved({
    required String successMessage,
  }) async {
    final current = currentNode;
    if (current == null) return;

    nextChoices = nextChoices.where((node) => node.id != current.id).toList();
    sessionQueue.removeWhere((node) => node.id == current.id);

    final nextNode = nextAutomaticNode(excluding: current.id);
    if (nextNode != null) {
      await setCurrentNode(nextNode);
      if (errorMessage == null) {
        statusMessage = successMessage;
      }
    } else {
      await loadSession(
        diversify: true,
        message: 'Deleted your post. Exploring other bubbles.',
      );
    }
  }

  Future<void> setCurrentNode(GraphFeedNode node) async {
    // Re-annotate from live preferences so a stale preview can't carry old flags.
    final annotated = GraphFeedRanking.makeNode(node.post, preferences);
    if (annotated.isBlacklistedTopic) {
      await loadSession(
        diversify: true,
        message: 'That topic is blacklisted, so exploring other bubbles.',
      );
      return;
    }

    currentNode = annotated;
    currentPostStartedAt = _clock();

    try {
      nextChoices = await loadChoices(annotated);

      if (nextChoices.isEmpty && sessionQueue.isEmpty) {
        statusMessage =
            'No connected posts were available, so the next action will pull a fresh session.';
      }
    } catch (error) {
      nextChoices = const [];
      handle(
        error,
        fallbackMessage: "We couldn't load the connected posts.",
      );
    }
  }

  Future<List<GraphFeedNode>> fetchUsableSessionNodes({
    required bool diversify,
    int maxAttempts = 3,
  }) async {
    String? lastSeedLabel;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      // Escalate to diversify on retries so blacklist / empty pools can escape.
      final forceDiversify = diversify || attempt > 0;
      final session =
          await _feedRepository.getSessionFeed(diversify: forceDiversify);
      lastSeedLabel = session.statusLabel;
      seedStrategyLabel = session.statusLabel;

      final ranked = GraphFeedRanking.rankedNodes(session.posts, preferences);
      final usable = GraphFeedRanking.usableSessionNodes(ranked);
      if (usable != null) {
        return usable;
      }
    }

    seedStrategyLabel = lastSeedLabel;
    throw const GraphFeedError.noUsablePosts();
  }

  Future<List<GraphFeedNode>> loadChoices(GraphFeedNode node) async {
    final posts = await _graphRepository.getNextGraphPosts(node.id);
    return GraphFeedRanking.rankedNodes(posts, preferences)
        .where(
          (choice) => choice.id != node.id && !choice.isBlacklistedTopic,
        )
        .toList();
  }

  GraphFeedNode? nextAutomaticNode({required String excluding}) {
    final choiceIndex = nextChoices.indexWhere(
      (choice) => choice.id != excluding && !choice.isBlacklistedTopic,
    );
    if (choiceIndex >= 0) {
      final choice = nextChoices[choiceIndex];
      nextChoices = nextChoices
          .where(
            (node) => node.id != choice.id && !node.isBlacklistedTopic,
          )
          .toList();
      return choice;
    }

    nextChoices =
        nextChoices.where((node) => !node.isBlacklistedTopic).toList();

    while (sessionQueue.isNotEmpty) {
      final nextNode = sessionQueue.removeAt(0);
      if (nextNode.id != excluding && !nextNode.isBlacklistedTopic) {
        return nextNode;
      }
    }

    return null;
  }

  void refreshPreferenceFlags() {
    final current = currentNode;
    if (current != null) {
      currentNode = GraphFeedRanking.makeNode(current.post, preferences);
    }

    nextChoices = GraphFeedRanking.rankedNodes(
      nextChoices.map((node) => node.post).toList(),
      preferences,
    );
    sessionQueue = sessionQueue
        .map((node) => GraphFeedRanking.makeNode(node.post, preferences))
        .toList();
  }

  Future<void> recordInteraction(
    GraphFeedNode node,
    GraphInteractionType type,
  ) async {
    final payload = GraphInteractionPayload(
      postId: node.id,
      type: type,
      viewTime: viewTime(),
    );
    await _userRepository.recordInteraction(payload);
  }

  void handle(Object error, {required String fallbackMessage}) {
    if (error is ApiUnauthorized) {
      _onUnauthorized();
    }

    final description = switch (error) {
      ApiException(:final message) => message.trim(),
      GraphFeedError(:final message) => message.trim(),
      _ => error.toString().trim(),
    };
    errorMessage = description.isEmpty ? fallbackMessage : description;
  }
}

/// Session seed failed after retries / blacklist filtering.
final class GraphFeedError implements Exception {
  const GraphFeedError.noUsablePosts()
      : message = 'No session posts matched your current topic rules.';

  final String message;

  @override
  String toString() => message;
}
