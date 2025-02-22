import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        TabView {
            LiveGameView()
                .tabItem {
                    Label("Live Game", systemImage: "camera.fill")
                }
            
            GameHistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
} 