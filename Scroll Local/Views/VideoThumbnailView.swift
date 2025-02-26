import SwiftUI

struct VideoThumbnailView: View {
    let video: Video
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Thumbnail or placeholder
                if let thumbnailUrl = video.thumbnailUrl,
                   let url = URL(string: thumbnailUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
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
                
                // Info container with dark background
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
                .background(Color.black.opacity(0.7))
                .frame(height: geometry.size.height * 0.27, alignment: .bottom)
                .foregroundColor(.white)
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
    }
} 