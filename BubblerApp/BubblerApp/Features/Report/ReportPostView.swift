import SwiftUI

struct ReportPostView: View {
    let post: Post

    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReportPostViewModel()

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

            TextEditor(text: $viewModel.comments)
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

    private var submitButton: some View {
        Button {
            if viewModel.submit() {
                dismiss()
            }
        } label: {
            Text("Submit Report")
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
    }
}
