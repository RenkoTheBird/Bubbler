//
//  ContentView.swift
//  BubblerApp
//
//  Created by Nishan Narain on 5/22/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authSession = AuthSession()
    @StateObject private var backendConnection = BackendConnection()
    @StateObject private var likedPosts = LikedPostsStore()

    var body: some View {
        Group {
            if authSession.isSignedIn {
                MainTabView()
            } else {
                NavigationStack {
                    LoginView()
                }
            }
        }
        .id(authSession.isSignedIn)
        .environmentObject(authSession)
        .environmentObject(backendConnection)
        .environmentObject(likedPosts)
        .task(id: authSession.accessToken) {
            if authSession.isSignedIn {
                await likedPosts.refresh()
            } else {
                likedPosts.clear()
            }
        }
        .overlay(alignment: .top) {
            if let successMessage = authSession.successMessage {
                Text(successMessage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.green.opacity(0.92))
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
                    )
                    .padding(.top, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: authSession.successMessage)
        .onChange(of: authSession.successMessage) { _, message in
            guard message != nil else { return }

            Task {
                try? await Task.sleep(for: .seconds(2))
                authSession.clearSuccessMessage()
            }
        }
    }
}
