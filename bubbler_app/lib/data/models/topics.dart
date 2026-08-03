/// Curated topic list — mirrors `backend/app/db/topics.py` `KNOWN_TOPICS`.
abstract final class KnownTopics {
  static const String defaultTopic = 'general';

  static const List<String> all = [
    defaultTopic,
    'politics',
    'technology',
    'science',
    'entertainment',
    'sports',
    'business',
    'health',
    'education',
    'environment',
  ];

  static String displayName(String topic) {
    if (topic.isEmpty) return topic;
    return topic[0].toUpperCase() + topic.substring(1);
  }

  /// Returns the canonical known topic for [value], or `null` if not in [all].
  static String? resolve(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final lower = trimmed.toLowerCase();
    for (final topic in all) {
      if (topic.toLowerCase() == lower) return topic;
    }
    return null;
  }

  /// Topics whose names contain [query] (case-insensitive), excluding
  /// already-selected ones.
  static List<String> matching(
    String query, {
    List<String> excluding = const [],
  }) {
    final trimmed = query.trim();
    final excluded = excluding.map((e) => e.toLowerCase()).toSet();
    final available =
        all.where((t) => !excluded.contains(t.toLowerCase())).toList();

    if (trimmed.isEmpty) return available;

    final needle = trimmed.toLowerCase();
    return available.where((t) => t.toLowerCase().contains(needle)).toList();
  }
}

/// Helpers for cleaning and mutating topic preference lists.
abstract final class TopicPreferenceList {
  static List<String> cleaned(List<String> topics) {
    final seen = <String>{};
    final result = <String>[];

    for (final raw in topics) {
      final topic = normalizedTopic(raw);
      if (topic.isEmpty) continue;
      if (!seen.add(topic.toLowerCase())) continue;
      result.add(topic);
    }

    result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return result;
  }

  static List<String> add(String rawTopic, List<String> topics) {
    final topic = KnownTopics.resolve(rawTopic);
    if (topic == null) return cleaned(topics);

    final updated = cleaned(topics);
    if (updated.any((t) => t.toLowerCase() == topic.toLowerCase())) {
      return updated;
    }
    updated.add(topic);
    return cleaned(updated);
  }

  static List<String> remove(String rawTopic, List<String> topics) {
    final topic = normalizedTopic(rawTopic);
    return cleaned(topics)
        .where((t) => t.toLowerCase() != topic.toLowerCase())
        .toList();
  }

  static String normalizedTopic(String value) {
    return value.trim().replaceAll(',', '');
  }
}
