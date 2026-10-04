import Foundation

struct WalletInputError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct WalletMetadataUpdate: Encodable, Sendable {
    let label: String
    let groupName: String
    let tags: [String]

    static func tags(from text: String) -> [String] {
        var result: [String] = []
        for value in text.split(separator: ",") {
            let tag = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !tag.isEmpty && !result.contains(tag) { result.append(tag) }
        }
        return result
    }

    func validate() throws {
        guard label.utf16.count <= 80, groupName.utf16.count <= 48 else {
            throw WalletInputError(message: "Der Name darf höchstens 80 und die Gruppe höchstens 48 Zeichen enthalten.")
        }
        guard tags.count <= 12, tags.allSatisfy({ !$0.isEmpty && $0.utf16.count <= 32 }) else {
            throw WalletInputError(message: "Bitte höchstens 12 Tags mit jeweils maximal 32 Zeichen eingeben.")
        }
    }
}

struct WalletCreation: Encodable, Sendable {
    let chain: String
    let address: String
    let sourceType: String
    let xpubAddressType: String
    let label: String
    let groupName: String
    let tags: [String]

    func validate() throws {
        try WalletMetadataUpdate(label: label, groupName: groupName, tags: tags).validate()
        guard !chain.isEmpty, ["address", "xpub", "stake"].contains(sourceType),
              sourceType != "xpub" || chain == "BTC", sourceType != "stake" || chain == "ADA" else {
            throw WalletInputError(message: "Bitte ein unterstütztes Netzwerk und eine passende öffentliche Quelle wählen.")
        }
        // Reject secret-like input before any request. Full network-specific address
        // validation and xPub checksums remain authoritative on the server.
        let lower = address.lowercased()
        guard !address.isEmpty, address.utf16.count <= 120,
              !address.contains(where: { $0.isWhitespace }),
              !["xprv", "yprv", "zprv", "tprv", "uprv", "vprv", "-----", "ed25519:"].contains(where: lower.hasPrefix),
              !(chain == "XLM" && address.hasPrefix("S")),
              !(address.range(of: "^(0x)?[a-fA-F0-9]{64}$", options: .regularExpression) != nil && chain != "NEAR") else {
            throw WalletInputError(message: "Bitte ausschließlich eine öffentliche Adresse oder einen öffentlichen Kontoschlüssel eingeben. Keine Seed-Phrases oder Private Keys.")
        }
        if sourceType == "xpub" {
            guard ["xpub", "ypub", "zpub"].contains(where: address.hasPrefix),
                  ["p2pkh", "p2sh-p2wpkh", "p2wpkh"].contains(xpubAddressType) else {
                throw WalletInputError(message: "Bitcoin benötigt einen öffentlichen xpub-, ypub- oder zpub-Schlüssel und ein gültiges Adressformat.")
            }
        }
        if sourceType == "stake" && !address.hasPrefix("stake1") {
            throw WalletInputError(message: "Eine öffentliche Cardano-Stake-Adresse beginnt mit stake1.")
        }
        if sourceType == "address" {
            let pattern: String?
            switch chain {
            case "BTC": pattern = "^(?:[13][1-9A-HJ-NP-Za-km-z]{25,34}|(?i:bc1)[a-zA-Z0-9]{11,87}|[xyz]pub[1-9A-HJ-NP-Za-km-z]{107})$"
            case "ETH", "BNB", "AVAX": pattern = "^0x[a-fA-F0-9]{40}$"
            case "SOL": pattern = "^[1-9A-HJ-NP-Za-km-z]{32,44}$"
            case "XLM": pattern = "^G[A-Z2-7]{55}$"
            default: pattern = nil
            }
            if let pattern, address.range(of: pattern, options: .regularExpression) == nil {
                throw WalletInputError(message: "Bitte eine öffentliche Adresse im Format des gewählten Netzwerks eingeben.")
            }
        }
    }
}
