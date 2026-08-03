import 'dart:math' as math;

import 'package:bubbler_app/data/models/graph.dart';
import 'package:bubbler_app/data/models/post.dart';
import 'package:bubbler_app/features/graph/widgets/bubble_field.dart';
import 'package:bubbler_app/features/graph/widgets/neighbor_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GraphFeedNode _node({
  required String id,
  String topic = 'technology',
  bool preferred = false,
}) {
  return GraphFeedNode(
    post: Post(
      id: id,
      userId: 1,
      content: 'Post $id',
      createdAt: DateTime.utc(2026, 1, 1),
      topic: topic,
    ),
    isPreferredTopic: preferred,
  );
}

void main() {
  group('BubbleField.bubbleAngle', () {
    test('returns 0 when total is non-positive', () {
      expect(BubbleField.bubbleAngle(index: 0, total: 0), 0);
      expect(BubbleField.bubbleAngle(index: 0, total: -1), 0);
    });

    test('starts at the top (-π/2) for the first bubble', () {
      expect(
        BubbleField.bubbleAngle(index: 0, total: 4),
        closeTo(-math.pi / 2, 1e-9),
      );
    });

    test('spaces four bubbles evenly around the circle', () {
      final angles = [
        for (var i = 0; i < 4; i++) BubbleField.bubbleAngle(index: i, total: 4),
      ];
      expect(angles[0], closeTo(-math.pi / 2, 1e-9));
      expect(angles[1], closeTo(0, 1e-9));
      expect(angles[2], closeTo(math.pi / 2, 1e-9));
      expect(angles[3], closeTo(math.pi, 1e-9));
    });

    test('spaces a single bubble at the top', () {
      expect(
        BubbleField.bubbleAngle(index: 0, total: 1),
        closeTo(-math.pi / 2, 1e-9),
      );
    });
  });

  testWidgets('renders at most four NeighborBubbles', (tester) async {
    final choices = [
      _node(id: '1', topic: 'technology'),
      _node(id: '2', topic: 'science'),
      _node(id: '3', topic: 'sports'),
      _node(id: '4', topic: 'health', preferred: true),
      _node(id: '5', topic: 'business'),
    ];
    GraphFeedNode? tapped;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 400,
            child: BubbleField(
              choices: choices,
              onBubbleTap: (node) => tapped = node,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(NeighborBubble), findsNWidgets(4));
    expect(find.text('Technology'), findsOneWidget);
    expect(find.text('Science'), findsOneWidget);
    expect(find.text('Sports'), findsOneWidget);
    expect(find.text('Health'), findsOneWidget);
    expect(find.text('Business'), findsNothing);

    await tester.tap(find.text('Science'));
    await tester.pump();
    expect(tapped?.id, '2');
  });

  testWidgets('shows preferred-topic star badge', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NeighborBubble(
              node: _node(id: 'p', preferred: true),
              size: 96,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(
      find.bySemanticsLabel('Technology bubble, preferred topic'),
      findsOneWidget,
    );
  });
}
