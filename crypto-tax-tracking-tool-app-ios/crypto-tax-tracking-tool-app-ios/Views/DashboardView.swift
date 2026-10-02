import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore
    @State private var portfolio: Portfolio?
    @State private var quality: Quality?
    @State private var error: String?
    @State private var qualityError: String?
    @State private var updatedAt: Date?
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                DemoFlag()
                if let portfolio {
                    balanceCard(portfolio)
                    if let error { Label(error, systemImage: "wifi.exclamationmark").font(.footnote).foregroundStyle(.red) }
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 20) { performanceCard(portfolio); qualityCard }
                            .frame(minWidth: 650)
                        VStack(spacing: 20) { performanceCard(portfolio); qualityCard }
                    }
                    if !portfolio.insights.valueHistory.isEmpty {
                        Card {
                            Text("Buchwertverlauf").font(.headline)
                            Chart(portfolio.insights.valueHistory) { point in
                                AreaMark(x: .value("Tag", point.day), y: .value("Buchwert EUR", Display.double(point.valueEur)))
                                    .foregroundStyle(LinearGradient(colors: [Theme.green.opacity(0.22), Theme.green.opacity(0.01)], startPoint: .top, endPoint: .bottom))
                                LineMark(x: .value("Tag", point.day), y: .value("Buchwert EUR", Display.double(point.valueEur)))
                                    .foregroundStyle(Theme.green).lineStyle(StrokeStyle(lineWidth: 2.5))
                            }.chartXAxis(.hidden).chartYAxis { AxisMarks(position: .leading) }
                                .frame(height: 145)
                                .accessibilityLabel("Verlauf des dokumentierten Buchwerts")
                            Hint(text: "Aus Käufen, Verkäufen und bewerteten Erträgen. Kein historischer Marktwert; fehlende Kurse sind nicht enthalten.")
                        }
                    }
                    Card {
                        HStack { Text("Deine Bestände").font(.headline); Spacer(); Text("\(portfolio.positions.count) Assets").font(.caption).foregroundStyle(.secondary) }
                        if portfolio.positions.isEmpty {
                            Hint(text: "Noch keine Bestände vorhanden. Füge im Web-Tool eine öffentliche Wallet oder ein Börsenkonto hinzu.")
                        }
                        ForEach(Array(portfolio.positions.enumerated()), id: \.element.id) { index, holding in
                            VStack(spacing: 10) {
                                HStack(spacing: 12) {
                                    AssetBadge(symbol: holding.symbol)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(holding.name).font(.subheadline.weight(.semibold))
                                        Text(Display.number(holding.amount) + " " + holding.symbol).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(holding.value.map { Display.money($0) } ?? "Kurs fehlt").font(.subheadline.weight(.semibold)).monospacedDigit()
                                }
                                if let value = holding.value, value > 0, portfolio.totalValueEur > 0 {
                                    ProgressView(value: min(1, Display.double(value / portfolio.totalValueEur)))
                                        .tint(Theme.colors[index % Theme.colors.count]).accessibilityLabel("Anteil am bewerteten Portfolio")
                                }
                            }
                            if index < portfolio.positions.count - 1 { Divider() }
                        }
                        Hint(text: "Aktuelle Kurse und Salden stammen vom Server. Kurse können verzögert sein; Buchungsdaten können vom tatsächlichen Börsensaldo abweichen.")
                    }
                    if let updatedAt {
                        Text("Abgerufen um " + updatedAt.formatted(.dateTime.hour().minute()))
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                } else if let error { FailureView(message: error, retry: load) }
                else { ProgressView("Portfolio wird geladen …").frame(maxWidth: .infinity, minHeight: 280) }
            }.padding(20).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }
        .background(Theme.canvas).navigationTitle("Überblick")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Label(store.serverName, systemImage: store.isDemo ? "sparkles" : "externaldrive.connected.to.line.below").font(.caption).foregroundStyle(.secondary) } }
        .task(id: store.dataRevision) { await load() }.refreshable { await load() }
    }

    private func balanceCard(_ portfolio: Portfolio) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Label("Bewertetes Portfolio", systemImage: "chart.pie").font(.subheadline); Spacer(); Text("EUR").font(.caption.weight(.bold)) }
                .foregroundStyle(Theme.mint)
            Text(Display.money(portfolio.totalValueEur))
                .font(.system(size: 38, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1).monospacedDigit()
                .accessibilityIdentifier("portfolioValue")
            let missing = portfolio.positions.filter { $0.price == nil }.count
            Text(missing > 0 ? "\(missing) Assets ohne Kurs sind im Wert nicht enthalten." : "Wert der Bestände mit bekanntem aktuellem Kurs.")
                .font(.footnote).foregroundStyle(.white.opacity(0.8))
        }.padding(24).foregroundStyle(.white).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [Theme.green, Color(red: 0.07, green: 0.24, blue: 0.20)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 28))
    }
    private func performanceCard(_ portfolio: Portfolio) -> some View {
        Card {
            Text("Bekannte Wertentwicklung").font(.headline)
            Metric(label: "Unrealisiertes Ergebnis", value: portfolio.insights.performance.unrealizedProfitEur)
            Divider()
            Metric(label: "Realisiert im laufenden Jahr", value: portfolio.insights.performance.realizedYearEur)
            Hint(text: "Nur auswertbare Buchungen. Fehlende Kurse oder Anschaffungsdaten begrenzen die Aussagekraft.")
        }
    }
    private var qualityCard: some View {
        Card {
            Label("Datenqualität", systemImage: "checkmark.shield").font(.headline)
            if let quality {
                LabeledContent("Kurse fehlen", value: String(quality.counts.missingHistoricPrices))
                LabeledContent("Zweck offen", value: String(quality.counts.unassignedPurposes))
                LabeledContent("Manuelle Kurse", value: String(quality.counts.manualHistoricPrices))
                Hint(text: "Offene Punkte im Journal prüfen und im Web-Tool vervollständigen.")
            } else if let qualityError { Hint(text: qualityError, icon: "exclamationmark.circle") }
            else { ProgressView() }
        }
    }
    private func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        if store.isDemo { portfolio = Demo.portfolio; quality = Demo.quality; updatedAt = Date(); return }
        guard let client = store.client else { return }
        error = nil
        qualityError = nil
        do {
            let result: Portfolio = try await client.get("/api/portfolio")
            try Task.checkCancellation()
            portfolio = result
            updatedAt = Date()
        } catch is CancellationError { return }
        catch { self.error = error.localizedDescription }
        do { quality = try await client.get("/api/data-quality") }
        catch is CancellationError { }
        catch { qualityError = error.localizedDescription }
    }
}
