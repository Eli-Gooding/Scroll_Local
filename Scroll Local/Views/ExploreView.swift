import SwiftUI
import MapKit
import FirebaseFirestore

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @State private var selectedVideo: Video?
    @State private var showVideoDetail = false
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    ))
    let initialLocation: GeoPoint?
    
    init(initialLocation: GeoPoint? = nil) {
        self.initialLocation = initialLocation
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                mapView
                VStack(alignment: .trailing, spacing: 8) {
                    categoryToggles
                    locationButton
                }
                .padding()
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showVideoDetail) {
            if let video = selectedVideo {
                VideoDetailView(video: video)
            }
        }
        .onAppear {
            if let location = initialLocation {
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    ),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                viewModel.updateRegion(region)
                cameraPosition = .region(region)
            } else {
                // Center on user's location if no initial location provided
                viewModel.startLocationUpdates()
                viewModel.centerMapOnUser { region in
                    cameraPosition = .region(region)
                }
            }
        }
    }
    
    private var mapView: some View {
        Map(position: $cameraPosition) {
            // User location marker
            if let userLocation = viewModel.userLocation {
                Marker("My Location", coordinate: userLocation.coordinate)
                    .tint(.blue)
            }
            
            // Video markers and heat map circles
            ForEach(viewModel.videoAnnotations) { annotation in
                if let category = VideoCategory(rawValue: annotation.category),
                   viewModel.selectedCategories.contains(category) {
                    // Heat map circle
                    MapCircle(center: annotation.coordinate, radius: viewModel.circleRadius)
                        .foregroundStyle(category.color.opacity(0.2))
                        .stroke(category.color.opacity(0.4), lineWidth: 1)
                    
                    // Video marker
                    Marker(coordinate: annotation.coordinate) {
                        VideoThumbnailButton(annotation: annotation) {
                            Task {
                                if let video = await viewModel.fetchVideo(id: annotation.id) {
                                    selectedVideo = video
                                    showVideoDetail = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .mapStyle(.standard)
        .onAppear {
            print("🗺 Map view appeared")
        }
        .onChange(of: viewModel.videoAnnotations) { _, newAnnotations in
            print("📍 Annotations updated: \(newAnnotations.count)")
        }
        .ignoresSafeArea(.container, edges: [.horizontal])
        .overlay {
            if let error = viewModel.locationError {
                VStack {
                    Text(error)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding()
                    Spacer()
                }
            }
        }
    }
    
    private var categoryToggles: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(VideoCategory.allCases, id: \.self) { category in
                Button(action: {
                    viewModel.toggleCategory(category)
                }) {
                    HStack {
                        Text(category.rawValue)
                            .font(.caption)
                            .foregroundColor(.white)
                        Circle()
                            .fill(category.color)
                            .frame(width: 12, height: 12)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(viewModel.selectedCategories.contains(category) ?
                                  category.color.opacity(0.3) :
                                    Color.black.opacity(0.5))
                    )
                }
            }
        }
    }
    
    private var locationButton: some View {
        Button {
            viewModel.centerMapOnUser { region in
                withAnimation {
                    cameraPosition = .region(region)
                }
            }
        } label: {
            Image(systemName: "location.fill")
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }
}

struct VideoThumbnailButton: View {
    let annotation: VideoAnnotation
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            if let thumbnailUrl = annotation.thumbnailUrl,
               let url = URL(string: thumbnailUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray
                }
            } else {
                // Default placeholder for videos without thumbnails
                Image(systemName: "video.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 80)
                    .background(Color.gray)
            }
        }
        .frame(width: 60, height: 80)
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

#Preview {
    ExploreView()
}