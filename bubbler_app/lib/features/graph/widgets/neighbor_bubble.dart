import 'package:flutter/material.dart';

import '../../../data/models/graph.dart';
import '../../../data/models/topics.dart';
import '../../../shared/theme/topic_style.dart';

/// A single neighbor choice bubble — Swift `GraphNeighborBubble`.
class NeighborBubble extends StatelessWidget {
  const NeighborBubble({
    super.key,
    required this.node,
    required this.size,
    required this.onTap,
  });

  final GraphFeedNode node;
  final double size;
  final VoidCallback onTap;

  String get _topic => node.topicName ?? 'topic';

  @override
  Widget build(BuildContext context) {
    final color = TopicStyle.color(_topic);
    final displayName = KnownTopics.displayName(_topic);

    return Semantics(
      button: true,
      label:
          '$displayName bubble${node.isPreferredTopic ? ', preferred topic' : ''}',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.6, -0.6),
                        radius: 0.95,
                        colors: [
                          color.withValues(alpha: 0.95),
                          color.withValues(alpha: 0.55),
                          color.withValues(alpha: 0.25),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const SizedBox.expand(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          TopicStyle.icon(_topic),
                          size: size * 0.22,
                          color: Colors.white,
                        ),
                        SizedBox(height: size * 0.06),
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: (size * 0.11).clamp(10.0, 18.0),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (node.isPreferredTopic)
                    Positioned(
                      top: size * 0.08,
                      right: size * 0.08,
                      child: Container(
                        padding: EdgeInsets.all(size * 0.07),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                        child: Icon(
                          Icons.star,
                          size: (size * 0.13).clamp(10.0, 20.0),
                          color: Colors.yellow.withValues(alpha: 0.9),
                        ),
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
