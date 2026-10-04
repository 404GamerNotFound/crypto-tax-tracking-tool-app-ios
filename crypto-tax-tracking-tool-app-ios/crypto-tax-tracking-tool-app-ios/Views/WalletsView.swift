import SwiftUI

struct WalletsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var wallets: [Wallet] = []
    @State private var exchanges: [Exchange] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var search = ""
    @State private var adding = false
    private var filtered: [Wallet] {
        wallets.filter { search.isEmpty || [$0.name, $0.address, $0.chain, $0.groupName ?? "", $0.tags.joined(separator: " ")].joined(separator: " ").localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        List {
            DemoFlag().listRowBackground(Color.clear)
            if let error { FailureView(message: error, retry: load).listRowBackground(Color.clear) }
            if !loaded && error == nil { ProgressView("Quellen werden geladen …") }
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
                if search.isEmpty {
                    VStack(spacing: 8) {
                        BrandEmptyState(title: "Platz für deine erste Wallet", message: "Füge eine öffentliche Adresse hinzu. Dein Server lädt die zugehörigen Buchungen.")
                        Button("Wallet hinzufügen") { adding = true }
                            .buttonStyle(.borderedProminent)
                            .disabled(store.isDemo || store.metadata?.chains.isEmpty != false)
                    }.padding(.bottom, 16).listRowBackground(Color.clear)
                } else {
                    ContentUnavailableView("Keine Treffer", systemImage: "magnifyingglass", description: Text("Ändere den Suchbegriff."))
                }
            }
            Section {
                Hint(text: store.isDemo ? "Die Demo enthält feste Wallet-Beispiele. Zum Verwalten eigener Wallets bitte einen Server verbinden." : "Über + eine öffentliche Wallet hinzufügen. Name, Gruppe und Tags lassen sich in der Detailansicht bearbeiten. Börsenverbindungen und Ledger-Adressen werden im Web-Tool eingerichtet.")
            }
        }
        .navigationTitle("Quellen").searchable(text: $search, prompt: "Name, Adresse, Netzwerk oder Tag")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Label("Wallet hinzufügen", systemImage: "plus") }
                    .disabled(store.isDemo || store.metadata?.chains.isEmpty != false)
                    .accessibilityIdentifier("addWallet")
            }
        }
        .sheet(isPresented: $adding) { NavigationStack { WalletEditorView() } }
        .task(id: store.dataRevision) { await load() }.refreshable { await load() }
    }
    private func load() async {
        let session = store.sessionID
        let revision = store.dataRevision
        error = nil
        if store.isDemo { wallets = Demo.wallets; exchanges = []; loaded = true; return }
        guard let client = store.client else { return }
        do {
            let values: [Wallet] = try await client.all("/api/v1/wallets")
            let connections: [Exchange] = try await client.all("/api/v1/exchange-connections")
            try Task.checkCancellation()
            guard session == store.sessionID, revision == store.dataRevision else { return }
            wallets = values; exchanges = connections; loaded = true
        } catch is CancellationError { }
        catch { if session == store.sessionID && revision == store.dataRevision { self.error = error.localizedDescription } }
    }
}

