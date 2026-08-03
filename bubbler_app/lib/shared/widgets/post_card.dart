import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/auth/auth_session.dart';
import '../../core/storage/liked_posts_store.dart';
import '../../data/models/graph.dart';
import '../../data/models/post.dart';
import '../../data/models/topics.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../theme/topic_style.dart';
import '../platform/platform.dart';
import 'relative_time.dart';

part 'post_card_chrome.dart';

/// Shared post card — Swift `PostCardView`.
///
/// Like / skip / edit / delete / topic prefer-blacklist are wired to
/// repositories as far as needed to compile and run. Full graph/feed
/// interaction orchestration lands in later phases.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.authSession,
    required this.likedPosts,
    this.userRepository,
    this.postRepository,
    this.preferencesRepository,
    this.showsSkip = false,
    this.isCompact = false,
    this.isTopicPreferred = false,
    this.isTopicBlacklisted = false,
    this.onSkip,
    this.onLikeChanged,
    this.onTopicPreferenceChanged,
    this.onDeleted,
    this.onEdited,
    this.onAuthorTap,
  });

  final Post post;
  final AuthSession authSession;
  final LikedPostsStore likedPosts;
  final UserRepository? userRepository;
  final PostRepository? postRepository;
  final PreferencesRepository? preferencesRepository;
  final bool showsSkip;
  final bool isCompact;
  final bool isTopicPreferred;
  final bool isTopicBlacklisted;
  final VoidCallback? onSkip;
  final ValueChanged<bool>? onLikeChanged;
  final VoidCallback? onTopicPreferenceChanged;
  final VoidCallback? onDeleted;
  final ValueChanged<String>? onEdited;
  final ValueChanged<String>? onAuthorTap;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showDeleteConfirmation = false;
  bool _isDeleting = false;
  bool _isTogglingLike = false;
  bool _isUpdatingTopicPreference = false;
  bool? _preferredLocally;
  bool? _blacklistedLocally;
  String? _actionError;
  late DateTime _appearedAt;

  Post get _post => widget.post;

  bool get _isOwned {
    final userId = widget.authSession.userId;
    if (userId == null) return false;
    return userId == _post.userId;
  }

  String? get _topicName {
    final topic = _post.topic?.trim();
    if (topic == null || topic.isEmpty) return null;
    return topic;
  }

  Color get _accentColor {
    final topic = _topicName;
    if (topic == null) return Colors.white;
    return TopicStyle.color(topic);
  }

  bool get _currentlyLiked => widget.likedPosts.isLiked(_post.id);

  bool get _currentlyPreferred =>
      _preferredLocally ?? widget.isTopicPreferred;

  bool get _currentlyBlacklisted =>
      _blacklistedLocally ?? widget.isTopicBlacklisted;

  @override
  void initState() {
    super.initState();
    _appearedAt = DateTime.now();
    widget.likedPosts.addListener(_onLikedChanged);
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.likedPosts != widget.likedPosts) {
      oldWidget.likedPosts.removeListener(_onLikedChanged);
      widget.likedPosts.addListener(_onLikedChanged);
    }
    if (oldWidget.post.id != widget.post.id) {
      _appearedAt = DateTime.now();
      _preferredLocally = null;
      _blacklistedLocally = null;
      _actionError = null;
    }
    if (oldWidget.isTopicPreferred != widget.isTopicPreferred) {
      _preferredLocally = null;
    }
    if (oldWidget.isTopicBlacklisted != widget.isTopicBlacklisted) {
      _blacklistedLocally = null;
    }
  }

  @override
  void dispose() {
    widget.likedPosts.removeListener(_onLikedChanged);
    super.dispose();
  }

  void _onLikedChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleLike() async {
    final userRepo = widget.userRepository;
    if (userRepo == null) {
      setState(() => _actionError = 'Like is unavailable in this preview.');
      return;
    }

    setState(() {
      _isTogglingLike = true;
      _actionError = null;
    });

    try {
      if (_currentlyLiked) {
        await userRepo.deleteLike(_post.id);
        widget.likedPosts.setLiked(_post.id, false);
        widget.onLikeChanged?.call(false);
      } else {
        final viewTime =
            DateTime.now().difference(_appearedAt).inMilliseconds / 1000.0;
        await userRepo.recordInteraction(
          GraphInteractionPayload(
            postId: _post.id,
            type: GraphInteractionType.like,
            viewTime: viewTime < 0 ? 0 : viewTime,
          ),
        );
        widget.likedPosts.setLiked(_post.id, true);
        widget.onLikeChanged?.call(true);
      }
    } on ApiUnauthorized {
      await widget.authSession.signOut();
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingLike = false);
      }
    }
  }

  Future<void> _togglePreferTopic(String topic) async {
    final prefsRepo = widget.preferencesRepository;
    if (prefsRepo == null) {
      setState(() => _actionError = 'Preferences unavailable in this preview.');
      return;
    }

    setState(() {
      _isUpdatingTopicPreference = true;
      _actionError = null;
    });

    try {
      var preferences = (await prefsRepo.getPreferences()).sanitized();
      if (_currentlyPreferred) {
        preferences = preferences.unpreferTopic(topic);
        _preferredLocally = false;
      } else {
        preferences = preferences.preferTopic(topic);
        _preferredLocally = true;
        _blacklistedLocally = false;
      }
      await prefsRepo.updatePreferences(preferences.sanitized().updatePayload);
      widget.onTopicPreferenceChanged?.call();
    } on ApiUnauthorized {
      await widget.authSession.signOut();
    } catch (error) {
      _preferredLocally = null;
      if (mounted) {
        setState(() => _actionError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingTopicPreference = false);
      }
    }
  }

  Future<void> _toggleBlacklistTopic(String topic) async {
    final prefsRepo = widget.preferencesRepository;
    if (prefsRepo == null) {
      setState(() => _actionError = 'Preferences unavailable in this preview.');
      return;
    }

    setState(() {
      _isUpdatingTopicPreference = true;
      _actionError = null;
    });

    try {
      var preferences = (await prefsRepo.getPreferences()).sanitized();
      if (_currentlyBlacklisted) {
        preferences = preferences.unblacklistTopic(topic);
        _blacklistedLocally = false;
      } else {
        preferences = preferences.blacklistTopic(topic);
        _blacklistedLocally = true;
        _preferredLocally = false;
      }
      await prefsRepo.updatePreferences(preferences.sanitized().updatePayload);
      widget.onTopicPreferenceChanged?.call();
    } on ApiUnauthorized {
      await widget.authSession.signOut();
    } catch (error) {
      _blacklistedLocally = null;
      if (mounted) {
        setState(() => _actionError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingTopicPreference = false);
      }
    }
  }

  Future<void> _deletePost() async {
    final postRepo = widget.postRepository;
    if (postRepo == null) {
      setState(() => _actionError = 'Delete is unavailable in this preview.');
      return;
    }

    setState(() {
      _isDeleting = true;
      _actionError = null;
    });

    try {
      await postRepo.deletePost(_post.id);
      widget.likedPosts.setLiked(_post.id, false);
      widget.authSession.showSuccessMessage('Post deleted.');
      widget.onDeleted?.call();
    } on ApiUnauthorized {
      await widget.authSession.signOut();
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _showDeleteConfirmation = false;
        });
      }
    }
  }

  Future<void> _editPost() async {
    final postRepo = widget.postRepository;
    final controller = TextEditingController(text: _post.content);

    final result = await showAdaptiveAlertDialog<String>(
      context: context,
      title: 'Edit post',
      content: isCupertinoPlatform(context)
          ? Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CupertinoTextField(
                controller: controller,
                maxLines: 5,
                autofocus: true,
                placeholder: 'Post content',
                padding: const EdgeInsets.all(12),
              ),
            )
          : Material(
              type: MaterialType.transparency,
              child: TextField(
                controller: controller,
                maxLines: 5,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
      actions: [
        const AdaptiveDialogAction(label: 'Cancel'),
        AdaptiveDialogAction(
          label: 'Save',
          isDefaultAction: true,
          resultBuilder: () => controller.text.trim(),
        ),
      ],
    );

    controller.dispose();

    if (result == null || result.isEmpty || result == _post.content) {
      return;
    }

    if (postRepo == null) {
      // Preview / gallery: surface the edit locally without a network call.
      widget.onEdited?.call(result);
      return;
    }

    setState(() => _actionError = null);
    try {
      await postRepo.updatePost(id: _post.id, content: result);
      widget.onEdited?.call(result);
    } on ApiUnauthorized {
      await widget.authSession.signOut();
    } catch (error) {
      if (mounted) {
        setState(() => _actionError = error.toString());
      }
    }
  }

  Future<void> _showTopicMenu() async {
    final topic = _topicName;
    if (topic == null) return;

    final action = await showAdaptiveActionSheet<_TopicMenuAction>(
      context: context,
      title: KnownTopics.displayName(topic),
      message:
          'Update how Bubbler treats ${KnownTopics.displayName(topic)}.',
      actions: [
        AdaptiveSheetAction(
          label: _currentlyPreferred ? 'Unprefer Topic' : 'Prefer Topic',
          value: _TopicMenuAction.prefer,
          icon: _currentlyPreferred ? Icons.star : Icons.star_border,
        ),
        AdaptiveSheetAction(
          label: _currentlyBlacklisted
              ? 'Unblacklist Topic'
              : 'Blacklist Topic',
          value: _TopicMenuAction.blacklist,
          isDestructive: !_currentlyBlacklisted,
          icon: _currentlyBlacklisted
              ? Icons.visibility
              : Icons.visibility_off,
        ),
      ],
    );

    if (action == _TopicMenuAction.prefer) {
      await _togglePreferTopic(topic);
    } else if (action == _TopicMenuAction.blacklist) {
      await _toggleBlacklistTopic(topic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.isCompact ? 18.0 : 22.0;
    final padding = widget.isCompact ? 12.0 : 16.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _accentColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            topicName: _topicName,
            accentColor: _accentColor,
            createdAt: _post.createdAt,
            isPreferred: _currentlyPreferred,
            isBlacklisted: _currentlyBlacklisted,
            showMenu: _topicName != null,
            menuEnabled: !_isUpdatingTopicPreference,
            onMenu: _showTopicMenu,
          ),
          SizedBox(height: widget.isCompact ? 10 : 12),
          Text(
            _post.content,
            maxLines: widget.isCompact ? 3 : null,
            overflow:
                widget.isCompact ? TextOverflow.ellipsis : TextOverflow.visible,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.isCompact ? 14 : 17,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          SizedBox(height: widget.isCompact ? 10 : 12),
          _AuthorRow(
            label: _post.authorLabel,
            username: _post.username,
            onAuthorTap: widget.onAuthorTap,
          ),
          const SizedBox(height: 10),
          _ActionRow(
            liked: _currentlyLiked,
            isTogglingLike: _isTogglingLike,
            showsSkip: widget.showsSkip,
            onLike: _toggleLike,
            onSkip: widget.onSkip,
          ),
          if (_isOwned) ...[
            const SizedBox(height: 8),
            _OwnerActions(
              isDeleting: _isDeleting,
              onEdit: _editPost,
              onDelete: () => setState(() => _showDeleteConfirmation = true),
            ),
          ],
          if (_actionError != null) ...[
            const SizedBox(height: 8),
            Text(
              _actionError!,
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
          ],
          if (_showDeleteConfirmation) ...[
            const SizedBox(height: 10),
            _DeleteConfirmBanner(
              onConfirm: _deletePost,
              onCancel: () => setState(() => _showDeleteConfirmation = false),
              isDeleting: _isDeleting,
            ),
          ],
        ],
      ),
    );
  }
}
