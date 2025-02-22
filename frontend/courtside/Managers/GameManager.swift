import Foundation
import CoreML
import Vision

class GameManager: ObservableObject {
    @Published var isGameActive = false
    @Published var currentGameStats = GameStats()
    @Published var currentFrame: CGImage?
    
    // Game state
    @Published var score = Score()
    @Published var possession: Team = .none
    
    func startNewGame() {
        isGameActive = true
        currentGameStats = GameStats()
    }
    
    func endGame() {
        isGameActive = false
        // Save game data
    }
}

struct Score {
    var homeTeam: Int = 0
    var awayTeam: Int = 0
}

enum Team {
    case home
    case away
    case none
}

struct GameStats {
    var timestamp = Date()
    // Add more game statistics
} 