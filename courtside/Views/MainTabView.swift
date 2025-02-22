import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        TabView {
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
