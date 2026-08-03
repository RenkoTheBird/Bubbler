import 'package:bubbler_app/core/api/api_client.dart';
import 'package:bubbler_app/core/api/api_exception.dart';
import 'package:bubbler_app/core/auth/auth_session.dart';
import 'package:bubbler_app/core/auth/token_store.dart';
import 'package:bubbler_app/data/models/post.dart';
import 'package:bubbler_app/data/models/topics.dart';
import 'package:bubbler_app/data/repositories/auth_repository.dart';
import 'package:bubbler_app/data/repositories/feed_repository.dart';
import 'package:bubbler_app/data/repositories/post_repository.dart';
import 'package:bubbler_app/features/feed/ranked_feed_controller.dart';
import 'package:bubbler_app/features/post/create_post_controller.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

Post _post({
  required String id,
  String topic = 'technology',
  String content = 'hello',
}) {
  return Post(
    id: id,
    userId: 1,
    content: content,
    createdAt: DateTime.utc(2026, 1, 1),
    topic: topic,
    username: 'tester',
  );
}

class FakeRankedFeedRepository extends FeedRepository {
  FakeRankedFeedRepository() : super(ApiClient(accessTokenProvider: () => null));

  List<Post> feed = const [];
  final List<String?> queries = [];
  Object? errorToThrow;

  @override
  Future<List<Post>> getFeed({String? query}) async {
    queries.add(query);
    final error = errorToThrow;
    if (error != null) throw error;
    return List<Post>.from(feed);
  }
}

class FakeCreatePostRepository extends PostRepository {
  FakeCreatePostRepository()
      : super(ApiClient(accessTokenProvider: () => null));

  final List<({String content, String topic})> created = [];
  final List<({String id, String content})> updated = [];
  final List<({String postId, String topic})> addedTopics = [];
  final List<({String postId, String topic})> removedTopics = [];
  Object? errorToThrow;

  @override
  Future<Post> createPost({
    required String content,
    required String topic,
  }) async {
    final error = errorToThrow;
    if (error != null) throw error;
    created.add((content: content, topic: topic));
    return _post(id: 'new', topic: topic, content: content);
  }

  @override
  Future<void> updatePost({
    required String id,
    required String content,
  }) async {
    final error = errorToThrow;
    if (error != null) throw error;
    updated.add((id: id, content: content));
  }

  @override
  Future<Post> addPostTopic({
    required String postId,
    required String topic,
  }) async {
    addedTopics.add((postId: postId, topic: topic));
    return _post(id: postId, topic: topic);
  }

