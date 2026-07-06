//
//  UserProfileView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/20/26.
//

import SwiftUI

struct UserProfileView: View {
    
    let username: String
    
    var body: some View {
        
        ZStack {
            
            // SAME BACKGROUND
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
                
                VStack(spacing: 15) {
                    
                    // top bar
                    HStack {
                        
                        Button(action: {}) {
                            Image(systemName: "arrow.left")
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
                        
                        HStack(spacing: 20) {
                            
                            Button(action: {}) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                            }
                            
                            Button(action: {}) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 18, weight: .semibold))
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
                    }
                    .padding(.horizontal, 30)
                    .padding(.top, -20)
                    
                    Spacer().frame(height: 1)
                    
                    // relationship bubble
                    Text("🫧 Connected via Tech • AI")
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
                    
                    // PROFILE CORE
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
                        Text("@\(username)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Bubble node in your network")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    
                    // ACTION ROW
                    HStack(spacing: 14) {
                        
                        actionButton("Follow", "person.fill.checkmark")
                        actionButton("Message", "bubble.left.fill")
                        actionButton("Mute", "speaker.slash.fill")
                    }
                    .padding(.horizontal, 20)
                    
                    // stats
                    HStack(spacing: 14) {
                        statCard(number: "18", label: "Bubbles")
                        statCard(number: "210", label: "Connections")
                        statCard(number: "54", label: "Clicks")
                    }
                    .padding(.horizontal, 20)
                    
                    // shared bubbles
                    VStack(alignment: .leading, spacing: 14) {
                        
                        Text("Shared Bubbles")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 35)
                        
                        HStack(spacing: 14) {
                            bubble("Tech", "desktopcomputer", .blue)
                            bubble("AI", "brain.head.profile", .pink)
                        }
                        .padding(.horizontal, 15)
                    }
                    
                    // recent activity
                    VStack(alignment: .leading, spacing: 14) {
                        
                        Text("Recent Activity")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 35)
                        
                        feedSnippet("Posted in AI bubble: Multi-step reasoning systems evolving")
                        feedSnippet("Joined Tech bubble discussion")
                        feedSnippet("Engaged with Space content")
                    }
                    
                    Spacer().frame(height: 40)
                }
            }
        }
    }
    
    // MARK: - Components
    
    private func actionButton(_ title: String, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.caption.bold())
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(14)
    }
    
    private func bubble(_ title: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 10) {
            
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 92, height: 92)
                
                Circle()
                    .fill(color.opacity(0.20))
                    .frame(width: 78, height: 78)
                    .overlay(
                        Image(systemName: icon)
                            .foregroundColor(.white)
                    )
            }
            .shadow(color: color.opacity(0.35), radius: 12)
            
            Text(title)
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.9))
        }
    }
    
    private func statCard(number: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(number)
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        )
    }
    
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
    UserProfileView(username: "alex")
}
