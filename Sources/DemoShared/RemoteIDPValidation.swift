public protocol PluginRemoteIDPValidating: Sendable {
    func checkHealth() async throws
    func login(username: String, password: String) async throws -> DemoTokenResponse
}
