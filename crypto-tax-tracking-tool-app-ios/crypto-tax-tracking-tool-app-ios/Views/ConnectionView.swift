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
                Card {
                    Label("Mit deinem Server verbinden", systemImage: "server.rack").font(.headline)
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
                    if let error = store.connectionError {
                        Label(error, systemImage: "exclamationmark.circle").font(.footnote).foregroundStyle(.red)
                    }
                    Button(action: connect) {
                        HStack {
                            Spacer()
                            if store.connecting { ProgressView().tint(.white) }
                            Text(store.connecting ? "Verbindung wird geprüft …" : "Verbinden").fontWeight(.semibold)
                            if !store.connecting { Image(systemName: "arrow.right") }
                            Spacer()
                        }.padding(.vertical, 8)
                    }.buttonStyle(.borderedProminent).disabled(host.isEmpty || port.isEmpty || store.connecting)
                    Hint(text: "Trage die IP-Adresse deines CryptoBuch-Servers und dessen Port ein. iPhone und Server müssen sich erreichen können, z. B. im selben WLAN. localhost bezeichnet auf dem iPhone das iPhone selbst.")
                }
                Button { store.demo() } label: {
                    HStack { Text("App mit Demodaten entdecken"); Spacer(); Image(systemName: "arrow.up.right") }
                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 4)
                }.disabled(store.connecting).accessibilityIdentifier("openDemo")
                Hint(text: "Die App fragt keine Wallet-Schlüssel ab. Zugangsdaten für Börsen bleiben auf deinem Server.", icon: "lock.shield")
                Hint(text: "Mit Verbinden erlaubst du dieser App, die Daten von deinem eingegebenen Server abzurufen. Aktionen wie Zweckänderungen werden an diesen Server gesendet.")
                HStack {
                    NavigationLink("Datenschutz") { PrivacyView() }
                    Spacer()
                    NavigationLink("Hilfe & Support") { SupportView() }
                }.font(.subheadline).padding(.vertical, 8)
                if !store.serverText.isEmpty { ForgetConnectionButton() }
                Hint(text: "Der Server besitzt keine eigene Anmeldung. Nutze im Internet einen geschützten HTTPS-Zugang. Die App unterstützt derzeit keine Anmeldung an einem vorgeschalteten Proxy.")
            }.padding(24).frame(maxWidth: 570).frame(maxWidth: .infinity)
        }.background(Theme.canvas).scrollDismissesKeyboard(.interactively)
        .onChange(of: store.serverText) { _, value in if value.isEmpty { host = ""; port = "3000" } }
        .onAppear {
            if let parts = URLComponents(string: store.serverText), let savedHost = parts.host {
                host = savedHost
                secure = parts.scheme == "https"
                port = String(parts.port ?? (secure ? 443 : 80))
            }
        }
    }
    private func connect() {
        focused = false
        do {
            let address = try ServerAddress(host: host, port: port, secure: secure)
            Task { await store.connect(address.url.absoluteString) }
        } catch { store.connectionError = error.localizedDescription }
    }
}
