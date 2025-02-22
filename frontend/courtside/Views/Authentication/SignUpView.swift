import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthenticationManager

    @State private var firstName = ""  // Added First Name Field
    @State private var lastName = ""   // Added Last Name Field
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                
                // Back Button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.white)
                            .font(.title)
                    }
                    Spacer()
                }
                .padding()
                
                Text("Create Account")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
                
                // First Name Field
                TextField("First Name", text: $firstName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .padding(.horizontal)

                // Last Name Field
                TextField("Last Name", text: $lastName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .padding(.horizontal)

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
                
                // Confirm Password Field
                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                // Sign Up Button
                Button(action: {
                    if password == confirmPassword {
                        authManager.signUp(email: email, password: password, firstName: firstName, lastName: lastName) { success in
                            DispatchQueue.main.async {
                                if success {
                                    dismiss()
                                }
                            }
                        }
                    } else {
                        authManager.errorMessage = "Passwords do not match"
                    }
                }) {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
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
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(AuthenticationManager())
    }
}
