import SwiftUI

struct FeedView: View {
    @State private var selectedFeed = 0
    @State private var currentIndex = 0
    
    // Layout constants
    private let tabBarHeight: CGFloat = 0
    private let pickerHeight: CGFloat = 50
    private let bottomPadding: CGFloat = 0
    
    var body: some View {
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
                
                // Video feed
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        if selectedFeed == 0 {
                            FollowingFeedContent(currentIndex: $currentIndex)
                        } else {
                            LocalAreaFeedContent(currentIndex: $currentIndex)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollClipDisabled(false)
                // Calculate exact space between picker and tab bar, with padding above tab bar
                .frame(height: mainGeometry.size.height - tabBarHeight - pickerHeight - bottomPadding)
            }
        }
    }
}

struct FollowingFeedContent: View {
    @Binding var currentIndex: Int
    
    var body: some View {
        ForEach(0..<10) { index in
            VideoCard(index: index)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical)
                .id(index)
        }
    }
}

struct LocalAreaFeedContent: View {
    @Binding var currentIndex: Int
    
    var body: some View {
        ForEach(0..<10) { index in
            VideoCard(index: index)
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical)
                .id(index)
        }
    }
}

struct VideoCard: View {
    let index: Int
    @State private var isWiggling = false
    @State private var showComments = false
    @State private var showRating = false
    @State private var isDescriptionExpanded = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Video content
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                
                // Overlay content
                HStack(alignment: .bottom) {
                    // Left side: Title and description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hidden Gem Alert!")
                            .font(.custom("AvenirNext-Bold", size: 24))
                            .foregroundStyle(.white)
                        
                        HStack {
                            Text("LocalExplorer")
                                .font(.custom("AvenirNext-Medium", size: 16))
                            Text("•")
                            Text("Downtown")
                                .font(.custom("AvenirNext-Medium", size: 16))
                                .padding(.horizontal, 8)
                                .background(Color.accentColor.opacity(0.3))
                                .clipShape(Capsule())
                        }
                        
                        Text("Amazing local coffee shop with the best pastries in town! #coffee #local #foodie")
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
                    
                    // Right side: Interaction buttons with animation
                    VStack(spacing: 20) {
                        InteractionButton(icon: "bookmark.fill", count: "1.2k")
                        
                        InteractionButton(icon: "bubble.left.fill", count: "45")
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    showComments = true
                                }
                            }
                        
                        VStack(spacing: 12) {
                            InteractionButton(icon: "square.and.arrow.up.fill", count: "Share")
                            
                            InteractionButton(icon: "hand.thumbsup.fill", count: "Rate")
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
                    // Handle helpful rating
                }
                Button("Unhelpful") {
                    // Handle unhelpful rating
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
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
            Text(count)
                .font(.custom("AvenirNext-Medium", size: 14))
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

#Preview {
    FeedView()
}
