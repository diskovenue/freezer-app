//
//  SettingsView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("Daten") {
                    NavigationLink("Kategorien") {
                        CategorySettingsView()
                    }
                }
                
                Section("Darstellung") {
                    Picker("Modus", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                Section {
                    Button("Logout") {
                        Task { await auth.signOut() }
                    }
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}
