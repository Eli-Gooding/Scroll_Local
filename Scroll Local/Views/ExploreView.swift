import SwiftUI
import MapKit

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @State private var selectedVideo: Video?
    @State private var showVideoDetail = false
    
    var body: some View {
        ZStack {
            // Map View
            Map(coordinateRegion: $viewModel.region,
                showsUserLocation: true,
                annotationItems: viewModel.videoAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
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
            .ignoresSafeArea()
            
            // Location Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            if let location = viewModel.userLocation {
                                viewModel.region.center = location.coordinate
                            }
                        }
                    }) {
                        Image(systemName: "location.fill")
                            .font(.title2)
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showVideoDetail) {
            if let video = selectedVideo {
                VideoDetailView(video: video)
            }
        }
        .onAppear {
            viewModel.startLocationUpdates()
        }
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

#Preview {
    ExploreView()
} 