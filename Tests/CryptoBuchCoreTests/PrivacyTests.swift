import XCTest
import Foundation
@testable import CryptoBuchCore

final class PrivacyTests: XCTestCase {
    func testDemoContentRemainsDecodableWithoutNetwork() {
        XCTAssertFalse(Demo.wallets.isEmpty)
        XCTAssertEqual(Demo.transactions.count, 4)
        XCTAssertGreaterThan(Demo.portfolio.totalValueEur, 0)
        XCTAssertEqual(Demo.tax.year, 2026)
        XCTAssertFalse(Demo.notices.isEmpty)
        XCTAssertFalse(Demo.jobs.isEmpty)
        XCTAssertTrue(Demo.metadata.purposePresets.contains("Kauf"))
        XCTAssertEqual(Demo.quality.counts.missingHistoricPrices, 1)
    }
    func testForgetRemovesOnlyConnectionAndDoesNotLeakIntoNextSession() throws {
        let suite = "CryptoBuchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = ServerPreferences(defaults: defaults)
        defaults.set("preserved", forKey: "unrelated")
        preferences.save("http://192.168.178.20:3000")
        XCTAssertEqual(preferences.address, "http://192.168.178.20:3000")
        preferences.forget()
        XCTAssertEqual(ServerPreferences(defaults: defaults).address, "")
        XCTAssertNil(defaults.object(forKey: "serverURL"))
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "preserved")
    }

    func testPublicationRejectsPlaceholderAndUnsafeLinks() {
        for url in ["", "http://developer.apple.com", "https://user:secret@developer.apple.com", "https://127.0.0.1:3000", "https://example.org/privacy", "https://server.local/privacy", "https://publisher.invalid/privacy"] {
            XCTAssertNil(Publication.publicHTTPSURL(url), url)
        }
        XCTAssertNotNil(Publication.publicHTTPSURL("https://developer.apple.com/support/"))
    }

    func testContactLinkDoesNotIncludePrivateServerData() throws {
        let publication = Publication(publisher: "Test", contactEmail: "support@fixture.invalid", privacyURL: "", supportURL: "")
        let url = try XCTUnwrap(publication.emailLink)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "mailto")
        XCTAssertEqual(components.queryItems?.map(\.name), ["subject"])
        XCTAssertFalse(url.absoluteString.contains("serverURL"))
    }

    func testContactRejectsMailHeaderInjection() {
        let publication = Publication(publisher: "Test", contactEmail: "support@fixture.invalid?bcc=other@fixture.invalid", privacyURL: "", supportURL: "")
        XCTAssertNil(publication.emailLink)
    }
}
