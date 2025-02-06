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
    
    // Computed property to group reactions by emoji
    var groupedReactions: [(emoji: String, count: Int, userIds: [String])] {
        guard let reactions = reactions else { return [] }
        
        // Group reactions by emoji
        let grouped = Dictionary(grouping: reactions) { $0.emoji }
        
        // Convert to array and sort by count
        return grouped.map { emoji, reactions in
            (emoji: emoji,
             count: reactions.count,
             userIds: reactions.map { $0.userId })
        }.sorted { $0.count > $1.count }
    }
}

struct Reaction: Identifiable, Codable {
    let id: String
    let userId: String
    let emoji: String
    let createdAt: Date
    let commentId: String?
    
    var user: User?  // For displaying who reacted
}
