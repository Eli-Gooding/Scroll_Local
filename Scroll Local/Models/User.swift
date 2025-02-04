import FirebaseFirestore
import CoreLocation

struct User: Identifiable, Codable {
    var id: String?
    let email: String
    var displayName: String?
    var createdAt: Date
    var location: GeoPoint?
    var following: [String]
    var followers: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName
        case createdAt
        case location
        case following
        case followers
    }
    
    init(id: String? = nil,
         email: String,
         displayName: String? = nil,
         createdAt: Date = Date(),
         location: GeoPoint? = nil,
         following: [String] = [],
         followers: [String] = []) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.location = location
        self.following = following
        self.followers = followers
    }
    
    // Add Firestore conversion methods
    init?(document: DocumentSnapshot) {
        guard let data = document.data() else { return nil }
        
        self.id = document.documentID
        self.email = data["email"] as? String ?? ""
        self.displayName = data["displayName"] as? String
        self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        self.location = data["location"] as? GeoPoint
        self.following = data["following"] as? [String] ?? []
        self.followers = data["followers"] as? [String] ?? []
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "email": email,
            "displayName": displayName as Any,
            "createdAt": Timestamp(date: createdAt),
            "location": location as Any,
            "following": following,
            "followers": followers
        ]
    }
} 