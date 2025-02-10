import Foundation
import FirebaseFirestore
import FirebaseAuth

class MessagesViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    private var listenerRegistration: ListenerRegistration?
    private let db = Firestore.firestore()
    
    struct Conversation: Identifiable {
        let id: String
        let otherUserId: String
        let otherUserName: String
        let otherUserProfileUrl: String?
        let lastMessage: String
        let lastMessageTime: Date
        let unreadCount: Int
    }
    
    init() {
        startListeningToConversations()
    }
    
    func startListeningToConversations() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        listenerRegistration?.remove()
        
        listenerRegistration = db.collection("conversations")
            .whereField("participants", arrayContains: currentUserId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    print("Error fetching conversations: \(error?.localizedDescription ?? "")")
                    return
                }
                
                Task {
                    var newConversations: [Conversation] = []
                    
                    for document in documents {
                        let data = document.data()
                        let participants = data["participants"] as? [String] ?? []
                        let otherUserId = participants.first { $0 != currentUserId } ?? ""
                        
                        // Fetch other user's details
                        if let userDoc = try? await self.db.collection("users").document(otherUserId).getDocument(),
                           let userData = userDoc.data() {
                            let conversation = Conversation(
                                id: document.documentID,
                                otherUserId: otherUserId,
                                otherUserName: userData["displayName"] as? String ?? "User",
                                otherUserProfileUrl: userData["profileImageUrl"] as? String,
                                lastMessage: data["lastMessageText"] as? String ?? "",
                                lastMessageTime: (data["lastMessageTime"] as? Timestamp)?.dateValue() ?? Date(),
                                unreadCount: data["unreadCount"] as? Int ?? 0
                            )
                            newConversations.append(conversation)
                        }
                    }
                    
                    DispatchQueue.main.async {
                        self.conversations = newConversations.sorted { $0.lastMessageTime > $1.lastMessageTime }
                    }
                }
            }
    }
    
    func searchUsers(query: String) async -> [UserSearchResult] {
        guard !query.isEmpty else { return [] }
        
        do {
            let snapshot = try await db.collection("users")
                .whereField("displayName", isGreaterThanOrEqualTo: query)
                .whereField("displayName", isLessThanOrEqualTo: query + "\u{f8ff}")
                .getDocuments()
            
            return snapshot.documents.compactMap { document -> UserSearchResult? in
                let data = document.data()
                return UserSearchResult(
                    id: document.documentID,
                    displayName: data["displayName"] as? String ?? "",
                    profileImageUrl: data["profileImageUrl"] as? String
                )
            }
        } catch {
            print("Error searching users: \(error.localizedDescription)")
            return []
        }
    }
    
    struct UserSearchResult: Identifiable {
        let id: String
        let displayName: String
        let profileImageUrl: String?
    }
    
    func createOrGetConversation(with otherUserId: String) async -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return "" }
        
        // Check if conversation already exists
        let snapshot = try? await db.collection("conversations")
            .whereField("participants", arrayContains: currentUserId)
            .getDocuments()
        
        if let existingConversation = snapshot?.documents.first(where: { document in
            let participants = document.data()["participants"] as? [String] ?? []
            return participants.contains(otherUserId)
        }) {
            return existingConversation.documentID
        }
        
        // Create new conversation
        let conversationRef = db.collection("conversations").document()
        
        let conversationData: [String: Any] = [
            "participants": [currentUserId, otherUserId],
            "lastMessageText": "",
            "lastMessageTime": Timestamp(),
            "lastMessageSenderId": "",
            "unreadCount": 0
        ]
        
        try? await conversationRef.setData(conversationData)
        return conversationRef.documentID
    }
    
    deinit {
        listenerRegistration?.remove()
    }
} 