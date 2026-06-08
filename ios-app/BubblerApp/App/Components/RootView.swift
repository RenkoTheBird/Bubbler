struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        if auth.isLoggedIn {
            FeedView()
        } else {
            LoginView()
        }
    }
}