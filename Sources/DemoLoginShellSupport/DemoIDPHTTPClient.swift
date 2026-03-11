import DemoShared
import Foundation

public protocol DemoIDPAuthenticating: Sendable {
    func login(username: String, password: String) async throws -> DemoTokenResponse
}

public struct DemoIDPHTTPClient: DemoIDPAuthenticating, PluginRemoteIDPValidating {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func checkHealth() async throws {
        let request = URLRequest(url: baseURL.appendingPathComponent("api/health"))
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DemoAuthError.serviceUnavailable
        }
    }

    public func login(username: String, password: String) async throws -> DemoTokenResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(DemoLoginRequest(username: username, password: password))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DemoAuthError.serviceUnavailable
        }
        guard let http = response as? HTTPURLResponse else {
            throw DemoAuthError.serviceUnavailable
        }

        guard http.statusCode == 200 else {
            throw DemoAuthError.invalidCredentials
        }

        return try JSONDecoder().decode(DemoTokenResponse.self, from: data)
    }
}
