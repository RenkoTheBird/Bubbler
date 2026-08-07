//
//  BlockedView.swift
//  BubblerApp
//

import SwiftUI
import Combine

struct BlockedView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = BlockedViewModel()
    @State private var userPendingUnblock: BlockedUser?

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

                    if let errorMessage = viewModel.errorMessage {
                        messageCard(
                            title: viewModel.errorTitle,
                            message: errorMessage,
                            tint: .red
                        )
                    }

                    if viewModel.isLoading && viewModel.blockedUsers.isEmpty {
                        loadingCard
                    } else if viewModel.blockedUsers.isEmpty {
                        emptyStateCard
                    } else {
                        blockedListCard
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .refreshable {
                await viewModel.loadBlockedUsers(using: authSession, force: true)
            }
        }
        .navigationTitle("Blocked")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadBlockedUsers(using: authSession)
        }
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
                    Task {
                        await viewModel.unblock(user, using: authSession)
                        userPendingUnblock = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                userPendingUnblock = nil
            }
        } message: {
            Text("They will be able to appear in your feed again once unblocked.")
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

            Text("People you block won’t appear in your feed or search results.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(.bottom, 4)
    }

    private var loadingCard: some View {
        sectionCard(title: "Loading") {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)

                Text("Fetching your blocked users.")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline)

                Spacer()
            }
        }
    }

    private var emptyStateCard: some View {
        sectionCard(title: "No blocked users") {
            Text("When you block someone from their profile, they’ll show up here so you can unblock them anytime.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var blockedListCard: some View {
        sectionCard(
            title: "Blocked",
            subtitle: viewModel.blockedUsers.count == 1
                ? "1 person"
                : "\(viewModel.blockedUsers.count) people"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.blockedUsers.enumerated()), id: \.element.id) { index, user in
                    blockedUserRow(user)

                    if index < viewModel.blockedUsers.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.12))
                    }
                }
            }
        }
    }

    private func blockedUserRow(_ user: BlockedUser) -> some View {
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
            .disabled(viewModel.isUpdating)
            .opacity(viewModel.isUpdating ? 0.55 : 1)
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

    private func messageCard(title: String, message: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(tint.opacity(0.22))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NavigationStack {
        BlockedView()
            .environmentObject(AuthSession())
    }
}
