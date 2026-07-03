//
//  UserPreferences.swift
//  BubblerApp
//

import Foundation

struct UserPreferences: Codable, Equatable {
    let userId: Int
    var diversityTolerance: Double
    var randomness: Double
    var preferredTopics: [String]
    var blacklistedTopics: [String]
    var useViewTime: Bool
    var viewTimeWeight: Double
    var strategyWeights: FeedStrategyWeights

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case diversityTolerance = "diversity_tolerance"
        case randomness
        case preferredTopics = "preferred_topics"
        case blacklistedTopics = "blacklisted_topics"
        case useViewTime = "use_view_time"
        case viewTimeWeight = "view_time_weight"
        case strategyWeights = "strategy_weights"
    }

    static let placeholder = UserPreferences(
        userId: 0,
        diversityTolerance: 0.4,
        randomness: 0.3,
        preferredTopics: [],
        blacklistedTopics: [],
        useViewTime: false,
        viewTimeWeight: 0.1,
        strategyWeights: .default
    )

    var updatePayload: PreferencesUpdatePayload {
        PreferencesUpdatePayload(
            diversityTolerance: diversityTolerance,
            randomness: randomness,
            preferredTopics: preferredTopics,
            blacklistedTopics: blacklistedTopics,
            useViewTime: useViewTime,
            viewTimeWeight: viewTimeWeight,
            strategyWeights: strategyWeights
        )
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
            preferredTopics: preferred,
            blacklistedTopics: blacklist,
            useViewTime: useViewTime,
            viewTimeWeight: viewTimeWeight.clamped(to: 0 ... 1),
            strategyWeights: strategyWeights.normalized()
        )
    }
}

struct PreferencesUpdatePayload: Codable {
    var diversityTolerance: Double
    var randomness: Double
    var preferredTopics: [String]
    var blacklistedTopics: [String]
    var useViewTime: Bool
    var viewTimeWeight: Double
    var strategyWeights: FeedStrategyWeights

    enum CodingKeys: String, CodingKey {
        case diversityTolerance = "diversity_tolerance"
        case randomness
        case preferredTopics = "preferred_topics"
        case blacklistedTopics = "blacklisted_topics"
        case useViewTime = "use_view_time"
        case viewTimeWeight = "view_time_weight"
        case strategyWeights = "strategy_weights"
    }
}

struct FeedStrategyWeights: Codable, Equatable {
    var similar: Double
    var graph: Double
    var opposite: Double
    var random: Double

    static let `default` = FeedStrategyWeights(
        similar: 0.7,
        graph: 0.2,
        opposite: 0.0,
        random: 0.1
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
