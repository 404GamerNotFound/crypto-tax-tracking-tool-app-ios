import SwiftUI

struct TaxView: View {
    @EnvironmentObject private var store: AppStore
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var report: TaxReport?
    @State private var error: String?
    @State private var loading = false
    @State private var generation = UUID()
    private var years: [Int] {
        Array(Set((report?.availableYears ?? []) + Array((Calendar.current.component(.year, from: Date()) - 5)...Calendar.current.component(.year, from: Date())) + [year])).sorted(by: >)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DemoFlag()
                HStack {
                    Text("Jahresübersicht").font(.headline)
                    Spacer()
                    Picker("Jahr", selection: $year) { ForEach(years, id: \.self) { Text(String($0)).tag($0) } }.pickerStyle(.menu)
                        .disabled(store.isDemo)
                }
                if loading { ProgressView("Auswertung wird geladen …").frame(maxWidth: .infinity, minHeight: 160) }
                else if let error { FailureView(message: error, retry: load) }
                else if let report {
                    Card {
                        Label("Unverbindliche Schätzung", systemImage: "info.bubble").font(.subheadline).foregroundStyle(Theme.green)
                        Text(Display.money(report.summary.estimatedTaxEur)).font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                        Text("Geschätzte Steuer laut Serverprofil").font(.subheadline).foregroundStyle(.secondary)
                        Divider()
                        LabeledContent("Profil", value: report.profile.label)
                        LabeledContent("Verfahren", value: report.profile.costBasisMethod)
                        Hint(text: "Organisationshilfe, keine Steuerberatung. Die App übernimmt das Ergebnis der bestehenden Serverlogik. Profil, Haltefristen und Schätzsätze werden im Web-Tool eingestellt.")
                    }
                    Card {
                        Text("Dokumentierte Ergebnisse").font(.headline)
                        Metric(label: "Realisiertes Ergebnis", value: report.summary.realizedProfitEur)
                        Divider()
                        Metric(label: "Bewertete Erträge", value: report.summary.incomeEur)
                        Divider()
                        LabeledContent("Steuerschätzung Verkäufe", value: Display.money(report.summary.estimatedDisposalTaxEur))
                        LabeledContent("Steuerschätzung Erträge", value: Display.money(report.summary.estimatedIncomeTaxEur))
                    }
                    Card {
                        Label("Vollständigkeit", systemImage: "checklist").font(.headline)
                        LabeledContent("Verkaufssegmente", value: String(report.summary.saleSegments))
                        LabeledContent("Davon unvollständig", value: String(report.summary.incompleteSaleSegments))
                        LabeledContent("Ertragsbuchungen", value: String(report.summary.incomeEntries))
                        LabeledContent("Davon unvollständig", value: String(report.summary.incompleteIncomeEntries))
                        Hint(text: "Fehlende Kurse oder Anschaffungsdaten werden nicht ergänzt. Die Summen enthalten nur auswertbare Einträge.", icon: "exclamationmark.circle")
                    }
                }
            }.padding(20).frame(maxWidth: 760).frame(maxWidth: .infinity)
        }.background(Theme.canvas).navigationTitle("Steuerübersicht")
            .task(id: "\(year)|\(store.dataRevision)") { await load() }.refreshable { await load() }
    }
    private func load() async {
        let token = UUID(); generation = token
        loading = true; error = nil
        defer { if generation == token { loading = false } }
        if store.isDemo { report = Demo.tax; year = Demo.tax.year; return }
        guard let client = store.client else { return }
        do {
            let result: TaxReport = try await client.get("/api/tax-report", query: [.init(name: "year", value: String(year))])
            try Task.checkCancellation()
            if generation == token { report = result }
        } catch is CancellationError { }
        catch { if generation == token { self.error = error.localizedDescription } }
    }
}
