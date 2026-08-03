/// A user the current account has blocked (`GET /user/me/blocks`).
class BlockedUser {
  const BlockedUser({
    required this.id,
    required this.username,
    required this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id'] as int,
      username: json['username'] as String,
      blockedAt: _parseDateTime(json['blocked_at'] as String),
    );
  }

  final int id;
  final String username;
  final DateTime blockedAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'blocked_at': blockedAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is BlockedUser &&
        other.id == id &&
        other.username == username &&
        other.blockedAt == blockedAt;
  }

  @override
  int get hashCode => Object.hash(id, username, blockedAt);

  @override
  String toString() {
    return 'BlockedUser(id: $id, username: $username, blockedAt: $blockedAt)';
  }
}

DateTime _parseDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid date: $value');
  }
  return parsed.toUtc();
}
