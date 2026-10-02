import SwiftUI
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var client: APIClient?
    @Published private(set) var metadata: Metadata?
    @Published private(set) var isDemo = false
    @Published var connecting = false
    @Published var connectionError: String?
    @Published var banner: String?
    @Published var dataRevision = 0
    @Published private(set) var sessionID = UUID()
    @Published private(set) var serverText = UserDefaults.standard.string(forKey: "serverURL") ?? ""
    var isConnected: Bool { client != nil || isDemo }
    var serverName: String { isDemo ? "Demomodus" : client?.address.url.host ?? "Server" }

    func connect(_ value: String) async {
        guard !connecting else { return }
        connecting = true
        connectionError = nil
        defer { connecting = false }
        do {
            let address = try ServerAddress(value)
            let candidate = APIClient(address: address)
            let metadata = try await candidate.verify()
            try Task.checkCancellation()
            self.metadata = metadata
            self.client = candidate
            self.isDemo = false
            self.serverText = address.url.absoluteString
            UserDefaults.standard.set(serverText, forKey: "serverURL")
            sessionID = UUID()
        } catch is CancellationError { }
        catch { connectionError = error.localizedDescription }
    }

    func demo() {
        metadata = Demo.metadata
        isDemo = true
        client = nil
        connectionError = nil
        sessionID = UUID()
    }

    func disconnect() {
        client = nil
        metadata = nil
        isDemo = false
        banner = nil
        connectionError = nil
        sessionID = UUID()
    }

    func queueSync(wallet: Wallet, exchangeID: Int?) async throws {
        guard let client else { banner = "Im Demomodus werden keine Aufträge ausgeführt."; return }
        let token = sessionID
        if wallet.isExchange {
            guard let exchangeID else { throw APIError.invalidData }
            let _: Acknowledgement = try await client.send("/api/exchange-connections/\(exchangeID)/sync", body: EmptyBody())
        } else {
            let _: Acknowledgement = try await client.send("/api/jobs/sync", body: SyncBody(walletIds: [wallet.id]))
        }
        if token == sessionID { banner = "Synchronisierung eingeplant. Den Fortschritt findest du unter Mehr → Hintergrundjobs." }
    }
    private struct EmptyBody: Encodable, Sendable {}
    private struct SyncBody: Encodable, Sendable { let walletIds: [Int] }
}

enum Demo {
    // Fictional sample data, never mixed into a live server response.
    static func decode<T: Decodable>(_ json: String) -> T {
        // These static fixtures are exercised by the simulator demo flow.
        try! APIClient.decoder().decode(T.self, from: Data(json.utf8))
    }
    static let metadata: Metadata = decode("""
    {"apiVersion":"1.0.0","purposePresets":["Kauf","Verkauf","Staking Rewards","Transfer","Gebühr","Sonstiges"],"chains":{}}
    """)
    static let wallets: [Wallet] = decode("""
    [{"id":1,"chain":"BTC","address":"Öffentliche Beispieladresse · keine echte Wallet","label":"Langzeit-Portfolio","source_type":"xpub","last_synced_at":"2026-10-01T18:30:00Z","group_name":"Privat","tags":["Sparen"]},
     {"id":2,"chain":"ETH","address":"Öffentliche Beispieladresse · keine echte Wallet","label":"Ethereum Wallet","source_type":"address","last_synced_at":"2026-10-01T18:30:00Z","group_name":"Privat","tags":[]},
     {"id":3,"chain":"EXCHANGE","address":"Demo-Börsenkonto","label":"Börsenkonto","source_type":"exchange","last_synced_at":"2026-10-01T18:30:00Z","group_name":"","tags":[]}]
    """)
    static let transactions: [Transaction] = decode("""
    [{"id":1,"wallet_id":1,"hash":"demo-btc-001","timestamp":"2026-09-02T12:00:00Z","direction":"in","asset":"BTC","asset_symbol":"BTC","amount":0.12,"fee":0,"price_transaction_eur":54000,"price_source":"auto","price_provider":"Beispielkurs","purpose":"Kauf","purpose_origin":"manual"},
     {"id":2,"wallet_id":2,"hash":"demo-eth-002","timestamp":"2026-09-14T09:40:00Z","direction":"in","asset":"ETH","asset_symbol":"ETH","amount":0.018,"fee":0,"price_transaction_eur":2650,"price_source":"auto","purpose":"Staking Rewards","purpose_origin":"auto"},
     {"id":3,"wallet_id":1,"hash":"demo-btc-003","timestamp":"2026-09-26T15:12:00Z","direction":"out","asset":"BTC","asset_symbol":"BTC","amount":0.025,"fee":0.00001,"fee_asset":"BTC","price_transaction_eur":61000,"price_source":"manual","purpose":"Verkauf","purpose_origin":"manual"},
     {"id":4,"wallet_id":2,"hash":"demo-eth-004","timestamp":"2026-10-01T16:10:00Z","direction":"in","asset":"ETH","asset_symbol":"ETH","amount":0.1,"fee":0,"price_transaction_eur":null,"price_source":"auto","purpose":null,"purpose_origin":"auto"}]
    """)
    static let portfolio: Portfolio = decode("""
    {"holdings":{"BTC":0.42,"ETH":3.8,"ADA":1200},"assets":{"BTC":{"name":"Bitcoin","symbol":"BTC","kind":"native"},"ETH":{"name":"Ethereum","symbol":"ETH","kind":"native"},"ADA":{"name":"Cardano","symbol":"ADA","kind":"native"}},"assetPrices":{"BTC":62400,"ETH":2680,"ADA":0.36},"totalValueEur":36824,"insights":{"valueHistory":[{"day":"2026-04-01","valueEur":17500},{"day":"2026-05-01","valueEur":20300},{"day":"2026-06-01","valueEur":21500},{"day":"2026-07-01","valueEur":26000},{"day":"2026-08-01","valueEur":28200},{"day":"2026-09-01","valueEur":31100},{"day":"2026-10-01","valueEur":30250}],"performance":{"unrealizedProfitEur":6574,"realizedYearEur":174.39,"netInvestmentEur":30250,"purchaseReturnPercent":21.73}}}
    """)
    static let quality: Quality = decode("""
    {"counts":{"missingHistoricPrices":1,"unassignedPurposes":1,"manualHistoricPrices":1}}
    """)
    static let tax: TaxReport = decode("""
    {"year":2026,"availableYears":[2026,2025],"profile":{"label":"Deutschland · Beispielprofil","costBasisMethod":"FIFO"},"summary":{"saleSegments":1,"incompleteSaleSegments":0,"incomeEntries":1,"incompleteIncomeEntries":0,"realizedProfitEur":174.39,"incomeEur":47.7,"estimatedTaxEur":14.31,"estimatedDisposalTaxEur":0,"estimatedIncomeTaxEur":14.31,"taxableSaleProfitEur":0}}
    """)
    static let jobs: [Job] = decode("""
    [{"id":1,"type":"wallet-sync","status":"success","progress_current":3,"progress_total":3,"created_at":"2026-10-01T18:30:00Z"}]
    """)
    static let notices: [Notice] = decode("""
    [{"id":1,"level":"warning","title":"Ein historischer Kurs fehlt","message":"Ergänze den Kurs im Web-Tool, um die Dokumentation zu vervollständigen.","is_read":0,"created_at":"2026-10-01T18:30:00Z"}]
    """)
}
