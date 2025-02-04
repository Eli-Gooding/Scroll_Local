import SwiftUI
import Firebase

struct LoginView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Logo
                Image("Scroll_Local_Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.top, 40)
                
                Text(isSignUp ? "Create an account" : "Welcome back!")
                    .font(.title2)
                    .padding(.bottom, 20)
                
                // Email Field
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal)
                
                // Password Field
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                // Sign In/Up Button
                Button(action: {
                    Task {
                        do {
                            if isSignUp {
                                try await firebaseService.signUp(email: email, password: password)
                            } else {
                                try await firebaseService.signIn(email: email, password: password)
                            }
                        } catch {
                            showError = true
                            errorMessage = error.localizedDescription
                        }
                    }
                }) {
                    Text(isSignUp ? "Sign Up" : "Sign In")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Toggle between Sign In/Up
                Button(action: {
                    isSignUp.toggle()
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(Color.accentColor)
                }
                
                // Social Sign In Button
                Button(action: {
                    // Google sign in
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        Text("Continue with Google")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                .padding(.top)
                
                Spacer()
                
                #if DEBUG
                // Debug Section
                VStack(spacing: 10) {
                    Text("Debug Controls")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        email = "test@example.com"
                        password = "password123"
                    }) {
                        Text("Fill Test Credentials")
                            .font(.caption)
                    }
                    
                    Button(action: {
                        firebaseService.debugPrintAuthState()
                    }) {
                        Text("Print Auth State")
                            .font(.caption)
                    }
                }
                .padding(.bottom)
                #endif
            }
            .padding()
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                #if DEBUG
                firebaseService.debugPrintAuthState()
                #endif
            }
        }
    }
}

#Preview {
    LoginView()
        .withPreviewFirebase(isAuthenticated: false)
} 
