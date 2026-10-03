import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var store: AppStore
    @State private var host = ""
    @State private var port = "3000"
    @State private var secure = false
    @FocusState private var focused: Bool
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    Image(systemName: "book.closed.fill").font(.title2).foregroundStyle(Theme.mint)
                        .frame(width: 54, height: 54).background(Theme.green, in: RoundedRectangle(cornerRadius: 18))
                    Text("CryptoBuch").font(.title2.weight(.bold))
                }.padding(.top, 40)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Dein Portfolio.\nKlar dokumentiert.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold)).tracking(-0.6)
                    Text("Wallets, Buchungen und die Qualität deiner Daten – direkt von deinem CryptoBuch-Server.")
                        .font(.body).foregroundStyle(.secondary).lineSpacing(3)
                }
                if store.connecting {
                    Card {
                        HStack {
                            ProgressView()
                            Text("Verbindung wird hergestellt …").font(.headline)
                        }
                        Text(store.connectingAddress ?? "").font(.footnote).foregroundStyle(.secondary)
                        Button("Abbrechen") { store.disconnect() }
                            .accessibilityIdentifier("cancelConnection")
                    }
                }
                if let error = store.connectionError {
                    Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red)
                }
                if !store.savedServers.isEmpty { savedServers }
                Card {
                    Label(store.savedServers.isEmpty ? "Mit deinem Server verbinden" : "Weiteren Server hinzufügen", systemImage: "plus.circle").font(.headline)
                    Text("IP-Adresse oder Hostname").font(.caption).foregroundStyle(.secondary)
                    TextField("192.168.178.20", text: $host)
                        .keyboardType(.URL).textInputAutocapitalization(.never)
                        .autocorrectionDisabled().focused($focused)
                        .padding(14).background(Theme.canvas, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("IP-Adresse oder Hostname").accessibilityIdentifier("serverAddress")
                        .submitLabel(.go).onSubmit { connect() }
                    HStack {
                        Text("Port").font(.subheadline)
                        Spacer()
                        TextField("3000", text: $port).keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing).frame(maxWidth: 130)
                            .padding(12).background(Theme.canvas, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Port").accessibilityIdentifier("serverPort")
                    }
                    Toggle("HTTPS verwenden", isOn: $secure)
                    if !secure {
                        Hint(text: "HTTP überträgt deine Daten unverschlüsselt. Nur in einem vertrauenswürdigen privaten Netz verwenden; HTTPS ist empfohlen.", icon: "lock.open")
                    }
                    Button(action: connect) {
                        HStack {
                            Spacer()
                            Text("Speichern & verbinden").fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                            Spacer()
                        }.padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).disabled(host.isEmpty || port.isEmpty)
                        .accessibilityIdentifier("saveAndConnect")
                    Hint(text: "Trage die IP-Adresse deines CryptoBuch-Servers und dessen Port ein. iPhone und Server müssen sich erreichen können, z. B. im selben WLAN. localhost bezeichnet auf dem iPhone das iPhone selbst.")
                }.disabled(store.connecting)
                Button { store.demo() } label: {
                    HStack { Text("App mit Demodaten entdecken"); Spacer(); Image(systemName: "arrow.up.right") }
                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 4)
                }.disabled(store.connecting).accessibilityIdentifier("openDemo")
                Hint(text: "Die App fragt keine Wallet-Schlüssel ab. Zugangsdaten für Börsen bleiben auf deinem Server.", icon: "lock.shield")
                Hint(text: "Mit Speichern & verbinden erlaubst du dieser App, Daten von deinem Server abzurufen. Beim nächsten App-Start verbindet sie sich automatisch mit dem zuletzt erfolgreich verwendeten Server. Aktionen wie Zweckänderungen werden an den verbundenen Server gesendet.")
                HStack {
                    NavigationLink("Datenschutz") { PrivacyView() }
                    Spacer()
                    NavigationLink("Hilfe & Support") { SupportView() }
                }.font(.subheadline).padding(.vertical, 8)
                if !store.savedServers.isEmpty { ForgetConnectionButton() }
                Hint(text: "Der Server besitzt keine eigene Anmeldung. Nutze im Internet einen geschützten HTTPS-Zugang. Die App unterstützt derzeit keine Anmeldung an einem vorgeschalteten Proxy.")
            }.padding(24).frame(maxWidth: 570).frame(maxWidth: .infinity)
        }.background(Theme.canvas).scrollDismissesKeyboard(.interactively)
        .onChange(of: store.savedServers.isEmpty) { _, empty in
            if empty { host = ""; port = "3000"; secure = false }
        }
    }

    private var savedServers: some View {
        Card {
            Label("Gespeicherte Server", systemImage: "server.rack").font(.headline)
            ForEach(store.savedServers) { server in
                HStack(alignment: .center, spacing: 12) {
                    Button {
                        focused = false
                        Task { await store.connect(server.address) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(server.address).font(.subheadline.monospaced()).multilineTextAlignment(.leading)
                                if server.address == store.serverText {
                                    Label("Öffnet beim App-Start", systemImage: "arrow.clockwise")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(store.connecting)
                        .accessibilityLabel("Mit \(server.address) verbinden")
                        .accessibilityValue(server.address == store.serverText ? "Startserver" : "")
                    Button(role: .destructive) { store.removeServer(server) } label: {
                        Image(systemName: "trash").frame(minWidth: 44, minHeight: 44)
                    }.buttonStyle(.plain).foregroundStyle(.red)
                        .accessibilityLabel("\(server.address) aus der Liste entfernen")
                }
                if server.id != store.savedServers.last?.id { Divider() }
            }
            Hint(text: "Tippe auf einen Server, um ihn zu öffnen. Deine Auswahl wird nach erfolgreicher Verbindung zum Startserver. Entfernen löscht nur den Listeneintrag auf diesem Gerät.")
        }
    }
    private func connect() {
        guard !store.connecting else { return }
        focused = false
        do {
            let address = try ServerAddress(host: host, port: port, secure: secure)
            Task { await store.connect(address.url.absoluteString) }
        } catch { store.connectionError = error.localizedDescription }
    }
}
