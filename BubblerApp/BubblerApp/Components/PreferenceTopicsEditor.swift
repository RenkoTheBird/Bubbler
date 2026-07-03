//
//  PreferenceTopicsEditor.swift
//  BubblerApp
//

import SwiftUI

struct PreferenceTopicsEditor: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    @Binding var topics: [String]

    private let conflictingTopics: Binding<[String]>?

    @State private var draft = ""

    init(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        topics: Binding<[String]>,
        conflictingTopics: Binding<[String]>? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        _topics = topics
        self.conflictingTopics = conflictingTopics
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }

            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)

                TextField("Add a topic", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit(addTopic)
                    .foregroundColor(.white)

                Button("Add", action: addTopic)
                    .foregroundColor(.white)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )

            if topics.isEmpty {
                Text("No topics added yet.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TopicChipGrid(topics: topics, onRemove: removeTopic)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func addTopic() {
        let topic = TopicPreferenceList.normalizedTopic(from: draft)
        guard !topic.isEmpty else { return }

        topics = TopicPreferenceList.add(topic, to: topics)
        if let conflictingTopics {
            conflictingTopics.wrappedValue = TopicPreferenceList.remove(topic, from: conflictingTopics.wrappedValue)
        }
        draft = ""
    }

    private func removeTopic(_ topic: String) {
        topics = TopicPreferenceList.remove(topic, from: topics)
    }
}

private struct TopicChipGrid: View {
    let topics: [String]
    let onRemove: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(topics, id: \.self) { topic in
                HStack(spacing: 8) {
                    Text(topic)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Button {
                        onRemove(topic)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.1))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }
}
