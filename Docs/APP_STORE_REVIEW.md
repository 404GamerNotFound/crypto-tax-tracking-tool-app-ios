# App-Store-Vorbereitung – CryptoBuch iOS

Recherche: 03.10.2026. Dies ist ein technischer Prüfstand, keine Zusage einer Apple-Freigabe. Die App bleibt eine native SwiftUI-Anwendung; Serverlogik und Datenbankschema wurden nicht verändert.

## Umgesetzt

| Bereich | Umsetzung |
| --- | --- |
| Datenschutz in der App | Native Datenschutzseite vor der Verbindung und unter Mehr; Datenfluss, Empfänger, Aufbewahrung, Server-Löschung und lokale Berechtigung erklärt. |
| Datenschutzmanifest | `PrivacyInfo.xcprivacy` im App-Target, UserDefaults mit `CA92.1`, kein Tracking. |
| Lokale Datenkontrolle | Einzelne gespeicherte Serveradressen entfernen oder die gesamte Serverliste samt Startserver löschen, offene Netzwerkverbindung schließen und Sitzung verwerfen. Serverseitige Aufträge und Backups bleiben erhalten. |
| Support | Offline-Hilfe, iOS-Einstellungen, Versionsangaben und freiwilliges Teilen von Versionsdaten ohne Server-/Wallet-Adressen. Konfigurierbare öffentliche Support-/Datenschutzlinks. |
| Prüfbare Oberfläche | Sichtbarer Demomodus; Zweckänderungen, gelesene Hinweise und simulierte Jobs bleiben in der Demo-Sitzung. Bewertungs- und Steuerbeispiele sind ausdrücklich feste Szenarien. |
| Netzwerksicherheit | Keine globale ATS-Ausnahme, HTTP nur für lokale Adressen, normale Zertifikatsprüfung; verständlicher HTTP-Hinweis. |
| Verschlüsselung | `ITSAppUsesNonExemptEncryption = NO`: ausschließlich OS-eigenes HTTPS, keine eigene Kryptobibliothek. |
| Schutz im Hintergrund | Abdeckung der verbundenen Ansicht bei inaktiver App; keine dauerhafte Speicherung der Finanzantworten. |
| Veröffentlichungskontrolle | Release-Archive prüfen Herausgeber, Kontakt, echte HTTPS-Links, Privacy-Manifest und Sicherheitskonfiguration. Entwicklungs-Builds bleiben möglich. |

