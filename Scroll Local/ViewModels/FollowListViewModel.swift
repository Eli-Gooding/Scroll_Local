import Foundation
import FirebaseFirestore

@MainActor
class FollowListViewModel: ObservableObject {
    @Published private(set) var users: [User] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let db = Firestore.firestore()
    
    func fetchUsers(for userId: String, listType: FollowListView.ListType) async {
        isLoading = true
        error = nil
        
        do {
            // First get the user document to get the list of follower/following IDs
            let userDoc = try await db.collection("users").document(userId).getDocument()
            guard let userData = userDoc.data() else { return }
            
            // Get the appropriate list of user IDs based on the list type
            let userIds: [String]
            switch listType {
            case .followers:
                userIds = userData["followers"] as? [String] ?? []
            case .following:
                userIds = userData["following"] as? [String] ?? []
            }
            
            // If there are no users, return empty array
            if userIds.isEmpty {
                users = []
                isLoading = false
                return
            }
            
            // Fetch user documents in chunks of 10 (Firestore limit for 'in' queries)
            let chunkedIds = stride(from: 0, to: userIds.count, by: 10).map {
                Array(userIds[$0..<min($0 + 10, userIds.count)])
            }
            
            var fetchedUsers: [User] = []
            for chunk in chunkedIds {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                
                let chunkUsers = snapshot.documents.compactMap { doc in
                    User(document: doc)
                }
                fetchedUsers.append(contentsOf: chunkUsers)
            }
            
            // Sort users by display name
            users = fetchedUsers.sorted { ($0.displayName ?? "") < ($1.displayName ?? "") }
            
        } catch {
            self.error = error
            print("Error fetching users: \(error)")
        }
        
        isLoading = false
    }
} 