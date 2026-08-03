/// Profile for the signed-in user or another account.
///
/// Unifies Swift `User` (has [email]) and `PublicUser` (has [isBlocked], no email)
/// into one shape with optional fields, per the Flutter file map.
class User {
  const User({
    required this.id,
    required this.username,
    required this.createdAt,
    this.email,
    this.isBlocked = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String?,
      createdAt: _parseDateTime(json['created_at'] as String),
      isBlocked: json['is_blocked'] as bool? ?? false,
    );
  }

  final int id;
  final String username;

  /// Present on `GET /user/me/profile` and email-update responses; absent on
  /// public profiles.
  final String? email;

  final DateTime createdAt;

  /// Present on public profile / block responses; defaults to `false` when
  /// omitted (matches Swift `PublicUser` decode).
  final bool isBlocked;

  /// Whether this payload includes the private [email] field.
  bool get isOwnProfile => email != null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      if (email != null) 'email': email,
      'created_at': createdAt.toUtc().toIso8601String(),
      'is_blocked': isBlocked,
    };
  }

  User copyWith({
    int? id,
    String? username,
    String? email,
    DateTime? createdAt,
    bool? isBlocked,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is User &&
        other.id == id &&
        other.username == username &&
        other.email == email &&
        other.createdAt == createdAt &&
        other.isBlocked == isBlocked;
  }

  @override
  int get hashCode => Object.hash(id, username, email, createdAt, isBlocked);

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email, '
        'createdAt: $createdAt, isBlocked: $isBlocked)';
  }
}

DateTime _parseDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid date: $value');
  }
  return parsed.toUtc();
}
