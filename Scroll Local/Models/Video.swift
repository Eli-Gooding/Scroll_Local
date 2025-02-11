import Foundation
import FirebaseFirestore
import CoreLocation

// Make the Video model public so it can be accessed from other files
public struct Video: Identifiable, Equatable, Codable, Hashable {
    public var id: String?
    public let userId: String
    public var userDisplayName: String?
    public let title: String
    public let description: String
    public let location: GeoPoint  // Store as GeoPoint
    public let formattedLocation: String  // Store formatted location
    public let tags: [String]
    public let category: String
    public let videoUrl: String
    public let thumbnailUrl: String?
    public let createdAt: Date
    public var views: Int
    public var helpfulCount: Int
    public var notHelpfulCount: Int
    public var saveCount: Int
    public var commentCount: Int
    
    // Add coding keys but keep them internal
    internal enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case userDisplayName = "user_display_name"
        case title
        case description
        case location
        case formattedLocation = "formatted_location"
        case tags
        case category
        case videoUrl = "video_url"
        case thumbnailUrl = "thumbnail_url"
        case createdAt = "created_at"
        case views
        case helpfulCount = "helpful_count"
        case notHelpfulCount = "not_helpful_count"
        case saveCount = "save_count"
        case commentCount = "comment_count"
    }
    
    // Custom decoder to handle GeoPoint
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        userDisplayName = try container.decodeIfPresent(String.self, forKey: .userDisplayName)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        formattedLocation = try container.decode(String.self, forKey: .formattedLocation)
        tags = try container.decode([String].self, forKey: .tags)
        category = try container.decode(String.self, forKey: .category)
        videoUrl = try container.decode(String.self, forKey: .videoUrl)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        
        // Decode GeoPoint directly from Firestore
        location = try container.decode(GeoPoint.self, forKey: .location)
        
        // Handle Timestamp decoding
        if let timestamp = try container.decodeIfPresent(Timestamp.self, forKey: .createdAt) {
            createdAt = timestamp.dateValue()
        } else {
            createdAt = Date()
        }
        
        views = try container.decode(Int.self, forKey: .views)
        helpfulCount = try container.decode(Int.self, forKey: .helpfulCount)
        notHelpfulCount = try container.decode(Int.self, forKey: .notHelpfulCount)
        saveCount = try container.decode(Int.self, forKey: .saveCount)
        commentCount = try container.decode(Int.self, forKey: .commentCount)
    }
    
    // Add computed properties for search
    var searchableTitle: [String] {
        // Include both individual words and full title
        var terms = title.lowercased().split(separator: " ").map(String.init)
        terms.append(title.lowercased()) // Add full title as a searchable term
        return terms
    }
    
    var searchableLocation: [String] {
        // Include both individual words and full location
        var terms = formattedLocation.lowercased().split(separator: " ").map(String.init)
        terms.append(formattedLocation.lowercased()) // Add full location as a searchable term
        return terms
    }
    
    // Update firestoreData to include searchable fields
    public var firestoreData: [String: Any] {
        var data = [
            "user_id": userId,
            "user_display_name": userDisplayName as Any,
            "title": title,
            "searchableTitle": searchableTitle,
            "description": description,
            "location": location,
            "formatted_location": formattedLocation,
            "searchableLocation": searchableLocation,
            "tags": tags,
            "category": category,
            "video_url": videoUrl,
            "thumbnail_url": thumbnailUrl as Any,
            "created_at": Timestamp(date: createdAt),
            "views": views,
            "helpful_count": helpfulCount,
            "not_helpful_count": notHelpfulCount,
            "save_count": saveCount,
            "comment_count": commentCount
        ]
        return data
    }
    
    public init(userId: String, title: String, description: String, location: GeoPoint,
         formattedLocation: String, tags: [String], category: String, videoUrl: String, createdAt: Date,
         views: Int, helpfulCount: Int, notHelpfulCount: Int, saveCount: Int, commentCount: Int,
         userDisplayName: String? = nil, thumbnailUrl: String? = nil) {
        self.userId = userId
        self.userDisplayName = userDisplayName
        self.title = title
        self.description = description
        self.location = location
        self.formattedLocation = formattedLocation
        self.tags = tags
        self.category = category
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
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
              let location = data["location"] as? GeoPoint,
              let formattedLocation = data["formatted_location"] as? String,
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
        self.formattedLocation = formattedLocation
        self.tags = tags
        self.category = category
        self.videoUrl = videoUrl
        self.thumbnailUrl = data["thumbnail_url"] as? String
        self.createdAt = createdAt
        self.views = views
        self.helpfulCount = helpfulCount
        self.notHelpfulCount = notHelpfulCount
        self.saveCount = saveCount
        self.commentCount = commentCount
    }
    
    public static func == (lhs: Video, rhs: Video) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Add Codable conformance without modifying existing behavior
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encodeIfPresent(userDisplayName, forKey: .userDisplayName)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(location, forKey: .location)
        try container.encode(formattedLocation, forKey: .formattedLocation)
        try container.encode(tags, forKey: .tags)
        try container.encode(category, forKey: .category)
        try container.encode(videoUrl, forKey: .videoUrl)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
        try container.encode(Timestamp(date: createdAt), forKey: .createdAt)
        try container.encode(views, forKey: .views)
        try container.encode(helpfulCount, forKey: .helpfulCount)
        try container.encode(notHelpfulCount, forKey: .notHelpfulCount)
        try container.encode(saveCount, forKey: .saveCount)
        try container.encode(commentCount, forKey: .commentCount)
    }
    
    // Add hash function
    public func hash(into hasher: inout Hasher) {
        // Use id for hashing since that's what we use for equality
        hasher.combine(id)
    }
} 