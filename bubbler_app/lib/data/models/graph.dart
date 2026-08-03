import 'package:bubbler_app/data/models/post.dart';

/// Client-side graph bubble wrapping a [Post] with preference flags.
class GraphFeedNode {
  const GraphFeedNode({
    required this.post,
    this.isPreferredTopic = false,
    this.isBlacklistedTopic = false,
  });

  final Post post;
  final bool isPreferredTopic;
  final bool isBlacklistedTopic;

  String get id => post.id;
  String get content => post.content;
  int get userId => post.userId;
  DateTime get createdAt => post.createdAt;

  String? get topicName {
    final topic = post.topic?.trim();
    if (topic == null || topic.isEmpty) return null;
    return topic;
  }

  GraphFeedNode copyWith({
    Post? post,
    bool? isPreferredTopic,
    bool? isBlacklistedTopic,
  }) {
    return GraphFeedNode(
      post: post ?? this.post,
      isPreferredTopic: isPreferredTopic ?? this.isPreferredTopic,
      isBlacklistedTopic: isBlacklistedTopic ?? this.isBlacklistedTopic,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GraphFeedNode &&
        other.post == post &&
        other.isPreferredTopic == isPreferredTopic &&
        other.isBlacklistedTopic == isBlacklistedTopic;
  }

  @override
  int get hashCode =>
      Object.hash(post, isPreferredTopic, isBlacklistedTopic);
}

/// Session seed payload from `GET /feed/me/session`.
class GraphSessionFeed {
  const GraphSessionFeed({
    required this.posts,
    required this.seedStrategy,
    required this.diversify,
  });

  factory GraphSessionFeed.fromJson(Map<String, dynamic> json) {
    return GraphSessionFeed(
      posts: (json['posts'] as List<dynamic>)
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList(),
      seedStrategy: json['seed_strategy'] as String,
      diversify: json['diversify'] as bool,
    );
  }

  final List<Post> posts;
  final String seedStrategy;
  final bool diversify;

  String get statusLabel {
    switch (seedStrategy) {
      case 'diversify':
      case 'diversify_fallback':
        return 'Exploring across topics';
      case 'soft_prior':
      case 'soft_prior_fallback':
        return 'Seeded from recent interests';
      case 'random':
        return 'Random topic mix';
      default:
        return 'Graph session ready';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'posts': posts.map((p) => p.toJson()).toList(),
      'seed_strategy': seedStrategy,
      'diversify': diversify,
    };
  }
}

/// Interaction kinds accepted by the graph / interaction APIs.
enum GraphInteractionType {
  like,
  skip,
  explore;

  static GraphInteractionType fromJson(String value) {
    return GraphInteractionType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('Unknown interaction type: $value'),
    );
  }

  String toJson() => name;
}

/// Body for recording a graph interaction (`POST /graph/interactions`).
class GraphInteractionPayload {
  const GraphInteractionPayload({
    required this.postId,
    required this.type,
    required this.viewTime,
  });

  factory GraphInteractionPayload.fromJson(Map<String, dynamic> json) {
    return GraphInteractionPayload(
      postId: json['post_id'] as String,
      type: GraphInteractionType.fromJson(json['type'] as String),
      viewTime: (json['view_time'] as num).toDouble(),
    );
  }

  final String postId;
  final GraphInteractionType type;
  final double viewTime;

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId,
      'type': type.toJson(),
      'view_time': viewTime,
    };
  }
}
