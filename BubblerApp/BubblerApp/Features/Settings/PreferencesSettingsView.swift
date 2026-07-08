//
//  PreferencesSettingsView.swift
//  BubblerApp
//

import SwiftUI

struct PreferencesSettingsView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = PreferencesSettingsViewModel()

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
                        PreferenceMessageCard(
                            title: viewModel.errorTitle,
                            message: errorMessage,
                            tint: .red
                        )
                    }

                    if let successMessage = viewModel.successMessage {
                        PreferenceMessageCard(
                            title: "Preferences updated",
                            message: successMessage,
                            tint: .green
                        )
                    }

                    if viewModel.isLoading {
                        loadingCard
                    } else {
                        tuningSection
                        strategySection
                        topicSections
                        behaviorSection
                        saveSection
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPreferences(using: authSession)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Recommendation Preferences")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Tune how much variety, randomness, and topic weighting shape your feed.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(.bottom, 4)
    }

    private var loadingCard: some View {
        PreferenceSectionCard(title: "Loading") {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)

                Text("Fetching your saved preference profile.")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline)

                Spacer()
            }
        }
    }

    private var tuningSection: some View {
        PreferenceSectionCard(
            title: "Core Tuning",
            subtitle: "Higher diversity broadens your bubble. Higher randomness introduces more unexpected posts."
        ) {
            PreferenceSliderRow(
                title: "Diversity",
                value: $viewModel.preferences.diversityTolerance,
                tint: .cyan
            )
            PreferenceSliderRow(
                title: "Randomness",
                value: $viewModel.preferences.randomness,
                tint: .purple
            )
        }
    }

    private var strategySection: some View {
        PreferenceSectionCard(
            title: "Feed Composition",
            subtitle: "These weights are normalized automatically when you save."
        ) {
            PreferenceSliderRow(
                title: "Similar",
                value: $viewModel.preferences.strategyWeights.similar,
                tint: .blue
            )
            PreferenceSliderRow(
                title: "Graph",
                value: $viewModel.preferences.strategyWeights.graph,
                tint: .teal
            )
            PreferenceSliderRow(
                title: "Opposite",
                value: $viewModel.preferences.strategyWeights.opposite,
                tint: .indigo
            )
            PreferenceSliderRow(
                title: "Random",
                value: $viewModel.preferences.strategyWeights.random,
                tint: .pink
            )

            HStack {
                Text("Current total")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.65))

                Spacer()

                Text("\(Int((viewModel.strategyTotal * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.75))
            }
        }
    }

    private var topicSections: some View {
        VStack(spacing: 20) {
            PreferenceTopicsEditor(
                title: "Preferred Topics",
                subtitle: "These topics get extra weight in your bubble.",
                icon: "heart.fill",
                iconColor: .pink,
                topics: Binding(
                    get: { viewModel.preferences.preferredTopics },
                    set: { viewModel.preferences.updatePreferredTopics($0) }
                ),
                conflictingTopics: Binding(
                    get: { viewModel.preferences.blacklistedTopics },
                    set: { viewModel.preferences.updateBlacklistedTopics($0) }
                )
            )

            PreferenceTopicsEditor(
                title: "Blacklisted Topics",
                subtitle: "These topics are filtered out of your recommendations.",
                icon: "nosign",
                iconColor: .orange,
                topics: Binding(
                    get: { viewModel.preferences.blacklistedTopics },
                    set: { viewModel.preferences.updateBlacklistedTopics($0) }
                ),
                conflictingTopics: Binding(
                    get: { viewModel.preferences.preferredTopics },
                    set: { viewModel.preferences.updatePreferredTopics($0) }
                )
            )
        }
    }

    private var behaviorSection: some View {
        PreferenceSectionCard(
            title: "Behavior Signals",
            subtitle: "Enable view-time feedback if you want watch time to influence recommendations."
        ) {
            Toggle(isOn: $viewModel.preferences.useViewTime) {
                Text("Use View Time")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(SwitchToggleStyle(tint: .cyan))

            PreferenceSliderRow(
                title: "View Time Weight",
                value: $viewModel.preferences.viewTimeWeight,
                tint: .green,
                isDisabled: !viewModel.preferences.useViewTime
            )
        }
    }

    private var saveSection: some View {
        VStack(spacing: 14) {
            Button {
                Task {
                    await viewModel.savePreferences(using: authSession)
                }
            } label: {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.black)
                    }

                    Text(viewModel.isSaving ? "Saving..." : "Save Preferences")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(viewModel.isSaving)

            Button("Reload from Server") {
                Task {
                    await viewModel.reloadPreferences(using: authSession)
                }
            }
            .foregroundColor(.white.opacity(0.78))
            .font(.subheadline)
        }
    }
}

private struct PreferenceSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
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

            content
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
}

private struct PreferenceMessageCard: View {
    let title: String
    let message: String
    let tint: Color

    var body: some View {
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
        PreferencesSettingsView()
            .environmentObject(AuthSession())
    }
}
