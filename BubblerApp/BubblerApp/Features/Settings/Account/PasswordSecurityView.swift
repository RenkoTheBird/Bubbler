//
//  PasswordSecurityView.swift
//  BubblerApp
//

import SwiftUI
import Combine

struct PasswordSecurityView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = PasswordSecurityViewModel()
    @State private var showResetConfirmation = false

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
                        logoutNoticeCard
                        passwordForm
                        resetSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Password & Security")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(using: authSession)
        }
        .confirmationDialog(
            "Reset your password?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Password") {
                Task {
                    await viewModel.resetPassword(using: authSession)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will be logged out and must sign in again with your new password.")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Password & Security")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Reset your password after confirming your account details.")
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

                Text("Preparing password reset.")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline)

                Spacer()
            }
        }
    }

    private var logoutNoticeCard: some View {
        sectionCard(
            title: "You'll be signed out",
            subtitle: accountSubtitle
        ) {
            Text("After a successful reset, your session ends immediately. Log back in with your new password to continue.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
        }
    }

    private var accountSubtitle: String? {
        if !viewModel.accountEmail.isEmpty {
            return "Signed in as \(viewModel.accountEmail)."
        }
        if !viewModel.accountUsername.isEmpty {
            return "Signed in as @\(viewModel.accountUsername)."
        }
        return nil
    }

    private var passwordForm: some View {
        sectionCard(
            title: "Reset Password",
            subtitle: "Confirm your identity, then choose a new password."
        ) {
            VStack(spacing: 14) {
                formField(label: "Current Email or Username") {
                    TextField("Enter your email or username", text: $viewModel.emailOrUsername)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)
                        .textContentType(.username)
                }

                formField(label: "Current Password") {
                    SecureField("Enter your current password", text: $viewModel.currentPassword)
                        .textContentType(.password)
                }

                formField(label: "New Password") {
                    SecureField("Create a new password", text: $viewModel.newPassword)
                        .textContentType(.newPassword)
                }

                formField(label: "Confirm New Password") {
                    SecureField("Re-enter your new password", text: $viewModel.confirmNewPassword)
                        .textContentType(.newPassword)
                }
            }
        }
    }

    private var resetSection: some View {
        Button {
            showResetConfirmation = true
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.black)
                }

                Text(viewModel.isSaving ? "Resetting..." : "Reset Password")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .foregroundColor(.black)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .disabled(!viewModel.canReset)
        .opacity(viewModel.canReset ? 1 : 0.55)
    }

    private func formField<Content: View>(
        label: String,
        @ViewBuilder field: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .foregroundColor(.white.opacity(0.8))
                .font(.caption)

            field()
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(14)
                .foregroundColor(.white)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
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
        PasswordSecurityView()
            .environmentObject(AuthSession())
    }
}
