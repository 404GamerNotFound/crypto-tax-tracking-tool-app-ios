//
//  ContentView.swift
//  crypto-tax-tracking-tool-app-ios
//
//  Created by Tony Brüser on 02.10.26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()
    var body: some View {
        Group {
            if store.isConnected {
                TabView {
                    NavigationStack { DashboardView() }.tabItem { Label("Überblick", systemImage: "square.grid.2x2") }
                    NavigationStack { WalletsView() }.tabItem { Label("Quellen", systemImage: "wallet.bifold") }
                    NavigationStack { JournalView() }.tabItem { Label("Buchungen", systemImage: "list.bullet.rectangle") }
                    NavigationStack { TaxView() }.tabItem { Label("Steuer", systemImage: "chart.bar.doc.horizontal") }
                    NavigationStack { MoreView() }.tabItem { Label("Mehr", systemImage: "ellipsis.circle") }
                }
                .id(store.sessionID)
            } else { ConnectionView() }
        }
        .environmentObject(store)
        .tint(Theme.green)
        .environment(\.locale, Locale(identifier: "de_DE"))
        .alert("CryptoBuch", isPresented: Binding(get: { store.banner != nil }, set: { if !$0 { store.banner = nil } })) {
            Button("OK", role: .cancel) { store.banner = nil }
        } message: { Text(store.banner ?? "") }
    }
}
