import Foundation
import FirebaseFirestore

// Make the Video model public so it can be accessed from other files
public struct Video: Identifiable {
    public var id: String?
    public let userId: String
    public let title: String
    public let description: String
    public let location: String
    public let tags: [String]
    public let category: String
    public let videoUrl: String
    public let createdAt: Date
    public var views: Int
    public var helpfulCount: Int
    public var notHelpfulCount: Int
    public var saveCount: Int
    public var commentCount: Int
    
    public init?(id: String, data: [String: Any]) {
        self.id = id
        guard let userId = data["user_id"] as? String,
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let location = data["location"] as? String,
              let tags = data["tags"] as? [String],
              let category = data["category"] as? String,
              let videoUrl = data["video_url"] as? String,
              let createdAt = (data["created_at"] as? Timestamp)?.dateValue(),
              let views = data["views"] as? Int,
              let helpfulCount = data["helpful_count"] as? Int,
              let notHelpfulCount = data["not_helpful_count"] as? Int,
              let saveCount = data["save_count"] as? Int,
              let commentCount = data["comment_count"] as? Int else {
            return nil
        }
        
        self.userId = userId
        self.title = title
        self.description = description
        self.location = location
        self.tags = tags
        self.category = category
        self.videoUrl = videoUrl
        self.createdAt = createdAt
        self.views = views
        self.helpfulCount = helpfulCount
        self.notHelpfulCount = notHelpfulCount
        self.saveCount = saveCount
        self.commentCount = commentCount
    }
} 