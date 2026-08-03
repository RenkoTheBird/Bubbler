import 'package:bubbler_app/data/models/topics.dart';

enum PreferenceType {
  preferred,
  blacklisted;

  static PreferenceType fromJson(String value) {
    return PreferenceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw FormatException('Unknown preference type: $value'),
    );
  }

  String toJson() => name;
}

class TopicPreference {
  const TopicPreference({
    required this.topic,
    required this.preferenceType,
  });

  factory TopicPreference.fromJson(Map<String, dynamic> json) {
    return TopicPreference(
      topic: json['topic'] as String,
      preferenceType:
          PreferenceType.fromJson(json['preference_type'] as String),
    );
  }

  final String topic;
  final PreferenceType preferenceType;

  Map<String, dynamic> toJson() {
    return {
      'topic': topic,
      'preference_type': preferenceType.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is TopicPreference &&
        other.topic == topic &&
        other.preferenceType == preferenceType;
  }

  @override
  int get hashCode => Object.hash(topic, preferenceType);
}

/// Feed composition weights (`similar` / `graph` / `opposite` / `random`).
class FeedStrategyWeights {
  const FeedStrategyWeights({
    required this.similar,
    required this.graph,
    required this.opposite,
    required this.random,
  });

  factory FeedStrategyWeights.fromJson(Map<String, dynamic> json) {
    double read(String key, double fallback) {
      final value = json[key];
      if (value is num) return value.toDouble();
      return fallback;
    }

    return FeedStrategyWeights(
      similar: read('similar', FeedStrategyWeights.defaults.similar),
      graph: read('graph', FeedStrategyWeights.defaults.graph),
      opposite: read('opposite', FeedStrategyWeights.defaults.opposite),
      random: read('random', FeedStrategyWeights.defaults.random),
    );
  }

  static const FeedStrategyWeights defaults = FeedStrategyWeights(
    similar: 0.4,
    graph: 0.25,
    opposite: 0.2,
    random: 0.15,
  );

  final double similar;
  final double graph;
  final double opposite;
  final double random;

  double get total => similar + graph + opposite + random;

  FeedStrategyWeights normalized() {
    final clamped = FeedStrategyWeights(
      similar: similar.clamp(0.0, 1.0),
      graph: graph.clamp(0.0, 1.0),
      opposite: opposite.clamp(0.0, 1.0),
      random: random.clamp(0.0, 1.0),
    );

    final sum = clamped.total;
    if (sum <= 0) return FeedStrategyWeights.defaults;

    return FeedStrategyWeights(
      similar: clamped.similar / sum,
      graph: clamped.graph / sum,
      opposite: clamped.opposite / sum,
      random: clamped.random / sum,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'similar': similar,
      'graph': graph,
      'opposite': opposite,
      'random': random,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is FeedStrategyWeights &&
        other.similar == similar &&
        other.graph == graph &&
        other.opposite == opposite &&
        other.random == random;
  }

  @override
  int get hashCode => Object.hash(similar, graph, opposite, random);
}

/// PUT body for preference updates (no `user_id`).
class PreferencesUpdatePayload {
  const PreferencesUpdatePayload({
    required this.diversityTolerance,
    required this.randomness,
    required this.topicPreferences,
    required this.useViewTime,
    required this.viewTimeWeight,
    required this.useRecency,
    required this.aiTopicDetection,
    required this.strategyWeights,
  });

  factory PreferencesUpdatePayload.fromJson(Map<String, dynamic> json) {
    return PreferencesUpdatePayload(
      diversityTolerance: (json['diversity_tolerance'] as num).toDouble(),
      randomness: (json['randomness'] as num).toDouble(),
      topicPreferences: (json['topic_preferences'] as List<dynamic>? ?? const [])
          .map((e) => TopicPreference.fromJson(e as Map<String, dynamic>))
          .toList(),
      useViewTime: json['use_view_time'] as bool? ?? false,
      viewTimeWeight: (json['view_time_weight'] as num?)?.toDouble() ?? 0.1,
      useRecency: json['use_recency'] as bool? ?? true,
      aiTopicDetection: json['ai_topic_detection'] as bool? ?? false,
      strategyWeights: FeedStrategyWeights.fromJson(
        Map<String, dynamic>.from(json['strategy_weights'] as Map? ?? const {}),
      ),
    );
  }

  final double diversityTolerance;
  final double randomness;
  final List<TopicPreference> topicPreferences;
  final bool useViewTime;
  final double viewTimeWeight;
  final bool useRecency;
  final bool aiTopicDetection;
  final FeedStrategyWeights strategyWeights;

