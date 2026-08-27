//
//  PreferencesSettingsView.swift
//  BubblerApp
//

import SwiftUI
import Combine

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
                        feedCompositionSection
                        recencySection
                        topicSections
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
            await viewModel.refreshFromServer(using: authSession)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Recommendation Preferences")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Choose how your bubble explores topics and posts.")
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

    private var feedCompositionSection: some View {
        PreferenceSectionCard(
            title: "Feed Composition",
            subtitle: "Pick a preset that matches how you want to explore."
        ) {
            FeedPresetPicker(
                selectedPreset: Binding(
                    get: { viewModel.preferences.feedPreset },
                    set: { viewModel.preferences.feedPreset = $0 }
                ),
                onSelect: { preset in
                    viewModel.selectPreset(preset)
                }
            )

            NavigationLink {
                PreferencesAdvancedSettingsView(viewModel: viewModel)
            } label: {
                HStack {
                    Text("Advanced feed settings")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white.opacity(0.9))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.top, 8)
            }
            .buttonStyle(.plain)
        }
    }

    private var recencySection: some View {
        PreferenceSectionCard(
            title: "Recency",
            subtitle: "Boost newer posts when ranking candidates."
        ) {
            Toggle(isOn: $viewModel.preferences.useRecency) {
                Text("Prioritize Recent Posts")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(SwitchToggleStyle(tint: .orange))
        }
    }

    private var topicSections: some View {
        VStack(spacing: 20) {
            PreferenceTopicsEditor(
                title: "Preferred Topics",
                subtitle: "Search existing topics to give them extra weight in your bubble.",
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
                subtitle: "Search existing topics to filter them out of your recommendations.",
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

            Button {
                viewModel.restoreDefaults()
            } label: {
                Text("Restore Defaults")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundColor(.white.opacity(0.9))
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
            .disabled(viewModel.isSaving)

            Button("Reload from Server") {
                Task {
                    await viewModel.reloadPreferences(using: authSession)
                }
            }
            .foregroundColor(.white.opacity(0.78))
            .font(.subheadline)
            .disabled(viewModel.isSaving)
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
