import SwiftUI

struct JournalView: View {
    @EnvironmentObject private var store: AppStore
    var walletID: Int? = nil
    @State private var transactions: [Transaction] = []
    @State private var total = 0
    @State private var next: String?
    @State private var error: String?
    @State private var loading = false
    @State private var loaded = false
    @State private var direction = ""
    @State private var purpose = ""
    @State private var search = ""
    @State private var generation = UUID()
    var filterKey: String { "\(direction)|\(purpose)" }
    private var visible: [Transaction] {
        transactions.filter { search.isEmpty || [$0.symbol, $0.assetName ?? "", $0.hash ?? "", $0.purpose ?? ""].joined(separator: " ").localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        List {
            DemoFlag().listRowBackground(Color.clear)
            Section {
                Picker("Richtung", selection: $direction) {
                    Text("Alle").tag(""); Text("Eingang").tag("in"); Text("Ausgang").tag("out"); Text("Intern").tag("self")
                }.pickerStyle(.segmented)
                Picker("Zweck", selection: $purpose) {
                    Text("Alle Zwecke").tag("")
                    ForEach(store.metadata?.purposePresets ?? [], id: \.self) { Text($0).tag($0) }
                }
            }
            Section {
                ForEach(visible) { transaction in
                    NavigationLink { TransactionDetailView(transaction: transaction) } label: { TransactionRow(transaction: transaction) }
                }
                if let error {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(error).font(.footnote).foregroundStyle(.red)
                        Button("Erneut versuchen") { Task { await load(reset: !loaded) } }
                    }
                }
                if loading { HStack { Spacer(); ProgressView("Buchungen werden geladen …"); Spacer() } }
                else if next != nil {
                    Button("Weitere Buchungen laden") { Task { await load(reset: false) } }
                        .frame(maxWidth: .infinity).accessibilityIdentifier("loadMoreTransactions")
                }
                if loaded && visible.isEmpty && error == nil {
                    ContentUnavailableView("Keine Buchungen", systemImage: "tray", description: Text(search.isEmpty ? "Für diese Auswahl liegen keine Buchungen vor." : "Keine Treffer unter den bereits geladenen Buchungen."))
                }
            } header: { Text("\(transactions.count) von \(total) geladen · nach ID aufsteigend") }
            footer: { Text("Die Suche durchsucht die geladenen Buchungen. Richtung und Zweck filtern auf dem Server. Historische EUR-Werte sind Schätzungen.") }
        }
        .navigationTitle(walletID == nil ? "Buchungen" : "Wallet-Buchungen")
        .searchable(text: $search, prompt: "Geladene Buchungen durchsuchen")
        .task(id: "\(filterKey)|\(store.dataRevision)") { await load(reset: true) }
        .refreshable { await load(reset: true) }
    }

    private func load(reset: Bool) async {
        if !reset && loading { return }
        let token = UUID()
        generation = token
        loading = true; error = nil
        if reset { transactions = []; next = nil; total = 0; loaded = false }
        defer { if generation == token { loading = false } }
        if store.isDemo {
            transactions = Demo.transactions.filter {
                (walletID == nil || $0.walletId == walletID) && (direction.isEmpty || $0.direction == direction) && (purpose.isEmpty || $0.purpose == purpose)
            }
            total = transactions.count; loaded = true; return
        }
        guard let client = store.client else { return }
        do {
            var query = [URLQueryItem(name: "limit", value: "50")]
            if let walletID { query.append(.init(name: "wallet_id", value: String(walletID))) }
            if !direction.isEmpty { query.append(.init(name: "direction", value: direction)) }
            if !purpose.isEmpty { query.append(.init(name: "purpose", value: purpose)) }
            let page: Page<Transaction> = try await client.get(reset ? "/api/v1/transactions" : next ?? "/api/v1/transactions", query: reset ? query : [])
            try Task.checkCancellation()
            guard generation == token else { return }
            let existing = Set(transactions.map(\.id))
            transactions += page.data.filter { !existing.contains($0.id) }
            total = page.pagination.total; next = page.links.next; loaded = true
        } catch is CancellationError { }
        catch { if generation == token { self.error = error.localizedDescription } }
    }
}