  Map<String, dynamic> toJson() {
    return {
      'diversity_tolerance': diversityTolerance,
      'randomness': randomness,
      'topic_preferences': topicPreferences.map((t) => t.toJson()).toList(),
      'use_view_time': useViewTime,
      'view_time_weight': viewTimeWeight,
      'use_recency': useRecency,
      'ai_topic_detection': aiTopicDetection,
      'strategy_weights': strategyWeights.toJson(),
    };
  }
}

/// User recommendation preferences from `GET /user/me/preferences`.
class UserPreferences {
  const UserPreferences({
    required this.userId,
    required this.diversityTolerance,
    required this.randomness,
    required this.topicPreferences,
    required this.useViewTime,
    required this.viewTimeWeight,
    required this.useRecency,
    required this.aiTopicDetection,
    required this.strategyWeights,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userId: json['user_id'] as int,
      diversityTolerance: (json['diversity_tolerance'] as num).toDouble(),
      randomness: (json['randomness'] as num).toDouble(),
      topicPreferences: (json['topic_preferences'] as List<dynamic>? ?? const [])
          .map((e) => TopicPreference.fromJson(e as Map<String, dynamic>))
          .toList(),
      useViewTime: json['use_view_time'] as bool? ?? false,
      viewTimeWeight: (json['view_time_weight'] as num?)?.toDouble() ?? 0.1,
      useRecency: json['use_recency'] as bool? ?? true,
      aiTopicDetection: json['ai_topic_detection'] as bool? ?? false,
      strategyWeights: FeedStrategyWeights.fromJson(
        Map<String, dynamic>.from(json['strategy_weights'] as Map? ?? const {}),
      ),
    );
  }

  static const UserPreferences placeholder = UserPreferences(
    userId: 0,
    diversityTolerance: 0.4,
    randomness: 0.4,
    topicPreferences: [],
    useViewTime: false,
    viewTimeWeight: 0.1,
    useRecency: true,
    aiTopicDetection: false,
    strategyWeights: FeedStrategyWeights.defaults,
  );

  /// Built-in algorithm defaults (matches backend `default_user_prefs`).
  static UserPreferences systemDefaults({required int userId}) {
    return UserPreferences(
      userId: userId,
      diversityTolerance: 0.4,
      randomness: 0.4,
      topicPreferences: const [],
      useViewTime: false,
      viewTimeWeight: 0.1,
      useRecency: true,
      aiTopicDetection: false,
      strategyWeights: FeedStrategyWeights.defaults,
    );
  }

  final int userId;
  final double diversityTolerance;
  final double randomness;
  final List<TopicPreference> topicPreferences;
  final bool useViewTime;
  final double viewTimeWeight;
  final bool useRecency;
  final bool aiTopicDetection;
  final FeedStrategyWeights strategyWeights;

  List<String> get preferredTopics => topicPreferences
      .where((t) => t.preferenceType == PreferenceType.preferred)
      .map((t) => t.topic)
      .toList();

  List<String> get blacklistedTopics => topicPreferences
      .where((t) => t.preferenceType == PreferenceType.blacklisted)
      .map((t) => t.topic)
      .toList();

  PreferencesUpdatePayload get updatePayload => PreferencesUpdatePayload(
        diversityTolerance: diversityTolerance,
        randomness: randomness,
        topicPreferences: topicPreferences,
        useViewTime: useViewTime,
        viewTimeWeight: viewTimeWeight,
        useRecency: useRecency,
        aiTopicDetection: aiTopicDetection,
        strategyWeights: strategyWeights,
      );

  UserPreferences copyWith({
    int? userId,
    double? diversityTolerance,
    double? randomness,
    List<TopicPreference>? topicPreferences,
    bool? useViewTime,
    double? viewTimeWeight,
    bool? useRecency,
    bool? aiTopicDetection,
    FeedStrategyWeights? strategyWeights,
  }) {
    return UserPreferences(
      userId: userId ?? this.userId,
      diversityTolerance: diversityTolerance ?? this.diversityTolerance,
      randomness: randomness ?? this.randomness,
      topicPreferences: topicPreferences ?? this.topicPreferences,
      useViewTime: useViewTime ?? this.useViewTime,
      viewTimeWeight: viewTimeWeight ?? this.viewTimeWeight,
      useRecency: useRecency ?? this.useRecency,
      aiTopicDetection: aiTopicDetection ?? this.aiTopicDetection,
      strategyWeights: strategyWeights ?? this.strategyWeights,
    );
  }

  UserPreferences updatePreferredTopics(List<String> topics) {
    final preferred = TopicPreferenceList.cleaned(topics)
        .map((t) => TopicPreference(
              topic: t,
              preferenceType: PreferenceType.preferred,
            ))
        .toList();
    final preferredKeys = preferred.map((t) => t.topic.toLowerCase()).toSet();
    // Preferring a topic must clear any blacklist entry in the same update.
    final blacklisted = topicPreferences
        .where(
          (t) =>
              t.preferenceType == PreferenceType.blacklisted &&
              !preferredKeys.contains(t.topic.toLowerCase()),
        )
        .toList();
    return copyWith(
      topicPreferences: _mergeTopicPreferences(
        preferred: preferred,
        blacklisted: blacklisted,
      ),
    );
  }

