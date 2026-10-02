import XCTest
import Foundation
@testable import CryptoBuchCore

final class APIClientTests: XCTestCase {
    func testIPAndPortBuildLocalURL() throws {
        let address = try ServerAddress(host: " 192.168.178.20 ", port: "3000", secure: false)
        XCTAssertEqual(address.url.absoluteString, "http://192.168.178.20:3000")
        XCTAssertEqual(try address.resolve("/api/v1").absoluteString, "http://192.168.178.20:3000/api/v1")
        XCTAssertThrowsError(try ServerAddress(host: "192.168.1.1", port: "65536", secure: false))
        XCTAssertThrowsError(try ServerAddress(host: "192.168.1.1", port: "abc", secure: false))
        XCTAssertThrowsError(try ServerAddress(host: "192.168.1.1/api", port: "3000", secure: false))
    }

    func testIPv6AndHTTPS() throws {
        XCTAssertEqual(try ServerAddress(host: "::1", port: "3000", secure: false).url.absoluteString, "http://[::1]:3000")
        XCTAssertEqual(try ServerAddress(host: "cryptobuch.example.org", port: "443", secure: true).url.scheme, "https")
        XCTAssertThrowsError(try ServerAddress(host: "example.org", port: "80", secure: false))
        XCTAssertThrowsError(try ServerAddress("http://8.8.8.8:3000"))
        XCTAssertThrowsError(try ServerAddress("http://evil.10.0.0.1.example.org:3000"))
    }

    func testRejectsCredentialsAndNonHTTPAddresses() {
        for input in ["file:///tmp/private", "https://user:password@example.org", "https://example.org?secret=abc", "https://example.org#key", "http://192.168.1.1/../secret"] {
            XCTAssertThrowsError(try ServerAddress(input), input)
        }
    }

    func testProxyPrefixAndQueryEncoding() throws {
        let address = try ServerAddress("https://example.org/cryptobuch/")
        let result = try address.resolve("/api/v1/transactions", query: [.init(name: "asset", value: "ETH:0x123/+"), .init(name: "purpose", value: "Staking Rewards")])
        XCTAssertEqual(result.path, "/cryptobuch/api/v1/transactions")
        let query = URLComponents(url: result, resolvingAgainstBaseURL: false)?.queryItems
        XCTAssertEqual(query?.first?.value, "ETH:0x123/+")
        XCTAssertEqual(query?.last?.value, "Staking Rewards")
    }

    func testRejectsForeignAndTraversalPaginationLinks() throws {
        let address = try ServerAddress("https://example.org/cryptobuch")
        for path in ["https://attacker.example/api/v1/wallets", "http://example.org/cryptobuch/api/v1", "//attacker.example/api/v1", "/api/../settings", "/api/%2e%2e/settings", "https://example.org/api/v1/wallets", "/api/v1#x", "file:///api/v1"] {
            XCTAssertThrowsError(try address.resolve(path), path)
        }
        XCTAssertNoThrow(try address.resolve("https://example.org/cryptobuch/api/v1/wallets?limit=50&offset=50"))
    }

    func testDecodingPreservesMissingPriceAndDecimalAmount() throws {
        let json = """
        {"id":7,"wallet_id":2,"hash":null,"timestamp":"2026-10-02 12:00:00","direction":"in","asset":"BTC","asset_symbol":"BTC","amount":0.12345678,"fee":0.00000001,"price_transaction_eur":null,"purpose":null}
        """
        let transaction = try APIClient.decoder().decode(Transaction.self, from: Data(json.utf8))
        XCTAssertEqual(transaction.walletId, 2)
        XCTAssertEqual(transaction.amount, Decimal(string: "0.12345678"))
        XCTAssertNil(transaction.priceTransactionEur)
        XCTAssertNil(transaction.historicValue)
    }

    func testMissingAssetPriceDoesNotBecomeZero() throws {
        let json = """
        {"holdings":{"BTC":2},"assets":{"BTC":{"name":"Bitcoin","symbol":"BTC","kind":"native"}},"assetPrices":{"BTC":null},"totalValueEur":0,"insights":{"valueHistory":[],"performance":{"unrealizedProfitEur":null,"realizedYearEur":0,"netInvestmentEur":0,"purchaseReturnPercent":null}}}
        """
        let result = try APIClient.decoder().decode(Portfolio.self, from: Data(json.utf8))
        XCTAssertEqual(result.positions.count, 1)
        XCTAssertNil(result.positions[0].price)
        XCTAssertNil(result.positions[0].value)
    }

