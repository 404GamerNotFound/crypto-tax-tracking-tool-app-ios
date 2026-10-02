import SwiftUI

enum Theme {
    static let green = Color(red: 0.12, green: 0.39, blue: 0.31)
    static let mint = Color(red: 0.74, green: 0.93, blue: 0.77)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let colors: [Color] = [green, .orange, .blue, .purple, .teal, .pink]
}

enum Display {
    static func money(_ value: Decimal?) -> String {
        guard let value else { return "Nicht verfügbar" }
        return value.formatted(.currency(code: "EUR").locale(Locale(identifier: "de_DE")))
    }
    static func number(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0...8)).locale(Locale(identifier: "de_DE")))
    }
    static func date(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "Noch nicht verfügbar" }
        let normalized = value.contains("T") ? value : value.replacingOccurrences(of: " ", with: "T") + "Z"
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed = parser.date(from: normalized)
        parser.formatOptions = [.withInternetDateTime]
        guard let date = parsed ?? parser.date(from: normalized) else { return value }
        return date.formatted(.dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "de_DE")))
    }
    static func short(_ value: String) -> String {
        value.count > 28 ? "\(value.prefix(12))…\(value.suffix(8))" : value
    }
    static func double(_ value: Decimal) -> Double { NSDecimalNumber(decimal: value).doubleValue }
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24))
    }
}

struct DemoFlag: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        if store.isDemo {
            Label("Demodaten · fiktives Portfolio", systemImage: "sparkles")
                .font(.caption.weight(.semibold)).foregroundStyle(Theme.green)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Theme.mint.opacity(0.35), in: Capsule())
                .accessibilityIdentifier("demoIndicator")
        }
    }
}

struct FailureView: View {
    let message: String
    var retry: (() async -> Void)? = nil
    var body: some View {
        ContentUnavailableView {
            Label("Abruf nicht möglich", systemImage: "wifi.exclamationmark")
        } description: { Text(message) } actions: {
            if let retry { Button("Erneut versuchen") { Task { await retry() } }.buttonStyle(.borderedProminent) }
        }
    }
}

struct Hint: View {
    let text: String
    var icon = "info.circle"
    var body: some View {
        Label(text, systemImage: icon).font(.footnote).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct Metric: View {
    let label: String
    let value: Decimal?
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(Display.money(value)).font(.title3.weight(.semibold)).monospacedDigit()
                .foregroundStyle(value.map { $0 < 0 } == true ? Color.red : Color.primary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AssetBadge: View {
    let symbol: String
    var body: some View {
        Text(String(symbol.prefix(3))).font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.green).frame(width: 44, height: 44)
            .background(Theme.mint.opacity(0.35), in: RoundedRectangle(cornerRadius: 15))
            .accessibilityHidden(true)
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.direction == "in" ? "arrow.down.left" : transaction.direction == "out" ? "arrow.up.right" : "arrow.left.arrow.right")
                .foregroundStyle(transaction.direction == "in" ? Theme.green : Color.secondary)
                .frame(width: 38, height: 38).background(Theme.canvas, in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(transaction.purpose?.isEmpty == false ? transaction.purpose! : "Zweck offen").font(.subheadline.weight(.semibold))
                Text(transaction.symbol + " · " + Display.date(transaction.timestamp)).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 5) {
                Text((transaction.direction == "out" ? "−" : transaction.direction == "in" ? "+" : "") + Display.number(transaction.amount))
                    .font(.subheadline.weight(.medium)).monospacedDigit()
                Text(transaction.historicValue.map { Display.money($0) } ?? "Kurs fehlt")
                    .font(.caption).foregroundStyle(transaction.historicValue == nil ? Color.orange : .secondary)
            }
        }.padding(.vertical, 4)
    }
}
