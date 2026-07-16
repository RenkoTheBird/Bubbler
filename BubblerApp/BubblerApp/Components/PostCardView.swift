import SwiftUI

struct PostCardView: View {
    let post: Post
    var showsSkip: Bool = false
    var isCompact: Bool = false
    var isTopicPreferred: Bool = false
    var isTopicBlacklisted: Bool = false
    var onSkip: (() -> Void)?
    var onLikeChanged: ((Bool) -> Void)?
    var onTopicPreferenceChanged: (() -> Void)?
    var onDeleted: (() -> Void)?
    var onEdited: ((String) -> Void)?

    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var likedPosts: LikedPostsStore
    @State private var showDeleteConfirmation = false
    @State private var showTopicMenu = false
    @State private var isDeleting = false
    @State private var isTogglingLike = false
    @State private var isUpdatingTopicPreference = false
    @State private var preferredLocally: Bool?
    @State private var blacklistedLocally: Bool?
    @State private var actionError: String?
    @State private var appearedAt = Date()

    private var isOwned: Bool {
        guard let userId = authSession.userId else { return false }
        return userId == post.userId
    }

    private var topicName: String? {
        guard let topic = post.topic?.trimmingCharacters(in: .whitespacesAndNewlines),
              !topic.isEmpty else {
            return nil
        }
        return topic
    }

    private var accentColor: Color {
        guard let topicName else { return .white }
        return TopicStyle.color(for: topicName)
    }

    private var currentlyLiked: Bool {
        likedPosts.isLiked(post.id)
    }

    private var currentlyPreferred: Bool {
        preferredLocally ?? isTopicPreferred
    }

    private var currentlyBlacklisted: Bool {
        blacklistedLocally ?? isTopicBlacklisted
    }

    private var contentLineLimit: Int? {
        isCompact ? 3 : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
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

                    if currentlyPreferred {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow.opacity(0.9))
                    }

