class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []

    func loadFeed() {
        APIClient.shared.get("/feed") { (result: [Post]) in
            DispatchQueue.main.async {
                self.posts = result
            }
        }
    }
}