import SwiftUI

struct GraphFeedView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = GraphFeedViewModel()
    @State private var showDeleteConfirmation = false

    private var accentColor: Color {
        topicColor(for: viewModel.currentTopicName)
    }

    private var ownsCurrentPost: Bool {
        guard let userId = authSession.userId,
              let currentNode = viewModel.currentNode else {
            return false
        }
        return userId == currentNode.userId
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accentColor.opacity(0.8),
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    headerSection
                    contextCard

                    if let statusMessage = viewModel.statusMessage {
                        messageCard(statusMessage, tint: accentColor.opacity(0.85))
                    }

                    if let errorMessage = viewModel.errorMessage {
                        messageCard(errorMessage, tint: .red.opacity(0.8))
                    }

                    currentPostSection
                    choicesSection
                    actionsSection

                    Spacer().frame(height: 30)
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("Graph Feed")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: authSession.accessToken) {
            await viewModel.load(using: authSession)
        }
        .confirmationDialog(
            "Delete this post?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Post", role: .destructive) {
                Task {
                    await viewModel.deleteCurrentPost(using: authSession)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your post.")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.25))
                    .frame(width: 90, height: 90)
                    .blur(radius: 0.5)

                Circle()
                    .stroke(accentColor.opacity(0.6), lineWidth: 1)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 70, height: 70)

                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundColor(.white)
                    .font(.system(size: 22, weight: .semibold))
            }

            Text(viewModel.currentTopicName.uppercased())
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(2)

            Text(topicStatusSubtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.72))
        }
        .frame(maxWidth: .infinity)
    }

    private var contextCard: some View {
        VStack(spacing: 10) {
            Text("Context Layer")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.8))
                .tracking(1)

            Text("Session posts come from your graph feed. Connected choices mix same-topic, bridge, and opposite neighbors so you can walk between bubbles.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)

            if let seedStrategyLabel = viewModel.seedStrategyLabel {
                Text(seedStrategyLabel)
                    .font(.caption2.bold())
                    .foregroundColor(.white.opacity(0.78))
                    .padding(.top, 2)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(cardBackground(stroke: Color.white.opacity(0.12)))
    }

    private var currentPostSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Current Post")

            if viewModel.isLoading && !viewModel.hasCurrentPost {
                stateCard(
                    title: "Loading graph feed",
                    message: "Pulling your initial session from Bubbler.",
                    showsProgress: true
                )
            } else if let node = viewModel.currentNode {
                postCard(node, isInteractive: false)

                if ownsCurrentPost {
                    ownerActions(for: node)
                }

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.white.opacity(0.7))

                        Text("View time: \(viewModel.viewTimeText(at: context.date))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))

                        Spacer()
                    }
                    .padding(.horizontal, 4)
                }
            } else {
                stateCard(
                    title: "No session loaded",
                    message: "Generate a new graph session to start exploring connected posts."
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var choicesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Connected Choices")

            if viewModel.currentNode == nil, !viewModel.isLoading {
                bubbleCard("Load a session first to see graph-connected choices.")
            } else if viewModel.nextChoices.isEmpty {
                bubbleCard("No connected posts are ready yet. You can like, skip, prefer/blacklist the topic, or refresh.")
            } else {
                ForEach(viewModel.nextChoices) { node in
                    postCard(node, isInteractive: true) {
                        Task {
                            await viewModel.choose(node, using: authSession)
                        }
                    }
                    .disabled(viewModel.isSubmitting)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                actionButton(
                    title: viewModel.isCurrentPostLiked ? "Unlike" : "Like",
                    systemImage: viewModel.isCurrentPostLiked ? "heart.slash.fill" : "heart.fill",
                    tint: .pink,
                    isPrimary: true
                ) {
                    Task {
                        await viewModel.toggleCurrentPostLike(using: authSession)
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isSubmitting || !viewModel.hasCurrentPost)

                actionButton(
                    title: "Skip",
                    systemImage: "arrow.right.circle",
                    tint: .white,
                    isPrimary: false
                ) {
                    Task {
                        await viewModel.skipCurrentPost(using: authSession)
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isSubmitting || !viewModel.hasCurrentPost)
            }

            HStack(spacing: 12) {
                actionButton(
                    title: viewModel.isCurrentTopicPreferred ? "Unprefer" : "Prefer Topic",
                    systemImage: viewModel.isCurrentTopicPreferred ? "star.slash.fill" : "star.fill",
                    tint: .yellow,
                    isPrimary: false
                ) {
                    Task {
                        await viewModel.togglePreferCurrentTopic(using: authSession)
                    }
                }
                .disabled(
                    viewModel.isLoading
                        || viewModel.isSubmitting
                        || !viewModel.hasCurrentPost
                        || !viewModel.hasCurrentTopic
                )

                actionButton(
                    title: viewModel.isCurrentTopicBlacklisted ? "Unblacklist" : "Blacklist Topic",
                    systemImage: viewModel.isCurrentTopicBlacklisted ? "eye" : "eye.slash.fill",
                    tint: .orange,
                    isPrimary: false
                ) {
                    Task {
                        await viewModel.toggleBlacklistCurrentTopic(using: authSession)
                    }
                }
                .disabled(
                    viewModel.isLoading
                        || viewModel.isSubmitting
                        || !viewModel.hasCurrentPost
                        || !viewModel.hasCurrentTopic
                )
            }

            actionButton(
                title: viewModel.isLoading ? "Exploring..." : "Explore Other Bubbles",
                systemImage: "arrow.triangle.branch",
                tint: accentColor,
                isPrimary: false
            ) {
                Task {
                    await viewModel.refreshSession(using: authSession)
                }
            }
            .disabled(viewModel.isLoading || viewModel.isSubmitting)
        }
    }

    private var topicStatusSubtitle: String {
        if viewModel.isCurrentTopicBlacklisted {
            return "Topic blacklisted"
        }
        if viewModel.isCurrentTopicPreferred {
            return "Preferred bubble path active"
        }
        return "Graph recommendation loop"
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption.bold())
            .foregroundColor(.white.opacity(0.64))
            .tracking(1)
    }

    private func ownerActions(for node: GraphFeedNode) -> some View {
        HStack(spacing: 10) {
            NavigationLink {
                CreatePostView(post: node.post) { content in
                    viewModel.updateCurrentPostContent(content)
                }
            } label: {
                Label("Edit", systemImage: "pencil")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSubmitting)

            Button {
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isSubmitting)

            Spacer()
        }
    }

    private func postCard(
        _ node: GraphFeedNode,
        isInteractive: Bool,
        onSelect: (() -> Void)? = nil
    ) -> some View {
        let topicName = node.topicName ?? "Topicless"
        let nodeColor = topicColor(for: topicName)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(nodeColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: nodeColor.opacity(0.8), radius: 6)

                            Text(topicName.uppercased())
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.85))
                                .tracking(1)
                        }

                        if node.isPreferredTopic {
                            tagLabel("Preferred Topic", tint: .pink)
                        }

                        if node.isBlacklistedTopic {
                            tagLabel("Blacklisted Topic", tint: .orange)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(node.createdAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.65))

                        if isInteractive {
                            Text("Tap to explore")
                                .font(.caption2.bold())
                                .foregroundColor(.white.opacity(0.58))
                        }
                    }
                }

                Text(node.content)
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard isInteractive else { return }
                onSelect?()
            }

            HStack {
                if let username = node.post.username, !username.isEmpty {
                    NavigationLink {
                        UserProfileView(username: username)
                    } label: {
                        Text("Posted by \(node.post.authorLabel)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Posted by \(node.post.authorLabel)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.72))
                }

                Spacer()

                if !isInteractive, viewModel.isCurrentPostLiked {
                    Label("Liked", systemImage: "heart.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.pink.opacity(0.9))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(stroke: nodeColor.opacity(0.2)))
        .shadow(color: nodeColor.opacity(0.18), radius: 18, x: 0, y: 10)
    }

    private func bubbleCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .padding(.vertical, 18)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .background(cardBackground(stroke: accentColor.opacity(0.16)))
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
        .background(cardBackground(stroke: Color.white.opacity(0.14)))
    }

    private func messageCard(_ message: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(.white.opacity(0.82))

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(tint.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(tint.opacity(0.34), lineWidth: 1)
                )
        )
    }

    private func actionButton(
        title: String,
        systemImage: String,
        tint: Color,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if viewModel.isSubmitting && isPrimary {
                    ProgressView()
                        .tint(isPrimary ? .black : .white)
                } else {
                    Image(systemName: systemImage)
                }

                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundColor(isPrimary ? .black : .white)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isPrimary ? Color.white : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isPrimary ? Color.white.opacity(0.2) : tint.opacity(0.3),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func tagLabel(_ title: String, tint: Color) -> some View {
        Text(title.uppercased())
            .font(.caption2.bold())
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.26))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.45), lineWidth: 1)
                    )
            )
    }

    private func cardBackground(stroke: Color) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(stroke, lineWidth: 1)
            )
    }

    private func topicColor(for topic: String) -> Color {
        switch topic.lowercased() {
        case "tech", "technology":
            return .blue
        case "sports":
            return .green
        case "space", "science":
            return .purple
        case "ai":
            return .pink
        case "music":
            return .orange
        default:
            return .cyan
        }
    }
}

#Preview {
    NavigationStack {
        GraphFeedView()
            .environmentObject(AuthSession())
    }
}
