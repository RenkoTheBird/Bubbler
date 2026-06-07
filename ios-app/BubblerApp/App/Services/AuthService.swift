class AuthService: ObservableObject {
    @Published var token: String?

    func login(email: String, password: String) {
        // call APIClient
    }
}