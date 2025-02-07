import SwiftUI
import MapKit

struct ExploreView: View {
    @StateObject private var viewModel = ExploreViewModel()
    @State private var selectedVideo: Video?
    @State private var showVideoDetail = false
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Map View
                Map(coordinateRegion: Binding(
                    get: { viewModel.region },
                    set: { newRegion in
                        withAnimation(.easeInOut) {
                            viewModel.updateRegion(newRegion)
                        }
                    }
                ),
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
                .edgesIgnoringSafeArea([.horizontal])
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
                
                // Location Button
                Button(action: {
                    withAnimation(.easeInOut) {
                        viewModel.centerMapOnUser()
                    }
                }) {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding(.bottom, 30)
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