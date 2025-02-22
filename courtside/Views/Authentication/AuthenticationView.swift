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
                
                // Smiley Faces (Placeholder)
                HStack(spacing: -20) { // Negative spacing for slight overlap
                    Image("curry")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .offset(y: 10) // Push Curry slightly down

                    ZStack {
                        Image("lebron (1)")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .zIndex(1) // Bring to front
                    }

                    Image("shai")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 110, height: 110)
                        .offset(y: 10) // Push Shai slightly down
                }
                
                // Tagline
                Text("\"Play Like The Pros\"")
                    .font(.title3)
                    .italic()
                    .foregroundColor(.white)
                
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
                    authManager.signIn(email: email, password: password)
                }) {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Google Sign In Button
                Button(action: {
                    authManager.signInWithGoogle()
                }) {
                    HStack {
                        Image("google")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 30, height: 30)
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
