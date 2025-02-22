import SwiftUI

struct AuthenticationView: View {
    @State private var showSignUp = false
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                
                // App Title
                Text("Courtside AI")
                    .font(.system(size: 40, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.bottom, 20)
                
                // Email Field
                TextField("Email", text: $email)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                // Password Field
                SecureField("Password", text: $password)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                // Sign In Button
                Button(action: {
                    authManager.signIn(email: email, password: password) { success in
                        if success {
                            print("✅ Sign-in successful")
                        }
                    }
                }) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Sign Up Button
                Button(action: {
                    showSignUp = true
                }) {
                    Text("Sign Up")
                        .foregroundColor(.white)
                        .underline()
                }
                .padding(.top, 10)
                
                if authManager.isLoading {
                    ProgressView()
                        .foregroundColor(.white)
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

struct AuthenticationView_Previews: PreviewProvider {
    static var previews: some View {
        AuthenticationView()
            .environmentObject(AuthenticationManager())
    }
}