struct WalletDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var wallet: Wallet
    let exchangeID: Int?
    @State private var syncing = false
    @State private var deleting = false
    @State private var deleted = false
    @State private var editing = false
    @State private var confirmingDelete = false
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
                }.disabled(syncing || deleting || (wallet.isExchange && exchangeID == nil && !store.isDemo))
            } footer: { Text("Der Server führt den Auftrag in seiner seriellen Warteschlange aus. Für neue Werte die Übersicht nach Abschluss aktualisieren.") }
            if !wallet.isExchange {
                Section {
                    Button { editing = true } label: { Label("Wallet bearbeiten", systemImage: "pencil") }
                        .disabled(store.isDemo || deleting || syncing)
                    Button(role: .destructive) { confirmingDelete = true } label: {
                        HStack { Label("Wallet löschen", systemImage: "trash"); if deleting { Spacer(); ProgressView() } }
                    }.disabled(store.isDemo || deleting || syncing)
                } footer: {
                    Text(store.isDemo ? "Wallet-Verwaltung benötigt einen verbundenen Server." : "Beim Löschen werden auch die zugehörigen Buchungen und lokalen Belege dauerhaft vom Server entfernt. Die Blockchain-Wallet und ihre Coins bleiben unberührt.")
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle(wallet.name).navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) { NavigationStack { WalletEditorView(wallet: wallet) } }
        .confirmationDialog("Wallet „\(wallet.name)“ löschen?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Wallet und Buchungen löschen", role: .destructive) { Task { await deleteWallet() } }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Die Quelle \(wallet.chain) · \(wallet.address), ihre Buchungen, manuellen Zuordnungen, Verknüpfungen und lokalen Belege werden dauerhaft von \(store.serverName) gelöscht. Diese Aktion ist nicht rückgängig zu machen. Coins werden nicht bewegt.")
        }
        .task(id: store.dataRevision) { await refreshWallet() }
    }
    private func refreshWallet() async {
        guard !deleted, !store.isDemo, let client = store.client else { return }
        let session = store.sessionID
        do {
            let result: Detail<Wallet> = try await client.get("/api/v1/wallets/\(wallet.id)")
            try Task.checkCancellation()
            if session == store.sessionID { wallet = result.data }
        } catch is CancellationError { }
        catch { if session == store.sessionID { self.error = error.localizedDescription } }
    }
    private func deleteWallet() async {
        guard !deleting, !store.isDemo, let client = store.client else { return }
        let session = store.sessionID
        deleting = true; error = nil
        defer { deleting = false }
        do {
            try await client.deleteWallet(id: wallet.id)
            guard session == store.sessionID else { return }
            deleted = true
            store.dataRevision += 1
            dismiss()
            store.banner = "Wallet und zugehörige lokale Buchungsdaten wurden gelöscht."
        } catch is CancellationError { }
        catch { if session == store.sessionID { self.error = error.localizedDescription } }
    }
}

