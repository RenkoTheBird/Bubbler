import 'package:bubbler_app/data/models/post.dart';

/// Hybrid search payload from `GET /search?q=...`.
class SearchResponse {
  const SearchResponse({
    required this.query,
    required this.exactMatches,
    required this.related,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      query: json['query'] as String,
      exactMatches: (json['exact_matches'] as List<dynamic>? ?? const [])
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList(),
      related: (json['related'] as List<dynamic>? ?? const [])
          .map((e) => Post.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final String query;
  final List<Post> exactMatches;
  final List<Post> related;

  bool get isEmpty => exactMatches.isEmpty && related.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'query': query,
      'exact_matches': exactMatches.map((p) => p.toJson()).toList(),
      'related': related.map((p) => p.toJson()).toList(),
    };
  }
}
