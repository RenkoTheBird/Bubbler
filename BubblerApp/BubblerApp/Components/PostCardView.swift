struct PostView: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading) {
            Text(post.author.username)
                .font(.headline)

            Text(post.content)
        }
        .padding()
    }
}