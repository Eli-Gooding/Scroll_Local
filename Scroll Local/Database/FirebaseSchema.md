# Scroll Local Firebase Schema

## Collections

### Users Collection
```swift
struct User {
    let id: String              // User's UID from Firebase Auth
    let email: String
    var displayName: String?
    var bio: String?           // User's bio/description
    var profileImageUrl: String? // URL to user's profile image in Storage
    let createdAt: Date
    var location: GeoPoint?
    var following: [String]     // Array of user IDs
    var followers: [String]     // Array of user IDs
}
```

### Conversations Collection
```swift
struct Conversation {
    let id: String
    let participants: [String]    // Array of user IDs (always size 2)
    let lastMessageText: String   // Preview of the last message
    let lastMessageTime: Date     // Timestamp of the last message
    let lastMessageSenderId: String // Who sent the last message
    var unreadCount: Int         // Number of unread messages for receiver
}
```

### Videos Collection
```swift
struct Video {
    let id: String
    let userId: String          // Reference to users collection
    let userDisplayName: String? // Display name of the user who posted the video
    let title: String
    var description: String
    let videoUrl: String        // URL to video in Storage
    let thumbnailUrl: String?   // URL to thumbnail in Storage
    let location: GeoPoint      // Geographic coordinates
    let formattedLocation: String // Human-readable location (e.g., "San Francisco, CA, USA")
    let createdAt: Date
    var views: Int
    var saveCount: Int         // Total number of saves
    var helpfulCount: Int      // Total number of helpful ratings
    var notHelpfulCount: Int   // Total number of not helpful ratings
    var commentCount: Int      // Total number of comments
    var tags: [String]        // Array of hashtags
    var category: String      // Video category
}
```

### VideoSaves Collection
```swift
struct VideoSave {
    let id: String
    let userId: String          // Reference to users collection
    let videoId: String         // Reference to videos collection
    let createdAt: Date
}
```

### VideoRatings Collection
```swift
struct VideoRating {
    let id: String
    let userId: String          // Reference to users collection
    let videoId: String         // Reference to videos collection
    let isHelpful: Bool        // true for helpful, false for not helpful
    let createdAt: Date
    let updatedAt: Date
}
```

### Comments Collection
```swift
struct Comment {
    let id: String
    let videoId: String         // Reference to videos collection
    let userId: String          // Reference to users collection
    let text: String
    let createdAt: Date
    var likes: Int
    let isReply: Bool          // true if this is a reply to another comment
    let parentCommentId: String? // only set if isReply is true
    var replyCount: Int        // count of replies to this comment (0 for replies)
}
```

### Messages Collection
```swift
struct Message {
    let id: String
    let conversationId: String   // Reference to conversations collection
    let senderId: String        // Reference to users collection
    let receiverId: String      // Reference to users collection
    let text: String
    let createdAt: Date
    var isRead: Bool
}
```

### Reactions Collection
```swift
struct Reaction {
    let id: String
    let userId: String         // Who added the reaction
    let emoji: String         // The emoji character
    let createdAt: Date
    // One of these will be set, indicating what the reaction is for
    let messageId: String?    // Reference to messages collection
    let commentId: String?    // Reference to comments collection
}
```

## Security Rules

### Firestore Rules
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }
    
    function isOwner(userId) {
      return request.auth.uid == userId;
    }
    
    function isParticipant(messageData) {
      return isSignedIn() && 
        (request.auth.uid == messageData.senderId || 
         request.auth.uid == messageData.receiverId);
    }
    
    function isConversationParticipant(conversationData) {
      return isSignedIn() && 
        conversationData.participants.hasAny([request.auth.uid]);
    }
    
    function isFollowOperation() {
      // Only allow updates to followers and following arrays
      return request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['followers', 'following']);
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() && isOwner(userId);
      allow update: if isSignedIn() && (isOwner(userId) || isFollowOperation());
      allow delete: if isSignedIn() && isOwner(userId);
    }
    
    // Videos collection
    match /videos/{videoId} {
      allow read: if resource.data.isPublic == true || 
                    (isSignedIn() && isOwner(resource.data.userId));
      allow create: if isSignedIn();
      allow update, delete: if isSignedIn() && isOwner(resource.data.userId);
    }
    
    // Comments collection
    match /comments/{commentId} {
      allow read: if true;
      allow create: if isSignedIn();
      allow update, delete: if isSignedIn() && isOwner(resource.data.userId);
      
      // Prevent replies to replies
      allow create: if isSignedIn() && 
        (!resource.data.isReply || 
         (resource.data.isReply && exists(/databases/$(database)/documents/comments/$(resource.data.parentCommentId)) && 
          !get(/databases/$(database)/documents/comments/$(resource.data.parentCommentId)).data.isReply));
    }
    
    // Messages collection
    match /messages/{messageId} {
      allow read: if isSignedIn() && isParticipant(resource.data);
      allow create: if isSignedIn() && isParticipant(request.resource.data);
      allow update: if isSignedIn() && isParticipant(resource.data);
      allow delete: if isSignedIn() && isOwner(resource.data.senderId);
    }
    
    // Conversations collection
    match /conversations/{conversationId} {
      allow read: if isSignedIn() && isConversationParticipant(resource.data);
      allow create: if isSignedIn() && isConversationParticipant(request.resource.data);
      allow update: if isSignedIn() && isConversationParticipant(resource.data);
      allow delete: if false; // Conversations should not be deleted
    }
    
    // Reactions collection
    match /reactions/{reactionId} {
      allow read: if true;
      allow create: if isSignedIn();
      allow delete: if isSignedIn() && isOwner(resource.data.userId);
    }
  }
}
```

### Storage Rules
```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Profile pictures path
    match /profile_pictures/{userId} {
      allow read: if true;
      allow write: if request.auth != null &&
                   request.auth.uid == userId &&
                   request.resource.size < 5 * 1024 * 1024 && // 5MB max
                   request.resource.contentType.matches('image/.*');
    }

    // Videos path
    match /videos/{videoId} {
      allow read: if true;
      allow write: if request.auth != null &&
                   request.resource.size < 100 * 1024 * 1024 && // 100MB max
                   request.resource.contentType.matches('video/.*');
    }
    
    // Thumbnails are stored alongside videos with thumb_ prefix
    match /videos/thumb_{videoId} {
      allow read: if true;
      allow write: if request.auth != null &&
                   request.resource.size < 5 * 1024 * 1024 && // 5MB max
                   request.resource.contentType.matches('image/.*');
    }
    
    // Default rule - deny everything else
    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

