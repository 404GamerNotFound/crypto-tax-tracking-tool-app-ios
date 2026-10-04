//
//  ContentView.swift
//  crypto-tax-tracking-tool-app-ios
//
//  Created by Tony Brüser on 02.10.26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
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
            } else { NavigationStack { ConnectionView() }.id(store.sessionID) }
        }
        .privacySensitive(store.isConnected && !store.isDemo)
        .accessibilityHidden(store.isConnected && scenePhase != .active)
        .overlay {
            if store.isConnected && scenePhase != .active {
                ZStack {
                    Theme.canvas.ignoresSafeArea()
                    VStack(spacing: 18) {
                        BrandLogo(size: 88)
                        Text("CryptoBuch").font(.title2.weight(.semibold))
                        Label("Geschützt im Hintergrund", systemImage: "lock.fill")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.accessibilityLabel("CryptoBuch ist im Hintergrund")
            }
        }
        .environmentObject(store)
        .task { await store.restoreConnectionIfNeeded() }
        .tint(Theme.green)
        .environment(\.locale, Locale(identifier: "de_DE"))
        .alert("CryptoBuch", isPresented: Binding(get: { store.banner != nil }, set: { if !$0 { store.banner = nil } })) {
            Button("OK", role: .cancel) { store.banner = nil }
        } message: { Text(store.banner ?? "") }
    }
}
