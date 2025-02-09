import SwiftUI
import CoreLocation
import FirebaseFirestore
import FirebaseAuth
import AVKit

struct LocationFeedView: View {
    let coordinate: CLLocationCoordinate2D
    @StateObject private var viewModel = LocationFeedViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            LocationFeedHeader(dismiss: dismiss)
            
            LocationFeedContent(viewModel: viewModel)
        }
        .task {
            print("🚀 LocationFeedView initialized with coordinate: \(coordinate)")
            await viewModel.fetchVideos(near: coordinate)
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
    let viewModel: FeedViewModel
    
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
    private let searchRadius = 201.168 // 1/8 mile in meters
    private var currentLocation: CLLocationCoordinate2D?
    
    override func fetchVideos() async {
        if let location = currentLocation {
            await fetchVideos(near: location)
        }
    }
    
    func fetchVideos(near coordinate: CLLocationCoordinate2D) async {
        print("🎯 Starting to fetch videos near coordinate: \(coordinate)")
        isLoading = true
        currentLocation = coordinate
        
        let center = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        print("📍 Search center: \(center)")
        
        do {
            let db = Firestore.firestore()
            print("🔍 Querying Firestore with radius: \(searchRadius) meters")
            
            let snapshot = try await db.collection("videos")
                .whereField("location", isGreaterThan: GeoPoint(
                    latitude: coordinate.latitude - 0.001,
                    longitude: coordinate.longitude - 0.001
                ))
                .whereField("location", isLessThan: GeoPoint(
                    latitude: coordinate.latitude + 0.001,
                    longitude: coordinate.longitude + 0.001
                ))
                .getDocuments()
            
            print("📦 Found \(snapshot.documents.count) documents in bounding box")
            
            let fetchedVideos = snapshot.documents.compactMap { document -> Video? in
                print("📄 Processing document: \(document.documentID)")
                guard let data = document.data() as? [String: Any],
                      let location = data["location"] as? GeoPoint else {
                    print("❌ Invalid document data or missing location")
                    return nil
                }
                
                // Calculate distance from search center
                let videoLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                let distance = videoLocation.distance(from: centerLocation)
                
                print("📏 Video distance from center: \(distance) meters")
                
                // Only include videos within the search radius
                if distance <= searchRadius {
                    print("✅ Video within radius, including in results")
                    return Video(id: document.documentID, data: data)
                }
                print("❌ Video outside radius, excluding")
                return nil
            }
            
            print("🎬 Found \(fetchedVideos.count) videos within search radius")
            
            // Update videos using the protected method
            updateVideos(fetchedVideos)
            print("🔄 Updated videos array with fetched results")
            
            // Let parent class handle user interactions
            print("👤 Fetching user interactions...")
            await super.fetchVideos()
            
        } catch {
            print("❌ Error fetching videos: \(error)")
            self.error = error
        }
        
        isLoading = false
        print("✅ Finished fetching videos")
    }
} 