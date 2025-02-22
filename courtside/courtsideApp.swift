//
//  courtsideApp.swift
//  courtside
//
//  Created by Garv Jain on 2/22/25.
//

import SwiftUI

@main
struct courtsideApp: App {
    @StateObject private var gameManager = GameManager()
    @StateObject private var analyticsManager = AnalyticsManager()
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                MainTabView()
                    .environmentObject(gameManager)
                    .environmentObject(analyticsManager)
                    .environmentObject(authManager)
            } else {
                AuthenticationView()
                    .environmentObject(authManager)
            }
        }
    }
}
