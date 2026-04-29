//
//  MainTabView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct MainTabView: View {
    private static let tabActiveTint = Color(red: 0.43, green: 0.67, blue: 0.88)

    @State private var attentionCount = 0
    private let inventoryRepository = InventoryRepository()

    var body: some View {
        TabView {
            InventoryView()
                .tabItem { Label("Bestand", systemImage: "refrigerator.fill") }

            ScanView()
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }

            attentionTab

            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
        .tint(Self.tabActiveTint)
        .task { await loadAttentionCount() }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDataDidChange)) { _ in
            Task { await loadAttentionCount() }
        }
    }

    @MainActor
    private func loadAttentionCount() async {
        do {
            attentionCount = try await inventoryRepository.fetchAttention().count
        } catch {
            attentionCount = 0
        }
    }

    @ViewBuilder
    private var attentionTab: some View {
        if attentionCount > 0 {
            AttentionView()
                .tabItem { Label("Fällig", systemImage: "clock.fill") }
                .badge(attentionCount)
        } else {
            AttentionView()
                .tabItem { Label("Fällig", systemImage: "clock.fill") }
        }
    }
}
