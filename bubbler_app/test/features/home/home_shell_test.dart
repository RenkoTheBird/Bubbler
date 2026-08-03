import 'package:bubbler_app/core/api/api_client.dart';
import 'package:bubbler_app/core/auth/auth_session.dart';
import 'package:bubbler_app/core/auth/token_store.dart';
import 'package:bubbler_app/core/storage/liked_posts_store.dart';
import 'package:bubbler_app/data/repositories/auth_repository.dart';
import 'package:bubbler_app/data/repositories/post_repository.dart';
import 'package:bubbler_app/data/repositories/preferences_repository.dart';
import 'package:bubbler_app/data/repositories/user_repository.dart';
import 'package:bubbler_app/features/home/feed_tab.dart';
import 'package:bubbler_app/features/home/home_shell.dart';
import 'package:bubbler_app/shared/platform/platform.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('AdaptiveTabScaffold', () {
    testWidgets('uses CupertinoTabScaffold on iOS', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: AdaptiveTabScaffold(
            destinations: const [
              AdaptiveTabDestination(
                label: 'Feed',
                icon: CupertinoIcons.house,
              ),
              AdaptiveTabDestination(
                label: 'Search',
                icon: CupertinoIcons.search,
              ),
            ],
            tabBuilder: (context, index) => Center(child: Text('tab-$index')),
          ),
        ),
      );

      expect(find.byType(CupertinoTabScaffold), findsOneWidget);
      expect(find.byType(CupertinoTabBar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('tab-0'), findsOneWidget);
    });

    testWidgets('uses NavigationBar on Android', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: AdaptiveTabScaffold(
            destinations: const [
              AdaptiveTabDestination(label: 'Feed', icon: Icons.home),
              AdaptiveTabDestination(label: 'Search', icon: Icons.search),
            ],
            tabBuilder: (context, index) => Center(child: Text('tab-$index')),
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(CupertinoTabScaffold), findsNothing);
      expect(find.text('tab-0'), findsOneWidget);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(find.text('tab-1'), findsOneWidget);
    });
  });

  group('HomeShell', () {
    late ApiClient apiClient;
    late AuthSession authSession;
    late UserRepository userRepository;
    late PostRepository postRepository;
    late PreferencesRepository preferencesRepository;
    late LikedPostsStore likedPosts;

    setUp(() {
      late final AuthSession session;
      apiClient = ApiClient(accessTokenProvider: () => session.accessToken);
      session = AuthSession(
        authRepository: AuthRepository(apiClient),
        tokenStore: TokenStore(),
      );
      authSession = session;
      userRepository = UserRepository(apiClient);
      postRepository = PostRepository(apiClient);
      preferencesRepository = PreferencesRepository(apiClient);
      likedPosts = LikedPostsStore(userRepository);
    });

    tearDown(() {
      authSession.dispose();
      likedPosts.dispose();
    });

    Future<void> pumpShell(
      WidgetTester tester, {
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: HomeShell(
            authSession: authSession,
            apiClient: apiClient,
            userRepository: userRepository,
            postRepository: postRepository,
            preferencesRepository: preferencesRepository,
            likedPosts: likedPosts,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('shows four main tabs on Android', (tester) async {
      await pumpShell(tester);

      expect(find.text('Feed'), findsWidgets);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byType(FeedTab), findsOneWidget);
    });

    testWidgets('Search tab shows phase placeholder', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Coming in Phase 6.1–6.2'), findsOneWidget);
    });

    testWidgets('Settings tab exposes sign out', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('UI gallery'), findsOneWidget);
    });
  });

  group('FeedTab', () {
    late ApiClient apiClient;
    late AuthSession authSession;
    late UserRepository userRepository;
    late PostRepository postRepository;
    late PreferencesRepository preferencesRepository;
    late LikedPostsStore likedPosts;

    setUp(() {
      late final AuthSession session;
      apiClient = ApiClient(accessTokenProvider: () => session.accessToken);
      session = AuthSession(
        authRepository: AuthRepository(apiClient),
        tokenStore: TokenStore(),
      );
      authSession = session;
      userRepository = UserRepository(apiClient);
      postRepository = PostRepository(apiClient);
      preferencesRepository = PreferencesRepository(apiClient);
      likedPosts = LikedPostsStore(userRepository);
    });

    tearDown(() {
      authSession.dispose();
      likedPosts.dispose();
    });

    Future<void> pumpFeed(
      WidgetTester tester, {
      TargetPlatform platform = TargetPlatform.android,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          home: FeedTab(
            authSession: authSession,
            apiClient: apiClient,
            userRepository: userRepository,
            postRepository: postRepository,
            preferencesRepository: preferencesRepository,
            likedPosts: likedPosts,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('toggles graph ↔ ranked mode', (tester) async {
      await pumpFeed(tester);

      expect(find.text('Feed'), findsOneWidget);
      expect(find.text('Ranked feed'), findsNothing);

      await tester.tap(find.text('Feed'));
      await tester.pumpAndSettle();

      expect(find.text('Ranked feed'), findsOneWidget);
      expect(find.text('Coming in Phase 5.4–5.5'), findsOneWidget);
      expect(find.text('Graph'), findsOneWidget);

      await tester.tap(find.text('Graph'));
      await tester.pumpAndSettle();

      expect(find.text('Ranked feed'), findsNothing);
      expect(find.text('Feed'), findsOneWidget);
    });

    testWidgets('opens Create Post placeholder', (tester) async {
      await pumpFeed(tester);

      await tester.tap(find.byTooltip('Create Post'));
      await tester.pumpAndSettle();

      expect(find.text('Coming in Phase 5.6–5.7'), findsOneWidget);
    });
  });
}
