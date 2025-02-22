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
                Text("Courtside AI 🏀")
                    .font(.system(size: 35, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                // Image Section with Overlapping Effect
                ZStack {
                    // Shai (Left)
                    Image("shai")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .offset(x: -60) // Move left
                    
                    // Curry (Right)
                    Image("curry")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .offset(x: 60) // Move right
                    
                    // LeBron (Middle - on top)
                    Image("lebron (1)")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .zIndex(1) // Ensure LeBron is on top
                }
                .padding(.bottom, 10)

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
