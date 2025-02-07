import SwiftUI
import MapKit
import FirebaseFirestore

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @State private var selectedVideo: Video?
    @State private var showVideoDetail = false
    @StateObject private var cameraPositionState = CameraPositionState()
    let initialLocation: GeoPoint?
    
    init(initialLocation: GeoPoint? = nil) {
        self.initialLocation = initialLocation
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                mapView
                locationButton
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
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
                cameraPositionState.position = .region(region)
            } else {
                // Only center on user location when first opening the view
                viewModel.centerMapOnUser { region in
                    cameraPositionState.position = .region(region)
                }
            }
            viewModel.startLocationUpdates()
        }
    }
    
    private var mapView: some View {
        Map(position: $cameraPositionState.position) {
            // User location marker
            if let userLocation = viewModel.userLocation,
               viewModel.locationAuthorizationStatus == .authorizedWhenInUse ||
               viewModel.locationAuthorizationStatus == .authorizedAlways {
                Marker(coordinate: userLocation.coordinate) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.white)
                        .background(Circle().fill(.blue))
                }
            }
            
            // Video markers
            ForEach(viewModel.videoAnnotations) { annotation in
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
        .mapStyle(.standard)
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
    
    private var locationButton: some View {
        Button {
            viewModel.centerMapOnUser { region in
                withAnimation(.easeInOut) {
                    cameraPositionState.position = .region(region)
                }
            }
        } label: {
            Image(systemName: "location.fill")
                .font(.title2)
                .padding()
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .padding(.bottom, 30)
    }
}

struct VideoThumbnailButton: View {
    let annotation: VideoAnnotation
    let action: () -> Void
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        Button(action: action) {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 4)
            } else {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 60, height: 60)
                    .overlay(ProgressView())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 4)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard let url = URL(string: annotation.thumbnailUrl) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.thumbnailImage = image
                }
            }
        }.resume()
    }
}

@MainActor
class CameraPositionState: ObservableObject {
    @Published var position: MapCameraPosition = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    ))
}

#Preview {
    ExploreView()
}

extension EnvironmentValues {
    var cameraPosition: Binding<MapCameraPosition> {
        get { self[CameraPositionKey.self] }
        set { self[CameraPositionKey.self] = newValue }
    }
}

private struct CameraPositionKey: EnvironmentKey {
    static let defaultValue: Binding<MapCameraPosition> = .constant(.automatic)
} 