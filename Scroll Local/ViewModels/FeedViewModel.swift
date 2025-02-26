import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var savedVideoIds: Set<String> = []
    @Published var videoRatings: [String: Bool] = [:]
    @Published var hasSearched = false
    @Published var lastSearchQuery: String?
    
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let batchSize = 5 // Number of videos to fetch at a time
    private let maxVideos = 10 // Maximum number of videos to keep in memory
    private var currentFeedType: FeedType = .localArea
    
    enum FeedType {
        case following
        case localArea
        case explore
    }
    
    init() {
        Task {
            await loadUserInteractions()
        }
    }
    
    // Update feed type and refresh videos
    func updateFeedType(_ type: FeedType) async {
        print("Updating feed type to: \(type)")
        currentFeedType = type
        
        // Clear videos in all cases
        videos.removeAll()
        
        if type == .explore {
            // For explore tab, just clear videos and wait for search
            lastDocument = nil
        } else {
            // For following and local area, fetch new videos
            lastDocument = nil
            await fetchVideos()
        }
    }
    
    // Refresh video data to get latest counts
    private func refreshVideoData() async {
        guard !videos.isEmpty else { return }
        
        do {
            let videoIds = videos.compactMap { $0.id }
            let chunkedIds = stride(from: 0, to: videoIds.count, by: 10).map {
                Array(videoIds[$0..<min($0 + 10, videoIds.count)])
            }
            
            for chunk in chunkedIds {
                let snapshot = try await db.collection("videos")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                
                for document in snapshot.documents {
                    if let index = videos.firstIndex(where: { $0.id == document.documentID }),
                       let updatedVideo = Video(id: document.documentID, data: document.data()) {
                        videos[index] = updatedVideo
                    }
                }
            }
        } catch {
            print("Error refreshing video data: \(error)")
        }
    }
    
    // Add real-time listener for video updates
    private func addVideoListener(for videoId: String) {
        db.collection("videos").document(videoId)
            .addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self,
                      let document = documentSnapshot,
                      document.exists,
                      let updatedVideo = Video(id: document.documentID, data: document.data() ?? [:]),
                      let index = self.videos.firstIndex(where: { $0.id == document.documentID }) else {
                    return
                }
                
                Task { @MainActor in
                    self.videos[index] = updatedVideo
                }
            }
    }
    
    // Add listeners for all visible videos
    private func addVideoListeners() {
        for video in videos {
            if let videoId = video.id {
                addVideoListener(for: videoId)
            }
        }
    }
    
    // Load user display names for videos
    private func loadUserDisplayNames() async {
        let userIds = Set(videos.map { $0.userId })
        
        for userId in userIds {
            do {
                let userDoc = try await db.collection("users").document(userId).getDocument()
                if let displayName = userDoc.data()?["displayName"] as? String {
                    // Update all videos by this user with their display name
                    for (index, video) in videos.enumerated() where video.userId == userId {
                        videos[index].userDisplayName = displayName
                    }
                }
            } catch {
                print("Error fetching user display name: \(error)")
            }
        }
    }
    
    // Load user interactions for all videos
    private func loadUserInteractions() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Fetch all video IDs
            let videoIds = videos.map { $0.id }
            
            // Fetch saves
            let savesSnapshot = try await db.collection("videoSaves")
                .whereField("userId", isEqualTo: currentUserId)
                .getDocuments()
            
            savedVideoIds = Set(savesSnapshot.documents.compactMap { doc in
                VideoSave(id: doc.documentID, data: doc.data())?.videoId
            })
            
            // Fetch ratings
            let ratingsSnapshot = try await db.collection("videoRatings")
                .whereField("userId", isEqualTo: currentUserId)
                .getDocuments()
            
            videoRatings = Dictionary(uniqueKeysWithValues: ratingsSnapshot.documents.compactMap { doc in
                if let rating = VideoRating(id: doc.documentID, data: doc.data()) {
                    return (rating.videoId, rating.isHelpful)
                }
                return nil
            })
        } catch {
            print("Error loading user interactions: \(error)")
        }
    }
    
    // Fetch initial videos
    func fetchVideos() async {
        print("Starting to fetch videos... Feed type: \(currentFeedType)")
        isLoading = true
        error = nil
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("No authenticated user found")
            isLoading = false
            return
        }
        
        do {
            if currentFeedType == .following {
                // Get the list of users being followed
                let userDoc = try await db.collection("users").document(currentUserId).getDocument()
                let following = (userDoc.data()?["following"] as? [String]) ?? []
                print("Found \(following.count) followed users")
                
                if following.isEmpty {
                    print("No followed users found, clearing videos")
                    videos = []
                    isLoading = false
                    return
                }
                
                // Split following into chunks of 10 (Firestore limit for 'in' operator)
                let followingChunks = stride(from: 0, to: following.count, by: 10).map {
                    Array(following[$0..<min($0 + 10, following.count)])
                }
                
                var allVideos: [QueryDocumentSnapshot] = []
                
                // Fetch videos for each chunk of followed users
                for chunk in followingChunks {
                    let query = db.collection("videos")
                        .whereField("user_id", in: chunk)
                        .order(by: "created_at", descending: true)
                        .limit(to: batchSize)
                    
                    let snapshot = try await query.getDocuments()
                    allVideos.append(contentsOf: snapshot.documents)
                }
                
                // Sort all videos by creation date
                allVideos.sort { doc1, doc2 in
                    let date1 = (doc1.data()["created_at"] as? Timestamp)?.dateValue() ?? Date.distantPast
                    let date2 = (doc2.data()["created_at"] as? Timestamp)?.dateValue() ?? Date.distantPast
                    return date1 > date2
                }
                
                // Take only the first batchSize videos
                let batchVideos = Array(allVideos.prefix(batchSize))
                lastDocument = batchVideos.last
                
                videos = batchVideos.compactMap { document in
                    print("Processing document: \(document.documentID)")
                    let video = Video(id: document.documentID, data: document.data())
                    if video == nil {
                        print("Failed to parse document: \(document.data())")
                    }
                    return video
                }
            } else {
                // Local area feed - original implementation
                let query = db.collection("videos")
                    .order(by: "created_at", descending: true)
                    .limit(to: batchSize)
                
                print("Executing Firestore query...")
                let snapshot = try await query.getDocuments()
                print("Got \(snapshot.documents.count) documents from Firestore")
                
                lastDocument = snapshot.documents.last
                
                videos = snapshot.documents.compactMap { document in
                    print("Processing document: \(document.documentID)")
                    let video = Video(id: document.documentID, data: document.data())
                    if video == nil {
                        print("Failed to parse document: \(document.data())")
                    }
                    return video
                }
            }
            
            print("Successfully parsed \(videos.count) videos")
            
            // Add listeners for the new videos
            addVideoListeners()
            
            // Load user display names
            await loadUserDisplayNames()
            
            // Refresh video data and fetch user interactions
            await refreshVideoData()
            await fetchUserInteractions(for: videos.compactMap { $0.id }, userId: currentUserId)
            
        } catch {
            self.error = error
            print("Error fetching videos: \(error)")
        }
        
        isLoading = false
    }
    
    // Fetch user interactions for videos
    private func fetchUserInteractions(for videoIds: [String], userId: String) async {
        // Guard against empty video IDs array
        guard !videoIds.isEmpty else {
            print("No videos to fetch interactions for")
            return
        }
        
        do {
            // Fetch saves
            let savesSnapshot = try await db.collection("videoSaves")
                .whereField("userId", isEqualTo: userId)
                .whereField("videoId", in: videoIds)
                .getDocuments()
            
            savedVideoIds = Set(savesSnapshot.documents.compactMap { doc in
                VideoSave(id: doc.documentID, data: doc.data())?.videoId
            })
            
            // Fetch ratings
            let ratingsSnapshot = try await db.collection("videoRatings")
                .whereField("userId", isEqualTo: userId)
                .whereField("videoId", in: videoIds)
                .getDocuments()
            
            videoRatings = Dictionary(uniqueKeysWithValues: ratingsSnapshot.documents.compactMap { doc in
                if let rating = VideoRating(id: doc.documentID, data: doc.data()) {
                    return (rating.videoId, rating.isHelpful)
                }
                return nil
            })
        } catch {
            print("Error fetching user interactions: \(error)")
        }
    }
    
    // Toggle save for video
    func toggleSave(for videoId: String) async {
        print("Toggling save for video: \(videoId)")
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let isSaved = try await VideoSave.toggleSave(userId: currentUserId, videoId: videoId)
            print("Save operation completed, isSaved: \(isSaved)")
            
            // Get the latest video data from Firebase
            let videoDoc = try await db.collection("videos").document(videoId).getDocument()
            print("Retrieved latest video data from Firebase")
            
            if let videoData = videoDoc.data(),
               let updatedVideo = Video(id: videoId, data: videoData) {
                print("📼 Video data: \(videoData)")
                print("Updated video data: save count = \(updatedVideo.saveCount)")
                
                // Update local video data
                if let index = videos.firstIndex(where: { $0.id == videoId }) {
                    videos[index] = updatedVideo
                }
                
                // Update local saved state
                if isSaved {
                    savedVideoIds.insert(videoId)
                    
                    // Create notification using the video data we already have
                    if let videoOwnerId = videoData["user_id"] as? String {
                        print("Creating save notification for user: \(videoOwnerId)")
                        await createNotification(
                            for: videoOwnerId,
                            type: "save",
                            videoId: videoId
                        )
                    } else {
                        print("❌ Could not find video owner ID in data")
                    }
                } else {
                    savedVideoIds.remove(videoId)
                }
            }
        } catch {
            print("Error toggling save: \(error)")
        }
    }
    
    // Update video rating
    func updateRating(for videoId: String, isHelpful: Bool) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            // Get the current rating before making any changes
            let oldRating = videoRatings[videoId]
            
            try await VideoRating.updateRating(userId: currentUserId, videoId: videoId, isHelpful: isHelpful)
            
            // Update local rating state
            videoRatings[videoId] = isHelpful
            
            // Update local counts
            if let index = videos.firstIndex(where: { $0.id == videoId }) {
                if let oldRating = oldRating {
                    // If changing from helpful to not helpful or vice versa
                    if oldRating != isHelpful {
                        if isHelpful {
                            videos[index].helpfulCount += 1
                            videos[index].notHelpfulCount -= 1
                        } else {
                            videos[index].helpfulCount -= 1
                            videos[index].notHelpfulCount += 1
                        }
                    }
                } else {
                    // New rating
                    if isHelpful {
                        videos[index].helpfulCount += 1
                    } else {
                        videos[index].notHelpfulCount += 1
                    }
                }
            }
        } catch {
            print("Error updating rating: \(error)")
        }
    }
    
    // Helper function to check if a video is saved
    func isVideoSaved(_ videoId: String) -> Bool {
        return savedVideoIds.contains(videoId)
    }
    
    // Helper function to get video rating
    func getVideoRating(_ videoId: String) -> Int {
        if let isHelpful = videoRatings[videoId] {
            return isHelpful ? 1 : -1
        }
        return 0
    }
    
    // Increment view count
    func incrementViews(for videoId: String) async {
        do {
            try await db.collection("videos").document(videoId).updateData([
                "views": FieldValue.increment(Int64(1))
            ])
        } catch {
            print("Error incrementing views: \(error)")
        }
    }
    
    // Fetch more videos (pagination)
    func fetchMoreVideos() async {
        print("Attempting to fetch more videos... Current count: \(videos.count)")
        guard !isLoading, let lastDocument = lastDocument else {
            print("Cannot fetch more videos: isLoading=\(isLoading), lastDocument=\(lastDocument != nil)")
            return
        }
        
        isLoading = true
        error = nil
        
        do {
            guard let currentUserId = Auth.auth().currentUser?.uid else {
                print("No authenticated user found")
                isLoading = false
                return
            }
            
            if currentFeedType == .following {
                // Get the list of users being followed
                let userDoc = try await db.collection("users").document(currentUserId).getDocument()
                let following = (userDoc.data()?["following"] as? [String]) ?? []
                print("Found \(following.count) followed users for pagination")
                
                if following.isEmpty {
                    print("No followed users found, skipping pagination")
                    isLoading = false
                    return
                }
                
                // Split following into chunks of 10 (Firestore limit for 'in' operator)
                let followingChunks = stride(from: 0, to: following.count, by: 10).map {
                    Array(following[$0..<min($0 + 10, following.count)])
                }
                
                var allVideos: [QueryDocumentSnapshot] = []
                
                // Fetch videos for each chunk of followed users
                for chunk in followingChunks {
                    let query = db.collection("videos")
                        .whereField("user_id", in: chunk)
                        .order(by: "created_at", descending: true)
                        .start(afterDocument: lastDocument)
                        .limit(to: batchSize)
                    
                    let snapshot = try await query.getDocuments()
                    allVideos.append(contentsOf: snapshot.documents)
                }
                
                // Sort all videos by creation date
                allVideos.sort { doc1, doc2 in
                    let date1 = (doc1.data()["created_at"] as? Timestamp)?.dateValue() ?? Date.distantPast
                    let date2 = (doc2.data()["created_at"] as? Timestamp)?.dateValue() ?? Date.distantPast
                    return date1 > date2
                }
                
                // Take only the first batchSize videos
                let batchVideos = Array(allVideos.prefix(batchSize))
                self.lastDocument = batchVideos.last
                
                let fetchedVideos = batchVideos.compactMap { document in
                    Video(id: document.documentID, data: document.data())
                }
                
                // Remove older videos if we'll exceed maxVideos
                if videos.count + fetchedVideos.count > maxVideos {
                    let numberOfVideosToRemove = (videos.count + fetchedVideos.count) - maxVideos
                    print("Removing \(numberOfVideosToRemove) older videos to maintain max limit")
                    videos.removeFirst(numberOfVideosToRemove)
                }
                
                // Add the new videos to our array
                videos.append(contentsOf: fetchedVideos)
                
            } else {
                // Local area feed - original implementation
                let query = db.collection("videos")
                    .order(by: "created_at", descending: true)
                    .start(afterDocument: lastDocument)
                    .limit(to: batchSize)
                
                print("Executing pagination query...")
                let snapshot = try await query.getDocuments()
                print("Got \(snapshot.documents.count) additional documents")
                
                self.lastDocument = snapshot.documents.last
                
                let fetchedVideos = snapshot.documents.compactMap { document in
                    Video(id: document.documentID, data: document.data())
                }
                
                // Remove older videos if we'll exceed maxVideos
                if videos.count + fetchedVideos.count > maxVideos {
                    let numberOfVideosToRemove = (videos.count + fetchedVideos.count) - maxVideos
                    print("Removing \(numberOfVideosToRemove) older videos to maintain max limit")
                    videos.removeFirst(numberOfVideosToRemove)
                }
                
                // Add the new videos to our array
                videos.append(contentsOf: fetchedVideos)
            }
            
            print("New total video count: \(videos.count)")
            
            // Load user display names for the new videos
            await loadUserDisplayNames()
            
            // Refresh video data and fetch user interactions for new videos
            await refreshVideoData()
            await fetchUserInteractions(for: videos.compactMap { $0.id }, userId: currentUserId)
            
        } catch {
            self.error = error
            print("Error fetching more videos: \(error)")
        }
        
        isLoading = false
    }
    
    // Protected method for subclasses to update videos
    func updateVideos(_ newVideos: [Video]) {
        videos = newVideos
    }
    
    // Add this method to FeedViewModel
    private func createNotification(for recipientId: String, type: String, videoId: String, commentText: String? = nil) async {
        print("🔔 Starting notification creation...")
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No current user found")
            return
        }
        
        // Don't create notification if recipient is the current user
        if recipientId == currentUser.uid {
            print("⚠️ Skipping notification - user is saving/commenting on their own video")
            return
        }
        
        print("📝 Creating notification for recipient: \(recipientId)")
        print("👤 From user: \(currentUser.uid)")
        print("🎥 For video: \(videoId)")
        
        let db = Firestore.firestore()
        let notification = [
            "recipientId": recipientId,
            "senderId": currentUser.uid,
            "senderDisplayName": currentUser.displayName ?? "A user",
            "type": type,
            "videoId": videoId,
            "createdAt": FieldValue.serverTimestamp(),
            "isRead": false,
            "commentText": commentText
        ] as [String: Any]
        
        do {
            let docRef = try await db.collection("notifications").addDocument(data: notification)
            print("✅ Successfully created notification with ID: \(docRef.documentID)")
        } catch {
            print("❌ Error creating notification: \(error)")
        }
    }
    
    func submitExploreResults(query: String, videos: [Video], isHelpful: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        do {
            let videoDetails = videos.map { video -> [String: Any] in
                return [
                    "id": video.id,
                    "title": video.title ?? "",
                    "description": video.description ?? "",
                    "user_id": video.userId,
                    "location": video.location ?? ""
                ]
            }
            
            try await db.collection("explore_results").addDocument(data: [
                "query": query,
                "is_helpful": isHelpful,
                "user_id": userId,
                "video_ids": videos.map { $0.id },
                "search_results": videoDetails,
                "created_at": FieldValue.serverTimestamp()
            ])
            print("Successfully submitted explore results feedback")
        } catch {
            print("Error submitting explore results:", error)
        }
    }
} 