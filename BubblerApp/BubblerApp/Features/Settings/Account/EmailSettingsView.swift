//
//  EmailSettingsView.swift
//  BubblerApp
//

import SwiftUI
import Combine

struct EmailSettingsView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = EmailSettingsViewModel()

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

                    if let successMessage = viewModel.successMessage {
                        messageCard(
                            title: "Email updated",
                            message: successMessage,
                            tint: .green
                        )
                    }

                    if viewModel.isLoading {
                        loadingCard
                    } else {
                        emailForm
                        saveSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Email Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(using: authSession)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Email Address")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Update the email used to sign in to your Bubbler account.")
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

                Text("Fetching your current email.")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline)

                Spacer()
            }
        }
    }

    private var emailForm: some View {
        sectionCard(
            title: "Contact Email",
            subtitle: viewModel.currentEmail.isEmpty
                ? nil
                : "Currently signed in as \(viewModel.currentEmail)."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption)

                TextField("Enter your email", text: $viewModel.email)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(14)
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
            }
        }
    }

    private var saveSection: some View {
        Button {
            Task {
                await viewModel.saveEmail(using: authSession)
            }
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .tint(.black)
                }

                Text(viewModel.isSaving ? "Saving..." : "Save Email")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .foregroundColor(.black)
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .disabled(!viewModel.canSave)
        .opacity(viewModel.canSave ? 1 : 0.55)
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
        EmailSettingsView()
            .environmentObject(AuthSession())
    }
}
