import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ProfileViewModel: ObservableObject {
    @Published private(set) var userPosts: [Video] = []
    @Published private(set) var savedVideos: [Video] = []
    @Published private(set) var followerCount: Int = 0
    @Published private(set) var followingCount: Int = 0
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    
    func fetchUserPosts() async {
        isLoading = true
        error = nil
        
        do {
            guard let userId = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            }
            
            let snapshot = try await db.collection("videos")
                .whereField("user_id", isEqualTo: userId)
                .order(by: "created_at", descending: true)
                .getDocuments()
            
            userPosts = snapshot.documents.compactMap { doc in
                Video(id: doc.documentID, data: doc.data())
            }
            
            // Update follower and following counts
            await updateFollowCounts()
        } catch {
            self.error = error
            print("Error fetching user posts: \(error)")
        }
        
        isLoading = false
    }
    
    private func updateFollowCounts() async {
        do {
            guard let userId = Auth.auth().currentUser?.uid else { return }
            
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let userData = userDoc.data() else { return }
            
            let followers = userData["followers"] as? [String] ?? []
            let following = userData["following"] as? [String] ?? []
            
            await MainActor.run {
                self.followerCount = followers.count
                self.followingCount = following.count
            }
        } catch {
            print("Error updating follow counts: \(error)")
        }
    }
    
    func fetchSavedVideos() async {
        isLoading = true
        error = nil
        
        do {
            guard let userId = Auth.auth().currentUser?.uid else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
            }
            
            // First get all saved video IDs
            let savesSnapshot = try await db.collection("videoSaves")
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            let videoIds = savesSnapshot.documents.compactMap { doc -> String? in
                VideoSave(id: doc.documentID, data: doc.data())?.videoId
            }
            
            // Then fetch the actual videos
            if !videoIds.isEmpty {
                let chunkedIds = stride(from: 0, to: videoIds.count, by: 10).map {
                    Array(videoIds[$0..<min($0 + 10, videoIds.count)])
                }
                
                var videos: [Video] = []
                for chunk in chunkedIds {
                    let snapshot = try await db.collection("videos")
                        .whereField(FieldPath.documentID(), in: chunk)
                        .getDocuments()
                    
                    let chunkVideos = snapshot.documents.compactMap { doc in
                        Video(id: doc.documentID, data: doc.data())
                    }
                    videos.append(contentsOf: chunkVideos)
                }
                
                savedVideos = videos
            } else {
                savedVideos = []
            }
        } catch {
            self.error = error
            print("Error fetching saved videos: \(error)")
        }
        
        isLoading = false
    }
} 