import FirebaseFirestore
import FirebaseFirestoreSwift

class FirestoreManager {
    static let shared = FirestoreManager()
    private let db = Firestore.firestore()
    
    // MARK: - Save User
    func saveUser(_ user: User, completion: @escaping (Error?) -> Void) {
        guard let userId = user.id else {
            completion(NSError(domain: "Firestore", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid User ID"]))
            return
        }

        let userRef = db.collection("users").document(userId)

        // Force Firestore to go online before writing
        db.disableNetwork { error in
            if let error = error {
                print("⚠️ Failed to disable Firestore network: \(error.localizedDescription)")
            } else {
                self.db.enableNetwork { error in
                    if let error = error {
                        print("⚠️ Failed to enable Firestore network: \(error.localizedDescription)")
                        completion(error)
                        return
                    }

                    // Now Firestore is online, try saving the user
                    do {
                        try userRef.setData(from: user, merge: true, completion: completion)
                    } catch {
                        completion(error)
                    }
                }
            }
        }
    }


    // MARK: - Fetch User
    func fetchUser(userId: String, completion: @escaping (Result<User, Error>) -> Void) {
        let docRef = db.collection("users").document(userId)
        docRef.getDocument { document, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let document = document, document.exists else {
                completion(.failure(NSError(domain: "Firestore", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])))
                return
            }
            do {
                let user = try document.data(as: User.self)
                completion(.success(user))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Save Game
    func saveGame(_ game: Game, completion: @escaping (Error?) -> Void) {
        let gameRef = db.collection("games").document()
        var newGame = game
        newGame.id = gameRef.documentID
        do {
            try gameRef.setData(from: newGame, merge: true, completion: completion)
        } catch {
            completion(error)
        }
    }
    
    // MARK: - Fetch Games
    func fetchGames(userId: String, completion: @escaping (Result<[Game], Error>) -> Void) {
        db.collection("games")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                let games = documents.compactMap { try? $0.data(as: Game.self) }
                completion(.success(games))
            }
    }

    // MARK: - Save Shot
    func saveShot(_ shot: Shot, gameId: String, completion: @escaping (Error?) -> Void) {
        let shotRef = db.collection("games").document(gameId).collection("shots").document()
        var newShot = shot
        newShot.id = shotRef.documentID
        do {
            try shotRef.setData(from: newShot, merge: true, completion: completion)
        } catch {
            completion(error)
        }
    }

    // MARK: - Fetch Shots for a Game
    func fetchShots(gameId: String, completion: @escaping (Result<[Shot], Error>) -> Void) {
        db.collection("games").document(gameId).collection("shots")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                let shots = documents.compactMap { try? $0.data(as: Shot.self) }
                completion(.success(shots))
            }
    }
}