    func testFollowsAllPages() async throws {
        let client = try makeClient { request in
            let offset = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "offset" })?.value
            if offset == "500" { return (200, "{\"data\":[{\"id\":2}],\"pagination\":{\"limit\":500,\"offset\":500,\"total\":501,\"hasMore\":false},\"links\":{\"next\":null}}") }
            return (200, "{\"data\":[{\"id\":1}],\"pagination\":{\"limit\":500,\"offset\":0,\"total\":501,\"hasMore\":true},\"links\":{\"next\":\"/api/v1/wallets?limit=500&offset=500\"}}")
        }
        let items: [TestItem] = try await client.all("/api/v1/wallets")
        XCTAssertEqual(items.map(\.id), [1, 2])
    }

    func testRejectsPaginationCycle() async throws {
        let client = try makeClient { _ in (200, "{\"data\":[],\"pagination\":{\"limit\":500,\"offset\":0,\"total\":20,\"hasMore\":true},\"links\":{\"next\":\"/api/v1/wallets\"}}") }
        do {
            let _: [TestItem] = try await client.all("/api/v1/wallets")
            XCTFail("Cycle should be rejected")
        } catch { XCTAssertEqual(error as? APIError, .tooManyPages) }
    }

    func testServerErrorKeepsUsefulMessage() async throws {
        let client = try makeClient { _ in (400, "{\"error\":\"Ungültiger Zweck.\"}") }
        do {
            let _: Acknowledgement = try await client.get("/api/v1")
            XCTFail("Expected an API error")
        } catch { XCTAssertEqual(error as? APIError, .server(400, "Ungültiger Zweck.")) }
    }

    func testHTMLDoesNotPassAsAPIResponse() async throws {
        let client = try makeClient { _ in (200, "<html>Login</html>") }
        do {
            let _: Discovery = try await client.get("/api/v1")
            XCTFail("Expected decoding failure")
        } catch { XCTAssertEqual(error as? APIError, .invalidData) }
    }

    func testOfflineErrorIsActionable() async throws {
        let client = try makeClient { _ in throw URLError(.cannotConnectToHost) }
        do {
            let _: Discovery = try await client.get("/api/v1")
            XCTFail("Expected connection failure")
        } catch { XCTAssertTrue(error.localizedDescription.contains("IP-Adresse, Port")) }
    }

    func testCancellationIsNotPresentedAsNetworkFailure() async throws {
        let client = try makeClient { _ in throw URLError(.cancelled) }
        do {
            let _: Discovery = try await client.get("/api/v1")
            XCTFail("Expected cancellation")
        } catch { XCTAssertTrue(error is CancellationError) }
    }

    func testRejectsUnsupportedAPIVersion() async throws {
        let client = try makeClient { _ in (200, "{\"apiVersion\":\"2.0.0\"}") }
        do { _ = try await client.verify(); XCTFail("Expected version failure") }
        catch { XCTAssertEqual(error as? APIError, .incompatibleVersion("2.0.0")) }
    }

    func testPurposeMutationUsesExistingRouteAndCamelCaseBody() async throws {
        struct Update: Encodable, Sendable { let purpose: String }
        let client = try makeClient { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/api/transactions/7")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            return (200, "{\"id\":7,\"purpose\":\"Kauf\",\"purpose_origin\":\"manual\"}")
        }
        let _: Acknowledgement = try await client.send("/api/transactions/7", method: "PATCH", body: Update(purpose: "Kauf"))
    }

    private func makeClient(handler: @escaping (URLRequest) throws -> (Int, String)) throws -> APIClient {
        StubProtocol.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return APIClient(address: try ServerAddress("http://127.0.0.1:3000"), session: URLSession(configuration: configuration))
    }
    private struct TestItem: Decodable, Sendable { let id: Int }
}

private final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (code, payload) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(payload.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
