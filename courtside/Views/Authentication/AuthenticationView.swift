import SwiftUI

struct AuthenticationView: View {
    @State private var showSignUp = false
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo or App Name
                Text("Courtside")
                    .font(.system(size: 40, weight: .bold))
                    .padding(.bottom, 50)
                
                // Email field
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal)
                
                // Password field
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // Sign In Button
                Button(action: {
                    authManager.signIn(email: email, password: password)
                }) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Google Sign In Button
                Button(action: {
                    authManager.signInWithGoogle()
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .foregroundColor(.red)
                        Text("Sign in with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                // Sign Up Button
                Button(action: {
                    showSignUp = true
                }) {
                    Text("Don't have an account? Sign Up")
                        .foregroundColor(.blue)
                }
                
                if authManager.isLoading {
                    ProgressView()
                }
                
                if let error = authManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding()
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationManager())
} 