/// Hard-coded API path constants formerly inlined in Swift `APIClient`.
abstract final class Endpoints {
  static const health = '/health';

  static const authLogin = '/auth/login';
  static const authRegister = '/auth/register';

  static const search = '/search';

  static const feedMe = '/feed/me';
  static const feedMeSession = '/feed/me/session';

  static String graphNext(String postId) => '/graph/posts/$postId/next';

  static const userMe = '/user/me';
  static const userMeProfile = '/user/me/profile';
  static const userMeProfileEmail = '/user/me/profile/email';
  static const userMeProfilePassword = '/user/me/profile/password';
  static const userMePreferences = '/user/me/preferences';
  static const userMePosts = '/user/me/posts';
  static const userMeInteractions = '/user/me/interactions';
  static const userMeLikes = '/user/me/likes';
  static const userMeBlocks = '/user/me/blocks';

  static String userMePost(String postId) => '/user/me/posts/$postId';

  static String userMePostTopics(String postId) =>
      '/user/me/posts/$postId/topics';

  static String userMePostTopic(String postId, String topic) =>
      '/user/me/posts/$postId/topics/$topic';

  static String userMeInteractionLike(String postId) =>
      '/user/me/interactions/$postId/like';

  static String userMeBlock(String username) =>
      '/user/me/blocks/${Uri.encodeComponent(username)}';

  static String userProfile(String username) =>
      '/user/${Uri.encodeComponent(username)}/profile';

  static String userPosts(String username) =>
      '/user/${Uri.encodeComponent(username)}/posts';
}
