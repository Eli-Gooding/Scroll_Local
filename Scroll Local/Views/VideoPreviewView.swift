import SwiftUI
import AVKit
import CoreLocation
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore

struct VideoPreviewView: View {
    let videoURL: URL
    @State private var player: AVPlayer?
    @State private var isUploading = false
    @State private var showMetadataForm = false
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationView {
            VStack {
                if let player = player {
                    VideoPlayer(player: player)
                        .aspectRatio(9/16, contentMode: .fit)
                        .onAppear {
                            player.play()
                        }
                        .onDisappear {
                            player.pause()
                        }
                }
                
                Button(action: {
                    showMetadataForm = true
                }) {
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .disabled(isUploading)
                .padding()
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
            .sheet(isPresented: $showMetadataForm) {
                VideoMetadataForm { title, description, category, commentCount in
                    uploadVideo(title: title, description: description, category: category)
                }
            }
        }
        .onAppear {
            player = AVPlayer(url: videoURL)
        }
    }
    
    private func uploadVideo(title: String, description: String, category: String) {
        isUploading = true
        
        // Get video metadata including location
        let location = locationManager.location
        let metadata = VideoMetadata(
            location: location?.coordinate,
            timestamp: Date()
        )
        
        // Upload video to Firebase Storage
        Task {
            do {
                guard let userId = Auth.auth().currentUser?.uid else {
                    print("Error: No authenticated user")
                    isUploading = false
                    return
                }
                
                let videoData = try Data(contentsOf: videoURL)
                let storageRef = Storage.storage().reference()
                let videoId = UUID().uuidString
                let videoRef = storageRef.child("videos/\(videoId).mov")
                
                // Create metadata
                let storageMetadata = StorageMetadata()
                storageMetadata.contentType = "video/quicktime"
                
                // Upload video data
                _ = try await videoRef.putDataAsync(videoData, metadata: storageMetadata)
                
                // Get download URL
                let downloadURL = try await videoRef.downloadURL()
                
                // Create video document in Firestore
                let locationString = if let location = metadata.location {
                    "\(location.latitude),\(location.longitude)"
                } else {
                    ""
                }
                
                let video = Video(
                    userId: userId,
                    title: title,
                    description: description,
                    location: locationString,
                    tags: [],
                    category: category,
                    videoUrl: downloadURL.absoluteString,
                    createdAt: Date(),
                    views: 0,
                    helpfulCount: 0,
                    notHelpfulCount: 0,
                    saveCount: 0,
                    commentCount: 0
                )
                
                try await Firestore.firestore()
                    .collection("videos")
                    .document()
                    .setData(video.firestoreData)
                
                // Dismiss view after successful upload
                DispatchQueue.main.async {
                    isUploading = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("Error uploading video: \(error)")
                isUploading = false
            }
        }
    }
}

// Helper class for location management
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var location: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
    }
}

// Video metadata structure
struct VideoMetadata {
    let location: CLLocationCoordinate2D?
    let timestamp: Date
}

#Preview {
    VideoPreviewView(videoURL: URL(string: "https://example.com/video.mov")!)
}
