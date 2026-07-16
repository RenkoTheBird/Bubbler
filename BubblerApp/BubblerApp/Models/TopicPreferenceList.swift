//
//  TopicPreferenceList.swift
//  BubblerApp
//

import Foundation

enum TopicPreferenceList {
    static func cleaned(_ topics: [String]) -> [String] {
        var seen = Set<String>()

        return topics
            .map { normalizedTopic(from: $0) }
            .filter { !$0.isEmpty }
            .filter { topic in
                seen.insert(topic.lowercased()).inserted
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    static func add(_ rawTopic: String, to topics: [String]) -> [String] {
        guard let topic = KnownTopics.resolve(rawTopic) else {
            return cleaned(topics)
        }

        var updatedTopics = cleaned(topics)
        guard !updatedTopics.contains(where: { $0.caseInsensitiveCompare(topic) == .orderedSame }) else {
            return updatedTopics
        }

        updatedTopics.append(topic)
        return cleaned(updatedTopics)
    }

    static func remove(_ rawTopic: String, from topics: [String]) -> [String] {
        let topic = normalizedTopic(from: rawTopic)
        return cleaned(topics).filter { $0.caseInsensitiveCompare(topic) != .orderedSame }
    }

    static func normalizedTopic(from value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: "")
    }
}
