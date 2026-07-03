import SwiftUI

struct PostCardView: View {
    let post: Post

    private var topicName: String? {
        guard let topic = post.topic?.trimmingCharacters(in: .whitespacesAndNewlines),
              !topic.isEmpty else {
            return nil
        }
        return topic
    }

    private var accentColor: Color {
        guard let topicName else { return .white }

        switch topicName.lowercased() {
        case "tech", "technology", "ai":
            return .blue
        case "space", "science":
            return .purple
        case "sports":
            return .green
        case "music":
            return .orange
        default:
            return .cyan
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: accentColor.opacity(0.8), radius: 6)

                    Text((topicName ?? "POST").uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.85))
                        .tracking(1)
                }

                Spacer()

                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }

            Text(post.content)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)

            Text("Posted by user #\(post.userId)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.10))

                RoundedRectangle(cornerRadius: 22)
                    .stroke(accentColor.opacity(0.25), lineWidth: 1)

                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        )
        .shadow(color: accentColor.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [
                Color.blue.opacity(0.9),
                Color.cyan.opacity(0.55),
                Color.indigo.opacity(0.9),
                Color.black.opacity(0.3),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        PostCardView(
            post: Post(
                id: "preview-post",
                userId: 0,
                content: "",
                createdAt: .now.addingTimeInterval(-2_700),
                topic: nil,
                embedding: nil
            )
        )
        .padding()
        .redacted(reason: .placeholder)
    }
}