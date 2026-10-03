import Foundation

enum Demo {
    // Fictional sample data, never mixed into a live server response.
    static func decode<T: Decodable>(_ json: String) -> T {
        // Static, fictional fixtures are decoded by the Core regression tests.
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
