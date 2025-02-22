import FirebaseFirestoreSwift

struct User: Identifiable, Codable {
    @DocumentID var id: String?  // Firestore document ID (UID)
    let email: String
    let firstName: String
    let lastName: String
    var games: [Game] = []  // List of games played
    var friends: [String] = []  // List of friend UIDs
    var playerMatches: [String: Float] = [:]  // Mapping of player name -> % match
   
    // Firestore requires an empty initializer for Codable
    init(id: String? = nil, email: String, firstName: String, lastName: String) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
    }
}
