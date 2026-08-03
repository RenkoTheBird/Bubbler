import 'package:bubbler_app/core/api/api_client.dart';
import 'package:bubbler_app/core/auth/auth_session.dart';
import 'package:bubbler_app/core/auth/token_store.dart';
import 'package:bubbler_app/core/storage/liked_posts_store.dart';
import 'package:bubbler_app/data/models/graph.dart';
import 'package:bubbler_app/data/models/post.dart';
import 'package:bubbler_app/data/models/preferences.dart';
import 'package:bubbler_app/data/repositories/auth_repository.dart';
import 'package:bubbler_app/data/repositories/feed_repository.dart';
import 'package:bubbler_app/data/repositories/graph_repository.dart';
import 'package:bubbler_app/data/repositories/post_repository.dart';
import 'package:bubbler_app/data/repositories/preferences_repository.dart';
import 'package:bubbler_app/data/repositories/user_repository.dart';
import 'package:bubbler_app/features/graph/graph_feed_controller.dart';

Post graphTestPost({
  required String id,
  String topic = 'technology',
  String content = 'hello',
  int userId = 1,
}) {
  return Post(
    id: id,
    userId: userId,
    content: content,
    createdAt: DateTime.utc(2026, 1, 1),
    topic: topic,
    username: 'tester',
  );
}

UserPreferences graphTestPrefs({
  List<String> preferred = const [],
  List<String> blacklisted = const [],
}) {
  return UserPreferences.placeholder
      .updatePreferredTopics(preferred)
      .updateBlacklistedTopics(blacklisted)
      .sanitized();
}

class FakeFeedRepository extends FeedRepository {
  FakeFeedRepository() : super(ApiClient(accessTokenProvider: () => null));

  final List<GraphSessionFeed> sessions = [];
  final List<bool> diversifyFlags = [];
  Duration? responseDelay;

  @override
  Future<GraphSessionFeed> getSessionFeed({bool diversify = false}) async {
    diversifyFlags.add(diversify);
    final delay = responseDelay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    if (sessions.isEmpty) {
      throw StateError('No session fixtures left');
    }
    return sessions.removeAt(0);
  }
}

class FakeGraphRepository extends GraphRepository {
  FakeGraphRepository() : super(ApiClient(accessTokenProvider: () => null));

  final Map<String, List<Post>> neighbors = {};

  @override
  Future<List<Post>> getNextGraphPosts(String postId) async {
    return List<Post>.from(neighbors[postId] ?? const []);
  }
}

class FakePreferencesRepository extends PreferencesRepository {
  FakePreferencesRepository()
      : super(ApiClient(accessTokenProvider: () => null));

  UserPreferences current = UserPreferences.placeholder;

  @override
  Future<UserPreferences> getPreferences() async => current;

  @override
  Future<UserPreferences> updatePreferences(
    PreferencesUpdatePayload payload,
  ) async {
    current = UserPreferences(
      userId: current.userId,
      diversityTolerance: payload.diversityTolerance,
      randomness: payload.randomness,
      topicPreferences: payload.topicPreferences,
      useViewTime: payload.useViewTime,
      viewTimeWeight: payload.viewTimeWeight,
      useRecency: payload.useRecency,
      aiTopicDetection: payload.aiTopicDetection,
      strategyWeights: payload.strategyWeights,
    ).sanitized();
    return current;
  }
}

class FakeUserRepository extends UserRepository {
  FakeUserRepository() : super(ApiClient(accessTokenProvider: () => null));

  final List<GraphInteractionPayload> recorded = [];

  @override
  Future<List<String>> getLikedPostIds() async => const [];

  @override
  Future<void> recordInteraction(GraphInteractionPayload payload) async {
    recorded.add(payload);
  }
}

class FakePostRepository extends PostRepository {
  FakePostRepository() : super(ApiClient(accessTokenProvider: () => null));

  final List<String> deleted = [];

  @override
  Future<void> deletePost(String id) async {
    deleted.add(id);
  }
}

class GraphFeedTestHarness {
  GraphFeedTestHarness({DateTime? now})
      : now = now ?? DateTime.utc(2026, 6, 1, 12) {
    feed = FakeFeedRepository();
    graph = FakeGraphRepository();
    preferences = FakePreferencesRepository();
    users = FakeUserRepository();
    posts = FakePostRepository();
    auth = AuthSession(
      authRepository:
          AuthRepository(ApiClient(accessTokenProvider: () => null)),
      tokenStore: TokenStore(),
    );
    likedPosts = LikedPostsStore(users);
    controller = GraphFeedController(
      authSession: auth,
      feedRepository: feed,
      graphRepository: graph,
      preferencesRepository: preferences,
      userRepository: users,
      postRepository: posts,
      clock: () => this.now,
    );
  }

  late final FakeFeedRepository feed;
  late final FakeGraphRepository graph;
  late final FakePreferencesRepository preferences;
  late final FakeUserRepository users;
  late final FakePostRepository posts;
  late final AuthSession auth;
  late final LikedPostsStore likedPosts;
  late final GraphFeedController controller;
  DateTime now;

  void seedSession({
    required List<Post> posts,
    String seedStrategy = 'random',
    bool diversify = false,
  }) {
    feed.sessions.add(
      GraphSessionFeed(
        posts: posts,
        seedStrategy: seedStrategy,
        diversify: diversify,
      ),
    );
  }
}
