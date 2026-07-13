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

    private var activeTopics: [String] {
        var seen = Set<String>()

        return viewModel.posts
            .compactMap { post in
                guard let topic = post.topic?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !topic.isEmpty else {
                    return nil
                }
                return topic
            }
            .filter { topic in
                seen.insert(topic.lowercased()).inserted
            }
    }
    
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
                    
                    // Create Post button
                    HStack {

                        Spacer()

                        NavigationLink {
                            CreatePostView()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, -20)

                    Spacer().frame(height: 1)
                    
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
                    
                    // bubble strip
                    if !activeTopics.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(Array(activeTopics.enumerated()), id: \.offset) { item in
                                    bubbleChip(
                                        item.element,
                                        topicIcon(for: item.element),
                                        topicColor(for: item.element),
                                        item.offset == 0
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
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
                                message: "Posts from the database will show up here after the feed has data."
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
    
    // bubble chip
    private func bubbleChip(_ name: String, _ icon: String, _ color: Color, _ isActive: Bool) -> some View {
        
        HStack(spacing: 8) {
            
            Image(systemName: icon)
                .font(.caption)
            
            Text(name)
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
    
    private func topicIcon(for topic: String) -> String {
        switch topic.lowercased() {
        case "tech", "technology":
            return "desktopcomputer"
        case "sports":
            return "basketball.fill"
        case "space", "science":
            return "globe.americas.fill"
        case "ai":
            return "brain.head.profile"
        case "music":
            return "music.note"
        default:
            return "circle.grid.2x2.fill"
        }
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
    }
}