  UserPreferences updateBlacklistedTopics(List<String> topics) {
    final blacklisted = TopicPreferenceList.cleaned(topics)
        .map((t) => TopicPreference(
              topic: t,
              preferenceType: PreferenceType.blacklisted,
            ))
        .toList();
    final blacklistedKeys =
        blacklisted.map((t) => t.topic.toLowerCase()).toSet();
    // Blacklisting a topic must clear any preferred entry in the same update.
    final preferred = topicPreferences
        .where(
          (t) =>
              t.preferenceType == PreferenceType.preferred &&
              !blacklistedKeys.contains(t.topic.toLowerCase()),
        )
        .toList();
    return copyWith(
      topicPreferences: _mergeTopicPreferences(
        preferred: preferred,
        blacklisted: blacklisted,
      ),
    );
  }

  UserPreferences preferTopic(String topic) {
    return updatePreferredTopics(
      TopicPreferenceList.add(topic, preferredTopics),
    ).updateBlacklistedTopics(
      TopicPreferenceList.remove(topic, blacklistedTopics),
    );
  }

  UserPreferences unpreferTopic(String topic) {
    return updatePreferredTopics(
      TopicPreferenceList.remove(topic, preferredTopics),
    );
  }

  UserPreferences blacklistTopic(String topic) {
    return updatePreferredTopics(
      TopicPreferenceList.remove(topic, preferredTopics),
    ).updateBlacklistedTopics(
      TopicPreferenceList.add(topic, blacklistedTopics),
    );
  }

  UserPreferences unblacklistTopic(String topic) {
    return updateBlacklistedTopics(
      TopicPreferenceList.remove(topic, blacklistedTopics),
    );
  }

  UserPreferences sanitized() {
    final preferred = TopicPreferenceList.cleaned(preferredTopics);
    final blacklist = TopicPreferenceList.cleaned(blacklistedTopics)
        .where(
          (blacklistedTopic) => !preferred.any(
            (p) => p.toLowerCase() == blacklistedTopic.toLowerCase(),
          ),
        )
        .toList();

    return UserPreferences(
      userId: userId,
      diversityTolerance: diversityTolerance.clamp(0.0, 1.0),
      randomness: randomness.clamp(0.0, 1.0),
      topicPreferences: _mergeTopicPreferences(
        preferred: preferred
            .map(
              (t) => TopicPreference(
                topic: t,
                preferenceType: PreferenceType.preferred,
              ),
            )
            .toList(),
        blacklisted: blacklist
            .map(
              (t) => TopicPreference(
                topic: t,
                preferenceType: PreferenceType.blacklisted,
              ),
            )
            .toList(),
      ),
      useViewTime: useViewTime,
      viewTimeWeight: viewTimeWeight.clamp(0.0, 1.0),
      useRecency: useRecency,
      aiTopicDetection: aiTopicDetection,
      strategyWeights: strategyWeights.normalized(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'diversity_tolerance': diversityTolerance,
      'randomness': randomness,
      'topic_preferences': topicPreferences.map((t) => t.toJson()).toList(),
      'use_view_time': useViewTime,
      'view_time_weight': viewTimeWeight,
      'use_recency': useRecency,
      'ai_topic_detection': aiTopicDetection,
      'strategy_weights': strategyWeights.toJson(),
    };
  }

  static List<TopicPreference> _mergeTopicPreferences({
    required List<TopicPreference> preferred,
    required List<TopicPreference> blacklisted,
  }) {
    final seen = <String>{};
    final merged = <TopicPreference>[];

    for (final pref in [...preferred, ...blacklisted]) {
      final key = pref.topic.toLowerCase();
      if (!seen.add(key)) continue;
      merged.add(pref);
    }

    merged.sort(
      (a, b) => a.topic.toLowerCase().compareTo(b.topic.toLowerCase()),
    );
    return merged;
  }

  @override
  bool operator ==(Object other) {
    if (other is! UserPreferences) return false;
    if (other.userId != userId ||
        other.diversityTolerance != diversityTolerance ||
        other.randomness != randomness ||
        other.useViewTime != useViewTime ||
        other.viewTimeWeight != viewTimeWeight ||
        other.useRecency != useRecency ||
        other.aiTopicDetection != aiTopicDetection ||
        other.strategyWeights != strategyWeights) {
      return false;
    }
    if (other.topicPreferences.length != topicPreferences.length) return false;
    for (var i = 0; i < topicPreferences.length; i++) {
      if (other.topicPreferences[i] != topicPreferences[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        userId,
        diversityTolerance,
        randomness,
        Object.hashAll(topicPreferences),
        useViewTime,
        viewTimeWeight,
        useRecency,
        aiTopicDetection,
        strategyWeights,
      );
}
