import DemoShared
import Foundation
import Network

private enum ServerError: Error {
    case invalidMethod
    case invalidPath
    case invalidBody
}

private struct HTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

private struct HTTPResponse {
    let statusCode: Int
    let reasonPhrase: String
    let body: Data
    let contentType: String

    static func json<T: Encodable>(_ value: T, statusCode: Int = 200, reasonPhrase: String = "OK") throws -> HTTPResponse {
        let body = try JSONEncoder().encode(value)
        return HTTPResponse(statusCode: statusCode, reasonPhrase: reasonPhrase, body: body, contentType: "application/json")
    }

    func serialize() -> Data {
        var header = ""
        header += "HTTP/1.1 \(statusCode) \(reasonPhrase)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"

        var data = Data(header.utf8)
        data.append(body)
        return data
    }
}

private final class DemoHTTPServer: @unchecked Sendable {
    private let listener: NWListener
    private let authenticator: DemoAuthenticator

    init(host: NWEndpoint.Host, port: NWEndpoint.Port, authenticator: DemoAuthenticator) throws {
        self.listener = try NWListener(using: .tcp, on: port)
        self.authenticator = authenticator
        listener.service = nil
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("DemoIDPServer listening on http://\(host):\(port.rawValue)")
            case let .failed(error):
                fputs("listener failed: \(error)\n", stderr)
                exit(1)
            default:
                break
            }
        }
    }

    func start() -> Never {
        listener.start(queue: .global(qos: .userInitiated))
        dispatchMain()
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))
        receiveAll(on: connection, accumulated: Data())
    }

    private func receiveAll(on connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            if let error {
                fputs("connection receive error: \(error)\n", stderr)
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let data {
                buffer.append(data)
            }

            if self?.isRequestComplete(buffer) == true || isComplete {
                self?.respond(on: connection, rawRequest: buffer)
            } else {
                self?.receiveAll(on: connection, accumulated: buffer)
            }
        }
    }

    private func respond(on connection: NWConnection, rawRequest: Data) {
        let response: HTTPResponse

        do {
            let request = try parse(requestData: rawRequest)
            response = try route(request: request)
        } catch DemoAuthError.invalidCredentials {
            response = try! .json(
                DemoErrorResponse(error: "invalid_credentials", message: "Username or password is not valid."),
                statusCode: 401,
                reasonPhrase: "Unauthorized"
            )
        } catch DemoAuthError.invalidRefreshToken {
            response = try! .json(
                DemoErrorResponse(error: "invalid_refresh_token", message: "Refresh token is not valid."),
                statusCode: 401,
                reasonPhrase: "Unauthorized"
            )
        } catch {
            response = try! .json(
                DemoErrorResponse(error: "bad_request", message: "Unable to process request."),
                statusCode: 400,
                reasonPhrase: "Bad Request"
            )
        }

        connection.send(content: response.serialize(), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func route(request: HTTPRequest) throws -> HTTPResponse {
        switch (request.method, request.path) {
        case ("GET", "/api/health"):
            return try .json(["status": "ok"])
        case ("POST", "/api/login"):
            let login = try JSONDecoder().decode(DemoLoginRequest.self, from: request.body)
            let response = try authenticator.login(username: login.username, password: login.password)
            return try .json(response)
        case ("POST", "/api/refresh"):
            let refresh = try JSONDecoder().decode(DemoRefreshRequest.self, from: request.body)
            let response = try authenticator.refresh(refreshToken: refresh.refreshToken)
            return try .json(response)
        default:
            throw ServerError.invalidPath
        }
    }

    private func parse(requestData: Data) throws -> HTTPRequest {
        guard let requestString = String(data: requestData, encoding: .utf8) else {
            throw ServerError.invalidBody
        }

        let components = requestString.components(separatedBy: "\r\n\r\n")
        guard let head = components.first else {
            throw ServerError.invalidBody
        }

        let lines = head.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw ServerError.invalidBody
        }

        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else {
            throw ServerError.invalidBody
        }

        let method = String(requestParts[0])
        let path = String(requestParts[1])
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            let pair = line.split(separator: ":", maxSplits: 1)
            if pair.count == 2 {
                headers[String(pair[0]).trimmingCharacters(in: .whitespaces)] = String(pair[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        let body = components.dropFirst().joined(separator: "\r\n\r\n")
        return HTTPRequest(method: method, path: path, headers: headers, body: Data(body.utf8))
    }

    private func isRequestComplete(_ data: Data) -> Bool {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator),
              let head = String(data: data.subdata(in: data.startIndex..<range.lowerBound), encoding: .utf8)
        else {
            return false
        }

        let headerLength = range.upperBound
        let contentLength = head
            .components(separatedBy: "\r\n")
            .dropFirst()
            .compactMap { line -> Int? in
                let pair = line.split(separator: ":", maxSplits: 1)
                guard pair.count == 2 else {
                    return nil
                }

                let key = String(pair[0]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard key == "content-length" else {
                    return nil
                }

                return Int(String(pair[1]).trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .first ?? 0

        return data.count >= headerLength + contentLength
    }
}

private func parseArguments() -> (host: String, port: Int, configURL: URL?) {
    var host = DemoConfiguration.defaultListenHost
    var port = DemoConfiguration.defaultListenPort
    var configURL: URL?

    var iterator = CommandLine.arguments.dropFirst().makeIterator()
    while let argument = iterator.next() {
        switch argument {
        case "--host":
            if let value = iterator.next() {
                host = value
            }
        case "--port":
            if let value = iterator.next(), let parsed = Int(value) {
                port = parsed
            }
        case "--config":
            if let value = iterator.next() {
                configURL = URL(fileURLWithPath: value)
            }
        default:
            break
        }
    }

    return (host, port, configURL)
}

private func run() throws -> Never {
    let arguments = parseArguments()
    let configuration = try DemoIDPConfiguration.load(from: arguments.configURL)
    let authenticator = DemoAuthenticator(configuration: configuration)
    let port = NWEndpoint.Port(rawValue: UInt16(arguments.port)) ?? .init(integerLiteral: UInt16(DemoConfiguration.defaultListenPort))
    let server = try DemoHTTPServer(
        host: NWEndpoint.Host(arguments.host),
        port: port,
        authenticator: authenticator
    )

    server.start()
}

try run()
