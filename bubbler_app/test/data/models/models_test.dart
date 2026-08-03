import 'package:bubbler_app/data/models/blocked_user.dart';
import 'package:bubbler_app/data/models/graph.dart';
import 'package:bubbler_app/data/models/interaction.dart';
import 'package:bubbler_app/data/models/post.dart';
import 'package:bubbler_app/data/models/preferences.dart';
import 'package:bubbler_app/data/models/search.dart';
import 'package:bubbler_app/data/models/topics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Post', () {
    test('fromJson decodes snake_case payload', () {
      final post = Post.fromJson({
        'id': 'post-1',
        'user_id': 42,
        'username': 'alice',
        'content': 'Hello world',
        'created_at': '2024-06-15T12:00:00Z',
        'topic': 'technology',
        'embedding': [0.1, 0.2],
      });

      expect(post.id, 'post-1');
      expect(post.userId, 42);
      expect(post.username, 'alice');
      expect(post.content, 'Hello world');
      expect(post.topic, 'technology');
      expect(post.embedding, [0.1, 0.2]);
      expect(post.authorLabel, '@alice');
      expect(post.createdAt.isUtc, isTrue);
    });

    test('authorLabel falls back to user id', () {
      final post = Post.fromJson({
        'id': 'post-2',
        'user_id': 7,
        'content': 'x',
        'created_at': '2024-01-01T00:00:00Z',
      });
      expect(post.authorLabel, 'user #7');
    });
  });

  group('Interaction', () {
    test('fromJson and trailSummary', () {
      final interaction = Interaction.fromJson({
        'id': 'int-1',
        'user_id': '42',
        'post_id': 'post-1',
        'type': 'like',
        'created_at': '2024-06-15T12:00:00Z',
        'topic': 'science',
        'view_time': 3.5,
        'liked': true,
      });

      expect(interaction.type, GraphInteractionType.like);
      expect(interaction.userId, '42');
      expect(interaction.viewTime, 3.5);
      expect(interaction.trailSummary, 'Liked a Science post');
    });
  });

  group('GraphSessionFeed', () {
    test('fromJson and statusLabel', () {
      final session = GraphSessionFeed.fromJson({
        'posts': [
          {
            'id': 'p1',
            'user_id': 1,
            'content': 'a',
            'created_at': '2024-01-01T00:00:00Z',
            'topic': 'sports',
          },
        ],
        'seed_strategy': 'soft_prior',
        'diversify': false,
      });

      expect(session.posts, hasLength(1));
      expect(session.seedStrategy, 'soft_prior');
      expect(session.diversify, isFalse);
      expect(session.statusLabel, 'Seeded from recent interests');
    });

    test('GraphInteractionPayload round-trips', () {
      const payload = GraphInteractionPayload(
        postId: 'p1',
        type: GraphInteractionType.skip,
        viewTime: 1.25,
      );
      final decoded = GraphInteractionPayload.fromJson(payload.toJson());
      expect(decoded.postId, 'p1');
      expect(decoded.type, GraphInteractionType.skip);
      expect(decoded.viewTime, 1.25);
    });
  });

  group('UserPreferences', () {
    test('fromJson decodes nested strategy weights and topic prefs', () {
      final prefs = UserPreferences.fromJson({
        'user_id': 9,
        'diversity_tolerance': 0.5,
        'randomness': 0.3,
        'topic_preferences': [
          {'topic': 'science', 'preference_type': 'preferred'},
          {'topic': 'politics', 'preference_type': 'blacklisted'},
        ],
        'use_view_time': true,
        'view_time_weight': 0.2,
        'use_recency': false,
        'ai_topic_detection': true,
        'strategy_weights': {
          'similar': 0.5,
          'graph': 0.2,
          'opposite': 0.2,
          'random': 0.1,
        },
      });

      expect(prefs.userId, 9);
      expect(prefs.preferredTopics, ['science']);
      expect(prefs.blacklistedTopics, ['politics']);
      expect(prefs.strategyWeights.similar, 0.5);
      expect(prefs.useViewTime, isTrue);
    });

    test('preferTopic clears blacklist and sanitizes weights', () {
      var prefs = UserPreferences.systemDefaults(userId: 1)
          .blacklistTopic('science')
          .preferTopic('science');

      expect(prefs.preferredTopics, ['science']);
      expect(prefs.blacklistedTopics, isEmpty);

      prefs = prefs.copyWith(
        strategyWeights: const FeedStrategyWeights(
          similar: 2,
          graph: 2,
          opposite: 0,
          random: 0,
        ),
      ).sanitized();

      expect(prefs.strategyWeights.similar, closeTo(0.5, 1e-9));
      expect(prefs.strategyWeights.graph, closeTo(0.5, 1e-9));
    });
  });

  group('SearchResponse', () {
    test('fromJson splits exact and related', () {
      final response = SearchResponse.fromJson({
        'query': 'hello',
        'exact_matches': [
          {
            'id': 'e1',
            'user_id': 1,
            'content': 'hello there',
            'created_at': '2024-01-01T00:00:00Z',
          },
        ],
        'related': [],
      });

      expect(response.query, 'hello');
      expect(response.exactMatches, hasLength(1));
      expect(response.isEmpty, isFalse);
    });
  });

  group('KnownTopics / TopicPreferenceList', () {
    test('resolve and cleaned helpers', () {
      expect(KnownTopics.resolve('Science'), 'science');
      expect(KnownTopics.resolve('unknown'), isNull);
      expect(
        TopicPreferenceList.cleaned([' Science ', 'science', '', 'Sports']),
        ['Science', 'Sports'],
      );
      expect(
        TopicPreferenceList.add('technology', ['science']),
        ['science', 'technology'],
      );
    });
  });

  group('BlockedUser', () {
    test('fromJson decodes blocked_at', () {
      final blocked = BlockedUser.fromJson({
        'id': 3,
        'username': 'bob',
        'blocked_at': '2024-03-01T08:30:00Z',
      });

      expect(blocked.id, 3);
      expect(blocked.username, 'bob');
      expect(blocked.blockedAt.toUtc().toIso8601String(), '2024-03-01T08:30:00.000Z');
    });
  });
}
