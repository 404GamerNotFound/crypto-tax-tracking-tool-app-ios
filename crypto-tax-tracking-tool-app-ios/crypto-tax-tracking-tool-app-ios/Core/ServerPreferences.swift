import Foundation

struct SavedServer: Identifiable, Equatable, Sendable {
    let address: String
    var id: String { address }

    init(_ value: String) throws {
        let validated = try ServerAddress(value)
        guard var parts = URLComponents(url: validated.url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidServer
        }
        // Explicit default ports identify the same installation as an omitted port.
        if parts.port == (parts.scheme == "https" ? 443 : 80) { parts.port = nil }
        guard let url = parts.url else { throw APIError.invalidServer }
        address = url.absoluteString
    }
}

/// Only connection settings are persisted, never API responses or credentials.
struct ServerPreferences {
    private static let key = "serverConnections.v1"
    private let defaults: UserDefaults
    private struct State: Codable {
        var addresses: [String] = []
        var lastUsedAddress: String?
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Self.key) == nil,
           let legacy = defaults.string(forKey: "serverURL"), let server = try? SavedServer(legacy) {
            write(State(addresses: [server.address], lastUsedAddress: server.address))
        }
        defaults.removeObject(forKey: "serverURL")
    }

    var servers: [SavedServer] { read().addresses.compactMap { try? SavedServer($0) } }
    var address: String { read().lastUsedAddress ?? "" }

    /// Keep a valid new address even when its server is temporarily offline.
    @discardableResult
    func save(_ value: String) throws -> SavedServer {
        let server = try SavedServer(value)
        var state = read()
        if !state.addresses.contains(server.address) { state.addresses.append(server.address) }
        write(state)
        return server
    }

    func markUsed(_ server: SavedServer) {
        var state = read()
        guard state.addresses.contains(server.address) else { return }
        state.lastUsedAddress = server.address
        write(state)
    }

    func remove(_ server: SavedServer) {
        var state = read()
        state.addresses.removeAll { $0 == server.address }
        // Never silently choose another server as the automatic start destination.
        if state.lastUsedAddress == server.address { state.lastUsedAddress = nil }
        write(state)
    }

    func forget() {
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: "serverURL")
    }

    private func read() -> State {
        guard let data = defaults.data(forKey: Self.key),
              let stored = try? JSONDecoder().decode(State.self, from: data) else { return State() }
        var state = State()
        for value in stored.addresses {
            if let server = try? SavedServer(value), !state.addresses.contains(server.address) {
                state.addresses.append(server.address)
            }
        }
        if let value = stored.lastUsedAddress, let server = try? SavedServer(value),
           state.addresses.contains(server.address) { state.lastUsedAddress = server.address }
        return state
    }

    private func write(_ state: State) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
