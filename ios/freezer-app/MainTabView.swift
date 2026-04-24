//
//  MainTabView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            InventoryView()
                .tabItem { Label("Bestand", systemImage: "tray.full") }

            ScanView()
                .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }

            AttentionView()
                .tabItem { Label("Fällig", systemImage: "exclamationmark.triangle") }

            SettingsView()
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
        }
    }
}
