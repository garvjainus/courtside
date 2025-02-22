import FirebaseFirestoreSwift

struct Shot: Identifiable, Codable {
    @DocumentID var id: String?  // Firestore document ID (optional)
    let userID: String  // UID of the player who took the shot
    let xPos: Int
    let yPos: Int
    let depth: Int
    let made: Bool

    init(userID: String, xPos: Int, yPos: Int, depth: Int, made: Bool) {
        self.userID = userID
        self.xPos = xPos
        self.yPos = yPos
        self.depth = depth
        self.made = made
    }
}
