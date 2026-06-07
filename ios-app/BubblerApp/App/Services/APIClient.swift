class APIClient {
    static let shared = APIClient()

    func get<T: Decodable>(_ path: String, completion: @escaping (T) -> Void) {
        let url = URL(string: "https://api.bubbler.com\(path)")!
        URLSession.shared.dataTask(with: url) { data, _, _ in
            let decoded = try! JSONDecoder().decode(T.self, from: data!)
            completion(decoded)
        }.resume()
    }
}