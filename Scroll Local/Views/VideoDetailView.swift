import SwiftUI
import AVKit

struct VideoDetailView: View {
    let video: Video
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FeedViewModel()
    @StateObject private var commentViewModel = CommentViewModel()
    @State private var showComments = false
    @State private var showRating = false
    @State private var isDescriptionExpanded = false
    @State private var player: AVPlayer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Video content
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .ignoresSafeArea()
                        .onAppear {
                            player.play()
                            // Loop the video
                            NotificationCenter.default.addObserver(
                                forName: .AVPlayerItemDidPlayToEndTime,
                                object: player.currentItem,
                                queue: .main) { _ in
                                    player.seek(to: .zero)
                                    player.play()
                                }
                            // Increment view count and load comment count
                            if let id = video.id {
                                Task {
                                    await viewModel.incrementViews(for: id)
                                    await commentViewModel.loadCommentCount(for: id)
                                }
                            }
                        }
                        .onDisappear {
                            player.pause()
                            NotificationCenter.default.removeObserver(
                                self,
                                name: .AVPlayerItemDidPlayToEndTime,
                                object: player.currentItem
                            )
                        }
                }
                
                // Overlay content
                VStack(spacing: 0) {
                    // Top bar with back button
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.black.opacity(0.7), .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    Spacer()
                    
                    // Bottom info and interactions
                    HStack(alignment: .bottom) {
                        // Left side: Title and description
                        VStack(alignment: .leading, spacing: 4) {
                            Text(video.title)
                                .font(.custom("AvenirNext-Bold", size: 24))
                                .foregroundStyle(.white)
                            
                            HStack {
                                NavigationLink(destination: OtherUserProfileView(userId: video.userId)) {
                                    Text(video.userDisplayName ?? video.userId)
                                }
                                .font(.custom("AvenirNext-Medium", size: 16))
                                .foregroundColor(.white)
                                Text("•")
                                Text(video.location)
                                    .font(.custom("AvenirNext-Medium", size: 16))
                                    .padding(.horizontal, 8)
                                    .background(Color.accentColor.opacity(0.3))
                                    .clipShape(Capsule())
                            }
                            
                            Text(video.description)
                                .font(.custom("AvenirNext-Regular", size: 15))
                                .lineLimit(isDescriptionExpanded ? nil : 2)
                                .onTapGesture {
                                    withAnimation(.easeInOut) {
                                        isDescriptionExpanded.toggle()
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 20)
                        
                        // Right side: Interaction buttons
                        VStack(spacing: 20) {
                            InteractionButton(
                                icon: "bookmark.fill",
                                count: "\(video.saveCount)",
                                isActive: video.id.map(viewModel.isVideoSaved) ?? false
                            )
                            .onTapGesture {
                                if let videoId = video.id {
                                    Task {
                                        await viewModel.toggleSave(for: videoId)
                                    }
                                }
                            }
                            
                            InteractionButton(icon: "bubble.left.fill", count: "\(commentViewModel.commentCount)")
                                .onTapGesture {
                                    commentViewModel.loadComments(for: video.id ?? "")
                                    withAnimation(.spring()) {
                                        showComments = true
                                    }
                                }
                            
                            VStack(spacing: 12) {
                                InteractionButton(icon: "square.and.arrow.up.fill", count: "Share")
                                
                                let rating = video.id.map(viewModel.getVideoRating) ?? 0
                                InteractionButton(
                                    icon: rating == -1 ? "hand.thumbsdown.fill" : "hand.thumbsup.fill",
                                    count: "Rate",
                                    isActive: rating != 0
                                )
                                .onTapGesture {
                                    showRating = true
                                }
                            }
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .sheet(isPresented: $showComments) {
                if let videoId = video.id {
                    CommentView(videoId: videoId)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .alert("Rate this content", isPresented: $showRating) {
                Button("Helpful") {
                    if let videoId = video.id {
                        Task {
                            await viewModel.updateRating(for: videoId, isHelpful: true)
                        }
                    }
                }
                Button("Unhelpful") {
                    if let videoId = video.id {
                        Task {
                            await viewModel.updateRating(for: videoId, isHelpful: false)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear {
            if let url = URL(string: video.videoUrl) {
                player = AVPlayer(url: url)
            }
        }
    }
} 