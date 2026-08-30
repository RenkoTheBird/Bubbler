//
//  OnboardingView.swift
//  BubblerApp
//

import Combine
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.blue.opacity(1.8),
                    Color.cyan.opacity(0.7),
                    Color.blue.opacity(1.2),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 24)

                    VStack(spacing: 12) {
                        BubblerLogoView()
                            .frame(width: 88, height: 88)

                        Text("Choose your feed style")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)

                        Text("Pick how adventurous your Bubble path should be. You can change this anytime in Settings, including advanced topic and ranking controls.")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 24)
                    } else {
                        FeedPresetPicker(
                            selectedPreset: Binding(
                                get: { viewModel.preferences.feedPreset },
                                set: { viewModel.selectPreset($0) }
                            ),
                            onSelect: { viewModel.selectPreset($0) }
                        )
                    }

                    VStack(spacing: 12) {
                        Button {
                            Task {
                                _ = await viewModel.completeOnboarding(using: authSession)
                            }
                        } label: {
                            Group {
                                if viewModel.isSaving {
                                    ProgressView()
                                        .tint(.blue)
                                } else {
                                    Text("Continue")
                                        .font(.headline)
                                }
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(14)
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .disabled(viewModel.isLoading || viewModel.isSaving)

                        Button {
                            Task {
                                _ = await viewModel.useRecommendedDefaults(using: authSession)
                            }
                        } label: {
                            Text("Use recommended settings")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .disabled(viewModel.isLoading || viewModel.isSaving)
                    }
                    .padding(.top, 8)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
            }
        }
        .task {
            await viewModel.loadPreferences(using: authSession)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AuthSession())
}
