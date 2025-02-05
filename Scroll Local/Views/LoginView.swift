import SwiftUI
import Firebase
import FirebaseAuth

struct LoginView: View {
    @StateObject private var firebaseService = FirebaseService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var isSignUp = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showVerificationAlert = false
    @State private var showResendVerification = false
    
    // Validation states
    private var isEmailValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    private var isPasswordValid: Bool {
        password.count >= 6
    }
    
    private var isUsernameValid: Bool {
        username.count >= 3 && username.count <= 30 && !username.contains(" ")
    }
    
    private var isFormValid: Bool {
        isEmailValid && isPasswordValid && !isLoading && (!isSignUp || isUsernameValid)
    }
    
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
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .disabled(isLoading)
                    
                    if !email.isEmpty && !isEmailValid {
                        Text("Please enter a valid email")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                // Username Field (only shown during sign up)
                if isSignUp {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disabled(isLoading)
                        
                        if !username.isEmpty && !isUsernameValid {
                            Text("Username must be 3-30 characters with no spaces")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isLoading)
                    
                    if !password.isEmpty && !isPasswordValid {
                        Text("Password must be at least 6 characters")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)
                
                // Sign In/Up Button
                Button(action: {
                    Task {
                        isLoading = true
                        do {
                            if isSignUp {
                                try await firebaseService.signUp(email: email, password: password, username: username)
                                showVerificationAlert = true
                            } else {
                                try await firebaseService.signIn(email: email, password: password)
                                // Check email verification status on sign in
                                if let isVerified = try? await firebaseService.checkEmailVerification(),
                                   !isVerified {
                                    showResendVerification = true
                                }
                            }
                        } catch {
                            showError = true
                            errorMessage = handleAuthError(error)
                        }
                        isLoading = false
                    }
                }) {
                    ZStack {
                        Text(isSignUp ? "Sign Up" : "Sign In")
                            .foregroundColor(.white)
                            .opacity(isLoading ? 0 : 1)
                        
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.accentColor : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(!isFormValid || isLoading)
                .padding(.horizontal)
                
                // Toggle between Sign In/Up
                Button(action: {
                    isSignUp.toggle()
                    // Clear username when switching modes
                    if !isSignUp {
                        username = ""
                    }
                }) {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .foregroundColor(Color.accentColor)
                }
                .disabled(isLoading)
                
                // Social Sign In Button
                Button(action: {
                    Task {
                        isLoading = true
                        do {
                            if isSignUp {
                                // For sign up, we need to check if the email exists first
                                let result = try await firebaseService.signInWithGoogle()
                                if result == .newUser {
                                    showVerificationAlert = true
                                }
                            } else {
                                // For sign in, just attempt to sign in
                                _ = try await firebaseService.signInWithGoogle()
                            }
                        } catch {
                            showError = true
                            errorMessage = "Google Sign In failed: \(error.localizedDescription)"
                        }
                        isLoading = false
                    }
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        Text(isSignUp ? "Sign up with Google" : "Continue with Google")
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
                .disabled(isLoading)
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
                        if isSignUp {
                            username = "testuser"
                        }
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
            .alert("Verify Your Email", isPresented: $showVerificationAlert) {
                Button("OK", role: .cancel) { }
                Button("Resend Email") {
                    Task {
                        do {
                            try await firebaseService.resendVerificationEmail()
                        } catch {
                            showError = true
                            errorMessage = "Failed to resend verification email"
                        }
                    }
                }
            } message: {
                Text("Please check your email to verify your account. You need to verify your email before you can use all features.")
            }
            .alert("Email Not Verified", isPresented: $showResendVerification) {
                Button("OK", role: .cancel) { }
                Button("Resend Email") {
                    Task {
                        do {
                            try await firebaseService.resendVerificationEmail()
                        } catch {
                            showError = true
                            errorMessage = "Failed to resend verification email"
                        }
                    }
                }
            } message: {
                Text("Your email is not verified. Please check your email for the verification link or request a new one.")
            }
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
    
    private func handleAuthError(_ error: Error) -> String {
        guard let errorCode = AuthErrorCode(_bridgedNSError: error as NSError) else {
            return error.localizedDescription
        }
        
        switch errorCode {
        case .invalidEmail:
            return "The email address is badly formatted."
        case .emailAlreadyInUse:
            return "The email address is already in use by another account."
        case .weakPassword:
            return "The password must be at least 6 characters long."
        case .wrongPassword:
            return "The password is invalid."
        case .userNotFound:
            return "There is no user record corresponding to this email."
        case .networkError:
            return "Network error. Please check your internet connection."
        case .unverifiedEmail:
            return "Please verify your email address before signing in."
        default:
            return "An error occurred. Please try again."
        }
    }
}

#Preview {
    LoginView()
        .withPreviewFirebase(isAuthenticated: false)
} 
