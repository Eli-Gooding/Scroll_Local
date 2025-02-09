import SwiftUI
import MapKit
import FirebaseFirestore

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @State private var selectedVideo: Video?
    @State private var showVideoDetail = false
    @State private var isSearchMode = false
    @State private var showLocationFeed = false
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var cameraPosition: MapCameraPosition
    let initialLocation: GeoPoint?
    
    init(initialLocation: GeoPoint? = nil) {
        self.initialLocation = initialLocation
        let initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        _cameraPosition = State(initialValue: .region(initialRegion))
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                ExploreMapView(
                    viewModel: viewModel,
                    cameraPosition: $cameraPosition,
                    isSearchMode: isSearchMode,
                    selectedVideo: $selectedVideo,
                    showVideoDetail: $showVideoDetail,
                    selectedLocation: $selectedLocation,
                    showLocationFeed: $showLocationFeed
                )
                
                VStack(alignment: .trailing, spacing: 8) {
                    CategoryToggleList(viewModel: viewModel)
                    ExploreControlButtons(
                        isSearchMode: $isSearchMode,
                        viewModel: viewModel,
                        cameraPosition: $cameraPosition
                    )
                }
                .padding()
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: isSearchMode) { newValue in
            print("🔍 Search mode changed to: \(newValue)")
        }
        .onChange(of: selectedLocation) { newValue in
            print("📍 Selected location changed to: \(String(describing: newValue))")
        }
        .onChange(of: showLocationFeed) { newValue in
            print("🎬 Show location feed changed to: \(newValue)")
        }
        .sheet(isPresented: $showVideoDetail) {
            if let video = selectedVideo {
                VideoDetailView(video: video)
            }
        }
        .sheet(isPresented: $showLocationFeed) {
            Group {
                if let location = selectedLocation {
                    print("📱 Presenting LocationFeedView for coordinate: \(location)")
                    LocationFeedView(coordinate: location)
                        .presentationDetents([.medium, .large])
                } else {
                    print("⚠️ No location available for LocationFeedView")
                    Color.clear
                }
            }
        }
        .onAppear {
            handleInitialLocation()
        }
    }
    
    private func handleInitialLocation() {
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
            viewModel.startLocationUpdates()
            viewModel.centerMapOnUser { region in
                cameraPosition = .region(region)
            }
        }
    }
}

