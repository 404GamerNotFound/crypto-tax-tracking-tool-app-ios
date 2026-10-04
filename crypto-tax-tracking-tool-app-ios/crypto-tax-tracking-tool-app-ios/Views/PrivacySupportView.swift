import SwiftUI

struct PrivacyView: View {
    private let publication = Publication.current
    var body: some View {
        List {
            Section("Datenverarbeitung") {
                Text("CryptoBuch zeigt Daten deines selbst betriebenen Servers an. Mit Speichern & verbinden oder durch Auswahl eines gespeicherten Servers lädt die App dein Portfolio, öffentliche Wallet-Adressen, Buchungen und Auswertungen. Bei späteren App-Starts verbindet sie sich automatisch mit dem zuletzt erfolgreich verwendeten Server. Ohne gespeicherten Startserver erfolgt keine automatische Verbindung.")
                Text("Fügst du eine öffentliche Wallet hinzu, bearbeitest oder löschst du sie, änderst du einen Buchungszweck, startest du einen Kursabruf oder eine Synchronisierung oder markierst du einen Hinweis als gelesen, übermittelt die App den jeweiligen Auftrag an diesen Server. Der Server kann dabei auch deine Netzwerkadresse sehen.")
            }
            Section("Speicherung auf dem Gerät") {
                Text("Gespeichert werden deine Serveradressen mit Protokoll und Port sowie die Auswahl des zuletzt erfolgreich verwendeten Servers. Diese Einstellungen können Teil deiner iOS-Gerätesicherung sein. Portfolio- und Buchungsdaten hält die App nur im Arbeitsspeicher; sie verwendet keinen dauerhaften Netzwerkcache und keine gespeicherten Cookies.")
                Text("Unter Mehr → Server wechseln / hinzufügen kannst du einzelne Adressen entfernen. Mit Lokale Verbindungsdaten löschen entfernst du die gesamte Serverliste und den Startserver, beendest die Verbindung und entfernst die angezeigten Daten aus der laufenden App-Sitzung.")
                ForgetConnectionButton()
            }
            Section("Dein Server und externe Anbieter") {
                Text("Daten, Backups und manuelle Zuordnungen auf deinem Server bleiben beim Zurücksetzen der App erhalten. Öffentliche Wallets kannst du unter Quellen in ihrer Detailansicht bearbeiten oder nach Bestätigung mitsamt ihren Buchungen und lokalen Belegen löschen. Weitere Daten und Backups verwaltest du im bestehenden CryptoBuch-Tool beziehungsweise über dessen Betreiber. Eine laufende Server-Synchronisierung wird durch das Trennen der App nicht abgebrochen.")
                Text("Dein Server kann Blockchain- und Kursanbieter abfragen. Welche Anbieter, Speicherfristen und Protokolle genutzt werden, hängt von seiner Konfiguration ab. Prüfe die Datenschutzinformationen dieser Anbieter und verwende nur einen Server, dessen Betreiber du vertraust.")
            }
            Section("Keine Werbung oder Verfolgung") {
                Text("Diese App enthält keine Werbung, keine Analyse-SDKs und kein Nutzertracking. Sie übermittelt keine Finanzdaten an einen zentralen Dienst des App-Herausgebers. Der eingebaute Demomodus verwendet ausschließlich fiktive lokale Beispiele.")
                Text("Die App fragt weder Seed-Phrases noch Private Keys ab. Sie kann keine Coins verwahren, Transaktionen signieren, handeln oder versenden.")
            }
            Section("Netzwerkzugriff und Berechtigungen") {
                Text("Die Berechtigung Lokales Netzwerk dient ausschließlich der Verbindung zu deiner eingegebenen Serveradresse. Ohne diese Berechtigung bleibt der Demomodus nutzbar. Du kannst die Berechtigung jederzeit in den iOS-Einstellungen ändern.")
                Text("HTTPS schützt die Übertragung. HTTP wird nur für lokale Adressen zugelassen und überträgt die Daten unverschlüsselt. Verwende HTTP nur in einem vertrauenswürdigen privaten Netz.")
                OpenSettingsButton()
            }
            if !publication.publisher.isEmpty || publication.privacyLink != nil {
                Section("Herausgeber und Datenschutzkontakt") {
                    if !publication.publisher.isEmpty { Text(publication.publisher) }
                    if let email = publication.emailLink { Link(publication.contactEmail, destination: email) }
                    if let url = publication.privacyLink { Link("Vollständige Datenschutzerklärung", destination: url) }
                }
            }
        }.navigationTitle("Datenschutz").navigationBarTitleDisplayMode(.inline)
    }
}

