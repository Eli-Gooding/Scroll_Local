import Foundation
import FirebaseFirestore

// Make the Video model public so it can be accessed from other files
public struct Video: Identifiable, Equatable {
    public var id: String?
    public let userId: String
    public var userDisplayName: String?
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
    
    public var firestoreData: [String: Any] {
        return [
            "user_id": userId,
            "user_display_name": userDisplayName as Any,
            "title": title,
            "description": description,
            "location": location,
            "tags": tags,
            "category": category,
            "video_url": videoUrl,
            "created_at": Timestamp(date: createdAt),
            "views": views,
            "helpful_count": helpfulCount,
            "not_helpful_count": notHelpfulCount,
            "save_count": saveCount,
            "comment_count": commentCount
        ]
    }
    
    public init(userId: String, title: String, description: String, location: String,
         tags: [String], category: String, videoUrl: String, createdAt: Date,
         views: Int, helpfulCount: Int, notHelpfulCount: Int, saveCount: Int, commentCount: Int,
         userDisplayName: String? = nil) {
        self.userId = userId
        self.userDisplayName = userDisplayName
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
        self.userDisplayName = data["user_display_name"] as? String
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