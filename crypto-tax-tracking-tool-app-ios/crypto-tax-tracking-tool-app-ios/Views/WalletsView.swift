import SwiftUI

struct WalletsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var wallets: [Wallet] = []
    @State private var exchanges: [Exchange] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var loading = false
    @State private var search = ""
    private var filtered: [Wallet] {
        wallets.filter { search.isEmpty || [$0.name, $0.chain, $0.groupName ?? "", $0.tags.joined(separator: " ")].joined(separator: " ").localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        List {
            DemoFlag().listRowBackground(Color.clear)
            if let error { FailureView(message: error, retry: load).listRowBackground(Color.clear) }
            if loading && !loaded { ProgressView("Quellen werden geladen …") }
            ForEach([false, true], id: \.self) { exchange in
                let items = filtered.filter { $0.isExchange == exchange }
                if !items.isEmpty {
                    Section(exchange ? "Börsenkonten" : "Öffentliche Wallets") {
                        ForEach(items) { wallet in
                            NavigationLink {
                                WalletDetailView(wallet: wallet, exchangeID: exchanges.first { $0.walletId == wallet.id }?.id)
                            } label: {
                                HStack(spacing: 12) {
                                    AssetBadge(symbol: wallet.isExchange ? "EX" : wallet.chain)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(wallet.name).font(.headline)
                                        Text(wallet.isExchange ? "Börsenkonto" : wallet.chain + " · " + wallet.sourceType).font(.caption).foregroundStyle(.secondary)
                                        if let group = wallet.groupName, !group.isEmpty { Text(group).font(.caption).foregroundStyle(Theme.green) }
                                    }
                                }.padding(.vertical, 5)
                            }
                        }
                    }
                }
            }
            if loaded && filtered.isEmpty && error == nil {
                ContentUnavailableView(search.isEmpty ? "Noch keine Quellen" : "Keine Treffer", systemImage: "wallet.bifold", description: Text("Wallets und Börsenkonten werden im Web-Tool eingerichtet."))
            }
            Section { Hint(text: "Die App liest öffentliche Quellen vom Server. Neue Wallets, Börsenverbindungen und Ledger-Adressen richtest du im Web-Tool ein.") }
        }
        .navigationTitle("Quellen").searchable(text: $search, prompt: "Name, Netzwerk oder Tag")
        .task { await load() }.refreshable { await load() }
    }
    private func load() async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        if store.isDemo { wallets = Demo.wallets; loaded = true; return }
        guard let client = store.client else { return }
        do {
            let values: [Wallet] = try await client.all("/api/v1/wallets")
            let connections: [Exchange] = try await client.all("/api/v1/exchange-connections")
            try Task.checkCancellation()
            wallets = values; exchanges = connections; loaded = true
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}

struct WalletDetailView: View {
    @EnvironmentObject private var store: AppStore
    let wallet: Wallet
    let exchangeID: Int?
    @State private var syncing = false
    @State private var error: String?
    var body: some View {
        List {
            DemoFlag().listRowBackground(Color.clear)
            Section("Quelle") {
                LabeledContent("Netzwerk", value: wallet.chain)
                LabeledContent("Quellentyp", value: wallet.sourceType)
                if let group = wallet.groupName, !group.isEmpty { LabeledContent("Gruppe", value: group) }
                if !wallet.tags.isEmpty { LabeledContent("Tags", value: wallet.tags.joined(separator: ", ")) }
                VStack(alignment: .leading, spacing: 8) {
                    Text(wallet.isExchange ? "Konto" : "Öffentliche Adresse / xPub").font(.caption).foregroundStyle(.secondary)
                    Text(wallet.address).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                }
                LabeledContent("Letzte Synchronisierung", value: Display.date(wallet.lastSyncedAt))
            }
            Section {
                NavigationLink { JournalView(walletID: wallet.id) } label: { Label("Buchungen anzeigen", systemImage: "list.bullet.rectangle") }
                Button {
                    Task {
                        syncing = true; error = nil
                        defer { syncing = false }
                        do { try await store.queueSync(wallet: wallet, exchangeID: exchangeID) }
                        catch { self.error = error.localizedDescription }
                    }
                } label: {
                    HStack { Label("Synchronisierung starten", systemImage: "arrow.triangle.2.circlepath"); if syncing { Spacer(); ProgressView() } }
                }.disabled(syncing || (wallet.isExchange && exchangeID == nil && !store.isDemo))
            } footer: { Text("Der Server führt den Auftrag in seiner seriellen Warteschlange aus. Für neue Werte die Übersicht nach Abschluss aktualisieren.") }
            if let error { Text(error).foregroundStyle(.red) }
        }.navigationTitle(wallet.name).navigationBarTitleDisplayMode(.inline)
    }
}
