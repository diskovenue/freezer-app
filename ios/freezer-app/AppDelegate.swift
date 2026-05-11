//
//  AppDelegate.swift
//  freezer-app
//
//  Created by OpenAI on 18.08.25.
//

import UIKit
import UserNotifications
import Supabase

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private enum ShortcutItemType {
        static let scan = "freezer-app.shortcut.scan"
        static let attention = "freezer-app.shortcut.attention"
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        let remoteNotificationLaunchKey = UIApplication.LaunchOptionsKey(rawValue: "UIApplicationLaunchOptionsRemoteNotificationKey")
        if launchOptions?[remoteNotificationLaunchKey] != nil {
            Task { @MainActor in
                AppNavigationState.shared.openAttentionTab()
            }
        }
        requestPushPermission(for: application)
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            handleShortcutItem(shortcutItem)
        }

        return UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(handleShortcutItem(shortcutItem))
    }

    private func requestPushPermission(for application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Push permission error:", error)
            }

            guard granted else {
                print("Push permission denied")
                return
            }

            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        print("APNs token:", token)

        Task {
            await PushRegistration.storeDeviceToken(token)
            await PushRegistration.syncStoredTokenIfPossible()
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNs registration failed:", error)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run {
            AppNavigationState.shared.openAttentionTab()
        }
    }

    @discardableResult
    private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        Task { @MainActor in
            switch shortcutItem.type {
            case ShortcutItemType.scan:
                AppNavigationState.shared.openScanTab()
            case ShortcutItemType.attention:
                AppNavigationState.shared.openAttentionTab()
            default:
                break
            }
        }

        return shortcutItem.type == ShortcutItemType.scan || shortcutItem.type == ShortcutItemType.attention
    }
}

enum PushRegistration {
    private static let defaultsKey = "saved_apns_device_token"

    private struct DeviceTokenPayload: Encodable {
        let user_id: UUID
        let platform: String
        let token: String
        let last_seen_at: String
    }

    static func storeDeviceToken(_ token: String) async {
        UserDefaults.standard.set(token, forKey: defaultsKey)
    }

    static func syncStoredTokenIfPossible() async {
        guard let token = UserDefaults.standard.string(forKey: defaultsKey), !token.isEmpty else {
            return
        }

        do {
            let session = try await SupabaseConfig.client.auth.session
            let payload = DeviceTokenPayload(
                user_id: session.user.id,
                platform: "ios",
                token: token,
                last_seen_at: ISO8601DateFormatter().string(from: Date())
            )

            try await SupabaseConfig.client
                .from("device_tokens")
                .upsert(payload, onConflict: "token")
                .execute()

            print("Device token saved")
        } catch {
            print("Failed to save device token:", error)
        }
    }
}
