import XCTest
@testable import CryptoBuchCore

@MainActor
private final class PasswordStoreStub: ServerPasswordStore {
    var values: [String: String] = [:]
    var requested: [String] = []
    func contains(server: String) -> Bool { values[server] != nil }
    func save(_ password: String, server: String) throws { values[server] = password }
    func load(server: String) async throws -> String {
        requested.append(server)
        throw BiometricPasswordError.cancelled
    }
    func remove(server: String) { values.removeValue(forKey: server) }
}
final class PasswordLoginTests: XCTestCase {
    @MainActor
    func testProtectedServerOffersManualPasswordWithoutSavingAnything() async throws {
        let name = "CryptoBuchPasswordTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let vault = PasswordStoreStub()
        let store = AppStore(preferences: ServerPreferences(defaults: defaults), passwords: vault) { _ in throw APIError.server(401, "Anmeldung erforderlich") }
        await store.connect("http://192.168.1.20:3000")
        XCTAssertFalse(store.isConnected)
        XCTAssertEqual(store.authenticationAddress, "http://192.168.1.20:3000")
        XCTAssertTrue(vault.values.isEmpty)
        XCTAssertTrue(vault.requested.isEmpty)
    }
    @MainActor
    func testBiometricCancelLeavesManualFallbackAndRemovalDeletesOnlyChosenCredential() async throws {
        let name = "CryptoBuchPasswordTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = "http://192.168.1.20:3000", second = "http://192.168.1.21:3000"
        let preferences = ServerPreferences(defaults: defaults)
        let server = try preferences.save(first); _ = try preferences.save(second)
        let vault = PasswordStoreStub(); vault.values = [first: "fake-password", second: "other-fake-password"]
        let store = AppStore(preferences: preferences, passwords: vault) { _ in throw APIError.server(401, "Anmeldung erforderlich") }
        await store.connect(first)
        XCTAssertFalse(store.isConnected)
        XCTAssertEqual(store.authenticationAddress, first)
        XCTAssertEqual(vault.requested, [first])
        XCTAssertTrue(store.connectionError?.contains("abgebrochen") == true)
        store.removeServer(server)
        XCTAssertNil(vault.values[first]); XCTAssertNotNil(vault.values[second])
        store.forgetConnection()
        XCTAssertTrue(vault.values.isEmpty)
    }
}
