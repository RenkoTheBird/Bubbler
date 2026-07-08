//
//  SettingsView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/12/26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authSession: AuthSession
    
    var body: some View {
        
        ZStack {
            
            // gradient background
            LinearGradient(
                colors: [
                    Color.black,
                    Color.blue.opacity(0.6),
                    Color.indigo.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                
                VStack(spacing: 26) {
                    
                    Spacer().frame(height: 20)
                    
                    // header
                    VStack(spacing: 6) {
                        Text("Settings")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Control your Bubbler experience")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 10)
                    
                    // account
                    settingsSection(title: "Account") {
                        settingsRow(icon: "person.fill", title: "Profile Information")
                        settingsRow(icon: "envelope.fill", title: "Email Settings")
                        settingsRow(icon: "lock.fill", title: "Password & Security")
                        Button {
                            authSession.signOut()
                        } label: {
                            settingsRow(icon: "rectangle.portrait.and.arrow.right", title: "Log Out")
                        }
                    }
                    
                    // notifications
                    settingsSection(title: "Notifications") {
                        settingsToggle(title: "Push Notifications")
                        settingsToggle(title: "Bubble Activity Alerts")
                        settingsToggle(title: "Trending Content Alerts")
                    }
                    
                    // privacy
                    settingsSection(title: "Privacy") {
                        settingsRow(icon: "eye.slash.fill", title: "Visibility Settings")
                        settingsRow(icon: "hand.raised.fill", title: "Blocked Accounts")
                    }
                    
                    // bubbler system
                    settingsSection(title: "Bubble System") {
                        settingsRow(icon: "bubble.left.and.bubble.right.fill", title: "Manage Interests")
                        settingsRow(icon: "arrow.counterclockwise", title: "Reset Bubble Profile")
                        NavigationLink {
                            PreferencesSettingsView()
                        } label: {
                            settingsRow(icon: "slider.horizontal.3", title: "Bubble Sensitivity")
                        }
                        .buttonStyle(.plain)
                        NavigationLink {
                            FeedView()
                        } label: {
                            settingsRow(icon: "rectangle.stack.fill", title: "Classic Feed")
                        }
                        .buttonStyle(.plain)
                        NavigationLink {
                            CreatePostView()
                        } label: {
                            settingsRow(icon: "square.and.pencil", title: "Create Post")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // app
                    settingsSection(title: "App") {
                        settingsRow(icon: "paintbrush.fill", title: "Appearance")
                        settingsRow(icon: "trash.fill", title: "Clear Cache")
                        settingsRow(icon: "info.circle.fill", title: "About Bubbler")
                    }
                    
                    Spacer().frame(height: 30)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // section wrapper
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        
        VStack(alignment: .leading, spacing: 12) {
            
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.6))
                .tracking(1)
            
            VStack(spacing: 12) {
                content()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
    }
    
    // row
    private func settingsRow(icon: String, title: String) -> some View {
        
        HStack {
            
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 22)
            
            Text(title)
                .foregroundColor(.white.opacity(0.9))
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.4))
        }
    }
    
    // toggle row
    private func settingsToggle(title: String) -> some View {
        
        HStack {
            
            Image(systemName: "switch.2")
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 22)
            
            Text(title)
                .foregroundColor(.white.opacity(0.9))
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: "circle")
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthSession())
}
