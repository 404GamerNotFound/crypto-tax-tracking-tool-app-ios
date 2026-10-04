import XCTest
@testable import CryptoBuchCore

final class WalletInputTests: XCTestCase {
    func testTagsAreTrimmedAndDeduplicatedInOrder() {
        XCTAssertEqual(WalletMetadataUpdate.tags(from: " lang, , privat, lang, privat "), ["lang", "privat"])
    }
    func testMetadataLimitsPreventSilentTruncation() {
        XCTAssertNoThrow(try WalletMetadataUpdate(label: "", groupName: "", tags: []).validate())
        XCTAssertThrowsError(try WalletMetadataUpdate(label: String(repeating: "a", count: 81), groupName: "", tags: []).validate())
        XCTAssertThrowsError(try WalletMetadataUpdate(label: "", groupName: String(repeating: "a", count: 49), tags: []).validate())
        XCTAssertThrowsError(try WalletMetadataUpdate(label: "", groupName: "", tags: (1...13).map(String.init)).validate())
        XCTAssertThrowsError(try WalletMetadataUpdate(label: "", groupName: "", tags: [String(repeating: "a", count: 33)]).validate())
    }
    func testPublicSourceKindsAndPrivateInput() {
        func source(_ chain: String, _ address: String, _ kind: String) -> WalletCreation {
            .init(chain: chain, address: address, sourceType: kind, xpubAddressType: "p2wpkh", label: "", groupName: "", tags: [])
        }
        XCTAssertNoThrow(try source("ETH", "0x" + String(repeating: "a", count: 40), "address").validate())
        XCTAssertNoThrow(try source("BTC", "zpub-public-test-placeholder", "xpub").validate())
        XCTAssertNoThrow(try source("ADA", "stake1-public-test-placeholder", "stake").validate())
        XCTAssertThrowsError(try source("ETH", "xpub-public-test-placeholder", "xpub").validate())
        XCTAssertThrowsError(try source("BTC", "xprv-private-test-placeholder", "address").validate())
        XCTAssertThrowsError(try source("BTC", "word word word", "address").validate())
        XCTAssertThrowsError(try source("ETH", String(repeating: "a", count: 64), "address").validate())
        XCTAssertThrowsError(try source("BTC", "K" + String(repeating: "a", count: 51), "address").validate())
        XCTAssertThrowsError(try source("SOL", String(repeating: "a", count: 88), "address").validate())
        XCTAssertThrowsError(try source("XLM", "S" + String(repeating: "A", count: 55), "address").validate())
    }
}
