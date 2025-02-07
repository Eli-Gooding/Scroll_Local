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
    private let geocoder = CLGeocoder()
    
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
        
        // Parse hashtags from description
        let tags = parseHashtags(from: description)
        
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
                
                // Get formatted location
                var geoPoint = GeoPoint(latitude: 0, longitude: 0)
                var formattedLocation = "Unknown Location"
                
                if let coordinate = metadata.location {
                    geoPoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
                    if let placemark = try? await geocoder.reverseGeocodeLocation(CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)).first {
                        // Build location string
                        var components: [String] = []
                        if let locality = placemark.locality {
                            components.append(locality)
                        }
                        if let administrativeArea = placemark.administrativeArea {
                            components.append(administrativeArea)
                        }
                        if let country = placemark.country {
                            components.append(country)
                        }
                        formattedLocation = components.joined(separator: ", ")
                    }
                }
                
                // Try to get the current user's display name, but don't fail if we can't
                var userDisplayName: String? = nil
                do {
                    let currentUser = try await UserService.shared.fetchUser(withId: userId)
                    userDisplayName = currentUser.displayName
                } catch {
                    print("Warning: Could not fetch user display name: \(error)")
                    // Continue without the display name
                }
                
                let video = Video(
                    userId: userId,
                    title: title,
                    description: description,
                    location: geoPoint,
                    formattedLocation: formattedLocation,
                    tags: tags,
                    category: category,
                    videoUrl: downloadURL.absoluteString,
                    createdAt: Date(),
                    views: 0,
                    helpfulCount: 0,
                    notHelpfulCount: 0,
                    saveCount: 0,
                    commentCount: 0,
                    userDisplayName: userDisplayName
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
    
    // Parse hashtags from text
    private func parseHashtags(from text: String) -> [String] {
        // Split text into words and filter for hashtags
        let words = text.split(separator: " ")
        return words
            .filter { $0.hasPrefix("#") }
            .map { String($0.dropFirst()) }  // Remove the # symbol
            .filter { !$0.isEmpty }  // Remove any empty tags
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
