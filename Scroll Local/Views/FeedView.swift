import SwiftUI
import AVKit
import Firebase
import FirebaseFunctions
import FirebaseAuth

struct FeedView: View {
    @StateObject private var viewModel = FeedViewModel()
    @State private var selectedFeed = 0
    @State private var currentIndex = 0
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var searchQuery = ""
    @State private var searchResults: [Video] = []
    @State private var showSearchPrompt = false
    @State private var currentSearchId: String?
    @State private var showFeedback = false
    let initialVideoId: String?
    
    init(initialVideoId: String? = nil) {
        self.initialVideoId = initialVideoId
    }
    
    // Layout constants
    private let tabBarHeight: CGFloat = 0
    private let pickerHeight: CGFloat = 50
    private let bottomPadding: CGFloat = 0
    
    var body: some View {
        NavigationStack {
            GeometryReader { mainGeometry in
                VStack(spacing: 0) {
                    // Updated Feed selector with combined Explore and sparkles
                    Picker("Feed Type", selection: $selectedFeed) {
                        Text("Following").tag(0)
                        Text("Local Area").tag(1)
                        Label {
                            Text("Explore")
                        } icon: {
                            Image(systemName: "sparkles")
                                .font(.caption)
                        }.tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.1))
                            .padding(.horizontal, 8)
                    )
                    
                    // Show search interface for Explore tab
                    if selectedFeed == 2 {
                        ZStack(alignment: .top) {
                            // Default state - show search interface
                            if !viewModel.hasSearched {
                                SearchInterface(
                                    searchText: $searchText,
                                    isSearchActive: $isSearchActive,
                                    viewModel: viewModel
                                )
                            }
                            // Show results if we have them
                            else if !viewModel.videos.isEmpty {
                                // Video feed with floating search button
                                ZStack(alignment: .topTrailing) {
                                    ScrollView(.vertical, showsIndicators: false) {
                                        LazyVStack(spacing: 0) {
                                            ForEach(Array(viewModel.videos.enumerated()), id: \.element.id) { index, video in
                                                VideoCard(video: video, index: index, viewModel: viewModel)
                                                    .frame(maxWidth: .infinity)
                                                    .containerRelativeFrame(.vertical)
                                                    .id(index)
                                            }
                                        }
                                        .scrollTargetLayout()
                                    }
                                    .scrollTargetBehavior(.paging)
                                    .scrollClipDisabled(false)
                                    .frame(height: mainGeometry.size.height - tabBarHeight - pickerHeight - bottomPadding)
                                    .scrollPosition(id: .init(get: { currentIndex }, set: { newValue in
                                        if let newIndex = newValue {
                                            currentIndex = newIndex
                                            // Show feedback when reaching the last video
                                            if newIndex == viewModel.videos.count - 1 {
                                                showFeedback = true
                                            }
                                        }
                                    }))
                                    
                                    // Floating search button
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            isSearchActive = true
                                        }
                                    }) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .padding(12)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                    }
                                    .padding()
                                }
                                .sheet(isPresented: $showFeedback) {
                                    SearchFeedbackView(
                                        query: viewModel.lastSearchQuery ?? "",
                                        videos: viewModel.videos,
                                        viewModel: viewModel
                                    )
                                    .presentationDetents([.medium])
                                }
                            }
                            // No results state
                            else {
                                Text("No videos found")
                                    .foregroundColor(.secondary)
                            }
                            
                            // Overlay search interface when active
                            if isSearchActive {
                                SearchInterface(
                                    searchText: $searchText,
                                    isSearchActive: $isSearchActive,
                                    viewModel: viewModel
                                )
                            }
                            
