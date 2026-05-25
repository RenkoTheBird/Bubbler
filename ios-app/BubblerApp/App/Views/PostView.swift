import SwiftUI

struct PostView: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(post.content).font(.body)

        HStack {
            Text(post.topic ?? "General").font(.caption).foregroundColor(.blue)

        Spacer()

        Text(post.createdAt, style: .time).font(.caption).foregroundColor(.gray)
        }
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .cornerRadius(10)
    }
}
    


