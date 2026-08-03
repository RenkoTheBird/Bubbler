import '../../data/models/graph.dart';
import '../../data/models/post.dart';
import '../../data/models/preferences.dart';
import '../../data/models/topics.dart';

/// Pure ranking / preference annotation helpers shared by
/// [GraphFeedController] — extracted from Swift `GraphFeedViewModel`.
abstract final class GraphFeedRanking {
  static String? normalizedTopicName(String? topic) {
    if (topic == null) return null;
    final normalized = TopicPreferenceList.normalizedTopic(topic);
    return normalized.isEmpty ? null : normalized;
  }

  static bool containsTopic(String? normalizedTopic, List<String> topics) {
    if (normalizedTopic == null) return false;
    final needle = normalizedTopic.toLowerCase();
    return topics.any((topic) => topic.toLowerCase() == needle);
  }

  static GraphFeedNode makeNode(Post post, UserPreferences preferences) {
    final normalizedTopic = normalizedTopicName(post.topic);
    return GraphFeedNode(
      post: post,
      isPreferredTopic:
          containsTopic(normalizedTopic, preferences.preferredTopics),
      isBlacklistedTopic:
          containsTopic(normalizedTopic, preferences.blacklistedTopics),
    );
  }

  static List<Post> uniqued(List<Post> posts) {
    final seen = <String>{};
    return posts.where((post) => seen.add(post.id)).toList();
  }

  /// Annotates posts, then promotes preferred-topic nodes while preserving
  /// relative order among equals (stable sort on original index).
  static List<GraphFeedNode> rankedNodes(
    List<Post> posts,
    UserPreferences preferences,
  ) {
    final nodes = uniqued(posts)
        .map((post) => makeNode(post, preferences))
        .toList();

    final indexed = [
      for (var i = 0; i < nodes.length; i++) (index: i, node: nodes[i]),
    ];

    indexed.sort((lhs, rhs) {
      if (lhs.node.isPreferredTopic != rhs.node.isPreferredTopic) {
        return lhs.node.isPreferredTopic ? -1 : 1;
      }
      return lhs.index.compareTo(rhs.index);
    });

    return [for (final entry in indexed) entry.node];
  }

  /// First usable session node plus remaining non-blacklisted queue entries.
  /// Returns `null` when the proposed current post is missing or blacklisted.
  static List<GraphFeedNode>? usableSessionNodes(List<GraphFeedNode> ranked) {
    if (ranked.isEmpty) return null;

    final proposedCurrent = ranked.first;
    if (proposedCurrent.isBlacklistedTopic) return null;

    final remaining = ranked
        .skip(1)
        .where((node) => !node.isBlacklistedTopic)
        .toList();

    return [proposedCurrent, ...remaining];
  }

  static String statusMessage({
    required GraphFeedNode node,
    required String? seedStrategyLabel,
    required String defaultMessage,
  }) {
    final parts = <String>[];

    if (node.isPreferredTopic) {
      final topicName = node.topicName;
      if (topicName != null) {
        parts.add('Preferred: $topicName');
      }
    }

    if (seedStrategyLabel != null) {
      parts.add(seedStrategyLabel);
    }

    if (parts.isEmpty) return defaultMessage;
    return parts.join(' · ');
  }
}
