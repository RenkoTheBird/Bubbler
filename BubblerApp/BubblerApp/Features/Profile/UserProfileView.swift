//
//  UserProfileView.swift
//  BubblerApp
//
//  Created by Alyssa Hooper on 6/20/26.
//

import SwiftUI

/// Profile for another user. Forwards to the shared `ProfileView` loader.
struct UserProfileView: View {
    let username: String

    var body: some View {
        ProfileView(username: username)
    }
}

#Preview {
    NavigationStack {
        UserProfileView(username: "alex")
            .environmentObject(AuthSession())
    }
}
