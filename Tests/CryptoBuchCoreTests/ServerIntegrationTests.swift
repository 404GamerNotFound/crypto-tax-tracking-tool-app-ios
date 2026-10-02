import XCTest
import Foundation
@testable import CryptoBuchCore

final class ServerIntegrationTests: XCTestCase {
    /// Opt-in: run against a separately started CryptoBuch server, not production data.
    func testExistingServerContract() async throws {
        guard let server = ProcessInfo.processInfo.environment["CRYPTOBUCH_TEST_SERVER"] else {
            throw XCTSkip("CRYPTOBUCH_TEST_SERVER ist nicht gesetzt; kein Serverzugriff im normalen Unit-Test.")
        }
        let client = APIClient(address: try ServerAddress(server))
        let metadata = try await client.verify()
        XCTAssertTrue(metadata.apiVersion.hasPrefix("1."))
        XCTAssertTrue(metadata.purposePresets.contains("Kauf"))
        let wallets: [Wallet] = try await client.all("/api/v1/wallets")
        let _: [Exchange] = try await client.all("/api/v1/exchange-connections")
        let _: Portfolio = try await client.get("/api/portfolio")
        let _: Quality = try await client.get("/api/data-quality")
        let _: TaxReport = try await client.get("/api/tax-report", query: [.init(name: "year", value: "2026")])
        let _: [Job] = try await client.all("/api/v1/jobs")
        let _: [Notice] = try await client.all("/api/v1/notifications")
        let transactions: Page<Transaction> = try await client.get("/api/v1/transactions", query: [.init(name: "limit", value: "2")])
        if let next = transactions.links.next {
            let second: Page<Transaction> = try await client.get(next)
            XCTAssertGreaterThan(second.pagination.offset, transactions.pagination.offset)
            XCTAssertTrue(Set(second.data.map(\.id)).isDisjoint(with: transactions.data.map(\.id)))
        }
        if let transaction = transactions.data.first {
            XCTAssertTrue(wallets.contains { $0.id == transaction.walletId })
            let detail: Detail<Transaction> = try await client.get("/api/v1/transactions/\(transaction.id)")
            XCTAssertEqual(detail.data.id, transaction.id)
            let _: [Document] = try await client.all("/api/v1/documents", query: [.init(name: "transaction_id", value: String(transaction.id))])
            let _: [PriceAudit] = try await client.all("/api/v1/price-audit", query: [.init(name: "transaction_id", value: String(transaction.id))])
        }
    }
}
