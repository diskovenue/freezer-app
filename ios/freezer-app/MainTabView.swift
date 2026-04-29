//
//  MainTabView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct MainTabView: View {
    private static let tabActiveTint = Color(red: 0.43, green: 0.67, blue: 0.88)

    @EnvironmentObject private var navigation: AppNavigationState
    @State private var attentionCount = 0
    private let inventoryRepository = InventoryRepository()

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            InventoryView()
                .tag(AppTab.inventory)
                .tabItem { Label("Bestand", systemImage: "refrigerator.fill") }

            ScanView()
                .tag(AppTab.scan)
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }

            AttentionView()
                .tag(AppTab.attention)
                .tabItem { Label("Fällig", systemImage: "clock.fill") }
                .badge(attentionBadgeValue)

            SettingsView()
                .tag(AppTab.settings)
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
        .tint(Self.tabActiveTint)
        .task { await refreshAttentionState() }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryDataDidChange)) { _ in
            Task { await refreshAttentionState() }
        }
    }

    @MainActor
    private func refreshAttentionState() async {
        do {
            let attentionItems = try await inventoryRepository.fetchAttention()
            attentionCount = attentionItems.count
            ListCache.save(attentionItems, for: .attention)
        } catch {
            attentionCount = 0
        }
    }

    private var attentionBadgeValue: String? {
        attentionCount > 0 ? String(attentionCount) : nil
    }
}
