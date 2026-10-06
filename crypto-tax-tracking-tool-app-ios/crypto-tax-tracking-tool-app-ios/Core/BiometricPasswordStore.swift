import Foundation
import Security
import LocalAuthentication

@MainActor
protocol ServerPasswordStore {
    func contains(server: String) -> Bool
    func save(_ password: String, server: String) throws
    func load(server: String) async throws -> String
    func remove(server: String)
}

enum BiometricPasswordError: LocalizedError {
    case unavailable, missing, cancelled, failed
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Face ID / Touch ID ist nicht verfügbar. Richte Biometrie und einen Gerätecode ein oder gib dein Server-Passwort manuell ein."
        case .missing: return "Kein gültiges biometrisch geschütztes Passwort vorhanden. Bitte das Server-Passwort erneut eingeben."
        case .cancelled: return "Biometrische Anmeldung abgebrochen. Du kannst dein Passwort manuell eingeben."
        case .failed: return "Das Passwort konnte nicht aus dem Schlüsselbund gelesen oder gespeichert werden. Bitte manuell anmelden."
        }
    }
}

@MainActor
final class BiometricPasswordStore: ServerPasswordStore {
    private nonisolated static let service = "de.cryptobuch.server-password.biometric.v1"
    private nonisolated static func query(_ server: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: server, kSecAttrSynchronizable as String: false]
    }
    func contains(server: String) -> Bool {
        var query = Self.query(server)
        let context = LAContext(); context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        query[kSecReturnAttributes as String] = true
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }
    func save(_ password: String, server: String) throws {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else { throw BiometricPasswordError.unavailable }
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                          .biometryCurrentSet, &error) else { throw BiometricPasswordError.failed }
        var query = Self.query(server)
        query[kSecAttrAccessControl as String] = access
        query[kSecValueData as String] = Data(password.utf8)
        query[kSecAttrLabel as String] = "CryptoBuch Server-Passwort"
        SecItemDelete(Self.query(server) as CFDictionary)
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else { throw BiometricPasswordError.failed }
    }
    func load(server: String) async throws -> String {
        try await Task.detached {
            let context = LAContext()
            context.localizedReason = "Dein CryptoBuch-Passwort für diesen Server freigeben."
            context.localizedFallbackTitle = ""
            defer { context.invalidate() }
            var query = Self.query(server)
            query[kSecUseAuthenticationContext as String] = context
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            if status == errSecUserCanceled { throw BiometricPasswordError.cancelled }
            if status == errSecItemNotFound { throw BiometricPasswordError.missing }
            guard status == errSecSuccess, let data = result as? Data,
                  let password = String(data: data, encoding: .utf8) else { throw BiometricPasswordError.failed }
            return password
        }.value
    }
    func remove(server: String) { SecItemDelete(Self.query(server) as CFDictionary) }
}
