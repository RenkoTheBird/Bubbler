import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/auth/auth_session.dart';
import '../core/storage/liked_posts_store.dart';
import '../data/models/post.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/preferences_repository.dart';
import '../data/repositories/user_repository.dart';
import 'widgets/async_body.dart';
import 'widgets/bubbler_logo.dart';
import 'widgets/post_card.dart';
import 'widgets/preference_slider.dart';
import 'widgets/preference_topics_editor.dart';
import 'widgets/status_banner.dart';
import 'widgets/topic_picker.dart';

/// Phase 3 exit gallery: logo, topic picker, sample post card, and related
/// shared primitives. Reachable from the Settings tab for now.
class SharedWidgetsGallery extends StatefulWidget {
  const SharedWidgetsGallery({
    super.key,
    required this.authSession,
    required this.likedPosts,
    this.userRepository,
    this.postRepository,
    this.preferencesRepository,
  });

  final AuthSession authSession;
  final LikedPostsStore likedPosts;
  final UserRepository? userRepository;
  final PostRepository? postRepository;
  final PreferencesRepository? preferencesRepository;

  @override
  State<SharedWidgetsGallery> createState() => _SharedWidgetsGalleryState();
}

class _SharedWidgetsGalleryState extends State<SharedWidgetsGallery> {
  String _selectedTopic = 'technology';
  double _sliderValue = 0.4;
  List<String> _preferredTopics = const ['science'];
  List<String> _blacklistedTopics = const [];
  late Post _samplePost;

  @override
  void initState() {
    super.initState();
    _samplePost = Post(
      id: 'gallery-preview-post',
      userId: widget.authSession.userId ?? 0,
      username: 'preview',
      content: 'A sample bubble post for the shared PostCard gallery.',
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      topic: 'technology',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared UI gallery'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: BubblerTheme.backgroundGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const _SectionLabel('BubblerLogo'),
            const Center(child: BubblerLogo(size: 160)),
            const SizedBox(height: 24),
            const _SectionLabel('TopicPicker'),
            TopicPicker(
              selectedTopic: _selectedTopic,
              onChanged: (topic) => setState(() => _selectedTopic = topic),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('PostCard'),
            PostCard(
              post: _samplePost,
              authSession: widget.authSession,
              likedPosts: widget.likedPosts,
              userRepository: widget.userRepository,
              postRepository: widget.postRepository,
              preferencesRepository: widget.preferencesRepository,
              showsSkip: true,
              isTopicPreferred: _preferredTopics.any(
                (t) => t.toLowerCase() == (_samplePost.topic ?? '').toLowerCase(),
              ),
              onSkip: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Skip tapped (gallery)')),
                );
              },
              onEdited: (content) {
                setState(() {
                  _samplePost = _samplePost.copyWith(content: content);
                });
              },
            ),
            const SizedBox(height: 24),
            const _SectionLabel('StatusBanner'),
            StatusBanner.status('Graph session ready — exploring connected posts.'),
            const SizedBox(height: 8),
            StatusBanner.error('Could not load neighbors. Try diversify.'),
            const SizedBox(height: 24),
            const _SectionLabel('AsyncBody'),
            AsyncBody.loading(
              title: 'Loading graph feed',
              message: 'Pulling your initial session from Bubbler.',
            ),
            const SizedBox(height: 8),
            AsyncBody.empty(
              title: 'No connected bubbles',
              message: 'Like, skip, or explore to keep walking the graph.',
            ),
            const SizedBox(height: 24),
            const _SectionLabel('PreferenceSlider'),
            PreferenceSlider(
              title: 'Diversity tolerance',
              value: _sliderValue,
              tint: BubblerTheme.cyan,
              onChanged: (value) => setState(() => _sliderValue = value),
            ),
            const SizedBox(height: 24),
            const _SectionLabel('PreferenceTopicsEditor'),
            PreferenceTopicsEditor(
              title: 'Preferred topics',
              subtitle: 'Boost posts in these bubbles.',
              icon: Icons.star,
              iconColor: Colors.amber,
              topics: _preferredTopics,
              conflictingTopics: _blacklistedTopics,
              onChanged: (topics) => setState(() => _preferredTopics = topics),
              onConflictingChanged: (topics) =>
                  setState(() => _blacklistedTopics = topics),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
