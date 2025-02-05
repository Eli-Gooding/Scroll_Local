import Foundation
import Firebase
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift

enum GoogleSignInResult {
    case existingUser
    case newUser
}

class FirebaseService: ObservableObject {
    @Published var authUser: FirebaseAuth.User?
    @Published var isAuthenticated = false
    @Published var authError: Error?
    
    static let shared = FirebaseService()
    private let userService = UserService.shared
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    private init() {
        #if DEBUG
        print("FirebaseService: Initializing...")
        #endif
        
        // Set up auth state listener
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] (_, user) in
            guard let self = self else { return }
            
            if let user = user {
                // Fetch the user document when authenticated
                Task { @MainActor in
                    do {
                        _ = try await self.userService.fetchUser(withId: user.uid)
                    } catch {
                        print("Error fetching user document: \(error)")
                    }
                    
                    self.authUser = user
                    self.isAuthenticated = true
                    
                    #if DEBUG
                    print("FirebaseService: User authenticated - \(user.email ?? "no email")")
                    #endif
                }
            } else {
                Task { @MainActor in
                    self.authUser = nil
                    self.isAuthenticated = false
                    
                    #if DEBUG
                    print("FirebaseService: No user authenticated")
                    #endif
                }
            }
        }
    }
    
    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }
    
    func signIn(email: String, password: String) async throws {
        #if DEBUG
        print("FirebaseService: Attempting sign in with email: \(email)")
        #endif
        
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            
            // Fetch the user document
            _ = try await userService.fetchUser(withId: result.user.uid)
            
            await MainActor.run {
                self.authUser = result.user
                self.isAuthenticated = true
                self.authError = nil
                
                #if DEBUG
                print("FirebaseService: Sign in successful")
                #endif
            }
        } catch {
            await MainActor.run {
                self.authError = error
                
                #if DEBUG
                print("FirebaseService: Sign in failed - \(error.localizedDescription)")
                #endif
            }
            throw error
        }
    }
    
    func signUp(email: String, password: String, username: String? = nil) async throws {
        #if DEBUG
        print("FirebaseService: Attempting sign up with email: \(email)")
        #endif
        
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            // Send email verification
            try await result.user.sendEmailVerification()
            
            // Create the user document in Firestore
            try await userService.createUser(
                withEmail: email,
                uid: result.user.uid,
                displayName: username
            )
            
            await MainActor.run {
                self.authUser = result.user
                self.isAuthenticated = true
                self.authError = nil
                
                #if DEBUG
                print("FirebaseService: Sign up successful")
                #endif
            }
        } catch {
            await MainActor.run {
                self.authError = error
                
                #if DEBUG
                print("FirebaseService: Sign up failed - \(error.localizedDescription)")
                #endif
            }
            throw error
        }
    }
    
    func checkEmailVerification() async throws -> Bool {
        guard let user = Auth.auth().currentUser else {
            return false
        }
        
        try await user.reload()
        return user.isEmailVerified
    }
    
    func resendVerificationEmail() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.sendEmailVerification()
    }
    
    func signOut() throws {
        #if DEBUG
        print("FirebaseService: Attempting sign out")
        #endif
        
        do {
            try Auth.auth().signOut()
            Task { @MainActor in
                self.authUser = nil
                self.isAuthenticated = false
                self.authError = nil
                
                #if DEBUG
                print("FirebaseService: Sign out successful")
                #endif
            }
        } catch {
            Task { @MainActor in
                self.authError = error
                
                #if DEBUG
                print("FirebaseService: Sign out failed - \(error.localizedDescription)")
                #endif
            }
            throw error
        }
    }
    
    #if DEBUG
    // Helper method for testing
    func debugPrintAuthState() {
        if let user = authUser {
            print("Current user: \(user.email ?? "no email")")
            print("User ID: \(user.uid)")
            print("Is authenticated: \(isAuthenticated)")
            if let currentUser = userService.currentUser {
                print("Firestore user data: \(currentUser)")
            }
        } else {
            print("No user authenticated")
            print("Is authenticated: \(isAuthenticated)")
        }
    }
    #endif
    
    func signInWithGoogle() async throws -> GoogleSignInResult {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(
                domain: "FirebaseService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Firebase configuration error: Client ID not found in GoogleService-Info.plist"]
            )
        }
        
        #if DEBUG
        print("FirebaseService: Attempting Google Sign In with client ID: \(clientID)")
        #endif
        
        // Get Google Sign In configuration object
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Get the root view controller from the main actor
        let rootViewController: UIViewController? = await MainActor.run {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return nil
            }
            return rootViewController
        }
        
        guard let rootViewController = rootViewController else {
            throw NSError(
                domain: "FirebaseService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No root view controller found. Please ensure the app is properly initialized."]
            )
        }
        
        do {
            // Start Google Sign In flow
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(
                    domain: "FirebaseService",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to get ID token from Google Sign In"]
                )
            }
            
            #if DEBUG
            print("FirebaseService: Successfully got Google Sign In token")
            #endif
            
            // Create Firebase credential
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            // Try to sign in with Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            
            // Get display name from Google profile
            let displayName: String? = result.user.profile?.givenName
            
            #if DEBUG
            print("FirebaseService: Successfully signed in with Google, checking if user exists...")
            #endif
            
            // Check if this is a new user by trying to fetch their document
            let isNewUser = try await userService.fetchUser(withId: authResult.user.uid) == nil
            
            if isNewUser {
                #if DEBUG
                print("FirebaseService: Creating new user document for Google Sign In user")
                #endif
                
                // Create new user document
                try await userService.createUser(
                    withEmail: authResult.user.email ?? "",
                    uid: authResult.user.uid,
                    displayName: displayName
                )
            }
            
            await MainActor.run {
                self.authUser = authResult.user
                self.isAuthenticated = true
                self.authError = nil
            }
            
            return isNewUser ? .newUser : .existingUser
        } catch {
            #if DEBUG
            print("FirebaseService: Google Sign In failed with error: \(error.localizedDescription)")
            #endif
            throw error
        }
    }
    
    // Facebook Sign In will be added here
    // func signInWithFacebook() { }
}