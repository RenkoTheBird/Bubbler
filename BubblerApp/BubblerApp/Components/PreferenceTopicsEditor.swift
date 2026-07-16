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
    @State private var errorMessage: String?

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

    private var matchingTopics: [String] {
        KnownTopics.matching(draft, excluding: topics)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)

                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }

            searchField

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.red.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                suggestionResults
            }

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

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(iconColor.opacity(0.9))

            TextField("Search existing topics...", text: $draft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit(addTopic)
                .onChange(of: draft) { _, _ in
                    errorMessage = nil
                }
                .foregroundColor(.white)

            if !draft.isEmpty {
                Button {
                    draft = ""
                    errorMessage = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.55))
                }
                .accessibilityLabel("Clear topic search")
            }

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
    }

    @ViewBuilder
    private var suggestionResults: some View {
        if matchingTopics.isEmpty {
            Text("No existing topics match \"\(draft.trimmingCharacters(in: .whitespacesAndNewlines))\".")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(spacing: 8) {
                ForEach(matchingTopics, id: \.self) { topic in
                    Button {
                        selectTopic(topic)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: TopicStyle.icon(for: topic))
                                .foregroundColor(TopicStyle.color(for: topic))
                                .frame(width: 18)

                            Text(KnownTopics.displayName(for: topic))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.white.opacity(0.55))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func addTopic() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = nil
            return
        }

        guard let topic = KnownTopics.resolve(trimmed) else {
            errorMessage = "Unknown topic: \"\(trimmed)\". Choose one from the list of existing topics."
            return
        }

        selectTopic(topic)
    }

    private func selectTopic(_ topic: String) {
        guard let resolved = KnownTopics.resolve(topic) else {
            errorMessage = "Unknown topic: \"\(topic)\". Choose one from the list of existing topics."
            return
        }

        // Clear the other list first so preferred → blacklisted doesn't get
        // dropped by merge (preferred wins when both are present).
        if let conflictingTopics {
            conflictingTopics.wrappedValue = TopicPreferenceList.remove(
                resolved,
                from: conflictingTopics.wrappedValue
            )
        }
        topics = TopicPreferenceList.add(resolved, to: topics)
        draft = ""
        errorMessage = nil
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
                    Text(KnownTopics.displayName(for: topic))
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
