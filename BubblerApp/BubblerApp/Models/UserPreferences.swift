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

enum FeedPreset: String, Codable, CaseIterable, Identifiable {
    case stayInLane = "stay_in_lane"
    case crossPollinate = "cross_pollinate"
    case wildWalk = "wild_walk"
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stayInLane: return "Stay in lane"
        case .crossPollinate: return "Cross-pollinate"
        case .wildWalk: return "Wild walk"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .stayInLane:
            return "Keep exploring within familiar topics and closely related posts."
        case .crossPollinate:
            return "Jump to different topics while surfacing posts that still feel connected to what you're reading."
        case .wildWalk:
            return "Maximize variety with unexpected topics and posts."
        case .custom:
            return "Your manually tuned topic and post mix (set in Advanced)."
        }
    }

    static let selectablePresets: [FeedPreset] = [.stayInLane, .crossPollinate, .wildWalk]
}

struct CompositionWeights: Codable, Equatable {
    var similar: Double
    var opposite: Double
    var surprise: Double

    static let defaultWeights = CompositionWeights(
        similar: 0.55,
        opposite: 0.15,
        surprise: 0.30
    )

    var total: Double {
        similar + opposite + surprise
    }

    func normalized() -> CompositionWeights {
        let clamped = CompositionWeights(
            similar: similar.clamped(to: 0 ... 1),
            opposite: opposite.clamped(to: 0 ... 1),
            surprise: surprise.clamped(to: 0 ... 1)
        )

        let total = clamped.total
        guard total > 0 else {
            return .defaultWeights
        }

        return CompositionWeights(
            similar: clamped.similar / total,
            opposite: clamped.opposite / total,
            surprise: clamped.surprise / total
        )
    }

    static func presetWeights(for preset: FeedPreset, tier: CompositionTier) -> CompositionWeights {
        switch (preset, tier) {
        case (.stayInLane, _):
            return CompositionWeights(similar: 0.55, opposite: 0.15, surprise: 0.30)
        case (.crossPollinate, .topic):
            return CompositionWeights(similar: 0.15, opposite: 0.55, surprise: 0.30)
        case (.crossPollinate, .post):
            return CompositionWeights(similar: 0.55, opposite: 0.15, surprise: 0.30)
        case (.wildWalk, _):
            return CompositionWeights(similar: 0.15, opposite: 0.25, surprise: 0.60)
        case (.custom, _):
            return .defaultWeights
        }
    }

    enum CompositionTier {
        case topic
        case post
    }

    private static let matchEpsilon = 0.02

    static func matches(_ left: CompositionWeights, _ right: CompositionWeights) -> Bool {
        let a = left.normalized()
        let b = right.normalized()
        return abs(a.similar - b.similar) <= matchEpsilon
            && abs(a.opposite - b.opposite) <= matchEpsilon
            && abs(a.surprise - b.surprise) <= matchEpsilon
    }
}

struct UserPreferences: Codable, Equatable {
    let userId: Int
    var feedPreset: FeedPreset
    var topicComposition: CompositionWeights
    var postComposition: CompositionWeights
    var topicPreferences: [TopicPreference]
    var useViewTime: Bool
    var viewTimeWeight: Double
    var useRecency: Bool
    var aiTopicDetection: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case feedPreset = "feed_preset"
        case topicComposition = "topic_composition"
        case postComposition = "post_composition"
        case topicPreferences = "topic_preferences"
        case useViewTime = "use_view_time"
        case viewTimeWeight = "view_time_weight"
        case useRecency = "use_recency"
        case aiTopicDetection = "ai_topic_detection"
    }

    static let placeholder = systemDefaults(userId: 0)

    static func systemDefaults(userId: Int) -> UserPreferences {
        UserPreferences(
            userId: userId,
            feedPreset: .stayInLane,
            topicComposition: .presetWeights(for: .stayInLane, tier: .topic),
            postComposition: .presetWeights(for: .stayInLane, tier: .post),
            topicPreferences: [],
            useViewTime: false,
            viewTimeWeight: 0.1,
            useRecency: true,
            aiTopicDetection: false
        )
    }

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
            feedPreset: feedPreset,
            topicComposition: topicComposition,
            postComposition: postComposition,
            topicPreferences: topicPreferences,
            useViewTime: useViewTime,
            viewTimeWeight: viewTimeWeight,
            useRecency: useRecency,
            aiTopicDetection: aiTopicDetection
        )
    }

    mutating func applyPreset(_ preset: FeedPreset) {
        guard preset != .custom else {
            feedPreset = .custom
            return
        }
        feedPreset = preset
        topicComposition = .presetWeights(for: preset, tier: .topic)
        postComposition = .presetWeights(for: preset, tier: .post)
    }

    mutating func detectPreset() {
        for preset in FeedPreset.selectablePresets {
            let topic = CompositionWeights.presetWeights(for: preset, tier: .topic)
            let post = CompositionWeights.presetWeights(for: preset, tier: .post)
            if CompositionWeights.matches(topicComposition, topic),
               CompositionWeights.matches(postComposition, post) {
                feedPreset = preset
                return
            }
        }
        feedPreset = .custom
    }

    mutating func updatePreferredTopics(_ topics: [String]) {
        let preferred = TopicPreferenceList.cleaned(topics).map {
            TopicPreference(topic: $0, preferenceType: .preferred)
        }
        let preferredKeys = Set(preferred.map { $0.topic.lowercased() })
        let blacklisted = topicPreferences.filter {
            $0.preferenceType == .blacklisted && !preferredKeys.contains($0.topic.lowercased())
        }
        topicPreferences = Self.mergeTopicPreferences(preferred: preferred, blacklisted: blacklisted)
    }

    mutating func updateBlacklistedTopics(_ topics: [String]) {
        let blacklisted = TopicPreferenceList.cleaned(topics).map {
            TopicPreference(topic: $0, preferenceType: .blacklisted)
        }
        let blacklistedKeys = Set(blacklisted.map { $0.topic.lowercased() })
        let preferred = topicPreferences.filter {
            $0.preferenceType == .preferred && !blacklistedKeys.contains($0.topic.lowercased())
        }
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

        var sanitized = UserPreferences(
            userId: userId,
            feedPreset: feedPreset,
            topicComposition: topicComposition.normalized(),
            postComposition: postComposition.normalized(),
            topicPreferences: Self.mergeTopicPreferences(
                preferred: preferred.map { TopicPreference(topic: $0, preferenceType: .preferred) },
                blacklisted: blacklist.map { TopicPreference(topic: $0, preferenceType: .blacklisted) }
            ),
            useViewTime: useViewTime,
            viewTimeWeight: viewTimeWeight.clamped(to: 0 ... 1),
            useRecency: useRecency,
            aiTopicDetection: aiTopicDetection
        )
        if sanitized.feedPreset != .custom {
            sanitized.applyPreset(sanitized.feedPreset)
        } else {
            sanitized.detectPreset()
        }
        return sanitized
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
    var feedPreset: FeedPreset
    var topicComposition: CompositionWeights
    var postComposition: CompositionWeights
    var topicPreferences: [TopicPreference]
    var useViewTime: Bool
    var viewTimeWeight: Double
    var useRecency: Bool
    var aiTopicDetection: Bool

    enum CodingKeys: String, CodingKey {
        case feedPreset = "feed_preset"
        case topicComposition = "topic_composition"
        case postComposition = "post_composition"
        case topicPreferences = "topic_preferences"
        case useViewTime = "use_view_time"
        case viewTimeWeight = "view_time_weight"
        case useRecency = "use_recency"
        case aiTopicDetection = "ai_topic_detection"
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
