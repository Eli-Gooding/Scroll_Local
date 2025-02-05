import Foundation
import FirebaseFirestore

@MainActor
class FeedViewModel: ObservableObject {
    @Published var videos: [Video] = []
    @Published var isLoading = false
    @Published var error: Error?
    
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
            
            // Print the raw data from Firestore
            for doc in snapshot.documents {
                print("Document \(doc.documentID) data: \(doc.data())")
            }
            
            lastDocument = snapshot.documents.last
            
            videos = snapshot.documents.compactMap { document in
                print("Processing document: \(document.documentID)")
                let video = Video(id: document.documentID, data: document.data())
                if video == nil {
                    print("Failed to parse document: \(document.data())")
                }
                return video
            }
            
            print("Successfully parsed \(videos.count) videos")
        } catch {
            self.error = error
            print("Error fetching videos: \(error)")
        }
        
        isLoading = false
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
            
            videos.append(contentsOf: fetchedVideos)
        } catch {
            self.error = error
            print("Error fetching more videos: \(error)")
        }
        
        isLoading = false
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
    
    // Update video ratings
    func updateRating(for videoId: String, isHelpful: Bool) async {
        do {
            let field = isHelpful ? "helpful_count" : "not_helpful_count"
            try await db.collection("videos").document(videoId).updateData([
                field: FieldValue.increment(Int64(1))
            ])
        } catch {
            print("Error updating rating: \(error)")
        }
    }
} 