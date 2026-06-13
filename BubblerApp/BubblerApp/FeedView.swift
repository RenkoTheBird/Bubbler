//
//  FeedView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/12/26.
//

import SwiftUI

struct FeedView: View {
    
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
                    
                    // Top buttons
                    HStack {

                        // Profile button
                        NavigationLink {
                            ProfileView()
                        } label: {
                            Image(systemName: "person.fill")
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

                        Spacer()

                        // Search button
                        NavigationLink {
                            SearchView() // WORKING ON STILL
                        } label: {
                            Image(systemName: "magnifyingglass")
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
                    .padding(.horizontal, 60)
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        
                        HStack(spacing: 14) {
                            bubbleChip("Tech", "desktopcomputer", .blue, true)
                            bubbleChip("Sports", "basketball.fill", .green, false)
                            bubbleChip("Space", "globe.americas.fill", .purple, false)
                            bubbleChip("AI", "brain.head.profile", .pink, true)
                            bubbleChip("Music", "music.note", .orange, false)
                        }
                        .padding(.horizontal)
                    }
                    
                    // feed stream
                    VStack(spacing: 18) {
                        
                        feedCard(
                            bubble: "Tech",
                            title: "AI systems are beginning to exhibit autonomous decision loops",
                            subtitle: "High resonance in your Tech bubble",
                            color: .blue
                        )
                        
                        feedCard(
                            bubble: "Space",
                            title: "NASA Artemis missions enter long-duration phase testing",
                            subtitle: "Pulled from your Space interest field",
                            color: .purple
                        )
                        
                        feedCard(
                            bubble: "AI",
                            title: "Agent-based models are evolving into multi-step reasoning systems",
                            subtitle: "Your AI bubble is highly active",
                            color: .pink
                        )
                        
                        feedCard(
                            bubble: "Sports",
                            title: "Playoff momentum is shifting across key teams",
                            subtitle: "Detected from Sports bubble activity",
                            color: .green
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 40)
                }
            }
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
    
    // feed card
    private func feedCard(bubble: String, title: String, subtitle: String, color: Color) -> some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            // top label
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .shadow(color: color.opacity(0.8), radius: 6)
                    
                    Text(bubble.uppercased())
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.85))
                        .tracking(1)
                }
                
                Spacer()
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
        }
        .padding(16)
        .background(
            ZStack {
                
                // main layer
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.white.opacity(0.10))
                
                // subtle glow
                RoundedRectangle(cornerRadius: 22)
                    .stroke(color.opacity(0.25), lineWidth: 1)
                
                // soft highlight
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
        )
        .shadow(color: color.opacity(0.15), radius: 20, x: 0, y: 10)
    }
}

#Preview {
    FeedView()
}
