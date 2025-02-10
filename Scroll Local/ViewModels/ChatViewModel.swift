import Foundation
import FirebaseFirestore
import FirebaseAuth

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var otherUser: UserProfile?
    private var listenerRegistration: ListenerRegistration?
    private let db = Firestore.firestore()
    private let conversationId: String
    private let otherUserId: String
    
    struct Message: Identifiable {
        let id: String
        let senderId: String
        let text: String
        let timestamp: Date
        var isRead: Bool
        
        var isFromCurrentUser: Bool {
            senderId == Auth.auth().currentUser?.uid
        }
    }
    
    struct UserProfile {
        let id: String
        let displayName: String
        let profileImageUrl: String?
    }
    
    init(conversationId: String, otherUserId: String) {
        self.conversationId = conversationId
        self.otherUserId = otherUserId
        fetchOtherUserProfile()
        startListeningToMessages()
    }
    
    private func fetchOtherUserProfile() {
        Task {
            do {
                let document = try await db.collection("users").document(otherUserId).getDocument()
                if let data = document.data() {
                    DispatchQueue.main.async {
                        self.otherUser = UserProfile(
                            id: self.otherUserId,
                            displayName: data["displayName"] as? String ?? "User",
                            profileImageUrl: data["profileImageUrl"] as? String
                        )
                    }
                }
            } catch {
                print("Error fetching user profile: \(error.localizedDescription)")
            }
        }
    }
    
    func startListeningToMessages() {
        listenerRegistration?.remove()
        
        listenerRegistration = db.collection("messages")
            .whereField("conversationId", isEqualTo: conversationId)
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "")")
                    return
                }
                
                self.messages = documents.compactMap { document in
                    let data = document.data()
                    return Message(
                        id: document.documentID,
                        senderId: data["senderId"] as? String ?? "",
                        text: data["text"] as? String ?? "",
                        timestamp: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                        isRead: data["isRead"] as? Bool ?? false
                    )
                }
                
                // Mark messages as read if they're sent to current user
                self.markMessagesAsRead()
            }
    }
    
    private func markMessagesAsRead() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let batch = db.batch()
        
        for message in messages where !message.isRead && message.senderId != currentUserId {
            let messageRef = db.collection("messages").document(message.id)
            batch.updateData(["isRead": true], forDocument: messageRef)
        }
        
        // Update conversation unread count
        let conversationRef = db.collection("conversations").document(conversationId)
        batch.updateData(["unreadCount": 0], forDocument: conversationRef)
        
        batch.commit()
    }
    
    func sendMessage(_ text: String) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let messageData: [String: Any] = [
            "conversationId": conversationId,
            "senderId": currentUserId,
            "receiverId": otherUserId,
            "text": text,
            "createdAt": Timestamp(),
            "isRead": false
        ]
        
        // Add message
        db.collection("messages").addDocument(data: messageData)
        
        // Update conversation
        let conversationData: [String: Any] = [
            "lastMessageText": text,
            "lastMessageTime": Timestamp(),
            "lastMessageSenderId": currentUserId,
            "unreadCount": FieldValue.increment(Int64(1))
        ]
        
        db.collection("conversations").document(conversationId).updateData(conversationData)
    }
    
    deinit {
        listenerRegistration?.remove()
    }
} 