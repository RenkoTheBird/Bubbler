//
//  PreferencesAdvancedSettingsView.swift
//  BubblerApp
//

import SwiftUI

struct PreferencesAdvancedSettingsView: View {
    @EnvironmentObject private var authSession: AuthSession
    @ObservedObject var viewModel: PreferencesSettingsViewModel

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

                    topicCompositionSection
                    postCompositionSection
                    behaviorSection
                    saveSection
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Advanced")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var topicCompositionSection: some View {
        PreferenceSectionCard(
            title: "Topic Composition",
            subtitle: "How your walk chooses the next topics."
        ) {
            PreferenceSliderRow(
                title: "Similar",
                value: topicSimilarBinding,
                tint: .blue
            )
            PreferenceSliderRow(
                title: "Opposite",
                value: topicOppositeBinding,
                tint: .indigo
            )
            PreferenceSliderRow(
                title: "Surprise",
                value: topicSurpriseBinding,
                tint: .pink
            )

            compositionTotalLabel(viewModel.topicCompositionTotal)
        }
    }

    private var postCompositionSection: some View {
        PreferenceSectionCard(
            title: "Post Composition",
            subtitle: "How posts are chosen within each topic."
        ) {
            PreferenceSliderRow(
                title: "Similar",
                value: postSimilarBinding,
                tint: .teal
            )
            PreferenceSliderRow(
                title: "Opposite",
                value: postOppositeBinding,
                tint: .purple
            )
            PreferenceSliderRow(
                title: "Surprise",
                value: postSurpriseBinding,
                tint: .orange
            )

            compositionTotalLabel(viewModel.postCompositionTotal)
        }
    }

    private var behaviorSection: some View {
        PreferenceSectionCard(
            title: "Behavior Signals",
            subtitle: "Optional signals that refine recommendations over time."
        ) {
            Toggle(isOn: $viewModel.preferences.useViewTime) {
                Text("Use View Time")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline.weight(.semibold))
            }
            .toggleStyle(SwitchToggleStyle(tint: .cyan))
            .onChange(of: viewModel.preferences.useViewTime) { _, _ in
                viewModel.markCompositionCustomIfNeeded()
            }

            PreferenceSliderRow(
                title: "View Time Weight",
                value: $viewModel.preferences.viewTimeWeight,
                tint: .green,
                isDisabled: !viewModel.preferences.useViewTime
            )

            aiTopicSection
        }
    }

    private var aiTopicSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Contribute Topic Classifications")
                    .foregroundColor(.white.opacity(
                        PreferencesSettingsViewModel.isAITopicDetectionAvailable ? 0.9 : 0.55
                    ))
                    .font(.subheadline.weight(.semibold))

                if !PreferencesSettingsViewModel.isAITopicDetectionAvailable {
                    Text("Unavailable")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            Spacer()

            Toggle(
                "",
                isOn: PreferencesSettingsViewModel.isAITopicDetectionAvailable
                    ? $viewModel.preferences.aiTopicDetection
                    : .constant(false)
            )
            .labelsHidden()
            .toggleStyle(SwitchToggleStyle(tint: .mint))
            .disabled(!PreferencesSettingsViewModel.isAITopicDetectionAvailable)
            .opacity(PreferencesSettingsViewModel.isAITopicDetectionAvailable ? 1 : 0.45)
        }
    }

    private var saveSection: some View {
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
    }

    private func compositionTotalLabel(_ total: Double) -> some View {
        HStack {
            Text("Current total")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.65))

            Spacer()

            Text("\(Int((total * 100).rounded()))%")
                .font(.caption.monospacedDigit())
                .foregroundColor(.white.opacity(0.75))
        }
    }

    private var topicSimilarBinding: Binding<Double> {
        Binding(
            get: { viewModel.preferences.topicComposition.similar },
            set: { viewModel.updateTopicComposition(similar: $0) }
        )
    }

    private var topicOppositeBinding: Binding<Double> {
        Binding(
            get: { viewModel.preferences.topicComposition.opposite },
            set: { viewModel.updateTopicComposition(opposite: $0) }
        )
    }

    private var topicSurpriseBinding: Binding<Double> {
        Binding(
            get: { viewModel.preferences.topicComposition.surprise },
            set: { viewModel.updateTopicComposition(surprise: $0) }
        )
    }

    private var postSimilarBinding: Binding<Double> {
        Binding(
            get: { viewModel.preferences.postComposition.similar },
            set: { viewModel.updatePostComposition(similar: $0) }
        )
    }

    private var postOppositeBinding: Binding<Double> {
        Binding(
            get: { viewModel.preferences.postComposition.opposite },
            set: { viewModel.updatePostComposition(opposite: $0) }
        )
    }

    private var postSurpriseBinding: Binding<Double> {
        Binding(
            get: { viewModel.preferences.postComposition.surprise },
            set: { viewModel.updatePostComposition(surprise: $0) }
        )
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
