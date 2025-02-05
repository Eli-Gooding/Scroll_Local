import Foundation
import FirebaseFirestore

class ProfileViewModel: ObservableObject {
    @Published var userVideos: [Video] = []
    @Published var savedVideos: [Video] = []
    @Published var isLoading = false
    
    private let firebaseService = FirebaseService.shared
    
    func fetchUserVideos() {
        guard let userId = firebaseService.authUser?.uid else { return }
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("videos")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        print("Error fetching user videos: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    self?.userVideos = documents.compactMap { document in
                        Video(id: document.documentID, data: document.data())
                    }
                }
            }
    }
    
    func fetchSavedVideos() {
        guard let userId = firebaseService.authUser?.uid else { return }
        isLoading = true
        
        let db = Firestore.firestore()
        db.collection("videoSaves")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("Error fetching saved videos: \(error)")
                    DispatchQueue.main.async {
                        self?.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.savedVideos = []
                    }
                    return
                }
                
                let videoIds = documents.compactMap { document -> String? in
                    document.data()["video_id"] as? String
                }
                
                if videoIds.isEmpty {
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        self?.savedVideos = []
                    }
                    return
                }
                
                // Fetch the actual video documents
                db.collection("videos")
                    .whereField(FieldPath.documentID(), in: videoIds)
                    .getDocuments { [weak self] videoSnapshot, videoError in
                        DispatchQueue.main.async {
                            self?.isLoading = false
                            
                            if let videoError = videoError {
                                print("Error fetching video details: \(videoError)")
                                return
                            }
                            
                            guard let videoDocuments = videoSnapshot?.documents else { return }
                            self?.savedVideos = videoDocuments.compactMap { document in
                                Video(id: document.documentID, data: document.data())
                            }
                        }
                    }
            }
    }
}
