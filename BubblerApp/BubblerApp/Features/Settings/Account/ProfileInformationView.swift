//
//  ProfileInformationView.swift
//  BubblerApp
//

import SwiftUI
import Combine

struct ProfileInformationView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = ProfileInformationViewModel()

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
                            title: "Couldn't load profile",
                            message: errorMessage,
                            tint: .red
                        )
                    }

                    if viewModel.isLoading {
                        loadingCard
                    } else if let profile = viewModel.profile {
                        infoSection(profile)
                    }

                    Button("Reload from Server") {
                        Task {
                            await viewModel.reload(using: authSession)
                        }
                    }
                    .foregroundColor(.white.opacity(0.78))
                    .font(.subheadline)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Profile Information")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(using: authSession)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Your Account")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Username and account details from your Bubbler profile.")
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

                Text("Fetching your profile.")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline)

                Spacer()
            }
        }
    }

    private func infoSection(_ profile: User) -> some View {
        sectionCard(title: "Profile Details") {
            infoRow(label: "Username", value: "@\(profile.username)")
            infoRow(label: "Email", value: profile.email)
            infoRow(label: "Member since", value: viewModel.memberSinceText)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.6))

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.95))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            content()
        }
        .padding(18)
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
        ProfileInformationView()
            .environmentObject(AuthSession())
    }
}
