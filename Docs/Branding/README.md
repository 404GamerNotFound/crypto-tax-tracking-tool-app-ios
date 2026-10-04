# CryptoBuch – Bildmarke und App-Grafiken

Neue Bildmarke: ein offenes Buch mit angedeutetem C. Mint und Elfenbein auf dunklem Tannengrün greifen die bestehende App-Palette auf. Die ergänzende Illustration zeigt ein Journal, Buchungskarten und verbundene Datenpunkte.

## Verwendung

- `CryptoBuchIcon.appiconset`: neues iOS-App-Icon, 1024 × 1024, ohne Transparenz. Das frühere AppIcon-Set bleibt unverändert erhalten.
- `CryptoBuchLogo.imageset`: Logo in 1×, 2× und 3× für native SwiftUI-Ansichten.
- `CryptoBuchJournal.imageset`: dekorative Illustration für Verbindungsseite und leere Datenansichten.
- `Views/Branding.swift`: gemeinsame native Komponenten. Keine Texte oder echte Finanzdaten in den Bildern; Beschriftungen bleiben skalierbarer, barrierefreier SwiftUI-Text. Dekorative Bilder sind für VoiceOver ausgeblendet.

Alle Assets liegen im App-Bundle. Es gibt keine Bildabrufe bei externen Diensten zur Laufzeit. Dark Mode verwendet dieselben kontrastreichen Grafiken; die umgebende Oberfläche folgt weiterhin den Systemfarben.

## Erzeugung und Originale

Erstellt mit dem integrierten **image_gen**-Werkzeug, kein CLI/API-Key-Fallback. Originale: `CryptoBuch-Logo-Original.png` und `CryptoBuch-Journal-Original.png` in diesem Ordner. Die Illustration wurde mit dem erzeugten Logo als Markenreferenz erstellt. Für iOS wurden ausschließlich die erforderlichen Auflösungen per `sips` exportiert; das Motiv wurde dabei nicht verändert.

## Verwendete Prompts

### Logo

```text
Use case: logo-brand. Asset type: production iOS app icon for CryptoBuch, a German private self-hosted cryptocurrency bookkeeping journal, not a trading exchange. Create one original, elegant, highly legible symbol: a bold open ledger/book silhouette whose flowing folded pages subtly form a letter C, a tiny discreet square ledger detail integrated into the page, a very simple recognizable geometric silhouette with balanced negative space. Existing app palette: forest green #1F644F, pale mint #BDEDC4, very deep pine #102E26. Use pale mint and warm ivory for the symbol on a full-bleed opaque deep pine background with extremely restrained tonal depth. Polished vector-like brand artwork, precise curves, editorial financial journal feel, serene and trustworthy. Center the symbol, occupy approximately 64 percent of the square with generous safe margins. Output exactly a 1024 x 1024 square, fully opaque RGB style, no rounded outer corners (iOS masks them), no external frame, no mockup, no lettering or words, no currencies, no Bitcoin logo, no arrows, no shield, no glossy 3D, no watermark. This must be a finished app icon asset, not a design presentation.
```

### Illustration

```text
Use case: illustration-story. Asset type: native iOS onboarding and empty-state illustration for CryptoBuch. Input image 1 is a brand reference only: retain its original mint and ivory open-book/C symbol as a small printed emblem on the journal cover in this NEW illustration. Create a polished editorial still life of one beautiful deep forest-green bookkeeping journal, three gently overlapping ivory ledger cards with simple mint line markings, and two small connected mint geometric nodes suggesting public wallet data coming into a local journal. Premium tactile matte paper and restrained soft 3D, rounded precise forms, calm studio lighting. Palette from reference: deep pine #102E26, forest green #1F644F, pale mint #BDEDC4, warm ivory. Wide landscape 1536 by 1024 composition on a full-bleed opaque deep pine background with subtle ambient light, balanced centered small group of objects in the central 70 percent, ample breathing room all around. Keep it minimalist and legible when shown at 160 pixels tall in a mobile interface. No text, no numbers, no financial amounts, no arrow implying profit, no currency logos, no screens, no photorealistic coins, no hands, no UI, no watermark. The illustration is a decorative brand asset, not a mockup of the app.
```
