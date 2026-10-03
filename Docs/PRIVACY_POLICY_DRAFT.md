# Datenschutz – Inhalt zur Veröffentlichung

**Redaktioneller Entwurf, vor Veröffentlichung vervollständigen:** Verantwortlicher/Herausgeber, ladungsfähige Kontaktinformationen, Datenschutzkontakt, Veröffentlichungsdatum und die tatsächlich betriebenen Dienste fehlen noch. Diese Notiz gehört nicht auf die fertige öffentliche Seite. Der folgende technische Inhalt muss zum gewählten Betrieb und zur endgültigen Datenschutzerklärung passen; der Betreiber ergänzt die für ihn geltenden rechtlichen Angaben.

## Zweck und Verbindung

CryptoBuch für iOS ist ein Portfolio- und Buchungsjournal. Nach Eingabe von IP-Adresse/Hostname und Port und Betätigen von „Speichern & verbinden“ oder Auswahl aus der gespeicherten Serverliste kontaktiert die App ausschließlich den gewählten CryptoBuch-Server für ihre fachlichen API-Anfragen. Übertragen beziehungsweise abgerufen werden öffentliche Wallet-Adressen und xPubs, Bestände, Transaktionsdaten, Zwecke, historische Bewertungen, Steuer-Schätzungen, Jobstatus, Belegmetadaten und Benachrichtigungen. Zweckänderungen und andere ausdrücklich gestartete Aktionen werden an diesen Server gesendet. Bei späteren App-Starts stellt die App automatisch eine Verbindung zum zuletzt erfolgreich verwendeten Server her. Ohne gespeicherten Startserver findet keine automatische Verbindung statt.

Der Serverbetreiber sieht die Netzwerkverbindung und kann abhängig von seiner Konfiguration Protokolle führen. Die App selbst enthält keinen zentralen Analysedienst, keine Werbung und keine Tracking-SDKs. Sie liest keine Seed-Phrases oder Private Keys und signiert oder sendet keine Blockchain-Transaktionen.

## Speicherung und Kontrolle

Auf dem Gerät speichert die App nur die eingegebenen Serveradressen einschließlich Protokoll und Port sowie die Auswahl des zuletzt erfolgreich verwendeten Servers. Diese Einstellungen können in einer iOS-Gerätesicherung enthalten sein. Finanzantworten und Demoänderungen bleiben nur im Arbeitsspeicher; es gibt keinen dauerhaften Netzwerkcache und keine gespeicherten Sitzungscookies.

Unter „Mehr → Server wechseln / hinzufügen“ lassen sich einzelne Serveradressen entfernen. „Lokale Verbindungsdaten löschen“ entfernt die gesamte Serverliste und den Startserver und beendet die App-Sitzung. Daten, laufende Aufträge und Backups auf dem gewählten Server bleiben davon unberührt. Für deren Aufbewahrung und Löschung ist die konkrete Serverinstallation maßgeblich. Das bestehende Servertool bietet die Verwaltungsfunktionen; bei einem fremd betriebenen Server ist dessen Betreiber zu kontaktieren. Die App eröffnet selbst keine Nutzerkonten.

## Dritte und Sicherheit

Die Blockchain-, Börsen- und Kursdienste werden vom gewählten Server angesteuert. Nutzer wählen den Server; sein Betreiber ist für die dort konfigurierten Anbieter, Aufbewahrungsfristen, Schutzmaßnahmen und Datenschutzinformationen verantwortlich. Falls der App-Herausgeber selbst eine Installation oder andere Dienste betreibt, muss deren Datenverarbeitung hier konkret ergänzt werden; sie ist durch diese allgemeine Beschreibung nicht abgedeckt.

HTTPS verwendet die Zertifikatsprüfung des Betriebssystems. HTTP ist auf lokale Adressen begrenzt, aber unverschlüsselt; es sollte nur in einem vertrauenswürdigen privaten Netz verwendet werden. Die iOS-Berechtigung für das lokale Netzwerk kann jederzeit in den Systemeinstellungen geändert werden. Der Demomodus benötigt keinen Serverzugriff.

Support- und Datenschutzlinks werden nur auf Initiative des Nutzers geöffnet. Das Teilen technischer Versionsdaten nutzt das iOS-Teilen-Menü und enthält keine Serveradresse oder Finanzdaten. Wenn Nutzer selbst Support kontaktieren, bestimmen sie die übermittelten Inhalte und Empfänger. Der Herausgeber muss die Verarbeitung solcher Anfragen, Kontaktmöglichkeiten und Fristen in der veröffentlichten Erklärung ergänzen.
