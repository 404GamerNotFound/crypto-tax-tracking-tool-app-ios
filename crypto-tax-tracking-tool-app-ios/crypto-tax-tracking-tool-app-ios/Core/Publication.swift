import Foundation

struct Publication: Decodable, Sendable {
    let publisher: String
    let contactEmail: String
    let privacyURL: String
    let supportURL: String

    static let current: Publication = {
        guard let url = Bundle.main.url(forResource: "Publication", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let value = try? PropertyListDecoder().decode(Publication.self, from: data) else {
            return Publication(publisher: "", contactEmail: "", privacyURL: "", supportURL: "")
        }
        return value
    }()

    var privacyLink: URL? { Self.publicHTTPSURL(privacyURL) }
    var supportLink: URL? { Self.publicHTTPSURL(supportURL) }
    var emailLink: URL? {
        let value = contactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^[A-Za-z0-9.!#$%&'*+/=^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$"#, options: .regularExpression) != nil else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = value
        components.queryItems = [.init(name: "subject", value: "CryptoBuch für iOS – Support")]
        return components.url
    }

    static func publicHTTPSURL(_ text: String) -> URL? {
        guard let parts = URLComponents(string: text), parts.scheme == "https", let host = parts.host,
              host.contains("."), parts.user == nil, parts.password == nil,
              !ServerAddress.isLocal(host), parts.fragment == nil,
              !["example.com", "example.org", "example.net"].contains(where: { host == $0 || host.hasSuffix("." + $0) }),
              !host.hasSuffix(".invalid"), !host.hasSuffix(".test") else { return nil }
        return parts.url
    }
}

/// The only app-specific persistent value. Never clear unrelated defaults.
struct ServerPreferences {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    var address: String { defaults.string(forKey: "serverURL") ?? "" }
    func save(_ address: String) { defaults.set(address, forKey: "serverURL") }
    func forget() { defaults.removeObject(forKey: "serverURL") }
}