Apple verlangt vollständige, prüfbare Funktionen und zutreffende Metadaten. Datenschutz muss zugänglich sein. Finanz-/Krypto-Bezug und sensible Informationen können Anforderungen an die einreichende Rechtsperson auslösen; ein reines Journal ist keine automatische Ausnahme. Keine Kontoregistrierung, Drittanbieter-Anmeldung oder Käufe werden implementiert. Entsprechende zusätzliche Kontolöschungs-, Login- und Kaufabläufe sind für den aktuellen Funktionsumfang nicht vorgesehen. Quellen: [Review Guidelines, insbesondere 2.1, 3.1.5, 4.2, 5.1.1](https://developer.apple.com/app-store/review/guidelines/), [Vorbereitung auf App Review](https://developer.apple.com/app-store/review/).

## Vor einer Einreichung noch erforderlich

1. In `Publication.plist` tatsächlichen Herausgeber, Kontakt-E-Mail sowie veröffentlichte Datenschutz- und Support-URLs eintragen. Die Seiten müssen ohne Anmeldung erreichbar sein und zum tatsächlichen Betreiber passen. `PRIVACY_POLICY_DRAFT.md` und `SUPPORT_CONTENT.md` liefern dafür Inhalte. Es wurden keine Identitäten oder URLs erfunden und keine Seiten veröffentlicht.
2. Die Einordnung des einreichenden Apple-Developer-Kontos wegen des Finanzdatenbezugs klären. Apple-Kontakt, Rechtsform, Rechte am Namen/Icon und gegebenenfalls EU-Händlerangaben in App Store Connect vervollständigen.
3. Apple einen erreichbaren Testserver mit ausschließlich fiktiven Daten anbieten, sofern die Live-Funktionen geprüft werden sollen. `REVIEW_NOTES.md` erklärt den Unterschied zum Offline-Demo-Szenario. `localhost` und eine private LAN-Adresse sind für Apple kein erreichbarer Review-Zugang. Nicht auf eine Ausnahme für den Demomodus vertrauen; gegebenenfalls vorher mit App Review klären.
4. App-Privacy-Angaben, aktuelle Altersfreigabe-Fragen, Kategorie, Beschreibung, echte iPhone-/iPad-Screenshots und Review-Kontakt in App Store Connect ausfüllen. `STORE_METADATA.json` enthält einen Beschreibungsvorschlag, keine hochgeladenen Metadaten.
5. Auf echten Geräten und iPad prüfen: erstmalige Netzwerkberechtigung, Ablehnung, Wiederverbindung, IPv6/Hostname, HTTPS, schlechter Empfang, alle Tabs, Zweckänderung mit Serverneuberechnung, VoiceOver, große Schrift, Hell-/Dunkelmodus, Hintergrundabdeckung und Zurücksetzen. Keine Barrierefreiheitsmerkmale im Store als geprüft angeben, bevor sie tatsächlich getestet sind.
6. Mit einem aktuell für Uploads akzeptierten Xcode/SDK signieren, archivieren und über TestFlight prüfen. Die veröffentlichte Mindestanforderung ist seit 28.04.2026 Xcode 26 mit iOS-26-SDK oder neuer; ein erfolgreicher lokaler Build ersetzt keine Upload-Validierung. [Apple SDK-Anforderung](https://developer.apple.com/news/upcoming-requirements/?id=04282026a).

## Datenschutzdeklaration korrekt einordnen

Das Manifest beschreibt die aktuelle App ohne zentrale Entwickler-Server, Werbung oder Analyse-SDKs. Der selbst gewählte CryptoBuch-Server erhält API-Anfragen, Aufträge und Zweckänderungen; diese Übertragung wird in der App ausdrücklich erläutert. Das ist keine Behauptung, dass keinerlei Daten das Gerät verlassen. Ob der Herausgeber selbst Server betreibt, Protokolle speichert oder weitere Dienste einbindet, muss vor den App-Privacy-Antworten bestätigt werden. Bei solchen Änderungen sind Manifest, Datenschutzerklärung und Store-Angaben erneut zu bewerten. Lokale UserDefaults können in einer iOS-Sicherung enthalten sein.

Apple unterscheidet lokale Verarbeitung von einer Erhebung durch Entwickler oder Drittpartner und erklärt die Aufbewahrung über die reine Anfrageverarbeitung hinaus. Die Antwort „keine Daten erhoben“ darf daher nicht allein aus dem leeren Manifest abgeleitet werden. [App-Privacy-Definitionen](https://developer.apple.com/app-store/app-privacy-details/). Ein Manifest ersetzt die öffentliche Datenschutzerklärung nicht. [Privacy-Manifest](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [Required-Reason-APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

Die verwendete HTTPS-Verschlüsselung wird durch Apple-Betriebssystem-APIs bereitgestellt. Die gesetzte Exportangabe bezieht sich auf diesen technischen Umfang; zusätzliche Kryptobibliotheken oder Vertriebsanforderungen erfordern eine neue Prüfung. [Apple Export-Dokumentation](https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption/).

## Reproduzierbare Prüfungen

Prüfstand 03.10.2026: iOS-Simulator-Build erfolgreich; Privacy-Manifest, Veröffentlichungskonfiguration und Verschlüsselungsangabe im erzeugten App-Bundle nachgewiesen. 20 Swift-Tests und vier Veröffentlichungstests bestanden; der separate Live-Integrationstest wurde mangels konfigurierter Testinstanz übersprungen. Das Release-Archiv wurde erwartungsgemäß durch die vier fehlenden Herausgeber-/Kontakt-/URL-Angaben gestoppt. `git diff --check` ist sauber.

Die native Bedienprüfung konnte wegen wiederholter Timeouts des Device Hub nicht abgeschlossen werden. Der unveränderte Backend-Testlauf (`npm test`) blieb zweimal nach den ersten sechs erfolgreichen Tests beim Laden bestehender Abhängigkeiten hängen und wurde beendet; für diesen Lauf wird kein vollständiger Testerfolg behauptet. Geräte-/Bedienprüfung und vollständige Backend-Regression bleiben vor einer Einreichung offen.

```sh
swift test
python3 -m unittest discover -s Tests/ReleaseChecks -v
python3 Tools/validate_submission.py
# Nach dem Eintragen echter öffentlicher Seiten zusätzlich:
python3 Tools/validate_submission.py --online
git diff --check
```

Die Veröffentlichungskontrolle muss mit fehlenden Betreiberangaben fehlschlagen. Ein erfolgreiches Ergebnis bestätigt lediglich die geprüften technischen Felder; weder die Rechtmäßigkeit des Inhalts noch Apples Entscheidung. In einem Release-Archiv (`ACTION=install`, `CONFIGURATION=Release`) ist diese Kontrolle eine Xcode-Buildphase und lässt sich nicht versehentlich durch einen normalen Archive-Vorgang überspringen. Der Online-Test erkennt offensichtliche HTTP-Fehler; Inhalt, Kontakt, Zugänglichkeit und Übereinstimmung der Seiten müssen zusätzlich von Menschen geprüft werden.
