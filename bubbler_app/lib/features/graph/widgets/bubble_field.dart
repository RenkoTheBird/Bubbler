import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/graph.dart';
import 'neighbor_bubble.dart';

/// Polar layout of up to four neighbor bubbles — extracted from Swift
/// `GraphFeedView.bubbleField` / `bubbleAngle(for:total:)`.
class BubbleField extends StatelessWidget {
  const BubbleField({
    super.key,
    required this.choices,
    required this.onBubbleTap,
    this.enabled = true,
    this.maxBubbles = 4,
  });

  final List<GraphFeedNode> choices;
  final ValueChanged<GraphFeedNode> onBubbleTap;
  final bool enabled;

  /// Matches the Swift hard cap of four visible neighbors.
  final int maxBubbles;

  /// Angle (radians) for bubble [index] of [total], starting at the top
  /// (`-π/2`) and spacing evenly clockwise.
  static double bubbleAngle({required int index, required int total}) {
    if (total <= 0) return 0;
    const start = -math.pi / 2;
    return start + (index / total) * (2 * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final visible = choices.take(maxBubbles).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final fieldWidth = constraints.maxWidth;
        final fieldHeight = constraints.maxHeight;
        final size = math.min(fieldWidth, fieldHeight);
        final radius = size * 0.32;
        final bubbleSize = math.min(96.0, size * 0.28);
        final center = Offset(fieldWidth / 2, fieldHeight / 2);
        final total = visible.length;

        return Stack(
          children: [
            for (var index = 0; index < total; index++)
              _positionedBubble(
                node: visible[index],
                index: index,
                total: total,
                center: center,
                radius: radius,
                bubbleSize: bubbleSize,
              ),
          ],
        );
      },
    );
  }

  Widget _positionedBubble({
    required GraphFeedNode node,
    required int index,
    required int total,
    required Offset center,
    required double radius,
    required double bubbleSize,
  }) {
    final angle = bubbleAngle(index: index, total: total);
    final offset = Offset(
      math.cos(angle) * radius,
      math.sin(angle) * radius,
    );
    final topLeft = Offset(
      center.dx + offset.dx - bubbleSize / 2,
      center.dy + offset.dy - bubbleSize / 2,
    );

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      child: IgnorePointer(
        ignoring: !enabled,
        child: NeighborBubble(
          node: node,
          size: bubbleSize,
          onTap: () => onBubbleTap(node),
        ),
      ),
    );
  }
}
