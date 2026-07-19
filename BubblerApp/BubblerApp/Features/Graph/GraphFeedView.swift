import SwiftUI

struct GraphFeedView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = GraphFeedViewModel()
    @State private var previewedChoice: GraphFeedNode?

    var body: some View {
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

            VStack(spacing: 12) {
                topChrome

                if let statusMessage = viewModel.statusMessage {
                    banner(statusMessage, tint: Color.cyan.opacity(0.85))
                }

                if let errorMessage = viewModel.errorMessage {
                    banner(errorMessage, tint: .red.opacity(0.8))
                }

                middleSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                stickyCurrentPost
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: authSession.accessToken) {
            await viewModel.load(using: authSession)
        }
        .onChange(of: viewModel.currentNode?.id) { _, _ in
            previewedChoice = nil
        }
    }

    private var topChrome: some View {
        HStack {
            if viewModel.isLoading || viewModel.isSubmitting {
                ProgressView()
                    .tint(.white)
            }

            Spacer()

            Button {
                previewedChoice = nil
                Task {
                    await viewModel.refreshSession(using: authSession)
                }
            } label: {
                Label("Explore", systemImage: "arrow.triangle.branch")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading || viewModel.isSubmitting)
            .accessibilityLabel("Explore Other Bubbles")
        }
    }

    @ViewBuilder
    private var middleSection: some View {
        if viewModel.isLoading && !viewModel.hasCurrentPost {
            stateCard(
                title: "Loading graph feed",
                message: "Pulling your initial session from Bubbler.",
                showsProgress: true
            )
        } else if let previewedChoice {
            previewSection(for: previewedChoice)
        } else if viewModel.currentNode == nil {
            stateCard(
                title: "No session loaded",
                message: "Generate a new graph session to start exploring connected posts."
            )
        } else if viewModel.nextChoices.isEmpty {
            stateCard(
                title: "No connected bubbles",
                message: "Like, skip, or explore to keep walking the graph."
            )
        } else {
            bubbleField
        }
    }

    private var bubbleField: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let radius = size * 0.32
            let bubbleSize = min(96, size * 0.28)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let choices = Array(viewModel.nextChoices.prefix(4))

            ZStack {
                ForEach(Array(choices.enumerated()), id: \.element.id) { index, node in
                    let angle = bubbleAngle(for: index, total: choices.count)
                    let offset = CGPoint(
                        x: cos(angle) * radius,
                        y: sin(angle) * radius
                    )

                    GraphNeighborBubble(node: node, size: bubbleSize) {
                        previewedChoice = node
                    }
                    .position(x: center.x + offset.x, y: center.y + offset.y)
                    .disabled(viewModel.isSubmitting)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func previewSection(for node: GraphFeedNode) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    previewedChoice = nil
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    Task {
                        await viewModel.choose(node, using: authSession)
                        previewedChoice = nil
                    }
                } label: {
                    Label("Select", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSubmitting)
            }

            ScrollView {
                PostCardView(
                    post: node.post,
                    showsSkip: false,
                    isCompact: false,
                    isTopicPreferred: node.isPreferredTopic,
                    isTopicBlacklisted: node.isBlacklistedTopic
                )
            }
        }
    }

    @ViewBuilder
    private var stickyCurrentPost: some View {
        if let node = viewModel.currentNode {
            VStack(alignment: .leading, spacing: 8) {
                Text("CURRENT")
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.55))
                    .tracking(1)

                PostCardView(
                    post: node.post,
                    showsSkip: true,
                    isCompact: true,
                    isTopicPreferred: node.isPreferredTopic,
                    isTopicBlacklisted: node.isBlacklistedTopic,
                    onSkip: {
                        previewedChoice = nil
                        Task {
                            await viewModel.skipCurrentPost(using: authSession)
                        }
                    },
                    onTopicPreferenceChanged: {
                        Task {
                            await viewModel.syncTopicPreferences(using: authSession)
                        }
                    },
                    onDeleted: {
                        Task {
                            await viewModel.handleCurrentPostDeleted(using: authSession)
                        }
                    },
                    onEdited: { content in
                        viewModel.updateCurrentPostContent(content)
                    }
                )
                .disabled(viewModel.isSubmitting)
            }
        }
    }

    private func bubbleAngle(for index: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        // Start slightly above horizontal and space evenly around the center.
        let start = -Double.pi / 2
        return start + (Double(index) / Double(total)) * (2 * Double.pi)
    }

    private func banner(_ message: String, tint: Color) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.white.opacity(0.92))
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(tint.opacity(0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(tint.opacity(0.35), lineWidth: 1)
                    )
            )
    }

    private func stateCard(title: String, message: String, showsProgress: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if showsProgress {
                    ProgressView()
                        .tint(.white)
                }

                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            Text(message)
                .font(.caption)
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct GraphNeighborBubble: View {
    let node: GraphFeedNode
    let size: CGFloat
    let onTap: () -> Void

    private var topic: String {
        node.topicName ?? "topic"
    }

    private var color: Color {
        TopicStyle.color(for: topic)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                color.opacity(0.95),
                                color.opacity(0.55),
                                color.opacity(0.25),
                            ],
                            center: .topLeading,
                            startRadius: 4,
                            endRadius: size * 0.7
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.55), lineWidth: 1.5)
                    )
                    .shadow(color: color.opacity(0.45), radius: 14, x: 0, y: 8)

                VStack(spacing: 6) {
                    Image(systemName: TopicStyle.icon(for: topic))
                        .font(.system(size: size * 0.22, weight: .semibold))
                        .foregroundColor(.white)

                    Text(KnownTopics.displayName(for: topic))
                        .font(.system(size: max(10, size * 0.11), weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .padding(.horizontal, 8)

                if node.isPreferredTopic {
                    Image(systemName: "star.fill")
                        .font(.system(size: max(10, size * 0.13), weight: .bold))
                        .foregroundColor(.yellow.opacity(0.9))
                        .padding(size * 0.07)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.92))
                        )
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topTrailing
                        )
                        .padding(size * 0.08)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(KnownTopics.displayName(for: topic)) bubble\(node.isPreferredTopic ? ", preferred topic" : "")"
        )
    }
}

#Preview {
    NavigationStack {
        GraphFeedView()
            .environmentObject(AuthSession())
            .environmentObject(LikedPostsStore())
    }
}
