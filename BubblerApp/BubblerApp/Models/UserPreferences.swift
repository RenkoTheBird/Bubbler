//
//  UserPreferences.swift
//  BubblerApp
//

import Foundation

struct TopicPreference: Codable, Equatable {
    var topic: String
    var preferenceType: PreferenceType

    enum PreferenceType: String, Codable {
        case preferred
        case blacklisted
    }

    enum CodingKeys: String, CodingKey {
        case topic
        case preferenceType = "preference_type"
    }
}

struct UserPreferences: Codable, Equatable {
    let userId: Int
    var diversityTolerance: Double
    var randomness: Double
    var topicPreferences: [TopicPreference]
    var useViewTime: Bool
    var viewTimeWeight: Double
    var useRecency: Bool
    var aiTopicDetection: Bool
    var strategyWeights: FeedStrategyWeights

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case diversityTolerance = "diversity_tolerance"
        case randomness
        case topicPreferences = "topic_preferences"
        case useViewTime = "use_view_time"
        case viewTimeWeight = "view_time_weight"
        case useRecency = "use_recency"
        case aiTopicDetection = "ai_topic_detection"
        case strategyWeights = "strategy_weights"
    }

    static let placeholder = UserPreferences(
        userId: 0,
        diversityTolerance: 0.4,
        randomness: 0.4,
        topicPreferences: [],
        useViewTime: false,
        viewTimeWeight: 0.1,
        useRecency: true,
        aiTopicDetection: false,
        strategyWeights: .default
    )

    var preferredTopics: [String] {
        topicPreferences
            .filter { $0.preferenceType == .preferred }
            .map(\.topic)
    }

    var blacklistedTopics: [String] {
        topicPreferences
            .filter { $0.preferenceType == .blacklisted }
            .map(\.topic)
    }

    var updatePayload: PreferencesUpdatePayload {
        PreferencesUpdatePayload(
            diversityTolerance: diversityTolerance,
            randomness: randomness,
            topicPreferences: topicPreferences,
            useViewTime: useViewTime,
            viewTimeWeight: viewTimeWeight,
            useRecency: useRecency,
            aiTopicDetection: aiTopicDetection,
            strategyWeights: strategyWeights
        )
    }

    mutating func updatePreferredTopics(_ topics: [String]) {
        let preferred = TopicPreferenceList.cleaned(topics).map {
            TopicPreference(topic: $0, preferenceType: .preferred)
        }
        let blacklisted = topicPreferences.filter { $0.preferenceType == .blacklisted }
        topicPreferences = Self.mergeTopicPreferences(preferred: preferred, blacklisted: blacklisted)
    }

    mutating func updateBlacklistedTopics(_ topics: [String]) {
        let blacklisted = TopicPreferenceList.cleaned(topics).map {
            TopicPreference(topic: $0, preferenceType: .blacklisted)
        }
        let preferred = topicPreferences.filter { $0.preferenceType == .preferred }
        topicPreferences = Self.mergeTopicPreferences(preferred: preferred, blacklisted: blacklisted)
    }

    mutating func preferTopic(_ topic: String) {
        updatePreferredTopics(TopicPreferenceList.add(topic, to: preferredTopics))
        updateBlacklistedTopics(TopicPreferenceList.remove(topic, from: blacklistedTopics))
    }

    mutating func unpreferTopic(_ topic: String) {
        updatePreferredTopics(TopicPreferenceList.remove(topic, from: preferredTopics))
    }

    mutating func blacklistTopic(_ topic: String) {
        updatePreferredTopics(TopicPreferenceList.remove(topic, from: preferredTopics))
        updateBlacklistedTopics(TopicPreferenceList.add(topic, to: blacklistedTopics))
    }

    mutating func unblacklistTopic(_ topic: String) {
        updateBlacklistedTopics(TopicPreferenceList.remove(topic, from: blacklistedTopics))
    }

    func sanitized() -> UserPreferences {
        let preferred = TopicPreferenceList.cleaned(preferredTopics)
        let blacklist = TopicPreferenceList.cleaned(blacklistedTopics)
            .filter { blacklistedTopic in
                !preferred.contains(where: { $0.caseInsensitiveCompare(blacklistedTopic) == .orderedSame })
            }

        return UserPreferences(
            userId: userId,
            diversityTolerance: diversityTolerance.clamped(to: 0 ... 1),
            randomness: randomness.clamped(to: 0 ... 1),
            topicPreferences: Self.mergeTopicPreferences(
                preferred: preferred.map { TopicPreference(topic: $0, preferenceType: .preferred) },
                blacklisted: blacklist.map { TopicPreference(topic: $0, preferenceType: .blacklisted) }
            ),
            useViewTime: useViewTime,
            viewTimeWeight: viewTimeWeight.clamped(to: 0 ... 1),
            useRecency: useRecency,
            aiTopicDetection: aiTopicDetection,
            strategyWeights: strategyWeights.normalized()
        )
    }

    private static func mergeTopicPreferences(
        preferred: [TopicPreference],
        blacklisted: [TopicPreference]
    ) -> [TopicPreference] {
        var seen = Set<String>()
        var merged: [TopicPreference] = []

        for pref in preferred + blacklisted {
            let key = pref.topic.lowercased()
            guard seen.insert(key).inserted else {
                continue
            }
            merged.append(pref)
        }

        return merged.sorted {
            $0.topic.localizedCaseInsensitiveCompare($1.topic) == .orderedAscending
        }
    }
}

