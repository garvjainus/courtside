import SwiftUI
import AVFoundation

struct LiveGameView: View {
    @EnvironmentObject var gameManager: GameManager
    @EnvironmentObject var analyticsManager: AnalyticsManager
    @State private var showingGameControls = true
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView()
                .edgesIgnoringSafeArea(.all)
            
            // Overlay with real-time analytics
            if showingGameControls {
                VStack {
                    ScoreboardView()
                    
                    Spacer()
                    
                    GameControlsView()
                }
                .padding()
            }
            
            // Toggle controls button
            VStack {
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showingGameControls.toggle()
                    }
                }) {
                    Image(systemName: showingGameControls ? "chevron.down" : "chevron.up")
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.bottom)
            }
        }
    }
}

struct ScoreboardView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        HStack {
            Text("Home: \(gameManager.score.homeTeam)")
            Spacer()
            Text("Away: \(gameManager.score.awayTeam)")
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
}

struct GameControlsView: View {
    @EnvironmentObject var gameManager: GameManager
    
    var body: some View {
        HStack {
            Button(action: {
                if gameManager.isGameActive {
                    gameManager.endGame()
                } else {
                    gameManager.startNewGame()
                }
            }) {
                Text(gameManager.isGameActive ? "End Game" : "Start Game")
                    .padding()
                    .background(gameManager.isGameActive ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }
} 