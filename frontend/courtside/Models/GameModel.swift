import FirebaseFirestoreSwift

struct Game: Identifiable, Codable {
    @DocumentID var id: String?  // Firestore document ID (unique game ID)
    let win: Bool
    let teamScore: Int
    let opponentTeamScore: Int
    let personalPoints: Int
    let personalRebounds: Int
    let personalAssists: Int
    let personalSteals: Int
    let personalBlocks: Int
    let personalTurnovers: Int
    let personalFGMade: Int
    let personal3FGMade: Int
    let personalFGAttempted: Int
    let personal3FGAttempted: Int
    let possessions: Int
    var shots: [Shot] = []  // List of shots taken

    init(win: Bool, teamScore: Int, opponentTeamScore: Int, personalPoints: Int, personalRebounds: Int, personalAssists: Int, personalSteals: Int, personalBlocks: Int, personalTurnovers: Int, personalFGMade: Int, personal3FGMade: Int, personalFGAttempted: Int, personal3FGAttempted: Int, possessions: Int, shots: [Shot] = []) {
        self.win = win
        self.teamScore = teamScore
        self.opponentTeamScore = opponentTeamScore
        self.personalPoints = personalPoints
        self.personalRebounds = personalRebounds
        self.personalAssists = personalAssists
        self.personalSteals = personalSteals
        self.personalBlocks = personalBlocks
        self.personalTurnovers = personalTurnovers
        self.personalFGMade = personalFGMade
        self.personal3FGMade = personal3FGMade
        self.personalFGAttempted = personalFGAttempted
        self.personal3FGAttempted = personal3FGAttempted
        self.possessions = possessions
        self.shots = shots
    }
}
