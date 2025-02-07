import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class OtherUserProfileViewModel: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var userPosts: [Video] = []
    @Published private(set) var isFollowing = false
    @Published private(set) var followerCount = 0
    @Published private(set) var followingCount = 0
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    private var userId: String?
    
    func loadUserProfile(userId: String) async {
        self.userId = userId
        do {
            let doc = try await db.collection("users").document(userId).getDocument()
            if let user = User(document: doc) {
                self.user = user
                self.followerCount = user.followers.count
                self.followingCount = user.following.count
                
                // Check if current user is following this user
                if let currentUserId = Auth.auth().currentUser?.uid {
                    self.isFollowing = user.followers.contains(currentUserId)
                }
            }
        } catch {
            self.error = error
            print("Error loading user profile: \(error)")
        }
    }
    
    func fetchUserPosts(userId: String) async {
        do {
            let snapshot = try await db.collection("videos")
                .whereField("user_id", isEqualTo: userId)
                .order(by: "created_at", descending: true)
                .getDocuments()
            
            userPosts = snapshot.documents.compactMap { doc in
                Video(id: doc.documentID, data: doc.data())
            }
        } catch {
            self.error = error
            print("Error fetching user posts: \(error)")
        }
    }
    
    func followUser() async throws {
        guard let userId = userId,
              let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Add to current user's following
        try await db.collection("users").document(currentUserId).updateData([
            "following": FieldValue.arrayUnion([userId])
        ])
        
        // Add to target user's followers
        try await db.collection("users").document(userId).updateData([
            "followers": FieldValue.arrayUnion([currentUserId])
        ])
        
        isFollowing = true
        followerCount += 1
    }
    
    func unfollowUser() async throws {
        guard let userId = userId,
              let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Remove from current user's following
        try await db.collection("users").document(currentUserId).updateData([
            "following": FieldValue.arrayRemove([userId])
        ])
        
        // Remove from target user's followers
        try await db.collection("users").document(userId).updateData([
            "followers": FieldValue.arrayRemove([currentUserId])
        ])
        
        isFollowing = false
        followerCount -= 1
    }
} 