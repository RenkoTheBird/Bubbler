import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_session.dart';
import '../../core/storage/liked_posts_store.dart';
import '../../data/models/topics.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/theme/topic_style.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/bubbler_logo.dart';
import '../../shared/widgets/post_card.dart';
import 'ranked_feed_controller.dart';

/// Ranked discovery feed — Swift `FeedView`.
class RankedFeedScreen extends StatefulWidget {
  const RankedFeedScreen({
    super.key,
    required this.authSession,
    required this.likedPosts,
    required this.controller,
    required this.userRepository,
    required this.postRepository,
    required this.preferencesRepository,
  });

  final AuthSession authSession;
  final LikedPostsStore likedPosts;
  final RankedFeedController controller;
  final UserRepository userRepository;
  final PostRepository postRepository;
  final PreferencesRepository preferencesRepository;

  @override
  State<RankedFeedScreen> createState() => _RankedFeedScreenState();
}

class _RankedFeedScreenState extends State<RankedFeedScreen> {
  static final List<String?> _feedTopics = [
    null,
    ...KnownTopics.all.map<String?>((topic) => topic),
  ];

  String? _loadedForToken;

  RankedFeedController get _controller => widget.controller;
  AuthSession get _auth => widget.authSession;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _auth.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  @override
  void didUpdateWidget(covariant RankedFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _loadedForToken = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
    }
    if (oldWidget.authSession != widget.authSession) {
      oldWidget.authSession.removeListener(_onAuthChanged);
      widget.authSession.addListener(_onAuthChanged);
      _loadedForToken = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onAuthChanged() {
    _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    final token = _auth.accessToken;
    if (token == null) {
      _loadedForToken = null;
      return;
    }
    if (_loadedForToken == token) return;
    _loadedForToken = token;
    await _controller.loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: BubblerTheme.feedGradient),
      child: SafeArea(
        child: RefreshIndicator(
          color: Colors.white,
          backgroundColor: BubblerTheme.deepBlue,
          onRefresh: _controller.loadFeed,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
            children: [
              const _FeedHeader(),
              const SizedBox(height: 20),
              _TopicStrip(
                topics: _feedTopics,
                selectedTopic: _controller.selectedTopic,
                isLoading: _controller.isLoading,
                onSelect: _controller.selectTopic,
              ),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildFeedBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedBody() {
    if (_controller.isLoading && _controller.posts.isEmpty) {
      return AsyncBody.loading(
        title: 'Loading your feed',
        message: 'Pulling the latest posts from Bubbler.',
      );
    }

    if (_controller.errorMessage != null) {
      return AsyncBody.empty(
        title: "Couldn't load the feed",
        message: _controller.errorMessage!,
      );
    }

    if (_controller.posts.isEmpty) {
      return AsyncBody.empty(
        title: 'No posts yet',
        message: _controller.selectedTopic == null
            ? 'Posts from the database will show up here after the feed has data.'
            : 'No posts matched this topic yet. Try another bubble.',
      );
    }

    return Column(
      children: [
        for (final post in _controller.posts) ...[
          PostCard(
            post: post,
            authSession: _auth,
            likedPosts: widget.likedPosts,
            userRepository: widget.userRepository,
            postRepository: widget.postRepository,
            preferencesRepository: widget.preferencesRepository,
            onDeleted: () => _controller.removePost(post.id),
            onEdited: (content) => _controller.updatePostContent(
              id: post.id,
              content: content,
            ),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          BubblerLogo(size: 55),
          SizedBox(height: 16),
          Text(
            'BUBBLER',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              height: 1.1,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'your interest field is active',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicStrip extends StatelessWidget {
  const _TopicStrip({
    required this.topics,
    required this.selectedTopic,
    required this.isLoading,
    required this.onSelect,
  });

  final List<String?> topics;
  final String? selectedTopic;
  final bool isLoading;
  final Future<void> Function(String?) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: topics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final topic = topics[index];
          return _TopicChip(
            topic: topic,
            selected: topic == null
                ? selectedTopic == null
                : selectedTopic?.toLowerCase() == topic.toLowerCase(),
            enabled: !isLoading,
            onTap: () => onSelect(topic),
          );
        },
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.topic,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String? topic;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = topic == null ? 'All' : KnownTopics.displayName(topic!);
    final icon = topic == null ? Icons.auto_awesome : TopicStyle.icon(topic!);
    final color = topic == null ? Colors.cyan : TopicStyle.color(topic!);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ]
                  : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
