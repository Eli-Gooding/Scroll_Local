import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@MainActor
class NotificationsViewModel: ObservableObject {
    @Published var notifications: [Notification] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private var listenerRegistration: ListenerRegistration?
    
    struct Notification: Identifiable {
        let id: String
        let senderId: String
        let senderDisplayName: String
        let type: NotificationType
        let videoId: String
        let createdAt: Date
        var isRead: Bool
        let commentText: String?
        
        enum NotificationType: String {
            case save = "save"
            case comment = "comment"
        }
    }
    
    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        listenerRegistration = db.collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = error
                    return
                }
                
                self?.notifications = snapshot?.documents.compactMap { document in
                    guard let data = document.data() as? [String: Any],
                          let senderId = data["senderId"] as? String,
                          let senderDisplayName = data["senderDisplayName"] as? String,
                          let type = data["type"] as? String,
                          let videoId = data["videoId"] as? String,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                          let isRead = data["isRead"] as? Bool else {
                        return nil
                    }
                    
                    return Notification(
                        id: document.documentID,
                        senderId: senderId,
                        senderDisplayName: senderDisplayName,
                        type: Notification.NotificationType(rawValue: type) ?? .save,
                        videoId: videoId,
                        createdAt: createdAt,
                        isRead: isRead,
                        commentText: data["commentText"] as? String
                    )
                } ?? []
            }
    }
    
    func deleteNotification(_ notificationId: String) async {
        do {
            let db = Firestore.firestore()
            try await db.collection("notifications").document(notificationId).delete()
        } catch {
            self.error = error
        }
    }
    
    func stopListening() {
        listenerRegistration?.remove()
    }
} 