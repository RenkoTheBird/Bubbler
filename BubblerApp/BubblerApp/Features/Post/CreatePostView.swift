import SwiftUI
import Combine

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel: CreatePostViewModel

    private let onSuccess: ((String) -> Void)?

    private var accentColor: Color {
        TopicStyle.color(for: viewModel.selectedTopic)
    }

    init(post: Post? = nil, onSuccess: ((String) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: CreatePostViewModel(post: post))
        self.onSuccess = onSuccess
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accentColor.opacity(0.75),
                    Color.black.opacity(0.7),
                    Color.black.opacity(0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    contentSection

                    TopicPicker(selectedTopic: $viewModel.selectedTopic)

                    if let errorMessage = viewModel.errorMessage {
                        messageCard(errorMessage, tint: .red.opacity(0.8))
                    }

                    postButton
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit Post" : "New Post")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.isEditing ? "Edit Bubble" : "Share a Bubble")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text(
                viewModel.isEditing
                    ? "Update your post content or topic."
                    : "Write your post and pick a topic for the feed."
            )
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Content")
                .font(.headline)
                .foregroundColor(.white)

            TextEditor(text: $viewModel.content)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(12)
                .foregroundColor(.white)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private var postButton: some View {
        Button {
            Task {
                if let content = await viewModel.submit(using: authSession) {
                    onSuccess?(content)
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 10) {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(.white)
                }

                Text(submitButtonTitle)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(viewModel.canSubmit ? accentColor.opacity(0.85) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(!viewModel.canSubmit)
        .buttonStyle(.plain)
    }

    private var submitButtonTitle: String {
        if viewModel.isSubmitting {
            return viewModel.isEditing ? "Saving..." : "Posting..."
        }
        return viewModel.isEditing ? "Save Changes" : "Post to Bubbler"
    }

    private func messageCard(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(tint.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(tint.opacity(0.4), lineWidth: 1)
                    )
            )
    }
}

#Preview {
    NavigationStack {
        CreatePostView()
            .environmentObject(AuthSession())
    }
}
