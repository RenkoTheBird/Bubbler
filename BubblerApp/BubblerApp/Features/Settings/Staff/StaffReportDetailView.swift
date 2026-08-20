import SwiftUI

struct StaffReportDetailView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel: StaffReportDetailViewModel

    init(report: StaffReport) {
        _viewModel = StateObject(
            wrappedValue: StaffReportDetailViewModel(
                reportId: report.id,
                initialReport: report
            )
        )
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color.blue.opacity(0.55),
                    Color.indigo.opacity(0.85),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if let errorMessage = viewModel.errorMessage {
                        messageCard(title: viewModel.errorTitle, message: errorMessage)
                    }

                    if viewModel.isLoading && viewModel.report == nil {
                        loadingCard
                    } else if let report = viewModel.report {
                        snapshotCard(report)
                        identityCard(report)
                        detailsCard(report)
                        actionsCard(report)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .refreshable {
                await viewModel.load(using: authSession, force: true)
            }
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(using: authSession)
        }
    }

    private var loadingCard: some View {
        sectionCard(title: "Loading") {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Fetching ticket details.")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline)
                Spacer()
            }
        }
    }

    private func snapshotCard(_ report: StaffReport) -> some View {
        sectionCard(title: "Snapshot") {
            VStack(alignment: .leading, spacing: 10) {
                Text(report.contentSnapshot)
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if let topic = report.topicSnapshot, !topic.isEmpty {
                    Text("Topic: \(topic)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Text(report.status.title.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
            }
        }
    }

    private func identityCard(_ report: StaffReport) -> some View {
        sectionCard(title: "Identifiers") {
            VStack(alignment: .leading, spacing: 10) {
                infoRow("Reason", report.reasonTitle)
                infoRow("Reporter ID", report.reporterId.map(String.init) ?? "—")
                infoRow("Post ID", report.postId ?? "—")
                infoRow("Author ID", report.reportedUserId.map(String.init) ?? "—")
                infoRow(
                    "Author",
                    report.authorUsernameSnapshot.map { "@\($0)" } ?? "—"
                )
                infoRow(
                    "Created",
                    report.createdAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
    }

    private func detailsCard(_ report: StaffReport) -> some View {
        sectionCard(title: "Reporter notes") {
            Text(report.details?.isEmpty == false ? report.details! : "No extra details.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func actionsCard(_ report: StaffReport) -> some View {
        sectionCard(title: "Triage") {
            VStack(spacing: 10) {
                Text("Mark the ticket without removing content. Enforcement is a later step.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if report.status != .inReview {
                    actionButton("Mark In Review", disabled: viewModel.isUpdating) {
                        Task { await viewModel.updateStatus(.inReview, using: authSession) }
                    }
                }
                if report.status != .resolved {
                    actionButton("Resolve", disabled: viewModel.isUpdating) {
                        Task { await viewModel.updateStatus(.resolved, using: authSession) }
                    }
                }
                if report.status != .dismissed {
                    actionButton("Dismiss", disabled: viewModel.isUpdating) {
                        Task { await viewModel.updateStatus(.dismissed, using: authSession) }
                    }
                }
            }
        }
    }

    private func actionButton(
        _ title: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if viewModel.isUpdating {
                    ProgressView()
                        .tint(.white)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
                .frame(width: 88, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func messageCard(title: String, message: String) -> some View {
        sectionCard(title: title) {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.65))
                .tracking(1)
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