// MARK: - Map View Component
private struct ExploreMapView: View {
    @ObservedObject var viewModel: ExploreViewModel
    @Binding var cameraPosition: MapCameraPosition
    let isSearchMode: Bool
    @Binding var selectedVideo: Video?
    @Binding var showVideoDetail: Bool
    @Binding var selectedLocation: CLLocationCoordinate2D?
    @Binding var showLocationFeed: Bool
    
    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: isSearchMode ? [] : .all) {
                UserLocationMarker(userLocation: viewModel.userLocation)
                VideoMarkersAndOverlays(
                    viewModel: viewModel,
                    selectedVideo: $selectedVideo,
                    showVideoDetail: $showVideoDetail
                )
            }
            .mapStyle(.standard)
            .contentShape(Rectangle())  // Make sure the entire map is tappable
            .onTapGesture { screenPoint in
                if isSearchMode {
                    print("🗺 Map tapped at screen point: \(screenPoint)")
                    if let coordinate = proxy.convert(screenPoint, from: .local) {
                        print("📍 Converted to coordinate: \(coordinate)")
                        handleMapTap(at: coordinate)
                    } else {
                        print("❌ Failed to convert screen point to coordinate")
                    }
                }
            }
            .overlay(searchModeOverlay)
            .onAppear {
                print("🗺 Map view appeared")
            }
            .onChange(of: viewModel.videoAnnotations) { _, newAnnotations in
                print("📍 Annotations updated: \(newAnnotations.count)")
            }
            .ignoresSafeArea(SafeAreaRegions.container, edges: [Edge.Set.horizontal])
            .overlay(errorOverlay)
        }
    }
    
    private func handleMapTap(at location: CLLocationCoordinate2D) {
        print("🎯 Handling map tap at: \(location)")
        print("🔍 Current search mode: \(isSearchMode)")
        selectedLocation = location
        print("📱 Selected location set to: \(String(describing: selectedLocation))")
        showLocationFeed = true
        print("🔄 showLocationFeed set to: \(showLocationFeed)")
        
        // Force a UI update
        DispatchQueue.main.async {
            print("🔄 Forcing UI update after tap")
            showLocationFeed = true
        }
    }
    
    @ViewBuilder
    private var searchModeOverlay: some View {
        if isSearchMode {
            VStack {
                // Top banner
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.tv.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .scaleEffect(1.1)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                    
                    Text("Tap anywhere to discover local gems!")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .shadow(radius: 1)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.accentColor.opacity(0.9))
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                )
                .padding(.top, 8)
                
                Spacer()
                
                // Semi-transparent overlay for the map
                Color.black.opacity(0.05)
            }
        }
    }
    
    @ViewBuilder
    private var errorOverlay: some View {
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

// MARK: - User Location Marker Component
private struct UserLocationMarker: MapContent {
    let userLocation: CLLocation?
    
    var body: some MapContent {
        if let location = userLocation {
            Marker("My Location", coordinate: location.coordinate)
                .tint(.blue)
        }
    }
}

// MARK: - Video Markers and Overlays Component
private struct VideoMarkersAndOverlays: MapContent {
    @ObservedObject var viewModel: ExploreViewModel
    @Binding var selectedVideo: Video?
    @Binding var showVideoDetail: Bool
    
    var body: some MapContent {
        ForEach(viewModel.videoAnnotations) { annotation in
            if let category = VideoCategory(rawValue: annotation.category),
               viewModel.selectedCategories.contains(category) {
                MapCircle(center: annotation.coordinate, radius: viewModel.circleRadius)
                    .foregroundStyle(category.color.opacity(0.2))
                    .stroke(category.color.opacity(0.4), lineWidth: 1)
                
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
}

// MARK: - Category Toggle List Component
private struct CategoryToggleList: View {
    @ObservedObject var viewModel: ExploreViewModel
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(VideoCategory.allCases, id: \.self) { category in
                CategoryToggleButton(
                    category: category,
                    isSelected: viewModel.selectedCategories.contains(category),
                    action: { viewModel.toggleCategory(category) }
                )
            }
        }
    }
}

// MARK: - Category Toggle Button Component
private struct CategoryToggleButton: View {
    let category: VideoCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
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
                    .fill(isSelected ?
                          category.color.opacity(0.3) :
                            Color.black.opacity(0.5))
            )
        }
    }
}

// MARK: - Control Buttons Component
private struct ExploreControlButtons: View {
    @Binding var isSearchMode: Bool
    @ObservedObject var viewModel: ExploreViewModel
    @Binding var cameraPosition: MapCameraPosition
    
    var body: some View {
        HStack(spacing: 8) {
            SearchModeButton(isSearchMode: $isSearchMode)
            LocationButton(viewModel: viewModel, cameraPosition: $cameraPosition)
        }
    }
}

// MARK: - Search Mode Button Component
private struct SearchModeButton: View {
    @Binding var isSearchMode: Bool
    
    var body: some View {
        Button {
            isSearchMode.toggle()
        } label: {
            Image(systemName: isSearchMode ? "magnifyingglass.circle.fill" : "magnifyingglass.circle")
                .font(.title2)
                .foregroundColor(.white)
                .padding(12)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }
}

// MARK: - Location Button Component
private struct LocationButton: View {
    @ObservedObject var viewModel: ExploreViewModel
    @Binding var cameraPosition: MapCameraPosition
    
    var body: some View {
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