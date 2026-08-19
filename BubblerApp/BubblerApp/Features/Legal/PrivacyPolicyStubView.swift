import SwiftUI

/// Placeholder until the published Privacy Policy ships (roadmap L1).
struct PrivacyPolicyStubView: View {
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
                VStack(alignment: .leading, spacing: 16) {
                    Text("Privacy Policy")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("This policy isn't published yet.")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.9))

                    Text("When it ships, this page will explain what Bubbler collects, how reports and other data are used, how long they are kept, and the rights you have over your information.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyStubView()
    }
}
