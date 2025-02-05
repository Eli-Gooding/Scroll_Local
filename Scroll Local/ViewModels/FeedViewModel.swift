import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published private var savedVideoIds: Set<String> = []
    @Published private var videoRatings: [String: Bool] = [:]
    
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let limit = 5 // Number of videos to fetch at a time
    
    init() {
        Task {
            await loadUserInteractions()
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
        print("Starting to fetch videos...")
        isLoading = true
        error = nil
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            isLoading = false
            return
        }
        
        do {
            let query = db.collection("videos")
                .order(by: "created_at", descending: true)
                .limit(to: limit)
            
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
            
            // Fetch user interactions for these videos
            await fetchUserInteractions(for: videos.compactMap { $0.id }, userId: currentUserId)
            
            print("Successfully parsed \(videos.count) videos")
        } catch {
            self.error = error
            print("Error fetching videos: \(error)")
        }
        
        isLoading = false
    }
    
    // Fetch user interactions for videos
    private func fetchUserInteractions(for videoIds: [String], userId: String) async {
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
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let isSaved = try await VideoSave.toggleSave(userId: currentUserId, videoId: videoId)
            
            // Update local saved state
            if isSaved {
                savedVideoIds.insert(videoId)
                // Update local save count
                if let index = videos.firstIndex(where: { $0.id == videoId }) {
                    videos[index].saveCount += 1
                }
            } else {
                savedVideoIds.remove(videoId)
                // Update local save count
                if let index = videos.firstIndex(where: { $0.id == videoId }) {
                    videos[index].saveCount -= 1
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
        guard !isLoading, let lastDocument = lastDocument else { return }
        
        isLoading = true
        error = nil
        
        do {
            let query = db.collection("videos")
                .order(by: "created_at", descending: true)
                .start(afterDocument: lastDocument)
                .limit(to: limit)
            
            let snapshot = try await query.getDocuments()
            self.lastDocument = snapshot.documents.last
            
            let fetchedVideos = snapshot.documents.compactMap { document in
                Video(id: document.documentID, data: document.data())
            }
            
            // Fetch user interactions for new videos
            if let currentUserId = Auth.auth().currentUser?.uid {
                await fetchUserInteractions(for: fetchedVideos.compactMap { $0.id }, userId: currentUserId)
            }
            
            videos.append(contentsOf: fetchedVideos)
        } catch {
            self.error = error
            print("Error fetching more videos: \(error)")
        }
        
        isLoading = false
    }
} 