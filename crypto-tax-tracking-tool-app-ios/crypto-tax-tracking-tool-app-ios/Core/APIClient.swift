import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidServer, insecureServer, unsafeLink, incompatibleVersion(String)
    case server(Int, String), network(String), invalidResponse, invalidData, tooManyPages

    var errorDescription: String? {
        switch self {
        case .invalidServer: return "Bitte eine gültige IP-Adresse oder einen Hostnamen und einen Port zwischen 1 und 65535 eingeben. Keine Zugangsdaten oder Suchparameter verwenden."
        case .insecureServer: return "Für Server im Internet ist HTTPS erforderlich. HTTP ist nur im lokalen Netzwerk erlaubt."
        case .unsafeLink: return "Der Server hat einen ungültigen oder fremden API-Link geliefert."
        case .incompatibleVersion(let version): return "API-Version \(version) wird noch nicht unterstützt. Diese App benötigt Version 1."
        case .server(let code, let message): return "\(message) (HTTP \(code))"
        case .network(let message): return message
        case .invalidResponse: return "Der Server liefert keine gültige HTTP-Antwort."
        case .invalidData: return "Die Antwort entspricht nicht der CryptoBuch-API. Bitte Serveradresse und Serverversion prüfen."
        case .tooManyPages: return "Die Datenmenge oder Seitenfolge ist zu groß. Bitte die Auswahl eingrenzen."
        }
    }
}

struct ServerAddress: Equatable, Sendable {
    let url: URL

    init(host: String, port: String, secure: Bool) throws {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !host.contains(where: { $0.isWhitespace }),
              !host.contains(where: { "/?#@".contains($0) }),
              port.allSatisfy({ $0.isASCII && $0.isNumber }), let portNumber = Int(port),
              (1...65535).contains(portNumber) else { throw APIError.invalidServer }
        var parts = URLComponents()
        parts.scheme = secure ? "https" : "http"
        parts.host = host.contains(":") && !host.hasPrefix("[") ? "[\(host)]" : host
        parts.port = portNumber
        guard let value = parts.string else { throw APIError.invalidServer }
        try self.init(value)
    }

    init(_ text: String) throws {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: text),
              let scheme = parts.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              !parts.path.contains(".."), !parts.path.contains("\\"),
              parts.port.map({ (1...65535).contains($0) }) ?? true else { throw APIError.invalidServer }
        if scheme == "http", !Self.isLocal(host) { throw APIError.insecureServer }
        parts.scheme = scheme
        parts.host = host.lowercased()
        parts.path = parts.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !parts.path.isEmpty { parts.path = "/" + parts.path }
        guard let url = parts.url else { throw APIError.invalidServer }
        self.url = url
    }

    static func isLocal(_ raw: String) -> Bool {
        let host = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if host == "localhost" || host.hasSuffix(".local") || host == "::1" { return true }
        let components = host.split(separator: ".", omittingEmptySubsequences: false)
        let octets = components.compactMap { Int($0) }
        if components.count == 4, octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) {
            return octets[0] == 10 || octets[0] == 127 || (octets[0] == 192 && octets[1] == 168)
                || (octets[0] == 172 && (16...31).contains(octets[1])) || (octets[0] == 169 && octets[1] == 254)
        }
        if host.contains(":") { return host.hasPrefix("fc") || host.hasPrefix("fd") || host.hasPrefix("fe80:") }
        return false
    }

    /// API paths are rooted at the configured installation, including a reverse proxy prefix.
    func resolve(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        guard let link = URLComponents(string: path), link.user == nil, link.password == nil,
              link.fragment == nil, !link.path.contains(".."), !link.path.contains("\\"),
              !path.hasPrefix("//") else { throw APIError.unsafeLink }
        var result: URLComponents
        if link.scheme != nil || link.host != nil {
            guard let target = link.url, sameOrigin(target),
                  target.path.hasPrefix(url.path + "/api/") || target.path == url.path + "/api/v1" else { throw APIError.unsafeLink }
            result = link
        } else {
            guard link.path.hasPrefix("/api/") || link.path == "/api/v1" || link.path == "/api-docs.html" else { throw APIError.unsafeLink }
            result = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            result.path = url.path + link.path
            result.queryItems = link.queryItems
        }
        if !query.isEmpty { result.queryItems = (result.queryItems ?? []) + query }
        guard let final = result.url else { throw APIError.unsafeLink }
        return final
    }

    func sameOrigin(_ target: URL) -> Bool {
        func port(_ value: URL) -> Int { value.port ?? (value.scheme == "https" ? 443 : 80) }
        return target.scheme == url.scheme && target.host == url.host && port(target) == port(url)
    }
}

