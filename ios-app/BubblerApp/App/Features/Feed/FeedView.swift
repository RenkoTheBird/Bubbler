struct FeedView: View {
    @StateObject var vm = FeedViewModel()

    var body: some View {
        List(vm.posts) { post in
            PostView(post: post)
        }
        .onAppear { vm.loadFeed() }
    }
}