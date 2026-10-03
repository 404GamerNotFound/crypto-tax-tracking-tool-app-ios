import Foundation
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
    @Published private(set) var serverText: String
    @Published private(set) var savedServers: [SavedServer]
    @Published private(set) var connectingAddress: String?
    @Published private(set) var demoTransactions = Demo.transactions
    @Published private(set) var demoJobs = Demo.jobs
    @Published private(set) var demoNotices = Demo.notices
    private var connectionAttempt = UUID()
    private var pendingClient: APIClient?
    private let preferences: ServerPreferences
    private let verifyConnection: (APIClient) async throws -> Metadata
    private var didAttemptRestore = false
    var isConnected: Bool { client != nil || isDemo }
    var serverName: String { isDemo ? "Demomodus" : client?.address.url.host ?? "Server" }

    init(preferences: ServerPreferences = ServerPreferences(),
         verifyConnection: @escaping (APIClient) async throws -> Metadata = { try await $0.verify() }) {
        self.preferences = preferences
        self.verifyConnection = verifyConnection
        serverText = preferences.address
        savedServers = preferences.servers
    }

    func restoreConnectionIfNeeded() async {
        guard !didAttemptRestore else { return }
        didAttemptRestore = true
        guard !isConnected, !connecting, !serverText.isEmpty else { return }
        await connect(serverText)
    }

    func connect(_ value: String) async {
        guard !connecting else { return }
        didAttemptRestore = true
        if isConnected { disconnect() }
        let attempt = UUID()
        connectionAttempt = attempt
        connecting = true
        connectionError = nil
        var candidate: APIClient?
        defer {
            if let candidate, client !== candidate { Task { await candidate.close() } }
            if connectionAttempt == attempt {
                connecting = false
                connectingAddress = nil
                pendingClient = nil
            }
        }
        do {
            let server = try preferences.save(value)
            savedServers = preferences.servers
            connectingAddress = server.address
            let address = try ServerAddress(server.address)
            let newClient = APIClient(address: address)
            candidate = newClient
            pendingClient = newClient
            let metadata = try await verifyConnection(newClient)
            try Task.checkCancellation()
            // A reset while the request is pending must not restore the deleted address.
            guard connectionAttempt == attempt else { return }
            self.metadata = metadata
            self.client = newClient
            self.isDemo = false
            preferences.markUsed(server)
            self.serverText = preferences.address
            sessionID = UUID()
        } catch is CancellationError { }
        catch {
            if connectionAttempt == attempt {
                connectionError = [connectingAddress, error.localizedDescription].compactMap { $0 }.joined(separator: "\n")
            }
        }
    }

    func demo() {
        disconnect()
        demoTransactions = Demo.transactions
        demoJobs = Demo.jobs
        demoNotices = Demo.notices
        metadata = Demo.metadata
        isDemo = true
        client = nil
        connectionError = nil
        sessionID = UUID()
    }

    func disconnect() {
        didAttemptRestore = true
        connectionAttempt = UUID()
        connecting = false
        connectingAddress = nil
        if let pendingClient { Task { await pendingClient.close() } }
        pendingClient = nil
        if let client { Task { await client.close() } }
        client = nil
        metadata = nil
        isDemo = false
        banner = nil
        connectionError = nil
        demoTransactions = Demo.transactions
        demoJobs = Demo.jobs
        demoNotices = Demo.notices
        sessionID = UUID()
    }

    func forgetConnection() {
        disconnect()
        preferences.forget()
        savedServers = []
        serverText = ""
    }

    func removeServer(_ server: SavedServer) {
        if connectingAddress == server.address || client?.address.url.absoluteString == server.address {
            disconnect()
        }
        preferences.remove(server)
        savedServers = preferences.servers
        serverText = preferences.address
        connectionError = nil
    }

    func queueSync(wallet: Wallet, exchangeID: Int?) async throws {
        if isDemo {
            demoJobs.append(Job(id: (demoJobs.map(\.id).max() ?? 0) + 1, type: "demo-sync", status: "success", progressCurrent: 1, progressTotal: 1, errorMessage: nil, createdAt: ISO8601DateFormatter().string(from: Date())))
            banner = "Demo: Synchronisierung simuliert. Es wurde kein Server kontaktiert. Den Beispielauftrag findest du unter Hintergrundjobs."
            return
        }
        guard let client else { return }
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

    func updateDemoPurpose(id: Int, purpose: String) -> Transaction? {
        guard isDemo, let index = demoTransactions.firstIndex(where: { $0.id == id }) else { return nil }
        demoTransactions[index].purpose = purpose.isEmpty ? nil : purpose
        demoTransactions[index].purposeOrigin = "manual"
        dataRevision += 1
        return demoTransactions[index]
    }

    func markDemoNoticeRead(id: Int) {
        guard isDemo, let index = demoNotices.firstIndex(where: { $0.id == id }) else { return }
        demoNotices[index].isRead = 1
    }

    var demoQuality: Quality {
        Quality(counts: .init(missingHistoricPrices: demoTransactions.filter { $0.priceTransactionEur == nil }.count,
                              unassignedPurposes: demoTransactions.filter { $0.purpose?.isEmpty != false }.count,
                              manualHistoricPrices: demoTransactions.filter { $0.priceSource == "manual" }.count))
    }
}