// Redirects are deliberately refused: a local endpoint must not redirect portfolio requests elsewhere.
final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

actor APIClient {
    nonisolated let address: ServerAddress
    private let session: URLSession

    init(address: ServerAddress, session: URLSession? = nil) {
        self.address = address
        if let session { self.session = session } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 45
            configuration.timeoutIntervalForResource = 90
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration, delegate: NoRedirectDelegate(), delegateQueue: nil)
        }
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    func close() { session.invalidateAndCancel() }

    func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        try await request(path, query: query, method: "GET")
    }

    func send<Body: Encodable & Sendable, Result: Decodable & Sendable>(
        _ path: String, method: String = "POST", body: Body
    ) async throws -> Result {
        try await request(path, method: method, body: JSONEncoder().encode(body))
    }

    private func request<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = [],
                                               method: String, body: Data? = nil) async throws -> T {
        var request = URLRequest(url: try address.resolve(path, query: query))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .timedOut:
                throw APIError.network("Der Server antwortet nicht rechtzeitig. Bitte Serverstatus, IP-Adresse und Port prüfen und erneut versuchen.")
            case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                throw APIError.network("Der Server ist nicht erreichbar. Bitte IP-Adresse, Port und WLAN-Verbindung prüfen. Der CryptoBuch-Server muss laufen.")
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.network("Die Netzwerkverbindung fehlt oder wurde unterbrochen. Bitte auch die Berechtigung für das lokale Netzwerk in den iOS-Einstellungen prüfen.")
            case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid:
                throw APIError.network("Die HTTPS-Verbindung ist nicht vertrauenswürdig. Bitte ein gültiges Serverzertifikat verwenden.")
            case .appTransportSecurityRequiresSecureConnection:
                throw APIError.network("iOS hat diese HTTP-Verbindung blockiert. Bitte HTTPS oder eine lokale IP-Adresse verwenden.")
            default: throw APIError.network("Die Verbindung zum Server ist fehlgeschlagen. Bitte die Netzwerkeinstellungen prüfen.")
            }
        }
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data).error)
                ?? "Serveranfrage fehlgeschlagen. Bitte Adresse und Zugriff prüfen."
            throw APIError.server(http.statusCode, String(message.prefix(500)))
        }
        do { return try Self.decoder().decode(T.self, from: data) }
        catch { throw APIError.invalidData }
    }

    func all<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = []) async throws -> [T] {
        var next: String? = path
        var result: [T] = []
        var seen = Set<String>()
        var first = true
        while let current = next {
            guard seen.insert(current).inserted, seen.count <= 200 else { throw APIError.tooManyPages }
            let page: Page<T> = try await get(current, query: first ? query + [.init(name: "limit", value: "500")] : [])
            result.append(contentsOf: page.data)
            guard !page.pagination.hasMore || page.links.next != nil else { throw APIError.invalidData }
            next = page.links.next
            first = false
        }
        return result
    }

    func verify() async throws -> Metadata {
        let discovery: Discovery = try await get("/api/v1")
        guard discovery.apiVersion.split(separator: ".").first == "1" else { throw APIError.incompatibleVersion(discovery.apiVersion) }
        return try await get("/api/v1/metadata")
    }

    private struct ErrorBody: Decodable { let error: String }
}
