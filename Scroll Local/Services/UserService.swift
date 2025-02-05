import Firebase
import FirebaseFirestore
import FirebaseAuth

class UserService: ObservableObject {
    static let shared = UserService()
    private let db = Firestore.firestore()
    
    @Published var currentUser: User?
    
    private init() {}
    
    func createUser(withEmail email: String, uid: String, displayName: String? = nil) async throws {
        let user = User(
            id: uid,
            email: email,
            displayName: displayName,
            createdAt: Date(),
            location: nil,
            following: [],
            followers: []
        )
        
        try await db.collection("users").document(uid).setData(user.toDictionary())
        self.currentUser = user
        
        #if DEBUG
        print("UserService: Created new user with ID: \(uid)")
        #endif
    }
    
    func fetchUser(withId uid: String) async throws -> User {
        let docSnapshot = try await db.collection("users").document(uid).getDocument()
        
        guard let user = User(document: docSnapshot) else {
            throw NSError(domain: "UserService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode user"])
        }
        
        if uid == Auth.auth().currentUser?.uid {
            self.currentUser = user
        }
        
        return user
    }
    
    func updateUserLocation(latitude: Double, longitude: Double) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let location = GeoPoint(latitude: latitude, longitude: longitude)
        try await db.collection("users").document(uid).updateData([
            "location": location
        ])
        
        currentUser?.location = location
    }
    
    func followUser(_ userIdToFollow: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // Add to current user's following
        try await db.collection("users").document(currentUid).updateData([
            "following": FieldValue.arrayUnion([userIdToFollow])
        ])
        
        // Add to target user's followers
        try await db.collection("users").document(userIdToFollow).updateData([
            "followers": FieldValue.arrayUnion([currentUid])
        ])
        
        // Update local state
        if currentUser?.following.contains(userIdToFollow) == false {
            currentUser?.following.append(userIdToFollow)
        }
    }
    
    func unfollowUser(_ userIdToUnfollow: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else { return }
        
        // Remove from current user's following
        try await db.collection("users").document(currentUid).updateData([
            "following": FieldValue.arrayRemove([userIdToUnfollow])
        ])
        
        // Remove from target user's followers
        try await db.collection("users").document(userIdToUnfollow).updateData([
            "followers": FieldValue.arrayRemove([currentUid])
        ])
        
        // Update local state
        currentUser?.following.removeAll(where: { $0 == userIdToUnfollow })
    }
    
    func updateDisplayName(_ newName: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        try await db.collection("users").document(uid).updateData([
            "displayName": newName
        ])
        
        currentUser?.displayName = newName
    }
} 