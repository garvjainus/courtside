import Foundation

class AnalyticsManager: ObservableObject {
    @Published var processingFrames = false
    @Published var currentAnalytics: GameAnalytics?
    
    func processFrame(_ frame: CGImage) {
        // Process frame using ML model
    }
    
    func saveGameAnalytics() {
        // Save to local storage
    }
    
    func syncWithServer() {
        // Sync with backend
    }
}

struct GameAnalytics {
    var playerPositions: [PlayerPosition] = []
    var ballPosition: CGPoint?
    var courtElements: [CourtElement] = []
}

struct PlayerPosition {
    var position: CGPoint
    var playerID: UUID
    var confidence: Float
}

struct CourtElement {
    var type: CourtElementType
    var bounds: CGRect
}

enum CourtElementType {
    case rim
    case backboard
    case threePointLine
} 