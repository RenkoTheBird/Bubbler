import Combine
import SwiftUI

struct PostCardView: View {
    let post: Post
    var isCompact: Bool = false
    var isTopicPreferred: Bool = false
    var isTopicBlacklisted: Bool = false
    var onFeedPreferenceChanged: ((FeedPreference) -> Void)?
    var onTopicPreferenceChanged: (() -> Void)?
    var onDeleted: (() -> Void)?
    var onEdited: ((String) -> Void)?

    @EnvironmentObject private var authSession: AuthSession
    @EnvironmentObject private var feedPreferences: FeedPreferencesStore
    @State private var showDeleteConfirmation = false
    @State private var showOverflowMenu = false
    @State private var showReportForm = false
    @State private var isDeleting = false
    @State private var isSavingFeedPreference = false
    @State private var isUpdatingTopicPreference = false
    @State private var preferredLocally: Bool?
    @State private var blacklistedLocally: Bool?
    @State private var localFeedPreference: FeedPreference = .neutral
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

    private var currentlyPreferred: Bool {
        preferredLocally ?? isTopicPreferred
    }

    private var currentlyBlacklisted: Bool {
        blacklistedLocally ?? isTopicBlacklisted
    }

    private var currentFeedPreference: FeedPreference {
        localFeedPreference
    }

    private var contentLineLimit: Int? {
        isCompact ? 3 : nil
    }

    private var showsOverflowMenu: Bool {
        topicName != nil || !isOwned
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

                if showsOverflowMenu {
                    Button {
                        showOverflowMenu = true
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
                    .accessibilityLabel("Post options")
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
            localFeedPreference = feedPreferences.preference(for: post.id)
        }
        .onChange(of: post.id) { _, _ in
            appearedAt = Date()
            preferredLocally = nil
            blacklistedLocally = nil
            actionError = nil
            localFeedPreference = feedPreferences.preference(for: post.id)
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
            overflowMenuTitle,
            isPresented: $showOverflowMenu,
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
            if !isOwned {
                Button("Report Post", role: .destructive) {
                    showReportForm = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let topicName {
                Text("Update how Bubbler treats \(KnownTopics.displayName(for: topicName)).")
            } else {
                Text("Report this post to Bubbler.")
            }
        }
        .navigationDestination(isPresented: $showReportForm) {
            ReportPostView(post: post)
        }
    }

    private var overflowMenuTitle: String {
        guard let topicName else { return "Post options" }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Feed preference")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                if isSavingFeedPreference {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                }
            }

            Slider(
                value: Binding(
                    get: { Double(currentFeedPreference.rawValue) },
                    set: { newValue in
                        let snapped = FeedPreference(rawValueOrZero: Int(newValue.rounded()))
                        guard snapped != localFeedPreference else { return }
                        localFeedPreference = snapped
                        Task { await saveFeedPreference(snapped) }
                    }
                ),
                in: -2...2,
                step: 1
            )
            .tint(accentColor)
            .disabled(isSavingFeedPreference)

            Text(currentFeedPreference.label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private func saveFeedPreference(_ value: FeedPreference) async {
        isSavingFeedPreference = true
        actionError = nil
        defer { isSavingFeedPreference = false }

        do {
            try await APIClient.setFeedPreference(postId: post.id, value: value)
            feedPreferences.setPreference(value, for: post.id)
            onFeedPreferenceChanged?(value)
        } catch {
            if case APIClientError.unauthorized = error {
                authSession.signOut()
            }
            localFeedPreference = feedPreferences.preference(for: post.id)
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
            feedPreferences.setPreference(.neutral, for: post.id)
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
                )
            )
            .padding()
        }
        .environmentObject(AuthSession())
        .environmentObject(FeedPreferencesStore())
    }
}
