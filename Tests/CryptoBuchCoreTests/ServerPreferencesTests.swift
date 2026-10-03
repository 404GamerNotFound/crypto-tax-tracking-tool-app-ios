import XCTest
import Foundation
@testable import CryptoBuchCore

final class ServerPreferencesTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suite = "CryptoBuchServers.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testMultipleServersAndLastSuccessfulSelectionSurviveRelaunch() throws {
        let preferences = ServerPreferences(defaults: defaults)
        let first = try preferences.save("http://192.168.1.20:3000")
        let second = try preferences.save("https://server.local:3443")
        preferences.markUsed(second)
        let restored = ServerPreferences(defaults: defaults)
        XCTAssertEqual(restored.servers, [first, second])
        XCTAssertEqual(restored.address, second.address)
    }

    func testSavingAnUnverifiedServerDoesNotReplaceStartServer() throws {
        let preferences = ServerPreferences(defaults: defaults)
        let first = try preferences.save("http://192.168.1.20:3000")
        preferences.markUsed(first)
        _ = try preferences.save("http://192.168.1.21:3000")
        XCTAssertEqual(preferences.address, first.address)
        XCTAssertEqual(preferences.servers.count, 2)
    }

    func testEquivalentAddressesDoNotCreateDuplicates() throws {
        let preferences = ServerPreferences(defaults: defaults)
        _ = try preferences.save(" HTTPS://SERVER.local:443/ ")
        _ = try preferences.save("https://server.local")
        _ = try preferences.save("http://server.local:80/")
        _ = try preferences.save("http://server.local")
        XCTAssertEqual(preferences.servers.map(\.address), ["https://server.local", "http://server.local"])
    }

    func testPortsProtocolsAndProxyPrefixesRemainSeparate() throws {
        let preferences = ServerPreferences(defaults: defaults)
        let values = ["http://[::1]:3000", "http://[::1]:3001", "https://[::1]:3001",
                      "https://server.local/one", "https://server.local/two"]
        for value in values { try preferences.save(value) }
        XCTAssertEqual(preferences.servers.map(\.address), values)
    }

    func testLegacyAddressMigratesExactlyOnceAsStartServer() throws {
        defaults.set("http://192.168.1.20:3000/", forKey: "serverURL")
        let preferences = ServerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.servers.map(\.address), ["http://192.168.1.20:3000"])
        XCTAssertEqual(preferences.address, "http://192.168.1.20:3000")
        XCTAssertNil(defaults.object(forKey: "serverURL"))
        _ = try preferences.save("http://192.168.1.21:3000")
        XCTAssertEqual(ServerPreferences(defaults: defaults).servers.count, 2)
    }

    func testRemovingStartServerDoesNotAutomaticallySelectAnother() throws {
        let preferences = ServerPreferences(defaults: defaults)
        let first = try preferences.save("http://192.168.1.20:3000")
        let second = try preferences.save("http://192.168.1.21:3000")
        preferences.markUsed(first)
        preferences.remove(second)
        XCTAssertEqual(preferences.address, first.address)
        _ = try preferences.save(second.address)
        preferences.remove(first)
        preferences.markUsed(first) // A late callback cannot recreate a removed entry.
        XCTAssertEqual(preferences.address, "")
        XCTAssertEqual(ServerPreferences(defaults: defaults).servers, [second])
    }

    func testInvalidAddressesNeverPersistOrMigrate() throws {
        let preferences = ServerPreferences(defaults: defaults)
        for value in ["https://user:secret@server.local", "https://server.local?token=secret", "http://8.8.8.8:3000", "file:///tmp/server"] {
            XCTAssertThrowsError(try preferences.save(value))
            defaults.set(value, forKey: "serverURL")
            XCTAssertTrue(ServerPreferences(defaults: defaults).servers.isEmpty)
        }
        XCTAssertEqual(preferences.address, "")
    }

    func testDamagedPreferencesCannotRestoreInvalidOrUnlistedServer() throws {
        defaults.set(Data("invalid JSON".utf8), forKey: "serverConnections.v1")
        XCTAssertTrue(ServerPreferences(defaults: defaults).servers.isEmpty)
        let data = try JSONSerialization.data(withJSONObject: [
            "addresses": ["http://192.168.1.20:3000/", "http://192.168.1.20:3000", "https://user:secret@server.local"],
            "lastUsedAddress": "https://unexpected.local"
        ])
        defaults.set(data, forKey: "serverConnections.v1")
        let preferences = ServerPreferences(defaults: defaults)
        XCTAssertEqual(preferences.servers.map(\.address), ["http://192.168.1.20:3000"])
        XCTAssertEqual(preferences.address, "")
    }
}
