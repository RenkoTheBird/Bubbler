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
    @StateObject private var viewModel = ProfileViewModel()

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
                        
                        Text("Your bubble profile 🫧")
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
                    
                    // active bubbles from topics you've posted about
                    VStack(alignment: .leading, spacing: 14) {
                        
                        Text("Active Bubbles")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 35)
                        
                        if viewModel.postedTopics.isEmpty {
                            Text(
                                viewModel.isLoading
                                    ? "Loading your bubbles…"
                                    : "Post about a topic to grow your bubbles."
                            )
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.75))
                            .padding(.horizontal, 35)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(viewModel.postedTopics, id: \.self) { topic in
                                        bubble(
                                            KnownTopics.displayName(for: topic),
                                            TopicStyle.icon(for: topic),
                                            TopicStyle.color(for: topic),
                                            0.95
                                        )
                                    }
                                }
                                .padding(.horizontal, 15)
                            }
                        }
                    }
                    
                    // bubble trail (GET /user/me, max 20)
                    VStack(alignment: .leading, spacing: 14) {
                        
                        Text("Your Bubble Trail")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 35)
                        
                        if viewModel.trailInteractions.isEmpty {
                            feedSnippet(
                                viewModel.isLoading
                                    ? "Loading your bubble trail…"
                                    : "Your bubble trail will appear here once you start interacting with posts."
                            )
                        } else {
                            ForEach(viewModel.trailInteractions) { interaction in
                                feedSnippet(interaction.trailSummary)
                            }
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
    
    // bubble
    private func bubble(_ title: String, _ icon: String, _ color: Color, _ scale: CGFloat) -> some View {
        
        VStack(spacing: 10) {
            
            ZStack {
                
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 92, height: 92)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                
                Circle()
                    .fill(color.opacity(0.20))
                    .frame(width: 78, height: 78)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
            .scaleEffect(scale)
            .shadow(color: color.opacity(0.35), radius: 12)
            
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    // feed card
    private func feedSnippet(_ text: String) -> some View {
        
        HStack {
            Text(text)
                .foregroundColor(.white.opacity(0.9))
                .font(.subheadline)
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
            
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthSession())
}
