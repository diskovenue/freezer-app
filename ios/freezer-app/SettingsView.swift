//
//  SettingsView.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI
import Auth

struct SettingsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    NavigationLink("Profil") {
                        ProfileSettingsView(email: auth.session?.user.email)
                    }
                }

                Section("Daten") {
                    NavigationLink("Kategorien") {
                        CategorySettingsView()
                    }

                    NavigationLink("Orte") {
                        LocationSettingsView()
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

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersionText)
                            .foregroundStyle(.secondary)
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

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        case let (nil, build?):
            return build
        default:
            return "-"
        }
    }
}
