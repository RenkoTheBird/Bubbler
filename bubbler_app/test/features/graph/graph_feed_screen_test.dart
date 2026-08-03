import 'package:bubbler_app/data/models/graph.dart';
import 'package:bubbler_app/features/graph/graph_feed_screen.dart';
import 'package:bubbler_app/features/graph/widgets/bubble_field.dart';
import 'package:bubbler_app/features/graph/widgets/neighbor_bubble.dart';
import 'package:bubbler_app/shared/widgets/async_body.dart';
import 'package:bubbler_app/shared/widgets/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'graph_feed_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Future<void> pumpGraph(
    WidgetTester tester,
    GraphFeedTestHarness h, {
    bool preload = true,
  }) async {
    if (preload) {
      await h.controller.load();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraphFeedScreen(
            authSession: h.auth,
            likedPosts: h.likedPosts,
            controller: h.controller,
            userRepository: h.users,
            postRepository: h.posts,
            preferencesRepository: h.preferences,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders current post and neighbor bubbles', (tester) async {
    final h = GraphFeedTestHarness();
    h.seedSession(
      posts: [
        graphTestPost(id: 'c1', content: 'Current bubble body'),
      ],
    );
    h.graph.neighbors['c1'] = [
      graphTestPost(id: 'n1', topic: 'science'),
      graphTestPost(id: 'n2', topic: 'sports'),
    ];

    await pumpGraph(tester, h);

    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.text('Current bubble body'), findsOneWidget);
    expect(find.byType(BubbleField), findsOneWidget);
    expect(find.byType(NeighborBubble), findsNWidgets(2));
    expect(find.text('Science'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('empty neighbors show connected-bubbles empty state',
      (tester) async {
    final h = GraphFeedTestHarness();
    h.seedSession(
      posts: [graphTestPost(id: 'c1', content: 'Lonely post')],
    );
    h.graph.neighbors['c1'] = [];

    await pumpGraph(tester, h);

    expect(find.text('No connected bubbles'), findsOneWidget);
    expect(find.text('Lonely post'), findsOneWidget);
    expect(find.byType(BubbleField), findsNothing);
  });

  testWidgets('no session shows empty session card', (tester) async {
    final h = GraphFeedTestHarness();
    h.preferences.current = graphTestPrefs(blacklisted: ['politics']);
    h.feed.sessions.addAll([
      for (var i = 0; i < 3; i++)
        GraphSessionFeed(
          posts: [graphTestPost(id: 'bad-$i', topic: 'politics')],
          seedStrategy: 'diversify',
          diversify: true,
        ),
    ]);

    await pumpGraph(tester, h);

    expect(find.text('No session loaded'), findsOneWidget);
    expect(find.byType(PostCard), findsNothing);
  });

  testWidgets('bubble tap opens preview; Select advances', (tester) async {
    final h = GraphFeedTestHarness();
    h.seedSession(
      posts: [graphTestPost(id: 'c1', content: 'Root post')],
    );
    h.graph.neighbors['c1'] = [
      graphTestPost(id: 'n1', topic: 'science', content: 'Neighbor science'),
    ];
    h.graph.neighbors['n1'] = [];

    await pumpGraph(tester, h);

    await tester.tap(find.text('Science'));
    await tester.pumpAndSettle();

    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Neighbor science'), findsOneWidget);
    expect(find.byType(BubbleField), findsNothing);

    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(h.controller.currentNode?.id, 'n1');
    expect(h.users.recorded.single.type, GraphInteractionType.explore);
    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.text('Neighbor science'), findsOneWidget);
    expect(find.text('Select'), findsNothing);
  });

  testWidgets('Back dismisses preview without advancing', (tester) async {
    final h = GraphFeedTestHarness();
    h.seedSession(posts: [graphTestPost(id: 'c1', content: 'Root post')]);
    h.graph.neighbors['c1'] = [
      graphTestPost(id: 'n1', topic: 'science', content: 'Neighbor science'),
    ];

    await pumpGraph(tester, h);
    await tester.tap(find.text('Science'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(h.controller.currentNode?.id, 'c1');
    expect(h.users.recorded, isEmpty);
    expect(find.byType(BubbleField), findsOneWidget);
    expect(find.text('Select'), findsNothing);
  });

  testWidgets('Skip advances via controller', (tester) async {
    final h = GraphFeedTestHarness();
    h.seedSession(posts: [graphTestPost(id: 'c1', content: 'Root post')]);
    h.graph.neighbors['c1'] = [
      graphTestPost(id: 'n1', topic: 'sports', content: 'Skipped-to post'),
    ];
    h.graph.neighbors['n1'] = [];

    await pumpGraph(tester, h);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(h.controller.currentNode?.id, 'n1');
    expect(h.users.recorded.single.type, GraphInteractionType.skip);
    expect(find.text('Skipped-to post'), findsOneWidget);
  });

  testWidgets('Explore refreshes with diversify', (tester) async {
    final h = GraphFeedTestHarness();
    h.seedSession(posts: [graphTestPost(id: 'c1', content: 'First')]);
    h.seedSession(
      posts: [graphTestPost(id: 'c2', content: 'Explored', topic: 'health')],
      seedStrategy: 'diversify',
      diversify: true,
    );
    h.graph.neighbors['c1'] = [];
    h.graph.neighbors['c2'] = [];

    await pumpGraph(tester, h);
    await tester.tap(find.bySemanticsLabel('Explore Other Bubbles'));
    await tester.pumpAndSettle();

    expect(h.feed.diversifyFlags, [false, true]);
    expect(h.controller.currentNode?.id, 'c2');
    expect(find.text('Explored'), findsOneWidget);
  });

  testWidgets('loading state shows progress card before first post',
      (tester) async {
    final h = GraphFeedTestHarness();
    h.feed.responseDelay = const Duration(milliseconds: 40);
    h.seedSession(posts: [graphTestPost(id: 'c1', content: 'Ready')]);
    h.graph.neighbors['c1'] = [];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GraphFeedScreen(
            authSession: h.auth,
            likedPosts: h.likedPosts,
            controller: h.controller,
            userRepository: h.users,
            postRepository: h.posts,
            preferencesRepository: h.preferences,
          ),
        ),
      ),
    );
    await tester.pump();

    final loadFuture = h.controller.load();
    await tester.pump();
    expect(find.text('Loading graph feed'), findsOneWidget);
    expect(find.byType(AsyncBody), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 50));
    await loadFuture;
    await tester.pumpAndSettle();
    expect(find.text('Loading graph feed'), findsNothing);
    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
  });
}
