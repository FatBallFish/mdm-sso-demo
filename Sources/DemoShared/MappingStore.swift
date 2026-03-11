import Foundation

public final class MappingStore: @unchecked Sendable {
    private let baseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(baseURL: URL) {
        self.baseURL = baseURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    public func save(_ record: AccountMapping) throws {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        let data = try encoder.encode(record)
        try data.write(to: recordURL(subject: record.ssoSubject), options: .atomic)
    }

    public func load(subject: String) throws -> AccountMapping? {
        let url = recordURL(subject: subject)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try decoder.decode(AccountMapping.self, from: data)
    }

    private func recordURL(subject: String) -> URL {
        baseURL.appendingPathComponent("\(subject).json")
    }
}
