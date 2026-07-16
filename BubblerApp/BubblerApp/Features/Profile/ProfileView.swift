//
//  ProfileView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/12/26.
//

import SwiftUI
import Combine

struct ProfileView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel: ProfileViewModel

    /// `nil` shows the signed-in user's profile. Pass a username for another user.
    init(username: String? = nil) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(username: username))
    }

    var body: some View {
        
        ZStack {
            
            // Background
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.9),
                    Color.cyan.opacity(0.6),
                    Color.indigo.opacity(0.8),
                    Color.blue.opacity(1.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                
                VStack(spacing: 28) {
                    
                    Spacer()
                        .frame(height: 20)
                    
                    Text(viewModel.activeBubbleLabel)
                        .font(.subheadline.bold())
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .cornerRadius(12)
                    
                    // profile core
                    ZStack {
                        
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 170, height: 170)
                        
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 135, height: 135)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            )
                        
                        Circle()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 110, height: 110)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 46))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    VStack(spacing: 6) {
                        Text(viewModel.displayUsername)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text(viewModel.profileSubtitle)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }

                    // Bubble Trail — only for the signed-in user's own profile
                    if viewModel.isOwnProfile {
                        NavigationLink {
                            BubbleTrailView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                                    .font(.body.weight(.semibold))

                                Text("Bubble Trail")
                                    .font(.subheadline.bold())

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }

                    // user's posts
                    VStack(alignment: .leading, spacing: 14) {
                        
                        Text(viewModel.isOwnProfile ? "Your Posts" : "Posts")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        if viewModel.isLoading && viewModel.posts.isEmpty {
                            Text(viewModel.emptyPostsMessage)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 20)
                        } else if viewModel.posts.isEmpty {
                            Text(viewModel.emptyPostsMessage)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.75))
                                .padding(.horizontal, 20)
                        } else {
                            VStack(spacing: 18) {
                                ForEach(viewModel.posts) { post in
                                    PostCardView(
                                        post: post,
                                        isCompact: true,
                                        onDeleted: {
                                            viewModel.removePost(id: post.id)
                                        },
                                        onEdited: { content in
                                            viewModel.updatePostContent(id: post.id, content: content)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    Spacer().frame(height: 40)
                }
            }
        }
        .task {
            await viewModel.loadProfile(using: authSession)
        }
    }
}

#Preview("Own profile") {
    NavigationStack {
        ProfileView()
            .environmentObject(AuthSession())
            .environmentObject(LikedPostsStore())
    }
}

#Preview("Other user") {
    NavigationStack {
        ProfileView(username: "alex")
            .environmentObject(AuthSession())
            .environmentObject(LikedPostsStore())
    }
}