struct WalletEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let wallet: Wallet?
    @State private var chain: String
    @State private var sourceType = "address"
    @State private var address = ""
    @State private var xpubAddressType = "p2wpkh"
    @State private var label: String
    @State private var groupName: String
    @State private var tags: String
    @State private var saving = false
    @State private var error: String?

    init(wallet: Wallet? = nil) {
        self.wallet = wallet
        _chain = State(initialValue: wallet?.chain ?? "BTC")
        _label = State(initialValue: wallet?.label ?? "")
        _groupName = State(initialValue: wallet?.groupName ?? "")
        _tags = State(initialValue: wallet?.tags.joined(separator: ", ") ?? "")
    }
    private var chains: [String: Metadata.Chain] { store.metadata?.chains ?? [:] }
    private var sourceTypes: [String] { (chains[chain]?.sourceTypes ?? []).filter { ["address", "xpub", "stake"].contains($0) } }
    private var cleanAddress: String { address.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var metadata: WalletMetadataUpdate {
        WalletMetadataUpdate(label: label.trimmingCharacters(in: .whitespacesAndNewlines), groupName: groupName.trimmingCharacters(in: .whitespacesAndNewlines), tags: WalletMetadataUpdate.tags(from: tags))
    }
    private var creation: WalletCreation {
        WalletCreation(chain: chain, address: cleanAddress, sourceType: sourceType, xpubAddressType: xpubAddressType,
                       label: metadata.label, groupName: metadata.groupName, tags: metadata.tags)
    }
    private var placeholder: String {
        sourceType == "xpub" ? "xpub…, ypub… oder zpub…" : sourceType == "stake" ? "stake1…" : chains[chain]?.addressPlaceholder ?? "Öffentliche Adresse"
    }
    var body: some View {
        Form {
            if let wallet {
                Section("Öffentliche Quelle") {
                    LabeledContent("Netzwerk", value: wallet.chain)
                    Text(wallet.address).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
                    Hint(text: "Netzwerk, Adresse und Quellentyp gehören fest zu dieser Quelle. Eine andere Adresse bitte als neue Wallet hinzufügen, damit bestehende Buchungen korrekt zugeordnet bleiben.")
                }
            } else {
                Section("Öffentliche Quelle") {
                    Picker("Netzwerk", selection: $chain) {
                        ForEach(chains.keys.sorted(), id: \.self) { key in Text("\(chains[key]?.name ?? key) (\(key))").tag(key) }
                    }
                    if sourceTypes.count > 1 {
                        Picker("Quellentyp", selection: $sourceType) {
                            ForEach(sourceTypes, id: \.self) { type in
                                Text(type == "xpub" ? "Öffentlicher Kontoschlüssel (xPub)" : type == "stake" ? "Cardano-Stake-Adresse" : "Einzelne Adresse").tag(type)
                            }
                        }
                    }
                    TextField(placeholder, text: $address, axis: .vertical)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityLabel("Öffentliche Adresse oder Kontoschlüssel")
                        .accessibilityIdentifier("walletAddress")
                    if sourceType == "xpub" {
                        Picker("Adressformat", selection: $xpubAddressType) {
                            Text("Native SegWit (BIP84)").tag("p2wpkh")
                            Text("SegWit (BIP49)").tag("p2sh-p2wpkh")
                            Text("Legacy (BIP44)").tag("p2pkh")
                        }
                        Hint(text: "Ein xPub kann mehrere öffentliche Adressen offenlegen. Bei ypub und zpub erkennt der Server das Adressformat automatisch.")
                    } else if sourceType == "stake" {
                        Hint(text: "Der Server fasst die verbundenen öffentlichen Cardano-Zahlungsadressen zusammen.")
                    } else if let hint = chains[chain]?.addressHint { Hint(text: hint) }
                    Hint(text: "Nur öffentliche Daten eingeben. Keine Seed-Phrases oder Private Keys. Die Quelle wird auf deinem ausgewählten Server gespeichert.")
                }
            }
            Section("Bezeichnung") {
                TextField("Name (optional)", text: $label).accessibilityIdentifier("walletLabel")
                TextField("Gruppe (optional)", text: $groupName)
                TextField("Tags, durch Komma getrennt", text: $tags)
                Hint(text: "Name: maximal 80 Zeichen · Gruppe: 48 Zeichen · bis zu 12 Tags mit je 32 Zeichen.")
            }
            if wallet == nil {
                Section { Hint(text: "Nach dem Speichern erscheint die Wallet unter Quellen. Öffne sie und wähle Synchronisierung starten, um ihre Buchungen über den Server zu laden.") }
            }
            if let error { Section { Text(error).foregroundStyle(.red).accessibilityIdentifier("walletSaveError") } }
        }
        .disabled(saving)
        .navigationTitle(wallet == nil ? "Wallet hinzufügen" : "Wallet bearbeiten")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(saving)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) {
                Button { Task { await save() } } label: {
                    if saving { ProgressView() } else { Text("Speichern") }
                }.disabled(saving || store.isDemo || (wallet == nil && (cleanAddress.isEmpty || !sourceTypes.contains(sourceType))))
                    .accessibilityIdentifier("saveWallet")
            }
        }
        .onChange(of: chain) { _, _ in sourceType = sourceTypes.first ?? "address"; address = ""; error = nil }
        .onChange(of: sourceType) { _, _ in address = ""; error = nil }
        .onAppear { if wallet == nil && chains[chain] == nil { chain = chains.keys.sorted().first ?? "" } }
    }
    private func save() async {
        guard !saving, !store.isDemo, let client = store.client else { return }
        let session = store.sessionID
        saving = true; error = nil
        defer { saving = false }
        do {
            if let wallet { try await client.updateWallet(id: wallet.id, metadata: metadata) }
            else { _ = try await client.createWallet(creation) }
            guard session == store.sessionID else { return }
            store.dataRevision += 1
            dismiss()
        } catch is CancellationError { }
        catch { if session == store.sessionID { self.error = error.localizedDescription } }
    }
}
