/// A post returned by feed, graph, search, and profile endpoints.
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.username,
    this.topic,
    this.embedding,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final rawEmbedding = json['embedding'];
    return Post(
      id: json['id'] as String,
      userId: json['user_id'] as int,
      username: json['username'] as String?,
      content: json['content'] as String,
      createdAt: _parseDateTime(json['created_at'] as String),
      topic: json['topic'] as String?,
      embedding: rawEmbedding == null
          ? null
          : (rawEmbedding as List<dynamic>)
              .map((e) => (e as num).toDouble())
              .toList(),
    );
  }

  final String id;
  final int userId;
  final String? username;
  final String content;
  final DateTime createdAt;
  final String? topic;
  final List<double>? embedding;

  /// Display label for the author (`@username` or `user #id`).
  String get authorLabel {
    final name = username;
    if (name != null && name.isNotEmpty) {
      return '@$name';
    }
    return 'user #$userId';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      if (username != null) 'username': username,
      'content': content,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (topic != null) 'topic': topic,
      if (embedding != null) 'embedding': embedding,
    };
  }

  Post copyWith({
    String? id,
    int? userId,
    String? username,
    String? content,
    DateTime? createdAt,
    String? topic,
    List<double>? embedding,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      topic: topic ?? this.topic,
      embedding: embedding ?? this.embedding,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Post &&
        other.id == id &&
        other.userId == userId &&
        other.username == username &&
        other.content == content &&
        other.createdAt == createdAt &&
        other.topic == topic;
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, username, content, createdAt, topic);

  @override
  String toString() {
    return 'Post(id: $id, userId: $userId, username: $username, '
        'topic: $topic, createdAt: $createdAt)';
  }
}

DateTime _parseDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid date: $value');
  }
  return parsed.toUtc();
}
