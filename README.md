# CryptoBuch für iOS

Native SwiftUI-App für das bestehende CryptoBuch-Tool. Die App verwendet ausschließlich dessen HTTP-API; Portfolio-, Import-, Kurs- und Steuerlogik bleiben auf dem Server. Es gibt weder WebView noch ein zusätzliches Web-Frontend.

## Starten

1. `crypto-tax-tracking-tool-app-ios/crypto-tax-tracking-tool-app-ios.xcodeproj` in Xcode öffnen. Das vorhandene Projektformat stammt aus Xcode 27; die App unterstützt iOS/iPadOS 17 oder neuer.
2. Einen iPhone- oder iPad-Simulator auswählen und mit **Run** starten. Für ein echtes Gerät bei Bedarf das eigene Signing-Team auswählen. Bundle-ID und vorhandenes Team wurden übernommen.
3. Auf der ersten Seite **IP-Adresse bzw. Hostname** und **Port** des bestehenden Servers eingeben, z. B. `192.168.178.20` und `3000`. HTTPS aktivieren, wenn der Server TLS verwendet.
4. **Speichern & verbinden** fügt die Adresse zur dauerhaften Serverliste hinzu und prüft zuerst `/api/v1` und `/api/v1/metadata`. Erst danach erscheint die App mit den Inhalten dieses Servers.

Der Server muss separat laufen und vom Gerät erreichbar sein. Auf dem echten iPhone meint `localhost` das iPhone selbst; verwende dort die LAN-Adresse des Rechners/NAS. Im iOS-Simulator kann ein auf dem Mac laufender Server unter `127.0.0.1` erreicht werden. Den lokalen Netzwerkzugriff unter iOS erlauben. Unter **Mehr → Server wechseln / hinzufügen** können weitere IP-Adressen mit Port und HTTPS-Einstellung gespeichert, ausgewählt und einzeln entfernt werden. Gleiche Adressen werden nicht doppelt angelegt; andere Ports oder Protokolle bleiben getrennte Einträge. Bei jedem Kaltstart verbindet sich die App einmal automatisch mit dem zuletzt erfolgreich verwendeten Server. Bei einem Fehler bleiben die Serverliste und eine erneute Auswahl verfügbar; der Verbindungsversuch ist abbrechbar. Neue gültige Adressen bleiben auch bei Nichterreichbarkeit gespeichert, ersetzen den Startserver aber erst nach erfolgreicher API-Prüfung. Wird der Startserver gelöscht, erfolgt bis zur nächsten erfolgreichen Auswahl keine automatische Verbindung.

Der separat auswählbare Demomodus enthält klar gekennzeichnete, fiktive Daten. Zweckänderungen, gelesene Hinweise und simulierte Jobs bleiben nur innerhalb seiner Sitzung. Bewertungs- und Steuerbeispiele sind feste Szenarien. Er führt keine API-Schreibaktionen aus und wird niemals als Ersatz für einen fehlgeschlagenen Serverabruf angezeigt.

## App-Store-Vorbereitung

Datenschutz und Hilfe sind bereits vor der Serververbindung sowie unter **Mehr** erreichbar. **Lokale Verbindungsdaten löschen** entfernt die gesamte Serverliste und den Startserver und beendet die Sitzung; Serverdaten werden dabei nicht gelöscht. Die native App enthält ein Privacy-Manifest, eine Erklärung der OS-eigenen HTTPS-Verschlüsselung und eine Abdeckung der verbundenen Ansicht im Hintergrund.

Vor einer Einreichung müssen reale Herausgeber-/Kontaktangaben sowie öffentliche HTTPS-Adressen in `crypto-tax-tracking-tool-app-ios/crypto-tax-tracking-tool-app-ios/Publication.plist` ergänzt werden. Fehlende Angaben verhindern ein Release-Archiv, aber keinen normalen Entwicklungs-Build. Die Seiten wurden nicht veröffentlicht. Siehe [Recherche und offene Einreichungsschritte](Docs/APP_STORE_REVIEW.md), [Review-Anleitung](Docs/REVIEW_NOTES.md) und [Metadatenentwurf](Docs/STORE_METADATA.json).

## Funktionen und API-Zuordnung

