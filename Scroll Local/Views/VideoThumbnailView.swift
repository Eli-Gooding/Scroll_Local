import SwiftUI
import FirebaseStorage

struct VideoThumbnailView: View {
    let video: Video
    @State private var thumbnailExists = false
    @State private var thumbnailUrl: URL?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // Thumbnail or placeholder
                if let url = thumbnailUrl {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "play.rectangle")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        }
                }
                
                // Overlay with video info
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.caption)
                        .bold()
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // Views
                        Label("\(video.views)", systemImage: "eye.fill")
                            .font(.caption2)
                        
                        // Saves
                        Label("\(video.saveCount)", systemImage: "bookmark.fill")
                            .font(.caption2)
                        
                        // Rating ratio
                        let total = video.helpfulCount + video.notHelpfulCount
                        if total > 0 {
                            let ratio = Double(video.helpfulCount) / Double(total)
                            Label(String(format: "%.0f%%", ratio * 100), systemImage: "hand.thumbsup.fill")
                                .font(.caption2)
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .foregroundColor(.white)
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .task {
            await checkAndLoadThumbnail()
        }
    }
    
    private func checkAndLoadThumbnail() async {
        guard let videoId = video.id else { return }
        
        let storage = Storage.storage()
        let thumbPath = "videos/thumb_\(videoId).png"
        let thumbRef = storage.reference().child(thumbPath)
        
        do {
            let url = try await thumbRef.downloadURL()
            await MainActor.run {
                self.thumbnailUrl = url
            }
        } catch {
            print("No thumbnail found for video \(videoId): \(error)")
            // Leave thumbnailUrl as nil to show placeholder
        }
    }
} 