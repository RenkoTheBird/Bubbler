part of 'post_card.dart';

enum _TopicMenuAction { prefer, blacklist }

class _Header extends StatelessWidget {
  const _Header({
    required this.topicName,
    required this.accentColor,
    required this.createdAt,
    required this.isPreferred,
    required this.isBlacklisted,
    required this.showMenu,
    required this.menuEnabled,
    required this.onMenu,
  });

  final String? topicName;
  final Color accentColor;
  final DateTime createdAt;
  final bool isPreferred;
  final bool isBlacklisted;
  final bool showMenu;
  final bool menuEnabled;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: accentColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.8),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          (topicName ?? 'POST').toUpperCase(),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        if (isPreferred) ...[
          const SizedBox(width: 6),
          Icon(Icons.star, size: 12, color: Colors.yellow.withValues(alpha: 0.9)),
        ],
        if (isBlacklisted) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.visibility_off,
            size: 12,
            color: Colors.orange.withValues(alpha: 0.9),
          ),
        ],
        const Spacer(),
        Text(
          formatRelativeTime(createdAt),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
          ),
        ),
        if (showMenu) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: menuEnabled ? onMenu : null,
            tooltip: 'Topic options',
            icon: Icon(
              Icons.more_horiz,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(32, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ],
    );
  }
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.label,
    required this.username,
    required this.onAuthorTap,
  });

  final String label;
  final String? username;
  final ValueChanged<String>? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 12,
    );
    final text = 'Posted by $label';

    if (username != null && username!.isNotEmpty && onAuthorTap != null) {
      return GestureDetector(
        onTap: () => onAuthorTap!(username!),
        child: Text(text, style: style),
      );
    }

    return Text(text, style: style);
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.liked,
    required this.isTogglingLike,
    required this.showsSkip,
    required this.onLike,
    required this.onSkip,
  });

  final bool liked;
  final bool isTogglingLike;
  final bool showsSkip;
  final VoidCallback onLike;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CapsuleButton(
          onPressed: isTogglingLike ? null : onLike,
          foreground: liked ? Colors.pink : Colors.white,
          background: liked
              ? Colors.pink.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.12),
          border: liked
              ? Colors.pink.withValues(alpha: 0.45)
              : Colors.white.withValues(alpha: 0.16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTogglingLike)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: AdaptiveProgressIndicator(
                    strokeWidth: 2,
                    radius: 7,
                    color: Colors.white,
                  ),
                )
              else
                Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  size: 14,
                  color: liked ? Colors.pink : Colors.white,
                ),
              const SizedBox(width: 6),
              Text(
                liked ? 'Liked' : 'Like',
                style: TextStyle(
                  color: liked ? Colors.pink : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (showsSkip) ...[
          const SizedBox(width: 10),
          _CapsuleButton(
            onPressed: onSkip,
            foreground: Colors.white,
            background: Colors.white.withValues(alpha: 0.12),
            border: Colors.white.withValues(alpha: 0.16),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_circle_right_outlined, size: 14),
                SizedBox(width: 6),
                Text(
                  'Skip',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _OwnerActions extends StatelessWidget {
  const _OwnerActions({
    required this.isDeleting,
    required this.onEdit,
    required this.onDelete,
  });

  final bool isDeleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RectButton(
          onPressed: onEdit,
          background: Colors.white.withValues(alpha: 0.14),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit, size: 14, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'Edit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _RectButton(
          onPressed: isDeleting ? null : onDelete,
          background: Colors.red.withValues(alpha: 0.55),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isDeleting)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: AdaptiveProgressIndicator(
                    strokeWidth: 2,
                    radius: 7,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(Icons.delete_outline, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                isDeleting ? 'Deleting...' : 'Delete',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DeleteConfirmBanner extends StatelessWidget {
  const _DeleteConfirmBanner({
    required this.onConfirm,
    required this.onCancel,
    required this.isDeleting,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delete this post?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This permanently removes your post.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              TextButton(
                onPressed: isDeleting ? null : onConfirm,
                child: Text(
                  isDeleting ? 'Deleting...' : 'Delete Post',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
              TextButton(
                onPressed: isDeleting ? null : onCancel,
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CapsuleButton extends StatelessWidget {
  const _CapsuleButton({
    required this.onPressed,
    required this.child,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: IconTheme(
              data: IconThemeData(color: foreground, size: 14),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _RectButton extends StatelessWidget {
  const _RectButton({
    required this.onPressed,
    required this.child,
    required this.background,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ),
    );
  }
}
