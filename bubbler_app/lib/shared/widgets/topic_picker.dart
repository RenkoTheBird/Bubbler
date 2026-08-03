import 'package:flutter/material.dart';

import '../../data/models/topics.dart';
import '../theme/topic_style.dart';

/// Topic chip grid for create/edit post — Swift `TopicPicker`.
class TopicPicker extends StatelessWidget {
  const TopicPicker({
    super.key,
    required this.selectedTopic,
    required this.onChanged,
  });

  final String selectedTopic;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Topic',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose the bubble this post belongs to.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final topic in KnownTopics.all)
                  SizedBox(
                    width: _chipWidth(constraints.maxWidth),
                    child: _TopicChip(
                      topic: topic,
                      selected: selectedTopic.toLowerCase() == topic.toLowerCase(),
                      onTap: () => onChanged(topic),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  double _chipWidth(double maxWidth) {
    // Adaptive columns ≈ Swift `GridItem(.adaptive(minimum: 110))`.
    const minWidth = 110.0;
    const spacing = 10.0;
    final columns = ((maxWidth + spacing) / (minWidth + spacing)).floor().clamp(1, 4);
    return (maxWidth - spacing * (columns - 1)) / columns;
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({
    required this.topic,
    required this.selected,
    required this.onTap,
  });

  final String topic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = TopicStyle.color(topic);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(TopicStyle.icon(topic), size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    KnownTopics.displayName(topic),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
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
