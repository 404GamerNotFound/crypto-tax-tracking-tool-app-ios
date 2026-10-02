import Foundation

struct Discovery: Decodable, Sendable { let apiVersion: String }
struct Page<Item: Decodable & Sendable>: Decodable, Sendable {
    let data: [Item]
    let pagination: Pagination
    let links: PageLinks
}
struct Pagination: Decodable, Sendable { let limit: Int; let offset: Int; let total: Int; let hasMore: Bool }
struct PageLinks: Decodable, Sendable { let next: String? }
struct Detail<Item: Decodable & Sendable>: Decodable, Sendable { let data: Item }
struct Acknowledgement: Decodable, Sendable {}

struct Metadata: Decodable, Sendable {
    let apiVersion: String
    let purposePresets: [String]
    let chains: [String: Chain]
    struct Chain: Decodable, Sendable {
        let name: String
        let asset: String
        let addressPlaceholder: String?
        let addressHint: String?
        let sourceTypes: [String]
    }
}

struct Wallet: Decodable, Identifiable, Sendable {
    let id: Int
    let chain: String
    let address: String
    let label: String?
    let sourceType: String
    let lastSyncedAt: String?
    let groupName: String?
    let tags: [String]
    var name: String { label?.isEmpty == false ? label! : "\(chain) Wallet" }
    var isExchange: Bool { sourceType == "exchange" }
}

struct Transaction: Decodable, Identifiable, Sendable {
    let id: Int
    let walletId: Int
    let hash: String?
    let timestamp: String?
    let direction: String
    let asset: String
    let assetSymbol: String?
    let assetName: String?
    let amount: Decimal
    let fee: Decimal
    let feeAsset: String?
    let counterparty: String?
    let priceTransactionEur: Decimal?
    let priceSource: String?
    let priceProvider: String?
    let purpose: String?
    let purposeOrigin: String?
    var symbol: String { assetSymbol ?? asset }
    var historicValue: Decimal? { priceTransactionEur.map { $0 * amount } }
    var directionName: String { direction == "in" ? "Eingang" : direction == "out" ? "Ausgang" : "Intern" }
}

struct Portfolio: Decodable, Sendable {
    let holdings: [String: Decimal]
    let assets: [String: Asset]
    let assetPrices: [String: Decimal?]
    let totalValueEur: Decimal
    let insights: Insights
    struct Asset: Decodable, Sendable { let name: String; let symbol: String; let kind: String? }
    struct Insights: Decodable, Sendable {
        let valueHistory: [HistoryPoint]
        let performance: Performance
    }
    struct HistoryPoint: Decodable, Identifiable, Sendable {
        let day: String
        let valueEur: Decimal
        var id: String { day }
    }
    struct Performance: Decodable, Sendable {
        let unrealizedProfitEur: Decimal?
        let realizedYearEur: Decimal?
        let netInvestmentEur: Decimal?
        let purchaseReturnPercent: Decimal?
    }
    struct Holding: Identifiable {
        let id: String
        let name: String
        let symbol: String
        let amount: Decimal
        let price: Decimal?
        var value: Decimal? { price.map { $0 * amount } }
    }
    var positions: [Holding] {
        holdings.filter { $0.value != 0 }.map { key, amount in
            Holding(id: key, name: assets[key]?.name ?? key, symbol: assets[key]?.symbol ?? key,
                    amount: amount, price: assetPrices[key] ?? nil)
        }.sorted { ($0.value ?? 0) > ($1.value ?? 0) }
    }
}

struct Quality: Decodable, Sendable {
    let counts: Counts
    struct Counts: Decodable, Sendable {
        let missingHistoricPrices: Int
        let unassignedPurposes: Int
        let manualHistoricPrices: Int
    }
}

struct Exchange: Decodable, Identifiable, Sendable {
    let id: Int
    let walletId: Int
    let provider: String
    let label: String?
}

struct Job: Decodable, Identifiable, Sendable {
    let id: Int
    let type: String
    let status: String
    let progressCurrent: Int
    let progressTotal: Int
    let errorMessage: String?
    let createdAt: String
    var isActive: Bool { status == "queued" || status == "running" }
    var statusName: String {
        ["queued": "Wartet", "running": "Läuft", "success": "Abgeschlossen", "error": "Fehlgeschlagen"][status] ?? status
    }
}

struct Notice: Decodable, Identifiable, Sendable {
    let id: Int
    let level: String
    let title: String
    let message: String?
    let isRead: Int
    let createdAt: String
}

struct Document: Decodable, Identifiable, Sendable {
    let id: Int
    let originalName: String
    let mimeType: String
    let byteSize: Int
    let sha256: String
}

struct PriceAudit: Decodable, Identifiable, Sendable {
    let id: Int
    let priceEur: Decimal?
    let source: String
    let note: String?
    let changedAt: String
}

struct TaxReport: Decodable, Sendable {
    let year: Int
    let availableYears: [Int]?
    let profile: Profile
    let summary: Summary
    struct Profile: Decodable, Sendable { let label: String; let costBasisMethod: String }
    struct Summary: Decodable, Sendable {
        let saleSegments: Int
        let incompleteSaleSegments: Int
        let incomeEntries: Int
        let incompleteIncomeEntries: Int
        let realizedProfitEur: Decimal
        let incomeEur: Decimal
        let estimatedTaxEur: Decimal
        let estimatedDisposalTaxEur: Decimal
        let estimatedIncomeTaxEur: Decimal
        let taxableSaleProfitEur: Decimal
    }
}