  @override
  Future<Post> removePostTopic({
    required String postId,
    required String topic,
  }) async {
    removedTopics.add((postId: postId, topic: topic));
    return _post(id: postId, topic: 'general');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('RankedFeedController.prioritize', () {
    test('returns posts unchanged when topic is null', () {
      final posts = [
        _post(id: '1', topic: 'sports'),
        _post(id: '2', topic: 'technology'),
      ];
      expect(
        RankedFeedController.prioritize(posts: posts, topic: null),
        posts,
      );
    });

    test('keeps matching topic first while preserving relative order', () {
      final posts = [
        _post(id: '1', topic: 'sports'),
        _post(id: '2', topic: 'technology'),
        _post(id: '3', topic: 'sports'),
        _post(id: '4', topic: 'technology'),
      ];

      final ranked = RankedFeedController.prioritize(
        posts: posts,
        topic: 'technology',
      );

      expect(ranked.map((p) => p.id), ['2', '4', '1', '3']);
    });
  });

  group('RankedFeedController', () {
    late FakeRankedFeedRepository feed;
    late AuthSession auth;
    late RankedFeedController controller;

    setUp(() async {
      feed = FakeRankedFeedRepository();
      final tokenStore = TokenStore();
      auth = AuthSession(
        authRepository:
            AuthRepository(ApiClient(accessTokenProvider: () => null)),
        tokenStore: tokenStore,
      );
      await tokenStore.saveAccessToken('test-token');
      await auth.restore();
      controller = RankedFeedController(
        authSession: auth,
        feedRepository: feed,
      );
    });

    tearDown(() {
      controller.dispose();
      auth.dispose();
    });

    test('loadFeed stores prioritized posts', () async {
      feed.feed = [
        _post(id: 'a', topic: 'sports'),
        _post(id: 'b', topic: 'science'),
      ];

      await controller.selectTopic('science');

      expect(feed.queries, ['science']);
      expect(controller.posts.map((p) => p.id), ['b', 'a']);
      expect(controller.selectedTopic, 'science');
      expect(controller.errorMessage, isNull);
    });

    test('loadFeed signs out on unauthorized', () async {
      feed.errorToThrow = const ApiUnauthorized();
      await controller.loadFeed();
      expect(controller.posts, isEmpty);
      expect(controller.errorMessage, isNotNull);
      expect(auth.isSignedIn, isFalse);
    });

    test('removePost and updatePostContent mutate local list', () async {
      feed.feed = [_post(id: '1', content: 'one'), _post(id: '2')];
      await controller.loadFeed();

      controller.updatePostContent(id: '1', content: 'updated');
      expect(controller.posts.first.content, 'updated');

      controller.removePost('1');
      expect(controller.posts.map((p) => p.id), ['2']);
    });
  });

  group('CreatePostController', () {
    late FakeCreatePostRepository posts;
    late AuthSession auth;

    setUp(() {
      posts = FakeCreatePostRepository();
      auth = AuthSession(
        authRepository:
            AuthRepository(ApiClient(accessTokenProvider: () => null)),
        tokenStore: TokenStore(),
      );
    });

    tearDown(() {
      auth.dispose();
    });

    test('create requires non-empty content', () async {
      final controller = CreatePostController(
        authSession: auth,
        postRepository: posts,
      );
      addTearDown(controller.dispose);

      final result = await controller.submit();
      expect(result, isNull);
      expect(controller.errorMessage, 'Write something before posting.');
      expect(posts.created, isEmpty);
    });

    test('create posts content and topic', () async {
      final controller = CreatePostController(
        authSession: auth,
        postRepository: posts,
      );
      addTearDown(controller.dispose);

      controller.setContent('  Hello bubble  ');
      controller.setSelectedTopic('science');

      final result = await controller.submit();
      expect(result, 'Hello bubble');
      expect(posts.created, [(content: 'Hello bubble', topic: 'science')]);
      expect(auth.successMessage, 'Post published!');
    });

    test('edit updates content and syncs topic change', () async {
      final controller = CreatePostController(
        authSession: auth,
        postRepository: posts,
        post: _post(id: 'p1', topic: 'technology', content: 'old'),
      );
      addTearDown(controller.dispose);

      expect(controller.isEditing, isTrue);
      expect(controller.selectedTopic, 'technology');
      expect(controller.originalTopic, 'technology');

      controller.setContent('new body');
      controller.setSelectedTopic('science');

      final result = await controller.submit();
      expect(result, 'new body');
      expect(posts.updated, [(id: 'p1', content: 'new body')]);
      expect(posts.addedTopics, [(postId: 'p1', topic: 'science')]);
      expect(posts.removedTopics, [(postId: 'p1', topic: 'technology')]);
      expect(auth.successMessage, 'Post updated!');
    });

    test('edit skips topic sync when topic unchanged', () async {
      final controller = CreatePostController(
        authSession: auth,
        postRepository: posts,
        post: _post(id: 'p1', topic: KnownTopics.defaultTopic, content: 'old'),
      );
      addTearDown(controller.dispose);

      controller.setContent('new body');
      await controller.submit();

      expect(posts.addedTopics, isEmpty);
      expect(posts.removedTopics, isEmpty);
    });
  });
}
