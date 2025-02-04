import SwiftUI
import Firebase
import FirebaseAuth

#if DEBUG
class PreviewFirebaseService: ObservableObject {
    static let shared = PreviewFirebaseService()
    
    @Published var isAuthenticated: Bool
    @Published var user: User?
    @Published var authError: Error?
    
    private init(isAuthenticated: Bool = false) {
        self.isAuthenticated = isAuthenticated
        print("[Preview] Initialized with isAuthenticated: \(isAuthenticated)")
    }
    
    func signIn(email: String, password: String) async throws {
        isAuthenticated = true
        print("[Preview] Signed in with email: \(email)")
    }
    
    func signUp(email: String, password: String) async throws {
        isAuthenticated = true
        print("[Preview] Signed up with email: \(email)")
    }
    
    func signOut() throws {
        isAuthenticated = false
        print("[Preview] Signed out")
    }
    
    func debugPrintAuthState() {
        print("[Preview] Auth State - isAuthenticated: \(isAuthenticated)")
    }
}

struct PreviewContextKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isPreview: Bool {
        get { self[PreviewContextKey.self] }
        set { self[PreviewContextKey.self] = newValue }
    }
}

struct PreviewFirebaseModifier: ViewModifier {
    init(isAuthenticated: Bool) {
        PreviewFirebaseService.shared.isAuthenticated = isAuthenticated
    }
    
    func body(content: Content) -> some View {
        content.environment(\.isPreview, true)
    }
}

extension View {
    func withPreviewFirebase(isAuthenticated: Bool = false) -> some View {
        self.modifier(PreviewFirebaseModifier(isAuthenticated: isAuthenticated))
    }
}
#endif 