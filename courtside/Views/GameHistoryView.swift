import SwiftUI

struct GameHistoryView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        Text("Game History")
            .navigationTitle("History")
    }
} 
