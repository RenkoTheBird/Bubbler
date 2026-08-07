//
//  DeleteAccountView.swift
//  BubblerApp
//

import SwiftUI
import Combine

struct DeleteAccountView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = DeleteAccountViewModel()
    @State private var showDeleteConfirmation = false

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

                    if viewModel.isLoading {
                        loadingCard
                    } else {
                        warningCard
                        passwordForm
                        deleteSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Delete Account")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(using: authSession)
        }
        .confirmationDialog(
            "Delete your account permanently?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                Task {
                    await viewModel.deleteAccount(using: authSession)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently remove your Bubbler account and data. This cannot be undone.")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Delete Account")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Permanently close your Bubbler account after confirming your password.")
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

                Text("Preparing account deletion.")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline)

                Spacer()
            }
        }
    }

    private var warningCard: some View {
        sectionCard(
            title: "Before you continue",
            subtitle: viewModel.accountEmail.isEmpty
                ? nil
                : "Signed in as \(viewModel.accountEmail)."
        ) {
            Text("Deleting your account removes your profile, posts, and preferences. This action is permanent.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private var passwordForm: some View {
        sectionCard(
            title: "Confirm Password",
            subtitle: "Retype your password to authorize account deletion."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption)

                SecureField("Enter your password", text: $viewModel.password)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(14)
                    .foregroundColor(.white)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }

    private var deleteSection: some View {
        Button {
            showDeleteConfirmation = true
        } label: {
            HStack {
                if viewModel.isDeleting {
                    ProgressView()
                        .tint(.white)
                }

                Text(viewModel.isDeleting ? "Deleting..." : "Delete Account")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red.opacity(0.9))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .disabled(!viewModel.canDelete)
        .opacity(viewModel.canDelete ? 1 : 0.55)
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
        DeleteAccountView()
            .environmentObject(AuthSession())
    }
}
