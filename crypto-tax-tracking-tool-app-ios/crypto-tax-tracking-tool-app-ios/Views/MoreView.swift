import SwiftUI

struct MoreView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            DemoFlag().listRowBackground(Color.clear)
            Section("Aktivität") {
                NavigationLink { JobsView() } label: { Label("Hintergrundjobs", systemImage: "arrow.triangle.2.circlepath") }
                NavigationLink { NoticesView() } label: { Label("Benachrichtigungen", systemImage: "bell") }
            }
            Section("Verbindung") {
                LabeledContent("Server", value: store.serverName)
                if !store.isDemo {
                    Text(store.serverText).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
                    LabeledContent("API-Version", value: store.metadata?.apiVersion ?? "Unbekannt")
                }
                Button("Server wechseln / hinzufügen") { store.disconnect() }
                ForgetConnectionButton()
            }
            Section("Hilfe & Datenschutz") {
                NavigationLink { PrivacyView() } label: { Label("Datenschutz", systemImage: "hand.raised") }
                NavigationLink { SupportView() } label: { Label("Hilfe & Support", systemImage: "questionmark.circle") }
            }
            Section("CryptoBuch für iOS") {
                Label("Native App · Version 1.0", systemImage: "book.closed")
                Text("Die App nutzt die bestehende CryptoBuch-API. Portfolio-Berechnung, Synchronisierung und Steuerauswertung laufen auf deinem Server.")
                Text("Auf diesem Gerät werden die Serverliste und der zuletzt verwendete Server gespeichert. Abgerufene Finanzdaten werden nicht dauerhaft zwischengespeichert.")
                Text("Wallets, Börsen-Zugangsdaten, Imports, Belegdateien und Steuerprofile verwaltest du weiterhin im bestehenden Web-Tool.")
            }.font(.footnote)
        }.navigationTitle("Mehr")
    }
}

struct JobsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var jobs: [Job] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var loading = false
    var body: some View {
        List {
            DemoFlag().listRowBackground(Color.clear)
            Section {
                ForEach(jobs.sorted { $0.id > $1.id }) { job in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: job.isActive ? "clock" : job.status == "success" ? "checkmark.circle" : "exclamationmark.circle")
                                .foregroundStyle(job.status == "error" ? Color.red : Theme.green)
                            Text(title(job.type)).font(.headline)
                            Spacer()
                            Text(job.statusName).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(Display.date(job.createdAt)).font(.caption).foregroundStyle(.secondary)
                        if job.isActive && job.progressTotal > 0 {
                            ProgressView(value: Double(min(job.progressCurrent, job.progressTotal)), total: Double(job.progressTotal))
                            Text("\(job.progressCurrent) von \(job.progressTotal)").font(.caption).foregroundStyle(.secondary)
                        }
                        if let message = job.errorMessage, !message.isEmpty { Text(message).font(.footnote).foregroundStyle(.red) }
                    }.padding(.vertical, 5)
                }
            } footer: { Text("Bei laufenden Aufträgen wird der Status alle fünf Sekunden aktualisiert, solange diese Seite im Vordergrund geöffnet ist.") }
            if let error { FailureView(message: error, retry: load) }
            else if !loaded { ProgressView("Aufträge werden geladen …") }
            else if jobs.isEmpty { ContentUnavailableView("Keine Aufträge", systemImage: "checkmark.circle", description: Text("Synchronisierungen werden bei den Quellen gestartet.")) }
        }.navigationTitle("Hintergrundjobs").navigationBarTitleDisplayMode(.inline)
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await load()
                while !Task.isCancelled && jobs.contains(where: \.isActive) && !store.isDemo {
                    do { try await Task.sleep(for: .seconds(5)); try Task.checkCancellation() }
                    catch { break }
                    await load()
                    if error != nil { break }
                }
            }.refreshable { await load() }
    }
    private func title(_ value: String) -> String {
        if value == "demo-sync" { return "Demo-Synchronisierung" }
        return ["wallet-sync": "Wallet-Synchronisierung", "wallet_sync": "Wallet-Synchronisierung", "exchange-sync": "Börsen-Synchronisierung", "exchange_sync": "Börsen-Synchronisierung", "price-backfill": "Historische Kurse", "historical-price-backfill": "Historische Kurse"][value] ?? value
    }
    private func load() async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        if store.isDemo { jobs = store.demoJobs; loaded = true; return }
        guard let client = store.client else { return }
        do { jobs = try await client.all("/api/v1/jobs"); loaded = true }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}

struct NoticesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var notices: [Notice] = []
    @State private var error: String?
    @State private var loaded = false
    @State private var loading = false
    @State private var marking = Set<Int>()
    var body: some View {
        List {
            DemoFlag().listRowBackground(Color.clear)
            ForEach(notices.sorted { $0.id > $1.id }) { notice in
                VStack(alignment: .leading, spacing: 10) {
                    Label(notice.title, systemImage: notice.isRead == 0 ? "circle.fill" : "checkmark.circle")
                        .font(.headline).foregroundStyle(notice.level == "error" ? Color.red : notice.level == "warning" ? Color.orange : Theme.green)
                    if let message = notice.message { Text(message).font(.subheadline) }
                    Text(Display.date(notice.createdAt)).font(.caption).foregroundStyle(.secondary)
                    if notice.isRead == 0 {
                        Button("Als gelesen markieren") { Task { await markRead(notice) } }
                            .font(.caption).disabled(marking.contains(notice.id))
                    }
                }.padding(.vertical, 6)
            }
            if let error { FailureView(message: error, retry: load) }
            else if !loaded { ProgressView("Hinweise werden geladen …") }
            else if notices.isEmpty { ContentUnavailableView("Alles gelesen", systemImage: "bell", description: Text("Es liegen noch keine Benachrichtigungen vor.")) }
        }.navigationTitle("Benachrichtigungen").navigationBarTitleDisplayMode(.inline)
            .task { await load() }.refreshable { await load() }
    }
    private func load() async {
        guard !loading else { return }
        loading = true; error = nil
        defer { loading = false }
        if store.isDemo { notices = store.demoNotices; loaded = true; return }
        guard let client = store.client else { return }
        do { notices = try await client.all("/api/v1/notifications"); loaded = true }
        catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
    private func markRead(_ notice: Notice) async {
        if store.isDemo { store.markDemoNoticeRead(id: notice.id); await load(); return }
        guard let client = store.client, !marking.contains(notice.id) else { return }
        struct Read: Encodable, Sendable { let ids: [Int] }
        marking.insert(notice.id)
        defer { marking.remove(notice.id) }
        do {
            let _: Acknowledgement = try await client.send("/api/notifications/read", method: "PATCH", body: Read(ids: [notice.id]))
            await load()
        } catch { self.error = error.localizedDescription }
    }
}
