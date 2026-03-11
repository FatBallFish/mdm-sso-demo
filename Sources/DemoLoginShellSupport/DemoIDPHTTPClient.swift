import DemoShared
import Foundation

public protocol DemoIDPAuthenticating: Sendable {
    func login(username: String, password: String) async throws -> DemoTokenResponse
}

public struct DemoIDPHTTPClient: DemoIDPAuthenticating {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func login(username: String, password: String) async throws -> DemoTokenResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DemoLoginRequest(username: username, password: password))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DemoAuthError.invalidCredentials
        }

        guard http.statusCode == 200 else {
            throw DemoAuthError.invalidCredentials
        }

        return try JSONDecoder().decode(DemoTokenResponse.self, from: data)
    }
}
