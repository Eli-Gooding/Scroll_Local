import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Codable {
    let id: String
    let videoId: String
    let userId: String
    let text: String
    let createdAt: Date
    var likes: Int
    let isReply: Bool
    let parentCommentId: String?
    var replyCount: Int
    
    var user: User?  // For displaying user info in the UI
    var reactions: [Reaction]?  // For displaying reactions
}

struct Reaction: Identifiable, Codable {
    let id: String
    let userId: String
    let emoji: String
    let createdAt: Date
    let commentId: String?
    
    var user: User?  // For displaying who reacted
}
