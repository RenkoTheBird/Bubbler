import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/auth/auth_session.dart';
import '../../core/storage/liked_posts_store.dart';
import '../../data/models/graph.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/widgets/async_body.dart';
import '../../shared/widgets/post_card.dart';
import '../../shared/widgets/status_banner.dart';
import 'graph_feed_controller.dart';
import 'widgets/bubble_field.dart';

/// Graph walk UI — Swift `GraphFeedView`.
class GraphFeedScreen extends StatefulWidget {
  const GraphFeedScreen({
    super.key,
    required this.authSession,
    required this.likedPosts,
    required this.controller,
    required this.userRepository,
    required this.postRepository,
    required this.preferencesRepository,
    this.onSignOut,
  });

  final AuthSession authSession;
  final LikedPostsStore likedPosts;
  final GraphFeedController controller;
  final UserRepository userRepository;
  final PostRepository postRepository;
  final PreferencesRepository preferencesRepository;

  /// Temporary until Phase 5 tabs own account chrome.
  final VoidCallback? onSignOut;

  @override
  State<GraphFeedScreen> createState() => _GraphFeedScreenState();
}

class _GraphFeedScreenState extends State<GraphFeedScreen> {
  /// Stored as an ID so preference flag refreshes on `nextChoices` stay in sync.
  String? _previewedChoiceId;
  String? _loadedForToken;

  AuthSession get _auth => widget.authSession;
  GraphFeedController get _controller => widget.controller;