struct SupportView: View {
    @EnvironmentObject private var store: AppStore
    private let publication = Publication.current
    private var version: String {
        "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))"
    }
    private var diagnostics: String {
        "CryptoBuch iOS \(version)\niOS \(UIDevice.current.systemVersion)\nAPI \(store.metadata?.apiVersion ?? "nicht verbunden")\nModus: \(store.isDemo ? "Demo" : store.isConnected ? "Server" : "nicht verbunden")\n\nKeine Serveradresse, Wallet-Adressen oder Buchungsdaten enthalten."
    }
    var body: some View {
        List {
            Section { BrandLockup().padding(.vertical, 8) }
                .listRowBackground(Color.clear)
            Section("Verbindung einrichten") {
                Text("Starte deinen CryptoBuch-Server. Trage seine IP-Adresse oder seinen Hostnamen und den freigegebenen Port ein, üblicherweise 3000. Verwende auf dem iPhone die Adresse des Servers, nicht localhost.")
                Text("Speichern & verbinden fügt die Adresse zur Serverliste hinzu. Unter Mehr → Server wechseln / hinzufügen kannst du weitere Server speichern, auswählen oder entfernen. Beim nächsten App-Start öffnet sich der zuletzt erfolgreich verwendete Server automatisch. Ist er nicht erreichbar, kannst du ihn über die Liste erneut öffnen oder einen anderen auswählen. Entfernst du den Startserver, wird bis zur nächsten erfolgreichen Auswahl keine automatische Verbindung aufgebaut.")
                Text("iPhone und Server müssen sich erreichen können, etwa im selben WLAN oder über dein privates VPN. HTTPS erfordert ein gültiges, vom Gerät vertrautes Zertifikat. Der Server benötigt die API-Version 1.")
            }
            Section("Wenn der Abruf fehlschlägt") {
                Text("Prüfe IP-Adresse, Port, laufenden Server und die lokale Netzwerkberechtigung. Prüfe außerdem, ob eine Firewall, WLAN-Gastnetztrennung oder ein vorgeschalteter Login den Zugriff verhindert. Die App unterstützt derzeit keine Proxy-Anmeldung.")
                OpenSettingsButton()
                Text("Ziehe eine Übersicht nach unten, um sie neu zu laden. Fehlende Kurse werden als fehlend angezeigt; ein nicht erreichbarer Server wird niemals unbemerkt durch Demodaten ersetzt.")
            }
            Section("Was die App kann") {
                Text("Öffentliche Wallets hinzufügen, benennen, gruppieren und löschen, Portfolio und Buchungen prüfen, Zwecke zuordnen, historische EUR-Kurse gezielt abrufen, Synchronisierungen einplanen, Hinweise lesen und vorhandene Steuer-Schätzungen anzeigen. Börsenverbindungen, Imports, Ledger, Belegdateien, Kurskorrekturen und Steuerprofile werden im CryptoBuch-Servertool verwaltet.")
                Text("Die App ist ein Buchungsjournal und eine Organisationshilfe. Historische Bewertungen und Steuerergebnisse sind unverbindliche Schätzungen, keine Anlage- oder Steuerberatung.")
            }
            if publication.supportLink != nil || publication.emailLink != nil {
                Section("Kontakt") {
                    if !publication.publisher.isEmpty { Text(publication.publisher) }
                    if let url = publication.supportLink { Link("Support kontaktieren", destination: url) }
                    if let email = publication.emailLink { Link(publication.contactEmail, destination: email) }
                    Text("Sende keine Private Keys, Zugangsdaten oder vollständigen Finanzunterlagen. Entferne persönliche Angaben aus Screenshots.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Versionsinformationen") {
                LabeledContent("App", value: version)
                LabeledContent("API", value: store.metadata?.apiVersion ?? "Nicht verbunden")
                ShareLink(item: diagnostics) { Label("Technische Versionsdaten teilen", systemImage: "square.and.arrow.up") }
                Text("Enthält nur App-, iOS- und API-Version sowie den Verbindungsmodus. Keine Serveradresse oder Finanzdaten. Du wählst selbst Empfänger und Versand.").font(.footnote).foregroundStyle(.secondary)
            }
        }.navigationTitle("Hilfe & Support").navigationBarTitleDisplayMode(.inline)
    }
}

struct ForgetConnectionButton: View {
    @EnvironmentObject private var store: AppStore
    @State private var confirming = false
    var body: some View {
        Button("Lokale Verbindungsdaten löschen", role: .destructive) { confirming = true }
            .disabled(store.savedServers.isEmpty && !store.isConnected && !store.connecting)
            .confirmationDialog("Lokale Verbindungsdaten löschen?", isPresented: $confirming, titleVisibility: .visible) {
                Button("Vom Gerät entfernen", role: .destructive) { store.forgetConnection() }
            } message: { Text("Alle gespeicherten Serveradressen, die Auswahl des Startservers und die aktuelle App-Sitzung werden entfernt. Daten und laufende Aufträge auf deinen Servern bleiben erhalten.") }
    }
}

struct OpenSettingsButton: View {
    var body: some View {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            Link("iOS-App-Einstellungen öffnen", destination: url)
        }
    }
}
