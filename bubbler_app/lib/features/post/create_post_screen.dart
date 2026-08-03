import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/auth/auth_session.dart';
import '../../data/models/post.dart';
import '../../data/repositories/post_repository.dart';
import '../../shared/platform/platform.dart';
import '../../shared/theme/topic_style.dart';
import '../../shared/widgets/status_banner.dart';
import '../../shared/widgets/topic_picker.dart';
import 'create_post_controller.dart';

/// Create / edit post form — Swift `CreatePostView`.
///
/// Pops with the published/updated content string on success.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({
    super.key,
    required this.authSession,
    required this.postRepository,
    this.post,
    this.onSuccess,
  });

  final AuthSession authSession;
  final PostRepository postRepository;

  /// When non-null, opens in edit mode (Swift `CreatePostView(post:)`).
  final Post? post;

  /// Optional side-effect after a successful submit (before pop).
  final ValueChanged<String>? onSuccess;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  late final CreatePostController _controller;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _controller = CreatePostController(
      authSession: widget.authSession,
      postRepository: widget.postRepository,
      post: widget.post,
    );
    _contentController = TextEditingController(text: _controller.content);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    final content = await _controller.submit();
    if (!mounted || content == null) return;
    widget.onSuccess?.call(content);
    Navigator.of(context).pop(content);
  }

  @override
  Widget build(BuildContext context) {
    final cupertino = isCupertinoPlatform(context);
    final accent = TopicStyle.color(_controller.selectedTopic);
    final title = _controller.isEditing ? 'Edit Post' : 'New Post';

    final body = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.75),
            Colors.black.withValues(alpha: 0.7),
            Colors.black.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Text(
              _controller.isEditing ? 'Edit Bubble' : 'Share a Bubble',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _controller.isEditing
                  ? 'Update your post content or topic.'
                  : 'Write your post and pick a topic for the feed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Content',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _contentController,
              onChanged: _controller.setContent,
              maxLines: 8,
              minLines: 5,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'What\'s on your mind?',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 24),
            TopicPicker(
              selectedTopic: _controller.selectedTopic,
              onChanged: _controller.setSelectedTopic,
            ),
            if (_controller.errorMessage != null) ...[
              const SizedBox(height: 16),
              StatusBanner.error(_controller.errorMessage!),
            ],
            const SizedBox(height: 24),
            _SubmitButton(
              accent: accent,
              enabled: _controller.canSubmit,
              isSubmitting: _controller.isSubmitting,
              isEditing: _controller.isEditing,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );

    if (cupertino) {
      return CupertinoPageScaffold(
        backgroundColor: Colors.transparent,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: Colors.black.withValues(alpha: 0.55),
          border: null,
          middle: Text(title, style: const TextStyle(color: Colors.white)),
        ),
        child: Material(type: MaterialType.transparency, child: body),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black.withValues(alpha: 0.35),
      ),
      body: body,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.accent,
    required this.enabled,
    required this.isSubmitting,
    required this.isEditing,
    required this.onPressed,
  });

  final Color accent;
  final bool enabled;
  final bool isSubmitting;
  final bool isEditing;
  final VoidCallback onPressed;

  String get _title {
    if (isSubmitting) {
      return isEditing ? 'Saving...' : 'Posting...';
    }
    return isEditing ? 'Save Changes' : 'Post to Bubbler';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.85)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSubmitting) ...[
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: AdaptiveProgressIndicator(
                      strokeWidth: 2,
                      radius: 9,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
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
