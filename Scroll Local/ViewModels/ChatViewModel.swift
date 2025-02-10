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
    
    struct Message: Identifiable, Equatable {
        let id: String
        let senderId: String
        let text: String
        let timestamp: Date
        var isRead: Bool
        
        var isFromCurrentUser: Bool {
            senderId == Auth.auth().currentUser?.uid
        }
        
        static func == (lhs: Message, rhs: Message) -> Bool {
            lhs.id == rhs.id &&
            lhs.senderId == rhs.senderId &&
            lhs.text == rhs.text &&
            lhs.timestamp == rhs.timestamp &&
            lhs.isRead == rhs.isRead
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
        
        // Create local message immediately
        let localMessage = Message(
            id: UUID().uuidString, // Temporary ID
            senderId: currentUserId,
            text: text,
            timestamp: Date(),
            isRead: false
        )
        
        // Update local state immediately
        DispatchQueue.main.async {
            self.messages.append(localMessage)
        }
        
        // Add message to Firebase
        db.collection("messages").addDocument(data: messageData) { [weak self] error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
                // Remove local message if Firebase save failed
                DispatchQueue.main.async {
                    self?.messages.removeAll { $0.id == localMessage.id }
                }
                return
            }
            
            // Update conversation
            let conversationData: [String: Any] = [
                "lastMessageText": text,
                "lastMessageTime": Timestamp(),
                "lastMessageSenderId": currentUserId,
                "unreadCount": FieldValue.increment(Int64(1))
            ]
            
            self?.db.collection("conversations").document(self?.conversationId ?? "").updateData(conversationData)
        }
    }
    
    deinit {
        listenerRegistration?.remove()
    }
} 