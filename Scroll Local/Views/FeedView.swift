import SwiftUI

struct FeedView: View {
    @State private var selectedFeed = 0
    @State private var currentIndex = 0
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Feed selector
                Picker("Feed Type", selection: $selectedFeed) {
                    Text("Following").tag(0)
                    Text("Local Area").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // Video feed
                GeometryReader { geometry in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            if selectedFeed == 0 {
                                FollowingFeedContent(currentIndex: $currentIndex)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            } else {
                                LocalAreaFeedContent(currentIndex: $currentIndex)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollTargetLayout()
                }
                .ignoresSafeArea()
            }
            .navigationTitle("Scroll Local")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

struct FollowingFeedContent: View {
    @Binding var currentIndex: Int
    
    var body: some View {
        ForEach(0..<10) { index in
            VideoCard(index: index)
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
                .containerRelativeFrame(.vertical)
                .id(index)
        }
    }
}

struct VideoCard: View {
    let index: Int
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Video content
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                
                // Overlay content
                HStack(alignment: .bottom) {
                    // Left side: Title and description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Hidden Gem Alert!")
                            .font(.title3)
                            .bold()
                        
                        HStack {
                            Text("LocalExplorer")
                                .font(.subheadline)
                            Text("•")
                            Text("Downtown")
                                .font(.subheadline)
                        }
                        
                        Text("Amazing local coffee shop with the best pastries in town! #coffee #local #foodie")
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 64)
                    
                    // Right side: Interaction buttons
                    VStack(spacing: 20) {
                        InteractionButton(icon: "heart", count: "1.2k")
                        InteractionButton(icon: "square.on.square", count: "45")
                        InteractionButton(icon: "square.and.arrow.up", count: "Share")
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .black.opacity(0.5)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .foregroundColor(.white)
            }
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
                .font(.caption)
        }
    }
}

#Preview {
    FeedView()
}
