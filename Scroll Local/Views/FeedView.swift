import SwiftUI
import AVKit
import Firebase

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedFeed = 0
    @State private var currentIndex = 0
    
    // Layout constants
    private let tabBarHeight: CGFloat = 0
    private let pickerHeight: CGFloat = 50
    private let bottomPadding: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            GeometryReader { mainGeometry in
                VStack(spacing: 0) {
                    // Feed selector
                    Picker("Feed Type", selection: $selectedFeed) {
                        Text("Following").tag(0)
                        Text("Local Area").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.1))
                            .padding(.horizontal, 8)
                    )
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Loading videos...")
                        Spacer()
                    } else if let error = viewModel.error {
                        Spacer()
                        VStack {
                            Text("Error loading videos")
                                .font(.headline)
                            Text(error.localizedDescription)
                                .font(.subheadline)
                                .foregroundColor(.red)
                            Button("Retry") {
                                Task {
                                    await viewModel.fetchVideos()
                                }
                            }
                            .padding()
                        }
                        Spacer()
                    } else if viewModel.videos.isEmpty {
                        Spacer()
                        Text("No videos found")
                            .font(.headline)
                        Spacer()
                    } else {
                        // Video feed
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                if selectedFeed == 0 {
                                    FollowingFeedContent(videos: viewModel.videos, currentIndex: $currentIndex)
                                } else {
                                    LocalAreaFeedContent(videos: viewModel.videos, currentIndex: $currentIndex)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.paging)
                        .scrollClipDisabled(false)
                        .frame(height: mainGeometry.size.height - tabBarHeight - pickerHeight - bottomPadding)
                    }
                }
            }
        }
        .task {
            print("FeedView appeared, fetching videos...")
            await viewModel.fetchVideos()
        }
    }
}

struct FollowingFeedContent: View {
    let videos: [Video]
    @Binding var currentIndex: Int
    
    var body: some View {
        ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
            VideoCard(video: video, index: index)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical)
                .id(index)
        }
    }
}

struct LocalAreaFeedContent: View {
    let videos: [Video]
    @Binding var currentIndex: Int
    
    var body: some View {
        ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
            VideoCard(video: video, index: index)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical)
                .id(index)
        }
    }
}

struct VideoCard: View {
    let video: Video
    let index: Int
    @State private var isWiggling = false
    @State private var showComments = false
    @State private var showRating = false
    @State private var isDescriptionExpanded = false
    @State private var player: AVPlayer?
    @StateObject private var viewModel = FeedViewModel()
    
    init(video: Video, index: Int) {
        self.video = video
        self.index = index
        if let url = URL(string: video.videoUrl) {
            let player = AVPlayer(url: url)
            player.isMuted = true // Muted by default for better UX
            _player = State(initialValue: player)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Video content
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
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
                            // Increment view count
                            if let id = video.id {
                                Task {
                                    await viewModel.incrementViews(for: id)
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
                HStack(alignment: .bottom) {
                    // Left side: Title and description
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.custom("AvenirNext-Bold", size: 24))
                            .foregroundStyle(.white)
                        
                        HStack {
                            NavigationLink(video.userId) {
                                OtherUserProfileView(username: video.userId)
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
                            isActive: viewModel.isVideoSaved(video.id ?? "")
                        )
                        .onTapGesture {
                            if let id = video.id {
                                Task {
                                    await viewModel.toggleSave(for: id)
                                }
                            }
                        }
                        
                        InteractionButton(icon: "bubble.left.fill", count: "\(video.commentCount)")
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    showComments = true
                                }
                            }
                        
                        VStack(spacing: 12) {
                            InteractionButton(icon: "square.and.arrow.up.fill", count: "Share")
                            
                            let rating = viewModel.getVideoRating(video.id ?? "")
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
                .foregroundColor(.white)
            }
            .frame(maxHeight: geometry.size.height)
            .cornerRadius(20)
            .shadow(radius: 5)
            .padding(.horizontal, 8)
            .sheet(isPresented: $showComments) {
                CommentsSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .alert("Rate this content", isPresented: $showRating) {
                Button("Helpful") {
                    if let id = video.id {
                        Task {
                            await viewModel.updateRating(for: id, isHelpful: true)
                        }
                    }
                }
                Button("Unhelpful") {
                    if let id = video.id {
                        Task {
                            await viewModel.updateRating(for: id, isHelpful: false)
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

struct CommentsSheet: View {
    @State private var newComment: String = ""
    @FocusState private var isCommentFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Comments")
                .font(.title)
                .bold()
                .padding(.horizontal)
            
            // Comment input field
            HStack(spacing: 12) {
                TextField("Add a comment...", text: $newComment, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .focused($isCommentFocused)
                    .lineLimit(1...5)
                
                Button(action: {
                    // Handle posting comment
                    if !newComment.isEmpty {
                        // Add comment logic here
                        newComment = ""
                        isCommentFocused = false
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(newComment.isEmpty ? .gray : .accentColor)
                }
                .disabled(newComment.isEmpty)
            }
            .padding(.horizontal)
            
            Divider()
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(0..<10) { _ in
                        CommentRow()
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top)
    }
}

struct CommentRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color.gray)
                    .frame(width: 40, height: 40)
                
                VStack(alignment: .leading) {
                    Text("User Name")
                        .font(.headline)
                    Text("2 hours ago")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Text("This is a great find! I love the atmosphere and the coffee is amazing!")
                .font(.body)
        }
    }
}

struct InteractionButton: View {
    let icon: String
    let count: String
    var isActive: Bool = false
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(isActive ? Color.accentColor : .white)
            Text(count)
                .font(.custom("AvenirNext-Medium", size: 12))
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

#Preview {
    FeedView()
}
