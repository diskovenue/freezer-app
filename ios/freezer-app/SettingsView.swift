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
                    Button("Ausloggen") {
                        Task { await auth.signOut() }
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .alert("Ausloggen fehlgeschlagen", isPresented: authErrorIsPresented) {
                Button("OK", role: .cancel) {
                    auth.errorMessage = nil
                }
            } message: {
                Text(auth.errorMessage ?? "Bitte versuche es erneut.")
            }
        }
    }

    private var authErrorIsPresented: Binding<Bool> {
        Binding(
            get: { auth.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    auth.errorMessage = nil
                }
            }
        )
    }
}
