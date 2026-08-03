import 'package:bubbler_app/core/api/api_client.dart';
import 'package:bubbler_app/core/auth/auth_session.dart';
import 'package:bubbler_app/core/auth/token_store.dart';
import 'package:bubbler_app/core/storage/liked_posts_store.dart';
import 'package:bubbler_app/data/repositories/auth_repository.dart';
import 'package:bubbler_app/data/repositories/user_repository.dart';
import 'package:bubbler_app/shared/theme/topic_style.dart';
import 'package:bubbler_app/shared/widgets/bubbler_logo.dart';
import 'package:bubbler_app/shared/widgets/post_card.dart';
import 'package:bubbler_app/shared/widgets/relative_time.dart';
import 'package:bubbler_app/shared/widgets/topic_picker.dart';
import 'package:bubbler_app/shared/widgets_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('TopicStyle maps known topics', () {
    expect(TopicStyle.icon('technology'), Icons.computer);
    expect(TopicStyle.color('sports'), Colors.green);
    expect(TopicStyle.icon('unknown-topic'), Icons.grid_view);
  });

  test('formatRelativeTime covers minute bucket', () {
    final stamp = DateTime.now().subtract(const Duration(minutes: 12));
    expect(formatRelativeTime(stamp), '12m ago');
  });

  testWidgets('gallery shows logo, topic picker, and sample post card',
      (tester) async {
    final apiClient = ApiClient(accessTokenProvider: () => null);
    final authSession = AuthSession(
      authRepository: AuthRepository(apiClient),
      tokenStore: TokenStore(),
    );
    final likedPosts = LikedPostsStore(UserRepository(apiClient));

    await tester.pumpWidget(
      MaterialApp(
        home: SharedWidgetsGallery(
          authSession: authSession,
          likedPosts: likedPosts,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BubblerLogo), findsOneWidget);
    expect(find.byType(TopicPicker), findsOneWidget);
    expect(find.byType(PostCard), findsOneWidget);
    expect(
      find.text('A sample bubble post for the shared PostCard gallery.'),
      findsOneWidget,
    );
    expect(find.text('Technology'), findsWidgets);
  });
}
