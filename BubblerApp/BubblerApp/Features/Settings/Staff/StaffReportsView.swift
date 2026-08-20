import SwiftUI

struct StaffReportsView: View {
    @EnvironmentObject private var authSession: AuthSession
    @StateObject private var viewModel = StaffReportsViewModel()

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
                    statusFilter

                    if let errorMessage = viewModel.errorMessage {
                        messageCard(title: viewModel.errorTitle, message: errorMessage)
                    }

                    if viewModel.isLoading && viewModel.reports.isEmpty {
                        loadingCard
                    } else if viewModel.reports.isEmpty {
                        emptyStateCard
                    } else {
                        reportsList
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .refreshable {
                await viewModel.reload(using: authSession)
            }
        }
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.reload(using: authSession)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Report Queue")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Review open tickets and mark them triaged or closed. Removal stays a separate step.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(.bottom, 4)
    }

    private var statusFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StaffReportStatus.allCases) { status in
                    Button {
                        Task {
                            await viewModel.changeStatusFilter(status, using: authSession)
                        }
                    } label: {
                        Text(status.title)
                            .font(.caption.bold())
                            .foregroundColor(
                                viewModel.selectedStatus == status
                                    ? .black
                                    : .white.opacity(0.85)
                            )
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        viewModel.selectedStatus == status
                                            ? Color.white
                                            : Color.white.opacity(0.12)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var loadingCard: some View {
        sectionCard(title: "Loading") {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("Fetching reports.")
                    .foregroundColor(.white.opacity(0.9))
                    .font(.subheadline)
                Spacer()
            }
        }
    }

    private var emptyStateCard: some View {
        sectionCard(title: "No \(viewModel.selectedStatus.title.lowercased()) reports") {
            Text("When users report posts, matching tickets show up here for triage.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var reportsList: some View {
        sectionCard(
            title: viewModel.selectedStatus.title,
            subtitle: viewModel.reports.count == 1
                ? "1 ticket"
                : "\(viewModel.reports.count) tickets"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.reports.enumerated()), id: \.element.id) { index, report in
                    NavigationLink {
                        StaffReportDetailView(report: report)
                    } label: {
                        reportRow(report)
                    }
                    .buttonStyle(.plain)

                    if index < viewModel.reports.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.12))
                    }
                }
            }
        }
    }

    private func reportRow(_ report: StaffReport) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(report.reasonTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)

                Text(report.contentSnapshot)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)

                Text(metaLine(for: report))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 4)
        }
        .padding(.vertical, 12)
    }

    private func metaLine(for report: StaffReport) -> String {
        let author = report.authorUsernameSnapshot.map { "@\($0)" } ?? "unknown author"
        let when = report.createdAt.formatted(date: .abbreviated, time: .shortened)
        return "\(author) · \(when)"
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
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.65))
                    .tracking(1)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.55))
                }
            }

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

#Preview {
    NavigationStack {
        StaffReportsView()
            .environmentObject(AuthSession())
    }
}
