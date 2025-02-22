import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import SwiftUI

class AuthenticationManager: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var user: User? // Use your custom User model

    init() {
        if let firebaseUser = Auth.auth().currentUser {
            fetchUser(userId: firebaseUser.uid)
        }
    }

    // MARK: - Sign Up with Email & Password
    func signUp(email: String, password: String, firstName: String, lastName: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil

        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Sign Up Error: \(error.localizedDescription)"
                    completion(false)
                    return
                }

                guard let authUser = result?.user else {
                    self.errorMessage = "User authentication failed"
                    completion(false)
                    return
                }

                let newUser = User(id: authUser.uid, email: email, firstName: firstName, lastName: lastName)

                FirestoreManager.shared.saveUser(newUser) { error in
                    DispatchQueue.main.async {
                        if let error = error {
                            self.errorMessage = "Failed to save user: \(error.localizedDescription)"
                            completion(false)
                        } else {
                            self.user = newUser
                            print("✅ User saved successfully")
                            completion(true)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sign In with Email & Password
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil

        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Sign in failed: \(error.localizedDescription)"
                    completion(false)
                    return
                }

                guard let authUser = authResult?.user else {
                    self.errorMessage = "Authentication failed"
                    completion(false)
                    return
                }

                self.fetchUser(userId: authUser.uid, completion: completion)
            }
        }
    }

    // MARK: - Fetch User from Firestore
    private func fetchUser(userId: String, completion: ((Bool) -> Void)? = nil) {
        FirestoreManager.shared.fetchUser(userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self.user = user
                    completion?(true)
                case .failure(let error):
                    self.errorMessage = "Failed to fetch user: \(error.localizedDescription)"
                    completion?(false)
                }
            }
        }
    }

    // MARK: - Sign Out
    func signOut(completion: @escaping (Bool) -> Void) {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.user = nil
                completion(true)
            }
        } catch let signOutError {
            DispatchQueue.main.async {
                self.errorMessage = "Error signing out: \(signOutError.localizedDescription)"
                completion(false)
            }
        }
    }
}