  GraphFeedNode? get _previewedChoice {
    final id = _previewedChoiceId;
    if (id == null) return null;
    for (final node in _controller.nextChoices) {
      if (node.id == id) return node;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
    _auth.addListener(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  @override
  void didUpdateWidget(covariant GraphFeedScreen oldWidget) {
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
    final currentId = _controller.currentNode?.id;
    if (_lastCurrentNodeId != currentId) {
      _previewedChoiceId = null;
      _lastCurrentNodeId = currentId;
    }

    final choiceIds = _controller.nextChoices.map((n) => n.id).toSet();
    if (_previewedChoiceId != null &&
        !choiceIds.contains(_previewedChoiceId)) {
      _previewedChoiceId = null;
    }

    if (mounted) {
      setState(() {});
    }
  }

  String? _lastCurrentNodeId;

  void _onAuthChanged() {
    _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    final token = _auth.accessToken;
    if (token == null) return;
    if (_loadedForToken == token) return;
    _loadedForToken = token;
    await _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: BubblerTheme.feedGradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            children: [
              _TopChrome(
                isBusy: _controller.isLoading || _controller.isSubmitting,
                onExplore: _controller.isLoading || _controller.isSubmitting
                    ? null
                    : () async {
                        setState(() => _previewedChoiceId = null);
                        await _controller.refreshSession();
                      },
                onSignOut: widget.onSignOut,
              ),
              if (_controller.statusMessage != null) ...[
                const SizedBox(height: 12),
                StatusBanner.status(_controller.statusMessage!),
              ],
              if (_controller.errorMessage != null) ...[
                const SizedBox(height: 12),
                StatusBanner.error(_controller.errorMessage!),
              ],
              const SizedBox(height: 12),
              Expanded(child: _buildMiddleSection()),
              _buildStickyCurrentPost(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiddleSection() {
    if (_controller.isLoading && !_controller.hasCurrentPost) {
      return AsyncBody.loading(
        title: 'Loading graph feed',
        message: 'Pulling your initial session from Bubbler.',
      );
    }

    if (_previewedChoiceId != null) {
      final previewed = _previewedChoice;
      if (previewed == null) {
        return AsyncBody.loading(
          title: 'Loading preview',
          message: 'Refreshing this bubble.',
        );
      }
      return _PreviewSection(
        node: previewed,
        authSession: _auth,
        likedPosts: widget.likedPosts,
        userRepository: widget.userRepository,
        postRepository: widget.postRepository,
        preferencesRepository: widget.preferencesRepository,
        isSubmitting: _controller.isSubmitting,
        onBack: () => setState(() => _previewedChoiceId = null),
        onSelect: () async {
          await _controller.choose(previewed);
          if (mounted) {
            setState(() => _previewedChoiceId = null);
          }
        },
        onTopicPreferenceChanged: _controller.syncTopicPreferences,
      );
    }

    if (_controller.currentNode == null) {
      return AsyncBody.empty(
        title: 'No session loaded',
        message:
            'Generate a new graph session to start exploring connected posts.',
      );
    }

    if (_controller.nextChoices.isEmpty) {
      return AsyncBody.empty(
        title: 'No connected bubbles',
        message: 'Like, skip, or explore to keep walking the graph.',
      );
    }

    return BubbleField(
      choices: _controller.nextChoices,
      enabled: !_controller.isSubmitting,
      onBubbleTap: (node) {
        setState(() => _previewedChoiceId = node.id);
      },
    );
  }

  Widget _buildStickyCurrentPost() {
    final node = _controller.currentNode;
    if (node == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          IgnorePointer(
            ignoring: _controller.isSubmitting,
            child: PostCard(
              post: node.post,
              authSession: _auth,
              likedPosts: widget.likedPosts,
              userRepository: widget.userRepository,
              postRepository: widget.postRepository,
              preferencesRepository: widget.preferencesRepository,
              showsSkip: true,
              isCompact: true,
              isTopicPreferred: node.isPreferredTopic,
              isTopicBlacklisted: node.isBlacklistedTopic,
              onSkip: () async {
                setState(() => _previewedChoiceId = null);
                await _controller.skipCurrentPost();
              },
              onTopicPreferenceChanged: _controller.syncTopicPreferences,
              onDeleted: _controller.handleCurrentPostDeleted,
              onEdited: _controller.updateCurrentPostContent,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.isBusy,
    required this.onExplore,
    this.onSignOut,
  });

  final bool isBusy;
  final Future<void> Function()? onExplore;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onSignOut != null)
          IconButton(
            onPressed: onSignOut,
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        if (isBusy)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        const Spacer(),
        Semantics(
          button: true,
          label: 'Explore Other Bubbles',
          onTap: onExplore == null ? null : () => onExplore!(),
          child: ExcludeSemantics(
            child: Opacity(
              opacity: onExplore == null ? 0.45 : 1,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: onExplore == null ? null : () => onExplore!(),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_tree,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Explore',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.node,
    required this.authSession,
    required this.likedPosts,
    required this.userRepository,
    required this.postRepository,
    required this.preferencesRepository,
    required this.isSubmitting,
    required this.onBack,
    required this.onSelect,
    required this.onTopicPreferenceChanged,
  });

  final GraphFeedNode node;
  final AuthSession authSession;
  final LikedPostsStore likedPosts;
  final UserRepository userRepository;
  final PostRepository postRepository;
  final PreferencesRepository preferencesRepository;
  final bool isSubmitting;
  final VoidCallback onBack;
  final Future<void> Function() onSelect;
  final Future<void> Function() onTopicPreferenceChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _CapsuleButton(
              label: 'Back',
              icon: Icons.chevron_left,
              foreground: Colors.white,
              background: Colors.white.withValues(alpha: 0.12),
              onPressed: onBack,
            ),
            const Spacer(),
            _CapsuleButton(
              label: 'Select',
              icon: Icons.check_circle,
              foreground: Colors.black,
              background: Colors.white,
              onPressed: isSubmitting ? null : () => onSelect(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: PostCard(
              post: node.post,
              authSession: authSession,
              likedPosts: likedPosts,
              userRepository: userRepository,
              postRepository: postRepository,
              preferencesRepository: preferencesRepository,
              showsSkip: false,
              isCompact: false,
              isTopicPreferred: node.isPreferredTopic,
              isTopicBlacklisted: node.isBlacklistedTopic,
              onTopicPreferenceChanged: onTopicPreferenceChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  const _CapsuleButton({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
