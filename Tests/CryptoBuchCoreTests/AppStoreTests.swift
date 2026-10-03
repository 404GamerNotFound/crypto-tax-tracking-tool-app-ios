import XCTest
import Foundation
@testable import CryptoBuchCore

final class AppStoreTests: XCTestCase {
    private var suite: String!
    private var defaults: UserDefaults!
    private let first = "http://192.168.1.20:3000"
    private let second = "http://192.168.1.21:3000"

    override func setUpWithError() throws {
        suite = "CryptoBuchSessions.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    }
    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    @MainActor
    func testFreshInstallMakesNoAutomaticRequest() async {
        let store = AppStore(preferences: ServerPreferences(defaults: defaults)) { _ in
            XCTFail("An empty server list must not contact a server")
            return Demo.metadata
        }
        await store.restoreConnectionIfNeeded()
        XCTAssertFalse(store.isConnected)
        XCTAssertTrue(store.savedServers.isEmpty)
    }

    @MainActor
    func testLaunchRestoresLastServerOnceAndSwitchScreenStaysOpen() async throws {
        let preferences = ServerPreferences(defaults: defaults)
        _ = try preferences.save(first)
        let selected = try preferences.save(second)
        preferences.markUsed(selected)
        var requests: [String] = []
        let store = AppStore(preferences: preferences) { client in
            requests.append(client.address.url.absoluteString)
            return Demo.metadata
        }
        await store.restoreConnectionIfNeeded()
        XCTAssertTrue(store.isConnected)
        XCTAssertEqual(store.client?.address.url.absoluteString, second)
        store.disconnect()
        await store.restoreConnectionIfNeeded()
        XCTAssertFalse(store.isConnected)
        XCTAssertEqual(requests, [second])
        XCTAssertEqual(store.savedServers.count, 2)
    }

    @MainActor
    func testSelectionPersistsAcrossNewAppStore() async {
        let preferences = ServerPreferences(defaults: defaults)
        let store = AppStore(preferences: preferences) { _ in Demo.metadata }
        await store.connect(first)
        let previousSession = store.sessionID
        await store.connect(second)
        XCTAssertNotEqual(store.sessionID, previousSession)
        XCTAssertEqual(store.savedServers.map(\.address), [first, second])
        store.disconnect()
        let relaunched = AppStore(preferences: preferences) { _ in Demo.metadata }
        await relaunched.restoreConnectionIfNeeded()
        XCTAssertEqual(relaunched.client?.address.url.absoluteString, second)
        relaunched.disconnect()
    }

    @MainActor
    func testFailedNewServerStaysListedButDoesNotReplaceStartServer() async {
        let preferences = ServerPreferences(defaults: defaults)
        let store = AppStore(preferences: preferences) { client in
            if client.address.url.host == "192.168.1.21" { throw APIError.network("Offline") }
            return Demo.metadata
        }
        await store.connect(first)
        await store.connect(second)
        XCTAssertFalse(store.isConnected)
        XCTAssertNil(store.metadata)
        XCTAssertFalse(store.connecting)
        XCTAssertEqual(store.savedServers.map(\.address), [first, second])
        XCTAssertEqual(preferences.address, first)
        XCTAssertTrue(store.connectionError?.contains(second) == true)
    }

    @MainActor
    func testFailedAutomaticConnectionDoesNotRetryOrEnterDemo() async throws {
        let preferences = ServerPreferences(defaults: defaults)
        preferences.markUsed(try preferences.save(first))
        var count = 0
        let store = AppStore(preferences: preferences) { _ in
            count += 1
            throw APIError.network("Offline")
        }
        await store.restoreConnectionIfNeeded()
        await store.restoreConnectionIfNeeded()
        XCTAssertEqual(count, 1)
        XCTAssertFalse(store.isConnected)
        XCTAssertFalse(store.isDemo)
        XCTAssertFalse(store.connecting)
        XCTAssertNotNil(store.connectionError)
        XCTAssertEqual(store.savedServers.count, 1)
    }

    @MainActor
    func testForgetDuringConnectionCannotRecreateDeletedServer() async throws {
        let preferences = ServerPreferences(defaults: defaults)
        let started = expectation(description: "Verification started")
        var pending: CheckedContinuation<Metadata, Error>?
        let store = AppStore(preferences: preferences) { _ in
            try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
        }
        let connecting = Task { await store.connect(first) }
        await fulfillment(of: [started], timeout: 2)
        store.forgetConnection()
        try XCTUnwrap(pending).resume(returning: Demo.metadata)
        await connecting.value
        XCTAssertFalse(store.isConnected)
        XCTAssertNil(store.metadata)
        XCTAssertTrue(store.savedServers.isEmpty)
        XCTAssertTrue(preferences.servers.isEmpty)
        XCTAssertEqual(preferences.address, "")
    }

    @MainActor
    func testRemovedPendingServerCannotReplaceNewSession() async throws {
        let preferences = ServerPreferences(defaults: defaults)
        let started = expectation(description: "First verification started")
        var pending: CheckedContinuation<Metadata, Error>?
        let store = AppStore(preferences: preferences) { client in
            if client.address.url.host == "192.168.1.20" {
                return try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
            }
            return Demo.metadata
        }
        let connecting = Task { await store.connect(first) }
        await fulfillment(of: [started], timeout: 2)
        store.removeServer(try SavedServer(first))
        await store.connect(second)
        let currentSession = store.sessionID
        try XCTUnwrap(pending).resume(returning: Demo.metadata)
        await connecting.value
        XCTAssertEqual(store.client?.address.url.absoluteString, second)
        XCTAssertEqual(store.sessionID, currentSession)
        XCTAssertEqual(store.savedServers.map(\.address), [second])
        XCTAssertEqual(preferences.address, second)
        XCTAssertFalse(store.connecting)
        store.disconnect()
    }
}
