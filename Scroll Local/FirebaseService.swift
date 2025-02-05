import Foundation
import Firebase
import FirebaseAuth

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
    
    // Google Sign In will be added here
    // func signInWithGoogle() { }
    
    // Facebook Sign In will be added here
    // func signInWithFacebook() { }
}