                            // Loading overlay
                            if viewModel.isLoading {
                                LoadingOverlay()
                            }
                        }
                    } else {
                        // Original content for Following and Local Area tabs
                    if viewModel.isLoading && viewModel.videos.isEmpty {
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
                            Text(selectedFeed == 0 ? "Follow some users to see their content" : "No videos found in your area")
                                .font(.headline)
                        Spacer()
                    } else {
                        // Video feed with search button for Explore tab
                        ZStack(alignment: .topTrailing) {
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(spacing: 0) {
                                    switch selectedFeed {
                                    case 0:
                                        FollowingFeedContent(videos: viewModel.videos, currentIndex: $currentIndex, viewModel: viewModel)
                                    case 1:
                                        LocalAreaFeedContent(videos: viewModel.videos, currentIndex: $currentIndex, viewModel: viewModel)
                                    case 2:
                                        ExploreFeedContent(videos: viewModel.videos, currentIndex: $currentIndex, viewModel: viewModel)
                                    default:
                                        EmptyView()
                                    }
                                }
                                .scrollTargetLayout()
                            }
                            .scrollTargetBehavior(.paging)
                            .scrollClipDisabled(false)
                            .frame(height: mainGeometry.size.height - tabBarHeight - pickerHeight - bottomPadding)
                            .scrollPosition(id: .init(get: { currentIndex }, set: { newValue in
                                if let newIndex = newValue {
                                    currentIndex = newIndex
                                    if newIndex >= viewModel.videos.count - 2 {
                                        Task {
                                            await viewModel.fetchMoreVideos()
                                        }
                                    }
                                }
                            }))
                            
                            // Search button (only shown in Explore tab)
                                if selectedFeed == 2 && !isSearchActive {
                                Button(action: {
                                    withAnimation(.spring()) {
                                            isSearchActive = true
                                    }
                                }) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                                .padding()
                                }
                            }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedFeed) { newValue in
            Task {
                if newValue != 2 { // Not Explore tab
                    await viewModel.updateFeedType(newValue == 0 ? .following : .localArea)
                }
            }
        }
        .task {
            print("FeedView appeared, fetching videos...")
            await viewModel.fetchVideos()
            
            if let videoId = initialVideoId,
               let index = viewModel.videos.firstIndex(where: { $0.id == videoId }) {
                currentIndex = index
            }
        }
    }
}

struct FollowingFeedContent: View {
    let videos: [Video]
    @Binding var currentIndex: Int
    @ObservedObject var viewModel: FeedViewModel
    
    var body: some View {
        ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
            VideoCard(video: video, index: index, viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical)
                .id(index)
        }
    }
}

struct LocalAreaFeedContent: View {
    let videos: [Video]
    @Binding var currentIndex: Int
    @ObservedObject var viewModel: FeedViewModel
    
    var body: some View {
        ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
            VideoCard(video: video, index: index, viewModel: viewModel)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical)
                .id(index)
        }
    }
}

struct ExploreFeedContent: View {
    let videos: [Video]
    @Binding var currentIndex: Int
    @ObservedObject var viewModel: FeedViewModel
    @State private var showFeedback = false
    
    var body: some View {
        VStack {
            ForEach(Array(videos.enumerated()), id: \.element.id) { index, video in
                VideoCard(video: video, index: index, viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .containerRelativeFrame(.vertical)
                    .id(index)
            }
        }
        .onChange(of: currentIndex) { oldValue, newValue in
            print("Current index changed to: \(newValue), total videos: \(videos.count)")
            if newValue == videos.count - 1 {
                print("Showing feedback sheet")
                showFeedback = true
            }
        }
        .sheet(isPresented: $showFeedback) {
            SearchFeedbackView(
                query: viewModel.lastSearchQuery ?? "",
                videos: videos,
                viewModel: viewModel
            )
            .presentationDetents([.medium])
        }
    }
}

struct VideoCard: View {
    let video: Video
    let index: Int
    @State private var isWiggling = false
    @State private var showComments = false
    @StateObject private var commentViewModel = CommentViewModel()
    @State private var showRating = false
    @State private var isDescriptionExpanded = false
    @State private var player: AVPlayer?
    @ObservedObject var viewModel: FeedViewModel
    
