//
//  courtsideApp.swift
//  courtside
//
//  Created by Garv Jain on 2/22/25.
//

import SwiftUI

@main
struct courtsideApp: App {
    // Add state objects for app-wide data management
    @StateObject private var gameManager = GameManager()
    @StateObject private var analyticsManager = AnalyticsManager()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(gameManager)
                .environmentObject(analyticsManager)
        }
    }
}