| Native Ansicht / Aktion | Bestehende API |
| --- | --- |
| Verbindungsprüfung, unterstützte Zwecke | `GET /api/v1`, `GET /api/v1/metadata` |
| Portfolio, Bestände, Buchwertverlauf | `GET /api/portfolio` |
| Datenqualität | `GET /api/data-quality` |
| Wallet hinzufügen / bearbeiten / löschen | `POST /api/wallets`, `PATCH /api/wallets/{id}`, `DELETE /api/wallets/{id}` |
| Wallets und Börsenkonten | `GET /api/v1/wallets`, `GET /api/v1/exchange-connections` |
| Buchungsjournal, Serverfilter, weitere Seiten | `GET /api/v1/transactions` und `links.next` |
| Buchung, zugehörige Wallet, Belegmetadaten, Kurs-Audit | `GET /api/v1/{transactions,wallets}/{id}`, `GET /api/v1/documents`, `GET /api/v1/price-audit` |
| Historischen EUR-Kurs einer Buchung neu abrufen | `POST /api/transactions/{id}/historical-price/fetch`, anschließend `GET /api/jobs/{id}` und erneuter Buchungs-/Audit-Abruf |
| Manuellen Zweck speichern | `PATCH /api/transactions/{id}` |
| Wallet-/Börsensynchronisierung einplanen | `POST /api/jobs/sync`, `POST /api/exchange-connections/{id}/sync` |
| Jobstatus | `GET /api/v1/jobs` |
| Hinweise lesen und als gelesen markieren | `GET /api/v1/notifications`, `PATCH /api/notifications/read` |
| Jahresauswertung gemäß Serverprofil | `GET /api/tax-report?year=…` |

Das Journal lädt 50 Einträge je Seite in der von der API gelieferten ID-Reihenfolge. Die Anzeige nennt die geladene und gesamte Anzahl. Richtung und Zweck werden serverseitig gefiltert, die Textsuche durchsucht ausdrücklich nur geladene Einträge. Andere Listen folgen der API-Paginierung vollständig (bis maximal 200 Seiten). Bei aktiven Jobs erfolgt im geöffneten Vordergrund alle fünf Sekunden eine Statusabfrage. Auf den Übersichten aktualisiert Ziehen nach unten die Daten. In den Buchungsdetails startet **Jetzt Kursdaten abrufen** einen gezielten historischen EUR-Kursabruf. Die App verfolgt den Job nur in der aktiven Ansicht und lädt danach Kurs, Herkunft und Audit neu. Fehlende Kurse bleiben offen; manuelle/importierte Kurse sind geschützt. Der Server arbeitet nach Verlassen der Ansicht weiter. Die Aktion benötigt einen Backend-Stand mit diesem Endpunkt; im Demomodus findet kein Kursabruf statt.

## Architektur und Datenschutz

- `Core/APIClient.swift`: typisierter, asynchroner URLSession-Client, Versionsprüfung, JSON-Fehler, Paginierung und URL-Validierung. Keine Abhängigkeiten von Drittanbietern.
- `Core/Models.swift`: API-Modelle mit `Decimal` für Beträge. Fehlende Preise bleiben `nil`; EUR-Werte werden nicht als null Euro erfunden.
- `Core/AppStore.swift`: Verbindung, einmalige Wiederverbindung beim Start und Sitzungswechsel. Abbruch und Löschen entwerten laufende Verbindungsversuche, damit verspätete Antworten keine alte Sitzung wiederherstellen. `URLSessionConfiguration.ephemeral`, kein URL-Cache, keine Cookies und keine gespeicherten HTTP-Zugangsdaten.
- `Core/ServerPreferences.swift`: Nur die Serverliste und der zuletzt erfolgreich verwendete Server werden in `UserDefaults` gespeichert. Die bisherige Einstellung `serverURL` wird beim ersten Lesen verlustfrei in die neue Liste übernommen und danach entfernt. Ungültige gespeicherte Adressen werden nicht verwendet.
- `Views/`: native SwiftUI-Ansichten; der Buchwertverlauf nutzt Swift Charts. Oberflächensprache Deutsch, iPhone/iPad, Systemfarben für Hell-/Dunkelmodus.
- `Config/Info.plist`: lokaler Netzwerkzugriff und auf private/Loopback-IP-Bereiche beschränkte HTTP-Ausnahmen. Öffentliche Server benötigen HTTPS. Zertifikatsprüfungen werden nicht umgangen, Weiterleitungen abgelehnt. Hintergrund: [Apples Dokumentation zu lokalem Netzwerkzugriff und ATS](https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking).

Es werden keine Seeds, Private Keys, Signaturen oder Transaktionsentwürfe abgefragt. Börsen-Zugangsdaten bleiben serverseitig. Serverantworten werden nicht protokolliert. Der Server besitzt keine eingebaute Anmeldung: für entfernten Zugriff ein vertrauenswürdiges privates Netz/VPN oder einen geeignet geschützten Zugang verwenden. Die App implementiert aktuell keine Anmeldung an einem vorgeschalteten Authentifizierungsproxy.