                    if currentlyBlacklisted {
                        Image(systemName: "eye.slash.fill")
                            .font(.caption2)
                            .foregroundColor(.orange.opacity(0.9))
                    }
                }

                Spacer()

                Text(post.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))

                if topicName != nil {
                    Button {
                        showTopicMenu = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white.opacity(0.85))
                            .padding(8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdatingTopicPreference)
                    .accessibilityLabel("Topic options")
                }
            }

            Text(post.content)
                .font(isCompact ? .subheadline.weight(.semibold) : .headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(contentLineLimit)

            authorRow

            actionRow

            if isOwned {
                ownerActions
            }

            if let actionError {
                Text(actionError)
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.9))
            }
        }
        .padding(isCompact ? 12 : 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: isCompact ? 18 : 22)
                    .fill(Color.white.opacity(0.10))

                RoundedRectangle(cornerRadius: isCompact ? 18 : 22)
                    .stroke(accentColor.opacity(0.25), lineWidth: 1)

                RoundedRectangle(cornerRadius: isCompact ? 18 : 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        )
        .shadow(color: accentColor.opacity(0.15), radius: 20, x: 0, y: 10)
        .onAppear {
            appearedAt = Date()
            preferredLocally = nil
            blacklistedLocally = nil
        }
        .onChange(of: post.id) { _, _ in
            appearedAt = Date()
            preferredLocally = nil
            blacklistedLocally = nil
            actionError = nil
        }
        .onChange(of: isTopicPreferred) { _, _ in
            preferredLocally = nil
        }
        .onChange(of: isTopicBlacklisted) { _, _ in
            blacklistedLocally = nil
        }
        .confirmationDialog(
            "Delete this post?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Post", role: .destructive) {
                Task { await deletePost() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your post.")
        }
        .confirmationDialog(
            topicMenuTitle,
            isPresented: $showTopicMenu,
            titleVisibility: .visible
        ) {
            if let topicName {
                Button(currentlyPreferred ? "Unprefer Topic" : "Prefer Topic") {
                    Task { await togglePreferTopic(topicName) }
                }
                Button(
                    currentlyBlacklisted ? "Unblacklist Topic" : "Blacklist Topic",
                    role: currentlyBlacklisted ? nil : .destructive
                ) {
                    Task { await toggleBlacklistTopic(topicName) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let topicName {
                Text("Update how Bubbler treats \(KnownTopics.displayName(for: topicName)).")
            }
        }
    }

    private var topicMenuTitle: String {
        guard let topicName else { return "Topic options" }
        return KnownTopics.displayName(for: topicName)
    }

    @ViewBuilder
    private var authorRow: some View {
        if let username = post.username, !username.isEmpty {
            NavigationLink {
                UserProfileView(username: username)
            } label: {
                Text("Posted by \(post.authorLabel)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        } else {
            Text("Posted by \(post.authorLabel)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                Task { await toggleLike() }
            } label: {
                HStack(spacing: 6) {
                    if isTogglingLike {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: currentlyLiked ? "heart.fill" : "heart")
                    }
                    Text(currentlyLiked ? "Liked" : "Like")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(currentlyLiked ? .pink : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(currentlyLiked ? Color.pink.opacity(0.22) : Color.white.opacity(0.12))
                        .overlay(
                            Capsule()
                                .stroke(
                                    currentlyLiked ? Color.pink.opacity(0.45) : Color.white.opacity(0.16),
                                    lineWidth: 1
                                )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(isTogglingLike)

            if showsSkip {
                Button {
                    onSkip?()
                } label: {
                    Label("Skip", systemImage: "arrow.right.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.top, 2)
    }

    private var ownerActions: some View {
        HStack(spacing: 10) {
            NavigationLink {
                CreatePostView(post: post) { updatedContent in
                    onEdited?(updatedContent)
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

            Button {
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 6) {
                    if isDeleting {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text(isDeleting ? "Deleting..." : "Delete")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)

            Spacer()
        }
        .padding(.top, 4)
    }

    private func toggleLike() async {
        isTogglingLike = true
        actionError = nil
        defer { isTogglingLike = false }

        do {
            if currentlyLiked {
                try await APIClient.deleteLike(postId: post.id)
                likedPosts.setLiked(post.id, liked: false)
                onLikeChanged?(false)
            } else {
                let viewTime = max(0, Date().timeIntervalSince(appearedAt))
                try await APIClient.recordInteraction(
                    GraphInteractionPayload(
                        postId: post.id,
                        type: .like,
                        viewTime: viewTime
                    )
                )
                likedPosts.setLiked(post.id, liked: true)
                onLikeChanged?(true)
            }
        } catch {
            if case APIClientError.unauthorized = error {
                authSession.signOut()
            }
            actionError = error.localizedDescription
        }
    }

    private func togglePreferTopic(_ topic: String) async {
        isUpdatingTopicPreference = true
        actionError = nil
        defer { isUpdatingTopicPreference = false }

        do {
            var preferences = try await APIClient.getPreferences().sanitized()
            if currentlyPreferred {
                preferences.unpreferTopic(topic)
                preferredLocally = false
            } else {
                preferences.preferTopic(topic)
                preferredLocally = true
                blacklistedLocally = false
            }
            _ = try await APIClient.updatePreferences(preferences.sanitized().updatePayload)
            onTopicPreferenceChanged?()
        } catch {
            if case APIClientError.unauthorized = error {
                authSession.signOut()
            }
            preferredLocally = nil
            actionError = error.localizedDescription
        }
    }

    private func toggleBlacklistTopic(_ topic: String) async {
        isUpdatingTopicPreference = true
        actionError = nil
        defer { isUpdatingTopicPreference = false }

        do {
            var preferences = try await APIClient.getPreferences().sanitized()
            if currentlyBlacklisted {
                preferences.unblacklistTopic(topic)
                blacklistedLocally = false
            } else {
                preferences.blacklistTopic(topic)
                blacklistedLocally = true
                preferredLocally = false
            }
            _ = try await APIClient.updatePreferences(preferences.sanitized().updatePayload)
            onTopicPreferenceChanged?()
        } catch {
            if case APIClientError.unauthorized = error {
                authSession.signOut()
            }
            blacklistedLocally = nil
            actionError = error.localizedDescription
        }
    }

    private func deletePost() async {
        isDeleting = true
        actionError = nil
        defer { isDeleting = false }

        do {
            try await APIClient.deletePost(id: post.id)
            likedPosts.setLiked(post.id, liked: false)
            authSession.showSuccessMessage("Post deleted.")
            onDeleted?()
        } catch {
            if case APIClientError.unauthorized = error {
                authSession.signOut()
            }
            actionError = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
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
                    username: "preview",
                    content: "A sample bubble post for the card preview.",
                    createdAt: .now.addingTimeInterval(-2_700),
                    topic: "technology",
                    embedding: nil
                ),
                showsSkip: true
            )
            .padding()
        }
        .environmentObject(AuthSession())
        .environmentObject(LikedPostsStore())
    }
}
