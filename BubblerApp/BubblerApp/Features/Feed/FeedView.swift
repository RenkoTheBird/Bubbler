//
//  FeedView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/12/26.
//

import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = FeedViewModel()

    private let feedTopics: [String?] = [nil] + KnownTopics.all.map { Optional($0) }

    var body: some View {

        ZStack {

            // background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.9),
                    Color.cyan.opacity(0.55),
                    Color.indigo.opacity(0.9),
                    Color.black.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {

                VStack(spacing: 28) {
                    // header
                    VStack(spacing: 8) {

                        // logo
                        BubblerLogoView()
                            .frame(width: 55, height: 55)
                            .opacity(0.95)
                            .shadow(color: .blue.opacity(0.2), radius: 8)
                            .padding(.bottom, 65)

                        // title
                        Text("BUBBLER")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(2)

                        // subtitle
                        Text("your interest field is active")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity)

                    // topic strip — All (mixed) plus curated KnownTopics
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(Array(feedTopics.enumerated()), id: \.offset) { _, topic in
                                topicChip(topic)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // feed stream
                    VStack(spacing: 18) {
                        if viewModel.isLoading && viewModel.posts.isEmpty {
                            stateCard(
                                title: "Loading your feed",
                                message: "Pulling the latest posts from Bubbler.",
                                showsProgress: true
                            )
                        } else if let errorMessage = viewModel.errorMessage {
                            stateCard(
                                title: "Couldn't load the feed",
                                message: errorMessage
                            )
                        } else if viewModel.posts.isEmpty {
                            stateCard(
                                title: "No posts yet",
                                message: viewModel.selectedTopic == nil
                                    ? "Posts from the database will show up here after the feed has data."
                                    : "No posts matched this topic yet. Try another bubble."
                            )
                        } else {
                            ForEach(viewModel.posts) { post in
                                PostCardView(
                                    post: post,
                                    onDeleted: {
                                        viewModel.removePost(id: post.id)
                                    },
                                    onEdited: { content in
                                        viewModel.updatePostContent(id: post.id, content: content)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer().frame(height: 40)
                }
            }
        }
        .task(id: authSession.accessToken) {
            await viewModel.loadFeed(using: authSession)
        }
    }

    private func topicChip(_ topic: String?) -> some View {
        let label: String
        let icon: String
        let color: Color
        let isActive: Bool

        if let topic {
            label = KnownTopics.displayName(for: topic)
            icon = TopicStyle.icon(for: topic)
            color = TopicStyle.color(for: topic)
            isActive = viewModel.selectedTopic?.caseInsensitiveCompare(topic) == .orderedSame
        } else {
            label = "All"
            icon = "sparkles"
            color = .cyan
            isActive = viewModel.selectedTopic == nil
        }

        return Button {
            Task {
                await viewModel.selectTopic(topic, using: authSession)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)

                Text(label)
                    .font(.caption.bold())
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isActive ? color.opacity(0.35) : Color.white.opacity(0.10))
                    .overlay(
                        Capsule()
                            .stroke(
                                isActive ? color.opacity(0.6) : Color.white.opacity(0.15),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: isActive ? color.opacity(0.4) : .clear, radius: 10)
            )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
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
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.10))

                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)

                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        )
        .shadow(color: Color.white.opacity(0.08), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    NavigationStack {
        FeedView()
            .environmentObject(AuthSession())
            .environmentObject(LikedPostsStore())
    }
}
