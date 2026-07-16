//
//  BubbleTrailView.swift
//  BubblerApp
//

import SwiftUI

/// Signed-in user's interaction history (likes, skips, explores).
struct BubbleTrailView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = BubbleTrailViewModel()

    var body: some View {
        ZStack {
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
                VStack(alignment: .leading, spacing: 14) {
                    Spacer()
                        .frame(height: 12)

                    Text("Your recent interactions across Bubbler.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                        .padding(.horizontal, 20)

                    if viewModel.isLoading && viewModel.interactions.isEmpty {
                        trailRow("Loading your bubble trail…")
                    } else if let errorMessage = viewModel.errorMessage {
                        trailRow(errorMessage)
                    } else if viewModel.interactions.isEmpty {
                        trailRow("Your bubble trail will appear here once you start interacting with posts.")
                    } else {
                        ForEach(viewModel.interactions) { interaction in
                            trailRow(interaction.trailSummary)
                        }
                    }

                    Spacer().frame(height: 40)
                }
            }
        }
        .navigationTitle("Bubble Trail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await viewModel.load(using: authSession)
        }
    }

    private func trailRow(_ text: String) -> some View {
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

@MainActor
final class BubbleTrailViewModel: ObservableObject {
    @Published private(set) var interactions: [Interaction] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var hasLoaded = false

    func load(using authSession: AuthSession, force: Bool = false) async {
        guard force || !hasLoaded else { return }

        isLoading = true
        errorMessage = nil

        do {
            interactions = try await APIClient.getMyInteractions()
            hasLoaded = true
        } catch {
            if case APIClientError.unauthorized = error {
                authSession.signOut()
            }
            let description = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            errorMessage = description.isEmpty
                ? "We couldn't load your bubble trail."
                : description
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        BubbleTrailView()
            .environmentObject(AuthSession())
    }
}
