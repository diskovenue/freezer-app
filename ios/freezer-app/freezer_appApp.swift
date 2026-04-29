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
        ZStack {
            if !auth.hasLoadedSession {
                launchLoadingView
                    .transition(rootTransition)
            } else if auth.session == nil {
                LoginView()
                    .transition(rootTransition)
            } else {
                MainTabView()
                    .transition(rootTransition)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: auth.hasLoadedSession)
        .animation(.easeInOut(duration: 0.28), value: auth.session != nil)
        .task {
            await auth.loadSession()
        }
    }

    private var launchLoadingView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ProgressView()
                .controlSize(.large)
        }
    }

    private var rootTransition: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.985))
    }
}
