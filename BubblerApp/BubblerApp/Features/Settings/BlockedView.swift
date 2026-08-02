//
//  BlockedView.swift
//  BubblerApp
//

import SwiftUI

struct BlockedUserItem: Identifiable, Equatable {
    let id: Int
    let username: String
}

struct BlockedView: View {
    @State private var blockedUsers: [BlockedUserItem]
    @State private var userPendingUnblock: BlockedUserItem?

    init(blockedUsers: [BlockedUserItem] = []) {
        _blockedUsers = State(initialValue: blockedUsers)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.blue.opacity(0.6),
                    Color.indigo.opacity(0.85),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    if blockedUsers.isEmpty {
                        emptyStateCard
                    } else {
                        blockedListCard
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Blocked")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            unblockDialogTitle,
            isPresented: Binding(
                get: { userPendingUnblock != nil },
                set: { if !$0 { userPendingUnblock = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Unblock", role: .destructive) {
                if let user = userPendingUnblock {
                    unblock(user)
                }
            }
            Button("Cancel", role: .cancel) {
                userPendingUnblock = nil
            }
        } message: {
            Text("They will be able to interact with you again once unblocked.")
        }
    }

    private var unblockDialogTitle: String {
        if let username = userPendingUnblock?.username {
            return "Unblock @\(username)?"
        }
        return "Unblock this user?"
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Blocked Users")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("People you block won’t appear in your feed or be able to interact with you.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(.bottom, 4)
    }

    private var emptyStateCard: some View {
        sectionCard(title: "No blocked users") {
            Text("When you block someone, they’ll show up here so you can unblock them anytime.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var blockedListCard: some View {
        sectionCard(
            title: "Blocked",
            subtitle: blockedUsers.count == 1
                ? "1 person"
                : "\(blockedUsers.count) people"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(blockedUsers.enumerated()), id: \.element.id) { index, user in
                    blockedUserRow(user)

                    if index < blockedUsers.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.12))
                    }
                }
            }
        }
    }

    private func blockedUserRow(_ user: BlockedUserItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.75))

            Text("@\(user.username)")
                .foregroundColor(.white)
                .font(.subheadline.weight(.medium))

            Spacer()

            Button("Unblock") {
                userPendingUnblock = user
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
    }

    private func sectionCard<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                }
            }

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func unblock(_ user: BlockedUserItem) {
        blockedUsers.removeAll { $0.id == user.id }
        userPendingUnblock = nil
    }
}

#Preview("Empty") {
    NavigationStack {
        BlockedView()
    }
}

#Preview("With blocked users") {
    NavigationStack {
        BlockedView(blockedUsers: [
            BlockedUserItem(id: 1, username: "alex"),
            BlockedUserItem(id: 2, username: "jordan"),
        ])
    }
}
