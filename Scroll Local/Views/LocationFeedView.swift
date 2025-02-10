import SwiftUI
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import AVKit

struct LocationFeedView: View {
    let coordinate: CLLocationCoordinate2D
    let searchRadius: CLLocationDistance
    let selectedCategories: Set<VideoCategory>
    @StateObject private var viewModel = LocationFeedViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            LocationFeedHeader(dismiss: dismiss)
            
            LocationFeedContent(viewModel: viewModel)
        }
        .task {
            print("🚀 LocationFeedView initialized with coordinate: \(coordinate), radius: \(searchRadius)m, categories: \(selectedCategories)")
            await viewModel.fetchVideos(
                near: coordinate,
                radius: searchRadius,
                categories: selectedCategories
            )
        }
    }
}

// MARK: - Header Component
private struct LocationFeedHeader: View {
    let dismiss: DismissAction
    
    var body: some View {
        HStack {
            Text("Videos Near Here")
                .font(.headline)
            Spacer()
            Button("Done") {
                dismiss()
            }
        }
        .padding()
    }
}

// MARK: - Content Component
private struct LocationFeedContent: View {
    @ObservedObject var viewModel: LocationFeedViewModel
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.videos.isEmpty {
                EmptyStateView()
            } else {
                VideoListView(videos: viewModel.videos, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Loading View
private struct LoadingView: View {
    var body: some View {
        ProgressView("Loading videos...")
            .padding()
    }
}

// MARK: - Empty State View
private struct EmptyStateView: View {
    var body: some View {
        Text("No videos found at this location")
            .foregroundColor(.secondary)
            .padding()
    }
}

// MARK: - Video List View
private struct VideoListView: View {
    let videos: [Video]
    let viewModel: LocationFeedViewModel
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                    VideoCard(video: video, index: index, viewModel: viewModel)
                        .frame(height: UIScreen.main.bounds.height * 0.8)
                }
            }
        }
    }
}

// MARK: - View Model
@MainActor
class LocationFeedViewModel: FeedViewModel {
    private var currentLocation: CLLocationCoordinate2D?
    private var currentRadius: CLLocationDistance?
    private var currentCategories: Set<VideoCategory>?
    
    override func fetchVideos() async {
        if let location = currentLocation,
           let radius = currentRadius,
           let categories = currentCategories {
            await fetchVideos(near: location, radius: radius, categories: categories)
        }
    }
    
    func fetchVideos(near coordinate: CLLocationCoordinate2D, radius: CLLocationDistance, categories: Set<VideoCategory>) async {
        print("🎯 Starting to fetch videos near coordinate: \(coordinate) within \(radius)m")
        isLoading = true
        currentLocation = coordinate
        currentRadius = radius
        currentCategories = categories
        
        let center = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        print("📍 Search center: \(center)")
        
        do {
            let db = Firestore.firestore()
            print("🔍 Querying Firestore with radius: \(radius) meters")
            
            // Use Firestore's geopoint queries
            let snapshot = try await db.collection("videos")
                .whereField("location", isGreaterThanOrEqualTo: GeoPoint(
                    latitude: coordinate.latitude - 0.1,  // Rough bounding box to help Firestore
                    longitude: coordinate.longitude - 0.1
                ))
                .whereField("location", isLessThanOrEqualTo: GeoPoint(
                    latitude: coordinate.latitude + 0.1,
                    longitude: coordinate.longitude + 0.1
                ))
                .getDocuments()
            
            print("📦 Found \(snapshot.documents.count) documents in rough bounding box")
            
            let fetchedVideos = snapshot.documents.compactMap { document -> Video? in
                print("📄 Processing document: \(document.documentID)")
                guard let data = document.data() as? [String: Any],
                      let location = data["location"] as? GeoPoint,
                      let category = data["category"] as? String,
                      let videoCategory = VideoCategory(rawValue: category),
                      categories.contains(videoCategory) else {
                    print("❌ Invalid document data or category not selected")
                    return nil
                }
                
                // Calculate exact distance from tap location
                let videoLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let centerLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                let distance = videoLocation.distance(from: centerLocation)
                
                print("📏 Video distance from center: \(distance)m (max allowed: \(radius)m)")
                
                // Only include videos within the exact search radius
                if distance <= radius {
                    print("✅ Video within radius (\(String(format: "%.2f", distance))m) and matching category '\(category)', including in results")
                    return Video(id: document.documentID, data: data)
                } else {
                    print("❌ Video outside radius (\(String(format: "%.2f", distance))m > \(radius)m), excluding")
                    return nil
                }
            }
            
            print("🎬 Found \(fetchedVideos.count) matching videos within \(String(format: "%.2f", radius))m radius")
            
            if fetchedVideos.isEmpty {
                print("ℹ️ No videos found within \(String(format: "%.2f", radius))m of tap location")
            }
            
            // Update videos using the protected method
            updateVideos(fetchedVideos)
            print("🔄 Updated videos array with fetched results")
            
            // Only fetch user interactions for the filtered videos
            if !fetchedVideos.isEmpty {
                print("👤 Fetching user interactions for \(fetchedVideos.count) videos...")
                await fetchUserInteractions(for: fetchedVideos.compactMap { $0.id })
            }
            
        } catch {
            print("❌ Error fetching videos: \(error)")
            self.error = error
        }
        
        isLoading = false
        print("✅ Finished fetching videos")
    }
    
    private func fetchUserInteractions(for videoIds: [String]) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let db = Firestore.firestore()
            
            // Fetch saves
            let savesSnapshot = try await db.collection("videoSaves")
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("videoId", in: videoIds)
                .getDocuments()
            
            savedVideoIds = Set(savesSnapshot.documents.compactMap { doc in
                VideoSave(id: doc.documentID, data: doc.data())?.videoId
            })
            
            // Fetch ratings
            let ratingsSnapshot = try await db.collection("videoRatings")
                .whereField("userId", isEqualTo: currentUserId)
                .whereField("videoId", in: videoIds)
                .getDocuments()
            
            videoRatings = Dictionary(uniqueKeysWithValues: ratingsSnapshot.documents.compactMap { doc in
                if let rating = VideoRating(id: doc.documentID, data: doc.data()) {
                    return (rating.videoId, rating.isHelpful)
                }
                return nil
            })
        } catch {
            print("❌ Error fetching user interactions: \(error)")
        }
    }
} 