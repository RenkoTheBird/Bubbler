import 'package:bubbler_app/data/models/graph.dart';
import 'package:bubbler_app/data/models/topics.dart';

/// Mirrors backend `Interaction` from `GET /user/me` (bubble trail).
class Interaction {
  const Interaction({
    required this.id,
    required this.userId,
    required this.postId,
    required this.type,
    required this.createdAt,
    required this.topic,
    required this.viewTime,
    required this.liked,
  });

  factory Interaction.fromJson(Map<String, dynamic> json) {
    return Interaction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      postId: json['post_id'] as String,
      type: GraphInteractionType.fromJson(json['type'] as String),
      createdAt: _parseDateTime(json['created_at'] as String),
      topic: json['topic'] as String,
      viewTime: (json['view_time'] as num).toDouble(),
      liked: json['liked'] as bool,
    );
  }

  final String id;

  /// Backend serializes this as a string (not int).
  final String userId;
  final String postId;
  final GraphInteractionType type;
  final DateTime createdAt;
  final String topic;
  final double viewTime;
  final bool liked;

  /// Short copy for the profile Bubble Trail row.
  String get trailSummary {
    final trimmed = topic.trim();
    final topicLabel = trimmed.isEmpty
        ? 'a post'
        : 'a ${KnownTopics.displayName(trimmed)} post';

    switch (type) {
      case GraphInteractionType.like:
        return 'Liked $topicLabel';
      case GraphInteractionType.skip:
        return 'Skipped $topicLabel';
      case GraphInteractionType.explore:
        return 'Explored $topicLabel';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'post_id': postId,
      'type': type.toJson(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'topic': topic,
      'view_time': viewTime,
      'liked': liked,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Interaction &&
        other.id == id &&
        other.userId == userId &&
        other.postId == postId &&
        other.type == type &&
        other.createdAt == createdAt &&
        other.topic == topic &&
        other.viewTime == viewTime &&
        other.liked == liked;
  }

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        postId,
        type,
        createdAt,
        topic,
        viewTime,
        liked,
      );

  @override
  String toString() {
    return 'Interaction(id: $id, type: $type, postId: $postId, topic: $topic)';
  }
}

DateTime _parseDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid date: $value');
  }
  return parsed.toUtc();
}
