import SwiftUI

struct TopicPicker: View {
    @Binding var selectedTopic: String

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Topic")
                .font(.headline)
                .foregroundColor(.white)

            Text("Choose the bubble this post belongs to.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.65))

            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                ForEach(KnownTopics.all, id: \.self) { topic in
                    topicChip(topic)
                }
            }
        }
    }

    private func topicChip(_ topic: String) -> some View {
        let isSelected = selectedTopic.caseInsensitiveCompare(topic) == .orderedSame
        let color = TopicStyle.color(for: topic)

        return Button {
            selectedTopic = topic
        } label: {
            HStack(spacing: 6) {
                Image(systemName: TopicStyle.icon(for: topic))
                    .font(.caption)

                Text(KnownTopics.displayName(for: topic))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.35) : Color.white.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(
                        isSelected ? color.opacity(0.7) : Color.white.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

enum TopicStyle {
    static func icon(for topic: String) -> String {
        switch topic.lowercased() {
        case "technology":
            return "desktopcomputer"
        case "science":
            return "globe.americas.fill"
        case "sports":
            return "basketball.fill"
        case "politics":
            return "building.columns.fill"
        case "entertainment":
            return "film.fill"
        case "business":
            return "briefcase.fill"
        case "health":
            return "heart.fill"
        case "education":
            return "book.fill"
        case "environment":
            return "leaf.fill"
        default:
            return "circle.grid.2x2.fill"
        }
    }

    static func color(for topic: String) -> Color {
        switch topic.lowercased() {
        case "technology":
            return .blue
        case "science":
            return .purple
        case "sports":
            return .green
        case "politics":
            return .red
        case "entertainment":
            return .pink
        case "business":
            return .indigo
        case "health":
            return .mint
        case "education":
            return .orange
        case "environment":
            return .teal
        default:
            return .cyan
        }
    }
}
