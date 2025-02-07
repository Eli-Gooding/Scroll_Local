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
    @Published private(set) var isProcessing = false
    
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
    
    func followUser() async {
        guard let userId = userId,
              let currentUserId = Auth.auth().currentUser?.uid,
              !isProcessing else { return }
        
        isProcessing = true
        
        do {
            let batch = db.batch()
            
            // Add to current user's following
            let currentUserRef = db.collection("users").document(currentUserId)
            batch.updateData([
                "following": FieldValue.arrayUnion([userId])
            ], forDocument: currentUserRef)
            
            // Add to target user's followers
            let targetUserRef = db.collection("users").document(userId)
            batch.updateData([
                "followers": FieldValue.arrayUnion([currentUserId])
            ], forDocument: targetUserRef)
            
            // Commit the batch
            try await batch.commit()
            
            // Refresh the profile to get updated counts
            if let userId = self.userId {
                await loadUserProfile(userId: userId)
            }
        } catch {
            self.error = error
            print("Error following user: \(error)")
        }
        
        isProcessing = false
    }
    
    func unfollowUser() async {
        guard let userId = userId,
              let currentUserId = Auth.auth().currentUser?.uid,
              !isProcessing else { return }
        
        isProcessing = true
        
        do {
            let batch = db.batch()
            
            // Remove from current user's following
            let currentUserRef = db.collection("users").document(currentUserId)
            batch.updateData([
                "following": FieldValue.arrayRemove([userId])
            ], forDocument: currentUserRef)
            
            // Remove from target user's followers
            let targetUserRef = db.collection("users").document(userId)
            batch.updateData([
                "followers": FieldValue.arrayRemove([currentUserId])
            ], forDocument: targetUserRef)
            
            // Commit the batch
            try await batch.commit()
            
            // Refresh the profile to get updated counts
            if let userId = self.userId {
                await loadUserProfile(userId: userId)
            }
        } catch {
            self.error = error
            print("Error unfollowing user: \(error)")
        }
        
        isProcessing = false
    }
} 