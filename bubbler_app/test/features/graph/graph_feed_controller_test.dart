import 'dart:convert';

import 'package:bubbler_app/core/api/api_client.dart';
import 'package:bubbler_app/core/api/api_exception.dart';
import 'package:bubbler_app/core/auth/auth_session.dart';
import 'package:bubbler_app/core/auth/token_store.dart';
import 'package:bubbler_app/data/models/graph.dart';
import 'package:bubbler_app/data/models/preferences.dart';
import 'package:bubbler_app/data/repositories/auth_repository.dart';
import 'package:bubbler_app/features/graph/graph_feed_controller.dart';
import 'package:bubbler_app/features/graph/graph_feed_ranking.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'graph_feed_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('GraphFeedRanking', () {
    test('promotes preferred topics while preserving relative order', () {
      final prefs = graphTestPrefs(preferred: ['science']);
      final ranked = GraphFeedRanking.rankedNodes(
        [
          graphTestPost(id: 'a', topic: 'technology'),
          graphTestPost(id: 'b', topic: 'science'),
          graphTestPost(id: 'c', topic: 'sports'),
          graphTestPost(id: 'd', topic: 'science'),
        ],
        prefs,
      );

      expect(ranked.map((n) => n.id), ['b', 'd', 'a', 'c']);
      expect(ranked[0].isPreferredTopic, isTrue);
      expect(ranked[1].isPreferredTopic, isTrue);
      expect(ranked[2].isPreferredTopic, isFalse);
    });

    test('dedupes posts by id before ranking', () {
      final ranked = GraphFeedRanking.rankedNodes(
        [
          graphTestPost(id: 'a', topic: 'technology'),
          graphTestPost(id: 'a', topic: 'science'),
          graphTestPost(id: 'b', topic: 'sports'),
        ],
        UserPreferences.placeholder,
      );
      expect(ranked.map((n) => n.id), ['a', 'b']);
      expect(ranked.first.topicName, 'technology');
    });

    test('usableSessionNodes rejects blacklisted current', () {
      final prefs = graphTestPrefs(blacklisted: ['politics']);
      final ranked = GraphFeedRanking.rankedNodes(
        [
          graphTestPost(id: '1', topic: 'politics'),
          graphTestPost(id: '2', topic: 'sports'),
        ],
        prefs,
      );
      expect(GraphFeedRanking.usableSessionNodes(ranked), isNull);
    });

    test('usableSessionNodes drops blacklisted queue entries', () {
      final prefs = graphTestPrefs(blacklisted: ['politics']);
      final ranked = GraphFeedRanking.rankedNodes(
        [
          graphTestPost(id: '1', topic: 'sports'),
          graphTestPost(id: '2', topic: 'politics'),
          graphTestPost(id: '3', topic: 'science'),
        ],
        prefs,
      );
      final usable = GraphFeedRanking.usableSessionNodes(ranked)!;
      expect(usable.map((n) => n.id), ['1', '3']);
    });

    test('statusMessage prefers topic and seed label over default', () {
      final node = GraphFeedRanking.makeNode(
        graphTestPost(id: '1', topic: 'science'),
        graphTestPrefs(preferred: ['science']),
      );
      expect(
        GraphFeedRanking.statusMessage(
          node: node,
          seedStrategyLabel: 'Seeded from recent interests',
          defaultMessage: 'Session ready.',
        ),
        'Preferred: science · Seeded from recent interests',
      );
    });
  });

  group('GraphFeedController', () {
    late GraphFeedTestHarness h;

    setUp(() {
      h = GraphFeedTestHarness();
    });

    test('load seeds current node and session queue', () async {
      h.seedSession(
        posts: [
          graphTestPost(id: 'c1', topic: 'technology'),
          graphTestPost(id: 'q1', topic: 'science'),
          graphTestPost(id: 'q2', topic: 'sports'),
        ],
        seedStrategy: 'soft_prior',
      );
      h.graph.neighbors['c1'] = [
        graphTestPost(id: 'n1', topic: 'business'),
        graphTestPost(id: 'n2', topic: 'health'),
      ];

      await h.controller.load();

      expect(h.controller.currentNode?.id, 'c1');
      expect(h.controller.sessionQueue.map((n) => n.id), ['q1', 'q2']);
      expect(h.controller.nextChoices.map((n) => n.id), ['n1', 'n2']);
      expect(h.feed.diversifyFlags, [false]);
      expect(h.controller.isLoading, isFalse);
    });

    test('retries session up to three times and forces diversify after first failure',
        () async {
      h.preferences.current = graphTestPrefs(blacklisted: ['politics']);
      h.feed.sessions.addAll([
        GraphSessionFeed(
          posts: [graphTestPost(id: 'bad', topic: 'politics')],
          seedStrategy: 'soft_prior',
          diversify: false,
        ),
        GraphSessionFeed(
          posts: [graphTestPost(id: 'still-bad', topic: 'politics')],
          seedStrategy: 'diversify',
          diversify: true,
        ),
        GraphSessionFeed(
          posts: [
            graphTestPost(id: 'ok', topic: 'science'),
            graphTestPost(id: 'queue', topic: 'sports'),
          ],
          seedStrategy: 'diversify',
          diversify: true,
        ),
      ]);
      h.graph.neighbors['ok'] = [];

      await h.controller.load();

      expect(h.feed.diversifyFlags, [false, true, true]);
      expect(h.controller.currentNode?.id, 'ok');
      expect(h.controller.sessionQueue.map((n) => n.id), ['queue']);
      expect(h.controller.errorMessage, isNull);
    });

    test('empty session posts count as a failed attempt and retry with diversify',
        () async {
      h.feed.sessions.addAll([
        GraphSessionFeed(
          posts: const [],
          seedStrategy: 'soft_prior',
          diversify: false,
        ),
        GraphSessionFeed(
          posts: [graphTestPost(id: 'ok', topic: 'science')],
          seedStrategy: 'diversify',
          diversify: true,
        ),
      ]);
      h.graph.neighbors['ok'] = [];

      await h.controller.load();

      expect(h.feed.diversifyFlags, [false, true]);
      expect(h.controller.currentNode?.id, 'ok');
    });

    test('exhausted retries surface noUsablePosts', () async {
      h.preferences.current = graphTestPrefs(blacklisted: ['politics']);
      h.feed.sessions.addAll([
        for (var i = 0; i < 3; i++)
          GraphSessionFeed(
            posts: [graphTestPost(id: 'bad-$i', topic: 'politics')],
            seedStrategy: 'diversify',
            diversify: true,
          ),
      ]);

      await h.controller.load();

      expect(h.feed.diversifyFlags, [false, true, true]);
      expect(h.controller.currentNode, isNull);
      expect(
        h.controller.errorMessage,
        'No session posts matched your current topic rules.',
      );
    });

    test('skip consumes next choice then session queue', () async {
      h.seedSession(
        posts: [
          graphTestPost(id: 'c1'),
          graphTestPost(id: 'q1', topic: 'science'),
        ],
      );
      h.graph.neighbors['c1'] = [graphTestPost(id: 'n1', topic: 'sports')];
      h.graph.neighbors['n1'] = [];
      h.graph.neighbors['q1'] = [];

      await h.controller.load();
      await h.controller.skipCurrentPost();

      expect(h.users.recorded.map((p) => p.postId), ['c1']);
      expect(h.users.recorded.single.type, GraphInteractionType.skip);
      expect(h.controller.currentNode?.id, 'n1');
      expect(h.controller.nextChoices, isEmpty);
      expect(h.controller.sessionQueue.map((n) => n.id), ['q1']);

      await h.controller.skipCurrentPost();

      expect(h.controller.currentNode?.id, 'q1');
      expect(h.controller.sessionQueue, isEmpty);
      expect(h.users.recorded.map((p) => p.type), [
        GraphInteractionType.skip,
        GraphInteractionType.skip,
      ]);
    });

    test('skip with empty neighbors and empty queue starts diversified session',
        () async {
      h.seedSession(posts: [graphTestPost(id: 'c1')]);
      h.seedSession(
        posts: [graphTestPost(id: 'fresh', topic: 'health')],
        seedStrategy: 'diversify',
        diversify: true,
      );
      h.graph.neighbors['c1'] = [];
      h.graph.neighbors['fresh'] = [];

      await h.controller.load();
      await h.controller.skipCurrentPost();

      expect(h.feed.diversifyFlags, [false, true]);
      expect(h.controller.currentNode?.id, 'fresh');
    });

    test('choose records explore and advances to selected neighbor', () async {
      h.seedSession(posts: [graphTestPost(id: 'c1')]);
      final neighbor = graphTestPost(id: 'picked', topic: 'science');
      h.graph.neighbors['c1'] = [neighbor, graphTestPost(id: 'other')];
      h.graph.neighbors['picked'] = [];

      await h.controller.load();
      final choice =
          h.controller.nextChoices.firstWhere((n) => n.id == 'picked');
      await h.controller.choose(choice);

      expect(h.users.recorded.single.type, GraphInteractionType.explore);
      expect(h.controller.currentNode?.id, 'picked');
    });

    test('next choices filter self and blacklisted topics', () async {
      h.preferences.current = graphTestPrefs(blacklisted: ['politics']);
      h.seedSession(posts: [graphTestPost(id: 'c1', topic: 'science')]);
      h.graph.neighbors['c1'] = [
        graphTestPost(id: 'c1', topic: 'science'),
        graphTestPost(id: 'bad', topic: 'politics'),
        graphTestPost(id: 'ok', topic: 'sports'),
      ];

      await h.controller.load();

      expect(h.controller.nextChoices.map((n) => n.id), ['ok']);
    });

    test('preferred neighbors are promoted in nextChoices', () async {
      h.preferences.current = graphTestPrefs(preferred: ['science']);
      h.seedSession(posts: [graphTestPost(id: 'c1')]);
      h.graph.neighbors['c1'] = [
        graphTestPost(id: 'a', topic: 'sports'),
        graphTestPost(id: 'b', topic: 'science'),
        graphTestPost(id: 'c', topic: 'health'),
      ];

      await h.controller.load();

      expect(h.controller.nextChoices.map((n) => n.id), ['b', 'a', 'c']);
      expect(h.controller.nextChoices.first.isPreferredTopic, isTrue);
    });

    test('tracks view time from currentPostStartedAt', () async {
      h.seedSession(posts: [graphTestPost(id: 'c1')]);
      h.seedSession(
        posts: [graphTestPost(id: 'fresh', topic: 'health')],
        seedStrategy: 'diversify',
        diversify: true,
      );
      h.graph.neighbors['c1'] = [];
      h.graph.neighbors['fresh'] = [];

      await h.controller.load();
      h.now = h.now.add(const Duration(seconds: 4, milliseconds: 200));

      expect(h.controller.viewTime(), closeTo(4.2, 1e-6));
      expect(h.controller.viewTimeText(), '4s tracked');

      await h.controller.skipCurrentPost();
      expect(h.users.recorded, isNotEmpty);
      expect(h.users.recorded.first.viewTime, closeTo(4.2, 1e-6));
      expect(h.users.recorded.first.type, GraphInteractionType.skip);
    });

    test('refreshSession requests diversify', () async {
      h.seedSession(posts: [graphTestPost(id: 'c1')]);
      h.seedSession(
        posts: [graphTestPost(id: 'c2', topic: 'science')],
        seedStrategy: 'diversify',
        diversify: true,
      );
      h.graph.neighbors['c1'] = [];
      h.graph.neighbors['c2'] = [];

      await h.controller.load();
      await h.controller.refreshSession();

      expect(h.feed.diversifyFlags, [false, true]);
      expect(h.controller.currentNode?.id, 'c2');
    });

    test('blacklist current topic records skip and diversifies', () async {
      h.seedSession(posts: [graphTestPost(id: 'c1', topic: 'technology')]);
      h.seedSession(
        posts: [graphTestPost(id: 'fresh', topic: 'science')],
        seedStrategy: 'diversify',
        diversify: true,
      );
      h.graph.neighbors['c1'] = [graphTestPost(id: 'n1')];
      h.graph.neighbors['fresh'] = [];

      await h.controller.load();
      await h.controller.toggleBlacklistCurrentTopic();

      expect(h.users.recorded.single.type, GraphInteractionType.skip);
      expect(h.feed.diversifyFlags, [false, true]);
      expect(h.controller.currentNode?.id, 'fresh');
      expect(
        h.preferences.current.blacklistedTopics,
        contains('technology'),
      );
    });

    test('syncTopicPreferences diversifies when current becomes blacklisted',
        () async {
      h.seedSession(posts: [graphTestPost(id: 'c1', topic: 'technology')]);
      h.seedSession(
        posts: [graphTestPost(id: 'fresh', topic: 'science')],
        seedStrategy: 'diversify',
        diversify: true,
      );
      h.graph.neighbors['c1'] = [];
      h.graph.neighbors['fresh'] = [];

      await h.controller.load();
      h.preferences.current =
          graphTestPrefs(blacklisted: ['technology']);

      await h.controller.syncTopicPreferences();

      expect(h.users.recorded.single.type, GraphInteractionType.skip);
      expect(h.feed.diversifyFlags, [false, true]);
      expect(h.controller.currentNode?.id, 'fresh');
    });

    test('handleCurrentPostDeleted advances to next choice', () async {
      h.seedSession(posts: [graphTestPost(id: 'c1')]);
      h.graph.neighbors['c1'] = [graphTestPost(id: 'n1', topic: 'sports')];
      h.graph.neighbors['n1'] = [];

      await h.controller.load();
      await h.controller.handleCurrentPostDeleted();

      expect(h.controller.currentNode?.id, 'n1');
      expect(
        h.controller.statusMessage,
        'Deleted your post and moved ahead.',
      );
    });

    test('handleCurrentPostDeleted diversifies when nothing remains', () async {
      h.seedSession(posts: [graphTestPost(id: 'c1')]);
      h.seedSession(
        posts: [graphTestPost(id: 'fresh', topic: 'health')],
        seedStrategy: 'diversify',
        diversify: true,
      );
      h.graph.neighbors['c1'] = [];
      h.graph.neighbors['fresh'] = [];

      await h.controller.load();
      await h.controller.handleCurrentPostDeleted();

      expect(h.feed.diversifyFlags, [false, true]);
      expect(h.controller.currentNode?.id, 'fresh');
    });

    test('deleteCurrentPost calls API then advances', () async {
      h.seedSession(posts: [graphTestPost(id: 'c1', userId: 1)]);
      h.graph.neighbors['c1'] = [graphTestPost(id: 'n1')];
      h.graph.neighbors['n1'] = [];

      await h.controller.load();
      await h.controller.deleteCurrentPost();

      expect(h.posts.deleted, ['c1']);
      expect(h.controller.currentNode?.id, 'n1');
      expect(h.auth.successMessage, 'Post deleted.');
    });

    test('updateCurrentPostContent mutates the sticky card post', () async {
      h.seedSession(
        posts: [graphTestPost(id: 'c1', content: 'old')],
      );
      h.graph.neighbors['c1'] = [];

      await h.controller.load();
      h.controller.updateCurrentPostContent('edited');

      expect(h.controller.currentNode?.content, 'edited');
      expect(h.controller.currentNode?.id, 'c1');
    });

    test('togglePreferCurrentTopic updates flags without leaving the node',
        () async {
      h.seedSession(posts: [graphTestPost(id: 'c1', topic: 'science')]);
      h.graph.neighbors['c1'] = [];

      await h.controller.load();
      expect(h.controller.isCurrentTopicPreferred, isFalse);

      await h.controller.togglePreferCurrentTopic();

      expect(h.controller.isCurrentTopicPreferred, isTrue);
      expect(h.controller.currentNode?.id, 'c1');
      expect(h.controller.statusMessage, 'Preferred topic: science.');

      await h.controller.togglePreferCurrentTopic();
      expect(h.controller.isCurrentTopicPreferred, isFalse);
    });

    test('choosing a blacklisted preview node diversifies instead', () async {
      h.seedSession(posts: [graphTestPost(id: 'c1')]);
      h.seedSession(
        posts: [graphTestPost(id: 'fresh', topic: 'health')],
        seedStrategy: 'diversify',
        diversify: true,
      );
      final neighbor = graphTestPost(id: 'later-bad', topic: 'politics');
      h.graph.neighbors['c1'] = [neighbor];
      h.graph.neighbors['fresh'] = [];

      await h.controller.load();
      final choice = h.controller.nextChoices.single;

      // Preferences changed under us (e.g. PostCard blacklist) while a stale
      // preview node is still held — setCurrentNode re-annotates from live prefs.
      h.preferences.current = graphTestPrefs(blacklisted: ['politics']);
      await h.controller.syncTopicPreferences();
      await h.controller.choose(choice);

      expect(h.feed.diversifyFlags, [false, true]);
      expect(h.controller.currentNode?.id, 'fresh');
    });

    test('unauthorized while loading signs out', () async {
      final tokenStore = TokenStore();
      await tokenStore.saveAccessToken(_fakeJwt(sub: '7'));
      final auth = AuthSession(
        authRepository:
            AuthRepository(ApiClient(accessTokenProvider: () => null)),
        tokenStore: tokenStore,
      );
      await auth.restore();
      expect(auth.isSignedIn, isTrue);

      final prefs = FakePreferencesRepository();
      final controller = GraphFeedController(
        authSession: auth,
        feedRepository: _UnauthorizedFeedRepository(),
        graphRepository: FakeGraphRepository(),
        preferencesRepository: prefs,
        userRepository: FakeUserRepository(),
        postRepository: FakePostRepository(),
      );

      await controller.load();

      expect(auth.isSignedIn, isFalse);
      expect(controller.errorMessage, const ApiUnauthorized().message);
      expect(controller.currentNode, isNull);
    });
  });
}

String _fakeJwt({required String sub}) {
  String encode(Map<String, Object?> json) {
    final bytes = utf8.encode(jsonEncode(json));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  return '${encode(const {})}.${encode({'sub': sub})}.sig';
}

class _UnauthorizedFeedRepository extends FakeFeedRepository {
  @override
  Future<GraphSessionFeed> getSessionFeed({bool diversify = false}) async {
    throw const ApiUnauthorized();
  }
}
