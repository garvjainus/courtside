//
//  courtsideApp.swift
//  courtside
//
//  Created by Garv Jain on 2/22/25.
//

import FirebaseCore
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct courtsideApp: App {
    @StateObject private var gameManager = GameManager()
    @StateObject private var authManager = AuthenticationManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            if authManager.user != nil { // ✅ Updated to check if user is logged in
                HomeView()
                    .environmentObject(gameManager)
                    .environmentObject(authManager)
            } else {
                AuthenticationView()
                    .environmentObject(authManager)
            }
        }
    }
}