    init(video: Video, index: Int, viewModel: FeedViewModel) {
        self.video = video
        self.index = index
        self.viewModel = viewModel
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
                            NavigationLink(destination: ExploreView(initialLocation: video.location)) {
                                Text(video.formattedLocation)
                                    .font(.custom("AvenirNext-Medium", size: 16))
                                    .padding(.horizontal, 8)
                                    .background(Color.accentColor.opacity(0.3))
                                    .clipShape(Capsule())
                            }
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
                .foregroundColor(.white)
            }
            .frame(maxHeight: geometry.size.height)
            .cornerRadius(20)
            .shadow(radius: 5)
            .padding(.horizontal, 8)
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

extension FeedViewModel {
    func performSemanticSearch(_ query: String) async {
        isLoading = true
        hasSearched = false
        
        do {
            let functions = Functions.functions()
            let result = try await functions.httpsCallable("semanticVideoSearch")
                .call(["query": query])
            
            if let searchResults = result.data as? [[String: Any]] {
                print("Received \(searchResults.count) search results")
                
                let videoIds = searchResults.compactMap { $0["id"] as? String }
                let db = Firestore.firestore()
                
                // Simple sequential fetching - no fancy async tasks needed
                var videos: [Video] = []
                for id in videoIds {
                    let docRef = db.collection("videos").document(id)
                    let doc = try await docRef.getDocument()
                    if let video = Video(id: doc.documentID, data: doc.data() ?? [:]) {
                        videos.append(video)
                    }
                }
                
                DispatchQueue.main.async {
                    self.videos = videos
                    self.hasSearched = true
                }
            } else {
                print("Failed to parse search results")
                print("Result data type: \(type(of: result.data))")
            }
        } catch {
            print("Search error:", error)
            DispatchQueue.main.async {
                self.error = error
            }
        }
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
    }
    
    func submitSearchFeedback(searchId: String, isHelpful: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let functions = Functions.functions()
            _ = try await functions.httpsCallable("submitSearchFeedback")
                .call([
                    "searchId": searchId,
                    "isHelpful": isHelpful,
                    "userId": userId
                ])
        } catch {
            print("Error submitting feedback:", error)
        }
    }
}

struct CustomSearchFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            )
            .font(.system(size: 18))
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(), value: configuration.isPressed)
    }
}

extension Sequence {
    func asyncCompactMap<T>(_ transform: (Element) async throws -> T?) async throws -> [T] {
        var values = [T]()
        for element in self {
            if let transformed = try await transform(element) {
                values.append(transformed)
            }
        }
        return values
    }
}

struct SearchInterface: View {
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    @ObservedObject var viewModel: FeedViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            if !isSearchActive {
                Spacer()
            }
            
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)
                .opacity(isSearchActive ? 0 : 1)
            
            Text("What would you like to discover?")
                .font(.headline)
                .opacity(isSearchActive ? 0 : 1)
            
            // Search field and buttons
            HStack(spacing: 12) {
                TextField("Search videos...", text: $searchText)
                    .textFieldStyle(CustomSearchFieldStyle())
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isSearchActive = true
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        Task {
                            isSearchActive = false  // Hide search when results come
                            await viewModel.performSemanticSearch(searchText)
                        }
                    }) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 44))
                            .shadow(radius: 2)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                
                if isSearchActive {
                    Button(action: {
                        searchText = ""
                        withAnimation(.spring()) {
                            isSearchActive = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                         to: nil, from: nil, for: nil)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.title2)
                    }
                }
            }
            .padding(.horizontal)
            
            if !searchText.isEmpty && isSearchActive {
                Text("Try: 'Show me somewhere warm and sunny where I can learn to surf'")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
            
            if !isSearchActive {
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .background(
            Group {
                if isSearchActive {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                } else {
                    Rectangle()
                        .fill(.clear)
                        .ignoresSafeArea()
                }
            }
        )
        .animation(.spring(), value: isSearchActive)
    }
}

struct LoadingOverlay: View {
    var body: some View {
        VStack {
            Spacer()
            ProgressView("Searching...")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}

struct SearchFeedbackView: View {
    let query: String
    let videos: [Video]
    @ObservedObject var viewModel: FeedViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Were these results helpful?")
                .font(.title2)
                .bold()
            
            Text("Your feedback helps improve search results")
                .foregroundColor(.secondary)
            
            HStack(spacing: 40) {
                Button(action: {
                    Task {
                        await viewModel.submitExploreResults(
                            query: query,
                            videos: videos,
                            isHelpful: false
                        )
                        dismiss()
                    }
                }) {
                    VStack {
                        Image(systemName: "hand.thumbsdown.fill")
                            .font(.system(size: 44))
                        Text("Not Helpful")
                    }
                    .foregroundColor(.red)
                }
                
                Button(action: {
                    Task {
                        await viewModel.submitExploreResults(
                            query: query,
                            videos: videos,
                            isHelpful: true
                        )
                        dismiss()
                    }
                }) {
                    VStack {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.system(size: 44))
                        Text("Helpful")
                    }
                    .foregroundColor(.green)
                }
            }
            .padding()
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}