## Required Indexes

### Videos Collection
1. Geospatial + Time Index:
   - Fields: 
     - `location` (ASCENDING)
     - `createdAt` (DESCENDING)
   - Query scope: Collection

2. Tags + Time Index:
   - Fields:
     - `tags` (ARRAY_CONTAINS)
     - `createdAt` (DESCENDING)
   - Query scope: Collection

3. User Posts Index:
   - Fields:
     - `user_id` (ASCENDING)
     - `created_at` (DESCENDING)
   - Query scope: Collection

### VideoSaves Collection
1. User Saves Index:
   - Fields:
     - `userId` (ASCENDING)
     - `createdAt` (DESCENDING)
   - Query scope: Collection

### Comments Collection
1. Video Comments Index:
   - Fields:
     - `videoId` (ASCENDING)
     - `isReply` (ASCENDING)
     - `createdAt` (DESCENDING)
   - Query scope: Collection

2. Comment Replies Index:
   - Fields:
     - `parentCommentId` (ASCENDING)
     - `createdAt` (ASCENDING)
   - Query scope: Collection

### Messages Collection
1. Conversation Messages Index:
   - Fields:
     - `conversationId` (ASCENDING)
     - `createdAt` (ASCENDING)
   - Query scope: Collection

2. User Messages Index:
   - Fields:
     - `senderId` (ASCENDING)
     - `createdAt` (DESCENDING)
   - Query scope: Collection

3. Received Messages Index:
   - Fields:
     - `receiverId` (ASCENDING)
     - `createdAt` (DESCENDING)
   - Query scope: Collection

### Reactions Collection
1. Message Reactions Index:
   - Fields:
     - `messageId` (ASCENDING)
     - `createdAt` (ASCENDING)
   - Query scope: Collection

2. Comment Reactions Index:
   - Fields:
     - `commentId` (ASCENDING)
     - `createdAt` (ASCENDING)
   - Query scope: Collection

### Conversations Collection
1. User Conversations Index:
   - Fields:
     - `participants` (ARRAY_CONTAINS)
     - `lastMessageTime` (DESCENDING)
   - Query scope: Collection

## Setup Instructions

1. **Enable Firestore**:
   - Go to Firebase Console > Build > Firestore Database
   - Create database in production mode
   - Select appropriate region (us-east/us-west)

2. **Enable Storage**:
   - Go to Firebase Console > Build > Storage
   - Initialize in production mode
   - Select same region as Firestore

3. **Set up Security Rules**:
   - Copy Firestore rules to Firebase Console > Firestore > Rules
   - Copy Storage rules to Firebase Console > Storage > Rules

4. **Create Indexes**:
   - Go to Firebase Console > Firestore > Indexes
   - Add the composite indexes listed above

5. **Initial Collections**:
   - Collections will be created automatically when first document is added
   - No manual setup required

## Best Practices

1. **Data Structure**:
   - Keep documents small
   - Use subcollections for scalable relationships
   - Denormalize data when it makes sense for your queries

2. **Security**:
   - Always validate auth in rules
   - Use security rules to enforce data structure
   - Test rules thoroughly before deployment

3. **Queries**:
   - Create indexes before querying
   - Keep queries simple and efficient
   - Monitor query performance in Firebase Console 