## Grenzen dieser Version

Börsenkonten anlegen, CSV-Import, Ledger, Belegdateien, manuelle Kurskorrekturen, Backups und Steuerprofile bleiben im bestehenden Web-Tool. Die App zeigt Belegmetadaten und Kurskorrekturen an, lädt aber keine Belegdateien herunter. Es gibt keine Push-Benachrichtigungen, keinen Offline-Datenspeicher und keine eigene Blockchain-Abfrage.

Steuerwerte und historische Bewertungen bleiben **unverbindliche Schätzungen und Organisationshilfe, keine Steuerberatung**. Unvollständige Datensätze werden sichtbar ausgewiesen. Alle fachlichen Berechnungen und ihre Einschränkungen werden unverändert vom bestehenden Server übernommen. Es sind keine Datenmigrationen am Backend erforderlich.

## Prüfen

```sh
swift test
git diff --check
xcodebuild \
  -project crypto-tax-tracking-tool-app-ios/crypto-tax-tracking-tool-app-ios.xcodeproj \
  -scheme crypto-tax-tracking-tool-app-ios \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/cryptobuch-ios-derived \
  CODE_SIGNING_ALLOWED=NO build
```

Die Core-Tests prüfen Speicherung mehrerer Server, Migration der bisherigen Adresse, Duplikate, automatische Verbindung, Serverwechsel, Offline-Verhalten, Abbruch/Löschen während eines Abrufs sowie IP/Port, IPv6, HTTPS, ungültige Zugangsdaten-URLs, fremde API-Links, Paginierung, Endlosschleifen, Dezimalwerte, fehlende Kurse und API-Fehler. Für einen zusätzlichen lesenden Vertragstest gegen eine **separate Testinstanz**:

```sh
CRYPTOBUCH_TEST_SERVER=http://127.0.0.1:3085 swift test --filter ServerIntegrationTests
```

Ohne diese Umgebungsvariable wird der Integrationstest übersprungen. Die Unit-Tests rufen keine externen Dienste auf. Ein signierter Geräte-Build und eine App-Store-Veröffentlichung sind separate Schritte.

### Wallet-Verwaltung in der App

Unter **Quellen → +** lassen sich öffentliche Wallets mit Netzwerk, Quellentyp, Adresse, Name, Gruppe und Tags hinzufügen. Die Auswahl nutzt `/api/v1/metadata`; Bitcoin unterstützt einzelne Adressen und xpub/ypub/zpub mit BIP44/49/84, Cardano auch Stake-Adressen. Nach dem Anlegen kann die Synchronisierung in der Wallet-Detailansicht separat gestartet werden.

In der Detailansicht können Name, Gruppe und Tags geändert oder die Wallet nach ausdrücklicher Bestätigung gelöscht werden. Netzwerk, öffentliche Adresse und Quellentyp bleiben unveränderlich, damit vorhandene Buchungen nicht einer anderen Quelle zugeordnet werden. Löschen entfernt auch die abhängigen Buchungen, Verknüpfungen und lokalen Belege auf dem Server; die Blockchain und Coins bleiben unverändert. Die App verarbeitet die leere HTTP-204-Antwort korrekt und lädt betroffene Ansichten neu. Im Demomodus sind Schreibaktionen für Wallets deaktiviert.

POST/PATCH verwenden das bestehende Schreibformat (camelCase; `tags` in der Antwort als JSON-String). Die App wertet die bestätigte ID aus und lädt anschließend normalisierte Wallet-Daten über die v1-Lese-API. Netzwerkfehler, Dubletten (409), ungültige Eingaben und verschwundene Wallets (404) bleiben sichtbar; fehlgeschlagene Schreibaktionen werden nicht automatisch wiederholt.

### Logo und App-Bilder

Die native App verwendet eine eigene CryptoBuch-Bildmarke und eine passende Journal-Illustration. Das neue `CryptoBuchIcon` ist als iOS-App-Icon konfiguriert. Logo und Illustration sind lokale Asset-Kataloge; sie erscheinen in der Verbindungseinrichtung, im Überblick, bei leeren Wallet-/Portfolio-Ansichten, in der Hilfe und auf der Sichtschutzansicht im Hintergrund. Es werden keine Bilder aus dem Netz nachgeladen. Texte bleiben native, skalierbare SwiftUI-Elemente; dekorative Bilder sind für VoiceOver ausgeblendet.

Originale, Gestaltung und die verwendeten Imagegen-Prompts sind unter [Docs/Branding](Docs/Branding/README.md) dokumentiert. Das frühere App-Icon bleibt als unbenutztes `AppIcon`-Set erhalten.
