import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/auth_session.dart';
import '../../core/storage/liked_posts_store.dart';
import '../../data/repositories/feed_repository.dart';
import '../../data/repositories/graph_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../shared/platform/platform.dart';
import '../feed/ranked_feed_controller.dart';
import '../feed/ranked_feed_screen.dart';
import '../graph/graph_feed_controller.dart';
import '../graph/graph_feed_screen.dart';
import '../post/create_post_screen.dart';

/// Feed mode owned by the home Feed tab (Swift `MainTabView.FeedMode`).
enum FeedMode {
  graph,
  ranked,
}

/// Graph ↔ ranked toggle + Create Post entry — Swift feed tab in `MainTabView`.
class FeedTab extends StatefulWidget {
  const FeedTab({
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

  @override
  State<FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<FeedTab> {
  FeedMode _mode = FeedMode.graph;
  late final FeedRepository _feedRepository;
  late final GraphRepository _graphRepository;
  late final GraphFeedController _graphController;
  late final RankedFeedController _rankedController;

  @override
  void initState() {
    super.initState();
    _feedRepository = FeedRepository(widget.apiClient);
    _graphRepository = GraphRepository(widget.apiClient);
    _graphController = GraphFeedController(
      authSession: widget.authSession,
      feedRepository: _feedRepository,
      graphRepository: _graphRepository,
      preferencesRepository: widget.preferencesRepository,
      userRepository: widget.userRepository,
      postRepository: widget.postRepository,
    );
    _rankedController = RankedFeedController(
      authSession: widget.authSession,
      feedRepository: _feedRepository,
    );
  }

  @override
  void dispose() {
    _graphController.dispose();
    _rankedController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _mode = _mode == FeedMode.graph ? FeedMode.ranked : FeedMode.graph;
    });
  }

  Future<void> _openCreatePost() async {
    final content = await Navigator.of(context).push<String>(
      adaptivePageRoute<String>(
        context: context,
        title: 'Create Post',
        builder: (_) => CreatePostScreen(
          authSession: widget.authSession,
          postRepository: widget.postRepository,
        ),
      ),
    );
    if (!mounted || content == null) return;

    // Refresh discovery surfaces so the new post can appear (Phase 5 exit).
    await _rankedController.loadFeed();
    if (_mode == FeedMode.graph) {
      await _graphController.refreshSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertinoPlatform(context);
    final toggleLabel = _mode == FeedMode.graph ? 'Feed' : 'Graph';
    final toggleSemantics = _mode == FeedMode.graph
        ? 'Switch to Feed'
        : 'Switch to Graph';
    final toggleIcon = _mode == FeedMode.graph
        ? (cupertino ? CupertinoIcons.list_bullet : Icons.list)
        : (cupertino ? CupertinoIcons.circle_grid_3x3_fill : Icons.hexagon);
    final composeIcon = cupertino
        ? CupertinoIcons.square_pencil
        : Icons.edit_square;

    final body = switch (_mode) {
      FeedMode.graph => GraphFeedScreen(
          authSession: widget.authSession,
          likedPosts: widget.likedPosts,
          controller: _graphController,
          userRepository: widget.userRepository,
          postRepository: widget.postRepository,
          preferencesRepository: widget.preferencesRepository,
        ),
      FeedMode.ranked => RankedFeedScreen(
          authSession: widget.authSession,
          likedPosts: widget.likedPosts,
          controller: _rankedController,
          userRepository: widget.userRepository,
          postRepository: widget.postRepository,
          preferencesRepository: widget.preferencesRepository,
        ),
    };

    final toggleControl = Semantics(
      button: true,
      label: toggleSemantics,
      child: ExcludeSemantics(
        child: cupertino
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _toggleMode,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(toggleIcon, size: 20, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      toggleLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              )
            : TextButton.icon(
                onPressed: _toggleMode,
                icon: Icon(toggleIcon, color: Colors.white),
                label: Text(
                  toggleLabel,
                  style: const TextStyle(color: Colors.white),
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
          leading: toggleControl,
          trailing: Semantics(
            button: true,
            label: 'Create Post',
            child: ExcludeSemantics(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _openCreatePost,
                child: Icon(composeIcon, color: Colors.white),
              ),
            ),
          ),
          middle: const Text(
            'Bubbler',
            style: TextStyle(color: Colors.white),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Bubbler'),
        leadingWidth: 96,
        leading: toggleControl,
        actions: [
          IconButton(
            onPressed: _openCreatePost,
            tooltip: 'Create Post',
            icon: Icon(composeIcon),
          ),
        ],
      ),
      body: body,
    );
  }
}
