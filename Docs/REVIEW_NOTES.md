# App Review notes – draft for App Store Connect

CryptoBuch is a native SwiftUI companion for a user-operated portfolio and bookkeeping server. It displays public-address data and historical records. It does not hold cryptocurrency, accept wallet secrets, sign transactions, execute trades, mine, or offer investment advice. All tax figures are explicitly non-binding estimates. There are no accounts created by this app, no social login, advertising, subscriptions, or in-app purchases.

## Offline walkthrough

1. On a fresh installation, launch the app. The first screen asks for a server IP/hostname and port. No automatic request is made without a previously saved start server. After a successful connection, subsequent cold launches reconnect once to the last successfully used server. A failed connection returns to the saved list; it never activates the demo automatically.
2. Privacy and Help are available on this screen without connecting or granting local-network permission.
3. Tap **App mit Demodaten entdecken**. The visible demo label identifies fictional data; this option is available to every user and is not reviewer-specific.
4. Review **Überblick**, **Quellen**, **Buchungen**, **Steuer**, and **Mehr**.
5. Open a demo transaction, change its purpose and save. The journal and quality counters reflect the session change. Demo portfolio/tax values remain explicitly labeled fixed example scenarios; no duplicate tax engine is bundled in the app.
6. Start a synchronization from a demo source: the app creates a clearly simulated example job locally. Under **Mehr → Benachrichtigungen**, mark the example notice as read.
7. **Mehr → Datenschutz** explains the data flows and offers removal of local connection settings. Changes in the demo reset when leaving the session.

## Live API verification — complete before submission

Provide a review-accessible CryptoBuch API v1 test instance, IP/hostname, port and TLS setting in the private Review Notes field. Use fictional records only and keep the instance available for the review. Never supply a user's production portfolio or wallet secrets. Do not insert private test access details into this public repository or the app binary.

The built-in demo does not exercise a real server job or recalculate the server's tax results. For those features, the reviewer must have access to a live test instance; do not describe the offline scenario as a replacement for this access. Discuss any exceptional review environment with Apple beforehand if needed.

With the test server connected, changing a transaction purpose PATCHes the existing API, refreshing views retrieves the server's updated results, and synchronization POSTs to the server's serial job queue. App data is held in memory; only the server address list (protocol and port included) and the last successful selection are saved preferences. **Mehr → Server wechseln / hinzufügen** opens the saved list and allows adding, selecting and removing addresses. **Lokale Verbindungsdaten löschen** clears the entire list and the automatic start destination. Local HTTP supports a user's existing trusted LAN installation; remote servers require HTTPS and standard certificate validation.
