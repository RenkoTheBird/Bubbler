import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_session.dart';
import '../core/storage/liked_posts_store.dart';
import '../data/repositories/feed_repository.dart';
import '../data/repositories/graph_repository.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/repositories/user_repository.dart';
import '../features/auth/login_screen.dart';
import '../features/graph/graph_feed_controller.dart';
import '../features/graph/graph_feed_screen.dart';
import '../shared/widgets_gallery.dart';
import 'theme.dart';

/// Auth gate matching Swift `ContentView`: signed-in home vs login stack.
///
/// Phase 4 surfaces the graph feed as the signed-in home. Main tabs arrive in
/// Phase 5.
class AuthGate extends StatefulWidget {
  const AuthGate({
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
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _pendingSuccessClear;
  bool _wasSignedIn = false;

  AuthSession get _session => widget.authSession;

  @override
  void initState() {
    super.initState();
    _wasSignedIn = _session.isSignedIn;
    _session.addListener(_onSessionChanged);
    if (_session.isSignedIn) {
      widget.likedPosts.refresh();
    }
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authSession != widget.authSession) {
      oldWidget.authSession.removeListener(_onSessionChanged);
      widget.authSession.addListener(_onSessionChanged);
    }
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) {
      return;
    }

    if (_session.isSignedIn && !_wasSignedIn) {
      widget.likedPosts.refresh();
    }
    if (!_session.isSignedIn && _wasSignedIn) {
      widget.likedPosts.clear();
    }
    _wasSignedIn = _session.isSignedIn;

    setState(() {});

    final message = _session.successMessage;
    if (message != null && message != _pendingSuccessClear) {
      _pendingSuccessClear = message;
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) {
          return;
        }
        if (_session.successMessage == message) {
          _session.clearSuccessMessage();
        }
        if (_pendingSuccessClear == message) {
          _pendingSuccessClear = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        KeyedSubtree(
          // Reset navigation when auth flips (Swift `.id(isSignedIn)`).
          key: ValueKey(_session.isSignedIn),
          child: _session.isSignedIn
              ? _SignedInGraphHome(
                  authSession: _session,
                  apiClient: widget.apiClient,
                  userRepository: widget.userRepository,
                  postRepository: widget.postRepository,
                  preferencesRepository: widget.preferencesRepository,
                  likedPosts: widget.likedPosts,
                )
              : LoginScreen(
                  authSession: _session,
                  apiClient: widget.apiClient,
                ),
        ),
        if (_session.successMessage != null)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 18,
            left: 24,
            right: 24,
            child: IgnorePointer(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    child: Text(
                      _session.successMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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

/// Signed-in graph home until Phase 5 `HomeShell` / main tabs.
class _SignedInGraphHome extends StatefulWidget {
  const _SignedInGraphHome({
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
  State<_SignedInGraphHome> createState() => _SignedInGraphHomeState();
}

class _SignedInGraphHomeState extends State<_SignedInGraphHome> {
  late final FeedRepository _feedRepository;
  late final GraphRepository _graphRepository;
  late final GraphFeedController _controller;

  @override
  void initState() {
    super.initState();
    _feedRepository = FeedRepository(widget.apiClient);
    _graphRepository = GraphRepository(widget.apiClient);
    _controller = GraphFeedController(
      authSession: widget.authSession,
      feedRepository: _feedRepository,
      graphRepository: _graphRepository,
      preferencesRepository: widget.preferencesRepository,
      userRepository: widget.userRepository,
      postRepository: widget.postRepository,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GraphFeedScreen(
            authSession: widget.authSession,
            likedPosts: widget.likedPosts,
            controller: _controller,
            userRepository: widget.userRepository,
            postRepository: widget.postRepository,
            preferencesRepository: widget.preferencesRepository,
            onSignOut: () => widget.authSession.signOut(),
          ),
          Positioned(
            left: 8,
            bottom: MediaQuery.paddingOf(context).bottom + 8,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SharedWidgetsGallery(
                      authSession: widget.authSession,
                      likedPosts: widget.likedPosts,
                      userRepository: widget.userRepository,
                      postRepository: widget.postRepository,
                      preferencesRepository: widget.preferencesRepository,
                    ),
                  ),
                );
              },
              child: Text(
                'UI gallery',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Brief splash while [AuthSession.restore] runs.
class AuthRestoreSplash extends StatelessWidget {
  const AuthRestoreSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: BubblerTheme.backgroundGradient),
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