struct TransactionDetailView: View {
    @EnvironmentObject private var store: AppStore
    @State var transaction: Transaction
    @State private var documents: [Document] = []
    @State private var audit: [PriceAudit] = []
    @State private var wallet: Wallet?
    @State private var purpose = ""
    @State private var error: String?
    @State private var saving = false
    @State private var loaded = false
    @State private var saved = false
    var body: some View {
        List {
            DemoFlag().listRowBackground(Color.clear)
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(transaction.directionName).font(.subheadline).foregroundStyle(.secondary)
                    Text(Display.number(transaction.amount) + " " + transaction.symbol).font(.title.weight(.semibold))
                    Text(transaction.historicValue.map { Display.money($0) } ?? "Historischer Kurs fehlt").font(.title3).foregroundStyle(.secondary)
                }.padding(.vertical, 10)
                LabeledContent("Datum", value: Display.date(transaction.timestamp))
                if let wallet { LabeledContent("Quelle", value: wallet.name) }
                LabeledContent("Gebühr", value: Display.number(transaction.fee) + " " + (transaction.feeAsset ?? transaction.symbol))
            }
            Section {
                Picker("Zweck", selection: $purpose) {
                    Text("Nicht zugeordnet").tag("")
                    ForEach(purposes, id: \.self) { Text($0).tag($0) }
                }
                if transaction.purposeOrigin == "manual" { Label("Manuell zugeordnet", systemImage: "hand.draw").font(.caption).foregroundStyle(.secondary) }
                Button {
                    Task { await savePurpose() }
                } label: {
                    HStack { Text(store.isDemo ? "Speichern im Demomodus deaktiviert" : "Zweck speichern"); if saving { Spacer(); ProgressView() } }
                }.disabled(store.isDemo || saving || purpose == (transaction.purpose ?? ""))
                if saved { Label("Zweck gespeichert", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.green) }
            } header: { Text("Zweck zuordnen") }
            footer: { Text("Eine Zuordnung ändert die Auswertung auf dem Server. Manuelle Zwecke bleiben bei einer Synchronisierung erhalten.") }
            Section("Historische Bewertung") {
                LabeledContent("Kurs je Einheit", value: Display.money(transaction.priceTransactionEur))
                LabeledContent("Herkunft", value: transaction.priceSource == "manual" ? "Manuell" : transaction.priceProvider ?? "Automatisch / unbekannt")
                Hint(text: "Unverbindliche Schätzung. Manuelle Kurskorrekturen werden im Web-Tool gepflegt.")
            }
            Section("Referenzen") {
                if let hash = transaction.hash, !hash.isEmpty { selectable("Transaktionsreferenz", hash) }
                if let counterparty = transaction.counterparty, !counterparty.isEmpty { selectable("Gegenadresse", counterparty) }
                selectable("Asset-Identität", transaction.asset)
            }
            Section("Belege") {
                if documents.isEmpty { Text(loaded ? "Keine Belege hinterlegt" : "Belege werden geladen …").foregroundStyle(.secondary) }
                ForEach(documents) { document in
                    VStack(alignment: .leading, spacing: 5) {
                        Label(document.originalName, systemImage: "doc.text")
                        Text(ByteCountFormatter.string(fromByteCount: Int64(document.byteSize), countStyle: .file)).font(.caption).foregroundStyle(.secondary)
                        Text("SHA-256: " + document.sha256).font(.system(.caption2, design: .monospaced)).textSelection(.enabled)
                    }
                }
                if !documents.isEmpty { Hint(text: "Belegdateien können im Web-Tool geöffnet werden.") }
            }
            if !audit.isEmpty {
                Section("Kurskorrekturen") {
                    ForEach(audit.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.priceEur.map { Display.money($0) } ?? "Automatik wieder aktiviert").font(.headline)
                            Text(entry.source + " · " + Display.date(entry.changedAt)).font(.caption).foregroundStyle(.secondary)
                            if let note = entry.note, !note.isEmpty { Text(note).font(.footnote) }
                        }
                    }
                }
            }
            if let error { Section { Text(error).foregroundStyle(.red); Button("Erneut laden") { Task { await load() } } } }
        }
        .navigationTitle("Buchung #\(transaction.id)").navigationBarTitleDisplayMode(.inline)
        .task { purpose = transaction.purpose ?? ""; await load() }
    }
    private var purposes: [String] {
        Array(Set((store.metadata?.purposePresets ?? []) + [transaction.purpose].compactMap { $0 }.filter { !$0.isEmpty })).sorted()
    }
    private func selectable(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.system(.footnote, design: .monospaced)).textSelection(.enabled) }
    }
    private func load() async {
        if store.isDemo { wallet = Demo.wallets.first { $0.id == transaction.walletId }; loaded = true; return }
        guard let client = store.client else { return }
        error = nil
        do {
            let source: Detail<Wallet> = try await client.get("/api/v1/wallets/\(transaction.walletId)")
            wallet = source.data
            documents = try await client.all("/api/v1/documents", query: [.init(name: "transaction_id", value: String(transaction.id))])
            audit = try await client.all("/api/v1/price-audit", query: [.init(name: "transaction_id", value: String(transaction.id))])
            loaded = true
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
    private func savePurpose() async {
        guard let client = store.client, !saving else { return }
        struct Update: Encodable, Sendable { let purpose: String }
        saving = true; saved = false; error = nil
        defer { saving = false }
        do {
            let _: Acknowledgement = try await client.send("/api/transactions/\(transaction.id)", method: "PATCH", body: Update(purpose: purpose))
            let updated: Detail<Transaction> = try await client.get("/api/v1/transactions/\(transaction.id)")
            transaction = updated.data; purpose = transaction.purpose ?? ""; saved = true
            store.dataRevision += 1
        } catch { self.error = error.localizedDescription }
    }
}