struct PreferencesUpdatePayload: Codable {
    var diversityTolerance: Double
    var randomness: Double
    var topicPreferences: [TopicPreference]
    var useViewTime: Bool
    var viewTimeWeight: Double
    var useRecency: Bool
    var aiTopicDetection: Bool
    var strategyWeights: FeedStrategyWeights

    enum CodingKeys: String, CodingKey {
        case diversityTolerance = "diversity_tolerance"
        case randomness
        case topicPreferences = "topic_preferences"
        case useViewTime = "use_view_time"
        case viewTimeWeight = "view_time_weight"
        case useRecency = "use_recency"
        case aiTopicDetection = "ai_topic_detection"
        case strategyWeights = "strategy_weights"
    }
}

struct FeedStrategyWeights: Codable, Equatable {
    var similar: Double
    var graph: Double
    var opposite: Double
    var random: Double

    static let `default` = FeedStrategyWeights(
        similar: 0.4,
        graph: 0.25,
        opposite: 0.2,
        random: 0.15
    )

    var total: Double {
        similar + graph + opposite + random
    }

    func normalized() -> FeedStrategyWeights {
        let clamped = FeedStrategyWeights(
            similar: similar.clamped(to: 0 ... 1),
            graph: graph.clamped(to: 0 ... 1),
            opposite: opposite.clamped(to: 0 ... 1),
            random: random.clamped(to: 0 ... 1)
        )

        let total = clamped.total
        guard total > 0 else {
            return .default
        }

        return FeedStrategyWeights(
            similar: clamped.similar / total,
            graph: clamped.graph / total,
            opposite: clamped.opposite / total,
            random: clamped.random / total
        )
    }

    init(similar: Double, graph: Double, opposite: Double, random: Double) {
        self.similar = similar
        self.graph = graph
        self.opposite = opposite
        self.random = random
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dictionary = try container.decode([String: Double].self)

        similar = dictionary["similar"] ?? FeedStrategyWeights.default.similar
        graph = dictionary["graph"] ?? FeedStrategyWeights.default.graph
        opposite = dictionary["opposite"] ?? FeedStrategyWeights.default.opposite
        random = dictionary["random"] ?? FeedStrategyWeights.default.random
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(
            [
                "similar": similar,
                "graph": graph,
                "opposite": opposite,
                "random": random,
            ]
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
