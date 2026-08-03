import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_session.dart';
import '../../core/storage/liked_posts_store.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/platform/platform.dart';
import '../../shared/widgets_gallery.dart';
import 'feed_tab.dart';

/// Main tabs — Swift `MainTabView`: Feed | Search | Profile | Settings.
class HomeShell extends StatelessWidget {
  const HomeShell({
    super.key,
    required this.authSession,
    required this.apiClient,
    required this.userRepository,
    required this.postRepository,
    required this.preferencesRepository,
    required this.likedPosts,
  });

  final AuthSession authSession;
  final ApiClient apiClient;
  final UserRepository userRepository;
  final PostRepository postRepository;
  final PreferencesRepository preferencesRepository;
  final LikedPostsStore likedPosts;

  static const _destinations = <AdaptiveTabDestination>[
    AdaptiveTabDestination(
      label: 'Feed',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    AdaptiveTabDestination(
      label: 'Search',
      icon: Icons.search,
    ),
    AdaptiveTabDestination(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
    AdaptiveTabDestination(
      label: 'Settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertinoPlatform(context);
    final destinations = cupertino
        ? const <AdaptiveTabDestination>[
            AdaptiveTabDestination(
              label: 'Feed',
              icon: CupertinoIcons.house,
              selectedIcon: CupertinoIcons.house_fill,
            ),
            AdaptiveTabDestination(
              label: 'Search',
              icon: CupertinoIcons.search,
            ),
            AdaptiveTabDestination(
              label: 'Profile',
              icon: CupertinoIcons.person,
              selectedIcon: CupertinoIcons.person_fill,
            ),
            AdaptiveTabDestination(
              label: 'Settings',
              icon: CupertinoIcons.gear,
              selectedIcon: CupertinoIcons.gear_solid,
            ),
          ]
        : _destinations;

    return AdaptiveTabScaffold(
      destinations: destinations,
      activeColor: BubblerTheme.cyan,
      tabBuilder: (context, index) {
        return switch (index) {
          0 => FeedTab(
              authSession: authSession,
              apiClient: apiClient,
              userRepository: userRepository,
              postRepository: postRepository,
              preferencesRepository: preferencesRepository,
              likedPosts: likedPosts,
            ),
          1 => const _ComingSoonTab(
              title: 'Search',
              subtitle: 'Coming in Phase 6.1–6.2',
              icon: Icons.search,
            ),
          2 => const _ComingSoonTab(
              title: 'Profile',
              subtitle: 'Coming in Phase 6.3–6.5',
              icon: Icons.person,
            ),
          _ => _SettingsPlaceholderTab(
              authSession: authSession,
              likedPosts: likedPosts,
              userRepository: userRepository,
              postRepository: postRepository,
              preferencesRepository: preferencesRepository,
            ),
        };
      },
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertinoPlatform(context);
    final body = DecoratedBox(
      decoration: BoxDecoration(gradient: BubblerTheme.feedGradient),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white70, size: 40),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (cupertino) {
      return CupertinoPageScaffold(
        backgroundColor: Colors.transparent,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: BubblerTheme.deepBlue.withValues(alpha: 0.92),
          border: null,
          middle: Text(title, style: const TextStyle(color: Colors.white)),
        ),
        child: Material(type: MaterialType.transparency, child: body),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}

/// Temporary settings surface until Phase 7 — keeps sign-out + UI gallery.
class _SettingsPlaceholderTab extends StatelessWidget {
  const _SettingsPlaceholderTab({
    required this.authSession,
    required this.likedPosts,
    required this.userRepository,
    required this.postRepository,
    required this.preferencesRepository,
  });

  final AuthSession authSession;
  final LikedPostsStore likedPosts;
  final UserRepository userRepository;
  final PostRepository postRepository;
  final PreferencesRepository preferencesRepository;

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertinoPlatform(context);
    final body = DecoratedBox(
      decoration: BoxDecoration(gradient: BubblerTheme.feedGradient),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Full settings land in Phase 7. Sign out and the UI gallery '
              'stay available here for now.',
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 28),
            _SettingsActionTile(
              label: 'UI gallery',
              icon: Icons.widgets_outlined,
              onTap: () {
                Navigator.of(context).push(
                  adaptivePageRoute<void>(
                    context: context,
                    title: 'UI gallery',
                    builder: (_) => SharedWidgetsGallery(
                      authSession: authSession,
                      likedPosts: likedPosts,
                      userRepository: userRepository,
                      postRepository: postRepository,
                      preferencesRepository: preferencesRepository,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _SettingsActionTile(
              label: 'Sign out',
              icon: Icons.logout,
              destructive: true,
              onTap: () => authSession.signOut(),
            ),
          ],
        ),
      ),
    );

    if (cupertino) {
      return CupertinoPageScaffold(
        backgroundColor: Colors.transparent,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: BubblerTheme.deepBlue.withValues(alpha: 0.92),
          border: null,
          middle: const Text(
            'Settings',
            style: TextStyle(color: Colors.white),
          ),
        ),
        child: Material(type: MaterialType.transparency, child: body),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: body,
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive ? const Color(0xFFFF8A80) : Colors.white;
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: foreground.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
