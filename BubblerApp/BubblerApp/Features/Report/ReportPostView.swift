import Combine
import SwiftUI

struct ReportPostView: View {
    let post: Post

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = ReportPostViewModel()

    private var blockableUsername: String? {
        guard let username = post.username?.trimmingCharacters(in: .whitespacesAndNewlines),
              !username.isEmpty else {
            return nil
        }
        return username
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.red.opacity(0.55),
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
                    postPreview
                    reasonSection
                    commentsSection
                    if blockableUsername != nil {
                        blockUserSection
                    }
                    privacyPolicyLink

                    if let errorMessage = viewModel.errorMessage {
                        messageCard(errorMessage)
                    }

                    submitButton
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Report Post")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Report this post")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.white)

            Text("Choose a reason. You can add extra context if it helps.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var postPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("POST")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.65))
                .tracking(1)

            Text(post.content)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(4)

            Text("Posted by \(post.authorLabel)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reason")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 0) {
                ForEach(Array(ReportReason.allCases.enumerated()), id: \.element.id) { index, reason in
                    if index > 0 {
                        Divider()
                            .background(Color.white.opacity(0.12))
                    }

                    Button {
                        viewModel.selectedReason = reason
                        viewModel.errorMessage = nil
                    } label: {
                        HStack {
                            Text(reason.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white)

                            Spacer()

                            if viewModel.selectedReason == reason {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(viewModel.selectedReason == reason ? [.isSelected] : [])
                }
            }
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Other comments")
                .font(.headline)
                .foregroundColor(.white)

            TextEditor(
                text: Binding(
                    get: { viewModel.comments },
                    set: { viewModel.updateComments($0) }
                )
            )
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(12)
                .foregroundColor(.white)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .accessibilityLabel("Other comments")
        }
    }

    private var blockUserSection: some View {
        Button {
            viewModel.alsoBlockUser.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: viewModel.alsoBlockUser ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Block this user too")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)

                    Text("Hide their posts from your feed.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isSubmitting)
        .accessibilityLabel("Block this user too")
        .accessibilityAddTraits(viewModel.alsoBlockUser ? [.isToggle, .isSelected] : [.isToggle])
        .accessibilityValue(viewModel.alsoBlockUser ? "On" : "Off")
    }

    private var privacyPolicyLink: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How we handle the information in this report")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.75))

            NavigationLink {
                PrivacyPolicyStubView()
            } label: {
                Text("Privacy Policy")
                    .font(.subheadline.weight(.semibold))
                    .underline()
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Privacy Policy")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var submitButton: some View {
        Button {
            Task {
                if await viewModel.submit(blockUsername: blockableUsername, using: authSession) {
                    dismiss()
                }
            }
        } label: {
            Group {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Submit Report")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(viewModel.canSubmit ? Color.red.opacity(0.85) : Color.white.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(!viewModel.canSubmit)
        .buttonStyle(.plain)
        .accessibilityLabel("Submit Report")
    }

    private func messageCard(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.red.opacity(0.25))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.4), lineWidth: 1)
                    )
            )
    }
}

#Preview {
    NavigationStack {
        ReportPostView(
            post: Post(
                id: "preview-post",
                userId: 0,
                username: "preview",
                content: "A sample bubble post for the report form preview.",
                createdAt: .now.addingTimeInterval(-2_700),
                topic: nil,
                embedding: nil
            )
        )
        .environmentObject(AuthSession())
    }
}
