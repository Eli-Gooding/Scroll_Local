import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var savedVideoIds: Set<String> = []
    @Published var videoRatings: [String: Bool] = [:] // videoId: isHelpful
    
    private let db = Firestore.firestore()
    private var lastDocument: DocumentSnapshot?
    private let limit = 5 // Number of videos to fetch at a time
    
    // Fetch initial videos
    func fetchVideos() async {
        print("Starting to fetch videos...")
        isLoading = true
        error = nil
        
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
            if let currentUserId = Auth.auth().currentUser?.uid {
                await fetchUserInteractions(for: videos.compactMap { $0.id }, userId: currentUserId)
            }
            
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
            
            // Update local state
            if isSaved {
                savedVideoIds.insert(videoId)
            } else {
                savedVideoIds.remove(videoId)
            }
            
            // Update video in the list if it exists
            if let index = videos.firstIndex(where: { $0.id == videoId }) {
                videos[index].saveCount += isSaved ? 1 : -1
            }
        } catch {
            print("Error toggling save: \(error)")
        }
    }
    
    // Update video rating
    func updateRating(for videoId: String, isHelpful: Bool) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            try await VideoRating.updateRating(userId: currentUserId, videoId: videoId, isHelpful: isHelpful)
            
            // Update local state
            videoRatings[videoId] = isHelpful
            
            // Update video in the list if it exists
            if let index = videos.firstIndex(where: { $0.id == videoId }) {
                let oldRating = videoRatings[videoId]
                if let oldRating = oldRating {
                    // Remove old rating count
                    if oldRating {
                        videos[index].helpfulCount -= 1
                    } else {
                        videos[index].notHelpfulCount -= 1
                    }
                }
                // Add new rating count
                if isHelpful {
                    videos[index].helpfulCount += 1
                } else {
                    videos[index].notHelpfulCount += 1
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
        guard let isHelpful = videoRatings[videoId] else {
            return 0
        }
        return isHelpful ? 1 : -1
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