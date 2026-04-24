//
//  freezer_appApp.swift
//  freezer-app
//
//  Created by Andreas Gößl on 24.04.26.
//

import SwiftUI

@main
struct freezer_appApp: App {
    @StateObject private var auth = AuthViewModel()
    @StateObject private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthViewModel

    var body: some View {
        Group {
            if auth.session == nil {
                LoginView()
            } else {
                MainTabView()
            }
        }
        .task {
            await auth.loadSession()
        }
    }
}
